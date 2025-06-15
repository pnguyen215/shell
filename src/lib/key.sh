#!/bin/bash
# key.sh

# shell::read_conf function
# Sources a configuration file, allowing its variables and functions to be loaded into the current shell.
#
# Usage:
#   shell::read_conf [-n] <filename>
#
# Parameters:
#   - -n       : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#   - <filename>: The configuration file to source.
#
# Description:
#   The function checks that a filename is provided and that the specified file exists.
#   If the file is not found, an error message is displayed.
#   In dry-run mode, the command "source <filename>" is printed using shell::on_evict.
#   Otherwise, the file is sourced using shell::run_cmd to log the execution.
#
# Example:
#   shell::read_conf ~/.my-config                # Sources the configuration file.
#   shell::read_conf -n ~/.my-config             # Prints the sourcing command without executing it.
shell::read_conf() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_READ_CONF"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if a filename is provided.
    if [ $# -lt 1 ]; then
        echo "Usage: shell::read_conf [-n] <filename>"
        return 1
    fi

    local filename="$1"

    # Verify that the configuration file exists.
    if [[ ! -f "$filename" ]]; then
        shell::colored_echo "ERR: Conf file '$filename' not found." 196
        return 1
    fi

    # Check if dry mode is enabled.
    # If so, print the command to source the file.
    # Otherwise, source the file.
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "source \"$filename\""
    else
        shell::run_cmd source "$filename"
    fi
}

# shell::add_key_conf function
# Adds a configuration entry (key=value) to a constant configuration file.
# The value is encoded using Base64 before being saved.
#
# Usage:
#   shell::add_key_conf [-n] <key> <value>
#
# Parameters:
#   - -n       : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#   - <key>    : The configuration key.
#   - <value>  : The configuration value to be encoded and saved.
#
# Description:
#   The function first checks for an optional dry-run flag (-n) and verifies that both key and value are provided.
#   It encodes the value using Base64 (with newline characters removed) and then appends a line in the format:
#       key=encoded_value
#   to a constant configuration file (defined by SHELL_KEY_CONF_FILE). If the configuration file does not exist, it is created.
#
# Example:
#   shell::add_key_conf my_setting "some secret value"         # Encodes the value and adds the entry.
#   shell::add_key_conf -n my_setting "some secret value"      # Prints the command without executing it.
shell::add_key_conf() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ADD_KEY_CONF"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if a key and value are provided.
    # If not, print usage information and return an error.
    if [ $# -lt 2 ]; then
        echo "Usage: shell::add_key_conf [-n] <key> <value>"
        return 1
    fi

    local key="$1"
    local value="$2"
    key=$(shell::sanitize_upper_var_name "$key")

    # Encode the value using Base64 and remove any newlines.
    local encoded_value
    encoded_value=$(echo -n "$value" | base64 | tr -d '\n')

    # Ensure the configuration file exists.
    shell::create_file_if_not_exists "$SHELL_KEY_CONF_FILE"
    shell::unlock_permissions "$SHELL_KEY_CONF_FILE"

    # Build the command to append the key and encoded value to the configuration file.
    local cmd="echo \"$key=$encoded_value\" >> \"$SHELL_KEY_CONF_FILE\""

    # Check if the dry mode is enabled.
    # If so, print the command to be executed.
    # Otherwise, execute the command to add the configuration entry.
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        result=$(shell::exist_key_conf $key)
        if [ "$result" = "true" ]; then
            shell::colored_echo "WARN: The key '$key' exists. Please consider updating it by using shell::fzf_update_key_conf" 11
            return 0
        fi
        shell::run_cmd_eval "$cmd"
        shell::colored_echo "INFO: Added configuration: $key (encoded value)" 46
    fi
}

# shell::add_key_conf_comment function
# Adds a configuration entry (key=value) with an optional comment to the constant configuration file.
# The value is encoded using Base64 before being saved.
#
# Usage:
# shell::add_key_conf_comment [-n] <key> <value> [comment]
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
# - <key> : The configuration key.
# - <value> : The configuration value to be encoded and saved.
# - [comment] : Optional comment to be added above the key-value pair.
#
# Description:
# This function encodes the value using Base64 (with newline characters removed) and appends a line in the format:
# # comment (if provided)
# key=encoded_value
# to the configuration file defined by SHELL_KEY_CONF_FILE.
# If the key already exists, a warning is shown and the function exits.
#
# Example:
# shell::add_key_conf_comment my_key "my secret" "This is a comment"
# shell::add_key_conf_comment -n my_key "my secret" "Dry-run with comment"
shell::add_key_conf_comment() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ADD_KEY_CONF_COMMENT"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -lt 2 ]; then
        echo "Usage: shell::add_key_conf_comment [-n] <key> <value> [comment]"
        return 1
    fi

    local key="$1"
    local value="$2"
    local comment="$3"

    key=$(shell::sanitize_upper_var_name "$key")

    # Encode the value using Base64 and remove any newlines
    local encoded_value
    encoded_value=$(echo -n "$value" | base64 | tr -d '\n')

    # Ensure the configuration file exists
    shell::create_file_if_not_exists "$SHELL_KEY_CONF_FILE"
    shell::unlock_permissions "$SHELL_KEY_CONF_FILE"

    # Check if the key already exists
    if [ "$(shell::exist_key_conf "$key")" = "true" ]; then
        shell::colored_echo "WARN: The key '$key' exists. Please consider updating it by using shell::fzf_update_key_conf" 11
        return 0
    fi

    # Build the command to append the comment and key-value pair
    local cmd=""
    if [ -n "$comment" ]; then
        cmd="echo \"# $comment\" >> \"$SHELL_KEY_CONF_FILE\" && "
    fi
    cmd+="echo \"$key=$encoded_value\" >> \"$SHELL_KEY_CONF_FILE\""

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::run_cmd_eval "$cmd"
        shell::colored_echo "INFO: Added configuration: $key (encoded value) with comment" 46
    fi
}

# shell::fzf_get_key_conf function
# Interactively selects a configuration key from a constant configuration file using fzf,
# then decodes and displays its corresponding value.
#
# Usage:
#   shell::fzf_get_key_conf
#
# Description:
#   The function reads the configuration file defined by the constant SHELL_KEY_CONF_FILE,
#   which is expected to have entries in the format:
#       key=encoded_value
#   Instead of listing the entire line, it extracts only the keys (before the '=') and uses fzf
#   for interactive selection. Once a key is selected, it looks up the full entry,
#   decodes the Base64-encoded value (using -D on macOS and -d on Linux), and then displays the key
#   and its decoded value.
#
# Example:
#   shell::fzf_get_key_conf      # Interactively select a key and display its decoded value.
shell::fzf_get_key_conf() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_GET_KEY_CONF"
        return 0
    fi

    if [ ! -f "$SHELL_KEY_CONF_FILE" ]; then
        shell::colored_echo "ERR: Configuration file '$SHELL_KEY_CONF_FILE' not found." 196
        return 1
    fi

    shell::install_package fzf

    # Extract only the keys from the configuration file and select one using fzf.
    local selected_key
    # selected_key=$(cut -d '=' -f 1 "$SHELL_KEY_CONF_FILE" | fzf --prompt="Select config key: ")
    selected_key=$(grep -v '^\s*#' "$SHELL_KEY_CONF_FILE" | cut -d '=' -f 1 | fzf --prompt="Select config key: ")
    if [ -z "$selected_key" ]; then
        shell::colored_echo "ERR: No configuration selected." 196
        return 1
    fi

    # Retrieve the full line corresponding to the selected key.
    local selected_line
    selected_line=$(grep "^${selected_key}=" "$SHELL_KEY_CONF_FILE")
    if [ -z "$selected_line" ]; then
        shell::colored_echo "ERR: Selected key '$selected_key' not found in configuration." 196
        return 1
    fi

    local encoded_value
    encoded_value=$(echo "$selected_line" | cut -d '=' -f 2-)

    local os_type
    os_type=$(shell::get_os_type)
    local decoded_value
    if [ "$os_type" = "macos" ]; then
        decoded_value=$(echo "$encoded_value" | base64 -D)
    else
        decoded_value=$(echo "$encoded_value" | base64 -d)
    fi

    shell::colored_echo "[k] Key: $selected_key" 33
    shell::clip_value "$decoded_value"
}

