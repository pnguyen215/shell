#!/usr/bin/env bash
# @file lib/profile.sh
# @brief Profile management built on the INI store.

# @description Returns the path to the profile directory for a given profile name.
#
#   Constructs and returns the path to the profile directory within the workspace,
#   located at $SHELL_CONFIG_DIR/workspace.
# @arg $1 string profile_name: The name of the profile.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   profile_dir=$(shell::profile::path "my_profile")  # Returns "$SHELL_CONFIG_DIR/workspace/my_profile"
#
shell::profile::path() {
	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Returns the path to the profile directory for a given profile name"
		shell::logger::usage "shell::profile::path [-h] <profile_name>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "profile_name" "The name of the profile."
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::profile::path <profile_name>"
		return 1
	fi
	local profile_name="$1"
	echo "$SHELL_WORKSPACE_DIR/$profile_name"
}

# @description Creates a new profile directory and initializes it with a profile.conf file.
#
#   Ensures the workspace directory exists, then creates a new directory for the specified profile
#   and initializes it with an empty profile.conf file. If the profile already exists, it prints a warning.
# @option -n Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.
# @arg $1 string profile_name: The name of the profile to create.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::profile::add my_profile         # Creates the profile directory and profile.conf.
#   shell::profile::add -n my_profile      # Prints the commands without executing them.
#
shell::profile::add() {
	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Creates a new profile directory and initializes it with a profile.conf file"
		shell::logger::usage "shell::profile::add [-n] [-h] <profile_name>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "profile_name" "The name of the profile to create."
		shell::logger::example "shell::profile::add my_profile"
		shell::logger::example "shell::profile::add -n my_profile"
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::profile::add [-n] <profile_name>"
		return 1
	fi
	local profile_name="$1"
	local profile_dir=$(shell::profile::path "$profile_name")
	if [ -d "$profile_dir" ]; then
		shell::logger::warn "Profile '$profile_name' already exists."
		return 1
	fi

	local cmd="mkdir -p \"$profile_dir\" && touch \"$profile_dir/profile.conf\""
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
	else
		shell::workspace::ensure
		shell::exec::shell "$cmd"
		shell::logger::success "Created profile '$profile_name'."
	fi
}

# @description Sources the profile.conf file from the specified profile directory.
#
#   Checks if the specified profile exists and sources its profile.conf file to load configurations
#   into the current shell session. If the profile or file does not exist, it prints an error.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.
# @arg $1 string profile_name: The name of the profile to read.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::profile::read my_profile         # Sources profile.conf from my_profile.
#   shell::profile::read -n my_profile      # Prints the sourcing command without executing it.
#
shell::profile::read() {
	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Sources the profile.conf file from the specified profile directory"
		shell::logger::usage "shell::profile::read [-n] [-h] <profile_name>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "profile_name" "The name of the profile to read."
		shell::logger::example "shell::profile::read my_profile"
		shell::logger::example "shell::profile::read -n my_profile"
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::profile::read [-n] <profile_name>"
		return 1
	fi
	local profile_name="$1"
	local profile_dir=$(shell::profile::path "$profile_name")
	local profile_conf="$profile_dir/profile.conf"
	if [ ! -d "$profile_dir" ]; then
		shell::logger::error "Profile '$profile_name' does not exist."
		return 1
	fi
	if [ ! -f "$profile_conf" ]; then
		shell::logger::error "Profile configuration file '$profile_conf' not found."
		return 1
	fi
	if [ "$dry_run" = "true" ]; then
		shell::conf::read -n "$profile_conf"
	else
		shell::conf::read "$profile_conf"
	fi
}

