#!/usr/bin/env bash
# @file lib/prompt_skills_fzf.sh
# @brief Interactive menus of the Prompt Skills Sync (browse, pick, view, update, remove, branch).
# @description
#   Same look-and-feel as the other prompt menus: every list goes through shell::fzf::select, ends with the
#   "← Back" row (SHELL_FZF_BACK_LABEL, exit code 11, nothing mutated), and loops: list -> select -> action -> refreshed list
#   (the status markers are rebuilt after every action and the cursor stays where it was).
#
#   Status markers: `-` not installed, `G` / `P` installed in the global / personal store, `*` an update is available,
#   `!` modified locally.
#
#   The live preview runs in a separate process where no `shell::*` function exists, so it is a POSIX `sh` script written into a
#   private work directory (removed on exit, error, Ctrl-C and kill). It only reads the disk cache: a cache miss shows
#   "loading..." and downloads that one file once (the cache is also warmed in the background when a list opens), so moving the
#   cursor never hits the network. Copy, install, update and remove run in the main function AFTER fzf exits (`--expect`
#   keys), never inside fzf `execute`, so they work on every pass.

# @internal
# @description Write the live preview script into the work directory. It reads `view.tsv` (written by view::build) and the
#   content cache; the baked values are the cache layout and the settings of the transport script.
# @arg $1 string The work directory.
# @exitcode 0 Written.
# @example
#   _shell::prompt::skills::preview::init "$work"
#
_shell::prompt::skills::preview::init() {
	local work="${1-}" base
	base="${XDG_CACHE_HOME:-$HOME/.cache}/shell/skills/${_SK_REPO%%/*}__${_SK_REPO#*/}"
	{
		printf 'WORK=%s\nBASE=%s\nTX=%s\nREPO=%s\nSPATH=%s\nFIXTURE=%s\nBACK=%s\n' "$(_shell::conf::sq "$work")" "$(_shell::conf::sq "$base")" \
			"$(_shell::conf::sq "$SHELL_DIR/scripts/prompt_skills_transport.sh")" "$(_shell::conf::sq "$_SK_REPO")" "$(_shell::conf::sq "$SHELL_PROMPT_SKILLS_PATH")" \
			"$(_shell::conf::sq "${SHELL_PROMPT_SKILLS_LOCAL_DIR-}")" "$(_shell::conf::sq "$SHELL_FZF_BACK_LABEL")"
		cat <<'EOS'
main () {
	key="$1"
	esc="$(printf '\033')"
	dim="${esc}[2m"
	rst="${esc}[0m"
	yel="${esc}[33m"
	red="${esc}[31m"
	if [ "$key" = "$BACK" ]; then
		printf '%sGo back without changing anything%s\n' "$dim" "$rst"
		return 0
	fi
	row="$(awk -F'\t' -v k="$key" '$1 == k { print; exit }' "$WORK/view.tsv" 2>/dev/null)"
	[ -n "$row" ] || return 0
	tab="$(printf '\t')"
	IFS="$tab" read -r k rpath sha size tags st inst branch loc <<EOF
$row
EOF
	bdir="$(printf '%s' "$branch" | sed 's#/#%2F#g')"
	blob="$BASE/$bdir/blobs/$sha"
	cols="${FZF_PREVIEW_COLUMNS:-80}"
	lines="${FZF_PREVIEW_LINES:-30}"
	maxl=$((lines - 10))
	[ "$maxl" -lt 5 ] && maxl=5
	pretty="$(printf '%s' "${key##*/}" | tr '-' ' ' | awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2); print }')"
	have=0
	if [ "$sha" != "-" ]; then
		if [ ! -f "$blob" ]; then
			printf '%sloading...%s\n' "$dim" "$rst"
			SKILLS_REPO="$REPO" SKILLS_BRANCH="$branch" SKILLS_PATH="$SPATH" SKILLS_CACHE="$BASE/$bdir" SKILLS_BLOBS="$BASE/$bdir/blobs" \
				SKILLS_LOCAL_DIR="$FIXTURE" SKILLS_LOG="$BASE/$bdir/requests.log" sh "$TX" file "$rpath" "$sha" >/dev/null 2>&1
		fi
		[ -f "$blob" ] && have=1
	fi
	strip() {
		if [ "$(sed -n 1p "$1" | tr -d '\r')" = "---" ] && sed -n '2,$p' "$1" | tr -d '\r' | grep -q '^---$'; then
			awk '{ sub(/\r$/, "") } NR == 1 { next } f { print; next } $0 == "---" { f = 1 }' "$1"
		else
			cat "$1"
		fi
	}
	fm() {
		awk -v k="$1" '{ sub(/\r$/, "") } NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit }
			{ i = index($0, ":"); if (i > 0 && substr($0, 1, i - 1) == k) { v = substr($0, i + 1); sub(/^[ \t]+/, "", v); print v; exit } }' "$2"
	}
	src="$blob"
	[ "$have" = 1 ] || src="$inst"
	title=""
	if [ -f "$src" ]; then
		title="$(fm title "$src")"
		[ -n "$title" ] || title="$(grep -m1 '^# ' "$src" | sed 's/^# *//')"
	fi
	row2() { printf '%s%-12s%s %s\n' "$dim" "$1" "$rst" "$2"; }
	printf '%s%s%s\n' "$yel" "${title:-$pretty}" "$rst"
	row2 tags "$tags"
	row2 source "$REPO@$branch:$rpath"
	row2 blob "$(printf '%s' "$sha" | cut -c1-8)"
	case "$st" in
	-) note="not installed" ;;
	*'!'*) note="$st - modified locally" ;;
	*'*'*) note="$st - update available" ;;
	*'?'*) note="$st - no longer in the repository" ;;
	*) note="$st - installed, up to date" ;;
	esac
	row2 status "$note"
	if [ -f "$src" ]; then
		vars="$(strip "$src" | grep -o '{{[^{}]*}}' | sed 's/^{{//; s/}}$//; s/|.*//; s/^ *//; s/ *$//' | awk '!s[$0]++' | paste -s -d, - | sed 's/,/, /g')"
		row2 variables "${vars:-none}"
		row2 size "$(strip "$src" | wc -m | tr -d ' ') chars (remote file: ${size} bytes)"
	fi
	if [ "$have" = 0 ]; then
		if [ "$sha" = "-" ]; then
			printf '%sThis prompt is not available on branch %s.%s\n' "$red" "$branch" "$rst"
		else
			printf '%scould not load the file (offline?)%s\n' "$red" "$rst"
		fi
		[ -f "$inst" ] || return 0
	fi
	case "$st" in
	*'!'* | *'*'*)
		if [ "$have" = 1 ] && [ -f "$inst" ]; then
			printf '%s----- installed -> remote (diff) -----%s\n' "$dim" "$rst"
			strip "$inst" >"$WORK/pv.a.$$"
			strip "$blob" >"$WORK/pv.b.$$"
			diff -u "$WORK/pv.a.$$" "$WORK/pv.b.$$" | sed '1,2d' | head -n "$maxl" | awk -v e="$esc" '
				/^\+/ { printf "%s[32m%s%s[0m\n", e, $0, e; next }
				/^-/ { printf "%s[31m%s%s[0m\n", e, $0, e; next }
				{ print }'
			rm -f "$WORK/pv.a.$$" "$WORK/pv.b.$$"
			return 0
		fi
		;;
	esac
	printf '%s----------------------------------------%s\n' "$dim" "$rst"
	if command -v bat >/dev/null 2>&1; then
		strip "$src" | bat --style=plain --color=always --language=markdown --wrap=character --terminal-width="$cols" --paging=never 2>/dev/null | head -n "$maxl"
	else
		strip "$src" | fold -s -w "$cols" | head -n "$maxl"
	fi
}
main "$@"
EOS
	} >"$work/skills_preview.sh"
}

