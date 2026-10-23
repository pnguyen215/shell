#!/usr/bin/env bash
# @file lib/conf.sh
# @brief Encoded key/value configuration store with groups and protected keys.

# @description Sources a configuration file, allowing its variables and functions to be loaded into the current shell.
#
#   The function checks that a filename is provided and that the specified file exists.
#   If the file is not found, an error message is displayed.
#   In dry-run mode, the command "source <filename>" is printed using shell::logger::command_clip.
#   Otherwise, the file is sourced using shell::exec::command to log the execution.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.
# @arg $1 string filename: The configuration file to source.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::read ~/.my-config                # Sources the configuration file.
#   shell::conf::read -n ~/.my-config             # Prints the sourcing command without executing it.
#
shell::conf::read() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Sources a configuration file, allowing its variables and functions to be loaded into the current shell"
		shell::logger::usage "shell::conf::read [-n] [-h] <filename>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "filename" "The configuration file to source."
		shell::logger::example "shell::conf::read ~/.my-config"
		shell::logger::example "shell::conf::read -n ~/.my-config"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check if a filename is provided.
	if [ $# -lt 1 ]; then
		echo "Usage: shell::conf::read [-n] <filename>"
		return 1
	fi

	local filename="$1"

	# Verify that the configuration file exists.
	if [[ ! -f "$filename" ]]; then
		shell::logger::error "Conf file '$filename' not found."
		return 1
	fi

	# Check if dry mode is enabled.
	# If so, print the command to source the file.
	# Otherwise, source the file.
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "source \"$filename\""
	else
		shell::exec::command source "$filename"
	fi
}

# @description Adds a configuration entry (key=value) to a constant configuration file.
#   The value is encoded using Base64 before being saved.
#
#   The function first checks for an optional dry-run flag (-n) and verifies that both key and value are provided.
#   It encodes the value using Base64 (with newline characters removed) and then appends a line in the format:
#   key=encoded_value
#   to a constant configuration file (defined by SHELL_KEY_FILE). If the configuration file does not exist, it is created.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.
# @arg $1 string key: The configuration key.
# @arg $2 string value: The configuration value to be encoded and saved.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::key::add my_setting "some secret value"         # Encodes the value and adds the entry.
#   shell::conf::key::add -n my_setting "some secret value"      # Prints the command without executing it.
#
shell::conf::key::add() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Adds a configuration entry (key=value) to a constant configuration file"
		shell::logger::usage "shell::conf::key::add [-n] [-h] <key> <value>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "key" "The configuration key."
		shell::logger::item "value" "The configuration value to be encoded and saved."
		shell::logger::example "shell::conf::key::add my_setting \"some secret value\""
		shell::logger::example "shell::conf::key::add -n my_setting \"some secret value\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check if a key and value are provided.
	# If not, print usage information and return an error.
	if [ $# -lt 2 ]; then
		echo "Usage: shell::conf::key::add [-n] <key> <value>"
		return 1
	fi

	local key="$1"
	local value="$2"
	key=$(shell::strings::sanitize::upper "$key")

	# Encode the value using Base64 and remove any newlines.
	local encoded_value
	encoded_value=$(echo -n "$value" | base64 | tr -d '\n')

	# Ensure the configuration file exists.
	shell::fs::touch --private "$SHELL_KEY_FILE"
	shell::permission::secure "$SHELL_KEY_FILE"

	# Build the command to append the key and encoded value to the configuration file.
	local cmd="echo \"$key=$encoded_value\" >> \"$SHELL_KEY_FILE\""

	# Check if the dry mode is enabled.
	# If so, print the command to be executed.
	# Otherwise, execute the command to add the configuration entry.
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
	else
		result=$(shell::conf::key::exists $key)
		if [ "$result" = "true" ]; then
			shell::logger::warn "The key '$key' exists. Please consider updating it by using shell::conf::key::update::fzf"
			return 0
		fi
		shell::exec::shell "$cmd"
		shell::logger::success "Added configuration: $key (encoded value)"
	fi
}

# @description Adds a configuration entry (key=value) with an optional comment to the constant configuration file.
#   The value is encoded using Base64 before being saved.
#
#   This function encodes the value using Base64 (with newline characters removed) and appends a line in the format:
#   # comment (if provided)
#   key=encoded_value
#   to the configuration file defined by SHELL_KEY_FILE.
#   If the key already exists, a warning is shown and the function exits.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.
# @arg $1 string key: The configuration key.
# @arg $2 string value: The configuration value to be encoded and saved.
# @arg $@ string comment: Optional comment to be added above the key-value pair.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::key::comment my_key "my secret" "This is a comment"
#   shell::conf::key::comment -n my_key "my secret" "Dry-run with comment"
#
shell::conf::key::comment() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Adds a configuration entry (key=value) with an optional comment to the constant configuration file"
		shell::logger::usage "shell::conf::key::comment [-n] <key> <value> [comment]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed."
		shell::logger::item "key" "The configuration key."
		shell::logger::item "value" "The configuration value to be encoded and saved."
		shell::logger::item "comment" "Optional comment to be added above the key-value pair."
		shell::logger::option "-h, --help" "Display this help message"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	if [ $# -lt 2 ]; then
		echo "Usage: shell::conf::key::comment [-n] <key> <value> [comment]"
		return 1
	fi

	local key="$1"
	local value="$2"
	local comment="$3"

	key=$(shell::strings::sanitize::upper "$key")

	# Encode the value using Base64 and remove any newlines
	local encoded_value
	encoded_value=$(echo -n "$value" | base64 | tr -d '\n')

	# Ensure the configuration file exists
	shell::fs::touch --private "$SHELL_KEY_FILE"
	shell::permission::secure "$SHELL_KEY_FILE"

	# Check if the key already exists
	if [ "$(shell::conf::key::exists "$key")" = "true" ]; then
		shell::logger::warn "The key '$key' exists. Please consider updating it by using shell::conf::key::update::fzf"
		return 0
	fi

	# Build the command to append the comment and key-value pair
	local cmd=""
	if [ -n "$comment" ]; then
		cmd="echo \"# $comment\" >> \"$SHELL_KEY_FILE\" && "
	fi
	cmd+="echo \"$key=$encoded_value\" >> \"$SHELL_KEY_FILE\""

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
	else
		shell::exec::shell "$cmd"
		shell::logger::success "Added configuration: $key (encoded value) with comment"
	fi
}

# @description Interactively selects a configuration key from a constant configuration file using fzf,
#   then decodes and displays its corresponding value.
#
#   The function reads the configuration file defined by the constant SHELL_KEY_FILE,
#   which is expected to have entries in the format:
#   key=encoded_value
#   Instead of listing the entire line, it extracts only the keys (before the '=') and uses fzf
#   for interactive selection. Once a key is selected, it looks up the full entry,
#   decodes the Base64-encoded value (using -D on macOS and -d on Linux), and then displays the key
#   and its decoded value.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::key::get::fzf      # Interactively select a key and display its decoded value.
#
shell::conf::key::get::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a configuration key from a constant configuration file using fzf, then decodes and displays its corresponding value"
		shell::logger::usage "shell::conf::key::get::fzf [-h]"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::conf::key::get::fzf"
		return $RETURN_SUCCESS
	fi

	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure

	# Extract only the keys from the configuration file and select one using fzf.
	local selected_key
	# selected_key=$(cut -d '=' -f 1 "$SHELL_KEY_FILE" | fzf --prompt="Select config key: ")
	selected_key=$(grep -v '^\s*#' "$SHELL_KEY_FILE" | cut -d '=' -f 1 | fzf --prompt="Select config key: ")
	if [ -z "$selected_key" ]; then
		shell::logger::error "No configuration selected."
		return 1
	fi

	# Retrieve the full line corresponding to the selected key.
	local selected_line
	selected_line=$(grep "^${selected_key}=" "$SHELL_KEY_FILE")
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

