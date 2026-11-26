#!/usr/bin/env bash
# @file lang/git/stash/save.sh
# @brief shell::git::stash::save

# @description Save the working tree to a named stash.
#   Runs `git stash push -m <name>`. A name is required: given with `-m` or as plain words, or typed when
#   you are on a terminal; otherwise exit 2. Untracked files are stashed only with `--include-untracked`.
#   Refuses (exit 1) when there is nothing to stash and (exit 7) while files are in conflict.
#   Changes your working tree, so `-n` shows the command without running it.
# @option -m | --message <name> The stash name.
# @option -u | --include-untracked Also stash untracked files.
# @option -k | --keep-index Leave the staged changes in the index.
# @option -n | --dry-run Print the exact command and execute nothing.
# @option -h | --help Show this help.
# @arg $@ string Name words (after `--` if they start with a dash).
# @stdout The new stash reference (`stash@{0}`).
# @exitcode 0 Saved.
# @exitcode 1 Nothing to stash, or git failed.
# @exitcode 2 Invalid usage, or no name and no terminal.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing or too old (stash push needs 2.13).
# @exitcode 5 Cancelled at the name prompt.
# @exitcode 7 Files are in conflict.
# @example
#   shell::git::stash::save -m "wip: parser"
#   shell::git::stash::save -u before the big refactor
#
shell::git::stash::save() {
	local msg="" untracked=0 keep=0 dry=0 staged unstaged untr conflicted
	local -a words=() args=()
	_shell::git::core::env
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::stash::save [-n] [-u] [-k] [-m <name> | <name words>]" \
				"Save the working tree to a named stash (untracked files only with -u)."
			return 0
			;;
		-m | --message)
			[ $# -ge 2 ] || {
				_shell::git::core::err "--message needs a value"
				return 2
			}
			msg="$2"
			shift
			;;
		-u | --include-untracked) untracked=1 ;;
		-k | --keep-index) keep=1 ;;
		-n | --dry-run) dry=1 ;;
		--)
			shift
			while [ $# -gt 0 ]; do
				words+=("$1")
				shift
			done
			break
			;;
		-*)
			_shell::git::core::err "unknown option: $1"
			return 2
			;;
		*) words+=("$1") ;;
		esac
		shift
	done
	if [ -z "$msg" ] && [ "${#words[@]}" -gt 0 ]; then
		msg="${words[*]}"
	fi
	_shell::git::core::require_repo --worktree || return $?
	_shell::git::core::git_ge 2 13 || {
		_shell::git::core::err "git 2.13 or newer is needed (stash push)"
		return 4
	}
	if [ -z "$msg" ]; then
		if ! _shell::git::core::interactive; then
			_shell::git::core::err "a stash name is required: -m <name>"
			return 2
		fi
		printf 'Stash name: ' >&2
		_shell::git::core::readline msg || return 5
		[ -n "$msg" ] || {
			_shell::git::core::err "a stash name is required"
			return 2
		}
	fi

	read -r staged unstaged untr conflicted <<LZ_EOF
$(_shell::git::core::tree_counts)
LZ_EOF
	if [ "${conflicted:-0}" -gt 0 ]; then
		_shell::git::core::err "$conflicted file(s) are in conflict: resolve them before stashing"
		return 7
	fi
	if [ $((staged + unstaged)) -eq 0 ] && { [ "$untracked" = "0" ] || [ "${untr:-0}" -eq 0 ]; }; then
		if [ "${untr:-0}" -gt 0 ]; then
			_shell::git::core::err "nothing to stash (untracked files need --include-untracked)"
		else
			_shell::git::core::err "nothing to stash"
		fi
		return 1
	fi

	args=(stash push)
	[ "$untracked" = "1" ] && args+=(--include-untracked)
	[ "$keep" = "1" ] && args+=(--keep-index)
	args+=(-m "$msg")
	if [ "$dry" = "1" ]; then
		_shell::git::core::dry git "${args[@]}"
		return 0
	fi
	_shell::git::core::git_rw "${args[@]}" >&2 || return 1
	_shell::git::core::info "stashed as stash@{0} ($(_shell::git::core::git_ro rev-parse --short 'stash@{0}' 2>/dev/null))"
	printf 'stash@{0}\n'
}