# shell::get_key_conf_value function
# Retrieves and outputs the decoded value for a given configuration key from the key configuration file.
#
# Usage:
#   shell::get_key_conf_value <key>
#
# Parameters:
#   - <key>: The configuration key whose value should be retrieved.
#
# Description:
#   This function searches for the specified key in the configuration file defined by SHELL_KEY_CONF_FILE.
#   The configuration file is expected to have entries in the format:
#       key=encoded_value
#   If the key is found, the function decodes the associated Base64‑encoded value (using -D on macOS and -d on Linux)
#   and outputs the decoded value to standard output.
#
# Example:
#   shell::get_key_conf_value my_setting   # Outputs the decoded value for the key 'my_setting'.
shell::get_key_conf_value() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GET_KEY_CONF_VALUE"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::get_key_conf_value [-h] <key>"
        return 1
    fi

    local key="$1"

    if [ ! -f "$SHELL_KEY_CONF_FILE" ]; then
        shell::colored_echo "ERR: Configuration file '$SHELL_KEY_CONF_FILE' not found." 196
        return 1
    fi

    local conf_line
    conf_line=$(grep "^${key}=" "$SHELL_KEY_CONF_FILE")
    if [ -z "$conf_line" ]; then
        shell::colored_echo "ERR: Key '$key' not found in configuration." 196
        return 1
    fi

    local encoded_value
    encoded_value=$(echo "$conf_line" | cut -d '=' -f 2-)

    local os_type
    os_type=$(shell::get_os_type)
    local decoded_value
    if [ "$os_type" = "macos" ]; then
        decoded_value=$(echo "$encoded_value" | base64 -D)
    else
        decoded_value=$(echo "$encoded_value" | base64 -d)
    fi

    echo "$decoded_value"
}

# shell::fzf_remove_key_conf function
# Interactively selects a configuration key from a constant configuration file using fzf,
# then removes the corresponding entry from the configuration file.
#
# Usage:
#   shell::fzf_remove_key_conf [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the removal command is printed using shell::on_evict instead of executed.
#
# Description:
#   The function reads the configuration file defined by the constant SHELL_KEY_CONF_FILE, where each entry is in the format:
#       key=encoded_value
#   It extracts only the keys (before the '=') and uses fzf for interactive selection.
#   Once a key is selected, it constructs a command to remove the line that starts with "key=" from the configuration file.
#   The command uses sed with different options depending on the operating system (macOS or Linux).
#   In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.
#
# Example:
#   shell::fzf_remove_key_conf         # Interactively select a key and remove its configuration entry.
#   shell::fzf_remove_key_conf -n      # Prints the removal command without executing it.
shell::fzf_remove_key_conf() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_REMOVE_KEY_CONF"
        return 0
    fi

    if [ ! -f "$SHELL_KEY_CONF_FILE" ]; then
        shell::colored_echo "ERR: Configuration file '$SHELL_KEY_CONF_FILE' not found." 196
        return 1
    fi

    shell::install_package fzf

    # Extract only the keys from the configuration file and select one using fzf.
    local selected_key
    # selected_key=$(cut -d '=' -f 1 "$SHELL_KEY_CONF_FILE" | fzf --prompt="Select config key to remove: ")
    selected_key=$(grep -v '^\s*#' "$SHELL_KEY_CONF_FILE" | cut -d '=' -f 1 | fzf --prompt="Select config key to remove: ")
    if [ -z "$selected_key" ]; then
        shell::colored_echo "ERR: No configuration selected." 196
        return 1
    fi

    if [ "$(shell::is_protected_key_conf "$selected_key")" = "true" ]; then
        shell::colored_echo "ERR: '$selected_key' is a protected key and cannot be modified." 196
        return 1
    fi

    local os_type
    os_type=$(shell::get_os_type)
    local sed_cmd=""
    local use_sudo="sudo "

    # Check if the configuration file is writable; if not, use sudo.
    # if [ ! -w "$SHELL_KEY_CONF_FILE" ]; then
    #     use_sudo="sudo "
    # fi

    # Construct the sed command to remove the line starting with "selected_key="
    if [ "$os_type" = "macos" ]; then
        # On macOS, use sed -i '' for in-place editing.
        sed_cmd="${use_sudo}sed -i '' \"/^${selected_key}=/d\" \"$SHELL_KEY_CONF_FILE\""
    else
        # On Linux, use sed -i for in-place editing.
        sed_cmd="${use_sudo}sed -i \"/^${selected_key}=/d\" \"$SHELL_KEY_CONF_FILE\""
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$sed_cmd"
    else
        shell::run_cmd_eval "$sed_cmd"
        shell::colored_echo "INFO: Removed configuration for key: $selected_key" 46
    fi
}

# shell::fzf_update_key_conf function
# Interactively updates the value for a configuration key in a constant configuration file.
# The new value is encoded using Base64 before updating the file.
#
# Usage:
#   shell::fzf_update_key_conf [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the update command is printed using shell::on_evict instead of executed.
#
# Description:
#   The function reads the configuration file defined by SHELL_KEY_CONF_FILE, which contains entries in the format:
#       key=encoded_value
#   It extracts only the keys and uses fzf to allow interactive selection.
#   Once a key is selected, the function prompts for a new value, encodes it using Base64 (with newlines removed),
#   and then updates the corresponding configuration entry in the file by replacing the line starting with "key=".
#   The sed command used for in-place update differs between macOS and Linux.
#
# Example:
#   shell::fzf_update_key_conf       # Interactively select a key, enter a new value, and update its entry.
#   shell::fzf_update_key_conf -n    # Prints the update command without executing it.
shell::fzf_update_key_conf() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_UPDATE_KEY_CONF"
        return 0
    fi

    if [ ! -f "$SHELL_KEY_CONF_FILE" ]; then
        shell::colored_echo "ERR: Configuration file '$SHELL_KEY_CONF_FILE' not found." 196
        return 1
    fi

    shell::install_package fzf

    # Extract only the keys from the configuration file and select one using fzf.
    local selected_key
    # selected_key=$(cut -d '=' -f 1 "$SHELL_KEY_CONF_FILE" | fzf --prompt="Select config key to update: ")
    selected_key=$(grep -v '^\s*#' "$SHELL_KEY_CONF_FILE" | cut -d '=' -f 1 | fzf --prompt="Select config key to update: ")
    if [ -z "$selected_key" ]; then
        shell::colored_echo "ERR: No configuration selected." 196
        return 1
    fi

    # Prompt the user for the new value.
    shell::colored_echo ">> Enter new value for key '$selected_key':" 33
    read -r new_value
    if [ -z "$new_value" ]; then
        shell::colored_echo "ERR: No new value entered. Update aborted." 196
        return 1
    fi

    # Encode the new value using Base64 and remove any newline characters.
    local encoded_value
    encoded_value=$(echo -n "$new_value" | base64 | tr -d '\n')

    local os_type
    os_type=$(shell::get_os_type)
    local sed_cmd=""
    local use_sudo="sudo "

    # Construct the sed command to update the line starting with "selected_key=".
    if [ "$os_type" = "macos" ]; then
        # For macOS, use sed -i '' for in-place editing.
        sed_cmd="${use_sudo}sed -i '' \"s/^${selected_key}=.*/${selected_key}=${encoded_value}/\" \"$SHELL_KEY_CONF_FILE\""
    else
        # For Linux, use sed -i for in-place editing.
        sed_cmd="${use_sudo}sed -i \"s/^${selected_key}=.*/${selected_key}=${encoded_value}/\" \"$SHELL_KEY_CONF_FILE\""
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$sed_cmd"
    else
        shell::run_cmd_eval "$sed_cmd"
        shell::colored_echo "INFO: Updated configuration for key: $selected_key" 46
    fi
}

