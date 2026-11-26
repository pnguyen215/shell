#!/usr/bin/env bash
# The flow group of the Git toolkit: shell::git::flow::{feature,release,hotfix,sync}.
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
t_setup
. "$SHELL_TEST_ROOT/test/support/git_toolkit.sh"
_shell::git::core::boot
gt_fake_fzf

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
run_i() {
	"$@" >"$HOME/out" 2>"$HOME/err" </dev/null
	RC=$?
	OUT="$(cat "$HOME/out")"
	ERR="$(cat "$HOME/err")"
	_shell::git::core::input_close
	unset SHELL_GIT_INPUT
	_SHELL_GIT_INPUT_OPEN=""
}
mk() {
	cd "$HOME" || return 1
	rm -rf "$HOME/repo" "$HOME/origin.git"
	gt_init "$HOME/repo"
	gt_commit first
	gt_commit second
}
is_hash() { case "$1" in *[!0-9a-f]* | "") echo no ;; *) [ "${#1}" -eq 40 ] && echo yes || echo no ;; esac }
ansi="$(printf '\033')"

# ============================ feature / hotfix / release ============================
mk
run shell::git::flow::feature -h
t_eq "feature: -h is exit 0 with usage on stdout" "0" "$RC"
t_has "feature: -h prints the usage" "Usage:" "$OUT"
S0="$(gt_snapshot)"
run shell::git::flow::feature -n login
t_eq "feature -n: exit 0" "0" "$RC"
t_eq "feature -n: prints the exact command" "git switch --create feature/login --no-track main" "$OUT"
t_eq "feature -n: executes nothing" "$S0" "$(gt_snapshot)"
run shell::git::flow::feature login
t_eq "feature: success" "0" "$RC"
t_eq "feature: stdout is the branch name only" "feature/login" "$OUT"
t_eq "feature: HEAD is on it" "feature/login" "$(git symbolic-ref --short HEAD)"
t_eq "feature: it starts at the base" "$(git rev-parse main)" "$(git rev-parse HEAD)"
git checkout -q main
run shell::git::flow::feature login
t_eq "feature: an existing branch is 1" "1" "$RC"
t_has "feature: ...and says so" "already exists" "$ERR"
run shell::git::flow::feature feature/already
t_eq "feature: a name that already has the prefix is not doubled" "feature/already" "$OUT"
git checkout -q main
run shell::git::flow::feature "a..b"
t_eq "feature: an invalid name is 2" "2" "$RC"
run shell::git::flow::feature "bad name"
t_eq "feature: a name with a space is 2" "2" "$RC"
run shell::git::flow::feature -x
t_eq "feature: an option-like argument is an unknown option (2)" "2" "$RC"
run shell::git::flow::feature -- -x
t_eq "feature: after -- a leading dash is part of the name" "feature/-x" "$OUT"
git checkout -q main
run shell::git::flow::feature
t_eq "feature: no name and no terminal is 2" "2" "$RC"
gt_input "from-prompt"
run_i shell::git::flow::feature
t_eq "feature: the name is asked on a terminal" "feature/from-prompt" "$OUT"
git checkout -q main
gt_input ""
run_i shell::git::flow::feature
t_eq "feature: an empty name at the prompt is 5" "5" "$RC"
SHELL_GIT_FEATURE_PREFIX="feat-" run shell::git::flow::feature custom
t_eq "feature: SHELL_GIT_FEATURE_PREFIX is honored" "feat-custom" "$OUT"
git checkout -q main
(
	SHELL_GIT_FEATURE_PREFIX="team/" shell::git::flow::feature -n x >"$HOME/out" 2>&1
)
t_has "feature: a prefix from the environment reaches the branch name" "team/x" "$(cat "$HOME/out")"

# base resolution: never hardcoded
git checkout -q -b develop
gt_commit dev-work
git checkout -q main
run shell::git::flow::feature -n --base develop x
t_has "feature --base: the start point" "feature/x --no-track develop" "$OUT"
(
	SHELL_GIT_BASE_BRANCH=develop shell::git::flow::feature -n y >"$HOME/out" 2>&1
)
t_has "feature: SHELL_GIT_BASE_BRANCH is honored" "feature/y --no-track develop" "$(cat "$HOME/out")"
(
	SHELL_GIT_BASE_BRANCH=nope shell::git::flow::feature -n y >"$HOME/out" 2>&1
	echo $? >"$HOME/rc"
)
t_eq "feature: a configured base that does not exist is 1" "1" "$(cat "$HOME/rc")"
run shell::git::flow::feature -n --base nope z
t_eq "feature: a --base that does not exist is 1" "1" "$RC"
run shell::git::flow::feature -n --base
t_eq "feature: --base without a value is 2" "2" "$RC"
git branch -q -D develop

