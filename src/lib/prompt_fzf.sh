#!/usr/bin/env bash
# @file lib/prompt_fzf.sh
# @brief Interactive menus of the prompt store (view, edit, search, history, tag, manage).
# @description
#   Every list and menu goes through shell::fzf::select, ends with the "← Back" row (SHELL_FZF_BACK_LABEL, exit code 11,
#   nothing mutated) and loops: list -> select -> action -> refreshed list. The list is rebuilt on every pass, so edits,
#   renames and removals show immediately, and the cursor stays on the prompt last used.
#
#   The live preview runs in a separate process where no `shell::*` function exists, so it is a POSIX `sh` script written
#   into a private work directory (removed on exit, error, Ctrl-C and kill). Keys that need the library (copy, edit, remove)
#   are returned with `--expect`; the action itself runs in the main function AFTER fzf exits, which is why copy works on
#   every pass and never depends on fzf `execute`.
#
#   List rows are `<G|L>/<slug><TAB><display>`; the scope marker [G] / [L] shows which store a prompt lives in.

# @internal
# @description Write the helper scripts of the menus (row listing and live preview) into the work directory.
#   They are plain POSIX `sh` with every path baked in: `rows.awk` and `rows.sh` (the list and the search-as-you-type
#   reload) and `preview.sh` (the live preview: title, tags, updated, description, variables, size, then the body).
#   `bat` colours the body when installed, `fold` otherwise.
# @arg $1 string The work directory.
# @arg $2 string Scope filter: `local`, `global` or empty for both.
# @arg $3 string Optional. A tag the list is limited to.
# @exitcode 0 Written.
# @example
#   _shell::prompt::preview::init "$work" "" ""
#
_shell::prompt::preview::init() {
	local work="${1-}" flag="${2-}" tag="${3-}" gdir="" ldir=""
	[ "$flag" != "local" ] && gdir="$(_shell::prompt::dir global)"
	[ "$flag" != "global" ] && ldir="$(_shell::prompt::dir local)"
	_shell::prompt::awk::rows >"$work/rows.awk"
	{
		printf 'GDIR=%s\nLDIR=%s\nWORK=%s\nTAG=%s\nBACK=%s\n' "$(_shell::conf::sq "$gdir")" "$(_shell::conf::sq "$ldir")" \
			"$(_shell::conf::sq "$work")" "$(_shell::conf::sq "$tag")" "$(_shell::conf::sq "$SHELL_FZF_BACK_LABEL")"
		cat <<'EOS'
main () {
	PROMPT_Q="$1"
	PROMPT_TAG="$TAG"
	export PROMPT_Q PROMPT_TAG
	{
		for pair in "G:$GDIR" "L:$LDIR"; do
			ch="${pair%%:*}"
			dir="${pair#*:}"
			[ -n "$dir" ] && [ -d "$dir" ] || continue
			find "$dir" -maxdepth 1 -type f -name '*.md' ! -name '.*' -exec awk -v sc="$ch" -v fmt=fzf -f "$WORK/rows.awk" {} +
		done
	} 2>/dev/null | LC_ALL=C sort
	printf '%s\t%s\n' "$BACK" "$BACK"
}
main "$@"
EOS
	} >"$work/rows.sh"
	{
		printf 'GDIR=%s\nLDIR=%s\nBACK=%s\n' "$(_shell::conf::sq "$gdir")" "$(_shell::conf::sq "$ldir")" "$(_shell::conf::sq "$SHELL_FZF_BACK_LABEL")"
		cat <<'EOS'
main () {
	mode=item
	if [ "$1" = hist ]; then
		mode=hist
		shift
	fi
	key="$1"
	stamp="$2"
	esc="$(printf '\033')"
	dim="${esc}[2m"
	rst="${esc}[0m"
	yel="${esc}[33m"
	red="${esc}[31m"
	if [ "$key" = "$BACK" ]; then
		printf '%sGo back without changing anything%s\n' "$dim" "$rst"
		return 0
	fi
	sc="${key%%/*}"
	slug="${key#*/}"
	case "$sc" in G) dir="$GDIR" ;; L) dir="$LDIR" ;; *) return 0 ;; esac
	case "$slug" in '' | -* | *[!a-z0-9-]*) return 0 ;; esac
	f="$dir/$slug.md"
	note=""
	if [ "$mode" = hist ]; then
		case "$stamp" in '' | *[!0-9TZ-]*) return 0 ;; esac
		f="$dir/.history/$slug/$stamp.md"
		note="snapshot $stamp"
	elif [ ! -f "$f" ]; then
		newest="$(ls -1 "$dir/.history/$slug" 2>/dev/null | sed -n 's/\.md$//p' | LC_ALL=C sort -r | head -n 1)"
		if [ -n "$newest" ]; then
			f="$dir/.history/$slug/$newest.md"
			note="removed - latest snapshot $newest"
		fi
	fi
	if [ ! -f "$f" ]; then
		printf '%snot found%s\n' "$red" "$rst"
		return 0
	fi
	fm() {
		awk -v k="$1" '{ sub(/\r$/, "") } NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit }
			{ i = index($0, ":"); if (i > 0 && substr($0, 1, i - 1) == k) { v = substr($0, i + 1); sub(/^[ \t]+/, "", v); print v; exit } }' "$f"
	}
	off="$(awk '{ sub(/\r$/, "") } NR == 1 { if ($0 != "---") exit; next } $0 == "---" { print NR + 1; exit }' "$f")"
	body() { if [ -n "$off" ]; then tail -n +"$off" "$f"; else cat "$f"; fi; }
	row() { printf '%s%-12s%s %s\n' "$dim" "$1" "$rst" "$2"; }
	cols="${FZF_PREVIEW_COLUMNS:-80}"
	lines="${FZF_PREVIEW_LINES:-30}"
	maxl=$((lines - 9))
	[ "$maxl" -lt 5 ] && maxl=5
	title="$(fm title)"
	printf '%s%s%s\n' "$yel" "${title:-$slug}" "$rst"
	[ -n "$note" ] && row note "$note"
	if [ "$sc" = G ]; then row scope "global  ($slug)"; else row scope "local   ($slug)"; fi
	tags="$(fm tags)"
	row tags "${tags:--}"
	row updated "$(fm updated)"
	d="$(fm description)"
	[ -n "$d" ] && row description "$d"
	vars="$(body | grep -o '{{[^{}]*}}' | sed 's/^{{//; s/}}$//; s/|.*//; s/^ *//; s/ *$//' | awk '!s[$0]++' | paste -s -d, - | sed 's/,/, /g')"
	row variables "${vars:-none}"
	row size "$(body | wc -m | tr -d ' ') chars, $(body | wc -l | tr -d ' ') lines"
	if [ "$mode" = hist ] && [ -f "$dir/$slug.md" ]; then
		printf '%s----- current -> this snapshot -----%s\n' "$dim" "$rst"
		diff -u "$dir/$slug.md" "$f" | sed '1,2d' | head -n "$maxl" | awk -v e="$esc" '
			/^\+/ { printf "%s[32m%s%s[0m\n", e, $0, e; next }
			/^-/ { printf "%s[31m%s%s[0m\n", e, $0, e; next }
			{ print }'
		return 0
	fi
	printf '%s----------------------------------------%s\n' "$dim" "$rst"
	if command -v bat >/dev/null 2>&1; then
		body | bat --style=plain --color=always --language=markdown --wrap=character --terminal-width="$cols" --paging=never 2>/dev/null | head -n "$maxl"
	else
		body | fold -s -w "$cols" | head -n "$maxl"
	fi
}
main "$@"
EOS
	} >"$work/preview.sh"
}