# @description Opens the profile.conf file of the specified profile in the default editor.
#
#   Checks if the specified profile exists and opens its profile.conf file in the editor specified
#   by the EDITOR environment variable (defaults to 'nano' if unset).
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.
# @arg $1 string profile_name: The name of the profile to update.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::profile::update my_profile         # Opens profile.conf in the default editor.
#   shell::profile::update -n my_profile      # Prints the editor command without executing it.
#
shell::profile::update() {
	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Opens the profile.conf file of the specified profile in the default editor"
		shell::logger::usage "shell::profile::update [-n] [-h] <profile_name>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "profile_name" "The name of the profile to update."
		shell::logger::example "shell::profile::update my_profile"
		shell::logger::example "shell::profile::update -n my_profile"
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::profile::update [-n] <profile_name>"
		return 1
	fi
	local profile_name="$1"
	local profile_dir=$(shell::profile::path "$profile_name")
	local profile_conf="$profile_dir/profile.conf"
	if [ ! -d "$profile_dir" ]; then
		shell::logger::error "Profile '$profile_name' does not exist."
		return 1
	fi
	if [ ! -f "$profile_conf" ]; then
		shell::logger::error "Profile configuration file '$profile_conf' not found."
		return 1
	fi
	local editor="${EDITOR:-vi}"
	local cmd="$editor \"$profile_conf\""
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
	else
		shell::exec::shell "$cmd"
	fi
}

# @description Deletes the specified profile directory after user confirmation.
#
#   Prompts for confirmation before deleting the profile directory and its contents.
#   If confirmed, removes the directory; otherwise, aborts the operation.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.
# @arg $1 string profile_name: The name of the profile to remove.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::profile::remove my_profile         # Prompts to confirm deletion of my_profile.
#   shell::profile::remove -n my_profile      # Prints the removal command without executing it.
#
shell::profile::remove() {
	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Deletes the specified profile directory after user confirmation"
		shell::logger::usage "shell::profile::remove [-n] [-h] <profile_name>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "profile_name" "The name of the profile to remove."
		shell::logger::example "shell::profile::remove my_profile"
		shell::logger::example "shell::profile::remove -n my_profile"
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::profile::remove [-n] <profile_name>"
		return 1
	fi
	local profile_name="$1"
	local profile_dir=$(shell::profile::path "$profile_name")
	if [ ! -d "$profile_dir" ]; then
		shell::logger::error "Profile '$profile_name' does not exist."
		return 1
	fi
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "rm -rf \"$profile_dir\""
	else
		shell::console::print "Are you sure you want to remove profile '$profile_name'? [y/N]" 33
		read -r confirm
		if [[ "$confirm" =~ ^[Yy]$ ]]; then
			shell::fs::remove "$profile_dir"
			shell::logger::success "Removed profile '$profile_name'."
		else
			shell::logger::warn "Removal aborted."
		fi
	fi
}

# @description Displays the contents of the profile.conf file for the specified profile.
#
#   Checks if the specified profile exists and displays the contents of its profile.conf file.
#   If the profile or file does not exist, it prints an error.
# @arg $1 string profile_name: The name of the profile to display.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::profile::get my_profile         # Displays the contents of profile.conf for my_profile.
#
shell::profile::get() {
	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Displays the contents of the profile.conf file for the specified profile"
		shell::logger::usage "shell::profile::get [-h] <profile_name>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "profile_name" "The name of the profile to display."
		shell::logger::example "shell::profile::get my_profile"
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::profile::get <profile_name>"
		return 1
	fi
	local profile_name="$1"
	local profile_dir=$(shell::profile::path "$profile_name")
	local profile_conf="$profile_dir/profile.conf"
	if [ ! -d "$profile_dir" ]; then
		shell::logger::error "Profile '$profile_name' does not exist."
		return 1
	fi
	if [ ! -f "$profile_conf" ]; then
		shell::logger::error "Profile configuration file '$profile_conf' not found."
		return 1
	fi
	shell::logger::debug "Contents of '$profile_conf':"
	shell::exec::shell cat "$profile_conf"
}

