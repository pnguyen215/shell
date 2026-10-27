#!/usr/bin/env bash
# shell::git::commit::pick::backport: new branch vs in-place, -x by default, remote-tracking
# targets, conflicts, the clean-up when nothing can be applied, and every refusal.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

export GIT_CONFIG_NOSYSTEM=1 GIT_EDITOR=true
git config --global user.email "t@example.com"
git config --global user.name "T"

r() {
	"$@" 2>&1
	echo "RC=$?"
}
subject() { git log -1 --format=%s "${1:-HEAD}"; }
branch() { git symbolic-ref --short -q HEAD; }
busy() { shell::git::commit::pick::in_progress && echo yes || echo no; }

# --- template: main with fixes, release/1.0 maintained separately, an origin -------------------------------
tpl="$HOME/tpl"
mkdir "$tpl" && cd "$tpl" || exit 1
git init -q && git checkout -q -b main
echo base >f && echo g >g && git add . && git commit -q -m "base"
git checkout -q -b release/1.0
echo release-f >f && git add f && git commit -q -m "R1: release change to f"
git checkout -q main
echo a >a && git add a && git commit -q -m "M1: add a"
echo b >b && git add b && git commit -q -m "M2: add b"
echo main-f >f && git add f && git commit -q -m "M3: change f"
echo c >c && git add c && git commit -q -m "M4: add c"
git commit -q --allow-empty -m "M5: empty"
git checkout -q -b side main~5
echo s >s && git add s && git commit -q -m "S1: add s"
git checkout -q -b withmerge main~5
echo w >w && git add w && git commit -q -m "W1: add w"
git merge -q --no-ff side -m "merge side" >/dev/null 2>&1
git checkout -q main
git init -q --bare "$HOME/origin.git"
git remote add origin "$HOME/origin.git"
git push -q origin main release/1.0 2>/dev/null
git fetch -q origin 2>/dev/null
M1="$(git rev-parse main~4)"
M2="$(git rev-parse main~3)"
M3="$(git rev-parse main~2)"
M4="$(git rev-parse main~1)"
M5="$(git rev-parse main)"
MG="$(git rev-parse withmerge)"
R1="$(git rev-parse release/1.0)"
short() { git rev-parse --short "$1"; }

fresh() {
	cd "$HOME" && rm -rf "$HOME/r" && cp -r "$tpl" "$HOME/r" && cd "$HOME/r" || exit 1
}

# =============================== the default: a new branch ===============================
fresh
out="$(r shell::git::commit::pick::backport release/1.0 "$M1" "$M2")"
name="backport/release-1.0/$(short "$M1")"
t_has "backport: exit 0" "RC=0" "$out"
t_eq "backport: you are on the new branch" "$name" "$(branch)"
t_eq "backport: built on the target" "$R1" "$(git rev-parse HEAD~2)"
t_eq "backport: M1 then M2" "M1: add a|M2: add b" "$(subject HEAD~1)|$(subject)"
t_has "backport: -x by default (traceability)" "(cherry picked from commit $M2)" "$(git log -1 --format=%B)"
t_has "backport: -x on the first too" "(cherry picked from commit $M1)" "$(git log -1 --format=%B HEAD~1)"
t_has "backport: says where you were" "You were on 'main'" "$out"
t_has "backport: suggests pushing, but does not push" "git push -u <remote> $name" "$out"
t_eq "backport: main is untouched" "$M5" "$(git rev-parse main)"
t_eq "backport: nothing was pushed" "$R1" "$(git --git-dir="$HOME/origin.git" rev-parse release/1.0)"
t_eq "backport: no upstream was configured" "" "$(git config --get "branch.$name.remote")"

fresh
shell::git::commit::pick::backport --no-reference release/1.0 "$M1" >/dev/null 2>&1
t_lacks "backport --no-reference: no source line" "cherry picked" "$(git log -1 --format=%B)"
fresh
shell::git::commit::pick::backport -s release/1.0 "$M1" >/dev/null 2>&1
t_has "backport -s: Signed-off-by" "Signed-off-by: T" "$(git log -1 --format=%B)"
fresh
out="$(r shell::git::commit::pick::backport --allow-empty release/1.0 "$M5")"
t_has "backport --allow-empty: an empty commit is kept" "RC=0" "$out"
t_eq "backport --allow-empty: it is on the branch" "M5: empty" "$(subject)"

