#!/usr/bin/env bash
# shell::system::stats::* (src/lib/system_stats*.sh, src/constant/stats.sh).
#
# Both platforms are tested on any host: SHELL_OS_TYPE picks the platform, the files read from /proc
# are fixtures (SHELL_STATS_PROC_*), and df, mount, sysctl and vm_stat are shell functions that print
# a fixture. Nothing here reads or changes the real disks, swap or memory.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

SEP=$'\037'
NL=$'\n'
GIB=1073741824

# --- mocks: the "commands" print what the test put in these variables
MOCK_DF=""
MOCK_MOUNT=""
MOCK_MEMSIZE=""
MOCK_VMSTAT=""
MOCK_SWAPUSAGE=""
df() { printf '%s\n' "$MOCK_DF"; }
mount() { printf '%s\n' "$MOCK_MOUNT"; }
vm_stat() { printf '%s\n' "$MOCK_VMSTAT"; }
sysctl() {
	case "$*" in
	"-n hw.memsize") printf '%s\n' "$MOCK_MEMSIZE" ;;
	"-n vm.swapusage") printf '%s\n' "$MOCK_SWAPUSAGE" ;;
	*) return 1 ;;
	esac
}
# Commands the library must never run: they leave a trace when called.
swapon() { : >"$HOME/swapon.called"; }
lsblk() { : >"$HOME/lsblk.called"; }

linux() {
	SHELL_OS_TYPE=linux
	SHELL_STATS_PROC_MEMINFO="$HOME/meminfo"
	SHELL_STATS_PROC_MOUNTS="$HOME/mounts"
	SHELL_STATS_PROC_SWAPS="$HOME/swaps"
	SHELL_STATS_COLUMNS=""
}
macos() {
	SHELL_OS_TYPE=macos
	SHELL_STATS_PROC_MEMINFO="$HOME/none/meminfo"
	SHELL_STATS_PROC_MOUNTS="$HOME/none/mounts"
	SHELL_STATS_PROC_SWAPS="$HOME/none/swaps"
	SHELL_STATS_COLUMNS=""
}

# --- fixtures: Linux
MEMINFO_32G='MemTotal:       33554432 kB
MemFree:          4194304 kB
MemAvailable:    14680064 kB
Buffers:           512000 kB
Cached:           8192000 kB
SwapCached:         10240 kB
SReclaimable:      409600 kB
Shmem:             307200 kB
SwapTotal:        8388608 kB
SwapFree:         6291456 kB'

DF_LINUX='Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/nvme0n1p2   488378644 312000000 151000000      68% /
tmpfs              8000000         0   8000000       0% /dev/shm
/dev/sda1        976762584 585000000 391000000      60% /mnt/data
/dev/sdb1         15000000   2000000  13000000      14% /media/usb/My Disk
overlay          100000000  50000000  50000000      50% /var/lib/docker/overlay2/x/merged
/dev/loop0              60        60         0     100% /snap/core/1
/dev/nvme0n1p2   488378644 312000000 151000000      68% /var/lib/bind'

MOUNTS_LINUX='/dev/nvme0n1p2 / ext4 rw,relatime 0 0
tmpfs /dev/shm tmpfs rw,nosuid 0 0
/dev/sda1 /mnt/data xfs rw 0 0
/dev/sdb1 /media/usb/My\040Disk vfat rw 0 0
overlay /var/lib/docker/overlay2/x/merged overlay rw 0 0
/dev/loop0 /snap/core/1 squashfs ro 0 0
/dev/nvme0n1p2 /var/lib/bind ext4 rw 0 0
proc /proc proc rw 0 0'

# --- fixtures: macOS (a system container disk3, an external APFS drive, two FAT volumes of one stick)
DF_MAC='Filesystem     1024-blocks      Used Available Capacity  Mounted on
/dev/disk3s1s1   488245288  15000000 300000000     5%    /
devfs                  200       200         0   100%    /dev
/dev/disk3s6     488245288   6000000 300000000     2%    /System/Volumes/VM
/dev/disk3s5     488245288 170000000 300000000    37%    /System/Volumes/Data
map auto_home            0         0         0   100%    /System/Volumes/Data/home
/dev/disk5s1     244000000   1000000 243000000     1%    /Volumes/Ext Drive (1)
/dev/disk6s1      30000000  10000000  20000000    34%    /Volumes/USB STICK
/dev/disk6s2      10000000   1000000   9000000    10%    /Volumes/USB TWO'

MOUNT_MAC='/dev/disk3s1s1 on / (apfs, sealed, local, read-only, journaled)
devfs on /dev (devfs, local, nobrowse)
/dev/disk3s6 on /System/Volumes/VM (apfs, local, noexec, journaled, noatime, nobrowse)
/dev/disk3s5 on /System/Volumes/Data (apfs, local, journaled, nobrowse, protect, root data)
map auto_home on /System/Volumes/Data/home (autofs, automounted, nobrowse)
/dev/disk5s1 on /Volumes/Ext Drive (1) (apfs, local, journaled)
/dev/disk6s1 on /Volumes/USB STICK (msdos, local, nodev, nosuid, noowners)
/dev/disk6s2 on /Volumes/USB TWO (msdos, local, nodev, nosuid, noowners)'

VMSTAT_16K='Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                               4096.
Pages active:                           300000.
Pages inactive:                         250000.
Pages speculative:                        2000.
Pages throttled:                             0.
Pages wired down:                       100000.
Pages purgeable:                         10000.
"Translation faults":                123456789.
Pages copy-on-write:                   1000000.
Pages zero filled:                    50000000.
File-backed pages:                      150000.
Anonymous pages:                        400000.
Pages stored in compressor:             300000.
Pages occupied by compressor:           120000.'