# @internal
# @description Show prompt rows with the live preview and a trailing "← Back" row, through shell::fzf::select.
#   `--expect` keys are returned on the first output line, so the caller runs the action after fzf exits.
# @arg $1 string The work directory (holds preview.sh and rows.sh).
# @arg $2 string The rows (`<G|L>/<slug><TAB><display>`, without the Back row).
# @arg $3 string The prompt.
# @arg $4 string The header (key hints).
# @arg $5 string The key to put the cursor on (may be empty).
# @arg $6 string Optional. Comma-separated `--expect` keys.
# @arg $@ string Optional. Extra fzf arguments.
# @stdout Two lines: the key pressed (empty for Enter) and the selected row; the Back row has the label as its key.
# @exitcode 0 Something was selected.
# @exitcode 9 Cancelled (ESC / Ctrl-C).
# @example
#   out="$(_shell::prompt::pick "$work" "$rows" "Prompt: " "Enter: actions" "$last" "ctrl-y")" || return
#
_shell::prompt::pick() {
	local work="${1-}" rows="${2-}" prompt="${3-}" header="${4-}" initial="${5-}" expect="${6-}" out
	shift 6
	local -a init=() exp=()
	[ -n "$initial" ] && init=(--initial "$initial" --initial-field 1)
	[ -n "$expect" ] && exp=("--expect=${expect}")
	out="$(printf '%s\n%s\t%s\n' "$rows" "$SHELL_FZF_BACK_LABEL" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select ${init[@]+"${init[@]}"} \
		--delimiter=$'\t' --with-nth=2 --prompt="$prompt" --header="$header" \
		--preview="sh $(_shell::conf::sq "$work/preview.sh") {1}" --preview-window="right:55%:wrap" \
		--height=70% --bind=ctrl-/:toggle-preview ${exp[@]+"${exp[@]}"} "$@")" || return $?
	# With --expect fzf prints the key first (empty for Enter); a plain pick has no key line.
	case "$out" in
	*$'\n'*) ;;
	*) out=$'\n'"$out" ;;
	esac
	printf '%s\n' "$out"
}

# @internal
# @description Pick one prompt from a list (no actions). Used by the hub for Export.
# @arg $1 string The work directory.
# @arg $2 string Scope filter.
# @arg $3 string The prompt text.
# @stdout `scope<TAB>slug` (scope is `global` or `local`).
# @exitcode 0 Picked.
# @exitcode 3 No prompt exists.
# @exitcode 9 Cancelled.
# @exitcode 11 The user picked "← Back".
# @example
#   pick="$(_shell::prompt::choose "$work" "" "Export: ")" || return
#
_shell::prompt::choose() {
	local work="${1-}" flag="${2-}" prompt="${3-}" rows out row ckey
	_shell::prompt::preview::init "$work" "$flag" ""
	rows="$(_shell::prompt::rows "$flag" fzf "" "")"
	if [ -z "$rows" ]; then
		shell::logger::warn "No prompt yet."
		return "$RETURN_NOT_FOUND"
	fi
	out="$(_shell::prompt::pick "$work" "$rows" "$prompt" "Enter: select   ESC: leave" "" "")" || return $?
	row="${out#*$'\n'}"
	ckey="${row%%$'\t'*}"
	[ "$ckey" = "$SHELL_FZF_BACK_LABEL" ] && return "$RETURN_BACK"
	if [ "${ckey%%/*}" = "L" ]; then
		printf 'local\t%s\n' "${ckey#*/}"
	else
		printf 'global\t%s\n' "${ckey#*/}"
	fi
}

