#!/usr/bin/env bash
# @file lib/ssh_cmd.sh
# @brief SSH client commands (connect, exec, script, check, multiplexing) and the engine shared by every ssh / scp / sftp / rsync wrapper.
# @description
#   One documented function per command of the SSH cheat sheets, each with a
#   `-n | --dry-run` switch and argument validation, so that
#   `ssh -p 2222 -i key user@host` is `shell::ssh::connect -p 2222 -i key user@host`.
#
#   The commands live in four files, all built on `shell::ssh::cmd` below:
#
#   * lib/ssh_cmd.sh       connect, exec, script, check, version, mux::check, mux::stop
#   * lib/ssh_transfer.sh  scp::upload, scp::download, rsync::push, rsync::pull, sftp::connect
#   * lib/ssh_tunnel.sh    tunnel::local (-L), tunnel::remote (-R), tunnel::socks (-D)
#   * lib/ssh_key.sh       key::copy_id, key::public, key::fingerprint ... (and ssh_agent.sh,
#                          ssh_known_hosts.sh, ssh_config.sh for the agent, known_hosts and ~/.ssh/config)
#
#   Things worth knowing:
#
#   * One vocabulary for every command: `-p | --port`, `-i | --identity`,
#     `-J | --jump`, `-F | --config`, `-o | --option`. The letter each program
#     really uses is chosen for you (scp and sftp want `-P`, rsync gets it
#     through `-e "ssh ..."`), so you never have to remember it.
#   * Options go **before** the target. For `connect` and `exec`, everything
#     after the target is the remote command, passed on untouched.
#   * Nothing is run through `eval`: arguments reach the program as they are,
#     so spaces and quotes are safe. A target, a port, a jump list or a
#     forwarding spec that could be mistaken for an option is refused up front.
#   * `-n | --dry-run` prints the command (quoted so that it can be pasted) and
#     copies it to the clipboard. It never needs the program to be installed.
#   * The exit status is the program's own (255 when ssh cannot connect).
#   * The safe options are preferred over the famous unsafe ones: there is
#     `--accept-new` (trust a host the first time only) and no
#     `StrictHostKeyChecking=no` shortcut.

# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

# @internal
# @description Tell whether a string is a safe `[user@]host` (or a Host alias of ~/.ssh/config).
#   Accepts `A-Z a-z 0-9 . _ + : - @`, at most one `@`, and refuses a leading `-`
#   (it would be read as an option), a leading or trailing `@`, and an empty string.
#   IPv6 literals are accepted by `connect` but not by the scp / rsync
#   `host:path` form, where the first `:` ends the host: use an alias there.
# @arg $1 string The candidate.
# @exitcode 0 It is safe.
# @exitcode 1 It is not.
# @example
#   shell::ssh::target::valid "deploy@10.0.0.5" && echo ok
#
shell::ssh::target::valid() {
	case "${1-}" in
	'' | -* | @* | *@ | *@*@* | *[!A-Za-z0-9._@+:-]*) return 1 ;;
	esac
	return 0
}

# @internal
# @description Tell whether a string is a valid ProxyJump list (`-J`): `[user@]host[:port]`, comma separated.
# @arg $1 string The candidate.
# @exitcode 0 It is safe.
# @exitcode 1 It is not.
# @example
#   shell::ssh::jump::valid "bastion1,ops@bastion2:2222" && echo ok
#
shell::ssh::jump::valid() {
	case "${1-}" in
	'' | -* | *[!A-Za-z0-9._@+:,-]*) return 1 ;;
	esac
	return 0
}

# @internal
# @description Tell whether a string is an `-o` option of the form `Key=Value`.
# @arg $1 string The candidate.
# @exitcode 0 A key of letters and digits, `=`, and a non-empty value.
# @exitcode 1 It is not.
# @example
#   shell::ssh::option::valid "Compression=yes" && echo ok
#
shell::ssh::option::valid() {
	local key="${1%%=*}"
	case "$key" in
	'' | *[!A-Za-z0-9]*) return 1 ;;
	esac
	case "${1-}" in
	*=?*) return 0 ;;
	esac
	return 1
}

