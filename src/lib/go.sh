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
#   Uses fzf to interactively select and remove entries from the GOPRIVATE environment variable.
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
#   shell::fzf_remove_go_privates           # Interactively remove entries from GOPRIVATE.
#   shell::fzf_remove_go_privates -n        # Preview the command without executing it.
#
# Instructions:
#   1. Run `shell::fzf_remove_go_privates` to select and remove GOPRIVATE entries via fzf.
#   2. Use `shell::fzf_remove_go_privates -n` to see the command that would be executed.
#
# Notes:
#   - Requires fzf and Go to be installed; fzf is installed automatically if missing.
#   - Uses `go env GOPRIVATE` to retrieve the current value.
#   - Uses `go env -w GOPRIVATE=<new_value>` to set the updated value.
#   - Supports dry-run and asynchronous execution via shell::on_evict and shell::async.
#   - Compatible with both Linux (Ubuntu 22.04 LTS) and macOS.
shell::fzf_remove_go_privates() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Ensure fzf is installed
    shell::install_package fzf

    # Retrieve current GOPRIVATE value
    local current_goprivate=$(go env GOPRIVATE)
    if [ -z "$current_goprivate" ]; then
        shell::colored_echo "🟡 GOPRIVATE is not set." 33
        return 0
    fi

    # Split GOPRIVATE into an array of entries
    local entries=($(echo "$current_goprivate" | tr ',' ' '))

    # Use fzf to select entries to remove (multi-select enabled)
    local selected=$(printf "%s\n" "${entries[@]}" | fzf --multi --prompt="Select entries to remove: ")
    if [ -z "$selected" ]; then
        shell::colored_echo "🟡 No entries selected for removal." 33
        return 0
    fi

    # Build new entries list by excluding selected ones
    local new_entries=()
    for entry in "${entries[@]}"; do
        if ! echo "$selected" | grep -q "^$entry$"; then
            new_entries+=("$entry")
        fi
    done

    # Construct the new GOPRIVATE value
    local new_goprivate=$(
        IFS=','
        echo "${new_entries[*]}"
    )

    # Prepare the command to update GOPRIVATE
    local cmd="go env -w GOPRIVATE=\"$new_goprivate\""

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        # Execute asynchronously and wait for completion
        shell::async "$cmd" &
        local pid=$!
        wait $pid
        if [ $? -eq 0 ]; then
            shell::colored_echo "🟢 Removed selected entries from GOPRIVATE." 46
        else
            shell::colored_echo "🔴 Error: Failed to update GOPRIVATE." 31
            return 1
        fi
    fi
}
