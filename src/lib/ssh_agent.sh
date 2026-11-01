#!/usr/bin/env bash
# @file lib/ssh_agent.sh
# @brief The ssh agent: start, stop, list, add and remove keys.
# @description
#   The agent keeps decrypted keys in memory, so a passphrase is typed once per
#   session instead of once per connection.
#
#   Things worth knowing:
#
#   * `shell::ssh::agent::start` sets `SSH_AUTH_SOCK` and `SSH_AGENT_PID` in **the
#     shell you call it from**, which is the point (it is what `eval "$(ssh-agent -s)"`
#     does). For that reason do not run it inside `$( ... )` or a pipeline: the
#     variables would be lost with the subshell. `shell::ssh::agent::stop` unsets them.
#   * It does nothing when an agent is already reachable (the one of your desktop,
#     or a forwarded one), so it is safe to call from a profile.
#   * No passphrase is taken on the command line; ssh-add asks for it.
#   * `--lifetime` makes a key leave the agent by itself after that many seconds.
#   * `--keychain` stores the passphrase in the macOS keychain
#     (`ssh-add --apple-use-keychain`); it exists on macOS only.

# @internal
# @description Tell whether an ssh agent can be reached from this shell.
#   `ssh-add -l` answers 0 (keys loaded) or 1 (no keys) when it talks to an agent
#   and 2 when it cannot; only 2 (or a missing ssh-add) means "no agent".
# @exitcode 0 An agent answers.
# @exitcode 1 None does.
# @example
#   shell::ssh::agent::reachable || shell::ssh::agent::start
#
shell::ssh::agent::reachable() {
	local rc=0
	command -v ssh-add >/dev/null 2>&1 || return 1
	ssh-add -l >/dev/null 2>&1 || rc=$?
	[ "$rc" -ne 2 ] && [ "$rc" -ne 127 ]
}

# @description Start an ssh agent in this shell (`eval "$(ssh-agent -s)"`).
#   Sets `SSH_AUTH_SOCK` and `SSH_AGENT_PID` here. Nothing is done when an agent
#   is already reachable. Do not run it in `$( ... )` or a pipeline.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @exitcode 0 An agent is running (started now, or already there).
# @exitcode 1 ssh-agent failed or printed something unexpected.
# @exitcode 3 ssh-agent is missing.
# @see shell::ssh::agent::stop
# @example
#   shell::ssh::agent::start && shell::ssh::agent::add
#
shell::ssh::agent::start() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Start an ssh agent in this shell (eval \"\$(ssh-agent -s)\")"
		shell::logger::usage "shell::ssh::agent::start [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "Sets SSH_AUTH_SOCK and SSH_AGENT_PID in this shell; do not run it inside \$( ) or a pipeline."
		shell::logger::example "shell::ssh::agent::start && shell::ssh::agent::add"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi
	if [ "$#" -gt 0 ]; then
		shell::logger::error "Unexpected argument: $1"
		return "$RETURN_INVALID"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip 'eval "$(ssh-agent -s)"'
		return "$RETURN_SUCCESS"
	fi

	shell::dependency::ensure ssh-agent || return "$RETURN_NOT_FOUND"
	if shell::ssh::agent::reachable; then
		shell::logger::info "An ssh agent is already available (SSH_AUTH_SOCK=${SSH_AUTH_SOCK-})"
		return "$RETURN_SUCCESS"
	fi

	local out sock pid
	out="$(ssh-agent -s)" || {
		shell::logger::error "ssh-agent failed to start"
		return "$RETURN_FAILURE"
	}
	sock="$(printf '%s\n' "$out" | sed -n 's/^SSH_AUTH_SOCK=\([^;]*\);.*/\1/p')"
	pid="$(printf '%s\n' "$out" | sed -n 's/^SSH_AGENT_PID=\([0-9]*\);.*/\1/p')"
	if [ -z "$sock" ] || [ -z "$pid" ]; then
		shell::logger::error "Unexpected output from ssh-agent: $out"
		return "$RETURN_FAILURE"
	fi
	export SSH_AUTH_SOCK="$sock" SSH_AGENT_PID="$pid"
	shell::logger::success "ssh-agent started (pid $pid)"
	return "$RETURN_SUCCESS"
}