fresh
out="$(r shell::git::commit::pick::backport -b hotfix/login release/1.0 "$M1")"
t_has "backport -b: exit 0" "RC=0" "$out"
t_eq "backport -b: the chosen name" "hotfix/login" "$(branch)"
fresh
git branch hotfix/login main
out="$(r shell::git::commit::pick::backport --branch hotfix/login release/1.0 "$M1")"
t_has "backport -b: an existing name is refused" "already exists" "$out"
t_has "backport -b: ...exit 1" "RC=1" "$out"
t_eq "backport -b: ...nothing changed" "main" "$(branch)"
out="$(r shell::git::commit::pick::backport -n --branch hotfix/login release/1.0 "$M1")"
t_has "backport -b: an existing name is refused before the dry-run too (our message, not git's)" "A branch named 'hotfix/login' already exists" "$out"
t_has "backport -b: ...dry-run exit 1" "RC=1" "$out"
t_lacks "backport -b: ...no commands are printed" "git cherry-pick" "$out"
out="$(r shell::git::commit::pick::backport -b "bad name" release/1.0 "$M1")"
t_has "backport -b: invalid name" "RC=2" "$out"
out="$(r shell::git::commit::pick::backport --branch=ok/name release/1.0 "$M1")"
t_has "backport --branch=: form" "RC=0" "$out"

fresh
git branch "backport/release-1.0/$(short "$M1")" main
shell::git::commit::pick::backport release/1.0 "$M1" >/dev/null 2>&1
t_eq "backport: a taken default name gets a suffix" "backport/release-1.0/$(short "$M1")-2" "$(branch)"

# =============================== in place ================================================
fresh
out="$(r shell::git::commit::pick::backport --in-place release/1.0 "$M1" "$M2")"
t_has "backport --in-place: exit 0" "RC=0" "$out"
t_eq "backport --in-place: on the target branch itself" "release/1.0" "$(branch)"
t_eq "backport --in-place: applied there" "M2: add b" "$(subject)"
t_eq "backport --in-place: no backport/* branch was created" "" "$(git branch --list 'backport/*')"
fresh
out="$(r shell::git::commit::pick::backport --in-place origin/release/1.0 "$M1")"
t_has "backport --in-place: needs a local branch" "needs a local branch" "$out"
t_has "backport --in-place: ...exit 1" "RC=1" "$out"
out="$(r shell::git::commit::pick::backport --in-place -b x release/1.0 "$M1")"
t_has "backport: --in-place and --branch are exclusive" "cannot be combined" "$out"
t_has "backport: ...usage error" "RC=2" "$out"

# =============================== remote-tracking target ====================================
fresh
git branch -q -D release/1.0
out="$(r shell::git::commit::pick::backport origin/release/1.0 "$M1")"
t_has "backport: a remote-tracking target" "RC=0" "$out"
t_eq "backport: built on origin/release/1.0" "$R1" "$(git rev-parse HEAD~1)"
t_eq "backport: the new branch name is safe" "backport/origin-release-1.0/$(short "$M1")" "$(branch)"
t_eq "backport: no tracking set up" "" "$(git config --get "branch.$(branch).remote")"

# =============================== dry-run =================================================
fresh
out="$(r shell::git::commit::pick::backport -n release/1.0 "$M1" "$M2")"
t_has "backport -n: exit 0" "RC=0" "$out"
t_has "backport -n: the branch command" "git checkout -b $name --no-track release/1.0" "$(printf '%s\n' "$out" | sed "s|backport/release-1.0/[0-9a-f]*|$name|")"
t_has "backport -n: the pick command" "git cherry-pick -x $M1 $M2" "$out"
t_eq "backport -n: still on main" "main" "$(branch)"
t_eq "backport -n: no branch created" "" "$(git branch --list 'backport/*')"
out="$(r shell::git::commit::pick::backport -n --in-place release/1.0 "$M1")"
t_has "backport -n --in-place: switches the target" "git checkout release/1.0" "$out"
t_eq "backport -n --in-place: still on main" "main" "$(branch)"

