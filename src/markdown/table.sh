#!/usr/bin/env bash
# @file markdown/table.sh
# @brief Tables built with table_header, table_align, table_row and table.
# @description
#   `table_header` starts a table, `table_align` (optional) sets the alignment of each
#   column, `table_row` adds rows, `table` appends the result to the document as one
#   block and clears the table. The table is formatted when `table` is called.
#
#   Markdown: a pipe table, columns padded to their widest cell, `|` escaped as `\|`,
#   newlines in a cell written as `<br>`, alignment through the `:---:` row.
#
#   Telegram MarkdownV2 has no tables. Every row becomes a small block of lines
#   `*Header:* value`, rows separated by an empty line. Empty cells are left out, a
#   newline in a cell becomes a space and alignment does not apply. Pass plain text
#   as header cells (a bold header would nest bold inside bold).
#
#   Plain: the same blocks without markup (`Header: value`).
#
#   Rows with fewer cells than the header are padded with empty cells; extra cells add
#   columns with an empty header. Cells may contain fragments. `-h` / `--help` is
#   recognised only as the sole argument.

# @internal
# @description Join the arguments with the cell separator. Result in SHELL_MARKDOWN_OUT.
# @arg $@ string The cells.
# @set SHELL_MARKDOWN_OUT string The record.
_shell::markdown::record() {
	local out="" first=1 cell
	for cell in "$@"; do
		if [ "$first" = 1 ]; then
			out="$cell"
			first=0
		else
			out="$out$SHELL_MARKDOWN_CELL_SEP$cell"
		fi
	done
	SHELL_MARKDOWN_OUT="$out"
}

# @internal
# @description Number of cells of a record. Result in SHELL_MARKDOWN_OUT.
# @arg $1 string The record.
# @set SHELL_MARKDOWN_OUT integer The count (an empty record has one empty cell).
_shell::markdown::count() {
	local rec="${1-}" n=1
	while :; do
		case "$rec" in
		*"$SHELL_MARKDOWN_CELL_SEP"*)
			rec="${rec#*"$SHELL_MARKDOWN_CELL_SEP"}"
			n=$((n + 1))
			;;
		*) break ;;
		esac
	done
	SHELL_MARKDOWN_OUT="$n"
}

# @internal
# @description The k-th cell (1-based) of a record, empty when absent. Result in SHELL_MARKDOWN_OUT.
# @arg $1 string The record.
# @arg $2 integer The position.
# @set SHELL_MARKDOWN_OUT string The cell.
_shell::markdown::nth() {
	local rec="${1-}" k="${2-1}"
	while [ "$k" -gt 1 ]; do
		case "$rec" in
		*"$SHELL_MARKDOWN_CELL_SEP"*) rec="${rec#*"$SHELL_MARKDOWN_CELL_SEP"}" ;;
		*) rec="" ;;
		esac
		k=$((k - 1))
	done
	SHELL_MARKDOWN_OUT="${rec%%"$SHELL_MARKDOWN_CELL_SEP"*}"
}

# @internal
# @description Format one cell: escape it for the format and flatten newlines.
#   Result in SHELL_MARKDOWN_OUT.
# @arg $1 string Format.
# @arg $2 string The raw cell.
# @set SHELL_MARKDOWN_OUT string The cell.
_shell::markdown::cell() {
	local fmt="$1" bs='\'
	_shell::markdown::inline "$fmt" "$2"
	local out="${SHELL_MARKDOWN_OUT//$'\r'/}"
	if [ "$fmt" = "markdown" ]; then
		out="${out//$'\n'/<br>}"
		out="${out//|/${bs}|}"
	else
		out="${out//$'\n'/ }"
	fi
	SHELL_MARKDOWN_OUT="$out"
}