# @description Stop the agent this shell started (`ssh-agent -k`).
#   Works from `SSH_AGENT_PID`, so it only stops an agent started with
#   `shell::ssh::agent::start` (or `eval "$(ssh-agent -s)"`) in this shell, never
#   the agent of your desktop session. Unsets `SSH_AUTH_SOCK` and `SSH_AGENT_PID`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @exitcode 0 The agent was stopped.
# @exitcode 1 ssh-agent could not stop it.
# @exitcode 3 ssh-agent is missing, or this shell did not start an agent.
# @see shell::ssh::agent::start
# @example
#   shell::ssh::agent::stop
#
shell::ssh::agent::stop() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Stop the agent this shell started (ssh-agent -k)"
		shell::logger::usage "shell::ssh::agent::stop [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::agent::stop"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi
	if [ "$#" -gt 0 ]; then
		shell::logger::error "Unexpected argument: $1"
		return "$RETURN_INVALID"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "ssh-agent -k"
		return "$RETURN_SUCCESS"
	fi
	if [ -z "${SSH_AGENT_PID-}" ]; then
		shell::logger::warn "This shell did not start an agent (SSH_AGENT_PID is empty)"
		return "$RETURN_NOT_FOUND"
	fi
	shell::dependency::ensure ssh-agent || return "$RETURN_NOT_FOUND"
	ssh-agent -k >/dev/null || {
		shell::logger::error "ssh-agent could not stop pid $SSH_AGENT_PID"
		return "$RETURN_FAILURE"
	}
	unset SSH_AUTH_SOCK SSH_AGENT_PID
	shell::logger::success "ssh-agent stopped"
	return "$RETURN_SUCCESS"
}

# @description List the keys the agent holds (`ssh-add -l`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --public Print the public keys themselves (`ssh-add -L`) instead of fingerprints.
# @stdout One line per key.
# @exitcode 0 The agent holds at least one key.
# @exitcode 1 No agent could be reached.
# @exitcode 3 ssh-add is missing.
# @exitcode 8 The agent holds no key.
# @see shell::ssh::agent::add
# @example
#   shell::ssh::agent::list
#   shell::ssh::agent::list --public
#
shell::ssh::agent::list() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List the keys the agent holds (ssh-add -l)"
		shell::logger::usage "shell::ssh::agent::list [-n] [--public]"
		shell::logger::option "--public" "Print the public keys instead of fingerprints (ssh-add -L)"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::agent::list"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" flag="-l"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		--public) flag="-L" ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "ssh-add $flag"
		return "$RETURN_SUCCESS"
	fi
	shell::dependency::ensure ssh-add || return "$RETURN_NOT_FOUND"

	local out rc=0
	out="$(ssh-add "$flag" 2>&1)" || rc=$?
	case "$rc" in
	0)
		printf '%s\n' "$out"
		return "$RETURN_SUCCESS"
		;;
	1)
		shell::logger::warn "The agent holds no key (add one with shell::ssh::agent::add)"
		return "$RETURN_EMPTY"
		;;
	*)
		shell::logger::error "Cannot reach an ssh agent (start one with shell::ssh::agent::start)"
		return "$RETURN_FAILURE"
		;;
	esac
}

