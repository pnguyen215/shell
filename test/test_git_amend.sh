#!/usr/bin/env bash
# shell::git::commit::amend in real temporary repositories with a real (bare) remote.
# GIT_EDITOR is a tiny script that rewrites the message; fzf is faked for the push prompt.
# Covers: staged vs message-only amends, --no-edit refusal, --force-with-lease (including a
# stale lease that must NOT overwrite somebody else's push), prompt, dry-run, early failures.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

git config --global user.email "t@example.com"
git config --global user.name "Test"

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
printf '#!/bin/sh\nprintf "feat: reworded\\n" >"$1"\n' >"$HOME/bin/rewrite-editor"
chmod +x "$HOME/bin/rewrite-editor"
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_FZF_PICKS=""
export GIT_EDITOR=true

reset_fzf() {
	find "$HOME" -maxdepth 1 -name 'stdin.*' -delete
	rm -f "$FAKE_FZF_STATE"
}
nl='
'
# run_amend <picks> [args...] -> output, then a final RC=<n> line
run_amend() {
	local picks="$1"
	shift
	reset_fzf
	FAKE_FZF_PICKS="$picks" shell::git::commit::amend "$@" 2>&1
	echo "RC=$?"
}
remote_tip() { git --git-dir="$HOME/remote.git" rev-parse "${1:-main}" 2>/dev/null; }

# mkrepo [remote]: branch main with 3 commits; with "remote" a bare origin and upstream set.
mkrepo() {
	cd "$HOME" && rm -rf "$HOME/r" "$HOME/remote.git" "$HOME/other" && mkdir "$HOME/r" && cd "$HOME/r" || exit 1
	git init -q && git checkout -q -b main
	local i=1
	while [ "$i" -le 3 ]; do
		printf 'line %s\n' "$i" >>f
		git add f
		git commit -q -m "commit $i"
		i=$((i + 1))
	done
	if [ "${1-}" = "remote" ]; then
		git init -q --bare "$HOME/remote.git"
		git remote add origin "$HOME/remote.git"
		git push -q -u origin main 2>/dev/null
	fi
}

# --- --no-edit with staged changes ---------------------------------------------------------------
mkrepo
old="$(git rev-parse HEAD)"
echo extra >g && git add g
out="$(run_amend "" --no-edit)"
t_has "no-edit: succeeded" "RC=0" "$out"
t_eq "no-edit: still 3 commits" "3" "$(git rev-list --count HEAD)"
t_eq "no-edit: message unchanged" "commit 3" "$(git log -1 --format=%s)"
t_rc "no-edit: the staged file is in the commit" 0 git cat-file -e HEAD:g
t_eq "no-edit: the hash changed" "1" "$([ "$(git rev-parse HEAD)" != "$old" ] && echo 1 || echo 0)"
t_has "no-edit: prints the previous commit" "Previous commit: $old" "$out"
t_has "no-edit: shows how to go back" "git reset --soft $old" "$out"
t_eq "no-edit: parent untouched" "$(git rev-parse HEAD~1)" "$(git rev-parse "${old}~1")"

# --- --no-edit with nothing staged is refused -------------------------------------------------------
mkrepo
old="$(git rev-parse HEAD)"
out="$(run_amend "" --no-edit)"
t_has "no-edit, nothing staged: refused" "would amend nothing" "$out"
t_has "no-edit, nothing staged: exit 1" "RC=1" "$out"
t_eq "no-edit, nothing staged: HEAD unchanged" "$old" "$(git rev-parse HEAD)"

# --- default (editor) mode ----------------------------------------------------------------------------
mkrepo
tree="$(git rev-parse 'HEAD^{tree}')"
out="$(GIT_EDITOR="$HOME/bin/rewrite-editor" run_amend "")"
t_has "reword only: succeeded" "RC=0" "$out"
t_has "reword only: says only the message changes" "only the commit message will be edited" "$out"
t_eq "reword only: new message" "feat: reworded" "$(git log -1 --format=%s)"
t_eq "reword only: tree identical" "$tree" "$(git rev-parse 'HEAD^{tree}')"

mkrepo
echo extra >g && git add g
out="$(GIT_EDITOR="$HOME/bin/rewrite-editor" run_amend "" -e)"
t_has "-e with staged: succeeded" "RC=0" "$out"
t_eq "-e with staged: message edited" "feat: reworded" "$(git log -1 --format=%s)"
t_rc "-e with staged: content added" 0 git cat-file -e HEAD:g
t_has "-e: the editor flag was passed" "git commit --amend --edit" "$out"

