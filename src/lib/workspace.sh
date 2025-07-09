#!/bin/bash
# workspace.sh

# shell::ensure_workspace function
# Ensures that the workspace directory exists.
#
# Usage:
#   shell::ensure_workspace
#
# Description:
#   Checks if the workspace directory ($SHELL_CONF_WORKING/workspace) exists.
#   If it does not exist, creates it using mkdir -p.
#
# Example:
#   shell::ensure_workspace
shell::ensure_workspace() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ENSURE_WORKSPACE"
        return 0
    fi

    # Check if the workspace directory exists
    # We check if the directory defined by $SHELL_CONF_WORKING_WORKSPACE exists
    if [ ! -d "$SHELL_CONF_WORKING_WORKSPACE" ]; then
        shell::run_cmd_eval sudo mkdir -p "$SHELL_CONF_WORKING_WORKSPACE"
    fi
}

# shell::populate_ssh_conf function
# Populates a .conf file with default [base], [dev], and [uat] blocks using shell::write_ini.
#
# Usage:
# shell::populate_ssh_conf <file_path> <file_name>
#
# Parameters:
# - <file_path> : The full path to the .conf file to populate.
# - <file_name> : The name of the .conf file (e.g., server.conf, kafka.conf).
#
# Description:
# This function writes default SSH tunnel configuration blocks to the specified .conf file.
# It includes a [base] block with shared SSH settings, and [dev] and [uat] blocks with
# environment-specific overrides. Additional service-specific keys are added based on the
# file name (e.g., kafka.conf, nginx.conf).
#
# The function uses shell::write_ini to write each key-value pair into the appropriate section.
# Port numbers are assigned based on a predefined mapping, with +1 offset for UAT.
#
# Example:
# shell::populate_ssh_conf "$HOME/.shell-config/workspace/my-app/.ssh/server.conf" "server.conf"
shell::populate_ssh_conf() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_POPULATE_SSH_CONF"
        return 0
    fi

    local file="$1"
    local name="$2"

    # Check if file path and name are provided
    if [ -z "$file" ] || [ -z "$name" ]; then
        echo "Usage: shell::populate_ssh_conf <file_path> <file_name>"
        return 1
    fi

    # Check if the file path is valid
    # We check if the directory for the file exists
    # If the directory does not exist, we print an error message and return
    if [ ! -d "$(dirname "$file")" ]; then
        shell::colored_echo "ERR: Directory for '$file' does not exist." 196
        return 1
    fi

    # Check if the file already exists
    # If the file already exists, we print a debug message
    # This is useful for debugging purposes to know if we are overwriting an existing file
    if [ -f "$file" ]; then
        shell::colored_echo "DEBUG: File '$file' already exists. Overwriting..." 244
    fi

    # Define port mappings for different services
    # We use an associative array to map service names to their base port numbers
    # This allows us to easily retrieve the base port for each service
    # The base port is used for the dev environment, and the uat port is calculated as base + 1
    declare -A ports=(
        ["server.conf"]=22
        ["kafka.conf"]=9092
        ["zookeeper.conf"]=2181
        ["nginx.conf"]=80
        ["web.conf"]=3000
        ["app.conf"]=4000
        ["api.conf"]=5000
        ["cache.conf"]=6379
        ["search.conf"]=9200
    )

    # Determine the base port and uat port for the service
    # We use the service name to look up the base port in the ports associative array
    # If the service name is not found, we default to port 5432
    # The uat port is calculated as base port + 1
    # This allows us to have separate ports for dev and uat environments
    local base_port="${ports[$name]:-5432}"
    local uat_port=$((base_port + 1))

    # Base block: shared across all environments
    # We write the base SSH configuration that is common to all environments
    shell::write_ini "$file" "base" "SSH_PRIVATE_KEY_REF" "$HOME/.ssh/id_rsa"
    shell::write_ini "$file" "base" "SSH_LOCAL_ADDR" "127.0.0.1"
    shell::write_ini "$file" "base" "SSH_TIMEOUT_SEC" "10"
    shell::write_ini "$file" "base" "SSH_KEEP_ALIVE" "yes"
    shell::write_ini "$file" "base" "SSH_SERVER_ALIVE_INTERVAL_SEC" "60"
    shell::write_ini "$file" "base" "SSH_RETRY" "3"
    shell::write_ini "$file" "base" "SSH_RETRY_DELAY_SEC" "10"

    # Environment-specific blocks: dev and uat
    # We write the dev and uat blocks with environment-specific settings
    for env in dev uat; do
        local port=$([ "$env" = "dev" ] && echo "$base_port" || echo "$uat_port")
        shell::write_ini "$file" "$env" "SSH_DESC" "$(echo "$env" | tr '[:lower:]' '[:upper:]') Tunnel for $name"
        shell::write_ini "$file" "$env" "SSH_SERVER_ADDR" "127.0.0.1"
        shell::write_ini "$file" "$env" "SSH_SERVER_PORT" "$port"
        shell::write_ini "$file" "$env" "SSH_SERVER_USER" "sysadmin"
        shell::write_ini "$file" "$env" "SSH_LOCAL_PORT" "$port"
        shell::write_ini "$file" "$env" "SSH_PRIVATE_KEY_REF" "$HOME/.ssh/id_rsa"
        shell::write_ini "$file" "$env" "SSH_SERVER_TARGET_SERVICE_ADDR" "127.0.0.1"
        shell::write_ini "$file" "$env" "SSH_SERVER_TARGET_SERVICE_PORT" "$port"

        case "$name" in
        "server.conf")
            shell::write_ini "$file" "$env" "SERVER_ROLE" "gateway"
            shell::write_ini "$file" "$env" "SERVER_ENV" "$env"
            shell::write_ini "$file" "$env" "SERVER_HEALTHCHECK" "http://localhost:8080/health"
            shell::write_ini "$file" "$env" "SERVER_LOG_LEVEL" "info"
            ;;
        "kafka.conf")
            shell::write_ini "$file" "$env" "KAFKA_CLUSTER_ID" "${env}-cluster"
            shell::write_ini "$file" "$env" "KAFKA_TOPIC" "${env}-events"
            shell::write_ini "$file" "$env" "KAFKA_REPLICATION_FACTOR" "1"
            shell::write_ini "$file" "$env" "KAFKA_PARTITIONS" "3"
            shell::write_ini "$file" "$env" "KAFKA_LOG_DIR" "/var/log/kafka"
            ;;
        "zookeeper.conf")
            shell::write_ini "$file" "$env" "ZK_DATA_DIR" "/var/lib/zookeeper"
            shell::write_ini "$file" "$env" "ZK_CLIENT_PORT" "$base_port"
            shell::write_ini "$file" "$env" "ZK_TICK_TIME" "2000"
            shell::write_ini "$file" "$env" "ZK_INIT_LIMIT" "5"
            shell::write_ini "$file" "$env" "ZK_SYNC_LIMIT" "2"
            ;;
        "nginx.conf")
            shell::write_ini "$file" "$env" "NGINX_CONF_PATH" "/etc/nginx/nginx.conf"
            shell::write_ini "$file" "$env" "NGINX_DOC_ROOT" "/var/www/html"
            shell::write_ini "$file" "$env" "NGINX_WORKER_PROCESSES" "auto"
            shell::write_ini "$file" "$env" "NGINX_ERROR_LOG" "/var/log/nginx/error.log"
            shell::write_ini "$file" "$env" "NGINX_ACCESS_LOG" "/var/log/nginx/access.log"
            ;;
        "web.conf")
            shell::write_ini "$file" "$env" "WEB_FRAMEWORK" "bash-sh"
            shell::write_ini "$file" "$env" "WEB_ENV" "$env"
            shell::write_ini "$file" "$env" "WEB_PORT" "$base_port"
            shell::write_ini "$file" "$env" "WEB_STATIC_DIR" "public"
            shell::write_ini "$file" "$env" "WEB_API_PROXY" "http://localhost:5000"
            ;;
        "app.conf")
            shell::write_ini "$file" "$env" "APP_NAME" "shell"
            shell::write_ini "$file" "$env" "APP_ENV" "$env"
            shell::write_ini "$file" "$env" "APP_LOG_LEVEL" "debug"
            shell::write_ini "$file" "$env" "APP_CONFIG_PATH" "./config/app.yaml"
            shell::write_ini "$file" "$env" "APP_SESSION_TIMEOUT" "3600"
            ;;
        "api.conf")
            shell::write_ini "$file" "$env" "API_VERSION" "v1"
            shell::write_ini "$file" "$env" "API_BASE_URL" "http://localhost:$port"
            shell::write_ini "$file" "$env" "API_TIMEOUT" "5000"
            shell::write_ini "$file" "$env" "API_KEY_HEADER" "X-API-KEY"
            shell::write_ini "$file" "$env" "API_DOCS_URL" "http://localhost:$port/docs"
            ;;
        "cache.conf")
            shell::write_ini "$file" "$env" "CACHE_ENGINE" "redis"
            shell::write_ini "$file" "$env" "CACHE_TTL" "3600"
            shell::write_ini "$file" "$env" "CACHE_MAX_MEMORY" "256mb"
            shell::write_ini "$file" "$env" "CACHE_POLICY" "allkeys-lru"
            shell::write_ini "$file" "$env" "CACHE_CLUSTER_MODE" "no"
            ;;
        "search.conf")
            shell::write_ini "$file" "$env" "SEARCH_ENGINE" "elasticsearch"
            shell::write_ini "$file" "$env" "SEARCH_INDEX" "${env}-index"
            shell::write_ini "$file" "$env" "SEARCH_REPLICAS" "1"
            shell::write_ini "$file" "$env" "SEARCH_SHARDS" "1"
            shell::write_ini "$file" "$env" "SEARCH_LOG_PATH" "/var/log/elasticsearch"
            ;;
        esac
    done
}

