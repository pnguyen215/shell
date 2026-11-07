#!/usr/bin/env bash
# @file markdown/block.sh
# @brief Block elements: headings, paragraphs, quotes, rules and code blocks.
# @description
#   Block functions append to the document buffer and print nothing. Their text
#   argument may mix plain text (escaped for the format) and fragments from the
#   inline functions (kept as they are).
#
#   | block            | markdown            | telegram (MarkdownV2)                  | plain               |
#   | ---------------- | ------------------- | -------------------------------------- | ------------------- |
#   | heading 1-6      | `#` .. `######`     | bold line `*text*` (no headings exist) | text, h1/h2 underlined |
#   | paragraph        | text                | text                                   | text                |
#   | blockquote       | `> ` per line       | `>` per line                           | `> ` per line       |
#   | horizontal_rule  | `---`               | a line of `─` characters               | a line of `-`       |
#   | code_block       | fenced, fence grows | triple backticks, ` and \ escaped      | indented 4 spaces   |
#
#   Empty text appends nothing. `-h` / `--help` is recognised only as the sole argument.

# @internal
# @description Prefix every line of a text. The result is left in SHELL_MARKDOWN_OUT.
#   Empty lines get the prefix without its trailing space.
# @arg $1 string Prefix of the first line.
# @arg $2 string Prefix of the other lines.
# @arg $3 string The text.
# @set SHELL_MARKDOWN_OUT string The prefixed text.
_shell::markdown::prefix_lines() {
	local first="${1-}" rest="${2-}" text="${3-}"
	local out="" line="" prefix="$first" n=0
	while IFS= read -r line || [ -n "$line" ]; do
		if [ "$n" -gt 0 ]; then
			out="$out"$'\n'
			prefix="$rest"
		fi
		if [ -z "$line" ]; then
			out="$out${prefix% }"
		else
			out="$out$prefix$line"
		fi
		n=$((n + 1))
	done <<<"$text"
	SHELL_MARKDOWN_OUT="$out"
}

# @description Append a heading of level 1 to 6.
#   Telegram MarkdownV2 has no headings: every level becomes a bold line, so the level is
#   lost. In plain output levels 1 and 2 are underlined with `=` and `-`.
#   A newline in the text is turned into a space.
# @option -h | --help Show help and return.
# @arg $1 integer Level, 1 to 6.
# @arg $2 string Heading text (plain text or fragments).
# @exitcode 0 Success.
# @exitcode 2 Invalid level or missing text.
# @example
#   shell::markdown::heading 4 "Heading"
#
shell::markdown::heading() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::heading <1-6> <text>" "Append a heading (a bold line in Telegram)" "shell::markdown::heading 2 \"Section\""
		return "$RETURN_SUCCESS"
	fi
	local level="${1-}"
	case "$level" in
	[1-6]) ;;
	*)
		shell::logger::error "The heading level must be 1 to 6 (got '$level')"
		return "$RETURN_INVALID"
		;;
	esac
	if [ "$#" -ne 2 ]; then
		shell::logger::error "A heading text is required"
		return "$RETURN_INVALID"
	fi
	local fmt="${SHELL_MARKDOWN_FORMAT:-$SHELL_MARKDOWN_DEFAULT_FORMAT}"
	_shell::markdown::inline "$fmt" "$2"
	local text="${SHELL_MARKDOWN_OUT//$'\n'/ }"
	[ -n "$text" ] || return "$RETURN_SUCCESS"
	case "$fmt" in
	telegram) _shell::markdown::emit "*$text*" ;;
	plain)
		case "$level" in
		1) _shell::markdown::repeat '=' "${#text}" ;;
		2) _shell::markdown::repeat '-' "${#text}" ;;
		*) SHELL_MARKDOWN_OUT="" ;;
		esac
		if [ -n "$SHELL_MARKDOWN_OUT" ]; then
			_shell::markdown::emit "$text"$'\n'"$SHELL_MARKDOWN_OUT"
		else
			_shell::markdown::emit "$text"
		fi
		;;
	*)
		_shell::markdown::repeat '#' "$level"
		_shell::markdown::emit "$SHELL_MARKDOWN_OUT $text"
		;;
	esac
}

# @description Append a level 1 heading.
# @option -h | --help Show help and return.
# @arg $1 string Heading text.
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   shell::markdown::h1 "Main Heading"
#
shell::markdown::h1() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::h1 <text>" "Append a level 1 heading" "shell::markdown::h1 \"Main Heading\""
		return "$RETURN_SUCCESS"
	fi
	shell::markdown::heading 1 "$@"
}

# @description Append a level 2 heading.
# @option -h | --help Show help and return.
# @arg $1 string Heading text.
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   shell::markdown::h2 "Section"
#
shell::markdown::h2() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::h2 <text>" "Append a level 2 heading" "shell::markdown::h2 \"Section\""
		return "$RETURN_SUCCESS"
	fi
	shell::markdown::heading 2 "$@"
}

# @description Append a level 3 heading.
# @option -h | --help Show help and return.
# @arg $1 string Heading text.
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   shell::markdown::h3 "Subsection"
#
shell::markdown::h3() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::h3 <text>" "Append a level 3 heading" "shell::markdown::h3 \"Subsection\""
		return "$RETURN_SUCCESS"
	fi
	shell::markdown::heading 3 "$@"
}

