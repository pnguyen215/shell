#!/usr/bin/env bash
# shell::ini::*::fzf and shell::profile::conf::* menus (src/lib/ini.sh, src/lib/profile.sh): the
# trailing "← Back" entry, and that Back changes nothing. fzf is a fake (see test_brew_fzf.sh): the
# Nth call picks the line of $FAKE_FZF_PICKS matching text; an empty pick is ESC.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

mkdir "$HOME/bin"
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
n="$(cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0)"
n=$((n + 1))
echo "$n" >"$FAKE_FZF_STATE"
cat >"$FAKE_FZF_DIR/stdin.$n"
pick="$(printf '%s\n' "$FAKE_FZF_PICKS" | sed -n "${n}p")"
[ -z "$pick" ] && exit 130
grep -F -- "$pick" "$FAKE_FZF_DIR/stdin.$n" | head -n 1
FAKE
chmod +x "$HOME/bin/fzf"
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME/fzfdir" FAKE_FZF_STATE="$HOME/fzf.count"
mkdir "$FAKE_FZF_DIR"
B="$SHELL_FZF_BACK_LABEL"
# The fake fzf does not strip ANSI codes like --ansi does: keep the colored menus plain.
export TERM=dumb

run() {
	rm -f "$FAKE_FZF_STATE"
	find "$FAKE_FZF_DIR" -name "stdin.*" -delete
	FAKE_FZF_PICKS="$1" "${@:2}" >"$HOME/out.log" 2>&1
	echo "$?"
}

ini="$HOME/b.ini"
printf '[dev]\nHOST=localhost\n[prod]\nHOST=example\n' >"$ini"
before="$(cat "$ini")"

t_eq "key::remove::fzf: Back returns RETURN_BACK" "$RETURN_BACK" "$(run "$B" shell::ini::key::remove::fzf "$ini" dev)"
t_eq "key::remove::fzf: Back is the last entry" "$B" "$(tail -n 1 "$FAKE_FZF_DIR/stdin.1")"
t_eq "key::remove::fzf: Back removed nothing" "$before" "$(cat "$ini")"
t_eq "key::remove::fzf: ESC keeps rc 1" "1" "$(run "" shell::ini::key::remove::fzf "$ini" dev)"
t_eq "section::rename::fzf: Back returns RETURN_BACK" "$RETURN_BACK" "$(run "$B" shell::ini::section::rename::fzf "$ini")"
t_eq "section::clone::fzf: Back returns RETURN_BACK" "$RETURN_BACK" "$(run "$B" shell::ini::section::clone::fzf "$ini")"
t_eq "view::fzf: Back at sections returns RETURN_BACK" "$RETURN_BACK" "$(run "$B" shell::ini::view::fzf "$ini")"
t_eq "view::fzf: Back at keys returns to the sections" "$RETURN_BACK" "$(run "dev
$B
$B" shell::ini::view::fzf "$ini")"
t_eq "view::fzf: ...which showed the sections twice" "3" "$(cat "$FAKE_FZF_STATE")"
t_eq "view::super::fzf: Back returns RETURN_BACK" "$RETURN_BACK" "$(run "$B" shell::ini::view::super::fzf "$ini")"
t_eq "view::control::fzf: Back returns RETURN_BACK" "$RETURN_BACK" "$(run "$B" shell::ini::view::control::fzf "$ini")"
t_eq "edit::fzf: Back at sections returns RETURN_BACK" "$RETURN_BACK" "$(run "$B" shell::ini::edit::fzf "$ini")"
t_eq "edit::fzf: key Back returns to sections, then Back leaves" "$RETURN_BACK" "$(run "dev
$B
$B" shell::ini::edit::fzf "$ini")"
t_eq "edit::fzf: nothing changed" "$before" "$(cat "$ini")"
t_eq "edit::fzf: ESC keeps rc 0" "0" "$(run "" shell::ini::edit::fzf "$ini")"
