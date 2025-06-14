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

    # Sanitize the workspace name
    # We use shell::sanitize_lower_var_name to ensure the name is in lowercase and safe for use as a directory name
    # This function replaces non-alphanumeric characters with underscores
    # This helps prevent issues with invalid directory names
    name=$(shell::sanitize_lower_var_name "$name")

    local base="$SHELL_CONF_WORKING_WORKSPACE"
    local dir="$base/$name"
    local profile="$dir/profile.conf"
    local ssh_dir="$dir/.ssh"
    local ssh_files=("server.conf" "db.conf" "redis.conf" "rmq.conf" "ast.conf" "kafka.conf" "zookeeper.conf" "nginx.conf" "web.conf" "app.conf" "api.conf" "cache.conf" "search.conf")

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
    local cmd="mkdir -p \"$ssh_dir\" && touch \"$profile\""
    for f in "${ssh_files[@]}"; do
        cmd="$cmd && touch \"$ssh_dir/$f\""
    done

    # If dry-run mode is enabled, we print the command instead of executing it
    # This allows us to see what would be done without making any changes
    # If dry_run is true, we call shell::on_evict with the command
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::create_file_if_not_exists "$profile"
        shell::create_directory_if_not_exists "$ssh_dir"
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

# shell::remove_workspace function
# Removes a workspace directory after confirmation.
#
# Usage:
# shell::remove_workspace [-n] <workspace_name>
#
# Parameters:
# - -n : Optional dry-run flag.
# - <workspace_name> : The name of the workspace to remove.
#
# Description:
# Prompts for confirmation before deleting the workspace directory.
#
# Example:
# shell::remove_workspace dxc
shell::remove_workspace() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_REMOVE_WORKSPACE"
        return 0
    fi

    # Check if dry-run mode is enabled
    # If the first argument is -n, we set dry_run to true
    # This allows us to print the command that would be executed without actually running it
    # This is useful for testing or when we want to see what would happen without making changes
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if workspace name is provided
    # If no workspace name is provided, we print usage information and return an error
    # This ensures the user knows how to use the command correctly
    if [ $# -lt 1 ]; then
        echo "Usage: shell::remove_workspace [-n] <workspace_name>"
        return 1
    fi

    local name="$1"

    # Sanitize the workspace name
    # We use shell::sanitize_lower_var_name to ensure the name is in lowercase and safe for use as a directory name
    # This function replaces non-alphanumeric characters with underscores
    # This helps prevent issues with invalid directory names
    name=$(shell::sanitize_lower_var_name "$name")

    local base="$SHELL_CONF_WORKING_WORKSPACE"
    local dir="$base/$name"

    # Check if the workspace directory exists
    # If the directory does not exist, we print an error message and return
    if [ ! -d "$dir" ]; then
        shell::colored_echo "ERR: Workspace '$name' does not exist at '$dir'" 196
        return 1
    fi

    # If dry-run mode is enabled, we print the command to delete the workspace directory
    # This allows us to see what would be done without actually deleting anything
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "sudo rm -rf \"$dir\""
    else
        shell::colored_echo "[q] Are you sure you want to delete workspace '$name'? [y/N]" 208
        read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            shell::run_cmd_eval "sudo rm -rf \"$dir\""
            shell::colored_echo "INFO: Workspace '$name' removed." 46
        else
            shell::colored_echo "WARN: Deletion aborted." 11
        fi
    fi
}

