#!/usr/bin/env bash
# @file lang/git/log/graph.sh
# @brief Compact decorated commit graph.

# @description Print a compact commit graph (`--graph --decorate --oneline`) of HEAD, of given revisions, or of
#   every ref. Colors only when stdout is a terminal and NO_COLOR is empty. Never opens a pager. One git call.
# @option -a | --all Draw every ref.
# @option -m | --max <n> Maximum commits (default 50).
# @option -h | --help Show this help.
# @arg $@ string Optional revisions (branches, tags, hashes); a name that starts with `-` is refused.
# @stdout The graph.
# @exitcode 0 Printed.
# @exitcode 1 git failed (for example an empty repository).
# @exitcode 2 Invalid argument or unknown revision.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing.
# @example
#   shell::git::log::graph
#   shell::git::log::graph --all -m 100
#
shell::git::log::graph() {
	local max=50 all=0 color rc out rev sha
	local -a cmd=() revs=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::log::graph [-a] [-m <n>] [<rev>...]"
			return 0
			;;
		-a | --all) all=1 ;;
		-m | --max)
			_shell::git::core::log_number "${2-}" || {
				_shell::git::core::err "--max needs a positive number"
				return 2
			}
			max="$2"
			shift
			;;
		-*)
			_shell::git::core::err "unknown option: $1"
			return 2
			;;
		*) revs+=("$1") ;;
		esac
		shift
	done
	_shell::git::core::env
	_shell::git::core::require_repo || return $?
	_shell::git::core::colors auto
	color="$(_shell::git::core::log_color out)"
	cmd=(log --graph --decorate --oneline --color="$color" "--max-count=$max")
	[ "$all" = "1" ] && cmd+=(--all)
	for rev in ${revs[@]+"${revs[@]}"}; do
		sha="$(_shell::git::core::rev "$rev")" || {
			_shell::git::core::err "unknown revision: $rev"
			return 2
		}
		cmd+=("$sha")
	done
	out="$(_shell::git::core::git_ro "${cmd[@]}" 2>&1)"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		_shell::git::core::err "git log failed: $out"
		return 1
	fi
	printf '%s\n' "$out"
}
