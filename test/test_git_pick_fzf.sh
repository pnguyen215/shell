#!/usr/bin/env bash
# The fzf group: fzf (the guided workflow and --all), ::local, ::remote, ::branch, ::current, ::range, ::backport, ::conflicts,
# ::continue, ::skip, ::abort. fzf is faked: each call outputs the stdin lines that match the
# scripted picks (exact line first, then substring), and records what it was given.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

export GIT_CONFIG_NOSYSTEM=1 GIT_EDITOR=true
git config --global user.email "t@example.com"
git config --global user.name "T"

mkdir "$HOME/bin"
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
n="$(cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0)"
n=$((n + 1))
echo "$n" >"$FAKE_FZF_STATE"
cat >"$FAKE_FZF_DIR/stdin.$n"
printf '%s\n' "$@" >"$FAKE_FZF_DIR/args.$n"
rec="$(printf '%s\n' "$FAKE_FZF_PICKS" | awk -v n="$n" 'BEGIN { c = 1 } /^---$/ { c++; next } c == n { print }')"
[ -z "$rec" ] && exit 130
# Control lines of a record: @query=<text> is what the user typed; @switch is Ctrl-T (the picker's own
# binding saves its state, then aborts); @pos=<n> is the cursor row (the focus binding's job).
query="$(printf '%s\n' "$rec" | sed -n 's/^@query=//p' | head -n 1)"
want_rows="$(printf '%s\n' "$rec" | grep -v '^@')"
pq=""
for a in "$@"; do [ "$a" = "--print-query" ] && pq=1; done
# Rows are matched on their visible text (colours stripped), exact line first, then substring; the
# original line (with its hidden id column) is what comes back.
sed "$(printf 's/\033\\[[0-9;]*[A-Za-z]//g')" "$FAKE_FZF_DIR/stdin.$n" >"$FAKE_FZF_DIR/plain.$n"
found="$(printf '%s\n' "$want_rows" | while IFS= read -r want; do
	[ -z "$want" ] && continue
	ln="$(grep -n -F -x -- "$want" "$FAKE_FZF_DIR/plain.$n" | head -n 1 | cut -d: -f1)"
	[ -z "$ln" ] && ln="$(grep -n -F -- "$want" "$FAKE_FZF_DIR/plain.$n" | head -n 1 | cut -d: -f1)"
	[ -n "$ln" ] && sed -n "${ln}p" "$FAKE_FZF_DIR/stdin.$n"
done)"
pos="$(printf '%s\n' "$rec" | sed -n 's/^@pos=//p' | head -n 1)"
if [ -n "$pos" ] && [ -n "${SHELL_GIT_PICK_STATE-}" ]; then printf '%s' "$pos" >"$SHELL_GIT_PICK_STATE.pos"; fi
if printf '%s\n' "$rec" | grep -qx '@switch'; then
	printf '%s' "$query" >"$SHELL_GIT_PICK_STATE.query"
	printf '%s\n' "$found" | cut -f1 | sed '/^$/d' >"$SHELL_GIT_PICK_STATE.sel"
	: >"$SHELL_GIT_PICK_STATE.sw"
	exit 130
fi
[ -n "$pq" ] && printf '%s\n' "$query"
[ -n "$found" ] && printf '%s\n' "$found"
exit 0
FAKE
chmod +x "$HOME/bin/fzf"
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_FZF_PICKS=""

reset_fzf() {
	find "$HOME" -maxdepth 1 \( -name 'stdin.*' -o -name 'args.*' -o -name 'plain.*' \) -delete
	rm -f "$FAKE_FZF_STATE"
}
nl='
'
tab="$(printf '\t')"
B="$SHELL_FZF_BACK_LABEL"
# picks "rec1" "rec2" ... -> records separated by ---
picks() {
	local first="true" rec
	for rec in "$@"; do
		if [ "$first" = "false" ]; then printf -- '---\n'; fi
		first="false"
		printf '%s\n' "$rec"
	done
}
# run <picks> <function...> -> output, then RC=<n>
run() {
	local p="$1"
	shift
	reset_fzf
	FAKE_FZF_PICKS="$p" "$@" 2>&1
	echo "RC=$?"
}
subject() { git log -1 --format=%s "${1:-HEAD}"; }
branch() { git symbolic-ref --short -q HEAD; }
busy() { _shell::git::commit::pick::in_progress && echo yes || echo no; }
calls() { cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0; }
lines() { wc -l <"$1" | tr -d ' '; }

# --- template ---------------------------------------------------------------------------------------------------
tpl="$HOME/tpl"
mkdir "$tpl" && cd "$tpl" || exit 1
git init -q && git checkout -q -b main
echo base >f && git add f && git commit -q -m "base"
git checkout -q -b feature
echo one >a && git add a && git commit -q -m "f1: add a"
echo two >b && git add b && git commit -q -m "f2: add b"
echo conflict-feature >f && git add f && git commit -q -m "f3: change f"
echo four >c && git add c && git commit -q -m "f4: add c"
git checkout -q -b side main
echo s >s && git add s && git commit -q -m "s1: add s"
git checkout -q -b release/1.0 main
echo r >rel && git add rel && git commit -q -m "r1: release only"
git checkout -q -b withmerge main
echo w >w && git add w && git commit -q -m "w1: add w"
git merge -q --no-ff side -m "merge side" >/dev/null 2>&1
git checkout -q main
echo conflict-main >f && git add f && git commit -q -m "m1: change f on main"
BASE="$(git rev-parse main~1)"
M1="$(git rev-parse main)"
F1="$(git rev-parse feature~3)"
F2="$(git rev-parse feature~2)"
F3="$(git rev-parse feature~1)"
F4="$(git rev-parse feature)"
S1="$(git rev-parse side)"
R1="$(git rev-parse release/1.0)"
fresh() {
	cd "$HOME" && rm -rf "$HOME/r" && cp -r "$tpl" "$HOME/r" && cd "$HOME/r" || exit 1
}

# =============================== fzf (all refs) ==========================================
fresh
out="$(run "$(picks "f2: add b${nl}f1: add a" "Cherry-pick")" shell::git::commit::pick::fzf --all)"
t_has "fzf: exit 0" "RC=0" "$out"
t_eq "fzf: applied oldest first, whatever the marking order (1)" "f1: add a" "$(subject HEAD~1)"
t_eq "fzf: ...(2)" "f2: add b" "$(subject)"
t_eq "fzf: the candidate list: every commit not in HEAD, nothing else" "7" "$(lines "$HOME/stdin.1")"
t_eq "fzf: ...first column is the full hash" "40" "$(head -n 1 "$HOME/stdin.1" | cut -f1 | tr -d '\n' | wc -c | tr -d ' ')"
t_lacks "fzf: ...commits already in HEAD are not offered (m1)" "m1: change f" "$(cat "$HOME/stdin.1")"
t_lacks "fzf: ...(base)" "base" "$(cat "$HOME/stdin.1")"
t_has "fzf: ...commits of other refs are (side)" "s1: add s" "$(cat "$HOME/stdin.1")"
t_has "fzf: ...(release)" "r1: release only" "$(cat "$HOME/stdin.1")"
t_lacks "fzf: ...merge commits are not listed" "merge side" "$(cat "$HOME/stdin.1")"
t_eq "fzf: ...newest first (f4 above f1)" "1" "$(awk '/f4: add c/ { a = NR } /f1: add a/ { b = NR } END { print (a < b) ? 1 : 0 }' "$HOME/stdin.1")"
t_has "fzf: multi-select" "--multi" "$(cat "$HOME/args.1")"
t_has "fzf: the hash column is hidden" "--with-nth=2.." "$(cat "$HOME/args.1")"
t_has "fzf: tab is the delimiter" "--delimiter=$tab" "$(cat "$HOME/args.1")"
t_has "fzf: the preview shows the highlighted commit" "--preview=git show --stat --patch --color=always {1} | head -n 300" "$(cat "$HOME/args.1")"
t_eq "fzf: the action menu" "Cherry-pick${nl}Cherry-pick with reference (-x)${nl}Apply without committing (--no-commit)${nl}Preview only${nl}$B" "$(cat "$HOME/stdin.2")"
t_has "fzf: shows the plan" "2 commit(s) selected, oldest first" "$out"

fresh
out="$(run "$(picks "f2: add b" "Cherry-pick with reference (-x)")" shell::git::commit::pick::fzf --all)"
t_has "fzf: with reference" "(cherry picked from commit $F2)" "$(git log -1 --format=%B)"
fresh
out="$(run "$(picks "f2: add b" "Apply without committing (--no-commit)")" shell::git::commit::pick::fzf --all)"
t_eq "fzf: --no-commit leaves HEAD" "$M1" "$(git rev-parse HEAD)"
t_has "fzf: ...and stages" "A  b" "$(git status --short)"