# @description Renames the specified profile directory.
#
#   Checks if the old profile exists and the new profile name does not already exist,
#   then renames the directory accordingly.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.
# @arg $1 string old_name: The current name of the profile.
# @arg $2 string new_name: The new name for the profile.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::profile::rename old_profile new_profile         # Renames old_profile to new_profile.
#   shell::profile::rename -n old_profile new_profile      # Prints the rename command without executing it.
#
shell::profile::rename() {
	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Renames the specified profile directory"
		shell::logger::usage "shell::profile::rename [-n] [-h] <old_name> <new_name>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "old_name" "The current name of the profile."
		shell::logger::item "new_name" "The new name for the profile."
		shell::logger::example "shell::profile::rename old_profile new_profile"
		shell::logger::example "shell::profile::rename -n old_profile new_profile"
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 2 ]; then
		echo "Usage: shell::profile::rename [-n] <old_name> <new_name>"
		return 1
	fi
	local old_name="$1"
	local new_name="$2"
	local old_dir=$(shell::profile::path "$old_name")
	local new_dir=$(shell::profile::path "$new_name")
	if [ ! -d "$old_dir" ]; then
		shell::logger::error "Profile '$old_name' does not exist."
		return 1
	fi
	if [ -d "$new_dir" ]; then
		shell::logger::error "Profile '$new_name' already exists."
		return 1
	fi
	local cmd="mv \"$old_dir\" \"$new_dir\""
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
	else
		shell::exec::shell "$cmd"
		shell::logger::success "Renamed profile '$old_name' to '$new_name'."
	fi
}

