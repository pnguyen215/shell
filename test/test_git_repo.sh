#!/usr/bin/env bash
# shell::git::repo::{health,stats,size,summary} on throwaway repositories (stdout is never a terminal here,
# so every report runs in its plain, tab-separated mode).
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
t_setup
. "$SHELL_TEST_ROOT/test/support/git_toolkit.sh"

# val <key> <report>: the value of a `key<TAB>value` row
val() { printf '%s\n' "$2" | awk -F'\t' -v k="$1" '$1 == k { print $2; exit }'; }

# live_repo <name>: a repository whose commits are dated now (so nothing is stale), with an origin
live_repo() {
	rm -rf "${HOME:?}/$1" "$HOME/origin.git"
	mkdir -p "$HOME/$1" && cd "$HOME/$1" || return 1
	git init -q . 2>/dev/null
	git symbolic-ref HEAD refs/heads/main
	git config user.email t@example.com
	git config user.name T
	git config commit.gpgsign false
	git config core.hooksPath /dev/null
	printf 'a\n' >a.txt
	git add a.txt
	git commit -q -m one
	printf 'b\n' >b.txt
	git add b.txt
	git commit -q -m two
	git init -q --bare "$HOME/origin.git" 2>/dev/null
	git remote add origin "$HOME/origin.git"
	git push -q -u origin main 2>/dev/null
}

# ---------------------------------------------------------------- usage and environment
for fn in health stats size summary; do
	t_has "$fn: -h prints usage on stdout" "usage: shell::git::repo::$fn" "$(shell::git::repo::$fn -h)"
	t_rc "$fn: -h exits 0" 0 shell::git::repo::$fn --help
	t_eq "$fn: an unknown option is exit 2" "2" "$(
		shell::git::repo::$fn --nope >/dev/null 2>&1
		echo $?
	)"
done
t_eq "stats: --top needs a number" "2" "$(
	shell::git::repo::stats --top x >/dev/null 2>&1
	echo $?
)"
t_eq "stats: --max needs a value" "2" "$(
	shell::git::repo::stats --max >/dev/null 2>&1
	echo $?
)"
mkdir "$HOME/notrepo" && cd "$HOME/notrepo" || exit 1
for fn in health stats size summary; do
	t_eq "$fn: outside a repository is exit 3" "3" "$(
		shell::git::repo::$fn >/dev/null 2>&1
		echo $?
	)"
	t_eq "$fn: ...and nothing on stdout" "" "$(shell::git::repo::$fn 2>/dev/null)"
done

# ---------------------------------------------------------------- health: healthy
live_repo h1
printf 'scratch\n' >untracked.txt
snap="$(gt_snapshot)"
out="$(shell::git::repo::health 2>"$HOME/h.err")"
rc=$?
t_eq "health: a clean, in-sync repository is healthy (untracked files alone are not a warning)" "0 healthy" "$rc $(val severity "$out")"
t_eq "health: plain rows are key<TAB>value, one per line" "18" "$(printf '%s\n' "$out" | awk -F'\t' 'NF == 2' | wc -l | tr -d ' ')"
t_eq "health: branch" "main" "$(val branch "$out")"
t_eq "health: upstream" "origin/main" "$(val upstream "$out")"
t_eq "health: ahead/behind" "0 0" "$(val ahead "$out") $(val behind "$out")"
t_eq "health: tree counts" "0 0 1 0" "$(val staged "$out") $(val unstaged "$out") $(val untracked "$out") $(val conflicted "$out")"
t_eq "health: branch counts (1 local, 1 remote)" "1 1" "$(val local_branches "$out") $(val remote_branches "$out")"
t_eq "health: stash count" "0" "$(val stash "$out")"
t_eq "health: base branch resolved" "main" "$(val base "$out")"
t_eq "health: operation" "-" "$(val operation "$out")"
t_eq "health: nothing on stderr" "" "$(cat "$HOME/h.err")"
t_eq "health: no ANSI in plain mode" "0" "$(printf '%s' "$out" | grep -c "$(printf '\033')")"
t_eq "health: read-only (repository identical)" "$snap" "$(gt_snapshot)"

