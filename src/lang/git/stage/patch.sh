#!/usr/bin/env bash
# @file lang/git/stage/patch.sh
# @brief Stage hunks interactively.

# @description Stage parts of files with `git add -p`. It needs an interactive terminal: without one the command
#   refuses (exit 2) instead of hanging. For scripted answers, `SHELL_GIT_INPUT` names a file whose lines
#   (`y`, `n`, `q`, ...) are fed to git's prompts.
# @option -n | --dry-run Print the exact command, run nothing.
# @option -h | --help Show this help.
# @arg $@ string Optional paths to limit the patch session to.
# @exitcode 0 The session ended normally.
# @exitcode 1 git failed.
# @exitcode 2 Invalid usage, or no terminal.
# @exitcode 3 Not a git repository with a working tree.
# @example
#   shell::git::stage::patch
#   shell::git::stage::patch -- src/main.c
#
shell::git::stage::patch() {
	local dry=0
	local -a paths=() cmd=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf 'usage: shell::git::stage::patch [-n|--dry-run] [--] [path...]\n'
			printf 'Stage hunks with git add -p (needs a terminal).\n'
			return 0
			;;
		-n | --dry-run) dry=1 ;;
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
	cmd=(add -p)
	[ "${#paths[@]}" -gt 0 ] && cmd+=(-- "${paths[@]}")
	if [ "$dry" = "1" ]; then
		_shell::git::core::dry git "${cmd[@]}"
		return 0
	fi
	if [ -n "${SHELL_GIT_INPUT-}" ] && [ -r "$SHELL_GIT_INPUT" ]; then
		GIT_LITERAL_PATHSPECS=1 _shell::git::core::git_rw "${cmd[@]}" <"$SHELL_GIT_INPUT" || return 1
		return 0
	fi
	if [ ! -t 0 ] || [ ! -t 2 ]; then
		_shell::git::core::err "git add -p needs a terminal"
		return 2
	fi
	GIT_LITERAL_PATHSPECS=1 _shell::git::core::git_rw "${cmd[@]}" || return 1
	return 0
}
