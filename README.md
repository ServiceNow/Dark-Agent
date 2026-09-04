# Dark Agent

![Dark Agent Logo](Payload_Type/dark_agent/dark_agent/mythic/dark.svg)

A production-ready Linux/macOS C2 agent written in Crystal for Mythic framework. Features static OpenSSL linking, comprehensive BOF support, and extensive built-in Unix commands.

## Overview

Dark Agent is a fully-featured Mythic C2 Agent for Linux and macOS environments. Built in Crystal with statically-linked OpenSSL, it provides comprehensive post-exploitation capabilities through COFF/BOF loading, extensive system commands, SOCKS proxy support, and flexible communication profiles.

## Platform Support

| Build | OS | Min glibc | Coverage |
|-------|----|-----------|---------|
| Dynamic | Linux x86_64 | 2.27 | RHEL 8+, Ubuntu 18.04+, Debian 10+ |
| Dynamic | macOS arm64 | N/A | macOS 12+ (Apple Silicon) |

Linux builds have OpenSSL statically linked — no `libssl` dependency on the target. macOS binaries are cross-compiled on Linux via Zig and ad-hoc signed with `rcodesign` (SHA-256 CodeDirectory hashes required by macOS 14+).

## Mythic Configuration

### Agent Configuration

- **Agent Name**: dark
- **Supported OS**: Linux, macOS  
- **File Extension**: bin
- **C2 Profiles**: HTTP, HTTPX (malleable)

**Build Parameters**:
- `debug_mode`: Boolean (default: false) - Enable debug logging and verbose output
- `debug_socks`: Boolean (default: false) - Enable SOCKS proxy debug logging  
- `encryption`: Boolean (default: true) - Enable AES-256-CBC encryption for C2 traffic
- `disable_ssl_verify`: Boolean (default: false) - Skip SSL certificate verification  
- `symmetric_jitter`: Boolean (default: false) - Use symmetric jitter (sleep_time ± jitter%) for better OPSEC
- `realtime`: Boolean (default: false) - Immediately send command responses without waiting for sleep interval
- `chunk_size`: Number (default: 512) - Size of file transfer chunks in KB, affects upload/download performance

**Available Commands**: Extensive built-in commands including system utilities, file operations, network tools, and agent management

**OPSEC Checks**: Dark Agent includes built-in operational security checks for high-risk commands:
- `shell` - All shell commands require approval from another operator
- `sleep` - Sleep intervals < 10 seconds require operator approval (special warning for sleep 0)
- `kill` - All process termination requires operator approval

### C2 Profile Types

#### HTTP Profile
The standard HTTP profile is a simpler implementation that uses regular HTTP requests. It's easier to configure but offers less customization options.

#### HTTPX Profile (Malleable C2)
The HTTPX profile is a more advanced implementation that supports malleable C2 profiles with extensive customization options:

- **Multiple Domains Support**: Configure multiple callback domains with rotation strategies
- **Domain Rotation Strategies**:
  - `round-robin`: Rotates through domains for each request
  - `fail-over`: Switches to next domain after consecutive failures
- **Traffic Transforms**: Apply custom transformations to C2 traffic:
  - Base64/Base64URL encoding
  - XOR encryption
  - Prepend/append custom data
- **Message Placement Options**: Place C2 messages in:
  - HTTP headers
  - URL parameters
  - Cookies
  - Request body
- **Custom Headers**: Define custom HTTP headers for C2 requests

### Installation

1. Copy the this entire repository to your Mythic C2 Server
2. Use `mythic-cli` to install the folder.  `./mythic-cli install folder /path/to/dark-agent`

## Supported Commands

Dark Agent implements commands across two categories: **Built-in Commands** (native Crystal implementations) and **BOF-based Commands** (C object files loaded at runtime).

