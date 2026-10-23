#!/usr/bin/env bash
# @file core/os.sh
# @brief Operating-system and environment detection.
# @description
#   Every platform branch in the library goes through these helpers so Linux,
#   macOS (and the "unsupported" fallback) are decided in one place.

# @description Print the normalised operating-system name.
#   The result of `uname` is cached in the global `SHELL_OS_TYPE`, so repeated
#   calls (this function is used in nearly every module) cost no fork.
# @option -h | --help Show help and return.
# @stdout One of: linux, macos, windows, unknown.
# @exitcode 0 Always.
# @example
#   case "$(shell::os::type)" in
#     macos) echo "BSD userland" ;;
#     linux) echo "GNU userland" ;;
#   esac
#
shell::os::type() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Print the normalised OS name (linux, macos, windows, unknown)"
		shell::logger::usage "shell::os::type"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::os::type"
		return "$RETURN_SUCCESS"
	fi

	if [ -n "${SHELL_OS_TYPE-}" ]; then
		printf '%s\n' "$SHELL_OS_TYPE"
		return "$RETURN_SUCCESS"
	fi

	local kernel
	kernel="$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')"

	case "$kernel" in
	linux*)
		# WSL reports "linux" but its kernel release contains "microsoft"; it
		# still behaves as Linux for every purpose this library cares about.
		SHELL_OS_TYPE="linux"
		;;
	darwin*) SHELL_OS_TYPE="macos" ;;
	cygwin* | mingw* | msys*) SHELL_OS_TYPE="windows" ;;
	*) SHELL_OS_TYPE="unknown" ;;
	esac

	printf '%s\n' "$SHELL_OS_TYPE"
	return "$RETURN_SUCCESS"
}

# @description Test whether the host is macOS.
# @noargs
# @exitcode 0 Running on macOS.
# @exitcode 1 Running anywhere else.
# @see shell::os::type
shell::os::is_macos() {
	[ "$(shell::os::type)" = "macos" ]
}

# @description Test whether the host is Linux (including WSL).
# @noargs
# @exitcode 0 Running on Linux.
# @exitcode 1 Running anywhere else.
# @see shell::os::type
shell::os::is_linux() {
	[ "$(shell::os::type)" = "linux" ]
}

# @description Print the normalised CPU architecture.
# @noargs
# @stdout One of: amd64, arm64, or the raw `uname -m` value for others.
# @exitcode 0 Always.
# @example
#   arch="$(shell::os::arch)"   # amd64 | arm64
#
shell::os::arch() {
	local machine
	machine="$(uname -m 2>/dev/null)"
	case "$machine" in
	x86_64 | amd64) printf 'amd64\n' ;;
	arm64 | aarch64) printf 'arm64\n' ;;
	*) printf '%s\n' "$machine" ;;
	esac
}

# @description Print the temporary directory for the current user.
#   Honours `$TMPDIR` (macOS sets it to a per-user directory under
#   /var/folders) and falls back to /tmp. A trailing slash is removed.
#
#   The previous implementation captured the *exit status* of
#   `shell::base::os` instead of its output, so it always returned `/tmp`, and
#   it leaked the OS name to stdout, corrupting `TEMP=$(...)` assignments.
# @noargs
# @stdout Absolute path of the temporary directory (no trailing slash).
# @exitcode 0 Always.
# @example
#   tmp="$(shell::os::temp_dir)"
#
shell::os::temp_dir() {
	local dir="${TMPDIR:-/tmp}"
	# Strip every trailing slash, but keep a lone "/" intact.
	while [ "${#dir}" -gt 1 ] && [ "${dir%/}" != "$dir" ]; do
		dir="${dir%/}"
	done
	printf '%s\n' "$dir"
}

# @description Print the user's login shell name (bash, zsh, ...).
#   Looks at the *running* shell first (ZSH_VERSION / BASH_VERSION), because
#   `$SHELL` only reflects the login shell, not the shell currently in use.
# @noargs
# @stdout Shell name, or "unknown".
# @exitcode 0 Always.
shell::os::shell_name() {
	if [ -n "${ZSH_VERSION-}" ]; then
		printf 'zsh\n'
	elif [ -n "${BASH_VERSION-}" ]; then
		printf 'bash\n'
	else
		printf '%s\n' "${SHELL##*/}"
	fi
}
