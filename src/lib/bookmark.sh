#!/usr/bin/env bash
# @file lib/bookmark.sh
# @brief Directory bookmarks.

# @description Create the bookmark directory and file (mode 700/600) if missing.
#   Replaces the code that used to run every time the library was sourced.
# @noargs
# @exitcode 0 The bookmark file exists.
# @exitcode 1 It could not be created.
shell::bookmark::ensure() {
	[ -f "$SHELL_BOOKMARK_FILE" ] && return "$RETURN_SUCCESS"
	shell::fs::touch --private "$SHELL_BOOKMARK_FILE"
}

# @description Adds a bookmark for the current working directory.
#
#   Sanitizes the bookmark name and stores the current working directory as:
#
#   <absolute_path>|<bookmark_name>
#
#   If the bookmark already exists, the user is prompted to confirm replacement.
# @option -n | --dry-run Print the planned commands instead of executing them.
# @option -h | --help Show this help message.
# @arg $1 string bookmark_name: Bookmark name.
# @exitcode 0 Success.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::bookmark::add project
#   shell::bookmark::add -n project
#
shell::bookmark::add() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Create a bookmark for the current working directory"
		shell::logger::usage "shell::bookmark::add [-n] [-h] <bookmark_name>"
		shell::logger::item "bookmark_name" "Bookmark name"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::example "shell::bookmark::add project"
		shell::logger::example "shell::bookmark::add -n project"
		return $RETURN_SUCCESS
	fi

	shell::bookmark::ensure || return $RETURN_FAILURE

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local bookmark_name="$1"

	if [ -z "$bookmark_name" ]; then
		shell::logger::error "Bookmark name is required"
		return $RETURN_INVALID
	fi

	bookmark_name=$(shell::strings::sanitize::lower "$bookmark_name")

	if [ -z "$bookmark_name" ]; then
		shell::logger::error "Bookmark name is invalid after sanitization"
		return $RETURN_INVALID
	fi

	local bookmark="${PWD}|${bookmark_name}"
	local exists="false"
	# -F: the name is a literal string, never a regex.
	grep -qF "|${bookmark_name}" "$SHELL_BOOKMARK_FILE" 2>/dev/null &&
		grep -q "|${bookmark_name}$" "$SHELL_BOOKMARK_FILE" 2>/dev/null && exists="true"

	if [ "$exists" = "false" ]; then
		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "printf '%s\\n' \"${bookmark}\" >> \"${SHELL_BOOKMARK_FILE}\""
			return $RETURN_SUCCESS
		fi
		printf '%s\n' "$bookmark" >>"$SHELL_BOOKMARK_FILE" || {
			shell::logger::error "Failed to save bookmark"
			return $RETURN_FAILURE
		}
		shell::logger::success "Bookmark '${bookmark_name}' saved"
		return $RETURN_SUCCESS
	fi

	if shell::ask::accept "Bookmark '${bookmark_name}' already exists. Replace it?"; then
		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "replace '|${bookmark_name}' entry in ${SHELL_BOOKMARK_FILE} with ${bookmark}"
			return $RETURN_SUCCESS
		fi
		# Rewrite through a temp file next to the target (same filesystem, mode kept
		# private by the umask), then swap it in.
		local tmp_file
		tmp_file="$(mktemp "${SHELL_BOOKMARK_FILE}.XXXXXX")" || return $RETURN_FAILURE
		{
			grep -v "|${bookmark_name}$" "$SHELL_BOOKMARK_FILE"
			printf '%s\n' "$bookmark"
		} >"$tmp_file" &&
			mv -f "$tmp_file" "$SHELL_BOOKMARK_FILE" || {
			rm -f "$tmp_file"
			shell::logger::error "Failed to replace bookmark"
			return $RETURN_FAILURE
		}
		shell::logger::success "Bookmark '${bookmark_name}' replaced"
		return $RETURN_SUCCESS
	fi

	shell::logger::info "Operation cancelled"
	return $RETURN_SUCCESS
}

