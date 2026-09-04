+++
title = "Commands"
chapter = true
weight = 15
pre = "<b>2. </b>"
+++

# Commands

Dark Agent implements commands in two different ways:

1. **Built-in Commands**: Native commands implemented directly in the agent
2. **BOF-based Commands**: Commands implemented as Beacon Object Files (BOFs)

## Command Types

### Built-in Commands

Built-in commands are directly integrated into the agent code and do not require loading separate BOFs. These commands:

- Are always available without needing to load anything
- Have full auto-completion in the Mythic UI
- Include core functionality like file operations and BOF management

### BOF-based Commands

BOF-based commands are implemented as C object files (.o) that are:

- Loaded into memory at runtime using the `bof_load` command
- Executed using either a dedicated command name (for registered BOFs) or the `bof_execute` command
- Flexible and extensible - you can add new commands by creating new BOFs

#### How BOF Commands Work in Mythic

Dark Agent implements a special system where most BOF-based commands have a corresponding Mythic command wrapper. This means:

1. **Auto-complete Method**: Commands like `ls`, `ps`, and `hello` appear in the Mythic UI with proper parameter auto-completion, but they actually load and execute their corresponding BOF in the background

2. **Manual BOF Loading**: You can also manually load any BOF using:
   ```
   bof_load [bof_name]
   ```
   Once loaded, the BOF will be available as a Mythic command with the same name.

3. **Executing BOFs Directly**: For BOFs that don't have a Mythic command wrapper, or for custom BOFs, you can execute them using:
   ```
   bof_execute [bof_name] [args]
   ```

## Available Commands

### Core Built-in Commands

#### Agent Control Commands

| Command | Description | Parameters |
|---------|-------------|------------|
| exit | Exit and terminate the agent | None |
| sleep | Adjust sleep interval and jitter | `seconds`: Sleep time in seconds<br>`jitter`: Jitter percentage (0-100) |

#### File Operations

| Command | Description | Parameters |
|---------|-------------|------------|
| upload | Upload file from C2 server to target | `file`: File ID to upload<br>`remote_path`: Destination path on target |
| download | Download file from target to C2 server | `path`: Source file path on target |
| ls | List directory contents (native implementation) | `filepath`: Directory to list (optional) |

#### BOF Management

| Command | Description | Parameters |
|---------|-------------|------------|
| load | Load a BOF and register it as a Mythic command | `file_id`: Mythic file ID<br>`name`: Name to register |
| unload | Unload a command from memory | `name`: Command name to unload |
| bof_load | Load a BOF into memory without registering | `command`: BOF name<br>`file_id`: Mythic file ID |
| bof_exec | Execute a previously loaded BOF | `name`: BOF name<br>`arguments`: Arguments to pass to BOF |
| bof_unload | Unload a BOF from memory | `name`: BOF name to unload |
| bof_list | List all loaded BOFs | None |
| bof_purge | Remove all BOFs from memory | None |

See [BOF Loading System](/agents/dark-agent/commands/bof_loading) for detailed information about how the loading system works.

#### Network Operations

| Command | Description | Parameters |
|---------|-------------|------------|
| socks | Start or stop a SOCKS proxy server | `port`: Port to listen on<br>`action`: "start" or "stop" (default: "start") |

### BOF-based Commands

Dark Agent includes several pre-built BOFs that are wrapped with Mythic command interfaces for convenience. Each has auto-completion in the Mythic UI but actually loads and executes the corresponding BOF in the background.

| Command | Description | Browser Scripts |
|---------|-------------|----------------|
| shell | Execute shell commands with separate command and parameter arguments | |
| hello | Simple hello world example | |
| ifconfig | Display network interface configuration | |
| netstat | Display network connections and routing tables | |
| portscan | Scan for open ports on target hosts | |
| timestomp | Modify file timestamps | |
| uptime | Show system uptime | |
| whoami | Display current user information | |
| ps | List running processes | Yes |
| nslookup | Perform DNS lookups on comma-separated hostnames with optional nameserver | |
| df | Display filesystem disk space usage | Yes |
| mounts | List all mounted filesystems | Yes |
| coffee | Test BOF execution | |

## Using BOF Commands

### Method 1: Using Auto-Complete Commands

If a BOF has a corresponding Mythic command wrapper, you can use it directly:

```
ls /path/to/directory
```

The agent will automatically:
1. Check if the BOF is loaded, and if not, load it
2. Execute the BOF with the provided arguments
3. Return the results

### Method 2: Manual Loading and Execution

For BOFs without wrappers or custom BOFs:

```
bof_load my_custom_bof
my_custom_bof arg1 arg2
```

Or use `bof_execute` directly:

```
bof_load my_custom_bof
bof_execute my_custom_bof arg1 arg2
```

## Creating Custom BOFs

Dark Agent supports custom BOFs written in C. See the [Creating Custom BOFs](/agents/dark-agent/commands/custom_bofs) section for detailed instructions.

{{% children %}}