# shell::exist_key_conf function
# Checks if a configuration key exists in the key configuration file.
#
# Usage:
#   shell::exist_key_conf <key>
#
# Parameters:
#   - <key>: The configuration key to check.
#
# Description:
#   This function searches for the specified key in the configuration file defined by SHELL_KEY_CONF_FILE.
#   The configuration file should have entries in the format:
#       key=encoded_value
#   If a line starting with "key=" is found, the function echoes "true" and returns 0.
#   Otherwise, it echoes "false" and returns 1.
#
# Sample Usage:
#   # Using the exit status:
#   if shell::exist_key_conf my_setting; then
#       echo "Key 'my_setting' exists."
#   else
#       echo "Key 'my_setting' does not exist."
#   fi
#
#   # Capturing the output:
#   result=$(shell::exist_key_conf my_setting)
#   if [ "$result" = "true" ]; then
#       echo "Key 'my_setting' exists."
#   else
#       echo "Key 'my_setting' does not exist."
#   fi
#
# Example:
#   shell::exist_key_conf my_setting   # Echoes "true" and returns 0 if 'my_setting' exists; otherwise, echoes "false" and returns 1.
shell::exist_key_conf() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_EXIST_KEY_CONF"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::exist_key_conf [-h] <key>"
        return 1
    fi

    local key="$1"

    if [ ! -f "$SHELL_KEY_CONF_FILE" ]; then
        shell::colored_echo "ERR: Configuration file '$SHELL_KEY_CONF_FILE' not found." 196
        return 1
    fi

    if grep -q "^${key}=" "$SHELL_KEY_CONF_FILE"; then
        echo "true"
        return 0
    else
        echo "false"
        return 1
    fi
}

# shell::fzf_rename_key_conf function
# Renames an existing configuration key in the key configuration file.
#
# Usage:
#   shell::fzf_rename_key_conf [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the renaming command is printed using shell::on_evict instead of executed.
#
# Description:
#   The function reads the configuration file defined by SHELL_KEY_CONF_FILE, which stores entries in the format:
#       key=encoded_value
#   It uses fzf to interactively select an existing key.
#   After selection, the function prompts for a new key name and checks if the new key already exists.
#   If the new key does not exist, it constructs a sed command to replace the old key with the new key in the file.
#   The sed command uses in-place editing options appropriate for macOS (sed -i '') or Linux (sed -i).
#   In dry-run mode, the command is printed via shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.
#
# Example:
#   shell::fzf_rename_key_conf         # Interactively select a key and rename it.
#   shell::fzf_rename_key_conf -n      # Prints the renaming command without executing it.
shell::fzf_rename_key_conf() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_RENAME_KEY_CONF"
        return 0
    fi

    if [ ! -f "$SHELL_KEY_CONF_FILE" ]; then
        shell::colored_echo "ERR: Configuration file '$SHELL_KEY_CONF_FILE' not found." 196
        return 1
    fi

    shell::install_package fzf

    # Use fzf to select an existing key.
    local old_key
    # old_key=$(cut -d '=' -f 1 "$SHELL_KEY_CONF_FILE" | fzf --prompt="Select a key to rename: ")
    old_key=$(grep -v '^\s*#' "$SHELL_KEY_CONF_FILE" | cut -d '=' -f 1 | fzf --prompt="Select config key to rename: ")
    if [ -z "$old_key" ]; then
        shell::colored_echo "ERR: No key selected. Aborting rename." 196
        return 1
    fi

    if [ "$(shell::is_protected_key_conf "$old_key")" = "true" ]; then
        shell::colored_echo "ERR: '$old_key' is a protected key and cannot be modified." 196
        return 1
    fi

    # Prompt for the new key name.
    shell::colored_echo "Enter new key name for '$old_key':" 33
    read -r new_key
    if [ -z "$new_key" ]; then
        shell::colored_echo "ERR: No new key name entered. Aborting rename." 196
        return 1
    fi

    # sanitized key
    new_key=$(shell::sanitize_upper_var_name "$new_key")

    # Check if the new key already exists.
    local exist
    exist=$(shell::exist_key_conf "$new_key")
    if [ "$exist" = "true" ]; then
        shell::colored_echo "ERR: Key '$new_key' already exists. Aborting rename." 196
        return 1
    fi

    local os_type
    os_type=$(shell::get_os_type)
    local sed_cmd=""
    local use_sudo="sudo "

    # Construct the sed command to replace the key name.
    if [ "$os_type" = "macos" ]; then
        sed_cmd="${use_sudo}sed -i '' \"s/^${old_key}=/${new_key}=/\" \"$SHELL_KEY_CONF_FILE\""
    else
        sed_cmd="${use_sudo}sed -i \"s/^${old_key}=/${new_key}=/\" \"$SHELL_KEY_CONF_FILE\""
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$sed_cmd"
    else
        shell::run_cmd_eval "$sed_cmd"
        shell::colored_echo "INFO: Renamed key '$old_key' to '$new_key'" 46
    fi
}

# shell::is_protected_key_conf function
# Checks if the specified configuration key is protected.
#
# Usage:
#   shell::is_protected_key_conf <key>
#
# Parameters:
#   - <key>: The configuration key to check.
#
# Description:
#   This function iterates over the SHELL_PROTECTED_KEYS array to determine if the given key is marked as protected.
#   If the key is found in the array, the function echoes "true" and returns 0.
#   Otherwise, it echoes "false" and returns 1.
#
# Example:
#   if shell::is_protected_key_conf "HOST"; then
#       shell::colored_echo "ERR: 'HOST' is a protected key and cannot be modified." 196
#       return 1
#   fi
shell::is_protected_key_conf() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_IS_PROTECTED_KEY_CONF"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::is_protected_key_conf <key>"
        return 1
    fi

    local key="$1"
    local file="$SHELL_KEY_CONF_FILE_PROTECTED"

    # Check if the key exists in the protected configuration file.
    # If the key is found, echo "true" and return 0.
    if [ -f "$file" ] && grep -q "^${key}$" "$file"; then
        echo "true"
        return 0
    fi

    # If the key is not found in the protected configuration file,
    # check against the SHELL_PROTECTED_KEYS array.
    if [ -z "${SHELL_PROTECTED_KEYS+x}" ]; then
        shell::colored_echo "ERR: SHELL_PROTECTED_KEYS array is not defined." 196
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