fresh
out="$(run "$(picks "f1: add a" "Preview only" "Cherry-pick")" shell::git::commit::pick::fzf --all)"
t_has "fzf: Preview only shows the commit" "diff --git a/a b/a" "$out"
t_eq "fzf: ...then the menu comes back" "5" "$(lines "$HOME/stdin.3")"
t_eq "fzf: ...and the commit can still be applied" "f1: add a" "$(subject)"
t_has "fzf: ...exit 0" "RC=0" "$out"

fresh
out="$(run "$(picks "f1: add a" "$B" "f2: add b" "Cherry-pick")" shell::git::commit::pick::fzf --all)"
t_eq "fzf: Back returns to the list" "7" "$(lines "$HOME/stdin.3")"
t_eq "fzf: ...and the second choice is what is applied" "f2: add b" "$(subject)"
t_eq "fzf: ...f1 was not" "$M1" "$(git rev-parse HEAD~1)"

fresh
out="$(run "" shell::git::commit::pick::fzf --all)"
t_has "fzf: ESC at the list cancels" "Cancelled" "$out"
t_has "fzf: ...exit 1" "RC=1" "$out"
t_eq "fzf: ...nothing applied" "$M1" "$(git rev-parse HEAD)"
out="$(run "$(picks "f1: add a")" shell::git::commit::pick::fzf --all)"
t_has "fzf: ESC at the menu cancels" "RC=1" "$out"
t_eq "fzf: ...nothing applied" "$M1" "$(git rev-parse HEAD)"
out="$(run "$(picks "no-such-text")" shell::git::commit::pick::fzf --all)"
t_has "fzf: nothing matched = nothing selected" "RC=1" "$out"

fresh
out="$(run "$(picks "f1: add a${nl}f2: add b" "Cherry-pick")" shell::git::commit::pick::fzf --all -n)"
t_has "fzf -n: prints the command" "git cherry-pick $F1 $F2" "$out"
t_eq "fzf -n: applies nothing" "$M1" "$(git rev-parse HEAD)"
t_has "fzf -n: exit 0" "RC=0" "$out"

fresh
run "" shell::git::commit::pick::fzf --all -c 2 >/dev/null
t_eq "fzf -c 2: two candidates" "2" "$(lines "$HOME/stdin.1")"
run "" shell::git::commit::pick::fzf --all --count=3 >/dev/null
t_eq "fzf --count=3" "3" "$(lines "$HOME/stdin.1")"
for bad in "-c 0" "-c abc" "-c" "--count=" "--bogus"; do
	# shellcheck disable=SC2086
	out="$(run "" shell::git::commit::pick::fzf $bad)"
	t_has "fzf: invalid usage [$bad]" "RC=2" "$out"
done
out="$(run "" shell::git::commit::pick::fzf feature side)"
t_has "fzf: two sources" "Only one source is accepted" "$out"
t_has "fzf: ...exit 2" "RC=2" "$out"
t_eq "fzf: ...and the list was never shown" "0" "$(calls)"

fresh
run "" shell::git::commit::pick::fzf feature~2 >/dev/null
t_eq "fzf <source>: only that history, not in HEAD (f1, f2)" "2" "$(lines "$HOME/stdin.1")"
t_has "fzf <source>: f2 is there" "f2: add b" "$(cat "$HOME/stdin.1")"
run "" shell::git::commit::pick::fzf --include-head feature >/dev/null
t_has "fzf --include-head: commits already in HEAD are listed" "base" "$(cat "$HOME/stdin.1")"
out="$(run "" shell::git::commit::pick::fzf nope-branch)"
t_has "fzf: invalid source" "Not a valid commit: 'nope-branch'" "$out"
t_has "fzf: ...exit 1" "RC=1" "$out"

out="$(run "$(picks "base" "Cherry-pick")" shell::git::commit::pick::fzf --include-head feature)"
t_has "fzf --include-head: picking one already in HEAD is skipped safely" "already contained in HEAD" "$out"
t_has "fzf --include-head: ...nothing applied (exit 1)" "RC=1" "$out"
t_eq "fzf --include-head: ...nothing left in progress" "no" "$(busy)"

fresh
out="$(run "$(picks "f3: change f" "Cherry-pick")" shell::git::commit::pick::fzf --all)"
t_has "fzf: a conflict stops with exit 1" "RC=1" "$out"
t_eq "fzf: ...leaving a cherry-pick in progress" "yes" "$(busy)"
out="$(run "" shell::git::commit::pick::fzf --all)"
t_has "fzf: refused up front while one is in progress" "already in progress" "$out"
t_eq "fzf: ...the list was not even shown" "0" "$(calls)"
shell::git::commit::pick::abort >/dev/null 2>&1

fresh
echo staged >s2 && git add s2
out="$(run "$(picks "f1: add a" "Cherry-pick")" shell::git::commit::pick::fzf --all)"
t_has "fzf: staged changes stop the plain cherry-pick" "staged changes" "$out"
t_has "fzf: ...exit 1" "RC=1" "$out"
out="$(run "$(picks "f1: add a" "Apply without committing (--no-commit)")" shell::git::commit::pick::fzf --all)"
t_has "fzf: ...but --no-commit is fine" "RC=0" "$out"

cd "$HOME" && rm -rf one && mkdir one && cd one || exit 1
git init -q && echo x >x && git add x && git commit -q -m "only"
out="$(run "" shell::git::commit::pick::fzf --all)"
t_has "fzf: nothing to pick from" "No commits to pick from" "$out"
t_has "fzf: ...exit 1" "RC=1" "$out"
cd "$HOME" && rm -rf norepo && mkdir norepo && cd norepo || exit 1
out="$(run "" shell::git::commit::pick::fzf --all)"
t_has "fzf: outside a repo" "Not inside a Git repository" "$out"
t_rc "fzf -h" 0 shell::git::commit::pick::fzf -h

# =============================== fzf::local ==============================================
fresh
out="$(run "$(picks "s1: add s" "Cherry-pick")" shell::git::commit::pick::fzf::local)"
t_has "fzf::local: exit 0" "RC=0" "$out"
t_eq "fzf::local: applied" "s1: add s" "$(subject)"
t_eq "fzf::local: all local branches' commits not in HEAD" "7" "$(lines "$HOME/stdin.1")"
fresh
run "" shell::git::commit::pick::fzf::local feature >/dev/null
t_eq "fzf::local <glob>: only that branch" "4" "$(lines "$HOME/stdin.1")"
run "" shell::git::commit::pick::fzf::local side >/dev/null
t_eq "fzf::local <glob>: a single commit" "1" "$(lines "$HOME/stdin.1")"
run "" shell::git::commit::pick::fzf::local 'rel*' >/dev/null
t_has "fzf::local: a real glob" "r1: release only" "$(cat "$HOME/stdin.1")"
out="$(run "" shell::git::commit::pick::fzf::local nope)"
t_has "fzf::local: a glob matching nothing" "No commits to pick from" "$out"
t_has "fzf::local: ...exit 1" "RC=1" "$out"
out="$(run "" shell::git::commit::pick::fzf::local a b)"
t_has "fzf::local: two patterns" "RC=2" "$out"
out="$(run "" shell::git::commit::pick::fzf::local --bogus)"
t_has "fzf::local: unknown option" "RC=2" "$out"
out="$(run "$(picks "s1: add s" "Cherry-pick")" shell::git::commit::pick::fzf::local -n)"
t_has "fzf::local -n" "git cherry-pick $S1" "$out"
t_eq "fzf::local -n: nothing applied" "$M1" "$(git rev-parse HEAD)"
t_rc "fzf::local -h" 0 shell::git::commit::pick::fzf::local -h

# =============================== fzf::remote =============================================
fresh
git init -q --bare "$HOME/origin.git"
git remote add origin "$HOME/origin.git"
git push -q origin feature side 2>/dev/null
git fetch -q origin 2>/dev/null
git branch -q -D feature side release/1.0 withmerge
out="$(run "$(picks "f1: add a" "Cherry-pick")" shell::git::commit::pick::fzf::remote)"
t_has "fzf::remote: exit 0" "RC=0" "$out"
t_eq "fzf::remote: applied" "f1: add a" "$(subject)"
t_eq "fzf::remote: only what origin has (f1..f4 and s1)" "5" "$(lines "$HOME/stdin.1")"
t_lacks "fzf::remote: ...nothing from local-only branches" "r1: release only" "$(cat "$HOME/stdin.1")"
run "" shell::git::commit::pick::fzf::remote origin >/dev/null
t_eq "fzf::remote origin" "5" "$(lines "$HOME/stdin.1")"
out="$(run "" shell::git::commit::pick::fzf::remote nope)"
t_has "fzf::remote: a remote with nothing" "No commits to pick from" "$out"
out="$(run "" shell::git::commit::pick::fzf::remote a b)"
t_has "fzf::remote: two remotes" "RC=2" "$out"
t_rc "fzf::remote -h" 0 shell::git::commit::pick::fzf::remote -h

