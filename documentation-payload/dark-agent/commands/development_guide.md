+++
title = "Command Development Guide"
chapter = false
weight = 100
+++

# Dark Agent Command Development Guide

This guide explains how to add new commands to Dark Agent, both as built-in commands in the agent and as Mythic UI command wrappers. We'll cover both approaches with examples from the existing codebase.

## Command Development Overview

Dark Agent supports two main types of commands:

1. **Built-in Commands**: Native commands implemented directly in the agent's Crystal code
2. **BOF-based Commands**: Commands implemented as C Beacon Object Files (BOFs)

Both types require:
- Implementation in the agent code (Crystal or C)
- A Python wrapper in the Mythic UI

## Adding a New Built-in Command

### Step 1: Implement the Command in Crystal

Create a new command class in the `src/dark/agent/commands/` directory named `your_command.cr`:

```crystal
require "./base"

module Dark::Agent::Commands
  class YourCommand < Base
    def name : String
      "your_command_name"
    end

    def execute(task : JSON::Any) : Nil
      task_id = task["id"]?.try(&.as_s) || ""
      
      # Extract parameters from the task JSON
      param1 = task["parameters"]["param1"]?.try(&.as_s) || ""
      param2 = task["parameters"]["param2"]?.try(&.as_i) || 0
      
      # Validate parameters
      if param1.empty?
        MessageHandler.add_response(task_id, :error, "Parameter 1 is required")
        return
      end
      
      # Implement your command logic
      begin
        result = do_something(param1, param2)
        MessageHandler.add_response(task_id, :success, "Command completed: #{result}")
      rescue ex
        MessageHandler.add_response(task_id, :error, "Command failed: #{ex.message}")
      end
    end

    private def do_something(param1 : String, param2 : Int32) : String
      # Your implementation here
      "Processed #{param1} with value #{param2}"
    end
  end
end
```

The command will be automatically registered by the command system through Crystal macros when the agent starts.

### Step 2: Create a Mythic Command Wrapper

Create a new Python file in the `mythic/agent_functions/` directory named `your_command_name.py`:

```python
from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *
import json

class YourCommandArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="param1",
                cli_name="param1",
                display_name="Parameter 1",
                type=ParameterType.String,
                description="Description of parameter 1",
                parameter_group_info=[
                    ParameterGroupInfo(
                        required=True,
                        group_name="Default",
                        ui_position=1
                    )
                ]
            ),
            CommandParameter(
                name="param2",
                cli_name="param2",
                display_name="Parameter 2",
                type=ParameterType.Number,
                description="Description of parameter 2",
                parameter_group_info=[
                    ParameterGroupInfo(
                        required=False,
                        group_name="Default",
                        ui_position=2
                    )
                ]
            ),
        ]

    async def parse_arguments(self):
        if len(self.command_line) == 0:
            return
        if self.command_line[0] == "{":
            self.load_args_from_json_string(self.command_line)
        else:
            # Parse arguments from command line
            parts = self.command_line.split()
            if len(parts) > 0:
                self.add_arg("param1", parts[0])
            if len(parts) > 1:
                self.add_arg("param2", int(parts[1]))

class YourCommandCommand(CommandBase):
    cmd = "your_command_name"
    needs_admin = False
    help_cmd = "your_command_name [param1] [param2]"
    description = "Description of your command"
    version = 1
    author = "Your Name"
    argument_class = YourCommandArguments
    attackmapping = ["T1000"]  # MITRE ATT&CK techniques
    attributes = CommandAttributes(
        builtin=True  # Set to True for built-in commands
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
        )
        
        # Set display parameters for the Mythic UI
        param1 = taskData.args.get_arg("param1")
        param2 = taskData.args.get_arg("param2", 0)
        response.DisplayParams = f"{param1} {param2}"
        
        return response

    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)
        return resp
```

## Adding a New BOF-based Command

For a detailed understanding of how the BOF loading system works internally, see the [BOF Loading System](/agents/dark-agent/commands/bof_loading) documentation.

### Step 1: Create the BOF in C

Create a new C file in `src/bofs/` named `your_bof.c`:

```c
#include "includes/beacon.h"
#include <string.h>

void coffee() {
    // Simple example - BOFs in Dark Agent use the coffee() entry point
    BeaconPrintf("Your BOF is executing!");
    
    // For string formatting, convert all values to strings first
    char buffer[256];
    snprintf(buffer, sizeof(buffer), "Processing at %d", 12345);
    BeaconPrintf("Status: %s", buffer);
    
    // Output raw data
    const char data[] = "Raw binary data";
    BeaconOutput((char*)data, sizeof(data) - 1);
}
```