# @internal
# @description Tell whether a string is a port-forwarding spec for `-L` or `-R`.
#   `[bind:]port:host:hostport`, or `[bind:]port:/path/to/socket`. Only the
#   characters of such a spec are accepted (`A-Z a-z 0-9 . _ : / * [ ] -`), it
#   must contain a `:` and cannot start with `-`; ssh checks the rest.
# @arg $1 string The candidate.
# @exitcode 0 It is safe.
# @exitcode 1 It is not.
# @example
#   shell::ssh::forward::valid "8080:localhost:80" && echo ok
#
shell::ssh::forward::valid() {
	case "${1-}" in
	'' | -* | *[!]A-Za-z0-9._:/*[-]*) return 1 ;;
	esac
	case "$1" in
	*:*) return 0 ;;
	esac
	return 1
}

# @internal
# @description Tell whether a string is a remote location `[user@]host:path`, as scp and rsync write it.
#   The path may be empty (the home directory) and may contain anything but
#   control characters. The host is checked with shell::ssh::target::valid.
# @arg $1 string The candidate.
# @exitcode 0 It is a valid remote location.
# @exitcode 1 It is not.
# @example
#   shell::ssh::spec::valid "deploy@web1:/var/www" && echo ok
#
shell::ssh::spec::valid() {
	case "${1-}" in
	*:*) ;;
	*) return 1 ;;
	esac
	case "$1" in
	*[[:cntrl:]]*) return 1 ;;
	esac
	shell::ssh::target::valid "${1%%:*}"
}

# @internal
# @description Print a local path in a form scp and rsync cannot mistake for a remote host.
#   `a:b` would be read as "file b on host a"; it is printed as `./a:b`. Every
#   other path is printed unchanged.
# @arg $1 string The local path.
# @stdout The path.
# @exitcode 0 Always.
# @example
#   shell::ssh::path::local "backup:2024.tgz"   # -> ./backup:2024.tgz
#
shell::ssh::path::local() {
	case "${1-}" in
	/* | ./* | ../*) printf '%s\n' "$1" ;;
	*:*)
		case "${1%%:*}" in
		*/*) printf '%s\n' "$1" ;;
		*) printf './%s\n' "$1" ;;
		esac
		;;
	*) printf '%s\n' "${1-}" ;;
	esac
}

# @internal
# @description Quote words so that the line can be pasted into a shell.
#   Words made only of `A-Z a-z 0-9 _ @ % + = : , . / -` stay as they are;
#   anything else (spaces, `*`, `~`, quotes, an empty word) is single-quoted.
#   Used for what is printed (dry run, the echoed command); never for execution.
# @arg $@ string The words.
# @stdout The words joined by a space, quoted where needed.
# @exitcode 0 Always.
# @example
#   shell::ssh::quote scp "my file" host:/tmp   # -> scp 'my file' host:/tmp
#
shell::ssh::quote() {
	local word out="" sep=""
	for word in "$@"; do
		case "$word" in
		'' | *[!A-Za-z0-9_@%+=:,./-]*)
			word="'$(printf '%s' "$word" | sed "s/'/'\\\\''/g")'"
			;;
		esac
		out="$out$sep$word"
		sep=" "
	done
	printf '%s\n' "$out"
}

# @internal
# @description Run a program (argv style), or only print the command.
#   The single place that starts ssh, scp, sftp, rsync, ssh-keygen, ssh-add and
#   friends. The command is echoed first, quoted so that it can be pasted. With
#   `-n` it is printed (and copied to the clipboard) and the program does not
#   even have to be installed; otherwise a missing program is installed when
#   `SHELL_AUTO_INSTALL_DEPS` allows it.
# @option -n | --dry-run Print the command instead of running it.
# @option --stdin <file> Feed the program from this file (`< file`).
# @arg $1 string The program.
# @arg $@ string Its arguments.
# @exitcode 0 The program succeeded (or the dry run printed).
# @exitcode 2 No program was given.
# @exitcode 3 The program is not installed and could not be installed.
# @exitcode N Exit status of the program.
# @example
#   shell::ssh::invoke -n ssh -p 2222 deploy@web1
#
shell::ssh::invoke() {
	local dry_run="false" stdin_file=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		--stdin)
			stdin_file="${2-}"
			shift 2
			;;
		*) break ;;
		esac
	done

	if [ "$#" -eq 0 ]; then
		shell::logger::error "A program to run is required"
		return "$RETURN_INVALID"
	fi

	local line
	line="$(shell::ssh::quote "$@")"
	if [ -n "$stdin_file" ]; then
		line="$line < $(shell::ssh::quote "$stdin_file")"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$line"
		return "$RETURN_SUCCESS"
	fi

	shell::dependency::ensure "$1" || return "$RETURN_NOT_FOUND"
	shell::logger::command "$line"
	if [ -n "$stdin_file" ]; then
		"$@" <"$stdin_file"
	else
		"$@"
	fi
}

# @internal
# @description Fail with a message when an option that needs a value is the last word.
# @arg $1 string The option.
# @arg $2 integer How many words are left (the option included).
# @exitcode 0 There is a value.
# @exitcode 2 There is not.
# @example
#   shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
#
shell::ssh::cmd::need() {
	if [ "${2-0}" -lt 2 ]; then
		shell::logger::error "Option ${1-} requires a value"
		return "$RETURN_INVALID"
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Fail with a message unless the value is a positive whole number.
# @arg $1 string The option the value belongs to.
# @arg $2 string The value.
# @exitcode 0 It is 1, 2, 3 ...
# @exitcode 2 It is not.
# @example
#   shell::ssh::cmd::number --timeout "$2" || return "$RETURN_INVALID"
#
shell::ssh::cmd::number() {
	case "${2-}" in
	'' | *[!0-9]* | 0*)
		shell::logger::error "Invalid value for ${1-}: '${2-}' (a positive whole number is required)"
		return "$RETURN_INVALID"
		;;
	esac
	return "$RETURN_SUCCESS"
}

