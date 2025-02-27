#!/bin/bash
# bookmark.sh

# Set the bookmarks file (tilde expansion works here)
bookmarks_file=~/.bookmarks

# Create bookmarks_file it if it doesn't exist
if [[ ! -f $bookmarks_file ]]; then
    touch $bookmarks_file
fi

# uplink function
# Creates a hard link between the specified source and destination.
#
# Usage:
#   uplink <source name> <destination name>
#
# Description:
#   The 'uplink' function creates a hard link between the specified source file and destination file.
#   This allows multiple file names to refer to the same file content.
#
# Dependencies:
#   - The 'ln' command for creating hard links.
#   - The 'chmod' command to modify file permissions.
uplink() {
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
        colored_echo "No link file found" 196
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
                colored_echo "🔴 Error: Invalid link specification in .link: $line" 196
            fi
        fi
    done <"$link_file"
}

# opent function
# Opens the specified directory in a new Finder tab (Mac OS only).
#
# Usage:
#   opent [directory]
#
# Description:
#   The 'opent' function opens the specified directory in a new Finder tab on Mac OS.
#   If no directory is specified, it opens the current directory.
#
# Dependencies:
#   - The 'osascript' command for AppleScript support.
opent() {
    local os
    os=$(get_os_type)

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
        colored_echo "🔴 Unsupported operating system for opent function." 196
        return 1
    fi

    colored_echo "🙂 Opening \"$name\" ..." 5
}

# add_bookmark function
# Adds a bookmark for the current directory with the specified name.
#
# Usage:
#   add_bookmark <bookmark name>
#
# Description:
#   The 'add_bookmark' function creates a bookmark for the current directory with the given name.
#   It allows quick navigation to the specified directory using the bookmark name.
add_bookmark() {
    local bookmark_name="$1"

    if [[ -z "$bookmark_name" ]]; then
        colored_echo "🔴 Please type a valid name for your bookmark." 3
        return 1
    fi

    local bookmark
    bookmark="$(pwd)|$bookmark_name" # Store the bookmark as folder|name

    # Check if the bookmark already exists.
    if [[ -z $(grep "|$bookmark_name" "$bookmarks_file") ]]; then
        echo "$bookmark" >>"$bookmarks_file"
        colored_echo "🟢 Bookmark '$bookmark_name' saved" 46
    else
        colored_echo "🟠 Bookmark '$bookmark_name' already exists. Replace it? (y or n)" 5
        while read -r replace; do
            if [[ "$replace" == "y" ]]; then
                # Delete existing bookmark and save the new one.
                run_cmd_eval "sed '/.*|$bookmark_name/d' \"$bookmarks_file\" > ~/.tmp && mv ~/.tmp \"$bookmarks_file\""
                echo "$bookmark" >>"$bookmarks_file"
                colored_echo "🟢 Bookmark '$bookmark_name' saved" 46
                break
            elif [[ "$replace" == "n" ]]; then
                break
            else
                colored_echo "🟡 Please type 'y' or 'n':" 5
            fi
        done
    fi
}

# show_bookmark function
# Displays a formatted list of all bookmarks.
#
# Usage:
#   show_bookmark
#
# Description:
#   The 'show_bookmark' function lists all bookmarks in a formatted manner,
#   showing the bookmark name (field 2) in yellow and the associated directory (field 1) in default color.
show_bookmark() {
    local yellow normal
    yellow=$(tput setaf 3)
    normal=$(tput sgr0)
    awk -v yellow="$yellow" -v normal="$normal" 'BEGIN { FS="|"} { printf "👉 %s%-10s%s %s\n", yellow, $2, normal, $1 }' "$bookmarks_file"
}

# go_bookmark function
# Navigates to the directory associated with the specified bookmark name.
#
# Usage:
#   go_bookmark <bookmark name>
#
# Description:
#   The 'go_bookmark' function changes the current working directory to the directory
#   associated with the given bookmark name. It looks for a line in the bookmarks file
#   that ends with "|<bookmark name>".
go_bookmark() {
    local bookmark_name="$1"
    local bookmark dir

    # Look for a bookmark that ends with "|<bookmark_name>"
    bookmark=$(grep "|${bookmark_name}$" "$bookmarks_file")

    if [[ -z "$bookmark" ]]; then
        colored_echo '🙈 Bookmark not found!' 3
        return 1
    else
        # Extract the directory (the part before the "|")
        dir=$(echo "$bookmark" | cut -d'|' -f1)
        if cd "$dir"; then
            colored_echo "📂 Changed directory to: $dir" 2
        else
            colored_echo "🔴 Failed to change directory to: $dir" 1
            return 1
        fi
    fi
}

# go_back function
# Navigates to the previous working directory.
#
# Usage:
#   go_back
#
# Description:
#   The 'go_back' function changes the current working directory to the previous directory in the history.
go_back() {
    cd $OLDPWD
}

# clip_cwd function
# Copies the current directory path to the clipboard.
#
# Usage:
#   clip_cwd
#
# Description:
#   The 'clip_cwd' function copies the current directory path to the clipboard using the 'pbcopy' command.
clip_cwd() {
    local adr="$PWD"
    local os
    os=$(get_os_type)

    if [[ "$os" == "macos" ]]; then
        echo -n "$adr" | pbcopy
        colored_echo "🟢 Path copied to clipboard using pbcopy" 46
    elif [[ "$os" == "linux" ]]; then
        if is_command_available xclip; then
            echo -n "$adr" | xclip -selection clipboard
            colored_echo "🟢 Path copied to clipboard using xclip" 46
        elif is_command_available xsel; then
            echo -n "$adr" | xsel --clipboard --input
            colored_echo "🟢 Path copied to clipboard using xsel" 46
        else
            colored_echo "🔴 Clipboard tool not found. Please install xclip or xsel." 196
            return 1
        fi
    else
        colored_echo "🔴 Clipboard copying not supported on this OS." 196
        return 1
    fi
}

# clip_value function
# Copies the provided text value into the system clipboard.
#
# Usage:
#   clip_value <text>
#
# Parameters:
#   <text> - The text string or value to copy to the clipboard.
#
# Description:
#   This function first checks if a value has been provided. It then determines the current operating
#   system using the get_os_type function. On macOS, it uses pbcopy to copy the value to the clipboard.
#   On Linux, it first checks if xclip is available and uses it; if not, it falls back to xsel.
#   If no clipboard tool is found or the OS is unsupported, an error message is displayed.
#
# Dependencies:
#   - get_os_type: To detect the operating system.
#   - is_command_available: To check for the availability of xclip or xsel on Linux.
#   - colored_echo: To print colored status messages.
#
# Example:
#   clip_value "Hello, World!"
clip_value() {
    local value="$1"
    if [[ -z "$value" ]]; then
        colored_echo "🔴 Error: No value provided to copy." 196
        return 1
    fi

    local os
    os=$(get_os_type)

    if [[ "$os" == "macos" ]]; then
        echo -n "$value" | pbcopy
        colored_echo "🟢 Value copied to clipboard using pbcopy." 46
    elif [[ "$os" == "linux" ]]; then
        if is_command_available xclip; then
            echo -n "$value" | xclip -selection clipboard
            colored_echo "🟢 Value copied to clipboard using xclip." 46
        elif is_command_available xsel; then
            echo -n "$value" | xsel --clipboard --input
            colored_echo "🟢 Value copied to clipboard using xsel." 46
        else
            colored_echo "🔴 Clipboard tool not found. Please install xclip or xsel." 196
            return 1
        fi
    else
        colored_echo "🔴 Clipboard copying not supported on this OS." 196
        return 1
    fi
}
