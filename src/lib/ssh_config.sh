#!/usr/bin/env bash
# @file lib/ssh_config.sh
# @brief Manage the Host aliases of ~/.ssh/config: add, list, show, remove, and connect by picking one.
# @description
#   A `Host` block in `~/.ssh/config` turns `ssh -p 2222 -i ~/.ssh/key deploy@10.0.0.5`
#   into `ssh web1`, and every command of the ssh library (`shell::ssh::connect`,
#   `scp::upload`, `tunnel::local` ...) accepts such an alias wherever it wants a host.
#
#   Things worth knowing:
#
#   * `shell::ssh::config::add` puts the new block **before** the first `Host *`
#     block, because ssh keeps the first value it finds for an option: a specific host
#     placed after `Host *` would never override it. Without `Host *` the block goes
#     at the end.
#   * Before the file is changed it is copied to `SHELL_SSH_CONFIG_BACKUP_FILE`
#     (mode 600). The file keeps its owner and mode; a new one is created with 600,
#     which ssh requires.
#   * Only plain aliases are listed and removed: patterns (`Host *.example.com`) and
#     `Match` blocks are never touched. A `Host` line that names several aliases
#     (`Host web1 web2`) is not edited either; split it by hand first.
#   * Comments are kept, including the ones right above a block you remove.
#   * `Include`d files are read by `shell::ssh::config::show` (it asks ssh itself) but
#     not by `list`, `add` or `remove`, which work on the one file.
#   * `--mux` writes the ControlMaster lines that make later connections to the host
#     reuse the first one (instant logins). See `shell::ssh::mux::check` and `::stop`.
#   * Every command takes `-f | --file <path>` to work on another config file.

# @internal
# @description Tell whether a string is a usable Host alias: letters, digits, `.`, `_`, `-`, not starting with `-`.
# @arg $1 string The candidate.
# @exitcode 0 It is.
# @exitcode 1 It is not (wildcards and spaces are refused on purpose).
# @example
#   _shell::ssh::config::alias::valid "web-1" && echo ok
#
_shell::ssh::config::alias::valid() {
	case "${1-}" in
	'' | [!A-Za-z0-9]* | *[!A-Za-z0-9._-]*) return 1 ;;
	esac
	return 0
}

# @internal
# @description Print a value the way ssh_config wants it: unchanged, or in double quotes when it has spaces.
# @arg $1 string The value.
# @stdout The value, quoted if needed.
# @exitcode 0 Success.
# @exitcode 1 The value is empty, or holds a double quote or a control character.
# @example
#   _shell::ssh::config::value "/home/me/my keys/id"   # -> "/home/me/my keys/id"
#
_shell::ssh::config::value() {
	case "${1-}" in
	'' | *'"'* | *[[:cntrl:]]*) return 1 ;;
	*[[:space:]]*) printf '"%s"\n' "$1" ;;
	*) printf '%s\n' "$1" ;;
	esac
}