# shell::fzf_view_workspace function
# Interactively selects a .ssh/*.conf file from a workspace and previews it using shell::fzf_view_ini_viz.
#
# Usage:
# shell::fzf_view_workspace <workspace_name>
#
# Parameters:
# - <workspace_name> : The name of the workspace to view.
#
# Description:
# This function locates all .conf files under $SHELL_CONF_WORKING_WORKSPACE/<workspace_name>/.ssh/,
# and uses fzf to let the user select one. The selected file is then passed to shell::fzf_view_ini_viz
# for real-time preview of all decoded values.
#
# Example:
# shell::fzf_view_workspace dxc
shell::fzf_view_workspace() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_VIEW_WORKSPACE"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::fzf_view_workspace <workspace_name>"
        return 1
    fi

    local name="$1"

    # Sanitize the workspace name
    # We use shell::sanitize_lower_var_name to ensure the name is in lowercase and safe for use as a directory name
    # This function replaces non-alphanumeric characters with underscores
    # This helps prevent issues with invalid directory names
    name=$(shell::sanitize_lower_var_name "$name")

    local base="$SHELL_CONF_WORKING_WORKSPACE"
    local ssh_dir="$base/$name/.ssh"

    # Check if workspace exists
    if [ ! -d "$ssh_dir" ]; then
        shell::colored_echo "ERR: Workspace '$name' does not exist or has no .ssh directory." 196
        return 1
    fi

    # Find all .conf files in the .ssh directory
    local conf_files
    conf_files=$(find "$ssh_dir" -type f -name "*.conf")

    if [ -z "$conf_files" ]; then
        shell::colored_echo "WARN: No .conf files found in '$ssh_dir'" 11
        return 0
    fi

    # Ensure fzf is installed
    shell::install_package fzf

    # Use fzf to select one of the .conf files
    local selected_file
    selected_file=$(echo "$conf_files" | fzf --prompt="Select a config file to view: ")

    # If no file was selected, we print an error message and return
    # This ensures the user knows they need to select a file
    if [ -z "$selected_file" ]; then
        shell::colored_echo "ERR: No file selected." 196
        return 1
    fi

    shell::fzf_view_ini_viz "$selected_file"
}

# shell::fzf_edit_workspace function
# Interactively selects a .ssh/*.conf file from a workspace and opens it for editing using shell::fzf_edit_ini_viz.
# Usage:
# shell::fzf_edit_workspace <workspace_name>
#
# Parameters:
# - <workspace_name> : The name of the workspace to edit.
#
# Description:
# This function locates all .conf files under $SHELL_CONF_WORKING_WORKSPACE/<workspace_name>/.ssh/,
# and uses fzf to let the user select one. The selected file is then passed to shell::fzf_edit_ini_viz
# for editing.
#
# Example:
# shell::fzf_edit_workspace dxc
shell::fzf_edit_workspace() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_EDIT_WORKSPACE"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::fzf_edit_workspace <workspace_name>"
        return 1
    fi

    local name="$1"

    # Sanitize the workspace name
    # We use shell::sanitize_lower_var_name to ensure the name is in lowercase and safe for use as a directory name
    # This function replaces non-alphanumeric characters with underscores
    # This helps prevent issues with invalid directory names
    name=$(shell::sanitize_lower_var_name "$name")

    local base="$SHELL_CONF_WORKING_WORKSPACE"
    local ssh_dir="$base/$name/.ssh"

    # Check if workspace exists
    if [ ! -d "$ssh_dir" ]; then
        shell::colored_echo "ERR: Workspace '$name' does not exist or has no .ssh directory." 196
        return 1
    fi

    # Find all .conf files in the .ssh directory
    local conf_files
    conf_files=$(find "$ssh_dir" -type f -name "*.conf")

    if [ -z "$conf_files" ]; then
        shell::colored_echo "WARN: No .conf files found in '$ssh_dir'" 11
        return 0
    fi

    # Ensure fzf is installed
    shell::install_package fzf

    # Use fzf to select one of the .conf files for editing
    local selected_file
    selected_file=$(echo "$conf_files" | fzf --prompt="Select a config file to edit: ")

    # If no file was selected, we print an error message and return
    if [ -z "$selected_file" ]; then
        shell::colored_echo "ERR: No file selected." 196
        return 1
    fi

    # Call shell::fzf_edit_ini_viz to edit the selected file
    shell::fzf_edit_ini_viz "$selected_file"
}

