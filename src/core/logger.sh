#!/usr/bin/env bash
# @file core/logger.sh
# @brief Leveled, colourised logging, help-block rendering and command echo.
# @description
#   Log levels, in increasing severity: DEBUG(0) < INFO(1) < WARN(2) < ERROR(3)
#   < FATAL(4). A message is printed only when its level is >= SHELL_LOGGER_LEVEL
#   (default DEBUG, see constant/defaults.sh).
#
#   DEBUG / WARN / ERROR / FATAL go to **stderr**; INFO / success go to
#   **stdout**. Keep that in mind when capturing output with `$(...)`.
#
#   The same module also renders the `-h` help blocks every shell::* function
#   uses (usage / item / option / example), so the help layout is uniform.

# @description Convert a log-level name to its numeric severity.
# @arg $1 string Level name (case-insensitive): DEBUG, INFO, WARN, ERROR, FATAL.
# @stdout Integer 0-4, or an empty string when the level is unknown.
# @exitcode 0 Always.
# @example
#   shell::logger::level::to_int warn   # prints 2
#
shell::logger::level::to_int() {
	local level
	level="$(printf '%s' "${1-}" | tr '[:lower:]' '[:upper:]')"

	case "$level" in
	DEBUG) printf '0\n' ;;
	INFO) printf '1\n' ;;
	WARN) printf '2\n' ;;
	ERROR) printf '3\n' ;;
	FATAL) printf '4\n' ;;
	*) printf '\n' ;;
	esac
}

# @description Decide whether a message of a given level should be printed.
# @arg $1 string Level of the message being logged.
# @exitcode 0 The level is enabled by the current threshold.
# @exitcode 1 The level is filtered out, or either level name is invalid.
# @example
#   shell::logger::can DEBUG && echo "debug output is on"
#
shell::logger::can() {
	local target_level="${1-}"
	local current_level="${SHELL_LOGGER_LEVEL:-DEBUG}"

	local current_value target_value
	current_value="$(shell::logger::level::to_int "$current_level")"
	target_value="$(shell::logger::level::to_int "$target_level")"

	# An unknown level name on either side means "do not print".
	if [ -z "$current_value" ] || [ -z "$target_value" ]; then
		return "$RETURN_FAILURE"
	fi

	[ "$target_value" -ge "$current_value" ]
}

# @internal
# @description Format and print one log line if its level is enabled.
# @arg $1 string Level name; also the visible prefix ("INFO: ...").
# @arg $2 integer ANSI 256-colour code.
# @arg $3 string Stream: "stdout" or "stderr".
# @arg $@ string Message words, joined with single spaces.
# @exitcode 0 Always (a filtered message is not an error).
shell::logger::fmt() {
	local level="$1"
	local color="$2"
	local stream="$3"
	shift 3

	if ! shell::logger::can "$level"; then
		return "$RETURN_SUCCESS"
	fi

	# "$*" joins all remaining words with the first character of IFS (a space).
	if [ "$stream" = "stderr" ]; then
		shell::console::print "$level: $*" "$color" >&2
	else
		shell::console::print "$level: $*" "$color"
	fi
	return "$RETURN_SUCCESS"
}

# @description Reset the threshold to DEBUG (print everything).
# @noargs
# @set SHELL_LOGGER_LEVEL string Set to "DEBUG".
# @exitcode 0 Always.
shell::logger::reset() {
	SHELL_LOGGER_LEVEL="DEBUG"
}

# @description Forget that the "OPTIONS:" heading was already printed.
#   shell::logger::option prints the heading once per help block; call this at
#   the start of every help block so the heading appears again.
# @noargs
# @exitcode 0 Always.
shell::logger::reset_options() {
	unset _SHELL_LOGGER_OPTIONS_SHOWN
}

# @description Interactively choose the log threshold with fzf.
# @noargs
# @set SHELL_LOGGER_LEVEL string The selected level (unchanged when cancelled).
# @exitcode 0 Level updated.
# @exitcode 9 Selection cancelled.
# @see shell::ask::option
shell::logger::level() {
	local selected
	selected="$(shell::ask::option "DEBUG" "INFO" "WARN" "ERROR" "FATAL")" || return "$RETURN_CANCELLED"
	SHELL_LOGGER_LEVEL="${selected:-DEBUG}"
	return "$RETURN_SUCCESS"
}

