#!/bin/bash
# fuzzy.sh

# shell::fzf_copy function
# Interactively selects a file to copy and a destination directory using fzf,
# then copies the selected file to the destination directory.
#
# Usage:
#   shell::fzf_copy
#
# Description:
#   This function leverages fzf to provide an interactive interface for choosing:
#     1. A source file (from the current directory and subdirectories).
#     2. A destination directory (from the current directory and subdirectories).
#   It then copies the source file to the destination directory using the original filename.
#
# Example:
#   shell::fzf_copy
#
# Requirements:
#   - fzf must be installed.
#   - Helper functions: shell::run_cmd_eval, shell::colored_echo, and shell::get_os_type.
shell::fzf_copy() {
	# Check for the help flag (-h)
	if [ "$1" = "-h" ]; then
		echo "$USAGE_SHELL_FZF_COPY"
		return 0
	fi

	# Check if fzf is installed.
	shell::install_package fzf

	# Use find and fzf to select the source file.
	local source_file
	source_file=$(find . -type f | fzf --prompt="Select source file: ")
	if [ -z "$source_file" ]; then
		shell::colored_echo "ERR: No source file selected." 196
		return 1
	fi

	# Use find and fzf to select the destination directory.
	local dest_dir
	dest_dir=$(find . -type d | fzf --prompt="Select destination directory: ")
	if [ -z "$dest_dir" ]; then
		shell::colored_echo "ERR: No destination directory selected." 196
		return 1
	fi

	# Derive the new filename (using the same basename as the source).
	local new_filename
	new_filename=$(basename "$source_file")
	local destination_file="$dest_dir/$new_filename"

	# Check if the destination file already exists.
	if [ -e "$destination_file" ]; then
		shell::colored_echo "ERR: Destination file '$destination_file' already exists." 196
		return 1
	fi

	# Build the copy command.
	local cmd="sudo cp \"$source_file\" \"$destination_file\""

	# Execute the command (using shell::run_cmd_eval to log and run it).
	shell::run_cmd_eval "$cmd"
	shell::clip_value "$cmd"
	shell::colored_echo "INFO: File copied successfully to $destination_file" 46
}

# shell::fzf_move function
# Interactively selects a file to move and a destination directory using fzf,
# then moves the selected file to the destination directory.
#
# Usage:
#   shell::fzf_move
#
# Description:
#   This function leverages fzf to provide an interactive interface for choosing:
#     1. A source file (from the current directory and subdirectories).
#     2. A destination directory (from the current directory and subdirectories).
#   It then moves the source file to the destination directory using the original filename.
#
# Example:
#   shell::fzf_move
#
# Requirements:
#   - fzf must be installed.
#   - Helper functions: shell::run_cmd_eval, shell::colored_echo, shell::get_os_type, shell::install_package, and shell::clip_value.
shell::fzf_move() {
	# Check for the help flag (-h)
	if [ "$1" = "-h" ]; then
		echo "$USAGE_SHELL_FZF_MOVE"
		return 0
	fi

	# Check if fzf is installed.
	shell::install_package fzf

	# Use find and fzf to select the source file.
	local source_file
	source_file=$(find . -type f | fzf --prompt="Select source file: ")
	if [ -z "$source_file" ]; then
		shell::colored_echo "ERR: No source file selected." 196
		return 1
	fi

	# Use find and fzf to select the destination directory.
	local dest_dir
	dest_dir=$(find . -type d | fzf --prompt="Select destination directory: ")
	if [ -z "$dest_dir" ]; then
		shell::colored_echo "ERR: No destination directory selected." 196
		return 1
	fi

	# Derive the new filename (using the same basename as the source).
	local new_filename
	new_filename=$(basename "$source_file")
	local destination_file="$dest_dir/$new_filename"

	# Check if the destination file already exists.
	if [ -e "$destination_file" ]; then
		shell::colored_echo "ERR: Destination file '$destination_file' already exists." 196
		return 1
	fi

	# Build the move command.
	local cmd="sudo mv \"$source_file\" \"$destination_file\""

	# Execute the command (using shell::run_cmd_eval to log and run it).
	shell::run_cmd_eval "$cmd"
	shell::clip_value "$cmd"
	shell::colored_echo "INFO: File moved successfully to $destination_file" 46
}

