#!/bin/bash
# bookmark.sh

# Set the bookmarks file (tilde expansion works here)
bookmarks_file="$SHELL_KEY_CONF_FILE_BOOKMARK"

# Create bookmarks_file it if it doesn't exist
if [[ ! -f $bookmarks_file ]]; then
    # shell::create_file_if_not_exists $bookmarks_file
    mkdir -p "$SHELL_CONF_WORKING_BOOKMARK" && touch "$SHELL_KEY_CONF_FILE_BOOKMARK"
fi

# shell::add_bookmark function
# Adds a bookmark for the current directory with the specified name.
#
# Usage:
#   shell::add_bookmark <bookmark name>
#
# Description:
#   The 'shell::add_bookmark' function creates a bookmark for the current directory with the given name.
#   It allows quick navigation to the specified directory using the bookmark name.
shell::add_bookmark() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ADD_BOOKMARK"
        return 0
    fi

    local bookmark_name="$1"

    if [[ -z "$bookmark_name" ]]; then
        shell::colored_echo "ERR: Please type a valid name for your bookmark." 196
        return 1
    fi

    # Sanitize the bookmark name to ensure it is a valid variable name.
    # This function should be defined in shell::sanitize_lower_var_name
    # It should convert the name to lowercase and replace invalid characters.
    bookmark_name=$(shell::sanitize_lower_var_name "$bookmark_name")

    # Check if the bookmark name is empty after sanitization.
    local bookmark
    bookmark="$(pwd)|$bookmark_name" # Store the bookmark as folder|name

    # Check if the bookmark already exists.
    if [[ -z $(grep "|$bookmark_name" "$bookmarks_file") ]]; then
        echo "$bookmark" >>"$bookmarks_file"
        shell::colored_echo "INFO: Bookmark '$bookmark_name' saved" 46
    else
        shell::colored_echo "WARN: Bookmark '$bookmark_name' already exists. Replace it? (y or n)" 11
        while read -r replace; do
            if [[ "$replace" == "y" ]]; then
                # Delete existing bookmark and save the new one.
                shell::run_cmd_eval "sed '/.*|$bookmark_name/d' \"$bookmarks_file\" > ~/.tmp && mv ~/.tmp \"$bookmarks_file\""
                echo "$bookmark" >>"$bookmarks_file"
                shell::colored_echo "INFO: Bookmark '$bookmark_name' saved" 46
                break
            elif [[ "$replace" == "n" ]]; then
                break
            else
                shell::colored_echo "WARN: Please type 'y' or 'n':" 11
            fi
        done
    fi
}

# shell::remove_bookmark function
# Deletes a bookmark with the specified name from the bookmarks file.
#
# Usage:
#   shell::remove_bookmark <bookmark_name>
#
# Parameters:
#   <bookmark_name> : The name of the bookmark to remove.
#
# Description:
#   This function searches for a bookmark entry in the bookmarks file that ends with "|<bookmark_name>".
#   If the entry is found, it creates a secure temporary file using mktemp, filters out the matching line,
#   and then replaces the original bookmarks file with the filtered version.
#   If the bookmark is not found or removal fails, an error message is displayed.
#
# Notes:
#   - The bookmarks file is specified by the global variable 'bookmarks_file'.
shell::remove_bookmark() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_REMOVE_BOOKMARK"
        return 0
    fi

    local bookmark_name="$1"
    if [[ -z "$bookmark_name" ]]; then
        shell::colored_echo "WARN: Type bookmark name to remove." 11
        return 1
    fi

    local bookmark
    bookmark=$(grep "|${bookmark_name}$" "$bookmarks_file")

    if [[ -z "$bookmark" ]]; then
        shell::colored_echo "WARN: Invalid bookmark name." 11
        return 1
    fi

    # Create a secure temporary file.
    local tmp_file
    tmp_file=$(mktemp) || {
        shell::colored_echo "ERR: Failed to create temporary file." 196
        return 1
    }

    # Set a trap to ensure the temporary file is removed when the function exits.
    trap 'rm -f "$tmp_file"' EXIT

    # Construct the command using improved quoting.
    # Using single quotes around the grep pattern helps avoid issues on Linux.
    local cmd="grep -v '|${bookmark_name}$' \"$bookmarks_file\" > \"$tmp_file\" && mv \"$tmp_file\" \"$bookmarks_file\""

    # Execute the command using shell::run_cmd_eval.
    if shell::run_cmd_eval "$cmd"; then
        shell::colored_echo "INFO: Bookmark '$bookmark_name' removed" 46
    else
        shell::colored_echo "ERR: Failed to remove bookmark '$bookmark_name'" 196
        return 1
    fi

    # Remove the trap after successful execution (temporary file is already moved).
    trap - EXIT
}