# shell::fzf_remove_workspace function
# Interactively selects a workspace using fzf and removes it after confirmation.
#
# Usage:
# shell::fzf_remove_workspace [-n]
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the removal command is printed using shell::on_evict instead of executed.
#
# Description:
# This function lists all workspace directories under $SHELL_CONF_WORKING_WORKSPACE,
# uses fzf to let the user select one, and then calls shell::remove_workspace to delete it.
#
# Example:
# shell::fzf_remove_workspace
shell::fzf_remove_workspace() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_REMOVE_WORKSPACE"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    local base="$SHELL_CONF_WORKING_WORKSPACE"
    local workspace_dir="$base"

    # Check if workspace directory exists
    if [ ! -d "$workspace_dir" ]; then
        shell::colored_echo "ERR: Workspace directory '$workspace_dir' not found." 196
        return 1
    fi

    # Ensure fzf is installed
    shell::install_package fzf

    # List all workspace directories and use fzf to select one
    # We use find to locate directories under the workspace directory
    local selected
    selected=$(find "$workspace_dir" -mindepth 1 -maxdepth 1 -type d |
        xargs -n 1 basename |
        fzf --prompt="Select workspace to remove: ")

    # If no workspace was selected, we print an error message and return
    if [ -z "$selected" ]; then
        shell::colored_echo "ERR: No workspace selected." 196
        return 1
    fi

    # If the dry mode is enabled, we print the command to remove the workspace
    # This allows us to see what would be done without actually deleting anything
    if [ "$dry_run" = "true" ]; then
        shell::remove_workspace -n "$selected"
    else
        shell::remove_workspace "$selected"
    fi
}

# shell::rename_workspace function
# Renames a workspace directory from an old name to a new name.
#
# Usage:
# shell::rename_workspace [-n] <old_name> <new_name>
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the rename command is printed using shell::on_evict instead of executed.
# - <old_name> : The current name of the workspace.
# - <new_name> : The new name for the workspace.
#
# Description:
# This function renames a workspace directory under $SHELL_CONF_WORKING_WORKSPACE
# from <old_name> to <new_name>. It checks for the existence of the old workspace
# and ensures the new name does not already exist. If valid, it renames the directory.
#
# Example:
# shell::rename_workspace dxc dxc-renamed
# shell::rename_workspace -n dxc dxc-renamed
shell::rename_workspace() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_RENAME_WORKSPACE"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if old and new workspace names are provided
    # If not, we print usage information and return an error
    # This ensures the user knows how to use the command correctly
    # We check if at least two arguments are provided
    # The first argument is the old name and the second is the new name
    # If less than two arguments are provided, we print usage information
    # and return an error code
    if [ $# -lt 2 ]; then
        echo "Usage: shell::rename_workspace [-n] <old_name> <new_name>"
        return 1
    fi

    local old_name="$1"
    local new_name="$2"

    # Sanitize the old and new workspace names
    # We use shell::sanitize_lower_var_name to ensure the names are in lowercase and safe for use as directory names
    # This function replaces non-alphanumeric characters with underscores
    old_name=$(shell::sanitize_lower_var_name "$old_name")
    new_name=$(shell::sanitize_lower_var_name "$new_name")

    local base="$SHELL_CONF_WORKING_WORKSPACE"
    local old_dir="$base/$old_name"
    local new_dir="$base/$new_name"

    # Check if the old workspace exists and the new workspace does not
    # We check if the old directory exists and if the new directory does not
    # If the old directory does not exist, we print an error message and return
    if [ ! -d "$old_dir" ]; then
        shell::colored_echo "ERR: Workspace '$old_name' does not exist at '$old_dir'" 196
        return 1
    fi

    # Check if the new workspace already exists
    # If the new directory already exists, we print an error message and return
    # This prevents overwriting an existing workspace
    if [ -d "$new_dir" ]; then
        shell::colored_echo "ERR: Workspace '$new_name' already exists at '$new_dir'" 196
        return 1
    fi

    # Construct the command to rename the workspace directory
    # We use sudo mv to move the old directory to the new directory
    # This effectively renames the workspace
    # If dry-run mode is enabled, we print the command instead of executing it
    local cmd="sudo mv \"$old_dir\" \"$new_dir\""
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::run_cmd_eval "$cmd"
        shell::colored_echo "INFO: Workspace renamed from '$old_name' to '$new_name'" 46
    fi
}