# @internal
# @description Edit a prompt in the editor: snapshot, edit a temp copy, validate, atomic replace.
#   No change writes nothing. A validation failure offers to re-open the editor or to discard (nothing is written
#   either way). `updated:` is refreshed, `created:` kept; the slug never changes (use rename for that).
# @arg $1 string The work directory.
# @arg $2 string The scope.
# @arg $3 string The slug.
# @arg $4 string `true` for dry-run (the editor is not opened).
# @exitcode 0 Saved, unchanged, discarded or dry-run.
# @exitcode 1 The editor or the write failed.
# @example
#   _shell::prompt::scoped _shell::prompt::edit::inner global code-review false
#
_shell::prompt::edit::inner() {
	local work="${1-}" scope="${2-}" slug="${3-}" dry_run="${4-false}" file tmp choice created
	file="$(_shell::prompt::file "$scope" "$slug")"
	tmp="$work/edit.md"
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "${VISUAL:-${EDITOR:-vi}} $(printf '%q' "$file")   # then snapshot + atomic replace"
		return "$RETURN_SUCCESS"
	fi
	(umask 077 && cp -- "$file" "$tmp") || return "$RETURN_FAILURE"
	while :; do
		_shell::prompt::editor "$tmp" || {
			shell::logger::error "The editor failed; nothing was saved."
			return "$RETURN_FAILURE"
		}
		if cmp -s "$file" "$tmp"; then
			shell::logger::info "No changes - nothing was written"
			return "$RETURN_SUCCESS"
		fi
		_shell::prompt::validate "$tmp" && break
		choice="$(printf 'Re-open the editor\nDiscard my changes\n%s\n' "$SHELL_FZF_BACK_LABEL" |
			shell::fzf::select --prompt="Invalid prompt: " --header="Fix it, or leave without saving" --height=30%)" || choice="Discard"
		if [ "$choice" != "Re-open the editor" ]; then
			shell::logger::info "Discarded - nothing was written"
			return "$RETURN_SUCCESS"
		fi
	done
	created="$(_shell::prompt::meta "$tmp" created)"
	[ -n "$created" ] || created="$(_shell::prompt::meta "$file" created)"
	_shell::prompt::body_stream "$tmp" >"$work/body" || return "$RETURN_FAILURE"
	_shell::prompt::snapshot "$scope" "$slug" "$file" >/dev/null || {
		shell::logger::error "Could not snapshot '${slug}'; nothing was saved."
		return "$RETURN_FAILURE"
	}
	_shell::prompt::write "$file" "$(_shell::prompt::meta "$tmp" title)" "$(_shell::prompt::meta "$tmp" description)" \
		"$(_shell::prompt::norm_tags "$(_shell::prompt::meta "$tmp" tags)")" "$created" "$(_shell::prompt::now)" "$work/body" || {
		shell::logger::error "Could not write '${slug}'."
		return "$RETURN_FAILURE"
	}
	shell::logger::success "Saved prompt '${slug}'"
}

# @internal
# @description Copy a prompt body, raw (placeholders untouched).
# @arg $1 string The work directory.
# @arg $2 string The scope.
# @arg $3 string The slug.
# @arg $4 string `true` for dry-run.
# @exitcode 0 Always (the outcome is logged).
# @example
#   _shell::prompt::do::copy "$work" global code-review false
#
_shell::prompt::do::copy() {
	local work="${1-}" scope="${2-}" slug="${3-}" dry_run="${4-false}" file title
	file="$(_shell::prompt::file "$scope" "$slug")"
	title="$(_shell::prompt::meta "$file" title)"
	_shell::prompt::body_stream "$file" >"$work/copy.txt" || {
		shell::logger::error "Prompt '${slug}' has no valid front matter."
		return "$RETURN_SUCCESS"
	}
	_shell::prompt::copy_file "${title:-$slug}" "$work/copy.txt" "$dry_run" || true
	return "$RETURN_SUCCESS"
}

# @internal
# @description Fill the placeholders (each asked with its default), show the final text and copy it on confirmation.
#   Cancel, Back or ESC copy nothing.
# @arg $1 string The work directory.
# @arg $2 string The scope.
# @arg $3 string The slug.
# @arg $4 string `true` for dry-run.
# @exitcode 0 Always (the outcome is logged).
# @example
#   _shell::prompt::do::copy_rendered "$work" global summary false
#
_shell::prompt::do::copy_rendered() {
	local work="${1-}" scope="${2-}" slug="${3-}" dry_run="${4-false}" file title rc=0 vars choice
	file="$(_shell::prompt::file "$scope" "$slug")"
	title="$(_shell::prompt::meta "$file" title)"
	vars="$(_shell::prompt::body_stream "$file" | _shell::prompt::vars)"
	if [ -z "$vars" ]; then
		shell::logger::info "No {{placeholders}} in '${slug}' - copying the prompt as it is"
		_shell::prompt::do::copy "$work" "$scope" "$slug" "$dry_run"
		return "$RETURN_SUCCESS"
	fi
	_shell::prompt::render::file "$file" "$work/rendered" true || rc=$?
	if [ "$rc" -ne 0 ]; then
		shell::logger::info "Cancelled - nothing was copied"
		return "$RETURN_SUCCESS"
	fi
	choice="$(printf 'Copy to clipboard\n%s\n' "$SHELL_FZF_BACK_LABEL" | shell::fzf::select \
		--prompt="Rendered: " --header="Enter: copy   ${SHELL_FZF_BACK_LABEL}/ESC: cancel" \
		--preview="head -c 20000 $(_shell::conf::sq "$work/rendered")" --preview-window="top:75%:wrap" --height=85%)" || choice=""
	if [ "$choice" != "Copy to clipboard" ]; then
		shell::logger::info "Cancelled - nothing was copied"
		return "$RETURN_SUCCESS"
	fi
	_shell::prompt::copy_file "${title:-$slug}" "$work/rendered" "$dry_run" || true
	return "$RETURN_SUCCESS"
}

# @internal
# @description Show a file in $PAGER (default `less`), falling back to `cat`.
# @arg $1 string The file.
# @exitcode 0 Always.
# @example
#   _shell::prompt::pager "$work/body.txt"
#
_shell::prompt::pager() {
	local pager="${PAGER:-less}"
	if command -v "${pager%% *}" >/dev/null 2>&1; then
		sh -c "$pager \"\$1\"" sh "${1-}" || true
	else
		cat -- "${1-}"
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Add or remove tags through a small menu.
# @arg $1 string The work directory.
# @arg $2 string The scope.
# @arg $3 string The slug.
# @arg $4 string `true` for dry-run.
# @exitcode 0 Always.
# @example
#   _shell::prompt::do::tags "$work" global code-review false
#
_shell::prompt::do::tags() {
	local work="${1-}" scope="${2-}" slug="${3-}" dry_run="${4-false}" file tags action answer picked t
	file="$(_shell::prompt::file "$scope" "$slug")"
	tags="$(_shell::prompt::meta "$file" tags)"
	action="$(printf 'Add tags\nRemove tags\n%s\n' "$SHELL_FZF_BACK_LABEL" | shell::fzf::select \
		--prompt="Tags: " --header="Tags of ${slug}: ${tags:--}" --height=30%)" || return "$RETURN_SUCCESS"
	case "$action" in
	"Add tags")
		answer="$(_shell::ask::read_line "t" "Tags to add (comma or space separated, empty = cancel):")" || return "$RETURN_SUCCESS"
		[ -n "$answer" ] || return "$RETURN_SUCCESS"
		_shell::prompt::tags::change "$scope" "$slug" add "$dry_run" "$answer" || true
		;;
	"Remove tags")
		if [ -z "$tags" ]; then
			shell::logger::info "'${slug}' has no tags"
			return "$RETURN_SUCCESS"
		fi
		picked="$(printf '%s\n%s\n' "$(printf '%s' "$tags" | tr ',' '\n')" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --multi \
			--prompt="Remove: " --header="TAB: mark   Enter: remove   ${SHELL_FZF_BACK_LABEL}: cancel" --height=40%)" || return "$RETURN_SUCCESS"
		case "$picked" in *"$SHELL_FZF_BACK_LABEL"*) return "$RETURN_SUCCESS" ;; esac
		answer=""
		while IFS= read -r t; do answer="${answer:+$answer,}$t"; done <<EOF
