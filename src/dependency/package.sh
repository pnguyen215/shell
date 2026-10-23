#!/usr/bin/env bash
# @file dependency/package.sh
# @brief Native package-manager abstraction (apt, dnf, yum, pacman, zypper, apk, brew).
# @description
#   One interface over every supported package manager. Commands are built as
#   argv arrays and executed through shell::exec::command, so package names are
#   never re-parsed by `eval` (the previous version interpolated the name into
#   an `eval`'d string).
#
#   Snap is intentionally NOT used: snap packages are sandboxed (a snap-installed
#   `jq`/`fzf` cannot read files outside $HOME) and several names do not exist
#   there.

# @description Print the native package manager for this machine.
# @noargs
# @stdout One of: brew, apt, dnf, yum, pacman, zypper, apk, unknown.
# @exitcode 0 A package manager was found.
# @exitcode 3 No supported package manager is available.
# @example
#   [ "$(shell::package::manager)" = "apt" ] && echo "Debian family"
#
shell::package::manager() {
	local candidate
	if shell::os::is_macos; then
		# On macOS the only practical manager is Homebrew.
		if command -v brew >/dev/null 2>&1; then
			printf 'brew\n'
			return "$RETURN_SUCCESS"
		fi
		# Homebrew is installed but not on PATH yet (fresh Apple Silicon install).
		if [ -x /opt/homebrew/bin/brew ] || [ -x /usr/local/bin/brew ]; then
			printf 'brew\n'
			return "$RETURN_SUCCESS"
		fi
		printf 'unknown\n'
		return "$RETURN_NOT_FOUND"
	fi

	for candidate in apt-get dnf yum pacman zypper apk brew; do
		if command -v "$candidate" >/dev/null 2>&1; then
			# Report apt-get as "apt" so callers do not care about the binary name.
			[ "$candidate" = "apt-get" ] && candidate="apt"
			printf '%s\n' "$candidate"
			return "$RETURN_SUCCESS"
		fi
	done

	printf 'unknown\n'
	return "$RETURN_NOT_FOUND"
}

# @internal
# @description Print "sudo" when privilege escalation is needed, else nothing.
#   Root needs no sudo; Homebrew must never run as root; other users need sudo.
# @arg $1 string Package manager name.
# @stdout "sudo" or an empty string.
# @exitcode 0 Escalation is not needed or `sudo` exists.
# @exitcode 3 Escalation is needed but `sudo` is not installed.
shell::package::sudo_prefix() {
	# Homebrew refuses to run as root and never needs sudo.
	if [ "${1-}" = "brew" ]; then
		return "$RETURN_SUCCESS"
	fi

	# `id -u` is portable; $EUID is bash-only.
	if [ "$(id -u)" -eq 0 ]; then
		return "$RETURN_SUCCESS"
	fi

	if command -v sudo >/dev/null 2>&1; then
		printf 'sudo\n'
		return "$RETURN_SUCCESS"
	fi

	return "$RETURN_NOT_FOUND"
}

# @description Test whether a package is installed in the native package database.
#   This queries the *package manager*, not PATH. To test for a command use
#   shell::command::exists.
# @option -h | --help Show help and return.
# @arg $1 string Package name.
# @exitcode 0 The package is installed.
# @exitcode 1 The package is not installed.
# @exitcode 2 No package name was given.
# @exitcode 3 No supported package manager was found.
# @example
#   shell::package::is_installed git && echo "git package present"
#
shell::package::is_installed() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Check whether a package is installed (native package manager)"
		shell::logger::usage "shell::package::is_installed <package>"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::package::is_installed git"
		return "$RETURN_SUCCESS"
	fi

	local package="${1-}"
	if [ -z "$package" ]; then
		shell::logger::error "No package name provided."
		return "$RETURN_INVALID"
	fi

	local manager
	manager="$(shell::package::manager)" || return "$RETURN_NOT_FOUND"

	case "$manager" in
	apt) dpkg -s "$package" >/dev/null 2>&1 ;;
	dnf | yum | zypper) rpm -q "$package" >/dev/null 2>&1 ;;
	pacman) pacman -Qi "$package" >/dev/null 2>&1 ;;
	apk) apk info -e "$package" >/dev/null 2>&1 ;;
	brew) brew list --versions "$package" >/dev/null 2>&1 ;;
	*) return "$RETURN_NOT_FOUND" ;;
	esac
}

