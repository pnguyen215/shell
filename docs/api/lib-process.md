# lib/process.sh

Process inspection helpers.

## Overview

List the processes using the most memory.
Uses `ps -axo pid=,user=,%mem=,command=` (the trailing `=` suppresses the
header) and `sort`, both of which behave identically on Linux and macOS.
The earlier implementation relied on GNU-only `ps --sort` on Linux and on a
fragile `top | grep | awk` pipeline on macOS.

## Index

- [shell::process::top_memory](#shellprocesstop_memory)

### shell::process::top_memory

List the processes using the most memory.
Uses `ps -axo pid=,user=,%mem=,command=` (the trailing `=` suppresses the
header) and `sort`, both of which behave identically on Linux and macOS.
The earlier implementation relied on GNU-only `ps --sort` on Linux and on a
fragile `top | grep | awk` pipeline on macOS.

#### Example

```bash
shell::process::top_memory 5
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (integer): How many processes to show (default: 10).

#### Exit codes

- **0**: Success.
- **2**: The count is not a positive integer.

#### Output on stdout

- One line per process: PID, user, %MEM, command.
