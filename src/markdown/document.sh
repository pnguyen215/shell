#!/usr/bin/env bash
# @file markdown/document.sh
# @brief Document state, buffer and output of the Markdown builder.
# @description
#   Lifecycle: `init` -> append blocks (`h1`, `paragraph`, `table` ...) -> `render` -> `to_file`.
#
#   State (one document per shell, kept in plain variables):
#     SHELL_MARKDOWN_FORMAT   the selected format
#     SHELL_MARKDOWN_BUFFER   the document so far
#
#   Three kinds of function, kept apart on purpose:
#     inline   (`bold`, `link` ...)    print a fragment on stdout, never touch the buffer
#     block    (`paragraph`, `h1` ...) append to the buffer, print nothing
#     output   (`render`, `to_file`)   read the buffer, never change it
#
#   Because block functions change shell variables, call them in the current shell,
#   not inside `$( ... )` or a pipeline (the changes would be lost with the subshell).
#
#   Blocks are formatted when they are appended, with the format that is selected at that
#   moment. `set_format` therefore affects the blocks added afterwards; it does not
#   rewrite what is already in the buffer. Blocks are separated by one empty line and a
#   document ends with exactly one newline.

# @internal
# @description Check a format identifier.
# @arg $1 string The identifier.
# @stderr The list of valid formats when it is unknown.
# @exitcode 0 Valid.
# @exitcode 2 Unknown or empty.
_shell::markdown::valid_format() {
	local fmt="${1-}"
	case " $SHELL_MARKDOWN_FORMATS " in
	*" $fmt "*)
		[ -n "$fmt" ] && return "$RETURN_SUCCESS"
		;;
	esac
	shell::logger::error "Unknown format '$fmt' (use one of: $SHELL_MARKDOWN_FORMATS)"
	return "$RETURN_INVALID"
}

# @internal
# @description True when the only argument is -h or --help.
# @arg $@ string The caller's arguments.
# @exitcode 0 Help was requested.
# @exitcode 1 It was not.
_shell::markdown::wants_help() {
	[ "$#" -eq 1 ] || return 1
	[ "$1" = "-h" ] || [ "$1" = "--help" ]
}

# @internal
# @description Print a help block through the logger.
# @arg $1 string Usage line.
# @arg $2 string One-sentence summary.
# @arg $3 string Optional. Example command.
# @exitcode 0 Always.
_shell::markdown::help() {
	shell::logger::reset_options
	shell::logger::info "$2"
	shell::logger::usage "$1"
	shell::logger::option "-h, --help" "Display this help message"
	if [ -n "${3-}" ]; then
		shell::logger::example "$3"
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Append a block to the buffer.
#   Empty blocks are ignored. Consecutive `list` blocks are joined with one newline,
#   every other block is separated from the previous one by an empty line.
# @arg $1 string The formatted block.
# @arg $2 string Optional. Block kind: `block` (default) or `list`.
# @exitcode 0 Always.
_shell::markdown::emit() {
	local block="${1-}" kind="${2-block}"
	[ -n "$block" ] || return "$RETURN_SUCCESS"

	if [ -z "${SHELL_MARKDOWN_BUFFER-}" ]; then
		SHELL_MARKDOWN_BUFFER="$block"
	elif [ "$kind" = "list" ] && [ "${SHELL_MARKDOWN_LAST-}" = "list" ]; then
		SHELL_MARKDOWN_BUFFER="$SHELL_MARKDOWN_BUFFER"$'\n'"$block"
	else
		SHELL_MARKDOWN_BUFFER="$SHELL_MARKDOWN_BUFFER"$'\n\n'"$block"
	fi
	SHELL_MARKDOWN_LAST="$kind"
	if [ "$kind" != "list" ]; then
		SHELL_MARKDOWN_OLIST=0
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Empty the buffer and every pending state (list numbering, table).
# @exitcode 0 Always.
_shell::markdown::clear() {
	SHELL_MARKDOWN_BUFFER=""
	SHELL_MARKDOWN_LAST=""
	SHELL_MARKDOWN_OLIST=0
	SHELL_MARKDOWN_TABLE_HEADER=""
	SHELL_MARKDOWN_TABLE_ALIGN=""
	SHELL_MARKDOWN_TABLE_ROWS=""
	SHELL_MARKDOWN_TABLE_STARTED=0
	return "$RETURN_SUCCESS"
}

# @description Start a new, empty document.
#   Clears the buffer and selects the format (the default is `markdown`, or
#   `SHELL_MARKDOWN_DEFAULT_FORMAT`). Calling it again starts over.
# @option -h | --help Show help and return.
# @option -f | --format Format of the document: markdown, telegram or plain.
# @stderr The reason when an argument is invalid.
# @exitcode 0 Success.
# @exitcode 2 Unknown format or unexpected argument.
# @example
#   shell::markdown::init -f telegram
#
shell::markdown::init() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::init [-f <format>]" "Start a new, empty document" "shell::markdown::init -f telegram"
		return "$RETURN_SUCCESS"
	fi
	local fmt="$SHELL_MARKDOWN_DEFAULT_FORMAT"
	if [ "${1-}" = "-f" ] || [ "${1-}" = "--format" ]; then
		fmt="${2-}"
		shift 2 2>/dev/null || shift "$#"
	fi
	if [ "$#" -ne 0 ]; then
		shell::logger::error "Unexpected argument: $1"
		return "$RETURN_INVALID"
	fi
	_shell::markdown::valid_format "$fmt" || return "$RETURN_INVALID"
	SHELL_MARKDOWN_FORMAT="$fmt"
	_shell::markdown::clear
}

# @description Empty the document but keep the selected format.
# @option -h | --help Show help and return.
# @exitcode 0 Success.
# @exitcode 2 Unexpected argument.
# @example
#   shell::markdown::reset
#
shell::markdown::reset() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::reset" "Empty the document, keep the format" "shell::markdown::reset"
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -ne 0 ]; then
		shell::logger::error "Unexpected argument: $1"
		return "$RETURN_INVALID"
	fi
	_shell::markdown::clear
}

