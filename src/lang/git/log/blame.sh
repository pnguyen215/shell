#!/usr/bin/env bash
# @file lang/git/log/blame.sh
# @brief Blame a file or a line range, optionally picking a line interactively.

# @description Show who last changed each line of a tracked file (`git blame`).
#   Refuses untracked or missing files and binary files with a clear message. Huge files are bounded:
#   above `SHELL_GIT_BLAME_MAX_LINES` (default 20000) a `-L` range is required. `-L` accepts
#   `start,end` and `start,+count`. With `--pick` the blame lines go into a picker and the chosen
#   line's commit is shown (`show --stat`). Without a file argument a tracked file is picked first.
# @option -L <range> Only these lines: `start,end` or `start,+count`.
# @option -r | --rev <rev> Blame the file as of this revision.
# @option --pick Choose a line interactively and show its commit.
# @option -h | --help Show this help.
# @arg $1 string The file (relative to the current directory).
# @stdout The blame lines, or with `--pick` the details of the chosen line's commit.
# @exitcode 0 Printed.
# @exitcode 1 Untracked/missing/binary file, or git failed.
# @exitcode 2 Invalid argument, huge file without -L, or no terminal for a picker.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing.
# @exitcode 5 A picker was cancelled.
# @example
#   shell::git::log::blame src/main.sh -L 10,20
#   shell::git::log::blame --pick src/main.sh
#
shell::git::log::blame() {
	local range="" rev="" pick=0 target="" have=0 sha lines limit numstat out rc rec color hash
	local -a cmd=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::log::blame [-L <start,end|start,+count>] [-r <rev>] [--pick] [--] <file>"
			return 0
			;;
		-L)
			range="${2-}"
			shift
			;;
		-L?*) range="${1#-L}" ;;
		-r | --rev)
			rev="${2-}"
			[ -n "$rev" ] || {
				_shell::git::core::err "--rev needs a revision"
				return 2
			}
			shift
			;;
		--pick) pick=1 ;;
		--)
			shift
			if [ $# -gt 1 ]; then
				_shell::git::core::err "blame takes one file"
				return 2
			fi
			if [ $# -eq 1 ]; then
				target="$1"
				have=1
			fi
			break
			;;
		-*)
			_shell::git::core::err "unknown option: $1 (a file that starts with a dash goes after --)"
			return 2
			;;
		*)
			if [ "$have" = "1" ]; then
				_shell::git::core::err "blame takes one file"
				return 2
			fi
			target="$1"
			have=1
			;;
		esac
		shift
	done
	if [ -n "$range" ]; then
		case "$range" in
		[0-9]*,[0-9]* | [0-9]*,+[0-9]*) ;;
		*)
			_shell::git::core::err "invalid -L range: $range (use start,end or start,+count)"
			return 2
			;;
		esac
		case "${range//,/}" in
		*[!0-9+]*)
			_shell::git::core::err "invalid -L range: $range (use start,end or start,+count)"
			return 2
			;;
		esac
	fi
	_shell::git::core::env
	_shell::git::core::require_repo --worktree || return $?
	if [ -n "$rev" ]; then
		sha="$(_shell::git::core::rev "$rev")" || {
			_shell::git::core::err "not a commit: $rev"
			return 2
		}
		rev="$sha"
	fi
	if [ "$have" = "0" ]; then
		if [ -z "${SHELL_GIT_INPUT-}" ] && { [ ! -t 2 ] || [ ! -r /dev/tty ]; } && [ -z "${SHELL_GIT_FORCE_FZF-}" ]; then
			_shell::git::core::err "no terminal to pick from: pass the file as an argument"
			return 2
		fi
		IFS= read -r -d '' target < <(
			while IFS= read -r -d '' rec; do
				printf '%s\037%s\0' "$rec" "$rec"
			done < <(_shell::git::core::git_ro ls-files -z) | _shell::git::core::pick -0 --prompt file
		)
		[ -n "$target" ] || return 5
	fi
	[ -n "$target" ] || {
		_shell::git::core::err "empty file name"
		return 2
	}
	if ! _shell::git::core::git_ro ls-files --error-unmatch -- "$target" >/dev/null 2>&1; then
		_shell::git::core::err "not a tracked file (untracked, ignored or missing): $target"
		return 1
	fi
	if [ -z "$rev" ]; then
		if [ ! -f "$target" ]; then
			_shell::git::core::err "the file does not exist in the working tree: $target (pass --rev to blame an old revision)"
			return 1
		fi
		numstat="$(_shell::git::core::git_ro diff --no-index --numstat -- /dev/null "$target" 2>/dev/null)"
		case "$numstat" in
		"-"$'\t'"-"$'\t'*)
			_shell::git::core::err "binary file, nothing to blame: $target"
			return 1
			;;
		esac
		lines="$(wc -l <"$target" | tr -d ' ')"
	else
		numstat="$(_shell::git::core::git_ro diff --numstat 4b825dc642cb6eb9a060e54bf8d69288fbee4904 "$rev" -- "$target" 2>/dev/null)"
		case "$numstat" in
		"-"$'\t'"-"$'\t'*)
			_shell::git::core::err "binary file, nothing to blame: $target"
			return 1
			;;
		esac
		lines=0
	fi
	limit="${SHELL_GIT_BLAME_MAX_LINES:-20000}"
	_shell::git::core::log_number "$limit" || limit=20000
	if [ -z "$range" ] && [ "${lines:-0}" -gt "$limit" ]; then
		_shell::git::core::err "$target has $lines lines (limit $limit): pass -L <start,end>"
		return 2
	fi
	_shell::git::core::colors auto
	color="$(_shell::git::core::log_color out)"
	cmd=(blame --date=short)
	[ -n "$range" ] && cmd+=("-L$range")
	[ -n "$rev" ] && cmd+=("$rev")
	cmd+=(-- "$target")
	out="$(_shell::git::core::git_ro "${cmd[@]}" 2>&1)"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		_shell::git::core::err "git blame failed: $out"
		return 1
	fi
	if [ "$pick" = "1" ]; then
		hash="$(
			while IFS= read -r rec; do
				printf '%s\037%s\n' "${rec%% *}" "$rec"
			done <<LZ_EOF | _shell::git::core::pick --prompt line
$out
LZ_EOF
		)"
		rc=$?
		[ "$rc" -eq 0 ] || return "$rc"
		[ -n "$hash" ] || return 5
		hash="${hash#^}"
		_shell::git::core::git_ro show --stat --color="$color" --format=fuller "$hash"
		return $?
	fi
	printf '%s\n' "$out"
}