$picked
EOF
		_shell::prompt::tags::change "$scope" "$slug" remove "$dry_run" "$answer" || true
		;;
	esac
	return "$RETURN_SUCCESS"
}

# @internal
# @description The history menu of one prompt: snapshots with a diff preview, then Restore or View. Loops back to the
#   refreshed snapshot list; Back / ESC return to the caller.
# @arg $1 string The work directory.
# @arg $2 string The scope.
# @arg $3 string The slug.
# @arg $4 string `true` for dry-run.
# @exitcode 0 Always.
# @example
#   _shell::prompt::history::menu "$work" global code-review false
#
_shell::prompt::history::menu() {
	local work="${1-}" scope="${2-}" slug="${3-}" dry_run="${4-false}" ch="G" dir stamps rows stamp f out sel act initial=""
	dir="$(_shell::prompt::dir "$scope")"
	[ "$scope" = "local" ] && ch="L"
	while true; do
		stamps="$(_shell::prompt::stamps "$scope" "$slug")"
		if [ -z "$stamps" ]; then
			shell::logger::info "No history for '${slug}' yet"
			return "$RETURN_SUCCESS"
		fi
		rows=""
		while IFS= read -r stamp; do
			f="$dir/.history/$slug/$stamp.md"
			rows="${rows}${stamp}"$'\t'"$(printf '%-24s %8s B  %s' "$stamp" "$(wc -c <"$f" | tr -d ' ')" "$(_shell::prompt::meta "$f" title)")"$'\n'
		done <<EOF
$stamps
EOF
		rows="${rows%$'\n'}"
		local -a init=()
		[ -n "$initial" ] && init=(--initial "$initial" --initial-field 1)
		out="$(printf '%s\n%s\t%s\n' "$rows" "$SHELL_FZF_BACK_LABEL" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select ${init[@]+"${init[@]}"} \
			--delimiter=$'\t' --with-nth=2 --prompt="History ${slug}: " \
			--header="Enter: restore / view   ESC: leave   (${SHELL_FZF_BACK_LABEL}: previous)" \
			--preview="sh $(_shell::conf::sq "$work/preview.sh") hist ${ch}/${slug} {1}" --preview-window="right:60%:wrap" --height=70%)" || return "$RETURN_SUCCESS"
		sel="${out%%$'\t'*}"
		[ "$sel" = "$SHELL_FZF_BACK_LABEL" ] && return "$RETURN_SUCCESS"
		initial="$sel"
		act="$(printf 'Restore this version\nView this version\n%s\n' "$SHELL_FZF_BACK_LABEL" | shell::fzf::select \
			--prompt="Snapshot ${sel}: " --height=30%)" || continue
		case "$act" in
		"Restore this version")
			if [ "$dry_run" = "true" ] || shell::ask::accept "Restore '${slug}' from ${sel}? The current version is snapshotted first"; then
				_shell::prompt::restore::do "$scope" "$slug" "$sel" "$dry_run" || true
			else
				shell::logger::info "Cancelled - nothing was restored"
			fi
			;;
		"View this version")
			_shell::prompt::body_stream "$dir/.history/$slug/$sel.md" >"$work/view.txt" && _shell::prompt::pager "$work/view.txt"
			;;
		esac
	done
}

# @internal
# @description The action menu of a prompt (Enter on the list): Copy, Copy rendered, Edit, Open pager, Tags, History, Remove, Back.
# @arg $1 string The work directory.
# @arg $2 string The scope.
# @arg $3 string The slug.
# @arg $4 string `true` for dry-run.
# @exitcode 0 Always (Back and ESC just return to the list).
# @example
#   _shell::prompt::actions "$work" global code-review false
#
_shell::prompt::actions() {
	local work="${1-}" scope="${2-}" slug="${3-}" dry_run="${4-false}" ch="G" action
	[ "$scope" = "local" ] && ch="L"
	action="$(printf 'Copy\nCopy rendered\nEdit\nOpen pager\nTags\nHistory\nRemove\n%s\n' "$SHELL_FZF_BACK_LABEL" | shell::fzf::select \
		--prompt="Action: " --header="Prompt ${slug}   Enter: run   ESC: back" \
		--preview="sh $(_shell::conf::sq "$work/preview.sh") ${ch}/${slug}" --preview-window="right:55%:wrap" --height=70%)" || return "$RETURN_SUCCESS"
	case "$action" in
	"Copy") _shell::prompt::do::copy "$work" "$scope" "$slug" "$dry_run" ;;
	"Copy rendered") _shell::prompt::do::copy_rendered "$work" "$scope" "$slug" "$dry_run" ;;
	"Edit") _shell::prompt::edit::inner "$work" "$scope" "$slug" "$dry_run" || true ;;
	"Open pager")
		_shell::prompt::body_stream "$(_shell::prompt::file "$scope" "$slug")" >"$work/view.txt" && _shell::prompt::pager "$work/view.txt"
		;;
	"Tags") _shell::prompt::do::tags "$work" "$scope" "$slug" "$dry_run" ;;
	"History") _shell::prompt::history::menu "$work" "$scope" "$slug" "$dry_run" ;;
	"Remove") _shell::prompt::remove::do "$scope" "$slug" "$dry_run" false || true ;;
	esac
	return "$RETURN_SUCCESS"
}

