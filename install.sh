#!/usr/bin/env bash
# @file install.sh
# @brief Install (or upgrade in place) the shell library.
# @description
#   Run it straight from GitHub:
#
#       /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pnguyen215/shell/master/install.sh)"
#
#   What it does:
#     1. Downloads the repository tarball to a staging directory next to the
#        install location (so the final `mv` stays on one filesystem).
#     2. Verifies the download actually contains src/shell.sh.
#     3. Swaps it into place, keeping the previous installation as `<dir>.bak`
#        and restoring it automatically if the swap fails.
#     4. Adds `source <dir>/src/shell.sh` to the right shell profile, once.
#     5. Copies the data files the library reads (the git commit message
#        templates) to `~/.shell-config/git/`. The repository is the source of
#        truth, so the copy is refreshed on every install/upgrade; a copy that
#        differs is kept as `<file>.bak`. Never fatal: without the copy the
#        library reads the file inside the installation.
#
#   Environment overrides:
#     SHELL_INSTALL_DIR  install location          (default: $HOME/shell)
#     SHELL_CONFIG_DIR   user data location        (default: $HOME/.shell-config)
#     SHELL_REPO_SLUG    GitHub owner/repo         (default: pnguyen215/shell)
#     SHELL_REPO_BRANCH  branch to install         (default: master)
#     SHELL_NO_PROFILE   set to 1 to leave dotfiles untouched
#     SHELL_ARCHIVE_URL  tarball to install (default: the GitHub archive of the branch)
#
#   Only `curl` and `tar` are required; both ship with macOS and with every
#   mainstream Linux distribution (the previous version needed `unzip`).
#   Compatible with bash 3.2 (macOS system bash).

set -u

SLUG="${SHELL_REPO_SLUG:-pnguyen215/shell}"
BRANCH="${SHELL_REPO_BRANCH:-master}"
INSTALL_DIR="${SHELL_INSTALL_DIR:-$HOME/shell}"
MARKER_BEGIN="# >>> shell >>>"
MARKER_END="# <<< shell <<<"

say() { printf '%s\n' "$*"; }
die() {
	printf 'ERR: %s\n' "$*" >&2
	exit 1
}

# --- Preconditions -----------------------------------------------------------
for tool in curl tar; do
	command -v "$tool" >/dev/null 2>&1 ||
		die "$tool is required but not installed (e.g. 'sudo apt install $tool' on Ubuntu, 'brew install $tool' on macOS)."
done

# Refuse locations that would make later `rm -rf` / `mv` operations dangerous.
case "$INSTALL_DIR" in
"" | "/" | "$HOME" | "$HOME/")
	die "Refusing to install into '$INSTALL_DIR'. Set SHELL_INSTALL_DIR to a dedicated directory."
	;;
esac

say "📦 Installing shell into $INSTALL_DIR ..."

# --- Stage the download ------------------------------------------------------
parent="$(dirname "$INSTALL_DIR")"
mkdir -p "$parent" || die "Cannot create $parent."
stage="$(mktemp -d "$parent/.shell-install.XXXXXX")" || die "Cannot create a staging directory in $parent."
# Always clean the staging area, whatever happens.
trap 'rm -rf "$stage"' EXIT

# SHELL_ARCHIVE_URL lets tests (and mirrors) point at any tarball, even file://.
url="${SHELL_ARCHIVE_URL:-https://github.com/$SLUG/archive/refs/heads/$BRANCH.tar.gz}"
# -f: fail on HTTP errors (a 404 must not be treated as an archive).
curl -fsSL --connect-timeout 15 --max-time 300 -o "$stage/shell.tar.gz" "$url" ||
	die "Download failed: $url"

mkdir "$stage/extract" || die "Cannot create $stage/extract."
# GitHub wraps the tree in "<repo>-<branch>/"; --strip-components=1 removes it.
tar -xzf "$stage/shell.tar.gz" -C "$stage/extract" --strip-components=1 ||
	die "Extraction failed (corrupt download?)."

[ -f "$stage/extract/src/shell.sh" ] ||
	die "The downloaded archive does not contain src/shell.sh; aborting before touching your installation."

# --- Swap into place (with rollback) -----------------------------------------
backup="${INSTALL_DIR}.bak"
if [ -e "$INSTALL_DIR" ]; then
	rm -rf "$backup"
	mv "$INSTALL_DIR" "$backup" || die "Cannot move the existing installation aside."
fi

if ! mv "$stage/extract" "$INSTALL_DIR"; then
	# Roll back so the user keeps a working installation.
	[ -e "$backup" ] && mv "$backup" "$INSTALL_DIR"
	die "Could not move the new version into place; the previous version was restored."
fi

# --- Data files ----------------------------------------------------------------
CONFIG_DIR="${SHELL_CONFIG_DIR:-$HOME/.shell-config}"

# install_data <source> <destination>: copy a data file shipped in the repository
# into the config directory. Replaced only when it differs (the old one is kept as
# <destination>.bak); written next to the destination and moved into place, so a
# failure never leaves a half-written file.
install_data() {
	local src="$1" dest="$2" tmp
	[ -f "$src" ] || return 0
	if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
		return 0
	fi
	(umask 077 && mkdir -p "$(dirname "$dest")") || return 1
	if [ -f "$dest" ]; then
		cp -p "$dest" "$dest.bak" || return 1
	fi
	tmp="$dest.tmp.$$"
	if ! cp "$src" "$tmp" || ! mv -f "$tmp" "$dest"; then
		rm -f "$tmp"
		return 1
	fi
}

if install_data "$INSTALL_DIR/src/data/git-commit-messages.txt" "$CONFIG_DIR/git/git-commit-messages.txt"; then
	say "[▸] Commit message templates: $CONFIG_DIR/git/git-commit-messages.txt"
else
	say "[!] Could not copy the commit message templates to $CONFIG_DIR/git; the copy inside $INSTALL_DIR is used instead."
fi

# --- Hook into the shell profile ---------------------------------------------

# Choose the profile the user's login shell actually reads.
pick_profile() {
	local login_shell
	login_shell="$(basename "${SHELL:-}")"
	case "$login_shell" in
	zsh) printf '%s\n' "$HOME/.zshrc" ;;
	bash)
		# macOS Terminal starts bash as a *login* shell, which reads
		# ~/.bash_profile, not ~/.bashrc.
		if [ "$(uname -s)" = "Darwin" ]; then
			printf '%s\n' "$HOME/.bash_profile"
		else
			printf '%s\n' "$HOME/.bashrc"
		fi
		;;
	*)
		if [ -f "$HOME/.zshrc" ]; then
			printf '%s\n' "$HOME/.zshrc"
		else
			printf '%s\n' "$HOME/.bashrc"
		fi
		;;
	esac
}

profile=""
if [ "${SHELL_NO_PROFILE:-0}" != "1" ]; then
	profile="$(pick_profile)"
	# Any existing mention of src/shell.sh (including the legacy one-liner) means
	# the hook is already there.
	if [ -f "$profile" ] && grep -qF "src/shell.sh" "$profile" 2>/dev/null; then
		say "[▸] $profile already sources shell."
	else
		{
			printf '\n%s\n' "$MARKER_BEGIN"
			printf 'source "%s/src/shell.sh"\n' "$INSTALL_DIR"
			printf '%s\n' "$MARKER_END"
		} >>"$profile" || die "Cannot write to $profile."
		say "[▸] Added shell to $profile"
	fi
fi

say "[▸] shell installed. Restart your terminal${profile:+ or run: source $profile}"