# @description Retrieves and outputs the decoded value for a given configuration key from the key configuration file.
#
#   This function searches for the specified key in the configuration file defined by SHELL_KEY_FILE.
#   The configuration file is expected to have entries in the format:
#   key=encoded_value
#   If the key is found, the function decodes the associated Base64‑encoded value (using -D on macOS and -d on Linux)
#   and outputs the decoded value to standard output.
# @arg $1 string key: The configuration key whose value should be retrieved.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::key::get my_setting   # Outputs the decoded value for the key 'my_setting'.
#
shell::conf::key::get() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Retrieves and outputs the decoded value for a given configuration key from the key configuration file"
		shell::logger::usage "shell::conf::key::get [-h] <key>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "key" "The configuration key whose value should be retrieved."
		shell::logger::example "shell::conf::key::get my_setting"
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::conf::key::get [-h] <key>"
		return 1
	fi

	local key
	key="$(shell::strings::sanitize::upper "$1")"

	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	local conf_line
	conf_line=$(grep "^${key}=" "$SHELL_KEY_FILE")
	if [ -z "$conf_line" ]; then
		shell::logger::error "Key '$key' not found in configuration."
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

# @description Interactively selects a configuration key from a constant configuration file using fzf,
#   then removes the corresponding entry from the configuration file.
#
#   The function reads the configuration file defined by the constant SHELL_KEY_FILE, where each entry is in the format:
#   key=encoded_value
#   It extracts only the keys (before the '=') and uses fzf for interactive selection.
#   Once a key is selected, it constructs a command to remove the line that starts with "key=" from the configuration file.
#   The command uses sed with different options depending on the operating system (macOS or Linux).
#   In dry-run mode, the command is printed using shell::logger::command_clip; otherwise, it is executed using shell::exec::shell.
# @option -n Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::key::remove::fzf         # Interactively select a key and remove its configuration entry.
#   shell::conf::key::remove::fzf -n      # Prints the removal command without executing it.
#
shell::conf::key::remove::fzf() {
	local dry_run="false"

	# Check for the optional dry-run flag (-n)
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a configuration key from a constant configuration file using fzf, then removes the corresponding entry from the configuration file"
		shell::logger::usage "shell::conf::key::remove::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::conf::key::remove::fzf"
		shell::logger::example "shell::conf::key::remove::fzf -n"
		return $RETURN_SUCCESS
	fi

	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure

	# Extract only the keys from the configuration file and select one using fzf.
	local selected_key
	# selected_key=$(cut -d '=' -f 1 "$SHELL_KEY_FILE" | fzf --prompt="Select config key to remove: ")
	selected_key=$(grep -v '^\s*#' "$SHELL_KEY_FILE" | cut -d '=' -f 1 | fzf --prompt="Select config key to remove: ")
	if [ -z "$selected_key" ]; then
		shell::logger::error "No configuration selected."
		return 1
	fi

	if [ "$(shell::conf::protected::is "$selected_key")" = "true" ]; then
		shell::logger::error "'$selected_key' is a protected key and cannot be modified."
		return 1
	fi

	local os_type
	os_type=$(shell::os::type)
	local sed_cmd=""

	# Check if the configuration file is writable; if not, use sudo.
	# if [ ! -w "$SHELL_KEY_FILE" ]; then
	#     use_sudo="sudo "
	# fi

	# Construct the sed command to remove the line starting with "selected_key="
	if [ "$os_type" = "macos" ]; then
		# On macOS, use shell::fs::sed_inplace for in-place editing.
		sed_cmd="shell::fs::sed_inplace \"/^${selected_key}=/d\" \"$SHELL_KEY_FILE\""
	else
		# On Linux, use shell::fs::sed_inplace for in-place editing.
		sed_cmd="shell::fs::sed_inplace \"/^${selected_key}=/d\" \"$SHELL_KEY_FILE\""
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$sed_cmd"
	else
		shell::exec::shell "$sed_cmd"
		shell::logger::success "Removed configuration for key: $selected_key"
	fi
}

# @description Interactively updates the value for a configuration key in a constant configuration file.
#   The new value is encoded using Base64 before updating the file.
#
#   The function reads the configuration file defined by SHELL_KEY_FILE, which contains entries in the format:
#   key=encoded_value
#   It extracts only the keys and uses fzf to allow interactive selection.
#   Once a key is selected, the function prompts for a new value, encodes it using Base64 (with newlines removed),
#   and then updates the corresponding configuration entry in the file by replacing the line starting with "key=".
#   The sed command used for in-place update differs between macOS and Linux.
# @option -n Optional dry-run flag. If provided, the update command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::key::update::fzf       # Interactively select a key, enter a new value, and update its entry.
#   shell::conf::key::update::fzf -n    # Prints the update command without executing it.
#
shell::conf::key::update::fzf() {
	local dry_run="false"

	# Check for the optional dry-run flag (-n)
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively updates the value for a configuration key in a constant configuration file"
		shell::logger::usage "shell::conf::key::update::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the update command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::conf::key::update::fzf"
		shell::logger::example "shell::conf::key::update::fzf -n"
		return $RETURN_SUCCESS
	fi

	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure

	# Extract only the keys from the configuration file and select one using fzf.
	local selected_key
	# selected_key=$(cut -d '=' -f 1 "$SHELL_KEY_FILE" | fzf --prompt="Select config key to update: ")
	selected_key=$(grep -v '^\s*#' "$SHELL_KEY_FILE" | cut -d '=' -f 1 | fzf --prompt="Select config key to update: ")
	if [ -z "$selected_key" ]; then
		shell::logger::error "No configuration selected."
		return 1
	fi

	# Prompt the user for the new value.
	shell::console::print ">> Enter new value for key '$selected_key':" 33
	read -r new_value
	if [ -z "$new_value" ]; then
		shell::logger::error "No new value entered. Update aborted."
		return 1
	fi

	# Encode the new value using Base64 and remove any newline characters.
	local encoded_value
	encoded_value=$(echo -n "$new_value" | base64 | tr -d '\n')

	local os_type
	os_type=$(shell::os::type)
	local sed_cmd=""

	# Construct the sed command to update the line starting with "selected_key=".
	if [ "$os_type" = "macos" ]; then
		# For macOS, use shell::fs::sed_inplace for in-place editing.
		sed_cmd="shell::fs::sed_inplace \"s/^${selected_key}=.*/${selected_key}=${encoded_value}/\" \"$SHELL_KEY_FILE\""
	else
		# For Linux, use shell::fs::sed_inplace for in-place editing.
		sed_cmd="shell::fs::sed_inplace \"s/^${selected_key}=.*/${selected_key}=${encoded_value}/\" \"$SHELL_KEY_FILE\""
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$sed_cmd"
	else
		shell::exec::shell "$sed_cmd"
		shell::logger::success "Updated configuration for key: $selected_key"
	fi
}

