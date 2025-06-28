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

    # Check if API_KEY and MODEL are set in the Gemini config file
    if [ -z "$api_key" ]; then
        shell::colored_echo "ERR: API_KEY config not found in Gemini config file ($SHELL_KEY_CONF_AGENT_GEMINI_FILE)." 196
        return 1
    fi
    if [ -z "$model" ]; then
        shell::colored_echo "ERR: MODEL config not found in Gemini config file ($SHELL_KEY_CONF_AGENT_GEMINI_FILE)." 196
        return 1
    fi

    local url="https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${api_key}"
    local prompt_request="$LLM_PROMPTS_DIR/gemini/english_translation_tutor_request.txt"
    local payload=$(sed "s/{ENTER_SENTENCE_ENGLISH}/$sentence_english/" "$prompt_request")

    # Check if the prompt file exists
    if [ ! -f "$prompt_request" ]; then
        shell::colored_echo "ERR: Prompt file not found at '$prompt_request'" 196
        return 1
    fi

    local curl_cmd="curl -s -X POST \"$url\" -H \"Content-Type: application/json\" -d '$payload'"

    # Check if the dry-run is enabled
    # If dry_run is true, it will print the curl command instead of executing it
    # This is useful for debugging or testing purposes
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$curl_cmd"
        return 0
    fi

    local response
    response=$(eval "$curl_cmd")

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
    # Check if the response contains candidates
    # if ! echo "$response" | jq -e '.candidates' >/dev/null 2>&1; then
    #     shell::colored_echo "ERR: No candidates found in Gemini API response." 196
    #     return 1
    # fi

    local correction
    correction=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text' | jq -r '.[0].suggested_correction')

    local examples
    examples=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text' | jq -r '.[0].example_sentences[] | "\(.en) (\(.vi))"')

    shell::colored_echo "INFO: Suggested Correction:" 46
    echo "$correction" | fzf --prompt="Correction: "

    shell::colored_echo "INFO: Example Sentences:" 46
    echo "$examples" | fzf --multi --prompt="Examples: "
}
