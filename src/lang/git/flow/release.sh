#!/usr/bin/env bash
# @file lang/git/flow/release.sh
# @brief shell::git::flow::release: start a release branch.

# @description Start a release branch `<SHELL_GIT_RELEASE_PREFIX><name>` (default prefix `release/`) and switch
#   to it. It starts from the release base: `SHELL_GIT_RELEASE_BASE` when set (for example `develop`),
#   otherwise the resolved base branch; `--base <ref>` overrides both. The name is validated with
#   `git check-ref-format`. No operation in progress and a clean tree (exit 7) unless `--autostash`;
#   optional `--fetch`.
# @option -n | --dry-run Print the exact commands and execute nothing.
# @option --autostash Stash a dirty tree first (restore with `git stash pop`).
# @option --fetch Fetch before creating the branch.
# @option --base <ref> Start point instead of the release base.
# @option -h | --help Show this help message.
# @arg $1 string Release name (for example a version).
# @stdout The new branch name.
# @exitcode 0 Success (or dry run).
# @exitcode 1 Failure (branch exists, no base branch, fetch failed).
# @exitcode 2 Usage error or invalid name.
# @exitcode 3 Not a git repository.
# @exitcode 5 Cancelled at the name prompt.
# @exitcode 7 Blocked by a dirty tree or an operation in progress.
# @example
#   shell::git::flow::release 1.4.0
#   SHELL_GIT_RELEASE_BASE=develop shell::git::flow::release -n 1.4.0
#
shell::git::flow::release() {
	_shell::git::core::env
	_shell::git::core::flow_start release "$SHELL_GIT_RELEASE_PREFIX" "${SHELL_GIT_RELEASE_BASE-}" "$@"
}
