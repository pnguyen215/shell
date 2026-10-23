#!/usr/bin/env bash
# @file lib/fs_fzf.sh
# @brief Interactive (fzf) file operations.

# @description Interactively selects a file to copy and a destination directory using fzf,
#   then copies the selected file to the destination directory.
#
#   This function leverages fzf to provide an interactive interface for choosing:
#   1. A source file (from the current directory and subdirectories).
#   2. A destination directory (from the current directory and subdirectories).
#   It then copies the source file to the destination directory using the original filename.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::fs::copy::fzf
#
shell::fs::copy::fzf() {
	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a file to copy and a destination directory using fzf, then copies the selected file to the destination directory"
		shell::logger::usage "shell::fs::copy::fzf [-h]"
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	# Check if fzf is installed.
	shell::dependency::fzf::ensure

	# Use find and fzf to select the source file.
	local source_file
	source_file=$(find . -type f | fzf --prompt="Select source file: ")
	if [ -z "$source_file" ]; then
		shell::logger::error "No source file selected."
		return 1
	fi

	# Use find and fzf to select the destination directory.
	local dest_dir
	dest_dir=$(find . -type d | fzf --prompt="Select destination directory: ")
	if [ -z "$dest_dir" ]; then
		shell::logger::error "No destination directory selected."
		return 1
	fi

	# Derive the new filename (using the same basename as the source).
	local new_filename
	new_filename=$(basename "$source_file")
	local destination_file="$dest_dir/$new_filename"

	# Check if the destination file already exists.
	if [ -e "$destination_file" ]; then
		shell::logger::error "Destination file '$destination_file' already exists."
		return 1
	fi

	# Build the copy command.
	local cmd="cp \"$source_file\" \"$destination_file\""

	# Execute the command (using shell::exec::shell to log and run it).
	shell::exec::shell "$cmd"
	shell::clipboard::copy --best-effort "$cmd"
	shell::logger::success "File copied successfully to $destination_file"
}

# @description Interactively selects a file to move and a destination directory using fzf,
#   then moves the selected file to the destination directory.
#
#   This function leverages fzf to provide an interactive interface for choosing:
#   1. A source file (from the current directory and subdirectories).
#   2. A destination directory (from the current directory and subdirectories).
#   It then moves the source file to the destination directory using the original filename.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::fs::move::fzf
#
shell::fs::move::fzf() {
	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a file to move and a destination directory using fzf, then moves the selected file to the destination directory"
		shell::logger::usage "shell::fs::move::fzf [-h]"
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	# Check if fzf is installed.
	shell::dependency::fzf::ensure

	# Use find and fzf to select the source file.
	local source_file
	source_file=$(find . -type f | fzf --prompt="Select source file: ")
	if [ -z "$source_file" ]; then
		shell::logger::error "No source file selected."
		return 1
	fi

	# Use find and fzf to select the destination directory.
	local dest_dir
	dest_dir=$(find . -type d | fzf --prompt="Select destination directory: ")
	if [ -z "$dest_dir" ]; then
		shell::logger::error "No destination directory selected."
		return 1
	fi

	# Derive the new filename (using the same basename as the source).
	local new_filename
	new_filename=$(basename "$source_file")
	local destination_file="$dest_dir/$new_filename"

	# Check if the destination file already exists.
	if [ -e "$destination_file" ]; then
		shell::logger::error "Destination file '$destination_file' already exists."
		return 1
	fi

	# Build the move command.
	local cmd="mv \"$source_file\" \"$destination_file\""

	# Execute the command (using shell::exec::shell to log and run it).
	shell::exec::shell "$cmd"
	shell::clipboard::copy --best-effort "$cmd"
	shell::logger::success "File moved successfully to $destination_file"
}

