#!/usr/bin/env bash
# shell::zsh::install (src/lib/zsh.sh): every state of ~/.zshrc, the resolution order of the
# installation directory, the dry run and the safety rules. Runs under bash and zsh with an
# isolated HOME; the package layer, chsh and the user's answers are stubs.
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
t_setup

nl='
'
RC="$HOME/.zshrc"
BAK="$RC.shell-bak"
B="$SHELL_ZSH_HOOK_BEGIN"
E="$SHELL_ZSH_HOOK_END"
REAL="$SHELL_TEST_ROOT"
block() { printf '%s\nsource "%s/src/shell.sh"\n%s\n' "$B" "$1" "$E"; }
reset_home() { find "$HOME" -maxdepth 1 -name '.zshrc*' -exec rm -f {} +; }
count() { grep -c -- "$1" "$RC"; }

# A fake installation (only src/shell.sh matters) for the "other directory" cases.
FAKE="$HOME/fake-shell"
mkdir -p "$FAKE/src" && : >"$FAKE/src/shell.sh"

# --- missing .zshrc: created, never clobbered, no backup to make ---------------------------
reset_home
t_rc "missing: success" 0 shell::zsh::install
t_eq "missing: file is exactly the block" "$(block "$REAL")" "$(cat "$RC")"
t_eq "missing: no backup (nothing to back up)" "no" "$([ -e "$BAK" ] && echo yes || echo no)"
t_eq "missing: no temp file left" "0" "$(find "$HOME" -maxdepth 1 -name '.zshrc.shell-tmp.*' | wc -l | tr -d ' ')"

# --- wizard-generated .zshrc without a hook: block appended, other lines untouched ----------
reset_home
printf '# Created by newuser for 5.9\nautoload -Uz compinit\ncompinit\nalias ll="ls -l"' >"$RC"
cp "$RC" "$HOME/wizard.orig"
t_rc "wizard: success" 0 shell::zsh::install
t_eq "wizard: backup is the original" "$(cat "$HOME/wizard.orig")" "$(cat "$BAK")"
t_has "wizard: original lines kept" "alias ll=\"ls -l\"" "$(cat "$RC")"
t_eq "wizard: block appended once" "1" "$(count 'src/shell.sh')"
t_eq "wizard: ends with the block" "$(block "$REAL")" "$(tail -n 3 "$RC")"
t_eq "wizard: first lines byte-identical" "$(head -n 3 "$HOME/wizard.orig")" "$(head -n 3 "$RC")"

# --- correct hook: no-op, file untouched, no backup -----------------------------------------
reset_home
printf 'export A=1\n\n%s\nexport Z=2' "$(block "$REAL")" >"$RC" # no trailing newline on purpose
cp "$RC" "$HOME/ok.orig"
t_rc "noop: success" 0 shell::zsh::install
t_has "noop: says so" "nothing to do" "$T_OUT"
t_eq "noop: file byte-identical" "yes" "$(cmp -s "$RC" "$HOME/ok.orig" && echo yes || echo no)"
t_eq "noop: no backup" "no" "$([ -e "$BAK" ] && echo yes || echo no)"
t_rc "noop: again" 0 shell::zsh::install
t_eq "noop: still identical" "yes" "$(cmp -s "$RC" "$HOME/ok.orig" && echo yes || echo no)"

# --- stale path: updated IN PLACE, backup keeps the old content -----------------------------
reset_home
printf 'export A=1\n%s\nsource "/gone/dir/src/shell.sh"\n%s\nexport Z=2\n' "$B" "$E" >"$RC"
cp "$RC" "$HOME/stale.orig"
t_rc "stale: success" 0 shell::zsh::install
t_eq "stale: updated in place" "export A=1${nl}$(block "$REAL")${nl}export Z=2" "$(cat "$RC")"
t_eq "stale: backup is the old file" "$(cat "$HOME/stale.orig")" "$(cat "$BAK")"
t_eq "stale: old path is gone" "0" "$(count '/gone/dir')"

