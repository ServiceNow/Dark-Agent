+++
title = "jobkill"
chapter = false
weight = 13
+++

## Summary

Terminates a specific background job by its Job ID.

The `jobkill` command forcibly stops a running background job and cleans up its resources. This is useful for terminating long-running scans, hung processes, or jobs that are no longer needed.

## Arguments

- **job_id** (number, required): The Job ID of the background job to terminate

## Usage

```bash
# Kill job with ID 5
jobkill 5

# Kill multiple jobs
jobkill 1
jobkill 2  
jobkill 3
```

## Output

Successful termination:
```
Job 5 (portscan 192.168.1.0/24 80) terminated successfully
```

Job not found:
```
Error: Job ID 10 not found
```

Job already completed:
```
Job 3 (ps -ef) was already completed
```

## Finding Job IDs

Use the `jobs` command to list active jobs and their IDs:

```bash
jobs
> Active Jobs:
> Job ID: 1 | Command: netstat -tulpn | Status: Running | Started: 2024-12-04 15:30:22
> Job ID: 2 | Command: portscan 10.0.0.0/8 22 | Status: Running | Started: 2024-12-04 15:31:05
> Job ID: 3 | Command: ps -aux | Status: Completed | Started: 2024-12-04 15:25:10

jobkill 1
> Job 1 (netstat -tulpn) terminated successfully
```

## Technical Details

- **Thread Termination**: Attempts graceful thread shutdown first
- **Resource Cleanup**: Frees memory and handles associated with the job
- **Output Preservation**: Partial output from killed jobs is still retrievable
- **Immediate Effect**: Job termination is immediate (no wait period)

## Job States After Termination

Killed jobs change status:
- **Before**: Status: Running
- **After**: Status: Killed

The job entry remains in the jobs list until agent restart.

## OPSEC Considerations

- Termination is immediate and may leave processes in unexpected states
- Some BOF operations may not handle termination gracefully
- System processes spawned by BOFs may continue running independently
- Consider the impact of abrupt termination on system stability

## Use Cases

**Long-running scans:**
```bash
# Start a large network scan
bof_exec portscan 0.0.0.0/0 80,443

# Realize it's too broad, kill it
jobs
jobkill 1
```

**Hung processes:**
```bash
# BOF appears stuck
jobs
> Job ID: 4 | Command: custom_bof | Status: Running | Started: 2024-12-04 14:30:22

# Force termination
jobkill 4
```

**Resource management:**
```bash
# Multiple jobs consuming resources
jobs
jobkill 1
jobkill 2
jobkill 3
```

## Error Scenarios

**Invalid Job ID:**
```bash
jobkill 999
> Error: Job ID 999 not found
```

**Already completed job:**
```bash
jobkill 5
> Job 5 (ps -ef) was already completed
```

**System error during termination:**
```bash
jobkill 2
> Error: Failed to terminate job 2: Thread cleanup failed
```

## Best Practices

1. **Check job status** before killing with `jobs` command
2. **Kill unnecessary jobs** to free system resources
3. **Consider graceful alternatives** if BOF supports clean shutdown
4. **Monitor system impact** after killing critical jobs

## Related Commands

- **jobs**: List all background jobs and their status
- **bof_exec**: Execute BOF commands that may run as background jobs
- Individual BOF commands that spawn long-running processes

## Limitations

- Cannot kill system processes spawned outside BOF framework
- Some BOF operations may not respond to termination signals
- Partial results from killed jobs may be incomplete or corrupted
- Agent restart is the only way to fully clean completed/killed job entries