# ======================================================================================
# helpers: bytes, percent, units, JSON, options
# ======================================================================================
fmt() {
	_shell::system::stats::format_bytes "$@"
	printf '%s' "$SHELL_STATS_OUT"
}
t_eq "format: zero bytes" "0 B" "$(fmt 0)"
t_eq "format: below 1 KiB" "1023 B" "$(fmt 1023)"
t_eq "format: 1 KiB" "1.0 KiB" "$(fmt 1024)"
t_eq "format: 1.5 KiB" "1.5 KiB" "$(fmt 1536)"
t_eq "format: 32 GiB" "32.0 GiB" "$(fmt $((32 * GIB)))"
t_eq "format: TiB" "4.0 TiB" "$(fmt 4398046511104)"
t_eq "format: si 1000 B is 1.0 KB" "1.0 KB" "$(fmt 1000 auto 1)"
t_eq "format: si never says KiB" "1.5 GB" "$(fmt 1500000000 auto 1)"
t_eq "format: fixed GiB" "0.5 GiB" "$(fmt 536870912 GiB)"
t_eq "format: fixed MB (decimal)" "1.5 MB" "$(fmt 1500000 MB)"
t_eq "format: fixed B" "2048 B" "$(fmt 2048 B)"
t_eq "format: not a number" "n/a" "$(fmt abc)"
t_eq "format: empty" "n/a" "$(fmt '')"

pc() {
	_shell::system::stats::percent "$@"
	printf '%s' "$SHELL_STATS_OUT"
}
t_eq "percent: zero whole" "0" "$(pc 5 0)"
t_eq "percent: zero part" "0" "$(pc 0 100)"
t_eq "percent: rounds to nearest" "56" "$(pc 18 32)"
t_eq "percent: rounds half up" "13" "$(pc 1 8)"
t_eq "percent: ceil like df" "60" "$(pc 585 976 ceil)"
t_eq "percent: capped at 100" "100" "$(pc 150 100)"

je() {
	_shell::system::stats::json_escape "$1"
	printf '%s' "$SHELL_STATS_OUT"
}
t_eq "json_escape: quote and backslash" 'a\"b\\c' "$(je 'a"b\c')"
t_eq "json_escape: tab and newline" 'a\tb\nc' "$(je $'a\tb\nc')"

ue() {
	_shell::system::stats::disk::unescape "$1"
	printf '%s' "$SHELL_STATS_OUT"
}
t_eq "unescape: space" "/media/My Disk" "$(ue '/media/My\040Disk')"
t_eq "unescape: backslash then digits stays a backslash" '/a\040' "$(ue '/a\134040')"
t_eq "unescape: unknown escape is kept" '/a\777b' "$(ue '/a\777b')"
t_eq "unescape: plain path" "/mnt/data" "$(ue '/mnt/data')"

t_rc "options: unknown unit" 2 _shell::system::stats::options 0 --unit XB
t_has "options: unknown unit names the choices" "GiB" "$T_OUT"
t_rc "options: --unit without value" 2 _shell::system::stats::options 0 --unit
t_rc "options: unknown option" 2 _shell::system::stats::options 0 --bogus
t_rc "options: --all refused outside disk" 2 _shell::system::stats::options 0 --all
t_rc "options: --all accepted for disk" 0 _shell::system::stats::options 1 --all
_shell::system::stats::options 1 --unit=MiB --si --json --all
t_eq "options: --unit=VALUE" "MiB" "$SHELL_STATS_OPT_UNIT"
t_eq "options: flags set" "1 1 1" "$SHELL_STATS_OPT_SI $SHELL_STATS_OPT_JSON $SHELL_STATS_OPT_ALL"

# ======================================================================================
# disk: Linux
# ======================================================================================
linux
printf '%s\n' "$MOUNTS_LINUX" >"$HOME/mounts"
MOCK_DF="$DF_LINUX"
NV=$((488378644 * 1024))
rec="$(_shell::system::stats::disk::linux 0)"
t_eq "disk linux: default keeps 3 filesystems" "3" "$(printf '%s\n' "$rec" | wc -l | tr -d ' ')"
t_has "disk linux: root (device, mount, type, total, used, avail)" "/dev/nvme0n1p2${SEP}/${SEP}ext4${SEP}${NV}${SEP}$((312000000 * 1024))${SEP}$((151000000 * 1024))" "$rec"
t_has "disk linux: second disk" "/dev/sda1${SEP}/mnt/data${SEP}xfs${SEP}" "$rec"
t_has "disk linux: mount path with a space, type from the escaped mounts file" "/dev/sdb1${SEP}/media/usb/My Disk${SEP}vfat${SEP}" "$rec"
t_lacks "disk linux: tmpfs filtered" "tmpfs" "$rec"
t_lacks "disk linux: overlay filtered" "overlay" "$rec"
t_lacks "disk linux: squashfs filtered" "squashfs" "$rec"
t_lacks "disk linux: bind mount of the same device listed once" "/var/lib/bind" "$rec"
rec_all="$(_shell::system::stats::disk::linux 1)"
t_eq "disk linux --all: every df row" "7" "$(printf '%s\n' "$rec_all" | wc -l | tr -d ' ')"
t_has "disk linux --all: tmpfs back" "tmpfs${SEP}/dev/shm${SEP}tmpfs" "$rec_all"
t_has "disk linux --all: bind mount back" "/var/lib/bind" "$rec_all"