# shell::remove_bookmark_linux function
# Deletes a bookmark with the specified name from the bookmarks file.
#
# Usage:
#   shell::remove_bookmark_linux <bookmark_name>
#
# Parameters:
#   <bookmark_name> : The name of the bookmark to remove.
#
# Description:
#   This function searches for a bookmark entry in the bookmarks file that ends with "|<bookmark_name>".
#   If the entry is found, it uses sed to delete the line from the file.
#   The sed command is constructed differently for macOS and Linux due to differences in the in‑place edit flag.
#
# Notes:
#   - The bookmarks file is specified by the global variable 'bookmarks_file'.
shell::remove_bookmark_linux() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_REMOVE_BOOKMARK_LINUX"
        return 0
    fi

    local bookmark_name="$1"

    if [[ -z "$bookmark_name" ]]; then
        shell::colored_echo "WARN: Type bookmark name to remove." 11
        return 1
    fi

    local bookmark
    bookmark=$(grep "|${bookmark_name}$" "$bookmarks_file")
    if [[ -z "$bookmark" ]]; then
        shell::colored_echo "WARN: Invalid bookmark name." 11
        return 1
    fi

    # Determine the OS and construct the appropriate sed command.
    local os
    os=$(shell::get_os_type)
    local sed_cmd
    if [[ "$os" == "macos" ]]; then
        # On macOS, sed -i requires an empty string argument.
        sed_cmd="sed -i '' '/|${bookmark_name}\$/d' \"$bookmarks_file\""
    else
        # On Linux, sed -i does not require an argument.
        sed_cmd="sed -i '/|${bookmark_name}\$/d' \"$bookmarks_file\""
    fi

    # Execute the sed command using shell::run_cmd_eval.
    if shell::run_cmd_eval "$sed_cmd"; then
        shell::colored_echo "INFO: Bookmark '$bookmark_name' removed" 46
    else
        shell::colored_echo "ERR: Failed to remove bookmark '$bookmark_name'" 196
        return 1
    fi
}

# shell::go_bookmark function
# Navigates to the directory associated with the specified bookmark name.
#
# Usage:
#   shell::go_bookmark <bookmark name>
#
# Description:
#   The 'shell::go_bookmark' function changes the current working directory to the directory
#   associated with the given bookmark name. It looks for a line in the bookmarks file
#   that ends with "|<bookmark name>".
shell::go_bookmark() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GO_BOOKMARK"
        return 0
    fi

    local bookmark_name="$1"
    local bookmark dir

    # Look for a bookmark that ends with "|<bookmark_name>"
    bookmark=$(grep "|${bookmark_name}$" "$bookmarks_file")

    if [[ -z "$bookmark" ]]; then
        shell::colored_echo 'WARN: Bookmark not found!' 11
        return 1
    else
        # Extract the directory (the part before the "|")
        dir=$(echo "$bookmark" | cut -d'|' -f1)
        if cd "$dir"; then
            shell::colored_echo "INFO: Changed directory to: $dir" 2
        else
            shell::colored_echo "ERR: Failed to change directory to: $dir" 196
            return 1
        fi
    fi
}

# shell::list_bookmark function
# Displays a formatted list of all bookmarks.
#
# Usage:
#   shell::list_bookmark
#
# Description:
#   The 'shell::list_bookmark' function lists all bookmarks in a formatted manner,
#   showing the bookmark name (field 2) in yellow and the associated directory (field 1) in default color.
shell::list_bookmark() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_LIST_BOOKMARK"
        return 0
    fi

    local yellow normal
    yellow=$(tput setaf 3)
    normal=$(tput sgr0)
    awk -v yellow="$yellow" -v normal="$normal" 'BEGIN { FS="|"} { printf "DEBUG: %s%-10s%s %s\n", yellow, $2, normal, $1 }' "$bookmarks_file"
}

