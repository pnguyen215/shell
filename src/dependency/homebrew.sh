#!/usr/bin/env bash
# @file dependency/homebrew.sh
# @brief Install, activate and remove Homebrew.
# @description
#   Homebrew is the macOS package manager (and optional on Linux). The
#   installer is downloaded to a temporary file and only executed when the
#   download succeeded; `bash -c "$(curl ...)"` would happily run an empty
#   script when curl fails.

# @internal
# @description Print the path of the brew executable, searching known prefixes.
# @noargs
# @stdout Absolute path to `brew`.
# @exitcode 0 brew was found.
# @exitcode 3 brew is not installed.
shell::homebrew::path() {
	local candidate
	# PATH first, then the default prefixes: Apple Silicon, Intel, Linuxbrew.
	if command -v brew >/dev/null 2>&1; then
		command -v brew
		return "$RETURN_SUCCESS"
	fi
	for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
		if [ -x "$candidate" ]; then
			printf '%s\n' "$candidate"
			return "$RETURN_SUCCESS"
		fi
	done
	return "$RETURN_NOT_FOUND"
}

# @description Add Homebrew to PATH for the *current* shell session.
#   A fresh Apple-Silicon install lives in /opt/homebrew, which is not on PATH
#   until `brew shellenv` runs. Without this, the very next `brew install`
#   fails with "command not found".
# @noargs
# @exitcode 0 brew is now on PATH.
# @exitcode 3 brew is not installed.
shell::homebrew::activate() {
	local brew_bin
	brew_bin="$(shell::homebrew::path)" || return "$RETURN_NOT_FOUND"
	eval "$("$brew_bin" shellenv)"
}

# @description Install Homebrew with the official installer.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the installer command instead of running it.
# @exitcode 0 Homebrew is installed (or dry-run printed).
# @exitcode 1 The installer failed.
# @example
#   shell::homebrew::install
#   shell::homebrew::install -n
#
shell::homebrew::install() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Install Homebrew using the official installer"
		shell::logger::usage "shell::homebrew::install [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::homebrew::install"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if shell::homebrew::path >/dev/null 2>&1; then
		shell::logger::debug "Homebrew is already installed."
		shell::homebrew::activate
		return "$RETURN_SUCCESS"
	fi

	# The installer itself needs git and curl.
	shell::dependency::curl::ensure || return "$RETURN_FAILURE"

	if [ "$dry_run" = "true" ]; then
		shell::net::run_remote_script -n "$SHELL_URL_HOMEBREW_INSTALL" bash
		return "$RETURN_SUCCESS"
	fi

	shell::logger::info "Installing Homebrew..."
	shell::net::run_remote_script "$SHELL_URL_HOMEBREW_INSTALL" bash || return "$RETURN_FAILURE"
	shell::homebrew::activate
	shell::logger::success "Homebrew installed."
}

# @description Uninstall Homebrew and remove its lines from the shell profile.
#   Asks for confirmation unless `-y` is given, because the official
#   uninstaller removes every formula and cask.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the commands instead of running them.
# @option -y | --yes Do not ask for confirmation.
# @exitcode 0 Homebrew was removed, was absent, or the user declined.
# @exitcode 1 The uninstaller failed.
# @example
#   shell::homebrew::uninstall -y
#
shell::homebrew::uninstall() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Uninstall Homebrew and clean its shell-profile lines"
		shell::logger::usage "shell::homebrew::uninstall [-n] [-y]"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "-y, --yes" "Skip the confirmation prompt"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::homebrew::uninstall -n"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" assume_yes="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-y | --yes) assume_yes="true" ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done

	if ! shell::homebrew::path >/dev/null 2>&1; then
		shell::logger::warn "Homebrew is not installed. Nothing to uninstall."
		return "$RETURN_SUCCESS"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::net::run_remote_script -n "$SHELL_URL_HOMEBREW_UNINSTALL" bash
		shell::logger::command_clip "sed -i.bak -e '/# Homebrew/d' -e '/brew shellenv/d' \"\$HOME/.zprofile\""
		return "$RETURN_SUCCESS"
	fi

	if [ "$assume_yes" != "true" ]; then
		shell::ask::accept "This removes Homebrew and ALL its packages. Continue?" || {
			shell::logger::info "Aborted."
			return "$RETURN_SUCCESS"
		}
	fi

	shell::net::run_remote_script "$SHELL_URL_HOMEBREW_UNINSTALL" bash || return "$RETURN_FAILURE"

	# Drop both the "# Homebrew" comment and the `brew shellenv` line the installer
	# appended (the earlier version only matched the comment, and its quoting was
	# broken so even that did not work).
	if [ -f "$HOME/.zprofile" ]; then
		shell::fs::sed_inplace -e '/# Homebrew/d' -e '/brew shellenv/d' "$HOME/.zprofile"
	fi

	shell::logger::success "Homebrew uninstalled."
}
