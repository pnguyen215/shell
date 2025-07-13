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