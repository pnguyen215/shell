#!/usr/bin/env bash
# @file lib/system_stats_memory.sh
# @brief Physical memory (RAM) usage on Linux and macOS.
# @description
#   The two kernels account for memory differently, so each platform has its own
#   calculation. Both print the same five values; they are estimates of the same idea
#   ("what applications hold" against "what they could still get"), not identical numbers.
#
#   Linux  (source: /proc/meminfo, kB values times 1024)
#     Total      MemTotal
#     Available  MemAvailable, the kernel's own estimate of memory usable by applications
#                without swapping (free memory plus the page cache and reclaimable slab it
#                can drop). `MemFree` alone is never used for this: it ignores the cache.
#                On kernels older than 3.14 without MemAvailable the estimate is
#                MemFree + Buffers + Cached + SReclaimable - Shmem (shared memory sits in
#                `Cached` but cannot be dropped), kept between 0 and Total.
#     Used       Total - Available. Buffers and caches are inside Available, so they are
#                not subtracted a second time and are not counted as used.
#     Free       MemFree, memory that holds nothing at all.
#     Usage      Used / Total, rounded to the nearest percent.
#
#   macOS  (sources: `sysctl -n hw.memsize` and `vm_stat`)
#     `vm_stat` counts PAGES; the page size comes from its first line ("page size of
#     16384 bytes"), it is never assumed (it is 4096 on Intel and 16384 on Apple silicon).
#     Used       what Activity Monitor calls Memory Used:
#                (Anonymous pages - Pages purgeable + Pages wired down +
#                 Pages occupied by compressor) * page size.
#                When `vm_stat` has no "Anonymous pages" line (old macOS) the estimate is
#                (Pages active + Pages wired down + Pages occupied by compressor).
#     Total      hw.memsize.
#     Available  Total - Used: cached files (File-backed pages), purgeable memory,
#                inactive and speculative pages and free pages can all be given back.
#     Free       Pages free (vm_stat already excludes speculative pages from it).
#     Usage      Used / Total, rounded to the nearest percent.
#
#   The values are read at one instant; memory keeps changing while the command runs.

# @internal
# @description Parse the text of `/proc/meminfo` into one record `total SEP used SEP available SEP free` (bytes).
# @arg $1 string The text of /proc/meminfo.
# @stdout The record.
# @stderr The reason when MemTotal is missing or zero.
# @exitcode 0 Success.
# @exitcode 1 The text has no usable MemTotal.
_shell::system::stats::memory::parse_meminfo() {
	local text="${1-}" total free avail buffers cached recl shmem used
	if ! _shell::system::stats::meminfo::get "$text" MemTotal || [ "$SHELL_STATS_OUT" -le 0 ]; then
		shell::logger::error "Invalid memory information: MemTotal is missing or zero"
		return "$RETURN_FAILURE"
	fi
	total="$SHELL_STATS_OUT"
	free=0
	_shell::system::stats::meminfo::get "$text" MemFree && free="$SHELL_STATS_OUT"
	if _shell::system::stats::meminfo::get "$text" MemAvailable; then
		avail="$SHELL_STATS_OUT"
	else
		buffers=0
		cached=0
		recl=0
		shmem=0
		_shell::system::stats::meminfo::get "$text" Buffers && buffers="$SHELL_STATS_OUT"
		_shell::system::stats::meminfo::get "$text" Cached && cached="$SHELL_STATS_OUT"
		_shell::system::stats::meminfo::get "$text" SReclaimable && recl="$SHELL_STATS_OUT"
		_shell::system::stats::meminfo::get "$text" Shmem && shmem="$SHELL_STATS_OUT"
		avail=$((free + buffers + cached + recl - shmem))
	fi
	[ "$avail" -lt 0 ] && avail=0
	[ "$avail" -gt "$total" ] && avail="$total"
	[ "$free" -gt "$total" ] && free="$total"
	used=$((total - avail))
	printf '%s%s%s%s%s%s%s\n' "$total" "$SHELL_STATS_SEP" "$used" "$SHELL_STATS_SEP" "$avail" "$SHELL_STATS_SEP" "$free"
}

