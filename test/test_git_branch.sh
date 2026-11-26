#!/usr/bin/env bash
# The branch group of the Git toolkit: pick, recent, cleanup, compare.
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
t_setup
. "$SHELL_TEST_ROOT/test/support/git_toolkit.sh"
_shell::git::core::boot

# run <function> [args...]: stdout in $OUT, stderr in $ERR, status in $RC (stdin closed: never a terminal)
run() {
	OUT="$("$@" 2>"$HOME/err" </dev/null)"
	RC=$?
	ERR="$(cat "$HOME/err")"
}
esc="$(printf '\033')"

gt_init "$HOME/repo"
gt_commit "base" base.txt
git branch merged-old
git branch -- "feature/a-b"
git branch -- "ünï-merged"
git branch develop
git checkout -q -b unmerged
gt_commit "unmerged work" unmerged.txt
git checkout -q main
gt_commit "second on main" second.txt
git branch merged-new
gt_fake_fzf

# ---------------------------------------------------------------- pick
run shell::git::branch::pick -h
t_eq "pick -h: usage on stdout, exit 0" "0" "$RC"
t_has "pick -h: names the function" "shell::git::branch::pick" "$OUT"
run shell::git::branch::pick main
t_eq "pick <name>: validated and printed" "main" "$OUT"
t_eq "pick <name>: exit 0" "0" "$RC"
run shell::git::branch::pick nope
t_eq "pick <unknown>: exit 1" "1" "$RC"
t_eq "pick <unknown>: nothing on stdout" "" "$OUT"
run shell::git::branch::pick -- -rf
t_eq "pick -- -rf: a dash name never reaches git (1)" "1" "$RC"
run shell::git::branch::pick --bogus
t_eq "pick: unknown option is 2" "2" "$RC"

OUT="$(FAKE_FZF_PICKS="feature/a-b" shell::git::branch::pick 2>"$HOME/err")"
t_eq "pick: interactive returns the raw ref, not the row" "feature/a-b" "$OUT"
t_eq "pick: exit 0" "0" "$?"
plain="$(cat "$FAKE_FZF_DIR/plain.1")"
t_has "pick: rows carry the short hash" "$(git rev-parse --short main)" "$plain"
t_has "pick: rows carry the subject" "second on main" "$plain"
t_eq "pick: the current branch is marked" "1" "$(tr '\037' '|' <"$FAKE_FZF_DIR/plain.1" | grep -c '^main|\* main')"
t_eq "pick: no ANSI under NO_COLOR / non-TTY" "0" "$(grep -c "$esc" "$FAKE_FZF_DIR/stdin.1")"
t_has "pick: hidden first field + ansi + preview reach fzf" "--with-nth=2.." "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "pick: preview is a bounded log of the focused ref" "--max-count=30 {1}" "$(cat "$FAKE_FZF_DIR/args.1")"
t_eq "pick: newest commit first" "main" "$(head -n 1 "$FAKE_FZF_DIR/stdin.1" | cut -d"$(printf '\037')" -f1)"

gt_fake_fzf
OUT="$(FAKE_FZF_PICKS="" shell::git::branch::pick 2>/dev/null)"
RC=$?
t_eq "pick: esc is exit 5" "5" "$RC"
t_eq "pick: esc prints nothing" "" "$OUT"

OUT="$(SHELL_GIT_FORCE_FZF='' shell::git::branch::pick 2>"$HOME/err" </dev/null)"
RC=$?
t_eq "pick: no terminal and no argument is exit 2" "2" "$RC"
t_has "pick: ...with a hint" "argument" "$(cat "$HOME/err")"

mkdir "$HOME/notrepo"
(cd "$HOME/notrepo" && run shell::git::branch::pick && exit "$RC")
t_eq "pick: not a repository is 3" "3" "$?"

# numbered fallback (no fzf)
gt_input 1
OUT="$(SHELL_GIT_FORCE_FZF='' shell::git::branch::pick 2>"$HOME/err")"
t_eq "pick fallback: number 1 is the newest branch" "main" "$OUT"
_shell::git::core::input_close
t_has "pick fallback: the list is on stderr" "second on main" "$(cat "$HOME/err")"
unset SHELL_GIT_INPUT

