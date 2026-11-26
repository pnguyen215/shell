#!/usr/bin/env bash
# @file lang/git/_core/stage.sh
# @brief Private helpers shared by the shell::git::stage::* functions.
# @description
#   Owned by the stage group. One `git status --porcelain=v2 -z` call is parsed into entries; every
#   entry is a RAW string `<class><X><Y>:<path>` (plus `<RS><original path>` for renames and copies,
#   RS = octal 036). Classes: `t` tracked, `r` renamed or copied, `u` untracked, `c` conflicted,
#   `s` submodule. X is the index state and Y the working-tree state (`.` = unchanged, `?` = untracked),
#   kept independent. Picker records are `<raw><US><display>` ending with NUL, so any file name works.
#   Every git command that receives user paths runs with `GIT_LITERAL_PATHSPECS=1`: a file called
#   `glob[*]?.txt` is that file, never a pattern.

# @internal
# @description Set `_SHELL_GIT_LB` to the word for a one-letter status code.
# @arg $1 string The status letter (`M A D R C T U` or `.`).
# @exitcode 0 Always.
# @example
#   _shell::git::core::stage_label M   # modified
#
_shell::git::core::stage_label() {
	case "$1" in
	M) _SHELL_GIT_LB="modified" ;;
	A) _SHELL_GIT_LB="added" ;;
	D) _SHELL_GIT_LB="deleted" ;;
	R) _SHELL_GIT_LB="renamed" ;;
	C) _SHELL_GIT_LB="copied" ;;
	T) _SHELL_GIT_LB="typechange" ;;
	U) _SHELL_GIT_LB="conflicted" ;;
	*) _SHELL_GIT_LB="-" ;;
	esac
	return 0
}

# @internal
# @description Split a RAW entry into the globals `_SHELL_GIT_ST_CLASS`, `_SHELL_GIT_ST_X`, `_SHELL_GIT_ST_Y`,
#   `_SHELL_GIT_ST_FILE` and `_SHELL_GIT_ST_ORIG` (empty unless renamed or copied).
# @arg $1 string The raw entry.
# @exitcode 0 Always.
# @example
#   _shell::git::core::stage_parse "tM.:a file.txt"
#
_shell::git::core::stage_parse() {
	local r="$1" rest
	_SHELL_GIT_ST_CLASS="${r:0:1}"
	_SHELL_GIT_ST_X="${r:1:1}"
	_SHELL_GIT_ST_Y="${r:2:1}"
	rest="${r:4}"
	_SHELL_GIT_ST_FILE="${rest%%$'\036'*}"
	case "$rest" in
	*$'\036'*) _SHELL_GIT_ST_ORIG="${rest#*$'\036'}" ;;
	*) _SHELL_GIT_ST_ORIG="" ;;
	esac
	return 0
}

