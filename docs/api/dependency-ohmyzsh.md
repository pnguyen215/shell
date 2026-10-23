# dependency/ohmyzsh.sh

Install and remove Oh My Zsh.

## Overview

Install Oh My Zsh with the official installer.
The installer is run with `RUNZSH=no` so it does not `exec zsh` at the end,
which would replace (and effectively kill) the shell running this function.

## Index

- [shell::ohmyzsh::install](#shellohmyzshinstall)
- [shell::ohmyzsh::uninstall](#shellohmyzshuninstall)

### shell::ohmyzsh::install

Install Oh My Zsh with the official installer.
The installer is run with `RUNZSH=no` so it does not `exec zsh` at the end,
which would replace (and effectively kill) the shell running this function.

#### Example

```bash
shell::ohmyzsh::install
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the installer command instead of running it.

#### Exit codes

- **0**: Installed, already installed, or dry-run printed.
- **1**: The installer failed.

### shell::ohmyzsh::uninstall

Uninstall Oh My Zsh and restore the original `.zshrc` backup.
Asks for confirmation unless `-y` is given.

#### Example

```bash
shell::ohmyzsh::uninstall -y
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the commands instead of running them.

- **-y** | **--yes**

  Do not ask for confirmation.

#### Exit codes

- **0**: Removed, absent, or the user declined.
- **1**: A removal step failed.
