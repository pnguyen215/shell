#!/usr/bin/env bash
# @file lib/process.sh
# @brief Process inspection helpers.

# @description List the processes using the most memory.
#   Uses `ps -axo pid=,user=,%mem=,command=` (the trailing `=` suppresses the
#   header) and `sort`, both of which behave identically on Linux and macOS.
#   The earlier implementation relied on GNU-only `ps --sort` on Linux and on a
#   fragile `top | grep | awk` pipeline on macOS.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 integer How many processes to show (default: 10).
# @stdout One line per process: PID, user, %MEM, command.
# @exitcode 0 Success.
# @exitcode 2 The count is not a positive integer.
# @example
#   shell::process::top_memory 5
#
shell::process::top_memory() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List the processes using the most memory"
		shell::logger::usage "shell::process::top_memory [-n] [count]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::process::top_memory 5"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local count="${1:-10}"
	case "$count" in
	'' | *[!0-9]* | 0)
		shell::logger::error "Count must be a positive integer."
		return "$RETURN_INVALID"
		;;
	esac

	local cmd="ps -axo pid=,user=,%mem=,command= | sort -k3,3 -nr | head -n $count"
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
		return "$RETURN_SUCCESS"
	fi

	shell::exec::shell "$cmd"
}
