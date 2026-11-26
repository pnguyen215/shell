#!/usr/bin/env bash
# @file lang/git/stash/pick.sh
# @brief shell::git::stash::pick

# @description Pick a stash entry and print its reference (`stash@{N}`).
#   Columns: index, date, source branch, message, from ONE `git stash list` call. The preview of the focused
#   entry shows its diffstat and a bounded diff (the file count is computed there, lazily, never for the whole
#   list). With an argument (`N` or `stash@{N}`) nothing is asked: the reference is checked and printed.
#   Cancelling exits 5 and prints nothing; without a terminal and without an argument it exits 2.
# @option -h | --help Show this help.
# @arg $1 string Optional `N` or `stash@{N}`.
# @stdout The selected reference.
# @exitcode 0 A stash was selected or validated.
# @exitcode 1 No stashes, or the stash does not exist.
# @exitcode 2 Invalid usage, not a stash reference, or no terminal to pick on.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing.
# @exitcode 5 Cancelled.
# @example
#   ref="$(shell::git::stash::pick)"
#   shell::git::stash::pick 1
#
shell::git::stash::pick() {
	local ref=""
	_shell::git::core::env
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::stash::pick [N|stash@{N}]" \
				"Pick a stash entry and print its reference (exit 5 when cancelled, 2 without a terminal)."
			return 0
			;;
		--)
			shift
			[ $# -gt 0 ] && ref="$1"
			break
			;;
		-*)
			_shell::git::core::err "unknown option: $1"
			return 2
			;;
		*) ref="$1" ;;
		esac
		shift
	done
	_shell::git::core::require_repo --worktree || return $?
	if [ -n "$ref" ]; then
		_shell::git::core::stash_resolve "$ref"
		return $?
	fi
	_shell::git::core::stash_pick_one stash
}
