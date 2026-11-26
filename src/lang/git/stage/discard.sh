#!/usr/bin/env bash
# @file lang/git/stage/discard.sh
# @brief Discard changes of picked files, after a recoverable snapshot.

# @description Throw away local changes of files: tracked files go back to HEAD (index and working tree), files
#   added to the index are removed, untracked files are deleted. With paths: exactly those; without: pick.
#
#   Safety: the exact list is shown, `git clean -n` previews the untracked files, and a confirmation is
#   required (`--yes` is the only non-interactive way). Only AFTER the confirmation a snapshot of the
#   working tree and index of those paths is stored under `refs/shell-backup/discard/<timestamp>` (also
#   covering untracked files), and the command that restores it is printed. If the snapshot fails nothing is
#   discarded. `git clean` only ever receives the listed files, `reset --hard` is never used. Submodules are
#   skipped (discard them by hand). Conflicted files stop the command with exit 6.
# @option -n | --dry-run Print the exact commands, take no snapshot, run nothing.
# @option -y | --yes Do not ask for confirmation (required without a terminal).
# @option --unstaged-only Restore only the working tree from the index: staged changes and untracked files stay.
# @option -z Print the discarded paths NUL-separated.
# @option -h | --help Show this help.
# @arg $@ string Optional paths.
# @stdout The discarded paths, one per line.
# @exitcode 0 Discarded (or nothing to discard).
# @exitcode 1 The snapshot or a git command failed.
# @exitcode 2 Invalid usage, no paths and no terminal, or confirmation needed without a terminal.
# @exitcode 3 Not a git repository with a working tree.
# @exitcode 5 Declined or cancelled: nothing changed.
# @exitcode 6 A selected file has unresolved conflicts.
# @example
#   shell::git::stage::discard
#   shell::git::stage::discard -n -- notes.md
#   shell::git::stage::discard --yes -- scratch.txt
#
shell::git::stage::discard() {
	local dry=0 nul=0 yes="" uonly=0 rc raw snap total
	local -a paths=() conflicted=() rmlist=() restore=() uns=() clean=() all=() shown=() skipped=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf 'usage: shell::git::stage::discard [-n|--dry-run] [-y|--yes] [--unstaged-only] [-z] [--] [path...]\n'
			printf 'Discard changes of files after a recoverable snapshot (refs/shell-backup/discard/...).\n'
			return 0
			;;
		-n | --dry-run) dry=1 ;;
		-y | --yes) yes="yes" ;;
		--unstaged-only) uonly=1 ;;
		-z) nul=1 ;;
		--)
			shift
			while [ $# -gt 0 ]; do
				paths+=("$1")
				shift
			done
			break
			;;
		-*)
			_shell::git::core::err "unknown option: $1"
			return 2
			;;
		*) paths+=("$1") ;;
		esac
		shift
	done
	_shell::git::core::env
	_shell::git::core::require_repo --worktree || return $?
	_shell::git::core::stage_select discard "discard" -- ${paths[@]+"${paths[@]}"}
	rc=$?
	[ "$rc" -eq 0 ] || return "$rc"

	for raw in ${_SHELL_GIT_ST_RAWS[@]+"${_SHELL_GIT_ST_RAWS[@]}"}; do
		_shell::git::core::stage_parse "$raw"
		case "$_SHELL_GIT_ST_CLASS" in
		c) conflicted+=("$_SHELL_GIT_ST_FILE") ;;
		s) skipped+=("$_SHELL_GIT_ST_FILE") ;;
		u)
			if [ "$uonly" = "0" ]; then
				clean+=("$_SHELL_GIT_ST_FILE")
				all+=("$_SHELL_GIT_ST_FILE")
				shown+=("$_SHELL_GIT_ST_FILE")
			fi
			;;
		*)
			if [ "$uonly" = "1" ]; then
				if [ "$_SHELL_GIT_ST_Y" != "." ]; then
					uns+=("$_SHELL_GIT_ST_FILE")
					all+=("$_SHELL_GIT_ST_FILE")
					shown+=("$_SHELL_GIT_ST_FILE")
				fi
			else
				all+=("$_SHELL_GIT_ST_FILE")
				shown+=("$_SHELL_GIT_ST_FILE")
				case "$_SHELL_GIT_ST_CLASS$_SHELL_GIT_ST_X" in
				rR | rC)
					# The new path is not in HEAD; the original path comes back from HEAD.
					rmlist+=("$_SHELL_GIT_ST_FILE")
					restore+=("$_SHELL_GIT_ST_ORIG")
					all+=("$_SHELL_GIT_ST_ORIG")
					;;
				*A | *C) rmlist+=("$_SHELL_GIT_ST_FILE") ;;
				*) restore+=("$_SHELL_GIT_ST_FILE") ;;
				esac
			fi
			;;
		esac
	done
	if [ "${#conflicted[@]}" -gt 0 ]; then
		_shell::git::core::stage_conflicts "${conflicted[@]}"
		return 6
	fi
	for raw in ${skipped[@]+"${skipped[@]}"}; do
		_shell::git::core::warn "skipping submodule $raw (discard it by hand: git submodule update -- $raw)"
	done
	total="${#shown[@]}"
	if [ "$total" -eq 0 ]; then
		_shell::git::core::info "nothing to discard"
		return 0
	fi

	if [ "$dry" = "1" ]; then
		[ "${#uns[@]}" -gt 0 ] && _shell::git::core::stage_dry restore --worktree -- "${uns[@]}"
		if [ "${#rmlist[@]}" -gt 0 ]; then _shell::git::core::stage_dry rm -f -q -- "${rmlist[@]}"; fi
		if [ "${#restore[@]}" -gt 0 ]; then
			if _shell::git::core::git_ge 2 23; then
				_shell::git::core::stage_dry restore --staged --worktree --source=HEAD -- "${restore[@]}"
			else
				_shell::git::core::stage_dry checkout HEAD -- "${restore[@]}"
			fi
		fi
		[ "${#clean[@]}" -gt 0 ] && _shell::git::core::stage_dry clean -f -q -- "${clean[@]}"
		return 0
	fi

	_shell::git::core::warn "about to discard $total file(s):"
	for raw in "${shown[@]}"; do
		printf '  %s\n' "$raw" >&2
	done
	if [ "${#clean[@]}" -gt 0 ]; then
		_shell::git::core::info "untracked files that would be removed (git clean -n):"
		_shell::git::core::stage_git_ro clean -n -- "${clean[@]}" >&2
	fi
	_shell::git::core::confirm "Discard $total file(s) for good (a snapshot is kept)?" "$yes" || return $?

	snap="$(cd "$_SHELL_GIT_ST_TOP" && GIT_LITERAL_PATHSPECS=1 _shell::git::core::backup_snapshot discard -- "${all[@]}")" || {
		_shell::git::core::err "could not take the safety snapshot: nothing was discarded"
		return 1
	}

	if [ "${#uns[@]}" -gt 0 ]; then
		_shell::git::core::stage_git restore --worktree -- "${uns[@]}" || return 1
	fi
	if [ "${#rmlist[@]}" -gt 0 ]; then
		_shell::git::core::stage_git rm -f -q -- "${rmlist[@]}" || return 1
	fi
	if [ "${#restore[@]}" -gt 0 ]; then
		if _shell::git::core::git_ge 2 23; then
			_shell::git::core::stage_git restore --staged --worktree --source=HEAD -- "${restore[@]}" || return 1
		else
			_shell::git::core::stage_git checkout HEAD -- "${restore[@]}" || return 1
		fi
	fi
	if [ "${#clean[@]}" -gt 0 ]; then
		_shell::git::core::stage_git clean -f -q -- "${clean[@]}" || return 1
	fi
	_shell::git::core::info "recover with: $(if [ -n "$_SHELL_GIT_ST_PFX" ]; then _shell::git::core::quote git -C "$_SHELL_GIT_ST_TOP" restore --source="$snap" --worktree -- "${all[@]}"; else _shell::git::core::quote git restore --source="$snap" --worktree -- "${all[@]}"; fi)"
	_shell::git::core::stage_print "$nul" "${shown[@]}"
	return 0
}
