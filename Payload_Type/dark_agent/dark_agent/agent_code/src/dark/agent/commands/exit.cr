require "./base"
require "../message_handler"
require "../transport"

module Dark::Agent::Commands
  class Exit < Base
    def name : String
      "exit"
    end

    def execute(task : JSON::Any) : Nil
      # Extract task ID for response
      task_id = task["id"]?.try(&.as_s) || ""

      # Queue the exit confirmation response
      MessageHandler.add_response(task_id, :success, "Exit task received, peace out!")

      # Force send any queued responses
      transport = Dark::Agent::Transport::Active.instance
      transport.send_responses

      # Give a small delay to ensure the response is transmitted
      sleep 0.5

      # Peace out!
      exit 0
    end
  end
end