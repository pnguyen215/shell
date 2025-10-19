#!/bin/bash
# strings.sh

# shell::strings::sanitize::upper function
# Converts a string into a format suitable for an environment variable name.
# Replaces non-alphanumeric characters (except underscore) with underscores,
# and converts to uppercase.
#
# Usage:
#   shell::strings::sanitize::upper <string>
#
# Parameters:
#   - <string> : The input string (e.g., INI section or key name).
#
# Returns:
#   The sanitized string suitable for a shell variable name.
#
# Example:
#   sanitized=$(shell::strings::sanitize::upper "My-Section.Key_Name") # Outputs "MY_SECTION_KEY_NAME"
shell::strings::sanitize::upper() {
	local input="$1"
	# Convert to uppercase, replace non-alphanumeric and non-underscore with underscore
	echo "$input" | tr '[:lower:]' '[:upper:]' | sed -e 's/[^A-Z0-9_]/_/g'
}

# shell::strings::sanitize::lower function
# Converts a string into a format suitable for a lower-case environment variable name.
# Replaces non-alphanumeric characters (except underscore) with underscores,
# and converts to lowercase.
#
# Usage:
#   shell::strings::sanitize::lower <string>
#
# Parameters:
#   - <string> : The input string (e.g., INI section or key name).
#
# Returns:
#   The sanitized string suitable for a lower-case shell variable name.
#
# Example:
#   sanitized=$(shell::strings::sanitize::lower "My-Section.Key_Name") # Outputs "my_section_key_name"
shell::strings::sanitize::lower() {
	local input="$1"
	# Convert to lowercase, replace non-alphanumeric and non-underscore with underscore
	echo "$input" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9_]/_/g'
}

# shell::strings::sanitize::capitalize function
# Converts a string into a format suitable for an environment variable name,
# capitalizing the first letter and replacing non-alphanumeric characters
# (except underscore) with underscores.
#
# Usage:
#   shell::strings::sanitize::capitalize <string>
#
# Parameters:
#   - <string> : The input string (e.g., INI section or key name).
#
# Returns:
#   The sanitized string suitable for a shell variable name with the first letter capitalized.
#
# Example:
#   sanitized=$(shell::strings::sanitize::capitalize "my-section.key_name") # Outputs "My_section_key_name"
shell::strings::sanitize::capitalize() {
	local input="$1"

	# Handle empty input gracefully
	if [ -z "$input" ]; then
		echo ""
		return
	fi

	local first_char_upper
	# Extract the first character and convert it to uppercase using tr.
	# tr '[:lower:]' '[:upper:]' is highly portable for case conversion.
	first_char_upper=$(echo "${input:0:1}" | tr '[:lower:]' '[:upper:]')

	# Get the rest of the string after the first character.
	local rest_of_string="${input:1}"

	# Combine the converted first character with the rest of the string.
	local temp_string="${first_char_upper}${rest_of_string}"

	# Sanitize the entire string:
	# tr -cs '[:alnum:]_' '_' does the following:
	# -c: Complements the set of characters, meaning it matches characters NOT in '[:alnum:]_'.
	#     '[:alnum:]' includes all alphanumeric characters (a-z, A-Z, 0-9).
	#     '_' is explicitly included in the set.
	# -s: Squeezes repeated output characters. This means if there are multiple consecutive
	#     non-alphanumeric/non-underscore characters (e.g., "--" or "."), they will be
	#     replaced by a single underscore.
	local sanitized_output
	sanitized_output=$(echo "$temp_string" | tr -cs '[:alnum:]_' '_')

	# Remove any leading or trailing underscores that might have been introduced by tr.
	# This uses sed to remove an underscore at the start (^) or end ($) of the string.
	echo "$sanitized_output" | sed 's/^_//;s/_$//'
}

# shell::strings::sanitize::lower_preserve function
# Converts a string into a format suitable for a lower-case environment variable name,
# making the first letter lowercase and replacing non-alphanumeric characters
# (except underscore) with underscores.
# Usage:
#   shell::strings::sanitize::lower_preserve <string>
#
# Parameters:
#   - <string> : The input string (e.g., INI section or key name).
#
# Returns:
#   The sanitized string suitable for a lower-case shell variable name with the first letter lowercase.
#
# Example:
#   sanitized=$(shell::strings::sanitize::lower_preserve "My-Section.Key_Name") # Outputs "my_section_key_name"
shell::strings::sanitize::lower_preserve() {
	local input="$1"

	# Handle empty input gracefully
	if [ -z "$input" ]; then
		echo ""
		return
	fi

	local lowercased_string
	# Convert the entire input string to lowercase first to match the example's desired output
	# (all characters after the first are also lowercased if they were uppercase).
	lowercased_string=$(echo "$input" | tr '[:upper:]' '[:lower:]')

	# Sanitize the lowercased string using the same robust tr command:
	# - Replaces all non-alphanumeric and non-underscore characters with a single underscore.
	local sanitized_output
	sanitized_output=$(echo "$lowercased_string" | tr -cs '[:alnum:]_' '_')

	# Remove any leading or trailing underscores that might have been introduced by tr.
	echo "$sanitized_output" | sed 's/^_//;s/_$//'
}

