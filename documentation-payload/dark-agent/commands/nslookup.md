+++
title = "nslookup"
chapter = false
weight = 5
+++

# nslookup

The `nslookup` command performs DNS lookups on one or more hostnames with optional nameserver specification.

## Usage

```
nslookup <hostname1>,<hostname2> [nameserver]
```

### Parameters

- `hostnames`: Comma-separated list of hostnames to resolve (required)
- `nameserver`: Optional DNS nameserver to use for lookups

### Examples

```bash
# Lookup single hostname
nslookup google.com

# Lookup multiple hostnames
nslookup google.com,github.com,stackoverflow.com

# Lookup with specific nameserver
nslookup google.com 8.8.8.8

# Lookup multiple hostnames with specific nameserver
nslookup google.com,github.com 1.1.1.1
```

## Output

The command provides detailed DNS resolution information including:

- Hostname being resolved
- IPv4 addresses (if available)
- IPv6 addresses (if available)
- Error messages for unresolvable hosts
- Summary of total lookups performed

### Example Output

```
DNS Lookup Results:
==================

[1] Hostname: google.com
    IPv4: 142.250.191.14
    IPv6: 2607:f8b0:4004:c1b::71

[2] Hostname: github.com
    IPv4: 140.82.112.3

DNS lookup completed for 2 hostname(s).
```

## MITRE ATT&CK Mapping

- **T1016**: System Network Configuration Discovery

## Implementation

This command is implemented as a BOF (Beacon Object File) that uses the system's `getaddrinfo()` function to perform DNS resolution. It supports both IPv4 and IPv6 lookups and handles multiple hostnames efficiently.

The command automatically handles DNS resolution using the system's default nameserver configuration, but allows specifying a custom nameserver when needed for specific reconnaissance scenarios.