require "./base"

module Dark::Agent::Commands
  class Ls < Base
    def name : String
      "ls"
    end

    def execute(task : JSON::Any) : Nil
      task_id = task["id"]?.try(&.as_s) || ""
      path = task["parameters"]["path"]?.try(&.as_s) || ""

      target_path = path.empty? ? Dir.current : path

      # Check if path exists
      if !File.exists?(target_path)
        MessageHandler.add_response(task_id, :success, "Path does not exist: #{target_path}")
        return
      end

      # Create file browser JSON response that works with Mythic UI
      target_is_file = !File.directory?(target_path)
      target_name = File.basename(target_path)
      if target_name.empty? || target_name == "."
        target_name = File.basename(Dir.current)
      end

      parent_path = File.dirname(File.expand_path(target_path))

      # If it's a directory, get files
      files = [] of Hash(String, JSON::Any)
      if !target_is_file
        begin
          Dir.each_child(target_path) do |entry_name|
            file_path = File.join(target_path, entry_name)
            begin
              file_details = File.info(file_path)

              # Create file browser object with required fields
              file = {
                "name" => JSON::Any.new(entry_name),
                "is_file" => JSON::Any.new(!file_details.directory?),
                "size" => JSON::Any.new(file_details.size),
                "modify_time" => JSON::Any.new((file_details.modification_time.to_unix * 1000).to_i64),
                "permissions" => JSON::Any.new({
                  "readable" => JSON::Any.new(File::Info.readable?(file_path)),
                  "writable" => JSON::Any.new(File::Info.writable?(file_path)),
                  "executable" => JSON::Any.new(File::Info.executable?(file_path))
                }),
                "access_time" => JSON::Any.new((file_details.modification_time.to_unix * 1000).to_i64),
                "creation_time" => JSON::Any.new((file_details.modification_time.to_unix * 1000).to_i64)
              }
              files << file
            rescue ex
              # Skip entries with permission issues
              log_debug("Error getting info for #{file_path}: #{ex.message}")
            end
          end
        rescue ex
          log_error("Error reading directory: #{ex.message}")
        end
      end

      # Get current file/directory info
      current_info = File.info(target_path)

      # Create file browser data structure according to Mythic's expected format
      file_browser_data = {
        "host" => JSON::Any.new(""),
        "is_file" => JSON::Any.new(target_is_file),
        "permissions" => JSON::Any.new({
          "readable" => JSON::Any.new(::File::Info.readable?(target_path)),
          "writable" => JSON::Any.new(File::Info.writable?(target_path)),
          "executable" => JSON::Any.new(File::Info.executable?(target_path))
        }),
        "name" => JSON::Any.new(target_name),
        "parent_path" => JSON::Any.new(parent_path),
        "success" => JSON::Any.new(true),
        "modify_time" => JSON::Any.new((current_info.modification_time.to_unix)),
        "size" => JSON::Any.new(current_info.size),
        "update_deleted" => JSON::Any.new(true),
        "files" => JSON::Any.new(files.map { |file| JSON::Any.new(file) })
      }

      # Add file browser response using MessageHandler
      MessageHandler.add_response(task_id, :file_browser, file_browser_data: file_browser_data, user_output: file_browser_data.to_json)
    end
  end
end