# @internal
# @description Ask for a new slug and clone or rename a prompt (an empty answer cancels).
# @arg $1 string The work directory.
# @arg $2 string `clone` or `rename`.
# @arg $3 string The scope.
# @arg $4 string The slug.
# @arg $5 string `true` for dry-run.
# @exitcode 0 Always (the outcome is logged).
# @example
#   _shell::prompt::do::name "$work" clone global code-review false
#
_shell::prompt::do::name() {
	local work="${1-}" op="${2-}" scope="${3-}" slug="${4-}" dry_run="${5-false}" new
	new="$(_shell::ask::read_line "n" "New slug to ${op} '${slug}' to (empty = cancel):")" || return "$RETURN_SUCCESS"
	if [ -z "$new" ]; then
		shell::logger::info "Cancelled"
		return "$RETURN_SUCCESS"
	fi
	if [ "$op" = "clone" ]; then
		_shell::prompt::clone::inner "$work" "$scope" "$slug" "$new" "$dry_run" || true
	else
		_shell::prompt::rename::do "$scope" "$slug" "$new" "$dry_run" || true
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Interactively add a prompt: title, tags, then the source (editor, clipboard, terminal paste or file).
# @arg $1 string The work directory.
# @arg $2 string `true` for dry-run.
# @arg $3 string Scope filter (`local` forces the project store).
# @exitcode 0 Always (the outcome is logged; Back and empty answers cancel).
# @example
#   _shell::prompt::add::interactive "$work" false ""
#
_shell::prompt::add::interactive() {
	local work="${1-}" dry_run="${2-false}" flag="${3-}" title tags scope="global" src choice file
	title="$(_shell::ask::read_line "t" "Title of the new prompt (empty = cancel):")" || return "$RETURN_SUCCESS"
	if [ -z "$title" ]; then
		shell::logger::info "Cancelled - nothing was added"
		return "$RETURN_SUCCESS"
	fi
	if [ "$flag" = "local" ]; then
		scope="local"
	elif [ "$flag" != "global" ] && [ -d "$(_shell::prompt::dir local)" ]; then
		choice="$(printf 'Global store\nLocal store (./%s)\n%s\n' "$SHELL_PROMPT_LOCAL_NAME" "$SHELL_FZF_BACK_LABEL" |
			shell::fzf::select --prompt="Store: " --height=30%)" || return "$RETURN_SUCCESS"
		case "$choice" in
		"Global store") scope="global" ;;
		Local*) scope="local" ;;
		*)
			shell::logger::info "Back - nothing was added"
			return "$RETURN_SUCCESS"
			;;
		esac
	fi
	tags="$(_shell::ask::read_line "g" "Tags (optional, comma separated):")" || return "$RETURN_SUCCESS"
	choice="$(printf 'Editor\nClipboard\nPaste here (finish with Ctrl-D)\nFile\n%s\n' "$SHELL_FZF_BACK_LABEL" |
		shell::fzf::select --prompt="Body from: " --height=35%)" || return "$RETURN_SUCCESS"
	case "$choice" in
	Editor) src="" ;;
	Clipboard) src="clipboard" ;;
	Paste*)
		src="-"
		shell::logger::info "Paste the prompt, then press Ctrl-D on an empty line."
		;;
	File)
		file="$(_shell::ask::read_line "f" "File path (empty = cancel):")" || return "$RETURN_SUCCESS"
		[ -n "$file" ] || return "$RETURN_SUCCESS"
		src="$file"
		;;
	*)
		shell::logger::info "Back - nothing was added"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::add::inner "$work" "$dry_run" "$scope" "$title" "" "$tags" "$src" || true
	return "$RETURN_SUCCESS"
}

# @internal
# @description Rows of the prompts that have history (live or removed): `<G|L>/<slug><TAB><display>`.
# @arg $1 string Scope filter.
# @stdout The rows.
# @exitcode 0 Always.
# @example
#   rows="$(_shell::prompt::history::rows "")"
#
_shell::prompt::history::rows() {
	local sc dir ch d slug n state title f
	while IFS= read -r sc; do
		dir="$(_shell::prompt::dir "$sc")"
		[ -d "$dir/.history" ] || continue
		ch="G"
		[ "$sc" = "local" ] && ch="L"
		for d in "$dir"/.history/*; do
			[ -d "$d" ] || continue
			slug="${d##*/}"
			_shell::prompt::valid_slug "$slug" || continue
			n="$(_shell::prompt::stamps "$sc" "$slug" | wc -l | tr -d ' ')"
			[ "$n" -gt 0 ] || continue
			state="live"
			f="$dir/$slug.md"
			if [ ! -f "$f" ]; then
				state="removed"
				f="$d/$(_shell::prompt::stamps "$sc" "$slug" | head -n 1).md"
			fi
			title="$(_shell::prompt::meta "$f" title)"
			printf '%s/%s\t[%s] %-26s %-34s %3s snapshots  %s\n' "$ch" "$slug" "$ch" "$slug" "$title" "$n" "$state"
		done
	done <<EOF
$(_shell::prompt::scopes "$1")
EOF
}

