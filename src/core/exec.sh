#!/usr/bin/env bash
# @file core/exec.sh
# @brief Command execution wrappers with logging and dry-run support.
# @description
#   Two families exist, and choosing the right one matters for safety:
#
#   * **argv style** (shell::exec::command, shell::exec::async): arguments are
#     passed to the program verbatim; no re-parsing, so spaces and quotes in
#     values are safe.
#   * **string style** (shell::exec::shell, shell::exec::silent,
#     shell::exec::safe): the string is run through `eval`, which allows pipes
#     and redirections but re-parses everything. Quote interpolated values and
#     never pass untrusted input.

# @description Run a program directly (argv style) and echo it first.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command (and copy it) instead of running it.
# @arg $1 string Program to run.
# @arg $@ string Arguments passed unchanged to the program.
# @exitcode 0 The program succeeded (or dry-run printed).
# @exitcode 2 No command was given.
# @exitcode N Exit status of the program.
# @example
#   shell::exec::command ls -lah
#   shell::exec::command -n git pull
#
shell::exec::command() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Execute a command directly (no shell re-parsing)"
		shell::logger::usage "shell::exec::command [-n] <command> [arguments...]"
		shell::logger::item "command" "Executable to run"
		shell::logger::item "arguments" "Arguments passed unchanged to the command"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::exec::command ls -lah"
		shell::logger::example "shell::exec::command -n git pull"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if [ "$#" -eq 0 ]; then
		shell::logger::error "Command is required"
		return "$RETURN_INVALID"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$*"
		return "$RETURN_SUCCESS"
	fi

	shell::logger::command "$*"
	"$@"
}

# @description Run a command string through `eval` and echo it first.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $@ string Command string (words are joined with spaces).
# @exitcode 0 The command succeeded (or dry-run printed).
# @exitcode 2 No command was given.
# @exitcode N Exit status of the evaluated command.
# @example
#   shell::exec::shell "ls -lah | grep txt"
#   shell::exec::shell -n "git log | head"
#
shell::exec::shell() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Execute a command string through the shell (eval)"
		shell::logger::usage "shell::exec::shell [-n] <command>"
		shell::logger::item "command" "Shell command string (pipes and redirects allowed)"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::exec::shell \"ls -lah | grep txt\""
		shell::logger::example "shell::exec::shell -n \"git log | head\""
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local command="$*"
	if [ -z "$command" ]; then
		shell::logger::error "Command is required"
		return "$RETURN_INVALID"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$command"
		return "$RETURN_SUCCESS"
	fi

	shell::logger::command "$command"
	eval "$command"
}

# @description Run a command string through `eval` without echoing it.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $@ string Command string.
# @exitcode 0 The command succeeded (or dry-run printed).
# @exitcode 2 No command was given.
# @exitcode N Exit status of the evaluated command.
# @example
#   shell::exec::silent "mkdir -p build"
#
shell::exec::silent() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Execute a command string silently (eval, no echo)"
		shell::logger::usage "shell::exec::silent [-n] <command>"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::exec::silent \"mkdir -p build\""
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local command="$*"
	if [ -z "$command" ]; then
		shell::logger::error "Command is required"
		return "$RETURN_INVALID"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$command"
		return "$RETURN_SUCCESS"
	fi

	eval "$command"
}

# @description Print a command when `dry_run` is true, otherwise execute it.
#   **Bug fix:** the previous implementation printed the command for *both*
#   `true` and `false`, so it could never execute anything.
# @option -h | --help Show help and return.
# @arg $1 string "true" to only print the command, "false" to execute it.
# @arg $2 string Command string (evaluated when executing).
# @exitcode 0 Printed (dry run) or the command succeeded.
# @exitcode 2 Wrong arguments, or $1 is neither "true" nor "false".
# @exitcode N Exit status of the evaluated command.
# @example
#   shell::exec::safe true  "rm -rf build"   # prints only
#   shell::exec::safe false "echo hello"     # runs
#
shell::exec::safe() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Execute a command, or only print it, depending on a flag"
		shell::logger::usage "shell::exec::safe <dry_run> <command>"
		shell::logger::item "dry_run" "true = print only, false = execute"
		shell::logger::item "command" "Command string"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::exec::safe true \"echo Hello\""
		shell::logger::example "shell::exec::safe false \"echo Hello\""
		return "$RETURN_SUCCESS"
	fi

	if [ "$#" -lt 2 ]; then
		shell::logger::error "Usage: shell::exec::safe <true|false> <command>"
		return "$RETURN_INVALID"
	fi

	local dry_run="$1"
	shift

	case "$dry_run" in
	true)
		shell::logger::command_clip "$*"
		return "$RETURN_SUCCESS"
		;;
	false)
		shell::logger::assert "$*"
		return $?
		;;
	*)
		shell::logger::error "First argument must be 'true' or 'false', got '$dry_run'"
		return "$RETURN_INVALID"
		;;
	esac
}