# @internal
# @description Format every cell of a record and pad it to `$3` cells. Result in SHELL_MARKDOWN_OUT.
# @arg $1 string Format.
# @arg $2 string The raw record.
# @arg $3 integer Number of cells wanted.
# @set SHELL_MARKDOWN_OUT string The formatted record.
_shell::markdown::cells() {
	local fmt="$1" rec="${2-}" want="$3"
	local out="" n=0
	while :; do
		_shell::markdown::cell "$fmt" "${rec%%"$SHELL_MARKDOWN_CELL_SEP"*}"
		if [ "$n" -eq 0 ]; then out="$SHELL_MARKDOWN_OUT"; else out="$out$SHELL_MARKDOWN_CELL_SEP$SHELL_MARKDOWN_OUT"; fi
		n=$((n + 1))
		case "$rec" in
		*"$SHELL_MARKDOWN_CELL_SEP"*) rec="${rec#*"$SHELL_MARKDOWN_CELL_SEP"}" ;;
		*) break ;;
		esac
	done
	while [ "$n" -lt "$want" ]; do
		out="$out$SHELL_MARKDOWN_CELL_SEP"
		n=$((n + 1))
	done
	SHELL_MARKDOWN_OUT="$out"
}

# @internal
# @description Pad a cell to a width according to the alignment. Result in SHELL_MARKDOWN_OUT.
# @arg $1 string The cell.
# @arg $2 integer Width.
# @arg $3 string Alignment: left, center or right.
# @set SHELL_MARKDOWN_OUT string The padded cell.
_shell::markdown::pad() {
	local cell="${1-}" width="${2-0}" align="${3-left}"
	local gap=$((width - ${#cell})) left=0 right=0
	[ "$gap" -lt 0 ] && gap=0
	case "$align" in
	right) left=$gap ;;
	center)
		left=$((gap / 2))
		right=$((gap - left))
		;;
	*) right=$gap ;;
	esac
	_shell::markdown::repeat ' ' "$left"
	local lead="$SHELL_MARKDOWN_OUT"
	_shell::markdown::repeat ' ' "$right"
	SHELL_MARKDOWN_OUT="$lead$cell$SHELL_MARKDOWN_OUT"
}

# @internal
# @description Render the pending table as a Markdown pipe table. Result in SHELL_MARKDOWN_OUT.
# @arg $1 integer Number of columns.
# @arg $2 string Formatted header record.
# @arg $3 string Formatted rows, each record ended by the row separator.
# @set SHELL_MARKDOWN_OUT string The table.
_shell::markdown::table_markdown() {
	local ncols="$1" header="$2" rows="$3"
	local k rec w rest widths="" line="" aligns="$SHELL_MARKDOWN_TABLE_ALIGN" a dashes
	local all="$header$SHELL_MARKDOWN_ROW_SEP$rows"

	k=1
	while [ "$k" -le "$ncols" ]; do
		w=3
		rest="$all"
		while [ -n "$rest" ]; do
			rec="${rest%%"$SHELL_MARKDOWN_ROW_SEP"*}"
			rest="${rest#*"$SHELL_MARKDOWN_ROW_SEP"}"
			_shell::markdown::nth "$rec" "$k"
			[ "${#SHELL_MARKDOWN_OUT}" -gt "$w" ] && w=${#SHELL_MARKDOWN_OUT}
		done
		if [ "$k" -eq 1 ]; then widths="$w"; else widths="$widths$SHELL_MARKDOWN_CELL_SEP$w"; fi
		k=$((k + 1))
	done

	# Header, alignment row, then the rows.
	local out="" row_text first_row=1 pass
	for pass in header align rows; do
		case "$pass" in
		header) rest="$header$SHELL_MARKDOWN_ROW_SEP" ;;
		align) rest="x$SHELL_MARKDOWN_ROW_SEP" ;;
		rows) rest="$rows" ;;
		esac
		while [ -n "$rest" ]; do
			rec="${rest%%"$SHELL_MARKDOWN_ROW_SEP"*}"
			rest="${rest#*"$SHELL_MARKDOWN_ROW_SEP"}"
			line="|"
			k=1
			while [ "$k" -le "$ncols" ]; do
				_shell::markdown::nth "$widths" "$k"
				w="$SHELL_MARKDOWN_OUT"
				_shell::markdown::nth "$aligns" "$k"
				a="$SHELL_MARKDOWN_OUT"
				if [ "$pass" = "align" ]; then
					case "$a" in
					left)
						_shell::markdown::repeat '-' "$((w - 1))"
						dashes=":$SHELL_MARKDOWN_OUT"
						;;
					right)
						_shell::markdown::repeat '-' "$((w - 1))"
						dashes="$SHELL_MARKDOWN_OUT:"
						;;
					center)
						_shell::markdown::repeat '-' "$((w - 2))"
						dashes=":$SHELL_MARKDOWN_OUT:"
						;;
					*)
						_shell::markdown::repeat '-' "$w"
						dashes="$SHELL_MARKDOWN_OUT"
						;;
					esac
					line="$line $dashes |"
				else
					_shell::markdown::nth "$rec" "$k"
					_shell::markdown::pad "$SHELL_MARKDOWN_OUT" "$w" "$a"
					line="$line $SHELL_MARKDOWN_OUT |"
				fi
				k=$((k + 1))
			done
			if [ "$first_row" = 1 ]; then out="$line"; first_row=0; else out="$out"$'\n'"$line"; fi
		done
	done
	SHELL_MARKDOWN_OUT="$out"
}

