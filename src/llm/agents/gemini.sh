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

    echo "BEFORE RESPONSE: $response"

    # Improved JSON parsing section for shell::gemini_learn_english function
    # Replace the existing JSON parsing logic with this improved version

    # Extract and parse the nested JSON from Gemini response
    local parsed_json
    parsed_json=$(echo "$response" | python3 -c "
import json
import sys

try:
    # Load the main response JSON
    data = json.load(sys.stdin)
    
    # Extract the text content from the nested structure
    text_content = data['candidates'][0]['content']['parts'][0]['text']
    
    # The text_content is a JSON string that needs to be parsed
    # It's already properly escaped, so we can parse it directly
    parsed_content = json.loads(text_content)
    
    # Output the parsed content as properly formatted JSON
    print(json.dumps(parsed_content, ensure_ascii=False, indent=2))
    
except KeyError as e:
    print(f'KeyError: Missing expected field {e}', file=sys.stderr)
    sys.exit(1)
except json.JSONDecodeError as e:
    print(f'JSONDecodeError: {e}', file=sys.stderr)
    # Print the problematic text for debugging
    try:
        data = json.load(sys.stdin)
        text_content = data['candidates'][0]['content']['parts'][0]['text']
        print(f'Problematic text (first 500 chars): {text_content[:500]}', file=sys.stderr)
    except:
        pass
    sys.exit(1)
except Exception as e:
    print(f'Unexpected error: {e}', file=sys.stderr)
    sys.exit(1)
")

    # Check if Python parsing succeeded
    if [ $? -ne 0 ] || [ -z "$parsed_json" ]; then
        shell::colored_echo "ERR: Failed to parse JSON response from Gemini API." 196
        shell::colored_echo "DEBUG: Raw response (first 500 chars):" 244
        echo "$response"
        echo "...ENDING"
        return 1
    fi

    shell::colored_echo "INFO: Successfully parsed JSON content" 46

    # Extract correction and examples from the parsed JSON
    local correction
    correction=$(echo "$parsed_json" | jq -r '.[0].suggested_correction // empty')

    if [ -z "$correction" ]; then
        shell::colored_echo "WARN: No suggested_correction found" 244
        correction="No correction available"
    fi

    # Extract examples with better error handling
    local examples
    examples=$(echo "$parsed_json" | jq -r '
    try (
        .[0].example_sentences[] | 
        "\(.en // .english // "No English text") (\(.vi // .vietnamese // "No Vietnamese text"))"
    ) catch "No examples available"
' 2>/dev/null)

    # Display the results
    shell::colored_echo "INFO: Suggested Correction:" 46
    echo "$correction" | fzf --prompt="Correction: " --height=10 --layout=reverse --no-multi

    if [ "$examples" != "No examples available" ] && [ -n "$examples" ]; then
        shell::colored_echo "INFO: Example Sentences:" 46
        echo "$examples" | fzf --multi --prompt="Examples: " --height=40% --layout=reverse
    else
        shell::colored_echo "WARN: No examples found in response" 244
        # Show additional fields that might be available
        shell::colored_echo "INFO: Available fields in response:" 244
        echo "$parsed_json" | jq -r '.[0] | keys[]' 2>/dev/null | head -10
    fi

    # Optional: Display grammar explanation if available
    local grammar_explanation
    grammar_explanation=$(echo "$parsed_json" | jq -r '.[0].grammar_explanation // empty' 2>/dev/null)

    if [ -n "$grammar_explanation" ]; then
        shell::colored_echo "INFO: Grammar Explanation:" 46
        echo "$grammar_explanation" | fold -w 80 -s
    fi
}

# unescape_json_string: Unescapes a JSON-escaped string.
# This function reverses the process of JSON escaping, converting sequences
# like `\"`, `\\`, `\n`, `\t`, and `\uXXXX` back into their literal characters.
#
# Arguments:
#   $1 - The JSON-escaped string to unescape.
#
# Output:
#   The unescaped string is printed to standard output.
#
# Example:
#   escaped_text="Hello\\nWorld!\\\""
#   unescaped_text=$(unescape_json_string "$escaped_text")
#   echo "$unescaped_text" # Output: Hello
#                         #         World!"
#
#   unicode_escaped="Test\\u0041\\u0008Finished" # \u0041 is 'A', \u0008 is backspace
#   unescaped_unicode=$(unescape_json_string "$unicode_escaped")
#   echo "$unescaped_unicode" # Output: TestA(backspace)Finished (backspace character will be inserted)
unescape_json_string() {
    local input="$1"
    local output=""
    local i=0
    local len=${#input}

    while [ "$i" -lt "$len" ]; do
        local char="${input:i:1}" # Get current character

        if [ "$char" = "\\" ]; then
            # Found a backslash, indicating a potential escape sequence
            i=$((i + 1)) # Move to the character after the backslash

            # Check if the backslash is at the end of the string
            if [ "$i" -ge "$len" ]; then
                output+="\\" # Treat as a literal backslash
                break        # End of string
            fi

            local next_char="${input:i:1}" # Get the character after the backslash
            case "$next_char" in
            '"') output+='"' ;;   # Unescape double quote
            '\') output+='\' ;;   # Unescape backslash
            '/') output+='/' ;;   # Unescape solidus (forward slash), though optional in JSON
            'b') output+=$'\b' ;; # Unescape backspace
            'f') output+=$'\f' ;; # Unescape form feed
            'n') output+=$'\n' ;; # Unescape newline
            'r') output+=$'\r' ;; # Unescape carriage return
            't') output+=$'\t' ;; # Unescape tab
            'u')
                # Handle Unicode escape sequence \uXXXX
                # Ensure there are enough characters for the 4-digit hex code
                if [ "$((i + 4))" -lt "$len" ]; then
                    local hex_code="${input:i+1:4}" # Extract the 4 hex digits
                    # Basic validation for hex code (optional but recommended)
                    if [[ "$hex_code" =~ ^[0-9a-fA-F]{4}$ ]]; then
                        # Convert hex code to the corresponding Unicode character
                        # This uses bash's internal printf, which supports \uXXXX for output
                        printf -v unicode_char "\u${hex_code}"
                        output+="$unicode_char"
                        i=$((i + 4)) # Move past the 4 hex digits
                    else
                        # Invalid hex code format, treat as literal \u and the invalid part
                        output+="\\u${hex_code}"
                        i=$((i + 4)) # Still consume the 4 characters to avoid infinite loop
                    fi
                else
                    # Incomplete \u escape sequence, treat as literal \u and any remaining characters
                    output+="\\u${input:i+1}"
                    i=$((len)) # Advance cursor to the end of the string
                fi
                ;;
            *)
                # Unrecognized escape sequence, treat as literal backslash and the next character
                output+="\\$next_char"
                ;;
            esac
        else
            # Not a backslash, append the character directly
            output+="$char"
        fi
        i=$((i + 1)) # Move to the next character in the input string
    done
    echo "$output" # Print the final unescaped string
}
