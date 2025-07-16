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

# shell::make_gemini_request function
# Sends a request to the Gemini API with the provided payload.
#
# Usage:
# shell::make_gemini_request [-n] [-d] [-h] <request_payload>
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the curl command is printed using shell::on_evict instead of executed.
# - -d : Optional debugging flag. If provided, debug information is printed.
# - -h : Optional help flag. If provided, displays usage information.
# - <request_payload> : The JSON payload to send to the Gemini API.
#
# Description:
# This function reads the Gemini configuration file, constructs a request to the Gemini API,
# and sends the provided payload. It handles errors, sanitizes the response, and returns the parsed JSON.
# It also supports debugging and dry-run modes.
shell::make_gemini_request() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_MAKE_GEMINI_REQUEST"
        return 0
    fi

    # Check if the -n flag is provided for dry-run
    # If -n is provided, it sets the dry_run variable to true
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if the -d flag is provided for debugging
    # If -d is provided, it sets the debugging variable to true
    local debugging="false"
    if [ "$1" = "-d" ]; then
        debugging="true"
        shift
    fi

    # Check if the required parameters are provided
    if [ -z "$1" ]; then
        echo "Usage: shell::make_gemini_request [-n] <request_payload>"
        return 1
    fi

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
    local payload="$1"

    # Check if the prompt file exists
    if [ -z "$payload" ]; then
        shell::colored_echo "ERR: Prompt request is required" 196
        return 1
    fi

    # Check if the dry-run is enabled
    # If dry_run is true, it will print the curl command instead of executing it
    # This is useful for debugging or testing purposes
    if [ "$dry_run" = "true" ]; then
        # Prepare the curl command to send the request to the Gemini API
        # The curl command is constructed to send a POST request with the payload
        # The payload is a JSON object containing the model, prompt, and other parameters
        local sanitized_payload
        sanitized_payload=$(echo "$payload" | tr -d '\n\r\t' | sed 's/  */ /g')
        local curl_cmd="curl -s -X POST \"$url\" -H \"Content-Type: application/json\" -d '$sanitized_payload'"
        shell::on_evict "$curl_cmd"
        return 0
    fi

    # Send request and capture raw response
    local response
    response=$(curl -s -X POST "$url" -H "Content-Type: application/json" -d "$payload")

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

    if [ "$debugging" = "true" ]; then
        shell::colored_echo "DEBUG: Response from Gemini API: $response" 244
    fi

    # Sanitize the JSON string by removing problematic characters and re-formatting
    local sanitized_json
    sanitized_json=$(echo "$response" | tr -d '\n\r\t' | sed 's/  */ /g')
    # Remove markdown code block markers if present
    # This step ensures that any JSON response wrapped in code blocks is cleaned up
    sanitized_json=$(echo "$sanitized_json" | sed -e 's/^```json//' -e 's/```$//' -e 's/^```//' -e 's/```$//')
    # Remove leading/trailing whitespace
    # This step ensures that any leading or trailing whitespace is removed from the JSON string
    sanitized_json=$(echo "$sanitized_json" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    # Remove excessive whitespace but preserve JSON structure
    # This step ensures that any excessive whitespace within the JSON structure is reduced to a single space
    # This is important for maintaining the integrity of the JSON while making it more readable
    sanitized_json=$(echo "$sanitized_json" | sed -e 's/[[:space:]]\+/ /g')

    if [ "$debugging" = "true" ]; then
        shell::colored_echo "DEBUG: Sanitized JSON by Gemini response: $sanitized_json" 244
    fi

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

    if [ "$debugging" = "true" ]; then
        shell::colored_echo "DEBUG: Raw text JSON content by Gemini response: $text_json_raw" 244
    fi

    # Sanitize the embedded JSON text to handle escaped quotes and other characters
    # Method 1: Use printf to properly handle escaped characters
    local text_json_clean
    text_json_clean=$(printf '%b' "$text_json_raw")

    # Method 2: Alternative approach using sed to clean escaped characters
    # Uncomment this if Method 1 doesn't work:
    text_json_clean=$(echo "$text_json_raw" | sed 's/\\"/"/g' | sed 's/\\n/\n/g' | sed 's/\\t/\t/g' | sed 's/\\r/\r/g')

    if [ "$debugging" = "true" ]; then
        shell::colored_echo "DEBUG: Cleaned text JSON content by Gemini response: $text_json_clean" 244
    fi

    # Parse the cleaned embedded JSON
    local parsed_embedded_json
    parsed_embedded_json=$(echo "$text_json_clean" | jq '.' 2>/dev/null)

    if [ $? -ne 0 ]; then
        shell::colored_echo "ERR: Failed to parse embedded JSON after sanitization by Gemini response." 196
        shell::colored_echo "DEBUG: Problematic JSON content by Gemini response:" 244
        echo "$text_json_clean"
        shell::clip_value "$text_json_clean"
        return 1
    fi

    echo "$parsed_embedded_json"
    return 0
}

# shell::eval_gemini_en_vi function
# Sends an English sentence to Gemini for grammar evaluation and interactively displays corrections and examples.
#
# Usage:
# shell::eval_gemini_en_vi [-n] [-d] [-h] <sentence_english>
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the curl command is printed using shell::on_evict instead of executed.
# - -d : Optional debugging flag. If provided, debug information is printed.
# - -h : Optional help flag. If provided, displays usage information.
#
# Description:
# This function reads a prompt from ~/.shell-config/agents/gemini/prompts/english_translation_tutor.txt,
# sends it to the Gemini API using curl, and uses jq and fzf to interactively select and display
# the suggested correction and example sentences (formatted as "en (vi)").
shell::eval_gemini_en_vi() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_EVAL_GEMINI_EN_VI"
        return 0
    fi

    # Check if the -n flag is provided for dry-run
    # If -n is provided, it sets the dry_run variable to true
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if the -d flag is provided for debugging
    # If -d is provided, it sets the debugging variable to true
    local debugging="false"
    if [ "$1" = "-d" ]; then
        debugging="true"
        shift
    fi

    # Check if the required parameters are provided
    if [ -z "$1" ]; then
        echo "Usage: shell::eval_gemini_en_vi [-n] <sentence english>"
        return 1
    fi

    # Ensure the sentence_english variable is set
    local sentence_english="$1"
    local prompt_file="$LLM_PROMPTS_DIR/gemini/en_eval_vi_prompt_request_v1.txt"

    # Check if the prompt file exists
    if [ ! -f "$prompt_file" ]; then
        shell::colored_echo "ERR: Prompt file not found at '$prompt_file'" 196
        return 1
    fi

    # Replace the placeholder in the prompt file with the provided sentence
    # The sed command replaces {ENTER_SENTENCE_ENGLISH} in the prompt file with the actual sentence_english
    # This allows the prompt to be dynamically generated based on user input
    local payload=$(sed "s/{ENTER_SENTENCE_ENGLISH}/$sentence_english/" "$prompt_file")

    # Check if the dry-run is enabled
    # If dry_run is true, it will print the curl command instead of executing it
    # This is useful for debugging or testing purposes
    if [ "$dry_run" = "true" ]; then
        shell::make_gemini_request -n "$payload"
    else
        local response
        if [ "$debugging" = "true" ]; then
            response=$(shell::make_gemini_request -d "$payload")
        else
            response=$(shell::make_gemini_request "$payload")
        fi

        # Check if the response is empty or if the command failed
        if [ $? -ne 0 ] || [ -z "$response" ]; then
            shell::colored_echo "ERR: Failed to get response from Gemini (sgemcheck): $response." 196
            return 1
        fi

        #  Check if the debugging flag is set
        # If debugging is enabled, it prints the response from Gemini
        # This is useful for debugging purposes to see the raw response from the API
        if [ "$debugging" = "true" ]; then
            shell::colored_echo "$response" 244
            return 0
        fi

        # Extract the first item from the JSON array (assuming the structure from the example)
        # Get the first object as compact JSON
        local item_json=$(echo "$response" | jq -c '.[0]')
        if [ -z "$item_json" ] || [ "$item_json" = "null" ]; then
            shell::colored_echo "ERR: No valid data found in Gemini response: $response." 196
            return 1
        fi

        local os_type=$(shell::get_os_type)
        local suggested_correction=$(echo "$item_json" | jq -r '.suggested_correction // empty')
        local vietnamese_translation=$(echo "$item_json" | jq -r '.vietnamese_translation // empty')
        local native_usage_probability=$(echo "$item_json" | jq -r '.native_usage_probability // empty')
        local natural_alternatives_count=$(echo "$item_json" | jq '.natural_alternatives | length // 0')
        local example_sentences_count=$(echo "$item_json" | jq '.example_sentences | length // 0')

        # Format the native usage probability
        # If native_usage_probability is empty or null, it sets the formatted value to "N/A"
        # If it is a valid number, it formats it as a percentage
        # If the percentage is greater than 75, it adds an arrow pointing up (↑)
        # If the percentage is less than 75, it adds an arrow pointing down (↓)
        # Format the native usage probability
        # If native_usage_probability is empty or null, it sets the formatted value to "N/A"
        # If it is a valid number, it formats it as a percentage
        # If the percentage is greater than 75, it adds an arrow pointing up (↑)
        # If the percentage is less than or equal to 75, it adds an arrow pointing down (↓)
        local native_usage_probability_formatted
        if [ -z "$native_usage_probability" ] || [ "$native_usage_probability" = "null" ]; then
            native_usage_probability_formatted="N/A"
        else
            if [ "$os_type" = "macos" ]; then
                # Convert to percentage (multiply by 100 and round)
                local percentage=$(echo "$native_usage_probability" | awk '{printf "%.0f", $1 * 100}')
                # shell::colored_echo "INFO: Native usage probability: $percentage%" 46
                # Use arithmetic evaluation for comparison (more portable)
                if [ "$percentage" -gt 75 ] 2>/dev/null; then
                    native_usage_probability_formatted="↑${percentage}%"
                elif [ "$percentage" -le 75 ] 2>/dev/null; then
                    native_usage_probability_formatted="↓${percentage}%"
                else
                    native_usage_probability_formatted="N/A"
                fi
            elif [ "$os_type" = "linux" ]; then
                local percentage_float=$(echo "$native_usage_probability * 100" | bc -l 2>/dev/null)
                local percentage=$(printf "%.0f" "$percentage_float" 2>/dev/null)
                # shell::colored_echo "INFO: Native usage probability: $percentage%" 46
                if [[ $percentage =~ ^[0-9]+$ ]] && [ "$percentage" -gt 75 ]; then
                    native_usage_probability_formatted="↑${percentage}%"
                elif [[ $percentage =~ ^[0-9]+$ ]] && [ "$percentage" -le 75 ]; then
                    native_usage_probability_formatted="↓${percentage}%"
                else
                    native_usage_probability_formatted="N/A"
                fi
            fi
        fi

        # Display the suggested correction and its details
        shell::colored_echo "[$native_usage_probability_formatted] $suggested_correction" 255
        shell::colored_echo "[$native_usage_probability] $vietnamese_translation" 255
        for i in $(seq 0 $((natural_alternatives_count - 1))); do
            local alt=$(echo "$item_json" | jq -r ".natural_alternatives[$i] // empty")
            if [ -n "$alt" ]; then
                shell::colored_echo "[alt=$((i + 1))]: $alt" 244
            fi
        done
        for i in $(seq 0 $((example_sentences_count - 1))); do
            local en_sentence=$(echo "$item_json" | jq -r ".example_sentences[$i].en // empty")
            local vi_sentence=$(echo "$item_json" | jq -r ".example_sentences[$i].vi // empty")
            if [ -n "$en_sentence" ]; then
                shell::colored_echo "[seg=$((i + 1))]: $en_sentence" 244
                shell::colored_echo "[svi=$((i + 1))]: $vi_sentence" 244
            fi
        done
        shell::clip_value "$suggested_correction"
    fi
}

