#!/usr/bin/env bash
# shell::git::log::{pick,search,file,graph,blame} on throwaway repositories (fake fzf, no network, no terminal).
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
t_setup
. "$SHELL_TEST_ROOT/test/support/git_toolkit.sh"
esc="$(printf '\033')"

# mkhist <n>: n commits on main in the current (new) repository, built with one fast-import run
mkhist() {
	local i=1
	{
		while [ "$i" -le "$1" ]; do
			printf 'commit refs/heads/main\ncommitter T <t@e> %d +0000\ndata 11\ncommit %04d\nM 100644 inline f.txt\ndata 5\n%04d\n' $((1600000000 + i)) "$i" "$i"
			i=$((i + 1))
		done
	} | git fast-import --quiet --force
	git reset -q --hard main 2>/dev/null
}

# custom_fzf <version> : a fzf that prints FAKE_KEY (when --expect is given) and then the record containing FAKE_WANT
custom_fzf() {
	mkdir -p "$HOME/gt-bin"
	cat >"$HOME/gt-bin/fzf" <<FAKE
#!/bin/sh
case "\$1" in --version) echo "$1 (fake)"; exit 0 ;; esac
printf '%s\n' "\$@" >"\$HOME/ff.args"
cat >"\$HOME/ff.in"
[ -n "\${FAKE_ESC-}" ] && exit 130
expect=""; for a in "\$@"; do [ "\$a" = "--expect" ] && expect=1; done
[ -n "\$expect" ] && printf '%s\n' "\${FAKE_KEY-}"
grep -F -- "\${FAKE_WANT-}" "\$HOME/ff.in" | head -n 1
exit 0
FAKE
	chmod +x "$HOME/gt-bin/fzf"
	_SHELL_GIT_VER_FZF=""
}

mkdir "$HOME/notrepo"
for fn in pick search file graph blame; do
	(cd "$HOME/notrepo" && shell::git::log::$fn -x >/dev/null 2>&1)
	t_eq "$fn: an option it does not know is 2 (even outside a repository)" "2" "$?"
done
(cd "$HOME/notrepo" && shell::git::log::graph >/dev/null 2>&1)
t_eq "graph: not a repository is 3" "3" "$?"
(cd "$HOME/notrepo" && shell::git::log::search --grep x >/dev/null 2>&1)
t_eq "search: not a repository is 3" "3" "$?"
(cd "$HOME/notrepo" && shell::git::log::file x >/dev/null 2>&1)
t_eq "file: not a repository is 3" "3" "$?"
(cd "$HOME/notrepo" && shell::git::log::blame x >/dev/null 2>&1)
t_eq "blame: not a repository is 3" "3" "$?"
(cd "$HOME/notrepo" && shell::git::log::pick >/dev/null 2>&1)
t_eq "pick: not a repository is 3" "3" "$?"
for fn in pick search file graph blame; do
	t_has "$fn: -h prints usage on stdout" "Usage: shell::git::log::$fn" "$(shell::git::log::$fn -h 2>/dev/null)"
	shell::git::log::$fn -h >/dev/null 2>&1
	t_eq "$fn: -h is 0" "0" "$?"
done

# --- empty repository
gt_init "$HOME/empty"
shell::git::log::graph >/dev/null 2>&1
t_eq "graph: empty repository is 1" "1" "$?"
shell::git::log::search --grep x >/dev/null 2>&1
t_eq "search: empty repository is 1" "1" "$?"
t_has "pick: empty repository says so" "no commits" "$(shell::git::log::pick 2>&1)"

# --- a small history
gt_init "$HOME/repo"
gt_commit "first alpha" "a.txt" "one
two
three"
gt_commit "second beta fix login" "b.txt" "bee"
gt_commit "third gamma" "a.txt" "one
TWO
three
four"
gt_commit "fourth delta --all" "c.txt" "see"
gt_commit "fifth epsilon" "b.txt" "bee2"
h1="$(git rev-parse HEAD~4)"
h3="$(git rev-parse HEAD~2)"
h5="$(git rev-parse HEAD)"

