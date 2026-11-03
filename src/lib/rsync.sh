#!/usr/bin/env bash
# @file lib/rsync.sh
# @brief rsync commands for local, ssh and daemon transfers: sync, mirror, move, resume, diff, list.
# @description
#   The commands of the rsync cheat sheets ([Linuxize](https://linuxize.com/cheatsheet/rsync/),
#   [Dev Cheatsheets](https://michaelcurrin.github.io/dev-cheatsheets/cheatsheets/shell/commands/rsync.html),
#   [DeployHQ](https://www.deployhq.com/cheatsheets/rsync),
#   [ditig](https://www.ditig.com/rsync-cheat-sheet)), grouped by what you want to do instead of
#   by flag, each with a `-n | --dry-run` switch and argument validation:
#
#   * `shell::rsync::sync`    copy what changed (`rsync -a src/ dest/`), anywhere to anywhere
#   * `shell::rsync::mirror`  make the destination identical to the source, with guard rails
#   * `shell::rsync::move`    copy, then remove the files from the source
#   * `shell::rsync::resume`  copy over a bad link: keep unfinished files, time out, retry
#   * `shell::rsync::diff`    show what a sync would change, changing nothing
#   * `shell::rsync::list`    list a source without copying (`--list-only`)
#   * `shell::rsync::version` print the rsync version
#
#   `shell::ssh::rsync::push` and `shell::ssh::rsync::pull` (lib/ssh_transfer.sh) stay the
#   short form for `rsync -avz -e ssh`; this file is for everything else.
#
#   Things worth knowing:
#
#   * A location is a path, `[user@]host:path` (ssh), `[user@]host::module` or
#     `rsync://[user@]host[:port]/module` (daemon), written as rsync writes them. Both sides
#     cannot be remote. A local path with a colon before any slash would be read as a host:
#     write it `./backup:2024`.
#   * Trailing `/` on a source: `src/` copies the contents, `src` copies the directory
#     itself. `mirror` always copies the contents.
#   * Options go **before** the locations. Nothing is run through `eval`: arguments reach
#     rsync as they are, so spaces and quotes are safe, and a location, port or pattern that
#     could be taken for an option is refused up front.
#   * `-n | --dry-run` prints the command (quoted so it can be pasted) and copies it to the
#     clipboard; rsync need not be installed. rsync's own `-n` is `--simulate`.
#   * The ssh options are those of the other ssh commands: `-p -i -J -F -o --batch
#     --accept-new` (rsync receives them through `-e "ssh ..."`). For a daemon, `-p` is
#     `--port`. `--sudo` runs rsync as root on the server (`--rsync-path="sudo rsync"`).
#   * `--timeout` is rsync's I/O timeout (no data for that long: give up), not the ssh
#     connect timeout; use `-o ConnectTimeout=<s>` for that.
#   * Compression is off unless you ask for `-z`: it helps on a slow link and wastes CPU on a
#     LAN, on a local copy and on files that are already compressed.
#   * `--delete` is rsync's `--delete-after`: nothing is removed until the transfer worked, so
#     a killed rsync leaves the destination as it was, not half emptied.
#   * The exit status is rsync's own. 23 (some files not transferred) and 24 (files vanished)
#     are partial successes; 25 means the `--max-delete` limit stopped the deletions.
#   * `--total-progress` needs rsync 3.1 and `--append` rsync 3.0. macOS ships an old (or
#     openrsync) build: `brew install rsync` for a current one.

# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

