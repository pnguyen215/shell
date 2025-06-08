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