# graph
out="$(shell::git::log::graph 2>/dev/null)"
t_eq "graph: one line per commit (5)" "5" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
t_has "graph: shows a subject" "third gamma" "$out"
t_lacks "graph: no ANSI when not a terminal" "$esc" "$out"
t_eq "graph -m 2: bounded" "2" "$(shell::git::log::graph -m 2 2>/dev/null | wc -l | tr -d ' ')"
shell::git::log::graph -m 0 >/dev/null 2>&1
t_eq "graph: --max 0 is 2" "2" "$?"
shell::git::log::graph -rf >/dev/null 2>&1
t_eq "graph: -rf is an unknown option (2), never a git option" "2" "$?"
shell::git::log::graph nope >/dev/null 2>&1
t_eq "graph: unknown revision is 2" "2" "$?"
t_has "graph: a revision argument" "first alpha" "$(shell::git::log::graph "$h1" 2>/dev/null)"
t_eq "graph: stderr is empty on success" "" "$(shell::git::log::graph 2>&1 >/dev/null)"
git checkout -q -b side "$h3"
gt_commit "side only" "s.txt" "s"
git checkout -q main
t_lacks "graph: HEAD only hides other branches" "side only" "$(shell::git::log::graph 2>/dev/null)"
t_has "graph --all shows them" "side only" "$(shell::git::log::graph --all 2>/dev/null)"
t_has "graph: decorations" "main" "$(shell::git::log::graph 2>/dev/null)"

# search
t_has "search: bare text is --grep" "second beta" "$(shell::git::log::search "fix login" 2>/dev/null)"
t_has "search --grep" "third gamma" "$(shell::git::log::search --grep gamma 2>/dev/null)"
t_eq "search --grep: one match, one line" "1" "$(shell::git::log::search --grep gamma 2>/dev/null | wc -l | tr -d ' ')"
t_has "search -S finds the commit that adds a string" "fourth delta" "$(shell::git::log::search -S see 2>/dev/null)"
t_has "search -G finds a diff matching a regex" "third gamma" "$(shell::git::log::search -G 'TW.' 2>/dev/null)"
t_has "search -i" "third gamma" "$(shell::git::log::search --grep GAMMA -i 2>/dev/null)"
shell::git::log::search --grep GAMMA >/dev/null 2>&1
t_eq "search: case sensitive by default (no match is 1)" "1" "$?"
t_has "search: option-like text is data (--grep --all)" "fourth delta" "$(shell::git::log::search --grep -- --all 2>/dev/null || shell::git::log::search --grep '--all' 2>/dev/null)"
shell::git::log::search -S -rf >/dev/null 2>&1
t_eq "search: -S -rf is searched, not run (no match is 1)" "1" "$?"
shell::git::log::search -rf >/dev/null 2>&1
t_eq "search: a bare -rf is refused with 2" "2" "$?"
t_has "search: ...and the message shows how to search for it" "--grep '-rf'" "$(shell::git::log::search -rf 2>&1)"
shell::git::log::search >/dev/null 2>&1
t_eq "search: nothing to search is 2" "2" "$?"
shell::git::log::search --grep >/dev/null 2>&1
t_eq "search: --grep without a value is 2" "2" "$?"
t_eq "search: only commits touching the path" "1" "$(shell::git::log::search --grep e -- c.txt 2>/dev/null | wc -l | tr -d ' ')"
t_eq "search: a miss prints nothing on stdout" "" "$(shell::git::log::search --grep zzzz 2>/dev/null)"
t_lacks "search: no ANSI when not a terminal" "$esc" "$(shell::git::log::search --grep e 2>/dev/null)"
t_has "search --all reaches other branches" "side only" "$(shell::git::log::search --grep side --all 2>/dev/null)"
t_eq "search -m 1: bounded" "1" "$(shell::git::log::search --grep e -m 1 2>/dev/null | wc -l | tr -d ' ')"