# @internal
# @description Tell whether a program takes a family of options.
#   Families: `verbose` (-v -q -C: not ssh-copy-id, not rsync), `session`
#   (-A -X -t: ssh), `copy` (-r --preserve: scp), `sync` (--delete --exclude
#   --simulate --progress: rsync). Everything else is understood by all programs.
# @arg $1 string The program (ssh, scp, sftp, ssh-copy-id, rsync).
# @arg $2 string The family.
# @exitcode 0 The program takes it.
# @exitcode 1 It does not.
# @example
#   shell::ssh::cmd::supports scp copy && echo yes
#
shell::ssh::cmd::supports() {
	case "${2-}" in
	verbose) [ "${1-}" != "ssh-copy-id" ] && [ "${1-}" != "rsync" ] ;;
	session) [ "${1-}" = "ssh" ] ;;
	copy) [ "${1-}" = "scp" ] ;;
	sync) [ "${1-}" = "rsync" ] ;;
	*) return 0 ;;
	esac
}

# @internal
# @description Like shell::ssh::cmd::supports, but report the refusal.
# @arg $1 string The program.
# @arg $2 string The family.
# @arg $3 string The option the user typed.
# @exitcode 0 The program takes it.
# @exitcode 2 It does not (an error was printed).
# @example
#   shell::ssh::cmd::allow "$program" session "$1" || return "$RETURN_INVALID"
#
shell::ssh::cmd::allow() {
	if shell::ssh::cmd::supports "${1-}" "${2-}"; then
		return "$RETURN_SUCCESS"
	fi
	shell::logger::error "Option ${3-} is not supported by '${1-}'"
	return "$RETURN_INVALID"
}

# @internal
# @description Print the OPTIONS lines of a help block for the options a program takes.
#   Call it between `shell::logger::usage` and the `-n` / `-h` lines.
# @arg $1 string The program (ssh, scp, sftp, ssh-copy-id, rsync).
# @stdout The option lines.
# @exitcode 0 Always.
# @example
#   shell::ssh::cmd::help ssh
#
shell::ssh::cmd::help() {
	local program="${1-ssh}"
	shell::logger::option "-p, --port <n>" "Server port (1-65535)"
	shell::logger::option "-i, --identity <file>" "Private key to use"
	shell::logger::option "-J, --jump <hosts>" "Go through jump host(s) (ProxyJump)"
	shell::logger::option "-F, --config <file>" "Use this ssh config file instead of ~/.ssh/config"
	shell::logger::option "-o, --option <k=v>" "Any ssh option, repeatable (e.g. -o Compression=yes)"
	shell::logger::option "--timeout <sec>" "Give up connecting after this many seconds"
	shell::logger::option "--keepalive <sec>" "Send a keep-alive every this many seconds"
	shell::logger::option "--batch" "Never ask for a password or passphrase"
	shell::logger::option "--accept-new" "Trust an unknown host key once, refuse it if it changes"
	if shell::ssh::cmd::supports "$program" verbose; then
		shell::logger::option "-v, --verbose" "Debug output (repeat for more)"
		shell::logger::option "-q, --quiet" "Quiet mode"
		shell::logger::option "-C, --compress" "Compress the data"
	fi
	if shell::ssh::cmd::supports "$program" session; then
		shell::logger::option "-A, --agent" "Forward the ssh agent"
		shell::logger::option "-X, --x11" "Forward X11"
		shell::logger::option "-t, --tty" "Force a terminal (needed for sudo, top ...)"
	fi
	if shell::ssh::cmd::supports "$program" copy; then
		shell::logger::option "-r, --recursive" "Copy directories recursively"
		shell::logger::option "--preserve" "Keep times and modes"
	fi
	if shell::ssh::cmd::supports "$program" sync; then
		shell::logger::option "--delete" "Delete files at the destination that are not at the source"
		shell::logger::option "--exclude <pattern>" "Skip matching files, repeatable"
		shell::logger::option "--simulate" "Let rsync show what it would do (rsync -n), changing nothing"
		shell::logger::option "--progress" "Show the progress of each file"
	fi
}

