#!/bin/bash
# shell.sh - Main entry point for the shell library

# Define the shell library directory
# This variable sets the path to the shell library directory, defaulting to $HOME/shell if not already defined.
SHELL_DIR="${SHELL_DIR:-$HOME/shell}"
LIB_DIR="$SHELL_DIR/src/lib"
LANG_DIR="$SHELL_DIR/src/lang"

# Source all .sh files in lib/
# This block checks if the library directory exists. If it does, it iterates over all .sh files in that directory
# and sources them, making their functions and variables available in the current shell environment.
if [ -d "$LIB_DIR" ]; then
    for script in "$LIB_DIR"/*.sh; do
        [ -f "$script" ] && source "$script"
    done
fi

if [ -d "$LANG_DIR" ]; then
    for script in "$LANG_DIR"/*.sh; do
        [ -f "$script" ] && source "$script"
    done
fi

# shell_version function
# This function outputs the current version of the shell library.
# It is useful for users to check which version they are running.
# Usage:
#   shell_version
# Example:
#   shell_version  # Outputs: shell v0.0.1
shell_version() {
    echo "shell v0.0.1"
}

# shell_upgrade function
# This function upgrades the shell library by removing the existing installation
# and downloading the latest version from the specified GitHub repository.
#
# Usage:
#   shell_upgrade
#
# Description:
#   - Displays a message indicating the upgrade process has started.
#   - Sets the installation directory to $HOME/shell.
#   - Removes the existing installation directory if it exists.
#   - Downloads and executes the install script from the GitHub repository.
#   - Informs the user that the shell has been upgraded and provides instructions
#     to restart the terminal or source the appropriate shell configuration file.
#
#   It checks for the presence of the source command in the user's .zshrc or .bashrc
#   files and executes the appropriate command to ensure the new version is loaded.
shell_upgrade() {
    echo "🚀 Upgrading shell..."
    install_dir="$HOME/shell"
    [ -d "$install_dir" ] && rm -rf "$install_dir"
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/pnguyen215/shell/master/install.sh)"
    shell::colored_echo "🟢 shell upgraded. Restart your terminal or run 'source ~/.zshrc' or 'source ~/.bashrc' to apply changes." 46
    if [ -f "$HOME/.zshrc" ] && grep -q "source $install_dir/src/shell.sh" "$HOME/.zshrc"; then
        shell::clip_value "source ~/.zshrc"
        shell::run_cmd_eval "source ~/.zshrc"
        return 0
    elif [ -f "$HOME/.bashrc" ] && grep -q "source $install_dir/src/shell.sh" "$HOME/.bashrc"; then
        shell::clip_value "source ~/.bashrc"
        shell::run_cmd_eval "source ~/.bashrc"
        return 0
    else
        # Fallback: default to .bashrc if none found.
        shell::clip_value "source ~/.bashrc"
        shell::run_cmd_eval "source ~/.bashrc"
    fi
}

# shell_uninstall function
# This function uninstalls the shell library by removing the installation directory
# and informing the user about the uninstallation process.
#
# Usage:
#   shell_uninstall
#
# Description:
#   - Displays a message indicating that the uninstallation process has started.
#   - Sets the installation directory to $HOME/shell.
#   - Checks if the installation directory exists; if it does, it removes it.
#   - Informs the user that the shell has been uninstalled and provides instructions
#     to manually remove the source command from their shell configuration file
#     (e.g., ~/.zshrc or ~/.bashrc).
shell_uninstall() {
    echo "🚀 Uninstalling shell..."
    install_dir="$HOME/shell"
    [ -d "$install_dir" ] && rm -rf "$install_dir"
    shell::colored_echo "🟢 shell uninstalled. Please remove 'source $install_dir/src/shell.sh' from your shell config (e.g., ~/.zshrc or ~/.bashrc)." 46
}
