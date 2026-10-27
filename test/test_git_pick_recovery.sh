#!/usr/bin/env bash
# Cherry-pick recovery: status, current, conflicts, resolve, remaining, continue, skip, abort, quit.
# Real conflicts in real repositories (single file, several files, a path with a space,
# modify/delete, two conflicts in one sequence, a commit made by hand mid-sequence).
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
busy() { shell::git::commit::pick::in_progress && echo yes || echo no; }
nl='
'

# --- repository 1: f1..f4 on feature, f3 conflicts with main ------------------------------------------------
tpl="$HOME/tpl"
mkdir "$tpl" && cd "$tpl" || exit 1
git init -q && git checkout -q -b main
echo base >f && git add f && git commit -q -m "base"
git checkout -q -b feature
echo one >a && git add a && git commit -q -m "f1: add a"
echo two >b && git add b && git commit -q -m "f2: add b"
echo conflict-feature >f && git add f && git commit -q -m "f3: change f"
echo four >c && git add c && git commit -q -m "f4: add c"
git checkout -q main
echo conflict-main >f && git add f && git commit -q -m "m1: change f on main"
F1="$(git rev-parse feature~3)"
F2="$(git rev-parse feature~2)"
F3="$(git rev-parse feature~1)"
F4="$(git rev-parse feature)"
M1="$(git rev-parse main)"
fresh() {
	cd "$HOME" && rm -rf "$HOME/r" && cp -r "$tpl" "$HOME/r" && cd "$HOME/r" || exit 1
}
# main has m1; pick f2, f3 (conflict), f4 (waiting)
stuck() {
	fresh
	shell::git::commit::pick::apply "$F2" "$F3" "$F4" >/dev/null 2>&1
}

# --- repository 2: three conflicts in one commit (content x2, one with a space, modify/delete) -------------
multi="$HOME/multi"
mkdir "$multi" && cd "$multi" || exit 1
git init -q && git checkout -q -b main
echo base >x.txt && echo base >"y z.txt" && echo base >del.txt && echo keep >ok.txt
git add . && git commit -q -m "base"
git checkout -q -b topic
echo topic >x.txt && echo topic >"y z.txt" && git rm -q del.txt && echo topic-ok >ok.txt
git add . && git commit -q -m "topic: change x, y z, delete del, change ok"
git checkout -q main
echo main >x.txt && echo main >"y z.txt" && echo main-edit >del.txt
git add . && git commit -q -m "main: change x, y z, del"
TOPIC="$(git rev-parse topic)"
multi_stuck() {
	cd "$HOME" && rm -rf "$HOME/r" && cp -r "$multi" "$HOME/r" && cd "$HOME/r" || exit 1
	shell::git::commit::pick::apply "$TOPIC" >/dev/null 2>&1
}

# --- repository 3: two conflicts one after the other ---------------------------------------------------------
seq2="$HOME/seq2"
mkdir "$seq2" && cd "$seq2" || exit 1
git init -q && git checkout -q -b main
echo base >c1 && echo base >c2 && git add . && git commit -q -m "base"
git checkout -q -b topic
echo t1 >c1 && git add c1 && git commit -q -m "A1: c1"
echo t2 >c2 && git add c2 && git commit -q -m "A2: c2"
git checkout -q main
echo m1 >c1 && echo m2 >c2 && git add . && git commit -q -m "main: c1 c2"
A1="$(git rev-parse topic~1)"
A2="$(git rev-parse topic)"
seq2_stuck() {
	cd "$HOME" && rm -rf "$HOME/r" && cp -r "$seq2" "$HOME/r" && cd "$HOME/r" || exit 1
	shell::git::commit::pick::apply "$A1" "$A2" >/dev/null 2>&1
}

# =============================== in_progress ============================================
fresh
t_eq "in_progress: no" "no" "$(busy)"
stuck
t_eq "in_progress: stopped on a conflict" "yes" "$(busy)"
git cherry-pick --abort >/dev/null 2>&1
t_eq "in_progress: no after abort" "no" "$(busy)"

# =============================== status ==================================================
fresh
out="$(r shell::git::commit::pick::status)"
t_has "status: nothing in progress" "No cherry-pick in progress" "$out"
t_has "status: ...exit 1" "RC=1" "$out"
out="$(r shell::git::commit::pick::status -q)"
t_eq "status -q: silent, exit 1" "RC=1" "$out"