**Note:** Dark Agent BOFs use a simplified API without complex argument parsing. Arguments are typically handled by the Python wrapper and passed as simple parameters.

Compile your BOF:
```bash
gcc -fPIC -c src/bofs/your_bof.c -o output/bofs/your_bof.o -I src/bofs/includes
```

Or use the build script:
```bash
./build.sh -b
```

### Step 2: Create a Mythic Command Wrapper

Create a new Python file in the `mythic/agent_functions/` directory named `your_bof.py`:

```python
from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *

class YourBofArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass

class YourBofCommand(CommandBase):
    cmd = "your_bof"
    needs_admin = False
    help_cmd = "your_bof [args]"
    description = "Description of your BOF command"
    version = 1
    author = "Your Name"
    attackmapping = []
    argument_class = YourBofArguments
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.Linux]
    )
```

## Examples from Existing Commands

### Example 1: Simple Built-in Command - Sleep

The `sleep` command in Dark Agent is a good example of a simple built-in command:

**Command Handler (Crystal):**
```crystal
register_command("sleep") do |args|
  log_debug("Processing sleep command")

  sleep_time = args["parameters"]?.try(&.["seconds"]?.try(&.as_i)) || 0
  jitter = args["parameters"]?.try(&.["jitter"]?.try(&.as_i)) || 0

  if sleep_time < 0
    raise "Invalid sleep time: must be a non-negative integer"
  end

  if jitter < 0 || jitter > 100
    raise "Invalid jitter: must be between 0 and 100"
  end

  log_debug("Setting sleep_time: #{sleep_time}s, jitter: #{jitter}%")

  # Update the global sleep settings
  transport = Dark::Agent::Transport::Active.instance
  transport.sleep_time = sleep_time
  transport.jitter = jitter

  msg = nil
  if sleep_time == 0
    msg = "Sleep interval disabled (set to 0s)"
  elsif jitter > 0
    msg = "Sleep interval updated to #{sleep_time}s with #{jitter}% jitter"
  else
    msg = "Sleep interval updated to #{sleep_time}s"
  end

  log_debug(msg)
  next msg
end
```

**Mythic Wrapper (Python):**
```python
from mythic_container.MythicCommandBase import *

class SleepArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="seconds",
                cli_name="Seconds",
                display_name="Sleep Time (seconds)",
                type=ParameterType.Number,
                description="Number of seconds between beacons (0 for polling mode)",
                parameter_group_info=[
                    ParameterGroupInfo(
                        required=True,
                        group_name="Default",
                        ui_position=1
                    )
                ],
                default_value=10
            ),
            CommandParameter(
                name="jitter",
                cli_name="Jitter",
                display_name="Jitter (%)",
                type=ParameterType.Number,
                description="Percentage of jitter for randomizing sleep time (0-100)",
                parameter_group_info=[
                    ParameterGroupInfo(
                        required=False,
                        group_name="Default",
                        ui_position=2
                    )
                ],
                default_value=10
            )
        ]

    async def parse_arguments(self):
        if len(self.command_line) == 0:
            return
        if self.command_line[0] == "{":
            self.load_args_from_json_string(self.command_line)
        else:
            parts = self.command_line.split()
            if len(parts) > 0:
                self.add_arg("seconds", int(parts[0]))
            if len(parts) > 1:
                self.add_arg("jitter", int(parts[1]))

class SleepCommand(CommandBase):
    cmd = "sleep"
    needs_admin = False
    help_cmd = "sleep [seconds] [jitter %]"
    description = "Adjust the sleep interval and jitter percentage for the agent"
    version = 1
    author = "nicholas.romanowski@servicenow.com"
    argument_class = SleepArguments
    attributes = CommandAttributes(
        builtin=True
    )
```

### Example 2: File Operation Command - Upload

The `upload` command demonstrates more complex parameter handling and file operations:

**Command Handler (Crystal):**
```crystal
register_command("upload") do |args|
  file_id = args["parameters"]["file"]?.try(&.as_s) || ""
  remote_path = args["parameters"]["remote_path"]?.try(&.as_s) || ""
  task_id = args["id"]?.try(&.as_s) || ""

  if file_id.empty?
    raise "No file specified for upload"
  end

  if remote_path.empty?
    raise "No destination path specified"
  end

  log_debug("Starting upload of file_id #{file_id} to #{remote_path}")

  # Send initial notification to Mythic UI
  MessageHandler.add_task_info(task_id, "Starting upload to #{remote_path}\n")

  # Implementation details omitted for brevity...

  next "Uploaded file to #{remote_path} successfully"
end
```