# shell::add_workspace function
# Creates a new workspace with profile.conf and default .ssh/*.conf templates populated via shell::write_ini.
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
# It uses shell::write_ini to populate each .conf file with [dev] and [uat] blocks.
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

    # Check if workspace already exists
    # If the directory already exists, we return an error
    if [ -d "$dir" ]; then
        shell::colored_echo "ERR: Workspace '$name' already exists at '$dir'" 196
        return 1
    fi

    # Ensure the fzf package is installed
    shell::install_package fzf

    # Prompt the user to select .conf files to include in the workspace
    # We define an array of all possible .conf files
    # We use fzf to allow the user to select multiple files interactively
    # The selected files will be used to create the .ssh/*.conf files in the workspace
    local all_files=("server.conf" "db.conf" "redis.conf" "rmq.conf" "ast.conf" "kafka.conf" "zookeeper.conf" "nginx.conf" "web.conf" "app.conf" "api.conf" "cache.conf" "search.conf")
    local selected_files
    selected_files=$(printf "%s\n" "${all_files[@]}" | fzf --multi --prompt="Select .conf files to include: ")

    # Check if any files were selected
    # If no files were selected, we print an error message and return
    if [ -z "$selected_files" ]; then
        shell::colored_echo "ERR: No configuration files selected." 196
        return 1
    fi

    # Create the workspace directory structure
    # We create the main workspace directory, the profile.conf file, and the .ssh directory with its files
    # We use mkdir -p to ensure parent directories are created as needed
    # We use touch to create the profile.conf and .ssh/*.conf files
    # The command is constructed as a single string to be executed later
    # This allows us to handle dry-run mode by simply printing the command instead of executing it
    local cmd="mkdir -p \"$ssh_dir\" && touch \"$profile\""
    while IFS= read -r f; do
        cmd="$cmd && touch \"$ssh_dir/$f\""
    done <<<"$selected_files"

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
        # We use shell::write_ini to write default values to the profile.conf file
        # This includes the workspace name, description, and other relevant fields
        # We use the shell::write_ini function to write these values
        while IFS= read -r f; do
            local file="$ssh_dir/$f"
            shell::colored_echo "DEBUG: Populating '$f' with default [dev] and [uat] blocks..." 244
            shell::populate_ssh_conf "$file" "$f"
        done <<<"$selected_files"
    fi
}

