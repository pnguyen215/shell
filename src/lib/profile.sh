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
        run_cmd_eval sudo mkdir -p "$SHELL_CONF_WORKING_WORKSPACE"
    fi
}

# add_profile function
# Creates a new profile directory and initializes it with a profile.conf file.
#
# Usage:
#   add_profile [-n] <profile_name>
#
# Parameters:
#   - -n             : Optional dry-run flag. If provided, commands are printed using on_evict instead of executed.
#   - <profile_name> : The name of the profile to create.
#
# Description:
#   Ensures the workspace directory exists, then creates a new directory for the specified profile
#   and initializes it with an empty profile.conf file. If the profile already exists, it prints a warning.
#
# Example:
#   add_profile my_profile         # Creates the profile directory and profile.conf.
#   add_profile -n my_profile      # Prints the commands without executing them.
add_profile() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi
    if [ $# -lt 1 ]; then
        echo "Usage: add_profile [-n] <profile_name>"
        return 1
    fi
    local profile_name="$1"
    local profile_dir=$(get_profile_dir "$profile_name")
    if [ -d "$profile_dir" ]; then
        colored_echo "🟡 Profile '$profile_name' already exists." 11
        return 1
    fi

    local cmd="sudo mkdir -p \"$profile_dir\" && sudo touch \"$profile_dir/profile.conf\""
    if [ "$dry_run" = "true" ]; then
        on_evict "$cmd"
    else
        ensure_workspace
        run_cmd_eval "$cmd"
        colored_echo "🟢 Created profile '$profile_name'." 46
    fi
}

# read_profile function
# Sources the profile.conf file from the specified profile directory.
#
# Usage:
#   read_profile [-n] <profile_name>
#
# Parameters:
#   - -n             : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
#   - <profile_name> : The name of the profile to read.
#
# Description:
#   Checks if the specified profile exists and sources its profile.conf file to load configurations
#   into the current shell session. If the profile or file does not exist, it prints an error.
#
# Example:
#   read_profile my_profile         # Sources profile.conf from my_profile.
#   read_profile -n my_profile      # Prints the sourcing command without executing it.
read_profile() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi
    if [ $# -lt 1 ]; then
        echo "Usage: read_profile [-n] <profile_name>"
        return 1
    fi
    local profile_name="$1"
    local profile_dir=$(get_profile_dir "$profile_name")
    local profile_conf="$profile_dir/profile.conf"
    if [ ! -d "$profile_dir" ]; then
        colored_echo "🔴 Profile '$profile_name' does not exist." 196
        return 1
    fi
    if [ ! -f "$profile_conf" ]; then
        colored_echo "🔴 Profile configuration file '$profile_conf' not found." 196
        return 1
    fi
    if [ "$dry_run" = "true" ]; then
        read_conf -n "$profile_conf"
    else
        read_conf "$profile_conf"
    fi
}

# update_profile function
# Opens the profile.conf file of the specified profile in the default editor.
#
# Usage:
#   update_profile [-n] <profile_name>
#
# Parameters:
#   - -n             : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
#   - <profile_name> : The name of the profile to update.
#
# Description:
#   Checks if the specified profile exists and opens its profile.conf file in the editor specified
#   by the EDITOR environment variable (defaults to 'nano' if unset).
#
# Example:
#   update_profile my_profile         # Opens profile.conf in the default editor.
#   update_profile -n my_profile      # Prints the editor command without executing it.
update_profile() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi
    if [ $# -lt 1 ]; then
        echo "Usage: update_profile [-n] <profile_name>"
        return 1
    fi
    local profile_name="$1"
    local profile_dir=$(get_profile_dir "$profile_name")
    local profile_conf="$profile_dir/profile.conf"
    if [ ! -d "$profile_dir" ]; then
        colored_echo "🔴 Profile '$profile_name' does not exist." 196
        return 1
    fi
    if [ ! -f "$profile_conf" ]; then
        colored_echo "🔴 Profile configuration file '$profile_conf' not found." 196
        return 1
    fi
    local editor="${EDITOR:-vim}"
    local cmd="sudo $editor \"$profile_conf\""
    if [ "$dry_run" = "true" ]; then
        on_evict "$cmd"
    else
        run_cmd_eval "$cmd"
    fi
}

