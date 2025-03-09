#!/bin/bash
# key.sh

# read_conf function
# Sources a configuration file, allowing its variables and functions to be loaded into the current shell.
#
# Usage:
#   read_conf [-n] <filename>
#
# Parameters:
#   - -n       : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
#   - <filename>: The configuration file to source.
#
# Description:
#   The function checks that a filename is provided and that the specified file exists.
#   If the file is not found, an error message is displayed.
#   In dry-run mode, the command "source <filename>" is printed using on_evict.
#   Otherwise, the file is sourced using run_cmd to log the execution.
#
# Example:
#   read_conf ~/.my-config                # Sources the configuration file.
#   read_conf -n ~/.my-config             # Prints the sourcing command without executing it.
read_conf() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: read_conf [-n] <filename>"
        return 1
    fi

    local filename="$1"

    # Verify that the configuration file exists.
    if [[ ! -f "$filename" ]]; then
        colored_echo "🔴 Error: Conf file '$filename' not found." 196
        return 1
    fi

    # Build and execute (or print) the command to source the configuration file.
    if [ "$dry_run" = "true" ]; then
        on_evict "source \"$filename\""
    else
        run_cmd source "$filename"
    fi
}

# add_conf function
# Adds a configuration entry (key=value) to a constant configuration file.
# The value is encoded using Base64 before being saved.
#
# Usage:
#   add_conf [-n] <key> <value>
#
# Parameters:
#   - -n       : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
#   - <key>    : The configuration key.
#   - <value>  : The configuration value to be encoded and saved.
#
# Description:
#   The function first checks for an optional dry-run flag (-n) and verifies that both key and value are provided.
#   It encodes the value using Base64 (with newline characters removed) and then appends a line in the format:
#       key=encoded_value
#   to a constant configuration file (defined by SHELL_CONF_FILE). If the configuration file does not exist, it is created.
#
# Example:
#   add_conf my_setting "some secret value"         # Encodes the value and adds the entry.
#   add_conf -n my_setting "some secret value"      # Prints the command without executing it.
add_conf() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -lt 2 ]; then
        echo "Usage: add_conf [-n] <key> <value>"
        return 1
    fi

    local key="$1"
    local value="$2"

    # Encode the value using Base64 and remove any newlines.
    local encoded_value
    encoded_value=$(echo -n "$value" | base64 | tr -d '\n')

    # Ensure the configuration file exists.
    create_file_if_not_exists "$SHELL_CONF_FILE"
    grant777 "$SHELL_CONF_FILE"

    # Build the command to append the key and encoded value to the configuration file.
    local cmd="echo \"$key=$encoded_value\" >> \"$SHELL_CONF_FILE\""

    if [ "$dry_run" = "true" ]; then
        on_evict "$cmd"
    else
        run_cmd_eval "$cmd"
        colored_echo "🟢 Added configuration: $key (encoded value)" 46
    fi
}

# get_conf function
# Interactively selects a configuration key from a constant configuration file using fzf,
# then decodes and displays its corresponding value.
#
# Usage:
#   get_conf
#
# Description:
#   The function reads the configuration file defined by the constant SHELL_CONF_FILE,
#   which is expected to have entries in the format:
#       key=encoded_value
#   Instead of listing the entire line, it extracts only the keys (before the '=') and uses fzf
#   for interactive selection. Once a key is selected, it looks up the full entry,
#   decodes the Base64-encoded value (using -D on macOS and -d on Linux), and then displays the key
#   and its decoded value.
#
# Example:
#   get_conf      # Interactively select a key and display its decoded value.
get_conf() {
    if [ ! -f "$SHELL_CONF_FILE" ]; then
        colored_echo "🔴 Error: Configuration file '$SHELL_CONF_FILE' not found." 196
        return 1
    fi

    # Extract only the keys from the configuration file and select one using fzf.
    local selected_key
    selected_key=$(cut -d '=' -f 1 "$SHELL_CONF_FILE" | fzf --prompt="Select config key: ")
    if [ -z "$selected_key" ]; then
        colored_echo "🔴 No configuration selected." 196
        return 1
    fi

    # Retrieve the full line corresponding to the selected key.
    local selected_line
    selected_line=$(grep "^${selected_key}=" "$SHELL_CONF_FILE")
    if [ -z "$selected_line" ]; then
        colored_echo "🔴 Error: Selected key '$selected_key' not found in configuration." 196
        return 1
    fi

    local encoded_value
    encoded_value=$(echo "$selected_line" | cut -d '=' -f 2-)

    local os_type
    os_type=$(get_os_type)
    local decoded_value
    if [ "$os_type" = "macos" ]; then
        decoded_value=$(echo "$encoded_value" | base64 -D)
    else
        decoded_value=$(echo "$encoded_value" | base64 -d)
    fi

    colored_echo "🔑 Key: $selected_key" 33
    clip_value "$decoded_value"
}