# =============================== fzf::branch =============================================
fresh
out="$(run "$(picks "feature" "f1: add a" "Cherry-pick")" shell::git::commit::pick::fzf::branch)"
t_has "fzf::branch: exit 0" "RC=0" "$out"
t_eq "fzf::branch: applied" "f1: add a" "$(subject)"
t_lacks "fzf::branch: the current branch is not offered" "main" "$(cat "$HOME/stdin.1")"
t_has "fzf::branch: the others are" "feature" "$(cat "$HOME/stdin.1")"
t_has "fzf::branch: ...(release)" "release/1.0" "$(cat "$HOME/stdin.1")"
t_has "fzf::branch: the preview shows the branch's log" "--preview=git log --oneline --color=always -n 15 {}" "$(cat "$HOME/args.1")"
t_eq "fzf::branch: then only that branch's commits (f1..f4)" "4" "$(lines "$HOME/stdin.2")"
t_lacks "fzf::branch: ...none of the others" "s1: add s" "$(cat "$HOME/stdin.2")"
fresh
out="$(run "" shell::git::commit::pick::fzf::branch)"
t_has "fzf::branch: ESC at the branch list" "RC=1" "$out"
t_eq "fzf::branch: ...nothing applied" "$M1" "$(git rev-parse HEAD)"
fresh
git checkout -q --detach
run "" shell::git::commit::pick::fzf::branch >/dev/null
t_has "fzf::branch: on a detached HEAD, main is offered too" "main" "$(cat "$HOME/stdin.1")"
t_eq "fzf::branch: ...and every other branch (5, plus the back row)" "6" "$(lines "$HOME/stdin.1")"
cd "$HOME/one" || exit 1
out="$(run "" shell::git::commit::pick::fzf::branch)"
t_has "fzf::branch: no other branch" "There is no other local branch" "$out"
t_has "fzf::branch: ...exit 1" "RC=1" "$out"
out="$(run "" shell::git::commit::pick::fzf::branch extra)"
t_has "fzf::branch: a stray argument" "RC=2" "$out"
t_rc "fzf::branch -h" 0 shell::git::commit::pick::fzf::branch -h

# =============================== fzf::current ============================================
fresh
git checkout -q feature
out="$(run "$(picks "f1: add a${nl}f2: add b" "release/1.0" "Apply onto release/1.0")" shell::git::commit::pick::fzf::current)"
t_has "fzf::current: exit 0" "RC=0" "$out"
t_eq "fzf::current: you are on the target now" "release/1.0" "$(branch)"
t_eq "fzf::current: the commits arrived, oldest first" "f1: add a|f2: add b" "$(subject HEAD~1)|$(subject)"
t_has "fzf::current: with a reference" "(cherry picked from commit $F2)" "$(git log -1 --format=%B)"
t_eq "fzf::current: the list is this branch's own history (base + 4)" "5" "$(lines "$HOME/stdin.1")"
t_eq "fzf::current: targets are the other local branches" "1" "$(grep -c '^main$' "$HOME/stdin.2")"
t_lacks "fzf::current: ...not the current one" "feature" "$(cat "$HOME/stdin.2")"
t_eq "fzf::current: the confirmation" "Apply onto release/1.0${nl}Abort${nl}$B" "$(cat "$HOME/stdin.3")"
fresh
git checkout -q feature
out="$(run "$(picks "f1: add a" "release/1.0" "$B" "main" "Apply onto main")" shell::git::commit::pick::fzf::current)"
t_has "fzf::current: Back at the confirmation re-opens the target list" "RC=0" "$out"
t_eq "fzf::current: ...and the new choice wins" "main" "$(branch)"
fresh
git checkout -q feature
out="$(run "$(picks "f1: add a" "$B" "f2: add b" "side" "Apply onto side")" shell::git::commit::pick::fzf::current)"
t_has "fzf::current: Back at the target list re-opens the commits" "RC=0" "$out"
t_eq "fzf::current: ...the second choice is applied" "f2: add b" "$(subject)"
fresh
git checkout -q feature
out="$(run "$(picks "f1: add a" "main" "Abort")" shell::git::commit::pick::fzf::current)"
t_has "fzf::current: Abort" "RC=1" "$out"
t_eq "fzf::current: ...stayed on feature" "feature" "$(branch)"
fresh
git checkout -q feature
out="$(run "$(picks "f1: add a" "main" "Apply onto main")" shell::git::commit::pick::fzf::current -n)"
t_has "fzf::current -n: prints the switch" "git checkout main" "$out"
t_has "fzf::current -n: prints the pick" "git cherry-pick -x $F1" "$out"
t_eq "fzf::current -n: stays on feature" "feature" "$(branch)"
fresh
git checkout -q feature
echo dirty >>a
out="$(run "$(picks "f1: add a" "main" "Apply onto main")" shell::git::commit::pick::fzf::current)"
t_has "fzf::current: a dirty tree is refused by the backport" "uncommitted change(s)" "$out"
t_has "fzf::current: ...exit 1" "RC=1" "$out"
t_eq "fzf::current: ...still on feature" "feature" "$(branch)"
fresh
git checkout -q feature
out="$(run "" shell::git::commit::pick::fzf::current)"
t_has "fzf::current: ESC at the list" "RC=1" "$out"
cd "$HOME/one" || exit 1
out="$(run "" shell::git::commit::pick::fzf::current)"
t_has "fzf::current: no other branch" "no other local branch" "$out"
t_rc "fzf::current -h" 0 shell::git::commit::pick::fzf::current -h

# =============================== fzf::range ==============================================
fresh
out="$(run "$(picks "f2: add b${nl}f4: add c" "Cherry-pick")" shell::git::commit::pick::fzf::range "$BASE..feature")"
t_has "fzf::range: exit 0" "RC=0" "$out"
t_eq "fzf::range: only the chosen ones, oldest first" "f2: add b|f4: add c" "$(subject HEAD~1)|$(subject)"
t_eq "fzf::range: the list is the range (f1..f4)" "4" "$(lines "$HOME/stdin.1")"
t_lacks "fzf::range: ...nothing outside it" "s1: add s" "$(cat "$HOME/stdin.1")"
out="$(run "" shell::git::commit::pick::fzf::range)"
t_has "fzf::range: no range" "RC=2" "$out"
out="$(run "" shell::git::commit::pick::fzf::range "$BASE...feature")"
t_has "fzf::range: three dots" "RC=2" "$out"
out="$(run "" shell::git::commit::pick::fzf::range feature)"
t_has "fzf::range: not a range" "Not a range" "$out"
out="$(run "" shell::git::commit::pick::fzf::range nope..feature)"
t_has "fzf::range: invalid side" "Not a valid commit in the range" "$out"
t_has "fzf::range: ...exit 1" "RC=1" "$out"
out="$(run "" shell::git::commit::pick::fzf::range a..b c..d)"
t_has "fzf::range: two ranges" "Only one range" "$out"
out="$(run "" shell::git::commit::pick::fzf::range feature..feature)"
t_has "fzf::range: an empty range" "No commits to pick from" "$out"
out="$(run "$(picks "f1: add a" "Cherry-pick")" shell::git::commit::pick::fzf::range -n "$BASE..feature")"
t_has "fzf::range -n" "git cherry-pick $F1" "$out"
t_rc "fzf::range -h" 0 shell::git::commit::pick::fzf::range -h

# =============================== fzf::backport ===========================================
fresh
git init -q --bare "$HOME/origin.git"
git remote add origin "$HOME/origin.git"
git push -q origin release/1.0 main 2>/dev/null
git fetch -q origin 2>/dev/null
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
out="$(run "$(picks "release/1.0" "f1: add a${nl}f2: add b" "Backport")" shell::git::commit::pick::fzf::backport)"
t_has "fzf::backport: exit 0" "RC=0" "$out"
t_eq "fzf::backport: a backport branch was created" "backport/release-1.0/$(git rev-parse --short "$F1")" "$(branch)"
t_eq "fzf::backport: built on the target, oldest first" "$R1|f1: add a|f2: add b" "$(git rev-parse HEAD~2)|$(subject HEAD~1)|$(subject)"
t_has "fzf::backport: with a reference" "(cherry picked from commit $F2)" "$(git log -1 --format=%B)"
t_lacks "fzf::backport: the current branch is not a target" "main$" "$(grep -x 'main' "$HOME/stdin.1")"
t_has "fzf::backport: local branches are targets" "release/1.0" "$(cat "$HOME/stdin.1")"
t_has "fzf::backport: remote-tracking branches are too" "origin/release/1.0" "$(cat "$HOME/stdin.1")"
t_lacks "fzf::backport: ...but not the symbolic origin/HEAD" "origin/HEAD" "$(cat "$HOME/stdin.1")"
t_eq "fzf::backport: ...nor a bare 'origin'" "0" "$(grep -c -x 'origin' "$HOME/stdin.1")"
t_lacks "fzf::backport: only commits the target lacks are listed (r1 is in it)" "r1: release only" "$(cat "$HOME/stdin.2")"
t_has "fzf::backport: ...f1 is" "f1: add a" "$(cat "$HOME/stdin.2")"
t_eq "fzf::backport: the confirmation" "Backport${nl}Abort${nl}$B" "$(cat "$HOME/stdin.3")"

