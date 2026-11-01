#!/usr/bin/env bash
# @file lib/ssh_known_hosts.sh
# @brief The known_hosts file: look a host up, forget it, or learn its keys.
# @description
#   `known_hosts` is where ssh remembers the key of every server it has met, so that
#   it can tell when a server is replaced by an impostor.
#
#   Things worth knowing:
#
#   * `shell::ssh::known_hosts::remove` is the cure for "WARNING: REMOTE HOST
#     IDENTIFICATION HAS CHANGED!" **after you have checked that the change is
#     legitimate** (a reinstalled server, a new IP). ssh-keygen keeps the old file
#     as `known_hosts.old`.
#   * A host on a port other than 22 is stored as `[host]:port`; the commands add
#     the brackets for you when you pass `-p`.
#   * `shell::ssh::known_hosts::scan --add` trusts whatever the server answers *right
#     now*, which is exactly the "yes" you would type at the first connection. It
#     prints the fingerprints so you can compare them with the ones the server owner
#     gave you, and never replaces a host that is already known. For unattended
#     setups it is a convenience; for anything sensitive compare the fingerprints.
#   * The file used is `SHELL_SSH_KNOWN_HOSTS_FILE` unless you pass `-f`.

# @internal
# @description Tell whether a string is a host as known_hosts spells it: `host`, `1.2.3.4` or `[host]:port`.
# @arg $1 string The candidate.
# @exitcode 0 It is safe.
# @exitcode 1 It is not.
# @example
#   shell::ssh::known_hosts::host::valid "[example.com]:2222" && echo ok
#
shell::ssh::known_hosts::host::valid() {
	case "${1-}" in
	'' | -* | *[!]A-Za-z0-9._:[-]*) return 1 ;;
	esac
	return 0
}

# @internal
# @description Print the name known_hosts uses for a host, given an optional port.
#   Port 22 or none: the host itself. Another port: `[host]:port`.
# @arg $1 string The host.
# @arg $2 string The port (optional).
# @stdout The name.
# @exitcode 0 Always.
# @example
#   shell::ssh::known_hosts::name example.com 2222   # -> [example.com]:2222
#
shell::ssh::known_hosts::name() {
	case "${2-}" in
	'' | 22) printf '%s\n' "${1-}" ;;
	*) printf '[%s]:%s\n' "${1-}" "$2" ;;
	esac
}

# @description Look a host up in known_hosts (`ssh-keygen -F host`).
#   Prints the stored key line(s) when the host is known.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -p | --port <n> The port the host listens on (looked up as `[host]:port`).
# @option -f | --file <path> Another known_hosts file.
# @arg $1 string The host name or address.
# @stdout The stored key line(s).
# @exitcode 0 The host is known.
# @exitcode 2 Unknown option, no host, or an invalid host or port.
# @exitcode 3 ssh-keygen is missing, or the host is not in the file.
# @example
#   shell::ssh::known_hosts::find github.com
#   shell::ssh::known_hosts::find -p 2222 10.0.0.5
#
shell::ssh::known_hosts::find() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Look a host up in known_hosts (ssh-keygen -F)"
		shell::logger::usage "shell::ssh::known_hosts::find [-n] [-p <port>] [-f <file>] <host>"
		shell::logger::item "host" "Host name or address"
		shell::logger::option "-p, --port <n>" "Port of the host (looked up as [host]:port)"
		shell::logger::option "-f, --file <path>" "Another known_hosts file"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::known_hosts::find github.com"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" port="" file="$SHELL_SSH_KNOWN_HOSTS_FILE"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
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
		-f | --file)
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			file="$2"
			shift 2
			;;
		--)
			shift
			break
			;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
	done

	if [ "$#" -ne 1 ] || ! shell::ssh::known_hosts::host::valid "$1"; then
		shell::logger::error "Exactly one valid host is required"
		return "$RETURN_INVALID"
	fi
	local name
	name="$(shell::ssh::known_hosts::name "$1" "$port")"

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$(shell::ssh::quote ssh-keygen -F "$name" -f "$file")"
		return "$RETURN_SUCCESS"
	fi
	shell::dependency::ensure ssh-keygen || return "$RETURN_NOT_FOUND"
	if [ ! -f "$file" ]; then
		shell::logger::warn "No known_hosts file at $file"
		return "$RETURN_NOT_FOUND"
	fi
	if ! ssh-keygen -F "$name" -f "$file"; then
		shell::logger::warn "$name is not in $file"
		return "$RETURN_NOT_FOUND"
	fi
	return "$RETURN_SUCCESS"
}