# remove_conf function
# Interactively selects a configuration key from a constant configuration file using fzf,
# then removes the corresponding entry from the configuration file.
#
# Usage:
#   remove_conf [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the removal command is printed using on_evict instead of executed.
#
# Description:
#   The function reads the configuration file defined by the constant SHELL_CONF_FILE, where each entry is in the format:
#       key=encoded_value
#   It extracts only the keys (before the '=') and uses fzf for interactive selection.
#   Once a key is selected, it constructs a command to remove the line that starts with "key=" from the configuration file.
#   The command uses sed with different options depending on the operating system (macOS or Linux).
#   In dry-run mode, the command is printed using on_evict; otherwise, it is executed using run_cmd_eval.
#
# Example:
#   remove_conf         # Interactively select a key and remove its configuration entry.
#   remove_conf -n      # Prints the removal command without executing it.
remove_conf() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ ! -f "$SHELL_CONF_FILE" ]; then
        colored_echo "🔴 Error: Configuration file '$SHELL_CONF_FILE' not found." 196
        return 1
    fi

    # Extract only the keys from the configuration file and select one using fzf.
    local selected_key
    selected_key=$(cut -d '=' -f 1 "$SHELL_CONF_FILE" | fzf --prompt="Select config key to remove: ")
    if [ -z "$selected_key" ]; then
        colored_echo "🔴 No configuration selected." 196
        return 1
    fi

    local os_type
    os_type=$(get_os_type)
    local sed_cmd=""
    local use_sudo="sudo "

    # Check if the configuration file is writable; if not, use sudo.
    # if [ ! -w "$SHELL_CONF_FILE" ]; then
    #     use_sudo="sudo "
    # fi

    # Construct the sed command to remove the line starting with "selected_key="
    if [ "$os_type" = "macos" ]; then
        # On macOS, use sed -i '' for in-place editing.
        sed_cmd="${use_sudo}sed -i '' \"/^${selected_key}=/d\" \"$SHELL_CONF_FILE\""
    else
        # On Linux, use sed -i for in-place editing.
        sed_cmd="${use_sudo}sed -i \"/^${selected_key}=/d\" \"$SHELL_CONF_FILE\""
    fi

    if [ "$dry_run" = "true" ]; then
        on_evict "$sed_cmd"
    else
        run_cmd_eval "$sed_cmd"
        colored_echo "🟢 Removed configuration for key: $selected_key" 46
    fi
}

