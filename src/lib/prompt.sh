#!/usr/bin/env bash
# @file lib/prompt.sh
# @brief Prompt Management Store: a local, file-based library of reusable AI prompts.
# @description
#   One Markdown file per prompt, in a GLOBAL store (available from any directory) and an optional
#   per-project LOCAL store (`./.prompts`).
#
#       <store>/<slug>.md                        the prompt (front matter + body)
#       <store>/.history/<slug>/<UTC-stamp>.md   snapshots taken before every edit, overwrite and removal
#
#   File format (the body is stored byte for byte and never interpreted):
#
#       ---
#       title: Code review checklist
#       description: Strict reviewer persona for bash PRs
#       tags: review,bash,quality
#       created: 2026-11-14T10:00:00Z
#       updated: 2026-11-14T10:00:00Z
#       ---
#       <prompt body>
#
#   The body may hold `{{name}}` or `{{name|default}}` placeholders, filled in by `render` / `copy`.
#   The interactive menus (`::fzf`) live in lib/prompt_fzf.sh.
#
#   Safety: files are 600 and directories 700 (prompts can hold secrets), every write is atomic
#   (temp file in the same directory + mv), the body is never passed to the logger or to a command
#   line, slugs are restricted to [a-z0-9-] (no path traversal) and lookups are exact filename matches.

# @internal
# @description Print the directory of a store.
# @arg $1 string `global` (default) or `local`.
# @stdout The directory (the local store is resolved against the current directory).
# @exitcode 0 Always.
# @example
#   dir="$(_shell::prompt::dir local)"
#
_shell::prompt::dir() {
	case "${1-global}" in
	local) printf '%s/%s\n' "$PWD" "$SHELL_PROMPT_LOCAL_NAME" ;;
	*) printf '%s\n' "$SHELL_PROMPT_DIR" ;;
	esac
}

# @internal
# @description Print the path of the file of a prompt (the file may not exist).
# @arg $1 string The scope: `global` or `local`.
# @arg $2 string The slug.
# @stdout The path.
# @exitcode 0 Always.
# @example
#   file="$(_shell::prompt::file global code-review)"
#
_shell::prompt::file() {
	printf '%s/%s.md\n' "$(_shell::prompt::dir "${1-global}")" "${2-}"
}

# @internal
# @description Print the scopes to read, one per line. The local store only counts when its directory exists.
# @arg $1 string Optional filter: `local`, `global` or empty / `all`.
# @stdout `global` and/or `local`.
# @exitcode 0 Always.
# @example
#   _shell::prompt::scopes all
#
_shell::prompt::scopes() {
	case "${1-}" in
	local) [ -d "$(_shell::prompt::dir local)" ] && printf 'local\n' ;;
	global) printf 'global\n' ;;
	*)
		printf 'global\n'
		[ -d "$(_shell::prompt::dir local)" ] && printf 'local\n'
		;;
	esac
	return "$RETURN_SUCCESS"
}

# @internal
# @description Tell whether a string is a valid slug: lowercase letters, digits and `-`, not starting with `-`, at most 100 characters.
# @arg $1 string The candidate.
# @exitcode 0 Valid.
# @exitcode 1 Invalid.
# @example
#   _shell::prompt::valid_slug "code-review" && echo ok
#
_shell::prompt::valid_slug() {
	case "${1-}" in
	'' | -* | *[!abcdefghijklmnopqrstuvwxyz0123456789-]*) return "$RETURN_FAILURE" ;;
	esac
	[ "${#1}" -le 100 ]
}

# @internal
# @description Validate a slug argument and say why it is rejected.
# @arg $1 string The slug.
# @exitcode 0 Valid.
# @exitcode 2 Invalid.
# @example
#   _shell::prompt::need_slug "$slug" || return
#
_shell::prompt::need_slug() {
	if _shell::prompt::valid_slug "${1-}"; then
		return "$RETURN_SUCCESS"
	fi
	shell::logger::error "Invalid slug '${1-}': use lowercase letters, digits and '-' (max 100, no leading '-')."
	return "$RETURN_INVALID"
}

# @internal
# @description Derive a slug from a title: lowercase, anything outside [a-z0-9] becomes `-`, trimmed, at most 80 characters.
# @arg $1 string The title.
# @stdout The slug (empty when the title has no usable character).
# @exitcode 0 A slug was derived.
# @exitcode 2 Nothing usable.
# @example
#   slug="$(_shell::prompt::slugify "Code review checklist")"   # code-review-checklist
#
_shell::prompt::slugify() {
	local slug
	slug="$(printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]' | LC_ALL=C sed 's/[^a-z0-9][^a-z0-9]*/-/g; s/^-//; s/-$//' | cut -c1-80 | LC_ALL=C sed 's/-$//')"
	[ -n "$slug" ] || return "$RETURN_INVALID"
	printf '%s\n' "$slug"
}

# @internal
# @description Make a value fit on one front-matter line: newlines and tabs become spaces, the ends are trimmed.
# @arg $1 string The value.
# @stdout The cleaned value.
# @exitcode 0 Always.
# @example
#   title="$(_shell::prompt::clean_line "$title")"
#
_shell::prompt::clean_line() {
	printf '%s' "${1-}" | tr '\r\n\t' '   ' | sed 's/^  *//; s/  *$//'
}

# @internal
# @description Normalise tags: split on commas and spaces, lowercase, keep [a-z0-9_-], drop empties and duplicates.
# @arg $@ string The tags (any mix of `a,b` and `a b`).
# @stdout The tags joined by commas (may be empty).
# @exitcode 0 Always.
# @example
#   tags="$(_shell::prompt::norm_tags "Review, bash quality")"   # review,bash,quality
#
_shell::prompt::norm_tags() {
	printf '%s' "$*" | tr '[:upper:]' '[:lower:]' | tr ', ' '\n\n' | LC_ALL=C sed 's/[^a-z0-9_-]//g' |
		awk 'NF && !seen[$0]++' | paste -s -d, -
}

# @internal
# @description Print the current UTC time as an ISO 8601 timestamp.
# @stdout For example `2026-11-14T10:00:00Z`.
# @exitcode 0 Always.
# @example
#   now="$(_shell::prompt::now)"
#
_shell::prompt::now() {
	date -u '+%Y-%m-%dT%H:%M:%SZ'
}

# @internal
# @description Print one front-matter value of a prompt file (POSIX awk only).
# @arg $1 string The file.
# @arg $2 string The key (`title`, `description`, `tags`, `created`, `updated`).
# @stdout The value, without the leading blanks.
# @exitcode 0 The key was found.
# @exitcode 1 No such key, or the file has no front matter.
# @example
#   title="$(_shell::prompt::meta "$file" title)"
#
_shell::prompt::meta() {
	PROMPT_K="${2-}" awk '
		BEGIN { k = ENVIRON["PROMPT_K"] }
		{ sub(/\r$/, "") }
		NR == 1 { if ($0 != "---") exit; next }
		$0 == "---" { exit }
		{ i = index($0, ":"); if (i > 0 && substr($0, 1, i - 1) == k) { v = substr($0, i + 1); sub(/^[ \t]+/, "", v); print v; f = 1; exit } }
		END { exit(f ? 0 : 1) }' "${1-}"
}

# @internal
# @description Print the line number where the body starts (the line after the closing `---`).
# @arg $1 string The file.
# @stdout The line number.
# @exitcode 0 The front matter is well formed.
# @exitcode 1 The file does not start with `---` or the block is never closed.
# @example
#   off="$(_shell::prompt::body_offset "$file")"
#
_shell::prompt::body_offset() {
	awk '
		{ sub(/\r$/, "") }
		NR == 1 { if ($0 != "---") exit; next }
		$0 == "---" { print NR + 1; f = 1; exit }
		END { exit(f ? 0 : 1) }' "${1-}"
}

# @internal
# @description Stream the body of a prompt file byte for byte (a missing final newline stays missing).
# @arg $1 string The file.
# @stdout The body.
# @exitcode 0 Printed.
# @exitcode 1 The file has no valid front matter.
# @example
#   _shell::prompt::body_stream "$file" | wc -c
#
_shell::prompt::body_stream() {
	local off
	off="$(_shell::prompt::body_offset "${1-}")" || return "$RETURN_FAILURE"
	tail -n +"$off" "$1"
}

# @internal
# @description Print the body followed by a sentinel `x`, so a command substitution keeps trailing newlines.
#   The caller removes it: `text="$(_shell::prompt::body_sentinel f)"; text="${text%x}"`.
# @arg $1 string The file.
# @stdout The body and `x`.
# @exitcode 0 Printed.
# @exitcode 1 The file has no valid front matter.
# @example
#   text="$(_shell::prompt::body_sentinel "$file")"; text="${text%x}"
#
_shell::prompt::body_sentinel() {
	_shell::prompt::body_stream "${1-}" || return "$RETURN_FAILURE"
	printf 'x'
}