# shell::add_group function
# Groups selected configuration keys under a specified group name.
#
# Usage:
#   shell::add_group [-n]
#
# Description:
#   This function prompts you to enter a group name, then uses fzf (with multi-select) to let you choose
#   one or more configuration keys (from SHELL_KEY_CONF_FILE). It then stores the group in SHELL_GROUP_CONF_FILE in the format:
#       group_name=key1,key2,...,keyN
#   If the group name already exists, the group entry is updated with the new selection.
#   An optional dry-run flag (-n) can be used to print the command via shell::on_evict instead of executing it.
#
# Example:
#   shell::add_group         # Prompts for a group name and lets you select keys to group.
#   shell::add_group -n      # Prints the command for creating/updating the group without executing it.
shell::add_group() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ADD_GROUP"
        return 0
    fi

    # Ensure the group configuration file exists.
    shell::create_file_if_not_exists "$SHELL_GROUP_CONF_FILE"
    shell::unlock_permissions "$SHELL_GROUP_CONF_FILE"

    # Prompt the user for a group name.
    shell::colored_echo "Enter group name:" 33
    read -r group_name
    if [ -z "$group_name" ]; then
        shell::colored_echo "ERR: No group name entered. Aborting." 196
        return 1
    fi

    # Ensure the individual configuration file exists.
    if [ ! -f "$SHELL_KEY_CONF_FILE" ]; then
        shell::colored_echo "ERR: Configuration file '$SHELL_KEY_CONF_FILE' not found." 196
        return 1
    fi

    shell::install_package fzf

    # Use fzf with multi-select to choose keys from SHELL_KEY_CONF_FILE.
    local selected_keys
    selected_keys=$(cut -d '=' -f 1 "$SHELL_KEY_CONF_FILE" | fzf --multi --prompt="Select config keys for group '$group_name': ")
    if [ -z "$selected_keys" ]; then
        shell::colored_echo "ERR: No keys selected. Aborting group creation." 196
        return 1
    fi

    # Convert the multi-line selection to a comma-separated list.
    local keys_csv
    keys_csv=$(echo "$selected_keys" | paste -sd "," -)

    # Construct the group entry in the format: group_name=key1,key2,...,keyN
    local group_entry="${group_name}=${keys_csv}"

    # If the group already exists, update it; otherwise, append it.
    if grep -q "^${group_name}=" "$SHELL_GROUP_CONF_FILE"; then
        local os_type
        os_type=$(shell::get_os_type)
        local sed_cmd=""
        if [ "$os_type" = "macos" ]; then
            sed_cmd="sed -i '' \"s/^${group_name}=.*/${group_entry}/\" \"$SHELL_GROUP_CONF_FILE\""
        else
            sed_cmd="sed -i \"s/^${group_name}=.*/${group_entry}/\" \"$SHELL_GROUP_CONF_FILE\""
        fi
        if [ "$dry_run" = "true" ]; then
            shell::on_evict "$sed_cmd"
        else
            shell::run_cmd_eval "$sed_cmd"
            shell::colored_echo "INFO: Updated group '$group_name' with keys: $keys_csv" 46
        fi
    else
        local cmd="echo \"$group_entry\" >> \"$SHELL_GROUP_CONF_FILE\""
        if [ "$dry_run" = "true" ]; then
            shell::on_evict "$cmd"
        else
            shell::run_cmd_eval "$cmd"
            shell::colored_echo "INFO: Created group '$group_name' with keys: $keys_csv" 46
        fi
    fi
}

# shell::read_group function
# Reads and displays the configurations for a given group by group name.
#
# Usage:
#   shell::read_group <group_name>
#
# Description:
#   This function looks up the group entry in SHELL_GROUP_CONF_FILE for the specified group name.
#   The group entry is expected to be in the format:
#       group_name=key1,key2,...,keyN
#   For each key in the group, the function retrieves the corresponding configuration entry from SHELL_KEY_CONF_FILE,
#   decodes the Base64-encoded value (using -D on macOS and -d on Linux), and groups the key-value pairs
#   into a JSON object which is displayed.
#
# Example:
#   shell::read_group my_group   # Displays the configurations for the keys in the group 'my_group'.
shell::read_group() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_READ_GROUP"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::read_group [-h] <group_name>"
        return 1
    fi

    local group_name="$1"

    if [ ! -f "$SHELL_GROUP_CONF_FILE" ]; then
        shell::colored_echo "ERR: Group configuration file '$SHELL_GROUP_CONF_FILE' not found." 196
        return 1
    fi

    # Retrieve the group entry for the specified group name.
    local group_entry
    group_entry=$(grep "^${group_name}=" "$SHELL_GROUP_CONF_FILE")
    if [ -z "$group_entry" ]; then
        shell::colored_echo "ERR: Group '$group_name' not found." 196
        return 1
    fi

    # Extract the comma-separated list of keys.
    local keys_csv
    keys_csv=$(echo "$group_entry" | cut -d '=' -f 2-)
    if [ -z "$keys_csv" ]; then
        shell::colored_echo "ERR: No keys defined in group '$group_name'." 196
        return 1
    fi

    local os_type
    os_type=$(shell::get_os_type)
    local json_obj="{"
    local first=1

    # Convert the comma-separated keys to an array in a way compatible with both Bash and zsh.
    if [ -n "$BASH_VERSION" ]; then
        IFS=',' read -r -a keys_array <<<"$keys_csv"
    else
        IFS=',' read -rA keys_array <<<"$keys_csv"
    fi

    for key in "${keys_array[@]}"; do
        # Retrieve the configuration entry from SHELL_KEY_CONF_FILE for each key.
        local conf_line
        conf_line=$(grep "^${key}=" "$SHELL_KEY_CONF_FILE")
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
    shell::colored_echo "$json_obj" 33
    shell::clip_value "$json_obj"
}

# shell::fzf_remove_group function
# Interactively selects a group name from the group configuration file using fzf,
# then removes the corresponding group entry.
#
# Usage:
#   shell::fzf_remove_group [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the removal command is printed using shell::on_evict instead of executed.
#
# Description:
#   The function extracts group names from SHELL_GROUP_CONF_FILE and uses fzf for interactive selection.
#   Once a group is selected, it constructs a sed command (with appropriate in-place options for macOS or Linux)
#   to remove the line that starts with "group_name=".
#   If the file is not writable, sudo is prepended. In dry-run mode, the command is printed via shell::on_evict.
#
# Example:
#   shell::fzf_remove_group         # Interactively select a group and remove its entry.
#   shell::fzf_remove_group -n      # Prints the removal command without executing it.
shell::fzf_remove_group() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_REMOVE_GROUP"
        return 0
    fi

    if [ ! -f "$SHELL_GROUP_CONF_FILE" ]; then
        shell::colored_echo "ERR: Group configuration file '$SHELL_GROUP_CONF_FILE' not found." 196
        return 1
    fi

    shell::install_package fzf

    local selected_group
    selected_group=$(cut -d '=' -f 1 "$SHELL_GROUP_CONF_FILE" | fzf --prompt="Select a group to remove: ")
    if [ -z "$selected_group" ]; then
        shell::colored_echo "ERR: No group selected." 196
        return 1
    fi

    local os_type
    os_type=$(shell::get_os_type)
    local sed_cmd=""
    local use_sudo="sudo "

    if [ "$os_type" = "macos" ]; then
        sed_cmd="${use_sudo}sed -i '' \"/^${selected_group}=/d\" \"$SHELL_GROUP_CONF_FILE\""
    else
        sed_cmd="${use_sudo}sed -i \"/^${selected_group}=/d\" \"$SHELL_GROUP_CONF_FILE\""
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$sed_cmd"
    else
        shell::run_cmd_eval "$sed_cmd"
        shell::colored_echo "INFO: Removed group: $selected_group" 46
    fi
}

