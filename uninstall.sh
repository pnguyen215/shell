#!/bin/bash
# uninstall.sh

echo "♻️  Uninstalling shell..."
shell_pkg="$HOME/shell"

# Remove the shell package if it exists
if [ -d "$shell_pkg" ]; then
	rm -rf "$shell_pkg"
fi

echo "[▸] shell uninstalled. Please remove 'source $shell_pkg/src/shell.sh' from your shell config (e.g., ~/.zshrc or ~/.bashrc)."