# @internal
# @description Validate a prompt file: well-formed front matter, a title (max 200 characters) and a non-blank body.
# @arg $1 string The file.
# @exitcode 0 Valid.
# @exitcode 1 Invalid (the reason is logged).
# @example
#   _shell::prompt::validate "$tmp" || echo "fix it"
#
_shell::prompt::validate() {
	local file="${1-}" off title
	off="$(_shell::prompt::body_offset "$file")" || {
		shell::logger::error "Front matter is missing: the file must start with '---' and close the block with another '---'."
		return "$RETURN_FAILURE"
	}
	title="$(_shell::prompt::clean_line "$(_shell::prompt::meta "$file" title)")"
	if [ -z "$title" ]; then
		shell::logger::error "The front matter needs a non-empty 'title:'."
		return "$RETURN_FAILURE"
	fi
	if [ "${#title}" -gt 200 ]; then
		shell::logger::error "The title is longer than 200 characters."
		return "$RETURN_FAILURE"
	fi
	if ! tail -n +"$off" "$file" | grep -q '[^[:space:]]'; then
		shell::logger::error "The prompt body is empty."
		return "$RETURN_FAILURE"
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Create a store directory (700) with its `.history` folder.
# @arg $1 string The scope: `global` or `local`.
# @exitcode 0 Ready.
# @exitcode 1 The directory could not be created.
# @example
#   _shell::prompt::init global
#
_shell::prompt::init() {
	local dir
	dir="$(_shell::prompt::dir "${1-global}")"
	(umask 077 && mkdir -p -- "$dir/.history") || {
		shell::logger::error "Could not create the prompt store '$dir'."
		return "$RETURN_FAILURE"
	}
	shell::permission::secure "$dir" >/dev/null 2>&1
	return "$RETURN_SUCCESS"
}

# @internal
# @description Write a prompt file atomically: front matter + the body of a file, via a temp file in the same directory and `mv`.
# @arg $1 string The destination.
# @arg $2 string The title.
# @arg $3 string The description.
# @arg $4 string The tags (already normalised).
# @arg $5 string The created timestamp.
# @arg $6 string The updated timestamp.
# @arg $7 string A file holding the body.
# @exitcode 0 Written (mode 600).
# @exitcode 1 The write failed (nothing is left behind).
# @example
#   _shell::prompt::write "$dest" "Title" "" "a,b" "$now" "$now" "$bodyfile"
#
_shell::prompt::write() {
	local dest="${1-}" title desc tags="${4-}" created="${5-}" updated="${6-}" bodyfile="${7-}" tmp
	title="$(_shell::prompt::clean_line "${2-}")"
	desc="$(_shell::prompt::clean_line "${3-}")"
	tmp="$(umask 077 && mktemp "${dest%/*}/.tmp.XXXXXX")" || return "$RETURN_FAILURE"
	{
		printf -- '---\ntitle: %s\ndescription: %s\ntags: %s\ncreated: %s\nupdated: %s\n---\n' "$title" "$desc" "$tags" "$created" "$updated"
		cat -- "$bodyfile"
	} >"$tmp" || {
		rm -f -- "$tmp"
		return "$RETURN_FAILURE"
	}
	chmod 600 "$tmp" 2>/dev/null
	mv -f -- "$tmp" "$dest" || {
		rm -f -- "$tmp"
		return "$RETURN_FAILURE"
	}
	return "$RETURN_SUCCESS"
}

# @internal
# @description Drop the oldest snapshots of a prompt beyond SHELL_PROMPT_HISTORY_LIMIT.
# @arg $1 string The scope.
# @arg $2 string The slug.
# @exitcode 0 Always.
# @example
#   _shell::prompt::prune global code-review
#
_shell::prompt::prune() {
	local hdir limit="$SHELL_PROMPT_HISTORY_LIMIT" stamp
	hdir="$(_shell::prompt::dir "${1-global}")/.history/${2-}"
	case "$limit" in '' | *[!0-9]* | 0) limit=20 ;; esac
	[ -d "$hdir" ] || return "$RETURN_SUCCESS"
	_shell::prompt::stamps "${1-global}" "${2-}" | tail -n +"$((limit + 1))" | while IFS= read -r stamp; do
		rm -f -- "$hdir/$stamp.md"
	done
	return "$RETURN_SUCCESS"
}

# @internal
# @description List the snapshot stamps of a prompt, newest first.
# @arg $1 string The scope.
# @arg $2 string The slug.
# @stdout One stamp per line (for example `20261114T100000Z`).
# @exitcode 0 Always.
# @example
#   _shell::prompt::stamps global code-review
#
_shell::prompt::stamps() {
	local hdir
	hdir="$(_shell::prompt::dir "${1-global}")/.history/${2-}"
	[ -d "$hdir" ] || return "$RETURN_SUCCESS"
	ls -1 "$hdir" 2>/dev/null | sed -n 's/\.md$//p' | LC_ALL=C sort -r
}

# @internal
# @description Copy a file into the history of a prompt (mode 600) and prune the old snapshots.
# @arg $1 string The scope.
# @arg $2 string The slug.
# @arg $3 string The file to keep.
# @arg $4 string Optional. `move` moves the file instead of copying it (used by remove).
# @stdout The snapshot stamp.
# @exitcode 0 Kept.
# @exitcode 1 The snapshot failed.
# @example
#   _shell::prompt::snapshot global code-review "$file" >/dev/null
#
_shell::prompt::snapshot() {
	local hdir stamp dest n=1
	hdir="$(_shell::prompt::dir "${1-global}")/.history/${2-}"
	(umask 077 && mkdir -p -- "$hdir") || return "$RETURN_FAILURE"
	stamp="$(date -u '+%Y%m%dT%H%M%SZ')"
	dest="$hdir/$stamp.md"
	while [ -e "$dest" ]; do
		n=$((n + 1))
		stamp="$(date -u '+%Y%m%dT%H%M%SZ')-$n"
		dest="$hdir/$stamp.md"
	done
	if [ "${4-}" = "move" ]; then
		mv -f -- "${3-}" "$dest" || return "$RETURN_FAILURE"
	else
		(umask 077 && cp -- "${3-}" "$dest") || return "$RETURN_FAILURE"
	fi
	chmod 600 "$dest" 2>/dev/null
	_shell::prompt::prune "${1-global}" "${2-}"
	printf '%s\n' "$stamp"
}

# @internal
# @description Find which store holds a prompt. An explicit scope is honoured; otherwise the local store wins over the global one.
# @arg $1 string `local`, `global` or empty.
# @arg $2 string The slug.
# @stdout The scope.
# @exitcode 0 Found.
# @exitcode 2 Invalid slug.
# @exitcode 3 Not found (logged).
# @example
#   scope="$(_shell::prompt::resolve "" code-review)" || return
#
_shell::prompt::resolve() {
	local flag="${1-}" slug="${2-}" sc
	_shell::prompt::need_slug "$slug" || return "$RETURN_INVALID"
	case "$flag" in
	local | global)
		if [ -f "$(_shell::prompt::file "$flag" "$slug")" ]; then
			printf '%s\n' "$flag"
			return "$RETURN_SUCCESS"
		fi
		;;
	*)
		for sc in local global; do
			if [ -f "$(_shell::prompt::file "$sc" "$slug")" ]; then
				printf '%s\n' "$sc"
				return "$RETURN_SUCCESS"
			fi
		done
		;;
	esac
	shell::logger::error "Prompt '$slug' not found${flag:+ in the $flag store}."
	return "$RETURN_NOT_FOUND"
}

# @internal
# @description Store a prompt: create the directories, then write it atomically. With `replace` an existing prompt is snapshotted first.
# @arg $1 string The scope.
# @arg $2 string The slug.
# @arg $3 string The title.
# @arg $4 string The description.
# @arg $5 string The tags.
# @arg $6 string The created timestamp (empty = now).
# @arg $7 string A file holding the body.
# @arg $8 string `new` (fail when the slug exists, default) or `replace`.
# @exitcode 0 Stored.
# @exitcode 1 The write failed.
# @exitcode 7 The slug already exists (`new` mode); nothing was written.
# @example
#   _shell::prompt::store global my-prompt "My prompt" "" "a,b" "" "$bodyfile" new
#
_shell::prompt::store() {
	local scope="${1-global}" slug="${2-}" file now
	file="$(_shell::prompt::file "$scope" "$slug")"
	if [ -e "$file" ] && [ "${8-new}" != "replace" ]; then
		shell::logger::error "Prompt '$slug' already exists in the $scope store; nothing was overwritten."
		return "$RETURN_EXISTS"
	fi
	_shell::prompt::init "$scope" || return "$RETURN_FAILURE"
	if [ -e "$file" ]; then
		_shell::prompt::snapshot "$scope" "$slug" "$file" >/dev/null || {
			shell::logger::error "Could not snapshot '$slug' before overwriting it."
			return "$RETURN_FAILURE"
		}
	fi
	now="$(_shell::prompt::now)"
	_shell::prompt::write "$file" "${3-}" "${4-}" "${5-}" "${6:-$now}" "$now" "${7-}" || {
		shell::logger::error "Could not write prompt '$slug'."
		return "$RETURN_FAILURE"
	}
	return "$RETURN_SUCCESS"
}

# @internal
# @description Run a function in a subshell with a private work directory that is removed on exit, error, Ctrl-C and kill.
#   The function receives the work directory as its first argument. (A `trap` set directly in a library function would
#   replace the traps of the user's shell, so the work happens in a subshell.)
# @arg $1 string The function to run.
# @arg $@ string Its arguments (after the work directory).
# @exitcode N The exit status of the function.
# @example
#   _shell::prompt::scoped _shell::prompt::edit::inner global code-review false
#
_shell::prompt::scoped() {
	local fn="${1-}" work rc=0
	shift
	work="$(mktemp -d "${TMPDIR:-/tmp}/shell-prompt.XXXXXX")" || {
		shell::logger::error "Could not create a temporary directory."
		return "$RETURN_FAILURE"
	}
	(
		trap 'rm -rf -- "$work"' EXIT
		trap 'exit 130' INT
		trap 'exit 143' TERM HUP
		"$fn" "$work" "$@"
	) || rc=$?
	rm -rf -- "$work"
	return "$rc"
}

# @internal
# @description Print the standard help block of a function.
# @arg $1 string The description.
# @arg $2 string The usage line.
# @arg $3 string One example.
# @arg $@ string Optional. Options as `flag::description`.
# @exitcode 0 Always.
# @example
#   _shell::prompt::help "Do it" "shell::prompt::x [-h]" "shell::prompt::x" "-h, --help::Display this help message"
#
_shell::prompt::help() {
	local info="${1-}" usage="${2-}" example="${3-}" opt
	shift 3
	shell::logger::reset_options
	shell::logger::info "$info"
	shell::logger::usage "$usage"
	for opt in "$@"; do
		shell::logger::option "${opt%%::*}" "${opt#*::}"
	done
	shell::logger::example "$example"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Open a file in the user's editor ($VISUAL, then $EDITOR, then vi). The command may carry arguments (`code -w`).
# @arg $1 string The file.
# @exitcode 0 The editor exited normally.
# @exitcode N The editor's exit status.
# @example
#   _shell::prompt::editor "$tmp"
#
_shell::prompt::editor() {
	local editor="${VISUAL:-${EDITOR:-vi}}"
	sh -c "$editor \"\$1\"" sh "${1-}"
}

# @internal
# @description Read the clipboard into a file.
# @arg $1 string The destination file.
# @exitcode 0 Read.
# @exitcode 3 No clipboard tool (pbpaste, wl-paste, xclip, xsel).
# @example
#   _shell::prompt::clip_read "$work/body" || echo "no clipboard"
#
_shell::prompt::clip_read() {
	local dest="${1-}"
	if command -v pbpaste >/dev/null 2>&1; then
		pbpaste >"$dest"
	elif command -v wl-paste >/dev/null 2>&1; then
		wl-paste --no-newline >"$dest"
	elif command -v xclip >/dev/null 2>&1; then
		xclip -selection clipboard -o >"$dest"
	elif command -v xsel >/dev/null 2>&1; then
		xsel --clipboard --output >"$dest"
	else
		return "$RETURN_NOT_FOUND"
	fi
}

# @internal
# @description Copy the content of a file to the clipboard and say what happened. The text travels in a variable (never
#   through fzf `execute`), `printf '%s'` keeps quotes, `$`, backticks, `%`, `\`, unicode and trailing newlines. An empty
#   or blank prompt is never copied. Only the title and the size are logged, never the body. Without a clipboard tool
#   the text is printed with a warning. In dry-run mode only the command is shown.
# @arg $1 string The label for the messages (for example the title).
# @arg $2 string The file holding the text.
# @arg $3 string `true` for dry-run.
# @exitcode 0 Copied (or printed, or dry-run).
# @exitcode 1 The clipboard tool failed.
# @exitcode 2 Nothing to copy.
# @example
#   _shell::prompt::copy_file "Code review" "$work/rendered" false
#
_shell::prompt::copy_file() {
	local label="${1-}" file="${2-}" dry_run="${3-false}" text size rc=0
	if [ ! -s "$file" ] || ! grep -q '[^[:space:]]' "$file"; then
		shell::logger::error "Nothing to copy: '${label}' is empty."
		return "$RETURN_INVALID"
	fi
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "shell::clipboard::copy \"<prompt: ${label}>\""
		return "$RETURN_SUCCESS"
	fi
	text="$(
		cat -- "$file"
		printf x
	)"
	text="${text%x}"
	size="$(printf '%s' "$text" | wc -m | tr -d ' ')"
	shell::clipboard::copy "$text" || rc=$?
	case "$rc" in
	0)
		shell::logger::success "Copied prompt '${label}' (${size} chars)"
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_NOT_FOUND")
		shell::logger::warn "No clipboard tool found - printing prompt '${label}' instead"
		printf '%s\n' "$text"
		return "$RETURN_SUCCESS"
		;;
	*)
		shell::logger::error "Could not copy prompt '${label}'."
		return "$RETURN_FAILURE"
		;;
	esac
}

# @internal
# @description Print the awk program that turns prompt files into rows. One program serves the CLI and the fzf helper
#   scripts. Variables: `sc` (scope letter G/L), `fmt` (`tsv` or `fzf`); environment: PROMPT_Q (words that must all
#   appear in title, description, tags or body, case-insensitive) and PROMPT_TAG (exact tag).
# @stdout The awk program.
# @exitcode 0 Always.
# @example
#   awk -v sc=G -v fmt=tsv "$(_shell::prompt::awk::rows)" "$dir"/*.md
#
_shell::prompt::awk::rows() {
	cat <<'EOS'
function flush(   hay, n, i, ws, ts, ok, shown) {
	if (slug !~ /^[a-z0-9][a-z0-9-]*$/) return
	if (title == "") title = slug
	if (q != "") {
		hay = tolower(title " " desc " " tags " " body)
		n = split(tolower(q), ws, /[ \t]+/)
		for (i = 1; i <= n; i++) if (ws[i] != "" && index(hay, ws[i]) == 0) return
	}
	if (tag != "") {
		n = split(tags, ts, ",")
		ok = 0
		for (i = 1; i <= n; i++) if (ts[i] == tag) ok = 1
		if (!ok) return
	}
	if (fmt == "fzf") {
		shown = (tags == "" ? "-" : tags)
		printf "%s/%s\t[%s] %-26s %-34s %-22s %s\n", sc, slug, sc, slug, title, shown, substr(upd, 1, 10)
	} else printf "%s\t%s\t%s\t%s\t%s\n", sc, slug, title, tags, upd
}
BEGIN { q = ENVIRON["PROMPT_Q"]; tag = tolower(ENVIRON["PROMPT_TAG"]) }
FNR == 1 {
	flush()
	fn = FILENAME
	sub(/^.*\//, "", fn)
	sub(/\.md$/, "", fn)
	slug = fn; title = ""; desc = ""; tags = ""; upd = ""; body = ""
	line = $0; sub(/\r$/, "", line)
	st = (line == "---") ? 1 : 2
	next
}
{ line = $0; sub(/\r$/, "", line) }
st == 1 {
	if (line == "---") { st = 2; next }
	i = index(line, ":")
	if (i > 0) {
		k = substr(line, 1, i - 1); v = substr(line, i + 1); sub(/^[ \t]+/, "", v)
		if (k == "title") title = v; else if (k == "description") desc = v
		else if (k == "tags") tags = v; else if (k == "updated") upd = v
	}
	next
}
st == 2 { if (q != "") body = body " " line }
END { flush() }
EOS
}

# @internal
# @description Print prompt rows from the stores, sorted.
# @arg $1 string Scope filter: `local`, `global` or empty for both.
# @arg $2 string Format: `tsv` (scope, slug, title, tags, updated) or `fzf` (key `G/slug`, tab, display).
# @arg $3 string Optional. Search words.
# @arg $4 string Optional. Tag filter.
# @stdout The rows.
# @exitcode 0 Always.
# @example
#   _shell::prompt::rows "" tsv "review bash" ""
#
_shell::prompt::rows() {
	local flag="${1-}" fmt="${2-tsv}" q="${3-}" tag="${4-}" prog sc dir ch
	prog="$(_shell::prompt::awk::rows)"
	{
		while IFS= read -r sc; do
			dir="$(_shell::prompt::dir "$sc")"
			[ -d "$dir" ] || continue
			ch="G"
			[ "$sc" = "local" ] && ch="L"
			PROMPT_Q="$q" PROMPT_TAG="$tag" find "$dir" -maxdepth 1 -type f -name '*.md' ! -name '.*' \
				-exec awk -v sc="$ch" -v fmt="$fmt" "$prog" {} + 2>/dev/null
		done <<EOF
$(_shell::prompt::scopes "$flag")
EOF
	} | LC_ALL=C sort
	return "$RETURN_SUCCESS"
}

# @internal
# @description Print the placeholders of a text read from stdin, once each: `name<TAB>has-default<TAB>default`.
#   A placeholder is `{{name}}` or `{{name|default}}`; names are `[A-Za-z_][A-Za-z0-9_.-]*`.
# @stdin The prompt body.
# @stdout One line per distinct name, in order of first appearance.
# @exitcode 0 Always.
# @example
#   _shell::prompt::body_stream "$file" | _shell::prompt::vars
#
_shell::prompt::vars() {
	grep -o '{{[^{}]*}}' 2>/dev/null | sed 's/^{{//; s/}}$//' | awk '
		{
			j = index($0, "|"); n = (j ? substr($0, 1, j - 1) : $0); d = (j ? substr($0, j + 1) : "")
			gsub(/^[ \t]+|[ \t]+$/, "", n)
			gsub(/^[ \t]+|[ \t]+$/, "", d)
			if (n !~ /^[A-Za-z_][A-Za-z0-9_.-]*$/) next
			if (!(n in seen)) { seen[n] = 1; order[++c] = n; has[n] = j ? 1 : 0; def[n] = d }
			else if (j && !has[n]) { has[n] = 1; def[n] = d }
		}
		END { for (i = 1; i <= c; i++) printf "%s\t%s\t%s\n", order[i], has[order[i]], def[order[i]] }'
	return "$RETURN_SUCCESS"
}

# @internal
# @description Replace the placeholders of a text with the given values (pure shell, so any character in a value is safe).
#   A placeholder without a value is left as it is. The text is not newline-terminated by this function.
# @arg $1 string The text.
# @arg $@ string The values as `name=value`.
# @stdout The text with the values filled in.
# @exitcode 0 Always.
# @example
#   out="$(_shell::prompt::subst "Hi {{who}}" who=world; printf x)"; out="${out%x}"
#
_shell::prompt::subst() {
	local rest="${1-}" out="" pre after tok name val kv
	shift
	while :; do
		case "$rest" in
		*'{{'*'}}'*) ;;
		*) break ;;
		esac
		pre="${rest%%\{\{*}"
		after="${rest#*\{\{}"
		tok="${after%%\}\}*}"
		case "$tok" in
		*'{'* | *'}'* | *$'\n'*)
			out="${out}${pre}{{"
			rest="$after"
			continue
			;;
		esac
		name="${tok%%|*}"
		name="${name#"${name%%[![:space:]]*}"}"
		name="${name%"${name##*[![:space:]]}"}"
		case "$name" in
		'' | [!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_]* | *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-]*)
			out="${out}${pre}{{${tok}}}"
			rest="${after#*\}\}}"
			continue
			;;
		esac
		val="{{${tok}}}"
		for kv in "$@"; do
			if [ "${kv%%=*}" = "$name" ]; then val="${kv#*=}"; fi
		done
		out="${out}${pre}${val}"
		rest="${after#*\}\}}"
	done
	printf '%s' "${out}${rest}"
}

# @internal
# @description Render a prompt into a file. Placeholders take the given `name=value` first; the others are asked
#   (with their default shown, Enter accepts it) when stdin is a terminal and `ask` is true, otherwise their default is used.
# @arg $1 string The prompt file.
# @arg $2 string The destination file.
# @arg $3 string `true` to ask for missing values.
# @arg $@ string Optional. Values as `name=value`.
# @exitcode 0 Rendered.
# @exitcode 2 A placeholder has no value and no default (logged).
# @exitcode 9 The user cancelled (Ctrl-D).
# @example
#   _shell::prompt::render::file "$file" "$work/out" true who=world
#
_shell::prompt::render::file() {
	local file="${1-}" dest="${2-}" ask="${3-false}" vars vname vhas vdef kv got val ans missing="" text out
	shift 3
	local -a resolved=()
	vars="$(_shell::prompt::body_stream "$file" | _shell::prompt::vars)"
	# fd 3 (not stdin): stdin must stay the terminal for the questions below.
	while IFS=$'\t' read -r vname vhas vdef <&3; do
		[ -n "$vname" ] || continue
		got="false"
		val=""
		for kv in "$@"; do
			if [ "${kv%%=*}" = "$vname" ]; then
				val="${kv#*=}"
				got="true"
			fi
		done
		if [ "$got" != "true" ]; then
			if [ "$ask" = "true" ] && [ -t 0 ]; then
				ans="$(_shell::ask::read_line "v" "${vname}${vdef:+ [${vdef}]}:")" || return "$RETURN_CANCELLED"
				if [ -n "$ans" ]; then val="$ans"; else val="$vdef"; fi
			elif [ "$vhas" = "1" ]; then
				val="$vdef"
			else
				missing="${missing} ${vname}"
				continue
			fi
		fi
		resolved+=("${vname}=${val}")
	done 3<<EOF
$vars
EOF
	if [ -n "$missing" ]; then
		shell::logger::error "No value for:${missing} (pass name=value arguments)."
		return "$RETURN_INVALID"
	fi
	text="$(_shell::prompt::body_sentinel "$file")"
	text="${text%x}"
	out="$(
		_shell::prompt::subst "$text" ${resolved[@]+"${resolved[@]}"}
		printf x
	)"
	out="${out%x}"
	printf '%s' "$out" >"$dest"
}

# @internal
# @description Check that every argument looks like `name=value` with a valid name.
# @arg $@ string The arguments.
# @exitcode 0 All valid.
# @exitcode 2 One is not (logged).
# @example
#   _shell::prompt::kv_check "$@" || return
#
_shell::prompt::kv_check() {
	local kv name
	for kv in "$@"; do
		name="${kv%%=*}"
		case "$kv" in
		*=*) ;;
		*)
			shell::logger::error "Expected name=value, got '${kv}'."
			return "$RETURN_INVALID"
			;;
		esac
		case "$name" in
		'' | [!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_]* | *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-]*)
			shell::logger::error "Invalid variable name '${name}'."
			return "$RETURN_INVALID"
			;;
		esac
	done
	return "$RETURN_SUCCESS"
}

# @internal
# @description Add a prompt. The body comes from a file, from stdin or from the editor.
# @arg $1 string The work directory.
# @arg $2 string `true` for dry-run.
# @arg $3 string The scope.
# @arg $4 string The title.
# @arg $5 string The description.
# @arg $6 string The tags.
# @arg $7 string The source: a file, `-` (stdin), `clipboard`, or empty (editor).
# @exitcode 0 Added (or dry-run).
# @exitcode 1 Failed.
# @exitcode 2 Invalid input.
# @exitcode 7 The slug exists.
# @example
#   _shell::prompt::scoped _shell::prompt::add::inner false global "My prompt" "" "" -
#
_shell::prompt::add::inner() {
	local work="${1-}" dry_run="${2-false}" scope="${3-global}" title="${4-}" desc="${5-}" tags="${6-}" src="${7-}"
	local slug body="$work/body" bytes now
	title="$(_shell::prompt::clean_line "$title")"
	if [ -z "$title" ]; then
		shell::logger::error "The title cannot be empty."
		return "$RETURN_INVALID"
	fi
	slug="$(_shell::prompt::slugify "$title")" || {
		shell::logger::error "The title has no usable character for a slug (use letters or digits)."
		return "$RETURN_INVALID"
	}
	if [ -e "$(_shell::prompt::file "$scope" "$slug")" ]; then
		shell::logger::error "Prompt '$slug' already exists in the $scope store; nothing was overwritten. Rename it, clone it or pick another title."
		return "$RETURN_EXISTS"
	fi
	tags="$(_shell::prompt::norm_tags "$tags")"
	case "$src" in
	"")
		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "shell::prompt::add --${scope} $(printf '%q' "$title") <body from ${VISUAL:-${EDITOR:-vi}}>"
			return "$RETURN_SUCCESS"
		fi
		now="$(_shell::prompt::now)"
		{
			printf -- '---\ntitle: %s\ndescription: %s\ntags: %s\ncreated: %s\nupdated: %s\n---\n' "$title" "$desc" "$tags" "$now" "$now"
			printf '\n'
		} >"$work/new.md"
		_shell::prompt::editor "$work/new.md" || {
			shell::logger::error "The editor failed."
			return "$RETURN_FAILURE"
		}
		_shell::prompt::validate "$work/new.md" || return "$RETURN_INVALID"
		desc="$(_shell::prompt::meta "$work/new.md" description)"
		tags="$(_shell::prompt::norm_tags "$(_shell::prompt::meta "$work/new.md" tags)")"
		_shell::prompt::body_stream "$work/new.md" >"$body"
		;;
	-) (umask 077 && cat >"$body") || return "$RETURN_FAILURE" ;;
	clipboard)
		(umask 077 && _shell::prompt::clip_read "$body") || {
			shell::logger::error "Could not read the clipboard (needs pbpaste, wl-paste, xclip or xsel)."
			return "$RETURN_NOT_FOUND"
		}
		;;
	*)
		if [ ! -f "$src" ] || [ ! -r "$src" ]; then
			shell::logger::error "Cannot read file '$src'."
			return "$RETURN_NOT_FOUND"
		fi
		(umask 077 && cp -- "$src" "$body") || return "$RETURN_FAILURE"
		;;
	esac
	bytes="$(wc -c <"$body" | tr -d ' ')"
	if [ "$bytes" -gt "$SHELL_PROMPT_MAX_BYTES" ]; then
		shell::logger::error "The prompt is larger than ${SHELL_PROMPT_MAX_BYTES} bytes."
		return "$RETURN_INVALID"
	fi
	if ! grep -q '[^[:space:]]' "$body"; then
		shell::logger::error "The prompt body is empty."
		return "$RETURN_INVALID"
	fi
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "shell::prompt::add --${scope} $(printf '%q' "$title") <${bytes} bytes>   # slug: ${slug}"
		return "$RETURN_SUCCESS"
	fi
	_shell::prompt::store "$scope" "$slug" "$title" "$desc" "$tags" "" "$body" new || return $?
	shell::logger::success "Added prompt '${slug}' (${scope}, ${bytes} bytes)"
}

# @description Add a prompt to the store. The body comes from a file, from stdin (`-`), or - when omitted - from your editor.
#   The slug is derived from the title (lowercase, `[a-z0-9-]`); an existing slug is never overwritten.
#   The body is stored byte for byte. Files are created 600, directories 700.
# @option -n Optional dry-run flag. The command is printed with shell::logger::command_clip and nothing is written.
# @option --local Optional. Use the project store (./.prompts) instead of the global one.
# @option -d | --description <text> Optional. A one-line description.
# @option -t | --tags <list> Optional. Tags, comma or space separated.
# @option -h | --help Show help and return.
# @arg $1 string The title.
# @arg $2 string Optional. A file, or `-` for stdin. Omitted: the editor opens.
# @exitcode 0 Added.
# @exitcode 1 The write failed.
# @exitcode 2 Invalid input (empty title or body, unusable title).
# @exitcode 7 A prompt with that slug already exists.
# @example
#   shell::prompt::add "Code review checklist" ./review.md
#   echo "Summarise {{topic}}" | shell::prompt::add -t "writing,summary" "Summary" -
#   shell::prompt::add -n --local "Release notes"
#
shell::prompt::add() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Add a prompt to the store (body from a file, stdin or the editor)" \
			"shell::prompt::add [-n] [--local] [-d <description>] [-t <tags>] <title> [file|-]" \
			"shell::prompt::add \"Code review checklist\" ./review.md" \
			"-n::Dry-run: print the command instead of executing it" "--local::Use the project store (./.prompts)" \
			"-d, --description <text>::One-line description" "-t, --tags <list>::Tags, comma or space separated" \
			"-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local dry_run="false" scope="global" desc="" tags=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n) dry_run="true" ;;
		--local) scope="local" ;;
		--global) scope="global" ;;
		-d | --description)
			[ "$#" -ge 2 ] || {
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			}
			desc="$2"
			shift
			;;
		-t | --tags)
			[ "$#" -ge 2 ] || {
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			}
			tags="$2"
			shift
			;;
		--)
			shift
			break
			;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done
	if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
		shell::logger::error "Usage: shell::prompt::add [-n] [--local] <title> [file|-]"
		return "$RETURN_INVALID"
	fi
	_shell::prompt::scoped _shell::prompt::add::inner "$dry_run" "$scope" "$1" "$desc" "$tags" "${2-}"
}

# @description Store the current clipboard content as a prompt (reads it with pbpaste, wl-paste, xclip or xsel).
# @option -n Optional dry-run flag. The command is printed and nothing is written.
# @option --local Optional. Use the project store (./.prompts).
# @option -d | --description <text> Optional. A one-line description.
# @option -t | --tags <list> Optional. Tags, comma or space separated.
# @option -h | --help Show help and return.
# @arg $1 string The title.
# @exitcode 0 Added.
# @exitcode 2 Invalid input or an empty clipboard.
# @exitcode 3 No clipboard tool.
# @exitcode 7 A prompt with that slug already exists.
# @example
#   shell::prompt::add::clipboard "Bug report template"
#
shell::prompt::add::clipboard() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Store the current clipboard as a prompt" \
			"shell::prompt::add::clipboard [-n] [--local] [-d <description>] [-t <tags>] <title>" \
			"shell::prompt::add::clipboard \"Bug report template\"" \
			"-n::Dry-run: print the command instead of executing it" "--local::Use the project store (./.prompts)" \
			"-d, --description <text>::One-line description" "-t, --tags <list>::Tags, comma or space separated" \
			"-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local dry_run="false" scope="global" desc="" tags=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n) dry_run="true" ;;
		--local) scope="local" ;;
		--global) scope="global" ;;
		-d | --description)
			[ "$#" -ge 2 ] || {
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			}
			desc="$2"
			shift
			;;
		-t | --tags)
			[ "$#" -ge 2 ] || {
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			}
			tags="$2"
			shift
			;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done
	if [ "$#" -ne 1 ]; then
		shell::logger::error "Usage: shell::prompt::add::clipboard [-n] [--local] <title>"
		return "$RETURN_INVALID"
	fi
	_shell::prompt::scoped _shell::prompt::add::inner "$dry_run" "$scope" "$1" "$desc" "$tags" clipboard
}

# @description Print the raw body of a prompt to stdout, byte for byte (pipe-friendly, no front matter, no rendering).
# @option --local Optional. Only look in the project store.
# @option --global Optional. Only look in the global store.
# @option -h | --help Show help and return.
# @arg $1 string The slug.
# @stdout The prompt body.
# @exitcode 0 Printed.
# @exitcode 2 Invalid slug.
# @exitcode 3 Not found.
# @example
#   shell::prompt::get code-review | pbcopy
#
shell::prompt::get() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Print the raw body of a prompt" "shell::prompt::get [--local|--global] <slug>" \
			"shell::prompt::get code-review | pbcopy" "--local::Only the project store" "--global::Only the global store" \
			"-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local flag=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--local) flag="local" ;;
		--global) flag="global" ;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done
	[ "$#" -eq 1 ] || {
		shell::logger::error "Usage: shell::prompt::get [--local|--global] <slug>"
		return "$RETURN_INVALID"
	}
	local scope
	scope="$(_shell::prompt::resolve "$flag" "$1")" || return $?
	_shell::prompt::body_stream "$(_shell::prompt::file "$scope" "$1")" || {
		shell::logger::error "Prompt '$1' has no valid front matter."
		return "$RETURN_FAILURE"
	}
}

# @internal
# @description Render (and optionally copy) one prompt inside a work directory.
# @arg $1 string The work directory.
# @arg $2 string `render` (print) or `copy`.
# @arg $3 string The scope flag (`local`, `global` or empty).
# @arg $4 string The slug.
# @arg $5 string `true` for dry-run (copy only).
# @arg $@ string Optional. Values as `name=value`.
# @exitcode 0 Done.
# @exitcode 2 A value is missing.
# @exitcode 3 Not found.
# @example
#   _shell::prompt::scoped _shell::prompt::render::inner render "" code-review false who=me
#
_shell::prompt::render::inner() {
	local work="${1-}" mode="${2-render}" flag="${3-}" slug="${4-}" dry_run="${5-false}" scope file title
	shift 5
	scope="$(_shell::prompt::resolve "$flag" "$slug")" || return $?
	file="$(_shell::prompt::file "$scope" "$slug")"
	_shell::prompt::render::file "$file" "$work/out" true "$@" || return $?
	if [ "$mode" = "copy" ]; then
		title="$(_shell::prompt::meta "$file" title)"
		_shell::prompt::copy_file "${title:-$slug}" "$work/out" "$dry_run"
	else
		cat -- "$work/out"
	fi
}

# @description Render a prompt: fill its `{{name}}` / `{{name|default}}` placeholders and print the result.
#   Values given as `name=value` are used first; the others are asked on the terminal (Enter accepts the default).
#   Without a terminal a missing value falls back to its default, or fails when it has none.
# @option --local Optional. Only look in the project store.
# @option --global Optional. Only look in the global store.
# @option -h | --help Show help and return.
# @arg $1 string The slug.
# @arg $@ string Optional. Values as `name=value`.
# @stdout The rendered prompt.
# @exitcode 0 Rendered.
# @exitcode 2 Invalid input, or a placeholder without value or default.
# @exitcode 3 Not found.
# @exitcode 9 Cancelled.
# @example
#   shell::prompt::render summary topic="the release notes" tone=formal
#
shell::prompt::render() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Fill the {{placeholders}} of a prompt and print it" \
			"shell::prompt::render [--local|--global] <slug> [name=value ...]" \
			"shell::prompt::render summary topic=\"release notes\"" "--local::Only the project store" \
			"--global::Only the global store" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local flag=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--local) flag="local" ;;
		--global) flag="global" ;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done
	[ "$#" -ge 1 ] || {
		shell::logger::error "Usage: shell::prompt::render [--local|--global] <slug> [name=value ...]"
		return "$RETURN_INVALID"
	}
	local slug="$1"
	shift
	_shell::prompt::kv_check "$@" || return "$RETURN_INVALID"
	_shell::prompt::scoped _shell::prompt::render::inner render "$flag" "$slug" false "$@"
}

# @description Render a prompt and copy the result to the clipboard (the body itself is never logged, only title and size).
#   The copy is done by this function with `printf '%s'`, so quotes, `$`, backticks, `%`, `\`, unicode and newlines survive.
#   Without a clipboard tool the text is printed with a warning.
# @option -n Optional dry-run flag. The clipboard command is printed and nothing is copied.
# @option --local Optional. Only look in the project store.
# @option --global Optional. Only look in the global store.
# @option -h | --help Show help and return.
# @arg $1 string The slug.
# @arg $@ string Optional. Values as `name=value`.
# @exitcode 0 Copied (or printed, or dry-run).
# @exitcode 1 The clipboard tool failed.
# @exitcode 2 Invalid input or a placeholder without value.
# @exitcode 3 Not found.
# @example
#   shell::prompt::copy code-review
#   shell::prompt::copy summary topic="the release notes"
#
shell::prompt::copy() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Render a prompt and copy it to the clipboard" \
			"shell::prompt::copy [-n] [--local|--global] <slug> [name=value ...]" \
			"shell::prompt::copy summary topic=\"release notes\"" "-n::Dry-run: print the command instead of executing it" \
			"--local::Only the project store" "--global::Only the global store" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local dry_run="false" flag=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n) dry_run="true" ;;
		--local) flag="local" ;;
		--global) flag="global" ;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done
	[ "$#" -ge 1 ] || {
		shell::logger::error "Usage: shell::prompt::copy [-n] [--local|--global] <slug> [name=value ...]"
		return "$RETURN_INVALID"
	}
	local slug="$1"
	shift
	_shell::prompt::kv_check "$@" || return "$RETURN_INVALID"
	_shell::prompt::scoped _shell::prompt::render::inner copy "$flag" "$slug" "$dry_run" "$@"
}

# @description Tell whether a prompt exists. Prints `true` or `false`, like shell::conf::key::exists.
# @option --local Optional. Only look in the project store.
# @option --global Optional. Only look in the global store.
# @option -h | --help Show help and return.
# @arg $1 string The slug.
# @stdout `true` or `false`.
# @exitcode 0 The prompt exists.
# @exitcode 1 It does not.
# @exitcode 2 Invalid slug.
# @example
#   [ "$(shell::prompt::exists code-review)" = "true" ] && echo found
#
shell::prompt::exists() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Print true when the prompt exists, false otherwise" \
			"shell::prompt::exists [--local|--global] <slug>" "shell::prompt::exists code-review" \
			"--local::Only the project store" "--global::Only the global store" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local flag=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--local) flag="local" ;;
		--global) flag="global" ;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done
	[ "$#" -eq 1 ] || {
		shell::logger::error "Usage: shell::prompt::exists [--local|--global] <slug>"
		return "$RETURN_INVALID"
	}
	_shell::prompt::need_slug "$1" || return "$RETURN_INVALID"
	if _shell::prompt::resolve "$flag" "$1" >/dev/null 2>&1; then
		printf 'true\n'
		return "$RETURN_SUCCESS"
	fi
	printf 'false\n'
	return "$RETURN_FAILURE"
}

# @description List prompts: scope, slug, title, tags and last update. Output is tab-separated (aligned when stdout is a terminal).
# @option --local Optional. Only the project store.
# @option --global Optional. Only the global store.
# @option --all Optional. Both stores (default).
# @option --tag <tag> Optional. Only prompts with this tag.
# @option --removed Optional. List the removed prompts that can still be restored from history.
# @option -h | --help Show help and return.
# @stdout One line per prompt: `G|L`, slug, title, tags, updated.
# @exitcode 0 Success (an empty store prints nothing).
# @exitcode 2 Invalid option.
# @example
#   shell::prompt::list
#   shell::prompt::list --tag review --global
#
shell::prompt::list() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "List the prompts of the stores" "shell::prompt::list [--local|--global|--all] [--tag <tag>] [--removed]" \
			"shell::prompt::list --tag review" "--local::Only the project store" "--global::Only the global store" \
			"--all::Both stores (default)" "--tag <tag>::Only prompts with this tag" \
			"--removed::List removed prompts that history can restore" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local flag="" tag="" removed="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--local) flag="local" ;;
		--global) flag="global" ;;
		--all) flag="" ;;
		--removed) removed="true" ;;
		--tag)
			[ "$#" -ge 2 ] || {
				shell::logger::error "Option --tag requires a value"
				return "$RETURN_INVALID"
			}
			tag="$(_shell::prompt::norm_tags "$2")"
			shift
			;;
		*)
			shell::logger::error "Unknown argument: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done
	if [ "$removed" = "true" ]; then
		_shell::prompt::removed "$flag"
		return "$RETURN_SUCCESS"
	fi
	if [ -t 1 ] && command -v column >/dev/null 2>&1; then
		_shell::prompt::rows "$flag" tsv "" "$tag" | column -t -s "$(printf '\t')"
	else
		_shell::prompt::rows "$flag" tsv "" "$tag"
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description List the prompts that have snapshots but no live file (removed), as `G|L<TAB>slug<TAB>snapshots`.
# @arg $1 string Scope filter or empty.
# @stdout The rows.
# @exitcode 0 Always.
# @example
#   _shell::prompt::removed ""
#
_shell::prompt::removed() {
	local sc dir ch d slug n
	while IFS= read -r sc; do
		dir="$(_shell::prompt::dir "$sc")"
		[ -d "$dir/.history" ] || continue
		ch="G"
		[ "$sc" = "local" ] && ch="L"
		for d in "$dir"/.history/*; do
			[ -d "$d" ] || continue
			slug="${d##*/}"
			[ -f "$dir/$slug.md" ] && continue
			n="$(_shell::prompt::stamps "$sc" "$slug" | wc -l | tr -d ' ')"
			printf '%s\t%s\t%s\n' "$ch" "$slug" "$n"
		done
	done <<EOF
$(_shell::prompt::scopes "$1")
EOF
}

# @description Search prompts by words that must all appear (case-insensitive) in the title, description, tags or body.
# @option --local Optional. Only the project store.
# @option --global Optional. Only the global store.
# @option -h | --help Show help and return.
# @arg $@ string The search words.
# @stdout Matching prompts, like shell::prompt::list.
# @exitcode 0 Success (no match prints nothing).
# @exitcode 2 No query.
# @example
#   shell::prompt::search bash review
#
shell::prompt::search() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Search prompts by title, description, tags and body" "shell::prompt::search [--local|--global] <words...>" \
			"shell::prompt::search bash review" "--local::Only the project store" "--global::Only the global store" \
			"-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local flag=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--local) flag="local" ;;
		--global) flag="global" ;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done
	[ "$#" -ge 1 ] || {
		shell::logger::error "Usage: shell::prompt::search [--local|--global] <words...>"
		return "$RETURN_INVALID"
	}
	if [ -t 1 ] && command -v column >/dev/null 2>&1; then
		_shell::prompt::rows "$flag" tsv "$*" "" | column -t -s "$(printf '\t')"
	else
		_shell::prompt::rows "$flag" tsv "$*" ""
	fi
	return "$RETURN_SUCCESS"
}

