#!/usr/bin/env bash
# @file lib/zsh_fzf.sh
# @brief fzf pickers of the zsh category: history, processes, ssh hosts, bookmarks, worktrees.
# @description
#   Every picker goes through shell::fzf::select (one look and feel), builds its
#   candidates once per call in a private `_shell::zsh::<x>::candidates` producer,
#   separates what is shown from the value that is used (`<value> TAB <row>`; only the
#   value is ever acted on, never the display line), and fails fast, with a clear
#   message, when there is no terminal. Nothing here runs when the library is sourced.
#   All of them work in bash too; the ZLE widgets that paste a pick into the command
#   line are in zsh_widget.sh.

# --------------------------------------------------------------------------
# Shared helpers
# --------------------------------------------------------------------------

# @internal
# @description Succeed when a terminal is available for fzf (/dev/tty can be opened).
#   A function of its own so a test can answer for it.
# @noargs
# @exitcode 0 There is a terminal.
# @exitcode 1 There is none.
# @example
#   _shell::zsh::fzf::has_tty || return
#
_shell::zsh::fzf::has_tty() {
	{ : </dev/tty; } 2>/dev/null
}

# @internal
# @description Fail fast, with a clear error, when no terminal is available.
# @arg $1 string Name of the picker, used in the message.
# @exitcode 0 There is a terminal.
# @exitcode 4 There is none.
# @example
#   _shell::zsh::fzf::guard "History search" || return
#
_shell::zsh::fzf::guard() {
	if ! _shell::zsh::fzf::has_tty; then
		shell::logger::error "$1 needs an interactive terminal (no TTY available)."
		return "$RETURN_NOT_SUPPORTED"
	fi
}

# @internal
# @description Quote a value as one shell word (single quotes), for fzf preview and reload strings.
# @arg $1 string The value.
# @stdout The quoted word.
# @exitcode 0 Always.
# @example
#   preview="ls -1A $(_shell::zsh::fzf::quote "$dir")"
#
_shell::zsh::fzf::quote() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# @internal
# @description Succeed when the installed fzf is at least a given version.
#   Used to switch on features that need a newer fzf (the `start` event and `reload` need 0.35).
# @arg $1 string Version, e.g. 0.35.
# @exitcode 0 fzf is that version or newer.
# @exitcode 1 It is older, or its version could not be read.
# @example
#   if _shell::zsh::fzf::version_ge 0.35; then args+=(--bind=...); fi
#
_shell::zsh::fzf::version_ge() {
	local have
	have="$(fzf --version 2>/dev/null)"
	[ -n "$have" ] || return 1
	awk -v have="${have%% *}" -v want="$1" 'BEGIN {
		split(have, a, "."); split(want, b, "."); r = 0
		for (i = 1; i <= 3; i++) {
			x = a[i] + 0; y = b[i] + 0
			if (x > y) break
			if (x < y) { r = 1; break }
		} exit r }'
}

# @internal
# @description Print the value (the text before the first TAB) of every selected line.
# @stdin The selected lines.
# @stdout The values, one per line.
# @exitcode 0 Always.
# @example
#   values="$(printf '%s\n' "$choice" | _shell::zsh::fzf::values)"
#
_shell::zsh::fzf::values() {
	awk -F'\t' 'NF { print $1 }'
}

# --------------------------------------------------------------------------
# History
# --------------------------------------------------------------------------

# @internal
# @description Say where the history comes from: zsh, bash or file.
#   `zsh` and `bash` read the running shell's own memory (current session included);
#   `file` reads a history file (a non-interactive shell, or an explicit --file).
# @arg $1 string An explicit history file, or empty.
# @stdout zsh | bash | file
# @exitcode 0 Always.
# @example
#   mode="$(_shell::zsh::history::mode "")"
#
_shell::zsh::history::mode() {
	if [ -n "${1-}" ]; then
		printf 'file\n'
	elif [ -n "${ZSH_VERSION-}" ] && fc -ln -1 >/dev/null 2>&1; then
		printf 'zsh\n'
	elif [ -n "${BASH_VERSION-}" ] && [ -n "$(HISTTIMEFORMAT='' history 1 2>/dev/null)" ]; then
		printf 'bash\n'
	else
		printf 'file\n'
	fi
}

