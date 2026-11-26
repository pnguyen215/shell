#!/usr/bin/env bash
# @file lang/git/remote/fetch.sh
# @brief Fetch from one or several remotes.

# @description Fetch from the named remotes, from the only remote, or from remotes picked interactively when the
#   repository has several. `--prune` (removing remote-tracking branches that vanished on the remote) is
#   used only when requested. It never waits for a credential prompt (`GIT_TERMINAL_PROMPT=0`, ssh batch
#   mode) and every message shown has credentials masked (`https://***@host`). A failure shows git's message
#   and an actionable hint.
# @option -n | --dry-run Print the commands that would run, execute nothing.
# @option --prune Also prune remote-tracking branches that no longer exist on the remote.
# @option -a | --all Fetch every remote.
# @option -h | --help Show this help.
# @arg $@ string Remote names (each validated against the configured remotes).
# @stdout The names of the remotes fetched, one per line; with `-n` the quoted commands.
# @exitcode 0 Fetched (or dry run).
# @exitcode 1 No remote, a fetch failed, or git failed.
# @exitcode 2 Invalid usage, unknown remote, or several remotes and nothing to ask on.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing.
# @exitcode 5 Cancelled.
# @example
#   shell::git::remote::fetch
#   shell::git::remote::fetch --prune origin upstream
#   shell::git::remote::fetch --all -n
#
shell::git::remote::fetch() {
	local dry=0 prune=0 all=0 chosen rc msg name failed=0
	local -a names=() flags=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::remote::fetch [-n] [--prune] [-a] [<remote>...]"
			return 0
			;;
		-n | --dry-run) dry=1 ;;
		--prune) prune=1 ;;
		-a | --all) all=1 ;;
		--)
			shift
			names+=("$@")
			break
			;;
		-*)
			_shell::git::core::err "unknown option: $1"
			return 2
			;;
		*) names+=("$1") ;;
		esac
		shift
	done
	_shell::git::core::env
	_shell::git::core::require_repo || return $?
	[ "$prune" = "1" ] && flags+=(--prune)
	if [ "$all" = "1" ]; then
		if [ "${#names[@]}" -gt 0 ]; then
			_shell::git::core::err "--all and remote names cannot be combined"
			return 2
		fi
		chosen="$(_shell::git::core::remote_names)"
		if [ -z "$chosen" ]; then
			_shell::git::core::err "this repository has no remote"
			return 1
		fi
	else
		chosen="$(_shell::git::core::remote_choose 0 ${names[@]+"${names[@]}"})"
		rc=$?
		[ "$rc" -eq 0 ] || return "$rc"
	fi
	while IFS= read -r name; do
		[ -n "$name" ] || continue
		if [ "$dry" = "1" ]; then
			_shell::git::core::dry git fetch ${flags[@]+"${flags[@]}"} -- "$name"
			continue
		fi
		msg="$(_shell::git::core::remote_git fetch ${flags[@]+"${flags[@]}"} -- "$name" 2>&1)"
		rc=$?
		[ -n "$msg" ] && printf '%s\n' "$msg" | _shell::git::core::remote_mask_text >&2
		if [ "$rc" -ne 0 ]; then
			_shell::git::core::err "fetch from '$name' failed"
			_shell::git::core::remote_hint "$msg" >&2
			failed=1
			continue
		fi
		printf '%s\n' "$name"
	done <<LZ_EOF
$chosen
LZ_EOF
	[ "$failed" -eq 0 ] || return 1
	return 0
}