# remote / local scopes and the gone flag
gt_remote origin
git push -q origin feature/a-b 2>/dev/null
git branch -q --set-upstream-to=origin/feature/a-b feature/a-b
git push -q origin --delete feature/a-b 2>/dev/null
git fetch -q --prune origin
gt_fake_fzf
FAKE_FZF_PICKS="@first" shell::git::branch::pick >/dev/null 2>&1
t_has "pick: remote-tracking branches are listed" "origin/main" "$(cat "$FAKE_FZF_DIR/plain.1")"
t_has "pick: a deleted upstream shows the gone flag" "gone" "$(grep 'feature/a-b' "$FAKE_FZF_DIR/plain.1")"
gt_fake_fzf
FAKE_FZF_PICKS="@first" shell::git::branch::pick --local >/dev/null 2>&1
t_eq "pick --local: no remote-tracking row" "0" "$(grep -c 'origin/' "$FAKE_FZF_DIR/plain.1")"
gt_fake_fzf
FAKE_FZF_PICKS="@first" shell::git::branch::pick --remote >/dev/null 2>&1
t_eq "pick --remote: only remote-tracking rows" "1" "$(wc -l <"$FAKE_FZF_DIR/plain.1" | tr -d ' ')"
git push -q origin main 2>/dev/null

# detached HEAD, empty and bare repositories
git checkout -q --detach
gt_fake_fzf
run env FAKE_FZF_PICKS=main true
OUT="$(FAKE_FZF_PICKS="main" shell::git::branch::pick 2>/dev/null)"
t_eq "pick: works on a detached HEAD" "main" "$OUT"
git checkout -q main
gt_init "$HOME/empty"
run shell::git::branch::pick -l
t_eq "pick: an empty repository has no branch (1)" "1" "$RC"
git clone -q --bare "$HOME/repo" "$HOME/bare.git" 2>/dev/null
OUT="$(cd "$HOME/bare.git" && FAKE_FZF_PICKS="main" shell::git::branch::pick 2>/dev/null)"
t_eq "pick: works in a bare repository" "main" "$OUT"
cd "$HOME/repo" || exit 1

# constant git-call count
count_calls() { # <n branches>
	gt_init "$HOME/many$1"
	gt_commit c
	local i=0
	while [ "$i" -lt "$1" ]; do
		git update-ref "refs/heads/b$i" HEAD
		i=$((i + 1))
	done
	gt_fake_fzf
	gt_git_counter on
	FAKE_FZF_PICKS="@first" shell::git::branch::pick >/dev/null 2>&1
	gt_count
	gt_git_counter off
}
c20="$(count_calls 20)"
c200="$(count_calls 200)"
t_eq "pick: same number of git calls for 20 and 200 branches" "$c20" "$c200"
t_eq "pick: ONE for-each-ref call" "1" "$(
	gt_init "$HOME/one"
	gt_commit c
	gt_git_counter on
	FAKE_FZF_PICKS="@first" shell::git::branch::pick >/dev/null 2>&1
	gt_count for-each-ref
	gt_git_counter off
)"
cd "$HOME/repo" || exit 1

# ---------------------------------------------------------------- recent
git checkout -q merged-old
git checkout -q unmerged
git checkout -q main
git checkout -q unmerged
git checkout -q main
run shell::git::branch::recent --list
t_eq "recent --list: most recent first, no duplicate" "main
unmerged
merged-old" "$(printf '%s\n' "$OUT" | head -n 3)"
git branch -q -D merged-old
run shell::git::branch::recent --list
t_lacks "recent: deleted branches are not listed" "merged-old" "$OUT"
run shell::git::branch::recent --list --count 1
t_eq "recent --count 1" "main" "$OUT"
run shell::git::branch::recent --count 0
t_eq "recent: bad count is 2" "2" "$RC"
OUT="$(FAKE_FZF_PICKS="unmerged" shell::git::branch::recent 2>/dev/null)"
t_eq "recent: interactive pick" "unmerged" "$OUT"
OUT="$(SHELL_GIT_FORCE_FZF='' shell::git::branch::recent 2>/dev/null </dev/null)"
t_eq "recent: no terminal and no --list is 2" "2" "$?"
OUT="$(FAKE_FZF_PICKS="" shell::git::branch::recent 2>/dev/null)"
t_eq "recent: esc is 5" "5" "$?"
git branch merged-old main~1 2>/dev/null
git checkout -q --detach
git checkout -q main
run shell::git::branch::recent --list
t_lacks "recent: a detached hash is not a branch" "HEAD" "$OUT"
(cd "$HOME/notrepo" && run shell::git::branch::recent --list && exit "$RC")
t_eq "recent: not a repository is 3" "3" "$?"
rcount() {
	gt_init "$HOME/rc$1"
	gt_commit c
	local i=0
	while [ "$i" -lt "$1" ]; do
		git checkout -q -b "r$i"
		git checkout -q main
		i=$((i + 1))
	done
	gt_git_counter on
	shell::git::branch::recent --list >/dev/null 2>&1
	gt_count
	gt_git_counter off
}
t_eq "recent: same number of git calls for 5 and 40 checkouts" "$(rcount 5)" "$(rcount 40)"
cd "$HOME/repo" || exit 1

