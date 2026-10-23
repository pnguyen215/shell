#!/usr/bin/env bash
# @file core/ask.sh
# @brief Interactive prompts: yes/no, text, secret, number, path and menus.
# @description
#   All prompts write the *question* to stderr and the *answer* to stdout, so
#   `answer="$(shell::ask::text "Name?")"` captures only the answer.
#
#   Cancelling (ESC in a menu, Ctrl-D / EOF in a text prompt) returns
#   RETURN_CANCELLED. Earlier versions looped forever in those cases, which
#   made it impossible to abort - and hung any non-interactive caller.

# @internal
# @description Read one line from the terminal with a coloured prompt.
# @arg $1 string Prompt tag shown in brackets, e.g. "e", "p", "n".
# @arg $2 string Question text.
# @arg $3 string "secret" to disable echo (passwords); anything else echoes.
# @stdout The trimmed line the user typed.
# @exitcode 0 A line was read.
# @exitcode 9 EOF / Ctrl-D (cancelled).
shell::ask::read_line() {
	local tag="$1"
	local question="$2"
	local mode="${3-}"
	local line=""

	shell::console::print "[${tag}] ${question} " "$SHELL_COLOR_PROMPT" -n >&2

	# `read -s` suppresses echo; `-r` keeps backslashes literal.
	if [ "$mode" = "secret" ]; then
		read -r -s line || {
			printf '\n' >&2
			return "$RETURN_CANCELLED"
		}
		printf '\n' >&2
	else
		read -r line || {
			printf '\n' >&2
			return "$RETURN_CANCELLED"
		}
	fi

	shell::strings::trim "$line"
}

# @description Ask a yes/no question with an fzf menu and print the answer.
# @option -h | --help Show help and return.
# @arg $1 string The question.
# @stdout "yes" or "no".
# @exitcode 0 An answer was chosen.
# @exitcode 2 The question is empty.
# @exitcode 9 The user cancelled (ESC).
# @example
#   [ "$(shell::ask::reply "Overwrite?")" = "yes" ] && echo "overwriting"
#
shell::ask::reply() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Ask a yes/no question (fzf) and print yes or no"
		shell::logger::usage "shell::ask::reply <question>"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ask::reply \"Overwrite the file?\""
		return "$RETURN_SUCCESS"
	fi

	if [ -z "${1-}" ]; then
		shell::logger::error "Question cannot be empty."
		return "$RETURN_INVALID"
	fi

	printf 'yes\nno\n' | shell::fzf::select --prompt="$1 " --height="10%"
}

# @description Ask a yes/no question on the terminal; succeed when answered **no**.
#   Reads naturally in guard clauses: `shell::ask::deny "Abort?" && return`.
# @option -h | --help Show help and return.
# @arg $1 string The question.
# @exitcode 0 The user answered no (denied).
# @exitcode 1 The user answered yes.
# @exitcode 2 The question is empty.
# @exitcode 9 Input ended (EOF).
shell::ask::deny() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Ask y/n; succeeds when the answer is NO"
		shell::logger::usage "shell::ask::deny <question>"
		shell::logger::option "-h, --help" "Display this help message"
		return "$RETURN_SUCCESS"
	fi

	if [ -z "${1-}" ]; then
		shell::logger::error "Question cannot be empty."
		return "$RETURN_INVALID"
	fi

	local answer
	while true; do
		answer="$(shell::ask::read_line "q" "$1 (y/n)")" || return "$RETURN_CANCELLED"
		case "$answer" in
		[Yy] | [Yy][Ee][Ss]) return "$RETURN_FAILURE" ;;
		[Nn] | [Nn][Oo]) return "$RETURN_SUCCESS" ;;
		*) shell::logger::warn "Please answer y/yes or n/no." ;;
		esac
	done
}

