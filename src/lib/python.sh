#!/bin/bash
# python.sh

# shell::install_python function
# Installs Python (python3) on macOS or Linux.
#
# Usage:
#   shell::install_python [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#
# Description:
#   Installs Python 3 using the appropriate package manager based on the OS:
#   - On Linux: Uses apt-get, yum, or dnf (detected automatically), with a specific check for package installation state.
#   - On macOS: Uses Homebrew, checking Homebrew's package list.
#   Skips installation only if Python is confirmed installed via the package manager.
#
# Example:
#   shell::install_python       # Installs Python 3.
#   shell::install_python -n    # Prints the installation command without executing it.
shell::install_python() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    local os_type
    os_type=$(shell::get_os_type)
    local python_version="python3"
    local is_installed="false"

    # Check installation state more precisely
    if [ "$os_type" = "linux" ]; then
        if shell::is_command_available apt-get && shell::is_package_installed_linux "python3"; then
            is_installed="true"
        elif shell::is_command_available yum && rpm -q "python3" >/dev/null 2>&1; then
            is_installed="true"
        elif shell::is_command_available dnf && rpm -q "python3" >/dev/null 2>&1; then
            is_installed="true"
        fi
    elif [ "$os_type" = "macos" ]; then
        if shell::is_command_available brew && brew list --versions python3 >/dev/null 2>&1; then
            is_installed="true"
        fi
    fi

    if [ "$is_installed" = "true" ]; then
        shell::colored_echo "🟡 Python3 is already installed via package manager. Skipping." 33
        return 0
    fi

    if [ "$os_type" = "linux" ]; then
        local package="python3"
        local cmd=""
        if shell::is_command_available apt-get; then
            cmd="sudo apt-get update && sudo apt-get install -y $package"
        elif shell::is_command_available yum; then
            cmd="sudo yum install -y $package"
        elif shell::is_command_available dnf; then
            cmd="sudo dnf install -y $package"
        else
            shell::colored_echo "🔴 Error: Unsupported package manager on Linux." 31
            return 1
        fi
        shell::execute_or_evict "$dry_run" "$cmd"
    elif [ "$os_type" = "macos" ]; then
        if ! shell::is_command_available brew; then
            shell::colored_echo "🍎 Installing Homebrew first..." 32
            shell::install_homebrew
        fi
        shell::execute_or_evict "$dry_run" "brew install python3"
    else
        shell::colored_echo "🔴 Error: Unsupported operating system." 31
        return 1
    fi

    # Verify installation
    if [ "$dry_run" = "false" ] && shell::is_command_available "$python_version"; then
        shell::colored_echo "🟢 Python3 installed successfully." 46
    elif [ "$dry_run" = "false" ]; then
        shell::colored_echo "🔴 Error: Python3 installation failed." 31
        return 1
    fi
}

# shell::uninstall_python function
# Removes Python (python3) and its core components from the system.
#
# Usage:
#   shell::uninstall_python [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#
# Description:
#   Thoroughly uninstalls Python 3 using the appropriate package manager:
#   - On Linux: Uses `purge` with apt-get or `remove` with yum/dnf, followed by autoremove to clean dependencies.
#   - On macOS: Uses Homebrew with cleanup to remove all traces.
#   Warns about potential system impact on Linux due to Python dependencies.
#
# Example:
#   shell::uninstall_python       # Removes Python 3.
#   shell::uninstall_python -n    # Prints the removal command without executing it.
#
# Notes:
#   - Requires sudo privileges.
#   - On Linux, system tools may break if Python is a core dependency; use with caution.
shell::uninstall_python() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    local os_type
    os_type=$(shell::get_os_type)

    if [ "$os_type" = "linux" ]; then
        local package="python3"
        shell::colored_echo "🟡 Warning: Removing Python3 may break system tools on Linux. Proceed with caution." 33
        if shell::is_command_available apt-get; then
            if shell::is_package_installed_linux "$package"; then
                shell::execute_or_evict "$dry_run" "sudo apt-get purge -y $package && sudo apt-get autoremove -y"
            else
                shell::colored_echo "🟡 Python3 is not installed via apt-get. Skipping." 33
            fi
        elif shell::is_command_available yum; then
            if rpm -q "$package" >/dev/null 2>&1; then
                shell::execute_or_evict "$dry_run" "sudo yum remove -y $package"
            else
                shell::colored_echo "🟡 Python3 is not installed via yum. Skipping." 33
            fi
        elif shell::is_command_available dnf; then
            if rpm -q "$package" >/dev/null 2>&1; then
                shell::execute_or_evict "$dry_run" "sudo dnf remove -y $package"
            else
                shell::colored_echo "🟡 Python3 is not installed via dnf. Skipping." 33
            fi
        else
            shell::colored_echo "🔴 Error: Unsupported package manager on Linux." 31
            return 1
        fi
    elif [ "$os_type" = "macos" ]; then
        if shell::is_command_available brew; then
            if brew list --versions python3 >/dev/null 2>&1; then
                shell::execute_or_evict "$dry_run" "brew uninstall python3 && brew cleanup"
            else
                shell::colored_echo "🟡 Python3 is not installed via Homebrew. Skipping." 33
            fi
        else
            shell::colored_echo "🔴 Error: Homebrew is not installed on macOS." 31
            return 1
        fi
    else
        shell::colored_echo "🔴 Error: Unsupported operating system." 31
        return 1
    fi

    if [ "$dry_run" = "false" ] && ! shell::is_command_available python3; then
        shell::colored_echo "🟢 Python3 removed successfully." 46
    elif [ "$dry_run" = "false" ]; then
        shell::colored_echo "🟡 Python3 binary still detected. Manual cleanup may be required." 33
    fi
}

