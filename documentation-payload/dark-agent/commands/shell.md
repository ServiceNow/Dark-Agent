+++
title = "shell"
chapter = false
weight = 100
hidden = false
+++

## Summary

Execute shell commands on the target system with separate command and parameter arguments.

### Arguments

#### Required

- **command**: The shell command to execute (e.g., `ls`, `cat`, `ps`)
- **arguments**: Parameters to pass to the command (e.g., `-la /tmp`, `--help`)

## Usage

The `shell` command allows you to execute arbitrary shell commands on the target system. Unlike other implementations that take a single command string, Dark Agent's shell command accepts the command and its arguments as separate parameters for better parsing and execution.

### Examples

```
shell ls -la /tmp
shell cat /etc/passwd
shell ps aux
shell whoami
```

### Implementation Details

The `shell` command is implemented as a BOF (Beacon Object File) that:

1. Takes multiple arguments through the `bof_args` parameter
2. Joins the command and all its parameters with spaces
3. Executes the full command using `popen()`
4. Returns the command output with proper newline handling

The command uses the `bof_args` parameter to pass arguments directly to the BOF execution framework, eliminating the need to manually call `bof_exec`.

### OPSEC Considerations

- **Process Creation**: This command will spawn new processes on the target system
- **Command History**: Commands may be logged in shell history depending on system configuration  
- **Network Traffic**: Command output is transmitted back to the C2 server
- **Detection**: Process monitoring tools may detect unusual command execution patterns

### Mitre ATT&CK Mapping

- **T1059.004** - Command and Scripting Interpreter: Unix Shell