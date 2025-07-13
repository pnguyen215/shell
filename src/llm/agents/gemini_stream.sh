#!/bin/bash
# gemini_stream.sh

# shell::show_gemini_help function
# Displays help information for Gemini streaming functionality.
#
# Usage:
#   shell::show_gemini_help [-h]
#
# Parameters:
#   - -h : Optional help flag. If provided, displays usage information.
#
# Description:
#   This function displays comprehensive help information for Gemini streaming functionality,
#   including available commands, configuration options, and usage examples.
#   It provides users with guidance on how to use the streaming features.
#
# Example:
#   shell::show_gemini_help
shell::show_gemini_help() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_SHOW_GEMINI_HELP"
        return 0
    fi

    shell::colored_echo "Gemini Streaming Help" 51
    shell::colored_echo "=====================" 51
    shell::colored_echo "" 255
    shell::colored_echo "Available Commands:" 33
    shell::colored_echo "  shell::list_gemini_models       - List available Gemini models" 244
    shell::colored_echo "  shell::load_gemini_config       - Load Gemini configuration" 244
    shell::colored_echo "  shell::save_gemini_config       - Save Gemini configuration" 244
    shell::colored_echo "  shell::clear_gemini_conversation - Clear conversation history" 244
    shell::colored_echo "  shell::stream_gemini_response   - Stream response from Gemini" 244
    shell::colored_echo "  shell::display_gemini_with_glow - Display response with formatting" 244
    shell::colored_echo "" 255
    shell::colored_echo "Configuration:" 33
    shell::colored_echo "  Config file: $SHELL_KEY_CONF_AGENT_GEMINI_FILE" 244
    shell::colored_echo "" 255
    shell::colored_echo "Example Usage:" 33
    shell::colored_echo "  shell::stream_gemini_response \"Hello, how are you?\"" 244
    shell::colored_echo "  shell::stream_gemini_response -n \"Dry run example\"" 244
}

# shell::list_gemini_models function
# Lists available Gemini models for streaming and non-streaming requests.
#
# Usage:
#   shell::list_gemini_models [-n] [-h]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the API request is printed using shell::on_evict instead of executed.
#   - -h : Optional help flag. If provided, displays usage information.
#
# Description:
#   This function retrieves and displays a list of available Gemini models by making an API request
#   to the Gemini service. It shows model names, descriptions, and capabilities.
#   In dry-run mode, it shows what API call would be made without actually executing it.
#
# Example:
#   shell::list_gemini_models
#   shell::list_gemini_models -n
shell::list_gemini_models() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_LIST_GEMINI_MODELS"
        return 0
    fi

    # Check if the -n flag is provided for dry-run
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if the Gemini configuration file exists
    if [ ! -f "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" ]; then
        shell::colored_echo "ERR: Gemini config file not found at '$SHELL_KEY_CONF_AGENT_GEMINI_FILE'" 196
        shell::colored_echo "INFO: Run shell::populate_gemini_conf to create default configuration" 33
        return 1
    fi

    # Read the API_KEY from the Gemini config file
    local api_key=$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "API_KEY")

    # Check if API_KEY is set
    if [ -z "$api_key" ]; then
        shell::colored_echo "ERR: API_KEY config not found in Gemini config file ($SHELL_KEY_CONF_AGENT_GEMINI_FILE)." 196
        return 1
    fi

    local url="https://generativelanguage.googleapis.com/v1beta/models?key=${api_key}"

    # Check if dry-run is enabled
    if [ "$dry_run" = "true" ]; then
        local curl_cmd="curl -s -X GET \"$url\" -H \"Content-Type: application/json\""
        shell::on_evict "$curl_cmd"
        return 0
    fi

    # Make the API request
    local response
    response=$(curl -s -X GET "$url" -H "Content-Type: application/json")

    # Check if the request was successful
    if [ $? -ne 0 ]; then
        shell::colored_echo "ERR: Failed to connect to Gemini API." 196
        return 1
    fi

    # Check if the response is empty
    if [ -z "$response" ]; then
        shell::colored_echo "ERR: No response from Gemini API." 196
        return 1
    fi

    # Check if the response contains an error
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        local error_message
        error_message=$(echo "$response" | jq -r '.error.message')
        shell::colored_echo "ERR: Gemini API error: $error_message" 196
        return 1
    fi

    # Display the models
    shell::colored_echo "Available Gemini Models:" 51
    shell::colored_echo "========================" 51
    
    echo "$response" | jq -r '.models[]? | "\(.name) - \(.displayName // "No description")"' 2>/dev/null | while read -r line; do
        if [ -n "$line" ]; then
            shell::colored_echo "  $line" 244
        fi
    done

    return 0
}