# @description Adds a configuration entry (key=value) to the profile.conf file of a specified profile.
#   The value is encoded using Base64 before being saved.
#
#   The function checks for an optional dry-run flag (-n) and ensures that the profile name, key, and value are provided.
#   It encodes the value using Base64 (with newline characters removed) and appends a line in the format:
#   key=encoded_value
#   to the profile.conf file in the specified profile directory. If the profile directory or the profile.conf file does not exist, they are created.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.
# @arg $1 string profile_name: The name of the profile.
# @arg $2 string key: The configuration key.
# @arg $3 string value: The configuration value to be encoded and saved.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::profile::conf::add my_profile my_setting "some secret value"         # Encodes the value and adds the entry to my_profile/profile.conf
#   shell::profile::conf::add -n my_profile my_setting "some secret value"      # Prints the command without executing it
#
shell::profile::conf::add() {
	local dry_run="false"

	# Check for the optional dry-run flag (-n)
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Adds a configuration entry (key=value) to the profile.conf file of a specified profile"
		shell::logger::usage "shell::profile::conf::add [-n] [-h] <profile_name> <key> <value>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "profile_name" "The name of the profile."
		shell::logger::item "key" "The configuration key."
		shell::logger::item "value" "The configuration value to be encoded and saved."
		shell::logger::example "shell::profile::conf::add my_profile my_setting \"some secret value\""
		shell::logger::example "shell::profile::conf::add -n my_profile my_setting \"some secret value\""
		return $RETURN_SUCCESS
	fi

	# Validate the number of arguments
	if [ $# -lt 3 ]; then
		echo "Usage: shell::profile::conf::add [-n] <profile_name> <key> <value>"
		return 1
	fi

	local profile_name="$1"
	local key="$2"
	local value="$3"
	# sanitized key
	key=$(shell::strings::sanitize::upper "$key")

	# Get the profile directory (assumes shell::profile::path is defined elsewhere)
	local profile_dir=$(shell::profile::path "$profile_name")

	# Ensure the profile directory exists
	if [ ! -d "$profile_dir" ]; then
		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "mkdir -p \"$profile_dir\""
		else
			shell::fs::mkdir --private "$profile_dir"
		fi
	fi

	# Define the profile.conf file path
	local profile_conf="$profile_dir/profile.conf"

	# Ensure the profile.conf file exists
	shell::fs::touch --private "$profile_conf"

	# Encode the value using Base64 and remove any newlines
	local encoded_value
	encoded_value=$(echo -n "$value" | base64 | tr -d '\n')

	# Build the command to append the key and encoded value to the profile.conf file
	local cmd="echo \"$key=$encoded_value\" >> \"$profile_conf\""

	# Execute or print the command based on dry-run mode
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
	else
		# Check if the key already exists in the profile.conf
		if grep -q "^${key}=" "$profile_conf"; then
			shell::logger::warn "The key '$key' already exists in profile '$profile_name'. Consider updating it using shell::profile::conf::update."
			return 0
		fi
		shell::permission::secure "$profile_conf"
		shell::exec::shell "$cmd"
		shell::logger::success "Added configuration to profile '$profile_name': $key (encoded value)"
	fi
}

# @description Retrieves a configuration profile value by prompting the user to select a config key from the profile's configuration file.
#
#   This function locates the profile directory and its configuration file, verifies that the profile exists,
#   and then ensures that the interactive fuzzy finder (fzf) is installed. It uses fzf to let the user select a configuration key,
#   decodes its base64-encoded value (using the appropriate flag for macOS or Linux), displays the selected key,
#   and finally copies the decoded value to the clipboard asynchronously.
# @arg $1 string profile_name: The name of the configuration profile.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::profile::conf::get my_profile          # Retrieves and processes the 'my_profile' profile.
#   shell::profile::conf::get -n my_profile       # Dry-run mode: prints the commands without executing them.
#
shell::profile::conf::get() {
	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Retrieves a configuration profile value by prompting the user to select a config key from the profile's configuration file"
		shell::logger::usage "shell::profile::conf::get [-n] [-h] <profile_name>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "profile_name" "The name of the configuration profile."
		shell::logger::example "shell::profile::conf::get my_profile"
		shell::logger::example "shell::profile::conf::get -n my_profile"
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::profile::conf::get <profile_name>"
		return 1
	fi
	shell::workspace::ensure
	local profile_name="$1"
	local profile_dir=$(shell::profile::path "$profile_name")
	local profile_conf="$profile_dir/profile.conf"
	if [ ! -d "$profile_dir" ]; then
		shell::logger::error "Profile '$profile_name' does not exist."
		return 1
	fi
	if [ ! -f "$profile_conf" ]; then
		shell::logger::error "Profile configuration file '$profile_conf' not found."
		return 1
	fi
	shell::dependency::fzf::ensure
	local selected_key
	selected_key=$(cut -d '=' -f 1 "$profile_conf" | fzf --prompt="Select config key for profile '$profile_name': ")
	if [ -z "$selected_key" ]; then
		shell::logger::error "No configuration selected."
		return 1
	fi
	local selected_line
	selected_line=$(grep "^${selected_key}=" "$profile_conf")
	if [ -z "$selected_line" ]; then
		shell::logger::error "Selected key '$selected_key' not found in configuration."
		return 1
	fi
	local encoded_value
	encoded_value=$(echo "$selected_line" | cut -d '=' -f 2-)
	local os_type
	os_type=$(shell::os::type)
	local decoded_value
	if [ "$os_type" = "macos" ]; then
		decoded_value=$(echo "$encoded_value" | base64 -D)
	else
		decoded_value=$(echo "$encoded_value" | base64 -d)
	fi
	shell::console::print "[k] Key: $selected_key" 33
	shell::clipboard::copy --best-effort "$decoded_value"
}

# @description Retrieves a configuration value for a given profile and key by decoding its base64-encoded value.
#
#   This function ensures that the workspace exists and locates the profile directory
#   and configuration file. It then extracts the configuration line matching the provided key,
#   decodes the associated base64-encoded value (using the appropriate flag for macOS or Linux),
#   asynchronously copies the decoded value to the clipboard, and finally outputs the decoded value.
# @arg $1 string profile_name: The name of the configuration profile.
# @arg $2 string key: The configuration key whose value will be retrieved.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::profile::conf::value my_profile API_KEY
#   shell::profile::conf::value -n my_profile API_KEY   # Dry-run: prints commands without executing them.
#
shell::profile::conf::value() {
	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Retrieves a configuration value for a given profile and key by decoding its base64-encoded value"
		shell::logger::usage "shell::profile::conf::value [-n] [-h] <profile_name> <key>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "profile_name" "The name of the configuration profile."
		shell::logger::item "key" "The configuration key whose value will be retrieved."
		shell::logger::example "shell::profile::conf::value my_profile API_KEY"
		shell::logger::example "shell::profile::conf::value -n my_profile API_KEY"
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 2 ]; then
		echo "Usage: shell::profile::conf::value <profile_name> <key>"
		return 1
	fi
	shell::workspace::ensure
	local profile_name="$1"
	local key="$2"
	local profile_dir=$(shell::profile::path "$profile_name")
	local profile_conf="$profile_dir/profile.conf"
	# sanitized key
	key=$(shell::strings::sanitize::upper "$key")

	if [ ! -d "$profile_dir" ]; then
		shell::logger::error "Profile '$profile_name' does not exist."
		return 1
	fi
	if [ ! -f "$profile_conf" ]; then
		shell::logger::error "Profile configuration file '$profile_conf' not found."
		return 1
	fi
	local conf_line
	conf_line=$(grep "^${key}=" "$profile_conf")
	if [ -z "$conf_line" ]; then
		shell::logger::error "Key '$key' not found in profile '$profile_name'."
		return 1
	fi
	local encoded_value
	encoded_value=$(echo "$conf_line" | cut -d '=' -f 2-)
	local os_type
	os_type=$(shell::os::type)
	local decoded_value
	if [ "$os_type" = "macos" ]; then
		decoded_value=$(echo "$encoded_value" | base64 -D)
	else
		decoded_value=$(echo "$encoded_value" | base64 -d)
	fi
	echo "$decoded_value"
}