out="$(shell::system::stats::disk --unit GiB 2>&1)"
t_has "disk: title" "DISK STORAGE" "$out"
t_has "disk: header" "Device" "$out"
t_has "disk: header has Mount Point and Usage" "Mount Point" "$out"
t_has "disk: usage is rounded up like df (312/463 -> 68%)" "68%" "$out"
t_has "disk: usage 60%" "60%" "$out"
t_has "disk: fixed unit in every size" "GiB" "$out"
t_lacks "disk: no MiB with --unit GiB" "MiB" "$out"
t_has "disk: path with a space shown whole" "/media/usb/My Disk" "$out"
out="$(shell::system::stats::disk --si 2>&1)"
t_has "disk --si: decimal units" "GB" "$out"
t_lacks "disk --si: no binary units" "GiB" "$out"
out="$(shell::system::stats::disk 2>&1)"
t_has "disk default: binary units, labelled" "GiB" "$out"

# columns line up: every row of the table has the same length
width_of_rows() {
	local line first="" bad=0
	while IFS= read -r line; do
		case "$line" in "" | "DISK STORAGE") continue ;; esac
		if [ -z "$first" ]; then first="${#line}"; elif [ "${#line}" -ne "$first" ]; then bad=1; fi
	done <<<"$1"
	printf '%s' "$bad"
}
t_eq "disk: columns aligned (same row length)" "0" "$(width_of_rows "$(shell::system::stats::disk 2>/dev/null)")"

# terminal width: long mount points are shortened, never the numbers
MOCK_DF='Filesystem 1024-blocks Used Available Capacity Mounted on
/dev/sda1 1000000 500000 500000 50% /mnt/a/very/long/mount/point/name/that/does/not/fit
/dev/sdb1 1000000 500000 500000 50% /mnt/b'
printf '/dev/sda1 /mnt/a/very/long/mount/point/name/that/does/not/fit ext4 rw 0 0\n/dev/sdb1 /mnt/b ext4 rw 0 0\n' >"$HOME/mounts"
SHELL_STATS_COLUMNS=70
out="$(shell::system::stats::disk 2>/dev/null)"
t_has "disk narrow terminal: shortened with ..." "..." "$out"
t_eq "disk narrow terminal: rows fit the width" "1" "$(
	ok=1
	while IFS= read -r l; do [ "${#l}" -le 70 ] || ok=0; done <<<"$out"
	echo $ok
)"
t_has "disk narrow terminal: numbers intact" "488.3 MiB" "$out"
SHELL_STATS_COLUMNS=""
out="$(shell::system::stats::disk 2>/dev/null)"
t_has "disk piped output: nothing shortened" "/mnt/a/very/long/mount/point/name/that/does/not/fit" "$out"

# edge cases
MOCK_DF=""
t_rc "disk: df prints nothing" 1 shell::system::stats::disk
t_eq "disk: df prints nothing -> stdout stays empty" "" "$(shell::system::stats::disk 2>/dev/null)"
MOCK_DF='Filesystem 1024-blocks Used Available Capacity Mounted on
this line is not a filesystem
/dev/x abc def ghi 1% /bad'
printf '/dev/x /bad ext4 rw 0 0\n' >"$HOME/mounts"
t_rc "disk: malformed df lines are skipped, nothing left -> 8" 8 shell::system::stats::disk
t_has "disk: empty section is still titled" "No filesystems found." "$(shell::system::stats::disk 2>/dev/null)"
MOCK_DF='Filesystem 1024-blocks Used Available Capacity Mounted on
/dev/zero1 0 0 0 0% /zero
/dev/full1 1000 1000 0 100% /full'
printf '/dev/zero1 /zero ext4 rw 0 0\n/dev/full1 /full ext4 rw 0 0\n' >"$HOME/mounts"
t_lacks "disk: zero-size filesystem hidden by default" "/zero" "$(shell::system::stats::disk 2>/dev/null)"
out="$(shell::system::stats::disk --all 2>/dev/null)"
t_has "disk --all: zero-size filesystem shown with 0%" "0%" "$out"
t_has "disk: no free space is 100%" "100%" "$out"

# unreadable /proc/self/mounts: no type, devices under /dev and network shares are kept, lsblk is not needed
rm -f "$HOME/mounts"
MOCK_DF='Filesystem 1024-blocks Used Available Capacity Mounted on
/dev/sda1 1000000 500000 500000 50% /
tmpfs 1000 0 1000 0% /run
nas:/export 2000000 1000000 1000000 50% /mnt/nas
//srv/share 3000000 1000000 2000000 33% /mnt/smb'
rec="$(_shell::system::stats::disk::linux 0)"
t_has "disk no mounts file: block device kept" "/dev/sda1${SEP}/${SEP}${SEP}" "$rec"
t_has "disk no mounts file: nfs kept" "nas:/export" "$rec"
t_has "disk no mounts file: smb kept" "//srv/share" "$rec"
t_lacks "disk no mounts file: tmpfs dropped" "tmpfs" "$rec"
t_rc "disk no mounts file: still succeeds" 0 shell::system::stats::disk
t_rc "disk: lsblk was never called" 1 test -e "$HOME/lsblk.called"

