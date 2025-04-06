#!/bin/bash
# go.sh

# shell::get_go_privates function
#
# Description:
#   Retrieves and prints the value of the GOPRIVATE environment variable.
#   The GOPRIVATE variable is used by Go tools to determine which modules
#   should be considered private, affecting how Go commands handle dependencies.
#
# Usage:
#   shell::get_go_privates [-n]
#
# Parameters:
#   -n: Optional. If provided, the command is printed using shell::on_evict instead of executed.
#
# Options:
#   None
#
# Example:
#   shell::get_go_privates
#   shell::get_go_privates -n
#
# Instructions:
#   1.  Run `shell::get_go_privates` to display the current GOPRIVATE value.
#   2.  Use `shell::get_go_privates -n` to preview the command.
#
# Notes:
#   -   This function is compatible with both Linux and macOS.
#   -   It uses `go env GOPRIVATE` to reliably fetch the GOPRIVATE setting.
shell::get_go_privates() {
    local dry_run="false"

    # Check for dry-run option
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    local cmd="go env GOPRIVATE"

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::async "$cmd" &
        local pid=$!
        wait $pid

        if [ $? -eq 0 ]; then
            shell::colored_echo "🟢 Go privates setting retrieved successfully: ${cmd}" 46
        else
            shell::colored_echo "🔴 Error: Failed to retrieve GOPRIVATE." 31
            return 1
        fi
    fi
}

