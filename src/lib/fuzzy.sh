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

    # Capture selected files into an array (splitting on newline only).
    local IFS=$'\n'
    local selected_files_arr=($(find "$folder_path" -type f | fzf --multi --prompt="Select files to zip:"))

    # Check if any files were selected.
    if [ ${#selected_files_arr[@]} -eq 0 ]; then
        colored_echo "🔴 No files selected. Aborting." 196
        return 1
    fi

    # Build the zip command with proper quoting for each file.
    local files_str=""
    for file in "${selected_files_arr[@]}"; do
        files_str+=" $(printf '%q' "$file")"
    done
    local cmd="sudo zip -r $(printf '%q' "$zip_filename") $files_str"

    if [ "$dry_run" = "true" ]; then
        on_evict "$cmd"
        return 0
    else
        run_cmd_eval "$cmd"
        colored_echo "🟢 Zipping selected files from '$folder_path'" 46
    fi

    # Determine the absolute path of the created zip file.
    local abs_zip_filename
    if command -v realpath >/dev/null 2>&1; then
        abs_zip_filename=$(realpath "$zip_filename")
    else
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
# ensuring that when unzipped, the archive creates a single top-level folder.
#
# Usage:
#   fzf_current_zip_attachment [-n]
#
# Parameters:
#   - -n         : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
#
# Description:
#   This function obtains the current directory’s name and its parent directory.
#   It then changes to the parent directory and calls fzf_zip_attachment on the folder name.
#   This ensures that the zip command is run with relative paths so that the resulting archive
#   contains only one top-level folder (the folder name). After zipping, it moves the zip file
#   back to the original (current) directory, echoes its absolute path, and copies the value to the clipboard.
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

    # Save the original directory (the folder to be zipped).
    local orig_dir="$PWD"
    local current_dir
    current_dir=$(basename "$PWD")
    local parent_dir
    parent_dir=$(dirname "$PWD")

    # Change to the parent directory so that the folder is referenced by its name only.
    pushd "$parent_dir" >/dev/null || return 1

    local zip_file
    if [ "$dry_run" = "true" ]; then
        fzf_zip_attachment -n "$current_dir"
        popd >/dev/null
        return 0
    else
        zip_file=$(fzf_zip_attachment "$current_dir")
    fi

    # fzf_zip_attachment will create a zip file named "<folder_name>.zip" in the parent directory.
    local created_zip="${parent_dir}/${current_dir}.zip"
    popd >/dev/null

    # Move the zip file into the original directory.
    local desired_zip="${orig_dir}/${current_dir}.zip"
    if [ -f "$created_zip" ]; then
        mv "$created_zip" "$desired_zip"
        colored_echo "🟢 Renamed zip file to '$desired_zip'" 46
        clip_value "$desired_zip"
    else
        colored_echo "🔴 Expected zip file not found." 196
        return 1
    fi
}