# @description Removes a configuration key from a given profile's configuration file.
#
#   This function locates the profile directory and its configuration file, verifies their existence,
#   and then uses fzf to let the user select a configuration key to remove.
#   It builds an OS-specific sed command to delete the line containing the selected key.
#   In dry-run mode, the command is printed using shell::logger::command_clip; otherwise, it is executed asynchronously
#   using shell::exec::async with shell::exec::shell.
# @arg $1 string profile_name: The name of the configuration profile.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::profile::conf::remove my_profile
#   shell::profile::conf::remove -n my_profile   # Dry-run: prints the removal command without executing.
#
shell::profile::conf::remove() {
	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Removes a configuration key from a given profile's configuration file"
		shell::logger::usage "shell::profile::conf::remove [-n] [-h] <profile_name>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "profile_name" "The name of the configuration profile."
		shell::logger::example "shell::profile::conf::remove my_profile"
		shell::logger::example "shell::profile::conf::remove -n my_profile"
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::profile::conf::remove [-n] <profile_name>"
		return 1
	fi
	shell::workspace::ensure
	local profile_name="$1"
	local profile_dir=$(shell::profile::path "$profile_name")
	local profile_conf="$profile_dir/profile.conf"
	if [ ! -d "$profile_dir" ]; then
		shell::logger::error "Profile '$profile_name' does not exist."
		return 1
	fi
	if [ ! -f "$profile_conf" ]; then
		shell::logger::error "Profile configuration file '$profile_conf' not found."
		return 1
	fi
	shell::dependency::fzf::ensure
	local selected_key
	selected_key=$(cut -d '=' -f 1 "$profile_conf" | fzf --prompt="Select config key to remove from profile '$profile_name': ")
	if [ -z "$selected_key" ]; then
		shell::logger::error "No configuration selected."
		return 1
	fi
	local os_type
	os_type=$(shell::os::type)
	local sed_cmd=""
	if [ "$os_type" = "macos" ]; then
		sed_cmd="shell::fs::sed_inplace \"/^${selected_key}=/d\" \"$profile_conf\""
	else
		sed_cmd="shell::fs::sed_inplace \"/^${selected_key}=/d\" \"$profile_conf\""
	fi
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$sed_cmd"
	else
		shell::exec::shell "$sed_cmd"
		shell::logger::success "Removed configuration for key: $selected_key from profile '$profile_name'"
	fi
}