# @internal
# @description Write one entry to stdout if it passes the filter: a picker record (`rec`) or the bare raw string (`raw`), NUL-terminated.
# @arg $1 string Filter: `stage` (something to stage), `unstage` (something staged), `discard` or `any` (everything).
# @arg $2 string Mode: `rec` or `raw`.
# @arg $3 string The raw entry.
# @arg $4 string Optional original path (rename or copy).
# @stdout The NUL-terminated record.
# @exitcode 0 Always.
# @example
#   _shell::git::core::stage_emit stage rec "tM.:a.txt"
#
_shell::git::core::stage_emit() {
	local filter="$1" mode="$2" raw="$3" orig="${4-}" class x y file shown disp sl yl sc yc suffix=""
	class="${raw:0:1}"
	x="${raw:1:1}"
	y="${raw:2:1}"
	file="${raw:4}"
	case "$filter" in
	stage)
		case "$class" in
		c | u) ;;
		*) [ "$y" != "." ] || return 0 ;;
		esac
		;;
	unstage)
		case "$class" in
		c | u) return 0 ;;
		esac
		[ "$x" != "." ] || return 0
		;;
	esac
	[ -n "$orig" ] && raw="$raw"$'\036'"$orig"
	if [ "$mode" = "raw" ]; then
		printf '%s\0' "$raw"
		return 0
	fi
	sc="${_SHELL_GIT_C_GREEN-}"
	yc="${_SHELL_GIT_C_YELLOW-}"
	case "$class" in
	c)
		sl="conflicted"
		yl="conflicted"
		sc="${_SHELL_GIT_C_RED-}"
		yc="${_SHELL_GIT_C_RED-}"
		;;
	u)
		sl="-"
		yl="untracked"
		yc="${_SHELL_GIT_C_CYAN-}"
		;;
	*)
		_shell::git::core::stage_label "$x"
		sl="$_SHELL_GIT_LB"
		_shell::git::core::stage_label "$y"
		yl="$_SHELL_GIT_LB"
		[ "$y" = "D" ] && yc="${_SHELL_GIT_C_RED-}"
		[ "$class" = "s" ] && suffix=" (submodule)"
		;;
	esac
	shown="$file"
	[ -n "$orig" ] && shown="$orig -> $file"
	shown="${shown//$'\n'/\\n}"
	shown="${shown//$'\t'/\\t}"
	printf -v disp '%s%-10s%s  %s%-10s%s  %s%s' "$sc" "$sl" "${_SHELL_GIT_C_RESET-}" "$yc" "$yl" "${_SHELL_GIT_C_RESET-}" "$shown" "$suffix"
	printf '%s\037%s\0' "$raw" "$disp"
}

# @internal
# @description Scan the working tree with ONE `git status --porcelain=v2 -z -uall` call and emit the entries.
# @arg $1 string Filter (see `_shell::git::core::stage_emit`).
# @arg $2 string Mode: `rec` (picker records, colored unless NO_COLOR) or `raw`.
# @stdout NUL-terminated records, paths relative to the repository root.
# @exitcode 0 Always.
# @example
#   _shell::git::core::stage_scan stage rec > "$tmp/in"
#
_shell::git::core::stage_scan() {
	local filter="$1" mode="$2" rec kind tmp xy sub n i file class pending=""
	[ "$mode" = "rec" ] && _shell::git::core::colors 1
	while IFS= read -r -d '' rec; do
		if [ -n "$pending" ]; then
			# The record after a rename/copy is its original path.
			_shell::git::core::stage_emit "$filter" "$mode" "$pending" "$rec"
			pending=""
			continue
		fi
		case "$rec" in
		"1 "* | "2 "* | "u "*)
			kind="${rec%% *}"
			tmp="${rec#* }"
			xy="${tmp%% *}"
			tmp="${tmp#* }"
			sub="${tmp%% *}"
			case "$kind" in
			1) n=8 ;;
			2) n=9 ;;
			*) n=10 ;;
			esac
			file="$rec"
			i=0
			while [ "$i" -lt "$n" ]; do
				file="${file#* }"
				i=$((i + 1))
			done
			class="t"
			[ "$kind" = "u" ] && class="c"
			[ "$kind" = "2" ] && class="r"
			[ "$class" = "t" ] && [ "${sub:0:1}" = "S" ] && class="s"
			if [ "$kind" = "2" ]; then
				pending="$class$xy:$file"
			else
				_shell::git::core::stage_emit "$filter" "$mode" "$class$xy:$file"
			fi
			;;
		"? "*)
			_shell::git::core::stage_emit "$filter" "$mode" "u.?:${rec#? }"
			;;
		esac
	done < <(_shell::git::core::stage_git_ro status --porcelain=v2 -z -uall 2>/dev/null)
	return 0
}

# @internal
# @description Tell whether the picker has somewhere to ask: a terminal, a scripted answer file or a forced fzf.
# @exitcode 0 It can ask.
# @exitcode 1 It cannot.
# @example
#   _shell::git::core::stage_can_pick || return 2
#
_shell::git::core::stage_can_pick() {
	[ -n "${SHELL_GIT_INPUT-}" ] && return 0
	[ -n "${SHELL_GIT_FORCE_FZF-}" ] && return 0
	[ -t 2 ] && [ -r /dev/tty ]
}