# shell::fzf_list_bookmark function
# Interactively selects a path from the bookmarks file using fzf and navigates to it.
#
# Usage:
#   shell::fzf_list_bookmark [-n] [-h]
#
# Parameters:
#   - -h : Optional help flag. Displays this help message.
#   - -n : Optional dry-run flag. If provided, the navigation command is printed instead of executed.
#
# Description:
#   This function first checks if the bookmarks file exists. If not, it displays an error.
#   It then extracts bookmark names and their associated paths from the bookmarks file,
#   formats them for fzf display, and allows the user to interactively select a bookmark.
#   Once a bookmark is selected, it extracts the target directory.
#   In dry-run mode, it prints the 'cd' command that would be executed.
#   Otherwise, it changes the current working directory to the selected path.
#
# Requirements:
#   - fzf must be installed.
#   - The 'bookmarks_file' variable must be set.
#   - Helper functions: shell::install_package, shell::colored_echo, shell::on_evict.
#
# Example usage:
#   shell::fzf_list_bookmark         # Interactively select a bookmark and navigate to it.
#   shell::fzf_list_bookmark -n      # Dry-run: print the navigation command without executing.
shell::fzf_list_bookmark() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_LIST_BOOKMARK"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ ! -f "$bookmarks_file" ]; then
        shell::colored_echo "ERR: Bookmarks file '$bookmarks_file' not found." 196
        return 1
    fi

    shell::install_package fzf || {
        shell::colored_echo "ERR: fzf is required but could not be installed." 196
        return 1
    }

    local selected_display_line
    # Display bookmarks in the format "name (path)" for fzf.
    # The original full line from the file is also passed through so we can easily grep for it.
    selected_display_line=$(awk -F'|' '{print $2 " (" $1 ")"}' "$bookmarks_file" | fzf --prompt="Select a bookmarked path: ")

    if [ -z "$selected_display_line" ]; then
        shell::colored_echo "ERR: No bookmark selected. Aborting." 196
        return 1
    fi

    local selected_bookmark_name
    # Extract only the bookmark name from the selected display line, e.g., "working-service-path"
    # This assumes the format "name (path)".
    selected_bookmark_name=$(echo "$selected_display_line" | sed 's/ (.*)//')

    local target_path
    # Find the original line in the bookmarks_file using the extracted name
    # Then cut the path (first field) from that line.
    target_path=$(grep "^.*|${selected_bookmark_name}$" "$bookmarks_file" | cut -d'|' -f1)

    if [ -z "$target_path" ]; then
        shell::colored_echo "ERR: Could not find path for selected bookmark '$selected_bookmark_name'." 196
        return 1
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "cd \"$target_path\""
    else
        if [ -d "$target_path" ]; then
            cd "$target_path" || {
                shell::colored_echo "ERR: Failed to change directory to '$target_path'." 196
                return 1
            }
            shell::colored_echo "INFO: Changed directory to: '$target_path'" 46
        else
            shell::colored_echo "ERR: Target directory '$target_path' does not exist." 196
            return 1
        fi
    fi

    return 0
}

# shell::fzf_list_bookmark_up function
# Interactively selects a path from the bookmarks file using fzf and displays its availability status.
#
# Usage:
#   shell::fzf_list_bookmark_up [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the verification commands are printed instead of executing checks.
#
# Description:
#   This function first checks if the bookmarks file exists. If not, it displays an error.
#   It then reads each bookmark, determines if its associated directory exists (Active/Inactive),
#   and formats the output for fzf to include this status.
#   The user can then interactively select a bookmark, and the function will display
#   the selected bookmark's name, path, and its active/inactive status.
#   In dry-run mode, it will print the commands that would be used to check directory existence.
#
# Requirements:
#   - fzf must be installed.
#   - The 'bookmarks_file' variable must be set.
#   - Helper functions: shell::install_package, shell::colored_echo, shell::on_evict.
#
# Example usage:
#   shell::fzf_list_bookmark_up         # Interactively select a bookmark and verify its path.
#   shell::fzf_list_bookmark_up -n      # Dry-run: print verification commands without executing.
shell::fzf_list_bookmark_up() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_LIST_BOOKMARK_UP"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ ! -f "$bookmarks_file" ]; then
        shell::colored_echo "ERR: Bookmarks file '$bookmarks_file' not found." 196
        return 1
    fi

    shell::install_package fzf || {
        shell::colored_echo "ERR: fzf is required but could not be installed." 196
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
        "$bookmarks_file" | fzf --ansi --prompt="Select a bookmarked path: ")

    if [ -z "$selected_display_line" ]; then
        shell::colored_echo "ERR: No bookmark selected. Aborting." 196
        return 1
    fi

    local selected_bookmark_name
    # Extract only the bookmark name from the selected display line, e.g., "working-service-path"
    # This assumes the format "name (path) [status]" and removes both " (path)" and " [status]".
    selected_bookmark_name=$(echo "$selected_display_line" | sed 's/ *(.*) *\[.*\]//')

    local target_path
    # Find the original line in the bookmarks_file using the extracted name
    # Then cut the path (first field) from that line.
    target_path=$(grep "^.*|${selected_bookmark_name}$" "$bookmarks_file" | cut -d'|' -f1)

    if [ -z "$target_path" ]; then
        shell::colored_echo "ERR: Could not find path for selected bookmark '$selected_bookmark_name'." 196
        return 1
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "cd \"$target_path\""
    else
        if [ -d "$target_path" ]; then
            cd "$target_path" || {
                shell::colored_echo "ERR: Failed to change directory to '$target_path'." 196
                return 1
            }
            shell::colored_echo "INFO: Changed directory to: '$target_path'" 46
        else
            shell::colored_echo "ERR: Target directory '$target_path' does not exist." 196
            return 1
        fi
    fi

    return 0
}