stuck
out="$(r shell::git::commit::pick::status)"
t_has "status: exit 0 when in progress" "RC=0" "$out"
t_has "status: the branch" "Cherry-pick in progress on 'main'" "$out"
t_has "status: the commit it stopped on" "Stopped on : $(git rev-parse --short "$F3") f3: change f" "$out"
t_has "status: one waiting" "Remaining  : 1 commit(s)" "$out"
t_has "status: one conflict" "Conflicts  : 1 file(s)" "$out"
t_has "status: the file" "✗ f" "$out"
t_has "status: nothing staged yet" "Staged     : 0 file(s)" "$out"
t_has "status: the next step" "shell::git::commit::pick::resolve" "$out"
out="$(r shell::git::commit::pick::status -q)"
t_eq "status -q: silent, exit 0" "RC=0" "$out"
echo fixed >f
shell::git::commit::pick::resolve >/dev/null 2>&1
out="$(r shell::git::commit::pick::status)"
t_has "status: no conflicts after resolve" "Conflicts  : 0 file(s)" "$out"
t_has "status: the resolved file is staged" "Staged     : 1 file(s)" "$out"
t_has "status: next is continue" "Next: shell::git::commit::pick::continue" "$out"
out="$(r shell::git::commit::pick::status --bogus)"
t_has "status: unknown option" "RC=2" "$out"
t_rc "status -h" 0 shell::git::commit::pick::status -h

# a commit made by hand in the middle of a sequence
stuck
echo fixed >f && git add f && git commit -q -m "manual resolution"
out="$(r shell::git::commit::pick::status)"
t_has "status: between commits is still in progress" "RC=0" "$out"
t_has "status: ...and explains it" "Stopped between commits" "$out"
t_has "status: ...f4 waits (the handled one is not counted)" "Remaining  : 1 commit(s)" "$out"
out="$(r shell::git::commit::pick::remaining)"
t_eq "remaining: between commits, only f4" "$(git rev-parse --short "$F4") f4: add c" "$(printf '%s\n' "$out" | grep -v RC=)"
out="$(r shell::git::commit::pick::continue --no-edit)"
t_has "continue after a manual commit: completes" "RC=0" "$out"
t_eq "continue after a manual commit: f4 applied" "f4: add c" "$(subject)"
t_eq "continue after a manual commit: the manual commit stays" "manual resolution" "$(subject HEAD~1)"

cd "$HOME" && mkdir -p norepo && cd norepo || exit 1
out="$(r shell::git::commit::pick::status)"
t_has "status: outside a repo" "RC=1" "$out"

# =============================== current =================================================
fresh
out="$(r shell::git::commit::pick::current)"
t_has "current: none" "No commit is being cherry-picked" "$out"
t_has "current: none, exit 1" "RC=1" "$out"
stuck
out="$(r shell::git::commit::pick::current)"
t_has "current: exit 0" "RC=0" "$out"
t_has "current: the commit being picked" "f3: change f" "$out"
t_has "current: its author" "Author:" "$out"
t_eq "current --hash: the full hash only" "$F3" "$(shell::git::commit::pick::current --hash 2>/dev/null)"
out="$(r shell::git::commit::pick::current --bogus)"
t_has "current: unknown option" "RC=2" "$out"
t_rc "current -h" 0 shell::git::commit::pick::current -h
cd "$HOME/norepo" || exit 1
out="$(r shell::git::commit::pick::current)"
t_has "current: outside a repo" "RC=1" "$out"

# =============================== conflicts ===============================================
fresh
out="$(r shell::git::commit::pick::conflicts)"
t_has "conflicts: none -> exit 1" "RC=1" "$out"
t_has "conflicts: none -> says so" "No conflicted files" "$out"
stuck
t_eq "conflicts: the path only on stdout" "f" "$(shell::git::commit::pick::conflicts 2>/dev/null)"
shell::git::commit::pick::conflicts >/dev/null 2>&1
t_eq "conflicts: exit 0 when there are some" "0" "$?"
multi_stuck
list="$(shell::git::commit::pick::conflicts 2>/dev/null)"
t_has "conflicts: several (1)" "x.txt" "$list"
t_has "conflicts: a path with a space, intact" "y z.txt" "$list"
t_has "conflicts: modify/delete counts" "del.txt" "$list"
t_eq "conflicts: three files" "3" "$(printf '%s\n' "$list" | wc -l | tr -d ' ')"
t_lacks "conflicts: a clean change is not listed" "ok.txt" "$list"
# outside a cherry-pick: a plain merge conflict is listed too
fresh
git checkout -q -b mrg main~1
echo other >f && git add f && git commit -q -m "other f"
git merge main >/dev/null 2>&1
t_eq "conflicts: also works for a plain merge" "f" "$(shell::git::commit::pick::conflicts 2>/dev/null)"
git merge --abort >/dev/null 2>&1
out="$(r shell::git::commit::pick::conflicts extra)"
t_has "conflicts: stray argument" "RC=2" "$out"
t_rc "conflicts -h" 0 shell::git::commit::pick::conflicts -h
cd "$HOME/norepo" || exit 1
out="$(r shell::git::commit::pick::conflicts)"
t_has "conflicts: outside a repo" "RC=1" "$out"