# shell::uninstall_python_pip_deps function
# Uninstalls all pip and pip3 packages with user confirmation and optional dry-run.
#
# Usage:
#   shell::uninstall_python_pip_deps [-n]
#
# Parameters:
#   -n: Optional flag to perform a dry-run (uses shell::on_evict to print commands without executing).
#
# Description:
#   This function uninstalls all packages installed via pip and pip3, including system packages,
#   after user confirmation. It is designed to work on both Linux and macOS, with safety checks
#   and enhanced logging using shell::run_cmd_eval.
#
# Example usage:
#   shell::uninstall_python_pip_deps       # Uninstalls all pip/pip3 packages after confirmation
#   shell::uninstall_python_pip_deps -n    # Dry-run to preview commands
#
# Instructions:
#   1. Run the function with or without the -n flag.
#   2. Confirm the action when prompted (yes/y/Yes accepted).
#
# Notes:
#   - Use with caution: Uninstalling system packages may break your Python environment.
#   - Supports asynchronous execution via shell::async, though kept synchronous for user feedback.
#   - Temporary files are cleaned up automatically.
shell::uninstall_python_pip_deps() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    shell::colored_echo "🟡 WARNING: This will uninstall all pip and pip3 packages, including system packages." 11
    shell::colored_echo "🟡 This is potentially dangerous and could break your system Python installation." 11
    shell::colored_echo "🟡 Are you absolutely sure you want to proceed? (yes/no)" 11
    read -r confirmation
    if [[ $confirmation =~ ^[Yy](es)?$ ]]; then
        shell::colored_echo "🟢 Proceeding with uninstallation..." 32

        # Helper function to uninstall packages for a given pip command
        uninstall_packages() {
            local pip_cmd="$1"
            if shell::is_command_available "$pip_cmd"; then
                shell::colored_echo "🔍 Processing $pip_cmd packages..." 36
                local packages_file
                packages_file=$(mktemp)
                local freeze_cmd="$pip_cmd freeze --break-system-packages | grep -v '^-e' | grep -v '@' | cut -d= -f1 > $packages_file"
                local uninstall_cmd="xargs $pip_cmd uninstall --break-system-packages -y < $packages_file"

                if [ "$dry_run" = "true" ]; then
                    shell::on_evict "$freeze_cmd && $uninstall_cmd && rm $packages_file"
                    # shell::on_evict "$uninstall_cmd"
                    # shell::on_evict "rm $packages_file"
                else
                    shell::run_cmd_eval "$freeze_cmd"
                    if [ -s "$packages_file" ]; then
                        shell::run_cmd_eval "$uninstall_cmd"
                        if [ $? -eq 0 ]; then
                            shell::colored_echo "🟢 All $pip_cmd packages uninstalled successfully." 46
                        else
                            shell::colored_echo "🔴 Errors occurred while uninstalling $pip_cmd packages." 196
                        fi
                    else
                        shell::colored_echo "🟡 No valid $pip_cmd packages found to uninstall." 11
                    fi
                    rm "$packages_file"
                fi
            else
                shell::colored_echo "🟡 $pip_cmd is not installed." 11
            fi
        }

        # Check if pip and pip3 are the same to avoid redundant uninstallation
        if shell::is_command_available pip && shell::is_command_available pip3; then
            if [ "$(command -v pip)" = "$(command -v pip3)" ]; then
                shell::colored_echo "🟡 pip and pip3 are the same; uninstalling once." 11
                uninstall_packages "pip"
            else
                uninstall_packages "pip"
                uninstall_packages "pip3"
            fi
        elif shell::is_command_available pip; then
            uninstall_packages "pip"
        elif shell::is_command_available pip3; then
            uninstall_packages "pip3"
        else
            shell::colored_echo "🟡 Neither pip nor pip3 is installed." 11
        fi

        shell::colored_echo "🟢 Operation completed." 46
    else
        shell::colored_echo "🔴 Operation canceled by user." 196
    fi
}

