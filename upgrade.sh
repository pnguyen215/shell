#!/bin/bash
# upgrade.sh

echo "↻ Upgrading shell..."
local shell_pkg="$HOME/shell"

# Remove the old shell package if it exists
if [ -d "$shell_pkg" ]; then
	rm -rf "$shell_pkg"
fi

# Install the latest version of the shell
bash -c "$(curl -fsSL https://raw.githubusercontent.com/pnguyen215/shell/master/install.sh)"

echo "INFO: shell upgraded. Restart your terminal or run 'source ~/.zshrc' or 'source ~/.bashrc' to apply changes."