fresh
out="$(run "$(picks "f1: add a" "Backport")" shell::git::commit::pick::fzf::backport release/1.0 --source feature)"
t_has "fzf::backport <target> --source: exit 0" "RC=0" "$out"
t_eq "fzf::backport <target> --source: the target step is skipped (first list is commits)" "4" "$(lines "$HOME/stdin.1")"
t_lacks "fzf::backport --source: only that history" "s1: add s" "$(cat "$HOME/stdin.1")"
fresh
out="$(run "$(picks "f1: add a" "$B" "f2: add b" "Backport")" shell::git::commit::pick::fzf::backport release/1.0)"
t_has "fzf::backport: Back at the confirmation re-opens the commits" "RC=0" "$out"
t_eq "fzf::backport: ...the second choice wins" "f2: add b" "$(subject)"
fresh
out="$(run "$(picks "f1: add a" "Abort")" shell::git::commit::pick::fzf::backport release/1.0)"
t_has "fzf::backport: Abort" "RC=1" "$out"
t_eq "fzf::backport: ...no branch created" "" "$(git branch --list 'backport/*')"
out="$(run "" shell::git::commit::pick::fzf::backport release/1.0)"
t_has "fzf::backport: ESC at the commit list (with a target)" "RC=1" "$out"
fresh
out="$(run "$(picks "f1: add a" "Backport")" shell::git::commit::pick::fzf::backport release/1.0 --in-place)"
t_eq "fzf::backport --in-place: on the target itself" "release/1.0" "$(branch)"
fresh
out="$(run "$(picks "f1: add a" "Backport")" shell::git::commit::pick::fzf::backport release/1.0 -b fix/one)"
t_eq "fzf::backport -b: the chosen branch" "fix/one" "$(branch)"
fresh
out="$(run "$(picks "f1: add a" "Backport")" shell::git::commit::pick::fzf::backport release/1.0 -n)"
t_has "fzf::backport -n: prints the branch command" "git checkout -b backport/release-1.0/" "$out"
t_eq "fzf::backport -n: nothing created" "main" "$(branch)"
out="$(run "" shell::git::commit::pick::fzf::backport feature --source feature)"
t_has "fzf::backport: nothing missing from the target" "Every commit is already in 'feature'" "$out"
t_has "fzf::backport: ...exit 1" "RC=1" "$out"
out="$(run "" shell::git::commit::pick::fzf::backport nope)"
t_has "fzf::backport: invalid target" "Not a valid target" "$out"
out="$(run "" shell::git::commit::pick::fzf::backport release/1.0 --source nope)"
t_has "fzf::backport: invalid source" "Not a valid source revision" "$out"
out="$(run "" shell::git::commit::pick::fzf::backport release/1.0 feature)"
t_has "fzf::backport: two targets" "Only one target is accepted" "$out"
t_has "fzf::backport: ...exit 2" "RC=2" "$out"
for bad in "--bogus" "-c abc" "-s" "-b"; do
	# shellcheck disable=SC2086
	out="$(run "" shell::git::commit::pick::fzf::backport $bad)"
	t_has "fzf::backport: invalid usage [$bad]" "RC=2" "$out"
done
cd "$HOME/one" || exit 1
out="$(run "" shell::git::commit::pick::fzf::backport)"
t_has "fzf::backport: no other branch" "no other branch" "$out"
t_rc "fzf::backport -h" 0 shell::git::commit::pick::fzf::backport -h

# =============================== fzf::conflicts ==========================================
cat >"$HOME/bin/ed-a" <<'ED'
#!/bin/sh
printf 'edited-by-A\n' >"$1"
ED
cat >"$HOME/bin/ed-b" <<'ED'
#!/bin/sh
printf 'edited-by-B\n' >"$1"
ED
chmod +x "$HOME/bin/ed-a" "$HOME/bin/ed-b"
stuck() {
	fresh
	shell::git::commit::pick::apply "$F3" >/dev/null 2>&1
}
stuck
out="$(run "$(picks "f" "Open in editor")" env VISUAL="$HOME/bin/ed-a" EDITOR="$HOME/bin/ed-b" bash -c 'true')"
stuck
FAKE_FZF_PICKS="$(picks "f" "Open in editor")" VISUAL="$HOME/bin/ed-a" EDITOR="$HOME/bin/ed-b" shell::git::commit::pick::fzf::conflicts >/dev/null 2>&1
t_eq "fzf::conflicts: Open in editor ($VISUAL wins over \$EDITOR)" "edited-by-A" "$(cat f)"
stuck
reset_fzf
FAKE_FZF_PICKS="$(picks "f" "Open in editor")" EDITOR="$HOME/bin/ed-b" shell::git::commit::pick::fzf::conflicts >/dev/null 2>&1
t_eq "fzf::conflicts: \$EDITOR is used when there is no \$VISUAL" "edited-by-B" "$(cat f)"
t_has "fzf::conflicts: the list is the conflicted files plus Back" "f" "$(cat "$HOME/stdin.1")"
t_eq "fzf::conflicts: ...exactly two lines" "2" "$(lines "$HOME/stdin.1")"
t_has "fzf::conflicts: the preview is the conflict diff" "--preview=git diff --color=always -- {} | head -n 200" "$(cat "$HOME/args.1")"
t_eq "fzf::conflicts: the action menu" "Open in editor${nl}Show diff${nl}Take ours (current branch) and mark resolved${nl}Take theirs (picked commit) and mark resolved${nl}Mark as resolved${nl}$B" "$(cat "$HOME/stdin.2")"

stuck
out="$(run "$(picks "f" "Take ours" "Overwrite f with the ours version")" shell::git::commit::pick::fzf::conflicts)"
t_has "fzf::conflicts: take ours: exit 0" "RC=0" "$out"
t_eq "fzf::conflicts: take ours: the file is HEAD's" "conflict-main" "$(cat f)"
t_eq "fzf::conflicts: take ours: and it is resolved" "1" "$(shell::git::commit::pick::conflicts >/dev/null 2>&1 && echo 0 || echo 1)"
t_has "fzf::conflicts: ...the loop ends by itself" "No conflicted files" "$out"
stuck
out="$(run "$(picks "f" "Take theirs" "Overwrite f with the theirs version")" shell::git::commit::pick::fzf::conflicts)"
t_eq "fzf::conflicts: take theirs: the picked commit's version" "conflict-feature" "$(cat f)"
t_has "fzf::conflicts: take theirs: exit 0" "RC=0" "$out"
stuck
out="$(run "$(picks "f" "Take theirs" "Cancel")" shell::git::commit::pick::fzf::conflicts)"
t_has "fzf::conflicts: take theirs, then Cancel at the confirmation" "Cancelled" "$out"
t_has "fzf::conflicts: ...the file keeps its markers" "<<<<<<<" "$(cat f)"
t_has "fzf::conflicts: ...so nothing was handled (exit 1)" "RC=1" "$out"
stuck
out="$(run "$(picks "f" "Take ours" "Overwrite f with the ours version")" shell::git::commit::pick::fzf::conflicts -n)"
t_has "fzf::conflicts -n: prints the checkout" "git checkout --ours -- f" "$out"
t_has "fzf::conflicts -n: prints the add" "git add -- f" "$out"
t_has "fzf::conflicts -n: the file is untouched" "<<<<<<<" "$(cat f)"