# ---------------------------------------------------------------- cleanup
git checkout -q main
git worktree add -q "$HOME/wt" -b in-worktree 2>/dev/null
snap="$(gt_snapshot)"
run shell::git::branch::cleanup -n --all
t_eq "cleanup -n: exit 0" "0" "$RC"
t_eq "cleanup -n: executes nothing" "$snap" "$(gt_snapshot)"
t_has "cleanup -n: prints the exact command" "git branch -d -- merged-new" "$OUT"
t_has "cleanup -n: unicode name" "git branch -d -- ünï-merged" "$OUT"
t_lacks "cleanup: the base is never a candidate" "-- main" "$OUT"
t_lacks "cleanup: a protected name is never a candidate" "-- develop" "$OUT"
t_lacks "cleanup: a branch checked out in a worktree is excluded" "in-worktree" "$OUT"
t_lacks "cleanup: an unmerged branch is excluded" "unmerged" "$OUT"
t_lacks "cleanup: never -D" "-D" "$OUT"
git checkout -q merged-new
run shell::git::branch::cleanup -n --all
t_lacks "cleanup: the current branch is excluded" "merged-new" "$OUT"
git checkout -q main

run shell::git::branch::cleanup --all
t_eq "cleanup --all without terminal and without --yes: 2" "2" "$RC"
t_eq "cleanup: ...nothing deleted" "$snap" "$(gt_snapshot)"

gt_input n
OUT="$(shell::git::branch::cleanup --all 2>"$HOME/err")"
t_eq "cleanup: declined is exit 5" "5" "$?"
_shell::git::core::input_close
t_eq "cleanup: declined leaves the repository identical" "$snap" "$(gt_snapshot)"
t_has "cleanup: the summary lists the targets" "merged-new" "$(cat "$HOME/err")"
t_has "cleanup: the summary warns about squash merges" "Squash-merged" "$(cat "$HOME/err")"
unset SHELL_GIT_INPUT

run shell::git::branch::cleanup -- -rf
t_eq "cleanup: an invalid name is 2" "2" "$RC"
run shell::git::branch::cleanup -- unmerged
t_eq "cleanup: an unmerged branch is not a candidate (2)" "2" "$RC"
run shell::git::branch::cleanup -- main
t_eq "cleanup: the base is not a candidate (2)" "2" "$RC"
run shell::git::branch::cleanup --base nope --all
t_eq "cleanup: unknown base is 1" "1" "$RC"
run shell::git::branch::cleanup --bogus
t_eq "cleanup: unknown option is 2" "2" "$RC"

# interactive multi-select
gt_fake_fzf
gt_input y
OUT="$(FAKE_FZF_PICKS="feature/a-b
merged-new" shell::git::branch::cleanup 2>"$HOME/err")"
t_eq "cleanup: interactive deletes the selection" "feature/a-b
merged-new" "$OUT"
_shell::git::core::input_close
t_eq "cleanup: the selected branches are gone" "0" "$(git branch --list feature/a-b merged-new | wc -l | tr -d ' ')"
t_eq "cleanup: the others are still there" "1" "$(git branch --list 'ünï-merged' | wc -l | tr -d ' ')"
t_has "cleanup: multi-select was requested" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
unset SHELL_GIT_INPUT
snap="$(gt_snapshot)"
OUT="$(FAKE_FZF_PICKS="" shell::git::branch::cleanup 2>/dev/null)"
t_eq "cleanup: esc is 5" "5" "$?"
t_eq "cleanup: esc changes nothing" "$snap" "$(gt_snapshot)"

