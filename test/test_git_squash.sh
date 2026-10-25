#!/usr/bin/env bash
# shell::git::commit::squash::fzf in real temporary repositories. fzf is faked (scripted
# picks, then ESC); text prompts read from stdin. Checks the resulting history, the tree
# (must be identical), the message, safety refusals, automatic restore, and -n.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

git config --global user.email "t@example.com"
git config --global user.name "Test"
export GIT_EDITOR=true

mkdir "$HOME/bin"
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
n="$(cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0)"
n=$((n + 1))
echo "$n" >"$FAKE_FZF_STATE"
cat >"$FAKE_FZF_DIR/stdin.$n"
pick="$(printf '%s\n' "$FAKE_FZF_PICKS" | sed -n "${n}p")"
[ -z "$pick" ] && exit 130
printf '%s\n' "$pick"
FAKE
chmod +x "$HOME/bin/fzf"
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_FZF_PICKS=""

reset_fzf() {
	find "$HOME" -maxdepth 1 -name 'stdin.*' -delete
	rm -f "$FAKE_FZF_STATE"
}
B="$SHELL_FZF_BACK_LABEL"
nl='
'

# run_squash <picks> <stdin text> [args...]  -> output, then a final RC=<n> line
run_squash() {
	local picks="$1" input="$2"
	shift 2
	reset_fzf
	printf '%s' "$input" | FAKE_FZF_PICKS="$picks" shell::git::commit::squash::fzf "$@" 2>&1
	echo "RC=$?"
}
line_of() { git log -1 --oneline "$1"; }

# mkrepo <n>: branch main with n commits, subjects "feat: one", "fix: two", ... (subj() avoids
# array indexing, which starts at 0 in bash and 1 in zsh)
subj() { case "$1" in 0) echo "feat: one" ;; 1) echo "fix: two" ;; 2) echo "docs: three" ;; 3) echo "refactor: four" ;; 4) echo "test: five" ;; 5) echo "chore: six" ;; esac }
mkrepo() {
	cd "$HOME" && rm -rf "$HOME/r" "$HOME/remote.git" && mkdir "$HOME/r" && cd "$HOME/r" || exit 1
	git init -q && git checkout -q -b main
	local i=0
	while [ "$i" -lt "$1" ]; do
		printf 'line %s\n' "$i" >>f
		git add f
		git commit -q -m "$(subj "$i")"
		i=$((i + 1))
	done
}

# --- happy path: combined messages ------------------------------------------------------------
mkrepo 5
old="$(git rev-parse HEAD)"
tree="$(git rev-parse 'HEAD^{tree}')"
c1="$(git rev-parse HEAD~4)"
base_line="$(line_of HEAD~3)"
out="$(run_squash "${base_line}${nl}Combined messages${nl}Squash" "")"
t_has "happy: succeeded" "RC=0" "$out"
t_eq "happy: 5 commits became 2" "2" "$(git rev-list --count HEAD)"
t_eq "happy: the parent is the commit before the base" "$c1" "$(git rev-parse HEAD^)"
t_eq "happy: the tree is IDENTICAL to the old HEAD" "$tree" "$(git rev-parse 'HEAD^{tree}')"
msg="$(git log -1 --format=%B)"
t_has "happy: starts with the base message" "fix: two" "$(printf '%s\n' "$msg" | head -n 1)"
t_has "happy: lists folded subjects" "- docs: three" "$msg"
t_has "happy: ...all of them" "- test: five" "$msg"
t_lacks "happy: ...but not the base again" "- fix: two" "$msg"
t_has "happy: prints the previous HEAD for undo" "Previous HEAD: $old" "$out"
t_has "happy: the undo command is shown" "git reset --soft $old" "$out"
t_eq "happy: first screen lists all commits plus Back" "6" "$(wc -l <"$HOME/stdin.1" | tr -d ' ')"
t_eq "happy: Back entry is last" "$B" "$(tail -n 1 "$HOME/stdin.1")"
# the undo hint works
git reset -q --soft "$old"
t_eq "undo: reset --soft restores the old HEAD" "$old" "$(git rev-parse HEAD)"

