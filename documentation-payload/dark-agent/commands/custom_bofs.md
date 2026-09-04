+++
title = "Creating Custom BOFs"
chapter = false
weight = 50
+++

# Creating Custom BOFs for Dark Agent

Dark Agent allows you to extend its functionality by creating custom Beacon Object Files (BOFs). These are compiled C object files that can be loaded and executed by the agent at runtime.

## BOF Development Overview

BOFs in Dark Agent provide:
- Access to the Beacon API for output and functionality
- Small, fast executables that run in the agent's process
- No need to restart the agent to add new commands
- Simplified C programming interface

## BOF Development Process

### 1. Set Up Development Environment

You'll need:
- GCC compiler
- Dark Agent source code (for the header files)
- Basic C programming knowledge

### 2. Create a C Source File

Start by creating a new `.c` file in the `src/bofs/c/` directory. Here's a minimal example:

```c
#include "beacon.h"

void coffee() {
    BeaconPrintf(CALLBACK_OUTPUT, "Hello from my custom BOF!");
    
    // Your functionality here
}
```

Important notes:
- The `coffee()` function is the entry point for your BOF
- `beacon.h` provides access to the Beacon API

### 3. Using the Beacon API

Dark Agent implements these Beacon API callbacks:

| Callback | Description |
|----------|-------------|
| BeaconPrintf(format, ...) | Print formatted output |
| BeaconOutput(data, len) | Output raw binary data |

#### String Formatting Guidelines

For string formatting in `BeaconPrintf`:
- Use only `%s` for strings - other format specifiers are not supported
- Convert non-string values to strings before using them
- Use string literals or string pointers

Example:

```c
// Good: Using %s with string variables
const char* name = "World";
BeaconPrintf("Hello, %s!", name);

// Good: Converting int to string
char number_str[16];
int value = 12345;
snprintf(number_str, sizeof(number_str), "%d", value);
BeaconPrintf("The value is %s", number_str);

// Bad: Don't use %d or other non-string specifiers
// BeaconPrintf("The value is %d", value);
```

### 4. Compiling Your BOF

Use GCC to compile your BOF:

```bash
gcc -fPIC -c your_bof.c -o your_bof.o -I src/bofs/includes
```

Or add it to the Dark Agent build script by placing it in the `src/bofs/` directory and running:

```bash
./build.sh -b
```

### 5. Using Your Custom BOF

Once compiled, your BOF can be loaded into the agent:

1. **Using manual loading**:
   ```
   bof_load your_bof
   bof_execute your_bof arg1 arg2
   ```

2. **Creating a Mythic command wrapper** (advanced):
   
   To add a Mythic UI wrapper for your BOF, you need to create a Python file in the `agent_functions` directory. This is for advanced users who want full Mythic UI integration.

## Example: Creating a 'hostname' BOF

Let's create a simple BOF that displays the system hostname:

```c
#include "beacon.h"
#include <unistd.h>

void coffee() {
    char hostname[256];
    
    if (gethostname(hostname, sizeof(hostname)) == 0) {
        BeaconPrintf(CALLBACK_OUTPUT, "Hostname: %s", hostname);
    } else {
        BeaconPrintf(CALLBACK_OUTPUT, "Failed to get hostname");
    }
}
```

Compile and use:

```bash
gcc -fPIC -c hostname.c -o hostname.o -I src/bofs/c/includes
# In Mythic:
bof_load hostname
bof_execute hostname
```

## Advanced BOF Development

### Passing Arguments to BOFs

For BOFs that need to accept arguments, you need to parse them manually from the command line:

```c
#include "beacon.h"
#include <string.h>

void coffee() {
    // Get the command line args
    datap parser;
    char* args;
    
    // Initialize the parser with the args
    BeaconDataParse(&parser, args);
    
    // Read a string argument
    char* arg1 = BeaconDataExtract(&parser, NULL);
    
    if (arg1) {
        BeaconPrintf(CALLBACK_OUTPUT, "Argument: %s", arg1);
    } else {
        BeaconPrintf(CALLBACK_OUTPUT, "No arguments provided");
    }
}
```

### BOF Best Practices

1. **Keep it Simple**: BOFs should be focused on a single task
2. **Error Handling**: Always check return values and handle errors
3. **Memory Management**: Be careful with memory allocations
4. **String Safety**: Use safe string functions to avoid buffer overflows
5. **Testing**: Test your BOFs in direct mode before using them in operations

## Troubleshooting BOF Development

Common issues when developing BOFs:

- **Compilation Errors**: Make sure you're including the correct headers
- **Runtime Errors**: Use debug mode to see detailed error messages
- **String Formatting Issues**: Remember to only use `%s` for string formatting
- **Memory Issues**: Be careful with memory allocation/deallocation

You can test BOFs in direct mode for easier debugging:

```bash
./build.sh -D
./output/dark-agent-direct output/bofs/your_bof.o arg1 arg2
```

This will load and execute your BOF outside of Mythic, making it easier to debug issues.