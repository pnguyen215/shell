#!/usr/bin/env bash
# @file lang/git/_core/env.sh
# @brief Configuration of the Git toolkit: SHELL_GIT_* variables and their lazy defaults.
# @description
#   Settings (environment, all optional):
#     SHELL_GIT_BASE_BRANCH         base branch (default: origin/HEAD, then main, master, develop)
#     SHELL_GIT_FEATURE_PREFIX      prefix of feature branches (default: feature/)
#     SHELL_GIT_RELEASE_PREFIX      prefix of release branches (default: release/)
#     SHELL_GIT_HOTFIX_PREFIX       prefix of hotfix branches (default: hotfix/)
#     SHELL_GIT_STALE_DAYS          age in days after which a branch is stale (default: 90)
#     SHELL_GIT_PROTECTED_BRANCHES  space separated names never deleted (default: "main master develop")
#     SHELL_GIT_FZF_OPTS            extra fzf options appended to every picker
#   Test and automation hooks:
#     SHELL_GIT_ASSUME_YES=1        confirmations are answered "yes" (what every --yes flag sets)
#     SHELL_GIT_INPUT=<file>        read prompt answers and numbered choices from <file> instead of /dev/tty
#     SHELL_GIT_QUIET=1             no info lines on stderr
#   Defaults are applied by _shell::git::core::env, on first use, never at shell start.

# @internal
# @description Apply the defaults of every SHELL_GIT_* setting that is not set. Idempotent and cheap.
#   The only variables this toolkit leaks into the shell are these and the `_SHELL_GIT_*` caches.
# @exitcode 0 Always.
# @example
#   _shell::git::core::env
#
_shell::git::core::env() {
	: "${SHELL_GIT_FEATURE_PREFIX:=feature/}"
	: "${SHELL_GIT_RELEASE_PREFIX:=release/}"
	: "${SHELL_GIT_HOTFIX_PREFIX:=hotfix/}"
	: "${SHELL_GIT_STALE_DAYS:=90}"
	: "${SHELL_GIT_PROTECTED_BRANCHES:=main master develop}"
	: "${SHELL_GIT_FZF_OPTS:=}"
	return 0
}
