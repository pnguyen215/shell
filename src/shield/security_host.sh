#!/usr/bin/env bash
# @file shield/security_host.sh
# @brief Host inventory and account inspection (`shell::security::host::*`).
# @description
#   Read-only. Needs no privileges; where a fact needs root (for example a full session list) the
#   result says it was not available instead of guessing.

# @description Collect `key SEP value` facts about this machine.
#   OS and version, kernel, architecture, hostname, CPU, logical cores and physical memory. Reuses
#   `shell::os::type` and `shell::os::arch`. A fact that cannot be read is reported as `unavailable`.
# @internal
# @stdout One record per fact.
# @exitcode 0 Always.
# @example
#   _shell::security::host::facts
#
_shell::security::host::facts() {
	local s="$SHELL_SECURITY_SEP" os name version cpu cores mem
	os="$(shell::os::type)"
	if [ "$os" = "macos" ]; then
		name="$(sw_vers -productName 2>/dev/null)"
		version="$(sw_vers -productVersion 2>/dev/null)"
		cpu="$(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
		mem="$(sysctl -n hw.memsize 2>/dev/null)"
	else
		name="$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release 2>/dev/null | head -1 | tr -d '"')"
		version=""
		cpu="$(sed -n 's/^model name[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo 2>/dev/null | head -1)"
		mem="$(awk '/^MemTotal:/ {print $2 * 1024}' /proc/meminfo 2>/dev/null)"
	fi
	cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null)"

	printf 'os_family%s%s\n' "$s" "$os"
	printf 'os_name%s%s\n' "$s" "${name:-unavailable}"
	printf 'os_version%s%s\n' "$s" "${version:-unavailable}"
	printf 'kernel%s%s\n' "$s" "$(uname -sr 2>/dev/null || printf unavailable)"
	printf 'architecture%s%s\n' "$s" "$(shell::os::arch 2>/dev/null || uname -m)"
	printf 'hostname%s%s\n' "$s" "$(hostname 2>/dev/null || printf unavailable)"
	printf 'cpu%s%s\n' "$s" "${cpu:-unavailable}"
	printf 'logical_cores%s%s\n' "$s" "${cores:-unavailable}"
	printf 'memory_bytes%s%s\n' "$s" "${mem:-unavailable}"
	printf 'collected_at%s%s\n' "$s" "$(_shell::security::now)"
}

# @description Print the host inventory: OS, kernel, architecture, hostname and hardware.
# @option -h | --help Show help and return.
# @option -f | --format Output format: text, json, markdown or csv (default: text).
# @stdout The facts.
# @exitcode 0 Success.
# @exitcode 2 Invalid format or argument.
# @example
#   shell::security::host::info --format json
#
shell::security::host::info() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Print OS, kernel, architecture, hostname and hardware facts"
		shell::logger::usage "shell::security::host::info [-f text|json|markdown|csv]"
		shell::logger::option "-f, --format" "Output format (default: text)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::security::host::info --format json"
		return "$RETURN_SUCCESS"
	fi
	_shell::security::args::parse "$@" || return "$?"
	_shell::security::host::facts | _shell::security::render::kv "$_SHELL_SECURITY_FORMAT" "fact" "value" "$SHELL_SECURITY_SEP"
}

# @description List the members of the administrative groups, one `group SEP member` record each.
#   macOS reads the `admin` group with `dscl`; Linux reads SHELL_SECURITY_GROUP_FILE (accounts that
#   come only from a directory service such as LDAP are not listed).
# @internal
# @stdout One record per group that has members.
# @exitcode 0 Success.
# @exitcode 3 No source could be read.
# @example
#   _shell::security::host::admins
#
_shell::security::host::admins() {
	local s="$SHELL_SECURITY_SEP" group members
	if [ "$(shell::os::type)" = "macos" ]; then
		_shell::security::have dscl || return "$RETURN_NOT_FOUND"
		members="$(dscl . -read /Groups/admin GroupMembership 2>/dev/null | sed 's/^GroupMembership:[[:space:]]*//')"
		[ -n "$members" ] && printf 'admin%s%s\n' "$s" "$members"
		return "$RETURN_SUCCESS"
	fi
	[ -r "$SHELL_SECURITY_GROUP_FILE" ] || return "$RETURN_NOT_FOUND"
	# (not `for g in $VAR`: zsh does not word-split unquoted expansions)
	printf '%s\n' "$SHELL_SECURITY_ADMIN_GROUPS" | tr ' ' '\n' | while IFS= read -r group; do
		[ -n "$group" ] || continue
		members="$(awk -F: -v g="$group" '$1 == g {print $4}' "$SHELL_SECURITY_GROUP_FILE" | tr ',' ' ')"
		[ -z "$members" ] || printf '%s%s%s\n' "$group" "$s" "$members"
	done
	return "$RETURN_SUCCESS"
}