# shell::camel_case function
# Converts a string into CamelCase format.
# Removes non-alphanumeric characters, splits by underscores, and capitalizes
# the first letter of each word.
# Usage:
#   shell::camel_case <string>
#
# Parameters:
#   - <string> : The input string (e.g., INI section or key name).
#
# Returns:
#   The CamelCase formatted string.
# Example:
#   camel_case=$(shell::camel_case "my-section.key_name") # Outputs "MySectionKeyName"
shell::camel_case() {
	local input="$1"
	# Remove non-alphanumeric characters, split by underscores, capitalize first letter of each word
	echo "$input" | sed -e 's/[^a-zA-Z0-9_]/ /g' -e 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1' | tr -d ' '
}

# shell::capitalize_each_word function
# Capitalizes the first letter of each word in a space-separated string.
#
# Usage:
#   shell::capitalize_each_word <string>
#
# Parameters:
#   - <string> : The input string (e.g., "my section key name").
#
# Returns:
#   The string with the first letter of each word capitalized.
#
# Example:
#   capitalized=$(shell::capitalize_each_word "my section key name") # Outputs "My Section Key Name"
shell::capitalize_each_word() {
	if [ $# -ne 1 ]; then
		echo "Usage: shell::capitalize_each_word <string>"
		return 1
	fi

	local input="$1"
	local output_string=""

	# Check if input is empty
	# If input is empty, return an empty string
	[ -z "$input" ] && echo "" && return

	# Use a while-read loop for better word splitting and IFS safety
	# IFS is set to read words separated by spaces
	while IFS= read -r -d ' ' word || [ -n "$word" ]; do
		if [ -n "$word" ]; then
			# Capitalize first letter and append rest
			first_char=$(printf "%s" "${word:0:1}" | tr '[:lower:]' '[:upper:]')
			rest="${word:1}"
			output_string+="${first_char}${rest} "
		fi
	done <<<"${input} "

	# Trim trailing space
	echo "${output_string%" "}"
}

# shell::sanitize_text function
# Sanitizes a text string for safe use in shell scripts and JSON.
# It escapes special characters, removes newlines and tabs, and trims whitespace.
# Usage:
#   shell::sanitize_text <text>
#
# Parameters:
#   - <text> : The input text to sanitize.
# Description:
#   This function performs the following sanitization steps:
#   1. Escapes backslashes, forward slashes, double quotes, and single quotes.
#   2. Replaces newlines with a space and removes extra spaces.
#   3. Replaces tabs with spaces.
#   4. Trims leading and trailing whitespace.
#   5. Returns the sanitized text.
#
# Returns:
#   The sanitized text string.
shell::sanitize_text() {
	local input_text="$1"
	# Escape special characters for sed and JSON safety
	# 1. Escape backslashes first (must be done before other escapes)
	# 2. Escape forward slashes for sed
	# 3. Escape double quotes for JSON
	# 4. Escape single quotes for shell safety
	# 5. Remove or escape newlines and tabs
	# 6. Handle other problematic characters

	local sanitized_text="$input_text"

	# Escape backslashes first
	sanitized_text=$(printf '%s\n' "$sanitized_text" | sed 's/\\/\\\\/g')

	# Escape forward slashes for sed
	sanitized_text=$(printf '%s\n' "$sanitized_text" | sed 's/\//\\\//g')

	# Escape double quotes
	sanitized_text=$(printf '%s\n' "$sanitized_text" | sed 's/"/\\"/g')

	# Escape single quotes by replacing with '\''
	sanitized_text=$(printf '%s\n' "$sanitized_text" | sed "s/'/'\\\\''/g")

	# Replace newlines with literal \n
	sanitized_text=$(printf '%s\n' "$sanitized_text" | tr '\n' ' ' | sed 's/  */ /g')

	# Replace tabs with spaces
	sanitized_text=$(printf '%s\n' "$sanitized_text" | tr '\t' ' ')

	# Trim leading and trailing whitespace
	sanitized_text=$(printf '%s\n' "$sanitized_text" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

	printf '%s' "$sanitized_text"
}
