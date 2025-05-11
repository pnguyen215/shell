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
        shell::colored_echo "Section name cannot be empty" 196
        return 1
    fi

    if [[ "$section" =~ [\[\]\=] ]]; then
        shell::colored_echo "Section name contains illegal characters: $section" 196
        return 1
    fi
    if [ "${SHELL_INI_STRICT}" -eq 1 ]; then
        echo "DEBUG: Strict mode is ON. Checking for illegal characters." # Debugging line
        # Check for illegal characters in section name
        if [[ "$section" =~ [\[\]\=] ]]; then
            shell::colored_echo "Section name contains illegal characters: $section" 196
            return 1
        fi
    fi

    if [ "${SHELL_INI_ALLOW_SPACES_IN_NAMES}" -eq 0 ] && [[ "$section" =~ [[:space:]] ]]; then
        shell::colored_echo "Section name contains spaces: $section" 196
        return 1
    fi

    return 0
}
