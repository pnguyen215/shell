#!/usr/bin/env bash
# shell::git::manage::fzf (src/lang/git_manage.sh): the area list -> action menu -> list loop,
# the "← Back" entry, dry-run flag forwarding and the repository check.
# fzf is a fake: the Nth call picks the line of $FAKE_FZF_PICKS that matches text (an empty pick is ESC).
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
export TERM=dumb

# Stubs record what the hub calls.
CALLS="$HOME/calls.log"
shell::git::diff::fzf() { echo "diff $*" >>"$CALLS"; }
shell::git::branch::merge::fzf() { echo "merge $*" >>"$CALLS"; }

run() {
	rm -f "$FAKE_FZF_STATE" "$CALLS"
	FAKE_FZF_PICKS="$1" "${@:2}" >"$HOME/out.log" 2>&1
	echo "$?"
}

# Outside a repository.
t_eq "not a repository fails" "1" "$(run "" shell::git::manage::fzf)"
t_eq "unknown argument is invalid" "2" "$(run "" shell::git::manage::fzf --nope)"

git init -q "$HOME/repo" && cd "$HOME/repo" || exit 1
git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init

t_eq "ESC at the area list closes" "0" "$(run "" shell::git::manage::fzf)"
t_eq "Back at the area list returns 11" "11" "$(run "$B" shell::git::manage::fzf)"

printf 'branch\ncommit\ntag\nstash\ndiff\nconfig\npatch\n%s\n' "$B" >"$HOME/want"
run "" shell::git::manage::fzf >/dev/null
t_eq "area list" "$(cat "$HOME/want")" "$(cut -f1 "$FAKE_FZF_DIR/stdin.1")"

# diff -> staged, then the list comes back, then ESC.
t_eq "action runs and the list returns" "0" "$(run "$(printf 'diff\nstaged\ndiff\n')" shell::git::manage::fzf)"
t_eq "staged action forwarded" "diff --staged" "$(cat "$CALLS")"
t_eq "list shown again after the action" "4" "$(cat "$FAKE_FZF_STATE")"

# dry-run is forwarded; Back at the action menu returns to the list without running anything.
run "$(printf 'branch\nmerge\n')" shell::git::manage::fzf -n >/dev/null
t_eq "dry-run forwarded" "merge -n" "$(cat "$CALLS")"
run "$(printf 'branch\n%s\n' "$B")" shell::git::manage::fzf >/dev/null
t_eq "Back at the action menu runs nothing" "" "$(cat "$CALLS" 2>/dev/null)"

t_done
