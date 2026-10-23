# core/logger.sh

Leveled, colourised logging, help-block rendering and command echo.

## Overview

Log levels, in increasing severity: **DEBUG(0) < INFO(1) < WARN(2) < ERROR(3)
< FATAL(4)**. A message is printed only when its level is >= `SHELL_LOGGER_LEVEL`
(default DEBUG, see constant/defaults.sh).

DEBUG / WARN / ERROR / FATAL go to **stderr**; INFO / success go to
**stdout**. Keep that in mind when capturing output with `$(...)`.

The same module also renders the `-h` help blocks every shell::\* function
uses (usage / item / option / example), so the help layout is uniform.

## Index

- [shell::logger::level::to_int](#shellloggerlevelto_int)
- [shell::logger::can](#shellloggercan)
- [shell::logger::reset](#shellloggerreset)
- [shell::logger::reset_options](#shellloggerreset_options)
- [shell::logger::level](#shellloggerlevel)
- [shell::logger::debug](#shellloggerdebug)
- [shell::logger::info](#shellloggerinfo)
- [shell::logger::warn](#shellloggerwarn)
- [shell::logger::error](#shellloggererror)
- [shell::logger::fatal](#shellloggerfatal)
- [shell::logger::success](#shellloggersuccess)
- [shell::logger::usage](#shellloggerusage)
- [shell::logger::item](#shellloggeritem)
- [shell::logger::option](#shellloggeroption)
- [shell::logger::example](#shellloggerexample)
- [shell::logger::indent](#shellloggerindent)
- [shell::logger::step](#shellloggerstep)
- [shell::logger::note](#shellloggernote)
- [shell::logger::section](#shellloggersection)
- [shell::logger::command](#shellloggercommand)
- [shell::logger::command_clip](#shellloggercommand_clip)
- [shell::logger::execute](#shellloggerexecute)
- [shell::logger::assert](#shellloggerassert)
- [shell::logger::dispatch](#shellloggerdispatch)
- [shell::logger::evaluate](#shellloggerevaluate)

### shell::logger::level::to_int

Convert a log-level name to its numeric severity.

#### Example

```bash
shell::logger::level::to_int warn   # prints 2
```

#### Arguments

- **$1** (string): Level name (case-insensitive): DEBUG, INFO, WARN, ERROR, FATAL.

#### Exit codes

- **0**: Always.

#### Output on stdout

- Integer 0-4, or an empty string when the level is unknown.

### shell::logger::can

Decide whether a message of a given level should be printed.

#### Example

```bash
shell::logger::can DEBUG && echo "debug output is on"
```

#### Arguments

- **$1** (string): Level of the message being logged.

#### Exit codes

- **0**: The level is enabled by the current threshold.
- **1**: The level is filtered out, or either level name is invalid.

### shell::logger::reset

Reset the threshold to DEBUG (print everything).

_Function has no arguments._

#### Variables set

- **SHELL_LOGGER_LEVEL** (string): Set to "DEBUG".

#### Exit codes

- **0**: Always.

### shell::logger::reset_options

Forget that the "OPTIONS:" heading was already printed.
shell::logger::option prints the heading once per help block; call this at
the start of every help block so the heading appears again.

_Function has no arguments._

#### Exit codes

- **0**: Always.

### shell::logger::level

Interactively choose the log threshold with fzf.

_Function has no arguments._

#### Variables set

- **SHELL_LOGGER_LEVEL** (string): The selected level (unchanged when cancelled).

#### Exit codes

- **0**: Level updated.
- **9**: Selection cancelled.

#### See also

- [shell::ask::option](#shellaskoption)

### shell::logger::debug

Log a DEBUG message (stderr).

#### Arguments

- **...** (string): Message.

#### Exit codes

- **0**: Always.

#### Output on stderr

- "DEBUG: <message>"

### shell::logger::info

Log an INFO message (stdout).

#### Arguments

- **...** (string): Message.

#### Exit codes

- **0**: Always.

#### Output on stdout

- "INFO: <message>"

### shell::logger::warn

Log a WARN message (stderr).

#### Arguments

- **...** (string): Message.

#### Exit codes

- **0**: Always.

#### Output on stderr

- "WARN: <message>"

### shell::logger::error

Log an ERROR message (stderr).

#### Arguments

- **...** (string): Message.

#### Exit codes

- **0**: Always.

#### Output on stderr

- "ERROR: <message>"

### shell::logger::fatal

Log a FATAL message (stderr) and return a failure status.
**Behaviour change:** the previous implementation called `exit 1`. Because
this library is _sourced_ into the user's interactive shell, `exit` closed
the user's terminal. The function now returns instead; callers decide
whether to abort (`shell::logger::fatal "..." || return`).

#### Arguments

- **...** (string): Message.

#### Exit codes

- **1**: Always.

#### Output on stderr

- "FATAL: <message>"

### shell::logger::success

Log a success message (INFO level, green, stdout).

#### Arguments

- **...** (string): Message.

#### Exit codes

- **0**: Always.

#### Output on stdout

- "INFO: <message>"

### shell::logger::usage

Print the "USAGE:" line of a help block.

#### Arguments

- **$1** (string): Synopsis, e.g. "shell::foo [-n] <path>".

#### Exit codes

- **0**: Always.

#### Output on stdout

- "USAGE: <synopsis>"

### shell::logger::item

Print a positional-argument line of a help block.

#### Arguments

- **$1** (string): Argument name.
- **$2** (string): Optional description (printed on its own, indented line).

#### Exit codes

- **0**: Always.

#### Output on stdout

- The argument and its description.

### shell::logger::option

Print an option line of a help block.
The "OPTIONS:" heading is printed before the first option of each block.

#### Arguments

- **$1** (string): Option flags, e.g. "-n, --dry-run".
- **$2** (string): Optional description.

#### Exit codes

- **0**: Always.

#### Output on stdout

- The formatted option line.

#### See also

- [shell::logger::reset_options](#shellloggerreset_options)

### shell::logger::example

Print an example invocation in a help block.

#### Arguments

- **$1** (string): The example command line.

#### Exit codes

- **0**: Always.

#### Output on stdout

- "Eg:" followed by the highlighted command.

### shell::logger::indent

Print an indented line.
Two argument forms are accepted: `(level color message)` or, as a
shorthand, `(level message)` which uses the default grey colour.

#### Arguments

- **$1** (integer): Indent level 0-5 (2 spaces per level; out of range = 0).
- **$2** (string): Colour code, or the message when $3 is omitted.
- **$3** (string): Message (when $2 is a colour code).

#### Exit codes

- **0**: Always.

#### Output on stdout

- The indented message.

### shell::logger::step

Print a "STEP n: ..." progress line.

#### Arguments

- **$1** (integer): Step number.
- **$2** (string): Step description.

#### Exit codes

- **0**: Always.

#### Output on stdout

- The step line.

### shell::logger::note

Print an indented "NOTE:" line.

#### Arguments

- **$1** (string): The note text.

#### Exit codes

- **0**: Always.

#### Output on stdout

- The note line.

### shell::logger::section

Print a titled section separated by horizontal rules.

#### Arguments

- **$1** (string): Section title.

#### Exit codes

- **0**: Always.

#### Output on stdout

- Rule, title, rule.

### shell::logger::command

Print a command line (prefixed with a glyph) without running it.

#### Arguments

- **...** (string): The command words.

#### Exit codes

- **0**: Always.

#### Output on stdout

- " ▶ <command>"

### shell::logger::command_clip

Print a command and copy it to the clipboard (dry-run helper).
This is the _result_ of a `-n / --dry-run` invocation, so it is printed even
when the log threshold would normally hide INFO messages. A missing
clipboard tool is not an error: the command is still printed.

#### Arguments

- **...** (string): The command words.

#### Exit codes

- **0**: Always.

#### Output on stdout

- The highlighted command.

#### See also

- [shell::clipboard::copy](#shellclipboardcopy)

### shell::logger::execute

Print a command and run it through `eval`.
The command is **always executed**; the log threshold only controls whether
the command line is echoed. (The previous implementation silently skipped
execution when the threshold was above INFO.)

SECURITY: `eval` re-parses the string. Quote every interpolated value, and
never pass untrusted input. Prefer shell::exec::command for argv-style calls.

#### Arguments

- **...** (string): Command string.

#### Exit codes

- **0**: The command succeeded.
- **2**: The command string is empty.
- N Exit status of the evaluated command.

### shell::logger::assert

Run a command string with `eval` and report a ✓ / ✗ result line.

#### Example

```bash
shell::logger::assert "mkdir -p \"$dir\"" "Directory ready" "mkdir failed"
```

#### Arguments

- **$1** (string): Command string (evaluated).
- **$2** (string): Success message (default: "Success").
- **$3** (string): Failure message (default: "Aborted").

#### Exit codes

- **0**: The command succeeded.
- **2**: The command string is empty.
- N Exit status of the evaluated command.

#### Output on stdout

- Echoed command and a result line (only when INFO is enabled).

### shell::logger::dispatch

Print a command and run it in a _fresh_ `bash -c` process.
Unlike shell::logger::execute, the command cannot read or modify the
current shell's variables, functions or working directory.

#### Arguments

- **...** (string): Command string.

#### Exit codes

- **0**: The command succeeded.
- **2**: The command string is empty.
- N Exit status of the command.

### shell::logger::evaluate

Like shell::logger::assert, but runs in a fresh `bash -c` process.

#### Arguments

- **$1** (string): Command string.
- **$2** (string): Success message (default: "Success").
- **$3** (string): Failure message (default: "Aborted").

#### Exit codes

- **0**: The command succeeded.
- **2**: The command string is empty.
- N Exit status of the command.

#### Output on stdout

- Echoed command and a result line (only when INFO is enabled).

#### See also

- [shell::logger::assert](#shellloggerassert)
