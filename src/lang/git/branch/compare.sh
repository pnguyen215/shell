#!/usr/bin/env bash
# @file lang/git/branch/compare.sh
# @brief shell::git::branch::compare

# @description Compare two branches (or any two refs).
#   Prints the ahead/behind counts of `<a>` against `<b>`, the commits only in `<a>` (`b..a`), the commits only
#   in `<b>` (`a..b`) and the files that differ between the two tips (`diff --name-status -z`, so any file
#   name works). Read-only, a fixed number of git calls whatever the history size; the commit lists are bounded
#   by `--limit`. With no argument you pick both branches; with one, it is compared with the current branch.
# @option -l | --limit <n> Show at most n commits per side (default 50).
# @option -h | --help Show this help.
# @arg $1 string Branch a (picked when omitted).
# @arg $2 string Branch b (default: the current branch, else picked).
# @stdout The comparison report.
# @exitcode 0 Compared.
# @exitcode 1 A ref does not exist.
# @exitcode 2 Invalid usage, or no terminal to pick on.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing.
# @exitcode 5 Cancelled.
# @example
#   shell::git::branch::compare feature/x main
#   shell::git::branch::compare origin/main
#
shell::git::branch::compare() {
	local limit=50 a="" b="" ahead behind rec st p1 p2 shas_a shas_b
	_shell::git::core::env
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::branch::compare [-l|--limit <n>] [<a> [<b>]]" \
				"Ahead/behind counts, commits on each side and changed files between two branches."
			return 0
			;;
		-l | --limit)
			case "${2-}" in
			"" | *[!0-9]* | 0)
				_shell::git::core::err "--limit needs a positive number"
				return 2
				;;
			esac
			limit="$2"
			shift
			;;
		--)
			shift
			while [ $# -gt 0 ]; do
				if [ -z "$a" ]; then
					a="$1"
				elif [ -z "$b" ]; then
					b="$1"
				else
					_shell::git::core::err "too many arguments"
					return 2
				fi
				shift
			done
			break
			;;
		-*)
			_shell::git::core::err "unknown option: $1"
			return 2
			;;
		*)
			if [ -z "$a" ]; then
				a="$1"
			elif [ -z "$b" ]; then
				b="$1"
			else
				_shell::git::core::err "too many arguments"
				return 2
			fi
			;;
		esac
		shift
	done
	_shell::git::core::require_repo || return $?
	if [ -z "$a" ]; then
		a="$(_shell::git::core::branch_pick_one "compare: first branch")" || return $?
	fi
	if [ -z "$b" ]; then
		b="$(_shell::git::core::head_branch)" || b=""
		if [ -z "$b" ] || [ "$b" = "$a" ]; then
			b="$(_shell::git::core::branch_pick_one "compare with")" || return $?
		fi
	fi
	shas_a="$(_shell::git::core::rev "$a")" || {
		_shell::git::core::err "not a branch or ref: $a"
		return 1
	}
	shas_b="$(_shell::git::core::rev "$b")" || {
		_shell::git::core::err "not a branch or ref: $b"
		return 1
	}
	read -r ahead behind <<LZ_EOF
$(_shell::git::core::ahead_behind "$shas_a" "$shas_b")
LZ_EOF
	_shell::git::core::branch_colors
	printf '%s%s%s vs %s%s%s: %s ahead, %s behind\n' "$_SHELL_GIT_C_CYAN" "$a" "$_SHELL_GIT_C_RESET" "$_SHELL_GIT_C_CYAN" "$b" "$_SHELL_GIT_C_RESET" "${ahead:-0}" "${behind:-0}"
	printf '\nCommits only in %s (%s..%s):\n' "$a" "$b" "$a"
	_shell::git::core::git_ro log --no-color "--max-count=$limit" '--format=  %h %s' "$shas_b..$shas_a" --
	printf '\nCommits only in %s (%s..%s):\n' "$b" "$a" "$b"
	_shell::git::core::git_ro log --no-color "--max-count=$limit" '--format=  %h %s' "$shas_a..$shas_b" --
	printf '\nFiles that differ (%s vs %s):\n' "$a" "$b"
	# --name-status -z: "S\0path\0" and, for renames and copies, "Sxx\0old\0new\0"
	while IFS= read -r -d '' st; do
		case "$st" in
		R* | C*)
			IFS= read -r -d '' p1
			IFS= read -r -d '' p2
			printf '  %s\t%s -> %s\n' "$st" "$p1" "$p2"
			;;
		*)
			IFS= read -r -d '' p1
			printf '  %s\t%s\n' "$st" "$p1"
			;;
		esac
	done < <(_shell::git::core::git_ro diff --name-status -z "$shas_a" "$shas_b" --)
	return 0
}