# @internal
# @description Build `view.tsv` (what the preview reads) and print the fzf rows. Modes: `remote` (one row per remote prompt,
#   key = slug), `installed` (one row per prompt installed from skills, key = `G/slug` or `P/slug`) and `outdated` (the
#   installed ones that have an update or a local change).
#   `view.tsv` columns: key, remote path, remote sha (`-` if gone), size, tags, status, installed file, branch, local state.
# @arg $1 string The work directory.
# @arg $2 string The mode.
# @stdout Rows `key<TAB>display`.
# @exitcode 0 Always.
# @example
#   rows="$(_shell::prompt::skills::view::build "$work" remote)"
#
_shell::prompt::skills::view::build() {
	local work="${1-}" mode="${2-remote}" gdir ldir
	gdir="$(_shell::prompt::dir global)"
	ldir="$(_shell::prompt::dir local)"
	{
		_shell::prompt::skills::locks_state all "" | awk -F'\t' 'NF >= 8 { print "S\t" $0 }'
		_shell::prompt::skills::entries | awk -F'\t' '{ print "E\t" $0 }'
	} | awk -F'\t' -v mode="$mode" -v gdir="$gdir" -v ldir="$ldir" -v branch="$_SK_BRANCH" -v out="$work/view.tsv" '
		function dash(v) { return (v == "" ? "-" : v) }
		function pretty(s,   n, a, i, r) { n = split(s, a, "-"); r = ""; for (i = 1; i <= n; i++) r = r (i > 1 ? " " : "") toupper(substr(a[i], 1, 1)) substr(a[i], 2); return r }
		BEGIN { printf "" > out }
		$1 == "S" {
			k++; ch[k] = $2; sl[k] = $3; lc[k] = $4; rm[k] = $5; pa[k] = $6; lb[k] = $7; rs[k] = $9
			if ($4 == "nofile") next
			f = ($4 == "modified") ? "!" : (($5 == "newer" || $5 == "switch") ? "*" : (($5 == "gone") ? "?" : ""))
			fl[k] = f
			st[$6] = st[$6] (st[$6] == "" ? "" : ",") $2 f
			if (!($6 in inst)) { inst[$6] = (($2 == "G") ? gdir : ldir) "/" $3 ".md"; loc1[$6] = $4 }
			next
		}
		$1 == "E" { c++; es[c] = $2; ep[c] = $3; eh[c] = $4; ez[c] = $5; et[c] = $6; byp[$3] = c; next }
		END {
			if (mode == "remote") {
				for (i = 1; i <= c; i++) {
					s = ((ep[i] in st) ? st[ep[i]] : "-")
					printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", es[i], ep[i], eh[i], dash(ez[i]), dash(et[i]), s, dash(inst[ep[i]]), branch, dash(loc1[ep[i]]) > out
					printf "%s\t%-7s %-30s %s\n", es[i], "[" s "]", es[i], et[i]
				}
				exit
			}
			for (i = 1; i <= k; i++) {
				if (lc[i] == "nofile") continue
				if (mode == "outdated" && fl[i] != "!" && fl[i] != "*") continue
				e = (pa[i] in byp) ? byp[pa[i]] : 0
				key = ch[i] "/" sl[i]
				s = ch[i] fl[i]
				file = ((ch[i] == "G") ? gdir : ldir) "/" sl[i] ".md"
				printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", key, pa[i], dash(rs[i]), (e ? dash(ez[e]) : "-"), (e ? dash(et[e]) : "-"), s, file, lb[i], lc[i] > out
				printf "%s\t%-7s %-30s %s\n", key, "[" s "]", sl[i], (e ? et[e] : "(no longer in the repository)")
			}
		}'
}