# shell::eval_gemini_vi_en function
# Sends a Vietnamese sentence to Gemini for translation to English and interactively displays corrections and examples.
#
# Usage:
# shell::eval_gemini_vi_en [-n] [-d] [-h] <sentence_vietnamese>
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the curl command is printed using shell::on_evict instead of executed.
# - -d : Optional debugging flag. If provided, debug information is printed.
# - -h : Optional help flag. If provided, displays usage information.
#
# Description:
# This function reads a prompt from ~/.shell-config/agents/gemini/prompts/vietnamese_translation_tutor.txt,
# sends it to the Gemini API using curl, and uses jq and fzf to interactively select and display
# the suggested translation and example sentences (formatted as "en (vi)").
shell::eval_gemini_vi_en() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_EVAL_GEMINI_VI_EN"
        return 0
    fi

    # Check if the -n flag is provided for dry-run
    # If -n is provided, it sets the dry_run variable to true
    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if the -d flag is provided for debugging
    # If -d is provided, it sets the debugging variable to true
    local debugging="false"
    if [ "$1" = "-d" ]; then
        debugging="true"
        shift
    fi

    # Check if the required parameters are provided
    if [ -z "$1" ]; then
        echo "Usage: shell::eval_gemini_vi_en [-n] [-d] [-h] <sentence vietnamese>"
        return 1
    fi

    # Ensure the sentence_vietnamese variable is set
    local sentence_vietnamese="$1"
    local prompt_file="$LLM_PROMPTS_DIR/gemini/vi_to_en_prompt_request_v1.txt"

    # Check if the prompt file exists
    if [ ! -f "$prompt_file" ]; then
        shell::colored_echo "ERR: Prompt file not found at '$prompt_file'" 196
        return 1
    fi

    # Replace the placeholder in the prompt file with the provided sentence
    local payload=$(sed "s/{ENTER_SENTENCE_VIETNAMESE}/$sentence_vietnamese/" "$prompt_file")

    # Check if the dry-run is enabled
    if [ "$dry_run" = "true" ]; then
        shell::make_gemini_request -n "$payload"
    else
        local response
        if [ "$debugging" = "true" ]; then
            response=$(shell::make_gemini_request -d "$payload")
        else
            response=$(shell::make_gemini_request "$payload")
        fi

        # Check if the response is empty or if the command failed
        if [ $? -ne 0 ] || [ -z "$response" ]; then
            shell::colored_echo "ERR: Failed to get response from Gemini (sgemviconv): $response." 196
            return 1
        fi

        #  Check if the debugging flag is set
        # If debugging is enabled, it prints the response from Gemini
        # This is useful for debugging purposes to see the raw response from the API
        if [ "$debugging" = "true" ]; then
            shell::colored_echo "$response" 244
            return 0
        fi

        # Extract the first item from the JSON array (assuming the structure from the example)
        # Get the first object as compact JSON
        local item_json=$(echo "$response" | jq -c '.[0]')
        if [ -z "$item_json" ] || [ "$item_json" = "null" ]; then
            shell::colored_echo "ERR: No valid data found in Gemini response: $response." 196
            return 1
        fi

        local os_type=$(shell::get_os_type)
        local translated_english=$(echo "$item_json" | jq -r '.translated_english // empty')
        local native_usage_probability=$(echo "$item_json" | jq -r '.native_usage_probability // empty')
        local natural_alternatives_count=$(echo "$item_json" | jq '.natural_alternatives | length // 0')
        local example_sentences_count=$(echo "$item_json" | jq '.example_sentences | length // 0')

        # Format the native usage probability
        # If native_usage_probability is empty or null, it sets the formatted value to "N/A"
        # If it is a valid number, it formats it as a percentage
        # If the percentage is greater than 75, it adds an arrow pointing up (↑)
        # If the percentage is less than 75, it adds an arrow pointing down (↓)
        # Format the native usage probability
        # If native_usage_probability is empty or null, it sets the formatted value to "N/A"
        # If it is a valid number, it formats it as a percentage
        # If the percentage is greater than 75, it adds an arrow pointing up (↑)
        # If the percentage is less than or equal to 75, it adds an arrow pointing down (↓)
        local native_usage_probability_formatted
        if [ -z "$native_usage_probability" ] || [ "$native_usage_probability" = "null" ]; then
            native_usage_probability_formatted="N/A"
        else
            if [ "$os_type" = "macos" ]; then
                # Convert to percentage (multiply by 100 and round)
                local percentage=$(echo "$native_usage_probability" | awk '{printf "%.0f", $1 * 100}')
                # shell::colored_echo "INFO: Native usage probability: $percentage%" 46
                # Use arithmetic evaluation for comparison (more portable)
                if [ "$percentage" -gt 75 ] 2>/dev/null; then
                    native_usage_probability_formatted="↑${percentage}%"
                elif [ "$percentage" -le 75 ] 2>/dev/null; then
                    native_usage_probability_formatted="↓${percentage}%"
                else
                    native_usage_probability_formatted="N/A"
                fi
            elif [ "$os_type" = "linux" ]; then
                local percentage_float=$(echo "$native_usage_probability * 100" | bc -l 2>/dev/null)
                local percentage=$(printf "%.0f" "$percentage_float" 2>/dev/null)
                # shell::colored_echo "INFO: Native usage probability: $percentage%" 46
                if [[ $percentage =~ ^[0-9]+$ ]] && [ "$percentage" -gt 75 ]; then
                    native_usage_probability_formatted="↑${percentage}%"
                elif [[ $percentage =~ ^[0-9]+$ ]] && [ "$percentage" -le 75 ]; then
                    native_usage_probability_formatted="↓${percentage}%"
                else
                    native_usage_probability_formatted="N/A"
                fi
            fi
        fi

        # Display the suggested correction and its details
        shell::colored_echo "[$native_usage_probability_formatted] $translated_english" 255
        for i in $(seq 0 $((natural_alternatives_count - 1))); do
            local alt=$(echo "$item_json" | jq -r ".natural_alternatives[$i] // empty")
            if [ -n "$alt" ]; then
                shell::colored_echo "[alt=$((i + 1))]: $alt" 244
            fi
        done
        for i in $(seq 0 $((example_sentences_count - 1))); do
            local en_sentence=$(echo "$item_json" | jq -r ".example_sentences[$i].en // empty")
            local vi_sentence=$(echo "$item_json" | jq -r ".example_sentences[$i].vi // empty")
            if [ -n "$en_sentence" ]; then
                shell::colored_echo "[seg=$((i + 1))]: $en_sentence" 244
                shell::colored_echo "[svi=$((i + 1))]: $vi_sentence" 244
            fi
        done
        shell::clip_value "$translated_english"
    fi
}

