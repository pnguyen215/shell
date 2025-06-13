#!/bin/bash
# workspace.sh

# shell::add_workspace function
# Creates a new workspace with profile.conf and default .ssh/*.conf templates populated via shell::ini_write.
#
# Usage:
# shell::add_workspace [-n] <workspace_name>
#
# Parameters:
# - -n : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
# - <workspace_name> : The name of the workspace to create.
#
# Description:
# This function creates a new workspace directory under $SHELL_CONF_WORKING_WORKSPACE/workspace/<workspace_name>,
# initializes a profile.conf file and a .ssh/ directory with default SSH config templates (db.conf, redis.conf, etc.).
# It uses shell::ini_write to populate each .conf file with [dev] and [uat] blocks.
#
# Example:
# shell::add_workspace dxc
shell::add_workspace() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ADD_WORKSPACE"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if workspace name is provided
    if [ $# -lt 1 ]; then
        echo "Usage: shell::add_workspace [-n] <workspace_name>"
        return 1
    fi

    local name="$1"
    local base="$SHELL_CONF_WORKING_WORKSPACE"
    local dir="$base/$name"
    local profile="$dir/profile.conf"
    local ssh_dir="$dir/.ssh"
    local ssh_files=("db.conf" "redis.conf" "rmq.conf" "wordpress.conf")

    # Check if workspace already exists
    # If the directory already exists, we return an error
    if [ -d "$dir" ]; then
        shell::colored_echo "ERR: Workspace '$name' already exists at '$dir'" 196
        return 1
    fi

    # Create the workspace directory structure
    # We create the main workspace directory, the profile.conf file, and the .ssh directory with its files
    # We use mkdir -p to ensure parent directories are created as needed
    # We use touch to create the profile.conf and .ssh/*.conf files
    # The command is constructed as a single string to be executed later
    # This allows us to handle dry-run mode by simply printing the command instead of executing it
    local cmd="sudo mkdir -p \"$ssh_dir\" && sudo touch \"$profile\""
    for f in "${ssh_files[@]}"; do
        cmd="$cmd && sudo touch \"$ssh_dir/$f\""
    done

    # If dry-run mode is enabled, we print the command instead of executing it
    # This allows us to see what would be done without making any changes
    # If dry_run is true, we call shell::on_evict with the command
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::run_cmd_eval "$cmd"
        shell::colored_echo "INFO: Workspace '$name' created at '$dir'" 46

        # Populate profile.conf with default values
        # We use shell::ini_write to write default values to the profile.conf file
        # This includes the workspace name, description, and other relevant fields
        # We use the shell::ini_write function to write these values
        for f in "${ssh_files[@]}"; do
            local file="$ssh_dir/$f"
            shell::colored_echo "DEBUG: Populating '$f' with default [dev] and [uat] blocks..." 244

            shell::ini_write "$file" "dev" "SSH_DESC" "Development Tunnel for $f"
            shell::ini_write "$file" "dev" "SSH_PRIVATE_KEY_REF" "$HOME/.ssh/id_rsa"
            shell::ini_write "$file" "dev" "SSH_SERVER_ADDR" "127.0.0.1"
            shell::ini_write "$file" "dev" "SSH_SERVER_PORT" "2222"
            shell::ini_write "$file" "dev" "SSH_SERVER_USER" "sysadmin"
            shell::ini_write "$file" "dev" "SSH_LOCAL_ADDR" "127.0.0.1"
            shell::ini_write "$file" "dev" "SSH_LOCAL_PORT" "5432"

            shell::ini_write "$file" "uat" "SSH_DESC" "UAT Tunnel for $f"
            shell::ini_write "$file" "uat" "SSH_PRIVATE_KEY_REF" "$HOME/.ssh/id_rsa"
            shell::ini_write "$file" "uat" "SSH_SERVER_ADDR" "127.0.0.1"
            shell::ini_write "$file" "uat" "SSH_SERVER_PORT" "2223"
            shell::ini_write "$file" "uat" "SSH_SERVER_USER" "sysadmin"
            shell::ini_write "$file" "uat" "SSH_LOCAL_ADDR" "127.0.0.1"
            shell::ini_write "$file" "uat" "SSH_LOCAL_PORT" "5432"
        done
    fi
}