# @description Updates a specified configuration key in a given profile by replacing its value.
#
#   The function retrieves the profile configuration file, prompts the user to select a key (using fzf),
#   asks for the new value, encodes it in base64, and constructs a sed command to update the key.
#   The sed command is executed asynchronously via the shell::exec::async function (unless in dry-run mode).
# @option -n Optional dry-run flag. If provided, the update command is printed using shell::logger::command_clip without executing.
# @arg $1 string profile_name: The name of the profile to update.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::profile::conf::update my_profile
#   shell::profile::conf::update -n my_profile   # dry-run mode
#
shell::profile::conf::update() {
	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Updates a specified configuration key in a given profile by replacing its value"
		shell::logger::usage "shell::profile::conf::update [-n] [-h] <profile_name>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the update command is printed using shell::logger::command_clip without executing."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "profile_name" "The name of the profile to update."
		shell::logger::example "shell::profile::conf::update my_profile"
		shell::logger::example "shell::profile::conf::update -n my_profile"
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::profile::conf::update [-n] <profile_name>"
		return 1
	fi
	local profile_name="$1"
	local profile_dir=$(shell::profile::path "$profile_name")
	local profile_conf="$profile_dir/profile.conf"
	if [ ! -d "$profile_dir" ]; then
		shell::logger::error "Profile '$profile_name' does not exist."
		return 1
	fi
	if [ ! -f "$profile_conf" ]; then
		shell::logger::error "Profile configuration file '$profile_conf' not found."
		return 1
	fi
	shell::dependency::fzf::ensure
	local selected_key
	selected_key=$(cut -d '=' -f 1 "$profile_conf" | fzf --prompt="Select config key to update in profile '$profile_name': ")
	if [ -z "$selected_key" ]; then
		shell::logger::error "No configuration selected."
		return 1
	fi
	shell::console::print ">> Enter new value for key '$selected_key' in profile '$profile_name':" 33
	read -r new_value
	if [ -z "$new_value" ]; then
		shell::logger::error "No new value entered. Update aborted."
		return 1
	fi
	local encoded_value
	encoded_value=$(echo -n "$new_value" | base64 | tr -d '\n')
	local os_type
	os_type=$(shell::os::type)
	local sed_cmd=""
	if [ "$os_type" = "macos" ]; then
		sed_cmd="shell::fs::sed_inplace \"s/^${selected_key}=.*/${selected_key}=${encoded_value}/\" \"$profile_conf\""
	else
		sed_cmd="shell::fs::sed_inplace \"s/^${selected_key}=.*/${selected_key}=${encoded_value}/\" \"$profile_conf\""
	fi
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$sed_cmd"
	else
		shell::exec::shell "$sed_cmd"
		shell::logger::success "Updated configuration for key: $selected_key in profile '$profile_name'"
	fi
}

