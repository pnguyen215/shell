#!/usr/bin/env bash
# install.sh / uninstall.sh and the nested Git toolkit tree plus the lazy-load cache, against local tarballs
# (no network, throwaway HOME): the tree is installed, the cache lives and dies with the install directory,
# an upgrade from the previous layout keeps existing functions working, and uninstall leaves nothing behind.
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
T_BASE="${SHELL_TEST_RUN:-${TMPDIR:-/tmp}}"
T_HOME="$(mktemp -d "$T_BASE/home.XXXXXX")"
T_HOME="$(cd "$T_HOME" && pwd -P)"
export HOME="$T_HOME" NO_COLOR=1 SHELL_AUTO_INSTALL_DEPS=0
if [ "$(uname -s)" = "Darwin" ]; then PROFILE="$HOME/.bash_profile"; else PROFILE="$HOME/.bashrc"; fi
export SHELL="/bin/bash" SHELL_INSTALL_DIR="$T_HOME/my shell" SHELL_NO_PROFILE=""
: >"$PROFILE"

# archive <name> <source dir with src/ install.sh ...>: a GitHub-style tarball under shell-master/
archive() {
	local name="$1" from="$2" st="$T_HOME/stage-$1"
	mkdir -p "$st/shell-master"
	(cd "$from" && tar --exclude=.git --exclude=.cache -cf - src install.sh uninstall.sh upgrade.sh) | (cd "$st/shell-master" && tar -xf -)
	(cd "$st" && tar -czf "$T_HOME/$name.tar.gz" shell-master)
}
# A shell that loads the installed copy and runs <code>; prints only what the code prints.
installed() {
	bash --noprofile --norc -c "unset SHELL_DIR; export HOME='$HOME' NO_COLOR=1 SHELL_AUTO_INSTALL_DEPS=0; . \"\$SHELL_INSTALL_DIR/src/shell.sh\" && $1" 2>&1
}

# --- the previous layout: the last commit before the toolkit, when the history is available
OLD_REV="594568a"
have_old=0
if git -C "$SHELL_TEST_ROOT" rev-parse --verify --quiet "$OLD_REV^{commit}" >/dev/null 2>&1; then
	have_old=1
	mkdir -p "$T_HOME/old-src"
	git -C "$SHELL_TEST_ROOT" archive "$OLD_REV" | tar -xf - -C "$T_HOME/old-src"
	archive old "$T_HOME/old-src"
fi
archive new "$SHELL_TEST_ROOT"

if [ "$have_old" = "1" ]; then
	SHELL_ARCHIVE_URL="file://$T_HOME/old.tar.gz" bash "$SHELL_TEST_ROOT/install.sh" >/dev/null 2>&1
	t_eq "previous layout: installs" "0" "$?"
	t_eq "previous layout: has no toolkit tree" "no" "$([ -e "$SHELL_INSTALL_DIR/src/lang/git/index.sh" ] && echo yes || echo no)"
	old_out="$(installed 'shell::os::type; shell::git::branch::merged -h >/dev/null 2>&1; echo "merged-rc=$?"')"
	t_has "previous layout: loads and works" "merged-rc=0" "$old_out"
fi

# --- install / upgrade to the current layout
SHELL_ARCHIVE_URL="file://$T_HOME/new.tar.gz" bash "$SHELL_TEST_ROOT/install.sh" >/dev/null 2>&1
t_eq "upgrade to the toolkit layout: exit 0" "0" "$?"
t_eq "install: the nested toolkit tree is installed (index.sh)" "yes" "$([ -f "$SHELL_INSTALL_DIR/src/lang/git/index.sh" ] && echo yes || echo no)"
expected_files="$(cd "$SHELL_TEST_ROOT/src/lang/git" && find . -name '*.sh' | sort)"
installed_files="$(cd "$SHELL_INSTALL_DIR/src/lang/git" && find . -name '*.sh' | sort)"
t_eq "install: every file of the toolkit tree arrives, none extra" "$expected_files" "$installed_files"
t_eq "install: no cache is shipped" "no" "$([ -e "$SHELL_INSTALL_DIR/.cache" ] && echo yes || echo no)"
t_eq "install: the path with a space works" "0" "$(installed 'echo $SHELL_LOAD_ERRORS' | tail -n 1)"
t_eq "install: the first start writes the lazy cache inside the install dir" "yes" "$([ -s "$SHELL_INSTALL_DIR/.cache/lazy.sh" ] && echo yes || echo no)"
t_eq "install: the cache holds no stale paths of the staging area" "0" "$(grep -c 'stage-' "$SHELL_INSTALL_DIR/.cache/lazy.sh" | tr -d ' ')"

