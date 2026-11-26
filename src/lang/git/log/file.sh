#!/usr/bin/env bash
# @file lang/git/log/file.sh
# @brief History of one file, following renames.

# @description Print the history of one file, following it across renames (`git log --follow`).
#   The path goes after `--`, so names with spaces, unicode or a leading dash work. The file may
#   have been deleted: only the history is read. Without an argument, pick a tracked file (fzf or a
#   numbered list; the list is read NUL-separated, so any name survives).
# @option -m | --max <n> Maximum commits (default 200).
# @option -p | --patch Show the diff of each commit too.
# @option -h | --help Show this help.
# @arg $1 string The path (relative to the current directory).
# @stdout One line per commit: short hash, date, author, subject (with `--patch`, the diffs follow).
# @exitcode 0 History printed.
# @exitcode 1 The file has no history, or git failed.
# @exitcode 2 Invalid argument, or no terminal to pick a file on.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing.
# @exitcode 5 The file picker was cancelled.
# @example
#   shell::git::log::file src/main.sh
#   shell::git::log::file -- -odd-name.txt
#
shell::git::log::file() {
	local max=200 patch=0 target="" have=0 color rc out rec
	local -a cmd=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::log::file [-m <n>] [-p] [--] <path>"
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
		-p | --patch) patch=1 ;;
		--)
			shift
			if [ $# -gt 1 ]; then
				_shell::git::core::err "--follow takes exactly one path"
				return 2
			fi
			if [ $# -eq 1 ]; then
				target="$1"
				have=1
			fi
			break
			;;
		-*)
			_shell::git::core::err "unknown option: $1 (a path that starts with a dash goes after --)"
			return 2
			;;
		*)
			if [ "$have" = "1" ]; then
				_shell::git::core::err "--follow takes exactly one path"
				return 2
			fi
			target="$1"
			have=1
			;;
		esac
		shift
	done
	_shell::git::core::env
	_shell::git::core::require_repo --worktree || return $?
	if [ "$have" = "0" ]; then
		if [ -z "${SHELL_GIT_INPUT-}" ] && { [ ! -t 2 ] || [ ! -r /dev/tty ]; } && [ -z "${SHELL_GIT_FORCE_FZF-}" ]; then
			_shell::git::core::err "no terminal to pick from: pass the file as an argument"
			return 2
		fi
		# The selection is NUL-terminated (a shell variable cannot hold NUL, `read -d ''` stops at it).
		IFS= read -r -d '' target < <(
			while IFS= read -r -d '' rec; do
				printf '%s\037%s\0' "$rec" "$rec"
			done < <(_shell::git::core::git_ro ls-files -z) | _shell::git::core::pick -0 --prompt file
		)
		[ -n "$target" ] || return 5
		have=1
	fi
	[ -n "$target" ] || {
		_shell::git::core::err "empty path"
		return 2
	}
	_shell::git::core::colors auto
	color="$(_shell::git::core::log_color out)"
	cmd=(log --follow --color="$color" --date=short "--max-count=$max" "--format=%C(yellow)%h%C(reset) %C(dim)%ad%C(reset) %C(cyan)%an%C(reset) %s")
	[ "$patch" = "1" ] && cmd+=(--patch)
	cmd+=(-- "$target")
	out="$(_shell::git::core::git_ro "${cmd[@]}" 2>&1)"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		_shell::git::core::err "git log failed: $out"
		return 1
	fi
	if [ -z "$out" ]; then
		_shell::git::core::err "no history for: $target"
		return 1
	fi
	printf '%s\n' "$out"
}
