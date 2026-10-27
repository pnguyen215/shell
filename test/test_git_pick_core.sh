#!/usr/bin/env bash
# Cherry-pick core: validate, apply (+ no_commit, ff, merge, empty, with_reference, signoff),
# range, preview, equivalent. Real repositories; nothing is mocked.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

export GIT_CONFIG_NOSYSTEM=1 GIT_EDITOR=true
git config --global user.email "t@example.com"
git config --global user.name "T"

# --- template repository, copied for every scenario ---------------------------------------------
tpl="$HOME/tpl"
mkdir "$tpl" && cd "$tpl" || exit 1
git init -q && git checkout -q -b main
echo base >f && git add f && git commit -q -m "base"
git checkout -q -b feature
echo one >a && git add a && git commit -q -m "f1: add a"
echo two >b && git add b && git commit -q -m "f2: add b"
echo conflict-feature >f && git add f && git commit -q -m "f3: change f"
echo four >c && git add c && git commit -q -m "f4: add c"
git commit -q --allow-empty -m "f5: empty"
git tag -a v1 -m "tag on f5" feature~4 2>/dev/null
git checkout -q main
echo conflict-main >f && git add f && git commit -q -m "m1: change f on main"
git checkout -q -b side main~1
echo s >s && git add s && git commit -q -m "s1: add s"
git checkout -q -b withmerge main~1
echo w >w && git add w && git commit -q -m "w1: add w"
git merge -q --no-ff side -m "merge side" >/dev/null 2>&1
git checkout -q main
B="$(git rev-parse main~1)"
M1="$(git rev-parse main)"
F1="$(git rev-parse feature~4)"
F2="$(git rev-parse feature~3)"
F3="$(git rev-parse feature~2)"
F4="$(git rev-parse feature~1)"
F5="$(git rev-parse feature)"
MG="$(git rev-parse withmerge)"
W1="$(git rev-parse withmerge^)"
S1="$(git rev-parse side)"

fresh() {
	cd "$HOME" && rm -rf "$HOME/r" && cp -r "$tpl" "$HOME/r" && cd "$HOME/r" || exit 1
}
# r <cmd...> -> output then RC=<n>
r() {
	"$@" 2>&1
	echo "RC=$?"
}
subject() { git log -1 --format=%s "${1:-HEAD}"; }
nl='
'

# =============================== validate ================================================
fresh
out="$(shell::git::commit::pick::validate "$F1" 2>&1)"
t_eq "validate: a full hash prints itself" "$F1" "$out"
t_eq "validate: a short hash is expanded" "$F1" "$(shell::git::commit::pick::validate "$(git rev-parse --short "$F1")" 2>&1)"
t_eq "validate: a branch resolves to its tip" "$F5" "$(shell::git::commit::pick::validate feature 2>&1)"
t_eq "validate: HEAD~1" "$B" "$(shell::git::commit::pick::validate HEAD~1 2>&1)"
t_eq "validate: an annotated tag is peeled to the commit" "$F1" "$(shell::git::commit::pick::validate v1 2>&1)"
t_eq "validate: several, in order" "$F2${nl}$F1" "$(shell::git::commit::pick::validate "$F2" "$F1" 2>&1)"
out="$(r shell::git::commit::pick::validate nope)"
t_has "validate: unknown revision reported" "Not a valid commit: 'nope'" "$out"
t_has "validate: unknown revision exit 1" "RC=1" "$out"
t_eq "validate: one bad among good prints NOTHING on stdout" "" "$(shell::git::commit::pick::validate "$F1" nope 2>/dev/null)"
shell::git::commit::pick::validate "$F1" nope >/dev/null 2>&1
t_eq "validate: one bad among good fails" "1" "$?"
t_eq "validate: a tree is not a commit" "1" "$(shell::git::commit::pick::validate "feature^{tree}" >/dev/null 2>&1 && echo 0 || echo 1)"
t_eq "validate: empty string" "1" "$(shell::git::commit::pick::validate '' >/dev/null 2>&1 && echo 0 || echo 1)"
t_eq "validate: a dash-leading name after --" "1" "$(shell::git::commit::pick::validate -- -x >/dev/null 2>&1 && echo 0 || echo 1)"
out="$(r shell::git::commit::pick::validate -q "$F1")"
t_eq "validate -q: valid prints nothing, exit 0" "RC=0" "$out"
out="$(r shell::git::commit::pick::validate -q nope)"
t_eq "validate -q: invalid prints nothing, exit 1" "RC=1" "$out"
out="$(r shell::git::commit::pick::validate)"
t_has "validate: no argument" "RC=2" "$out"
out="$(r shell::git::commit::pick::validate --bogus x)"
t_has "validate: unknown option" "RC=2" "$out"
t_rc "validate -h" 0 shell::git::commit::pick::validate -h
cd "$HOME" && mkdir -p norepo && cd norepo || exit 1
out="$(r shell::git::commit::pick::validate HEAD)"
t_has "validate: outside a repo" "RC=1" "$out"