# file
out="$(shell::git::log::file a.txt 2>/dev/null)"
t_eq "file: two commits touched a.txt" "2" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
t_has "file: names the commit" "first alpha" "$out"
shell::git::log::file nofile.txt >/dev/null 2>&1
t_eq "file: no history is 1" "1" "$?"
shell::git::log::file a.txt b.txt >/dev/null 2>&1
t_eq "file: two paths is 2" "2" "$?"
shell::git::log::file -rf >/dev/null 2>&1
t_eq "file: -rf is an unknown option (2)" "2" "$?"
t_has "file --patch shows the diff" "+TWO" "$(shell::git::log::file --patch a.txt 2>/dev/null)"
git mv a.txt renamed.txt
git commit -q -m "rename a"
t_eq "file: follows the rename" "3" "$(shell::git::log::file renamed.txt 2>/dev/null | wc -l | tr -d ' ')"
git rm -q b.txt
git commit -q -m "delete b"
t_has "file: a deleted file still has history" "second beta" "$(shell::git::log::file b.txt 2>/dev/null)"
# odd names
n=0
for odd in "with space.txt" "unicodé-日本.txt" "-leading-dash.txt" "it's \"q\".txt" "glob[*]?.txt"; do
	n=$((n + 1))
	gt_commit "odd $n" "$odd" "x$n"
	t_has "file: odd name works: $odd" "odd $n" "$(shell::git::log::file -- "$odd" 2>/dev/null)"
done
t_has "file: a plain leading-dash name is refused with a hint" "after --" "$(shell::git::log::file -leading-dash.txt 2>&1)"
t_eq "file: no ANSI when not a terminal" "" "$(shell::git::log::file renamed.txt 2>&1 | grep -c "$esc" | sed 's/^0$//')"
# interactive file pick (fake fzf over NUL records)
gt_fake_fzf
out="$(FAKE_FZF_PICKS="with space.txt" shell::git::log::file 2>/dev/null)"
t_has "file: picks a file with fzf when no argument is given" "odd 1" "$out"
t_has "file: the picker was fed NUL-separated records" "--read0" "$(cat "$FAKE_FZF_DIR/args.1")"
FAKE_FZF_PICKS="" shell::git::log::file >/dev/null 2>&1
t_eq "file: esc in the file picker is 5" "5" "$?"
(
	unset SHELL_GIT_FORCE_FZF
	shell::git::log::file </dev/null >/dev/null 2>&1
	echo $? >"$HOME/rc.out"
)
t_eq "file: no argument and no terminal is 2" "2" "$(cat "$HOME/rc.out")"