# @description Checks if a configuration key exists in the key configuration file.
#
#   This function searches for the specified key in the configuration file defined by SHELL_KEY_FILE.
#   The configuration file should have entries in the format:
#   key=encoded_value
#   If a line starting with "key=" is found, the function echoes "true" and returns 0.
#   Otherwise, it echoes "false" and returns 1.
#
#   Sample Usage:
#   # Using the exit status:
#   if shell::conf::key::exists my_setting; then
#   echo "Key 'my_setting' exists."
#   else
#   echo "Key 'my_setting' does not exist."
#   fi
#
#   # Capturing the output:
#   result=$(shell::conf::key::exists my_setting)
#   if [ "$result" = "true" ]; then
#   echo "Key 'my_setting' exists."
#   else
#   echo "Key 'my_setting' does not exist."
#   fi
# @arg $1 string key: The configuration key to check.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::key::exists my_setting   # Echoes "true" and returns 0 if 'my_setting' exists; otherwise, echoes "false" and returns 1.
#
shell::conf::key::exists() {
	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Checks if a configuration key exists in the key configuration file"
		shell::logger::usage "shell::conf::key::exists [-h] <key>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "key" "The configuration key to check."
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::conf::key::exists [-h] <key>"
		return 1
	fi

	local key
	key="$(shell::strings::sanitize::upper "$1")"

	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	if grep -q "^${key}=" "$SHELL_KEY_FILE"; then
		echo "true"
		return 0
	else
		echo "false"
		return 1
	fi
}

# @description Renames an existing configuration key in the key configuration file.
#
#   The function reads the configuration file defined by SHELL_KEY_FILE, which stores entries in the format:
#   key=encoded_value
#   It uses fzf to interactively select an existing key.
#   After selection, the function prompts for a new key name and checks if the new key already exists.
#   If the new key does not exist, it constructs a sed command to replace the old key with the new key in the file.
#   The sed command uses in-place editing options appropriate for macOS (sed -i '') or Linux (sed -i).
#   In dry-run mode, the command is printed via shell::logger::command_clip; otherwise, it is executed using shell::exec::shell.
# @option -n Optional dry-run flag. If provided, the renaming command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::key::rename::fzf         # Interactively select a key and rename it.
#   shell::conf::key::rename::fzf -n      # Prints the renaming command without executing it.
#
shell::conf::key::rename::fzf() {
	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Renames an existing configuration key in the key configuration file"
		shell::logger::usage "shell::conf::key::rename::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the renaming command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::conf::key::rename::fzf"
		shell::logger::example "shell::conf::key::rename::fzf -n"
		return $RETURN_SUCCESS
	fi

	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure

	# Use fzf to select an existing key.
	local old_key
	# old_key=$(cut -d '=' -f 1 "$SHELL_KEY_FILE" | fzf --prompt="Select a key to rename: ")
	old_key=$(grep -v '^\s*#' "$SHELL_KEY_FILE" | cut -d '=' -f 1 | fzf --prompt="Select config key to rename: ")
	if [ -z "$old_key" ]; then
		shell::logger::error "No key selected. Aborting rename."
		return 1
	fi

	if [ "$(shell::conf::protected::is "$old_key")" = "true" ]; then
		shell::logger::error "'$old_key' is a protected key and cannot be modified."
		return 1
	fi

	# Prompt for the new key name.
	shell::console::print "Enter new key name for '$old_key':" 33
	read -r new_key
	if [ -z "$new_key" ]; then
		shell::logger::error "No new key name entered. Aborting rename."
		return 1
	fi

	# sanitized key
	new_key=$(shell::strings::sanitize::upper "$new_key")

	# Check if the new key already exists.
	local exist
	exist=$(shell::conf::key::exists "$new_key")
	if [ "$exist" = "true" ]; then
		shell::logger::error "Key '$new_key' already exists. Aborting rename."
		return 1
	fi

	local os_type
	os_type=$(shell::os::type)
	local sed_cmd=""

	# Construct the sed command to replace the key name.
	if [ "$os_type" = "macos" ]; then
		sed_cmd="shell::fs::sed_inplace \"s/^${old_key}=/${new_key}=/\" \"$SHELL_KEY_FILE\""
	else
		sed_cmd="shell::fs::sed_inplace \"s/^${old_key}=/${new_key}=/\" \"$SHELL_KEY_FILE\""
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$sed_cmd"
	else
		shell::exec::shell "$sed_cmd"
		shell::logger::success "Renamed key '$old_key' to '$new_key'"
	fi
}

# @description Checks if the specified configuration key is protected.
#
#   This function iterates over the SHELL_PROTECTED_KEYS array to determine if the given key is marked as protected.
#   If the key is found in the array, the function echoes "true" and returns 0.
#   Otherwise, it echoes "false" and returns 1.
# @arg $1 string key: The configuration key to check.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   if shell::conf::protected::is "HOST"; then
#   shell::console::print "ERR: 'HOST' is a protected key and cannot be modified." 196
#   return 1
#   fi
#
shell::conf::protected::is() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Checks if the specified configuration key is protected"
		shell::logger::usage "shell::conf::protected::is [-h] <key>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "key" "The configuration key to check."
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::conf::protected::is <key>"
		return 1
	fi

	local key="$1"
	local file="$SHELL_KEY_PROTECTED_FILE"

	# Check if the key exists in the protected configuration file.
	# If the key is found, echo "true" and return 0.
	if [ -f "$file" ] && grep -q "^${key}$" "$file"; then
		echo "true"
		return 0
	fi

	# If the key is not found in the protected configuration file,
	# check against the SHELL_PROTECTED_KEYS array.
	if [ -z "${SHELL_PROTECTED_KEYS+x}" ]; then
		shell::logger::error "SHELL_PROTECTED_KEYS array is not defined."
		return 1
	fi
	# Iterate over the SHELL_PROTECTED_KEYS array to check if the key is protected.
	# If the key matches any entry in the array, echo "true" and return 0.
	for protected in "${SHELL_PROTECTED_KEYS[@]}"; do
		if [ "$protected" = "$key" ]; then
			echo "true"
			return 0
		fi
	done

	echo "false"
	return 1
}

