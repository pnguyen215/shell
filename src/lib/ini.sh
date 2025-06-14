#!/bin/bash
# ini.sh

# shell::read_ini function
# Reads the value of a specified key from a given section in an INI file.
#
# Usage:
#   shell::read_ini <file> <section> <key>
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
#   shell::read_ini config.ini MySection MyKey  # Retrieves the value of MyKey in MySection.
#
# Returns:
#   The value of the specified key if found, or an error message if the key is not found.
#
# Notes:
#   - Relies on the shell::colored_echo function for output.
#   - The behavior is controlled by the SHELL_INI_STRICT environment variable.
shell::read_ini() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_READ_INI"
        return 0
    fi

    local file="$1"
    local section="$2"
    local key="$3"

    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ] || [ -z "$key" ]; then
        shell::colored_echo "shell::read_ini: Missing required parameters" 196 >&2
        echo "Usage: shell::read_ini [-h] <file> <section> <key>"
        return 1
    fi

    # Validate section and key names only if strict mode is enabled
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::validate_ini_section_name "$section" || return 1
        shell::validate_ini_key_name "$key" || return 1
    fi

    # Check if file exists
    if [ ! -f "$file" ]; then
        shell::colored_echo "ERR: File not found: $file" 196
        return 1
    fi

    # Escape section and key for regex pattern
    local escaped_section
    escaped_section=$(shell::ini_escape_for_regex "$section")
    local escaped_key
    escaped_key=$(shell::ini_escape_for_regex "$key")

    local section_pattern="^\[$escaped_section\]"
    local any_section_pattern="^\[[^]]+\]" # Regex for any section header
    local in_target_section=0
    local os_type=$(shell::get_os_type)
    local decoded_value

    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*[#\;] ]]; then
            continue
        fi

        # Check if the line is a section header
        if [[ "$line" =~ $any_section_pattern ]]; then
            if [ "$in_target_section" -eq 1 ] && ! [[ "$line" =~ $section_pattern ]]; then
                # We were in the target section, but now we've moved to a *different* section.
                # Key was not found in the target section. Exit the loop.
                shell::colored_echo "WARN: Reached end of target section '$section' without finding key '$key'." 33
                return 1 # Key not found in specified section.
            fi

            if [[ "$line" =~ $section_pattern ]]; then
                # This is the target section.
                in_target_section=1
            else
                # This is a different section (not the target one, and not the one we just exited from).
                # Ensure we are no longer searching within the target section's scope.
                in_target_section=0
            fi
            continue # Move to the next line, as this line is a section header.
        fi

        # Only proceed to check for key if we are currently inside the target section
        if [ "$in_target_section" -eq 1 ]; then
            local key_pattern="^[[:space:]]*${escaped_key}[[:space:]]*="
            if [[ "$line" =~ $key_pattern ]]; then
                local value="${line#*=}"
                # Trim whitespace
                value=$(shell::trim_ini "$value")

                # Check for quoted values
                if [[ "$value" =~ ^\"(.*)\"$ ]]; then
                    # Remove the quotes
                    value="${BASH_REMATCH[1]}"
                    # Handle escaped quotes within the value
                    value="${value//\\\"/\"}"
                fi

                # shell::colored_echo "INFO: Found value for key '$key'." 46
                if [ "$os_type" = "macos" ]; then
                    decoded_value=$(echo "$value" | base64 -D)
                else
                    decoded_value=$(echo "$value" | base64 -d)
                fi
                echo "$decoded_value"
                return 0
            fi
        fi
    done <"$file"

    shell::colored_echo "WARN: Key not found: '$key' in section: '$section'." 33
    return 1
}

# shell::validate_ini_section_name function
# Validates an INI section name based on defined strictness levels.
# It checks for empty names and disallowed characters or spaces according to
# SHELL_INI_STRICT and SHELL_INI_ALLOW_SPACES_IN_NAMES variables.
#
# Usage:
#   shell::validate_ini_section_name <section_name>
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
#   shell::validate_ini_section_name "MySection"   # Valid
#   shell::validate_ini_section_name "My Section"  # Invalid (contains space)
#   shell::validate_ini_section_name "My[Section]" # Invalid (contains illegal character)
#   shell::validate_ini_section_name ""            # Invalid (empty)
#
# Returns:
#   0 if the section name is valid, 1 otherwise.
#
# Notes:
#   - Relies on the shell::colored_echo function for output.
#   - The behavior is controlled by the SHELL_INI_STRICT and
#     SHELL_INI_ALLOW_SPACES_IN_NAMES environment variables or constants.
shell::validate_ini_section_name() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_VALIDATE_INI_SECTION_NAME"
        return 0
    fi

    local section="$1"

    if [ -z "$section" ]; then
        shell::colored_echo "ERR: Section name cannot be empty" 196
        echo "Usage: shell::validate_ini_section_name [-h] <section_name>"
        return 1
    fi

    # Check for illegal characters if strict mode is enabled.
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        # Check for illegal characters in section name: [, ], = using case for portability
        case "$section" in
        *\[* | *\]* | *=*)
            # If the section contains [, ], or =, it's illegal
            shell::colored_echo "ERR: Section name contains illegal characters: $section" 196
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
        shell::colored_echo "ERR: Section name contains spaces: $section" 196
        return 1
    fi

    return 0
}

# shell::validate_ini_key_name function
# Validates an INI key name based on defined strictness levels.
# It checks for empty names and disallowed characters or spaces according to
# SHELL_INI_STRICT and SHELL_INI_ALLOW_SPACES_IN_NAMES variables.

# Usage:
#   shell::validate_ini_key_name [-h] <key_name>

# Parameters:
#   - -h         : Optional. Displays this help message.
#   - <key_name> : The name of the INI key to validate.

# Returns:
#   0 if the key name is valid, 1 otherwise.

# Notes:
#   - Relies on the shell::colored_echo function for output.
#   - The behavior is controlled by the SHELL_INI_STRICT and
#     SHELL_INI_ALLOW_SPACES_IN_NAMES environment variables or constants.
shell::validate_ini_key_name() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_VALIDATE_INI_KEY_NAME"
        return 0
    fi

    local key="$1"

    if [ -z "$key" ]; then
        shell::colored_echo "ERR: Key name cannot be empty" 196
        echo "Usage: shell::validate_ini_key_name [-h] <key_name>"
        return 1
    fi

    # Check for illegal characters if strict mode is enabled.
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        # Check for illegal characters in key name: [, ], = using case for portability
        case "$key" in
        *\[* | *\]* | *=*)
            # If the key contains [, ], or =, it's illegal
            shell::colored_echo "ERR: Key name contains illegal characters: $key" 196
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
        shell::colored_echo "ERR: Key name contains spaces: $key" 196
        return 1
    fi

    return 0
}

# shell::create_ini_temp_file function
# Creates a temporary file with a unique name in the system's temporary directory.
#
# Usage:
#   shell::create_ini_temp_file
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
#   temp_file=$(shell::create_ini_temp_file)  # Creates a temporary file and stores its path in temp_file.
shell::create_ini_temp_file() {
    mktemp "${TMPDIR:-/tmp}/shell_ini_XXXXXXXXXX"
}

# shell::trim_ini function
# Trims leading and trailing whitespace from a given string.
#
# Usage:
#   shell::trim_ini <string>
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
#   trimmed_string=$(shell::trim_ini "  example string  ")  # Outputs "example string"
shell::trim_ini() {
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

# shell::check_ini_file function
# Validates the existence and write ability of a specified file, creating it if necessary.
#
# Usage:
#   shell::check_ini_file [-h] <file>
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
#   shell::check_ini_file /path/to/config.ini  # Checks or creates the file at the specified path.
shell::check_ini_file() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_CHECK_FILE"
        return 0
    fi

    local file="$1"

    # Check if file parameter is provided
    if [ -z "$file" ]; then
        shell::colored_echo "File path is required" 196
        echo "Usage: shell::check_ini_file [-h] <file>"
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

# shell::list_ini_sections function
# Lists all section names from a given INI file.
#
# Usage:
#   shell::list_ini_sections [-h] <file>
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
#   shell::list_ini_sections config.ini  # Lists all sections in config.ini.
#
# Returns:
#   0 on success, 1 if the file is missing or not found.
#
# Notes:
#   - Relies on the shell::colored_echo function for output.
shell::list_ini_sections() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_LIST_SECTIONS"
        return 0
    fi

    local file="$1"

    # Validate parameters
    if [ -z "$file" ]; then
        shell::colored_echo "shell::list_ini_sections: Missing file parameter" 196
        echo "Usage: shell::list_ini_sections [-h] <file>"
        return 1
    fi

    # Check if file exists
    if [ ! -f "$file" ]; then
        shell::colored_echo "File not found: $file" 196
        return 1
    fi

    # shell::colored_echo "Listing sections in file: $file" 11

    # Extract section names
    grep -o '^\[[^]]*\]' "$file" 2>/dev/null | sed 's/^\[\(.*\)\]$/\1/'
    return 0
}

# shell::list_ini_keys function
# Lists all key names from a specified section in a given INI file.
#
# Usage:
#   shell::list_ini_keys [-h] <file> <section>
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
#   shell::list_ini_keys config.ini MySection  # Lists all keys in MySection.
#
# Returns:
#   0 on success, 1 if the file or section is missing or not found.
#
# Notes:
#   - Relies on the shell::colored_echo function for output.
shell::list_ini_keys() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_LIST_KEYS"
        return 0
    fi

    local file="$1"
    local section="$2"

    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ]; then
        shell::colored_echo "shell::list_ini_keys: Missing required parameters" 196
        echo "Usage: shell::list_ini_keys [-h] <file> <section>"
        return 1
    fi

    # Validate section name only if strict mode is enabled
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::validate_ini_section_name "$section" || return 1
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
    local any_section_pattern="^\[[^]]+\]"
    local in_section=0
    local found_keys=0

    # shell::colored_echo "Listing keys in section '$section' in file: $file" 11

    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*[#\;] ]]; then
            continue
        fi

        # Check for section headers
        if [[ "$line" =~ $any_section_pattern ]]; then
            if [[ "$line" =~ $section_pattern ]]; then
                in_section=1
            else
                in_section=0 # Exit target section when a new section is encountered
            fi
            continue
        fi

        # Extract key name from current section
        if [ $in_section -eq 1 ] && [[ "$line" =~ ^[[:space:]]*[^=]+= ]]; then
            local key="${line%%=*}"
            key=$(shell::trim_ini "$key")
            echo "$key"
            found_keys=1
        fi
    done <"$file"

    # Return 1 if no keys were found in the section
    if [ $found_keys -eq 0 ]; then
        shell::colored_echo "WARN: No keys found in section '$section' in file: $file" 33
        return 1
    fi

    return 0
}

