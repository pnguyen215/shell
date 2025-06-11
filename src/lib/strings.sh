#!/bin/bash
# strings.sh

# shell::sanitize_upper_var_name function
# Converts a string into a format suitable for an environment variable name.
# Replaces non-alphanumeric characters (except underscore) with underscores,
# and converts to uppercase.
#
# Usage:
#   shell::sanitize_upper_var_name <string>
#
# Parameters:
#   - <string> : The input string (e.g., INI section or key name).
#
# Returns:
#   The sanitized string suitable for a shell variable name.
#
# Example:
#   sanitized=$(shell::sanitize_upper_var_name "My-Section.Key_Name") # Outputs "MY_SECTION_KEY_NAME"
shell::sanitize_upper_var_name() {
    local input="$1"
    # Convert to uppercase, replace non-alphanumeric and non-underscore with underscore
    echo "$input" | tr '[:lower:]' '[:upper:]' | sed -e 's/[^A-Z0-9_]/_/g'
}

# shell::sanitize_lower_var_name function
# Converts a string into a format suitable for a lower-case environment variable name.
# Replaces non-alphanumeric characters (except underscore) with underscores,
# and converts to lowercase.
#
# Usage:
#   shell::sanitize_lower_var_name <string>
#
# Parameters:
#   - <string> : The input string (e.g., INI section or key name).
#
# Returns:
#   The sanitized string suitable for a lower-case shell variable name.
#
# Example:
#   sanitized=$(shell::sanitize_lower_var_name "My-Section.Key_Name") # Outputs "my_section_key_name"
shell::sanitize_lower_var_name() {
    local input="$1"
    # Convert to lowercase, replace non-alphanumeric and non-underscore with underscore
    echo "$input" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9_]/_/g'
}

# shell::sanitize_first_upper_var_name function
# Converts a string into a format suitable for an environment variable name,
# capitalizing the first letter and replacing non-alphanumeric characters
# (except underscore) with underscores.
#
# Usage:
#   shell::sanitize_first_upper_var_name <string>
#
# Parameters:
#   - <string> : The input string (e.g., INI section or key name).
#
# Returns:
#   The sanitized string suitable for a shell variable name with the first letter capitalized.
#
# Example:
#   sanitized=$(shell::sanitize_first_upper_var_name "my-section.key_name") # Outputs "My_section_key_name"
shell::sanitize_first_upper_var_name() {
    local input="$1"
    # Convert first character to uppercase, replace non-alphanumeric and non-underscore with underscore
    echo "$input" | sed -e 's/^\(.\)/\U\1/' -e 's/[^A-Z0-9_]/_/g'
}

# shell::sanitize_first_lower_var_name function
# Converts a string into a format suitable for a lower-case environment variable name,
# making the first letter lowercase and replacing non-alphanumeric characters
# (except underscore) with underscores.
# Usage:
#   shell::sanitize_first_lower_var_name <string>
#
# Parameters:
#   - <string> : The input string (e.g., INI section or key name).
#
# Returns:
#   The sanitized string suitable for a lower-case shell variable name with the first letter lowercase.
#
# Example:
#   sanitized=$(shell::sanitize_first_lower_var_name "My-Section.Key_Name") # Outputs "my_section_key_name"
shell::sanitize_first_lower_var_name() {
    local input="$1"
    # Convert first character to lowercase, replace non-alphanumeric and non-underscore with underscore
    echo "$input" | sed -e 's/^\(.\)/\L\1/' -e 's/[^a-z0-9_]/_/g'
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
