#!/usr/bin/env bash
# @file lang/git/flow/feature.sh
# @brief shell::git::flow::feature: start a feature branch.

# @description Start a feature branch `<SHELL_GIT_FEATURE_PREFIX><name>` (default prefix `feature/`) from the
#   base branch and switch to it. The base branch comes from `SHELL_GIT_BASE_BRANCH`, then `origin/HEAD`,
#   then `main`/`master`/`develop`, or `--base <ref>`; it is never hardcoded. The name is validated with
#   `git check-ref-format`. Preconditions: no operation in progress and a clean tree (exit 7), or `--autostash`
#   to stash tracked changes first. `--fetch` fetches before branching (never prompts for credentials, never
#   hangs). Without a name, on a terminal, you are asked for one; otherwise exit 2.
# @option -n | --dry-run Print the exact commands and execute nothing.
# @option --autostash Stash a dirty tree first (restore with `git stash pop`).
# @option --fetch Fetch before creating the branch.
# @option --base <ref> Start point instead of the resolved base branch.
# @option -h | --help Show this help message.
# @arg $1 string Feature name.
# @stdout The new branch name.
# @exitcode 0 Success (or dry run).
# @exitcode 1 Failure (branch exists, no base branch, fetch failed).
# @exitcode 2 Usage error or invalid name.
# @exitcode 3 Not a git repository.
# @exitcode 5 Cancelled at the name prompt.
# @exitcode 7 Blocked by a dirty tree or an operation in progress.
# @example
#   shell::git::flow::feature login-form
#   shell::git::flow::feature -n --fetch login-form
#
shell::git::flow::feature() {
	_shell::git::core::env
	_shell::git::core::flow_start feature "$SHELL_GIT_FEATURE_PREFIX" "" "$@"
}
