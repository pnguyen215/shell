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
        run_cmd "$cmd"
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
#   The function reads the configuration file defined by the constant SHELL_CONF_FILE, where each line is in the format:
#       key=encoded_value
#   It uses fzf to allow interactive selection of one entry. Once a key is selected, the function extracts the encoded value,
#   decodes it using Base64 (using -D on macOS and -d on Linux), and then displays the key and the decoded value.
#
# Example:
#   get_conf      # Interactively select a key and display its decoded value.
get_conf() {
    if [ ! -f "$SHELL_CONF_FILE" ]; then
        colored_echo "🔴 Error: Configuration file '$SHELL_CONF_FILE' not found." 196
        return 1
    fi

    local selected_line
    selected_line=$(cat "$SHELL_CONF_FILE" | fzf --prompt="Select config key: ")
    if [ -z "$selected_line" ]; then
        colored_echo "🔴 No configuration selected." 196
        return 1
    fi

    local key
    key=$(echo "$selected_line" | cut -d '=' -f 1)
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

    colored_echo "🔑 Key: $key" 33
    colored_echo "🔓 Value: $decoded_value" 33
}