# @internal
# @description Say how rsync would reach a location: `local`, `ssh` or `daemon`.
#   rsync's own rule: `rsync://` is a daemon; otherwise the first `:` makes it remote unless a
#   `/` comes before it, and `::` right after the host makes it a daemon module.
# @arg $1 string The location.
# @stdout local, ssh or daemon.
# @exitcode 0 Always.
# @example
#   shell::rsync::spec::kind "deploy@web1:/var/www"   # -> ssh
#
shell::rsync::spec::kind() {
	local before
	case "${1-}" in
	rsync://*)
		printf 'daemon\n'
		return "$RETURN_SUCCESS"
		;;
	*:*) ;;
	*)
		printf 'local\n'
		return "$RETURN_SUCCESS"
		;;
	esac
	before="${1%%:*}"
	case "$before" in
	*/*) printf 'local\n' ;;
	*)
		case "${1#*:}" in
		:*) printf 'daemon\n' ;;
		*) printf 'ssh\n' ;;
		esac
		;;
	esac
}

# @internal
# @description Tell whether a string is a location this module accepts.
#   A local path is any non-empty string; an ssh location is checked like in scp
#   (shell::ssh::spec::valid); a daemon location needs a safe `[user@]host[:port]`.
# @arg $1 string The candidate.
# @exitcode 0 It is valid.
# @exitcode 1 It is not.
# @example
#   shell::rsync::spec::valid "rsync://mirror.example.com/pub/" && echo ok
#
shell::rsync::spec::valid() {
	local location="${1-}" authority
	if [ -z "$location" ]; then
		return 1
	fi
	case "$(shell::rsync::spec::kind "$location")" in
	local) return 0 ;;
	ssh) shell::ssh::spec::valid "$location" ;;
	*)
		case "$location" in
		*[[:cntrl:]]*) return 1 ;;
		rsync://*)
			authority="${location#rsync://}"
			authority="${authority%%/*}"
			;;
		*) authority="${location%%::*}" ;;
		esac
		shell::ssh::target::valid "$authority"
		;;
	esac
}

# @internal
# @description Tell whether a string is a bandwidth limit for `--bwlimit`.
#   Digits with an optional fraction and an optional `K`, `M` or `G` (`5m`, `1.5M`,
#   `10240`). Without a suffix rsync counts KiB per second.
# @arg $1 string The candidate.
# @exitcode 0 It is valid.
# @exitcode 1 It is not.
# @example
#   shell::rsync::rate::valid "5m" && echo ok
#
shell::rsync::rate::valid() {
	case "${1-}" in
	'' | *[!0-9.KkMmGg]* | [!0-9]* | *.*.* | *[KkMmGg]*[0-9.KkMmGg]*) return 1 ;;
	esac
	return 0
}

# @internal
# @description Tell whether a string is a permission spec for `--chmod`.
#   Comma separated `[D|F][ugoa][+-=][rwxXst]` clauses or octal modes (`D755,F644`,
#   `Du=rwx,go=rx`): only the characters of such a spec are accepted.
# @arg $1 string The candidate.
# @exitcode 0 It is valid.
# @exitcode 1 It is not.
# @example
#   shell::rsync::chmod::valid "D755,F644" && echo ok
#
shell::rsync::chmod::valid() {
	case "${1-}" in
	'' | -* | *[!DFugoarwxXst0-9,=+-]*) return 1 ;;
	esac
	return 0
}

# @internal
# @description Tell whether a mode takes a family of options.
#   Families: `data` (-z --bwlimit --timeout --partial --partial-dir --append --chmod
#   --progress --total-progress --stats --itemize), `compare` (-c -u --ignore-existing -L -H
#   --omit-dir-times --exclude --include --exclude-from), `sim` (--simulate), `delete`
#   (--delete) and `limit` (--max-delete).
# @arg $1 string The mode (sync, mirror, move, resume, diff, list).
# @arg $2 string The family.
# @exitcode 0 The mode takes it.
# @exitcode 1 It does not.
# @example
#   shell::rsync::cmd::supports mirror limit && echo yes
#
shell::rsync::cmd::supports() {
	case "${2-}" in
	data | sim)
		case "${1-}" in
		sync | mirror | move | resume) return 0 ;;
		esac
		;;
	compare)
		case "${1-}" in
		sync | mirror | move | resume | diff) return 0 ;;
		esac
		;;
	delete)
		case "${1-}" in
		sync | resume) return 0 ;;
		esac
		;;
	limit)
		case "${1-}" in
		sync | mirror | resume) return 0 ;;
		esac
		;;
	esac
	return 1
}

# @internal
# @description Like shell::rsync::cmd::supports, but report the refusal.
# @arg $1 string The mode.
# @arg $2 string The family.
# @arg $3 string The option the user typed.
# @exitcode 0 The mode takes it.
# @exitcode 2 It does not (an error was printed).
# @example
#   shell::rsync::cmd::allow "$mode" data "$1" || return "$RETURN_INVALID"
#
shell::rsync::cmd::allow() {
	if shell::rsync::cmd::supports "${1-}" "${2-}"; then
		return "$RETURN_SUCCESS"
	fi
	shell::logger::error "Option ${3-} is not supported by '${1-}'"
	return "$RETURN_INVALID"
}

# @internal
# @description Fail with a message unless the command is the one that has the option.
#   For the few options that belong to a single command (`--no-delete`, `--allow-empty`, `--retries`).
# @arg $1 string The mode being run.
# @arg $2 string The only mode that has the option.
# @arg $3 string The option the user typed.
# @exitcode 0 The mode has it.
# @exitcode 2 It does not (an error was printed).
# @example
#   shell::rsync::cmd::only "$mode" resume "$1" || return "$RETURN_INVALID"
#
shell::rsync::cmd::only() {
	if [ "${1-}" = "${2-}" ]; then
		return "$RETURN_SUCCESS"
	fi
	shell::logger::error "Option ${3-} is not supported by '${1-}'"
	return "$RETURN_INVALID"
}

# @internal
# @description Print the OPTIONS lines of a help block for the options a mode takes.
#   Call it between `shell::logger::usage` and the `-n` / `-h` lines.
# @arg $1 string The mode (sync, mirror, move, resume, diff, list).
# @stdout The option lines.
# @exitcode 0 Always.
# @example
#   shell::rsync::cmd::help sync
#
shell::rsync::cmd::help() {
	local mode="${1-sync}"
	case "$mode" in
	list) shell::logger::option "-r, --recursive" "Go into directories" ;;
	mirror) shell::logger::option "--allow-empty" "Mirror an empty source too (it empties the destination)" ;;
	resume) shell::logger::option "--retries <n>" "Start again up to n times after a network failure (default $SHELL_RSYNC_RETRIES)" ;;
	diff) shell::logger::option "--no-delete" "Do not report files that exist only at the destination" ;;
	esac
	if shell::rsync::cmd::supports "$mode" delete; then
		shell::logger::option "--delete" "Delete at the destination what is not at the source (after the transfer)"
	fi
	if shell::rsync::cmd::supports "$mode" limit; then
		shell::logger::option "--max-delete <n>" "Stop after deleting n files (rsync exits 25)"
	fi
	if shell::rsync::cmd::supports "$mode" sim; then
		shell::logger::option "--simulate" "Let rsync show what it would do (rsync -n), changing nothing"
	fi
	if shell::rsync::cmd::supports "$mode" compare; then
		shell::logger::option "--exclude <pattern>" "Skip matching files, repeatable (first matching rule wins)"
		shell::logger::option "--include <pattern>" "Do not skip matching files, repeatable"
		shell::logger::option "--exclude-from <file>" "Read exclude patterns from a file"
		shell::logger::option "-c, --checksum" "Compare checksums, not size and time (slow)"
		shell::logger::option "-u, --update" "Skip files that are newer at the destination"
		shell::logger::option "--ignore-existing" "Skip files that already exist at the destination"
		shell::logger::option "-L, --copy-links" "Copy what symlinks point to, not the links"
		shell::logger::option "-H, --hard-links" "Keep hard links"
		shell::logger::option "--omit-dir-times" "Do not set times on directories (NFS, FAT)"
	fi
	if shell::rsync::cmd::supports "$mode" data; then
		shell::logger::option "-z, --compress" "Compress the data on the wire"
		shell::logger::option "--bwlimit <rate>" "Limit the speed: 5m, 1.5M, 10240 (KiB/s)"
		shell::logger::option "--timeout <sec>" "Give up when no data moves for this long (rsync I/O timeout)"
		shell::logger::option "--partial" "Keep unfinished files at their final path"
		shell::logger::option "--partial-dir <dir>" "Keep unfinished files in this directory below the destination"
		shell::logger::option "--append" "Resume by appending, checking what is there (rsync 3.0; not with --partial-dir)"
		shell::logger::option "--chmod <spec>" "Set permissions, e.g. D755,F644"
		shell::logger::option "--progress" "Show the progress of each file"
		shell::logger::option "--total-progress" "Show one progress line for the whole transfer (rsync 3.1)"
		shell::logger::option "--stats" "Print a summary at the end"
		shell::logger::option "--itemize" "One line per changed file, with the reason"
	fi
	shell::logger::option "-v, --verbose" "More output (repeat for more)"
	shell::logger::option "-q, --quiet" "Less output"
	shell::logger::option "--human" "Print sizes in a readable form (1.2M)"
	shell::logger::option "-p, --port <n>" "Server port (ssh), or daemon port (1-65535)"
	shell::logger::option "-i, --identity <file>" "Private key to use (ssh)"
	shell::logger::option "-J, --jump <hosts>" "Go through jump host(s) (ssh)"
	shell::logger::option "-F, --config <file>" "Use this ssh config file instead of ~/.ssh/config"
	shell::logger::option "-o, --option <k=v>" "Any ssh option, repeatable (e.g. -o ConnectTimeout=10)"
	shell::logger::option "--batch" "Never ask for a password or passphrase (ssh)"
	shell::logger::option "--accept-new" "Trust an unknown host key once, refuse it if it changes (ssh)"
	shell::logger::option "--sudo" "Run rsync as root on the server (needs sudo without a password)"
	shell::logger::option "--rsync-path <cmd>" "Command that starts rsync on the server"
}

# @internal
# @description Explain an rsync exit status that has a well-known meaning.
#   Prints nothing for any other status. Warnings and errors go to stderr.
# @arg $1 integer The exit status of rsync.
# @stderr A hint for 23, 24 and 25.
# @exitcode 0 Always.
# @example
#   shell::rsync::hint 25
#
shell::rsync::hint() {
	case "${1-}" in
	23) shell::logger::warn "Some files or attributes were not transferred (status 23); see the errors above. The rest was transferred." ;;
	24) shell::logger::warn "Some source files vanished while rsync was running (status 24); the rest was transferred." ;;
	25) shell::logger::error "Stopped by the deletion limit --max-delete (status 25). Files deleted before the limit stay deleted: check the source, then raise --max-delete if these removals are expected." ;;
	esac
	return "$RETURN_SUCCESS"
}

# @internal
# @description The engine behind the commands: parse the options, validate the locations, build the rsync command, run it.
#   `mode` decides the arguments and the default flags (always `-a` unless noted):
#
#   * `sync`    `<source>... <destination>`
#   * `mirror`  `<source-dir> <destination>`  adds `--delete-after --max-delete=N`; the source is
#     a directory whose contents are mirrored; an empty source and the destination `/` are refused
#   * `move`    `<source>... <destination>`  adds `--remove-source-files`
#   * `resume`  `<source>... <destination>`  keeps unfinished files (`--partial-dir`, or
#     `--partial --append-verify` with `--append`), sets `--timeout`, and starts rsync again after a
#     network failure (status 10, 12, 30, 35 or 255)
#   * `diff`    `<source> <destination>`  `-n -i --delete`: what a sync would do
#   * `list`    `<location>`  `--list-only`
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string The mode.
# @arg $@ string The caller's own arguments.
# @exitcode 0 rsync succeeded (or the dry run printed).
# @exitcode 2 Unknown option, missing value, wrong number of arguments or an unsafe argument.
# @exitcode 3 rsync, ssh, or a local file that must exist, is missing.
# @exitcode 8 A mirror source is empty.
# @exitcode N Exit status of rsync.
# @example
#   shell::rsync::cmd sync -z --exclude .git ./site/ deploy@web1:/var/www/site/
#
shell::rsync::cmd() {
	local mode="${1-}"
	case "$mode" in
	sync | mirror | move | resume | diff | list) ;;
	*)
		shell::logger::error "Unknown mode: '$mode'"
		return "$RETURN_NOT_IMPLEMENTED"
		;;
	esac
	shift

	local dry_run="false" simulate="false" recursive="false" allow_empty="false" no_delete="false" delete="false"
	local append="false" partial="false" sudo="false"
	local partial_dir="" port="" identity="" config="" jump="" rsync_path="" timeout="" max_delete="" retries=""
	local src="" dest="" arg="" kind="" src_kind="" dest_kind="local" remote_kind="local" e_cmd=""
	local count=0 index=0 rc=0 attempt=0 delay=0
	local -a base=() flags=() filters=() filter_files=() ssh_opts=() sources=() invocation=() run=()

	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		--)
			shift
			break
			;;
		--simulate)
			shell::rsync::cmd::allow "$mode" sim "$1" || return "$RETURN_INVALID"
			simulate="true"
			shift
			;;
		-v | --verbose)
			flags+=(-v)
			shift
			;;
		-q | --quiet)
			flags+=(-q)
			shift
			;;
		--human)
			flags+=(-h)
			shift
			;;
		-r | --recursive)
			if [ "$mode" != "list" ]; then
				shell::logger::error "Option $1 is only for list (the other commands always recurse)"
				return "$RETURN_INVALID"
			fi
			recursive="true"
			shift
			;;
		-z | --compress)
			shell::rsync::cmd::allow "$mode" data "$1" || return "$RETURN_INVALID"
			flags+=(-z)
			shift
			;;
		--progress | --stats)
			shell::rsync::cmd::allow "$mode" data "$1" || return "$RETURN_INVALID"
			flags+=("$1")
			shift
			;;
		--total-progress)
			shell::rsync::cmd::allow "$mode" data "$1" || return "$RETURN_INVALID"
			flags+=(--info=progress2)
			shift
			;;
		--itemize)
			shell::rsync::cmd::allow "$mode" data "$1" || return "$RETURN_INVALID"
			flags+=(-i)
			shift
			;;
		--partial)
			shell::rsync::cmd::allow "$mode" data "$1" || return "$RETURN_INVALID"
			partial="true"
			shift
			;;
		--append)
			shell::rsync::cmd::allow "$mode" data "$1" || return "$RETURN_INVALID"
			append="true"
			shift
			;;
		--partial-dir)
			shell::rsync::cmd::allow "$mode" data "$1" || return "$RETURN_INVALID"
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			case "$2" in
			'' | -* | *[[:cntrl:]]*)
				shell::logger::error "Invalid partial directory: '$2'"
				return "$RETURN_INVALID"
				;;
			esac
			partial_dir="$2"
			shift 2
			;;
		--bwlimit)
			shell::rsync::cmd::allow "$mode" data "$1" || return "$RETURN_INVALID"
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			if ! shell::rsync::rate::valid "$2"; then
				shell::logger::error "Invalid bandwidth limit: '$2' (e.g. 5m, 1.5M, 10240)"
				return "$RETURN_INVALID"
			fi
			flags+=(--bwlimit="$2")
			shift 2
			;;
		--timeout)
			shell::rsync::cmd::allow "$mode" data "$1" || return "$RETURN_INVALID"
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			shell::ssh::cmd::number "$1" "$2" || return "$RETURN_INVALID"
			timeout="$2"
			shift 2
			;;
		--chmod)
			shell::rsync::cmd::allow "$mode" data "$1" || return "$RETURN_INVALID"
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			if ! shell::rsync::chmod::valid "$2"; then
				shell::logger::error "Invalid permission spec: '$2' (e.g. D755,F644 or Du=rwx,go=rx)"
				return "$RETURN_INVALID"
			fi
			flags+=(--chmod="$2")
			shift 2
			;;
		-c | --checksum | -u | --update | --ignore-existing | -L | --copy-links | -H | --hard-links | --omit-dir-times)
			shell::rsync::cmd::allow "$mode" compare "$1" || return "$RETURN_INVALID"
			case "$1" in
			-c | --checksum) flags+=(-c) ;;
			-u | --update) flags+=(-u) ;;
			-L | --copy-links) flags+=(-L) ;;
			-H | --hard-links) flags+=(-H) ;;
			*) flags+=("$1") ;;
			esac
			shift
			;;
		--exclude | --include)
			shell::rsync::cmd::allow "$mode" compare "$1" || return "$RETURN_INVALID"
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			if [ -z "$2" ]; then
				shell::logger::error "The $1 pattern cannot be empty"
				return "$RETURN_INVALID"
			fi
			filters+=("$1=$2")
			shift 2
			;;
		--exclude-from)
			shell::rsync::cmd::allow "$mode" compare "$1" || return "$RETURN_INVALID"
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			case "$2" in
			'' | -*)
				shell::logger::error "Invalid exclude file: '$2'"
				return "$RETURN_INVALID"
				;;
			esac
			filters+=("--exclude-from=$2")
			filter_files+=("$2")
			shift 2
			;;
		--delete)
			shell::rsync::cmd::allow "$mode" delete "$1" || return "$RETURN_INVALID"
			delete="true"
			shift
			;;
		--max-delete)
			shell::rsync::cmd::allow "$mode" limit "$1" || return "$RETURN_INVALID"
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			shell::ssh::cmd::number "$1" "$2" || return "$RETURN_INVALID"
			max_delete="$2"
			shift 2
			;;
		--no-delete)
			shell::rsync::cmd::only "$mode" diff "$1" || return "$RETURN_INVALID"
			no_delete="true"
			shift
			;;
		--allow-empty)
			shell::rsync::cmd::only "$mode" mirror "$1" || return "$RETURN_INVALID"
			allow_empty="true"
			shift
			;;
		--retries)
			shell::rsync::cmd::only "$mode" resume "$1" || return "$RETURN_INVALID"
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			shell::ssh::cmd::number "$1" "$2" || return "$RETURN_INVALID"
			retries="$2"
			shift 2
			;;
		-p | --port)
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			if ! shell::net::port::valid "$2"; then
				shell::logger::error "Invalid port: '$2' (1-65535)"
				return "$RETURN_INVALID"
			fi
			port="$2"
			shift 2
			;;
		-i | --identity | -F | --config)
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			case "$2" in
			'' | -*)
				shell::logger::error "Invalid file for $1: '$2'"
				return "$RETURN_INVALID"
				;;
			esac
			case "$1" in
			-i | --identity) identity="$2" ;;
			*) config="$2" ;;
			esac
			shift 2
			;;
		-J | --jump)
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			if ! shell::ssh::jump::valid "$2"; then
				shell::logger::error "Invalid jump host list: '$2' (use [user@]host[:port], comma separated)"
				return "$RETURN_INVALID"
			fi
			jump="$2"
			shift 2
			;;
		-o | --option)
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			if ! shell::ssh::option::valid "$2"; then
				shell::logger::error "Invalid ssh option: '$2' (expected Key=Value)"
				return "$RETURN_INVALID"
			fi
			ssh_opts+=(-o "$2")
			shift 2
			;;
		--batch)
			ssh_opts+=(-o "BatchMode=yes")
			shift
			;;
		--accept-new)
			ssh_opts+=(-o "StrictHostKeyChecking=accept-new")
			shift
			;;
		--sudo)
			sudo="true"
			shift
			;;
		--rsync-path)
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			case "$2" in
			'' | -* | *[[:cntrl:]]*)
				shell::logger::error "Invalid rsync path: '$2'"
				return "$RETURN_INVALID"
				;;
			esac
			rsync_path="$2"
			shift 2
			;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
	done

	# --- the locations ----------------------------------------------------------
	case "$mode" in
	list)
		if [ "$#" -ne 1 ]; then
			shell::logger::error "Exactly one location to list is required"
			return "$RETURN_INVALID"
		fi
		sources=("$1")
		;;
	mirror | diff)
		if [ "$#" -ne 2 ]; then
			shell::logger::error "Exactly one source and one destination are required"
			return "$RETURN_INVALID"
		fi
		sources=("$1")
		dest="$2"
		;;
	*)
		if [ "$#" -lt 2 ]; then
			shell::logger::error "At least one source and a destination are required"
			return "$RETURN_INVALID"
		fi
		count="$#"
		for arg in "$@"; do
			index=$((index + 1))
			if [ "$index" -eq "$count" ]; then
				dest="$arg"
			else
				sources+=("$arg")
			fi
		done
		;;
	esac
	if [ "${#sources[@]}" -eq 1 ]; then
		src="${sources[*]}"
	fi

	for arg in "${sources[@]}"; do
		if ! shell::rsync::spec::valid "$arg"; then
			shell::logger::error "Invalid location: '$arg' (a path, [user@]host:path, [user@]host::module or rsync://[user@]host[:port]/module)"
			return "$RETURN_INVALID"
		fi
		kind="$(shell::rsync::spec::kind "$arg")"
		if [ -z "$src_kind" ]; then
			src_kind="$kind"
		elif [ "$kind" != "$src_kind" ]; then
			shell::logger::error "Sources of different kinds (local, ssh, daemon) cannot be mixed: '$arg'"
			return "$RETURN_INVALID"
		fi
	done
	remote_kind="$src_kind"
	if [ -n "$dest" ]; then
		if ! shell::rsync::spec::valid "$dest"; then
			shell::logger::error "Invalid destination: '$dest' (a path, [user@]host:path, [user@]host::module or rsync://[user@]host[:port]/module)"
			return "$RETURN_INVALID"
		fi
		dest_kind="$(shell::rsync::spec::kind "$dest")"
		if [ "$src_kind" != "local" ] && [ "$dest_kind" != "local" ]; then
			shell::logger::error "Source and destination are both remote: rsync cannot copy from one server to another. Run it on one of them, or go through this machine in two steps"
			return "$RETURN_INVALID"
		fi
		if [ "$dest_kind" != "local" ]; then
			remote_kind="$dest_kind"
		fi
	fi

	# --- ssh and daemon options only where they mean something -------------------
	if [ "$sudo" = "true" ] && [ -n "$rsync_path" ]; then
		shell::logger::error "Use either --sudo or --rsync-path, not both"
		return "$RETURN_INVALID"
	fi
	local ssh_given="false"
	if [ -n "$identity$config$jump$rsync_path" ] || [ "${#ssh_opts[@]}" -gt 0 ] || [ "$sudo" = "true" ]; then
		ssh_given="true"
	fi
	case "$remote_kind" in
	ssh) ;;
	daemon)
		if [ "$ssh_given" = "true" ]; then
			shell::logger::error "-i, -J, -F, -o, --batch, --accept-new, --sudo and --rsync-path are for ssh; an rsync daemon (rsync://, host::module) does not use them"
			return "$RETURN_INVALID"
		fi
		;;
	*)
		if [ "$ssh_given" = "true" ] || [ -n "$port" ]; then
			shell::logger::error "The ssh and port options need a remote location ([user@]host:path)"
			return "$RETURN_INVALID"
		fi
		;;
	esac

	# --- what must exist -----------------------------------------------------------
	if [ "$dry_run" = "false" ]; then
		if [ -n "$identity" ] && [ ! -f "$identity" ]; then
			shell::logger::error "Identity file not found: $identity"
			return "$RETURN_NOT_FOUND"
		fi
		if [ -n "$config" ] && [ ! -f "$config" ]; then
			shell::logger::error "Config file not found: $config"
			return "$RETURN_NOT_FOUND"
		fi
		for arg in ${filter_files[@]+"${filter_files[@]}"}; do
			if [ ! -f "$arg" ]; then
				shell::logger::error "Exclude file not found: $arg"
				return "$RETURN_NOT_FOUND"
			fi
		done
		if [ "$src_kind" = "local" ]; then
			for arg in "${sources[@]}"; do
				if [ ! -e "$arg" ] && [ ! -h "$arg" ]; then
					shell::logger::error "Not found: $arg"
					return "$RETURN_NOT_FOUND"
				fi
			done
		fi
	fi

	# --- guard rails -----------------------------------------------------------------
	if [ "$mode" = "mirror" ]; then
		case "$src" in
		*/) ;;
		*)
			src="$src/"
			sources=("$src")
			;;
		esac
		case "$dest" in
		/ | //)
			shell::logger::error "Refusing to mirror onto /"
			return "$RETURN_INVALID"
			;;
		esac
		if [ "$src_kind" = "local" ] && [ "$dry_run" = "false" ]; then
			if [ ! -d "$src" ]; then
				shell::logger::error "The source of a mirror must be a directory: ${src%/}"
				return "$RETURN_INVALID"
			fi
			if [ "$allow_empty" = "false" ] && [ -z "$(ls -A "$src" 2>/dev/null | head -n 1)" ]; then
				shell::logger::error "The source is empty: mirroring it would delete everything at the destination. Use --allow-empty if that is what you want"
				return "$RETURN_EMPTY"
			fi
		fi
		if [ -z "$max_delete" ]; then
			max_delete="$SHELL_RSYNC_MAX_DELETE"
			shell::ssh::cmd::number SHELL_RSYNC_MAX_DELETE "$max_delete" || return "$RETURN_INVALID"
		fi
	fi
	if [ -n "$max_delete" ] && [ "$mode" != "mirror" ] && [ "$delete" = "false" ]; then
		shell::logger::error "Option --max-delete needs --delete"
		return "$RETURN_INVALID"
	fi
	if [ "$delete" = "true" ] && [ "$src_kind" = "local" ] && [ -n "$src" ] && [ -d "$src" ]; then
		case "$src" in
		*/) ;;
		*) shell::logger::warn "'$src' has no trailing /: the directory itself is copied into the destination and --delete removes everything else there. Add a / to copy its contents." ;;
		esac
	fi
	if [ "$append" = "true" ] && [ -n "$partial_dir" ]; then
		shell::logger::error "--append cannot be combined with --partial-dir (rsync refuses it)"
		return "$RETURN_INVALID"
	fi

	# --- the command ---------------------------------------------------------------------
	case "$mode" in
	sync) base=(-a) ;;
	mirror) base=(-a --delete-after) ;;
	move) base=(-a --remove-source-files) ;;
	resume)
		base=(-a)
		retries="${retries:-$SHELL_RSYNC_RETRIES}"
		shell::ssh::cmd::number SHELL_RSYNC_RETRIES "$retries" || return "$RETURN_INVALID"
		case "$SHELL_RSYNC_RETRY_DELAY" in
		'' | *[!0-9]*)
			shell::logger::error "Invalid SHELL_RSYNC_RETRY_DELAY: '$SHELL_RSYNC_RETRY_DELAY' (seconds, a whole number)"
			return "$RETURN_INVALID"
			;;
		esac
		if [ -z "$timeout" ]; then
			timeout="$SHELL_RSYNC_TIMEOUT"
			shell::ssh::cmd::number SHELL_RSYNC_TIMEOUT "$timeout" || return "$RETURN_INVALID"
		fi
		if [ "$append" = "true" ]; then
			partial="true"
		elif [ "$partial" = "false" ] && [ -z "$partial_dir" ]; then
			partial_dir="$SHELL_RSYNC_PARTIAL_DIR"
		fi
		;;
	diff) base=(-a -n -i) ;;
	list)
		base=(--list-only)
		if [ "$recursive" = "true" ]; then
			base+=(-r)
		fi
		;;
	esac
	if [ "$delete" = "true" ]; then
		base+=(--delete-after)
	fi
	if [ "$mode" = "diff" ] && [ "$no_delete" = "false" ]; then
		base+=(--delete)
	fi
	if [ -n "$max_delete" ]; then
		flags+=(--max-delete="$max_delete")
	fi
	if [ "$simulate" = "true" ]; then
		flags+=(-n)
	fi
	if [ "$partial" = "true" ]; then
		flags+=(--partial)
	fi
	if [ -n "$partial_dir" ]; then
		flags+=(--partial-dir="$partial_dir")
	fi
	if [ "$append" = "true" ]; then
		flags+=(--append-verify)
	fi
	if [ -n "$timeout" ]; then
		flags+=(--timeout="$timeout")
	fi

	invocation=(rsync "${base[@]}" ${flags[@]+"${flags[@]}"} ${filters[@]+"${filters[@]}"})
	case "$remote_kind" in
	ssh)
		if [ -n "$identity" ]; then
			ssh_opts+=(-i "$identity")
		fi
		if [ -n "$config" ]; then
			ssh_opts+=(-F "$config")
		fi
		if [ -n "$jump" ]; then
			ssh_opts+=(-J "$jump")
		fi
		if [ -n "$port" ]; then
			ssh_opts+=(-p "$port")
		fi
		if [ "${#ssh_opts[@]}" -gt 0 ]; then
			e_cmd="ssh $(shell::ssh::quote "${ssh_opts[@]}")"
			invocation+=(-e "$e_cmd")
		fi
		if [ "$sudo" = "true" ]; then
			invocation+=("--rsync-path=sudo rsync")
		elif [ -n "$rsync_path" ]; then
			invocation+=("--rsync-path=$rsync_path")
		fi
		;;
	daemon)
		if [ -n "$port" ]; then
			invocation+=(--port="$port")
		fi
		;;
	esac
	invocation+=(-- "${sources[@]}")
	if [ -n "$dest" ]; then
		invocation+=("$dest")
	fi

	if [ "$dry_run" = "true" ]; then
		run+=(-n)
	elif [ "$remote_kind" = "ssh" ]; then
		shell::dependency::ensure ssh || return "$RETURN_NOT_FOUND"
	fi

	while :; do
		rc=0
		shell::ssh::invoke ${run[@]+"${run[@]}"} "${invocation[@]}" || rc=$?
		if [ "$mode" != "resume" ] || [ "$dry_run" = "true" ] || [ "$rc" -eq 0 ]; then
			break
		fi
		case "$rc" in
		10 | 12 | 30 | 35 | 255) ;;
		*) break ;;
		esac
		if [ "$attempt" -ge "$retries" ]; then
			shell::logger::error "Giving up after $attempt retries (rsync status $rc). Run the same command again to continue where it stopped."
			break
		fi
		attempt=$((attempt + 1))
		delay=$((attempt * SHELL_RSYNC_RETRY_DELAY))
		shell::logger::warn "rsync stopped with status $rc (network problem?); retry $attempt of $retries in ${delay}s"
		sleep "$delay"
	done

	if [ "$dry_run" = "false" ]; then
		shell::rsync::hint "$rc"
		if [ "$rc" -eq 0 ] && [ "$mode" = "move" ] && [ "$simulate" = "false" ]; then
			shell::logger::note "Moved files are gone from the source; its empty directories are left in place."
		fi
	fi
	return "$rc"
}