# ---------------------------------------------------------------- health: warnings (exit 1)
printf 'x\n' >>a.txt
out="$(shell::git::repo::health 2>/dev/null)"
t_eq "health: uncommitted changes are a warning (exit 1)" "1 warning" "$? $(val severity "$out")"
t_eq "health: ...counted as unstaged" "1" "$(val unstaged "$out")"
shell::git::repo::health >/dev/null 2>&1
t_eq "health: exit status is 1 for warnings" "1" "$?"
git add a.txt
out="$(shell::git::repo::health 2>/dev/null)"
t_eq "health: a staged change is counted as staged" "1 0" "$(val staged "$out") $(val unstaged "$out")"
git commit -q -m "three"
out="$(shell::git::repo::health 2>/dev/null)"
t_eq "health: an unpushed commit is ahead 1 and still healthy" "1 healthy" "$(val ahead "$out") $(val severity "$out")"
git push -q origin main 2>/dev/null

git checkout -q --detach
shell::git::repo::health >/dev/null 2>&1
t_eq "health: detached HEAD is a warning" "1" "$?"
t_eq "health: ...reported as (detached)" "(detached)" "$(val branch "$(shell::git::repo::health 2>/dev/null)")"
git checkout -q main

rm -rf "$HOME/other"
git clone -q "$HOME/origin.git" "$HOME/other" 2>/dev/null
git -C "$HOME/other" checkout -q main 2>/dev/null
git -C "$HOME/other" config user.email o@example.com
git -C "$HOME/other" config user.name O
git -C "$HOME/other" commit -q --allow-empty -m "remote work"
git -C "$HOME/other" push -q origin main 2>/dev/null
git fetch -q
out="$(shell::git::repo::health 2>/dev/null)"
t_eq "health: behind the upstream is a warning with the count" "1 0 warning" "$(val behind "$out") $(val ahead "$out") $(val severity "$out")"
git merge -q --ff-only origin/main 2>/dev/null

git checkout -q -b topic
git push -q -u origin topic 2>/dev/null
git -C "$HOME/other" push -q origin --delete topic 2>/dev/null
git fetch -q --prune
out="$(shell::git::repo::health 2>/dev/null)"
t_eq "health: a gone upstream is a warning" "warning" "$(val severity "$out")"
t_has "health: ...named in the notes" "upstream is gone" "$(val notes "$out")"
git checkout -q main
git branch -q -D topic

# stale branch: an old commit on a non-current branch
git checkout -q -b old-work
GIT_AUTHOR_DATE="2020-01-01T00:00:00" GIT_COMMITTER_DATE="2020-01-01T00:00:00" git commit -q --allow-empty -m "ancient"
git checkout -q main
out="$(shell::git::repo::health 2>/dev/null)"
t_eq "health: a branch older than SHELL_GIT_STALE_DAYS is stale (warning)" "1 warning" "$(val stale "$out") $(val severity "$out")"
out="$(SHELL_GIT_STALE_DAYS=100000 shell::git::repo::health 2>/dev/null)"
t_eq "health: the threshold is configurable" "0" "$(val stale "$out")"
t_eq "health: merged and unmerged against the base (old-work is unmerged)" "0 1" "$(val merged "$out") $(val unmerged "$out")"
git branch -q merged-one main
out="$(shell::git::repo::health 2>/dev/null)"
t_eq "health: a branch at the base tip is merged" "1 1" "$(val merged "$out") $(val unmerged "$out")"
git stash list >/dev/null
printf 'p\n' >>a.txt
git stash -q
out="$(shell::git::repo::health 2>/dev/null)"
t_eq "health: stash count" "1" "$(val stash "$out")"
git stash drop -q
git branch -q -D old-work merged-one