# @internal
# @description Parse macOS `hw.memsize` and `vm_stat` output into one record `total SEP used SEP available SEP free` (bytes).
# @arg $1 string The output of `sysctl -n hw.memsize` (bytes).
# @arg $2 string The output of `vm_stat`.
# @stdout The record.
# @stderr The reason when an input is not valid.
# @exitcode 0 Success.
# @exitcode 1 Invalid `hw.memsize` or `vm_stat` output.
_shell::system::stats::memory::parse_vm_stat() {
	local memsize="${1-}" text="${2-}" line key val
	local psize="" free="" active="" wired="" comp=0 purg=0 anon=""
	memsize="${memsize//[[:space:]]/}"
	if ! _shell::system::stats::uint "$memsize" || [ "$SHELL_STATS_OUT" -le 0 ]; then
		shell::logger::error "Invalid memory information: hw.memsize is '$memsize'"
		return "$RETURN_FAILURE"
	fi
	local total="$SHELL_STATS_OUT"

	while IFS= read -r line; do
		case "$line" in
		*"page size of "*)
			val="${line#*page size of }"
			val="${val%%[!0-9]*}"
			_shell::system::stats::uint "$val" && psize="$SHELL_STATS_OUT"
			continue
			;;
		esac
		key="${line%%:*}"
		val="${line#*:}"
		val="${val//[!0-9]/}"
		_shell::system::stats::uint "$val" || continue
		val="$SHELL_STATS_OUT"
		case "$key" in
		"Pages free") free="$val" ;;
		"Pages active") active="$val" ;;
		"Pages wired down") wired="$val" ;;
		"Pages occupied by compressor") comp="$val" ;;
		"Pages purgeable") purg="$val" ;;
		"Anonymous pages") anon="$val" ;;
		esac
	done <<<"$text"

	if [ -z "$psize" ] || [ "$psize" -le 0 ] || [ -z "$free" ] || [ -z "$wired" ]; then
		shell::logger::error "Invalid vm_stat output: no page size, free pages or wired pages"
		return "$RETURN_FAILURE"
	fi

	local used_pages
	if [ -n "$anon" ]; then
		used_pages=$((anon - purg + wired + comp))
		[ "$anon" -lt "$purg" ] && used_pages=$((wired + comp))
	elif [ -n "$active" ]; then
		used_pages=$((active + wired + comp))
	else
		shell::logger::error "Invalid vm_stat output: neither anonymous nor active pages"
		return "$RETURN_FAILURE"
	fi
	local used=$((used_pages * psize)) avail freeb=$((free * psize))
	[ "$used" -gt "$total" ] && used="$total"
	avail=$((total - used))
	[ "$freeb" -gt "$avail" ] && freeb="$avail"
	printf '%s%s%s%s%s%s%s\n' "$total" "$SHELL_STATS_SEP" "$used" "$SHELL_STATS_SEP" "$avail" "$SHELL_STATS_SEP" "$freeb"
}

# @internal
# @description Collect the memory record on Linux from /proc/meminfo.
# @stdout The record `total SEP used SEP available SEP free`.
# @stderr The reason when the file is missing or invalid.
# @exitcode 0 Success.
# @exitcode 1 Invalid content.
# @exitcode 3 /proc/meminfo is missing or unreadable.
_shell::system::stats::memory::linux() {
	local text
	if [ ! -r "$SHELL_STATS_PROC_MEMINFO" ]; then
		shell::logger::error "Cannot read $SHELL_STATS_PROC_MEMINFO"
		return "$RETURN_NOT_FOUND"
	fi
	text="$(cat "$SHELL_STATS_PROC_MEMINFO" 2>/dev/null)"
	_shell::system::stats::memory::parse_meminfo "$text"
}

# @internal
# @description Collect the memory record on macOS from `sysctl` and `vm_stat`.
# @stdout The record `total SEP used SEP available SEP free`.
# @stderr The reason when a command is missing or its output is invalid.
# @exitcode 0 Success.
# @exitcode 1 Invalid output.
# @exitcode 3 `sysctl` or `vm_stat` is not installed.
_shell::system::stats::memory::macos() {
	local memsize vmstat
	if ! command -v sysctl >/dev/null 2>&1 || ! command -v vm_stat >/dev/null 2>&1; then
		shell::logger::error "sysctl and vm_stat are required"
		return "$RETURN_NOT_FOUND"
	fi
	memsize="$(sysctl -n hw.memsize 2>/dev/null)"
	vmstat="$(vm_stat 2>/dev/null)"
	_shell::system::stats::memory::parse_vm_stat "$memsize" "$vmstat"
}

