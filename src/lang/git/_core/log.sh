#!/usr/bin/env bash
# @file lang/git/_core/log.sh
# @brief Private helpers shared by the shell::git::log::* functions.
# @description
#   Owned by the log group. Functions here are named `_shell::git::core::log_<name>`, are marked
#   `# @internal`, and are used by the actions of the group (one public function per action file,
#   so shared code lives here).
#
#   Key bindings of `log::pick` (fzf >= 0.38; older fzf keeps enter and the preview only):
#     enter    details of the commit (`show --stat`, on stderr), the hash goes to stdout
#     alt-d    full diff of the focused commit        alt-f   changed files (name-status)
#     alt-i    full information (fuller format)       alt-m   load more history (no path filter)
#     alt-p    cherry-pick the focused commit (confirmation, conflicts exit 6)
#     alt-r    revert the focused commit (confirmation, conflicts exit 6)
#     ?        help overlay        ctrl-/   toggle the preview        esc / ctrl-c   abort, nothing changes
#   Not used for features: ctrl-c (aborts fzf), ctrl-s (terminal flow control), ctrl-d (quits fzf on an empty
#   query). The older library pickers use ctrl-y/o/f/b/d/u; no alt-* or `?` binding exists anywhere else.

# @internal
# @description Tell whether a string is a positive integer.
# @arg $1 string The value.
# @exitcode 0 It is.
# @exitcode 1 It is not.
# @example
#   _shell::git::core::log_number "$max" || return 2
#
_shell::git::core::log_number() {
	case "${1-}" in
	"" | *[!0-9]* | 0 | 0[0-9]*) return 1 ;;
	esac
	return 0
}

# @internal
# @description Choose the color mode for git: `always` when stdout (or the picker, with `ui`) can show colors and NO_COLOR is empty.
# @arg $1 string `out` (default) tests stdout for a terminal; `ui` only honors NO_COLOR (fzf draws on the terminal itself).
# @stdout `always` or `never`.
# @exitcode 0 Always.
# @example
#   color="$(_shell::git::core::log_color out)"
#
_shell::git::core::log_color() {
	if [ -n "${NO_COLOR-}" ]; then
		printf 'never\n'
	elif [ "${1:-out}" = "ui" ] || { [ -t 1 ] && [ "${TERM-}" != "dumb" ]; }; then
		printf 'always\n'
	else
		printf 'never\n'
	fi
}

# @internal
# @description Say how to finish or abandon an operation that stopped on conflicts, and pick the exit code.
# @arg $1 string The operation: `cherry-pick` or `revert`.
# @exitcode 6 Conflicts (or the operation is in progress): resolve them by hand.
# @exitcode 1 The operation failed without leaving anything in progress.
# @example
#   _shell::git::core::git_rw cherry-pick "$sha" || _shell::git::core::log_conflict cherry-pick
#
_shell::git::core::log_conflict() {
	if _shell::git::core::operation >/dev/null 2>&1; then
		_shell::git::core::err "$1 stopped: resolve the conflicts by hand"
		_shell::git::core::info "then run: git $1 --continue    or give up with: git $1 --abort"
		return 6
	fi
	return 1
}