# shell::gemini_init_workspace function
# Creates and initializes the Gemini workspace directory with daily history structure.
#
# Usage:
#   shell::gemini_init_workspace [-n] [-h] [workspace_dir]
#
# Parameters:
#   - -n             : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h             : Optional. Displays this help message.
#   - [workspace_dir]: Optional. The workspace directory path. Defaults to config value.
#
# Description:
#   Creates the workspace directory and initializes daily conversation structure.
#   Creates history subdirectory for daily conversation backlogs.
#
# Example:
#   shell::gemini_init_workspace
#   shell::gemini_init_workspace -n "$HOME/.custom_gemini"
shell::gemini_init_workspace() {
    local dry_run="false"

    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GEMINI_INIT_WORKSPACE"
        return 0
    fi

    local workspace_dir="$HOME/.shell-config/agents/gemini/workspace"
    local history_dir="$workspace_dir/history"
    local conversation_file="$workspace_dir/conversation.json"
    local session_file="$workspace_dir/session.json"

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "mkdir -p \"$workspace_dir\""
        shell::on_evict "mkdir -p \"$history_dir\""
        shell::on_evict "[ ! -f \"$conversation_file\" ] && echo '{\"contents\": [], \"date\": \"$(date +%Y-%m-%d)\", \"created_at\": \"$(date -Iseconds)\"}' > \"$conversation_file\""
        shell::on_evict "[ ! -f \"$session_file\" ] && echo '{\"model\": \"gemini-2.0-flash\", \"temperature\": 0.7, \"last_used\": \"$(date -Iseconds)\"}' > \"$session_file\""
    else
        shell::run_cmd_eval "mkdir -p \"$workspace_dir\""
        shell::run_cmd_eval "mkdir -p \"$history_dir\""
        if [ ! -f "$conversation_file" ]; then
            shell::run_cmd_eval "echo '{\"contents\": [], \"date\": \"$(date +%Y-%m-%d)\", \"created_at\": \"$(date -Iseconds)\"}' > \"$conversation_file\""
        fi
        if [ ! -f "$session_file" ]; then
            shell::run_cmd_eval "echo '{\"model\": \"gemini-2.0-flash\", \"temperature\": 0.7, \"last_used\": \"$(date -Iseconds)\"}' > \"$session_file\""
        fi
        shell::colored_echo "INFO: Gemini workspace initialized at '$workspace_dir'" 46
    fi
}

# shell::gemini_get_daily_conversation_file function
# Gets the conversation file path for a specific date.
#
# Usage:
#   shell::gemini_get_daily_conversation_file [-h] [date] [workspace_dir]
#
# Parameters:
#   - -h             : Optional. Displays this help message.
#   - [date]         : Optional. Date in YYYY-MM-DD format. Defaults to today.
#   - [workspace_dir]: Optional. The workspace directory path. Defaults to config value.
#
# Description:
#   Returns the path to the conversation file for the specified date.
#   Creates the daily conversation file if it doesn't exist.
#
# Example:
#   file_path=$(shell::gemini_get_daily_conversation_file)
#   file_path=$(shell::gemini_get_daily_conversation_file "2024-01-15")
shell::gemini_get_daily_conversation_file() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GEMINI_GET_DAILY_CONVERSATION_FILE"
        return 0
    fi

    local date="${1:-$(date +%Y-%m-%d)}"
    # local workspace_dir="${2:-$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "WORKSPACE_DIR")}"
    local workspace_dir="$HOME/.shell-config/agents/gemini/workspace"
    local daily_file="$workspace_dir/history/$date.json"

    # Create daily conversation file if it doesn't exist
    if [ ! -f "$daily_file" ]; then
        shell::run_cmd_eval "echo '{\"contents\": [], \"date\": \"$date\", \"created_at\": \"$(date -Iseconds)\"}' > \"$daily_file\""
    fi

    echo "$daily_file"
}

# shell::gemini_archive_current_conversation function
# Archives the current conversation to daily history.
#
# Usage:
#   shell::gemini_archive_current_conversation [-n] [-h] [conversation_file]
#
# Parameters:
#   - -n                  : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h                  : Optional. Displays this help message.
#   - [conversation_file] : Optional. Path to current conversation file. Defaults to workspace/conversation.json.
#
# Description:
#   Saves the current conversation to the daily history backlog and clears the current conversation.
#   Archives conversations by date in YYYY-MM-DD format.
#
# Example:
#   shell::gemini_archive_current_conversation
#   shell::gemini_archive_current_conversation -n
shell::gemini_archive_current_conversation() {
    local dry_run="false"

    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GEMINI_ARCHIVE_CURRENT_CONVERSATION"
        return 0
    fi

    # local workspace_dir="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "WORKSPACE_DIR")"
    local workspace_dir="$HOME/.shell-config/agents/gemini/workspace"
    local conversation_file="${1:-$workspace_dir/conversation.json}"
    local today=$(date +%Y-%m-%d)
    local daily_file="$workspace_dir/history/$today.json"

    # Check if current conversation has content
    if [ ! -f "$conversation_file" ]; then
        if [ "$dry_run" = "false" ]; then
            shell::colored_echo "WARN: No current conversation to archive" 244
        fi
        return 0
    fi

    local content_count=$(jq '.contents | length' "$conversation_file" 2>/dev/null || echo "0")
    if [ "$content_count" = "0" ]; then
        if [ "$dry_run" = "false" ]; then
            shell::colored_echo "INFO: No conversation content to archive" 46
        fi
        return 0
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "# Archive current conversation to $daily_file"
        shell::on_evict "jq '.contents += (.contents // [])' \"$daily_file\" \"$conversation_file\" > \"$daily_file.tmp\" && mv \"$daily_file.tmp\" \"$daily_file\""
        shell::on_evict "echo '{\"contents\": [], \"date\": \"$today\", \"created_at\": \"$(date -Iseconds)\"}' > \"$conversation_file\""
    else
        # Ensure daily file exists
        if [ ! -f "$daily_file" ]; then
            shell::run_cmd_eval "mkdir -p \"$(dirname "$daily_file")\""
            shell::run_cmd_eval "echo '{\"contents\": [], \"date\": \"$today\", \"created_at\": \"$(date -Iseconds)\"}' > \"$daily_file\""
        fi

        # Merge current conversation into daily file
        local merge_cmd="jq -s '.[0] + {contents: (.[0].contents + .[1].contents), archived_at: \"$(date -Iseconds)\"}' \"$daily_file\" \"$conversation_file\" > \"$daily_file.tmp\" && mv \"$daily_file.tmp\" \"$daily_file\""
        shell::run_cmd_eval "$merge_cmd"

        # Clear current conversation
        shell::run_cmd_eval "echo '{\"contents\": [], \"date\": \"$today\", \"created_at\": \"$(date -Iseconds)\"}' > \"$conversation_file\""

        shell::colored_echo "INFO: Conversation archived to daily history: $daily_file" 46
    fi
}

