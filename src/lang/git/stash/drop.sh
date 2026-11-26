#!/usr/bin/env bash
# @file lang/git/stash/drop.sh
# @brief shell::git::stash::drop

# @description Drop a stash entry after a confirmation, printing the hash of what was dropped.
#   The confirmation names the stash, its date and message. The dropped commit is still in the object store
#   for a while: the hash printed on stdout lets you bring it back with
#   `git stash store -m <message> <hash>`. Later entries move up by one index. Without a terminal, dropping needs
#   `--yes`. Declining changes nothing.
# @option -y | --yes Do not ask for confirmation (required without a terminal).
# @option -n | --dry-run Print the exact command and execute nothing.
# @option -h | --help Show this help.
# @arg $1 string Optional `N` or `stash@{N}`.
# @stdout The full hash of the dropped stash commit.
# @exitcode 0 Dropped.
# @exitcode 1 git failed, or no such stash.
# @exitcode 2 Invalid usage, not a stash reference, no terminal to pick on, or no terminal and no `--yes`.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing.
# @exitcode 5 Cancelled or declined; nothing changed.
# @example
#   shell::git::stash::drop
#   shell::git::stash::drop --yes 2
#
shell::git::stash::drop() {
	local ref="" yes=no dry=0 hash what
	_shell::git::core::env
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::stash::drop [-y|--yes] [-n|--dry-run] [N|stash@{N}]" \
				"Drop a stash after a confirmation and print the dropped hash."
			return 0
			;;
		-y | --yes) yes=yes ;;
		-n | --dry-run) dry=1 ;;
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
		ref="$(_shell::git::core::stash_resolve "$ref")" || return $?
	else
		ref="$(_shell::git::core::stash_pick_one drop)" || return $?
	fi
	if [ "$dry" = "1" ]; then
		_shell::git::core::dry git stash drop "$ref"
		return 0
	fi
	hash="$(_shell::git::core::git_ro rev-parse --verify --quiet "$ref")" || return 1
	what="$(_shell::git::core::git_ro log -1 '--format=%cr: %s' "$ref" -- 2>/dev/null)"
	_shell::git::core::confirm "Drop $ref ($what)?" "$yes" || return $?
	_shell::git::core::git_rw stash drop "$ref" >/dev/null || return 1
	_shell::git::core::info "dropped $ref ($hash)"
	_shell::git::core::info "bring it back with: git stash store -m \"<message>\" $hash"
	printf '%s\n' "$hash"
}