# --- legacy unmarked line: migrated into the block, no duplicates ---------------------------
reset_home
printf 'export A=1\nsource ~/old/src/shell.sh\nexport Z=2\n. "$HOME/other/src/shell.sh"\n# source /commented/src/shell.sh\n' >"$RC"
t_rc "legacy: success" 0 shell::zsh::install
t_has "legacy: migrated" "Migrated" "$T_OUT"
t_eq "legacy: one hook only" "1" "$(grep -c '^source ' "$RC")"
t_eq "legacy: position kept, others untouched" "export A=1${nl}$(block "$REAL")${nl}export Z=2${nl}# source /commented/src/shell.sh" "$(cat "$RC")"
t_eq "legacy: backup made" "yes" "$([ -f "$BAK" ] && echo yes || echo no)"

# duplicate marked blocks collapse into one
reset_home
{
	block "$FAKE"
	echo 'export M=1'
	block "$FAKE"
} >"$RC"
t_rc "dup: success" 0 shell::zsh::install --dir "$FAKE"
t_eq "dup: one block" "$(block "$FAKE")${nl}export M=1" "$(cat "$RC")"

# --- no valid installation: error, .zshrc untouched ------------------------------------------
reset_home
printf 'export A=1\n' >"$RC"
cp "$RC" "$HOME/none.orig"
(
	SHELL_DIR="$HOME/nowhere"
	SHELL_INSTALL_DIR="$HOME/nowhere2"
	t_rc "none: not found" "$RETURN_NOT_FOUND" shell::zsh::install
	t_has "none: install one-liner" "install.sh" "$T_OUT"
	t_eq "none: untouched" "yes" "$(cmp -s "$RC" "$HOME/none.orig" && echo yes || echo no)"
	t_eq "none: no backup" "no" "$([ -e "$BAK" ] && echo yes || echo no)"
	rm -f "$RC"
	t_rc "none: not found, no file" "$RETURN_NOT_FOUND" shell::zsh::install
	t_eq "none: file not created" "no" "$([ -e "$RC" ] && echo yes || echo no)"
	T_PASS_SUB="$T_PASS"
	T_FAIL_SUB="$T_FAIL"
	printf '%s %s' "$T_PASS" "$T_FAIL" >"$HOME/sub.counts"
)
read -r p f <"$HOME/sub.counts"
T_PASS="$p"
T_FAIL="$f"
# a hook of a valid installation is found even when the session knows nothing (candidate d)
reset_home
block "$FAKE" >"$RC"
(
	SHELL_DIR="$HOME/nowhere"
	t_rc "hook candidate: success" 0 shell::zsh::install
	t_has "hook candidate: source named" "(hook)" "$T_OUT"
	t_eq "hook candidate: file unchanged" "$(block "$FAKE")" "$(cat "$RC")"
	printf '%s %s' "$T_PASS" "$T_FAIL" >"$HOME/sub.counts"
)
read -r p f <"$HOME/sub.counts"
T_PASS="$p"
T_FAIL="$f"

# --- resolution order and dangerous directories ----------------------------------------------
reset_home
t_rc "dir arg: success" 0 shell::zsh::install --dir "$FAKE"
t_eq "dir arg: used" "$(block "$FAKE")" "$(cat "$RC")"
reset_home
t_rc "dir arg=: success" 0 shell::zsh::install "--dir=$FAKE/"
t_eq "dir arg=: trailing slash removed" "$(block "$FAKE")" "$(cat "$RC")"
reset_home
(
	SHELL_INSTALL_DIR="$FAKE"
	t_rc "env: success" 0 shell::zsh::install
	t_has "env: SHELL_INSTALL_DIR wins over the session" "(SHELL_INSTALL_DIR)" "$T_OUT"
	printf '%s %s' "$T_PASS" "$T_FAIL" >"$HOME/sub.counts"
)
read -r p f <"$HOME/sub.counts"
T_PASS="$p"
T_FAIL="$f"
reset_home
t_rc "danger: /" "$RETURN_INVALID" shell::zsh::install --dir /
t_rc "danger: HOME" "$RETURN_INVALID" shell::zsh::install --dir "$HOME"
t_rc "danger: relative" "$RETURN_INVALID" shell::zsh::install --dir relative/dir
t_rc "danger: quote" "$RETURN_INVALID" shell::zsh::install --dir '/tmp/a"b'
t_rc "danger: dollar" "$RETURN_INVALID" shell::zsh::install --dir '/tmp/a$b'
t_rc "danger: no src/shell.sh" "$RETURN_NOT_FOUND" shell::zsh::install --dir "$HOME"/empty
t_rc "arg: --dir needs a value" "$RETURN_INVALID" shell::zsh::install --dir
t_rc "arg: unknown option" "$RETURN_INVALID" shell::zsh::install --bogus
t_eq "danger: nothing was written" "no" "$([ -e "$RC" ] && echo yes || echo no)"