# @description Append a paragraph.
#   Plain parts are escaped for the selected format; fragments are kept.
#   Newlines inside the text are kept.
# @option -h | --help Show help and return.
# @arg $1 string Text (plain text or fragments).
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   shell::markdown::paragraph "Version 1.2.3 is out"
#
shell::markdown::paragraph() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::paragraph <text>" "Append a paragraph" "shell::markdown::paragraph \"Description\""
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -ne 1 ]; then
		shell::logger::error "Exactly one text argument is required"
		return "$RETURN_INVALID"
	fi
	local fmt="${SHELL_MARKDOWN_FORMAT:-$SHELL_MARKDOWN_DEFAULT_FORMAT}"
	_shell::markdown::inline "$fmt" "$1"
	_shell::markdown::emit "$SHELL_MARKDOWN_OUT"
}

# @description Append a block quote.
#   Markdown prefixes each line with `> `, Telegram with `>` (MarkdownV2 quote syntax).
#   Blank lines inside the quote are kept as `>`.
# @option -h | --help Show help and return.
# @arg $1 string Text (plain text or fragments), possibly several lines.
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   shell::markdown::blockquote "Quoted content"
#
shell::markdown::blockquote() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::blockquote <text>" "Append a block quote" "shell::markdown::blockquote \"Quoted content\""
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -ne 1 ]; then
		shell::logger::error "Exactly one text argument is required"
		return "$RETURN_INVALID"
	fi
	local fmt="${SHELL_MARKDOWN_FORMAT:-$SHELL_MARKDOWN_DEFAULT_FORMAT}"
	_shell::markdown::inline "$fmt" "$1"
	[ -n "$SHELL_MARKDOWN_OUT" ] || return "$RETURN_SUCCESS"
	if [ "$fmt" = "telegram" ]; then
		_shell::markdown::prefix_lines ">" ">" "$SHELL_MARKDOWN_OUT"
	else
		_shell::markdown::prefix_lines "> " "> " "$SHELL_MARKDOWN_OUT"
	fi
	_shell::markdown::emit "$SHELL_MARKDOWN_OUT"
}

# @description Append a horizontal rule.
#   Telegram MarkdownV2 has none: a line of `─` characters (SHELL_MARKDOWN_TELEGRAM_RULE) is used.
# @option -h | --help Show help and return.
# @exitcode 0 Success.
# @exitcode 2 Unexpected argument.
# @example
#   shell::markdown::horizontal_rule
#
shell::markdown::horizontal_rule() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::horizontal_rule" "Append a horizontal rule" "shell::markdown::horizontal_rule"
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -ne 0 ]; then
		shell::logger::error "Unexpected argument: $1"
		return "$RETURN_INVALID"
	fi
	case "${SHELL_MARKDOWN_FORMAT:-$SHELL_MARKDOWN_DEFAULT_FORMAT}" in
	telegram) _shell::markdown::emit "$SHELL_MARKDOWN_TELEGRAM_RULE" ;;
	plain) _shell::markdown::emit "$SHELL_MARKDOWN_PLAIN_RULE" ;;
	*) _shell::markdown::emit "---" ;;
	esac
}

# @description Append a fenced code block.
#   The code is never Markdown-escaped. It cannot close its own fence: Markdown
#   uses a fence one backtick longer than the longest run inside the code, Telegram
#   escapes every backtick (and backslash) as the MarkdownV2 rules require.
#   The language is optional and limited to letters, digits and `_ + . # -`.
#   A single trailing newline of the code is dropped.
# @option -h | --help Show help and return.
# @arg $1 string Language (may be empty). With a single argument, that argument is the code.
# @arg $2 string The code, possibly several lines.
# @exitcode 0 Success.
# @exitcode 2 Invalid language or wrong number of arguments.
# @example
#   shell::markdown::code_block "bash" "git log --oneline"
#
shell::markdown::code_block() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::code_block [<language>] <code>" "Append a fenced code block" "shell::markdown::code_block bash \"git log --oneline\""
		return "$RETURN_SUCCESS"
	fi
	local lang="" code=""
	case "$#" in
	1) code="$1" ;;
	2)
		lang="$1"
		code="$2"
		;;
	*)
		shell::logger::error "Usage: code_block [<language>] <code>"
		return "$RETURN_INVALID"
		;;
	esac
	case "$lang" in
	*[!A-Za-z0-9_+.#-]*)
		shell::logger::error "Invalid code language '$lang'"
		return "$RETURN_INVALID"
		;;
	esac
	local fmt="${SHELL_MARKDOWN_FORMAT:-$SHELL_MARKDOWN_DEFAULT_FORMAT}"
	_shell::markdown::strip "$code"
	code="${SHELL_MARKDOWN_OUT%$'\n'}"
	case "$fmt" in
	telegram)
		_shell::markdown::esc_code telegram "$code"
		_shell::markdown::emit "\`\`\`$lang"$'\n'"$SHELL_MARKDOWN_OUT"$'\n'"\`\`\`"
		;;
	plain)
		_shell::markdown::prefix_lines "    " "    " "$code"
		_shell::markdown::emit "$SHELL_MARKDOWN_OUT"
		;;
	*)
		_shell::markdown::max_run "$code"
		local run="$SHELL_MARKDOWN_OUT"
		[ "$run" -lt 3 ] && run=2
		_shell::markdown::repeat '`' "$((run + 1))"
		local fence="$SHELL_MARKDOWN_OUT"
		_shell::markdown::emit "$fence$lang"$'\n'"$code"$'\n'"$fence"
		;;
	esac
}
