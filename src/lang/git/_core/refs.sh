#!/usr/bin/env bash
# @file lang/git/_core/refs.sh
# @brief Safe ref validation and bounded ref queries.
# @description
#   Every branch name, ref and revision that reaches git is validated first and passed after `--`
#   or `--end-of-options`, so a branch named `-rf` can never be read as an option. Queries use
#   plumbing formats and a constant number of git calls.

# @internal
# @description Validate a branch name: not empty, not starting with `-`, accepted by `git check-ref-format --branch`.
# @arg $1 string The name.
# @exitcode 0 Valid.
# @exitcode 1 Invalid.
# @example
#   _shell::git::core::valid_branch "$name" || return 2
#
_shell::git::core::valid_branch() {
	case "${1-}" in
	"" | -*) return 1 ;;
	esac
	_shell::git::core::git_ro check-ref-format --branch "$1" >/dev/null 2>&1 || return 1
}

# @internal
# @description Tell whether a revision resolves to a commit. A leading `-` is refused before git sees it.
# @arg $1 string The revision.
# @stdout The full commit hash.
# @exitcode 0 It resolves.
# @exitcode 1 It does not (or looks like an option).
# @example
#   sha="$(_shell::git::core::rev "$ref")" || return 2
#
_shell::git::core::rev() {
	case "${1-}" in
	"" | -*) return 1 ;;
	esac
	if _shell::git::core::git_ge 2 30; then
		_shell::git::core::git_ro rev-parse --verify --quiet --end-of-options "$1^{commit}" 2>/dev/null
	else
		_shell::git::core::git_ro rev-parse --verify --quiet "$1^{commit}" 2>/dev/null
	fi
}

# @internal
# @description Print the ahead/behind counts of a ref against another, with ONE `rev-list --left-right --count`.
# @arg $1 string Left ref (what "ahead" counts), for example `HEAD`.
# @arg $2 string Right ref (what "behind" counts), for example `origin/main`.
# @stdout `<ahead> <behind>` on one line.
# @exitcode 0 Counted.
# @exitcode 1 A ref does not exist.
# @example
#   read -r ahead behind <<EOF
#   $(_shell::git::core::ahead_behind HEAD '@{upstream}')
#   EOF
#
_shell::git::core::ahead_behind() {
	local out
	out="$(_shell::git::core::git_ro rev-list --left-right --count "$1...$2" -- 2>/dev/null)" || return 1
	printf '%s\n' "${out//$'\t'/ }"
}

# @internal
# @description Print the local branches merged into a base branch, never the current one, the base,
#   a protected name or a branch checked out in a worktree. Reuses `shell::git::branch::merged`.
#   A branch that was squash-merged is NOT detected: its commits are not in the base's history.
# @arg $1 string Optional base (default: the resolved base branch).
# @stdout One branch per line.
# @exitcode 0 Listed (maybe empty).
# @exitcode 1 No base branch.
# @example
#   _shell::git::core::merged_branches main
#
_shell::git::core::merged_branches() {
	local base="${1-}"
	[ -n "$base" ] || base="$(_shell::git::core::base)" || return 1
	case "$base" in origin/*) base="${base#origin/}" ;; esac
	shell::git::branch::merged --base "$base"
}

# @internal
# @description Print the local branches whose last commit is older than N days (`SHELL_GIT_STALE_DAYS`). Reuses `shell::git::branch::stale`.
# @arg $1 integer Optional days.
# @stdout One tab-separated line per branch, as `shell::git::branch::stale --plain` prints it.
# @exitcode 0 Listed.
# @exitcode 1 Not a repository.
# @example
#   _shell::git::core::stale_branches 60
#
_shell::git::core::stale_branches() {
	if [ -n "${1-}" ]; then
		shell::git::branch::stale --plain --days "$1"
	else
		shell::git::branch::stale --plain
	fi
}

# @internal
# @description Print the files in conflict (unmerged paths), NUL separated, using `diff --name-only --diff-filter=U -z`.
# @stdout NUL-terminated paths.
# @exitcode 0 Always (empty when there is no conflict).
# @example
#   _shell::git::core::conflicts | while IFS= read -r -d '' f; do echo "$f"; done
#
_shell::git::core::conflicts() {
	_shell::git::core::git_ro diff --name-only --diff-filter=U -z 2>/dev/null
	return 0
}

# @internal
# @description Print the branches checked out in any worktree (one `worktree list --porcelain` call).
# @stdout One short branch name per line.
# @exitcode 0 Always.
# @example
#   _shell::git::core::worktree_branches
#
_shell::git::core::worktree_branches() {
	local line
	while IFS= read -r line; do
		case "$line" in "branch refs/heads/"*) printf '%s\n' "${line#branch refs/heads/}" ;; esac
	done <<LZ_EOF
$(_shell::git::core::git_ro worktree list --porcelain 2>/dev/null)
LZ_EOF
	return 0
}

# @internal
# @description Hide the password of `https://user:token@host/...` remotes before they are shown.
# @arg $1 string A remote URL.
# @stdout The URL with the credentials replaced by `***`.
# @exitcode 0 Always.
# @example
#   _shell::git::core::mask_url "https://me:secret@github.com/a/b.git"   # https://***@github.com/a/b.git
#
_shell::git::core::mask_url() {
	case "$1" in
	*://*@*)
		local scheme="${1%%://*}" rest="${1#*://}"
		printf '%s://***@%s\n' "$scheme" "${rest#*@}"
		;;
	*) printf '%s\n' "$1" ;;
	esac
}
