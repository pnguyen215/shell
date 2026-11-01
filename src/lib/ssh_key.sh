#!/usr/bin/env bash
# @file lib/ssh_key.sh
# @brief SSH keys: install on a server, derive the public key, fingerprints, passphrase, comment, and the permissions ssh insists on.
# @description
#   Complements lib/ssh.sh (which generates, views, renames and removes key files)
#   with the other key commands of the SSH cheat sheets. The agent has its own
#   file (lib/ssh_agent.sh) and so have known_hosts (lib/ssh_known_hosts.sh) and
#   `~/.ssh/config` (lib/ssh_config.sh).
#
#   Things worth knowing:
#
#   * No passphrase is ever taken on the command line (it would show up in `ps` and
#     in your history): commands that need one let ssh-keygen ask for it.
#   * `shell::ssh::key::public` and `shell::ssh::key::fingerprint` print data and
#     nothing else, so they are safe inside `$( ... )`.
#   * `shell::ssh::permission::fix` is the answer to "Permissions 0644 for
#     '~/.ssh/id_rsa' are too open" and to "Bad owner or permissions on
#     ~/.ssh/config": it sets 700 on the directory, 600 on private keys, the
#     config and authorized_keys, and 644 on public keys and known_hosts.

# @internal
# @description Print the private key files of an SSH directory, one per line.
#   A regular file qualifies when its first line is a `-----BEGIN ... PRIVATE KEY-----`
#   marker (OpenSSH, RSA, EC, PKCS8, encrypted or not). Public keys, `config`,
#   `known_hosts*`, `authorized_keys*`, backups and everything else are skipped.
# @arg $1 string Directory (default: SHELL_SSH_DIR).
# @stdout The paths, sorted.
# @exitcode 0 The directory exists (the list may be empty).
# @exitcode 3 The directory does not exist.
# @example
#   shell::ssh::key::candidates
#
shell::ssh::key::candidates() {
	local dir="${1:-$SHELL_SSH_DIR}" file name
	if [ ! -d "$dir" ]; then
		return "$RETURN_NOT_FOUND"
	fi
	while IFS= read -r file; do
		name="${file##*/}"
		case "$name" in
		config | known_hosts* | authorized_keys* | environment | rc | *.bak | *.old) continue ;;
		esac
		if head -n 1 "$file" 2>/dev/null | grep -q -- '-----BEGIN .*PRIVATE KEY-----'; then
			printf '%s\n' "$file"
		fi
	done <<EOF
$(find "$dir" -maxdepth 1 -type f ! -name '*.pub' | sort)
EOF
	return "$RETURN_SUCCESS"
}

# @description Install your public key on a server (`ssh-copy-id [-i key.pub] [user@]host`).
#   After this, `ssh host` logs in with the key instead of the password. ssh-copy-id
#   skips keys the server already has.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -i | --identity <file> The key to install (default: the agent's keys, or ~/.ssh/id_*.pub).
# @option -p | --port <n> Server port.
# @arg $1 string The target.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, no target, or an unsafe argument.
# @exitcode 3 ssh-copy-id, or the key given with -i, is missing.
# @exitcode N Exit status of ssh-copy-id.
# @see shell::ssh::cmd
# @see shell::ssh::key::generate
# @example
#   shell::ssh::key::copy_id deploy@web1
#   shell::ssh::key::copy_id -i ~/.ssh/id_ed25519.pub -p 2222 deploy@web1
#
shell::ssh::key::copy_id() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Install your public key on a server (ssh-copy-id)"
		shell::logger::usage "shell::ssh::key::copy_id [-n] [options] <[user@]host|alias>"
		shell::logger::item "target" "user@host, host, or a Host alias of ~/.ssh/config"
		shell::ssh::cmd::help ssh-copy-id
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::key::copy_id deploy@web1"
		shell::logger::example "shell::ssh::key::copy_id -i ~/.ssh/id_ed25519.pub -p 2222 deploy@web1"
		return "$RETURN_SUCCESS"
	fi
	shell::ssh::cmd ssh-copy-id target "$@"
}

