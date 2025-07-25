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
	sentence_english=$(shell::sanitize_text "$sentence_english")
	if [ -z "$sentence_english" ]; then
		shell::colored_echo "ERR: Sentence cannot be empty." 196
		return 1
	fi
	local prompt_file="$LLM_PROMPTS_DIR/gemini/en_eval_vi_prompt_request_v1.txt"

	# Check if the prompt file exists
	if [ ! -f "$prompt_file" ]; then
		shell::colored_echo "ERR: Prompt file not found at '$prompt_file'" 196
		return 1
	fi

	# Replace the placeholder in the prompt file with the provided sentence
	# The sed command replaces {ENTER_SENTENCE_ENGLISH} in the prompt file with the actual sentence_english
	# This allows the prompt to be dynamically generated based on user input
	# local payload=$(sed "s/{ENTER_SENTENCE_ENGLISH}/$sentence_english/" "$prompt_file")
	local payload
	if jq . "$prompt_file" >/dev/null 2>&1; then
		payload=$(shell::replace_json_placeholder "$prompt_file" "{ENTER_SENTENCE_ENGLISH}" "$sentence_english")
	else
		payload=$(sed "s/{ENTER_SENTENCE_ENGLISH}/$sentence_english/g" "$prompt_file")
	fi

	# Check if payload is empty or invalid
	if [ -z "$payload" ]; then
		shell::colored_echo "ERR: Failed to generate payload from prompt template" 196
		return 1
	fi

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
	sentence_vietnamese=$(shell::sanitize_text "$sentence_vietnamese")
	if [ -z "$sentence_vietnamese" ]; then
		shell::colored_echo "ERR: Sentence cannot be empty." 196
		return 1
	fi
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

# shell::replace_json_placeholder function
# Replaces a placeholder in a JSON file with a specified value.
#
# Usage:
# shell::replace_json_placeholder <json_file> <placeholder> <replacement>
#
# Parameters:
# - <json_file> : The path to the JSON file where the placeholder will be replaced.
# - <placeholder> : The placeholder string to be replaced in the JSON file.
# - <replacement> : The value to replace the placeholder with.
#
# Description:
# This function reads a JSON file, replaces a specified placeholder with a given value,
# and returns the modified JSON. It uses jq to ensure the JSON structure remains valid.
shell::replace_json_placeholder() {
	local json_file="$1"
	local placeholder="$2"
	local replacement="$3"

	# Read the JSON template and replace placeholder using jq
	# This ensures the JSON structure remains valid
	local escaped_replacement
	escaped_replacement=$(printf '%s' "$replacement" | jq -R -s '.')

	# Remove the outer quotes from jq output since we'll be inserting into existing JSON
	escaped_replacement=$(printf '%s' "$escaped_replacement" | sed 's/^"//; s/"$//')

	# Use jq to safely replace the placeholder in the JSON structure
	jq --arg replacement "$replacement" \
		'walk(if type == "string" then gsub("'$placeholder'"; $replacement) else . end)' \
		"$json_file"
}
