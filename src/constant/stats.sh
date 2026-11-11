#!/usr/bin/env bash
# @file constant/stats.sh
# @brief Defaults and fixed strings of the system statistics (src/lib/system_stats*.sh).
# @description
#   Every path read by `shell::system::stats::*` is a constant here so a test (or a
#   container with a relocated /proc) can point it elsewhere before sourcing the library.

# Linux sources. They are only read, never written.
: "${SHELL_STATS_PROC_MEMINFO:=/proc/meminfo}"
: "${SHELL_STATS_PROC_MOUNTS:=/proc/self/mounts}"
: "${SHELL_STATS_PROC_SWAPS:=/proc/swaps}"

# Filesystem types left out of the disk table unless `--all` is given (space separated).
# They are kernel interfaces, in-memory filesystems, container layers or read-only
# images, not storage a person manages.
: "${SHELL_STATS_PSEUDO_FS:=proc sysfs devtmpfs devpts tmpfs ramfs cgroup cgroup2 overlay squashfs securityfs debugfs tracefs configfs fusectl mqueue hugetlbfs pstore bpf autofs binfmt_misc efivarfs nsfs rpc_pipefs selinuxfs fuse.gvfsd-fuse fuse.portal fuse.lxcfs devfs}"

# Separates the fields of an internal record. A control character that is not
# whitespace, so `read` keeps empty fields and a mount path may contain spaces.
SHELL_STATS_SEP=$'\037'

# Horizontal rule between the sections of `shell::system::stats::all`.
: "${SHELL_STATS_RULE_CHAR:=━}"
: "${SHELL_STATS_RULE_WIDTH:=44}"

# Width of the label column of the memory and swap blocks (`Available:` plus a gap).
: "${SHELL_STATS_LABEL_WIDTH:=12}"

# A disk table wider than the terminal shortens its Device and Mount Point columns,
# but never below this many characters.
: "${SHELL_STATS_MIN_CELL:=12}"

# Terminal width used for that shortening. Empty = use $COLUMNS when stdout is a terminal;
# a number forces it (also when the output is piped).
: "${SHELL_STATS_COLUMNS:=}"