# @internal
# @description The engine behind the commands: parse the options, validate the arguments, build the command, run it.
#   `program` is what is started (`ssh`, `scp`, `sftp`, `ssh-copy-id`, `rsync`)
#   and `mode` decides what the arguments are and how the command is put together:
#
#   * `connect`      `<target> [command...]`  ssh, remote command passed as it is
#   * `exec`         `<target> <command...>`  like connect, a command is required
#   * `script`       `<target> <file> [args...]`  runs the local file with `bash -s` on the server
#   * `target`       `<target>`  ssh-copy-id, sftp
#   * `check`        `<target>`  ssh in batch mode, runs `true`, reports the result
#   * `mux_check`    `<target>`  `ssh -O check`
#   * `mux_exit`     `<target>`  `ssh -O exit`
#   * `upload`       `<local>... <[user@]host:path>`  scp
#   * `download`     `<[user@]host:path>... <local>`  scp
#   * `push`         `<local>... <[user@]host:path>`  rsync -avz over ssh
#   * `pull`         `<[user@]host:path>... <local>`  rsync -avz over ssh
#   * `tunnel_local`, `tunnel_remote`  `<target> <spec>`  ssh -N -L / -R, in the background
#   * `tunnel_socks` `<target> [port]`  ssh -N -D (default port 1080), in the background
#
#   Defaults of a command (keep-alive of a tunnel, the timeout of `check`) are
#   put **after** the options you give, and ssh keeps the first value it sees,
#   so your own `--timeout` or `--keepalive` always wins.
# @option -n | --dry-run Print the command instead of running it.
# @option -p | --port <n> Port of the server (`-p` for ssh, `-P` for scp and sftp).
# @option -i | --identity <file> Private key (`-i`); it must exist unless this is a dry run.
# @option -J | --jump <hosts> ProxyJump list; for ssh-copy-id it becomes `-o ProxyJump=`.
# @option -F | --config <file> Alternative ssh config file; it must exist unless this is a dry run.
# @option -o | --option <k=v> An ssh option, repeatable.
# @option --timeout <sec> `-o ConnectTimeout=<sec>`.
# @option --keepalive <sec> `-o ServerAliveInterval=<sec>` with `ServerAliveCountMax` from SHELL_SSH_KEEPALIVE_COUNT.
# @option --batch `-o BatchMode=yes`.
# @option --accept-new `-o StrictHostKeyChecking=accept-new`.
# @option -v | --verbose `-v`, repeatable (ssh, scp, sftp).
# @option -q | --quiet `-q` (ssh, scp, sftp).
# @option -C | --compress `-C` (ssh, scp, sftp).
# @option -A | --agent `-A`, forward the agent (ssh).
# @option -X | --x11 `-X`, forward X11 (ssh).
# @option -t | --tty `-t`, force a terminal (ssh).
# @option -r | --recursive `-r` (scp).
# @option --preserve `-p` of scp: keep times and modes (scp).
# @option --delete `--delete` (rsync).
# @option --exclude <pattern> `--exclude` (rsync), repeatable.
# @option --simulate `-n` of rsync: show what it would do (rsync).
# @option --progress `--progress` (rsync).
# @option --foreground Keep the tunnel in this terminal (tunnel modes only).
# @arg $1 string The program.
# @arg $2 string The mode.
# @arg $@ string The caller's own arguments.
# @exitcode 0 The program succeeded (or the dry run printed).
# @exitcode 2 Unknown option, missing value, wrong number of arguments or an unsafe argument.
# @exitcode 3 The program, a file given with -i, -F or as a source, is missing.
# @exitcode N Exit status of the program (for `check`: 1 when it cannot connect).
# @example
#   shell::ssh::cmd ssh connect -p 2222 deploy@web1 uptime
#   shell::ssh::cmd scp upload -r ./site deploy@web1:/var/www
#
shell::ssh::cmd() {
	local program="${1-}" mode="${2-}"
	shift 2

	local dry_run="false" foreground="false" port_flag="-p"
	local port="" identity="" config="" jump=""
	local target="" script="" remote="" stdin_file="" dest="" e_cmd="" flag="" spec="" arg="" count=0 index=0 rc=0
	local -a opts=() sync=() sources=() invocation=() run=()

	case "$program" in
	scp | sftp) port_flag="-P" ;;
	esac

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
		-p | --port)
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			if ! shell::net::port::valid "$2"; then
				shell::logger::error "Invalid port: '$2' (1-65535)"
				return "$RETURN_INVALID"
			fi
			port="$2"
			shift 2
			;;
		-i | --identity)
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			case "$2" in
			'' | -*)
				shell::logger::error "Invalid identity file: '$2'"
				return "$RETURN_INVALID"
				;;
			esac
			identity="$2"
			shift 2
			;;
		-F | --config)
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			case "$2" in
			'' | -*)
				shell::logger::error "Invalid config file: '$2'"
				return "$RETURN_INVALID"
				;;
			esac
			config="$2"
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
			opts+=(-o "$2")
			shift 2
			;;
		--timeout)
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			shell::ssh::cmd::number "$1" "$2" || return "$RETURN_INVALID"
			opts+=(-o "ConnectTimeout=$2")
			shift 2
			;;
		--keepalive)
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			shell::ssh::cmd::number "$1" "$2" || return "$RETURN_INVALID"
			opts+=(-o "ServerAliveInterval=$2" -o "ServerAliveCountMax=$SHELL_SSH_KEEPALIVE_COUNT")
			shift 2
			;;
		--batch)
			opts+=(-o "BatchMode=yes")
			shift
			;;
		--accept-new)
			opts+=(-o "StrictHostKeyChecking=accept-new")
			shift
			;;
		-v | --verbose | -q | --quiet | -C | --compress)
			shell::ssh::cmd::allow "$program" verbose "$1" || return "$RETURN_INVALID"
			case "$1" in
			-v | --verbose) opts+=(-v) ;;
			-q | --quiet) opts+=(-q) ;;
			*) opts+=(-C) ;;
			esac
			shift
			;;
		-A | --agent | -X | --x11 | -t | --tty)
			shell::ssh::cmd::allow "$program" session "$1" || return "$RETURN_INVALID"
			case "$1" in
			-A | --agent) opts+=(-A) ;;
			-X | --x11) opts+=(-X) ;;
			*) opts+=(-t) ;;
			esac
			shift
			;;
		-r | --recursive | --preserve)
			shell::ssh::cmd::allow "$program" copy "$1" || return "$RETURN_INVALID"
			case "$1" in
			--preserve) opts+=(-p) ;;
			*) opts+=(-r) ;;
			esac
			shift
			;;
		--delete | --simulate | --progress)
			shell::ssh::cmd::allow "$program" sync "$1" || return "$RETURN_INVALID"
			case "$1" in
			--simulate) sync+=(-n) ;;
			*) sync+=("$1") ;;
			esac
			shift
			;;
		--exclude)
			shell::ssh::cmd::allow "$program" sync "$1" || return "$RETURN_INVALID"
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			if [ -z "$2" ]; then
				shell::logger::error "The --exclude pattern cannot be empty"
				return "$RETURN_INVALID"
			fi
			sync+=(--exclude "$2")
			shift 2
			;;
		--foreground)
			case "$mode" in
			tunnel_*) foreground="true" ;;
			*)
				shell::logger::error "Option --foreground is only for tunnels"
				return "$RETURN_INVALID"
				;;
			esac
			shift
			;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
	done

	if [ -n "$port" ]; then
		opts+=("$port_flag" "$port")
	fi
	if [ -n "$identity" ]; then
		opts+=(-i "$identity")
	fi
	if [ -n "$config" ]; then
		opts+=(-F "$config")
	fi
	if [ -n "$jump" ]; then
		if [ "$program" = "ssh-copy-id" ]; then
			opts+=(-o "ProxyJump=$jump")
		else
			opts+=(-J "$jump")
		fi
	fi

	if [ "$dry_run" = "false" ]; then
		if [ -n "$identity" ] && [ ! -f "$identity" ]; then
			shell::logger::error "Identity file not found: $identity"
			return "$RETURN_NOT_FOUND"
		fi
		if [ -n "$config" ] && [ ! -f "$config" ]; then
			shell::logger::error "Config file not found: $config"
			return "$RETURN_NOT_FOUND"
		fi
	fi

	case "$mode" in
	connect | exec)
		count=1
		if [ "$mode" = "exec" ]; then
			count=2
		fi
		if [ "$#" -lt "$count" ]; then
			if [ "$mode" = "exec" ]; then
				shell::logger::error "A target and a command are required"
			else
				shell::logger::error "A target ([user@]host or an alias) is required"
			fi
			return "$RETURN_INVALID"
		fi
		target="$1"
		shift
		if ! shell::ssh::target::valid "$target"; then
			shell::logger::error "Invalid target: '$target'"
			return "$RETURN_INVALID"
		fi
		invocation=("$program" ${opts[@]+"${opts[@]}"} "$target" "$@")
		;;
	script)
		if [ "$#" -lt 2 ]; then
			shell::logger::error "A target and a script file are required"
			return "$RETURN_INVALID"
		fi
		target="$1"
		script="$2"
		shift 2
		if ! shell::ssh::target::valid "$target"; then
			shell::logger::error "Invalid target: '$target'"
			return "$RETURN_INVALID"
		fi
		if [ "$dry_run" = "false" ] && [ ! -f "$script" ]; then
			shell::logger::error "Script not found: $script"
			return "$RETURN_NOT_FOUND"
		fi
		remote="bash -s"
		if [ "$#" -gt 0 ]; then
			remote="bash -s -- $(shell::ssh::quote "$@")"
		fi
		invocation=("$program" ${opts[@]+"${opts[@]}"} "$target" "$remote")
		stdin_file="$script"
		;;
	target | check | mux_check | mux_exit)
		if [ "$#" -ne 1 ]; then
			shell::logger::error "Exactly one target ([user@]host or an alias) is required"
			return "$RETURN_INVALID"
		fi
		target="$1"
		if ! shell::ssh::target::valid "$target"; then
			shell::logger::error "Invalid target: '$target'"
			return "$RETURN_INVALID"
		fi
		case "$mode" in
		check) invocation=("$program" ${opts[@]+"${opts[@]}"} -o "BatchMode=yes" -o "ConnectTimeout=$SHELL_SSH_CHECK_TIMEOUT" "$target" true) ;;
		mux_check) invocation=("$program" -O check ${opts[@]+"${opts[@]}"} "$target") ;;
		mux_exit) invocation=("$program" -O exit ${opts[@]+"${opts[@]}"} "$target") ;;
		*) invocation=("$program" ${opts[@]+"${opts[@]}"} "$target") ;;
		esac
		;;
	upload | push | download | pull)
		if [ "$#" -lt 2 ]; then
			case "$mode" in
			upload | push) shell::logger::error "At least one file or directory to send and a remote destination ([user@]host:path) are required" ;;
			*) shell::logger::error "At least one remote source ([user@]host:path) and a local destination are required" ;;
			esac
			return "$RETURN_INVALID"
		fi
		count="$#"
		index=0
		for arg in "$@"; do
			index=$((index + 1))
			if [ "$index" -eq "$count" ]; then
				dest="$arg"
			else
				sources+=("$arg")
			fi
		done
		case "$mode" in
		upload | push)
			if ! shell::ssh::spec::valid "$dest"; then
				shell::logger::error "Invalid remote destination: '$dest' (expected [user@]host:path)"
				return "$RETURN_INVALID"
			fi
			;;
		*)
			for arg in "${sources[@]}"; do
				if ! shell::ssh::spec::valid "$arg"; then
					shell::logger::error "Invalid remote source: '$arg' (expected [user@]host:path)"
					return "$RETURN_INVALID"
				fi
			done
			if [ "${#sources[@]}" -gt 1 ] && [ "$dry_run" = "false" ] && [ ! -d "$dest" ]; then
				shell::logger::error "Several sources need an existing local directory as destination: $dest"
				return "$RETURN_INVALID"
			fi
			dest="$(shell::ssh::path::local "$dest")"
			;;
		esac
		case "$mode" in
		upload | push)
			local -a locals=()
			for arg in "${sources[@]}"; do
				if [ "$dry_run" = "false" ] && [ ! -e "$arg" ]; then
					shell::logger::error "Not found: $arg"
					return "$RETURN_NOT_FOUND"
				fi
				locals+=("$(shell::ssh::path::local "$arg")")
			done
			sources=("${locals[@]}")
			;;
		esac
		case "$program" in
		rsync)
			e_cmd="ssh"
			if [ "${#opts[@]}" -gt 0 ]; then
				e_cmd="ssh $(shell::ssh::quote "${opts[@]}")"
			fi
			invocation=(rsync -avz ${sync[@]+"${sync[@]}"} -e "$e_cmd" -- "${sources[@]}" "$dest")
			;;
		*) invocation=("$program" ${opts[@]+"${opts[@]}"} -- "${sources[@]}" "$dest") ;;
		esac
		;;
	tunnel_local | tunnel_remote | tunnel_socks)
		if [ "$mode" = "tunnel_socks" ]; then
			if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
				shell::logger::error "Usage: <target> [port]"
				return "$RETURN_INVALID"
			fi
			spec="${2:-1080}"
			if ! shell::net::port::valid "$spec"; then
				shell::logger::error "Invalid SOCKS port: '$spec' (1-65535)"
				return "$RETURN_INVALID"
			fi
			flag="-D"
		else
			if [ "$#" -ne 2 ]; then
				shell::logger::error "Usage: <target> <spec>"
				return "$RETURN_INVALID"
			fi
			spec="$2"
			if ! shell::ssh::forward::valid "$spec"; then
				shell::logger::error "Invalid forwarding spec: '$spec' (expected [bind:]port:host:hostport or [bind:]port:/socket)"
				return "$RETURN_INVALID"
			fi
			flag="-L"
			if [ "$mode" = "tunnel_remote" ]; then
				flag="-R"
			fi
		fi
		target="$1"
		if ! shell::ssh::target::valid "$target"; then
			shell::logger::error "Invalid target: '$target'"
			return "$RETURN_INVALID"
		fi
		invocation=("$program" -N -T)
		if [ "$foreground" = "false" ]; then
			invocation+=(-f)
		fi
		invocation+=(${opts[@]+"${opts[@]}"} -o "ExitOnForwardFailure=yes" -o "ServerAliveInterval=$SHELL_SSH_KEEPALIVE_INTERVAL" -o "ServerAliveCountMax=$SHELL_SSH_KEEPALIVE_COUNT" "$flag" "$spec" "$target")
		;;
	*)
		shell::logger::error "Unknown mode: '$mode'"
		return "$RETURN_NOT_IMPLEMENTED"
		;;
	esac

	if [ "$dry_run" = "true" ]; then
		run+=(-n)
	fi
	if [ -n "$stdin_file" ]; then
		run+=(--stdin "$stdin_file")
	fi
	if [ "$dry_run" = "false" ]; then
		if [ "$program" = "rsync" ] || [ "$mode" = "check" ]; then
			shell::dependency::ensure ssh || return "$RETURN_NOT_FOUND"
		fi
	fi

	shell::ssh::invoke ${run[@]+"${run[@]}"} "${invocation[@]}" || rc=$?

	if [ "$dry_run" = "false" ]; then
		case "$mode" in
		check)
			if [ "$rc" -eq 0 ]; then
				shell::logger::success "$target is reachable and accepted the login"
			else
				shell::logger::error "Cannot log in to $target (ssh exit status $rc). Try again with -v, or --accept-new for a host seen for the first time."
				rc="$RETURN_FAILURE"
			fi
			;;
		tunnel_*)
			if [ "$rc" -eq 0 ] && [ "$foreground" = "false" ]; then
				shell::logger::success "Tunnel is up: $flag $spec via $target (list: shell::ssh::tunnel::list, stop: shell::ssh::tunnel::kill::fzf)"
			fi
			;;
		esac
	fi
	return "$rc"
}

