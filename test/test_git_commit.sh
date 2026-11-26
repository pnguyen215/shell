#!/usr/bin/env bash
# The commit group of the Git toolkit: shell::git::commit::{pick,fixup,squash,revert}.
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
t_setup
. "$SHELL_TEST_ROOT/test/support/git_toolkit.sh"
_shell::git::core::boot
gt_fake_fzf

# run <cmd...>: non-interactive (no terminal, no scripted input); sets RC OUT ERR
run() {
	(
		unset SHELL_GIT_FORCE_FZF SHELL_GIT_INPUT
		"$@" >"$HOME/out" 2>"$HOME/err" </dev/null
		echo $? >"$HOME/rc"
	)
	RC="$(cat "$HOME/rc")"
	OUT="$(cat "$HOME/out")"
	ERR="$(cat "$HOME/err")"
}
# run_i <cmd...>: interactive through the fake fzf / scripted input (call gt_input first); sets RC OUT ERR
run_i() {
	"$@" >"$HOME/out" 2>"$HOME/err" </dev/null
	RC=$?
	OUT="$(cat "$HOME/out")"
	ERR="$(cat "$HOME/err")"
	_shell::git::core::input_close
	unset SHELL_GIT_INPUT
	_SHELL_GIT_INPUT_OPEN=""
}
# mk: fresh repository with commits first..fourth (file1..file4)
mk() {
	cd "$HOME" || return 1
	rm -rf "$HOME/repo" "$HOME/origin.git"
	gt_init "$HOME/repo"
	gt_commit first
	gt_commit second
	gt_commit third
	gt_commit fourth
}
hash_of() { git log --format='%H %s' | awk -v s="$1" '$2 == s { print $1 }'; }
is_hash() { case "$1" in *[!0-9a-f]* | "") echo no ;; *) [ "${#1}" -eq 40 ] && echo yes || echo no ;; esac }
seq_leftovers() { find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'shell-git-seq.*' | wc -l | tr -d ' '; }
ansi="$(printf '\033')"

# ============================ commit::pick ============================
mk
t_rc "pick: -h is exit 0" 0 shell::git::commit::pick -h
run shell::git::commit::pick HEAD~1
t_eq "pick: an explicit revision resolves to a full hash" "$(git rev-parse HEAD~1)" "$OUT"
t_eq "pick: nothing on stderr for a plain resolve" "" "$ERR"
run shell::git::commit::pick HEAD HEAD~2
t_eq "pick: several revisions, one hash per line" "$(git rev-parse HEAD)
$(git rev-parse HEAD~2)" "$OUT"
run shell::git::commit::pick nope
t_eq "pick: an unknown revision is 2" "2" "$RC"
t_eq "pick: ...and prints nothing on stdout" "" "$OUT"
run shell::git::commit::pick -x
t_eq "pick: an unknown option is 2" "2" "$RC"
git update-ref refs/heads/-rf HEAD
run shell::git::commit::pick -- -rf
t_eq "pick: a branch named -rf is never read as an option (2)" "2" "$RC"
t_eq "pick: ...and is left alone" "1" "$(git for-each-ref refs/heads/-rf | wc -l | tr -d ' ')"
git update-ref -d refs/heads/-rf
run shell::git::commit::pick --max abc
t_eq "pick: --max must be a number (2)" "2" "$RC"
run shell::git::commit::pick
t_eq "pick: no terminal and no argument is 2" "2" "$RC"
t_has "pick: ...with a hint" "argument" "$ERR"
t_eq "pick: ...and nothing on stdout" "" "$OUT"