# =============================== resolve =================================================
fresh
out="$(r shell::git::commit::pick::resolve)"
t_has "resolve: nothing to resolve" "There are no conflicted files" "$out"
t_has "resolve: ...exit 1" "RC=1" "$out"
stuck
out="$(r shell::git::commit::pick::resolve)"
t_has "resolve: refuses files that still have markers" "Conflict markers are still in 1 file(s)" "$out"
t_has "resolve: ...naming the file" "✗ f" "$out"
t_has "resolve: ...exit 1" "RC=1" "$out"
t_eq "resolve: ...and the file is still in conflict" "f" "$(shell::git::commit::pick::conflicts 2>/dev/null)"
out="$(r shell::git::commit::pick::resolve -n)"
t_has "resolve -n: markers are checked before the dry-run too" "RC=1" "$out"
echo fixed >f
out="$(r shell::git::commit::pick::resolve -n)"
t_has "resolve -n: prints the command" "git add -- f" "$out"
t_eq "resolve -n: nothing staged" "f" "$(shell::git::commit::pick::conflicts 2>/dev/null)"
out="$(r shell::git::commit::pick::resolve)"
t_has "resolve: exit 0" "RC=0" "$out"
t_has "resolve: says no conflict is left" "no conflicts left" "$out"
t_eq "resolve: the file is staged" "M  f" "$(git status --short | grep ' f$' | head -n 1)"
t_eq "resolve: no conflicts remain" "1" "$(shell::git::commit::pick::conflicts >/dev/null 2>&1 && echo 0 || echo 1)"

stuck
out="$(r shell::git::commit::pick::resolve --force)"
t_has "resolve --force: stages even with markers" "RC=0" "$out"
t_has "resolve --force: ...the markers are now staged (that is the point of the guard)" "<<<<<<<" "$(git show :f)"

multi_stuck
echo merged >x.txt
out="$(r shell::git::commit::pick::resolve x.txt)"
t_has "resolve: one named file" "RC=0" "$out"
t_has "resolve: ...2 still in conflict" "2 still in conflict" "$out"
echo merged >"y z.txt"
out="$(r shell::git::commit::pick::resolve "y z.txt")"
t_has "resolve: a path with a space" "RC=0" "$out"
out="$(r shell::git::commit::pick::resolve ok.txt)"
t_has "resolve: a file that is not in conflict is refused" "Not a conflicted file: ok.txt" "$out"
t_has "resolve: ...exit 2" "RC=2" "$out"
rm -f del.txt
out="$(r shell::git::commit::pick::resolve del.txt)"
t_has "resolve: modify/delete resolved by deleting" "RC=0" "$out"
t_has "resolve: ...no conflicts left" "no conflicts left" "$out"
t_eq "resolve: ...the deletion is staged" "D  del.txt" "$(git status --short | grep del.txt)"

multi_stuck
echo merged >x.txt && echo merged >"y z.txt"
out="$(r shell::git::commit::pick::resolve)"
t_has "resolve: no names -> all conflicted files (markers gone in two, del.txt kept as is)" "RC=0" "$out"
t_has "resolve: ...all staged" "no conflicts left" "$out"
out="$(r shell::git::commit::pick::resolve --bogus)"
t_has "resolve: unknown option" "RC=2" "$out"
multi_stuck
echo merged >x.txt
out="$(r shell::git::commit::pick::resolve -- x.txt)"
t_has "resolve: -- ends the options" "RC=0" "$out"
t_rc "resolve -h" 0 shell::git::commit::pick::resolve -h
cd "$HOME/norepo" || exit 1
out="$(r shell::git::commit::pick::resolve)"
t_has "resolve: outside a repo" "RC=1" "$out"