# --------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------

# @description Copy what changed from one place to another (`rsync -a source/ dest/`).
#   Works for local paths, `[user@]host:path` over ssh and rsync daemons, and picks the
#   transport from the locations. Nothing is deleted, compressed or limited unless you ask.
#   Mind the trailing `/` of the source (see the file description) and `--delete`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --simulate Let rsync show what it would do, changing nothing.
# @option --delete Delete at the destination what is not at the source (`--delete-after`).
# @option --exclude <pattern> Skip matching files (repeatable).
# @option -z | --compress Compress the data on the wire.
# @option --bwlimit <rate> Limit the speed (`5m`, `10240`).
# @option -p | --port <n> Server port (ssh) or daemon port.
# @arg $@ string One or more sources, then the destination.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, missing arguments, or an unsafe argument.
# @exitcode 3 rsync, ssh, or a local source, is missing.
# @exitcode N Exit status of rsync.
# @see shell::rsync::mirror
# @see shell::rsync::diff
# @see shell::ssh::rsync::push
# @example
#   shell::rsync::sync ./site/ /mnt/backup/site/
#   shell::rsync::sync -z --exclude node_modules --exclude .git -p 2222 ./app/ deploy@web1:/srv/app/
#
shell::rsync::sync() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Copy what changed from one place to another (rsync -a)"
		shell::logger::usage "shell::rsync::sync [-n] [options] <source>... <destination>"
		shell::logger::item "source" "One or more paths or remote locations (a trailing / copies the contents)"
		shell::logger::item "destination" "A path, [user@]host:path, [user@]host::module or rsync://host/module"
		shell::rsync::cmd::help sync
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::rsync::sync ./site/ /mnt/backup/site/"
		shell::logger::example "shell::rsync::sync -z --exclude .git -p 2222 ./app/ deploy@web1:/srv/app/"
		return "$RETURN_SUCCESS"
	fi
	shell::rsync::cmd sync "$@"
}