# @description Remove a prompt. The file is MOVED into its history (`.history/<slug>/<stamp>.md`), so it can be restored
#   with shell::prompt::restore. A confirmation is asked unless `-y` or `-n` is given.
# @option -n Optional dry-run flag. The command is printed and nothing is moved.
# @option -y | --yes Optional. Skip the confirmation.
# @option --local Optional. Only the project store.
# @option --global Optional. Only the global store.
# @option -h | --help Show help and return.
# @arg $1 string The slug.
# @exitcode 0 Removed (or dry-run, or the user declined: nothing changed).
# @exitcode 1 The move failed.
# @exitcode 2 Invalid slug.
# @exitcode 3 Not found.
# @example
#   shell::prompt::remove old-draft
#   shell::prompt::remove -n old-draft
#
shell::prompt::remove() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Remove a prompt (kept in history, restorable)" "shell::prompt::remove [-n] [-y] [--local|--global] <slug>" \
			"shell::prompt::remove old-draft" "-n::Dry-run: print the command instead of executing it" \
			"-y, --yes::Skip the confirmation" "--local::Only the project store" "--global::Only the global store" \
			"-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local dry_run="false" yes="false" flag=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n) dry_run="true" ;;
		-y | --yes) yes="true" ;;
		--local) flag="local" ;;
		--global) flag="global" ;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done
	[ "$#" -eq 1 ] || {
		shell::logger::error "Usage: shell::prompt::remove [-n] [-y] [--local|--global] <slug>"
		return "$RETURN_INVALID"
	}
	local scope
	scope="$(_shell::prompt::resolve "$flag" "$1")" || return $?
	_shell::prompt::remove::do "$scope" "$1" "$dry_run" "$yes"
}

