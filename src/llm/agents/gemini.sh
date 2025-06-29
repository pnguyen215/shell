#!/bin/bash
# gemini.sh

# shell::populate_gemini_conf function
# Populates the Gemini agent configuration file with default keys if they do not already exist.
#
# Usage:
# shell::populate_gemini_conf [file_path]
#
# Parameters:
# - [file_path] : Optional. The path to the Gemini configuration file. Defaults to SHELL_KEY_CONF_AGENT_GEMINI_FILE.
#
# Description:
# This function writes default Gemini configuration keys to the specified file under the [gemini] section.
# It checks if each key already exists before writing. Values are encoded using Base64 and written using shell::write_ini.
#
# Example:
# shell::populate_gemini_conf
# shell::populate_gemini_conf "$HOME/.config/gemini.conf"
shell::populate_gemini_conf() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_POPULATE_GEMINI_CONF"
        return 0
    fi

    local file="${1:-$SHELL_KEY_CONF_AGENT_GEMINI_FILE}"
    local section="gemini"

    # Ensure the section exists in the INI file
    # This function uses shell::exist_ini_section to check if the section exists
    # If it does not exist, it adds the section using shell::add_ini_section
    if ! shell::exist_ini_section "$file" "$section" >/dev/null 2>&1; then
        shell::add_ini_section "$file" "$section"
    fi

    # Define default keys and their values
    # This associative array contains the default keys and their values for the Gemini configuration
    # Each key is a string, and the value is also a string
    declare -A default_keys=(
        ["MODEL"]="gemini-2.0-flash"
        ["API_KEY"]="api-key-value"
        ["MAX_TOKENS"]="4096"
        ["TEMPERATURE"]="0.7"
        ["TOP_P"]="0.9"
        ["TOP_K"]="40"
        ["FREQUENCY_PENALTY"]="0.0"
        ["PRESENCE_PENALTY"]="0.0"
    )

    # Check and write each key if it does not exist
    # If a key does not exist, it writes the default value using shell::write_ini
    if ! shell::exist_ini_key "$file" "$section" "MODEL" >/dev/null 2>&1; then
        shell::write_ini "$file" "$section" "MODEL" "${default_keys[MODEL]}"
    fi
    if ! shell::exist_ini_key "$file" "$section" "API_KEY" >/dev/null 2>&1; then
        shell::write_ini "$file" "$section" "API_KEY" "${default_keys[API_KEY]}"
    fi
    if ! shell::exist_ini_key "$file" "$section" "MAX_TOKENS" >/dev/null 2>&1; then
        shell::write_ini "$file" "$section" "MAX_TOKENS" "${default_keys[MAX_TOKENS]}"
    fi
    if ! shell::exist_ini_key "$file" "$section" "TEMPERATURE" >/dev/null 2>&1; then
        shell::write_ini "$file" "$section" "TEMPERATURE" "${default_keys[TEMPERATURE]}"
    fi
    if ! shell::exist_ini_key "$file" "$section" "TOP_P" >/dev/null 2>&1; then
        shell::write_ini "$file" "$section" "TOP_P" "${default_keys[TOP_P]}"
    fi
    if ! shell::exist_ini_key "$file" "$section" "TOP_K" >/dev/null 2>&1; then
        shell::write_ini "$file" "$section" "TOP_K" "${default_keys[TOP_K]}"
    fi
    if ! shell::exist_ini_key "$file" "$section" "FREQUENCY_PENALTY" >/dev/null 2>&1; then
        shell::write_ini "$file" "$section" "FREQUENCY_PENALTY" "${default_keys[FREQUENCY_PENALTY]}"
    fi
    if ! shell::exist_ini_key "$file" "$section" "PRESENCE_PENALTY" >/dev/null 2>&1; then
        shell::write_ini "$file" "$section" "PRESENCE_PENALTY" "${default_keys[PRESENCE_PENALTY]}"
    fi

    shell::colored_echo "INFO: Gemini configuration populated at '$file'" 46
}

# shell::fzf_view_gemini_conf function
# Interactively views the Gemini configuration file using fzf.
#
# Usage:
# shell::fzf_view_gemini_conf
#
# Description:
# This function opens the Gemini configuration file defined by SHELL_KEY_CONF_AGENT_GEMINI_FILE.
# It uses fzf to preview all key-value pairs in the [gemini] section.
shell::fzf_view_gemini_conf() {
    local file="$SHELL_KEY_CONF_AGENT_GEMINI_FILE"
    if [ ! -f "$file" ]; then
        shell::colored_echo "ERR: Gemini config file not found at '$file'" 196
        return 1
    fi
    shell::fzf_view_ini_viz "$file"
}

