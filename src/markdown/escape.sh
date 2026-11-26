#!/usr/bin/env bash
# @file markdown/escape.sh
# @brief Escaping rules and fragment handling of the Markdown builder.
# @description
#   One escaping implementation per output format, used by every other file of
#   `src/markdown/`. There is no second converter anywhere in the library.
#
#   Telegram MarkdownV2 (https://core.telegram.org/bots/api#markdownv2-style):
#   * normal text: every one of `_ * [ ] ( ) ~ ` > # + - = | { } . ! \` is escaped with `\`;
#   * inside `code` and ```pre```: only `` ` `` and `\` are escaped;
#   * inside the `(...)` part of an inline link: only `)` and `\` are escaped.
#
#   Fragments: the inline functions (`bold`, `link`, ...) return text wrapped in two
#   invisible markers. A block function (`paragraph`, `list_item`, ...) escapes the
#   plain parts of its argument and keeps the marked parts verbatim, which is how
#   `paragraph "$(shell::markdown::bold Hi) there."` works without escaping twice.
#   The markers are removed before anything reaches the document buffer.

# @internal
# @description Escape plain text for a format. The result is left in SHELL_MARKDOWN_OUT
#   (not printed, so trailing newlines survive).
# @arg $1 string Format: markdown, telegram or plain.
# @arg $2 string Text.
# @arg $3 string Optional. `0` when the text does not start a line (default `1`).
# @set SHELL_MARKDOWN_OUT string The escaped text.
# @exitcode 0 Always.
_shell::markdown::esc_text() {
	local fmt="${1-}" text="${2-}" at_start="${3-1}"
	local out="" c="" next="" i=0 j=0 n=${#text}

	case "$fmt" in
	telegram)
		while [ "$i" -lt "$n" ]; do
			c="${text:$i:1}"
			case "$c" in
			'_' | '*' | '[' | ']' | '(' | ')' | '~' | '`' | '>' | '#' | '+' | '-' | '=' | '|' | '{' | '}' | '.' | '!' | '\')
				out="$out\\$c"
				;;
			*) out="$out$c" ;;
			esac
			i=$((i + 1))
		done
		;;
	markdown)
		while [ "$i" -lt "$n" ]; do
			c="${text:$i:1}"
			case "$c" in
			'\' | '`' | '*' | '_' | '[' | ']' | '<' | '~')
				out="$out\\$c"
				at_start=0
				;;
			'#' | '>' | '+' | '-' | '=')
				# Only a block marker at the start of a line.
				if [ "$at_start" = 1 ]; then out="$out\\$c"; else out="$out$c"; fi
				at_start=0
				;;
			[0-9])
				# `1.` or `1)` at the start of a line would become a list.
				if [ "$at_start" = 1 ]; then
					j=$i
					while [ "$j" -lt "$n" ]; do
						case "${text:$j:1}" in
						[0-9]) j=$((j + 1)) ;;
						*) break ;;
						esac
					done
					next="${text:$j:1}"
					if [ "$next" = "." ] || [ "$next" = ")" ]; then
						out="$out${text:$i:$((j - i))}\\$next"
						i=$j
					else
						out="$out$c"
					fi
				else
					out="$out$c"
				fi
				at_start=0
				;;
			$'\n')
				out="$out$c"
				at_start=1
				;;
			' ' | $'\t') out="$out$c" ;;
			*)
				out="$out$c"
				at_start=0
				;;
			esac
			i=$((i + 1))
		done
		;;
	*) out="$text" ;;
	esac
	SHELL_MARKDOWN_OUT="$out"
}

# @internal
# @description Escape a URL for a format. Result in SHELL_MARKDOWN_OUT.
#   Telegram: only `)` and `\` are escaped (the rule for the `(...)` of a link).
#   Markdown: space, quotes, angle brackets and parentheses are percent-encoded.
# @arg $1 string Format.
# @arg $2 string URL.
# @set SHELL_MARKDOWN_OUT string The escaped URL.
# @exitcode 0 Always.
_shell::markdown::esc_url() {
	local fmt="${1-}" url="${2-}"
	local out="" c="" i=0 n=${#url}

	case "$fmt" in
	telegram)
		while [ "$i" -lt "$n" ]; do
			c="${url:$i:1}"
			case "$c" in
			')' | '\') out="$out\\$c" ;;
			*) out="$out$c" ;;
			esac
			i=$((i + 1))
		done
		;;
	markdown)
		while [ "$i" -lt "$n" ]; do
			c="${url:$i:1}"
			case "$c" in
			' ') out="$out%20" ;;
			'(') out="$out%28" ;;
			')') out="$out%29" ;;
			'<') out="$out%3C" ;;
			'>') out="$out%3E" ;;
			'"') out="$out%22" ;;
			*) out="$out$c" ;;
			esac
			i=$((i + 1))
		done
		;;
	*) out="$url" ;;
	esac
	SHELL_MARKDOWN_OUT="$out"
}

# @internal
# @description Escape text that goes inside a code entity. Result in SHELL_MARKDOWN_OUT.
#   Telegram: only `` ` `` and `\`. Other formats leave the text alone (the
#   fence is lengthened instead, see `_shell::markdown::max_run`).
# @arg $1 string Format.
# @arg $2 string Code.
# @set SHELL_MARKDOWN_OUT string The escaped code.
# @exitcode 0 Always.
_shell::markdown::esc_code() {
	local fmt="${1-}" code="${2-}"
	local out="" c="" i=0 n=${#code}

	if [ "$fmt" != "telegram" ]; then
		SHELL_MARKDOWN_OUT="$code"
		return "$RETURN_SUCCESS"
	fi
	while [ "$i" -lt "$n" ]; do
		c="${code:$i:1}"
		case "$c" in
		'`' | '\') out="$out\\$c" ;;
		*) out="$out$c" ;;
		esac
		i=$((i + 1))
	done
	SHELL_MARKDOWN_OUT="$out"
}