# JSON
printf '/dev/sdb1 /media/usb/My\\040Disk vfat rw 0 0\n' >"$HOME/mounts"
MOCK_DF='Filesystem 1024-blocks Used Available Capacity Mounted on
/dev/sdb1 15000000 2000000 13000000 14% /media/usb/My Disk'
out="$(shell::system::stats::disk --json 2>/dev/null)"
t_eq "disk --json: exact object" '[{"device":"/dev/sdb1","mount":"/media/usb/My Disk","type":"vfat","total":15360000000,"used":2048000000,"free":13312000000,"usage":14}]' "$out"
MOCK_DF='Filesystem 1024-blocks Used Available Capacity Mounted on
/dev/sdb1 15000000 2000000 13000000 14% /media/usb/Say "hi"\x'
t_has "disk --json: quotes and backslashes escaped" '"mount":"/media/usb/Say \"hi\"\\x"' "$(shell::system::stats::disk --json --all 2>/dev/null)"
MOCK_DF=""
t_eq "disk --json: nothing printed on failure" "" "$(shell::system::stats::disk --json 2>/dev/null)"
MOCK_DF='Filesystem 1024-blocks Used Available Capacity Mounted on
/dev/x abc def ghi 1% /bad'
t_eq "disk --json: empty result is []" "[]" "$(shell::system::stats::disk --json 2>/dev/null)"

# non-ASCII names stay aligned
MOCK_DF='Filesystem 1024-blocks Used Available Capacity Mounted on
/dev/sda1 1000000 500000 500000 50% /
/dev/sdb1 2000000 500000 1500000 25% /Volumes/Dữ liệu'
printf '/dev/sda1 / ext4 rw 0 0\n/dev/sdb1 /Volumes/Dữ\\040liệu ext4 rw 0 0\n' >"$HOME/mounts"
t_eq "disk: non-ASCII mount name keeps the columns aligned" "0" "$(width_of_rows "$(shell::system::stats::disk 2>/dev/null)")"

# ======================================================================================
# disk: macOS and APFS
# ======================================================================================
macos
MOCK_DF="$DF_MAC"
MOCK_MOUNT="$MOUNT_MAC"
rec="$(_shell::system::stats::disk::macos 0)"
t_eq "disk macos: containers and FAT volumes -> 4 rows" "4" "$(printf '%s\n' "$rec" | wc -l | tr -d ' ')"
APFS_TOTAL=$((488245288 * 1024))
APFS_FREE=$((300000000 * 1024))
t_has "disk macos: APFS system container is ONE row: total=container, free=container free, used=total-free" "/dev/disk3s1s1${SEP}/${SEP}apfs${SEP}${APFS_TOTAL}${SEP}$((APFS_TOTAL - APFS_FREE))${SEP}${APFS_FREE}" "$rec"
t_lacks "disk macos: Data volume of the same container is not listed again" "/System/Volumes/Data" "$rec"
t_lacks "disk macos: VM volume of the same container is not listed again" "/System/Volumes/VM" "$rec"
t_has "disk macos: another container with spaces and parentheses in its name" "/dev/disk5s1${SEP}/Volumes/Ext Drive (1)${SEP}apfs${SEP}" "$rec"
t_has "disk macos: msdos volume keeps df's own numbers" "/dev/disk6s1${SEP}/Volumes/USB STICK${SEP}msdos${SEP}$((30000000 * 1024))${SEP}$((10000000 * 1024))${SEP}$((20000000 * 1024))" "$rec"
t_has "disk macos: second volume of the same disk but a different filesystem is NOT merged" "/Volumes/USB TWO${SEP}msdos" "$rec"
t_lacks "disk macos: devfs filtered" "devfs" "$rec"
t_lacks "disk macos: autofs row (name with a space, no sizes) skipped" "auto_home" "$rec"
rec_all="$(_shell::system::stats::disk::macos 1)"
t_has "disk macos --all: every APFS volume as df reports it" "/dev/disk3s5${SEP}/System/Volumes/Data${SEP}apfs${SEP}${APFS_TOTAL}${SEP}$((170000000 * 1024))" "$rec_all"
t_has "disk macos --all: devfs back" "devfs${SEP}/dev${SEP}devfs" "$rec_all"
out="$(shell::system::stats::disk 2>&1)"
t_has "disk macos: container usage is used/total (188245288/488245288 -> 39%)" "39%" "$out"
t_has "disk macos: external volume name" "/Volumes/Ext Drive (1)" "$out"
t_eq "disk macos: columns aligned" "0" "$(width_of_rows "$out")"
MOCK_MOUNT=""
rec="$(_shell::system::stats::disk::macos 0)"
t_has "disk macos without mount output: device names decide, volumes are not merged" "/dev/disk3s5${SEP}/System/Volumes/Data${SEP}${SEP}" "$rec"
MOCK_DF=""
t_rc "disk macos: df prints nothing" 1 shell::system::stats::disk

# ======================================================================================
# memory: Linux
# ======================================================================================
linux
printf '%s\n' "$MEMINFO_32G" >"$HOME/meminfo"
rec="$(_shell::system::stats::memory::linux)"
t_eq "memory linux: Used = MemTotal - MemAvailable; Free = MemFree" "$((32 * GIB))${SEP}$((18 * GIB))${SEP}$((14 * GIB))${SEP}$((4 * GIB))" "$rec"
out="$(shell::system::stats::memory 2>&1)"
t_has "memory: title" "PHYSICAL MEMORY" "$out"
t_has "memory: total" "Total:" "$out"
t_has "memory: 32 GiB" "32.0 GiB" "$out"
t_has "memory: used 18 GiB" "18.0 GiB" "$out"
t_has "memory: available 14 GiB" "14.0 GiB" "$out"
t_has "memory: free 4 GiB" "4.0 GiB" "$out"
t_has "memory: usage 56%" "56%" "$out"
t_eq "memory: values right-aligned in one column" "1" "$(
	n="$(printf '%s\n' "$out" | grep -E '^(Total|Used|Available|Free|Usage):' | while IFS= read -r l; do echo "${#l}"; done | sort -u | wc -l | tr -d ' ')"
	[ "$n" = 1 ] && echo 1 || echo 0
)"
t_eq "memory --json: exact object" "{\"total\":$((32 * GIB)),\"used\":$((18 * GIB)),\"available\":$((14 * GIB)),\"free\":$((4 * GIB)),\"usage\":56}" "$(shell::system::stats::memory --json 2>/dev/null)"
t_has "memory --unit MiB" "32768.0 MiB" "$(shell::system::stats::memory --unit MiB 2>&1)"
t_has "memory --si" "GB" "$(shell::system::stats::memory --si 2>&1)"