# shell::fzf_edit_gemini_conf function
# Interactively edits the Gemini configuration file using fzf.
#
# Usage:
# shell::fzf_edit_gemini_conf
#
# Description:
# This function opens the Gemini configuration file defined by SHELL_KEY_CONF_AGENT_GEMINI_FILE.
# It uses fzf to select a key from the [gemini] section and allows editing its value.
shell::fzf_edit_gemini_conf() {
    local file="$SHELL_KEY_CONF_AGENT_GEMINI_FILE"
    if [ ! -f "$file" ]; then
        shell::colored_echo "ERR: Gemini config file not found at '$file'" 196
        return 1
    fi
    shell::fzf_edit_ini_viz "$file"
}

# shell::dump_gemini_conf_json function
# Dumps all sections from the Gemini config file as JSON.
#
# Usage:
# shell::dump_gemini_conf_json
#
# Description:
# This function calls shell::dump_ini_json using SHELL_KEY_CONF_AGENT_GEMINI_FILE.
shell::dump_gemini_conf_json() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_DUMP_GEMINI_CONF_JSON"
        return 0
    fi
    shell::dump_ini_json "$SHELL_KEY_CONF_AGENT_GEMINI_FILE"
}

# shell::gemini_learn_english function
# Sends an English sentence to Gemini for grammar evaluation and interactively displays corrections and examples.
#
# Usage:
# shell::gemini_learn_english [-n]
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the curl command is printed using shell::on_evict instead of executed.
#
# Description:
# This function reads a prompt from ~/.shell-config/agents/gemini/prompts/english_translation_tutor.txt,
# sends it to the Gemini API using curl, and uses jq and fzf to interactively select and display
# the suggested correction and example sentences (formatted as "en (vi)").
shell::gemini_learn_english() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GEMINI_LEARN_ENGLISH"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if the required parameters are provided
    if [ -z "$1" ]; then
        echo "Usage: shell::gemini_learn_english [-n] <sentence english>"
        return 1
    fi
    # Ensure the sentence_english variable is set
    local sentence_english="$1"

    # Check if the Gemini configuration file exists
    if [ ! -f "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" ]; then
        shell::colored_echo "ERR: Gemini config file not found at '$SHELL_KEY_CONF_AGENT_GEMINI_FILE'" 196
        return 1
    fi

    # Read the API_KEY and MODEL from the Gemini config file
    local api_key=$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "API_KEY")
    local model=$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "MODEL")

    # Check if API_KEY is set in the Gemini config file
    # If API_KEY is not set, it defaults to an empty string
    if [ -z "$api_key" ]; then
        shell::colored_echo "ERR: API_KEY config not found in Gemini config file ($SHELL_KEY_CONF_AGENT_GEMINI_FILE)." 196
        return 1
    fi

    # Check if MODEL is set in the Gemini config file
    # If MODEL is not set, it defaults to "gemini-2.0-flash"
    if [ -z "$model" ]; then
        shell::colored_echo "ERR: MODEL config not found in Gemini config file ($SHELL_KEY_CONF_AGENT_GEMINI_FILE)." 196
        return 1
    fi

    local url="https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${api_key}"
    local prompt_request="$LLM_PROMPTS_DIR/gemini/english_translation_tutor_request.txt"

    # Check if the prompt file exists
    if [ ! -f "$prompt_request" ]; then
        shell::colored_echo "ERR: Prompt file not found at '$prompt_request'" 196
        return 1
    fi

    # Replace the placeholder in the prompt file with the provided sentence
    # The sed command replaces {ENTER_SENTENCE_ENGLISH} in the prompt file with the actual sentence_english
    # This allows the prompt to be dynamically generated based on user input
    local payload=$(sed "s/{ENTER_SENTENCE_ENGLISH}/$sentence_english/" "$prompt_request")

    # Check if the dry-run is enabled
    # If dry_run is true, it will print the curl command instead of executing it
    # This is useful for debugging or testing purposes
    if [ "$dry_run" = "true" ]; then
        # Prepare the curl command to send the request to the Gemini API
        # The curl command is constructed to send a POST request with the payload
        # The payload is a JSON object containing the model, prompt, and other parameters
        local curl_cmd="curl -s -X POST \"$url\" -H \"Content-Type: application/json\" -d '$payload'"
        shell::on_evict "$curl_cmd"
        return 0
    fi

    # local tmp_payload_file
    # tmp_payload_file=$(mktemp)
    # echo "$payload" >"$tmp_payload_file"

    # Send request and capture raw response
    local response
    response=$(curl -s -X POST "$url" -H "Content-Type: application/json" -d "$payload")
    # response=$(curl -s -X POST "$url" -H "Content-Type: application/json" --data @"$tmp_payload_file")
    # rm -f "$tmp_payload_file"

    # Check if the response is empty
    # If the response is empty, it indicates that there was no response from the Gemini API
    if [ $? -ne 0 ]; then
        shell::colored_echo "ERR: Failed to connect to Gemini API." 196
        return 1
    fi

    # Check if the response is empty
    # If the response is empty, it indicates that there was no response from the Gemini API
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

    # shell::colored_echo "DEBUG: Response from Gemini API: $response" 244

    # Sanitize the JSON string by removing problematic characters and re-formatting
    local sanitized_json
    sanitized_json=$(echo "$response" | tr -d '\n\r\t' | sed 's/  */ /g')

    shell::colored_echo "DEBUG: Sanitized JSON: $sanitized_json" 244

    # Try to parse the sanitized JSON
    local parsed_json
    parsed_json=$(echo "$sanitized_json" | jq '.' 2>/dev/null)

    # shell::colored_echo "DEBUG: Parsed JSON: $parsed_json" 244

    # Check if the parsed JSON is valid
    if [ $? -ne 0 ]; then
        shell::colored_echo "ERR: Failed to parse JSON response." 196
        return 1
    fi

    # Extract the text field (this contains the embedded JSON string)
    local text_json_raw
    text_json_raw=$(echo "$parsed_json" | jq -r '.candidates[0].content.parts[0].text')

    shell::colored_echo "DEBUG: Raw text JSON content: $text_json_raw" 244

    # Sanitize the embedded JSON text to handle escaped quotes and other characters
    # Method 1: Use printf to properly handle escaped characters
    local text_json_clean
    text_json_clean=$(printf '%b' "$text_json_raw")

    # Method 2: Alternative approach using sed to clean escaped characters
    # Uncomment this if Method 1 doesn't work:
    text_json_clean=$(echo "$text_json_raw" | sed 's/\\"/"/g' | sed 's/\\n/\n/g' | sed 's/\\t/\t/g' | sed 's/\\r/\r/g')

    shell::colored_echo "DEBUG: Cleaned text JSON content: $text_json_clean" 244

    # Parse the cleaned embedded JSON
    local parsed_embedded_json
    parsed_embedded_json=$(echo "$text_json_clean" | jq '.' 2>/dev/null)

    if [ $? -ne 0 ]; then
        shell::colored_echo "ERR: Failed to parse embedded JSON after sanitization." 196
        shell::colored_echo "DEBUG: Problematic JSON content:" 244
        echo "$text_json_clean"
        return 1
    fi

    # Use the new dump function for clean visualization
    shell::dump_gemini_conf_json "$parsed_embedded_json"
}