# --------------------------------------------------------------------------
# Connecting
# --------------------------------------------------------------------------

# @description Open an SSH session, or run one command on the server (`ssh [user@]host [command]`).
#   The target is `user@host`, `host`, or a `Host` alias of `~/.ssh/config`. Words
#   after the target are the remote command; like ssh, they are joined with spaces
#   and parsed by the remote shell, so give one quoted string when you need a
#   pipe or a redirect.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -p | --port <n> Server port.
# @option -i | --identity <file> Private key.
# @option -J | --jump <hosts> Jump host(s).
# @arg $1 string The target.
# @arg $@ string Optional remote command.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, no target, or an unsafe argument.
# @exitcode 3 ssh, or a file given with -i or -F, is missing.
# @exitcode N Exit status of ssh (255 when it cannot connect).
# @see shell::ssh::cmd
# @see shell::ssh::connect::fzf
# @example
#   shell::ssh::connect deploy@10.0.0.5
#   shell::ssh::connect -p 2222 -i ~/.ssh/id_ed25519 deploy@10.0.0.5 uptime
#   shell::ssh::connect -J bastion deploy@10.0.0.5
#
shell::ssh::connect() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Open an SSH session, or run one command on the server (ssh)"
		shell::logger::usage "shell::ssh::connect [-n] [options] <[user@]host|alias> [command...]"
		shell::logger::item "target" "user@host, host, or a Host alias of ~/.ssh/config"
		shell::logger::item "command" "Optional remote command (joined and parsed by the remote shell, as ssh does)"
		shell::ssh::cmd::help ssh
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::connect -p 2222 -i ~/.ssh/id_ed25519 deploy@10.0.0.5"
		shell::logger::example "shell::ssh::connect -J bastion deploy@10.0.0.5 uptime"
		return "$RETURN_SUCCESS"
	fi
	shell::ssh::cmd ssh connect "$@"
}

