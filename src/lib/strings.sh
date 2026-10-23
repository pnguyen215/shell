#!/usr/bin/env bash
# @file lib/strings.sh
# @brief String sanitising, trimming and case-formatting helpers.
# @description
#   Pure text helpers. They print their result on stdout and never modify the
#   caller's variables. `printf '%s\n'` is used everywhere instead of `echo`,
#   because `echo "$x"` misbehaves when `$x` is `-n`, `-e` or contains
#   backslashes (and behaves differently in bash, zsh and sh).

# @description Remove leading and trailing whitespace.
#   Pure parameter expansion - no external process is forked.
# @arg $1 string Text to trim.
# @stdout The trimmed text.
# @exitcode 0 Always.
# @example
#   shell::strings::trim "   hello  "    # -> hello
#
shell::strings::trim() {
	local value="${1-}"
	# Strip the longest leading run of whitespace, then the trailing run.
	value="${value#"${value%%[![:space:]]*}"}"
	value="${value%"${value##*[![:space:]]}"}"
	printf '%s\n' "$value"
}

# @description Upper-case a string and replace every char outside [A-Z0-9_] with `_`.
#   Intended for building environment-variable names.
# @arg $1 string Text to convert.
# @stdout The sanitised, upper-case text.
# @exitcode 0 Always.
# @example
#   shell::strings::sanitize::upper "my var-name"   # -> MY_VAR_NAME
#
shell::strings::sanitize::upper() {
	printf '%s\n' "${1-}" | tr '[:lower:]' '[:upper:]' | sed -e 's/[^A-Z0-9_]/_/g'
}

# @description Lower-case a string and replace every char outside [a-z0-9_] with `_`.
# @arg $1 string Text to convert.
# @stdout The sanitised, lower-case text.
# @exitcode 0 Always.
# @example
#   shell::strings::sanitize::lower "My Var-Name"   # -> my_var_name
#
shell::strings::sanitize::lower() {
	printf '%s\n' "${1-}" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9_]/_/g'
}

# @description Capitalise the first letter and collapse non-alphanumerics to `_`.
#   Leading and trailing underscores are removed.
# @arg $1 string Text to convert.
# @stdout The sanitised text (empty for empty input).
# @exitcode 0 Always.
# @example
#   shell::strings::sanitize::capitalize "hello world"   # -> Hello_world
#
shell::strings::sanitize::capitalize() {
	local input="${1-}"
	if [ -z "$input" ]; then
		printf '\n'
		return "$RETURN_SUCCESS"
	fi

	# Upper-case only the first character, keep the rest untouched.
	local first rest
	first="$(printf '%s' "${input:0:1}" | tr '[:lower:]' '[:upper:]')"
	rest="${input:1}"

	# `tr -cs` squeezes every run of non-alphanumeric chars into one `_`.
	printf '%s%s\n' "$first" "$rest" | tr -cs '[:alnum:]_' '_' | sed 's/^_//;s/_$//'
}

# @description Lower-case a string and collapse non-alphanumerics to `_` (no capitalisation).
# @arg $1 string Text to convert.
# @stdout The sanitised, lower-case text (empty for empty input).
# @exitcode 0 Always.
# @example
#   shell::strings::sanitize::lower_preserve "Hello, World"   # -> hello_world
#
shell::strings::sanitize::lower_preserve() {
	local input="${1-}"
	if [ -z "$input" ]; then
		printf '\n'
		return "$RETURN_SUCCESS"
	fi
	printf '%s\n' "$input" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]_' '_' | sed 's/^_//;s/_$//'
}

# @description Convert text to PascalCase ("my var name" -> "MyVarName").
#   Despite the historical name `camel`, the first letter IS capitalised.
# @arg $1 string Text to convert.
# @stdout The PascalCase text.
# @exitcode 0 Always.
# @example
#   shell::strings::format::camel "my_var name"   # -> MyVarName
#
shell::strings::format::camel() {
	# Turn every separator into a space, capitalise each word, then drop the spaces.
	printf '%s\n' "${1-}" |
		sed -e 's/[^a-zA-Z0-9]/ /g' |
		awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2) } 1' |
		tr -d ' '
}

# @description Capitalise the first letter of every space-separated word.
# @option -h | --help Show help and return.
# @arg $1 string Text to convert.
# @stdout The title-cased text.
# @exitcode 0 Success.
# @exitcode 2 Not exactly one argument was given.
# @example
#   shell::strings::format::title "hello big world"   # -> Hello Big World
#
shell::strings::format::title() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Capitalise the first letter of every word"
		shell::logger::usage "shell::strings::format::title <string>"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::strings::format::title \"hello world\""
		return "$RETURN_SUCCESS"
	fi

	if [ "$#" -ne 1 ]; then
		shell::logger::error "Usage: shell::strings::format::title <string>"
		return "$RETURN_INVALID"
	fi

	# awk keeps this portable (no bash-4 ${var^}) and handles any number of words.
	printf '%s\n' "$1" | awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2) } 1'
}

# @description Escape text so it can be embedded in a double-quoted shell string.
#   Escapes backslash, forward slash, double quote and single quote, flattens
#   newlines/tabs to spaces, squeezes repeated spaces and trims the ends.
# @arg $1 string Text to escape.
# @stdout The escaped single-line text (no trailing newline).
# @exitcode 0 Always.
# @example
#   shell::strings::sanitize::escape 'say "hi" / there'
#
shell::strings::sanitize::escape() {
	# One sed program applies the escapes in order: backslash first so the
	# backslashes added by the later rules are not escaped again.
	printf '%s' "${1-}" |
		tr '\n\t' '  ' |
		sed -e 's/\\/\\\\/g' \
			-e 's/\//\\\//g' \
			-e 's/"/\\"/g' \
			-e "s/'/'\\\\''/g" \
			-e 's/  */ /g' \
			-e 's/^[[:space:]]*//' \
			-e 's/[[:space:]]*$//'
}
