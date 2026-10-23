#!/usr/bin/env bash
# @file dependency/jq.sh
# @brief Ensure `jq` is installed (JSON processor used by the *::dump::json functions).

# @description Make sure `jq` is available, installing it when allowed.
#   Thin wrapper around shell::dependency::ensure; see that function for the
#   install policy (SHELL_AUTO_INSTALL_DEPS).
# @noargs
# @exitcode 0 `jq` is available.
# @exitcode 3 `jq` is missing and could not be installed.
# @see shell::dependency::ensure
# @example
#   shell::dependency::jq::ensure || return
#
shell::dependency::jq::ensure() {
	shell::dependency::ensure "jq"
}
