#!/usr/bin/env bash
# @file lang/git/branch/cleanup.sh
# @brief shell::git::branch::cleanup

# @description Delete local branches that are already merged into the base branch.
#   Candidates are the branches merged into the base (`SHELL_GIT_BASE_BRANCH`, else `origin/HEAD`, else
#   `main`/`master`/`develop`), never the current branch, the base, a protected name
#   (`SHELL_GIT_PROTECTED_BRANCHES`) or a branch checked out in any worktree. You select several of them (fzf
#   multi-select or numbered prompt), see a summary, and confirm. Deletion uses `git branch -d` only, never `-D`:
#   what git refuses is reported, not forced. Branches that were squash-merged are NOT detected, because their
#   commits are not in the base's history; delete those yourself after checking them.
#   Names given as arguments must be candidates; `--all` takes every candidate. Without a terminal, deleting
#   needs `--yes`. Declining changes nothing.
# @option -b | --base <branch> Compare with this branch instead of the detected base.
# @option -a | --all Select every candidate.
# @option -y | --yes Do not ask for confirmation (required without a terminal).
# @option -n | --dry-run Print the exact commands and execute nothing.
# @option -h | --help Show this help.
# @arg $@ string Optional branches to delete (after `--` if they start with a dash).
# @stdout The deleted branches, one per line (with `-n`, the commands that would run).
# @exitcode 0 Everything selected was deleted, or there was nothing to do.
# @exitcode 1 Git refused to delete some branches, or no base branch exists.
# @exitcode 2 Invalid usage, a name that is not a candidate, or no terminal and no `--yes`.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing.
# @exitcode 5 Cancelled or declined; nothing changed.
# @example
#   shell::git::branch::cleanup
#   shell::git::branch::cleanup --all --yes
#   shell::git::branch::cleanup -n -- old-feature
#
shell::git::branch::cleanup() {
	local base="" all=0 yes=no dry=0 rc recs b line cand sel
	local -a names=()
	_shell::git::core::env
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::branch::cleanup [-b <base>] [-a|--all] [-y|--yes] [-n|--dry-run] [--] [<branch>...]" \
				"Delete merged local branches with 'git branch -d' (never -D). Squash-merged branches are not detected."
			return 0
			;;
		-b | --base)
			[ -n "${2-}" ] || {
				_shell::git::core::err "--base needs a branch"
				return 2
			}
			base="$2"
			shift
			;;
		-a | --all) all=1 ;;
		-y | --yes) yes=yes ;;
		-n | --dry-run) dry=1 ;;
		--)
			shift
			while [ $# -gt 0 ]; do
				names+=("$1")
				shift
			done
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
	_shell::git::core::require_repo || return $?
	if [ -n "$base" ]; then
		_shell::git::core::valid_branch "$base" || {
			_shell::git::core::err "invalid base branch: $base"
			return 2
		}
	else
		base="$(_shell::git::core::base)" || {
			_shell::git::core::err "cannot determine the base branch (set SHELL_GIT_BASE_BRANCH or pass --base)"
			return 1
		}
	fi
	cand="$(_shell::git::core::merged_branches "$base" 2>/dev/null)" || {
		_shell::git::core::err "cannot list branches merged into '$base'"
		return 1
	}
	if [ -z "$cand" ]; then
		_shell::git::core::info "no merged branches to clean up (base: $base)"
		return 0
	fi

	sel=""
	if [ "${#names[@]}" -gt 0 ]; then
		for b in "${names[@]}"; do
			_shell::git::core::valid_branch "$b" || {
				_shell::git::core::err "invalid branch name: $b"
				return 2
			}
			if ! printf '%s\n' "$cand" | grep -qxF -- "$b"; then
				_shell::git::core::err "'$b' is not a candidate (not merged into $base, current, protected, or checked out in a worktree)"
				return 2
			fi
			sel="$sel$b"$'\n'
		done
	elif [ "$all" = "1" ]; then
		sel="$cand"$'\n'
	else
		_shell::git::core::branch_colors
		recs="$(printf '%s\n' "$cand" | while IFS= read -r line; do _shell::git::core::rec "$line" "$line"; done)"
		sel="$(printf '%s\n' "$recs" | _shell::git::core::pick --multi --prompt "delete (merged into $base)" \
			--header "tab: mark  enter: confirm selection  esc: cancel" \
			--preview 'git --no-pager log --oneline --max-count=15 {1} --')"
		rc=$?
		[ "$rc" -eq 0 ] || return "$rc"
		sel="$sel"$'\n'
	fi
	sel="$(printf '%s' "$sel" | sed '/^$/d')"
	[ -n "$sel" ] || return 5

	if [ "$dry" = "1" ]; then
		while IFS= read -r b; do
			_shell::git::core::dry git branch -d -- "$b"
		done <<LZ_EOF
$sel
LZ_EOF
		return 0
	fi

	{
		printf 'Merged into %s, to be deleted with "git branch -d":\n' "$base"
		while IFS= read -r b; do printf '  %s\n' "$b"; done <<LZ_EOF
$sel
LZ_EOF
		printf 'Squash-merged branches are not detected by this check.\n'
	} >&2
	_shell::git::core::confirm "Delete $(printf '%s\n' "$sel" | wc -l | tr -d ' ') branch(es)?" "$yes" || return $?

	rc=0
	while IFS= read -r b; do
		if line="$(_shell::git::core::git_rw branch -d -- "$b" 2>&1)"; then
			printf '%s\n' "$b"
		else
			_shell::git::core::warn "git refused to delete '$b': $(printf '%s' "$line" | tr '\n' ' ')"
			rc=1
		fi
	done <<LZ_EOF
$sel
LZ_EOF
	return "$rc"
}
