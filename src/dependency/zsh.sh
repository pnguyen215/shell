#!/usr/bin/env bash
# @file dependency/zsh.sh
# @brief Ensure `zsh` is installed (shell::zsh::install needs it).

# @description Make sure `zsh` is available, installing it when allowed.
#   Thin wrapper around shell::dependency::ensure; see that function for the
#   install policy (SHELL_AUTO_INSTALL_DEPS). macOS ships /bin/zsh, so there
#   this is a single `command -v`.
# @noargs
# @exitcode 0 `zsh` is available.
# @exitcode 3 `zsh` is missing and could not be installed.
# @see shell::dependency::ensure
# @example
#   shell::dependency::zsh::ensure || return
#
shell::dependency::zsh::ensure() {
	shell::dependency::ensure "zsh"
}
