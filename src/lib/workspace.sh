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
# @option -n Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
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
	# We use fzf to allow the user to select a workspace interactively
	local workspace
	workspace=$(find "$base" -mindepth 1 -maxdepth 1 -type d | xargs -n 1 basename | fzf --prompt="Select workspace: ")

	# If no workspace was selected, we print an error message and return
	# This ensures the user knows they need to select a workspace
	if [ -z "$workspace" ]; then
		shell::logger::error "No workspace selected."
		return 1
	fi

	# Check if the selected workspace has a .ssh directory
	# We construct the path to the .ssh directory for the selected workspace
	local ssh_dir="$base/$workspace/.ssh"
	if [ ! -d "$ssh_dir" ]; then
		shell::logger::error "Workspace '$workspace' has no .ssh directory."
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
		shell::logger::success "All SSH config files already exist in workspace '$workspace'."
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
		shell::logger::error "No SSH config selected."
		return 1
	fi

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

# @description Interactively selects a .ssh/*.conf file from a workspace and previews it using shell::ini::view::fzf.
#
#   This function locates all .conf files under $SHELL_WORKSPACE_DIR/<workspace_name>/.ssh/,
#   and uses fzf to let the user select one. The selected file is then passed to shell::ini::view::fzf
#   for real-time preview of all decoded values.
# @arg $1 string workspace_name: The name of the workspace to view.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::workspace::view::fzf dxc
#
shell::workspace::view::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a .ssh/*.conf file from a workspace and previews it using shell::ini::view::fzf"
		shell::logger::usage "shell::workspace::view::fzf [-h] <workspace_name>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "workspace_name" "The name of the workspace to view."
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::workspace::view::fzf <workspace_name>"
		return 1
	fi

	local name="$1"

	# Sanitize the workspace name
	# We use shell::strings::sanitize::lower to ensure the name is in lowercase and safe for use as a directory name
	# This function replaces non-alphanumeric characters with underscores
	# This helps prevent issues with invalid directory names
	name=$(shell::strings::sanitize::lower "$name")

	local base="$SHELL_WORKSPACE_DIR"
	local ssh_dir="$base/$name/.ssh"

	# Check if workspace exists
	if [ ! -d "$ssh_dir" ]; then
		shell::logger::error "Workspace '$name' does not exist or has no .ssh directory."
		return 1
	fi

	# Find all .conf files in the .ssh directory
	local conf_files
	conf_files=$(find "$ssh_dir" -type f -name "*.conf")

	if [ -z "$conf_files" ]; then
		shell::logger::warn "No .conf files found in '$ssh_dir'"
		return 0
	fi

	# Ensure fzf is installed
	shell::dependency::fzf::ensure

	# Use fzf to select one of the .conf files
	local selected_file
	selected_file=$(echo "$conf_files" | fzf --prompt="Select a config file to view: ")

	# If no file was selected, we print an error message and return
	# This ensures the user knows they need to select a file
	if [ -z "$selected_file" ]; then
		shell::logger::error "No file selected."
		return 1
	fi

	shell::ini::view::fzf "$selected_file"
}

# @description Interactively selects a .ssh/*.conf file from a workspace and opens it for editing using shell::ini::edit::fzf.
#
#   This function locates all .conf files under $SHELL_WORKSPACE_DIR/<workspace_name>/.ssh/,
#   and uses fzf to let the user select one. The selected file is then passed to shell::ini::edit::fzf
#   for editing.
# @arg $1 string workspace_name: The name of the workspace to edit.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::workspace::edit::fzf dxc
#
shell::workspace::edit::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a .ssh/*.conf file from a workspace and opens it for editing using shell::ini::edit::fzf"
		shell::logger::usage "shell::workspace::edit::fzf [-h] <workspace_name>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "workspace_name" "The name of the workspace to edit."
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::workspace::edit::fzf <workspace_name>"
		return 1
	fi

	local name="$1"

	# Sanitize the workspace name
	# We use shell::strings::sanitize::lower to ensure the name is in lowercase and safe for use as a directory name
	# This function replaces non-alphanumeric characters with underscores
	# This helps prevent issues with invalid directory names
	name=$(shell::strings::sanitize::lower "$name")

	local base="$SHELL_WORKSPACE_DIR"
	local ssh_dir="$base/$name/.ssh"

	# Check if workspace exists
	if [ ! -d "$ssh_dir" ]; then
		shell::logger::error "Workspace '$name' does not exist or has no .ssh directory."
		return 1
	fi

	# Find all .conf files in the .ssh directory
	local conf_files
	conf_files=$(find "$ssh_dir" -type f -name "*.conf")

	if [ -z "$conf_files" ]; then
		shell::logger::warn "No .conf files found in '$ssh_dir'"
		return 0
	fi

	# Ensure fzf is installed
	shell::dependency::fzf::ensure

	# Use fzf to select one of the .conf files for editing
	local selected_file
	selected_file=$(echo "$conf_files" | fzf --prompt="Select a config file to edit: ")

	# If no file was selected, we print an error message and return
	if [ -z "$selected_file" ]; then
		shell::logger::error "No file selected."
		return 1
	fi

	# Call shell::ini::edit::fzf to edit the selected file
	shell::ini::edit::fzf "$selected_file"
}

# @description Interactively selects a workspace using fzf and removes it after confirmation.
#
#   This function lists all workspace directories under $SHELL_WORKSPACE_DIR,
#   uses fzf to let the user select one, and then calls shell::workspace::remove to delete it.
# @option -n Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
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
	local selected
	selected=$(find "$workspace_dir" -mindepth 1 -maxdepth 1 -type d |
		xargs -n 1 basename |
		fzf --prompt="Select workspace to remove: ")

	# If no workspace was selected, we print an error message and return
	if [ -z "$selected" ]; then
		shell::logger::error "No workspace selected."
		return 1
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
# @option -n Optional dry-run flag. If provided, the rename command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
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
		shell::logger::error "No workspace selected."
		return 1
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

# @description Interactively selects a workspace and performs an action (view, edit, rename, remove) using fzf.
#
#   This function lists all workspace directories under $SHELL_WORKSPACE_DIR,
#   uses fzf to let the user select one, then presents a list of actions to perform on the selected workspace.
#   Supported actions include: view, edit, rename, and remove.
# @option -n Optional dry-run flag. If provided, actions that support dry-run will be executed in dry-run mode.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::workspace::manage::fzf
#
shell::workspace::manage::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a workspace and performs an action (view, edit, rename, remove) using fzf"
		shell::logger::usage "shell::workspace::manage::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, actions that support dry-run will be executed in dry-run mode."
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
	local selected
	selected=$(find "$base" -mindepth 1 -maxdepth 1 -type d |
		xargs -n 1 basename |
		fzf --prompt="Select workspace: ")

	# Check if a workspace was selected
	# If no workspace was selected, we print an error message and return
	# This ensures the user knows they need to select a workspace
	if [ -z "$selected" ]; then
		shell::logger::error "No workspace selected."
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
		shell::logger::error "No action selected."
		return 1
	fi

	# Perform the selected action on the workspace
	# We use a case statement to determine which action was selected
	# Depending on the action, we call the appropriate function
	# If the action is 'view', we call shell::workspace::view::fzf
	# If the action is 'edit', we call shell::workspace::edit::fzf
	# If the action is 'rename', we call shell::workspace::rename
	# If the action is 'remove', we call shell::workspace::remove
	# If the action is not recognized, we print an error message and return
	case "$action" in
	view)
		shell::workspace::view::fzf "$selected"
		;;
	edit)
		shell::workspace::edit::fzf "$selected"
		;;
	rename)
		shell::console::print "[e] Enter new name for workspace '$selected':" 208
		read -r new_name
		# Check if a new name was entered
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
		;;
	remove)
		# If dry mode is enabled, we print the command to remove the workspace
		# This allows us to see what would be done without actually deleting anything
		if [ "$dry_run" = "true" ]; then
			shell::workspace::remove -n "$selected"
		else
			shell::workspace::remove "$selected"
		fi
		;;
	clone)
		# If the action is 'clone', we call shell::workspace::clone
		# We prompt for the new workspace name to clone to
		shell::console::print "[e] Enter new name for cloned workspace from '$selected':" 208
		read -r new_name
		# Check if a new name was entered
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
		;;
	*)
		shell::logger::error "Unknown action '$action'"
		return 1
		;;
	esac
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
# @option -n Optional dry-run flag. If provided, the clone command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
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
		shell::logger::error "No workspace selected."
		return 1
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
# @option -h Show help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
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
		shell::logger::error "No workspace selected."
		return 1
	fi

	# Check if the selected workspace has a .ssh directory
	# We check if the .ssh directory exists under the selected workspace
	# If the .ssh directory does not exist, we print an error message and return
	local ssh_dir="$base/$workspace/.ssh"
	if [ ! -d "$ssh_dir" ]; then
		shell::logger::error "Workspace '$workspace' has no .ssh directory."
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
		shell::logger::error "No .conf file selected."
		return 1
	fi

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
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip.
# @exitcode 0 Success.
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

	# Check if the workspace directory exists
	local workspace
	workspace=$(find "$SHELL_WORKSPACE_DIR" -mindepth 1 -maxdepth 1 -type d |
		xargs -n 1 basename |
		fzf --border=rounded --ansi --layout=reverse --pointer="▶" --marker="✓" --prompt="Select workspace: ")

	# Check if a workspace was selected
	# If no workspace was selected, we print an error message and return
	# This ensures the user knows they need to select a workspace
	if [ -z "$workspace" ]; then
		shell::logger::error "No workspace selected."
		return 0
	fi

	# Check if the selected workspace has a .ssh directory
	# We check if the .ssh directory exists under the selected workspace
	# If the .ssh directory does not exist, we print an error message and return
	local ssh_dir="$SHELL_WORKSPACE_DIR/$workspace/.ssh"
	if [ ! -d "$ssh_dir" ]; then
		shell::logger::error "Workspace '$workspace' has no .ssh directory."
		return 0
	fi

	# Find all .conf files in the .ssh directory
	# We use find to locate all .conf files under the .ssh directory
	# We use xargs to convert the output of find into a list of file names
	local conf_file
	conf_file=$(find "$ssh_dir" -type f -name "*.conf" |
		xargs -n 1 basename |
		fzf --border=rounded --ansi --layout=reverse --pointer="▶" --marker="✓" --prompt="Select SSH config file: ")

	if [ -z "$conf_file" ]; then
		shell::logger::error "No config file selected."
		return 0
	fi

	# Check if the selected .conf file exists
	local section
	section=$(printf "dev\nuat" | fzf --prompt="Select section: ")
	if [ -z "$section" ]; then
		shell::logger::error "No section selected."
		return 0
	fi

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
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip.
# @exitcode 0 Success.
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

	# Check if the workspace directory exists
	local workspace
	workspace=$(find "$SHELL_WORKSPACE_DIR" -mindepth 1 -maxdepth 1 -type d |
		xargs -n 1 basename |
		fzf --border=rounded --ansi --layout=reverse --pointer="▶" --marker="✓" --prompt="Select workspace: ")

	# Check if a workspace was selected
	# If no workspace was selected, we print an error message and return
	# This ensures the user knows they need to select a workspace
	if [ -z "$workspace" ]; then
		shell::logger::error "No workspace selected."
		return 0
	fi

	# Check if the selected workspace has a .ssh directory
	# We check if the .ssh directory exists under the selected workspace
	# If the .ssh directory does not exist, we print an error message and return
	local ssh_dir="$SHELL_WORKSPACE_DIR/$workspace/.ssh"
	if [ ! -d "$ssh_dir" ]; then
		shell::logger::error "Workspace '$workspace' has no .ssh directory."
		return 0
	fi

	# Find all .conf files in the .ssh directory
	# We use find to locate all .conf files under the .ssh directory
	# We use xargs to convert the output of find into a list of file names
	local conf_file
	conf_file=$(find "$ssh_dir" -type f -name "*.conf" |
		xargs -n 1 basename |
		fzf --border=rounded --ansi --layout=reverse --pointer="▶" --marker="✓" --prompt="Select SSH config file: ")

	if [ -z "$conf_file" ]; then
		shell::logger::error "No config file selected."
		return 0
	fi

	# Check if the selected .conf file exists
	local section
	section=$(printf "dev\nuat" | fzf --prompt="Select section: ")
	if [ -z "$section" ]; then
		shell::logger::error "No section selected."
		return 0
	fi

	# Check if the dry-mode is enabled
	# If dry-run mode is enabled, we print the command instead of executing it
	# This allows us to see what would be done without actually opening the SSH tunnel
	if [ "$dry_run" = "true" ]; then
		shell::workspace::ssh::tunnel::tune -n "$workspace" "$conf_file" "$section"
	else
		shell::workspace::ssh::tunnel::tune "$workspace" "$conf_file" "$section"
	fi
}
