#!/usr/bin/env bash
# shell::git::isolate::commit / file / lines (src/lang/git_isolate.sh): every operation creates a NEW
# branch in a NEW worktree and leaves the current checkout (branch, HEAD, staged, unstaged, untracked
# files, other worktrees and branches) exactly as it was. Real temporary repositories, no mocks.
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
t_setup

export SHELL_GIT_ISOLATE_DIR="$HOME/iso"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
R="$HOME/repo"
git init -q "$R" && cd "$R" || exit 1
git checkout -q -b main 2>/dev/null
seq 1 10 | sed 's/^/line /' >a.txt
printf 'keep\n' >b.txt
mkdir -p dir/sub && printf 'deep\n' >dir/sub/c.txt
git add -A && git commit -q -m "base"

# feature branch: edits a.txt (line 3 changed, two lines added after 7), changes b.txt, adds new.txt and dir/sub/d.txt
git checkout -q -b feature
sed -e 's/^line 3$/LINE THREE/' -e 's/^line 7$/line 7\nadded A\nadded B/' a.txt >a.tmp && mv a.tmp a.txt
printf 'changed\n' >b.txt
printf 'n1\nn2\nn3\n' >new.txt
printf 'd\n' >dir/sub/d.txt
git add -A && git commit -q -m "feature work"
FEAT="$(git rev-parse HEAD)"
git checkout -q main

# a user checkout with staged, unstaged and untracked work, plus an extra worktree and branch
printf 'mine\n' >>b.txt && git add b.txt
printf 'unstaged\n' >>a.txt
printf 'untracked\n' >untracked.txt
git branch other
git worktree add -q "$HOME/other-wt" other

snapshot() {
	{
		git rev-parse HEAD
		git symbolic-ref HEAD
		git status --porcelain=v1 --untracked-files=all
		git diff --cached
		git diff
		cat untracked.txt
		git for-each-ref --format='%(refname:short) %(objectname)' refs/heads/main refs/heads/feature refs/heads/other
		git worktree list --porcelain | awk -v RS= -v ORS="\n\n" '$0 ~ /other-wt/ || $0 ~ /\/repo\n/'

	} 2>&1
}
before="$(snapshot)"
wt_of() { git worktree list --porcelain | awk -v b="refs/heads/$1" '/^worktree /{w=substr($0,10)} $0=="branch " b{print w}'; }
rc() {
	"$@" >"$HOME/out.log" 2>&1
	echo "$?"
}

# --- commit -------------------------------------------------------------------------------------
t_eq "commit: succeeds" "0" "$(rc shell::git::isolate::commit "$FEAT")"
t_eq "commit: checkout unchanged" "$before" "$(snapshot)"
cbranch="$(git branch --list 'isolate/commit/*' --format='%(refname:short)' | head -n 1)"
t_ok "commit: a new branch was created" test -n "$cbranch"
t_eq "commit: the branch points at the commit" "$FEAT" "$(git rev-parse "$cbranch")"
cdir="$(wt_of "$cbranch")"
t_ok "commit: its worktree exists, outside the repo" test -f "$cdir/b.txt"
t_eq "commit: worktree content is the commit" "changed" "$(cat "$cdir/b.txt")"
t_eq "commit: a second run does not reuse the branch" "0" "$(rc shell::git::isolate::commit "$FEAT")"
t_eq "commit: collision gets a suffix" "2" "$(git branch --list 'isolate/commit/*' | wc -l | tr -d ' ')"
t_eq "commit: unknown commit" "3" "$(rc shell::git::isolate::commit deadbeefdeadbeef)"
t_eq "commit: checkout still unchanged" "$before" "$(snapshot)"