# --- --count limits the list --------------------------------------------------------------------
mkrepo 6
out="$(run_squash "" "" -c 3)"
t_eq "--count 3 lists 3 commits + Back" "4" "$(wc -l <"$HOME/stdin.1" | tr -d ' ')"
out="$(run_squash "" "" --count=4)"
t_eq "--count=4 form" "5" "$(wc -l <"$HOME/stdin.1" | tr -d ' ')"
t_has "ESC at the picker fails (exit 1) and says nothing changed" "RC=1" "$out"

# --- other message choices ---------------------------------------------------------------------
mkrepo 4
base_line="$(line_of HEAD~2)"
out="$(run_squash "${base_line}${nl}Write a new message${nl}Squash" "feat: squashed everything${nl}")"
t_has "new message: succeeded" "RC=0" "$out"
t_eq "new message: exactly what was typed" "feat: squashed everything" "$(git log -1 --format=%B | sed '/^$/d')"
t_eq "new message: 4 commits -> 2" "2" "$(git rev-list --count HEAD)"

mkrepo 4
base_line="$(line_of HEAD~2)"
out="$(run_squash "${base_line}${nl}Edit combined messages in my editor${nl}Squash" "")"
t_has "editor: succeeded" "RC=0" "$out"
t_has "editor: the combined message was committed (editor 'true' keeps it)" "- docs: three" "$(git log -1 --format=%B)"

# --- Back navigation ------------------------------------------------------------------------------
mkrepo 5
l1="$(line_of HEAD~3)"
l2="$(line_of HEAD~2)"
out="$(run_squash "${l1}${nl}${B}${nl}${l2}${nl}Combined messages${nl}Squash" "")"
t_has "back at the message menu returns to the picker" "RC=0" "$out"
t_eq "back: the second base was used (5 -> 3 commits)" "3" "$(git rev-list --count HEAD)"

mkrepo 5
l1="$(line_of HEAD~3)"
out="$(run_squash "${l1}${nl}Combined messages${nl}${B}${nl}Write a new message${nl}Squash" "custom msg${nl}")"
t_has "back at the confirmation returns to the message menu" "RC=0" "$out"
t_eq "back: the new message was used" "custom msg" "$(git log -1 --format=%B | sed '/^$/d')"

mkrepo 5
l1="$(line_of HEAD~3)"
out="$(run_squash "${l1}${nl}Write a new message${nl}Combined messages${nl}Squash" ":back${nl}")"
t_has ":back at the text prompt returns to the message menu" "RC=0" "$out"
t_has "back: ...and the combined message was used" "- docs: three" "$(git log -1 --format=%B)"

mkrepo 5
old="$(git rev-parse HEAD)"
out="$(run_squash "$B" "")"
t_has "back at the first screen cancels with exit 1" "RC=1" "$out"
t_eq "...and changes nothing" "$old" "$(git rev-parse HEAD)"

# --- picking HEAD is refused (needs two commits) --------------------------------------------------
mkrepo 4
head_line="$(line_of HEAD)"
base_line="$(line_of HEAD~2)"
out="$(run_squash "${head_line}${nl}${base_line}${nl}Combined messages${nl}Squash" "")"
t_has "HEAD as base: warns and asks again" "pick an older one" "$out"
t_has "...then succeeds with a proper base" "RC=0" "$out"

# --- abort / dry-run leave the repository untouched ------------------------------------------------
mkrepo 4
old="$(git rev-parse HEAD)"
base_line="$(line_of HEAD~2)"
out="$(run_squash "${base_line}${nl}Combined messages${nl}Abort" "")"
t_has "abort: exit 1" "RC=1" "$out"
t_eq "abort: HEAD unchanged" "$old" "$(git rev-parse HEAD)"

