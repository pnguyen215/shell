#!/usr/bin/env bash
# @file lang/git/commit/pick.sh
# @brief shell::git::commit::pick: fuzzy-pick commits and print their hashes.

# @description Pick one or several commits and print their full hashes, one per line.
#   With revisions as arguments nothing is asked: each one is validated and resolved to a commit.
#   Without arguments, on a terminal (or with scripted input), a fuzzy picker lists the commits of `--rev`
#   (default HEAD), newest first, built with ONE `git log` call whatever the history size, at most `--max`
#   commits (default `SHELL_GIT_LOG_LIMIT` or 5000) so the first screen appears immediately. The preview is
#   `git show --stat`, bounded to 60 lines and computed for the focused commit only.
#   Without a terminal and without arguments it refuses (exit 2). Esc or Ctrl-C selects nothing (exit 5).
# @option --multi Allow several selections.
# @option --max <n> Maximum number of commits listed.
# @option --rev <rev> Revision or range to list (default HEAD).
# @option -h | --help Show this help message.
# @arg $@ string Optional revisions to resolve instead of picking.
# @stdout The full hash of every selected commit, one per line.
# @exitcode 0 Success.
# @exitcode 2 Invalid argument, or no terminal to pick on.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is not installed.
# @exitcode 5 Cancelled.
# @example
#   shell::git::commit::pick
#   shell::git::commit::pick --multi --max 200
#   shell::git::commit::pick HEAD~2
#
shell::git::commit::pick() {
	local multi=0 max="" rev="HEAD" c sha sel=""
	local -a given=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf 'Usage: shell::git::commit::pick [--multi] [--max <n>] [--rev <rev>] [<revision>...]\n'
			printf 'Pick commits (fuzzy) or resolve revisions; prints full hashes.\n'
			return 0
			;;
		--multi) multi=1 ;;
		--max | --rev)
			if [ $# -lt 2 ]; then
				_shell::git::core::err "$1 needs a value"
				return 2
			fi
			if [ "$1" = "--max" ]; then max="$2"; else rev="$2"; fi
			shift
			;;
		--)
			shift
			while [ $# -gt 0 ]; do
				given+=("$1")
				shift
			done
			break
			;;
		-*)
			_shell::git::core::err "unknown option: $1"
			return 2
			;;
		*) given+=("$1") ;;
		esac
		shift
	done
	_shell::git::core::env
	_shell::git::core::require_repo --worktree || return $?

	if [ "${#given[@]}" -gt 0 ]; then
		for c in "${given[@]}"; do
			sha="$(_shell::git::core::rev "$c")" || {
				_shell::git::core::err "not a commit: $c"
				return 2
			}
			printf '%s\n' "$sha"
		done
		return 0
	fi

	max="${max:-${SHELL_GIT_LOG_LIMIT:-5000}}"
	case "$max" in
	*[!0-9]* | "" | 0)
		_shell::git::core::err "--max needs a positive number"
		return 2
		;;
	esac
	if ! _shell::git::core::git_ro rev-parse --verify --quiet 'HEAD^{commit}' >/dev/null 2>&1; then
		_shell::git::core::err "this repository has no commits yet"
		return 1
	fi
	_shell::git::core::rev "$rev" >/dev/null || {
		_shell::git::core::err "not a revision: $rev"
		return 2
	}
	_shell::git::core::commit_choose sel "$multi" "$max" "$rev" "commit" || return $?
	printf '%s\n' "$sel"
}
