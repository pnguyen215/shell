#!/usr/bin/env bash
# shell::git::stage::{pick,patch,unstage,discard} on throwaway repositories.
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
t_setup
. "$SHELL_TEST_ROOT/test/support/git_toolkit.sh"

# scan: the private scanner pointed at the current directory (the actions set the root themselves)
scan() {
	_SHELL_GIT_ST_TOP="."
	_SHELL_GIT_ST_PFX=""
	_shell::git::core::stage_scan "$@"
}

nl_name="new
line.txt"
tab_name="with	tab.txt"
quote_name="it's \"quoted\".txt"
uni_name="unicodé-日本.txt"

reset_input() {
	_shell::git::core::input_close
	unset SHELL_GIT_INPUT
	_SHELL_GIT_INPUT_OPEN=""
}

fresh_repo() { # <name>: a repository with two committed files, cwd inside it
	rm -rf "${HOME:?}/$1"
	gt_init "$HOME/$1"
	gt_commit "one" a.txt "alpha"
	gt_commit "two" "b c.txt" "beta"
}

# ---------------------------------------------------------------- usage and environment
gt_fake_fzf
for fn in pick unstage discard patch; do
	out="$(shell::git::stage::$fn -h)"
	t_has "$fn: -h prints usage on stdout" "usage: shell::git::stage::$fn" "$out"
	t_rc "$fn: -h exits 0" 0 shell::git::stage::$fn --help
	shell::git::stage::$fn --nonsense >/dev/null 2>&1
	t_eq "$fn: an unknown option is exit 2" "2" "$?"
done

mkdir "$HOME/notrepo" && cd "$HOME/notrepo" || exit 1
for fn in pick unstage discard patch; do
	shell::git::stage::$fn -- x >/dev/null 2>&1
	t_eq "$fn: outside a repository is exit 3" "3" "$?"
done
git init -q --bare "$HOME/bare.git"
cd "$HOME/bare.git" || exit 1
for fn in pick unstage discard patch; do
	shell::git::stage::$fn -- x >/dev/null 2>&1
	t_eq "$fn: a bare repository (no working tree) is exit 3" "3" "$?"
done

# ---------------------------------------------------------------- stage::pick with paths
fresh_repo r1
printf 'more\n' >>a.txt
printf 'u\n' >"new file.txt"
out="$(shell::git::stage::pick -- a.txt "new file.txt" 2>/dev/null)"
t_eq "pick: stdout is the staged paths only" "a.txt
new file.txt" "$out"
t_eq "pick: both are staged" "M  a.txt
A  \"new file.txt\"" "$(git status --short)"
t_eq "pick: -z prints NUL-separated paths" "b c.txt|" "$(printf 'x\n' >>"b c.txt" && shell::git::stage::pick -z -- "b c.txt" 2>/dev/null | tr '\0' '|')"

# dry-run
fresh_repo r2
printf 'x\n' >>a.txt
snap="$(gt_snapshot)"
out="$(shell::git::stage::pick -n -- a.txt 2>/dev/null)"
t_eq "pick -n: prints the exact command on stdout" "git add -- a.txt" "$out"
t_eq "pick -n: executes nothing" "$snap" "$(gt_snapshot)"
t_eq "pick -n: a name with a space is quoted" 'git add -- b\ c.txt' "$(printf 'x\n' >>"b c.txt" && shell::git::stage::pick -n -- "b c.txt" 2>/dev/null)"

# staged and unstaged on the same file stay independent
fresh_repo r3
printf 'first\n' >>a.txt
git add a.txt
printf 'second\n' >>a.txt
disp="$(scan any rec | tr '\0' '\n')"
t_has "scan: staged and unstaged shown as two independent columns" "modified    modified    a.txt" "${disp#*$'\037'}"
t_eq "scan: raw carries both states" "tMM:a.txt" "$(scan any raw | tr '\0' '\n')"
shell::git::stage::unstage -- a.txt >/dev/null 2>&1
t_eq "unstage: staged part leaves the index" "" "$(git diff --cached --name-only)"
t_eq "unstage: both changes stay in the working tree" "2" "$(grep -c -e first -e second a.txt)"