# @description Groups selected configuration keys under a specified group name.
#
#   This function prompts you to enter a group name, then uses fzf (with multi-select) to let you choose
#   one or more configuration keys (from SHELL_KEY_FILE). It then stores the group in SHELL_KEY_GROUP_FILE in the format:
#   group_name=key1,key2,...,keyN
#   If the group name already exists, the group entry is updated with the new selection.
#   An optional dry-run flag (-n) can be used to print the command via shell::logger::command_clip instead of executing it.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::group::add::fzf         # Prompts for a group name and lets you select keys to group.
#   shell::conf::group::add::fzf -n      # Prints the command for creating/updating the group without executing it.
#
shell::conf::group::add::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Groups selected configuration keys under a specified group name"
		shell::logger::usage "shell::conf::group::add::fzf [-n] [-h]"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::conf::group::add::fzf"
		shell::logger::example "shell::conf::group::add::fzf -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Ensure the group configuration file exists.
	shell::fs::touch --private "$SHELL_KEY_GROUP_FILE"
	shell::permission::secure "$SHELL_KEY_GROUP_FILE"

	# Prompt the user for a group name.
	shell::console::print "[e] Enter group name:" 208
	read -r group_name
	if [ -z "$group_name" ]; then
		shell::logger::error "No group name entered. Aborting."
		return 1
	fi

	# Ensure the individual configuration file exists.
	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	# Ensure fzf is installed.
	shell::dependency::fzf::ensure

	# Sanitize the group name to ensure it is a valid variable name.
	# This is done to avoid issues with special characters or spaces in the group name.
	# shell::strings::sanitize::upper function is expected to be defined elsewhere in the script.
	group_name=$(shell::strings::sanitize::upper "$group_name")

	# Use fzf with multi-select to choose keys from SHELL_KEY_FILE.
	local selected_keys
	# selected_keys=$(cut -d '=' -f 1 "$SHELL_KEY_FILE" | fzf --multi --prompt="Select config keys for group '$group_name': ")
	selected_keys=$(grep -v '^\s*#' "$SHELL_KEY_FILE" | cut -d '=' -f 1 | fzf --multi --prompt="Select config keys for group '$group_name': ")

	# Check if any keys were selected.
	# If no keys were selected, print an error message and return.
	if [ -z "$selected_keys" ]; then
		shell::logger::error "No keys selected. Aborting group creation."
		return 1
	fi

	# Convert the multi-line selection to a comma-separated list.
	local keys_csv
	keys_csv=$(echo "$selected_keys" | paste -sd "," -)

	# Construct the group entry in the format: group_name=key1,key2,...,keyN
	local group_entry="${group_name}=${keys_csv}"

	# If the group already exists, update it; otherwise, append it.
	if grep -q "^${group_name}=" "$SHELL_KEY_GROUP_FILE"; then
		local os_type
		os_type=$(shell::os::type)
		local sed_cmd=""
		if [ "$os_type" = "macos" ]; then
			sed_cmd="shell::fs::sed_inplace \"s/^${group_name}=.*/${group_entry}/\" \"$SHELL_KEY_GROUP_FILE\""
		else
			sed_cmd="shell::fs::sed_inplace \"s/^${group_name}=.*/${group_entry}/\" \"$SHELL_KEY_GROUP_FILE\""
		fi
		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "$sed_cmd"
		else
			shell::exec::shell "$sed_cmd"
			shell::logger::success "Updated group '$group_name' with keys: $keys_csv"
		fi
	else
		local cmd="echo \"$group_entry\" >> \"$SHELL_KEY_GROUP_FILE\""
		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "$cmd"
		else
			shell::exec::shell "$cmd"
			shell::logger::success "Created group '$group_name' with keys: $keys_csv"
		fi
	fi
}

# @description Reads and displays the configurations for a given group by group name.
#
#   This function looks up the group entry in SHELL_KEY_GROUP_FILE for the specified group name.
#   The group entry is expected to be in the format:
#   group_name=key1,key2,...,keyN
#   For each key in the group, the function retrieves the corresponding configuration entry from SHELL_KEY_FILE,
#   decodes the Base64-encoded value (using -D on macOS and -d on Linux), and groups the key-value pairs
#   into a JSON object which is displayed.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::group::read my_group   # Displays the configurations for the keys in the group 'my_group'.
#
shell::conf::group::read() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Reads and displays the configurations for a given group by group name"
		shell::logger::usage "shell::conf::group::read [-h] <group_name>"
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::conf::group::read [-h] <group_name>"
		return 1
	fi

	local group_name="$1"

	# Check if the group configuration file exists.
	if [ ! -f "$SHELL_KEY_GROUP_FILE" ]; then
		shell::logger::error "Group configuration file '$SHELL_KEY_GROUP_FILE' not found."
		return 1
	fi

	# Sanitize the group name to ensure it is a valid variable name.
	# This is done to avoid issues with special characters or spaces in the group name.
	# shell::strings::sanitize::upper function is expected to be defined elsewhere in the script.
	group_name=$(shell::strings::sanitize::upper "$group_name")

	# Retrieve the group entry for the specified group name.
	local group_entry
	group_entry=$(grep "^${group_name}=" "$SHELL_KEY_GROUP_FILE")
	if [ -z "$group_entry" ]; then
		shell::logger::error "Group '$group_name' not found."
		return 1
	fi

	# Extract the comma-separated list of keys.
	local keys_csv
	keys_csv=$(echo "$group_entry" | cut -d '=' -f 2-)
	if [ -z "$keys_csv" ]; then
		shell::logger::error "No keys defined in group '$group_name'."
		return 1
	fi

	local os_type
	os_type=$(shell::os::type)
	local json_obj="{"
	local first=1

	# Convert the comma-separated keys to an array in a way compatible with both Bash and zsh.
	if [ -n "$BASH_VERSION" ]; then
		IFS=',' read -r -a keys_array <<<"$keys_csv"
	else
		IFS=',' read -rA keys_array <<<"$keys_csv"
	fi

	for key in "${keys_array[@]}"; do
		# Retrieve the configuration entry from SHELL_KEY_FILE for each key.
		local conf_line
		conf_line=$(grep "^${key}=" "$SHELL_KEY_FILE")
		if [ -z "$conf_line" ]; then
			continue
		fi

		local encoded_value
		encoded_value=$(echo "$conf_line" | cut -d '=' -f 2-)
		local decoded_value
		if [ "$os_type" = "macos" ]; then
			decoded_value=$(echo "$encoded_value" | base64 -D)
		else
			decoded_value=$(echo "$encoded_value" | base64 -d)
		fi

		# Append a comma if not the first key.
		if [ $first -eq 0 ]; then
			json_obj+=","
		else
			first=0
		fi

		json_obj+="\"$key\":\"$decoded_value\""
	done

	json_obj+="}"
	shell::console::print "$json_obj" 33
	shell::clipboard::copy --best-effort "$json_obj"
}

# @description Interactively selects a group name from the group configuration file using fzf,
#   then removes the corresponding group entry.
#
#   The function extracts group names from SHELL_KEY_GROUP_FILE and uses fzf for interactive selection.
#   Once a group is selected, it constructs a sed command (with appropriate in-place options for macOS or Linux)
#   to remove the line that starts with "group_name=".
#   If the file is not writable, sudo is prepended. In dry-run mode, the command is printed via shell::logger::command_clip.
# @option -n Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::group::remove::fzf         # Interactively select a group and remove its entry.
#   shell::conf::group::remove::fzf -n      # Prints the removal command without executing it.
#
shell::conf::group::remove::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a group name from the group configuration file using fzf, then removes the corresponding group entry"
		shell::logger::usage "shell::conf::group::remove::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::conf::group::remove::fzf"
		shell::logger::example "shell::conf::group::remove::fzf -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	if [ ! -f "$SHELL_KEY_GROUP_FILE" ]; then
		shell::logger::error "Group configuration file '$SHELL_KEY_GROUP_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure

	local selected_group
	selected_group=$(cut -d '=' -f 1 "$SHELL_KEY_GROUP_FILE" | fzf --prompt="Select a group to remove: ")
	if [ -z "$selected_group" ]; then
		shell::logger::error "No group selected."
		return 1
	fi

	local os_type
	os_type=$(shell::os::type)
	local sed_cmd=""

	if [ "$os_type" = "macos" ]; then
		sed_cmd="shell::fs::sed_inplace \"/^${selected_group}=/d\" \"$SHELL_KEY_GROUP_FILE\""
	else
		sed_cmd="shell::fs::sed_inplace \"/^${selected_group}=/d\" \"$SHELL_KEY_GROUP_FILE\""
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$sed_cmd"
	else
		shell::exec::shell "$sed_cmd"
		shell::logger::success "Removed group: $selected_group"
	fi
}