# the session's library shadows a different valid hook: ask first
reset_home
block "$FAKE" >"$RC"
cp "$RC" "$HOME/shadow.orig"
T_OUT="$(printf 'n\n' | shell::zsh::install 2>&1)"
t_rc_is=$?
t_eq "shadow: declined -> cancelled" "$RETURN_CANCELLED" "$t_rc_is"
t_eq "shadow: declined -> untouched" "yes" "$(cmp -s "$RC" "$HOME/shadow.orig" && echo yes || echo no)"
printf 'y\n' | shell::zsh::install >/dev/null 2>&1
t_eq "shadow: accepted -> updated" "$(block "$REAL")" "$(cat "$RC")"
reset_home
block "$FAKE" >"$RC"
t_rc "shadow: --dir decides without a question" 0 shell::zsh::install --dir "$REAL"
t_eq "shadow: --dir applied" "$(block "$REAL")" "$(cat "$RC")"

# --- dry run: prints the plan, writes nothing ------------------------------------------------
reset_home
t_rc "dry: missing file" 0 shell::zsh::install -n
t_has "dry: shows the block" "$B" "$T_OUT"
t_has "dry: shows the source line" "source \"$REAL/src/shell.sh\"" "$T_OUT"
t_eq "dry: file not created" "no" "$([ -e "$RC" ] && echo yes || echo no)"
printf 'export A=1\n' >"$RC"
cp "$RC" "$HOME/dry.orig"
t_rc "dry: existing file" 0 shell::zsh::install --dry-run
t_has "dry: mentions the backup" ".shell-bak" "$T_OUT"
t_eq "dry: file unchanged" "yes" "$(cmp -s "$RC" "$HOME/dry.orig" && echo yes || echo no)"
t_eq "dry: no backup" "no" "$([ -e "$BAK" ] && echo yes || echo no)"

# --- unclosed marker block: refuse, nothing guessed -------------------------------------------
reset_home
printf 'export A=1\n%s\nsource "/x/src/shell.sh"\nexport KEEP=me\n' "$B" >"$RC"
cp "$RC" "$HOME/open.orig"
t_rc "unclosed: failure" "$RETURN_FAILURE" shell::zsh::install
t_eq "unclosed: untouched" "yes" "$(cmp -s "$RC" "$HOME/open.orig" && echo yes || echo no)"

# --- symbolic link (dotfile managers): the target is rewritten, the link stays ---------------
reset_home
mkdir -p "$HOME/dotfiles"
printf 'export A=1\n' >"$HOME/dotfiles/zshrc"
ln -s "$HOME/dotfiles/zshrc" "$RC"
t_rc "symlink: success" 0 shell::zsh::install
t_eq "symlink: still a link" "yes" "$([ -L "$RC" ] && echo yes || echo no)"
t_has "symlink: target has the hook" "src/shell.sh" "$(cat "$HOME/dotfiles/zshrc")"
rm -f "$RC" "$BAK"

# --- the file permissions survive ---------------------------------------------------------------
reset_home
printf 'export A=1\n' >"$RC"
chmod 600 "$RC"
shell::zsh::install >/dev/null 2>&1
t_eq "mode: 600 kept" "600" "$(shell::fs::stat mode "$RC")"

# --- uninstall.sh keeps working on what we write ---------------------------------------------
reset_home
printf 'export A=1\n' >"$RC"
shell::zsh::install >/dev/null 2>&1
sed -i.tmp -e "\|$B|,\|$E|d" -e '\|source .*/src/shell\.sh|d' "$RC" && rm -f "$RC.tmp"
t_eq "uninstall: the block is removed cleanly" "export A=1" "$(grep -v '^$' "$RC")"
t_eq "uninstall: nothing of the hook is left" "0" "$(count 'src/shell.sh')"