# @internal
# @description Warm the content cache in the background (one tarball or a few parallel requests), so previews and copies are
#   instant. It is skipped when SHELL_PROMPT_SKILLS_PREFETCH=0.
# @exitcode 0 Always.
# @example
#   _shell::prompt::skills::prefetch
#
_shell::prompt::skills::prefetch() {
	local pairs
	[ "${SHELL_PROMPT_SKILLS_PREFETCH-1}" = "0" ] && return "$RETURN_SUCCESS"
	pairs="$(_shell::prompt::skills::entries | awk -F'\t' '{ print $2 "\t" $3 }')"
	[ -n "$pairs" ] || return "$RETURN_SUCCESS"
	(
		(printf '%s\n' "$pairs" | _shell::prompt::skills::ensure_blobs >/dev/null 2>&1) &
	)
	return "$RETURN_SUCCESS"
}

# @internal
# @description Show rows with the live preview, a trailing "← Back" row and multi-select, through shell::fzf::select.
#   The `--expect` keys come back on the first output line.
# @arg $1 string The work directory.
# @arg $2 string The rows.
# @arg $3 string The prompt.
# @arg $4 string The header.
# @arg $5 string The key to put the cursor on (may be empty).
# @arg $6 string Comma-separated `--expect` keys.
# @arg $7 string `true` for multi-select.
# @stdout The key pressed (first line, empty for Enter) and the selected rows.
# @exitcode 0 Something was selected.
# @exitcode 9 Cancelled.
# @example
#   out="$(_shell::prompt::skills::choose "$work" "$rows" "Skills: " "Enter: actions" "" "ctrl-y" true)" || return
#
_shell::prompt::skills::choose() {
	local work="${1-}" rows="${2-}" prompt="${3-}" header="${4-}" initial="${5-}" expect="${6-}" multi="${7-false}"
	local -a init=() ml=()
	[ -n "$initial" ] && init=(--initial "$initial" --initial-field 1)
	[ "$multi" = "true" ] && ml=(--multi)
	printf '%s\n%s\t%s\n' "$rows" "$SHELL_FZF_BACK_LABEL" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select ${init[@]+"${init[@]}"} \
		--delimiter=$'\t' --with-nth=2 --prompt="$prompt" --header="$header" \
		--preview="sh $(_shell::conf::sq "$work/skills_preview.sh") {1}" --preview-window="right:55%:wrap" \
		--height=80% --bind=ctrl-/:toggle-preview "--expect=${expect}" ${ml[@]+"${ml[@]}"}
}

# @internal
# @description Split the output of `choose` into the key pressed (`_SK_KEY`), the selected row keys without the Back row
#   (`_SK_KEYS`, one per line) and whether Back was among them (`_SK_BACK`).
# @arg $1 string The output of choose.
# @exitcode 0 Always.
# @example
#   _shell::prompt::skills::split_choice "$out"
#
_shell::prompt::skills::split_choice() {
	local out="${1-}" rest line k
	_SK_KEY="${out%%$'\n'*}"
	_SK_KEYS=""
	_SK_BACK="false"
	case "$out" in
	*$'\n'*) rest="${out#*$'\n'}" ;;
	*) rest="" ;;
	esac
	while IFS= read -r line; do
		[ -n "$line" ] || continue
		k="${line%%$'\t'*}"
		if [ "$k" = "$SHELL_FZF_BACK_LABEL" ]; then
			_SK_BACK="true"
		else
			_SK_KEYS="${_SK_KEYS}${k}"$'\n'
		fi
	done <<EOF
$rest
EOF
	return "$RETURN_SUCCESS"
}

# @internal
# @description Print the `view.tsv` row of a key.
# @arg $1 string The work directory.
# @arg $2 string The key.
# @stdout The row.
# @exitcode 0 Found.
# @exitcode 1 Unknown.
# @example
#   row="$(_shell::prompt::skills::view::row "$work" skill-optimizer)"
#
_shell::prompt::skills::view::row() {
	local row
	row="$(awk -F'\t' -v k="${2-}" '$1 == k { print; exit }' "${1-}/view.tsv" 2>/dev/null)"
	[ -n "$row" ] || return "$RETURN_FAILURE"
	printf '%s\n' "$row"
}

# @internal
# @description Ask for the target store with fzf: Global (preselected), Personal, Back. The answer is left in `_SK_CHOICE`
#   (not on stdout, so the "Back" message is visible).
# @exitcode 0 Chosen (`global` or `local`).
# @exitcode 9 Cancelled.
# @exitcode 11 The user picked "← Back" (logged; nothing was installed).
# @example
#   _shell::prompt::skills::scope::menu || return $?
#
_shell::prompt::skills::scope::menu() {
	local choice
	choice="$(printf 'Global (any directory)\nPersonal (this project: %s)\n%s\n' "$SHELL_PROMPT_LOCAL_NAME" "$SHELL_FZF_BACK_LABEL" |
		shell::fzf::select --prompt="Install into: " --header="Enter: choose   ESC: cancel" --height=30%)" || return "$RETURN_CANCELLED"
	case "$choice" in
	"$SHELL_FZF_BACK_LABEL" | '')
		shell::logger::info "Back — nothing was installed"
		return "$RETURN_BACK"
		;;
	Personal*) _SK_CHOICE="local" ;;
	*) _SK_CHOICE="global" ;;
	esac
	return "$RETURN_SUCCESS"
}

