+++
title = "upload"
chapter = false
weight = 11
+++

## Summary

Uploads a file from the Mythic server to the target system using chunked transmission.

The `upload` command transfers files from the Mythic server to the compromised system. Files are transmitted in configurable chunks and reassembled on the target. The command supports specifying custom destination paths and provides real-time progress updates.

## Arguments

- **file** (file, required): File to upload from Mythic server (selected via file browser)
- **remote_path** (string, required): Destination path on the target system

## Usage

1. **Select File**: Use the file browser in Mythic to select the file to upload
2. **Specify Path**: Enter the destination path on the target system

```bash
# Upload to specific location
upload /tmp/payload.bin

# Upload to user directory  
upload /home/user/documents/file.txt

# Upload to system location (requires privileges)
upload /etc/malicious.conf
```

## Output

The command provides real-time progress during upload:

```
Starting upload to /tmp/payload.bin
Requesting chunk 1/1 from Mythic server...
Writing chunk 1/1 (2048 bytes) to file...
Upload completed successfully: /tmp/payload.bin
```

For large files:
```
Starting upload to /tmp/large_file.bin
Requesting chunk 1/205 from Mythic server...
Writing chunk 1/205 (524288 bytes) to file...
Requesting chunk 2/205 from Mythic server...
...
Upload completed successfully: /tmp/large_file.bin
```

## Technical Details

- **Chunk Size**: Configurable via `chunk_size` build parameter (default: 512KB)
- **Encoding**: Files are Base64 decoded after transmission
- **Atomicity**: File is written completely or not at all (no partial files on failure)
- **Permissions**: Written with standard file permissions (644)
- **Overwrite**: Existing files are overwritten without warning

## File Transfer Process

1. Agent requests first chunk from Mythic server
2. Mythic responds with Base64-encoded file chunk
3. Agent decodes and writes chunk to destination file
4. Process repeats until all chunks are received
5. File is marked complete and closed

## OPSEC Considerations

- File writes are performed by the agent process
- Large uploads create multiple HTTP requests to C2 server  
- Files are written directly to specified path (no staging area)
- Consider upload size vs. network detection risk
- Uploaded files persist on disk until manually removed

## Examples

Upload common payloads:
```bash
upload /tmp/linpeas.sh
upload /tmp/privilege_escalation.bin
upload /tmp/additional_payload
```

Upload configuration files:
```bash
upload /etc/cron.d/persistence
upload /home/user/.bashrc
upload /tmp/malicious_library.so
```

## Error Handling

Common error scenarios:

- **Permission denied**: "Error: Permission denied writing to /path/to/file"
- **Disk full**: "Error: No space left on device"
- **Invalid path**: "Error: Cannot create file at /invalid/path"
- **Chunk timeout**: "Error: Timeout waiting for chunk from server"

## Security Notes

- Uploaded files are not automatically made executable
- Consider file ownership and permissions after upload
- Large uploads may trigger network monitoring
- Files persist until manually deleted with `rm` or system commands