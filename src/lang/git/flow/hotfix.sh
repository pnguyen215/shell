#!/usr/bin/env bash
# @file lang/git/flow/hotfix.sh
# @brief shell::git::flow::hotfix: start a hotfix branch.

# @description Start a hotfix branch `<SHELL_GIT_HOTFIX_PREFIX><name>` (default prefix `hotfix/`) from the base
#   branch and switch to it. Same rules as `shell::git::flow::feature`: base branch resolved from
#   configuration or auto-detection (never hardcoded), name validated with `git check-ref-format`, no
#   operation in progress and a clean tree (exit 7) unless `--autostash`, optional `--fetch`.
# @option -n | --dry-run Print the exact commands and execute nothing.
# @option --autostash Stash a dirty tree first (restore with `git stash pop`).
# @option --fetch Fetch before creating the branch.
# @option --base <ref> Start point instead of the resolved base branch.
# @option -h | --help Show this help message.
# @arg $1 string Hotfix name.
# @stdout The new branch name.
# @exitcode 0 Success (or dry run).
# @exitcode 1 Failure (branch exists, no base branch, fetch failed).
# @exitcode 2 Usage error or invalid name.
# @exitcode 3 Not a git repository.
# @exitcode 5 Cancelled at the name prompt.
# @exitcode 7 Blocked by a dirty tree or an operation in progress.
# @example
#   shell::git::flow::hotfix crash-on-start
#   shell::git::flow::hotfix -n crash-on-start
#
shell::git::flow::hotfix() {
	_shell::git::core::env
	_shell::git::core::flow_start hotfix "$SHELL_GIT_HOTFIX_PREFIX" "" "$@"
}
