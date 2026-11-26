#!/usr/bin/env bash
# @file lang/git/remote/compare.sh
# @brief Local branches against their remote counterparts.

# @description Compare every local branch with its remote counterpart: ahead/behind counts, gone and missing
#   upstreams. Reads two things only (`for-each-ref` over local branches, one over remote-tracking branches), so
#   the number of git calls does not depend on the number of branches. A branch without an upstream is
#   marked `no upstream` and, when a remote branch of the same name exists, tells which one. Nothing is fetched:
#   run `shell::git::remote::fetch` first for fresh numbers.
# @option -r | --remote <name> Only branches whose upstream is on this remote.
# @option --plain Tab separated lines, no alignment, no color (for scripts).
# @option -h | --help Show this help.
# @stdout One line per branch: name, upstream, state (`in sync`, `ahead N`, `behind N`, `ahead N, behind M`, `gone`, `no upstream`).
# @exitcode 0 Printed.
# @exitcode 1 git failed.
# @exitcode 2 Invalid usage or unknown remote.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing.
# @example
#   shell::git::remote::compare
#   shell::git::remote::compare --remote origin --plain
#
shell::git::remote::compare() {
	local only="" mark plain=0 line name up track rname state rows="" remotes="" cur color r short
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::remote::compare [-r <remote>] [--plain]"
			return 0
			;;
		-r | --remote)
			only="${2-}"
			shift
			;;
		--plain) plain=1 ;;
		*)
			_shell::git::core::err "unknown argument: $1"
			return 2
			;;
		esac
		shift
	done
	_shell::git::core::env
	_shell::git::core::require_repo || return $?
	if [ -n "$only" ] && ! _shell::git::core::remote_exists "$only"; then
		_shell::git::core::err "unknown remote: $only"
		return 2
	fi
	cur="$(_shell::git::core::head_branch)"
	# Remote-tracking branches, for the "same name exists elsewhere" hint (one call).
	remotes="$(_shell::git::core::git_ro for-each-ref --format='%(refname:short)' refs/remotes 2>/dev/null)"
	rows="$(
		_shell::git::core::git_ro for-each-ref --format="%(refname:short)%1f%(upstream:short)%1f%(upstream:track,nobracket)%1f%(upstream:remotename)" refs/heads 2>/dev/null
	)" || return 1
	_shell::git::core::colors auto
	color=""
	[ "$plain" = "0" ] && color="1"
	{
		while IFS=$'\037' read -r name up track rname; do
			[ -n "$name" ] || continue
			if [ -n "$only" ] && [ "$rname" != "$only" ]; then
				continue
			fi
			if [ -z "$up" ]; then
				state="no upstream"
				while IFS= read -r r; do
					short="${r#*/}"
					if [ "$short" = "$name" ]; then
						state="no upstream (${r} exists)"
						break
					fi
				done <<LZ_EOF
$remotes
LZ_EOF
				[ -n "$only" ] && continue
			elif [ "$track" = "gone" ]; then
				state="gone"
			elif [ -z "$track" ]; then
				state="in sync"
			else
				state="$track"
			fi
			if [ "$plain" = "1" ]; then
				printf '%s\t%s\t%s\n' "$name" "${up:--}" "$state"
			else
				mark="  "
				[ "$name" = "$cur" ] && mark="* "
				printf '%s%s\t%s\t%s\n' "$mark" "$name" "${up:--}" "$state"
			fi
		done <<LZ_EOF
$rows
LZ_EOF
	} | if [ -n "$color" ]; then _shell::git::core::align "CYAN,BLUE,"; else cat; fi
	return 0
}
