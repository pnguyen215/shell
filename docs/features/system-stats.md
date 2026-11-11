# System statistics

`shell::system::stats::*` shows disk, memory (RAM) and swap usage from the terminal on **macOS and Linux**, so you do not have to remember `df`, `diskutil`, `free`, `vm_stat` or `swapon`. It is **read-only**: it never needs root, never calls `sudo` and changes no disk, partition, filesystem, swap setting or memory setting.

| Property    | Value                                                                                     |
| ----------- | ----------------------------------------------------------------------------------------- |
| Audience    | Anyone using the library from an interactive shell or a script                            |
| Last review | 2026-11-11                                                                                |
| Platforms   | Linux and macOS (both run in CI); bash 3.2+ and zsh                                       |
| Source      | `src/lib/system_stats*.sh`, `src/constant/stats.sh`; tests in `test/test_system_stats.sh` |

## Public functions

| Function                       | Shows                                                                    |
| ------------------------------ | ------------------------------------------------------------------------ |
| `shell::system::stats::disk`   | Mounted filesystems: device, mount point, type, total, used, free, usage |
| `shell::system::stats::memory` | Physical memory: total, used, available, free, usage                     |
| `shell::system::stats::swap`   | Swap: status, total, used, free, usage                                   |
| `shell::system::stats::all`    | The three above under a header with the platform and architecture        |

Every function accepts `-h` / `--help`. All other functions of the module start with `_shell::system::stats::`; they are private and may change.

### Options

| Option          | Functions   | Effect                                                                                                                                                                  |
| --------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--unit <unit>` | all         | Print every size in one unit: `B`, `KiB`, `MiB`, `GiB`, `TiB` (binary) or `KB`, `MB`, `GB`, `TB` (decimal). The unit names the system, so `--si` is not needed with it. |
| `--si`          | all         | With automatic scaling, use decimal units (KB, MB, GB, powers of 1000)                                                                                                  |
| `--json`        | all         | One JSON value on stdout, sizes in **bytes**, no headings, no colour                                                                                                    |
| `--all`         | `disk` only | Do not filter: list every filesystem `df` reports, one row each                                                                                                         |

An unknown option or unit returns 2 and prints the reason on stderr.

```bash
shell::system::stats::all                    # the overview
shell::system::stats::disk --unit GiB        # every size in GiB
shell::system::stats::disk --all             # include tmpfs, overlay, every APFS volume ...
shell::system::stats::memory --si            # 1 GB = 1000 MB
shell::system::stats::swap --json            # for scripts
shell::system::stats::all --json | jq .memory.usage
```

## Output

Example on Linux (the numbers come from a test fixture; `--unit GiB` makes the swap lines read `0.0 GiB`, without it they read `0 B`):

```text
SYSTEM RESOURCE OVERVIEW

Platform: Linux
Architecture: arm64

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DISK STORAGE

Device          Mount Point         Type      Total       Used       Free  Usage
/dev/nvme0n1p2  /                   ext4  465.8 GiB  297.5 GiB  144.0 GiB    68%
/dev/sda1       /mnt/data           xfs   931.5 GiB  557.9 GiB  372.9 GiB    60%
/dev/sdb1       /media/usb/My Disk  vfat   14.3 GiB    1.9 GiB   12.4 GiB    14%

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PHYSICAL MEMORY

Total:      32.0 GiB
Used:       18.0 GiB
Available:  14.0 GiB
Free:        4.0 GiB
Usage:           56%

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SWAP MEMORY

Status:     Disabled
Total:       0.0 GiB
Used:        0.0 GiB
Free:        0.0 GiB
Usage:            0%
Devices:           0
```

Example on macOS (Apple silicon, real output): three APFS containers appear as three rows, not ten.

```text
DISK STORAGE