# shell::gemini_load_daily_conversation function
# Loads a specific day's conversation as the current conversation.
#
# Usage:
#   shell::gemini_load_daily_conversation [-n] [-h] <date> [conversation_file]
#
# Parameters:
#   - -n                  : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h                  : Optional. Displays this help message.
#   - <date>              : Date in YYYY-MM-DD format to load.
#   - [conversation_file] : Optional. Path to current conversation file. Defaults to workspace/conversation.json.
#
# Description:
#   Loads a specific day's conversation history as the current active conversation.
#   Useful for continuing conversations from previous days.
#
# Example:
#   shell::gemini_load_daily_conversation "2024-01-15"
#   shell::gemini_load_daily_conversation -n "2024-01-15"
shell::gemini_load_daily_conversation() {
    local dry_run="false"

    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GEMINI_LOAD_DAILY_CONVERSATION"
        return 0
    fi

    if [ -z "$1" ]; then
        shell::colored_echo "ERR: Date is required (YYYY-MM-DD format)" 196
        return 1
    fi

    local date="$1"
    # local workspace_dir="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "WORKSPACE_DIR")"
    local workspace_dir="$HOME/.shell-config/agents/gemini/workspace"
    local conversation_file="${2:-$workspace_dir/conversation.json}"
    local daily_file="$workspace_dir/history/$date.json"

    # Validate date format
    if ! echo "$date" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
        shell::colored_echo "ERR: Invalid date format. Use YYYY-MM-DD" 196
        return 1
    fi

    if [ ! -f "$daily_file" ]; then
        shell::colored_echo "ERR: No conversation found for date: $date" 196
        return 1
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "# Archive current conversation first"
        shell::on_evict "shell::gemini_archive_current_conversation -n"
        shell::on_evict "# Load conversation from $daily_file"
        shell::on_evict "cp \"$daily_file\" \"$conversation_file\""
        shell::on_evict "# Update loaded conversation date"
        shell::on_evict "jq '.loaded_from = \"$date\", .loaded_at = \"$(date -Iseconds)\"' \"$conversation_file\" > \"$conversation_file.tmp\" && mv \"$conversation_file.tmp\" \"$conversation_file\""
    else
        # Archive current conversation first
        shell::gemini_archive_current_conversation

        # Load the daily conversation
        shell::run_cmd_eval "cp \"$daily_file\" \"$conversation_file\""

        # Update metadata
        local update_cmd="jq '. + {loaded_from: \"$date\", loaded_at: \"$(date -Iseconds)\"}' \"$conversation_file\" > \"$conversation_file.tmp\" && mv \"$conversation_file.tmp\" \"$conversation_file\""
        shell::run_cmd_eval "$update_cmd"

        local message_count=$(jq '.contents | length' "$conversation_file" 2>/dev/null || echo "0")
        shell::colored_echo "INFO: Loaded conversation from $date ($message_count messages)" 46
    fi
}

# shell::gemini_list_conversation_history function
# Lists available conversation history by date.
#
# Usage:
#   shell::gemini_list_conversation_history [-h] [-l] [days]
#
# Parameters:
#   - -h     : Optional. Displays this help message.
#   - -l     : Optional. Long format with message counts and timestamps.
#   - [days] : Optional. Number of recent days to show. Defaults to 7.
#
# Description:
#   Lists available conversation history files with optional details.
#   Shows dates, message counts, and timestamps when available.
#
# Example:
#   shell::gemini_list_conversation_history
#   shell::gemini_list_conversation_history -l 30
shell::gemini_list_conversation_history() {
    local long_format="false"
    local days="7"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
        -h)
            echo "$USAGE_SHELL_GEMINI_LIST_CONVERSATION_HISTORY"
            return 0
            ;;
        -l)
            long_format="true"
            shift
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                days="$1"
            fi
            shift
            ;;
        esac
    done

    # local workspace_dir="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "WORKSPACE_DIR")"
    local workspace_dir="$HOME/.shell-config/agents/gemini/workspace"
    local history_dir="$workspace_dir/history"

    if [ ! -d "$history_dir" ]; then
        shell::colored_echo "INFO: No conversation history found" 46
        return 0
    fi

    shell::colored_echo "INFO: Conversation History" 46
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Get recent history files
    local files=$(find "$history_dir" -name "*.json" -type f | sort -r | head -n "$days")

    if [ -z "$files" ]; then
        shell::colored_echo "INFO: No conversation files found in last $days days" 244
        return 0
    fi

    if [ "$long_format" = "true" ]; then
        printf "%-12s %-8s %-20s %-20s\n" "Date" "Messages" "Created" "Last Modified"
        echo "────────────────────────────────────────────────────────────────────────────"

        for file in $files; do
            local basename=$(basename "$file" .json)
            local message_count=$(jq '.contents | length' "$file" 2>/dev/null || echo "0")
            local created=$(jq -r '.created_at // "Unknown"' "$file" 2>/dev/null)
            local modified=$(stat -c "%y" "$file" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1 || echo "Unknown")

            # Format created timestamp
            if [ "$created" != "Unknown" ] && [ "$created" != "null" ]; then
                created=$(echo "$created" | cut -d'T' -f1,2 | tr 'T' ' ' | cut -d'+' -f1)
            fi

            printf "%-12s %-8s %-20s %-20s\n" "$basename" "$message_count" "$created" "$modified"
        done
    else
        echo "Available dates:"
        for file in $files; do
            local basename=$(basename "$file" .json)
            local message_count=$(jq '.contents | length' "$file" 2>/dev/null || echo "0")
            printf "  %s (%s messages)\n" "$basename" "$message_count"
        done
    fi

    echo ""
    shell::colored_echo "INFO: Use 'shell::gemini_load_daily_conversation <date>' to load a specific day" 244
}

# shell::gemini_cleanup_old_history function
# Cleans up old conversation history based on retention policy.
#
# Usage:
#   shell::gemini_cleanup_old_history [-n] [-h] [retention_days]
#
# Parameters:
#   - -n              : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h              : Optional. Displays this help message.
#   - [retention_days]: Optional. Number of days to retain. Defaults to config value.
#
# Description:
#   Removes conversation history files older than the specified retention period.
#   Helps manage disk space by cleaning up old conversations.
#
# Example:
#   shell::gemini_cleanup_old_history
#   shell::gemini_cleanup_old_history -n 60
shell::gemini_cleanup_old_history() {
    local dry_run="false"

    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GEMINI_CLEANUP_OLD_HISTORY"
        return 0
    fi

    # local retention_days="${1:-$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "HISTORY_RETENTION_DAYS")}"
    local retention_days="30"
    # local workspace_dir="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "WORKSPACE_DIR")"
    local workspace_dir="$HOME/.shell-config/agents/gemini/workspace"
    local history_dir="$workspace_dir/history"

    if [ ! -d "$history_dir" ]; then
        if [ "$dry_run" = "false" ]; then
            shell::colored_echo "INFO: No history directory found" 46
        fi
        return 0
    fi

    # Calculate cutoff date
    local cutoff_date=""
    if shell::is_command_available date; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            cutoff_date=$(date -v-"${retention_days}"d +%Y-%m-%d)
        else
            cutoff_date=$(date -d "-${retention_days} days" +%Y-%m-%d)
        fi
    else
        shell::colored_echo "ERR: date command not available" 196
        return 1
    fi

    # Find old files
    local old_files=$(find "$history_dir" -name "*.json" -type f | while read -r file; do
        local basename=$(basename "$file" .json)
        if [[ "$basename" < "$cutoff_date" ]]; then
            echo "$file"
        fi
    done)

    if [ -z "$old_files" ]; then
        if [ "$dry_run" = "false" ]; then
            shell::colored_echo "INFO: No old conversation files to clean up" 46
        fi
        return 0
    fi

    local file_count=$(echo "$old_files" | wc -l)

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "# Would remove $file_count conversation files older than $retention_days days"
        echo "$old_files" | while read -r file; do
            shell::on_evict "rm \"$file\""
        done
    else
        shell::colored_echo "INFO: Removing $file_count conversation files older than $retention_days days" 46
        echo "$old_files" | while read -r file; do
            shell::run_cmd_eval "rm \"$file\""
            shell::colored_echo "INFO: Removed $(basename "$file")" 244
        done
        shell::colored_echo "INFO: Cleanup completed" 46
    fi
}

