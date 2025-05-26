#!/bin/bash
# bookmark.sh

# Set the bookmarks file (tilde expansion works here)
bookmarks_file="$SHELL_KEY_CONF_FILE_BOOKMARK"

# Create bookmarks_file it if it doesn't exist
if [[ ! -f $bookmarks_file ]]; then
    # shell::create_file_if_not_exists $bookmarks_file
    mkdir -p "$SHELL_CONF_WORKING_BOOKMARK" && touch "$SHELL_KEY_CONF_FILE_BOOKMARK"
fi

# shell::uplink function
# Creates a hard link between the specified source and destination.
#
# Usage:
#   shell::uplink <source name> <destination name>
#
# Description:
#   The 'shell::uplink' function creates a hard link between the specified source file and destination file.
#   This allows multiple file names to refer to the same file content.
#
# Dependencies:
#   - The 'ln' command for creating hard links.
#   - The 'chmod' command to modify file permissions.
shell::uplink() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_UPLINK"
        return 0
    fi

    # If two arguments are provided, use them as source and destination.
    if [ "$#" -eq 2 ]; then
        local src="$1"
        local dest="$2"
        ln -vif "$src" "$dest" && chmod +x "$dest"
        return $?
    fi

    # Otherwise, expect a .link file containing link pairs separated by "→".
    local link_file=".link"
    if [[ ! -f $link_file ]]; then
        shell::colored_echo "No link file found" 196
        return 1
    fi

    # Process each line in the .link file that contains the delimiter "→".
    while IFS= read -r line; do
        if echo "$line" | grep -q "→"; then
            # Extract the source and destination, trimming any extra whitespace.
            local src
            local dest
            src=$(echo "$line" | cut -d'→' -f1 | xargs)
            dest=$(echo "$line" | cut -d'→' -f2 | xargs)
            if [ -n "$src" ] && [ -n "$dest" ]; then
                ln -vif "$src" "$dest" && chmod +x "$dest"
            else
                shell::colored_echo "🔴 Error: Invalid link specification in .link: $line" 196
            fi
        fi
    done <"$link_file"
}

# shell::opent function
# Opens the specified directory in a new Finder tab (Mac OS only).
#
# Usage:
#   shell::opent [directory]
#
# Description:
#   The 'shell::opent' function opens the specified directory in a new Finder tab on Mac OS.
#   If no directory is specified, it opens the current directory.
#
# Dependencies:
#   - The 'osascript' command for AppleScript support.
shell::opent() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_OPENT"
        return 0
    fi

    local os
    os=$(shell::get_os_type)

    local dir
    local name

    # If no directory is provided, use the current directory.
    if [ "$#" -eq 0 ]; then
        dir=$(pwd)
        name=$(basename "$dir")
    else
        dir="$1"
        name=$(basename "$dir")
    fi

    if [ "$os" = "macos" ]; then
        osascript -e 'tell application "Finder"' \
            -e 'activate' \
            -e 'tell application "System Events"' \
            -e 'keystroke "t" using command down' \
            -e 'end tell' \
            -e 'set target of front Finder window to ("'"$dir"'" as POSIX file)' \
            -e 'end tell' \
            -e '--say "'"$name"'"'
    elif [ "$os" = "linux" ]; then
        # Use xdg-open to open the directory in the default file manager.
        xdg-open "$dir"
    else
        shell::colored_echo "🔴 Unsupported operating system for shell::opent function." 196
        return 1
    fi

    shell::colored_echo "🙂 Opening \"$name\" ..." 5
}

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
        shell::colored_echo "🔴 Please type a valid name for your bookmark." 3
        return 1
    fi

    local bookmark
    bookmark="$(pwd)|$bookmark_name" # Store the bookmark as folder|name

    # Check if the bookmark already exists.
    if [[ -z $(grep "|$bookmark_name" "$bookmarks_file") ]]; then
        echo "$bookmark" >>"$bookmarks_file"
        shell::colored_echo "🟢 Bookmark '$bookmark_name' saved" 46
    else
        shell::colored_echo "🟠 Bookmark '$bookmark_name' already exists. Replace it? (y or n)" 5
        while read -r replace; do
            if [[ "$replace" == "y" ]]; then
                # Delete existing bookmark and save the new one.
                shell::run_cmd_eval "sed '/.*|$bookmark_name/d' \"$bookmarks_file\" > ~/.tmp && mv ~/.tmp \"$bookmarks_file\""
                echo "$bookmark" >>"$bookmarks_file"
                shell::colored_echo "🟢 Bookmark '$bookmark_name' saved" 46
                break
            elif [[ "$replace" == "n" ]]; then
                break
            else
                shell::colored_echo "🟡 Please type 'y' or 'n':" 5
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
#   If the entry is found, it removes the corresponding line from the bookmarks file.
#   If the bookmark is not found or the name is empty, it prints an error message.
#
# Notes:
#   - The bookmarks file is specified by the global variable 'bookmarks_file'.
#   - A temporary file (located at "$HOME/bookmarks_temp") is used during the removal process.
# shell::remove_bookmark() {
#     local bookmark_name="$1"

