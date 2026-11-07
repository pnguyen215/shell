#!/usr/bin/env bash
# @file markdown/inline.sh
# @brief Inline formatting: functions that print a fragment and never touch the document.
# @description
#   Each function escapes its text for the selected format and prints a fragment.
#   Fragments nest (`bold "$(italic x)"`) and can be passed to any block function.
#   Empty text gives an empty fragment, so no stray `**` is ever produced.
#
#   | function        | markdown          | telegram (MarkdownV2) | plain      |
#   | --------------- | ----------------- | --------------------- | ---------- |
#   | bold            | `**t**`           | `*t*`                 | t          |
#   | italic          | `*t*`             | `_t_`                 | t          |
#   | bold_italic     | `***t***`         | `*_t_*`               | t          |
#   | underline       | `<u>t</u>`        | `__t__`               | t          |
#   | strikethrough   | `~~t~~`           | `~t~`                 | t          |
#   | spoiler         | `<span class="spoiler">t</span>` | `\|\|t\|\|` | t       |
#   | code            | `` `t` ``         | `` `t` ``             | t          |
#   | link            | `[t](url)`        | `[t](url)`            | `t (url)`  |
#   | image           | `![alt](url)`     | `[alt](url)` (fallback) | `alt (url)` |
#
#   Telegram limits: an entity of one kind cannot be nested in itself, and italic
#   directly wrapping underline (or the reverse) is ambiguous (`___`); avoid those.
#   `-h` / `--help` is recognised only as the sole argument.

# @internal
# @description Shared body of bold, italic, underline ...: escape the text, wrap it, print the fragment.
# @arg $1 string Markdown opening delimiter.
# @arg $2 string Markdown closing delimiter.
# @arg $3 string Telegram opening delimiter.
# @arg $4 string Telegram closing delimiter.
# @arg $5 string Plain opening delimiter.
# @arg $6 string Plain closing delimiter.
# @arg $7 string The text (exactly one).
# @stdout The fragment.
# @exitcode 0 Success.
# @exitcode 2 The text argument is missing or there are extra arguments.
_shell::markdown::wrap() {
	local md_open="$1" md_close="$2" tg_open="$3" tg_close="$4" pl_open="$5" pl_close="$6"
	shift 6
	if [ "$#" -ne 1 ]; then
		shell::logger::error "Exactly one text argument is required"
		return "$RETURN_INVALID"
	fi
	local fmt="${SHELL_MARKDOWN_FORMAT:-$SHELL_MARKDOWN_DEFAULT_FORMAT}"
	_shell::markdown::inline "$fmt" "$1"
	local text="$SHELL_MARKDOWN_OUT"
	[ -n "$text" ] || return "$RETURN_SUCCESS"
	case "$fmt" in
	telegram) _shell::markdown::frag "$tg_open$text$tg_close" ;;
	plain) _shell::markdown::frag "$pl_open$text$pl_close" ;;
	*) _shell::markdown::frag "$md_open$text$md_close" ;;
	esac
}

# @description Bold text.
# @option -h | --help Show help and return.
# @arg $1 string Text (plain text or fragments).
# @stdout The fragment.
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   title=$(shell::markdown::bold "Git History")
#
shell::markdown::bold() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::bold <text>" "Bold text (prints a fragment)" "shell::markdown::bold \"Important\""
		return "$RETURN_SUCCESS"
	fi
	_shell::markdown::wrap '**' '**' '*' '*' '' '' "$@"
}

# @description Italic text.
# @option -h | --help Show help and return.
# @arg $1 string Text (plain text or fragments).
# @stdout The fragment.
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   shell::markdown::italic "Note"
#
shell::markdown::italic() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::italic <text>" "Italic text (prints a fragment)" "shell::markdown::italic \"Note\""
		return "$RETURN_SUCCESS"
	fi
	_shell::markdown::wrap '*' '*' '_' '_' '' '' "$@"
}

# @description Bold and italic text.
# @option -h | --help Show help and return.
# @arg $1 string Text (plain text or fragments).
# @stdout The fragment.
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   shell::markdown::bold_italic "Important note"
#
shell::markdown::bold_italic() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::bold_italic <text>" "Bold and italic text (prints a fragment)" "shell::markdown::bold_italic \"Important note\""
		return "$RETURN_SUCCESS"
	fi
	_shell::markdown::wrap '***' '***' '*_' '_*' '' '' "$@"
}

# @description Underlined text.
#   Standard Markdown has no underline: `<u>` is used (HTML, accepted by GitHub and most renderers).
# @option -h | --help Show help and return.
# @arg $1 string Text (plain text or fragments).
# @stdout The fragment.
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   shell::markdown::underline "Underlined"
#
shell::markdown::underline() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::underline <text>" "Underlined text (prints a fragment)" "shell::markdown::underline \"Underlined\""
		return "$RETURN_SUCCESS"
	fi
	_shell::markdown::wrap '<u>' '</u>' '__' '__' '' '' "$@"
}

# @description Struck-through text.
# @option -h | --help Show help and return.
# @arg $1 string Text (plain text or fragments).
# @stdout The fragment.
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   shell::markdown::strikethrough "Deprecated"
#
shell::markdown::strikethrough() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::strikethrough <text>" "Struck-through text (prints a fragment)" "shell::markdown::strikethrough \"Deprecated\""
		return "$RETURN_SUCCESS"
	fi
	_shell::markdown::wrap '~~' '~~' '~' '~' '' '' "$@"
}