# shell::gemini_clear_conversation function
# Clears the current conversation history.
#
# Usage:
#   shell::gemini_clear_conversation [-n] [-h] [--archive] [conversation_file]
#
# Parameters:
#   - -n                  : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h                  : Optional. Displays this help message.
#   - --archive           : Optional. Archive current conversation before clearing.
#   - [conversation_file] : Optional. Path to conversation file. Defaults to workspace/conversation.json.
#
# Description:
#   Resets the current conversation history to an empty state.
#   Optionally archives the current conversation before clearing.
#
# Example:
#   shell::gemini_clear_conversation
#   shell::gemini_clear_conversation --archive
#   shell::gemini_clear_conversation -n "$HOME/.gemini/conversation.json"
shell::gemini_clear_conversation() {
    local dry_run="false"
    local archive_first="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
        -n)
            dry_run="true"
            shift
            ;;
        -h)
            echo "$USAGE_SHELL_GEMINI_CLEAR_CONVERSATION"
            return 0
            ;;
        --archive)
            archive_first="true"
            shift
            ;;
        *)
            conversation_file="$1"
            shift
            ;;
        esac
    done

    # local workspace_dir="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "WORKSPACE_DIR")"
    local workspace_dir="$HOME/.shell-config/agents/gemini/workspace"
    local conversation_file="${conversation_file:-$workspace_dir/conversation.json}"
    local today=$(date +%Y-%m-%d)

    if [ "$archive_first" = "true" ]; then
        if [ "$dry_run" = "true" ]; then
            shell::gemini_archive_current_conversation -n
        else
            shell::gemini_archive_current_conversation
        fi
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "echo '{\"contents\": [], \"date\": \"$today\", \"created_at\": \"$(date -Iseconds)\"}' > \"$conversation_file\""
    else
        shell::run_cmd_eval "echo '{\"contents\": [], \"date\": \"$today\", \"created_at\": \"$(date -Iseconds)\"}' > \"$conversation_file\""
        shell::colored_echo "INFO: Conversation history cleared" 46
    fi
}

# shell::gemini_add_message function
# Adds a message to the conversation history.
#
# Usage:
#   shell::gemini_add_message [-n] [-h] <role> <content> [attachments] [conversation_file]
#
# Parameters:
#   - -n                  : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h                  : Optional. Displays this help message.
#   - <role>              : The message role (user, model).
#   - <content>           : The message content.
#   - [attachments]       : Optional. JSON array of file attachments.
#   - [conversation_file] : Optional. Path to conversation file. Defaults to workspace/conversation.json.
#
# Description:
#   Adds a new message to the conversation history with proper JSON formatting.
#
# Example:
#   shell::gemini_add_message "user" "Hello, how are you?"
#   shell::gemini_add_message -n "model" "I'm doing well, thank you!"
shell::gemini_add_message() {
    local dry_run="false"

    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GEMINI_ADD_MESSAGE"
        return 0
    fi

    if [ $# -lt 2 ]; then
        shell::colored_echo "ERR: Role and content are required" 196
        return 1
    fi

    local role="$1"
    local content="$2"
    local attachments="$3"
    # local workspace_dir="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "WORKSPACE_DIR")"
    local workspace_dir="$HOME/.shell-config/agents/gemini/workspace"
    local conversation_file="${4:-$workspace_dir/conversation.json}"

    # Build message parts
    local escaped_content=$(echo "$content" | jq -R -s '.')
    local parts='[{"text": '"$escaped_content"'}]'

    if [[ -n "$attachments" ]]; then
        parts='[{"text": '"$escaped_content"'}, '"$attachments"']'
    fi

    local jq_cmd="jq '.contents += [{\"role\": \"$role\", \"parts\": $parts}]' \"$conversation_file\" > \"$conversation_file.tmp\" && mv \"$conversation_file.tmp\" \"$conversation_file\""

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$jq_cmd"
    else
        shell::run_cmd_eval "$jq_cmd"
    fi
}

# shell::gemini_encode_file function
# Encodes a file to base64 for API submission.
#
# Usage:
#   shell::gemini_encode_file [-n] [-h] <file_path>
#
# Parameters:
#   - -n         : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h         : Optional. Displays this help message.
#   - <file_path>: The path to the file to encode.
#
# Description:
#   Encodes the specified file to base64 format for API consumption.
#   Handles platform differences between macOS and Linux.
#
# Example:
#   shell::gemini_encode_file "document.pdf"
#   shell::gemini_encode_file -n "image.jpg"
shell::gemini_encode_file() {
    local dry_run="false"

    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GEMINI_ENCODE_FILE"
        return 0
    fi

    if [ -z "$1" ]; then
        shell::colored_echo "ERR: File path is required" 196
        return 1
    fi

    local file_path="$1"

    if [ ! -f "$file_path" ]; then
        shell::colored_echo "ERR: File not found: $file_path" 196
        return 1
    fi

    local os_type=$(shell::get_os_type)
    local base64_cmd=""

    if [ "$os_type" = "macos" ]; then
        base64_cmd="base64 -i \"$file_path\""
    else
        base64_cmd="base64 -w 0 \"$file_path\""
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$base64_cmd"
    else
        shell::run_cmd_eval "$base64_cmd"
    fi
}

# shell::gemini_get_mime_type function
# Determines the MIME type of a file.
#
# Usage:
#   shell::gemini_get_mime_type [-h] <file_path>
#
# Parameters:
#   - -h         : Optional. Displays this help message.
#   - <file_path>: The path to the file.
#
# Description:
#   Returns the appropriate MIME type based on file extension.
#
# Example:
#   mime_type=$(shell::gemini_get_mime_type "document.pdf")
shell::gemini_get_mime_type() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GEMINI_GET_MIME_TYPE"
        return 0
    fi

    if [ -z "$1" ]; then
        shell::colored_echo "ERR: File path is required" 196
        return 1
    fi

    local file_path="$1"
    local extension="${file_path##*.}"

    case "$extension" in
    txt | log) echo "text/plain" ;;
    json) echo "application/json" ;;
    csv) echo "text/csv" ;;
    md) echo "text/markdown" ;;
    html) echo "text/html" ;;
    xml) echo "application/xml" ;;
    jpg | jpeg) echo "image/jpeg" ;;
    png) echo "image/png" ;;
    webp) echo "image/webp" ;;
    gif) echo "image/gif" ;;
    pdf) echo "application/pdf" ;;
    docx) echo "application/vnd.openxmlformats-officedocument.wordprocessingml.document" ;;
    xlsx) echo "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" ;;
    *) echo "text/plain" ;;
    esac
}

