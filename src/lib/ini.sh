#!/bin/bash
# ini.sh

# shell::ini_read function
# Reads the value of a specified key from a given section in an INI file.
#
# Usage:
#   shell::ini_read <file> <section> <key>
#
# Parameters:
#   - <file>    : The path to the INI file.
#   - <section> : The section within the INI file to search.
#   - <key>     : The key within the section whose value is to be retrieved.
#
# Description:
#   This function reads an INI file and retrieves the value associated with a
#   specified key within a given section. It validates the presence of the file,
#   section, and key, and applies strict validation rules if SHELL_INI_STRICT is set.
#   The function handles comments, empty lines, and quoted values within the INI file.
#
# Example:
#   shell::ini_read config.ini MySection MyKey  # Retrieves the value of MyKey in MySection.
#
# Returns:
#   The value of the specified key if found, or an error message if the key is not found.
#
# Notes:
#   - Relies on the shell::colored_echo function for output.
#   - The behavior is controlled by the SHELL_INI_STRICT environment variable.
shell::ini_read() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_READ"
        return 0
    fi

    local file="$1"
    local section="$2"
    local key="$3"

    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ] || [ -z "$key" ]; then
        shell::colored_echo "shell::ini_read: Missing required parameters" 196
        return 1
    fi

    # Validate section and key names only if strict mode is enabled
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::ini_validate_section_name "$section" || return 1
        shell::ini_validate_key_name "$key" || return 1
    fi

    # Check if file exists
    if [ ! -f "$file" ]; then
        shell::colored_echo "File not found: $file" 196
        return 1
    fi

    # Escape section and key for regex pattern
    local escaped_section
    escaped_section=$(shell::ini_escape_for_regex "$section")
    local escaped_key
    escaped_key=$(shell::ini_escape_for_regex "$key")

    local section_pattern="^\[$escaped_section\]"
    local in_section=0

    shell::colored_echo "Reading key '$key' from section '$section' in file: $file" 11

    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*[#\;] ]]; then
            continue
        fi

        # Check for section
        if [[ "$line" =~ $section_pattern ]]; then
            in_section=1
            # shell::colored_echo "Found section: $section" 11
            continue
        fi

        # Check if we've moved to a different section
        if [[ $in_section -eq 1 && "$line" =~ ^\[[^]]+\] ]]; then
            shell::colored_echo "Reached end of section without finding key" 11
            return 1
        fi

        # Check for key in the current section
        if [[ $in_section -eq 1 ]]; then
            local key_pattern="^[[:space:]]*${escaped_key}[[:space:]]*="
            if [[ "$line" =~ $key_pattern ]]; then
                local value="${line#*=}"
                # Trim whitespace
                value=$(shell::ini_trim "$value")

                # Check for quoted values
                if [[ "$value" =~ ^\"(.*)\"$ ]]; then
                    # Remove the quotes
                    value="${BASH_REMATCH[1]}"
                    # Handle escaped quotes within the value
                    value="${value//\\\"/\"}"
                fi

                # shell::colored_echo "Found value: $value" 11
                echo "$value"
                return 0
            fi
        fi
    done <"$file"

    shell::colored_echo "Key not found: $key in section: $section" 11
    return 1
}

# shell::ini_validate_section_name function
# Validates an INI section name based on defined strictness levels.
# It checks for empty names and disallowed characters or spaces according to
# SHELL_INI_STRICT and SHELL_INI_ALLOW_SPACES_IN_NAMES variables.
#
# Usage:
#   shell::ini_validate_section_name <section_name>
#
# Parameters:
#   <section_name> : The name of the INI section to validate.
#
# Description:
#   This function takes a section name as input and applies validation rules.
#   An empty section name is always considered invalid.
#   If SHELL_INI_STRICT is set to 1, the function checks for the presence of
#   illegal characters: square brackets (`[` and `]`) and the equals sign (`=`).
#   If SHELL_INI_ALLOW_SPACES_IN_NAMES is set to 0, the function checks for
#   the presence of spaces within the section name.
#   Error messages are displayed using the shell::colored_echo function.
#
# Example usage:
#   # Assuming SHELL_INI_STRICT=1 and SHELL_INI_ALLOW_SPACES_IN_NAMES=0
#   shell::ini_validate_section_name "MySection"   # Valid
#   shell::ini_validate_section_name "My Section"  # Invalid (contains space)
#   shell::ini_validate_section_name "My[Section]" # Invalid (contains illegal character)
#   shell::ini_validate_section_name ""            # Invalid (empty)
#
# Returns:
#   0 if the section name is valid, 1 otherwise.
#
# Notes:
#   - Relies on the shell::colored_echo function for output.
#   - The behavior is controlled by the SHELL_INI_STRICT and
#     SHELL_INI_ALLOW_SPACES_IN_NAMES environment variables or constants.
shell::ini_validate_section_name() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_VALIDATE_SECTION_NAME"
        return 0
    fi

    local section="$1"

    if [ -z "$section" ]; then
        shell::colored_echo "🔴 Section name cannot be empty" 196
        return 1
    fi

    # Check for illegal characters if strict mode is enabled.
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        # Check for illegal characters in section name: [, ], = using case for portability
        case "$section" in
        *\[* | *\]* | *=*)
            # If the section contains [, ], or =, it's illegal
            shell::colored_echo "🔴 Section name contains illegal characters: $section" 196
            return 1
            ;;
        *)
            # No illegal characters found
            ;;
        esac
    fi

    # Check for spaces in section name if spaces are not allowed.
    # The [[ ... =~ ... ]] for spaces works in Zsh too with [[:space:]]
    # Alternatively, could use case: *[[:space:]]*)
    if [ "${SHELL_INI_ALLOW_SPACES_IN_NAMES}" -eq 0 ] && [[ "$section" =~ [[:space:]] ]]; then
        shell::colored_echo "🔴 Section name contains spaces: $section" 196
        return 1
    fi

    return 0
}