# release and hotfix
run shell::git::flow::hotfix -n crash
t_eq "hotfix -n: prefix hotfix/" "git switch --create hotfix/crash --no-track main" "$OUT"
run shell::git::flow::hotfix crash
t_eq "hotfix: created" "hotfix/crash" "$OUT"
git checkout -q main
run shell::git::flow::release -n 1.4.0
t_eq "release -n: prefix release/, from the base by default" "git switch --create release/1.4.0 --no-track main" "$OUT"
git checkout -q -b develop
gt_commit dev2
git checkout -q main
(
	SHELL_GIT_RELEASE_BASE=develop shell::git::flow::release -n 1.5.0 >"$HOME/out" 2>&1
)
t_eq "release: SHELL_GIT_RELEASE_BASE is the start point" "git switch --create release/1.5.0 --no-track develop" "$(cat "$HOME/out")"
(
	SHELL_GIT_RELEASE_BASE=develop shell::git::flow::release 1.5.0 >"$HOME/out" 2>/dev/null
)
t_eq "release: created from the release base" "$(git rev-parse develop)" "$(git rev-parse release/1.5.0)"
git checkout -q main
git branch -q -D release/1.5.0 develop

# dirty tree, autostash, operation in progress
printf 'dirty\n' >>file1.txt
S0="$(gt_snapshot)"
run shell::git::flow::feature wip
t_eq "feature: a dirty tree blocks it (7)" "7" "$RC"
t_eq "feature: ...nothing changed" "$S0" "$(gt_snapshot)"
run shell::git::flow::feature --autostash wip
t_eq "feature --autostash: success" "0" "$RC"
t_eq "feature --autostash: the changes are in a stash" "1" "$(git stash list | wc -l | tr -d ' ')"
t_eq "feature --autostash: the tree is clean" "0 0 0 0" "$(_shell::git::core::tree_counts)"
git checkout -q main
git stash pop -q
git checkout -q -- file1.txt
git checkout -q -b ca main
gt_commit ca clash.txt a
git checkout -q -b cb main
gt_commit cb clash.txt b
git merge ca >/dev/null 2>&1
run shell::git::flow::feature blocked
t_eq "feature: an operation in progress blocks it (7)" "7" "$RC"
t_has "feature: ...and says how to leave it" "git merge --abort" "$ERR"
git merge --abort
git checkout -q main
git branch -q -D ca cb

# fetch: never hangs
gt_remote origin
run shell::git::flow::feature --fetch fetched
t_eq "feature --fetch: success with a reachable remote" "0" "$RC"
t_eq "feature --fetch: from the local base, no upstream copied" "" "$(git rev-parse --abbrev-ref "feature/fetched@{upstream}" 2>/dev/null)"
git checkout -q main
git remote set-url origin "$HOME/does-not-exist.git"
S0="$(gt_snapshot)"
run shell::git::flow::feature --fetch nofetch
t_eq "feature --fetch: a failing fetch is 1" "1" "$RC"
t_eq "feature --fetch: ...and nothing was created" "$S0" "$(gt_snapshot)"
run shell::git::flow::feature -n --fetch nofetch
t_has "feature -n --fetch: the fetch command is printed, not run" "git fetch --quiet" "$OUT"

# repository kinds
cd "$HOME" && rm -rf "$HOME/emptyrepo" && mkdir "$HOME/emptyrepo" && cd "$HOME/emptyrepo" && git init -q . && git symbolic-ref HEAD refs/heads/main
run shell::git::flow::feature x
t_eq "feature: an empty repository is 1 (no base branch)" "1" "$RC"
mkdir -p "$HOME/plain" && cd "$HOME/plain" || exit 1
run shell::git::flow::feature x
t_eq "feature: not a repository is 3" "3" "$RC"
git init -q --bare "$HOME/bare.git" && cd "$HOME/bare.git" || exit 1
run shell::git::flow::feature x
t_eq "feature: a bare repository is 3" "3" "$RC"
mk
git checkout -q --detach HEAD
run shell::git::flow::feature fromdetached
t_eq "feature: works on a detached HEAD" "feature/fromdetached" "$OUT"
git checkout -q main
git worktree add -q "$HOME/wt" -b wtb >/dev/null 2>&1
cd "$HOME/wt" || exit 1
run shell::git::flow::feature inworktree
t_eq "feature: works in a linked worktree" "feature/inworktree" "$OUT"
t_eq "feature: ...and does not touch the main worktree" "main" "$(git -C "$HOME/repo" symbolic-ref --short HEAD)"
cd "$HOME/repo" || exit 1

