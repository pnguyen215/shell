#!/usr/bin/env bash
# @file lang/git/remote/prune.sh
# @brief Prune stale remote-tracking branches after a preview.

# @description Remove the remote-tracking branches of a remote that no longer exist on it. It always shows
#   what would be pruned first (`git remote prune --dry-run`), then asks for a confirmation, then prunes. Only
#   remote-tracking refs are touched; local branches and the remote itself are never changed. With several
#   remotes and no argument the remote is picked interactively.
# @option -n | --dry-run Print both commands (the preview and the prune), execute neither.
# @option -y | --yes Answer the confirmation.
# @option -h | --help Show this help.
# @arg $1 string Optional remote name.
# @stdout The pruned remote-tracking branches, one per line (for example `origin/old`); with `-n` the quoted commands.
# @exitcode 0 Pruned, or nothing to prune (or dry run).
# @exitcode 1 No remote, the remote could not be reached, or git failed.
# @exitcode 2 Invalid usage, unknown remote, or nothing to ask on.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing.
# @exitcode 5 Declined or cancelled; nothing changed.
# @example
#   shell::git::remote::prune origin
#   shell::git::remote::prune -n
#
shell::git::remote::prune() {
	local dry=0 yes="" remote="" chosen rc preview line count=0 pruned=""
	local -a names=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::remote::prune [-n] [-y] [<remote>]"
			return 0
			;;
		-n | --dry-run) dry=1 ;;
		-y | --yes) yes="yes" ;;
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
	if [ "${#names[@]}" -gt 1 ]; then
		_shell::git::core::err "one remote at a time"
		return 2
	fi
	_shell::git::core::env
	_shell::git::core::require_repo || return $?
	chosen="$(_shell::git::core::remote_choose 0 ${names[@]+"${names[@]}"})"
	rc=$?
	[ "$rc" -eq 0 ] || return "$rc"
	remote="$chosen"
	if [ "$dry" = "1" ]; then
		_shell::git::core::dry git remote prune --dry-run "$remote"
		_shell::git::core::dry git remote prune "$remote"
		return 0
	fi
	preview="$(_shell::git::core::remote_git remote prune --dry-run "$remote" 2>&1)"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		printf '%s\n' "$preview" | _shell::git::core::remote_mask_text >&2
		_shell::git::core::err "cannot read the remote '$remote'"
		_shell::git::core::remote_hint "$preview" >&2
		return 1
	fi
	while IFS= read -r line; do
		case "$line" in
		*"[would prune] "*)
			count=$((count + 1))
			pruned="$pruned${line##*\[would prune\] }"$'\n'
			;;
		esac
	done <<LZ_EOF
$preview
LZ_EOF
	if [ "$count" -eq 0 ]; then
		_shell::git::core::info "nothing to prune on '$remote'"
		return 0
	fi
	_shell::git::core::info "would prune from '$remote':"
	printf '%s' "$pruned" | while IFS= read -r line; do printf '  %s\n' "$line" >&2; done
	_shell::git::core::confirm "Prune $count remote-tracking branch(es) of '$remote'?" "$yes" || return $?
	preview="$(_shell::git::core::remote_git remote prune "$remote" 2>&1)"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		printf '%s\n' "$preview" | _shell::git::core::remote_mask_text >&2
		_shell::git::core::err "prune failed"
		return 1
	fi
	printf '%s' "$pruned"
}
