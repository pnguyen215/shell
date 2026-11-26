#!/usr/bin/env bash
# @file lang/git/_core/stash.sh
# @brief Private helpers shared by the shell::git::stash::* functions.
# @description
#   Owned by the stash group. The list is ONE `git stash list` call formatted in ONE awk pass; the number
#   of files of a stash is computed lazily, in the preview of the focused entry only.

# @internal
# @description Validate a stash reference and print it normalized as `stash@{N}`.
#   Accepts `N` or `stash@{N}`; anything else (a revision, an option, a path) is refused before git sees it.
# @arg $1 string The user's reference.
# @stdout The normalized reference.
# @exitcode 0 The stash exists.
# @exitcode 1 No such stash.
# @exitcode 2 Not a stash reference.
# @example
#   ref="$(_shell::git::core::stash_resolve 0)" || return $?
#
_shell::git::core::stash_resolve() {
	local arg="${1-}" n ref
	case "$arg" in
	stash@\{*\})
		n="${arg#stash@\{}"
		n="${n%\}}"
		;;
	*) n="$arg" ;;
	esac
	case "$n" in
	"" | *[!0-9]*)
		_shell::git::core::err "not a stash reference: $arg (use N or stash@{N})"
		return 2
		;;
	esac
	ref="stash@{$n}"
	if ! _shell::git::core::git_ro rev-parse --verify --quiet "$ref" >/dev/null 2>&1; then
		_shell::git::core::err "no such stash: $ref"
		return 1
	fi
	printf '%s\n' "$ref"
}

# @internal
# @description Print picker records (`raw<US>display`) for the stash entries: index, date, source branch, message.
#   ONE `git stash list` call, ONE awk pass.
# @stdout One record per stash; the raw field is `stash@{N}`.
# @exitcode 0 Listed (maybe nothing).
# @example
#   _shell::git::core::stash_records | _shell::git::core::pick
#
_shell::git::core::stash_records() {
	_shell::git::core::git_ro stash list '--format=%gd%x1f%cr%x1f%gs' |
		awk -F'\037' -v cc="${_SHELL_GIT_C_CYAN-}" -v cd="${_SHELL_GIT_C_DIM-}" -v cb="${_SHELL_GIT_C_BLUE-}" -v cr="${_SHELL_GIT_C_RESET-}" '
			function pad(s, w,   k, out) { out = s; for (k = length(s); k < w; k++) out = out " "; return out }
			{
				n++; ref[n] = $1; dt[n] = $2
				s = $3; sub(/^(WIP on|On) /, "", s)
				i = index(s, ": ")
				if (i > 0) { br[n] = substr(s, 1, i - 1); msg[n] = substr(s, i + 2) } else { br[n] = ""; msg[n] = s }
				if (length($1) > wr) wr = length($1)
				if (length($2) > wd) wd = length($2)
				if (length(br[n]) > wb) wb = length(br[n])
			}
			END {
				for (i = 1; i <= n; i++)
					printf "%s\037%s  %s  %s  %s\n", ref[i], cc pad(ref[i], wr) cr, cd pad(dt[i], wd) cr, cb pad(br[i], wb) cr, msg[i]
			}'
}

# @internal
# @description Pick ONE stash interactively (fzf or numbered prompt) and print its `stash@{N}` reference.
#   The preview shows the diffstat then a bounded diff of the focused stash only.
# @arg $1 string Prompt text.
# @stdout The selected reference.
# @exitcode 0 Selected.
# @exitcode 1 No stashes.
# @exitcode 2 No terminal to ask on.
# @exitcode 5 Cancelled.
# @example
#   ref="$(_shell::git::core::stash_pick_one "apply")" || return $?
#
_shell::git::core::stash_pick_one() {
	local recs
	_shell::git::core::branch_colors
	recs="$(_shell::git::core::stash_records)" || return 1
	if [ -z "$recs" ]; then
		_shell::git::core::err "no stashes"
		return 1
	fi
	printf '%s\n' "$recs" | _shell::git::core::pick --prompt "${1:-stash}" \
		--header "enter: select  esc: cancel  ctrl-/: toggle preview" \
		--preview 'git --no-pager stash show --stat --color=always {1}; git --no-pager stash show -p --color=always {1} | head -n 200'
}