# =============================== apply ===================================================
fresh
out="$(r shell::git::commit::pick::apply "$F1")"
t_has "apply: succeeded" "RC=0" "$out"
t_eq "apply: the commit is on top" "f1: add a" "$(subject)"
t_eq "apply: onto the previous tip" "$M1" "$(git rev-parse HEAD~1)"
t_has "apply: the file arrived" "one" "$(cat a)"
t_has "apply: reports the plan" "Applying 1 commit(s) onto 'main'" "$out"

fresh
shell::git::commit::pick::apply "$F2" "$F1" >/dev/null 2>&1
t_eq "apply: several commits keep the order given (first)" "f2: add b" "$(subject HEAD~1)"
t_eq "apply: ...(second)" "f1: add a" "$(subject)"

fresh
shell::git::commit::pick::apply -x "$F1" >/dev/null 2>&1
t_has "apply -x: records the source" "(cherry picked from commit $F1)" "$(git log -1 --format=%B)"
fresh
shell::git::commit::pick::apply --reference "$F1" >/dev/null 2>&1
t_has "apply --reference: long form" "(cherry picked from commit" "$(git log -1 --format=%B)"
fresh
shell::git::commit::pick::apply -s "$F1" >/dev/null 2>&1
t_has "apply -s: Signed-off-by trailer" "Signed-off-by: T <t@example.com>" "$(git log -1 --format=%B)"
fresh
shell::git::commit::pick::apply -x -s "$F1" >/dev/null 2>&1
t_has "apply -x -s: both" "Signed-off-by" "$(git log -1 --format=%B)"

fresh
out="$(r shell::git::commit::pick::apply --no-commit "$F1" "$F2")"
t_has "apply --no-commit: succeeded" "RC=0" "$out"
t_eq "apply --no-commit: HEAD did not move" "$M1" "$(git rev-parse HEAD)"
t_has "apply --no-commit: changes are staged" "A  a" "$(git status --short)"
t_has "apply --no-commit: both commits" "A  b" "$(git status --short)"
t_has "apply --no-commit: says what to do" "run git commit" "$out"

fresh
out="$(r shell::git::commit::pick::apply -n -x "$F1" "$F2")"
t_has "apply -n: prints the command" "git cherry-pick -x $F1 $F2" "$out"
t_eq "apply -n: HEAD unchanged" "$M1" "$(git rev-parse HEAD)"
t_rc "apply -n: nothing applied" 1 test -e a

fresh
git checkout -q -b ffb "$B"
out="$(r shell::git::commit::pick::apply --ff "$F1")"
t_has "apply --ff: succeeded" "RC=0" "$out"
t_eq "apply --ff: fast-forwarded (same hash as the source)" "$F1" "$(git rev-parse HEAD)"
fresh
for bad in "--ff -x" "--ff -s" "--ff --no-commit"; do
	# shellcheck disable=SC2086
	out="$(r shell::git::commit::pick::apply $bad "$F1")"
	t_has "apply [$bad]: refused as git does" "RC=2" "$out"
done

# merge commits
fresh
out="$(r shell::git::commit::pick::apply "$MG")"
t_has "apply: a merge needs -m" "is a merge commit" "$out"
t_has "apply: ...and points to pick::merge" "pick::merge" "$out"
t_has "apply: ...exit 1" "RC=1" "$out"
t_eq "apply: ...nothing applied" "$M1" "$(git rev-parse HEAD)"
out="$(r shell::git::commit::pick::apply -m 1 "$MG")"
t_has "apply -m 1: a merge works" "RC=0" "$out"
fresh
out="$(r shell::git::commit::pick::apply -m 3 "$MG")"
t_has "apply -m 3: out of range" "has only 2 parents" "$out"
t_has "apply -m 3: exit 1" "RC=1" "$out"
fresh
out="$(r shell::git::commit::pick::apply -m 1 "$F1")"
t_has "apply -m on a non-merge" "is not a merge commit" "$out"
for bad in "-m 0" "-m x" "-m -1" "-m" "--mainline="; do
	# shellcheck disable=SC2086
	out="$(r shell::git::commit::pick::apply $bad "$MG")"
	t_has "apply: invalid mainline [$bad]" "RC=2" "$out"