FAKE_FZF_PICKS="second" run_i shell::git::commit::pick
t_eq "pick (fzf): the picked commit's hash" "$(hash_of second)" "$OUT"
t_eq "pick (fzf): stdout is the hash only" "yes" "$(is_hash "$OUT")"
t_has "pick (fzf): the record list has the subject" "second" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_eq "pick (fzf): newest commit first" "fourth" "$(sed -n 1p "$FAKE_FZF_DIR/stdin.1" | awk -F'  ' '{ print $NF }')"
t_eq "pick (fzf): 4 records for 4 commits" "4" "$(wc -l <"$FAKE_FZF_DIR/stdin.1" | tr -d ' ')"
t_eq "pick (fzf): no ANSI under NO_COLOR" "0" "$(grep -c "$ansi" "$FAKE_FZF_DIR/stdin.1")"
t_has "pick (fzf): the preview is bounded and lazy" "head -n 60" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "pick (fzf): hidden raw field" "--with-nth=2.." "$(cat "$FAKE_FZF_DIR/args.1")"
FAKE_FZF_PICKS="@all" run_i shell::git::commit::pick --multi
t_eq "pick --multi: every selection" "4" "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')"
FAKE_FZF_PICKS="@all" run_i shell::git::commit::pick --max 2
t_eq "pick --max 2: only 2 records are listed" "2" "$(wc -l <"$FAKE_FZF_DIR/stdin.$(cat "$FAKE_FZF_DIR/count")" | tr -d ' ')"
FAKE_FZF_PICKS="" run_i shell::git::commit::pick
t_eq "pick: esc is 5" "5" "$RC"
t_eq "pick: esc prints nothing" "" "$OUT"
# numbered fallback (fzf hidden)
oldpath="$PATH"
PATH="$(printf '%s' "$PATH" | sed "s|$HOME/gt-bin:||")"
_SHELL_GIT_VER_FZF=0
unset SHELL_GIT_FORCE_FZF
gt_input 2
run_i shell::git::commit::pick
t_eq "pick (numbered): the second line is the second newest" "$(hash_of third)" "$OUT"
t_has "pick (numbered): the list is on stderr" "fourth" "$ERR"
PATH="$oldpath"
export SHELL_GIT_FORCE_FZF=1
_SHELL_GIT_VER_FZF=""

# non-repo, empty, bare, detached, linked worktree
mkdir -p "$HOME/plain" && cd "$HOME/plain" || exit 1
run shell::git::commit::pick HEAD
t_eq "pick: not a repository is 3" "3" "$RC"
git init -q --bare "$HOME/bare.git" && cd "$HOME/bare.git" || exit 1
run shell::git::commit::pick HEAD
t_eq "pick: a bare repository is 3" "3" "$RC"
mkdir -p "$HOME/emptyrepo" && cd "$HOME/emptyrepo" && git init -q . && git symbolic-ref HEAD refs/heads/main
FAKE_FZF_PICKS="@all" run_i shell::git::commit::pick
t_eq "pick: an empty repository is 1" "1" "$RC"
mk
git checkout -q --detach HEAD~1
FAKE_FZF_PICKS="first" run_i shell::git::commit::pick
t_eq "pick: works on a detached HEAD" "$(hash_of first)" "$OUT"
git checkout -q main
git worktree add -q "$HOME/wt" -b wtbranch >/dev/null 2>&1
cd "$HOME/wt" || exit 1
FAKE_FZF_PICKS="third" run_i shell::git::commit::pick
t_eq "pick: works in a linked worktree" "$(git rev-parse HEAD~1)" "$OUT"
cd "$HOME/repo" || exit 1

# constant number of git calls: 20 commits vs 2000
big() { # dir n
	gt_init "$1"
	local i=1 m
	{
		while [ "$i" -le "$2" ]; do
			m="c$i"
			printf 'commit refs/heads/main\ncommitter T <t@e.com> %d +0000\ndata %d\n%s\n' $((1577880000 + i)) "${#m}" "$m"
			i=$((i + 1))
		done
	} | git fast-import --quiet
	git reset -q --hard main
}
big "$HOME/small" 20
gt_git_counter on
FAKE_FZF_PICKS="@first" run_i shell::git::commit::pick
n_small="$(gt_count)"
l_small="$(gt_count log)"
big "$HOME/large" 2000
gt_git_counter off
gt_git_counter on
FAKE_FZF_PICKS="@first" run_i shell::git::commit::pick --max 5000
n_large="$(gt_count)"
l_large="$(gt_count log)"
t_eq "pick: ONE git log call for 20 commits" "1" "$l_small"
t_eq "pick: ONE git log call for 2000 commits" "1" "$l_large"
t_eq "pick: the same number of git calls for 20 and 2000 commits" "$n_small" "$n_large"
t_eq "pick: 2000 records reached the picker" "2000" "$(wc -l <"$FAKE_FZF_DIR/stdin.$(cat "$FAKE_FZF_DIR/count")" | tr -d ' ')"
gt_git_counter off

