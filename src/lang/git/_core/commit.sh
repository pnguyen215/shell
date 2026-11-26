#!/usr/bin/env bash
# @file lang/git/_core/commit.sh
# @brief Private helpers shared by the shell::git::commit::* functions.
# @description
#   Owned by the commit group. Functions here are named `_shell::git::core::commit_<name>`, are marked
#   `# @internal`, and are used by more than one action of the group.

# @internal
# @description Emit picker records for a commit list with ONE `git log` call (`raw<US>display`, raw = full hash).
#   The number of git invocations does not depend on the number of commits.
# @arg $1 integer Maximum number of commits.
# @arg $2 string Revision or range to walk (already validated).
# @stdout One record per commit, newline terminated.
# @exitcode 0 Always.
# @example
#   _shell::git::core::commit_records 5000 HEAD
#
_shell::git::core::commit_records() {
	local full short rel who subj
	_shell::git::core::git_ro log --max-count="$1" '--format=%H%x1f%h%x1f%cr%x1f%an%x1f%s' "$2" -- 2>/dev/null |
		while IFS=$'\037' read -r full short rel who subj; do
			printf '%s\037%s%s%s  %s%s%s  %s  %s\n' "$full" "${_SHELL_GIT_C_CYAN-}" "$short" "${_SHELL_GIT_C_RESET-}" "${_SHELL_GIT_C_DIM-}" "$rel" "${_SHELL_GIT_C_RESET-}" "$who" "$subj"
		done
	return 0
}

# @internal
# @description Pick commit(s) interactively into a variable, in the CURRENT shell (the picker may read prompt
#   answers from a file whose position must survive until the next prompt, so it must not run in a subshell).
# @arg $1 string Name of the variable that receives the selected hashes, one per line.
# @arg $2 integer `1` to allow several selections.
# @arg $3 integer Maximum number of commits listed.
# @arg $4 string Revision or range (already validated).
# @arg $5 string Optional prompt text.
# @exitcode 0 Selected.
# @exitcode 5 Cancelled.
# @exitcode 2 No terminal and no argument.
# @example
#   _shell::git::core::commit_choose sel 0 500 HEAD "commit" || return $?
#
_shell::git::core::commit_choose() {
	local __var="$1" __multi="$2" __max="$3" __rev="$4" __prompt="${5:-commit}" __tmp __rc __out
	local -a __args=(--prompt "$__prompt" --header "enter: select   esc: cancel   ctrl-/: preview")
	[ "$__multi" = "1" ] && __args+=(--multi)
	__args+=(--preview 'git --no-pager show --stat --color=always {1} -- | head -n 60')
	if _shell::git::core::fzf_ok; then _shell::git::core::colors 1; else _shell::git::core::colors 0; fi
	__tmp="$(mktemp "${TMPDIR:-/tmp}/shell-git-commit.XXXXXX")" || return 1
	# The list goes through a private file rather than a process substitution: it needs no extra
	# process and behaves the same in bash 3.2 and zsh. (The limit keeps the file small.)
	_shell::git::core::commit_records "$__max" "$__rev" >"$__tmp.list"
	_shell::git::core::pick "${__args[@]}" >"$__tmp" <"$__tmp.list"
	__rc=$?
	__out="$(cat "$__tmp")"
	rm -f "$__tmp" "$__tmp.list"
	[ "$__rc" -eq 0 ] || return "$__rc"
	printf -v "$__var" '%s' "$__out"
	return 0
}

# @internal
# @description Same contract as `_shell::git::core::require_idle`, but the idle path runs `operation` without a
#   command substitution. In zsh, `require_idle` leaves descriptor 9 unusable for the answer-file prompt that
#   follows (`_shell::git::core::readline` then fails), so the commit and flow groups use this instead.
# @arg $1 string Optional name of the caller's operation, used in the message.
# @exitcode 0 Idle.
# @exitcode 7 An operation is in progress.
# @example
#   _shell::git::core::commit_idle "squash" || return $?
#
_shell::git::core::commit_idle() {
	local op
	_shell::git::core::operation >/dev/null || return 0
	op="$(_shell::git::core::operation)"
	_shell::git::core::err "a $op is in progress${1:+, refusing to start $1}"
	_shell::git::core::info "finish it (git $op --continue) or abort it (git $op --abort) first"
	return 7
}

# @internal
# @description Explain a failed rebase/revert/merge: conflicts mean exit 6 with the exact way forward.
# @arg $1 string Label of what failed (`squash`, `revert`, ...).
# @exitcode 6 An operation is stopped on conflicts.
# @exitcode 1 It failed for another reason.
# @example
#   _shell::git::core::commit_failed squash; return $?
#
_shell::git::core::commit_failed() {
	local op
	op="$(_shell::git::core::operation)" || op=""
	case "$op" in
	rebase | revert | merge | cherry-pick)
		_shell::git::core::err "$1 stopped: resolve the conflicts, git add the files, then run: git $op --continue"
		_shell::git::core::info "or give up with: git $op --abort"
		return 6
		;;
	esac
	_shell::git::core::err "$1 failed"
	return 1
}

# @internal
# @description Safety checks before rewriting history from a commit up to HEAD: merge commits in the range
#   (refused unless allowed) and commits already reachable from a remote-tracking branch (warned).
#   Uses `rev-list --merges --count` and ONE `for-each-ref --contains` call. Sets `_SHELL_GIT_COMMIT_PUSHED=1`
#   when the oldest rewritten commit is already on a remote branch.
# @arg $1 string The oldest commit that will be rewritten.
# @arg $2 string `1` when merge commits are explicitly allowed (`--allow-merges`).
# @exitcode 0 Go on (after the caller's confirmation).
# @exitcode 2 The range contains merge commits and they were not allowed without a terminal.
# @exitcode 5 The user declined to rewrite across merge commits.
# @example
#   _shell::git::core::commit_guard "$oldest" "$allow_merges" || return $?
#
_shell::git::core::commit_guard() {
	local oldest="$1" allow="$2" range merges remotes ans=""
	_SHELL_GIT_COMMIT_PUSHED=0
	if _shell::git::core::git_ro rev-parse --verify --quiet "$oldest^" >/dev/null 2>&1; then
		range="$oldest^..HEAD"
	else
		range="HEAD"
	fi
	merges="$(_shell::git::core::git_ro rev-list --merges --count "$range" -- 2>/dev/null)"
	if [ "${merges:-0}" -gt 0 ] && [ "$allow" != "1" ]; then
		_shell::git::core::warn "the range contains $merges merge commit(s); rebasing flattens them"
		if ! _shell::git::core::interactive; then
			_shell::git::core::err "refusing to rewrite merge commits: pass --allow-merges to accept this"
			return 2
		fi
		printf 'Rewrite across the merge commit(s) anyway? [y/N] ' >&2
		_shell::git::core::readline ans || ans=""
		case "$ans" in
		y | Y | yes) ;;
		*)
			_shell::git::core::info "aborted, nothing changed"
			return 5
			;;
		esac
	fi
	remotes="$(_shell::git::core::git_ro for-each-ref --contains "$oldest" '--format=%(refname:short)' refs/remotes 2>/dev/null)"
	if [ -n "$remotes" ]; then
		_SHELL_GIT_COMMIT_PUSHED=1
		_shell::git::core::warn "commits to rewrite are already on a remote branch ($(printf '%s\n' "$remotes" | head -n 3 | tr '\n' ' ')): you will need --force-with-lease to push"
	fi
	return 0
}