out="$(installed 'typeset -f shell::git::branch::pick >/dev/null && echo stub-defined; shell::git::branch::merged -h >/dev/null 2>&1; echo "merged-rc=$?"; shell::os::type')"
t_has "installed toolkit: a stub is defined" "stub-defined" "$out"
t_has "installed toolkit: pre-existing git functions still work" "merged-rc=0" "$out"
# a toolkit function from the installed tree (the loader finds its files under the install path)
out="$(installed 'shell::git::repo::summary -h >/dev/null 2>&1; echo "rc=$?"; typeset -f _shell::git::core::err >/dev/null && echo core-loaded')"
if [ -f "$SHELL_INSTALL_DIR/src/lang/git/repo/summary.sh" ]; then
	t_has "installed toolkit: a real function loads from the installed tree" "core-loaded" "$out"
else
	out="$(installed '_shell::git::core::boot; typeset -f _shell::git::core::err >/dev/null && echo core-loaded')"
	t_has "installed toolkit: the core helpers load from the installed tree" "core-loaded" "$out"
fi
t_rc "upgrade: the previous install is kept as .bak" 0 test -d "$SHELL_INSTALL_DIR.bak"

# an upgrade replaces the directory: the cache of the old version cannot survive into the new one
cache_before="$(cksum <"$SHELL_INSTALL_DIR/.cache/lazy.sh")"
printf '# marker of the old install\n' >>"$SHELL_INSTALL_DIR/.cache/lazy.sh"
SHELL_ARCHIVE_URL="file://$T_HOME/new.tar.gz" bash "$SHELL_TEST_ROOT/install.sh" >/dev/null 2>&1
t_eq "reinstall: the old cache is gone with the old directory" "no" "$([ -e "$SHELL_INSTALL_DIR/.cache/lazy.sh" ] && echo yes || echo no)"
installed 'true' >/dev/null
t_eq "reinstall: the cache is rebuilt, without the old marker" "0" "$(grep -c 'marker of the old install' "$SHELL_INSTALL_DIR/.cache/lazy.sh" | tr -d ' ')"
t_eq "reinstall: ...and identical to the first build" "$cache_before" "$(cksum <"$SHELL_INSTALL_DIR/.cache/lazy.sh")"

# --- uninstall
mkdir -p "$HOME/.shell-config" && printf 'keep\n' >"$HOME/.shell-config/keepme"
bash "$SHELL_TEST_ROOT/uninstall.sh" >/dev/null 2>&1
t_eq "uninstall: exit 0" "0" "$?"
t_eq "uninstall: the install directory (with the toolkit tree and the cache) is gone" "no" "$([ -e "$SHELL_INSTALL_DIR" ] && echo yes || echo no)"
t_eq "uninstall: the .bak is gone too" "no" "$([ -e "$SHELL_INSTALL_DIR.bak" ] && echo yes || echo no)"
t_eq "uninstall: the profile hook is removed" "0" "$(grep -c 'src/shell.sh' "$PROFILE" | tr -d ' ')"
t_eq "uninstall: user data is kept" "keep" "$(cat "$HOME/.shell-config/keepme")"
t_eq "uninstall: nothing of the toolkit is left in the home (no cache, no refs files)" "0" "$(find "$HOME" -path "$HOME/.shell-config" -prune -o \( -name 'lazy.sh' -o -name 'ovr.*' -o -name '.lazy.*' \) -print | grep -v 'stage-' | wc -l | tr -d ' ')"

rm -rf "$T_HOME"
t_done