# --yes deletes without asking, reports what git refuses (a branch not merged into HEAD)
git checkout -q --orphan elsewhere
gt_commit "unrelated root" lone.txt
run shell::git::branch::cleanup --yes -- 'ünï-merged'
t_eq "cleanup --yes: git -d refuses a branch HEAD does not contain (1)" "1" "$RC"
t_has "cleanup: the refusal is reported" "git refused" "$ERR"
t_eq "cleanup: ...and the branch is kept (never -D)" "1" "$(git branch --list 'ünï-merged' | wc -l | tr -d ' ')"
git checkout -q main
run shell::git::branch::cleanup --yes -- 'ünï-merged'
t_eq "cleanup --yes: deletes" "ünï-merged" "$OUT"
t_eq "cleanup --yes: exit 0" "0" "$RC"
run shell::git::branch::cleanup --all --yes
t_eq "cleanup: after all that nothing left but exit 0" "0" "$RC"
t_eq "cleanup: no ANSI on stdout or stderr" "0" "$(printf '%s%s' "$OUT" "$ERR" | grep -c "$esc")"
git worktree remove --force "$HOME/wt" 2>/dev/null
(cd "$HOME/notrepo" && run shell::git::branch::cleanup --all --yes && exit "$RC")
t_eq "cleanup: not a repository is 3" "3" "$?"

# ---------------------------------------------------------------- compare
cd "$HOME/repo" || exit 1
git checkout -q main
git checkout -q -b cmp-a
gt_commit "a1" "with space.txt"
gt_commit "a2" "tab	name.txt"
git mv base.txt renamed.txt 2>/dev/null
git commit -q -m "rename"
git checkout -q main
git checkout -q -b cmp-b
gt_commit "b1" "only-b.txt"
git checkout -q main
run shell::git::branch::compare cmp-a cmp-b
t_eq "compare: exit 0" "0" "$RC"
t_has "compare: ahead/behind" "cmp-a vs cmp-b: 3 ahead, 1 behind" "$OUT"
t_has "compare: commits only in a" "a1" "$OUT"
t_has "compare: commits only in b" "b1" "$OUT"
t_has "compare: a file with a space" "with space.txt" "$OUT"
t_has "compare: a file with a tab" "tab	name.txt" "$OUT"
t_has "compare: a rename shows both paths" "renamed.txt -> base.txt" "$OUT"
t_eq "compare: report on stdout only" "" "$ERR"
run shell::git::branch::compare cmp-a
t_has "compare <a>: against the current branch (main)" "cmp-a vs main" "$OUT"
run shell::git::branch::compare cmp-a nope
t_eq "compare: unknown ref is 1" "1" "$RC"
run shell::git::branch::compare -- -x main
t_eq "compare: a dash ref never reaches git (1)" "1" "$RC"
run shell::git::branch::compare --limit 0 cmp-a cmp-b
t_eq "compare: bad limit is 2" "2" "$RC"
run shell::git::branch::compare cmp-a cmp-b extra
t_eq "compare: too many arguments is 2" "2" "$RC"
run shell::git::branch::compare cmp-a cmp-b --limit 1
t_eq "compare --limit 1: one commit per side at most" "1" "$(printf '%s\n' "$OUT" | sed -n '/only in cmp-a/,/only in cmp-b/p' | grep -c '^  [0-9a-f]\{7,\} ')"
OUT="$(SHELL_GIT_FORCE_FZF='' shell::git::branch::compare 2>/dev/null </dev/null)"
t_eq "compare: no argument and no terminal is 2" "2" "$?"
gt_fake_fzf
OUT="$(FAKE_FZF_PICKS="cmp-a
---
cmp-b" shell::git::branch::compare 2>/dev/null)"
t_has "compare: both branches picked interactively" "cmp-a vs " "$OUT"
snap="$(gt_snapshot)"
OUT="$(FAKE_FZF_PICKS="" shell::git::branch::compare 2>/dev/null)"
t_eq "compare: esc is 5" "5" "$?"
t_eq "compare: read-only" "$snap" "$(gt_snapshot)"
OUT="$(cd "$HOME/bare.git" && shell::git::branch::compare main merged-old 2>/dev/null)"
t_has "compare: works in a bare repository" "main vs merged-old" "$OUT"
(cd "$HOME/notrepo" && run shell::git::branch::compare a b && exit "$RC")
t_eq "compare: not a repository is 3" "3" "$?"
gt_git_counter on
shell::git::branch::compare cmp-a cmp-b >/dev/null 2>&1
n1="$(gt_count)"
gt_git_counter off
cd "$HOME/many200" || exit 1
git branch -q x HEAD
gt_commit more
gt_git_counter on
shell::git::branch::compare x main >/dev/null 2>&1
n2="$(gt_count)"
gt_git_counter off
t_eq "compare: the same number of git calls on another repository" "$n1" "$n2"

t_done
