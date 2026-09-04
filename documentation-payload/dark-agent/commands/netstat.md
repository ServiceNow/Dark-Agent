+++
title = "netstat"
chapter = false
weight = 22
+++

## Summary

Displays network connections, routing tables, interface statistics, and listening ports.

The `netstat` command provides comprehensive network information including active connections, listening services, routing configuration, and network interface statistics. This is essential for network reconnaissance and lateral movement planning.

## Arguments

- **options** (string, optional): Command line options for netstat (default: `-tulpn`)

## Usage

```bash
# Default: Show all TCP/UDP listening and established connections
netstat

# Custom options
netstat -rn          # Show routing table
netstat -i           # Show interface statistics  
netstat -a           # Show all connections
netstat -tulpn       # TCP/UDP, listening, numeric, with PIDs
```

## Default Output Format

```bash
netstat
```
```
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:22             0.0.0.0:*               LISTEN      1205/sshd: /usr/sbi
tcp        0      0 127.0.0.1:3306         0.0.0.0:*               LISTEN      1432/mysqld
tcp        0      0 0.0.0.0:80             0.0.0.0:*               LISTEN      1368/apache2
tcp        0      0 0.0.0.0:443            0.0.0.0:*               LISTEN      1368/apache2
udp        0      0 0.0.0.0:53             0.0.0.0:*                           1256/systemd-resolv
```

## Information Provided

**Connection Details:**
- **Protocol**: TCP, UDP, or other
- **Local Address**: IP and port bound locally
- **Foreign Address**: Remote connection endpoint
- **State**: Connection state (LISTEN, ESTABLISHED, etc.)
- **PID/Process**: Process ID and name (if available)

**Network States:**
- **LISTEN**: Service accepting connections
- **ESTABLISHED**: Active connection
- **TIME_WAIT**: Connection recently closed
- **SYN_SENT**: Connection attempt in progress

## Common Options

**All Connections:**
```bash
netstat -a
# Shows all connections including inactive
```

**Routing Table:**
```bash
netstat -rn  
# Shows network routing information
```

**Interface Statistics:**
```bash
netstat -i
# Shows network interface statistics and errors
```

**Numeric Output:**
```bash
netstat -n
# Shows IP addresses instead of resolving hostnames
```

## Reconnaissance Applications

**Service Discovery:**
```bash
netstat -tulpn
# Identify running services and listening ports
```

**Database Services:**
```
tcp  0  0  127.0.0.1:3306  0.0.0.0:*  LISTEN  1432/mysqld
tcp  0  0  127.0.0.1:5432  0.0.0.0:*  LISTEN  1521/postgres
tcp  0  0  127.0.0.1:6379  0.0.0.0:*  LISTEN  1654/redis-server
```

**Web Services:**
```
tcp  0  0  0.0.0.0:80     0.0.0.0:*  LISTEN  1368/apache2
tcp  0  0  0.0.0.0:443    0.0.0.0:*  LISTEN  1368/apache2
tcp  0  0  0.0.0.0:8080   0.0.0.0:*  LISTEN  1789/java
```

**Administrative Services:**
```
tcp  0  0  0.0.0.0:22     0.0.0.0:*  LISTEN  1205/sshd
tcp  0  0  0.0.0.0:3389   0.0.0.0:*  LISTEN  1456/xrdp
```

## Network Topology Discovery

**Internal Connections:**
```bash
netstat -an | grep ESTABLISHED
# Shows active connections to discover network relationships
```

**Routing Information:**
```bash
netstat -rn
```
```
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
0.0.0.0         10.0.1.1        0.0.0.0         UG        0 0          0 eth0
10.0.1.0        0.0.0.0         255.255.255.0   U         0 0          0 eth0
192.168.100.0   10.0.1.254      255.255.255.0   UG        0 0          0 eth0
```

## OPSEC Considerations

**Detection Risk:**
- **Low Profile**: Standard administrative command
- **System Impact**: Read-only operation, minimal resources
- **Logging**: May be logged in process monitoring
- **Timing**: Can run repeatedly with minimal risk

**Information Sensitivity:**
- Reveals internal network architecture
- Shows running services and versions
- Indicates system role and criticality
- May expose backdoors or persistence mechanisms

## Use Cases

**Initial Assessment:**
```bash
netstat -tulpn
# Quick overview of system services
```

**Lateral Movement Planning:**
```bash
netstat -rn
# Identify network segments and routing
```

**Service Enumeration:**
```bash
netstat -tulpn | grep LISTEN
# Focus on listening services only
```

**Connection Monitoring:**
```bash
netstat -tupln | grep :80
# Monitor specific service connections
```

## Security Analysis

**Suspicious Services:**
Look for unusual ports or unexpected services:
```
tcp  0  0  0.0.0.0:4444   0.0.0.0:*  LISTEN  2345/nc
tcp  0  0  0.0.0.0:31337  0.0.0.0:*  LISTEN  2456/backdoor
```

**Internal Services Exposed:**
Services that should be internal only:
```
tcp  0  0  0.0.0.0:3306   0.0.0.0:*  LISTEN  1432/mysqld
# MySQL exposed to all interfaces (potential security issue)
```

**High-Value Targets:**
```
tcp  0  0  0.0.0.0:389    0.0.0.0:*  LISTEN  1234/slapd      # LDAP
tcp  0  0  0.0.0.0:636    0.0.0.0:*  LISTEN  1234/slapd      # LDAPS
tcp  0  0  0.0.0.0:88     0.0.0.0:*  LISTEN  1345/krb5kdc    # Kerberos
```

## Technical Details

- **Implementation**: BOF (Beacon Object File) execution
- **Performance**: May take several seconds for complete output
- **Privileges**: Some information requires elevated privileges
- **Output Size**: Can be large on busy systems

## Error Handling

```bash
netstat -invalid
> Error: invalid option -- 'i'
> Try 'netstat --help' for more information.
```

## Integration with Other Commands

**Complete Network Assessment:**
```bash
hostname        # System identity
ifconfig        # Interface configuration
netstat -tulpn  # Service discovery
netstat -rn     # Routing information
arp             # ARP table
```

**Service Analysis:**
```bash
netstat -tulpn  # Identify services
ps aux          # Process details
lsof            # File handles (if available)
```

## Alternative Commands

- **ss**: Modern replacement for netstat (if available)
- **lsof -i**: Show network file handles
- **nmap localhost**: Port scanning approach
- **/proc/net/tcp**: Direct kernel interface reading