# @description Ask a yes/no question on the terminal; succeed when answered **yes**.
#   **Bug fix:** the previous implementation never returned on "yes" - it fell
#   out of the `case` and asked the same question again, forever.
# @option -h | --help Show help and return.
# @arg $1 string The question.
# @exitcode 0 The user answered yes.
# @exitcode 1 The user answered no.
# @exitcode 2 The question is empty.
# @exitcode 9 Input ended (EOF).
# @example
#   if shell::ask::accept "Continue?"; then echo "go"; fi
#
shell::ask::accept() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Ask y/n; succeeds when the answer is YES"
		shell::logger::usage "shell::ask::accept <question>"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ask::accept \"Continue?\" && echo ok"
		return "$RETURN_SUCCESS"
	fi

	if [ -z "${1-}" ]; then
		shell::logger::error "Question cannot be empty."
		return "$RETURN_INVALID"
	fi

	local answer
	while true; do
		answer="$(shell::ask::read_line "q" "$1 (y/n)")" || return "$RETURN_CANCELLED"
		case "$answer" in
		[Yy] | [Yy][Ee][Ss]) return "$RETURN_SUCCESS" ;;
		[Nn] | [Nn][Oo]) return "$RETURN_FAILURE" ;;
		*) shell::logger::warn "Please answer 'y/yes' or 'n/no'." ;;
		esac
	done
}

# @description Prompt for a non-empty line of text.
# @option -h | --help Show help and return.
# @arg $1 string The question.
# @stdout The trimmed text.
# @exitcode 0 A value was entered.
# @exitcode 2 The question is empty.
# @exitcode 9 Input ended (EOF).
# @example
#   name="$(shell::ask::text "Project name?")"
#
shell::ask::text() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Prompt for a non-empty line of text"
		shell::logger::usage "shell::ask::text <question>"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "name=\"\$(shell::ask::text \"Project name?\")\""
		return "$RETURN_SUCCESS"
	fi

	if [ -z "${1-}" ]; then
		shell::logger::error "Question cannot be empty."
		return "$RETURN_INVALID"
	fi

	local value
	while true; do
		value="$(shell::ask::read_line "e" "$1")" || return "$RETURN_CANCELLED"
		if [ -n "$value" ]; then
			printf '%s\n' "$value"
			return "$RETURN_SUCCESS"
		fi
		shell::logger::error "Please enter a valid non-empty value."
	done
}

# @description Prompt for a secret (input is not echoed).
# @option -h | --help Show help and return.
# @arg $1 string The question.
# @stdout The trimmed secret.
# @exitcode 0 A value was entered.
# @exitcode 2 The question is empty.
# @exitcode 9 Input ended (EOF).
shell::ask::password() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Prompt for a secret without echoing it"
		shell::logger::usage "shell::ask::password <question>"
		shell::logger::option "-h, --help" "Display this help message"
		return "$RETURN_SUCCESS"
	fi

	if [ -z "${1-}" ]; then
		shell::logger::error "Question cannot be empty."
		return "$RETURN_INVALID"
	fi

	local value
	while true; do
		value="$(shell::ask::read_line "p" "$1" secret)" || return "$RETURN_CANCELLED"
		if [ -n "$value" ]; then
			printf '%s\n' "$value"
			return "$RETURN_SUCCESS"
		fi
		shell::logger::error "Password cannot be empty. Please try again."
	done
}

# @description Prompt for a number (integer or decimal, optionally negative).
# @option -h | --help Show help and return.
# @arg $1 string The question.
# @stdout The number as typed.
# @exitcode 0 A valid number was entered.
# @exitcode 2 The question is empty.
# @exitcode 9 Input ended (EOF).
shell::ask::number() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Prompt for an integer or decimal number"
		shell::logger::usage "shell::ask::number <question>"
		shell::logger::option "-h, --help" "Display this help message"
		return "$RETURN_SUCCESS"
	fi

	if [ -z "${1-}" ]; then
		shell::logger::error "Question cannot be empty."
		return "$RETURN_INVALID"
	fi

	local value
	while true; do
		value="$(shell::ask::read_line "n" "$1")" || return "$RETURN_CANCELLED"
		# Optional minus, digits, optional fractional part.
		if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
			printf '%s\n' "$value"
			return "$RETURN_SUCCESS"
		fi
		shell::logger::error "Please enter a valid numeric value (e.g., 42 or 3.14)."
	done
}