# @internal
# @description Run the history awk program (src/data/zsh-history.awk) on stdin.
# @arg $1 string Input kind: list | file.
# @arg $2 string 1 when the input is oldest first, 0 when newest first.
# @stdin The raw history.
# @stdout `<id> TAB <command>`, newest first, deduplicated.
# @exitcode 0 Success.
# @exitcode 3 The awk program is missing.
# @example
#   fc -rl 1 | _shell::zsh::history::awk list 0
#
_shell::zsh::history::awk() {
	if [ ! -f "$SHELL_ZSH_HISTORY_AWK" ]; then
		shell::logger::error "Missing $SHELL_ZSH_HISTORY_AWK"
		return "$RETURN_NOT_FOUND"
	fi
	LC_ALL=C awk -v mode="$1" -v rev="$2" -v limit="$SHELL_ZSH_HISTORY_LIMIT" \
		-v mark=" $SHELL_ZSH_NEWLINE_MARK " -f "$SHELL_ZSH_HISTORY_AWK"
}

# @internal
# @description Parse a history file (plain, bash with time stamps, or zsh extended format).
# @arg $1 string The history file.
# @stdout `<id> TAB <command>`, newest first, deduplicated.
# @exitcode 0 Success.
# @exitcode 3 The file does not exist.
# @example
#   _shell::zsh::history::from_file "$HOME/.zsh_history"
#
_shell::zsh::history::from_file() {
	[ -f "${1-}" ] || return "$RETURN_NOT_FOUND"
	_shell::zsh::history::awk file 1 <"$1"
}

# @internal
# @description Produce the history candidates: `<id> TAB <command>`, newest first, each command once.
#   One producer pipeline (a single awk pass). A history FILE is parsed through the TTL
#   cache; the running shell's memory is always read live.
# @arg $1 string Mode from _shell::zsh::history::mode.
# @arg $2 string History file (mode file); default $HISTFILE, ~/.zsh_history or ~/.bash_history.
# @arg $3 string "refresh" to bypass the cache.
# @stdout The candidates.
# @exitcode 0 Success.
# @exitcode 3 No history file was found.
# @example
#   _shell::zsh::history::candidates "$(_shell::zsh::history::mode "")" "" ""
#
_shell::zsh::history::candidates() {
	local mode="${1-}" file="${2-}" refresh="${3-}" sum
	case "$mode" in
	zsh) fc -rl 1 2>/dev/null | _shell::zsh::history::awk list 0 ;;
	bash) HISTTIMEFORMAT='' history | _shell::zsh::history::awk list 1 ;;
	*)
		if [ -z "$file" ]; then
			for file in "${HISTFILE-}" "$HOME/.zsh_history" "$HOME/.bash_history"; do
				[ -n "$file" ] && [ -f "$file" ] && break
				file=""
			done
		fi
		if [ -z "$file" ] || [ ! -f "$file" ]; then
			shell::logger::warn "No history file found (HISTFILE, ~/.zsh_history, ~/.bash_history)."
			return "$RETURN_NOT_FOUND"
		fi
		sum="$(printf '%s' "$file" | cksum)"
		_shell::zsh::cache::get "$refresh" "history-${sum%% *}" "$SHELL_ZSH_CACHE_TTL" _shell::zsh::history::from_file "$file"
		;;
	esac
}