stuck
out="$(run "$(picks "f" "Mark as resolved")" shell::git::commit::pick::fzf::conflicts)"
t_has "fzf::conflicts: marking a file with markers is refused" "Conflict markers are still" "$out"
t_has "fzf::conflicts: ...that counts as a failure (exit 1)" "RC=1" "$out"
stuck
echo fixed >f
out="$(run "$(picks "f" "Mark as resolved")" shell::git::commit::pick::fzf::conflicts)"
t_has "fzf::conflicts: Mark as resolved works once fixed" "RC=0" "$out"
t_eq "fzf::conflicts: ...the file is staged" "M  f" "$(git status --short | grep ' f$' | head -n 1)"
stuck
out="$(run "$(picks "f" "Show diff")" shell::git::commit::pick::fzf::conflicts)"
t_has "fzf::conflicts: Show diff prints the conflict" "<<<<<<<" "$out"
t_has "fzf::conflicts: ...it handles nothing (exit 1)" "RC=1" "$out"
stuck
out="$(run "$(picks "$B")" shell::git::commit::pick::fzf::conflicts)"
t_has "fzf::conflicts: Back leaves" "RC=1" "$out"
out="$(run "" shell::git::commit::pick::fzf::conflicts)"
t_has "fzf::conflicts: ESC leaves" "RC=1" "$out"
stuck
out="$(run "$(picks "f" "$B")" shell::git::commit::pick::fzf::conflicts)"
t_has "fzf::conflicts: Back at the action menu returns to the list" "RC=1" "$out"
t_eq "fzf::conflicts: ...which was shown again" "1" "$([ -e "$HOME/stdin.3" ] && echo 1 || echo 0)"

fresh
out="$(run "" shell::git::commit::pick::fzf::conflicts)"
t_has "fzf::conflicts: no conflicts" "No conflicted files" "$out"
t_has "fzf::conflicts: ...exit 1" "RC=1" "$out"
t_eq "fzf::conflicts: ...no list was shown" "0" "$(calls)"
out="$(run "" shell::git::commit::pick::fzf::conflicts --bogus)"
t_has "fzf::conflicts: unknown option" "RC=2" "$out"
t_rc "fzf::conflicts -h" 0 shell::git::commit::pick::fzf::conflicts -h

# several conflicts: handle one, the rest remain and are listed again
cd "$HOME" && rm -rf multi && mkdir multi && cd multi || exit 1
git init -q && git checkout -q -b main
echo base >x && echo base >y && git add . && git commit -q -m "base"
git checkout -q -b topic && echo t >x && echo t >y && git add . && git commit -q -m "topic"
git checkout -q main && echo m >x && echo m >y && git add . && git commit -q -m "main"
shell::git::commit::pick::apply topic >/dev/null 2>&1
out="$(run "$(picks "x" "Take ours" "Overwrite x with the ours version" "y" "Take theirs" "Overwrite y with the theirs version")" shell::git::commit::pick::fzf::conflicts)"
t_has "fzf::conflicts: two files handled in one session" "RC=0" "$out"
t_eq "fzf::conflicts: ...x is ours, y is theirs" "m|t" "$(cat x)|$(cat y)"
t_eq "fzf::conflicts: ...the second list had only y" "1" "$(grep -c '^y$' "$HOME/stdin.4")"
t_eq "fzf::conflicts: ...and not x" "0" "$(grep -c '^x$' "$HOME/stdin.4")"

# =============================== fzf::continue / skip / abort ================================
stuck
echo fixed >f && shell::git::commit::pick::resolve >/dev/null 2>&1
out="$(run "$(picks "Continue the cherry-pick")" shell::git::commit::pick::fzf::continue --no-edit)"
t_has "fzf::continue: shows the state first" "Cherry-pick in progress on 'main'" "$out"
t_has "fzf::continue: exit 0" "RC=0" "$out"
t_eq "fzf::continue: the pick was committed" "f3: change f" "$(subject)"
t_eq "fzf::continue: nothing in progress" "no" "$(busy)"
t_eq "fzf::continue: the menu" "Continue the cherry-pick${nl}Cancel" "$(cat "$HOME/stdin.1")"
stuck
echo fixed >f && shell::git::commit::pick::resolve >/dev/null 2>&1
out="$(run "$(picks "Cancel")" shell::git::commit::pick::fzf::continue)"
t_has "fzf::continue: Cancel" "RC=1" "$out"
t_eq "fzf::continue: ...still in progress" "yes" "$(busy)"
out="$(run "" shell::git::commit::pick::fzf::continue)"
t_has "fzf::continue: ESC" "RC=1" "$out"
stuck
out="$(run "$(picks "Continue the cherry-pick")" shell::git::commit::pick::fzf::continue)"
t_has "fzf::continue: a conflict left makes continue refuse" "still in conflict" "$out"
t_has "fzf::continue: ...exit 1" "RC=1" "$out"
out="$(run "$(picks "Continue the cherry-pick")" shell::git::commit::pick::fzf::continue -n)"
t_has "fzf::continue -n: forwarded" "RC=1" "$out"
fresh
out="$(run "" shell::git::commit::pick::fzf::continue)"
t_has "fzf::continue: nothing in progress" "No cherry-pick in progress" "$out"
t_has "fzf::continue: ...exit 1" "RC=1" "$out"
t_eq "fzf::continue: ...no menu" "0" "$(calls)"
out="$(run "" shell::git::commit::pick::fzf::continue --bogus)"
t_has "fzf::continue: unknown option" "RC=2" "$out"
t_rc "fzf::continue -h" 0 shell::git::commit::pick::fzf::continue -h

stuck
out="$(run "$(picks "Skip this commit")" shell::git::commit::pick::fzf::skip)"
t_has "fzf::skip: shows the commit that will go" "f3: change f" "$out"
t_has "fzf::skip: exit 0" "RC=0" "$out"
t_eq "fzf::skip: f3 was dropped, HEAD is where it was" "m1: change f on main" "$(subject)"
t_eq "fzf::skip: f3's change is not in the tree" "conflict-main" "$(cat f)"
t_eq "fzf::skip: nothing in progress" "no" "$(busy)"
t_eq "fzf::skip: the menu" "Skip this commit${nl}Cancel" "$(cat "$HOME/stdin.1")"
stuck
out="$(run "$(picks "Cancel")" shell::git::commit::pick::fzf::skip)"
t_has "fzf::skip: Cancel" "RC=1" "$out"
t_eq "fzf::skip: ...still in progress" "yes" "$(busy)"
stuck
out="$(run "$(picks "Skip this commit")" shell::git::commit::pick::fzf::skip -n)"
t_has "fzf::skip -n: forwarded" "git cherry-pick --skip" "$out"
t_eq "fzf::skip -n: still in progress" "yes" "$(busy)"
fresh
out="$(run "" shell::git::commit::pick::fzf::skip)"
t_has "fzf::skip: nothing in progress" "nothing to skip" "$out"
t_eq "fzf::skip: ...no menu" "0" "$(calls)"
out="$(run "" shell::git::commit::pick::fzf::skip --bogus)"
t_has "fzf::skip: unknown option" "RC=2" "$out"
t_rc "fzf::skip -h" 0 shell::git::commit::pick::fzf::skip -h

stuck
out="$(run "$(picks "Abort the cherry-pick")" shell::git::commit::pick::fzf::abort)"
t_has "fzf::abort: shows the state" "Cherry-pick in progress on 'main'" "$out"
t_has "fzf::abort: reminds what is lost" "drops everything the cherry-pick changed" "$out"
t_has "fzf::abort: exit 0" "RC=0" "$out"
t_eq "fzf::abort: HEAD is back" "$M1" "$(git rev-parse HEAD)"
t_eq "fzf::abort: the menu" "Abort the cherry-pick${nl}Cancel" "$(cat "$HOME/stdin.1")"
stuck
out="$(run "$(picks "Cancel")" shell::git::commit::pick::fzf::abort)"
t_has "fzf::abort: Cancel is the safety net" "RC=1" "$out"
t_eq "fzf::abort: ...still in progress" "yes" "$(busy)"
out="$(run "" shell::git::commit::pick::fzf::abort)"
t_has "fzf::abort: ESC" "RC=1" "$out"
t_eq "fzf::abort: ...still in progress" "yes" "$(busy)"
out="$(run "$(picks "Abort the cherry-pick")" shell::git::commit::pick::fzf::abort -n)"
t_has "fzf::abort -n: forwarded" "git cherry-pick --abort" "$out"
t_eq "fzf::abort -n: still in progress" "yes" "$(busy)"
fresh
out="$(run "" shell::git::commit::pick::fzf::abort)"
t_has "fzf::abort: nothing in progress" "No cherry-pick in progress" "$out"
t_eq "fzf::abort: ...no menu" "0" "$(calls)"
out="$(run "" shell::git::commit::pick::fzf::abort --bogus)"
t_has "fzf::abort: unknown option" "RC=2" "$out"
t_rc "fzf::abort -h" 0 shell::git::commit::pick::fzf::abort -h

