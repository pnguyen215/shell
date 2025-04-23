#!/bin/bash
# bookmark.sh

# Set the bookmarks file (tilde expansion works here)
# bookmarks_file=~/.bookmarks
bookmarks_file="$SHELL_KEY_CONF_FILE_BOOKMARK"

# Create bookmarks_file it if it doesn't exist
if [[ ! -f $bookmarks_file ]]; then
    # touch $bookmarks_file
    shell::create_file_if_not_exists $bookmarks_file
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
    cd $OLDPWD
}
