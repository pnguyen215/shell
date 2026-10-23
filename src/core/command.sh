#!/usr/bin/env bash
# @file core/command.sh
# @brief Command-availability checks.

# @description Test whether an executable, builtin, alias or function exists.
#   Uses the `command -v` builtin, which is POSIX and avoids forking `which`
#   (whose exit status and output differ across Linux and macOS).
# @option -h | --help Show help and return.
# @arg $1 string Name of the command to look up.
# @exitcode 0 The command exists.
# @exitcode 1 The command does not exist.
# @exitcode 2 No command name was provided.
# @example
#   if shell::command::exists jq; then echo "jq available"; fi
#
shell::command::exists() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Check whether a command exists in PATH"
		shell::logger::usage "shell::command::exists <command>"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::command::exists git"
		return "$RETURN_SUCCESS"
	fi

	if [ -z "${1-}" ]; then
		return "$RETURN_INVALID"
	fi

	command -v "$1" >/dev/null 2>&1
}