# shell::uninstall_python_pip_deps::latest function
# Uninstalls all pip and pip3 packages with user confirmation and optional dry-run.
#
# Usage:
#   shell::uninstall_python_pip_deps::latest [-n]
#
# Parameters:
#   -n: Optional flag to perform a dry-run (uses shell::on_evict to print commands without executing).
#
# Description:
#   This function uninstalls all packages installed via pip and pip3, including system packages,
#   after user confirmation. It is designed to work on both Linux and macOS, with safety checks.
#   In non-dry-run mode, it executes the uninstallation commands asynchronously using shell::async,
#   ensuring that the function returns once the background process completes.
#
# Example usage:
#   shell::uninstall_python_pip_deps::latest       # Uninstalls all pip/pip3 packages after confirmation
#   shell::uninstall_python_pip_deps::latest -n    # Dry-run to preview commands
#
# Notes:
#   - Use with caution: Uninstalling system packages may break your Python environment.
#   - Supports asynchronous execution via shell::async for non-blocking uninstallation.
shell::uninstall_python_pip_deps::latest() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    shell::colored_echo "🟡 WARNING: This will uninstall all pip and pip3 packages, including system packages." 11
    shell::colored_echo "🟡 This is potentially dangerous and could break your system Python installation." 11
    shell::colored_echo "🟡 Are you absolutely sure you want to proceed? (yes/no)" 11
    read -r confirmation
    if [[ $confirmation =~ ^[Yy](es)?$ ]]; then
        shell::colored_echo "🟢 Proceeding with uninstallation..." 32

        # Helper function to uninstall packages for a given pip command asynchronously.
        uninstall_packages() {
            local pip_cmd="$1"
            if shell::is_command_available "$pip_cmd"; then
                shell::colored_echo "🔍 Processing $pip_cmd packages asynchronously..." 36
                local packages_file
                packages_file=$(mktemp)
                # Build command to capture installed packages (ignoring editable installs and VCS links)
                local freeze_cmd="$pip_cmd freeze --break-system-packages | grep -v '^-e' | grep -v '@' | cut -d= -f1 > $packages_file"
                # Build uninstallation command that reads the package list and removes packages
                local uninstall_cmd="xargs $pip_cmd uninstall --break-system-packages -y < $packages_file"
                if [ "$dry_run" = "true" ]; then
                    shell::on_evict "$freeze_cmd && $uninstall_cmd && rm $packages_file"
                else
                    # Execute the freeze command synchronously to capture the list of packages
                    shell::run_cmd_eval "$freeze_cmd"
                    if [ -s "$packages_file" ]; then
                        # Run the uninstallation command asynchronously
                        shell::async "$uninstall_cmd && rm $packages_file" &
                        wait $! # Wait for the asynchronous process to finish
                        if [ $? -eq 0 ]; then
                            shell::colored_echo "🟢 All $pip_cmd packages uninstalled successfully." 46
                        else
                            shell::colored_echo "🔴 Errors occurred while uninstalling $pip_cmd packages." 196
                        fi
                    else
                        shell::colored_echo "🟡 No valid $pip_cmd packages found to uninstall." 11
                    fi
                    # Clean up the temporary file if it still exists
                    [ -f "$packages_file" ] && rm "$packages_file"
                fi
            else
                shell::colored_echo "🟡 $pip_cmd is not installed." 11
            fi
        }

        # Check if pip and pip3 are the same to avoid redundant uninstallation
        if shell::is_command_available pip && shell::is_command_available pip3; then
            if [ "$(command -v pip)" = "$(command -v pip3)" ]; then
                shell::colored_echo "🟡 pip and pip3 are the same; uninstalling once." 11
                uninstall_packages "pip"
            else
                uninstall_packages "pip"
                uninstall_packages "pip3"
            fi
        elif shell::is_command_available pip; then
            uninstall_packages "pip"
        elif shell::is_command_available pip3; then
            uninstall_packages "pip3"
        else
            shell::colored_echo "🟡 Neither pip nor pip3 is installed." 11
        fi

        shell::colored_echo "🟢 Operation completed." 46
    else
        shell::colored_echo "🔴 Operation canceled by user." 196
    fi
}