# shell::fzf_update_group function
# Interactively updates an existing group by letting you select new keys for that group.
#
# Usage:
#   shell::fzf_update_group [-n] [-h]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the update command is printed using shell::on_evict instead of executed.
#
# Description:
#   The function reads SHELL_GROUP_CONF_FILE and uses fzf to let you select an existing group.
#   It then presents all available keys from SHELL_KEY_CONF_FILE (via fzf with multi-select) for you to choose the new group membership.
#   The selected keys are converted into a comma-separated list, and the group entry is updated in SHELL_GROUP_CONF_FILE
#   (using sed with options appropriate for macOS or Linux). If the file is not writable, sudo is used.
#
# Example:
#   shell::fzf_update_group         # Interactively select a group, update its keys, and update the group entry.
#   shell::fzf_update_group -n      # Prints the update command without executing it.
shell::fzf_update_group() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_UPDATE_GROUP"
        return 0
    fi

    if [ ! -f "$SHELL_GROUP_CONF_FILE" ]; then
        shell::colored_echo "ERR: Group configuration file '$SHELL_GROUP_CONF_FILE' not found." 196
        return 1
    fi

    shell::install_package fzf

    # Select the group to update.
    local selected_group
    selected_group=$(cut -d '=' -f 1 "$SHELL_GROUP_CONF_FILE" | fzf --prompt="Select a group to update: ")
    if [ -z "$selected_group" ]; then
        shell::colored_echo "ERR: No group selected." 196
        return 1
    fi

    # Ensure the individual configuration file exists.
    if [ ! -f "$SHELL_KEY_CONF_FILE" ]; then
        shell::colored_echo "ERR: Configuration file '$SHELL_KEY_CONF_FILE' not found." 196
        return 1
    fi

    # Let the user select new keys for the group from all available keys.
    local new_keys
    new_keys=$(cut -d '=' -f 1 "$SHELL_KEY_CONF_FILE" | fzf --multi --prompt="Select new keys for group '$selected_group': " | paste -sd "," -)
    if [ -z "$new_keys" ]; then
        shell::colored_echo "ERR: No keys selected. Aborting update." 196
        return 1
    fi

    local new_group_entry="${selected_group}=${new_keys}"
    local os_type
    os_type=$(shell::get_os_type)
    local sed_cmd=""
    local use_sudo="sudo "

    if [ "$os_type" = "macos" ]; then
        sed_cmd="${use_sudo}sed -i '' \"s/^${selected_group}=.*/${new_group_entry}/\" \"$SHELL_GROUP_CONF_FILE\""
    else
        sed_cmd="${use_sudo}sed -i \"s/^${selected_group}=.*/${new_group_entry}/\" \"$SHELL_GROUP_CONF_FILE\""
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$sed_cmd"
    else
        shell::run_cmd_eval "$sed_cmd"
        shell::colored_echo "INFO: Updated group '$selected_group' with new keys: $new_keys" 46
    fi
}

# shell::fzf_rename_group function
# Renames an existing group in the group configuration file.
#
# Usage:
#   shell::fzf_rename_group [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the renaming command is printed using shell::on_evict instead of executed.
#
# Description:
#   The function reads the group configuration file (SHELL_GROUP_CONF_FILE) where each line is in the format:
#       group_name=key1,key2,...,keyN
#   It uses fzf to let you select an existing group to rename.
#   After selection, the function prompts for a new group name.
#   It then constructs a sed command to replace the old group name with the new one in the configuration file.
#   The sed command uses in-place editing options appropriate for macOS (sed -i '') or Linux (sed -i).
#   In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.
#
# Example:
#   shell::fzf_rename_group         # Interactively select a group and rename it.
#   shell::fzf_rename_group -n      # Prints the renaming command without executing it.
shell::fzf_rename_group() {
    local dry_run="false"
    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_RENAME_GROUP"
        return 0
    fi

    if [ ! -f "$SHELL_GROUP_CONF_FILE" ]; then
        shell::colored_echo "ERR: Group configuration file '$SHELL_GROUP_CONF_FILE' not found." 196
        return 1
    fi

    shell::install_package fzf

    # Use fzf to let the user select an existing group.
    local old_group
    old_group=$(cut -d '=' -f 1 "$SHELL_GROUP_CONF_FILE" | fzf --prompt="Select group to rename: ")
    if [ -z "$old_group" ]; then
        shell::colored_echo "ERR: No group selected. Aborting rename." 196
        return 1
    fi

    # Prompt for the new group name.
    shell::colored_echo "Enter new name for group '$old_group':" 33
    read -r new_group
    if [ -z "$new_group" ]; then
        shell::colored_echo "ERR: No new group name entered. Aborting rename." 196
        return 1
    fi

    # Construct the sed command to update the group name while preserving the keys.
    local os_type
    os_type=$(shell::get_os_type)
    local sed_cmd=""
    local use_sudo="sudo "

    if [ "$os_type" = "macos" ]; then
        sed_cmd="${use_sudo}sed -i '' \"s/^${old_group}=/${new_group}=/\" \"$SHELL_GROUP_CONF_FILE\""
    else
        sed_cmd="${use_sudo}sed -i \"s/^${old_group}=/${new_group}=/\" \"$SHELL_GROUP_CONF_FILE\""
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$sed_cmd"
    else
        shell::run_cmd_eval "$sed_cmd"
        shell::colored_echo "INFO: Renamed group '$old_group' to '$new_group'" 46
    fi
}

# shell::list_groups function
# Lists all group names defined in the group configuration file.
#
# Usage:
#   shell::list_groups
#
# Description:
#   This function reads the configuration file defined by SHELL_GROUP_CONF_FILE,
#   where each line is in the format:
#       group_name=key1,key2,...,keyN
#   It extracts and displays the group names (the part before the '=')
#   using the 'cut' command.
#
# Example:
#   shell::list_groups       # Displays all group names.
shell::list_groups() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_LIST_GROUP"
        return 0
    fi

    if [ ! -f "$SHELL_GROUP_CONF_FILE" ]; then
        shell::colored_echo "ERR: Group configuration file '$SHELL_GROUP_CONF_FILE' not found." 196
        return 1
    fi

    # Extract group names from the configuration file.
    local groups
    groups=$(cut -d '=' -f 1 "$SHELL_GROUP_CONF_FILE")
    if [ -z "$groups" ]; then
        shell::colored_echo "ERR: No groups found in '$SHELL_GROUP_CONF_FILE'." 196
        return 1
    fi

    echo "$groups"
}