# @description Deletes a bookmark with the specified name from the bookmarks file.
#
#   This function searches for a bookmark entry in the bookmarks file that ends with "|<bookmark_name>".
#   If the entry is found, it creates a secure temporary file using mktemp, filters out the matching line,
#   and then replaces the original bookmarks file with the filtered version.
#   If the bookmark is not found or removal fails, an error message is displayed.
#
#   Notes:
#   - The bookmarks file is specified by the global variable 'bookmarks_file'.
# @arg $1 string bookmark_name: The name of the bookmark to remove.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::bookmark::remove
#
shell::bookmark::remove() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Deletes a bookmark with the specified name from the bookmarks file"
		shell::logger::usage "shell::bookmark::remove [-h] <bookmark_name>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "bookmark_name" "The name of the bookmark to remove."
		return $RETURN_SUCCESS
	fi

	shell::bookmark::ensure || return $RETURN_FAILURE

	local bookmark_name="$1"
	if [[ -z "$bookmark_name" ]]; then
		shell::logger::warn "Type bookmark name to remove."
		return 1
	fi

	local bookmark
	bookmark=$(grep "|${bookmark_name}$" "$SHELL_BOOKMARK_FILE")

	if [[ -z "$bookmark" ]]; then
		shell::logger::warn "Invalid bookmark name."
		return 1
	fi

	# Create a secure temporary file.
	local tmp_file
	tmp_file=$(mktemp) || {
		shell::logger::error "Failed to create temporary file."
		return 1
	}

	# Construct the command using improved quoting.
	# Using single quotes around the grep pattern helps avoid issues on Linux.
	# `|| true`: grep -v exits 1 when nothing is left (removing the LAST bookmark).
	local cmd="{ grep -v '|${bookmark_name}$' \"$SHELL_BOOKMARK_FILE\" || true; } > \"$tmp_file\" && mv \"$tmp_file\" \"$SHELL_BOOKMARK_FILE\""

	# Execute the command using shell::exec::shell.
	if shell::exec::shell "$cmd"; then
		shell::logger::success "Bookmark '$bookmark_name' removed"
	else
		shell::logger::error "Failed to remove bookmark '$bookmark_name'"
		return 1
	fi

	# Remove the trap after successful execution (temporary file is already moved).
}

# @description Navigates to the directory associated with the specified bookmark name.
#
#   The 'shell::bookmark::go' function changes the current working directory to the directory
#   associated with the given bookmark name. It looks for a line in the bookmarks file
#   that ends with "|<bookmark name>".
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::bookmark::go
#
shell::bookmark::go() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Navigates to the directory associated with the specified bookmark name"
		shell::logger::usage "shell::bookmark::go [-h] <bookmark name>"
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	shell::bookmark::ensure || return $RETURN_FAILURE

	local bookmark_name="$1"
	local bookmark dir

	# Look for a bookmark that ends with "|<bookmark_name>"
	bookmark=$(grep "|${bookmark_name}$" "$SHELL_BOOKMARK_FILE")

	if [[ -z "$bookmark" ]]; then
		shell::console::print 'WARN: Bookmark not found!' 11
		return 1
	else
		# Extract the directory (the part before the "|")
		dir=$(echo "$bookmark" | cut -d'|' -f1)
		if cd "$dir"; then
			shell::logger::info "Changed directory to: $dir"
		else
			shell::logger::error "Failed to change directory to: $dir"
			return 1
		fi
	fi
}

# @description Displays a formatted list of all bookmarks.
#
#   The 'shell::bookmark::list' function lists all bookmarks in a formatted manner,
#   showing the bookmark name (field 2) in yellow and the associated directory (field 1) in default color.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @example
#   shell::bookmark::list
#
shell::bookmark::list() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Displays a formatted list of all bookmarks"
		shell::logger::usage "shell::bookmark::list [-h]"
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	shell::bookmark::ensure || return $RETURN_FAILURE

	local yellow normal
	yellow=$(tput setaf 3)
	normal=$(tput sgr0)
	awk -v yellow="$yellow" -v normal="$normal" 'BEGIN { FS="|"} { printf "DEBUG: %s%-10s%s %s\n", yellow, $2, normal, $1 }' "$SHELL_BOOKMARK_FILE"
}

# @description Interactively selects a path from the bookmarks file using fzf and navigates to it.
#
#   This function first checks if the bookmarks file exists. If not, it displays an error.
#   It then extracts bookmark names and their associated paths from the bookmarks file,
#   formats them for fzf display, and allows the user to interactively select a bookmark.
#   Once a bookmark is selected, it extracts the target directory.
#   In dry-run mode, it prints the 'cd' command that would be executed.
#   Otherwise, it changes the current working directory to the selected path.
# @option -h Optional help flag. Displays this help message.
# @option -n Optional dry-run flag. If provided, the navigation command is printed instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::bookmark::list::fzf         # Interactively select a bookmark and navigate to it.
#   shell::bookmark::list::fzf -n      # Dry-run: print the navigation command without executing.
#
shell::bookmark::list::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a path from the bookmarks file using fzf and navigates to it"
		shell::logger::usage "shell::bookmark::list::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional. Dry-run mode. Prints the command without executing it."
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	shell::bookmark::ensure || return $RETURN_FAILURE

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	if [ ! -f "$SHELL_BOOKMARK_FILE" ]; then
		shell::logger::error "Bookmarks file '$SHELL_BOOKMARK_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure || {
		shell::logger::error "fzf is required but could not be installed."
		return 1
	}

	local selected_display_line
	# Display bookmarks in the format "name (path)" for fzf.
	# The original full line from the file is also passed through so we can easily grep for it.
	selected_display_line=$(awk -F'|' '{print $2 " (" $1 ")"}' "$SHELL_BOOKMARK_FILE" | fzf --pointer="▶" --marker="✓" --border=rounded --layout=reverse --prompt="Select a bookmarked path: ")

	if [ -z "$selected_display_line" ]; then
		shell::logger::error "No bookmark selected. Aborting."
		return 1
	fi

	local selected_bookmark_name
	# Extract only the bookmark name from the selected display line, e.g., "working-service-path"
	# This assumes the format "name (path)".
	selected_bookmark_name=$(echo "$selected_display_line" | sed 's/ (.*)//')

	local target_path
	# Find the original line in the bookmarks_file using the extracted name
	# Then cut the path (first field) from that line.
	target_path=$(grep "^.*|${selected_bookmark_name}$" "$SHELL_BOOKMARK_FILE" | cut -d'|' -f1)

	if [ -z "$target_path" ]; then
		shell::logger::error "Could not find path for selected bookmark '$selected_bookmark_name'."
		return 1
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "cd \"$target_path\""
	else
		if [ -d "$target_path" ]; then
			cd "$target_path" || {
				shell::logger::error "Failed to change directory to '$target_path'."
				return 1
			}
			shell::logger::success "Changed directory to: '$target_path'"
		else
			shell::logger::error "Target directory '$target_path' does not exist."
			return 1
		fi
	fi

	return 0
}