# shell::exist_ini_section function
# Checks if a specified section exists in a given INI file.
#
# Usage:
#   shell::exist_ini_section [-h] <file> <section>
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
#   shell::exist_ini_section config.ini MySection  # Checks if MySection exists in config.ini.
shell::exist_ini_section() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_SECTION_EXISTS"
        return 0
    fi

    local file="$1"
    local section="$2"

    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ]; then
        shell::colored_echo "shell::exist_ini_section: Missing required parameters" 196
        echo "Usage: shell::exist_ini_section [-h] <file> <section>"
        return 1
    fi

    # Validate section name only if strict mode is enabled
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::validate_ini_section_name "$section" || return 1
    fi

    # Check if file exists
    if [ ! -f "$file" ]; then
        shell::colored_echo "File not found: $file" 196
        return 1
    fi

    # Escape section for regex pattern
    local escaped_section
    escaped_section=$(shell::ini_escape_for_regex "$section")

    shell::colored_echo "DEBUG: Checking if section '$section' exists in file: $file" 244

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

# shell::add_ini_section function
# Adds a new section to a specified INI file if it does not already exist.
#
# Usage:
#   shell::add_ini_section [-h] <file> <section>
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
#   shell::add_ini_section config.ini NewSection  # Adds NewSection to config.ini if it doesn't exist.
shell::add_ini_section() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_ADD_SECTION"
        return 0
    fi

    local file="$1"
    local section="$2"

    if [ -z "$file" ] || [ -z "$section" ]; then
        shell::colored_echo "shell::add_ini_section: Missing required parameters" 196
        echo "Usage: shell::add_ini_section [-h] <file> <section>"
        return 1
    fi

    # Validate section name only if strict mode is enabled
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::validate_ini_section_name "$section" || return 1
    fi

    # Check and create file if needed
    shell::create_file_if_not_exists "$file"

    # Check if section already exists
    if shell::exist_ini_section "$file" "$section"; then
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
    shell::colored_echo "INFO: Successfully added section: $section" 46
    return 0
}