done
fresh
out="$(r shell::git::commit::pick::apply --mainline=1 "$MG")"
t_has "apply --mainline=1 form" "RC=0" "$out"

# already there / empty / duplicates
fresh
shell::git::commit::pick::apply "$F1" >/dev/null 2>&1
out="$(r shell::git::commit::pick::apply "$F1")"
t_has "apply: a patch already picked is skipped" "patch-equivalent commit is already in HEAD" "$out"
t_has "apply: ...and there is nothing to apply (exit 1)" "RC=1" "$out"
t_eq "apply: ...HEAD did not move" "1" "$([ "$(subject)" = "f1: add a" ] && echo 1 || echo 0)"
t_eq "apply: ...no cherry-pick was left in progress" "1" "$(shell::git::commit::pick::in_progress && echo 0 || echo 1)"
out="$(r shell::git::commit::pick::apply "$M1")"
t_has "apply: a commit already in HEAD is skipped" "already contained in HEAD" "$out"
t_has "apply: ...exit 1" "RC=1" "$out"
t_eq "apply: nothing in progress after the skip" "1" "$(shell::git::commit::pick::in_progress && echo 0 || echo 1)"

fresh
out="$(r shell::git::commit::pick::apply "$F5")"
t_has "apply: an empty commit is skipped" "it is an empty commit" "$out"
t_has "apply: ...exit 1" "RC=1" "$out"
out="$(r shell::git::commit::pick::apply --allow-empty "$F5")"
t_has "apply --allow-empty: keeps it" "RC=0" "$out"
t_eq "apply --allow-empty: the empty commit is on top" "f5: empty" "$(subject)"

fresh
shell::git::commit::pick::apply "$F1" "$F1" "$F2" >/dev/null 2>&1
t_eq "apply: a duplicate hash is applied once" "$((2 + 1))" "$(git rev-list --count HEAD ^"$B")"
fresh
shell::git::commit::pick::apply "$F1" "$M1" "$F2" >/dev/null 2>&1
t_eq "apply: an already-contained one in the list is dropped, the rest applied" "f2: add b" "$(subject)"

# usage and guards
fresh
for bad in "" "--bogus $F1" "-z"; do
	# shellcheck disable=SC2086
	out="$(r shell::git::commit::pick::apply $bad)"
	t_has "apply: invalid usage [$bad]" "RC=2" "$out"
done
out="$(r shell::git::commit::pick::apply "$F1" nope)"
t_has "apply: an invalid revision" "Not a valid commit: 'nope'" "$out"
t_has "apply: ...exit 1" "RC=1" "$out"
t_eq "apply: ...and nothing was applied" "$M1" "$(git rev-parse HEAD)"
out="$(r shell::git::commit::pick::apply -- "$F1")"
t_has "apply: -- ends the options" "RC=0" "$out"

fresh
echo staged >s2 && git add s2
out="$(r shell::git::commit::pick::apply "$F1")"
t_has "apply: staged changes are refused" "staged changes" "$out"
t_has "apply: ...exit 1" "RC=1" "$out"
out="$(r shell::git::commit::pick::apply --no-commit "$F1")"
t_has "apply --no-commit: allowed with staged changes" "RC=0" "$out"
fresh
echo more >>f
out="$(r shell::git::commit::pick::apply "$F1")"
t_has "apply: unstaged edits are fine" "RC=0" "$out"
t_has "apply: ...and are kept" "more" "$(cat f)"
fresh
git checkout -q --detach
out="$(r shell::git::commit::pick::apply "$F1")"
t_has "apply: works on a detached HEAD" "RC=0" "$out"
t_has "apply: ...and says so" "detached HEAD" "$out"

fresh
out="$(r shell::git::commit::pick::apply "$F3")"
t_has "apply: a conflict stops with exit 1" "RC=1" "$out"
t_has "apply: ...and shows the way forward" "pick::status" "$out"
t_eq "apply: ...leaving a cherry-pick in progress" "0" "$(shell::git::commit::pick::in_progress && echo 0 || echo 1)"
out="$(r shell::git::commit::pick::apply "$F1")"
t_has "apply: no new pick while one is in progress" "already in progress" "$out"
t_has "apply: ...exit 1" "RC=1" "$out"
git cherry-pick --abort >/dev/null 2>&1