# shell::fzf_select_group function
# Interactively selects a group name from the group configuration file using fzf,
# then lists all keys belonging to the selected group and uses fzf to choose one key,
# finally displaying the decoded value for the selected key.
#
# Usage:
#   shell::fzf_select_group
#
# Description:
#   The function reads the configuration file defined by SHELL_GROUP_CONF_FILE, where each line is in the format:
#       group_name=key1,key2,...,keyN
#   It first uses fzf to allow interactive selection of a group name.
#   Once a group is selected, the function extracts the comma-separated list of keys,
#   converts them into a list (one per line), and uses fzf again to let you choose one key.
#   It then retrieves the corresponding configuration entry from SHELL_KEY_CONF_FILE (which stores entries as key=encoded_value),
#   decodes the Base64-encoded value (using -D on macOS and -d on Linux), and displays the group name, key, and decoded value.
#
# Example:
#   shell::fzf_select_group   # Prompts to select a group, then a key within that group, and displays the decoded value.
shell::fzf_select_group() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_SELECT_GROUP"
        return 0
    fi

    # Ensure the group configuration file exists.
    if [ ! -f "$SHELL_GROUP_CONF_FILE" ]; then
        shell::colored_echo "ERR: Group configuration file '$SHELL_GROUP_CONF_FILE' not found." 196
        return 1
    fi

    shell::install_package fzf

    # Extract group names from SHELL_GROUP_CONF_FILE and let the user select one.
    local groups
    groups=$(cut -d '=' -f 1 "$SHELL_GROUP_CONF_FILE")
    local selected_group
    selected_group=$(echo "$groups" | fzf --prompt="Select a group name: ")
    if [ -z "$selected_group" ]; then
        shell::colored_echo "ERR: No group selected." 196
        return 1
    fi

    # Retrieve the group entry for the selected group.
    local group_entry
    group_entry=$(grep "^${selected_group}=" "$SHELL_GROUP_CONF_FILE")
    if [ -z "$group_entry" ]; then
        shell::colored_echo "ERR: Group '$selected_group' not found in configuration." 196
        return 1
    fi

    # Extract the comma-separated list of keys.
    local keys_csv
    keys_csv=$(echo "$group_entry" | cut -d '=' -f 2-)
    if [ -z "$keys_csv" ]; then
        shell::colored_echo "ERR: No keys defined in group '$selected_group'." 196
        return 1
    fi

    # Convert the comma-separated keys into a list (one per line) and use fzf to select one key.
    local selected_key
    selected_key=$(echo "$keys_csv" | tr ',' '\n' | fzf --prompt="Select a key from group '$selected_group': ")
    if [ -z "$selected_key" ]; then
        shell::colored_echo "ERR: No key selected from group '$selected_group'." 196
        return 1
    fi

    # Ensure the individual configuration file exists.
    if [ ! -f "$SHELL_KEY_CONF_FILE" ]; then
        shell::colored_echo "ERR: Configuration file '$SHELL_KEY_CONF_FILE' not found." 196
        return 1
    fi

    # Retrieve the configuration entry corresponding to the selected key.
    local conf_line
    conf_line=$(grep "^${selected_key}=" "$SHELL_KEY_CONF_FILE")
    if [ -z "$conf_line" ]; then
        shell::colored_echo "ERR: Key '$selected_key' not found in configuration." 196
        return 1
    fi

    # Extract the encoded value.
    local encoded_value
    encoded_value=$(echo "$conf_line" | cut -d '=' -f 2-)

    # Decode the value based on the operating system.
    local os_type
    os_type=$(shell::get_os_type)
    local decoded_value
    if [ "$os_type" = "macos" ]; then
        decoded_value=$(echo "$encoded_value" | base64 -D)
    else
        decoded_value=$(echo "$encoded_value" | base64 -d)
    fi

    # Display the results.
    shell::colored_echo "[g] Group: $selected_group" 33
    shell::colored_echo "[k] Key: $selected_key" 33
    shell::clip_value "$decoded_value"
}

# shell::fzf_clone_group function
# Clones an existing group by creating a new group with the same keys.
#
# Usage:
#   shell::fzf_clone_group [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the cloning command is printed using shell::on_evict instead of executed.
#
# Description:
#   The function reads the group configuration file (SHELL_GROUP_CONF_FILE) where each line is in the format:
#       group_name=key1,key2,...,keyN
#   It uses fzf to interactively select an existing group.
#   After selection, it prompts for a new group name.
#   The new group entry is then constructed with the new group name and the same comma-separated keys
#   as the selected group, and appended to SHELL_GROUP_CONF_FILE.
#   In dry-run mode, the final command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.
#
# Example:
#   shell::fzf_clone_group         # Interactively select a group and create a clone with a new group name.
#   shell::fzf_clone_group -n      # Prints the cloning command without executing it.
shell::fzf_clone_group() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_CLONE_GROUP"
        return 0
    fi

    # Ensure the group configuration file exists.
    if [ ! -f "$SHELL_GROUP_CONF_FILE" ]; then
        shell::colored_echo "ERR: Group configuration file '$SHELL_GROUP_CONF_FILE' not found." 196
        return 1
    fi

    shell::install_package fzf

    # Use fzf to let the user select an existing group.
    local selected_group
    selected_group=$(cut -d '=' -f 1 "$SHELL_GROUP_CONF_FILE" | fzf --prompt="Select a group to clone: ")
    if [ -z "$selected_group" ]; then
        shell::colored_echo "ERR: No group selected. Aborting clone." 196
        return 1
    fi

    # Retrieve the group entry to get the keys.
    local group_entry
    group_entry=$(grep "^${selected_group}=" "$SHELL_GROUP_CONF_FILE")
    if [ -z "$group_entry" ]; then
        shell::colored_echo "ERR: Group '$selected_group' not found." 196
        return 1
    fi

    local keys_csv
    keys_csv=$(echo "$group_entry" | cut -d '=' -f 2-)
    if [ -z "$keys_csv" ]; then
        shell::colored_echo "ERR: No keys defined in group '$selected_group'." 196
        return 1
    fi

    # Prompt for the new group name.
    shell::colored_echo "Enter new group name for the clone of '$selected_group':" 33
    read -r new_group
    if [ -z "$new_group" ]; then
        shell::colored_echo "ERR: No new group name entered. Aborting clone." 196
        return 1
    fi

    # Check if the new group name already exists.
    if grep -q "^${new_group}=" "$SHELL_GROUP_CONF_FILE"; then
        shell::colored_echo "ERR: Group '$new_group' already exists." 196
        return 1
    fi

    # Construct the new group entry.
    local new_group_entry="${new_group}=${keys_csv}"

    # Build the command to append the new group entry.
    local cmd="echo \"$new_group_entry\" >> \"$SHELL_GROUP_CONF_FILE\""

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::run_cmd_eval "$cmd"
        shell::colored_echo "INFO: Created new group '$new_group' as a clone of '$selected_group' with keys: $keys_csv" 46
    fi
}