# shell::gemini_build_request function
# Builds the API request payload.
#
# Usage:
#   shell::gemini_build_request [-n] [-h] <prompt> [file_path] [temperature] [schema_file] [continue_chat]
#
# Parameters:
#   - -n            : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h            : Optional. Displays this help message.
#   - <prompt>      : The user prompt.
#   - [file_path]   : Optional. Path to file attachment.
#   - [temperature] : Optional. Temperature setting (0.0-2.0).
#   - [schema_file] : Optional. Path to JSON schema file.
#   - [continue_chat]: Optional. Continue existing conversation (true/false).
#
# Description:
#   Constructs the JSON request payload for the Gemini API.
#
# Example:
#   payload=$(shell::gemini_build_request "Explain quantum computing")
shell::gemini_build_request() {
    local dry_run="false"

    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GEMINI_BUILD_REQUEST"
        return 0
    fi

    if [ -z "$1" ]; then
        shell::colored_echo "ERR: Prompt is required" 196
        return 1
    fi

    local prompt="$1"
    local file_path="$2"
    local temperature="${3:-0.7}"
    local schema_file="$4"
    local continue_chat="${5:-false}"
    # local workspace_dir="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "WORKSPACE_DIR")"
    local workspace_dir="$HOME/.shell-config/agents/gemini/workspace"
    local conversation_file="$workspace_dir/conversation.json"

    local attachments=""
    if [[ -n "$file_path" && -f "$file_path" ]]; then
        if [ "$dry_run" = "false" ]; then
            shell::colored_echo "INFO: Processing file: $file_path" 46
        fi
        local mime_type=$(shell::gemini_get_mime_type "$file_path")
        local base64_data=""

        if [ "$dry_run" = "true" ]; then
            shell::on_evict "shell::gemini_encode_file \"$file_path\""
            base64_data="<encoded_data>"
        else
            base64_data=$(shell::gemini_encode_file "$file_path")
        fi

        attachments='{"inlineData": {"mimeType": "'"$mime_type"'", "data": "'"$base64_data"'"}}'
    fi

    # Get configuration values
    # local max_tokens="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "MAX_TOKENS")"
    local max_tokens="8192"
    # local top_k="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "TOP_K")"
    local top_k="40"
    # local top_p="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "TOP_P")"
    local top_p="0.95"

    local jq_build_cmd=""
    if [[ "$continue_chat" == "true" ]]; then
        # Add to existing conversation
        if [ "$dry_run" = "true" ]; then
            shell::on_evict "shell::gemini_add_message -n \"user\" \"$prompt\" \"$attachments\" \"$conversation_file\""
            jq_build_cmd="jq -n --argjson contents '[]' --arg temp '$temperature' --arg topK '$top_k' --arg topP '$top_p' --arg maxTokens '$max_tokens' '{contents: \$contents, generationConfig: {temperature: (\$temp | tonumber), topK: (\$topK | tonumber), topP: (\$topP | tonumber), maxOutputTokens: (\$maxTokens | tonumber)}}'"
        else
            shell::gemini_add_message "user" "$prompt" "$attachments" "$conversation_file"
            jq_build_cmd="jq --arg temp '$temperature' --arg topK '$top_k' --arg topP '$top_p' --arg maxTokens '$max_tokens' '{contents: .contents, generationConfig: {temperature: (\$temp | tonumber), topK: (\$topK | tonumber), topP: (\$topP | tonumber), maxOutputTokens: (\$maxTokens | tonumber)}}' \"$conversation_file\""
        fi
    else
        # Build new conversation
        local escaped_prompt=$(echo "$prompt" | jq -R -s '.')
        local parts='[{"text": '"$escaped_prompt"'}]'
        if [[ -n "$attachments" ]]; then
            parts='[{"text": '"$escaped_prompt"'}, '"$attachments"']'
        fi
        # jq_build_cmd="jq -n --argjson parts '$parts' --arg temp '$temperature' --arg topK '$top_k' --arg topP '$top_p' --arg maxTokens '$max_tokens' '{contents: [{role: \"user\", parts: \$parts}], generationConfig: {temperature: (\$temp | tonumber), topK: (\$topK | tonumber), topP: (\$topP | tonumber), maxOutputTokens: (\$maxTokens | tonumber)}}'"
    fi

    # Add JSON schema if provided
    if [[ -n "$schema_file" && -f "$schema_file" ]]; then
        local schema_cmd="$jq_build_cmd | jq '. + {generationConfig: (.generationConfig + {responseMimeType: \"application/json\", responseSchema: (\"$schema_file\" | fromjson)})}'"
        jq_build_cmd="$schema_cmd"
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$jq_build_cmd"
    else
        shell::run_cmd_eval "$jq_build_cmd"
    fi
}

# shell::gemini_stream_response function
# Streams response from the Gemini API.
#
# Usage:
#   shell::gemini_stream_response [-n] [-d] [-h] <request_payload>
#
# Parameters:
#   - -n               : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -d               : Optional debugging flag.
#   - -h               : Optional. Displays this help message.
#   - <request_payload>: The JSON request payload.
#
# Description:
#   Sends a streaming request to the Gemini API and processes the real-time response.
#
# Example:
#   shell::gemini_stream_response "$payload"
shell::gemini_stream_response() {
    local dry_run="false"
    local debugging="false"

    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ "$1" = "-d" ]; then
        debugging="true"
        shift
    fi

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GEMINI_STREAM_RESPONSE"
        return 0
    fi

    if [ -z "$1" ]; then
        shell::colored_echo "ERR: Request payload is required" 196
        return 1
    fi

    local request_payload="$1"
    local api_key="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "API_KEY")"
    local model="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "MODEL")"
    # local workspace_dir="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "WORKSPACE_DIR")"
    local workspace_dir="$HOME/.shell-config/agents/gemini/workspace"
    local response_file="$workspace_dir/response.md"

    if [ -z "$api_key" ] || [ "$api_key" = "your-api-key-here" ]; then
        shell::colored_echo "ERR: Valid API key is required" 196
        return 1
    fi

    if [ "$debugging" = "true" ]; then
        shell::colored_echo "DEBUG: Request payload:" 244
        echo "$request_payload" | jq .
    fi

    local curl_cmd="curl -s -N --location \"https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?key=$api_key\" --header 'Content-Type: application/json' --data '$request_payload'"

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$curl_cmd"
        shell::on_evict "# Process streaming response and save to $response_file"
        shell::on_evict "# Add response to conversation history"
        return 0
    fi

    shell::colored_echo "INFO: Streaming response from $model..." 46

    # Execute streaming and process response
    shell::run_cmd_eval "echo -n '' > \"$response_file\""

    local temp_script=$(mktemp)
    cat >"$temp_script" <<'EOF'
#!/bin/bash
response_file="$1"
debugging="$2"
full_response=""

while IFS= read -r line; do
    [[ "$debugging" == "true" ]] && echo "DEBUG: Processing line: $line" >&2
    [[ -z "$line" ]] && continue
    
    json_line="$line"
    if [[ "$line" =~ ^data:\ (.*)$ ]]; then
        json_line="${BASH_REMATCH[1]}"
    fi
    
    [[ -z "$json_line" || "$json_line" == "data: " ]] && continue
    
    if echo "$json_line" | jq empty 2>/dev/null; then
        text=$(echo "$json_line" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
        
        if [[ -n "$text" && "$text" != "null" && "$text" != "empty" ]]; then
            printf "%s" "$text"
            printf "%s" "$text" >> "$response_file"
            full_response+="$text"
        fi
        
        finish_reason=$(echo "$json_line" | jq -r '.candidates[0].finishReason // empty' 2>/dev/null)
        if [[ -n "$finish_reason" && "$finish_reason" != "empty" ]]; then
            [[ "$debugging" == "true" ]] && echo "DEBUG: Finish reason: $finish_reason" >&2
            break
        fi
    else
        [[ "$debugging" == "true" ]] && echo "WARN: Non-JSON line: $json_line" >&2
    fi
done
echo ""
EOF

    chmod +x "$temp_script"

    local stream_cmd="$curl_cmd | \"$temp_script\" \"$response_file\" \"$debugging\""
    shell::run_cmd_eval "$stream_cmd"
    shell::run_cmd_eval "rm -f \"$temp_script\""

    # Add response to conversation
    if [[ -f "$response_file" && -s "$response_file" ]]; then
        local response_content=$(cat "$response_file")
        shell::colored_echo "INFO: Response saved ($(wc -c <"$response_file") bytes)" 46
        if [[ -n "$response_content" ]]; then
            shell::gemini_add_message "model" "$response_content" ""
        fi
    else
        shell::colored_echo "ERR: No response content received" 196
        return 1
    fi
}

# shell::gemini_request function
# Makes a non-streaming request to the Gemini API.
#
# Usage:
#   shell::gemini_request [-n] [-d] [-h] <request_payload>
#
# Parameters:
#   - -n               : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -d               : Optional debugging flag.
#   - -h               : Optional. Displays this help message.
#   - <request_payload>: The JSON request payload.
#
# Description:
#   Sends a non-streaming request to the Gemini API.
#
# Example:
#   shell::gemini_request "$payload"
shell::gemini_request() {
    local dry_run="false"
    local debugging="false"

    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ "$1" = "-d" ]; then
        debugging="true"
        shift
    fi

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GEMINI_REQUEST"
        return 0
    fi

    if [ -z "$1" ]; then
        shell::colored_echo "ERR: Request payload is required" 196
        return 1
    fi

    local request_payload="$1"
    local api_key="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "API_KEY")"
    local model="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "MODEL")"
    # local workspace_dir="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "WORKSPACE_DIR")"
    local workspace_dir="$HOME/.shell-config/agents/gemini/workspace"
    local response_file="$workspace_dir/response.md"

    if [ -z "$api_key" ] || [ "$api_key" = "your-api-key-here" ]; then
        shell::colored_echo "ERR: Valid API key is required" 196
        return 1
    fi

    if [ "$debugging" = "true" ]; then
        shell::colored_echo "DEBUG: Request payload:" 244
        echo "$request_payload" | jq .
    fi

    # local curl_cmd="curl -s --location \"https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$api_key\" --header 'Content-Type: application/json' --data '$request_payload'"
    local curl_cmd="curl -s --location https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyCV3Fx-hOK3Ip5WTMO7a-TNydXr0eCfXnE\" --header 'Content-Type: application/json' --data '$request_payload'"

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$curl_cmd"
        shell::on_evict "# Extract response text and save to $response_file"
        shell::on_evict "# Add response to conversation history"
        return 0
    fi

    shell::colored_echo "INFO: Getting response from $model..." 46

    local process_cmd="$curl_cmd | jq -r '.candidates[0].content.parts[0].text // empty' > \"$response_file\""
    shell::run_cmd_eval "$process_cmd"

    if [[ -f "$response_file" && -s "$response_file" ]]; then
        local response_content=$(cat "$response_file")
        echo "$response_content"
        shell::gemini_add_message "model" "$response_content" ""
        shell::colored_echo "INFO: Response saved to $response_file" 46
    else
        shell::colored_echo "ERR: No response received" 196
        return 1
    fi
}

