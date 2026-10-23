# core/fzf.sh

Single entry point for every interactive fuzzy picker.

## Overview

Instead of repeating the same eight fzf flags in every function, pickers
call shell::fzf::select. The look-and-feel is controlled by the
`SHELL_FZF_OPTS` array in constant/defaults.sh.

## Index

- [shell::fzf::select](#shellfzfselect)

### shell::fzf::select

Run fzf with the library's default options.
Reads candidate lines from **stdin** and prints the selection on stdout.
fzf is installed on demand (see shell::dependency::fzf::ensure).

Pressing ESC / Ctrl-C is reported as `RETURN_CANCELLED` so callers can stop
instead of looping forever (the previous prompts re-asked indefinitely).

#### Example

```bash
branch="$(git branch --format='%(refname:short)' | shell::fzf::select --prompt='Branch: ')"
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Arguments

- **...** (string): Extra fzf arguments (e.g. --prompt="Pick: ", --multi, --preview=...).

#### Exit codes

- **0**: A selection was made.
- **9**: The user cancelled, or nothing matched.
- **3**: fzf is not installed and could not be installed.

#### Input on stdin

- Candidate lines.

#### Output on stdout

- The selected line(s).
