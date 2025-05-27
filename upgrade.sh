#!/bin/bash
echo "🚀 Upgrading shell..."
install_dir="$HOME/shell"
[ -d "$install_dir" ] && rm -rf "$install_dir"
bash -c "$(curl -fsSL https://raw.githubusercontent.com/pnguyen215/shell/master/install.sh)"
echo "INFO: shell upgraded. Restart your terminal or run 'source ~/.zshrc' or 'source ~/.bashrc' to apply changes."