# @description Select the output format for everything produced from now on.
#   Blocks already in the buffer are not converted (see the file header).
# @option -h | --help Show help and return.
# @arg $1 string Format: markdown, telegram or plain.
# @exitcode 0 Success.
# @exitcode 2 Unknown format.
# @example
#   shell::markdown::set_format telegram
#
shell::markdown::set_format() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::set_format <markdown|telegram|plain>" "Select the output format" "shell::markdown::set_format telegram"
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -ne 1 ]; then
		shell::logger::error "Exactly one format is required"
		return "$RETURN_INVALID"
	fi
	_shell::markdown::valid_format "$1" || return "$RETURN_INVALID"
	SHELL_MARKDOWN_FORMAT="$1"
}

# @description Print the selected output format.
# @option -h | --help Show help and return.
# @stdout markdown, telegram or plain.
# @exitcode 0 Always.
# @example
#   shell::markdown::get_format
#
shell::markdown::get_format() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::get_format" "Print the selected output format" "shell::markdown::get_format"
		return "$RETURN_SUCCESS"
	fi
	printf '%s\n' "${SHELL_MARKDOWN_FORMAT:-$SHELL_MARKDOWN_DEFAULT_FORMAT}"
}

# @description Append text to the end of the buffer exactly as given.
#   No escaping, no separator, no newline: for building a block by hand.
#   Fragment markers are removed. Use `raw` to add a separate block.
# @option -h | --help Show help and return.
# @arg $1 string The text.
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   shell::markdown::append "tail of the previous line"
#
shell::markdown::append() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::append <text>" "Append text to the buffer exactly as given" "shell::markdown::append \"more\""
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -ne 1 ]; then
		shell::logger::error "Exactly one text argument is required"
		return "$RETURN_INVALID"
	fi
	_shell::markdown::strip "$1"
	SHELL_MARKDOWN_BUFFER="${SHELL_MARKDOWN_BUFFER-}$SHELL_MARKDOWN_OUT"
	SHELL_MARKDOWN_LAST="block"
	SHELL_MARKDOWN_OLIST=0
}

# @description Add trusted Markdown as its own block, without escaping it.
#   The text must already be valid in the selected format. Never pass untrusted input.
# @option -h | --help Show help and return.
# @arg $1 string The Markdown.
# @exitcode 0 Success.
# @exitcode 2 Missing text.
# @example
#   shell::markdown::raw "# Custom Markdown"
#
shell::markdown::raw() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::raw <markdown>" "Add trusted Markdown as its own block, unescaped" "shell::markdown::raw \"# Custom\""
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -ne 1 ]; then
		shell::logger::error "Exactly one text argument is required"
		return "$RETURN_INVALID"
	fi
	_shell::markdown::strip "$1"
	_shell::markdown::emit "$SHELL_MARKDOWN_OUT"
}

# @description Print the whole document.
#   Reads the buffer without changing it, so rendering twice prints the same
#   text. An empty document prints nothing.
# @option -h | --help Show help and return.
# @stdout The document, ending with one newline.
# @exitcode 0 Always.
# @example
#   shell::markdown::render
#
shell::markdown::render() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::render" "Print the whole document" "shell::markdown::render"
		return "$RETURN_SUCCESS"
	fi
	if [ "$#" -ne 0 ]; then
		shell::logger::error "Unexpected argument: $1"
		return "$RETURN_INVALID"
	fi
	if [ -n "${SHELL_MARKDOWN_BUFFER-}" ]; then
		printf '%s\n' "$SHELL_MARKDOWN_BUFFER"
	fi
	return "$RETURN_SUCCESS"
}

# @description Write the document to a file (replacing it).
#   The directory must exist. An empty document creates an empty file.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print what would be written, write nothing.
# @arg $1 string Destination file.
# @exitcode 0 Success.
# @exitcode 1 The file could not be written.
# @exitcode 2 Missing path, or the path is a directory.
# @exitcode 3 The directory does not exist.
# @example
#   shell::markdown::to_file "$HOME/report.md"
#
shell::markdown::to_file() {
	if _shell::markdown::wants_help "$@"; then
		_shell::markdown::help "shell::markdown::to_file [-n] <file>" "Write the document to a file" "shell::markdown::to_file report.md"
		return "$RETURN_SUCCESS"
	fi
	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi
	local file="${1-}"
	if [ "$#" -ne 1 ] || [ -z "$file" ]; then
		shell::logger::error "A destination file is required"
		return "$RETURN_INVALID"
	fi
	if [ -d "$file" ]; then
		shell::logger::error "'$file' is a directory"
		return "$RETURN_INVALID"
	fi
	local dir="${file%/*}"
	[ "$dir" = "$file" ] && dir="."
	[ -n "$dir" ] || dir="/"
	if [ ! -d "$dir" ]; then
		shell::logger::error "Directory not found: $dir"
		return "$RETURN_NOT_FOUND"
	fi
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "shell::markdown::render > $file"
		return "$RETURN_SUCCESS"
	fi
	if [ -n "${SHELL_MARKDOWN_BUFFER-}" ]; then
		printf '%s\n' "$SHELL_MARKDOWN_BUFFER" >"$file" || return "$RETURN_FAILURE"
	else
		: >"$file" || return "$RETURN_FAILURE"
	fi
	return "$RETURN_SUCCESS"
}