# @internal
# @description Install the selected remote prompts into a store. Conflicts and locally modified prompts are skipped first;
#   after that the user is asked once whether to overwrite them (their old version stays in history).
# @arg $1 string The work directory.
# @arg $2 string `true` for dry-run.
# @arg $3 string The scope.
# @arg $4 string The keys (remote slugs), one per line.
# @exitcode 0 Always (the outcome is logged).
# @example
#   _shell::prompt::skills::do::install "$work" false global "$keys"
#
_shell::prompt::skills::do::install() {
	local work="${1-}" dry="${2-false}" scope="${3-global}" keys="${4-}" k row p h
	: >"$work/todo"
	while IFS= read -r k; do
		[ -n "$k" ] || continue
		row="$(_shell::prompt::skills::view::row "$work" "$k")" || continue
		IFS=$'\t' read -r _ p h _ <<EOF
$row
EOF
		printf '%s\t%s\t%s\n' "$k" "$p" "$h" >>"$work/todo"
	done <<EOF
$keys
EOF
	[ -s "$work/todo" ] || {
		shell::logger::info "Nothing to install"
		return "$RETURN_SUCCESS"
	}
	rm -f "$work/skipped.$scope"
	_shell::prompt::skills::install::many "$work" "$dry" false "$scope" "$work/todo" || true
	_shell::prompt::skills::offer_force "$work" "$dry" "$scope"
	return "$RETURN_SUCCESS"
}

# @internal
# @description After an install or update: when entries were skipped (a conflicting or locally modified prompt), ask once
#   whether to overwrite them. The old version is snapshotted into history; declining changes nothing.
# @arg $1 string The work directory.
# @arg $2 string `true` for dry-run.
# @arg $3 string The scope.
# @exitcode 0 Always.
# @example
#   _shell::prompt::skills::offer_force "$work" false global
#
_shell::prompt::skills::offer_force() {
	local work="${1-}" dry="${2-false}" scope="${3-global}" n ok="false"
	[ -s "$work/skipped.$scope" ] || return "$RETURN_SUCCESS"
	[ "$dry" = "true" ] && return "$RETURN_SUCCESS"
	n="$(wc -l <"$work/skipped.$scope" | tr -d ' ')"
	shell::ask::accept "${n} prompt(s) were skipped (existing or modified locally). Overwrite them? Your versions are kept in history" && ok="true"
	if [ "$ok" != "true" ]; then
		shell::logger::info "Kept as they are - nothing was overwritten"
		return "$RETURN_SUCCESS"
	fi
	cp -- "$work/skipped.$scope" "$work/todo.force"
	rm -f "$work/skipped.$scope"
	_shell::prompt::skills::install::many "$work" "$dry" true "$scope" "$work/todo.force" || true
	return "$RETURN_SUCCESS"
}

# @internal
# @description Copy a remote prompt (from the cache, no install) to the clipboard, asking for its placeholders.
# @arg $1 string The work directory.
# @arg $2 string `true` for dry-run.
# @arg $3 string The key.
# @exitcode 0 Always (the outcome is logged).
# @example
#   _shell::prompt::skills::do::copy "$work" false skill-optimizer
#
_shell::prompt::skills::do::copy() {
	local work="${1-}" dry="${2-false}" row p
	row="$(_shell::prompt::skills::view::row "$work" "${3-}")" || return "$RETURN_SUCCESS"
	IFS=$'\t' read -r _ p _ <<EOF
$row
EOF
	if [ "$p" = "-" ]; then
		shell::logger::warn "'${3-}' is not available on branch ${_SK_BRANCH}; nothing was copied."
		return "$RETURN_SUCCESS"
	fi
	_shell::prompt::skills::copy::inner "$work" "$dry" true "$p" || true
	return "$RETURN_SUCCESS"
}

