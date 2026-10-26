#!/usr/bin/env bash
# shell::git::commit::spec and ::spec::current in a real repository with known authors, dates,
# a merge commit and paths. Covers every option, the default output (unchanged), the dry-run
# command (must be pasteable), validation, and that nothing a user types is ever executed.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

export GIT_CONFIG_NOSYSTEM=1
git config --global user.email "t@example.com"
git config --global user.name "Test"

# mkc <subject> <author> <date> <file> : add a commit touching <file>
mkc() {
	mkdir -p "$(dirname "$4")"
	printf '%s\n' "$1" >>"$4"
	git add -- "$4"
	GIT_AUTHOR_NAME="$2" GIT_AUTHOR_EMAIL="$2@example.com" GIT_AUTHOR_DATE="$3T12:00:00" \
		GIT_COMMITTER_NAME="$2" GIT_COMMITTER_EMAIL="$2@example.com" GIT_COMMITTER_DATE="$3T12:00:00" \
		git commit -q -m "$1"
}
cd "$HOME" && rm -rf "$HOME/repo" && mkdir "$HOME/repo" && cd "$HOME/repo" || exit 1
git init -q && git checkout -q -b main
mkc "feat: alpha" Alice 2024-01-10 a.txt
mkc "fix: beta" Bob 2024-02-10 b.txt
mkc "docs: gamma" Alice 2024-03-10 docs/g.md
mkc "feat: delta" Bob 2024-04-10 src/d.c
git checkout -q -b side
mkc "feat: side work" Carol 2024-04-20 side.txt
git checkout -q main
GIT_AUTHOR_NAME=Dave GIT_AUTHOR_EMAIL=dave@example.com GIT_AUTHOR_DATE="2024-04-25T12:00:00" \
	GIT_COMMITTER_NAME=Dave GIT_COMMITTER_EMAIL=dave@example.com GIT_COMMITTER_DATE="2024-04-25T12:00:00" \
	git merge -q --no-ff side -m "Merge branch side" >/dev/null 2>&1
mkc "fix: epsilon" Alice 2024-05-10 "my file.txt"
# main: alpha beta gamma delta, side work, merge, epsilon  (7 commits, 6 on the first-parent line)

spec() {
	shell::git::commit::spec "$@" 2>&1
	echo "RC=$?"
}
# only what git printed: drop the echoed command, the status line and RC
body() { grep -v -e '^  ▶ ' -e '^\[ok\]' -e '^\[error\]' -e '^RC='; }
ncommits() { grep -c ' - (' || true; }
FMT='%C(bold blue)%H (%h)%C(reset) - %C(bold green)(%ar at %ad)%C(reset) %C(white)%an%C(reset)%C(bold yellow)%d%C(reset) %C(dim white)- %s%C(reset)'

# --- default output is unchanged ------------------------------------------------------------------
out="$(spec main)"
expected="$(git log --graph --decorate --date=format:'%Y-%m-%d %H:%M:%S' --format=tformat:"$FMT" main)"
t_eq "default: same commits as the original command" "$expected" "$(printf '%s\n' "$out" | body)"
t_has "default: exit 0" "RC=0" "$out"
t_has "default: success line" "Commit history for branch 'main' displayed" "$out"
t_eq "default: all 7 commits" "7" "$(printf '%s\n' "$out" | body | ncommits)"
t_has "default: the graph is there" "* " "$(printf '%s\n' "$out" | body | head -n 1)"
t_has "default: the status line is on its own line" "$(printf '\n[ok]')" "$out"

# --- --count ------------------------------------------------------------------------------------------
t_eq "-c 2" "2" "$(spec main -c 2 | body | ncommits)"
t_eq "--count 3" "3" "$(spec main --count 3 | body | ncommits)"
t_eq "--count=1" "1" "$(spec main --count=1 | body | ncommits)"
t_eq "-c larger than the history" "7" "$(spec main -c 100 | body | ncommits)"
t_has "-c shows the newest commits" "fix: epsilon" "$(spec main -c 1)"
t_lacks "-c hides the older ones" "feat: alpha" "$(spec main -c 1)"
t_eq "option before the branch" "2" "$(spec -c 2 main | body | ncommits)"