out="$(run_squash "${base_line}${nl}Combined messages${nl}Squash" "" -n)"
t_has "dry-run: exit 0" "RC=0" "$out"
t_has "dry-run: prints the soft reset to the parent" "git reset --soft $(git rev-parse HEAD~3)" "$out"
t_has "dry-run: prints the commit" "git commit -m" "$out"
t_eq "dry-run: HEAD unchanged" "$old" "$(git rev-parse HEAD)"
t_eq "dry-run: still 4 commits" "4" "$(git rev-list --count HEAD)"

# --- root commit ---------------------------------------------------------------------------------------
mkrepo 4
tree="$(git rev-parse 'HEAD^{tree}')"
root_line="$(line_of "$(git rev-list --max-parents=0 HEAD)")"
out="$(run_squash "${root_line}${nl}Combined messages${nl}Squash" "")"
t_has "root: succeeded" "RC=0" "$out"
t_eq "root: a single commit remains" "1" "$(git rev-list --count HEAD)"
t_eq "root: it has no parent" "0" "$(git rev-list --parents -n 1 HEAD | wc -w | tr -d ' ' | awk '{ print $1 - 1 }')"
t_eq "root: the tree is identical" "$tree" "$(git rev-parse 'HEAD^{tree}')"
t_eq "root: still on branch main" "main" "$(git symbolic-ref --short HEAD)"
out="$(run_squash "${root_line}${nl}Combined messages${nl}Squash" "" -n)"

# --- the commit fails -> the original history is restored ----------------------------------------------
mkrepo 4
old="$(git rev-parse HEAD)"
printf '#!/bin/sh\nexit 1\n' >.git/hooks/commit-msg && chmod +x .git/hooks/commit-msg
base_line="$(line_of HEAD~2)"
out="$(run_squash "${base_line}${nl}Combined messages${nl}Squash" "")"
t_has "hook rejects: exit 1" "RC=1" "$out"
t_has "hook rejects: says it restored" "original history was restored" "$out"
t_eq "hook rejects: HEAD is back" "$old" "$(git rev-parse HEAD)"
t_eq "hook rejects: nothing left staged" "0" "$(git diff --cached --name-only | wc -l | tr -d ' ')"
t_eq "hook rejects: still on main" "main" "$(git symbolic-ref --short HEAD)"

mkrepo 4
old="$(git rev-parse HEAD)"
printf '#!/bin/sh\nexit 1\n' >.git/hooks/commit-msg && chmod +x .git/hooks/commit-msg
root_line="$(line_of "$(git rev-list --max-parents=0 HEAD)")"
out="$(run_squash "${root_line}${nl}Combined messages${nl}Squash" "")"
t_has "root + hook rejects: restored" "original history was restored" "$out"
t_eq "root + hook rejects: HEAD is back" "$old" "$(git rev-parse HEAD)"
t_eq "root + hook rejects: branch exists again" "main" "$(git symbolic-ref --short HEAD)"
t_eq "root + hook rejects: full history intact" "4" "$(git rev-list --count HEAD)"

# --- safety refusals ----------------------------------------------------------------------------------------
mkrepo 4
old="$(git rev-parse HEAD)"
echo staged >>f && git add f
out="$(run_squash "" "")"
t_has "staged changes: refused" "staged changes" "$out"
t_has "staged changes: exit 1" "RC=1" "$out"
t_eq "staged changes: picker never shown" "0" "$(test -e "$HOME/fzf.count" && echo 1 || echo 0)"
git reset -q --hard

echo unstaged >>f
base_line="$(line_of HEAD~2)"
out="$(run_squash "${base_line}${nl}Combined messages${nl}Squash" "")"
t_has "unstaged edits: allowed" "RC=0" "$out"
t_eq "unstaged edits: preserved in the working tree" "unstaged" "$(tail -n 1 f)"
t_has "unstaged edits: still reported as modified" "f" "$(git status --porcelain)"
git checkout -q -- f

