#!/usr/bin/env bash
# @file lang/git/_core/fzf.sh
# @brief The one picker behind every interactive list, with a numbered-prompt fallback.
# @description
#   Records are `raw<US>display` where US is the unit separator (octal 037): the first field is what the
#   caller gets back, the rest is shown. fzf hides the first field (`--with-nth=2..`), so ANSI
#   colors in the display never corrupt what is returned. Input records end with a newline, or with NUL
#   when `-0` is given (paths with newlines).
#
#   Key bindings (never ctrl-c, which aborts; never ctrl-s, swallowed by terminal flow control; never ctrl-d,
#   which quits fzf on an empty query): `tab`/`shift-tab` multi-select where enabled, `esc`/`ctrl-c` abort,
#   `ctrl-/` toggles the preview, `?` shows the key help line. `log::pick` adds its own bindings.
#   Minimum: fzf 0.19. Without a usable fzf, or without a terminal, see `_shell::git::core::pick`.

# @internal
# @description Split a whitespace separated string into the global array `_SHELL_GIT_WORDS` (bash and zsh alike).
# @arg $1 string The string.
# @exitcode 0 Always.
# @example
#   _shell::git::core::split "$SHELL_GIT_FZF_OPTS"; fzf "${_SHELL_GIT_WORDS[@]}"
#
_shell::git::core::split() {
	if [ -n "${ZSH_VERSION-}" ]; then
		setopt local_options sh_word_split noglob
	else
		set -f
	fi
	# shellcheck disable=SC2206
	_SHELL_GIT_WORDS=(${1-})
	[ -n "${ZSH_VERSION-}" ] || set +f
	return 0
}

# @internal
# @description Pick one or several records from a list on stdin.
#   With fzf (>= 0.19) and a terminal: a fuzzy picker (`--ansi`, hidden first field, optional preview and bindings,
#   plus `SHELL_GIT_FZF_OPTS`). Otherwise, with a terminal or `SHELL_GIT_INPUT`: a numbered list on stderr and a
#   prompt (numbers separated by spaces when `--multi`). Without any of these: refused with exit 2.
#   Cancelling (esc, ctrl-c, no match, empty answer) is exit 5 and prints nothing.
# @option --multi Allow several selections.
# @option -0 Records end with NUL instead of newline.
# @option --prompt <text> Prompt (default `pick`).
# @option --header <text> Header line (key hints).
# @option --preview <cmd> fzf preview command; `{1}` is the raw field, safely quoted by fzf.
# @option --bind <spec> Extra fzf binding, repeatable.
# @option --query <text> Initial query.
# @stdout The raw first field of every selected record, one per line (NUL-terminated with `-0`).
# @exitcode 0 Something was selected.
# @exitcode 5 Cancelled.
# @exitcode 2 No terminal to ask on.
# @example
#   printf 'main\037main  (current)\n' | _shell::git::core::pick --prompt branch
#
_shell::git::core::pick() {
	local multi=0 nul=0 prompt="pick" header="" preview="" query="" rec raw n=0 answer word rc
	local -a binds=() items=() fzf_args=()
	while [ $# -gt 0 ]; do
		case "$1" in
		--multi) multi=1 ;;
		-0) nul=1 ;;
		--prompt) prompt="$2" && shift ;;
		--header) header="$2" && shift ;;
		--preview) preview="$2" && shift ;;
		--bind) binds+=("$2") && shift ;;
		--query) query="$2" && shift ;;
		esac
		shift
	done
	_shell::git::core::env

	if [ -z "${SHELL_GIT_INPUT-}" ] && { [ ! -t 2 ] || [ ! -r /dev/tty ]; } && [ -z "${SHELL_GIT_FORCE_FZF-}" ]; then
		_shell::git::core::err "no terminal to pick from: pass the value as an argument"
		return 2
	fi

	if { [ -z "${SHELL_GIT_INPUT-}" ] || [ -n "${SHELL_GIT_FORCE_FZF-}" ]; } && _shell::git::core::fzf_ok; then
		fzf_args=(--ansi --delimiter=$'\037' --with-nth=2.. --layout=reverse --info=inline --prompt "$prompt> " --bind 'ctrl-/:toggle-preview' --bind 'esc:abort')
		[ "$nul" = "1" ] && fzf_args+=(--read0 --print0)
		[ "$multi" = "1" ] && fzf_args+=(--multi --bind 'tab:toggle+down' --bind 'shift-tab:toggle+up')
		[ -n "$header" ] && fzf_args+=(--header "$header")
		[ -n "$query" ] && fzf_args+=(--query "$query")
		[ -n "$preview" ] && fzf_args+=(--preview "$preview" --preview-window 'right:60%:wrap')
		for word in "${binds[@]}"; do
			[ -n "$word" ] && fzf_args+=(--bind "$word")
		done
		_shell::git::core::split "$SHELL_GIT_FZF_OPTS"
		for word in "${_SHELL_GIT_WORDS[@]}"; do
			fzf_args+=("$word")
		done
		local out tmp
		if [ "$nul" = "1" ]; then
			# A shell variable cannot hold NUL bytes: keep the selection in a private temp file.
			tmp="$(mktemp "${TMPDIR:-/tmp}/shell-git-pick.XXXXXX")" || return 1
			fzf "${fzf_args[@]}" >"$tmp"
			rc=$?
			if [ "$rc" -ne 0 ] || [ ! -s "$tmp" ]; then
				rm -f "$tmp"
				return 5
			fi
			while IFS= read -r -d '' rec; do
				printf '%s\0' "${rec%%$'\037'*}"
			done <"$tmp"
			rm -f "$tmp"
			return 0
		fi
		out="$(fzf "${fzf_args[@]}")"
		rc=$?
		if [ "$rc" -ne 0 ] || [ -z "$out" ]; then
			return 5
		fi
		# Keep only the raw first field of every selected record.
		while IFS= read -r rec; do
			printf '%s\n' "${rec%%$'\037'*}"
		done <<LZ_EOF
