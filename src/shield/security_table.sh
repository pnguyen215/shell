#!/usr/bin/env bash
# @file shield/security_table.sh
# @brief Generic multi-column table renderer for the security modules (text, JSON, Markdown, CSV).
# @description
#   Used for inventories that are data, not findings (for example the connection table). CSV and
#   JSON are produced in one awk pass, so a table of hundreds of rows costs no per-cell fork. CSV
#   cells starting with `= + - @` get a leading apostrophe (spreadsheet formula injection). The
#   Markdown format reuses `shell::markdown::*` and supports 2 to 8 columns.

# @description Render multi-column records read from standard input as a table.
#   The first line of text and CSV output is the header; JSON is an array of objects keyed by the
#   column names. Empty input prints the header only (text, CSV, Markdown) or `[]` (JSON).
# @internal
# @arg $1 string Format: text, json, markdown or csv.
# @arg $2 string Column names, separated by spaces (no spaces inside a name).
# @arg $3 string Field separator of the input records.
# @stdout The table.
# @exitcode 0 Success.
# @exitcode 2 Unknown format, or too many columns for Markdown.
# @example
#   printf 'a\037b\n' | _shell::security::render::table csv "first second" "$(printf '\037')"
#
_shell::security::render::table() {
	local format="${1-text}" cols="${2-}" sep="${3-$SHELL_SECURITY_SEP}"
	local data
	data="$(cat)"
	case "$format" in
	text)
		{
			printf '%s\n' "$cols" | tr ' ' "$sep"
			[ -z "$data" ] || printf '%s\n' "$data"
		} | awk -F"$sep" '
			{ for (i = 1; i <= NF; i++) { c[NR, i] = $i; if (length($i) > w[i]) w[i] = length($i) } if (NF > m) m = NF }
			END { for (r = 1; r <= NR; r++) { line = ""; for (i = 1; i <= m; i++) line = line sprintf("%-" w[i] "s  ", c[r, i]); sub(/ +$/, "", line); print line } }'
		;;
	csv)
		{
			printf '%s\n' "$cols" | tr ' ' "$sep"
			[ -z "$data" ] || printf '%s\n' "$data"
		} | awk -F"$sep" '
			function cell(v) {
				if (v ~ /^[=+@-]/) v = "\047" v
				gsub(/"/, "\"\"", v)
				return "\"" v "\""
			}
			{ line = ""; for (i = 1; i <= NF; i++) line = line (i > 1 ? "," : "") cell($i); print line }'
		;;
	json)
		printf '%s\n' "$data" | awk -F"$sep" -v cols="$cols" '
			function js(v) {
				gsub(/\\/, "\\\\", v); gsub(/"/, "\\\"", v); gsub(/\t/, "\\t", v)
				gsub(/[\001-\010\013\014\016-\037\177]/, "", v)
				return "\"" v "\""
			}
			BEGIN { n = split(cols, name, " "); printf "[" }
			NF > 0 { if (rows++) printf ","; printf "{"; for (i = 1; i <= n; i++) printf "%s%s:%s", (i > 1 ? "," : ""), js(name[i]), js($i); printf "}" }
			END { printf "]\n" }'
		;;
	markdown)
		local n f1 f2 f3 f4 f5 f6 f7 f8 c1 c2 c3 c4 c5 c6 c7 c8
		n="$(printf '%s\n' "$cols" | tr ' ' '\n' | grep -c .)"
		if [ "$n" -lt 2 ] || [ "$n" -gt 8 ]; then
			shell::logger::error "Markdown tables support 2 to 8 columns (got $n)"
			return "$RETURN_INVALID"
		fi
		IFS=' ' read -r c1 c2 c3 c4 c5 c6 c7 c8 <<<"$cols"
		shell::markdown::init -f markdown || return "$?"
		case "$n" in
		2) shell::markdown::table_header "$c1" "$c2" ;;
		3) shell::markdown::table_header "$c1" "$c2" "$c3" ;;
		4) shell::markdown::table_header "$c1" "$c2" "$c3" "$c4" ;;
		5) shell::markdown::table_header "$c1" "$c2" "$c3" "$c4" "$c5" ;;
		6) shell::markdown::table_header "$c1" "$c2" "$c3" "$c4" "$c5" "$c6" ;;
		7) shell::markdown::table_header "$c1" "$c2" "$c3" "$c4" "$c5" "$c6" "$c7" ;;
		8) shell::markdown::table_header "$c1" "$c2" "$c3" "$c4" "$c5" "$c6" "$c7" "$c8" ;;
		esac
		if [ -n "$data" ]; then
			while IFS="$sep" read -r f1 f2 f3 f4 f5 f6 f7 f8; do
				case "$n" in
				2) shell::markdown::table_row "$f1" "$f2" ;;
				3) shell::markdown::table_row "$f1" "$f2" "$f3" ;;
				4) shell::markdown::table_row "$f1" "$f2" "$f3" "$f4" ;;
				5) shell::markdown::table_row "$f1" "$f2" "$f3" "$f4" "$f5" ;;
				6) shell::markdown::table_row "$f1" "$f2" "$f3" "$f4" "$f5" "$f6" ;;
				7) shell::markdown::table_row "$f1" "$f2" "$f3" "$f4" "$f5" "$f6" "$f7" ;;
				8) shell::markdown::table_row "$f1" "$f2" "$f3" "$f4" "$f5" "$f6" "$f7" "$f8" ;;
				esac
			done <<EOF
$data
EOF
		fi
		shell::markdown::table
		shell::markdown::render
		;;
	*)
		shell::logger::error "Unknown format: $format"
		return "$RETURN_INVALID"
		;;
	esac
}
