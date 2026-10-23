#!/usr/bin/env bash
# @file dependency/openssl.sh
# @brief Ensure `openssl` is installed (cryptography toolkit used by shell::crypto::*).

# @description Make sure `openssl` is available, installing it when allowed.
#   Thin wrapper around shell::dependency::ensure; see that function for the
#   install policy (SHELL_AUTO_INSTALL_DEPS).
# @noargs
# @exitcode 0 `openssl` is available.
# @exitcode 3 `openssl` is missing and could not be installed.
# @see shell::dependency::ensure
# @example
#   shell::dependency::openssl::ensure || return
#
shell::dependency::openssl::ensure() {
	shell::dependency::ensure "openssl"
}