**Mythic Wrapper (Python):**
```python
from mythic_container.MythicCommandBase import *
import json
from mythic_container.MythicRPC import *

class UploadArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="file",
                cli_name="File",
                display_name="File",
                type=ParameterType.File,
                description="File to upload to the target",
                parameter_group_info=[
                    ParameterGroupInfo(
                        required=True,
                        group_name="Default",
                        ui_position=1
                    )
                ]
            ),
            CommandParameter(
                name="remote_path",
                cli_name="Path",
                display_name="Destination Path",
                type=ParameterType.String,
                description="Required: Path on target where to save the file.",
                parameter_group_info=[
                    ParameterGroupInfo(
                        required=True,
                        group_name="Default",
                        ui_position=2
                    )
                ]
            ),
        ]

    async def parse_arguments(self):
        if len(self.command_line) == 0:
            raise Exception("Require arguments.")
        if self.command_line[0] != "{":
            raise Exception("Require JSON blob, but got raw command line.")
        self.load_args_from_json_string(self.command_line)

class UploadCommand(CommandBase):
    cmd = "upload"
    needs_admin = False
    help_cmd = "upload (modal popup)"
    description = "Upload a file from the Mythic server to the target system."
    version = 1
    supported_ui_features = ["file_browser:upload"]
    author = "nicholas.romanowski@servicenow.com"
    argument_class = UploadArguments
    attackmapping = ["T1132", "T1030", "T1105"]
    attributes = CommandAttributes(
        suggested_command=True,
        builtin=True
    )
```

### Example 3: BOF-based Command with Arguments - Shell

The `shell` command demonstrates how to create a BOF command that accepts arguments:

**BOF (C):**
```c
// In src/bofs/SA/shell.c
#include "../includes/beacon.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void coffee(int argc, char **argv) {
    if (argc < 1) {
        BeaconPrintf("Error: No command provided\n");
        return;
    }

    // The entire command line is in argv[0] when using bof_args_str
    char *full_command = argv[0];
    BeaconPrintf("Executing: %s\n", full_command);

    FILE *fp = popen(full_command, "r");
    if (fp == NULL) {
        BeaconPrintf("Error: Failed to execute command\n");
        return;
    }

    char buffer[4096];
    while (fgets(buffer, sizeof(buffer), fp) != NULL) {
        // Remove trailing newline if present
        size_t len = strlen(buffer);
        if (len > 0 && buffer[len - 1] == '\n') {
            buffer[len - 1] = '\0';
            len--;
        }
        BeaconOutput(buffer, len);
    }

    pclose(fp);
}
```

**Mythic Wrapper (Python):**
```python
from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *

class ShellArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
      if len(self.command_line) <= 0:
        raise Exception("Usage: shell [command] [arguments]")

      # Pass the entire command line as-is to the BOF
      # The BOF will handle parsing the command and arguments
      self.set_arg("bof_args_str", self.command_line.strip())

class ShellCommand(CommandBase):
    cmd = "shell"
    needs_admin = False
    help_cmd = "shell [command] [arguments]"
    description = "Execute shell commands on the target system"
    version = 1
    author = "nicholas.romanowski@servicenow.com"
    attackmapping = ["T1059.004"]
    argument_class = ShellArguments
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.Linux]
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
            DisplayParams=taskData.args.get_arg("bof_args_str")
        )

        return response
```

### Example 4: BOF-based Command with Parameters - Portscan

The `portscan` command shows how to handle structured parameters:

**Mythic Wrapper (Python):**
```python
from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *

class PortscanArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="host",
                type=ParameterType.String,
                description="Target host to scan",
                parameter_group_info=[ParameterGroupInfo(
                    required=True,
                    ui_position=1
                )]
            ),
            CommandParameter(
                name="ports",
                type=ParameterType.String,
                description="Comma-separated list of ports to scan (e.g., 22,80,443)",
                parameter_group_info=[ParameterGroupInfo(
                    required=True,
                    ui_position=2
                )]
            )
        ]

    async def parse_arguments(self):
        pass

    async def parse_dictionary(self, dictionary_arguments):
        host = dictionary_arguments.get("host")
        ports = dictionary_arguments.get("ports")
        
        # CRITICAL: Set these parameters for BOF execution
        self.add_arg("name", "portscan")           # BOF name
        self.add_arg("host", host)                 # For display
        self.add_arg("ports", ports)               # For display
        self.add_arg("bof_args", f"{host} {ports}") # Arguments passed to BOF

class PortscanCommand(CommandBase):
    cmd = "portscan"
    needs_admin = False
    help_cmd = "portscan <host> <port1,port2,...>"
    description = "Scan specified ports on a target host to check if they're open"
    version = 1
    author = "nicholas.romanowski@servicenow.com"
    attackmapping = ["T1046"]
    argument_class = PortscanArguments
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.Linux]
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
            CommandName="bof_exec",  # CRITICAL: Route to bof_exec
            DisplayParams=taskData.args.get_arg("arguments")
        )
        return response
```