# shell::fzf_remove_bookmark_down function
# Interactively selects inactive bookmark paths using fzf and removes them from the bookmarks file.
#
# Usage:
#   shell::fzf_remove_bookmark_down [-n] [-h]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the removal commands are printed instead of executed.
#   - -h : Optional help flag. Displays this help message.
#
# Description:
#   This function checks if the bookmarks file exists. If not, it displays an error.
#   It then identifies inactive bookmarks (paths that do not exist), formats them for fzf display
#   with their status, and allows the user to interactively select one or more bookmarks for removal.
#   Selected bookmarks are removed from the bookmarks file using a secure temporary file.
#   In dry-run mode, it prints the commands that would be used to update the bookmarks file.
#
# Requirements:
#   - fzf must be installed.
#   - The 'bookmarks_file' variable must be set.
#   - Helper functions: shell::install_package, shell::colored_echo, shell::on_evict, shell::run_cmd_eval.
#
# Example usage:
#   shell::fzf_remove_bookmark_down         # Interactively select and remove inactive bookmarks.
#   shell::fzf_remove_bookmark_down -n      # Dry-run: print removal commands without executing.
#
# Returns:
#   0 on success, 1 on failure (e.g., no bookmarks file, fzf not installed, no selection).
#
# Notes:
#   - Uses a secure temporary file created with mktemp to safely update the bookmarks file.
#   - Compatible with both macOS and Linux.
#   - Inactive bookmarks are those whose associated directories do not exist.
shell::fzf_remove_bookmark_down() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_REMOVE_BOOKMARK_DOWN"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Validate bookmarks file existence
    if [ ! -f "$bookmarks_file" ]; then
        shell::colored_echo "ERR: Bookmarks file '$bookmarks_file' not found." 196
        return 1
    fi

    # Ensure fzf is installed
    shell::install_package fzf || {
        shell::colored_echo "ERR: fzf is required but could not be installed." 196
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
        "$bookmarks_file")

    if [ -z "$inactive_bookmarks" ]; then
        shell::colored_echo "INFO: No inactive bookmarks found." 46
        return 0
    fi

    # Use fzf in multi-select mode to select inactive bookmarks
    local selected_display_lines
    selected_display_lines=$(echo "$inactive_bookmarks" | fzf --ansi --multi --prompt="Select inactive bookmarks to remove: ")

    if [ -z "$selected_display_lines" ]; then
        shell::colored_echo "ERR: No bookmarks selected. Aborting." 196
        return 1
    fi

    # Extract bookmark names from selected lines
    local selected_bookmark_names=()
    while IFS= read -r line; do
        # Extract bookmark name (before " (path) [inactive]")
        local name=$(echo "$line" | sed 's/ *(.*) *\[.*\]//')
        selected_bookmark_names+=("$name")
    done <<<"$selected_display_lines"

    # Remove selected bookmarks using shell::remove_bookmark
    local success_count=0
    local failed_count=0
    for name in "${selected_bookmark_names[@]}"; do
        if [ "$dry_run" = "true" ]; then
            shell::on_evict "shell::remove_bookmark \"$name\""
        else
            if shell::remove_bookmark "$name"; then
                ((success_count++))
            else
                ((failed_count++))
            fi
        fi
    done

    # Provide feedback
    if [ "$dry_run" = "true" ]; then
        shell::colored_echo "INFO: Dry-run: Would have attempted to remove ${#selected_bookmark_names[@]} bookmark(s)." 46
    else
        if [ $failed_count -eq 0 ]; then
            shell::colored_echo "INFO: Successfully removed $success_count inactive bookmark(s)." 46
        else
            shell::colored_echo "WARN: Removed $success_count bookmark(s), but $failed_count failed." 11
            return 1
        fi
    fi

    return 0
}