# shell::ini_validate_key_name function
# Validates an INI key name based on defined strictness levels.
# It checks for empty names and disallowed characters or spaces according to
# SHELL_INI_STRICT and SHELL_INI_ALLOW_SPACES_IN_NAMES variables.

# Usage:
#   shell::ini_validate_key_name [-h] <key_name>

# Parameters:
#   - -h         : Optional. Displays this help message.
#   - <key_name> : The name of the INI key to validate.

# Returns:
#   0 if the key name is valid, 1 otherwise.

# Notes:
#   - Relies on the shell::colored_echo function for output.
#   - The behavior is controlled by the SHELL_INI_STRICT and
#     SHELL_INI_ALLOW_SPACES_IN_NAMES environment variables or constants.
shell::ini_validate_key_name() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_VALIDATE_KEY_NAME"
        return 0
    fi

    local key="$1"

    if [ -z "$key" ]; then
        shell::colored_echo "🔴 Key name cannot be empty" 196
        return 1
    fi

    # Check for illegal characters if strict mode is enabled.
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        # Check for illegal characters in key name: [, ], = using case for portability
        case "$key" in
        *\[* | *\]* | *=*)
            # If the key contains [, ], or =, it's illegal
            shell::colored_echo "🔴 Key name contains illegal characters: $key" 196
            return 1
            ;;
        *)
            # No illegal characters found
            ;;
        esac
    fi

    # Check for spaces in key name if spaces are not allowed.
    # The [[ ... =~ ... ]] for spaces works in Zsh too with [[:space:]]
    # Alternatively, could use case: *[[:space:]]*)
    if [ "${SHELL_INI_ALLOW_SPACES_IN_NAMES}" -eq 0 ] && [[ "$key" =~ [[:space:]] ]]; then
        shell::colored_echo "🔴 Key name contains spaces: $key" 196
        return 1
    fi

    return 0
}

# shell::ini_create_temp_file function
# Creates a temporary file with a unique name in the system's temporary directory.
#
# Usage:
#   shell::ini_create_temp_file
#
# Returns:
#   The path to the newly created temporary file.
#
# Description:
#   This function generates a temporary file using the mktemp command.
#   The file is created in the directory specified by the TMPDIR environment variable,
#   or in /tmp if TMPDIR is not set. The filename is prefixed with 'shell_ini_' and
#   followed by a series of random characters to ensure uniqueness.
#
# Example:
#   temp_file=$(shell::ini_create_temp_file)  # Creates a temporary file and stores its path in temp_file.
shell::ini_create_temp_file() {
    mktemp "${TMPDIR:-/tmp}/shell_ini_XXXXXXXXXX"
}

# shell::ini_trim function
# Trims leading and trailing whitespace from a given string.
#
# Usage:
#   shell::ini_trim <string>
#
# Parameters:
#   - <string> : The string from which to remove leading and trailing whitespace.
#
# Returns:
#   The trimmed string with no leading or trailing whitespace.
#
# Description:
#   This function takes a string as input and removes any leading and trailing
#   whitespace characters. It uses parameter expansion to efficiently trim
#   the whitespace and then outputs the cleaned string.
#
# Example:
#   trimmed_string=$(shell::ini_trim "  example string  ")  # Outputs "example string"
shell::ini_trim() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_TRIM"
        return 0
    fi

    local var="$*"
    # Remove leading whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    # Remove trailing whitespace
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

# shell::ini_escape_for_regex function
# Escapes special characters in a string for regex matching.
#
# Usage:
#   shell::ini_escape_for_regex <string>
#
# Parameters:
#   - <string> : The string in which to escape special regex characters.
#
# Returns:
#   The string with special regex characters escaped.
#
# Description:
#   This function takes a string as input and escapes special characters
#   that are used in regular expressions. It uses the sed command to
#   prepend a backslash to each special character, ensuring the string
#   can be safely used in regex operations.
#
# Example:
#   escaped_string=$(shell::ini_escape_for_regex "example(string)")  # Outputs "example\(string\)"
shell::ini_escape_for_regex() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_ESCAPE_FOR_REGEX"
        return 0
    fi

    echo "$1" | sed -e 's/[]\/()$*.^|[]/\\&/g'
}

# shell::ini_check_file function
# Validates the existence and write ability of a specified file, creating it if necessary.
#
# Usage:
#   shell::ini_check_file <file>
#
# Parameters:
#   - <file> : The path to the file to check or create.
#
# Description:
#   This function checks if a specified file exists and is writable. If the file does not exist,
#   it attempts to create the file and its parent directory if necessary. It ensures the file
#   is writable before returning success. If any step fails, it outputs an error message and
#   returns a non-zero status.
#
# Example:
#   shell::ini_check_file /path/to/config.ini  # Checks or creates the file at the specified path.
shell::ini_check_file() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_CHECK_FILE"
        return 0
    fi

    local file="$1"

    # Check if file parameter is provided
    if [ -z "$file" ]; then
        shell::colored_echo "File path is required" 196
        return 1
    fi

    # Check if file exists
    if [ ! -f "$file" ]; then
        shell::colored_echo "File does not exist, attempting to create: $file" 11
        # Create directory if it doesn't exist
        local dir
        dir=$(dirname "$file")
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir" 2>/dev/null || {
                shell::colored_echo "Could not create directory: $dir" 196
                return 1
            }
        fi

        # Create the file
        if ! touch "$file" 2>/dev/null; then
            shell::colored_echo "Could not create file: $file" 196
            return 1
        fi
        shell::colored_echo "File created successfully: $file" 46
    fi

    # Check if file is writable
    if [ ! -w "$file" ]; then
        shell::colored_echo "File is not writable: $file" 196
        return 1
    fi

    return 0
}

