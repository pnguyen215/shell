#!/bin/bash
# install.sh

echo "📦 Installing shell..."

# Check if curl and unzip are installed
for cmd in curl unzip; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "ERR: $cmd is required but not installed. Please install it (e.g., 'sudo apt install $cmd' on Ubuntu)."
		exit 1
	fi
done

# GitHub repo details
owner="pnguyen215"
repo="shell"
shell_pkg="$HOME/shell"
shell_pkg_zip="$repo.zip"

# Download from the master branch only
zip_url="https://github.com/$owner/$repo/archive/master.zip"

# Download the zip file
curl -s -L -o "$shell_pkg_zip" "$zip_url" || {
	echo "ERR: Download failed."
	exit 1
}

# Create the installation directory
mkdir -p "$shell_pkg"

# Extract the zip file
unzip -qq -o "$shell_pkg_zip" -d "$shell_pkg" || {
	echo "ERR: Extraction failed."
	exit 1
}

# Find the extracted folder
shell_pkg_ext=$(find "$shell_pkg" -maxdepth 1 -type d -name "$repo-*" | head -n 1)

# Check if the extracted folder exists
if [ -z "$shell_pkg_ext" ]; then
	echo "ERR: Could not locate extracted folder matching '$repo-*'."
	rm "$shell_pkg_zip"
	exit 1
fi

# Move all contents (including hidden files) and clean up
mv "$shell_pkg_ext"/* "$shell_pkg/" 2>/dev/null || echo "WARN: Some files couldn't be moved (possibly empty or hidden files only)."

# Remove the extracted folder
rmdir "$shell_pkg_ext" 2>/dev/null || {
	rm -rf "$shell_pkg_ext"
}

# Remove the zip file
rm "$shell_pkg_zip"

# Update shell configuration file with priority: .zshrc > .bashrc
shell_conf=""
if [ -f "$HOME/.zshrc" ]; then
	shell_conf="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
	shell_conf="$HOME/.bashrc"
else
	echo "WARN: No .zshrc or .bashrc found. Please manually add 'source $shell_pkg/src/shell.sh' to your shell config."
	exit 0
fi

line="source $shell_pkg/src/shell.sh"

# Check if the line already exists in the shell config
if ! grep -qF "$line" "$shell_conf" 2>/dev/null; then
	echo "$line" >>"$shell_conf"
	echo "INFO: Added shell to $shell_conf"
else
	echo "WARN: Shell already sourced in $shell_conf"
fi

echo "INFO: shell installed. Restart your terminal or run 'source $shell_conf' or 'source ~/.bashrc' to apply changes."
