+++
title = "kill"
chapter = false
weight = 105
hidden = false
+++

## Summary

Terminate a process on the target system by sending a signal to a specified process ID (PID).

### Arguments

#### Required

- **pid** (Number): The process ID of the target process to terminate

#### Optional

- **signal** (Number): The signal number to send to the process (default: 15 - SIGTERM)
  - Common signals:
    - 15 (SIGTERM): Graceful termination (default)
    - 9 (SIGKILL): Forceful termination
    - 2 (SIGINT): Interrupt signal
    - 1 (SIGHUP): Hangup signal

## Usage

The `kill` command allows operators to terminate processes by sending Unix signals. By default, it sends SIGTERM (signal 15) for graceful termination, but can be configured to send other signals including SIGKILL (signal 9) for forceful termination.

### Examples

```
kill 1234
kill 1234 15
kill 1234 9
```

The first example sends SIGTERM to process 1234. The second example explicitly sends SIGTERM (15). The third example sends SIGKILL (9) for forceful termination.

### Implementation Details

The `kill` command is implemented as a BOF (Beacon Object File) that:

1. Validates the provided PID and signal number
2. Checks if the target process exists using `kill(pid, 0)`
3. Sends the specified signal to the target process using the `kill()` system call
4. Provides detailed error reporting for permission issues and process states

### Process Browser Integration

The `kill` command integrates with the Mythic process browser, allowing operators to:
- View running processes through the `ps` command
- Select processes from the browser interface
- Execute kill commands directly from the process list

### Error Handling

The command provides comprehensive error handling for common scenarios:

- **Invalid PID**: Reports when PID is zero or negative
- **Process Not Found**: Reports when the specified process does not exist
- **Permission Denied**: Reports when insufficient privileges to signal the process
- **Invalid Signal**: Reports when signal number is outside valid range (1-64)

### OPSEC Considerations

- **Process Termination**: Terminating processes may be logged by security tools
- **Permission Checks**: The command first checks process existence, which may generate audit logs
- **Signal Selection**: SIGKILL (9) cannot be caught or ignored by processes, making it more obvious
- **Detection**: Security tools may monitor process termination patterns
- **Privilege Requirements**: Some processes may require elevated privileges to terminate

### Mitre ATT&CK Mapping

- **T1489** - Service Stop: Adversaries may stop or disable services on a system to render those services unavailable to legitimate users