# shell::fzf_rename_workspace function
# Interactively selects a workspace using fzf and renames it.
#
# Usage:
# shell::fzf_rename_workspace [-n]
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the rename command is printed using shell::on_evict instead of executed.
#
# Description:
# This function lists all workspace directories under $SHELL_CONF_WORKING_WORKSPACE,
# uses fzf to let the user select one, prompts for a new name, and then calls shell::rename_workspace
# to rename the selected workspace.
#
# Example:
# shell::fzf_rename_workspace
shell::fzf_rename_workspace() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_RENAME_WORKSPACE"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    local base="$SHELL_CONF_WORKING_WORKSPACE"
    local workspace_dir="$base"

    # Check if workspace directory exists
    if [ ! -d "$workspace_dir" ]; then
        shell::colored_echo "ERR: Workspace directory '$workspace_dir' not found." 196
        return 1
    fi

    # Ensure fzf is installed
    shell::install_package fzf

    # List all workspace directories and use fzf to select one
    local selected
    selected=$(find "$workspace_dir" -mindepth 1 -maxdepth 1 -type d |
        xargs -n 1 basename |
        fzf --prompt="Select workspace to rename: ")

    # Check if a workspace was selected
    # If no workspace was selected, we print an error message and return
    # This ensures the user knows they need to select a workspace
    # We check if the selected variable is empty
    # If it is empty, we print an error message and return
    if [ -z "$selected" ]; then
        shell::colored_echo "ERR: No workspace selected." 196
        return 1
    fi

    shell::colored_echo "[e] Enter new name for workspace '$selected':" 208
    read -r new_name

    # Check if a new name was entered
    # If no new name was entered, we print an error message and return
    # This ensures the user knows they need to provide a new name
    if [ -z "$new_name" ]; then
        shell::colored_echo "ERR: No new name entered. Aborting rename." 196
        return 1
    fi

    # If dry mode is enabled, we print the command to rename the workspace
    # This allows us to see what would be done without actually renaming anything
    if [ "$dry_run" = "true" ]; then
        shell::rename_workspace -n "$selected" "$new_name"
    else
        shell::rename_workspace "$selected" "$new_name"
    fi
}

