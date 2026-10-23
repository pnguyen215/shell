#!/usr/bin/env bash
# @file dependency/ensure.sh
# @brief Generic "make sure this command exists" engine and dependency report.
# @description
#   Every per-tool installer (fzf.sh, jq.sh, ...) is a one-line wrapper around
#   shell::dependency::ensure. Keeping the logic here means the install policy
#   (auto-install or only report) is controlled by one switch:
#   SHELL_AUTO_INSTALL_DEPS (constant/defaults.sh).

# @internal
# @description Map a command name to the package that provides it.
#   Most tools share their command's name; the exceptions are listed here so
#   the knowledge lives in one place.
# @arg $1 string Command name.
# @arg $2 string Package manager (apt, dnf, yum, pacman, zypper, apk, brew).
# @stdout Package name.
# @exitcode 0 Always.
shell::dependency::package_name() {
	local command="$1"
	local manager="$2"

	case "$command" in
	ssh | ssh-keygen | ssh-copy-id)
		case "$manager" in
		apt) printf 'openssh-client\n' ;;
		dnf | yum | zypper) printf 'openssh-clients\n' ;;
		*) printf 'openssh\n' ;;
		esac
		;;
	column)
		case "$manager" in
		apt) printf 'bsdextrautils\n' ;;
		dnf | yum | zypper) printf 'util-linux\n' ;;
		*) printf 'util-linux\n' ;;
		esac
		;;
	nslookup | dig)
		case "$manager" in
		apt) printf 'dnsutils\n' ;;
		dnf | yum) printf 'bind-utils\n' ;;
		apk) printf 'bind-tools\n' ;;
		*) printf 'bind\n' ;;
		esac
		;;
	realpath | gdate) printf 'coreutils\n' ;;
	7z) [ "$manager" = "apt" ] && printf 'p7zip-full\n' || printf 'p7zip\n' ;;
	*) printf '%s\n' "$command" ;;
	esac
}

# @description Make sure a command is available, installing it if allowed.
#   Fast path: when the command already exists this is a single `command -v`
#   (no package-database query), which matters because pickers call it on every
#   invocation.
# @option -h | --help Show help and return.
# @arg $1 string Command that must exist.
# @arg $2 string Package providing it (default: derived from the command name).
# @exitcode 0 The command is available.
# @exitcode 2 No command name was given.
# @exitcode 3 The command is missing and could not (or may not) be installed.
# @example
#   shell::dependency::ensure jq || return
#   shell::dependency::ensure dig dnsutils
#
shell::dependency::ensure() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Ensure a command is available, installing it when allowed"
		shell::logger::usage "shell::dependency::ensure <command> [package]"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::dependency::ensure jq"
		return "$RETURN_SUCCESS"
	fi

	local command="${1-}"
	if [ -z "$command" ]; then
		shell::logger::error "No command name provided."
		return "$RETURN_INVALID"
	fi

	# Fast path.
	if command -v "$command" >/dev/null 2>&1; then
		return "$RETURN_SUCCESS"
	fi

	local manager
	manager="$(shell::package::manager)"
	local package="${2:-$(shell::dependency::package_name "$command" "$manager")}"

	# Policy switch: only report when auto-install is disabled.
	if [ "${SHELL_AUTO_INSTALL_DEPS:-1}" != "1" ]; then
		shell::logger::error "'$command' is required but not installed (package: $package). Install it manually, or set SHELL_AUTO_INSTALL_DEPS=1."
		return "$RETURN_NOT_FOUND"
	fi

	shell::logger::warn "'$command' is not installed. Installing package '$package'..."
	shell::package::install "$package" || return "$RETURN_NOT_FOUND"

	# Make the shell forget cached "command not found" lookups (bash: hash, zsh: rehash).
	hash -r 2>/dev/null || rehash 2>/dev/null

	if ! command -v "$command" >/dev/null 2>&1; then
		shell::logger::error "Package '$package' was installed but '$command' is still not on PATH."
		return "$RETURN_NOT_FOUND"
	fi
	return "$RETURN_SUCCESS"
}

# @description Report which declared dependencies are installed.
#   Reads SHELL_DEPENDENCIES_REQUIRED and SHELL_DEPENDENCIES_OPTIONAL.
# @option -h | --help Show help and return.
# @stdout One line per dependency with its status.
# @exitcode 0 Every REQUIRED dependency is installed.
# @exitcode 3 At least one REQUIRED dependency is missing.
# @example
#   shell::dependency::doctor
#
shell::dependency::doctor() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Report which required/optional dependencies are installed"
		shell::logger::usage "shell::dependency::doctor"
		shell::logger::option "-h, --help" "Display this help message"
		return "$RETURN_SUCCESS"
	fi

	local missing_required=0
	local tool kind

	shell::logger::section "Dependency report ($(shell::os::type), $(shell::package::manager))"

	for kind in required optional; do
		local -a tools=()
		if [ "$kind" = "required" ]; then
			tools=("${SHELL_DEPENDENCIES_REQUIRED[@]}")
		else
			tools=("${SHELL_DEPENDENCIES_OPTIONAL[@]}")
		fi

		for tool in "${tools[@]}"; do
			if command -v "$tool" >/dev/null 2>&1; then
				shell::console::print "  ${SHELL_GLYPH_OK} ${tool} (${kind})" "$SHELL_COLOR_SUCCESS"
			elif [ "$kind" = "required" ]; then
				shell::console::print "  ${SHELL_GLYPH_FAIL} ${tool} (${kind}) - MISSING" "$SHELL_COLOR_ERROR"
				missing_required=$((missing_required + 1))
			else
				shell::console::print "  [ ] ${tool} (${kind}) - not installed" "$SHELL_COLOR_WARN"
			fi
		done
	done

	[ "$missing_required" -eq 0 ] || return "$RETURN_NOT_FOUND"
	return "$RETURN_SUCCESS"
}
