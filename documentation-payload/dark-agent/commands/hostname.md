+++
title = "hostname"
chapter = false
weight = 21
+++

## Summary

Displays the system hostname and domain information.

The `hostname` command reveals the network identity of the compromised system, including computer name, domain membership, and FQDN information. This is crucial for understanding network topology and system identification.

## Arguments

None - this command takes no parameters.

## Usage

```bash
hostname
```

## Output

**Standalone System:**
```
webserver01
```

**Domain-Joined System:**
```
webserver01.corp.example.com
```

**Cloud Instance:**
```
ip-10-0-1-45.us-west-2.compute.internal
```

## Information Provided

The hostname command provides:
- **Short Hostname**: Computer name only
- **FQDN**: Fully Qualified Domain Name (if configured)
- **Domain Suffix**: Domain/organization identifier

## Use Cases

**Network Reconnaissance:**
```bash
hostname
# Identify system role and network position
```

**Domain Discovery:**
```bash
hostname
# Determine if system is domain-joined
# Example: srv01.corp.acme.com reveals domain
```

**Cloud Environment Detection:**
```bash
hostname
# Cloud providers often use predictable naming
# AWS: ip-10-0-1-45.us-west-2.compute.internal
# Azure: vm-web-001.cloudapp.net
```

**System Role Identification:**
```bash
hostname
# Common patterns reveal function:
# webserver01, db-primary, mail-exchange
```

## Network Intelligence

**Corporate Environments:**
```bash
hostname
> sql01.finance.corp.acme.com
# Reveals: SQL server in finance department of acme.com
```

**Development Environments:**
```bash
hostname  
> dev-api-staging.internal.company.net
# Reveals: Development/staging environment
```

**Infrastructure Naming:**
```bash
hostname
> lb-prod-web-01.datacenter.example.org
# Reveals: Load balancer, production, web tier
```

## OPSEC Considerations

- **Very Low Profile**: Standard system query
- **No Network Activity**: Local system call only
- **Minimal Logging**: Rarely logged or monitored
- **Safe Execution**: No system impact

## Technical Details

- **Implementation**: BOF (Beacon Object File) execution
- **Performance**: Instantaneous execution
- **Source**: System hostname configuration
- **Format**: Standard hostname output format

## Hostname Patterns

**Corporate Patterns:**
- `<role><number>.<department>.<company>.com`
- `<env>-<service>-<instance>.<domain>`
- `<location>-<function>-<tier><number>`

**Cloud Patterns:**
- AWS: `ip-<private-ip>.<region>.compute.internal`
- Azure: `<vmname>.<cloudapp>.net`
- GCP: `<instance-name>.<zone>.c.<project>.internal`

## Integration with Network Discovery

**Complete Network Context:**
```bash
hostname        # System identity
ifconfig        # Network interfaces
route          # Network routing
nslookup       # DNS resolution
```

**Domain Environment Assessment:**
```bash
hostname        # Domain membership
env            # Domain-related environment variables
cat /etc/resolv.conf  # DNS configuration
```

## Error Scenarios

Rare but possible:

```bash
hostname
> Error: Unable to retrieve hostname
# Possible on misconfigured systems
```

**Temporary Hostname Issues:**
```bash
hostname
> localhost
# May indicate configuration problems
```

## Security Implications

**Information Disclosure:**
- Reveals organizational naming conventions
- Indicates system purpose and criticality
- Shows network architecture patterns
- May reveal geographic location

**Attack Planning:**
- Helps identify high-value targets
- Reveals network segmentation
- Indicates system relationships
- Guides lateral movement planning

## Example Intelligence Gathering

**Database Server Discovery:**
```bash
hostname
> prod-mysql-master.db.corp.company.com
# High-value target identified
```

**Development Environment:**
```bash
hostname
> dev-web-01.staging.internal
# Lower security, potential staging data access
```

**Network Infrastructure:**
```bash
hostname
> fw-dmz-01.network.corp.company.com  
# Network security device identified
```

## Related Commands

Combine for comprehensive system identification:

```bash
hostname        # System name
whoami          # User context  
uname -a        # OS information
ifconfig        # Network configuration
```

## Alternative Methods

Other ways to get hostname information:
- `uname -n` - Node name (often same as hostname)
- `cat /etc/hostname` - Hostname configuration file
- `echo $HOSTNAME` - Environment variable (if set)