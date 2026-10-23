# dependency/homebrew.sh

Install, activate and remove Homebrew.

## Overview

Homebrew is the macOS package manager (and optional on Linux). The
installer is downloaded to a temporary file and only executed when the
download succeeded; `bash -c "$(curl ...)"` would happily run an empty
script when curl fails.

## Index

* [shell::homebrew::activate](#shellhomebrewactivate)
* [shell::homebrew::install](#shellhomebrewinstall)
* [shell::homebrew::uninstall](#shellhomebrewuninstall)

### shell::homebrew::activate

Add Homebrew to PATH for the *current* shell session.
A fresh Apple-Silicon install lives in /opt/homebrew, which is not on PATH
until `brew shellenv` runs. Without this, the very next `brew install`
fails with "command not found".

_Function has no arguments._

#### Exit codes

* **0**: brew is now on PATH.
* **3**: brew is not installed.

### shell::homebrew::install

Install Homebrew with the official installer.

#### Example

```bash
shell::homebrew::install
shell::homebrew::install -n
```

#### Options

* **-h** | **--help**

  Show help and return.

* **-n** | **--dry-run**

  Print the installer command instead of running it.

#### Exit codes

* **0**: Homebrew is installed (or dry-run printed).
* **1**: The installer failed.

### shell::homebrew::uninstall

Uninstall Homebrew and remove its lines from the shell profile.
Asks for confirmation unless `-y` is given, because the official
uninstaller removes every formula and cask.

#### Example

```bash
shell::homebrew::uninstall -y
```

#### Options

* **-h** | **--help**

  Show help and return.

* **-n** | **--dry-run**

  Print the commands instead of running them.

* **-y** | **--yes**

  Do not ask for confirmation.

#### Exit codes

* **0**: Homebrew was removed, was absent, or the user declined.
* **1**: The uninstaller failed.

