#!/usr/bin/env bash
# @file lang/git/stage/pick.sh
# @brief Pick files and stage them.

# @description Stage files. With paths: stage exactly those. Without: pick from the files that have something to
#   stage (unstaged changes, untracked files, conflicts), with the staged and unstaged state in two
#   independent columns. One `git status --porcelain=v2 -z` call lists everything, whatever the number of files.
#   Conflicted files are never staged blindly: the command stops with exit 6 and changes nothing.
#   File names may contain spaces, tabs, newlines, quotes, `*`, unicode or start with `-`.
# @option -n | --dry-run Print the exact `git add` command, run nothing.
# @option -z Print the staged paths NUL-separated.
# @option -h | --help Show this help.
# @arg $@ string Optional paths (after `--` when they start with `-`).
# @stdout The staged paths, one per line.
# @exitcode 0 Staged (or nothing to stage).
# @exitcode 1 git failed.
# @exitcode 2 Invalid usage, or no paths and no terminal to pick from.
# @exitcode 3 Not a git repository with a working tree.
# @exitcode 5 Cancelled.
# @exitcode 6 A selected file has unresolved conflicts.
# @example
#   shell::git::stage::pick
#   shell::git::stage::pick -- "a file.txt" -leading-dash.txt
#   shell::git::stage::pick -n -- notes.md
#
shell::git::stage::pick() {
	local dry=0 nul=0 rc raw
	local -a paths=() add=() conflicted=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf 'usage: shell::git::stage::pick [-n|--dry-run] [-z] [--] [path...]\n'
			printf 'Stage files; without paths, pick them (tab marks, enter confirms, esc cancels).\n'
			return 0
			;;
		-n | --dry-run) dry=1 ;;
		-z) nul=1 ;;
		--)
			shift
			while [ $# -gt 0 ]; do
				paths+=("$1")
				shift
			done
			break
			;;
		-*)
			_shell::git::core::err "unknown option: $1"
			return 2
			;;
		*) paths+=("$1") ;;
		esac
		shift
	done
	_shell::git::core::env
	_shell::git::core::require_repo --worktree || return $?
	_shell::git::core::stage_select stage "stage" -- ${paths[@]+"${paths[@]}"}
	rc=$?
	[ "$rc" -eq 0 ] || return "$rc"
	for raw in ${_SHELL_GIT_ST_RAWS[@]+"${_SHELL_GIT_ST_RAWS[@]}"}; do
		_shell::git::core::stage_parse "$raw"
		case "$_SHELL_GIT_ST_CLASS" in
		c) conflicted+=("$_SHELL_GIT_ST_FILE") ;;
		u) add+=("$_SHELL_GIT_ST_FILE") ;;
		*) [ "$_SHELL_GIT_ST_Y" != "." ] && add+=("$_SHELL_GIT_ST_FILE") ;;
		esac
	done
	if [ "${#conflicted[@]}" -gt 0 ]; then
		_shell::git::core::stage_conflicts "${conflicted[@]}"
		return 6
	fi
	if [ "${#add[@]}" -eq 0 ]; then
		_shell::git::core::info "nothing to stage"
		return 0
	fi
	if [ "$dry" = "1" ]; then
		_shell::git::core::stage_dry add -- "${add[@]}"
		return 0
	fi
	_shell::git::core::stage_git add -- "${add[@]}" || return 1
	_shell::git::core::stage_print "$nul" "${add[@]}"
	return 0
}