# shell::gemini_display_response function
# Displays the Gemini response with proper formatting.
#
# Usage:
#   shell::gemini_display_response [-h] [schema_file] [response_file]
#
# Parameters:
#   - -h             : Optional. Displays this help message.
#   - [schema_file]  : Optional. JSON schema file for JSON response formatting.
#   - [response_file]: Optional. Path to response file. Defaults to workspace/response.md.
#
# Description:
#   Displays the response using glow for markdown or jq for JSON formatting.
#
# Example:
#   shell::gemini_display_response
#   shell::gemini_display_response "schema.json"
shell::gemini_display_response() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GEMINI_DISPLAY_RESPONSE"
        return 0
    fi

    local schema_file="$1"
    local workspace_dir="$HOME/.shell-config/agents/gemini/workspace"
    # local workspace_dir="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "WORKSPACE_DIR")"
    local response_file="${2:-$workspace_dir/response.md}"

    shell::colored_echo "INFO: Formatted Response:" 46
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ ! -f "$response_file" ]]; then
        shell::colored_echo "ERR: Response file not found: $response_file" 196
        return 1
    elif [[ ! -s "$response_file" ]]; then
        shell::colored_echo "ERR: Response file is empty: $response_file" 196
        return 1
    fi

    if [[ -n "$schema_file" ]]; then
        shell::colored_echo "INFO: JSON Response:" 255
        local format_cmd="cat \"$response_file\" | jq . 2>/dev/null || cat \"$response_file\""
        shell::run_cmd_eval "$format_cmd"
    elif shell::is_command_available glow; then
        local glow_cmd="glow \"$response_file\" -p"
        shell::run_cmd_eval "$glow_cmd"
    else
        shell::colored_echo "WARN: Glow not installed. Install with: brew install glow" 244
        shell::colored_echo "INFO: Raw response:" 255
        shell::run_cmd_eval "cat \"$response_file\""
    fi
}

# shell::gemini_chat function
# Main function for Gemini chat functionality with daily conversation management.
#
# Usage:
#   shell::gemini_chat [-n] [-d] [-h] [-m model] [-t temperature] [-s] [--no-stream] [-j schema_file] [-c] [--clear] [--archive] [--load date] [--history] <prompt> [file_path]
#
# Parameters:
#   - -n           : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -d           : Optional debugging flag.
#   - -h           : Optional. Displays this help message.
#   - -m model     : Optional. Gemini model to use.
#   - -t temperature: Optional. Temperature setting (0.0-2.0).
#   - -s           : Optional. Enable streaming (default).
#   - --no-stream  : Optional. Disable streaming.
#   - -j schema_file: Optional. Path to JSON schema file.
#   - -c           : Optional. Continue previous conversation.
#   - --clear      : Optional. Clear conversation history.
#   - --archive    : Optional. Archive current conversation before clearing.
#   - --load date  : Optional. Load conversation from specific date (YYYY-MM-DD).
#   - --history    : Optional. Show conversation history list.
#   - <prompt>     : The user prompt.
#   - [file_path]  : Optional. Path to file attachment.
#
# Description:
#   Main entry point for Gemini chat functionality with full feature support including daily conversation management.
#
# Example:
#   shell::gemini_chat "Explain quantum computing"
#   shell::gemini_chat -c -m "gemini-1.5-pro" "Continue our discussion"
#   shell::gemini_chat --load "2024-01-15" -c "Continue yesterday's conversation"
#   shell::gemini_chat --history
shell::gemini_chat() {
    local dry_run="false"
    local debugging="false"
    local model=""
    local temperature="0.7"
    local enable_streaming="true"
    local schema_file=""
    local continue_chat="false"
    local clear_chat="false"
    local archive_first="false"
    local load_date=""
    local show_history="false"
    local prompt=""
    local file_path=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
        -n)
            dry_run="true"
            shift
            ;;
        -d)
            debugging="true"
            shift
            ;;
        -h)
            echo "$USAGE_SHELL_GEMINI_CHAT"
            return 0
            ;;
        -m)
            model="$2"
            shift 2
            ;;
        -t)
            temperature="$2"
            shift 2
            ;;
        -s)
            enable_streaming="true"
            shift
            ;;
        --no-stream)
            enable_streaming="false"
            shift
            ;;
        -j)
            schema_file="$2"
            shift 2
            ;;
        -c)
            continue_chat="true"
            shift
            ;;
        --clear)
            clear_chat="true"
            shift
            ;;
        --archive)
            archive_first="true"
            shift
            ;;
        --load)
            load_date="$2"
            shift 2
            ;;
        --history)
            show_history="true"
            shift
            ;;
        *)
            if [[ -z "$prompt" ]]; then
                prompt="$1"
            elif [[ -z "$file_path" ]]; then
                file_path="$1"
            fi
            shift
            ;;
        esac
    done

    # Initialize if needed
    if [[ ! -f "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" ]]; then
        if [ "$dry_run" = "true" ]; then
            shell::gemini_init_config -n
        else
            shell::gemini_init_config
        fi
    fi

    # Initialize workspace
    if [ "$dry_run" = "true" ]; then
        shell::gemini_init_workspace -n
    else
        shell::gemini_init_workspace
    fi

    # Handle history listing
    if [[ "$show_history" == "true" ]]; then
        shell::gemini_list_conversation_history -l
        return 0
    fi

    # Handle conversation loading
    if [[ -n "$load_date" ]]; then
        if [ "$dry_run" = "true" ]; then
            shell::gemini_load_daily_conversation -n "$load_date"
        else
            shell::gemini_load_daily_conversation "$load_date"
        fi
        if [[ -z "$prompt" ]]; then
            return 0 # Just load, don't continue
        fi
        continue_chat="true" # Auto-enable continue mode when loading
    fi

    # Handle conversation clearing
    if [[ "$clear_chat" == "true" ]]; then
        if [ "$archive_first" = "true" ]; then
            if [ "$dry_run" = "true" ]; then
                shell::gemini_clear_conversation -n --archive
            else
                shell::gemini_clear_conversation --archive
            fi
        else
            if [ "$dry_run" = "true" ]; then
                shell::gemini_clear_conversation -n
            else
                shell::gemini_clear_conversation
            fi
        fi
        if [[ -z "$prompt" ]]; then
            return 0 # Just clear, don't continue
        fi
    fi

    # Validate prompt is provided for chat
    if [[ -z "$prompt" ]]; then
        shell::colored_echo "ERR: No prompt provided" 196
        shell::colored_echo "INFO: Use --history to view conversation history" 244
        shell::colored_echo "INFO: Use --load YYYY-MM-DD to load a specific conversation" 244
        return 1
    fi

    # Auto-archive daily conversations
    # local daily_history="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "DAILY_HISTORY")"
    local daily_history="true" # Default to true for this example
    if [[ "$daily_history" == "true" && "$continue_chat" == "false" && "$clear_chat" == "false" ]]; then
        # Check if current conversation is from a different day
        # local workspace_dir="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "WORKSPACE_DIR")"
        local workspace_dir="$HOME/.shell-config/agents/gemini/workspace"
        local conversation_file="$workspace_dir/conversation.json"
        local today=$(date +%Y-%m-%d)

        if [[ -f "$conversation_file" ]]; then
            local conv_date=$(jq -r '.date // "unknown"' "$conversation_file" 2>/dev/null)
            if [[ "$conv_date" != "$today" && "$conv_date" != "unknown" ]]; then
                if [ "$dry_run" = "false" ]; then
                    shell::colored_echo "INFO: Auto-archiving conversation from $conv_date" 244
                    shell::gemini_archive_current_conversation
                fi
            fi
        fi
    fi

    # Update model if provided
    if [[ -n "$model" ]]; then
        if [ "$dry_run" = "true" ]; then
            shell::on_evict "shell::write_ini \"$SHELL_KEY_CONF_AGENT_GEMINI_FILE\" \"gemini\" \"MODEL\" \"$model\""
        else
            shell::write_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "MODEL" "$model"
        fi
    fi

    # Validate file exists
    if [[ -n "$file_path" && ! -f "$file_path" ]]; then
        shell::colored_echo "ERR: File not found: $file_path" 196
        return 1
    fi

    # Validate JSON schema exists
    if [[ -n "$schema_file" && ! -f "$schema_file" ]]; then
        shell::colored_echo "ERR: JSON schema file not found: $schema_file" 196
        return 1
    fi

    # Check dependencies
    for cmd in curl jq; do
        if ! shell::is_command_available "$cmd"; then
            shell::colored_echo "ERR: $cmd is required but not installed" 196
            return 1
        fi
    done

    # Get current model
    local current_model="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "MODEL")"

    # Display session info
    shell::colored_echo "INFO: Model: $current_model" 46
    shell::colored_echo "INFO: Temperature: $temperature" 46
    shell::colored_echo "INFO: Prompt: $prompt" 46
    [[ -n "$file_path" ]] && shell::colored_echo "INFO: File: $file_path" 46
    [[ -n "$schema_file" ]] && shell::colored_echo "INFO: JSON Schema: $schema_file" 46
    [[ "$continue_chat" == "true" ]] && shell::colored_echo "INFO: Continue conversation: Yes" 46
    [[ -n "$load_date" ]] && shell::colored_echo "INFO: Loaded from: $load_date" 46
    echo ""

    # Build request
    local request_payload
    if [ "$dry_run" = "true" ]; then
        request_payload=$(shell::gemini_build_request -n "$prompt" "$file_path" "$temperature" "$schema_file" "$continue_chat")
    else
        request_payload=$(shell::gemini_build_request "$prompt" "$file_path" "$temperature" "$schema_file" "$continue_chat")
    fi

    # Make request
    if [[ "$enable_streaming" == "true" ]]; then
        if [ "$dry_run" = "true" ]; then
            shell::gemini_stream_response -n ${debugging:+-d} "$request_payload"
        else
            shell::gemini_stream_response ${debugging:+-d} "$request_payload"
        fi
    else
        if [ "$dry_run" = "true" ]; then
            shell::gemini_request -n ${debugging:+-d} "$request_payload"
        else
            shell::gemini_request ${debugging:+-d} "$request_payload"
        fi
    fi

    # Display response
    # if [ "$dry_run" = "false" ]; then
    #     shell::gemini_display_response "$schema_file"

    #     local workspace_dir="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "WORKSPACE_DIR")"
    #     local response_file="$workspace_dir/response.md"
    #     local conversation_file="$workspace_dir/conversation.json"

    #     shell::colored_echo "INFO: Response saved to: $response_file" 46
    #     shell::colored_echo "INFO: Conversation: $conversation_file" 46
    #     shell::colored_echo "INFO: Daily history: $workspace_dir/history/" 244
    #     echo ""
    #     shell::colored_echo "INFO: Use 'shell::gemini_chat --history' to view conversation history" 244

    if [ "$dry_run" = "false" ]; then
        shell::gemini_display_response "$schema_file"

        local workspace_dir="$HOME/.shell-config/agents/gemini/workspace"
        # local workspace_dir="$(shell::read_ini "$SHELL_KEY_CONF_AGENT_GEMINI_FILE" "gemini" "WORKSPACE_DIR")"
        local response_file="$workspace_dir/response.md"
        local conversation_file="$workspace_dir/conversation.json"

        shell::colored_echo "INFO: Response saved to: $response_file" 46
        [[ "$continue_chat" == "true" ]] && shell::colored_echo "INFO: Conversation saved to: $conversation_file" 46
    fi
}