fresh
echo x >MERGE_HEAD_TEST
git rev-parse HEAD >"$(git rev-parse --git-path MERGE_HEAD)"
out="$(r shell::git::commit::pick::apply "$F1")"
t_has "apply: refused during a merge" "MERGE_HEAD" "$out"
rm -f "$(git rev-parse --git-path MERGE_HEAD)"

cd "$HOME/norepo" || exit 1
out="$(r shell::git::commit::pick::apply "$F1")"
t_has "apply: outside a repo" "Not inside a Git repository" "$out"
t_rc "apply -h" 0 shell::git::commit::pick::apply -h

# =============================== wrappers ================================================
fresh
for fn in no_commit ff merge empty with_reference signoff; do
	t_rc "$fn -h" 0 "shell::git::commit::pick::$fn" -h
	t_has "$fn help mentions its name" "shell::git::commit::pick::$fn" "$T_OUT"
done
out="$(r shell::git::commit::pick::no_commit -n "$F1")"
t_has "no_commit: adds --no-commit" "git cherry-pick --no-commit $F1" "$out"
out="$(r shell::git::commit::pick::ff -n "$F1")"
t_has "ff: adds --ff" "git cherry-pick --ff $F1" "$out"
out="$(r shell::git::commit::pick::empty -n "$F5")"
t_has "empty: adds --allow-empty" "git cherry-pick --allow-empty $F5" "$out"
out="$(r shell::git::commit::pick::with_reference -n "$F1")"
t_has "with_reference: adds -x" "git cherry-pick -x $F1" "$out"
out="$(r shell::git::commit::pick::signoff -n "$F1")"
t_has "signoff: adds -s" "git cherry-pick -s $F1" "$out"
out="$(r shell::git::commit::pick::merge -n -m 1 "$MG")"
t_has "merge: passes -m" "git cherry-pick -m 1 $MG" "$out"
out="$(r shell::git::commit::pick::merge -n "$MG")"
t_has "merge: -m is required" "-m <parent-number> is required" "$out"
t_has "merge: -m missing is usage error" "RC=2" "$out"
out="$(r shell::git::commit::pick::merge -n --mainline=2 "$MG")"
t_has "merge: --mainline=N form" "-m 2" "$out"

fresh
shell::git::commit::pick::with_reference "$F2" >/dev/null 2>&1
t_has "with_reference: real run records the source" "(cherry picked from commit $F2)" "$(git log -1 --format=%B)"
fresh
shell::git::commit::pick::signoff "$F2" >/dev/null 2>&1
t_has "signoff: real run adds the trailer" "Signed-off-by: T" "$(git log -1 --format=%B)"
fresh
shell::git::commit::pick::no_commit "$F2" >/dev/null 2>&1
t_eq "no_commit: real run does not commit" "$M1" "$(git rev-parse HEAD)"
t_has "no_commit: real run stages" "A  b" "$(git status --short)"
fresh
shell::git::commit::pick::empty "$F5" >/dev/null 2>&1
t_eq "empty: real run keeps the empty commit" "f5: empty" "$(subject)"
fresh
git checkout -q -b ffb2 "$B"
shell::git::commit::pick::ff "$F1" >/dev/null 2>&1
t_eq "ff: real run fast-forwards" "$F1" "$(git rev-parse HEAD)"
fresh
shell::git::commit::pick::merge -m 1 "$MG" >/dev/null 2>&1
t_eq "merge: real run applies the merge against parent 1" "1" "$([ -e s ] && echo 1 || echo 0)"
out="$(r shell::git::commit::pick::with_reference --ff "$F1")"
t_has "with_reference + --ff is refused (git forbids it)" "RC=2" "$out"

# =============================== range ===================================================
fresh
out="$(r shell::git::commit::pick::range -n "$B..feature")"
t_has "range: dry-run exit 0" "RC=0" "$out"
t_has "range: counts the commits" "Range $B..feature: 5 commit(s)" "$out"
t_has "range: the empty commit is skipped with a warning" "f5: empty" "$(printf '%s\n' "$out" | grep -i 'skipping')"
plan="$(printf '%s\n' "$out" | grep '•' | sed 's/.*• [0-9a-f]* //' | tr '\n' ',')"
t_eq "range: oldest first (dependency order)" "f1: add a,f2: add b,f3: change f,f4: add c," "$plan"
t_has "range: one cherry-pick command" "git cherry-pick" "$out"
t_eq "range: dry-run changed nothing" "$M1" "$(git rev-parse HEAD)"

