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
