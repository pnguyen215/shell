#!/usr/bin/env bash
# @file security/security_platform.sh
# @brief Platform and utility detection shared by the security modules.
# @description
#   Read-only. Nothing here changes the system or needs root. The module decides at run time which
#   of the BSD / GNU tools exist and reports a missing one as "unavailable", which is different
#   from "found nothing".

# @description Test whether a command is available.
# @internal
# @arg $1 string Command name.
# @exitcode 0 The command exists.
# @exitcode 3 It does not.
# @example
#   _shell::security::have ss
#
_shell::security::have() {
	command -v "${1-}" >/dev/null 2>&1 || return "$RETURN_NOT_FOUND"
}

# @description Current UTC time in ISO 8601, e.g. 2026-11-12T10:00:00Z.
# @internal
# @stdout The timestamp.
# @exitcode 0 Always.
# @example
#   _shell::security::now
#
_shell::security::now() {
	date -u +%Y-%m-%dT%H:%M:%SZ
}

# @description SHA-256 of standard input as 64 lowercase hex characters.
#   Uses sha256sum (GNU), then shasum (macOS, Perl), then openssl.
# @internal
# @stdout The digest.
# @exitcode 0 Success.
# @exitcode 3 No SHA-256 tool is installed.
# @example
#   printf 'abc' | _shell::security::sha256
#
_shell::security::sha256() {
	if _shell::security::have sha256sum; then
		sha256sum | awk '{print $1}'
	elif _shell::security::have shasum; then
		shasum -a 256 | awk '{print $1}'
	elif _shell::security::have openssl; then
		openssl dgst -sha256 | awk '{print $NF}'
	else
		return "$RETURN_NOT_FOUND"
	fi
}

# @description Name of the first available tool of a list, or nothing.
# @internal
# @arg $@ string Candidate command names, in order of preference.
# @stdout The first one that exists.
# @exitcode 0 One was found.
# @exitcode 3 None exists.
# @example
#   _shell::security::first_of ss lsof
#
_shell::security::first_of() {
	local candidate
	for candidate in "$@"; do
		if _shell::security::have "$candidate"; then
			printf '%s\n' "$candidate"
			return "$RETURN_SUCCESS"
		fi
	done
	return "$RETURN_NOT_FOUND"
}

# @description Print the capability matrix: which investigations can run on this machine.
#   Each row is a capability, whether it is available, and the tool that provides it. An
#   `unavailable` capability means the matching checks are skipped and reported as unsupported,
#   never as "nothing found".
# @option -h | --help Show help and return.
# @option -f | --format Output format: text, json, markdown or csv (default: text).
# @stdout The matrix.
# @exitcode 0 Success.
# @exitcode 2 Invalid format or argument.
# @example
#   shell::security::capabilities --format json
#
shell::security::capabilities() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show which security investigations are available on this machine"
		shell::logger::usage "shell::security::capabilities [-f text|json|markdown|csv]"
		shell::logger::option "-f, --format" "Output format (default: text)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::security::capabilities --format json"
		return "$RETURN_SUCCESS"
	fi

	_shell::security::args::parse "$@" || return "$?"
	local format="$_SHELL_SECURITY_FORMAT"

	local sep="$SHELL_SECURITY_SEP" os tool
	os="$(shell::os::type)"
	{
		tool="$(_shell::security::first_of ps)" || tool=""
		_shell::security::capabilities::row "process-list" "$tool"
		if [ "$os" = "linux" ]; then
			tool="$(_shell::security::first_of ss)" || tool=""
		else
			tool="$(_shell::security::first_of lsof)" || tool=""
		fi
		_shell::security::capabilities::row "network-sockets" "$tool"
		tool="$(_shell::security::first_of sha256sum shasum openssl)" || tool=""
		_shell::security::capabilities::row "sha256" "$tool"
		tool="$(_shell::security::first_of who w)" || tool=""
		_shell::security::capabilities::row "sessions" "$tool"
		if [ "$os" = "linux" ]; then
			tool="$(_shell::security::first_of journalctl)" || tool=""
			_shell::security::capabilities::row "system-journal" "$tool"
			tool="$(_shell::security::first_of systemctl)" || tool=""
			_shell::security::capabilities::row "service-manager" "$tool"
		else
			tool="$(_shell::security::first_of log)" || tool=""
			_shell::security::capabilities::row "system-log" "$tool"
			tool="$(_shell::security::first_of launchctl)" || tool=""
			_shell::security::capabilities::row "service-manager" "$tool"
		fi
		tool="$(_shell::security::first_of jq)" || tool=""
		_shell::security::capabilities::row "json-validation (optional)" "$tool"
	} | _shell::security::render::kv "$format" "capability" "status" "$sep"
}

# @description Emit one capability record: `name SEP status (tool)`.
# @internal
# @arg $1 string Capability name.
# @arg $2 string Tool that provides it, or empty when none does.
# @stdout One record.
# @exitcode 0 Always.
# @example
#   _shell::security::capabilities::row sha256 shasum
#
_shell::security::capabilities::row() {
	if [ -n "${2-}" ]; then
		printf '%s%savailable (%s)\n' "$1" "$SHELL_SECURITY_SEP" "$2"
	else
		printf '%s%sunavailable\n' "$1" "$SHELL_SECURITY_SEP"
	fi
}
