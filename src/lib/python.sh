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
#   - On Linux: Uses apt-get, yum, or dnf (detected automatically).
#   - On macOS: Uses Homebrew.
#   If Python is already installed, it skips the installation.
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

    # Check if Python is already installed
    if shell::is_command_available "$python_version"; then
        shell::colored_echo "🟡 Python 3 is already installed. Skipping." 33
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
        shell::colored_echo "🟢 Python 3 installed successfully." 46
    elif [ "$dry_run" = "false" ]; then
        shell::colored_echo "🔴 Error: Python 3 installation failed." 31
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
#   Uninstalls Python 3 using the appropriate package manager:
#   - On Linux: Removes python3 via apt-get, yum, or dnf.
#   - On macOS: Removes Python via Homebrew.
#   Does not remove user-installed packages (see shell::removal_python_deps).
#
# Example:
#   shell::removal_python       # Removes Python 3.
#   shell::removal_python -n    # Prints the removal command without executing it.
#
# Notes:
#   - Requires sudo privileges.
#   - May disrupt system tools relying on Python.
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
        if shell::is_command_available apt-get; then
            if shell::is_package_installed_linux "$package"; then
                shell::execute_or_evict "$dry_run" "sudo apt-get remove -y $package"
            else
                shell::colored_echo "🟡 Python 3 is not installed via apt-get. Skipping." 33
            fi
        elif shell::is_command_available yum; then
            if rpm -q shell::is_package_installed_linux "$package"; then
                shell::execute_or_evict "$dry_run" "sudo yum remove -y $package"
            else
                shell::colored_echo "🟡 Python 3 is not installed via yum. Skipping." 33
            fi
        elif shell::is_command_available dnf; then
            if rpm -q "$package" >/dev/null 2>&1; then
                shell::execute_or_evict "$dry_run" "sudo dnf remove -y $package"
            else
                shell::colored_echo "🟡 Python 3 is not installed via dnf. Skipping." 33
            fi
        else
            shell::colored_echo "🔴 Error: Unsupported package manager on Linux." 31
            return 1
        fi
    elif [ "$os_type" = "macos" ]; then
        if shell::is_command_available brew; then
            if brew list --versions python3 >/dev/null 2>&1; then
                shell::execute_or_evict "$dry_run" "brew uninstall python3"
            else
                shell::colored_echo "🟡 Python 3 is not installed via Homebrew. Skipping." 33
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
        shell::colored_echo "🟢 Python 3 removed successfully." 46
    fi
}
