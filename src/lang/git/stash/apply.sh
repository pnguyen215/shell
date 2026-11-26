#!/usr/bin/env bash
# @file lang/git/stash/apply.sh
# @brief shell::git::stash::apply

# @description Apply a stash to the working tree and keep it.
#   Runs `git stash apply`, never `pop`: the stash stays in the list whatever happens, so a conflict never
#   costs you the saved work. When the apply stops on conflicts it says so and exits 6; resolve the files, then
#   drop the stash yourself when you are done (`shell::git::stash::drop`). Refuses while a merge, rebase,
#   cherry-pick or revert is in progress (exit 7). With no argument you pick the stash.
# @option --index Also restore the staged state (`git stash apply --index`).
# @option -n | --dry-run Print the exact command and execute nothing.
# @option -h | --help Show this help.
# @arg $1 string Optional `N` or `stash@{N}`.
# @stdout The applied stash reference.
# @exitcode 0 Applied cleanly.
# @exitcode 1 git failed (for example local changes would be overwritten), or no such stash.
# @exitcode 2 Invalid usage, not a stash reference, or no terminal to pick on.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing.
# @exitcode 5 Cancelled.
# @exitcode 6 Applied with conflicts to resolve by hand; the stash is kept.
# @exitcode 7 Blocked by an operation in progress.
# @example
#   shell::git::stash::apply
#   shell::git::stash::apply --index 1
#
shell::git::stash::apply() {
	local ref="" index=0 dry=0 rc junk
	local -a args=()
	_shell::git::core::env
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::stash::apply [--index] [-n] [N|stash@{N}]" \
				"Apply a stash and keep it (exit 6 on conflicts)."
			return 0
			;;
		--index) index=1 ;;
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
		ref="$(_shell::git::core::stash_pick_one apply)" || return $?
	fi
	args=(stash apply)
	[ "$index" = "1" ] && args+=(--index)
	args+=("$ref")
	if [ "$dry" = "1" ]; then
		_shell::git::core::dry git "${args[@]}"
		return 0
	fi
	_shell::git::core::require_idle "stash apply" || return $?
	_shell::git::core::git_rw "${args[@]}" >&2
	rc=$?
	if [ "$rc" -ne 0 ]; then
		if _shell::git::core::conflicts | IFS= read -r -d '' junk; then
			_shell::git::core::err "applying $ref left conflicts; the stash is kept"
			_shell::git::core::info "resolve the files, stage them, and drop the stash when done: shell::git::stash::drop $ref"
			return 6
		fi
		_shell::git::core::err "could not apply $ref (the stash is kept)"
		return 1
	fi
	printf '%s\n' "$ref"
}