Device          Mount Point            Type      Total       Used       Free  Usage
/dev/disk4s1s1  /                      apfs  246.2 GiB  187.4 GiB   58.8 GiB    77%
/dev/disk1s2    /System/Volumes/xarts  apfs  500.0 MiB   18.0 MiB  482.0 MiB     4%
/dev/disk3s1    /Volumes/Inbox         apfs  214.2 GiB   26.0 GiB  188.2 GiB    13%
```

`--json` examples:

```json
{"total":34359738368,"used":19327352832,"available":15032385536,"free":4294967296,"usage":56}
{"status":"disabled","total":0,"used":0,"free":0,"usage":0,"devices":0}
[{"device":"/dev/sdb1","mount":"/media/usb/My Disk","type":"vfat","total":15360000000,"used":2048000000,"free":13312000000,"usage":14}]
```

`shell::system::stats::all --json` returns `{"platform":"linux|macos","architecture":"...","disk":[...],"memory":{...},"swap":{...}}` on one line.

### Terminal width

The columns are aligned by character count, also for non-ASCII names. When stdout is a terminal and the table is wider than `$COLUMNS` (80 if unset), the Mount Point and then the Device column are shortened with `...` down to 12 characters; the numbers are never cut. Piped output is never shortened. `SHELL_STATS_COLUMNS=<n>` forces a width.

## Units

| Convention | Units                 | Base | Used when                          |
| ---------- | --------------------- | ---- | ---------------------------------- |
| Binary     | B, KiB, MiB, GiB, TiB | 1024 | **default**                        |
| Decimal    | B, KB, MB, GB, TB     | 1000 | `--si`, or `--unit KB\|MB\|GB\|TB` |

The label always says which one it is, and one output never mixes the two. Sizes are kept as whole bytes internally and rounded to one decimal only when printed. In `--json` they are always bytes.

## How each value is calculated

### Disk

| Value | Meaning                                                                                               |
| ----- | ----------------------------------------------------------------------------------------------------- |
| Total | Capacity the mounted filesystem reports to `df`                                                       |
| Used  | `df` Used                                                                                             |
| Free  | `df` Available (blocks reserved for root on ext4 are not included, so Used + Free can be below Total) |
| Usage | `Used / (Used + Free)` rounded **up**, the same percentage `df` prints                                |

- **Sources.** Linux: `df -P -k` plus `/proc/self/mounts` for the type; octal escapes such as `\040` are decoded, so `/media/usb/My Disk` works. macOS: `df -P -k` plus `mount`. `lsblk` and `diskutil` are not used: the table needs nothing they add.
- **A row is a mounted filesystem, not a physical disk.** Rows are never summed, so no storage is counted twice.
- **Default filter.** Hidden: the types in `SHELL_STATS_PSEUDO_FS` (proc, sysfs, devtmpfs, devpts, tmpfs, ramfs, cgroup, cgroup2, overlay, squashfs, autofs, devfs ...) and filesystems of size 0. The same device with the same numbers mounted again (bind mounts, btrfs subvolumes) is listed once, under its first mount point. If `/proc/self/mounts` cannot be read, the type is unknown and only devices under `/dev` and network shares (`host:/path`, `//host/share`) are kept.
- **Removable and external storage** is a normal row, with its type (`vfat`, `exfat`, `msdos` ...).
- **APFS.** All volumes of one APFS container share one pool of space. `df` reports the container size and the container's free space for each of them, so listing them all would count the same bytes repeatedly. By default the volumes whose device is `/dev/diskNsM...` with the same `N` become **one row**, for the first volume `df` lists (normally `/`): Total = container size, Free = container free space, **Used = Total - Free** (all volumes and snapshots), Usage = Used / Total. Volumes of the same physical disk with a non-APFS type (two FAT partitions of one stick) are separate filesystems and stay separate rows. `--all` prints every APFS volume exactly as `df` reports it, where Used is that volume's own data.

### Memory

The kernels account for memory differently, so the calculations differ on purpose. Both are estimates of "held by programs" against "still available to programs".