# =============================== fzf (guided workflow: source -> mode -> picker -> action) =================
# One repository with: a branch whose files are changed by several commits, special file names, a remote
# branch only the remote has, a branch the remote has too (equal and diverged), and a branch with nothing to pick.
ftpl="$HOME/ftpl"
rm -rf "$HOME/forigin.git"
git init -q --bare "$HOME/forigin.git"
mkdir "$ftpl" && cd "$ftpl" || exit 1
git init -q && git checkout -q -b main
echo base >f && git add f && git commit -q -m "base"
git checkout -q -b old
git checkout -q -b feature main
echo one >a && git add a && git commit -q -m "x1: add a"
echo s1 >"sp ace.txt"
printf 'tab\n' >"ta${tab}b.txt"
printf 'nl\n' >"new${nl}line.txt"
printf 'q\n' >'q"uote.txt'
echo d >-dash.txt
echo u >"ünï.txt"
git add -A && git commit -q -m "x2: specials"
echo two >>a && git add a && git commit -q -m "x3: a again"
echo s2 >>"sp ace.txt" && git add -A && git commit -q -m "x4: touch sp"
git checkout -q -b release/1.0 main
echo r >rel && git add rel && git commit -q -m "r1: release"
git checkout -q -b side main
echo s >s && git add s && git commit -q -m "s1: only on side"
git remote add origin "$HOME/forigin.git"
git push -q origin feature release/1.0 side 2>/dev/null
git fetch -q origin 2>/dev/null
git checkout -q release/1.0
git branch -q -D side
echo r2 >rel2 && git add rel2 && git commit -q -m "r2: local only"
git checkout -q main
echo m >m && git add m && git commit -q -m "m1: on main"
FM1="$(git rev-parse main)"
X1="$(git rev-parse feature~3)"
X2="$(git rev-parse feature~2)"
X3="$(git rev-parse feature~1)"
X4="$(git rev-parse feature)"
fresh2() {
	cd "$HOME" && rm -rf "$HOME/r" && cp -r "$ftpl" "$HOME/r" && cd "$HOME/r" || exit 1
}
staged() { git diff --cached --name-only -z | tr '\0' '|'; }
head_is() { [ "$(git rev-parse HEAD)" = "$1" ] && echo same || echo moved; }
args_of() { cat "$HOME/args.$1"; }
rows_of() { sed "s/$(printf '\033')\[[0-9;]*m//g" "$HOME/stdin.$1"; }
S="Pick by commit"
F="Pick by files"
APPLY_F="Apply to the working tree (staged, no commit)"

# --- 3.1 source branch selection -------------------------------------------------------------------------
fresh2
out="$(run "$(picks "feature" "$S" "x1: add a" "Cherry-pick")" shell::git::commit::pick::fzf)"
t_has "flow: exit 0" "RC=0" "$out"
t_has "flow: local branch listed, once, marked as also on the remote" "[local]  feature (= origin)" "$(rows_of 1)"
t_lacks "flow: ...its remote twin is not listed again (same commit)" "origin/feature" "$(rows_of 1)"
t_has "flow: a remote-only branch is listed" "[remote] origin/side" "$(rows_of 1)"
t_has "flow: a diverged local branch is listed..." "[local]  release/1.0  " "$(rows_of 1)"
t_has "flow: ...and so is its remote twin" "[remote] origin/release/1.0" "$(rows_of 1)"
t_lacks "flow: ...the diverged one is not marked equal" "release/1.0 (=" "$(rows_of 1)"
t_lacks "flow: the current branch is not offered" "[local]  main" "$(rows_of 1)"
t_lacks "flow: origin/HEAD is not offered" "origin/HEAD" "$(rows_of 1)"
t_eq "flow: 5 branches (old, feature, release/1.0, origin/release/1.0, origin/side) and the back row" "6" "$(lines "$HOME/stdin.1")"
t_eq "flow: the back row is last" "${B}${tab}@back" "$(tail -n 1 "$HOME/stdin.1")"
t_eq "flow: the second column is the full ref" "refs/heads/feature" "$(rows_of 1 | grep -F 'feature (=' | cut -f2)"
t_has "flow: the source preview is the branch's log" "git log --oneline --color=always -n 15" "$(args_of 1)"
t_has "flow: ...on the right" "--preview-window=right:55%:wrap" "$(args_of 1)"
t_eq "flow: then the mode menu" "Pick by commit${nl}Pick by files${nl}$B" "$(rows_of 2)"
t_eq "flow: HEAD moved by exactly the pick" "x1: add a" "$(subject)"

fresh2
run "$(picks "[remote] origin/release/1.0" "$S")" shell::git::commit::pick::fzf >/dev/null
t_eq "flow: a remote ref is listed from the remote, not from the same-named local branch (r1 only)" "1" "$(lines "$HOME/stdin.3")"
run "$(picks "[local]  release/1.0" "$S")" shell::git::commit::pick::fzf >/dev/null
t_eq "flow: ...the local one has its own extra commit (r1, r2)" "2" "$(lines "$HOME/stdin.3")"
run "$(picks "[remote] origin/side" "$S")" shell::git::commit::pick::fzf >/dev/null
t_has "flow: a remote-only branch resolves" "s1: only on side" "$(rows_of 3)"

fresh2
out="$(run "$(picks "$B")" shell::git::commit::pick::fzf)"
t_has "flow: Back at the source list" "RC=11" "$out"
t_eq "flow: ...nothing applied" "$FM1" "$(git rev-parse HEAD)"
out="$(run "" shell::git::commit::pick::fzf)"
t_has "flow: ESC at the source list" "Cancelled" "$out"
t_has "flow: ...exit 1" "RC=1" "$out"
out="$(run "$(picks "feature" "$B" "feature" "$S")" shell::git::commit::pick::fzf)"
t_eq "flow: Back at the mode menu returns to the source list (shown twice)" "6" "$(lines "$HOME/stdin.3")"
t_eq "flow: ...the source list is the same" "$(rows_of 1)" "$(rows_of 3)"
t_has "flow: ...the cursor comes back on the branch chosen" "--bind=start:pos(" "$(args_of 3)"
out="$(run "$(picks "feature")" shell::git::commit::pick::fzf)"
t_has "flow: ESC at the mode menu" "RC=1" "$out"

# an empty list of branches, a branch with nothing left to pick, a branch that vanished
cd "$HOME/one" || exit 1
out="$(run "" shell::git::commit::pick::fzf)"
t_has "flow: no other branch" "There is no other branch to pick from" "$out"
t_has "flow: ...exit 1" "RC=1" "$out"
t_eq "flow: ...fzf never shown" "0" "$(calls)"
fresh2
out="$(run "$(picks "[local]  old")" shell::git::commit::pick::fzf)"
t_has "flow: a branch with nothing to pick says so" "No commits to pick from 'old'" "$out"
t_eq "flow: ...and the source list is shown again" "2" "$(calls)"
orig_sources="$(declare -f _shell::git::commit::pick::fzf::sources 2>/dev/null || functions _shell::git::commit::pick::fzf::sources)"
_shell::git::commit::pick::fzf::sources() { printf '[local]  ghost\trefs/heads/ghost\n'; }
out="$(run "$(picks "ghost")" shell::git::commit::pick::fzf)"
eval "$orig_sources"
t_has "flow: a branch that is not there any more" "not available any more: 'refs/heads/ghost'" "$out"
t_has "flow: ...exit 1" "RC=1" "$out"
out="$(run "" shell::git::commit::pick::fzf --all feature)"
t_has "flow: --all and a source" "cannot be combined" "$out"
t_has "flow: ...exit 2" "RC=2" "$out"
cd "$HOME/norepo" || exit 1
out="$(run "" shell::git::commit::pick::fzf)"
t_has "flow: outside a repository" "Not inside a Git repository" "$out"
fresh2
git cherry-pick -n "$X1" >/dev/null 2>&1
git cherry-pick --quit >/dev/null 2>&1
git reset -q --hard
git checkout -q -b busy-branch
git cherry-pick "$X3" >/dev/null 2>&1
out="$(run "" shell::git::commit::pick::fzf)"
t_has "flow: refused while a cherry-pick is in progress" "already in progress" "$out"
t_eq "flow: ...before any list is shown" "0" "$(calls)"
shell::git::commit::pick::abort >/dev/null 2>&1