# @internal
# @description Show a remote prompt in the pager.
# @arg $1 string The work directory.
# @arg $2 string The key.
# @exitcode 0 Always.
# @example
#   _shell::prompt::skills::do::view "$work" skill-optimizer
#
_shell::prompt::skills::do::view() {
	local work="${1-}" row p h
	row="$(_shell::prompt::skills::view::row "$work" "${2-}")" || return "$RETURN_SUCCESS"
	IFS=$'\t' read -r _ p h _ <<EOF
$row
EOF
	[ "$h" != "-" ] || {
		shell::logger::warn "'${2-}' is not available on branch ${_SK_BRANCH}."
		return "$RETURN_SUCCESS"
	}
	printf '%s\t%s\n' "$p" "$h" | _shell::prompt::skills::ensure_blobs || {
		shell::logger::error "Could not download '${p}'."
		return "$RETURN_SUCCESS"
	}
	_shell::prompt::pager "$(_shell::prompt::skills::cache_dir)/blobs/$h"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Update the selected installed prompts (keys `G/slug` or `P/slug`) to the remote version of the current branch.
#   Locally modified ones are skipped and then offered for overwrite once.
# @arg $1 string The work directory.
# @arg $2 string `true` for dry-run.
# @arg $3 string The keys, one per line.
# @exitcode 0 Always.
# @example
#   _shell::prompt::skills::do::update "$work" false "$keys"
#
_shell::prompt::skills::do::update() {
	local work="${1-}" dry="${2-false}" keys="${3-}" k row p h sc
	rm -f "$work"/todo.G "$work"/todo.P "$work"/skipped.global "$work"/skipped.local
	while IFS= read -r k; do
		[ -n "$k" ] || continue
		row="$(_shell::prompt::skills::view::row "$work" "$k")" || continue
		IFS=$'\t' read -r _ p h _ <<EOF
$row
EOF
		if [ "$h" = "-" ]; then
			shell::logger::warn "'${k#*/}' no longer exists on ${_SK_BRANCH} - skipped."
			continue
		fi
		printf '%s\t%s\t%s\n' "${k#*/}" "$p" "$h" >>"$work/todo.${k%%/*}"
	done <<EOF
$keys
EOF
	for sc in G P; do
		[ -s "$work/todo.$sc" ] || continue
		if [ "$sc" = "G" ]; then
			_shell::prompt::skills::install::many "$work" "$dry" false global "$work/todo.$sc" || true
			_shell::prompt::skills::offer_force "$work" "$dry" global
		else
			_shell::prompt::skills::install::many "$work" "$dry" false local "$work/todo.$sc" || true
			_shell::prompt::skills::offer_force "$work" "$dry" local
		fi
	done
	return "$RETURN_SUCCESS"
}

# @internal
# @description Remove the selected installed prompts (keys `G/slug` or `P/slug`); each one is confirmed and snapshotted.
# @arg $1 string The work directory.
# @arg $2 string `true` for dry-run.
# @arg $3 string The keys, one per line.
# @exitcode 0 Always.
# @example
#   _shell::prompt::skills::do::remove "$work" false "$keys"
#
_shell::prompt::skills::do::remove() {
	local work="${1-}" dry="${2-false}" keys="${3-}" k scope
	# fd 8, not stdin: the confirmation inside the loop must read the terminal, not the list of keys.
	while IFS= read -r k <&8; do
		[ -n "$k" ] || continue
		scope="global"
		[ "${k%%/*}" = "P" ] && scope="local"
		_shell::prompt::skills::remove::inner "$work" "$dry" false "$scope" "${k#*/}" || true
	done 8<<EOF
$keys
EOF
	return "$RETURN_SUCCESS"
}

# @internal
# @description The action menu of the browse hub. The chosen action is left in `_SK_CHOICE`: `global`, `personal`, `view`,
#   `copy`, `update`, `remove` or `branch`.
# @arg $1 string The count of selected prompts.
# @exitcode 0 Chosen.
# @exitcode 9 Cancelled.
# @exitcode 11 The user picked "← Back" (logged; nothing was changed).
# @example
#   _shell::prompt::skills::actions "$n" || continue
#
_shell::prompt::skills::actions() {
	local choice
	choice="$(printf 'Install global\nInstall personal\nView\nCopy\nUpdate\nRemove\nSwitch branch\n%s\n' "$SHELL_FZF_BACK_LABEL" |
		shell::fzf::select --prompt="Action (${1-1} selected): " --header="Enter: run   ESC: cancel" --height=40%)" || return "$RETURN_CANCELLED"
	case "$choice" in
	"Install global") _SK_CHOICE="global" ;;
	"Install personal") _SK_CHOICE="personal" ;;
	View) _SK_CHOICE="view" ;;
	Copy) _SK_CHOICE="copy" ;;
	Update) _SK_CHOICE="update" ;;
	Remove) _SK_CHOICE="remove" ;;
	"Switch branch") _SK_CHOICE="branch" ;;
	*)
		shell::logger::info "Back — nothing was changed"
		return "$RETURN_BACK"
		;;
	esac
	return "$RETURN_SUCCESS"
}

# @internal
# @description Map remote keys (slugs) to the installed keys (`G/slug`, `P/slug`) tracked for the same remote file.
# @arg $1 string The work directory.
# @arg $2 string The remote keys, one per line.
# @stdout The installed keys, one per line.
# @exitcode 0 Always.
# @example
#   inst="$(_shell::prompt::skills::installed_keys "$work" "$keys")"
#
_shell::prompt::skills::installed_keys() {
	local work="${1-}" k row p
	while IFS= read -r k; do
		[ -n "$k" ] || continue
		row="$(_shell::prompt::skills::view::row "$work" "$k")" || continue
		IFS=$'\t' read -r _ p _ <<EOF
$row
EOF
		_shell::prompt::skills::locks_state all "" | SK_P="$p" awk -F'\t' '$5 == ENVIRON["SK_P"] && $3 != "nofile" { print $1 "/" $2 }'
	done <<EOF
$2
EOF
}

# @internal
# @description Switch the branch from inside a menu: pick it, load its index, warm its cache and remember it for the session
#   (the menu function exports it after the scoped subshell ends, through `_SK_BRANCH_FILE`).
# @exitcode 0 Always (the outcome is logged; Back and ESC change nothing).
# @example
#   _shell::prompt::skills::switch_branch
#
_shell::prompt::skills::switch_branch() {
	local nb rc=0 old="$_SK_BRANCH"
	nb="$(_shell::prompt::skills::branch::pick)" || rc=$?
	if [ "$rc" -eq "$RETURN_BACK" ]; then
		shell::logger::info "Back — nothing was switched"
		return "$RETURN_SUCCESS"
	fi
	[ "$rc" -eq 0 ] || return "$RETURN_SUCCESS"
	_SK_BRANCH="$nb"
	_SK_EXPLICIT="true"
	if ! _shell::prompt::skills::index; then
		_SK_BRANCH="$old"
		return "$RETURN_SUCCESS"
	fi
	[ -z "${_SK_BRANCH_FILE-}" ] || printf '%s\n' "$nb" >"$_SK_BRANCH_FILE"
	_shell::prompt::skills::prefetch
	shell::logger::success "Branch for this session: ${nb}"
	return "$RETURN_SUCCESS"
}

