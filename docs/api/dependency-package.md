# dependency/package.sh

Native package-manager abstraction (apt, dnf, yum, pacman, zypper, apk, brew).

## Overview

One interface over every supported package manager. Commands are built as
argv arrays and executed through `shell::exec::command`, so package names are
never re-parsed by `eval` (the previous version interpolated the name into
an `eval`'d string).

Snap is intentionally NOT used: snap packages are sandboxed (a snap-installed
`jq`/`fzf` cannot read files outside `$HOME`) and several names do not exist
there.

## Index

- [shell::package::manager](#shellpackagemanager)
- [shell::package::is_installed](#shellpackageis_installed)
- [shell::package::install](#shellpackageinstall)
- [shell::package::uninstall](#shellpackageuninstall)

### shell::package::manager

Print the native package manager for this machine.

#### Example

```bash
[ "$(shell::package::manager)" = "apt" ] && echo "Debian family"
```

_Function has no arguments._

#### Exit codes

- **0**: A package manager was found.
- **3**: No supported package manager is available.

#### Output on stdout

- One of: `brew`, `apt`, `dnf`, `yum`, `pacman`, `zypper`, `apk`, unknown.

### shell::package::is_installed

Test whether a package is installed in the native package database.
This queries the _package manager_, not PATH. To test for a command use
shell::command::exists.

#### Example

```bash
shell::package::is_installed git && echo "git package present"
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Arguments

- **$1** (string): Package name.

#### Exit codes

- **0**: The package is installed.
- **1**: The package is not installed.
- **2**: No package name was given.
- **3**: No supported package manager was found.

### shell::package::install

Install one or more packages with the native package manager.
Already-installed packages are skipped. On apt the package index is
refreshed at most once per shell session.

#### Example

```bash
shell::package::install jq
shell::package::install -n fzf git
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the commands instead of running them.

#### Arguments

- **...** (string): Package names.

#### Exit codes

- **0**: Every package is installed (or dry-run printed).
- **1**: An installation failed.
- **2**: No package name was given.
- **3**: No package manager (or required `sudo`) is available.

### shell::package::uninstall

Remove one or more packages with the native package manager.
Packages that are not installed are skipped with a warning.

#### Example

```bash
shell::package::uninstall jq
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the commands instead of running them.

#### Arguments

- **...** (string): Package names.

#### Exit codes

- **0**: Every package is removed (or was already absent).
- **1**: A removal failed.
- **2**: No package name was given.
- **3**: No package manager (or required `sudo`) is available.
