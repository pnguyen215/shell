#!/usr/bin/env bash
# The stash group of the Git toolkit: pick, save, apply, drop.
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
t_setup
. "$SHELL_TEST_ROOT/test/support/git_toolkit.sh"
_shell::git::core::boot

# run <function> [args...]: stdout in $OUT, stderr in $ERR, status in $RC (stdin closed: never a terminal)
run() {
	OUT="$("$@" 2>"$HOME/err" </dev/null)"
	RC=$?
	ERR="$(cat "$HOME/err")"
}
esc="$(printf '\033')"

gt_init "$HOME/repo"
gt_commit "base" shared.txt "base"
gt_fake_fzf
mkdir "$HOME/notrepo"

# ---------------------------------------------------------------- save
run shell::git::stash::save -h
t_eq "save -h: exit 0" "0" "$RC"
t_has "save -h: usage" "shell::git::stash::save" "$OUT"
run shell::git::stash::save -m "nothing"
t_eq "save: nothing to stash is 1" "1" "$RC"
t_has "save: ...says so" "nothing to stash" "$ERR"
printf 'only untracked\n' >untracked.txt
run shell::git::stash::save -m "u"
t_eq "save: untracked files alone are not stashed without -u (1)" "1" "$RC"
t_has "save: ...and the hint says --include-untracked" "--include-untracked" "$ERR"
run shell::git::stash::save -n -u -m "with untracked"
t_eq "save -n: exit 0" "0" "$RC"
t_eq "save -n: prints the exact command" "git stash push --include-untracked -m with\\ untracked" "$OUT"
t_eq "save -n: nothing was stashed" "0" "$(git stash list | wc -l | tr -d ' ')"
run shell::git::stash::save -u -m "with untracked"
t_eq "save -u: exit 0" "0" "$RC"
t_eq "save: stdout is the new reference" "stash@{0}" "$OUT"
t_eq "save -u: the untracked file went into the stash" "0" "$([ -e untracked.txt ] && echo 1 || echo 0)"
t_eq "save: the stash carries the name" "1" "$(git stash list | grep -c 'with untracked')"

printf 'change\n' >>shared.txt
run shell::git::stash::save -m "tracked only"
t_eq "save -m: exit 0" "0" "$RC"
printf 'two\n' >>shared.txt
run shell::git::stash::save wip words as name
t_eq "save: plain words become the name" "1" "$(git stash list | grep -c 'wip words as name')"
printf 'three\n' >>shared.txt
run shell::git::stash::save -- -dash start
t_eq "save: a name starting with a dash after --" "1" "$(git stash list | grep -c -- '-dash start')"
printf 'four\n' >>shared.txt
run shell::git::stash::save -m "it's \"quoted\" ünï	tab"
t_eq "save: quotes, unicode and tab in the name" "0" "$RC"
t_eq "save: ...kept as given (git itself turns the tab into a space)" "1" "$(git log -g -1 --format=%gs 'stash@{0}' | grep -cF "it's \"quoted\" ünï tab")"
printf 'five\n' >>shared.txt
run shell::git::stash::save
t_eq "save: no name and no terminal is 2" "2" "$RC"
t_eq "save: ...and nothing was stashed" "1" "$(git status --porcelain | wc -l | tr -d ' ')"
gt_input "typed name"
OUT="$(shell::git::stash::save 2>"$HOME/err")"
t_eq "save: the name can be typed" "stash@{0}" "$OUT"
_shell::git::core::input_close
unset SHELL_GIT_INPUT
t_eq "save: ...and is used" "1" "$(git stash list | grep -c 'typed name')"
run shell::git::stash::save --bogus
t_eq "save: unknown option is 2" "2" "$RC"
run shell::git::stash::save -m
t_eq "save: -m without a value is 2" "2" "$RC"

printf 'k\n' >>shared.txt
git add shared.txt
printf 'extra\n' >>shared.txt
run shell::git::stash::save -k -m "keep index"
t_eq "save -k: exit 0" "0" "$RC"
t_eq "save -k: the staged change stays staged" "shared.txt" "$(git diff --cached --name-only)"
git reset -q --hard HEAD

