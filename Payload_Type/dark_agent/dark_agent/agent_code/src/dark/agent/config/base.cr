require "json"

module Dark::Agent::Config
  # Base abstract class for configuration handling
  abstract class Base
    getter config : JSON::Any

    def initialize(@config : JSON::Any)
    end

    # Abstract methods that must be implemented by concrete subclasses
    abstract def c2_profile : JSON::Any
    abstract def payload_uuid : String
    abstract def sleep_interval : Int32
    abstract def jitter_percent : Int32
    abstract def killdate : String
    abstract def encryption_type : String
    abstract def encryption_key : String
    abstract def decryption_key : String

    # Configuration options that may be in different locations depending on profile
    abstract def symmetric_jitter? : Bool
    abstract def chunk_size : Int32
    abstract def realtime? : Bool
    abstract def disable_ssl_verify? : Bool

    # Common methods that use the abstract methods
    def has_kill_date? : Bool
      !killdate.empty?
    end

    def past_kill_date? : Bool
      return false unless has_kill_date?

      begin
        # Parse the killdate (format: YYYY-MM-DD)
        parts = killdate.split("-")
        if parts.size == 3
          year = parts[0].to_i
          month = parts[1].to_i
          day = parts[2].to_i

          now = Time.local
          kill_date = Time.local(year, month, day)

          return now > kill_date
        end
      rescue
        # If there's any error parsing the date, assume it's not past
      end

      false
    end

    def encryption_enabled? : Bool
      # Get encryption keys and check if they are available
      !encryption_type.empty? && !encryption_key.empty? && !decryption_key.empty?
    end

    # Keep has_encryption? for backwards compatibility
    def has_encryption? : Bool
      encryption_enabled?
    end
  end
end