# ============================ commit::fixup ============================
mk
printf 'more\n' >>file2.txt
git add file2.txt
S0="$(gt_snapshot)"
run shell::git::commit::fixup -n "$(hash_of second)"
t_eq "fixup -n: exit 0" "0" "$RC"
t_has "fixup -n: prints the fixup commit command" "git commit --fixup=" "$OUT"
t_has "fixup -n: prints the rebase command" "rebase -i --autosquash" "$OUT"
t_has "fixup -n: prints the backup command" "update-ref" "$OUT"
t_eq "fixup -n: executes nothing" "$S0" "$(gt_snapshot)"
run shell::git::commit::fixup "$(hash_of second)"
t_eq "fixup: no terminal and no --yes is 2" "2" "$RC"
t_eq "fixup: ...and changes nothing" "$S0" "$(gt_snapshot)"
gt_input n
run_i shell::git::commit::fixup "$(hash_of second)"
t_eq "fixup: a declined confirmation is 5" "5" "$RC"
t_eq "fixup: ...and the repository is identical" "$S0" "$(gt_snapshot)"
old_head="$(git rev-parse HEAD)"
old_second="$(hash_of second)"
run shell::git::commit::fixup -y "$old_second"
t_eq "fixup -y: success" "0" "$RC"
t_eq "fixup: stdout is the new HEAD" "$(git rev-parse HEAD)" "$OUT"
t_eq "fixup: still 4 commits (the fixup commit was folded in)" "4" "$(git rev-list --count HEAD)"
t_eq "fixup: the change is in the second commit" "1" "$(git show "$(hash_of second)":file2.txt | grep -c more)"
t_eq "fixup: the working tree is clean afterwards" "0 0 0 0" "$(_shell::git::core::tree_counts)"
ref="$(git for-each-ref --format='%(refname)' refs/shell-backup/fixup | head -n 1)"
t_has "fixup: a backup ref exists" "refs/shell-backup/fixup/" "$ref"
t_eq "fixup: the backup ref holds the old HEAD" "$old_head" "$(git rev-parse "$ref")"
t_has "fixup: the restore command is printed" "git reset --hard $ref" "$ERR"
git reset -q --hard "$ref"
t_eq "fixup: restoring the backup recovers the old history" "$old_head" "$(git rev-parse HEAD)"

mk
run shell::git::commit::fixup -y "$(hash_of second)"
t_eq "fixup: nothing staged is 1" "1" "$RC"
t_has "fixup: ...and says so" "nothing is staged" "$ERR"
printf 'staged\n' >>file2.txt
git add file2.txt
printf 'unstaged\n' >>file3.txt
S0="$(gt_snapshot)"
run shell::git::commit::fixup -y "$(hash_of second)"
t_eq "fixup: unstaged changes block it (7)" "7" "$RC"
t_eq "fixup: ...and nothing changed" "$S0" "$(gt_snapshot)"
run shell::git::commit::fixup -y --autostash "$(hash_of second)"
t_eq "fixup --autostash: success" "0" "$RC"
t_eq "fixup --autostash: the unstaged change is back" "1" "$(grep -c unstaged file3.txt)"
t_eq "fixup --autostash: the staged change went into the second commit" "1" "$(git show "$(hash_of second)":file2.txt | grep -c staged)"

mk
printf 'x\n' >>file1.txt
git add file1.txt
run shell::git::commit::fixup -y "$(hash_of first)"
t_eq "fixup: into the root commit (--root path)" "0" "$RC"
t_eq "fixup: ...folded in" "1" "$(git show "$(hash_of first)":file1.txt | grep -c x)"
t_eq "fixup: ...history length kept" "4" "$(git rev-list --count HEAD)"

mk
printf 'x\n' >>file2.txt
git add file2.txt
run shell::git::commit::fixup -y nope
t_eq "fixup: an unknown commit is 2" "2" "$RC"
run shell::git::commit::fixup -y -z
t_eq "fixup: an unknown option is 2" "2" "$RC"
side="$(GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@e GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@e git commit-tree -p "$(git rev-parse HEAD~3)" -m side "$(git rev-parse 'HEAD~3^{tree}')")"
t_eq "fixup: the unrelated commit exists" "yes" "$(is_hash "$side")"
run shell::git::commit::fixup -y "$side"
t_eq "fixup: a commit that is not an ancestor of HEAD is 2" "2" "$RC"
t_has "fixup: ...and says why" "not an ancestor" "$ERR"

