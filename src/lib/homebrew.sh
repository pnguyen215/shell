#!/bin/bash
# homebrew.sh

# This script provides functions to install and uninstall Homebrew,
# streamlining the process of managing Homebrew as part of your development
# environment setup on macOS (and Linux if supported).

# install_homebrew function
# -------------------------
# Installs Homebrew using the official installation script.
#
# Usage:
#   install_homebrew
#
# Description:
#   This function downloads and executes the official Homebrew installation
#   script via curl. The command is executed using run_cmd_eval, which logs
#   the command before executing it.
#
# Dependencies:
#   - run_cmd_eval: A helper function that logs and executes shell commands.
#
# Example:
#   install_homebrew
function install_homebrew() {
    run_cmd_eval '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
}

# uninstall_homebrew function
# ---------------------------
# Uninstalls Homebrew from the system.
#
# Usage:
#   uninstall_homebrew
#
# Description:
#   This function first checks if Homebrew is installed using is_command_available.
#   If Homebrew is detected, it uninstalls Homebrew by running the official uninstall
#   script. Additionally, it removes Homebrew-related lines from the user's shell
#   profile (e.g., $HOME/.zprofile) using sed. The commands are executed via
#   run_cmd_eval to ensure they are logged prior to execution.
#
# Dependencies:
#   - is_command_available: Checks if the 'brew' command is available in the PATH.
#   - run_cmd_eval: Executes shell commands with logging.
#   - colored_echo: Displays colored messages to the terminal.
#
# Example:
#   uninstall_homebrew
function uninstall_homebrew() {
    if is_command_available brew; then
        echo "🚀 Uninstalling Homebrew..."
        run_cmd_eval '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"'
        run_cmd_eval 'sed -i.bak '/# Homebrew/d' "$HOME/.zprofile"' # Remove Homebrew-related lines from the shell profile
        colored_echo "🟢 Homebrew uninstalled successfully!" 46
    else
        colored_echo "🟡 Homebrew is not installed. Nothing to uninstall." 11
    fi
}