# @description Interactively updates an existing group by letting you select new keys for that group.
#
#   The function reads SHELL_KEY_GROUP_FILE and uses fzf to let you select an existing group.
#   It then presents all available keys from SHELL_KEY_FILE (via fzf with multi-select) for you to choose the new group membership.
#   The selected keys are converted into a comma-separated list, and the group entry is updated in SHELL_KEY_GROUP_FILE
#   (using sed with options appropriate for macOS or Linux). If the file is not writable, sudo is used.
# @option -n Optional dry-run flag. If provided, the update command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::group::update::fzf         # Interactively select a group, update its keys, and update the group entry.
#   shell::conf::group::update::fzf -n      # Prints the update command without executing it.
#
shell::conf::group::update::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively updates an existing group by letting you select new keys for that group"
		shell::logger::usage "shell::conf::group::update::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the update command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::conf::group::update::fzf"
		shell::logger::example "shell::conf::group::update::fzf -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	if [ ! -f "$SHELL_KEY_GROUP_FILE" ]; then
		shell::logger::error "Group configuration file '$SHELL_KEY_GROUP_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure

	# Select the group to update.
	local selected_group
	selected_group=$(cut -d '=' -f 1 "$SHELL_KEY_GROUP_FILE" | fzf --prompt="Select a group to update: ")
	if [ -z "$selected_group" ]; then
		shell::logger::error "No group selected."
		return 1
	fi

	# Ensure the individual configuration file exists.
	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	# Let the user select new keys for the group from all available keys.
	local new_keys
	# new_keys=$(cut -d '=' -f 1 "$SHELL_KEY_FILE" | fzf --multi --prompt="Select new keys for group '$selected_group': " | paste -sd "," -)
	new_keys=$(grep -v '^\s*#' "$SHELL_KEY_FILE" | cut -d '=' -f 1 | fzf --multi --prompt="Select new keys for group '$selected_group': " | paste -sd "," -)

	# Check if any keys were selected.
	# If no keys were selected, print an error message and return.
	if [ -z "$new_keys" ]; then
		shell::logger::error "No keys selected. Aborting update."
		return 1
	fi

	local new_group_entry="${selected_group}=${new_keys}"
	local os_type
	os_type=$(shell::os::type)
	local sed_cmd=""

	if [ "$os_type" = "macos" ]; then
		sed_cmd="shell::fs::sed_inplace \"s/^${selected_group}=.*/${new_group_entry}/\" \"$SHELL_KEY_GROUP_FILE\""
	else
		sed_cmd="shell::fs::sed_inplace \"s/^${selected_group}=.*/${new_group_entry}/\" \"$SHELL_KEY_GROUP_FILE\""
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$sed_cmd"
	else
		shell::exec::shell "$sed_cmd"
		shell::logger::success "Updated group '$selected_group' with new keys: $new_keys"
	fi
}

# @description Renames an existing group in the group configuration file.
#
#   The function reads the group configuration file (SHELL_KEY_GROUP_FILE) where each line is in the format:
#   group_name=key1,key2,...,keyN
#   It uses fzf to let you select an existing group to rename.
#   After selection, the function prompts for a new group name.
#   It then constructs a sed command to replace the old group name with the new one in the configuration file.
#   The sed command uses in-place editing options appropriate for macOS (sed -i '') or Linux (sed -i).
#   In dry-run mode, the command is printed using shell::logger::command_clip; otherwise, it is executed using shell::exec::shell.
# @option -n Optional dry-run flag. If provided, the renaming command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::group::rename::fzf         # Interactively select a group and rename it.
#   shell::conf::group::rename::fzf -n      # Prints the renaming command without executing it.
#
shell::conf::group::rename::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Renames an existing group in the group configuration file"
		shell::logger::usage "shell::conf::group::rename::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the renaming command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::conf::group::rename::fzf"
		shell::logger::example "shell::conf::group::rename::fzf -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	if [ ! -f "$SHELL_KEY_GROUP_FILE" ]; then
		shell::logger::error "Group configuration file '$SHELL_KEY_GROUP_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure

	# Use fzf to let the user select an existing group.
	local old_group
	old_group=$(cut -d '=' -f 1 "$SHELL_KEY_GROUP_FILE" | fzf --prompt="Select group to rename: ")
	if [ -z "$old_group" ]; then
		shell::logger::error "No group selected. Aborting rename."
		return 1
	fi

	# Prompt for the new group name.
	shell::console::print "[e] Enter new name for group '$old_group':" 208
	read -r new_group
	if [ -z "$new_group" ]; then
		shell::logger::error "No new group name entered. Aborting rename."
		return 1
	fi

	# Sanitize the new group name to ensure it is a valid variable name.
	# This is done to avoid issues with special characters or spaces in the group name.
	# shell::strings::sanitize::upper function is expected to be defined elsewhere in the script.
	new_group=$(shell::strings::sanitize::upper "$new_group")

	# Construct the sed command to update the group name while preserving the keys.
	local os_type
	os_type=$(shell::os::type)
	local sed_cmd=""

	if [ "$os_type" = "macos" ]; then
		sed_cmd="shell::fs::sed_inplace \"s/^${old_group}=/${new_group}=/\" \"$SHELL_KEY_GROUP_FILE\""
	else
		sed_cmd="shell::fs::sed_inplace \"s/^${old_group}=/${new_group}=/\" \"$SHELL_KEY_GROUP_FILE\""
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$sed_cmd"
	else
		shell::exec::shell "$sed_cmd"
		shell::logger::success "Renamed group '$old_group' to '$new_group'"
	fi
}

# @description Lists all group names defined in the group configuration file.
#
#   This function reads the configuration file defined by SHELL_KEY_GROUP_FILE,
#   where each line is in the format:
#   group_name=key1,key2,...,keyN
#   It extracts and displays the group names (the part before the '=')
#   using the 'cut' command.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::group::list       # Displays all group names.
#
shell::conf::group::list() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Lists all group names defined in the group configuration file"
		shell::logger::usage "shell::conf::group::list [-h]"
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	if [ ! -f "$SHELL_KEY_GROUP_FILE" ]; then
		shell::logger::error "Group configuration file '$SHELL_KEY_GROUP_FILE' not found."
		return 1
	fi

	# Extract group names from the configuration file.
	local groups
	groups=$(cut -d '=' -f 1 "$SHELL_KEY_GROUP_FILE")
	if [ -z "$groups" ]; then
		shell::logger::error "No groups found in '$SHELL_KEY_GROUP_FILE'."
		return 1
	fi

	echo "$groups"
}