gemini_stream() {
    local question="$1"
    local api_key="AIzaSyCV3Fx-hOK3Ip5WTMO7a-TNydXr0eCfXnE"
    local model="gemini-2.0-flash"
    local temp_file="/tmp/gemini_response.md"
    local response_buffer=""
    local display_pid=""

    # Check dependencies
    command -v curl >/dev/null 2>&1 || {
        echo "Error: curl is required but not installed." >&2
        return 1
    }
    command -v jq >/dev/null 2>&1 || {
        echo "Error: jq is required but not installed." >&2
        return 1
    }
    command -v glow >/dev/null 2>&1 || {
        echo "Error: glow is required but not installed." >&2
        return 1
    }

    # Check API key
    if [[ -z "$api_key" ]]; then
        echo "Error: GEMINI_API_KEY environment variable is not set." >&2
        echo "Please set it with: export GEMINI_API_KEY='your-api-key-here'" >&2
        return 1
    fi

    # Check if question is provided
    if [[ -z "$question" ]]; then
        echo "Usage: gemini_stream \"Your question here\"" >&2
        return 1
    fi

    # Initialize temp file with header
    cat >"$temp_file" <<'EOF'
# Gemini Response

**Question:** QUESTION_PLACEHOLDER

**Response:**

EOF

    # Replace placeholder with actual question
    sed -i.bak "s/QUESTION_PLACEHOLDER/$question/" "$temp_file" 2>/dev/null ||
        sed -i "s/QUESTION_PLACEHOLDER/$question/" "$temp_file" 2>/dev/null
    rm -f "$temp_file.bak" 2>/dev/null

    # Function to update display
    update_display() {
        if [[ -n "$display_pid" ]]; then
            kill "$display_pid" 2>/dev/null
            wait "$display_pid" 2>/dev/null
        fi
        clear
        glow "$temp_file" &
        display_pid=$!
    }

    # Initial display
    update_display

    # Cleanup function
    cleanup() {
        if [[ -n "$display_pid" ]]; then
            kill "$display_pid" 2>/dev/null
            wait "$display_pid" 2>/dev/null
        fi
        rm -f "$temp_file"
    }

    # Set trap for cleanup
    trap cleanup EXIT INT TERM

    # Prepare JSON payload
    local json_payload
    json_payload=$(jq -n \
        --arg text "$question" \
        '{
            contents: [{
                parts: [{
                    text: $text
                }]
            }],
            generationConfig: {
                temperature: 0.7,
                candidateCount: 1,
                maxOutputTokens: 8192
            }
        }')

    echo "🚀 Connecting to Gemini API..."
    echo "📱 Model: $model"
    echo "❓ Question: $question"
    echo ""
    echo "⏳ Streaming response (Press Ctrl+C to stop)..."
    echo ""

    # Stream the response with better error handling
    {
        curl -s -N --fail \
            -H "Content-Type: application/json" \
            -H "x-goog-api-key: $api_key" \
            -d "$json_payload" \
            "https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?alt=sse"
    } | while IFS= read -r line; do
        # Skip empty lines and non-data lines
        if [[ "$line" =~ ^data:\ (.*)$ ]]; then
            local json_data="${BASH_REMATCH[1]}"

            # Skip if it's just whitespace or [DONE]
            if [[ "$json_data" =~ ^\s*$ ]] || [[ "$json_data" == "[DONE]" ]]; then
                continue
            fi

            # Parse the JSON and extract text
            local text_chunk
            text_chunk=$(echo "$json_data" | jq -r '.candidates[]?.content?.parts[]?.text // empty' 2>/dev/null)

            if [[ -n "$text_chunk" && "$text_chunk" != "null" ]]; then
                # Append to buffer
                response_buffer+="$text_chunk"

                # Update the markdown file with proper escaping
                {
                    echo "# Gemini Response"
                    echo ""
                    echo "**Question:** $question"
                    echo ""
                    echo "**Response:**"
                    echo ""
                    echo "$response_buffer"
                } >"$temp_file"

                # Update display
                update_display
                sleep 0.1
            fi
        fi
    done

    # Final display update
    update_display

    echo ""
    echo "✅ Response complete. Press any key to exit..."

    # Fixed read command for cross-shell compatibility
    if [[ -n "$ZSH_VERSION" ]]; then
        read -k1
    else
        read -n1
    fi

    cleanup
}