# @description Make the destination identical to the source (`rsync -a --delete-after --max-delete=N`).
#   The source is a directory whose **contents** are mirrored (a trailing `/` is added).
#   Guard rails: nothing is deleted before the transfer succeeded; at most
#   `SHELL_RSYNC_MAX_DELETE` files are deleted (rsync then stops with status 25, and
#   what it already removed stays removed); an empty or missing local source and the
#   destination `/` are refused. Look at `shell::rsync::diff` first the first time.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --simulate Let rsync show what it would do, changing nothing.
# @option --max-delete <n> Delete at most n files.
# @option --allow-empty Mirror an empty source too (it empties the destination).
# @option --exclude <pattern> Skip matching files (repeatable); they are not deleted either.
# @arg $1 string The source directory.
# @arg $2 string The destination.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, wrong arguments, an unsafe argument, or a source that is not a directory.
# @exitcode 3 rsync, ssh, or the local source, is missing.
# @exitcode 8 The local source is empty.
# @exitcode 25 The deletion limit was reached.
# @exitcode N Exit status of rsync.
# @see shell::rsync::diff
# @example
#   shell::rsync::mirror --simulate ./build deploy@web1:/var/www/releases/new
#   shell::rsync::mirror --max-delete 50 ./photos /mnt/backup/photos
#
shell::rsync::mirror() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Make the destination identical to the source (rsync -a --delete-after --max-delete)"
		shell::logger::usage "shell::rsync::mirror [-n] [options] <source-dir> <destination>"
		shell::logger::item "source-dir" "The directory whose contents are mirrored (a trailing / is added)"
		shell::logger::item "destination" "A path, [user@]host:path, [user@]host::module or rsync://host/module"
		shell::rsync::cmd::help mirror
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::rsync::mirror --simulate ./build deploy@web1:/var/www/releases/new"
		shell::logger::example "shell::rsync::mirror --max-delete 50 ./photos /mnt/backup/photos"
		return "$RETURN_SUCCESS"
	fi
	shell::rsync::cmd mirror "$@"
}