# @description Add keys to the agent (`ssh-add [key...]`).
#   Without a key, ssh-add loads the default ones (`~/.ssh/id_ed25519`, `id_rsa` ...).
#   The agent must be reachable (see `shell::ssh::agent::start`). ssh-add asks for
#   the passphrase; nothing is taken on the command line.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -t | --lifetime <sec> Drop the key from the agent after this many seconds.
# @option --keychain Store the passphrase in the macOS keychain (macOS only).
# @arg $@ string Optional private key files.
# @exitcode 0 Success.
# @exitcode 1 No agent could be reached.
# @exitcode 2 Unknown option or an invalid lifetime.
# @exitcode 3 ssh-add or a key is missing.
# @exitcode 4 `--keychain` was used on another system than macOS.
# @exitcode N Exit status of ssh-add.
# @see shell::ssh::agent::add::fzf
# @example
#   shell::ssh::agent::add
#   shell::ssh::agent::add -t 3600 ~/.ssh/id_ed25519
#
shell::ssh::agent::add() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Add keys to the agent (ssh-add)"
		shell::logger::usage "shell::ssh::agent::add [-n] [-t <sec>] [--keychain] [key...]"
		shell::logger::item "key" "Private key files (default: the standard ones in ~/.ssh)"
		shell::logger::option "-t, --lifetime <sec>" "Drop the key from the agent after this many seconds"
		shell::logger::option "--keychain" "Store the passphrase in the macOS keychain (macOS only)"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::agent::add"
		shell::logger::example "shell::ssh::agent::add -t 3600 ~/.ssh/id_ed25519"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" lifetime="" keychain="false" key
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		-t | --lifetime)
			shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			shell::ssh::cmd::number "$1" "$2" || return "$RETURN_INVALID"
			lifetime="$2"
			shift 2
			;;
		--keychain)
			keychain="true"
			shift
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

	if [ "$keychain" = "true" ] && ! shell::os::is_macos; then
		shell::logger::error "--keychain is only available on macOS"
		return "$RETURN_NOT_SUPPORTED"
	fi

	local -a flags=()
	if [ -n "$lifetime" ]; then
		flags+=(-t "$lifetime")
	fi
	if [ "$keychain" = "true" ]; then
		flags+=(--apple-use-keychain)
	fi

	local -a run=()
	if [ "$dry_run" = "true" ]; then
		run+=(-n)
	else
		for key in "$@"; do
			if [ ! -f "$key" ]; then
				shell::logger::error "Key not found: $key"
				return "$RETURN_NOT_FOUND"
			fi
		done
		shell::dependency::ensure ssh-add || return "$RETURN_NOT_FOUND"
		if ! shell::ssh::agent::reachable; then
			shell::logger::error "Cannot reach an ssh agent (start one with shell::ssh::agent::start)"
			return "$RETURN_FAILURE"
		fi
	fi
	shell::ssh::invoke ${run[@]+"${run[@]}"} ssh-add ${flags[@]+"${flags[@]}"} "$@"
}

# @description Pick private keys with fzf and add them to the agent.
#   The keys are the private keys found in `~/.ssh`; the preview shows the
#   fingerprint of the highlighted one. Several keys can be marked (Tab).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -t | --lifetime <sec> Drop the keys from the agent after this many seconds.
# @option --keychain Store the passphrases in the macOS keychain (macOS only).
# @exitcode 0 Success.
# @exitcode 1 No agent could be reached.
# @exitcode 8 There is no private key in `~/.ssh`.
# @exitcode 9 The selection was cancelled.
# @exitcode N Exit status of shell::ssh::agent::add.
# @see shell::ssh::agent::add
# @example
#   shell::ssh::agent::add::fzf
#
shell::ssh::agent::add::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick private keys with fzf and add them to the agent"
		shell::logger::usage "shell::ssh::agent::add::fzf [-n] [-t <sec>] [--keychain]"
		shell::logger::option "-t, --lifetime <sec>" "Drop the keys from the agent after this many seconds"
		shell::logger::option "--keychain" "Store the passphrases in the macOS keychain (macOS only)"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::agent::add::fzf"
		return "$RETURN_SUCCESS"
	fi

	local candidates picked key rc=0
	candidates="$(shell::ssh::key::candidates)"
	if [ -z "$candidates" ]; then
		shell::logger::warn "No private key found in $SHELL_SSH_DIR"
		return "$RETURN_EMPTY"
	fi

	picked="$(printf '%s\n' "$candidates" | shell::fzf::select --multi --prompt="Add key: " \
		--preview="ssh-keygen -lf {}.pub 2>/dev/null || ssh-keygen -lf {} 2>/dev/null || echo 'no fingerprint available'")" || rc=$?
	if [ "$rc" -ne 0 ]; then
		return "$rc"
	fi

	local -a keys=()
	while IFS= read -r key; do
		if [ -n "$key" ]; then
			keys+=("$key")
		fi
	done <<EOF