# @internal
# @description Print the plain Host aliases of a config file, one per line, in file order.
#   Patterns (`*`, `?`, `!`) are skipped.
# @arg $1 string The config file.
# @stdout The aliases.
# @exitcode 0 Success (the list may be empty).
# @exitcode 3 The file does not exist.
# @example
#   _shell::ssh::config::aliases ~/.ssh/config
#
_shell::ssh::config::aliases() {
	local file="${1-}"
	if [ ! -f "$file" ]; then
		return "$RETURN_NOT_FOUND"
	fi
	awk '
	{
		line = $0
		sub(/^[ \t]+/, "", line)
		key = line
		sub(/[ \t=].*$/, "", key)
		if (tolower(key) != "host") next
		rest = line
		sub(/^[^ \t=]+[ \t]*=?[ \t]*/, "", rest)
		sub(/[ \t]*#.*$/, "", rest)
		n = split(rest, pat, /[ \t]+/)
		for (i = 1; i <= n; i++) {
			if (pat[i] == "" || pat[i] ~ /[*?!]/) continue
			print pat[i]
		}
	}' "$file"
}

# @internal
# @description Keep a copy of the config file before it is rewritten.
#   The copy is `SHELL_SSH_CONFIG_BACKUP_FILE`, mode 600; the previous copy is replaced.
# @arg $1 string The config file.
# @exitcode 0 Backed up (or there was nothing to back up).
# @exitcode 1 The copy failed.
# @example
#   _shell::ssh::config::backup ~/.ssh/config
#
_shell::ssh::config::backup() {
	local file="${1-}"
	if [ ! -s "$file" ]; then
		return "$RETURN_SUCCESS"
	fi
	shell::fs::mkdir --private "$SHELL_CONFIG_BACKUP_DIR" || return "$RETURN_FAILURE"
	(umask 077 && cp "$file" "$SHELL_SSH_CONFIG_BACKUP_FILE") || return "$RETURN_FAILURE"
}

# @internal
# @description Print a config file without the Host block of one alias.
#   The block runs from its `Host` line to the next `Host` or `Match` line. The
#   comments and blank lines that sit between it and the next block are kept.
# @arg $1 string The config file.
# @arg $2 string The alias.
# @stdout The new content.
# @exitcode 0 The block was left out.
# @exitcode 3 The alias is not in the file.
# @exitcode 4 The alias shares its `Host` line with other names.
# @example
#   _shell::ssh::config::block::remove ~/.ssh/config web1 > /tmp/new
#
_shell::ssh::config::block::remove() {
	local rc=0
	awk -v target="${2-}" '
	function emit(l) {
		print l
		last_blank = (l ~ /^[ \t]*$/)
	}
	function flush_pending(   i) {
		for (i = 1; i <= np; i++) {
			if (pend[i] ~ /^[ \t]*$/ && last_blank) continue
			emit(pend[i])
		}
		np = 0
	}
	BEGIN { skip = 0; np = 0; last_blank = 0; found = 0; shared = 0 }
	{
		line = $0
		t = line
		sub(/^[ \t]+/, "", t)
		key = t
		sub(/[ \t=].*$/, "", key)
		key = tolower(key)
		if (key == "host" || key == "match") {
			if (skip) flush_pending()
			hit = 0
			if (key == "host") {
				rest = t
				sub(/^[^ \t=]+[ \t]*=?[ \t]*/, "", rest)
				sub(/[ \t]*#.*$/, "", rest)
				n = split(rest, pat, /[ \t]+/)
				others = 0
				for (i = 1; i <= n; i++) {
					if (pat[i] == "") continue
					if (pat[i] == target) hit = 1
					else others++
				}
			}
			if (hit) {
				found = 1
				if (others > 0) shared = 1
				skip = 1
				np = 0
			} else {
				skip = 0
				emit(line)
			}
			next
		}
		if (!skip) { emit(line); next }
		if (line ~ /^[ \t]*(#.*)?$/) pend[++np] = line
		else np = 0
	}
	END {
		if (shared) exit 4
		if (!found) exit 3
	}' "${1-}" || rc=$?
	return "$rc"
}

# @internal
# @description Print a config file with a block added before its first `Host *` (or at the end).
# @arg $1 string The config file.
# @arg $2 string A file holding the block to add.
# @stdout The new content.
# @exitcode 0 Success.
# @example
#   _shell::ssh::config::block::insert ~/.ssh/config /tmp/block > /tmp/new
#
_shell::ssh::config::block::insert() {
	awk -v blockfile="${2-}" '
	function dump(   l) {
		while ((getline l < blockfile) > 0) print l
		close(blockfile)
	}
	BEGIN { done = 0; n = 0; last = "" }
	{
		t = $0
		sub(/^[ \t]+/, "", t)
		if (!done && t ~ /^[Hh][Oo][Ss][Tt][ \t=]+\*[ \t]*(#.*)?$/) {
			if (n > 0 && last !~ /^[ \t]*$/) print ""
			dump()
			print ""
			done = 1
		}
		print
		last = $0
		n++
	}
	END {
		if (!done) {
			if (n > 0 && last !~ /^[ \t]*$/) print ""
			dump()
		}
	}' "${1-}"
}

# @internal
# @description Rewrite a config file: optionally drop one alias, then add a block.
#   Works through temporary files and copies the result over the file, so its owner
#   and mode are kept. The caller makes the backup.
# @arg $1 string The config file.
# @arg $2 string The alias to replace (empty to only add).
# @arg $3 string The block to add.
# @exitcode 0 The file was rewritten.
# @exitcode 1 A step failed; the file is unchanged.
# @example
#   _shell::ssh::config::apply ~/.ssh/config "" "$block"
#
_shell::ssh::config::apply() {
	local file="${1-}" replace="${2-}" block="${3-}" tmp_block tmp_old tmp_new rc=0 tmp_dir
	tmp_dir="$(shell::os::temp_dir)"
	tmp_block="$(mktemp "$tmp_dir/shell-ssh-block.XXXXXX")" || return "$RETURN_FAILURE"
	tmp_old="$(mktemp "$tmp_dir/shell-ssh-old.XXXXXX")" || return "$RETURN_FAILURE"
	tmp_new="$(mktemp "$tmp_dir/shell-ssh-new.XXXXXX")" || return "$RETURN_FAILURE"

	printf '%s\n' "$block" >"$tmp_block"
	if [ -n "$replace" ]; then
		_shell::ssh::config::block::remove "$file" "$replace" >"$tmp_old" || rc=$?
	else
		cat "$file" >"$tmp_old" || rc=$?
	fi
	if [ "$rc" -eq 0 ]; then
		_shell::ssh::config::block::insert "$tmp_old" "$tmp_block" >"$tmp_new" || rc=$?
	fi
	if [ "$rc" -eq 0 ]; then
		cat "$tmp_new" >"$file" || rc=$?
	fi
	rm -f "$tmp_block" "$tmp_old" "$tmp_new"
	if [ "$rc" -ne 0 ]; then
		return "$RETURN_FAILURE"
	fi
	return "$RETURN_SUCCESS"
}

# @description Add a Host alias to ~/.ssh/config (`Host alias` + `HostName`, `User`, `Port` ...).
#   Afterwards `ssh <alias>` (or `shell::ssh::connect <alias>`) is all you type. The
#   block goes before the first `Host *` block (see the file description), the file
#   is backed up first, and an alias that already exists is refused unless you add
#   `--force`, which replaces its block.
# @option -h | --help Show help and return.
# @option -n | --dry-run Show the block that would be written, change nothing.
# @option -u | --user <name> `User`.
# @option -p | --port <n> `Port`.
# @option -i | --identity <file> `IdentityFile`, with `IdentitiesOnly yes` so the agent does not offer other keys.
# @option -J | --jump <hosts> `ProxyJump`.
# @option --keepalive <sec> `ServerAliveInterval` (with `ServerAliveCountMax`).
# @option --forward-agent `ForwardAgent yes`.
# @option --mux `ControlMaster auto`, `ControlPath`, `ControlPersist`.
# @option --force Replace the block of an existing alias.
# @option -f | --file <path> Another config file.
# @arg $1 string The alias.
# @arg $2 string The real host name or address.
# @exitcode 0 The block was written (or shown, with -n).
# @exitcode 1 The file could not be written.
# @exitcode 2 Unknown option, missing arguments, or an invalid alias, host, user, port, key or jump list.
# @exitcode 7 The alias already exists and --force was not given.
# @see shell::ssh::config::list
# @see shell::ssh::connect
# @example
#   shell::ssh::config::add web1 10.0.0.5 -u deploy
#   shell::ssh::config::add -u deploy -p 2222 -i ~/.ssh/id_ed25519 --mux web1 10.0.0.5
#   shell::ssh::config::add --force -J bastion db1 10.0.1.9
#
shell::ssh::config::add() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Add a Host alias to ~/.ssh/config"
		shell::logger::usage "shell::ssh::config::add [-n] [options] <alias> <hostname>"
		shell::logger::item "alias" "The short name to type (letters, digits, . _ -)"
		shell::logger::item "hostname" "The real host name or IP address"
		shell::logger::option "-u, --user <name>" "User"
		shell::logger::option "-p, --port <n>" "Port"
		shell::logger::option "-i, --identity <file>" "IdentityFile (and IdentitiesOnly yes)"
		shell::logger::option "-J, --jump <hosts>" "ProxyJump"
		shell::logger::option "--keepalive <sec>" "ServerAliveInterval"
		shell::logger::option "--forward-agent" "ForwardAgent yes"
		shell::logger::option "--mux" "Reuse one connection per host (ControlMaster)"
		shell::logger::option "--force" "Replace the block of an existing alias"
		shell::logger::option "-f, --file <path>" "Another config file (default: ~/.ssh/config)"
		shell::logger::option "-n, --dry-run" "Show the block that would be written, change nothing"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::config::add web1 10.0.0.5 -u deploy"
		shell::logger::example "shell::ssh::config::add -u deploy -p 2222 -i ~/.ssh/id_ed25519 --mux web1 10.0.0.5"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" file="$SHELL_SSH_CONFIG_FILE" user="" port="" identity="" jump=""
	local keepalive="" forward_agent="false" mux="false" force="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		-f | --file)
			_shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			file="$2"
			shift 2
			;;
		-u | --user)
			_shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			case "$2" in
			'' | -* | *[!A-Za-z0-9._+-]*)
				shell::logger::error "Invalid user: '$2'"
				return "$RETURN_INVALID"
				;;
			esac
			user="$2"
			shift 2
			;;
		-p | --port)
			_shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			if ! _shell::net::port::valid "$2"; then
				shell::logger::error "Invalid port: '$2' (1-65535)"
				return "$RETURN_INVALID"
			fi
			port="$2"
			shift 2
			;;
		-i | --identity)
			_shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			case "$2" in
			'' | -*)
				shell::logger::error "Invalid identity file: '$2'"
				return "$RETURN_INVALID"
				;;
			esac
			identity="$2"
			shift 2
			;;
		-J | --jump)
			_shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			if ! _shell::ssh::jump::valid "$2"; then
				shell::logger::error "Invalid jump host list: '$2' (use [user@]host[:port], comma separated)"
				return "$RETURN_INVALID"
			fi
			jump="$2"
			shift 2
			;;
		--keepalive)
			_shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			_shell::ssh::cmd::number "$1" "$2" || return "$RETURN_INVALID"
			keepalive="$2"
			shift 2
			;;
		--forward-agent)
			forward_agent="true"
			shift
			;;
		--mux)
			mux="true"
			shift
			;;
		--force)
			force="true"
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

	if [ "$#" -ne 2 ]; then
		shell::logger::error "An alias and a hostname are required"
		return "$RETURN_INVALID"
	fi
	local alias_name="$1" host="$2"
	if ! _shell::ssh::config::alias::valid "$alias_name"; then
		shell::logger::error "Invalid alias: '$alias_name' (letters, digits, . _ - ; it must not start with -)"
		return "$RETURN_INVALID"
	fi
	case "$host" in
	'' | -* | *[!A-Za-z0-9._:-]*)
		shell::logger::error "Invalid hostname: '$host'"
		return "$RETURN_INVALID"
		;;
	esac

	local nl='