# ---------------------------------------------------------------- odd names, interactive
fresh_repo r4
gt_fixtures_odd_names
printf 'a\n' >"globX.txt"
printf 'a\n' >"-lead.txt"
t_eq "scan: one status call lists every odd name (9 untracked)" "9" "$(scan any raw | tr -cd '\0' | wc -c | tr -d ' ')"
FAKE_FZF_PICKS="@all" shell::git::stage::pick >/dev/null 2>&1
t_eq "pick @all: every odd file is staged" "9" "$(git diff --cached --name-only -z | tr -cd '\0' | wc -c | tr -d ' ')"
t_rc "pick @all: the file with a newline is staged under its exact name" 0 git ls-files --error-unmatch -- "$nl_name"
t_rc "pick @all: tab name" 0 git ls-files --error-unmatch -- "$tab_name"
t_rc "pick @all: quote name" 0 git ls-files --error-unmatch -- "$quote_name"
t_rc "pick @all: unicode name" 0 git ls-files --error-unmatch -- "$uni_name"
t_rc "pick @all: leading dash" 0 git ls-files --error-unmatch -- "-leading-dash.txt"
t_rc "pick @all: glob characters in a name" 0 git ls-files --error-unmatch -- "glob[*]?.txt"
FAKE_FZF_PICKS="@all" shell::git::stage::unstage >/dev/null 2>&1
t_eq "unstage @all: all unstaged again, still on disk" "0 9" "$(git diff --cached --name-only | wc -l | tr -d ' ') $(git ls-files --others --exclude-standard | wc -l | tr -d ' ')"
t_has "pick: the picker received NUL records (--read0)" "--read0" "$(cat "$FAKE_FZF_DIR/args.1")"

# a glob is not expanded: staging the literal name must not touch its look-alike
fresh_repo r5
printf 'a\n' >"glob[*]?.txt"
printf 'a\n' >"globX.txt"
shell::git::stage::pick -- 'glob[*]?.txt' >/dev/null 2>&1
t_eq "pick: a path is literal, never a pattern" "A  glob[*]?.txt
?? globX.txt" "$(git status --short)"
shell::git::stage::pick -- '*.txt' >/dev/null 2>&1
t_eq "pick: '*.txt' as a path matches nothing (no entry named like that)" "A  glob[*]?.txt
?? globX.txt" "$(git status --short)"

# a single record picked by its visible text
fresh_repo r6
printf 'x\n' >>a.txt
printf 'y\n' >>"b c.txt"
out="$(FAKE_FZF_PICKS="b c.txt" shell::git::stage::pick 2>/dev/null)"
t_eq "pick: only the picked file is staged" "b c.txt" "$out"
t_eq "pick: the other file stays unstaged" " M a.txt
M  \"b c.txt\"" "$(git status --short)"
t_has "pick: the picker shows the independent columns" "modified" "$(cat "$FAKE_FZF_DIR/stdin.$(cat "$FAKE_FZF_DIR/count")")"

# cancel, no terminal
snap="$(gt_snapshot)"
FAKE_FZF_PICKS="" shell::git::stage::pick >/dev/null 2>&1
t_eq "pick: esc is exit 5" "5" "$(
	FAKE_FZF_PICKS="" shell::git::stage::pick >/dev/null 2>&1
	echo $?
)"
t_eq "pick: esc prints nothing on stdout" "" "$(FAKE_FZF_PICKS="" shell::git::stage::pick 2>/dev/null)"
t_eq "pick: esc leaves the repository identical" "$snap" "$(gt_snapshot)"
t_eq "pick: fzf exit 1 (no match) is exit 5" "5" "$(
	FAKE_FZF_PICKS="@rc=1" shell::git::stage::pick >/dev/null 2>&1
	echo $?
)"
t_eq "discard: esc is exit 5, nothing changed" "5 $snap" "$(
	FAKE_FZF_PICKS="" shell::git::stage::discard >/dev/null 2>&1
	echo "$? $(gt_snapshot)"
)"
oldforce="$SHELL_GIT_FORCE_FZF"
unset SHELL_GIT_FORCE_FZF
t_eq "pick: no paths and no terminal is exit 2" "2" "$(
	shell::git::stage::pick </dev/null >/dev/null 2>&1
	echo $?
)"
t_has "pick: ...with a hint" "pass the paths" "$(shell::git::stage::pick </dev/null 2>&1)"
t_eq "unstage: no paths and no terminal is exit 2" "2" "$(
	shell::git::stage::unstage </dev/null >/dev/null 2>&1
	echo $?
)"
t_eq "discard: no paths and no terminal is exit 2" "2" "$(
	shell::git::stage::discard </dev/null >/dev/null 2>&1
	echo $?
)"
t_eq "pick: exit 2 changed nothing" "$snap" "$(gt_snapshot)"

