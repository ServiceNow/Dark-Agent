+++
title = "HTTP"
chapter = false
weight = 101
+++

## Summary
Standard HTTP/HTTPS profile for reliable C2 communication with static OpenSSL support.

The HTTP profile provides a robust communication channel using standard HTTP protocols with AES-256-CBC encryption and HMAC authentication. All HTTPS connections use statically-linked OpenSSL for maximum compatibility across systems without external dependencies.

### Profile Options

#### Callback Host
The URL for the redirector or Mythic server. This must include the protocol to use (e.g. `http://` or `https://`).

#### Callback Interval in seconds
Time to sleep between agent check-ins (default: 10).

#### Callback Jitter in percent
Randomize the callback interval within the specified threshold. e.g., if Callback Interval is 10, and jitter is 10%, Dark Agent will call back randomly between 10 and 11 seconds (or between 9 and 11 seconds if symmetric jitter is enabled).

#### Callback Port
The port at which the web server lives (80, 443, etc.)

#### Crypto type
Do not modify from aes256_hmac

#### POST request URI
The path on the web server Dark Agent will talk to

#### HTTP Headers
A dictionary of key-value pairs Dark Agent will use in web requests.

#### Kill Date
The date at which the agent will stop calling back.

#### Performs Key Exchange
Perform encrypted key exchange with Mythic on check-in. Recommended to keep as T for true.

#### Disable SSL Verify
If set to true, SSL certificate validation will be disabled. Useful for testing with self-signed certificates or internal PKI environments.

## Security Features

**Encryption & Authentication:**
- **AES-256-CBC**: Strong symmetric encryption for all C2 traffic
- **HMAC-SHA256**: Message authentication prevents tampering
- **Static OpenSSL**: Self-contained crypto libraries, no dependencies
- **Perfect Forward Secrecy**: Unique session keys for each communication

**SSL/TLS Support:**
- **TLS 1.2/1.3**: Modern TLS protocols supported
- **Certificate Validation**: Full certificate chain validation (configurable)
- **Self-Signed Support**: Can disable validation for testing environments
- **No External Dependencies**: Works without system OpenSSL libraries

#### Additional Configuration Options

Dark Agent HTTP profile supports these behavioral parameters:

#### Symmetric Jitter
When enabled, jitter will be applied both positively and negatively to the callback interval. For example, with a 10 second callback and 20% jitter, callbacks will occur between 8 and 12 seconds apart rather than between 10 and 12 seconds.

#### Realtime Mode
When enabled, the agent will not wait for the callback interval when it has pending messages to send. This significantly reduces latency but increases network traffic.


#### Chunk Size
The size in KB of file transfer chunks for upload/download operations (default: 512KB).

### Using with Mythic

When creating a payload in Mythic with the HTTP profile, follow these steps:

1. **Select HTTP Profile**: When creating a new payload, select "HTTP" from the C2 profile dropdown
2. **Configure Basic Options**:
   - Callback Host/Port: The base domain and port for C2 communications
   - Callback Interval: How often the agent checks in
   - Jitter: Randomization percentage for callback timing
   - Kill Date: When the agent should stop functioning

3. **Set Agent Parameters**:
   - **debug_mode**: Enable for verbose logging (recommended for initial testing)
   - **symmetric_jitter**: Enable for more unpredictable beaconing
   - **realtime**: Configure for interactive operations
   - **disable_ssl_verify**: Enable if using self-signed certificates

The build process will detect that you're using the HTTP profile and create a self-contained binary with static OpenSSL linking.

### Debugging

If you encounter issues with the HTTP profile:

1. Enable debug_mode to see detailed logging
2. Check network connectivity to the callback host
3. Verify firewall rules allow outbound connections on the specified port
4. Look for SSL certificate issues if using HTTPS
5. Examine debug output for any encryption/decryption errors

Debug output will be sent to stdout, which Mythic captures during execution. This information is invaluable for troubleshooting connectivity issues or understanding how the agent is communicating with the C2 server.