#!/usr/bin/env bash
# @file dependency/curl.sh
# @brief Ensure `curl` is installed (HTTP client used by downloads, Telegram and GitHub API calls).

# @description Make sure `curl` is available, installing it when allowed.
#   Thin wrapper around shell::dependency::ensure; see that function for the
#   install policy (SHELL_AUTO_INSTALL_DEPS).
# @noargs
# @exitcode 0 `curl` is available.
# @exitcode 3 `curl` is missing and could not be installed.
# @see shell::dependency::ensure
# @example
#   shell::dependency::curl::ensure || return
#
shell::dependency::curl::ensure() {
	shell::dependency::ensure "curl"
}
