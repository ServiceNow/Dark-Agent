+++
title = "sleep"
chapter = false
weight = 14
+++

## Summary

Dynamically changes the agent's callback interval and jitter percentage during runtime.

The `sleep` command allows operators to modify the agent's beaconing behavior without rebuilding or redeploying the payload. This is essential for operational security and adapting to different network conditions.

## Arguments

- **interval** (number, required): New callback interval in seconds
- **jitter** (number, optional): New jitter percentage (0-100), defaults to current jitter if not specified

## Usage

```bash
# Change sleep to 30 seconds, keep current jitter
sleep 30

# Change sleep to 60 seconds with 25% jitter  
sleep 60 25

# Set aggressive polling (1 second intervals)
sleep 1 0

# Set very slow beaconing (10 minutes)
sleep 600 10
```

## Output

```
Sleep interval updated: 30 seconds, jitter: 15%
Previous: 10 seconds, jitter: 10%
Next beacon will use new timing
```

## Timing Behavior

The new timing takes effect immediately after the command response:

```bash
# Current: 10s interval, 20% jitter (8-12 second actual intervals)
sleep 5 0
# Next beacon: exactly 5 seconds
# All subsequent beacons: exactly 5 seconds (no jitter)
```

## Technical Details

- **Immediate Effect**: New timing applies to the very next beacon
- **Jitter Calculation**: Applied according to `symmetric_jitter` build parameter
- **Interrupt Capability**: Can interrupt current sleep cycle immediately
- **Realtime Override**: Realtime mode still bypasses sleep when responses are pending

## Jitter Types

**Standard Jitter** (symmetric_jitter=false):
```bash
sleep 10 20
# Actual intervals: 10.0 to 12.0 seconds
```

**Symmetric Jitter** (symmetric_jitter=true):
```bash
sleep 10 20  
# Actual intervals: 8.0 to 12.0 seconds
```

## OPSEC Considerations

**Stealth Profiles:**
```bash
# Blend with normal web traffic
sleep 300 30    # 5 minutes ± 30%

# Mimic scheduled tasks
sleep 3600 5    # 1 hour ± 5%

# Very low profile
sleep 1800 50   # 30 minutes ± 50%
```

**Interactive Operations:**
```bash
# Fast response for active sessions
sleep 1 0       # 1 second, no jitter

# Moderate interactive
sleep 5 10      # 5 seconds ± 10%
```

**Network Adaptation:**
```bash
# High-latency networks
sleep 30 20

# Low-latency networks  
sleep 5 15

# Unreliable networks
sleep 10 50     # Large jitter for irregular timing
```

## Operational Scenarios

**Initial Deployment:**
```bash
# Start conservative
sleep 300 40    # 5 minutes with high jitter
```

**Active Engagement:**
```bash
# Switch to interactive
sleep 3 0       # Fast response for shell/tools

# Return to stealth when done
sleep 1800 30   # 30 minutes
```

**Detection Evasion:**
```bash
# Detected regular beacons? Add randomness
sleep 120 75    # 2 minutes with 75% jitter

# Very irregular timing
sleep 600 90    # 10 minutes ± 90%
```

## Special Values

**Polling Mode:**
```bash
sleep 0
# Agent polls continuously (no sleep)
# WARNING: Very high network activity
```

**Maximum Stealth:**
```bash
sleep 86400 20  # 24 hours ± 20%
# One beacon per day with variance
```

## Error Handling

**Invalid intervals:**
```bash
sleep -5
> Error: Interval must be positive

sleep abc
> Error: Invalid interval format
```

**Invalid jitter:**
```bash
sleep 10 150
> Error: Jitter must be 0-100%

sleep 10 -20
> Error: Jitter cannot be negative
```

## Sleep Interruption

The agent can interrupt sleep cycles for immediate config changes:

```bash
# Agent is sleeping for 10 minutes
# New sleep command received
sleep 5
# Current sleep interrupted, new 5-second interval starts immediately
```

## Performance Impact

**Network Considerations:**
- Lower intervals = more network traffic
- Higher jitter = more unpredictable patterns
- Consider bandwidth limitations

**System Impact:**
- Very low intervals may impact performance
- Zero sleep (polling) uses significant CPU
- Balance responsiveness vs. system load

## Related Features

- **Realtime Mode**: Bypasses sleep when responses are pending
- **Symmetric Jitter**: Changes how jitter percentage is calculated
- **Sleep Interrupt**: Internal mechanism for immediate timing changes

## Best Practices

1. **Start Conservative**: Begin with longer intervals, reduce as needed
2. **Use Jitter**: Always use some jitter unless specific timing required
3. **Adapt to Network**: Adjust based on connection quality and detection risk
4. **Document Changes**: Track timing changes for operational awareness
5. **Return to Stealth**: Switch back to longer intervals after interactive operations