# --- zsh missing: installed through the package layer, or the profile is not touched -----------
reset_home
printf 'export A=1\n' >"$RC"
cp "$RC" "$HOME/nozsh.orig"
(
	_shell::zsh::have() { return 1; }
	shell::dependency::zsh::ensure() { return "$RETURN_NOT_FOUND"; }
	t_rc "no zsh: not found when it cannot be installed" "$RETURN_NOT_FOUND" shell::zsh::install
	t_eq "no zsh: profile untouched" "yes" "$(cmp -s "$RC" "$HOME/nozsh.orig" && echo yes || echo no)"
	t_rc "no zsh: dry run still plans" 0 shell::zsh::install -n
	t_has "no zsh: dry run names the ensure step" "shell::dependency::zsh::ensure" "$T_OUT"
	shell::dependency::zsh::ensure() { return 0; }
	t_rc "no zsh: continues once ensured" 0 shell::zsh::install
	t_has "no zsh: hook written" "src/shell.sh" "$(cat "$RC")"
	printf '%s %s' "$T_PASS" "$T_FAIL" >"$HOME/sub.counts"
)
read -r p f <"$HOME/sub.counts"
T_PASS="$p"
T_FAIL="$f"

# --- --default: chsh only after the flag AND a confirmation ----------------------------------
mkdir -p "$HOME/bin"
cat >"$HOME/bin/chsh" <<'FAKE'
#!/bin/sh
printf '%s\n' "$*" >>"$FAKE_CHSH_LOG"
FAKE
chmod +x "$HOME/bin/chsh"
export FAKE_CHSH_LOG="$HOME/chsh.log"
: >"$FAKE_CHSH_LOG"
ZBIN="$(command -v zsh)"
printf '%s\n' "$ZBIN" >"$HOME/shells"
reset_home
(
	export PATH="$HOME/bin:$PATH" SHELL=/bin/bash SHELL_ZSH_SHELLS_FILE="$HOME/shells"
	shell::zsh::install >/dev/null 2>&1
	t_eq "default: no flag, no chsh" "0" "$(wc -l <"$FAKE_CHSH_LOG" | tr -d ' ')"
	T_OUT="$(printf 'n\n' | shell::zsh::install --default 2>&1)"
	t_eq "default: declined" "$RETURN_CANCELLED" "$?"
	t_eq "default: declined, no chsh" "0" "$(wc -l <"$FAKE_CHSH_LOG" | tr -d ' ')"
	t_rc "default: dry run" 0 shell::zsh::install -n --default
	t_has "default: dry run prints chsh" "chsh -s" "$T_OUT"
	t_eq "default: dry run, no chsh" "0" "$(wc -l <"$FAKE_CHSH_LOG" | tr -d ' ')"
	printf 'y\n' | shell::zsh::install --default >/dev/null 2>&1
	t_eq "default: confirmed" "1" "$(wc -l <"$FAKE_CHSH_LOG" | tr -d ' ')"
	t_has "default: chsh gets the zsh path" "-s " "$(cat "$FAKE_CHSH_LOG")"
	SHELL=/usr/bin/zsh
	: >"$FAKE_CHSH_LOG"
	t_rc "default: already zsh" 0 shell::zsh::install --default
	t_eq "default: already zsh, no chsh" "0" "$(wc -l <"$FAKE_CHSH_LOG" | tr -d ' ')"
	printf '%s %s' "$T_PASS" "$T_FAIL" >"$HOME/sub.counts"
)
read -r p f <"$HOME/sub.counts"
T_PASS="$p"
T_FAIL="$f"
(
	export SHELL=/bin/bash SHELL_ZSH_SHELLS_FILE="$HOME/shells-empty"
	: >"$SHELL_ZSH_SHELLS_FILE"
	t_rc "default: not in shells file" "$RETURN_FAILURE" shell::zsh::install --default
	t_has "default: tells how to add it" "tee -a" "$T_OUT"
	printf '%s %s' "$T_PASS" "$T_FAIL" >"$HOME/sub.counts"
)
read -r p f <"$HOME/sub.counts"
T_PASS="$p"
T_FAIL="$f"

# --- help and the dependency wrapper -----------------------------------------------------------
t_rc "help" 0 shell::zsh::install --help
t_has "help: usage" "shell::zsh::install" "$T_OUT"
t_rc "help: -h" 0 shell::zsh::install -h
t_rc "ensure: zsh present is a no-op" 0 shell::dependency::zsh::ensure

t_done