# New function for clean JSON visualization with real-time view board
shell::dump_gemini_conf_json() {
    local json_data="$1"

    # Handle array input - take first element if array
    local is_array
    is_array=$(echo "$json_data" | jq -r 'type == "array"')

    if [ "$is_array" = "true" ]; then
        json_data=$(echo "$json_data" | jq '.[0]')
    fi

    # Get all keys from the JSON object
    local keys
    keys=$(echo "$json_data" | jq -r 'keys[]' 2>/dev/null)

    if [ -z "$keys" ]; then
        echo "No data to display"
        return 1
    fi

    # Create clean menu without icons or background colors
    local menu_items=""
    while IFS= read -r key; do
        local value_type
        value_type=$(echo "$json_data" | jq -r --arg k "$key" '.[$k] | type')

        case "$value_type" in
        "array")
            local array_length
            array_length=$(echo "$json_data" | jq --arg k "$key" '.[$k] | length')
            menu_items="${menu_items}${key} [${array_length} items]\n"
            ;;
        "object")
            menu_items="${menu_items}${key} [object]\n"
            ;;
        *)
            local preview_value
            preview_value=$(echo "$json_data" | jq -r --arg k "$key" '.[$k]' | head -c 40)
            if [ ${#preview_value} -gt 40 ]; then
                preview_value="${preview_value}..."
            fi
            menu_items="${menu_items}${key}: ${preview_value}\n"
            ;;
        esac
    done <<<"$keys"

    # Interactive selection with clean fzf layout
    local selected_field
    selected_field=$(printf "%b" "$menu_items" | fzf \
        --height=70% \
        --layout=reverse \
        --border=rounded \
        --prompt="Select field > " \
        --header="English Learning Data Viewer" \
        --preview-window=right:60%:wrap \
        --preview="shell::_preview_json_field '$json_data' {}" \
        --bind='ctrl-c:abort' \
        --no-info)

    if [ -n "$selected_field" ]; then
        # Extract just the key name (remove preview text and array indicators)
        local selected_key
        selected_key=$(echo "$selected_field" | sed 's/:.*$//' | sed 's/ \[.*\]$//')
        shell::_display_json_field_detailed "$json_data" "$selected_key"
    fi
}

# Preview function for real-time field viewing
shell::_preview_json_field() {
    local json_data="$1"
    local field_line="$2"

    # Extract key name from the field line
    local key
    key=$(echo "$field_line" | sed 's/:.*$//' | sed 's/ \[.*\]$//')

    # Check if key exists
    if ! echo "$json_data" | jq -e --arg k "$key" 'has($k)' >/dev/null 2>&1; then
        echo "Field not found: $key"
        return 1
    fi

    local value_type
    value_type=$(echo "$json_data" | jq -r --arg k "$key" '.[$k] | type')

    case "$value_type" in
    "array")
        echo "ARRAY CONTENTS:"
        echo "==============="
        local array_items
        array_items=$(echo "$json_data" | jq -r --arg k "$key" '.[$k][]')
        if [ -n "$array_items" ]; then
            echo "$array_items" | nl -w2 -s'. ' | head -10
            local total_count
            total_count=$(echo "$json_data" | jq --arg k "$key" '.[$k] | length')
            if [ "$total_count" -gt 10 ]; then
                echo "... and $((total_count - 10)) more items"
            fi
        else
            echo "Empty array"
        fi
        ;;
    "object")
        echo "OBJECT STRUCTURE:"
        echo "=================="
        echo "$json_data" | jq --arg k "$key" '.[$k]' | jq -r 'to_entries | map("\(.key): \(.value)") | .[]'
        ;;
    "string")
        echo "TEXT CONTENT:"
        echo "============="
        echo "$json_data" | jq -r --arg k "$key" '.[$k]' | fold -w 50
        ;;
    *)
        echo "VALUE:"
        echo "======"
        echo "$json_data" | jq -r --arg k "$key" '.[$k]'
        ;;
    esac
}