# update_conf function
# Interactively updates the value for a configuration key in a constant configuration file.
# The new value is encoded using Base64 before updating the file.
#
# Usage:
#   update_conf [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the update command is printed using on_evict instead of executed.
#
# Description:
#   The function reads the configuration file defined by SHELL_CONF_FILE, which contains entries in the format:
#       key=encoded_value
#   It extracts only the keys and uses fzf to allow interactive selection.
#   Once a key is selected, the function prompts for a new value, encodes it using Base64 (with newlines removed),
#   and then updates the corresponding configuration entry in the file by replacing the line starting with "key=".
#   The sed command used for in-place update differs between macOS and Linux.
#
# Example:
#   update_conf       # Interactively select a key, enter a new value, and update its entry.
#   update_conf -n    # Prints the update command without executing it.
update_conf() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ ! -f "$SHELL_CONF_FILE" ]; then
        colored_echo "🔴 Error: Configuration file '$SHELL_CONF_FILE' not found." 196
        return 1
    fi

    # Extract only the keys from the configuration file and select one using fzf.
    local selected_key
    selected_key=$(cut -d '=' -f 1 "$SHELL_CONF_FILE" | fzf --prompt="Select config key to update: ")
    if [ -z "$selected_key" ]; then
        colored_echo "🔴 No configuration selected." 196
        return 1
    fi

    # Prompt the user for the new value.
    colored_echo ">> Enter new value for key '$selected_key':" 33
    read -r new_value
    if [ -z "$new_value" ]; then
        colored_echo "🔴 No new value entered. Update aborted." 196
        return 1
    fi

    # Encode the new value using Base64 and remove any newline characters.
    local encoded_value
    encoded_value=$(echo -n "$new_value" | base64 | tr -d '\n')

    local os_type
    os_type=$(get_os_type)
    local sed_cmd=""
    local use_sudo="sudo "

    # Construct the sed command to update the line starting with "selected_key=".
    if [ "$os_type" = "macos" ]; then
        # For macOS, use sed -i '' for in-place editing.
        sed_cmd="${use_sudo}sed -i '' \"s/^${selected_key}=.*/${selected_key}=${encoded_value}/\" \"$SHELL_CONF_FILE\""
    else
        # For Linux, use sed -i for in-place editing.
        sed_cmd="${use_sudo}sed -i \"s/^${selected_key}=.*/${selected_key}=${encoded_value}/\" \"$SHELL_CONF_FILE\""
    fi

    if [ "$dry_run" = "true" ]; then
        on_evict "$sed_cmd"
    else
        run_cmd_eval "$sed_cmd"
        colored_echo "🟢 Updated configuration for key: $selected_key" 46
    fi
}

# add_group function
# Groups selected configuration keys under a specified group name.
#
# Usage:
#   add_group [-n]
#
# Description:
#   This function prompts you to enter a group name, then uses fzf (with multi-select) to let you choose
#   one or more configuration keys (from SHELL_CONF_FILE). It then stores the group in GROUP_CONF_FILE in the format:
#       group_name=key1,key2,...,keyN
#   If the group name already exists, the group entry is updated with the new selection.
#   An optional dry-run flag (-n) can be used to print the command via on_evict instead of executing it.
#
# Example:
#   add_group         # Prompts for a group name and lets you select keys to group.
#   add_group -n      # Prints the command for creating/updating the group without executing it.
add_group() {
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Ensure the group configuration file exists.
    create_file_if_not_exists "$GROUP_CONF_FILE"
    grant777 "$GROUP_CONF_FILE"

    # Prompt the user for a group name.
    colored_echo "Enter group name:" 33
    read -r group_name
    if [ -z "$group_name" ]; then
        colored_echo "🔴 No group name entered. Aborting." 196
        return 1
    fi

    # Ensure the individual configuration file exists.
    if [ ! -f "$SHELL_CONF_FILE" ]; then
        colored_echo "🔴 Error: Configuration file '$SHELL_CONF_FILE' not found." 196
        return 1
    fi

    # Use fzf with multi-select to choose keys from SHELL_CONF_FILE.
    local selected_keys
    selected_keys=$(cut -d '=' -f 1 "$SHELL_CONF_FILE" | fzf --multi --prompt="Select config keys for group '$group_name': ")
    if [ -z "$selected_keys" ]; then
        colored_echo "🔴 No keys selected. Aborting group creation." 196
        return 1
    fi

    # Convert the multi-line selection to a comma-separated list.
    local keys_csv
    keys_csv=$(echo "$selected_keys" | paste -sd "," -)

    # Construct the group entry in the format: group_name=key1,key2,...,keyN
    local group_entry="${group_name}=${keys_csv}"

    # If the group already exists, update it; otherwise, append it.
    if grep -q "^${group_name}=" "$GROUP_CONF_FILE"; then
        local os_type
        os_type=$(get_os_type)
        local sed_cmd=""
        if [ "$os_type" = "macos" ]; then
            sed_cmd="sed -i '' \"s/^${group_name}=.*/${group_entry}/\" \"$GROUP_CONF_FILE\""
        else
            sed_cmd="sed -i \"s/^${group_name}=.*/${group_entry}/\" \"$GROUP_CONF_FILE\""
        fi
        if [ "$dry_run" = "true" ]; then
            on_evict "$sed_cmd"
        else
            run_cmd_eval "$sed_cmd"
            colored_echo "🟢 Updated group '$group_name' with keys: $keys_csv" 46
        fi
    else
        local cmd="echo \"$group_entry\" >> \"$GROUP_CONF_FILE\""
        if [ "$dry_run" = "true" ]; then
            on_evict "$cmd"
        else
            run_cmd_eval "$cmd"
            colored_echo "🟢 Created group '$group_name' with keys: $keys_csv" 46
        fi
    fi
}

