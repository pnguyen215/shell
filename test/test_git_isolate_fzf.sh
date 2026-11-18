#!/usr/bin/env bash
# shell::git::isolate (src/lang/git_isolate.sh + git_isolate_fzf.sh): the persistent session.
# source branch -> target strategy -> ONE branch + ONE worktree -> action menu that keeps looping
# (Pick Files / Pick Commit / Pick Lines / Switch Source Branch / Back), and the original checkout never changes.
# fzf is a fake: the Nth call picks, for each text of the Nth line of $FAKE_FZF_PICKS (texts separated by
# ";"), the first candidate line containing it; an empty line is ESC. $FAKE_FZF_HOOK (eval'ed) runs at call
# $FAKE_FZF_HOOK_AT. Confirmations and typed names come from stdin.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

mkdir "$HOME/bin"
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
n="$(cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0)"
n=$((n + 1))
echo "$n" >"$FAKE_FZF_STATE"
cat >"$FAKE_FZF_DIR/stdin.$n"
[ "$n" = "${FAKE_FZF_HOOK_AT-}" ] && eval "$FAKE_FZF_HOOK"
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

run() { # <picks> <stdin> [args...] -> exit status; output in out.log
	rm -f "$FAKE_FZF_STATE"
	find "$FAKE_FZF_DIR" -name "stdin.*" -delete
	printf '%s' "$2" | FAKE_FZF_PICKS="$1" shell::git::isolate "${@:3}" >"$HOME/out.log" 2>&1
	echo "$?"
}
calls() { cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0; }
sessions() { git branch --list 'isolate/session/*' | wc -l | tr -d ' '; }
wt_of() { git worktree list --porcelain | awk -v b="refs/heads/$1" '/^worktree /{w=substr($0,10)} $0=="branch " b{print w}'; }
only_session_branch() { git branch --list 'isolate/session/*' --format='%(refname:short)' | head -n 1; }
drop() { # <branch>: remove a session's worktree and branch
	local d
	d="$(wt_of "$1")"
	[ -n "$d" ] && git worktree remove --force "$d"
	git branch -q -D "$1" 2>/dev/null
	return 0
}

R="$HOME/repo"
git init -q "$R" && cd "$R" || exit 1
git checkout -q -b main 2>/dev/null
seq 1 6 | sed 's/^/l/' >a.txt
printf 'keep\n' >b.txt
git add -A && git commit -q -m base
BASE="$(git rev-parse HEAD)"
git checkout -q -b feature
sed -i.bak 's/^l2$/L2/;s/^l5$/L5/' a.txt && rm a.txt.bak
printf 'new\n' >n.txt
printf 'spaced\n' >"d d.txt"
git add -A && git commit -q -m "feature work"
git checkout -q main
git checkout -q -b other
printf 'other\n' >o.txt
git add -A && git commit -q -m "other work"
git checkout -q main
git checkout -q -b conf
sed -i.bak 's/^l2$/X2/' a.txt && rm a.txt.bak
git add -A && git commit -q -m "conf change"
git checkout -q main
git checkout -q -b mrg
git merge -q --no-ff -m "Merge feature into mrg" feature
git checkout -q main
# the user's own work in the checkout, and an extra worktree
printf 'wip\n' >>a.txt
printf 'staged\n' >>b.txt && git add b.txt
printf 'u\n' >untracked.txt
git branch extra && git worktree add -q "$HOME/extra-wt" extra
snap() {
	{
		git rev-parse HEAD
		git symbolic-ref HEAD
		git ls-files -s
		git status --porcelain=v1 --untracked-files=all
		git diff
		cat a.txt b.txt untracked.txt
		git for-each-ref --format='%(refname) %(objectname)' | grep -v 'refs/heads/\(isolate\|my\|c-dest\|m-dest\|conf-dest\)'
		git worktree list --porcelain | awk -v RS= -v ORS="\n\n" '$0 ~ /extra-wt/ || $0 ~ /\/repo\n/'
	} 2>&1
}
before="$(snap)"

# --- entry: source branch first, ESC and Back --------------------------------------------------
t_eq "ESC at the source list closes" "0" "$(run "" "")"
t_eq "Back at the source list returns 11" "11" "$(run "$B" "")"
t_ok "the source list marks the current branch" grep -q "main (current)" "$FAKE_FZF_DIR/stdin.1"
t_eq "nothing was created yet" "0" "$(sessions)"
t_eq "unknown argument" "2" "$(run "" "" --nope)"

