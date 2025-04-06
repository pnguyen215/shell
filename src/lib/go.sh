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
#   Interactively removes entries from the GOPRIVATE environment variable using fzf for selection.
#   This allows the user to choose which private modules to exclude from GOPRIVATE.
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
#   1.  Run `shell::fzf_remove_go_privates` to interactively select and remove GOPRIVATE entries.
#   2.  Use `shell::fzf_remove_go_privates -n` to preview the command.
#
# Notes:
#   -   This function requires fzf to be installed.
#   -   It supports dry-run and asynchronous execution.
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
    local current_go_private=$(go env GOPRIVATE)

    # Handle the case where GOPRIVATE is empty
    if [ -z "$current_go_private" ]; then
        shell::colored_echo "🟡 GOPRIVATE is currently empty. Nothing to remove." 33
        return 0
    fi

    # Use fzf to select entries to remove
    local selected_entries
    selected_entries=$(echo "$current_go_private" | tr ',' '\n' | fzf --multi --prompt="Select entries to remove: ")

    # Handle no selection
    if [ -z "$selected_entries" ]; then
        shell::colored_echo "🟡 No entries selected for removal." 33
        return 0
    fi

    # Convert the current GOPRIVATE string to an array
    IFS=',' read -ra go_private_array <<<"$current_go_private"

    # Convert the selected entries string to an array
    IFS=$'\n' read -ra selected_array <<<"$selected_entries"
    unset IFS

    # Create an array to hold the updated GOPRIVATE entries
    local updated_go_private_array=()

    # Iterate through the current GOPRIVATE entries
    for entry in "${go_private_array[@]}"; do
        # Check if the current entry is in the selected entries
        local found=false
        for selected in "${selected_array[@]}"; do
            if [ "$entry" = "$selected" ]; then
                found=true
                break
            fi
        done
        # If the entry was not selected for removal, add it to the updated array
        if [ "$found" = "false" ]; then
            updated_go_private_array+=("$entry")
        fi
    done

    # Join the updated GOPRIVATE entries back into a comma-separated string
    IFS=','
    local updated_go_private="${updated_go_private_array[*]}"
    unset IFS

    # Construct the command to set the updated GOPRIVATE value
    local cmd="go env -w GOPRIVATE=\"$updated_go_private\""

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