$out
LZ_EOF
		return 0
	fi

	# Numbered fallback: show the display column, ask for numbers.
	if [ "$nul" = "1" ]; then
		while IFS= read -r -d '' rec; do
			n=$((n + 1))
			items+=("${rec%%$'\037'*}")
			printf '%3d) %s\n' "$n" "${rec#*$'\037'}" >&2
		done
	else
		while IFS= read -r rec; do
			n=$((n + 1))
			items+=("${rec%%$'\037'*}")
			printf '%3d) %s\n' "$n" "${rec#*$'\037'}" >&2
		done
	fi
	[ "$n" -gt 0 ] || return 5
	if [ "$multi" = "1" ]; then
		printf '%s (numbers separated by spaces, empty to cancel): ' "$prompt" >&2
	else
		printf '%s (number, empty to cancel): ' "$prompt" >&2
	fi
	_shell::git::core::readline answer || {
		printf '\n' >&2
		return 5
	}
	[ -n "$answer" ] || return 5
	local picked=0
	if [ -n "${ZSH_VERSION-}" ]; then
		setopt local_options sh_word_split
	fi
	for word in $answer; do
		case "$word" in
		*[!0-9]* | "")
			_shell::git::core::err "not a number: $word"
			return 5
			;;
		esac
		if [ "$word" -lt 1 ] || [ "$word" -gt "$n" ]; then
			_shell::git::core::err "out of range: $word"
			return 5
		fi
		# bash arrays count from 0, zsh from 1: both are addressed through a loop-free helper.
		_shell::git::core::nth "$word" "${items[@]}"
		if [ "$nul" = "1" ]; then printf '%s\0' "$_SHELL_GIT_NTH"; else printf '%s\n' "$_SHELL_GIT_NTH"; fi
		picked=$((picked + 1))
		[ "$multi" = "1" ] || break
	done
	[ "$picked" -gt 0 ] || return 5
	return 0
}

# @internal
# @description Pick the Nth argument (1-based) into `_SHELL_GIT_NTH`. Isolates the bash/zsh array index difference.
# @arg $1 integer N, starting at 1.
# @arg $@ string The list.
# @exitcode 0 Always.
# @example
#   _shell::git::core::nth 2 a b c   # _SHELL_GIT_NTH=b
#
_shell::git::core::nth() {
	local n="$1"
	shift
	while [ "$n" -gt 1 ]; do
		shift
		n=$((n - 1))
	done
	_SHELL_GIT_NTH="${1-}"
	return 0
}

# @internal
# @description Emit one picker record on stdout: `raw<US>display`, newline- or NUL-terminated.
# @arg $1 string Raw value returned to the caller.
# @arg $2 string Text shown to the user.
# @arg $3 string `0` to end with NUL instead of newline.
# @stdout The record.
# @exitcode 0 Always.
# @example
#   _shell::git::core::rec "main" "main  2 days ago"
#
_shell::git::core::rec() {
	if [ "${3-}" = "0" ]; then
		printf '%s\037%s\0' "$1" "$2"
	else
		printf '%s\037%s\n' "$1" "$2"
	fi
}
