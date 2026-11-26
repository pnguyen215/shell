#!/usr/bin/env bash
# @file lang/git/repo/summary.sh
# @brief A compact picture of the repository.

# @description Compose the health, history and size reports into a few lines: branch and upstream, working-tree
#   state, branch and stash counts, commits and authors, packed size, and the severity. Same collectors as
#   `repo::health`, `repo::stats` and `repo::size`, so the same bounded number of git calls. Plain mode
#   (`--plain`, or stdout is not a terminal) prints tab-separated `key<TAB>value` rows; the exit status
#   is always 0.
# @option --plain Tab-separated rows, no color.
# @option -h | --help Show this help.
# @stdout The summary.
# @exitcode 0 Success.
# @exitcode 2 Invalid usage.
# @exitcode 3 Not a git repository.
# @example
#   shell::git::repo::summary
#
shell::git::repo::summary() {
	local sev
	_shell::git::core::repo_opts "$@" || return $?
	if [ "$_SHELL_GIT_RP_HELP" = "1" ]; then
		printf 'usage: shell::git::repo::summary [--plain]\n'
		printf 'Branch, working tree, branches, history and size in a few lines.\n'
		return 0
	fi
	_shell::git::core::require_repo || return $?
	_shell::git::core::repo_collect
	_shell::git::core::repo_stats_data 0
	sev="$(_shell::git::core::repo_severity)"
	if [ "$_SHELL_GIT_RP_PLAIN" = "1" ]; then
		_shell::git::core::repo_size_data
		printf 'branch\t%s\nupstream\t%s\nahead\t%s\nbehind\t%s\nstaged\t%s\nunstaged\t%s\nuntracked\t%s\nconflicted\t%s\nlocal_branches\t%s\nremote_branches\t%s\nstash\t%s\ncommits\t%s\nauthors\t%s\npack_kib\t%s\nseverity\t%s\n' \
			"$_SHELL_GIT_RP_HEAD" "${_SHELL_GIT_RP_UP:--}" "$_SHELL_GIT_RP_AHEAD" "$_SHELL_GIT_RP_BEHIND" "$_SHELL_GIT_RP_STAGED" "$_SHELL_GIT_RP_UNSTAGED" \
			"$_SHELL_GIT_RP_UNTRACKED" "$_SHELL_GIT_RP_CONFLICTED" "$_SHELL_GIT_RP_LOCAL" "$_SHELL_GIT_RP_REMOTE" "$_SHELL_GIT_RP_STASH" \
			"$_SHELL_GIT_RP_COMMITS" "$_SHELL_GIT_RP_AUTHORS" "$_SHELL_GIT_RP_SZ_PACK" "$sev"
		return 0
	fi
	_shell::git::core::colors auto
	_shell::git::core::repo_size_data human
	local tree="clean" color="$_SHELL_GIT_C_GREEN" where="$_SHELL_GIT_RP_HEAD"
	[ -n "$_SHELL_GIT_RP_UP" ] && where="$where -> $_SHELL_GIT_RP_UP (ahead $_SHELL_GIT_RP_AHEAD, behind $_SHELL_GIT_RP_BEHIND)"
	if [ "$_SHELL_GIT_RP_STAGED" = "-" ]; then
		tree="bare repository"
	elif [ $((_SHELL_GIT_RP_STAGED + _SHELL_GIT_RP_UNSTAGED + _SHELL_GIT_RP_UNTRACKED + _SHELL_GIT_RP_CONFLICTED)) -gt 0 ]; then
		tree="$_SHELL_GIT_RP_STAGED staged, $_SHELL_GIT_RP_UNSTAGED unstaged, $_SHELL_GIT_RP_UNTRACKED untracked, $_SHELL_GIT_RP_CONFLICTED conflicted"
	fi
	[ "$_SHELL_GIT_RP_SEV" = "1" ] && color="$_SHELL_GIT_C_YELLOW"
	[ "$_SHELL_GIT_RP_SEV" = "2" ] && color="$_SHELL_GIT_C_RED"
	printf 'branch\t%s\nstate\t%s\nbranches\t%s local, %s remote, %s stash(es)\nhistory\t%s commits by %s author(s), %s .. %s\nsize\t%s packed\n' \
		"$where" "$tree" "$_SHELL_GIT_RP_LOCAL" "$_SHELL_GIT_RP_REMOTE" "$_SHELL_GIT_RP_STASH" \
		"$_SHELL_GIT_RP_COMMITS" "$_SHELL_GIT_RP_AUTHORS" "$_SHELL_GIT_RP_FIRST" "$_SHELL_GIT_RP_LAST" "$_SHELL_GIT_RP_SZ_PACK" | _shell::git::core::align "DIM,"
	printf '%sstatus%s  %s%s%s\n' "$_SHELL_GIT_C_DIM" "$_SHELL_GIT_C_RESET" "$color" "$sev" "$_SHELL_GIT_C_RESET"
	return 0
}
