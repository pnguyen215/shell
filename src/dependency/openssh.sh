#!/usr/bin/env bash
# @file dependency/openssh.sh
# @brief Ensure the OpenSSH client (`ssh`, plus `scp`, `sftp`, `ssh-keygen` ...) is installed.

# @description Make sure `ssh` is available, installing the OpenSSH client when allowed.
#   Thin wrapper around shell::dependency::ensure; see that function for the
#   install policy (SHELL_AUTO_INSTALL_DEPS). The package is `openssh-client`
#   (apt), `openssh-clients` (dnf, yum, zypper) or `openssh` (the others).
# @noargs
# @exitcode 0 `ssh` is available.
# @exitcode 3 `ssh` is missing and could not be installed.
# @see shell::dependency::ensure
# @example
#   shell::dependency::openssh::ensure || return
#
shell::dependency::openssh::ensure() {
	shell::dependency::ensure "ssh"
}