# @internal
# @description Run git against the repository root, with literal pathspecs (read-write).
#   `git status` reports paths relative to the root while the user types paths relative to the current
#   directory, so every stage command runs with `-C <root>` on root-relative paths.
# @arg $@ string Arguments of git.
# @exitcode * Git's own.
# @example
#   _shell::git::core::stage_git add -- "a file.txt"
#
_shell::git::core::stage_git() {
	GIT_LITERAL_PATHSPECS=1 _shell::git::core::git_rw -C "${_SHELL_GIT_ST_TOP:-.}" "$@"
}

# @internal
# @description Read-only variant of `_shell::git::core::stage_git`.
# @arg $@ string Arguments of git.
# @exitcode * Git's own.
# @example
#   _shell::git::core::stage_git_ro clean -n -- "new file.txt"
#
_shell::git::core::stage_git_ro() {
	GIT_LITERAL_PATHSPECS=1 _shell::git::core::git_ro -C "${_SHELL_GIT_ST_TOP:-.}" "$@"
}

# @internal
# @description Dry-run output for a stage command: `git <args>`, with `-C <root>` when run below the root.
# @arg $@ string Arguments of git.
# @stdout The quoted command.
# @exitcode 0 Always.
# @example
#   _shell::git::core::stage_dry add -- a.txt
#
_shell::git::core::stage_dry() {
	if [ -n "${_SHELL_GIT_ST_PFX-}" ]; then
		_shell::git::core::dry git -C "$_SHELL_GIT_ST_TOP" "$@"
	else
		_shell::git::core::dry git "$@"
	fi
}