(cd "$HOME/notrepo" && run shell::git::stash::save -m x && exit "$RC")
t_eq "save: not a repository is 3" "3" "$?"
gt_init "$HOME/empty"
printf 'a\n' >f.txt
git add f.txt
run shell::git::stash::save -m "no commits yet"
t_eq "save: a repository without commits cannot stash (1)" "1" "$RC"
cd "$HOME/repo" || exit 1

# conflict blocks the save
git checkout -q -b cb
gt_commit "cb" shared.txt "cb side"
git checkout -q main
gt_commit "main side" shared.txt "main side"
git merge cb >/dev/null 2>&1
run shell::git::stash::save -m "during merge"
t_eq "save: files in conflict are 7" "7" "$RC"
git merge --abort
git reset -q --hard HEAD

# ---------------------------------------------------------------- pick
git stash clear
run shell::git::stash::pick
t_eq "pick: no stash at all is 1 (and no terminal needed to say so)" "1" "$RC"
t_has "pick: ...says no stashes" "no stashes" "$ERR"
printf 'one\n' >>shared.txt
git stash push -q -m "first named"
printf 'two\n' >>shared.txt
git stash push -q
git checkout -q -b side
printf 'three\n' >>shared.txt
git stash push -q -m "on side: ünï"
git checkout -q main
run shell::git::stash::pick -h
t_eq "pick -h: exit 0" "0" "$RC"
run shell::git::stash::pick 1
t_eq "pick N: normalized" "stash@{1}" "$OUT"
run shell::git::stash::pick 'stash@{2}'
t_eq "pick stash@{N}: accepted" "stash@{2}" "$OUT"
run shell::git::stash::pick 9
t_eq "pick: a missing stash is 1" "1" "$RC"
run shell::git::stash::pick HEAD
t_eq "pick: a revision is not a stash reference (2)" "2" "$RC"
run shell::git::stash::pick -- -1
t_eq "pick: -1 is not a stash reference (2)" "2" "$RC"
run shell::git::stash::pick 'stash@{x}'
t_eq "pick: stash@{x} is 2" "2" "$RC"
run shell::git::stash::pick --bogus
t_eq "pick: unknown option is 2" "2" "$RC"

gt_fake_fzf
OUT="$(FAKE_FZF_PICKS="first named" shell::git::stash::pick 2>/dev/null)"
t_eq "pick: interactive returns the reference" "stash@{2}" "$OUT"
plain="$(cat "$FAKE_FZF_DIR/plain.1")"
t_has "pick: source branch column" "side" "$plain"
t_has "pick: message column (named stash)" "on side: ünï" "$plain"
t_has "pick: message column (WIP stash)" "WIP" "$(grep 'stash@{1}' "$FAKE_FZF_DIR/plain.1" | head -n 1)$(git log -g -1 --format=%gs 'stash@{1}')"
t_has "pick: date column" "ago" "$plain"
t_eq "pick: newest first" "stash@{0}" "$(head -n 1 "$FAKE_FZF_DIR/stdin.1" | cut -d"$(printf '\037')" -f1)"
t_eq "pick: no ANSI under NO_COLOR / non-TTY" "0" "$(grep -c "$esc" "$FAKE_FZF_DIR/stdin.1")"
t_has "pick: lazy, bounded preview of the focused stash" "head -n 200" "$(cat "$FAKE_FZF_DIR/args.1")"
OUT="$(FAKE_FZF_PICKS="" shell::git::stash::pick 2>/dev/null)"
t_eq "pick: esc is 5" "5" "$?"
t_eq "pick: esc prints nothing" "" "$OUT"
OUT="$(SHELL_GIT_FORCE_FZF='' shell::git::stash::pick 2>/dev/null </dev/null)"
t_eq "pick: no terminal and no argument is 2" "2" "$?"
gt_input 3
OUT="$(SHELL_GIT_FORCE_FZF='' shell::git::stash::pick 2>"$HOME/err")"
t_eq "pick fallback: number 3 is the oldest" "stash@{2}" "$OUT"
_shell::git::core::input_close
unset SHELL_GIT_INPUT
(cd "$HOME/notrepo" && run shell::git::stash::pick && exit "$RC")
t_eq "pick: not a repository is 3" "3" "$?"
git clone -q --bare "$HOME/repo" "$HOME/bare.git" 2>/dev/null
(cd "$HOME/bare.git" && run shell::git::stash::pick && exit "$RC")
t_eq "pick: a bare repository has no working tree (3)" "3" "$?"

