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

# shell::logger::reset_options function
# Resets the options display flag.
#
# Usage:
#   shell::logger::reset_options
#
# Description:
#   Call this function to reset the options display state, allowing
#   "OPTIONS:" to be displayed again for a new section.
shell::logger::reset_options() {
	unset _SHELL_LOGGER_OPTIONS_SHOWN
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

	# Display OPTIONS label if this is the first option call
	if [[ -z "$_SHELL_LOGGER_OPTIONS_SHOWN" ]]; then
		shell::colored_echo "OPTIONS:" 39
		export _SHELL_LOGGER_OPTIONS_SHOWN=1
	fi
	
	if [[ -n "$description" ]]; then
		local formatted_line
		formatted_line=$(printf "    %-20s %s" "$option" "$description")
		shell::colored_echo "$formatted_line" 246
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

# shell::logger::indent function
# Logs a message with indentation and optional color.
#
# Usage:
#   shell::logger::indent <level> <message>
#   shell::logger::indent <level> <color> <message>
#
# Parameters:
#   - <level> : The indentation level (0-5).
#   - <color> : (Optional) The color code for the message.
#   - <message> : The message to log.
#
# Description:
#   This function logs a message with indentation and optional color. The
#   indentation level determines the number of spaces to indent the message.
#   If no color is provided, the default color (245) is used.
shell::logger::indent() {
	local level="$1"
	local color="$2"
	local message="$3"
	
	if ! shell::logger::can "INFO"; then
		return 0
	fi
	
	# If only 2 arguments, treat second as message with default color
	if [[ -z "$message" ]]; then
		message="$color"
		color="245"
	fi
	
	# Validate level (0-5)
	if ! [[ "$level" =~ ^[0-5]$ ]]; then
		level=0
	fi
	
	# Create indentation string
	local indent=""
	local i
	for ((i = 0; i < level * 2; i++)); do
		indent+=" "
	done
	
	shell::colored_echo "${indent}${message}" "$color"
}

# shell::logger::step function
# Logs a step with a step number and description.
#
# Usage:
#   shell::logger::step <step_number> <description>
#
# Parameters:
#   - <step_number> : The step number to log.
#   - <description> : The description of the step.
#
# Description:
#   This function logs a step with a step number and description. The step
#   number is displayed in a specific color (33) to stand out.
shell::logger::step() {
	local step_number="$1"
	local description="$2"
	
	if ! shell::logger::can "INFO"; then
		return 0
	fi
	
	shell::colored_echo "STEP $step_number: $description" 33
}

# shell::logger::step_note function
# Logs a note with an optional description.
#
# Usage:
#   shell::logger::step_note <note> <description>
#
# Parameters:
#   - <note> : The note to log.
#   - <description> : (Optional) A description of the note.
#
# Description:
#   This function logs a note with an optional description. If a description
#   is provided, it is indented and formatted for readability. The note is
#   displayed in a specific color (248) to stand out.
shell::logger::step_note() {
	local note="$1"
	if ! shell::logger::can "INFO"; then
		return 0
	fi
	shell::colored_echo "  NOTE: $note" 248
}

# shell::logger::cmd function
# Logs a command with an optional description.
#
# Usage:
#   shell::logger::cmd <command> <description>
#
# Parameters:
#   - <command> : The command to log.
#   - <description> : (Optional) A description of the command.
#
# Description:
#   This function logs a command with an optional description. If a description
#   is provided, it is indented and formatted for readability. The command is
#   displayed in a specific color (245) to stand out.
shell::logger::cmd() {
	local command="$1"
	
	if ! shell::logger::can "INFO"; then
		return 0
	fi
	
	shell::colored_echo "  $ $command" 245
}

# shell::logger::cmd_copy function
# Logs a command with an optional description and copies it to the clipboard.
#
# Usage:
#   shell::logger::cmd_copy <command> <description>
#
# Parameters:
#   - <command> : The command to log and copy.
#   - <description> : (Optional) A description of the command.
#
# Description:
#   This function logs a command with an optional description and copies it to
#   the clipboard. If a description is provided, it is indented and formatted for
#   readability. The command is displayed in a specific color (245) to stand out.
shell::logger::cmd_copy() {
	local command="$1"
	if ! shell::logger::can "INFO"; then
		return 0
	fi
	shell::colored_echo "  $ $command" 245
	shell::clip_value "$command"
}

# shell::logger::exec function
# Logs a command with an optional description and executes it using eval.
#
# Usage:
#   shell::logger::exec <command> <description>
#
# Parameters:
#   - <command> : The command to log and execute.
#   - <description> : (Optional) A description of the command.
#
# Description:
#   This function logs a command with an optional description and executes it
#   using eval. If a description is provided, it is indented and formatted for
#   readability. The command is displayed in a specific color (245) to stand out.
shell::logger::exec() {
	local command="$1"
	if ! shell::logger::can "INFO"; then
		return 0
	fi
	shell::colored_echo "  $ $command" 245
	eval "$command"
}

# shell::logger::section function
# Logs a section title with a separator.
#
# Usage:
#   shell::logger::section <title>
#
# Parameters:
#   - <title> : The title of the section.
#
# Description:
#   This function logs a section title with a separator. The title is displayed
#   in a specific color (39) to stand out. The separator consists of 60 equal
#   signs.
shell::logger::section() {
	local title="$1"
	if ! shell::logger::can "INFO"; then
		return 0
	fi
	local separator=$(printf '%.0s=' {1..60})
	shell::colored_echo "$separator" 240
	shell::colored_echo "  $title" 39
	shell::colored_echo "$separator" 240
}