# @description Print the public key of a private key (`ssh-keygen -y -f key`).
#   Handy when the `.pub` file is lost. With `--save` the result is written to
#   `<key>.pub` (mode 644) instead of printed; an existing file is kept unless you
#   add `--force`. ssh-keygen asks for the passphrase when the key has one.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -s | --save Write `<key>.pub` instead of printing.
# @option --force Overwrite an existing `<key>.pub` (with --save).
# @arg $1 string The private key file.
# @stdout The public key line (without --save).
# @exitcode 0 Success.
# @exitcode 1 ssh-keygen failed (wrong passphrase, not a key ...).
# @exitcode 2 Unknown option, or no key.
# @exitcode 3 ssh-keygen or the key is missing.
# @exitcode 7 `<key>.pub` exists and --force was not given.
# @example
#   shell::ssh::key::public ~/.ssh/id_ed25519
#   shell::ssh::key::public --save ~/.ssh/id_ed25519
#
shell::ssh::key::public() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Print the public key of a private key (ssh-keygen -y)"
		shell::logger::usage "shell::ssh::key::public [-n] [-s] [--force] <private_key>"
		shell::logger::item "private_key" "The private key file"
		shell::logger::option "-s, --save" "Write <private_key>.pub instead of printing"
		shell::logger::option "--force" "Overwrite an existing .pub file (with --save)"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::key::public ~/.ssh/id_ed25519"
		shell::logger::example "shell::ssh::key::public --save ~/.ssh/id_ed25519"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" save="false" force="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-s | --save) save="true" ;;
		--force) force="true" ;;
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
		shift
	done

	local key="${1-}"
	if [ -z "$key" ] || [ "$#" -gt 1 ]; then
		shell::logger::error "Exactly one private key file is required"
		return "$RETURN_INVALID"
	fi

	local pub="$key.pub"
	if [ "$dry_run" = "true" ]; then
		local line
		line="$(shell::ssh::quote ssh-keygen -y -f "$key")"
		if [ "$save" = "true" ]; then
			line="$line > $(shell::ssh::quote "$pub")"
		fi
		shell::logger::command_clip "$line"
		return "$RETURN_SUCCESS"
	fi

	shell::dependency::ensure ssh-keygen || return "$RETURN_NOT_FOUND"
	if [ ! -f "$key" ]; then
		shell::logger::error "Key not found: $key"
		return "$RETURN_NOT_FOUND"
	fi

	if [ "$save" = "false" ]; then
		ssh-keygen -y -f "$key" || return "$RETURN_FAILURE"
		return "$RETURN_SUCCESS"
	fi

	if [ -e "$pub" ] && [ "$force" = "false" ]; then
		shell::logger::warn "$pub already exists (use --force to overwrite it)"
		return "$RETURN_EXISTS"
	fi

	local tmp rc=0
	tmp="$(mktemp "$(shell::os::temp_dir)/shell-ssh-pub.XXXXXX")" || return "$RETURN_FAILURE"
	ssh-keygen -y -f "$key" >"$tmp" || rc=$?
	if [ "$rc" -ne 0 ] || [ ! -s "$tmp" ]; then
		rm -f "$tmp"
		shell::logger::error "Could not read the public key of $key"
		return "$RETURN_FAILURE"
	fi
	(umask 022 && cat "$tmp" >"$pub") || rc=$?
	rm -f "$tmp"
	if [ "$rc" -ne 0 ]; then
		shell::logger::error "Could not write $pub"
		return "$RETURN_FAILURE"
	fi
	shell::logger::success "Wrote $pub"
	return "$RETURN_SUCCESS"
}

# @description Show the fingerprint of SSH keys (`ssh-keygen -l -f key`).
#   Without arguments it covers every public key in `~/.ssh`. The fingerprint is
#   what to compare with the one a server or GitHub shows. Prints data only, so it
#   can be used inside `$( ... )`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the commands instead of running them.
# @option --md5 Show the old MD5 form instead of SHA256.
# @arg $@ string Optional key files (private or public).
# @stdout One line per key: bits, fingerprint, comment, type.
# @exitcode 0 Success.
# @exitcode 1 ssh-keygen failed for at least one key.
# @exitcode 2 Unknown option.
# @exitcode 3 ssh-keygen or a key is missing.
# @exitcode 8 No key to show.
# @example
#   shell::ssh::key::fingerprint
#   shell::ssh::key::fingerprint ~/.ssh/id_ed25519.pub
#   shell::ssh::key::fingerprint --md5 ~/.ssh/id_rsa.pub
#
shell::ssh::key::fingerprint() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show the fingerprint of SSH keys (ssh-keygen -l)"
		shell::logger::usage "shell::ssh::key::fingerprint [-n] [--md5] [key...]"
		shell::logger::item "key" "Key files (default: every public key in ~/.ssh)"
		shell::logger::option "--md5" "Show the MD5 fingerprint instead of SHA256"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::key::fingerprint"
		shell::logger::example "shell::ssh::key::fingerprint ~/.ssh/id_ed25519.pub"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" hash="sha256"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		--md5) hash="md5" ;;
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
		shift
	done

	local key rc=0
	local -a keys=() flags=(-l)
	if [ "$hash" = "md5" ]; then
		flags+=(-E md5)
	fi
	if [ "$#" -gt 0 ]; then
		keys=("$@")
	else
		while IFS= read -r key; do
			if [ -n "$key" ]; then
				keys+=("$key")
			fi
		done <<EOF