'
	local identity_value="" socket_value=""
	if [ -n "$identity" ]; then
		identity_value="$(_shell::ssh::config::value "$identity")" || {
			shell::logger::error "Invalid identity file: '$identity' (no double quotes or control characters)"
			return "$RETURN_INVALID"
		}
	fi
	if [ "$mux" = "true" ]; then
		socket_value="$(_shell::ssh::config::value "$SHELL_SSH_SOCKET_DIR/%C")" || {
			shell::logger::error "SHELL_SSH_SOCKET_DIR cannot be used in an ssh config: $SHELL_SSH_SOCKET_DIR"
			return "$RETURN_INVALID"
		}
	fi

	local block="Host $alias_name${nl}    HostName $host"
	if [ -n "$user" ]; then
		block="$block${nl}    User $user"
	fi
	if [ -n "$port" ]; then
		block="$block${nl}    Port $port"
	fi
	if [ -n "$identity_value" ]; then
		block="$block${nl}    IdentityFile $identity_value${nl}    IdentitiesOnly yes"
	fi
	if [ -n "$jump" ]; then
		block="$block${nl}    ProxyJump $jump"
	fi
	if [ -n "$keepalive" ]; then
		block="$block${nl}    ServerAliveInterval $keepalive${nl}    ServerAliveCountMax $SHELL_SSH_KEEPALIVE_COUNT"
	fi
	if [ "$forward_agent" = "true" ]; then
		block="$block${nl}    ForwardAgent yes"
	fi
	if [ "$mux" = "true" ]; then
		block="$block${nl}    ControlMaster auto${nl}    ControlPath $socket_value${nl}    ControlPersist $SHELL_SSH_CONTROL_PERSIST"
	fi

	local replace=""
	if [ -f "$file" ] && _shell::ssh::config::aliases "$file" | grep -Fxq -- "$alias_name"; then
		if [ "$force" = "false" ]; then
			shell::logger::warn "Host '$alias_name' already exists in $file (use --force to replace it)"
			return "$RETURN_EXISTS"
		fi
		replace="$alias_name"
	fi

	if [ "$dry_run" = "true" ]; then
		if [ -n "$replace" ]; then
			shell::logger::info "Would replace the block of '$alias_name' in $file with:"
		else
			shell::logger::info "Would add to $file:"
		fi
		printf '%s\n' "$block"
		return "$RETURN_SUCCESS"
	fi

	if [ -n "$identity" ] && [ ! -f "$identity" ]; then
		shell::logger::warn "Identity file does not exist yet: $identity"
	fi
	local parent
	case "$file" in
	*/*) parent="${file%/*}" ;;
	*) parent="." ;;
	esac
	shell::fs::mkdir --private "$parent" || return "$RETURN_FAILURE"
	if [ "$mux" = "true" ]; then
		shell::fs::mkdir --private "$SHELL_SSH_SOCKET_DIR" || return "$RETURN_FAILURE"
	fi
	shell::fs::touch --private "$file" || return "$RETURN_FAILURE"
	_shell::ssh::config::backup "$file" || {
		shell::logger::error "Could not back up $file"
		return "$RETURN_FAILURE"
	}
	_shell::ssh::config::apply "$file" "$replace" "$block" || {
		shell::logger::error "Could not update $file"
		return "$RETURN_FAILURE"
	}
	shell::logger::success "Host '$alias_name' saved in $file (connect with: shell::ssh::connect $alias_name)"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Print the Host aliases of a config file as an aligned table.
#   Columns: ALIAS HOST USER PORT IDENTITY JUMP (`-` for an unset value). The first
#   value of an option in a block wins, as it does for ssh. Patterns and `Match`
#   blocks are skipped. Nothing is printed when there is no alias.
# @arg $1 string The config file.
# @stdout The table.
# @exitcode 0 Success.
# @example
#   _shell::ssh::config::table ~/.ssh/config
#
_shell::ssh::config::table() {
	awk '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function flush(   i) {
	for (i = 1; i <= na; i++) {
		rows++
		ra[rows] = al[i]; rh[rows] = hn; ru[rows] = us; rp[rows] = po; rk[rows] = idf; rj[rows] = jmp
	}
	na = 0; hn = ""; us = ""; po = ""; idf = ""; jmp = ""
}
function dash(s) { return (s == "" ? "-" : s) }
function pad(s, w) { return sprintf("%-" w "s", s) }
function max(a, b) { return (a > b ? a : b) }
BEGIN { na = 0; rows = 0 }
{
	t = $0
	sub(/^[ \t]+/, "", t)
	if (t == "" || t ~ /^#/) next
	key = t
	sub(/[ \t=].*$/, "", key)
	key = tolower(key)
	val = t
	sub(/^[^ \t=]+[ \t]*=?[ \t]*/, "", val)
	sub(/[ \t]*#.*$/, "", val)
	val = trim(val)
	gsub(/"/, "", val)
	if (key == "host") {
		flush()
		n = split(val, pat, /[ \t]+/)
		for (i = 1; i <= n; i++) {
			if (pat[i] == "" || pat[i] ~ /[*?!]/) continue
			na++; al[na] = pat[i]
		}
	} else if (key == "match") {
		flush()
	} else if (na > 0) {
		if (key == "hostname" && hn == "") hn = val
		else if (key == "user" && us == "") us = val
		else if (key == "port" && po == "") po = val
		else if (key == "identityfile" && idf == "") idf = val
		else if (key == "proxyjump" && jmp == "") jmp = val
	}
}
END {
	flush()
	if (rows == 0) exit 0
	w1 = 5; w2 = 4; w3 = 4; w4 = 4; w5 = 8
	for (i = 1; i <= rows; i++) {
		w1 = max(w1, length(ra[i])); w2 = max(w2, length(dash(rh[i])))
		w3 = max(w3, length(dash(ru[i]))); w4 = max(w4, length(dash(rp[i])))
		w5 = max(w5, length(dash(rk[i])))
	}
	print pad("ALIAS", w1) "  " pad("HOST", w2) "  " pad("USER", w3) "  " pad("PORT", w4) "  " pad("IDENTITY", w5) "  JUMP"
	for (i = 1; i <= rows; i++)
		print pad(ra[i], w1) "  " pad(dash(rh[i]), w2) "  " pad(dash(ru[i]), w3) "  " pad(dash(rp[i]), w4) "  " pad(dash(rk[i]), w5) "  " dash(rj[i])
}' "${1-}"
}