# shell::ini_list_sections function
# Lists all section names from a given INI file.
#
# Usage:
#   shell::ini_list_sections [-h] <file>
#
# Parameters:
#   - -h     : Optional. Displays this help message.
#   - <file> : The path to the INI file.
#
# Description:
#   This function reads an INI file and extracts all section names.
#   It validates the presence of the file and outputs the section names
#   without the enclosing square brackets.
#
# Example:
#   shell::ini_list_sections config.ini  # Lists all sections in config.ini.
#
# Returns:
#   0 on success, 1 if the file is missing or not found.
#
# Notes:
#   - Relies on the shell::colored_echo function for output.
shell::ini_list_sections() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_LIST_SECTIONS"
        return 0
    fi

    local file="$1"

    # Validate parameters
    if [ -z "$file" ]; then
        shell::colored_echo "shell::ini_list_sections: Missing file parameter" 196
        return 1
    fi

    # Check if file exists
    if [ ! -f "$file" ]; then
        shell::colored_echo "File not found: $file" 196
        return 1
    fi

    shell::colored_echo "Listing sections in file: $file" 11

    # Extract section names
    grep -o '^\[[^]]*\]' "$file" 2>/dev/null | sed 's/^\[\(.*\)\]$/\1/'
    return 0
}

# shell::ini_list_keys function
# Lists all key names from a specified section in a given INI file.
#
# Usage:
#   shell::ini_list_keys [-h] <file> <section>
#
# Parameters:
#   - -h        : Optional. Displays this help message.
#   - <file>    : The path to the INI file.
#   - <section> : The section within the INI file to search for keys.
#
# Description:
#   This function reads an INI file and extracts all key names from a specified section.
#   It validates the presence of the file and section, and applies strict validation rules
#   if SHELL_INI_STRICT is set. The function handles comments and empty lines within the INI file.
#
# Example:
#   shell::ini_list_keys config.ini MySection  # Lists all keys in MySection.
#
# Returns:
#   0 on success, 1 if the file or section is missing or not found.
#
# Notes:
#   - Relies on the shell::colored_echo function for output.
shell::ini_list_keys() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_LIST_KEYS"
        return 0
    fi

    local file="$1"
    local section="$2"

    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ]; then
        shell::colored_echo "shell::ini_list_keys: Missing required parameters" 196
        return 1
    fi

    # Validate section name only if strict mode is enabled
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::ini_validate_section_name "$section" || return 1
    fi

    # Check if file exists
    if [ ! -f "$file" ]; then
        shell::colored_echo "File not found: $file" 196
        return 1
    fi

    # Escape section for regex pattern
    local escaped_section
    escaped_section=$(shell::ini_escape_for_regex "$section")
    local section_pattern="^\[$escaped_section\]"
    local in_section=0

    # shell::colored_echo "Listing keys in section '$section' in file: $file" 11

    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*[#\;] ]]; then
            continue
        fi

        # Check for section
        if [[ "$line" =~ $section_pattern ]]; then
            in_section=1
            continue
        fi

        # Check if we've moved to a different section
        if [[ $in_section -eq 1 && "$line" =~ ^\[[^]]+\] ]]; then
            break
        fi

        # Extract key name from current section
        if [[ $in_section -eq 1 && "$line" =~ ^[[:space:]]*[^=]+= ]]; then
            local key="${line%%=*}"
            key=$(shell::ini_trim "$key")
            echo "$key"
        fi
    done <"$file"

    return 0
}

# shell::ini_section_exists function
# Checks if a specified section exists in a given INI file.
#
# Usage:
#   shell::ini_section_exists [-h] <file> <section>
#
# Parameters:
#   - -h        : Optional. Displays this help message.
#   - <file>    : The path to the INI file.
#   - <section> : The section within the INI file to check for existence.
#
# Description:
#   This function checks whether a specified section exists in an INI file.
#   It validates the presence of the file and section, and applies strict
#   validation rules if SHELL_INI_STRICT is set. The function uses regex
#   to search for the section header within the file.
#
# Example:
#   shell::ini_section_exists config.ini MySection  # Checks if MySection exists in config.ini.
shell::ini_section_exists() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_SECTION_EXISTS"
        return 0
    fi

    local file="$1"
    local section="$2"

    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ]; then
        shell::colored_echo "shell::ini_section_exists: Missing required parameters" 196
        return 1
    fi

    # Validate section name only if strict mode is enabled
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::ini_validate_section_name "$section" || return 1
    fi

    # Check if file exists
    if [ ! -f "$file" ]; then
        shell::colored_echo "File not found: $file" 196
        return 1
    fi

    # Escape section for regex pattern
    local escaped_section
    escaped_section=$(shell::ini_escape_for_regex "$section")

    shell::colored_echo "Checking if section '$section' exists in file: $file" 11

    # Check if section exists
    grep -q "^\[$escaped_section\]" "$file"
    local result=$?

    if [ $result -eq 0 ]; then
        shell::colored_echo "Section found: $section" 46
    else
        shell::colored_echo "Section not found: $section" 196
    fi

    return $result
}