# shell::fzf_manage_workspace function
# Interactively selects a workspace and performs an action (view, edit, rename, remove) using fzf.
#
# Usage:
# shell::fzf_manage_workspace [-n]
#
# Parameters:
# - -n : Optional dry-run flag. If provided, actions that support dry-run will be executed in dry-run mode.
#
# Description:
# This function lists all workspace directories under $SHELL_CONF_WORKING_WORKSPACE,
# uses fzf to let the user select one, then presents a list of actions to perform on the selected workspace.
# Supported actions include: view, edit, rename, and remove.
#
# Example:
# shell::fzf_manage_workspace
shell::fzf_manage_workspace() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_MANAGE_WORKSPACE"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if the workspace directory exists
    # We check if the base directory for workspaces exists
    # If it does not exist, we print an error message and return
    local base="$SHELL_CONF_WORKING_WORKSPACE"
    if [ ! -d "$base" ]; then
        shell::colored_echo "ERR: Workspace directory '$base' not found." 196
        return 1
    fi

    # Ensure fzf is installed
    shell::install_package fzf

    # List all workspace directories and use fzf to select one
    # We use find to locate directories under the workspace directory
    # We use xargs to convert the output of find into a list of directory names
    # We use fzf to let the user select one of the directories
    local selected
    selected=$(find "$base" -mindepth 1 -maxdepth 1 -type d |
        xargs -n 1 basename |
        fzf --prompt="Select workspace: ")

    # Check if a workspace was selected
    # If no workspace was selected, we print an error message and return
    # This ensures the user knows they need to select a workspace
    if [ -z "$selected" ]; then
        shell::colored_echo "ERR: No workspace selected." 196
        return 1
    fi

    # Prompt for action to perform on the selected workspace
    # We present a list of actions to the user using fzf
    # The actions include: view, edit, rename, and remove
    # We use printf to create a list of actions, which is then piped into fzf
    local action
    action=$(printf "view\nedit\nrename\nremove\nclone" |
        fzf --prompt="Action for workspace '$selected': ")

    # Check if an action was selected
    # If no action was selected, we print an error message and return
    # This ensures the user knows they need to select an action
    # We check if the action variable is empty
    # If it is empty, we print an error message and return
    if [ -z "$action" ]; then
        shell::colored_echo "ERR: No action selected." 196
        return 1
    fi

    # Perform the selected action on the workspace
    # We use a case statement to determine which action was selected
    # Depending on the action, we call the appropriate function
    # If the action is 'view', we call shell::fzf_view_workspace
    # If the action is 'edit', we call shell::fzf_edit_workspace
    # If the action is 'rename', we call shell::rename_workspace
    # If the action is 'remove', we call shell::remove_workspace
    # If the action is not recognized, we print an error message and return
    case "$action" in
    view)
        shell::fzf_view_workspace "$selected"
        ;;
    edit)
        shell::fzf_edit_workspace "$selected"
        ;;
    rename)
        shell::colored_echo "[e] Enter new name for workspace '$selected':" 208
        read -r new_name
        # Check if a new name was entered
        if [ -z "$new_name" ]; then
            shell::colored_echo "ERR: No new name entered. Aborting rename." 196
            return 1
        fi
        # If dry mode is enabled, we print the command to rename the workspace
        # This allows us to see what would be done without actually renaming anything
        if [ "$dry_run" = "true" ]; then
            shell::rename_workspace -n "$selected" "$new_name"
        else
            shell::rename_workspace "$selected" "$new_name"
        fi
        ;;
    remove)
        # If dry mode is enabled, we print the command to remove the workspace
        # This allows us to see what would be done without actually deleting anything
        if [ "$dry_run" = "true" ]; then
            shell::remove_workspace -n "$selected"
        else
            shell::remove_workspace "$selected"
        fi
        ;;
    clone)
        # If the action is 'clone', we call shell::clone_workspace
        # We prompt for the new workspace name to clone to
        shell::colored_echo "[e] Enter new name for cloned workspace from '$selected':" 208
        read -r new_name
        # Check if a new name was entered
        if [ -z "$new_name" ]; then
            shell::colored_echo "ERR: No new name entered. Aborting clone." 196
            return 1
        fi
        # If dry mode is enabled, we print the command to clone the workspace
        # This allows us to see what would be done without actually cloning anything
        if [ "$dry_run" = "true" ]; then
            shell::clone_workspace -n "$selected" "$new_name"
        else
            shell::clone_workspace "$selected" "$new_name"
        fi
        ;;
    *)
        shell::colored_echo "ERR: Unknown action '$action'" 196
        return 1
        ;;
    esac
}

