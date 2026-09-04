+++
title = "env"
chapter = false
weight = 23
+++

## Summary

Displays all environment variables and their values for the current process.

The `env` command reveals environment variables that contain valuable system information, user context, application paths, and configuration details. This information is essential for understanding the system environment and potential privilege escalation vectors.

## Arguments

None - this command takes no parameters.

## Usage

```bash
env
```

## Output Format

```
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOME=/home/user
USER=user
SHELL=/bin/bash
PWD=/home/user
LANG=en_US.UTF-8
XDG_SESSION_ID=3
XDG_SESSION_TYPE=x11
DISPLAY=:0
```

## Key Information Categories

**User Context:**
```
USER=webadmin
HOME=/home/webadmin
SHELL=/bin/bash
LOGNAME=webadmin
```

**System Paths:**
```
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LD_LIBRARY_PATH=/usr/local/lib:/usr/lib
PYTHONPATH=/opt/python/lib
```

**Application Configuration:**
```
JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
CATALINA_HOME=/opt/tomcat
MYSQL_ROOT_PASSWORD=secretpassword123
```

**Network and Domain:**
```
HOSTNAME=webserver01.corp.example.com
DOMAIN=corp.example.com
```

## Security-Relevant Variables

**Authentication & Credentials:**
```
SUDO_USER=admin
SSH_AUTH_SOCK=/tmp/ssh-agent.socket
KERBEROS_CONFIG=/etc/krb5.conf
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
```

**Development & Debug:**
```
DEBUG=true
FLASK_ENV=development
NODE_ENV=development
DATABASE_URL=mysql://root:password@localhost/app
```

**Privilege Information:**
```
SUDO_COMMAND=/bin/bash
SUDO_GID=0
SUDO_UID=0
ORIGINAL_USER=normaluser
```

## Reconnaissance Applications

**Credential Discovery:**
```bash
env | grep -i pass
env | grep -i key
env | grep -i secret
env | grep -i token
```

**Path Analysis:**
```bash
env | grep PATH
# Identify custom application paths and potential hijacking opportunities
```

**Application Detection:**
```bash
env | grep -i java
env | grep -i python
env | grep -i node
# Identify installed runtimes and frameworks
```

**Cloud Environment Detection:**
```bash
env | grep -i aws
env | grep -i azure  
env | grep -i gcp
# Detect cloud provider and potential credentials
```

## Common Security Findings

**Exposed Database Credentials:**
```
DATABASE_PASSWORD=admin123
MYSQL_ROOT_PASSWORD=supersecret
POSTGRES_PASSWORD=development
```

**API Keys and Tokens:**
```
API_KEY=sk-1234567890abcdef
SLACK_TOKEN=xoxb-1234-5678-abcdef
GITHUB_TOKEN=ghp_abcdef1234567890
```

**Development Passwords:**
```
ADMIN_PASSWORD=password123
DEFAULT_PASSWORD=changeme
DEV_DB_PASS=testpass
```

**Cloud Credentials:**
```
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AZURE_CLIENT_SECRET=abc123def456
```

## OPSEC Considerations

- **Very Low Profile**: Standard system command
- **No Network Activity**: Local environment only
- **Minimal Resource Usage**: Very fast execution
- **Low Detection Risk**: Rarely monitored or logged

## Privilege Escalation Vectors

**SUDO Context:**
```
SUDO_USER=normaluser
SUDO_UID=1000
SUDO_GID=1000
# Running under sudo, original user identified
```

**Service Account Context:**
```
USER=tomcat
HOME=/opt/tomcat
# Running as service account, check for privilege escalation
```

**Development Environment:**
```
NODE_ENV=development
DEBUG=true
# Development mode may have relaxed security
```

## Application Context Discovery

**Web Applications:**
```
CATALINA_HOME=/opt/tomcat
TOMCAT_USER=tomcat
APACHE_HOME=/etc/apache2
NGINX_CONF=/etc/nginx
```

**Databases:**
```
MYSQL_HOME=/var/lib/mysql
POSTGRES_HOME=/var/lib/postgresql
REDIS_CONF=/etc/redis/redis.conf
```

**Container Environments:**
```
KUBERNETES_SERVICE_HOST=10.96.0.1
DOCKER_HOST=unix:///var/run/docker.sock
CONTAINER_ID=abc123def456
```

## Integration with Other Commands

**Complete Environment Assessment:**
```bash
whoami          # User context
env             # Environment variables
ps aux          # Running processes
netstat -tulpn  # Network services
```

**Credential Search Workflow:**
```bash
env | grep -i pass
env | grep -i key
env | grep -i secret
cat ~/.bashrc   # Shell configuration
cat ~/.profile  # User profile
```

## Technical Details

- **Implementation**: BOF (Beacon Object File) execution
- **Performance**: Very fast, minimal system impact
- **Output Size**: Variable, depends on environment complexity
- **Inheritance**: Shows variables inherited from parent process

## Filtering and Analysis

**Search for Specific Patterns:**
```bash
# Use with grep in post-processing:
env | grep -E "(PASS|KEY|SECRET|TOKEN)"
env | grep -i database
env | grep HOME
```

**Common Interesting Variables:**
- PATH, LD_LIBRARY_PATH (hijacking opportunities)
- HOME, USER (user context)
- Any variable containing passwords or keys
- Application-specific configuration variables

## Error Scenarios

Rarely fails, but possible issues:
```bash
env
> Error: Unable to access environment
# Possible in very restricted containers
```

## Alternative Methods

- `printenv` - Same functionality as env
- `set` - Shows shell variables (may include more than env)
- `export` - Shows exported variables
- `/proc/self/environ` - Direct kernel interface (null-separated)