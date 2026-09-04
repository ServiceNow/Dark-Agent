+++
title = "df"
chapter = false
weight = 5
+++

# df

The `df` command displays filesystem disk space usage information for mounted filesystems, similar to the Unix `df -h` command.

## Usage

```
df
```

### Parameters

None - the command takes no parameters and displays usage for all mounted filesystems.

### Examples

```bash
# Display disk usage for all filesystems
df
```

## Output

The command provides detailed filesystem usage information in both text format and structured JSON for browser visualization:

- Device name or filesystem source
- Mount point
- Filesystem type
- Total space in bytes
- Used space in bytes
- Available space in bytes
- Usage percentage

### Browser Visualization

When viewed in the Mythic browser interface, the output includes:

- Interactive table with sortable columns
- Color-coded usage bars showing disk utilization
- Device type icons (HDD, memory, loop devices)
- Usage percentage highlighting (green < 40%, yellow 40-60%, orange 60-80%, red > 80%)
- Formatted file sizes (automatically converts bytes to KB, MB, GB, TB)

## MITRE ATT&CK Mapping

- **T1082**: System Information Discovery

## Implementation

This command is implemented as a BOF (Beacon Object File) that:

1. Reads `/proc/mounts` to identify mounted filesystems
2. Uses `statvfs()` to get filesystem statistics
3. Filters to show only real filesystems (excludes pseudo filesystems)
4. Outputs structured JSON data for enhanced browser visualization
5. Provides fallback text output for non-browser interfaces

The command focuses on mounted block devices, tmpfs, and devtmpfs filesystems while excluding other pseudo-filesystems to provide relevant disk usage information.