# @description Interactively selects a path from the bookmarks file using fzf and displays its availability status.
#
#   This function first checks if the bookmarks file exists. If not, it displays an error.
#   It then reads each bookmark, determines if its associated directory exists (Active/Inactive),
#   and formats the output for fzf to include this status.
#   The user can then interactively select a bookmark, and the function will display
#   the selected bookmark's name, path, and its active/inactive status.
#   In dry-run mode, it will print the commands that would be used to check directory existence.
# @option -n Optional dry-run flag. If provided, the verification commands are printed instead of executing checks.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::bookmark::list::up::fzf         # Interactively select a bookmark and verify its path.
#   shell::bookmark::list::up::fzf -n      # Dry-run: print verification commands without executing.
#
shell::bookmark::list::up::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a path from the bookmarks file using fzf and displays its availability status"
		shell::logger::usage "shell::bookmark::list::up::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional. Dry-run mode. Prints the command without executing it."
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	shell::bookmark::ensure || return $RETURN_FAILURE

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	if [ ! -f "$SHELL_BOOKMARK_FILE" ]; then
		shell::logger::error "Bookmarks file '$SHELL_BOOKMARK_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure || {
		shell::logger::error "fzf is required but could not be installed."
		return 1
	}

	# Define ANSI color codes using tput
	local yellow=$(tput setaf 3) # Yellow for bookmark name
	local cyan=$(tput setaf 6)   # Cyan for path
	local green=$(tput setaf 2)  # Green for [active]
	local red=$(tput setaf 1)    # Red for [inactive]
	local normal=$(tput sgr0)    # Reset to normal

	local selected_display_line
	# Display bookmarks in the format "name (path) [status]" with colors for fzf.
	# Check each path's existence and append [active] or [inactive] with appropriate color.
	selected_display_line=$(awk -F'|' -v yellow="$yellow" -v cyan="$cyan" -v green="$green" -v red="$red" -v normal="$normal" \
		'{status = system("[ -d \"" $1 "\" ]") == 0 ? green "[active]" normal : red "[inactive]" normal; print yellow $2 normal " (" cyan $1 normal ") " status}' \
		"$SHELL_BOOKMARK_FILE" | fzf --ansi --bind 'tab:toggle' --bind 'shift-tab:toggle+up' --pointer="▶" --marker="✓" --border=rounded --layout=reverse --prompt="Select a bookmarked path: ")

	if [ -z "$selected_display_line" ]; then
		shell::logger::error "No bookmark selected. Aborting."
		return 1
	fi

	local selected_bookmark_name
	# Extract only the bookmark name from the selected display line, e.g., "working-service-path"
	# This assumes the format "name (path) [status]" and removes both " (path)" and " [status]".
	selected_bookmark_name=$(echo "$selected_display_line" | sed 's/ *(.*) *\[.*\]//')

	local target_path
	# Find the original line in the bookmarks_file using the extracted name
	# Then cut the path (first field) from that line.
	target_path=$(grep "^.*|${selected_bookmark_name}$" "$SHELL_BOOKMARK_FILE" | cut -d'|' -f1)

	if [ -z "$target_path" ]; then
		shell::logger::error "Could not find path for selected bookmark '$selected_bookmark_name'."
		return 1
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "cd \"$target_path\""
	else
		if [ -d "$target_path" ]; then
			cd "$target_path" || {
				shell::logger::error "Failed to change directory to '$target_path'."
				return 1
			}
			shell::logger::success "Changed directory to: '$target_path'"
		else
			shell::logger::error "Target directory '$target_path' does not exist."
			return 1
		fi
	fi

	return 0
}