# @internal
# @description Move a prompt into its history, after confirmation.
# @arg $1 string The scope.
# @arg $2 string The slug.
# @arg $3 string `true` for dry-run.
# @arg $4 string `true` to skip the confirmation.
# @exitcode 0 Removed, dry-run, or declined.
# @exitcode 1 The move failed.
# @example
#   _shell::prompt::remove::do global old-draft false false
#
_shell::prompt::remove::do() {
	local scope="${1-}" slug="${2-}" dry_run="${3-false}" yes="${4-false}" file rc=0
	file="$(_shell::prompt::file "$scope" "$slug")"
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "mv $(printf '%q' "$file") $(printf '%q' "$(_shell::prompt::dir "$scope")/.history/$slug/<UTC-stamp>.md")"
		return "$RETURN_SUCCESS"
	fi
	if [ "$yes" != "true" ]; then
		shell::ask::accept "Remove prompt '${slug}' (${scope})? It stays in history and can be restored" || {
			shell::logger::info "Cancelled - nothing was removed"
			return "$RETURN_SUCCESS"
		}
	fi
	_shell::prompt::snapshot "$scope" "$slug" "$file" move >/dev/null || rc=$?
	if [ "$rc" -ne 0 ]; then
		shell::logger::error "Could not move '${slug}' into its history; nothing was removed."
		return "$RETURN_FAILURE"
	fi
	_shell::prompt::skills::lock::del "$scope" "$slug"
	shell::logger::success "Removed prompt '${slug}' (restore with: shell::prompt::history ${slug})"
}

