#!/usr/bin/env bash
# @file dependency/git.sh
# @brief Ensure `git` is installed (version control used by shell::git::*).

# @description Make sure `git` is available, installing it when allowed.
#   Thin wrapper around shell::dependency::ensure; see that function for the
#   install policy (SHELL_AUTO_INSTALL_DEPS).
# @noargs
# @exitcode 0 `git` is available.
# @exitcode 3 `git` is missing and could not be installed.
# @see shell::dependency::ensure
# @example
#   shell::dependency::git::ensure || return
#
shell::dependency::git::ensure() {
	shell::dependency::ensure "git"
}
