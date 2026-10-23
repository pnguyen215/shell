# core/os.sh

Operating-system and environment detection.

## Overview

Every platform branch in the library goes through these helpers so Linux,
macOS (and the "unsupported" fallback) are decided in one place.

## Index

- [shell::os::type](#shellostype)
- [shell::os::is_macos](#shellosis_macos)
- [shell::os::is_linux](#shellosis_linux)
- [shell::os::arch](#shellosarch)
- [shell::os::temp_dir](#shellostemp_dir)
- [shell::os::shell_name](#shellosshell_name)

### shell::os::type

Print the normalised operating-system name.
The result of `uname` is cached in the global `SHELL_OS_TYPE`, so repeated
calls (this function is used in nearly every module) cost no fork.

#### Example

```bash
case "$(shell::os::type)" in
  macos) echo "BSD userland" ;;
  linux) echo "GNU userland" ;;
esac
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Exit codes

- **0**: Always.

#### Output on stdout

- One of: linux, macos, windows, unknown.

### shell::os::is_macos

Test whether the host is macOS.

_Function has no arguments._

#### Exit codes

- **0**: Running on macOS.
- **1**: Running anywhere else.

#### See also

- [shell::os::type](#shellostype)

### shell::os::is_linux

Test whether the host is Linux (including WSL).

_Function has no arguments._

#### Exit codes

- **0**: Running on Linux.
- **1**: Running anywhere else.

#### See also

- [shell::os::type](#shellostype)

### shell::os::arch

Print the normalised CPU architecture.

#### Example

```bash
arch="$(shell::os::arch)"   # amd64 | arm64
```

_Function has no arguments._

#### Exit codes

- **0**: Always.

#### Output on stdout

- One of: amd64, arm64, or the raw `uname -m` value for others.

### shell::os::temp_dir

Print the temporary directory for the current user.
Honours `$TMPDIR` (macOS sets it to a per-user directory under
/var/folders) and falls back to /tmp. A trailing slash is removed.

The previous implementation captured the _exit status_ of
`shell::base::os` instead of its output, so it always returned `/tmp`, and
it leaked the OS name to stdout, corrupting `TEMP=$(...)` assignments.

#### Example

```bash
tmp="$(shell::os::temp_dir)"
```

_Function has no arguments._

#### Exit codes

- **0**: Always.

#### Output on stdout

- Absolute path of the temporary directory (no trailing slash).

### shell::os::shell_name

Print the user's login shell name (bash, zsh, ...).
Looks at the _running_ shell first (ZSH_VERSION / BASH_VERSION), because
`$SHELL` only reflects the login shell, not the shell currently in use.

_Function has no arguments._

#### Exit codes

- **0**: Always.

#### Output on stdout

- Shell name, or "unknown".
