#!/bin/bash
# logger.sh

# shell::logger::can function
# Determines if the logger can log messages at a specified level.
# 
# Usage:
#   shell::logger::can <level>
# 
# Parameters:
#   - <level> : The logging level to check (DEBUG, INFO, WARN, ERROR, FATAL).
# 
# Description:
#   This function checks the current logging level set in SHELL_LOGGER_LEVEL
#   and compares it with the target level. It uses an array to define the order of logging levels.
shell::logger::can() {
    local level_order=(DEBUG INFO WARN ERROR FATAL)
    local current_level="$SHELL_LOGGER_LEVEL"
    local target_level="$1"

    local i current_i
    for i in "${!level_order[@]}"; do
        [[ "${level_order[$i]}" == "$current_level" ]] && current_i=$i
        [[ "${level_order[$i]}" == "$target_level" ]] && target_i=$i
    done

    [[ $target_i -ge $current_i ]]
}

# shell::logger::fmt function
# Formats and prints a log message with a specific level, color, and stream.
#
# Usage:
#   shell::logger::fmt <level> <color> <stream> <message>
#
# Parameters:
#   - <level>  : The logging level (DEBUG, INFO, WARN, ERROR, FATAL).
#   - <color>  : The color code for the message.
#   - <stream> : The output stream (stdout or stderr).
#   - <message>: The message to log.
#
# Description:
#   This function checks if the logger can log at the specified level using shell::logger::can.
#   If it can, it formats the message with the specified level and color,
#   and prints it to the specified output stream.
shell::logger::fmt() {
    local level="$1"
    local color="$2"
    local stream="$3"
    shift 3
    local message="[$level:] $*"

    if shell::logger::can "$level"; then
        if [[ "$stream" == "stderr" ]]; then
            shell::colored_echo "$message" "$color" >&2
        else
            shell::colored_echo "$message" "$color"
        fi
    fi
}

# shell::logger::debug function
# Logs a debug message if the current logging level allows it.
#
# Usage:
#   shell::logger::debug <message>
#
# Parameters:
#   - <message> : The message to log as a debug message.
#
# Description:
#   This function uses shell::logger::fmt to format the message with the DEBUG level and a specific color.
shell::logger::debug() {
    shell::logger::fmt "DEBUG" 244 "stderr" "$@"
}

# shell::logger::info function
# Logs an informational message if the current logging level allows it.
#
# Usage:
#   shell::logger::info <message>
#
# Parameters:
#   - <message> : The message to log as an informational message.
#
# Description:
#   This function uses shell::logger::fmt to format the message with the INFO level and a specific color.
shell::logger::info() {
    shell::logger::fmt "INFO" 33 "stdout" "$@"
}

# shell::logger::warn function
# Logs a warning message if the current logging level allows it.
#
# Usage:
#   shell::logger::warn <message>
#
# Parameters:
#   - <message> : The message to log as a warning.
#
# Description:
#   This function uses shell::logger::fmt to format the message with the WARN level and a specific color.
shell::logger::warn() {
    shell::logger::fmt "WARN" 11 "stderr" "$@"
}

# shell::logger::error function
# Logs an error message if the current logging level allows it.
#
# Usage:
#   shell::logger::error <message>
#
# Parameters:
#   - <message> : The message to log as an error.
#
# Description:
#   This function uses shell::logger::fmt to format the message with the ERROR level and a specific color.
shell::logger::error() {
    shell::logger::fmt "ERROR" 196 "stderr" "$@"
}

# shell::logger::fatal function
# Logs a fatal error message if the current logging level allows it.
#
# Usage:
#   shell::logger::fatal <message>
#
# Parameters:
#   - <message> : The message to log as a fatal error.
#
# Description:
#   This function uses shell::logger::fmt to format the message with the FATAL level and a specific color.
shell::logger::fatal() {
    shell::logger::fmt "FATAL" 160 "stderr" "$@"
    exit 1
}
