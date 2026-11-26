#!/usr/bin/env bash
# @file lang/git/log/pick.sh
# @brief Browse history in fzf (streamed, previewed) and pick commits.

# @description Browse the history interactively and print the picked commit hash(es).
#   One `git log --format` call streams into fzf, so the first screen appears at once even on a huge
#   history (`--max-count`, default 2000, and `alt-m` reloads up to 100000 when there is no path filter).
#   The first column (the full hash) is hidden, so colors never corrupt what is returned. Previews are
#   lazy (the focused commit only) and bounded (`show --stat`, 60 lines).
#
#   Key bindings (fzf >= 0.38; older fzf has enter and the preview only):
#   | key | action |
#   |---|---|
#   | enter | pick the commit: hash on stdout, `show --stat` details on stderr |
#   | alt-d | full diff of the focused commit |
#   | alt-f | changed files of the focused commit |
#   | alt-i | full information of the focused commit |
#   | alt-p | cherry-pick the focused commit (confirmation; conflicts: exit 6, with continue/abort instructions) |
#   | alt-r | revert the focused commit (same protections) |
#   | alt-m | load more history |
#   | ? | help overlay |
#   | esc / ctrl-c | abort, nothing changes (exit 5) |
#
#   ctrl-c, ctrl-s and ctrl-d are never used for features. Without fzf, a numbered list of the 30 most recent
#   commits (`SHELL_GIT_LOG_FALLBACK`) is shown. Without a terminal the function exits 2.
# @option -m | --max <n> Maximum commits streamed (default 2000).
# @option -a | --all Include every ref, not only HEAD.
# @option -r | --rev <rev> Start from this revision instead of HEAD.
# @option --multi Allow several commits (tab to mark).
# @option -n | --dry-run With alt-p / alt-r: print the command, change nothing.
# @option -y | --yes With alt-p / alt-r: answer the confirmation.
# @option -h | --help Show this help.
# @arg $@ string After `--`: path filters.
# @stdout The picked hash(es), one per line.
# @exitcode 0 Picked, or the cherry-pick/revert succeeded.
# @exitcode 2 Invalid argument, or no terminal to pick on.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing.
# @exitcode 5 Cancelled (esc, ctrl-c, nothing selected, declined confirmation).
# @exitcode 6 alt-p / alt-r stopped on conflicts: resolve by hand.
# @exitcode 7 alt-p / alt-r blocked by a dirty tree or an operation in progress.
# @example
#   hash="$(shell::git::log::pick)"
#   shell::git::log::pick --all -- src/
#
shell::git::log::pick() {
	local max=2000 all=0 multi=0 yes="" dry=0 rev="" sha
	local -a paths=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::log::pick [-m <n>] [-a] [-r <rev>] [--multi] [-n] [-y] [-- <path>...]" \
				"Keys: enter details, alt-d diff, alt-f files, alt-i info, alt-p cherry-pick, alt-r revert, alt-m more, ? help, esc abort"
			return 0
			;;
		-m | --max)
			_shell::git::core::log_number "${2-}" || {
				_shell::git::core::err "--max needs a positive number"
				return 2
			}
			max="$2"
			shift
			;;
		-a | --all) all=1 ;;
		-r | --rev)
			[ -n "${2-}" ] || {
				_shell::git::core::err "--rev needs a revision"
				return 2
			}
			rev="$2"
			shift
			;;
		--multi) multi=1 ;;
		-n | --dry-run) dry=1 ;;
		-y | --yes) yes="yes" ;;
		--)
			shift
			paths=("$@")
			break
			;;
		*)
			_shell::git::core::err "unknown argument: $1"
			return 2
			;;
		esac
		shift
	done
	_shell::git::core::env
	_shell::git::core::require_repo || return $?
	if [ -n "$rev" ]; then
		sha="$(_shell::git::core::rev "$rev")" || {
			_shell::git::core::err "not a commit: $rev"
			return 2
		}
		rev="$sha"
	fi
	if ! _shell::git::core::git_ro rev-parse --verify --quiet 'HEAD^{commit}' >/dev/null 2>&1 && [ -z "$rev" ] && [ "$all" != "1" ]; then
		_shell::git::core::err "no commits yet"
		return 1
	fi
	_shell::git::core::log_picker "$max" "$multi" "$all" "$yes" "$dry" "$rev" -- ${paths[@]+"${paths[@]}"}
}