# @description List the Host aliases of ~/.ssh/config with their host, user, port, key and jump.
#   Only plain aliases are listed (no patterns, no `Match`). With `--names` the output
#   is the bare alias list, one per line, ready for a loop or for fzf.
# @option -h | --help Show help and return.
# @option --names Print only the alias names.
# @option -f | --file <path> Another config file.
# @stdout A table (or the names).
# @exitcode 0 Success.
# @exitcode 2 Unknown option.
# @exitcode 3 The config file does not exist.
# @exitcode 8 The file has no alias.
# @see shell::ssh::config::show
# @example
#   shell::ssh::config::list
#   for h in $(shell::ssh::config::list --names); do shell::ssh::check "$h"; done
#
shell::ssh::config::list() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List the Host aliases of ~/.ssh/config"
		shell::logger::usage "shell::ssh::config::list [--names] [-f <file>]"
		shell::logger::option "--names" "Print only the alias names, one per line"
		shell::logger::option "-f, --file <path>" "Another config file"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::config::list"
		return "$RETURN_SUCCESS"
	fi

	local names="false" file="$SHELL_SSH_CONFIG_FILE"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--names)
			names="true"
			shift
			;;
		-f | --file)
			_shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
			file="$2"
			shift 2
			;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
	done

	if [ ! -f "$file" ]; then
		shell::logger::warn "No ssh config file at $file"
		return "$RETURN_NOT_FOUND"
	fi

	local out
	if [ "$names" = "true" ]; then
		out="$(_shell::ssh::config::aliases "$file")"
	else
		out="$(_shell::ssh::config::table "$file")"
	fi

	if [ -z "$out" ]; then
		shell::logger::warn "No Host alias in $file (add one with shell::ssh::config::add)"
		return "$RETURN_EMPTY"
	fi
	printf '%s\n' "$out"
	return "$RETURN_SUCCESS"
}

