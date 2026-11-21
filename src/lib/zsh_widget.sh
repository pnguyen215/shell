#!/usr/bin/env bash
# @file lib/zsh_widget.sh
# @brief Optional ZLE widgets: paste a picked history entry, host, directory or worktree into the command line.
# @description
#   zsh only, and opt-in: nothing is registered or bound unless you set
#   `SHELL_ZSH_WIDGETS=1` before sourcing the library (or call
#   shell::zsh::widget::enable yourself). Widgets are named `shell-*`; a key is bound
#   only when it is still unbound, so fzf's and your own bindings are never replaced.
#   The widget functions are plain functions that do nothing outside a zsh widget.

# @internal
# @description Run a picker inside a ZLE widget and give back what it printed.
#   The prompt is redrawn afterwards, whatever happened.
# @arg $@ string The picker command line.
# @stdout The picked value (empty when cancelled).
# @exitcode 0 Always.
# @example
#   picked="$(_shell::zsh::widget::pick shell::zsh::ssh::host::pick::fzf)"
#
_shell::zsh::widget::pick() {
	local out
	out="$("$@" 2>/dev/null)"
	printf '%s' "$out"
}

# @internal
# @description Widget body: replace the line with a command chosen from the history.
# @noargs
# @exitcode 0 Always.
# @example
#   zle -N shell-history _shell::zsh::widget::history
#
_shell::zsh::widget::history() {
	local picked
	zle -I
	picked="$(_shell::zsh::widget::pick shell::zsh::history::search::fzf --query "$LBUFFER")"
	if [ -n "$picked" ]; then
		BUFFER="$picked"
		CURSOR="${#BUFFER}"
	fi
	zle reset-prompt
}

# @internal
# @description Insert a value, quoted as one word, at the cursor.
# @arg $1 string The value.
# @arg $2 string "quote" to shell-quote it (paths), anything else to insert it as it is (host names).
# @exitcode 0 Always.
# @example
#   _shell::zsh::widget::insert "$dir" quote
#
_shell::zsh::widget::insert() {
	local text="$1"
	[ -n "$text" ] || return "$RETURN_SUCCESS"
	[ "${2-}" = "quote" ] && text="$(_shell::zsh::fzf::quote "$text")"
	LBUFFER="${LBUFFER}${text} "
}

# @internal
# @description Widget body: insert an ssh host alias.
# @noargs
# @exitcode 0 Always.
# @example
#   zle -N shell-ssh-host _shell::zsh::widget::ssh_host
#
_shell::zsh::widget::ssh_host() {
	zle -I
	_shell::zsh::widget::insert "$(_shell::zsh::widget::pick shell::zsh::ssh::host::pick::fzf)"
	zle reset-prompt
}

# @internal
# @description Widget body: insert the directory of a git worktree.
# @noargs
# @exitcode 0 Always.
# @example
#   zle -N shell-worktree _shell::zsh::widget::worktree
#
_shell::zsh::widget::worktree() {
	zle -I
	_shell::zsh::widget::insert "$(_shell::zsh::widget::pick shell::zsh::git::worktree::switch::fzf --print)" quote
	zle reset-prompt
}

# @internal
# @description Widget body: insert the directory of a bookmark.
# @noargs
# @exitcode 0 Always.
# @example
#   zle -N shell-bookmark _shell::zsh::widget::bookmark
#
_shell::zsh::widget::bookmark() {
	zle -I
	_shell::zsh::widget::insert "$(_shell::zsh::widget::pick shell::zsh::bookmark::goto::fzf --print)" quote
	zle reset-prompt
}

# @description Register the shell-* ZLE widgets and bind their keys where the keys are free (zsh only).
#   Widgets: `shell-history` (replace the line with a history entry), `shell-ssh-host`,
#   `shell-worktree` and `shell-bookmark` (insert the pick at the cursor). Keys come from
#   `SHELL_ZSH_KEY_HISTORY`, `_SSH`, `_WORKTREE`, `_BOOKMARK` (defaults ^Xh ^Xj ^Xw ^Xb). A key that is
#   already bound to anything is left alone and reported; running this again changes nothing.
#   Set `SHELL_ZSH_WIDGETS=1` before sourcing the library to do this automatically in an
#   interactive zsh.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print what would be registered and bound; change nothing.
# @exitcode 0 The widgets are registered (some keys may have been skipped).
# @exitcode 2 Unknown option.
# @exitcode 4 Not an interactive zsh.
# @example
#   shell::zsh::widget::enable
#   SHELL_ZSH_KEY_HISTORY='^X^H' shell::zsh::widget::enable
#
shell::zsh::widget::enable() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Register the shell-* ZLE widgets and bind their keys where free (zsh)"
		shell::logger::usage "shell::zsh::widget::enable [-n]"
		shell::logger::option "-n, --dry-run" "Print what would be registered and bound"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::zsh::widget::enable"
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
	if [ -z "${ZSH_VERSION-}" ]; then
		shell::logger::error "ZLE widgets need zsh."
		return "$RETURN_NOT_SUPPORTED"
	fi
	case "$-" in
	*i*) ;;
	*)
		if [ "$dry_run" != "true" ]; then
			shell::logger::error "ZLE widgets need an interactive zsh."
			return "$RETURN_NOT_SUPPORTED"
		fi
		;;
	esac

	local row widget fn key current
	for row in \
		"shell-history|_shell::zsh::widget::history|$SHELL_ZSH_KEY_HISTORY" \
		"shell-ssh-host|_shell::zsh::widget::ssh_host|$SHELL_ZSH_KEY_SSH" \
		"shell-worktree|_shell::zsh::widget::worktree|$SHELL_ZSH_KEY_WORKTREE" \
		"shell-bookmark|_shell::zsh::widget::bookmark|$SHELL_ZSH_KEY_BOOKMARK"; do
		widget="${row%%|*}"
		fn="${row#*|}"
		key="${fn#*|}"
		fn="${fn%%|*}"
		# A key is "free" when bindkey reports it as undefined-key (or says nothing).
		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "zle -N $widget $fn; bindkey '$key' $widget   # only if '$key' is unbound"
			continue
		fi
		zle -N "$widget" "$fn"
		current="$(bindkey "$key" 2>/dev/null)"
		case "$current" in
		"" | *" undefined-key") bindkey "$key" "$widget" ;;
		*" $widget") ;;
		*) shell::logger::warn "Key $key is already bound ($current); $widget is registered but not bound." ;;
		esac
	done
}

# Opt-in at source time: one variable test, nothing else runs unless it is 1.
if [ "${SHELL_ZSH_WIDGETS:-0}" = "1" ] && [ -n "${ZSH_VERSION-}" ]; then
	case "$-" in
	*i*) shell::zsh::widget::enable >/dev/null 2>&1 ;;
	esac
fi