# shell::fzf_remove_bookmark function
# Interactively selects a bookmark using fzf and removes it from the bookmarks file.
#
# Usage:
#   shell::fzf_remove_bookmark [-n] [-h]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the removal command is printed instead of executed.
#   - -h : Optional help flag. Displays this help message.
#
# Description:
#   This function checks if the bookmarks file exists. If not, it displays an error.
#   It then reads all bookmarks, formats them for fzf display, and allows the user to
#   interactively select a bookmark to remove. The selected bookmark is removed from
#   the bookmarks file using a secure temporary file.
#
# Requirements:
#   - fzf must be installed.
#   - The 'bookmarks_file' variable must be set.
#   - Helper functions: shell::install_package, shell::colored_echo, shell::on_evict, shell::run_cmd_eval.
#
# Example usage:
#   shell::fzf_remove_bookmark       # Interactively select and remove a bookmark.
#   shell::fzf_remove_bookmark -n    # Dry-run: print removal command without executing.
shell::fzf_remove_bookmark() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_REMOVE_BOOKMARK"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Validate bookmarks file existence
    # This checks if the bookmarks file exists before proceeding.
    if [ ! -f "$bookmarks_file" ]; then
        shell::colored_echo "ERR: Bookmarks file '$bookmarks_file' not found." 196
        return 1
    fi

    # Ensure fzf is installed
    shell::install_package fzf || {
        shell::colored_echo "ERR: fzf is required but could not be installed." 196
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
        "$bookmarks_file" | fzf --ansi --prompt="Select a bookmarked path: ")

    if [ -z "$selected_display_line" ]; then
        shell::colored_echo "ERR: No bookmark selected. Aborting." 196
        return 1
    fi

    local selected_bookmark_name
    # Extract only the bookmark name from the selected display line, e.g., "working-service-path"
    # This assumes the format "name (path) [status]" and removes both " (path)" and " [status]".
    selected_bookmark_name=$(echo "$selected_display_line" | sed 's/ *(.*) *\[.*\]//')

    local target_path
    # Find the original line in the bookmarks_file using the extracted name
    # Then cut the path (first field) from that line.
    target_path=$(grep "^.*|${selected_bookmark_name}$" "$bookmarks_file" | cut -d'|' -f1)

    if [ -z "$target_path" ]; then
        shell::colored_echo "ERR: Could not find path for selected bookmark '$selected_bookmark_name'." 196
        return 1
    fi

    local os_type=$(shell::get_os_type)
    # Check if the dry-run is enabled
    # If dry-run is true, we prepare the command to remove the bookmark without executing it.
    if [ "$dry_run" = "true" ]; then
        if [[ "$os_type" == "linux" ]]; then
            shell::on_evict "shell::remove_bookmark_linux \"$selected_bookmark_name\""
        else
            shell::on_evict "shell::remove_bookmark \"$selected_bookmark_name\""
        fi
    else
        if [[ "$os_type" == "linux" ]]; then
            shell::remove_bookmark_linux "$selected_bookmark_name"
        else
            shell::remove_bookmark "$selected_bookmark_name"
        fi
    fi
}

