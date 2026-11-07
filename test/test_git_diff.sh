#!/usr/bin/env bash
# shell::git::diff::fzf on a throwaway repo. fzf is faked: call 1 picks FAKE_FZF_ROW (a
# line number of the list), later calls exit 130 (ESC). Stdin and arguments are recorded.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

mkdir "$HOME/bin"
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
n="$(cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0)"
n=$((n + 1)); echo "$n" >"$FAKE_FZF_STATE"
cat >"$FAKE_FZF_DIR/stdin.$n"
printf '%s\n' "$@" >"$FAKE_FZF_DIR/args.$n"
[ "$n" -gt 1 ] && exit 130
[ -z "$FAKE_FZF_ROW" ] && exit 130
sed -n "${FAKE_FZF_ROW}p" "$FAKE_FZF_DIR/stdin.$n"
FAKE
chmod +x "$HOME/bin/fzf"
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_FZF_ROW=""
reset_fzf() { find "$HOME" -maxdepth 1 \( -name "stdin.*" -o -name "args.*" -o -name fzf.count \) -exec rm -f {} +; }

mkdir "$HOME/repo" && cd "$HOME/repo" || exit 1
git init -q . && git config user.email t@t && git config user.name t
printf 'one\n' >a.txt && printf 'x\n' >b.txt && printf 'gone\n' >c.txt && printf 'ren\n' >old.txt
git add . && git commit -q -m init
printf 'two\n' >>a.txt
git rm -q c.txt
git mv old.txt new.txt
printf 'fresh\n' >d.txt && git add d.txt
git commit -q -am second

# --- a commit: list, statuses, overview
reset_fzf
t_rc "commit: runs" 0 shell::git::diff::fzf HEAD
list="$(cat "$HOME/stdin.1")"
t_has "list: overview row first" "Overview" "$(printf '%s' "$list" | sed -n 1p)"
t_has "list: modified" "M  a.txt" "$list"
t_has "list: added" "A  d.txt" "$list"
t_has "list: deleted" "D  c.txt" "$list"
t_has "list: renamed" "R  old.txt → new.txt" "$list"
t_eq "list: overview + 4 files + back" "6" "$(printf '%s\n' "$list" | grep -c .)"
args="$(cat "$HOME/args.1")"
t_has "list: back entry is last" "Back" "$(printf '%s' "$list" | tail -n 1)"
t_has "header counts" "4 file(s): 1 added, 1 modified, 1 deleted, 1 renamed" "$args"
t_has "preview shows the file diff" "diff --color=never" "$args"
t_has "preview has the stat for the overview" "--stat" "$args"
t_lacks "no colour off a terminal" "\033[" "$list"

# --- selecting a file shows its diff (output is not a terminal: plain, no pager)
reset_fzf
FAKE_FZF_ROW=2
t_rc "select: file diff" 0 shell::git::diff::fzf HEAD
t_has "select: shows the change" "+two" "$T_OUT"
t_eq "select: list comes back until ESC" "2" "$(cat "$HOME/fzf.count")"
reset_fzf
FAKE_FZF_ROW=1
t_rc "select: overview" 0 shell::git::diff::fzf HEAD
t_has "overview: diffstat" "4 files changed" "$T_OUT"
FAKE_FZF_ROW=""

# --- Back entry: leaves with RETURN_BACK (11), no diff shown
reset_fzf
FAKE_FZF_ROW=6
t_rc "back: returns RETURN_BACK" 11 shell::git::diff::fzf HEAD
t_has "back: says so" "Back" "$T_OUT"
t_eq "back: list not reopened" "1" "$(cat "$HOME/fzf.count")"
reset_fzf
FAKE_FZF_ROW=""
FAKE_FZF_ROW=""

# --- root commit: the empty tree is the parent
reset_fzf
root="$(git rev-list --max-parents=0 HEAD)"
t_rc "root commit" 0 shell::git::diff::fzf "$root"
t_has "root: files are added" "A  a.txt" "$(cat "$HOME/stdin.1")"

# --- range, staged, working tree, errors
reset_fzf
t_rc "range" 0 shell::git::diff::fzf "$root..HEAD"
t_has "range: lists files" "M  a.txt" "$(cat "$HOME/stdin.1")"
printf 'wip\n' >>b.txt
reset_fzf
t_rc "uncommitted by default" 0 shell::git::diff::fzf
t_has "uncommitted: lists b.txt" "M  b.txt" "$(cat "$HOME/stdin.1")"
git add b.txt
reset_fzf
t_rc "staged" 0 shell::git::diff::fzf --staged
t_has "staged: lists b.txt" "M  b.txt" "$(cat "$HOME/stdin.1")"
git reset -q --hard
t_rc "clean tree" 0 shell::git::diff::fzf
t_has "clean tree: message" "No changed files" "$T_OUT"
t_rc "bad commit" 1 shell::git::diff::fzf nope-ref
t_rc "unknown option" 2 shell::git::diff::fzf --bogus
t_rc "dry run" 0 shell::git::diff::fzf -n HEAD
t_has "dry run: command" "diff --name-status" "$T_OUT"
t_rc "pick: ESC aborts" 0 shell::git::diff::fzf --pick
reset_fzf
FAKE_FZF_ROW=3
t_rc "pick: Back entry" 11 shell::git::diff::fzf --pick
t_has "pick: back entry is offered last" "Back" "$(tail -n 1 "$HOME/stdin.1")"
# --- new (untracked) files are listed, and the diff works from a subdirectory
git reset -q --hard
mkdir -p sub && printf 'in sub\n' >sub/s.txt && git add sub/s.txt && git commit -q -m sub
printf 'more\n' >>sub/s.txt
printf 'brand new\n' >sub/fresh.txt
reset_fzf
t_rc "untracked: runs" 0 shell::git::diff::fzf
t_has "untracked: modified file is listed" "M  sub/s.txt" "$(cat "$HOME/stdin.1")"
t_has "untracked: new file is listed" "?  sub/fresh.txt" "$(cat "$HOME/stdin.1")"
t_has "untracked: counted as added" "1 added, 1 modified" "$(cat "$HOME/args.1")"
reset_fzf
shell::git::diff::fzf HEAD >/dev/null 2>&1
t_lacks "untracked: not part of a commit view" "fresh.txt" "$(cat "$HOME/stdin.1")"
reset_fzf
FAKE_FZF_ROW=2
(cd sub && shell::git::diff::fzf >"$HOME/out.txt" 2>&1)
t_has "subdirectory: the modified file's diff is shown" "+more" "$(cat "$HOME/out.txt")"
reset_fzf
FAKE_FZF_ROW=3
(cd sub && shell::git::diff::fzf >"$HOME/out.txt" 2>&1)
t_has "subdirectory: the new file's diff is shown" "+brand new" "$(cat "$HOME/out.txt")"
FAKE_FZF_ROW=""
t_done
