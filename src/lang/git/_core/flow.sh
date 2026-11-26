#!/usr/bin/env bash
# @file lang/git/_core/flow.sh
# @brief Private helpers shared by the shell::git::flow::* functions.
# @description
#   Owned by the flow group. Functions here are named `_shell::git::core::flow_<name>`, are marked
#   `# @internal`. Settings: SHELL_GIT_BASE_BRANCH, SHELL_GIT_FEATURE_PREFIX, SHELL_GIT_RELEASE_PREFIX,
#   SHELL_GIT_HOTFIX_PREFIX and SHELL_GIT_RELEASE_BASE (the branch releases start from; default: the base).

# @internal
# @description Start a flow branch (`feature`, `release` or `hotfix`): validate the name, resolve the start
#   point, check preconditions (no operation in progress, clean tree or `--autostash`, optional `--fetch`),
#   create the branch with `git switch --create --no-track` (`checkout -b` on git older than 2.23) and switch to it.
# @arg $1 string Kind: `feature`, `release` or `hotfix` (used in messages).
# @arg $2 string Branch prefix (for example `feature/`).
# @arg $3 string Start point override from the configuration (empty: the resolved base branch).
# @arg $@ string The caller's arguments: `[-n] [--autostash] [--fetch] [--base <ref>] [--] [<name>]`.
# @stdout The new branch name.
# @exitcode 0 Created and checked out (or dry run).
# @exitcode 1 Failure (branch exists, no base branch, fetch failed).
# @exitcode 2 Usage error or invalid name.
# @exitcode 3 Not a git repository.
# @exitcode 7 Blocked by a dirty tree or an operation in progress.
# @example
#   _shell::git::core::flow_start feature "$SHELL_GIT_FEATURE_PREFIX" "" "$@"
#
_shell::git::core::flow_start() {
	local kind="$1" prefix="$2" over="$3" dry=0 autostash="" fetch=0 base_opt="" name="" has_name=0 branch start sha
	shift 3
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			printf 'Usage: shell::git::flow::%s [-n] [--autostash] [--fetch] [--base <ref>] [<name>]\n' "$kind"
			printf 'Create %s<name> from the base branch and switch to it.\n' "$prefix"
			return 0
			;;
		-n | --dry-run) dry=1 ;;
		--autostash) autostash="autostash" ;;
		--fetch) fetch=1 ;;
		--base)
			if [ $# -lt 2 ]; then
				_shell::git::core::err "--base needs a ref"
				return 2
			fi
			base_opt="$2"
			shift
			;;
		--)
			shift
			if [ $# -gt 0 ]; then
				name="$1"
				has_name=1
			fi
			break
			;;
		-*)
			_shell::git::core::err "unknown option: $1"
			return 2
			;;
		*)
			name="$1"
			has_name=1
			;;
		esac
		shift
	done
	_shell::git::core::env
	_shell::git::core::require_repo --worktree || return $?

	if [ "$has_name" = "0" ]; then
		if ! _shell::git::core::interactive; then
			_shell::git::core::err "a $kind name is required (nothing to ask without a terminal)"
			return 2
		fi
		printf 'Name of the %s branch: ' "$kind" >&2
		_shell::git::core::readline name || return 5
		[ -n "$name" ] || return 5
	fi
	case "$name" in
	"$prefix"*) branch="$name" ;;
	*) branch="$prefix$name" ;;
	esac
	if [ -z "$name" ] || ! _shell::git::core::valid_branch "$branch"; then
		_shell::git::core::err "invalid branch name: $branch"
		return 2
	fi

	if [ "$fetch" = "1" ] && [ "$dry" = "0" ]; then
		_shell::git::core::git_rw fetch --quiet >&2 || {
			_shell::git::core::err "fetch failed (network or credentials); not creating the branch"
			return 1
		}
	fi

	if [ -n "$base_opt" ]; then
		start="$base_opt"
	elif [ -n "$over" ]; then
		start="$over"
	else
		start="$(_shell::git::core::base)" || {
			_shell::git::core::err "cannot determine the base branch (set SHELL_GIT_BASE_BRANCH or pass --base)"
			return 1
		}
	fi
	sha="$(_shell::git::core::rev "$start")" || {
		_shell::git::core::err "the start point does not exist: $start"
		return 1
	}
	if _shell::git::core::git_ro rev-parse --verify --quiet "refs/heads/$branch" >/dev/null 2>&1; then
		_shell::git::core::err "the branch already exists: $branch"
		return 1
	fi

	if [ "$dry" = "1" ]; then
		[ "$fetch" = "1" ] && _shell::git::core::dry git fetch --quiet
		if _shell::git::core::git_ge 2 23; then
			_shell::git::core::dry git switch --create "$branch" --no-track "$start"
		else
			_shell::git::core::dry git checkout --no-track -b "$branch" "$start" --
		fi
		return 0
	fi

	_shell::git::core::commit_idle "$kind" || return $?
	_shell::git::core::require_clean "$autostash" || return $?
	if _shell::git::core::git_ge 2 23; then
		_shell::git::core::git_rw switch --create "$branch" --no-track "$sha" >&2 || return 1
	else
		_shell::git::core::git_rw checkout --no-track -b "$branch" "$sha" -- >&2 || return 1
	fi
	_shell::git::core::info "created $branch from $start and switched to it"
	printf '%s\n' "$branch"
}