# @description Run a command on the server and return (`ssh [user@]host command`).
#   Same as `shell::ssh::connect` with a command, except that the command is
#   mandatory. Add `-t` for commands that need a terminal, such as `sudo`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -t | --tty Force a terminal.
# @arg $1 string The target.
# @arg $@ string The remote command (one or more words).
# @exitcode 0 Success.
# @exitcode 2 Unknown option, no target or no command, or an unsafe argument.
# @exitcode 3 ssh, or a file given with -i or -F, is missing.
# @exitcode N Exit status of the remote command (255 when ssh cannot connect).
# @see shell::ssh::cmd
# @example
#   shell::ssh::exec deploy@web1 'df -h'
#   shell::ssh::exec -t deploy@web1 sudo systemctl restart nginx
#
shell::ssh::exec() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Run a command on the server and return (ssh host command)"
		shell::logger::usage "shell::ssh::exec [-n] [options] <[user@]host|alias> <command...>"
		shell::logger::item "target" "user@host, host, or a Host alias of ~/.ssh/config"
		shell::logger::item "command" "Remote command (joined and parsed by the remote shell, as ssh does)"
		shell::ssh::cmd::help ssh
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::exec deploy@web1 'df -h'"
		shell::logger::example "shell::ssh::exec -t deploy@web1 sudo systemctl restart nginx"
		return "$RETURN_SUCCESS"
	fi
	shell::ssh::cmd ssh exec "$@"
}

