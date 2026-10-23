# lang/python.sh

Python and virtual-environment helpers.

## Overview

Installs Python (python3) on macOS or Linux.

Installs Python 3 using the appropriate package manager based on the OS:
- On Linux: Uses apt-get, yum, or dnf (detected automatically), with a specific check for package installation state.
- On macOS: Uses Homebrew, checking Homebrew's package list.
Skips installation only if Python is confirmed installed via the package manager.

## Index

* [shell::python::install](#shellpythoninstall)
* [shell::python::is_installed](#shellpythonis_installed)
* [shell::python::uninstall](#shellpythonuninstall)
* [shell::python::pip::uninstall](#shellpythonpipuninstall)
* [shell::python::pip::uninstall::all](#shellpythonpipuninstallall)
* [shell::python::venv::create](#shellpythonvenvcreate)
* [shell::python::venv::pkg::install](#shellpythonvenvpkginstall)
* [shell::python::venv::pkg::uninstall](#shellpythonvenvpkguninstall)
* [shell::python::venv::pkg::uninstall::fzf](#shellpythonvenvpkguninstallfzf)
* [shell::python::venv::activate::fzf](#shellpythonvenvactivatefzf)
* [shell::python::venv::pkg::upgrade](#shellpythonvenvpkgupgrade)
* [shell::python::venv::pkg::upgrade::fzf](#shellpythonvenvpkgupgradefzf)
* [shell::python::venv::pkg::freeze](#shellpythonvenvpkgfreeze)
* [shell::python::venv::pkg::install::requirements](#shellpythonvenvpkginstallrequirements)
* [shell::python::gitignore::add](#shellpythongitignoreadd)

### shell::python::install

Installs Python (python3) on macOS or Linux.

Installs Python 3 using the appropriate package manager based on the OS:
- On Linux: Uses apt-get, yum, or dnf (detected automatically), with a specific check for package installation state.
- On macOS: Uses Homebrew, checking Homebrew's package list.
Skips installation only if Python is confirmed installed via the package manager.

#### Example

```bash
shell::python::install       # Installs Python 3.
shell::python::install -n    # Prints the installation command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.
* **5**: Not implemented.

### shell::python::is_installed

Checks if Python (python3) is installed on the system.

Verifies the installation of Python 3 using the appropriate package manager:
- On Linux: Checks apt-get, yum, or dnf package lists.
- On macOS: Checks Homebrew's package list.
Returns "true" if Python is found, otherwise "false".

#### Example

```bash
shell::python::is_installed  # Outputs "true" or "false" based on installation status.
```

_Function has no arguments._

#### Exit codes

* **0**: Success.

### shell::python::uninstall

Removes Python (python3) and its core components from the system.

Thoroughly uninstalls Python 3 using the appropriate package manager:
- On Linux: Uses `purge` with apt-get or `remove` with yum/dnf, followed by autoremove to clean dependencies.
- On macOS: Uses Homebrew with cleanup to remove all traces.
Warns about potential system impact on Linux due to Python dependencies.

Notes:
- Requires sudo privileges.
- On Linux, system tools may break if Python is a core dependency; use with caution.

#### Example

```bash
shell::python::uninstall       # Removes Python 3.
shell::python::uninstall -n    # Prints the removal command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.
* **5**: Not implemented.

### shell::python::pip::uninstall

Uninstalls all pip and pip3 packages with user confirmation and optional dry-run.

Uninstalls all pip and pip3 packages using the specified pip version.
Prompts for confirmation before uninstalling.

Notes:
- Requires sudo privileges.

#### Example

```bash
shell::python::pip::uninstall pip3       # Uninstalls all pip3 packages.
shell::python::pip::uninstall -n pip3    # Prints the uninstallation command without executing it.
shell::python::pip::uninstall --dry-run pip3  # Prints the uninstallation command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.

* **-h** | **--help**

  Displays this help message.

#### Arguments

* **$1** (string): pip_version: The pip version to uninstall (e.g., pip3, pip).

#### Exit codes

* **0**: Success.
* **2**: Invalid or missing arguments.
* **5**: Not implemented.

### shell::python::pip::uninstall::all

Uninstalls all pip and pip3 packages with user confirmation and optional dry-run.

This function uninstalls all packages installed via pip and pip3, including system packages,
after user confirmation. It is designed to work on both Linux and macOS, with safety checks
and enhanced logging using shell::exec::shell.

Notes:
- Use with caution: Uninstalling system packages may break your Python environment.
- Supports asynchronous execution via shell::exec::async, though kept synchronous for user feedback.
- Temporary files are cleaned up automatically.
1. Run the function with or without the -n flag.
2. Confirm the action when prompted (yes/y/Yes accepted).

#### Example

```bash
shell::python::pip::uninstall::all       # Uninstalls all pip/pip3 packages after confirmation
shell::python::pip::uninstall::all -n    # Dry-run to preview commands
```

#### Options

* **-n**

  Optional flag to perform a dry-run (uses shell::logger::command_clip to print commands without executing).

#### Exit codes

* **0**: Success.
* **5**: Not implemented.

### shell::python::venv::create

Creates a Python virtual environment for development, isolating it from system packages.

This function sets up a Python virtual environment to avoid package conflicts with the system OS:
- Ensures Python3 and pip are installed using shell::python::install.
- Creates a virtual environment at the specified or default path using the specified or default Python version.
- Upgrades pip and installs basic tools (wheel, setuptools) in the virtual environment.
- Supports asynchronous execution for pip upgrades to speed up setup.
- Verifies the environment and provides activation instructions.

Notes:
- Requires Python3 to be available on the system.
- On Linux, uses python3-venv package if needed.
- Activation command is copied to clipboard for convenience.

#### Example

```bash
shell::python::venv::create                # Creates a virtual env at ./venv with default Python3.
shell::python::venv::create -n             # Prints commands without executing them.
shell::python::venv::create -p ~/my_env     # Creates a virtual env at ~/my_env.
shell::python::venv::create -v 3.10        # Uses Python 3.10 for the virtual env.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

* **-p \<path\>**

  Optional. Specifies the path where the virtual environment will be created (defaults to ./venv).

* **-v \<version\>**

  Optional. Specifies the Python version (e.g., 3.10); defaults to system Python3.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::python::venv::pkg::install

Installs Python packages into an existing virtual environment using pip, avoiding system package conflicts.

This function installs specified Python packages into an existing virtual environment:
- Verifies the virtual environment exists at the specified or default path.
- Uses the virtual environment's pip to install packages, ensuring isolation from system Python.
- Supports asynchronous execution for package installation to improve performance.
- Provides feedback on success or failure, with dry-run support for previewing commands.

Notes:
- Requires an existing virtual environment (use shell::python::venv::create to create one if needed).
- Assumes pip is available in the virtual environment (upgraded by shell::python::venv::create).
- Compatible with both Linux (Ubuntu 22.04 LTS) and macOS.

#### Example

```bash
shell::python::venv::pkg::install numpy pandas    # Installs numpy and pandas in ./venv.
shell::python::venv::pkg::install -n requests     # Prints installation command without executing.
shell::python::venv::pkg::install -p ~/my_env flask  # Installs flask in ~/my_env.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

* **-p \<path\>**

  Optional. Specifies the path to the virtual environment (defaults to ./venv). - <package1> [package2 ...] : One or more Python package names to install (e.g., numpy, requests).

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::python::venv::pkg::uninstall

Uninstalls Python packages from a virtual environment using pip or pip3.

This function uninstalls specified Python packages from an existing virtual
environment:
- Verifies the virtual environment exists at the specified or default path.
- Uses the virtual environment's pip to uninstall packages, ensuring
uninstallation is isolated to the virtual environment.
- Supports asynchronous execution for package uninstallation to improve
performance.
- Provides feedback on success or failure, with dry-run support for
previewing commands.

Notes:
- Requires an existing virtual environment (use shell::python::venv::create
to create one if needed).
- Assumes pip is available in the virtual environment.
- Compatible with both Linux (Ubuntu 22.04 LTS) and macOS.

#### Example

```bash
shell::python::venv::pkg::uninstall numpy pandas    # Uninstalls numpy and pandas from ./venv.
shell::python::venv::pkg::uninstall -n requests     # Prints uninstallation command without executing.
shell::python::venv::pkg::uninstall -p ~/my_env flask  # Uninstalls flask from ~/my_env.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

* **-p \<path\>**

  Optional. Specifies the path to the virtual environment (defaults to ./venv). - <package1> [package2 ...] : One or more Python package names to uninstall (e.g., numpy, requests).

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::python::venv::pkg::uninstall::fzf

Interactively uninstalls Python packages from a virtual environment using fzf for package selection.

This function enhances Python package uninstallation by:
- Using fzf to allow interactive selection of packages to uninstall.
- Reusing shell::python::venv::pkg::uninstall to perform the actual uninstallation.
- Supports dry-run and asynchronous execution.

Notes:
- Requires fzf and an existing virtual environment.

#### Example

```bash
shell::python::venv::pkg::uninstall::fzf          # Uninstalls packages from ./venv after interactive selection.
shell::python::venv::pkg::uninstall::fzf -n -p ~/my_env  # Prints uninstallation commands for ~/my_env without executing.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

* **-p \<path\>**

  Optional. Specifies the path to the virtual environment (defaults to ./venv).

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::python::venv::activate::fzf

Interactively selects a Python virtual environment using fzf and activates/deactivates it.

This function enhances virtual environment management by:
- Using fzf to allow interactive selection of a virtual environment.
- Activating the selected virtual environment.
- Providing an option to deactivate the current environment.
- Supports dry-run.

Notes:
- Requires fzf.

#### Example

```bash
shell::python::venv::activate::fzf          # Select and activate a venv from the current directory.
shell::python::venv::activate::fzf -n -p ~/projects  # Prints activation command for a venv in ~/projects without executing.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

* **-p \<path\>**

  Optional. Specifies the parent path to search for virtual environments (defaults to current directory).

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::python::venv::pkg::upgrade

Upgrades Python packages in a virtual environment using pip.

This function upgrades specified Python packages within an existing virtual environment:
- Verifies the virtual environment exists at the specified or default path.
- Uses the virtual environment's pip to upgrade packages.
- Supports dry-run mode to preview commands.
- Implements asynchronous execution for the upgrade process.

Notes:
- Requires an existing virtual environment.
- Assumes pip is available in the virtual environment.

#### Example

```bash
shell::python::venv::pkg::upgrade numpy pandas   # Upgrades numpy and pandas in ./venv.
shell::python::venv::pkg::upgrade -n requests    # Prints upgrade command without executing.
shell::python::venv::pkg::upgrade -p ~/my_env flask  # Upgrades flask in ~/my_env.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

* **-p \<path\>**

  Optional. Specifies the path to the virtual environment (defaults to ./venv). - <package1> [package2 ...]: One or more Python package names to upgrade.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::python::venv::pkg::upgrade::fzf

Interactively upgrades Python packages in a virtual environment using fzf for package selection.

This function provides an interactive way to upgrade Python packages within a virtual environment by:
- Using fzf to allow selection of packages to upgrade.
- Constructing and executing pip upgrade commands.
- Supporting dry-run mode to preview commands.

Notes:
- Requires fzf and an existing virtual environment.

#### Example

```bash
shell::python::venv::pkg::upgrade::fzf          # Upgrades packages in ./venv after interactive selection.
shell::python::venv::pkg::upgrade::fzf -n -p ~/my_env  # Prints upgrade commands for ~/my_env without executing.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

* **-p \<path\>**

  Optional. Specifies the path to the virtual environment (defaults to ./venv).

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::python::venv::pkg::freeze

Exports a list of installed packages and their versions from a Python virtual environment to a requirements.txt file.

This function uses pip freeze to generate a requirements.txt file, capturing the current state of the virtual environment's packages.
- It checks for the existence of the virtual environment.
- It constructs the appropriate pip freeze command.
- It supports dry-run mode to preview the command.
- It implements asynchronous execution for the freeze operation.

Notes:
- Requires an existing virtual environment.
- Assumes pip is available in the virtual environment.

#### Example

```bash
shell::python::venv::pkg::freeze         # Exports requirements from ./venv.
shell::python::venv::pkg::freeze -n -p ~/my_env  # Prints the export command for ~/my_env without executing.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

* **-p \<path\>**

  Optional. Specifies the path to the virtual environment (defaults to ./venv).

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::python::venv::pkg::install::requirements

Installs Python packages from a requirements.txt file into a virtual environment.

This function uses pip install -r to install packages from a requirements.txt file into the specified virtual environment.
- It checks for the existence of the virtual environment and the requirements.txt file.
- It constructs the appropriate pip install command.
- It supports dry-run mode to preview the command.
- It implements asynchronous execution for the installation process.

Notes:
- Requires an existing virtual environment and a requirements.txt file.
- Assumes pip is available in the virtual environment.

#### Example

```bash
shell::python::venv::pkg::install::requirements         # Installs from requirements.txt in ./venv.
shell::python::venv::pkg::install::requirements -n -p ~/my_env  # Prints the installation command for ~/my_env without executing.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

* **-p \<path\>**

  Optional. Specifies the path to the virtual environment (defaults to ./venv).

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::python::gitignore::add

This function downloads the .gitignore file specifically for Python projects.

The .gitignore file is essential for specifying which files and directories
should be ignored by Git, helping to keep the repository clean and free of
unnecessary files that do not need to be tracked.

It utilizes the shell::net::download function to fetch the .gitignore file
from the specified URL and saves it in the appropriate location within the
project structure.

#### Example

```bash
shell::python::gitignore::add
```

_Function has no arguments._

#### Exit codes

* **0**: Success.