# @description Interactively selects a group name from the group configuration file using fzf,
#   then lists all keys belonging to the selected group and uses fzf to choose one key,
#   finally displaying the decoded value for the selected key.
#
#   The function reads the configuration file defined by SHELL_KEY_GROUP_FILE, where each line is in the format:
#   group_name=key1,key2,...,keyN
#   It first uses fzf to allow interactive selection of a group name.
#   Once a group is selected, the function extracts the comma-separated list of keys,
#   converts them into a list (one per line), and uses fzf again to let you choose one key.
#   It then retrieves the corresponding configuration entry from SHELL_KEY_FILE (which stores entries as key=encoded_value),
#   decodes the Base64-encoded value (using -D on macOS and -d on Linux), and displays the group name, key, and decoded value.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::group::view::fzf   # Prompts to select a group, then a key within that group, and displays the decoded value.
#
shell::conf::group::view::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a group name from the group configuration file using fzf, then lists all keys belonging to the selected group and uses fzf to choose one key, finally displaying the decoded value for the selected key"
		shell::logger::usage "shell::conf::group::view::fzf [-h]"
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	# Ensure the group configuration file exists.
	if [ ! -f "$SHELL_KEY_GROUP_FILE" ]; then
		shell::logger::error "Group configuration file '$SHELL_KEY_GROUP_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure

	# Extract group names from SHELL_KEY_GROUP_FILE and let the user select one.
	local groups
	groups=$(cut -d '=' -f 1 "$SHELL_KEY_GROUP_FILE")
	local selected_group
	selected_group=$(echo "$groups" | fzf --prompt="Select a group name: ")
	if [ -z "$selected_group" ]; then
		shell::logger::error "No group selected."
		return 1
	fi

	# Retrieve the group entry for the selected group.
	local group_entry
	group_entry=$(grep "^${selected_group}=" "$SHELL_KEY_GROUP_FILE")
	if [ -z "$group_entry" ]; then
		shell::logger::error "Group '$selected_group' not found in configuration."
		return 1
	fi

	# Extract the comma-separated list of keys.
	local keys_csv
	keys_csv=$(echo "$group_entry" | cut -d '=' -f 2-)
	if [ -z "$keys_csv" ]; then
		shell::logger::error "No keys defined in group '$selected_group'."
		return 1
	fi

	# Convert the comma-separated keys into a list (one per line) and use fzf to select one key.
	local selected_key
	selected_key=$(echo "$keys_csv" | tr ',' '\n' | fzf --prompt="Select a key from group '$selected_group': ")
	if [ -z "$selected_key" ]; then
		shell::logger::error "No key selected from group '$selected_group'."
		return 1
	fi

	# Ensure the individual configuration file exists.
	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	# Retrieve the configuration entry corresponding to the selected key.
	local conf_line
	conf_line=$(grep "^${selected_key}=" "$SHELL_KEY_FILE")
	if [ -z "$conf_line" ]; then
		shell::logger::error "Key '$selected_key' not found in configuration."
		return 1
	fi

	# Extract the encoded value.
	local encoded_value
	encoded_value=$(echo "$conf_line" | cut -d '=' -f 2-)

	# Decode the value based on the operating system.
	local os_type
	os_type=$(shell::os::type)
	local decoded_value
	if [ "$os_type" = "macos" ]; then
		decoded_value=$(echo "$encoded_value" | base64 -D)
	else
		decoded_value=$(echo "$encoded_value" | base64 -d)
	fi

	shell::console::print "[g] Group: $selected_group" 33
	shell::console::print "[k] Key: $selected_key" 33
	shell::clipboard::copy --best-effort "$decoded_value"
}

# @description Clones an existing group by creating a new group with the same keys.
#
#   The function reads the group configuration file (SHELL_KEY_GROUP_FILE) where each line is in the format:
#   group_name=key1,key2,...,keyN
#   It uses fzf to interactively select an existing group.
#   After selection, it prompts for a new group name.
#   The new group entry is then constructed with the new group name and the same comma-separated keys
#   as the selected group, and appended to SHELL_KEY_GROUP_FILE.
#   In dry-run mode, the final command is printed using shell::logger::command_clip; otherwise, it is executed using shell::exec::shell.
# @option -n Optional dry-run flag. If provided, the cloning command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::group::clone::fzf         # Interactively select a group and create a clone with a new group name.
#   shell::conf::group::clone::fzf -n      # Prints the cloning command without executing it.
#
shell::conf::group::clone::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Clones an existing group by creating a new group with the same keys"
		shell::logger::usage "shell::conf::group::clone::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the cloning command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Ensure the group configuration file exists.
	if [ ! -f "$SHELL_KEY_GROUP_FILE" ]; then
		shell::logger::error "Group configuration file '$SHELL_KEY_GROUP_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure

	# Use fzf to let the user select an existing group.
	local selected_group
	selected_group=$(cut -d '=' -f 1 "$SHELL_KEY_GROUP_FILE" | fzf --prompt="Select a group to clone: ")
	if [ -z "$selected_group" ]; then
		shell::logger::error "No group selected. Aborting clone."
		return 1
	fi

	# Retrieve the group entry to get the keys.
	local group_entry
	group_entry=$(grep "^${selected_group}=" "$SHELL_KEY_GROUP_FILE")
	if [ -z "$group_entry" ]; then
		shell::logger::error "Group '$selected_group' not found."
		return 1
	fi

	local keys_csv
	keys_csv=$(echo "$group_entry" | cut -d '=' -f 2-)
	if [ -z "$keys_csv" ]; then
		shell::logger::error "No keys defined in group '$selected_group'."
		return 1
	fi

	# Prompt for the new group name.
	shell::console::print "[e] Enter new group name for the clone of '$selected_group':" 208
	read -r new_group
	if [ -z "$new_group" ]; then
		shell::logger::error "No new group name entered. Aborting clone."
		return 1
	fi

	# Sanitize the new group name to ensure it is a valid variable name.
	# This is done to avoid issues with special characters or spaces in the group name.
	# shell::strings::sanitize::upper function is expected to be defined elsewhere in the script.
	new_group=$(shell::strings::sanitize::upper "$new_group")

	# Check if the new group name already exists.
	if grep -q "^${new_group}=" "$SHELL_KEY_GROUP_FILE"; then
		shell::logger::error "Group '$new_group' already exists."
		return 1
	fi

	# Construct the new group entry.
	local new_group_entry="${new_group}=${keys_csv}"

	# Build the command to append the new group entry.
	local cmd="echo \"$new_group_entry\" >> \"$SHELL_KEY_GROUP_FILE\""

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
	else
		shell::exec::shell "$cmd"
		shell::logger::success "Created new group '$new_group' as a clone of '$selected_group' with keys: $keys_csv"
	fi
}

