#!/bin/bash
echo "🚀 Installing shell..."

# Check for required tools
for cmd in curl unzip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "🔴 Error: $cmd is required but not installed. Please install it (e.g., 'sudo apt install $cmd' on Ubuntu)."
        exit 1
    fi
done

# GitHub repo details
owner="pnguyen215"
repo="shell"
zip_file="$repo.zip"
install_dir="$HOME/shell"

# Fetch latest release or fallback to master
release_url=$(curl -s "https://api.github.com/repos/$owner/$repo/releases/latest")
zip_url=$(echo "$release_url" | grep -o '"browser_download_url": ".*shell.*.zip"' | cut -d'"' -f4)
if [ -z "$zip_url" ]; then
    echo "👉 Latest release not found. Downloading from master branch."
    zip_url="https://github.com/$owner/$repo/archive/master.zip"
fi

# Download and extract
curl -L -o "$zip_file" "$zip_url" || {
    echo "🔴 Download failed."
    exit 1
}
mkdir -p "$install_dir"
unzip -o "$zip_file" -d "$install_dir" || {
    echo "🔴 Extraction failed."
    exit 1
}

# Dynamically find the extracted folder
extracted_dir=$(find "$install_dir" -maxdepth 1 -type d -name "$repo-*" | head -n 1)
if [ -z "$extracted_dir" ]; then
    echo "🔴 Error: Could not locate extracted folder matching '$repo-*'."
    rm "$zip_file"
    exit 1
fi

# Move all contents (including hidden files) and clean up
shopt -s dotglob # Enable globbing to include hidden files
mv "$extracted_dir"/* "$install_dir/" 2>/dev/null || echo "⚠️ Some files couldn’t be moved (possibly empty or hidden files only)."
shopt -u dotglob # Reset globbing behavior
rmdir "$extracted_dir" 2>/dev/null || {
    echo "🟡 $extracted_dir not empty, removing with rm -rf"
    rm -rf "$extracted_dir"
}
rm "$zip_file"

# Detect shell and update config
shell_config=""
if [ -n "$ZSH_VERSION" ]; then
    shell_config="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    shell_config="$HOME/.bashrc"
else
    echo "🟡 Unsupported shell. Please manually add 'source $install_dir/src/shell.sh' to your shell config."
    exit 0
fi

line="source $install_dir/src/shell.sh"
if ! grep -q "$line" "$shell_config" 2>/dev/null; then
    echo "$line" >>"$shell_config"
    echo "🟢 Added shell to $shell_config"
else
    echo "🟡 shell already in $shell_config"
fi

echo "🟢 shell installed. Restart your terminal or run 'source $shell_config' to apply changes."