# ---------------------------------------------------------------- health: problems (exit 2)
git checkout -q -b side
printf 'side\n' >clash.txt
git add clash.txt
git commit -q -m side
git checkout -q main
printf 'main\n' >clash.txt
git add clash.txt
git commit -q -m mainside
git merge side >/dev/null 2>&1
snap="$(gt_snapshot)"
out="$(shell::git::repo::health 2>/dev/null)"
t_eq "health: a merge with conflicts is a problem (exit 2)" "2 problem" "$? $(val severity "$out")"
shell::git::repo::health >/dev/null 2>&1
t_eq "health: exit status is 2 for problems" "2" "$?"
t_eq "health: conflicts counted" "1" "$(val conflicted "$out")"
t_eq "health: the operation in progress is named" "merge" "$(val operation "$out")"
t_has "health: the notes say why" "unresolved conflicts" "$(val notes "$out")"
t_eq "health: still read-only in the middle of a merge" "$snap" "$(gt_snapshot)"
git merge --abort
git cherry-pick side >/dev/null 2>&1
out="$(shell::git::repo::health 2>/dev/null)"
t_eq "health: a cherry-pick in progress is a problem" "cherry-pick problem" "$(val operation "$out") $(val severity "$out")"
git cherry-pick --abort 2>/dev/null
git reset -q --hard HEAD 2>/dev/null
git branch -q -D side

# ---------------------------------------------------------------- health: special repositories
rm -rf "$HOME/empty"
mkdir "$HOME/empty" && cd "$HOME/empty" || exit 1
git init -q . 2>/dev/null
git symbolic-ref HEAD refs/heads/main
out="$(shell::git::repo::health 2>/dev/null)"
t_eq "health: an empty repository works (branch main, healthy, no base)" "main healthy -" "$(val branch "$out") $(val severity "$out") $(val base "$out")"
t_eq "health: ...with merged/unmerged unknown" "- -" "$(val merged "$out") $(val unmerged "$out")"

git init -q --bare "$HOME/bare.git" 2>/dev/null
git -C "$HOME/bare.git" symbolic-ref HEAD refs/heads/main
cd "$HOME/bare.git" || exit 1
out="$(shell::git::repo::health 2>/dev/null)"
t_eq "health: a bare repository works (no tree fields)" "0 - -" "$? $(val staged "$out") $(val untracked "$out")"
t_eq "health: ...and has a branch" "main" "$(val branch "$out")"

live_repo w1
git worktree add -q "$HOME/wt1" -b wtb 2>/dev/null
cd "$HOME/wt1" || exit 1
printf 'wt\n' >wt.txt
out="$(shell::git::repo::health 2>/dev/null)"
t_eq "health: works in a linked worktree (own branch, own untracked file)" "wtb 1 2" "$(val branch "$out") $(val untracked "$out") $(val local_branches "$out")"
cd "$HOME/w1" || exit 1

# ---------------------------------------------------------------- constant git-call counts
live_repo perf
for i in $(seq 20); do : >"f$i.txt"; done
for i in $(seq 20); do printf 'create refs/heads/b%d HEAD\n' "$i"; done | git update-ref --stdin
gt_git_counter on
shell::git::repo::health >/dev/null 2>&1
small="$(gt_count)"
gt_git_counter off
rm -f f*.txt
for i in $(seq 2000); do : >"f$i.txt"; done
for i in $(seq 2000); do printf 'create refs/heads/c%d HEAD\n' "$i"; done | git update-ref --stdin
gt_git_counter on
SECONDS=0
shell::git::repo::health >"$HOME/big.out" 2>/dev/null
elapsed=$SECONDS
large="$(gt_count)"
t_eq "health: the same number of git calls for 20 and 2000 changed files / branches" "$small" "$large"
t_eq "health: ONE status call" "1" "$(grep -c 'status --porcelain=v2' "$GT_GIT_LOG")"
t_eq "health: no fsck, no per-branch call (bounded)" "0" "$(grep -c 'fsck' "$GT_GIT_LOG")"
t_eq "health: 2000 files and 2000 branches are counted" "2000 2021" "$(val untracked "$(cat "$HOME/big.out")") $(val local_branches "$(cat "$HOME/big.out")")"
t_eq "health: under 2 seconds on 2000 branches and 2000 changed files" "1" "$([ "$elapsed" -le 2 ] && echo 1 || echo 0)"
gt_git_counter off
rm -f f*.txt

