# dependency/nvm.sh

Find, load, install and remove nvm (Node Version Manager).

## Overview

nvm is a **shell function**, not a program: `nvm use` changes the PATH of the
shell it runs in, so it cannot be started as a child process and has to be
_sourced_ (`. "$NVM_DIR/nvm.sh"`). That is what shell::dependency::nvm::load
does, once, so every `shell::nvm::*` command can call `nvm` in the current
shell, where `use` and `deactivate` keep their effect.

nvm is looked for in `$NVM_DIR`, `~/.nvm`, `$XDG_CONFIG_HOME/nvm` and the
Homebrew prefixes (`brew install nvm`). It is loaded with `--no-use`, so
loading never switches your Node version or slows anything down.

The commands themselves are in lang/nvm.sh (shell::nvm::\*). The name
`shell::nvm::install` is `nvm install <version>`, which is why installing nvm
itself is `shell::dependency::nvm::install`.

## Index

- [dependency/nvm.sh](#dependencynvmsh)
  - [Overview](#overview)
  - [Index](#index)
    - [shell::dependency::nvm::path](#shelldependencynvmpath)
      - [Example](#example)
      - [Exit codes](#exit-codes)
      - [Output on stdout](#output-on-stdout)
    - [shell::dependency::nvm::load](#shelldependencynvmload)
      - [Example](#example-1)
      - [Exit codes](#exit-codes-1)
      - [See also](#see-also)
    - [shell::dependency::nvm::install](#shelldependencynvminstall)
      - [Example](#example-2)
      - [Options](#options)
      - [Exit codes](#exit-codes-2)
      - [See also](#see-also-1)
    - [shell::dependency::nvm::uninstall](#shelldependencynvmuninstall)
      - [Example](#example-3)
      - [Options](#options-1)
      - [Exit codes](#exit-codes-3)
      - [See also](#see-also-2)

### shell::dependency::nvm::path

Print the path of nvm's `nvm.sh`, searching the usual places.
Order: `$NVM_DIR`, `~/.nvm`, `$XDG_CONFIG_HOME/nvm` (default `~/.config/nvm`),
then the Homebrew prefixes for Apple Silicon, Intel and Linux.

#### Example

```bash
nvm_sh="$(shell::dependency::nvm::path)" || echo "no nvm"
```

_Function has no arguments._

#### Exit codes

- **0**: nvm.sh was found.
- **3**: nvm is not installed.

#### Output on stdout

- Absolute path to `nvm.sh`.

### shell::dependency::nvm::load

Make the `nvm` function available in the current shell.
Does nothing when `nvm` is already a function (for instance because your
profile loaded it). Otherwise it sources `nvm.sh` with `--no-use`, after
exporting `NVM_DIR` (the directory of nvm.sh, or `~/.nvm` when nvm comes from
Homebrew, whose nvm.sh lives outside your data directory).

#### Example

```bash
shell::dependency::nvm::load && nvm --version
```

_Function has no arguments._

#### Exit codes

- **0**: `nvm` is available.
- **3**: nvm is not installed (install it with shell::dependency::nvm::install).

#### See also

- [shell::dependency::nvm::install](#shelldependencynvminstall)

### shell::dependency::nvm::install

Install nvm with its official installer, then load it.
The installer is pinned to a release (`SHELL_NVM_VERSION`) and run only after
it was downloaded completely. It adds the loader lines to your shell profile,
unless `--no-profile` is given. Nothing happens when nvm is already installed.

#### Example

```bash
shell::dependency::nvm::install
shell::dependency::nvm::install -n -v v0.40.8
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the installer command instead of running it.

- **-v** | **--version**

  Release to install, e.g. `v0.40.8` (default: SHELL_NVM_VERSION).

- **-p** | **--no-profile**

  Do not touch your shell profile (`PROFILE=/dev/null`).

#### Exit codes

- **0**: Installed, already installed, or dry-run printed.
- **1**: The installer failed.
- **2**: Invalid option or version.

#### See also

- [shell::dependency::nvm::uninstall](#shelldependencynvmuninstall)

### shell::dependency::nvm::uninstall

Remove nvm, **every Node version installed through it**, and its
loader lines from your shell profile.
Safety rules: only a directory that contains `nvm.sh` is removed; `/`, your
home directory and relative paths are refused; an nvm installed by
Homebrew is left to `brew uninstall nvm`. Each profile file that is changed
keeps a copy named `<file>.nvm-backup`. You are asked first unless `-y`.

#### Example

```bash
shell::dependency::nvm::uninstall -n
shell::dependency::nvm::uninstall -y
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print what would be removed instead of removing it.

- **-y** | **--yes**

  Do not ask for confirmation.

#### Exit codes

- **0**: Removed, nothing to remove, or the user declined.
- **1**: A removal step failed.
- **2**: Invalid option, or `NVM_DIR` is not a safe directory to delete.

#### See also

- [shell::dependency::nvm::install](#shelldependencynvminstall)