# @description Synchronizes group configurations by ensuring that each group's keys exist in the key configuration file.
#   If a key listed in a group does not exist, it is removed from that group.
#   If a group ends up with no valid keys, that group entry is removed.
#
#   The function reads each group entry from SHELL_KEY_GROUP_FILE (entries in the format: group_name=key1,key2,...,keyN).
#   For each group, it splits the comma‑separated list of keys and checks each key using shell::conf::key::exists.
#   It builds a new list of valid keys. If the new list is non‑empty, the group entry is updated;
#   if it is empty, the group entry is omitted.
#   In dry‑run mode, the new group configuration is printed via shell::logger::command_clip without modifying the file.
# @option -n Optional dry-run flag. If provided, the new group configuration is printed using shell::logger::command_clip instead of being applied.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::group::sync         # Synchronizes the group configuration file.
#   shell::conf::group::sync -n      # Displays the updated group configuration without modifying the file.
#
shell::conf::group::sync() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Synchronizes group configurations by ensuring that each group's keys exist in the key configuration file"
		shell::logger::usage "shell::conf::group::sync [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the new group configuration is printed using shell::logger::command_clip instead of being applied."
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	if [ ! -f "$SHELL_KEY_GROUP_FILE" ]; then
		shell::logger::error "Group configuration file '$SHELL_KEY_GROUP_FILE' not found."
		return 1
	fi

	shell::logger::debug "Syncing group configuration..."

	# Create a temporary file for the updated configuration.
	local temp_file
	temp_file=$(mktemp) || {
		shell::logger::error "Unable to create temporary file."
		return 1
	}

	# Process each group entry.
	while IFS= read -r line || [ -n "$line" ]; do
		# Skip empty lines.
		[ -z "$line" ] && continue

		# Extract group name and keys.
		local group_name keys_csv
		group_name=$(echo "$line" | cut -d '=' -f 1)
		keys_csv=$(echo "$line" | cut -d '=' -f 2-)
		[ -z "$group_name" ] && continue

		# Build a new comma-separated list of valid keys.
		local new_keys=""
		# Use a portable loop to split keys_csv.
		while IFS= read -r key; do
			if [ "$(shell::conf::key::exists "$key")" = "true" ]; then
				if [ -z "$new_keys" ]; then
					new_keys="$key"
				else
					new_keys="${new_keys},${key}"
				fi
			fi
		done <<<"$(echo "$keys_csv" | tr ',' '\n')"

		if [ -n "$new_keys" ]; then
			echo "${group_name}=${new_keys}" >>"$temp_file"
		else
			shell::logger::warn "Group '$group_name' has no valid keys and will be removed."
		fi
	done <"$SHELL_KEY_GROUP_FILE"

	# If dry-run mode is enabled, print the new configuration and remove the temporary file.
	# Otherwise, replace the original configuration file with the new one.
	if [ "$dry_run" = "true" ]; then
		shell::clipboard::copy --best-effort "$(cat "$temp_file")"
		shell::exec::shell "rm $temp_file"
	else
		local backup_file="$SHELL_KEY_GROUP_BACKUP_FILE"
		# Change end of the backup file with YYYYMMDD format.
		backup_file="${backup_file}_$(date +%Y%m%d_%H%M%S)"
		# Check if the backup file does not exist, and create it if necessary.
		if [ ! -f "$backup_file" ]; then
			shell::fs::touch --private "$backup_file"
		fi
		shell::exec::shell "cp $SHELL_KEY_GROUP_FILE $backup_file"
		shell::exec::shell "mv $temp_file $SHELL_KEY_GROUP_FILE"
		shell::logger::success "Group configuration synchronized successfully."
	fi
}

# @description Interactively selects a configuration key using fzf and displays its decoded value in real-time.
#
#   This function checks if the configuration file exists. If not, it displays an error.
#   It then uses fzf to interactively select a configuration key from the file, showing
#   the Base64-decoded value in real-time in a preview window, formatted as "key (value)"
#   with the key in yellow and the value in cyan. Once a key is selected, its decoded value
#   is copied to the clipboard unless in dry-run mode, where the copy command is printed.
#
#   Notes:
#   - Compatible with both macOS and Linux.
#   - Uses ANSI color codes for formatting (yellow for key, cyan for value).
#   - The configuration file is expected to contain key=value pairs with Base64-encoded values.
# @option -n Optional dry-run flag. If provided, the clipboard copy command is printed instead of executed.
# @option -h Optional help flag. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::key::view::fzf         # Select a key and copy its decoded value.
#   shell::conf::key::view::fzf -n      # Dry-run: print the clipboard copy command.
#
shell::conf::key::view::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a configuration key using fzf and displays its decoded value in real-time"
		shell::logger::usage "shell::conf::key::view::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the clipboard copy command is printed instead of executed."
		shell::logger::option "-h" "Optional help flag. Displays this help message."
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Validate configuration file existence
	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	# Ensure fzf is installed
	shell::dependency::fzf::ensure || {
		shell::logger::error "fzf is required but could not be installed."
		return 1
	}

	# Define ANSI color codes using tput
	local yellow=$(tput setaf 3) # Yellow for key
	local cyan=$(tput setaf 6)   # Cyan for value
	local normal=$(tput sgr0)    # Reset to normal

	# Determine OS type for Base64 decoding
	local os_type
	os_type=$(shell::os::type)
	local base64_decode_cmd
	if [ "$os_type" = "macos" ]; then
		base64_decode_cmd="base64 -D"
	else
		base64_decode_cmd="base64 -d"
	fi

	# Prepare colored key list for fzf
	# local key_list
	# key_list=$(cut -d '=' -f 1 "$SHELL_KEY_FILE" | awk -v yellow="$yellow" -v normal="$normal" '{print yellow $0 normal}')
	# if [ -z "$key_list" ]; then
	#     shell::logger::error "No configuration keys found in '$SHELL_KEY_FILE'."
	#     return 1
	# fi
	# Use fzf with a preview window to show only the decoded value
	local selected_key
	# selected_key=$(echo "$key_list" | fzf --ansi \
	#     --prompt="Select config key: " \
	#     --preview="grep '^{}=.*' \"$SHELL_KEY_FILE\" | cut -d '=' -f 2- | $base64_decode_cmd 2>/dev/null || echo 'Invalid Base64'")

	# Use grep to filter out comments and then cut to get the key names
	# Use fzf to select a key, showing the decoded value in the preview
	# selected_key=$(grep -v '^\s*#' "$SHELL_KEY_FILE" | cut -d '=' -f 1 |
	#     fzf --ansi \
	#         --prompt="Select config key: " \
	#         --preview="grep -v '^\s*#' \"$SHELL_KEY_FILE\" | grep '^{}=' | cut -d '=' -f 2- | $base64_decode_cmd 2>/dev/null || echo 'Invalid Base64'" \
	#         --preview-window=up:3:wrap)

	selected_key=$(grep -v '^\s*#' "$SHELL_KEY_FILE" | cut -d '=' -f 1 | awk -v yellow="$yellow" -v normal="$normal" '{print yellow $0 normal}' |
		fzf --ansi \
			--prompt="Select config key: " \
			--preview="grep -v '^\s*#' \"$SHELL_KEY_FILE\" | grep '^{}=' | cut -d '=' -f 2- | $base64_decode_cmd 2>/dev/null || echo 'Invalid Base64'" \
			--preview-window=up:3:wrap)

	# Extract the uncolored key (remove ANSI codes)
	selected_key=$(echo "$selected_key" | sed "s/$(printf '\033')[0-9;]*m//g")

	if [ -z "$selected_key" ]; then
		shell::logger::error "No configuration key selected."
		return 1
	fi
	shell::logger::success "Selected key: $selected_key"
	shell::clipboard::copy "$(shell::conf::key::get "$selected_key")"
}