## Command Attributes Guide

When implementing Mythic command wrappers, these attributes control their behavior:

- **builtin**: Set to `True` for built-in commands, `False` for BOF-based commands
- **load_only**: Set to `True` for BOF commands that need to be loaded first
- **suggested_command**: Set to `True` to display in command suggestions
- **supported_os**: Array of supported operating systems (`SupportedOS.Linux`, `SupportedOS.MacOS`)

## Parameter Types Reference

Available parameter types for Mythic commands:

- `ParameterType.String`: Text input
- `ParameterType.Number`: Numeric input
- `ParameterType.Boolean`: True/false toggle
- `ParameterType.File`: File upload
- `ParameterType.Array`: Array of values
- `ParameterType.ChooseOne`: Dropdown selection
- `ParameterType.ChooseMultiple`: Multi-select dropdown

## Testing Your Command

1. **For Built-in Commands**:
   - Add your command to `command_handler.cr`
   - Add your Python wrapper in `mythic/agent_functions/`
   - Rebuild the agent with `./build.sh`
   - Test through the Mythic UI

2. **For BOF-based Commands**:
   - Create your BOF in `src/bofs/c/`
   - Compile with `gcc -fPIC -c src/bofs/c/your_bof.c -o output/bofs/your_bof.o -I src/bofs/c/includes`
   - Add your Python wrapper in `mythic/agent_functions/`
   - Test by loading the BOF with `bof_load your_bof` and executing it

## Critical Pattern for BOF Commands with Arguments

When creating BOF-based commands that accept arguments, you **MUST** follow this pattern in your Mythic Python wrapper:

### Required Parameters

In your argument parsing method, set these critical parameters:

```python
# CRITICAL: These parameters are required for BOF execution
self.set_arg("name", "your_bof_name")        # The BOF name to execute

# Choose ONE of the following argument patterns:

# Option 1: Split arguments (traditional BOF behavior)
self.set_arg("bof_args", "arg1 arg2 arg3")   # Arguments split by spaces into argv[0], argv[1], argv[2]

# Option 2: Single string argument (shell-like commands)
self.set_arg("bof_args_str", "ls -latr /tmp/")  # Entire string passed as argv[0]
```

### Required Command Routing

In your `create_go_tasking` method, route the command to `bof_exec`:

```python
async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
    response = PTTaskCreateTaskingMessageResponse(
        TaskID=taskData.Task.ID,
        Success=True,
        CommandName="bof_exec"  # CRITICAL: Route to bof_exec, not your command name
    )
    return response
```

### BOF Argument Handling: bof_args vs bof_args_str

Dark Agent supports two different argument passing patterns for BOFs:

#### bof_args (Split Arguments)
Use this for traditional BOFs that expect individual arguments:
- Arguments are split by spaces: `"arg1 arg2 arg3"` becomes `argv[0]="arg1"`, `argv[1]="arg2"`, `argv[2]="arg3"`
- Best for BOFs that parse individual parameters
- Example: `portscan 192.168.1.1 22,80,443`

#### bof_args_str (Single String Argument)
Use this for shell-like commands that need the entire command line:
- Entire string passed as `argv[0]`: `"ls -latr /tmp/"` becomes `argv[0]="ls -latr /tmp/"`
- Best for BOFs that execute system commands or need complex argument parsing
- Example: `shell ls -latr /tmp/`

### Why This Pattern is Required

Dark Agent's command handler works as follows:

1. Your Mythic command wrapper parses user input and sets the `name` and either `bof_args` or `bof_args_str` parameters
2. The wrapper routes the command to `bof_exec` via `CommandName="bof_exec"`
3. The agent receives a `bof_exec` command with your BOF name and arguments
4. The agent checks for `bof_args_str` first (single string), then falls back to `bof_args` (split arguments)
5. The agent executes the BOF using the BOF registry with the processed arguments

**Without this pattern, your BOF command will not work correctly.**

## Common Patterns

1. **Error Handling**: Always handle errors gracefully in both Crystal and Python code
2. **Parameter Validation**: Validate parameters before using them
3. **UI Display**: Set `DisplayParams` in `create_go_tasking` for clear UI feedback
4. **Progress Updates**: Use `MessageHandler.add_task_info` for progress updates during long operations
5. **BOF Argument Routing**: Always use the `name` and `bof_args` pattern for BOF commands

By following this guide, you can implement new commands for Dark Agent that integrate seamlessly with both the agent codebase and the Mythic UI.