# @internal
# @description The list loop shared by every menu: list -> select -> action -> refreshed list.
#   Kinds: `view`, `search`, `tag` (Enter opens the action menu; Ctrl-Y/R/E/D act at once), `edit`, `copy`, `clone`,
#   `rename`, `remove` (Enter runs that action) and `history`. An empty store offers "Create your first prompt".
# @arg $1 string The work directory.
# @arg $2 string The kind.
# @arg $3 string `true` for dry-run.
# @arg $4 string Scope filter.
# @arg $5 string Optional. A tag the list is limited to.
# @exitcode 0 Closed (ESC / Ctrl-C).
# @exitcode 11 The user picked "← Back".
# @example
#   _shell::prompt::loop "$work" view false "" ""
#
_shell::prompt::loop() {
	local work="${1-}" kind="${2-view}" dry_run="${3-false}" flag="${4-}" tag="${5-}"
	local back="$SHELL_FZF_BACK_LABEL" rows out key row ckey scope slug initial="" header expect="" prompt rc choice
	local -a extra=()
	case "$kind" in
	view | search | tag)
		expect="ctrl-y,ctrl-r,ctrl-e,ctrl-d"
		header="Enter: actions   ESC: leave   ^/: preview"$'\n'"^Y copy   ^R rendered   ^E edit   ^D remove"
		;;
	history) header="Enter: history   ESC: leave   ^/: preview" ;;
	*) header="Enter: ${kind}   ESC: leave   ^/: preview" ;;
	esac
	prompt="Prompt: "
	[ "$kind" = "search" ] && prompt="Search: " && header="Type to search title, tags and body"$'\n'"${header}"
	[ -n "$tag" ] && prompt="Tag ${tag}: "
	_shell::prompt::preview::init "$work" "$flag" "$tag"
	while true; do
		if [ "$kind" = "history" ]; then
			rows="$(_shell::prompt::history::rows "$flag")"
		else
			rows="$(_shell::prompt::rows "$flag" fzf "" "$tag")"
		fi
		if [ -z "$rows" ]; then
			if [ -n "$tag" ]; then
				shell::logger::info "No prompt tagged '${tag}'"
				return "$RETURN_BACK"
			fi
			if [ "$kind" = "history" ]; then
				shell::logger::info "No history yet - snapshots appear after an edit, overwrite or removal"
				return "$RETURN_BACK"
			fi
			choice="$(printf 'Create your first prompt\n%s\n' "$back" | shell::fzf::select --prompt="No prompts yet: " \
				--header="The store is empty" --height=25%)" || {
				shell::logger::info "Closed"
				return "$RETURN_SUCCESS"
			}
			if [ "$choice" = "$back" ] || [ -z "$choice" ]; then
				shell::logger::info "Back"
				return "$RETURN_BACK"
			fi
			_shell::prompt::add::interactive "$work" "$dry_run" "$flag"
			[ "$dry_run" = "true" ] && return "$RETURN_SUCCESS"
			continue
		fi
		extra=()
		if [ "$kind" = "search" ]; then
			extra=(--disabled "--bind=change:reload:sh $(_shell::conf::sq "$work/rows.sh") {q} || true")
		fi
		rc=0
		out="$(_shell::prompt::pick "$work" "$rows" "$prompt" "$header" "$initial" "$expect" ${extra[@]+"${extra[@]}"})" || rc=$?
		if [ "$rc" -ne 0 ]; then
			shell::logger::info "Closed"
			return "$RETURN_SUCCESS"
		fi
		key="${out%%$'\n'*}"
		row="${out#*$'\n'}"
		ckey="${row%%$'\t'*}"
		if [ "$ckey" = "$back" ]; then
			shell::logger::info "Back"
			return "$RETURN_BACK"
		fi
		[ -n "$ckey" ] || continue
		initial="$ckey"
		scope="global"
		[ "${ckey%%/*}" = "L" ] && scope="local"
		slug="${ckey#*/}"
		_shell::prompt::valid_slug "$slug" || {
			shell::logger::error "Skipping '${slug}': not a valid slug (rename the file in the store)."
			continue
		}
		case "$key" in
		ctrl-y) _shell::prompt::do::copy "$work" "$scope" "$slug" "$dry_run" ;;
		ctrl-r) _shell::prompt::do::copy_rendered "$work" "$scope" "$slug" "$dry_run" ;;
		ctrl-e) _shell::prompt::edit::inner "$work" "$scope" "$slug" "$dry_run" || true ;;
		ctrl-d) _shell::prompt::remove::do "$scope" "$slug" "$dry_run" false || true ;;
		*)
			case "$kind" in
			view | search | tag) _shell::prompt::actions "$work" "$scope" "$slug" "$dry_run" ;;
			edit) _shell::prompt::edit::inner "$work" "$scope" "$slug" "$dry_run" || true ;;
			copy) _shell::prompt::do::copy "$work" "$scope" "$slug" "$dry_run" ;;
			clone | rename) _shell::prompt::do::name "$work" "$kind" "$scope" "$slug" "$dry_run" ;;
			remove) _shell::prompt::remove::do "$scope" "$slug" "$dry_run" false || true ;;
			history) _shell::prompt::history::menu "$work" "$scope" "$slug" "$dry_run" ;;
			esac
			;;
		esac
	done
}

# @internal
# @description Parse the options shared by the ::fzf functions and run a menu in a scoped work directory.
# @arg $1 string The kind (see _shell::prompt::loop).
# @arg $2 string The function name (for the usage message).
# @arg $@ string The user's arguments (`-n`, `--local`, `--global`).
# @exitcode 0 Closed.
# @exitcode 2 Invalid option.
# @exitcode 3 fzf is missing.
# @exitcode 11 The user picked "← Back".
# @example
#   _shell::prompt::menu view shell::prompt::view::fzf "$@"
#
_shell::prompt::menu() {
	local kind="${1-view}" fn="${2-}" dry_run="false" flag=""
	shift 2
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n) dry_run="true" ;;
		--local) flag="local" ;;
		--global) flag="global" ;;
		*)
			shell::logger::error "Unknown argument: $1 (usage: ${fn} [-n] [--local|--global])"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done
	shell::dependency::fzf::ensure || {
		shell::logger::error "fzf is required but could not be installed."
		return "$RETURN_NOT_FOUND"
	}
	if [ "$kind" = "hub" ]; then
		_shell::prompt::scoped _shell::prompt::hub "$dry_run" "$flag"
	else
		_shell::prompt::scoped _shell::prompt::loop "$kind" "$dry_run" "$flag" ""
	fi
}