# shell::rename_bookmark function
# Renames a bookmark in the bookmarks file.
#
# Usage:
#   shell::rename_bookmark [-n] <old_name> <new_name>
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the rename command is printed instead of executed.
#   - <old_name> : The current name of the bookmark.
#   - <new_name> : The new name to assign to the bookmark.
#
# Description:
#   This function searches for a bookmark entry in the bookmarks file that ends with "|<old_name>".
#   If found, it replaces the bookmark name with the new name using a sed command.
#   The sed command is constructed differently for macOS and Linux due to differences in the in-place edit flag.
#
# Requirements:
#   - The 'bookmarks_file' variable must be set.
#   - Helper functions: shell::colored_echo, shell::on_evict, shell::run_cmd_eval, shell::get_os_type.
#
# Example usage:
#   shell::rename_bookmark old_name new_name
#   shell::rename_bookmark -n old_name new_name
shell::rename_bookmark() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_RENAME_BOOKMARK"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if the required parameters are provided
    # This checks if at least two parameters are provided (old_name and new_name).
    if [ $# -lt 2 ]; then
        echo "Usage: shell::rename_bookmark [-n] <old_name> <new_name>"
        return 1
    fi

    local old_name="$1"
    local new_name="$2"

    # Check if the bookmarks file exists
    # This checks if the bookmarks file exists before proceeding.
    if [ ! -f "$bookmarks_file" ]; then
        shell::colored_echo "ERR: Bookmarks file '$bookmarks_file' not found." 196
        return 1
    fi

    # Check if old_name and new_name are provided
    # This checks if both old_name and new_name are not empty.
    if [[ -z "$old_name" || -z "$new_name" ]]; then
        shell::colored_echo "ERR: Both old and new bookmark names must be provided." 196
        return 1
    fi

    # Sanitize the bookmark names to ensure they are valid variable names.
    # This function should be defined in shell::sanitize_lower_var_name
    # It should convert the names to lowercase and replace invalid characters.
    # old_name=$(shell::sanitize_lower_var_name "$old_name")
    new_name=$(shell::sanitize_lower_var_name "$new_name")

    # Check if the old bookmark exists
    # This checks if there is an entry in the bookmarks file that ends with "|<old_name>".
    # If not, it displays an error message and returns.
    local old_entry
    old_entry=$(grep "^.*|${old_name}$" "$bookmarks_file")
    if [[ -z "$old_entry" ]]; then
        shell::colored_echo "ERR: Bookmark '$old_name' does not exist." 196
        return 1
    fi

    # Check if the new bookmark already exists
    # This checks if there is an entry in the bookmarks file that ends with "|<new_name>".
    local new_entry
    new_entry=$(grep "^.*|${new_name}$" "$bookmarks_file")
    if [[ -n "$new_entry" ]]; then
        shell::colored_echo "ERR: Bookmark '$new_name' already exists." 196
        return 1
    fi

    local os_type=$(shell::get_os_type)
    local sed_cmd=""
    if [[ "$os_type" == "macos" ]]; then
        sed_cmd="sed -i '' 's/^\(.*|\)$old_name$/\1$new_name/' \"$bookmarks_file\""
    else
        sed_cmd="sed -i 's/^\(.*|\)$old_name$/\1$new_name/' \"$bookmarks_file\""
    fi

    # Check if dry-run is enabled
    # If dry-run is true, we prepare the command to rename the bookmark without executing it.
    # Otherwise, we execute the command to rename the bookmark.
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$sed_cmd"
    else
        shell::run_cmd_eval "$sed_cmd"
        shell::colored_echo "INFO: Renamed bookmark '$old_name' to '$new_name'" 46
    fi
}

# shell::fzf_rename_bookmark function
# Interactively selects a bookmark using fzf and renames it.
#
# Usage:
#   shell::fzf_rename_bookmark [-n] [-h]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the rename command is printed instead of executed.
#   - -h : Optional help flag. Displays this help message.
#
# Description:
#   This function checks if the bookmarks file exists. If not, it displays an error.
#   It then reads all bookmarks, formats them for fzf display, and allows the user to
#   interactively select a bookmark to rename. The user is prompted to enter a new name,
#   and the shell::rename_bookmark function is called to perform the rename.
#
# Example usage:
#   shell::fzf_rename_bookmark       # Interactively select and rename a bookmark.
#   shell::fzf_rename_bookmark -n    # Dry-run: print rename command without executing.
shell::fzf_rename_bookmark() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_RENAME_BOOKMARK"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Validate bookmarks file existence
    # This checks if the bookmarks file exists before proceeding.
    if [ ! -f "$bookmarks_file" ]; then
        shell::colored_echo "ERR: Bookmarks file '$bookmarks_file' not found." 196
        return 1
    fi

    # Ensure fzf is installed
    shell::install_package fzf

    local yellow=$(tput setaf 3)
    local cyan=$(tput setaf 6)
    local normal=$(tput sgr0)

    # Display bookmarks in the format "name (path)" for fzf.
    # The original full line from the file is also passed through so we can easily grep for it.
    # This uses awk to format the output with colors.
    local selected_display_line
    selected_display_line=$(awk -F'|' -v yellow="$yellow" -v cyan="$cyan" -v normal="$normal" \
        '{print yellow $2 normal " (" cyan $1 normal ")"}' "$bookmarks_file" |
        fzf --ansi --prompt="Select bookmark to rename: ")

    # Check if a bookmark was selected
    # This checks if the user selected a bookmark. If not, it displays an error and returns.
    # If no bookmark is selected, it will return an empty string.
    if [ -z "$selected_display_line" ]; then
        shell::colored_echo "ERR: No bookmark selected. Aborting." 196
        return 1
    fi

    # Extract the old bookmark name from the selected display line
    # This assumes the format "name (path)" and removes the " (path)" part.
    local old_name
    old_name=$(echo "$selected_display_line" | sed 's/ *(.*)//')

    shell::colored_echo "[e] Enter new name for bookmark '$old_name':" 208
    read -r new_name

    # Check if the new name is empty
    # This checks if the user entered a new name. If not, it displays an error and returns.
    if [ -z "$new_name" ]; then
        shell::colored_echo "ERR: No new name entered. Aborting rename." 196
        return 1
    fi

    # Check if the dry mode is enabled
    # If dry-run is true, we prepare the command to rename the bookmark without executing it.
    # Otherwise, we execute the command to rename the bookmark.
    if [ "$dry_run" = "true" ]; then
        shell::rename_bookmark -n "$old_name" "$new_name"
    else
        shell::rename_bookmark "$old_name" "$new_name"
    fi
}

