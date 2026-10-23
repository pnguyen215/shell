# core/command.sh

Command-availability checks.

## Overview

Test whether an executable, builtin, alias or function exists.
Uses the `command -v` builtin, which is POSIX and avoids forking `which`
(whose exit status and output differ across Linux and macOS).

## Index

* [shell::command::exists](#shellcommandexists)

### shell::command::exists

Test whether an executable, builtin, alias or function exists.
Uses the `command -v` builtin, which is POSIX and avoids forking `which`
(whose exit status and output differ across Linux and macOS).

#### Example

```bash
if shell::command::exists jq; then echo "jq available"; fi
```

#### Options

* **-h** | **--help**

  Show help and return.

#### Arguments

* **$1** (string): Name of the command to look up.

#### Exit codes

* **0**: The command exists.
* **1**: The command does not exist.
* **2**: No command name was provided.

