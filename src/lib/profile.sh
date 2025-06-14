#!/bin/bash
# profile.sh

# shell::get_profile_workspace function
# Returns the path to the profile directory for a given profile name.
#
# Usage:
#   shell::get_profile_workspace <profile_name>
#
# Parameters:
#   - <profile_name>: The name of the profile.
#
# Description:
#   Constructs and returns the path to the profile directory within the workspace,
#   located at $SHELL_CONF_WORKING/workspace.
#
# Example:
#   profile_dir=$(shell::get_profile_workspace "my_profile")  # Returns "$SHELL_CONF_WORKING/workspace/my_profile"
shell::get_profile_workspace() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GET_PROFILE_WORKSPACE"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::get_profile_workspace <profile_name>"
        return 1
    fi
    local profile_name="$1"
    echo "$SHELL_CONF_WORKING_WORKSPACE/$profile_name"
}

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
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ENSURE_WORKSPACE"
        return 0
    fi

    if [ ! -d "$SHELL_CONF_WORKING_WORKSPACE" ]; then
        shell::run_cmd_eval sudo mkdir -p "$SHELL_CONF_WORKING_WORKSPACE"
    fi
}

# shell::add_profile function
# Creates a new profile directory and initializes it with a profile.conf file.
#
# Usage:
#   shell::add_profile [-n] <profile_name>
#
# Parameters:
#   - -n             : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - <profile_name> : The name of the profile to create.
#
# Description:
#   Ensures the workspace directory exists, then creates a new directory for the specified profile
#   and initializes it with an empty profile.conf file. If the profile already exists, it prints a warning.
#
# Example:
#   shell::add_profile my_profile         # Creates the profile directory and profile.conf.
#   shell::add_profile -n my_profile      # Prints the commands without executing them.
shell::add_profile() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ADD_PROFILE"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::add_profile [-n] <profile_name>"
        return 1
    fi
    local profile_name="$1"
    local profile_dir=$(shell::get_profile_workspace "$profile_name")
    if [ -d "$profile_dir" ]; then
        shell::colored_echo "WARN: Profile '$profile_name' already exists." 11
        return 1
    fi

    local cmd="sudo mkdir -p \"$profile_dir\" && sudo touch \"$profile_dir/profile.conf\""
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::ensure_workspace
        shell::run_cmd_eval "$cmd"
        shell::colored_echo "INFO: Created profile '$profile_name'." 46
    fi
}

# shell::read_profile function
# Sources the profile.conf file from the specified profile directory.
#
# Usage:
#   shell::read_profile [-n] <profile_name>
#
# Parameters:
#   - -n             : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#   - <profile_name> : The name of the profile to read.
#
# Description:
#   Checks if the specified profile exists and sources its profile.conf file to load configurations
#   into the current shell session. If the profile or file does not exist, it prints an error.
#
# Example:
#   shell::read_profile my_profile         # Sources profile.conf from my_profile.
#   shell::read_profile -n my_profile      # Prints the sourcing command without executing it.
shell::read_profile() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_READ_PROFILE"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::read_profile [-n] <profile_name>"
        return 1
    fi
    local profile_name="$1"
    local profile_dir=$(shell::get_profile_workspace "$profile_name")
    local profile_conf="$profile_dir/profile.conf"
    if [ ! -d "$profile_dir" ]; then
        shell::colored_echo "ERR: Profile '$profile_name' does not exist." 196
        return 1
    fi
    if [ ! -f "$profile_conf" ]; then
        shell::colored_echo "ERR: Profile configuration file '$profile_conf' not found." 196
        return 1
    fi
    if [ "$dry_run" = "true" ]; then
        shell::read_conf -n "$profile_conf"
    else
        shell::read_conf "$profile_conf"
    fi
}