printf 'MemTotal: 33554432 kB\nMemFree: 1024 kB\nMemAvailable: 102400 kB\n' >"$HOME/meminfo"
t_eq "memory: low available memory -> 100%" "{\"total\":$((32 * GIB)),\"used\":$((32 * GIB - 104857600)),\"available\":104857600,\"free\":1048576,\"usage\":100}" "$(shell::system::stats::memory --json 2>/dev/null)"
printf 'MemTotal: 4294967296 kB\nMemFree: 1 kB\nMemAvailable: 2147483648 kB\n' >"$HOME/meminfo"
t_has "memory: 4 TiB machine" "4.0 TiB" "$(shell::system::stats::memory 2>&1)"
t_has "memory: 4 TiB machine usage" '"total":4398046511104,"used":2199023255552' "$(shell::system::stats::memory --json 2>&1)"
printf 'MemTotal: 10000 kB\nMemFree: 1000 kB\nBuffers: 200 kB\nCached: 3000 kB\nSReclaimable: 500 kB\nShmem: 700 kB\n' >"$HOME/meminfo"
t_eq "memory: no MemAvailable -> MemFree+Buffers+Cached+SReclaimable-Shmem" "10240000${SEP}6144000${SEP}4096000${SEP}1024000" "$(_shell::system::stats::memory::linux)"
printf 'MemTotal: 10000 kB\nMemFree: 1000 kB\n' >"$HOME/meminfo"
t_eq "memory: only MemTotal and MemFree" "10240000${SEP}9216000${SEP}1024000${SEP}1024000" "$(_shell::system::stats::memory::linux)"
printf 'MemTotal: 10000 kB\n' >"$HOME/meminfo"
t_eq "memory: only MemTotal (everything else missing) -> nothing available, never negative" "10240000${SEP}10240000${SEP}0${SEP}0" "$(_shell::system::stats::memory::linux)"
printf 'MemTotal: 10000 kB\nMemFree: 1000 kB\nMemAvailable: 20000 kB\n' >"$HOME/meminfo"
t_eq "memory: MemAvailable above MemTotal is capped" "10240000${SEP}0${SEP}10240000${SEP}1024000" "$(_shell::system::stats::memory::linux)"
printf 'MemFree: 1000 kB\nMemAvailable: 500 kB\n' >"$HOME/meminfo"
t_rc "memory: MemTotal missing" 1 shell::system::stats::memory
t_eq "memory: MemTotal missing -> stdout empty" "" "$(shell::system::stats::memory 2>/dev/null)"
t_has "memory: MemTotal missing -> reason on stderr" "MemTotal" "$(shell::system::stats::memory 2>&1 >/dev/null)"
printf 'MemTotal: 0 kB\n' >"$HOME/meminfo"
t_rc "memory: MemTotal zero" 1 shell::system::stats::memory
printf 'MemTotal: lots kB\n' >"$HOME/meminfo"
t_rc "memory: MemTotal not a number" 1 shell::system::stats::memory
rm -f "$HOME/meminfo"
t_rc "memory: /proc/meminfo missing" 3 shell::system::stats::memory