# ---------------------------------------------------------------- stats
rm -rf "$HOME/st"
gt_init "$HOME/st"
i=0
while [ "$i" -lt 6 ]; do
	gt_commit "a$i"
	i=$((i + 1))
done
GT_TICK=$GT_TICK
git -c user.name=Bea -c user.email=bea@example.com commit -q --allow-empty -m b1 --date="2020-03-01T10:00:00"
git -c user.name=Bea -c user.email=bea@example.com commit -q --allow-empty -m b2 --date="2020-03-02T10:00:00"
git -c user.name=Cy -c user.email=cy@example.com commit -q --allow-empty -m c1 --date="2020-02-01T10:00:00"
gt_git_counter on
out="$(shell::git::repo::stats 2>/dev/null)"
t_eq "stats: ONE git log pass" "1" "$(grep -c '^--no-pager log\| log ' "$GT_GIT_LOG")"
gt_git_counter off
t_eq "stats: commits" "9" "$(val commits "$out")"
t_eq "stats: authors (by e-mail)" "3" "$(val authors "$out")"
t_eq "stats: first date" "2020-01-01" "$(val first "$out")"
t_has "stats: last date is the newest author date" "2020-0" "$(val last "$out")"
t_eq "stats: top contributor first, with count and name" "top	6	T" "$(printf '%s\n' "$out" | grep -m1 '^top')"
t_eq "stats: second contributor" "top	2	Bea" "$(printf '%s\n' "$out" | grep '^top' | sed -n 2p)"
t_eq "stats: --top 1 lists one" "1" "$(shell::git::repo::stats --top 1 2>/dev/null | grep -c '^top')"
t_eq "stats: --top 0 lists none" "0" "$(shell::git::repo::stats --top 0 2>/dev/null | grep -c '^top')"
t_eq "stats: --max bounds the commits read" "2" "$(val commits "$(shell::git::repo::stats --max 2 2>/dev/null)")"
t_eq "stats: nothing on stderr" "" "$(shell::git::repo::stats 2>&1 >/dev/null)"
t_eq "stats: an empty repository reports zeros" "0 0 -" "$(cd "$HOME/empty" && out="$(shell::git::repo::stats 2>/dev/null)" && echo "$(val commits "$out") $(val authors "$out") $(val first "$out")")"
t_eq "stats: a bare repository works" "0" "$(
	cd "$HOME/bare.git" && shell::git::repo::stats >/dev/null 2>&1
	echo $?
)"
# a name with odd characters survives
git -c user.name="Zoë \"Z\" Ünï" -c user.email=z@example.com commit -q --allow-empty -m z1
t_has "stats: unicode and quotes in an author name" 'Zoë "Z" Ünï' "$(shell::git::repo::stats --top 9 2>/dev/null)"
# constant calls: stats is one log call for 20 or 2000 commits
rm -rf "$HOME/many"
gt_init "$HOME/many"
gt_commit base
gt_git_counter on
shell::git::repo::stats >/dev/null 2>&1
small="$(gt_count)"
gt_git_counter off
n=0
{
	while [ "$n" -lt 2000 ]; do
		n=$((n + 1))
		printf 'commit refs/heads/main\ncommitter T <t@example.com> %d +0000\ndata 2\nc\n\n' $((1600000000 + n))
	done
} | git fast-import --quiet --force 2>/dev/null
gt_git_counter on
out="$(shell::git::repo::stats 2>/dev/null)"
large="$(gt_count)"
gt_git_counter off
t_eq "stats: the same number of git calls for 1 and 2000 commits" "$small" "$large"
t_eq "stats: 2000 commits counted" "2000" "$(val commits "$out")"