# shell::update_profile function
# Opens the profile.conf file of the specified profile in the default editor.
#
# Usage:
#   shell::update_profile [-n] <profile_name>
#
# Parameters:
#   - -n             : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#   - <profile_name> : The name of the profile to update.
#
# Description:
#   Checks if the specified profile exists and opens its profile.conf file in the editor specified
#   by the EDITOR environment variable (defaults to 'nano' if unset).
#
# Example:
#   shell::update_profile my_profile         # Opens profile.conf in the default editor.
#   shell::update_profile -n my_profile      # Prints the editor command without executing it.
shell::update_profile() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_UPDATE_PROFILE"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::update_profile [-n] <profile_name>"
        return 1
    fi
    local profile_name="$1"
    local profile_dir=$(shell::get_profile_workspace "$profile_name")
    local profile_conf="$profile_dir/profile.conf"
    if [ ! -d "$profile_dir" ]; then
        shell::colored_echo "ERR: Profile '$profile_name' does not exist." 196
        return 1
    fi
    if [ ! -f "$profile_conf" ]; then
        shell::colored_echo "ERR: Profile configuration file '$profile_conf' not found." 196
        return 1
    fi
    local editor="${EDITOR:-vi}"
    local cmd="sudo $editor \"$profile_conf\""
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::run_cmd_eval "$cmd"
    fi
}

# shell::remove_profile function
# Deletes the specified profile directory after user confirmation.
#
# Usage:
#   shell::remove_profile [-n] <profile_name>
#
# Parameters:
#   - -n             : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#   - <profile_name> : The name of the profile to remove.
#
# Description:
#   Prompts for confirmation before deleting the profile directory and its contents.
#   If confirmed, removes the directory; otherwise, aborts the operation.
#
# Example:
#   shell::remove_profile my_profile         # Prompts to confirm deletion of my_profile.
#   shell::remove_profile -n my_profile      # Prints the removal command without executing it.
shell::remove_profile() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_REMOVE_PROFILE"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::remove_profile [-n] <profile_name>"
        return 1
    fi
    local profile_name="$1"
    local profile_dir=$(shell::get_profile_workspace "$profile_name")
    if [ ! -d "$profile_dir" ]; then
        shell::colored_echo "ERR: Profile '$profile_name' does not exist." 196
        return 1
    fi
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "sudo rm -rf \"$profile_dir\""
    else
        shell::colored_echo "Are you sure you want to remove profile '$profile_name'? [y/N]" 33
        read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            shell::run_cmd_eval sudo rm -rf "$profile_dir"
            shell::colored_echo "INFO: Removed profile '$profile_name'." 46
        else
            shell::colored_echo "WARN: Removal aborted." 11
        fi
    fi
}

# shell::get_profile function
# Displays the contents of the profile.conf file for the specified profile.
#
# Usage:
#   shell::get_profile <profile_name>
#
# Parameters:
#   - <profile_name> : The name of the profile to display.
#
# Description:
#   Checks if the specified profile exists and displays the contents of its profile.conf file.
#   If the profile or file does not exist, it prints an error.
#
# Example:
#   shell::get_profile my_profile         # Displays the contents of profile.conf for my_profile.
shell::get_profile() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GET_PROFILE"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::get_profile <profile_name>"
        return 1
    fi
    local profile_name="$1"
    local profile_dir=$(shell::get_profile_workspace "$profile_name")
    local profile_conf="$profile_dir/profile.conf"
    if [ ! -d "$profile_dir" ]; then
        shell::colored_echo "ERR: Profile '$profile_name' does not exist." 196
        return 1
    fi
    if [ ! -f "$profile_conf" ]; then
        shell::colored_echo "ERR: Profile configuration file '$profile_conf' not found." 196
        return 1
    fi
    shell::colored_echo "DEBUG: Contents of '$profile_conf':" 244
    shell::run_cmd_eval cat "$profile_conf"
}