# blame
gt_init "$HOME/brepo"
gt_commit "b1" "t.txt" "l1
l2
l3
l4"
printf 'l1\nL2\nl3\nl4\nl5\n' >t.txt
git commit -q -a -m "b2 change l2"
out="$(shell::git::log::blame t.txt 2>/dev/null)"
t_eq "blame: one line per line" "5" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
t_eq "blame -L 2,3" "2" "$(shell::git::log::blame t.txt -L 2,3 2>/dev/null | wc -l | tr -d ' ')"
t_eq "blame -L 2,+1" "1" "$(shell::git::log::blame -L 2,+1 t.txt 2>/dev/null | wc -l | tr -d ' ')"
t_eq "blame -L2,3 (attached)" "2" "$(shell::git::log::blame -L2,3 t.txt 2>/dev/null | wc -l | tr -d ' ')"
shell::git::log::blame -L abc t.txt >/dev/null 2>&1
t_eq "blame: invalid range is 2" "2" "$?"
shell::git::log::blame -L '1,2;touch x' t.txt >/dev/null 2>&1
t_eq "blame: a range with shell syntax is 2" "2" "$?"
t_eq "blame: nothing executed from the range" "no" "$([ -e x ] && echo yes || echo no)"
printf 'u\n' >untracked.txt
t_has "blame: an untracked file is refused clearly" "not a tracked file" "$(shell::git::log::blame untracked.txt 2>&1)"
shell::git::log::blame untracked.txt >/dev/null 2>&1
t_eq "blame: untracked is 1" "1" "$?"
shell::git::log::blame missing.txt >/dev/null 2>&1
t_eq "blame: missing is 1" "1" "$?"
printf 'a\0b\0c\n' >bin.dat
git add bin.dat
git commit -q -m "binary"
t_has "blame: a binary file is refused clearly" "binary file" "$(shell::git::log::blame bin.dat 2>&1)"
shell::git::log::blame bin.dat >/dev/null 2>&1
t_eq "blame: binary is 1" "1" "$?"
SHELL_GIT_BLAME_MAX_LINES=3 shell::git::log::blame t.txt >/dev/null 2>&1
t_eq "blame: a file over the limit needs -L (2)" "2" "$?"
t_has "blame: ...and says so" "pass -L" "$(SHELL_GIT_BLAME_MAX_LINES=3 shell::git::log::blame t.txt 2>&1)"
t_eq "blame: a range is allowed on a huge file" "2" "$(SHELL_GIT_BLAME_MAX_LINES=3 shell::git::log::blame t.txt -L 1,2 2>/dev/null | wc -l | tr -d ' ')"
t_has "blame --rev: as of an older revision" "l2" "$(shell::git::log::blame --rev "$(git rev-parse HEAD~2)" t.txt 2>/dev/null | sed -n 2p)"
gt_commit "dash" "-dash.txt" "d"
t_eq "blame: a file with a leading dash after --" "1" "$(shell::git::log::blame -- -dash.txt 2>/dev/null | wc -l | tr -d ' ')"
t_has "blame: a plain leading dash is refused with a hint" "after --" "$(shell::git::log::blame -dash.txt 2>&1)"
out="$(FAKE_FZF_PICKS="L2" shell::git::log::blame --pick t.txt 2>/dev/null)"
t_has "blame --pick: shows the commit of the chosen line" "b2 change l2" "$out"
FAKE_FZF_PICKS="" shell::git::log::blame --pick t.txt >/dev/null 2>&1
t_eq "blame --pick: esc is 5" "5" "$?"
out="$(FAKE_FZF_PICKS="t.txt" shell::git::log::blame 2>/dev/null)"
t_eq "blame: picks the file when none is given" "5" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"

# --- pick
gt_init "$HOME/prepo"
gt_commit "c1 alpha" "f1" "1"
gt_commit "c2 beta" "f2" "2"
gt_commit "c3 gamma" "f3" "3"
gt_commit "c4 delta" "f4" "4"
gt_commit "c5 eps" "f5" "5"
gt_fake_fzf
want="$(git rev-parse HEAD~2)"
out="$(FAKE_FZF_PICKS="c3 gamma" shell::git::log::pick 2>/dev/null)"
t_eq "pick: prints the full hash of the picked commit" "$want" "$out"
t_has "pick: details of the commit go to stderr" "c3 gamma" "$(FAKE_FZF_PICKS="c3 gamma" shell::git::log::pick 2>&1 >/dev/null)"
t_eq "pick: details stay off stdout" "$want" "$(FAKE_FZF_PICKS="c3 gamma" shell::git::log::pick 2>/dev/null)"
args="$(cat "$FAKE_FZF_DIR/args.1")"
for k in "--with-nth=2.." "--ansi" "--expect" "alt-p,alt-r" "alt-d:execute" "alt-f:execute" "alt-i:execute" "?:preview" "alt-m:reload" "ctrl-/:toggle-preview" "esc:abort"; do
	t_has "pick: fzf got $k" "$k" "$args"