# numbered fallback when fzf is not usable
oldpath="$PATH"
PATH="$(printf '%s' "$PATH" | sed "s|$HOME/gt-bin:||")"
_SHELL_GIT_VER_FZF=0
gt_input 1
out="$(shell::git::stage::pick 2>"$HOME/fallback.err")"
reset_input
t_eq "pick (numbered fallback): number 1 picks the first listed file" "a.txt" "$out"
t_has "pick (numbered fallback): the list is on stderr" "modified" "$(cat "$HOME/fallback.err")"
PATH="$oldpath"
_SHELL_GIT_VER_FZF=""
export SHELL_GIT_FORCE_FZF="$oldforce"

# ---------------------------------------------------------------- conflicts, other states
fresh_repo c1
git checkout -q -b side
gt_commit "side" "clash.txt" "from side"
git checkout -q main
gt_commit "main" "clash.txt" "from main"
git merge side >/dev/null 2>&1
snap="$(gt_snapshot)"
shell::git::stage::pick -- clash.txt >/dev/null 2>&1
t_eq "pick: a conflicted file is exit 6" "6" "$(
	shell::git::stage::pick -- clash.txt >/dev/null 2>&1
	echo $?
)"
t_has "pick: ...pointing at resolving it" "resolve" "$(shell::git::stage::pick -- clash.txt 2>&1)"
t_eq "pick: ...and nothing was staged" "$snap" "$(gt_snapshot)"
t_eq "unstage: conflicted is exit 6" "6" "$(
	shell::git::stage::unstage -- clash.txt >/dev/null 2>&1
	echo $?
)"
t_eq "discard: conflicted is exit 6, even with --yes" "6" "$(
	shell::git::stage::discard -y -- clash.txt >/dev/null 2>&1
	echo $?
)"
t_eq "discard: ...no snapshot was taken, nothing changed" "$snap" "$(gt_snapshot)"
t_eq "scan: the conflicted entry is class c" "cAA:clash.txt" "$(scan any raw | tr '\0' '\n')"
t_has "pick (interactive): the picker lists it as conflicted" "conflicted" "$(
	FAKE_FZF_PICKS="@first" shell::git::stage::pick >/dev/null 2>&1
	cat "$FAKE_FZF_DIR/stdin.$(cat "$FAKE_FZF_DIR/count")"
)"
t_eq "pick (interactive): picking the conflicted one is exit 6" "6" "$(
	FAKE_FZF_PICKS="@first" shell::git::stage::pick >/dev/null 2>&1
	echo $?
)"
git merge --abort