# @internal
# @description Length of the longest run of backticks in a text. Result in SHELL_MARKDOWN_OUT.
# @arg $1 string Text.
# @set SHELL_MARKDOWN_OUT integer The longest run (0 when there is no backtick).
_shell::markdown::max_run() {
	local text="${1-}" best=0 run=0 i=0 n=${#1}
	while [ "$i" -lt "$n" ]; do
		if [ "${text:$i:1}" = '`' ]; then
			run=$((run + 1))
			[ "$run" -gt "$best" ] && best=$run
		else
			run=0
		fi
		i=$((i + 1))
	done
	SHELL_MARKDOWN_OUT="$best"
}

# @internal
# @description Repeat a string. Result in SHELL_MARKDOWN_OUT.
# @arg $1 string The string.
# @arg $2 integer How many times.
# @set SHELL_MARKDOWN_OUT string The repetition.
_shell::markdown::repeat() {
	local unit="${1-}" count="${2-0}" out=""
	while [ "$count" -gt 0 ]; do
		out="$out$unit"
		count=$((count - 1))
	done
	SHELL_MARKDOWN_OUT="$out"
}

# @internal
# @description Turn a mix of plain text and fragments into formatted text: plain
#   parts are escaped for the format, fragments are kept, markers are removed.
#   Result in SHELL_MARKDOWN_OUT.
# @arg $1 string Format.
# @arg $2 string Text, possibly containing fragments.
# @set SHELL_MARKDOWN_OUT string The formatted text.
_shell::markdown::inline() {
	local fmt="${1-}" rest="${2-}"
	local out="" plain="" frag="" at_start=1
	local mark_start="$SHELL_MARKDOWN_FRAG_START" mark_end="$SHELL_MARKDOWN_FRAG_END"

	while [ -n "$rest" ]; do
		case "$rest" in
		*"$mark_start"*)
			plain="${rest%%"$mark_start"*}"
			rest="${rest#*"$mark_start"}"
			if [ -n "$plain" ]; then
				_shell::markdown::esc_text "$fmt" "$plain" "$at_start"
				out="$out$SHELL_MARKDOWN_OUT"
			fi
			case "$rest" in
			*"$mark_end"*)
				frag="${rest%%"$mark_end"*}"
				rest="${rest#*"$mark_end"}"
				;;
			*)
				frag="$rest"
				rest=""
				;;
			esac
			out="$out$frag"
			;;
		*)
			_shell::markdown::esc_text "$fmt" "$rest" "$at_start"
			out="$out$SHELL_MARKDOWN_OUT"
			rest=""
			;;
		esac
		at_start=0
	done
	SHELL_MARKDOWN_OUT="$out"
}

