#!/usr/bin/env bash
# @file core/clipboard.sh
# @brief Cross-platform clipboard access.
# @description
#   Tool detection order: `pbcopy` (macOS), `wl-copy` (Wayland), `xclip` and
#   `xsel` (X11), `clip.exe` (WSL). The previous implementation returned exit
#   status 1 on *success* and 0 on *failure*; both are now correct.

# @internal
# @description Print the name of the first available clipboard tool.
# @noargs
# @stdout Tool name, or nothing when none is installed.
# @exitcode 0 A tool was found.
# @exitcode 3 No clipboard tool is available.
shell::clipboard::tool() {
	local tool
	for tool in pbcopy wl-copy xclip xsel clip.exe; do
		if command -v "$tool" >/dev/null 2>&1; then
			printf '%s\n' "$tool"
			return "$RETURN_SUCCESS"
		fi
	done
	return "$RETURN_NOT_FOUND"
}

# @description Copy text to the system clipboard.
# @option -h | --help Show help and return.
# @option -q | --quiet Stay silent when no clipboard tool exists (used by dry-run helpers).
# @option -b | --best-effort Never fail: copying is a convenience, not the purpose of the caller.
# @arg $1 string Text to copy (copied verbatim, no trailing newline added).
# @stdout "✨ Copied (<tool>)" on success (unless --quiet).
# @exitcode 0 Text copied.
# @exitcode 2 No text was given.
# @exitcode 3 No clipboard tool is installed.
# @exitcode 1 The clipboard tool failed.
# @example
#   shell::clipboard::copy "hello"
#   echo "data" | shell::clipboard::copy "$(cat)"
#
shell::clipboard::copy() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Copy text to the system clipboard"
		shell::logger::usage "shell::clipboard::copy [-q] [-b] <text>"
		shell::logger::option "-q, --quiet" "Do not complain when no clipboard tool exists"
		shell::logger::option "-b, --best-effort" "Log problems at debug level and always succeed"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::clipboard::copy \"hello\""
		return "$RETURN_SUCCESS"
	fi

	local quiet="false" best_effort="false"
	while [ "${1-}" = "-q" ] || [ "${1-}" = "--quiet" ] || [ "${1-}" = "-b" ] || [ "${1-}" = "--best-effort" ]; do
		case "$1" in
		-q | --quiet) quiet="true" ;;
		*) best_effort="true" ;;
		esac
		shift
	done

	local value="${1-}"
	if [ -z "$value" ]; then
		[ "$quiet" = "true" ] || shell::logger::error "No value provided to copy."
		return "$RETURN_INVALID"
	fi

	local tool
	tool="$(shell::clipboard::tool)" || {
		if [ "$best_effort" = "true" ]; then
			shell::logger::debug "Clipboard copy skipped: no clipboard tool installed."
			return "$RETURN_SUCCESS"
		fi
		[ "$quiet" = "true" ] || shell::logger::error "No clipboard tool found. Install xclip, xsel or wl-clipboard."
		return "$RETURN_NOT_FOUND"
	}

	# printf '%s' (not echo) so a value like "-n" or "\n" is copied literally.
	local rc=0
	case "$tool" in
	pbcopy) printf '%s' "$value" | pbcopy || rc=$? ;;
	wl-copy) printf '%s' "$value" | wl-copy || rc=$? ;;
	xclip) printf '%s' "$value" | xclip -selection clipboard || rc=$? ;;
	xsel) printf '%s' "$value" | xsel --clipboard --input || rc=$? ;;
	clip.exe) printf '%s' "$value" | clip.exe || rc=$? ;;
	esac

	if [ "$rc" -ne 0 ]; then
		if [ "$best_effort" = "true" ]; then
			shell::logger::debug "Clipboard tool '$tool' failed (exit $rc); ignored."
			return "$RETURN_SUCCESS"
		fi
		[ "$quiet" = "true" ] || shell::logger::error "Clipboard tool '$tool' failed (exit $rc)."
		return "$RETURN_FAILURE"
	fi

	[ "$quiet" = "true" ] || shell::console::print " ${SHELL_GLYPH_COPIED} Copied (${tool})" "$SHELL_COLOR_DEBUG"
	return "$RETURN_SUCCESS"
}

# @description Copy the current working directory to the clipboard.
# @option -h | --help Show help and return.
# @stdout "✨ Copied (<tool>)".
# @exitcode 0 Path copied.
# @exitcode 3 No clipboard tool is installed.
# @see shell::clipboard::copy
shell::clipboard::copy_cwd() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Copy the current working directory to the clipboard"
		shell::logger::usage "shell::clipboard::copy_cwd"
		shell::logger::option "-h, --help" "Display this help message"
		return "$RETURN_SUCCESS"
	fi
	shell::clipboard::copy "$PWD"
}