fresh
out="$(r shell::git::commit::pick::range "$F1^..$F2")"
t_has "range: A^..B includes A" "RC=0" "$out"
t_eq "range: both applied, oldest first (1)" "f1: add a" "$(subject HEAD~1)"
t_eq "range: both applied, oldest first (2)" "f2: add b" "$(subject)"
fresh
out="$(r shell::git::commit::pick::range "$F1..$F2")"
t_has "range: A..B excludes A" "Range $F1..$F2: 1 commit(s)" "$out"
fresh
shell::git::commit::pick::range -x "$F1^..$F1" >/dev/null 2>&1
t_has "range: -x is passed on" "(cherry picked from commit $F1)" "$(git log -1 --format=%B)"
fresh
out="$(r shell::git::commit::pick::range --no-commit "$F1^..$F2")"
t_has "range: --no-commit is passed on" "A  b" "$(git status --short)"

fresh
out="$(r shell::git::commit::pick::range "$B..withmerge")"
t_has "range: merges are refused" "contains 1 merge commit(s)" "$out"
t_has "range: ...with the way out" "--no-merges" "$out"
t_has "range: ...exit 1" "RC=1" "$out"
t_eq "range: ...nothing applied" "$M1" "$(git rev-parse HEAD)"
out="$(r shell::git::commit::pick::range --no-merges "$B..withmerge")"
t_has "range --no-merges: ok" "RC=0" "$out"
t_eq "range --no-merges: both side commits arrived" "1" "$([ -e w ] && [ -e s ] && echo 1 || echo 0)"

fresh
out="$(r shell::git::commit::pick::range feature..feature)"
t_has "range: an empty range" "No commits in feature..feature" "$out"
t_has "range: ...exit 1" "RC=1" "$out"
out="$(r shell::git::commit::pick::range "$B...feature")"
t_has "range: three dots refused" "RC=2" "$out"
out="$(r shell::git::commit::pick::range feature)"
t_has "range: not a range" "Not a range" "$out"
t_has "range: ...exit 2" "RC=2" "$out"
out="$(r shell::git::commit::pick::range nope..feature)"
t_has "range: invalid side" "Not a valid commit in the range: 'nope'" "$out"
t_has "range: invalid side exit 1" "RC=1" "$out"
out="$(r shell::git::commit::pick::range)"
t_has "range: no range" "RC=2" "$out"
out="$(r shell::git::commit::pick::range a..b c..d)"
t_has "range: two ranges" "Only one range" "$out"
out="$(r shell::git::commit::pick::range --bogus "$B..feature")"
t_has "range: unknown option" "RC=2" "$out"
out="$(r shell::git::commit::pick::range -m 1 "$B..feature")"
t_has "range: -m is not supported" "RC=2" "$out"

fresh
out="$(r shell::git::commit::pick::range "$F2^..$F4")"
t_has "range: a conflict midway stops" "RC=1" "$out"
t_has "range: ...with a pick in progress" "Stopped" "$out"
t_eq "range: f2 was applied before the conflict" "f2: add b" "$(subject)"
t_has "range: f4 is still waiting" "f4: add c" "$(shell::git::commit::pick::remaining 2>&1)"
git cherry-pick --abort >/dev/null 2>&1
t_rc "range -h" 0 shell::git::commit::pick::range -h