$(find "$SHELL_SSH_DIR" -maxdepth 1 -type f -name '*.pub' 2>/dev/null | sort)
EOF
	fi
	if [ "${#keys[@]}" -eq 0 ]; then
		shell::logger::warn "No public key found in $SHELL_SSH_DIR"
		return "$RETURN_EMPTY"
	fi

	if [ "$dry_run" = "false" ]; then
		shell::dependency::ensure ssh-keygen || return "$RETURN_NOT_FOUND"
	fi
	for key in "${keys[@]}"; do
		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "$(shell::ssh::quote ssh-keygen "${flags[@]}" -f "$key")"
			continue
		fi
		if [ ! -f "$key" ]; then
			shell::logger::error "Key not found: $key"
			return "$RETURN_NOT_FOUND"
		fi
		ssh-keygen "${flags[@]}" -f "$key" || rc=$?
	done
	if [ "$rc" -ne 0 ]; then
		return "$RETURN_FAILURE"
	fi
	return "$RETURN_SUCCESS"
}

# @description Change the passphrase of a private key (`ssh-keygen -p -f key`).
#   ssh-keygen asks for the old and the new passphrase; an empty new one removes
#   the protection. Nothing is taken on the command line.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string The private key file.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, or no key.
# @exitcode 3 ssh-keygen or the key is missing.
# @exitcode N Exit status of ssh-keygen.
# @example
#   shell::ssh::key::passphrase ~/.ssh/id_ed25519
#
shell::ssh::key::passphrase() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Change the passphrase of a private key (ssh-keygen -p)"
		shell::logger::usage "shell::ssh::key::passphrase [-n] <private_key>"
		shell::logger::item "private_key" "The private key file"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::key::passphrase ~/.ssh/id_ed25519"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi
	if [ "$#" -ne 1 ] || [ -z "$1" ]; then
		shell::logger::error "Exactly one private key file is required"
		return "$RETURN_INVALID"
	fi
	if [ "$dry_run" = "false" ] && [ ! -f "$1" ]; then
		shell::logger::error "Key not found: $1"
		return "$RETURN_NOT_FOUND"
	fi

	local -a run=()
	if [ "$dry_run" = "true" ]; then
		run+=(-n)
	fi
	shell::ssh::invoke ${run[@]+"${run[@]}"} ssh-keygen -p -f "$1"
}

# @description Change the comment stored in a key (`ssh-keygen -c -C comment -f key`).
#   The comment is the free text at the end of the public key (often an e-mail).
#   ssh-keygen asks for the passphrase when the key has one.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string The private key file.
# @arg $2 string The new comment.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, missing arguments, or a comment with control characters.
# @exitcode 3 ssh-keygen or the key is missing.
# @exitcode N Exit status of ssh-keygen.
# @example
#   shell::ssh::key::comment ~/.ssh/id_ed25519 "alice@work-laptop"
#
shell::ssh::key::comment() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Change the comment stored in a key (ssh-keygen -c)"
		shell::logger::usage "shell::ssh::key::comment [-n] <private_key> <comment>"
		shell::logger::item "private_key" "The private key file"
		shell::logger::item "comment" "The new comment"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::key::comment ~/.ssh/id_ed25519 \"alice@work-laptop\""
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi
	if [ "$#" -ne 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
		shell::logger::error "A private key file and a comment are required"
		return "$RETURN_INVALID"
	fi
	case "$2" in
	*[[:cntrl:]]*)
		shell::logger::error "The comment cannot contain control characters"
		return "$RETURN_INVALID"
		;;
	esac
	if [ "$dry_run" = "false" ] && [ ! -f "$1" ]; then
		shell::logger::error "Key not found: $1"
		return "$RETURN_NOT_FOUND"
	fi

	local -a run=()
	if [ "$dry_run" = "true" ]; then
		run+=(-n)
	fi
	shell::ssh::invoke ${run[@]+"${run[@]}"} ssh-keygen -c -C "$2" -f "$1"
}