# rename, delete, detached HEAD, linked worktree
fresh_repo s1
git mv "b c.txt" renamed.txt
printf 'z\n' >>renamed.txt
rm a.txt
printf 'n\n' >untracked.txt
raws="$(scan any raw | tr '\0\036' '|~')"
t_has "scan: rename carries both paths" "rRM:renamed.txt~b c.txt" "$raws"
t_has "scan: unstaged delete" "t.D:a.txt" "$raws"
t_has "scan: untracked" "u.?:untracked.txt" "$raws"
FAKE_FZF_PICKS="@all" shell::git::stage::pick >/dev/null 2>&1
t_eq "pick: rename (kept staged), delete and untracked all staged" "D  a.txt
R  \"b c.txt\" -> renamed.txt
A  untracked.txt" "$(git status --short)"
git checkout -q --detach
printf 'q\n' >>untracked.txt
shell::git::stage::pick -- untracked.txt >/dev/null 2>&1
t_eq "pick: works on a detached HEAD" "1" "$(git diff --cached --name-only | grep -c untracked.txt)"
git checkout -q -f main 2>/dev/null
git reset -q --hard 2>/dev/null
git clean -fdq
git worktree add -q "$HOME/wt" -b wtbranch 2>/dev/null
cd "$HOME/wt" || exit 1
printf 'w\n' >wt.txt
shell::git::stage::pick -- wt.txt >/dev/null 2>&1
t_eq "pick: works in a linked worktree" "A  wt.txt" "$(git status --short)"
cd "$HOME/s1" || exit 1

# empty repository
rm -rf "$HOME/empty"
gt_init "$HOME/empty"
printf 'e\n' >e.txt
shell::git::stage::pick -- e.txt >/dev/null 2>&1
t_eq "pick: works in a repository without commits" "A  e.txt" "$(git status --short)"
t_eq "unstage -n: no HEAD uses rm --cached" "git rm --cached -q -- e.txt" "$(shell::git::stage::unstage -n -- e.txt 2>/dev/null)"
shell::git::stage::unstage -- e.txt >/dev/null 2>&1
t_eq "unstage: works in a repository without commits" "?? e.txt" "$(git status --short)"
shell::git::stage::pick -- e.txt >/dev/null 2>&1
shell::git::stage::discard -y -- e.txt >/dev/null 2>&1
t_eq "discard: an added file in an empty repository is removed" "no" "$([ -e e.txt ] && echo yes || echo no)"

# submodule entry
fresh_repo m1
gt_init "$HOME/subsrc" && gt_commit "s1" s.txt "s"
cd "$HOME/m1" || exit 1
git -c protocol.file.allow=always submodule add -q "$HOME/subsrc" sub >/dev/null 2>&1
git commit -q -m "add sub"
(cd sub && printf 'x\n' >>s.txt && git add s.txt && git commit -q -m "sub change")
t_eq "scan: submodule raw (class s)" "s.M:sub" "$(scan any raw | tr '\0' '\n')"
t_has "scan: the picker marks it" "(submodule)" "$(scan any rec | tr '\0' '\n')"
snap="$(gt_snapshot)"
t_eq "discard: a submodule is skipped with a warning, nothing discarded" "0 1" "$(
	shell::git::stage::discard -y -- sub >/dev/null 2>&1
	echo "$? $(shell::git::stage::discard -y -- sub 2>&1 >/dev/null | grep -c 'skipping submodule')"
)"
t_eq "discard: the submodule checkout is intact" "yes" "$([ -f sub/s.txt ] && echo yes || echo no)"
t_eq "discard: ...and the repository unchanged" "$snap" "$(gt_snapshot)"
shell::git::stage::pick -- sub >/dev/null 2>&1
t_eq "pick: a submodule can be staged" "M  sub" "$(git status --short)"
git reset -q 2>/dev/null