# --- 3.2 / 3.3 mode A: pick by commit ---------------------------------------------------------------------
fresh2
out="$(run "$(picks "feature" "$S" "x3: a again${nl}x1: add a" "Cherry-pick")" shell::git::commit::pick::fzf)"
t_has "commit mode: exit 0" "RC=0" "$out"
t_eq "commit mode: both applied, oldest first whatever the marking order" "x1: add a|x3: a again" "$(subject HEAD~1)|$(subject)"
t_eq "commit mode: the list is the branch's commits not in HEAD (x1..x4)" "4" "$(lines "$HOME/stdin.3")"
t_lacks "commit mode: ...none of main's" "m1: on main" "$(rows_of 3)"
t_eq "commit mode: ...first column is the full hash" "40" "$(head -n 1 "$HOME/stdin.3" | cut -f1 | tr -d '\n' | wc -c | tr -d ' ')"
t_has "commit mode: multi-select" "--multi" "$(args_of 3)"
t_has "commit mode: Tab marks without moving the cursor" "--bind=tab:toggle" "$(args_of 3)"
t_has "commit mode: ...Shift-Tab too" "--bind=btab:toggle" "$(args_of 3)"
t_has "commit mode: the preview shows the highlighted commit" "--preview=git show --stat --patch --color=always {1} | head -n 300" "$(args_of 3)"
t_has "commit mode: ...on the right" "--preview-window=right:55%:wrap" "$(args_of 3)"
t_has "commit mode: the state is saved through the focus binding" "--bind=focus:execute-silent(" "$(args_of 3)"
t_has "commit mode: Ctrl-T flips to the files" "--bind=ctrl-t:execute-silent(" "$(args_of 3)"
t_has "commit mode: the query is read back" "--print-query" "$(args_of 3)"
t_lacks "commit mode: first visit has nothing to restore" "--bind=start:" "$(args_of 3)"
t_eq "commit mode: the action menu" "Cherry-pick${nl}Cherry-pick with reference (-x)${nl}Apply without committing (--no-commit)${nl}Preview only${nl}$B" "$(rows_of 4)"
t_has "commit mode: the plan is shown" "2 commit(s) selected, oldest first" "$out"

fresh2
out="$(run "$(picks "feature" "$S" "x2: specials" "Cherry-pick")" shell::git::commit::pick::fzf)"
t_eq "commit mode: one commit" "x2: specials" "$(subject)"
t_eq "commit mode: ...with all its special files (f, m and six more)" "8" "$(git ls-files -z | tr -cd '\0' | wc -c | tr -d ' ')"
fresh2
out="$(run "$(picks "feature" "$S" "x4: touch sp" "Cherry-pick")" shell::git::commit::pick::fzf)"
t_has "commit mode: a pick that cannot apply stops with exit 1" "RC=1" "$out"
shell::git::commit::pick::abort >/dev/null 2>&1
fresh2
out="$(run "$(picks "feature" "$S" "x1: add a" "Cherry-pick")" shell::git::commit::pick::fzf -n)"
t_has "commit mode -n: prints the command" "git cherry-pick $X1" "$out"
t_eq "commit mode -n: nothing applied" "same" "$(head_is "$FM1")"
t_has "commit mode -n: exit 0" "RC=0" "$out"
fresh2
run "$(picks "feature" "$S")" shell::git::commit::pick::fzf -c 2 >/dev/null
t_eq "commit mode -c 2: two candidates" "2" "$(lines "$HOME/stdin.3")"
run "$(picks "feature" "$S")" shell::git::commit::pick::fzf --include-head >/dev/null
t_has "commit mode --include-head: commits already in HEAD are listed" "base" "$(rows_of 3)"

# cancellation at each stage
fresh2
out="$(run "$(picks "feature" "$S")" shell::git::commit::pick::fzf)"
t_has "commit mode: ESC at the picker cancels" "Cancelled" "$out"
t_has "commit mode: ...exit 1" "RC=1" "$out"
out="$(run "$(picks "feature" "$S" "x1: add a")" shell::git::commit::pick::fzf)"
t_has "commit mode: ESC at the action menu cancels" "RC=1" "$out"
t_eq "commit mode: ...nothing applied" "$FM1" "$(git rev-parse HEAD)"

# --- 3.3 mode B: pick by files ----------------------------------------------------------------------------
fresh2
out="$(run "$(picks "feature" "$F" "-dash.txt" "$APPLY_F")" shell::git::commit::pick::fzf)"
t_has "files mode: exit 0" "RC=0" "$out"
t_eq "files mode: one row per (commit, file): 1 + 6 + 1 + 1" "9" "$(lines "$HOME/stdin.3")"
t_eq "files mode: a file changed by two commits appears twice (a)" "2" "$(grep -c '^[^	]*	a  ' "$HOME/plain.3")"
t_eq "files mode: ...and so does sp ace.txt" "2" "$(grep -c 'sp ace.txt  ' "$HOME/plain.3")"
t_has "files mode: each row names its commit" "T - x3: a again" "$(cat "$HOME/plain.3")"
t_eq "files mode: the id is <full hash>:<path>" "1" "$(grep -c "^${X3}:a	" "$HOME/stdin.3")"
t_eq "files mode: a tab in a path is stored as \\002 and shown as \\t" "1" "$(grep -c "^${X2}:ta"$'\002'"b.txt	ta\\\\tb.txt  " "$HOME/plain.3")"
t_eq "files mode: a newline in a path is stored as \\001 and shown as \\n" "1" "$(grep -c "^${X2}:new"$'\001'"line.txt	new\\\\nline.txt  " "$HOME/plain.3")"
t_has "files mode: a quote" 'q"uote.txt  ' "$(cat "$HOME/plain.3")"
t_has "files mode: non-ASCII" "ünï.txt  " "$(cat "$HOME/plain.3")"
t_has "files mode: a leading dash" "-dash.txt  " "$(cat "$HOME/plain.3")"
t_eq "files mode: rows of one file are adjacent, newest commit first (a: x3 then x1)" "x3:x1" "$(grep '^[^	]*	a  ' "$HOME/plain.3" | sed -E 's/.*T - (x[0-9]).*/\1/' | tr '\n' ':' | sed 's/:$//')"
t_has "files mode: multi-select" "--multi" "$(args_of 3)"
t_has "files mode: Tab marks without moving the cursor" "--bind=tab:toggle" "$(args_of 3)"
t_has "files mode: the preview is on the right" "--preview-window=right:55%:wrap" "$(args_of 3)"
t_has "files mode: ...and is fed the row id" "_ {1}" "$(args_of 3)"
t_eq "files mode: the action menu" "${APPLY_F}${nl}Preview only${nl}$B" "$(rows_of 4)"
t_eq "files mode: the chosen file is staged" "-dash.txt|" "$(staged)"
t_eq "files mode: ...nothing is committed" "$FM1" "$(git rev-parse HEAD)"
t_has "files mode: ...and the plan shows the file with its commit" "-dash.txt  ($(git log -1 --format=%h "$X2") x2: specials)" "$out"

# the preview command, run the way fzf runs it
prev="$(grep '^--preview=sh' "$HOME/args.3")"
prev="${prev#--preview=}"
suffix=' {1}'
prev="${prev%"$suffix"}"
id="$(cut -f1 "$HOME/stdin.3" | grep -F "${X4}:sp ace.txt")"
noansi() { sed "$(printf 's/\033\\[[0-9;]*[A-Za-z]//g')"; }
pout="$(eval "$prev \"\$id\"" 2>&1 | noansi)"
t_has "files mode preview: shows the commit" "x4: touch sp" "$pout"
t_has "files mode preview: ...and only the chosen file's change" "+s2" "$pout"
t_lacks "files mode preview: ...not the other files" "ünï.txt" "$pout"
id="$(cut -f1 "$HOME/stdin.3" | grep -F "${X2}:ta")"
pout="$(eval "$prev \"\$id\"" 2>&1 | noansi)"
t_has "files mode preview: a path with a tab" '"ta\tb.txt" | 1 +' "$pout"
t_has "files mode preview: ...its content" "+tab" "$pout"
id="$(cut -f1 "$HOME/stdin.3" | grep -F "${X2}:new")"
pout="$(eval "$prev \"\$id\"" 2>&1 | noansi)"
t_has "files mode preview: a path with a newline" '"new\nline.txt" | 1 +' "$pout"
t_has "files mode preview: ...its content" "+nl" "$pout"

# several files, special names, exact content
fresh2
out="$(run "$(picks "feature" "$F" "sp ace.txt  $(git log -1 --format=%h "$X2")${nl}ta\\tb.txt${nl}new\\nline.txt${nl}q\"uote.txt${nl}ünï.txt${nl}-dash.txt" "$APPLY_F")" shell::git::commit::pick::fzf)"
t_has "files mode: special names: exit 0" "RC=0" "$out"
t_eq "files mode: special names: exactly the six files are staged" "-dash.txt|new${nl}line.txt|q\"uote.txt|sp ace.txt|ta${tab}b.txt|ünï.txt|" "$(staged)"
t_eq "files mode: ...with their content (tab)" "tab" "$(git show ":ta${tab}b.txt")"
t_eq "files mode: ...with their content (newline)" "nl" "$(git show ":new${nl}line.txt")"
t_eq "files mode: ...and not the others of the commit" "0" "$(staged | tr '|' '\n' | grep -c '^a$')"
t_eq "files mode: ...worktree files match" "tab" "$(cat "ta${tab}b.txt")"