# shell::create_python_env function
# Creates a Python virtual environment for development, isolating it from system packages.
#
# Usage:
#   shell::create_python_env [-n] [-p <path>] [-v <version>]
#
# Parameters:
#   - -n          : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -p <path>   : Optional. Specifies the path where the virtual environment will be created (defaults to ./venv).
#   - -v <version>: Optional. Specifies the Python version (e.g., 3.10); defaults to system Python3.
#
# Description:
#   This function sets up a Python virtual environment to avoid package conflicts with the system OS:
#   - Ensures Python3 and pip are installed using shell::install_python.
#   - Creates a virtual environment at the specified or default path using the specified or default Python version.
#   - Upgrades pip and installs basic tools (wheel, setuptools) in the virtual environment.
#   - Supports asynchronous execution for pip upgrades to speed up setup.
#   - Verifies the environment and provides activation instructions.
#
# Example:
#   shell::create_python_env                # Creates a virtual env at ./venv with default Python3.
#   shell::create_python_env -n             # Prints commands without executing them.
#   shell::create_python_env -p ~/my_env     # Creates a virtual env at ~/my_env.
#   shell::create_python_env -v 3.10        # Uses Python 3.10 for the virtual env.
#
# Notes:
#   - Requires Python3 to be available on the system.
#   - On Linux, uses python3-venv package if needed.
#   - Activation command is copied to clipboard for convenience.
shell::create_python_env() {
    local dry_run="false"
    local venv_path="./venv"
    local python_version="python3"

    # Parse optional arguments
    while [ $# -gt 0 ]; do
        case "$1" in
        -n)
            dry_run="true"
            shift
            ;;
        -p)
            venv_path="$2"
            shift 2
            ;;
        -v)
            python_version="python$2"
            shift 2
            ;;
        *)
            shell::colored_echo "🔴 Error: Unknown option '$1'. Usage: shell::create_python_env [-n] [-p <path>] [-v <version>]" 196
            return 1
            ;;
        esac
    done

    local os_type
    os_type=$(shell::get_os_type)

    # Ensure Python is installed
    if ! shell::is_command_available "$python_version"; then
        shell::colored_echo "🔍 Installing $python_version..." 36
        if [ "$os_type" = "linux" ]; then
            shell::execute_or_evict "$dry_run" "shell::install_python"
            # Ensure python3-venv is installed on Linux for virtual env support
            if ! shell::is_package_installed_linux "$python_version-venv"; then
                shell::execute_or_evict "$dry_run" "shell::install_package $python_version-venv"
            fi
        elif [ "$os_type" = "macos" ]; then
            shell::execute_or_evict "$dry_run" "shell::install_python"
        else
            shell::colored_echo "🔴 Error: Unsupported operating system." 31
            return 1
        fi
    fi

    # Check if virtual environment already exists
    if [ -d "$venv_path" ] && [ "$dry_run" = "false" ]; then
        shell::colored_echo "🟡 Virtual environment already exists at '$venv_path'. Skipping creation." 33
    else
        # Create the virtual environment
        local create_cmd="$python_version -m venv \"$venv_path\""
        shell::colored_echo "🔍 Creating virtual environment at '$venv_path' with $python_version..." 36
        shell::execute_or_evict "$dry_run" "$create_cmd"
    fi

    # Define activation path based on OS
    local activate_cmd
    if [ "$os_type" = "macos" ] || [ "$os_type" = "linux" ]; then
        activate_cmd="source \"$venv_path/bin/activate\""
    else
        shell::colored_echo "🔴 Error: Unsupported OS for activation path." 31
        return 1
    fi

    # Upgrade pip and install basic tools asynchronously
    if [ "$dry_run" = "false" ] && [ -d "$venv_path" ]; then
        local pip_cmd="$venv_path/bin/pip"
        if shell::is_command_available "$pip_cmd"; then
            shell::colored_echo "🔍 Upgrading pip and installing basic tools in the virtual environment..." 36
            local upgrade_cmd="$pip_cmd install --upgrade pip wheel setuptools"
            shell::async "$upgrade_cmd" &
            wait $! # Wait for async process to complete
            if [ $? -eq 0 ]; then
                shell::colored_echo "🟢 Pip and tools upgraded successfully." 46
            else
                shell::colored_echo "🔴 Warning: Failed to upgrade pip/tools." 31
            fi
        else
            shell::colored_echo "🔴 Error: pip not found in virtual environment." 31
            return 1
        fi
    elif [ "$dry_run" = "true" ]; then
        shell::on_evict "$venv_path/bin/pip install --upgrade pip wheel setuptools"
    fi

    # Verify and provide activation instructions
    if [ "$dry_run" = "false" ] && [ -f "$venv_path/bin/activate" ]; then
        shell::colored_echo "🟢 Virtual environment created successfully at '$venv_path'." 46
        shell::colored_echo "🔑 To activate, run: $activate_cmd" 33
        shell::clip_value "$activate_cmd"
    elif [ "$dry_run" = "false" ]; then
        shell::colored_echo "🔴 Error: Failed to create virtual environment." 31
        return 1
    fi
}