# =============================== remaining ===============================================
fresh
out="$(r shell::git::commit::pick::remaining)"
t_has "remaining: nothing in progress" "No cherry-pick in progress" "$out"
t_has "remaining: ...exit 1" "RC=1" "$out"
t_eq "remaining: ...nothing on stdout" "" "$(shell::git::commit::pick::remaining 2>/dev/null)"
stuck
t_eq "remaining: the commits after the current one" "$(git rev-parse --short "$F4") f4: add c" "$(shell::git::commit::pick::remaining 2>/dev/null)"
shell::git::commit::pick::remaining >/dev/null 2>&1
t_eq "remaining: exit 0 when some wait" "0" "$?"
fresh
shell::git::commit::pick::apply "$F3" >/dev/null 2>&1
out="$(r shell::git::commit::pick::remaining)"
t_has "remaining: a single pick has nothing after it" "No commits are waiting" "$out"
t_has "remaining: ...exit 1" "RC=1" "$out"
out="$(r shell::git::commit::pick::remaining extra)"
t_has "remaining: stray argument" "RC=2" "$out"
t_rc "remaining -h" 0 shell::git::commit::pick::remaining -h
cd "$HOME/norepo" || exit 1
out="$(r shell::git::commit::pick::remaining)"
t_has "remaining: outside a repo" "RC=1" "$out"

# =============================== continue ================================================
fresh
out="$(r shell::git::commit::pick::continue)"
t_has "continue: nothing in progress" "nothing to continue" "$out"
t_has "continue: ...exit 1" "RC=1" "$out"
stuck
out="$(r shell::git::commit::pick::continue)"
t_has "continue: refuses while a file is in conflict" "still in conflict" "$out"
t_has "continue: ...naming it" "✗ f" "$out"
t_has "continue: ...exit 1" "RC=1" "$out"
t_lacks "continue: ...git was not even called" "▶ git cherry-pick --continue" "$out"
t_eq "continue: ...still in progress" "yes" "$(busy)"
echo fixed >f && shell::git::commit::pick::resolve >/dev/null 2>&1
out="$(r shell::git::commit::pick::continue -n)"
t_has "continue -n: prints the command" "git cherry-pick --continue" "$out"
t_eq "continue -n: still in progress" "yes" "$(busy)"
out="$(r shell::git::commit::pick::continue --no-edit -n)"
t_has "continue --no-edit -n: the flag is passed" "git cherry-pick --continue --no-edit" "$out"
out="$(r shell::git::commit::pick::continue --no-edit)"
t_has "continue: completes the sequence" "RC=0" "$out"
t_has "continue: says so" "Cherry-pick continued and completed" "$out"
t_eq "continue: f3 was committed (second to last)" "f3: change f" "$(subject HEAD~1)"
t_eq "continue: and f4 applied after it" "f4: add c" "$(subject)"
t_eq "continue: nothing in progress any more" "no" "$(busy)"
t_has "continue: f3 has the resolution" "fixed" "$(git show HEAD~1:f)"

stuck
echo fixed >f && shell::git::commit::pick::resolve >/dev/null 2>&1
out="$(r shell::git::commit::pick::continue)"
t_has "continue: works with the editor (the default)" "RC=0" "$out"

seq2_stuck
t_eq "continue: setup, stopped on the first conflict" "c1" "$(shell::git::commit::pick::conflicts 2>/dev/null)"
echo merged1 >c1 && shell::git::commit::pick::resolve >/dev/null 2>&1
out="$(r shell::git::commit::pick::continue --no-edit)"
t_has "continue: stops again on the next conflict" "RC=1" "$out"
t_has "continue: ...and says so" "Stopped again" "$out"
t_eq "continue: ...the first was committed" "A1: c1" "$(subject)"
t_eq "continue: ...the second is now the conflict" "c2" "$(shell::git::commit::pick::conflicts 2>/dev/null)"
t_eq "continue: ...still in progress" "yes" "$(busy)"
echo merged2 >c2 && shell::git::commit::pick::resolve >/dev/null 2>&1
out="$(r shell::git::commit::pick::continue --no-edit)"
t_has "continue: the second conflict completes it" "RC=0" "$out"
t_eq "continue: ...both applied" "A2: c2" "$(subject)"

out="$(r shell::git::commit::pick::continue --bogus)"
t_has "continue: unknown option" "RC=2" "$out"
t_rc "continue -h" 0 shell::git::commit::pick::continue -h