# --- unstaged changes are reported but not included -------------------------------------------------------
mkrepo
echo extra >g && git add g
echo "changed" >>f
out="$(run_amend "" --no-edit)"
t_has "unstaged: noted" "1 file(s) with unstaged changes" "$out"
t_rc "unstaged: the staged file is in the commit" 0 git cat-file -e HEAD:g
t_lacks "unstaged: the unstaged edit is NOT in the commit" "changed" "$(git show HEAD:f)"
t_has "unstaged: still modified in the working tree" " M f" "$(git status --porcelain)"

# --- usage errors ------------------------------------------------------------------------------------------------
mkrepo
for bad in "--edit --no-edit" "--bogus" "extra" "-x"; do
	# shellcheck disable=SC2086
	out="$(run_amend "" $bad)"
	t_has "usage error [$bad]" "RC=2" "$out"
done
t_rc "help" 0 shell::git::commit::amend -h
t_has "help shows the options" "--no-edit" "$T_OUT"

# --- dry-run -------------------------------------------------------------------------------------------------------
mkrepo remote
old="$(git rev-parse HEAD)"
echo extra >g && git add g
out="$(run_amend "" --no-edit -p -n)"
t_has "dry-run: exit 0" "RC=0" "$out"
t_has "dry-run: prints the amend" "git commit --amend --no-edit" "$out"
t_has "dry-run: prints the lease push" "git push --force-with-lease origin refs/heads/main:refs/heads/main" "$out"
t_eq "dry-run: HEAD unchanged" "$old" "$(git rev-parse HEAD)"
t_eq "dry-run: remote unchanged" "$old" "$(remote_tip)"
t_has "dry-run: the staged file is still staged" "A  g" "$(git status --porcelain)"
out="$(run_amend "" --no-edit -n)"
t_lacks "dry-run without -p: no push command" "git push" "$out"
t_has "dry-run: warns the commit is published" "already on origin/main" "$out"

# --- --push (force-with-lease) -----------------------------------------------------------------------------------
mkrepo remote
old="$(git rev-parse HEAD)"
echo extra >g && git add g
out="$(run_amend "" --no-edit -p)"
t_has "push: succeeded" "RC=0" "$out"
t_eq "push: the remote now has the amended commit" "$(git rev-parse HEAD)" "$(remote_tip)"
t_eq "push: ...not the old one" "1" "$([ "$(remote_tip)" != "$old" ] && echo 1 || echo 0)"
t_eq "push: tracking ref updated" "$(git rev-parse HEAD)" "$(git rev-parse origin/main)"
t_has "push: reported" "with --force-with-lease" "$out"
t_eq "push: no prompt was needed" "0" "$(test -e "$HOME/fzf.count" && echo 1 || echo 0)"

# stale lease: somebody else pushed meanwhile; their work must survive
mkrepo remote
git clone -q -b main "$HOME/remote.git" "$HOME/other" 2>/dev/null
(cd "$HOME/other" && git config user.email o@e.com && git config user.name O && echo theirs >t && git add t && git commit -q -m "their commit" && git push -q origin main 2>/dev/null)
theirs="$(remote_tip)"
t_eq "stale lease setup: the remote moved ahead of our tracking ref" "1" "$([ "$theirs" != "$(git rev-parse origin/main)" ] && echo 1 || echo 0)"
echo extra >g && git add g
out="$(run_amend "" --no-edit -p)"
t_has "stale lease: push is rejected, exit 1" "RC=1" "$out"
t_has "stale lease: says the push failed" "Push failed" "$out"
t_eq "stale lease: THEIR commit is still on the remote" "$theirs" "$(remote_tip)"
t_rc "stale lease: the amend itself stayed local" 0 git cat-file -e HEAD:g
t_eq "stale lease: ...and is not on the remote" "absent" "$(git --git-dir="$HOME/remote.git" cat-file -e main:g >/dev/null 2>&1 && echo present || echo absent)"

# upstream branch has a different name
mkrepo remote
git checkout -q -b topic
git config branch.topic.remote origin
git config branch.topic.merge refs/heads/topic-remote
git push -q origin topic:topic-remote 2>/dev/null
git fetch -q origin 2>/dev/null
echo extra >g && git add g
out="$(run_amend "" --no-edit -p)"
t_has "different upstream name: succeeded" "RC=0" "$out"
t_eq "different upstream name: pushed to topic-remote" "$(git rev-parse HEAD)" "$(remote_tip topic-remote)"
t_eq "different upstream name: no stray 'topic' branch created" "" "$(git --git-dir="$HOME/remote.git" rev-parse --verify --quiet refs/heads/topic)"