# shell::fzf_remove function
# Interactively selects a file or directory to remove using fzf,
# then removes the selected file or directory.
#
# Usage:
#   shell::fzf_remove
#
# Description:
#   This function leverages fzf to provide an interactive interface for choosing:
#     1. A file or directory (from the current directory and subdirectories).
#   It then removes the selected file or directory using the original path.
#
# Example:
#   shell::fzf_remove
#
# Requirements:
#   - fzf must be installed.
#   - Helper functions: shell::run_cmd_eval, shell::colored_echo, shell::get_os_type, shell::install_package, and shell::clip_value.
shell::fzf_remove() {
	# Check for the help flag (-h)
	if [ "$1" = "-h" ]; then
		echo "$USAGE_SHELL_FZF_REMOVE"
		return 0
	fi

	# Check if fzf is installed.
	shell::install_package fzf

	# Use find and fzf to select the target file or directory.
	local target
	target=$(find . -mindepth 1 | fzf --prompt="Select file/directory to remove: ")
	if [ -z "$target" ]; then
		shell::colored_echo "ERR: No file or directory selected." 196
		return 1
	fi

	# Build the removal command.
	local cmd="sudo rm -rf \"$target\""

	# Execute the command (using shell::run_cmd_eval to log and run it).
	shell::run_cmd_eval "$cmd"
	shell::clip_value "$cmd"
	shell::colored_echo "INFO: Removed successfully: $target" 46
}

# shell::fzf_zip_attachment function
# Zips selected files from a specified folder and outputs the absolute path of the created zip file.
#
# Usage:
#   shell::fzf_zip_attachment [-n] <folder_path>
#
# Parameters:
#   - -n          : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#   - <folder_path>: The folder (directory) from which to select files for zipping.
#
# Description:
#   This function uses the 'find' command to list all files in the specified folder,
#   and then launches 'fzf' in multi-select mode to allow interactive file selection.
#   If one or more files are selected, a zip command is constructed to compress those files.
#   In dry-run mode (-n), the command is printed (via shell::on_evict) without execution;
#   otherwise, it is executed using shell::run_cmd_eval.
#   Finally, the absolute path of the created zip file is echoed.
#
# Example:
#   shell::fzf_zip_attachment /path/to/folder
#   shell::fzf_zip_attachment -n /path/to/folder  # Dry-run: prints the command without executing it.
shell::fzf_zip_attachment() {
	# Check if fzf is installed.
	shell::install_package fzf

	local dry_run="false"

	# Check for the optional dry-run flag (-n).
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "$1" = "-h" ]; then
		echo "$USAGE_SHELL_FZF_ZIP_ATTACHMENT"
		return 0
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::fzf_zip_attachment [-n] <folder_path>"
		return 1
	fi

	local folder_path="$1"
	local zip_filename="${folder_path}.zip"

	# Capture selected files into an array (splitting on newline only).
	local IFS=$'\n'
	local selected_files_arr=($(find "$folder_path" -type f | fzf --multi --prompt="Select files to zip:"))

	# Check if any files were selected.
	if [ ${#selected_files_arr[@]} -eq 0 ]; then
		shell::colored_echo "ERR: No files selected. Aborting." 196
		return 1
	fi

	# Build the zip command as an array.
	local cmd=(sudo zip -r "$zip_filename")
	for file in "${selected_files_arr[@]}"; do
		cmd+=("$file")
	done

	if [ "$dry_run" = "true" ]; then
		# Construct a log-friendly command string (using proper quoting).
		local cmd_str
		cmd_str=$(printf '%q ' "${cmd[@]}")
		shell::on_evict "$cmd_str"
		return 0
	else
		shell::run_cmd "${cmd[@]}"
		shell::colored_echo "INFO: Zipping selected files from '$folder_path'" 46
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

	shell::colored_echo "$abs_zip_filename" 245
	shell::clip_value "$abs_zip_filename"
}

# shell::fzf_current_zip_attachment function
# Reuses shell::fzf_zip_attachment to zip selected files from the current directory,
# ensuring that when unzipped, the archive creates a single top-level folder.
#
# Usage:
#   shell::fzf_current_zip_attachment [-n]
#
# Parameters:
#   - -n         : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#
# Description:
#   This function obtains the current directory's name and its parent directory.
#   It then changes to the parent directory and calls shell::fzf_zip_attachment on the folder name.
#   This ensures that the zip command is run with relative paths so that the resulting archive
#   contains only one top-level folder (the folder name). After zipping, it moves the zip file
#   back to the original (current) directory, echoes its absolute path, and copies the value to the clipboard.
#
# Example:
#   shell::fzf_current_zip_attachment
#   shell::fzf_current_zip_attachment -n  # Dry-run: prints the command without executing it.
shell::fzf_current_zip_attachment() {
	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "$1" = "-h" ]; then
		echo "$USAGE_SHELL_FZF_CURRENT_ZIP_ATTACHMENT"
		return 0
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
		shell::fzf_zip_attachment -n "$current_dir"
		popd >/dev/null
		return 0
	else
		shell::fzf_zip_attachment "$current_dir"
	fi

	# shell::fzf_zip_attachment will create a zip file named "<folder_name>.zip" in the parent directory.
	local created_zip="${parent_dir}/${current_dir}.zip"
	popd >/dev/null

	# Move the zip file into the original directory.
	local desired_zip="${orig_dir}/${current_dir}.zip"
	if [ -f "$created_zip" ]; then
		mv "$created_zip" "$desired_zip"
		shell::colored_echo "INFO: Renamed zip file to '$desired_zip'" 46
		shell::clip_value "$desired_zip"
	else
		shell::colored_echo "ERR: Expected zip file not found." 196
		return 1
	fi
}

