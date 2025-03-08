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
fzf_copy() {
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

# fzf_move function
# Interactively selects a file to move and a destination directory using fzf,
# then moves the selected file to the destination directory.
#
# Usage:
#   fzf_move
#
# Description:
#   This function leverages fzf to provide an interactive interface for choosing:
#     1. A source file (from the current directory and subdirectories).
#     2. A destination directory (from the current directory and subdirectories).
#   It then moves the source file to the destination directory using the original filename.
#
# Example:
#   fzf_move
#
# Requirements:
#   - fzf must be installed.
#   - Helper functions: run_cmd_eval, colored_echo, get_os_type, install_package, and clip_value.
fzf_move() {
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

    # Build the move command.
    local cmd="sudo mv \"$source_file\" \"$destination_file\""

    # Execute the command (using run_cmd_eval to log and run it).
    run_cmd_eval "$cmd"
    clip_value "$cmd"
    colored_echo "🟢 File moved successfully to $destination_file" 46
}

# fzf_remove function
# Interactively selects a file or directory to remove using fzf,
# then removes the selected file or directory.
#
# Usage:
#   fzf_remove
#
# Description:
#   This function leverages fzf to provide an interactive interface for choosing:
#     1. A file or directory (from the current directory and subdirectories).
#   It then removes the selected file or directory using the original path.
#
# Example:
#   fzf_remove
#
# Requirements:
#   - fzf must be installed.
#   - Helper functions: run_cmd_eval, colored_echo, get_os_type, install_package, and clip_value.
fzf_remove() {
    # Check if fzf is installed.
    install_package fzf

    # Use find and fzf to select the target file or directory.
    local target
    target=$(find . -mindepth 1 | fzf --prompt="Select file/directory to remove: ")
    if [ -z "$target" ]; then
        colored_echo "🔴 No file or directory selected." 196
        return 1
    fi

    # Build the removal command.
    local cmd="sudo rm -rf \"$target\""

    # Execute the command (using run_cmd_eval to log and run it).
    run_cmd_eval "$cmd"
    clip_value "$cmd"
    colored_echo "🟢 Removed successfully: $target" 46
}
