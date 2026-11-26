#!/usr/bin/env bash
# @file lang/git/flow/sync.sh
# @brief shell::git::flow::sync: bring the base branch into the current working branch.

# @description Integrate the BASE branch into the CURRENT branch, by merge or by rebase. (This is not
#   `shell::git::remote::sync`, which syncs the current branch with its own upstream.) The base comes from
#   `SHELL_GIT_BASE_BRANCH`, then `origin/HEAD`, then `main`/`master`/`develop`, or `--base <ref>`. A
#   divergence preview (commits ahead/behind the base) is printed on stderr, then the integration is
#   confirmed (`-y` to answer yes). The method is `--merge` or `--rebase`; on a terminal it is asked,
#   otherwise one of them is required (exit 2). Another operation in progress blocks it (exit 7); a dirty
#   tree blocks it (exit 7) unless `--autostash` (git's own autostash). A rebase first creates a backup ref
#   `refs/shell-backup/sync/<timestamp>` and prints its restore command, and warns that a pushed branch
#   will then need `--force-with-lease`. Nothing is ever reset automatically. Conflicts exit 6 with the
#   exact `--continue`/`--abort` commands. `--fetch` fetches first (never prompts for credentials).
# @option -n | --dry-run Print the exact commands and execute nothing.
# @option -y | --yes Confirm without asking (required without a terminal).
# @option --merge Integrate with `git merge`.
# @option --rebase Integrate with `git rebase`.
# @option --autostash Stash a dirty tree around the integration.
# @option --fetch Fetch before integrating.
# @option --base <ref> Integrate this ref instead of the resolved base branch.
# @option -h | --help Show this help message.
# @stdout The hash of the new HEAD.
# @exitcode 0 Success, or already up to date (or dry run).
# @exitcode 1 Failure (detached HEAD, no base branch, fetch failed).
# @exitcode 2 Usage error, method missing without a terminal, or confirmation needed without a terminal.
# @exitcode 3 Not a git repository.
# @exitcode 5 Declined or cancelled; nothing changed.
# @exitcode 6 Conflicts: resolve them and continue or abort.
# @exitcode 7 Blocked by a dirty tree or an operation in progress.
# @example
#   shell::git::flow::sync --merge
#   shell::git::flow::sync -y --rebase --autostash
#   shell::git::flow::sync -n --merge
#
shell::git::flow::sync() {
	local dry=0 yes="" method="" autostash=0 fetch=0 base_opt="" base cur sha ahead behind ans="" backup rc up
	local -a extra=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf 'Usage: shell::git::flow::sync [-n] [-y] [--merge|--rebase] [--autostash] [--fetch] [--base <ref>]\n'
			printf 'Integrate the base branch into the current branch (divergence preview, confirmation).\n'
			return 0
			;;
		-n | --dry-run) dry=1 ;;
		-y | --yes) yes="yes" ;;
		--merge) method="merge" ;;
		--rebase) method="rebase" ;;
		--autostash) autostash=1 ;;
		--fetch) fetch=1 ;;
		--base)
			if [ $# -lt 2 ]; then
				_shell::git::core::err "--base needs a ref"
				return 2
			fi
			base_opt="$2"
			shift
			;;
		*)
			_shell::git::core::err "unknown argument: $1"
			return 2
			;;
		esac
		shift
	done
	_shell::git::core::env
	_shell::git::core::require_repo --worktree || return $?
	cur="$(_shell::git::core::head_branch)" || {
		_shell::git::core::err "HEAD is detached: switch to a branch first"
		return 1
	}
	if [ "$fetch" = "1" ] && [ "$dry" = "0" ]; then
		_shell::git::core::git_rw fetch --quiet >&2 || {
			_shell::git::core::err "fetch failed (network or credentials)"
			return 1
		}
	fi
	if [ -n "$base_opt" ]; then
		base="$base_opt"
	else
		base="$(_shell::git::core::base)" || {
			_shell::git::core::err "cannot determine the base branch (set SHELL_GIT_BASE_BRANCH or pass --base)"
			return 1
		}
	fi
	sha="$(_shell::git::core::rev "$base")" || {
		_shell::git::core::err "the base does not exist: $base"
		return 1
	}
	if [ "$sha" = "$(_shell::git::core::git_ro rev-parse HEAD 2>/dev/null)" ]; then
		_shell::git::core::info "$cur is already at $base"
		return 0
	fi
	read -r ahead behind <<LZ_EOF
$(_shell::git::core::ahead_behind HEAD "$sha")
LZ_EOF
	_shell::git::core::info "$cur is $ahead commit(s) ahead of and $behind commit(s) behind $base"
	if [ "${behind:-0}" -eq 0 ]; then
		_shell::git::core::info "nothing to integrate: $base is already part of $cur"
		return 0
	fi

	if [ -z "$method" ]; then
		if [ "$dry" = "1" ] || ! _shell::git::core::interactive; then
			_shell::git::core::err "choose the method: --merge or --rebase"
			return 2
		fi
		printf 'Integrate %s into %s by [m]erge or [r]ebase? ' "$base" "$cur" >&2
		_shell::git::core::readline ans || return 5
		case "$ans" in
		m | M | merge) method="merge" ;;
		r | R | rebase) method="rebase" ;;
		*) return 5 ;;
		esac
	fi
	[ "$autostash" = "1" ] && extra=(--autostash)

	if [ "$dry" = "1" ]; then
		[ "$fetch" = "1" ] && _shell::git::core::dry git fetch --quiet
		if [ "$method" = "rebase" ]; then
			_shell::git::core::dry git update-ref -m "shell backup before sync" "$(_shell::git::core::backup_name sync)" "$(_shell::git::core::git_ro rev-parse HEAD)"
			_shell::git::core::dry git rebase ${extra[@]+"${extra[@]}"} "$base"
		else
			_shell::git::core::dry git merge --no-edit ${extra[@]+"${extra[@]}"} "$base"
		fi
		return 0
	fi

	_shell::git::core::commit_idle "sync" || return $?
	if [ "$autostash" != "1" ]; then
		_shell::git::core::require_clean "" || return $?
	fi
	if [ "$method" = "rebase" ]; then
		up="$(_shell::git::core::upstream)" && _shell::git::core::warn "$cur tracks $up: after a rebase you will need git push --force-with-lease"
	fi
	_shell::git::core::confirm "Integrate $base ($behind new commit(s)) into $cur by $method?" "$yes" || return $?

	if [ "$method" = "rebase" ]; then
		backup="$(_shell::git::core::backup_ref sync HEAD)" || return 1
		_shell::git::core::git_rw rebase ${extra[@]+"${extra[@]}"} "$base" >&2
	else
		_shell::git::core::git_rw merge --no-edit ${extra[@]+"${extra[@]}"} "$base" >&2
	fi
	rc=$?
	if [ "$rc" -ne 0 ]; then
		[ -n "${backup-}" ] && _shell::git::core::info "backup: $backup"
		_shell::git::core::commit_failed sync
		return $?
	fi
	_shell::git::core::git_ro rev-parse HEAD
}