# shell::write_ini function
# Writes a key-value pair to a specified section in an INI file.
#
# Usage:
#   shell::write_ini [-h] <file> <section> <key> <value>
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
#   shell::write_ini config.ini MySection MyKey MyValue  # Writes MyKey=MyValue in MySection.
shell::write_ini() {
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
        echo "Usage: shell::write_ini [-h] <file> <section> <key> <value>"
        return 1
    fi

    # Validate section and key names only if strict mode is enabled
    # Assumes shell::validate_ini_section_name and shell::validate_ini_key_name exist.
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::validate_ini_section_name "$section" || return 1
        shell::validate_ini_key_name "$key" || return 1
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
    # Assumes shell::add_ini_section function exists and handles adding a blank line
    # before a new section if the file is not empty.
    shell::add_ini_section "$file" "$section" || return 1

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
    temp_file=$(shell::create_ini_temp_file)

    shell::colored_echo "DEBUG: Writing key '$key' with value '$value' to section '$section' in file: $file" 244

    # Special handling for values with quotes or special characters (remains the same)
    # Assumes SHELL_INI_STRICT is defined.
    if [ "${SHELL_INI_STRICT}" -eq 1 ] && [[ "$value" =~ [[:space:]\"\'\`\&\|\<\>\;\$] ]]; then
        value="\"${value//\"/\\\"}\""
        shell::colored_echo "Value contains special characters, quoting: $value" 11
    fi

    # Sanitize the key to ensure it is a valid variable name.
    key=$(shell::sanitize_upper_var_name "$key")

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
                # Encode the value using Base64 and remove any newlines
                local encoded_value
                encoded_value=$(echo -n "$value" | base64 | tr -d '\n')
                echo "$key=$encoded_value" >>"$temp_file"
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
                # Encode the value using Base64 and remove any newlines
                local encoded_value
                encoded_value=$(echo -n "$value" | base64 | tr -d '\n')
                echo "$key=$encoded_value" >>"$temp_file"
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
        # Encode the value using Base64 and remove any newlines
        local encoded_value
        encoded_value=$(echo -n "$value" | base64 | tr -d '\n')
        echo "$key=$encoded_value" >>"$temp_file"
        key_handled=1 # Mark as added
    fi

    # Use atomic operation to replace the original file.
    # This is safer than removing the original and renaming the temp file,
    # as it reduces the window where the file might be missing.
    mv "$temp_file" "$file"

    # Provide feedback based on whether the key was updated or added.
    if [ $key_handled -eq 1 ]; then
        shell::colored_echo "INFO: Successfully wrote key '$key' with value '$value' to section '$section'" 46
    else
        # This case should ideally not be reached if shell::add_ini_section ensures
        # the section exists and the logic is correct. It's a safeguard.
        shell::colored_echo "WARN: Section '$section' processed, but key '$key' was not added or updated." 11
        return 1
    fi

    return 0
}

# shell::remove_ini_section function
# Removes a specified section and its key-value pairs from an INI formatted file.
#
# Usage:
#   shell::remove_ini_section <file> <section>
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
#   shell::remove_ini_section /path/to/config.ini "database"
#
# Notes:
#   - Assumes the INI file has sections enclosed in square brackets (e.g., [section]).
#   - Empty lines and lines outside of sections are preserved.
#   - Relies on helper functions like shell::colored_echo, shell::ini_escape_for_regex,
#     shell::create_ini_temp_file, and optionally shell::validate_ini_section_name
#     if SHELL_INI_STRICT is enabled. (Note: shell::ini_escape_for_regex and
#     shell::create_ini_temp_file are not provided in this snippet, but are assumed
#     to exist based on usage.)
#   - Uses atomic operation (mv) to replace the original file, reducing risk of data loss.
shell::remove_ini_section() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_REMOVE_SECTION"
        return 0
    fi

    local file="$1"
    local section="$2"

    # Validate required parameters: file path and section name.
    if [ -z "$file" ] || [ -z "$section" ]; then
        shell::colored_echo "shell::remove_ini_section: Missing required parameters" 196
        echo "Usage: shell::remove_ini_section [-h] <file> <section>"
        return 1
    fi

    # Validate section name only if strict mode is enabled (optional, based on existing code).
    # Assumes shell::validate_ini_section_name function exists.
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::validate_ini_section_name "$section" || return 1
    fi

    # Check if the specified file exists.
    if [ ! -f "$file" ]; then
        shell::colored_echo "File not found: $file" 196
        return 1
    fi

    # Check if the section exists in the file
    local escaped_section
    escaped_section=$(shell::ini_escape_for_regex "$section")
    if ! grep -q "^\[$escaped_section\]" "$file"; then
        shell::colored_echo "Section '$section' not found in file: $file" 11
        return 0
    fi

    shell::colored_echo "DEBUG: Removing section '$section' from file: $file" 244

    local section_pattern="^\[$escaped_section\]" # Regex for the target section header
    local any_section_pattern="^\[[^]]+\]"        # Regex for any section header
    local in_target_section=0                     # Flag: are we in the target section?
    local section_removed=0                       # Flag: has the section been removed?
    local temp_file
    temp_file=$(shell::create_ini_temp_file)
    local last_line_was_blank=0 # Flag: was the last written line blank?

    # Process the file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        # Trim the line for processing but preserve the original for output
        local trimmed_line
        trimmed_line=$(shell::trim_ini "$line")

        # Check if the line is empty
        if [ -z "$trimmed_line" ]; then
            # Only write a blank line if the last written line was not blank
            if [ $last_line_was_blank -eq 0 ] && [ -s "$temp_file" ]; then
                echo "" >>"$temp_file"
                last_line_was_blank=1
            fi
            continue
        fi

        # Check if the line is a section header
        if [[ "$trimmed_line" =~ $any_section_pattern ]]; then
            if [[ "$trimmed_line" =~ $section_pattern ]]; then
                # Found the target section header; skip it and enter the section
                in_target_section=1
                section_removed=1
                continue
            else
                # Found a different section header; exit the target section
                in_target_section=0
                # Only add a blank line if the last written line was not blank and the temp file is not empty
                if [ $last_line_was_blank -eq 0 ] && [ -s "$temp_file" ]; then
                    echo "" >>"$temp_file"
                    last_line_was_blank=1
                fi
                echo "$line" >>"$temp_file"
                last_line_was_blank=0
                continue
            fi
        fi

        # If not in the target section, write the line to the temp file
        if [ $in_target_section -eq 0 ]; then
            # Skip writing if the line is empty and we're at the start of the file
            if [ ! -s "$temp_file" ] && [ -z "$trimmed_line" ]; then
                continue
            fi
            echo "$line" >>"$temp_file"
            last_line_was_blank=0
        fi
    done <"$file"

    # Construct the command to replace the original file
    local replace_cmd="mv \"$temp_file\" \"$file\""

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$replace_cmd"
        shell::colored_echo "INFO: Dry-run: Would remove section '$section' from '$file'" 46
    else
        shell::run_cmd_eval "$replace_cmd"
        if [ $? -eq 0 ] && [ $section_removed -eq 1 ]; then
            shell::colored_echo "INFO: Successfully removed section '$section'" 46
        else
            shell::colored_echo "ERR: removing section '$section'" 196
            return 1
        fi
    fi

    return 0
}

# shell::fzf_remove_ini_key function
# Interactively selects a key from a specific section in an INI file using fzf
# and then removes the selected key from that section.
#
# Usage:
#   shell::fzf_remove_ini_key [-n] <file> <section>
#
# Parameters:
#   - -n        : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - <file>    : The path to the INI file.
#   - <section> : The section within the INI file from which to remove a key.
#
# Description:
#   This function validates the input file and section, lists keys within the section
#   using shell::list_ini_keys, presents the keys for interactive selection using fzf,
#   and then removes the chosen key-value pair from the specified section in the INI file.
#   It handles cases where the file or section does not exist and provides feedback
#   using shell::colored_echo.
#
# Example:
#   shell::fzf_remove_ini_key config.ini "Database"  # Interactively remove a key from the Database section.
#   shell::fzf_remove_ini_key -n settings.ini "API"  # Dry-run: show commands to remove a key from the API section.
shell::fzf_remove_ini_key() {
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
        shell::colored_echo "shell::fzf_remove_ini_key: Missing required parameters" 196
        echo "Usage: shell::fzf_remove_ini_key [-n] <file> <section>"
        return 1
    fi

    local file="$1"
    local section="$2"

    # Check if the specified file exists.
    if ! shell::check_ini_file "$file"; then
        # shell::check_ini_file prints an error if the file is not found
        return 1
    fi

    # Check if the section exists in the file.
    if ! shell::exist_ini_section "$file" "$section"; then
        # shell::exist_ini_section prints an error if the section is not found
        return 1
    fi

    # Ensure fzf is installed.
    shell::install_package fzf || {
        shell::colored_echo "ERR: fzf is required but could not be installed." 196
        return 1
    }

    # Get the list of keys in the specified section and use fzf to select one.
    local selected_key
    selected_key=$(shell::list_ini_keys "$file" "$section" | fzf --prompt="Select key to remove from section '$section': ")

    # Check if a key was selected.
    if [ -z "$selected_key" ]; then
        shell::colored_echo "ERR: No key selected. Aborting removal." 196
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
    temp_file=$(shell::create_ini_temp_file)

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
                shell::colored_echo "INFO: Successfully removed key '$selected_key' from section '$section'" 46
            else
                # This case should not be reached if shell::list_ini_keys and fzf worked correctly,
                # but it's a safeguard.
                shell::colored_echo "WARN: Key '$selected_key' was selected but not found in section '$section' during removal process." 11
                return 1
            fi
        else
            shell::colored_echo "ERR: replacing the original file after key removal." 196
            return 1
        fi
    fi

    return 0
}

# shell::remove_ini_key function
# Removes a specified key from a specific section in an INI formatted file.
#
# Usage:
#   shell::remove_ini_key [-n] <file> <section> <key>
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
#   shell::remove_ini_key /path/to/config.ini "database" "username"
#   shell::remove_ini_key -n /path/to/config.ini "api" "api_key" # Dry-run mode
#
# Notes:
#   - Assumes the INI file has sections enclosed in square brackets (e.g., [section]) and key=value pairs.
#   - Empty lines and lines outside of sections are preserved.
#   - Relies on helper functions like shell::colored_echo, shell::ini_escape_for_regex,
#     shell::create_ini_temp_file, and optionally shell::validate_ini_section_name,
#     shell::validate_ini_key_name if SHELL_INI_STRICT is enabled.
#   - Uses atomic operation (mv) to replace the original file, reducing risk of data loss.
shell::remove_ini_key() {
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
        shell::colored_echo "shell::remove_ini_key: Missing required parameters" 196
        echo "Usage: shell::remove_ini_key [-n] <file> <section> <key>"
        return 1
    fi

    local file="$1"
    local section="$2"
    local key="$3"

    # Validate section and key names only if strict mode is enabled (optional, based on existing code).
    # Assumes shell::validate_ini_section_name and shell::validate_ini_key_name functions exist.
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::validate_ini_section_name "$section" || return 1
        shell::validate_ini_key_name "$key" || return 1
    fi

    # Check if the specified file exists.
    if [ ! -f "$file" ]; then
        shell::colored_echo "File not found: $file" 196
        return 1
    fi

    # Check if the section exists in the file before attempting removal.
    if ! shell::exist_ini_section "$file" "$section"; then
        # shell::exist_ini_section prints an error if the section is not found
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
    temp_file=$(shell::create_ini_temp_file)

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
                shell::colored_echo "INFO: Successfully removed key '$key' from section '$section'" 46
                return 0
            else
                shell::colored_echo "WARN: Key '$key' not found in section '$section'." 11
                return 1
            fi
        else
            shell::colored_echo "ERR: replacing the original file after key removal." 196
            return 1
        fi
    fi
}

# shell::set_array_ini_value function
# Writes an array of values to a specified key in an INI file.
#
# Usage:
#   shell::set_array_ini_value [-h] <file> <section> <key> [value1] [value2 ...]
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
#   The final formatted string is passed to 'shell::write_ini' for atomic writing,
#   which handles file and section existence, creation, and updates.
#
# Example:
#   shell::set_array_ini_value config.ini MySection MyList "alpha" "beta gamma" "delta,epsilon"
#   # This would result in MyList=alpha,"beta gamma","delta,epsilon" in config.ini
#
# Returns:
#   0 on success, 1 on failure (e.g., missing parameters, underlying write failure).
#
# Notes:
#   - Relies on 'shell::colored_echo' for output and 'shell::write_ini' for file operations.
#   - Interaction with SHELL_INI_STRICT in 'shell::write_ini': If SHELL_INI_STRICT is set
#     to 1, 'shell::write_ini' might re-quote the entire array string generated by this
#     function if it contains spaces or quotes, potentially leading to double-quoting
#     (e.g., value becoming ""item1\",\"item 2""). This function aims to produce a
#     standard, internally-quoted INI array value.
shell::set_array_ini_value() {
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
        shell::colored_echo "ERR: shell::set_array_ini_value: Missing required parameters." 196
        echo "Usage: shell::set_array_ini_value [-h] <file> <section> <key> [value1] [value2 ...]"
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

    # Write the formatted array string to the INI file using shell::write_ini.
    shell::write_ini "$file" "$section" "$key" "$array_string"
    local status=$?

    # Provide feedback based on the operation's success.
    if [ $status -eq 0 ]; then
        shell::colored_echo "INFO: Successfully wrote array value for key '$key' to section '$section'." 46
    else
        shell::colored_echo "ERR: Failed to write array value for key '$key' to section '$section'." 196
    fi

    return $status
}

# shell::get_array_ini_value function
# Reads and parses an array of values from a specified key in an INI file.
#
# Usage:
#   shell::get_array_ini_value [-h] <file> <section> <key>
#
# Parameters:
#   - -h        : Optional. Displays this help message.
#   - <file>    : The path to the INI file.
#   - <section> : The section within the INI file to read the array from.
#   - <key>     : The key whose array of values is to be retrieved.
#
# Description:
#   This function first reads the raw string value of a specified key from an INI file
#   using 'shell::read_ini'. It then meticulously parses this string to extract
#   individual array elements. The parsing logic correctly handles comma delimiters
#   and preserves values enclosed in double quotes, including those containing
#   spaces, commas, or escaped double quotes within the value itself.
#   Each extracted item is then trimmed of leading/trailing whitespace.
#   The function outputs each parsed array item on a new line to standard output.
#
# Example:
#   # Assuming 'my_config.ini' contains:
#   # [Settings]
#   # MyArray=item1,\"item with spaces\",\"item,with,commas\",\"item with \\\"escaped\\\" quotes\"
#
#   shell::get_array_ini_value my_config.ini Settings MyArray
#   # Expected output:
#   # item1
#   # item with spaces
#   # item,with,commas
#   # item with "escaped" quotes
#
# Returns:
#   0 on successful parsing and output, 1 on failure (e.g., missing parameters,
#   file/section/key not found).
#   The parsed array items are echoed to standard output, one per line.
#
# Notes:
#   - Relies on 'shell::read_ini' to retrieve the raw value.
#   - Relies on 'shell::trim_ini' for whitespace removal from individual items.
#   - The parsing logic is custom-built to handle INI-style quoted comma-separated lists.
#   - Interaction with SHELL_INI_STRICT in 'shell::write_ini': Values formatted by
#     'shell::set_array_ini_value' (which are read by this function) are intended to be
#     interpreted as single strings by 'shell::write_ini'. If 'SHELL_INI_STRICT' is 1
#     during writing, the entire formatted string might be re-quoted. This function correctly
#     parses values regardless of outer re-quoting, as it targets the internal array structure.
shell::get_array_ini_value() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_GET_ARRAY_VALUE"
        return 0
    fi

    local file="$1"
    local section="$2"
    local key="$3"

    # Validate required parameters.
    if [ -z "$file" ] || [ -z "$section" ] || [ -z "$key" ]; then
        shell::colored_echo "ERR: shell::get_array_ini_value: Missing required parameters." 196
        echo "Usage: shell::get_array_ini_value [-h] <file> <section> <key>"
        return 1
    fi

    # Read the raw string value from the INI file.
    local value
    # Capture stderr from shell::read_ini to prevent its error messages from appearing if not desired,
    # but still allow it to return status.
    value=$(shell::read_ini "$file" "$section" "$key")
    local ini_read_status=$?

    # Check if shell::read_ini failed (e.g., file/section/key not found).
    if [ $ini_read_status -ne 0 ]; then
        # shell::read_ini already prints specific error messages, so just indicate general failure here.
        shell::colored_echo "ERR: Failed to read raw value for key '$key' from section '$section'." 196
        return 1
    fi

    local -a result=()
    local in_quotes=0
    local current_item=""
    local char

    # Iterate through the string character by character to parse the array.
    for ((i = 0; i < ${#value}; i++)); do
        char="${value:$i:1}"

        if [ "$char" = '"' ]; then
            # Handle escaped quotes: if the previous character was a backslash,
            # it's an escaped quote, so remove the backslash and add the literal quote.
            if [ $i -gt 0 ] && [ "${value:$((i - 1)):1}" = "\\" ]; then
                current_item="${current_item:0:-1}\"" # Remove trailing backslash, add literal quote.
            else
                # Toggle the 'in_quotes' state for unescaped double quotes.
                in_quotes=$((1 - in_quotes))
            fi
        elif [ "$char" = ',' ] && [ "$in_quotes" -eq 0 ]; then
            # If a comma is encountered outside of quotes, it signifies the end of an item.
            result+=("$(shell::trim_ini "$current_item")") # Add the trimmed item to the result array.
            current_item=""                                # Reset current_item for the next element.
        else
            # Append the current character to the current item being built.
            current_item="$current_item$char"
        fi
    done

    # After the loop, add the last accumulated item.
    # This conditional ensures that:
    # 1. A non-empty 'current_item' is always added.
    # 2. An empty 'current_item' is added if it implies a trailing comma (result already has items).
    # 3. Nothing is added if the initial 'value' was entirely empty (no items parsed, current_item is empty).
    if [ -n "$current_item" ] || [ ${#result[@]} -gt 0 ]; then
        result+=("$(shell::trim_ini "$current_item")")
    fi

    # Output each item of the parsed array on a new line.
    if [ ${#result[@]} -gt 0 ]; then
        for item in "${result[@]}"; do
            echo "$item"
        done
    else
        # This case covers scenarios where the key exists but its value is empty or malformed
        # such that no discernible items were parsed.
        shell::colored_echo "WARN: Key '$key' found in section '$section', but no array items could be parsed. Check format." 33
    fi

    return 0
}

# shell::exist_ini_key function
# Checks if a specified key exists within a section in an INI file.
#
# Usage:
#   shell::exist_ini_key [-h] <file> <section> <key>
#
# Parameters:
#   - -h        : Optional. Displays this help message.
#   - <file>    : The path to the INI file.
#   - <section> : The section within the INI file to check.
#   - <key>     : The key to check for existence.
#
# Description:
#   This function provides a convenient way to verify the presence of a specific
#   key within a designated section of an INI configuration file. It acts as a
#   wrapper around 'shell::read_ini', using its capabilities to determine if
#   the key can be successfully retrieved.
#   If strict mode is active (SHELL_INI_STRICT is set to 1), it first
#   validates the format of the section and key names, returning an error if
#   they do not conform to the defined naming conventions.
#   The function ensures its own output is clean by suppressing the internal
#   logging of 'shell::read_ini', providing clear, colored messages indicating
#   whether the key was found or not.
#
# Example:
#   # Check if a 'port' key exists in the 'Network' section of 'settings.ini'
#   if shell::exist_ini_key settings.ini Network port; then
#     shell::colored_echo "Found 'port' setting." 46
#   else
#     shell::colored_echo "The 'port' setting is missing." 196
#   fi
#
# Returns:
#   0 (success) if the key exists in the specified section and file.
#   1 (failure) if the key does not exist, or if required parameters are missing,
#     or if validation fails (in strict mode).
#   Outputs status messages using 'shell::colored_echo' to standard error.
#
# Notes:
#   - This function does not output the value of the key, only its existence status.
#   - It leverages 'shell::read_ini' and other 'shell::ini_validate_*' functions for its operations.
#   - For detailed reasons why a key might not be found (e.g., file doesn't exist,
#     section doesn't exist), 'shell::read_ini' or 'shell::exist_ini_section'
#     will provide their own specific error messages if called directly.
shell::exist_ini_key() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_KEY_EXISTS"
        return 0
    fi

    local file="$1"
    local section="$2"
    local key="$3"

    # Validate required parameters.
    if [ -z "$file" ] || [ -z "$section" ] || [ -z "$key" ]; then
        shell::colored_echo "ERR: shell::exist_ini_key: Missing required parameters: file, section, or key." 196
        echo "Usage: shell::exist_ini_key [-h] <file> <section> <key>"
        return 1
    fi

    # Validate section and key names if strict mode is enabled.
    # The called validation functions will print their own error messages if validation fails.
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::validate_ini_section_name "$section" || return 1
        shell::validate_ini_key_name "$key" || return 1
    fi

    # Attempt to read the key's value.
    # Redirect stdout and stderr to /dev/null to prevent shell::read_ini's output/errors
    # from cluttering the console, as this function provides its own status messages.
    if shell::read_ini "$file" "$section" "$key" >/dev/null 2>&1; then
        shell::colored_echo "INFO: Key found: '$key' in section '$section'." 46
        return 0
    else
        shell::colored_echo "ERR: Key not found: '$key' in section '$section'." 196
        return 1
    fi
}

# shell::expose_ini_env function
# Exports key-value pairs from an INI file as environment variables.
#
# Usage:
#   shell::expose_ini_env [-h] <file> [prefix] [section]
#
# Parameters:
#   - -h        : Optional. Displays this help message.
#   - <file>    : The path to the INI file to read.
#   - [prefix]  : Optional. A string prefix to prepend to all environment variable names.
#                 If provided, variables will be named like \`PREFIX_SECTION_KEY\`.
#                 If omitted, variables will be named like \`SECTION_KEY\`.
#   - [section] : Optional. If specified, only keys from this specific section will
#                 be exported. If omitted, keys from all sections will be exported.
#
# Description:
#   This function provides a convenient way to load INI configuration into the
#   current shell's environment. It iterates through the specified INI file,
#   reading section and key-value pairs, and then uses the 'export' command
#   to make them available as environment variables.
#
#   To ensure compatibility with shell variable naming conventions, all section
#   and key names used in the environment variable name (e.g., SECTION_KEY) are
#   automatically sanitized. This involves converting them to uppercase and
#   replacing any non-alphanumeric or non-underscore characters with underscores.
#
#   If a specific section is provided, only the keys within that section are
#   processed. If no section is given, all readable sections and their keys
#   across the entire file are exported.
#
# Example:
#   # Export database credentials from 'db.ini' with 'DB_APP' prefix
#   # assuming db.ini contains:
#   # [production]
#   # host=localhost
#   # user=db.user
#   # pass=db.pass
#   shell::expose_ini_env db.ini DB_APP production
#   echo $DB_APP_PRODUCTION_HOST # Outputs 'localhost'
#
# Returns:
#   0 (success) if the export process completes without critical errors.
#   1 (failure) if the INI file is not found, required parameters are missing,
#     or if underlying functions report an error (e.g., invalid section/key name
#     in strict mode).
#   Outputs colored status messages to standard error.
#
# Notes:
#   - This function does not modify the INI file.
#   - Variable names in the environment are derived from sanitized section and
#     key names. For instance, a section '[My Config]' and key 'api-key' would
#     become 'MY_CONFIG_API_KEY'.
#   - Values containing special characters are exported as-is; it's the calling
#     script's responsibility to handle such values.
#   - This function uses process substitution (`< <(...)`) for portability
#     when iterating over lists of sections/keys, making it compatible with
#     older Bash versions (e.g., Bash 3 on macOS) as well as newer ones.
#   - If a key's value cannot be read (e.g., key not found by ini_read), that
#     specific key will be skipped in the export process, and a warning will be
#     logged.
shell::expose_ini_env() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_TO_ENV"
        return 0
    fi

    local file="$1"
    local prefix="$2"
    local section="$3"

    # Validate required parameters.
    if [ -z "$file" ]; then
        shell::colored_echo "ERR: shell::expose_ini_env: Missing file parameter." 196
        echo "Usage: shell::expose_ini_env [-h] <file> [prefix] [section]"
        return 1
    fi

    # Check if file exists.
    if [ ! -f "$file" ]; then
        shell::colored_echo "ERR: File not found: $file" 196
        return 1
    fi

    shell::colored_echo "🔵 Exporting INI values to environment variables from '$file' (prefix: '$prefix', section: '$section')." 11

    # If a specific section is specified, only export keys from that section.
    if [ -n "$section" ]; then
        # Validate section name if strict mode is enabled.
        if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
            shell::validate_ini_section_name "$section" || return 1
        fi

        # Safely read keys line by line using process substitution to handle spaces in names.
        while IFS= read -r key; do
            local value
            # Attempt to read the key's value. Suppress ini_read's output for cleaner logging here.
            value=$(shell::read_ini "$file" "$section" "$key" 2>/dev/null)
            local read_status=$? # Capture exit status of shell::read_ini

            # Only export if shell::read_ini was successful (key found and read).
            if [ $read_status -eq 0 ]; then
                local sanitized_section
                sanitized_section=$(shell::sanitize_upper_var_name "$section")
                local sanitized_key
                sanitized_key=$(shell::sanitize_upper_var_name "$key")

                local var_name
                if [ -n "$prefix" ]; then
                    local sanitized_prefix
                    sanitized_prefix=$(shell::sanitize_upper_var_name "$prefix")
                    var_name="${sanitized_prefix}_${sanitized_section}_${sanitized_key}"
                else
                    var_name="${sanitized_section}_${sanitized_key}"
                fi

                export "${var_name}=${value}"
                shell::colored_echo "  ✅ Exported: ${var_name}=${value}" 46
            else
                shell::colored_echo "  WARN: Failed to read key '$key' from section '$section'. Skipping export." 33
            fi
        done < <(shell::list_ini_keys "$file" "$section") # Use process substitution for robust key listing

    else # No specific section specified, export keys from all sections.
        # Safely read sections line by line.
        while IFS= read -r current_section; do
            # Validate current section name if strict mode is enabled.
            if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
                shell::validate_ini_section_name "$current_section" || {
                    shell::colored_echo "ERR: Skipping invalid section name '$current_section' in strict mode." 196
                    continue # Skip to the next section
                }
            fi

            # Safely read keys from the current section.
            while IFS= read -r key; do
                local value
                # Attempt to read the key's value. Suppress ini_read's output for cleaner logging here.
                value=$(shell::read_ini "$file" "$current_section" "$key" 2>/dev/null)
                local read_status=$?

                if [ $read_status -eq 0 ]; then
                    local sanitized_section
                    sanitized_section=$(shell::sanitize_upper_var_name "$current_section")
                    local sanitized_key
                    sanitized_key=$(shell::sanitize_upper_var_name "$key")

                    local var_name
                    if [ -n "$prefix" ]; then
                        local sanitized_prefix
                        sanitized_prefix=$(shell::sanitize_upper_var_name "$prefix")
                        var_name="${sanitized_prefix}_${sanitized_section}_${sanitized_key}"
                    else
                        var_name="${sanitized_section}_${sanitized_key}"
                    fi

                    export "${var_name}=${value}"
                    shell::colored_echo "  ✅ Exported: ${var_name}=${value}" 46
                else
                    shell::colored_echo "  WARN: Failed to read key '$key' from section '$current_section'. Skipping export." 33
                fi
            done < <(shell::list_ini_keys "$file" "$current_section")
        done < <(shell::list_ini_sections "$file")
    fi

    shell::colored_echo "INFO: Environment variables export completed." 46
    return 0
}

# shell::destroy_ini_env function
# Unsets environment variables previously exported from an INI file.
#
# Usage:
#   shell::destroy_ini_env [-h] <file> [prefix] [section]
#
# Parameters:
#   - -h        : Optional. Displays this help message.
#   - <file>    : The path to the INI file that was used for exporting variables.
#   - [prefix]  : Optional. The same prefix that was used during the export (e.g., 'APP_CONFIG').
#                 If provided, only variables with this prefix will be targeted.
#   - [section] : Optional. If specified, only variables corresponding to keys from
#                 this specific section will be unset. If omitted, keys from all
#                 sections (matching the prefix, if given) will be targeted.
#
# Description:
#   This function serves to clean up environment variables that were previously
#   populated using 'shell::expose_ini_env'. It reconstructs the expected names of
#   these environment variables by parsing the provided INI file (or a specified
#   subset) and applying the same sanitization and prefixing logic as
#   'shell::expose_ini_env'.
#
#   For each potential environment variable name, the function checks if it is
#   currently set in the shell's environment. If found, the variable is
#   then unset, effectively removing it from the current session. This helps in
#   maintaining a clean environment or switching between different configurations.
#
#   It's important to use the identical parameters (file, prefix, section) that
#   were supplied during the initial export to ensure that the correct set of
#   variables is targeted for destruction.
#
# Example:
#   # To export variables from 'dev.ini' with prefix 'DEV_APP':
#   # shell::expose_ini_env dev.ini DEV_APP
#   # To then destroy these variables:
#   # shell::destroy_ini_env dev.ini DEV_APP
#
# Returns:
#   0 (success) on completion of the unsetting process.
#   1 (failure) if the INI file is not found or required parameters are missing.
#   Outputs colored status messages to standard error.
#
# Notes:
#   - This function does not report individual errors if a variable was expected
#     but not found or already unset; it simply proceeds.
#   - The function's effectiveness relies on matching the naming convention of
#     'shell::expose_ini_env'.
#   - This function uses process substitution (`< <(...)`) for portability
#     when iterating over lists of sections/keys, making it compatible with
#     older Bash versions (e.g., Bash 3 on macOS) as well as newer ones.
shell::destroy_ini_env() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_DESTROY_KEYS"
        return 0
    fi

    local file="$1"
    local prefix="$2"
    local section="$3"

    # Validate required parameters.
    if [ -z "$file" ]; then
        shell::colored_echo "ERR: shell::destroy_ini_env: Missing file parameter." 196
        echo "Usage: shell::destroy_ini_env [-h] <file> [prefix] [section]"
        return 1
    fi

    # Check if file exists.
    if [ ! -f "$file" ]; then
        shell::colored_echo "ERR: File not found: $file" 196
        return 1
    fi

    # If a specific section is specified, only target keys from that section.
    if [ -n "$section" ]; then
        # Validate section name if strict mode is enabled.
        if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
            shell::validate_ini_section_name "$section" || {
                shell::colored_echo "ERR: Cannot destroy keys: Invalid section name '$section' in strict mode." 196
                return 1
            }
        fi

        local sanitized_section
        sanitized_section=$(shell::sanitize_upper_var_name "$section")

        # Safely read keys line by line using process substitution.
        while IFS= read -r key; do
            local sanitized_key
            sanitized_key=$(shell::sanitize_upper_var_name "$key")

            local var_name
            if [ -n "$prefix" ]; then
                local sanitized_prefix
                sanitized_prefix=$(shell::sanitize_upper_var_name "$prefix")
                var_name="${sanitized_prefix}_${sanitized_section}_${sanitized_key}"
            else
                var_name="${sanitized_section}_${sanitized_key}"
            fi

            # Check if the variable is set before unsetting.
            # 'declare -p' is used for robust variable existence check across Bash versions.
            if declare -p "$var_name" &>/dev/null; then
                unset "$var_name"
                shell::colored_echo "📍 Unset: ${var_name}" 208
            fi
        done < <(shell::list_ini_keys "$file" "$section")

    else # No specific section specified, target keys from all sections.
        # Safely read sections line by line.
        while IFS= read -r current_section; do
            # Validate current section name if strict mode is enabled.
            if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
                shell::validate_ini_section_name "$current_section" || {
                    shell::colored_echo "ERR: Skipping section with invalid name '$current_section' in strict mode." 196
                    continue
                }
            fi

            local sanitized_section
            sanitized_section=$(shell::sanitize_upper_var_name "$current_section")

            # Safely read keys from the current section.
            while IFS= read -r key; do
                local sanitized_key
                sanitized_key=$(shell::sanitize_upper_var_name "$key")

                local var_name
                if [ -n "$prefix" ]; then
                    local sanitized_prefix
                    sanitized_prefix=$(shell::sanitize_upper_var_name "$prefix")
                    var_name="${sanitized_prefix}_${sanitized_section}_${sanitized_key}"
                else
                    var_name="${sanitized_section}_${sanitized_key}"
                fi

                if declare -p "$var_name" &>/dev/null; then
                    unset "$var_name"
                    shell::colored_echo "  🗑️ Unset: ${var_name}" 208
                fi
            done < <(shell::list_ini_keys "$file" "$current_section")
        done < <(shell::list_ini_sections "$file")
    fi

    shell::colored_echo "INFO: Environment variables destruction completed." 46
    return 0
}

# shell::get_or_default_ini_value function
# Reads a key's value from an INI file or returns a default if not found.
#
# Usage:
#   shell::get_or_default_ini_value [-h] <file> <section> <key> [default_value]
#
# Parameters:
#   - -h          : Optional. Displays this help message.
#   - <file>      : The path to the INI file.
#   - <section>   : The section within the INI file to search.
#   - <key>       : The key whose value is to be retrieved.
#   - [default_value]: Optional. The value to return if the key is not found
#                     or if reading fails. Defaults to an empty string if omitted.
#
# Description:
#   This function attempts to retrieve a configuration value from an INI file.
#   It takes the file path, section name, and key as mandatory arguments.
#   An optional 'default_value' can be provided.
#
#   The function first tries to read the key's value using 'shell::read_ini'.
#   If 'shell::read_ini' successfully finds and returns a value (exit status 0),
#   that value is echoed to standard output.
#   If 'shell::read_ini' fails to find the key or encounters any other issue
#   (e.g., file not found, section not found), the 'default_value' is echoed
#   to standard output instead. If 'default_value' is not provided, an empty
#   string is used as the default.
#
#   This function always returns 0 on completion (indicating that a value,
#   either read or default, was provided), unless there are missing mandatory
#   parameters.
#
# Example:
#   # Read 'timeout' from 'Network' section, default to '30'
#   TIMEOUT=$(shell::get_or_default_ini_value app.ini Network timeout 30)
#   echo "Connection Timeout: $TIMEOUT seconds"
#
#   # Read 'feature_flag' or default to empty string
#   FLAG=$(shell::get_or_default_ini_value settings.ini Features feature_flag)
#   if [ "$FLAG" = "enabled" ]; then
#     echo "Feature is ON."
#   fi
#
# Returns:
#   0 (success) if the function completes and provides a value (either read or default).
#   1 (failure) if mandatory parameters (file, section, key) are missing.
#   The retrieved value or default value is echoed to standard output.
#
# Notes:
#   - 'shell::read_ini' error messages (e.g., "File not found", "Key not found") are
#     suppressed to avoid clutter when a default value is being returned.
#     This function provides its own consolidated logging.
#   - Ensures cross-platform compatibility by relying on standard Bash features
#     and existing cross-platform helper functions.
shell::get_or_default_ini_value() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_GET_OR_DEFAULT"
        return 0
    fi

    local file="$1"
    local section="$2"
    local key="$3"
    local default_value="${4:-}"

    # Validate mandatory parameters.
    if [ -z "$file" ] || [ -z "$section" ] || [ -z "$key" ]; then
        shell::colored_echo "ERR: shell::get_or_default_ini_value: Missing required parameters: file, section, or key." 196
        echo "Usage: shell::get_or_default_ini_value [-h] <file> <section> <key> [default_value]"
        return 1
    fi

    local value
    # Try to read the value, suppressing shell::read_ini's error output.
    value=$(shell::read_ini "$file" "$section" "$key" 2>/dev/null)
    local read_status=$?

    # Return the value if read successfully, otherwise return the default_value.
    if [ $read_status -eq 0 ]; then
        echo "$value"
    else
        echo "$default_value"
    fi

    return 0
}

# shell::rename_ini_section function
# Renames an existing section in an INI file.
#
# Usage:
#   shell::rename_ini_section [-n] <file> <old_section> <new_section>
#
# Parameters:
#   - -n          : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - <file>      : The path to the INI file.
#   - <old_section> : The current name of the section to be renamed.
#   - <new_section> : The new name for the section.
#
# Description:
#   This function renames a section within an INI file by replacing its header.
#   It performs validation to ensure the file exists, the old section exists,
#   and the new section name does not already exist. It also applies strict
#   validation rules for section names if SHELL_INI_STRICT is enabled.
#   The function uses 'sed' for in-place editing, adapting its syntax for
#   macOS (BSD sed) and Linux (GNU sed) for cross-platform compatibility.
#
# Example usage:
#   shell::rename_ini_section config.ini "OldSection" "NewSection"
#   shell::rename_ini_section -n settings.ini "Database" "ProductionDB" # Dry-run mode
#
# Returns:
#   0 on success, 1 on failure (e.g., missing parameters, file not found,
#   section not found, new section already exists, or validation failure).
#
# Notes:
#   - Relies on shell::colored_echo, shell::check_ini_file, shell::exist_ini_section,
#     shell::ini_escape_for_regex, shell::validate_ini_section_name, and shell::run_cmd_eval.
shell::rename_ini_section() {
    local dry_run="false"
    local opt_h_found="false"

    # Process options: -n and -h
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -n)
            dry_run="true"
            shift # Consume -n
            ;;
        -h)
            opt_h_found="true"
            shift # Consume -h
            ;;
        *)
            break # End of options
            ;;
        esac
    done

    # If -h was found, display usage and exit immediately regardless of other args
    if [ "$opt_h_found" = "true" ]; then
        echo "$USAGE_SHELL_INI_RENAME_SECTION"
        return 0
    fi

    # Validate required parameters: file, old_section, new_section.
    if [ $# -lt 3 ]; then
        shell::colored_echo "ERR: shell::rename_ini_section: Missing required parameters." 196
        echo "Usage: shell::rename_ini_section [-n] [-h] <file> <old_section> <new_section>"
        return 1
    fi

    local file="$1"
    local old_section="$2"
    local new_section="$3"

    # Validate section names if strict mode is enabled.
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::validate_ini_section_name "$old_section" || return 1
        shell::validate_ini_section_name "$new_section" || return 1
    fi

    # Check if the file exists and is writable.
    if ! shell::check_ini_file "$file"; then
        return 1
    fi

    # Check if the old section exists. Suppress output as shell::exist_ini_section
    # already provides verbose messages.
    if ! shell::exist_ini_section "$file" "$old_section" >/dev/null 2>&1; then
        shell::colored_echo "ERR: Section to rename ('$old_section') not found in file: $file" 196
        return 1
    fi

    # Check if the new section name already exists.
    if shell::exist_ini_section "$file" "$new_section" >/dev/null 2>&1; then
        shell::colored_echo "ERR: New section name ('$new_section') already exists in file: $file. Aborting rename." 196
        return 1
    fi

    local escaped_old_section
    escaped_old_section=$(shell::ini_escape_for_regex "$old_section")

    local os_type
    os_type=$(shell::get_os_type)
    local sed_cmd=""

    # Construct the sed command for in-place editing based on OS type.
    # The 's' command replaces the matched pattern.
    if [ "$os_type" = "macos" ]; then
        # BSD sed on macOS requires an empty string backup extension with -i.
        sed_cmd="sed -i '' \"s/^\[${escaped_old_section}\]$/\[${new_section}\]/\" \"$file\""
    else
        # GNU sed on Linux typically does not require a backup extension with -i.
        sed_cmd="sed -i \"s/^\[${escaped_old_section}\]$/\[${new_section}\]/\" \"$file\""
    fi

    shell::execute_or_evict "$dry_run" "$sed_cmd"
    if [ "$dry_run" = "false" ]; then
        shell::colored_echo "INFO: Successfully renamed section from '$old_section' to '$new_section'." 46
    fi
    return 0
}

# shell::fzf_rename_ini_section function
# Interactively selects a section from an INI file using fzf and renames it.
#
# Usage:
#   shell::fzf_rename_ini_section [-n] [-h] <file>
#
# Parameters:
#   - -n     : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h     : Optional help flag. Displays this help message.
#   - <file> : The path to the INI file.
#
# Description:
#   This function first lists all sections in the specified INI file using
#   shell::list_ini_sections. It then presents these sections to the user
#   via fzf for interactive selection. Once a section is chosen, the user is
#   prompted to enter a new name for it. The renaming operation is then
#   delegated to the shell::rename_ini_section function.
#   It includes checks for file existence and fzf installation.
#
# Example:
#   shell::fzf_rename_ini_section config.ini  # Interactively rename a section in config.ini.
#   shell::fzf_rename_ini_section -n settings.ini # Dry-run: show commands to rename a section.
#
# Returns:
#   0 on success, 1 on failure (e.g., missing file, no section selected,
#   fzf not installed, or underlying rename failure).
#
# Notes:
#   - Relies on shell::colored_echo, shell::install_package, shell::list_ini_sections,
#     and shell::rename_ini_section.
shell::fzf_rename_ini_section() {
    local dry_run="false"
    local opt_h_found="false" # Flag to track if -h was explicitly passed
    local file_param=""       # To store the actual file parameter after option parsing

    # Process options: -n and -h
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -n)
            dry_run="true"
            shift # Consume -n
            ;;
        -h)
            opt_h_found="true"
            shift # Consume -h
            ;;
        *)
            # Assuming the first non-option argument is the file
            file_param="$1"
            shift # Consume the file parameter
            break # Stop processing args as options, rest are positional
            ;;
        esac
    done

    # If -h was found, display usage and exit immediately regardless of other args
    if [ "$opt_h_found" = "true" ]; then
        echo "$USAGE_SHELL_FZF_INI_RENAME_SECTION"
        return 0
    fi

    # Validate required parameter: file path.
    if [ -z "$file_param" ]; then
        shell::colored_echo "ERR: shell::fzf_rename_ini_section: Missing required file parameter." 196
        echo "Usage: shell::fzf_rename_ini_section [-n] [-h] <file>"
        return 1
    fi

    local file="$file_param" # Assign to 'file' for consistency

    # Check if the specified file exists.
    if [ ! -f "$file" ]; then
        shell::colored_echo "ERR: File not found: $file" 196
        return 1
    fi

    # Ensure fzf is installed.
    shell::install_package fzf || {
        shell::colored_echo "ERR: fzf is required but could not be installed." 196
        return 1
    }

    # Get the list of sections and use fzf to select one.
    local selected_section
    selected_section=$(shell::list_ini_sections "$file" | fzf --prompt="Select section to rename: ")

    # Check if a section was selected.
    if [ -z "$selected_section" ]; then
        shell::colored_echo "ERR: No section selected. Aborting rename." 196
        return 1
    fi

    shell::colored_echo "Selected section for renaming: '$selected_section'" 33

    # Prompt for the new section name.
    shell::colored_echo ">> Enter new name for section '$selected_section':" 33
    read -r new_section
    if [ -z "$new_section" ]; then
        shell::colored_echo "ERR: No new section name entered. Aborting rename." 196
        return 1
    fi

    local rename_args=("$file" "$selected_section" "$new_section")
    if [ "$dry_run" = "true" ]; then
        rename_args=("-n" "${rename_args[@]}")
    fi
    shell::rename_ini_section "${rename_args[@]}"
}