# ---------------------------------------------------------------- below the repository root
# status reports root-relative paths; the user types paths relative to the current directory. A path must
# never land on a same-named file elsewhere.
fresh_repo sd
mkdir -p sub
gt_commit "in sub" sub/a.txt "sub original"
printf 'root change\n' >>a.txt
printf 'sub change\n' >>sub/a.txt
printf 'u\n' >sub/new.txt
cd sub || exit 1
out="$(shell::git::stage::pick -- a.txt 2>/dev/null)"
t_eq "subdir: the path is relative to the current directory (stdout is root-relative)" "sub/a.txt" "$out"
t_eq "subdir: only sub/a.txt was staged, not the root a.txt" " M ../a.txt
M  a.txt
?? new.txt" "$(git status --short)"
t_eq "subdir: pick -n names the repository root" "1" "$(shell::git::stage::pick -n -- new.txt 2>/dev/null | grep -c '^git -C .* add -- sub/new.txt$')"
snap="$(gt_snapshot)"
shell::git::stage::discard -y -- a.txt new.txt >/dev/null 2>&1
t_eq "subdir: discard touched sub/ only; the root a.txt change is still there" "1 0 0" "$(grep -c 'root change' ../a.txt) $(grep -c 'sub change' a.txt) $([ -e new.txt ] && echo 1 || echo 0)"
shell::git::stage::unstage -- a.txt >/dev/null 2>&1
t_eq "subdir: unstage on a staged, already discarded path is a no-op" "0" "$(git diff --cached --name-only | wc -l | tr -d ' ')"
t_eq "subdir: '..' is refused (exit 2) before anything runs" "2" "$(
	shell::git::stage::discard -y -- ../a.txt >/dev/null 2>&1
	echo $?
)"
t_eq "subdir: an absolute path inside the repository is accepted" "0" "$(
	printf 'z\n' >>a.txt
	shell::git::stage::pick -- "$HOME/sd/sub/a.txt" >/dev/null 2>&1
	echo $?
)"
t_eq "subdir: an absolute path outside the repository is exit 2" "2" "$(
	shell::git::stage::pick -- /etc/hosts >/dev/null 2>&1
	echo $?
)"
t_eq "subdir: a directory argument covers the files under it" "sub/a.txt" "$(
	printf 'y\n' >>a.txt
	shell::git::stage::pick -- . 2>/dev/null
)"
cd "$HOME/sd" || exit 1

# ---------------------------------------------------------------- unstage
fresh_repo u1
git mv "b c.txt" renamed.txt
printf 'staged\n' >>a.txt
git add a.txt
out="$(shell::git::stage::unstage -- a.txt renamed.txt 2>/dev/null)"
t_eq "unstage: stdout lists the unstaged paths" "a.txt
renamed.txt" "$out"
t_eq "unstage: a rename is undone on both paths (index back to HEAD)" "" "$(git diff --cached --name-only)"
t_eq "unstage: the working tree keeps the change" "1" "$(grep -c staged a.txt)"
printf 'x\n' >>a.txt
git add a.txt
snap="$(gt_snapshot)"
t_has "unstage -n: restore --staged on git >= 2.23" "git restore --staged -- a.txt" "$(shell::git::stage::unstage -n -- a.txt 2>/dev/null)"
t_eq "unstage -n: executes nothing" "$snap" "$(gt_snapshot)"
t_eq "unstage: nothing staged for the path is a no-op with exit 0" "0" "$(
	shell::git::stage::unstage -- "untracked-nothing" >/dev/null 2>&1
	echo $?
)"
FAKE_FZF_PICKS="a.txt" shell::git::stage::unstage >/dev/null 2>&1
t_eq "unstage (interactive): the picked file leaves the index" "" "$(git diff --cached --name-only)"
t_has "unstage (interactive): only staged files were listed" "a.txt" "$(cat "$FAKE_FZF_DIR/stdin.$(cat "$FAKE_FZF_DIR/count")")"

# ---------------------------------------------------------------- discard
fresh_repo d1
printf 'tracked change\n' >>a.txt
printf 'only on disk\n' >"new file.txt"
printf 'staged\n' >>"b c.txt"
git add "b c.txt"
printf 'unstaged on top\n' >>"b c.txt"
snap="$(gt_snapshot)"
gt_git_counter on
gt_input n
shell::git::stage::discard -- a.txt "new file.txt" "b c.txt" >"$HOME/d.out" 2>"$HOME/d.err"
rc=$?
reset_input
t_eq "discard: declining is exit 5" "5" "$rc"
t_eq "discard: declining leaves the repository identical (refs, status, stash)" "$snap" "$(gt_snapshot)"
t_eq "discard: declining printed nothing on stdout" "" "$(cat "$HOME/d.out")"
t_has "discard: the exact file list is shown" "new file.txt" "$(cat "$HOME/d.err")"
t_has "discard: the git clean preview is shown before asking" "Would remove new file.txt" "$(cat "$HOME/d.err")"
t_eq "discard: declining never ran git clean -f" "0" "$(grep -c 'clean -f' "$GT_GIT_LOG")"
t_eq "discard: the dry preview ran" "1" "$(grep -c 'clean -n' "$GT_GIT_LOG")"
t_eq "discard: no snapshot ref when declined" "0" "$(git for-each-ref refs/shell-backup | wc -l | tr -d ' ')"
t_eq "discard: no terminal and no --yes is exit 2, nothing changed" "2 $snap" "$(
	shell::git::stage::discard -- a.txt </dev/null >/dev/null 2>&1
	echo "$? $(gt_snapshot)"
)"
out="$(shell::git::stage::discard -n -- a.txt "new file.txt" 2>/dev/null)"
t_has "discard -n: prints the restore command" "git restore --staged --worktree --source=HEAD -- a.txt" "$out"
t_has "discard -n: prints the clean command for exactly the listed file" 'git clean -f -q -- new\ file.txt' "$out"
t_eq "discard -n: executes nothing and takes no snapshot" "$snap" "$(gt_snapshot)"