# shell::install_pkg_python_env function
# Installs Python packages into an existing virtual environment using pip, avoiding system package conflicts.
#
# Usage:
#   shell::install_pkg_python_env [-n] [-p <path>] <package1> [package2 ...]
#
# Parameters:
#   - -n          : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -p <path>   : Optional. Specifies the path to the virtual environment (defaults to ./venv).
#   - <package1> [package2 ...] : One or more Python package names to install (e.g., numpy, requests).
#
# Description:
#   This function installs specified Python packages into an existing virtual environment:
#   - Verifies the virtual environment exists at the specified or default path.
#   - Uses the virtual environment's pip to install packages, ensuring isolation from system Python.
#   - Supports asynchronous execution for package installation to improve performance.
#   - Provides feedback on success or failure, with dry-run support for previewing commands.
#
# Example:
#   shell::install_pkg_python_env numpy pandas    # Installs numpy and pandas in ./venv.
#   shell::install_pkg_python_env -n requests     # Prints installation command without executing.
#   shell::install_pkg_python_env -p ~/my_env flask  # Installs flask in ~/my_env.
#
# Notes:
#   - Requires an existing virtual environment (use shell::create_python_env to create one if needed).
#   - Assumes pip is available in the virtual environment (upgraded by shell::create_python_env).
#   - Compatible with both Linux (Ubuntu 22.04 LTS) and macOS.
shell::install_pkg_python_env() {
    local dry_run="false"
    local venv_path="./venv"
    local packages=()

    # Parse optional arguments
    while [ $# -gt 0 ]; do
        case "$1" in
        -n)
            dry_run="true"
            shift
            ;;
        -p)
            venv_path="$2"
            shift 2
            ;;
        *)
            packages+=("$1")
            shift
            ;;
        esac
    done

    # Validate that at least one package is specified
    if [ ${#packages[@]} -eq 0 ]; then
        shell::colored_echo "🔴 Error: No packages specified. Usage: shell::install_pkg_python_env [-n] [-p <path>] <package1> [package2 ...]" 31
        return 1
    fi

    # Check if the virtual environment exists
    if [ ! -d "$venv_path" ] || [ ! -f "$venv_path/bin/pip" ]; then
        shell::colored_echo "🔴 Error: Virtual environment at '$venv_path' does not exist or is invalid. Create it with shell::create_python_env first." 31
        return 1
    fi

    local os_type
    os_type=$(shell::get_os_type)
    local pip_cmd="$venv_path/bin/pip"

    # Ensure pip command is available
    if ! shell::is_command_available "$pip_cmd"; then
        shell::colored_echo "🔴 Error: pip not found in virtual environment at '$venv_path'." 31
        return 1
    fi

    # Construct the install command
    local install_cmd="$pip_cmd install"
    for pkg in "${packages[@]}"; do
        install_cmd="$install_cmd \"$pkg\""
    done

    # Execute or preview the installation
    shell::colored_echo "🔍 Installing packages (${packages[*]}) into virtual environment at '$venv_path'..." 36
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$install_cmd"
    else
        # Run the installation asynchronously
        shell::async "$install_cmd" &
        local pid=$!
        wait $pid
        if [ $? -eq 0 ]; then
            shell::colored_echo "🟢 Packages installed successfully: ${packages[*]}" 46
        else
            shell::colored_echo "🔴 Error: Failed to install one or more packages." 31
            return 1
        fi
    fi
}