# @description Adds a key to the protected key list stored in protected.conf.
#
#   This function appends a key to the protected.conf file located at $SHELL_CONFIG_DIR/protected.conf.
#   If the key already exists in the file, it will not be added again.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.
# @arg $1 string key: The key to mark as protected.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::protected::add
#
shell::conf::protected::add() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Adds a key to the protected key list stored in protected.conf"
		shell::logger::usage "shell::conf::protected::add [-n] [-h] <key>"
		shell::logger::option "-n" "Optional. Dry-run mode. Prints the command without executing it."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "key" "The key to mark as protected."
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed."
		shell::logger::item "key" "The key to mark as protected."
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::conf::protected::add [-n] <key>"
		return 1
	fi

	local key="$1"
	local file="$SHELL_KEY_PROTECTED_FILE"

	# Check if the key is provided
	if [ -z "$key" ]; then
		shell::logger::error "No key provided to protect."
		return 1
	fi
	# Ensure the protected.conf file exists and has the correct permissions.
	if [ ! -d "$SHELL_CONFIG_DIR" ]; then
		shell::logger::error "Working directory '$SHELL_CONFIG_DIR' does not exist."
		return 1
	fi

	# Create the protected.conf file if it does not exist.
	# Use shell::fs::touch --private to ensure the file is created.
	# Set permissions to 777 for the file.
	shell::fs::touch --private "$file"
	shell::permission::secure "$file"

	# Check if the key is already protected.
	# Use grep to check if the key is already in the file.
	# The key is considered protected if it matches exactly (no partial matches).
	# Use ^ and $ to ensure we match the whole line.
	if grep -q "^${key}$" "$file"; then
		shell::logger::warn "Key '$key' is already protected."
		return 0
	fi

	# Append the key to the protected.conf file.
	# Use echo to append the key, ensuring it is quoted to handle special characters.
	# Use shell::logger::command_clip for dry-run mode, otherwise run the command.
	local cmd="echo \"$key\" >> \"$file\""
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
	else
		shell::exec::shell "$cmd"
		shell::logger::success "Protected key added: $key"
	fi
}

# @description Interactively selects a key from the configuration file and adds it to the protected list.
#
#   This function uses fzf to select a key from the configuration file (excluding comments),
#   and adds it to the protected.conf file.
# @option -n Optional. Dry-run mode. Prints the command without executing it.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::protected::add::fzf
#
shell::conf::protected::add::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a key from the configuration file and adds it to the protected list"
		shell::logger::usage "shell::conf::protected::add::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional. Dry-run mode. Prints the command without executing it."
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Ensure the configuration file exists.
	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure

	local yellow=$(tput setaf 3)
	local normal=$(tput sgr0)

	# Use fzf to select a key from the configuration file.
	# Exclude comments and format the output with colors.
	# Use grep to filter out comments and then cut to get the key names.
	# Use awk to color the selected key.
	local selected_key_colored
	selected_key_colored=$(grep -v '^\s*#' "$SHELL_KEY_FILE" | cut -d '=' -f 1 |
		awk -v yellow="$yellow" -v normal="$normal" '{print yellow $0 normal}' |
		fzf --ansi --prompt="Select key to protect: ")

	local selected_key
	selected_key=$(echo "$selected_key_colored" | sed "s/$(printf '\033')[0-9;]*m//g")

	# Check if a key was selected.
	# If no key was selected, print an error message and return.
	if [ -z "$selected_key" ]; then
		shell::logger::error "No key selected."
		return 1
	fi

	# Verify dry-run mode.
	# If dry-run mode is enabled, print the command to add the protected key.
	# Otherwise, call shell::conf::protected::add to add the key.
	if [ "$dry_run" = "true" ]; then
		shell::conf::protected::add "-n" "$selected_key"
	else
		shell::conf::protected::add "$selected_key"
	fi
}

# @description Interactively selects a protected key using fzf and removes it from protected.conf.
#
#   This function reads the protected.conf file, uses fzf to let the user select a key,
#   and removes the selected key using sed. In dry-run mode, the command is printed instead of executed.
# @option -n Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::protected::remove::fzf
#
shell::conf::protected::remove::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a protected key using fzf and removes it from protected.conf"
		shell::logger::usage "shell::conf::protected::remove::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	local file="$SHELL_KEY_PROTECTED_FILE"
	# Check if the protected.conf file exists.
	# If it does not exist, print an error message and return.
	if [ ! -f "$file" ]; then
		shell::logger::error "Protected key file '$file' not found."
		return 1
	fi

	# Ensure fzf is installed.
	shell::dependency::fzf::ensure

	# Use fzf to select a protected key.
	# Exclude comments and use fzf to let the user select a key.
	# Use grep to filter out comments and then use fzf to select a key.
	local selected_key
	selected_key=$(grep -v '^\s*#' "$file" | fzf --prompt="Select protected key to remove: ")

	if [ -z "$selected_key" ]; then
		shell::logger::error "No key selected."
		return 1
	fi

	local os_type
	os_type=$(shell::os::type)
	local sed_cmd=""
	if [ "$os_type" = "macos" ]; then
		sed_cmd="shell::fs::sed_inplace \"/^${selected_key}$/d\" \"$file\"" # Use sed with -i '' for macOS compatibility
	else
		sed_cmd="shell::fs::sed_inplace \"/^${selected_key}$/d\" \"$file\"" # Use sed with -i for Linux compatibility
	fi

	# If dry-run mode is enabled, print the command to remove the protected key.
	# Otherwise, execute the command to remove the key.
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$sed_cmd"
	else
		shell::exec::shell "$sed_cmd"
		shell::logger::success "Removed protected key: $selected_key"
	fi
}

# @description Synchronizes the protected.conf file by removing keys that no longer exist in key.conf.
#
#   This function compares the keys listed in protected.conf with those in key.conf.
#   Any protected key that is not found in key.conf will be removed.
#   In dry-run mode, the updated list is printed instead of being written to the file.
# @option -n Optional dry-run flag. If provided, the updated protected.conf is printed using shell::logger::command_clip instead of being applied.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::protected::sync
#
shell::conf::protected::sync() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Synchronizes the protected.conf file by removing keys that no longer exist in key.conf"
		shell::logger::usage "shell::conf::protected::sync [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the updated protected.conf is printed using shell::logger::command_clip instead of being applied."
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	local key_file="$SHELL_KEY_FILE"
	local protected_file="$SHELL_KEY_PROTECTED_FILE"

	# Check if the protected.conf file and key.conf file exist.
	# If either file does not exist, print an error message and return.
	if [ ! -f "$protected_file" ]; then
		shell::logger::error "Protected key file '$protected_file' not found."
		return 1
	fi

	# Check if the key configuration file exists.
	# If it does not exist, print an error message and return.
	if [ ! -f "$key_file" ]; then
		shell::logger::error "Key configuration file '$key_file' not found."
		return 1
	fi

	shell::logger::debug "Syncing protected keys..."

	# Create a temporary file to store the updated protected keys.
	# Use mktemp to create a temporary file for the updated protected keys.
	local temp_file
	temp_file=$(mktemp) || {
		shell::logger::error "Unable to create temporary file."
		return 1
	}

	# Read the protected keys from the protected.conf file.
	# Use a while loop to read each line from the protected.conf file.
	# For each key, check if it exists in the key.conf file.
	# If the key exists, write it to the temporary file.
	# If the key does not exist, print a warning message.
	while IFS= read -r key; do
		[ -z "$key" ] && continue
		if grep -q "^${key}=" "$key_file"; then
			echo "$key" >>"$temp_file"
		else
			shell::logger::warn "Removing undefined protected key: $key"
		fi
	done <"$protected_file"

	# If dry-run mode is enabled, print the updated protected keys and remove the temporary file.
	# Otherwise, move the temporary file to the protected.conf file.
	if [ "$dry_run" = "true" ]; then
		shell::logger::debug "Dry-run: Updated protected keys:"
		cat "$temp_file"
		shell::exec::shell "rm \"$temp_file\""
	else
		shell::exec::shell "mv \"$temp_file\" \"$protected_file\""
		shell::logger::success "Protected keys synchronized successfully."
	fi
}