#     if [[ -z "$bookmark_name" ]]; then
#         shell::colored_echo "👊 Type bookmark name to remove." 3
#         return 1
#     fi

#     local bookmark
#     bookmark=$(grep "|${bookmark_name}$" "$bookmarks_file")

#     if [[ -z "$bookmark" ]]; then
#         shell::colored_echo "🙈 Invalid bookmark name." 3
#         return 1
#     else
#         grep -v "|${bookmark_name}$" "$bookmarks_file" >"$HOME/bookmarks_temp" && mv "$HOME/bookmarks_temp" "$bookmarks_file"
#         shell::colored_echo "🟢 Bookmark '$bookmark_name' removed" 46
#     fi
# }

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
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_REMOVE_BOOKMARK"
        return 0
    fi

    local bookmark_name="$1"

    if [[ -z "$bookmark_name" ]]; then
        shell::colored_echo "👊 Type bookmark name to remove." 3
        return 1
    fi

    local bookmark
    bookmark=$(grep "|${bookmark_name}$" "$bookmarks_file")

    if [[ -z "$bookmark" ]]; then
        shell::colored_echo "🙈 Invalid bookmark name." 3
        return 1
    fi

    # Create a secure temporary file.
    local tmp_file
    tmp_file=$(mktemp) || {
        shell::colored_echo "🔴 Failed to create temporary file." 196
        return 1
    }

    # Set a trap to ensure the temporary file is removed when the function exits.
    trap 'rm -f "$tmp_file"' EXIT

    # Construct the command using improved quoting.
    # Using single quotes around the grep pattern helps avoid issues on Linux.
    local cmd="grep -v '|${bookmark_name}$' \"$bookmarks_file\" > \"$tmp_file\" && mv \"$tmp_file\" \"$bookmarks_file\""

    # Execute the command using shell::run_cmd_eval.
    if shell::run_cmd_eval "$cmd"; then
        shell::colored_echo "🟢 Bookmark '$bookmark_name' removed" 46
    else
        shell::colored_echo "🔴 Failed to remove bookmark '$bookmark_name'" 196
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
        shell::colored_echo "👊 Type bookmark name to remove." 3
        return 1
    fi

    local bookmark
    bookmark=$(grep "|${bookmark_name}$" "$bookmarks_file")
    if [[ -z "$bookmark" ]]; then
        shell::colored_echo "🙈 Invalid bookmark name." 3
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
        shell::colored_echo "🟢 Bookmark '$bookmark_name' removed" 46
    else
        shell::colored_echo "🔴 Failed to remove bookmark '$bookmark_name'" 196
        return 1
    fi
}

# shell::show_bookmark function
# Displays a formatted list of all bookmarks.
#
# Usage:
#   shell::show_bookmark
#
# Description:
#   The 'shell::show_bookmark' function lists all bookmarks in a formatted manner,
#   showing the bookmark name (field 2) in yellow and the associated directory (field 1) in default color.
shell::show_bookmark() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_SHOW_BOOKMARK"
        return 0
    fi

    local yellow normal
    yellow=$(tput setaf 3)
    normal=$(tput sgr0)
    awk -v yellow="$yellow" -v normal="$normal" 'BEGIN { FS="|"} { printf "👉 %s%-10s%s %s\n", yellow, $2, normal, $1 }' "$bookmarks_file"
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
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GO_BOOKMARK"
        return 0
    fi

    local bookmark_name="$1"
    local bookmark dir

    # Look for a bookmark that ends with "|<bookmark_name>"
    bookmark=$(grep "|${bookmark_name}$" "$bookmarks_file")

    if [[ -z "$bookmark" ]]; then
        shell::colored_echo '🙈 Bookmark not found!' 3
        return 1
    else
        # Extract the directory (the part before the "|")
        dir=$(echo "$bookmark" | cut -d'|' -f1)
        if cd "$dir"; then
            shell::colored_echo "📂 Changed directory to: $dir" 2
        else
            shell::colored_echo "🔴 Failed to change directory to: $dir" 1
            return 1
        fi
    fi
}