# =============================== skip ====================================================
stuck
out="$(r shell::git::commit::pick::skip -n)"
t_has "skip -n: prints the command" "git cherry-pick --skip" "$out"
t_eq "skip -n: still in progress" "yes" "$(busy)"
out="$(r shell::git::commit::pick::skip)"
t_has "skip: exit 0" "RC=0" "$out"
t_has "skip: says so" "Commit skipped" "$out"
t_eq "skip: f3 was dropped, f4 applied" "f4: add c" "$(subject)"
t_eq "skip: the commit before is f2" "f2: add b" "$(subject HEAD~1)"
t_eq "skip: nothing in progress" "no" "$(busy)"
t_eq "skip: f3's change is not in the tree" "conflict-main" "$(cat f)"
fresh
out="$(r shell::git::commit::pick::skip)"
t_has "skip: nothing in progress" "nothing to skip" "$out"
t_has "skip: ...exit 1" "RC=1" "$out"
out="$(r shell::git::commit::pick::skip --no-edit)"
t_has "skip: --no-edit is for continue only" "RC=2" "$out"
t_rc "skip -h" 0 shell::git::commit::pick::skip -h

# =============================== abort ===================================================
stuck
out="$(r shell::git::commit::pick::abort -n)"
t_has "abort -n: prints the command" "git cherry-pick --abort" "$out"
t_eq "abort -n: still in progress" "yes" "$(busy)"
out="$(r shell::git::commit::pick::abort)"
t_has "abort: exit 0" "RC=0" "$out"
t_has "abort: warns what it discards" "drops what it changed" "$out"
t_eq "abort: HEAD is back where the sequence started" "$M1" "$(git rev-parse HEAD)"
t_eq "abort: f2 (picked before the conflict) is gone too" "m1: change f on main" "$(subject)"
t_eq "abort: the work tree is clean" "" "$(git status --short)"
t_eq "abort: nothing in progress" "no" "$(busy)"
fresh
out="$(r shell::git::commit::pick::abort)"
t_has "abort: nothing in progress" "nothing to abort" "$out"
t_has "abort: ...exit 1" "RC=1" "$out"
stuck
echo my-resolution >f
shell::git::commit::pick::abort >/dev/null 2>&1
t_eq "abort: discards your manual resolution" "conflict-main" "$(cat f)"
t_rc "abort -h" 0 shell::git::commit::pick::abort -h

# =============================== quit ====================================================
stuck
out="$(r shell::git::commit::pick::quit -n)"
t_has "quit -n: prints the command" "git cherry-pick --quit" "$out"
out="$(r shell::git::commit::pick::quit)"
t_has "quit: exit 0" "RC=0" "$out"
t_has "quit: says nothing was touched" "left as they are" "$out"
t_eq "quit: nothing in progress" "no" "$(busy)"
t_eq "quit: HEAD stays where it is (f2 stays applied)" "f2: add b" "$(subject)"
t_has "quit: the conflict markers are still in the file" "<<<<<<<" "$(cat f)"
t_eq "quit: the file is still unmerged" "f" "$(shell::git::commit::pick::conflicts 2>/dev/null)"
fresh
out="$(r shell::git::commit::pick::quit)"
t_has "quit: nothing in progress (git would silently succeed)" "nothing to quit" "$out"
t_has "quit: ...exit 1" "RC=1" "$out"
t_rc "quit -h" 0 shell::git::commit::pick::quit -h
cd "$HOME/norepo" || exit 1
for fn in continue skip abort quit; do
	out="$(r "shell::git::commit::pick::$fn")"
	t_has "$fn: outside a repo" "Not inside a Git repository" "$out"
done

# =============================== the whole workflow ======================================
stuck
shell::git::commit::pick::status -q
t_eq "workflow: 1. status says busy" "0" "$?"
t_eq "workflow: 2. conflicts lists f" "f" "$(shell::git::commit::pick::conflicts 2>/dev/null)"
echo "resolved by hand" >f
shell::git::commit::pick::resolve >/dev/null 2>&1
t_eq "workflow: 3. resolve leaves none" "no-conflicts" "$(shell::git::commit::pick::conflicts >/dev/null 2>&1 && echo conflicts || echo no-conflicts)"
shell::git::commit::pick::continue --no-edit >/dev/null 2>&1
t_eq "workflow: 4. continue completes" "f4: add c" "$(subject)"
shell::git::commit::pick::status -q
t_eq "workflow: 5. status says idle" "1" "$?"

t_done
