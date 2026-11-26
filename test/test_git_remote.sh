#!/usr/bin/env bash
# shell::git::remote::{sync,compare,fetch,prune} against local bare repositories (no network, no terminal).
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
t_setup
. "$SHELL_TEST_ROOT/test/support/git_toolkit.sh"
esc="$(printf '\033')"
rn=0
no_input() {
	_shell::git::core::input_close
	unset SHELL_GIT_INPUT
	_SHELL_GIT_INPUT_OPEN=""
}

# mkpair: bare origin, repository a (cwd) tracking origin/main, clone b used to move the remote
mkpair() {
	cd "$HOME" || exit 1
	rm -rf "$HOME/origin.git" "$HOME/a" "$HOME/b" "$HOME/backup.git"
	gt_init "$HOME/a"
	gt_commit "base" "base.txt" "base"
	gt_remote origin
	git --git-dir="$HOME/origin.git" symbolic-ref HEAD refs/heads/main
	git clone -q "$HOME/origin.git" "$HOME/b" 2>/dev/null
	(cd "$HOME/b" && git config user.email t@e && git config user.name T && git config commit.gpgsign false)
	cd "$HOME/a" || exit 1
}
# remote_commit <msg> <file> <text>: a commit on origin/main made through the clone b
remote_commit() {
	rn=$((rn + 1))
	(
		cd "$HOME/b" || exit 1
		git pull -q --rebase origin main 2>/dev/null
		GT_TICK=$((200 + rn))
		gt_commit "$1" "$2" "$3"
		git push -q origin main 2>/dev/null
	)
}

# --- usage, errors that need no repository
for fn in sync compare fetch prune; do
	t_has "$fn: -h prints usage on stdout" "Usage: shell::git::remote::$fn" "$(shell::git::remote::$fn -h 2>/dev/null)"
	shell::git::remote::$fn --bogus >/dev/null 2>&1
	t_eq "$fn: an unknown option is 2" "2" "$?"
	mkdir -p "$HOME/notrepo"
	(cd "$HOME/notrepo" && shell::git::remote::$fn >/dev/null 2>&1)
	t_eq "$fn: not a repository is 3" "3" "$?"
done

# --- sync
mkpair
t_eq "sync: up to date is 0" "0" "$(
	shell::git::remote::sync >/dev/null 2>&1
	echo $?
)"
t_has "sync: says so on stderr" "up to date" "$(shell::git::remote::sync 2>&1 >/dev/null)"
t_eq "sync: nothing on stdout when there was nothing to do" "" "$(shell::git::remote::sync 2>/dev/null)"
gt_commit "local ahead" "ahead.txt" "a"
t_has "sync: ahead only is reported, not pushed" "1 commit(s) ahead" "$(shell::git::remote::sync 2>&1 >/dev/null)"
t_eq "sync: ahead only is 0" "0" "$(
	shell::git::remote::sync >/dev/null 2>&1
	echo $?
)"
t_eq "sync: ahead only did not push" "$(git rev-parse HEAD~1)" "$(git --git-dir="$HOME/origin.git" rev-parse main)"
mkpair
remote_commit "remote one" "r1.txt" "r1"
tip="$(git --git-dir="$HOME/origin.git" rev-parse main)"
snap="$(gt_snapshot)"
out="$(shell::git::remote::sync -n 2>/dev/null)"
t_eq "sync -n: prints the fetch and nothing else when the remote is not fetched yet" "git fetch -- origin" "$out"
t_eq "sync -n: executed nothing" "$snap" "$(gt_snapshot)"
git fetch -q origin
snap="$(gt_snapshot)"
out="$(shell::git::remote::sync -n 2>/dev/null)"
t_eq "sync -n: the exact commands, quoted" "git fetch -- origin
git merge --ff-only -- origin/main" "$out"
t_eq "sync -n: still nothing changed" "$snap" "$(gt_snapshot)"
out="$(shell::git::remote::sync 2>/dev/null)"
t_eq "sync: fast-forward prints the new HEAD" "$tip" "$out"
t_eq "sync: fast-forward moved the branch" "$tip" "$(git rev-parse HEAD)"
t_eq "sync: the new file arrived" "r1" "$(cat r1.txt)"
t_eq "sync: stderr and stdout are separate (stdout is one hash)" "1" "$(shell::git::remote::sync 2>/dev/null | wc -l | tr -d ' ' | sed 's/^0$/1/')"