# shell::go_back function
# Navigates to the previous working directory.
#
# Usage:
#   shell::go_back
#
# Description:
#   The 'shell::go_back' function changes the current working directory to the previous directory in the history.
shell::go_back() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GO_BACK"
        return 0
    fi

    cd $OLDPWD
}

# shell::fzf_goto function
# Interactively selects a path from the bookmarks file using fzf and navigates to it.
#
# Usage:
#   shell::fzf_goto [-n] [-h]
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
#   shell::fzf_goto         # Interactively select a bookmark and navigate to it.
#   shell::fzf_goto -n      # Dry-run: print the navigation command without executing.
shell::fzf_goto() {
    local dry_run="false"

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_GOTO"
        return 0
    fi

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ ! -f "$bookmarks_file" ]; then
        shell::colored_echo "🔴 Error: Bookmarks file '$bookmarks_file' not found." 196
        return 1
    fi

    shell::install_package fzf || {
        shell::colored_echo "🔴 Error: fzf is required but could not be installed." 196
        return 1
    }

    local selected_display_line
    # Display bookmarks in the format "name (path)" for fzf.
    # The original full line from the file is also passed through so we can easily grep for it.
    selected_display_line=$(awk -F'|' '{print $2 " (" $1 ")"}' "$bookmarks_file" | fzf --prompt="Select a bookmarked path: ")

    if [ -z "$selected_display_line" ]; then
        shell::colored_echo "🔴 No bookmark selected. Aborting." 196
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
        shell::colored_echo "🔴 Error: Could not find path for selected bookmark '$selected_bookmark_name'." 196
        return 1
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "cd \"$target_path\""
    else
        if [ -d "$target_path" ]; then
            cd "$target_path" || {
                shell::colored_echo "🔴 Failed to change directory to '$target_path'." 196
                return 1
            }
            shell::colored_echo "🟢 Changed directory to: '$target_path'" 46
        else
            shell::colored_echo "🔴 Error: Target directory '$target_path' does not exist." 196
            return 1
        fi
    fi

    return 0
}

# shell::fzf_goto_verifier function
# Interactively selects a path from the bookmarks file using fzf and displays its availability status.
#
# Usage:
#   shell::fzf_goto_verifier [-n]
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
#   shell::fzf_goto_verifier         # Interactively select a bookmark and verify its path.
#   shell::fzf_goto_verifier -n      # Dry-run: print verification commands without executing.
shell::fzf_goto_verifier() {
    local dry_run="false"

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_GOTO_VERIFIER"
        return 0
    fi

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ ! -f "$bookmarks_file" ]; then
        shell::colored_echo "🔴 Error: Bookmarks file '$bookmarks_file' not found." 196
        return 1
    fi

    shell::install_package fzf || {
        shell::colored_echo "🔴 Error: fzf is required but could not be installed." 196
        return 1
    }

    # local selected_display_line
    # # Display bookmarks in the format "name (path) [status]" for fzf.
    # # Check each path's existence and append [active] or [inactive].
    # selected_display_line=$(awk -F'|' '{status = system("[ -d \"" $1 "\" ]") == 0 ? "[active]" : "[inactive]"; print $2 " (" $1 ") " status}' "$bookmarks_file" | fzf --prompt="Select a bookmarked path: ")

    # if [ -z "$selected_display_line" ]; then
    #     shell::colored_echo "🔴 No bookmark selected. Aborting." 196
    #     return 1
    # fi

    # local selected_bookmark_name
    # # Extract only the bookmark name from the selected display line, e.g., "working-service-path"
    # # This assumes the format "name (path) [status]" and removes both " (path)" and " [status]".
    # selected_bookmark_name=$(echo "$selected_display_line" | sed 's/ *(.*) *\[.*\]//')

    # local target_path
    # # Find the original line in the bookmarks_file using the extracted name
    # # Then cut the path (first field) from that line.
    # target_path=$(grep "^.*|${selected_bookmark_name}$" "$bookmarks_file" | cut -d'|' -f1)

    # if [ -z "$target_path" ]; then
    #     shell::colored_echo "🔴 Error: Could not find path for selected bookmark '$selected_bookmark_name'." 196
    #     return 1
    # fi

    # if [ "$dry_run" = "true" ]; then
    #     shell::on_evict "cd \"$target_path\""
    # else
    #     if [ -d "$target_path" ]; then
    #         cd "$target_path" || {
    #             shell::colored_echo "🔴 Failed to change directory to '$target_path'." 196
    #             return 1
    #         }
    #         shell::colored_echo "🟢 Changed directory to: '$target_path'" 46
    #     else
    #         shell::colored_echo "🔴 Error: Target directory '$target_path' does not exist." 196
    #         return 1
    #     fi
    # fi

    # return 0

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
        shell::colored_echo "🔴 No bookmark selected. Aborting." 196
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
        shell::colored_echo "🔴 Error: Could not find path for selected bookmark '$selected_bookmark_name'." 196
        return 1
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "cd \"$target_path\""
    else
        if [ -d "$target_path" ]; then
            cd "$target_path" || {
                shell::colored_echo "🔴 Failed to change directory to '$target_path'." 196
                return 1
            }
            shell::colored_echo "🟢 Changed directory to: '$target_path'" 46
        else
            shell::colored_echo "🔴 Error: Target directory '$target_path' does not exist." 196
            return 1
        fi
    fi

    return 0
}