mk_stashes() { # <n>: a repository with n stashes, returns the git-call count of a pick
	gt_init "$HOME/many$1"
	gt_commit c shared.txt base
	local i=0
	while [ "$i" -lt "$1" ]; do
		printf '%s\n' "$i" >>shared.txt
		git stash push -q -m "stash $i"
		i=$((i + 1))
	done
	gt_fake_fzf
	gt_git_counter on
	FAKE_FZF_PICKS="@first" shell::git::stash::pick >/dev/null 2>&1
	printf '%s/%s\n' "$(gt_count)" "$(gt_count stash)"
	gt_git_counter off
}
c20="$(mk_stashes 20)"
c200="$(mk_stashes 200)"
t_eq "pick: same number of git calls for 20 and 200 stashes" "${c20%/*}" "${c200%/*}"
t_eq "pick: ONE stash list call whatever the number of stashes" "1/1" "${c20#*/}/${c200#*/}"
cd "$HOME/repo" || exit 1

# ---------------------------------------------------------------- apply
git stash clear
git checkout -q main
git reset -q --hard HEAD
printf 'applied line\n' >apply.txt
git add apply.txt
git stash push -q -m "to apply"
OUT="$(SHELL_GIT_FORCE_FZF='' shell::git::stash::apply 2>/dev/null </dev/null)"
t_eq "apply: no argument and no terminal is 2" "2" "$?"
run shell::git::stash::apply -h
t_eq "apply -h: exit 0" "0" "$RC"
snap="$(gt_snapshot)"
run shell::git::stash::apply -n 0
t_eq "apply -n: exit 0" "0" "$RC"
t_eq "apply -n: the exact command" "git stash apply stash@\\{0\\}" "$OUT"
t_eq "apply -n: executes nothing" "$snap" "$(gt_snapshot)"
run shell::git::stash::apply 0
t_eq "apply: exit 0" "0" "$RC"
t_eq "apply: stdout is the reference" "stash@{0}" "$OUT"
t_eq "apply: the change is back" "applied line" "$(cat apply.txt)"
t_eq "apply: the stash is kept" "1" "$(git stash list | wc -l | tr -d ' ')"
run shell::git::stash::apply 5
t_eq "apply: a missing stash is 1" "1" "$RC"
run shell::git::stash::apply HEAD
t_eq "apply: a revision is not a stash reference (2)" "2" "$RC"
git reset -q --hard HEAD
git clean -fdq
run shell::git::stash::apply --index 0
t_eq "apply --index: exit 0" "0" "$RC"
t_eq "apply --index: the staged state is restored" "apply.txt" "$(git diff --cached --name-only)"
git reset -q --hard HEAD
git clean -fdq
printf 'local content\n' >apply.txt
run shell::git::stash::apply 0
t_eq "apply: a local file that would be overwritten is 1" "1" "$RC"
t_eq "apply: ...the local content is intact" "local content" "$(cat apply.txt)"
t_eq "apply: ...the stash is still kept" "1" "$(git stash list | wc -l | tr -d ' ')"
git reset -q --hard HEAD
git clean -fdq

# interactive
gt_fake_fzf
OUT="$(FAKE_FZF_PICKS="to apply" shell::git::stash::apply 2>/dev/null)"
t_eq "apply: interactive pick" "stash@{0}" "$OUT"
git reset -q --hard HEAD
git clean -fdq
OUT="$(FAKE_FZF_PICKS="" shell::git::stash::apply 2>/dev/null)"
t_eq "apply: esc is 5" "5" "$?"
t_eq "apply: esc changes nothing" "0" "$(git status --porcelain | wc -l | tr -d ' ')"