# interactive pick of the target
mk
printf 'p\n' >>file3.txt
git add file3.txt
gt_input y
FAKE_FZF_PICKS="third" run_i shell::git::commit::fixup
t_eq "fixup (fzf): picked target, confirmed with y" "0" "$RC"
t_eq "fixup (fzf): folded into the picked commit" "1" "$(git show "$(hash_of third)":file3.txt | grep -c p)"
mk
printf 'p\n' >>file3.txt
git add file3.txt
S0="$(gt_snapshot)"
FAKE_FZF_PICKS="" run_i shell::git::commit::fixup
t_eq "fixup (fzf): esc is 5" "5" "$RC"
t_eq "fixup (fzf): ...and nothing changed" "$S0" "$(gt_snapshot)"
run shell::git::commit::fixup
t_eq "fixup: no commit, no terminal is 2" "2" "$RC"

# conflict: folding a change of the first commit's line past a later edit of the same line
cd "$HOME" && rm -rf "$HOME/repo" && gt_init "$HOME/repo"
gt_commit one f.txt "line"
gt_commit two f.txt "changed"
printf 'again\n' >f.txt
git add f.txt
run shell::git::commit::fixup -y "$(hash_of one)"
t_eq "fixup: a conflicting rebase is 6" "6" "$RC"
t_has "fixup: ...with the --continue command" "git rebase --continue" "$ERR"
t_has "fixup: ...and the --abort command" "git rebase --abort" "$ERR"
t_eq "fixup: the rebase is really in progress" "rebase" "$(_shell::git::core::operation)"
S0="$(gt_snapshot)"
run shell::git::commit::fixup -y "$(hash_of one)"
t_eq "fixup: a second rewrite during the rebase is 7" "7" "$RC"
git rebase --abort >/dev/null 2>&1
t_eq "fixup: after --abort no operation remains" "" "$(_shell::git::core::operation)"

# merge commits and pushed commits
cd "$HOME" && rm -rf "$HOME/repo" "$HOME/origin.git" && gt_init "$HOME/repo"
gt_commit base
git checkout -q -b side
gt_commit sidework
git checkout -q main
gt_commit mainwork
git merge -q --no-ff -m merged side >/dev/null 2>&1
gt_commit aftermerge
printf 'm\n' >>file1.txt
git add file1.txt
S0="$(gt_snapshot)"
run shell::git::commit::fixup -y "$(hash_of base)"
t_eq "fixup: a range with a merge commit is refused without a terminal (2)" "2" "$RC"
t_has "fixup: ...naming --allow-merges" "--allow-merges" "$ERR"
t_eq "fixup: ...and nothing changed" "$S0" "$(gt_snapshot)"
gt_input n
run_i shell::git::commit::fixup -y "$(hash_of base)"
t_eq "fixup: declining the merge-commit question is 5" "5" "$RC"
t_eq "fixup: ...and nothing changed" "$S0" "$(gt_snapshot)"
git reset -q
git checkout -q -- .

mk
gt_remote origin
printf 'push\n' >>file2.txt
git add file2.txt
run shell::git::commit::fixup -y "$(hash_of second)"
t_eq "fixup: rewriting pushed commits still works with -y" "0" "$RC"
t_has "fixup: ...but warns that they are on a remote branch" "already on a remote branch" "$ERR"
t_has "fixup: ...and that --force-with-lease will be needed" "--force-with-lease" "$ERR"

# ============================ commit::squash ============================
mk
old_head="$(git rev-parse HEAD)"
S0="$(gt_snapshot)"
run shell::git::commit::squash -n 3
t_eq "squash -n: exit 0" "0" "$RC"
t_has "squash -n: prints the rebase command" "git rebase -i" "$OUT"
t_has "squash -n: prints the backup command" "update-ref" "$OUT"
t_eq "squash -n: executes nothing" "$S0" "$(gt_snapshot)"
t_eq "squash -n: leaves no helper script behind" "0" "$(seq_leftovers)"
for bad in 1 9 abc; do
	run shell::git::commit::squash -y "$bad"
	t_eq "squash: count '$bad' is refused (2)" "2" "$RC"