# @description Fuzzy-search the shell history and print the chosen command.
#   Reads the history of the running shell (zsh `fc`, bash `history`), or a history
#   file when run non-interactively or with `--file`. Entries are deduplicated, newest
#   first, and a long multi-line command is shown on one row. With `--push` (zsh) the
#   command is put in the next prompt's buffer instead of being printed, which is how
#   to "paste to the line" from a plain function; the optional `shell-history` widget
#   does it in place (see shell::zsh::widget::enable). The command is only printed or
#   pushed, never executed.
# @option -h | --help Show help and return.
# @option -p | --push Put the command in the next prompt (zsh `print -z`) instead of printing it.
# @option -q | --query <text> Start with this search text.
# @option -f | --file <path> Read this history file instead of the shell's memory.
# @option --refresh Rebuild the cached history of a file before showing it.
# @stdout The chosen command (unless --push).
# @exitcode 0 A command was chosen.
# @exitcode 2 Unknown option or missing value.
# @exitcode 3 fzf or the history file is missing.
# @exitcode 4 No terminal is available, or --push outside zsh.
# @exitcode 8 The history is empty.
# @exitcode 9 The user cancelled.
# @example
#   shell::zsh::history::search::fzf
#   shell::zsh::history::search::fzf --push -q "git "
#
shell::zsh::history::search::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Fuzzy-search the shell history and print the chosen command"
		shell::logger::usage "shell::zsh::history::search::fzf [-p] [-q <text>] [-f <file>] [--refresh]"
		shell::logger::option "-p, --push" "Put the command in the next prompt (zsh) instead of printing it"
		shell::logger::option "-q, --query <text>" "Start with this search text"
		shell::logger::option "-f, --file <path>" "Read this history file instead of the shell's memory"
		shell::logger::option "--refresh" "Rebuild the cached history of a file"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::zsh::history::search::fzf"
		shell::logger::example "shell::zsh::history::search::fzf --push -q \"git \""
		return "$RETURN_SUCCESS"
	fi

	local push="false" query="" file="" refresh=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-p | --push) push="true" ;;
		--refresh) refresh="refresh" ;;
		-q | --query | -f | --file)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			case "$1" in
			-q | --query) query="$2" ;;
			*) file="$2" ;;
			esac
			shift
			;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done
	if [ "$push" = "true" ] && [ -z "${ZSH_VERSION-}" ]; then
		shell::logger::error "--push needs zsh (print -z); without it the command is printed."
		return "$RETURN_NOT_SUPPORTED"
	fi
	_shell::zsh::fzf::guard "History search" || return $?

	local mode candidates choice rc cmd id full
	mode="$(_shell::zsh::history::mode "$file")"
	candidates="$(_shell::zsh::history::candidates "$mode" "$file" "$refresh")" || return $?
	if [ -z "$candidates" ]; then
		shell::logger::warn "The history is empty."
		return "$RETURN_EMPTY"
	fi

	choice="$(printf '%s\n' "$candidates" | shell::fzf::select --delimiter=$'\t' --with-nth=2.. --nth=2.. \
		--prompt="History: " --query="$query" --preview='printf "%s\n" {2..}' --preview-window=down,3,wrap)"
	rc=$?
	[ "$rc" -eq 0 ] || return "$rc"

	id="${choice%%$'\t'*}"
	cmd="${choice#*$'\t'}"
	# A multi-line entry was flattened for display; zsh can give the real text back by event number.
	case "$cmd" in
	*"$SHELL_ZSH_NEWLINE_MARK"*)
		if [ "$mode" = "zsh" ]; then
			full="$(fc -ln "$id" "$id" 2>/dev/null)"
			[ -n "$full" ] && cmd="${full#"${full%%[![:space:]]*}"}"
		fi
		;;
	esac

	if [ "$push" = "true" ]; then
		print -z -- "$cmd"
	else
		printf '%s\n' "$cmd"
	fi
}

# --------------------------------------------------------------------------
# Processes
# --------------------------------------------------------------------------

# @internal
# @description Print the `ps | awk` pipeline that lists processes, as one shell string.
#   It is what the picker's ctrl-r reload runs; the picker itself runs the same two
#   commands through _shell::zsh::process::candidates, so both show the same rows.
# @arg $1 string "true" for every user's processes, otherwise only the current user's.
# @stdout The pipeline.
# @exitcode 0 Always.
# @example
#   cmd="$(_shell::zsh::process::pipeline false)"
#
_shell::zsh::process::pipeline() {
	local scope="-U ${USER:-$(id -un)}"
	[ "${1-}" = "true" ] && scope="-A"
	printf "ps %s -o pid=,user=,pcpu=,pmem=,comm= | awk -v me=%s -f %s" \
		"$scope" "$$" "$(_shell::zsh::fzf::quote "$SHELL_ZSH_PROCESS_AWK")"
}

