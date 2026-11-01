#!/usr/bin/env bash
# @file dependency/rsync.sh
# @brief Ensure `rsync` is installed (used by shell::ssh::rsync::*).

# @description Make sure `rsync` is available, installing it when allowed.
#   Thin wrapper around shell::dependency::ensure; see that function for the
#   install policy (SHELL_AUTO_INSTALL_DEPS).
# @noargs
# @exitcode 0 `rsync` is available.
# @exitcode 3 `rsync` is missing and could not be installed.
# @see shell::dependency::ensure
# @example
#   shell::dependency::rsync::ensure || return
#
shell::dependency::rsync::ensure() {
	shell::dependency::ensure "rsync"
}
