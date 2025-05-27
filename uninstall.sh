#!/bin/bash
echo "🚀 Uninstalling shell..."
install_dir="$HOME/shell"
[ -d "$install_dir" ] && rm -rf "$install_dir"
echo "INFO: shell uninstalled. Please remove 'source $install_dir/src/shell.sh' from your shell config (e.g., ~/.zshrc or ~/.bashrc)."
