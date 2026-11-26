#!/usr/bin/env bash
# @file lang/git/_core/confirm.sh
# @brief Prompts: simple and typed confirmations, line input.
# @description
#   Prompts are written to stderr and answered on the terminal (`/dev/tty`), or from the file named by
#   `SHELL_GIT_INPUT` (automation and tests). Without a terminal and without that file nothing is
#   asked: the caller must have been given an explicit `--yes`, otherwise the operation is refused (exit 2).

# @internal
# @description Tell whether prompts can be answered: a terminal is available, or `SHELL_GIT_INPUT` names a file.
# @exitcode 0 Interactive.
# @exitcode 1 Not interactive.
# @example
#   _shell::git::core::interactive || echo "pass explicit arguments"
#
_shell::git::core::interactive() {
	[ -n "${SHELL_GIT_INPUT-}" ] && [ -r "$SHELL_GIT_INPUT" ] && return 0
	[ -t 2 ] && [ -r /dev/tty ] && return 0
	return 1
}

# @internal
# @description Read one line of an answer from the terminal, or from the next line of `SHELL_GIT_INPUT`.
#   The file case keeps its read position in the descriptor 9, opened on first use and closed by `_shell::git::core::input_close`.
# @arg $1 string Variable name that receives the line (default `REPLY`).
# @exitcode 0 A line was read.
# @exitcode 1 End of input.
# @example
#   _shell::git::core::readline answer
#
_shell::git::core::readline() {
	local __name="${1:-REPLY}" __line
	if [ -n "${SHELL_GIT_INPUT-}" ]; then
		if [ "${_SHELL_GIT_INPUT_OPEN-}" != "$SHELL_GIT_INPUT" ]; then
			# `exec` with no command returns the previous status in zsh: test the descriptor itself.
			{ exec 9<"$SHELL_GIT_INPUT"; } 2>/dev/null
			[ -r "$SHELL_GIT_INPUT" ] || return 1
			_SHELL_GIT_INPUT_OPEN="$SHELL_GIT_INPUT"
		fi
		IFS= read -r __line <&9 || return 1
	else
		IFS= read -r __line </dev/tty || return 1
	fi
	printf -v "$__name" '%s' "$__line"
	return 0
}

# @internal
# @description Close the answer file opened by `_shell::git::core::readline` (a no-op otherwise).
# @exitcode 0 Always.
# @example
#   _shell::git::core::input_close
#
_shell::git::core::input_close() {
	if [ -n "${_SHELL_GIT_INPUT_OPEN-}" ]; then
		exec 9<&-
		_SHELL_GIT_INPUT_OPEN=""
	fi
	return 0
}

# @internal
# @description Ask a yes/no question (default no).
# @arg $1 string The question (a summary of what will happen).
# @arg $2 string `yes` when the caller was given `--yes`: answered without asking.
# @exitcode 0 Confirmed.
# @exitcode 5 Declined, aborted or end of input: nothing must happen.
# @exitcode 2 Not interactive and no `--yes`: refused, nothing asked.
# @example
#   _shell::git::core::confirm "Delete 3 branches?" "$assume_yes" || return $?
#
_shell::git::core::confirm() {
	local answer=""
	if [ "${2-}" = "yes" ] || [ "${SHELL_GIT_ASSUME_YES-}" = "1" ]; then
		return 0
	fi
	if ! _shell::git::core::interactive; then
		_shell::git::core::err "$1 needs confirmation: run it in a terminal, or pass --yes"
		return 2
	fi
	printf '%s [y/N] ' "$1" >&2
	_shell::git::core::readline answer || {
		printf '\n' >&2
		return 5
	}
	case "$answer" in
	y | Y | yes | YES | Yes) return 0 ;;
	esac
	_shell::git::core::info "aborted, nothing changed"
	return 5
}

# @internal
# @description Ask the user to type a word to confirm something destructive. `--yes` alone does not satisfy it
#   unless the caller passes `yes` (an explicit, documented flag).
# @arg $1 string The warning.
# @arg $2 string The word to type (for example the branch name or `discard`).
# @arg $3 string `yes` when the caller was given `--yes`.
# @exitcode 0 The word was typed.
# @exitcode 5 Anything else.
# @exitcode 2 Not interactive and no `--yes`.
# @example
#   _shell::git::core::confirm_typed "This drops the stash for good." "drop" "$assume_yes" || return $?
#
_shell::git::core::confirm_typed() {
	local answer=""
	if [ "${3-}" = "yes" ] || [ "${SHELL_GIT_ASSUME_YES-}" = "1" ]; then
		return 0
	fi
	if ! _shell::git::core::interactive; then
		_shell::git::core::err "$1 needs confirmation: run it in a terminal, or pass --yes"
		return 2
	fi
	printf '%s\nType "%s" to continue: ' "$1" "$2" >&2
	_shell::git::core::readline answer || {
		printf '\n' >&2
		return 5
	}
	[ "$answer" = "$2" ] && return 0
	_shell::git::core::info "aborted, nothing changed"
	return 5
}