# dirty tree, autostash
remote_commit "remote two" "r2.txt" "r2"
printf 'dirty\n' >>base.txt
snap="$(gt_snapshot)"
shell::git::remote::sync >/dev/null 2>"$HOME/err.out"
t_eq "sync: a dirty tree blocks with 7" "7" "$?"
t_has "sync: ...and says how to proceed" "--autostash" "$(cat "$HOME/err.out")"
t_eq "sync: blocked sync changed no ref" "$(printf '%s\n' "$snap" | grep -v 'origin')" "$(gt_snapshot | grep -v 'origin')"
git fetch -q origin
shell::git::remote::sync --autostash >/dev/null 2>&1
t_eq "sync --autostash: ok" "0" "$?"
t_eq "sync --autostash: the remote commit arrived" "r2" "$(cat r2.txt)"
t_eq "sync --autostash: your change is back" "dirty" "$(tail -n 1 base.txt)"
t_eq "sync --autostash: no stash left behind" "0" "$(git stash list | wc -l | tr -d ' ')"
git checkout -q -- base.txt

# detached HEAD, no upstream, gone upstream, operation in progress
git checkout -q --detach
shell::git::remote::sync >/dev/null 2>&1
t_eq "sync: detached HEAD is 1" "1" "$?"
git checkout -q main
git checkout -q -b lonely
shell::git::remote::sync >/dev/null 2>"$HOME/err.out"
t_eq "sync: no upstream is 1" "1" "$?"
t_has "sync: ...with the command to set one" "--set-upstream-to" "$(cat "$HOME/err.out")"
git push -q -u origin lonely 2>/dev/null
git --git-dir="$HOME/origin.git" branch -D lonely >/dev/null
git fetch -q --prune origin
shell::git::remote::sync >/dev/null 2>"$HOME/err.out"
t_eq "sync: a gone upstream is 1" "1" "$?"
t_has "sync: ...and says gone" "gone" "$(cat "$HOME/err.out")"
git checkout -q main
git branch -q -D lonely
git checkout -q -b conf-a
gt_commit "ca" "clash.txt" "a"
git checkout -q main
git checkout -q -b conf-b
gt_commit "cb" "clash.txt" "b"
git merge conf-a >/dev/null 2>&1
shell::git::remote::sync >/dev/null 2>&1
t_eq "sync: a merge in progress blocks with 7" "7" "$?"
git merge --abort
git checkout -q main
git branch -q -D conf-a conf-b

