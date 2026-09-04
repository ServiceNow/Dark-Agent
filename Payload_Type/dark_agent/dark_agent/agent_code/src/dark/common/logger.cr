# Logging functions
{% if flag?(:debug) %}
  # Debug mode logging - colored output with timestamps
  def log_error(message)
    timestamp = Time.local.to_s("%H:%M:%S")
    puts "\033[0;31m[#{timestamp}] #{message}\033[0m"
  end

  def log_warn(message)
    timestamp = Time.local.to_s("%H:%M:%S")
    puts "\033[0;33m[#{timestamp}] #{message}\033[0m"
  end

  def log_debug(message)
    {% if flag?(:debug_socks) %}
      # In SOCKS debug mode, suppress regular debug logs to reduce noise
    {% else %}
      timestamp = Time.local.to_s("%H:%M:%S")
      puts "\033[0;36m[#{timestamp}] #{message}\033[0m"
    {% end %}
  end

  def log_socks(message)
    {% if flag?(:debug_socks) %}
      timestamp = Time.local.to_s("%H:%M:%S")
      puts "\033[0;35m[#{timestamp}] SOCKS: #{message}\033[0m"  # Purple/magenta for SOCKS
    {% end %}
  end
{% else %}
  # Silent in release mode
  def log_error(message)
    # No output in release mode
  end

  def log_warn(message)
    # No output in release mode
  end

  def log_debug(message)
    # No output in release mode
  end

  def log_socks(message)
    # No output in release mode
  end
{% end %}