fresh2
out="$(run "$(picks "feature" "$F" "T - x1: add a${nl}T - x3: a again" "$APPLY_F")" shell::git::commit::pick::fzf)"
t_has "files mode: the same file from two commits: exit 0" "RC=0" "$out"
t_eq "files mode: ...both changes, oldest first" "one${nl}two" "$(git show :a)"
t_has "files mode: ...reported per commit" "2 file change(s) from 2 commit(s)" "$out"
fresh2
out="$(run "$(picks "feature" "$F" "T - x3: a again" "$APPLY_F")" shell::git::commit::pick::fzf)"
t_has "files mode: a change whose base is missing does not apply" "RC=1" "$out"
t_has "files mode: ...and says which commit" "Could not apply the chosen files of $(git log -1 --format=%h "$X3")" "$out"
t_eq "files mode: ...nothing staged" "" "$(staged)"
fresh2
out="$(run "$(picks "feature" "$F" "T - x1: add a${nl}-dash.txt" "$APPLY_F")" shell::git::commit::pick::fzf -n)"
t_has "files mode -n: prints one command per commit (x1)" "git --literal-pathspecs diff-tree -p --binary --no-renames --root --no-commit-id -r $X1 -- a | git apply --index --3way" "$out"
t_has "files mode -n: ...(x2: the literal pathspec after --)" "-r $X2 -- -dash.txt | git apply --index --3way" "$out"
t_eq "files mode -n: nothing staged" "" "$(staged)"
t_has "files mode -n: exit 0" "RC=0" "$out"

fresh2
out="$(run "$(picks "feature" "$F" "T - x1: add a" "Preview only" "T - x1: add a" "$APPLY_F")" shell::git::commit::pick::fzf)"
t_has "files mode: Preview only shows the change" "diff --git a/a b/a" "$out"
t_eq "files mode: ...then the menu comes back" "${APPLY_F}${nl}Preview only${nl}$B" "$(rows_of 5)"
fresh2
out="$(run "$(picks "feature" "$F")" shell::git::commit::pick::fzf)"
t_has "files mode: ESC at the picker cancels" "RC=1" "$out"
out="$(run "$(picks "feature" "$F" "-dash.txt")" shell::git::commit::pick::fzf)"
t_has "files mode: ESC at the action menu cancels" "RC=1" "$out"
t_eq "files mode: ...nothing staged" "" "$(staged)"
git checkout -q -b empty-diff main
git commit -q --allow-empty -m "e1: empty"
git checkout -q main
out="$(run "$(picks "empty-diff" "$F" "$S")" shell::git::commit::pick::fzf)"
t_has "files mode: commits that change no file" "change no files" "$out"
t_eq "files mode: ...fall back to the commit list (one commit)" "1" "$(lines "$HOME/stdin.3")"

# --- 3.4 cursor, marks and query across screens ----------------------------------------------------------
fresh2
out="$(run "$(picks "feature" "$S" "x1: add a${nl}x3: a again${nl}@query=add${nl}@pos=1" "$B" "x1: add a" "Cherry-pick")" shell::git::commit::pick::fzf)"
t_eq "state: Back from the action menu shows the picker again" "4" "$(lines "$HOME/stdin.5")"
t_has "state: ...with the marks (rows 2 and 4), the query and the cursor row restored" "--bind=start:pos(2)+toggle+pos(4)+toggle+change-query(add)+pos(1)" "$(args_of 5)"
t_has "state: ...the marks are applied to the full list, so --sync" "--sync" "$(args_of 5)"
t_eq "state: ...and the list is the same list" "$(rows_of 3)" "$(rows_of 5)"
fresh2
out="$(run "$(picks "feature" "$S" "x2: specials${nl}@pos=3" "$B" "x2: specials")" shell::git::commit::pick::fzf)"
t_has "state: marks and cursor without a query" "--bind=start:pos(3)+toggle+pos(3)" "$(args_of 5)"
t_lacks "state: ...no query action" "change-query" "$(args_of 5)"

# a query with brackets and a plus sign
t_eq "state: the query action avoids a delimiter the query contains" "change-query[fix(a+b)]" "$(_shell::git::commit::pick::fzf::action change-query 'fix(a+b)')"
t_eq "state: ...plain query" "change-query(abc)" "$(_shell::git::commit::pick::fzf::action change-query 'abc')"
t_eq "state: ...every bracket kind in the query" "change-query~([{<>}])~" "$(_shell::git::commit::pick::fzf::action change-query '([{<>}])')"

# restore() on its own
st="$HOME/st"
rm -f "$st.sel" "$st.query" "$st.pos"
t_eq "restore: no state, no actions" "" "$(_shell::git::commit::pick::fzf::restore "$st" "a${tab}A")"
printf 'b\n' >"$st.sel"
printf 'xy' >"$st.query"
printf '2' >"$st.pos"
t_eq "restore: marks, query, cursor" "pos(2)+toggle+change-query(xy)+pos(2)" "$(_shell::git::commit::pick::fzf::restore "$st" "a${tab}A${nl}b${tab}B")"
printf 'zz\n' >"$st.sel"
t_eq "restore: a mark that is no longer in the list is dropped" "change-query(xy)+pos(2)" "$(_shell::git::commit::pick::fzf::restore "$st" "a${tab}A${nl}b${tab}B")"
printf 'x' >"$st.pos"
printf 'b\n' >"$st.sel"
rm -f "$st.query"
t_eq "restore: a garbage cursor is ignored" "pos(2)+toggle" "$(_shell::git::commit::pick::fzf::restore "$st" "a${tab}A${nl}b${tab}B")"
rm -f "$st.sel" "$st.query" "$st.pos"

# flipping modes keeps each mode's own state
fresh2
out="$(run "$(picks "feature" "$S" "x1: add a${nl}@query=add${nl}@pos=2${nl}@switch" "-dash.txt${nl}@query=dash${nl}@pos=1${nl}@switch" "x2: specials${nl}@query=add${nl}@pos=2${nl}@switch" "$B" "$B")" shell::git::commit::pick::fzf)"
t_has "flip: Ctrl-T in the commit picker opens the files picker" "Files of feature" "$(args_of 4)"
t_lacks "flip: ...which starts fresh the first time" "--bind=start:" "$(args_of 4)"
dashrow="$(cut -f1 "$HOME/stdin.4" | grep -n -F -- "-dash.txt" | cut -d: -f1)"
t_has "flip: back to the commit picker: its marks, query and cursor are restored" "--bind=start:pos(4)+toggle+change-query(add)+pos(2)" "$(args_of 5)"
t_has "flip: ...it is the commit picker again" "Commits of feature" "$(args_of 5)"
t_has "flip: and the files picker comes back as it was left (mark, query, cursor)" "--bind=start:pos(${dashrow})+toggle+change-query(dash)+pos(1)" "$(args_of 6)"
t_has "flip: ...it is the files picker" "Files of feature" "$(args_of 6)"

# --- the rest of the surface ----------------------------------------------------------------------------
t_rc "fzf -h" 0 shell::git::commit::pick::fzf -h
t_has "fzf -h mentions --all" "--all" "$(shell::git::commit::pick::fzf -h 2>&1)"
t_has "fzf -h mentions the workflow" "source branch" "$(shell::git::commit::pick::fzf -h 2>&1)"

# the helpers on their own
fresh2
t_eq "sources: refs are full names (local and remote can not be confused)" "refs/heads/feature
refs/heads/old
refs/heads/release/1.0
refs/remotes/origin/release/1.0
refs/remotes/origin/side" "$(_shell::git::commit::pick::fzf::sources | cut -f2 | LC_ALL=C sort)"
git checkout -q feature
t_lacks "sources: on feature, feature is not offered (but main is)" "refs/heads/feature" "$(_shell::git::commit::pick::fzf::sources | cut -f2)"
t_has "sources: ...main is" "refs/heads/main" "$(_shell::git::commit::pick::fzf::sources | cut -f2)"
git checkout -q --detach
t_has "sources: on a detached HEAD every branch is offered" "refs/heads/feature" "$(_shell::git::commit::pick::fzf::sources | cut -f2)"
git checkout -q main
t_eq "file_decode: tab and newline" "a${tab}b${nl}c" "$(_shell::git::commit::pick::fzf::file_decode "a"$'\002'"b"$'\001'"c")"
t_eq "file_decode: plain" "sp ace.txt" "$(_shell::git::commit::pick::fzf::file_decode "sp ace.txt")"
t_eq "file_rows: no commits, no rows" "" "$(_shell::git::commit::pick::fzf::file_rows 5 main --not main)"
t_eq "file_rows: -c limits the commits (x4 only: sp ace.txt)" "1" "$(_shell::git::commit::pick::fzf::file_rows 1 feature --not HEAD | wc -l | tr -d ' ')"
t_eq "oldest_first: order of the list, reversed" "b
a" "$(_shell::git::commit::pick::fzf::oldest_first "a${tab}x${nl}b${tab}y" "b a")"

t_done