# shell::get_gemini_mime_type function
# Determines the MIME type of a file for Gemini API requests.
#
# Usage:
#   shell::get_gemini_mime_type [-n] [-h] <file_path>
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#   - -h : Optional help flag. If provided, displays usage information.
#   - <file_path> : Required. The path to the file to analyze.
#
# Description:
#   This function determines the MIME type of a file using the `file` command.
#   It returns the MIME type in a format suitable for Gemini API requests.
#   Supports common file types like images, text, audio, and video.
#
# Example:
#   shell::get_gemini_mime_type "image.jpg"
#   shell::get_gemini_mime_type -n "document.pdf"
shell::get_gemini_mime_type() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GET_GEMINI_MIME_TYPE"
        return 0
    fi

    # Check if the -n flag is provided for dry-run
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if file path is provided
    if [ -z "$1" ]; then
        shell::colored_echo "ERR: File path is required" 196
        echo "Usage: shell::get_gemini_mime_type [-n] <file_path>"
        return 1
    fi

    local file_path="$1"

    # Check if file exists
    if [ ! -f "$file_path" ]; then
        shell::colored_echo "ERR: File not found: $file_path" 196
        return 1
    fi

    # Construct the command to get MIME type
    local cmd="file --mime-type -b \"$file_path\""

    # Check if dry-run is enabled
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
        return 0
    fi

    # Get the MIME type
    local mime_type
    mime_type=$(file --mime-type -b "$file_path")

    if [ $? -ne 0 ] || [ -z "$mime_type" ]; then
        shell::colored_echo "ERR: Failed to determine MIME type for: $file_path" 196
        return 1
    fi

    echo "$mime_type"
    return 0
}

# shell::encode_gemini_file function
# Encodes a file to Base64 format for inclusion in Gemini API requests.
#
# Usage:
#   shell::encode_gemini_file [-n] [-h] <file_path>
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#   - -h : Optional help flag. If provided, displays usage information.
#   - <file_path> : Required. The path to the file to encode.
#
# Description:
#   This function encodes a file to Base64 format suitable for Gemini API requests.
#   It validates the file exists and is readable before encoding.
#   The output is the Base64-encoded content without line breaks.
#
# Example:
#   shell::encode_gemini_file "image.jpg"
#   shell::encode_gemini_file -n "document.pdf"
shell::encode_gemini_file() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ENCODE_GEMINI_FILE"
        return 0
    fi

    # Check if the -n flag is provided for dry-run
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if file path is provided
    if [ -z "$1" ]; then
        shell::colored_echo "ERR: File path is required" 196
        echo "Usage: shell::encode_gemini_file [-n] <file_path>"
        return 1
    fi

    local file_path="$1"

    # Check if file exists
    if [ ! -f "$file_path" ]; then
        shell::colored_echo "ERR: File not found: $file_path" 196
        return 1
    fi

    # Check if file is readable
    if [ ! -r "$file_path" ]; then
        shell::colored_echo "ERR: File is not readable: $file_path" 196
        return 1
    fi

    # Get OS type for platform-specific base64 command
    local os_type=$(shell::get_os_type)
    local cmd

    # Construct base64 command based on OS
    if [ "$os_type" = "macos" ]; then
        cmd="base64 -i \"$file_path\""
    else
        cmd="base64 -w 0 \"$file_path\""
    fi

    # Check if dry-run is enabled
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
        return 0
    fi

    # Encode the file
    local encoded_content
    if [ "$os_type" = "macos" ]; then
        encoded_content=$(base64 -i "$file_path")
    else
        encoded_content=$(base64 -w 0 "$file_path")
    fi

    if [ $? -ne 0 ] || [ -z "$encoded_content" ]; then
        shell::colored_echo "ERR: Failed to encode file: $file_path" 196
        return 1
    fi

    echo "$encoded_content"
    return 0
}