# explicit name that exists is an error and the branch is untouched
other_before="$(git rev-parse other)"
t_eq "commit: explicit existing branch fails" "7" "$(rc shell::git::isolate::commit -b other "$FEAT")"
t_eq "commit: existing branch untouched" "$other_before" "$(git rev-parse other)"
t_eq "commit: invalid branch name" "2" "$(rc shell::git::isolate::commit -b 'bad name~' "$FEAT")"
t_eq "commit: existing dir fails" "7" "$(rc shell::git::isolate::commit -b nb1 -d "$HOME/other-wt" "$FEAT")"
t_ok "commit: that failure created no branch" test -z "$(git branch --list nb1)"
t_eq "commit: dir inside the repo is refused" "2" "$(rc shell::git::isolate::commit -b nb2 -d "$R/inside" "$FEAT")"
t_eq "commit: dry-run creates nothing" "0" "$(rc shell::git::isolate::commit -n -b nb3 -d "$HOME/dry" "$FEAT")"
t_ok "commit: dry-run left no branch" test -z "$(git branch --list nb3)"
t_ok "commit: dry-run left no dir" test ! -e "$HOME/dry"
t_eq "commit: preview creates nothing" "0" "$(rc shell::git::isolate::commit -p "$FEAT")"
t_eq "commit: explicit name and dir" "0" "$(rc shell::git::isolate::commit -b mine/pick -d "$HOME/pick" "$FEAT")"
t_ok "commit: explicit worktree exists" test -f "$HOME/pick/new.txt"

# --- file ---------------------------------------------------------------------------------------
t_eq "file: new file succeeds" "0" "$(rc shell::git::isolate::file feature new.txt dir/sub/d.txt)"
fbranch="$(git branch --list 'isolate/file/*' --format='%(refname:short)' | head -n 1)"
fdir="$(wt_of "$fbranch")"
t_eq "file: branch starts at the current HEAD" "$(git rev-parse HEAD)" "$(git rev-parse "$fbranch")"
t_eq "file: requested file retrieved" "n1 n2 n3" "$(tr '\n' ' ' <"$fdir/new.txt" | sed 's/ $//')"
t_eq "file: directory structure preserved" "d" "$(cat "$fdir/dir/sub/d.txt")"
t_eq "file: only the requested files differ" "dir/sub/d.txt new.txt" "$(git -C "$fdir" diff --cached --name-only | tr '\n' ' ' | sed 's/ $//')"
t_eq "file: unrelated file untouched in the worktree" "keep" "$(cat "$fdir/b.txt")"
t_eq "file: checkout unchanged" "$before" "$(snapshot)"

# a file that exists at HEAD with other content is a conflict: nothing is created without --overwrite
nb="$(git branch | wc -l | tr -d ' ')"
t_eq "file: conflict is detected" "7" "$(rc shell::git::isolate::file feature b.txt)"
t_eq "file: conflict created no branch" "$nb" "$(git branch | wc -l | tr -d ' ')"
t_ok "file: conflict is reported" grep -q "Conflict: b.txt" "$HOME/out.log"
t_ok "file: dirty path is reported" grep -q "uncommitted changes" "$HOME/out.log"
t_eq "file: --preview of a conflict creates nothing" "0" "$(rc shell::git::isolate::file -p feature b.txt)"
t_eq "file: --overwrite works" "0" "$(rc shell::git::isolate::file -o feature b.txt)"
ob="$(git branch --list 'isolate/file/*-b.txt*' --format='%(refname:short)' | head -n 1)"
t_eq "file: overwritten only in the new branch" "changed" "$(git -C "$(wt_of "$ob")" show :b.txt)"
t_eq "file: your staged b.txt is intact" "keep mine" "$(tr '\n' ' ' <b.txt | sed 's/ $//')"
t_eq "file: missing in source" "3" "$(rc shell::git::isolate::file feature nope.txt)"
t_eq "file: missing source" "3" "$(rc shell::git::isolate::file nobranch a.txt)"
t_eq "file: a directory is not a file" "2" "$(rc shell::git::isolate::file feature dir)"
t_eq "file: .. is refused" "2" "$(rc shell::git::isolate::file feature ../x)"
t_eq "file: identical content is skipped" "8" "$(rc shell::git::isolate::file main dir/sub/c.txt)"
t_eq "file: dry-run prints commands only" "0" "$(rc shell::git::isolate::file -n -b dry/f -d "$HOME/dryf" feature new.txt)"
t_ok "file: dry-run left nothing" test -z "$(git branch --list dry/f)$([ -e "$HOME/dryf" ] && echo x)"
t_eq "file: checkout unchanged after all file runs" "$before" "$(snapshot)"

