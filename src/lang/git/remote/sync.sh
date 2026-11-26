#!/usr/bin/env bash
# @file lang/git/remote/sync.sh
# @brief Sync the current branch with its upstream.

# @description Bring the current branch up to date with its upstream (the canonical "sync" of the toolkit).
#   Fetches the upstream's remote, then decides from `rev-list --left-right --count HEAD...@{u}`:
#   - nothing behind: nothing to do (a branch that is only ahead is reported, not pushed);
#   - only behind: fast-forward with `merge --ff-only`;
#   - diverged: merge or rebase, from `--merge` / `--rebase` or an interactive choice, after a preview of
#     both sides and a confirmation. It never resets and never discards commits.
#   A dirty working tree blocks the integration (exit 7) unless `--autostash` is given; an operation in
#   progress also blocks (exit 7); conflicts stop with exit 6 and the exact `--continue` / `--abort` commands.
#   A missing or gone upstream is reported with how to fix it. Network and authentication errors are shown
#   (credentials masked) with a hint, and nothing ever waits for a prompt.
#
#   `shell::git::branch::sync` is a different, older function of the library (it syncs your local branches with
#   origin); no alias is created for it.
# @option -n | --dry-run Print the commands that would run, execute nothing.
# @option -y | --yes Answer the confirmation of a merge or rebase.
# @option --merge Integrate a diverged branch with a merge.
# @option --rebase Integrate a diverged branch with a rebase.
# @option --ff-only Only fast-forward; a diverged branch is an error.
# @option --autostash Stash a dirty tree first and pop it afterwards.
# @option --no-fetch Do not contact the remote; use what is already fetched.
# @option -h | --help Show this help.
# @stdout The new HEAD hash (nothing when there was nothing to do); with `-n` the quoted commands.
# @exitcode 0 Up to date, fast-forwarded or integrated (or dry run).
# @exitcode 1 No upstream, upstream gone, detached HEAD, network failure or git failed.
# @exitcode 2 Invalid usage, or diverged without a strategy and nothing to ask on.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing.
# @exitcode 5 Declined or cancelled.
# @exitcode 6 Conflicts: resolve by hand (the commands are printed).
# @exitcode 7 Dirty tree or an operation in progress.
# @example
#   shell::git::remote::sync
#   shell::git::remote::sync --rebase --autostash
#   shell::git::remote::sync -n
#
shell::git::remote::sync() {
	local dry=0 yes="" strategy="" ffonly=0 autostash="" fetch=1 branch up remote ahead behind msg rc choice integ=""
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::remote::sync [-n] [-y] [--merge|--rebase|--ff-only] [--autostash] [--no-fetch]"
			return 0
			;;
		-n | --dry-run) dry=1 ;;
		-y | --yes) yes="yes" ;;
		--merge) strategy="merge" ;;
		--rebase) strategy="rebase" ;;
		--ff-only) ffonly=1 ;;
		--autostash) autostash="autostash" ;;
		--no-fetch) fetch=0 ;;
		*)
			_shell::git::core::err "unknown argument: $1"
			return 2
			;;
		esac
		shift
	done
	_shell::git::core::env
	_shell::git::core::require_repo --worktree || return $?
	_SHELL_GIT_AUTOSTASHED=0
	_shell::git::core::require_idle "sync" || return $?
	branch="$(_shell::git::core::head_branch)" || {
		_shell::git::core::err "HEAD is detached: check out a branch first"
		return 1
	}
	if _shell::git::core::upstream_gone; then
		_shell::git::core::err "the upstream of '$branch' no longer exists on the remote (gone)"
		_shell::git::core::info "set a new one: git branch --set-upstream-to=<remote>/<branch>   or delete the branch: git branch -d $branch"
		return 1
	fi
	up="$(_shell::git::core::upstream)" || {
		_shell::git::core::err "'$branch' has no upstream"
		_shell::git::core::info "set one: git branch --set-upstream-to=<remote>/<branch>   or push it: git push -u <remote> $branch"
		return 1
	}
	remote="$(_shell::git::core::git_ro config --get "branch.$branch.remote" 2>/dev/null)"

	if [ "$fetch" = "1" ] && [ -n "$remote" ] && [ "$remote" != "." ]; then
		if [ "$dry" = "1" ]; then
			_shell::git::core::dry git fetch -- "$remote"
		else
			msg="$(_shell::git::core::remote_git fetch --quiet -- "$remote" 2>&1)"
			rc=$?
			if [ "$rc" -ne 0 ]; then
				printf '%s\n' "$msg" | _shell::git::core::remote_mask_text >&2
				_shell::git::core::remote_hint "$msg" >&2
				return 1
			fi
		fi
	fi

	read -r ahead behind <<LZ_EOF