# --- strategy screen: Back returns to the source list; dry-run creates nothing -------------------
t_eq "Back at the strategy returns to the source list, then ESC" "0" "$(run "$(printf 'feature\n%s\n\n' "$B")" "")"
t_ok "the strategy list offers both strategies" grep -q "Create new branch from a parent branch" "$FAKE_FZF_DIR/stdin.2"
t_eq "the source list came back" "3" "$(calls)"
t_eq "dry-run prints the command and creates nothing" "0" "$(run "$(printf 'feature\nApply to current\n')" "" -n)"
t_ok "dry-run printed the worktree command" grep -q "git worktree add" "$HOME/out.log"
t_eq "dry-run: no branch" "0" "$(sessions)"

# --- Option A: one session, every action, the menu keeps coming back ------------------------------
# calls: 1 source, 2 strategy, 3 menu, 4 files, 5 menu, 6 file, 7 lines, 8 menu, 9 branch, 10 menu, 11 commit, 12 menu (ESC)
PICKS="$(printf 'feature\nApply to current\nPick Files\nn.txt;d d.txt\nPick Lines\na.txt\n    2  L2\nSwitch Source\nother\nPick Commit\nother work\n\n')"
t_eq "full session exits with ESC" "0" "$(run "$PICKS" "y
y
y
")"
t_eq "twelve fzf screens in one session" "12" "$(calls)"
t_eq "the action menu appeared five times" "5" "$(grep -l 'Pick Files' "$FAKE_FZF_DIR"/stdin.* | wc -l | tr -d ' ')"
t_eq "exactly one session branch" "1" "$(sessions)"
sb="$(only_session_branch)"
sd="$(wt_of "$sb")"
t_ok "the branch is distinguishable from main" test "$sb" != "main"
t_ok "the worktree exists" test -d "$sd"
case "$sd" in "$R"/*) t_ok "worktree outside the repo" false ;; *) t_ok "worktree outside the repo" true ;; esac
t_eq "files picked" "new" "$(cat "$sd/n.txt")"
t_eq "file with a space picked" "spaced" "$(cat "$sd/d d.txt")"
t_eq "lines picked: line 2 only" "L2 l5" "$(printf '%s %s' "$(sed -n 2p "$sd/a.txt")" "$(sed -n 5p "$sd/a.txt")")"
t_eq "commit picked from the switched source" "other" "$(cat "$sd/o.txt")"
t_eq "three actions, three commits on the destination" "3" "$(git rev-list --count "$BASE..$sb")"
t_eq "a single worktree was added" "3" "$(git worktree list | wc -l | tr -d ' ')"
t_eq "the destination has no pending changes" "" "$(git -C "$sd" status --porcelain)"
t_eq "the original checkout is untouched" "$before" "$(snap)"
t_ok "the summary names the worktree" grep -q "Worktree: $sd" "$HOME/out.log"
t_ok "the worktree survives the end of the session" test -d "$sd"
t_eq "main was not modified" "$BASE" "$(git rev-parse main)"
drop "$sb"

# Back leaves with 11 and keeps the destination
t_eq "Back exits with 11" "11" "$(run "$(printf 'feature\nApply to current\nPick Files\nn.txt\n%s\n' "$B")" "y
")"
sb="$(only_session_branch)"
sd="$(wt_of "$sb")"
t_eq "Back keeps the worktree" "new" "$(cat "$sd/n.txt")"
t_eq "the original checkout is untouched after Back" "$before" "$(snap)"
drop "$sb"

# repeated selection of applied content: nothing new is committed, the session goes on
t_eq "the same file twice" "0" "$(run "$(printf 'feature\nApply to current\nPick Files\nn.txt\nPick Files\nn.txt\n\n')" "y
y
")"
t_eq "the second pick adds nothing" "1" "$(git rev-list --count "$BASE..$(only_session_branch)")"
t_ok "it was reported as already applied" grep -q "already identical" "$HOME/out.log"
drop "$(only_session_branch)"

# --- cancelling a picker returns to the menu; an empty session offers (never forces) cleanup -------
t_eq "cancelled pickers return to the menu" "0" "$(run "$(printf 'feature\nApply to current\nPick Files\n\nPick Commit\n\n\n')" "n
")"
t_eq "the menu was shown three times" "3" "$(grep -l 'Pick Commit' "$FAKE_FZF_DIR"/stdin.* | wc -l | tr -d ' ')"
t_eq "an empty session keeps its worktree when you answer no" "1" "$(sessions)"
drop "$(only_session_branch)"
run "$(printf 'feature\nApply to current\n\n')" "y
" >/dev/null
t_eq "an empty session is removed on an explicit yes" "0" "$(sessions)"
t_eq "the original checkout is untouched after cancellations" "$before" "$(snap)"

# --- Option B: parent branch, typed name, validation --------------------------------------------------
t_eq "parent strategy with a typed name" "11" "$(run "$(printf 'feature\nCreate new branch\nmain (current)\nPick Files\nn.txt\n%s\n' "$B")" "my/new-br
y
")"
t_ok "the named branch exists" git show-ref --verify --quiet refs/heads/my/new-br
t_eq "it starts at the parent plus the picked file" "new" "$(git show my/new-br:n.txt)"
t_eq "the parent is unchanged" "$BASE" "$(git rev-parse main)"
t_eq "the original checkout is untouched (option B)" "$before" "$(snap)"
drop my/new-br

run "$(printf 'feature\nCreate new branch\nmain (current)\n%s\n' "$B")" "bad name~
other
my/ok
" >/dev/null
t_ok "an invalid name is reported" grep -q "not a valid branch name" "$HOME/out.log"
t_ok "an existing name is reported" grep -q "already exists" "$HOME/out.log"
t_ok "the valid name was used" git show-ref --verify --quiet refs/heads/my/ok
t_ok "the existing branch kept its commit" test "$(git rev-parse other)" != "$BASE"
drop my/ok

t_eq "an empty name generates one" "0" "$(run "$(printf 'feature\nCreate new branch\nmain (current)\n\n')" "
n
")"
t_ok "a generated name was used" test "$(sessions)" = "1"
drop "$(only_session_branch)"
t_eq "Back at the parent list returns to the strategy" "0" "$(run "$(printf 'feature\nCreate new branch\n%s\n\n' "$B")" "")"

# --- conflicts and merge commits are reported, the destination stays clean, the menu continues ----------
t_eq "a conflicting commit does not end the session" "11" "$(run "$(printf 'feature\nCreate new branch\nconf\nPick Commit\nfeature work\n%s\n' "$B")" "conf-dest
y
")"
cs="$(wt_of conf-dest)"
t_ok "the conflict is reported" grep -q "does not apply cleanly" "$HOME/out.log"
t_eq "the destination is restored" "" "$(git -C "$cs" status --porcelain)"
t_eq "no commit was added" "0" "$(git rev-list --count "conf..conf-dest")"
t_eq "the menu came back after the failure" "6" "$(calls)"
drop conf-dest

t_eq "a merge commit is refused" "11" "$(run "$(printf 'mrg\nCreate new branch\nmain (current)\nPick Commit\nMerge feature\n%s\n' "$B")" "m-dest
")"
t_ok "the merge commit is explained" grep -q "merge commit" "$HOME/out.log"
t_eq "nothing was applied for the merge commit" "0" "$(git rev-list --count "main..m-dest")"
drop m-dest

t_eq "an overwrite is declined" "11" "$(run "$(printf 'feature\nCreate new branch\nconf\nPick Files\na.txt\n%s\n' "$B")" "c-dest
n
")"
t_ok "the file conflict is reported" grep -q "Conflict: a.txt" "$HOME/out.log"
t_eq "a declined overwrite changes nothing" "X2" "$(sed -n 2p "$(wt_of c-dest)/a.txt")"
drop c-dest
run "$(printf 'feature\nCreate new branch\nconf\nPick Files\na.txt\n%s\n' "$B")" "c-dest
y
" >/dev/null
t_eq "a confirmed overwrite applies the file" "L2" "$(sed -n 2p "$(wt_of c-dest)/a.txt")"
drop c-dest

# --- the destination worktree vanishing ends the session safely ------------------------------------------
cat >"$HOME/bin/hook.sh" <<'HOOK'
#!/bin/sh
d="$(git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' | grep '/iso/' | head -n 1)"
[ -n "$d" ] && rm -rf "$d"
HOOK
export FAKE_FZF_HOOK_AT=4 FAKE_FZF_HOOK="sh $HOME/bin/hook.sh"
t_eq "a vanished worktree stops the session with a failure" "1" "$(run "$(printf 'feature\nApply to current\nPick Files\n\nPick Files\n')" "")"
t_ok "it is explained" grep -q "no longer available" "$HOME/out.log"
unset FAKE_FZF_HOOK_AT FAKE_FZF_HOOK
git worktree prune
for b in $(git branch --list 'isolate/*' --format='%(refname:short)'); do git branch -q -D "$b"; done
t_eq "the original checkout is untouched after everything" "$before" "$(snap)"
t_eq "the extra worktree and branch are intact" "extra" "$(git -C "$HOME/extra-wt" rev-parse --abbrev-ref HEAD)"

cd "$HOME" || exit 1
t_eq "outside a repository" "1" "$(run "" "")"

t_done