# @internal
# @description The loop of every skills menu: build the rows, choose, run the action, rebuild.
# @arg $1 string The work directory.
# @arg $2 string The kind: `browse`, `pick`, `view`, `update`, `remove`.
# @arg $3 string `true` for dry-run.
# @exitcode 0 Closed with ESC (or nothing left to do).
# @exitcode 11 The user picked "← Back".
# @example
#   _shell::prompt::scoped _shell::prompt::skills::loop browse false
#
_shell::prompt::skills::loop() {
	local work="${1-}" kind="${2-browse}" dry="${3-false}" rows out rc mode multi expect header prompt initial="" act scope first inst verb
	mode="remote"
	multi="true"
	expect="ctrl-y"
	verb="changed"
	case "$kind" in
	browse) header=$'Enter: actions (Tab: multi-select)   ESC: leave   ^/: preview\n^Y copy   ^G install global   ^P install personal   ^B switch branch' ;;
	pick)
		verb="installed"
		header="Tab: multi-select   Enter: install   ESC: leave   ^/: preview"
		;;
	view)
		multi="false"
		header=$'Enter: view   ESC: leave   ^/: preview\n^Y copy to clipboard'
		;;
	update)
		mode="outdated"
		verb="updated"
		header="Tab: multi-select   Enter: update   ESC: leave   ^/: preview"
		;;
	remove)
		mode="installed"
		verb="removed"
		header="Tab: multi-select   Enter: remove (kept in history)   ESC: leave   ^/: preview"
		;;
	esac
	[ "$kind" = "browse" ] && expect="ctrl-y,ctrl-g,ctrl-p,ctrl-b"
	_shell::prompt::skills::index || return $?
	_shell::prompt::skills::preview::init "$work"
	_shell::prompt::skills::prefetch
	while true; do
		prompt="Skills ${_SK_REPO}@${_SK_BRANCH}: "
		rows="$(_shell::prompt::skills::view::build "$work" "$mode")"
		if [ -z "$rows" ]; then
			case "$kind" in
			update) shell::logger::success "Everything installed from skills is up to date." ;;
			remove) shell::logger::info "Nothing is installed from skills." ;;
			*) shell::logger::warn "No prompt found under '${SHELL_PROMPT_SKILLS_PATH}/' in ${_SK_REPO}@${_SK_BRANCH}." ;;
			esac
			return "$RETURN_SUCCESS"
		fi
		rc=0
		out="$(_shell::prompt::skills::choose "$work" "$rows" "$prompt" "$header" "$initial" "$expect" "$multi")" || rc=$?
		if [ "$rc" -ne 0 ]; then
			shell::logger::info "Closed"
			return "$RETURN_SUCCESS"
		fi
		_shell::prompt::skills::split_choice "$out"
		if [ -z "$_SK_KEYS" ]; then
			if [ "$_SK_BACK" = "true" ]; then
				shell::logger::info "Back — nothing was ${verb}"
				return "$RETURN_BACK"
			fi
			continue
		fi
		first="${_SK_KEYS%%$'\n'*}"
		initial="$first"
		if [ "$_SK_KEY" = "ctrl-b" ]; then
			_shell::prompt::skills::switch_branch
			continue
		fi
		if [ "$_SK_KEY" = "ctrl-y" ]; then
			_shell::prompt::skills::do::copy "$work" "$dry" "$first"
			continue
		fi
		case "$kind" in
		browse)
			act=""
			case "$_SK_KEY" in
			ctrl-g) act="global" ;;
			ctrl-p) act="personal" ;;
			*)
				rc=0
				_shell::prompt::skills::actions "$(printf '%s' "$_SK_KEYS" | grep -c .)" || rc=$?
				[ "$rc" -eq 0 ] || continue
				act="$_SK_CHOICE"
				;;
			esac
			case "$act" in
			global) _shell::prompt::skills::do::install "$work" "$dry" global "$_SK_KEYS" ;;
			personal) _shell::prompt::skills::do::install "$work" "$dry" local "$_SK_KEYS" ;;
			view) _shell::prompt::skills::do::view "$work" "$first" ;;
			copy) _shell::prompt::skills::do::copy "$work" "$dry" "$first" ;;
			update)
				inst="$(_shell::prompt::skills::installed_keys "$work" "$_SK_KEYS")"
				if [ -z "$inst" ]; then
					shell::logger::info "Nothing selected is installed from skills."
				else
					_shell::prompt::skills::do::update "$work" "$dry" "$inst"
				fi
				;;
			remove)
				inst="$(_shell::prompt::skills::installed_keys "$work" "$_SK_KEYS")"
				if [ -z "$inst" ]; then
					shell::logger::info "Nothing selected is installed from skills."
				else
					_shell::prompt::skills::do::remove "$work" "$dry" "$inst"
				fi
				;;
			branch) _shell::prompt::skills::switch_branch ;;
			esac
			;;
		pick)
			rc=0
			_shell::prompt::skills::scope::menu || rc=$?
			[ "$rc" -eq 0 ] || continue
			scope="$_SK_CHOICE"
			_shell::prompt::skills::do::install "$work" "$dry" "$scope" "$_SK_KEYS"
			;;
		view) _shell::prompt::skills::do::view "$work" "$first" ;;
		update) _shell::prompt::skills::do::update "$work" "$dry" "$_SK_KEYS" ;;
		remove) _shell::prompt::skills::do::remove "$work" "$dry" "$_SK_KEYS" ;;
		esac
	done
}