# @description Log a DEBUG message (stderr).
# @arg $@ string Message.
# @stderr "DEBUG: <message>"
# @exitcode 0 Always.
shell::logger::debug() {
	shell::logger::fmt "DEBUG" "$SHELL_COLOR_DEBUG" "stderr" "$@"
}

# @description Log an INFO message (stdout).
# @arg $@ string Message.
# @stdout "INFO: <message>"
# @exitcode 0 Always.
shell::logger::info() {
	shell::logger::fmt "INFO" "$SHELL_COLOR_INFO" "stdout" "$@"
}

# @description Log a WARN message (stderr).
# @arg $@ string Message.
# @stderr "WARN: <message>"
# @exitcode 0 Always.
shell::logger::warn() {
	shell::logger::fmt "WARN" "$SHELL_COLOR_WARN" "stderr" "$@"
}

# @description Log an ERROR message (stderr).
# @arg $@ string Message.
# @stderr "ERROR: <message>"
# @exitcode 0 Always.
shell::logger::error() {
	shell::logger::fmt "ERROR" "$SHELL_COLOR_ERROR" "stderr" "$@"
}

# @description Log a FATAL message (stderr) and return a failure status.
#   **Behaviour change:** the previous implementation called `exit 1`. Because
#   this library is *sourced* into the user's interactive shell, `exit` closed
#   the user's terminal. The function now returns instead; callers decide
#   whether to abort (`shell::logger::fatal "..." || return`).
# @arg $@ string Message.
# @stderr "FATAL: <message>"
# @exitcode 1 Always.
shell::logger::fatal() {
	shell::logger::fmt "FATAL" "$SHELL_COLOR_FATAL" "stderr" "$@"
	return "$RETURN_FAILURE"
}

# @description Log a success message (INFO level, green, stdout).
# @arg $@ string Message.
# @stdout "INFO: <message>"
# @exitcode 0 Always.
shell::logger::success() {
	shell::logger::fmt "INFO" "$SHELL_COLOR_SUCCESS" "stdout" "$@"
}

# @description Print the "USAGE:" line of a help block.
# @arg $1 string Synopsis, e.g. "shell::foo [-n] <path>".
# @stdout "USAGE: <synopsis>"
# @exitcode 0 Always.
shell::logger::usage() {
	if ! shell::logger::can "INFO"; then
		return "$RETURN_SUCCESS"
	fi
	shell::console::print "USAGE: ${1-}" "$SHELL_COLOR_USAGE"
}

# @description Print a positional-argument line of a help block.
# @arg $1 string Argument name.
# @arg $2 string Optional description (printed on its own, indented line).
# @stdout The argument and its description.
# @exitcode 0 Always.
shell::logger::item() {
	local name="${1-}"
	local description="${2-}"

	if ! shell::logger::can "INFO"; then
		return "$RETURN_SUCCESS"
	fi

	shell::console::print "  $name" "$SHELL_COLOR_ITEM"
	if [ -n "$description" ]; then
		shell::console::print "    $description" "$SHELL_COLOR_DESCRIPTION"
	fi
}

# @description Print an option line of a help block.
#   The "OPTIONS:" heading is printed before the first option of each block.
# @arg $1 string Option flags, e.g. "-n, --dry-run".
# @arg $2 string Optional description.
# @stdout The formatted option line.
# @exitcode 0 Always.
# @see shell::logger::reset_options
shell::logger::option() {
	local option="${1-}"
	local description="${2-}"

	if ! shell::logger::can "INFO"; then
		return "$RETURN_SUCCESS"
	fi

	if [ -z "${_SHELL_LOGGER_OPTIONS_SHOWN-}" ]; then
		shell::console::print "OPTIONS:" "$SHELL_COLOR_USAGE"
		_SHELL_LOGGER_OPTIONS_SHOWN=1
	fi

	if [ -n "$description" ]; then
		# Left-align the flag in a 20-character column.
		local line
		line="$(printf '    %-20s %s' "$option" "$description")"
		shell::console::print "$line" "$SHELL_COLOR_DESCRIPTION"
	else
		shell::console::print "    $option" "$SHELL_COLOR_DESCRIPTION"
	fi
}