# @description Show how ssh resolves a host (`ssh -G host`): host name, user, port, keys, jump ...
#   It is the truth ssh will act on, with defaults, `Include`s and `Host *` applied, so it
#   is the first thing to look at when a login goes to the wrong user or key. By default
#   only the useful settings are shown.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --all Show every setting ssh resolved.
# @option -f | --file <path> Another config file (ssh -F).
# @arg $1 string The alias or host.
# @stdout `setting value` lines.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, no host, or an unsafe host.
# @exitcode 3 ssh is missing, or the file does not exist.
# @exitcode N Exit status of ssh.
# @example
#   shell::ssh::config::show web1
#   shell::ssh::config::show --all web1
#
shell::ssh::config::show() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show how ssh resolves a host (ssh -G)"
		shell::logger::usage "shell::ssh::config::show [-n] [--all] [-f <file>] <alias|host>"
		shell::logger::item "host" "A Host alias of ~/.ssh/config, or any host"
		shell::logger::option "--all" "Show every setting, not only the useful ones"
		shell::logger::option "-f, --file <path>" "Another config file (ssh -F)"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::config::show web1"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" all="false" file=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		--all)
			all="true"
			shift
			;;
		-f | --file)
			_shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
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

	if [ "$#" -ne 1 ] || ! _shell::ssh::target::valid "$1"; then
		shell::logger::error "Exactly one valid alias or host is required"
		return "$RETURN_INVALID"
	fi

	local -a cmd=(ssh)
	if [ -n "$file" ]; then
		cmd+=(-F "$file")
	fi
	cmd+=(-G "$1")

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$(_shell::ssh::quote "${cmd[@]}")"
		return "$RETURN_SUCCESS"
	fi
	shell::dependency::ensure ssh || return "$RETURN_NOT_FOUND"
	if [ -n "$file" ] && [ ! -f "$file" ]; then
		shell::logger::error "Config file not found: $file"
		return "$RETURN_NOT_FOUND"
	fi

	local out rc=0
	out="$("${cmd[@]}")" || rc=$?
	if [ "$rc" -ne 0 ]; then
		return "$rc"
	fi
	if [ "$all" = "true" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E '^(hostname|user|port|identityfile|identitiesonly|proxyjump|forwardagent|serveraliveinterval|serveralivecountmax|controlmaster|controlpath|controlpersist) '
	fi
	return "$RETURN_SUCCESS"
}