# read_group function
# Reads and displays the configurations for a given group by group name.
#
# Usage:
#   read_group <group_name>
#
# Description:
#   This function looks up the group entry in GROUP_CONF_FILE for the specified group name.
#   The group entry is expected to be in the format:
#       group_name=key1,key2,...,keyN
#   For each key in the group, the function retrieves the corresponding configuration entry from SHELL_CONF_FILE,
#   decodes the Base64-encoded value (using -D on macOS and -d on Linux), and groups the key-value pairs
#   into a JSON object which is displayed.
#
# Example:
#   read_group my_group   # Displays the configurations for the keys in the group 'my_group'.
read_group() {
    if [ $# -lt 1 ]; then
        echo "Usage: read_group <group_name>"
        return 1
    fi

    local group_name="$1"

    if [ ! -f "$GROUP_CONF_FILE" ]; then
        colored_echo "🔴 Error: Group configuration file '$GROUP_CONF_FILE' not found." 196
        return 1
    fi

    # Retrieve the group entry for the specified group name.
    local group_entry
    group_entry=$(grep "^${group_name}=" "$GROUP_CONF_FILE")
    if [ -z "$group_entry" ]; then
        colored_echo "🔴 Error: Group '$group_name' not found." 196
        return 1
    fi

    # Extract the comma-separated list of keys.
    local keys_csv
    keys_csv=$(echo "$group_entry" | cut -d '=' -f 2-)
    if [ -z "$keys_csv" ]; then
        colored_echo "🔴 Error: No keys defined in group '$group_name'." 196
        return 1
    fi

    local os_type
    os_type=$(get_os_type)
    local json_obj="{"
    local first=1

    # Convert the comma-separated keys to an array in a way compatible with both Bash and zsh.
    if [ -n "$BASH_VERSION" ]; then
        IFS=',' read -r -a keys_array <<<"$keys_csv"
    else
        IFS=',' read -rA keys_array <<<"$keys_csv"
    fi

    for key in "${keys_array[@]}"; do
        # Retrieve the configuration entry from SHELL_CONF_FILE for each key.
        local conf_line
        conf_line=$(grep "^${key}=" "$SHELL_CONF_FILE")
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
    colored_echo "$json_obj" 33
}

# list_groups function
# Lists all group names defined in the group configuration file.
#
# Usage:
#   list_groups
#
# Description:
#   This function reads the configuration file defined by GROUP_CONF_FILE,
#   where each line is in the format:
#       group_name=key1,key2,...,keyN
#   It extracts and displays the group names (the part before the '=')
#   using the 'cut' command.
#
# Example:
#   list_groups       # Displays all group names.
list_groups() {
    if [ ! -f "$GROUP_CONF_FILE" ]; then
        colored_echo "🔴 Error: Group configuration file '$GROUP_CONF_FILE' not found." 196
        return 1
    fi

    # Extract group names from the configuration file.
    local groups
    groups=$(cut -d '=' -f 1 "$GROUP_CONF_FILE")
    if [ -z "$groups" ]; then
        colored_echo "🔴 No groups found in '$GROUP_CONF_FILE'." 196
        return 1
    fi

    colored_echo "📁 Group Names:" 33
    echo "$groups"
}

# select_group function
# Interactively selects a group name from the group configuration file using fzf,
# then lists all keys belonging to the selected group and uses fzf to choose one key,
# finally displaying the decoded value for the selected key.
#
# Usage:
#   select_group
#
# Description:
#   The function reads the configuration file defined by GROUP_CONF_FILE, where each line is in the format:
#       group_name=key1,key2,...,keyN
#   It first uses fzf to allow interactive selection of a group name.
#   Once a group is selected, the function extracts the comma-separated list of keys,
#   converts them into a list (one per line), and uses fzf again to let you choose one key.
#   It then retrieves the corresponding configuration entry from SHELL_CONF_FILE (which stores entries as key=encoded_value),
#   decodes the Base64-encoded value (using -D on macOS and -d on Linux), and displays the group name, key, and decoded value.
#
# Example:
#   select_group   # Prompts to select a group, then a key within that group, and displays the decoded value.
select_group() {
    # Ensure the group configuration file exists.
    if [ ! -f "$GROUP_CONF_FILE" ]; then
        colored_echo "🔴 Error: Group configuration file '$GROUP_CONF_FILE' not found." 196
        return 1
    fi

    # Extract group names from GROUP_CONF_FILE and let the user select one.
    local groups
    groups=$(cut -d '=' -f 1 "$GROUP_CONF_FILE")
    local selected_group
    selected_group=$(echo "$groups" | fzf --prompt="Select a group name: ")
    if [ -z "$selected_group" ]; then
        colored_echo "🔴 No group selected." 196
        return 1
    fi

    # Retrieve the group entry for the selected group.
    local group_entry
    group_entry=$(grep "^${selected_group}=" "$GROUP_CONF_FILE")
    if [ -z "$group_entry" ]; then
        colored_echo "🔴 Error: Group '$selected_group' not found in configuration." 196
        return 1
    fi

    # Extract the comma-separated list of keys.
    local keys_csv
    keys_csv=$(echo "$group_entry" | cut -d '=' -f 2-)
    if [ -z "$keys_csv" ]; then
        colored_echo "🔴 Error: No keys defined in group '$selected_group'." 196
        return 1
    fi

    # Convert the comma-separated keys into a list (one per line) and use fzf to select one key.
    local selected_key
    selected_key=$(echo "$keys_csv" | tr ',' '\n' | fzf --prompt="Select a key from group '$selected_group': ")
    if [ -z "$selected_key" ]; then
        colored_echo "🔴 No key selected from group '$selected_group'." 196
        return 1
    fi

    # Ensure the individual configuration file exists.
    if [ ! -f "$SHELL_CONF_FILE" ]; then
        colored_echo "🔴 Error: Configuration file '$SHELL_CONF_FILE' not found." 196
        return 1
    fi

    # Retrieve the configuration entry corresponding to the selected key.
    local conf_line
    conf_line=$(grep "^${selected_key}=" "$SHELL_CONF_FILE")
    if [ -z "$conf_line" ]; then
        colored_echo "🔴 Error: Key '$selected_key' not found in configuration." 196
        return 1
    fi

    # Extract the encoded value.
    local encoded_value
    encoded_value=$(echo "$conf_line" | cut -d '=' -f 2-)

    # Decode the value based on the operating system.
    local os_type
    os_type=$(get_os_type)
    local decoded_value
    if [ "$os_type" = "macos" ]; then
        decoded_value=$(echo "$encoded_value" | base64 -D)
    else
        decoded_value=$(echo "$encoded_value" | base64 -d)
    fi

    # Display the results.
    colored_echo "📁 Group: $selected_group" 33
    colored_echo "🔑 Key: $selected_key" 33
    clip_value "$decoded_value"
}
