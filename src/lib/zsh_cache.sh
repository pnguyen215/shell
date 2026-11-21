#!/usr/bin/env bash
# @file lib/zsh_cache.sh
# @brief TTL cache of slow candidate lists (stale-while-revalidate) for the zsh pickers.
# @description
#   Entries live in `$SHELL_ZSH_CACHE_DIR` (default `~/.shell-config/cache/zsh`, mode 700,
#   files 600). A fresh entry is served as it is; an entry older than the TTL is served
#   at once and refreshed in the background, so the picker never waits for it; a missing
#   entry (or `--refresh`) is generated first. Every write is a temp file and a `mv`.

# @internal
# @description Path of the cache file of a key (the key is reduced to safe characters).
# @arg $1 string The key.
# @stdout The path.
# @exitcode 0 Always.
# @example
#   file="$(_shell::zsh::cache::file history-1234)"
#
_shell::zsh::cache::file() {
	local key
	key="$(printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_')"
	printf '%s/%s.cache\n' "$SHELL_ZSH_CACHE_DIR" "$key"
}

# @internal
# @description Run a producer and store its output atomically (mode 600), then stamp it.
#   Nothing is stored when the producer fails or prints nothing.
# @arg $1 string The cache file.
# @arg $@ string The producer command and its arguments.
# @exitcode 0 Stored.
# @exitcode N The producer's exit status (an empty result is RETURN_EMPTY).
# @example
#   _shell::zsh::cache::fill "$file" _shell::zsh::history::from_file "$HISTFILE"
#
_shell::zsh::cache::fill() {
	local file="$1" tmp rc
	shift
	tmp="$file.tmp.$$"
	shell::fs::mkdir --private "$SHELL_ZSH_CACHE_DIR" >/dev/null 2>&1 || return "$RETURN_FAILURE"
	(umask 077 && "$@" >"$tmp")
	rc=$?
	if [ "$rc" -ne 0 ] || [ ! -s "$tmp" ]; then
		rm -f "$tmp"
		[ "$rc" -ne 0 ] && return "$rc"
		return "$RETURN_EMPTY"
	fi
	mv -f "$tmp" "$file" || {
		rm -f "$tmp"
		return "$RETURN_FAILURE"
	}
	(umask 077 && date +%s >"$file.ts.$$" && mv -f "$file.ts.$$" "$file.ts")
}

# @internal
# @description Print a cached list, generating or refreshing it as needed.
#   Fresh: served. Stale: served, refreshed in the background. Missing or `refresh`:
#   generated synchronously. The producer runs in a subshell when it refreshes.
# @arg $1 string "refresh" to force a synchronous regeneration, anything else to use the cache.
# @arg $2 string The key.
# @arg $3 string TTL in seconds.
# @arg $@ string The producer command and its arguments.
# @stdout The list.
# @exitcode 0 A list was printed.
# @exitcode 8 The producer gave nothing.
# @exitcode N The producer's exit status.
# @example
#   _shell::zsh::cache::get "" history 300 _shell::zsh::history::from_file "$file"
#
_shell::zsh::cache::get() {
	local force="$1" key="$2" ttl="$3" file stamp="" now
	shift 3
	file="$(_shell::zsh::cache::file "$key")"

	if [ "$force" != "refresh" ] && [ -s "$file" ]; then
		[ -f "$file.ts" ] && read -r stamp <"$file.ts"
		now="$(date +%s)"
		case "$stamp" in
		'' | *[!0-9]*) stamp=0 ;;
		esac
		if [ $((now - stamp)) -ge "$ttl" ]; then
			# Stale: refresh behind the scenes (a subshell that backgrounds, so no job notice).
			( (_shell::zsh::cache::fill "$file" "$@" >/dev/null 2>&1) &)
		fi
		cat "$file"
		return "$RETURN_SUCCESS"
	fi

	_shell::zsh::cache::fill "$file" "$@" || return $?
	cat "$file"
}

# @description Delete the cached candidate lists of the zsh pickers.
#   Removes the files of `$SHELL_ZSH_CACHE_DIR` only (never anything else); they are
#   rebuilt on the next use.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @exitcode 0 The cache is empty (or was already).
# @exitcode 1 A file could not be removed.
# @exitcode 2 Unknown option.
# @example
#   shell::zsh::cache::clear
#   shell::zsh::cache::clear -n
#
shell::zsh::cache::clear() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Delete the cached candidate lists of the zsh pickers"
		shell::logger::usage "shell::zsh::cache::clear [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::zsh::cache::clear"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	case "${1-}" in
	-n | --dry-run) dry_run="true" ;;
	"") ;;
	*)
		shell::logger::error "Unknown option: $1"
		return "$RETURN_INVALID"
		;;
	esac

	case "$SHELL_ZSH_CACHE_DIR" in
	"" | "/" | "$HOME" | "$HOME/")
		shell::logger::error "Refusing to clear an unsafe cache directory: '$SHELL_ZSH_CACHE_DIR'"
		return "$RETURN_INVALID"
		;;
	esac
	if [ ! -d "$SHELL_ZSH_CACHE_DIR" ]; then
		shell::logger::info "The cache is already empty."
		return "$RETURN_SUCCESS"
	fi
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "find '$SHELL_ZSH_CACHE_DIR' -maxdepth 1 -type f -name '*.cache*' -exec rm -f {} +"
		return "$RETURN_SUCCESS"
	fi
	find "$SHELL_ZSH_CACHE_DIR" -maxdepth 1 -type f -name '*.cache*' -exec rm -f {} + || return "$RETURN_FAILURE"
	shell::logger::success "Cleared the zsh picker cache ($SHELL_ZSH_CACHE_DIR)."
}