# shell::ini_add_section function
# Adds a new section to a specified INI file if it does not already exist.
#
# Usage:
#   shell::ini_add_section [-h] <file> <section>
#
# Parameters:
#   - -h        : Optional. Displays this help message.
#   - <file>    : The path to the INI file.
#   - <section> : The section to be added to the INI file.
#
# Description:
#   This function checks if a specified section exists in an INI file and adds it if not.
#   It validates the presence of the file and section, and applies strict validation rules
#   if SHELL_INI_STRICT is set. The function handles the creation of the file if it does not exist.
#
# Example:
#   shell::ini_add_section config.ini NewSection  # Adds NewSection to config.ini if it doesn't exist.
shell::ini_add_section() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_ADD_SECTION"
        return 0
    fi

    local file="$1"
    local section="$2"

    if [ -z "$file" ] || [ -z "$section" ]; then
        shell::colored_echo "shell::ini_add_section: Missing required parameters" 196
        return 1
    fi

    # Validate section name only if strict mode is enabled
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::ini_validate_section_name "$section" || return 1
    fi

    # Check and create file if needed
    shell::create_file_if_not_exists "$file"

    # Check if section already exists
    if shell::ini_section_exists "$file" "$section"; then
        shell::colored_echo "Section already exists: $section" 11
        return 0
    fi

    shell::colored_echo "Adding section '$section' to file: $file" 11

    # Add a blank line before the new section unless the file is empty.
    # Use stat in case the file requires elevated permissions to read size.
    # Use echo for appending in case the file requires elevated permissions to write.
    if [ -s "$file" ]; then
        echo "" >>"$file"
    fi

    # Add the section
    echo "[$section]" >>"$file"
    shell::colored_echo "🟢 Successfully added section: $section" 46
    return 0
}

