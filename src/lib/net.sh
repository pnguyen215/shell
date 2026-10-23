#!/usr/bin/env bash
# @file lib/net.sh
# @brief Networking helpers: downloads, URLs, remote scripts, ports, address validation.

# @description Download a file over HTTP(S) safely.
#   Improvements over `shell::download_dataset`:
#   * `curl -f` makes HTTP 4xx/5xx a failure; previously a "404 Not Found" HTML
#     page was saved under the requested filename and reported as success.
#   * The data is written to a temporary file in the same directory and moved
#     into place only after a complete download (no truncated files).
#   * Connect and total timeouts come from SHELL_NET_CONNECT_TIMEOUT / MAX_TIME.
#   * Declining the overwrite prompt now really aborts.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the curl command instead of running it.
# @option -f | --force Overwrite an existing file without asking.
# @arg $1 string Destination file (parent directories are created).
# @arg $2 string Source URL.
# @exitcode 0 Downloaded (or dry-run printed).
# @exitcode 1 The transfer failed.
# @exitcode 2 Wrong arguments.
# @exitcode 7 The file exists and the user declined to overwrite it.
# @example
#   shell::net::download .gitignore "$SHELL_URL_GITIGNORE_GO"
#   shell::net::download -f data.zip https://example.com/data.zip
#
shell::net::download() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Download a file over HTTP(S) (fails on HTTP errors)"
		shell::logger::usage "shell::net::download [-n] [-f] <file> <url>"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-f, --force" "Overwrite an existing file without asking"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::net::download data.zip https://example.com/data.zip"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" force="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-f | --force) force="true" ;;
		*) break ;;
		esac
		shift
	done

	if [ "$#" -ne 2 ]; then
		shell::logger::error "Usage: shell::net::download [-n] [-f] <file> <url>"
		return "$RETURN_INVALID"
	fi

	local file="$1"
	local url="$2"

	local -a curl_args=(-fsSL --connect-timeout "$SHELL_NET_CONNECT_TIMEOUT" --max-time "$SHELL_NET_MAX_TIME")

	if [ "$dry_run" = "true" ]; then
		shell::exec::command -n curl "${curl_args[@]}" -o "$file" "$url"
		return "$RETURN_SUCCESS"
	fi

	if [ -e "$file" ] && [ "$force" != "true" ]; then
		shell::ask::accept "Overwrite the existing file '$file'?" || {
			shell::logger::info "Download skipped; '$file' kept."
			return "$RETURN_EXISTS"
		}
	fi

	shell::dependency::curl::ensure || return "$RETURN_FAILURE"

	local parent="."
	case "$file" in */*) parent="${file%/*}" ;; esac
	[ -z "$parent" ] && parent="/"
	shell::fs::mkdir "$parent" || return "$RETURN_FAILURE"

	# Temp file beside the destination so the final `mv` is an atomic rename.
	local tmp
	tmp="$(mktemp "${file}.XXXXXX")" || {
		shell::logger::error "Cannot create a temporary file next to '$file'."
		return "$RETURN_FAILURE"
	}

	if shell::exec::command curl "${curl_args[@]}" -o "$tmp" "$url" && mv -f "$tmp" "$file"; then
		shell::logger::success "Downloaded: $file"
		return "$RETURN_SUCCESS"
	fi

	rm -f "$tmp"
	shell::logger::error "Download failed for $url"
	return "$RETURN_FAILURE"
}

# @description Open a URL in the default browser.
#   macOS: `open`. Linux: `xdg-open`. WSL: `wslview` or `explorer.exe`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string The URL.
# @exitcode 0 The opener was launched (or dry-run printed).
# @exitcode 2 No URL given.
# @exitcode 3 No opener is installed.
# @exitcode 4 Unsupported operating system.
# @example
#   shell::net::open_url https://example.com
#
shell::net::open_url() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Open a URL in the default web browser"
		shell::logger::usage "shell::net::open_url [-n] <url>"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::net::open_url https://example.com"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local url="${1-}"
	if [ -z "$url" ]; then
		shell::logger::error "Usage: shell::net::open_url [-n] <url>"
		return "$RETURN_INVALID"
	fi

	local opener=""
	case "$(shell::os::type)" in
	macos) opener="open" ;;
	linux)
		local candidate
		for candidate in xdg-open wslview explorer.exe; do
			if command -v "$candidate" >/dev/null 2>&1; then
				opener="$candidate"
				break
			fi
		done
		if [ -z "$opener" ]; then
			shell::logger::error "No URL opener found (install xdg-utils)."
			return "$RETURN_NOT_FOUND"
		fi
		;;
	*)
		shell::logger::error "Unsupported operating system: $(shell::os::type)"
		return "$RETURN_NOT_SUPPORTED"
		;;
	esac

	if [ "$dry_run" = "true" ]; then
		shell::exec::command -n "$opener" "$url"
		return "$RETURN_SUCCESS"
	fi
	shell::exec::command "$opener" "$url"
}

# @description Download a script and run it with an interpreter.
#   Replaces the `sh -c "$(curl ...)"` idiom. If curl fails, `$(...)` expands to
#   an empty string and `sh -c ""` *succeeds*, so a failed download used to be
#   reported as a successful install. Here the script is saved first, checked
#   for being non-empty, then executed.
#
#   Environment variables set by the caller (e.g. `RUNZSH=no`) are inherited by
#   the script. Any arguments after the interpreter are passed to the script
#   unchanged (argv style, so spaces and quotes survive).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the equivalent pipeline instead of running it.
# @arg $1 string Script URL.
# @arg $2 string Interpreter (default: sh).
# @arg $@ string Arguments passed to the script (everything after the interpreter).
# @exitcode 0 The script ran successfully (or dry-run printed).
# @exitcode 1 Download failed, the script was empty, or it exited non-zero.
# @exitcode 2 No URL given.
# @exitcode N Exit status of the script when it exits non-zero.
# @example
#   RUNZSH=no shell::net::run_remote_script "$SHELL_URL_OHMYZSH_INSTALL" sh
#   shell::net::run_remote_script "$url" bash --yes --tool claude
#
shell::net::run_remote_script() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Download a script, verify it, then run it with an interpreter"
		shell::logger::usage "shell::net::run_remote_script [-n] <url> [interpreter] [script-args...]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::net::run_remote_script https://example.com/install.sh bash"
		shell::logger::example "shell::net::run_remote_script https://example.com/install.sh bash --yes"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local url="${1-}"
	local interpreter="${2:-sh}"
	if [ -z "$url" ]; then
		shell::logger::error "Usage: shell::net::run_remote_script [-n] <url> [interpreter] [script-args...]"
		return "$RETURN_INVALID"
	fi

	# Drop <url> and <interpreter>; what is left are the script's own arguments.
	[ "$#" -gt 0 ] && shift
	[ "$#" -gt 0 ] && shift

	if [ "$dry_run" = "true" ]; then
		local shown="" arg
		for arg in "$@"; do
			shown="$shown $(printf '%q' "$arg")"
		done
		if [ -n "$shown" ]; then
			shell::logger::command_clip "curl -fsSL \"$url\" | $interpreter -s --$shown"
		else
			shell::logger::command_clip "curl -fsSL \"$url\" | $interpreter"
		fi
		return "$RETURN_SUCCESS"
	fi

	shell::dependency::curl::ensure || return "$RETURN_FAILURE"

	local script
	script="$(mktemp "$(shell::os::temp_dir)/${SHELL_NAME}-remote.XXXXXX")" || return "$RETURN_FAILURE"

	if ! curl -fsSL --connect-timeout "$SHELL_NET_CONNECT_TIMEOUT" --max-time "$SHELL_NET_MAX_TIME" -o "$script" "$url"; then
		rm -f "$script"
		shell::logger::error "Failed to download $url"
		return "$RETURN_FAILURE"
	fi
	if [ ! -s "$script" ]; then
		rm -f "$script"
		shell::logger::error "Downloaded script is empty: $url"
		return "$RETURN_FAILURE"
	fi

	local rc=0
	shell::logger::command "$interpreter <(downloaded $url)"
	"$interpreter" "$script" "$@" || rc=$?
	rm -f "$script"
	return "$rc"
}

# @internal
# @description Print the PIDs of processes LISTENING on a TCP port, one per line.
#   `-sTCP:LISTEN` is essential: without it lsof also matches *clients*
#   connected to that port (a browser tab, for example).
# @arg $1 integer TCP port.
# @stdout PIDs, one per line (nothing when the port is free).
# @exitcode 0 At least one listener exists.
# @exitcode 1 The port is free.
shell::net::port::pids() {
	local pids
	pids="$(lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null | sort -u)"
	[ -n "$pids" ] || return "$RETURN_FAILURE"
	printf '%s\n' "$pids"
}

# @description Show which process is listening on a TCP port.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the lsof command instead of running it.
# @arg $1 integer TCP port (1-65535).
# @stdout lsof's listing of the listener(s).
# @exitcode 0 The port is in use.
# @exitcode 1 The port is free.
# @exitcode 2 Invalid port.
# @example
#   shell::net::port::check 8080 && echo "8080 is busy"
#
shell::net::port::check() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Check whether a TCP port has a listener"
		shell::logger::usage "shell::net::port::check [-n] <port>"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::net::port::check 8080"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local port="${1-}"
	if ! shell::net::port::valid "$port"; then
		shell::logger::error "Usage: shell::net::port::check [-n] <port 1-65535>"
		return "$RETURN_INVALID"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "lsof -nP -iTCP:$port -sTCP:LISTEN"
		return "$RETURN_SUCCESS"
	fi

	shell::dependency::lsof::ensure || return "$RETURN_NOT_FOUND"
	# Both the listing and the exit status come from lsof: exit 1 = nothing found.
	lsof -nP -iTCP:"$port" -sTCP:LISTEN
}

# @internal
# @description Validate a TCP port number.
# @arg $1 string Candidate port.
# @exitcode 0 Integer in 1..65535.
# @exitcode 1 Anything else.
shell::net::port::valid() {
	case "${1-}" in
	'' | *[!0-9]*) return "$RETURN_FAILURE" ;;
	esac
	[ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

# @description Terminate the processes listening on one or more TCP ports.
#   Sends SIGTERM by default so programs can shut down cleanly; use `-9` to
#   force. Only LISTENING processes are targeted (the old implementation also
#   killed *clients* connected to the port).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the kill commands instead of running them.
# @option -9 | --force Send SIGKILL instead of SIGTERM.
# @arg $@ integer One or more ports.
# @exitcode 0 Done (ports with no listener only produce a warning).
# @exitcode 1 A kill failed.
# @exitcode 2 No port given or an invalid port.
# @example
#   shell::net::port::kill 3000 8080
#   shell::net::port::kill -9 -n 8080
#
shell::net::port::kill() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Terminate the processes listening on TCP ports"
		shell::logger::usage "shell::net::port::kill [-n] [-9] <port> [port ...]"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "-9, --force" "Send SIGKILL instead of SIGTERM"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::net::port::kill 3000 8080"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" signal="-TERM"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-9 | --force) signal="-KILL" ;;
		*) break ;;
		esac
		shift
	done

	if [ "$#" -eq 0 ]; then
		shell::logger::error "No ports specified. Usage: shell::net::port::kill [-n] [-9] <port> [port ...]"
		return "$RETURN_INVALID"
	fi

	shell::dependency::lsof::ensure || return "$RETURN_NOT_FOUND"

	local port pid pids failed=0
	for port in "$@"; do
		if ! shell::net::port::valid "$port"; then
			shell::logger::error "Invalid port: $port"
			return "$RETURN_INVALID"
		fi

		pids="$(shell::net::port::pids "$port")" || {
			shell::logger::warn "No process is listening on port $port"
			continue
		}

		# One PID per line; read them back without relying on word splitting.
		while IFS= read -r pid; do
			[ -n "$pid" ] || continue
			shell::logger::info "Port $port -> PID $pid"
			if [ "$dry_run" = "true" ]; then
				shell::exec::command -n kill "$signal" "$pid"
			else
				shell::exec::command kill "$signal" "$pid" || failed=1
			fi
		done <<<"$pids"
	done

	return "$failed"
}

# @description Validate an IPv4 or IPv6 address.
# @option -h | --help Show help and return.
# @arg $1 string The address.
# @stdout "INFO: '<ip>' is a valid IPv4/IPv6 address."
# @exitcode 0 The address is valid.
# @exitcode 1 The address is not valid.
# @exitcode 2 No address given.
# @example
#   shell::validate::ip::address 192.168.1.10
#   shell::validate::ip::address 2001:db8::1
#
shell::validate::ip::address() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Validate an IPv4 or IPv6 address"
		shell::logger::usage "shell::validate::ip::address <address>"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::validate::ip::address 192.168.1.10"
		return "$RETURN_SUCCESS"
	fi

	if [ "$#" -ne 1 ]; then
		shell::logger::error "An IP address is required"
		return "$RETURN_INVALID"
	fi

	local ip="$1"

	# --- IPv4: four decimal octets 0-255 -------------------------------------
	if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
		local octet valid="true"
		# Split on dots using IFS in a subshell-free way.
		local rest="$ip"
		while [ -n "$rest" ]; do
			octet="${rest%%.*}"
			if [ "$octet" = "$rest" ]; then rest=""; else rest="${rest#*.}"; fi
			# 10# forces base-10 so "08" is not parsed as invalid octal.
			if [ "$((10#$octet))" -gt 255 ]; then
				valid="false"
			fi
		done
		if [ "$valid" = "true" ]; then
			shell::logger::info "'$ip' is a valid IPv4 address."
			return "$RETURN_SUCCESS"
		fi
		shell::logger::error "'$ip' has an IPv4 octet out of range (0-255)."
		return "$RETURN_FAILURE"
	fi

	# --- IPv6: up to 8 hex groups, at most one "::" ---------------------------
	case "$ip" in
	*:*)
		local ok="true"
		case "$ip" in *[!0-9a-fA-F:]* | *:::*) ok="false" ;; esac
		# A single leading/trailing colon is only legal as part of "::".
		case "$ip" in :[!:]* | *[!:]:) ok="false" ;; esac

		local compressed="false"
		case "$ip" in *::*) compressed="true" ;; esac
		if [ "$compressed" = "true" ]; then
			# A second "::" after the first is invalid.
			local after="${ip#*::}"
			case "$after" in *::*) ok="false" ;; esac
		fi

		local groups=0 group
		while IFS= read -r group; do
			[ -n "$group" ] || continue
			[ "${#group}" -le 4 ] || ok="false"
			groups=$((groups + 1))
		done <<<"$(printf '%s' "$ip" | tr ':' '\n')"

		if [ "$compressed" = "true" ]; then
			[ "$groups" -le 7 ] || ok="false"
		else
			[ "$groups" -eq 8 ] || ok="false"
		fi

		if [ "$ok" = "true" ]; then
			shell::logger::info "'$ip' is a valid IPv6 address."
			return "$RETURN_SUCCESS"
		fi
		;;
	esac

	shell::logger::error "'$ip' is not a valid IPv4 or IPv6 address."
	return "$RETURN_FAILURE"
}

# @description Validate a hostname and report whether it resolves.
#   Syntax is checked against RFC 1123 (labels of 1-63 letters, digits and
#   hyphens, total length <= 253). Resolution uses whichever of `getent`,
#   `host` or `nslookup` is available; if none is, only the syntax is checked.
# @option -h | --help Show help and return.
# @arg $1 string The hostname.
# @stdout Validity and resolution status.
# @exitcode 0 The hostname is syntactically valid (resolution only warns).
# @exitcode 1 The hostname is not valid.
# @exitcode 2 No hostname given.
# @example
#   shell::validate::hostname example.com
#
shell::validate::hostname() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Validate a hostname and check whether it resolves"
		shell::logger::usage "shell::validate::hostname <hostname>"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::validate::hostname example.com"
		return "$RETURN_SUCCESS"
	fi

	if [ "$#" -ne 1 ]; then
		shell::logger::error "A hostname is required"
		return "$RETURN_INVALID"
	fi

	local name="$1"
	if [ "${#name}" -gt 253 ]; then
		shell::logger::error "Hostname exceeds 253 characters."
		return "$RETURN_FAILURE"
	fi

	local label='[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
	if ! [[ "$name" =~ ^(${label}\.)*${label}$ ]]; then
		shell::logger::error "'$name' is not a valid hostname format."
		return "$RETURN_FAILURE"
	fi

	local resolved="skip"
	if command -v getent >/dev/null 2>&1; then
		getent hosts "$name" >/dev/null 2>&1 && resolved="yes" || resolved="no"
	elif command -v host >/dev/null 2>&1; then
		host "$name" >/dev/null 2>&1 && resolved="yes" || resolved="no"
	elif command -v nslookup >/dev/null 2>&1; then
		nslookup "$name" >/dev/null 2>&1 && resolved="yes" || resolved="no"
	fi

	case "$resolved" in
	yes) shell::logger::info "'$name' is a valid hostname and resolves via DNS." ;;
	no) shell::logger::warn "'$name' is valid but does not resolve via DNS." ;;
	*) shell::logger::info "'$name' is a valid hostname (DNS lookup tools unavailable)." ;;
	esac
	return "$RETURN_SUCCESS"
}
