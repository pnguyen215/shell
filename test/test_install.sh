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

# --- the git commit message templates are copied to ~/.shell-config/git ----------------------------------
tpl_src="$SHELL_TEST_ROOT/src/data/git-commit-messages.txt"
tpl_dst="$HOME/.shell-config/git/git-commit-messages.txt"
t_rc "install: the templates are copied to ~/.shell-config/git" 0 test -f "$tpl_dst"
t_rc "install: ...identical to the repository's file" 0 cmp -s "$tpl_src" "$tpl_dst"
t_eq "install: ...in a private directory (700)" "1" "$(find "$HOME/.shell-config/git" -maxdepth 0 -perm 700 | wc -l | tr -d ' ')"
t_rc "install: ...with no backup, nothing was there before" 1 test -e "$tpl_dst.bak"
t_eq "install: ...and no temporary file left behind" "0" "$(find "$HOME/.shell-config/git" -name '*.tmp.*' | wc -l | tr -d ' ')"

out="$(bash "$SHELL_TEST_ROOT/install.sh" 2>&1)"
t_has "install: names the file it installed" "Commit message templates: $tpl_dst" "$out"
t_rc "install again: still identical" 0 cmp -s "$tpl_src" "$tpl_dst"
t_rc "install again: an identical file is not backed up" 1 test -e "$tpl_dst.bak"

# an upgrade replaces a copy that was edited by hand, and keeps what it replaced
printf '\n# edited by hand\n' >>"$tpl_dst"
printf '[Mine]\n:tada:|chore|celebrate with a template of my own\n' >"$HOME/.shell-config/git/git-commit-messages.user.txt"
user_before="$(cat "$HOME/.shell-config/git/git-commit-messages.user.txt")"
bash "$SHELL_TEST_ROOT/install.sh" >/dev/null 2>&1
t_eq "upgrade: exit 0" "0" "$?"
t_rc "upgrade: the file is the repository's again" 0 cmp -s "$tpl_src" "$tpl_dst"
t_has "upgrade: the hand edit is kept in the backup" "# edited by hand" "$(cat "$tpl_dst.bak")"
t_eq "upgrade: your own template file is never touched" "$user_before" "$(cat "$HOME/.shell-config/git/git-commit-messages.user.txt")"
rm -f "$tpl_dst.bak" "$HOME/.shell-config/git/git-commit-messages.user.txt"

# the library reads the installed copy, not the one inside the installation
printf '[Installed Copy]\n:rocket:|ci|trigger the pipeline from the installed copy\n' >"$tpl_dst"
out="$(bash -c "export HOME='$HOME' NO_COLOR=1; unset SHELL_DIR SHELL_CONFIG_DIR; . '$SHELL_INSTALL_DIR/src/shell.sh'; shell::git::commit::message::scan categories" 2>&1)"
t_eq "the library reads ~/.shell-config/git/git-commit-messages.txt" "Installed Copy" "$out"
rm -f "$tpl_dst"
out="$(bash -c "export HOME='$HOME' NO_COLOR=1; unset SHELL_DIR SHELL_CONFIG_DIR; . '$SHELL_INSTALL_DIR/src/shell.sh'; shell::git::commit::message::scan categories | head -n 1" 2>&1)"
t_eq "without the installed copy it reads the one inside the installation" "CI/CD Pipeline Triggers" "$out"
bash "$SHELL_TEST_ROOT/install.sh" >/dev/null 2>&1
t_rc "install: restores the deleted copy" 0 cmp -s "$tpl_src" "$tpl_dst"

# SHELL_CONFIG_DIR moves it
alt="$HOME/alt-config"
SHELL_CONFIG_DIR="$alt" bash "$SHELL_TEST_ROOT/install.sh" >/dev/null 2>&1
t_rc "install: SHELL_CONFIG_DIR is honoured" 0 cmp -s "$tpl_src" "$alt/git/git-commit-messages.txt"

# a copy that cannot be made never breaks the installation
: >"$HOME/not-a-dir"
out="$(SHELL_CONFIG_DIR="$HOME/not-a-dir/config" bash "$SHELL_TEST_ROOT/install.sh" 2>&1)"
t_eq "install: a failed copy is not fatal (exit 0)" "0" "$(
	SHELL_CONFIG_DIR="$HOME/not-a-dir/config" bash "$SHELL_TEST_ROOT/install.sh" >/dev/null 2>&1
	echo $?
)"
t_has "install: ...but it says so and where the fallback is" "Could not copy the commit message templates" "$out"
t_rc "install: ...and the installation is complete" 0 test -f "$SHELL_INSTALL_DIR/src/shell.sh"

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
