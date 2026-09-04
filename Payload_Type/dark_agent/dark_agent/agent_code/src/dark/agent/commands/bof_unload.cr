require "./base"

module Dark::Agent::Commands
  class BofUnload < Base
    def name : String
      "bof_unload"
    end

    def execute(task : JSON::Any) : Nil
      task_id = task["id"]?.try(&.as_s) || ""
      bof_name = task["parameters"]["name"]?.try(&.as_s) || ""

      if bof_name.empty?
        MessageHandler.add_response(task_id, :success, "No BOF name specified")
        return
      end

      if bof_registry.unload(bof_name)
        MessageHandler.add_response(task_id, :success, "Successfully unloaded BOF: #{bof_name}")
      else
        MessageHandler.add_response(task_id, :success, "BOF not found: #{bof_name}")
      end
    end
  end
end