# @description Remove a Host alias from ~/.ssh/config.
#   Only its block goes (see the file description for what that means), after a
#   confirmation unless `--yes`, and after a backup of the file.
# @option -h | --help Show help and return.
# @option -n | --dry-run Say what would be removed, change nothing.
# @option -y | --yes Do not ask for confirmation.
# @option -f | --file <path> Another config file.
# @arg $1 string The alias.
# @exitcode 0 The block was removed (or the dry run reported it).
# @exitcode 1 The file could not be written.
# @exitcode 2 Unknown option, no alias, or an invalid alias.
# @exitcode 3 The file or the alias does not exist.
# @exitcode 4 The alias shares its `Host` line with other names: edit the file by hand.
# @exitcode 9 You answered no, or input ended.
# @see shell::ssh::config::remove::fzf
# @example
#   shell::ssh::config::remove web1
#   shell::ssh::config::remove --yes web1
#
shell::ssh::config::remove() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Remove a Host alias from ~/.ssh/config"
		shell::logger::usage "shell::ssh::config::remove [-n] [-y] [-f <file>] <alias>"
		shell::logger::item "alias" "The Host alias to remove"
		shell::logger::option "-y, --yes" "Do not ask for confirmation"
		shell::logger::option "-f, --file <path>" "Another config file"
		shell::logger::option "-n, --dry-run" "Say what would be removed, change nothing"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::config::remove web1"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" assume_yes="false" file="$SHELL_SSH_CONFIG_FILE"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		-y | --yes)
			assume_yes="true"
			shift
			;;
		-f | --file)
			_shell::ssh::cmd::need "$1" "$#" || return "$RETURN_INVALID"
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

	if [ "$#" -ne 1 ] || ! _shell::ssh::config::alias::valid "$1"; then
		shell::logger::error "Exactly one valid alias is required"
		return "$RETURN_INVALID"
	fi
	local alias_name="$1"
	if [ ! -f "$file" ]; then
		shell::logger::warn "No ssh config file at $file"
		return "$RETURN_NOT_FOUND"
	fi

	local tmp rc=0
	tmp="$(mktemp "$(shell::os::temp_dir)/shell-ssh-config.XXXXXX")" || return "$RETURN_FAILURE"
	_shell::ssh::config::block::remove "$file" "$alias_name" >"$tmp" || rc=$?
	case "$rc" in
	0) ;;
	3)
		rm -f "$tmp"
		shell::logger::warn "Host '$alias_name' is not in $file"
		return "$RETURN_NOT_FOUND"
		;;
	4)
		rm -f "$tmp"
		shell::logger::error "'$alias_name' shares its Host line with other names; edit $file by hand"
		return "$RETURN_NOT_SUPPORTED"
		;;
	*)
		rm -f "$tmp"
		return "$RETURN_FAILURE"
		;;
	esac

	if [ "$dry_run" = "true" ]; then
		rm -f "$tmp"
		shell::logger::info "Would remove the block of '$alias_name' from $file"
		return "$RETURN_SUCCESS"
	fi

	if [ "$assume_yes" = "false" ]; then
		if ! shell::ask::accept "Remove Host '$alias_name' from $file?"; then
			rm -f "$tmp"
			shell::logger::warn "Cancelled"
			return "$RETURN_CANCELLED"
		fi
	fi

	rc=0
	_shell::ssh::config::backup "$file" && cat "$tmp" >"$file" || rc=$?
	rm -f "$tmp"
	if [ "$rc" -ne 0 ]; then
		shell::logger::error "Could not update $file"
		return "$RETURN_FAILURE"
	fi
	shell::logger::success "Host '$alias_name' removed from $file"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Pick a Host alias of a config file with fzf; the preview shows how ssh resolves it.