# @internal
# @description Render the pending table as `Header: value` blocks (Telegram or plain).
#   Result in SHELL_MARKDOWN_OUT.
# @arg $1 string Format: telegram or plain.
# @arg $2 integer Number of columns.
# @arg $3 string Formatted header record.
# @arg $4 string Formatted rows, each record ended by the row separator.
# @set SHELL_MARKDOWN_OUT string The text.
_shell::markdown::table_cards() {
	local fmt="$1" ncols="$2" header="$3" rows="$4"
	local rest="$rows" rec k label value out="" card nonempty=0
	while [ -n "$rest" ]; do
		rec="${rest%%"$SHELL_MARKDOWN_ROW_SEP"*}"
		rest="${rest#*"$SHELL_MARKDOWN_ROW_SEP"}"
		card=""
		k=1
		while [ "$k" -le "$ncols" ]; do
			_shell::markdown::nth "$rec" "$k"
			value="$SHELL_MARKDOWN_OUT"
			if [ -n "$value" ]; then
				_shell::markdown::nth "$header" "$k"
				label="$SHELL_MARKDOWN_OUT"
				if [ -z "$label" ]; then
					_shell::markdown::esc_text "$fmt" "Column $k"
					label="$SHELL_MARKDOWN_OUT"
				fi
				[ "$fmt" = "telegram" ] && label="*$label:*" || label="$label:"
				if [ -n "$card" ]; then card="$card"$'\n'; fi
				card="$card$label $value"
			fi
			k=$((k + 1))
		done
		[ -n "$card" ] || continue
		if [ "$nonempty" -eq 0 ]; then out="$card"; else out="$out"$'\n\n'"$card"; fi
		nonempty=$((nonempty + 1))
	done
	SHELL_MARKDOWN_OUT="$out"
}

# @description Start a table: set its header cells and discard any pending table.
# @option -h | --help Show help and return.
# @arg $@ string One argument per column.
# @exitcode 0 Success.
# @exitcode 2 No header cell.
# @example
#   shell::markdown::table_header "Hash" "Author" "Message"
#
shell::markdown::table_header() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::table_header <column>..." "Start a table with its header cells" "shell::markdown::table_header \"Hash\" \"Author\""
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -eq 0 ]; then
		shell::logger::error "At least one header cell is required"
		return "$RETURN_INVALID"
	fi
	_shell::markdown::record "$@"
	SHELL_MARKDOWN_TABLE_HEADER="$SHELL_MARKDOWN_OUT"
	SHELL_MARKDOWN_TABLE_ALIGN=""
	SHELL_MARKDOWN_TABLE_ROWS=""
	SHELL_MARKDOWN_TABLE_STARTED=1
}

# @description Set the alignment of the columns of the pending table.
#   Columns without a value keep the default (no alignment marker, left padding).
#   Alignment shows in standard Markdown only.
# @option -h | --help Show help and return.
# @arg $@ string One of `left`, `center`, `right`, `default` per column.
# @exitcode 0 Success.
# @exitcode 2 Unknown alignment or no table started.
# @example
#   shell::markdown::table_align left center right
#
shell::markdown::table_align() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::table_align <left|center|right|default>..." "Set the column alignment of the pending table" "shell::markdown::table_align left right"
		return "$RETURN_SUCCESS"
	fi
	if [ "${SHELL_MARKDOWN_TABLE_STARTED-}" != "1" ]; then
		shell::logger::error "Start a table with table_header first"
		return "$RETURN_INVALID"
	fi
	local a
	for a in "$@"; do
		case "$a" in
		left | center | right | default) ;;
		*)
			shell::logger::error "Unknown alignment '$a' (use left, center, right or default)"
			return "$RETURN_INVALID"
			;;
		esac
	done
	_shell::markdown::record "$@"
	SHELL_MARKDOWN_TABLE_ALIGN="$SHELL_MARKDOWN_OUT"
}