# @internal
# @description Produce the process candidates: `<pid> TAB <row>`.
# @arg $1 string "true" for every user's processes.
# @stdout The candidates.
# @exitcode 0 Success.
# @example
#   _shell::zsh::process::candidates false
#
_shell::zsh::process::candidates() {
	local scope="-U ${USER:-$(id -un)}"
	[ "${1-}" = "true" ] && scope="-A"
	# shellcheck disable=SC2086  # the scope is two plain words by construction
	ps $scope -o pid=,user=,pcpu=,pmem=,comm= | awk -v me="$$" -f "$SHELL_ZSH_PROCESS_AWK"
}

# @internal
# @description Print which of the given processes are still running, space separated.
#   Words are never split on a variable: the pids are arguments, so this works the same in bash and zsh.
# @arg $@ string The pids.
# @stdout The running ones, each preceded by a space (empty when none).
# @exitcode 0 Always.
# @example
#   alive="$(_shell::zsh::process::alive 101 202)"
#
_shell::zsh::process::alive() {
	local pid
	for pid in "$@"; do
		if kill -0 "$pid" 2>/dev/null; then printf ' %s' "$pid"; fi
	done
}

# @description Pick processes with fzf and stop them: SIGTERM first, SIGKILL only if you agree.
#   Mark several with Tab. The chosen processes get SIGTERM (or `--signal`); after a
#   short grace period (`SHELL_ZSH_KILL_GRACE`, default 3 s) the ones still alive are
#   listed and SIGKILL is sent only after you confirm. PID 1 and this shell are never
#   offered or signalled. Ctrl-R in the picker refreshes the list (fzf 0.35+). Only your own
#   processes are listed unless `--all`; nothing is run through sudo.
# @option -h | --help Show help and return.
# @option -n | --dry-run Pick, then print the kill command instead of running it.
# @option -a | --all Also list other users' processes (you can only signal your own).
# @option -s | --signal <NAME> First signal to send (default TERM).
# @exitcode 0 Every chosen process was stopped (or the dry run was printed).
# @exitcode 1 A process could not be signalled, or survived.
# @exitcode 2 Unknown option or a bad signal name.
# @exitcode 3 fzf is missing.
# @exitcode 4 No terminal is available.
# @exitcode 8 Nothing to pick from.
# @exitcode 9 The user cancelled.
# @example
#   shell::zsh::process::kill::fzf
#   shell::zsh::process::kill::fzf -n --all
#
shell::zsh::process::kill::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick processes with fzf and stop them (SIGTERM first)"
		shell::logger::usage "shell::zsh::process::kill::fzf [-n] [-a] [-s <SIGNAL>]"
		shell::logger::option "-a, --all" "Also list other users' processes"
		shell::logger::option "-s, --signal <NAME>" "First signal to send (default TERM)"
		shell::logger::option "-n, --dry-run" "Print the kill command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::zsh::process::kill::fzf"
		shell::logger::example "shell::zsh::process::kill::fzf -n --all"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" all="false" signal="TERM"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-a | --all) all="true" ;;
		-s | --signal)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			signal="$2"
			shift
			;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done
	signal="${signal#SIG}"
	case "$signal" in
	'' | *[!A-Za-z0-9]*)
		shell::logger::error "Not a signal name: $signal"
		return "$RETURN_INVALID"
		;;
	esac
	_shell::zsh::fzf::guard "Process picker" || return $?

	local candidates choice rc
	candidates="$(_shell::zsh::process::candidates "$all")"
	if [ -z "$candidates" ]; then
		shell::logger::warn "No processes to choose from."
		return "$RETURN_EMPTY"
	fi

	local header="  PID USER         CPU%  MEM%  COMMAND   (Tab: mark"
	local -a fzf_args=(--multi --delimiter=$'\t' --with-nth=2.. --nth=2.. --prompt="Kill: "
		--preview='ps -p {1} -o pid,ppid,user,etime,args' "--preview-window=$SHELL_ZSH_PREVIEW_WINDOW")
	shell::dependency::fzf::ensure || return "$RETURN_NOT_FOUND"
	if _shell::zsh::fzf::version_ge 0.35; then
		fzf_args+=("--bind=ctrl-r:reload($(_shell::zsh::process::pipeline "$all"))")
		header="$header, Ctrl-R: refresh"
	fi
	fzf_args+=("--header=$header)")
	choice="$(printf '%s\n' "$candidates" | shell::fzf::select "${fzf_args[@]}")"
	rc=$?
	[ "$rc" -eq 0 ] || return "$rc"

	local pid values
	local -a pids=()
	values="$(printf '%s\n' "$choice" | _shell::zsh::fzf::values)"
	while IFS= read -r pid; do
		case "$pid" in
		'' | *[!0-9]*) continue ;;
		1 | "$$")
			shell::logger::warn "Skipping pid $pid (init / this shell)."
			continue
			;;
		esac
		pids+=("$pid")
	done <<<"$values"
	if [ "${#pids[@]}" -eq 0 ]; then
		shell::logger::warn "No process was chosen."
		return "$RETURN_EMPTY"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::exec::command -n kill -s "$signal" "${pids[@]}"
		return "$RETURN_SUCCESS"
	fi

	local failed=0
	for pid in "${pids[@]}"; do
		shell::logger::command "kill -s $signal $pid"
		kill -s "$signal" "$pid" 2>/dev/null || {
			shell::logger::warn "Cannot signal pid $pid (gone, or not yours)."
			failed=$((failed + 1))
		}
	done

	# Grace period: wait for them to exit before talking about SIGKILL.
	local waited=0 grace="${SHELL_ZSH_KILL_GRACE:-3}" alive=""
	case "$grace" in '' | *[!0-9]*) grace=3 ;; esac
	while :; do
		alive="$(_shell::zsh::process::alive "${pids[@]}")"
		[ -z "$alive" ] && break
		[ "$waited" -ge $((grace * 5)) ] && break
		sleep 0.2
		waited=$((waited + 1))
	done

	if [ -n "$alive" ] && [ "$signal" != "KILL" ]; then
		shell::logger::warn "Still running after ${grace}s:${alive}"
		if shell::ask::accept "Send SIGKILL to${alive}?"; then
			while IFS= read -r pid; do
				[ -n "$pid" ] || continue
				shell::logger::command "kill -s KILL $pid"
				kill -s KILL "$pid" 2>/dev/null || failed=$((failed + 1))
			done <<<"$(printf '%s\n' "$alive" | tr ' ' '\n')"
			sleep 0.2
			alive="$(_shell::zsh::process::alive "${pids[@]}")"
		fi
	fi

	if [ -n "$alive" ] || [ "$failed" -gt 0 ]; then
		[ -n "$alive" ] && shell::logger::error "Still running:${alive}"
		return "$RETURN_FAILURE"
	fi
	shell::logger::success "Stopped ${#pids[@]} process(es)."
}

