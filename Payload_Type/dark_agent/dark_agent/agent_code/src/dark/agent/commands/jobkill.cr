require "./base"

module Dark::Agent::Commands
  class Jobkill < Base
    def name : String
      "jobkill"
    end

    def execute(task : JSON::Any) : Nil
      task_id = task["id"]?.try(&.as_s) || ""
      target_task_id = task["parameters"]["task_id"]?.try(&.as_s) || ""

      if target_task_id.empty?
        MessageHandler.add_response(task_id, :error, "No task ID specified for jobkill")
        return
      end

      log_debug("Attempting to kill BOF job with task ID: #{target_task_id}")

      # Try to kill the job
      if bof_registry.kill_job(target_task_id)
        MessageHandler.add_response(task_id, :success, "Successfully marked job #{target_task_id} for termination")
      else
        MessageHandler.add_response(task_id, :error, "Job with task ID #{target_task_id} not found")
      end
    end
  end
end