# @description Add a row to the pending table.
# @option -h | --help Show help and return.
# @arg $@ string One argument per column (an empty argument is an empty cell).
# @exitcode 0 Success.
# @exitcode 2 No cell, or no table started.
# @example
#   shell::markdown::table_row "a1b2c3" "John" "Add feature"
#
shell::markdown::table_row() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::table_row <cell>..." "Add a row to the pending table" "shell::markdown::table_row \"a1b2c3\" \"John\""
		return "$RETURN_SUCCESS"
	fi
	if [ "${SHELL_MARKDOWN_TABLE_STARTED-}" != "1" ]; then
		shell::logger::error "Start a table with table_header first"
		return "$RETURN_INVALID"
	fi
	if [ "$#" -eq 0 ]; then
		shell::logger::error "At least one cell is required"
		return "$RETURN_INVALID"
	fi
	_shell::markdown::record "$@"
	SHELL_MARKDOWN_TABLE_ROWS="${SHELL_MARKDOWN_TABLE_ROWS-}$SHELL_MARKDOWN_OUT$SHELL_MARKDOWN_ROW_SEP"
}

# @description Append the pending table to the document and clear it.
#   Format-specific output is described in the file header. A table without rows
#   still prints its header (Markdown) or nothing (Telegram, plain).
# @option -h | --help Show help and return.
# @exitcode 0 Success.
# @exitcode 2 No table was started.
# @example
#   shell::markdown::table_header "Hash" "Author"
#   shell::markdown::table_row "a1b2c3" "John"
#   shell::markdown::table
#
shell::markdown::table() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::table" "Append the pending table to the document" "shell::markdown::table"
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -ne 0 ]; then
		shell::logger::error "Unexpected argument: $1"
		return "$RETURN_INVALID"
	fi
	if [ "${SHELL_MARKDOWN_TABLE_STARTED-}" != "1" ]; then
		shell::logger::error "Start a table with table_header first"
		return "$RETURN_INVALID"
	fi

	local fmt="${SHELL_MARKDOWN_FORMAT:-$SHELL_MARKDOWN_DEFAULT_FORMAT}"
	local ncols rec rest n
	_shell::markdown::count "$SHELL_MARKDOWN_TABLE_HEADER"
	ncols="$SHELL_MARKDOWN_OUT"
	rest="${SHELL_MARKDOWN_TABLE_ROWS-}"
	while [ -n "$rest" ]; do
		rec="${rest%%"$SHELL_MARKDOWN_ROW_SEP"*}"
		rest="${rest#*"$SHELL_MARKDOWN_ROW_SEP"}"
		_shell::markdown::count "$rec"
		n="$SHELL_MARKDOWN_OUT"
		[ "$n" -gt "$ncols" ] && ncols="$n"
	done

	_shell::markdown::cells "$fmt" "$SHELL_MARKDOWN_TABLE_HEADER" "$ncols"
	local header="$SHELL_MARKDOWN_OUT" rows=""
	rest="${SHELL_MARKDOWN_TABLE_ROWS-}"
	while [ -n "$rest" ]; do
		rec="${rest%%"$SHELL_MARKDOWN_ROW_SEP"*}"
		rest="${rest#*"$SHELL_MARKDOWN_ROW_SEP"}"
		_shell::markdown::cells "$fmt" "$rec" "$ncols"
		rows="$rows$SHELL_MARKDOWN_OUT$SHELL_MARKDOWN_ROW_SEP"
	done

	case "$fmt" in
	markdown) _shell::markdown::table_markdown "$ncols" "$header" "$rows" ;;
	*) _shell::markdown::table_cards "$fmt" "$ncols" "$header" "$rows" ;;
	esac
	local block="$SHELL_MARKDOWN_OUT"

	SHELL_MARKDOWN_TABLE_HEADER=""
	SHELL_MARKDOWN_TABLE_ALIGN=""
	SHELL_MARKDOWN_TABLE_ROWS=""
	SHELL_MARKDOWN_TABLE_STARTED=0
	_shell::markdown::emit "$block"
}