# @description Hidden (spoiler) text.
#   Standard Markdown has no spoiler: `<span class="spoiler">` is used and renderers that
#   do not know it show the text. Plain output shows the text.
# @option -h | --help Show help and return.
# @arg $1 string Text (plain text or fragments).
# @stdout The fragment.
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   shell::markdown::spoiler "Hidden content"
#
shell::markdown::spoiler() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::spoiler <text>" "Spoiler text (prints a fragment)" "shell::markdown::spoiler \"Hidden content\""
		return "$RETURN_SUCCESS"
	fi
	_shell::markdown::wrap '<span class="spoiler">' '</span>' '||' '||' '' '' "$@"
}

# @description Inline code.
#   The text is code, not Markdown: nothing but `` ` `` and `\` (Telegram) is escaped.
#   Standard Markdown lengthens the backtick delimiter when the code contains backticks.
# @option -h | --help Show help and return.
# @arg $1 string The code (fragment markers are removed).
# @stdout The fragment.
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   shell::markdown::code "git status"
#
shell::markdown::code() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::code <code>" "Inline code (prints a fragment)" "shell::markdown::code \"git status\""
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -ne 1 ]; then
		shell::logger::error "Exactly one code argument is required"
		return "$RETURN_INVALID"
	fi
	local fmt="${SHELL_MARKDOWN_FORMAT:-$SHELL_MARKDOWN_DEFAULT_FORMAT}"
	_shell::markdown::strip "$1"
	local text="$SHELL_MARKDOWN_OUT"
	[ -n "$text" ] || return "$RETURN_SUCCESS"
	text="${text//$'\n'/ }"
	case "$fmt" in
	telegram)
		_shell::markdown::esc_code telegram "$text"
		_shell::markdown::frag "\`$SHELL_MARKDOWN_OUT\`"
		;;
	plain) _shell::markdown::frag "$text" ;;
	*)
		_shell::markdown::max_run "$text"
		_shell::markdown::repeat '`' "$((SHELL_MARKDOWN_OUT + 1))"
		local fence="$SHELL_MARKDOWN_OUT"
		case "$text" in
		'`'* | *'`' | ' '* | *' ') text=" $text " ;;
		esac
		_shell::markdown::frag "$fence$text$fence"
		;;
	esac
}

# @description A link.
#   An empty text uses the URL as text. A URL containing a newline is refused.
#   Telegram escapes the text as normal text and the URL with the `(...)` rule.
# @option -h | --help Show help and return.
# @arg $1 string Link text (plain text or fragments).
# @arg $2 string URL.
# @stdout The fragment.
# @exitcode 0 Success.
# @exitcode 2 Missing or invalid argument.
# @example
#   shell::markdown::link "GitHub" "https://github.com"
#
shell::markdown::link() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::link <text> <url>" "A link (prints a fragment)" "shell::markdown::link \"GitHub\" \"https://github.com\""
		return "$RETURN_SUCCESS"
	fi
	_shell::markdown::link_like link "$@"
}

# @description An image.
#   Telegram MarkdownV2 cannot embed images: the fallback is a link to the image
#   (send the picture with sendPhoto). Plain output is `alt (url)`.
# @option -h | --help Show help and return.
# @arg $1 string Alternative text.
# @arg $2 string Image URL.
# @stdout The fragment.
# @exitcode 0 Success.
# @exitcode 2 Missing or invalid argument.
# @example
#   shell::markdown::image "Screenshot" "https://example.com/image.png"
#
shell::markdown::image() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::image <alt> <url>" "An image (prints a fragment)" "shell::markdown::image \"Screenshot\" \"https://example.com/a.png\""
		return "$RETURN_SUCCESS"
	fi
	_shell::markdown::link_like image "$@"
}

# @internal
# @description Shared body of link and image.
# @arg $1 string `link` or `image`.
# @arg $2 string Text.
# @arg $3 string URL.
# @stdout The fragment.
# @exitcode 0 Success.
# @exitcode 2 Missing or invalid argument.
_shell::markdown::link_like() {
	local kind="$1"
	shift
	if [ "$#" -ne 2 ]; then
		shell::logger::error "A text and a URL are required"
		return "$RETURN_INVALID"
	fi
	local fmt="${SHELL_MARKDOWN_FORMAT:-$SHELL_MARKDOWN_DEFAULT_FORMAT}"
	local url="$2" text
	_shell::markdown::strip "$url"
	url="$SHELL_MARKDOWN_OUT"
	if [ -z "$url" ]; then
		shell::logger::error "A URL is required"
		return "$RETURN_INVALID"
	fi
	case "$url" in
	*$'\n'* | *$'\r'*)
		shell::logger::error "A URL cannot contain a newline"
		return "$RETURN_INVALID"
		;;
	esac
	_shell::markdown::inline "$fmt" "${1:-$url}"
	text="$SHELL_MARKDOWN_OUT"
	_shell::markdown::esc_url "$fmt" "$url"
	url="$SHELL_MARKDOWN_OUT"
	case "$fmt" in
	plain) _shell::markdown::frag "$text ($url)" ;;
	telegram) _shell::markdown::frag "[$text]($url)" ;;
	*)
		if [ "$kind" = "image" ]; then
			_shell::markdown::frag "![$text]($url)"
		else
			_shell::markdown::frag "[$text]($url)"
		fi
		;;
	esac
}

