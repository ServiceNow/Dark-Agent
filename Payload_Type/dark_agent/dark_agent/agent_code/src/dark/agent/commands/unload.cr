require "./base"

module Dark::Agent::Commands
  class Unload < Base
    def name : String
      "unload"
    end

    def execute(task : JSON::Any) : Nil
      task_id = task["id"]?.try(&.as_s) || ""
      command_name = task["parameters"]["name"]?.try(&.as_s) || ""

      if command_name.empty?
        MessageHandler.add_response(task_id, :success, "No command name specified")
        return
      end

      if bof_registry.unload(command_name)
        # Remove the command from the agent
        MessageHandler.remove_command(command_name)
        MessageHandler.add_response(task_id, :success, "Successfully unloaded BOF: #{command_name}")
      else
        MessageHandler.add_response(task_id, :success, "BOF not found: #{command_name}")
      end
    end
  end
end