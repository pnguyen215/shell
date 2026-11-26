#!/usr/bin/env bash
# @file lang/git/commit/fixup.sh
# @brief shell::git::commit::fixup: fold the staged changes into an earlier commit.

# @description Create a fixup commit for an earlier commit from the STAGED changes, then fold it in with a
#   non-interactive `git rebase --autosquash`. This rewrites history from that commit up to HEAD, so:
#   another operation in progress blocks it (exit 7); unstaged changes block it (exit 7) unless
#   `--autostash`; a range containing merge commits is refused unless `--allow-merges` (or confirmed on a
#   terminal); commits already on a remote-tracking branch are warned about; a backup ref
#   `refs/shell-backup/fixup/<timestamp>` is created first and its restore command printed; and it is
#   confirmed (`-y` to answer yes). A failing rebase on conflicts exits 6 with the `--continue`/`--abort`
#   commands. Without a commit argument the commit is picked in fzf (or a numbered list).
# @option -n | --dry-run Print the exact commands and execute nothing.
# @option -y | --yes Confirm without asking (required without a terminal).
# @option --autostash Stash unstaged changes around the rebase.
# @option --allow-merges Accept rewriting across merge commits.
# @option -h | --help Show this help message.
# @arg $1 string Optional commit to fix up (default: pick one).
# @stdout The hash of the new HEAD.
# @exitcode 0 Success (or dry run).
# @exitcode 1 Failure, or nothing is staged.
# @exitcode 2 Usage error, or confirmation needed without a terminal.
# @exitcode 3 Not a git repository.
# @exitcode 5 Declined or cancelled; nothing changed.
# @exitcode 6 Conflicts: resolve them and continue or abort the rebase.
# @exitcode 7 Blocked by unstaged changes or an operation in progress.
# @example
#   shell::git::commit::fixup
#   shell::git::commit::fixup -y HEAD~2
#   shell::git::commit::fixup -n abc1234
#
shell::git::commit::fixup() {
	local pushed dry=0 yes="" autostash=0 allow=0 target="" sha sel="" counts staged unstaged untracked conflicted
	local oldest count rc backup head
	local -a rb=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf 'Usage: shell::git::commit::fixup [-n] [-y] [--autostash] [--allow-merges] [<commit>]\n'
			printf 'Fold the staged changes into an earlier commit (backup ref, confirmation).\n'
			return 0
			;;
		-n | --dry-run) dry=1 ;;
		-y | --yes) yes="yes" ;;
		--autostash) autostash=1 ;;
		--allow-merges) allow=1 ;;
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

	if [ -n "$target" ]; then
		sha="$(_shell::git::core::rev "$target")" || {
			_shell::git::core::err "not a commit: $target"
			return 2
		}
	elif [ "$dry" = "1" ] && ! _shell::git::core::interactive; then
		_shell::git::core::err "a commit is required (nothing to pick on without a terminal)"
		return 2
	else
		_shell::git::core::commit_choose sel 0 500 HEAD "fixup target" || return $?
		sha="$sel"
	fi
	if ! _shell::git::core::git_ro merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then
		_shell::git::core::err "$sha is not an ancestor of HEAD"
		return 2
	fi

	if _shell::git::core::git_ro rev-parse --verify --quiet "$sha^" >/dev/null 2>&1; then
		rb=("$sha^")
	else
		rb=(--root)
	fi

	if [ "$dry" = "1" ]; then
		head="$(_shell::git::core::git_ro rev-parse HEAD)"
		_shell::git::core::dry git update-ref -m "shell backup before fixup" "$(_shell::git::core::backup_name fixup)" "$head"
		_shell::git::core::dry git commit --fixup="$sha"
		printf 'GIT_SEQUENCE_EDITOR=true GIT_EDITOR=true '
		if [ "$autostash" = "1" ]; then
			_shell::git::core::dry git rebase -i --autosquash --autostash "${rb[@]}"
		else
			_shell::git::core::dry git rebase -i --autosquash "${rb[@]}"
		fi
		return 0
	fi

	_shell::git::core::commit_idle "fixup" || return $?
	counts="$(_shell::git::core::tree_counts)"
	read -r staged unstaged untracked conflicted <<LZ_EOF
$counts
LZ_EOF
	if [ "$staged" -eq 0 ]; then
		_shell::git::core::err "nothing is staged: stage the changes to fold into $sha first"
		return 1
	fi
	if [ $((unstaged + conflicted)) -gt 0 ] && [ "$autostash" != "1" ]; then
		_shell::git::core::err "the working tree has unstaged changes ($unstaged) or conflicts ($conflicted)"
		_shell::git::core::info "commit or stash them first, or pass --autostash"
		return 7
	fi

	oldest="$sha"
	_shell::git::core::commit_guard "$oldest" "$allow" || return $?
	count="$(_shell::git::core::git_ro rev-list --count "$sha^..HEAD" -- 2>/dev/null || _shell::git::core::git_ro rev-list --count HEAD)"
	pushed=""
	if [ "${_SHELL_GIT_COMMIT_PUSHED:-0}" = "1" ]; then pushed=" (already pushed!)"; fi
	_shell::git::core::confirm "Fold the staged changes into ${sha} and rewrite ${count} commit(s)${pushed}?" "$yes" || return $?

	backup="$(_shell::git::core::backup_ref fixup HEAD)" || return 1
	_shell::git::core::git_rw commit -q --fixup="$sha" >&2 || {
		_shell::git::core::err "could not create the fixup commit"
		return 1
	}
	if [ "$autostash" = "1" ]; then
		GIT_SEQUENCE_EDITOR=true GIT_EDITOR=true _shell::git::core::git_rw rebase -i --autosquash --autostash "${rb[@]}" >&2
	else
		GIT_SEQUENCE_EDITOR=true GIT_EDITOR=true _shell::git::core::git_rw rebase -i --autosquash "${rb[@]}" >&2
	fi
	rc=$?
	if [ "$rc" -ne 0 ]; then
		_shell::git::core::info "backup: $backup"
		_shell::git::core::commit_failed fixup
		return $?
	fi
	_shell::git::core::git_ro rev-parse HEAD
}