| Command | Description | Type | Linux | macOS | Browser Scripts | MITRE ATT&CK |
|---------|-------------|------|-------|-------|----------------|--------------|
| bof_exec | Execute a previously loaded BOF with arguments | Built-in | Yes | Yes | | T1059 |
| bof_list | List all currently loaded BOFs | Built-in | Yes | Yes | | |
| bof_load | Load a BOF into memory without registering as command | Built-in | Yes | Yes | | T1129 |
| bof_purge | Remove all BOFs from memory* | Built-in | Yes | Yes | | |
| bof_unload | Unload a specific BOF from memory | Built-in | Yes | Yes | | |
| download | Download file from target system (supports chunked transfers) | Built-in | Yes | Yes | | T1020, T1030, T1041 |
| exit | Terminate the agent | Built-in | Yes | Yes | | |
| jobkill | Kill a running BOF job by task ID | Built-in | Yes | Yes | | |
| jobs | List active BOF jobs with runtime information | Built-in | Yes | Yes | | |
| load | Load a BOF and register it as a Mythic command | Built-in | Yes | Yes | | T1129 |
| ls | List files in a directory with detailed metadata | Built-in | Yes | Yes | Yes | T1083 |
| sleep | Change agent sleep/jitter intervals | Built-in | Yes | Yes | | |
| socks | Start or stop a SOCKS5 proxy server on specified port | Built-in | Yes | Yes | | T1090 |
| unload | Unload a command from memory | Built-in | Yes | Yes | | |
| upload | Upload file to target system | Built-in | Yes | Yes | | T1105 |
| arp | Display ARP table information | BOF | Yes | Yes | Yes | T1016 |
| cat | Display file contents | BOF | Yes | Yes | | T1005 |
| chmod | Change file permissions | BOF | Yes | Yes | | T1222.002 |
| chown | Change file ownership | BOF | Yes | Yes | | T1222.002 |
| coffee | Test BOF execution (example "coffee brewing" command) | BOF | Yes | Yes | | |
| df | Display filesystem disk space usage with mount analysis | BOF | Yes | Yes | Yes | T1082 |
| env | Display environment variables | BOF | Yes | Yes | | T1082 |
| hostname | Display system hostname | BOF | Yes | Yes | | T1082 |
| ifconfig | Display network interface configuration | BOF | Yes | Yes | Yes | T1016 |
| kill | Terminate processes by PID | BOF | Yes | Yes | | T1562.001 |
| krb_dump_kirbi | Dump credentials from a Kerberos credential cache | BOF | | Yes | | T1558.005 |
| krb_listccaches | Enumerate all Kerberos credential caches | BOF | | Yes | | T1558.005 |
| last | Show last logged in users from wtmp log | BOF | Yes | | Yes | T1033 |
| mkdir | Create directory and any necessary parent directories | BOF | Yes | Yes | | T1059 |
| mounts | List all mounted filesystems with security analysis | BOF | Yes | Yes | Yes | T1082 |
| mv | Move or rename files and directories | BOF | Yes | Yes | | T1070.006 |
| netstat | Display network connections and routing tables | BOF | Yes | | Yes | T1049 |
| nslookup | Perform DNS lookups with optional custom nameserver | BOF | Yes | Yes | Yes | T1018 |
| portscan | Scan for open ports on target hosts | BOF | Yes | Yes | | T1046 |
| ps | List running processes with detailed information | BOF | Yes | Yes | Yes | T1057 |
| rm | Remove files and directories | BOF | Yes | Yes | | T1070.004 |
| routes | Display system routing table | BOF | Yes | Yes | Yes | T1016 |
| shell | Execute shell commands on the target system | BOF | Yes | Yes | | T1059.004 |
| timestomp | Modify file timestamps for anti-forensics | BOF | Yes | Yes | | T1070.006 |
| uptime | Show system uptime and load averages | BOF | Yes | Yes | | T1082 |
| whoami | Display current user information | BOF | Yes | Yes | | T1033 |

Each command (like `hostname` and `ifconfig`) is implemented using a BOF file. When you use the command:

1. The command uses `bof_execute` to run the associated BOF
2. If the BOF hasn't been loaded yet, you must first use `load [command]` to load it
3. For example: `load hostname` followed by `hostname`

## Creating Custom BOFs

Writing a BOF is straightforward — include `beacon.h` and implement `coffee()`. The framework handles loading, execution, and sending output back to the operator.

### Minimal Example