# a failing checkout rolls back only what it created
mkdir -p "$HOME/rb"
git branch rb-existing
t_eq "file: bad worktree target (file in the way) fails" "7" "$(rc shell::git::isolate::file -b rb-existing feature new.txt)"
t_ok "file: pre-existing branch survived" git show-ref --verify --quiet refs/heads/rb-existing
t_eq "file: no branch left after a failed explicit dir" "7" "$(rc shell::git::isolate::file -b rb-new -d "$HOME/rb" feature new.txt)"
t_ok "file: pre-existing directory survived" test -d "$HOME/rb"
t_ok "file: no stray branch" test -z "$(git branch --list rb-new)"

# --- lines --------------------------------------------------------------------------------------
# source a.txt (feature): 1 line 1, 2 line 2, 3 LINE THREE, 4..7 line 4..7, 8 added A, 9 added B, 10.. line 8..10
t_eq "lines: only the selected block" "0" "$(rc shell::git::isolate::lines feature a.txt 3)"
lbranch="$(git branch --list 'isolate/lines/*' --format='%(refname:short)' | head -n 1)"
ldir="$(wt_of "$lbranch")"
t_eq "lines: line 3 replaced" "LINE THREE" "$(sed -n 3p "$ldir/a.txt")"
t_eq "lines: no added lines came along" "10" "$(wc -l <"$ldir/a.txt" | tr -d ' ')"
t_eq "lines: only a.txt changed" "a.txt" "$(git -C "$ldir" diff --cached --name-only)"
t_eq "lines: the change is staged, not committed" "$(git rev-parse HEAD)" "$(git rev-parse "$lbranch")"
t_eq "lines: your unstaged a.txt is intact" "unstaged" "$(tail -n 1 a.txt)"
t_eq "lines: checkout unchanged" "$before" "$(snapshot)"

t_eq "lines: a range of added lines" "0" "$(rc shell::git::isolate::lines feature a.txt 8-9)"
l2="$(git branch --list 'isolate/lines/*' --format='%(refname:short)' | sed -n 2p)"
l2dir="$(wt_of "$l2")"
t_eq "lines: added lines inserted after line 7" "line 7 added A added B line 8" "$(sed -n '7,10p' "$l2dir/a.txt" | tr '\n' ' ' | sed 's/ $//')"
t_eq "lines: line 3 not replaced" "line 3" "$(sed -n 3p "$l2dir/a.txt")"

t_eq "lines: a partly selected block inserts only that line" "0" "$(rc shell::git::isolate::lines feature a.txt 9)"
t_ok "lines: partial selection is reported" grep -q "only in part" "$HOME/out.log"
l3="$(git branch --list 'isolate/lines/*' --format='%(refname:short)' | sed -n 3p)"
l3dir="$(wt_of "$l3")"
t_eq "lines: only 'added B' inserted" "added B" "$(sed -n 8p "$l3dir/a.txt")"
t_eq "lines: file grew by one" "11" "$(wc -l <"$l3dir/a.txt" | tr -d ' ')"

t_eq "lines: ranges and lists" "0" "$(rc shell::git::isolate::lines feature a.txt '3, 8-9')"
l4="$(git branch --list 'isolate/lines/*' --format='%(refname:short)' | sed -n 4p)"
l4dir="$(wt_of "$l4")"
t_eq "lines: both blocks applied" "LINE THREE|added A|added B" "$(printf '%s|%s|%s' "$(sed -n 3p "$l4dir/a.txt")" "$(sed -n 8p "$l4dir/a.txt")" "$(sed -n 9p "$l4dir/a.txt")")"

