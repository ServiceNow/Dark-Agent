+++
title = "jobs"
chapter = false
weight = 12
+++

## Summary

Lists all currently running background jobs and their status.

The `jobs` command displays information about active background processes spawned by BOF commands or other long-running operations. Each job shows its ID, command, status, and runtime information.

## Arguments

None - this command takes no parameters.

## Usage

```bash
jobs
```

## Output

When jobs are running:
```
Active Jobs:
Job ID: 1 | Command: ps -aux | Status: Running | Started: 2024-12-04 15:30:22
Job ID: 2 | Command: netstat -tulpn | Status: Running | Started: 2024-12-04 15:31:05
Job ID: 3 | Command: portscan 192.168.1.0/24 80 | Status: Completed | Started: 2024-12-04 15:25:10

Total: 3 jobs (2 running, 1 completed)
```

When no jobs are active:
```
No active jobs
```

## Job Information

Each job entry contains:

- **Job ID**: Unique identifier for the job (used with `jobkill`)
- **Command**: The original command that was executed
- **Status**: Current state (Running, Completed, Failed, Killed)
- **Started**: Timestamp when the job was initiated
- **Duration**: How long the job has been running (for active jobs)

## Job Status Types

- **Running**: Job is currently executing
- **Completed**: Job finished successfully
- **Failed**: Job terminated with an error
- **Killed**: Job was manually terminated with `jobkill`

## Technical Details

- **Multi-threading**: Jobs run in separate threads to prevent blocking
- **Memory Management**: Completed job output is stored until retrieved
- **Job Limits**: No hard limit on concurrent jobs (system dependent)
- **Cleanup**: Completed jobs remain in list until agent restart

## OPSEC Considerations

- Background jobs continue running even if C2 connection is lost
- Long-running jobs may consume system resources
- Some jobs may create detectable process activity
- Job output is stored in agent memory until retrieved

## Related Commands

- **jobkill**: Terminate a specific job by ID
- **bof_exec**: Many BOF commands run as background jobs
- Individual commands that support background execution

## Examples

Monitor system activity:
```bash
# Start some background tasks
bof_exec ps -ef
bof_exec netstat -tulpn
bof_exec portscan 10.0.0.0/8 22,80,443

# Check their status
jobs
```

Typical output workflow:
```bash
# Start a long-running scan
bof_exec portscan 192.168.0.0/16 80

# Check if it's running
jobs
> Job ID: 5 | Command: portscan 192.168.0.0/16 80 | Status: Running | Started: 2024-12-04 16:45:30

# Wait and check again
jobs
> Job ID: 5 | Command: portscan 192.168.0.0/16 80 | Status: Completed | Started: 2024-12-04 16:45:30
```

## Performance Notes

- **Memory Usage**: Each job stores its complete output
- **System Resources**: Multiple jobs share system CPU and I/O
- **Network Impact**: Job output transmitted via normal C2 channels
- **Cleanup**: Consider manually killing unnecessary long-running jobs

## Troubleshooting

If jobs appear stuck:
1. Check system resource availability
2. Use `jobkill` to terminate unresponsive jobs
3. Monitor for BOF-related errors in debug mode
4. Consider agent restart for cleanup if necessary