# --- dates ----------------------------------------------------------------------------------------------
t_eq "--since" "4" "$(spec main --since 2024-03-20 | body | ncommits)"
t_eq "-s" "4" "$(spec main -s 2024-03-20 | body | ncommits)"
t_eq "--until" "3" "$(spec main --until 2024-03-20 | body | ncommits)"
t_eq "-u" "3" "$(spec main -u 2024-03-20 | body | ncommits)"
t_eq "--since and --until together (a window)" "2" "$(spec main -s 2024-02-01 -u 2024-04-01 | body | ncommits)"
t_eq "--since=value form" "4" "$(spec main --since=2024-03-20 | body | ncommits)"
t_eq "--since with a relative date" "7" "$(spec main --since '10 years ago' | body | ncommits)"

# --- author / message ---------------------------------------------------------------------------------------
t_eq "--author Alice" "3" "$(spec main --author Alice | body | ncommits)"
t_eq "-a Bob" "2" "$(spec main -a Bob | body | ncommits)"
t_eq "--author=Carol" "1" "$(spec main --author=Carol | body | ncommits)"
t_eq "--author with no match" "0" "$(spec main -a Nobody | body | ncommits)"
t_eq "--grep feat" "3" "$(spec main --grep feat | body | ncommits)"
t_eq "-g fix" "2" "$(spec main -g fix | body | ncommits)"
t_eq "--grep and --author combine (AND)" "1" "$(spec main --grep feat --author Alice | body | ncommits)"
t_eq "--grep and --count combine" "1" "$(spec main --grep feat -c 1 | body | ncommits)"

# --- merges ------------------------------------------------------------------------------------------------------
t_eq "--no-merges hides the merge commit" "6" "$(spec main --no-merges | body | ncommits)"
t_lacks "--no-merges: no merge subject" "Merge branch side" "$(spec main --no-merges)"
t_eq "--first-parent hides the side branch" "6" "$(spec main --first-parent | body | ncommits)"
t_lacks "--first-parent: no side commit" "feat: side work" "$(spec main --first-parent)"
t_eq "--no-merges --first-parent" "5" "$(spec main --no-merges --first-parent | body | ncommits)"

# --- shape ----------------------------------------------------------------------------------------------------------
out="$(spec main --no-graph)"
t_eq "--no-graph: no graph characters" "0" "$(printf '%s\n' "$out" | body | grep -c '^\*' || true)"
t_eq "--no-graph: still 7 commits" "7" "$(printf '%s\n' "$out" | body | ncommits)"
out="$(spec main --oneline)"
t_eq "--oneline: no 40-character hash" "0" "$(printf '%s\n' "$out" | body | grep -Ec '[0-9a-f]{40}' || true)"
t_eq "--oneline: all commits" "7" "$(printf '%s\n' "$out" | body | ncommits)"
out="$(spec main --no-graph --reverse)"
t_has "--reverse: oldest first" "feat: alpha" "$(printf '%s\n' "$out" | body | head -n 1)"
t_has "--reverse: newest last" "fix: epsilon" "$(printf '%s\n' "$out" | body | tail -n 1)"
out="$(spec main --reverse)"
t_has "--reverse needs --no-graph" "RC=2" "$out"
t_has "--reverse error explains" "add --no-graph" "$out"
out="$(spec main -c 1 --stat)"
t_has "--stat shows the changed file" "my file.txt" "$out"
t_has "--stat shows the summary" "changed" "$out"

# --- paths ------------------------------------------------------------------------------------------------------------------
t_eq "-- docs" "1" "$(spec main -- docs | body | ncommits)"
t_has "-- docs: the right commit" "docs: gamma" "$(spec main -- docs)"
t_eq "-- two paths" "2" "$(spec main -- src docs | body | ncommits)"
t_eq "-- a path with a space" "1" "$(spec main -- 'my file.txt' | body | ncommits)"
t_eq "-- a path that matches nothing" "0" "$(spec main -- nothing-here | body | ncommits)"
t_has "-- a path that matches nothing: still exit 0" "RC=0" "$(spec main -- nothing-here)"
t_eq "paths combine with options" "1" "$(spec main --author Alice -c 1 -- docs | body | ncommits)"
t_eq "everything at once" "1" "$(spec main -c 5 -s 2024-01-01 -u 2024-12-31 -a Alice -g docs --no-merges --first-parent --no-graph --oneline -- docs | body | ncommits)"

