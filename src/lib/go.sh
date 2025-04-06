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
# Interactively removes selected entries from the GOPRIVATE environment variable using fzf.
#
# Usage:
#   shell::fzf_remove_go_privates [-n]
#
# Parameters:
#   - -n          : Optional dry-run flag.
#                   If provided, the command is printed using shell::on_evict instead of executed.
#
# Description:
#   This function enhances GOPRIVATE management by:
#   - Retrieving the current GOPRIVATE value using go env
#   - Using fzf to interactively select entries for removal
#   - Updating GOPRIVATE with the remaining entries
#   - Supporting dry-run mode and asynchronous execution
#
# Example:
#   shell::fzf_remove_go_privates     # Interactively remove GOPRIVATE entries
#   shell::fzf_remove_go_privates -n  # Preview the removal command
#
# Notes:
#   - Requires fzf and Go environment tools
#   - Maintains existing entries not selected for removal
#   - Handles comma-separated GOPRIVATE format automatically
shell::fzf_remove_go_privates() {
    local dry_run="false"

    # Check for dry-run option
    if [[ "$1" == "-n" ]]; then
        dry_run="true"
        shift
    fi

    # Install fzf if not available
    shell::install_package fzf

    # Get current GOPRIVATE value
    local current_privates
    current_privates=$(go env GOPRIVATE 2>/dev/null)

    # Handle empty GOPRIVATE
    if [[ -z "$current_privates" ]]; then
        shell::colored_echo "🟢 GOPRIVATE is already empty" 46
        return 0
    fi

    # Convert to array
    local -a private_array
    IFS=',' read -ra private_array <<<"$current_privates"

    # Select entries to remove using fzf
    local selected
    selected=$(printf "%s\n" "${private_array[@]}" | fzf --multi --prompt="Select entries to remove: ")

    # Exit if no selection
    if [[ -z "$selected" ]]; then
        shell::colored_echo "🟡 No entries selected for removal" 33
        return 0
    fi

    # Filter out selected entries
    local -a new_privates
    for entry in "${private_array[@]}"; do
        if ! grep -qxF "$entry" <<<"$selected"; then
            new_privates+=("$entry")
        fi
    done

    # Join remaining entries
    local new_value
    IFS=',' new_value="${new_privates[*]}"
    unset IFS

    # Build update command
    local cmd="go env -w GOPRIVATE=\"$new_value\""

    # Execute or preview
    if [[ "$dry_run" == "true" ]]; then
        shell::on_evict "$cmd"
    else
        shell::colored_echo "🔍 Updating GOPRIVATE..." 36
        shell::async "$cmd" &
        local pid=$!
        wait $pid

        if [[ $? -eq 0 ]]; then
            shell::colored_echo "🟢 GOPRIVATE updated successfully" 46
        else
            shell::colored_echo "🔴 Failed to update GOPRIVATE" 196
            return 1
        fi
    fi
}
