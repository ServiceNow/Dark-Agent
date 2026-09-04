+++
title = "mounts"
chapter = false
weight = 5
+++

# mounts

The `mounts` command lists all mounted filesystems on the system, similar to the Unix `mount -l` command.

## Usage

```
mounts
```

### Parameters

None - the command takes no parameters and displays all mounted filesystems.

### Examples

```bash
# List all mounted filesystems
mounts
```

## Output

The command provides comprehensive information about all mounted filesystems:

- Device name or filesystem source
- Mount point path
- Filesystem type
- Mount options (ro, rw, noexec, nosuid, etc.)

### Browser Visualization

When viewed in the Mythic browser interface, the output includes:

- Interactive table with sortable columns
- Device type icons (HDD, memory, network, system)
- Filesystem type color coding
- Security analysis column showing mount security posture
- Security risk indicators (low/medium/high based on mount options)

### Security Analysis

The command automatically analyzes mount options from a red team perspective:

- **EXPLOITABLE** (Green): Read-write filesystems without security restrictions - ideal for exploitation
- **RESTRICTED** (Yellow): Read-write filesystems with some security restrictions - limited exploitation potential  
- **HARDENED** (Red): Filesystems with security restrictions like `noexec`, `nosuid`, `nodev`, or `ro` - difficult to exploit

## MITRE ATT&CK Mapping

- **T1082**: System Information Discovery

## Implementation

This command is implemented as a BOF (Beacon Object File) that:

1. Reads `/proc/mounts` to enumerate all mounted filesystems
2. Extracts mount information including device, mount point, filesystem type, and options
3. Outputs structured JSON data for enhanced browser visualization
4. Provides security analysis of mount options
5. Includes all filesystem types (block devices, pseudo-filesystems, network mounts)

The command provides comprehensive filesystem mount information useful for system reconnaissance and security assessment.