# @description Move files: copy them, then remove them from the source (`rsync -a --remove-source-files`).
#   Only files are removed after they arrived intact; the empty directories stay at the source.
#   `--delete` is not available here.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --simulate Let rsync show what it would do, changing nothing.
# @option --exclude <pattern> Skip matching files (repeatable).
# @arg $@ string One or more sources, then the destination.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, missing arguments, or an unsafe argument.
# @exitcode 3 rsync, ssh, or a local source, is missing.
# @exitcode N Exit status of rsync.
# @see shell::rsync::sync
# @example
#   shell::rsync::move ./incoming/ /mnt/archive/
#   shell::rsync::move --simulate --exclude '*.part' ./downloads/ nas:/volume1/inbox/
#
shell::rsync::move() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Move files: copy them, then remove them from the source (rsync --remove-source-files)"
		shell::logger::usage "shell::rsync::move [-n] [options] <source>... <destination>"
		shell::logger::item "source" "One or more paths or remote locations (a trailing / moves the contents)"
		shell::logger::item "destination" "A path, [user@]host:path, [user@]host::module or rsync://host/module"
		shell::rsync::cmd::help move
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::rsync::move ./incoming/ /mnt/archive/"
		shell::logger::example "shell::rsync::move --simulate --exclude '*.part' ./downloads/ nas:/volume1/inbox/"
		return "$RETURN_SUCCESS"
	fi
	shell::rsync::cmd move "$@"
}

