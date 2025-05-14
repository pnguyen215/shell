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

    shell::colored_echo "Listing keys in section '$section' in file: $file" 11

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

    # Add a newline if file is not empty
    if [ -s "$file" ]; then
        echo "" >>"$file"
    fi

    # Add the section
    echo "[$section]" >>"$file"

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
    shell::create_file_if_not_exists "$file"

    # Create section if it doesn't exist
    shell::ini_add_section "$file" "$section" || return 1

    # Escape section and key for regex pattern
    local escaped_section
    escaped_section=$(shell::ini_escape_for_regex "$section")
    local escaped_key
    escaped_key=$(shell::ini_escape_for_regex "$key")

    local section_pattern="^\[$escaped_section\]"
    local key_pattern="^[[:space:]]*${escaped_key}[[:space:]]*="
    local in_section=0
    local found_key=0
    local temp_file
    temp_file=$(shell::ini_create_temp_file)

    shell::colored_echo "Writing key '$key' with value '$value' to section '$section' in file: $file" 11

    # Special handling for values with quotes or special characters
    if [ "${SHELL_INI_STRICT}" -eq 1 ] && [[ "$value" =~ [[:space:]\"\'\`\&\|\<\>\;\$] ]]; then
        value="\"${value//\"/\\\"}\""
        shell::colored_echo "Value contains special characters, quoting: $value" 11
    fi

    # Process the file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        # Check for section
        if [[ "$line" =~ $section_pattern ]]; then
            in_section=1
            echo "$line" >>"$temp_file"
            continue
        fi

        # Check if we've moved to a different section
        if [[ $in_section -eq 1 && "$line" =~ ^\[[^]]+\] ]]; then
            # Add the key-value pair if we haven't found it yet
            if [ $found_key -eq 0 ]; then
                echo "$key=$value" >>"$temp_file"
                found_key=1
            fi
            in_section=0
        fi

        # Update the key if it exists in the current section
        if [[ $in_section -eq 1 && "$line" =~ $key_pattern ]]; then
            echo "$key=$value" >>"$temp_file"
            found_key=1
            continue
        fi

        # Write the line to the temp file
        echo "$line" >>"$temp_file"
    done <"$file"

    # Add the key-value pair if we're still in the section and haven't found it
    if [ $in_section -eq 1 ] && [ $found_key -eq 0 ]; then
        echo "$key=$value" >>"$temp_file"
    fi

    # Use atomic operation to replace the original file
    mv "$temp_file" "$file"
    shell::colored_echo "Successfully wrote key '$key' with value '$value' to section '$section'" 46
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

    # local file="$1"
    # local section="$2"

    # # Validate parameters
    # if [ -z "$file" ] || [ -z "$section" ]; then
    #     shell::colored_echo "shell::ini_remove_section: Missing required parameters" 196
    #     return 1
    # fi

    # # Validate section name only if strict mode is enabled
    # if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
    #     shell::ini_validate_section_name "$section" || return 1
    # fi

    # # Check if file exists
    # if [ ! -f "$file" ]; then
    #     shell::colored_echo "File not found: $file" 196
    #     return 1
    # fi

    # # Escape the section name for use in a regex pattern to match the section header.
    # # Assumes shell::ini_escape_for_regex function exists.
    # local escaped_section
    # escaped_section=$(shell::ini_escape_for_regex "$section")
    # local section_pattern="^\[$escaped_section\]"
    # local in_section=0
    # local temp_file
    # # Create a temporary file to write the lines that are not in the removed section.
    # # Assumes shell::ini_create_temp_file function exists and returns the temp file path.
    # temp_file=$(shell::ini_create_temp_file)

    # shell::colored_echo "Removing section '$section' from file: $file" 11

    # # Process the file line by line.
    # # IFS= read -r line prevents issues with spaces and backslashes in lines.
    # while IFS= read -r line; do
    #     # Check if the current line matches the start of the section to be removed.
    #     if [[ "$line" =~ $section_pattern ]]; then
    #         in_section=1 # Set flag to indicate we are now inside the target section.
    #         continue
    #     fi

    #     # If we are currently inside the section to be removed, check if the current line
    #     # is the start of a new section.
    #     if [[ $in_section -eq 1 && "$line" =~ ^\[[^]]+\] ]]; then
    #         in_section=0 # If it's a new section, we are no longer in the section to be removed.
    #     fi

    #     # If we are not inside the section to be removed, write the line to the temporary file.
    #     if [ $in_section -eq 0 ]; then
    #         echo "$line" >>"$temp_file"
    #     fi
    # done <"$file"

    # # Atomically replace the original file with the temporary file.
    # # This is safer than removing the original and renaming the temp file,
    # # as it reduces the window where the file might be missing.
    # mv "$temp_file" "$file"

    # shell::colored_echo "Successfully removed section '$section'" 46
    # return 0

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