out="$(shell::git::stage::discard --yes -- a.txt "new file.txt" "b c.txt" 2>"$HOME/d2.err")"
t_eq "discard --yes: stdout lists the discarded files (in status order)" "a.txt
b c.txt
new file.txt" "$out"
t_eq "discard: the tree is clean" "" "$(git status --short)"
ref="$(git for-each-ref --format='%(refname)' refs/shell-backup/discard)"
t_has "discard: a snapshot ref exists" "refs/shell-backup/discard/" "$ref"
t_has "discard: the recovery command is printed" "git restore --source=$ref --worktree --" "$(cat "$HOME/d2.err")"
t_eq "discard: the snapshot holds the tracked change" "1" "$(git show "${ref}:a.txt" | grep -c 'tracked change')"
t_eq "discard: the snapshot holds the untracked file" "only on disk" "$(git show "${ref}:new file.txt")"
git restore --source="$ref" --worktree -- a.txt "new file.txt" "b c.txt"
t_eq "discard: restoring brings back the tracked change" "1" "$(grep -c 'tracked change' a.txt)"
t_eq "discard: restoring brings back the untracked file" "only on disk" "$(cat "new file.txt")"
t_eq "discard: restoring brings back the unstaged edit too" "1" "$(grep -c 'unstaged on top' "b c.txt")"
t_eq "discard: staged version is the snapshot's second parent" "1" "$(git show "${ref}^2:b c.txt" | grep -c staged)"
t_eq "discard: never reset --hard, never clean -fd" "0" "$(grep -cE 'reset|clean -f?d|clean -d' "$GT_GIT_LOG")"
git checkout -q -- . 2>/dev/null
git clean -fdq
gt_git_counter off

# added file, renamed file, --unstaged-only
fresh_repo d2
printf 'added\n' >added.txt
git add added.txt
git mv "b c.txt" moved.txt
shell::git::stage::discard -y -- added.txt moved.txt >/dev/null 2>&1
t_eq "discard: an added file is removed and a rename is undone (original back)" "" "$(git status --short)"
t_eq "discard: the original of the rename is back" "yes" "$([ -f "b c.txt" ] && echo yes || echo no)"
printf 'staged\n' >>a.txt
git add a.txt
printf 'unstaged\n' >>a.txt
shell::git::stage::discard -y --unstaged-only -- a.txt >/dev/null 2>&1
t_eq "discard --unstaged-only: the staged change survives" "M  a.txt" "$(git status --short)"
t_eq "discard --unstaged-only: only the working tree went back to the index" "1 0" "$(grep -c staged a.txt) $(grep -c unstaged a.txt)"
t_eq "discard: a snapshot ref per call" "2" "$(git for-each-ref refs/shell-backup/discard | wc -l | tr -d ' ')"

