#!/bin/bash
# shell.sh - Main entry point for the shell library

# Define the library directory
SHELL_DIR="${SHELL_DIR:-$HOME/shell}"
echo "$SHELL_DIR"
LIB_DIR="$SHELL_DIR/src/lib"
echo "$LIB_DIR"

# Source all .sh files in lib/
if [ -d "$LIB_DIR" ]; then
    for script in "$LIB_DIR"/*.sh; do
        [ -f "$script" ] && source "$script"
    done
fi

shell_version() {
    echo "shell v0.1.0"
}