# @internal
# @description Cherry-pick or revert one commit after validation and a confirmation. Merge commits are refused
#   (a mainline cannot be guessed): use `shell::git::commit::revert` for them.
# @arg $1 string `cherry-pick` or `revert`.
# @arg $2 string The commit (hash or revision).
# @arg $3 string `yes` when the caller was given `--yes`.
# @arg $4 integer `1` for a dry run: print the command, change nothing.
# @stdout The new HEAD hash on success; the command on a dry run.
# @exitcode 0 Done (or dry run).
# @exitcode 1 Failure.
# @exitcode 2 Invalid commit, or not confirmable without a terminal.
# @exitcode 5 Declined.
# @exitcode 6 Conflicts: resolve by hand.
# @exitcode 7 Dirty tree or another operation in progress.
# @example
#   _shell::git::core::log_apply cherry-pick "$hash" "$yes" 0
#
_shell::git::core::log_apply() {
	local op="$1" sha line rc
	sha="$(_shell::git::core::rev "$2")" || {
		_shell::git::core::err "not a commit: $2"
		return 2
	}
	line="$(_shell::git::core::git_ro rev-list --parents -n 1 "$sha" 2>/dev/null)"
	case "$line" in
	*" "*" "*)
		_shell::git::core::err "$sha is a merge commit: use shell::git::commit::revert (it asks for the mainline)"
		return 2
		;;
	esac
	if [ "${4-0}" = "1" ]; then
		_shell::git::core::dry git "$op" "$sha"
		return 0
	fi
	_shell::git::core::require_idle "$op" || return $?
	_shell::git::core::require_clean "" || return $?
	_shell::git::core::confirm "$op $(_shell::git::core::git_ro log -1 --format='%h %s' "$sha" 2>/dev/null)?" "${3-}" || return $?
	_shell::git::core::git_rw "$op" "$sha" >&2
	rc=$?
	if [ "$rc" -ne 0 ]; then
		_shell::git::core::log_conflict "$op"
		return $?
	fi
	_shell::git::core::git_ro rev-parse HEAD
}

# @internal
# @description Run the commit picker of `log::pick`: fzf (streaming, hidden hash column, preview, key bindings)
#   or, without a usable fzf, a numbered list of the most recent commits.
# @arg $1 integer Maximum number of commits to stream.
# @arg $2 integer `1` to allow several selections.
# @arg $3 integer `1` for all refs.
# @arg $4 string `yes` when `--yes` was given (for alt-p / alt-r).
# @arg $5 integer `1` for a dry run of alt-p / alt-r.
# @arg $6 string Optional revision (a validated commit hash), empty for HEAD.
# @arg $@ string After a literal `--`: path filters.
# @stdout The selected hashes, one per line.
# @exitcode 0 Selected (or the cherry-pick/revert succeeded).
# @exitcode 2 No terminal to pick on.
# @exitcode 5 Cancelled.
# @example
#   _shell::git::core::log_picker 2000 0 0 "" "" "" -- src/
#
_shell::git::core::log_picker() {
	local max="$1" multi="$2" all="$3" yes="$4" dry="$5" rev="$6" color fmt ext=0 key="" hashes="" out rc line first=1 n=0 first_hash=""
	local -a cmd=() fargs=()
	shift 6
	[ "${1-}" = "--" ] && shift
	fmt='%H%x1f%C(yellow)%h%C(reset) %C(dim)%ad%C(reset) %C(cyan)%an%C(reset) %s%C(auto)%d'
	color="$(_shell::git::core::log_color ui)"
	cmd=(log --color="$color" --date=short "--format=$fmt" "--max-count=$max")
	[ "$all" = "1" ] && cmd+=(--all)
	[ -n "$rev" ] && cmd+=("$rev")
	[ "$#" -gt 0 ] && cmd+=(-- "$@")

	if [ -z "${SHELL_GIT_INPUT-}" ] && { [ ! -t 2 ] || [ ! -r /dev/tty ]; } && [ -z "${SHELL_GIT_FORCE_FZF-}" ]; then
		_shell::git::core::err "no terminal to pick from: pass the value as an argument"
		return 2
	fi
	_shell::git::core::env

	if { [ -z "${SHELL_GIT_INPUT-}" ] || [ -n "${SHELL_GIT_FORCE_FZF-}" ]; } && _shell::git::core::fzf_ok; then
		_shell::git::core::fzf_ge 0 38 && ext=1
		fargs=(--ansi --delimiter=$'\037' --with-nth=2.. --layout=reverse --info=inline --prompt 'log> ' --bind 'ctrl-/:toggle-preview' --bind 'esc:abort')
		fargs+=(--preview 'git --no-pager show --stat --color=always --format=fuller {1} 2>/dev/null | head -n 60' --preview-window 'right:60%:wrap')
		[ "$multi" = "1" ] && fargs+=(--multi --bind 'tab:toggle+down' --bind 'shift-tab:toggle+up')
		if [ "$ext" = "1" ]; then
			fargs+=(--header 'enter details | alt-d diff | alt-f files | alt-i info | alt-p cherry-pick | alt-r revert | ? help')
			fargs+=(--expect 'alt-p,alt-r')
			fargs+=(--bind 'alt-d:execute(git --no-pager show --color=always {1} | less -R)')
			fargs+=(--bind 'alt-f:execute(git --no-pager show --color=always --name-status --format=fuller {1} | less -R)')
			fargs+=(--bind 'alt-i:execute(git --no-pager show --color=always --stat --summary --format=fuller {1} | less -R)')
			fargs+=(--bind '?:preview(printf "%s\n" "enter details   alt-d diff   alt-f changed files   alt-i full info" "alt-p cherry-pick   alt-r revert   alt-m load more history" "ctrl-/ toggle preview   esc abort (nothing changes)")')
			if [ "$#" -eq 0 ]; then
				fargs+=(--bind 'alt-m:reload(git --no-pager log --color=always --date=short "--format=$SHELL_GIT_LOG_FMT" --max-count=100000 $SHELL_GIT_LOG_REV)')
			fi
		else
			_shell::git::core::info "fzf is older than 0.38: only enter and the preview are available"
			fargs+=(--header 'enter selects')
		fi
		_shell::git::core::split "$SHELL_GIT_FZF_OPTS"
		for line in "${_SHELL_GIT_WORDS[@]}"; do
			fargs+=("$line")
		done
		out="$(GIT_OPTIONAL_LOCKS=0 SHELL_GIT_LOG_FMT="$fmt" SHELL_GIT_LOG_REV="${rev:---all}" command git --no-pager "${cmd[@]}" | fzf "${fargs[@]}")"
		rc=$?
		if [ "$rc" -ne 0 ] || [ -z "$out" ]; then
			return 5
		fi
		while IFS= read -r line; do
			# With --expect fzf prints the key (empty for enter) before the records; a record always
			# contains the unit separator, a key never does.
			if [ "$first" = "1" ] && [ "$ext" = "1" ]; then
				first=0
				case "$line" in
				*$'\037'*) ;;
				*)
					key="$line"
					continue
					;;
				esac
			fi
			first=0
			[ -n "$line" ] || continue
			line="${line%%$'\037'*}"
			n=$((n + 1))
			[ -n "$first_hash" ] || first_hash="$line"
			hashes="$hashes$line"$'\n'
		done <<LZ_EOF