# shell::rename_profile function
# Renames the specified profile directory.
#
# Usage:
#   shell::rename_profile [-n] <old_name> <new_name>
#
# Parameters:
#   - -n             : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#   - <old_name>     : The current name of the profile.
#   - <new_name>     : The new name for the profile.
#
# Description:
#   Checks if the old profile exists and the new profile name does not already exist,
#   then renames the directory accordingly.
#
# Example:
#   shell::rename_profile old_profile new_profile         # Renames old_profile to new_profile.
#   shell::rename_profile -n old_profile new_profile      # Prints the rename command without executing it.
shell::rename_profile() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_RENAME_PROFILE"
        return 0
    fi

    if [ $# -lt 2 ]; then
        echo "Usage: shell::rename_profile [-n] <old_name> <new_name>"
        return 1
    fi
    local old_name="$1"
    local new_name="$2"
    local old_dir=$(shell::get_profile_workspace "$old_name")
    local new_dir=$(shell::get_profile_workspace "$new_name")
    if [ ! -d "$old_dir" ]; then
        shell::colored_echo "ERR: Profile '$old_name' does not exist." 196
        return 1
    fi
    if [ -d "$new_dir" ]; then
        shell::colored_echo "ERR: Profile '$new_name' already exists." 196
        return 1
    fi
    local cmd="sudo mv \"$old_dir\" \"$new_dir\""
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::run_cmd_eval "$cmd"
        shell::colored_echo "INFO: Renamed profile '$old_name' to '$new_name'." 46
    fi
}

# shell::add_profile_conf function
# Adds a configuration entry (key=value) to the profile.conf file of a specified profile.
# The value is encoded using Base64 before being saved.
#
# Usage:
#   shell::add_profile_conf [-n] <profile_name> <key> <value>
#
# Parameters:
#   -n             : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#   <profile_name> : The name of the profile.
#   <key>          : The configuration key.
#   <value>        : The configuration value to be encoded and saved.
#
# Description:
#   The function checks for an optional dry-run flag (-n) and ensures that the profile name, key, and value are provided.
#   It encodes the value using Base64 (with newline characters removed) and appends a line in the format:
#       key=encoded_value
#   to the profile.conf file in the specified profile directory. If the profile directory or the profile.conf file does not exist, they are created.
#
# Example:
#   shell::add_profile_conf my_profile my_setting "some secret value"         # Encodes the value and adds the entry to my_profile/profile.conf
#   shell::add_profile_conf -n my_profile my_setting "some secret value"      # Prints the command without executing it
shell::add_profile_conf() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ADD_PROFILE_CONF"
        return 0
    fi

    # Validate the number of arguments
    if [ $# -lt 3 ]; then
        echo "Usage: shell::add_profile_conf [-n] <profile_name> <key> <value>"
        return 1
    fi

    local profile_name="$1"
    local key="$2"
    local value="$3"
    # sanitized key
    key=$(shell::sanitize_upper_var_name "$key")

    # Get the profile directory (assumes shell::get_profile_workspace is defined elsewhere)
    local profile_dir=$(shell::get_profile_workspace "$profile_name")

    # Ensure the profile directory exists
    if [ ! -d "$profile_dir" ]; then
        if [ "$dry_run" = "true" ]; then
            shell::on_evict "sudo mkdir -p \"$profile_dir\""
        else
            shell::run_cmd_eval sudo mkdir -p "$profile_dir"
        fi
    fi

    # Define the profile.conf file path
    local profile_conf="$profile_dir/profile.conf"

    # Ensure the profile.conf file exists
    shell::create_file_if_not_exists "$profile_conf"

    # Encode the value using Base64 and remove any newlines
    local encoded_value
    encoded_value=$(echo -n "$value" | base64 | tr -d '\n')

    # Build the command to append the key and encoded value to the profile.conf file
    local cmd="echo \"$key=$encoded_value\" >> \"$profile_conf\""

    # Execute or print the command based on dry-run mode
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        # Check if the key already exists in the profile.conf
        if grep -q "^${key}=" "$profile_conf"; then
            shell::colored_echo "WARN: The key '$key' already exists in profile '$profile_name'. Consider updating it using shell::update_profile_conf." 11
            return 0
        fi
        shell::unlock_permissions "$profile_conf"
        shell::run_cmd_eval "$cmd"
        shell::colored_echo "INFO: Added configuration to profile '$profile_name': $key (encoded value)" 46
    fi
}