# no upstream: new branch on origin
mkrepo remote
git checkout -q -b fresh
echo extra >g && git add g
out="$(run_amend "" --no-edit -p)"
t_has "no upstream: pushes to origin" "RC=0" "$out"
t_eq "no upstream: the branch exists on the remote" "$(git rev-parse HEAD)" "$(remote_tip fresh)"

# --- failing early, before anything changes ------------------------------------------------------------------------------
mkrepo
old="$(git rev-parse HEAD)"
echo extra >g && git add g
out="$(run_amend "" --no-edit -p)"
t_has "no remote + --push: refused" "no remote" "$out"
t_has "no remote + --push: exit 1" "RC=1" "$out"
t_eq "no remote + --push: nothing was amended" "$old" "$(git rev-parse HEAD)"
t_has "no remote + --push: the change is still staged" "A  g" "$(git status --porcelain)"

mkrepo remote
git remote add second "$HOME/remote.git"
git remote rename origin first >/dev/null 2>&1
git config --unset branch.main.remote
git config --unset branch.main.merge
old="$(git rev-parse HEAD)"
echo extra >g && git add g
out="$(run_amend "" --no-edit -p)"
t_has "several remotes, no origin: refused" "none is named origin" "$out"
t_eq "several remotes, no origin: nothing amended" "$old" "$(git rev-parse HEAD)"

mkrepo remote
git checkout -q --detach
echo extra >g && git add g
out="$(run_amend "" --no-edit -p)"
t_has "detached HEAD + --push: refused" "HEAD is detached" "$out"
out="$(run_amend "" --no-edit)"
t_has "detached HEAD without --push: amend works" "RC=0" "$out"

# --- hooks ------------------------------------------------------------------------------------------------------------------
mkrepo
old="$(git rev-parse HEAD)"
printf '#!/bin/sh\nexit 1\n' >.git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
echo extra >g && git add g
out="$(run_amend "" --no-edit)"
t_has "failing hook: exit 1" "RC=1" "$out"
t_has "failing hook: says the commit is unchanged" "left unchanged" "$out"
t_eq "failing hook: HEAD unchanged" "$old" "$(git rev-parse HEAD)"
t_has "failing hook: change still staged" "A  g" "$(git status --porcelain)"

# --- the prompt (commit was already published, no --push) ----------------------------------------------------------------------
mkrepo remote
old="$(git rev-parse HEAD)"
echo extra >g && git add g
out="$(run_amend "Push with --force-with-lease" --no-edit)"
t_has "prompt: warns before" "already on origin/main" "$out"
t_has "prompt: push accepted" "RC=0" "$out"
t_eq "prompt: remote updated" "$(git rev-parse HEAD)" "$(remote_tip)"
t_eq "prompt: the menu offered both choices" "Push with --force-with-lease${nl}Don't push" "$(cat "$HOME/stdin.1")"

mkrepo remote
old="$(git rev-parse HEAD)"
echo extra >g && git add g
out="$(run_amend "Don't push" --no-edit)"
t_has "prompt: declined -> exit 0" "RC=0" "$out"
t_has "prompt: declined -> hint to push later" "git push --force-with-lease" "$out"
t_eq "prompt: declined -> remote untouched" "$old" "$(remote_tip)"

mkrepo remote
old="$(git rev-parse HEAD)"
echo extra >g && git add g
out="$(run_amend "" --no-edit)"
t_has "prompt: ESC -> exit 0" "RC=0" "$out"
t_eq "prompt: ESC -> remote untouched" "$old" "$(remote_tip)"

# a commit that was never pushed needs no force push and no question
mkrepo remote
echo new >n && git add n && git commit -q -m "local only"
echo extra >g && git add g
out="$(run_amend "" --no-edit)"
t_has "unpublished commit: succeeded" "RC=0" "$out"
t_lacks "unpublished commit: no warning" "already on" "$out"
t_eq "unpublished commit: no prompt" "0" "$(test -e "$HOME/fzf.count" && echo 1 || echo 0)"

# --- guards ------------------------------------------------------------------------------------------------------------------------
cd "$HOME" && rm -rf "$HOME/notrepo" && mkdir "$HOME/notrepo" && cd "$HOME/notrepo" || exit 1
out="$(run_amend "" --no-edit)"
t_has "outside a repository" "Not inside a Git repository" "$out"
t_has "outside a repository: exit 1" "RC=1" "$out"
git init -q
out="$(run_amend "" --no-edit)"
t_has "no commits yet" "no commit to amend" "$out"
t_has "no commits yet: exit 1" "RC=1" "$out"

t_done