# ---------------------------------------------------------------- size
cd "$HOME/st" || exit 1
printf '12345678901234567890' >twenty.txt
git add twenty.txt
git commit -q -m size
out="$(shell::git::repo::size 2>/dev/null)"
t_eq "size: tracked bytes are the files at HEAD (6 x 10 + 20)" "80" "$(val tracked_bytes "$out")"
t_eq "size: tracked file count" "7" "$(val tracked_files "$out")"
t_eq "size: loose objects present before gc" "1" "$([ "$(val loose_objects "$out")" -gt 0 ] && echo 1 || echo 0)"
t_eq "size: no packs before gc" "0" "$(val packs "$out")"
git gc -q 2>/dev/null
out="$(shell::git::repo::size 2>/dev/null)"
t_eq "size: one pack after gc" "1" "$(val packs "$out")"
t_eq "size: pack size is a number of KiB" "1" "$(printf '%s\n' "$(val pack_kib "$out")" | grep -cE '^[0-9]+$')"
t_eq "size: the git directory has a size" "1" "$([ "$(val gitdir_kib "$out")" -gt 0 ] && echo 1 || echo 0)"
t_eq "size: nothing on stderr" "" "$(shell::git::repo::size 2>&1 >/dev/null)"
t_eq "size: an empty repository works (zero tracked)" "0 0" "$(cd "$HOME/empty" && out="$(shell::git::repo::size 2>/dev/null)" && echo "$(val tracked_bytes "$out") $(val tracked_files "$out")")"
t_eq "size: a bare repository works" "0" "$(
	cd "$HOME/bare.git" && shell::git::repo::size >/dev/null 2>&1
	echo $?
)"
gt_git_counter on
shell::git::repo::size >/dev/null 2>&1
small="$(gt_count)"
gt_git_counter off
cd "$HOME/many" || exit 1
git checkout -q -f main 2>/dev/null
for i in $(seq 300); do printf 'x\n' >"s$i.txt"; done
git add -A
git commit -q -m files
gt_git_counter on
shell::git::repo::size >/dev/null 2>&1
large="$(gt_count)"
gt_git_counter off
t_eq "size: the same number of git calls however many files" "$small" "$large"
cd "$HOME/st" || exit 1

# ---------------------------------------------------------------- summary
live_repo sm
printf 'dirty\n' >>a.txt
out="$(shell::git::repo::summary 2>"$HOME/sm.err")"
t_eq "summary: exit 0" "0" "$(
	shell::git::repo::summary >/dev/null 2>&1
	echo $?
)"
t_eq "summary: branch, upstream, tree, branches" "main origin/main 1 1" "$(val branch "$out") $(val upstream "$out") $(val unstaged "$out") $(val remote_branches "$out")"
t_eq "summary: history" "2 1" "$(val commits "$out") $(val authors "$out")"
t_eq "summary: severity" "warning" "$(val severity "$out")"
t_eq "summary: agrees with health" "$(val severity "$(shell::git::repo::health 2>/dev/null)")" "$(val severity "$out")"
t_eq "summary: nothing on stderr" "" "$(cat "$HOME/sm.err")"
t_eq "summary: exit 0 even with problems (a merge conflict)" "0" "$(
	git checkout -q -b s2 && printf 's\n' >a.txt && git commit -qam s2 && git checkout -q main && printf 'm\n' >a.txt && git commit -qam m2 && git merge s2 >/dev/null 2>&1
	shell::git::repo::summary >/dev/null 2>&1
	echo $?
)"
git merge --abort 2>/dev/null
t_eq "summary: works in a bare repository" "0" "$(
	cd "$HOME/bare.git" && shell::git::repo::summary >/dev/null 2>&1
	echo $?
)"
t_eq "summary: works in an empty repository" "0" "$(
	cd "$HOME/empty" && shell::git::repo::summary >/dev/null 2>&1
	echo $?
)"
t_eq "summary: no ANSI in plain mode" "0" "$(shell::git::repo::summary 2>/dev/null | grep -c "$(printf '\033')")"

# human sizes
t_eq "human: bytes" "512 B" "$(_shell::git::core::repo_human 512)"
t_eq "human: KiB" "1.5 KiB" "$(_shell::git::core::repo_human 1536)"
t_eq "human: MiB" "3.0 MiB" "$(_shell::git::core::repo_human 3145728)"

t_done