mkrepo 4
git checkout -q --detach
out="$(run_squash "" "")"
t_has "detached HEAD: refused" "HEAD is detached" "$out"
t_has "detached HEAD: exit 1" "RC=1" "$out"
git checkout -q main

mkrepo 4
git rev-parse HEAD >.git/MERGE_HEAD
out="$(run_squash "" "")"
t_has "merge in progress: refused" "MERGE_HEAD operation is in progress" "$out"
rm -f .git/MERGE_HEAD

mkrepo 1
out="$(run_squash "" "")"
t_has "single commit: refused" "at least two commits" "$out"

cd "$HOME" && rm -rf "$HOME/notrepo" && mkdir "$HOME/notrepo" && cd "$HOME/notrepo" || exit 1
out="$(run_squash "" "")"
t_has "outside a repository: refused" "Not inside a Git repository" "$out"
t_has "outside a repository: exit 1" "RC=1" "$out"

# --- warnings ---------------------------------------------------------------------------------------------------
mkrepo 4
git init -q --bare "$HOME/remote.git"
git remote add origin "$HOME/remote.git"
git push -q -u origin main 2>/dev/null
base_line="$(line_of HEAD~2)"
out="$(run_squash "${base_line}${nl}Combined messages${nl}Squash" "")"
t_has "published: warns before" "already on origin/main" "$out"
t_has "published: hints the force push after" "git push --force-with-lease" "$out"
t_has "published: but never pushes" "RC=0" "$out"
t_eq "published: the remote still has the old history" "4" "$(git --git-dir="$HOME/remote.git" rev-list --count main)"

mkrepo 3
git checkout -q -b side
echo side >s && git add s && git commit -q -m "feat: side work"
git checkout -q main
git merge -q --no-ff side -m "Merge branch side" >/dev/null 2>&1
echo more >>f && git add f && git commit -q -m "fix: after merge"
tree="$(git rev-parse 'HEAD^{tree}')"
base_line="$(line_of HEAD~3)"
out="$(run_squash "${base_line}${nl}Combined messages${nl}Squash" "")"
t_has "merge commits: warns" "merge commit" "$out"
t_has "merge commits: still succeeds" "RC=0" "$out"
t_eq "merge commits: tree preserved (nothing lost)" "$tree" "$(git rev-parse 'HEAD^{tree}')"

# --- special characters survive (message goes through -F) --------------------------------------------------
cd "$HOME" && rm -rf "$HOME/r" && mkdir "$HOME/r" && cd "$HOME/r" || exit 1
git init -q && git checkout -q -b main
echo a >f && git add f && git commit -q -m 'feat: base'
echo b >>f && git add f && git commit -q -m 'fix: handle "quotes" and $HOME and `ticks`'
echo c >>f && git add f && git commit -q -m "fix: it's a single quote; and & pipes | too"
base_line="$(line_of HEAD~2)"
out="$(run_squash "${base_line}${nl}Combined messages${nl}Squash" "")"
t_has "special chars: succeeded" "RC=0" "$out"
msg="$(git log -1 --format=%B)"
t_has "special chars: double quotes and \$HOME kept literally" '- fix: handle "quotes" and $HOME and `ticks`' "$msg"
t_has "special chars: single quote and metacharacters kept" "- fix: it's a single quote; and & pipes | too" "$msg"

# --- usage errors ------------------------------------------------------------------------------------------------
mkrepo 3
for bad in "-c 1" "-c 0" "-c abc" "-c -5" "--count=x" "-c" "--bogus" "extra"; do
	# shellcheck disable=SC2086
	out="$(run_squash "" "" $bad)"
	t_has "usage error [$bad]" "RC=2" "$out"
done
t_rc "help" 0 shell::git::commit::squash::fzf -h
t_has "help mentions --count" "--count" "$T_OUT"

t_done
