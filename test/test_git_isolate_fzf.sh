#!/usr/bin/env bash
# shell::git::isolate::fzf (src/lang/git_isolate_fzf.sh): mode -> source branch -> commit / files / lines
# -> preview -> confirm. fzf is a fake: the Nth call picks, for each text of the Nth line of
# $FAKE_FZF_PICKS (texts separated by ";"), the first candidate line containing it; an empty pick is ESC.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

mkdir "$HOME/bin"
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
n="$(cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0)"
n=$((n + 1))
echo "$n" >"$FAKE_FZF_STATE"
cat >"$FAKE_FZF_DIR/stdin.$n"
printf '%s\n' "$@" >"$FAKE_FZF_DIR/args.$n"
line="$(printf '%s\n' "$FAKE_FZF_PICKS" | sed -n "${n}p")"
[ -z "$line" ] && exit 130
printf '%s\n' "$line" | tr ';' '\n' | while IFS= read -r pick; do
	grep -F -- "$pick" "$FAKE_FZF_DIR/stdin.$n" | head -n 1
done
FAKE
chmod +x "$HOME/bin/fzf"
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME/fzfdir" FAKE_FZF_STATE="$HOME/fzf.count"
mkdir "$FAKE_FZF_DIR"
B="$SHELL_FZF_BACK_LABEL"
export TERM=dumb SHELL_GIT_ISOLATE_DIR="$HOME/iso"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

run() { # <picks> <answers> -> exit status
	rm -f "$FAKE_FZF_STATE"
	find "$FAKE_FZF_DIR" -name "stdin.*" -delete
	printf '%s' "$2" | FAKE_FZF_PICKS="$1" shell::git::isolate::fzf "${@:3}" >"$HOME/out.log" 2>&1
	echo "$?"
}
isos() { git branch --list 'isolate/*' | wc -l | tr -d ' '; }

R="$HOME/repo"
git init -q "$R" && cd "$R" || exit 1
git checkout -q -b main 2>/dev/null
seq 1 6 | sed 's/^/l/' >a.txt
git add -A && git commit -q -m base
git checkout -q -b feature
sed -i.bak 's/^l2$/L2/;s/^l5$/L5/' a.txt && rm a.txt.bak
printf 'new\n' >n.txt
git add -A && git commit -q -m "feature work"
git checkout -q main
printf 'wip\n' >>a.txt
printf 'u\n' >untracked.txt
snap() { {
	git rev-parse HEAD
	git status --porcelain=v1 --untracked-files=all
	git diff
} 2>&1; }
before="$(snap)"

t_eq "ESC at the mode list closes" "0" "$(run "" "")"
t_eq "Back at the mode list returns 11" "11" "$(run "$B" "")"
printf 'commit\nfile\nlines\n%s\n' "$B" >"$HOME/want_modes"
run "" "" >/dev/null
t_eq "mode list" "$(cat "$HOME/want_modes")" "$(cut -f2 "$FAKE_FZF_DIR/stdin.1" | tr -d '@' | sed 's/^back$/'"$B"'/')"

# commit: mode, branch, commit, confirm
t_eq "commit: yes creates a branch" "0" "$(run "$(printf 'commit\nfeature\nfeature work\n')" "y
")"
t_eq "commit: one new branch" "1" "$(isos)"
t_eq "commit: branch rows list local branches" "1" "$(grep -c '^feature' "$FAKE_FZF_DIR/stdin.2")"
t_eq "commit: the checkout is untouched" "$before" "$(snap)"

# commit: answering no changes nothing
t_eq "commit: no creates nothing" "0" "$(run "$(printf 'commit\nfeature\nfeature work\n\n')" "n
")"
t_eq "commit: still one branch" "1" "$(isos)"

# file: pick the changed file (marked), confirm -> new branch
t_eq "file: yes" "0" "$(run "$(printf 'file\nfeature\nn.txt\n')" "y
")"
t_eq "file: two branches" "2" "$(isos)"
t_ok "file: changed files are listed first" test "$(sed -n 1p "$FAKE_FZF_DIR/stdin.3" | cut -c1)" != "="
t_eq "file: the checkout is untouched" "$before" "$(snap)"
fb="$(git branch --list 'isolate/file/*' --format='%(refname:short)' | head -n 1)"
t_eq "file: only n.txt retrieved" "n.txt" "$(git -C "$(git worktree list --porcelain | awk -v b="refs/heads/$fb" '/^worktree /{w=substr($0,10)} $0=="branch " b{print w}')" diff --cached --name-only)"

# lines: mode, branch, file, marked lines, confirm
t_eq "lines: yes" "0" "$(run "$(printf 'lines\nfeature\na.txt\n    2  L2\n')" "y
")"
t_eq "lines: three branches" "3" "$(isos)"
lb="$(git branch --list 'isolate/lines/*' --format='%(refname:short)' | head -n 1)"
ldir="$(git worktree list --porcelain | awk -v b="refs/heads/$lb" '/^worktree /{w=substr($0,10)} $0=="branch " b{print w}')"
t_eq "lines: only line 2 changed" "L2 l5" "$(printf '%s %s' "$(sed -n 2p "$ldir/a.txt")" "$(sed -n 5p "$ldir/a.txt")")"
t_eq "lines: the checkout is untouched" "$before" "$(snap)"
t_ok "lines: the line preview uses the file" grep -q "SHELL_GIT_ISOLATE_PREVIEW_PATH" "$FAKE_FZF_DIR/args.4"

# Back at the source list returns to the mode list; dry-run creates nothing
t_eq "Back at the branch list loops, ESC then closes" "0" "$(run "$(printf 'commit\n%s\n' "$B")" "")"
t_eq "dry-run creates nothing" "0" "$(run "$(printf 'file\nfeature\nn.txt\n')" "y
" -n)"
t_eq "dry-run: still three branches" "3" "$(isos)"
t_ok "dry-run: prints the worktree command" grep -q "git worktree add" "$HOME/out.log"
t_eq "unknown argument" "2" "$(run "" "" --nope)"
cd "$HOME" || exit 1
t_eq "outside a repository" "1" "$(run "" "")"

t_done