# shell::add_workspace_ssh_conf function
# Adds a missing SSH configuration file to a specified workspace.
#
# Usage:
# shell::add_workspace_ssh_conf [-n] <workspace_name> <ssh_conf_name>
#
# Parameters:
# - -n : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
# - <workspace_name> : The name of the workspace.
# - <ssh_conf_name> : The name of the SSH configuration file to add (e.g., kafka.conf).
#
# Description:
# This function checks if the specified SSH configuration file exists in the workspace's .ssh directory.
# If it does not exist, it creates the file and populates it using shell::populate_ssh_conf.
#
# Example:
# shell::add_workspace_ssh_conf my-app kafka.conf
# shell::add_workspace_ssh_conf -n my-app kafka.conf
shell::add_workspace_ssh_conf() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ADD_WORKSPACE_SSH_CONF"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if workspace name and SSH configuration name are provided
    # If not, we print usage information and return an error
    if [ $# -lt 2 ]; then
        echo "Usage: shell::add_workspace_ssh_conf [-n] <workspace_name> <ssh_conf_name>"
        return 1
    fi

    # Get the workspace name and SSH configuration name from the arguments
    local name="$1"
    if [ -z "$name" ]; then
        shell::colored_echo "ERR: Workspace name is required." 196
        return 1
    fi

    # Get the SSH configuration name from the arguments
    local conf="$2"
    if [ -z "$conf" ]; then
        shell::colored_echo "ERR: SSH configuration name is required." 196
        return 1
    fi

    # Sanitize the workspace name
    # We use shell::sanitize_lower_var_name to ensure the name is in lowercase and safe for use as a directory name
    # This function replaces non-alphanumeric characters with underscores
    # This helps prevent issues with invalid directory names
    # We use shell::sanitize_lower_var_name to ensure the name is in lowercase and safe for use as a directory name
    # This function replaces non-alphanumeric characters with underscores
    # This helps prevent issues with invalid directory names
    name=$(shell::sanitize_lower_var_name "$name")

    # Construct the directory and file paths
    # We define the base directory for the workspace and the .ssh directory
    # The file path is constructed by combining the workspace directory, .ssh directory, and the SSH configuration name
    local dir="$SHELL_CONF_WORKING_WORKSPACE/$name/.ssh"
    local file="$dir/$conf"

    # Check if the workspace directory exists
    # We check if the directory for the workspace exists
    # If the directory does not exist, we print an error message and return
    if [ ! -d "$dir" ]; then
        shell::colored_echo "ERR: Workspace '$name' does not exist or has no .ssh directory." 196
        return 1
    fi

    # Check if the SSH configuration file already exists
    # We check if the specified file already exists in the .ssh directory
    # If the file exists, we print a message and return
    # This prevents overwriting an existing configuration file
    if [ -f "$file" ]; then
        shell::colored_echo "WARN: '$conf' already exists in workspace '$name'." 11
        return 0
    fi

    # Check if the dry run mode is enabled
    # If dry_run is true, we print the command to create the file and populate it
    # This allows us to see what would be done without actually creating the file
    # If dry_run is false, we create the file and populate it with default values
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "touch \"$file\" && shell::populate_ssh_conf \"$file\" \"$conf\""
    else
        shell::create_file_if_not_exists "$file"
        shell::populate_ssh_conf "$file" "$conf"
        shell::colored_echo "INFO: '$conf' added to workspace '$name'." 46
    fi
}

