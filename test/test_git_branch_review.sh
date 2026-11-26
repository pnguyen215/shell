#!/usr/bin/env bash
# shell::git::branch::merged and ::stale on a throwaway repository with fixed dates.
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
t_setup

mkdir "$HOME/repo" && cd "$HOME/repo" || exit 1
git init -q . && git config user.email t@t && git config user.name t
git checkout -q -b main 2>/dev/null
# cm <date> <message>: an empty commit at a fixed date
cm() { GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" git commit -q --allow-empty -m "$2"; }
cm "2020-01-01T10:00:00" base
git branch merged-old # same commit as main: merged
git checkout -q -b old-work
cm "2020-02-01T10:00:00" "old work" # not merged, very old
git checkout -q main
git checkout -q -b "feature/a-rf" # merged, a name with a slash and a dash
git checkout -q main
git checkout -q -b fresh
cm "$(date -u +%Y-%m-%dT%H:%M:%S)" "fresh work" # not merged, new
git checkout -q main
git worktree add -q "$HOME/wt" -b in-worktree 2>/dev/null # merged but checked out elsewhere
git checkout -q -b current-merged                         # merged, and the branch we are on

# --- base resolution
t_eq "base: falls back to main" "main" "$(_shell::git::branch::base)"
t_eq "base: SHELL_GIT_BASE_BRANCH wins" "fresh" "$(SHELL_GIT_BASE_BRANCH=fresh _shell::git::branch::base)"
t_rc "base: a missing configured base fails" 1 env SHELL_GIT_BASE_BRANCH=nope bash -c 'cd "$1" && . "$SHELL_TEST_ROOT/src/shell.sh" && _shell::git::branch::base' _ "$HOME/repo"

# --- merged
out="$(shell::git::branch::merged 2>&1)"
t_has "merged: a merged branch is listed" "merged-old" "$out"
t_has "merged: a slashed branch name is listed intact" "feature/a-rf" "$out"
t_lacks "merged: unmerged work is not listed" "old-work" "$out"
t_lacks "merged: the base is not listed" "main" "$(printf '%s\n' "$out" | grep -x main)"
t_lacks "merged: the current branch is not listed" "current-merged" "$out"
t_lacks "merged: a worktree branch is not listed" "in-worktree" "$out"
t_eq "merged: --base changes the comparison (fresh descends from the merged branches)" "1" "$(shell::git::branch::merged --base fresh | grep -c "^merged-old$")"
t_rc "merged: unknown base" 1 shell::git::branch::merged --base nope
t_rc "merged: bad argument" 2 shell::git::branch::merged --bogus
t_rc "merged: --base needs a value" 2 shell::git::branch::merged --base
t_rc "merged: outside a repository" 1 bash -c 'cd "$HOME" && . "$SHELL_TEST_ROOT/src/shell.sh" && shell::git::branch::merged'
t_eq "merged: nothing was deleted" "1" "$(git rev-parse --verify -q refs/heads/merged-old >/dev/null && echo 1)"

# --- stale
out="$(shell::git::branch::stale --days 90 --plain)"
t_has "stale: an old branch is listed" "old-work" "$out"
t_lacks "stale: a fresh branch is not listed" "fresh" "$out"
t_eq "stale: tab separated, 4 fields" "4" "$(printf '%s\n' "$out" | grep '^old-work' | awk -F'\t' '{print NF}')"
t_has "stale: the commit date is shown with time" "2020-02-01 10:00" "$out"
t_lacks "stale: the current branch is skipped" "current-merged" "$out"
t_eq "stale: a huge threshold lists nothing" "" "$(shell::git::branch::stale --days 99999 --plain)"
t_rc "stale: --days must be numeric" 2 shell::git::branch::stale --days abc
t_rc "stale: bad argument" 2 shell::git::branch::stale --x
t_lacks "stale: no colour off a terminal" "$(printf '\033')" "$(shell::git::branch::stale --days 90)"

# --- constant number of git calls: a counting wrapper on PATH
mkdir "$HOME/cbin"
real_git="$(command -v git)"
printf '#!/bin/sh\necho x >>"%s/gitcalls"\nexec "%s" "$@"\n' "$HOME" "$real_git" >"$HOME/cbin/git"
chmod +x "$HOME/cbin/git"
i=0
while [ "$i" -lt 200 ]; do
	git branch "bulk-$i" main 2>/dev/null
	i=$((i + 1))
done
: >"$HOME/gitcalls"
PATH="$HOME/cbin:$PATH" shell::git::branch::stale --days 0 --plain >/dev/null
stale_calls="$(wc -l <"$HOME/gitcalls" | tr -d ' ')"
: >"$HOME/gitcalls"
PATH="$HOME/cbin:$PATH" shell::git::branch::merged >/dev/null
merged_calls="$(wc -l <"$HOME/gitcalls" | tr -d ' ')"
t_eq "perf: stale uses a constant number of git calls with 200+ branches (<= 3)" "1" "$([ "$stale_calls" -le 3 ] && echo 1 || echo 0)"
t_eq "perf: merged uses a constant number of git calls with 200+ branches (<= 8)" "1" "$([ "$merged_calls" -le 8 ] && echo 1 || echo 0)"

t_done