# shell::fzf_goto_clear function
# Interactively selects inactive bookmark paths using fzf and removes them from the bookmarks file.
#
# Usage:
#   shell::fzf_goto_clear [-n] [-h]
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
#   shell::fzf_goto_clear         # Interactively select and remove inactive bookmarks.
#   shell::fzf_goto_clear -n      # Dry-run: print removal commands without executing.
#
# Returns:
#   0 on success, 1 on failure (e.g., no bookmarks file, fzf not installed, no selection).
#
# Notes:
#   - Uses a secure temporary file created with mktemp to safely update the bookmarks file.
#   - Compatible with both macOS and Linux.
#   - Inactive bookmarks are those whose associated directories do not exist.
shell::fzf_goto_clear() {
    local dry_run="false"

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_GOTO_CLEAR"
        return 0
    fi

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Validate bookmarks file existence
    if [ ! -f "$bookmarks_file" ]; then
        shell::colored_echo "🔴 Error: Bookmarks file '$bookmarks_file' not found." 196
        return 1
    fi

    # Ensure fzf is installed
    shell::install_package fzf || {
        shell::colored_echo "🔴 Error: fzf is required but could not be installed." 196
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
        shell::colored_echo "🟢 No inactive bookmarks found." 46
        return 0
    fi

    # Use fzf in multi-select mode to select inactive bookmarks
    local selected_display_lines
    selected_display_lines=$(echo "$inactive_bookmarks" | fzf --ansi --multi --prompt="Select inactive bookmarks to remove: ")

    if [ -z "$selected_display_lines" ]; then
        shell::colored_echo "🔴 No bookmarks selected. Aborting." 196
        return 1
    fi

    # Create a secure temporary file
    local tmp_file
    tmp_file=$(mktemp) || {
        shell::colored_echo "🔴 Failed to create temporary file." 196
        return 1
    }

    # Set a trap to ensure the temporary file is removed
    trap 'rm -f "$tmp_file"' EXIT

    # Extract bookmark names from selected lines
    local selected_bookmark_names=()
    while IFS= read -r line; do
        # Extract bookmark name (before " (path) [inactive]")
        local name=$(echo "$line" | sed 's/ *(.*) *\[.*\]//')
        selected_bookmark_names+=("$name")
    done <<<"$selected_display_lines"

    # Construct the grep command to exclude selected bookmarks
    local grep_cmd="grep -v -E '"
    local first="true"
    for name in "${selected_bookmark_names[@]}"; do
        if [ "$first" = "true" ]; then
            grep_cmd+="|${name}$"
            first="false"
        else
            grep_cmd+="\\||${name}$"
        fi
    done
    grep_cmd+="' \"$bookmarks_file\" > \"$tmp_file\" && mv \"$tmp_file\" \"$bookmarks_file\""

    # Execute or print the command on dry-run mode
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$grep_cmd"
    else
        if shell::run_cmd_eval "$grep_cmd"; then
            shell::colored_echo "🟢 Successfully removed ${#selected_bookmark_names[@]} inactive bookmark(s)." 46
        else
            shell::colored_echo "🔴 Failed to remove selected bookmarks." 196
            return 1
        fi
    fi

    # Remove the trap after successful execution
    trap - EXIT
    return 0
}