# shell::ini_write function
# Writes a key-value pair to a specified section in an INI file.
#
# Usage:
#   shell::ini_write [-h] <file> <section> <key> <value>
#
# Parameters:
#   - -h        : Optional. Displays this help message.
#   - <file>    : The path to the INI file.
#   - <section> : The section within the INI file to write the key-value pair.
#   - <key>     : The key to be written in the specified section.
#   - <value>   : The value associated with the key.
#
# Description:
#   This function writes a key-value pair to a specified section in an INI file.
#   It validates the presence of the file, section, and key, and applies strict
#   validation rules if SHELL_INI_STRICT is set. The function handles the creation
#   of the file and section if they do not exist. It also manages special characters
#   in values by quoting them if necessary.
#
# Example:
#   shell::ini_write config.ini MySection MyKey MyValue  # Writes MyKey=MyValue in MySection.
shell::ini_write() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_WRITE"
        return 0
    fi

    local file="$1"
    local section="$2"
    local key="$3"
    local value="$4"

    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ] || [ -z "$key" ]; then
        shell::colored_echo "shell::ini_write: Missing required parameters" 196
        return 1
    fi

    # Validate section and key names only if strict mode is enabled
    # Assumes shell::ini_validate_section_name and shell::ini_validate_key_name exist.
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::ini_validate_section_name "$section" || return 1
        shell::ini_validate_key_name "$key" || return 1
    fi

    # Check for empty value if not allowed
    if [ -z "$value" ] && [ "${SHELL_INI_ALLOW_EMPTY_VALUES}" -eq 0 ]; then
        shell::colored_echo "Empty values are not allowed" 196
        return 1
    fi

    # Check and create file if needed
    # Assumes shell::create_file_if_not_exists function exists.
    shell::create_file_if_not_exists "$file"

    # Ensure the target section exists in the file. Add it if it doesn't.
    # Assumes shell::ini_add_section function exists and handles adding a blank line
    # before a new section if the file is not empty.
    shell::ini_add_section "$file" "$section" || return 1

    # Escape section and key for regex pattern
    # Assumes shell::ini_escape_for_regex function exists.
    local escaped_section
    escaped_section=$(shell::ini_escape_for_regex "$section")
    local escaped_key
    escaped_key=$(shell::ini_escape_for_regex "$key")

    local section_pattern="^\[$escaped_section\]"                # Regex for the target section header
    local any_section_pattern="^\[[^]]+\]"                       # Regex for any section header
    local key_pattern="^[[:space:]]*${escaped_key}[[:space:]]*=" # Regex to match the key at the start of a line (allowing leading spaces)

    local in_target_section=0 # Flag: are we currently inside the target section?
    local key_handled=0       # Flag: has the key been found and updated, or added?
    local temp_file
    temp_file=$(shell::ini_create_temp_file)

    shell::colored_echo "Writing key '$key' with value '$value' to section '$section' in file: $file" 11

    # Special handling for values with quotes or special characters (remains the same)
    # Assumes SHELL_INI_STRICT is defined.
    if [ "${SHELL_INI_STRICT}" -eq 1 ] && [[ "$value" =~ [[:space:]\"\'\`\&\|\<\>\;\$] ]]; then
        value="\"${value//\"/\\\"}\""
        shell::colored_echo "Value contains special characters, quoting: $value" 11
    fi

    # Process the file line by line
    # Use `|| [ -n "$line" ]` to ensure the last line is processed even if it doesn't end with a newline.
    while IFS= read -r line || [ -n "$line" ]; do
        # Trim leading and trailing whitespace from the line for easier processing.
        local trimmed_line
        trimmed_line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        # trimmed_line=$(awk '{gsub(/^[[:space:]]*/, "", $0); gsub(/[[:space:]]*$/, "", $0); print $0}' <<<"$line")

        # Skip empty lines (after trimming). This removes blank lines within sections.
        if [ -z "$trimmed_line" ]; then
            continue
        fi

        # Check if the trimmed line is a section header
        if [[ "$trimmed_line" =~ $any_section_pattern ]]; then
            # If we were in the target section and reached a new section,
            # and the key hasn't been handled yet, add it now at the end of the target section.
            if [ $in_target_section -eq 1 ] && [ $key_handled -eq 0 ]; then
                echo "$key=$value" >>"$temp_file"
                key_handled=1 # Mark as added
            fi

            # Add a blank line before this section header unless the temp file is currently empty.
            # This ensures a blank line before all sections after the first one.
            if [ -s "$temp_file" ]; then
                echo "" >>"$temp_file"
            fi

            # Check if this is the target section header
            if [[ "$trimmed_line" =~ $section_pattern ]]; then
                in_target_section=1 # We are now inside the target section
            else
                in_target_section=0 # We are in a different section
            fi

            # Write the original (untrimmed) section header to preserve original spacing if desired.
            echo "$line" >>"$temp_file"
            continue # Move to the next line
        fi

        # If we are currently inside the target section
        if [ $in_target_section -eq 1 ]; then
            # Check if this line contains the key we are looking for (using trimmed line for pattern match)
            if [[ "$trimmed_line" =~ $key_pattern ]]; then
                # If the key is found, write the updated line with the new value.
                # No blank line added before the key-value pair.
                echo "$key=$value" >>"$temp_file"
                key_handled=1 # Mark as updated
                continue      # Skip the original line containing the old key-value pair
            fi

            # If the line is within the target section but is not the key we are handling,
            # write the original line. This preserves other keys or comments in the section.
            # Blank lines were already skipped.
            echo "$line" >>"$temp_file"
            continue # Move to the next line
        fi

        # If the trimmed line was not empty, not a section header, and we are not in the target section,
        # write the original line to the temporary file. This preserves lines outside sections.
        echo "$line" >>"$temp_file"

    done <"$file" # Read input from the specified file.

    # After the loop, if we were in the target section when the file ended,
    # and the key was never handled (meaning it didn't exist in the target section),
    # add the key-value pair at the end of the file (within that last section).
    if [ $in_target_section -eq 1 ] && [ $key_handled -eq 0 ]; then
        # No blank line added before the key-value pair at the end of the section.
        echo "$key=$value" >>"$temp_file"
        key_handled=1 # Mark as added
    fi

    # Use atomic operation to replace the original file.
    # This is safer than removing the original and renaming the temp file,
    # as it reduces the window where the file might be missing.
    mv "$temp_file" "$file"

    # Provide feedback based on whether the key was updated or added.
    if [ $key_handled -eq 1 ]; then
        shell::colored_echo "🟢 Successfully wrote key '$key' with value '$value' to section '$section'" 46
    else
        # This case should ideally not be reached if shell::ini_add_section ensures
        # the section exists and the logic is correct. It's a safeguard.
        shell::colored_echo "🟡 Section '$section' processed, but key '$key' was not added or updated." 11
        return 1
    fi

    return 0
}

# shell::ini_remove_section function
# Removes a specified section and its key-value pairs from an INI formatted file.
#
# Usage:
#   shell::ini_remove_section <file> <section>
#
# Parameters:
#   - <file>: The path to the INI file.
#   - <section>: The name of the section to remove (without the square brackets).
#
# Description:
#   This function processes an INI file line by line. It identifies the start of the
#   section to be removed and skips all subsequent lines until another section
#   header is encountered or the end of the file is reached. The remaining lines
#   (before the target section and after it) are written to a temporary file,
#   which then replaces the original file.
#
# Example usage:
#   shell::ini_remove_section /path/to/config.ini "database"
#
# Notes:
#   - Assumes the INI file has sections enclosed in square brackets (e.g., [section]).
#   - Empty lines and lines outside of sections are preserved.
#   - Relies on helper functions like shell::colored_echo, shell::ini_escape_for_regex,
#     shell::ini_create_temp_file, and optionally shell::ini_validate_section_name
#     if SHELL_INI_STRICT is enabled. (Note: shell::ini_escape_for_regex and
#     shell::ini_create_temp_file are not provided in this snippet, but are assumed
#     to exist based on usage.)
#   - Uses atomic operation (mv) to replace the original file, reducing risk of data loss.
shell::ini_remove_section() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_REMOVE_SECTION"
        return 0
    fi

    local file="$1"
    local section="$2"

    # Validate required parameters: file path and section name.
    if [ -z "$file" ] || [ -z "$section" ]; then
        shell::colored_echo "shell::ini_remove_section: Missing required parameters" 196
        return 1
    fi

    # Validate section name only if strict mode is enabled (optional, based on existing code).
    # Assumes shell::ini_validate_section_name function exists.
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::ini_validate_section_name "$section" || return 1
    fi

    # Check if the specified file exists.
    if [ ! -f "$file" ]; then
        shell::colored_echo "File not found: $file" 196
        return 1
    fi

    # Check if the section exists in the file before attempting removal.
    # This prevents sed from processing the entire file unnecessarily if the section isn't there.
    if ! grep -q "^\[${section}\]$" "$file"; then
        shell::colored_echo "Section '$section' not found in file: $file" 11
        return 0
    fi

    shell::colored_echo "Removing section '$section' from file: $file" 11

    local os_type
    # Determine the operating system type to adjust the sed command syntax.
    # Assumes shell::get_os_type function exists.
    os_type=$(shell::get_os_type)

    local sed_cmd=""
    # Construct the sed command for in-place editing based on OS type.
    # The command '/^\[${section}\]$/,/^\[.*\]$/ { /^\[.*\]$/!d; }' works as follows:
    # 1. '/^\[${section}\]$/,/^\[.*\]$/': Defines a range starting from the line matching the exact section header
    #    (e.g., [dev]) and ending at the next line that matches any section header (e.g., [uat]).
    # 2. '{ ... }': Applies the commands within the curly braces to lines within the matched range.
    # 3. '/^\[.*\]$/!d': Deletes lines (`d`) within the range that do *not* (`!`) match the pattern
    #    `^\[.*\]$` (which matches any section header). This ensures that the starting section header
    #    and all lines *within* the section are deleted, but the *next* section header (which ends the range)
    #    is not deleted. If the target is the last section, the range extends to the end of the file,
    #    and all lines after the target header are deleted correctly.
    if [ "$os_type" = "macos" ]; then
        # BSD sed on macOS requires an empty string backup extension with -i.
        sed_cmd="sed -i '' '/^\[${section}\]$/,/^\[.*\]$/ { /^\[.*\]$/!d; }' \"$file\""
    else
        # GNU sed on Linux typically does not require a backup extension with -i.
        sed_cmd="sed -i '/^\[${section}\]$/,/^\[.*\]$/ { /^\[.*\]$/!d; }' \"$file\""
    fi

    # Execute the sed command using shell::run_cmd_eval for logging and execution.
    # Assumes shell::run_cmd_eval function exists.
    shell::run_cmd_eval "$sed_cmd"

    # Check the exit status of the sed command. sed returns 0 on successful execution.
    if [ $? -eq 0 ]; then
        shell::colored_echo "🟢 Successfully removed section '$section'" 46
        return 0
    else
        # sed might return non-zero for various reasons, though the command is expected to work.
        # A generic error message is appropriate here.
        shell::colored_echo "🔴 Error removing section '$section'" 196
        return 1
    fi
}

# shell::fzf_ini_remove_key function
# Interactively selects a key from a specific section in an INI file using fzf
# and then removes the selected key from that section.
#
# Usage:
#   shell::fzf_ini_remove_key [-n] <file> <section>
#
# Parameters:
#   - -n        : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - <file>    : The path to the INI file.
#   - <section> : The section within the INI file from which to remove a key.
#
# Description:
#   This function validates the input file and section, lists keys within the section
#   using shell::ini_list_keys, presents the keys for interactive selection using fzf,
#   and then removes the chosen key-value pair from the specified section in the INI file.
#   It handles cases where the file or section does not exist and provides feedback
#   using shell::colored_echo.
#
# Example:
#   shell::fzf_ini_remove_key config.ini "Database"  # Interactively remove a key from the Database section.
#   shell::fzf_ini_remove_key -n settings.ini "API"  # Dry-run: show commands to remove a key from the API section.
shell::fzf_ini_remove_key() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_INI_REMOVE_KEY"
        return 0
    fi

    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Validate required parameters: file path and section name.
    if [ $# -lt 2 ]; then
        shell::colored_echo "shell::fzf_ini_remove_key: Missing required parameters" 196
        echo "Usage: shell::fzf_ini_remove_key [-n] <file> <section>"
        return 1
    fi

    local file="$1"
    local section="$2"

    # Check if the specified file exists.
    if ! shell::ini_check_file "$file"; then
        # shell::ini_check_file prints an error if the file is not found
        return 1
    fi

    # Check if the section exists in the file.
    if ! shell::ini_section_exists "$file" "$section"; then
        # shell::ini_section_exists prints an error if the section is not found
        return 1
    fi

    # Ensure fzf is installed.
    shell::install_package fzf || {
        shell::colored_echo "🔴 Error: fzf is required but could not be installed." 196
        return 1
    }

    # Get the list of keys in the specified section and use fzf to select one.
    local selected_key
    selected_key=$(shell::ini_list_keys "$file" "$section" | fzf --prompt="Select key to remove from section '$section': ")

    # Check if a key was selected.
    if [ -z "$selected_key" ]; then
        shell::colored_echo "🔴 No key selected. Aborting removal." 196
        return 1
    fi

    shell::colored_echo "Selected key for removal: '$selected_key'" 33

    local os_type
    os_type=$(shell::get_os_type)

    # Escape section and key for regex pattern
    local escaped_section
    escaped_section=$(shell::ini_escape_for_regex "$section")
    local escaped_key
    escaped_key=$(shell::ini_escape_for_regex "$selected_key")

    local section_pattern="^\[$escaped_section\]"                # Regex for the target section header
    local any_section_pattern="^\[[^]]+\]"                       # Regex for any section header
    local key_pattern="^[[:space:]]*${escaped_key}[[:space:]]*=" # Regex to match the key at the start of a line (allowing leading spaces)

    local in_target_section=0 # Flag: are we currently inside the target section?
    local key_removed=0       # Flag: has the key been found and removed?
    local temp_file
    temp_file=$(shell::ini_create_temp_file)

    shell::colored_echo "Removing key '$selected_key' from section '$section' in file: $file" 11

    # Process the file line by line
    # Use `|| [ -n "$line" ]` to ensure the last line is processed even if it doesn't end with a newline.
    while IFS= read -r line || [ -n "$line" ]; do
        local trimmed_line
        trimmed_line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

        # Check if the trimmed line is a section header
        if [[ "$trimmed_line" =~ $any_section_pattern ]]; then
            # Check if this is the target section header
            if [[ "$trimmed_line" =~ $section_pattern ]]; then
                in_target_section=1 # We are now inside the target section
            else
                in_target_section=0 # We are in a different section
            fi
            # Always write section headers to the temporary file
            echo "$line" >>"$temp_file"
            continue # Move to the next line
        fi

        # If we are currently inside the target section
        if [ $in_target_section -eq 1 ]; then
            # Check if this line contains the key we are looking for (using trimmed line for pattern match)
            if [[ "$trimmed_line" =~ $key_pattern ]]; then
                # Found the key, skip this line to remove it
                key_removed=1
                continue # Move to the next line without writing the current line
            fi
            # If the line is within the target section but is not the key we are removing,
            # write the original line to the temporary file.
            echo "$line" >>"$temp_file"
            continue # Move to the next line
        fi

        # If the trimmed line was not empty, not a section header, and we are not in the target section,
        # write the original line to the temporary file. This preserves lines outside sections.
        echo "$line" >>"$temp_file"

    done <"$file" # Read input from the specified file.

    # Use atomic operation to replace the original file.
    # This is safer than removing the original and renaming the temp file.
    local replace_cmd="mv \"$temp_file\" \"$file\""

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$replace_cmd"
    else
        shell::run_cmd_eval "$replace_cmd"
        if [ $? -eq 0 ]; then
            if [ $key_removed -eq 1 ]; then
                shell::colored_echo "🟢 Successfully removed key '$selected_key' from section '$section'" 46
            else
                # This case should not be reached if shell::ini_list_keys and fzf worked correctly,
                # but it's a safeguard.
                shell::colored_echo "🟡 Key '$selected_key' was selected but not found in section '$section' during removal process." 11
                return 1
            fi
        else
            shell::colored_echo "🔴 Error replacing the original file after key removal." 196
            return 1
        fi
    fi

    return 0
}

# shell::ini_remove_key function
# Removes a specified key from a specific section in an INI formatted file.
#
# Usage:
#   shell::ini_remove_key [-n] <file> <section> <key>
#
# Parameters:
#   - -n        : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - <file>    : The path to the INI file.
#   - <section> : The section within the INI file from which to remove the key.
#   - <key>     : The key to be removed from the specified section.
#
# Description:
#   This function processes an INI file line by line. It identifies the start of the
#   target section and then skips the line containing the specified key within that section.
#   All other lines (before the target section, in the target section but not matching the key,
#   and after the target section) are written to a temporary file, which then replaces
#   the original file.
#
# Example usage:
#   shell::ini_remove_key /path/to/config.ini "database" "username"
#   shell::ini_remove_key -n /path/to/config.ini "api" "api_key" # Dry-run mode
#
# Notes:
#   - Assumes the INI file has sections enclosed in square brackets (e.g., [section]) and key=value pairs.
#   - Empty lines and lines outside of sections are preserved.
#   - Relies on helper functions like shell::colored_echo, shell::ini_escape_for_regex,
#     shell::ini_create_temp_file, and optionally shell::ini_validate_section_name,
#     shell::ini_validate_key_name if SHELL_INI_STRICT is enabled.
#   - Uses atomic operation (mv) to replace the original file, reducing risk of data loss.
shell::ini_remove_key() {
    local dry_run="false"

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_REMOVE_KEY"
        return 0
    fi

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Validate required parameters: file path, section name, and key name.
    if [ $# -lt 3 ]; then
        shell::colored_echo "shell::ini_remove_key: Missing required parameters" 196
        echo "Usage: shell::ini_remove_key [-n] <file> <section> <key>"
        return 1
    fi

    local file="$1"
    local section="$2"
    local key="$3"

    # Validate section and key names only if strict mode is enabled (optional, based on existing code).
    # Assumes shell::ini_validate_section_name and shell::ini_validate_key_name functions exist.
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::ini_validate_section_name "$section" || return 1
        shell::ini_validate_key_name "$key" || return 1
    fi

    # Check if the specified file exists.
    if [ ! -f "$file" ]; then
        shell::colored_echo "File not found: $file" 196
        return 1
    fi

    # Check if the section exists in the file before attempting removal.
    if ! shell::ini_section_exists "$file" "$section"; then
        # shell::ini_section_exists prints an error if the section is not found
        return 1
    fi

    shell::colored_echo "Attempting to remove key '$key' from section '$section' in file: $file" 11

    # Escape section and key for regex pattern
    local escaped_section
    escaped_section=$(shell::ini_escape_for_regex "$section")
    local escaped_key
    escaped_key=$(shell::ini_escape_for_regex "$key")

    local section_pattern="^\[$escaped_section\]"                # Regex for the target section header
    local any_section_pattern="^\[[^]]+\]"                       # Regex for any section header
    local key_pattern="^[[:space:]]*${escaped_key}[[:space:]]*=" # Regex to match the key at the start of a line (allowing leading spaces)

    local in_target_section=0 # Flag: are we currently inside the target section?
    local key_removed=0       # Flag: has the key been found and removed?
    local temp_file
    temp_file=$(shell::ini_create_temp_file)

    # Process the file line by line
    # Use `|| [ -n "$line" ]` to ensure the last line is processed even if it doesn't end with a newline.
    while IFS= read -r line || [ -n "$line" ]; do
        local trimmed_line
        trimmed_line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

        # Check if the trimmed line is a section header
        if [[ "$trimmed_line" =~ $any_section_pattern ]]; then
            # Check if this is the target section header
            if [[ "$trimmed_line" =~ $section_pattern ]]; then
                in_target_section=1 # We are now inside the target section
            else
                in_target_section=0 # We are in a different section
            fi
            # Always write section headers to the temporary file
            echo "$line" >>"$temp_file"
            continue # Move to the next line
        fi

        # If we are currently inside the target section
        if [ $in_target_section -eq 1 ]; then
            # Check if this line contains the key we are looking for (using trimmed line for pattern match)
            if [[ "$trimmed_line" =~ $key_pattern ]]; then
                # Found the key, skip this line to remove it
                shell::colored_echo "Found key '$key' for removal." 11
                key_removed=1
                continue # Move to the next line without writing the current line
            fi
            # If the line is within the target section but is not the key we are removing,
            # write the original line to the temporary file.
            echo "$line" >>"$temp_file"
            continue # Move to the next line
        fi

        # If the trimmed line was not empty, not a section header, and we are not in the target section,
        # write the original line to the temporary file. This preserves lines outside sections.
        echo "$line" >>"$temp_file"

    done <"$file" # Read input from the specified file.

    # Use atomic operation to replace the original file.
    # This is safer than removing the original and renaming the temp file.
    local replace_cmd="mv \"$temp_file\" \"$file\""

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$replace_cmd"
    else
        shell::run_cmd_eval "$replace_cmd"
        if [ $? -eq 0 ]; then
            if [ $key_removed -eq 1 ]; then
                shell::colored_echo "🟢 Successfully removed key '$key' from section '$section'" 46
                return 0
            else
                shell::colored_echo "🟡 Key '$key' not found in section '$section'." 11
                return 1
            fi
        else
            shell::colored_echo "🔴 Error replacing the original file after key removal." 196
            return 1
        fi
    fi
}

# shell::ini_set_array_value function
# Writes an array of values to a specified key in an INI file.
#
# Usage:
#   shell::ini_set_array_value [-h] <file> <section> <key> [value1] [value2 ...]
#
# Parameters:
#   - -h        : Optional. Displays this help message.
#   - <file>    : The path to the INI file.
#   - <section> : The section within the INI file to write the array to.
#   - <key>     : The key to be associated with the array of values.
#   - [valueN]  : Optional. One or more values to be written as part of the array.
#
# Description:
#   This function processes a list of values, formats them into a comma-separated
#   string, and writes this string as the value for a specified key in an INI file.
#   Values containing spaces, commas, or double quotes are automatically enclosed
#   in double quotes, and internal double quotes are escaped (e.g., "value with \"quote\"").
#   The final formatted string is passed to 'shell::ini_write' for atomic writing,
#   which handles file and section existence, creation, and updates.
#
# Example:
#   shell::ini_set_array_value config.ini MySection MyList "alpha" "beta gamma" "delta,epsilon"
#   # This would result in MyList=alpha,"beta gamma","delta,epsilon" in config.ini
#
# Returns:
#   0 on success, 1 on failure (e.g., missing parameters, underlying write failure).
#
# Notes:
#   - Relies on 'shell::colored_echo' for output and 'shell::ini_write' for file operations.
#   - Interaction with SHELL_INI_STRICT in 'shell::ini_write': If SHELL_INI_STRICT is set
#     to 1, 'shell::ini_write' might re-quote the entire array string generated by this
#     function if it contains spaces or quotes, potentially leading to double-quoting
#     (e.g., value becoming ""item1\",\"item 2""). This function aims to produce a
#     standard, internally-quoted INI array value.
shell::ini_set_array_value() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_SET_ARRAY_VALUE"
        return 0
    fi

    local file="$1"
    local section="$2"
    local key="$3"
    shift 3
    local -a raw_array_values=("$@")

    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ] || [ -z "$key" ]; then
        shell::colored_echo "🔴 shell::ini_set_array_value: Missing required parameters." 196
        echo "Usage: shell::ini_set_array_value [-h] <file> <section> <key> [value1] [value2 ...]"
        return 1
    fi

    local -a formatted_values=()
    local temp_value
    local array_string

    # Process each raw value, escaping quotes and adding outer quotes if necessary.
    for val in "${raw_array_values[@]}"; do
        temp_value="${val//\"/\\\"}" # Escape existing double quotes within the value.

        # Quote the value if it contains spaces, commas, or (after escaping) original quotes.
        if [[ "$temp_value" =~ [[:space:],\"] ]]; then
            temp_value="\"$temp_value\"" # Enclose in double quotes.
        fi
        formatted_values+=("$temp_value")
    done

    # Join the formatted values with a comma.
    # 'printf -v' is used for robust string concatenation, and trailing comma is removed.
    if [ ${#formatted_values[@]} -gt 0 ]; then
        printf -v array_string '%s,' "${formatted_values[@]}"
        array_string="${array_string%,}" # Remove the last comma.
    else
        array_string=""
    fi

    # Write the formatted array string to the INI file using shell::ini_write.
    shell::ini_write "$file" "$section" "$key" "$array_string"
    local status=$?

    # Provide feedback based on the operation's success.
    if [ $status -eq 0 ]; then
        shell::colored_echo "🟢 Successfully wrote array value for key '$key' to section '$section'." 46
    else
        shell::colored_echo "🔴 Failed to write array value for key '$key' to section '$section'." 196
    fi

    return $status
}
