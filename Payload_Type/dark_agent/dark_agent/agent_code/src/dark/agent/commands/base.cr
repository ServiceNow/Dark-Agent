require "json"
require "../message_handler"

module Dark::Agent::Commands
  abstract class Base
    abstract def name : String
    abstract def execute(task : JSON::Any) : Nil

    protected def config : Config::Base
      command_handler.config
    end

    protected def bof_registry : Dark::ELF::BofRegistry
      command_handler.bof_registry
    end

    protected def command_handler : Dark::Agent::CommandHandler
      Dark::Agent::CommandHandler.instance.not_nil!
    end
  end

  class Registry
    @commands = {} of String => Base.class

    def register(command_class : Base.class)
      instance = command_class.new
      @commands[instance.name] = command_class
    end

    def has_command?(name : String) : Bool
      @commands.has_key?(name)
    end

    def execute(command_name : String, task : JSON::Any) : Nil
      command_class = @commands[command_name]?
      unless command_class
        task_id = task["id"]?.try(&.as_s) || ""
        MessageHandler.add_response(task_id, :error, "Unknown command: #{command_name}")
        return
      end

      begin
        command_instance = command_class.new
        command_instance.execute(task)
      rescue ex
        task_id = task["id"]?.try(&.as_s) || ""
        MessageHandler.add_response(task_id, :error, "Error executing #{command_name}: #{ex.message}")
      end
    end

    def list_commands : Array(String)
      @commands.keys.sort
    end
  end
end