# @description Inspect accounts and sessions and report findings.
#   - HIGH: an account other than `root` has UID 0 (full root privileges under another name).
#   - INFO: members of the administrative groups, and the number of interactive sessions.
#   Group membership is an inventory, not a defect: administrators are expected to exist.
# @option -h | --help Show help and return.
# @option -f | --format Output format: text, json, markdown or csv (default: text).
# @option --min-severity Lowest severity to print (default: INFO).
# @stdout The findings.
# @exitcode 0 Success.
# @exitcode 2 Invalid argument.
# @example
#   shell::security::host::users --format markdown
#
shell::security::host::users() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Inspect administrator accounts, UID 0 accounts and logged-in users"
		shell::logger::usage "shell::security::host::users [-f text|json|markdown|csv] [--min-severity LEVEL]"
		shell::logger::option "-f, --format" "Output format (default: text)"
		shell::logger::option "--min-severity" "Lowest severity to print (default: INFO)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::security::host::users --min-severity MEDIUM"
		return "$RETURN_SUCCESS"
	fi
	_shell::security::args::parse "$@" || return "$?"
	local format="$_SHELL_SECURITY_FORMAT" min="$_SHELL_SECURITY_MIN_SEVERITY"
	_shell::security::session::begin || return "$?"
	local owns="$_SHELL_SECURITY_OWNS"

	_shell::security::host::users::scan

	_shell::security::session::finish "$owns" "$format" "$min"
}

# @description Run the account and session checks and record their findings.
# @internal
# @exitcode 0 Always.
# @example
#   _shell::security::host::users::scan
#
_shell::security::host::users::scan() {
	local s="$SHELL_SECURITY_SEP" user

	# UID 0 accounts other than root.
	if [ -r "$SHELL_SECURITY_PASSWD_FILE" ]; then
		awk -F: '$3 == 0 && $1 != "root" {print $1}' "$SHELL_SECURITY_PASSWD_FILE" | while IFS= read -r user; do
			_shell::security::finding::add account HIGH "user $user" \
				"Account '$user' has UID 0 (root privileges) but is not named root" \
				"$SHELL_SECURITY_PASSWD_FILE" \
				"Any account with UID 0 is equivalent to root. Legitimate setups are rare; a hidden second root account is a known persistence technique." high \
				"Check when the entry was added (file mtime, package history, auth logs) and who created it." \
				"If it is not documented, lock the account with your account-management tooling after preserving evidence."
		done
	else
		_shell::security::finding::unavailable account "UID 0 account check" "$SHELL_SECURITY_PASSWD_FILE is not readable"
	fi

	# Administrative group members (inventory only).
	local admins group members
	if admins="$(_shell::security::host::admins)"; then
		if [ -n "$admins" ]; then
			printf '%s\n' "$admins" | while IFS="$s" read -r group members; do
				_shell::security::finding::add account INFO "group $group" \
					"Members of administrative group '$group': $members" \
					"$(if [ "$(shell::os::type)" = macos ]; then printf 'dscl . -read /Groups/admin'; else printf '%s' "$SHELL_SECURITY_GROUP_FILE"; fi)" \
					"Inventory of accounts that can gain root. Administrators are expected; review that the list matches who should have access." high \
					"Compare the list with your access policy; check last login of each member." \
					"Remove members who no longer need administrative access."
			done
		fi
	else
		_shell::security::finding::unavailable account "administrator group listing" "no readable group source on this system"
	fi

	# Interactive sessions.
	if _shell::security::have who; then
		local sessions
		sessions="$(who 2>/dev/null | awk '{print $1}' | sort | uniq -c | awk '{printf "%s%s(%s)", (NR > 1 ? ", " : ""), $2, $1}')"
		if [ -n "$sessions" ]; then
			_shell::security::finding::add session INFO "logged-in users" \
				"Active sessions: $sessions" "who" \
				"Snapshot of who is logged in now (user and session count)." high \
				"Confirm each user and origin; use 'last' for recent history." \
				"None needed unless a session is unexpected."
		fi
	else
		_shell::security::finding::unavailable session "logged-in session listing" "'who' is not installed"
	fi
	return "$RETURN_SUCCESS"
}
