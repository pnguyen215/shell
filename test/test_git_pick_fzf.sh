#!/usr/bin/env bash
# The fzf group: fzf, ::local, ::remote, ::branch, ::current, ::range, ::backport, ::conflicts,
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
printf '%s\n' "$rec" | while IFS= read -r want; do
	[ -z "$want" ] && continue
	line="$(grep -F -x -- "$want" "$FAKE_FZF_DIR/stdin.$n" | head -n 1)"
	[ -z "$line" ] && line="$(grep -F -- "$want" "$FAKE_FZF_DIR/stdin.$n" | head -n 1)"
	[ -n "$line" ] && printf '%s\n' "$line"
done
exit 0
FAKE
chmod +x "$HOME/bin/fzf"
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_FZF_PICKS=""

reset_fzf() {
	find "$HOME" -maxdepth 1 \( -name 'stdin.*' -o -name 'args.*' \) -delete
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
busy() { shell::git::commit::pick::in_progress && echo yes || echo no; }
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
out="$(run "$(picks "f2: add b${nl}f1: add a" "Cherry-pick")" shell::git::commit::pick::fzf)"
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
out="$(run "$(picks "f2: add b" "Cherry-pick with reference (-x)")" shell::git::commit::pick::fzf)"
t_has "fzf: with reference" "(cherry picked from commit $F2)" "$(git log -1 --format=%B)"
fresh
out="$(run "$(picks "f2: add b" "Apply without committing (--no-commit)")" shell::git::commit::pick::fzf)"
t_eq "fzf: --no-commit leaves HEAD" "$M1" "$(git rev-parse HEAD)"
t_has "fzf: ...and stages" "A  b" "$(git status --short)"

fresh
out="$(run "$(picks "f1: add a" "Preview only" "Cherry-pick")" shell::git::commit::pick::fzf)"
t_has "fzf: Preview only shows the commit" "diff --git a/a b/a" "$out"
t_eq "fzf: ...then the menu comes back" "5" "$(lines "$HOME/stdin.3")"
t_eq "fzf: ...and the commit can still be applied" "f1: add a" "$(subject)"
t_has "fzf: ...exit 0" "RC=0" "$out"

fresh
out="$(run "$(picks "f1: add a" "$B" "f2: add b" "Cherry-pick")" shell::git::commit::pick::fzf)"
t_eq "fzf: Back returns to the list" "7" "$(lines "$HOME/stdin.3")"
t_eq "fzf: ...and the second choice is what is applied" "f2: add b" "$(subject)"
t_eq "fzf: ...f1 was not" "$M1" "$(git rev-parse HEAD~1)"

fresh
out="$(run "" shell::git::commit::pick::fzf)"
t_has "fzf: ESC at the list cancels" "Cancelled" "$out"
t_has "fzf: ...exit 1" "RC=1" "$out"
t_eq "fzf: ...nothing applied" "$M1" "$(git rev-parse HEAD)"
out="$(run "$(picks "f1: add a")" shell::git::commit::pick::fzf)"
t_has "fzf: ESC at the menu cancels" "RC=1" "$out"
t_eq "fzf: ...nothing applied" "$M1" "$(git rev-parse HEAD)"
out="$(run "$(picks "no-such-text")" shell::git::commit::pick::fzf)"
t_has "fzf: nothing matched = nothing selected" "RC=1" "$out"

fresh
out="$(run "$(picks "f1: add a${nl}f2: add b" "Cherry-pick")" shell::git::commit::pick::fzf -n)"
t_has "fzf -n: prints the command" "git cherry-pick $F1 $F2" "$out"
t_eq "fzf -n: applies nothing" "$M1" "$(git rev-parse HEAD)"
t_has "fzf -n: exit 0" "RC=0" "$out"

fresh
run "" shell::git::commit::pick::fzf -c 2 >/dev/null
t_eq "fzf -c 2: two candidates" "2" "$(lines "$HOME/stdin.1")"
run "" shell::git::commit::pick::fzf --count=3 >/dev/null
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
out="$(run "$(picks "f3: change f" "Cherry-pick")" shell::git::commit::pick::fzf)"
t_has "fzf: a conflict stops with exit 1" "RC=1" "$out"
t_eq "fzf: ...leaving a cherry-pick in progress" "yes" "$(busy)"
out="$(run "" shell::git::commit::pick::fzf)"
t_has "fzf: refused up front while one is in progress" "already in progress" "$out"
t_eq "fzf: ...the list was not even shown" "0" "$(calls)"
shell::git::commit::pick::abort >/dev/null 2>&1

fresh
echo staged >s2 && git add s2
out="$(run "$(picks "f1: add a" "Cherry-pick")" shell::git::commit::pick::fzf)"
t_has "fzf: staged changes stop the plain cherry-pick" "staged changes" "$out"
t_has "fzf: ...exit 1" "RC=1" "$out"
out="$(run "$(picks "f1: add a" "Apply without committing (--no-commit)")" shell::git::commit::pick::fzf)"
t_has "fzf: ...but --no-commit is fine" "RC=0" "$out"

cd "$HOME" && rm -rf one && mkdir one && cd one || exit 1
git init -q && echo x >x && git add x && git commit -q -m "only"
out="$(run "" shell::git::commit::pick::fzf)"
t_has "fzf: nothing to pick from" "No commits to pick from" "$out"
t_has "fzf: ...exit 1" "RC=1" "$out"
cd "$HOME" && rm -rf norepo && mkdir norepo && cd norepo || exit 1
out="$(run "" shell::git::commit::pick::fzf)"
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
t_eq "fzf::branch: ...and every other branch" "5" "$(lines "$HOME/stdin.1")"
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

t_done