# @arg $1 string The config file.
# @arg $2 string The fzf prompt.
# @stdout The chosen alias.
# @exitcode 0 An alias was chosen.
# @exitcode 3 The file does not exist, or fzf is missing.
# @exitcode 8 The file has no alias.
# @exitcode 9 The selection was cancelled.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was chosen.
# @example
#   alias_name="$(_shell::ssh::config::pick "$SHELL_SSH_CONFIG_FILE" "Connect to: ")" || return
#
_shell::ssh::config::pick() {
	local file="${1-}" prompt="${2:-Host: }" names preview
	if [ ! -f "$file" ]; then
		shell::logger::warn "No ssh config file at $file"
		return "$RETURN_NOT_FOUND"
	fi
	names="$(_shell::ssh::config::aliases "$file")"
	if [ -z "$names" ]; then
		shell::logger::warn "No Host alias in $file (add one with shell::ssh::config::add)"
		return "$RETURN_EMPTY"
	fi
	preview="$(_shell::ssh::quote ssh -F "$file" -G) {} | grep -E '^(hostname|user|port|identityfile|proxyjump) '"
	local picked rc
	# The back entry comes last so that Enter never lands on it by accident.
	picked="$(printf '%s\n%s\n' "$names" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --prompt="$prompt" --preview="$preview")"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		return "$rc"
	fi
	if [ "$picked" = "$SHELL_FZF_BACK_LABEL" ]; then
		shell::logger::info "Back — no host was chosen"
		return "$RETURN_BACK"
	fi
	printf '%s\n' "$picked"
}