# shell::clone_ini_section function
# Clones an existing section to a new section within the same INI file.
# All key-value pairs from the source section are copied to the destination section.
#
# Usage:
#   shell::clone_ini_section [-n] <file> <source_section> <destination_section>
#
# Parameters:
#   - -n                 : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - <file>             : The path to the INI file.
#   - <source_section>   : The name of the section to clone.
#   - <destination_section>: The name of the new section to create and copy keys into.
#
# Description:
#   This function first validates that the source section exists in the INI file.
#   It then checks if the destination section already exists, warning the user if it does.
#   It reads all key-value pairs from the source section and writes them sequentially
#   to the new destination section. This is achieved by iterating through the file content
#   between the source section header and the next section header (or end of file).
#   The function ensures file integrity by writing to a temporary file and then atomically
#   replacing the original file.
#
# Example:
#   shell::clone_ini_section config.ini "Development" "Staging"
#   shell::clone_ini_section -n config.ini "Production" "Backup_Prod"
#
# Returns:
#   0 on success, 1 on failure (e.g., missing parameters, file/section not found,
#   destination section already exists in strict mode, or write errors).
#
# Notes:
#   - Relies on shell::colored_echo, shell::exist_ini_section, shell::add_ini_section,
#     shell::write_ini, shell::create_ini_temp_file, and shell::ini_escape_for_regex.
#   - Honors SHELL_INI_STRICT for section name validation.
shell::clone_ini_section() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INI_CLONE_SECTION"
        return 0
    fi

    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    local file="$1"
    local source_section="$2"
    local destination_section="$3"

    # Validate parameters
    if [ -z "$file" ] || [ -z "$source_section" ] || [ -z "$destination_section" ]; then
        shell::colored_echo "ERR: shell::clone_ini_section: Missing required parameters." 196
        echo "Usage: shell::clone_ini_section [-n] [-h] <file> <source_section> <destination_section>"
        return 1
    fi

    # Validate section names if strict mode is enabled
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        shell::validate_ini_section_name "$source_section" || return 1
        shell::validate_ini_section_name "$destination_section" || return 1
    fi

    # Check if file exists
    if [ ! -f "$file" ]; then
        shell::colored_echo "ERR: File not found: $file" 196
        return 1
    fi

    # Check if source section exists
    if ! shell::exist_ini_section "$file" "$source_section"; then
        shell::colored_echo "ERR: Source section '$source_section' not found in file: $file" 196
        return 1
    fi

    # Check if destination section already exists
    if shell::exist_ini_section "$file" "$destination_section"; then
        shell::colored_echo "WARN: Destination section '$destination_section' already exists. Aborting clone to prevent overwrite." 11
        return 1
    fi

    shell::colored_echo "DEBUG: Cloning section '$source_section' to '$destination_section' in file: $file" 244

    local escaped_source_section
    escaped_source_section=$(shell::ini_escape_for_regex "$source_section")
    local source_section_start_pattern="^\[$escaped_source_section\]"
    local any_section_pattern="^\[[^]]+\]"

    local in_source_section_to_clone=0
    local cloned_section_content=""
    local temp_file
    temp_file=$(shell::create_ini_temp_file)

    # Read original file line by line to capture content and build the new file
    while IFS= read -r line || [ -n "$line" ]; do
        local trimmed_line
        trimmed_line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

        # Detect start of source section
        if [[ "$trimmed_line" =~ $source_section_start_pattern ]]; then
            in_source_section_to_clone=1
            echo "$line" >>"$temp_file" # Write original section header
            continue
        fi

        # Detect end of source section or beginning of new section for content capture
        if [ "$in_source_section_to_clone" -eq 1 ]; then
            if [[ "$trimmed_line" =~ $any_section_pattern ]]; then
                # We hit a new section, so the source section content ended here.
                in_source_section_to_clone=0
            else
                # Still inside the source section, add to cloned content.
                # Only add non-empty, non-comment lines to the cloned content.
                if [[ -n "$trimmed_line" && ! "$trimmed_line" =~ ^[[:space:]]*[#\;] ]]; then
                    cloned_section_content+="$line\n"
                fi
            fi
        fi
        # Always write the original line to the temp file to reconstruct the original content
        echo "$line" >>"$temp_file"
    done <"$file"

    # Append the new cloned section at the end of the temp file
    local append_cloned_section_cmd=""
    if [ -s "$temp_file" ]; then # Add a blank line only if the file isn't empty already
        append_cloned_section_cmd+="echo \"\" >>\"$temp_file\" && "
    fi
    append_cloned_section_cmd+="echo \"[$destination_section]\" >>\"$temp_file\""

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$append_cloned_section_cmd"
    else
        eval "$append_cloned_section_cmd"
    fi

    # Append the accumulated content for the cloned section
    if [ -n "$cloned_section_content" ]; then
        local append_cloned_content_cmd="echo -e \"${cloned_section_content%\\n}\" >>\"$temp_file\"" # Remove trailing newline
        if [ "$dry_run" = "true" ]; then
            shell::on_evict "$append_cloned_content_cmd"
        else
            eval "$append_cloned_content_cmd"
        fi
    fi

    # Atomically replace the original file with the modified temporary file
    local replace_cmd="mv \"$temp_file\" \"$file\""
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$replace_cmd"
    else
        shell::run_cmd_eval "$replace_cmd"
        if [ $? -eq 0 ]; then
            shell::colored_echo "INFO: Successfully cloned section '$source_section' to '$destination_section'." 46
            return 0
        else
            shell::colored_echo "ERR: replacing the original file after section clone." 196
            return 1
        fi
    fi
}

# shell::fzf_clone_ini_section function
# Interactively selects a section to clone from an INI file using fzf,
# prompts for a new name (with "_clone" prefix), and then clones the section.
#
# Usage:
#   shell::fzf_clone_ini_section [-n] <file>
#
# Parameters:
#   - -n        : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - <file>    : The path to the INI file.
#
# Description:
#   This function first ensures fzf is installed. It then lists all sections in the
#   given INI file and uses fzf to allow the user to interactively select a section.
#   After selection, it prompts the user for a new section name, appending "_clone"
#   to the selected section name as a suggestion. Finally, it calls
#   shell::clone_ini_section to perform the cloning operation.
#   The function handles dry-run mode, where it only prints the commands that would be executed.
#
# Example:
#   shell::fzf_clone_ini_section config.ini   # Interactively clone a section.
#   shell::fzf_clone_ini_section -n config.ini # Dry-run: show commands to clone a section.
#
# Returns:
#   0 on success, 1 on failure (e.g., missing parameters, file not found, no section selected).
#
# Notes:
#   - Relies on shell::colored_echo, shell::install_package, shell::list_ini_sections,
#     shell::clone_ini_section, and shell::on_evict.
#   - Provides interactive selection and auto-suggestion for the cloned section name.
shell::fzf_clone_ini_section() {
    local dry_run="false"

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_INI_CLONE_SECTION"
        return 0
    fi

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Validate required parameters
    if [ $# -lt 1 ]; then
        shell::colored_echo "ERR: shell::fzf_clone_ini_section: Missing file parameter." 196
        echo "Usage: shell::fzf_clone_ini_section [-n] [-h] <file>"
        return 1
    fi

    local file="$1"

    # Check if file exists
    if [ ! -f "$file" ]; then
        shell::colored_echo "ERR: File not found: $file" 196
        return 1
    fi

    # Ensure fzf is installed.
    shell::install_package fzf || {
        shell::colored_echo "ERR: fzf is required but could not be installed." 196
        return 1
    }

    # Get the list of sections and use fzf to select one.
    local selected_section
    selected_section=$(shell::list_ini_sections "$file" | fzf --prompt="Select section to clone: ")

    # Check if a section was selected.
    if [ -z "$selected_section" ]; then
        shell::colored_echo "ERR: No section selected. Aborting clone." 196
        return 1
    fi

    shell::colored_echo "DEBUG: Selected section for cloning: '$selected_section'" 244

    # Prompt for the new section name, with "_clone" appended as a suggestion.
    shell::colored_echo ">> Enter new section name (e.g., ${selected_section}_clone):" 33
    read -r new_section_name
    if [ -z "$new_section_name" ]; then
        new_section_name="${selected_section}_clone"
        shell::colored_echo "DEBUG: Using default new section name: '$new_section_name'" 244
    fi

    # Perform the clone operation using shell::clone_ini_section
    if [ "$dry_run" = "true" ]; then
        shell::clone_ini_section -n "$file" "$selected_section" "$new_section_name"
    else
        shell::clone_ini_section "$file" "$selected_section" "$new_section_name"
    fi

    return $?
}

# shell::fzf_remove_ini_sections function
# Interactively selects multiple sections to remove from an INI file using fzf.
#
# Usage:
#   shell::fzf_remove_ini_sections [-n] [-h] <file>
#
# Parameters:
#   - -n        : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h        : Optional help flag. Displays this help message.
#   - <file>    : The path to the INI file.
#
# Description:
#   This function first ensures fzf is installed. It then lists all sections in the
#   given INI file and uses fzf to allow the user to interactively select one or
#   more sections for removal. After selection, it proceeds to remove the selected
#   sections and their contents from the INI file.
#   The function handles dry-run mode, where it only prints the commands that would be executed.
#
# Example:
#   shell::fzf_remove_ini_sections config.ini   # Interactively remove sections.
#   shell::fzf_remove_ini_sections -n config.ini # Dry-run: show commands to remove sections.
#
# Returns:
#   0 on success, 1 on failure (e.g., missing parameters, file not found, no section selected).
#
# Notes:
#   - Relies on shell::colored_echo, shell::install_package, shell::list_ini_sections,
#     shell::run_cmd_eval, shell::on_evict, and shell::ini_escape_for_regex.
#   - Uses fzf's multi-select feature (TAB key) for selecting multiple sections.
shell::fzf_remove_ini_sections() {
    local dry_run="false"

    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_REMOVE_SECTIONS"
        return 0
    fi

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Validate required parameters
    if [ $# -lt 1 ]; then
        shell::colored_echo "ERR: shell::fzf_remove_ini_sections: Missing file parameter." 196
        echo "Usage: shell::fzf_remove_ini_sections [-n] [-h] <file>"
        return 1
    fi

    local file="$1"

    # Check if file exists
    if [ ! -f "$file" ]; then
        shell::colored_echo "ERR: File not found: $file" 196
        return 1
    fi

    # Ensure fzf is installed.
    shell::install_package fzf || {
        shell::colored_echo "ERR: fzf is required but could not be installed." 196
        return 1
    }

    # Get the list of sections in the specified file and use fzf to select multiple
    local IFS=$'\n'
    local selected_sections=($(shell::list_ini_sections "$file" | fzf --multi --prompt="Select sections to remove from '$file': "))

    # Check if any sections were selected
    if [ ${#selected_sections[@]} -eq 0 ]; then
        shell::colored_echo "ERR: No sections selected. Aborting removal." 196
        return 1
    fi

    shell::colored_echo "DEBUG: Selected sections for removal: ${selected_sections[*]}" 244

    local success=0
    # Process each selected section
    for section in "${selected_sections[@]}"; do
        if [ "$dry_run" = "true" ]; then
            # In dry-run mode, pass the -n flag to shell::remove_ini_section
            shell::remove_ini_section -n "$file" "$section"
            if [ $? -ne 0 ]; then
                success=1
            fi
        else
            # Execute the removal of the section
            shell::remove_ini_section "$file" "$section"
            if [ $? -ne 0 ]; then
                success=1
            fi
        fi
    done

    if [ "$dry_run" = "true" ]; then
        shell::colored_echo "INFO: Dry-run completed. Commands for removing sections were printed." 46
    elif [ $success -eq 0 ]; then
        shell::colored_echo "INFO: Successfully removed all selected sections from '$file'" 46
    else
        shell::colored_echo "ERR: Some sections could not be removed from '$file'" 196
        return 1
    fi

    return $success
}

# shell::fzf_view_ini_viz function
# Interactively previews all key-value pairs in each section of an INI file using fzf in a real-time wrapped vertical layout.
#
# Usage:
# shell::fzf_view_ini_viz <file>
#
# Parameters:
# - <file> : The path to the INI file.
#
# Description:
# This function lists all sections in the specified INI file using shell::list_ini_sections,
# and uses fzf to preview all key-value pairs in each section in real-time.
# The preview window wraps lines and simulates a tree-like layout for readability.
#
# Example:
# shell::fzf_view_ini_viz config.ini
# shell::fzf_view_ini_viz -n config.ini
shell::fzf_view_ini_viz() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_GET_INI_VIZ"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::fzf_view_ini_viz [-h] <file>"
        return 1
    fi

    # Validate the file parameter.
    # Ensure the file exists and is readable.
    local file="$1"
    if [ ! -f "$file" ]; then
        shell::colored_echo "ERR: File not found: $file" 196
        return 1
    fi

    # Ensure fzf is installed.
    shell::install_package fzf

    # Set up color variables for fzf preview.
    # Using tput to set colors for better visibility.
    # Colors are set to ANSI escape codes for terminal compatibility.
    local yellow=$(tput setaf 3)
    local cyan=$(tput setaf 6)
    local green=$(tput setaf 2)
    local normal=$(tput sgr0)
    local os_type
    os_type=$(shell::get_os_type)

    # Determine the base64 decode command based on the OS type.
    # This is used to decode values that might be base64 encoded.
    # macOS uses 'base64 -D', while Linux typically uses 'base64 -d'.
    # This ensures compatibility across different operating systems.
    local decode_cmd
    [ "$os_type" = "macos" ] && decode_cmd="base64 -D" || decode_cmd="base64 -d"

    # List sections and use fzf to select one.
    # The preview command uses awk to format the output in a tree-like structure.
    # It highlights keys and values with colors for better visibility.
    # The preview window is set to wrap lines and display up to 60 lines.
    local section
    # section=$(shell::list_ini_sections "$file" |
    #     awk -v y="$yellow" -v n="$normal" '{print y $0 n}' |
    #     fzf --ansi \
    #         --prompt="Select section: " \
    #         --preview="awk -v s='{}' '
    #       BEGIN { in_section=0 }
    #       /^\[.*\]/ {
    #         in_section = (\$0 == \"[\" s \"]\") ? 1 : 0
    #         next
    #       }
    #       in_section && /^[^#;]/ && /=/ {
    #         split(\$0, kv, \"=\")
    #         gsub(/^[ \t]+|[ \t]+$/, \"\", kv[1])
    #         gsub(/^[ \t]+|[ \t]+$/, \"\", kv[2])
    #         printf(\" %s%s%s: %s%s%s\\n\", \"\033[36m\", kv[1], \"\033[0m\", \"\033[32m\", kv[2], \"\033[0m\")
    #       }
    #     ' \"$file\"" \
    #         --preview-window=up:wrap:60%)

    section=$(shell::list_ini_sections "$file" |
        awk -v y="$yellow" -v n="$normal" '{print y $0 n}' |
        fzf --ansi \
            --prompt="Select section: " \
            --preview="bash -c '
        section=\"{}\"; in_section=0
        while IFS= read -r line; do
          [[ \"\$line\" =~ ^\\[.*\\]$ ]] && {
            [[ \"\$line\" == \"[\$section]\" ]] && in_section=1 || in_section=0
            continue
          }
          [[ \$in_section -eq 1 && \"\$line\" =~ = ]] && {
            key=\${line%%=*}
            val=\${line#*=}
            decoded=\$(echo \"\$val\" | $decode_cmd 2>/dev/null)
            printf \"  \033[36m%s\033[0m: \033[32m%s\033[0m\n\" \"\$key\" \"\$decoded\"
          }
        done < \"$file\"
      '" \
            --preview-window=up:wrap:60%)

    # Check if a section was selected.
    # If not, print an error message and return.
    section=$(echo "$section" | sed "s/$(echo -e "\033")[0-9;]*m//g")
    if [ -z "$section" ]; then
        shell::colored_echo "ERR: No section selected." 196
        return 1
    fi

    # Read all keys in the selected section and display them using fzf.
    # The keys are colored for better visibility.
    local key
    key=$(shell::list_ini_keys "$file" "$section" |
        awk -v c="$cyan" -v n="$normal" '{print c $0 n}' |
        fzf --ansi --prompt="Select key in [$section]: ")

    key=$(echo "$key" | sed "s/$(echo -e "\033")[0-9;]*m//g")
    if [ -z "$key" ]; then
        shell::colored_echo "ERR: No key selected." 196
        return 1
    fi

    # Read the value of the selected key in the specified section.
    # The value is colored for better visibility.
    # The value is then passed to shell::clip_value for further processing.
    local value
    value=$(shell::read_ini "$file" "$section" "$key")
    if [ $? -ne 0 ]; then
        shell::colored_echo "ERR: Failed to read value for key '$key' in section '$section'." 196
        return 1
    fi

    shell::colored_echo "DEBUG: [s] Section: $section" 244
    shell::colored_echo "DEBUG: [k] Key: $key" 244
    shell::colored_echo "INFO: [v] Value: $value" 46
    shell::clip_value "$value"
}

# shell::fzf_view_ini_viz_super function
# Interactively previews all key-value pairs in each section of an INI file using fzf in a real-time wrapped vertical layout.
#
# Usage:
# shell::fzf_view_ini_viz_super <file> [--json|--yaml|--multi]
#
# Parameters:
# - <file> : The path to the INI file.
# - --json : Optional. Export the selected section as JSON.
# - --yaml : Optional. Export the selected section as YAML.
# - --multi : Optional. Allow multi-key selection and export.
#
# Description:
# This function lists all sections in the specified INI file using shell::list_ini_sections,
# and uses fzf to preview all key-value pairs in each section in real-time.
# The preview window wraps lines and simulates a tree-like layout for readability.
# It supports exporting the selected section as JSON or YAML, or selecting multiple keys for export.
#
# Example:
# shell::fzf_view_ini_viz_super config.ini
# shell::fzf_view_ini_viz_super config.ini --json
# shell::fzf_view_ini_viz_super config.ini --multi
shell::fzf_view_ini_viz_super() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_VIEW_INI_VIZ_SUPER"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::fzf_view_ini_viz_super <file> [--json|--yaml|--multi]"
        return 1
    fi

    local file="$1"
    shift
    local mode=""
    local multi="false"

    # Process additional options: --json, --yaml, --multi
    # These options determine how the selected section will be exported.
    # --json: Export as JSON format.
    # --yaml: Export as YAML format.
    # --multi: Allow multi-key selection and export.
    for arg in "$@"; do
        case "$arg" in
        --json | --yaml) mode="$arg" ;;
        --multi) multi="true" ;;
        esac
    done

    # Validate the file parameter.
    # Ensure the file exists and is readable.
    if [ ! -f "$file" ]; then
        shell::colored_echo "ERR: File not found: $file" 196
        return 1
    fi

    # Ensure fzf is installed.
    shell::install_package fzf

    # Set up color variables for fzf preview.
    # Using tput to set colors for better visibility.
    # Colors are set to ANSI escape codes for terminal compatibility.
    local yellow=$(tput setaf 3)
    local cyan=$(tput setaf 6)
    local green=$(tput setaf 2)
    local normal=$(tput sgr0)

    # List sections and use fzf to select one.
    # The preview command uses awk to format the output in a tree-like structure.
    # It highlights keys and values with colors for better visibility.
    local section
    section=$(shell::list_ini_sections "$file" |
        awk -v y="$yellow" -v n="$normal" '{print y $0 n}' |
        fzf --ansi \
            --prompt="Select section: " \
            --preview="awk -v s='{}' '
          BEGIN { in_section=0 }
          /^\[.*\]/ {
            in_section = (\$0 == \"[\" s \"]\") ? 1 : 0
            next
          }
          in_section && /^[^#;]/ && /=/ {
            split(\$0, kv, \"=\")
            gsub(/^[ \t]+|[ \t]+$/, \"\", kv[1])
            gsub(/^[ \t]+|[ \t]+$/, \"\", kv[2])
            printf(\" %s%s%s: %s%s%s\\n\", \"\033[36m\", kv[1], \"\033[0m\", \"\033[32m\", kv[2], \"\033[0m\")
          }
        ' \"$file\"" \
            --preview-window=up:wrap:60%)

    # Check if a section was selected.
    # If not, print an error message and return.
    section=$(echo "$section" | sed "s/$(echo -e "\033")[0-9;]*m//g")
    if [ -z "$section" ]; then
        shell::colored_echo "ERR: No section selected." 196
        return 1
    fi

    # Read all keys in the selected section and display them using fzf.
    # The keys are colored for better visibility.
    local keys
    keys=$(shell::list_ini_keys "$file" "$section")
    if [ -z "$keys" ]; then
        shell::colored_echo "WARN: No keys found in section '$section'." 33
        return 1
    fi

    # If --json mode is specified, format the output as JSON.
    # --json: Export as JSON format.
    if [ "$mode" = "--json" ]; then
        local output="{"
        local first=1
        while IFS= read -r key; do
            local val
            val=$(shell::read_ini "$file" "$section" "$key")
            val=$(echo "$val" | sed 's/"/\\"/g') # escape double quotes
            key=$(shell::sanitize_lower_var_name "$key")
            if [ $first -eq 1 ]; then
                output="$output\n  \"$key\": \"$val\""
                first=0
            else
                output="$output,\n  \"$key\": \"$val\""
            fi
        done <<<"$keys"
        output="$output\n}"
        echo -e "$output"
        shell::clip_value "$output"
        return 0
    fi

    # If --yaml mode is specified, format the output as YAML.
    # --yaml: Export as YAML format.
    if [ "$mode" = "--yaml" ]; then
        local output=""
        while IFS= read -r key; do
            local val
            val=$(shell::read_ini "$file" "$section" "$key")
            key=$(shell::sanitize_lower_var_name "$key")
            output="${output}$key: $val\n"
        done <<<"$keys"
        echo -e "$output"
        shell::clip_value "$output"
        return 0
    fi

    # If --multi is specified, allow multi-key selection.
    # Use fzf to select one or more keys from the section.
    # The selected keys are then read and their values are displayed.
    local key_selection
    if [ "$multi" = "true" ]; then
        key_selection=$(echo "$keys" | fzf --ansi --multi --prompt="Select key(s) in [$section]: ")
    else
        key_selection=$(echo "$keys" | fzf --ansi --prompt="Select key in [$section]: ")
    fi

    if [ -z "$key_selection" ]; then
        shell::colored_echo "ERR: No key selected." 196
        return 1
    fi

    # Process the selected keys and read their values.
    # The values are colored for better visibility.
    # The output is formatted as key=value pairs and copied to the clipboard.
    # Each key-value pair is printed in a debug and info format.
    local output=""
    while IFS= read -r key; do
        key=$(echo "$key" | sed "s/$(echo -e "\033")[0-9;]*m//g")
        local value
        value=$(shell::read_ini "$file" "$section" "$key")
        shell::colored_echo "DEBUG: [k] $key" 244
        shell::colored_echo "INFO: [v] $value" 46
        key=$(shell::sanitize_lower_var_name "$key")
        output="${output}$key=$value\n"
    done <<<"$key_selection"

    shell::clip_value "$output"
    return 0
}

# shell::fzf_view_ini_viz_super_control function
# Interactively previews all key-value pairs in each section of an INI file using fzf in a real-time wrapped vertical layout.
#
# Usage:
# shell::fzf_view_ini_viz_super_control <file> [--json|--yaml|--multi]
#
# Parameters:
# - <file> : The path to the INI file.
# - --json : Optional. Export the selected section as JSON.
# - --yaml : Optional. Export the selected section as YAML.
# - --multi : Optional. Allow multi-key selection and export.
#
# Description:
# This function lists all sections in the specified INI file using shell::list_ini_sections,
# and uses fzf to preview all key-value pairs in each section in real-time.
# The preview window wraps lines and simulates a tree-like layout for readability.
# It supports exporting the selected section as JSON or YAML, or selecting multiple keys for export.
# A [Previous Section] option is included to allow users to return to section selection.
#
# Example:
# shell::fzf_view_ini_viz_super_control config.ini
# shell::fzf_view_ini_viz_super_control config.ini --json
# shell::fzf_view_ini_viz_super_control config.ini --multi
shell::fzf_view_ini_viz_super_control() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_VIEW_INI_VIZ_SUPER"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::fzf_view_ini_viz_super_control <file> [--json|--yaml|--multi]"
        return 1
    fi

    local file="$1"
    shift
    local mode=""
    local multi="false"

    # Process additional options: --json, --yaml, --multi
    # These options determine how the selected section will be exported.
    for arg in "$@"; do
        case "$arg" in
        --json | --yaml) mode="$arg" ;;
        --multi) multi="true" ;;
        esac
    done

    # Validate the file parameter.
    # Ensure the file exists and is readable.
    if [ ! -f "$file" ]; then
        shell::colored_echo "ERR: File not found: $file" 196
        return 1
    fi

    # Ensure fzf is installed.
    shell::install_package fzf

    # Set up color variables for fzf preview.
    # Using tput to set colors for better visibility.
    local yellow=$(tput setaf 3)
    local cyan=$(tput setaf 6)
    local green=$(tput setaf 2)
    local normal=$(tput sgr0)

    # Begin interactive loop to allow returning to section selection.
    while true; do
        # List sections and use fzf to select one.
        # The preview command uses awk to format the output in a tree-like structure.
        local section
        section=$(shell::list_ini_sections "$file" |
            awk -v y="$yellow" -v n="$normal" '{print y $0 n}' |
            fzf --ansi \
                --prompt="Select section: " \
                --preview="awk -v s='{}' '
                  BEGIN { in_section=0 }
                  /^\[.*\]/ {
                    in_section = (\$0 == \"[\" s \"]\") ? 1 : 0
                    next
                  }
                  in_section && /^[^#;]/ && /=/ {
                    split(\$0, kv, \"=\")
                    gsub(/^[ \t]+|[ \t]+$/, \"\", kv[1])
                    gsub(/^[ \t]+|[ \t]+$/, \"\", kv[2])
                    printf(\" %s%s%s: %s%s%s\\n\", \"\033[36m\", kv[1], \"\033[0m\", \"\033[32m\", kv[2], \"\033[0m\")
                  }
                ' \"$file\"" \
                --preview-window=up:wrap)

        # Check if a section was selected.
        section=$(echo "$section" | sed "s/$(echo -e "\033")[0-9;]*m//g")
        if [ -z "$section" ]; then
            shell::colored_echo "ERR: No section selected." 196
            return 1
        fi

        # Read all keys in the selected section.
        local keys
        keys=$(shell::list_ini_keys "$file" "$section")
        if [ -z "$keys" ]; then
            shell::colored_echo "WARN: No keys found in section '$section'." 33
            continue
        fi

        # If --json mode is specified, format the output as JSON.
        if [ "$mode" = "--json" ]; then
            local output="{"
            local first=1
            while IFS= read -r key; do
                local val
                val=$(shell::read_ini "$file" "$section" "$key")
                val=$(echo "$val" | sed 's/"/\\"/g')
                key=$(shell::sanitize_lower_var_name "$key")
                if [ $first -eq 1 ]; then
                    output="$output\n  \"$key\": \"$val\""
                    first=0
                else
                    output="$output,\n  \"$key\": \"$val\""
                fi
            done <<<"$keys"
            output="$output\n}"
            echo -e "$output"
            shell::clip_value "$output"
            return 0
        fi

        # If --yaml mode is specified, format the output as YAML.
        if [ "$mode" = "--yaml" ]; then
            local output=""
            while IFS= read -r key; do
                local val
                val=$(shell::read_ini "$file" "$section" "$key")
                key=$(shell::sanitize_lower_var_name "$key")
                output="${output}$key: $val\n"
            done <<<"$keys"
            echo -e "$output"
            shell::clip_value "$output"
            return 0
        fi

        # If --multi is specified, allow multi-key selection.
        # Add [Previous Section] as the first option.
        local key_selection
        key_selection=$( (
            echo "[Previous Section]"
            echo "$keys"
        ) |
            fzf --ansi ${multi:+--multi} --prompt="Select key(s) in [$section]: ")

        # Clean ANSI color codes from selection.
        key_selection=$(echo "$key_selection" | sed "s/$(echo -e "\033")[0-9;]*m//g")

        # If no key was selected, return with error.
        if [ -z "$key_selection" ]; then
            shell::colored_echo "ERR: No key selected." 196
            return 1
        fi

        # If user selected [Previous Section], restart loop.
        if [ "$key_selection" = "[Previous Section]" ]; then
            continue
        fi

        # Process the selected keys and read their values.
        # The values are colored for better visibility.
        local output=""
        while IFS= read -r key; do
            key=$(echo "$key" | sed "s/$(echo -e "\033")[0-9;]*m//g")
            local value
            value=$(shell::read_ini "$file" "$section" "$key")
            shell::colored_echo "DEBUG: [k] $key" 244
            shell::colored_echo "INFO: [v] $value" 46
            key=$(shell::sanitize_lower_var_name "$key")
            output="${output}$key=$value\n"
        done <<<"$key_selection"

        shell::clip_value "$output"
        return 0
    done
}

# shell::fzf_edit_ini_viz function
# Interactively edits or renames a key in an INI file using fzf.
#
# Usage:
# shell::fzf_edit_ini_viz <file>
#
# Parameters:
# - <file> : The path to the INI file.
#
# Description:
# This function allows the user to select a section and a key from an INI file,
# then choose to either edit the value of the key or rename the key.
# It uses fzf for interactive selection and sed for in-place editing.
#
# Example:
# shell::fzf_edit_ini_viz config.ini
shell::fzf_edit_ini_viz() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_EDIT_INI_VIZ"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::fzf_edit_ini_viz <file>"
        return 1
    fi

    local file="$1"
    # Validate the file parameter.
    # Ensure the file exists and is readable.
    if [ ! -f "$file" ]; then
        shell::colored_echo "ERR: File not found: $file" 196
        return 1
    fi

    # Ensure fzf is installed.
    shell::install_package fzf

    # Get the list of sections in the specified file and use fzf to select one.
    local section
    section=$(shell::list_ini_sections "$file" | fzf --prompt="Select section to edit: ")
    if [ -z "$section" ]; then
        shell::colored_echo "ERR: No section selected." 196
        return 1
    fi

    # Get the list of keys in the selected section and use fzf to select one.
    # The keys are colored for better visibility.
    local key
    key=$(shell::list_ini_keys "$file" "$section" | fzf --prompt="Select key to edit/rename: ")
    if [ -z "$key" ]; then
        shell::colored_echo "ERR: No key selected." 196
        return 1
    fi

    # Prompt the user to choose an action for the selected key.
    # The user can choose to edit the value of the key or rename the key.
    # The options are presented in a numbered list using select.
    shell::colored_echo "Choose action for key '$key' in section [$section]:" 33
    select action in "Edit Value" "Remove Key" "Cancel"; do
        case $REPLY in
        1)
            shell::colored_echo "Enter new value for '$key':" 33
            read -r new_value
            shell::write_ini "$file" "$section" "$key" "$new_value"
            return $?
            ;;
        2)
            shell::colored_echo "Are you sure you want to remove the key '$key' from section [$section]? (y/n)" 33
            read -r confirmation
            if [[ "$confirmation" != "y" && "$confirmation" != "Y" ]]; then
                shell::colored_echo "WARN: Key removal cancelled." 11
                return 0
            fi
            shell::colored_echo "DEBUG: Removing key '$key' from section [$section] in file '$file'..." 244
            shell::remove_ini_key "$file" "$section" "$key"
            return $?
            ;;
        3)
            shell::colored_echo "WARN: Cancelled." 11
            return 0
            ;;
        *)
            shell::colored_echo "ERR: Invalid option." 196
            ;;
        esac
    done
}
