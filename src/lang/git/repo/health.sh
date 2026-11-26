#!/usr/bin/env bash
# @file lang/git/repo/health.sh
# @brief Report the health of the repository.

# @description Report where the repository stands: current branch, working-tree counts (staged, unstaged,
#   untracked, conflicted), upstream with ahead/behind (and whether the upstream is gone), local and remote
#   branch counts, stashes, branches merged and not merged into the resolved base branch, stale branches
#   (older than `SHELL_GIT_STALE_DAYS`, default 90) and any operation in progress (rebase, merge,
#   cherry-pick, revert, bisect). A constant number of git calls whatever the number of branches or files;
#   no `fsck`, no network. Works in a bare repository (the working-tree fields show `-`).
#
#   Plain mode (`--plain`, or stdout is not a terminal): tab-separated `key<TAB>value` rows, no color, and the
#   exit status is the severity: 0 healthy, 1 warnings (uncommitted changes, detached HEAD, behind or gone
#   upstream, stale branches), 2 problems (unresolved conflicts, an operation in progress).
#   On a terminal the report is aligned and colored and the exit status is 0.
# @option --plain Tab-separated rows and severity as exit status.
# @option -h | --help Show this help.
# @stdout The report.
# @exitcode 0 Healthy (plain mode), or any state on a terminal.
# @exitcode 1 Warnings (plain mode).
# @exitcode 2 Problems (plain mode), or invalid usage.
# @exitcode 3 Not a git repository.
# @example
#   shell::git::repo::health
#   shell::git::repo::health --plain | awk -F'\t' '$1 == "severity" { print $2 }'
#
shell::git::repo::health() {
	_shell::git::core::repo_opts "$@" || return $?
	if [ "$_SHELL_GIT_RP_HELP" = "1" ]; then
		printf 'usage: shell::git::repo::health [--plain]\n'
		printf 'Repository health. Plain mode exits 0 healthy, 1 warnings, 2 problems.\n'
		return 0
	fi
	_shell::git::core::require_repo || return $?
	_shell::git::core::repo_collect
	if [ "$_SHELL_GIT_RP_PLAIN" = "1" ]; then
		_shell::git::core::repo_rows
		return "$_SHELL_GIT_RP_SEV"
	fi
	_shell::git::core::colors auto
	local color="$_SHELL_GIT_C_GREEN"
	[ "$_SHELL_GIT_RP_SEV" = "1" ] && color="$_SHELL_GIT_C_YELLOW"
	[ "$_SHELL_GIT_RP_SEV" = "2" ] && color="$_SHELL_GIT_C_RED"
	_shell::git::core::repo_rows | grep -v -e '^severity' -e '^notes' | _shell::git::core::align "DIM,"
	printf '%sseverity%s  %s%s%s' "$_SHELL_GIT_C_DIM" "$_SHELL_GIT_C_RESET" "$color" "$(_shell::git::core::repo_severity)" "$_SHELL_GIT_C_RESET"
	[ -n "$_SHELL_GIT_RP_NOTES" ] && printf '  (%s)' "$_SHELL_GIT_RP_NOTES"
	printf '\n'
	return 0
}
