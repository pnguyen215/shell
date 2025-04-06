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
            shell::colored_echo "🔴 Error: Failed to retrieve GOPRIVATE." 196
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
        shell::colored_echo "🔴 Error: No repositories provided." 196
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
            shell::colored_echo "🔴 Error: Failed to set GOPRIVATE." 196
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
            shell::colored_echo "🔴 Error: Failed to update GOPRIVATE." 196
            return 1
        fi
    fi
}

# shell::create_go_app function
# Creates a new Go application by initializing a Go module and tidying dependencies.
#
# Usage:
#   shell::create_go_app [-n] <app_name|github_url>
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the commands are printed using shell::on_evict instead of being executed.
#   - <app_name|github_url> : The name of the application or a GitHub URL to initialize the module.
#
# Description:
#   This function checks if the provided application name is a valid URL. If it is, it extracts the module name
#   from the URL. It then initializes the Go module using `go mod init` and tidies the dependencies using `go mod tidy`.
#   In dry-run mode, the commands are displayed without execution.
#
# Example:
#   shell::create_go_app my_app         # Initializes a Go module named 'my_app'.
#   shell::create_go_app -n my_app      # Previews the initialization commands without executing them.
shell::create_go_app() {
    local app_name="$1"
    local dry_run="false"

    # Check for dry-run option
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
        app_name="$1"
    fi

    # Validate app name
    if [ -z "$app_name" ]; then
        shell::colored_echo "🔴 Error: Application name is required." 196
        shell::colored_echo "Usage: shell::create_go_app [-n] <app_name|github_url>"
        return 1
    fi

    # Check if the app name is a URL
    local is_url="false"
    if [[ "$app_name" =~ ^(http:\/\/|https:\/\/) ]]; then
        is_url="true"
    fi

    local module_name="$app_name"

    # If it's a URL, extract the module name
    if [ "$is_url" = "true" ]; then
        # Remove "http://" or "https://"
        module_name="${module_name#http://}"
        module_name="${module_name#https://}"
        # Remove trailing slashes
        module_name="${module_name%/}"
    fi

    local init_cmd="go mod init $module_name"
    local tidy_cmd="go mod tidy"

    # Execute go mod init
    shell::colored_echo "🔍 Initializing Go module: $module_name" 36
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$init_cmd"
    else
        shell::run_cmd_eval "$init_cmd"
    fi

    # Execute go mod tidy
    shell::colored_echo "🔍 Tidying Go dependencies" 36
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$tidy_cmd"
    else
        shell::run_cmd_eval "$tidy_cmd"
    fi

    shell::colored_echo "🟢 Go application initialized successfully." 46
}

shell::add_go_app_settings() {
    shell::download_dataset "docs/VERSION_RELEASE.md" "$SHELL_PROJECT_DOC_VERSION_RELEASE"
    # shell::download_dataset "" ""
    # shell::download_dataset "" ""
    # shell::download_dataset "" ""
    # shell::download_dataset "" ""
    # shell::download_dataset "" ""
}
