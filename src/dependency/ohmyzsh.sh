#!/usr/bin/env bash
# @file dependency/ohmyzsh.sh
# @brief Install and remove Oh My Zsh.

# @description Install Oh My Zsh with the official installer.
#   The installer is run with `RUNZSH=no` so it does not `exec zsh` at the end,
#   which would replace (and effectively kill) the shell running this function.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the installer command instead of running it.
# @exitcode 0 Installed, already installed, or dry-run printed.
# @exitcode 1 The installer failed.
# @example
#   shell::ohmyzsh::install
#
shell::ohmyzsh::install() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Install Oh My Zsh"
		shell::logger::usage "shell::ohmyzsh::install [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ohmyzsh::install"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	# ZSH is the variable the official installer itself uses for this path.
	local target="${ZSH:-$HOME/.oh-my-zsh}"
	if [ -d "$target" ]; then
		shell::logger::warn "Oh My Zsh is already installed ($target)."
		return "$RETURN_SUCCESS"
	fi

	if [ "$dry_run" = "true" ]; then
		RUNZSH=no shell::net::run_remote_script -n "$SHELL_URL_OHMYZSH_INSTALL" sh
		return "$RETURN_SUCCESS"
	fi

	# Oh My Zsh needs zsh, git and curl.
	shell::dependency::ensure zsh || return "$RETURN_FAILURE"
	shell::dependency::git::ensure || return "$RETURN_FAILURE"
	shell::dependency::curl::ensure || return "$RETURN_FAILURE"

	shell::logger::info "Installing Oh My Zsh..."
	RUNZSH=no shell::net::run_remote_script "$SHELL_URL_OHMYZSH_INSTALL" sh || return "$RETURN_FAILURE"
	shell::logger::success "Oh My Zsh installed."
}

# @description Uninstall Oh My Zsh and restore the original `.zshrc` backup.
#   Asks for confirmation unless `-y` is given.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the commands instead of running them.
# @option -y | --yes Do not ask for confirmation.
# @exitcode 0 Removed, absent, or the user declined.
# @exitcode 1 A removal step failed.
# @example
#   shell::ohmyzsh::uninstall -y
#
shell::ohmyzsh::uninstall() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Uninstall Oh My Zsh and restore the original .zshrc"
		shell::logger::usage "shell::ohmyzsh::uninstall [-n] [-y]"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "-y, --yes" "Skip the confirmation prompt"
		shell::logger::option "-h, --help" "Display this help message"
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

	local target="${ZSH:-$HOME/.oh-my-zsh}"
	local backup="$HOME/.zshrc.pre-oh-my-zsh"

	if [ ! -d "$target" ]; then
		shell::logger::warn "Oh My Zsh is not installed."
		return "$RETURN_SUCCESS"
	fi

	# Safety net: never run `rm -rf` on a path that is empty or "/" or $HOME.
	if [ -z "$target" ] || [ "$target" = "/" ] || [ "$target" = "$HOME" ]; then
		shell::logger::error "Refusing to remove unsafe path '$target'."
		return "$RETURN_INVALID"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "rm -rf \"$target\""
		[ -f "$backup" ] && shell::logger::command_clip "mv \"$backup\" \"$HOME/.zshrc\""
		return "$RETURN_SUCCESS"
	fi

	if [ "$assume_yes" != "true" ]; then
		shell::ask::accept "Remove $target?" || {
			shell::logger::info "Aborted."
			return "$RETURN_SUCCESS"
		}
	fi

	shell::exec::command rm -rf "$target" || return "$RETURN_FAILURE"

	if [ -f "$backup" ]; then
		shell::exec::command mv "$backup" "$HOME/.zshrc" || return "$RETURN_FAILURE"
		shell::logger::info "Original .zshrc restored from backup."
	else
		shell::logger::warn "No backup .zshrc found. Update your .zshrc manually if necessary."
	fi

	shell::logger::success "Oh My Zsh uninstalled."
}