# @internal
# @description Parse the options shared by the ::fzf functions and run a menu in a scoped work directory.
# @arg $1 string The kind (see loop).
# @arg $2 string The function name (for the message).
# @arg $@ string The user's arguments.
# @exitcode 0 Closed.
# @exitcode 2 Invalid option.
# @exitcode 3 fzf is missing.
# @exitcode 11 The user picked "← Back".
# @example
#   _shell::prompt::skills::menu browse shell::prompt::skills::browse::fzf "$@"
#
_shell::prompt::skills::menu() {
	local kind="${1-browse}" fn="${2-}" rc=0 chosen
	shift 2
	_shell::prompt::skills::parse "n" "$@" || return $?
	[ "${#_SK_NAMES[@]}" -eq 0 ] || {
		shell::logger::error "${fn} takes no names."
		return "$RETURN_INVALID"
	}
	shell::dependency::fzf::ensure || {
		shell::logger::error "fzf is required but could not be installed."
		return "$RETURN_NOT_FOUND"
	}
	_SK_BRANCH_FILE="$(umask 077 && mktemp "${TMPDIR:-/tmp}/shell-skills-branch.XXXXXX")" || return "$RETURN_FAILURE"
	_shell::prompt::scoped _shell::prompt::skills::loop "$kind" "$_SK_DRY" || rc=$?
	# A branch picked inside the menu lasts for the session; the loop ran in a subshell, so it comes back through a file.
	chosen="$(cat "$_SK_BRANCH_FILE" 2>/dev/null)"
	rm -f -- "$_SK_BRANCH_FILE"
	_SK_BRANCH_FILE=""
	if [ -n "$chosen" ] && _shell::prompt::skills::valid_branch "$chosen"; then
		export SHELL_PROMPT_SKILLS_BRANCH="$chosen"
	fi
	return "$rc"
}

# @description Browse the prompts of the skills repository with a live preview and act on the selection: Install global,
#   Install personal, View, Copy, Update, Remove, Switch branch. Tab selects several prompts.
#
#   Markers: `-` not installed, `G` / `P` installed in the global / personal store, `*` update available, `!` modified locally.
#   Shortcuts: Enter = actions, Ctrl-Y = copy (works without installing), Ctrl-G / Ctrl-P = install global / personal,
#   Ctrl-B = switch branch, Ctrl-/ = toggle the preview. The preview reads the disk cache only (no network per cursor move).
#   `--branch` and the branch menu set SHELL_PROMPT_SKILLS_BRANCH for the session.
# @option -n Optional dry-run flag. Install, copy and remove commands are printed instead of executed.
# @option --repo <owner/repo> Optional. Another repository.
# @option --branch <name> Optional. Another branch (default master).
# @option --refresh Optional. Ask GitHub again.
# @option -h | --help Show help and return.
# @exitcode 0 Closed with ESC.
# @exitcode 2 Invalid option.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::prompt::skills::browse::fzf
#   shell::prompt::skills::browse::fzf --branch develop
#
shell::prompt::skills::browse::fzf() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Browse the skills repository with a live preview; install, view, copy, update or remove" \
			"shell::prompt::skills::browse::fzf [-n] [--repo <o/r>] [--branch <b>] [--refresh]" "shell::prompt::skills::browse::fzf" \
			"-n::Dry-run: print commands instead of executing them" "--repo <owner/repo>::Another repository" "--branch <name>::Branch to read (default master)" \
			"--refresh::Ignore the cached index" "-h, --help::Display this help message"
		shell::logger::note "Enter: actions  Tab: multi-select  Ctrl-Y: copy  Ctrl-G/P: install global/personal  Ctrl-B: branch. '${SHELL_FZF_BACK_LABEL}' returns ${RETURN_BACK}."
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::skills::menu browse shell::prompt::skills::browse::fzf "$@"
}

# @description Pick prompts from the skills repository (Tab selects several), choose the target store (Global preselected,
#   Personal, or Back) and install them. Existing prompts are never overwritten without an explicit confirmation.
# @option -n Optional dry-run flag. The install commands are printed instead of executed.
# @option --repo <owner/repo> Optional. Another repository.
# @option --branch <name> Optional. Another branch.
# @option --refresh Optional. Ask GitHub again.
# @option -h | --help Show help and return.
# @exitcode 0 Closed with ESC.
# @exitcode 2 Invalid option.
# @exitcode 11 The user picked "← Back"; nothing was installed.
# @example
#   shell::prompt::skills::pick::fzf
#
shell::prompt::skills::pick::fzf() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Pick prompts from the skills repository and install them (global or personal)" \
			"shell::prompt::skills::pick::fzf [-n] [--repo <o/r>] [--branch <b>] [--refresh]" "shell::prompt::skills::pick::fzf" \
			"-n::Dry-run: print commands instead of executing them" "--repo <owner/repo>::Another repository" "--branch <name>::Branch to read (default master)" \
			"--refresh::Ignore the cached index" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::skills::menu pick shell::prompt::skills::pick::fzf "$@"
}

# @description View the remote prompts with a live preview: Enter opens the prompt in the pager, Ctrl-Y copies it to the
#   clipboard (nothing is installed).
# @option -n Optional dry-run flag. The copy command is printed instead of executed.
# @option --repo <owner/repo> Optional. Another repository.
# @option --branch <name> Optional. Another branch.
# @option --refresh Optional. Ask GitHub again.
# @option -h | --help Show help and return.
# @exitcode 0 Closed with ESC.
# @exitcode 2 Invalid option.
# @exitcode 11 The user picked "← Back".
# @example
#   shell::prompt::skills::view::fzf
#
shell::prompt::skills::view::fzf() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "View remote prompts with a live preview; copy to the clipboard without installing" \
			"shell::prompt::skills::view::fzf [-n] [--repo <o/r>] [--branch <b>] [--refresh]" "shell::prompt::skills::view::fzf" \
			"-n::Dry-run: print commands instead of executing them" "--repo <owner/repo>::Another repository" "--branch <name>::Branch to read (default master)" \
			"--refresh::Ignore the cached index" "-h, --help::Display this help message"
		shell::logger::note "Enter: view  Ctrl-Y: copy  Ctrl-/: preview. '${SHELL_FZF_BACK_LABEL}' returns ${RETURN_BACK}."
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::skills::menu view shell::prompt::skills::view::fzf "$@"
}