# shell::clone_workspace function
# Clones an existing workspace to a new workspace directory.
#
# Usage:
# shell::clone_workspace [-n] <source_workspace> <destination_workspace>
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the clone command is printed using shell::on_evict instead of executed.
# - <source_workspace> : The name of the existing workspace to clone.
# - <destination_workspace> : The name of the new workspace to create.
#
# Description:
# This function clones a workspace directory under $SHELL_CONF_WORKING_WORKSPACE
# from <source_workspace> to <destination_workspace>. It checks for the existence of the source
# and ensures the destination does not already exist. If valid, it copies the entire directory.
#
# Example:
# shell::clone_workspace dxc dxc-clone
# shell::clone_workspace -n dxc dxc-clone
shell::clone_workspace() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_CLONE_WORKSPACE"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if source and destination workspace names are provided
    # If not, we print usage information and return an error
    # This ensures the user knows how to use the command correctly
    # We check if at least two arguments are provided
    # The first argument is the source workspace and the second is the destination workspace
    # If less than two arguments are provided, we print usage information
    # and return an error code
    if [ $# -lt 2 ]; then
        echo "Usage: shell::clone_workspace [-n] <source_workspace> <destination_workspace>"
        return 1
    fi

    local source="$1"
    local destination="$2"

    # Sanitize the source and destination workspace names
    # We use shell::sanitize_lower_var_name to ensure the names are in lowercase and safe for use as directory names
    # This function replaces non-alphanumeric characters with underscores
    source=$(shell::sanitize_lower_var_name "$source")
    destination=$(shell::sanitize_lower_var_name "$destination")

    local base="$SHELL_CONF_WORKING_WORKSPACE"
    local source_dir="$base/$source"
    local destination_dir="$base/$destination"

    # Check if the source workspace exists and the destination does not
    # We check if the source directory exists and if the destination directory does not
    # If the source directory does not exist, we print an error message and return
    # If the destination directory already exists, we print an error message and return
    if [ ! -d "$source_dir" ]; then
        shell::colored_echo "ERR: Source workspace '$source' does not exist at '$source_dir'" 196
        return 1
    fi

    # Check if the destination workspace already exists
    # If the destination directory already exists, we print an error message and return
    # This prevents overwriting an existing workspace
    if [ -d "$destination_dir" ]; then
        shell::colored_echo "ERR: Destination workspace '$destination' already exists at '$destination_dir'" 196
        return 1
    fi

    # Construct the command to clone the workspace directory
    # We use sudo cp -r to recursively copy the source directory to the destination directory
    # This effectively clones the workspace
    local cmd="sudo cp -r \"$source_dir\" \"$destination_dir\""

    # If dry-run mode is enabled, we print the command instead of executing it
    # This allows us to see what would be done without making any changes
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::run_cmd_eval "$cmd"
        shell::unlock_permissions "$destination_dir"
        shell::colored_echo "INFO: Workspace cloned from '$source' to '$destination'" 46
    fi
}

# shell::fzf_clone_workspace function
# Interactively selects a workspace using fzf and clones it to a new workspace.
#
# Usage:
# shell::fzf_clone_workspace [-n]
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the clone command is printed using shell::on_evict instead of executed.
#
# Description:
# This function lists all workspace directories under $SHELL_CONF_WORKING_WORKSPACE,
# uses fzf to let the user select one, prompts for a new name, and then calls shell::clone_workspace
# to clone the selected workspace.
#
# Example:
# shell::fzf_clone_workspace
shell::fzf_clone_workspace() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_CLONE_WORKSPACE"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if the workspace directory exists
    # We check if the base directory for workspaces exists
    # If it does not exist, we print an error message and return
    local base="$SHELL_CONF_WORKING_WORKSPACE"
    if [ ! -d "$base" ]; then
        shell::colored_echo "ERR: Workspace directory '$base' not found." 196
        return 1
    fi

    # Ensure fzf is installed
    shell::install_package fzf

    # List all workspace directories and use fzf to select one
    # We use find to locate directories under the workspace directory
    # We use xargs to convert the output of find into a list of directory names
    # We use fzf to let the user select one of the directories
    local selected
    selected=$(find "$base" -mindepth 1 -maxdepth 1 -type d |
        xargs -n 1 basename |
        fzf --prompt="Select workspace to clone: ")

    # Check if a workspace was selected
    # If no workspace was selected, we print an error message and return
    # This ensures the user knows they need to select a workspace
    # We check if the selected variable is empty
    # If it is empty, we print an error message and return
    if [ -z "$selected" ]; then
        shell::colored_echo "ERR: No workspace selected." 196
        return 1
    fi

    shell::colored_echo "[e] Enter new name for cloned workspace of '$selected':" 208
    read -r new_name

    # Check if a new name was entered
    # If no new name was entered, we print an error message and return
    # This ensures the user knows they need to provide a new name
    if [ -z "$new_name" ]; then
        shell::colored_echo "ERR: No new name entered. Aborting clone." 196
        return 1
    fi

    # If dry mode is enabled, we print the command to clone the workspace
    # This allows us to see what would be done without actually cloning anything
    if [ "$dry_run" = "true" ]; then
        shell::clone_workspace -n "$selected" "$new_name"
    else
        shell::clone_workspace "$selected" "$new_name"
    fi
}

