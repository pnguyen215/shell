#!/usr/bin/env bash
# @file lang/git/_core/state.sh
# @brief Repository detection and state: HEAD, upstream, base branch, in-progress operations, tree state.
# @description
#   Read-only helpers. Every query is one git invocation (or one `rev-parse` with several answers),
#   run with `GIT_OPTIONAL_LOCKS=0`, `--no-pager` and `LC_ALL=C` so the output can be parsed.
#   Exit codes of the public functions: 0 ok, 1 failure, 2 usage, 3 not a repository,
#   4 missing dependency, 5 aborted by the user, 6 manual conflict resolution required,
#   7 blocked by a dirty tree or an in-progress operation, 130 interrupted.

# @internal
# @description Run a read-only git command: no pager, no optional locks, no credential prompt, C locale.
# @arg $@ string Arguments of git.
# @stdout What git prints.
# @exitcode * Git's own.
# @example
#   _shell::git::core::git_ro rev-parse --git-dir
#
_shell::git::core::git_ro() {
	GIT_OPTIONAL_LOCKS=0 GIT_TERMINAL_PROMPT=0 LC_ALL=C command git --no-pager "$@"
}

# @internal
# @description Run a git command that changes the repository: no pager, no credential prompt (nothing may hang).
# @arg $@ string Arguments of git.
# @exitcode * Git's own.
# @example
#   _shell::git::core::git_rw branch -d -- old
#
_shell::git::core::git_rw() {
	GIT_TERMINAL_PROMPT=0 command git --no-pager "$@"
}

# @internal
# @description Require a git repository (and, with `--worktree`, a non-bare working tree) around the current directory.
# @arg $1 string Optional `--worktree`.
# @exitcode 0 Inside a repository.
# @exitcode 3 Not a repository, or a bare one when a working tree is required.
# @exitcode 4 git is not installed.
# @example
#   _shell::git::core::require_repo --worktree || return $?
#
_shell::git::core::require_repo() {
	command -v git >/dev/null 2>&1 || {
		_shell::git::core::err "git is not installed"
		return 4
	}
	local inside
	inside="$(_shell::git::core::git_ro rev-parse --is-inside-work-tree 2>/dev/null)"
	if [ "$inside" = "true" ]; then
		return 0
	fi
	if [ "${1-}" != "--worktree" ] && _shell::git::core::git_ro rev-parse --git-dir >/dev/null 2>&1; then
		return 0
	fi
	if _shell::git::core::git_ro rev-parse --git-dir >/dev/null 2>&1; then
		_shell::git::core::err "this command needs a working tree (bare repository or inside .git)"
	else
		_shell::git::core::err "not a git repository"
	fi
	return 3
}

# @internal
# @description Print the current branch name, or nothing on a detached HEAD or an empty repository without commits yet (the unborn branch name is still printed).
# @stdout The short branch name.
# @exitcode 0 On a branch.
# @exitcode 1 Detached HEAD.
# @example
#   branch="$(_shell::git::core::head_branch)" || echo "detached"
#
_shell::git::core::head_branch() {
	_shell::git::core::git_ro symbolic-ref --quiet --short HEAD 2>/dev/null
}

# @internal
# @description Print the upstream of the current branch (for example `origin/main`).
# @arg $1 string Optional branch (default: the current one).
# @stdout The short upstream name.
# @exitcode 0 An upstream is configured.
# @exitcode 1 None.
# @example
#   up="$(_shell::git::core::upstream)" || echo "no upstream"
#
_shell::git::core::upstream() {
	_shell::git::core::git_ro rev-parse --abbrev-ref --symbolic-full-name "${1:-HEAD}@{upstream}" 2>/dev/null || return 1
}

# @internal
# @description Tell whether the configured upstream of the current branch no longer exists on the remote (gone).
# @exitcode 0 The upstream is configured but its remote branch is gone.
# @exitcode 1 Otherwise.
# @example
#   _shell::git::core::upstream_gone && echo "the remote branch was deleted"
#
_shell::git::core::upstream_gone() {
	local ref
	ref="$(_shell::git::core::git_ro for-each-ref --format='%(upstream:track)' "$(_shell::git::core::git_ro symbolic-ref --quiet HEAD 2>/dev/null)" 2>/dev/null)"
	[ "$ref" = "[gone]" ]
}

# @internal
# @description Resolve the base branch other branches are compared with and integrated into.
#   Order: `SHELL_GIT_BASE_BRANCH`, `origin/HEAD`, then `main`, `master`, `develop`. A local branch is
#   preferred; when only the remote-tracking one exists, `origin/<name>` is printed. Never a name that does not exist.
# @stdout The ref.
# @exitcode 0 Found.
# @exitcode 1 No base branch could be determined.
# @example
#   base="$(_shell::git::core::base)" || echo "no base branch"
#
_shell::git::core::base() {
	local cand name
	_shell::git::core::env
	if [ -n "${SHELL_GIT_BASE_BRANCH-}" ]; then
		for cand in "refs/heads/$SHELL_GIT_BASE_BRANCH" "refs/remotes/origin/$SHELL_GIT_BASE_BRANCH"; do
			if _shell::git::core::git_ro rev-parse --verify --quiet "$cand^{commit}" >/dev/null 2>&1; then
				cand="${cand#refs/heads/}"
				printf '%s\n' "${cand#refs/remotes/}"
				return 0
			fi
		done
		return 1
	fi
	name="$(_shell::git::core::git_ro symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
	name="${name#origin/}"
	for cand in $name main master develop; do
		if _shell::git::core::git_ro rev-parse --verify --quiet "refs/heads/$cand^{commit}" >/dev/null 2>&1; then
			printf '%s\n' "$cand"
			return 0
		fi
		if _shell::git::core::git_ro rev-parse --verify --quiet "refs/remotes/origin/$cand^{commit}" >/dev/null 2>&1; then
			printf 'origin/%s\n' "$cand"
			return 0
		fi
	done
	return 1
}