# @description Interactively selects inactive bookmark paths using fzf and removes them from the bookmarks file.
#
#   This function checks if the bookmarks file exists. If not, it displays an error.
#   It then identifies inactive bookmarks (paths that do not exist), formats them for fzf display
#   with their status, and allows the user to interactively select one or more bookmarks for removal.
#   Selected bookmarks are removed from the bookmarks file using a secure temporary file.
#   In dry-run mode, it prints the commands that would be used to update the bookmarks file.
#
#   Notes:
#   - Uses a secure temporary file created with mktemp to safely update the bookmarks file.
#   - Compatible with both macOS and Linux.
#   - Inactive bookmarks are those whose associated directories do not exist.
# @option -n Optional dry-run flag. If provided, the removal commands are printed instead of executed.
# @option -h Optional help flag. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::bookmark::remove::down::fzf         # Interactively select and remove inactive bookmarks.
#   shell::bookmark::remove::down::fzf -n      # Dry-run: print removal commands without executing.
#
shell::bookmark::remove::down::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects inactive bookmark paths using fzf and removes them from the bookmarks file"
		shell::logger::usage "shell::bookmark::remove::down::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional. Dry-run mode. Prints the command without executing it."
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	shell::bookmark::ensure || return $RETURN_FAILURE

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Validate bookmarks file existence
	if [ ! -f "$SHELL_BOOKMARK_FILE" ]; then
		shell::logger::error "Bookmarks file '$SHELL_BOOKMARK_FILE' not found."
		return 1
	fi

	# Ensure fzf is installed
	shell::dependency::fzf::ensure || {
		shell::logger::error "fzf is required but could not be installed."
		return 1
	}

	# Define ANSI color codes using tput
	local yellow=$(tput setaf 3) # Yellow for bookmark name
	local cyan=$(tput setaf 6)   # Cyan for path
	local red=$(tput setaf 1)    # Red for [inactive]
	local normal=$(tput sgr0)    # Reset to normal

	# Filter and format inactive bookmarks for fzf
	local inactive_bookmarks
	inactive_bookmarks=$(awk -F'|' -v yellow="$yellow" -v cyan="$cyan" -v red="$red" -v normal="$normal" \
		'{if (system("[ -d \"" $1 "\" ]") != 0) print yellow $2 normal " (" cyan $1 normal ") " red "[inactive]" normal}' \
		"$SHELL_BOOKMARK_FILE")

	if [ -z "$inactive_bookmarks" ]; then
		shell::logger::success "No inactive bookmarks found."
		return 0
	fi

	# Use fzf in multi-select mode to select inactive bookmarks
	local selected_display_lines
	selected_display_lines=$(echo "$inactive_bookmarks" | fzf --ansi --multi --pointer="▶" --marker="✓" --border=rounded --layout=reverse --prompt="Select inactive bookmarks to remove: ")

	if [ -z "$selected_display_lines" ]; then
		shell::logger::error "No bookmarks selected. Aborting."
		return 1
	fi

	# Extract bookmark names from selected lines
	local selected_bookmark_names=()
	while IFS= read -r line; do
		# Extract bookmark name (before " (path) [inactive]")
		local name=$(echo "$line" | sed 's/ *(.*) *\[.*\]//')
		selected_bookmark_names+=("$name")
	done <<<"$selected_display_lines"

	# Remove selected bookmarks using shell::bookmark::remove
	local success_count=0
	local failed_count=0
	for name in "${selected_bookmark_names[@]}"; do
		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "shell::bookmark::remove \"$name\""
		else
			if shell::bookmark::remove "$name"; then
				((success_count++))
			else
				((failed_count++))
			fi
		fi
	done

	# Provide feedback
	if [ "$dry_run" = "true" ]; then
		shell::logger::success "Dry-run: Would have attempted to remove ${#selected_bookmark_names[@]} bookmark(s)."
	else
		if [ $failed_count -eq 0 ]; then
			shell::logger::success "Successfully removed $success_count inactive bookmark(s)."
		else
			shell::logger::warn "Removed $success_count bookmark(s), but $failed_count failed."
			return 1
		fi
	fi

	return 0
}