# conflicts: exit 6, stash kept
git reset -q --hard HEAD
gt_commit "line v1" conflict.txt "v1"
printf 'stashed v2\n' >conflict.txt
git stash push -q -m "conflicting"
gt_commit "line v3" conflict.txt "v3"
run shell::git::stash::apply 0
t_eq "apply: conflicts are exit 6" "6" "$RC"
t_has "apply: the message says the stash is kept" "stash is kept" "$ERR"
t_eq "apply: the stash is still there" "1" "$(git stash list | grep -c conflicting)"
t_eq "apply: stdout is empty on conflict" "" "$OUT"
# an operation in progress blocks (merge conflict state)
run shell::git::stash::apply 0
t_eq "apply: with conflicts in the tree git refuses (1 or 6, never 0)" "1" "$([ "$RC" -ne 0 ] && echo 1 || echo 0)"
git reset -q --hard HEAD
git checkout -q -b mb
gt_commit "mb" shared.txt "mb side unique"
git checkout -q main
gt_commit "main" shared.txt "main side unique"
git merge mb >/dev/null 2>&1
run shell::git::stash::apply 0
t_eq "apply: a merge in progress is 7" "7" "$RC"
t_has "apply: ...says how to finish" "git merge --abort" "$ERR"
git merge --abort
git reset -q --hard HEAD
(cd "$HOME/notrepo" && run shell::git::stash::apply 0 && exit "$RC")
t_eq "apply: not a repository is 3" "3" "$?"

# ---------------------------------------------------------------- drop
git stash clear
for n in one two three; do
	printf '%s\n' "$n" >>shared.txt
	git stash push -q -m "drop $n"
done
h0="$(git rev-parse 'stash@{0}')"
h1="$(git rev-parse 'stash@{1}')"
snap="$(gt_snapshot)"
run shell::git::stash::drop 0
t_eq "drop: no terminal and no --yes is 2" "2" "$RC"
t_eq "drop: ...nothing dropped" "$snap" "$(gt_snapshot)"
run shell::git::stash::drop -h
t_eq "drop -h: exit 0" "0" "$RC"
run shell::git::stash::drop -n 0
t_eq "drop -n: the exact command" "git stash drop stash@\\{0\\}" "$OUT"
t_eq "drop -n: executes nothing" "$snap" "$(gt_snapshot)"
gt_input n
OUT="$(shell::git::stash::drop 0 2>"$HOME/err")"
t_eq "drop: declined is 5" "5" "$?"
_shell::git::core::input_close
t_eq "drop: declined leaves the repository identical" "$snap" "$(gt_snapshot)"
t_has "drop: the question names the stash" "drop three" "$(cat "$HOME/err")"
unset SHELL_GIT_INPUT
gt_input y
OUT="$(shell::git::stash::drop 0 2>"$HOME/err")"
t_eq "drop: confirmed is 0" "0" "$?"
_shell::git::core::input_close
unset SHELL_GIT_INPUT
t_eq "drop: prints the dropped hash on stdout" "$h0" "$OUT"
t_has "drop: tells how to bring it back" "git stash store" "$(cat "$HOME/err")"
t_eq "drop: the entry is gone and the next one moved up" "$h1" "$(git rev-parse 'stash@{0}')"
git stash store -m "restored" "$h0"
t_eq "drop: the printed hash restores the stash" "$h0" "$(git rev-parse 'stash@{0}')"
run shell::git::stash::drop --yes 1
t_eq "drop --yes: exit 0" "0" "$RC"
t_eq "drop --yes: stdout is the hash" "$h1" "$OUT"
run shell::git::stash::drop --yes 9
t_eq "drop: a missing stash is 1" "1" "$RC"
run shell::git::stash::drop --yes HEAD
t_eq "drop: a revision is not a stash reference (2)" "2" "$RC"
run shell::git::stash::drop --bogus
t_eq "drop: unknown option is 2" "2" "$RC"
gt_fake_fzf
gt_input y
OUT="$(FAKE_FZF_PICKS="drop one" shell::git::stash::drop 2>/dev/null)"
t_eq "drop: interactive pick and confirm" "0" "$?"
_shell::git::core::input_close
unset SHELL_GIT_INPUT
t_eq "drop: the picked entry is gone" "0" "$(git stash list | grep -c 'drop one')"
snap="$(gt_snapshot)"
OUT="$(FAKE_FZF_PICKS="" shell::git::stash::drop --yes 2>/dev/null)"
t_eq "drop: esc is 5" "5" "$?"
t_eq "drop: esc changes nothing" "$snap" "$(gt_snapshot)"
t_eq "drop: no ANSI in stdout" "0" "$(printf '%s' "$OUT" | grep -c "$esc")"
(cd "$HOME/notrepo" && run shell::git::stash::drop --yes 0 && exit "$RC")
t_eq "drop: not a repository is 3" "3" "$?"

t_done