# interactive discard of odd names, declined then accepted
fresh_repo d3
gt_fixtures_odd_names
printf 'a\n' >"-leading-dash.txt"
snap="$(gt_snapshot)"
gt_input n
FAKE_FZF_PICKS="@all" shell::git::stage::discard >/dev/null 2>&1
t_eq "discard (interactive, declined): exit 5 and identical" "$snap" "$(gt_snapshot)"
reset_input
gt_input y
FAKE_FZF_PICKS="@all" shell::git::stage::discard >/dev/null 2>&1
rc=$?
reset_input
t_eq "discard (interactive, confirmed): exit 0" "0" "$rc"
t_eq "discard (interactive): every odd file removed" "0" "$(git ls-files --others | wc -l | tr -d ' ')"
dref="$(git for-each-ref --format='%(refname)' refs/shell-backup/discard)"
t_eq "discard (interactive): the snapshot kept the 7 odd files and the 2 tracked ones" "9" "$(git ls-tree -r --name-only -z "$dref" | tr -cd '\0' | wc -c | tr -d ' ')"

# discard refuses to run when the snapshot cannot be taken: make backup_snapshot fail
fresh_repo d4
printf 'keep me\n' >>a.txt
backup_snapshot_real="$(typeset -f _shell::git::core::backup_snapshot)"
_shell::git::core::backup_snapshot() { return 1; }
shell::git::stage::discard -y -- a.txt >/dev/null 2>&1
t_eq "discard: no snapshot, no discard (exit 1)" "1 1" "$(
	shell::git::stage::discard -y -- a.txt >/dev/null 2>&1
	echo "$? $(grep -c 'keep me' a.txt)"
)"
unset -f _shell::git::core::backup_snapshot
_shell::git::core::boot_reload() { :; }
. "$SHELL_TEST_ROOT/src/lang/git/_core/backup.sh"

# ---------------------------------------------------------------- patch
fresh_repo p1
printf 'patched\n' >>a.txt
t_eq "patch: no terminal is exit 2" "2" "$(
	shell::git::stage::patch </dev/null >/dev/null 2>&1
	echo $?
)"
t_eq "patch -n: prints the command" "git add -p -- a.txt" "$(shell::git::stage::patch -n -- a.txt 2>/dev/null)"
snap="$(gt_snapshot)"
shell::git::stage::patch -n -- a.txt >/dev/null 2>&1
t_eq "patch -n: executes nothing" "$snap" "$(gt_snapshot)"
gt_input y
shell::git::stage::patch -- a.txt >/dev/null 2>&1
rc=$?
reset_input
t_eq "patch: scripted answers (SHELL_GIT_INPUT) stage the hunk" "0 M  a.txt" "$rc $(git status --short)"

# ---------------------------------------------------------------- performance and output contract
rm -rf "$HOME/big"
gt_init "$HOME/big"
gt_commit "base" a.txt "x"
for i in $(seq 20); do : >"f$i.txt"; done
gt_git_counter on
FAKE_FZF_PICKS="@first" shell::git::stage::pick >/dev/null 2>&1
small="$(gt_count)"
gt_git_counter off
git reset -q
rm -f f*.txt
for i in $(seq 2000); do : >"f$i.txt"; done
gt_git_counter on
FAKE_FZF_PICKS="@first" shell::git::stage::pick >/dev/null 2>&1
large="$(gt_count)"
t_eq "performance: the same number of git calls for 20 and 2000 changed files" "$small" "$large"
t_eq "performance: ONE status call lists them" "1" "$(grep -c 'status --porcelain=v2' "$GT_GIT_LOG")"
gt_git_counter off

NO_COLOR=1 scan any rec >/dev/null
printf 'x\n' >>a.txt
t_eq "output: no ANSI in picker records under NO_COLOR" "0" "$(NO_COLOR=1 scan any rec | tr '\0' '\n' | grep -c "$(printf '\033')")"
saved="$NO_COLOR"
unset NO_COLOR
t_eq "output: ANSI colors in picker records otherwise" "1" "$([ "$(scan any rec | tr "\0" "\n" | grep -c "$(printf "\033")")" -gt 0 ] && echo 1 || echo 0)"
export NO_COLOR="$saved"
t_eq "output: stdout carries only the path, diagnostics go to stderr" "a.txt" "$(shell::git::stage::pick -- a.txt 2>/dev/null)"

t_done