# shell::set_go_privates function
#
# Description:
#   Sets the GOPRIVATE environment variable to the provided value.
#   If GOPRIVATE already has values, the new values are appended
#   to the existing comma-separated list.
#   This variable is used by Go tools to determine which modules
#   should be considered private, affecting how Go commands handle dependencies.
#
# Usage:
#   shell::set_go_privates [-n] <repository1> [repository2] ...
#
# Parameters:
#   -n: Optional.
#   If provided, the command is printed using shell::on_evict instead of executed.
#   <repository1>: The first repository to add to GOPRIVATE.
#   [repository2] [repository3] ...: Additional repositories to add to GOPRIVATE.
#
# Options:
#   None
#
# Example:
#   shell::set_go_privates "example.com/private1"
#   shell::set_go_privates -n "example.com/private1" "example.com/internal"
#
# Instructions:
#   1.  Run `shell::set_go_privates <repository1> [repository2] ...` to set or append to the GOPRIVATE variable.
#   2.  Use `shell::set_go_privates -n <repository1> [repository2] ...` to preview the command.
#
# Notes:
#   -   This function is compatible with both Linux and macOS.
#   -   It uses `go env -w GOPRIVATE=<value>` to set the GOPRIVATE setting.
#   -   It supports dry-run and asynchronous execution.
shell::set_go_privates() {
    local dry_run="false"

    # Check for dry-run option
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Handle no arguments provided
    if [ $# -eq 0 ]; then
        shell::colored_echo "🔴 Error: No repositories provided." 31
        echo "Usage: shell::set_go_privates [-n] <repository1> [repository2] ..."
        return 1
    fi

    # Join all repositories with a comma
    local repositories_by_comma
    IFS=','
    repositories_by_comma="$*"
    unset IFS

    # Check if GOPRIVATE is already set
    local existing_go_private=$(go env GOPRIVATE)

    if [ -n "$existing_go_private" ]; then
        # Append to existing GOPRIVATE value
        repositories_by_comma="$existing_go_private,$repositories_by_comma"
    fi

    local cmd="go env -w GOPRIVATE=\"$repositories_by_comma\""

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::async "$cmd" &
        local pid=$!
        wait $pid

        if [ $? -eq 0 ]; then
            shell::colored_echo "🟢 GOPRIVATE set successfully to: $repositories_by_comma" 46
        else
            shell::colored_echo "🔴 Error: Failed to set GOPRIVATE." 31
            return 1
        fi
    fi
}

# shell::fzf_remove_go_privates function
#
# Description:
#   Interactively removes selected entries from the GOPRIVATE environment variable using fzf.
#   The GOPRIVATE variable is used by Go tools to determine which modules should be considered private,
#   affecting how Go commands handle authenticated access to dependencies.
#
# Usage:
#   shell::fzf_remove_go_privates [-n]
#
# Parameters:
#   -n: Optional. If provided, the command is printed using shell::on_evict instead of executed.
#
# Options:
#   None
#
# Example:
#   shell::fzf_remove_go_privates           # Interactively remove GOPRIVATE entries.
#   shell::fzf_remove_go_privates -n        # Preview the command without executing it.
#
# Instructions:
#   1. Run `shell::fzf_remove_go_privates` to select and remove entries from GOPRIVATE using fzf.
#   2. Use `shell::fzf_remove_go_privates -n` to see the command that would be executed.
#
# Notes:
#   - Requires fzf to be installed; automatically handled via shell::install_package.
#   - Compatible with both Linux (Ubuntu 22.04 LTS) and macOS.
#   - Uses `go env GOPRIVATE` to retrieve the current setting and `go env -w GOPRIVATE=...` to update it.
#   - Supports dry-run via shell::on_evict and asynchronous execution via shell::async.
#   - If GOPRIVATE is empty or no entries are selected, the function exits gracefully with a message.
# shell::fzf_remove_go_privates() {
#     local dry_run="false"
#     if [ "$1" = "-n" ]; then
#         dry_run="true"
#         shift
#     fi

#     # Ensure fzf is installed
#     shell::install_package "fzf"

#     # Retrieve current GOPRIVATE value
#     local current_goprivate
#     current_goprivate=$(go env GOPRIVATE)

#     # Check if GOPRIVATE is empty
#     if [ -z "$current_goprivate" ]; then
#         shell::colored_echo "🟡 GOPRIVATE is not set or empty. Nothing to remove." 33
#         return 0
#     fi

#     # Split GOPRIVATE into an array
#     local goprivate_array=($(echo "$current_goprivate" | tr ',' ' '))

#     # Use fzf to select entries to remove
#     local selected_array = $(echo "$current_goprivate" | tr ',' '\n' | fzf --multi --prompt="Select entries to remove: ")

#     # Check if any entries were selected
#     if [ ${#selected_array[@]} -eq 0 ]; then
#         shell::colored_echo "🟡 No entries selected to remove." 33
#         return 0
#     fi

#     # Create new array excluding selected entries
#     local new_goprivate_array=()
#     for item in "${goprivate_array[@]}"; do
#         if ! printf '%s\n' "${selected_array[@]}" | grep -q -x "$item"; then
#             new_goprivate_array+=("$item")
#         fi
#     done

#     # Join new array into a comma-separated string
#     local new_goprivate
#     if [ ${#new_goprivate_array[@]} -gt 0 ]; then
#         IFS=','
#         new_goprivate="${new_goprivate_array[*]}"
#         unset IFS
#     else
#         new_goprivate=""
#     fi

#     # Construct and execute the update command
#     local cmd="go env -w GOPRIVATE=\"$new_goprivate\""
#     if [ "$dry_run" = "true" ]; then
#         shell::on_evict "$cmd"
#     else
#         shell::async "$cmd" &
#         local pid=$!
#         wait $pid
#         if [ $? -eq 0 ]; then
#             shell::colored_echo "🟢 GOPRIVATE updated successfully." 46
#         else
#             shell::colored_echo "🔴 Error: Failed to update GOPRIVATE." 31
#             return 1
#         fi
#     fi
# }

# shell::fzf_remove_go_privates function
#
# Description:
#   Interactively removes entries from the GOPRIVATE environment variable using fzf.
#   This function allows the user to select which private repositories to remove
#   from the GOPRIVATE list.
#
# Usage:
#   shell::fzf_remove_go_privates [-n]
#
# Parameters:
#   -n: Optional.
#   If provided, the command is printed using shell::on_evict instead of executed.
#
# Options:
#   None
#
# Example:
#   shell::fzf_remove_go_privates
#   shell::fzf_remove_go_privates -n
#
# Instructions:
#   1. Run `shell::fzf_remove_go_privates` to interactively select and remove GOPRIVATE entries.
#   2. Use `shell::fzf_remove_go_privates -n` to preview the command.
#
# Notes:
#   - This function is compatible with both Linux and macOS.
#   - It requires fzf to be installed.
#   - It uses `go env -w GOPRIVATE=<value>` to update the GOPRIVATE setting.
shell::fzf_remove_go_privates() {
    local dry_run="false"

    # Check for dry-run option
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if fzf is installed
    shell::install_package fzf

    # Get the current GOPRIVATE value
    local current_go_private
    current_go_private=$(go env GOPRIVATE)

    # Handle the case where GOPRIVATE is not set
    if [ -z "$current_go_private" ]; then
        shell::colored_echo "🟡 GOPRIVATE is not set. Nothing to remove." 33
        return 0
    fi

    # Use fzf to select entries to remove
    local entries_to_remove
    entries_to_remove=$(echo "$current_go_private" | tr ',' '\n' | fzf --multi --prompt="Select GOPRIVATE entries to remove: ")

    # Handle no selection
    if [ -z "$entries_to_remove" ]; then
        shell::colored_echo "🟡 No entries selected for removal." 33
        return 0
    fi

    # Remove selected entries from the GOPRIVATE value
    local updated_go_private="$current_go_private"
    local entry

    IFS=$'\n'
    for entry in $entries_to_remove; do
        # Safely construct patterns for removal, handling edge cases
        local pattern
        pattern="(,$entry\\b)|(\\b$entry,)|(\\b$entry\\b)"

        # Use sed to remove matching entries and surrounding commas
        updated_go_private=$(echo "$updated_go_private" | sed -E "s/$pattern//g")

        # Remove any double commas or leading/trailing commas
        updated_go_private=$(echo "$updated_go_private" | sed -E "s/,+/,/g;s/^,//;s/,$//")

    done
    unset IFS

    echo "DEBUG:updated_go_private values: $updated_go_private"
    # Construct the command to update GOPRIVATE
    local cmd="go env -w GOPRIVATE=\"$updated_go_private\""

    # Execute or preview the command
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::async "$cmd" &
        local pid=$!
        wait $pid

        if [ $? -eq 0 ]; then
            shell::colored_echo "🟢 GOPRIVATE updated successfully." 46
        else
            shell::colored_echo "🔴 Error: Failed to update GOPRIVATE." 31
            return 1
        fi
    fi
}