# shell::load_gemini_config function
# Loads Gemini configuration from the configuration file and exports to environment variables.
#
# Usage:
#   shell::load_gemini_config [-n] [-h] [config_file]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h : Optional help flag. If provided, displays usage information.
#   - [config_file] : Optional. Path to the configuration file. Defaults to SHELL_KEY_CONF_AGENT_GEMINI_FILE.
#
# Description:
#   This function loads Gemini configuration from the specified file and exports
#   key-value pairs as environment variables prefixed with GEMINI_.
#   It validates the configuration file exists and reads all keys from the [gemini] section.
#
# Example:
#   shell::load_gemini_config
#   shell::load_gemini_config -n
#   shell::load_gemini_config "/path/to/custom/config.conf"
shell::load_gemini_config() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_LOAD_GEMINI_CONFIG"
        return 0
    fi

    # Check if the -n flag is provided for dry-run
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    local config_file="${1:-$SHELL_KEY_CONF_AGENT_GEMINI_FILE}"

    # Check if configuration file exists
    if [ ! -f "$config_file" ]; then
        shell::colored_echo "ERR: Gemini config file not found at '$config_file'" 196
        shell::colored_echo "INFO: Run shell::populate_gemini_conf to create default configuration" 33
        return 1
    fi

    # Check if dry-run is enabled
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "shell::expose_ini_env \"$config_file\" GEMINI gemini"
        return 0
    fi

    # Load configuration using existing shell function
    shell::expose_ini_env "$config_file" GEMINI gemini

    shell::colored_echo "INFO: Gemini configuration loaded from '$config_file'" 46
    return 0
}

# shell::save_gemini_config function
# Saves current environment variables to Gemini configuration file.
#
# Usage:
#   shell::save_gemini_config [-n] [-h] [config_file]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h : Optional help flag. If provided, displays usage information.
#   - [config_file] : Optional. Path to the configuration file. Defaults to SHELL_KEY_CONF_AGENT_GEMINI_FILE.
#
# Description:
#   This function saves Gemini configuration by reading GEMINI_* environment variables
#   and writing them to the configuration file under the [gemini] section.
#   It strips the GEMINI_ prefix when writing to the file.
#
# Example:
#   export GEMINI_API_KEY="your-api-key"
#   export GEMINI_MODEL="gemini-2.0-flash"
#   shell::save_gemini_config
#   shell::save_gemini_config -n
shell::save_gemini_config() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_SAVE_GEMINI_CONFIG"
        return 0
    fi

    # Check if the -n flag is provided for dry-run
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    local config_file="${1:-$SHELL_KEY_CONF_AGENT_GEMINI_FILE}"

    # Get all GEMINI_* environment variables
    local gemini_vars
    gemini_vars=$(env | grep "^GEMINI_" | cut -d= -f1)

    if [ -z "$gemini_vars" ]; then
        shell::colored_echo "WARN: No GEMINI_* environment variables found to save" 11
        return 1
    fi

    # Check if dry-run is enabled
    if [ "$dry_run" = "true" ]; then
        shell::colored_echo "Would save the following variables to '$config_file':" 33
        for var in $gemini_vars; do
            local key="${var#GEMINI_}"
            local value="${!var}"
            shell::on_evict "shell::write_ini \"$config_file\" \"gemini\" \"$key\" \"$value\""
        done
        return 0
    fi

    # Ensure the gemini section exists
    if ! shell::exist_ini_section "$config_file" "gemini" >/dev/null 2>&1; then
        shell::add_ini_section "$config_file" "gemini"
    fi

    # Save each GEMINI_* variable
    for var in $gemini_vars; do
        local key="${var#GEMINI_}"
        local value="${!var}"
        shell::write_ini "$config_file" "gemini" "$key" "$value"
        shell::colored_echo "INFO: Saved $key to configuration" 244
    done

    shell::colored_echo "INFO: Gemini configuration saved to '$config_file'" 46
    return 0
}