```c
#include "../includes/beacon.h"
#include <sys/stat.h>
#include <errno.h>

void coffee(int argc, char **argv) {
    if (argc < 1) { BeaconPrintf("Usage: example <path>"); return; }

    const char *path = argv[0];
    struct stat st;

    // Simple status message
    BeaconPrintf("checking path: %s", path);

    if (stat(path, &st) != 0) {
        BeaconPrintf("error: %s", strerror(errno));
        return;
    }

    // JSON output for browser script rendering
    bof_result_t *r = bof_result_create(512);
    bof_result_append(r, "{");
    bof_field_str(r, "path",  path);
    bof_field_ull(r, "size",  (unsigned long long)st.st_size);
    bof_field_uint(r, "mode", (unsigned int)st.st_mode);
    bof_result_trim(r);
    bof_result_append(r, "}");
    bof_result_send(r);
    bof_result_destroy(r);
}
```

Compile it, drop the `.o` into the payload, load it in Mythic — done.

### Output API

| Function | Output |
|---|---|
| `BeaconOutput(buf, len)` | send raw bytes to the operator |
| `BeaconPrintf("found %d user=%s", n, u)` | status/debug message — supports `%d %s %p %x` |
| `bof_result_append(r, "text")` | `text` |
| `bof_field_str(r, "name", "ls")` | `"name":"ls",` |
| `bof_field_int(r, "pid", 1234)` | `"pid":1234,` |
| `bof_field_uint(r, "uid", 501)` | `"uid":501,` |
| `bof_field_ull(r, "size", 102400)` | `"size":102400,` |
| `bof_field_hex(r, "flags", 0x405)` | `"flags":"0x405",` |
| `bof_result_append_mac(r, mac)` | `aa:bb:cc:dd:ee:ff` |
| `bof_result_trim(r)` | strips trailing comma |
| `bof_result_send(r)` | sends via BeaconOutput |
| `bof_result_destroy(r)` | free |

`BeaconOutput` and `BeaconPrintf` are the most common ways to write data from a BOF. The `bof_result_t` JSON builder is primarily useful when pairing with a Mythic browser script for structured UI rendering.

```c
bof_result_t *r = bof_result_create(4096);
bof_result_append(r, "{\"entries\":[{");
bof_field_str(r,  "name",  proc_name);
bof_field_int(r,  "pid",   pid);
bof_field_ull(r,  "size",  file_size);
bof_field_hex(r,  "flags", flags);
bof_result_trim(r);
bof_result_append(r, "}]}");
bof_result_send(r);
bof_result_destroy(r);
// → {"entries":[{"name":"ls","pid":1234,"size":102400,"flags":"0x405"}]}
```

### Arguments

BOFs receive `(int argc, char **argv)`. Mythic passes arguments two ways:

#### Split Arguments (`bof_args`)
Space-separated → individual `argv` entries:
- `"192.168.1.1 22,80,443"` → `argv[0]="192.168.1.1"`, `argv[1]="22,80,443"`
- Best for BOFs with structured parameters (paths, modes, hosts)
- Example: `portscan 192.168.1.1 22,80,443`

#### Single String (`bof_args_str`)
Full string → `argv[0]`:
- `"ls -latr /tmp"` → `argv[0]="ls -latr /tmp"`
- Best for BOFs that pass a command through as-is
- Example: `shell ls -latr /tmp`

### Building

```bash
# Linux
gcc -fPIC -c your_bof.c -o your_bof.o -I src/bofs/includes

# Build all BOFs (runs inside the Mythic build container)
./build.sh -b    # Linux
./build.sh -B    # macOS (aarch64, requires Zig + macOS SDK)
```

## Usage

### Running the Agent

```bash
# Run the debug version
./output/dark-agent-debug

# Run the release version
./output/dark-agent
```

### Direct Mode

Dark Agent can be built in "direct mode", which creates a standalone COFF loader without any Mythic C2 functionality. This is useful for testing BOFs without needing a full Mythic server.

In direct mode, the agent:
1. Loads the specified COFF file
2. Executes the `coffee()` function from the BOF
3. Passes any additional command-line arguments to the BOF
4. Displays any output produced by the BOF

This mode is ideal for BOF development and testing before deploying to a full Mythic environment.

Example usage:
```bash
# Build direct mode version
./build.sh -D

# Have a cup of COFFee
./output/dark-agent-direct output/bofs/coffee.o
```