# @description Run a local script on the server (`ssh host bash -s < script.sh`).
#   The file is streamed to `bash -s` on the server, so nothing is copied there.
#   Extra arguments become the script's `$1`, `$2` ... and are quoted for you. The
#   server needs `bash`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string The target.
# @arg $2 string The local script.
# @arg $@ string Optional arguments for the script.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, missing arguments, or an unsafe argument.
# @exitcode 3 ssh or the script is missing.
# @exitcode N Exit status of the script (255 when ssh cannot connect).
# @see shell::ssh::cmd
# @example
#   shell::ssh::script deploy@web1 ./bootstrap.sh
#   shell::ssh::script deploy@web1 ./backup.sh daily "my database"
#
shell::ssh::script() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Run a local script on the server (ssh host bash -s < script)"
		shell::logger::usage "shell::ssh::script [-n] [options] <[user@]host|alias> <script> [args...]"
		shell::logger::item "target" "user@host, host, or a Host alias of ~/.ssh/config"
		shell::logger::item "script" "Local script to run"
		shell::logger::item "args" "Arguments for the script (\$1, \$2 ...)"
		shell::ssh::cmd::help ssh
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::script deploy@web1 ./backup.sh daily"
		return "$RETURN_SUCCESS"
	fi
	shell::ssh::cmd ssh script "$@"
}