# @description Prompt for a filesystem path, optionally validating it.
#   A leading `~` is expanded to `$HOME`.
# @option -h | --help Show help and return.
# @option --exists The path must exist.
# @option --dir The path must be a directory (implies --exists).
# @option --file The path must be a regular file (implies --exists).
# @option --writable The path must be writable.
# @option --readable The path must be readable.
# @arg $1 string The question.
# @stdout The validated path (with `~` expanded).
# @exitcode 0 A valid path was entered.
# @exitcode 2 Unknown option or empty question.
# @exitcode 9 Input ended (EOF).
# @example
#   dir="$(shell::ask::path --dir --writable "Output directory?")"
#
shell::ask::path() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Prompt for a filesystem path with optional validation"
		shell::logger::usage "shell::ask::path [--exists] [--dir] [--file] [--writable] [--readable] <question>"
		shell::logger::option "--exists" "Path must exist"
		shell::logger::option "--dir" "Path must be a directory"
		shell::logger::option "--file" "Path must be a regular file"
		shell::logger::option "--writable" "Path must be writable"
		shell::logger::option "--readable" "Path must be readable"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ask::path --dir \"Output directory?\""
		return "$RETURN_SUCCESS"
	fi

	local need_exists="false" need_dir="false" need_file="false"
	local need_writable="false" need_readable="false"

	while [ "${1-}" != "" ] && [ "${1#--}" != "$1" ]; do
		case "$1" in
		--exists) need_exists="true" ;;
		--dir)
			need_dir="true"
			need_exists="true"
			;;
		--file)
			need_file="true"
			need_exists="true"
			;;
		--writable) need_writable="true" ;;
		--readable) need_readable="true" ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done

	if [ -z "${1-}" ]; then
		shell::logger::error "Question cannot be empty."
		return "$RETURN_INVALID"
	fi

	local value
	while true; do
		value="$(shell::ask::read_line "p" "$1")" || return "$RETURN_CANCELLED"

		if [ -z "$value" ]; then
			shell::logger::error "Path cannot be empty. Please enter a valid path."
			continue
		fi

		# Expand a leading ~ ourselves (it is not expanded inside quotes).
		# shellcheck disable=SC2088  # we match the literal characters "~" and "~/"
		case "$value" in
		"~") value="$HOME" ;;
		"~/"*) value="$HOME/${value#\~/}" ;;
		esac

		if [ "$need_exists" = "true" ] && [ ! -e "$value" ]; then
			shell::logger::error "Path '$value' does not exist."
		elif [ "$need_dir" = "true" ] && [ ! -d "$value" ]; then
			shell::logger::error "Path '$value' is not a directory."
		elif [ "$need_file" = "true" ] && [ ! -f "$value" ]; then
			shell::logger::error "Path '$value' is not a regular file."
		elif [ "$need_writable" = "true" ] && [ ! -w "$value" ]; then
			shell::logger::error "Path '$value' is not writable."
		elif [ "$need_readable" = "true" ] && [ ! -r "$value" ]; then
			shell::logger::error "Path '$value' is not readable."
		else
			printf '%s\n' "$value"
			return "$RETURN_SUCCESS"
		fi
	done
}

# @description Choose ONE entry from a list with fzf.
# @option -h | --help Show help and return.
# @arg $@ string The choices.
# @stdout The chosen entry.
# @exitcode 0 An entry was chosen.
# @exitcode 2 No choices were given.
# @exitcode 9 The user cancelled (ESC).
# @example
#   env="$(shell::ask::option dev staging prod)" || return
#
shell::ask::option() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Choose one entry from a list (fzf)"
		shell::logger::usage "shell::ask::option <choice1> [choice2 ...]"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ask::option dev staging prod"
		return "$RETURN_SUCCESS"
	fi

	if [ "$#" -eq 0 ]; then
		shell::logger::error "No options provided to shell::ask::option."
		return "$RETURN_INVALID"
	fi

	printf '%s\n' "$@" | shell::fzf::select --prompt="Select an option: "
}