# @description Checks whether a specified key exists in the configuration file of a given profile.
#
#   The function constructs the path to the profile's configuration file and verifies that the profile directory exists.
#   It then checks if the configuration file exists. If both exist, it searches for the specified key using grep.
#   The function outputs "true" if the key is found and "false" otherwise.
# @arg $1 string profile_name: The name of the profile.
# @arg $2 string key: The configuration key to search for.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::profile::conf::exists my_profile my_key
#
shell::profile::conf::exists() {
	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Checks whether a specified key exists in the configuration file of a given profile"
		shell::logger::usage "shell::profile::conf::exists [-h] <profile_name> <key>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "profile_name" "The name of the profile."
		shell::logger::item "key" "The configuration key to search for."
		shell::logger::example "shell::profile::conf::exists my_profile my_key"
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 2 ]; then
		echo "Usage: shell::profile::conf::exists <profile_name> <key>"
		return 1
	fi
	local profile_name="$1"
	local key="$2"
	local profile_dir=$(shell::profile::path "$profile_name")
	local profile_conf="$profile_dir/profile.conf"
	# sanitized key
	key=$(shell::strings::sanitize::upper "$key")

	if [ ! -d "$profile_dir" ]; then
		shell::logger::error "Profile '$profile_name' does not exist."
		return 1
	fi
	if [ ! -f "$profile_conf" ]; then
		echo "false"
		return 1
	fi
	if grep -q "^${key}=" "$profile_conf"; then
		echo "true"
		return 0
	else
		echo "false"
		return 1
	fi
}

# @description Renames an existing configuration key in a given profile.
#
#   The function checks that the profile directory and configuration file exist.
#   It then uses fzf to allow the user to select the existing key to rename.
#   After prompting for a new key name and verifying that it does not already exist,
#   the function constructs an OS-specific sed command to replace the old key with the new one.
#   In dry-run mode, the command is printed via shell::logger::command_clip; otherwise, it is executed using shell::exec::shell.
# @option -n Optional dry-run flag. If provided, prints the sed command using shell::logger::command_clip without executing.
# @arg $1 string profile_name: The name of the profile whose key should be renamed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::profile::conf::rename my_profile
#   shell::profile::conf::rename -n my_profile   # dry-run mode
#
shell::profile::conf::rename() {
	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Renames an existing configuration key in a given profile"
		shell::logger::usage "shell::profile::conf::rename [-n] [-h] <profile_name>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, prints the sed command using shell::logger::command_clip without executing."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "profile_name" "The name of the profile whose key should be renamed."
		shell::logger::example "shell::profile::conf::rename my_profile"
		shell::logger::example "shell::profile::conf::rename -n my_profile"
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::profile::conf::rename [-n] <profile_name>"
		return 1
	fi
	local profile_name="$1"
	local profile_dir=$(shell::profile::path "$profile_name")
	local profile_conf="$profile_dir/profile.conf"
	if [ ! -d "$profile_dir" ]; then
		shell::logger::error "Profile '$profile_name' does not exist."
		return 1
	fi
	if [ ! -f "$profile_conf" ]; then
		shell::logger::error "Profile configuration file '$profile_conf' not found."
		return 1
	fi
	shell::dependency::fzf::ensure
	local old_key
	old_key=$(cut -d '=' -f 1 "$profile_conf" | fzf --prompt="Select a key to rename in profile '$profile_name': ")
	if [ -z "$old_key" ]; then
		shell::logger::error "No key selected. Aborting rename."
		return 1
	fi
	shell::console::print "Enter new key name for '$old_key' in profile '$profile_name':" 33
	read -r new_key
	if [ -z "$new_key" ]; then
		shell::logger::error "No new key name entered. Aborting rename."
		return 1
	fi
	# sanitized key
	new_key=$(shell::strings::sanitize::upper "$new_key")

	if grep -q "^${new_key}=" "$profile_conf"; then
		shell::logger::error "Key '$new_key' already exists in profile '$profile_name'."
		return 1
	fi
	local os_type
	os_type=$(shell::os::type)
	local sed_cmd=""
	if [ "$os_type" = "macos" ]; then
		sed_cmd="shell::fs::sed_inplace \"s/^${old_key}=/${new_key}=/\" \"$profile_conf\""
	else
		sed_cmd="shell::fs::sed_inplace \"s/^${old_key}=/${new_key}=/\" \"$profile_conf\""
	fi
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$sed_cmd"
	else
		shell::exec::shell "$sed_cmd"
		shell::logger::success "Renamed key '$old_key' to '$new_key' in profile '$profile_name'"
	fi
}