# shell::get_profile_conf function
# Retrieves a configuration profile value by prompting the user to select a config key from the profile's configuration file.
#
# Usage:
#   shell::get_profile_conf [-n] <profile_name>
#
# Parameters:
#   - -n (optional): Dry-run mode. Instead of executing commands, prints them using shell::on_evict.
#   - <profile_name>: The name of the configuration profile.
#
# Description:
#   This function locates the profile directory and its configuration file, verifies that the profile exists,
#   and then ensures that the interactive fuzzy finder (fzf) is installed. It uses fzf to let the user select a configuration key,
#   decodes its base64-encoded value (using the appropriate flag for macOS or Linux), displays the selected key,
#   and finally copies the decoded value to the clipboard asynchronously.
#
# Example:
#   shell::get_profile_conf my_profile          # Retrieves and processes the 'my_profile' profile.
#   shell::get_profile_conf -n my_profile       # Dry-run mode: prints the commands without executing them.
shell::get_profile_conf() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GET_PROFILE_CONF"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::get_profile_conf <profile_name>"
        return 1
    fi
    shell::ensure_workspace
    local profile_name="$1"
    local profile_dir=$(shell::get_profile_workspace "$profile_name")
    local profile_conf="$profile_dir/profile.conf"
    if [ ! -d "$profile_dir" ]; then
        shell::colored_echo "ERR: Profile '$profile_name' does not exist." 196
        return 1
    fi
    if [ ! -f "$profile_conf" ]; then
        shell::colored_echo "ERR: Profile configuration file '$profile_conf' not found." 196
        return 1
    fi
    shell::install_package fzf
    local selected_key
    selected_key=$(cut -d '=' -f 1 "$profile_conf" | fzf --prompt="Select config key for profile '$profile_name': ")
    if [ -z "$selected_key" ]; then
        shell::colored_echo "ERR: No configuration selected." 196
        return 1
    fi
    local selected_line
    selected_line=$(grep "^${selected_key}=" "$profile_conf")
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

# shell::get_profile_conf_value function
# Retrieves a configuration value for a given profile and key by decoding its base64-encoded value.
#
# Usage:
#   shell::get_profile_conf_value [-n] <profile_name> <key>
#
# Parameters:
#   - -n (optional): Dry-run mode. Instead of executing commands, prints them using shell::on_evict.
#   - <profile_name>: The name of the configuration profile.
#   - <key>: The configuration key whose value will be retrieved.
#
# Description:
#   This function ensures that the workspace exists and locates the profile directory
#   and configuration file. It then extracts the configuration line matching the provided key,
#   decodes the associated base64-encoded value (using the appropriate flag for macOS or Linux),
#   asynchronously copies the decoded value to the clipboard, and finally outputs the decoded value.
#
# Example:
#   shell::get_profile_conf_value my_profile API_KEY
#   shell::get_profile_conf_value -n my_profile API_KEY   # Dry-run: prints commands without executing them.
shell::get_profile_conf_value() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GET_PROFILE_CONF_VALUE"
        return 0
    fi

    if [ $# -lt 2 ]; then
        echo "Usage: shell::get_profile_conf_value <profile_name> <key>"
        return 1
    fi
    shell::ensure_workspace
    local profile_name="$1"
    local key="$2"
    local profile_dir=$(shell::get_profile_workspace "$profile_name")
    local profile_conf="$profile_dir/profile.conf"
    # sanitized key
    key=$(shell::sanitize_upper_var_name "$key")

    if [ ! -d "$profile_dir" ]; then
        shell::colored_echo "ERR: Profile '$profile_name' does not exist." 196
        return 1
    fi
    if [ ! -f "$profile_conf" ]; then
        shell::colored_echo "ERR: Profile configuration file '$profile_conf' not found." 196
        return 1
    fi
    local conf_line
    conf_line=$(grep "^${key}=" "$profile_conf")
    if [ -z "$conf_line" ]; then
        shell::colored_echo "ERR: Key '$key' not found in profile '$profile_name'." 196
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

# shell::remove_profile_conf function
# Removes a configuration key from a given profile's configuration file.
#
# Usage:
#   shell::remove_profile_conf [-n] <profile_name>
#
# Parameters:
#   - -n (optional): Dry-run mode. Instead of executing commands, prints them using shell::on_evict.
#   - <profile_name>: The name of the configuration profile.
#
# Description:
#   This function locates the profile directory and its configuration file, verifies their existence,
#   and then uses fzf to let the user select a configuration key to remove.
#   It builds an OS-specific sed command to delete the line containing the selected key.
#   In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed asynchronously
#   using shell::async with shell::run_cmd_eval.
#
# Example:
#   shell::remove_profile_conf my_profile
#   shell::remove_profile_conf -n my_profile   # Dry-run: prints the removal command without executing.
shell::remove_profile_conf() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_REMOVE_PROFILE_CONF"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::remove_profile_conf [-n] <profile_name>"
        return 1
    fi
    shell::ensure_workspace
    local profile_name="$1"
    local profile_dir=$(shell::get_profile_workspace "$profile_name")
    local profile_conf="$profile_dir/profile.conf"
    if [ ! -d "$profile_dir" ]; then
        shell::colored_echo "ERR: Profile '$profile_name' does not exist." 196
        return 1
    fi
    if [ ! -f "$profile_conf" ]; then
        shell::colored_echo "ERR: Profile configuration file '$profile_conf' not found." 196
        return 1
    fi
    shell::install_package fzf
    local selected_key
    selected_key=$(cut -d '=' -f 1 "$profile_conf" | fzf --prompt="Select config key to remove from profile '$profile_name': ")
    if [ -z "$selected_key" ]; then
        shell::colored_echo "ERR: No configuration selected." 196
        return 1
    fi
    local os_type
    os_type=$(shell::get_os_type)
    local sed_cmd=""
    if [ "$os_type" = "macos" ]; then
        sed_cmd="sudo sed -i '' \"/^${selected_key}=/d\" \"$profile_conf\""
    else
        sed_cmd="sudo sed -i \"/^${selected_key}=/d\" \"$profile_conf\""
    fi
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$sed_cmd"
    else
        shell::run_cmd_eval "$sed_cmd"
        shell::colored_echo "INFO: Removed configuration for key: $selected_key from profile '$profile_name'" 46
    fi
}

