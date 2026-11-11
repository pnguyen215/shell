#!/usr/bin/env bash
# @file lib/system_stats.sh
# @brief Shared helpers and the overview of the system resource statistics (disk, RAM, swap).
# @description
#   Read-only. Nothing here writes to a disk, changes swap or touches memory settings,
#   and nothing needs root.
#
#   Public API (one file per resource, this file holds the overview):
#     shell::system::stats::disk     mounted filesystems       (system_stats_disk.sh)
#     shell::system::stats::memory   physical memory           (system_stats_memory.sh)
#     shell::system::stats::swap     swap                      (system_stats_swap.sh)
#     shell::system::stats::all      the three, with a header
#
#   Layers, per resource:
#     collect   `::linux` / `::macos` read the platform sources and print one normalised
#               record per line (fields joined by SHELL_STATS_SEP, sizes in BYTES).
#     parse     pure functions that turn command output into those records, so tests feed
#               them fixtures and need neither the real OS nor the real command.
#     render    `::render` (aligned text) and `::json` (dependency-free) read a record.
#
#   Sizes are bytes until they are printed. The default unit system is binary (KiB, MiB,
#   GiB, TiB: powers of 1024) and says so in the label; `--si` switches to decimal
#   (KB, MB, GB, TB: powers of 1000). The two are never mixed in one output.
#
#   Options shared by the public functions are parsed once, into the SHELL_STATS_OPT_*
#   variables, by `_shell::system::stats::options`. Helpers leave their answer in
#   SHELL_STATS_OUT (as the markdown module does) because command substitution would cost
#   a fork per table cell.

# @internal
# @description Resolve a unit name to the number of bytes it stands for.
# @arg $1 string One of B, KiB, MiB, GiB, TiB (powers of 1024) or KB, MB, GB, TB (powers of 1000).
# @set SHELL_STATS_OUT integer The divisor.
# @exitcode 0 Known unit.
# @exitcode 1 Unknown unit.
_shell::system::stats::unit_divisor() {
	case "${1-}" in
	B) SHELL_STATS_OUT=1 ;;
	KiB) SHELL_STATS_OUT=1024 ;;
	MiB) SHELL_STATS_OUT=1048576 ;;
	GiB) SHELL_STATS_OUT=1073741824 ;;
	TiB) SHELL_STATS_OUT=1099511627776 ;;
	KB) SHELL_STATS_OUT=1000 ;;
	MB) SHELL_STATS_OUT=1000000 ;;
	GB) SHELL_STATS_OUT=1000000000 ;;
	TB) SHELL_STATS_OUT=1000000000000 ;;
	*)
		SHELL_STATS_OUT=""
		return "$RETURN_FAILURE"
		;;
	esac
	return "$RETURN_SUCCESS"
}

# @internal
# @description Check that a value is a plain non-negative integer (at most 18 digits) and
#   normalise it (no leading zeros, so `$(( ))` never reads it as octal).
# @arg $1 string The value.
# @set SHELL_STATS_OUT integer The normalised integer.
# @exitcode 0 It is an integer.
# @exitcode 1 It is not.
_shell::system::stats::uint() {
	local v="${1-}"
	SHELL_STATS_OUT=""
	case "$v" in
	'' | *[!0-9]*) return "$RETURN_FAILURE" ;;
	esac
	[ "${#v}" -le 18 ] || return "$RETURN_FAILURE"
	v="${v#"${v%%[!0]*}"}"
	SHELL_STATS_OUT="${v:-0}"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Format a byte count for display with one decimal.
#   `auto` picks the largest unit that keeps the number at 1 or more; a unit name fixes it.
# @arg $1 integer Bytes.
# @arg $2 string `auto` or a unit accepted by `_shell::system::stats::unit_divisor`.
# @arg $3 integer 1 for decimal units (KB, MB ...) when the unit is `auto`; default 0.
# @set SHELL_STATS_OUT string For example `31.2 GiB`, `512 B`, or `n/a` for a bad value.
# @exitcode 0 Always.
_shell::system::stats::format_bytes() {
	local bytes="${1-}" unit="${2:-auto}" si="${3:-0}"
	if ! _shell::system::stats::uint "$bytes"; then
		SHELL_STATS_OUT="n/a"
		return "$RETURN_SUCCESS"
	fi
	bytes="$SHELL_STATS_OUT"

	local div=1 label="B" base=1024 i=0 tenths
	if [ "$unit" != "auto" ] && _shell::system::stats::unit_divisor "$unit"; then
		div="$SHELL_STATS_OUT"
		label="$unit"
	else
		[ "$si" = "1" ] && base=1000
		while [ "$i" -lt 5 ] && [ "$bytes" -ge $((div * base)) ]; do
			div=$((div * base))
			i=$((i + 1))
		done
		if [ "$si" = "1" ]; then
			case "$i" in
			0) label="B" ;; 1) label="KB" ;; 2) label="MB" ;; 3) label="GB" ;; 4) label="TB" ;; *) label="PB" ;;
			esac
		else
			case "$i" in
			0) label="B" ;; 1) label="KiB" ;; 2) label="MiB" ;; 3) label="GiB" ;; 4) label="TiB" ;; *) label="PiB" ;;
			esac
		fi
	fi

	if [ "$label" = "B" ]; then
		SHELL_STATS_OUT="$bytes B"
		return "$RETURN_SUCCESS"
	fi
	tenths=$(((bytes * 10 + div / 2) / div))
	SHELL_STATS_OUT="$((tenths / 10)).$((tenths % 10)) $label"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Integer percentage of `part` in `whole`, between 0 and 100.