# @description Interactively selects a bookmark using fzf and removes it from the bookmarks file.
#
#   This function checks if the bookmarks file exists. If not, it displays an error.
#   It then reads all bookmarks, formats them for fzf display, and allows the user to
#   interactively select a bookmark to remove. The selected bookmark is removed from
#   the bookmarks file using a secure temporary file.
# @option -n Optional dry-run flag. If provided, the removal command is printed instead of executed.
# @option -h Optional help flag. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::bookmark::remove::fzf       # Interactively select and remove a bookmark.
#   shell::bookmark::remove::fzf -n    # Dry-run: print removal command without executing.
#
shell::bookmark::remove::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a bookmark using fzf and removes it from the bookmarks file"
		shell::logger::usage "shell::bookmark::remove::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the removal command is printed instead of executed."
		shell::logger::option "-h" "Optional help flag. Displays this help message."
		shell::logger::example "shell::bookmark::remove::fzf"
		shell::logger::example "shell::bookmark::remove::fzf -n"
		return $RETURN_SUCCESS
	fi

	shell::bookmark::ensure || return $RETURN_FAILURE

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Validate bookmarks file existence
	# This checks if the bookmarks file exists before proceeding.
	if [ ! -f "$SHELL_BOOKMARK_FILE" ]; then
		shell::logger::error "Bookmarks file '$SHELL_BOOKMARK_FILE' not found."
		return 1
	fi

	# Ensure fzf is installed
	shell::dependency::fzf::ensure || {
		shell::logger::error "fzf is required but could not be installed."
		return 1
	}

	# Define ANSI color codes using tput
	local yellow=$(tput setaf 3) # Yellow for bookmark name
	local cyan=$(tput setaf 6)   # Cyan for path
	local green=$(tput setaf 2)  # Green for [active]
	local red=$(tput setaf 1)    # Red for [inactive]
	local normal=$(tput sgr0)    # Reset to normal

	local selected_display_line
	# Display bookmarks in the format "name (path) [status]" with colors for fzf.
	# Check each path's existence and append [active] or [inactive] with appropriate color.
	selected_display_line=$(awk -F'|' -v yellow="$yellow" -v cyan="$cyan" -v green="$green" -v red="$red" -v normal="$normal" \
		'{status = system("[ -d \"" $1 "\" ]") == 0 ? green "[active]" normal : red "[inactive]" normal; print yellow $2 normal " (" cyan $1 normal ") " status}' \
		"$SHELL_BOOKMARK_FILE" | fzf --ansi --pointer="▶" --marker="✓" --border=rounded --layout=reverse --prompt="Select a bookmarked path: ")

	if [ -z "$selected_display_line" ]; then
		shell::logger::error "No bookmark selected. Aborting."
		return 1
	fi

	local selected_bookmark_name
	# Extract only the bookmark name from the selected display line, e.g., "working-service-path"
	# This assumes the format "name (path) [status]" and removes both " (path)" and " [status]".
	selected_bookmark_name=$(echo "$selected_display_line" | sed 's/ *(.*) *\[.*\]//')

	local target_path
	# Find the original line in the bookmarks_file using the extracted name
	# Then cut the path (first field) from that line.
	target_path=$(grep "^.*|${selected_bookmark_name}$" "$SHELL_BOOKMARK_FILE" | cut -d'|' -f1)

	if [ -z "$target_path" ]; then
		shell::logger::error "Could not find path for selected bookmark '$selected_bookmark_name'."
		return 1
	fi

	local os_type=$(shell::os::type)
	# Check if the dry-run is enabled
	# If dry-run is true, we prepare the command to remove the bookmark without executing it.
	if [ "$dry_run" = "true" ]; then
		if [[ "$os_type" == "linux" ]]; then
			shell::logger::command_clip "shell::bookmark::remove \"$selected_bookmark_name\""
		else
			shell::logger::command_clip "shell::bookmark::remove \"$selected_bookmark_name\""
		fi
	else
		if [[ "$os_type" == "linux" ]]; then
			shell::bookmark::remove "$selected_bookmark_name"
		else
			shell::bookmark::remove "$selected_bookmark_name"
		fi
	fi
}