# =============================== conflicts ===============================================
fresh
out="$(r shell::git::commit::pick::backport release/1.0 "$M2" "$M3" "$M4")"
t_has "backport: a conflict stops it (exit 1)" "RC=1" "$out"
t_eq "backport: you stay on the backport branch" "backport/release-1.0/$(short "$M2")" "$(branch)"
t_eq "backport: a cherry-pick is in progress" "yes" "$(busy)"
t_has "backport: the way out is explained" "shell::git::commit::pick::abort, then git checkout main and git branch -D" "$out"
t_eq "backport: M2 was applied before the conflict" "M2: add b" "$(subject)"
t_eq "backport: M4 waits" "$(short "$M4") M4: add c" "$(shell::git::commit::pick::remaining 2>/dev/null)"
shell::git::commit::pick::abort >/dev/null 2>&1
git checkout -q main
git branch -q -D "backport/release-1.0/$(short "$M2")" 2>/dev/null
t_eq "backport: after abort and checkout, back on main" "main" "$(branch)"

fresh
out="$(r shell::git::commit::pick::backport --in-place release/1.0 "$M3")"
t_has "backport --in-place: the conflict message has no branch -D" "RC=1" "$out"
t_lacks "backport --in-place: ...since no branch was created" "git branch -D" "$out"
shell::git::commit::pick::abort >/dev/null 2>&1

# =============================== nothing to apply: clean up ============================================
fresh
shell::git::commit::pick::backport --in-place release/1.0 "$M1" >/dev/null 2>&1
git checkout -q main
out="$(r shell::git::commit::pick::backport release/1.0 "$M1")"
t_has "backport: already in the target (by patch) -> nothing to apply" "a patch-equivalent commit is already in" "$out"
t_has "backport: ...exit 1" "RC=1" "$out"
t_eq "backport: nothing to apply happens before any branch switch" "main" "$(branch)"
t_eq "backport: ...and no branch was created" "" "$(git branch --list 'backport/*')"
out="$(r shell::git::commit::pick::backport release/1.0 "$M5")"
t_has "backport: an empty commit alone -> nothing to apply" "empty commit" "$out"
t_has "backport: ...exit 1" "RC=1" "$out"
t_eq "backport: ...still on main" "main" "$(branch)"

# =============================== the clean-up, simulated (apply fails) =========================================
# No real failure reaches that code (the plan is checked before the switch), so apply is replaced.
fresh
out="$(
	shell::git::commit::pick::apply() { return 1; }
	r shell::git::commit::pick::backport release/1.0 "$M1"
)"
t_has "clean-up: apply failed with nothing done -> exit 1" "RC=1" "$out"
t_has "clean-up: ...the empty branch is announced as removed" "was removed and you are back on 'main'" "$out"
t_eq "clean-up: ...back on the original branch" "main" "$(branch)"
t_eq "clean-up: ...and the new branch is gone" "" "$(git branch --list 'backport/*')"

fresh
git checkout -q --detach main
detached="$(git rev-parse HEAD)"
out="$(
	shell::git::commit::pick::apply() { return 1; }
	r shell::git::commit::pick::backport release/1.0 "$M1"
)"
t_eq "clean-up: from a detached HEAD, back on the same commit" "$detached" "$(git rev-parse HEAD)"
t_eq "clean-up: ...detached again" "" "$(branch)"
t_eq "clean-up: ...and no branch left" "" "$(git branch --list 'backport/*')"

# data safety: if apply made a commit before failing, the branch is NOT deleted
fresh
out="$(
	shell::git::commit::pick::apply() {
		git commit -q --allow-empty -m "partial work"
		return 1
	}
	r shell::git::commit::pick::backport release/1.0 "$M1"
)"
t_has "clean-up: failure after a commit -> exit 1" "RC=1" "$out"
t_lacks "clean-up: ...the branch is NOT announced as removed" "was removed" "$out"
t_eq "clean-up: ...you stay on it" "backport/release-1.0/$(short "$M1")" "$(branch)"
t_eq "clean-up: ...with the partial work intact" "partial work" "$(subject)"