# @internal
# @description Remove the fragment markers from a text. Result in SHELL_MARKDOWN_OUT.
# @arg $1 string Text.
# @set SHELL_MARKDOWN_OUT string The text without markers.
_shell::markdown::strip() {
	local text="${1-}"
	text="${text//"$SHELL_MARKDOWN_FRAG_START"/}"
	text="${text//"$SHELL_MARKDOWN_FRAG_END"/}"
	SHELL_MARKDOWN_OUT="$text"
}

# @internal
# @description Resolve the `-f|--format` option of the escape functions.
#   On success the format is in SHELL_MARKDOWN_FMT_ARG and SHELL_MARKDOWN_FMT_SHIFT is 0 or 2.
# @arg $@ string The caller's arguments.
# @set SHELL_MARKDOWN_FMT_ARG string The format to use.
# @set SHELL_MARKDOWN_FMT_SHIFT integer How many arguments the option consumed.
# @exitcode 0 Resolved.
# @exitcode 2 Unknown or missing format.
_shell::markdown::format_opt() {
	SHELL_MARKDOWN_FMT_ARG="${SHELL_MARKDOWN_FORMAT:-$SHELL_MARKDOWN_DEFAULT_FORMAT}"
	SHELL_MARKDOWN_FMT_SHIFT=0
	if [ "${1-}" = "-f" ] || [ "${1-}" = "--format" ]; then
		SHELL_MARKDOWN_FMT_ARG="${2-}"
		SHELL_MARKDOWN_FMT_SHIFT=2
		_shell::markdown::valid_format "$SHELL_MARKDOWN_FMT_ARG" || return "$RETURN_INVALID"
	fi
	return "$RETURN_SUCCESS"
}

# @description Escape text for the selected format, keeping inline fragments.
#   Plain parts are escaped; parts produced by the inline functions (`bold`, `link` ...)
#   are kept as they are. Use `escape_text` to escape everything.
# @option -h | --help Show help and return.
# @option -f | --format Format to use instead of the document's (markdown, telegram, plain).
# @arg $1 string Text.
# @stdout The escaped text.
# @exitcode 0 Success.
# @exitcode 2 Missing text or unknown format.
# @example
#   shell::markdown::escape -f telegram "Version 1.2.3"   # Version 1\.2\.3
#
shell::markdown::escape() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::escape [-f <format>] <text>" "Escape text for the selected format (fragments are kept)" "shell::markdown::escape -f telegram \"Version 1.2.3\""
		return "$RETURN_SUCCESS"
	fi
	_shell::markdown::format_opt "$@" || return "$RETURN_INVALID"
	local fmt="$SHELL_MARKDOWN_FMT_ARG"
	shift "$SHELL_MARKDOWN_FMT_SHIFT"
	if [ "$#" -ne 1 ]; then
		shell::logger::error "Exactly one text argument is required"
		return "$RETURN_INVALID"
	fi
	_shell::markdown::inline "$fmt" "$1"
	printf '%s' "$SHELL_MARKDOWN_OUT"
}

# @description Escape plain text for the selected format, escaping everything.
#   Telegram MarkdownV2: `_ * [ ] ( ) ~ ` > # + - = | { } . ! \` get a backslash.
#   Markdown: inline markers always, block markers (`# > + - =`, `1.`) only at the start of a line.
# @option -h | --help Show help and return.
# @option -f | --format Format to use instead of the document's.
# @arg $1 string Text.
# @stdout The escaped text.
# @exitcode 0 Success.
# @exitcode 2 Missing text or unknown format.
# @example
#   shell::markdown::escape_text -f telegram 'Price: $100 + $20'   # Price: $100 \+ $20
#
shell::markdown::escape_text() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::escape_text [-f <format>] <text>" "Escape plain text for the selected format" "shell::markdown::escape_text -f telegram \"a.b\""
		return "$RETURN_SUCCESS"
	fi
	_shell::markdown::format_opt "$@" || return "$RETURN_INVALID"
	local fmt="$SHELL_MARKDOWN_FMT_ARG"
	shift "$SHELL_MARKDOWN_FMT_SHIFT"
	if [ "$#" -ne 1 ]; then
		shell::logger::error "Exactly one text argument is required"
		return "$RETURN_INVALID"
	fi
	_shell::markdown::esc_text "$fmt" "$1"
	printf '%s' "$SHELL_MARKDOWN_OUT"
}