# ============================ flow::sync ============================
# base mk_div: main has base + 2 commits after the branch point; work has 1 own commit
mk_div() {
	cd "$HOME" || return 1
	rm -rf "$HOME/repo" "$HOME/origin.git"
	gt_init "$HOME/repo"
	gt_commit base
	git checkout -q -b work
	gt_commit mywork
	git checkout -q main
	gt_commit main1
	gt_commit main2
	git checkout -q work
}
mk_div
S0="$(gt_snapshot)"
run shell::git::flow::sync -h
t_eq "sync: -h exit 0" "0" "$RC"
run shell::git::flow::sync -n --merge
t_eq "sync -n --merge: prints the command" "git merge --no-edit main" "$OUT"
t_eq "sync -n --merge: executes nothing" "$S0" "$(gt_snapshot)"
run shell::git::flow::sync -n --rebase
t_has "sync -n --rebase: prints the rebase" "git rebase main" "$OUT"
t_has "sync -n --rebase: and the backup command" "update-ref" "$OUT"
t_eq "sync -n --rebase: executes nothing" "$S0" "$(gt_snapshot)"
run shell::git::flow::sync --merge
t_eq "sync: no terminal and no --yes is 2" "2" "$RC"
t_eq "sync: ...nothing changed" "$S0" "$(gt_snapshot)"
run shell::git::flow::sync -y
t_eq "sync: no method and no terminal is 2" "2" "$RC"
t_has "sync: ...naming both methods" "--merge or --rebase" "$ERR"
t_has "sync: the divergence preview is on stderr" "1 commit(s) ahead of and 2 commit(s) behind main" "$ERR"
gt_input n
run_i shell::git::flow::sync --merge
t_eq "sync: a declined confirmation is 5" "5" "$RC"
t_eq "sync: ...the repository is identical" "$S0" "$(gt_snapshot)"
run shell::git::flow::sync -z
t_eq "sync: an unknown argument is 2" "2" "$RC"
run shell::git::flow::sync -y --merge
t_eq "sync --merge -y: success" "0" "$RC"
t_eq "sync: stdout is the new HEAD, nothing else" "$(git rev-parse HEAD)" "$OUT"
t_eq "sync: a merge commit was created" "3" "$(git rev-list --parents -n 1 HEAD | wc -w | tr -d " ")"
t_eq "sync: main is now part of work" "0" "$(git rev-list --count HEAD..main)"
t_eq "sync: nothing on stdout but the hash (no ANSI)" "0" "$(printf '%s' "$OUT$ERR" | grep -c "$ansi")"
run shell::git::flow::sync -y --merge
t_eq "sync: already integrated is 0" "0" "$RC"
t_eq "sync: ...prints nothing on stdout" "" "$OUT"

mk_div
old_head="$(git rev-parse HEAD)"
run shell::git::flow::sync -y --rebase
t_eq "sync --rebase -y: success" "0" "$RC"
t_eq "sync --rebase: linear history, work on top of main" "$(git rev-parse main)" "$(git rev-parse HEAD~1)"
ref="$(git for-each-ref --format='%(refname)' refs/shell-backup/sync | head -n 1)"
t_has "sync --rebase: a backup ref exists" "refs/shell-backup/sync/" "$ref"
t_eq "sync --rebase: ...holding the old HEAD" "$old_head" "$(git rev-parse "$ref")"
t_has "sync --rebase: the restore command is printed" "git reset --hard $ref" "$ERR"
git reset -q --hard "$ref"
t_eq "sync --rebase: restoring recovers the old history" "$old_head" "$(git rev-parse HEAD)"
gt_remote origin
git push -q -u origin work 2>/dev/null
run shell::git::flow::sync -y --rebase
t_has "sync --rebase: a tracked branch gets the force-with-lease warning" "--force-with-lease" "$ERR"
git reset -q --hard "$old_head"

