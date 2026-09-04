+++
title = "HTTPX"
chapter = false
weight = 102
+++

## Summary
Advanced malleable C2 profile with extensive traffic customization and static OpenSSL support.

The HTTPX profile provides comprehensive traffic manipulation capabilities similar to Cobalt Strike malleable C2 profiles. It enables deep customization of HTTP request/response patterns, headers, data transformations, and domain rotation strategies. All HTTPS connections use statically-linked OpenSSL for maximum compatibility and reliability.

### Profile Options

All standard HTTP profile options are supported, plus the following advanced features:

#### Multiple Callback Domains
HTTPX supports specifying multiple callback domains for redundancy and traffic distribution.

#### Domain Rotation Strategy
Two strategies are available for managing multiple domains:
- **Round-Robin**: Rotates through all available domains with each request
- **Fail-Over**: Uses the primary domain until a threshold of failures is reached, then moves to the next domain

#### Failover Threshold
Number of consecutive failures before switching to the next domain in fail-over mode.

#### Raw C2 Configuration
This is where the malleable profile is defined, similar to Cobalt Strike malleable C2 profiles. It allows fine-grained control over HTTP traffic characteristics.

### Malleable Profile Structure

The malleable profile is defined in the `raw_c2_config` section and includes:

#### GET Configuration
- **URIs**: List of URI paths for GET requests
- **Client**: Settings for outbound requests
  - **Headers**: Custom HTTP headers
  - **Message**: Where to place the data (cookie, header, parameter, body)
  - **Transforms**: Transformations to apply to outbound data
- **Server**: Settings for inbound responses
  - **Headers**: Custom HTTP response headers
  - **Transforms**: Transformations to apply to inbound data

#### POST Configuration
Similar structure to GET but for POST requests.

### Supported Message Locations

Data can be positioned in several places:
1. **cookie** - Places data in a cookie header with the specified name
2. **header** - Places data in a custom HTTP header with the specified name
3. **parameter** - Places data in a URL parameter with the specified name
4. **body** - Places data directly in the request body (default for POST)

### Supported Transformations

The following transformations are supported:
1. **base64** - Standard Base64 encoding/decoding
2. **base64url** - URL-safe Base64 encoding/decoding (replacing '+' with '-' and '/' with '_')
3. **xor** - XOR encryption with the provided key value
4. **prepend** - Add the specified string before the data
5. **append** - Add the specified string after the data

### Example Configuration

```json
{
  "raw_c2_config": {
    "name": "jQuery Profile",
    "get": {
      "uris": ["/jquery-3.3.1.min.js", "/jquery-3.3.2.min.js"],
      "client": {
        "headers": {
          "Accept": "text/javascript, application/javascript, */*",
          "Accept-Language": "en-US,en;q=0.9",
          "Referer": "https://example.com/"
        },
        "message": {
          "location": "cookie",
          "name": "SESSID"
        },
        "transforms": [
          { "action": "base64", "value": "" },
          { "action": "prepend", "value": "session=" }
        ]
      },
      "server": {
        "transforms": [
          { "action": "prepend", "value": "/* " },
          { "action": "append", "value": " */" },
          { "action": "base64", "value": "" }
        ]
      }
    },
    "post": {
      "uris": ["/jquery-3.3.1.min.js", "/jquery-3.3.2.min.js"],
      "client": {
        "headers": {
          "Accept": "text/javascript, application/javascript, */*",
          "Content-Type": "application/json"
        },
        "message": {
          "location": "body"
        },
        "transforms": [
          { "action": "base64", "value": "" }
        ]
      },
      "server": {
        "transforms": [
          { "action": "base64", "value": "" }
        ]
      }
    }
  }
}
```

### Using with Mythic

When creating a payload in Mythic with the HTTPX profile, follow these steps:

1. **Select HTTPX Profile**: When creating a new payload, select "HTTPX" from the C2 profile dropdown
2. **Configure Basic Options**:
   - Callback Host/Port: The base domain(s) and port for C2 communications
   - Callback Interval: How often the agent checks in
   - Jitter: Randomization percentage for callback timing
   - Kill Date: When the agent should stop functioning

3. **Upload Malleable Profile**:
   - In the `raw_c2_config` field, click "Upload File" and select your malleable profile JSON
   - An example profile is available at `/Payload_Type/dark_agent/dark_agent/agent_code/httpx-profile-example.json`

4. **Configure Domain Options**:
   - **Multiple Domains**: Add multiple callback domains for redundancy
   - **Domain Rotation**: Select between "round-robin" or "fail-over" strategies
   - **Failover Threshold**: Set consecutive failures before switching domains (for fail-over)

5. **Set Agent Parameters**:
   - **debug_mode**: Enable for verbose logging (see Debugging section)
   - **symmetric_jitter**: Enable for more unpredictable beaconing
   - **realtime**: Configure for interactive operations
   - **disable_ssl_verify**: Enable if using self-signed certificates

The build process automatically detects that you're using the HTTPX profile and creates a self-contained binary with static OpenSSL linking. The resulting payload will use the malleable profile configuration to customize its communications with full TLS support.

### Testing Your Profile

Before deploying to a production environment, you should test your malleable profile:

1. Build with debug_mode enabled
2. Run the agent in a controlled environment
3. Monitor the debug output to verify the profile is working correctly
4. Use network capture tools to confirm traffic matches expected patterns

### Troubleshooting

If your HTTPX profile is not working correctly:

1. Check the debug output for parsing errors
2. Validate your JSON profile syntax
3. Ensure all required fields are present
4. Verify domain configurations match your infrastructure
5. Test transforms individually to identify which might be causing issues

A common issue is incorrect transform ordering - remember that transforms are applied in sequence, and the order matters (especially when combining encoding/encryption operations).