# --------------------------------------------------------------------------
# ssh hosts
# --------------------------------------------------------------------------

# @internal
# @description Produce the ssh host candidates: the plain Host aliases, one per line.
#   A thin wrapper of the public shell::ssh::config::list.
# @arg $1 string The ssh config file, or empty for the default.
# @stdout The aliases.
# @exitcode 0 Success.
# @exitcode 3 The config file does not exist.
# @exitcode 8 It holds no alias.
# @example
#   _shell::zsh::ssh::candidates ""
#
_shell::zsh::ssh::candidates() {
	if [ -n "${1-}" ]; then
		shell::ssh::config::list --names -f "$1"
	else
		shell::ssh::config::list --names
	fi
}

# @description Pick a host alias from ~/.ssh/config with fzf and print it.
#   The preview is the alias's `Host` block of the config file. The alias is printed
#   (so it can be used in a command line, or inserted by the `shell-ssh-host` widget);
#   with `--connect` it is handed to shell::ssh::connect instead.
# @option -h | --help Show help and return.
# @option -c | --connect Connect to the chosen host (shell::ssh::connect).
# @option -n | --dry-run With --connect, print the ssh command instead of running it.
# @option -F | --file <path> Another ssh config file.
# @stdout The chosen alias (unless --connect).
# @exitcode 0 A host was chosen.
# @exitcode 2 Unknown option or missing value.
# @exitcode 3 fzf or the config file is missing.
# @exitcode 4 No terminal is available.
# @exitcode 8 The config has no alias.
# @exitcode 9 The user cancelled.
# @see shell::ssh::connect::fzf
# @example
#   host="$(shell::zsh::ssh::host::pick::fzf)"
#   shell::zsh::ssh::host::pick::fzf --connect
#
shell::zsh::ssh::host::pick::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick a host alias from ~/.ssh/config with fzf and print it"
		shell::logger::usage "shell::zsh::ssh::host::pick::fzf [-c] [-n] [-F <file>]"
		shell::logger::option "-c, --connect" "Connect to the chosen host"
		shell::logger::option "-n, --dry-run" "With --connect, print the ssh command"
		shell::logger::option "-F, --file <path>" "Another ssh config file"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "host=\"\$(shell::zsh::ssh::host::pick::fzf)\""
		return "$RETURN_SUCCESS"
	fi

	local connect="false" dry_run="false" file=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-c | --connect) connect="true" ;;
		-n | --dry-run) dry_run="true" ;;
		-F | --file)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			file="$2"
			shift
			;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done
	_shell::zsh::fzf::guard "Host picker" || return $?

	local candidates choice rc conf="${file:-$SHELL_SSH_CONFIG_FILE}"
	candidates="$(_shell::zsh::ssh::candidates "$file")" || return $?
	[ -n "$candidates" ] || return "$RETURN_EMPTY"

	choice="$(printf '%s\n' "$candidates" | shell::fzf::select --prompt="Host: " \
		--preview="awk -v host={} -f $(_shell::zsh::fzf::quote "$SHELL_ZSH_SSH_BLOCK_AWK") $(_shell::zsh::fzf::quote "$conf")" \
		"--preview-window=$SHELL_ZSH_PREVIEW_WINDOW")"
	rc=$?
	[ "$rc" -eq 0 ] || return "$rc"

	if [ "$connect" = "true" ]; then
		if [ "$dry_run" = "true" ]; then
			shell::ssh::connect -n "$choice"
		else
			shell::ssh::connect "$choice"
		fi
		return $?
	fi
	printf '%s\n' "$choice"
}