# diverged
mkpair
remote_commit "remote side" "remote-side.txt" "rs"
gt_commit "local side" "local-side.txt" "ls"
git fetch -q origin
snap="$(gt_snapshot)"
shell::git::remote::sync >/dev/null 2>"$HOME/err.out"
t_eq "sync: diverged without a strategy and without a terminal is 2" "2" "$?"
t_has "sync: ...and says to pass --merge or --rebase" "--merge or --rebase" "$(cat "$HOME/err.out")"
t_eq "sync: refusing changed nothing" "$snap" "$(gt_snapshot)"
shell::git::remote::sync --ff-only >/dev/null 2>&1
t_eq "sync --ff-only: diverged is 1" "1" "$?"
t_eq "sync --ff-only: nothing changed" "$snap" "$(gt_snapshot)"
out="$(shell::git::remote::sync --merge -n 2>/dev/null)"
t_eq "sync --merge -n: the merge command" "git fetch -- origin
git merge --no-edit -- origin/main" "$out"
out="$(shell::git::remote::sync --rebase -n 2>/dev/null)"
t_eq "sync --rebase -n: the rebase command" "git fetch -- origin
git rebase origin/main" "$out"
t_eq "sync -n: executed nothing" "$snap" "$(gt_snapshot)"
shell::git::remote::sync --merge >/dev/null 2>&1
t_eq "sync --merge: no terminal and no --yes is 2" "2" "$?"
t_eq "sync --merge without --yes: nothing changed" "$snap" "$(gt_snapshot)"
gt_input n
shell::git::remote::sync --merge >/dev/null 2>&1
t_eq "sync --merge: declined is 5" "5" "$?"
no_input
t_eq "sync --merge: declined leaves the repository identical" "$snap" "$(gt_snapshot)"
t_has "sync: the divergence preview lists both sides" "local side" "$(shell::git::remote::sync --merge -y 2>&1 >/dev/null)"
t_eq "sync --merge -y: a merge commit with two parents" "2" "$(git rev-list --parents -n 1 HEAD | wc -w | tr -d ' ' | awk '{ print $1 - 1 }')"
t_eq "sync --merge: both files present" "rs ls" "$(cat remote-side.txt) $(cat local-side.txt)"
mkpair
remote_commit "remote side" "remote-side.txt" "rs"
gt_commit "local side" "local-side.txt" "ls"
out="$(shell::git::remote::sync --rebase -y 2>/dev/null)"
t_eq "sync --rebase -y: prints the new HEAD" "$(git rev-parse HEAD)" "$out"
t_eq "sync --rebase -y: linear history (one parent)" "1" "$(git rev-list --parents -n 1 HEAD | wc -w | tr -d ' ' | awk '{ print $1 - 1 }')"
t_eq "sync --rebase: your commit sits on top of the remote one" "local side" "$(git log -1 --format=%s)"
# interactive choice with the fake fzf
mkpair
remote_commit "remote side" "remote-side.txt" "rs"
gt_commit "local side" "local-side.txt" "ls"
gt_fake_fzf
out="$(FAKE_FZF_PICKS="rebase" shell::git::remote::sync -y 2>/dev/null)"
t_eq "sync: the interactive choice picks rebase" "$(git rev-parse HEAD)" "$out"
t_eq "sync: ...and the history is linear" "1" "$(git rev-list --parents -n 1 HEAD | wc -w | tr -d ' ' | awk '{ print $1 - 1 }')"
mkpair
remote_commit "remote side" "remote-side.txt" "rs"
gt_commit "local side" "local-side.txt" "ls"
snap="$(gt_snapshot)"
FAKE_FZF_PICKS="" shell::git::remote::sync -y >/dev/null 2>&1
t_eq "sync: esc in the strategy choice is 5" "5" "$?"
git fetch -q origin
t_eq "sync: esc changed nothing" "$(printf '%s\n' "$snap" | grep -v origin)" "$(gt_snapshot | grep -v origin)"
# conflicts
mkpair
remote_commit "remote clash" "clash.txt" "remote"
gt_commit "local clash" "clash.txt" "local"
shell::git::remote::sync --rebase -y >/dev/null 2>"$HOME/err.out"
t_eq "sync --rebase: conflicts are 6" "6" "$?"
t_has "sync: says how to continue" "git rebase --continue" "$(cat "$HOME/err.out")"
t_has "sync: says how to abort" "git rebase --abort" "$(cat "$HOME/err.out")"
shell::git::remote::sync >/dev/null 2>&1
t_eq "sync: the rebase in progress blocks a second sync with 7" "7" "$?"
git rebase --abort
mkpair
remote_commit "remote clash" "clash.txt" "remote"
gt_commit "local clash" "clash.txt" "local"
shell::git::remote::sync --merge -y >/dev/null 2>"$HOME/err.out"
t_eq "sync --merge: conflicts are 6" "6" "$?"
t_has "sync: says how to continue a merge" "git merge --continue" "$(cat "$HOME/err.out")"
git merge --abort
# network failure and credentials
mkpair
git remote set-url origin "$HOME/does-not-exist.git"
shell::git::remote::sync >/dev/null 2>"$HOME/err.out"
t_eq "sync: an unreachable remote is 1" "1" "$?"
t_has "sync: ...with a hint" "hint:" "$(cat "$HOME/err.out")"
git remote set-url origin "https://me:topsecret@127.0.0.1:9/x.git"
shell::git::remote::sync >/dev/null 2>"$HOME/err.out"
t_eq "sync: a refused connection is 1 and returns at once" "1" "$?"
t_lacks "sync: the password never appears in the messages" "topsecret" "$(cat "$HOME/err.out")"
git remote set-url origin "$HOME/origin.git"
t_eq "sync --no-fetch: no fetch call" "0" "$(
	gt_git_counter on
	shell::git::remote::sync --no-fetch >/dev/null 2>&1
	gt_count fetch
	gt_git_counter off
)"
t_eq "mask_text: a credentialed URL" "see https://***@host/x.git ok" "$(printf 'see https://me:tok@host/x.git ok\n' | _shell::git::core::remote_mask_text)"
t_eq "mask_text: a plain URL is untouched" "see https://host/x.git" "$(printf 'see https://host/x.git\n' | _shell::git::core::remote_mask_text)"