# @description Copy over an unreliable link and pick up where it stopped.
#   Unfinished files are kept in a hidden directory below the destination
#   (`--partial-dir`, `SHELL_RSYNC_PARTIAL_DIR`), so a half file never shows under its
#   final name; `--timeout` (`SHELL_RSYNC_TIMEOUT`) ends a dead connection; and when rsync
#   stops for a network reason (status 10, 12, 30, 35 or 255) it is started again, up to
#   `--retries` times (`SHELL_RSYNC_RETRIES`), waiting longer each time. Any other failure is
#   not retried. `--append` resumes huge files by appending instead (rsync cannot combine it
#   with a partial directory); it trusts that the file only grows.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --retries <n> Start again up to n times after a network failure.
# @option --timeout <sec> Give up a stalled connection after this long.
# @option --append Resume by appending (rsync 3.0).
# @option --total-progress One progress line for the whole transfer (rsync 3.1).
# @arg $@ string One or more sources, then the destination.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, missing arguments, or an unsafe argument.
# @exitcode 3 rsync, ssh, or a local source, is missing.
# @exitcode N Exit status of the last rsync run.
# @see shell::rsync::sync
# @example
#   shell::rsync::resume --total-progress ./backup.tar.gz deploy@web1:/srv/backups/
#   shell::rsync::resume --retries 10 --bwlimit 2m -p 2222 ./build/ deploy@web1:/srv/app/
#
shell::rsync::resume() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Copy over an unreliable link: keep unfinished files, time out, retry (rsync --partial-dir --timeout)"
		shell::logger::usage "shell::rsync::resume [-n] [options] <source>... <destination>"
		shell::logger::item "source" "One or more paths or remote locations (a trailing / copies the contents)"
		shell::logger::item "destination" "A path, [user@]host:path, [user@]host::module or rsync://host/module"
		shell::rsync::cmd::help resume
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::rsync::resume --total-progress ./backup.tar.gz deploy@web1:/srv/backups/"
		shell::logger::example "shell::rsync::resume --retries 10 --bwlimit 2m -p 2222 ./build/ deploy@web1:/srv/app/"
		return "$RETURN_SUCCESS"
	fi
	shell::rsync::cmd resume "$@"
}