# @description List the installed prompts that have an update or a local change, with a diff preview (installed -> remote),
#   and update the selected ones. A locally modified prompt is skipped unless you confirm the overwrite (your version is kept
#   in history).
# @option -n Optional dry-run flag. The update commands are printed instead of executed.
# @option --repo <owner/repo> Optional. Another repository.
# @option --branch <name> Optional. Compare with, and switch to, this branch.
# @option --refresh Optional. Ask GitHub again.
# @option -h | --help Show help and return.
# @exitcode 0 Closed with ESC, or everything is up to date.
# @exitcode 2 Invalid option.
# @exitcode 11 The user picked "← Back"; nothing was updated.
# @example
#   shell::prompt::skills::update::fzf
#
shell::prompt::skills::update::fzf() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Update installed skills (outdated or modified) with a diff preview" \
			"shell::prompt::skills::update::fzf [-n] [--repo <o/r>] [--branch <b>] [--refresh]" "shell::prompt::skills::update::fzf" \
			"-n::Dry-run: print commands instead of executing them" "--repo <owner/repo>::Another repository" "--branch <name>::Branch to compare with" \
			"--refresh::Ignore the cached index" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::skills::menu update shell::prompt::skills::update::fzf "$@"
}

# @description List the prompts installed from skills and remove the selected ones after confirmation. Each is snapshotted
#   into history first, so `shell::prompt::restore` brings it back.
# @option -n Optional dry-run flag. The remove commands are printed instead of executed.
# @option --repo <owner/repo> Optional. Another repository.
# @option --branch <name> Optional. Another branch.
# @option --refresh Optional. Ask GitHub again.
# @option -h | --help Show help and return.
# @exitcode 0 Closed with ESC, or nothing is installed.
# @exitcode 2 Invalid option.
# @exitcode 11 The user picked "← Back"; nothing was removed.
# @example
#   shell::prompt::skills::remove::fzf
#
shell::prompt::skills::remove::fzf() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Remove prompts installed from skills (kept in history, recoverable)" \
			"shell::prompt::skills::remove::fzf [-n] [--repo <o/r>] [--branch <b>] [--refresh]" "shell::prompt::skills::remove::fzf" \
			"-n::Dry-run: print commands instead of executing them" "--repo <owner/repo>::Another repository" "--branch <name>::Branch to compare with" \
			"--refresh::Ignore the cached index" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::skills::menu remove shell::prompt::skills::remove::fzf "$@"
}

# @description Pick the branch of the skills repository for this shell session. The choice is kept in the exported variable
#   SHELL_PROMPT_SKILLS_BRANCH (no file is written); an unknown branch is rejected, never replaced silently.
# @option --repo <owner/repo> Optional. Another repository.
# @option -h | --help Show help and return.
# @exitcode 0 Switched.
# @exitcode 1 The branches could not be listed.
# @exitcode 9 Cancelled.
# @exitcode 11 The user picked "← Back"; nothing was switched.
# @example
#   shell::prompt::skills::branch::fzf
#
shell::prompt::skills::branch::fzf() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Pick the skills branch for this shell session" "shell::prompt::skills::branch::fzf [--repo <o/r>]" \
			"shell::prompt::skills::branch::fzf" "--repo <owner/repo>::Another repository" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::skills::parse "" "$@" || return $?
	shell::dependency::fzf::ensure || {
		shell::logger::error "fzf is required but could not be installed."
		return "$RETURN_NOT_FOUND"
	}
	local out rc=0
	# The switch must outlive the scoped subshell: the chosen name comes back on stdout.
	out="$(_shell::prompt::scoped _shell::prompt::skills::branch::pick)" || rc=$?
	[ "$rc" -eq 0 ] || return "$rc"
	export SHELL_PROMPT_SKILLS_BRANCH="$out"
	shell::logger::success "Branch for this session: ${out}"
}

# @internal
# @description Pick a branch and print its name (the caller exports it).
# @arg $1 string The work directory (unused).
# @stdout The branch.
# @exitcode 0 Chosen.
# @exitcode 9 Cancelled.
# @exitcode 11 The user picked "← Back".
# @example
#   branch="$(_shell::prompt::scoped _shell::prompt::skills::branch::pick)"
#
_shell::prompt::skills::branch::pick() {
	local list choice rc=0 b rows=""
	list="$(_shell::prompt::skills::tx branches)" || rc=$?
	if [ "$rc" -ne 0 ]; then
		shell::logger::error "Could not list the branches of ${_SK_REPO}." >&2
		return "$RETURN_FAILURE"
	fi
	while IFS= read -r b; do
		_shell::prompt::skills::valid_branch "$b" || continue
		if [ "$b" = "$_SK_BRANCH" ]; then rows="${rows}${b}  (current)"$'\n'; else rows="${rows}${b}"$'\n'; fi
	done <<EOF
$list
EOF
	choice="$(printf '%s%s\n' "$rows" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --prompt="Branch (${_SK_REPO}): " \
		--header="Enter: use this branch for the session   ESC: cancel" --height=40%)" || return "$RETURN_CANCELLED"
	if [ "$choice" = "$SHELL_FZF_BACK_LABEL" ] || [ -z "$choice" ]; then
		shell::logger::info "Back — nothing was switched" >&2
		return "$RETURN_BACK"
	fi
	choice="${choice%%  (current)}"
	_SK_BRANCH="$choice"
	_SK_EXPLICIT="true"
	_shell::prompt::skills::index >&2 || return $?
	printf '%s\n' "$choice"
}