$picked
EOF
	if [ "${#keys[@]}" -eq 0 ]; then
		return "$RETURN_CANCELLED"
	fi
	shell::ssh::agent::add "$@" "${keys[@]}"
}

# @description Remove keys from the agent (`ssh-add -d key`).
#   The key files stay on disk; only the copy in the agent's memory goes.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $@ string One or more key files (the private key or its `.pub`).
# @exitcode 0 Success.
# @exitcode 1 No agent could be reached.
# @exitcode 2 Unknown option, or no key given.
# @exitcode 3 ssh-add or a key file is missing.
# @exitcode N Exit status of ssh-add.
# @see shell::ssh::agent::clear
# @example
#   shell::ssh::agent::remove ~/.ssh/id_ed25519
#
shell::ssh::agent::remove() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Remove keys from the agent (ssh-add -d)"
		shell::logger::usage "shell::ssh::agent::remove [-n] <key>..."
		shell::logger::item "key" "Key files (the private key or its .pub)"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::agent::remove ~/.ssh/id_ed25519"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" key
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi
	if [ "$#" -eq 0 ]; then
		shell::logger::error "At least one key is required"
		return "$RETURN_INVALID"
	fi
	for key in "$@"; do
		case "$key" in
		-*)
			shell::logger::error "Invalid key: '$key'"
			return "$RETURN_INVALID"
			;;
		esac
	done

	local -a run=()
	if [ "$dry_run" = "true" ]; then
		run+=(-n)
	else
		for key in "$@"; do
			if [ ! -f "$key" ] && [ ! -f "$key.pub" ]; then
				shell::logger::error "Key not found: $key"
				return "$RETURN_NOT_FOUND"
			fi
		done
		shell::dependency::ensure ssh-add || return "$RETURN_NOT_FOUND"
		if ! shell::ssh::agent::reachable; then
			shell::logger::error "Cannot reach an ssh agent (start one with shell::ssh::agent::start)"
			return "$RETURN_FAILURE"
		fi
	fi
	shell::ssh::invoke ${run[@]+"${run[@]}"} ssh-add -d "$@"
}

# @description Remove every key from the agent (`ssh-add -D`).
#   The key files stay on disk; only the copies in the agent's memory go.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @exitcode 0 Success.
# @exitcode 1 No agent could be reached.
# @exitcode 3 ssh-add is missing.
# @exitcode N Exit status of ssh-add.
# @see shell::ssh::agent::remove
# @example
#   shell::ssh::agent::clear
#
shell::ssh::agent::clear() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Remove every key from the agent (ssh-add -D)"
		shell::logger::usage "shell::ssh::agent::clear [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::agent::clear"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi
	if [ "$#" -gt 0 ]; then
		shell::logger::error "Unexpected argument: $1"
		return "$RETURN_INVALID"
	fi

	local -a run=()
	if [ "$dry_run" = "true" ]; then
		run+=(-n)
	else
		shell::dependency::ensure ssh-add || return "$RETURN_NOT_FOUND"
		if ! shell::ssh::agent::reachable; then
			shell::logger::error "Cannot reach an ssh agent (start one with shell::ssh::agent::start)"
			return "$RETURN_FAILURE"
		fi
	fi
	shell::ssh::invoke ${run[@]+"${run[@]}"} ssh-add -D
}