# @description Run a command or function in the background.
#   Unlike the previous version (which evaluated `"<cmd> &"` and never used the
#   PID), this runs the command argv-style and reports the PID.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of starting it.
# @arg $1 string Command or function name.
# @arg $@ string Arguments.
# @stdout "INFO: started in background (pid N)".
# @exitcode 0 Started (or dry-run printed).
# @exitcode 2 No command was given.
# @example
#   shell::exec::async sleep 30
#   shell::exec::async -n my_function arg1
#
shell::exec::async() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Run a command or function in the background"
		shell::logger::usage "shell::exec::async [-n] <command> [arguments...]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::exec::async sleep 30"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if [ "$#" -eq 0 ]; then
		shell::logger::error "No command provided"
		return "$RETURN_INVALID"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$* &"
		return "$RETURN_SUCCESS"
	fi

	"$@" &
	local pid=$!
	shell::logger::info "started in background (pid ${pid}): $*"
	return "$RETURN_SUCCESS"
}

# @description Print the current time in milliseconds since the Unix epoch.
#   Portable across Linux and macOS: `date +%s%3N` is GNU-only and prints a
#   literal "N" on BSD/macOS, so several fallbacks are tried in order:
#   `$EPOCHREALTIME`, GNU `date +%s%N`, `gdate` (Homebrew coreutils), and
#   finally whole seconds.
# @noargs
# @stdout Integer milliseconds.
# @exitcode 0 Always.
shell::exec::now_ms() {
	# bash >= 5.0 and zsh (with zsh/datetime) expose EPOCHREALTIME as "sec.micro".
	if [ -z "${EPOCHREALTIME-}" ] && [ -n "${ZSH_VERSION-}" ]; then
		zmodload zsh/datetime 2>/dev/null
	fi
	if [ -n "${EPOCHREALTIME-}" ]; then
		# bash prints "sec.micro" (6 decimals); zsh prints a float with a variable
		# number of decimals. Split at the separator ("." or "," by locale), pad the
		# fraction to 3 digits and keep exactly milliseconds.
		local seconds="${EPOCHREALTIME%%[.,]*}"
		local fraction="${EPOCHREALTIME#*[.,]}000"
		fraction="${fraction:0:3}"
		# 10# forces base 10 so a fraction such as "065" is not read as octal.
		printf '%s\n' "$((seconds * 1000 + 10#$fraction))"
		return "$RETURN_SUCCESS"
	fi

	# GNU date supports %N (nanoseconds); BSD date prints a literal "N".
	local now
	now="$(date +%s%N 2>/dev/null)"
	case "$now" in
	*N | '') ;; # unsupported - try the next option
	*)
		printf '%s\n' "$((now / 1000000))"
		return "$RETURN_SUCCESS"
		;;
	esac

	if command -v gdate >/dev/null 2>&1; then
		now="$(gdate +%s%N 2>/dev/null)"
		printf '%s\n' "$((now / 1000000))"
		return "$RETURN_SUCCESS"
	fi

	# Last resort: second resolution.
	printf '%s\n' "$(($(date +%s) * 1000))"
}

# @description Run a command and report how long it took.
# @option -h | --help Show help and return.
# @arg $1 string Program or function to run.
# @arg $@ string Arguments.
# @stdout "Execution time: Ns Mms".
# @exitcode 2 No command was given.
# @exitcode N Exit status of the measured command (preserved).
# @example
#   shell::exec::measure sleep 2
#
shell::exec::measure() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Run a command and report its execution time"
		shell::logger::usage "shell::exec::measure <command> [arguments...]"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::exec::measure sleep 2"
		return "$RETURN_SUCCESS"
	fi

	if [ "$#" -eq 0 ]; then
		shell::logger::error "No command provided"
		return "$RETURN_INVALID"
	fi

	local start end elapsed exit_code
	start="$(shell::exec::now_ms)"
	"$@"
	exit_code=$?
	end="$(shell::exec::now_ms)"

	elapsed=$((end - start))
	shell::console::print "Execution time: $((elapsed / 1000))s $((elapsed % 1000))ms" "$SHELL_COLOR_INFO"
	return "$exit_code"
}
