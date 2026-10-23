#!/usr/bin/env bash
# @file dependency/lsof.sh
# @brief Ensure `lsof` is installed (open-files/port inspector used by shell::net::port::*).

# @description Make sure `lsof` is available, installing it when allowed.
#   Thin wrapper around shell::dependency::ensure; see that function for the
#   install policy (SHELL_AUTO_INSTALL_DEPS).
# @noargs
# @exitcode 0 `lsof` is available.
# @exitcode 3 `lsof` is missing and could not be installed.
# @see shell::dependency::ensure
# @example
#   shell::dependency::lsof::ensure || return
#
shell::dependency::lsof::ensure() {
	shell::dependency::ensure "lsof"
}