| Value     | Linux (`/proc/meminfo`)                      | macOS (`sysctl hw.memsize`, `vm_stat`)                                                                                                 |
| --------- | -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Total     | `MemTotal`                                   | `hw.memsize`                                                                                                                           |
| Available | `MemAvailable`                               | Total - Used                                                                                                                           |
| Used      | `MemTotal - MemAvailable`                    | `(Anonymous pages - Pages purgeable + Pages wired down + Pages occupied by compressor) x page size` (Activity Monitor's "Memory Used") |
| Free      | `MemFree`                                    | `Pages free x page size`                                                                                                               |
| Usage     | Used / Total, rounded to the nearest percent | Used / Total, rounded to the nearest percent                                                                                           |

- Linux never derives Available from `MemFree`: the page cache is reclaimable and `MemAvailable` accounts for it. Buffers and cache sit inside Available, so they are not subtracted twice. On a kernel older than 3.14 (no `MemAvailable`) the estimate is `MemFree + Buffers + Cached + SReclaimable - Shmem`, limited to 0..Total. If only `MemTotal` exists, Available is 0.
- macOS reads the page size from the first line of `vm_stat` (4096 on Intel, 16384 on Apple silicon); it is never assumed, and a missing page size is an error. Without an "Anonymous pages" line (old macOS) Used is `(Pages active + Pages wired down + Pages occupied by compressor) x page size`. On macOS **Free is small by design**: the system uses spare memory for file cache, which is part of Available.
- Values are read once; memory changes while the command runs.

### Swap

| Value | Linux (`/proc/meminfo`, `/proc/swaps`)        | macOS (`sysctl -n vm.swapusage`) |
| ----- | --------------------------------------------- | -------------------------------- |
| Total | `SwapTotal` (all swap partitions and files)   | `total` (`M` = MiB, `G` = GiB)   |
| Used  | `SwapTotal - SwapFree`                        | `used`                           |
| Free  | `SwapFree`                                    | Total - Used                     |
| Usage | Used / Total, nearest percent; 0 without swap | same                             |

`SwapCached` is not subtracted: it is swap content also held in RAM, and it still occupies the device. `Devices` (a text line, and `"devices"` in JSON) is the number of entries in `/proc/swaps` and appears only when that file is readable; the total already covers every device. `swapon` is never run.

| Status        | Meaning                                                                                                                     | Exit code |
| ------------- | --------------------------------------------------------------------------------------------------------------------------- | --------- |
| `Enabled`     | The capacity is above 0                                                                                                     | 0         |
| `Disabled`    | The source was read and the capacity is 0. On macOS this means no swap file exists right now (macOS creates them on demand) | 0         |
| `Unavailable` | The source is missing or cannot be understood; a warning goes to stderr and sizes print as 0                                | 0         |

A system without swap is a normal state, not an error. In `--json` the status is `"enabled"`, `"disabled"` or `"unavailable"`.

## Exit codes and streams

Data goes to stdout. Errors and warnings go to stderr. With `--json`, stdout holds the JSON and nothing else.

| Code | Constant               | When                                                                                      |
| ---- | ---------------------- | ----------------------------------------------------------------------------------------- |
| 0    | `RETURN_SUCCESS`       | Success, including "no swap" and "swap unavailable"                                       |
| 1    | `RETURN_FAILURE`       | The source content is invalid (no `MemTotal`, unusable `vm_stat`) or `df` printed nothing |
| 2    | `RETURN_INVALID`       | Unknown option or unit, `--all` on `memory`, `swap` or `all`                              |
| 3    | `RETURN_NOT_FOUND`     | `df`, `sysctl`, `vm_stat` or `/proc/meminfo` is missing                                   |
| 4    | `RETURN_NOT_SUPPORTED` | Windows shells or an unknown OS                                                           |
| 8    | `RETURN_EMPTY`         | No filesystem matched the filter (`disk` still prints its title, or `[]`)                 |

`shell::system::stats::all` always prints every section it can. A section that fails is reported on stderr (`null` in JSON) and the exit code is the first failure.

## Known limitations

- **One row per filesystem.** There is no per-physical-disk view and no total across disks.
- **APFS grouping uses the device name** (`/dev/diskNsM`) and the type reported by `mount`. If `mount` prints nothing, APFS volumes are listed separately.
- **`df` can block** on an unreachable network mount; the module does not add a timeout because no portable `timeout` command exists on macOS.
- **Not supported:** a device name with a space, a mount path with a newline, Windows (WSL counts as Linux).
- **Free memory is not comparable across platforms.** Compare Available and Usage, and read the calculation tables above.
- **Swap on macOS** reports only what `vm.swapusage` returns; it cannot tell "disabled by the user" from "not needed yet".
- **Verification.** The parsers are tested with fixtures for both platforms in bash 3.2, bash and zsh. The Linux collectors were not run on a real Linux host for this change; run `make test` in the Ubuntu CI job to confirm.

## Settings

Defaults are in `src/constant/stats.sh`; set them before sourcing the library to override.

| Variable                   | Default             | Purpose                                                 |
| -------------------------- | ------------------- | ------------------------------------------------------- |
| `SHELL_STATS_PROC_MEMINFO` | `/proc/meminfo`     | Linux memory and swap source                            |
| `SHELL_STATS_PROC_MOUNTS`  | `/proc/self/mounts` | Linux filesystem types                                  |
| `SHELL_STATS_PROC_SWAPS`   | `/proc/swaps`       | Linux swap device count                                 |
| `SHELL_STATS_PSEUDO_FS`    | see the file        | Types hidden unless `--all`                             |
| `SHELL_STATS_COLUMNS`      | empty               | Force the terminal width used to shorten the disk table |
| `SHELL_STATS_RULE_CHAR`    | `━`                 | Rule between the sections of `all`                      |

## Design

```mermaid
flowchart LR
    P["public: disk | memory | swap | all"] --> O["options (--unit --si --json --all)"]
    O --> PL["platform: shell::os::type"]
    PL -->|linux| L["::linux collectors<br>/proc, df"]
    PL -->|macos| M["::macos collectors<br>sysctl, vm_stat, mount, df"]
    L --> R["records in bytes"]
    M --> R
    R --> T["::render (text)"]
    R --> J["::json"]
```

- **Collect, parse, render are separate.** The `parse_*` functions take text and print records, so tests feed them fixtures and run Linux and macOS cases on any host. `SHELL_OS_TYPE` selects the platform in tests; `df`, `mount`, `sysctl` and `vm_stat` are replaced by shell functions.
- **One OS check.** `_shell::system::stats::platform` asks `shell::os::type` once; there is no `uname` in the module.
- **No exported functions.** The library does not use `export -f`; "public" means the `shell::` prefix and a shdoc block without `# @internal`, which `make lint` enforces.
- **Bash 3.2 and zsh.** No arrays, no `declare -A`, no `mapfile`, no `BASH_REMATCH`. Records are joined with an unprintable, non-whitespace separator so `read` keeps empty fields and mount paths may contain spaces.
