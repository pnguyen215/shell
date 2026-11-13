#!/usr/bin/env bash
# @file security/security_network.sh
# @brief Local network state inspection (`shell::security::hunt::network`, `::connections`).
# @description
#   Observes this host's own sockets, resolver and proxy configuration. It never scans or contacts
#   another machine. Linux uses `ss`; macOS uses `lsof` (both fall back to the other when it is
#   the only one installed). Without privileges the owning process of other users' sockets is not
#   visible: those rows keep an empty pid and the report says so.

# @description Print awk helper functions that split `addr:port` / `[v6]:port` endpoints.
#   Sets the awk globals EA (address, brackets and %zone removed) and EP (port).
# @internal
# @stdout awk source text.
# @exitcode 0 Always.
# @example
#   awk "$(_shell::security::net::awk_lib) { ep(\$1); print EA, EP }"
#
_shell::security::net::awk_lib() {
	printf '%s\n' 'function ep(x,   i) { i = match(x, /:[^:]*$/); EP = substr(x, i + 1); EA = substr(x, 1, i - 1); gsub(/\[/, "", EA); gsub(/\]/, "", EA); sub(/%.*/, "", EA) }'
}

# @description Print one record per listening socket (TCP listeners and bound UDP sockets).
#   Fields (joined by SHELL_SECURITY_SEP): protocol, address, port, pid, process.
# @internal
# @stdout The records.
# @exitcode 0 Success (possibly no output: nothing is listening).
# @exitcode 3 Neither `ss` nor `lsof` is available.
# @example
#   _shell::security::net::listeners
#
_shell::security::net::listeners() {
	local s="$SHELL_SECURITY_SEP" lib tool
	lib="$(_shell::security::net::awk_lib)"
	if [ "$(shell::os::type)" = "linux" ] && _shell::security::have ss; then
		tool="ss"
	elif _shell::security::have lsof; then
		tool="lsof"
	else
		return "$RETURN_NOT_FOUND"
	fi
	if [ "$tool" = "ss" ]; then
		ss -H -tulnp 2>/dev/null | awk -v s="$s" "$lib"'
			$1 == "Netid" { next }
			{
				pid = ""; proc = ""
				if (match($0, /\(\("[^"]*"/)) proc = substr($0, RSTART + 3, RLENGTH - 4)
				if (match($0, /pid=[0-9]+/)) pid = substr($0, RSTART + 4, RLENGTH - 4)
				ep($5); print $1 s EA s EP s pid s proc
			}'
	else
		{
			lsof -nP -iTCP -sTCP:LISTEN -F pcPn 2>/dev/null
			lsof -nP -iUDP -F pcPn 2>/dev/null
		} | awk -v s="$s" "$lib"'
			/^p/ { pid = substr($0, 2); next }
			/^c/ { proc = substr($0, 2); next }
			/^P/ { proto = tolower(substr($0, 2)); next }
			/^n/ {
				name = substr($0, 2)
				if (name ~ /->/) next
				ep(name)
				if (EP !~ /^[0-9]+$/) next
				print proto s EA s EP s pid s proc
			}'
	fi
}

# @description Print one record per established TCP connection.
#   Fields (joined by SHELL_SECURITY_SEP): protocol, local address, local port, remote address,
#   remote port, pid, process.
# @internal
# @stdout The records.
# @exitcode 0 Success (possibly no output).
# @exitcode 3 Neither `ss` nor `lsof` is available.
# @example
#   _shell::security::net::connections
#
_shell::security::net::connections() {
	local s="$SHELL_SECURITY_SEP" lib
	lib="$(_shell::security::net::awk_lib)"
	if [ "$(shell::os::type)" = "linux" ] && _shell::security::have ss; then
		ss -H -tnp state established 2>/dev/null | awk -v s="$s" "$lib"'
			{
				pid = ""; proc = ""
				if (match($0, /\(\("[^"]*"/)) proc = substr($0, RSTART + 3, RLENGTH - 4)
				if (match($0, /pid=[0-9]+/)) pid = substr($0, RSTART + 4, RLENGTH - 4)
				ep($3); la = EA; lp = EP; ep($4)
				print "tcp" s la s lp s EA s EP s pid s proc
			}'
	elif _shell::security::have lsof; then
		lsof -nP -iTCP -sTCP:ESTABLISHED -F pcPn 2>/dev/null | awk -v s="$s" "$lib"'
			/^p/ { pid = substr($0, 2); next }
			/^c/ { proc = substr($0, 2); next }
			/^n/ {
				name = substr($0, 2)
				i = index(name, "->"); if (i == 0) next
				ep(substr(name, 1, i - 1)); la = EA; lp = EP
				ep(substr(name, i + 2))
				print "tcp" s la s lp s EA s EP s pid s proc
			}'
	else
		return "$RETURN_NOT_FOUND"
	fi
}

# @description Test whether an address is loopback (127.0.0.0/8, ::1, localhost).
# @internal
# @arg $1 string Address.
# @exitcode 0 Loopback.
# @exitcode 1 Anything else.
# @example
#   _shell::security::net::is_loopback 127.0.0.1
#
_shell::security::net::is_loopback() {
	case "${1-}" in 127.* | ::1 | localhost | ::ffff:127.*) return 0 ;; esac
	return 1
}

# @description Strip scheme and credentials from a proxy URL so only host and port remain.
# @internal
# @arg $1 string Proxy URL.
# @stdout host[:port][/path]
# @exitcode 0 Always.
# @example
#   _shell::security::net::proxy_host "http://user:pw@proxy:3128"   # proxy:3128
#
_shell::security::net::proxy_host() {
	printf '%s' "${1-}" | sed -E 's#^[A-Za-z][A-Za-z0-9+.-]*://##; s#^[^@/]*@##'
}

# @description Record the findings about listening sockets, resolvers and proxies.
# @internal
# @exitcode 0 Success.
# @exitcode 3 Sockets could not be listed.
# @example
#   _shell::security::hunt::network::scan
#
_shell::security::hunt::network::scan() {
	local s="$SHELL_SECURITY_SEP" rc=0 listeners
	if listeners="$(_shell::security::net::listeners)"; then
		if [ -z "$listeners" ]; then
			_shell::security::finding::add network INFO "listening sockets" "No listening sockets were found" "$(_shell::security::net::source_label listeners)" \
				"The socket listing succeeded and returned no listeners." high "None needed." "None needed."
		else
			# Exposed (non-loopback) listeners; risky ports first.
			local exposed
			exposed="$(printf '%s\n' "$listeners" | PORTS="$SHELL_SECURITY_EXPOSED_PORTS" awk -F"$s" -v s="$s" '
				BEGIN {
					n = split(ENVIRON["PORTS"], p, " ")
					for (i = 1; i <= n; i++) { split(p[i], f, ":"); svc[f[1]] = f[2]; sv[f[1]] = f[3] }
				}
				$2 ~ /^127\./ || $2 == "::1" || $2 == "localhost" { next }
				{
					k = $1 s $3
					addrs[k] = (k in addrs) ? addrs[k] ", " $2 : $2
					if (!(k in proc) || proc[k] == "") proc[k] = $5
					if (!(k in pid) || pid[k] == "") pid[k] = $4
					if (!(k in order)) { order[k] = ++cnt; port[k] = $3; proto[k] = $1 }
				}
				END {
					for (k in order) print proto[k] s port[k] s addrs[k] s pid[k] s proc[k] s svc[port[k]] s sv[port[k]]
				}' | sort)"
			local proto port addrs pid proc svc sev total_exposed=0 summary="" unknown_owner=0
			if [ -n "$exposed" ]; then
				while IFS="$s" read -r proto port addrs pid proc svc sev; do
					[ -n "$proto" ] || continue
					total_exposed=$((total_exposed + 1))
					summary="${summary:+$summary, }$proto/$port${proc:+ ($proc)}"
					[ -n "$pid" ] || unknown_owner=$((unknown_owner + 1))
					if [ -n "$svc" ]; then
						_shell::security::finding::add network "$sev" "$proto/$port on $addrs" \
							"Port $port/$proto (commonly $svc) accepts connections on a non-loopback address${proc:+; owner: $proc}" "$(_shell::security::net::source_label listeners)" \
							"The port number suggests $svc, which is usually kept on localhost or behind a firewall. The service is inferred from the port only; it may be intentionally exposed or protected by network rules." medium \
							"Confirm which process owns the port and whether remote access is intended; test reachability from outside only on hosts you are authorised to test; review the firewall." \
							"Bind the service to 127.0.0.1 or a private interface, or restrict it with firewall rules, through your change process."
					fi
				done <<EOF
$exposed
EOF
			fi
			_shell::security::finding::add network INFO "listening sockets" \
				"$total_exposed listening port(s) reachable on non-loopback addresses${summary:+: $summary}" "$(_shell::security::net::source_label listeners)" \
				"Inventory of sockets not bound to loopback. Reachability from other hosts also depends on the firewall." high \
				"Check that each exposed service is expected." "Close or restrict services that are not needed."
			if [ "$unknown_owner" -gt 0 ]; then
				_shell::security::finding::add network INFO "socket owners" \
					"The owning process of $unknown_owner exposed socket(s) could not be read" "$(_shell::security::net::source_label listeners)" \
					"Process names for other users' sockets need elevated privileges. The owner is unknown, not absent." high \
					"Rerun with the privileges you are authorised to use (for example as root) to see owners." "None needed."
			fi
		fi
	else
		_shell::security::finding::unavailable network "listening sockets" "neither 'ss' (Linux) nor 'lsof' is installed"
		rc="$RETURN_NOT_FOUND"
	fi

	# DNS resolvers.
	local resolvers=""
	if [ "$(shell::os::type)" = "macos" ] && _shell::security::have scutil; then
		resolvers="$(scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/ {print $3}' | sort -u | tr '\n' ' ')"
	elif [ -r "$SHELL_SECURITY_RESOLV_CONF" ]; then
		resolvers="$(awk '$1 == "nameserver" {print $2}' "$SHELL_SECURITY_RESOLV_CONF" | tr '\n' ' ')"
	fi
	resolvers="${resolvers% }"
	if [ -n "$resolvers" ]; then
		_shell::security::finding::add network INFO "dns resolvers" "DNS resolvers in use: $resolvers" "scutil --dns | $SHELL_SECURITY_RESOLV_CONF" \
			"Inventory only. A resolver you do not recognise can redirect lookups; 127.0.0.53 is the normal systemd-resolved stub." high \
			"Compare with the resolvers your network or DHCP should provide." "Correct unexpected resolvers in the network configuration."
	else
		_shell::security::finding::unavailable network "DNS resolver configuration" "no resolver source could be read"
	fi

	# Proxy settings in the environment (host and port only; credentials are never printed).
	local var val proxies=""
	for var in http_proxy HTTP_PROXY https_proxy HTTPS_PROXY all_proxy ALL_PROXY; do
		eval "val=\"\${$var-}\""
		[ -z "$val" ] || proxies="${proxies:+$proxies, }$var=$(_shell::security::net::proxy_host "$val")"
	done
	if [ -n "$proxies" ]; then
		_shell::security::finding::add network INFO "proxy environment" "Proxy configured in the environment: $proxies" "environment variables" \
			"Inventory only. Traffic through an unexpected proxy can be observed or altered." high \
			"Confirm the proxy is the one your organisation provides." "Unset or correct proxy variables that are not expected."
	fi
	return "$rc"
}

# @description Name of the socket source in use, for the evidence-source field.
# @internal
# @arg $1 string `listeners` or `connections`.
# @stdout The command line used.
# @exitcode 0 Always.
# @example
#   _shell::security::net::source_label listeners
#
_shell::security::net::source_label() {
	if [ "$(shell::os::type)" = "linux" ] && _shell::security::have ss; then
		if [ "${1-}" = "connections" ]; then printf 'ss -tnp state established'; else printf 'ss -tulnp'; fi
	else
		if [ "${1-}" = "connections" ]; then printf 'lsof -nP -iTCP -sTCP:ESTABLISHED'; else printf 'lsof -nP -iTCP -sTCP:LISTEN; lsof -nP -iUDP'; fi
	fi
}

# @description Inspect listening ports, resolver and proxy configuration for this host.
#   Reports non-loopback listeners (risky database, remote-admin and unauthenticated-API ports are
#   graded; the service is inferred from the port number only), the DNS resolvers and any proxy in
#   the environment (credentials are stripped). Observes only the local host.
# @option -h | --help Show help and return.
# @option -f | --format Output format: text, json, markdown or csv (default: text).
# @option --min-severity Lowest severity to print (default: INFO).
# @stdout The findings.
# @exitcode 0 Success.
# @exitcode 2 Invalid argument.
# @exitcode 3 Sockets could not be listed (reported as a "Not inspected" finding).
# @example
#   shell::security::hunt::network --format json
#
shell::security::hunt::network() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Inspect listening ports, DNS resolvers and proxy settings of this host"
		shell::logger::usage "shell::security::hunt::network [-f text|json|markdown|csv] [--min-severity LEVEL]"
		shell::logger::option "-f, --format" "Output format (default: text)"
		shell::logger::option "--min-severity" "Lowest severity to print (default: INFO)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::security::hunt::network --min-severity MEDIUM"
		return "$RETURN_SUCCESS"
	fi
	_shell::security::args::parse "$@" || return "$?"
	local format="$_SHELL_SECURITY_FORMAT" min="$_SHELL_SECURITY_MIN_SEVERITY" rc=0
	_shell::security::session::begin || return "$?"
	local owns="$_SHELL_SECURITY_OWNS"

	_shell::security::hunt::network::scan || rc=$?

	_shell::security::session::finish "$owns" "$format" "$min" || return "$?"
	return "$rc"
}

# @description Record the findings about established connections, correlated with their processes.
# @internal
# @exitcode 0 Success.
# @exitcode 3 Connections could not be listed.
# @example
#   _shell::security::hunt::connections::scan
#
_shell::security::hunt::connections::scan() {
	local s="$SHELL_SECURITY_SEP" conns
	if ! conns="$(_shell::security::net::connections)"; then
		_shell::security::finding::unavailable network "established connections" "neither 'ss' (Linux) nor 'lsof' is installed"
		return "$RETURN_NOT_FOUND"
	fi
	if [ -z "$conns" ]; then
		_shell::security::finding::add network INFO "established connections" "No established TCP connections were found" "$(_shell::security::net::source_label connections)" \
			"The connection listing succeeded and returned no rows." high "None needed." "None needed."
		return "$RETURN_SUCCESS"
	fi
	_shell::security::tmp_prime

	local procs="" total remote_count unknown_owner
	total="$(printf '%s\n' "$conns" | grep -c .)"
	remote_count="$(printf '%s\n' "$conns" | awk -F"$s" '{print $4}' | sort -u | grep -c .)"
	unknown_owner="$(printf '%s\n' "$conns" | awk -F"$s" '$6 == "" {n++} END {print n + 0}')"
	_shell::security::finding::add network INFO "established connections" \
		"$total established TCP connection(s) to $remote_count distinct remote address(es)" "$(_shell::security::net::source_label connections)" \
		"Inventory of the host's own outbound and inbound sessions at this moment." high \
		"Review remote addresses you do not recognise." "None needed."
	if [ "$unknown_owner" -gt 0 ]; then
		_shell::security::finding::add network INFO "connection owners" "The owning process of $unknown_owner connection(s) could not be read" "$(_shell::security::net::source_label connections)" \
			"Process names for other users' sockets need elevated privileges. The owner is unknown, not absent." high \
			"Rerun with the privileges you are authorised to use to see owners." "None needed."
	fi

	if _shell::security::have ps; then
		procs="$(_shell::security::process::list)"
	fi

	local proto laddr lport raddr rport pid proc exe
	printf '%s\n' "$conns" | while IFS="$s" read -r proto laddr lport raddr rport pid proc; do
		[ -n "$proto" ] || continue
		_shell::security::net::is_loopback "$raddr" && continue

		# Connection owned by a process running from a temporary directory.
		if [ -n "$pid" ] && [ -n "$procs" ]; then
			exe="$(printf '%s\n' "$procs" | awk -F"$s" -v p="$pid" '$1 == p {print $7; exit}')"
			exe="${exe% (deleted)}"
			if [ -n "$exe" ] && _shell::security::in_tmp "$exe"; then
				_shell::security::finding::add network HIGH "pid $pid ($exe) -> $raddr:$rport" \
					"Process '$proc' (pid $pid) runs from a temporary directory and has a connection to $raddr:$rport" "$(_shell::security::net::source_label connections); ps" \
					"A program in a temporary directory talking to a remote host is a typical command-and-control or download pattern. Installers and test tools fetching data do the same, so validate it." medium \
					"Identify the remote host and the process's parent and start time; compare the binary's hash with a trusted source; capture the connection details now." \
					"If it is not expected, preserve evidence, then block the destination and stop the process through your incident process."
			fi
		fi

		# Remote port often used by remote-access tools or miners.
		case " $SHELL_SECURITY_SUSPECT_REMOTE_PORTS " in *" $rport "*)
			_shell::security::finding::add network MEDIUM "${proc:-unknown process} -> $raddr:$rport" \
				"Connection to remote port $rport${proc:+ owned by '$proc'}${pid:+ (pid $pid)}" "$(_shell::security::net::source_label connections)" \
				"Port $rport is often used by remote-access tools, IRC bots and mining pools, but the port number alone proves nothing; many services use these ports legitimately." low \
				"Identify the owning process and the remote host; check whether the application is meant to talk to it." \
				"Block the destination if the traffic is not expected."
			;;
		esac
	done
	return "$RETURN_SUCCESS"
}

# @description Inspect established connections and correlate them with their processes.
#   Reports a connection when its process runs from a temporary directory (HIGH, correlated with
#   the process list) or when it targets a port often used by remote-access tools and miners
#   (MEDIUM, low confidence). With `--list` it prints the raw connection table instead. Observes
#   only this host's own sockets.
# @option -h | --help Show help and return.
# @option -f | --format Output format: text, json, markdown or csv (default: text).
# @option --min-severity Lowest severity to print (default: INFO).
# @option --list Print the connection table instead of findings.
# @stdout The findings, or the table with --list.
# @exitcode 0 Success.
# @exitcode 2 Invalid argument.
# @exitcode 3 Connections could not be listed.
# @example
#   shell::security::hunt::connections --list --format csv
#
shell::security::hunt::connections() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Inspect established connections and map them to their processes"
		shell::logger::usage "shell::security::hunt::connections [--list] [-f text|json|markdown|csv] [--min-severity LEVEL]"
		shell::logger::option "--list" "Print the connection table instead of findings"
		shell::logger::option "-f, --format" "Output format (default: text)"
		shell::logger::option "--min-severity" "Lowest severity to print (default: INFO)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::security::hunt::connections --list --format csv"
		return "$RETURN_SUCCESS"
	fi
	local list="false" count="$#" arg
	while [ "$count" -gt 0 ]; do
		arg="$1"
		shift
		count=$((count - 1))
		if [ "$arg" = "--list" ]; then list="true"; else set -- "$@" "$arg"; fi
	done
	_shell::security::args::parse "$@" || return "$?"
	local format="$_SHELL_SECURITY_FORMAT" min="$_SHELL_SECURITY_MIN_SEVERITY" rc=0

	if [ "$list" = "true" ]; then
		local conns
		if ! conns="$(_shell::security::net::connections)"; then
			shell::logger::error "Cannot list connections: neither 'ss' (Linux) nor 'lsof' is installed"
			return "$RETURN_NOT_FOUND"
		fi
		printf '%s\n' "$conns" | _shell::security::render::table "$format" "protocol local_address local_port remote_address remote_port pid process" "$SHELL_SECURITY_SEP"
		return "$?"
	fi

	_shell::security::session::begin || return "$?"
	local owns="$_SHELL_SECURITY_OWNS"

	_shell::security::hunt::connections::scan || rc=$?

	_shell::security::session::finish "$owns" "$format" "$min" || return "$?"
	return "$rc"
}