# @description Test that a server can be reached and accepts your login.
#   Runs `true` on the server in batch mode (no password prompt) and says whether
#   it worked. The wait is `SHELL_SSH_CHECK_TIMEOUT` seconds unless you pass
#   `--timeout`. A host never seen before fails in batch mode: add `--accept-new`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string The target.
# @exitcode 0 The server accepted the login.
# @exitcode 1 It could not be reached, or refused the login.
# @exitcode 2 Unknown option, no target, or an unsafe argument.
# @exitcode 3 ssh is missing.
# @see shell::ssh::cmd
# @example
#   shell::ssh::check deploy@web1
#   shell::ssh::check --accept-new -p 2222 deploy@web1
#
shell::ssh::check() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Test that a server can be reached and accepts your login"
		shell::logger::usage "shell::ssh::check [-n] [options] <[user@]host|alias>"
		shell::logger::item "target" "user@host, host, or a Host alias of ~/.ssh/config"
		shell::ssh::cmd::help ssh
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::check deploy@web1"
		shell::logger::example "shell::ssh::check --accept-new -p 2222 deploy@web1"
		return "$RETURN_SUCCESS"
	fi
	shell::ssh::cmd ssh check "$@"
}

# @description Print the version of the installed OpenSSH client (`ssh -V`).
# @option -h | --help Show help and return.
# @stdout The version line (ssh prints it on stderr; it is brought to stdout).
# @exitcode 0 Success.
# @exitcode 3 ssh is not installed.
# @example
#   shell::ssh::version
#
shell::ssh::version() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Print the version of the OpenSSH client (ssh -V)"
		shell::logger::usage "shell::ssh::version"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::version"
		return "$RETURN_SUCCESS"
	fi
	shell::dependency::ensure ssh || return "$RETURN_NOT_FOUND"
	ssh -V 2>&1
}

# --------------------------------------------------------------------------
# Multiplexing (ControlMaster)
# --------------------------------------------------------------------------

# @description Tell whether the shared connection to a host is alive (`ssh -O check`).
#   It looks at the control socket your ssh config names (`ControlPath`); write
#   one with `shell::ssh::config::add --mux`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string The target (the alias or the user@host the connection was opened with).
# @exitcode 0 The master connection is running.
# @exitcode 2 Unknown option, no target, or an unsafe argument.
# @exitcode 3 ssh is missing.
# @exitcode N Exit status of ssh (255 when there is no master connection).
# @see shell::ssh::mux::stop
# @see shell::ssh::config::add
# @example
#   shell::ssh::mux::check web1
#
shell::ssh::mux::check() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Tell whether the shared connection to a host is alive (ssh -O check)"
		shell::logger::usage "shell::ssh::mux::check [-n] [options] <[user@]host|alias>"
		shell::logger::item "target" "The alias or user@host the connection was opened with"
		shell::ssh::cmd::help ssh
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::mux::check web1"
		return "$RETURN_SUCCESS"
	fi
	shell::ssh::cmd ssh mux_check "$@"
}

# @description Close the shared connection to a host (`ssh -O exit`).
#   Sessions already open end with it; the next `ssh` to the host starts a new master.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string The target (the alias or the user@host the connection was opened with).
# @exitcode 0 The master connection was told to exit.
# @exitcode 2 Unknown option, no target, or an unsafe argument.
# @exitcode 3 ssh is missing.
# @exitcode N Exit status of ssh (255 when there is no master connection).
# @see shell::ssh::mux::check
# @example
#   shell::ssh::mux::stop web1
#
shell::ssh::mux::stop() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Close the shared connection to a host (ssh -O exit)"
		shell::logger::usage "shell::ssh::mux::stop [-n] [options] <[user@]host|alias>"
		shell::logger::item "target" "The alias or user@host the connection was opened with"
		shell::ssh::cmd::help ssh
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::mux::stop web1"
		return "$RETURN_SUCCESS"
	fi
	shell::ssh::cmd ssh mux_exit "$@"
}
