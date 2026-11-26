#!/usr/bin/env bash
# @file lang/git/repo/stats.sh
# @brief Commit, author and date-range statistics.

# @description Count the commits and authors of the current history, its first and last commit date, and list
#   the most active contributors. ONE `git log` pass piped to awk, whatever the size of the history; an
#   empty repository reports zeros. Authors are told apart by e-mail and shown with their name.
#   Plain mode (`--plain`, or stdout is not a terminal) prints tab-separated rows
#   (`commits`, `authors`, `first`, `last`, then `top<TAB>count<TAB>name`).
# @option --top <n> Number of top contributors to list (default 5).
# @option --max <n> Read at most <n> commits (bounds the cost on huge histories).
# @option --plain Tab-separated rows, no color.
# @option -h | --help Show this help.
# @stdout The statistics.
# @exitcode 0 Success.
# @exitcode 2 Invalid usage.
# @exitcode 3 Not a git repository.
# @example
#   shell::git::repo::stats
#   shell::git::repo::stats --top 10 --max 50000
#
shell::git::repo::stats() {
	local line count name
	_shell::git::core::repo_opts "$@" || return $?
	if [ "$_SHELL_GIT_RP_HELP" = "1" ]; then
		printf 'usage: shell::git::repo::stats [--top N] [--max N] [--plain]\n'
		printf 'Commits, authors, date range and top contributors from one git log pass.\n'
		return 0
	fi
	_shell::git::core::require_repo || return $?
	_shell::git::core::repo_stats_data "$_SHELL_GIT_RP_TOP" "$_SHELL_GIT_RP_MAX"
	if [ "$_SHELL_GIT_RP_PLAIN" = "1" ]; then
		printf 'commits\t%s\nauthors\t%s\nfirst\t%s\nlast\t%s\n' "$_SHELL_GIT_RP_COMMITS" "$_SHELL_GIT_RP_AUTHORS" "$_SHELL_GIT_RP_FIRST" "$_SHELL_GIT_RP_LAST"
		while IFS= read -r line; do
			[ -n "$line" ] && printf 'top\t%s\n' "$line"
		done <<LZ_EOF
$_SHELL_GIT_RP_TOPLIST
LZ_EOF
		return 0
	fi
	_shell::git::core::colors auto
	printf 'commits\t%s\nauthors\t%s\nfirst\t%s\nlast\t%s\n' "$_SHELL_GIT_RP_COMMITS" "$_SHELL_GIT_RP_AUTHORS" "$_SHELL_GIT_RP_FIRST" "$_SHELL_GIT_RP_LAST" | _shell::git::core::align "DIM,"
	if [ -n "$_SHELL_GIT_RP_TOPLIST" ]; then
		printf '\n%stop contributors%s\n' "$_SHELL_GIT_C_DIM" "$_SHELL_GIT_C_RESET"
		while IFS=$'\t' read -r count name; do
			[ -n "$count" ] && printf '  %s%6s%s  %s\n' "$_SHELL_GIT_C_CYAN" "$count" "$_SHELL_GIT_C_RESET" "$name"
		done <<LZ_EOF
$_SHELL_GIT_RP_TOPLIST
LZ_EOF
	fi
	return 0
}