# @description Escape a URL for the selected format.
#   Telegram MarkdownV2: only `)` and `\` are escaped. Markdown: spaces, quotes,
#   angle brackets and parentheses are percent-encoded.
# @option -h | --help Show help and return.
# @option -f | --format Format to use instead of the document's.
# @arg $1 string URL.
# @stdout The escaped URL.
# @exitcode 0 Success.
# @exitcode 2 Missing URL or unknown format.
# @example
#   shell::markdown::escape_url -f telegram "https://a.org/w_(x)"   # https://a.org/w_(x\)
#
shell::markdown::escape_url() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::escape_url [-f <format>] <url>" "Escape a URL for the selected format" "shell::markdown::escape_url -f telegram \"https://a.org/w_(x)\""
		return "$RETURN_SUCCESS"
	fi
	_shell::markdown::format_opt "$@" || return "$RETURN_INVALID"
	local fmt="$SHELL_MARKDOWN_FMT_ARG"
	shift "$SHELL_MARKDOWN_FMT_SHIFT"
	if [ "$#" -ne 1 ]; then
		shell::logger::error "Exactly one URL argument is required"
		return "$RETURN_INVALID"
	fi
	_shell::markdown::esc_url "$fmt" "$1"
	printf '%s' "$SHELL_MARKDOWN_OUT"
}

# @description Escape text that goes inside a code span or code block.
#   Telegram MarkdownV2: only `` ` `` and `\` get a backslash. Other formats return the text unchanged.
# @option -h | --help Show help and return.
# @option -f | --format Format to use instead of the document's.
# @arg $1 string Code.
# @stdout The escaped code.
# @exitcode 0 Success.
# @exitcode 2 Missing code or unknown format.
# @example
#   shell::markdown::escape_code -f telegram 'echo `date`'
#
shell::markdown::escape_code() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::escape_code [-f <format>] <code>" "Escape code for a code entity" "shell::markdown::escape_code -f telegram 'a\\b'"
		return "$RETURN_SUCCESS"
	fi
	_shell::markdown::format_opt "$@" || return "$RETURN_INVALID"
	local fmt="$SHELL_MARKDOWN_FMT_ARG"
	shift "$SHELL_MARKDOWN_FMT_SHIFT"
	if [ "$#" -ne 1 ]; then
		shell::logger::error "Exactly one code argument is required"
		return "$RETURN_INVALID"
	fi
	_shell::markdown::esc_code "$fmt" "$1"
	printf '%s' "$SHELL_MARKDOWN_OUT"
}

# @description Mark text as a trusted fragment: block functions keep it verbatim.
#   Use it for text that is already valid in the current format (a mention, a
#   hand-written entity). It is not escaped, so never pass untrusted input.
# @option -h | --help Show help and return.
# @arg $1 string Already formatted text.
# @stdout The fragment (empty for empty text).
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   shell::markdown::paragraph "Hi $(shell::markdown::fragment '[Ann](tg://user?id=1)')"
#
shell::markdown::fragment() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::fragment <text>" "Mark already formatted text so block functions keep it verbatim" "shell::markdown::fragment '[Ann](tg://user?id=1)'"
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -ne 1 ]; then
		shell::logger::error "Exactly one text argument is required"
		return "$RETURN_INVALID"
	fi
	_shell::markdown::strip "$1"
	_shell::markdown::frag "$SHELL_MARKDOWN_OUT"
}

# @description Remove the invisible fragment markers from a text.
#   Inline functions return fragments with markers so blocks can compose them.
#   Call this when you want to use a fragment outside the builder.
# @option -h | --help Show help and return.
# @arg $1 string A fragment or any text.
# @stdout The text without markers.
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   plain=$(shell::markdown::unwrap "$(shell::markdown::bold Hi)")
#
shell::markdown::unwrap() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::unwrap <text>" "Remove the invisible fragment markers from a text" "shell::markdown::unwrap \"\$(shell::markdown::bold Hi)\""
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -ne 1 ]; then
		shell::logger::error "Exactly one text argument is required"
		return "$RETURN_INVALID"
	fi
	_shell::markdown::strip "$1"
	printf '%s' "$SHELL_MARKDOWN_OUT"
}

# @internal
# @description Wrap text in the fragment markers and print it (nothing for empty text).
# @arg $1 string Formatted text.
# @stdout The fragment.
# @exitcode 0 Always.
_shell::markdown::frag() {
	[ -n "${1-}" ] || return "$RETURN_SUCCESS"
	printf '%s%s%s' "$SHELL_MARKDOWN_FRAG_START" "$1" "$SHELL_MARKDOWN_FRAG_END"
}
