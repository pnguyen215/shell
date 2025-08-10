#!/bin/bash
# logger.sh

# _shell::logger::get_level_value (internal function)
# Retrieves the numerical value of a given logging level.
#
# Usage:
#   _shell::logger::get_level_value <level>
#
# Parameters:
#   - <level>: The logging level string (e.g., "INFO").
#
# Output:
#   Prints the numerical value of the level.
#   Prints nothing if the level is invalid.
#
# Description:
#   This helper function maps a log level string to its corresponding integer
#   value using a case statement for maximum portability across shells
#   like older bash versions on macOS.
_shell::logger::get_level_value() {
	local level
	level="$(echo "$1" | tr '[:lower:]' '[:upper:]')"

	case "${level}" in
	DEBUG) echo 0 ;;
	INFO) echo 1 ;;
	WARN) echo 2 ;;
	ERROR) echo 3 ;;
	FATAL) echo 4 ;;
	*) echo "" ;;
	esac
}

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
	local target_level="$1"
	local current_level="${SHELL_LOGGER_LEVEL:-DEBUG}"

	local current_value
	current_value="$(_shell::logger::get_level_value "${current_level}")"

	local target_value
	target_value="$(_shell::logger::get_level_value "${target_level}")"

	# If either level is invalid, the check fails.
	if [[ -z "${current_value}" || -z "${target_value}" ]]; then
		return 1
	fi

	[[ "${target_value}" -ge "${current_value}" ]]
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
	local message="$level: $*"

	if shell::logger::can "$level"; then
		if [[ "$stream" == "stderr" ]]; then
			shell::colored_echo "$message" "$color" >&2
		else
			shell::colored_echo "$message" "$color"
		fi
	fi
}

# shell::logger::reset function
# Resets the logging level to DEBUG.
#
# Usage:
#   shell::logger::reset
#
# Description:
#   This function sets the SHELL_LOGGER_LEVEL environment variable to DEBUG,
#   effectively resetting the logging level to the most verbose.
shell::logger::reset() {
	SHELL_LOGGER_LEVEL="DEBUG"
}

# shell::logger::set_level function
# Sets the logging level to a specified value.
#
# Usage:
#   shell::logger::set_level
#
# Description:
#   This function sets the SHELL_LOGGER_LEVEL environment variable to the specified level,
#   allowing for dynamic adjustment of the logging verbosity.
shell::logger::set_level() {
	local menu_options
	local selected_value
	menu_options=(
		"DEBUG"
		"INFO"
		"WARN"
		"ERROR"
		"FATAL"
	)
	selected_value=$(shell::select "${menu_options[@]}")
	SHELL_LOGGER_LEVEL="${selected_value:-DEBUG}"
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

# shell::logger::success function
# Logs a success message if the current logging level allows it.
#
# Usage:
#   shell::logger::success <message>
#
# Parameters:
#   - <message> : The message to log as a success.
#
# Description:
#   This function uses shell::logger::fmt to format the message with the INFO level and a specific color.
shell::logger::success() {
	shell::logger::fmt "INFO" 46 "stdout" "$@"
}

# shell::logger::usage function
# Logs CLI usage instructions with proper indentation and formatting.
#
# Usage:
#   shell::logger::usage <title>
#   shell::logger::item <command> <description>
#   shell::logger::option <option> <description>
#   shell::logger::example <example>
#
# Description:
#   Provides a set of functions for displaying professional CLI usage documentation
#   with consistent indentation and colors. Compatible with Linux and macOS.
shell::logger::usage() {
	local title="$1"
	if ! shell::logger::can "INFO"; then
		return 0
	fi
	shell::colored_echo "USAGE: $title" 39
}

# shell::logger::item function
# Logs a command or option with an optional description.
#
# Usage:
#   shell::logger::item <command> <description>
#
# Parameters:
#   - <command> : The command or option to log.
#   - <description> : (Optional) A description of the command or option.
#
# Description:
#   This function logs a command or option with an optional description. If a
#   description is provided, it is indented and formatted for readability.
shell::logger::item() {
	local command="$1"
	local description="$2"

	if ! shell::logger::can "INFO"; then
		return 0
	fi
	
	if [[ -n "$description" ]]; then
		shell::colored_echo "  $command" 245
		shell::colored_echo "    $description" 250
	else
		shell::colored_echo "  $command" 245
	fi
}

# shell::logger::option function
# Logs an option with an optional description.
#
# Usage:
#   shell::logger::option <option> <description>
#
# Parameters:
#   - <option> : The option to log.
#   - <description> : (Optional) A description of the option.
#
# Description:
#   This function logs an option with an optional description. If a description
#   is provided, it is indented and formatted for readability. The option is
#   displayed in a specific color (246) to stand out.
shell::logger::option() {
	local option="$1"
	local description="$2"
	
	if ! shell::logger::can "INFO"; then
		return 0
	fi
	
	if [[ -n "$description" ]]; then
		printf "    %-20s %s\n" "$option" "$description" | shell::colored_echo "$(cat)" 246
	else
		shell::colored_echo "    $option" 246
	fi
}

# shell::logger::example function
# Logs an example command with an optional description.
#
# Usage:
#   shell::logger::example <example> <description>
#
# Parameters:
#   - <example> : The example command to log.
#   - <description> : (Optional) A description of the example.
#
# Description:
#   This function logs an example command with an optional description. If a
#   description is provided, it is indented and formatted for readability. The
#   example is displayed in a specific color (42) to stand out.
shell::logger::example() {
	local example="$1"
	
	if ! shell::logger::can "INFO"; then
		return 0
	fi
	
	shell::colored_echo "EXAMPLE: $example" 42
}