done
t_lacks "pick: ctrl-c is never bound" "ctrl-c:" "$args"
t_lacks "pick: ctrl-s is never bound" "ctrl-s:" "$args"
t_lacks "pick: ctrl-d is never bound (it quits fzf on an empty query)" "ctrl-d:" "$args"
t_has "pick: the header lists the keys" "alt-p cherry-pick" "$args"
t_has "pick: the first column is the hidden hash" "$(printf '\037')" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "pick: the stream starts with the full hash" "$(git rev-parse HEAD)" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_eq "pick: 5 records streamed" "5" "$(wc -l <"$FAKE_FZF_DIR/stdin.1" | tr -d ' ')"
t_lacks "pick: no ANSI codes reach fzf under NO_COLOR" "$esc" "$(cat "$FAKE_FZF_DIR/stdin.1")"
FAKE_FZF_PICKS="" shell::git::log::pick >/dev/null 2>&1
t_eq "pick: esc is 5" "5" "$?"
t_eq "pick: esc prints nothing" "" "$(FAKE_FZF_PICKS="" shell::git::log::pick 2>/dev/null)"
out="$(FAKE_FZF_PICKS="@all" shell::git::log::pick --multi 2>/dev/null)"
t_eq "pick --multi: every picked hash" "5" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
t_has "pick --multi: --multi reaches fzf" "--multi" "$(tail -n +1 "$FAKE_FZF_DIR/args.$(cat "$FAKE_FZF_DIR/count")")"
out="$(FAKE_FZF_PICKS="c1" shell::git::log::pick -m 2 2>/dev/null)"
t_eq "pick -m 2: only two commits are streamed (c1 is not among them)" "" "$out"
t_eq "pick -m 2: stream length" "2" "$(wc -l <"$FAKE_FZF_DIR/stdin.$(cat "$FAKE_FZF_DIR/count")" | tr -d ' ')"
shell::git::log::pick -m x >/dev/null 2>&1
t_eq "pick: bad --max is 2" "2" "$?"
shell::git::log::pick --rev nope >/dev/null 2>&1
t_eq "pick: unknown revision is 2" "2" "$?"
shell::git::log::pick --rev -rf >/dev/null 2>&1
t_eq "pick: --rev -rf never reaches git (2)" "2" "$?"
FAKE_FZF_PICKS="@first" shell::git::log::pick -- -rf >/dev/null 2>&1
t_eq "pick: a path filter named -rf after -- is only a pathspec (empty list is 5)" "5" "$?"
out="$(FAKE_FZF_PICKS="@first" shell::git::log::pick -- f2 2>/dev/null)"
t_eq "pick: a path filter limits the stream" "$(git rev-parse HEAD~3)" "$out"
t_lacks "pick: no reload binding when paths filter the stream" "alt-m:reload" "$(cat "$FAKE_FZF_DIR/args.$(cat "$FAKE_FZF_DIR/count")")"
git checkout -q --detach HEAD~1
out="$(FAKE_FZF_PICKS="c2 beta" shell::git::log::pick 2>/dev/null)"
t_eq "pick: works on a detached HEAD" "$(git rev-parse HEAD~2)" "$out"
git checkout -q main
(
	unset SHELL_GIT_FORCE_FZF
	shell::git::log::pick </dev/null >/dev/null 2>&1
	echo $? >"$HOME/rc.out"
)
t_eq "pick: no terminal is 2" "2" "$(cat "$HOME/rc.out")"
# fzf older than 0.38: enter and the preview only
custom_fzf 0.30.0
out="$(FAKE_WANT="c4 delta" shell::git::log::pick 2>"$HOME/err.out")"
t_eq "pick (old fzf): still picks" "$(git rev-parse HEAD~1)" "$out"
t_lacks "pick (old fzf): no --expect" "--expect" "$(cat "$HOME/ff.args")"
t_lacks "pick (old fzf): no execute bindings" "execute" "$(cat "$HOME/ff.args")"
t_has "pick (old fzf): says what is missing" "older than 0.38" "$(cat "$HOME/err.out")"
# numbered fallback (no fzf at all, answers scripted)
oldpath="$PATH"
rm -f "$HOME/gt-bin/fzf"
_SHELL_GIT_VER_FZF=0
saved_force="$SHELL_GIT_FORCE_FZF"
unset SHELL_GIT_FORCE_FZF
gt_input 2
out="$(shell::git::log::pick 2>"$HOME/err.out")"
t_eq "pick (numbered): 2 is the second most recent commit" "$(git rev-parse HEAD~1)" "$out"
_shell::git::core::input_close
t_has "pick (numbered): lists the commits on stderr" "c5 eps" "$(cat "$HOME/err.out")"
SHELL_GIT_LOG_FALLBACK=3 shell::git::log::pick 2>"$HOME/err.out" >/dev/null <<<""
gt_input 1
SHELL_GIT_LOG_FALLBACK=3 shell::git::log::pick 2>"$HOME/err.out" >/dev/null
t_eq "pick (numbered): bounded by SHELL_GIT_LOG_FALLBACK" "3" "$(grep -c ') ' "$HOME/err.out")"
_shell::git::core::input_close
gt_input ""
shell::git::log::pick >/dev/null 2>&1
t_eq "pick (numbered): empty answer is 5" "5" "$?"
_shell::git::core::input_close
unset SHELL_GIT_INPUT
_SHELL_GIT_INPUT_OPEN=""
PATH="$oldpath"
SHELL_GIT_FORCE_FZF="$saved_force"
gt_fake_fzf