# --------------------------------------------------------------------------
# Permissions
# --------------------------------------------------------------------------

# @internal
# @description Give a file or directory the mode ssh expects, when it has another one.
#   Symbolic links are left alone (chmod would change their target).
# @arg $1 string `true` for a dry run.
# @arg $2 string The octal mode (700, 600, 644).
# @arg $3 string The path.
# @stdout What is (or would be) changed.
# @exitcode 0 The mode was changed (or would be).
# @exitcode 1 Nothing to do: the path is absent, a link, or already right.
# @example
#   shell::ssh::permission::set false 600 ~/.ssh/config
#
shell::ssh::permission::set() {
	local dry_run="${1-false}" mode="${2-}" target_path="${3-}" current
	if [ ! -e "$target_path" ] || [ -L "$target_path" ]; then
		return 1
	fi
	current="$(shell::fs::stat mode "$target_path")"
	if [ "$current" = "$mode" ]; then
		return 1
	fi
	if [ "$dry_run" = "true" ]; then
		shell::exec::command -n chmod "$mode" "$target_path"
		return 0
	fi
	shell::logger::debug "$target_path: $current -> $mode"
	chmod "$mode" "$target_path" || return 1
	return 0
}

# @description Set the permissions ssh insists on for `~/.ssh` (700 / 600 / 644).
#   Directory 700 (and `sockets` 700), private keys, `config`, `authorized_keys`
#   600, public keys and `known_hosts` 644. Only what differs is changed and
#   reported; links are skipped. Nothing is made more open than it was asked.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the chmod commands instead of running them.
# @option -d | --dir <path> Another SSH directory (default: SHELL_SSH_DIR).
# @exitcode 0 Done (also when nothing needed changing).
# @exitcode 2 Unknown option.
# @exitcode 3 The SSH directory does not exist.
# @see shell::ssh::key::candidates
# @example
#   shell::ssh::permission::fix
#   shell::ssh::permission::fix -n
#
shell::ssh::permission::fix() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Set the permissions ssh insists on for ~/.ssh (700 / 600 / 644)"
		shell::logger::usage "shell::ssh::permission::fix [-n] [-d <dir>]"
		shell::logger::option "-d, --dir <path>" "Another SSH directory (default: ~/.ssh)"
		shell::logger::option "-n, --dry-run" "Print the chmod commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "700 on the directory; 600 on private keys, config, authorized_keys; 644 on public keys and known_hosts."
		shell::logger::example "shell::ssh::permission::fix -n"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" dir="$SHELL_SSH_DIR"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		-d | --dir)
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			dir="$2"
			shift 2
			;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
	done

	if [ ! -d "$dir" ]; then
		shell::logger::warn "No SSH directory at $dir"
		return "$RETURN_NOT_FOUND"
	fi

	local changed=0 file name
	if shell::ssh::permission::set "$dry_run" 700 "$dir"; then
		changed=$((changed + 1))
	fi
	if shell::ssh::permission::set "$dry_run" 700 "$dir/sockets"; then
		changed=$((changed + 1))
	fi
	for name in config authorized_keys authorized_keys2; do
		if shell::ssh::permission::set "$dry_run" 600 "$dir/$name"; then
			changed=$((changed + 1))
		fi
	done
	if shell::ssh::permission::set "$dry_run" 644 "$dir/known_hosts"; then
		changed=$((changed + 1))
	fi
	while IFS= read -r file; do
		if [ -z "$file" ]; then
			continue
		fi
		if shell::ssh::permission::set "$dry_run" 600 "$file"; then
			changed=$((changed + 1))
		fi
	done <<EOF
$(shell::ssh::key::candidates "$dir")
EOF
	while IFS= read -r file; do
		if [ -z "$file" ]; then
			continue
		fi
		if shell::ssh::permission::set "$dry_run" 644 "$file"; then
			changed=$((changed + 1))
		fi
	done <<EOF
$(find "$dir" -maxdepth 1 -type f -name '*.pub' | sort)
EOF

	if [ "$changed" -eq 0 ]; then
		shell::logger::success "Permissions in $dir are already right"
	elif [ "$dry_run" = "false" ]; then
		shell::logger::success "Fixed the permissions of $changed item(s) in $dir"
	fi
	return "$RETURN_SUCCESS"
}