done
run shell::git::commit::squash -y -z
t_eq "squash: an unknown option is 2" "2" "$RC"
run shell::git::commit::squash 3
t_eq "squash: no terminal and no --yes is 2" "2" "$RC"
t_eq "squash: ...and changes nothing" "$S0" "$(gt_snapshot)"
gt_input n
run_i shell::git::commit::squash 3
t_eq "squash: a declined confirmation is 5" "5" "$RC"
t_eq "squash: ...and the repository is identical" "$S0" "$(gt_snapshot)"
run shell::git::commit::squash -y 3
t_eq "squash -y 3: success" "0" "$RC"
t_eq "squash: stdout is the new HEAD" "$(git rev-parse HEAD)" "$OUT"
t_eq "squash: two commits left" "2" "$(git rev-list --count HEAD)"
t_eq "squash: the oldest message survives" "second" "$(git log -1 --format=%s)"
t_eq "squash: all three files are in the result" "3" "$(git ls-tree --name-only HEAD | grep -c 'file[234]')"
ref="$(git for-each-ref --format='%(refname)' refs/shell-backup/squash | head -n 1)"
t_eq "squash: the backup ref holds the old HEAD" "$old_head" "$(git rev-parse "$ref")"
t_has "squash: the restore command is printed" "git reset --hard $ref" "$ERR"
t_eq "squash: the helper script is removed" "0" "$(seq_leftovers)"
git reset -q --hard "$ref"
t_eq "squash: restoring the backup recovers the old history" "4" "$(git rev-list --count HEAD)"
run shell::git::commit::squash -y -m "all together" "$(hash_of second)"
t_eq "squash -m: success from a commit hash" "0" "$RC"
t_eq "squash -m: the new message" "all together" "$(git log -1 --format=%s)"
t_eq "squash -m: the range started at the given commit (first + squashed)" "2" "$(git rev-list --count HEAD)"
git reset -q --hard "$ref"
run shell::git::commit::squash -y "$(hash_of first)"
t_eq "squash: including the root commit (--root path)" "0" "$RC"
t_eq "squash: ...one commit left" "1" "$(git rev-list --count HEAD)"
t_eq "squash: ...with the root message" "first" "$(git log -1 --format=%s)"
git reset -q --hard "$ref"
printf 'dirty\n' >>file1.txt
S0="$(gt_snapshot)"
run shell::git::commit::squash -y 2
t_eq "squash: a dirty tree blocks it (7)" "7" "$RC"
t_eq "squash: ...and nothing changed" "$S0" "$(gt_snapshot)"
run shell::git::commit::squash -y --autostash 2
t_eq "squash --autostash: success" "0" "$RC"
t_eq "squash --autostash: the change is back in the tree" "1" "$(grep -c dirty file1.txt)"
git checkout -q -- file1.txt
git reset -q --hard "$ref"
# interactive pick of the oldest commit
gt_input y
FAKE_FZF_PICKS="third" run_i shell::git::commit::squash
t_eq "squash (fzf): picked the oldest commit" "0" "$RC"
t_eq "squash (fzf): third..fourth squashed" "3" "$(git rev-list --count HEAD)"
git reset -q --hard "$ref"
S0="$(gt_snapshot)"
FAKE_FZF_PICKS="" run_i shell::git::commit::squash
t_eq "squash (fzf): esc is 5" "5" "$RC"
t_eq "squash (fzf): ...nothing changed" "$S0" "$(gt_snapshot)"
run shell::git::commit::squash
t_eq "squash: nothing given and no terminal is 2" "2" "$RC"
# in the middle of an operation
git checkout -q -b ca HEAD~1
gt_commit ca clash.txt a
git checkout -q -b cb HEAD~1
gt_commit cb clash.txt b
git merge ca >/dev/null 2>&1
S0="$(gt_snapshot)"
run shell::git::commit::squash -y 2
t_eq "squash: an operation in progress blocks it (7)" "7" "$RC"
t_has "squash: ...and says how to leave it" "git merge --abort" "$ERR"
git merge --abort
git checkout -q main
git branch -q -D ca cb
# merge commits and pushed commits
cd "$HOME" && rm -rf "$HOME/repo" "$HOME/origin.git" && gt_init "$HOME/repo"
gt_commit base
git checkout -q -b side
gt_commit sidework
git checkout -q main
gt_commit mainwork
git merge -q --no-ff -m merged side >/dev/null 2>&1
gt_commit aftermerge
S0="$(gt_snapshot)"
run shell::git::commit::squash -y 4
t_eq "squash: a range with a merge commit is refused without a terminal (2)" "2" "$RC"
t_eq "squash: ...nothing changed" "$S0" "$(gt_snapshot)"
gt_input n
run_i shell::git::commit::squash -y 4
t_eq "squash: declining the merge-commit question is 5" "5" "$RC"
t_eq "squash: ...nothing changed" "$S0" "$(gt_snapshot)"
mk
gt_remote origin
run shell::git::commit::squash -y 2
t_eq "squash: rewriting pushed commits works with -y" "0" "$RC"
t_has "squash: ...with the pushed-commit warning" "already on a remote branch" "$ERR"
cd "$HOME/plain" || exit 1
run shell::git::commit::squash -y 2
t_eq "squash: not a repository is 3" "3" "$RC"
cd "$HOME/emptyrepo" || exit 1
run shell::git::commit::squash -y 2
t_eq "squash: an empty repository is 1" "1" "$RC"
cd "$HOME/repo" || exit 1

