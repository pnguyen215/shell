#!/usr/bin/env bash
# @file dependency/column.sh
# @brief Ensure `column` is installed (column formatter used by shell::fs::ls).

# @description Make sure `column` is available, installing it when allowed.
#   Thin wrapper around shell::dependency::ensure; see that function for the
#   install policy (SHELL_AUTO_INSTALL_DEPS).
# @noargs
# @exitcode 0 `column` is available.
# @exitcode 3 `column` is missing and could not be installed.
# @see shell::dependency::ensure
# @example
#   shell::dependency::column::ensure || return
#
shell::dependency::column::ensure() {
	shell::dependency::ensure "column"
}