# @description Show what a sync would change, changing nothing (`rsync -a -n -i --delete`).
#   One line per difference, as rsync itemizes it: `>f+++++++++` a new file, `>f.st......`
#   a file whose size or time differs, `.d..t......` a directory whose time differs,
#   `*deleting` a file that exists only at the destination. The output is rsync's own, so
#   it can be piped. Use it before a `mirror` or a `--delete`. Files that exist only at the
#   destination are listed as deletions; `--no-delete` leaves them out.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --no-delete Do not report files that exist only at the destination.
# @option -c | --checksum Compare checksums, not size and time (slow).
# @option --exclude <pattern> Skip matching files (repeatable).
# @arg $1 string The source.
# @arg $2 string The destination.
# @exitcode 0 Success (whether or not there are differences).
# @exitcode 2 Unknown option, wrong arguments, or an unsafe argument.
# @exitcode 3 rsync, ssh, or a local source, is missing.
# @exitcode N Exit status of rsync.
# @see shell::rsync::mirror
# @example
#   shell::rsync::diff ./build/ deploy@web1:/var/www/current/
#   shell::rsync::diff --no-delete --exclude .git ./a/ ./b/
#
shell::rsync::diff() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show what a sync would change, changing nothing (rsync -a -n -i --delete)"
		shell::logger::usage "shell::rsync::diff [-n] [options] <source> <destination>"
		shell::logger::item "source" "The source, as for sync (a trailing / compares the contents)"
		shell::logger::item "destination" "The destination, as for sync"
		shell::logger::item "output" ">f+++++++++ new file, >f.st...... size or time differs, *deleting only at the destination"
		shell::rsync::cmd::help diff
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::rsync::diff ./build/ deploy@web1:/var/www/current/"
		shell::logger::example "shell::rsync::diff --no-delete --exclude .git ./a/ ./b/"
		return "$RETURN_SUCCESS"
	fi
	shell::rsync::cmd diff "$@"
}