# shell::update_profile_conf function
# Updates a specified configuration key in a given profile by replacing its value.
#
# Usage:
#   shell::update_profile_conf [-n] <profile_name>
#
# Parameters:
#   - -n              : Optional dry-run flag. If provided, the update command is printed using shell::on_evict without executing.
#   - <profile_name>  : The name of the profile to update.
#
# Description:
#   The function retrieves the profile configuration file, prompts the user to select a key (using fzf),
#   asks for the new value, encodes it in base64, and constructs a sed command to update the key.
#   The sed command is executed asynchronously via the shell::async function (unless in dry-run mode).
#
# Example:
#   shell::update_profile_conf my_profile
#   shell::update_profile_conf -n my_profile   # dry-run mode
shell::update_profile_conf() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_UPDATE_PROFILE_CONF"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::update_profile_conf [-n] <profile_name>"
        return 1
    fi
    local profile_name="$1"
    local profile_dir=$(shell::get_profile_workspace "$profile_name")
    local profile_conf="$profile_dir/profile.conf"
    if [ ! -d "$profile_dir" ]; then
        shell::colored_echo "ERR: Profile '$profile_name' does not exist." 196
        return 1
    fi
    if [ ! -f "$profile_conf" ]; then
        shell::colored_echo "ERR: Profile configuration file '$profile_conf' not found." 196
        return 1
    fi
    shell::install_package fzf
    local selected_key
    selected_key=$(cut -d '=' -f 1 "$profile_conf" | fzf --prompt="Select config key to update in profile '$profile_name': ")
    if [ -z "$selected_key" ]; then
        shell::colored_echo "ERR: No configuration selected." 196
        return 1
    fi
    shell::colored_echo ">> Enter new value for key '$selected_key' in profile '$profile_name':" 33
    read -r new_value
    if [ -z "$new_value" ]; then
        shell::colored_echo "ERR: No new value entered. Update aborted." 196
        return 1
    fi
    local encoded_value
    encoded_value=$(echo -n "$new_value" | base64 | tr -d '\n')
    local os_type
    os_type=$(shell::get_os_type)
    local sed_cmd=""
    if [ "$os_type" = "macos" ]; then
        sed_cmd="sudo sed -i '' \"s/^${selected_key}=.*/${selected_key}=${encoded_value}/\" \"$profile_conf\""
    else
        sed_cmd="sudo sed -i \"s/^${selected_key}=.*/${selected_key}=${encoded_value}/\" \"$profile_conf\""
    fi
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$sed_cmd"
    else
        shell::run_cmd_eval "$sed_cmd"
        shell::colored_echo "INFO: Updated configuration for key: $selected_key in profile '$profile_name'" 46
    fi
}