# shell::sync_key_group_conf function
# Synchronizes group configurations by ensuring that each group's keys exist in the key configuration file.
# If a key listed in a group does not exist, it is removed from that group.
# If a group ends up with no valid keys, that group entry is removed.
#
# Usage:
#   shell::sync_key_group_conf [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the new group configuration is printed using shell::on_evict instead of being applied.
#
# Description:
#   The function reads each group entry from SHELL_GROUP_CONF_FILE (entries in the format: group_name=key1,key2,...,keyN).
#   For each group, it splits the comma‑separated list of keys and checks each key using shell::exist_key_conf.
#   It builds a new list of valid keys. If the new list is non‑empty, the group entry is updated;
#   if it is empty, the group entry is omitted.
#   In dry‑run mode, the new group configuration is printed via shell::on_evict without modifying the file.
#
# Example:
#   shell::sync_key_group_conf         # Synchronizes the group configuration file.
#   shell::sync_key_group_conf -n      # Displays the updated group configuration without modifying the file.
shell::sync_key_group_conf() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_SYNC_KEY_GROUP_CONF"
        return 0
    fi

    if [ ! -f "$SHELL_GROUP_CONF_FILE" ]; then
        shell::colored_echo "ERR: Group configuration file '$SHELL_GROUP_CONF_FILE' not found." 196
        return 1
    fi

    shell::colored_echo "DEBUG: Syncing group configuration..." 244

    # Create a temporary file for the updated configuration.
    local temp_file
    temp_file=$(mktemp) || {
        shell::colored_echo "ERR: Unable to create temporary file." 196
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
            if [ "$(shell::exist_key_conf "$key")" = "true" ]; then
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
            shell::colored_echo "WARN: Group '$group_name' has no valid keys and will be removed." 11
        fi
    done <"$SHELL_GROUP_CONF_FILE"

    # If dry-run mode is enabled, print the new configuration and remove the temporary file.
    # Otherwise, replace the original configuration file with the new one.
    if [ "$dry_run" = "true" ]; then
        shell::clip_value "$(cat "$temp_file")"
        shell::run_cmd_eval "sudo rm $temp_file"
    else
        local backup_file="${SHELL_GROUP_CONF_FILE}.bak"
        shell::run_cmd_eval "sudo cp $SHELL_GROUP_CONF_FILE $backup_file"
        shell::run_cmd_eval "sudo mv $temp_file $SHELL_GROUP_CONF_FILE"
        shell::colored_echo "INFO: Group configuration synchronized successfully." 46
    fi
}

# shell::fzf_view_conf_viz function
# Interactively selects a configuration key using fzf and displays its decoded value in real-time.
#
# Usage:
#   shell::fzf_view_conf_viz [-n] [-h]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the clipboard copy command is printed instead of executed.
#   - -h : Optional help flag. Displays this help message.
#
# Description:
#   This function checks if the configuration file exists. If not, it displays an error.
#   It then uses fzf to interactively select a configuration key from the file, showing
#   the Base64-decoded value in real-time in a preview window, formatted as "key (value)"
#   with the key in yellow and the value in cyan. Once a key is selected, its decoded value
#   is copied to the clipboard unless in dry-run mode, where the copy command is printed.
#
# Requirements:
#   - fzf must be installed.
#   - The 'SHELL_KEY_CONF_FILE' variable must be set.
#   - Helper functions: shell::install_package, shell::colored_echo, shell::get_os_type, shell::clip_value, shell::on_evict.
#
# Example usage:
#   shell::fzf_view_conf_viz         # Select a key and copy its decoded value.
#   shell::fzf_view_conf_viz -n      # Dry-run: print the clipboard copy command.
#
# Returns:
#   0 on success, 1 on failure (e.g., no config file, fzf not installed, no selection).
#
# Notes:
#   - Compatible with both macOS and Linux.
#   - Uses ANSI color codes for formatting (yellow for key, cyan for value).
#   - The configuration file is expected to contain key=value pairs with Base64-encoded values.
shell::fzf_view_conf_viz() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_GET_KEY_CONF_VISUALIZATION"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Validate configuration file existence
    if [ ! -f "$SHELL_KEY_CONF_FILE" ]; then
        shell::colored_echo "ERR: Configuration file '$SHELL_KEY_CONF_FILE' not found." 196
        return 1
    fi

    # Ensure fzf is installed
    shell::install_package fzf || {
        shell::colored_echo "ERR: fzf is required but could not be installed." 196
        return 1
    }

    # Define ANSI color codes using tput
    local yellow=$(tput setaf 3) # Yellow for key
    local cyan=$(tput setaf 6)   # Cyan for value
    local normal=$(tput sgr0)    # Reset to normal

    # Determine OS type for Base64 decoding
    local os_type
    os_type=$(shell::get_os_type)
    local base64_decode_cmd
    if [ "$os_type" = "macos" ]; then
        base64_decode_cmd="base64 -D"
    else
        base64_decode_cmd="base64 -d"
    fi

    # Prepare colored key list for fzf
    # local key_list
    # key_list=$(cut -d '=' -f 1 "$SHELL_KEY_CONF_FILE" | awk -v yellow="$yellow" -v normal="$normal" '{print yellow $0 normal}')
    # if [ -z "$key_list" ]; then
    #     shell::colored_echo "ERR: No configuration keys found in '$SHELL_KEY_CONF_FILE'." 196
    #     return 1
    # fi
    # Use fzf with a preview window to show only the decoded value
    local selected_key
    # selected_key=$(echo "$key_list" | fzf --ansi \
    #     --prompt="Select config key: " \
    #     --preview="grep '^{}=.*' \"$SHELL_KEY_CONF_FILE\" | cut -d '=' -f 2- | $base64_decode_cmd 2>/dev/null || echo 'Invalid Base64'")

    # Use grep to filter out comments and then cut to get the key names
    # Use fzf to select a key, showing the decoded value in the preview
    # selected_key=$(grep -v '^\s*#' "$SHELL_KEY_CONF_FILE" | cut -d '=' -f 1 |
    #     fzf --ansi \
    #         --prompt="Select config key: " \
    #         --preview="grep -v '^\s*#' \"$SHELL_KEY_CONF_FILE\" | grep '^{}=' | cut -d '=' -f 2- | $base64_decode_cmd 2>/dev/null || echo 'Invalid Base64'" \
    #         --preview-window=up:3:wrap)

    selected_key=$(grep -v '^\s*#' "$SHELL_KEY_CONF_FILE" | cut -d '=' -f 1 | awk -v yellow="$yellow" -v normal="$normal" '{print yellow $0 normal}' |
        fzf --ansi \
            --prompt="Select config key: " \
            --preview="grep -v '^\s*#' \"$SHELL_KEY_CONF_FILE\" | grep '^{}=' | cut -d '=' -f 2- | $base64_decode_cmd 2>/dev/null || echo 'Invalid Base64'" \
            --preview-window=up:3:wrap)

    # Extract the uncolored key (remove ANSI codes)
    selected_key=$(echo "$selected_key" | sed "s/$(echo -e "\033")[0-9;]*m//g")

    if [ -z "$selected_key" ]; then
        shell::colored_echo "ERR: No configuration key selected." 196
        return 1
    fi
    shell::colored_echo "INFO: Selected key: $selected_key" 46
    shell::clip_value $(shell::get_key_conf_value "$selected_key")
}

