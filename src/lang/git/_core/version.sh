#!/usr/bin/env bash
# @file lang/git/_core/version.sh
# @brief Version gates for git and fzf.
# @description
#   Minimum versions (documented in the README): git 2.11 (`status --porcelain=v2`); newer
#   options are gated one by one: `switch`/`restore` 2.23, `--end-of-options` 2.24,
#   `--force-if-includes` 2.30. fzf 0.19 for `--read0`/`--print0`; older or missing fzf
#   falls back to a numbered prompt.

# @internal
# @description Turn "2.48.1" or "git version 2.48.1.windows.1" into a comparable integer (major*10000 + minor*100 + patch).
# @arg $1 string A version string.
# @stdout The integer, 0 when nothing could be parsed.
# @exitcode 0 Always.
# @example
#   _shell::git::core::version_num "git version 2.48.1"   # 24801
#
_shell::git::core::version_num() {
	local v="${1-}" major minor patch
	v="${v#git version }"
	v="${v#fzf }"
	v="${v%% *}"
	major="${v%%.*}"
	v="${v#*.}"
	minor="${v%%.*}"
	case "$v" in *.*) patch="${v#*.}" ;; *) patch=0 ;; esac
	patch="${patch%%.*}"
	case "$major$minor$patch" in
	*[!0-9]* | "")
		printf '0\n'
		return 0
		;;
	esac
	printf '%d\n' $((10#$major * 10000 + 10#$minor * 100 + 10#$patch))
}

# @internal
# @description Tell whether the installed git is at least a version. The version is read once and cached in `_SHELL_GIT_VER_GIT`.
# @arg $1 integer Major.
# @arg $2 integer Minor.
# @arg $3 integer Optional patch (default 0).
# @exitcode 0 git is new enough.
# @exitcode 1 git is older or missing.
# @example
#   _shell::git::core::git_ge 2 23 && echo "switch is available"
#
_shell::git::core::git_ge() {
	if [ -z "${_SHELL_GIT_VER_GIT-}" ]; then
		_SHELL_GIT_VER_GIT="$(_shell::git::core::version_num "$(command git --version 2>/dev/null)")"
	fi
	[ "$_SHELL_GIT_VER_GIT" -ge $((10#${1:-0} * 10000 + 10#${2:-0} * 100 + 10#${3:-0})) ]
}

# @internal
# @description Tell whether fzf is installed and at least a version. Cached in `_SHELL_GIT_VER_FZF`.
# @arg $1 integer Major.
# @arg $2 integer Minor.
# @exitcode 0 fzf is new enough.
# @exitcode 1 fzf is older or missing.
# @example
#   _shell::git::core::fzf_ge 0 38 && echo "become() is available"
#
_shell::git::core::fzf_ge() {
	if [ -z "${_SHELL_GIT_VER_FZF-}" ]; then
		if command -v fzf >/dev/null 2>&1; then
			_SHELL_GIT_VER_FZF="$(_shell::git::core::version_num "$(fzf --version 2>/dev/null)")"
		else
			_SHELL_GIT_VER_FZF=0
		fi
	fi
	[ "$_SHELL_GIT_VER_FZF" -ge $((10#${1:-0} * 10000 + 10#${2:-0} * 100)) ]
}

# @internal
# @description Tell whether the interactive picker can use fzf (installed and >= 0.19, the first with --read0/--print0).
# @exitcode 0 fzf can be used.
# @exitcode 1 Use the numbered prompt instead.
# @example
#   _shell::git::core::fzf_ok || echo "falling back to a numbered prompt"
#
_shell::git::core::fzf_ok() {
	_shell::git::core::fzf_ge 0 19
}
