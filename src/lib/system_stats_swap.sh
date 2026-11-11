#!/usr/bin/env bash
# @file lib/system_stats_swap.sh
# @brief Swap usage on Linux and macOS.
# @description
#   Swap is optional. A machine without swap is a normal state, not an error: the section
#   prints `Status: Disabled` with zero sizes and the exit code stays 0.
#
#   Status
#     Enabled      the configured swap capacity is above 0.
#     Disabled     the source was read and the capacity is 0.
#     Unavailable  the source is missing or its content cannot be understood. A warning goes
#                  to stderr, the sizes print as 0 and the exit code stays 0 so the overview
#                  keeps working. Scripts should test the status (`--json`: "status").
#
#   Linux  (source: /proc/meminfo, optionally /proc/swaps; no `swapon`, no root)
#     Total  SwapTotal, which already adds up every swap partition and file.
#     Free   SwapFree.
#     Used   SwapTotal - SwapFree. SwapCached is not subtracted: it is swap content that is
#            also held in RAM and it is still stored on the device.
#     Devices (JSON, and a line in the text block) the number of entries of /proc/swaps,
#            shown only when that file is readable.
#
#   macOS  (source: `sysctl -n vm.swapusage`, for example
#          `total = 2048.00M  used = 1023.25M  free = 1024.75M  (encrypted)`)
#     Total and Used come from the command (M = MiB, G = GiB, K = KiB); Free = Total - Used.
#     macOS creates swap files on demand, so `Disabled` on macOS means "no swap file exists
#     right now", not "swap cannot be used".
#
#   Usage = Used / Total, rounded to the nearest percent; 0 when there is no swap.

# @internal
# @description Convert a size token of `vm.swapusage` such as `1023.25M` to bytes.
#   K, M, G and T are powers of 1024; a token without a letter is bytes.
# @arg $1 string The token.
# @set SHELL_STATS_OUT integer Bytes (fraction truncated).
# @exitcode 0 Success.
# @exitcode 1 The token is not a number with an optional unit letter.
_shell::system::stats::swap::to_bytes() {
	local tok="${1-}" unit="" num mult int frac="" flen=0 denom=1
	SHELL_STATS_OUT=""
	case "$tok" in
	*[KMGT])
		unit="${tok#"${tok%?}"}"
		num="${tok%?}"
		;;
	*) num="$tok" ;;
	esac
	case "$unit" in
	K) mult=1024 ;;
	M) mult=1048576 ;;
	G) mult=1073741824 ;;
	T) mult=1099511627776 ;;
	*) mult=1 ;;
	esac
	int="${num%%.*}"
	[ -n "$int" ] || int=0
	case "$num" in
	*.*) frac="${num#*.}" ;;
	esac
	_shell::system::stats::uint "$int" || return "$RETURN_FAILURE"
	int="$SHELL_STATS_OUT"
	if [ -n "$frac" ]; then
		frac="${frac:0:6}"
		flen="${#frac}"
		_shell::system::stats::uint "$frac" || return "$RETURN_FAILURE"
		frac="$SHELL_STATS_OUT"
		while [ "$flen" -gt 0 ]; do
			denom=$((denom * 10))
			flen=$((flen - 1))
		done
	else
		frac=0
	fi
	SHELL_STATS_OUT=$((int * mult + frac * mult / denom))
	return "$RETURN_SUCCESS"
}

# @internal
# @description Build the swap record `state SEP total SEP used SEP free SEP devices` (bytes).
#   `state` is `enabled`, `disabled` or `unavailable`; `devices` is empty when unknown.
# @arg $1 string The state.
# @arg $2 integer Total bytes.
# @arg $3 integer Used bytes.
# @arg $4 string Number of swap devices, or empty.
# @stdout The record.
# @exitcode 0 Always.
_shell::system::stats::swap::record() {
	local state="$1" total="$2" used="$3" devices="${4-}" free
	[ "$used" -gt "$total" ] && used="$total"
	free=$((total - used))
	printf '%s%s%s%s%s%s%s%s%s\n' "$state" "$SHELL_STATS_SEP" "$total" "$SHELL_STATS_SEP" "$used" "$SHELL_STATS_SEP" "$free" "$SHELL_STATS_SEP" "$devices"
}

