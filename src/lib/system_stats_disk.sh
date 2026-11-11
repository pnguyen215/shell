#!/usr/bin/env bash
# @file lib/system_stats_disk.sh
# @brief Disk usage of the mounted filesystems on Linux and macOS.
# @description
#   Sources
#     Linux   `df -P -k` for the sizes and `/proc/self/mounts` for the filesystem type
#             (octal escapes such as `\040` in a mount path are decoded). `lsblk` is not
#             used: it adds device metadata (model, rotational) that this table does not
#             show, and it may be absent.
#     macOS   `df -P -k` for the sizes and `mount` for the filesystem type.
#
#   What a row is
#     One row is one MOUNTED FILESYSTEM, not one physical disk. A disk can hold several
#     partitions and a partition can hold several volumes; the table never adds rows up,
#     so nothing is counted twice.
#     Total      the capacity `df` reports for the mounted filesystem.
#     Used       what `df` reports as used (see APFS below).
#     Free       what `df` reports as available to a normal user (it excludes blocks
#                reserved for root on ext4, so Used + Free can be less than Total).
#     Usage      Used / (Used + Free), rounded up, exactly the percentage `df` prints.
#
#   Default filter (use `--all` to turn it off)
#     - filesystem types listed in SHELL_STATS_PSEUDO_FS (proc, sysfs, tmpfs, overlay,
#       cgroup, squashfs ...) and filesystems of size 0 are hidden;
#     - when the type is unknown (unreadable /proc/self/mounts), only devices under /dev,
#       network shares (`//host/x`, `host:/x`) are kept;
#     - the same device with the same numbers mounted again (bind mounts, btrfs
#       subvolumes) is listed once, under its first mount point.
#
#   APFS (macOS)
#     Volumes of one APFS container share one pool of space: `df` reports the container
#     size as Total and the container's free space as Free for each of them, but Used per
#     volume. Adding or comparing those rows would count the same bytes many times. By
#     default the volumes of a container (`/dev/diskNsM...` with the same N) are shown as
#     ONE row, for the first volume `df` lists (normally `/`): Total = container size,
#     Free = container free space, Used = Total - Free (everything in the container, all
#     volumes and snapshots), Usage = Used / Total. `--all` prints every volume as `df`
#     reports it instead.
#
#   Limits
#     `df` is run once and can block on an unreachable network mount. A mount path with a
#     newline, or a device name with a space, is not supported.

# @internal
# @description Decode the octal escapes of a `/proc/self/mounts` path (`\040` space,
#   `\011` tab, `\012` newline, `\134` backslash).
# @arg $1 string The escaped path.
# @set SHELL_STATS_OUT string The path.
# @exitcode 0 Always.
_shell::system::stats::disk::unescape() {
	local s="${1-}" out="" rest code
	while :; do
		case "$s" in
		*\\*) ;;
		*) break ;;
		esac
		out="$out${s%%\\*}"
		rest="${s#*\\}"
		code="${rest:0:3}"
		case "$code" in
		040)
			out="$out "
			rest="${rest:3}"
			;;
		011)
			out="$out"$'\t'
			rest="${rest:3}"
			;;
		012)
			out="$out"$'\n'
			rest="${rest:3}"
			;;
		134)
			out="$out\\"
			rest="${rest:3}"
			;;
		*) out="$out\\" ;;
		esac
		s="$rest"
	done
	SHELL_STATS_OUT="$out$s"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Turn the text of `/proc/self/mounts` into a lookup table.
#   Every entry is `<newline><mount point><SEP><type>` (the newline starts an entry, so
#   an entry is found by an exact match and a prefix of another path never matches).
# @arg $1 string The text of the mounts file.
# @stdout The table (no trailing newline).
# @exitcode 0 Always.
_shell::system::stats::disk::table_linux() {
	local line mdev mnt fstype rest
	while IFS= read -r line; do
		read -r mdev mnt fstype rest <<<"$line"
		[ -n "$mnt" ] && [ -n "$fstype" ] || continue
		_shell::system::stats::disk::unescape "$mnt"
		printf '\n%s%s%s' "$SHELL_STATS_OUT" "$SHELL_STATS_SEP" "$fstype"
	done <<<"${1-}"
}