# @description Browse prompts with a live preview, then act on one: Copy, Copy rendered, Edit, Open pager, Tags, History, Remove, Back.
#
#   The preview shows the title, tags, update time, description, the `{{variables}}` found, the size and the body.
#   Shortcuts on the list: Enter = action menu, Ctrl-Y = copy, Ctrl-R = copy rendered, Ctrl-E = edit, Ctrl-D = remove,
#   Ctrl-/ = toggle the preview. The list comes back after every action (rebuilt, cursor kept). Copying is done by the
#   function itself on every pass, byte for byte; without a clipboard tool the text is printed with a warning.
#   An empty store offers "Create your first prompt". `[G]` / `[L]` marks the global / project store.
# @option -n Optional dry-run flag. Copy and write commands are printed instead of executed.
# @option --local Optional. Only the project store.
# @option --global Optional. Only the global store.
# @option -h | --help Show help and return.
# @exitcode 0 Closed with ESC.
# @exitcode 2 Invalid option.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::prompt::view::fzf
#   shell::prompt::view::fzf -n --global
#
shell::prompt::view::fzf() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Browse prompts with a live preview; copy, edit, tag, restore or remove" "shell::prompt::view::fzf [-n] [--local|--global]" \
			"shell::prompt::view::fzf" "-n::Dry-run: print commands instead of executing them" "--local::Only the project store" \
			"--global::Only the global store" "-h, --help::Display this help message"
		shell::logger::note "Enter: actions  Ctrl-Y: copy  Ctrl-R: rendered  Ctrl-E: edit  Ctrl-D: remove  Ctrl-/: preview. '${SHELL_FZF_BACK_LABEL}' returns ${RETURN_BACK}."
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::menu view shell::prompt::view::fzf "$@"
}

# @description Pick a prompt and edit it in your editor ($VISUAL / $EDITOR), then return to the refreshed list.
#   Flow: snapshot -> edit a temp copy -> validate (front matter, title, non-empty body) -> refresh `updated:` ->
#   atomic replace. No change writes nothing; an invalid file offers "re-open the editor" or "discard".
# @option -n Optional dry-run flag. The editor is not opened and nothing is written.
# @option --local Optional. Only the project store.
# @option --global Optional. Only the global store.
# @option -h | --help Show help and return.
# @exitcode 0 Closed with ESC.
# @exitcode 2 Invalid option.
# @exitcode 11 The user picked "← Back".
# @example
#   shell::prompt::edit::fzf
#
shell::prompt::edit::fzf() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Pick a prompt and edit it in your editor (snapshot, validate, atomic save)" "shell::prompt::edit::fzf [-n] [--local|--global]" \
			"shell::prompt::edit::fzf" "-n::Dry-run: print commands instead of executing them" "--local::Only the project store" \
			"--global::Only the global store" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::menu edit shell::prompt::edit::fzf "$@"
}

# @description Fuzzy-search prompts as you type, including their body (title, description, tags and body words, all of
#   which must match), with the live preview and the same actions as shell::prompt::view::fzf.
# @option -n Optional dry-run flag. Copy and write commands are printed instead of executed.
# @option --local Optional. Only the project store.
# @option --global Optional. Only the global store.
# @option -h | --help Show help and return.
# @exitcode 0 Closed with ESC.
# @exitcode 2 Invalid option.
# @exitcode 11 The user picked "← Back".
# @example
#   shell::prompt::search::fzf
#
shell::prompt::search::fzf() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Search prompts as you type, including their body" "shell::prompt::search::fzf [-n] [--local|--global]" \
			"shell::prompt::search::fzf" "-n::Dry-run: print commands instead of executing them" "--local::Only the project store" \
			"--global::Only the global store" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::menu search shell::prompt::search::fzf "$@"
}

# @description Browse the history of a prompt (live or removed): snapshots with a coloured diff against the current version, then Restore or View.
# @option -n Optional dry-run flag. Restore commands are printed instead of executed.
# @option --local Optional. Only the project store.
# @option --global Optional. Only the global store.
# @option -h | --help Show help and return.
# @exitcode 0 Closed with ESC.
# @exitcode 2 Invalid option.
# @exitcode 11 The user picked "← Back".
# @example
#   shell::prompt::history::fzf
#
shell::prompt::history::fzf() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Browse snapshots of a prompt with a diff preview and restore one" "shell::prompt::history::fzf [-n] [--local|--global]" \
			"shell::prompt::history::fzf" "-n::Dry-run: print commands instead of executing them" "--local::Only the project store" \
			"--global::Only the global store" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::menu history shell::prompt::history::fzf "$@"
}

# @internal
# @description The tag chooser: pick a tag, browse its prompts (view actions), come back to the tags.
# @arg $1 string The work directory.
# @arg $2 string `true` for dry-run.
# @arg $3 string Scope filter.
# @exitcode 0 Closed.
# @exitcode 11 Back.
# @example
#   _shell::prompt::tag::loop "$work" false ""
#
_shell::prompt::tag::loop() {
	local work="${1-}" dry_run="${2-false}" flag="${3-}" counts rows sel tag rc initial=""
	while true; do
		counts="$(_shell::prompt::rows "$flag" tsv "" "" | awk -F'\t' '
			{ n = split($4, a, ","); for (i = 1; i <= n; i++) if (a[i] != "") c[a[i]]++ }
			END { for (t in c) printf "%s (%d)\n", t, c[t] }' | LC_ALL=C sort)"
		if [ -z "$counts" ]; then
			shell::logger::info "No tags yet - add some with shell::prompt::tag::add or the Tags action"
			return "$RETURN_BACK"
		fi
		local -a init=()
		[ -n "$initial" ] && init=(--initial "$initial")
		sel="$(printf '%s\n%s\n' "$counts" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select ${init[@]+"${init[@]}"} \
			--prompt="Tag: " --header="Enter: browse   ESC: leave   (${SHELL_FZF_BACK_LABEL}: previous)" --height=40%)" || {
			shell::logger::info "Closed"
			return "$RETURN_SUCCESS"
		}
		if [ "$sel" = "$SHELL_FZF_BACK_LABEL" ]; then
			shell::logger::info "Back"
			return "$RETURN_BACK"
		fi
		initial="$sel"
		tag="${sel% \(*}"
		rc=0
		_shell::prompt::loop "$work" tag "$dry_run" "$flag" "$tag" || rc=$?
		[ "$rc" -eq "$RETURN_BACK" ] || return "$rc"
	done
}