# --- compare
mkpair
git checkout -q -b ahead-b
gt_commit "ab" "ab.txt" "x"
git push -q -u origin ahead-b 2>/dev/null
gt_commit "ab2" "ab2.txt" "x"
git checkout -q main
git checkout -q -b behind-b
git push -q -u origin behind-b 2>/dev/null
git checkout -q main
(
	cd "$HOME/b" && git fetch -q origin && git checkout -q behind-b && GT_TICK=300 gt_commit "bb" "bb.txt" "x" && git push -q origin behind-b 2>/dev/null
)
git checkout -q -b diverged-b
git push -q -u origin diverged-b 2>/dev/null
gt_commit "db local" "db-l.txt" "x"
(
	cd "$HOME/b" && git fetch -q origin && git checkout -q diverged-b && GT_TICK=301 gt_commit "db remote" "db-r.txt" "x" && git push -q origin diverged-b 2>/dev/null
)
git checkout -q main
git checkout -q -b gone-b
git push -q -u origin gone-b 2>/dev/null
git --git-dir="$HOME/origin.git" branch -D gone-b >/dev/null
git checkout -q -b no-up
git checkout -q main
git fetch -q --prune origin
out="$(shell::git::remote::compare --plain 2>/dev/null)"
t_has "compare: in sync" "main	origin/main	in sync" "$out"
t_has "compare: ahead" "ahead-b	origin/ahead-b	ahead 1" "$out"
t_has "compare: behind" "behind-b	origin/behind-b	behind 1" "$out"
t_has "compare: diverged" "diverged-b	origin/diverged-b	ahead 1, behind 1" "$out"
t_has "compare: gone" "gone-b	origin/gone-b	gone" "$out"
t_has "compare: no upstream" "no-up	-	no upstream" "$out"
t_eq "compare --plain: every branch, one line each" "6" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
t_eq "compare: stderr is empty on success" "" "$(shell::git::remote::compare 2>&1 >/dev/null)"
out="$(shell::git::remote::compare 2>/dev/null)"
t_has "compare: the current branch is marked" "* main" "$out"
t_lacks "compare: no ANSI when not a terminal" "$esc" "$out"
t_eq "compare: columns are aligned (same width up to the upstream column)" "1" "$(printf '%s\n' "$out" | awk '{ n = index($0, "origin/"); if (n > 0) w[n] = 1 } END { c = 0; for (k in w) c++; print (c <= 2 ? 1 : 0) }')"
git remote add backup "$HOME/backup.git"
git init -q --bare "$HOME/backup.git"
git push -q backup no-up 2>/dev/null
git fetch -q backup
t_has "compare: a branch without upstream hints at the remote branch of the same name" "no upstream (backup/no-up exists)" "$(shell::git::remote::compare --plain 2>/dev/null)"
t_eq "compare --remote origin: only upstreams on origin" "5" "$(shell::git::remote::compare --remote origin --plain 2>/dev/null | wc -l | tr -d ' ')"
shell::git::remote::compare --remote nope >/dev/null 2>&1
t_eq "compare: unknown remote is 2" "2" "$?"
# constant number of git calls
mkbranches() { # <n>
	local i=1
	while [ "$i" -le "$1" ]; do
		printf 'create refs/heads/bulk%s HEAD\n' "$i"
		i=$((i + 1))
	done | git update-ref --stdin
}
gt_git_counter on
shell::git::remote::compare >/dev/null 2>&1
few="$(gt_count)"
gt_git_counter off
mkbranches 300
gt_git_counter on
shell::git::remote::compare >/dev/null 2>&1
many="$(gt_count)"
gt_git_counter off
t_eq "compare: the same number of git calls for 8 and 300 branches ($few)" "$few" "$many"
t_eq "compare: exactly two for-each-ref calls" "2" "$(
	gt_git_counter on
	shell::git::remote::compare >/dev/null 2>&1
	gt_count for-each-ref
	gt_git_counter off
)"