# alt-p / alt-r through the key the picker returns
git checkout -q -b feature HEAD~1
gt_commit "feature work" "ff.txt" "feat"
fh="$(git rev-parse HEAD)"
git checkout -q main
custom_fzf 0.64.0
snap="$(gt_snapshot)"
FAKE_KEY=alt-p FAKE_WANT="feature work" shell::git::log::pick -a -n >"$HOME/out.txt" 2>/dev/null
t_eq "pick alt-p -n: rc 0" "0" "$?"
t_eq "pick alt-p -n: prints the exact command" "git cherry-pick $fh" "$(cat "$HOME/out.txt")"
t_eq "pick alt-p -n: nothing changed" "$snap" "$(gt_snapshot)"
gt_input n
FAKE_KEY=alt-p FAKE_WANT="feature work" shell::git::log::pick -a >/dev/null 2>&1
t_eq "pick alt-p: declined is 5" "5" "$?"
_shell::git::core::input_close
t_eq "pick alt-p: declined leaves the repository identical" "$snap" "$(gt_snapshot)"
FAKE_KEY=alt-p FAKE_WANT="feature work" shell::git::log::pick -a </dev/null >/dev/null 2>&1
unset SHELL_GIT_INPUT
t_eq "pick alt-p: no terminal and no --yes is 2" "2" "$(
	FAKE_KEY=alt-p FAKE_WANT="feature work" shell::git::log::pick -a </dev/null >/dev/null 2>&1
	echo $?
)"
t_eq "pick alt-p: nothing changed by the refusal" "$snap" "$(gt_snapshot)"
printf 'dirty\n' >>f1
FAKE_KEY=alt-p FAKE_WANT="feature work" shell::git::log::pick -a -y >/dev/null 2>&1
t_eq "pick alt-p: a dirty tree blocks with 7" "7" "$?"
git checkout -q -- f1
out="$(FAKE_KEY=alt-p FAKE_WANT="feature work" shell::git::log::pick -a -y 2>/dev/null)"
t_eq "pick alt-p -y: cherry-picked, new HEAD on stdout" "$(git rev-parse HEAD)" "$out"
t_eq "pick alt-p -y: the file arrived" "feat" "$(cat ff.txt)"
mh="$(git rev-parse HEAD)"
FAKE_KEY=alt-r FAKE_WANT="feature work" shell::git::log::pick -a -y >/dev/null 2>&1
t_eq "pick alt-r -y: reverted" "0" "$?"
t_eq "pick alt-r -y: the file is gone again" "no" "$([ -e ff.txt ] && echo yes || echo no)"
t_eq "pick alt-r -y: a new commit was made" "1" "$(git rev-list --count "$mh..HEAD")"
# conflict -> 6
git checkout -q -b conf1 main
gt_commit "conf one" "clash.txt" "one"
c1="$(git rev-parse HEAD)"
git checkout -q main
gt_commit "main clash" "clash.txt" "main"
FAKE_KEY=alt-p FAKE_WANT="conf one" shell::git::log::pick -a -y >/dev/null 2>"$HOME/err.out"
t_eq "pick alt-p: a conflict is 6" "6" "$?"
t_has "pick alt-p: says how to continue" "git cherry-pick --continue" "$(cat "$HOME/err.out")"
t_has "pick alt-p: says how to abort" "git cherry-pick --abort" "$(cat "$HOME/err.out")"
FAKE_KEY=alt-p FAKE_WANT="feature work" shell::git::log::pick -a -y >/dev/null 2>&1
t_eq "pick alt-p: an operation in progress blocks with 7" "7" "$?"
git cherry-pick --abort
# merge commit refused
git checkout -q -b mergeside main
gt_commit "ms" "ms.txt" "ms"
git checkout -q main
git merge -q --no-ff -m "merge ms" mergeside
FAKE_KEY=alt-r FAKE_WANT="merge ms" shell::git::log::pick -a -y >/dev/null 2>"$HOME/err.out"
t_eq "pick alt-r: a merge commit is refused (2)" "2" "$?"
t_has "pick alt-r: ...and why" "merge commit" "$(cat "$HOME/err.out")"
# Enter through the custom fzf (empty key line)
out="$(FAKE_KEY="" FAKE_WANT="main clash" shell::git::log::pick -a 2>/dev/null)"
t_eq "pick: enter (empty key) returns the hash" "$(git log -1 --format=%H --grep='main clash')" "$out"
FAKE_ESC=1 shell::git::log::pick >/dev/null 2>&1
t_eq "pick: fzf 130 is 5" "5" "$?"