# --- other branches ---------------------------------------------------------------------------------------------------------
t_eq "another branch" "5" "$(spec side | body | ncommits)"
out="$(spec nope-branch)"
t_has "unknown branch: git log failed" "Git log aborted" "$out"
t_has "unknown branch: exit non-zero" "RC=128" "$out"

# --- dry-run -------------------------------------------------------------------------------------------------------------------
out="$(spec -n main -c 3 --author "Al ice" --grep "it's" -- 'my file.txt')"
t_has "dry-run: exit 0" "RC=0" "$out"
t_has "dry-run: prints a git log command" "git log --graph --decorate" "$out"
t_has "dry-run: the author is one quoted word" "'--author=Al ice'" "$out"
t_has "dry-run: a single quote is escaped" "--grep=it'\\''s" "$out"
t_has "dry-run: the path is one quoted word" "'my file.txt'" "$out"
t_eq "dry-run: nothing is run" "0" "$(printf '%s\n' "$out" | body | ncommits)"
t_lacks "dry-run: no status line" "[ok]" "$out"

# the printed command, pasted into a shell, gives the same history as running it
out="$(spec -n main -c 3 --author Alice --no-merges -- docs src 'my file.txt')"
cmd="$(printf '%s\n' "$out" | grep '^  ▶ ' | head -n 1)"
cmd="${cmd#  ▶ }"
pasted="$(sh -c "$cmd" 2>&1)"
direct="$(spec main -c 3 --author Alice --no-merges -- docs src 'my file.txt' | body)"
t_eq "dry-run: the printed command is pasteable and equivalent" "$direct" "$pasted"
t_eq "dry-run: ...and not empty" "1" "$([ -n "$pasted" ] && echo 1 || echo 0)"

# --- validation ------------------------------------------------------------------------------------------------------------------------
for bad in "-c 0" "-c abc" "-c -3" "-c 05" "-c 1.5" "-c" "-s" "-u" "-a" "-g" "--since=" "--author=" "--bogus" "-x"; do
	# shellcheck disable=SC2086
	out="$(spec main $bad)"
	t_has "invalid usage [$bad]" "RC=2" "$out"
done
out="$(spec main -a "")"
t_has "empty --author value" "non-empty" "$out"
out="$(spec)"
t_has "no branch" "Branch name is required" "$out"
t_has "no branch: exit 2" "RC=2" "$out"
out="$(spec -- docs)"
t_has "only paths, no branch" "RC=2" "$out"
out="$(spec main side)"
t_has "a second branch is rejected" "Unexpected argument 'side'" "$out"
t_has "a second branch: exit 2" "RC=2" "$out"
out="$(spec -c 2)"
t_has "options but no branch" "RC=2" "$out"
t_rc "help" 0 shell::git::commit::spec -h
t_has "help lists --count" "--count" "$T_OUT"
t_has "help explains -n vs -c" "-n is the dry-run flag" "$T_OUT"
t_rc "help after the branch" 0 shell::git::commit::spec main --help

