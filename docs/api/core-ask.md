# core/ask.sh

Interactive prompts: yes/no, text, secret, number, path and menus.

## Overview

All prompts write the *question* to stderr and the *answer* to stdout, so
`answer="$(shell::ask::text "Name?")"` captures only the answer.

Cancelling (ESC in a menu, Ctrl-D / EOF in a text prompt) returns
RETURN_CANCELLED. Earlier versions looped forever in those cases, which
made it impossible to abort - and hung any non-interactive caller.

## Index

* [shell::ask::reply](#shellaskreply)
* [shell::ask::deny](#shellaskdeny)
* [shell::ask::accept](#shellaskaccept)
* [shell::ask::text](#shellasktext)
* [shell::ask::password](#shellaskpassword)
* [shell::ask::number](#shellasknumber)
* [shell::ask::path](#shellaskpath)
* [shell::ask::option](#shellaskoption)
* [shell::ask::option::value](#shellaskoptionvalue)
* [shell::ask::options](#shellaskoptions)
* [shell::ask::options::values](#shellaskoptionsvalues)

### shell::ask::reply

Ask a yes/no question with an fzf menu and print the answer.

#### Example

```bash
[ "$(shell::ask::reply "Overwrite?")" = "yes" ] && echo "overwriting"
```

#### Options

* **-h** | **--help**

  Show help and return.

#### Arguments

* **$1** (string): The question.

#### Exit codes

* **0**: An answer was chosen.
* **2**: The question is empty.
* **9**: The user cancelled (ESC).

#### Output on stdout

* "yes" or "no".

### shell::ask::deny

Ask a yes/no question on the terminal; succeed when answered **no**.
Reads naturally in guard clauses: `shell::ask::deny "Abort?" && return`.

#### Options

* **-h** | **--help**

  Show help and return.

#### Arguments

* **$1** (string): The question.

#### Exit codes

* **0**: The user answered no (denied).
* **1**: The user answered yes.
* **2**: The question is empty.
* **9**: Input ended (EOF).

### shell::ask::accept

Ask a yes/no question on the terminal; succeed when answered **yes**.
**Bug fix:** the previous implementation never returned on "yes" - it fell
out of the `case` and asked the same question again, forever.

#### Example

```bash
if shell::ask::accept "Continue?"; then echo "go"; fi
```

#### Options

* **-h** | **--help**

  Show help and return.

#### Arguments

* **$1** (string): The question.

#### Exit codes

* **0**: The user answered yes.
* **1**: The user answered no.
* **2**: The question is empty.
* **9**: Input ended (EOF).

### shell::ask::text

Prompt for a non-empty line of text.

#### Example

```bash
name="$(shell::ask::text "Project name?")"
```

#### Options

* **-h** | **--help**

  Show help and return.

#### Arguments

* **$1** (string): The question.

#### Exit codes

* **0**: A value was entered.
* **2**: The question is empty.
* **9**: Input ended (EOF).

#### Output on stdout

* The trimmed text.

### shell::ask::password

Prompt for a secret (input is not echoed).

#### Options

* **-h** | **--help**

  Show help and return.

#### Arguments

* **$1** (string): The question.

#### Exit codes

* **0**: A value was entered.
* **2**: The question is empty.
* **9**: Input ended (EOF).

#### Output on stdout

* The trimmed secret.

### shell::ask::number

Prompt for a number (integer or decimal, optionally negative).

#### Options

* **-h** | **--help**

  Show help and return.

#### Arguments

* **$1** (string): The question.

#### Exit codes

* **0**: A valid number was entered.
* **2**: The question is empty.
* **9**: Input ended (EOF).

#### Output on stdout

* The number as typed.

### shell::ask::path

Prompt for a filesystem path, optionally validating it.
A leading `~` is expanded to `$HOME`.

#### Example

```bash
dir="$(shell::ask::path --dir --writable "Output directory?")"
```

#### Options

* **-h** | **--help**

  Show help and return.

* **--exists**

  The path must exist.

* **--dir**

  The path must be a directory (implies --exists).

* **--file**

  The path must be a regular file (implies --exists).

* **--writable**

  The path must be writable.

* **--readable**

  The path must be readable.

#### Arguments

* **$1** (string): The question.

#### Exit codes

* **0**: A valid path was entered.
* **2**: Unknown option or empty question.
* **9**: Input ended (EOF).

#### Output on stdout

* The validated path (with `~` expanded).

### shell::ask::option

Choose ONE entry from a list with fzf.

#### Example

```bash
env="$(shell::ask::option dev staging prod)" || return
```

#### Options

* **-h** | **--help**

  Show help and return.

#### Arguments

* **...** (string): The choices.

#### Exit codes

* **0**: An entry was chosen.
* **2**: No choices were given.
* **9**: The user cancelled (ESC).

#### Output on stdout

* The chosen entry.

### shell::ask::option::value

Choose one entry from `label:value` pairs; print the value.
Only the label is displayed; the text after the first colon is returned.

#### Example

```bash
port="$(shell::ask::option::value "HTTP:80" "HTTPS:443")"
```

#### Options

* **-h** | **--help**

  Show help and return.

#### Arguments

* **...** (string): Entries in the form `label:value`.

#### Exit codes

* **0**: An entry was chosen.
* **2**: No entries were given.
* **9**: The user cancelled (ESC).

#### Output on stdout

* The value belonging to the chosen label.

### shell::ask::options

Choose SEVERAL entries from a list with fzf (Tab to mark).

#### Example

```bash
picks="$(shell::ask::options alpha beta gamma)"
```

#### Options

* **-h** | **--help**

  Show help and return.

#### Arguments

* **...** (string): The choices.

#### Exit codes

* **0**: Zero or more entries were chosen.
* **2**: No choices were given.

#### Output on stdout

* The chosen entries, separated by single spaces (empty if none).

### shell::ask::options::values

Choose several `label:value` entries; print the values.

#### Options

* **-h** | **--help**

  Show help and return.

#### Arguments

* **...** (string): Entries in the form `label:value`.

#### Exit codes

* **0**: Zero or more entries were chosen.
* **2**: No entries were given.

#### Output on stdout

* The values of the chosen labels, separated by single spaces.

