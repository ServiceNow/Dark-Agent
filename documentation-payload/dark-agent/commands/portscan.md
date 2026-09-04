+++
title = "portscan"
chapter = false
weight = 24
+++

## Summary

Performs TCP port scanning against specified targets to discover open services.

The `portscan` command conducts network reconnaissance by testing connectivity to specified ports on target systems. This is essential for lateral movement planning and network service discovery.

## Arguments

- **target** (string, required): IP address, hostname, or CIDR network range
- **ports** (string, required): Comma-separated port list or ranges (e.g., "22,80,443" or "1-1000")

## Usage

```bash
# Single host, specific ports
portscan 192.168.1.10 22,80,443,3389

# Network range, common ports  
portscan 10.0.1.0/24 21,22,23,25,53,80,110,135,139,443,445,993,995

# Single host, port range
portscan 192.168.1.50 1-1000

# Multiple specific hosts
portscan 192.168.1.1 80,443
portscan 192.168.1.2 80,443
portscan 192.168.1.3 80,443
```

## Output Format

```bash
portscan 192.168.1.10 22,80,443,3389
```

**Open Ports Found:**
```
Port Scan Results for 192.168.1.10:
22/tcp   open    ssh
80/tcp   open    http
443/tcp  open    https
3389/tcp closed  rdp

Scan completed: 4 ports scanned, 3 open, 1 closed
```

**No Open Ports:**
```
Port Scan Results for 192.168.1.99:
22/tcp   closed  ssh
80/tcp   closed  http
443/tcp  closed  https

Scan completed: 3 ports scanned, 0 open, 3 closed
```

## Port Scan Types

**Common Service Ports:**
```bash
portscan 192.168.1.0/24 22,80,443
# SSH, HTTP, HTTPS discovery
```

**Database Ports:**
```bash
portscan 192.168.1.0/24 1433,1521,3306,5432,6379,27017
# SQL Server, Oracle, MySQL, PostgreSQL, Redis, MongoDB
```

**Windows Services:**
```bash
portscan 192.168.1.0/24 135,139,445,3389,5985,5986
# RPC, NetBIOS, SMB, RDP, WinRM
```

**Web Application Ports:**
```bash
portscan 192.168.1.0/24 8080,8443,9090,9443,8000,8888
# Common web application ports
```

## Network Discovery Scenarios

**Initial Network Reconnaissance:**
```bash
# Discover web services
portscan 10.0.0.0/8 80,443,8080,8443

# Discover SSH access
portscan 172.16.0.0/12 22

# Discover Windows systems
portscan 192.168.1.0/24 135,139,445,3389
```

**Service-Specific Discovery:**
```bash
# Database hunting
portscan 10.10.10.0/24 1433,3306,5432,1521

# Mail server discovery
portscan 192.168.0.0/16 25,110,143,993,995

# Management interface discovery
portscan 172.16.1.0/24 8080,9090,8443,9443
```

## Technical Details

- **Implementation**: Custom BOF with socket programming
- **Performance**: Concurrent scanning for faster results
- **Timeouts**: Configurable connection timeouts (default: 3 seconds)
- **Background Execution**: Runs as background job for large scans

## OPSEC Considerations

**Detection Risk:**
- **Network Logging**: Connections may be logged by firewalls/IDS
- **Service Logs**: Failed connections logged by target services  
- **Timing**: Rapid consecutive connections may trigger alerts
- **Pattern Recognition**: Sequential port scans have distinctive patterns

**Stealth Options:**
```bash
# Smaller ranges to avoid detection
portscan 192.168.1.10 80,443
# Instead of: portscan 192.168.1.10 1-65535

# Target specific services
portscan 192.168.1.0/24 22
# Instead of: portscan 192.168.1.0/24 1-1000
```

## Performance Considerations

**Large Network Scans:**
```bash
# This will take significant time and create many connections:
portscan 10.0.0.0/8 1-1000
# Consider smaller ranges or specific ports
```

**Background Job Management:**
```bash
# Start scan
portscan 192.168.0.0/16 80,443

# Check progress
jobs

# Kill if needed
jobkill 1
```

## Common Port Lists

**Top 100 Ports:**
```bash
portscan target 7,9,13,21,22,23,25,26,37,53,79,80,81,88,106,110,111,113,119,135,139,143,144,179,199,389,427,443,444,445,465,513,514,515,543,544,548,554,587,631,646,873,990,993,995,1025,1026,1027,1028,1029,1110,1433,1720,1723,1755,1900,2000,2001,2049,2121,2717,3000,3128,3306,3389,3986,4899,5000,5009,5051,5060,5101,5190,5357,5432,5631,5666,5800,5900,6000,6001,6646,7070,8000,8008,8009,8080,8081,8443,8888,9100,9999,10000,32768,49152,49153,49154,49155,49156,49157
```

**Web Services Only:**
```bash
portscan target 80,443,8000,8080,8443,8888,9090,9443
```

**Database Services:**
```bash  
portscan target 1433,1521,3306,5432,6379,27017,28017
```

## Error Handling

**Network Unreachable:**
```
Error: Network unreachable for target 192.168.99.0/24
```

**Invalid Target:**
```
Error: Invalid IP address or hostname: invalid.target
```

**Invalid Port Range:**
```
Error: Invalid port specification: abc-def
```

## Integration with Other Commands

**Complete Network Assessment:**
```bash
# Network discovery
portscan 192.168.1.0/24 22,80,443

# Service enumeration
netstat -tulpn           # Local services
arp                      # Local ARP table
route                    # Network routing
```

**Lateral Movement Planning:**
```bash
# Discover targets
portscan 192.168.1.0/24 22,3389,5985

# Assess current system
whoami                   # Current privileges
netstat -tulpn          # Local services for pivoting
```

## Security Analysis

**High-Value Targets:**
```bash
# Domain controllers
portscan 192.168.1.0/24 88,389,636,3268,3269

# Database servers  
portscan 10.10.10.0/24 1433,3306,5432

# Infrastructure services
portscan 172.16.0.0/16 22,23,80,161,443,623
```

## Alternative Approaches

- **nmap**: Full-featured port scanner (if available on target)
- **nc (netcat)**: Manual connection testing
- **telnet**: Basic connectivity testing
- **curl/wget**: HTTP service testing