# ============================ commit::revert ============================
mk
S0="$(gt_snapshot)"
run shell::git::commit::revert -n "$(hash_of third)"
t_eq "revert -n: exit 0" "0" "$RC"
t_has "revert -n: prints the command" "git revert --no-edit $(hash_of third)" "$OUT"
t_eq "revert -n: executes nothing" "$S0" "$(gt_snapshot)"
run shell::git::commit::revert "$(hash_of third)"
t_eq "revert: no terminal and no --yes is 2" "2" "$RC"
t_eq "revert: ...and changes nothing" "$S0" "$(gt_snapshot)"
gt_input n
run_i shell::git::commit::revert "$(hash_of third)"
t_eq "revert: a declined confirmation is 5" "5" "$RC"
t_eq "revert: ...and the repository is identical" "$S0" "$(gt_snapshot)"
run shell::git::commit::revert -y "$(hash_of third)"
t_eq "revert -y: success" "0" "$RC"
t_eq "revert: stdout is the new HEAD" "$(git rev-parse HEAD)" "$OUT"
t_eq "revert: a Revert commit on top" 'Revert "third"' "$(git log -1 --format=%s)"
t_eq "revert: file3 is gone again" "0" "$(ls file3.txt 2>/dev/null | wc -l | tr -d ' ')"
run shell::git::commit::revert -y nope
t_eq "revert: an unknown commit is 2" "2" "$RC"
run shell::git::commit::revert -y -z
t_eq "revert: an unknown option is 2" "2" "$RC"
run shell::git::commit::revert -y
t_eq "revert: nothing given and no terminal is 2" "2" "$RC"

mk
run shell::git::commit::revert -y "$(hash_of second)" "$(hash_of fourth)"
t_eq "revert: two commits given oldest-first" "0" "$RC"
t_eq "revert: two Revert commits on top" 'Revert "second"
Revert "fourth"' "$(git log -2 --format=%s)"
t_eq "revert: both files are gone" "0" "$(ls file2.txt file4.txt 2>/dev/null | wc -l | tr -d ' ')"
mk
gt_input y
FAKE_FZF_PICKS="third
second" run_i shell::git::commit::revert
t_eq "revert (fzf): multi-select, confirmed" "0" "$RC"
t_has "revert (fzf): --multi reaches fzf" "--multi" "$(cat "$FAKE_FZF_DIR/args.$(cat "$FAKE_FZF_DIR/count")")"
t_eq "revert (fzf): two Revert commits, newest commit reverted first" 'Revert "second"
Revert "third"' "$(git log -2 --format=%s)"
S0="$(gt_snapshot)"
FAKE_FZF_PICKS="" run_i shell::git::commit::revert
t_eq "revert (fzf): esc is 5" "5" "$RC"
t_eq "revert (fzf): ...nothing changed" "$S0" "$(gt_snapshot)"

