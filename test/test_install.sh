#!/usr/bin/env bash
# install.sh / uninstall.sh against a local tarball (no network).
. "$SHELL_TEST_ROOT/test/lib.sh"
T_HOME="$(mktemp -d "${TMPDIR:-/tmp}/shell-inst.XXXXXX")"
T_HOME="$(cd "$T_HOME" && pwd -P)" # canonical path (macOS: /var -> /private/var)
export HOME="$T_HOME"

# install.sh hooks bash users into ~/.bash_profile on macOS (Terminal starts bash as a
# login shell) and ~/.bashrc elsewhere. Tests must expect the same.
if [ "$(uname -s)" = "Darwin" ]; then PROFILE="$HOME/.bash_profile"; else PROFILE="$HOME/.bashrc"; fi

# Build a GitHub-style archive: everything under a "<repo>-<branch>/" prefix.
stage="$T_HOME/stage"
mkdir -p "$stage/shell-master"
(cd "$SHELL_TEST_ROOT" && tar --exclude=.git -cf - src install.sh uninstall.sh upgrade.sh) | (cd "$stage/shell-master" && tar -xf -)
(cd "$stage" && tar -czf "$T_HOME/shell.tar.gz" shell-master)
export SHELL_ARCHIVE_URL="file://$T_HOME/shell.tar.gz"
export SHELL_INSTALL_DIR="$T_HOME/shell"
export SHELL="/bin/bash"
: >"$PROFILE"

bash "$SHELL_TEST_ROOT/install.sh" >/dev/null 2>&1
t_eq "install: exit 0" "0" "$?"
t_rc "install: src/shell.sh present" 0 test -f "$SHELL_INSTALL_DIR/src/shell.sh"
t_eq "install: profile hook added once" "1" "$(grep -c 'src/shell.sh' "$PROFILE")"
bash "$SHELL_TEST_ROOT/install.sh" >/dev/null 2>&1
t_eq "install: idempotent profile hook" "1" "$(grep -c 'src/shell.sh' "$PROFILE")"
t_rc "install: previous version kept as .bak" 0 test -d "$SHELL_INSTALL_DIR.bak"
t_eq "install: no staging dirs left" "0" "$(find "$T_HOME" -maxdepth 1 -name '.shell-install.*' | wc -l | tr -d ' ')"

# Installed copy must load by itself.
out="$(bash -c "export HOME='$HOME' NO_COLOR=1; unset SHELL_DIR; . '$SHELL_INSTALL_DIR/src/shell.sh'; echo \$SHELL_LOAD_ERRORS; shell::os::type" 2>&1)"
t_eq "installed copy loads without errors" "0
$(uname -s | tr '[:upper:]' '[:lower:]' | sed 's/darwin/macos/')" "$out"

# A broken download must leave the existing installation untouched.
echo "not a tarball" >"$T_HOME/bad.tar.gz"
before="$(cat "$SHELL_INSTALL_DIR/src/shell.sh" | wc -c)"
SHELL_ARCHIVE_URL="file://$T_HOME/bad.tar.gz" bash "$SHELL_TEST_ROOT/install.sh" >/dev/null 2>&1
t_eq "bad archive: install fails" "1" "$?"
t_eq "bad archive: existing install untouched" "$before" "$(cat "$SHELL_INSTALL_DIR/src/shell.sh" | wc -c)"
SHELL_ARCHIVE_URL="file://$T_HOME/missing.tar.gz" bash "$SHELL_TEST_ROOT/install.sh" >/dev/null 2>&1
t_eq "missing archive: install fails" "1" "$?"
t_rc "missing archive: existing install untouched" 0 test -f "$SHELL_INSTALL_DIR/src/shell.sh"

# Refuses dangerous locations.
SHELL_INSTALL_DIR="$HOME" bash "$SHELL_TEST_ROOT/install.sh" >/dev/null 2>&1
t_eq "install refuses \$HOME" "1" "$?"

# Profile selection on each platform (fake `uname`, so this runs anywhere).
mkdir -p "$HOME/fakebin"
for platform in Darwin Linux; do
	printf '#!/bin/sh\n[ "$1" = "-s" ] && echo %s || /usr/bin/uname "$@"\n' "$platform" >"$HOME/fakebin/uname"
	chmod +x "$HOME/fakebin/uname"
	rm -f "$HOME/.bash_profile" "$HOME/.bashrc"
	PATH="$HOME/fakebin:$PATH" SHELL=/bin/bash bash "$SHELL_TEST_ROOT/install.sh" >/dev/null 2>&1
	if [ "$platform" = "Darwin" ]; then want=".bash_profile"; else want=".bashrc"; fi
	t_rc "install: bash on $platform hooks ~/$want" 0 grep -q 'src/shell.sh' "$HOME/$want"
done
rm -f "$HOME/.bash_profile" "$HOME/.bashrc"
: >"$PROFILE"
bash "$SHELL_TEST_ROOT/install.sh" >/dev/null 2>&1

# Uninstall keeps user data by default, removes hook + install dir.
mkdir -p "$HOME/.shell-config" && echo k >"$HOME/.shell-config/key.conf"
SHELL_DIR="$SHELL_INSTALL_DIR" bash "$SHELL_INSTALL_DIR/uninstall.sh" >/dev/null 2>&1
t_eq "uninstall: exit 0" "0" "$?"
t_rc "uninstall: install dir removed" 1 test -e "$SHELL_INSTALL_DIR"
t_eq "uninstall: profile hook removed" "0" "$(grep -c 'src/shell.sh' "$PROFILE")"
t_rc "uninstall: profile backup written" 0 test -f "$PROFILE.shell-bak"
t_rc "uninstall: user data kept" 0 test -f "$HOME/.shell-config/key.conf"

# Refuses to delete a directory that is not a shell installation.
mkdir -p "$HOME/precious" && echo x >"$HOME/precious/file"
SHELL_DIR="$HOME/precious" bash "$SHELL_TEST_ROOT/uninstall.sh" >/dev/null 2>&1
t_eq "uninstall refuses a non-installation dir" "1" "$?"
t_rc "uninstall: precious dir intact" 0 test -f "$HOME/precious/file"

bash "$SHELL_TEST_ROOT/install.sh" >/dev/null 2>&1
SHELL_DIR="$SHELL_INSTALL_DIR" bash "$SHELL_INSTALL_DIR/uninstall.sh" --purge >/dev/null 2>&1
t_rc "uninstall --purge removes config" 1 test -e "$HOME/.shell-config"

t_done
