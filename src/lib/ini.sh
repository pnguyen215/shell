#!/bin/bash
# ini.sh

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