#   A `whole` of 0 gives 0, never a division error.
# @arg $1 integer The part.
# @arg $2 integer The whole.
# @arg $3 string `round` (default, nearest) or `ceil` (what `df` prints).
# @set SHELL_STATS_OUT integer The percentage.
# @exitcode 0 Always.
_shell::system::stats::percent() {
	local part="${1:-0}" whole="${2:-0}" mode="${3:-round}" pct
	if [ "$whole" -le 0 ] || [ "$part" -le 0 ]; then
		SHELL_STATS_OUT=0
		return "$RETURN_SUCCESS"
	fi
	if [ "$mode" = "ceil" ]; then
		pct=$(((part * 100 + whole - 1) / whole))
	else
		pct=$(((part * 100 + whole / 2) / whole))
	fi
	[ "$pct" -gt 100 ] && pct=100
	SHELL_STATS_OUT="$pct"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Repeat a string.
# @arg $1 string The string.
# @arg $2 integer How many times.
# @set SHELL_STATS_OUT string The result (empty for 0).
# @exitcode 0 Always.
_shell::system::stats::repeat() {
	local piece="${1-}" n="${2:-0}" out=""
	while [ "$n" -gt 0 ]; do
		out="$out$piece"
		n=$((n - 1))
	done
	SHELL_STATS_OUT="$out"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Pad a text with spaces to a width, by characters (not bytes), so
#   non-ASCII mount names keep the columns aligned.
# @arg $1 string The text.
# @arg $2 integer Width.
# @arg $3 string `left` (text on the left, default) or `right`.
# @set SHELL_STATS_OUT string The padded text (never cut).
# @exitcode 0 Always.
_shell::system::stats::pad() {
	local text="${1-}" width="${2:-0}" side="${3:-left}" gap
	gap=$((width - ${#text}))
	[ "$gap" -lt 0 ] && gap=0
	_shell::system::stats::repeat " " "$gap"
	if [ "$side" = "right" ]; then
		SHELL_STATS_OUT="$SHELL_STATS_OUT$text"
	else
		SHELL_STATS_OUT="$text$SHELL_STATS_OUT"
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Cut a text to a width, ending in `...` when something was removed.
# @arg $1 string The text.
# @arg $2 integer Maximum width (at least 4).
# @set SHELL_STATS_OUT string The text, possibly shortened.
# @exitcode 0 Always.
_shell::system::stats::truncate() {
	local text="${1-}" width="${2:-0}"
	if [ "${#text}" -le "$width" ] || [ "$width" -lt 4 ]; then
		SHELL_STATS_OUT="$text"
	else
		SHELL_STATS_OUT="${text:0:$((width - 3))}..."
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Escape a text as the inside of a JSON string.
#   Backslash, quote, tab, newline and carriage return are escaped; other control
#   characters are dropped (they cannot appear in a path the tools report).
# @arg $1 string The text.
# @set SHELL_STATS_OUT string The escaped text, without the surrounding quotes.
# @exitcode 0 Always.
_shell::system::stats::json_escape() {
	local s="${1-}"
	s="${s//\\/\\\\}"
	s="${s//\"/\\\"}"
	s="${s//$'\t'/\\t}"
	s="${s//$'\n'/\\n}"
	s="${s//$'\r'/\\r}"
	SHELL_STATS_OUT="$s"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Read one value of a `/proc/meminfo` style text, in bytes.
#   The file reports kB (really KiB), so the value is multiplied by 1024.
# @arg $1 string The text.
# @arg $2 string The key, without the colon (for example `MemAvailable`).
# @set SHELL_STATS_OUT integer Bytes, empty when the key is absent or not a number.
# @exitcode 0 Found.
# @exitcode 1 Absent.
_shell::system::stats::meminfo::get() {
	local text="${1-}" key="${2-}" line val
	SHELL_STATS_OUT=""
	while IFS= read -r line; do
		case "$line" in
		"$key:"*)
			val="${line#*:}"
			val="${val#"${val%%[![:space:]]*}"}"
			val="${val%%[!0-9]*}"
			if _shell::system::stats::uint "$val"; then
				SHELL_STATS_OUT=$((SHELL_STATS_OUT * 1024))
				return "$RETURN_SUCCESS"
			fi
			SHELL_STATS_OUT=""
			return "$RETURN_FAILURE"
			;;
		esac
	done <<<"$text"
	return "$RETURN_FAILURE"
}

# @internal
# @description Parse the options shared by the public stats functions.
#   Results go to SHELL_STATS_OPT_UNIT (auto or a unit), SHELL_STATS_OPT_SI, SHELL_STATS_OPT_JSON
#   and SHELL_STATS_OPT_ALL (0 or 1).
# @arg $1 integer 1 when `--all` is accepted (the disk function), 0 otherwise.
# @arg $@ string The caller's arguments.
# @stderr The reason when an option is unknown or invalid.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, missing or invalid unit.
_shell::system::stats::options() {
	local allow_all="${1-0}"
	shift
	SHELL_STATS_OPT_UNIT="auto"
	SHELL_STATS_OPT_SI=0
	SHELL_STATS_OPT_JSON=0
	SHELL_STATS_OPT_ALL=0
	local value=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--json) SHELL_STATS_OPT_JSON=1 ;;
		--si) SHELL_STATS_OPT_SI=1 ;;
		--all)
			if [ "$allow_all" != "1" ]; then
				shell::logger::error "Unknown option: --all (only the disk statistics have it)"
				return "$RETURN_INVALID"
			fi
			SHELL_STATS_OPT_ALL=1
			;;
		--unit | --unit=*)
			case "$1" in
			--unit=*) value="${1#--unit=}" ;;
			*)
				if [ "$#" -lt 2 ]; then
					shell::logger::error "--unit needs a value (B, KiB, MiB, GiB, TiB, KB, MB, GB, TB)"
					return "$RETURN_INVALID"
				fi
				shift
				value="$1"
				;;
			esac
			if ! _shell::system::stats::unit_divisor "$value"; then
				shell::logger::error "Unknown unit '$value' (use B, KiB, MiB, GiB, TiB, KB, MB, GB, TB)"
				return "$RETURN_INVALID"
			fi
			SHELL_STATS_OPT_UNIT="$value"
			;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done
	return "$RETURN_SUCCESS"
}

# @internal
# @description Print the platform the statistics are collected for.
# @stdout `linux` or `macos`.
# @stderr The reason when the OS is not supported.
# @exitcode 0 Supported.
# @exitcode 4 Any other OS (Windows shells, unknown).
_shell::system::stats::platform() {
	local os
	os="$(shell::os::type)"
	case "$os" in
	linux | macos) printf '%s\n' "$os" ;;
	*)
		shell::logger::error "System statistics support Linux and macOS (this OS is: $os)"
		return "$RETURN_NOT_SUPPORTED"
		;;
	esac
}

