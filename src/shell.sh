#!/bin/bash
# shell.sh - Main entry point for the shell library

# Define the library directory
SHELL_DIR="${SHELL_DIR:-$HOME/shell}"
LIB_DIR="$SHELL_DIR/src/lib"

# Source all .sh files in lib/
if [ -d "$LIB_DIR" ]; then
    for script in "$LIB_DIR"/*.sh; do
        [ -f "$script" ] && source "$script"
    done
fi

shell_version() {
    echo "shell v0.0.1"
}

shell_upgrade() {
    echo "🚀 Upgrading shell..."
    install_dir="$HOME/shell"
    [ -d "$install_dir" ] && rm -rf "$install_dir"
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/pnguyen215/shell/master/install.sh)"
    shell::colored_echo "🟢 shell upgraded. Restart your terminal or run 'source ~/.zshrc' or 'source ~/.bashrc' to apply changes." 46
    # Check if the shell source command is in .zshrc or .bashrc and copy the appropriate command.
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

shell_uninstall() {
    echo "🚀 Uninstalling shell..."
    install_dir="$HOME/shell"
    [ -d "$install_dir" ] && rm -rf "$install_dir"
    shell::colored_echo "🟢 shell uninstalled. Please remove 'source $install_dir/src/shell.sh' from your shell config (e.g., ~/.zshrc or ~/.bashrc)." 46
}
