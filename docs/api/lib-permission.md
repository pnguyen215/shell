# lib/permission.sh

File permission helpers: set, secure, unlock, explain.

## Overview

Restrict a path to its owner: 600 for files, 700 for directories.
Use this for anything holding secrets (tokens, keys, credentials). It is
the safe replacement for the old habit of `chmod 777` on config files.

## Index

- [shell::permission::secure](#shellpermissionsecure)
- [shell::permission::unlock](#shellpermissionunlock)
- [shell::permission::set](#shellpermissionset)
- [shell::permission::set::fzf](#shellpermissionsetfzf)
- [shell::permission::analyze](#shellpermissionanalyze)

### shell::permission::secure

Restrict a path to its owner: 600 for files, 700 for directories.
Use this for anything holding secrets (tokens, keys, credentials). It is
the safe replacement for the old habit of `chmod 777` on config files.

#### Example

```bash
shell::permission::secure "$SHELL_KEY_FILE"
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): File or directory.

#### Exit codes

- **0**: Permissions were applied (or already correct, or dry-run printed).
- **1**: chmod failed.
- **2**: No path given.
- **3**: The path does not exist.

### shell::permission::unlock

Grant read/write/execute to everyone (`chmod -R 777`). **Dangerous.**
Kept for explicit, deliberate use (e.g. a throw-away shared scratch dir).
The library itself no longer calls it on configuration files: use
shell::permission::secure for anything sensitive.

#### Example

```bash
shell::permission::unlock ./shared-scratch
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--sudo**

  Run chmod through sudo.

#### Arguments

- **$1** (string): File or directory.

#### Exit codes

- **0**: Permissions applied, already 777, or dry-run printed.
- **1**: chmod failed.
- **2**: No path given.
- **3**: The path does not exist.

### shell::permission::set

Set permissions from `owner=`, `group=` and `others=` descriptions.
Each description is a comma-separated mix of `read`, `write`, `execute` (or
`none`). Unspecified classes get no permission.

#### Example

```bash
shell::permission::set ./run.sh owner=read,write,execute group=read,execute others=read
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): File or directory.
- **...** (string): One or more of owner=<perms> group=<perms> others=<perms>.

#### Exit codes

- **0**: Permissions applied (or dry-run printed).
- **1**: chmod failed.
- **2**: Wrong arguments or an unknown class.
- **3**: The target does not exist.

### shell::permission::set::fzf

Pick owner/group/others permissions with fzf and apply them.

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): File or directory.

#### Exit codes

- **0**: Permissions applied (or dry-run printed).
- **2**: No target given.
- **3**: The target does not exist.
- **9**: The user cancelled a selection.

#### See also

- [shell::permission::set](#shellpermissionset)

### shell::permission::analyze

Explain a permission string in plain language.
Reads the permissions of a file, or analyses a literal string such as
`-rwxr-xr-x`, and prints owner/group/others meaning, the octal value and a
short developer-oriented hint.

#### Example

```bash
shell::permission::analyze -rwxr-xr-x
shell::permission::analyze --file ./deploy.sh
```

#### Options

- **-h** | **--help**

  Show help and return.

- **--file \<path\>**

  Use the permissions of this file.

- **--debug**

  Print the parsed components to stderr.

#### Arguments

- **$1** (string): Permission string like -rwxr-xr-x (default: -rw-r--r--).

#### Exit codes

- **0**: Success.
- **1**: The permissions could not be read.
- **2**: Bad arguments or malformed permission string.
- **3**: The file does not exist.

#### Output on stdout

- The explanation.
