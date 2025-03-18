#!/bin/bash
# profile.sh

# get_profile_dir function
# Returns the path to the profile directory for a given profile name.
#
# Usage:
#   get_profile_dir <profile_name>
#
# Parameters:
#   - <profile_name>: The name of the profile.
#
# Description:
#   Constructs and returns the path to the profile directory within the workspace,
#   located at $SHELL_CONF_WORKING/workspace.
#
# Example:
#   profile_dir=$(get_profile_dir "neyu")  # Returns "$SHELL_CONF_WORKING/workspace/neyu"
get_profile_dir() {
    if [ $# -lt 1 ]; then
        echo "Usage: get_profile_dir <profile_name>"
        return 1
    fi
    local profile_name="$1"
    echo "$SHELL_CONF_WORKING_WORKSPACE/$profile_name"
}

# ensure_workspace function
# Ensures that the workspace directory exists.
#
# Usage:
#   ensure_workspace
#
# Description:
#   Checks if the workspace directory ($SHELL_CONF_WORKING/workspace) exists.
#   If it does not exist, creates it using mkdir -p.
#
# Example:
#   ensure_workspace
ensure_workspace() {
    if [ ! -d "$SHELL_CONF_WORKING_WORKSPACE" ]; then
        run_cmd mkdir -p "$SHELL_CONF_WORKING_WORKSPACE"
    fi
}