# @description Rename a prompt (its slug and file; the title is kept). The history moves with it.
# @option -n Optional dry-run flag. The command is printed and nothing is renamed.
# @option --local Optional. Only the project store.
# @option --global Optional. Only the global store.
# @option -h | --help Show help and return.
# @arg $1 string The current slug.
# @arg $2 string The new slug.
# @exitcode 0 Renamed (or dry-run).
# @exitcode 1 The rename failed.
# @exitcode 2 Invalid slug.
# @exitcode 3 Not found.
# @exitcode 7 The new slug exists; nothing changed.
# @example
#   shell::prompt::rename code-review review-bash
#
shell::prompt::rename() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Rename a prompt (slug and file)" "shell::prompt::rename [-n] [--local|--global] <old> <new>" \
			"shell::prompt::rename code-review review-bash" "-n::Dry-run: print the command instead of executing it" \
			"--local::Only the project store" "--global::Only the global store" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local dry_run="false" flag=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n) dry_run="true" ;;
		--local) flag="local" ;;
		--global) flag="global" ;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done
	[ "$#" -eq 2 ] || {
		shell::logger::error "Usage: shell::prompt::rename [-n] [--local|--global] <old> <new>"
		return "$RETURN_INVALID"
	}
	local scope
	scope="$(_shell::prompt::resolve "$flag" "$1")" || return $?
	_shell::prompt::rename::do "$scope" "$1" "$2" "$dry_run"
}