# @internal
# @description Parse `/proc/meminfo` (and optionally `/proc/swaps`) into the swap record.
# @arg $1 string The text of /proc/meminfo.
# @arg $2 string The text of /proc/swaps; empty when the file is not available.
# @stdout The record (state `unavailable` when SwapTotal or SwapFree is missing).
# @exitcode 0 Always.
_shell::system::stats::swap::parse_meminfo() {
	local text="${1-}" swaps="${2-}" total free devices="" line first=1 n=0
	if ! _shell::system::stats::meminfo::get "$text" SwapTotal; then
		_shell::system::stats::swap::record unavailable 0 0 ""
		return "$RETURN_SUCCESS"
	fi
	total="$SHELL_STATS_OUT"
	if ! _shell::system::stats::meminfo::get "$text" SwapFree; then
		_shell::system::stats::swap::record unavailable 0 0 ""
		return "$RETURN_SUCCESS"
	fi
	free="$SHELL_STATS_OUT"
	[ "$free" -gt "$total" ] && free="$total"
	if [ -n "$swaps" ]; then
		while IFS= read -r line; do
			if [ "$first" = 1 ]; then
				first=0
				continue
			fi
			[ -n "$line" ] && n=$((n + 1))
		done <<<"$swaps"
		devices="$n"
	fi
	if [ "$total" -gt 0 ]; then
		_shell::system::stats::swap::record enabled "$total" "$((total - free))" "$devices"
	else
		_shell::system::stats::swap::record disabled 0 0 "$devices"
	fi
}

# @internal
# @description Parse the output of macOS `sysctl -n vm.swapusage` into the swap record.
# @arg $1 string The output.
# @stdout The record (state `unavailable` when the output is empty or not understood).
# @exitcode 0 Always.
_shell::system::stats::swap::parse_swapusage() {
	local text="${1-}" rest tok total used
	case "$text" in
	*"total = "*"used = "*) ;;
	*)
		_shell::system::stats::swap::record unavailable 0 0 ""
		return "$RETURN_SUCCESS"
		;;
	esac
	rest="${text#*"total = "}"
	tok="${rest%%[[:space:]]*}"
	if ! _shell::system::stats::swap::to_bytes "$tok"; then
		_shell::system::stats::swap::record unavailable 0 0 ""
		return "$RETURN_SUCCESS"
	fi
	total="$SHELL_STATS_OUT"
	rest="${text#*"used = "}"
	tok="${rest%%[[:space:]]*}"
	if ! _shell::system::stats::swap::to_bytes "$tok"; then
		_shell::system::stats::swap::record unavailable 0 0 ""
		return "$RETURN_SUCCESS"
	fi
	used="$SHELL_STATS_OUT"
	if [ "$total" -gt 0 ]; then
		_shell::system::stats::swap::record enabled "$total" "$used" ""
	else
		_shell::system::stats::swap::record disabled 0 0 ""
	fi
}

# @internal
# @description Collect the swap record on Linux.
# @stdout The record.
# @stderr A warning when /proc/meminfo cannot be read.
# @exitcode 0 Always (an unreadable source gives the state `unavailable`).
_shell::system::stats::swap::linux() {
	local text swaps=""
	if [ ! -r "$SHELL_STATS_PROC_MEMINFO" ]; then
		shell::logger::warn "Cannot read $SHELL_STATS_PROC_MEMINFO: swap status is unavailable"
		_shell::system::stats::swap::record unavailable 0 0 ""
		return "$RETURN_SUCCESS"
	fi
	text="$(cat "$SHELL_STATS_PROC_MEMINFO" 2>/dev/null)"
	if [ -r "$SHELL_STATS_PROC_SWAPS" ]; then
		swaps="$(cat "$SHELL_STATS_PROC_SWAPS" 2>/dev/null)"
	fi
	_shell::system::stats::swap::parse_meminfo "$text" "$swaps"
}

# @internal
# @description Collect the swap record on macOS.
# @stdout The record.
# @stderr A warning when `sysctl` is missing or its output is not understood.
# @exitcode 0 Always (an unusable source gives the state `unavailable`).
_shell::system::stats::swap::macos() {
	local text
	if ! command -v sysctl >/dev/null 2>&1; then
		shell::logger::warn "sysctl is not installed: swap status is unavailable"
		_shell::system::stats::swap::record unavailable 0 0 ""
		return "$RETURN_SUCCESS"
	fi
	text="$(sysctl -n vm.swapusage 2>/dev/null)"
	_shell::system::stats::swap::parse_swapusage "$text"
}

