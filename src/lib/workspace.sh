#!/usr/bin/env bash
# @file lib/workspace.sh
# @brief Workspace definitions (INI based) with SSH tunnel integration.

# @description Ensures that the workspace directory exists.
#
#   Checks if the workspace directory ($SHELL_CONFIG_DIR/workspace) exists.
#   If it does not exist, creates it using mkdir -p.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @example
#   shell::workspace::ensure
#
shell::workspace::ensure() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Ensures that the workspace directory exists"
		shell::logger::usage "shell::workspace::ensure [-h]"
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	# Check if the workspace directory exists
	# We check if the directory defined by $SHELL_WORKSPACE_DIR exists
	if [ ! -d "$SHELL_WORKSPACE_DIR" ]; then
		shell::fs::mkdir --private "$SHELL_WORKSPACE_DIR"
	fi
}

# @description Populates a .conf file with default [base], [dev], and [uat] blocks using shell::ini::write.
#
#   This function writes default SSH tunnel configuration blocks to the specified .conf file.
#   It includes a [base] block with shared SSH settings, and [dev] and [uat] blocks with
#   environment-specific overrides. Additional service-specific keys are added based on the
#   file name (e.g., kafka.conf, nginx.conf).
#
#   The function uses shell::ini::write to write each key-value pair into the appropriate section.
#   Port numbers are assigned based on a predefined mapping, with +1 offset for UAT.
# @arg $1 string file_path: The full path to the .conf file to populate.
# @arg $2 string file_name: The name of the .conf file (e.g., server.conf, kafka.conf).
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::workspace::ssh::populate "$HOME/.shell-config/workspace/my-app/.ssh/server.conf" "server.conf"
#
shell::workspace::ssh::populate() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Populates a .conf file with default [base], [dev], and [uat] blocks using shell::ini::write"
		shell::logger::usage "shell::workspace::ssh::populate [-h] <file_path> <file_name>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "file_path" "The full path to the .conf file to populate."
		shell::logger::item "file_name" "The name of the .conf file (e.g., server.conf, kafka.conf)."
		shell::logger::example "shell::workspace::ssh::populate \"\$HOME/.shell-config/workspace/my-app/.ssh/server.conf\" \"server.conf"
		return $RETURN_SUCCESS
	fi

	local file="$1"
	local name="$2"

	# Check if file path and name are provided
	if [ -z "$file" ] || [ -z "$name" ]; then
		echo "Usage: shell::workspace::ssh::populate <file_path> <file_name>"
		return 1
	fi

	# Check if the file path is valid
	# We check if the directory for the file exists
	# If the directory does not exist, we print an error message and return
	if [ ! -d "$(dirname "$file")" ]; then
		shell::logger::error "Directory for '$file' does not exist."
		return 1
	fi

	# Check if the file already exists
	# If the file already exists, we print a debug message
	# This is useful for debugging purposes to know if we are overwriting an existing file
	if [ -f "$file" ]; then
		shell::logger::debug "File '$file' already exists. Overwriting..."
	fi

	# Define port mappings for different services
	# We use an associative array to map service names to their base port numbers
	# This allows us to easily retrieve the base port for each service
	# The base port is used for the dev environment, and the uat port is calculated as base + 1

	# Determine the base port and uat port for the service
	# We use the service name to look up the base port in the ports associative array
	# If the service name is not found, we default to port 5432
	# The uat port is calculated as base port + 1
	# This allows us to have separate ports for dev and uat environments
	# Default base port per service (a case statement works in bash 3.2 and zsh,
	# unlike `declare -A`, which needs bash >= 4).
	local base_port
	case "$name" in
	server.conf) base_port=22 ;;
	kafka.conf) base_port=9092 ;;
	zookeeper.conf) base_port=2181 ;;
	nginx.conf) base_port=80 ;;
	web.conf) base_port=3000 ;;
	app.conf) base_port=4000 ;;
	api.conf) base_port=5000 ;;
	cache.conf) base_port=6379 ;;
	search.conf) base_port=9200 ;;
	*) base_port=5432 ;;
	esac
	local uat_port=$((base_port + 1))

	# Base block: shared across all environments
	# We write the base SSH configuration that is common to all environments
	shell::ini::write "$file" "base" "SSH_PRIVATE_KEY_REF" "$HOME/.ssh/id_rsa"
	shell::ini::write "$file" "base" "SSH_LOCAL_ADDR" "127.0.0.1"
	shell::ini::write "$file" "base" "SSH_TIMEOUT_SEC" "10"
	shell::ini::write "$file" "base" "SSH_KEEP_ALIVE" "yes"
	shell::ini::write "$file" "base" "SSH_SERVER_ALIVE_INTERVAL_SEC" "60"
	shell::ini::write "$file" "base" "SSH_RETRY" "3"
	shell::ini::write "$file" "base" "SSH_RETRY_DELAY_SEC" "10"

	# Environment-specific blocks: dev and uat
	# We write the dev and uat blocks with environment-specific settings
	for env in dev uat; do
		local port=$([ "$env" = "dev" ] && echo "$base_port" || echo "$uat_port")
		shell::ini::write "$file" "$env" "SSH_DESC" "$(echo "$env" | tr '[:lower:]' '[:upper:]') Tunnel for $name"
		shell::ini::write "$file" "$env" "SSH_SERVER_ADDR" "127.0.0.1"
		shell::ini::write "$file" "$env" "SSH_SERVER_PORT" "$port"
		shell::ini::write "$file" "$env" "SSH_SERVER_USER" "sysadmin"
		shell::ini::write "$file" "$env" "SSH_LOCAL_PORT" "$port"
		shell::ini::write "$file" "$env" "SSH_PRIVATE_KEY_REF" "$HOME/.ssh/id_rsa"
		shell::ini::write "$file" "$env" "SSH_SERVER_TARGET_SERVICE_ADDR" "127.0.0.1"
		shell::ini::write "$file" "$env" "SSH_SERVER_TARGET_SERVICE_PORT" "$port"

		case "$name" in
		"server.conf")
			shell::ini::write "$file" "$env" "SERVER_ROLE" "gateway"
			shell::ini::write "$file" "$env" "SERVER_ENV" "$env"
			shell::ini::write "$file" "$env" "SERVER_HEALTHCHECK" "http://localhost:8080/health"
			shell::ini::write "$file" "$env" "SERVER_LOG_LEVEL" "info"
			;;
		"kafka.conf")
			shell::ini::write "$file" "$env" "KAFKA_CLUSTER_ID" "${env}-cluster"
			shell::ini::write "$file" "$env" "KAFKA_TOPIC" "${env}-events"
			shell::ini::write "$file" "$env" "KAFKA_REPLICATION_FACTOR" "1"
			shell::ini::write "$file" "$env" "KAFKA_PARTITIONS" "3"
			shell::ini::write "$file" "$env" "KAFKA_LOG_DIR" "/var/log/kafka"
			;;
		"zookeeper.conf")
			shell::ini::write "$file" "$env" "ZK_DATA_DIR" "/var/lib/zookeeper"
			shell::ini::write "$file" "$env" "ZK_CLIENT_PORT" "$base_port"
			shell::ini::write "$file" "$env" "ZK_TICK_TIME" "2000"
			shell::ini::write "$file" "$env" "ZK_INIT_LIMIT" "5"
			shell::ini::write "$file" "$env" "ZK_SYNC_LIMIT" "2"
			;;
		"nginx.conf")
			shell::ini::write "$file" "$env" "NGINX_CONF_PATH" "/etc/nginx/nginx.conf"
			shell::ini::write "$file" "$env" "NGINX_DOC_ROOT" "/var/www/html"
			shell::ini::write "$file" "$env" "NGINX_WORKER_PROCESSES" "auto"
			shell::ini::write "$file" "$env" "NGINX_ERROR_LOG" "/var/log/nginx/error.log"
			shell::ini::write "$file" "$env" "NGINX_ACCESS_LOG" "/var/log/nginx/access.log"
			;;
		"web.conf")
			shell::ini::write "$file" "$env" "WEB_FRAMEWORK" "bash-sh"
			shell::ini::write "$file" "$env" "WEB_ENV" "$env"
			shell::ini::write "$file" "$env" "WEB_PORT" "$base_port"
			shell::ini::write "$file" "$env" "WEB_STATIC_DIR" "public"
			shell::ini::write "$file" "$env" "WEB_API_PROXY" "http://localhost:5000"
			;;
		"app.conf")
			shell::ini::write "$file" "$env" "APP_NAME" "shell"
			shell::ini::write "$file" "$env" "APP_ENV" "$env"
			shell::ini::write "$file" "$env" "APP_LOG_LEVEL" "debug"
			shell::ini::write "$file" "$env" "APP_CONFIG_PATH" "./config/app.yaml"
			shell::ini::write "$file" "$env" "APP_SESSION_TIMEOUT" "3600"
			;;
		"api.conf")
			shell::ini::write "$file" "$env" "API_VERSION" "v1"
			shell::ini::write "$file" "$env" "API_BASE_URL" "http://localhost:$port"
			shell::ini::write "$file" "$env" "API_TIMEOUT" "5000"
			shell::ini::write "$file" "$env" "API_KEY_HEADER" "X-API-KEY"
			shell::ini::write "$file" "$env" "API_DOCS_URL" "http://localhost:$port/docs"
			;;
		"cache.conf")
			shell::ini::write "$file" "$env" "CACHE_ENGINE" "redis"
			shell::ini::write "$file" "$env" "CACHE_TTL" "3600"
			shell::ini::write "$file" "$env" "CACHE_MAX_MEMORY" "256mb"
			shell::ini::write "$file" "$env" "CACHE_POLICY" "allkeys-lru"
			shell::ini::write "$file" "$env" "CACHE_CLUSTER_MODE" "no"
			;;
		"search.conf")
			shell::ini::write "$file" "$env" "SEARCH_ENGINE" "elasticsearch"
			shell::ini::write "$file" "$env" "SEARCH_INDEX" "${env}-index"
			shell::ini::write "$file" "$env" "SEARCH_REPLICAS" "1"
			shell::ini::write "$file" "$env" "SEARCH_SHARDS" "1"
			shell::ini::write "$file" "$env" "SEARCH_LOG_PATH" "/var/log/elasticsearch"
			;;
		esac
	done
}