# @description Print an example invocation in a help block.
# @arg $1 string The example command line.
# @stdout "Eg:" followed by the highlighted command.
# @exitcode 0 Always.
shell::logger::example() {
	if ! shell::logger::can "INFO"; then
		return "$RETURN_SUCCESS"
	fi

	shell::console::print "Eg:" "$SHELL_COLOR_EXAMPLE"
	shell::logger::command "${1-}"
}

# @description Print an indented line.
#   Two argument forms are accepted: `(level color message)` or, as a
#   shorthand, `(level message)` which uses the default grey colour.
# @arg $1 integer Indent level 0-5 (2 spaces per level; out of range = 0).
# @arg $2 string Colour code, or the message when $3 is omitted.
# @arg $3 string Message (when $2 is a colour code).
# @stdout The indented message.
# @exitcode 0 Always.
shell::logger::indent() {
	local level="${1-}"
	local color="${2-}"
	local message="${3-}"

	if ! shell::logger::can "INFO"; then
		return "$RETURN_SUCCESS"
	fi

	# Two-argument shorthand: the second argument is the message.
	if [ -z "$message" ]; then
		message="$color"
		color="$SHELL_COLOR_ITEM"
	fi

	# Accept only a single digit 0-5, otherwise fall back to level 0.
	case "$level" in
	[0-5]) ;;
	*) level=0 ;;
	esac

	# Build the indentation: 2 spaces per level.
	local indent=""
	local i=0
	while [ "$i" -lt $((level * 2)) ]; do
		indent="${indent} "
		i=$((i + 1))
	done

	shell::console::print "${indent}${message}" "$color"
}

# @description Print a "STEP n: ..." progress line.
# @arg $1 integer Step number.
# @arg $2 string Step description.
# @stdout The step line.
# @exitcode 0 Always.
shell::logger::step() {
	if ! shell::logger::can "INFO"; then
		return "$RETURN_SUCCESS"
	fi
	shell::console::print "STEP ${1-}: ${2-}" "$SHELL_COLOR_STEP"
}

# @description Print an indented "NOTE:" line.
# @arg $1 string The note text.
# @stdout The note line.
# @exitcode 0 Always.
shell::logger::note() {
	if ! shell::logger::can "INFO"; then
		return "$RETURN_SUCCESS"
	fi
	shell::console::print "  NOTE: ${1-}" "$SHELL_COLOR_NOTE"
}

# @description Print a titled section separated by horizontal rules.
# @arg $1 string Section title.
# @stdout Rule, title, rule.
# @exitcode 0 Always.
shell::logger::section() {
	if ! shell::logger::can "INFO"; then
		return "$RETURN_SUCCESS"
	fi

	# `printf '%60s' | tr` builds a 60-character rule without bash-only brace
	# expansion ({1..60}), which would not work in every shell.
	local rule
	rule="$(printf '%60s' '' | tr ' ' '=')"

	shell::console::print "$rule" "$SHELL_COLOR_SEPARATOR"
	shell::console::print "  ${1-}" "$SHELL_COLOR_SECTION"
	shell::console::print "$rule" "$SHELL_COLOR_SEPARATOR"
}

# @description Print a command line (prefixed with a glyph) without running it.
# @arg $@ string The command words.
# @stdout "  ▶ <command>"
# @exitcode 0 Always.
shell::logger::command() {
	if ! shell::logger::can "INFO"; then
		return "$RETURN_SUCCESS"
	fi
	shell::console::print "  ${SHELL_GLYPH_COMMAND} $*" "$SHELL_COLOR_COMMAND"
}

# @description Print a command and copy it to the clipboard (dry-run helper).
#   This is the *result* of a `-n / --dry-run` invocation, so it is printed even
#   when the log threshold would normally hide INFO messages. A missing
#   clipboard tool is not an error: the command is still printed.
# @arg $@ string The command words.
# @stdout The highlighted command.
# @exitcode 0 Always.
# @see shell::clipboard::copy
shell::logger::command_clip() {
	local command="$*"

	# Print unconditionally: the user explicitly asked to see this command.
	shell::console::print "  ${SHELL_GLYPH_COMMAND} ${command}" "$SHELL_COLOR_COMMAND"
	# Best-effort clipboard copy; --quiet suppresses "no tool found" noise.
	shell::clipboard::copy --quiet "$command" >/dev/null 2>&1
	return "$RETURN_SUCCESS"
}