# shell::rename_dir_base_bookmark function
# Renames the directory associated with a bookmark.
#
# Usage:
#   shell::rename_dir_base_bookmark [-n] <bookmark_name> <new_dir_name>
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the rename command is printed instead of executed.
#   - <bookmark_name> : The name of the bookmark whose directory should be renamed.
#   - <new_dir_name> : The new name for the directory.
#
# Description:
#   This function finds the directory path associated with the given bookmark name
#   and renames the directory to the new name provided. It validates that the bookmark exists,
#   the directory exists, and the target name does not already exist.
#
# Example usage:
#   shell::rename_dir_base_bookmark my-bookmark new-dir-name
#   shell::rename_dir_base_bookmark -n my-bookmark new-dir-name
shell::rename_dir_base_bookmark() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_RENAME_DIR_BASE_BOOKMARK"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if the required parameters are provided
    # This checks if at least two parameters are provided (bookmark_name and new_dir_name).
    if [ $# -lt 2 ]; then
        echo "Usage: shell::rename_dir_base_bookmark [-n] <bookmark_name> <new_dir_name>"
        return 1
    fi

    # Validate the parameters
    # This checks if the bookmark_name and new_dir_name are not empty.
    # If they are empty, it displays an error message and returns.
    local bookmark_name="$1"
    local new_dir_name="$2"

    # Check if the bookmarks file exists
    # This checks if the bookmarks file exists before proceeding.
    if [ ! -f "$bookmarks_file" ]; then
        shell::colored_echo "ERR: Bookmarks file '$bookmarks_file' not found." 196
        return 1
    fi

    # Check if the bookmark exists
    # This checks if there is an entry in the bookmarks file that ends with "|<bookmark_name>".
    # If not, it displays an error message and returns.
    local old_path
    old_path=$(grep "^.*|${bookmark_name}$" "$bookmarks_file" | cut -d'|' -f1)

    # Check if the old_path is empty
    # If the old_path is empty, it means the bookmark was not found.
    # It displays an error message and returns.
    if [ -z "$old_path" ]; then
        shell::colored_echo "ERR: Bookmark '$bookmark_name' not found." 196
        return 1
    fi

    # Check if the old_path is a directory
    # This checks if the old_path is a valid directory.
    # If it is not a directory, it displays an error message and returns.
    if [ ! -d "$old_path" ]; then
        shell::colored_echo "ERR: Directory '$old_path' does not exist." 196
        return 1
    fi

    # Check if the new_dir_name is empty
    # If the new_dir_name is empty, it displays an error message and returns.
    # This ensures that the user provides a valid new directory name.
    local new_path="$(dirname "$old_path")/$new_dir_name"
    if [ -e "$new_path" ]; then
        shell::colored_echo "ERR: Target directory '$new_path' already exists." 196
        return 1
    fi

    # Prepare the command to rename the directory
    # This uses sed to update the bookmarks file with the new directory name.
    # The sed command is constructed differently for macOS and Linux due to differences in the in-place edit flag.
    local os_type=$(shell::get_os_type)
    local update_cmd
    if [[ "$os_type" == "macos" ]]; then
        update_cmd="sed -i '' 's|^$old_path|$new_path|' \"$bookmarks_file\""
    else
        update_cmd="sed -i 's|^$old_path|$new_path|' \"$bookmarks_file\""
    fi

    local rename_cmd="mv \"$old_path\" \"$new_path\""

    # Check if dry-run is enabled
    # If dry-run is true, we prepare the command to rename the directory without executing it.
    # Otherwise, we execute the command to rename the directory.
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$rename_cmd && $update_cmd"
    else
        shell::run_cmd_eval "$rename_cmd && $update_cmd"
        shell::colored_echo "INFO: Renamed directory '$old_path' to '$new_path'" 46
    fi
}

