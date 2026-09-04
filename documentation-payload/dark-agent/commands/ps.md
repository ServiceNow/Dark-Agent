+++
title = "ps"
chapter = false
weight = 100
hidden = false
+++

## Summary

List running processes on the target system with PID, PPID, process name, and state information.

### Arguments

#### Required

None - the `ps` command takes no arguments.

## Usage

The `ps` command provides a process listing similar to the standard Unix `ps` command. It displays running processes in a formatted table showing process ID, parent process ID, process name, and current state.

### Examples

```
ps
```

### Implementation Details

The `ps` command is implemented as a BOF (Beacon Object File) that:

1. Reads the `/proc` filesystem to enumerate running processes
2. Parses `/proc/[pid]/status` files to extract process information
3. Formats the output in a readable table format
4. Returns process details including PID, PPID, name, and state

### Output Format

```
PID      PPID     NAME             STATE   
---      ----     ----             -----   
1        0        systemd          S
2        0        kthreadd         S
3        2        rcu_gp           I
...
```

### OPSEC Considerations

- **File System Access**: This command reads multiple files from `/proc` filesystem
- **Process Enumeration**: May trigger security tools that monitor process enumeration
- **Network Traffic**: Process list data is transmitted back to the C2 server
- **Detection**: Security tools may detect repeated `/proc` filesystem access patterns

### Mitre ATT&CK Mapping

- **T1057** - Process Discovery