# @internal
# @description Print a section title followed by an empty line.
#   The title goes through the console helper (coloured only on a terminal).
# @arg $1 string The title.
# @stdout The title and an empty line.
# @exitcode 0 Always.
_shell::system::stats::heading() {
	shell::console::print "${1-}" "$SHELL_COLOR_SECTION" -E
	printf '\n'
}

# @internal
# @description Print a horizontal rule between the sections of the overview.
# @stdout The rule.
# @exitcode 0 Always.
_shell::system::stats::rule() {
	_shell::system::stats::repeat "$SHELL_STATS_RULE_CHAR" "$SHELL_STATS_RULE_WIDTH"
	shell::console::print "$SHELL_STATS_OUT" "$SHELL_COLOR_SEPARATOR" -E
}

# @internal
# @description Print one `Label:   value` line of a memory or swap block.
# @arg $1 string The label, without the colon.
# @arg $2 string The value.
# @arg $3 integer Width of the value column (the value is right-aligned in it).
# @stdout The line.
# @exitcode 0 Always.
_shell::system::stats::kv() {
	local label="${1-}" value="${2-}" width="${3:-0}" head
	_shell::system::stats::pad "$label:" "$SHELL_STATS_LABEL_WIDTH" left
	head="$SHELL_STATS_OUT"
	_shell::system::stats::pad "$value" "$width" right
	printf '%s%s\n' "$head" "$SHELL_STATS_OUT"
}