$(_shell::git::core::ahead_behind HEAD "$up")
LZ_EOF
	if [ -z "$ahead" ] || [ -z "$behind" ]; then
		_shell::git::core::err "cannot compare '$branch' with '$up'"
		return 1
	fi
	if [ "$behind" -eq 0 ]; then
		if [ "$ahead" -eq 0 ]; then
			_shell::git::core::info "'$branch' is up to date with $up"
		else
			_shell::git::core::info "'$branch' is $ahead commit(s) ahead of $up: nothing to pull (push with: git push)"
		fi
		return 0
	fi

	# Integration is needed: choose how.
	if [ "$ahead" -eq 0 ]; then
		integ="ff"
	else
		if [ "$ffonly" = "1" ]; then
			_shell::git::core::err "'$branch' has diverged from $up ($ahead ahead, $behind behind): cannot fast-forward"
			return 1
		fi
		integ="$strategy"
		if [ -z "$integ" ]; then
			if ! _shell::git::core::interactive && [ -z "${SHELL_GIT_FORCE_FZF-}" ]; then
				_shell::git::core::err "'$branch' has diverged from $up ($ahead ahead, $behind behind): pass --merge or --rebase"
				return 2
			fi
			choice="$(
				_shell::git::core::rec merge "merge   keep both histories, one merge commit"
				_shell::git::core::rec rebase "rebase  replay your $ahead commit(s) on top of $up"
			)"
			integ="$(printf '%s\n' "$choice" | _shell::git::core::pick --prompt "diverged: $ahead ahead, $behind behind")"
			rc=$?
			[ "$rc" -eq 0 ] || return "$rc"
			[ -n "$integ" ] || return 5
		fi
		if [ "$dry" != "1" ]; then
			_shell::git::core::warn "'$branch' has diverged from $up: $ahead local, $behind upstream commit(s)"
			_shell::git::core::git_ro log --oneline --left-right --max-count=20 "HEAD...$up" >&2 2>/dev/null
		fi
	fi

	if [ "$dry" = "1" ]; then
		[ -n "$autostash" ] && _shell::git::core::dry git stash push --quiet -m "shell autostash"
		case "$integ" in
		ff) _shell::git::core::dry git merge --ff-only -- "$up" ;;
		merge) _shell::git::core::dry git merge --no-edit -- "$up" ;;
		rebase) _shell::git::core::dry git rebase "$up" ;;
		esac
		[ -n "$autostash" ] && _shell::git::core::dry git stash pop --quiet
		return 0
	fi

	_shell::git::core::require_clean "$autostash" || return $?
	if [ "$integ" != "ff" ]; then
		_shell::git::core::confirm "Integrate $behind commit(s) of $up into '$branch' by $integ?" "$yes"
		rc=$?
		if [ "$rc" -ne 0 ]; then
			if [ "${_SHELL_GIT_AUTOSTASHED:-0}" = "1" ]; then
				_shell::git::core::git_rw stash pop --quiet >&2
			fi
			return "$rc"
		fi
	fi
	case "$integ" in
	ff) _shell::git::core::git_rw merge --ff-only -- "$up" >&2 ;;
	merge) _shell::git::core::git_rw merge --no-edit -- "$up" >&2 ;;
	rebase) _shell::git::core::git_rw rebase "$up" >&2 ;;
	esac
	rc=$?
	if [ "$rc" -ne 0 ]; then
		if _shell::git::core::operation >/dev/null 2>&1; then
			_shell::git::core::err "$integ stopped: resolve the conflicts by hand"
			_shell::git::core::info "then run: git $integ --continue    or give up with: git $integ --abort"
			[ "${_SHELL_GIT_AUTOSTASHED:-0}" = "1" ] && _shell::git::core::info "your stashed changes are kept: git stash pop (after the $integ is finished)"
			return 6
		fi
		_shell::git::core::err "git $integ failed"
		[ "${_SHELL_GIT_AUTOSTASHED:-0}" = "1" ] && _shell::git::core::git_rw stash pop --quiet >&2
		return 1
	fi
	if [ "${_SHELL_GIT_AUTOSTASHED:-0}" = "1" ]; then
		if ! _shell::git::core::git_rw stash pop --quiet >&2; then
			_shell::git::core::err "your stashed changes conflict with the result: resolve them (the stash is kept)"
			return 6
		fi
	fi
	_shell::git::core::git_ro rev-parse HEAD
}
