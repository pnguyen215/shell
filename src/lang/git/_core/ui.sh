#!/usr/bin/env bash
# @file lang/git/_core/ui.sh
# @brief Colors, reporting and column formatting shared by the Git toolkit.
# @description
#   Output contract: stdout carries results only (refs, hashes, paths, tables, dry-run commands);
#   stderr carries diagnostics, warnings, prompts and progress. Colors are used only when the
#   target is a terminal and NO_COLOR is empty.
#   Colors: green = current/success/added, yellow = modified/warning/pending, red = deleted/error/destructive,
#   cyan = branch names and hashes, blue = remotes/info, dim = timestamps.

# @internal
# @description Set the color variables `_SHELL_GIT_C_{RED,GREEN,YELLOW,BLUE,CYAN,DIM,BOLD,RESET}`.
#   They are empty when colors are off, so they can always be interpolated.
# @arg $1 string `1` on, `0` off, `auto` (default): on only when stdout is a terminal and NO_COLOR is empty.
# @exitcode 0 Always.
# @example
#   _shell::git::core::colors auto
#
_shell::git::core::colors() {
	local mode="${1:-auto}"
	if [ "$mode" = "auto" ]; then
		mode=0
		if [ -z "${NO_COLOR-}" ] && [ -t 1 ] && [ "${TERM-}" != "dumb" ]; then
			mode=1
		fi
	fi
	if [ "$mode" = "1" ] && [ -z "${NO_COLOR-}" ]; then
		_SHELL_GIT_C_RED=$'\033[31m'
		_SHELL_GIT_C_GREEN=$'\033[32m'
		_SHELL_GIT_C_YELLOW=$'\033[33m'
		_SHELL_GIT_C_BLUE=$'\033[34m'
		_SHELL_GIT_C_CYAN=$'\033[36m'
		_SHELL_GIT_C_DIM=$'\033[2m'
		_SHELL_GIT_C_BOLD=$'\033[1m'
		_SHELL_GIT_C_RESET=$'\033[0m'
	else
		_SHELL_GIT_C_RED="" _SHELL_GIT_C_GREEN="" _SHELL_GIT_C_YELLOW="" _SHELL_GIT_C_BLUE=""
		_SHELL_GIT_C_CYAN="" _SHELL_GIT_C_DIM="" _SHELL_GIT_C_BOLD="" _SHELL_GIT_C_RESET=""
	fi
	return 0
}

# @internal
# @description Print an error line on stderr (`error: <message>`), red on a terminal.
# @arg $@ string The message.
# @exitcode 0 Always.
# @example
#   _shell::git::core::err "not a git repository"
#
_shell::git::core::err() {
	if [ -t 2 ] && [ -z "${NO_COLOR-}" ]; then
		printf '\033[31merror:\033[0m %s\n' "$*" >&2
	else
		printf 'error: %s\n' "$*" >&2
	fi
	return 0
}

# @internal
# @description Print a warning line on stderr (`warning: <message>`), yellow on a terminal.
# @arg $@ string The message.
# @exitcode 0 Always.
# @example
#   _shell::git::core::warn "2 commits are already pushed"
#
_shell::git::core::warn() {
	if [ -t 2 ] && [ -z "${NO_COLOR-}" ]; then
		printf '\033[33mwarning:\033[0m %s\n' "$*" >&2
	else
		printf 'warning: %s\n' "$*" >&2
	fi
	return 0
}

# @internal
# @description Print an information line on stderr, unless `SHELL_GIT_QUIET=1`.
# @arg $@ string The message.
# @exitcode 0 Always.
# @example
#   _shell::git::core::info "created refs/shell-backup/amend/20240101T000000Z"
#
_shell::git::core::info() {
	[ "${SHELL_GIT_QUIET-}" = "1" ] && return 0
	printf '%s\n' "$*" >&2
	return 0
}

# @internal
# @description Quote arguments so the line can be pasted into a shell and run as typed.
# @arg $@ string The words of a command.
# @stdout The command on one line, every word quoted when needed.
# @exitcode 0 Always.
# @example
#   _shell::git::core::quote git branch -d -- "my branch"   # git branch -d -- my\ branch
#
_shell::git::core::quote() {
	local out="" word
	for word in "$@"; do
		out="$out$(printf '%q' "$word") "
	done
	printf '%s\n' "${out% }"
}

# @internal
# @description Dry-run output: print the exact quoted command on stdout and execute nothing.
# @arg $@ string The words of the command that would run.
# @stdout The quoted command.
# @exitcode 0 Always.
# @example
#   _shell::git::core::dry git branch -d -- old
#
_shell::git::core::dry() {
	_shell::git::core::quote "$@"
}

# @internal
# @description Align tab-separated columns read from stdin and print them. The last column is not padded.
#   Cell widths are computed on the plain text, then each column is wrapped in its color, so
#   color codes never disturb the alignment.
# @arg $1 string Optional comma-separated list of color variable names per column, e.g. `GREEN,CYAN,DIM,,`; empty entries are uncolored.
# @stdout The aligned table.
# @exitcode 0 Always.
# @example
#   printf 'a\tbbb\nccc\td\n' | _shell::git::core::align "CYAN,"
#
_shell::git::core::align() {
	local spec="${1-}" pal="" name val rest
	rest="$spec,"
	while [ -n "$rest" ]; do
		name="${rest%%,*}"
		rest="${rest#*,}"
		case "$name" in
		RED) val="${_SHELL_GIT_C_RED-}" ;;
		GREEN) val="${_SHELL_GIT_C_GREEN-}" ;;
		YELLOW) val="${_SHELL_GIT_C_YELLOW-}" ;;
		BLUE) val="${_SHELL_GIT_C_BLUE-}" ;;
		CYAN) val="${_SHELL_GIT_C_CYAN-}" ;;
		DIM) val="${_SHELL_GIT_C_DIM-}" ;;
		BOLD) val="${_SHELL_GIT_C_BOLD-}" ;;
		*) val="" ;;
		esac
		pal="$pal$val,"
	done
	awk -F'\t' -v pal="$pal" -v reset="${_SHELL_GIT_C_RESET-}" '
		{ nf[NR] = NF; for (i = 1; i <= NF; i++) { c[NR, i] = $i; if (length($i) > w[i]) w[i] = length($i) } }
		END {
			split(pal, p, ",")
			for (r = 1; r <= NR; r++) {
				line = ""
				for (i = 1; i <= nf[r]; i++) {
					cell = c[r, i]
					pad = ""
					if (i < nf[r]) for (k = length(cell); k < w[i]; k++) pad = pad " "
					if (p[i] != "") cell = p[i] cell reset
					line = line cell pad (i < nf[r] ? "  " : "")
				}
				print line
			}
		}'
}
