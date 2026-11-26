#!/usr/bin/env bash
# @file lang/git/_core/remote.sh
# @brief Private helpers shared by the shell::git::remote::* functions.
# @description
#   Owned by the remote group. Functions here are named `_shell::git::core::remote_<name>`, are marked
#   `# @internal`, and are used by the actions of the group.
#
#   Network safety: every command that talks to a remote runs with `GIT_TERMINAL_PROMPT=0` and, for ssh,
#   `-o BatchMode=yes`, so a missing credential fails at once instead of waiting for input. Messages shown
#   to the user have `https://user:token@host` credentials replaced by `***`.

# @internal
# @description Run a git command that may talk to a remote: no credential prompt, ssh in batch mode, no pager.
# @arg $@ string Arguments of git.
# @exitcode * Git's own.
# @example
#   _shell::git::core::remote_git fetch -- origin
#
_shell::git::core::remote_git() {
	GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -o BatchMode=yes" GIT_TERMINAL_PROMPT=0 command git --no-pager "$@"
}

# @internal
# @description Replace credentials in URLs found in text read from stdin (`scheme://user:token@host` becomes `scheme://***@host`).
# @stdout The text with credentials masked.
# @exitcode 0 Always.
# @example
#   printf '%s\n' "$message" | _shell::git::core::remote_mask_text
#
_shell::git::core::remote_mask_text() {
	sed -e 's#\([A-Za-z][A-Za-z0-9+.-]*\)://[^/@[:space:]]*@#\1://***@#g'
}

# @internal
# @description Print a one-line, actionable hint for a failed network command, from its error text.
# @arg $1 string The error text git printed.
# @stdout The hint (nothing when the error is not recognised).
# @exitcode 0 Always.
# @example
#   _shell::git::core::remote_hint "$message"
#
_shell::git::core::remote_hint() {
	case "$1" in
	*"Authentication failed"* | *"could not read Username"* | *"Permission denied"* | *"terminal prompts disabled"*)
		printf 'hint: authentication failed or needs a prompt: check your credentials, token or ssh key (nothing is asked here)\n'
		;;
	*"Could not resolve host"* | *"Connection refused"* | *"timed out"* | *"unable to access"* | *"Network is unreachable"*)
		printf 'hint: the remote is not reachable: check your network, VPN and the remote URL (git remote -v)\n'
		;;
	*"does not appear to be a git repository"* | *"Could not read from remote repository"* | *"not found"*)
		printf 'hint: the remote repository was not found or is not readable: check the URL (git remote -v) and your access\n'
		;;
	esac
}

# @internal
# @description Print the names of the configured remotes, one per line.
# @stdout The remote names.
# @exitcode 0 Always.
# @example
#   _shell::git::core::remote_names
#
_shell::git::core::remote_names() {
	_shell::git::core::git_ro remote 2>/dev/null
	return 0
}

# @internal
# @description Tell whether a name is a configured remote.
# @arg $1 string The name.
# @exitcode 0 It is.
# @exitcode 1 It is not (or starts with a dash).
# @example
#   _shell::git::core::remote_exists "$name" || return 2
#
_shell::git::core::remote_exists() {
	local n
	case "${1-}" in
	"" | -*) return 1 ;;
	esac
	while IFS= read -r n; do
		[ "$n" = "$1" ] && return 0
	done <<LZ_EOF
$(_shell::git::core::remote_names)
LZ_EOF
	return 1
}

# @internal
# @description Choose remotes: the explicit names, or the only remote, or an interactive pick when there are several.
# @arg $1 integer `1` to allow several (a multi-select), `0` for exactly one.
# @arg $@ string Optional explicit remote names.
# @stdout The chosen remote names, one per line.
# @exitcode 0 Chosen.
# @exitcode 1 The repository has no remote.
# @exitcode 2 Unknown remote, or several remotes and nothing to ask on.
# @exitcode 5 Cancelled.
# @example
#   remotes="$(_shell::git::core::remote_choose 0 "$@")" || return $?
#
_shell::git::core::remote_choose() {
	local multi="$1" names="" n count=0 only="" line name url rc
	shift
	if [ "$#" -gt 0 ]; then
		for n in "$@"; do
			_shell::git::core::remote_exists "$n" || {
				_shell::git::core::err "unknown remote: $n"
				return 2
			}
			printf '%s\n' "$n"
		done
		return 0
	fi
	while IFS= read -r n; do
		[ -n "$n" ] || continue
		count=$((count + 1))
		only="$n"
	done <<LZ_EOF
$(_shell::git::core::remote_names)
LZ_EOF
	if [ "$count" -eq 0 ]; then
		_shell::git::core::err "this repository has no remote"
		return 1
	fi
	if [ "$count" -eq 1 ]; then
		printf '%s\n' "$only"
		return 0
	fi
	# Several remotes: ask (names with their masked URLs, from one `git remote -v` call).
	while IFS= read -r line; do
		case "$line" in
		*"(fetch)")
			name="${line%%$'\t'*}"
			url="${line#*$'\t'}"
			url="${url% (fetch)}"
			_shell::git::core::rec "$name" "$name  $(_shell::git::core::mask_url "$url")"
			;;
		esac
	done <<LZ_EOF | if [ "$multi" = "1" ]
$(_shell::git::core::git_ro remote -v 2>/dev/null)
LZ_EOF
	then _shell::git::core::pick --multi --prompt remote; else _shell::git::core::pick --prompt remote; fi
	rc=$?
	return "$rc"
}
