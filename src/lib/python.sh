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

# shell::removal_python function
# Removes Python (python3) and its core components from the system.
#
# Usage:
#   shell::removal_python [-n]
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
#   shell::removal_python       # Removes Python 3.
#   shell::removal_python -n    # Prints the removal command without executing it.
#
# Notes:
#   - Requires sudo privileges.
#   - On Linux, system tools may break if Python is a core dependency; use with caution.
shell::removal_python() {
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

# shell::removal_python_pip_deps() {
#     echo "WARNING: This will uninstall ALL pip and pip3 packages, including system packages."
#     echo "This is potentially dangerous and could break your system Python installation."
#     echo "Are you absolutely sure you want to proceed? (yes/no)"
#     read confirmation
#     if [[ $confirmation == "y" || $confirmation == "Y" ]]; then
#         echo "Uninstalling pip packages..."

#         # For pip (Python 2)
#         if command -v pip &>/dev/null; then
#             # Create a temporary file to store package names
#             PIP_PACKAGES=$(mktemp)
#             pip freeze --break-system-packages | grep -v "^-e" | grep -v "@" | cut -d= -f1 >"$PIP_PACKAGES"

#             if [ -s "$PIP_PACKAGES" ]; then
#                 xargs pip uninstall --break-system-packages -y <"$PIP_PACKAGES"
#                 echo "All pip packages have been uninstalled."
#             else
#                 echo "No valid pip packages found to uninstall."
#             fi

#             # Clean up
#             rm "$PIP_PACKAGES"
#         else
#             echo "pip is not installed."
#         fi

#         # For pip3 (Python 3)
#         if command -v pip3 &>/dev/null; then
#             # Create a temporary file to store package names
#             PIP3_PACKAGES=$(mktemp)
#             pip3 freeze --break-system-packages | grep -v "^-e" | grep -v "@" | cut -d= -f1 >"$PIP3_PACKAGES"

#             if [ -s "$PIP3_PACKAGES" ]; then
#                 xargs pip3 uninstall --break-system-packages -y <"$PIP3_PACKAGES"
#                 echo "All pip3 packages have been uninstalled."
#             else
#                 echo "No valid pip3 packages found to uninstall."
#             fi

#             # Clean up
#             rm "$PIP3_PACKAGES"
#         else
#             echo "pip3 is not installed."
#         fi

#         echo "Operation completed."
#     else
#         echo "Operation canceled."
#     fi
# }

# shell::removal_python_pip_deps function
# Uninstalls all pip and pip3 packages with user confirmation and optional dry-run.
#
# Usage:
#   shell::removal_python_pip_deps [-n]
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
#   shell::removal_python_pip_deps       # Uninstalls all pip/pip3 packages after confirmation
#   shell::removal_python_pip_deps -n    # Dry-run to preview commands
#
# Instructions:
#   1. Run the function with or without the -n flag.
#   2. Confirm the action when prompted (yes/y/Yes accepted).
#
# Notes:
#   - Use with caution: Uninstalling system packages may break your Python environment.
#   - Supports asynchronous execution via shell::async, though kept synchronous for user feedback.
#   - Temporary files are cleaned up automatically.
shell::removal_python_pip_deps() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    shell::colored_echo "🟡 WARNING: This will uninstall all pip and pip3 packages, including system packages." 33
    shell::colored_echo "🟡 This is potentially dangerous and could break your system Python installation." 33
    shell::colored_echo "🟡 Are you absolutely sure you want to proceed? (yes/no)" 33
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
                    shell::on_evict "$freeze_cmd"
                    shell::on_evict "$uninstall_cmd"
                    shell::on_evict "rm $packages_file"
                else
                    shell::run_cmd_eval "$freeze_cmd"
                    if [ -s "$packages_file" ]; then
                        shell::run_cmd_eval "$uninstall_cmd"
                        if [ $? -eq 0 ]; then
                            shell::colored_echo "🟢 All $pip_cmd packages uninstalled successfully." 32
                        else
                            shell::colored_echo "🔴 Errors occurred while uninstalling $pip_cmd packages." 31
                        fi
                    else
                        shell::colored_echo "🟡 No valid $pip_cmd packages found to uninstall." 33
                    fi
                    rm "$packages_file"
                fi
            else
                shell::colored_echo "🟡 $pip_cmd is not installed." 33
            fi
        }

        # Check if pip and pip3 are the same to avoid redundant uninstallation
        if shell::is_command_available pip && shell::is_command_available pip3; then
            if [ "$(command -v pip)" = "$(command -v pip3)" ]; then
                shell::colored_echo "🟡 pip and pip3 are the same; uninstalling once." 33
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
            shell::colored_echo "🟡 Neither pip nor pip3 is installed." 33
        fi

        shell::colored_echo "🟢 Operation completed." 32
    else
        shell::colored_echo "🔴 Operation canceled by user." 31
    fi
}
