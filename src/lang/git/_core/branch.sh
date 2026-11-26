#!/usr/bin/env bash
# @file lang/git/_core/branch.sh
# @brief Private helpers shared by the shell::git::branch::* functions.
# @description
#   Owned by the branch group. Lists are built from ONE `for-each-ref` call (plus one `reflog` call for
#   `recent`) and formatted in ONE awk pass; nothing here runs git per branch.

# @internal
# @description Turn colors on only for an interactive terminal (fzf and the numbered list are drawn on it) and
#   only when NO_COLOR is empty; otherwise every `_SHELL_GIT_C_*` variable is empty.
# @exitcode 0 Always.
# @example
#   _shell::git::core::branch_colors
#
_shell::git::core::branch_colors() {
	if [ -z "${NO_COLOR-}" ] && [ -t 2 ] && [ "${TERM-}" != "dumb" ]; then
		_shell::git::core::colors 1
	else
		_shell::git::core::colors 0
	fi
}

# @internal
# @description Print picker records (`raw<US>display`) for the branches of the repository, sorted by committer date
#   (newest first). Columns: current marker, name, relative date, short hash, subject, ahead/behind, `gone` flag.
#   Cyan names, green current, blue remotes, dim dates. ONE `for-each-ref` call, ONE awk pass.
# @arg $1 string `all` (default), `local` or `remote`.
# @stdout One record per branch; the raw field is the short ref name (`main`, `origin/main`).
# @exitcode 0 Listed (maybe nothing).
# @exitcode 1 git failed.
# @example
#   _shell::git::core::branch_records local | _shell::git::core::pick
#
_shell::git::core::branch_records() {
	local scope="${1:-all}"
	local -a patterns=()
	case "$scope" in
	local) patterns=(refs/heads) ;;
	remote) patterns=(refs/remotes) ;;
	*) patterns=(refs/heads refs/remotes) ;;
	esac
	_shell::git::core::git_ro for-each-ref --sort=-committerdate \
		'--format=%(HEAD)%1f%(refname)%1f%(refname:short)%1f%(committerdate:relative)%1f%(objectname:short)%1f%(upstream:track)%1f%(contents:subject)' \
		"${patterns[@]}" |
		awk -F'\037' -v cg="${_SHELL_GIT_C_GREEN-}" -v cc="${_SHELL_GIT_C_CYAN-}" -v cb="${_SHELL_GIT_C_BLUE-}" \
			-v cd="${_SHELL_GIT_C_DIM-}" -v cy="${_SHELL_GIT_C_YELLOW-}" -v cr="${_SHELL_GIT_C_RESET-}" '
			function pad(s, w,   k, out) { out = s; for (k = length(s); k < w; k++) out = out " "; return out }
			$2 ~ /^refs\/remotes\/.*\/HEAD$/ { next }
			{
				n++
				raw[n] = $3; cur[n] = ($1 == "*"); rem[n] = ($2 ~ /^refs\/remotes\//)
				dt[n] = $4; hs[n] = $5
				s = $7; if (length(s) > 50) s = substr(s, 1, 49) "~"
				sj[n] = s
				t = $6; gsub(/[\[\]]/, "", t); ab[n] = ""; gone[n] = ""
				if (t == "gone") gone[n] = "gone"
				else {
					a = 0; b = 0
					if (match(t, /ahead [0-9]+/)) a = substr(t, RSTART + 6, RLENGTH - 6)
					if (match(t, /behind [0-9]+/)) b = substr(t, RSTART + 7, RLENGTH - 7)
					if (a + 0 > 0 || b + 0 > 0) ab[n] = "+" a "/-" b
				}
				if (length($3) > wn) wn = length($3)
				if (length($4) > wd) wd = length($4)
				if (length(s) > ws) ws = length(s)
				if (length(ab[n]) > wa) wa = length(ab[n])
			}
			END {
				for (i = 1; i <= n; i++) {
					nc = cc; if (rem[i]) nc = cb; if (cur[i]) nc = cg
					line = (cur[i] ? cg "*" cr : " ") " " nc pad(raw[i], wn) cr "  " cd pad(dt[i], wd) cr "  " cc hs[i] cr "  " pad(sj[i], ws) "  " pad(ab[i], wa)
					if (gone[i] != "") line = line "  " cy "gone" cr
					printf "%s\037%s\n", raw[i], line
				}
			}'
}

# @internal
# @description Pick ONE branch interactively (fzf or numbered prompt) and print its short name.
# @arg $1 string Prompt text.
# @arg $2 string `all` (default), `local` or `remote`.
# @stdout The selected ref.
# @exitcode 0 Selected.
# @exitcode 5 Cancelled.
# @exitcode 2 No terminal to ask on.
# @exitcode 1 No branches.
# @example
#   ref="$(_shell::git::core::branch_pick_one "compare" local)" || return $?
#
_shell::git::core::branch_pick_one() {
	local recs
	_shell::git::core::branch_colors
	recs="$(_shell::git::core::branch_records "${2:-all}")" || return 1
	if [ -z "$recs" ]; then
		_shell::git::core::err "no branches"
		return 1
	fi
	printf '%s\n' "$recs" | _shell::git::core::pick --prompt "${1:-branch}" \
		--header "enter: select  esc: cancel  ctrl-/: preview" \
		--preview 'git --no-pager log --oneline --graph --color=always --max-count=30 {1} --'
}