# shell::exist_profile_conf_key function
# Checks whether a specified key exists in the configuration file of a given profile.
#
# Usage:
#   shell::exist_profile_conf_key <profile_name> <key>
#
# Parameters:
#   - <profile_name>: The name of the profile.
#   - <key>         : The configuration key to search for.
#
# Description:
#   The function constructs the path to the profile's configuration file and verifies that the profile directory exists.
#   It then checks if the configuration file exists. If both exist, it searches for the specified key using grep.
#   The function outputs "true" if the key is found and "false" otherwise.
#
# Example:
#   shell::exist_profile_conf_key my_profile my_key
shell::exist_profile_conf_key() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_EXIST_PROFILE_CONF_KEY"
        return 0
    fi

    if [ $# -lt 2 ]; then
        echo "Usage: shell::exist_profile_conf_key <profile_name> <key>"
        return 1
    fi
    local profile_name="$1"
    local key="$2"
    local profile_dir=$(shell::get_profile_workspace "$profile_name")
    local profile_conf="$profile_dir/profile.conf"
    # sanitized key
    key=$(shell::sanitize_upper_var_name "$key")

    if [ ! -d "$profile_dir" ]; then
        shell::colored_echo "ERR: Profile '$profile_name' does not exist." 196
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

# shell::rename_profile_conf_key function
# Renames an existing configuration key in a given profile.
#
# Usage:
#   shell::rename_profile_conf_key [-n] <profile_name>
#
# Parameters:
#   - -n            : Optional dry-run flag. If provided, prints the sed command using shell::on_evict without executing.
#   - <profile_name>: The name of the profile whose key should be renamed.
#
# Description:
#   The function checks that the profile directory and configuration file exist.
#   It then uses fzf to allow the user to select the existing key to rename.
#   After prompting for a new key name and verifying that it does not already exist,
#   the function constructs an OS-specific sed command to replace the old key with the new one.
#   In dry-run mode, the command is printed via shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.
#
# Example:
#   shell::rename_profile_conf_key my_profile
#   shell::rename_profile_conf_key -n my_profile   # dry-run mode
shell::rename_profile_conf_key() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_RENAME_PROFILE_CONF_KEY"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::rename_profile_conf_key [-n] <profile_name>"
        return 1
    fi
    local profile_name="$1"
    local profile_dir=$(shell::get_profile_workspace "$profile_name")
    local profile_conf="$profile_dir/profile.conf"
    if [ ! -d "$profile_dir" ]; then
        shell::colored_echo "ERR: Profile '$profile_name' does not exist." 196
        return 1
    fi
    if [ ! -f "$profile_conf" ]; then
        shell::colored_echo "ERR: Profile configuration file '$profile_conf' not found." 196
        return 1
    fi
    shell::install_package fzf
    local old_key
    old_key=$(cut -d '=' -f 1 "$profile_conf" | fzf --prompt="Select a key to rename in profile '$profile_name': ")
    if [ -z "$old_key" ]; then
        shell::colored_echo "ERR: No key selected. Aborting rename." 196
        return 1
    fi
    shell::colored_echo "Enter new key name for '$old_key' in profile '$profile_name':" 33
    read -r new_key
    if [ -z "$new_key" ]; then
        shell::colored_echo "ERR: No new key name entered. Aborting rename." 196
        return 1
    fi
    # sanitized key
    new_key=$(shell::sanitize_upper_var_name "$new_key")

    if grep -q "^${new_key}=" "$profile_conf"; then
        shell::colored_echo "ERR: Key '$new_key' already exists in profile '$profile_name'." 196
        return 1
    fi
    local os_type
    os_type=$(shell::get_os_type)
    local sed_cmd=""
    if [ "$os_type" = "macos" ]; then
        sed_cmd="sudo sed -i '' \"s/^${old_key}=/${new_key}=/\" \"$profile_conf\""
    else
        sed_cmd="sudo sed -i \"s/^${old_key}=/${new_key}=/\" \"$profile_conf\""
    fi
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$sed_cmd"
    else
        shell::run_cmd_eval "$sed_cmd"
        shell::colored_echo "INFO: Renamed key '$old_key' to '$new_key' in profile '$profile_name'" 46
    fi
}