# @internal
# @description Print the swap section as a block of `Label: value` lines.
#   Uses SHELL_STATS_OPT_UNIT and SHELL_STATS_OPT_SI for the sizes.
# @arg $1 string The record `state SEP total SEP used SEP free SEP devices`.
# @stdout The title and the block.
# @exitcode 0 Always.
_shell::system::stats::swap::render() {
	local state total used free devices label t u f pct w v
	IFS="$SHELL_STATS_SEP" read -r state total used free devices <<<"${1-}"
	case "$state" in
	enabled) label="Enabled" ;;
	disabled) label="Disabled" ;;
	*) label="Unavailable" ;;
	esac
	_shell::system::stats::heading "SWAP MEMORY"
	_shell::system::stats::format_bytes "$total" "$SHELL_STATS_OPT_UNIT" "$SHELL_STATS_OPT_SI"
	t="$SHELL_STATS_OUT"
	_shell::system::stats::format_bytes "$used" "$SHELL_STATS_OPT_UNIT" "$SHELL_STATS_OPT_SI"
	u="$SHELL_STATS_OUT"
	_shell::system::stats::format_bytes "$free" "$SHELL_STATS_OPT_UNIT" "$SHELL_STATS_OPT_SI"
	f="$SHELL_STATS_OUT"
	_shell::system::stats::percent "$used" "$total" round
	pct="$SHELL_STATS_OUT%"
	w=0
	for v in "$label" "$t" "$u" "$f" "$pct" "$devices"; do
		[ "${#v}" -gt "$w" ] && w="${#v}"
	done
	_shell::system::stats::kv "Status" "$label" "$w"
	_shell::system::stats::kv "Total" "$t" "$w"
	_shell::system::stats::kv "Used" "$u" "$w"
	_shell::system::stats::kv "Free" "$f" "$w"
	_shell::system::stats::kv "Usage" "$pct" "$w"
	if [ -n "$devices" ]; then
		_shell::system::stats::kv "Devices" "$devices" "$w"
	fi
}

# @internal
# @description Print the swap record as a JSON object (sizes in bytes).
# @arg $1 string The record `state SEP total SEP used SEP free SEP devices`.
# @stdout `{"status":"enabled|disabled|unavailable","total":N,"used":N,"free":N,"usage":N,"devices":N|null}`.
# @exitcode 0 Always.
_shell::system::stats::swap::json() {
	local state total used free devices
	IFS="$SHELL_STATS_SEP" read -r state total used free devices <<<"${1-}"
	[ -n "$devices" ] || devices="null"
	_shell::system::stats::percent "$used" "$total" round
	printf '{"status":"%s","total":%s,"used":%s,"free":%s,"usage":%s,"devices":%s}\n' "$state" "$total" "$used" "$free" "$SHELL_STATS_OUT" "$devices"
}

# @internal
# @description Collect and print the swap section in the selected output mode.
# @arg $1 string The platform: linux or macos.
# @stdout The block or the JSON object.
# @exitcode 0 Always.
_shell::system::stats::swap::emit() {
	local record rc
	record="$("_shell::system::stats::swap::$1")"
	rc=$?
	[ "$rc" -eq 0 ] || return "$rc"
	if [ "$SHELL_STATS_OPT_JSON" = "1" ]; then
		_shell::system::stats::swap::json "$record"
	else
		_shell::system::stats::swap::render "$record"
	fi
}

# @description Show the swap usage: status, total, used, free and usage.
#   Linux reads SwapTotal and SwapFree from /proc/meminfo (and counts the devices in
#   /proc/swaps); macOS reads `sysctl -n vm.swapusage`. No swap is a normal result: the status
#   is `Disabled`, the sizes are 0 and the exit code is 0. When the source cannot be read the
#   status is `Unavailable` with a warning on stderr. Read-only, no root, no `swapon`.
#   Sizes are binary (KiB, MiB, GiB, TiB) unless `--si` or a fixed `--unit` says otherwise.
# @option -h | --help Show help and return.
# @option --unit Fixed unit for every size: B, KiB, MiB, GiB, TiB, KB, MB, GB or TB.
# @option --si Decimal units (KB, MB, GB) instead of binary (KiB, MiB, GiB) for automatic scaling.
# @option --json Machine-readable output (sizes in bytes, no decoration).
# @stdout The block, or a JSON object.
# @stderr Warnings and errors.
# @exitcode 0 Success, including "no swap" and "unavailable".
# @exitcode 2 Unknown option or invalid unit.
# @exitcode 4 Unsupported operating system.
# @example
#   shell::system::stats::swap
#   shell::system::stats::swap --json
#
shell::system::stats::swap() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show the swap usage"
		shell::logger::usage "shell::system::stats::swap [--unit <unit>] [--si] [--json]"
		shell::logger::option "--unit <unit>" "Fixed unit: B, KiB, MiB, GiB, TiB, KB, MB, GB, TB"
		shell::logger::option "--si" "Decimal units (KB, MB, GB) instead of binary (KiB, MiB, GiB)"
		shell::logger::option "--json" "Machine-readable output (sizes in bytes)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::system::stats::swap"
		return "$RETURN_SUCCESS"
	fi

	_shell::system::stats::options 0 "$@" || return "$?"
	local platform
	platform="$(_shell::system::stats::platform)" || return "$?"
	_shell::system::stats::swap::emit "$platform"
}