# --------------------------------------------------------------------------
# Bookmarks
# --------------------------------------------------------------------------

# @internal
# @description Produce the bookmark candidates: `<name> TAB <directory> TAB <row>`.
#   Reads the bookmark file (`<directory>|<name>` lines) in one awk pass.
# @stdout The candidates.
# @exitcode 0 Success (the list may be empty).
# @example
#   _shell::zsh::bookmark::candidates
#
_shell::zsh::bookmark::candidates() {
	[ -f "$SHELL_BOOKMARK_FILE" ] || return "$RETURN_SUCCESS"
	awk 'NF && index($0, "|") {
		dir = $0; sub(/\|[^|]*$/, "", dir)
		name = $0; sub(/^.*\|/, "", name)
		printf "%s\t%s\t%-20s %s\n", name, dir, name, dir
	}' "$SHELL_BOOKMARK_FILE"
}

# @description Pick a bookmark with fzf and go to its directory.
#   Candidates are the bookmarks of shell::bookmark::*; the preview lists the directory
#   (with `eza` when installed, `ls` otherwise). The move itself is shell::goto::run, so
#   it happens in the current shell. With `--print` the directory is printed instead.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the `cd` command instead of running it.
# @option -p | --print Print the chosen directory; do not change directory.
# @stdout The directory (with --print).
# @exitcode 0 Done.
# @exitcode 2 Unknown option.
# @exitcode 3 fzf is missing, or the bookmark's directory is gone.
# @exitcode 4 No terminal is available.
# @exitcode 8 There are no bookmarks.
# @exitcode 9 The user cancelled.
# @see shell::goto::run
# @example
#   shell::zsh::bookmark::goto::fzf
#   cd "$(shell::zsh::bookmark::goto::fzf --print)"
#
shell::zsh::bookmark::goto::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick a bookmark with fzf and go to its directory"
		shell::logger::usage "shell::zsh::bookmark::goto::fzf [-n] [-p]"
		shell::logger::option "-p, --print" "Print the directory instead of going there"
		shell::logger::option "-n, --dry-run" "Print the cd command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::zsh::bookmark::goto::fzf"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" print_only="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-p | --print) print_only="true" ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done
	_shell::zsh::fzf::guard "Bookmark picker" || return $?

	local candidates choice rc name dir preview rest
	candidates="$(_shell::zsh::bookmark::candidates)"
	if [ -z "$candidates" ]; then
		shell::logger::warn "There are no bookmarks (add one with shell::bookmark::add)."
		return "$RETURN_EMPTY"
	fi
	if command -v eza >/dev/null 2>&1; then
		preview="eza -1 --color=always {2}"
	else
		preview="ls -1A {2}"
	fi

	# {2} is the directory (fzf quotes it); the row shown is field 3; the value is the name.
	choice="$(printf '%s\n' "$candidates" | shell::fzf::select --delimiter=$'\t' --with-nth=3 --nth=3 \
		--prompt="Bookmark: " --preview="$preview" "--preview-window=$SHELL_ZSH_PREVIEW_WINDOW")"
	rc=$?
	[ "$rc" -eq 0 ] || return "$rc"

	name="${choice%%$'\t'*}"
	rest="${choice#*$'\t'}"
	dir="${rest%%$'\t'*}"
	if [ "$print_only" = "true" ]; then
		printf '%s\n' "$dir"
		return "$RETURN_SUCCESS"
	fi
	if [ "$dry_run" = "true" ]; then
		shell::exec::command -n cd "$dir"
		return "$RETURN_SUCCESS"
	fi
	shell::goto::run "$name"
}