# @description Creates a new workspace with profile.conf and default .ssh/*.conf templates populated via shell::ini::write.
#
#   This function creates a new workspace directory under $SHELL_WORKSPACE_DIR/workspace/<workspace_name>,
#   initializes a profile.conf file and a .ssh/ directory with default SSH config templates (db.conf, redis.conf, etc.).
#   It uses shell::ini::write to populate each .conf file with [dev] and [uat] blocks.
# @option -n Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.
# @arg $1 string workspace_name: The name of the workspace to create.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::workspace::add dxc
#
shell::workspace::add() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Creates a new workspace with profile.conf and default .ssh/*.conf templates populated via shell::ini::write"
		shell::logger::usage "shell::workspace::add [-n] [-h] <workspace_name>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "workspace_name" "The name of the workspace to create."
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check if workspace name is provided
	if [ $# -lt 1 ]; then
		echo "Usage: shell::workspace::add [-n] <workspace_name>"
		return 1
	fi

	local name="$1"

	# Sanitize the workspace name
	# We use shell::strings::sanitize::lower to ensure the name is in lowercase and safe for use as a directory name
	# This function replaces non-alphanumeric characters with underscores
	# This helps prevent issues with invalid directory names
	name=$(shell::strings::sanitize::lower "$name")

	local base="$SHELL_WORKSPACE_DIR"
	local dir="$base/$name"
	local profile="$dir/profile.conf"
	local ssh_dir="$dir/.ssh"

	# Check if workspace already exists
	# If the directory already exists, we return an error
	if [ -d "$dir" ]; then
		shell::logger::error "Workspace '$name' already exists at '$dir'"
		return 1
	fi

	# Ensure the fzf package is installed
	shell::dependency::fzf::ensure

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
		shell::logger::error "No configuration files selected."
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
	# If dry_run is true, we call shell::logger::command_clip with the command
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
	else
		shell::fs::touch --private "$profile"
		shell::fs::mkdir --private "$ssh_dir"
		shell::exec::shell "$cmd"
		shell::logger::success "Workspace '$name' created at '$dir'"

		# Populate profile.conf with default values
		# We use shell::ini::write to write default values to the profile.conf file
		# This includes the workspace name, description, and other relevant fields
		# We use the shell::ini::write function to write these values
		while IFS= read -r f; do
			local file="$ssh_dir/$f"
			shell::logger::debug "Populating '$f' with default [dev] and [uat] blocks..."
			shell::workspace::ssh::populate "$file" "$f"
		done <<<"$selected_files"
	fi
}

# @description Adds a missing SSH configuration file to a specified workspace.
#
#   This function checks if the specified SSH configuration file exists in the workspace's .ssh directory.
#   If it does not exist, it creates the file and populates it using shell::workspace::ssh::populate.
# @option -n Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.
# @arg $1 string workspace_name: The name of the workspace.
# @arg $2 string ssh_conf_name: The name of the SSH configuration file to add (e.g., kafka.conf).
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::workspace::ssh::add my-app kafka.conf
#   shell::workspace::ssh::add -n my-app kafka.conf
#
shell::workspace::ssh::add() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Adds a missing SSH configuration file to a specified workspace"
		shell::logger::usage "shell::workspace::ssh::add [-n] [-h] <workspace_name> <ssh_conf_name>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "workspace_name" "The name of the workspace."
		shell::logger::item "ssh_conf_name" "The name of the SSH configuration file to add (e.g., kafka.conf)."
		shell::logger::example "shell::workspace::ssh::add my-app kafka.conf"
		shell::logger::example "shell::workspace::ssh::add -n my-app kafka.conf"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check if workspace name and SSH configuration name are provided
	# If not, we print usage information and return an error
	if [ $# -lt 2 ]; then
		echo "Usage: shell::workspace::ssh::add [-n] <workspace_name> <ssh_conf_name>"
		return 1
	fi

	# Get the workspace name and SSH configuration name from the arguments
	local name="$1"
	if [ -z "$name" ]; then
		shell::logger::error "Workspace name is required."
		return 1
	fi

	# Get the SSH configuration name from the arguments
	local conf="$2"
	if [ -z "$conf" ]; then
		shell::logger::error "SSH configuration name is required."
		return 1
	fi

	# Sanitize the workspace name
	# We use shell::strings::sanitize::lower to ensure the name is in lowercase and safe for use as a directory name
	# This function replaces non-alphanumeric characters with underscores
	# This helps prevent issues with invalid directory names
	# We use shell::strings::sanitize::lower to ensure the name is in lowercase and safe for use as a directory name
	# This function replaces non-alphanumeric characters with underscores
	# This helps prevent issues with invalid directory names
	name=$(shell::strings::sanitize::lower "$name")

	# Construct the directory and file paths
	# We define the base directory for the workspace and the .ssh directory
	# The file path is constructed by combining the workspace directory, .ssh directory, and the SSH configuration name
	local dir="$SHELL_WORKSPACE_DIR/$name/.ssh"
	local file="$dir/$conf"

	# Check if the workspace directory exists
	# We check if the directory for the workspace exists
	# If the directory does not exist, we print an error message and return
	if [ ! -d "$dir" ]; then
		shell::logger::error "Workspace '$name' does not exist or has no .ssh directory."
		return 1
	fi

	# Check if the SSH configuration file already exists
	# We check if the specified file already exists in the .ssh directory
	# If the file exists, we print a message and return
	# This prevents overwriting an existing configuration file
	if [ -f "$file" ]; then
		shell::logger::warn "'$conf' already exists in workspace '$name'."
		return 0
	fi

	# Check if the dry run mode is enabled
	# If dry_run is true, we print the command to create the file and populate it
	# This allows us to see what would be done without actually creating the file
	# If dry_run is false, we create the file and populate it with default values
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "touch \"$file\" && shell::workspace::ssh::populate \"$file\" \"$conf\""
	else
		shell::fs::touch --private "$file"
		shell::workspace::ssh::populate "$file" "$conf"
		shell::logger::success "'$conf' added to workspace '$name'."
	fi
}

# @description Interactively selects a workspace and SSH config to add using fzf.
#
#   This function uses fzf to select a workspace and a missing SSH configuration file.
#   It then calls shell::workspace::ssh::add to add the selected file if it does not exist.
#   Every menu ends with a "← Back" entry (SHELL_FZF_BACK_LABEL); picking it steps back one level and changes nothing.
# @option -n Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::workspace::ssh::add::fzf
#   shell::workspace::ssh::add::fzf -n
#
shell::workspace::ssh::add::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a workspace and SSH config to add using fzf"
		shell::logger::usage "shell::workspace::ssh::add::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::workspace::ssh::add::fzf"
		shell::logger::example "shell::workspace::ssh::add::fzf -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Ensure fzf is installed
	shell::dependency::fzf::ensure

	# Check if the workspace directory exists
	# We check if the directory defined by $SHELL_WORKSPACE_DIR exists
	local base="$SHELL_WORKSPACE_DIR"
	if [ ! -d "$base" ]; then
		shell::logger::error "Workspace directory '$base' not found."
		return 1
	fi

	# List all workspace directories and use fzf to select one
	# We use find to locate directories under the workspace directory
	# We use xargs to get the basename of each directory
	# Two levels: "Back" at the SSH config menu returns to the workspace menu,
	# "Back" at the workspace menu leaves the function.
	local workspace ws_list ssh_dir selected_conf
	local all_files=("server.conf" "db.conf" "redis.conf" "rmq.conf" "ast.conf" "kafka.conf" "zookeeper.conf" "nginx.conf" "web.conf" "app.conf" "api.conf" "cache.conf" "search.conf" "mysql.conf")
	local missing_files=() f
	while true; do
		ws_list=$(find "$base" -mindepth 1 -maxdepth 1 -type d | xargs -n 1 basename)

		# If no workspace was selected, we print an error message and return
		# This ensures the user knows they need to select a workspace
		if [ -z "$ws_list" ]; then
			shell::logger::error "No workspace selected."
			return 1
		fi
		workspace=$(printf '%s\n%s\n' "$ws_list" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --prompt="Select workspace: ")
		if [ -z "$workspace" ]; then
			shell::logger::error "No workspace selected."
			return 1
		fi
		if [ "$workspace" = "$SHELL_FZF_BACK_LABEL" ]; then
			shell::logger::info "Back — nothing was added"
			return "$RETURN_BACK"
		fi

		# Check if the selected workspace has a .ssh directory
		ssh_dir="$base/$workspace/.ssh"
		if [ ! -d "$ssh_dir" ]; then
			shell::logger::error "Workspace '$workspace' has no .ssh directory."
			return 1
		fi

		# List all possible SSH config files and check which ones are missing
		missing_files=()
		for f in "${all_files[@]}"; do
			[ ! -f "$ssh_dir/$f" ] && missing_files+=("$f")
		done

		# If no files are missing, we print a message and return
		# This means all SSH config files already exist in the workspace
		if [ ${#missing_files[@]} -eq 0 ]; then
			shell::logger::success "All SSH config files already exist in workspace '$workspace'."
			return 0
		fi

		# Use fzf to select one of the missing SSH config files
		selected_conf=$(printf '%s\n' "${missing_files[@]}" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --prompt="Select SSH config to add: ")

		# If no SSH config was selected, we print an error message and return
		if [ -z "$selected_conf" ]; then
			shell::logger::error "No SSH config selected."
			return 1
		fi

		# Back to the workspace menu
		if [ "$selected_conf" = "$SHELL_FZF_BACK_LABEL" ]; then
			continue
		fi
		break
	done

	# Check if the dry run mode is enabled
	# If dry_run is true, we print the command to add the SSH config file
	# This allows us to see what would be done without actually adding the file
	if [ "$dry_run" = "true" ]; then
		shell::workspace::ssh::add -n "$workspace" "$selected_conf"
	else
		shell::workspace::ssh::add "$workspace" "$selected_conf"
	fi
}

# @description Removes a workspace directory after confirmation.
#
#   Prompts for confirmation before deleting the workspace directory.
# @option -n Optional dry-run flag.
# @arg $1 string workspace_name: The name of the workspace to remove.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::workspace::remove dxc
#
shell::workspace::remove() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Removes a workspace directory after confirmation"
		shell::logger::usage "shell::workspace::remove [-n] [-h] <workspace_name>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "workspace_name" "The name of the workspace to remove."
		return $RETURN_SUCCESS
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
		echo "Usage: shell::workspace::remove [-n] <workspace_name>"
		return 0
	fi

	local name="$1"

	# Sanitize the workspace name
	# We use shell::strings::sanitize::lower to ensure the name is in lowercase and safe for use as a directory name
	# This function replaces non-alphanumeric characters with underscores
	# This helps prevent issues with invalid directory names
	name=$(shell::strings::sanitize::lower "$name")

	local base="$SHELL_WORKSPACE_DIR"
	local dir="$base/$name"

	# Check if the workspace directory exists
	# If the directory does not exist, we print an error message and return
	if [ ! -d "$dir" ]; then
		shell::logger::error "Workspace '$name' does not exist at '$dir'"
		return 0
	fi

	# If dry-run mode is enabled, we print the command to delete the workspace directory
	# This allows us to see what would be done without actually deleting anything
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "rm -rf \"$dir\""
		return 0
	fi
	local asked
	asked=$(shell::ask::reply "Are you sure you want to delete workspace '$name'?")
	if [ "$asked" = "yes" ]; then
		shell::fs::remove "$dir"
		shell::logger::success "Workspace '$name' removed."
		return $RETURN_SUCCESS
	fi
	shell::logger::warn "Deletion aborted."
	return 0
}

# --------------------------------------------------------------------------
# Live browser shared by shell::workspace::view::fzf / edit::fzf / manage::fzf
#
#   config file  ->  section · key  ->  action menu  ->  back to the list
#
# Every list is shell::fzf::select with a live preview and a trailing
# "← Back" entry (SHELL_FZF_BACK_LABEL). Each .conf file is decoded and rendered
# ONCE into a temp cache, so moving the cursor only prints a prepared file.
# --------------------------------------------------------------------------

# @internal
# @description Tell whether a key holds a secret that must stay hidden in previews.
#   `*_REF` keys hold a path (e.g. SSH_PRIVATE_KEY_REF), not a secret, so they are shown.
# @arg $1 string The key name.
# @exitcode 0 The value is sensitive.
# @exitcode 1 The value is not sensitive.
# @example
#   _shell::workspace::conf::sensitive "DB_PASSWORD" && echo hidden
#
_shell::workspace::conf::sensitive() {
	local key
	key="$(printf '%s' "${1-}" | tr '[:lower:]' '[:upper:]')"
	case "$key" in
	*_REF) return 1 ;;
	*PASSWORD* | *PASSWD* | *PASSPHRASE* | *SECRET* | *TOKEN* | *CREDENTIAL* | *API_KEY* | *PRIVATE_KEY*) return 0 ;;
	esac
	return 1
}

# @internal
# @description Decode one Base64 value (macOS: base64 -D, Linux: base64 -d).
# @arg $1 string The Base64 text.
# @stdout The decoded text (no trailing newline added).
# @exitcode 0 Decoded.
# @exitcode 1 The text is not valid Base64.
# @example
#   plain="$(_shell::workspace::b64decode "bG9jYWxob3N0")"
#
_shell::workspace::b64decode() {
	if [ "$(shell::os::type)" = "macos" ]; then
		printf '%s' "${1-}" | base64 -D 2>/dev/null
	else
		printf '%s' "${1-}" | base64 -d 2>/dev/null
	fi
}

# @internal
# @description Print `key<TAB>value` rows as aligned, colored lines (the focused key gets an arrow).
# @arg $1 string File holding the rows.
# @arg $2 string Optional. The key to mark.
# @stdout The rendered lines.
# @exitcode 0 Success.
# @example
#   _shell::workspace::conf::render "$dir/s/1" "SSH_SERVER_ADDR"
#
_shell::workspace::conf::render() {
	local esc
	esc="$(printf '\033')"
	awk -F'\t' -v e="$esc" -v focus="${2-}" '
		{ k[NR] = $1; v[NR] = $2; if (length($1) > w) w = length($1) }
		END {
			fmt = " %s " e "[36m%-" w "s" e "[0m  " e "[32m%s" e "[0m\n"
			for (i = 1; i <= NR; i++) {
				mark = (focus != "" && k[i] == focus) ? e "[33m▶" e "[0m" : " "
				printf fmt, mark, k[i], v[i]
			}
		}' "$1"
}

# @internal
# @description Decode a .conf file once and write everything the live preview needs into a directory.
#   Layout of <dir>: `rows` (display<TAB>n, one per key), `v/<n>` (decoded value), `p/<n>` (rendered
#   preview of key n), `m/<n>` (section index, section, key), `kv` (section, key, n), `o` (overview of
#   the whole file), `count` and `sections`. Sensitive values are masked in every preview.
# @arg $1 string The .conf file.
# @arg $2 string The cache directory (recreated).
# @arg $3 string The workspace name (shown in the preview).
# @exitcode 0 Cache written.
# @exitcode 1 The directory could not be created.
# @exitcode 2 Missing arguments or the file does not exist.
# @example
#   _shell::workspace::conf::load "$ssh_dir/server.conf" "$work/f1" "dxc"
#
_shell::workspace::conf::load() {
	local file="${1-}" dir="${2-}" ws="${3-}"
	if [ ! -f "$file" ] || [ -z "$dir" ]; then
		return "$RETURN_INVALID"
	fi
	rm -rf "$dir"
	mkdir -p "$dir/v" "$dir/p" "$dir/s" "$dir/m" || return "$RETURN_FAILURE"

	local esc dim rst tab=$'\t'
	esc="$(printf '\033')"
	dim="${esc}[2m"
	rst="${esc}[0m"

	local n=0 sec_n=0 section="" prev="@@none@@" line key val dec disp
	: >"$dir/rows"
	: >"$dir/kv"
	while IFS= read -r line || [ -n "$line" ]; do
		line="${line%$'\r'}"
		line="${line#"${line%%[![:space:]]*}"}"
		case "$line" in
		'' | '#'* | ';'*) continue ;;
		'['*']')
			section="${line#\[}"
			section="${section%\]}"
			continue
			;;
		*=*) ;;
		*) continue ;;
		esac
		key="${line%%=*}"
		key="${key%"${key##*[![:space:]]}"}"
		val="${line#*=}"
		val="${val#"${val%%[![:space:]]*}"}"
		val="${val%"${val##*[![:space:]]}"}"
		if [ "${#val}" -ge 2 ] && [ "${val#\"}" != "$val" ] && [ "${val%\"}" != "$val" ]; then
			val="${val#\"}"
			val="${val%\"}"
		fi
		if ! dec="$(_shell::workspace::b64decode "$val")"; then
			dec="$val"
		fi

		if [ "$section" != "$prev" ]; then
			sec_n=$((sec_n + 1))
			printf '%s' "${section:-(none)}" >"$dir/s/name.$sec_n"
			prev="$section"
		fi
		n=$((n + 1))
		printf '%s' "$dec" >"$dir/v/$n"
		printf '%s\t%s\t%s\n' "$sec_n" "${section:-(none)}" "$key" >"$dir/m/$n"
		printf '%s\t%s\t%s\n' "${section:-(none)}" "$key" "$n" >>"$dir/kv"
		if _shell::workspace::conf::sensitive "$key"; then
			disp="••••••••"
		else
			disp="${dec%%$'\n'*}"
			disp="${disp//$esc/}"
			disp="${disp//$tab/ }"
			if [ "${#disp}" -gt 100 ]; then
				disp="${disp:0:99}…"
			fi
			case "$dec" in *$'\n'*) disp="${disp} …" ;; esac
		fi
		printf '%s\t%s\n' "$key" "$disp" >>"$dir/s/$sec_n"
		printf '%-8s %s\t%s\n' "${section:-(none)}" "$key" "$n" >>"$dir/rows"
	done <"$file"

	printf '%s' "$n" >"$dir/count"
	printf '%s' "$sec_n" >"$dir/sections"

	# One preview file per key: where it is, the section it lives in, and the selected value.
	local i=1 sidx sname skey fname
	fname="$(basename "$file")"
	while [ "$i" -le "$n" ]; do
		IFS=$'\t' read -r sidx sname skey <"$dir/m/$i"
		{
			printf '%s%-9s%s %s\n' "$dim" "workspace" "$rst" "$ws"
			printf '%s%-9s%s %s\n' "$dim" "file" "$rst" "$fname"
			printf '%s%-9s%s %s\n\n' "$dim" "section" "$rst" "$sname"
			_shell::workspace::conf::render "$dir/s/$sidx" "$skey"
			printf '\n%svalue%s\n' "$dim" "$rst"
			if _shell::workspace::conf::sensitive "$skey"; then
				printf '  %shidden — choose "Reveal value" in the action menu%s\n' "$dim" "$rst"
			else
				tr -d '\033' <"$dir/v/$i" | sed 's/^/  /'
				printf '\n'
			fi
		} >"$dir/p/$i"
		i=$((i + 1))
	done
	printf '%sGo back without changing anything%s\n' "$dim" "$rst" >"$dir/p/b"
	printf '%sAdd a key or a section to this file%s\n' "$dim" "$rst" >"$dir/p/n"

	# Overview of the whole file (preview of the config-file list).
	local k=1
	{
		printf '%s%-9s%s %s\n' "$dim" "workspace" "$rst" "$ws"
		printf '%s%-9s%s %s\n\n' "$dim" "file" "$rst" "$fname"
		while [ "$k" -le "$sec_n" ]; do
			printf '%s[%s]%s\n' "${esc}[33m" "$(cat "$dir/s/name.$k")" "$rst"
			_shell::workspace::conf::render "$dir/s/$k" ""
			printf '\n'
			k=$((k + 1))
		done
		if [ "$n" -eq 0 ]; then
			printf '  %sno keys yet%s\n' "$dim" "$rst"
		fi
	} >"$dir/o"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Print the decoded value of a key from a cache made by _shell::workspace::conf::load.
# @arg $1 string The cache directory.
# @arg $2 string The section.
# @arg $3 string The key.
# @stdout The value.
# @exitcode 0 Found.
# @exitcode 8 The key is not in that section.
# @example
#   addr="$(_shell::workspace::conf::value "$dir" dev SSH_SERVER_ADDR)"
#
_shell::workspace::conf::value() {
	local n
	n="$(awk -F'\t' -v s="${2-}" -v k="${3-}" '$1 == s && $2 == k { print $3; exit }' "$1/kv")"
	if [ -z "$n" ]; then
		return "$RETURN_EMPTY"
	fi
	cat "$1/v/$n"
}

# @internal
# @description Print a key of a section, or of the [base] section when the section lacks it.
# @arg $1 string The cache directory.
# @arg $2 string The section.
# @arg $3 string The key.
# @stdout The value.
# @exitcode 0 Found and not empty.
# @exitcode 8 Neither section holds it.
# @example
#   key="$(_shell::workspace::conf::value::or_base "$dir" dev SSH_PRIVATE_KEY_REF)"
#
_shell::workspace::conf::value::or_base() {
	local v
	v="$(_shell::workspace::conf::value "$1" "$2" "$3" 2>/dev/null)"
	if [ -z "$v" ]; then
		v="$(_shell::workspace::conf::value "$1" "base" "$3" 2>/dev/null)"
	fi
	if [ -z "$v" ]; then
		return "$RETURN_EMPTY"
	fi
	printf '%s\n' "$v"
}

# @internal
# @description Build the `ssh -N -L ...` command of a section (needs SSH_SERVER_ADDR, _PORT and _USER).
#   Values missing in the section fall back to the [base] section of the same file.
# @arg $1 string The cache directory.
# @arg $2 string The section.
# @stdout The command.
# @exitcode 0 Built.
# @exitcode 8 The section lacks the server address, port or user.
# @example
#   cmd="$(_shell::workspace::conf::ssh_command "$dir" dev)"
#
_shell::workspace::conf::ssh_command() {
	local d="${1-}" s="${2-}" addr port user key laddr lport taddr tport cmd
	addr="$(_shell::workspace::conf::value::or_base "$d" "$s" SSH_SERVER_ADDR)" || return "$RETURN_EMPTY"
	port="$(_shell::workspace::conf::value::or_base "$d" "$s" SSH_SERVER_PORT)" || return "$RETURN_EMPTY"
	user="$(_shell::workspace::conf::value::or_base "$d" "$s" SSH_SERVER_USER)" || return "$RETURN_EMPTY"
	key="$(_shell::workspace::conf::value::or_base "$d" "$s" SSH_PRIVATE_KEY_REF)" || key=""
	laddr="$(_shell::workspace::conf::value::or_base "$d" "$s" SSH_LOCAL_ADDR)" || laddr="127.0.0.1"
	lport="$(_shell::workspace::conf::value::or_base "$d" "$s" SSH_LOCAL_PORT)" || lport=""
	taddr="$(_shell::workspace::conf::value::or_base "$d" "$s" SSH_SERVER_TARGET_SERVICE_ADDR)" || taddr="127.0.0.1"
	tport="$(_shell::workspace::conf::value::or_base "$d" "$s" SSH_SERVER_TARGET_SERVICE_PORT)" || tport=""

	cmd="ssh -N"
	if [ -n "$lport" ] && [ -n "$tport" ]; then
		cmd="${cmd} -L ${laddr}:${lport}:${taddr}:${tport}"
	fi
	cmd="${cmd} -p $(printf '%q' "$port")"
	if [ -n "$key" ]; then
		cmd="${cmd} -i $(printf '%q' "$key")"
	fi
	cmd="${cmd} $(printf '%q' "${user}@${addr}")"
	printf '%s\n' "$cmd"
}

# @internal
# @description Copy a value to the clipboard and say what happened. Never copies an empty value.
#   The value travels in a variable (no fzf redirection or subshell is involved), so it works on
#   every pass of a menu loop and keeps spaces, quotes, `$` and newlines intact. Without a clipboard
#   tool the value is printed instead, with a warning. In dry-run mode only the command is shown.
# @arg $1 string What is copied (for the messages).
# @arg $2 string The value.
# @arg $3 string `true` for dry-run.
# @arg $4 string Optional. How to show the value in dry-run mode (default: the value; use it to hide secrets).
# @exitcode 0 Copied (or printed, or dry-run).
# @exitcode 1 The clipboard tool failed.
# @exitcode 2 The value is empty.
# @example
#   _shell::workspace::copy "value of SSH_SERVER_ADDR" "$value" "$dry_run"
#
_shell::workspace::copy() {
	local label="${1-}" value="${2-}" dry_run="${3-false}" shown="${4-}" rc=0
	if [ -z "$value" ]; then
		shell::logger::error "Nothing to copy: ${label} is empty"
		return "$RETURN_INVALID"
	fi
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "shell::clipboard::copy $(printf '%q' "${shown:-$value}")"
		return "$RETURN_SUCCESS"
	fi
	shell::clipboard::copy "$value" || rc=$?
	case "$rc" in
	0)
		shell::logger::success "Copied ${label}"
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_NOT_FOUND")
		shell::logger::warn "No clipboard tool found — printing ${label} instead"
		printf '%s\n' "$value"
		return "$RETURN_SUCCESS"
		;;
	*)
		shell::logger::error "Could not copy ${label}"
		return "$RETURN_FAILURE"
		;;
	esac
}

# @internal
# @description Check a value before it is written to a .conf file.
#   Always: non-empty. For `*_ADDR` keys: an IP address or a plain host name. For `*_PORT` keys: 1-65535.
# @arg $1 string The key.
# @arg $2 string The new value.
# @exitcode 0 Valid.
# @exitcode 2 Invalid (the reason is logged).
# @example
#   _shell::workspace::conf::validate "SSH_SERVER_PORT" "2222" || return
#
_shell::workspace::conf::validate() {
	local key value
	key="$(printf '%s' "${1-}" | tr '[:lower:]' '[:upper:]')"
	value="${2-}"
	if [ -z "$value" ]; then
		shell::logger::error "The value cannot be empty"
		return "$RETURN_INVALID"
	fi
	case "$key" in
	*_PORT)
		case "$value" in
		*[!0-9]* | 0*)
			shell::logger::error "'${value}' is not a valid port (1-65535)"
			return "$RETURN_INVALID"
			;;
		esac
		if [ "$value" -gt 65535 ]; then
			shell::logger::error "'${value}' is not a valid port (1-65535)"
			return "$RETURN_INVALID"
		fi
		;;
	*_ADDR)
		if ! shell::validate::ip::address "$value" >/dev/null 2>&1; then
			case "$value" in
			*[!A-Za-z0-9._-]* | -* | .* | '')
				shell::logger::error "'${value}' is not an IP address or a valid host name"
				return "$RETURN_INVALID"
				;;
			esac
		fi
		;;
	esac
	return "$RETURN_SUCCESS"
}

# @internal
# @description Run one action of the view/edit browser on the focused key (or on the file).
#   Read-only actions copy or reveal. Edit actions change the file through shell::ini::* (which
#   Base64-encodes the value and replaces the file atomically); the caller reloads the cache after.
#   In dry-run mode the command is printed with shell::logger::command_clip and nothing changes.
# @arg $1 string Action label (as shown in the action menu).
# @arg $2 string The .conf file.
# @arg $3 string The cache directory of that file.
# @arg $4 string Section of the focused key (empty for the "add" row).
# @arg $5 string Focused key (empty for the "add" row).
# @arg $6 string `true` for dry-run.
# @exitcode 0 Done (or nothing to do).
# @exitcode 1 The action failed.
# @exitcode 2 Invalid input.
# @example
#   _shell::workspace::conf::act "Copy value" "$file" "$dir" dev SSH_SERVER_ADDR false
#
_shell::workspace::conf::act() {
	local action="${1-}" file="${2-}" dir="${3-}" section="${4-}" key="${5-}" dry_run="${6-false}"
	local value shown new answer line out sec k n

	case "$action" in
	"Copy value")
		value="$(_shell::workspace::conf::value "$dir" "$section" "$key")"
		shown="$value"
		_shell::workspace::conf::sensitive "$key" && shown="********"
		_shell::workspace::copy "the value of ${key}" "$value" "$dry_run" "$shown"
		;;
	"Copy KEY=VALUE")
		value="$(_shell::workspace::conf::value "$dir" "$section" "$key")"
		shown="${key}=${value}"
		_shell::workspace::conf::sensitive "$key" && shown="${key}=********"
		_shell::workspace::copy "${key}=…" "${key}=${value}" "$dry_run" "$shown"
		;;
	"Copy section as KEY=VALUE lines")
		out=""
		while IFS=$'\t' read -r sec k n; do
			[ "$sec" = "$section" ] || continue
			line="$(cat "$dir/v/$n")"
			out="${out}${k}=${line}"$'\n'
		done <"$dir/kv"
		_shell::workspace::copy "section [${section}]" "${out%$'\n'}" "$dry_run" "<KEY=VALUE lines of [${section}]>"
		;;
	"Copy ssh tunnel command")
		value="$(_shell::workspace::conf::ssh_command "$dir" "$section")" || {
			shell::logger::error "[${section}] has no SSH_SERVER_ADDR / SSH_SERVER_PORT / SSH_SERVER_USER"
			return "$RETURN_FAILURE"
		}
		_shell::workspace::copy "the ssh tunnel command of [${section}]" "$value" "$dry_run"
		;;
	"Reveal value")
		value="$(_shell::workspace::conf::value "$dir" "$section" "$key")"
		shell::logger::info "[${section}] ${key} = ${value}"
		;;
	"Edit value")
		new="$(shell::ask::text "New value for ${key} in [${section}]:")" || {
			shell::logger::info "Cancelled — nothing was changed"
			return "$RETURN_SUCCESS"
		}
		_shell::workspace::conf::validate "$key" "$new" || return "$?"
		_shell::workspace::conf::write "$file" "$dir" "$section" "$key" "$new" "$dry_run"
		;;
	"Add key")
		if [ -z "$section" ]; then
			section="$(shell::ask::text "Section for the new key:")" || return "$RETURN_SUCCESS"
		fi
		key="$(shell::ask::text "New key name in [${section}]:")" || return "$RETURN_SUCCESS"
		case "$key" in
		[A-Za-z_]*) ;;
		*)
			shell::logger::error "'${key}' is not a valid key name"
			return "$RETURN_INVALID"
			;;
		esac
		case "$key" in
		*[!A-Za-z0-9_]*)
			shell::logger::error "'${key}' is not a valid key name"
			return "$RETURN_INVALID"
			;;
		esac
		new="$(shell::ask::text "Value for ${key}:")" || return "$RETURN_SUCCESS"
		_shell::workspace::conf::validate "$key" "$new" || return "$?"
		_shell::workspace::conf::write "$file" "$dir" "$section" "$key" "$new" "$dry_run"
		;;
	"Remove key")
		answer="$(shell::ask::reply "Remove the key '${key}' from [${section}]?")"
		if [ "$answer" != "yes" ]; then
			shell::logger::info "Cancelled — nothing was removed"
			return "$RETURN_SUCCESS"
		fi
		if [ "$dry_run" = "true" ]; then
			shell::ini::key::remove -n "$file" "$section" "$key"
		else
			shell::ini::key::remove "$file" "$section" "$key"
		fi
		;;
	"Add section")
		new="$(shell::ask::text "New section name:")" || return "$RETURN_SUCCESS"
		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "shell::ini::section::add $(printf '%q %q' "$file" "$new")"
			return "$RETURN_SUCCESS"
		fi
		shell::ini::section::add "$file" "$new"
		;;
	"Rename section")
		new="$(shell::ask::text "New name for section [${section}]:")" || return "$RETURN_SUCCESS"
		answer="$(shell::ask::reply "Rename [${section}] to [${new}]?")"
		if [ "$answer" != "yes" ]; then
			shell::logger::info "Cancelled — nothing was renamed"
			return "$RETURN_SUCCESS"
		fi
		if [ "$dry_run" = "true" ]; then
			shell::ini::section::rename -n "$file" "$section" "$new"
		else
			shell::ini::section::rename "$file" "$section" "$new"
		fi
		;;
	"Remove section")
		answer="$(shell::ask::reply "Remove the section [${section}] and all its keys?")"
		if [ "$answer" != "yes" ]; then
			shell::logger::info "Cancelled — nothing was removed"
			return "$RETURN_SUCCESS"
		fi
		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "shell::ini::section::remove $(printf '%q %q' "$file" "$section")"
			return "$RETURN_SUCCESS"
		fi
		shell::ini::section::remove "$file" "$section"
		;;
	*)
		shell::logger::error "Unknown action: ${action}"
		return "$RETURN_INVALID"
		;;
	esac
}

# @internal
# @description Write one value with shell::ini::write (Base64 + atomic replace) and check that it landed.
#   The value of a sensitive key is never echoed. The cache is reloaded so the preview shows the change.
# @arg $1 string The .conf file.
# @arg $2 string The cache directory of that file.
# @arg $3 string Section.
# @arg $4 string Key.
# @arg $5 string The new value.
# @arg $6 string `true` for dry-run.
# @exitcode 0 Written (or dry-run).
# @exitcode 1 The value could not be written.
# @example
#   _shell::workspace::conf::write "$file" "$dir" dev SSH_SERVER_PORT 2222 false
#
_shell::workspace::conf::write() {
	local file="${1-}" dir="${2-}" section="${3-}" key="${4-}" new="${5-}" dry_run="${6-false}" shown got
	shown="$new"
	_shell::workspace::conf::sensitive "$key" && shown="********"
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "shell::ini::write $(printf '%q %q %q %q' "$file" "$section" "$key" "$shown")"
		return "$RETURN_SUCCESS"
	fi
	# ini::write logs the value on stderr: keep secrets out of the terminal.
	shell::ini::write "$file" "$section" "$key" "$new" 2>/dev/null
	_shell::workspace::conf::load "$file" "$dir" "$(basename "$(dirname "$(dirname "$file")")")" || return "$RETURN_FAILURE"
	got="$(_shell::workspace::conf::value "$dir" "$section" "$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')")" || {
		shell::logger::error "Could not write ${key} in [${section}]"
		return "$RETURN_FAILURE"
	}
	if [ "$got" != "$new" ] && [ "$got" != "\"${new}\"" ]; then
		shell::logger::error "Could not write ${key} in [${section}] (the file holds a different value)"
		return "$RETURN_FAILURE"
	fi
	shell::logger::success "Saved ${key} in [${section}]"
}

# @internal
# @description List the .conf files of a workspace as `label<TAB>index` rows for the file menu.
# @arg $1 string The work directory (holds f<index>/ caches).
# @arg $2 string Number of files.
# @stdout The rows.
# @exitcode 0 Success.
# @example
#   rows="$(_shell::workspace::conf::file_rows "$work" 3)"
#
_shell::workspace::conf::file_rows() {
	local work="${1-}" total="${2-0}" i=1
	while [ "$i" -le "$total" ]; do
		printf '%s  (%s sections · %s keys)\t%s\n' "$(basename "$(cat "$work/file.$i")")" \
			"$(cat "$work/f$i/sections")" "$(cat "$work/f$i/count")" "$i"
		i=$((i + 1))
	done
}

# @internal
# @description The browser loop: config file list -> key list -> action menu -> back to the key list.
#   Back at the action menu returns to the key list, Back at the key list returns to the file list,
#   and Back at the top list returns RETURN_BACK. After every action (copy included) the key list is
#   shown again with the cursor where it was; after a write the preview already shows the new value.
#   A workspace with a single .conf file skips the file list.
# @arg $1 string `view` or `edit`.
# @arg $2 string Workspace name.
# @arg $3 string `true` for dry-run.
# @arg $4 string The .conf files, one per line.
# @arg $5 string Work directory for the caches.
# @exitcode 0 The user left with ESC / Ctrl-C.
# @exitcode 1 A file could not be loaded.
# @exitcode 11 The user picked "← Back" at the top list.
# @example
#   _shell::workspace::conf::browse::loop view dxc false "$files" "$work"
#
_shell::workspace::conf::browse::loop() {
	local mode="${1-}" name="${2-}" dry_run="${3-false}" list="${4-}" work="${5-}"
	local back="$SHELL_FZF_BACK_LABEL" tab=$'\t'
	local total=0 f level="files" single="false" cur=1
	while IFS= read -r f; do
		total=$((total + 1))
		printf '%s' "$f" >"$work/file.$total"
		if ! _shell::workspace::conf::load "$f" "$work/f$total" "$name"; then
			shell::logger::error "Could not read '$f'"
			return "$RETURN_FAILURE"
		fi
	done <<<"$list"
	mkdir -p "$work/fb"
	printf '\033[2mGo back without changing anything\033[0m\n' >"$work/fb/o"

	if [ "$total" -eq 1 ]; then
		level="items"
		single="true"
	fi

	local picked rc idx label file dir section key skip
	local -a files_init=() items_init=() acts=()
	local act_picked
	while true; do
		if [ "$level" = "files" ]; then
			picked="$({
				_shell::workspace::conf::file_rows "$work" "$total"
				printf '%s\t%s\n' "$back" "b"
			} | shell::fzf::select ${files_init[@]+"${files_init[@]}"} \
				--prompt="Config file: " \
				--header="${name} · Enter: open   ESC: leave   ${back}: previous" \
				--delimiter="$tab" --with-nth=1 --initial-field 1 \
				--preview="cat '$work'/f{2}/o" --preview-window="right:60%:wrap" \
				--height=60%)"
			rc=$?
			if [ "$rc" -ne 0 ] || [ -z "$picked" ]; then
				shell::logger::info "Closed"
				return "$RETURN_SUCCESS"
			fi
			label="${picked%%"$tab"*}"
			if [ "$label" = "$back" ]; then
				shell::logger::info "Back — nothing was changed"
				return "$RETURN_BACK"
			fi
			cur="${picked##*"$tab"}"
			files_init=(--initial "$label")
			items_init=()
			level="items"
			continue
		fi

		# --- key list of one file -------------------------------------------------
		file="$(cat "$work/file.$cur")"
		dir="$work/f$cur"
		picked="$({
			cat "$dir/rows"
			if [ "$mode" = "edit" ]; then
				printf '%s\t%s\n' "＋ Add a key or a section" "n"
			fi
			printf '%s\t%s\n' "$back" "b"
		} | shell::fzf::select ${items_init[@]+"${items_init[@]}"} \
			--prompt="$(basename "$file"): " \
			--header="${name} · Enter: actions   ESC: leave   ${back}: previous" \
			--delimiter="$tab" --with-nth=1 --initial-field 1 \
			--preview="cat '$dir'/p/{2}" --preview-window="right:60%:wrap" \
			--height=60%)"
		rc=$?
		if [ "$rc" -ne 0 ] || [ -z "$picked" ]; then
			shell::logger::info "Closed"
			return "$RETURN_SUCCESS"
		fi
		label="${picked%%"$tab"*}"
		idx="${picked##*"$tab"}"
		if [ "$idx" = "b" ]; then
			if [ "$single" = "true" ]; then
				shell::logger::info "Back — nothing was changed"
				return "$RETURN_BACK"
			fi
			level="files"
			continue
		fi
		items_init=(--initial "$label")

		section=""
		key=""
		if [ "$idx" != "n" ]; then
			IFS=$'\t' read -r skip section key <"$dir/m/$idx"
		fi

		# --- action menu ------------------------------------------------------------
		acts=()
		if [ "$idx" = "n" ]; then
			acts=("Add key" "Add section")
		elif [ "$mode" = "edit" ]; then
			acts=("Edit value" "Add key" "Remove key" "Add section" "Rename section" "Remove section" "Copy value")
		else
			acts=("Copy value" "Copy KEY=VALUE")
			if _shell::workspace::conf::sensitive "$key"; then
				acts+=("Reveal value")
			fi
			acts+=("Copy section as KEY=VALUE lines")
			if _shell::workspace::conf::ssh_command "$dir" "$section" >/dev/null 2>&1; then
				acts+=("Copy ssh tunnel command")
			fi
		fi
		act_picked="$(printf '%s\n' ${acts[@]+"${acts[@]}"} "$back" | shell::fzf::select \
			--prompt="Action: " \
			--header="${name} · $(basename "$file")${section:+ · [${section}]}${key:+ · ${key}}" \
			--height=40%)"
		rc=$?
		if [ "$rc" -ne 0 ] || [ -z "$act_picked" ]; then
			shell::logger::info "Closed"
			return "$RETURN_SUCCESS"
		fi
		if [ "$act_picked" = "$back" ]; then
			continue
		fi

		_shell::workspace::conf::act "$act_picked" "$file" "$dir" "$section" "$key" "$dry_run" || true
		# Reload so the list and the preview show what an edit just changed.
		if [ "$mode" = "edit" ] && [ "$dry_run" != "true" ]; then
			_shell::workspace::conf::load "$file" "$dir" "$name" || return "$RETURN_FAILURE"
		fi
	done
}

# @internal
# @description Entry point of view::fzf / edit::fzf: validate the workspace, build the cache, run the browser.
#   The temp directory is always removed, whichever way the browser ends.
# @arg $1 string `view` or `edit`.
# @arg $2 string Workspace name (sanitized here).
# @arg $3 string `true` for dry-run.
# @exitcode 0 The user left with ESC / Ctrl-C, or the workspace has no .conf file.
# @exitcode 1 The workspace does not exist, or a file could not be read.
# @exitcode 11 The user picked "← Back" at the top list.
# @example
#   _shell::workspace::conf::browse view dxc false
#
_shell::workspace::conf::browse() {
	local mode="${1-}" name="${2-}" dry_run="${3-false}"

	# Sanitize the workspace name the same way every workspace function does.
	name=$(shell::strings::sanitize::lower "$name")

	local ssh_dir="$SHELL_WORKSPACE_DIR/$name/.ssh"
	if [ ! -d "$ssh_dir" ]; then
		shell::logger::error "Workspace '$name' does not exist or has no .ssh directory."
		return 1
	fi

	local files
	files=$(find "$ssh_dir" -type f -name "*.conf" | sort)
	if [ -z "$files" ]; then
		shell::logger::warn "No .conf files found in '$ssh_dir'"
		return 0
	fi

	shell::dependency::fzf::ensure

	local work rc=0
	work="$(mktemp -d "${TMPDIR:-/tmp}/shell-workspace.XXXXXX")" || {
		shell::logger::error "Could not create a temporary directory."
		return 1
	}
	_shell::workspace::conf::browse::loop "$mode" "$name" "$dry_run" "$files" "$work" || rc=$?
	rm -rf "$work"
	return "$rc"
}

# @description Live browser of a workspace's .ssh/*.conf files (view -> copy -> view loop).
#
#   Lists the .conf files of the workspace, then the `section · key` rows of the chosen file, with a
#   live preview on the right that follows the cursor: workspace, file, section, every key of the
#   section as aligned key/value rows (Base64 decoded) and the focused value. Values of secret keys
#   (password, token, secret, API key, private key) are masked until you choose "Reveal value".
#   Enter opens an action menu: copy the value, `KEY=VALUE`, the whole section, or an `ssh -L` tunnel
#   command. After every action the list comes back with the cursor where it was, so you can copy
#   again and again; it ends only with ESC / Ctrl-C or "← Back" (SHELL_FZF_BACK_LABEL) at the top list.
#   Back at the action menu returns to the list, and Back at the list returns to the file list.
#   Every list is shell::fzf::select and ends with "← Back"; picking it changes nothing.
#   The file is decoded once when it is opened, so moving the cursor is instant.
# @option -n | --dry-run Optional. Copy actions print the clipboard command via shell::logger::command_clip and do not copy.
# @option -h | --help Show this help message.
# @arg $1 string workspace_name: The name of the workspace to view.
# @exitcode 0 Success (closed with ESC / Ctrl-C), or the workspace has no .conf file.
# @exitcode 1 The workspace does not exist, or a file could not be read.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @see shell::workspace::edit::fzf
# @see shell::workspace::manage::fzf
# @example
#   shell::workspace::view::fzf dxc
#   shell::workspace::view::fzf -n dxc
#
shell::workspace::view::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Live browser of a workspace's .ssh/*.conf files: preview, copy values, back to the list"
		shell::logger::usage "shell::workspace::view::fzf [-n] [-h] <workspace_name>"
		shell::logger::option "-n, --dry-run" "Print the clipboard command instead of copying"
		shell::logger::option "-h, --help" "Displays this help message."
		shell::logger::item "workspace_name" "The name of the workspace to view."
		shell::logger::note "Secret values are masked; pick 'Reveal value' to show one. Pick '$SHELL_FZF_BACK_LABEL' to step back (returns ${RETURN_BACK} at the top list)."
		shell::logger::example "shell::workspace::view::fzf dxc"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::workspace::view::fzf [-n] <workspace_name>"
		return 1
	fi

	_shell::workspace::conf::browse view "$1" "$dry_run"
}

# @description Live editor of a workspace's .ssh/*.conf files (edit -> save -> list loop).
#
#   Same lists and live preview as shell::workspace::view::fzf. Enter opens an action menu: edit the
#   value, add or remove a key, add, rename or remove a section, or copy the value. Input is
#   validated before it is written (non-empty; `*_ADDR` must be an IP address or host name; `*_PORT`
#   must be 1-65535). Values are Base64-encoded by shell::ini::write, which replaces the file
#   atomically, so a failed edit never corrupts the config. After a save the list returns with the
#   new value already in the preview. Removing needs a confirmation. The loop ends only with ESC /
#   Ctrl-C or "← Back" (SHELL_FZF_BACK_LABEL) at the top list; Back never changes anything.
# @option -n | --dry-run Optional. Print the shell::ini::* command instead of running it (secret values are hidden).
# @option -h | --help Show this help message.
# @arg $1 string workspace_name: The name of the workspace to edit.
# @exitcode 0 Success (closed with ESC / Ctrl-C), or the workspace has no .conf file.
# @exitcode 1 The workspace does not exist, or a file could not be read.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @see shell::workspace::view::fzf
# @see shell::workspace::manage::fzf
# @example
#   shell::workspace::edit::fzf dxc
#   shell::workspace::edit::fzf -n dxc
#
shell::workspace::edit::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Live editor of a workspace's .ssh/*.conf files: preview, validated edits, back to the list"
		shell::logger::usage "shell::workspace::edit::fzf [-n] [-h] <workspace_name>"
		shell::logger::option "-n, --dry-run" "Print the command instead of writing"
		shell::logger::option "-h, --help" "Displays this help message."
		shell::logger::item "workspace_name" "The name of the workspace to edit."
		shell::logger::note "Pick '$SHELL_FZF_BACK_LABEL' to step back (returns ${RETURN_BACK} at the top list); it never changes anything."
		shell::logger::example "shell::workspace::edit::fzf dxc"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::workspace::edit::fzf [-n] <workspace_name>"
		return 1
	fi

	_shell::workspace::conf::browse edit "$1" "$dry_run"
}

# @description Interactively selects a workspace using fzf and removes it after confirmation.
#
#   This function lists all workspace directories under $SHELL_WORKSPACE_DIR,
#   uses fzf to let the user select one, and then calls shell::workspace::remove to delete it.
#   Every menu ends with a "← Back" entry (SHELL_FZF_BACK_LABEL); picking it steps back one level and changes nothing.
# @option -n Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::workspace::remove::fzf
#
shell::workspace::remove::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a workspace using fzf and removes it after confirmation"
		shell::logger::usage "shell::workspace::remove::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	local base="$SHELL_WORKSPACE_DIR"
	local workspace_dir="$base"

	# Check if workspace directory exists
	if [ ! -d "$workspace_dir" ]; then
		shell::logger::error "Workspace directory '$workspace_dir' not found."
		return 1
	fi

	# Ensure fzf is installed
	shell::dependency::fzf::ensure

	# List all workspace directories and use fzf to select one
	# We use find to locate directories under the workspace directory
	local selected ws_list
	ws_list=$(find "$workspace_dir" -mindepth 1 -maxdepth 1 -type d | xargs -n 1 basename)
	if [ -z "$ws_list" ]; then
		shell::logger::error "No workspace selected."
		return 1
	fi
	selected=$(printf '%s\n%s\n' "$ws_list" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --prompt="Select workspace to remove: ")

	# If no workspace was selected, we print an error message and return
	if [ -z "$selected" ]; then
		shell::logger::error "No workspace selected."
		return 1
	fi

	if [ "$selected" = "$SHELL_FZF_BACK_LABEL" ]; then
		shell::logger::info "Back — nothing was removed"
		return "$RETURN_BACK"
	fi

	# If the dry mode is enabled, we print the command to remove the workspace
	# This allows us to see what would be done without actually deleting anything
	if [ "$dry_run" = "true" ]; then
		shell::workspace::remove -n "$selected"
	else
		shell::workspace::remove "$selected"
	fi
}

# @description Renames a workspace directory from an old name to a new name.
#
#   This function renames a workspace directory under $SHELL_WORKSPACE_DIR
#   from <old_name> to <new_name>. It checks for the existence of the old workspace
#   and ensures the new name does not already exist. If valid, it renames the directory.
# @option -n Optional dry-run flag. If provided, the rename command is printed using shell::logger::command_clip instead of executed.
# @arg $1 string old_name: The current name of the workspace.
# @arg $2 string new_name: The new name for the workspace.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::workspace::rename dxc dxc-renamed
#   shell::workspace::rename -n dxc dxc-renamed
#
shell::workspace::rename() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Renames a workspace directory from an old name to a new name"
		shell::logger::usage "shell::workspace::rename [-n] [-h] <old_name> <new_name>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the rename command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "old_name" "The current name of the workspace."
		shell::logger::item "new_name" "The new name for the workspace."
		return $RETURN_SUCCESS
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
		echo "Usage: shell::workspace::rename [-n] <old_name> <new_name>"
		return 1
	fi

	local old_name="$1"
	local new_name="$2"

	# Sanitize the old and new workspace names
	# We use shell::strings::sanitize::lower to ensure the names are in lowercase and safe for use as directory names
	# This function replaces non-alphanumeric characters with underscores
	old_name=$(shell::strings::sanitize::lower "$old_name")
	new_name=$(shell::strings::sanitize::lower "$new_name")

	local base="$SHELL_WORKSPACE_DIR"
	local old_dir="$base/$old_name"
	local new_dir="$base/$new_name"

	# Check if the old workspace exists and the new workspace does not
	# We check if the old directory exists and if the new directory does not
	# If the old directory does not exist, we print an error message and return
	if [ ! -d "$old_dir" ]; then
		shell::logger::error "Workspace '$old_name' does not exist at '$old_dir'"
		return 1
	fi

	# Check if the new workspace already exists
	# If the new directory already exists, we print an error message and return
	# This prevents overwriting an existing workspace
	if [ -d "$new_dir" ]; then
		shell::logger::error "Workspace '$new_name' already exists at '$new_dir'"
		return 1
	fi

	# Construct the command to rename the workspace directory
	# We use mv to move the old directory to the new directory
	# This effectively renames the workspace
	# If dry-run mode is enabled, we print the command instead of executing it
	local cmd="mv \"$old_dir\" \"$new_dir\""
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
	else
		shell::exec::shell "$cmd"
		shell::logger::success "Workspace renamed from '$old_name' to '$new_name'"
	fi
}

# @description Interactively selects a workspace using fzf and renames it.
#
#   This function lists all workspace directories under $SHELL_WORKSPACE_DIR,
#   uses fzf to let the user select one, prompts for a new name, and then calls shell::workspace::rename
#   to rename the selected workspace.
#   Every menu ends with a "← Back" entry (SHELL_FZF_BACK_LABEL); picking it steps back one level and changes nothing.
# @option -n Optional dry-run flag. If provided, the rename command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::workspace::rename::fzf
#
shell::workspace::rename::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a workspace using fzf and renames it"
		shell::logger::usage "shell::workspace::rename::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the rename command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	local base="$SHELL_WORKSPACE_DIR"
	local workspace_dir="$base"

	# Check if workspace directory exists
	if [ ! -d "$workspace_dir" ]; then
		shell::logger::error "Workspace directory '$workspace_dir' not found."
		return 1
	fi

	# Ensure fzf is installed
	shell::dependency::fzf::ensure

	# List all workspace directories and use fzf to select one
	local selected ws_list
	ws_list=$(find "$workspace_dir" -mindepth 1 -maxdepth 1 -type d | xargs -n 1 basename)
	if [ -z "$ws_list" ]; then
		shell::logger::error "No workspace selected."
		return 1
	fi
	selected=$(printf '%s\n%s\n' "$ws_list" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --prompt="Select workspace to rename: ")

	# Check if a workspace was selected
	# If no workspace was selected, we print an error message and return
	# This ensures the user knows they need to select a workspace
	# We check if the selected variable is empty
	# If it is empty, we print an error message and return
	if [ -z "$selected" ]; then
		shell::logger::error "No workspace selected."
		return 1
	fi

	if [ "$selected" = "$SHELL_FZF_BACK_LABEL" ]; then
		shell::logger::info "Back — nothing was renamed"
		return "$RETURN_BACK"
	fi

	shell::console::print "[e] Enter new name for workspace '$selected':" 208
	read -r new_name

	# Check if a new name was entered
	# If no new name was entered, we print an error message and return
	# This ensures the user knows they need to provide a new name
	if [ -z "$new_name" ]; then
		shell::logger::error "No new name entered. Aborting rename."
		return 1
	fi

	# If dry mode is enabled, we print the command to rename the workspace
	# This allows us to see what would be done without actually renaming anything
	if [ "$dry_run" = "true" ]; then
		shell::workspace::rename -n "$selected" "$new_name"
	else
		shell::workspace::rename "$selected" "$new_name"
	fi
}

# @internal
# @description Write the live-preview text of every workspace into a directory (`ws.<name>` files).
#   Each preview shows the path and, per .conf file, each section with `user@address:port`. One awk
#   pass reads all the files and decodes only those three ASCII fields, so a list of many
#   workspaces stays fast (no process is started per value). Nothing secret is shown.
# @arg $1 string The workspace base directory.
# @arg $2 string The output directory.
# @exitcode 0 Written.
# @example
#   _shell::workspace::ws::previews "$SHELL_WORKSPACE_DIR" "$work/w"
#
_shell::workspace::ws::previews() {
	local base="${1-}" out="${2-}" ws esc dim rst
	base="${base%/}"
	esc="$(printf '\033')"
	dim="${esc}[2m"
	rst="${esc}[0m"
	mkdir -p "$out" || return "$RETURN_FAILURE"

	# A header for every workspace, also those without a .conf file.
	while IFS= read -r ws; do
		[ -n "$ws" ] || continue
		{
			printf '%s%-9s%s %s\n' "$dim" "workspace" "$rst" "$ws"
			printf '%s%-9s%s %s\n' "$dim" "path" "$rst" "$base/$ws"
		} >"$out/ws.$ws"
	done < <(find "$base" -mindepth 1 -maxdepth 1 -type d | xargs -n 1 basename)

	find "$base" -mindepth 3 -maxdepth 3 -path '*/.ssh/*.conf' -type f 2>/dev/null | sort | tr '\n' '\0' |
		xargs -0 awk -v base="$base" -v out="$out" -v e="$esc" '
			BEGIN {
				chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
				for (i = 1; i <= 64; i++) tbl[substr(chars, i, 1)] = i - 1
				dim = e "[2m"; yel = e "[33m"; rst = e "[0m"
			}
			# Decode ASCII Base64; anything else becomes "?" (the key browser decodes the rest).
			function b64d(s,   i, n, a, b, c, d, v, r, x) {
				r = ""; n = length(s)
				for (i = 1; i + 3 <= n; i += 4) {
					a = tbl[substr(s, i, 1)]; b = tbl[substr(s, i + 1, 1)]
					c = substr(s, i + 2, 1); d = substr(s, i + 3, 1)
					v = a * 262144 + b * 4096 + (c == "=" ? 0 : tbl[c] * 64) + (d == "=" ? 0 : tbl[d])
					x = int(v / 65536); if (x > 127) return "?"; r = r sprintf("%c", x)
					if (c != "=") { x = int(v / 256) % 256; if (x > 127) return "?"; r = r sprintf("%c", x) }
					if (d != "=") { x = v % 256; if (x > 127) return "?"; r = r sprintf("%c", x) }
				}
				return r
			}
			function flush() {
				if (section != "" && (addr port user) != "")
					print "  " dim "[" section "]" rst " " (user == "" ? "-" : user) "@" (addr == "" ? "-" : addr) ":" (port == "" ? "-" : port) >> dest
				section = ""; addr = ""; port = ""; user = ""
			}
			FNR == 1 {
				flush()
				rest = substr(FILENAME, length(base) + 2)
				ws = substr(rest, 1, index(rest, "/") - 1)
				fname = FILENAME; sub(/.*\//, "", fname)
				dest = out "/ws." ws
				print "\n" yel fname rst >> dest
			}
			{ sub(/\r$/, ""); sub(/^[ \t]+/, ""); sub(/[ \t]+$/, "") }
			/^[#;]/ || $0 == "" { next }
			/^\[.*\]$/ { flush(); section = substr($0, 2, length($0) - 2); next }
			{
				i = index($0, "="); if (!i) next
				k = substr($0, 1, i - 1); sub(/[ \t]+$/, "", k)
				v = substr($0, i + 1); sub(/^[ \t]+/, "", v); gsub(/"/, "", v)
				if (k == "SSH_SERVER_ADDR") addr = b64d(v)
				else if (k == "SSH_SERVER_PORT") port = b64d(v)
				else if (k == "SSH_SERVER_USER") user = b64d(v)
			}
			END { flush() }
		'
	printf '%sGo back without changing anything%s\n' "$dim" "$rst" >"$out/ws.@back"
}

# @description Live hub for workspaces: pick one, run an action, come back to the list (loop).
#
#   Lists the workspaces under $SHELL_WORKSPACE_DIR with a live preview (path, .conf files and each
#   section's `user@address:port`). Enter opens an action menu: view, edit, rename, remove, clone or
#   copy path. View and edit are the live browsers of shell::workspace::view::fzf and
#   shell::workspace::edit::fzf (copy, edit and back all loop inside them). When an action finishes the
#   workspace list is shown again with the cursor on the same workspace, so the flow is
#   list -> action -> list. It ends only with ESC / Ctrl-C or "← Back" (SHELL_FZF_BACK_LABEL) at the
#   workspace list; Back at the action menu returns to the list. Remove, rename and clone keep their
#   confirmations, and Back never changes anything.
# @option -n Optional dry-run flag. If provided, actions that support dry-run will be executed in dry-run mode.
# @exitcode 0 Success (closed with ESC / Ctrl-C).
# @exitcode 1 The workspace directory is missing, or no workspace exists.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @see shell::workspace::view::fzf
# @see shell::workspace::edit::fzf
# @example
#   shell::workspace::manage::fzf
#   shell::workspace::manage::fzf -n
#
shell::workspace::manage::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Live hub for workspaces: preview, view, edit, rename, remove, clone, copy path (loops back to the list)"
		shell::logger::usage "shell::workspace::manage::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, actions that support dry-run will be executed in dry-run mode."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::note "The list comes back after every action; leave with ESC or '$SHELL_FZF_BACK_LABEL' (returns ${RETURN_BACK})."
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# The base directory for workspaces must exist.
	local base="$SHELL_WORKSPACE_DIR"
	if [ ! -d "$base" ]; then
		shell::logger::error "Workspace directory '$base' not found."
		return 1
	fi

	shell::dependency::fzf::ensure

	local work rc=0
	work="$(mktemp -d "${TMPDIR:-/tmp}/shell-workspace.XXXXXX")" || {
		shell::logger::error "Could not create a temporary directory."
		return 1
	}
	_shell::workspace::manage::loop "$dry_run" "$base" "$work" || rc=$?
	rm -rf "$work"
	return "$rc"
}

# @internal
# @description The loop of shell::workspace::manage::fzf: workspace list -> action menu -> list.
# @arg $1 string `true` for dry-run.
# @arg $2 string The workspace base directory.
# @arg $3 string Work directory for the previews.
# @exitcode 0 The user left with ESC / Ctrl-C.
# @exitcode 1 No workspace exists.
# @exitcode 11 The user picked "← Back" at the workspace list.
# @example
#   _shell::workspace::manage::loop false "$SHELL_WORKSPACE_DIR" "$work"
#
_shell::workspace::manage::loop() {
	local dry_run="${1-false}" base="${2-}" work="${3-}"
	local back="$SHELL_FZF_BACK_LABEL" tab=$'\t'
	local ws_list ws picked rc idx selected action new_name first="true"
	local -a init=() flag=()
	[ "$dry_run" = "true" ] && flag=(-n)

	while true; do
		ws_list="$(find "$base" -mindepth 1 -maxdepth 1 -type d | xargs -n 1 basename | sort)"
		if [ -z "$ws_list" ]; then
			if [ "$first" = "true" ]; then
				shell::logger::error "No workspace selected."
				return 1
			fi
			shell::logger::info "No workspace left"
			return "$RETURN_SUCCESS"
		fi
		first="false"

		rm -rf "$work/w"
		_shell::workspace::ws::previews "$base" "$work/w" || return 1
		: >"$work/rows"
		while IFS= read -r ws; do
			printf '%s\t%s\n' "$ws" "$ws" >>"$work/rows"
		done <<<"$ws_list"

		picked="$({
			cat "$work/rows"
			printf '%s\t%s\n' "$back" "@back"
		} | shell::fzf::select ${init[@]+"${init[@]}"} \
			--prompt="Workspace: " \
			--header="Enter: actions   ESC: leave   ${back}: previous" \
			--delimiter="$tab" --with-nth=1 --initial-field 1 \
			--preview="cat '$work'/w/ws.{2}" --preview-window="right:60%:wrap" \
			--height=60%)"
		rc=$?
		if [ "$rc" -ne 0 ] || [ -z "$picked" ]; then
			shell::logger::info "Closed"
			return "$RETURN_SUCCESS"
		fi
		selected="${picked%%"$tab"*}"
		idx="${picked##*"$tab"}"
		if [ "$idx" = "@back" ]; then
			shell::logger::info "Back — nothing was changed"
			return "$RETURN_BACK"
		fi
		init=(--initial "$selected")

		action="$(printf '%s\n' view edit rename remove clone "copy path" "$back" | shell::fzf::select \
			--prompt="Action: " \
			--header="Workspace ${selected}" \
			--height=40%)"
		rc=$?
		if [ "$rc" -ne 0 ] || [ -z "$action" ]; then
			shell::logger::info "Closed"
			return "$RETURN_SUCCESS"
		fi
		if [ "$action" = "$back" ]; then
			continue
		fi

		# Each action runs in this shell and then the workspace list comes back.
		case "$action" in
		view)
			shell::workspace::view::fzf ${flag[@]+"${flag[@]}"} "$selected" || true
			;;
		edit)
			shell::workspace::edit::fzf ${flag[@]+"${flag[@]}"} "$selected" || true
			;;
		rename)
			shell::console::print "[e] Enter new name for workspace '$selected':" 208
			read -r new_name
			if [ -z "$new_name" ]; then
				shell::logger::error "No new name entered. Aborting rename."
			else
				shell::workspace::rename ${flag[@]+"${flag[@]}"} "$selected" "$new_name" || true
				[ "$dry_run" = "true" ] || init=(--initial "$(shell::strings::sanitize::lower "$new_name")")
			fi
			;;
		remove)
			shell::workspace::remove ${flag[@]+"${flag[@]}"} "$selected" || true
			;;
		clone)
			shell::console::print "[e] Enter new name for cloned workspace from '$selected':" 208
			read -r new_name
			if [ -z "$new_name" ]; then
				shell::logger::error "No new name entered. Aborting clone."
			else
				shell::workspace::clone ${flag[@]+"${flag[@]}"} "$selected" "$new_name" || true
			fi
			;;
		"copy path")
			_shell::workspace::copy "the path of workspace ${selected}" "$base/$selected" "$dry_run" || true
			;;
		*)
			shell::logger::error "Invalid action."
			;;
		esac
	done
}

# @description Clones an existing workspace to a new workspace directory.
#
#   This function clones a workspace directory under $SHELL_WORKSPACE_DIR
#   from <source_workspace> to <destination_workspace>. It checks for the existence of the source
#   and ensures the destination does not already exist. If valid, it copies the entire directory.
# @option -n Optional dry-run flag. If provided, the clone command is printed using shell::logger::command_clip instead of executed.
# @arg $1 string source_workspace: The name of the existing workspace to clone.
# @arg $2 string destination_workspace: The name of the new workspace to create.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::workspace::clone dxc dxc-clone
#   shell::workspace::clone -n dxc dxc-clone
#
shell::workspace::clone() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Clones an existing workspace to a new workspace directory"
		shell::logger::usage "shell::workspace::clone [-n] [-h] <source_workspace> <destination_workspace>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the clone command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "source_workspace" "The name of the existing workspace to clone."
		shell::logger::item "destination_workspace" "The name of the new workspace to create."
		return $RETURN_SUCCESS
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
		echo "Usage: shell::workspace::clone [-n] <source_workspace> <destination_workspace>"
		return 1
	fi

	local source="$1"
	local destination="$2"

	# Sanitize the source and destination workspace names
	# We use shell::strings::sanitize::lower to ensure the names are in lowercase and safe for use as directory names
	# This function replaces non-alphanumeric characters with underscores
	source=$(shell::strings::sanitize::lower "$source")
	destination=$(shell::strings::sanitize::lower "$destination")

	local base="$SHELL_WORKSPACE_DIR"
	local source_dir="$base/$source"
	local destination_dir="$base/$destination"

	# Check if the source workspace exists and the destination does not
	# We check if the source directory exists and if the destination directory does not
	# If the source directory does not exist, we print an error message and return
	# If the destination directory already exists, we print an error message and return
	if [ ! -d "$source_dir" ]; then
		shell::logger::error "Source workspace '$source' does not exist at '$source_dir'"
		return 1
	fi

	# Check if the destination workspace already exists
	# If the destination directory already exists, we print an error message and return
	# This prevents overwriting an existing workspace
	if [ -d "$destination_dir" ]; then
		shell::logger::error "Destination workspace '$destination' already exists at '$destination_dir'"
		return 1
	fi

	# Construct the command to clone the workspace directory
	# We use cp -r to recursively copy the source directory to the destination directory
	# This effectively clones the workspace
	local cmd="cp -r \"$source_dir\" \"$destination_dir\""

	# If dry-run mode is enabled, we print the command instead of executing it
	# This allows us to see what would be done without making any changes
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
	else
		shell::exec::shell "$cmd"
		shell::permission::secure "$destination_dir"
		shell::logger::success "Workspace cloned from '$source' to '$destination'"
	fi
}

# @description Interactively selects a workspace using fzf and clones it to a new workspace.
#
#   This function lists all workspace directories under $SHELL_WORKSPACE_DIR,
#   uses fzf to let the user select one, prompts for a new name, and then calls shell::workspace::clone
#   to clone the selected workspace.
#   Every menu ends with a "← Back" entry (SHELL_FZF_BACK_LABEL); picking it steps back one level and changes nothing.
# @option -n Optional dry-run flag. If provided, the clone command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::workspace::clone::fzf
#
shell::workspace::clone::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a workspace using fzf and clones it to a new workspace"
		shell::logger::usage "shell::workspace::clone::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the clone command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check if the workspace directory exists
	# We check if the base directory for workspaces exists
	# If it does not exist, we print an error message and return
	local base="$SHELL_WORKSPACE_DIR"
	if [ ! -d "$base" ]; then
		shell::logger::error "Workspace directory '$base' not found."
		return 1
	fi

	# Ensure fzf is installed
	shell::dependency::fzf::ensure

	# List all workspace directories and use fzf to select one
	# We use find to locate directories under the workspace directory
	# We use xargs to convert the output of find into a list of directory names
	# We use fzf to let the user select one of the directories
	local selected ws_list
	ws_list=$(find "$base" -mindepth 1 -maxdepth 1 -type d | xargs -n 1 basename)
	if [ -z "$ws_list" ]; then
		shell::logger::error "No workspace selected."
		return 1
	fi
	selected=$(printf '%s\n%s\n' "$ws_list" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --prompt="Select workspace to clone: ")

	# Check if a workspace was selected
	# If no workspace was selected, we print an error message and return
	# This ensures the user knows they need to select a workspace
	# We check if the selected variable is empty
	# If it is empty, we print an error message and return
	if [ -z "$selected" ]; then
		shell::logger::error "No workspace selected."
		return 1
	fi

	if [ "$selected" = "$SHELL_FZF_BACK_LABEL" ]; then
		shell::logger::info "Back — nothing was cloned"
		return "$RETURN_BACK"
	fi

	shell::console::print "[e] Enter new name for cloned workspace of '$selected':" 208
	read -r new_name

	# Check if a new name was entered
	# If no new name was entered, we print an error message and return
	# This ensures the user knows they need to provide a new name
	if [ -z "$new_name" ]; then
		shell::logger::error "No new name entered. Aborting clone."
		return 1
	fi

	# If dry mode is enabled, we print the command to clone the workspace
	# This allows us to see what would be done without actually cloning anything
	if [ "$dry_run" = "true" ]; then
		shell::workspace::clone -n "$selected" "$new_name"
	else
		shell::workspace::clone "$selected" "$new_name"
	fi
}

# @description Interactively selects a workspace, section, and fields to export as JSON from .ssh/*.conf files.
#
#   This function uses fzf to let the user select a workspace, then a section (e.g., [dev], [uat]),
#   and then one or more fields to export. It reads values from .ssh/*.conf files and outputs a JSON
#   structure to the terminal and copies it to the clipboard.
#   Every menu ends with a "← Back" entry (SHELL_FZF_BACK_LABEL); picking it steps back one level and changes nothing.
# @option -h Show help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::workspace::dump::json
#
shell::workspace::dump::json() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a workspace, section, and fields to export as JSON from .ssh/*.conf files"
		shell::logger::usage "shell::workspace::dump::json [-h]"
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	# Ensure fzf is installed
	shell::dependency::fzf::ensure

	# Check if the workspace directory exists
	# We check if the base directory for workspaces exists
	# If it does not exist, we print an error message and return
	local base="$SHELL_WORKSPACE_DIR"
	if [ ! -d "$base" ]; then
		shell::logger::error "Workspace directory '$base' not found."
		return 1
	fi

	# List all workspace directories and use fzf to select one
	# We use find to locate directories under the workspace directory
	# We use xargs to convert the output of find into a list of directory names
	# Two levels: "Back" at the .conf menu returns to the workspace menu,
	# "Back" at the workspace menu leaves the function.
	local workspace conf_file ws_list conf_list ssh_dir
	while true; do
		ws_list=$(find "$base" -mindepth 1 -maxdepth 1 -type d | xargs -n 1 basename)

		# If no workspace was selected, we print an error message and return
		if [ -z "$ws_list" ]; then
			shell::logger::error "No workspace selected."
			return 1
		fi
		workspace=$(printf '%s\n%s\n' "$ws_list" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --prompt="Select workspace: ")
		if [ -z "$workspace" ]; then
			shell::logger::error "No workspace selected."
			return 1
		fi
		if [ "$workspace" = "$SHELL_FZF_BACK_LABEL" ]; then
			shell::logger::info "Back — nothing was exported"
			return "$RETURN_BACK"
		fi

		# Check if the selected workspace has a .ssh directory
		ssh_dir="$base/$workspace/.ssh"
		if [ ! -d "$ssh_dir" ]; then
			shell::logger::error "Workspace '$workspace' has no .ssh directory."
			return 1
		fi

		# Find all .conf files in the .ssh directory
		conf_list=$(find "$ssh_dir" -type f -name "*.conf")
		if [ -z "$conf_list" ]; then
			shell::logger::error "No .conf file selected."
			return 1
		fi
		conf_file=$(printf '%s\n%s\n' "$conf_list" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --prompt="Select .conf file to export: ")

		# If no .conf file was selected, we print an error message and return
		if [ -z "$conf_file" ]; then
			shell::logger::error "No .conf file selected."
			return 1
		fi

		# Back to the workspace menu
		if [ "$conf_file" = "$SHELL_FZF_BACK_LABEL" ]; then
			continue
		fi
		break
	done

	# Check if the selected .conf file exists
	# We check if the conf_file exists
	# If the conf_file does not exist, we print an error message and return
	local sections
	sections=$(shell::ini::section::list "$conf_file" |
		fzf --multi --prompt="Select sections to export: ")

	# Check if a section was selected
	# If no section was selected, we print an error message and return
	# This ensures the user knows they need to select a section
	# We check if the section variable is empty
	if [ -z "$sections" ]; then
		shell::logger::error "No sections selected."
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
	#     shell::logger::error "No fields selected. Aborting."
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
	# We use shell::ini::read to read the values for each field
	# We use shell::strings::sanitize::lower to ensure the keys are valid JSON keys
	# We build the JSON string incrementally
	# local json="{ \"$workspace\": { \"$config_name\": {"
	# local first_section=1
	# while IFS= read -r section; do
	#     [ $first_section -eq 0 ] && json+=","
	#     json+=" \"$section\": {"
	#     local first_field=1
	#     while IFS= read -r key; do
	#         local value
	#         # value=$(shell::ini::read "$conf_file" "$section" "$key" 2>/dev/null)
	#         # value=$(shell::ini::read "$conf_file" "$section" "$key" 2>/dev/null | tail -n 1)
	#         value=$(shell::ini::read "$conf_file" "$section" "$key" 2>/dev/null | sed 's/^value=//')
	#         [ $first_field -eq 0 ] && json+=","
	#         key=$(shell::strings::sanitize::lower "$key") # Ensure the key is a valid JSON key
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
		# We use shell::ini::key::list to get the keys in the section
		# If no keys are found, we print a warning and skip to the next section
		# We use shell::ini::key::list to get the keys in the section
		# If no keys are found, we print a warning and skip to the next section
		local keys
		keys=$(shell::ini::key::list "$conf_file" "$section")
		if [ -z "$keys" ]; then
			shell::logger::warn "No keys found in section '$section'"
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
			shell::logger::warn "No keys selected in section '$section'. Skipping."
			continue
		fi

		local first_field=1
		while IFS= read -r key; do
			local value
			value=$(shell::ini::read "$conf_file" "$section" "$key" 2>/dev/null | sed 's/^value=//')
			[ $first_field -eq 0 ] && json+=","
			key=$(shell::strings::sanitize::lower "$key")
			json+=" \"$key\": \"${value}\""
			first_field=0
		done <<<"$selected_keys"

		json+=" }"
		first_section=0
	done <<<"$sections"
	json+=" } } }"

	shell::console::print "$json" 33
	shell::clipboard::copy --best-effort "$json"
}

# @description Opens an SSH tunnel using configuration from a workspace .ssh/*.conf file.
#
#   This function reads the [base] section first, then overrides with values from the specified section.
#   It delegates the actual SSH tunnel execution to shell::ssh::tunnel::open.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip.
# @arg $1 string workspace_name: The name of the workspace.
# @arg $2 string conf_name: The name of the SSH configuration file (e.g., kafka.conf).
# @arg $3 string section: The section to use (e.g., dev, uat).
# @exitcode 0 Success.
# @example
#   shell::workspace::ssh::tunnel::open my-app kafka.conf dev
#   shell::workspace::ssh::tunnel::open -n my-app kafka.conf uat
#
shell::workspace::ssh::tunnel::open() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Opens an SSH tunnel using configuration from a workspace .ssh/*.conf file"
		shell::logger::usage "shell::workspace::ssh::tunnel::open [-n] [-h] <workspace_name> <conf_name> <section>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "workspace_name" "The name of the workspace."
		shell::logger::item "conf_name" "The name of the SSH configuration file (e.g., kafka.conf)."
		shell::logger::item "section" "The section to use (e.g., dev, uat)."
		shell::logger::example "shell::workspace::ssh::tunnel::open my-app db.conf dev"
		shell::logger::example "shell::workspace::ssh::tunnel::open -n my-app kafka.conf uat"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	if [ $# -ne 3 ]; then
		echo "Usage: shell::workspace::ssh::tunnel::open [-n] <workspace_name> <conf_name> <section>"
		return 0
	fi

	local workspace="$1"
	if [ -z "$workspace" ]; then
		shell::logger::error "Workspace name is required."
		return 0
	fi
	local conf_name="$2"
	if [ -z "$conf_name" ]; then
		shell::logger::error "Configuration name is required."
		return 0
	fi
	local section="$3"
	if [ -z "$section" ]; then
		shell::logger::error "Section name is required."
		return 0
	fi

	# Sanitize the workspace name and section name
	# We use shell::strings::sanitize::lower to ensure the names are in lowercase and safe for use as directory names
	workspace=$(shell::strings::sanitize::lower "$workspace")
	section=$(shell::strings::sanitize::lower "$section")

	local conf_path="$SHELL_WORKSPACE_DIR/$workspace/.ssh/$conf_name"

	# We check if the base directory for workspaces exists
	# If it does not exist, we print an error message and return
	if [ ! -f "$conf_path" ]; then
		shell::logger::error "Configuration file '$conf_path' not found."
		return 0
	fi

	# Check if the section exists in the configuration file
	# We use shell::ini::section::exists to check if the specified section exists in the configuration file
	# If the section does not exist, we print an error message and return
	if ! shell::ini::section::exists "$conf_path" "$section" >/dev/null 2>&1; then
		shell::logger::error "Section ('$section') not found in file: $file"
		return 0
	fi

	# Load base values
	# We read the base section of the configuration file
	# This function reads the base section first, then overrides with values from the specified section
	local base_section="base"
	local timeout=$(shell::ini::read "$conf_path" "$base_section" SSH_TIMEOUT_SEC)
	local alive_interval=$(shell::ini::read "$conf_path" "$base_section" SSH_SERVER_ALIVE_INTERVAL_SEC)

	# Load section overrides
	local local_port=$(shell::ini::read "$conf_path" "$section" SSH_LOCAL_PORT)
	local target_addr=$(shell::ini::read "$conf_path" "$section" SSH_SERVER_TARGET_SERVICE_ADDR)
	local target_port=$(shell::ini::read "$conf_path" "$section" SSH_SERVER_TARGET_SERVICE_PORT)
	local server_desc=$(shell::ini::read "$conf_path" "$section" SSH_DESC)
	local server_file=$(shell::ini::read "$conf_path" "$section" SSH_PRIVATE_KEY_REF)
	local server_user=$(shell::ini::read "$conf_path" "$section" SSH_SERVER_USER)
	local server_addr=$(shell::ini::read "$conf_path" "$section" SSH_SERVER_ADDR)
	local server_port=$(shell::ini::read "$conf_path" "$section" SSH_SERVER_PORT)

	# Check if the dry-mode is enabled
	# If dry-run mode is enabled, we print the command instead of executing it
	# This allows us to see what would be done without actually opening the SSH tunnel
	if [ "$dry_run" = "true" ]; then
		shell::logger::debug "Opening SSH tunnel for '$server_desc' at $server_addr:$server_port"
		shell::ssh::tunnel::open -n "$server_file" "$local_port" "$target_addr" "$target_port" "$server_user" "$server_addr" "$server_port" "$alive_interval" "$timeout"
	else
		shell::logger::success "Opening SSH tunnel for '$server_desc' at $server_addr:$server_port"
		shell::ssh::tunnel::open "$server_file" "$local_port" "$target_addr" "$target_port" "$server_user" "$server_addr" "$server_port" "$alive_interval" "$timeout"
	fi
}

# @description Interactively selects a workspace and SSH config section to open an SSH tunnel.
#
#   Uses fzf to select a workspace and a .conf file, then selects a section (dev or uat),
#   and opens an SSH tunnel using shell::workspace::ssh::tunnel::open.
#   Every menu ends with a "← Back" entry (SHELL_FZF_BACK_LABEL); picking it steps back one level and changes nothing.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip.
# @exitcode 0 Success.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::workspace::ssh::tunnel::open::fzf
#   shell::workspace::ssh::tunnel::open::fzf -n
#
shell::workspace::ssh::tunnel::open::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a workspace and SSH config section to open an SSH tunnel"
		shell::logger::usage "shell::workspace::ssh::tunnel::open::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::workspace::ssh::tunnel::open::fzf"
		shell::logger::example "shell::workspace::ssh::tunnel::open::fzf -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Ensure the fzf package is installed
	shell::dependency::fzf::ensure

	# Three levels: "Back" at the section menu returns to the .conf menu, "Back" at
	# the .conf menu returns to the workspace menu, "Back" at the workspace menu
	# leaves the function.
	local workspace conf_file section ws_list conf_list ssh_dir picked step="workspace"
	while true; do
		case "$step" in
		workspace)
			ws_list=$(find "$SHELL_WORKSPACE_DIR" -mindepth 1 -maxdepth 1 -type d | xargs -n 1 basename)

			# If no workspace was selected, we print an error message and return
			# This ensures the user knows they need to select a workspace
			if [ -z "$ws_list" ]; then
				shell::logger::error "No workspace selected."
				return 0
			fi
			picked=$(printf '%s\n%s\n' "$ws_list" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --prompt="Select workspace: ")
			if [ -z "$picked" ]; then
				shell::logger::error "No workspace selected."
				return 0
			fi
			if [ "$picked" = "$SHELL_FZF_BACK_LABEL" ]; then
				shell::logger::info "Back — no tunnel was changed"
				return "$RETURN_BACK"
			fi
			workspace="$picked"

			# Check if the selected workspace has a .ssh directory
			ssh_dir="$SHELL_WORKSPACE_DIR/$workspace/.ssh"
			if [ ! -d "$ssh_dir" ]; then
				shell::logger::error "Workspace '$workspace' has no .ssh directory."
				return 0
			fi
			step="conf"
			;;
		conf)
			# Find all .conf files in the .ssh directory
			conf_list=$(find "$ssh_dir" -type f -name "*.conf" | xargs -n 1 basename)
			if [ -z "$conf_list" ]; then
				shell::logger::error "No config file selected."
				return 0
			fi
			picked=$(printf '%s\n%s\n' "$conf_list" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --prompt="Select SSH config file: ")
			if [ -z "$picked" ]; then
				shell::logger::error "No config file selected."
				return 0
			fi
			if [ "$picked" = "$SHELL_FZF_BACK_LABEL" ]; then
				step="workspace"
				continue
			fi
			conf_file="$picked"
			step="section"
			;;
		section)
			picked=$(printf '%s\n%s\n%s\n' "dev" "uat" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --prompt="Select section: ")
			if [ -z "$picked" ]; then
				shell::logger::error "No section selected."
				return 0
			fi
			if [ "$picked" = "$SHELL_FZF_BACK_LABEL" ]; then
				step="conf"
				continue
			fi
			section="$picked"
			break
			;;
		esac
	done

	# Check if the dry-mode is enabled
	# If dry-run mode is enabled, we print the command instead of executing it
	# This allows us to see what would be done without actually opening the SSH tunnel
	if [ "$dry_run" = "true" ]; then
		shell::workspace::ssh::tunnel::open -n "$workspace" "$conf_file" "$section"
	else
		shell::workspace::ssh::tunnel::open "$workspace" "$conf_file" "$section"
	fi
}

# @description Opens an SSH tunnel using configuration from a workspace .ssh/*.conf file, with tuning options.
#
#   This function reads the [base] section first, then overrides with values from the specified section.
#   It delegates the actual SSH tunnel execution to shell::ssh::tunnel::tune.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip.
# @arg $1 string workspace_name: The name of the workspace.
# @arg $2 string conf_name: The name of the SSH configuration file (e.g., kafka.conf).
# @arg $3 string section: The section to use (e.g., dev, uat).
# @exitcode 0 Success.
# @example
#   shell::workspace::ssh::tunnel::tune my-app kafka.conf dev
#   shell::workspace::ssh::tunnel::tune -n my-app kafka.conf uat
#
shell::workspace::ssh::tunnel::tune() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Opens an SSH tunnel using configuration from a workspace .ssh/*.conf file, with tuning options"
		shell::logger::usage "shell::workspace::ssh::tunnel::tune [-n] [-h] <workspace_name> <conf_name> <section>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "workspace_name" "The name of the workspace."
		shell::logger::item "conf_name" "The name of the SSH configuration file (e.g., kafka.conf)."
		shell::logger::item "section" "The section to use (e.g., dev, uat)."
		shell::logger::example "shell::workspace::ssh::tunnel::tune my-app kafka.conf dev"
		shell::logger::example "shell::workspace::ssh::tunnel::tune -n my-app kafka.conf uat"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	if [ $# -ne 3 ]; then
		echo "Usage: shell::workspace::ssh::tunnel::tune [-n] <workspace_name> <conf_name> <section>"
		return 0
	fi

	local workspace="$1"
	if [ -z "$workspace" ]; then
		shell::logger::error "Workspace name is required."
		return 0
	fi
	local conf_name="$2"
	if [ -z "$conf_name" ]; then
		shell::logger::error "Configuration name is required."
		return 0
	fi
	local section="$3"
	if [ -z "$section" ]; then
		shell::logger::error "Section name is required."
		return 0
	fi

	# Sanitize the workspace name and section name
	# We use shell::strings::sanitize::lower to ensure the names are in lowercase and safe for use as directory names
	workspace=$(shell::strings::sanitize::lower "$workspace")
	section=$(shell::strings::sanitize::lower "$section")

	local conf_path="$SHELL_WORKSPACE_DIR/$workspace/.ssh/$conf_name"

	# We check if the base directory for workspaces exists
	# If it does not exist, we print an error message and return
	if [ ! -f "$conf_path" ]; then
		shell::logger::error "Configuration file '$conf_path' not found."
		return 0
	fi

	# Check if the section exists in the configuration file
	# We use shell::ini::section::exists to check if the specified section exists in the configuration file
	# If the section does not exist, we print an error message and return
	if ! shell::ini::section::exists "$conf_path" "$section" >/dev/null 2>&1; then
		shell::logger::error "Section ('$section') not found in file: $file"
		return 0
	fi

	# Load section overrides
	local server_desc=$(shell::ini::read "$conf_path" "$section" SSH_DESC)
	local server_file=$(shell::ini::read "$conf_path" "$section" SSH_PRIVATE_KEY_REF)
	local server_user=$(shell::ini::read "$conf_path" "$section" SSH_SERVER_USER)
	local server_addr=$(shell::ini::read "$conf_path" "$section" SSH_SERVER_ADDR)
	local server_port=$(shell::ini::read "$conf_path" "$section" SSH_SERVER_PORT)

	# Check if the dry-mode is enabled
	# If dry-run mode is enabled, we print the command instead of executing it
	# This allows us to see what would be done without actually opening the SSH tunnel
	if [ "$dry_run" = "true" ]; then
		shell::logger::debug "Tunning SSH tunnel for '$server_desc' at $server_addr:$server_port"
		shell::ssh::tunnel::tune -n "$server_file" "$server_user" "$server_addr" "$server_port"
	else
		shell::logger::success "Tunning SSH tunnel for '$server_desc' at $server_addr:$server_port"
		shell::ssh::tunnel::tune "$server_file" "$server_user" "$server_addr" "$server_port"
	fi
}

# @description Interactively selects a workspace and SSH config section to tune an SSH tunnel.
#
#   Uses fzf to select a workspace and a .conf file, then selects a section (dev or uat),
#   and tunes an SSH tunnel using shell::workspace::ssh::tunnel::tune.
#   Every menu ends with a "← Back" entry (SHELL_FZF_BACK_LABEL); picking it steps back one level and changes nothing.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip.
# @exitcode 0 Success.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::workspace::ssh::tunnel::tune::fzf
#
shell::workspace::ssh::tunnel::tune::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a workspace and SSH config section to tune an SSH tunnel"
		shell::logger::usage "shell::workspace::ssh::tunnel::tune::fzf [-n]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip."
		shell::logger::option "-h, --help" "Display this help message"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Ensure the fzf package is installed
	shell::dependency::fzf::ensure

	# Three levels: "Back" at the section menu returns to the .conf menu, "Back" at
	# the .conf menu returns to the workspace menu, "Back" at the workspace menu
	# leaves the function.
	local workspace conf_file section ws_list conf_list ssh_dir picked step="workspace"
	while true; do
		case "$step" in
		workspace)
			ws_list=$(find "$SHELL_WORKSPACE_DIR" -mindepth 1 -maxdepth 1 -type d | xargs -n 1 basename)

			# If no workspace was selected, we print an error message and return
			# This ensures the user knows they need to select a workspace
			if [ -z "$ws_list" ]; then
				shell::logger::error "No workspace selected."
				return 0
			fi
			picked=$(printf '%s\n%s\n' "$ws_list" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --prompt="Select workspace: ")
			if [ -z "$picked" ]; then
				shell::logger::error "No workspace selected."
				return 0
			fi
			if [ "$picked" = "$SHELL_FZF_BACK_LABEL" ]; then
				shell::logger::info "Back — no tunnel was changed"
				return "$RETURN_BACK"
			fi
			workspace="$picked"

			# Check if the selected workspace has a .ssh directory
			ssh_dir="$SHELL_WORKSPACE_DIR/$workspace/.ssh"
			if [ ! -d "$ssh_dir" ]; then
				shell::logger::error "Workspace '$workspace' has no .ssh directory."
				return 0
			fi
			step="conf"
			;;
		conf)
			# Find all .conf files in the .ssh directory
			conf_list=$(find "$ssh_dir" -type f -name "*.conf" | xargs -n 1 basename)
			if [ -z "$conf_list" ]; then
				shell::logger::error "No config file selected."
				return 0
			fi
			picked=$(printf '%s\n%s\n' "$conf_list" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --prompt="Select SSH config file: ")
			if [ -z "$picked" ]; then
				shell::logger::error "No config file selected."
				return 0
			fi
			if [ "$picked" = "$SHELL_FZF_BACK_LABEL" ]; then
				step="workspace"
				continue
			fi
			conf_file="$picked"
			step="section"
			;;
		section)
			picked=$(printf '%s\n%s\n%s\n' "dev" "uat" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --prompt="Select section: ")
			if [ -z "$picked" ]; then
				shell::logger::error "No section selected."
				return 0
			fi
			if [ "$picked" = "$SHELL_FZF_BACK_LABEL" ]; then
				step="conf"
				continue
			fi
			section="$picked"
			break
			;;
		esac
	done

	# Check if the dry-mode is enabled
	# If dry-run mode is enabled, we print the command instead of executing it
	# This allows us to see what would be done without actually opening the SSH tunnel
	if [ "$dry_run" = "true" ]; then
		shell::workspace::ssh::tunnel::tune -n "$workspace" "$conf_file" "$section"
	else
		shell::workspace::ssh::tunnel::tune "$workspace" "$conf_file" "$section"
	fi
}