# @internal
# @description Print the operation in progress in the repository (one word) using ONE `rev-parse --git-path` call.
# @stdout `rebase`, `merge`, `cherry-pick`, `revert` or `bisect`; nothing when idle.
# @exitcode 0 An operation is in progress.
# @exitcode 1 Idle.
# @example
#   op="$(_shell::git::core::operation)" && echo "finish the $op first"
#
_shell::git::core::operation() {
	local paths a b c d e f
	paths="$(_shell::git::core::git_ro rev-parse --git-path rebase-merge --git-path rebase-apply --git-path MERGE_HEAD --git-path CHERRY_PICK_HEAD --git-path REVERT_HEAD --git-path BISECT_LOG 2>/dev/null)" || return 1
	{
		read -r a
		read -r b
		read -r c
		read -r d
		read -r e
		read -r f
	} <<LZ_EOF
$paths
LZ_EOF
	if [ -d "$a" ] || [ -d "$b" ]; then
		printf 'rebase\n'
	elif [ -e "$c" ]; then
		printf 'merge\n'
	elif [ -e "$d" ]; then
		printf 'cherry-pick\n'
	elif [ -e "$e" ]; then
		printf 'revert\n'
	elif [ -e "$f" ]; then
		printf 'bisect\n'
	else
		return 1
	fi
	return 0
}

# @internal
# @description Refuse to start something while another operation is in progress.
# @arg $1 string Optional name of the caller's operation, used in the message.
# @exitcode 0 Idle.
# @exitcode 7 An operation is in progress (the message says which, and how to finish or abort it).
# @example
#   _shell::git::core::require_idle "amend" || return $?
#
_shell::git::core::require_idle() {
	local op
	op="$(_shell::git::core::operation)" || return 0
	_shell::git::core::err "a $op is in progress${1:+, refusing to start $1}"
	_shell::git::core::info "finish it (git $op --continue) or abort it (git $op --abort) first"
	return 7
}

# @internal
# @description Count the entries of the working tree with ONE `status --porcelain=v2` call.
# @stdout Four numbers on one line: `staged unstaged untracked conflicted`.
# @exitcode 0 Counted.
# @exitcode 1 git failed.
# @example
#   read -r staged unstaged untracked conflicted <<EOF
#   $(_shell::git::core::tree_counts)
#   EOF
#
_shell::git::core::tree_counts() {
	local rec staged=0 unstaged=0 untracked=0 conflicted=0 xy skip=0
	while IFS= read -r -d '' rec; do
		if [ "$skip" -gt 0 ]; then
			skip=$((skip - 1))
			continue
		fi
		case "$rec" in
		"1 "* | "2 "*)
			xy="${rec#? }"
			xy="${xy%% *}"
			[ "${xy%?}" != "." ] && staged=$((staged + 1))
			[ "${xy#?}" != "." ] && unstaged=$((unstaged + 1))
			# A rename/copy record is followed by one extra NUL-separated field (the original path).
			case "$rec" in "2 "*) skip=1 ;; esac
			;;
		"u "*) conflicted=$((conflicted + 1)) ;;
		"? "*) untracked=$((untracked + 1)) ;;
		esac
	done < <(_shell::git::core::git_ro status --porcelain=v2 -z 2>/dev/null) || true
	printf '%d %d %d %d\n' "$staged" "$unstaged" "$untracked" "$conflicted"
}

# @internal
# @description Block on a dirty tree, or stash it first when the caller opted in.
#   Tracked changes (staged, unstaged, conflicted) count as dirty; untracked files do not.
# @arg $1 string `autostash` to stash a dirty tree (and print the restore reminder) instead of refusing.
# @exitcode 0 Clean, or stashed.
# @exitcode 7 Dirty and no autostash requested.
# @exitcode 1 The stash failed.
# @example
#   _shell::git::core::require_clean "$autostash" || return $?
#
_shell::git::core::require_clean() {
	local staged unstaged untracked conflicted
	read -r staged unstaged untracked conflicted <<LZ_EOF
$(_shell::git::core::tree_counts)
LZ_EOF
	if [ $((staged + unstaged + conflicted)) -eq 0 ]; then
		return 0
	fi
	if [ "${1-}" = "autostash" ]; then
		_shell::git::core::git_rw stash push --quiet -m "shell autostash" || return 1
		_SHELL_GIT_AUTOSTASHED=1
		_shell::git::core::info "stashed your changes (restore with: git stash pop)"
		return 0
	fi
	_shell::git::core::err "the working tree has uncommitted changes ($staged staged, $unstaged unstaged, $conflicted conflicted)"
	_shell::git::core::info "commit or stash them first, or pass --autostash"
	return 7
}