# @description Renames a bookmark in the bookmarks file.
#
#   This function searches for a bookmark entry in the bookmarks file that ends with "|<old_name>".
#   If found, it replaces the bookmark name with the new name using a sed command.
#   The sed command is constructed differently for macOS and Linux due to differences in the in-place edit flag.
# @option -n Optional dry-run flag. If provided, the rename command is printed instead of executed.
# @arg $1 string old_name: The current name of the bookmark.
# @arg $2 string new_name: The new name to assign to the bookmark.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::bookmark::rename old_name new_name
#   shell::bookmark::rename -n old_name new_name
#
shell::bookmark::rename() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Renames a bookmark in the bookmarks file"
		shell::logger::usage "shell::bookmark::rename [-n] [-h] <old_name> <new_name>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the rename command is printed instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "old_name" "The current name of the bookmark."
		shell::logger::item "new_name" "The new name to assign to the bookmark."
		shell::logger::example "shell::bookmark::rename old_name new_name"
		shell::logger::example "shell::bookmark::rename -n old_name new_name"
		return $RETURN_SUCCESS
	fi

	shell::bookmark::ensure || return $RETURN_FAILURE

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check if the required parameters are provided
	# This checks if at least two parameters are provided (old_name and new_name).
	if [ $# -lt 2 ]; then
		echo "Usage: shell::bookmark::rename [-n] <old_name> <new_name>"
		return 1
	fi

	local old_name="$1"
	local new_name="$2"

	# Check if the bookmarks file exists
	# This checks if the bookmarks file exists before proceeding.
	if [ ! -f "$SHELL_BOOKMARK_FILE" ]; then
		shell::logger::error "Bookmarks file '$SHELL_BOOKMARK_FILE' not found."
		return 1
	fi

	# Check if old_name and new_name are provided
	# This checks if both old_name and new_name are not empty.
	if [[ -z "$old_name" || -z "$new_name" ]]; then
		shell::logger::error "Both old and new bookmark names must be provided."
		return 1
	fi

	# Sanitize the bookmark names to ensure they are valid variable names.
	# This function should be defined in shell::strings::sanitize::lower
	# It should convert the names to lowercase and replace invalid characters.
	# old_name=$(shell::strings::sanitize::lower "$old_name")
	new_name=$(shell::strings::sanitize::lower "$new_name")

	# Check if the old bookmark exists
	# This checks if there is an entry in the bookmarks file that ends with "|<old_name>".
	# If not, it displays an error message and returns.
	local old_entry
	old_entry=$(grep "^.*|${old_name}$" "$SHELL_BOOKMARK_FILE")
	if [[ -z "$old_entry" ]]; then
		shell::logger::error "Bookmark '$old_name' does not exist."
		return 1
	fi

	# Check if the new bookmark already exists
	# This checks if there is an entry in the bookmarks file that ends with "|<new_name>".
	local new_entry
	new_entry=$(grep "^.*|${new_name}$" "$SHELL_BOOKMARK_FILE")
	if [[ -n "$new_entry" ]]; then
		shell::logger::error "Bookmark '$new_name' already exists."
		return 1
	fi

	local os_type=$(shell::os::type)
	local sed_cmd=""
	if [[ "$os_type" == "macos" ]]; then
		sed_cmd="shell::fs::sed_inplace 's/^\(.*|\)$old_name$/\1$new_name/' \"$SHELL_BOOKMARK_FILE\""
	else
		sed_cmd="shell::fs::sed_inplace 's/^\(.*|\)$old_name$/\1$new_name/' \"$SHELL_BOOKMARK_FILE\""
	fi

	# Check if dry-run is enabled
	# If dry-run is true, we prepare the command to rename the bookmark without executing it.
	# Otherwise, we execute the command to rename the bookmark.
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$sed_cmd"
	else
		shell::exec::shell "$sed_cmd"
		shell::logger::success "Renamed bookmark '$old_name' to '$new_name'"
	fi
}

# @description Interactively selects a bookmark using fzf and renames it.
#
#   This function checks if the bookmarks file exists. If not, it displays an error.
#   It then reads all bookmarks, formats them for fzf display, and allows the user to
#   interactively select a bookmark to rename. The user is prompted to enter a new name,
#   and the shell::bookmark::rename function is called to perform the rename.
# @option -n Optional dry-run flag. If provided, the rename command is printed instead of executed.
# @option -h Optional help flag. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::bookmark::rename::fzf       # Interactively select and rename a bookmark.
#   shell::bookmark::rename::fzf -n    # Dry-run: print rename command without executing.
#
shell::bookmark::rename::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a bookmark using fzf and renames it"
		shell::logger::usage "shell::bookmark::rename::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the rename command is printed instead of executed."
		shell::logger::option "-h" "Optional help flag. Displays this help message."
		shell::logger::example "shell::bookmark::rename::fzf"
		shell::logger::example "shell::bookmark::rename::fzf -n"
		return $RETURN_SUCCESS
	fi

	shell::bookmark::ensure || return $RETURN_FAILURE

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Validate bookmarks file existence
	# This checks if the bookmarks file exists before proceeding.
	if [ ! -f "$SHELL_BOOKMARK_FILE" ]; then
		shell::logger::error "Bookmarks file '$SHELL_BOOKMARK_FILE' not found."
		return 1
	fi

	# Ensure fzf is installed
	shell::dependency::fzf::ensure

	local yellow=$(tput setaf 3)
	local cyan=$(tput setaf 6)
	local normal=$(tput sgr0)

	# Display bookmarks in the format "name (path)" for fzf.
	# The original full line from the file is also passed through so we can easily grep for it.
	# This uses awk to format the output with colors.
	local selected_display_line
	selected_display_line=$(awk -F'|' -v yellow="$yellow" -v cyan="$cyan" -v normal="$normal" \
		'{print yellow $2 normal " (" cyan $1 normal ")"}' "$SHELL_BOOKMARK_FILE" |
		fzf --ansi --pointer="▶" --marker="✓" --border=rounded --layout=reverse --prompt="Select bookmark to rename: ")

	# Check if a bookmark was selected
	# This checks if the user selected a bookmark. If not, it displays an error and returns.
	# If no bookmark is selected, it will return an empty string.
	if [ -z "$selected_display_line" ]; then
		shell::logger::error "No bookmark selected. Aborting."
		return 1
	fi

	# Extract the old bookmark name from the selected display line
	# This assumes the format "name (path)" and removes the " (path)" part.
	local old_name
	old_name=$(echo "$selected_display_line" | sed 's/ *(.*)//')

	shell::console::print "[e] Enter new name for bookmark '$old_name':" 208
	read -r new_name

	# Check if the new name is empty
	# This checks if the user entered a new name. If not, it displays an error and returns.
	if [ -z "$new_name" ]; then
		shell::logger::error "No new name entered. Aborting rename."
		return 1
	fi

	# Check if the dry mode is enabled
	# If dry-run is true, we prepare the command to rename the bookmark without executing it.
	# Otherwise, we execute the command to rename the bookmark.
	if [ "$dry_run" = "true" ]; then
		shell::bookmark::rename -n "$old_name" "$new_name"
	else
		shell::bookmark::rename "$old_name" "$new_name"
	fi
}

