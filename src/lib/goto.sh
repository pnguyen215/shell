#!/usr/bin/env bash
# @file lib/goto.sh
# @brief `goto` command: bookmark navigation front-end.

# @description Print the goto version.
# @noargs
# @stdout "goto v0.0.1".
# @exitcode 0 Always.
shell::goto::version() {
	printf 'goto v0.0.1\n'
}

# @description Print the goto command reference.
# @noargs
# @stdout The command list.
# @exitcode 0 Always.
shell::goto::usage() {
	cat <<'USAGE'
  USAGE:

    shell::goto <command>

  COMMANDS:

    shell::goto                         # List all bookmarks.
    shell::goto <bookmark name>         # Go to a bookmarked directory.
    shell::goto -s <bookmark name>      # Save the current directory under a name (-b is an alias).
    shell::goto -d <bookmark name>      # Delete a bookmark.
    shell::goto -l | -list | -all       # List all bookmarks.
    shell::goto back                    # Go back to the previous directory.
    shell::goto -cp                     # Copy the current directory to the clipboard.
    shell::goto -v | -ver               # Show the version.
    shell::goto -h | help               # Show this help.

    shell::directory::open [location]   # Open a directory in the file manager.
USAGE
}

# @description Navigate and manage directory bookmarks with a single command.
#   Fixes: `-b` used to be shadowed by the "save" branch so `back | -b` never
#   ran; `$2` was passed unquoted, which broke names containing spaces.
# @option -s | -b Save the current directory as a bookmark (needs a name).
# @option -d Delete a bookmark (needs a name).
# @option -l | --list List bookmarks (`-list` and `-all` are accepted too).
# @arg $1 string -cp: copy the current directory to the clipboard.
# @option -v | --version Show the version (`-ver` is accepted too).
# @option -h | help Show the command reference.
# @arg $1 string A bookmark name to jump to, or `back`.
# @exitcode 0 Success.
# @exitcode 2 A command that needs a bookmark name did not get one.
# @example
#   shell::goto myproject
#   shell::goto -s myproject
#   shell::goto back
#
shell::goto::run() {
	if [ "$#" -eq 0 ]; then
		shell::bookmark::list
		return $?
	fi

	case "$1" in
	-v | -ver | --version) shell::goto::version ;;
	-cp) shell::clipboard::copy_cwd ;;
	-s | -b)
		[ -n "${2-}" ] || {
			shell::logger::error "A bookmark name is required."
			return "$RETURN_INVALID"
		}
		shell::bookmark::add "$2"
		;;
	-d)
		[ -n "${2-}" ] || {
			shell::logger::error "A bookmark name is required."
			return "$RETURN_INVALID"
		}
		shell::bookmark::remove "$2"
		;;
	-l | --list | -list | -all) shell::bookmark::list ;;
	-h | help | --help) shell::goto::usage ;;
	back) shell::directory::back ;;
	*)
		if [ "$#" -ne 1 ]; then
			shell::logger::warn "What?! Run 'shell::goto help' for usage."
			return "$RETURN_INVALID"
		fi
		shell::bookmark::go "$1"
		;;
	esac
}
