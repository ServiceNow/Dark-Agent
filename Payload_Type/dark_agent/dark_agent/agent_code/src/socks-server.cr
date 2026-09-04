require "socket"
require "option_parser"

# Standalone SOCKS5 server for performance testing
# No Mythic overhead - pure TCP-to-TCP forwarding
class SocksServer
  @listen_port : Int32
  @server_socket : TCPServer?
  
  # Type annotations for class variables
  @@buffer_pool : Array(Bytes) = Array.new(16) { Bytes.new(262144) }
  @@buffer_mutex : Mutex = Mutex.new

  def initialize(@listen_port : Int32)
    puts "SOCKS5 Server initializing on port #{@listen_port}"
  end

  def start
    @server_socket = TCPServer.new(@listen_port)
    puts "SOCKS5 Server listening on port #{@listen_port}"

    # Start multiple accept threads for massive concurrency
    8.times do |i|
      spawn(name: "acceptor-#{i}") do
        puts "[#{Time.utc}] Started acceptor thread #{i}"
        loop do
          if server = @server_socket
            begin
              puts "[#{Time.utc}] Acceptor #{i}: Waiting for connection..."
              client_socket = server.accept
              
              # Get remote address safely before socket might close
              client_addr = begin
                client_socket.remote_address.to_s
              rescue
                "unknown"
              end
              
              puts "[#{Time.utc}] Acceptor #{i}: New SOCKS client connected from #{client_addr}"
              
              # Handle each client in a separate fiber - spawn aggressively
              spawn(name: "client-#{client_addr}") do
                puts "[#{Time.utc}] Started client handler for #{client_addr}"
                handle_client(client_socket)
                puts "[#{Time.utc}] Finished client handler for #{client_addr}"
              end
            rescue ex
              puts "[#{Time.utc}] Acceptor #{i} error: #{ex.message}"
              sleep(0.1)  # Brief pause on error
            end
          end
        end
      end
    end

    # Keep main thread alive
    sleep
  end

  private def handle_client(client : TCPSocket)
    client_addr = begin
      client.remote_address.to_s
    rescue
      "closed-socket"
    end
    begin
      puts "[#{Time.utc}] #{client_addr}: Starting SOCKS handshake"
      
      # SOCKS5 authentication negotiation
      puts "[#{Time.utc}] #{client_addr}: Starting auth negotiation"
      unless handle_auth_negotiation(client)
        puts "[#{Time.utc}] #{client_addr}: Authentication negotiation failed"
        client.close
        return
      end
      puts "[#{Time.utc}] #{client_addr}: Auth negotiation successful"

      # SOCKS5 connection request
      puts "[#{Time.utc}] #{client_addr}: Processing connection request"
      target_socket = handle_connect_request(client)
      unless target_socket
        puts "[#{Time.utc}] #{client_addr}: Connection request failed"
        client.close
        return
      end

      puts "[#{Time.utc}] #{client_addr}: SOCKS connection established, starting forwarding"
      
      # Start bidirectional forwarding
      forward_data(client, target_socket)

    rescue ex
      puts "[#{Time.utc}] #{client_addr}: Error handling client: #{ex.message}"
      puts "[#{Time.utc}] #{client_addr}: Error backtrace: #{ex.backtrace?.try(&.join("\n"))}"
    ensure
      puts "[#{Time.utc}] #{client_addr}: Closing client connection"
      client.close rescue nil
    end
  end

  # Handle SOCKS5 authentication negotiation - OPTIMIZED
  private def handle_auth_negotiation(client : TCPSocket) : Bool
    client_addr = begin
      client.remote_address.to_s
    rescue
      "closed-socket"
    end
    puts "[#{Time.utc}] #{client_addr}: Reading auth header (2 bytes)"
    
    # Read version and number of methods
    buffer = Bytes.new(2)
    unless client.read_fully?(buffer)
      puts "[#{Time.utc}] #{client_addr}: Failed to read auth header"
      return false
    end
    
    version = buffer[0]
    num_methods = buffer[1]
    puts "[#{Time.utc}] #{client_addr}: Version=#{version}, Methods=#{num_methods}"
    
    unless version == 5  # SOCKS5
      puts "[#{Time.utc}] #{client_addr}: Invalid SOCKS version: #{version}"
      return false
    end
    
    # Read authentication methods
    puts "[#{Time.utc}] #{client_addr}: Reading #{num_methods} auth methods"
    methods = Bytes.new(num_methods)
    unless client.read_fully?(methods)
      puts "[#{Time.utc}] #{client_addr}: Failed to read auth methods"
      return false
    end
    
    # Send response immediately: no authentication required
    puts "[#{Time.utc}] #{client_addr}: Sending auth response (no auth required)"
    response = Bytes[5, 0]  # SOCKS5, no auth
    client.write(response)
    # No flush - let TCP optimize
    
    puts "[#{Time.utc}] #{client_addr}: Auth negotiation complete"
    true
  end

  # Handle SOCKS5 connect request and establish target connection
  private def handle_connect_request(client : TCPSocket) : TCPSocket?
    # Read SOCKS5 request header
    header = Bytes.new(4)
    return nil unless client.read_fully?(header)
    
    version = header[0]
    command = header[1]
    reserved = header[2]
    addr_type = header[3]
    
    return nil unless version == 5 && command == 1  # CONNECT command
    
    # Parse target address
    host, port = parse_target_address(client, addr_type)
    return nil unless host && port
    
    puts "[#{Time.utc}] Connecting to #{host}:#{port}"
    
    # Establish connection to target with optimizations and timeout
    begin
      start_time = Time.utc
      puts "[#{Time.utc}] Starting DNS resolution and connection to #{host}:#{port}"
      target_socket = TCPSocket.new(host, port, connect_timeout: 5.seconds)
      end_time = Time.utc
      connection_time = (end_time - start_time).total_milliseconds
      resolved_ip = target_socket.remote_address.address rescue "unknown"
      puts "[#{Time.utc}] Connected to #{host}:#{port} (#{resolved_ip}) in #{connection_time.round(1)}ms"
      
      # Optimize TCP socket settings for maximum performance
      target_socket.tcp_nodelay = true  # Disable Nagle's algorithm
      target_socket.tcp_keepalive_idle = 1
      target_socket.tcp_keepalive_interval = 1
      target_socket.tcp_keepalive_count = 3
      
      # Also optimize client socket
      client.tcp_nodelay = true
      client.tcp_keepalive_idle = 1
      client.tcp_keepalive_interval = 1
      client.tcp_keepalive_count = 3
      
      # Send success response
      send_connect_response(client, true)
      
      return target_socket
    rescue ex
      puts "Failed to connect to #{host}:#{port}: #{ex.message}"
      send_connect_response(client, false)
      return nil
    end
  end

  # Parse target address from SOCKS5 request
  private def parse_target_address(client : TCPSocket, addr_type : UInt8) : {String?, Int32?}
    case addr_type
    when 1  # IPv4
      addr_bytes = Bytes.new(4)
      return {nil, nil} unless client.read_fully?(addr_bytes)
      host = addr_bytes.join(".")
    when 3  # Domain name
      length_byte = Bytes.new(1)
      return {nil, nil} unless client.read_fully?(length_byte)
      domain_length = length_byte[0]
      domain_bytes = Bytes.new(domain_length)
      return {nil, nil} unless client.read_fully?(domain_bytes)
      host = String.new(domain_bytes)
    when 4  # IPv6
      addr_bytes = Bytes.new(16)
      return {nil, nil} unless client.read_fully?(addr_bytes)
      # Simple IPv6 formatting
      segments = [] of String
      addr_bytes.each_slice(2) do |slice|
        hex = slice.map { |b| b.to_s(16).rjust(2, '0') }.join
        segments << hex
      end
      host = segments.join(":")
    else
      return {nil, nil}
    end
    
    # Read port
    port_bytes = Bytes.new(2)
    return {nil, nil} unless client.read_fully?(port_bytes)
    port = (port_bytes[0].to_i32 << 8) | port_bytes[1].to_i32
    
    {host, port}
  end

  # Send SOCKS5 connect response - OPTIMIZED
  private def send_connect_response(client : TCPSocket, success : Bool)
    if success
      # Success response: VER=5, REP=0, RSV=0, ATYP=1, BND.ADDR=0.0.0.0, BND.PORT=0
      response = Bytes[5, 0, 0, 1, 0, 0, 0, 0, 0, 0]
    else
      # General failure: VER=5, REP=1, RSV=0, ATYP=1, BND.ADDR=0.0.0.0, BND.PORT=0
      response = Bytes[5, 1, 0, 1, 0, 0, 0, 0, 0, 0]
    end
    
    client.write(response)
    # No flush - faster handshake
  end

  # Pre-allocated buffers to avoid repeated allocations (moved to class level)
  
  private def get_buffer : Bytes
    @@buffer_mutex.synchronize do
      @@buffer_pool.pop? || Bytes.new(262144)
    end
  end
  
  private def return_buffer(buffer : Bytes)
    @@buffer_mutex.synchronize do
      @@buffer_pool << buffer if @@buffer_pool.size < 16
    end
  end

  # Bidirectional data forwarding between client and target - OPTIMIZED FOR SPEED
  private def forward_data(client : TCPSocket, target : TCPSocket)
    # Client to target forwarding - optimized
    spawn(name: "c2t") do
      buffer = get_buffer
      begin
        total_bytes = 0_i64
        while !client.closed? && !target.closed?
          bytes_read = client.read(buffer)
          break if bytes_read <= 0
          
          total_bytes += bytes_read
          target.write(buffer[0, bytes_read])
          # Remove flush for maximum speed - let TCP handle buffering
        end
        puts "[#{Time.utc}] Client->Target finished: #{total_bytes} bytes transferred" if total_bytes > 1000
      rescue ex
        # Silent error handling
      ensure
        return_buffer(buffer)
        target.close rescue nil
      end
    end

    # Target to client forwarding - optimized
    spawn(name: "t2c") do
      buffer = get_buffer
      begin
        total_bytes = 0_i64
        while !target.closed? && !client.closed?
          bytes_read = target.read(buffer)
          break if bytes_read <= 0
          
          total_bytes += bytes_read
          client.write(buffer[0, bytes_read])
          # Remove flush for maximum speed - let TCP handle buffering
        end
        puts "[#{Time.utc}] Target->Client finished: #{total_bytes} bytes transferred" if total_bytes > 1000
      rescue ex
        # Silent error handling
      ensure
        return_buffer(buffer)
        client.close rescue nil
      end
    end

    # Wait for all forwarding to complete
    while !client.closed? && !target.closed?
      sleep(0.1)
    end
    
    # Cleanup
    client.close rescue nil
    target.close rescue nil
  end

  def stop
    if server = @server_socket
      server.close
      @server_socket = nil
      puts "SOCKS5 Server stopped"
    end
  end
end

# Command line argument parsing
listen_port = 1080

OptionParser.parse do |parser|
  parser.banner = "Usage: socks-server [options]"
  
  parser.on("-p PORT", "--port PORT", "Listen port (default: 1080)") do |port|
    listen_port = port.to_i
  end
  
  parser.on("-h", "--help", "Show help") do
    puts parser
    exit
  end
end

# Start the server
server = SocksServer.new(listen_port)

# Handle Ctrl+C gracefully
Signal::INT.trap do
  puts "\nShutting down SOCKS server..."
  server.stop
  exit
end

server.start