# shell::add_protected_key function
# Adds a key to the protected key list stored in protected.conf.
#
# Usage:
# shell::add_protected_key [-n] <key>
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
# - <key> : The key to mark as protected.
#
# Description:
# This function appends a key to the protected.conf file located at $SHELL_CONF_WORKING/protected.conf.
# If the key already exists in the file, it will not be added again.
shell::add_protected_key() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ADD_PROTECTED_KEY"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::add_protected_key [-n] <key>"
        return 1
    fi

    local key="$1"
    local file="$SHELL_KEY_CONF_FILE_PROTECTED"

    # Check if the key is provided
    if [ -z "$key" ]; then
        shell::colored_echo "ERR: No key provided to protect." 196
        return 1
    fi
    # Ensure the protected.conf file exists and has the correct permissions.
    if [ ! -d "$SHELL_CONF_WORKING" ]; then
        shell::colored_echo "ERR: Working directory '$SHELL_CONF_WORKING' does not exist." 196
        return 1
    fi

    # Create the protected.conf file if it does not exist.
    # Use shell::create_file_if_not_exists to ensure the file is created.
    # Set permissions to 777 for the file.
    shell::create_file_if_not_exists "$file"
    shell::unlock_permissions "$file"

    # Check if the key is already protected.
    # Use grep to check if the key is already in the file.
    # The key is considered protected if it matches exactly (no partial matches).
    # Use ^ and $ to ensure we match the whole line.
    if grep -q "^${key}$" "$file"; then
        shell::colored_echo "WARN: Key '$key' is already protected." 11
        return 0
    fi

    # Append the key to the protected.conf file.
    # Use echo to append the key, ensuring it is quoted to handle special characters.
    # Use shell::on_evict for dry-run mode, otherwise run the command.
    local cmd="echo \"$key\" >> \"$file\""
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::run_cmd_eval "$cmd"
        shell::colored_echo "INFO: Protected key added: $key" 46
    fi
}

# shell::fzf_add_protected_key function
# Interactively selects a key from the configuration file and adds it to the protected list.
#
# Usage:
# shell::fzf_add_protected_key [-n]
#
# Description:
# This function uses fzf to select a key from the configuration file (excluding comments),
# and adds it to the protected.conf file.
shell::fzf_add_protected_key() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_ADD_PROTECTED_KEY"
        return 0
    fi

    # Ensure the configuration file exists.
    if [ ! -f "$SHELL_KEY_CONF_FILE" ]; then
        shell::colored_echo "ERR: Configuration file '$SHELL_KEY_CONF_FILE' not found." 196
        return 1
    fi

    shell::install_package fzf

    local yellow=$(tput setaf 3)
    local normal=$(tput sgr0)

    # Use fzf to select a key from the configuration file.
    # Exclude comments and format the output with colors.
    # Use grep to filter out comments and then cut to get the key names.
    # Use awk to color the selected key.
    local selected_key_colored
    selected_key_colored=$(grep -v '^\s*#' "$SHELL_KEY_CONF_FILE" | cut -d '=' -f 1 |
        awk -v yellow="$yellow" -v normal="$normal" '{print yellow $0 normal}' |
        fzf --ansi --prompt="Select key to protect: ")

    local selected_key
    selected_key=$(echo "$selected_key_colored" | sed "s/$(echo -e "\033")[0-9;]*m//g")

    # Check if a key was selected.
    # If no key was selected, print an error message and return.
    if [ -z "$selected_key" ]; then
        shell::colored_echo "ERR: No key selected." 196
        return 1
    fi

    # Verify dry-run mode.
    # If dry-run mode is enabled, print the command to add the protected key.
    # Otherwise, call shell::add_protected_key to add the key.
    if [ "$dry_run" = "true" ]; then
        shell::add_protected_key "-n" "$selected_key"
    else
        shell::add_protected_key "$selected_key"
    fi
}

# shell::fzf_remove_protected_key function
# Interactively selects a protected key using fzf and removes it from protected.conf.
#
# Usage:
# shell::fzf_remove_protected_key [-n]
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the removal command is printed using shell::on_evict instead of executed.
#
# Description:
# This function reads the protected.conf file, uses fzf to let the user select a key,
# and removes the selected key using sed. In dry-run mode, the command is printed instead of executed.
shell::fzf_remove_protected_key() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_REMOVE_PROTECTED_KEY"
        return 0
    fi

    local file="$SHELL_KEY_CONF_FILE_PROTECTED"
    # Check if the protected.conf file exists.
    # If it does not exist, print an error message and return.
    if [ ! -f "$file" ]; then
        shell::colored_echo "ERR: Protected key file '$file' not found." 196
        return 1
    fi

    # Ensure fzf is installed.
    shell::install_package fzf

    # Use fzf to select a protected key.
    # Exclude comments and use fzf to let the user select a key.
    # Use grep to filter out comments and then use fzf to select a key.
    local selected_key
    selected_key=$(grep -v '^\s*#' "$file" | fzf --prompt="Select protected key to remove: ")

    if [ -z "$selected_key" ]; then
        shell::colored_echo "ERR: No key selected." 196
        return 1
    fi

    local os_type
    os_type=$(shell::get_os_type)
    local sed_cmd=""
    if [ "$os_type" = "macos" ]; then
        sed_cmd="sudo sed -i '' \"/^${selected_key}$/d\" \"$file\"" # Use sed with -i '' for macOS compatibility
    else
        sed_cmd="sudo sed -i \"/^${selected_key}$/d\" \"$file\"" # Use sed with -i for Linux compatibility
    fi

    # If dry-run mode is enabled, print the command to remove the protected key.
    # Otherwise, execute the command to remove the key.
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$sed_cmd"
    else
        shell::run_cmd_eval "$sed_cmd"
        shell::colored_echo "INFO: Removed protected key: $selected_key" 46
    fi
}

# shell::sync_protected_key function
# Synchronizes the protected.conf file by removing keys that no longer exist in key.conf.
#
# Usage:
# shell::sync_protected_key [-n]
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the updated protected.conf is printed using shell::on_evict instead of being applied.
#
# Description:
# This function compares the keys listed in protected.conf with those in key.conf.
# Any protected key that is not found in key.conf will be removed.
# In dry-run mode, the updated list is printed instead of being written to the file.
shell::sync_protected_key() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_SYNC_PROTECTED_KEY"
        return 0
    fi

    local key_file="$SHELL_KEY_CONF_FILE"
    local protected_file="$SHELL_KEY_CONF_FILE_PROTECTED"

    # Check if the protected.conf file and key.conf file exist.
    # If either file does not exist, print an error message and return.
    if [ ! -f "$protected_file" ]; then
        shell::colored_echo "ERR: Protected key file '$protected_file' not found." 196
        return 1
    fi

    # Check if the key configuration file exists.
    # If it does not exist, print an error message and return.
    if [ ! -f "$key_file" ]; then
        shell::colored_echo "ERR: Key configuration file '$key_file' not found." 196
        return 1
    fi

    shell::colored_echo "DEBUG: Syncing protected keys..." 244

    # Create a temporary file to store the updated protected keys.
    # Use mktemp to create a temporary file for the updated protected keys.
    local temp_file
    temp_file=$(mktemp) || {
        shell::colored_echo "ERR: Unable to create temporary file." 196
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
            shell::colored_echo "WARN: Removing undefined protected key: $key" 11
        fi
    done <"$protected_file"

    # If dry-run mode is enabled, print the updated protected keys and remove the temporary file.
    # Otherwise, move the temporary file to the protected.conf file.
    if [ "$dry_run" = "true" ]; then
        shell::colored_echo "DEBUG: Dry-run: Updated protected keys:" 244
        cat "$temp_file"
        shell::run_cmd_eval "sudo rm \"$temp_file\""
    else
        shell::run_cmd_eval "sudo mv \"$temp_file\" \"$protected_file\""
        shell::colored_echo "INFO: Protected keys synchronized successfully." 46
    fi
}
