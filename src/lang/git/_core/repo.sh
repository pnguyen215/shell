#!/usr/bin/env bash
# @file lang/git/_core/repo.sh
# @brief Private helpers shared by the shell::git::repo::* functions.
# @description
#   Owned by the repo group. Every collector runs a bounded, constant number of git calls whatever the
#   size of the repository: `status --porcelain=v2 --branch -z` (state, upstream, ahead/behind, counts), one
#   `for-each-ref` over branches (counts, stale, gone), one `for-each-ref --merged`, one `stash list`, one
#   `rev-parse --git-path` for operations in progress, plus the base-branch lookup. No `fsck`, no per-branch call.
#   Results land in `_SHELL_GIT_RP_*` globals. Report rows are tab-separated `key<TAB>value`.

# @internal
# @description Parse the common options of the repo reports: `--plain`, `--top N`, `--max N`, `-h`.
#   Sets `_SHELL_GIT_RP_PLAIN` (1 when `--plain` was given or stdout is not a terminal), `_SHELL_GIT_RP_TOP`,
#   `_SHELL_GIT_RP_MAX` and `_SHELL_GIT_RP_HELP`.
# @arg $@ string The caller's arguments.
# @exitcode 0 Parsed.
# @exitcode 2 Unknown option or bad number.
# @example
#   _shell::git::core::repo_opts "$@" || return $?
#
_shell::git::core::repo_opts() {
	_SHELL_GIT_RP_PLAIN=0
	_SHELL_GIT_RP_TOP=5
	_SHELL_GIT_RP_MAX=""
	_SHELL_GIT_RP_HELP=0
	[ -t 1 ] || _SHELL_GIT_RP_PLAIN=1
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help) _SHELL_GIT_RP_HELP=1 ;;
		--plain | -q) _SHELL_GIT_RP_PLAIN=1 ;;
		--top | --max)
			case "${2-}" in
			"" | *[!0-9]*)
				_shell::git::core::err "$1 needs a number"
				return 2
				;;
			esac
			if [ "$1" = "--top" ]; then _SHELL_GIT_RP_TOP="$2"; else _SHELL_GIT_RP_MAX="$2"; fi
			shift
			;;
		*)
			_shell::git::core::err "unknown option: $1"
			return 2
			;;
		esac
		shift
	done
	return 0
}

# @internal
# @description Turn a byte count into a short human string (`1.5 MiB`).
# @arg $1 integer Bytes.
# @stdout The string.
# @exitcode 0 Always.
# @example
#   _shell::git::core::repo_human 1572864   # 1.5 MiB
#
_shell::git::core::repo_human() {
	local val=$((${1:-0} * 10)) unit i=0
	for unit in B KiB MiB GiB TiB; do
		if [ "$val" -lt 10240 ] || [ "$unit" = "TiB" ]; then
			if [ "$unit" = "B" ]; then printf '%d B\n' $((val / 10)); else printf '%d.%d %s\n' $((val / 10)) $((val % 10)) "$unit"; fi
			return 0
		fi
		val=$((val / 1024))
		i=$((i + 1))
	done
}