# shell::dump_workspace_json function
# Interactively selects a workspace, section, and fields to export as JSON from .ssh/*.conf files.
#
# Usage:
# shell::dump_workspace_json [-h]
#
# Parameters:
# - -h : Show help message.
#
# Description:
# This function uses fzf to let the user select a workspace, then a section (e.g., [dev], [uat]),
# and then one or more fields to export. It reads values from .ssh/*.conf files and outputs a JSON
# structure to the terminal and copies it to the clipboard.
#
# Example:
# shell::dump_workspace_json
shell::dump_workspace_json() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_DUMP_WORKSPACE_JSON"
        return 0
    fi

    # Ensure fzf is installed
    shell::install_package fzf

    # Check if the workspace directory exists
    # We check if the base directory for workspaces exists
    # If it does not exist, we print an error message and return
    local base="$SHELL_CONF_WORKING_WORKSPACE"
    if [ ! -d "$base" ]; then
        shell::colored_echo "ERR: Workspace directory '$base' not found." 196
        return 1
    fi

    # List all workspace directories and use fzf to select one
    # We use find to locate directories under the workspace directory
    # We use xargs to convert the output of find into a list of directory names
    # We use fzf to let the user select one of the directories
    local workspace
    workspace=$(find "$base" -mindepth 1 -maxdepth 1 -type d |
        xargs -n 1 basename |
        fzf --prompt="Select workspace: ")

    # Check if a workspace was selected
    # If no workspace was selected, we print an error message and return
    # This ensures the user knows they need to select a workspace
    # We check if the workspace variable is empty
    # If it is empty, we print an error message and return
    if [ -z "$workspace" ]; then
        shell::colored_echo "ERR: No workspace selected." 196
        return 1
    fi

    # Check if the selected workspace has a .ssh directory
    # We check if the .ssh directory exists under the selected workspace
    # If the .ssh directory does not exist, we print an error message and return
    local ssh_dir="$base/$workspace/.ssh"
    if [ ! -d "$ssh_dir" ]; then
        shell::colored_echo "ERR: Workspace '$workspace' has no .ssh directory." 196
        return 1
    fi

    # Find all .conf files in the .ssh directory
    # We use find to locate all .conf files under the .ssh directory
    local conf_file
    conf_file=$(find "$ssh_dir" -type f -name "*.conf" |
        fzf --prompt="Select .conf file to export: ")

    # Check if a .conf file was selected
    # If no .conf file was selected, we print an error message and return
    # This ensures the user knows they need to select a .conf file
    # We check if the conf_file variable is empty
    # If it is empty, we print an error message and return
    if [ -z "$conf_file" ]; then
        shell::colored_echo "ERR: No .conf file selected." 196
        return 1
    fi

    # Check if the selected .conf file exists
    # We check if the conf_file exists
    # If the conf_file does not exist, we print an error message and return
    local sections
    sections=$(shell::ini_list_sections "$conf_file" |
        fzf --multi --prompt="Select sections to export: ")

    # Check if a section was selected
    # If no section was selected, we print an error message and return
    # This ensures the user knows they need to select a section
    # We check if the section variable is empty
    if [ -z "$sections" ]; then
        shell::colored_echo "ERR: No sections selected." 196
        return 1
    fi

    # All possible fields to export
    # We define an array of all possible fields that can be exported as JSON
    # These fields correspond to the keys in the .conf file
    # We use an array to store the field names
    # This allows us to easily iterate over the fields later
    # local all_fields=(
    #     SSH_DESC
    #     SSH_PRIVATE_KEY_REF
    #     SSH_SERVER_ADDR
    #     SSH_SERVER_PORT
    #     SSH_SERVER_USER
    #     SSH_LOCAL_ADDR
    #     SSH_LOCAL_PORT
    # )

    # Use fzf to select fields to export
    # We use printf to create a list of all fields, which is then piped into fzf
    # We use --multi to allow the user to select multiple fields
    # We use --prompt to customize the prompt message shown to the user
    # local selected_fields
    # selected_fields=$(printf "%s\n" "${all_fields[@]}" |
    #     fzf --multi --prompt="Select fields to export as JSON: ")

    # Check if any fields were selected
    # If no fields were selected, we print an error message and return
    # This ensures the user knows they need to select at least one field
    # We check if the selected_fields variable is empty
    # if [ -z "$selected_fields" ]; then
    #     shell::colored_echo "ERR: No fields selected. Aborting." 196
    #     return 1
    # fi

    # Get the name of the .conf file
    # We use basename to extract the file name from the full path
    # This allows us to use the file name as part of the JSON output
    # We store the file name in a variable for later use
    local config_name
    config_name=$(basename "$conf_file")

    # Construct the JSON output
    # We start with a JSON object that contains the workspace and section
    # We iterate over the selected fields and read their values from the .conf file
    # We use shell::read_ini to read the values for each field
    # We use shell::sanitize_lower_var_name to ensure the keys are valid JSON keys
    # We build the JSON string incrementally
    # local json="{ \"$workspace\": { \"$config_name\": {"
    # local first_section=1
    # while IFS= read -r section; do
    #     [ $first_section -eq 0 ] && json+=","
    #     json+=" \"$section\": {"
    #     local first_field=1
    #     while IFS= read -r key; do
    #         local value
    #         # value=$(shell::read_ini "$conf_file" "$section" "$key" 2>/dev/null)
    #         # value=$(shell::read_ini "$conf_file" "$section" "$key" 2>/dev/null | tail -n 1)
    #         value=$(shell::read_ini "$conf_file" "$section" "$key" 2>/dev/null | sed 's/^value=//')
    #         [ $first_field -eq 0 ] && json+=","
    #         key=$(shell::sanitize_lower_var_name "$key") # Ensure the key is a valid JSON key
    #         json+=" \"$key\": \"${value}\""
    #         first_field=0
    #     done <<<"$selected_fields"
    #     json+=" }"
    #     first_section=0
    # done <<<"$sections"
    # json+=" } } }"

    local json="{ \"$workspace\": { \"$config_name\": {"
    local first_section=1
    while IFS= read -r section; do
        [ $first_section -eq 0 ] && json+=","
        json+=" \"$section\": {"

        # Get keys in the section
        # We use shell::ini_list_keys to get the keys in the section
        # If no keys are found, we print a warning and skip to the next section
        # We use shell::ini_list_keys to get the keys in the section
        # If no keys are found, we print a warning and skip to the next section
        local keys
        keys=$(shell::ini_list_keys "$conf_file" "$section")
        if [ -z "$keys" ]; then
            shell::colored_echo "WARN: No keys found in section '$section'" 11
            continue
        fi

        # Use fzf to select keys to export
        # We use fzf to let the user select one or more keys from the section
        # We use --multi to allow multiple selections
        # We use --prompt to customize the prompt message shown to the user
        # We store the selected keys in a variable
        local selected_keys
        selected_keys=$(echo "$keys" | fzf --multi --prompt="Select keys in [$section] to export: ")
        if [ -z "$selected_keys" ]; then
            shell::colored_echo "WARN: No keys selected in section '$section'. Skipping." 11
            continue
        fi

        local first_field=1
        while IFS= read -r key; do
            local value
            value=$(shell::read_ini "$conf_file" "$section" "$key" 2>/dev/null | sed 's/^value=//')
            [ $first_field -eq 0 ] && json+=","
            key=$(shell::sanitize_lower_var_name "$key")
            json+=" \"$key\": \"${value}\""
            first_field=0
        done <<<"$selected_keys"

        json+=" }"
        first_section=0
    done <<<"$sections"
    json+=" } } }"

    shell::colored_echo "$json" 33
    shell::clip_value "$json"
}