# shell::fzf_send_telegram_attachment function
# Uses fzf to interactively select one or more files from a folder (default: current directory)
# and sends them as attachments via the Telegram Bot API by reusing shell::send_telegram_attachment.
#
# Usage:
#   shell::fzf_send_telegram_attachment [-n] <token> <chat_id> <description> [folder_path]
#
# Parameters:
#   - -n           : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - <token>      : The Telegram Bot API token.
#   - <chat_id>    : The chat identifier where the attachments are sent.
#   - <description>: A text description appended to each attachment's caption along with a timestamp.
#   - [folder_path]: (Optional) The folder to search for files; defaults to the current directory if not provided.
#
# Description:
#   This function checks that the required parameters are provided and sets the folder path to the current directory if none is given.
#   It then uses the 'find' command and fzf (in multi-select mode) to let the user choose one or more files.
#   If files are selected, it calls shell::send_telegram_attachment (passing the dry-run flag if needed) with the selected filenames.
#
# Example:
#   shell::fzf_send_telegram_attachment 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 "Report"
#   shell::fzf_send_telegram_attachment -n 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 "Test" /path/to/folder
shell::fzf_send_telegram_attachment() {
	# Check if fzf is installed.
	shell::install_package fzf

	local dry_run="false"
	# Check for the optional dry-run flag (-n).
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "$1" = "-h" ]; then
		echo "$USAGE_SHELL_FZF_SEND_TELEGRAM_ATTACHMENT"
		return 0
	fi

	# Ensure that at least three arguments remain: token, chat_id, description.
	if [ $# -lt 3 ]; then
		echo "Usage: shell::fzf_send_telegram_attachment [-n] <token> <chat_id> <description> [folder_path]"
		return 1
	fi

	local token="$1"
	local chatID="$2"
	local description="$3"
	shift 3

	# Use provided folder path or default to current directory.
	local folder_path="${1:-$PWD}"
	if [ ! -d "$folder_path" ]; then
		shell::colored_echo "ERR: '$folder_path' is not a valid directory." 196
		return 1
	fi

	# Capture selected files into an array using fzf.
	local IFS=$'\n'
	local selected_files_arr=($(find "$folder_path" -type f | fzf --multi --prompt="Select attachments to send: "))

	# Check if any files were selected.
	if [ ${#selected_files_arr[@]} -eq 0 ]; then
		shell::colored_echo "ERR: No attachments selected. Aborting." 196
		return 1
	fi

	# Call shell::send_telegram_attachment with the selected files.
	if [ "$dry_run" = "true" ]; then
		shell::send_telegram_attachment -n "$token" "$chatID" "$description" "${selected_files_arr[@]}"
	else
		shell::send_telegram_attachment "$token" "$chatID" "$description" "${selected_files_arr[@]}"
	fi
}
