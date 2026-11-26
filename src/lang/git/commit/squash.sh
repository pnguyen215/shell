#!/usr/bin/env bash
# @file lang/git/commit/squash.sh
# @brief shell::git::commit::squash: combine the last commits into one.

# @description Squash a range of commits, from an older commit (inclusive) up to HEAD, into one commit that
#   keeps the OLDEST commit's message (or `-m <message>`). The range is a count (`3` = the last three
#   commits) or a commit hash/revision. The rebase is non-interactive: a helper script made with `mktemp`
#   (fixed content, no user data) rewrites the todo list and is removed on every path. This rewrites history,
#   so: another operation in progress blocks it (exit 7); a dirty tree blocks it (exit 7) unless
#   `--autostash`; a range containing merge commits is refused unless `--allow-merges` (or confirmed on a
#   terminal); commits already on a remote branch are warned about; a backup ref
#   `refs/shell-backup/squash/<timestamp>` is created first and its restore command printed; it is
#   confirmed (`-y` to answer yes). Conflicts exit 6 with the `--continue`/`--abort` commands. Without an
#   argument the oldest commit to include is picked in fzf (or a numbered list).
# @option -n | --dry-run Print the exact commands and execute nothing.
# @option -y | --yes Confirm without asking (required without a terminal).
# @option -m | --message <msg> Message of the resulting commit (default: the oldest commit's).
# @option --autostash Stash a dirty tree around the rebase.
# @option --allow-merges Accept rewriting across merge commits.
# @option -h | --help Show this help message.
# @arg $1 string Optional count (at least 2) or the oldest commit to include.
# @stdout The hash of the new HEAD.
# @exitcode 0 Success (or dry run).
# @exitcode 1 Failure.
# @exitcode 2 Usage error, or confirmation needed without a terminal.
# @exitcode 3 Not a git repository.
# @exitcode 5 Declined or cancelled; nothing changed.
# @exitcode 6 Conflicts: resolve them and continue or abort the rebase.
# @exitcode 7 Blocked by a dirty tree or an operation in progress.
# @example
#   shell::git::commit::squash 3
#   shell::git::commit::squash -y -m "feat: login" HEAD~4
#   shell::git::commit::squash -n 2
#
shell::git::commit::squash() {
	local pushed dry=0 yes="" autostash=0 allow=0 target="" msg="" has_msg=0 oldest sel="" total n head rc backup script q
	local -a rb=() ra=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf 'Usage: shell::git::commit::squash [-n] [-y] [-m <msg>] [--autostash] [--allow-merges] [<count>|<commit>]\n'
			printf 'Combine commits (from the given one up to HEAD) into one (backup ref, confirmation).\n'
			return 0
			;;
		-n | --dry-run) dry=1 ;;
		-y | --yes) yes="yes" ;;
		--autostash) autostash=1 ;;
		--allow-merges) allow=1 ;;
		-m | --message)
			if [ $# -lt 2 ]; then
				_shell::git::core::err "$1 needs a message"
				return 2
			fi
			msg="$2"
			has_msg=1
			shift
			;;
		--)
			shift
			[ $# -gt 0 ] && target="$1"
			break
			;;
		-*)
			_shell::git::core::err "unknown option: $1"
			return 2
			;;
		*) target="$1" ;;
		esac
		shift
	done
	_shell::git::core::env
	_shell::git::core::require_repo --worktree || return $?
	if ! _shell::git::core::git_ro rev-parse --verify --quiet 'HEAD^{commit}' >/dev/null 2>&1; then
		_shell::git::core::err "this repository has no commits yet"
		return 1
	fi
	total="$(_shell::git::core::git_ro rev-list --count HEAD 2>/dev/null)"

	case "$target" in
	"" | *[!0-9]*) ;;
	*)
		n="$target"
		if [ "$n" -lt 2 ] || [ "$n" -gt "$total" ]; then
			_shell::git::core::err "the count must be between 2 and $total"
			return 2
		fi
		target="HEAD~$((n - 1))"
		;;
	esac
	if [ -z "$target" ]; then
		if [ "$dry" = "1" ] && ! _shell::git::core::interactive; then
			_shell::git::core::err "a count or commit is required (nothing to pick on without a terminal)"
			return 2
		fi
		_shell::git::core::commit_choose sel 0 500 HEAD "oldest commit to squash" || return $?
		oldest="$sel"
	else
		oldest="$(_shell::git::core::rev "$target")" || {
			_shell::git::core::err "not a commit: $target"
			return 2
		}
	fi
	if ! _shell::git::core::git_ro merge-base --is-ancestor "$oldest" HEAD 2>/dev/null; then
		_shell::git::core::err "$oldest is not an ancestor of HEAD"
		return 2
	fi
	if [ "$oldest" = "$(_shell::git::core::git_ro rev-parse HEAD)" ]; then
		_shell::git::core::err "nothing to squash: the range is a single commit"
		return 2
	fi
	if _shell::git::core::git_ro rev-parse --verify --quiet "$oldest^" >/dev/null 2>&1; then
		rb=("$oldest^")
		n="$(_shell::git::core::git_ro rev-list --count "$oldest^..HEAD" --)"
	else
		rb=(--root)
		n="$total"
	fi
	[ "$autostash" = "1" ] && ra=(--autostash)

	if [ "$dry" = "1" ]; then
		head="$(_shell::git::core::git_ro rev-parse HEAD)"
		_shell::git::core::dry git update-ref -m "shell backup before squash" "$(_shell::git::core::backup_name squash)" "$head"
		printf 'GIT_SEQUENCE_EDITOR=<todo-helper> GIT_EDITOR=true '
		_shell::git::core::dry git rebase -i ${ra[@]+"${ra[@]}"} "${rb[@]}"
		if [ "$has_msg" = "1" ]; then _shell::git::core::dry git commit --amend -m "$msg"; fi
		return 0
	fi

	_shell::git::core::commit_idle "squash" || return $?
	if [ "$autostash" != "1" ]; then
		_shell::git::core::require_clean "" || return $?
	fi
	_shell::git::core::commit_guard "$oldest" "$allow" || return $?
	pushed=""
	if [ "${_SHELL_GIT_COMMIT_PUSHED:-0}" = "1" ]; then pushed=" (already pushed!)"; fi
	_shell::git::core::confirm "Squash ${n} commit(s) into one${pushed}?" "$yes" || return $?

	backup="$(_shell::git::core::backup_ref squash HEAD)" || return 1
	script="$(mktemp "${TMPDIR:-/tmp}/shell-git-seq.XXXXXX")" || return 1
	# Fixed content: keep the first `pick`, turn the others into `fixup` (the oldest message survives).
	printf '%s\n' '#!/bin/sh' \
		'tmp="$1.new"' \
		'awk '"'"'/^pick / { if (seen) sub(/^pick /, "fixup "); seen = 1 } { print }'"'"' "$1" > "$tmp" && cat "$tmp" > "$1"' \
		'rm -f "$tmp"' >"$script"
	chmod +x "$script"
	q="$(printf '%q' "$script")"
	(
		trap 'rm -f "$script" "$script.new"' INT TERM EXIT
		GIT_SEQUENCE_EDITOR="$q" GIT_EDITOR=true _shell::git::core::git_rw rebase -i ${ra[@]+"${ra[@]}"} "${rb[@]}" >&2
	)
	rc=$?
	rm -f "$script"
	if [ "$rc" -ne 0 ]; then
		_shell::git::core::info "backup: $backup"
		_shell::git::core::commit_failed squash
		return $?
	fi
	if [ "$has_msg" = "1" ]; then
		_shell::git::core::git_rw commit -q --amend -m "$msg" >&2 || {
			_shell::git::core::err "squashed, but the new message could not be set (backup: $backup)"
			return 1
		}
	fi
	_shell::git::core::git_ro rev-parse HEAD
}