# @description Install one or more packages with the native package manager.
#   Already-installed packages are skipped. On apt the package index is
#   refreshed at most once per shell session.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the commands instead of running them.
# @arg $@ string Package names.
# @exitcode 0 Every package is installed (or dry-run printed).
# @exitcode 1 An installation failed.
# @exitcode 2 No package name was given.
# @exitcode 3 No package manager (or required `sudo`) is available.
# @example
#   shell::package::install jq
#   shell::package::install -n fzf git
#
shell::package::install() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Install packages with the native package manager"
		shell::logger::usage "shell::package::install [-n] <package> [package ...]"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::package::install jq"
		shell::logger::example "shell::package::install -n fzf git"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if [ "$#" -eq 0 ]; then
		shell::logger::error "No package name provided."
		return "$RETURN_INVALID"
	fi

	local manager
	manager="$(shell::package::manager)"
	if [ "$manager" = "unknown" ]; then
		if shell::os::is_macos; then
			# Bootstrap Homebrew, then retry the detection.
			if [ "$dry_run" = "true" ]; then
				shell::homebrew::install -n
				return "$RETURN_SUCCESS"
			fi
			shell::homebrew::install || return "$RETURN_NOT_FOUND"
			manager="$(shell::package::manager)"
		fi
		if [ "$manager" = "unknown" ]; then
			shell::logger::error "No supported package manager found (apt, dnf, yum, pacman, zypper, apk, brew)."
			return "$RETURN_NOT_FOUND"
		fi
	fi

	local sudo_cmd=""
	sudo_cmd="$(shell::package::sudo_prefix "$manager")" || {
		shell::logger::error "Root privileges are required but 'sudo' is not installed."
		return "$RETURN_NOT_FOUND"
	}

	local package
	for package in "$@"; do
		if shell::package::is_installed "$package"; then
			shell::logger::debug "$package is already installed. Skipping."
			continue
		fi

		# Build argv; ${sudo_cmd:+$sudo_cmd} expands to nothing when empty.
		local -a install_cmd=()
		case "$manager" in
		apt)
			# Refresh the index once per session; non-interactive to avoid prompts.
			if [ -z "${_SHELL_PKG_APT_UPDATED-}" ] && [ "$dry_run" != "true" ]; then
				shell::exec::command ${sudo_cmd:+"$sudo_cmd"} apt-get update || return "$RETURN_FAILURE"
				_SHELL_PKG_APT_UPDATED=1
			fi
			install_cmd=(${sudo_cmd:+"$sudo_cmd"} env DEBIAN_FRONTEND=noninteractive apt-get install -y "$package")
			;;
		dnf) install_cmd=(${sudo_cmd:+"$sudo_cmd"} dnf install -y "$package") ;;
		yum) install_cmd=(${sudo_cmd:+"$sudo_cmd"} yum install -y "$package") ;;
		zypper) install_cmd=(${sudo_cmd:+"$sudo_cmd"} zypper --non-interactive install "$package") ;;
		pacman) install_cmd=(${sudo_cmd:+"$sudo_cmd"} pacman -S --noconfirm "$package") ;;
		apk) install_cmd=(${sudo_cmd:+"$sudo_cmd"} apk add "$package") ;;
		brew) install_cmd=(brew install "$package") ;;
		esac

		if [ "$dry_run" = "true" ]; then
			shell::exec::command -n "${install_cmd[@]}"
			continue
		fi

		if ! shell::exec::command "${install_cmd[@]}"; then
			shell::logger::error "Failed to install '$package' via $manager."
			return "$RETURN_FAILURE"
		fi
		shell::logger::success "Successfully installed $package via $manager."
	done

	return "$RETURN_SUCCESS"
}

# @description Remove one or more packages with the native package manager.
#   Packages that are not installed are skipped with a warning.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the commands instead of running them.
# @arg $@ string Package names.
# @exitcode 0 Every package is removed (or was already absent).
# @exitcode 1 A removal failed.
# @exitcode 2 No package name was given.
# @exitcode 3 No package manager (or required `sudo`) is available.
# @example
#   shell::package::uninstall jq
#
shell::package::uninstall() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Uninstall packages with the native package manager"
		shell::logger::usage "shell::package::uninstall [-n] <package> [package ...]"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::package::uninstall jq"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if [ "$#" -eq 0 ]; then
		shell::logger::error "No package name provided."
		return "$RETURN_INVALID"
	fi

	local manager
	manager="$(shell::package::manager)" || {
		shell::logger::error "No supported package manager found."
		return "$RETURN_NOT_FOUND"
	}

	local sudo_cmd=""
	sudo_cmd="$(shell::package::sudo_prefix "$manager")" || {
		shell::logger::error "Root privileges are required but 'sudo' is not installed."
		return "$RETURN_NOT_FOUND"
	}

	local package
	for package in "$@"; do
		if ! shell::package::is_installed "$package"; then
			shell::logger::warn "$package is not installed. Skipping uninstallation."
			continue
		fi

		local -a remove_cmd=()
		case "$manager" in
		apt) remove_cmd=(${sudo_cmd:+"$sudo_cmd"} apt-get remove -y "$package") ;;
		dnf) remove_cmd=(${sudo_cmd:+"$sudo_cmd"} dnf remove -y "$package") ;;
		yum) remove_cmd=(${sudo_cmd:+"$sudo_cmd"} yum remove -y "$package") ;;
		zypper) remove_cmd=(${sudo_cmd:+"$sudo_cmd"} zypper --non-interactive remove "$package") ;;
		pacman) remove_cmd=(${sudo_cmd:+"$sudo_cmd"} pacman -R --noconfirm "$package") ;;
		apk) remove_cmd=(${sudo_cmd:+"$sudo_cmd"} apk del "$package") ;;
		brew) remove_cmd=(brew uninstall "$package") ;;
		esac

		if [ "$dry_run" = "true" ]; then
			shell::exec::command -n "${remove_cmd[@]}"
			continue
		fi

		shell::exec::command "${remove_cmd[@]}" || {
			shell::logger::error "Failed to uninstall '$package' via $manager."
			return "$RETURN_FAILURE"
		}
	done

	return "$RETURN_SUCCESS"
}
