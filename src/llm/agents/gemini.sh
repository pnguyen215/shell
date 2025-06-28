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

    # Create the file if it does not exist
    # This function uses shell::create_file_if_not_exists to ensure the file is created
    if [ ! -f "$file" ]; then
        shell::create_file_if_not_exists "$file"
    fi

    # Ensure the section exists in the INI file
    # This function uses shell::exist_ini_section to check if the section exists
    # If it does not exist, it adds the section using shell::add_ini_section
    if ! shell::exist_ini_section "$file" "$section" >/dev/null 2>&1; then
        shell::add_ini_section "$file" "$section"
    fi

    # Define default keys and their values
    # This associative array contains the default keys and their values for the Gemini configuration
    # Each key is a string, and the value is also a string
    declare -A defaults=(
        ["MODEL"]="gemini-2.0-flash"
        ["API_KEY"]="your-api-key-here"
        ["TEMPERATURE"]="0.7"
        ["MAX_TOKENS"]="2048"
        ["TOP_P"]="1.0"
        ["TOP_K"]="40"
        ["STREAM"]="false"
        ["SAFETY_SETTINGS"]="default"
        ["LANGUAGE"]="en"
        ["TIMEOUT"]="30"
        ["RETRY_COUNT"]="3"
    )

    # Populate the section with default keys if they do not exist
    # This loop iterates over the defaults associative array
    shell::colored_echo "DEBUG: Populating Gemini configuration in '$file' under section [$section]..." 244
    for key in "${!defaults[@]}"; do
        if ! shell::exist_ini_key "$file" "$section" "$key" >/dev/null 2>&1; then
            shell::write_ini "$file" "$section" "$key" "${defaults[$key]}"
        else
            shell::colored_echo "WARN: Key '$key' already exists in section [$section], skipping." 11
        fi
    done

    shell::colored_echo "INFO: Gemini configuration populated at '$file'" 46
}