# Detailed display function with array handling
shell::_display_json_field_detailed() {
    local json_data="$1"
    local key="$2"

    clear

    # Display header
    local header_text
    header_text=$(echo "$key" | tr '_' ' ' | tr '[:lower:]' '[:upper:]')
    echo "$header_text"
    printf '%*s\n' "${#header_text}" '' | tr ' ' '='
    echo

    local value_type
    value_type=$(echo "$json_data" | jq -r --arg k "$key" '.[$k] | type')

    case "$value_type" in
    "array")
        # Handle arrays with fzf selection
        local array_data
        array_data=$(echo "$json_data" | jq -r --arg k "$key" '.[$k][]')

        if [ -n "$array_data" ]; then
            echo "Select an item from the array:"
            echo
            local selected_item
            selected_item=$(echo "$array_data" | fzf \
                --height=50% \
                --layout=reverse \
                --border=rounded \
                --prompt="Select item > " \
                --header="Array items for: $key" \
                --preview='echo {} | fold -w 70' \
                --bind='ctrl-c:abort')

            if [ -n "$selected_item" ]; then
                echo
                echo "SELECTED ITEM:"
                echo "=============="
                echo "$selected_item" | fold -w 80
            fi
        else
            echo "Empty array"
        fi
        ;;
    "object")
        echo "$json_data" | jq --arg k "$key" '.[$k]' | jq -r 'to_entries | map("\(.key): \(.value)") | .[]'
        ;;
    *)
        echo "$json_data" | jq -r --arg k "$key" '.[$k]' | fold -w 80
        ;;
    esac

    echo
    echo "Press any key to continue..."
    read -n 1 -s
}

# Alternative compact view function for quick overview
shell::dump_gemini_compact() {
    local json_data="$1"

    # Handle array input
    local is_array
    is_array=$(echo "$json_data" | jq -r 'type == "array"')

    if [ "$is_array" = "true" ]; then
        json_data=$(echo "$json_data" | jq '.[0]')
    fi

    echo "ENGLISH LEARNING ANALYSIS"
    echo "========================="
    echo

    # Key-value pairs in clean format
    local keys
    keys=$(echo "$json_data" | jq -r 'keys[]')

    while IFS= read -r key; do
        local value_type
        value_type=$(echo "$json_data" | jq -r --arg k "$key" '.[$k] | type')

        local formatted_key
        formatted_key=$(echo "$key" | tr '_' ' ' | sed 's/\b\w/\U&/g')
        printf "%-25s: " "$formatted_key"

        case "$value_type" in
        "array")
            local count
            count=$(echo "$json_data" | jq --arg k "$key" '.[$k] | length')
            echo "[$count items - use detailed view]"
            ;;
        "boolean" | "number")
            echo "$json_data" | jq -r --arg k "$key" '.[$k]'
            ;;
        *)
            local value
            value=$(echo "$json_data" | jq -r --arg k "$key" '.[$k]' | head -c 50)
            if [ ${#value} -gt 50 ]; then
                echo "${value}..."
            else
                echo "$value"
            fi
            ;;
        esac
    done <<<"$keys"

    echo
    echo "Use 'shell::dump_gemini_conf_json' for interactive detailed view"
}