$out
LZ_EOF
		[ "$n" -gt 0 ] || return 5
		case "$key" in
		alt-p)
			_shell::git::core::log_apply cherry-pick "$first_hash" "$yes" "$dry"
			return $?
			;;
		alt-r)
			_shell::git::core::log_apply revert "$first_hash" "$yes" "$dry"
			return $?
			;;
		esac
		printf '%s' "$hashes"
		if [ "$multi" != "1" ] && [ "${SHELL_GIT_QUIET-}" != "1" ]; then
			_shell::git::core::git_ro show --stat --color=never --format=fuller "$first_hash" >&2 2>/dev/null
		fi
		return 0
	fi

	# Numbered fallback: a bounded list of the most recent commits.
	max="${SHELL_GIT_LOG_FALLBACK:-30}"
	_shell::git::core::log_number "$max" || max=30
	cmd=(log --color=never --date=short "--format=$fmt" "--max-count=$max")
	[ "$all" = "1" ] && cmd+=(--all)
	[ -n "$rev" ] && cmd+=("$rev")
	[ "$#" -gt 0 ] && cmd+=(-- "$@")
	if [ "$multi" = "1" ]; then
		GIT_OPTIONAL_LOCKS=0 command git --no-pager "${cmd[@]}" | _shell::git::core::pick --multi --prompt commit
	else
		GIT_OPTIONAL_LOCKS=0 command git --no-pager "${cmd[@]}" | _shell::git::core::pick --prompt commit
	fi
}
