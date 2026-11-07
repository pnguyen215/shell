#!/usr/bin/env bash
# @file markdown/list.sh
# @brief Unordered, ordered and nested lists.
# @description
#   Consecutive items form one list (joined with a single newline, no empty line);
#   any other block ends it. Ordered numbering starts at 1 and restarts after a
#   different block.
#
#   Markdown uses `- ` and `1. ` and indents nested items by SHELL_MARKDOWN_INDENT
#   (4) spaces per level. Telegram MarkdownV2 has no lists, so the output is readable
#   text: `•`, `◦`, `▪` bullets and `1\.` numbers (the dot must be escaped), with the
#   item text escaped. Continuation lines of a multi-line item are aligned under the
#   first line. `-h` / `--help` is recognised only as the sole argument.

# @internal
# @description Append one list item.
# @arg $1 string Kind: `ul` or `ol`.
# @arg $2 integer Nesting level (0 = top level).
# @arg $3 string Item text (plain text or fragments), possibly several lines.
# @exitcode 0 Success.
# @exitcode 2 Invalid level.
_shell::markdown::item() {
	local kind="$1" level="$2" text="$3"
	case "$level" in
	'' | *[!0-9]*)
		shell::logger::error "The nesting level must be a non-negative integer (got '$level')"
		return "$RETURN_INVALID"
		;;
	esac
	local fmt="${SHELL_MARKDOWN_FORMAT:-$SHELL_MARKDOWN_DEFAULT_FORMAT}"
	_shell::markdown::inline "$fmt" "$text"
	local body="$SHELL_MARKDOWN_OUT"
	[ -n "$body" ] || return "$RETURN_SUCCESS"

	# A list directly after another block starts counting again.
	if [ "${SHELL_MARKDOWN_LAST-}" != "list" ]; then
		SHELL_MARKDOWN_OLIST=0
	fi

	local indent_width=$((level * SHELL_MARKDOWN_INDENT))
	local marker
	if [ "$kind" = "ol" ]; then
		SHELL_MARKDOWN_OLIST=$((${SHELL_MARKDOWN_OLIST:-0} + 1))
		if [ "$fmt" = "telegram" ]; then
			marker="${SHELL_MARKDOWN_OLIST}\\."
		else
			marker="${SHELL_MARKDOWN_OLIST}."
		fi
	else
		case "$fmt" in
		telegram)
			case "$level" in
			0) marker="$SHELL_MARKDOWN_TELEGRAM_BULLET_0" ;;
			1) marker="$SHELL_MARKDOWN_TELEGRAM_BULLET_1" ;;
			*) marker="$SHELL_MARKDOWN_TELEGRAM_BULLET_2" ;;
			esac
			;;
		*) marker="-" ;;
		esac
	fi
	# Telegram nests with 2 spaces per level: wide indents look broken in a chat bubble.
	if [ "$fmt" = "telegram" ]; then
		indent_width=$((level * 2))
	fi

	_shell::markdown::repeat ' ' "$indent_width"
	local indent="$SHELL_MARKDOWN_OUT"
	_shell::markdown::repeat ' ' "$((${#marker} + 1))"
	local hang="$SHELL_MARKDOWN_OUT"
	_shell::markdown::prefix_lines "$indent$marker " "$indent$hang" "$body"
	_shell::markdown::emit "$SHELL_MARKDOWN_OUT" list
}

# @description Append an unordered list item.
# @option -h | --help Show help and return.
# @arg $1 string Item text.
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   shell::markdown::list_item "First item"
#
shell::markdown::list_item() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::list_item <text>" "Append an unordered list item" "shell::markdown::list_item \"First item\""
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -ne 1 ]; then
		shell::logger::error "Exactly one text argument is required"
		return "$RETURN_INVALID"
	fi
	_shell::markdown::item ul 0 "$1"
}

# @description Append an ordered list item (numbered after the previous item).
# @option -h | --help Show help and return.
# @arg $1 string Item text.
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   shell::markdown::ordered_item "First step"
#
shell::markdown::ordered_item() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::ordered_item <text>" "Append an ordered list item" "shell::markdown::ordered_item \"First step\""
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -ne 1 ]; then
		shell::logger::error "Exactly one text argument is required"
		return "$RETURN_INVALID"
	fi
	_shell::markdown::item ol 0 "$1"
}

# @description Append a nested unordered list item.
# @option -h | --help Show help and return.
# @arg $1 integer Nesting level: 0 is top level, 1 is one level in, and so on.
# @arg $2 string Item text.
# @exitcode 0 Success.
# @exitcode 2 Invalid level or missing text.
# @example
#   shell::markdown::nested_item 1 "Nested item"
#
shell::markdown::nested_item() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::nested_item <level> <text>" "Append a nested unordered list item" "shell::markdown::nested_item 1 \"Nested item\""
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -ne 2 ]; then
		shell::logger::error "A level and a text are required"
		return "$RETURN_INVALID"
	fi
	_shell::markdown::item ul "$1" "$2"
}

# @description Append a whole unordered list, one item per argument.
#   It always starts a new list, separated from the previous block.
# @option -h | --help Show help and return.
# @arg $@ string The items.
# @exitcode 0 Success.
# @exitcode 2 No items.
# @example
#   shell::markdown::list "First" "Second" "Third"
#
shell::markdown::list() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::list <item>..." "Append a whole unordered list" "shell::markdown::list \"First\" \"Second\""
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -eq 0 ]; then
		shell::logger::error "At least one item is required"
		return "$RETURN_INVALID"
	fi
	SHELL_MARKDOWN_LAST=""
	local entry
	for entry in "$@"; do
		_shell::markdown::item ul 0 "$entry" || return "$?"
	done
}

# @description Append a whole ordered list, one item per argument.
#   It always starts a new list numbered from 1.
# @option -h | --help Show help and return.
# @arg $@ string The items.
# @exitcode 0 Success.
# @exitcode 2 No items.
# @example
#   shell::markdown::ordered_list "First" "Second"
#
shell::markdown::ordered_list() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::ordered_list <item>..." "Append a whole ordered list" "shell::markdown::ordered_list \"First\" \"Second\""
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -eq 0 ]; then
		shell::logger::error "At least one item is required"
		return "$RETURN_INVALID"
	fi
	SHELL_MARKDOWN_LAST=""
	SHELL_MARKDOWN_OLIST=0
	local entry
	for entry in "$@"; do
		_shell::markdown::item ol 0 "$entry" || return "$?"
	done
}
