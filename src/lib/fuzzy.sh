#!/bin/bash
# fuzzy.sh

# fzf_copy function
# Interactively selects a file to copy and a destination directory using fzf,
# then copies the selected file to the destination directory.
#
# Usage:
#   fzf_copy
#
# Description:
#   This function leverages fzf to provide an interactive interface for choosing:
#     1. A source file (from the current directory and subdirectories).
#     2. A destination directory (from the current directory and subdirectories).
#   It then copies the source file to the destination directory using the original filename.
#
# Example:
#   fzf_copy
#
# Requirements:
#   - fzf must be installed.
#   - Helper functions: run_cmd_eval, colored_echo, and get_os_type.
function fzf_copy() {
    # Check if fzf is installed.
    install_package fzf

    # Use find and fzf to select the source file.
    local source_file
    source_file=$(find . -type f | fzf --prompt="Select source file: ")
    if [ -z "$source_file" ]; then
        colored_echo "🔴 No source file selected." 196
        return 1
    fi

    # Use find and fzf to select the destination directory.
    local dest_dir
    dest_dir=$(find . -type d | fzf --prompt="Select destination directory: ")
    if [ -z "$dest_dir" ]; then
        colored_echo "🔴 No destination directory selected." 196
        return 1
    fi

    # Derive the new filename (using the same basename as the source).
    local new_filename
    new_filename=$(basename "$source_file")
    local destination_file="$dest_dir/$new_filename"

    # Check if the destination file already exists.
    if [ -e "$destination_file" ]; then
        colored_echo "🔴 Error: Destination file '$destination_file' already exists." 196
        return 1
    fi

    # Build the copy command.
    local cmd="sudo cp \"$source_file\" \"$destination_file\""

    # Execute the command (using run_cmd_eval to log and run it).
    run_cmd_eval "$cmd"
    clip_value "$cmd"
    colored_echo "🟢 File copied successfully to $destination_file" 46
}