# @internal
# @description Rename a prompt file and its history directory.
# @arg $1 string The scope.
# @arg $2 string The old slug.
# @arg $3 string The new slug.
# @arg $4 string `true` for dry-run.
# @exitcode 0 Renamed or dry-run.
# @exitcode 1 Failed.
# @exitcode 2 Invalid new slug.
# @exitcode 7 The new slug exists.
# @example
#   _shell::prompt::rename::do global old new false
#
_shell::prompt::rename::do() {
	local scope="${1-}" old="${2-}" new="${3-}" dry_run="${4-false}" dir
	_shell::prompt::need_slug "$new" || return "$RETURN_INVALID"
	dir="$(_shell::prompt::dir "$scope")"
	if [ "$old" = "$new" ]; then
		shell::logger::info "Same slug - nothing to rename"
		return "$RETURN_SUCCESS"
	fi
	if [ -e "$dir/$new.md" ] || [ -e "$dir/.history/$new" ]; then
		shell::logger::error "'${new}' already exists (prompt or history) in the $scope store; nothing was renamed."
		return "$RETURN_EXISTS"
	fi
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "mv $(printf '%q' "$dir/$old.md") $(printf '%q' "$dir/$new.md")"
		return "$RETURN_SUCCESS"
	fi
	mv -- "$dir/$old.md" "$dir/$new.md" || {
		shell::logger::error "Could not rename '${old}'."
		return "$RETURN_FAILURE"
	}
	if [ -d "$dir/.history/$old" ]; then
		mv -- "$dir/.history/$old" "$dir/.history/$new" || shell::logger::warn "The prompt was renamed but its history stayed under '${old}'."
	fi
	_shell::prompt::skills::lock::move "$scope" "$old" "$new"
	shell::logger::success "Renamed '${old}' to '${new}'"
}

# @description Clone a prompt under a new slug (the title gets " (copy)"). An existing slug is never overwritten.
# @option -n Optional dry-run flag. The command is printed and nothing is written.
# @option --local Optional. Only the project store.
# @option --global Optional. Only the global store.
# @option -h | --help Show help and return.
# @arg $1 string The source slug.
# @arg $2 string The new slug.
# @exitcode 0 Cloned (or dry-run).
# @exitcode 1 The write failed.
# @exitcode 2 Invalid slug.
# @exitcode 3 Not found.
# @exitcode 7 The new slug exists.
# @example
#   shell::prompt::clone code-review code-review-strict
#
shell::prompt::clone() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Clone a prompt under a new slug" "shell::prompt::clone [-n] [--local|--global] <slug> <new>" \
			"shell::prompt::clone code-review code-review-strict" "-n::Dry-run: print the command instead of executing it" \
			"--local::Only the project store" "--global::Only the global store" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local dry_run="false" flag=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n) dry_run="true" ;;
		--local) flag="local" ;;
		--global) flag="global" ;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done
	[ "$#" -eq 2 ] || {
		shell::logger::error "Usage: shell::prompt::clone [-n] [--local|--global] <slug> <new>"
		return "$RETURN_INVALID"
	}
	local scope
	scope="$(_shell::prompt::resolve "$flag" "$1")" || return $?
	_shell::prompt::scoped _shell::prompt::clone::inner "$scope" "$1" "$2" "$dry_run"
}

# @internal
# @description Clone a prompt inside a work directory.
# @arg $1 string The work directory.
# @arg $2 string The scope.
# @arg $3 string The source slug.
# @arg $4 string The new slug.
# @arg $5 string `true` for dry-run.
# @exitcode 0 Cloned or dry-run.
# @exitcode 7 The new slug exists.
# @example
#   _shell::prompt::scoped _shell::prompt::clone::inner global a b false
#
_shell::prompt::clone::inner() {
	local work="${1-}" scope="${2-}" slug="${3-}" new="${4-}" dry_run="${5-false}" file
	_shell::prompt::need_slug "$new" || return "$RETURN_INVALID"
	file="$(_shell::prompt::file "$scope" "$slug")"
	if [ -e "$(_shell::prompt::file "$scope" "$new")" ]; then
		shell::logger::error "Prompt '${new}' already exists in the $scope store; nothing was overwritten."
		return "$RETURN_EXISTS"
	fi
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "cp $(printf '%q' "$file") $(printf '%q' "$(_shell::prompt::file "$scope" "$new")")"
		return "$RETURN_SUCCESS"
	fi
	_shell::prompt::body_stream "$file" >"$work/body" || return "$RETURN_FAILURE"
	_shell::prompt::store "$scope" "$new" "$(_shell::prompt::meta "$file" title) (copy)" "$(_shell::prompt::meta "$file" description)" \
		"$(_shell::prompt::meta "$file" tags)" "" "$work/body" new || return $?
	shell::logger::success "Cloned '${slug}' to '${new}'"
}

# @internal
# @description Change the tags of a prompt (snapshot first, atomic write).
# @arg $1 string The scope.
# @arg $2 string The slug.
# @arg $3 string `add` or `remove`.
# @arg $4 string `true` for dry-run.
# @arg $@ string The tags.
# @exitcode 0 Changed, unchanged or dry-run.
# @exitcode 1 Failed.
# @example
#   _shell::prompt::tags::change global code-review add false bash review
#
_shell::prompt::tags::change() {
	local scope="${1-}" slug="${2-}" op="${3-}" dry_run="${4-false}" file tags new t work rc=0
	shift 4
	file="$(_shell::prompt::file "$scope" "$slug")"
	tags="$(_shell::prompt::meta "$file" tags)"
	new="$(_shell::prompt::norm_tags "$*")"
	if [ -z "$new" ]; then
		shell::logger::error "Give at least one valid tag (letters, digits, '_' and '-')."
		return "$RETURN_INVALID"
	fi
	if [ "$op" = "add" ]; then
		new="$(_shell::prompt::norm_tags "$tags,$new")"
	else
		local keep=""
		while IFS= read -r t; do
			[ -n "$t" ] || continue
			case ",${new}," in *",${t},"*) ;; *) keep="${keep:+$keep,}$t" ;; esac
		done <<EOF
$(printf '%s' "$tags" | tr ',' '\n')
EOF
		new="$keep"
	fi
	if [ "$new" = "$tags" ]; then
		shell::logger::info "Tags of '${slug}' unchanged"
		return "$RETURN_SUCCESS"
	fi
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "shell::prompt::tag::${op} ${slug} -> tags: ${new:-<none>}"
		return "$RETURN_SUCCESS"
	fi
	work="$(mktemp "$(_shell::prompt::dir "$scope")/.tmp.XXXXXX")" || return "$RETURN_FAILURE"
	_shell::prompt::body_stream "$file" >"$work" || rc=$?
	if [ "$rc" -eq 0 ]; then
		_shell::prompt::snapshot "$scope" "$slug" "$file" >/dev/null || rc=$?
	fi
	if [ "$rc" -eq 0 ]; then
		_shell::prompt::write "$file" "$(_shell::prompt::meta "$file" title)" "$(_shell::prompt::meta "$file" description)" "$new" \
			"$(_shell::prompt::meta "$file" created)" "$(_shell::prompt::now)" "$work" || rc=$?
	fi
	rm -f -- "$work"
	if [ "$rc" -ne 0 ]; then
		shell::logger::error "Could not change the tags of '${slug}'."
		return "$RETURN_FAILURE"
	fi
	shell::logger::success "Tags of '${slug}': ${new:-<none>}"
}

# @description Add tags to a prompt (a snapshot is kept in history first).
# @option -n Optional dry-run flag. The change is printed and nothing is written.
# @option --local Optional. Only the project store.
# @option --global Optional. Only the global store.
# @option -h | --help Show help and return.
# @arg $1 string The slug.
# @arg $@ string The tags to add (comma or space separated; lowercased, [a-z0-9_-]).
# @exitcode 0 Done (or dry-run).
# @exitcode 1 The write failed.
# @exitcode 2 Invalid input.
# @exitcode 3 Not found.
# @example
#   shell::prompt::tag::add code-review bash quality
#
shell::prompt::tag::add() {
	_shell::prompt::tag::cli add "$@"
}