# @description Renames the directory associated with a bookmark.
#
#   This function finds the directory path associated with the given bookmark name
#   and renames the directory to the new name provided. It validates that the bookmark exists,
#   the directory exists, and the target name does not already exist.
# @option -n Optional dry-run flag. If provided, the rename command is printed instead of executed.
# @arg $1 string bookmark_name: The name of the bookmark whose directory should be renamed.
# @arg $2 string new_dir_name: The new name for the directory.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::bookmark::rename_dir my-bookmark new-dir-name
#   shell::bookmark::rename_dir -n my-bookmark new-dir-name
#
shell::bookmark::rename_dir() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Renames the directory associated with a bookmark"
		shell::logger::usage "shell::bookmark::rename_dir [-n] [-h] <bookmark_name> <new_dir_name>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the rename command is printed instead of executed."
		shell::logger::option "-h" "Optional help flag. Displays this help message."
		shell::logger::item "bookmark_name" "The name of the bookmark whose directory should be renamed."
		shell::logger::item "new_dir_name" "The new name for the directory."
		shell::logger::example "shell::bookmark::rename_dir my-bookmark new-dir-name"
		shell::logger::example "shell::bookmark::rename_dir -n my-bookmark new-dir-name"
		return $RETURN_SUCCESS
	fi

	shell::bookmark::ensure || return $RETURN_FAILURE

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check if the required parameters are provided
	# This checks if at least two parameters are provided (bookmark_name and new_dir_name).
	if [ $# -lt 2 ]; then
		echo "Usage: shell::bookmark::rename_dir [-n] <bookmark_name> <new_dir_name>"
		return 1
	fi

	# Validate the parameters
	# This checks if the bookmark_name and new_dir_name are not empty.
	# If they are empty, it displays an error message and returns.
	local bookmark_name="$1"
	local new_dir_name="$2"

	# Check if the bookmarks file exists
	# This checks if the bookmarks file exists before proceeding.
	if [ ! -f "$SHELL_BOOKMARK_FILE" ]; then
		shell::logger::error "Bookmarks file '$SHELL_BOOKMARK_FILE' not found."
		return 1
	fi

	# Check if the bookmark exists
	# This checks if there is an entry in the bookmarks file that ends with "|<bookmark_name>".
	# If not, it displays an error message and returns.
	local old_path
	old_path=$(grep "^.*|${bookmark_name}$" "$SHELL_BOOKMARK_FILE" | cut -d'|' -f1)

	# Check if the old_path is empty
	# If the old_path is empty, it means the bookmark was not found.
	# It displays an error message and returns.
	if [ -z "$old_path" ]; then
		shell::logger::error "Bookmark '$bookmark_name' not found."
		return 1
	fi

	# Check if the old_path is a directory
	# This checks if the old_path is a valid directory.
	# If it is not a directory, it displays an error message and returns.
	if [ ! -d "$old_path" ]; then
		shell::logger::error "Directory '$old_path' does not exist."
		return 1
	fi

	# Check if the new_dir_name is empty
	# If the new_dir_name is empty, it displays an error message and returns.
	# This ensures that the user provides a valid new directory name.
	local new_path="$(dirname "$old_path")/$new_dir_name"
	if [ -e "$new_path" ]; then
		shell::logger::error "Target directory '$new_path' already exists."
		return 1
	fi

	# Prepare the command to rename the directory
	# This uses sed to update the bookmarks file with the new directory name.
	# The sed command is constructed differently for macOS and Linux due to differences in the in-place edit flag.
	local os_type=$(shell::os::type)
	local update_cmd
	if [[ "$os_type" == "macos" ]]; then
		update_cmd="shell::fs::sed_inplace 's|^$old_path|$new_path|' \"$SHELL_BOOKMARK_FILE\""
	else
		update_cmd="shell::fs::sed_inplace 's|^$old_path|$new_path|' \"$SHELL_BOOKMARK_FILE\""
	fi

	local rename_cmd="mv \"$old_path\" \"$new_path\""

	# Check if dry-run is enabled
	# If dry-run is true, we prepare the command to rename the directory without executing it.
	# Otherwise, we execute the command to rename the directory.
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$rename_cmd && $update_cmd"
	else
		shell::exec::shell "$rename_cmd && $update_cmd"
		shell::logger::success "Renamed directory '$old_path' to '$new_path'"
	fi
}