# shell::populate_gemini_stream_conf function
# Populates the Gemini streaming configuration file with additional streaming-specific keys.
#
# Usage:
#   shell::populate_gemini_stream_conf [-n] [-h] [config_file]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h : Optional help flag. If provided, displays usage information.
#   - [config_file] : Optional. Path to the configuration file. Defaults to SHELL_KEY_CONF_AGENT_GEMINI_FILE.
#
# Description:
#   This function extends the basic Gemini configuration with streaming-specific settings.
#   It adds conversation history settings, file upload limits, and streaming preferences
#   while preserving existing configuration values.
#
# Example:
#   shell::populate_gemini_stream_conf
#   shell::populate_gemini_stream_conf -n
shell::populate_gemini_stream_conf() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_POPULATE_GEMINI_STREAM_CONF"
        return 0
    fi

    # Check if the -n flag is provided for dry-run
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    local config_file="${1:-$SHELL_KEY_CONF_AGENT_GEMINI_FILE}"

    # First ensure basic gemini config exists
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "shell::populate_gemini_conf \"$config_file\""
    else
        shell::populate_gemini_conf "$config_file"
    fi

    # Define streaming-specific default keys
    declare -A streaming_keys=(
        ["STREAM_ENABLED"]="true"
        ["CONVERSATION_HISTORY_MAX"]="50"
        ["CONVERSATION_FILE"]="$SHELL_CONF_WORKING_AGENT/gemini_conversation.json"
        ["FILE_UPLOAD_MAX_SIZE"]="10485760"
        ["SUPPORTED_FILE_TYPES"]="jpg,jpeg,png,gif,pdf,txt,md,json,yaml,yml"
        ["GLOW_ENABLED"]="true"
        ["AUTO_SAVE_RESPONSES"]="false"
        ["RESPONSE_SAVE_DIR"]="$SHELL_CONF_WORKING_AGENT/responses"
    )

    # Check if dry-run is enabled
    if [ "$dry_run" = "true" ]; then
        for key in "${!streaming_keys[@]}"; do
            shell::on_evict "shell::write_ini \"$config_file\" \"gemini\" \"$key\" \"${streaming_keys[$key]}\""
        done
        return 0
    fi

    # Ensure the section exists
    if ! shell::exist_ini_section "$config_file" "gemini" >/dev/null 2>&1; then
        shell::add_ini_section "$config_file" "gemini"
    fi

    # Add streaming-specific keys if they don't exist
    for key in "${!streaming_keys[@]}"; do
        if ! shell::exist_ini_key "$config_file" "gemini" "$key" >/dev/null 2>&1; then
            shell::write_ini "$config_file" "gemini" "$key" "${streaming_keys[$key]}"
            shell::colored_echo "INFO: Added streaming setting: $key" 244
        fi
    done

    shell::colored_echo "INFO: Gemini streaming configuration populated at '$config_file'" 46
    return 0
}

# shell::clear_gemini_conversation function
# Clears the conversation history by removing the conversation file.
#
# Usage:
#   shell::clear_gemini_conversation [-n] [-h] [conversation_file]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h : Optional help flag. If provided, displays usage information.
#   - [conversation_file] : Optional. Path to the conversation file. Defaults to reading from config.
#
# Description:
#   This function clears the conversation history by removing the conversation file.
#   If no file is specified, it reads the CONVERSATION_FILE setting from the configuration.
#   In dry-run mode, it shows what file would be removed without actually doing it.
#
# Example:
#   shell::clear_gemini_conversation
#   shell::clear_gemini_conversation -n
#   shell::clear_gemini_conversation "/path/to/conversation.json"
shell::clear_gemini_conversation() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_CLEAR_GEMINI_CONVERSATION"
        return 0
    fi

    # Check if the -n flag is provided for dry-run
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    local conversation_file="$1"
    
    # If no conversation file specified, read from config
    if [ -z "$conversation_file" ]; then
        if [ -f "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" ]; then
            conversation_file=$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "CONVERSATION_FILE" 2>/dev/null)
        fi
        
        # Default fallback
        if [ -z "$conversation_file" ]; then
            conversation_file="$SHELL_CONF_WORKING_AGENT/gemini_conversation.json"
        fi
    fi

    # Check if dry-run is enabled
    if [ "$dry_run" = "true" ]; then
        if [ -f "$conversation_file" ]; then
            shell::on_evict "rm -f \"$conversation_file\""
        else
            shell::colored_echo "INFO: Conversation file does not exist: $conversation_file" 33
        fi
        return 0
    fi

    # Check if conversation file exists
    if [ ! -f "$conversation_file" ]; then
        shell::colored_echo "INFO: No conversation history to clear at: $conversation_file" 33
        return 0
    fi

    # Remove conversation file
    if rm -f "$conversation_file" 2>/dev/null; then
        shell::colored_echo "INFO: Conversation history cleared: $conversation_file" 46
        return 0
    else
        shell::colored_echo "ERR: Failed to clear conversation history: $conversation_file" 196
        return 1
    fi
}