# @description Clones a configuration profile by copying its profile.conf from a source profile to a destination profile.
#
#   This function retrieves the source and destination profile directories using shell::profile::path,
#   verifies that the source profile exists and has a profile.conf file, and ensures that the destination
#   profile does not already exist. If validations pass, it clones the configuration by creating the destination
#   directory and copying the profile.conf file from the source to the destination. When the dry-run flag (-n)
#   is provided, it prints the command without executing it.
# @option -n (Optional) Dry-run flag. If provided, the command is printed but not executed.
# @arg $1 string source_profile: The name of the source profile.
# @arg $2 string destination_profile: The name of the destination profile.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::profile::conf::clone my_profile backup_profile   # Clones profile.conf from 'my_profile' to 'backup_profile'
#
shell::profile::conf::clone() {
	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Clones a configuration profile by copying its profile.conf from a source profile to a destination profile"
		shell::logger::usage "shell::profile::conf::clone [-n] [-h] <source_profile> <destination_profile>"
		shell::logger::option "-n" "(Optional) Dry-run flag. If provided, the command is printed but not executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "source_profile" "The name of the source profile."
		shell::logger::item "destination_profile" "The name of the destination profile."
		shell::logger::example "shell::profile::conf::clone my_profile backup_profile"
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 2 ]; then
		echo "Usage: shell::profile::conf::clone [-n] <source_profile> <destination_profile>"
		return 1
	fi
	local source_profile="$1"
	local destination_profile="$2"
	local source_dir=$(shell::profile::path "$source_profile")
	local destination_dir=$(shell::profile::path "$destination_profile")
	local source_conf="$source_dir/profile.conf"
	local destination_conf="$destination_dir/profile.conf"
	if [ ! -d "$source_dir" ]; then
		shell::logger::error "Source profile '$source_profile' does not exist."
		return 1
	fi
	if [ ! -f "$source_conf" ]; then
		shell::logger::error "Source profile configuration file '$source_conf' not found."
		return 1
	fi
	if [ -d "$destination_dir" ]; then
		shell::logger::error "Destination profile '$destination_profile' already exists."
		return 1
	fi
	local cmd="mkdir -p \"$destination_dir\" && cp \"$source_conf\" \"$destination_conf\""
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
	else
		shell::exec::shell "$cmd"
		shell::logger::success "Cloned profile.conf from '$source_profile' to '$destination_profile'"
	fi
}

# @description Lists all available configuration profiles in the workspace.
#
#   This function checks that the workspace directory ($SHELL_CONFIG_DIR/workspace) exists.
#   It then finds all subdirectories (each representing a profile) and prints their names.
#   If no profiles are found, an appropriate message is displayed.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::profile::conf::list       # Displays the names of all profiles in the workspace.
#
shell::profile::conf::list() {
	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Lists all available configuration profiles in the workspace"
		shell::logger::usage "shell::profile::conf::list [-h]"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::profile::conf::list"
		return $RETURN_SUCCESS
	fi

	# Ensure that the workspace exists.
	shell::workspace::ensure

	# Check if the workspace directory exists.
	if [ ! -d "$SHELL_WORKSPACE_DIR" ]; then
		shell::logger::error "Workspace directory '$SHELL_WORKSPACE_DIR' does not exist."
		return 1
	fi

	# Find all subdirectories (profiles) in the workspace.
	local profiles
	profiles=$(find "$SHELL_WORKSPACE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

	# Check if any profiles were found.
	if [ -z "$profiles" ]; then
		shell::logger::error "No profiles found in workspace."
		return 1
	fi

	# List profile names by extracting the basename from each directory path.
	echo "$profiles" | xargs -n 1 basename
}