# @internal
# @description Tell whether an entry belongs to the paths the user named (root-relative): the same file or
#   directory, either side of a rename, or anything under a named directory. An empty path matches all.
# @arg $1 string The entry's file.
# @arg $2 string The entry's original path (may be empty).
# @arg $@ string The root-relative paths.
# @exitcode 0 It matches.
# @exitcode 1 It does not.
# @example
#   _shell::git::core::stage_match "src/a.c" "" "src"
#
_shell::git::core::stage_match() {
	local file="$1" orig="$2" want
	shift 2
	for want in "$@"; do
		want="${want%/}"
		[ -z "$want" ] && return 0
		case "$file" in "$want" | "$want"/*) return 0 ;; esac
		if [ -n "$orig" ]; then
			case "$orig" in "$want" | "$want"/*) return 0 ;; esac
		fi
	done
	return 1
}

# @internal
# @description Fill the global array `_SHELL_GIT_ST_RAWS` with the entries to act on: the entries matching the
#   explicit paths when given, otherwise what the user picks. Sets `_SHELL_GIT_ST_TOP` (repository root) and
#   `_SHELL_GIT_ST_PFX` (current directory below the root, with a trailing slash, or empty). Temporary files
#   live in a private directory removed before returning.
# @arg $1 string Filter for the picker listing (`stage`, `unstage`, `discard`).
# @arg $2 string Picker prompt.
# @arg $@ string Optional `--` then the explicit paths (relative to the current directory).
# @exitcode 0 Entries selected (the array may be empty when there is nothing to do).
# @exitcode 2 No paths and nowhere to ask, or a path this function cannot place.
# @exitcode 5 The user cancelled.
# @exitcode 1 A temporary file could not be created.
# @example
#   _shell::git::core::stage_select stage "stage" -- "${paths[@]}" || return $?
#
_shell::git::core::stage_select() {
	local filter="$1" prompt="$2" dir rc=0 raw arg rel hits
	local -a want=()
	shift 2
	[ "${1-}" = "--" ] && shift
	_SHELL_GIT_ST_RAWS=()
	if [ "$#" -eq 0 ] && ! _shell::git::core::stage_can_pick; then
		_shell::git::core::err "no terminal to pick from: pass the paths as arguments"
		return 2
	fi
	{
		read -r _SHELL_GIT_ST_TOP
		read -r _SHELL_GIT_ST_PFX
	} <<LZ_EOF
$(_shell::git::core::git_ro rev-parse --show-toplevel --show-prefix 2>/dev/null)
LZ_EOF
	[ -n "$_SHELL_GIT_ST_TOP" ] || return 3
	for arg in "$@"; do
		case "$arg" in
		/*)
			case "$arg" in
			"$_SHELL_GIT_ST_TOP"/*) rel="${arg#"$_SHELL_GIT_ST_TOP"/}" ;;
			"$_SHELL_GIT_ST_TOP") rel="" ;;
			*)
				_shell::git::core::err "$arg is outside the repository"
				return 2
				;;
			esac
			;;
		.. | ../* | */../* | */..)
			_shell::git::core::err "paths with '..' are not supported: $arg (run it from the repository root)"
			return 2
			;;
		.) rel="$_SHELL_GIT_ST_PFX" ;;
		./*) rel="$_SHELL_GIT_ST_PFX${arg#./}" ;;
		*) rel="$_SHELL_GIT_ST_PFX$arg" ;;
		esac
		want+=("$rel")
	done
	dir="$(mktemp -d "${TMPDIR:-/tmp}/shell-git-stage.XXXXXX")" || return 1
	if [ "$#" -gt 0 ]; then
		_shell::git::core::stage_scan any raw >"$dir/all"
		hits=0
		while IFS= read -r -d '' raw; do
			_shell::git::core::stage_parse "$raw"
			if _shell::git::core::stage_match "$_SHELL_GIT_ST_FILE" "$_SHELL_GIT_ST_ORIG" "${want[@]}"; then
				_SHELL_GIT_ST_RAWS+=("$raw")
				hits=$((hits + 1))
			fi
		done <"$dir/all"
		rm -rf "$dir"
		[ "$hits" -gt 0 ] || _shell::git::core::info "no changes found for the given paths"
		return 0
	fi
	_shell::git::core::stage_scan "$filter" rec >"$dir/in"
	if [ ! -s "$dir/in" ]; then
		rm -rf "$dir"
		return 0
	fi
	_shell::git::core::pick -0 --multi --prompt "$prompt" \
		--header "tab: mark  enter: confirm  esc: cancel  ctrl-/: preview" \
		--preview 'f={1}; f=${f#????}; f=${f%%$(printf "\036")*}; GIT_LITERAL_PATHSPECS=1 git --no-pager diff HEAD --color=always --stat -- "$f" 2>/dev/null | head -40' \
		<"$dir/in" >"$dir/sel"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		rm -rf "$dir"
		return "$rc"
	fi
	while IFS= read -r -d '' raw; do
		_SHELL_GIT_ST_RAWS+=("$raw")
	done <"$dir/sel"
	rm -rf "$dir"
	return 0
}

# @internal
# @description Print paths on stdout, newline-separated or NUL-separated.
# @arg $1 string `1` for NUL separators.
# @arg $@ string The paths.
# @stdout The paths.
# @exitcode 0 Always.
# @example
#   _shell::git::core::stage_print 0 "${paths[@]}"
#
_shell::git::core::stage_print() {
	local nul="$1" p
	shift
	for p in "$@"; do
		if [ "$nul" = "1" ]; then printf '%s\0' "$p"; else printf '%s\n' "$p"; fi
	done
	return 0
}

# @internal
# @description Report conflicted entries and tell the user to resolve them first.
# @arg $@ string The conflicted paths.
# @exitcode 6 Always.
# @example
#   _shell::git::core::stage_conflicts "${conflicted[@]}"
#
_shell::git::core::stage_conflicts() {
	local p
	_shell::git::core::err "unresolved conflicts, nothing was changed:"
	for p in "$@"; do
		printf '  %s\n' "$p" >&2
	done
	_shell::git::core::info "resolve them, then run: git add -- <path>"
	return 6
}