# @internal
# @description Print the memory section as a block of `Label: value` lines.
#   Uses SHELL_STATS_OPT_UNIT and SHELL_STATS_OPT_SI for the sizes.
# @arg $1 string The record `total SEP used SEP available SEP free`.
# @stdout The title and the block.
# @exitcode 0 Always.
_shell::system::stats::memory::render() {
	local total used avail free pct t u a f w
	IFS="$SHELL_STATS_SEP" read -r total used avail free <<<"${1-}"
	_shell::system::stats::heading "PHYSICAL MEMORY"
	_shell::system::stats::format_bytes "$total" "$SHELL_STATS_OPT_UNIT" "$SHELL_STATS_OPT_SI"
	t="$SHELL_STATS_OUT"
	_shell::system::stats::format_bytes "$used" "$SHELL_STATS_OPT_UNIT" "$SHELL_STATS_OPT_SI"
	u="$SHELL_STATS_OUT"
	_shell::system::stats::format_bytes "$avail" "$SHELL_STATS_OPT_UNIT" "$SHELL_STATS_OPT_SI"
	a="$SHELL_STATS_OUT"
	_shell::system::stats::format_bytes "$free" "$SHELL_STATS_OPT_UNIT" "$SHELL_STATS_OPT_SI"
	f="$SHELL_STATS_OUT"
	_shell::system::stats::percent "$used" "$total" round
	pct="$SHELL_STATS_OUT%"
	w=0
	local v
	for v in "$t" "$u" "$a" "$f" "$pct"; do
		[ "${#v}" -gt "$w" ] && w="${#v}"
	done
	_shell::system::stats::kv "Total" "$t" "$w"
	_shell::system::stats::kv "Used" "$u" "$w"
	_shell::system::stats::kv "Available" "$a" "$w"
	_shell::system::stats::kv "Free" "$f" "$w"
	_shell::system::stats::kv "Usage" "$pct" "$w"
}

# @internal
# @description Print the memory record as a JSON object (sizes in bytes).
# @arg $1 string The record `total SEP used SEP available SEP free`.
# @stdout `{"total":N,"used":N,"available":N,"free":N,"usage":N}`.
# @exitcode 0 Always.
_shell::system::stats::memory::json() {
	local total used avail free
	IFS="$SHELL_STATS_SEP" read -r total used avail free <<<"${1-}"
	_shell::system::stats::percent "$used" "$total" round
	printf '{"total":%s,"used":%s,"available":%s,"free":%s,"usage":%s}\n' "$total" "$used" "$avail" "$free" "$SHELL_STATS_OUT"
}

# @internal
# @description Collect and print the memory section in the selected output mode.
# @arg $1 string The platform: linux or macos.
# @stdout The block or the JSON object.
# @exitcode 0 Success.
# @exitcode 1 Invalid source content.
# @exitcode 3 A source file or command is missing.
_shell::system::stats::memory::emit() {
	local record rc
	record="$("_shell::system::stats::memory::$1")"
	rc=$?
	[ "$rc" -eq 0 ] || return "$rc"
	if [ "$SHELL_STATS_OPT_JSON" = "1" ]; then
		_shell::system::stats::memory::json "$record"
	else
		_shell::system::stats::memory::render "$record"
	fi
}

# @description Show the physical memory (RAM): total, used, available, free and usage.
#   Linux reads /proc/meminfo (Used = MemTotal - MemAvailable); macOS reads `sysctl hw.memsize`
#   and `vm_stat` with the real page size (Used = app + wired + compressed memory, like
#   Activity Monitor). The calculations differ on purpose, see the file header of
#   `lib/system_stats_memory.sh`. Read-only, no root.
#   Sizes are binary (KiB, MiB, GiB, TiB) unless `--si` or a fixed `--unit` says otherwise.
# @option -h | --help Show help and return.
# @option --unit Fixed unit for every size: B, KiB, MiB, GiB, TiB, KB, MB, GB or TB.
# @option --si Decimal units (KB, MB, GB) instead of binary (KiB, MiB, GiB) for automatic scaling.
# @option --json Machine-readable output (sizes in bytes, no decoration).
# @stdout The block, or a JSON object.
# @stderr Errors.
# @exitcode 0 Success.
# @exitcode 1 The source content is invalid.
# @exitcode 2 Unknown option or invalid unit.
# @exitcode 3 /proc/meminfo, `sysctl` or `vm_stat` is missing.
# @exitcode 4 Unsupported operating system.
# @example
#   shell::system::stats::memory
#   shell::system::stats::memory --unit MiB
#   shell::system::stats::memory --json
#
shell::system::stats::memory() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show the physical memory (RAM) usage"
		shell::logger::usage "shell::system::stats::memory [--unit <unit>] [--si] [--json]"
		shell::logger::option "--unit <unit>" "Fixed unit: B, KiB, MiB, GiB, TiB, KB, MB, GB, TB"
		shell::logger::option "--si" "Decimal units (KB, MB, GB) instead of binary (KiB, MiB, GiB)"
		shell::logger::option "--json" "Machine-readable output (sizes in bytes)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::system::stats::memory --unit MiB"
		return "$RETURN_SUCCESS"
	fi

	_shell::system::stats::options 0 "$@" || return "$?"
	local platform
	platform="$(_shell::system::stats::platform)" || return "$?"
	_shell::system::stats::memory::emit "$platform"
}