# dirty tree and operation in progress
mk
printf 'd\n' >>file1.txt
S0="$(gt_snapshot)"
run shell::git::commit::revert -y "$(hash_of third)"
t_eq "revert: a dirty tree blocks it (7)" "7" "$RC"
t_eq "revert: ...nothing changed" "$S0" "$(gt_snapshot)"
git checkout -q -- file1.txt

# conflicts
cd "$HOME" && rm -rf "$HOME/repo" && gt_init "$HOME/repo"
gt_commit one f.txt "1"
gt_commit two f.txt "2"
gt_commit three f.txt "3"
gt_commit four g.txt "g"
run shell::git::commit::revert -y "$(hash_of two)" "$(hash_of one)"
t_eq "revert: a conflict is 6" "6" "$RC"
t_has "revert: ...with the --continue command" "git revert --continue" "$ERR"
t_has "revert: ...and the --abort command" "git revert --abort" "$ERR"
t_has "revert: ...and the commits not applied yet" "not applied yet" "$ERR"
t_eq "revert: the operation is really in progress" "revert" "$(_shell::git::core::operation)"
run shell::git::commit::revert -y "$(hash_of one)"
t_eq "revert: another revert during it is 7" "7" "$RC"
git revert --abort >/dev/null 2>&1
t_eq "revert: after --abort the tree is clean" "0 0 0 0" "$(_shell::git::core::tree_counts)"

# merge commits need a parent number
cd "$HOME" && rm -rf "$HOME/repo" && gt_init "$HOME/repo"
gt_commit base
git checkout -q -b side
gt_commit sidework
git checkout -q main
gt_commit mainwork
git merge -q --no-ff -m merged side >/dev/null 2>&1
merge="$(git rev-parse HEAD)"
S0="$(gt_snapshot)"
run shell::git::commit::revert -y "$merge"
t_eq "revert: a merge commit without --mainline is 2" "2" "$RC"
t_has "revert: ...naming --mainline" "--mainline" "$ERR"
t_eq "revert: ...nothing changed" "$S0" "$(gt_snapshot)"
run shell::git::commit::revert -n --mainline 1 "$merge"
t_has "revert -n: the -m option is in the command" "-m 1" "$OUT"
gt_input 1 y
run_i shell::git::commit::revert "$merge"
t_eq "revert: the parent number is asked on a terminal" "0" "$RC"
t_eq "revert: the merge was reverted" 'Revert "merged"' "$(git log -1 --format=%s)"
git reset -q --hard "$merge"
run shell::git::commit::revert -y --mainline 1 "$merge"
t_eq "revert --mainline 1 -y: success" "0" "$RC"
run shell::git::commit::revert -y --mainline x "$merge"
t_eq "revert: a bad --mainline is 2" "2" "$RC"

cd "$HOME/plain" || exit 1
run shell::git::commit::revert -y HEAD
t_eq "revert: not a repository is 3" "3" "$RC"
cd "$HOME/emptyrepo" || exit 1
run shell::git::commit::revert -y HEAD
t_eq "revert: an empty repository is 1" "1" "$RC"

# ---- design checks
t_eq "design: one public function per commit action file" "4" "$(grep -c '^shell::git::commit::[a-z]*() {' "$SHELL_TEST_ROOT"/src/lang/git/commit/{pick,fixup,squash,revert}.sh | awk -F: '{ s += $2 } END { print s }')"
t_eq "design: no --no-verify anywhere (hooks are never skipped)" "0" "$(grep -rh -e '--no-verify' "$SHELL_TEST_ROOT/src/lang/git/commit" "$SHELL_TEST_ROOT/src/lang/git/flow" | wc -l | tr -d ' ')"
t_eq "design: no reset --hard or clean or plain force push in the code" "0" "$(grep -rhE 'git_rw (reset --hard|clean|push)|--force( |$)' "$SHELL_TEST_ROOT/src/lang/git/commit" "$SHELL_TEST_ROOT/src/lang/git/flow" | grep -vE '^[[:space:]]*#' | wc -l | tr -d ' ')"

t_done
