#!/bin/bash
# homebrew.sh

# This script provides functions to install and uninstall Homebrew,
# streamlining the process of managing Homebrew as part of your development
# environment setup on macOS (and Linux if supported).

# shell::install_homebrew function
# Installs Homebrew using the official installation script.
#
# Usage:
#   shell::install_homebrew
#
# Description:
#   This function downloads and executes the official Homebrew installation
#   script via curl. The command is executed using shell::run_cmd_eval, which logs
#   the command before executing it.
#
# Dependencies:
#   - shell::run_cmd_eval: A helper function that logs and executes shell commands.
#
# Example:
#   shell::install_homebrew
shell::install_homebrew() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INSTALL_HOMEBREW"
        return 0
    fi

    shell::run_cmd_eval '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
}

# shell::removal_homebrew function
# Uninstalls Homebrew from the system.
#
# Usage:
#   shell::removal_homebrew
#
# Description:
#   This function first checks if Homebrew is installed using shell::is_command_available.
#   If Homebrew is detected, it uninstalls Homebrew by running the official uninstall
#   script. Additionally, it removes Homebrew-related lines from the user's shell
#   profile (e.g., $HOME/.zprofile) using sed. The commands are executed via
#   shell::run_cmd_eval to ensure they are logged prior to execution.
#
# Dependencies:
#   - shell::is_command_available: Checks if the 'brew' command is available in the PATH.
#   - shell::run_cmd_eval: Executes shell commands with logging.
#   - shell::colored_echo: Displays colored messages to the terminal.
#
# Example:
#   shell::removal_homebrew
shell::removal_homebrew() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_REMOVAL_HOMEBREW"
        return 0
    fi

    if shell::is_command_available brew; then
        echo "🚀 Uninstalling Homebrew..."
        shell::run_cmd_eval '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"'
        shell::run_cmd_eval 'sed -i.bak '/# Homebrew/d' "$HOME/.zprofile"' # Remove Homebrew-related lines from the shell profile
        shell::colored_echo "INFO: Homebrew uninstalled successfully!" 46
    else
        shell::colored_echo "🟡 Homebrew is not installed. Nothing to uninstall." 11
    fi
}