# @description Choose one entry from `label:value` pairs; print the value.
#   Only the label is displayed; the text after the first colon is returned.
# @option -h | --help Show help and return.
# @arg $@ string Entries in the form `label:value`.
# @stdout The value belonging to the chosen label.
# @exitcode 0 An entry was chosen.
# @exitcode 2 No entries were given.
# @exitcode 9 The user cancelled (ESC).
# @example
#   port="$(shell::ask::option::value "HTTP:80" "HTTPS:443")"
#
shell::ask::option::value() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Choose a label; print the value attached to it"
		shell::logger::usage "shell::ask::option::value <label:value> [label:value ...]"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ask::option::value \"HTTP:80\" \"HTTPS:443\""
		return "$RETURN_SUCCESS"
	fi

	if [ "$#" -eq 0 ]; then
		shell::logger::error "No options provided to shell::ask::option::value."
		return "$RETURN_INVALID"
	fi

	# Show only the part before the first colon.
	local entry label
	label="$(
		for entry in "$@"; do
			printf '%s\n' "${entry%%:*}"
		done | shell::fzf::select --prompt="Select an option: "
	)" || return "$RETURN_CANCELLED"

	# Return the part after the first colon of the matching entry.
	for entry in "$@"; do
		if [ "${entry%%:*}" = "$label" ]; then
			printf '%s\n' "${entry#*:}"
			return "$RETURN_SUCCESS"
		fi
	done
	return "$RETURN_NOT_FOUND"
}

# @description Choose SEVERAL entries from a list with fzf (Tab to mark).
# @option -h | --help Show help and return.
# @arg $@ string The choices.
# @stdout The chosen entries, separated by single spaces (empty if none).
# @exitcode 0 Zero or more entries were chosen.
# @exitcode 2 No choices were given.
# @example
#   picks="$(shell::ask::options alpha beta gamma)"
#
shell::ask::options() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Choose several entries from a list (Tab to mark, Enter to confirm)"
		shell::logger::usage "shell::ask::options <choice1> [choice2 ...]"
		shell::logger::option "-h, --help" "Display this help message"
		return "$RETURN_SUCCESS"
	fi

	if [ "$#" -eq 0 ]; then
		shell::logger::error "No options provided to shell::ask::options."
		return "$RETURN_INVALID"
	fi

	local picked
	picked="$(printf '%s\n' "$@" | shell::fzf::select --multi \
		--prompt="Select options (Tab to select, Enter to confirm): ")" || return "$RETURN_SUCCESS"

	# Join the selected lines with single spaces.
	printf '%s\n' "$picked" | tr '\n' ' ' | sed 's/[[:space:]]*$//'
	printf '\n'
}

# @description Choose several `label:value` entries; print the values.
# @option -h | --help Show help and return.
# @arg $@ string Entries in the form `label:value`.
# @stdout The values of the chosen labels, separated by single spaces.
# @exitcode 0 Zero or more entries were chosen.
# @exitcode 2 No entries were given.
shell::ask::options::values() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Choose several labels; print the values attached to them"
		shell::logger::usage "shell::ask::options::values <label:value> [label:value ...]"
		shell::logger::option "-h, --help" "Display this help message"
		return "$RETURN_SUCCESS"
	fi

	if [ "$#" -eq 0 ]; then
		shell::logger::error "No options provided to shell::ask::options::values."
		return "$RETURN_INVALID"
	fi

	local entry labels
	labels="$(
		for entry in "$@"; do
			printf '%s\n' "${entry%%:*}"
		done | shell::fzf::select --multi \
			--prompt="Select options (Tab to select, Enter to confirm): "
	)" || return "$RETURN_SUCCESS"

	local label values=""
	# Walk the chosen labels and collect the matching values.
	while IFS= read -r label; do
		[ -n "$label" ] || continue
		for entry in "$@"; do
			if [ "${entry%%:*}" = "$label" ]; then
				values="${values:+$values }${entry#*:}"
				break
			fi
		done
	done <<<"$labels"

	printf '%s\n' "$values"
}
