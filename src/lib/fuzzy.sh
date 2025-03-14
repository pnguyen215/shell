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

# fzf_zip_attachment function
# Zips selected files from a specified folder and outputs the absolute path of the created zip file.
#
# Usage:
#   fzf_zip_attachment [-n] <folder_path>
#
# Parameters:
#   - -n          : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
#   - <folder_path>: The folder (directory) from which to select files for zipping.
#
# Description:
#   This function uses the 'find' command to list all files in the specified folder,
#   and then launches 'fzf' in multi-select mode to allow interactive file selection.
#   If one or more files are selected, a zip command is constructed to compress those files.
#   In dry-run mode (-n), the command is printed (via on_evict) without execution;
#   otherwise, it is executed using run_cmd_eval.
#   Finally, the absolute path of the created zip file is echoed.
#
# Example:
#   fzf_zip_attachment /path/to/folder
#   fzf_zip_attachment -n /path/to/folder  # Dry-run: prints the command without executing it.
fzf_zip_attachment() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n).
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: fzf_zip_attachment [-n] <folder_path>"
        return 1
    fi

    local folder_path="$1"
    local zip_filename="${folder_path}.zip"

    # Use fzf to allow the user to interactively select files from the folder.
    local selected_files
    selected_files=$(find "$folder_path" -type f | fzf --multi --prompt="Select files to zip:")

    # Check if any files were selected.
    if [ -z "$selected_files" ]; then
        colored_echo "🔴 No files selected. Aborting." 196
        return 1
    fi

    # Construct the zip command.
    local cmd="sudo zip -r \"$zip_filename\" $selected_files"

    # Execute the command in dry-run mode or actually perform the zipping.
    if [ "$dry_run" = "true" ]; then
        on_evict "$cmd"
        return 1
    else
        run_cmd_eval "$cmd"
        colored_echo "🟢 Zipping selected files from '$folder_path'" 46
    fi

    # Determine the absolute path of the created zip file.
    local abs_zip_filename
    if command -v realpath >/dev/null 2>&1; then
        abs_zip_filename=$(realpath "$zip_filename")
    else
        # Fallback: if zip_filename is relative, prepend the current working directory.
        case "$zip_filename" in
        /*) abs_zip_filename="$zip_filename" ;;
        *) abs_zip_filename="$PWD/$zip_filename" ;;
        esac
    fi

    colored_echo "$abs_zip_filename" 245
    clip_value "$abs_zip_filename"
}

# fzf_current_zip_attachment function
# Reuses fzf_zip_attachment to zip selected files from the current directory,
# then renames the resulting zip file to use the current directory's basename and places it inside the current directory.
#
# Usage:
#   fzf_current_zip_attachment [-n]
#
# Parameters:
#   - -n         : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
#
# Description:
#   The function sets the folder to the current working directory and computes the desired zip filename as "<basename_of_pwd>.zip" in the current directory.
#   It then calls fzf_zip_attachment with the current directory.
#   If not in dry-run mode, after zipping, the function renames the generated zip file from "<PWD>.zip" to "<PWD>/<basename_of_pwd>.zip".
#   Finally, it echoes the absolute path of the renamed zip file.
#
# Example:
#   fzf_current_zip_attachment
#   fzf_current_zip_attachment -n  # Dry-run: prints the command without executing it.
fzf_current_zip_attachment() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Set folder_path to current working directory.
    local folder_path="$PWD"
    # Compute the desired zip filename: current directory's basename with .zip, placed inside $PWD.
    local current_dir
    current_dir=$(basename "$PWD")
    local desired_zip_filename="$PWD/${current_dir}.zip"

    if [ "$dry_run" = "true" ]; then
        fzf_zip_attachment -n "$folder_path"
        return 0
    else
        # Call fzf_zip_attachment with the current working directory.
        # It will create a zip file named as "<folder_path>.zip", which expands to "$PWD.zip".
        local original_abs_zip_filename
        original_abs_zip_filename=$(fzf_zip_attachment "$folder_path")
    fi

    # The zip file created by fzf_zip_attachment is expected to be "$folder_path.zip".
    local expected_zip_filename="$folder_path.zip"

    # If the file exists, rename it to the desired name.
    if [ -f "$expected_zip_filename" ]; then
        mv "$expected_zip_filename" "$desired_zip_filename"
        colored_echo "🟢 Renamed zip file to '$desired_zip_filename'" 46
        colored_echo "$desired_zip_filename" 245
        clip_value "$desired_zip_filename"
    else
        # If for some reason the file wasn't found, fall back to echoing the original output.
        colored_echo "$original_abs_zip_filename" 245
    fi
}
