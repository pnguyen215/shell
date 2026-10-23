#!/usr/bin/env bash
# @file uninstall.sh
# @brief Remove the shell library and its profile hook.
# @description
#   Removes the installation directory and the `source .../src/shell.sh` line
#   from your shell profile(s). Your data in ~/.shell-config (keys, bookmarks,
#   workspaces) is kept unless `--purge` is passed.
#
#   Usage:  uninstall.sh [--purge]
#
#   Every edited profile is backed up as `<profile>.shell-bak` first.

set -u

INSTALL_DIR="${SHELL_DIR:-${SHELL_INSTALL_DIR:-$HOME/shell}}"
CONFIG_DIR="${SHELL_CONFIG_DIR:-$HOME/.shell-config}"
MARKER_BEGIN="# >>> shell >>>"
MARKER_END="# <<< shell <<<"
purge="false"

for arg in "$@"; do
	case "$arg" in
	--purge) purge="true" ;;
	-h | --help)
		printf 'Usage: uninstall.sh [--purge]\n'
		exit 0
		;;
	*)
		printf 'ERR: Unknown option: %s\n' "$arg" >&2
		exit 2
		;;
	esac
done

printf '♻️  Uninstalling shell...\n'

# Never `rm -rf` something that is not clearly a shell installation.
case "$INSTALL_DIR" in
"" | "/" | "$HOME" | "$HOME/")
	printf 'ERR: Refusing to remove unsafe path "%s".\n' "$INSTALL_DIR" >&2
	exit 1
	;;
esac

if [ -d "$INSTALL_DIR" ]; then
	if [ ! -f "$INSTALL_DIR/src/shell.sh" ]; then
		printf 'ERR: %s does not look like a shell installation (no src/shell.sh); not removing it.\n' "$INSTALL_DIR" >&2
		exit 1
	fi
	rm -rf "$INSTALL_DIR"
	printf '[▸] Removed %s\n' "$INSTALL_DIR"
else
	printf '[▸] %s not found; nothing to remove.\n' "$INSTALL_DIR"
fi
# A leftover backup from install/upgrade is no longer needed either.
rm -rf "${INSTALL_DIR}.bak"

# Remove the profile hook: both the marked block and the legacy bare line.
for profile in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
	[ -f "$profile" ] || continue
	grep -qF "src/shell.sh" "$profile" || continue

	cp "$profile" "$profile.shell-bak"
	# `-i.suffix` (attached) is understood by both GNU and BSD sed.
	sed -i.tmp -e "\|$MARKER_BEGIN|,\|$MARKER_END|d" -e '\|source .*/src/shell\.sh|d' "$profile" &&
		rm -f "$profile.tmp"
	printf '[▸] Removed the shell hook from %s (backup: %s.shell-bak)\n' "$profile" "$profile"
done

if [ "$purge" = "true" ]; then
	case "$CONFIG_DIR" in
	"" | "/" | "$HOME" | "$HOME/")
		printf 'ERR: Refusing to purge unsafe path "%s".\n' "$CONFIG_DIR" >&2
		exit 1
		;;
	esac
	rm -rf "$CONFIG_DIR"
	printf '[▸] Purged %s\n' "$CONFIG_DIR"
else
	printf '[▸] Kept your data in %s (use --purge to delete it).\n' "$CONFIG_DIR"
fi

printf '[▸] shell uninstalled. Restart your terminal.\n'
