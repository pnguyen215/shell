#!/usr/bin/env bash
# @file lang/git/stage/unstage.sh
# @brief Pick staged files and unstage them.

# @description Unstage files, keeping their working-tree changes. With paths: exactly those; without: pick from
#   the staged files. A renamed or copied file is unstaged with both of its paths. Uses
#   `git restore --staged` (git 2.23+), `git reset -q --` on older git, and `git rm --cached` in a repository
#   without commits. Conflicted files stop the command with exit 6.
# @option -n | --dry-run Print the exact command, run nothing.
# @option -z Print the unstaged paths NUL-separated.
# @option -h | --help Show this help.
# @arg $@ string Optional paths.
# @stdout The unstaged paths, one per line.
# @exitcode 0 Unstaged (or nothing staged).
# @exitcode 1 git failed.
# @exitcode 2 Invalid usage, or no paths and no terminal to pick from.
# @exitcode 3 Not a git repository with a working tree.
# @exitcode 5 Cancelled.
# @exitcode 6 A selected file has unresolved conflicts.
# @example
#   shell::git::stage::unstage
#   shell::git::stage::unstage -- "a file.txt"
#
shell::git::stage::unstage() {
	local dry=0 nul=0 rc raw
	local -a paths=() targets=() shown=() conflicted=() cmd=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf 'usage: shell::git::stage::unstage [-n|--dry-run] [-z] [--] [path...]\n'
			printf 'Unstage files, keeping their changes; without paths, pick them.\n'
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
	_shell::git::core::stage_select unstage "unstage" -- ${paths[@]+"${paths[@]}"}
	rc=$?
	[ "$rc" -eq 0 ] || return "$rc"
	for raw in ${_SHELL_GIT_ST_RAWS[@]+"${_SHELL_GIT_ST_RAWS[@]}"}; do
		_shell::git::core::stage_parse "$raw"
		case "$_SHELL_GIT_ST_CLASS" in
		c) conflicted+=("$_SHELL_GIT_ST_FILE") ;;
		u) ;;
		*)
			if [ "$_SHELL_GIT_ST_X" != "." ]; then
				targets+=("$_SHELL_GIT_ST_FILE")
				shown+=("$_SHELL_GIT_ST_FILE")
				[ -n "$_SHELL_GIT_ST_ORIG" ] && targets+=("$_SHELL_GIT_ST_ORIG")
			fi
			;;
		esac
	done
	if [ "${#conflicted[@]}" -gt 0 ]; then
		_shell::git::core::stage_conflicts "${conflicted[@]}"
		return 6
	fi
	if [ "${#targets[@]}" -eq 0 ]; then
		_shell::git::core::info "nothing staged to unstage"
		return 0
	fi
	if ! _shell::git::core::git_ro rev-parse --verify --quiet 'HEAD^{commit}' >/dev/null 2>&1; then
		cmd=(rm --cached -q --)
	elif _shell::git::core::git_ge 2 23; then
		cmd=(restore --staged --)
	else
		cmd=(reset -q --)
	fi
	if [ "$dry" = "1" ]; then
		_shell::git::core::stage_dry "${cmd[@]}" "${targets[@]}"
		return 0
	fi
	_shell::git::core::stage_git "${cmd[@]}" "${targets[@]}" || return 1
	_shell::git::core::stage_print "$nul" "${shown[@]}"
	return 0
}