# @description Interactively selects a file or directory to remove using fzf,
#   then removes the selected file or directory.
#
#   This function leverages fzf to provide an interactive interface for choosing:
#   1. A file or directory (from the current directory and subdirectories).
#   It then removes the selected file or directory using the original path.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::fs::remove::fzf
#
shell::fs::remove::fzf() {
	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a file or directory to remove using fzf, then removes the selected file or directory"
		shell::logger::usage "shell::fs::remove::fzf [-h]"
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	# Check if fzf is installed.
	shell::dependency::fzf::ensure

	# Use find and fzf to select the target file or directory.
	local target
	target=$(find . -mindepth 1 | fzf --prompt="Select file/directory to remove: ")
	if [ -z "$target" ]; then
		shell::logger::error "No file or directory selected."
		return 1
	fi

	# Build the removal command.
	local cmd="rm -rf \"$target\""

	# Execute the command (using shell::exec::shell to log and run it).
	shell::exec::shell "$cmd"
	shell::clipboard::copy --best-effort "$cmd"
	shell::logger::success "Removed successfully: $target"
}

# @description Zips selected files from a specified folder and outputs the absolute path of the created zip file.
#
#   This function uses the 'find' command to list all files in the specified folder,
#   and then launches 'fzf' in multi-select mode to allow interactive file selection.
#   If one or more files are selected, a zip command is constructed to compress those files.
#   In dry-run mode (-n), the command is printed (via shell::logger::command_clip) without execution;
#   otherwise, it is executed using shell::exec::shell.
#   Finally, the absolute path of the created zip file is echoed.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.
# @arg $1 string folder_path: The folder (directory) from which to select files for zipping.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::fs::zip::fzf /path/to/folder
#   shell::fs::zip::fzf -n /path/to/folder  # Dry-run: prints the command without executing it.
#
shell::fs::zip::fzf() {
	# Check if fzf is installed.
	shell::dependency::fzf::ensure

	local dry_run="false"

	# Check for the optional dry-run flag (-n).
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Zips selected files from a specified folder and outputs the absolute path of the created zip file"
		shell::logger::usage "shell::fs::zip::fzf [-n] [-h] <folder_path>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "folder_path" "The folder (directory) from which to select files for zipping."
		shell::logger::example "shell::fs::zip::fzf /path/to/folder"
		shell::logger::example "shell::fs::zip::fzf -n /path/to/folder"
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::fs::zip::fzf [-n] <folder_path>"
		return 1
	fi

	local folder_path="$1"
	local zip_filename="${folder_path}.zip"

	# Capture selected files into an array (splitting on newline only).
	local IFS=$'\n'
	local selected_files_arr=()
	local _item
	while IFS= read -r _item; do
		[ -n "$_item" ] && selected_files_arr+=("$_item")
	done < <(find "$folder_path" -type f | fzf --multi --prompt="Select files to zip:")

	# Check if any files were selected.
	if [ ${#selected_files_arr[@]} -eq 0 ]; then
		shell::logger::error "No files selected. Aborting."
		return 1
	fi

	# Build the zip command as an array.
	local cmd=(zip -r "$zip_filename")
	for file in "${selected_files_arr[@]}"; do
		cmd+=("$file")
	done

	if [ "$dry_run" = "true" ]; then
		# Construct a log-friendly command string (using proper quoting).
		local cmd_str
		cmd_str=$(printf '%q ' "${cmd[@]}")
		shell::logger::command_clip "$cmd_str"
		return 0
	else
		shell::exec::command "${cmd[@]}"
		shell::logger::success "Zipping selected files from '$folder_path'"
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

	shell::console::print "$abs_zip_filename" 245
	shell::clipboard::copy --best-effort "$abs_zip_filename"
}

# @description Reuses shell::fs::zip::fzf to zip selected files from the current directory,
#   ensuring that when unzipped, the archive creates a single top-level folder.
#
#   This function obtains the current directory's name and its parent directory.
#   It then changes to the parent directory and calls shell::fs::zip::fzf on the folder name.
#   This ensures that the zip command is run with relative paths so that the resulting archive
#   contains only one top-level folder (the folder name). After zipping, it moves the zip file
#   back to the original (current) directory, echoes its absolute path, and copies the value to the clipboard.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::fs::zip::current::fzf
#   shell::fs::zip::current::fzf -n  # Dry-run: prints the command without executing it.
#
shell::fs::zip::current::fzf() {
	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Reuses shell::fs::zip::fzf to zip selected files from the current directory, ensuring that when unzipped, the archive creates a single top-level folder"
		shell::logger::usage "shell::fs::zip::current::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::fs::zip::current::fzf"
		shell::logger::example "shell::fs::zip::current::fzf -n"
		return $RETURN_SUCCESS
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
		shell::fs::zip::fzf -n "$current_dir"
		popd >/dev/null
		return 0
	else
		shell::fs::zip::fzf "$current_dir"
	fi

	# shell::fs::zip::fzf will create a zip file named "<folder_name>.zip" in the parent directory.
	local created_zip="${parent_dir}/${current_dir}.zip"
	popd >/dev/null

	# Move the zip file into the original directory.
	local desired_zip="${orig_dir}/${current_dir}.zip"
	if [ -f "$created_zip" ]; then
		mv "$created_zip" "$desired_zip"
		shell::logger::success "Renamed zip file to '$desired_zip'"
		shell::clipboard::copy --best-effort "$desired_zip"
	else
		shell::logger::error "Expected zip file not found."
		return 1
	fi
}

# @description Uses fzf to interactively select one or more files from a folder (default: current directory)
#   and sends them as attachments via the Telegram Bot API by reusing shell::telegram::send_document.
#
#   This function checks that the required parameters are provided and sets the folder path to the current directory if none is given.
#   It then uses the 'find' command and fzf (in multi-select mode) to let the user choose one or more files.
#   If files are selected, it calls shell::telegram::send_document (passing the dry-run flag if needed) with the selected filenames.
# @option -n Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.
# @arg $1 string token: The Telegram Bot API token.
# @arg $2 string chat_id: The chat identifier where the attachments are sent.
# @arg $3 string description: A text description appended to each attachment's caption along with a timestamp.
# @arg $@ string folder_path: (Optional) The folder to search for files; defaults to the current directory if not provided.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::telegram::send_document::fzf 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 "Report"
#   shell::telegram::send_document::fzf -n 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 "Test" /path/to/folder
#
shell::telegram::send_document::fzf() {
	# Check if fzf is installed.
	shell::dependency::fzf::ensure

	local dry_run="false"
	# Check for the optional dry-run flag (-n).
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Uses fzf to interactively select one or more files from a folder (default: current directory) and sends them as attachments via the Telegram Bot API by reusing shell::telegram::send_document"
		shell::logger::usage "shell::telegram::send_document::fzf [-n] [-h] <token> <chat_id> <description> [folder_path]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "token" "The Telegram Bot API token."
		shell::logger::item "chat_id" "The chat identifier where the attachments are sent."
		shell::logger::item "description" "A text description appended to each attachment's caption along with a timestamp."
		shell::logger::item "folder_path" "(Optional) The folder to search for files; defaults to the current directory if not provided."
		shell::logger::example "shell::telegram::send_document::fzf 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 \"Report\""
		shell::logger::example "shell::telegram::send_document::fzf -n 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 \"Test\" /path/to/folder"
		return $RETURN_SUCCESS
	fi

	# Ensure that at least three arguments remain: token, chat_id, description.
	if [ $# -lt 3 ]; then
		echo "Usage: shell::telegram::send_document::fzf [-n] <token> <chat_id> <description> [folder_path]"
		return 1
	fi

	local token="$1"
	local chatID="$2"
	local description="$3"
	shift 3

	# Use provided folder path or default to current directory.
	local folder_path="${1:-$PWD}"
	if [ ! -d "$folder_path" ]; then
		shell::logger::error "'$folder_path' is not a valid directory."
		return 1
	fi

	# Capture selected files into an array using fzf.
	local IFS=$'\n'
	local selected_files_arr=()
	local _item
	while IFS= read -r _item; do
		[ -n "$_item" ] && selected_files_arr+=("$_item")
	done < <(find "$folder_path" -type f | fzf --multi --prompt="Select attachments to send: ")

	# Check if any files were selected.
	if [ ${#selected_files_arr[@]} -eq 0 ]; then
		shell::logger::error "No attachments selected. Aborting."
		return 1
	fi

	# Call shell::telegram::send_document with the selected files.
	if [ "$dry_run" = "true" ]; then
		shell::telegram::send_document -n "$token" "$chatID" "$description" "${selected_files_arr[@]}"
	else
		shell::telegram::send_document "$token" "$chatID" "$description" "${selected_files_arr[@]}"
	fi
}