# --- bare repository and linked worktree
git clone -q --bare "$HOME/prepo" "$HOME/bare.git"
(cd "$HOME/bare.git" && shell::git::log::graph -m 1 >/dev/null 2>&1)
t_eq "graph: works in a bare repository" "0" "$?"
(cd "$HOME/bare.git" && shell::git::log::file x >/dev/null 2>&1)
t_eq "file: needs a working tree (3)" "3" "$?"
git worktree add -q "$HOME/wt" -b wtbranch >/dev/null 2>&1
t_has "graph: works in a linked worktree" "c5 eps" "$(cd "$HOME/wt" && shell::git::log::graph 2>/dev/null)"

# --- constant git-call counts: independent of the number of commits
count_for() { # <n> <function words...>
	local n="$1" d="$HOME/perf$1"
	shift
	rm -rf "$d"
	gt_init "$d" >/dev/null
	mkhist "$n"
	gt_git_counter on
	"$@" >/dev/null 2>&1
	gt_count
	gt_git_counter off
}
a="$(count_for 20 shell::git::log::graph)"
b="$(count_for 2000 shell::git::log::graph)"
t_eq "graph: the same number of git calls for 20 and 2000 commits ($a)" "$a" "$b"
a="$(count_for 20 shell::git::log::search --grep commit)"
b="$(count_for 2000 shell::git::log::search --grep commit)"
t_eq "search: the same number of git calls for 20 and 2000 commits ($a)" "$a" "$b"
a="$(count_for 20 shell::git::log::file f.txt)"
b="$(count_for 2000 shell::git::log::file f.txt)"
t_eq "file: the same number of git calls for 20 and 2000 commits ($a)" "$a" "$b"
gt_fake_fzf
export FAKE_FZF_PICKS="@first"
a="$(count_for 20 shell::git::log::pick)"
b="$(count_for 2000 shell::git::log::pick)"
t_eq "pick: the same number of git calls for 20 and 2000 commits ($a)" "$a" "$b"
d="$HOME/perf2000"
cd "$d" || exit 1
gt_git_counter on
shell::git::log::pick >/dev/null 2>&1
t_eq "pick: exactly one git log for the whole stream" "1" "$(gt_count log)"
gt_git_counter off
t_eq "pick: the stream is bounded by --max-count (2000 default)" "2000" "$(wc -l <"$FAKE_FZF_DIR/stdin.$(cat "$FAKE_FZF_DIR/count")" | tr -d ' ')"
unset FAKE_FZF_PICKS

t_done