# @internal
# @description Turn the output of macOS `mount` into the same lookup table.
#   A line is `<device> on <mount point> (<type>, <option>, ...)`; the mount point is
#   everything between ` on ` and the LAST ` (`, so names with spaces or parentheses work.
# @arg $1 string The output of `mount`.
# @stdout The table (no trailing newline).
# @exitcode 0 Always.
_shell::system::stats::disk::table_macos() {
	local line rest mnt opts fstype
	while IFS= read -r line; do
		case "$line" in
		*" on "*" ("*) ;;
		*) continue ;;
		esac
		rest="${line#* on }"
		mnt="${rest%" ("*}"
		opts="${rest##*" ("}"
		fstype="${opts%%[,)]*}"
		[ -n "$mnt" ] && [ -n "$fstype" ] || continue
		printf '\n%s%s%s' "$mnt" "$SHELL_STATS_SEP" "$fstype"
	done <<<"${1-}"
}

# @internal
# @description Look up the filesystem type of a mount point in a table.
#   When a path is mounted more than once the last (topmost) mount wins.
# @arg $1 string The table.
# @arg $2 string The mount point.
# @set SHELL_STATS_OUT string The type, empty when unknown.
# @exitcode 0 Found.
# @exitcode 1 Not found.
_shell::system::stats::disk::lookup() {
	local table="${1-}" mnt="${2-}" nl=$'\n' rest
	SHELL_STATS_OUT=""
	case "$table" in
	*"$nl$mnt$SHELL_STATS_SEP"*)
		rest="${table##*"$nl$mnt$SHELL_STATS_SEP"}"
		SHELL_STATS_OUT="${rest%%"$nl"*}"
		return "$RETURN_SUCCESS"
		;;
	esac
	return "$RETURN_FAILURE"
}

# @internal
# @description Parse `df -P -k` output into records `device SEP mount SEP total SEP used SEP avail`
#   (bytes). The header and every line whose size columns are not numbers are skipped.
# @arg $1 string The output of `df -P -k`.
# @stdout One record per filesystem.
# @exitcode 0 Always.
_shell::system::stats::disk::parse_df() {
	local line dev blocks used avail cap mnt
	while IFS= read -r line; do
		read -r dev blocks used avail cap mnt <<<"$line"
		[ -n "$mnt" ] || continue
		_shell::system::stats::uint "$blocks" || continue
		blocks="$SHELL_STATS_OUT"
		_shell::system::stats::uint "$used" || continue
		used="$SHELL_STATS_OUT"
		_shell::system::stats::uint "$avail" || continue
		avail="$SHELL_STATS_OUT"
		printf '%s%s%s%s%s%s%s%s%s\n' "$dev" "$SHELL_STATS_SEP" "$mnt" "$SHELL_STATS_SEP" \
			"$((blocks * 1024))" "$SHELL_STATS_SEP" "$((used * 1024))" "$SHELL_STATS_SEP" "$((avail * 1024))"
	done <<<"${1-}"
}