# @description Remove tags from a prompt (a snapshot is kept in history first).
# @option -n Optional dry-run flag. The change is printed and nothing is written.
# @option --local Optional. Only the project store.
# @option --global Optional. Only the global store.
# @option -h | --help Show help and return.
# @arg $1 string The slug.
# @arg $@ string The tags to remove.
# @exitcode 0 Done (or dry-run).
# @exitcode 1 The write failed.
# @exitcode 2 Invalid input.
# @exitcode 3 Not found.
# @example
#   shell::prompt::tag::remove code-review quality
#
shell::prompt::tag::remove() {
	_shell::prompt::tag::cli remove "$@"
}

# @internal
# @description Shared body of shell::prompt::tag::add and ::remove.
# @arg $1 string `add` or `remove`.
# @arg $@ string The arguments of the public function.
# @exitcode 0 Done.
# @exitcode 2 Invalid input.
# @example
#   _shell::prompt::tag::cli add code-review bash
#
_shell::prompt::tag::cli() {
	local op="${1-add}"
	shift
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "${op} tags on a prompt" "shell::prompt::tag::${op} [-n] [--local|--global] <slug> <tag...>" \
			"shell::prompt::tag::${op} code-review bash" "-n::Dry-run: print the change instead of writing it" \
			"--local::Only the project store" "--global::Only the global store" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local dry_run="false" flag=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n) dry_run="true" ;;
		--local) flag="local" ;;
		--global) flag="global" ;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done
	[ "$#" -ge 2 ] || {
		shell::logger::error "Usage: shell::prompt::tag::${op} [-n] [--local|--global] <slug> <tag...>"
		return "$RETURN_INVALID"
	}
	local scope slug="$1"
	shift
	scope="$(_shell::prompt::resolve "$flag" "$slug")" || return $?
	_shell::prompt::tags::change "$scope" "$slug" "$op" "$dry_run" "$@"
}

# @description Export one prompt (a Markdown file) or the whole store (a .tar.gz) to a file or directory.
#   Nothing is overwritten without a confirmation. History is not exported.
# @option -n Optional dry-run flag. The command is printed and nothing is written.
# @option --local Optional. Only the project store.
# @option --global Optional. Only the global store.
# @option -h | --help Show help and return.
# @arg $1 string A slug, or `--all`.
# @arg $2 string The destination file or an existing directory.
# @exitcode 0 Exported (or dry-run, or the user declined).
# @exitcode 1 The export failed.
# @exitcode 2 Invalid input.
# @exitcode 3 Not found.
# @example
#   shell::prompt::export code-review ~/Desktop
#   shell::prompt::export --all ~/prompts-backup.tar.gz
#
shell::prompt::export() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Export a prompt (.md) or the whole store (.tar.gz)" "shell::prompt::export [-n] [--local|--global] <slug|--all> <file|dir>" \
			"shell::prompt::export --all ~/prompts-backup.tar.gz" "-n::Dry-run: print the command instead of executing it" \
			"--local::Only the project store" "--global::Only the global store" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local dry_run="false" flag=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n) dry_run="true" ;;
		--local) flag="local" ;;
		--global) flag="global" ;;
		--all) break ;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done
	[ "$#" -eq 2 ] || {
		shell::logger::error "Usage: shell::prompt::export [-n] [--local|--global] <slug|--all> <file|dir>"
		return "$RETURN_INVALID"
	}
	local what="$1" dest="$2" scope src out slug dir
	if [ "$what" = "--all" ]; then
		scope="${flag:-global}"
		dir="$(_shell::prompt::dir "$scope")"
		[ -d "$dir" ] || {
			shell::logger::error "The $scope store is empty or missing."
			return "$RETURN_NOT_FOUND"
		}
		[ -d "$dest" ] && dest="${dest%/}/prompts-$(date -u '+%Y%m%dT%H%M%SZ').tar.gz"
		local -a names=()
		while IFS= read -r slug; do
			[ -n "$slug" ] && names+=("$slug.md")
		done <<EOF
$(_shell::prompt::rows "$scope" tsv "" "" | awk -F'\t' '{ print $2 }')
EOF
		if [ "${#names[@]}" -eq 0 ]; then
			shell::logger::error "No prompt to export."
			return "$RETURN_EMPTY"
		fi
		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "tar -czf $(printf '%q' "$dest") -C $(printf '%q' "$dir") ${#names[@]} files"
			return "$RETURN_SUCCESS"
		fi
		_shell::prompt::export::confirm "$dest" || return "$RETURN_SUCCESS"
		out="$(umask 077 && mktemp "${dest}.XXXXXX")" || return "$RETURN_FAILURE"
		if tar -czf "$out" -C "$dir" -- "${names[@]}"; then
			mv -f -- "$out" "$dest" || {
				rm -f -- "$out"
				return "$RETURN_FAILURE"
			}
			shell::logger::success "Exported ${#names[@]} prompts to ${dest}"
			return "$RETURN_SUCCESS"
		fi
		rm -f -- "$out"
		shell::logger::error "tar failed."
		return "$RETURN_FAILURE"
	fi
	scope="$(_shell::prompt::resolve "$flag" "$what")" || return $?
	src="$(_shell::prompt::file "$scope" "$what")"
	[ -d "$dest" ] && dest="${dest%/}/$what.md"
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "cp $(printf '%q' "$src") $(printf '%q' "$dest")"
		return "$RETURN_SUCCESS"
	fi
	_shell::prompt::export::confirm "$dest" || return "$RETURN_SUCCESS"
	out="$(umask 077 && mktemp "${dest}.XXXXXX")" || return "$RETURN_FAILURE"
	if cp -- "$src" "$out" && mv -f -- "$out" "$dest"; then
		shell::logger::success "Exported '${what}' to ${dest}"
		return "$RETURN_SUCCESS"
	fi
	rm -f -- "$out"
	shell::logger::error "Could not write ${dest}."
	return "$RETURN_FAILURE"
}

# @internal
# @description Ask before overwriting an export destination (silent when it does not exist).
# @arg $1 string The destination.
# @exitcode 0 Free to write.
# @exitcode 1 The user declined (logged).
# @example
#   _shell::prompt::export::confirm "$dest" || return 0
#
_shell::prompt::export::confirm() {
	[ -e "${1-}" ] || return "$RETURN_SUCCESS"
	shell::ask::accept "'${1}' exists. Overwrite it?" && return "$RETURN_SUCCESS"
	shell::logger::info "Cancelled - nothing was written"
	return "$RETURN_FAILURE"
}

# @internal
# @description Import one text file as a prompt. A file with valid front matter keeps its fields; any other text file
#   becomes a prompt titled after its file name. An existing slug is replaced only after confirmation (and a snapshot).
# @arg $1 string The scope.
# @arg $2 string The file.
# @arg $3 string `true` for dry-run.
# @arg $4 string `true` to replace without asking.
# @exitcode 0 Imported, dry-run or skipped by the user.
# @exitcode 1 Failed.
# @exitcode 2 Not a valid text prompt.
# @example
#   _shell::prompt::import::file global ./review.md false false
#
_shell::prompt::import::file() {
	local scope="${1-}" src="${2-}" dry_run="${3-false}" yes="${4-false}" stem slug title desc tags created work off mode="new" bytes
	local file
	if [ ! -f "$src" ] || [ ! -r "$src" ]; then
		shell::logger::error "Cannot read '$src'."
		return "$RETURN_INVALID"
	fi
	bytes="$(wc -c <"$src" | tr -d ' ')"
	if [ "$bytes" -gt "$SHELL_PROMPT_MAX_BYTES" ]; then
		shell::logger::error "'${src}' is larger than ${SHELL_PROMPT_MAX_BYTES} bytes."
		return "$RETURN_INVALID"
	fi
	if ! tr -d '\000' <"$src" | cmp -s - "$src"; then
		shell::logger::error "'${src}' is not a text file."
		return "$RETURN_INVALID"
	fi
	stem="${src##*/}"
	stem="${stem%.md}"
	work="$(mktemp "${TMPDIR:-/tmp}/shell-prompt-import.XXXXXX")" || return "$RETURN_FAILURE"
	if off="$(_shell::prompt::body_offset "$src")"; then
		_shell::prompt::validate "$src" || {
			rm -f -- "$work"
			return "$RETURN_INVALID"
		}
		title="$(_shell::prompt::meta "$src" title)"
		desc="$(_shell::prompt::meta "$src" description)"
		tags="$(_shell::prompt::norm_tags "$(_shell::prompt::meta "$src" tags)")"
		created="$(_shell::prompt::meta "$src" created)"
		tail -n +"$off" "$src" >"$work"
	else
		title="$(printf '%s' "$stem" | tr '_-' '  ')"
		desc=""
		tags=""
		created=""
		cat -- "$src" >"$work"
		if ! grep -q '[^[:space:]]' "$work"; then
			rm -f -- "$work"
			shell::logger::error "'${src}' is empty."
			return "$RETURN_INVALID"
		fi
	fi
	slug="$(_shell::prompt::slugify "$stem")" || slug="$(_shell::prompt::slugify "$title")" || {
		rm -f -- "$work"
		shell::logger::error "Cannot derive a slug for '${src}'."
		return "$RETURN_INVALID"
	}
	file="$(_shell::prompt::file "$scope" "$slug")"
	if [ "$dry_run" = "true" ]; then
		rm -f -- "$work"
		shell::logger::command_clip "shell::prompt::import ${src} -> ${scope}/${slug}$([ -e "$file" ] && printf ' (would ask before replacing)')"
		return "$RETURN_SUCCESS"
	fi
	if [ -e "$file" ]; then
		if [ "$yes" != "true" ]; then
			if [ ! -t 0 ]; then
				rm -f -- "$work"
				shell::logger::warn "Prompt '${slug}' exists; skipped (no terminal to confirm; use -y to replace)."
				return "$RETURN_SUCCESS"
			fi
			shell::ask::accept "Prompt '${slug}' exists in the $scope store. Replace it (a snapshot is kept)?" || {
				rm -f -- "$work"
				shell::logger::info "Skipped '${slug}'"
				return "$RETURN_SUCCESS"
			}
		fi
		mode="replace"
	fi
	_shell::prompt::store "$scope" "$slug" "$title" "$desc" "$tags" "$created" "$work" "$mode"
	local rc=$?
	rm -f -- "$work"
	[ "$rc" -eq 0 ] && shell::logger::success "Imported '${slug}' (${scope})"
	return "$rc"
}

