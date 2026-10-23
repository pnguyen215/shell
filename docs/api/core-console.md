# core/console.sh

Colourised terminal output primitives.

## Overview

Lowest-level output layer. Everything that prints (logger, prompts, help
blocks) funnels through shell::console::print so colour handling, `NO_COLOR`
support and escape-sequence behaviour live in exactly one place.

## Index

- [shell::console::detect_colors](#shellconsoledetect_colors)
- [shell::console::print](#shellconsoleprint)
- [shell::console::spinner](#shellconsolespinner)

### shell::console::detect_colors

Detect how many colours the terminal supports and cache the result.
Runs `tput colors` at most once per shell session (the previous
implementation forked `tput` two or three times for _every_ printed line).
Honours the https://no-color.org convention: when `NO_COLOR` is set and
non-empty, colours are disabled.

The result is stored in the global `_SHELL_CONSOLE_COLORS` (an integer).
It is written to a variable rather than echoed so callers do not need a
command substitution, which would run in a subshell and lose the cache.

_Function has no arguments._

#### Variables set

- **\_SHELL_CONSOLE_COLORS** (integer): Number of supported colours (0, 8, 256 ...).

#### Exit codes

- **0**: Always.

### shell::console::print

Print a message to stdout in a bold foreground colour.
Uses `printf` instead of `echo -e` because `echo` flag handling differs
between bash, zsh and the BSD/macOS userland.

Backslash escapes in the message (`\n`, `\t`, `\033`) are interpreted by
default, matching the historical behaviour. Pass `-E` to print verbatim.

#### Example

```bash
shell::console::print "Build finished" 46
shell::console::print "Enter name: " 208 -n
shell::console::print 'literal \n text' 33 -E
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n**

  Do not append a trailing newline.

- **-e**

  Interpret backslash escapes in the message (default).

- **-E**

  Print the message verbatim, without interpreting escapes.

#### Arguments

- **$1** (string): Message to print.
- **$2** (integer): ANSI 256-colour code, 0-255 (default: 4, blue).

#### Exit codes

- **0**: Message printed.
- **2**: Colour code is not an integer between 0 and 255.

#### Output on stdout

- The (possibly coloured) message.

### shell::console::spinner

Show a small text spinner for a fixed number of seconds.
Drawn on stderr so it never pollutes data captured from stdout.

#### Example

```bash
shell::console::spinner 5
shell::console::spinner -n 5
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print what would be shown instead of animating.

#### Arguments

- **$1** (integer): Duration in seconds (default: 3).

#### Exit codes

- **0**: Spinner finished (or dry-run printed).
- **2**: Duration is not a positive integer.

#### Output on stderr

- The animation frames.
