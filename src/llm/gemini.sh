#!/bin/bash
# gemini.sh

# shell::gemini function
# Calls the Gemini API via REST using cURL to generate streaming text responses.
#
# Usage:
#   shell::gemini [-n] <profile_name> <prompt>
#
# Parameters:
#   - -n             : Optional dry-run flag. If provided, the cURL command is printed using shell::on_evict instead of executed.
#   - <profile_name> : The name of the profile containing the Gemini API key (stored as GEMINI_API_KEY).
#   - <prompt>       : The text prompt to send to the Gemini API.
#
# Description:
#   This function retrieves the Gemini API key from the specified profile's configuration
#   using shell::get_profile_conf_value. It constructs a JSON payload with the provided prompt
#   and sends a streaming POST request to the Gemini API using cURL with --no-buffer for real-time output.
#   A loading animation is displayed while waiting for the response. The function extracts the generated
#   text from the streaming JSON response using jq (if available) or grep/sed as a fallback.
#   The response is printed as it arrives, and errors are reported with colored output.
#
# Example usage:
#   shell::gemini my_profile "Write a poem about the stars"  # Sends prompt to Gemini API and streams response.
#   shell::gemini -n my_profile "Summarize a news article"   # Dry-run: prints the cURL command without executing.
#
# Dependencies:
#   - curl: Required for making HTTP requests.
#   - jq (optional): For robust JSON parsing; falls back to grep/sed if unavailable.
#
# Notes:
#   - Requires internet access and a valid Gemini API key stored in the profile configuration.
#   - The API key is retrieved from the profile using the key name 'GEMINI_API_KEY'.
#   - Works on both macOS and Linux, leveraging shell::get_os_type for compatibility.
#   - Uses shell::colored_echo for output, shell::run_cmd for command execution, and shell::install_package for dependency management.
#   - The loading animation runs in the background and is terminated once the response is complete.
shell::gemini() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Validate arguments
    if [ $# -lt 2 ]; then
        shell::colored_echo "ERR: Usage: shell::gemini [-n] <profile_name> <prompt>" 196
        return 1
    fi

    local profile_name="$1"
    local prompt="$2"

    # Retrieve the Gemini API key from the profile
    local api_key
    # api_key=$(shell::get_profile_conf_value "$profile_name" "GEMINI_API_KEY" 2>/dev/null)
    api_key=""
    if [ $? -ne 0 ] || [ -z "$api_key" ]; then
        shell::colored_echo "ERR: Could not retrieve GEMINI_API_KEY from profile '$profile_name'." 196
        return 1
    fi

    # Define the Gemini API endpoint
    local api_url="https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:streamGenerateContent?alt=sse&key=$api_key"

    # Construct the JSON payload
    local json_payload='{
        "contents": [
            {
                "parts": [
                    {
                        "text": "'"$prompt"'"
                    }
                ]
            }
        ]
    }'

    # Build the cURL command for streaming
    local curl_cmd="curl --silent --no-buffer -X POST -H 'Content-Type: application/json' -d '$json_payload' '$api_url'"

    # Function to display a loading animation
    local spinner_pid
    show_loading() {
        spinner_chars=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷")
        while true; do
            for char in "${spinner_chars[@]}"; do
                printf "\r⏳ Generating... %s " "$char" >&2
                sleep 0.1
            done
        done
    }

    # Execute or print the command based on dry-run mode
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$curl_cmd"
        return 0
    fi

    # Start the loading animation in the background
    show_loading &
    spinner_pid=$!

    # Execute the cURL command and process the streaming SSE response
    local response=""
    local temp_file
    temp_file=$(mktemp)

    # Run cURL and process SSE stream
    shell::run_cmd_eval "$curl_cmd" >"$temp_file" 2>/dev/null
    if [ $? -ne 0 ]; then
        kill $spinner_pid >/dev/null 2>&1
        wait $spinner_pid >/dev/null 2>&1
        printf "\r\033[K" >&2
        shell::colored_echo "ERR: Failed to connect to Gemini API." 196
        rm -f "$temp_file"
        return 1
    fi

    # Process the SSE stream
    if shell::is_command_available jq; then
        # Use jq to parse each JSON chunk
        while IFS= read -r line; do
            # Skip empty lines or non-data lines
            if [[ "$line" =~ ^data:\ (.*)$ ]]; then
                json_chunk="${BASH_REMATCH[1]}"
                # Skip if json_chunk is empty or not valid JSON
                if [ -n "$json_chunk" ] && echo "$json_chunk" | jq . >/dev/null 2>&1; then
                    text=$(echo "$json_chunk" | jq -r '.candidates[0].content.parts[0].text // empty')
                    if [ -n "$text" ]; then
                        response+="$text"
                    fi
                fi
            fi
        done <"$temp_file"
    else
        # Fallback to grep/sed for JSON parsing
        while IFS= read -r line; do
            if [[ "$line" =~ ^data:\ (.*)$ ]]; then
                json_chunk="${BASH_REMATCH[1]}"
                if [ -n "$json_chunk" ]; then
                    text=$(echo "$json_chunk" | grep '"text":' | sed -E 's/.*"text":"([^"]+)"[,}].*/\1/' | tr -d '\n')
                    if [ -n "$text" ]; then
                        response+="$text"
                    fi
                fi
            fi
        done <"$temp_file"
    fi

    # Clean up
    rm -f "$temp_file"

    # Stop the loading animation
    kill $spinner_pid >/dev/null 2>&1
    wait $spinner_pid >/dev/null 2>&1
    printf "\r\033[K" >&2 # Clear the last spinner line

    # Check if the response is empty
    if [ -z "$response" ]; then
        shell::colored_echo "ERR: No valid text response received from Gemini API." 196
        return 1
    fi

    # Output the response
    shell::colored_echo "INFO: Response:" 46
    echo "$response"
    return 0
}
