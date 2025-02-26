#!/bin/bash
# shell.sh - Main entry point for the shell library

# Define the library directory
SHELL_DIR="${SHELL_DIR:-$HOME/shell}"
echo "$SHELL_DIR"
LIB_DIR="$SHELL_DIR/src/lib"
echo "$LIB_DIR"

# Source all .sh files in lib/
# if [ -d "$LIB_DIR" ]; then
#     for script in "$LIB_DIR"/*.sh; do
#         [ -f "$script" ] && source "$script"
#     done
# fi

# Source all .sh files in lib/
if [ -d "$LIB_DIR" ]; then
    for script in "$LIB_DIR"/*.sh; do
        if [ -f "$script" ]; then
            source "$script"
            echo "Sourced: $script" # Optional debug
        fi
    done
else
    echo "⚠️ Warning: $LIB_DIR not found. Functions may be unavailable."
fi

shell_version() {
    echo "shell v0.1.0"
}

shell_upgrade() {
    echo "🚀 Upgrading shell..."
    install_dir="$HOME/shell"
    [ -d "$install_dir" ] && rm -rf "$install_dir"
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/pnguyen215/shell/master/install.sh)"
    echo "🍺 shell upgraded. Restart your terminal or run 'source ~/.zshrc' or 'source ~/.bashrc' to apply changes."
}

exe() {
    # Example implementation
    os_type=$(get_os_type)

    case "$os_type" in
    "linux")
        # Linux-specific commands
        echo "Linux"
        ;;
    "macos")
        # macOS-specific commands
        echo "macOS"
        ;;
    "windows")
        # Windows-specific commands
        echo "windows"
        ;;
    *)
        echo "Unsupported operating system: $os_type"
        exit 1
        ;;
    esac

}

exe
