#!/usr/bin/env bash
# @file lang/git/branch/recent.sh
# @brief shell::git::branch::recent

# @description Pick among the branches you checked out recently.
#   The order comes from the reflog of `HEAD` (the `checkout: moving from A to B` entries), most recent first,
#   without duplicates, and only branches that still exist. Two git calls whatever the history length: one
#   `reflog`, one `for-each-ref`, merged in one awk pass.
#   With `--list` the names are printed one per line and nothing is asked (no terminal needed).
#   Cancelling exits 5 and prints nothing; without a terminal and without `--list` it exits 2.
# @option -l | --list Print the names instead of asking.
# @option -c | --count <n> Show at most n branches (default 20).
# @option -h | --help Show this help.
# @stdout The selected branch, or with `--list` the recent branches.
# @exitcode 0 Success.
# @exitcode 1 Nothing to show.
# @exitcode 2 Invalid usage, or no terminal to pick on.
# @exitcode 3 Not a git repository.
# @exitcode 4 git is missing.
# @exitcode 5 Cancelled.
# @example
#   shell::git::branch::recent
#   shell::git::branch::recent --list --count 5
#
shell::git::branch::recent() {
	local list=0 count=20 recs rec
	_shell::git::core::env
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf '%s\n' "Usage: shell::git::branch::recent [-l|--list] [-c|--count <n>]" \
				"Pick among recently checked-out branches (from the reflog); --list prints them."
			return 0
			;;
		-l | --list) list=1 ;;
		-c | --count)
			case "${2-}" in
			"" | *[!0-9]* | 0)
				_shell::git::core::err "--count needs a positive number"
				return 2
				;;
			esac
			count="$2"
			shift
			;;
		*)
			_shell::git::core::err "unknown argument: $1"
			return 2
			;;
		esac
		shift
	done
	_shell::git::core::require_repo || return $?
	_shell::git::core::branch_colors
	recs="$(
		{
			_shell::git::core::git_ro for-each-ref \
				'--format=%(HEAD)%1f%(refname:short)%1f%(committerdate:relative)%1f%(objectname:short)%1f%(contents:subject)' refs/heads | sed 's/^/B/'
			_shell::git::core::git_ro reflog show --format=%gs -n 1000 HEAD 2>/dev/null | sed 's/^/R/'
		} | awk -F'\037' -v max="$count" -v cg="${_SHELL_GIT_C_GREEN-}" -v cc="${_SHELL_GIT_C_CYAN-}" -v cd="${_SHELL_GIT_C_DIM-}" -v cr="${_SHELL_GIT_C_RESET-}" '
			function pad(s, w,   k, out) { out = s; for (k = length(s); k < w; k++) out = out " "; return out }
			substr($0, 1, 1) == "B" {
				name = $2; ex[name] = 1; cur[name] = (substr($1, 2) == "*"); dt[name] = $3; hs[name] = $4
				s = $5; if (length(s) > 50) s = substr(s, 1, 49) "~"; sj[name] = s
				next
			}
			substr($0, 1, 1) == "R" && $1 ~ /^Rcheckout: moving from / {
				k = split($1, w, " "); dest = w[k]
				if (!(dest in seen)) { seen[dest] = 1; order[++n] = dest }
			}
			END {
				for (i = 1; i <= n && m < max; i++) {
					b = order[i]
					if (!(b in ex)) continue
					out[++m] = b
					if (length(b) > wn) wn = length(b)
					if (length(dt[b]) > wd) wd = length(dt[b])
				}
				for (i = 1; i <= m; i++) {
					b = out[i]
					nc = cc; if (cur[b]) nc = cg
					printf "%s\037%s %s  %s  %s  %s\n", b, (cur[b] ? cg "*" cr : " "), nc pad(b, wn) cr, cd pad(dt[b], wd) cr, cc hs[b] cr, sj[b]
				}
			}'
	)"
	if [ -z "$recs" ]; then
		_shell::git::core::err "no recently checked-out branches"
		return 1
	fi
	if [ "$list" = "1" ]; then
		printf '%s\n' "$recs" | while IFS= read -r rec; do printf '%s\n' "${rec%%$'\037'*}"; done
		return 0
	fi
	printf '%s\n' "$recs" | _shell::git::core::pick --prompt recent \
		--header "enter: select  esc: cancel  ctrl-/: toggle preview" \
		--preview 'git --no-pager log --oneline --graph --color=always --max-count=30 {1} --'
}