# @description Forget a host (`ssh-keygen -R host`).
#   Use it after a server was reinstalled or got a new key, and you have checked that
#   this is legitimate. The previous file is kept as `known_hosts.old`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -p | --port <n> The port the host listens on (removed as `[host]:port`).
# @option -f | --file <path> Another known_hosts file.
# @arg $1 string The host name or address.
# @exitcode 0 The host was removed.
# @exitcode 2 Unknown option, no host, or an invalid host or port.
# @exitcode 3 ssh-keygen is missing, or the host is not in the file.
# @exitcode N Exit status of ssh-keygen.
# @example
#   shell::ssh::known_hosts::remove 10.0.0.5
#   shell::ssh::known_hosts::remove -p 2222 web1.example.com
#
shell::ssh::known_hosts::remove() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Forget a host (ssh-keygen -R)"
		shell::logger::usage "shell::ssh::known_hosts::remove [-n] [-p <port>] [-f <file>] <host>"
		shell::logger::item "host" "Host name or address"
		shell::logger::option "-p, --port <n>" "Port of the host (removed as [host]:port)"
		shell::logger::option "-f, --file <path>" "Another known_hosts file"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "Only do this when you know why the key changed. The old file is kept as known_hosts.old."
		shell::logger::example "shell::ssh::known_hosts::remove 10.0.0.5"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" port="" file="$SHELL_SSH_KNOWN_HOSTS_FILE"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
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
		-f | --file)
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			file="$2"
			shift 2
			;;
		--)
			shift
			break
			;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
	done

	if [ "$#" -ne 1 ] || ! shell::ssh::known_hosts::host::valid "$1"; then
		shell::logger::error "Exactly one valid host is required"
		return "$RETURN_INVALID"
	fi
	local name rc=0
	name="$(shell::ssh::known_hosts::name "$1" "$port")"

	local -a run=()
	if [ "$dry_run" = "true" ]; then
		run+=(-n)
	else
		shell::dependency::ensure ssh-keygen || return "$RETURN_NOT_FOUND"
		if [ ! -f "$file" ]; then
			shell::logger::warn "No known_hosts file at $file"
			return "$RETURN_NOT_FOUND"
		fi
		# ssh-keygen -R exits 0 even when the host is not listed, so look first.
		if ! ssh-keygen -F "$name" -f "$file" >/dev/null 2>&1; then
			shell::logger::warn "$name is not in $file"
			return "$RETURN_NOT_FOUND"
		fi
	fi
	shell::ssh::invoke ${run[@]+"${run[@]}"} ssh-keygen -R "$name" -f "$file" || rc=$?
	return "$rc"
}