# ======================================================================================
# memory: macOS
# ======================================================================================
macos
MOCK_MEMSIZE=17179869184
MOCK_VMSTAT="$VMSTAT_16K"
t_eq "memory macos: 16 KiB pages: Used = (anon - purgeable + wired + compressor) * page size" "17179869184${SEP}9994240000${SEP}7185629184${SEP}67108864" "$(_shell::system::stats::memory::macos)"
MOCK_VMSTAT="${VMSTAT_16K//16384 bytes/4096 bytes}"
MOCK_MEMSIZE=8589934592
t_eq "memory macos: 4 KiB pages (page size read, not assumed)" "8589934592${SEP}2498560000${SEP}6091374592${SEP}16777216" "$(_shell::system::stats::memory::macos)"
MOCK_MEMSIZE=17179869184
MOCK_VMSTAT="$(printf '%s\n' "$VMSTAT_16K" | grep -v 'Anonymous pages')"
t_eq "memory macos: no Anonymous pages line -> (active + wired + compressor)" "17179869184${SEP}8519680000${SEP}8660189184${SEP}67108864" "$(_shell::system::stats::memory::macos)"
MOCK_VMSTAT="$VMSTAT_16K"
out="$(shell::system::stats::memory --unit GiB 2>&1)"
t_has "memory macos: title" "PHYSICAL MEMORY" "$out"
t_has "memory macos: total 16 GiB" "16.0 GiB" "$out"
t_has "memory macos: usage 58%" "58%" "$out"
t_has "memory macos --json" '"total":17179869184,"used":9994240000,"available":7185629184,"free":67108864,"usage":58' "$(shell::system::stats::memory --json 2>/dev/null)"
MOCK_VMSTAT='Pages free: 100.
Pages active: 100.'
t_rc "memory macos: no page size and no wired pages -> invalid" 1 shell::system::stats::memory
MOCK_VMSTAT='this is not vm_stat output'
t_rc "memory macos: garbage vm_stat" 1 shell::system::stats::memory
t_eq "memory macos: garbage -> stdout empty" "" "$(shell::system::stats::memory 2>/dev/null)"
MOCK_VMSTAT="$(printf '%s\n' "$VMSTAT_16K" | grep -v 'Pages wired down')"
t_rc "memory macos: wired pages missing -> invalid" 1 shell::system::stats::memory
MOCK_VMSTAT="$(printf '%s\n' "$VMSTAT_16K" | grep -v 'page size of')"
t_rc "memory macos: page size line missing -> invalid, never assumed" 1 shell::system::stats::memory
MOCK_VMSTAT="$VMSTAT_16K"
MOCK_MEMSIZE=""
t_rc "memory macos: empty hw.memsize" 1 shell::system::stats::memory
MOCK_MEMSIZE="0"
t_rc "memory macos: zero hw.memsize" 1 shell::system::stats::memory
MOCK_MEMSIZE="sixteen"
t_rc "memory macos: hw.memsize not a number" 1 shell::system::stats::memory
MOCK_MEMSIZE=17179869184
# used cannot exceed what is installed
MOCK_VMSTAT='Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free: 0.
Pages wired down: 999999999.
Anonymous pages: 1.'
t_eq "memory macos: used capped at total" "17179869184${SEP}17179869184${SEP}0${SEP}0" "$(_shell::system::stats::memory::macos)"

# ======================================================================================
# swap: Linux
# ======================================================================================
linux
printf '%s\n' "$MEMINFO_32G" >"$HOME/meminfo"
printf 'Filename\tType\tSize\tUsed\tPriority\n/dev/sda2\tpartition\t4194304\t1048576\t-2\n/swapfile\tfile\t4194304\t1048576\t-3\n' >"$HOME/swaps"
t_eq "swap linux: enabled, 2 devices, Used = SwapTotal - SwapFree (SwapCached ignored)" "enabled${SEP}$((8 * GIB))${SEP}$((2 * GIB))${SEP}$((6 * GIB))${SEP}2" "$(_shell::system::stats::swap::linux)"
out="$(shell::system::stats::swap 2>&1)"
t_has "swap: title" "SWAP MEMORY" "$out"
t_has "swap: status enabled" "Enabled" "$out"
t_has "swap: total" "8.0 GiB" "$out"
t_has "swap: used" "2.0 GiB" "$out"
t_has "swap: free" "6.0 GiB" "$out"
t_has "swap: usage 25%" "25%" "$out"
t_has "swap: devices line" "Devices:" "$out"
t_eq "swap --json" "{\"status\":\"enabled\",\"total\":$((8 * GIB)),\"used\":$((2 * GIB)),\"free\":$((6 * GIB)),\"usage\":25,\"devices\":2}" "$(shell::system::stats::swap --json 2>/dev/null)"
rm -f "$HOME/swaps"
t_eq "swap linux: no /proc/swaps -> still enabled, devices unknown" "enabled${SEP}$((8 * GIB))${SEP}$((2 * GIB))${SEP}$((6 * GIB))${SEP}" "$(_shell::system::stats::swap::linux)"
t_has "swap --json: unknown devices is null" '"devices":null' "$(shell::system::stats::swap --json 2>/dev/null)"
t_lacks "swap: no Devices line when unknown" "Devices" "$(shell::system::stats::swap 2>&1)"
printf 'MemTotal: 100 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\n' >"$HOME/meminfo"
printf 'Filename\tType\tSize\tUsed\tPriority\n' >"$HOME/swaps"
t_eq "swap linux: disabled" "disabled${SEP}0${SEP}0${SEP}0${SEP}0" "$(_shell::system::stats::swap::linux)"
t_rc "swap: disabled is not an error" 0 shell::system::stats::swap
out="$(shell::system::stats::swap 2>&1)"
t_has "swap disabled: status" "Disabled" "$out"
t_has "swap disabled: zero total" "0 B" "$out"
t_has "swap disabled: 0%" "0%" "$out"
t_eq "swap --json disabled" '{"status":"disabled","total":0,"used":0,"free":0,"usage":0,"devices":0}' "$(shell::system::stats::swap --json 2>/dev/null)"
printf 'MemTotal: 100 kB\n' >"$HOME/meminfo"
t_eq "swap linux: no SwapTotal -> unavailable" "unavailable${SEP}0${SEP}0${SEP}0${SEP}" "$(_shell::system::stats::swap::linux)"
t_rc "swap: unavailable is not an error" 0 shell::system::stats::swap
t_has "swap unavailable: status" "Unavailable" "$(shell::system::stats::swap 2>/dev/null)"
printf 'MemTotal: 100 kB\nSwapTotal: 100 kB\n' >"$HOME/meminfo"
t_has "swap linux: SwapFree missing -> unavailable" "unavailable" "$(_shell::system::stats::swap::linux)"
printf 'MemTotal: 100 kB\nSwapTotal: 100 kB\nSwapFree: 900 kB\n' >"$HOME/meminfo"
t_eq "swap linux: SwapFree above SwapTotal is capped" "enabled${SEP}102400${SEP}0${SEP}102400${SEP}0" "$(_shell::system::stats::swap::linux)"
rm -f "$HOME/meminfo"
t_rc "swap: /proc/meminfo missing -> rc 0" 0 shell::system::stats::swap
t_has "swap: /proc/meminfo missing -> warning on stderr" "unavailable" "$(shell::system::stats::swap 2>&1 >/dev/null)"
t_eq "swap: /proc/meminfo missing -> still a status block on stdout" "1" "$(shell::system::stats::swap 2>/dev/null | grep -c 'Unavailable')"
t_rc "swap: swapon was never called" 1 test -e "$HOME/swapon.called"