# --------------------------------------------------------------------------
# Git worktrees
# --------------------------------------------------------------------------

# @internal
# @description Produce the worktree candidates: `<path> TAB <row>`.
#   One `git worktree list --porcelain` call and one awk pass; the row shows a `*` for
#   the worktree you are in, the branch (or `(detached)` / `(bare)`), the path and flags.
# @stdout The candidates.
# @exitcode 0 Success.
# @exitcode 3 Not inside a git repository.
# @example
#   _shell::zsh::worktree::candidates
#
_shell::zsh::worktree::candidates() {
	local out
	out="$(git worktree list --porcelain 2>/dev/null)" || return "$RETURN_NOT_FOUND"
	printf '%s\n' "$out" | awk -v cwd="$PWD" '
	function flush() {
		if (path == "") return
		label = (branch != "" ? branch : (bare ? "(bare)" : "(detached)"))
		here = (cwd == path || index(cwd, path "/") == 1) ? "*" : " "
		printf "%s\t%s %-28s %s%s\n", path, here, label, path, (flags != "" ? "  [" flags "]" : "")
		path = ""; branch = ""; flags = ""; bare = 0
	}
	function flag(f) { flags = flags (flags != "" ? "," : "") f }
	/^worktree / { flush(); path = substr($0, 10); next }
	/^branch / { branch = $2; sub(/^refs\/heads\//, "", branch); next }
	/^bare/ { bare = 1; flag("bare"); next }
	/^locked/ { flag("locked"); next }
	/^prunable/ { flag("prunable"); next }
	END { flush() }'
}

# @description Pick a git worktree of the current repository with fzf and go to it.
#   Lists every `git worktree` (including the ones made by shell::git::isolate::*),
#   previews its last commits, and changes to the chosen directory in the current shell.
#   With `--print` the path is printed instead.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the `cd` command instead of running it.
# @option -p | --print Print the chosen path; do not change directory.
# @stdout The path (with --print).
# @exitcode 0 Done.
# @exitcode 2 Unknown option.
# @exitcode 3 fzf or git is missing, not in a repository, or the worktree directory is gone.
# @exitcode 4 No terminal is available.
# @exitcode 8 There is nothing to pick.
# @exitcode 9 The user cancelled.
# @example
#   shell::zsh::git::worktree::switch::fzf
#   cd "$(shell::zsh::git::worktree::switch::fzf --print)"
#
shell::zsh::git::worktree::switch::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick a git worktree with fzf and go to it"
		shell::logger::usage "shell::zsh::git::worktree::switch::fzf [-n] [-p]"
		shell::logger::option "-p, --print" "Print the path instead of going there"
		shell::logger::option "-n, --dry-run" "Print the cd command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::zsh::git::worktree::switch::fzf"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" print_only="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-p | --print) print_only="true" ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done
	shell::dependency::git::ensure || return "$RETURN_NOT_FOUND"
	_shell::zsh::fzf::guard "Worktree picker" || return $?

	local candidates choice rc dir
	candidates="$(_shell::zsh::worktree::candidates)" || {
		shell::logger::error "Not inside a git repository."
		return "$RETURN_NOT_FOUND"
	}
	if [ -z "$candidates" ]; then
		shell::logger::warn "No worktrees found."
		return "$RETURN_EMPTY"
	fi

	choice="$(printf '%s\n' "$candidates" | shell::fzf::select --delimiter=$'\t' --with-nth=2.. --nth=2.. \
		--prompt="Worktree: " --preview='git -C {1} log --oneline --decorate --color=always -n 12' \
		"--preview-window=$SHELL_ZSH_PREVIEW_WINDOW")"
	rc=$?
	[ "$rc" -eq 0 ] || return "$rc"

	dir="${choice%%$'\t'*}"
	if [ ! -d "$dir" ]; then
		shell::logger::error "The worktree directory is gone: $dir (git worktree prune removes it)."
		return "$RETURN_NOT_FOUND"
	fi
	if [ "$print_only" = "true" ]; then
		printf '%s\n' "$dir"
		return "$RETURN_SUCCESS"
	fi
	if [ "$dry_run" = "true" ]; then
		shell::exec::command -n cd "$dir"
		return "$RETURN_SUCCESS"
	fi
	cd "$dir" || return "$RETURN_FAILURE"
	shell::logger::info "Changed directory to: $dir"
}

