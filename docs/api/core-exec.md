# core/exec.sh

Command execution wrappers with logging and dry-run support.

## Overview

Two families exist, and choosing the right one matters for safety:

- **argv style** (shell::exec::command, shell::exec::async): arguments are
  passed to the program verbatim; no re-parsing, so spaces and quotes in
  values are safe.
- **string style** (shell::exec::shell, shell::exec::silent,
  shell::exec::safe): the string is run through `eval`, which allows pipes
  and redirections but re-parses everything. Quote interpolated values and
  never pass untrusted input.

## Index

- [shell::exec::command](#shellexeccommand)
- [shell::exec::shell](#shellexecshell)
- [shell::exec::silent](#shellexecsilent)
- [shell::exec::safe](#shellexecsafe)
- [shell::exec::async](#shellexecasync)
- [shell::exec::now_ms](#shellexecnow_ms)
- [shell::exec::measure](#shellexecmeasure)

### shell::exec::command

Run a program directly (argv style) and echo it first.

#### Example

```bash
shell::exec::command ls -lah
shell::exec::command -n git pull
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command (and copy it) instead of running it.

#### Arguments

- **$1** (string): Program to run.
- **...** (string): Arguments passed unchanged to the program.

#### Exit codes

- **0**: The program succeeded (or dry-run printed).
- **2**: No command was given.
- N Exit status of the program.

### shell::exec::shell

Run a command string through `eval` and echo it first.

#### Example

```bash
shell::exec::shell "ls -lah | grep txt"
shell::exec::shell -n "git log | head"
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **...** (string): Command string (words are joined with spaces).

#### Exit codes

- **0**: The command succeeded (or dry-run printed).
- **2**: No command was given.
- N Exit status of the evaluated command.

### shell::exec::silent

Run a command string through `eval` without echoing it.

#### Example

```bash
shell::exec::silent "mkdir -p build"
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **...** (string): Command string.

#### Exit codes

- **0**: The command succeeded (or dry-run printed).
- **2**: No command was given.
- N Exit status of the evaluated command.

### shell::exec::safe

Print a command when `dry_run` is true, otherwise execute it.

#### Example

```bash
shell::exec::safe true  "rm -rf build"   # prints only
shell::exec::safe false "echo hello"     # runs
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Arguments

- **$1** (string): "true" to only print the command, "false" to execute it.
- **$2** (string): Command string (evaluated when executing).

#### Exit codes

- **0**: Printed (dry run) or the command succeeded.
- **2**: Wrong arguments, or $1 is neither "true" nor "false".
- N Exit status of the evaluated command.

### shell::exec::async

Run a command or function in the background.
Unlike the previous version (which evaluated `"<cmd> &"` and never used the
PID), this runs the command argv-style and reports the PID.

#### Example

```bash
shell::exec::async sleep 30
shell::exec::async -n my_function arg1
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of starting it.

#### Arguments

- **$1** (string): Command or function name.
- **...** (string): Arguments.

#### Exit codes

- **0**: Started (or dry-run printed).
- **2**: No command was given.

#### Output on stdout

- "INFO: started in background (pid N)".

### shell::exec::now_ms

Print the current time in milliseconds since the Unix epoch.
Portable across Linux and macOS: `date +%s%3N` is GNU-only and prints a
literal "N" on BSD/macOS, so several fallbacks are tried in order:
`$EPOCHREALTIME`, GNU `date +%s%N`, `gdate` (Homebrew coreutils), and
finally whole seconds.

_Function has no arguments._

#### Exit codes

- **0**: Always.

#### Output on stdout

- Integer milliseconds.

### shell::exec::measure

Run a command and report how long it took.

#### Example

```bash
shell::exec::measure sleep 2
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Arguments

- **$1** (string): Program or function to run.
- **...** (string): Arguments.

#### Exit codes

- **2**: No command was given.
- N Exit status of the measured command (preserved).

#### Output on stdout

- "Execution time: Ns Mms".