fresh
out="$(
	shell::git::commit::pick::apply() { return 1; }
	r shell::git::commit::pick::backport --in-place release/1.0 "$M1"
)"
t_has "clean-up: --in-place failure -> exit 1" "RC=1" "$out"
t_eq "clean-up: --in-place never deletes the target branch" "release/1.0" "$(branch)"
t_eq "clean-up: ...it still exists" "$R1" "$(git rev-parse release/1.0)"

# =============================== refusals ===============================================
fresh
echo dirty >>f
out="$(r shell::git::commit::pick::backport release/1.0 "$M1")"
t_has "backport: uncommitted changes are refused" "uncommitted change(s)" "$out"
t_has "backport: ...exit 1" "RC=1" "$out"
t_eq "backport: ...still on main" "main" "$(branch)"
t_eq "backport: ...no branch created" "" "$(git branch --list 'backport/*')"
git checkout -q -- f
echo untracked >untracked.txt
out="$(r shell::git::commit::pick::backport release/1.0 "$M1")"
t_has "backport: untracked files do not matter" "RC=0" "$out"

fresh
out="$(r shell::git::commit::pick::backport nope "$M1")"
t_has "backport: invalid target" "Not a valid commit: 'nope'" "$out"
t_has "backport: ...exit 1" "RC=1" "$out"
out="$(r shell::git::commit::pick::backport release/1.0 nope)"
t_has "backport: invalid revision" "RC=1" "$out"
t_eq "backport: ...nothing created" "" "$(git branch --list 'backport/*')"
out="$(r shell::git::commit::pick::backport)"
t_has "backport: no target" "A target branch is required" "$out"
t_has "backport: ...exit 2" "RC=2" "$out"
out="$(r shell::git::commit::pick::backport release/1.0)"
t_has "backport: no commits" "At least one commit" "$out"
t_has "backport: ...exit 2" "RC=2" "$out"
out="$(r shell::git::commit::pick::backport --bogus release/1.0 "$M1")"
t_has "backport: unknown option" "RC=2" "$out"
out="$(r shell::git::commit::pick::backport -b)"
t_has "backport: -b needs a value" "RC=2" "$out"
out="$(r shell::git::commit::pick::backport release/1.0 "$MG")"
t_has "backport: a merge commit is refused" "is a merge commit" "$out"
t_eq "backport: ...before any branch is created" "" "$(git branch --list 'backport/*')"

fresh
git checkout -q release/1.0
shell::git::commit::pick::apply "$M3" >/dev/null 2>&1
t_eq "backport: setup, a real conflict is in progress" "yes" "$(busy)"
out="$(r shell::git::commit::pick::backport release/1.0 "$M1")"
t_has "backport: refused while a cherry-pick is in progress" "already in progress" "$out"
t_has "backport: ...exit 1" "RC=1" "$out"
t_eq "backport: ...and the branch was not switched" "release/1.0" "$(branch)"
shell::git::commit::pick::abort >/dev/null 2>&1

# a detached HEAD is restored when nothing could be applied
fresh
shell::git::commit::pick::backport --in-place release/1.0 "$M1" >/dev/null 2>&1
git checkout -q --detach main
detached="$(git rev-parse HEAD)"
out="$(r shell::git::commit::pick::backport release/1.0 "$M1")"
t_has "backport: nothing to apply from a detached HEAD" "RC=1" "$out"
t_eq "backport: ...HEAD is where it was" "$detached" "$(git rev-parse HEAD)"

cd "$HOME" && mkdir -p norepo && cd norepo || exit 1
out="$(r shell::git::commit::pick::backport release/1.0 abc)"
t_has "backport: outside a repo" "Not inside a Git repository" "$out"
t_rc "backport -h" 0 shell::git::commit::pick::backport -h
t_has "backport help" "--in-place" "$T_OUT"

t_done
