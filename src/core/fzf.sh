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
#
#   Cursor memory: fzf always starts on the first line, so a menu that shows
#   the same list again after a view or action loses the user's place. Pass the
#   previously selected line with --initial and the cursor starts on it again.
#   The line is looked up in the current list by VALUE (so it still works when
#   the order or content changed); if it is gone, --initial-pos (a 1-based
#   index) is used, and if that is not usable either, fzf starts on the first
#   line. Without these options the behavior is unchanged. Needs fzf with the
#   `start` event (0.35+) when an initial position is applied.
# @option -h | --help Show help and return.
# @option --initial <value> Optional. Start on the line equal to <value>.
# @option --initial-field <N> Optional. Compare <value> with field N of each line (1-based,
#   split on the --delimiter given to fzf, or on whitespace). Default 0 = the whole line.
# @option --initial-pos <N> Optional. 1-based line to start on when --initial is not found.
# @arg $@ string Extra fzf arguments (e.g. --prompt="Pick: ", --multi, --preview=...).
# @stdin Candidate lines.
# @stdout The selected line(s).
# @exitcode 0 A selection was made.
# @exitcode 9 The user cancelled, or nothing matched.
# @exitcode 3 fzf is not installed and could not be installed.
# @exitcode 2 An option is missing its value, or a value is not a number.
# @example
#   branch="$(git branch --format='%(refname:short)' | shell::fzf::select --prompt='Branch: ')"
#   # Re-show the list with the cursor on the previous choice:
#   branch="$(git branch --format='%(refname:short)' | shell::fzf::select --initial "$branch")"
#
shell::fzf::select() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Run fzf with the library's default look and feel"
		shell::logger::usage "<candidates> | shell::fzf::select [--initial <value>] [--initial-field <N>] [--initial-pos <N>] [fzf arguments...]"
		shell::logger::option "--initial <value>" "Start the cursor on the line equal to <value> (cursor memory)"
		shell::logger::option "--initial-field <N>" "Compare <value> with field N of each line instead of the whole line"
		shell::logger::option "--initial-pos <N>" "1-based line to start on when --initial is not found"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "printf 'a\nb\n' | shell::fzf::select --prompt='Pick: '"
		shell::logger::example "printf 'a\nb\n' | shell::fzf::select --initial b"
		return "$RETURN_SUCCESS"
	fi

	shell::dependency::fzf::ensure || return "$RETURN_NOT_FOUND"

	# Split the cursor-memory options from the plain fzf arguments (CHANGED).
	local selection has_initial="false" initial="" initial_field=0 initial_pos="" delimiter=""
	local -a fzf_args=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--initial | --initial-field | --initial-pos)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			case "$1" in
			--initial)
				has_initial="true"
				initial="$2"
				;;
			--initial-field | --initial-pos)
				case "$2" in
				'' | *[!0-9]*)
					shell::logger::error "Option $1 requires a number"
					return "$RETURN_INVALID"
					;;
				esac
				if [ "$1" = "--initial-field" ]; then initial_field="$2"; else initial_pos="$2"; fi
				;;
			esac
			shift 2
			;;
		--delimiter=*)
			delimiter="${1#--delimiter=}"
			fzf_args+=("$1")
			shift
			;;
		--delimiter)
			if [ "$#" -ge 2 ]; then
				delimiter="$2"
				fzf_args+=("$1" "$2")
				shift 2
			else
				fzf_args+=("$1")
				shift
			fi
			;;
		*)
			fzf_args+=("$1")
			shift
			;;
		esac
	done

	# Resolve the start position (CHANGED). Only when asked; otherwise stdin goes straight to fzf.
	local -a pos_args=()
	if [ "$has_initial" = "true" ] || [ -n "$initial_pos" ]; then
		local candidates pos=""
		candidates="$(cat)"
		if [ -n "$candidates" ]; then
			if [ "$has_initial" = "true" ]; then
				# By value first: ENVIRON (not awk -v) keeps backslashes and spaces intact.
				# Lines are counted as fzf counts them (empty lines included), 1-based.
				# An array, not ${delimiter:+-F "$delimiter"}: zsh does not word-split that form.
				local -a awk_fs=()
				if [ -n "$delimiter" ]; then awk_fs=(-F "$delimiter"); fi
				pos="$(printf '%s\n' "$candidates" | SHELL_FZF_INITIAL="$initial" awk \
					${awk_fs[@]+"${awk_fs[@]}"} -v f="$initial_field" '
					# fzf --ansi prints the selection without color codes, so strip them from the list too.
					{ line = $0; gsub(/\033\[[0-9;]*[A-Za-z]/, "", line); $0 = line; v = (f > 0 ? $f : $0) }
					v == ENVIRON["SHELL_FZF_INITIAL"] { print NR; exit }')"
			fi
			case "$pos" in
			'' | *[!0-9]*) pos="$initial_pos" ;; # not found: saved index
			esac
			case "$pos" in
			'' | *[!0-9]* | 0) pos="" ;; # unusable: first line
			esac
		fi
		if [ -n "$pos" ]; then
			# --sync: fzf reads the whole list before `start` fires, so pos() is applied
			# to the full list; pos() clamps to its length, so a stale index is harmless.
			pos_args=(--sync "--bind=start:pos(${pos})")
		fi
		# stdin was consumed above: replay it.
		selection="$(printf '%s\n' "$candidates" | fzf "${SHELL_FZF_OPTS[@]}" ${fzf_args[@]+"${fzf_args[@]}"} ${pos_args[@]+"${pos_args[@]}"})" || return "$RETURN_CANCELLED"
		printf '%s\n' "$selection"
		return "$RETURN_SUCCESS"
	fi

	# fzf exit codes: 0 = selected, 1 = no match, 130 = interrupted (ESC/Ctrl-C).
	selection="$(fzf "${SHELL_FZF_OPTS[@]}" ${fzf_args[@]+"${fzf_args[@]}"})" || return "$RETURN_CANCELLED"

	printf '%s\n' "$selection"
}

# @description Show a list, run a command on the chosen item, then return to the list.
#   A menu loop built on shell::fzf::select. The candidates are read from
#   **stdin** once; after every selection `<command> [args...] <item>` runs in
#   the current shell (so it can be a shell function) and the same list is shown
#   again. The loop ends when the user presses ESC / Ctrl-C or, with `--back`,
#   picks the "back" entry (`SHELL_FZF_BACK_LABEL`, listed last so that Enter
#   never lands on it by accident). When the list comes back, the cursor is on
#   the item that was chosen last (cursor memory, see shell::fzf::select --initial).
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
	local -a initial_args=() # CHANGED: last chosen item, passed back as the start position
	while true; do
		if [ "$back" = "true" ]; then
			choice="$(printf '%s\n%s\n' "$candidates" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select ${initial_args[@]+"${initial_args[@]}"} ${fzf_args[@]+"${fzf_args[@]}"})"
		else
			choice="$(printf '%s\n' "$candidates" | shell::fzf::select ${initial_args[@]+"${initial_args[@]}"} ${fzf_args[@]+"${fzf_args[@]}"})"
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

		initial_args=(--initial "$choice") # CHANGED: remember the cursor
		"$@" "$choice" || shell::logger::warn "'$1' exited with status $?"

		if [ "$pause" = "true" ] && [ -r /dev/tty ]; then
			printf 'Press Enter to return to the list...' >&2
			read -r _ </dev/tty || return "$RETURN_SUCCESS"
		fi
	done
}