# shell::fzf_rename_dir_base_bookmark function
# Interactively selects a bookmark using fzf and renames its associated directory.
#
# Usage:
#   shell::fzf_rename_dir_base_bookmark [-n] [-h]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the rename command is printed instead of executed.
#   - -h : Optional help flag. Displays this help message.
#
# Description:
#   This function checks if the bookmarks file exists. If not, it displays an error.
#   It then reads all bookmarks, formats them for fzf display, and allows the user to
#   interactively select a bookmark. The user is prompted to enter a new directory name,
#   and the shell::rename_dir_base_bookmark function is called to perform the rename.
#
# Requirements:
#   - fzf must be installed.
#   - The 'bookmarks_file' variable must be set.
#   - Helper functions: shell::install_package, shell::colored_echo, shell::on_evict, shell::rename_dir_base_bookmark.
#
# Example usage:
#   shell::fzf_rename_dir_base_bookmark       # Interactively select and rename a directory.
#   shell::fzf_rename_dir_base_bookmark -n    # Dry-run: print rename command without executing.
shell::fzf_rename_dir_base_bookmark() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_RENAME_DIR_BASE_BOOKMARK"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Validate bookmarks file existence
    # This checks if the bookmarks file exists before proceeding.
    # If the bookmarks file does not exist, it displays an error and returns.
    if [ ! -f "$bookmarks_file" ]; then
        shell::colored_echo "ERR: Bookmarks file '$bookmarks_file' not found." 196
        return 1
    fi

    # Ensure fzf is installed
    shell::install_package fzf

    local yellow=$(tput setaf 3)
    local cyan=$(tput setaf 6)
    local normal=$(tput sgr0)

    # Display bookmarks in the format "name (path)" for fzf.
    # The original full line from the file is also passed through so we can easily grep for it.
    # This uses awk to format the output with colors.
    # The awk command formats each line with colors for better visibility in fzf.
    local selected_display_line
    selected_display_line=$(awk -F'|' -v yellow="$yellow" -v cyan="$cyan" -v normal="$normal" \
        '{print yellow $2 normal " (" cyan $1 normal ")"}' "$bookmarks_file" |
        fzf --ansi --prompt="Select bookmark to rename its directory: ")

    # Check if a bookmark was selected
    # This checks if the user selected a bookmark. If not, it displays an error and returns.
    # If no bookmark is selected, it will return an empty string.
    if [ -z "$selected_display_line" ]; then
        shell::colored_echo "ERR: No bookmark selected. Aborting." 196
        return 1
    fi

    # Extract the bookmark name from the selected display line
    # This assumes the format "name (path)" and removes the " (path)" part.
    local bookmark_name
    bookmark_name=$(echo "$selected_display_line" | sed 's/ *(.*)//')

    # shell::colored_echo "[e] Enter new name for directory of bookmark '$bookmark_name':" 208
    # read -r new_dir_name

    # Check if the new directory name is empty
    # If the new_dir_name is empty, it displays an error message and returns.
    # This ensures that the user provides a valid new directory name.
    # if [ -z "$new_dir_name" ]; then
    #     shell::colored_echo "ERR: No new name entered. Aborting rename." 196
    #     return 1
    # fi

    # Check if the dry mode is enabled
    # If dry-run is true, we prepare the command to rename the directory without executing it.
    # Otherwise, we execute the command to rename the directory.
    if [ "$dry_run" = "true" ]; then
        shell::rename_dir_base_bookmark -n "$bookmark_name" "$bookmark_name"
    else
        shell::rename_dir_base_bookmark "$bookmark_name" "$bookmark_name"
    fi
}
