#!/usr/bin/env bash
# @file core/fzf.sh
# @brief Single entry point for every interactive fuzzy picker.
# @description
#   Instead of repeating the same eight fzf flags in every function, pickers
#   call shell::fzf::select. The look-and-feel is controlled by the
#   SHELL_FZF_OPTS array in constant/defaults.sh.

# @description Run fzf with the library's default options.
#   Reads candidate lines from **stdin** and prints the selection on stdout.
#   fzf is installed on demand (see shell::dependency::fzf::ensure).
#
#   Pressing ESC / Ctrl-C is reported as RETURN_CANCELLED so callers can stop
#   instead of looping forever (the previous prompts re-asked indefinitely).
# @option -h | --help Show help and return.
# @arg $@ string Extra fzf arguments (e.g. --prompt="Pick: ", --multi, --preview=...).
# @stdin Candidate lines.
# @stdout The selected line(s).
# @exitcode 0 A selection was made.
# @exitcode 9 The user cancelled, or nothing matched.
# @exitcode 3 fzf is not installed and could not be installed.
# @example
#   branch="$(git branch --format='%(refname:short)' | shell::fzf::select --prompt='Branch: ')"
#
shell::fzf::select() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Run fzf with the library's default look and feel"
		shell::logger::usage "<candidates> | shell::fzf::select [fzf arguments...]"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "printf 'a\\nb\\n' | shell::fzf::select --prompt='Pick: '"
		return "$RETURN_SUCCESS"
	fi

	shell::dependency::fzf::ensure || return "$RETURN_NOT_FOUND"

	# fzf exit codes: 0 = selected, 1 = no match, 130 = interrupted (ESC/Ctrl-C).
	local selection
	selection="$(fzf "${SHELL_FZF_OPTS[@]}" "$@")" || return "$RETURN_CANCELLED"

	printf '%s\n' "$selection"
}

# @description Show a list, run a command on the chosen item, then return to the list.
#   A menu loop built on shell::fzf::select. The candidates are read from
#   **stdin** once; after every selection `<command> [args...] <item>` runs in
#   the current shell (so it can be a shell function) and the same list is shown
#   again. The loop ends when the user presses ESC / Ctrl-C or, with `--back`,
#   picks the "back" entry (`SHELL_FZF_BACK_LABEL`, listed last so that Enter
#   never lands on it by accident).
#
#   The command is run argv style (no `eval`): the item is passed as one
#   argument, spaces and quotes included. A command that fails is reported and
#   the loop continues, because it is a menu, not a pipeline.
# @option -h | --help Show help and return.
# @option -b | --back Add a "back" entry to the list that ends the loop.
# @option -p | --pause Wait for Enter after each command, so its output stays readable.
# @option -f | --fzf Pass one extra argument to fzf (repeatable), e.g. `-f --prompt="Pick: "`.
# @arg $1 string Command (or function) to run for each selection.
# @arg $@ string Arguments placed before the selected item.
# @stdin Candidate lines.
# @exitcode 0 The loop ended normally (ESC, Ctrl-C or the back entry).
# @exitcode 2 No command given, or the candidates were not piped in.
# @exitcode 3 The command, or fzf, was not found.
# @exitcode 8 There were no candidates.
# @see shell::fzf::select
# @example
#   git branch --format='%(refname:short)' | shell::fzf::loop --back git checkout
#   ls ~/notes | shell::fzf::loop -b -p -f --prompt="Note: " cat
#
shell::fzf::loop() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick an item, run a command on it, then return to the list"
		shell::logger::usage "<candidates> | shell::fzf::loop [-b] [-p] [-f <fzf-arg>]... <command> [args...]"
		shell::logger::item "command" "Command or function run as: command [args...] <item>"
		shell::logger::option "-b, --back" "Add a back entry that ends the loop"
		shell::logger::option "-p, --pause" "Wait for Enter after each command"
		shell::logger::option "-f, --fzf <arg>" "Extra fzf argument (repeatable)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "git branch --format='%(refname:short)' | shell::fzf::loop --back git checkout"
		shell::logger::example "ls ~/notes | shell::fzf::loop -b -p -f --prompt='Note: ' cat"
		return "$RETURN_SUCCESS"
	fi

	local back="false" pause="false"
	local fzf_args=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-b | --back)
			back="true"
			shift
			;;
		-p | --pause)
			pause="true"
			shift
			;;
		-f | --fzf)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			fzf_args+=("$2")
			shift 2
			;;
		--)
			shift
			break
			;;
		*) break ;;
		esac
	done

	if [ "$#" -eq 0 ]; then
		shell::logger::error "A command to run for each selection is required"
		return "$RETURN_INVALID"
	fi
	if ! shell::command::exists "$1"; then
		shell::logger::error "Command not found: $1"
		return "$RETURN_NOT_FOUND"
	fi
	if [ -t 0 ]; then
		shell::logger::error "Candidates must be piped on stdin"
		return "$RETURN_INVALID"
	fi

	local candidates
	candidates="$(cat)"
	if [ -z "$candidates" ]; then
		shell::logger::warn "No candidates to choose from"
		return "$RETURN_EMPTY"
	fi

	local choice rc
	while true; do
		if [ "$back" = "true" ]; then
			choice="$(printf '%s\n%s\n' "$candidates" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select ${fzf_args[@]+"${fzf_args[@]}"})"
		else
			choice="$(printf '%s\n' "$candidates" | shell::fzf::select ${fzf_args[@]+"${fzf_args[@]}"})"
		fi
		rc=$?

		case "$rc" in
		0) ;;
		"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
		*) return "$rc" ;;
		esac

		if [ "$back" = "true" ] && [ "$choice" = "$SHELL_FZF_BACK_LABEL" ]; then
			return "$RETURN_SUCCESS"
		fi

		"$@" "$choice" || shell::logger::warn "'$1' exited with status $?"

		if [ "$pause" = "true" ] && [ -r /dev/tty ]; then
			printf 'Press Enter to return to the list...' >&2
			read -r _ </dev/tty || return "$RETURN_SUCCESS"
		fi
	done
}