# @internal
# @description Terminal width to fit a table in, or empty for "do not shorten".
#   SHELL_STATS_COLUMNS wins; otherwise `$COLUMNS` (default 80) when stdout is a terminal.
# @set SHELL_STATS_OUT integer The width or empty.
# @exitcode 0 Always.
_shell::system::stats::columns() {
	SHELL_STATS_OUT=""
	if [ -n "${SHELL_STATS_COLUMNS-}" ]; then
		_shell::system::stats::uint "$SHELL_STATS_COLUMNS" || SHELL_STATS_OUT=""
	elif [ -t 1 ]; then
		_shell::system::stats::uint "${COLUMNS:-80}" || SHELL_STATS_OUT=80
	fi
	return "$RETURN_SUCCESS"
}

# @description Show disk, memory and swap statistics together.
#   Prints a header with the platform and CPU architecture, then the three sections
#   (see `shell::system::stats::disk`, `::memory` and `::swap` for their rules). A section that
#   cannot be read does not stop the others: its reason goes to stderr and the exit code is
#   the first failure. With `--json` stdout holds one object and nothing else; a section
#   that failed is `null`.
#   Read-only: no root, no change to the system.
# @option -h | --help Show help and return.
# @option --unit Fixed unit for every size: B, KiB, MiB, GiB, TiB, KB, MB, GB or TB.
# @option --si Decimal units (KB, MB, GB) instead of binary (KiB, MiB, GiB) for automatic scaling.
# @option --json Machine-readable output (sizes in bytes, no decoration).
# @stdout The overview, or one JSON object.
# @stderr Warnings and errors.
# @exitcode 0 Success.
# @exitcode 2 Unknown option or invalid unit.
# @exitcode 4 Unsupported operating system.
# @exitcode 8 No filesystem matched (the other sections are still printed).
# @example
#   shell::system::stats::all
#   shell::system::stats::all --json
#
shell::system::stats::all() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show disk, memory and swap statistics together"
		shell::logger::usage "shell::system::stats::all [--unit <unit>] [--si] [--json]"
		shell::logger::option "--unit <unit>" "Fixed unit: B, KiB, MiB, GiB, TiB, KB, MB, GB, TB"
		shell::logger::option "--si" "Decimal units (KB, MB, GB) instead of binary (KiB, MiB, GiB)"
		shell::logger::option "--json" "Machine-readable output (sizes in bytes)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::system::stats::all"
		return "$RETURN_SUCCESS"
	fi

	_shell::system::stats::options 0 "$@" || return "$?"
	local platform rc=0 step=0
	platform="$(_shell::system::stats::platform)" || return "$?"

	local arch
	arch="$(shell::os::arch)"

	if [ "$SHELL_STATS_OPT_JSON" = "1" ]; then
		local frag disk="null" memory="null" swap="null"
		frag="$(_shell::system::stats::disk::emit "$platform")"
		step=$?
		if [ "$step" -eq 0 ] || [ "$step" -eq "$RETURN_EMPTY" ]; then disk="$frag"; fi
		[ "$step" -ne 0 ] && rc="$step"
		frag="$(_shell::system::stats::memory::emit "$platform")"
		step=$?
		if [ "$step" -eq 0 ]; then memory="$frag"; fi
		[ "$rc" -eq 0 ] && rc="$step"
		frag="$(_shell::system::stats::swap::emit "$platform")"
		step=$?
		if [ "$step" -eq 0 ]; then swap="$frag"; fi
		[ "$rc" -eq 0 ] && rc="$step"
		_shell::system::stats::json_escape "$arch"
		printf '{"platform":"%s","architecture":"%s","disk":%s,"memory":%s,"swap":%s}\n' \
			"$platform" "$SHELL_STATS_OUT" "$disk" "$memory" "$swap"
		return "$rc"
	fi

	local label="Linux"
	[ "$platform" = "macos" ] && label="macOS"
	_shell::system::stats::heading "SYSTEM RESOURCE OVERVIEW"
	printf 'Platform: %s\n' "$label"
	printf 'Architecture: %s\n\n' "$arch"

	_shell::system::stats::rule
	printf '\n'
	_shell::system::stats::disk::emit "$platform"
	rc=$?
	printf '\n'
	_shell::system::stats::rule
	printf '\n'
	_shell::system::stats::memory::emit "$platform"
	step=$?
	[ "$rc" -eq 0 ] && rc="$step"
	printf '\n'
	_shell::system::stats::rule
	printf '\n'
	_shell::system::stats::swap::emit "$platform"
	step=$?
	[ "$rc" -eq 0 ] && rc="$step"
	return "$rc"
}
