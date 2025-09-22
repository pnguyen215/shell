#!/bin/bash
# uninstall.sh

echo "♻️ Uninstalling shell..."

local shell_pkg="$HOME/shell"
if [ -d "$shell_pkg" ]; then
	rm -rf "$shell_pkg"
fi

echo "INFO: shell uninstalled. Please remove 'source $shell_pkg/src/shell.sh' from your shell config (e.g., ~/.zshrc or ~/.bashrc)."
