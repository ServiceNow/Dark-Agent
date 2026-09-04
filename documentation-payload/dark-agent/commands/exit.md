+++
title = "exit"
chapter = false
weight = 15
+++

## Summary

Gracefully terminates the Dark Agent process and cleans up resources.

The `exit` command provides a clean shutdown mechanism for the agent, ensuring proper cleanup of memory, file handles, network connections, and background jobs before termination.

## Arguments

None - this command takes no parameters.

## Usage

```bash
exit
```

## Output

```
Agent shutting down gracefully...
Cleaning up resources...
Agent terminated
```

## Shutdown Process

The exit command performs the following cleanup steps:

1. **Stop New Tasks**: Prevents acceptance of new commands
2. **Complete Pending Operations**: Waits for active file transfers to complete
3. **Terminate Background Jobs**: Kills all running BOF jobs
4. **Close Network Connections**: Cleanly closes SOCKS proxy connections
5. **Release Memory**: Frees allocated memory and resources
6. **Process Termination**: Exits the agent process

## Technical Details

- **Graceful Shutdown**: Attempts to complete in-progress operations
- **Timeout Protection**: Will force-exit if cleanup takes too long (30 seconds)
- **Resource Cleanup**: Properly closes all handles and connections
- **No Recovery**: Once executed, the agent cannot be restarted remotely

## Background Job Handling

Active jobs are handled during shutdown:

```bash
jobs
> Job ID: 1 | Command: portscan 10.0.0.0/8 80 | Status: Running
> Job ID: 2 | Command: netstat -tulpn | Status: Running

exit
> Terminating 2 background jobs...
> Job 1 (portscan) terminated
> Job 2 (netstat) terminated  
> Agent shutting down gracefully...
```

## File Transfer Handling

Active transfers are completed if possible:

```bash
# Large download in progress
download /var/log/large_logfile.log
> Downloading chunk 50/200...

exit
> Waiting for active download to complete...
> Download completed: /var/log/large_logfile.log
> Agent shutting down gracefully...
```

## SOCKS Proxy Cleanup

If SOCKS proxy connections are active:

```bash
exit
> Closing 3 active SOCKS connections...
> SOCKS proxy shutdown complete
> Agent shutting down gracefully...
```

## OPSEC Considerations

**Clean Exit:**
- Removes most traces of agent execution from memory
- Properly closes network connections to avoid hanging sockets
- Terminates child processes to avoid orphaned processes

**Process Traces:**
- Agent process disappears from process list
- Temporary files may remain (not automatically cleaned)
- System logs may still contain execution traces

**Network Cleanup:**
- Gracefully closes C2 connections
- Terminates SOCKS proxy sessions properly
- May send final beacon to indicate shutdown

## Operational Use Cases

**Mission Complete:**
```bash
# Objective achieved, clean exit
exit
```

**Detection Response:**
```bash
# Possible detection, immediate shutdown
exit
```

**System Maintenance:**
```bash
# System reboot scheduled, graceful exit
exit
```

**Agent Replacement:**
```bash
# Deploying new agent version
exit
# Deploy new agent
```

## Emergency vs. Graceful Exit

**Graceful Exit (recommended):**
```bash
exit
# Proper cleanup, completes operations
```

**Emergency Exit (system kill):**
```bash
# System admin: kill -9 <agent_pid>
# Immediate termination, no cleanup
```

## Recovery Considerations

After exit, agent recovery requires:

1. **New Deployment**: Agent must be redeployed manually
2. **No Remote Restart**: Cannot be restarted via C2 commands
3. **Persistence Loss**: Any persistence mechanisms must be re-triggered
4. **Session Loss**: All session state and context is lost

## Troubleshooting

**Hung Exit Process:**
If exit doesn't complete within 30 seconds:
- Agent automatically force-exits
- May indicate stuck background jobs or transfers
- Check system resources if this occurs frequently

**Exit Failures:**
```bash
exit
> Error: Critical operation in progress, cannot exit safely
> Retry in 30 seconds or use system kill if necessary
```

## Best Practices

1. **Complete Operations**: Finish important tasks before exiting
2. **Kill Background Jobs**: Use `jobkill` for non-essential jobs before exit
3. **Document Exit Reason**: Note why agent was terminated
4. **Plan Recovery**: Ensure agent can be redeployed if needed
5. **Monitor Cleanup**: Verify proper resource cleanup in debug mode

## Alternative Termination Methods

**System Commands:**
```bash
# From agent (not recommended)
bof_exec kill -TERM $(pgrep dark-agent)

# From system admin
kill <agent_pid>
kill -9 <agent_pid>  # Force kill
```

**System Reboot:**
- Agent terminates with system shutdown
- No graceful cleanup performed
- May leave temporary files or connections

## Related Commands

- **jobs**: Check background jobs before exit
- **jobkill**: Terminate unnecessary jobs before graceful exit
- **socks**: Check active SOCKS connections before exit