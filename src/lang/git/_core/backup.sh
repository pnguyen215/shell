#!/usr/bin/env bash
# @file lang/git/_core/backup.sh
# @brief Recovery points for history rewrites and discards.
# @description
#   Every rewrite or discard first records what it is about to lose under `refs/shell-backup/<op>/<timestamp>`
#   and prints the command that restores it. Backup refs are plain refs: list them with
#   `git for-each-ref refs/shell-backup`, delete one with `git update-ref -d <ref>`. They are never removed
#   automatically.
#
#   Restore a rewritten branch:    git reset --hard refs/shell-backup/<op>/<timestamp>   (your decision, never run for you)
#   Restore a discarded snapshot:  git restore --source=refs/shell-backup/discard/<timestamp> --worktree -- <paths>

# @internal
# @description Pick a backup ref name that does not exist yet: `refs/shell-backup/<op>/<UTC timestamp>[-N]`.
# @arg $1 string Operation name (`amend`, `fixup`, `squash`, `discard`, ...).
# @stdout The ref name.
# @exitcode 0 Always.
# @example
#   ref="$(_shell::git::core::backup_name amend)"
#
_shell::git::core::backup_name() {
	local base n=1 ref
	base="refs/shell-backup/$1/$(date -u +%Y%m%dT%H%M%SZ)"
	ref="$base"
	while _shell::git::core::git_ro rev-parse --verify --quiet "$ref" >/dev/null 2>&1; do
		n=$((n + 1))
		ref="$base-$n"
	done
	printf '%s\n' "$ref"
}

# @internal
# @description Record a commit under a new backup ref and print how to restore it.
# @arg $1 string Operation name.
# @arg $2 string The commit (or ref) to keep reachable, for example `HEAD`.
# @arg $3 string Optional: restore hint kind, `branch` (default, `git reset --hard <ref>`) or `paths`.
# @stdout The backup ref name.
# @exitcode 0 The backup exists.
# @exitcode 1 It could not be created (the caller must stop: never rewrite without a backup).
# @example
#   backup="$(_shell::git::core::backup_ref amend HEAD)" || return 1
#
_shell::git::core::backup_ref() {
	local ref sha
	sha="$(_shell::git::core::git_ro rev-parse --verify --quiet "$2^{commit}" 2>/dev/null)" || {
		_shell::git::core::err "cannot back up '$2': not a commit"
		return 1
	}
	ref="$(_shell::git::core::backup_name "$1")"
	_shell::git::core::git_rw update-ref -m "shell backup before $1" "$ref" "$sha" || {
		_shell::git::core::err "could not create the backup ref $ref"
		return 1
	}
	_shell::git::core::info "backup: $ref ($sha)"
	if [ "${3-branch}" = "branch" ]; then
		_shell::git::core::info "restore with: git reset --hard $ref"
	fi
	printf '%s\n' "$ref"
}

# @internal
# @description Snapshot the working-tree (and index) state of some paths into a backup ref, WITHOUT touching the
#   real index or working tree. Built with a temporary index, so it also covers untracked files, which
#   `git stash create` does not. The snapshot commit's second parent holds the index version.
# @arg $1 string Operation name (usually `discard`).
# @arg $@ string The paths to snapshot (after `--`), exactly as they will be discarded.
# @stdout The backup ref name.
# @exitcode 0 The snapshot exists.
# @exitcode 1 It could not be created (the caller must not discard).
# @example
#   snap="$(_shell::git::core::backup_snapshot discard -- "a file.txt")" || return 1
#
_shell::git::core::backup_snapshot() {
	local op="$1" idxdir idx wt_tree idx_tree head ref idx_commit wt_commit
	local -a parents=()
	shift
	[ "${1-}" = "--" ] && shift
	idxdir="$(mktemp -d "${TMPDIR:-/tmp}/shell-git-idx.XXXXXX")" || return 1
	idx="$idxdir/index"
	head="$(_shell::git::core::git_ro rev-parse --verify --quiet 'HEAD^{commit}' 2>/dev/null)"
	# The index as it is now.
	idx_tree="$(_shell::git::core::git_ro write-tree 2>/dev/null)" || {
		rm -rf "$idxdir"
		return 1
	}
	# The working tree: HEAD (or empty) overlaid with the current content of the paths, added to a copy of the index.
	if [ -n "$head" ]; then
		GIT_INDEX_FILE="$idx" _shell::git::core::git_rw read-tree "$head" 2>/dev/null || {
			rm -rf "$idxdir"
			return 1
		}
	fi
	if [ "$#" -gt 0 ]; then
		GIT_LITERAL_PATHSPECS=1 GIT_INDEX_FILE="$idx" _shell::git::core::git_rw add -A --force -- "$@" 2>/dev/null || {
			rm -rf "$idxdir"
			return 1
		}
	fi
	wt_tree="$(GIT_INDEX_FILE="$idx" _shell::git::core::git_rw write-tree 2>/dev/null)" || {
		rm -rf "$idxdir"
		return 1
	}
	rm -rf "$idxdir"
	[ -n "$head" ] && parents=(-p "$head")
	idx_commit="$(GIT_AUTHOR_NAME=shell GIT_AUTHOR_EMAIL=shell@localhost GIT_COMMITTER_NAME=shell GIT_COMMITTER_EMAIL=shell@localhost command git commit-tree "$idx_tree" ${parents[@]+"${parents[@]}"} -m "shell backup: index before $op" 2>/dev/null)" || return 1
	wt_commit="$(GIT_AUTHOR_NAME=shell GIT_AUTHOR_EMAIL=shell@localhost GIT_COMMITTER_NAME=shell GIT_COMMITTER_EMAIL=shell@localhost command git commit-tree "$wt_tree" ${parents[@]+"${parents[@]}"} -p "$idx_commit" -m "shell backup: working tree before $op" 2>/dev/null)" || return 1
	ref="$(_shell::git::core::backup_name "$op")"
	_shell::git::core::git_rw update-ref -m "shell backup before $op" "$ref" "$wt_commit" || return 1
	_shell::git::core::info "snapshot: $ref"
	_shell::git::core::info "restore with: git restore --source=$ref --worktree -- <paths>   (index version: $ref^2)"
	printf '%s\n' "$ref"
}