# shell::clone_profile_conf function
# Clones a configuration profile by copying its profile.conf from a source profile to a destination profile.
#
# Usage:
#   shell::clone_profile_conf [-n] <source_profile> <destination_profile>
#
# Parameters:
#   - -n               : (Optional) Dry-run flag. If provided, the command is printed but not executed.
#   - <source_profile> : The name of the source profile.
#   - <destination_profile> : The name of the destination profile.
#
# Description:
#   This function retrieves the source and destination profile directories using shell::get_profile_workspace,
#   verifies that the source profile exists and has a profile.conf file, and ensures that the destination
#   profile does not already exist. If validations pass, it clones the configuration by creating the destination
#   directory and copying the profile.conf file from the source to the destination. When the dry-run flag (-n)
#   is provided, it prints the command without executing it.
#
# Example:
#   shell::clone_profile_conf my_profile backup_profile   # Clones profile.conf from 'my_profile' to 'backup_profile'
shell::clone_profile_conf() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_CLONE_PROFILE_CONF"
        return 0
    fi

    if [ $# -lt 2 ]; then
        echo "Usage: shell::clone_profile_conf [-n] <source_profile> <destination_profile>"
        return 1
    fi
    local source_profile="$1"
    local destination_profile="$2"
    local source_dir=$(shell::get_profile_workspace "$source_profile")
    local destination_dir=$(shell::get_profile_workspace "$destination_profile")
    local source_conf="$source_dir/profile.conf"
    local destination_conf="$destination_dir/profile.conf"
    if [ ! -d "$source_dir" ]; then
        shell::colored_echo "ERR: Source profile '$source_profile' does not exist." 196
        return 1
    fi
    if [ ! -f "$source_conf" ]; then
        shell::colored_echo "ERR: Source profile configuration file '$source_conf' not found." 196
        return 1
    fi
    if [ -d "$destination_dir" ]; then
        shell::colored_echo "ERR: Destination profile '$destination_profile' already exists." 196
        return 1
    fi
    local cmd="sudo mkdir -p \"$destination_dir\" && sudo cp \"$source_conf\" \"$destination_conf\""
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::run_cmd_eval "$cmd"
        shell::colored_echo "INFO: Cloned profile.conf from '$source_profile' to '$destination_profile'" 46
    fi
}

# shell::list_profile_conf function
# Lists all available configuration profiles in the workspace.
#
# Usage:
#   shell::list_profile_conf
#
# Description:
#   This function checks that the workspace directory ($SHELL_CONF_WORKING/workspace) exists.
#   It then finds all subdirectories (each representing a profile) and prints their names.
#   If no profiles are found, an appropriate message is displayed.
#
# Example:
#   shell::list_profile_conf       # Displays the names of all profiles in the workspace.
shell::list_profile_conf() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_LIST_PROFILE_CONF"
        return 0
    fi

    # Ensure that the workspace exists.
    shell::ensure_workspace

    # Check if the workspace directory exists.
    if [ ! -d "$SHELL_CONF_WORKING_WORKSPACE" ]; then
        shell::colored_echo "ERR: Workspace directory '$SHELL_CONF_WORKING_WORKSPACE' does not exist." 196
        return 1
    fi

    # Find all subdirectories (profiles) in the workspace.
    local profiles
    profiles=$(find "$SHELL_CONF_WORKING_WORKSPACE" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

    # Check if any profiles were found.
    if [ -z "$profiles" ]; then
        shell::colored_echo "ERR: No profiles found in workspace." 196
        return 1
    fi

    shell::colored_echo "DEBUG: Available profiles:" 244

    # List profile names by extracting the basename from each directory path.
    echo "$profiles" | xargs -n 1 basename
}