# shell::add_to_gemini_conversation function
# Adds a message to the conversation history.
#
# Usage:
#   shell::add_to_gemini_conversation [-n] [-h] <role> <content> [conversation_file]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h : Optional help flag. If provided, displays usage information.
#   - <role> : Required. The role of the message sender (user, model, system).
#   - <content> : Required. The content of the message.
#   - [conversation_file] : Optional. Path to the conversation file. Defaults to reading from config.
#
# Description:
#   This function adds a message to the conversation history stored in JSON format.
#   The conversation file is created if it doesn't exist. Each message includes
#   a timestamp, role, and content. The function respects the maximum conversation
#   history limit from the configuration.
#
# Example:
#   shell::add_to_gemini_conversation "user" "Hello, how are you?"
#   shell::add_to_gemini_conversation -n "model" "I'm doing well, thank you!"
shell::add_to_gemini_conversation() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ADD_TO_GEMINI_CONVERSATION"
        return 0
    fi

    # Check if the -n flag is provided for dry-run
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check required parameters
    if [ $# -lt 2 ]; then
        shell::colored_echo "ERR: Role and content are required" 196
        echo "Usage: shell::add_to_gemini_conversation [-n] <role> <content> [conversation_file]"
        return 1
    fi

    local role="$1"
    local content="$2"
    local conversation_file="$3"

    # Validate role
    if [[ ! "$role" =~ ^(user|model|system)$ ]]; then
        shell::colored_echo "ERR: Invalid role '$role'. Must be 'user', 'model', or 'system'" 196
        return 1
    fi

    # If no conversation file specified, read from config
    if [ -z "$conversation_file" ]; then
        if [ -f "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" ]; then
            conversation_file=$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "CONVERSATION_FILE" 2>/dev/null)
        fi
        
        # Default fallback
        if [ -z "$conversation_file" ]; then
            conversation_file="$SHELL_CONF_WORKING_AGENT/gemini_conversation.json"
        fi
    fi

    # Get max conversation history from config
    local max_history
    if [ -f "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" ]; then
        max_history=$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "CONVERSATION_HISTORY_MAX" 2>/dev/null)
    fi
    max_history="${max_history:-50}"

    # Create timestamp
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Prepare the new message
    local new_message
    new_message=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "role": "$role",
  "content": $(echo "$content" | jq -R .)
}
EOF
)

    # Check if dry-run is enabled
    if [ "$dry_run" = "true" ]; then
        shell::colored_echo "Would add message to '$conversation_file':" 33
        shell::colored_echo "Role: $role" 244
        shell::colored_echo "Content: $content" 244
        shell::on_evict "echo '$new_message' >> conversation.json (with history limit: $max_history)"
        return 0
    fi

    # Ensure conversation file directory exists
    local conversation_dir
    conversation_dir=$(dirname "$conversation_file")
    if [ ! -d "$conversation_dir" ]; then
        mkdir -p "$conversation_dir" 2>/dev/null || {
            shell::colored_echo "ERR: Failed to create conversation directory: $conversation_dir" 196
            return 1
        }
    fi

    # Initialize conversation file if it doesn't exist
    if [ ! -f "$conversation_file" ]; then
        echo "[]" > "$conversation_file"
    fi

    # Read existing conversation
    local existing_conversation
    existing_conversation=$(cat "$conversation_file" 2>/dev/null)
    
    # Validate JSON format
    if ! echo "$existing_conversation" | jq . >/dev/null 2>&1; then
        shell::colored_echo "WARN: Invalid JSON in conversation file, reinitializing" 11
        echo "[]" > "$conversation_file"
        existing_conversation="[]"
    fi

    # Add new message
    local updated_conversation
    updated_conversation=$(echo "$existing_conversation" | jq --argjson msg "$new_message" '. + [$msg]')

    # Trim conversation to max_history if needed
    local conversation_count
    conversation_count=$(echo "$updated_conversation" | jq 'length')
    
    if [ "$conversation_count" -gt "$max_history" ]; then
        local trim_count=$((conversation_count - max_history))
        updated_conversation=$(echo "$updated_conversation" | jq ".[$trim_count:]")
        shell::colored_echo "INFO: Trimmed conversation history to $max_history messages" 244
    fi

    # Write updated conversation
    if echo "$updated_conversation" > "$conversation_file"; then
        shell::colored_echo "INFO: Added $role message to conversation: $conversation_file" 244
        return 0
    else
        shell::colored_echo "ERR: Failed to update conversation file: $conversation_file" 196
        return 1
    fi
}