# @description Fetch the public keys of servers (`ssh-keyscan host`), and optionally trust them.
#   Without `--add` the keys are only printed. With `--add` each host that is not yet
#   in known_hosts gets its keys appended (hashed, as `HashKnownHosts` does), after the
#   fingerprints are printed for you to check; known hosts are left alone. See the
#   file description for what that trusts.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the commands instead of running them.
# @option -p | --port <n> The port the servers listen on.
# @option -t | --type <list> Key types to fetch, comma separated (e.g. `ed25519,rsa`).
# @option -f | --file <path> Another known_hosts file (with --add).
# @option --add Append the keys of unknown hosts to known_hosts.
# @arg $@ string One or more host names or addresses.
# @stdout The keys, in known_hosts format (without --add).
# @exitcode 0 Success.
# @exitcode 1 No key was received from at least one host.
# @exitcode 2 Unknown option, no host, or an invalid host, port or type.
# @exitcode 3 ssh-keyscan or ssh-keygen is missing.
# @example
#   shell::ssh::known_hosts::scan github.com
#   shell::ssh::known_hosts::scan --add -t ed25519 git.example.com
#   shell::ssh::known_hosts::scan --add -p 2222 10.0.0.5
#
shell::ssh::known_hosts::scan() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Fetch the public keys of servers (ssh-keyscan), and optionally trust them"
		shell::logger::usage "shell::ssh::known_hosts::scan [-n] [-p <port>] [-t <types>] [-f <file>] [--add] <host>..."
		shell::logger::item "host" "One or more host names or addresses"
		shell::logger::option "-p, --port <n>" "Port the servers listen on"
		shell::logger::option "-t, --type <list>" "Key types to fetch, comma separated (ed25519,rsa ...)"
		shell::logger::option "-f, --file <path>" "Another known_hosts file (with --add)"
		shell::logger::option "--add" "Append the keys of unknown hosts to known_hosts"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "--add trusts what the server answers now: compare the printed fingerprints with the owner's."
		shell::logger::example "shell::ssh::known_hosts::scan github.com"
		shell::logger::example "shell::ssh::known_hosts::scan --add -t ed25519 git.example.com"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" add="false" port="" types="" file="$SHELL_SSH_KNOWN_HOSTS_FILE"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		--add)
			add="true"
			shift
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
		-t | --type)
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			case "$2" in
			'' | -* | *[!a-z0-9,-]*)
				shell::logger::error "Invalid key type list: '$2' (e.g. ed25519,rsa)"
				return "$RETURN_INVALID"
				;;
			esac
			types="$2"
			shift 2
			;;
		-f | --file)
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			file="$2"
			shift 2
			;;
		--)
			shift
			break
			;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
	done

	if [ "$#" -eq 0 ]; then
		shell::logger::error "At least one host is required"
		return "$RETURN_INVALID"
	fi
	local host name tmp scanned parent rc=0
	for host in "$@"; do
		if ! shell::ssh::known_hosts::host::valid "$host"; then
			shell::logger::error "Invalid host: '$host'"
			return "$RETURN_INVALID"
		fi
	done

	local -a scan=(ssh-keyscan)
	if [ -n "$port" ]; then
		scan+=(-p "$port")
	fi
	if [ -n "$types" ]; then
		scan+=(-t "$types")
	fi
	if [ "$add" = "true" ]; then
		scan+=(-H)
	fi

	if [ "$dry_run" = "true" ]; then
		for host in "$@"; do
			if [ "$add" = "true" ]; then
				shell::logger::command_clip "$(shell::ssh::quote "${scan[@]}" "$host") >> $(shell::ssh::quote "$file")"
			else
				shell::logger::command_clip "$(shell::ssh::quote "${scan[@]}" "$host")"
			fi
		done
		return "$RETURN_SUCCESS"
	fi

	shell::dependency::ensure ssh-keyscan || return "$RETURN_NOT_FOUND"
	if [ "$add" = "true" ]; then
		shell::dependency::ensure ssh-keygen || return "$RETURN_NOT_FOUND"
		case "$file" in
		*/*) parent="${file%/*}" ;;
		*) parent="." ;;
		esac
		shell::fs::mkdir --private "$parent" || return "$RETURN_FAILURE"
	fi

	for host in "$@"; do
		scanned="$("${scan[@]}" "$host" 2>/dev/null)"
		if [ -z "$scanned" ]; then
			shell::logger::error "No host key received from $host"
			rc="$RETURN_FAILURE"
			continue
		fi
		if [ "$add" = "false" ]; then
			printf '%s\n' "$scanned"
			continue
		fi

		name="$(shell::ssh::known_hosts::name "$host" "$port")"
		if [ -f "$file" ] && ssh-keygen -F "$name" -f "$file" >/dev/null 2>&1; then
			shell::logger::info "$name is already in $file, left unchanged"
			continue
		fi
		tmp="$(mktemp "$(shell::os::temp_dir)/shell-ssh-scan.XXXXXX")" || return "$RETURN_FAILURE"
		printf '%s\n' "$scanned" >"$tmp"
		shell::logger::info "Keys received from $name (compare these fingerprints with the owner's):"
		ssh-keygen -l -f "$tmp"
		if cat "$tmp" >>"$file"; then
			shell::logger::success "Added $name to $file"
		else
			shell::logger::error "Could not write $file"
			rc="$RETURN_FAILURE"
		fi
		rm -f "$tmp"
	done
	return "$rc"
}