# @internal
# @description Collect the repository state into `_SHELL_GIT_RP_*` globals with a constant number of git calls:
#   BARE, HEAD (branch, or `(detached)`), OID, UP (upstream or empty), AHEAD, BEHIND, GONE (1 when the upstream
#   branch no longer exists), STAGED, UNSTAGED, UNTRACKED, CONFLICTED (`-` for the tree fields in a bare
#   repository), LOCAL, REMOTE, STASH, BASE (empty when none), MERGED, UNMERGED (`-` without a base), STALE,
#   OP (operation in progress or empty), SEV (0 healthy, 1 warnings, 2 problems) and NOTES (reasons).
# @exitcode 0 Collected.
# @example
#   _shell::git::core::repo_collect
#
_shell::git::core::repo_collect() {
	local rec skip=0 xy line ref ts now days cur="" base name stashes
	_shell::git::core::env
	_SHELL_GIT_RP_BARE="$(_shell::git::core::git_ro rev-parse --is-bare-repository 2>/dev/null)"
	_SHELL_GIT_RP_HEAD="" _SHELL_GIT_RP_OID="" _SHELL_GIT_RP_UP="" _SHELL_GIT_RP_AHEAD=0 _SHELL_GIT_RP_BEHIND=0 _SHELL_GIT_RP_GONE=0
	_SHELL_GIT_RP_STAGED=0 _SHELL_GIT_RP_UNSTAGED=0 _SHELL_GIT_RP_UNTRACKED=0 _SHELL_GIT_RP_CONFLICTED=0
	if [ "$_SHELL_GIT_RP_BARE" = "true" ]; then
		_SHELL_GIT_RP_HEAD="$(_shell::git::core::head_branch)"
		_SHELL_GIT_RP_STAGED="-" _SHELL_GIT_RP_UNSTAGED="-" _SHELL_GIT_RP_UNTRACKED="-" _SHELL_GIT_RP_CONFLICTED="-"
	else
		local have_ab=0
		while IFS= read -r -d '' rec; do
			if [ "$skip" -gt 0 ]; then
				skip=$((skip - 1))
				continue
			fi
			case "$rec" in
			"# branch.head "*) _SHELL_GIT_RP_HEAD="${rec#\# branch.head }" ;;
			"# branch.oid "*) _SHELL_GIT_RP_OID="${rec#\# branch.oid }" ;;
			"# branch.upstream "*) _SHELL_GIT_RP_UP="${rec#\# branch.upstream }" ;;
			"# branch.ab "*)
				have_ab=1
				line="${rec#\# branch.ab +}"
				_SHELL_GIT_RP_AHEAD="${line%% *}"
				_SHELL_GIT_RP_BEHIND="${line#* -}"
				;;
			"1 "* | "2 "*)
				xy="${rec#? }"
				xy="${xy%% *}"
				[ "${xy%?}" != "." ] && _SHELL_GIT_RP_STAGED=$((_SHELL_GIT_RP_STAGED + 1))
				[ "${xy#?}" != "." ] && _SHELL_GIT_RP_UNSTAGED=$((_SHELL_GIT_RP_UNSTAGED + 1))
				case "$rec" in "2 "*) skip=1 ;; esac
				;;
			"u "*) _SHELL_GIT_RP_CONFLICTED=$((_SHELL_GIT_RP_CONFLICTED + 1)) ;;
			"? "*) _SHELL_GIT_RP_UNTRACKED=$((_SHELL_GIT_RP_UNTRACKED + 1)) ;;
			esac
		done < <(_shell::git::core::git_ro status --porcelain=v2 --branch -z 2>/dev/null)
		[ -n "$_SHELL_GIT_RP_UP" ] && [ "$have_ab" = "0" ] && _SHELL_GIT_RP_GONE=1
	fi
	[ -n "$_SHELL_GIT_RP_HEAD" ] || _SHELL_GIT_RP_HEAD="(detached)"
	[ "$_SHELL_GIT_RP_HEAD" = "(detached)" ] || cur="$_SHELL_GIT_RP_HEAD"

	# Branches: counts and staleness from ONE for-each-ref.
	days="${SHELL_GIT_STALE_DAYS:-90}"
	now="$(date +%s)"
	_SHELL_GIT_RP_LOCAL=0 _SHELL_GIT_RP_REMOTE=0 _SHELL_GIT_RP_STALE=0
	while IFS=$'\t' read -r ref ts; do
		case "$ref" in
		refs/heads/*)
			_SHELL_GIT_RP_LOCAL=$((_SHELL_GIT_RP_LOCAL + 1))
			if [ "${ref#refs/heads/}" != "$cur" ] && [ -n "$ts" ] && [ $((now - ts)) -gt $((days * 86400)) ]; then
				_SHELL_GIT_RP_STALE=$((_SHELL_GIT_RP_STALE + 1))
			fi
			;;
		refs/remotes/*/HEAD) ;;
		refs/remotes/*) _SHELL_GIT_RP_REMOTE=$((_SHELL_GIT_RP_REMOTE + 1)) ;;
		esac
	done < <(_shell::git::core::git_ro for-each-ref '--format=%(refname)%09%(committerdate:unix)' refs/heads refs/remotes 2>/dev/null)

	# Merged / unmerged against the base branch (other than the base itself and the current branch).
	_SHELL_GIT_RP_BASE=""
	_SHELL_GIT_RP_MERGED="-"
	_SHELL_GIT_RP_UNMERGED="-"
	if base="$(_shell::git::core::base 2>/dev/null)" && [ -n "$base" ]; then
		_SHELL_GIT_RP_BASE="$base"
		local merged=0 candidates=$_SHELL_GIT_RP_LOCAL
		if _shell::git::core::git_ro rev-parse --verify --quiet "refs/heads/$base" >/dev/null 2>&1; then
			candidates=$((candidates - 1))
		fi
		[ -n "$cur" ] && [ "$cur" != "$base" ] && candidates=$((candidates - 1))
		while IFS= read -r name; do
			[ "$name" = "$base" ] && continue
			[ "$name" = "$cur" ] && continue
			merged=$((merged + 1))
		done < <(_shell::git::core::git_ro for-each-ref "--merged=$base" '--format=%(refname:short)' refs/heads 2>/dev/null)
		[ "$candidates" -lt 0 ] && candidates=0
		_SHELL_GIT_RP_MERGED="$merged"
		_SHELL_GIT_RP_UNMERGED=$((candidates - merged))
		[ "$_SHELL_GIT_RP_UNMERGED" -lt 0 ] && _SHELL_GIT_RP_UNMERGED=0
	fi

	# Stashes and the operation in progress.
	_SHELL_GIT_RP_STASH=0
	while IFS= read -r stashes; do
		[ -n "$stashes" ] && _SHELL_GIT_RP_STASH=$((_SHELL_GIT_RP_STASH + 1))
	done < <(_shell::git::core::git_ro stash list 2>/dev/null)
	_SHELL_GIT_RP_OP="$(_shell::git::core::operation)"

	# Severity: problems (2) beat warnings (1).
	_SHELL_GIT_RP_SEV=0
	_SHELL_GIT_RP_NOTES=""
	if [ "$_SHELL_GIT_RP_CONFLICTED" != "-" ] && [ "$_SHELL_GIT_RP_CONFLICTED" -gt 0 ]; then
		_SHELL_GIT_RP_SEV=2
		_SHELL_GIT_RP_NOTES="$_SHELL_GIT_RP_NOTES unresolved conflicts;"
	fi
	if [ -n "$_SHELL_GIT_RP_OP" ]; then
		_SHELL_GIT_RP_SEV=2
		_SHELL_GIT_RP_NOTES="$_SHELL_GIT_RP_NOTES $_SHELL_GIT_RP_OP in progress;"
	fi
	local warn=""
	[ "$_SHELL_GIT_RP_HEAD" = "(detached)" ] && [ "$_SHELL_GIT_RP_BARE" != "true" ] && warn="$warn detached HEAD;"
	if [ "$_SHELL_GIT_RP_STAGED" != "-" ] && [ $((_SHELL_GIT_RP_STAGED + _SHELL_GIT_RP_UNSTAGED)) -gt 0 ]; then
		warn="$warn uncommitted changes;"
	fi
	[ "$_SHELL_GIT_RP_BEHIND" -gt 0 ] && warn="$warn behind upstream;"
	[ "$_SHELL_GIT_RP_GONE" = "1" ] && warn="$warn upstream is gone;"
	[ "$_SHELL_GIT_RP_STALE" -gt 0 ] && warn="$warn stale branches;"
	if [ -n "$warn" ]; then
		[ "$_SHELL_GIT_RP_SEV" -lt 1 ] && _SHELL_GIT_RP_SEV=1
		_SHELL_GIT_RP_NOTES="$_SHELL_GIT_RP_NOTES$warn"
	fi
	_SHELL_GIT_RP_NOTES="${_SHELL_GIT_RP_NOTES# }"
	_SHELL_GIT_RP_NOTES="${_SHELL_GIT_RP_NOTES%;}"
	return 0
}

# @internal
# @description Print the severity word of the collected state: `healthy`, `warning` or `problem`.
# @stdout The word.
# @exitcode 0 Always.
# @example
#   _shell::git::core::repo_collect; _shell::git::core::repo_severity
#
_shell::git::core::repo_severity() {
	case "${_SHELL_GIT_RP_SEV:-0}" in
	0) printf 'healthy\n' ;;
	1) printf 'warning\n' ;;
	*) printf 'problem\n' ;;
	esac
}

# @internal
# @description Print the collected state as `key<TAB>value` rows (the plain format).
# @stdout The rows.
# @exitcode 0 Always.
# @example
#   _shell::git::core::repo_collect; _shell::git::core::repo_rows
#
_shell::git::core::repo_rows() {
	printf 'branch\t%s\n' "$_SHELL_GIT_RP_HEAD"
	printf 'upstream\t%s\n' "${_SHELL_GIT_RP_UP:--}"
	printf 'ahead\t%s\n' "$_SHELL_GIT_RP_AHEAD"
	printf 'behind\t%s\n' "$_SHELL_GIT_RP_BEHIND"
	printf 'staged\t%s\n' "$_SHELL_GIT_RP_STAGED"
	printf 'unstaged\t%s\n' "$_SHELL_GIT_RP_UNSTAGED"
	printf 'untracked\t%s\n' "$_SHELL_GIT_RP_UNTRACKED"
	printf 'conflicted\t%s\n' "$_SHELL_GIT_RP_CONFLICTED"
	printf 'local_branches\t%s\n' "$_SHELL_GIT_RP_LOCAL"
	printf 'remote_branches\t%s\n' "$_SHELL_GIT_RP_REMOTE"
	printf 'stash\t%s\n' "$_SHELL_GIT_RP_STASH"
	printf 'base\t%s\n' "${_SHELL_GIT_RP_BASE:--}"
	printf 'merged\t%s\n' "$_SHELL_GIT_RP_MERGED"
	printf 'unmerged\t%s\n' "$_SHELL_GIT_RP_UNMERGED"
	printf 'stale\t%s\n' "$_SHELL_GIT_RP_STALE"
	printf 'operation\t%s\n' "${_SHELL_GIT_RP_OP:--}"
	printf 'severity\t%s\n' "$(_shell::git::core::repo_severity)"
	printf 'notes\t%s\n' "${_SHELL_GIT_RP_NOTES:--}"
}

# @internal
# @description Collect commit statistics with ONE `git log` pass piped to awk, into `_SHELL_GIT_RP_COMMITS`,
#   `_SHELL_GIT_RP_AUTHORS`, `_SHELL_GIT_RP_FIRST`, `_SHELL_GIT_RP_LAST` and `_SHELL_GIT_RP_TOPLIST`
#   (lines `count<TAB>name`, most active first). An empty repository gives zeros.
# @arg $1 integer Number of top contributors (default 5).
# @arg $2 integer Optional cap on the number of commits read.
# @exitcode 0 Collected.
# @example
#   _shell::git::core::repo_stats_data 5
#
_shell::git::core::repo_stats_data() {
	local top="${1:-5}" max="${2-}" us out line key val
	us=$'\037'
	local -a limit=()
	[ -n "$max" ] && limit=(--max-count="$max")
	out="$(_shell::git::core::git_ro log --format="%ad%x1f%aE%x1f%aN" --date=short ${limit[@]+"${limit[@]}"} 2>/dev/null | awk -F"$us" -v top="$top" '
		{ n++; if (lo == "" || $1 < lo) lo = $1; if ($1 > hi) hi = $1; c[$2]++; if (!($2 in nm)) nm[$2] = $3 }
		END {
			a = 0
			for (k in c) a++
			print "commits\t" n + 0
			print "authors\t" a
			print "first\t" (n ? lo : "-")
			print "last\t" (n ? hi : "-")
			for (i = 1; i <= top; i++) {
				best = ""; bc = 0
				for (k in c) if (c[k] > bc || (c[k] == bc && best != "" && nm[k] < nm[best])) { best = k; bc = c[k] }
				if (best == "") break
				print "top\t" bc "\t" nm[best]
				delete c[best]
			}
		}')"
	_SHELL_GIT_RP_COMMITS=0 _SHELL_GIT_RP_AUTHORS=0 _SHELL_GIT_RP_FIRST="-" _SHELL_GIT_RP_LAST="-" _SHELL_GIT_RP_TOPLIST=""
	while IFS= read -r line; do
		key="${line%%$'\t'*}"
		val="${line#*$'\t'}"
		case "$key" in
		commits) _SHELL_GIT_RP_COMMITS="$val" ;;
		authors) _SHELL_GIT_RP_AUTHORS="$val" ;;
		first) _SHELL_GIT_RP_FIRST="$val" ;;
		last) _SHELL_GIT_RP_LAST="$val" ;;
		top) _SHELL_GIT_RP_TOPLIST="$_SHELL_GIT_RP_TOPLIST$val"$'\n' ;;
		esac
	done <<LZ_EOF
$out
LZ_EOF
	return 0
}

# @internal
# @description Collect object and tree sizes into `_SHELL_GIT_RP_SZ_*` globals: LOOSE and PACK (what
#   `count-objects` reports: KiB with `-v`, human text with `-vH`), LOOSE_COUNT, PACKED_COUNT, PACKS, GARBAGE,
#   TRACKED (bytes of the files at HEAD, from ONE `ls-tree -r -l`), TRACKED_FILES and GITDIR (KiB, `du -sk`).
#   No walk of the working tree.
# @arg $1 string `human` to ask git for `-vH` strings, otherwise numbers (KiB).
# @exitcode 0 Collected.
# @example
#   _shell::git::core::repo_size_data human
#
_shell::git::core::repo_size_data() {
	local flag="-v" line key val out gitdir
	[ "${1-}" = "human" ] && flag="-vH"
	_SHELL_GIT_RP_SZ_LOOSE=0 _SHELL_GIT_RP_SZ_PACK=0 _SHELL_GIT_RP_SZ_LOOSE_COUNT=0 _SHELL_GIT_RP_SZ_PACKED_COUNT=0
	_SHELL_GIT_RP_SZ_PACKS=0 _SHELL_GIT_RP_SZ_GARBAGE=0
	while IFS= read -r line; do
		key="${line%%: *}"
		val="${line#*: }"
		case "$key" in
		count) _SHELL_GIT_RP_SZ_LOOSE_COUNT="$val" ;;
		size) _SHELL_GIT_RP_SZ_LOOSE="$val" ;;
		in-pack) _SHELL_GIT_RP_SZ_PACKED_COUNT="$val" ;;
		packs) _SHELL_GIT_RP_SZ_PACKS="$val" ;;
		size-pack) _SHELL_GIT_RP_SZ_PACK="$val" ;;
		garbage) _SHELL_GIT_RP_SZ_GARBAGE="$val" ;;
		esac
	done < <(_shell::git::core::git_ro count-objects "$flag" 2>/dev/null)
	out="$(_shell::git::core::git_ro ls-tree -r -l HEAD 2>/dev/null | awk -F'\t' '{ split($1, f, " "); if (f[4] != "-") s += f[4]; n++ } END { print s + 0, n + 0 }')"
	_SHELL_GIT_RP_SZ_TRACKED="${out% *}"
	_SHELL_GIT_RP_SZ_TRACKED_FILES="${out#* }"
	gitdir="$(_shell::git::core::git_ro rev-parse --absolute-git-dir 2>/dev/null)"
	_SHELL_GIT_RP_SZ_GITDIR=0
	if [ -d "$gitdir" ]; then
		out="$(du -sk "$gitdir" 2>/dev/null)"
		_SHELL_GIT_RP_SZ_GITDIR="${out%%[[:space:]]*}"
	fi
	return 0
}
