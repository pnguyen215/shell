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
#   -n: Optional. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
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
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Retrieve GOPRIVATE setting"
		shell::logger::usage "shell::get_go_privates [-n] [-h]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::get_go_privates"
		shell::logger::example "shell::get_go_privates -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local cmd="go env GOPRIVATE"

	if [ "$dry_run" = "true" ]; then
		shell::logger::cmd_copy "$cmd"
		return $RETURN_SUCCESS
	fi

	shell::logger::exec_check "$cmd"
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
#   If provided, the command is printed using shell::logger::cmd_copy instead of executed.
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
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Set GOPRIVATE setting"
		shell::logger::usage "shell::set_go_privates [-n] <repository1> [repository2] ..."
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::set_go_privates \"example.com/private1\""
		shell::logger::example "shell::set_go_privates -n \"example.com/private1\" \"example.com/internal\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	# Join all repositories with a comma
	local repositories="$*"

	if [ -z "$repositories" ]; then
		shell::logger::error "No repositories provided."
		return $RETURN_FAILURE
	fi

	# If the repositories entered which length is greater than 1, then split by whitespace and join by comma
	if [ $(echo "$repositories" | wc -w) -gt 1 ]; then
		repositories=$(echo "$repositories" | tr ' ' ',')
	fi

	IFS=','
	unset IFS

	# Check if GOPRIVATE is already set
	local exists_privates=$(go env GOPRIVATE)

	if [ -n "$exists_privates" ]; then
		repositories="$exists_privates,$repositories"
	fi

	local cmd="go env -w GOPRIVATE=\"$repositories\""

	if [ "$dry_run" = "true" ]; then
		shell::logger::cmd_copy "$cmd"
		return $RETURN_SUCCESS
	fi

	shell::logger::exec_check "$cmd"
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
#   -n: Optional. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
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
#   - Supports dry-run and asynchronous execution via shell::logger::cmd_copy and shell::async.
#   - Compatible with both Linux (Ubuntu 22.04 LTS) and macOS.
shell::fzf_remove_go_privates() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Remove GOPRIVATE entries"
		shell::logger::usage "shell::fzf_remove_go_privates [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::fzf_remove_go_privates"
		shell::logger::example "shell::fzf_remove_go_privates -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	# Ensure fzf is installed
	shell::install_package fzf

	# Retrieve current GOPRIVATE value
	local current_goprivate=$(go env GOPRIVATE)
	if [ -z "$current_goprivate" ]; then
		shell::logger::warn "GOPRIVATE is not set. Nothing to remove."
		return $RETURN_EMPTY
	fi

	# Split GOPRIVATE into an array of entries
	local entries=($(echo "$current_goprivate" | tr ',' ' '))

	# Use fzf to select entries to remove (multi-select enabled)
	local selected=$(printf "%s\n" "${entries[@]}" | fzf --multi --prompt="Select entries to remove: ")
	if [ -z "$selected" ]; then
		shell::logger::warn "No entries selected for removal."
		return $RETURN_NOT_IMPLEMENTED
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
		shell::logger::cmd_copy "$cmd"
		return $RETURN_SUCCESS
	else
		shell::async "$cmd" &
		local pid=$!
		wait $pid
		if [ $? -eq 0 ]; then
			shell::logger::info "Removed selected entries from GOPRIVATE."
			return $RETURN_SUCCESS
		else
			shell::logger::error "Failed to update GOPRIVATE."
			return $RETURN_FAILURE
		fi
	fi
}

