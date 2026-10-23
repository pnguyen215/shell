#!/usr/bin/env bash
# @file upgrade.sh
# @brief Upgrade the shell library to the latest version.
# @description
#   Thin wrapper over install.sh, which already performs a safe, staged,
#   rollback-capable replacement of an existing installation.
#
#   The previous version ran `rm -rf ~/shell` *before* downloading anything, so
#   a dropped connection destroyed the installation. That ordering is gone:
#   nothing is removed until the new version is downloaded and verified.
#
#       /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pnguyen215/shell/master/upgrade.sh)"

set -u

SLUG="${SHELL_REPO_SLUG:-pnguyen215/shell}"
BRANCH="${SHELL_REPO_BRANCH:-master}"

printf '↻ Upgrading shell...\n'

# Always use the *latest* installer, not whatever copy is lying around locally.
installer="$(mktemp "${TMPDIR:-/tmp}/shell-install.XXXXXX")" || exit 1
trap 'rm -f "$installer"' EXIT

curl -fsSL --connect-timeout 15 --max-time 300 -o "$installer" \
	"https://raw.githubusercontent.com/$SLUG/$BRANCH/install.sh" || {
	printf 'ERR: Could not download the installer; your installation was left untouched.\n' >&2
	exit 1
}

bash "$installer" || exit 1
printf '[▸] shell upgraded. Restart your terminal or re-source your shell profile to apply changes.\n'
