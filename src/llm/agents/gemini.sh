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

    #     echo "BEFORE RESPONSE: $response"

    #     # Extract the text field content between quotes, handling multiline content
    #     local raw_text
    #     raw_text=$(echo "$response" | python3 -c "
    # import json
    # import sys

    # try:
    #     data = json.load(sys.stdin)
    #     text_content = data['candidates'][0]['content']['parts'][0]['text']
    #     print(text_content)
    # except Exception as e:
    #     print('', file=sys.stderr)
    #     sys.exit(1)
    # ")

    #     # Check if extraction failed
    #     if [ $? -ne 0 ] || [ -z "$raw_text" ]; then
    #         shell::colored_echo "ERR: Could not extract text field using Python JSON parser." 196

    #         # Fallback: manual extraction using sed/awk
    #         shell::colored_echo "INFO: Attempting manual text extraction..." 244
    #         raw_text=$(echo "$response" | sed -n '/"text":/,/"role":/p' | sed '1s/.*"text": *"//; $s/".*//; $d' | sed 's/\\n/\n/g; s/\\"/"/g')

    #         if [ -z "$raw_text" ]; then
    #             shell::colored_echo "ERR: Manual extraction also failed." 196
    #             return 1
    #         fi
    #     fi

    #     shell::colored_echo "DEBUG: Successfully extracted text field" 46

    #     # Now parse the extracted text as JSON
    #     local parsed_json
    #     parsed_json=$(echo "$raw_text" | jq . 2>/dev/null)

    #     # Check if parsing was successful
    #     if [ $? -ne 0 ] || [ -z "$parsed_json" ] || [ "$parsed_json" = "null" ]; then
    #         shell::colored_echo "ERR: Failed to parse extracted text as JSON." 196
    #         shell::colored_echo "DEBUG: Text preview (first 300 chars):" 244
    #         echo "$raw_text"
    #         echo "..."
    #         return 1
    #     fi

    #     shell::colored_echo "INFO: Successfully parsed JSON content" 46

    #     # Extract correction and examples from the parsed JSON
    #     local correction
    #     correction=$(echo "$parsed_json" | jq -r '.[0].suggested_correction // empty')

    #     if [ -z "$correction" ]; then
    #         shell::colored_echo "WARN: No suggested_correction found, trying alternative field names" 244
    #         correction=$(echo "$parsed_json" | jq -r '.[0].correction // .[0].suggestion // "No correction found"')
    #     fi

    #     local examples
    #     examples=$(echo "$parsed_json" | jq -r '.[0].example_sentences[]? // empty | "\(.en // .english // .) (\(.vi // .vietnamese // .))"' 2>/dev/null)

    #     if [ -z "$examples" ]; then
    #         shell::colored_echo "WARN: No example_sentences found, trying alternative structure" 244
    #         examples=$(echo "$parsed_json" | jq -r '.[] | select(.examples) | .examples[] | "\(.en // .english // .) (\(.vi // .vietnamese // .))"' 2>/dev/null)
    #     fi

    #     # Display the results
    #     if [ -n "$correction" ]; then
    #         shell::colored_echo "INFO: Suggested Correction:" 46
    #         echo "$correction" | fzf --prompt="Correction: " --height=10 --layout=reverse
    #     else
    #         shell::colored_echo "WARN: No correction found in response" 244
    #     fi

    #     if [ -n "$examples" ]; then
    #         shell::colored_echo "INFO: Example Sentences:" 46
    #         echo "$examples" | fzf --multi --prompt="Examples: " --height=40% --layout=reverse
    #     else
    #         shell::colored_echo "WARN: No examples found in response" 244
    #         shell::colored_echo "INFO: Full parsed JSON structure:" 244
    #         echo "$parsed_json" | jq .
    #     fi

    echo "BEFORE RESPONSE: $response"

    # Extract the text field content and properly escape it as JSON
    local raw_text
    raw_text=$(echo "$response" | python3 -c "
import json
import sys

try:
    data = json.load(sys.stdin)
    text_content = data['candidates'][0]['content']['parts'][0]['text']
    # Parse the text content as JSON and re-output it properly formatted
    parsed_content = json.loads(text_content)
    print(json.dumps(parsed_content, ensure_ascii=False, indent=2))
except Exception as e:
    print('PYTHON_PARSE_FAILED', file=sys.stderr)
    sys.exit(1)
")

    # Check if Python parsing succeeded
    if [ $? -eq 0 ] && [ -n "$raw_text" ]; then
        shell::colored_echo "DEBUG: Successfully extracted and parsed text using Python" 46
        parsed_json="$raw_text"
    else
        shell::colored_echo "INFO: Python parsing failed, attempting manual extraction and escaping..." 244

        # Manual extraction: get the raw text content between "text": and "role":
        local extracted_text
        extracted_text=$(echo "$response" | awk '
            BEGIN { 
                in_text = 0
                text_lines = ""
                found_start = 0
            }
            /"text": *"/ {
                in_text = 1
                found_start = 1
                # Get everything after "text": "
                sub(/.*"text": *"/, "")
                text_lines = $0
                next
            }
            in_text && /"role":/ {
                # End of text field - remove trailing quote
                gsub(/"[[:space:]]*$/, "", text_lines)
                print text_lines
                exit
            }
            in_text {
                text_lines = text_lines "\n" $0
            }
            END {
                if (found_start && !in_text) {
                    gsub(/"[[:space:]]*$/, "", text_lines)
                    print text_lines
                }
            }
        ')

        if [ -z "$extracted_text" ]; then
            shell::colored_echo "ERR: Failed to extract text content." 196
            return 1
        fi

        # Convert escaped characters and create properly formatted JSON
        local processed_text
        processed_text=$(echo "$extracted_text" | python3 -c "
import sys
import json

try:
    # Read the raw text
    raw_content = sys.stdin.read().strip()
    
    # Handle the double-escaped quotes and other escape sequences
    # First pass: convert literal escape sequences
    processed = raw_content.replace('\\\\n', '\n')
    processed = processed.replace('\\\\\"', '\"')  
    processed = processed.replace('\\\\\\\\', '\\\\')
    
    # Second pass: handle the remaining escaped quotes in the content
    processed = processed.replace('\\\"', '\"')
    
    # Try to parse as JSON
    parsed = json.loads(processed)
    
    # Output properly formatted JSON
    print(json.dumps(parsed, ensure_ascii=False, indent=2))
    
except json.JSONDecodeError as e:
    # If JSON parsing fails, try to fix common issues
    try:
        # Remove any trailing characters that might be breaking the JSON
        lines = raw_content.strip().split('\n')
        # Find the last line that looks like it ends the JSON structure
        for i in range(len(lines)-1, -1, -1):
            if '}]' in lines[i]:
                processed_lines = lines[:i+1]
                break
        else:
            processed_lines = lines
            
        cleaned_content = '\n'.join(processed_lines)
        
        # Clean up the content
        cleaned_content = cleaned_content.replace('\\\\n', '\n')
        cleaned_content = cleaned_content.replace('\\\\\"', '\"')
        cleaned_content = cleaned_content.replace('\\\"', '\"')
        
        parsed = json.loads(cleaned_content)
        print(json.dumps(parsed, ensure_ascii=False, indent=2))
        
    except Exception as e2:
        print(f'JSON Error: {e}', file=sys.stderr)
        print(f'Retry Error: {e2}', file=sys.stderr)
        sys.exit(1)
        
except Exception as e:
    print(f'General Error: {e}', file=sys.stderr)
    sys.exit(1)
")

        if [ $? -eq 0 ] && [ -n "$processed_text" ]; then
            shell::colored_echo "DEBUG: Successfully processed text manually" 46
            parsed_json="$processed_text"
        else
            shell::colored_echo "ERR: Failed to process extracted text as JSON." 196
            shell::colored_echo "DEBUG: Raw extracted text (first 300 chars):" 244
            echo "$extracted_text" | head -c 300
            echo "..."
            return 1
        fi
    fi

    shell::colored_echo "INFO: Successfully parsed JSON content" 46

    # Extract correction and examples from the parsed JSON
    local correction
    correction=$(echo "$parsed_json" | jq -r '.[0].suggested_correction // empty')

    if [ -z "$correction" ]; then
        shell::colored_echo "WARN: No suggested_correction found, trying alternative field names" 244
        correction=$(echo "$parsed_json" | jq -r '.[0].correction // .[0].suggestion // "No correction found"')
    fi

    local examples
    examples=$(echo "$parsed_json" | jq -r '.[0].example_sentences[]? // empty | "\(.en // .english // .) (\(.vi // .vietnamese // .))"' 2>/dev/null)

    if [ -z "$examples" ]; then
        shell::colored_echo "WARN: No example_sentences found, trying alternative structure" 244
        examples=$(echo "$parsed_json" | jq -r '.[] | select(.examples) | .examples[] | "\(.en // .english // .) (\(.vi // .vietnamese // .))"' 2>/dev/null)
    fi

    # Display the results
    if [ -n "$correction" ]; then
        shell::colored_echo "INFO: Suggested Correction:" 46
        echo "$correction" | fzf --prompt="Correction: " --height=10 --layout=reverse
    else
        shell::colored_echo "WARN: No correction found in response" 244
    fi

    if [ -n "$examples" ]; then
        shell::colored_echo "INFO: Example Sentences:" 46
        echo "$examples" | fzf --multi --prompt="Examples: " --height=40% --layout=reverse
    else
        shell::colored_echo "WARN: No examples found in response" 244
        shell::colored_echo "INFO: Full parsed JSON structure:" 244
        echo "$parsed_json" | jq .
    fi
}