# shell::create_go_app function
# Creates a new Go application by initializing a Go module and tidying dependencies
# within a specified target folder.
#
# Usage:
#   shell::create_go_app [-n] <app_name|github_url> [target_folder]
#
# Parameters:
#   - -n : Optional dry-run flag.
#          If provided, the commands are printed using shell::logger::cmd_copy instead of being executed.
#   - <app_name|github_url> : The name of the application or a GitHub URL to initialize the module.
#   - [target_folder] : Optional. The path to the folder where the Go application should be created.
#                       If not provided, the application is created in the current directory.
#
# Description:
#   This function checks if the provided application name is a valid URL.
#   If it is, it extracts the module name from the URL.
#   If a target folder is specified, the function ensures the folder exists,
#   changes into that directory, initializes the Go module using `go mod init`,
#   and tidies the dependencies using `go mod tidy`.
#   After execution, it returns to the original directory.
#   In dry-run mode, the commands are displayed without execution.
#
# Example:
#   shell::create_go_app my_app                      # Initializes a Go module named 'my_app' in the current directory.
#   shell::create_go_app my_app /path/to/my/folder   # Initializes 'my_app' in the specified folder.
#   shell::create_go_app -n my_app                   # Previews the initialization commands without executing them.
#   shell::create_go_app -n my_app /tmp/go_projects  # Previews initialization in a target folder.
#   shell::create_go_app https://github.com/user/repo /home/user/src # Initializes from a GitHub URL in a target folder.
shell::create_go_app() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Create Go application"
		shell::logger::usage "shell::create_go_app [-n] [-h] <app_name|github_url> [target_folder]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::option "<app_name|github_url>" "The name of the application or a GitHub URL to initialize the module"
		shell::logger::option "[target_folder]" "Optional. The path to the folder where the Go application should be created"
		shell::logger::example "shell::create_go_app my_app"
		shell::logger::example "shell::create_go_app my_app /path/to/my/folder"
		shell::logger::example "shell::create_go_app -n my_app"
		shell::logger::example "shell::create_go_app -n my_app /tmp/go_projects"
		shell::logger::example "shell::create_go_app https://github.com/user/repo /home/user/src"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local app_name="$1"
	if [ -z "$app_name" ]; then
		shell::logger::error "Application name or GitHub URL is required."
		return $RETURN_FAILURE
	fi

	local target_folder="$2"
	local original_dir="$PWD" # Save the original directory
	local module_name="$app_name"
	local is_url="false"

	# Check if the app name is a URL
	if [[ "$app_name" =~ ^(http:\/\/|https:\/\/) ]]; then
		is_url="true"
		# If it's a URL, extract the module name
		module_name="${module_name#http://}"
		module_name="${module_name#https://}"
		module_name="${module_name%/}" # Remove trailing slashes
	fi

	# If a target folder is specified, create it and change directory
	if [ -n "$target_folder" ]; then
		shell::logger::warn "Ensuring target directory exists: $target_folder"
		if [ "$dry_run" = "true" ]; then
			shell::logger::cmd_copy "shell::create_directory_if_not_exists \"$target_folder\""
			shell::logger::cmd_copy "cd \"$target_folder\""
		else
			shell::create_directory_if_not_exists "$target_folder"
			if [ $? -ne 0 ]; then
				shell::logger::error "Could not create or access target directory '$target_folder'."
				return $RETURN_FAILURE
			fi
			cd "$target_folder" || {
				shell::logger::error "Could not change to target directory '$target_folder'."
				return $RETURN_FAILURE
			}
		fi
	fi

	local init_cmd="go mod init $module_name"
	local tidy_cmd="go mod tidy"

	# Execute go mod init
	shell::logger::debug "Initializing Go module: $module_name"
	if [ "$dry_run" = "true" ]; then
		shell::logger::cmd_copy "$init_cmd"
	else
		shell::run_cmd_eval "$init_cmd"
	fi

	# Execute go mod tidy
	shell::logger::debug "Tidying Go dependencies"
	if [ "$dry_run" = "true" ]; then
		shell::logger::cmd_copy "$tidy_cmd"
	else
		shell::run_cmd_eval "$tidy_cmd"
	fi

	# Change back to the original directory if a target folder was used
	if [ -n "$target_folder" ]; then
		if [ "$dry_run" = "true" ]; then
			shell::logger::cmd_copy "cd \"$original_dir\""
		else
			cd "$original_dir" || {
				shell::logger::warn "Could not change back to original directory '$original_dir'."
				return $RETURN_FAILURE
			}
		fi
	fi
	shell::logger::info "Go application initialized successfully."
	return $RETURN_SUCCESS
}

# shell::add_go_app_settings function
# This function downloads essential configuration files for a Go application.
#
# It retrieves the following files:
# - VERSION_RELEASE.md: Contains the version release information for the application.
# - Makefile: A build script that defines how to compile and manage the application.
# - ci.yml: A GitHub Actions workflow configuration for continuous integration.
# - ci_notify.yml: A GitHub Actions workflow configuration for notifications related to CI events.
#
# Each file is downloaded using the shell::download_dataset function, which ensures that the files are
# fetched from the specified URLs and saved in the appropriate locations.
shell::add_go_app_settings() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::section "Go Settings"
		shell::logger::info "Add Go application settings"
		shell::logger::indent 0 "go-project/"
		shell::logger::indent 1 "docs/"
		shell::logger::indent 2 "VERSION_RELEASE.md"
		shell::logger::indent 1 ".github/"
		shell::logger::indent 2 "workflows/"
		shell::logger::indent 3 "gh_wrk_base.yml"
		shell::logger::indent 3 "gh_wrk_news.yml"
		shell::logger::indent 3 "gh_wrk_news_go.yml"
		shell::logger::indent 1 "Makefile"
		return $RETURN_SUCCESS
	fi
	shell::add_go_gitignore
	shell::download_dataset "docs/VERSION_RELEASE.md" $SHELL_PROJECT_DOC_VERSION_RELEASE
	shell::download_dataset "Makefile" $SHELL_PROJECT_GO_MAKEFILE
	shell::download_dataset ".github/workflows/gh_wrk_base.yml" $SHELL_PROJECT_GITHUB_WORKFLOW_BASE
	shell::download_dataset ".github/workflows/gh_wrk_news.yml" $SHELL_PROJECT_GITHUB_WORKFLOW_NEWS
	shell::download_dataset ".github/workflows/gh_wrk_news_go.yml" $SHELL_PROJECT_GITHUB_WORKFLOW_NEWS_GO
	return $RETURN_SUCCESS
}

# shell::add_go_gitignore function
# This function downloads the .gitignore file for a Go project.
#
# It utilizes the shell::download_dataset function to fetch the .gitignore file
# from the specified URL and saves it in the appropriate location within the project structure.
#
# The .gitignore file is essential for specifying which files and directories
# should be ignored by Git, helping to keep the repository clean and free of unnecessary files.
shell::add_go_gitignore() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Add .gitignore file for Go project"
		return $RETURN_SUCCESS
	fi
	shell::download_dataset ".gitignore" $SHELL_PROJECT_GITIGNORE_GO
	return $RETURN_SUCCESS
}
