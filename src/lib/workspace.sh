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
    action=$(printf "view\nedit\nrename\nremove" |
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
    *)
        shell::colored_echo "ERR: Unknown action '$action'" 196
        return 1
        ;;
    esac
}
