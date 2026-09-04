require "./base"

module Dark::Agent::Commands
  class Jobs < Base
    def name : String
      "jobs"
    end

    def execute(task : JSON::Any) : Nil
      task_id = task["id"]?.try(&.as_s) || ""

      log_debug("Listing active BOF jobs")

      # Get active jobs from the BOF registry
      active_jobs = bof_registry.list_jobs

      if active_jobs.empty?
        MessageHandler.add_response(task_id, :success, "No active BOF jobs")
        return
      end

      # Format jobs as JSON for browser script support
      jobs_array = [] of Hash(String, String | Int32)
      
      active_jobs.each do |job_task_id, job_info|
        # Format duration as HH:MM:SS
        duration_seconds = job_info[:duration].total_seconds.to_i
        hours = duration_seconds // 3600
        minutes = (duration_seconds % 3600) // 60
        seconds = duration_seconds % 60
        duration_str = sprintf("%02d:%02d:%02d", hours, minutes, seconds)

        jobs_array << {
          "task_id" => job_task_id,
          "bof_name" => job_info[:bof_name],
          "duration" => duration_str,
          "duration_seconds" => duration_seconds,
          "start_time" => job_info[:start_time].to_s("%Y-%m-%d %H:%M:%S")
        }
      end

      # Output JSON format
      output = String.build do |str|
        str << "{\n"
        str << "  \"jobs\": [\n"
        jobs_array.each_with_index do |job, index|
          str << "    {\n"
          str << "      \"task_id\": \"#{job["task_id"]}\",\n"
          str << "      \"bof_name\": \"#{job["bof_name"]}\",\n"
          str << "      \"duration\": \"#{job["duration"]}\",\n"
          str << "      \"duration_seconds\": #{job["duration_seconds"]},\n"
          str << "      \"start_time\": \"#{job["start_time"]}\"\n"
          str << "    }#{index < jobs_array.size - 1 ? "," : ""}\n"
        end
        str << "  ]\n"
        str << "}\n"
      end

      MessageHandler.add_response(task_id, :success, output)
    end
  end
end