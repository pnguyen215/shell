#!/usr/bin/env bash
# @file dependency/fzf.sh
# @brief Ensure `fzf` is installed (interactive fuzzy finder used by every *::fzf function).

# @description Make sure `fzf` is available, installing it when allowed.
#   Thin wrapper around shell::dependency::ensure; see that function for the
#   install policy (SHELL_AUTO_INSTALL_DEPS).
# @noargs
# @exitcode 0 `fzf` is available.
# @exitcode 3 `fzf` is missing and could not be installed.
# @see shell::dependency::ensure
# @example
#   shell::dependency::fzf::ensure || return
#
shell::dependency::fzf::ensure() {
	shell::dependency::ensure "fzf"
}