# --- fetch
mkpair
remote_commit "remote one" "r1.txt" "r1"
tip="$(git --git-dir="$HOME/origin.git" rev-parse main)"
snap="$(gt_snapshot)"
out="$(shell::git::remote::fetch -n 2>/dev/null)"
t_eq "fetch -n: the exact command (single remote chosen without asking)" "git fetch -- origin" "$out"
t_eq "fetch -n: executed nothing" "$snap" "$(gt_snapshot)"
out="$(shell::git::remote::fetch 2>/dev/null)"
t_eq "fetch: prints the remote fetched" "origin" "$out"
t_eq "fetch: origin/main moved" "$tip" "$(git rev-parse origin/main)"
t_eq "fetch: HEAD did not move" "$(git rev-parse HEAD)" "$(git rev-parse main)"
shell::git::remote::fetch nope >/dev/null 2>&1
t_eq "fetch: unknown remote is 2" "2" "$?"
shell::git::remote::fetch -- -x >/dev/null 2>&1
t_eq "fetch: a remote named like an option is unknown (2), never run as an option" "2" "$?"
shell::git::remote::fetch -x >/dev/null 2>&1
t_eq "fetch: -x is an unknown option (2)" "2" "$?"
# prune only when asked
git checkout -q -b topic
git push -q -u origin topic 2>/dev/null
git checkout -q main
git --git-dir="$HOME/origin.git" branch -D topic >/dev/null
shell::git::remote::fetch >/dev/null 2>&1
t_eq "fetch: without --prune the stale remote-tracking branch stays" "1" "$(git branch -r | grep -c 'origin/topic')"
shell::git::remote::fetch --prune >/dev/null 2>&1
t_eq "fetch --prune: it is removed" "0" "$(git branch -r | grep -c 'origin/topic')"
t_eq "fetch --prune -n: the flag is in the command" "git fetch --prune -- origin" "$(shell::git::remote::fetch --prune -n 2>/dev/null)"
# several remotes
git init -q --bare "$HOME/backup.git"
git remote add backup "$HOME/backup.git"
git push -q backup main 2>/dev/null
git remote set-url backup "https://me:topsecret@example.invalid/x.git"
git config remote.backup.pushurl "$HOME/backup.git"
unset SHELL_GIT_FORCE_FZF
shell::git::remote::fetch >/dev/null 2>&1
t_eq "fetch: several remotes and nothing to ask on is 2" "2" "$?"
gt_fake_fzf
out="$(FAKE_FZF_PICKS="origin" shell::git::remote::fetch 2>/dev/null)"
t_eq "fetch: picks a remote interactively" "origin" "$out"
t_lacks "fetch: the picker never shows the password" "topsecret" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "fetch: ...it shows it masked" "https://***@example.invalid/x.git" "$(cat "$FAKE_FZF_DIR/stdin.1")"
FAKE_FZF_PICKS="" shell::git::remote::fetch >/dev/null 2>&1
t_eq "fetch: esc in the remote picker is 5" "5" "$?"
git remote set-url backup "$HOME/backup.git"
remote_commit "remote two" "r2.txt" "r2"
git -C "$HOME/backup.git" update-ref refs/heads/other "$(git rev-parse main)"
out="$(shell::git::remote::fetch --all 2>/dev/null)"
t_eq "fetch --all: every remote, in order" "backup
origin" "$out"
t_eq "fetch --all: the second remote's branch arrived" "1" "$(git branch -r | grep -c 'backup/other')"
t_eq "fetch --all -n: one command per remote" "git fetch -- backup
git fetch -- origin" "$(shell::git::remote::fetch --all -n 2>/dev/null)"
shell::git::remote::fetch --all origin >/dev/null 2>&1
t_eq "fetch: --all with names is 2" "2" "$?"
git remote set-url origin "$HOME/does-not-exist.git"
shell::git::remote::fetch origin >/dev/null 2>"$HOME/err.out"
t_eq "fetch: an unreachable remote is 1" "1" "$?"
t_has "fetch: ...with a hint" "hint:" "$(cat "$HOME/err.out")"
git remote set-url origin "https://me:topsecret@127.0.0.1:9/x.git"
shell::git::remote::fetch origin >/dev/null 2>"$HOME/err.out"
t_eq "fetch: a refused connection is 1" "1" "$?"
t_lacks "fetch: the password never appears in the messages" "topsecret" "$(cat "$HOME/err.out")"
mkdir "$HOME/norem" && (cd "$HOME/norem" && git init -q . && shell::git::remote::fetch >/dev/null 2>&1)
t_eq "fetch: a repository without remote is 1" "1" "$?"
# empty repository with a remote, detached HEAD, linked worktree, bare repository
mkpair
git checkout -q --detach
t_eq "fetch: works on a detached HEAD" "origin" "$(shell::git::remote::fetch 2>/dev/null)"
git checkout -q main
git worktree add -q "$HOME/wt" -b wtb >/dev/null 2>&1
t_eq "fetch: works in a linked worktree" "origin" "$(cd "$HOME/wt" && shell::git::remote::fetch 2>/dev/null)"
git clone -q --bare "$HOME/origin.git" "$HOME/bare.git" 2>/dev/null
t_eq "fetch: works in a bare repository" "origin" "$(cd "$HOME/bare.git" && shell::git::remote::fetch 2>/dev/null)"
rm -rf "$HOME/empty" && mkdir "$HOME/empty" && cd "$HOME/empty" && git init -q . && git remote add origin "$HOME/origin.git"
t_eq "fetch: works in an empty repository" "origin" "$(shell::git::remote::fetch 2>/dev/null)"
shell::git::remote::sync >/dev/null 2>&1
t_eq "sync: an empty repository is 1" "1" "$?"
cd "$HOME/a" || exit 1