# remove_profile function
# Deletes the specified profile directory after user confirmation.
#
# Usage:
#   remove_profile [-n] <profile_name>
#
# Parameters:
#   - -n             : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
#   - <profile_name> : The name of the profile to remove.
#
# Description:
#   Prompts for confirmation before deleting the profile directory and its contents.
#   If confirmed, removes the directory; otherwise, aborts the operation.
#
# Example:
#   remove_profile my_profile         # Prompts to confirm deletion of my_profile.
#   remove_profile -n my_profile      # Prints the removal command without executing it.
remove_profile() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi
    if [ $# -lt 1 ]; then
        echo "Usage: remove_profile [-n] <profile_name>"
        return 1
    fi
    local profile_name="$1"
    local profile_dir=$(get_profile_dir "$profile_name")
    if [ ! -d "$profile_dir" ]; then
        colored_echo "🔴 Profile '$profile_name' does not exist." 196
        return 1
    fi
    if [ "$dry_run" = "true" ]; then
        on_evict "sudo rm -rf \"$profile_dir\""
    else
        colored_echo "Are you sure you want to remove profile '$profile_name'? [y/N]" 33
        read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            run_cmd_eval sudo rm -rf "$profile_dir"
            colored_echo "🟢 Removed profile '$profile_name'." 46
        else
            colored_echo "🟡 Removal aborted." 11
        fi
    fi
}

# get_profile function
# Displays the contents of the profile.conf file for the specified profile.
#
# Usage:
#   get_profile <profile_name>
#
# Parameters:
#   - <profile_name> : The name of the profile to display.
#
# Description:
#   Checks if the specified profile exists and displays the contents of its profile.conf file.
#   If the profile or file does not exist, it prints an error.
#
# Example:
#   get_profile my_profile         # Displays the contents of profile.conf for my_profile.
get_profile() {
    if [ $# -lt 1 ]; then
        echo "Usage: get_profile <profile_name>"
        return 1
    fi
    local profile_name="$1"
    local profile_dir=$(get_profile_dir "$profile_name")
    local profile_conf="$profile_dir/profile.conf"
    if [ ! -d "$profile_dir" ]; then
        colored_echo "🔴 Profile '$profile_name' does not exist." 196
        return 1
    fi
    if [ ! -f "$profile_conf" ]; then
        colored_echo "🔴 Profile configuration file '$profile_conf' not found." 196
        return 1
    fi
    colored_echo "📄 Contents of '$profile_conf':" 33
    run_cmd_eval cat "$profile_conf"
}

# rename_profile function
# Renames the specified profile directory.
#
# Usage:
#   rename_profile [-n] <old_name> <new_name>
#
# Parameters:
#   - -n             : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
#   - <old_name>     : The current name of the profile.
#   - <new_name>     : The new name for the profile.
#
# Description:
#   Checks if the old profile exists and the new profile name does not already exist,
#   then renames the directory accordingly.
#
# Example:
#   rename_profile old_profile new_profile         # Renames old_profile to new_profile.
#   rename_profile -n old_profile new_profile      # Prints the rename command without executing it.
rename_profile() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi
    if [ $# -lt 2 ]; then
        echo "Usage: rename_profile [-n] <old_name> <new_name>"
        return 1
    fi
    local old_name="$1"
    local new_name="$2"
    local old_dir=$(get_profile_dir "$old_name")
    local new_dir=$(get_profile_dir "$new_name")
    if [ ! -d "$old_dir" ]; then
        colored_echo "🔴 Profile '$old_name' does not exist." 196
        return 1
    fi
    if [ -d "$new_dir" ]; then
        colored_echo "🔴 Profile '$new_name' already exists." 196
        return 1
    fi
    local cmd="sudo mv \"$old_dir\" \"$new_dir\""
    if [ "$dry_run" = "true" ]; then
        on_evict "$cmd"
    else
        run_cmd_eval "$cmd"
        colored_echo "🟢 Renamed profile '$old_name' to '$new_name'." 46
    fi
}