# @description Filter prompts by tag: pick a tag (with counts), browse its prompts with the live preview and the view actions, come back to the tags.
# @option -n Optional dry-run flag. Copy and write commands are printed instead of executed.
# @option --local Optional. Only the project store.
# @option --global Optional. Only the global store.
# @option -h | --help Show help and return.
# @exitcode 0 Closed with ESC.
# @exitcode 2 Invalid option.
# @exitcode 11 The user picked "← Back".
# @example
#   shell::prompt::tag::fzf
#
shell::prompt::tag::fzf() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Pick a tag, then browse the prompts that carry it" "shell::prompt::tag::fzf [-n] [--local|--global]" \
			"shell::prompt::tag::fzf" "-n::Dry-run: print commands instead of executing them" "--local::Only the project store" \
			"--global::Only the global store" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local dry_run="false" flag=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n) dry_run="true" ;;
		--local) flag="local" ;;
		--global) flag="global" ;;
		*)
			shell::logger::error "Unknown argument: $1 (usage: shell::prompt::tag::fzf [-n] [--local|--global])"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done
	shell::dependency::fzf::ensure || {
		shell::logger::error "fzf is required but could not be installed."
		return "$RETURN_NOT_FOUND"
	}
	_shell::prompt::scoped _shell::prompt::tag::loop "$dry_run" "$flag"
}

# @internal
# @description Interactive export: all prompts as a .tar.gz, or one prompt chosen from the list.
# @arg $1 string The work directory.
# @arg $2 string `true` for dry-run.
# @arg $3 string Scope filter.
# @exitcode 0 Always (the outcome is logged).
# @example
#   _shell::prompt::export::interactive "$work" false ""
#
_shell::prompt::export::interactive() {
	local work="${1-}" dry_run="${2-false}" flag="${3-}" choice picked scope slug dest rc=0
	local -a n=()
	[ "$dry_run" = "true" ] && n=(-n)
	choice="$(printf 'All prompts (.tar.gz)\nOne prompt (.md)\n%s\n' "$SHELL_FZF_BACK_LABEL" | shell::fzf::select \
		--prompt="Export: " --height=30%)" || return "$RETURN_SUCCESS"
	case "$choice" in
	"All prompts"*)
		dest="$(_shell::ask::read_line "d" "Destination file or directory (empty = cancel):")" || return "$RETURN_SUCCESS"
		[ -n "$dest" ] || return "$RETURN_SUCCESS"
		shell::prompt::export ${n[@]+"${n[@]}"} "--${flag:-global}" --all "$dest" || true
		;;
	"One prompt"*)
		picked="$(_shell::prompt::choose "$work" "$flag" "Export: ")" || rc=$?
		[ "$rc" -eq 0 ] || return "$RETURN_SUCCESS"
		scope="${picked%%$'\t'*}"
		slug="${picked#*$'\t'}"
		dest="$(_shell::ask::read_line "d" "Destination file or directory (empty = cancel):")" || return "$RETURN_SUCCESS"
		[ -n "$dest" ] || return "$RETURN_SUCCESS"
		shell::prompt::export ${n[@]+"${n[@]}"} "--${scope}" "$slug" "$dest" || true
		;;
	esac
	return "$RETURN_SUCCESS"
}

# @internal
# @description The hub loop of shell::prompt::manage::fzf.
# @arg $1 string The work directory.
# @arg $2 string `true` for dry-run.
# @arg $3 string Scope filter.
# @exitcode 0 Closed with ESC.
# @exitcode 11 The user picked "← Back".
# @example
#   _shell::prompt::scoped _shell::prompt::hub false ""
#
_shell::prompt::hub() {
	local work="${1-}" dry_run="${2-false}" flag="${3-}" action src
	local -a n=() loc=()
	[ "$dry_run" = "true" ] && n=(-n)
	[ "$flag" = "local" ] && loc=(--local)
	while true; do
		action="$(printf 'Add\nView\nEdit\nCopy\nClone\nRename\nRemove\nImport\nExport\nHistory\n%s\n' "$SHELL_FZF_BACK_LABEL" | shell::fzf::select \
			--prompt="Prompts: " --header="Prompt store   Enter: open   ESC: leave" --height=45%)" || {
			shell::logger::info "Closed"
			return "$RETURN_SUCCESS"
		}
		case "$action" in
		Add) _shell::prompt::add::interactive "$work" "$dry_run" "$flag" ;;
		View) _shell::prompt::loop "$work" view "$dry_run" "$flag" "" || true ;;
		Edit) _shell::prompt::loop "$work" edit "$dry_run" "$flag" "" || true ;;
		Copy) _shell::prompt::loop "$work" copy "$dry_run" "$flag" "" || true ;;
		Clone) _shell::prompt::loop "$work" clone "$dry_run" "$flag" "" || true ;;
		Rename) _shell::prompt::loop "$work" rename "$dry_run" "$flag" "" || true ;;
		Remove) _shell::prompt::loop "$work" remove "$dry_run" "$flag" "" || true ;;
		History) _shell::prompt::loop "$work" history "$dry_run" "$flag" "" || true ;;
		Export) _shell::prompt::export::interactive "$work" "$dry_run" "$flag" ;;
		Import)
			src="$(_shell::ask::read_line "i" "File, directory or URL to import (empty = cancel):")" || continue
			[ -n "$src" ] && { shell::prompt::import ${n[@]+"${n[@]}"} ${loc[@]+"${loc[@]}"} "$src" || true; }
			;;
		*)
			shell::logger::info "Back"
			return "$RETURN_BACK"
			;;
		esac
	done
}

# @description The hub of the prompt store: Add, View, Edit, Copy, Clone, Rename, Remove, Import, Export, History and Back.
#   Each entry opens its own live-preview list (or asks what it needs) and returns to this menu when done; "← Back"
#   leaves the hub without changing anything.
# @option -n Optional dry-run flag. Write and copy commands are printed instead of executed.
# @option --local Optional. Work on the project store (./.prompts) only.
# @option --global Optional. Work on the global store only.
# @option -h | --help Show help and return.
# @exitcode 0 Closed with ESC.
# @exitcode 2 Invalid option.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL).
# @example
#   shell::prompt::manage::fzf
#   shell::prompt::manage::fzf -n
#
shell::prompt::manage::fzf() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Hub of the prompt store: add, view, edit, copy, clone, rename, remove, import, export, history" "shell::prompt::manage::fzf [-n] [--local|--global]" \
			"shell::prompt::manage::fzf" "-n::Dry-run: print commands instead of executing them" "--local::Only the project store" \
			"--global::Only the global store" "-h, --help::Display this help message"
		shell::logger::note "Every list comes back after an action; leave with ESC or '${SHELL_FZF_BACK_LABEL}' (returns ${RETURN_BACK})."
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::menu hub shell::prompt::manage::fzf "$@"
}
