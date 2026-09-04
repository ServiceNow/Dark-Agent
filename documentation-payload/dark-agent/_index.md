+++
title = "Dark Agent"
chapter = true
weight = 100
+++

![logo](/agents/dark-agent/dark.svg?width=600px)

## Summary

Dark Agent is a production-ready Mythic C2 Agent designed for Linux and MacOS systems. Built in Crystal language, it provides comprehensive post-exploitation capabilities through COFF/BOF loading, extensive system commands, and flexible C2 communication options. All network communications use statically-linked OpenSSL for maximum compatibility.

### Core Features

**Agent Architecture:**
- Written in Crystal language for optimal performance
- Static OpenSSL linking (self-contained binary)
- Support for Linux and macOS systems
- Multi-threading for BOF execution and SOCKS handling

**C2 Communication:**
- HTTP and HTTPX (malleable) C2 profiles with domain rotation
- AES-256-CBC encryption with HMAC authentication
- Configurable symmetric jitter for OPSEC
- Realtime mode for interactive operations
- SOCKS proxy support for network pivoting

**Command Capabilities:**
- COFF/BOF loading and execution with extensive built-in Unix commands
- File upload/download with configurable chunk sizes
- Job management (background task execution)
- Dynamic command loading/unloading
- Comprehensive system information gathering

**Built-in Commands:**
- **System Commands**: ps, kill, df, mounts, netstat, routes, uptime, whoami, hostname, env
- **File Operations**: cat, rm, chmod, chown, timestomp, ls
- **Network Tools**: arp, ifconfig, nslookup, portscan, shell
- **Agent Management**: bof_exec, bof_load, bof_list, bof_unload, download, upload, jobs, jobkill, sleep, exit

## Building

### Build Options

Dark Agent provides several build options to customize the payload for your specific needs:

```bash
# Build everything (default) - agent + BOFs with static OpenSSL
./build.sh

# Build only BOFs 
./build.sh -b

# Build debug version (verbose logging)
./build.sh -d

# Build release version (optimized)
./build.sh -r

# Build SOCKS debug version
./build.sh -S

# Specify C2 profile type
./build.sh -p http     # Build with HTTP profile (default)
./build.sh -p httpx    # Build with HTTPX profile (malleable C2)
```

**Build Features:**
- **Static OpenSSL**: All builds include statically-linked OpenSSL for maximum compatibility
- **No Dependencies**: Resulting binary runs on any Linux/macOS system without external libraries
- **Automatic BOF Compilation**: Built-in Unix commands compiled during build process
- **Multi-threading Support**: BOF execution and SOCKS proxy handling use separate threads

### Build Parameters

When creating a payload in Mythic, you can configure the following build parameters:

**Security & Performance:**
- **debug_mode** (Boolean, default: false) - Enables verbose logging to stdout, useful for troubleshooting agent issues  
- **debug_socks** (Boolean, default: false) - Enables SOCKS proxy debug logging for network troubleshooting
- **disable_encryption** (Boolean, default: false) - Disables AES-256-CBC encryption for C2 communications (testing only)
- **disable_ssl_verify** (Boolean, default: true) - Disables SSL certificate validation for development environments

**Communication Behavior:**
- **symmetric_jitter** (Boolean, default: false) - Uses symmetric jitter ranging from (sleep_time ± jitter%) for better OPSEC
- **realtime** (Boolean, default: false) - Immediately sends pending command responses without waiting for sleep interval
- **chunk_size** (Number, default: 512) - Size of file transfer chunks in KB, affects upload/download performance

### Debugging

The debug build provides detailed logging to help with troubleshooting:

1. **Debug Mode**: When enabled (either with `-d` flag or `debug_mode: true` in Mythic):
   - Detailed logging messages are sent to stdout
   - Network requests/responses are logged
   - Internal agent operations are traced
   - Error messages include more context

2. **To build in debug mode**:
   ```bash
   ./build.sh -d -p http   # Debug build with HTTP profile
   ./build.sh -d -p httpx  # Debug build with HTTPX profile
   ```

3. **Running in debug mode**:
   ```bash
   ./output/dark-agent-debug
   ```

Debug output includes:
- C2 profile initialization
- Request/response details
- BOF loading and execution
- Encryption/decryption operations
- Command processing
- Task handling
- File transfer operations

The debug output is essential for developing and testing custom BOFs, troubleshooting C2 connectivity issues, or diagnosing problems with malleable profiles.

## Authors

- Nicholas Romanowski

## Table of Contents

{{% children %}}