# shell::load_gemini_conversation function
# Loads and displays the conversation history.
#
# Usage:
#   shell::load_gemini_conversation [-n] [-h] [conversation_file] [format]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h : Optional help flag. If provided, displays usage information.
#   - [conversation_file] : Optional. Path to the conversation file. Defaults to reading from config.
#   - [format] : Optional. Output format: 'json', 'pretty', or 'summary'. Defaults to 'pretty'.
#
# Description:
#   This function loads the conversation history from the specified file and displays it
#   in the requested format. The 'pretty' format shows a human-readable conversation,
#   'json' shows the raw JSON, and 'summary' shows basic statistics.
#
# Example:
#   shell::load_gemini_conversation
#   shell::load_gemini_conversation -n
#   shell::load_gemini_conversation "/path/to/conversation.json" "json"
shell::load_gemini_conversation() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_LOAD_GEMINI_CONVERSATION"
        return 0
    fi

    # Check if the -n flag is provided for dry-run
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    local conversation_file="$1"
    local format="${2:-pretty}"

    # If no conversation file specified, read from config
    if [ -z "$conversation_file" ]; then
        if [ -f "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" ]; then
            conversation_file=$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "CONVERSATION_FILE" 2>/dev/null)
        fi
        
        # Default fallback
        if [ -z "$conversation_file" ]; then
            conversation_file="$SHELL_CONF_WORKING_AGENT/gemini_conversation.json"
        fi
    fi

    # Validate format
    if [[ ! "$format" =~ ^(json|pretty|summary)$ ]]; then
        shell::colored_echo "ERR: Invalid format '$format'. Must be 'json', 'pretty', or 'summary'" 196
        return 1
    fi

    # Check if dry-run is enabled
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "cat \"$conversation_file\" | jq . (format: $format)"
        return 0
    fi

    # Check if conversation file exists
    if [ ! -f "$conversation_file" ]; then
        shell::colored_echo "INFO: No conversation history found at: $conversation_file" 33
        return 0
    fi

    # Read and validate conversation
    local conversation_content
    conversation_content=$(cat "$conversation_file" 2>/dev/null)
    
    if ! echo "$conversation_content" | jq . >/dev/null 2>&1; then
        shell::colored_echo "ERR: Invalid JSON in conversation file: $conversation_file" 196
        return 1
    fi

    # Display based on format
    case "$format" in
        "json")
            echo "$conversation_content" | jq .
            ;;
        "summary")
            local message_count
            message_count=$(echo "$conversation_content" | jq 'length')
            local user_count
            user_count=$(echo "$conversation_content" | jq '[.[] | select(.role == "user")] | length')
            local model_count
            model_count=$(echo "$conversation_content" | jq '[.[] | select(.role == "model")] | length')
            local system_count
            system_count=$(echo "$conversation_content" | jq '[.[] | select(.role == "system")] | length')
            
            shell::colored_echo "Conversation Summary" 51
            shell::colored_echo "===================" 51
            shell::colored_echo "Total messages: $message_count" 244
            shell::colored_echo "User messages: $user_count" 244
            shell::colored_echo "Model messages: $model_count" 244
            shell::colored_echo "System messages: $system_count" 244
            shell::colored_echo "File: $conversation_file" 244
            ;;
        "pretty"|*)
            shell::colored_echo "Conversation History" 51
            shell::colored_echo "===================" 51
            
            # Process each message
            echo "$conversation_content" | jq -r '.[] | @json' | while read -r message; do
                local timestamp
                timestamp=$(echo "$message" | jq -r '.timestamp')
                local role
                role=$(echo "$message" | jq -r '.role')
                local content
                content=$(echo "$message" | jq -r '.content')
                
                # Color-code based on role
                case "$role" in
                    "user")
                        shell::colored_echo "[$timestamp] User:" 33
                        shell::colored_echo "$content" 255
                        ;;
                    "model")
                        shell::colored_echo "[$timestamp] Model:" 46
                        shell::colored_echo "$content" 255
                        ;;
                    "system")
                        shell::colored_echo "[$timestamp] System:" 244
                        shell::colored_echo "$content" 255
                        ;;
                esac
                echo ""
            done
            ;;
    esac

    return 0
}