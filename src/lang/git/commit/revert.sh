#!/usr/bin/env bash
# @file lang/git/commit/revert.sh
# @brief shell::git::commit::revert: revert one or several commits.

# @description Revert commits with `git revert`, newest first (the only order in which later commits
#   cannot conflict with the undoing of earlier ones). Arguments are commits; without arguments they are
#   picked in fzf (multi-select) or a numbered list. A merge commit needs its parent number: pass
#   `--mainline <n>` or, on a terminal, you are asked. The working tree must be clean (exit 7) and no other
#   operation may be in progress (exit 7); the revert is confirmed (`-y` to answer yes). It does not rewrite
#   history, so no backup ref is needed: the reverted commits stay in the log. When a revert stops on
#   conflicts it exits 6 and prints the exact `git revert --continue` / `git revert --abort` commands and
#   the commits that were not applied yet.
# @option -n | --dry-run Print the exact commands and execute nothing.
# @option -y | --yes Confirm without asking (required without a terminal).
# @option -m | --mainline <n> Parent number to use for merge commits.
# @option -h | --help Show this help message.
# @arg $@ string Commits to revert (default: pick).
# @stdout The hash of the new HEAD.
# @exitcode 0 Success (or dry run).
# @exitcode 1 Failure.
# @exitcode 2 Usage error, merge commit without a parent number, or confirmation needed without a terminal.
# @exitcode 3 Not a git repository.
# @exitcode 5 Declined or cancelled; nothing changed.
# @exitcode 6 Conflicts: resolve them, then `git revert --continue` (or `--abort`).
# @exitcode 7 Blocked by a dirty tree or an operation in progress.
# @example
#   shell::git::commit::revert
#   shell::git::commit::revert -y abc1234 def5678
#   shell::git::commit::revert --mainline 1 -n 9f8e7d6
#
shell::git::commit::revert() {
	local dry=0 yes="" mainline="" c sha sel="" merges line count=0 total rc pending="" ans m
	local -a given=() shas=() ordered=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf 'Usage: shell::git::commit::revert [-n] [-y] [-m <parent>] [<commit>...]\n'
			printf 'Revert commits, newest first; stops on conflicts with the way forward (exit 6).\n'
			return 0
			;;
		-n | --dry-run) dry=1 ;;
		-y | --yes) yes="yes" ;;
		-m | --mainline)
			case "${2-}" in
			"" | *[!0-9]* | 0)
				_shell::git::core::err "$1 needs a parent number (1, 2, ...)"
				return 2
				;;
			esac
			mainline="$2"
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
	if ! _shell::git::core::git_ro rev-parse --verify --quiet 'HEAD^{commit}' >/dev/null 2>&1; then
		_shell::git::core::err "this repository has no commits yet"
		return 1
	fi

	if [ "${#given[@]}" -gt 0 ]; then
		for c in "${given[@]}"; do
			sha="$(_shell::git::core::rev "$c")" || {
				_shell::git::core::err "not a commit: $c"
				return 2
			}
			shas+=("$sha")
		done
	else
		if [ "$dry" = "1" ] && ! _shell::git::core::interactive; then
			_shell::git::core::err "a commit is required (nothing to pick on without a terminal)"
			return 2
		fi
		_shell::git::core::commit_choose sel 1 500 HEAD "revert" || return $?
		while IFS= read -r line; do
			[ -n "$line" ] && shas+=("$line")
		done <<LZ_EOF
$sel
LZ_EOF
	fi
	[ "${#shas[@]}" -gt 0 ] || return 5

	# Newest first, by topology: ONE rev-list call for the whole selection.
	while IFS= read -r line; do
		[ -n "$line" ] && ordered+=("$line")
	done <<LZ_EOF
$(_shell::git::core::git_ro rev-list --topo-order --no-walk "${shas[@]}" --)
LZ_EOF
	total="${#ordered[@]}"

	# Which of them are merge commits? ONE call.
	merges="$(_shell::git::core::git_ro rev-list --merges --no-walk "${ordered[@]}" -- 2>/dev/null)"
	if [ -n "$merges" ] && [ -z "$mainline" ]; then
		if [ "$dry" = "1" ] || ! _shell::git::core::interactive; then
			_shell::git::core::err "a merge commit needs its parent number: pass --mainline <n>"
			return 2
		fi
		printf 'Parent number to keep for the merge commit(s) (usually 1): ' >&2
		_shell::git::core::readline ans || return 5
		case "$ans" in
		"" | *[!0-9]* | 0)
			_shell::git::core::err "not a parent number: $ans"
			return 2
			;;
		esac
		mainline="$ans"
	fi

	if [ "$dry" = "1" ]; then
		for sha in "${ordered[@]}"; do
			m=""
			case "$merges" in *"$sha"*) m="$mainline" ;; esac
			if [ -n "$m" ]; then
				_shell::git::core::dry git revert --no-edit -m "$m" "$sha"
			else
				_shell::git::core::dry git revert --no-edit "$sha"
			fi
		done
		return 0
	fi

	_shell::git::core::commit_idle "revert" || return $?
	_shell::git::core::require_clean "" || return $?
	_shell::git::core::confirm "Revert ${total} commit(s), newest first?" "$yes" || return $?

	for sha in "${ordered[@]}"; do
		count=$((count + 1))
		m=""
		case "$merges" in *"$sha"*) m="$mainline" ;; esac
		if [ -n "$m" ]; then
			GIT_EDITOR=true _shell::git::core::git_rw revert --no-edit -m "$m" "$sha" >&2
		else
			GIT_EDITOR=true _shell::git::core::git_rw revert --no-edit "$sha" >&2
		fi
		rc=$?
		if [ "$rc" -ne 0 ]; then
			pending=""
			c=0
			for line in "${ordered[@]}"; do
				c=$((c + 1))
				[ "$c" -gt "$count" ] && pending="$pending $line"
			done
			[ -n "$pending" ] && _shell::git::core::info "not applied yet (revert them after continuing):$pending"
			_shell::git::core::commit_failed revert
			return $?
		fi
	done
	_shell::git::core::git_ro rev-parse HEAD
}
