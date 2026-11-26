#!/usr/bin/env bash
# @file lang/git/log/search.sh
# @brief Search history by message, by added/removed string, or by regex.

# @description Search the history and print one line per matching commit (`<hash> <date> <subject>`).
#   The search text is always attached to its option (`--grep=<text>`, `-S<text>`, `-G<text>`), so text
#   such as `--all` or `-rf` is data, never an option. One git call, whatever the number of matches.
# @option --grep <text> Search commit messages (default mode; a bare text argument means the same).
# @option -S <text> Search commits that add or remove this exact string.
# @option -G <regex> Search commits whose diff matches this regular expression.
# @option -i | --ignore-case Case-insensitive match (for --grep and -G).
# @option -a | --all Search every ref, not only HEAD.
# @option -m | --max <n> Maximum matches (default 200).
# @option -h | --help Show this help.
# @arg $@ string After `--`: path filters.
# @stdout One line per match: short hash, date, subject (colored only on a terminal, never under NO_COLOR).
# @exitcode 0 At least one match.
# @exitcode 1 No match, or git failed.
# @exitcode 2 Missing text or invalid argument.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing.
# @example
#   shell::git::log::search --grep "fix login"
#   shell::git::log::search -S "API_KEY" -- config/
#
shell::git::log::search() {
	local mode="" text="" icase=0 all=0 max=200 color rc out
	local -a paths=() cmd=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::log::search (--grep <text> | -S <text> | -G <regex> | <text>) [-i] [-a] [-m <n>] [-- <path>...]"
			return 0
			;;
		--grep | -S | -G)
			[ $# -ge 2 ] || {
				_shell::git::core::err "$1 needs a value"
				return 2
			}
			mode="$1"
			text="$2"
			shift
			;;
		-i | --ignore-case) icase=1 ;;
		-a | --all) all=1 ;;
		-m | --max)
			_shell::git::core::log_number "${2-}" || {
				_shell::git::core::err "--max needs a positive number"
				return 2
			}
			max="$2"
			shift
			;;
		--)
			shift
			paths=("$@")
			break
			;;
		-*)
			_shell::git::core::err "unknown option: $1 (to search for it, use --grep '$1')"
			return 2
			;;
		*)
			if [ -n "$mode" ]; then
				_shell::git::core::err "unexpected argument: $1"
				return 2
			fi
			mode="--grep"
			text="$1"
			;;
		esac
		shift
	done
	[ -n "$mode" ] && [ -n "$text" ] || {
		_shell::git::core::err "nothing to search for: pass --grep <text>, -S <text> or -G <regex>"
		return 2
	}
	_shell::git::core::env
	_shell::git::core::require_repo || return $?
	_shell::git::core::colors auto
	color="$(_shell::git::core::log_color out)"
	cmd=(log --color="$color" --date=short "--max-count=$max" "--format=%C(yellow)%h%C(reset) %C(dim)%ad%C(reset) %s%C(auto)%d")
	case "$mode" in
	--grep) cmd+=("--grep=$text") ;;
	-S) cmd+=("-S$text") ;;
	-G) cmd+=("-G$text") ;;
	esac
	[ "$icase" = "1" ] && cmd+=(--regexp-ignore-case)
	[ "$all" = "1" ] && cmd+=(--all)
	[ "${#paths[@]}" -gt 0 ] && cmd+=(-- "${paths[@]}")
	out="$(_shell::git::core::git_ro "${cmd[@]}" 2>&1)"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		_shell::git::core::err "git log failed: $out"
		return 1
	fi
	if [ -z "$out" ]; then
		_shell::git::core::info "no commit matches"
		return 1
	fi
	printf '%s\n' "$out"
}