# --- prune
mkpair
git checkout -q -b topic
git push -q -u origin topic 2>/dev/null
git checkout -q -b topic2
git push -q -u origin topic2 2>/dev/null
git checkout -q main
git --git-dir="$HOME/origin.git" branch -D topic topic2 >/dev/null
snap="$(gt_snapshot)"
out="$(shell::git::remote::prune -n 2>/dev/null)"
t_eq "prune -n: the preview and the prune, both quoted" "git remote prune --dry-run origin
git remote prune origin" "$out"
t_eq "prune -n: executed nothing" "$snap" "$(gt_snapshot)"
shell::git::remote::prune >/dev/null 2>"$HOME/err.out"
t_eq "prune: no terminal and no --yes is 2" "2" "$?"
t_has "prune: the preview was shown first" "origin/topic" "$(cat "$HOME/err.out")"
t_has "prune: ...as a would-prune list" "would prune" "$(cat "$HOME/err.out")"
t_eq "prune: refusing changed nothing" "$snap" "$(gt_snapshot)"
gt_input n
shell::git::remote::prune >/dev/null 2>&1
t_eq "prune: declined is 5" "5" "$?"
no_input
t_eq "prune: declined leaves the repository identical" "$snap" "$(gt_snapshot)"
gt_input y
out="$(shell::git::remote::prune 2>/dev/null)"
no_input
unset SHELL_GIT_INPUT
_SHELL_GIT_INPUT_OPEN=""
t_eq "prune: confirmed, prints what was pruned" "origin/topic
origin/topic2" "$out"
t_eq "prune: the remote-tracking branches are gone" "0" "$(git branch -r | grep -c 'origin/topic')"
t_eq "prune: local branches are untouched" "2" "$(git branch | grep -c 'topic')"
out="$(shell::git::remote::prune -y 2>&1)"
t_has "prune: nothing to prune is said" "nothing to prune" "$out"
t_eq "prune: nothing to prune is 0" "0" "$(
	shell::git::remote::prune -y >/dev/null 2>&1
	echo $?
)"
shell::git::remote::prune nope >/dev/null 2>&1
t_eq "prune: unknown remote is 2" "2" "$?"
shell::git::remote::prune origin extra >/dev/null 2>&1
t_eq "prune: two remotes is 2" "2" "$?"
git remote set-url origin "$HOME/does-not-exist.git"
shell::git::remote::prune -y >/dev/null 2>"$HOME/err.out"
t_eq "prune: an unreachable remote is 1" "1" "$?"
t_has "prune: ...with a hint" "hint:" "$(cat "$HOME/err.out")"
git remote set-url origin "$HOME/origin.git"
git push -q origin topic 2>/dev/null
git --git-dir="$HOME/origin.git" branch -D topic >/dev/null
t_eq "prune: the remote can be given explicitly" "origin/topic" "$(shell::git::remote::prune -y origin 2>/dev/null)"

t_done