# @description Print a command and run it through `eval`.
#   The command is **always executed**; the log threshold only controls whether
#   the command line is echoed. (The previous implementation silently skipped
#   execution when the threshold was above INFO.)
#
#   SECURITY: `eval` re-parses the string. Quote every interpolated value, and
#   never pass untrusted input. Prefer shell::exec::command for argv-style calls.
# @arg $@ string Command string.
# @exitcode 0 The command succeeded.
# @exitcode 2 The command string is empty.
# @exitcode N Exit status of the evaluated command.
shell::logger::execute() {
	local command="$*"

	if [ -z "$command" ]; then
		shell::logger::error "Command is empty"
		return "$RETURN_INVALID"
	fi

	shell::logger::command "$command"
	eval "$command"
}

# @description Run a command string with `eval` and report a ✓ / ✗ result line.
# @arg $1 string Command string (evaluated).
# @arg $2 string Success message (default: "Success").
# @arg $3 string Failure message (default: "Aborted").
# @stdout Echoed command and a result line (only when INFO is enabled).
# @exitcode 0 The command succeeded.
# @exitcode 2 The command string is empty.
# @exitcode N Exit status of the evaluated command.
# @example
#   shell::logger::assert "mkdir -p \"$dir\"" "Directory ready" "mkdir failed"
#
shell::logger::assert() {
	local command="${1-}"
	local success_msg="${2:-Success}"
	local failure_msg="${3:-Aborted}"

	if [ -z "$command" ]; then
		shell::logger::error "Command is empty"
		return "$RETURN_INVALID"
	fi

	# Quiet mode: just run it.
	if ! shell::logger::can "INFO"; then
		eval "$command"
		return $?
	fi

	shell::logger::command "$command"

	local exit_code
	eval "$command"
	exit_code=$?

	if [ "$exit_code" -eq 0 ]; then
		shell::console::print "  ${SHELL_GLYPH_OK} $success_msg" "$SHELL_COLOR_SUCCESS"
	else
		shell::console::print "  ${SHELL_GLYPH_FAIL} $failure_msg (exit code: $exit_code)" "$SHELL_COLOR_ERROR"
	fi

	return "$exit_code"
}

# @description Print a command and run it in a *fresh* `bash -c` process.
#   Unlike shell::logger::execute, the command cannot read or modify the
#   current shell's variables, functions or working directory.
# @arg $@ string Command string.
# @exitcode 0 The command succeeded.
# @exitcode 2 The command string is empty.
# @exitcode N Exit status of the command.
shell::logger::dispatch() {
	local command="$*"

	if [ -z "$command" ]; then
		shell::logger::error "Command is empty"
		return "$RETURN_INVALID"
	fi

	shell::logger::command "$command"
	bash -c "$command"
}

# @description Like shell::logger::assert, but runs in a fresh `bash -c` process.
# @arg $1 string Command string.
# @arg $2 string Success message (default: "Success").
# @arg $3 string Failure message (default: "Aborted").
# @stdout Echoed command and a result line (only when INFO is enabled).
# @exitcode 0 The command succeeded.
# @exitcode 2 The command string is empty.
# @exitcode N Exit status of the command.
# @see shell::logger::assert
shell::logger::evaluate() {
	local command="${1-}"
	local success_msg="${2:-Success}"
	local failure_msg="${3:-Aborted}"

	if [ -z "$command" ]; then
		shell::logger::error "Command is empty"
		return "$RETURN_INVALID"
	fi

	if ! shell::logger::can "INFO"; then
		bash -c "$command"
		return $?
	fi

	shell::logger::command "$command"

	local exit_code
	bash -c "$command"
	exit_code=$?

	if [ "$exit_code" -eq 0 ]; then
		shell::console::print "  ${SHELL_GLYPH_OK} $success_msg" "$SHELL_COLOR_SUCCESS"
	else
		shell::console::print "  ${SHELL_GLYPH_FAIL} $failure_msg (exit code: $exit_code)" "$SHELL_COLOR_ERROR"
	fi

	return "$exit_code"
}