# --- nothing a user types is executed ----------------------------------------------------------------------------------------------
pwned="$HOME/pwned"
evil='evil$(touch${IFS}'"$pwned"')x'
git branch "$evil"
out="$(spec "$evil")"
t_has "hostile branch name: log works" "RC=0" "$out"
t_rc "hostile branch name: NOT executed" 1 test -e "$pwned"
git checkout -q "$evil"
out="$(shell::git::commit::spec::current -c 1 2>&1)"
t_has "hostile branch checked out: spec::current works" "fix: epsilon" "$out"
t_has "hostile branch checked out: the name is shown as plain text" "$evil" "$out"
t_rc "hostile branch checked out: NOT executed" 1 test -e "$pwned"
git checkout -q main
spec main -a '$(touch '"$pwned"')' >/dev/null
t_rc "hostile --author: NOT executed" 1 test -e "$pwned"
spec main -g '`touch '"$pwned"'`' >/dev/null
t_rc "hostile --grep (backticks): NOT executed" 1 test -e "$pwned"
spec main -s '$(touch '"$pwned"')' >/dev/null
t_rc "hostile --since: NOT executed" 1 test -e "$pwned"
spec main -- '$(touch '"$pwned"')' >/dev/null
t_rc "hostile path: NOT executed" 1 test -e "$pwned"
out="$(spec main -g "it's \"quoted\" & piped | here; ok")"
t_has "quotes and metacharacters in --grep are plain text" "RC=0" "$out"
spec -n main -a "x'; touch $pwned; echo '" >/dev/null
t_rc "dry-run with a quote-breaking author: nothing ran" 1 test -e "$pwned"
cmd="$(spec -n main -a "x'; touch $pwned; echo '" | grep '^  ▶ ' | head -n 1)"
sh -c "${cmd#  ▶ }" >/dev/null 2>&1
t_rc "...and the pasted command stays safe too" 1 test -e "$pwned"

# =============================== spec::current =======================================================
cur() {
	shell::git::commit::spec::current "$@" 2>&1
	echo "RC=$?"
}
git checkout -q main
out="$(cur)"
t_has "current: exit 0" "RC=0" "$out"
t_eq "current: the history of the current branch" "7" "$(printf '%s\n' "$out" | body | ncommits)"
git checkout -q side
t_eq "current: follows the checked out branch" "5" "$(cur | body | ncommits)"
t_has "current: ...(side work is there)" "feat: side work" "$(cur)"
git checkout -q main

t_eq "current -c 2" "2" "$(cur -c 2 | body | ncommits)"
t_eq "current --author Bob" "2" "$(cur --author Bob | body | ncommits)"
t_eq "current --since" "4" "$(cur --since 2024-03-20 | body | ncommits)"
t_eq "current --grep fix" "2" "$(cur --grep fix | body | ncommits)"
t_eq "current --no-merges" "6" "$(cur --no-merges | body | ncommits)"
t_eq "current --oneline --no-graph" "7" "$(cur --oneline --no-graph | body | ncommits)"
t_eq "current -- paths" "1" "$(cur -- docs | body | ncommits)"
t_eq "current: filters and paths together" "1" "$(cur -a Alice -c 1 -- docs | body | ncommits)"

out="$(cur -n -c 5)"
t_has "current -n is forwarded (dry-run)" "git log --graph" "$out"
t_has "current -n: the branch is in the command" "main" "$(printf '%s\n' "$out" | grep '^  ▶ ')"
t_eq "current -n: nothing is run" "0" "$(printf '%s\n' "$out" | body | ncommits)"
t_lacks "current -n: no status line" "[ok]" "$out"
t_has "current -n: the options are in the command" "--max-count=5" "$out"

git checkout -q --detach HEAD~1
out="$(cur -c 1)"
t_has "current: a detached HEAD shows the history of HEAD" "RC=0" "$out"
t_eq "current: detached -c 1" "1" "$(printf '%s\n' "$out" | body | ncommits)"
git checkout -q main

out="$(cur main)"
t_has "current: a positional argument is rejected" "RC=2" "$out"
out="$(cur --bogus)"
t_has "current: unknown option" "RC=2" "$out"
out="$(cur -c 0)"
t_has "current: invalid count" "RC=2" "$out"
out="$(cur --reverse)"
t_has "current: --reverse needs --no-graph" "RC=2" "$out"
t_rc "current -h" 0 shell::git::commit::spec::current -h
t_has "current help lists --count" "--count" "$T_OUT"
t_has "current help lists --author" "--author" "$T_OUT"

cd "$HOME" && rm -rf "$HOME/norepo" && mkdir "$HOME/norepo" && cd "$HOME/norepo" || exit 1
out="$(cur)"
t_has "current outside a repo: refused" "Not inside a Git repository" "$out"
t_has "current outside a repo: exit 1" "RC=1" "$out"

t_done