# shell::fzf_add_workspace_ssh_conf function
# Interactively selects a workspace and SSH config to add using fzf.
#
# Usage:
# shell::fzf_add_workspace_ssh_conf [-n]
#
# Parameters:
# - -n : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#
# Description:
# This function uses fzf to select a workspace and a missing SSH configuration file.
# It then calls shell::add_workspace_ssh_conf to add the selected file if it does not exist.
#
# Example:
# shell::fzf_add_workspace_ssh_conf
# shell::fzf_add_workspace_ssh_conf -n
shell::fzf_add_workspace_ssh_conf() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_ADD_WORKSPACE_SSH_CONF"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Ensure fzf is installed
    shell::install_package fzf

    # Check if the workspace directory exists
    # We check if the directory defined by $SHELL_CONF_WORKING_WORKSPACE exists
    local base="$SHELL_CONF_WORKING_WORKSPACE"
    if [ ! -d "$base" ]; then
        shell::colored_echo "ERR: Workspace directory '$base' not found." 196
        return 1
    fi

    # List all workspace directories and use fzf to select one
    # We use find to locate directories under the workspace directory
    # We use xargs to get the basename of each directory
    # We use fzf to allow the user to select a workspace interactively
    local workspace
    workspace=$(find "$base" -mindepth 1 -maxdepth 1 -type d | xargs -n 1 basename | fzf --prompt="Select workspace: ")

    # If no workspace was selected, we print an error message and return
    # This ensures the user knows they need to select a workspace
    if [ -z "$workspace" ]; then
        shell::colored_echo "ERR: No workspace selected." 196
        return 1
    fi

    # Check if the selected workspace has a .ssh directory
    # We construct the path to the .ssh directory for the selected workspace
    local ssh_dir="$base/$workspace/.ssh"
    if [ ! -d "$ssh_dir" ]; then
        shell::colored_echo "ERR: Workspace '$workspace' has no .ssh directory." 196
        return 1
    fi

    # List all possible SSH config files and check which ones are missing
    # We define an array of all possible SSH config files
    local all_files=("server.conf" "db.conf" "redis.conf" "rmq.conf" "ast.conf" "kafka.conf" "zookeeper.conf" "nginx.conf" "web.conf" "app.conf" "api.conf" "cache.conf" "search.conf" "mysql.conf")
    local missing_files=()
    for f in "${all_files[@]}"; do
        [ ! -f "$ssh_dir/$f" ] && missing_files+=("$f")
    done

    # If no files are missing, we print a message and return
    # This means all SSH config files already exist in the workspace
    if [ ${#missing_files[@]} -eq 0 ]; then
        shell::colored_echo "INFO: All SSH config files already exist in workspace '$workspace'." 46
        return 0
    fi

    # Use fzf to select one of the missing SSH config files
    # We use printf to list the missing files and pipe it to fzf
    # The user can select one of the missing files to add to the workspace
    local selected_conf
    selected_conf=$(printf "%s\n" "${missing_files[@]}" | fzf --prompt="Select SSH config to add: ")

    # If no SSH config was selected, we print an error message and return
    # This ensures the user knows they need to select a file
    # If the user did not select a file, we print an error message and return
    if [ -z "$selected_conf" ]; then
        shell::colored_echo "ERR: No SSH config selected." 196
        return 1
    fi

    # Check if the dry run mode is enabled
    # If dry_run is true, we print the command to add the SSH config file
    # This allows us to see what would be done without actually adding the file
    if [ "$dry_run" = "true" ]; then
        shell::add_workspace_ssh_conf -n "$workspace" "$selected_conf"
    else
        shell::add_workspace_ssh_conf "$workspace" "$selected_conf"
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
    sections=$(shell::list_ini_sections "$conf_file" |
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
        # We use shell::list_ini_keys to get the keys in the section
        # If no keys are found, we print a warning and skip to the next section
        # We use shell::list_ini_keys to get the keys in the section
        # If no keys are found, we print a warning and skip to the next section
        local keys
        keys=$(shell::list_ini_keys "$conf_file" "$section")
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

# shell::open_workspace_ssh_tunnel function
# Opens an SSH tunnel using configuration from a workspace .ssh/*.conf file.
#
# Usage:
# shell::open_workspace_ssh_tunnel [-n] <workspace_name> <conf_name> <section>
#
# Parameters:
# - -n               : Optional dry-run flag. If provided, the command is printed using shell::on_evict.
# - <workspace_name> : The name of the workspace.
# - <conf_name>      : The name of the SSH configuration file (e.g., kafka.conf).
# - <section>        : The section to use (e.g., dev, uat).
#
# Description:
# This function reads the [base] section first, then overrides with values from the specified section.
# It delegates the actual SSH tunnel execution to shell::open_ssh_tunnel.
#
# Example:
# shell::open_workspace_ssh_tunnel my-app kafka.conf dev
# shell::open_workspace_ssh_tunnel -n my-app kafka.conf uat
shell::open_workspace_ssh_tunnel() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_OPEN_WORKSPACE_SSH_TUNNEL"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -ne 3 ]; then
        echo "Usage: shell::open_workspace_ssh_tunnel [-n] <workspace_name> <conf_name> <section>"
        return 1
    fi

    local workspace="$1"
    if [ -z "$workspace" ]; then
        shell::colored_echo "ERR: Workspace name is required." 196
        return 1
    fi
    local conf_name="$2"
    if [ -z "$conf_name" ]; then
        shell::colored_echo "ERR: Configuration name is required." 196
        return 1
    fi
    local section="$3"
    if [ -z "$section" ]; then
        shell::colored_echo "ERR: Section name is required." 196
        return 1
    fi

    # Sanitize the workspace name and section name
    # We use shell::sanitize_lower_var_name to ensure the names are in lowercase and safe for use as directory names
    workspace=$(shell::sanitize_lower_var_name "$workspace")
    section=$(shell::sanitize_lower_var_name "$section")

    local conf_path="$SHELL_CONF_WORKING_WORKSPACE/$workspace/.ssh/$conf_name"

    # We check if the base directory for workspaces exists
    # If it does not exist, we print an error message and return
    if [ ! -f "$conf_path" ]; then
        shell::colored_echo "ERR: Configuration file '$conf_path' not found." 196
        return 1
    fi

    # Check if the section exists in the configuration file
    # We use shell::exist_ini_section to check if the specified section exists in the configuration file
    # If the section does not exist, we print an error message and return
    if ! shell::exist_ini_section "$conf_path" "$section" >/dev/null 2>&1; then
        shell::colored_echo "ERR: Section ('$section') not found in file: $file" 196
        return 1
    fi

    # Load base values
    # We read the base section of the configuration file
    # This function reads the base section first, then overrides with values from the specified section
    local base_section="base"
    local timeout=$(shell::read_ini "$conf_path" "$base_section" SSH_TIMEOUT_SEC)
    local alive_interval=$(shell::read_ini "$conf_path" "$base_section" SSH_SERVER_ALIVE_INTERVAL_SEC)

    # Load section overrides
    local local_port=$(shell::read_ini "$conf_path" "$section" SSH_LOCAL_PORT)
    local target_addr=$(shell::read_ini "$conf_path" "$section" SSH_SERVER_TARGET_SERVICE_ADDR)
    local target_port=$(shell::read_ini "$conf_path" "$section" SSH_SERVER_TARGET_SERVICE_PORT)
    local server_desc=$(shell::read_ini "$conf_path" "$section" SSH_DESC)
    local server_file=$(shell::read_ini "$conf_path" "$section" SSH_PRIVATE_KEY_REF)
    local server_user=$(shell::read_ini "$conf_path" "$section" SSH_SERVER_USER)
    local server_addr=$(shell::read_ini "$conf_path" "$section" SSH_SERVER_ADDR)
    local server_port=$(shell::read_ini "$conf_path" "$section" SSH_SERVER_PORT)

    # Check if the dry-mode is enabled
    # If dry-run mode is enabled, we print the command instead of executing it
    # This allows us to see what would be done without actually opening the SSH tunnel
    if [ "$dry_run" = "true" ]; then
        shell::colored_echo "DEBUG: Opening SSH tunnel for '$server_desc' at $server_addr:$server_port" 244
        shell::open_ssh_tunnel -n "$server_file" "$local_port" "$target_addr" "$target_port" "$server_user" "$server_addr" "$server_port" "$alive_interval" "$timeout"
    else
        shell::colored_echo "INFO: Opening SSH tunnel for '$server_desc' at $server_addr:$server_port" 46
        shell::open_ssh_tunnel "$server_file" "$local_port" "$target_addr" "$target_port" "$server_user" "$server_addr" "$server_port" "$alive_interval" "$timeout"
    fi
}

# shell::fzf_open_workspace_ssh_tunnel function
# Interactively selects a workspace and SSH config section to open an SSH tunnel.
#
# Usage:
# shell::fzf_open_workspace_ssh_tunnel [-n]
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict.
#
# Description:
# Uses fzf to select a workspace and a .conf file, then selects a section (dev or uat),
# and opens an SSH tunnel using shell::open_workspace_ssh_tunnel.
#
# Example:
# shell::fzf_open_workspace_ssh_tunnel
# shell::fzf_open_workspace_ssh_tunnel -n
shell::fzf_open_workspace_ssh_tunnel() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_OPEN_WORKSPACE_SSH_TUNNEL"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Ensure the fzf package is installed
    shell::install_package fzf

    # Check if the workspace directory exists
    local workspace
    workspace=$(find "$SHELL_CONF_WORKING_WORKSPACE" -mindepth 1 -maxdepth 1 -type d |
        xargs -n 1 basename |
        fzf --prompt="Select workspace: ")

    # Check if a workspace was selected
    # If no workspace was selected, we print an error message and return
    # This ensures the user knows they need to select a workspace
    if [ -z "$workspace" ]; then
        shell::colored_echo "ERR: No workspace selected." 196
        return 1
    fi

    # Check if the selected workspace has a .ssh directory
    # We check if the .ssh directory exists under the selected workspace
    # If the .ssh directory does not exist, we print an error message and return
    local ssh_dir="$SHELL_CONF_WORKING_WORKSPACE/$workspace/.ssh"
    if [ ! -d "$ssh_dir" ]; then
        shell::colored_echo "ERR: Workspace '$workspace' has no .ssh directory." 196
        return 1
    fi

    # Find all .conf files in the .ssh directory
    # We use find to locate all .conf files under the .ssh directory
    # We use xargs to convert the output of find into a list of file names
    local conf_file
    conf_file=$(find "$ssh_dir" -type f -name "*.conf" |
        xargs -n 1 basename |
        fzf --prompt="Select SSH config file: ")

    if [ -z "$conf_file" ]; then
        shell::colored_echo "ERR: No config file selected." 196
        return 1
    fi

    # Check if the selected .conf file exists
    local section
    section=$(printf "dev\nuat" | fzf --prompt="Select section: ")
    if [ -z "$section" ]; then
        shell::colored_echo "ERR: No section selected." 196
        return 1
    fi

    # Check if the dry-mode is enabled
    # If dry-run mode is enabled, we print the command instead of executing it
    # This allows us to see what would be done without actually opening the SSH tunnel
    if [ "$dry_run" = "true" ]; then
        shell::open_workspace_ssh_tunnel -n "$workspace" "$conf_file" "$section"
    else
        shell::open_workspace_ssh_tunnel "$workspace" "$conf_file" "$section"
    fi
}

# shell::tune_workspace_ssh_tunnel function
# Opens an SSH tunnel using configuration from a workspace .ssh/*.conf file, with tuning options.
#
# Usage:
# shell::tune_workspace_ssh_tunnel [-n] <workspace_name> <conf_name> <section>
#
# Parameters:
# - -n               : Optional dry-run flag. If provided, the command is printed using shell::on_evict.
# - <workspace_name> : The name of the workspace.
# - <conf_name>      : The name of the SSH configuration file (e.g., kafka.conf).
# - <section>        : The section to use (e.g., dev, uat).
#
# Description:
# This function reads the [base] section first, then overrides with values from the specified section.
# It delegates the actual SSH tunnel execution to shell::tune_ssh_tunnel.
#
# Example:
# shell::tune_workspace_ssh_tunnel my-app kafka.conf dev
# shell::tune_workspace_ssh_tunnel -n my-app kafka.conf uat
shell::tune_workspace_ssh_tunnel() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_TUNE_WORKSPACE_SSH_TUNNEL"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -ne 3 ]; then
        echo "Usage: shell::tune_workspace_ssh_tunnel [-n] <workspace_name> <conf_name> <section>"
        return 1
    fi

    local workspace="$1"
    if [ -z "$workspace" ]; then
        shell::colored_echo "ERR: Workspace name is required." 196
        return 1
    fi
    local conf_name="$2"
    if [ -z "$conf_name" ]; then
        shell::colored_echo "ERR: Configuration name is required." 196
        return 1
    fi
    local section="$3"
    if [ -z "$section" ]; then
        shell::colored_echo "ERR: Section name is required." 196
        return 1
    fi

    # Sanitize the workspace name and section name
    # We use shell::sanitize_lower_var_name to ensure the names are in lowercase and safe for use as directory names
    workspace=$(shell::sanitize_lower_var_name "$workspace")
    section=$(shell::sanitize_lower_var_name "$section")

    local conf_path="$SHELL_CONF_WORKING_WORKSPACE/$workspace/.ssh/$conf_name"

    # We check if the base directory for workspaces exists
    # If it does not exist, we print an error message and return
    if [ ! -f "$conf_path" ]; then
        shell::colored_echo "ERR: Configuration file '$conf_path' not found." 196
        return 1
    fi

    # Check if the section exists in the configuration file
    # We use shell::exist_ini_section to check if the specified section exists in the configuration file
    # If the section does not exist, we print an error message and return
    if ! shell::exist_ini_section "$conf_path" "$section" >/dev/null 2>&1; then
        shell::colored_echo "ERR: Section ('$section') not found in file: $file" 196
        return 1
    fi

    # Load section overrides
    local server_desc=$(shell::read_ini "$conf_path" "$section" SSH_DESC)
    local server_file=$(shell::read_ini "$conf_path" "$section" SSH_PRIVATE_KEY_REF)
    local server_user=$(shell::read_ini "$conf_path" "$section" SSH_SERVER_USER)
    local server_addr=$(shell::read_ini "$conf_path" "$section" SSH_SERVER_ADDR)
    local server_port=$(shell::read_ini "$conf_path" "$section" SSH_SERVER_PORT)

    # Check if the dry-mode is enabled
    # If dry-run mode is enabled, we print the command instead of executing it
    # This allows us to see what would be done without actually opening the SSH tunnel
    if [ "$dry_run" = "true" ]; then
        shell::colored_echo "DEBUG: Tunning SSH tunnel for '$server_desc' at $server_addr:$server_port" 244
        shell::tune_ssh_tunnel -n "$server_file" "$server_user" "$server_addr" "$server_port"
    else
        shell::colored_echo "INFO: Tunning SSH tunnel for '$server_desc' at $server_addr:$server_port" 46
        shell::tune_ssh_tunnel "$server_file" "$server_user" "$server_addr" "$server_port"
    fi
}