# @internal
# @description Apply the default filter and the APFS rule to the `df` records (see the file header).
# @arg $1 integer 1 to keep every row as `df` reports it (`--all`), 0 to filter.
# @arg $2 string The records of `parse_df`.
# @arg $3 string The lookup table of the mount types.
# @stdout Records `device SEP mount SEP type SEP total SEP used SEP avail`, bytes.
# @exitcode 0 Always.
_shell::system::stats::disk::select() {
	local include_all="${1-0}" records="${2-}" table="${3-}"
	local sep="$SHELL_STATS_SEP" nl=$'\n' seen=$'\n'
	local dev mnt total used avail fstype name base key
	while IFS="$sep" read -r dev mnt total used avail; do
		[ -n "$dev" ] || continue
		fstype=""
		_shell::system::stats::disk::lookup "$table" "$mnt" && fstype="$SHELL_STATS_OUT"
		if [ "$include_all" != "1" ]; then
			[ "$total" -gt 0 ] || continue
			if [ -n "$fstype" ]; then
				case " $SHELL_STATS_PSEUDO_FS " in
				*" $fstype "*) continue ;;
				esac
			else
				case "$dev" in
				/dev/* | //* | *:*) ;;
				*) continue ;;
				esac
			fi
			if [ "$fstype" = "apfs" ]; then
				name="${dev#/dev/}"
				base="${name%%s[0-9]*}"
				key="apfs:$base"
				used=$((total - avail))
				[ "$used" -lt 0 ] && used=0
			else
				key="$dev|$total|$used|$avail"
			fi
			case "$seen" in
			*"$nl$key$nl"*) continue ;;
			esac
			seen="$seen$key$nl"
		fi
		printf '%s%s%s%s%s%s%s%s%s%s%s\n' "$dev" "$sep" "$mnt" "$sep" "$fstype" "$sep" "$total" "$sep" "$used" "$sep" "$avail"
	done <<<"$records"
}

# @internal
# @description Collect the disk records on Linux.
# @arg $1 integer 1 for `--all`, 0 for the default filter.
# @stdout The records of `select`.
# @stderr The reason when `df` is missing or prints nothing.
# @exitcode 0 Success.
# @exitcode 1 `df` printed nothing.
# @exitcode 3 `df` is not installed.
# @exitcode 8 No filesystem matched.
_shell::system::stats::disk::linux() {
	local include_all="${1-0}" df_out mounts="" table records
	if ! command -v df >/dev/null 2>&1; then
		shell::logger::error "df is not installed"
		return "$RETURN_NOT_FOUND"
	fi
	df_out="$(df -P -k 2>/dev/null)"
	if [ -z "$df_out" ]; then
		shell::logger::error "df printed no filesystem"
		return "$RETURN_FAILURE"
	fi
	if [ -r "$SHELL_STATS_PROC_MOUNTS" ]; then
		mounts="$(cat "$SHELL_STATS_PROC_MOUNTS" 2>/dev/null)"
	fi
	table="$(_shell::system::stats::disk::table_linux "$mounts")"
	records="$(_shell::system::stats::disk::parse_df "$df_out")"
	records="$(_shell::system::stats::disk::select "$include_all" "$records" "$table")"
	[ -n "$records" ] && printf '%s\n' "$records"
	[ -n "$records" ] || return "$RETURN_EMPTY"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Collect the disk records on macOS.
# @arg $1 integer 1 for `--all`, 0 for the default filter.
# @stdout The records of `select`.
# @stderr The reason when `df` is missing or prints nothing.
# @exitcode 0 Success.
# @exitcode 1 `df` printed nothing.
# @exitcode 3 `df` is not installed.
# @exitcode 8 No filesystem matched.
_shell::system::stats::disk::macos() {
	local include_all="${1-0}" df_out mounts="" table records
	if ! command -v df >/dev/null 2>&1; then
		shell::logger::error "df is not installed"
		return "$RETURN_NOT_FOUND"
	fi
	df_out="$(df -P -k 2>/dev/null)"
	if [ -z "$df_out" ]; then
		shell::logger::error "df printed no filesystem"
		return "$RETURN_FAILURE"
	fi
	if command -v mount >/dev/null 2>&1; then
		mounts="$(mount 2>/dev/null)"
	fi
	table="$(_shell::system::stats::disk::table_macos "$mounts")"
	records="$(_shell::system::stats::disk::parse_df "$df_out")"
	records="$(_shell::system::stats::disk::select "$include_all" "$records" "$table")"
	[ -n "$records" ] && printf '%s\n' "$records"
	[ -n "$records" ] || return "$RETURN_EMPTY"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Print one line of the disk table.
# @arg $1 string The seven cells, joined by SHELL_STATS_SEP.
# @arg $2 string The seven column widths, joined by SHELL_STATS_SEP.
# @stdout The line (cells longer than their column end in `...`).
# @exitcode 0 Always.
_shell::system::stats::disk::line() {
	local sep="$SHELL_STATS_SEP" c1 c2 c3 c4 c5 c6 c7 w1 w2 w3 w4 w5 w6 w7 out
	IFS="$sep" read -r c1 c2 c3 c4 c5 c6 c7 <<<"$1"
	IFS="$sep" read -r w1 w2 w3 w4 w5 w6 w7 <<<"$2"
	_shell::system::stats::truncate "$c1" "$w1"
	_shell::system::stats::pad "$SHELL_STATS_OUT" "$w1" left
	out="$SHELL_STATS_OUT  "
	_shell::system::stats::truncate "$c2" "$w2"
	_shell::system::stats::pad "$SHELL_STATS_OUT" "$w2" left
	out="$out$SHELL_STATS_OUT  "
	_shell::system::stats::pad "$c3" "$w3" left
	out="$out$SHELL_STATS_OUT  "
	_shell::system::stats::pad "$c4" "$w4" right
	out="$out$SHELL_STATS_OUT  "
	_shell::system::stats::pad "$c5" "$w5" right
	out="$out$SHELL_STATS_OUT  "
	_shell::system::stats::pad "$c6" "$w6" right
	out="$out$SHELL_STATS_OUT  "
	_shell::system::stats::pad "$c7" "$w7" right
	printf '%s%s\n' "$out" "$SHELL_STATS_OUT"
}

# @internal
# @description Print the disk section as an aligned table.
#   Uses SHELL_STATS_OPT_UNIT and SHELL_STATS_OPT_SI for the sizes.
# @arg $1 string The records of `select` (may be empty).
# @stdout The title and the table, or `No filesystems found.`.
# @exitcode 0 Always.
_shell::system::stats::disk::render() {
	local records="${1-}" sep="$SHELL_STATS_SEP" nl=$'\n'
	_shell::system::stats::heading "DISK STORAGE"
	if [ -z "$records" ]; then
		printf 'No filesystems found.\n'
		return "$RETURN_SUCCESS"
	fi

	local rows="" dev mnt fstype total used avail t u f pct
	local w1=6 w2=11 w3=4 w4=5 w5=4 w6=4 w7=5
	while IFS="$sep" read -r dev mnt fstype total used avail; do
		[ -n "$dev" ] || continue
		_shell::system::stats::format_bytes "$total" "$SHELL_STATS_OPT_UNIT" "$SHELL_STATS_OPT_SI"
		t="$SHELL_STATS_OUT"
		_shell::system::stats::format_bytes "$used" "$SHELL_STATS_OPT_UNIT" "$SHELL_STATS_OPT_SI"
		u="$SHELL_STATS_OUT"
		_shell::system::stats::format_bytes "$avail" "$SHELL_STATS_OPT_UNIT" "$SHELL_STATS_OPT_SI"
		f="$SHELL_STATS_OUT"
		_shell::system::stats::percent "$used" "$((used + avail))" ceil
		pct="$SHELL_STATS_OUT%"
		[ -n "$fstype" ] || fstype="-"
		rows="$rows$dev$sep$mnt$sep$fstype$sep$t$sep$u$sep$f$sep$pct$nl"
		[ "${#dev}" -gt "$w1" ] && w1="${#dev}"
		[ "${#mnt}" -gt "$w2" ] && w2="${#mnt}"
		[ "${#fstype}" -gt "$w3" ] && w3="${#fstype}"
		[ "${#t}" -gt "$w4" ] && w4="${#t}"
		[ "${#u}" -gt "$w5" ] && w5="${#u}"
		[ "${#f}" -gt "$w6" ] && w6="${#f}"
		[ "${#pct}" -gt "$w7" ] && w7="${#pct}"
	done <<<"$records"

	# Fit the terminal: shorten the mount point first, then the device.
	local cols table_w excess cut
	_shell::system::stats::columns
	cols="$SHELL_STATS_OUT"
	table_w=$((w1 + w2 + w3 + w4 + w5 + w6 + w7 + 12))
	if [ -n "$cols" ] && [ "$table_w" -gt "$cols" ]; then
		excess=$((table_w - cols))
		cut=$((w2 - SHELL_STATS_MIN_CELL))
		[ "$cut" -lt 0 ] && cut=0
		[ "$cut" -gt "$excess" ] && cut="$excess"
		w2=$((w2 - cut))
		excess=$((excess - cut))
		cut=$((w1 - SHELL_STATS_MIN_CELL))
		[ "$cut" -lt 0 ] && cut=0
		[ "$cut" -gt "$excess" ] && cut="$excess"
		w1=$((w1 - cut))
	fi

	local widths="$w1$sep$w2$sep$w3$sep$w4$sep$w5$sep$w6$sep$w7" row
	_shell::system::stats::disk::line "Device${sep}Mount Point${sep}Type${sep}Total${sep}Used${sep}Free${sep}Usage" "$widths"
	while IFS= read -r row; do
		[ -n "$row" ] || continue
		_shell::system::stats::disk::line "$row" "$widths"
	done <<<"$rows"
}

# @internal
# @description Print the disk records as a JSON array (sizes in bytes).
# @arg $1 string The records of `select` (may be empty).
# @stdout `[{"device":...,"mount":...,"type":...,"total":N,"used":N,"free":N,"usage":N}, ...]`.
# @exitcode 0 Always.
_shell::system::stats::disk::json() {
	local records="${1-}" sep="$SHELL_STATS_SEP" out="[" first=1
	local dev mnt fstype total used avail d m t pct
	while IFS="$sep" read -r dev mnt fstype total used avail; do
		[ -n "$dev" ] || continue
		_shell::system::stats::json_escape "$dev"
		d="$SHELL_STATS_OUT"
		_shell::system::stats::json_escape "$mnt"
		m="$SHELL_STATS_OUT"
		_shell::system::stats::json_escape "$fstype"
		t="$SHELL_STATS_OUT"
		_shell::system::stats::percent "$used" "$((used + avail))" ceil
		pct="$SHELL_STATS_OUT"
		[ "$first" = 1 ] || out="$out,"
		first=0
		out="$out{\"device\":\"$d\",\"mount\":\"$m\",\"type\":\"$t\",\"total\":$total,\"used\":$used,\"free\":$avail,\"usage\":$pct}"
	done <<<"$records"
	printf '%s]\n' "$out"
}

# @internal
# @description Collect and print the disk section in the selected output mode.
# @arg $1 string The platform: linux or macos.
# @stdout The table or the JSON array.
# @stderr A warning when no filesystem matched.
# @exitcode 0 Success.
# @exitcode 1 `df` printed nothing.
# @exitcode 3 `df` is not installed.
# @exitcode 8 No filesystem matched (an empty section is still printed).
_shell::system::stats::disk::emit() {
	local records rc
	records="$("_shell::system::stats::disk::$1" "$SHELL_STATS_OPT_ALL")"
	rc=$?
	if [ "$rc" -ne 0 ] && [ "$rc" -ne "$RETURN_EMPTY" ]; then
		return "$rc"
	fi
	[ "$rc" -eq "$RETURN_EMPTY" ] && shell::logger::warn "No mounted filesystem matched (--all also lists pseudo filesystems)"
	if [ "$SHELL_STATS_OPT_JSON" = "1" ]; then
		_shell::system::stats::disk::json "$records"
	else
		_shell::system::stats::disk::render "$records"
	fi
	return "$rc"
}

# @description Show the usage of the mounted filesystems (device, mount point, type, total, used, free, usage).
#   Linux reads `df` and `/proc/self/mounts`, macOS reads `df` and `mount`; nothing needs root
#   and nothing is changed. One row is one mounted filesystem: sizes are never added up, and the
#   volumes of one APFS container are shown as one row so the shared space is not counted twice.
#   Pseudo filesystems (tmpfs, proc, overlay ...), empty ones and repeated mounts of the same
#   device are hidden unless `--all` is given. Usage is rounded up like `df`.
#   Sizes are binary (KiB, MiB, GiB, TiB) unless `--si` or a fixed `--unit` says otherwise.
# @option -h | --help Show help and return.
# @option --all List every filesystem `df` reports, one row each, without filtering.
# @option --unit Fixed unit for every size: B, KiB, MiB, GiB, TiB, KB, MB, GB or TB.
# @option --si Decimal units (KB, MB, GB) instead of binary (KiB, MiB, GiB) for automatic scaling.
# @option --json Machine-readable output (sizes in bytes, no decoration).
# @stdout The table, or a JSON array.
# @stderr Warnings and errors.
# @exitcode 0 Success.
# @exitcode 1 `df` printed nothing.
# @exitcode 2 Unknown option or invalid unit.
# @exitcode 3 `df` is not installed.
# @exitcode 4 Unsupported operating system.
# @exitcode 8 No filesystem matched (an empty section is still printed).
# @example
#   shell::system::stats::disk
#   shell::system::stats::disk --all --unit GiB
#   shell::system::stats::disk --json
#
shell::system::stats::disk() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show the usage of the mounted filesystems"
		shell::logger::usage "shell::system::stats::disk [--all] [--unit <unit>] [--si] [--json]"
		shell::logger::option "--all" "Include pseudo filesystems and every APFS volume"
		shell::logger::option "--unit <unit>" "Fixed unit: B, KiB, MiB, GiB, TiB, KB, MB, GB, TB"
		shell::logger::option "--si" "Decimal units (KB, MB, GB) instead of binary (KiB, MiB, GiB)"
		shell::logger::option "--json" "Machine-readable output (sizes in bytes)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::system::stats::disk --unit GiB"
		return "$RETURN_SUCCESS"
	fi

	_shell::system::stats::options 1 "$@" || return "$?"
	local platform
	platform="$(_shell::system::stats::platform)" || return "$?"
	_shell::system::stats::disk::emit "$platform"
}