# --------------------------------------------------------------------------
# Hub menu
# --------------------------------------------------------------------------

# @internal
# @description Run the entry of the zsh hub menu that was picked.
#   A picker that was cancelled or had nothing to show is not an error of the menu.
# @arg $1 string The picked line: `<label> TAB <key>`.
# @exitcode 0 The entry ran (or ended without a pick).
# @exitcode N The entry failed with this status.
# @example
#   _shell::zsh::manage::dispatch "Search history	history"
#
_shell::zsh::manage::dispatch() {
	local key="${1#*$'\t'}" rc=0
	case "$key" in
	install) shell::zsh::install ;;
	history)
		if [ -n "${ZSH_VERSION-}" ]; then shell::zsh::history::search::fzf --push; else shell::zsh::history::search::fzf; fi
		;;
	kill) shell::zsh::process::kill::fzf ;;
	ssh) shell::zsh::ssh::host::pick::fzf ;;
	bookmark) shell::zsh::bookmark::goto::fzf ;;
	worktree) shell::zsh::git::worktree::switch::fzf ;;
	cache) shell::zsh::cache::clear ;;
	*) shell::logger::warn "Unknown entry: $key" ;;
	esac
	rc=$?
	case "$rc" in
	"$RETURN_CANCELLED" | "$RETURN_EMPTY" | "$RETURN_BACK") return "$RETURN_SUCCESS" ;;
	esac
	return "$rc"
}

# @description Open the zsh menu: install the hook, history, processes, hosts, bookmarks, worktrees.
#   A hub on shell::fzf::loop: after an action the menu comes back with the cursor on the
#   entry you used; ESC or the "← Back" entry leaves it.
# @option -h | --help Show help and return.
# @exitcode 0 The menu was left.
# @exitcode 4 No terminal is available.
# @example
#   shell::zsh::manage::fzf
#
shell::zsh::manage::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Open the zsh menu (hook, history, processes, hosts, bookmarks, worktrees)"
		shell::logger::usage "shell::zsh::manage::fzf"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::zsh::manage::fzf"
		return "$RETURN_SUCCESS"
	fi
	_shell::zsh::fzf::guard "The zsh menu" || return $?

	printf '%s\n' \
		"Install / repair the zsh hook	install" \
		"Search history	history" \
		"Kill processes	kill" \
		"Pick an ssh host	ssh" \
		"Go to a bookmark	bookmark" \
		"Switch git worktree	worktree" \
		"Clear the picker cache	cache" |
		shell::fzf::loop --back --pause -f --delimiter=$'\t' -f --with-nth=1 -f --prompt="zsh: " _shell::zsh::manage::dispatch
}
