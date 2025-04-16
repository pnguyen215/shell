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
# if [ -d "$LIB_DIR" ]; then
#     for script in "$LIB_DIR"/*.sh; do
#         [ -f "$script" ] && source "$script"
#     done
# fi

# if [ -d "$LANG_DIR" ]; then
#     for script in "$LANG_DIR"/*.sh; do
#         [ -f "$script" ] && source "$script"
#     done
# fi

# This function is called after all library and language scripts have been sourced.
# It notifies the user that the sourcing process is complete.
shell::emit() {
    echo "Finished sourcing all library and language scripts."
}

# This function sources all .sh scripts in the specified directory asynchronously.
# It takes two arguments: the directory containing the scripts and a callback function to execute after sourcing.
# It collects the process IDs of the background sourcing processes and waits for them to finish before executing the callback.
shell::__source_async_with_callback() {
    local dir="$1"
    local callback="$2"
    local pids=()

    if [ -d "$dir" ]; then
        for script in "$dir"/*.sh; do
            if [ -f "$script" ]; then
                source "$script" &
                pids+=("$!")
            fi
        done
    fi

    # Wait for all background processes to finish and discard any output
    for pid in "${pids[@]}"; do
        wait "$pid" &>/dev/null
    done

    # Execute the callback function
    if [ -n "$callback" ] && type "$callback" >/dev/null 2>&1; then
        "$callback"
    fi
}

# Source library scripts asynchronously and then execute the callback
shell::__source_async_with_callback "$LIB_DIR" shell::emit

# Source language scripts asynchronously (no specific callback here, the main callback handles both)
shell::__source_async_with_callback "$LANG_DIR" ""

# shell::version function
# This function outputs the current version of the shell library.
# It is useful for users to check which version they are running.
# Usage:
#   shell::version
# Example:
#   shell::version  # Outputs: shell v0.0.1
shell::version() {
    echo "shell v0.0.1"
}

# shell::upgrade function
# This function upgrades the shell library by removing the existing installation
# and downloading the latest version from the specified GitHub repository.
#
# Usage:
#   shell::upgrade
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
shell::upgrade() {
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

# shell::uninstall function
# This function uninstalls the shell library by removing the installation directory
# and informing the user about the uninstallation process.
#
# Usage:
#   shell::uninstall
#
# Description:
#   - Displays a message indicating that the uninstallation process has started.
#   - Sets the installation directory to $HOME/shell.
#   - Checks if the installation directory exists; if it does, it removes it.
#   - Informs the user that the shell has been uninstalled and provides instructions
#     to manually remove the source command from their shell configuration file
#     (e.g., ~/.zshrc or ~/.bashrc).
shell::uninstall() {
    echo "🚀 Uninstalling shell..."
    install_dir="$HOME/shell"
    [ -d "$install_dir" ] && rm -rf "$install_dir"
    shell::colored_echo "🟢 shell uninstalled. Please remove 'source $install_dir/src/shell.sh' from your shell config (e.g., ~/.zshrc or ~/.bashrc)." 46
}