# =============================== preview =================================================
fresh
out="$(r shell::git::commit::pick::preview "$F1")"
t_has "preview: exit 0" "RC=0" "$out"
t_has "preview: the full message" "f1: add a" "$out"
t_has "preview: author metadata" "Author:" "$out"
t_has "preview: committer metadata" "Commit:" "$out"
t_has "preview: the stat" "a | 1 +" "$out"
t_has "preview: the patch" "diff --git a/a b/a" "$out"
out="$(r shell::git::commit::pick::preview --stat "$F1")"
t_has "preview --stat: has the stat" "a | 1 +" "$out"
t_lacks "preview --stat: no patch" "diff --git" "$out"
out="$(r shell::git::commit::pick::preview -S "$F1")"
t_lacks "preview -S: no patch" "diff --git" "$out"
out="$(r shell::git::commit::pick::preview "$F1" "$F2")"
t_has "preview: several commits (1)" "f1: add a" "$out"
t_has "preview: several commits (2)" "f2: add b" "$out"
out="$(r shell::git::commit::pick::preview "$MG")"
t_has "preview: warns about a merge" "is a merge commit" "$out"
out="$(r shell::git::commit::pick::preview "$M1")"
t_has "preview: warns when already in HEAD" "already contained in HEAD" "$out"
out="$(r shell::git::commit::pick::preview "$F5")"
t_has "preview: warns about an empty commit" "is an empty commit" "$out"
out="$(r shell::git::commit::pick::preview nope)"
t_has "preview: invalid revision" "RC=1" "$out"
out="$(r shell::git::commit::pick::preview)"
t_has "preview: nothing given" "RC=2" "$out"
out="$(r shell::git::commit::pick::preview --bogus "$F1")"
t_has "preview: unknown option" "RC=2" "$out"
t_eq "preview is read-only" "$M1" "$(git rev-parse HEAD)"
t_rc "preview -h" 0 shell::git::commit::pick::preview -h

# =============================== equivalent ==============================================
fresh
out="$(r shell::git::commit::pick::equivalent "$F1")"
t_has "equivalent: not applied -> missing" "missing" "$out"
t_has "equivalent: ...exit 1" "RC=1" "$out"
t_eq "equivalent: tab-separated status/hash/subject" "missing	$F1	f1: add a" "$(shell::git::commit::pick::equivalent "$F1" 2>/dev/null)"
shell::git::commit::pick::apply "$F1" >/dev/null 2>&1
out="$(r shell::git::commit::pick::equivalent "$F1")"
t_has "equivalent: cherry-picked -> equivalent (different hash, same patch)" "equivalent" "$out"
t_has "equivalent: ...exit 0" "RC=0" "$out"
out="$(r shell::git::commit::pick::equivalent "$M1")"
t_has "equivalent: an ancestor -> contained" "contained" "$out"
out="$(r shell::git::commit::pick::equivalent "$MG")"
t_has "equivalent: a merge -> unsupported" "unsupported" "$out"
t_has "equivalent: ...counts as not present (exit 1)" "RC=1" "$out"
out="$(r shell::git::commit::pick::equivalent "$B")"
t_has "equivalent: the root commit is contained" "contained" "$out"
out="$(r shell::git::commit::pick::equivalent "$F1" "$F2")"
t_has "equivalent: mixed -> exit 1" "RC=1" "$out"
t_eq "equivalent: mixed shows both statuses" "equivalent|missing" "$(printf '%s\n' "$out" | grep -v RC= | cut -f1 | tr '\n' '|' | sed 's/|$//')"
out="$(r shell::git::commit::pick::equivalent -t feature "$F1" "$F4")"
t_has "equivalent -t: looks in another branch" "RC=0" "$out"
t_eq "equivalent -t: contained there" "contained|contained" "$(printf '%s\n' "$out" | grep -v RC= | cut -f1 | tr '\n' '|' | sed 's/|$//')"
out="$(r shell::git::commit::pick::equivalent --target=feature "$F1")"
t_has "equivalent --target=: form" "RC=0" "$out"
out="$(r shell::git::commit::pick::equivalent -q "$F2")"
t_eq "equivalent -q: silent, exit 1 when missing" "RC=1" "$out"
out="$(r shell::git::commit::pick::equivalent -q "$F1")"
t_eq "equivalent -q: silent, exit 0 when present" "RC=0" "$out"
out="$(r shell::git::commit::pick::equivalent -t nope "$F1")"
t_has "equivalent: bad target" "RC=1" "$out"
out="$(r shell::git::commit::pick::equivalent)"
t_has "equivalent: nothing given" "RC=2" "$out"
out="$(r shell::git::commit::pick::equivalent -t)"
t_has "equivalent: -t needs a value" "RC=2" "$out"
out="$(r shell::git::commit::pick::equivalent --bogus "$F1")"
t_has "equivalent: unknown option" "RC=2" "$out"
out="$(r shell::git::commit::pick::equivalent nope)"
t_has "equivalent: invalid revision" "RC=1" "$out"
t_rc "equivalent -h" 0 shell::git::commit::pick::equivalent -h

t_done