# @description Import a prompt file, every `*.md` of a directory, or a text file from an http(s) URL.
#   Files are validated (text only, size limit, front matter); a file without front matter becomes a prompt titled after its
#   name. An existing prompt is replaced only after confirmation. A URL is shown and ALWAYS needs a confirmation, and
#   non-text content is rejected.
# @option -n Optional dry-run flag. The command is printed and nothing is written or downloaded.
# @option -y | --yes Optional. Replace existing prompts without asking (never skips the URL confirmation).
# @option --local Optional. Import into the project store.
# @option -h | --help Show help and return.
# @arg $1 string A file, a directory or an http(s) URL.
# @exitcode 0 Imported (or dry-run, or skipped by the user).
# @exitcode 1 Failed.
# @exitcode 2 Invalid input.
# @exitcode 3 Nothing found (or curl missing for a URL).
# @example
#   shell::prompt::import ./review.md
#   shell::prompt::import ~/prompts-backup/
#   shell::prompt::import https://example.com/prompts/review.md
#
shell::prompt::import() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Import a prompt file, a directory of .md files or an http(s) URL" "shell::prompt::import [-n] [-y] [--local] <file|dir|url>" \
			"shell::prompt::import ./review.md" "-n::Dry-run: print the command instead of executing it" \
			"-y, --yes::Replace existing prompts without asking" "--local::Import into the project store" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local dry_run="false" yes="false" scope="global"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n) dry_run="true" ;;
		-y | --yes) yes="true" ;;
		--local) scope="local" ;;
		--global) scope="global" ;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done
	[ "$#" -eq 1 ] || {
		shell::logger::error "Usage: shell::prompt::import [-n] [-y] [--local] <file|dir|url>"
		return "$RETURN_INVALID"
	}
	local src="$1" f count=0 rc=0 work ctype
	case "$src" in
	http://* | https://*)
		command -v curl >/dev/null 2>&1 || {
			shell::logger::error "curl is required to import from a URL."
			return "$RETURN_NOT_FOUND"
		}
		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "curl -fsSL --max-time 30 --max-filesize ${SHELL_PROMPT_MAX_BYTES} $(printf '%q' "$src")"
			return "$RETURN_SUCCESS"
		fi
		shell::logger::warn "Source: ${src}"
		[ -t 0 ] || {
			shell::logger::error "Importing from a URL needs a terminal to confirm."
			return "$RETURN_FAILURE"
		}
		shell::ask::accept "Download this URL and import it as a prompt?" || {
			shell::logger::info "Cancelled - nothing was downloaded"
			return "$RETURN_SUCCESS"
		}
		work="$(mktemp -d "${TMPDIR:-/tmp}/shell-prompt-url.XXXXXX")" || return "$RETURN_FAILURE"
		ctype="$(curl -fsSL --proto '=http,https' --proto-redir '=http,https' --max-time 30 --max-filesize "$SHELL_PROMPT_MAX_BYTES" \
			-o "$work/download" -w '%{content_type}' "$src")" || {
			rm -rf -- "$work"
			shell::logger::error "Download failed."
			return "$RETURN_FAILURE"
		}
		case "$ctype" in
		text/* | '') ;;
		*)
			rm -rf -- "$work"
			shell::logger::error "Rejected: the server sent '${ctype}', not text."
			return "$RETURN_INVALID"
			;;
		esac
		f="${src%%\?*}"
		f="${f##*/}"
		[ -n "$f" ] || f="prompt.md"
		mv -- "$work/download" "$work/$f"
		_shell::prompt::import::file "$scope" "$work/$f" false "$yes" || rc=$?
		rm -rf -- "$work"
		return "$rc"
		;;
	esac
	if [ -d "$src" ]; then
		# fd 3 (not stdin): the confirmation of a collision must read the terminal.
		while IFS= read -r f <&3; do
			[ -n "$f" ] || continue
			count=$((count + 1))
			_shell::prompt::import::file "$scope" "$f" "$dry_run" "$yes" || rc=1
		done 3<<EOF
$(find "$src" -maxdepth 1 -type f -name '*.md' ! -name '.*' | LC_ALL=C sort)
EOF
		if [ "$count" -eq 0 ]; then
			shell::logger::error "No .md file in '$src'."
			return "$RETURN_NOT_FOUND"
		fi
		return "$rc"
	fi
	if [ ! -e "$src" ]; then
		shell::logger::error "'$src' does not exist."
		return "$RETURN_NOT_FOUND"
	fi
	_shell::prompt::import::file "$scope" "$src" "$dry_run" "$yes"
}

# @description List the history of a prompt: the snapshots taken before every edit, overwrite and removal (newest first).
#   Also works for a removed prompt, which is how you find what to restore.
# @option --local Optional. Only the project store.
# @option --global Optional. Only the global store.
# @option -h | --help Show help and return.
# @arg $1 string The slug.
# @stdout One line per snapshot: stamp, size in bytes, title.
# @exitcode 0 Listed.
# @exitcode 2 Invalid slug.
# @exitcode 3 No history.
# @example
#   shell::prompt::history code-review
#
shell::prompt::history() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "List the snapshots of a prompt" "shell::prompt::history [--local|--global] <slug>" \
			"shell::prompt::history code-review" "--local::Only the project store" "--global::Only the global store" \
			"-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local flag=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--local) flag="local" ;;
		--global) flag="global" ;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done
	[ "$#" -eq 1 ] || {
		shell::logger::error "Usage: shell::prompt::history [--local|--global] <slug>"
		return "$RETURN_INVALID"
	}
	_shell::prompt::need_slug "$1" || return "$RETURN_INVALID"
	local scope sc found="" stamp f
	for sc in local global; do
		[ -n "$flag" ] && [ "$sc" != "$flag" ] && continue
		[ "$sc" = "local" ] && [ ! -d "$(_shell::prompt::dir local)" ] && continue
		if [ -n "$(_shell::prompt::stamps "$sc" "$1")" ]; then
			scope="$sc"
			found="yes"
			break
		fi
	done
	if [ -z "$found" ]; then
		shell::logger::error "No history for '$1'."
		return "$RETURN_NOT_FOUND"
	fi
	while IFS= read -r stamp; do
		f="$(_shell::prompt::dir "$scope")/.history/$1/$stamp.md"
		printf '%s\t%s\t%s\n' "$stamp" "$(wc -c <"$f" | tr -d ' ')" "$(_shell::prompt::meta "$f" title)"
	done <<EOF
$(_shell::prompt::stamps "$scope" "$1")
EOF
}

# @internal
# @description Restore a snapshot as the live prompt: the current file is snapshotted first, then replaced atomically.
#   Works for a removed prompt too (the file is recreated).
# @arg $1 string The scope.
# @arg $2 string The slug.
# @arg $3 string The snapshot stamp.
# @arg $4 string `true` for dry-run.
# @exitcode 0 Restored or dry-run.
# @exitcode 1 Failed.
# @exitcode 2 Invalid stamp.
# @exitcode 3 No such snapshot.
# @example
#   _shell::prompt::restore::do global code-review 20261114T100000Z false
#
_shell::prompt::restore::do() {
	local scope="${1-}" slug="${2-}" stamp="${3-}" dry_run="${4-false}" snap file work rc=0
	case "$stamp" in
	'' | *[!0-9TZ-]*)
		shell::logger::error "Invalid timestamp '${stamp}' (see shell::prompt::history)."
		return "$RETURN_INVALID"
		;;
	esac
	snap="$(_shell::prompt::dir "$scope")/.history/$slug/$stamp.md"
	file="$(_shell::prompt::file "$scope" "$slug")"
	if [ ! -f "$snap" ]; then
		shell::logger::error "No snapshot '${stamp}' for '${slug}'."
		return "$RETURN_NOT_FOUND"
	fi
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "restore $(printf '%q' "$snap") -> $(printf '%q' "$file")"
		return "$RETURN_SUCCESS"
	fi
	_shell::prompt::validate "$snap" || return "$RETURN_FAILURE"
	_shell::prompt::init "$scope" || return "$RETURN_FAILURE"
	work="$(mktemp "$(_shell::prompt::dir "$scope")/.tmp.XXXXXX")" || return "$RETURN_FAILURE"
	_shell::prompt::body_stream "$snap" >"$work" || rc=$?
	if [ "$rc" -eq 0 ] && [ -f "$file" ]; then
		_shell::prompt::snapshot "$scope" "$slug" "$file" >/dev/null || rc=$?
	fi
	if [ "$rc" -eq 0 ]; then
		_shell::prompt::write "$file" "$(_shell::prompt::meta "$snap" title)" "$(_shell::prompt::meta "$snap" description)" \
			"$(_shell::prompt::meta "$snap" tags)" "$(_shell::prompt::meta "$snap" created)" "$(_shell::prompt::now)" "$work" || rc=$?
	fi
	rm -f -- "$work"
	if [ "$rc" -ne 0 ]; then
		shell::logger::error "Could not restore '${slug}'."
		return "$RETURN_FAILURE"
	fi
	shell::logger::success "Restored '${slug}' from ${stamp}"
}

# @description Restore a prompt from a snapshot. The current version (if any) is snapshotted first, so a restore can be undone;
#   a removed prompt is recreated.
# @option -n Optional dry-run flag. The command is printed and nothing is written.
# @option --local Optional. Only the project store.
# @option --global Optional. Only the global store.
# @option -h | --help Show help and return.
# @arg $1 string The slug.
# @arg $2 string The snapshot stamp, as printed by shell::prompt::history.
# @exitcode 0 Restored (or dry-run).
# @exitcode 1 The write failed.
# @exitcode 2 Invalid input.
# @exitcode 3 No such snapshot.
# @example
#   shell::prompt::restore code-review 20261114T100000Z
#
shell::prompt::restore() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Restore a prompt from a history snapshot" "shell::prompt::restore [-n] [--local|--global] <slug> <timestamp>" \
			"shell::prompt::restore code-review 20261114T100000Z" "-n::Dry-run: print the command instead of executing it" \
			"--local::Only the project store" "--global::Only the global store" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local dry_run="false" flag=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n) dry_run="true" ;;
		--local) flag="local" ;;
		--global) flag="global" ;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done
	[ "$#" -eq 2 ] || {
		shell::logger::error "Usage: shell::prompt::restore [-n] [--local|--global] <slug> <timestamp>"
		return "$RETURN_INVALID"
	}
	_shell::prompt::need_slug "$1" || return "$RETURN_INVALID"
	local scope sc
	if [ -n "$flag" ]; then
		scope="$flag"
	else
		scope="global"
		for sc in local global; do
			if [ -f "$(_shell::prompt::dir "$sc")/.history/$1/$2.md" ]; then
				scope="$sc"
				break
			fi
		done
	fi
	_shell::prompt::restore::do "$scope" "$1" "$2" "$dry_run"
}