# shell::fzf_tune_workspace_ssh_tunnel function
# Interactively selects a workspace and SSH config section to tune an SSH tunnel.
#
# Usage:
# shell::fzf_tune_workspace_ssh_tunnel [-n]
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict.
#
# Description:
# Uses fzf to select a workspace and a .conf file, then selects a section (dev or uat),
# and tunes an SSH tunnel using shell::tune_workspace_ssh_tunnel.
shell::fzf_tune_workspace_ssh_tunnel() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_TUNE_WORKSPACE_SSH_TUNNEL"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Ensure the fzf package is installed
    shell::install_package fzf

    # Check if the workspace directory exists
    local workspace
    workspace=$(find "$SHELL_CONF_WORKING_WORKSPACE" -mindepth 1 -maxdepth 1 -type d |
        xargs -n 1 basename |
        fzf --prompt="Select workspace: ")

    # Check if a workspace was selected
    # If no workspace was selected, we print an error message and return
    # This ensures the user knows they need to select a workspace
    if [ -z "$workspace" ]; then
        shell::colored_echo "ERR: No workspace selected." 196
        return 1
    fi

    # Check if the selected workspace has a .ssh directory
    # We check if the .ssh directory exists under the selected workspace
    # If the .ssh directory does not exist, we print an error message and return
    local ssh_dir="$SHELL_CONF_WORKING_WORKSPACE/$workspace/.ssh"
    if [ ! -d "$ssh_dir" ]; then
        shell::colored_echo "ERR: Workspace '$workspace' has no .ssh directory." 196
        return 1
    fi

    # Find all .conf files in the .ssh directory
    # We use find to locate all .conf files under the .ssh directory
    # We use xargs to convert the output of find into a list of file names
    local conf_file
    conf_file=$(find "$ssh_dir" -type f -name "*.conf" |
        xargs -n 1 basename |
        fzf --prompt="Select SSH config file: ")

    if [ -z "$conf_file" ]; then
        shell::colored_echo "ERR: No config file selected." 196
        return 1
    fi

    # Check if the selected .conf file exists
    local section
    section=$(printf "dev\nuat" | fzf --prompt="Select section: ")
    if [ -z "$section" ]; then
        shell::colored_echo "ERR: No section selected." 196
        return 1
    fi

    # Check if the dry-mode is enabled
    # If dry-run mode is enabled, we print the command instead of executing it
    # This allows us to see what would be done without actually opening the SSH tunnel
    if [ "$dry_run" = "true" ]; then
        shell::tune_workspace_ssh_tunnel -n "$workspace" "$conf_file" "$section"
    else
        shell::tune_workspace_ssh_tunnel "$workspace" "$conf_file" "$section"
    fi
}