# ======================================================================================
# swap: macOS
# ======================================================================================
macos
MOCK_SWAPUSAGE='total = 2048.00M  used = 1023.25M  free = 1024.75M  (encrypted)'
t_eq "swap macos: enabled, M = MiB, fractions kept" "enabled${SEP}2147483648${SEP}1072955392${SEP}1074528256${SEP}" "$(_shell::system::stats::swap::macos)"
t_has "swap macos: usage 50%" "50%" "$(shell::system::stats::swap 2>&1)"
t_has "swap macos --json" '"status":"enabled","total":2147483648,"used":1072955392,"free":1074528256,"usage":50,"devices":null' "$(shell::system::stats::swap --json 2>/dev/null)"
MOCK_SWAPUSAGE='total = 4.50G  used = 1.25G  free = 3.25G  (encrypted)'
t_eq "swap macos: G unit" "enabled${SEP}4831838208${SEP}1342177280${SEP}3489660928${SEP}" "$(_shell::system::stats::swap::macos)"
MOCK_SWAPUSAGE='total = 0.00M  used = 0.00M  free = 0.00M  (encrypted)'
t_eq "swap macos: disabled" "disabled${SEP}0${SEP}0${SEP}0${SEP}" "$(_shell::system::stats::swap::macos)"
t_rc "swap macos: disabled is rc 0" 0 shell::system::stats::swap
t_has "swap macos: disabled status" "Disabled" "$(shell::system::stats::swap 2>&1)"
MOCK_SWAPUSAGE=''
t_has "swap macos: empty output -> unavailable" "unavailable" "$(_shell::system::stats::swap::macos)"
t_rc "swap macos: empty output -> rc 0" 0 shell::system::stats::swap
MOCK_SWAPUSAGE='something unexpected'
t_has "swap macos: unexpected output -> unavailable" "unavailable" "$(_shell::system::stats::swap::macos)"
MOCK_SWAPUSAGE='total = lots  used = 1.00M  free = 1.00M'
t_has "swap macos: invalid number -> unavailable" "unavailable" "$(_shell::system::stats::swap::macos)"
MOCK_SWAPUSAGE='total = 1.00M  used = -1.00M  free = 2.00M'
t_has "swap macos: negative number -> unavailable" "unavailable" "$(_shell::system::stats::swap::macos)"
MOCK_SWAPUSAGE='total = 1.00M  used = 9.00M  free = 0.00M'
t_eq "swap macos: used above total is capped" "enabled${SEP}1048576${SEP}1048576${SEP}0${SEP}" "$(_shell::system::stats::swap::macos)"
t_rc "swap: swapon was never called on macOS either" 1 test -e "$HOME/swapon.called"

# ======================================================================================
# overview, help, return codes, streams, visibility
# ======================================================================================
linux
printf '%s\n' "$MEMINFO_32G" >"$HOME/meminfo"
printf '%s\n' "$MOUNTS_LINUX" >"$HOME/mounts"
printf 'Filename\tType\tSize\tUsed\tPriority\n/dev/sda2\tpartition\t8388608\t2097152\t-2\n' >"$HOME/swaps"
MOCK_DF="$DF_LINUX"
out="$(shell::system::stats::all 2>&1)"
t_rc "all: success" 0 shell::system::stats::all
t_has "all: heading" "SYSTEM RESOURCE OVERVIEW" "$out"
t_has "all: platform" "Platform: Linux" "$out"
t_has "all: architecture" "Architecture: $(shell::os::arch)" "$out"
t_has "all: disk section" "DISK STORAGE" "$out"
t_has "all: memory section" "PHYSICAL MEMORY" "$out"
t_has "all: swap section" "SWAP MEMORY" "$out"
t_has "all: rule between sections" "━━━━" "$out"
t_eq "all: three rules (header|disk, disk|memory, memory|swap)" "3" "$(printf '%s\n' "$out" | grep -c '^━')"
t_eq "all: sections in order" "DISK STORAGE PHYSICAL MEMORY SWAP MEMORY" "$(printf '%s\n' "$out" | grep -E '^(DISK STORAGE|PHYSICAL MEMORY|SWAP MEMORY)$' | tr '\n' ' ' | sed 's/ $//')"
macos
MOCK_DF="$DF_MAC"
MOCK_MOUNT="$MOUNT_MAC"
MOCK_MEMSIZE=17179869184
MOCK_VMSTAT="$VMSTAT_16K"
MOCK_SWAPUSAGE='total = 2048.00M  used = 1023.25M  free = 1024.75M  (encrypted)'
t_has "all: macOS platform label" "Platform: macOS" "$(shell::system::stats::all 2>&1)"
t_has "all: macOS uses the APFS container row" "/dev/disk3s1s1" "$(shell::system::stats::all 2>&1)"