# @description Pick a Host alias with fzf and remove it.
#   Same as `shell::ssh::config::remove`, with the alias chosen from a list. It still
#   asks for confirmation unless `--yes`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Say what would be removed, change nothing.
# @option -y | --yes Do not ask for confirmation.
# @option -f | --file <path> Another config file.
# @exitcode 0 The block was removed (or the dry run reported it).
# @exitcode 3 The file does not exist.
# @exitcode 8 The file has no alias.
# @exitcode 9 The selection or the confirmation was cancelled.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @see shell::ssh::config::remove
# @example
#   shell::ssh::config::remove::fzf
#
shell::ssh::config::remove::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick a Host alias with fzf and remove it"
		shell::logger::usage "shell::ssh::config::remove::fzf [-n] [-y] [-f <file>]"
		shell::logger::option "-y, --yes" "Do not ask for confirmation"
		shell::logger::option "-f, --file <path>" "Another config file"
		shell::logger::option "-n, --dry-run" "Say what would be removed, change nothing"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::config::remove::fzf"
		return "$RETURN_SUCCESS"
	fi

	local file="$SHELL_SSH_CONFIG_FILE" arg prev="" alias_name rc=0
	for arg in "$@"; do
		if [ "$prev" = "-f" ] || [ "$prev" = "--file" ]; then
			file="$arg"
		fi
		prev="$arg"
	done
	alias_name="$(_shell::ssh::config::pick "$file" "Remove host: ")" || rc=$?
	if [ "$rc" -ne 0 ]; then
		return "$rc"
	fi
	shell::ssh::config::remove "$@" "$alias_name"
}

# @description Pick a Host alias with fzf and connect to it.
#   The list is the Host aliases of `~/.ssh/config`; the preview shows how ssh
#   resolves the highlighted one. Any option of `shell::ssh::connect` can be given
#   first (`-n` to only print the command, `-v`, `-A` ...).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -F | --config <file> Another ssh config file (used for the list and for ssh).
# @exitcode 0 Success.
# @exitcode 3 The config file does not exist, or ssh or fzf is missing.
# @exitcode 8 The config file has no alias.
# @exitcode 9 The selection was cancelled.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @exitcode N Exit status of shell::ssh::connect.
# @see shell::ssh::connect
# @see shell::ssh::config::add
# @example
#   shell::ssh::connect::fzf
#   shell::ssh::connect::fzf -n
#   shell::ssh::connect::fzf -A
#
shell::ssh::connect::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick a Host alias with fzf and connect to it"
		shell::logger::usage "shell::ssh::connect::fzf [-n] [connect options]"
		shell::logger::item "connect options" "Any option of shell::ssh::connect (-v, -A, -t, -o ...)"
		shell::logger::option "-F, --config <file>" "Another ssh config file"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::connect::fzf"
		shell::logger::example "shell::ssh::connect::fzf -n"
		return "$RETURN_SUCCESS"
	fi

	local file="$SHELL_SSH_CONFIG_FILE" arg prev="" alias_name rc=0
	for arg in "$@"; do
		if [ "$prev" = "-F" ] || [ "$prev" = "--config" ]; then
			file="$arg"
		fi
		prev="$arg"
	done
	alias_name="$(_shell::ssh::config::pick "$file" "Connect to: ")" || rc=$?
	if [ "$rc" -ne 0 ]; then
		return "$rc"
	fi
	shell::ssh::connect "$@" "$alias_name"
}