# method asked on a terminal
mk_div
gt_input m y
run_i shell::git::flow::sync
t_eq "sync: the method is asked on a terminal (merge)" "0" "$RC"
t_eq "sync: ...it merged" "3" "$(git rev-list --parents -n 1 HEAD | wc -w | tr -d " ")"
mk_div
S0="$(gt_snapshot)"
gt_input q
run_i shell::git::flow::sync
t_eq "sync: an unknown method answer is 5" "5" "$RC"
t_eq "sync: ...nothing changed" "$S0" "$(gt_snapshot)"

# dirty tree and autostash
printf 'dirty\n' >>base.txt 2>/dev/null
printf 'dirty\n' >>file1.txt
git add file1.txt 2>/dev/null
S0="$(gt_snapshot)"
run shell::git::flow::sync -y --merge
t_eq "sync: a dirty tree blocks it (7)" "7" "$RC"
t_eq "sync: ...nothing changed" "$S0" "$(gt_snapshot)"
git reset -q
git checkout -q -- . 2>/dev/null
rm -f base.txt
mk_div
printf 'dirty\n' >>file1.txt
run shell::git::flow::sync -y --merge --autostash
t_eq "sync --autostash: success" "0" "$RC"
t_eq "sync --autostash: the change is back" "1" "$(grep -c dirty file1.txt)"
git checkout -q -- file1.txt 2>/dev/null

# conflicts
cd "$HOME" && rm -rf "$HOME/repo" && gt_init "$HOME/repo"
gt_commit base f.txt "base"
git checkout -q -b work
gt_commit mine f.txt "mine"
git checkout -q main
gt_commit theirs f.txt "theirs"
git checkout -q work
run shell::git::flow::sync -y --merge
t_eq "sync: a merge conflict is 6" "6" "$RC"
t_has "sync: ...with the --continue command" "git merge --continue" "$ERR"
t_has "sync: ...and the --abort command" "git merge --abort" "$ERR"
run shell::git::flow::sync -y --merge
t_eq "sync: another sync during it is 7" "7" "$RC"
git merge --abort
run shell::git::flow::sync -y --rebase
t_eq "sync: a rebase conflict is 6" "6" "$RC"
t_has "sync: ...with git rebase --continue" "git rebase --continue" "$ERR"
t_has "sync: ...and the backup is mentioned" "backup: refs/shell-backup/sync/" "$ERR"
git rebase --abort >/dev/null 2>&1
t_eq "sync: after --abort the branch is as before" "work" "$(git symbolic-ref --short HEAD)"

# other branch states
mk_div
git checkout -q --detach HEAD
run shell::git::flow::sync -y --merge
t_eq "sync: a detached HEAD is 1" "1" "$RC"
git checkout -q main
run shell::git::flow::sync -y --merge
t_eq "sync: on the base itself there is nothing to do (0)" "0" "$RC"
git checkout -q work
run shell::git::flow::sync -n --merge --base nope
t_eq "sync: a --base that does not exist is 1" "1" "$RC"
git branch -q develop main
(
	SHELL_GIT_BASE_BRANCH=develop shell::git::flow::sync -n --merge >"$HOME/out" 2>&1
)
t_has "sync: SHELL_GIT_BASE_BRANCH is honored" "git merge --no-edit develop" "$(cat "$HOME/out")"
run shell::git::flow::sync -n --merge --base develop
t_eq "sync --base: the given ref" "git merge --no-edit develop" "$OUT"
gt_remote origin
git remote set-url origin "$HOME/does-not-exist.git"
S0="$(gt_snapshot)"
run shell::git::flow::sync -y --merge --fetch
t_eq "sync --fetch: a failing fetch is 1, nothing changes" "1" "$RC"
t_eq "sync --fetch: ...repository identical" "$S0" "$(gt_snapshot)"
cd "$HOME/plain" || exit 1
run shell::git::flow::sync -y --merge
t_eq "sync: not a repository is 3" "3" "$RC"
cd "$HOME/emptyrepo" || exit 1
run shell::git::flow::sync -y --merge
t_eq "sync: an empty repository is 1" "1" "$RC"
cd "$HOME/bare.git" || exit 1
run shell::git::flow::sync -y --merge
t_eq "sync: a bare repository is 3" "3" "$RC"
cd "$HOME/repo" || exit 1

t_eq "design: one public function per flow action file" "4" "$(grep -c '^shell::git::flow::[a-z]*() {' "$SHELL_TEST_ROOT"/src/lang/git/flow/{feature,release,hotfix,sync}.sh | awk -F: '{ s += $2 } END { print s }')"

t_done