# @description Interactively selects a bookmark using fzf and renames its associated directory.
#
#   This function checks if the bookmarks file exists. If not, it displays an error.
#   It then reads all bookmarks, formats them for fzf display, and allows the user to
#   interactively select a bookmark. The user is prompted to enter a new directory name,
#   and the shell::bookmark::rename_dir function is called to perform the rename.
# @option -n Optional dry-run flag. If provided, the rename command is printed instead of executed.
# @option -h Optional help flag. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::bookmark::rename_dir::fzf       # Interactively select and rename a directory.
#   shell::bookmark::rename_dir::fzf -n    # Dry-run: print rename command without executing.
#
shell::bookmark::rename_dir::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a bookmark using fzf and renames its associated directory"
		shell::logger::usage "shell::bookmark::rename_dir::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the rename command is printed instead of executed."
		shell::logger::option "-h" "Optional help flag. Displays this help message."
		shell::logger::example "shell::bookmark::rename_dir::fzf"
		shell::logger::example "shell::bookmark::rename_dir::fzf -n"
		return $RETURN_SUCCESS
	fi

	shell::bookmark::ensure || return $RETURN_FAILURE

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Validate bookmarks file existence
	# This checks if the bookmarks file exists before proceeding.
	# If the bookmarks file does not exist, it displays an error and returns.
	if [ ! -f "$SHELL_BOOKMARK_FILE" ]; then
		shell::logger::error "Bookmarks file '$SHELL_BOOKMARK_FILE' not found."
		return 1
	fi

	# Ensure fzf is installed
	shell::dependency::fzf::ensure

	local yellow=$(tput setaf 3)
	local cyan=$(tput setaf 6)
	local normal=$(tput sgr0)
	local home_prefix="$HOME"

	# Display bookmarks in the format "name (path)" for fzf.
	# The original full line from the file is also passed through so we can easily grep for it.
	# This uses awk to format the output with colors.
	# The awk command formats each line with colors for better visibility in fzf.
	local selected_display_line
	# selected_display_line=$(awk -F'|' -v yellow="$yellow" -v cyan="$cyan" -v normal="$normal" \
	#     '{print yellow $2 normal " (" cyan $1 normal ")"}' "$SHELL_BOOKMARK_FILE" |
	#     fzf --ansi --prompt="Select bookmark to rename its directory: ")

	selected_display_line=$(awk -F'|' -v yellow="$yellow" -v cyan="$cyan" -v normal="$normal" -v home="$home_prefix" '
        $1 !~ "^" home {
            print yellow $2 normal " (" cyan $1 normal ")"
        }' "$SHELL_BOOKMARK_FILE" | fzf --ansi --pointer="▶" --marker="✓" --border=rounded --layout=reverse --prompt="Select bookmark to rename its directory: ")

	# Check if a bookmark was selected
	# This checks if the user selected a bookmark. If not, it displays an error and returns.
	# If no bookmark is selected, it will return an empty string.
	if [ -z "$selected_display_line" ]; then
		shell::logger::error "No bookmark selected. Aborting."
		return 1
	fi

	# Extract the bookmark name from the selected display line
	# This assumes the format "name (path)" and removes the " (path)" part.
	local bookmark_name
	bookmark_name=$(echo "$selected_display_line" | sed 's/ *(.*)//')

	# shell::console::print "[e] Enter new name for directory of bookmark '$bookmark_name':" 208
	# read -r new_dir_name

	# Check if the new directory name is empty
	# If the new_dir_name is empty, it displays an error message and returns.
	# This ensures that the user provides a valid new directory name.
	# if [ -z "$new_dir_name" ]; then
	#     shell::logger::error "No new name entered. Aborting rename."
	#     return 1
	# fi

	# Check if the dry mode is enabled
	# If dry-run is true, we prepare the command to rename the directory without executing it.
	# Otherwise, we execute the command to rename the directory.
	if [ "$dry_run" = "true" ]; then
		shell::bookmark::rename_dir -n "$bookmark_name" "$bookmark_name"
	else
		shell::bookmark::rename_dir "$bookmark_name" "$bookmark_name"
	fi
}