# @description List a source without copying anything (`rsync --list-only`).
#   Works on local paths, `[user@]host:path` and daemons; `rsync://host/` lists the modules
#   of a daemon. Add `-r` to go into directories.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -r | --recursive Go into directories.
# @option --human Print sizes in a readable form.
# @arg $1 string The location to list.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, no location, or an unsafe argument.
# @exitcode 3 rsync or ssh is missing, or the local path does not exist.
# @exitcode N Exit status of rsync.
# @example
#   shell::rsync::list deploy@web1:/var/www/
#   shell::rsync::list -r --human rsync://mirror.example.com/pub/
#
shell::rsync::list() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List a source without copying anything (rsync --list-only)"
		shell::logger::usage "shell::rsync::list [-n] [options] <location>"
		shell::logger::item "location" "A path, [user@]host:path, [user@]host::module or rsync://host/ (the modules of a daemon)"
		shell::rsync::cmd::help list
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::rsync::list deploy@web1:/var/www/"
		shell::logger::example "shell::rsync::list -r --human rsync://mirror.example.com/pub/"
		return "$RETURN_SUCCESS"
	fi
	shell::rsync::cmd list "$@"
}

# @description Print the version of the installed rsync (`rsync --version`, first line).
#   Several options depend on it: `--total-progress` needs 3.1, `--append` needs 3.0.
# @option -h | --help Show help and return.
# @stdout The version line.
# @exitcode 0 Success.
# @exitcode 3 rsync is not installed.
# @example
#   shell::rsync::version
#
shell::rsync::version() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Print the version of the installed rsync"
		shell::logger::usage "shell::rsync::version"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::rsync::version"
		return "$RETURN_SUCCESS"
	fi
	shell::dependency::rsync::ensure || return "$RETURN_NOT_FOUND"
	rsync --version 2>&1 | head -n 1
}
