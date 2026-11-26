#!/usr/bin/env bash
# @file lang/git/branch/pick.sh
# @brief shell::git::branch::pick

# @description Fuzzy-pick a branch and print its name.
#   Columns (aligned, newest commit first): current marker, name, relative date, short hash, subject,
#   ahead/behind of the upstream, `gone` when the upstream was deleted. Names are cyan, the current branch green,
#   remote-tracking branches blue, dates dim. The list comes from ONE `git for-each-ref` call whatever the
#   number of branches. The preview shows a short `log --oneline --graph` of the focused branch only.
#   With a branch name as argument nothing is asked: the name is checked and printed.
#   Cancelling (esc, ctrl-c) exits 5 and prints nothing. Without a terminal and without an argument it exits 2.
# @option -l | --local Only local branches.
# @option -r | --remote Only remote-tracking branches.
# @option -q | --query <text> Start the picker with this query.
# @option -h | --help Show this help.
# @arg $1 string Optional branch (or any ref that resolves to a commit): printed as is when valid.
# @stdout The selected branch (`feature/x`, `origin/main`).
# @exitcode 0 A branch was selected or validated.
# @exitcode 1 No branches, or the argument is not a ref.
# @exitcode 2 Invalid usage, or no terminal to pick on.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing.
# @exitcode 5 Cancelled.
# @example
#   branch="$(shell::git::branch::pick)"
#   shell::git::branch::pick --local --query feat
#
shell::git::branch::pick() {
	local scope=all query="" ref="" recs
	_shell::git::core::env
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::branch::pick [-l|--local] [-r|--remote] [-q|--query <text>] [<branch>]" \
				"Fuzzy-pick a branch and print its name (exit 5 when cancelled, 2 without a terminal)."
			return 0
			;;
		-l | --local) scope=local ;;
		-r | --remote) scope=remote ;;
		-q | --query)
			[ $# -ge 2 ] || {
				_shell::git::core::err "--query needs a value"
				return 2
			}
			query="$2"
			shift
			;;
		--)
			shift
			[ $# -gt 0 ] && ref="$1"
			break
			;;
		-*)
			_shell::git::core::err "unknown option: $1"
			return 2
			;;
		*) ref="$1" ;;
		esac
		shift
	done
	_shell::git::core::require_repo || return $?
	if [ -n "$ref" ]; then
		_shell::git::core::rev "$ref" >/dev/null || {
			_shell::git::core::err "not a branch or ref: $ref"
			return 1
		}
		printf '%s\n' "$ref"
		return 0
	fi
	_shell::git::core::branch_colors
	recs="$(_shell::git::core::branch_records "$scope")" || return 1
	if [ -z "$recs" ]; then
		_shell::git::core::err "no branches"
		return 1
	fi
	printf '%s\n' "$recs" | _shell::git::core::pick --prompt branch --query "$query" \
		--header "enter: select  esc: cancel  ctrl-/: toggle preview" \
		--preview 'git --no-pager log --oneline --graph --color=always --max-count=30 {1} --'
}