# JSON of the overview: one object, nothing else on stdout
macos
out="$(shell::system::stats::all --json 2>/dev/null)"
t_eq "all --json: one line" "1" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
t_has "all --json: platform" '{"platform":"macos","architecture":"' "$out"
t_has "all --json: disk array" '"disk":[{"device":"/dev/disk3s1s1"' "$out"
t_has "all --json: memory object" '"memory":{"total":17179869184' "$out"
t_has "all --json: swap object" '"swap":{"status":"enabled"' "$out"
t_lacks "all --json: no heading" "SYSTEM RESOURCE" "$out"
t_lacks "all --json: no rule" "━" "$out"
t_has "all --json: ends with a closing brace" "}" "$out"

# a section that fails does not hide the others
MOCK_VMSTAT='garbage'
out="$(shell::system::stats::all --json 2>/dev/null)"
t_has "all --json: failed section is null" '"memory":null' "$out"
t_has "all --json: other sections still there" '"swap":{"status":"enabled"' "$out"
t_rc "all: a failed section gives a non-zero rc" 1 shell::system::stats::all
t_has "all: failed section reason on stderr" "vm_stat" "$(shell::system::stats::all 2>&1 >/dev/null)"
t_has "all: other sections still printed" "SWAP MEMORY" "$(shell::system::stats::all 2>/dev/null)"
MOCK_VMSTAT="$VMSTAT_16K"
MOCK_DF='Filesystem 1024-blocks Used Available Capacity Mounted on
/dev/x abc def ghi 1% /bad'
t_rc "all: empty disk section -> rc 8" 8 shell::system::stats::all
t_has "all --json: empty disk is []" '"disk":[]' "$(shell::system::stats::all --json 2>/dev/null)"
t_has "all: memory printed although disk was empty" "PHYSICAL MEMORY" "$(shell::system::stats::all 2>/dev/null)"
MOCK_DF="$DF_MAC"

# help: every public function, rc 0, usage on stdout
for fn in disk memory swap all; do
	t_rc "$fn: --help" 0 shell::system::stats::$fn --help
	t_has "$fn: --help has USAGE" "USAGE: shell::system::stats::$fn" "$T_OUT"
	t_has "$fn: --help mentions --json" "--json" "$T_OUT"
	t_rc "$fn: -h" 0 shell::system::stats::$fn -h
	t_rc "$fn: unknown option" 2 shell::system::stats::$fn --bogus
	t_eq "$fn: unknown option prints nothing on stdout" "" "$(shell::system::stats::$fn --bogus 2>/dev/null)"
	t_has "$fn: unknown option explained on stderr" "Unknown option" "$(shell::system::stats::$fn --bogus 2>&1 >/dev/null)"
	t_rc "$fn: bad unit" 2 shell::system::stats::$fn --unit furlong
done
t_has "disk --help mentions --all" "--all" "$(shell::system::stats::disk --help 2>&1)"
t_rc "memory --all is refused" 2 shell::system::stats::memory --all
t_rc "swap --all is refused" 2 shell::system::stats::swap --all
t_rc "all --all is refused" 2 shell::system::stats::all --all

# unsupported platforms: error on stderr, nothing on stdout, rc 4
for os in windows unknown; do
	SHELL_OS_TYPE="$os"
	for fn in disk memory swap all; do
		t_rc "$fn on $os: unsupported" 4 shell::system::stats::$fn
		t_eq "$fn on $os: stdout empty" "" "$(shell::system::stats::$fn 2>/dev/null)"
		t_has "$fn on $os: reason on stderr" "Linux and macOS" "$(shell::system::stats::$fn 2>&1 >/dev/null)"
	done
done

# a missing tool is reported, not crashed on (the subshell has no PATH and none of the mocks)
macos
(
	unset -f df mount sysctl vm_stat
	PATH="$HOME/no-such-bin"
	shell::system::stats::memory >/dev/null 2>&1
	echo $? >"$HOME/rc.memory"
	shell::system::stats::disk >/dev/null 2>&1
	echo $? >"$HOME/rc.disk"
	SHELL_OS_TYPE=linux
	shell::system::stats::disk >/dev/null 2>&1
	echo $? >"$HOME/rc.disk.linux"
)
t_eq "memory macos: tools missing -> rc 3" "3" "$(cat "$HOME/rc.memory")"
t_eq "disk macos: df missing -> rc 3" "3" "$(cat "$HOME/rc.disk")"
t_eq "disk linux: df missing -> rc 3" "3" "$(cat "$HOME/rc.disk.linux")"

# visibility: exactly four public functions, every other function of the module is private
public="$(grep -hoE '^shell::system::stats::[a-z_]+\(\)' "$SHELL_TEST_ROOT"/src/lib/system_stats*.sh | sed 's/()//' | sort | tr '\n' ' ')"
t_eq "public API is exactly disk, memory, swap, all" "shell::system::stats::all shell::system::stats::disk shell::system::stats::memory shell::system::stats::swap " "$public"
t_eq "no helper is declared with the public prefix" "0" "$(grep -hoE '^shell::system::stats::[a-z_]+::[a-z_:]+\(\)' "$SHELL_TEST_ROOT"/src/lib/system_stats*.sh | wc -l | tr -d ' ')"
t_rc "swapon never referenced as a command" 1 grep -qE '^[^#]*[ (]swapon ' "$SHELL_TEST_ROOT"/src/lib/system_stats_swap.sh
t_rc "no sudo anywhere in the module" 1 grep -qE '(^|[^a-z])sudo ' "$SHELL_TEST_ROOT"/src/lib/system_stats.sh "$SHELL_TEST_ROOT"/src/lib/system_stats_disk.sh "$SHELL_TEST_ROOT"/src/lib/system_stats_memory.sh "$SHELL_TEST_ROOT"/src/lib/system_stats_swap.sh

t_done