nb="$(git branch | wc -l | tr -d ' ')"
t_eq "lines: empty selection" "2" "$(rc shell::git::isolate::lines feature a.txt '')"
t_eq "lines: invalid selection" "2" "$(rc shell::git::isolate::lines feature a.txt 'x-y')"
t_eq "lines: reversed range" "2" "$(rc shell::git::isolate::lines feature a.txt 9-3)"
t_eq "lines: out of range" "2" "$(rc shell::git::isolate::lines feature a.txt 1-99)"
t_eq "lines: line 0" "2" "$(rc shell::git::isolate::lines feature a.txt 0)"
t_eq "lines: overlapping ranges" "2" "$(rc shell::git::isolate::lines feature a.txt '3-5,5-6')"
t_ok "lines: overlap is explained" grep -q "overlapping" "$HOME/out.log"
t_eq "lines: unchanged lines change nothing" "8" "$(rc shell::git::isolate::lines feature a.txt 1-2)"
t_eq "lines: missing file" "3" "$(rc shell::git::isolate::lines feature nope.txt 1)"
t_eq "lines: missing source" "3" "$(rc shell::git::isolate::lines nobranch a.txt 1)"
t_eq "lines: wrong argument count" "2" "$(rc shell::git::isolate::lines feature a.txt)"
t_eq "lines: none of the failures created a branch" "$nb" "$(git branch | wc -l | tr -d ' ')"
t_eq "lines: --preview creates nothing" "0" "$(rc shell::git::isolate::lines -p feature a.txt 3)"
t_eq "lines: dry-run creates nothing" "0" "$(rc shell::git::isolate::lines -n -b dry/l -d "$HOME/dryl" feature a.txt 3)"
t_ok "lines: dry-run left nothing" test -z "$(git branch --list dry/l)$([ -e "$HOME/dryl" ] && echo x)"

# a file that does not exist at HEAD is created from the selected lines only
t_eq "lines: new file from selected lines" "0" "$(rc shell::git::isolate::lines feature new.txt 2-3)"
nbranch="$(git branch --list 'isolate/lines/*new*' --format='%(refname:short)' | head -n 1)"
ndir="$(wt_of "$nbranch")"
t_eq "lines: new file has only lines 2-3" "n2 n3" "$(tr '\n' ' ' <"$ndir/new.txt" | sed 's/ $//')"

# a patch that cannot apply (source line removed from base after planning is simulated by a stale base) is rolled back
git checkout -q -b conflict-base feature~1 2>/dev/null
git stash list >/dev/null
git checkout -q main
t_eq "lines: checkout unchanged after all lines runs" "$before" "$(snapshot)"
t_eq "lines: the extra worktree is unchanged" "other" "$(git -C "$HOME/other-wt" rev-parse --abbrev-ref HEAD)"
t_eq "lines: no leftover temp files" "0" "$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'shell-isolate-*' 2>/dev/null | wc -l | tr -d ' ')"

# a failure after the worktree exists (the checkout inside it fails) is rolled back, and only that
cd "$R" || exit 1
before_df_branches="$(git branch | wc -l | tr -d ' ')"
before_df_wts="$(git worktree list | wc -l | tr -d ' ')"
git() {
	case " $* " in
	*" -C "*" checkout "*)
		echo "fatal: simulated failure" >&2
		return 1
		;;
	esac
	command git "$@"
}
t_eq "rollback: a failing checkout fails the call" "1" "$(rc shell::git::isolate::file feature new.txt)"
unset -f git
t_eq "rollback: no branch left" "$before_df_branches" "$(git branch | wc -l | tr -d ' ')"
t_eq "rollback: no worktree left" "$before_df_wts" "$(git worktree list | wc -l | tr -d ' ')"
t_ok "rollback: the error is shown" grep -q "simulated failure" "$HOME/out.log"
t_eq "rollback: checkout unchanged" "$before" "$(snapshot)"

# detached HEAD: allowed, based on the commit
git checkout -q --detach HEAD
t_eq "detached: file retrieval works" "0" "$(rc shell::git::isolate::file feature dir/sub/d.txt)"
t_ok "detached: it is reported" grep -q "detached" "$HOME/out.log"
git checkout -q main

# outside a repository / empty repository
cd "$HOME" || exit 1
t_eq "outside a repository" "1" "$(rc shell::git::isolate::commit HEAD)"
git init -q "$HOME/empty" && cd "$HOME/empty" || exit 1
t_eq "no commit yet" "1" "$(rc shell::git::isolate::file main a)"

t_done
