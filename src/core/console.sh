#!/usr/bin/env bash
# @file core/console.sh
# @brief Colourised terminal output primitives.
# @description
#   Lowest-level output layer. Everything that prints (logger, prompts, help
#   blocks) funnels through shell::console::print so colour handling, NO_COLOR
#   support and escape-sequence behaviour live in exactly one place.

# @description Detect how many colours the terminal supports and cache the result.
#   Runs `tput colors` at most once per shell session (the previous
#   implementation forked `tput` two or three times for *every* printed line).
#   Honours the https://no-color.org convention: when `NO_COLOR` is set and
#   non-empty, colours are disabled.
#
#   The result is stored in the global `_SHELL_CONSOLE_COLORS` (an integer).
#   It is written to a variable rather than echoed so callers do not need a
#   command substitution, which would run in a subshell and lose the cache.
# @noargs
# @set _SHELL_CONSOLE_COLORS integer Number of supported colours (0, 8, 256 ...).
# @exitcode 0 Always.
shell::console::detect_colors() {
	# Already detected in this session - nothing to do.
	if [ -n "${_SHELL_CONSOLE_COLORS-}" ]; then
		return 0
	fi

	# NO_COLOR wins over everything else.
	if [ -n "${NO_COLOR-}" ]; then
		_SHELL_CONSOLE_COLORS=0
		return 0
	fi

	local colors=0
	if command -v tput >/dev/null 2>&1; then
		# tput exits non-zero when TERM is unset or unknown (cron, CI); treat as 0.
		colors="$(tput colors 2>/dev/null)" || colors=0
	fi

	# Guard against empty / non-numeric tput output.
	case "$colors" in
	'' | *[!0-9]*) colors=0 ;;
	esac

	_SHELL_CONSOLE_COLORS="$colors"
	return 0
}

# @description Print a message to stdout in a bold foreground colour.
#   Uses `printf` instead of `echo -e` because `echo` flag handling differs
#   between bash, zsh and the BSD/macOS userland.
#
#   Backslash escapes in the message (`\n`, `\t`, `\033`) are interpreted by
#   default, matching the historical behaviour. Pass `-E` to print verbatim.
# @option -h | --help Show help and return.
# @option -n Do not append a trailing newline.
# @option -e Interpret backslash escapes in the message (default).
# @option -E Print the message verbatim, without interpreting escapes.
# @arg $1 string Message to print.
# @arg $2 integer ANSI 256-colour code, 0-255 (default: 4, blue).
# @stdout The (possibly coloured) message.
# @exitcode 0 Message printed.
# @exitcode 2 Colour code is not an integer between 0 and 255.
# @example
#   shell::console::print "Build finished" 46
#   shell::console::print "Enter name: " 208 -n
#   shell::console::print 'literal \n text' 33 -E
#
shell::console::print() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Print a message in a bold ANSI colour"
		shell::logger::usage "shell::console::print <message> [color_code] [-n] [-e|-E]"
		shell::logger::option "-n" "Do not append a trailing newline"
		shell::logger::option "-e" "Interpret backslash escapes (default)"
		shell::logger::option "-E" "Print the message verbatim"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::console::print \"Done\" 46"
		return "$RETURN_SUCCESS"
	fi

	local message="${1-}"
	local color_code="${2:-4}"

	# Drop <message> and <color_code>; when fewer than two were given, drop
	# whatever exists so the option loop below sees only flags.
	if [ "$#" -ge 2 ]; then
		shift 2
	else
		shift "$#"
	fi

	local escapes="true"
	local newline="true"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n) newline="false" ;;
		-e) escapes="true" ;;
		-E) escapes="false" ;;
		*) ;; # Unknown flags are ignored for backward compatibility.
		esac
		shift
	done

	# A valid colour code is a non-empty string of digits with value <= 255.
	case "$color_code" in
	'' | *[!0-9]*)
		printf 'ERR: Invalid color code! Please provide a number between 0 and 255.\n' >&2
		return "$RETURN_INVALID"
		;;
	esac
	if [ "$color_code" -gt 255 ]; then
		printf 'ERR: Invalid color code! Please provide a number between 0 and 255.\n' >&2
		return "$RETURN_INVALID"
	fi

	# %b interprets backslash escapes (like echo -e); %s prints verbatim.
	local body_fmt="%b"
	if [ "$escapes" = "false" ]; then
		body_fmt="%s"
	fi

	local tail=""
	if [ "$newline" = "true" ]; then
		tail="\n"
	fi

	shell::console::detect_colors
	local colors="$_SHELL_CONSOLE_COLORS"

	if [ "$colors" -ge 256 ]; then
		# \033[1m = bold, \033[38;5;Nm = 256-colour foreground, \033[0m = reset.
		# shellcheck disable=SC2059  # body_fmt/tail are trusted constants
		printf "\033[1m\033[38;5;%sm${body_fmt}\033[0m${tail}" "$color_code" "$message"
	elif [ "$colors" -ge 8 ]; then
		# Fall back to the 8 basic colours by folding the code into 0-7.
		# shellcheck disable=SC2059
		printf "\033[1m\033[3%sm${body_fmt}\033[0m${tail}" "$((color_code % 8))" "$message"
	else
		# No colour support: plain text.
		# shellcheck disable=SC2059
		printf "${body_fmt}${tail}" "$message"
	fi
}

# @description Show a small text spinner for a fixed number of seconds.
#   Drawn on stderr so it never pollutes data captured from stdout.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print what would be shown instead of animating.
# @arg $1 integer Duration in seconds (default: 3).
# @stderr The animation frames.
# @exitcode 0 Spinner finished (or dry-run printed).
# @exitcode 2 Duration is not a positive integer.
# @example
#   shell::console::spinner 5
#   shell::console::spinner -n 5
#
shell::console::spinner() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Display a loading spinner for a number of seconds"
		shell::logger::usage "shell::console::spinner [-n] [seconds]"
		shell::logger::option "-n, --dry-run" "Print the action instead of animating"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::console::spinner 5"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local duration="${1:-3}"
	case "$duration" in
	'' | *[!0-9]*)
		shell::logger::error "Duration must be a positive integer (seconds)."
		return "$RETURN_INVALID"
		;;
	esac

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "Display loading spinner for ${duration} seconds"
		return "$RETURN_SUCCESS"
	fi

	# SECONDS is a bash/zsh builtin counter of elapsed seconds.
	local end_time=$((SECONDS + duration))
	local frames='|/-\'
	local i=0
	while [ "$SECONDS" -lt "$end_time" ]; do
		# ${frames:i:1} is a 1-character substring (works in bash and zsh).
		printf '\r%s' "${frames:i:1}" >&2
		i=$(((i + 1) % 4))
		sleep 0.1
	done
	# Erase the last frame.
	printf '\r \r' >&2
	return "$RETURN_SUCCESS"
}
