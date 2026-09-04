+++
title = "whoami"
chapter = false
weight = 20
+++

## Summary

Displays the current username and user ID information for the agent process.

The `whoami` command shows the effective user context under which the Dark Agent is running. This is essential for understanding privilege level and determining what actions are possible on the target system.

## Arguments

None - this command takes no parameters.

## Usage

```bash
whoami
```

## Output

Standard user context:
```
uid=1000(user) gid=1000(user) groups=1000(user),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),120(lpadmin),131(lxd),132(sambashare)
```

Root context:
```
uid=0(root) gid=0(root) groups=0(root)
```

Service account:
```
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

## Information Provided

- **UID**: Numeric user identifier
- **Username**: Human-readable username 
- **GID**: Primary group identifier
- **Primary Group**: Name of primary group
- **Secondary Groups**: All additional groups with IDs and names

## Use Cases

**Initial Reconnaissance:**
```bash
whoami
# Determine current privilege level
```

**Privilege Escalation Planning:**
```bash
whoami
# Check if already root or need to escalate
```

**Permission Validation:**
```bash
whoami
# Verify expected user context after exploitation
```

**Service Account Identification:**
```bash
whoami
# Determine if running as web server, database, etc.
```

## Privilege Levels

**Standard User:**
- Limited system access
- Home directory permissions
- User-installed applications only

**Privileged User (sudo group):**
- Can escalate with sudo
- Access to administrative commands
- System configuration capabilities

**Root User:**
- Full system access
- All file and process permissions
- Can modify system configurations

**Service Accounts:**
- Limited functional permissions
- Specific service access only
- Often restricted shells

## Related Information

Combine with other commands for complete context:

```bash
whoami
id
groups
```

## OPSEC Considerations

- Command execution is very low profile
- No network activity generated
- Minimal system resource usage
- Safe to run repeatedly

## Technical Details

- **Implementation**: Uses BOF (Beacon Object File) execution
- **Performance**: Near-instantaneous execution
- **Dependencies**: None (uses system calls)
- **Output Format**: Standard Unix format compatible

## Example Scenarios

**Web Application Context:**
```bash
whoami
> uid=33(www-data) gid=33(www-data) groups=33(www-data)
# Agent running in web server context
```

**Database Service Context:**
```bash
whoami  
> uid=114(mysql) gid=121(mysql) groups=121(mysql)
# Agent running as database service
```

**Administrative Context:**
```bash
whoami
> uid=1000(admin) gid=1000(admin) groups=1000(admin),27(sudo),116(docker)
# User with sudo and docker privileges
```

**Root Compromise:**
```bash
whoami
> uid=0(root) gid=0(root) groups=0(root)
# Full system compromise achieved
```

## Error Scenarios

Generally very reliable, but possible issues:

```bash
whoami
> Error: Unable to retrieve user information
# Possible on heavily restricted systems
```

## Integration with Other Commands

**Security Assessment Workflow:**
```bash
whoami          # Check current user
ps              # Check running processes  
df              # Check filesystem access
netstat         # Check network permissions
```

**Privilege Escalation Workflow:**
```bash
whoami          # Starting privilege level
# <attempt escalation>
whoami          # Verify escalation success
```

## Alternative Commands

Similar information available through:
- `id` - More detailed user/group information
- `env | grep USER` - Environment variable approach
- `ps` - Process owner information