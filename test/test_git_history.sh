#!/usr/bin/env bash
# shell::git::history::* on a throwaway repository. fzf is faked: call 1 picks FAKE_FZF_ROW (a
# line number of the list; with FAKE_FZF_KEY it also prints that key first, like --expect),
# later calls exit 130 (ESC). Stdin and arguments of every call are recorded.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

mkdir "$HOME/bin"
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
n="$(cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0)"
n=$((n + 1)); echo "$n" >"$FAKE_FZF_STATE"
cat >"$FAKE_FZF_DIR/stdin.$n"
printf '%s\n' "$@" >"$FAKE_FZF_DIR/args.$n"
[ "$n" -gt 1 ] && exit 130
[ -z "$FAKE_FZF_ROW" ] && exit 130
case " $* " in *--expect*) printf '%s\n' "$FAKE_FZF_KEY" ;; esac
sed -n "${FAKE_FZF_ROW}p" "$FAKE_FZF_DIR/stdin.$n"
FAKE
chmod +x "$HOME/bin/fzf"
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_FZF_ROW="" FAKE_FZF_KEY=""
reset_fzf() { find "$HOME" -maxdepth 1 \( -name "stdin.*" -o -name "args.*" -o -name fzf.count \) -exec rm -f {} +; }
US="$(printf '\037')"
field() { printf '%s\n' "$1" | cut -d "$US" -f"$2"; }

# --- a repository without any commit ------------------------------------------
mkdir "$HOME/empty" && cd "$HOME/empty" || exit 1
git init -q .
t_rc "no commits: repo scope is not an error" 0 shell::git::history::fzf --print
t_has "no commits: empty state" "No commits found" "$T_OUT"
t_eq "no commits: log is empty" "" "$(shell::git::history::log repo "" "")"

# --- the repository -----------------------------------------------------------
mkdir "$HOME/repo" && cd "$HOME/repo" || exit 1
git init -q . && git config user.email t@t && git config user.name tester
git checkout -q -b main 2>/dev/null
mkdir -p src/auth
F="src/auth/login file.go"
w() { # write the file: Login body, Logout body, Helper present?, header lines
	{
		[ "$4" -gt 0 ] && printf '// header\n// more\n'
		printf 'package main\n\nfunc Login() {\n\ta := %s\n}\n\nfunc Logout() {\n\tb := %s\n}\n' "$1" "$2"
		[ "$3" = "yes" ] && printf '\nfunc Helper() {\n\treturn\n}\n'
	} >"$F"
}
commit() { git add -A && git commit -q -m "$1" -m "${2:-}"; }
w 1 1 yes 0 && commit "init"
w 2 1 yes 0 && commit "change login"
w 2 2 yes 0 && commit "change logout"
w 3 3 yes 0 && commit "change both"
w 3 3 yes 1 && commit "shift lines"
mkdir -p "src/auth" && git mv "$F" "src/auth/new login.go" && F="src/auth/new login.go" && commit "rename file"
sed 's/func Login/func SignIn/' "$F" >"$F.tmp" && mv "$F.tmp" "$F" && commit "rename function"
printf 'x\n' >other.txt && commit "touch another file only"
# delete the Helper function
{ printf '// header\n// more\npackage main\n\nfunc SignIn() {\n\ta := 3\n}\n\nfunc Logout() {\n\tb := 3\n}\n'; } >"$F" && commit "delete helper"
LONG="$(printf 'very long subject %.0s' 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20)"
printf '// header\n// more\npackage main\n\nfunc SignIn() {\n\ta := 4\n}\n\nfunc Logout() {\n\tb := 3\n}\n' >"$F"
commit "$LONG" "Body line one

Body line two"
# merge commit that differs from both parents (so it is part of the file's history):
# the feature branch changes Logout, main changes the header (far enough apart not to conflict).
git checkout -q -b feat
printf '// header\n// more\npackage main\n\nfunc SignIn() {\n\ta := 4\n}\n\nfunc Logout() {\n\tb := 7\n}\n' >"$F" && commit "feature change"
git checkout -q main
printf '// HEADER\n// more\npackage main\n\nfunc SignIn() {\n\ta := 4\n}\n\nfunc Logout() {\n\tb := 3\n}\n' >"$F" && commit "main change"
git merge -q --no-ff feat -m "Merge feat" >/dev/null 2>&1
# a large diff in another file
i=0; : >big.txt; while [ "$i" -lt 3000 ]; do echo "line $i" >>big.txt; i=$((i + 1)); done
commit "large diff"

# --- context ------------------------------------------------------------------
ctx="$(shell::git::history::context "$F")"
t_eq "context: repo name" "repo" "$(field "$ctx" 2)"
t_eq "context: branch" "main" "$(field "$ctx" 3)"
t_eq "context: relative path" "$F" "$(field "$ctx" 4)"
ctx="$(cd src && shell::git::history::context "auth/new login.go")"
t_eq "context: resolved from a subdirectory" "$F" "$(field "$ctx" 4)"
ctx="$(shell::git::history::context "$HOME/repo/$F")"
t_eq "context: absolute path" "$F" "$(field "$ctx" 4)"
t_rc "context: unknown file" 1 shell::git::history::context nope.txt
t_has "context: says why" "not in this repository" "$T_OUT"
t_rc "context: deleted file is still known" 0 shell::git::history::context "src/auth/login file.go"
git checkout -q --detach HEAD
t_has "context: detached HEAD" "(detached at " "$(shell::git::history::context)"
git checkout -q main
t_eq "context: outside a repository fails" "1" "$(cd "$HOME" && shell::git::history::context >/dev/null 2>&1; echo $?)"

# --- scope --------------------------------------------------------------------
t_eq "scope: lines are normalized" "lines${US}$F${US}3,5" "$(shell::git::history::scope lines "$F" 3-5)"
t_eq "scope: START:END" "lines${US}$F${US}3,5" "$(shell::git::history::scope lines "$F" 3:5)"
t_rc "scope: reversed range" 1 shell::git::history::scope lines "$F" 9,3
t_rc "scope: range past the end" 1 shell::git::history::scope lines "$F" 1,9999
t_rc "scope: range is not a number" 1 shell::git::history::scope lines "$F" a,b
t_rc "scope: function needs a file" 1 shell::git::history::scope function "" Login
t_rc "scope: bad function name" 1 shell::git::history::scope function "$F" 'a;b'
t_rc "scope: unsupported type" 1 shell::git::history::scope blame "$F" x
t_rc "scope: empty search" 1 shell::git::history::scope search "" ""
t_eq "scope: repo needs nothing" "repo${US}${US}" "$(shell::git::history::scope repo "" "")"

# --- file history: --follow across the rename ---------------------------------
recs="$(shell::git::history::log file "$F")"
subjects="$(printf '%s\n' "$recs" | cut -d "$US" -f14)"
t_has "file: follows the rename (oldest commit)" "init" "$subjects"
t_has "file: has the rename commit" "rename file" "$subjects"
t_lacks "file: no commit of other files" "touch another file only" "$subjects"
t_lacks "file: no unrelated large diff" "large diff" "$subjects"
t_eq "file: path at the oldest commit is the old name" "src/auth/login file.go" "$(field "$(printf '%s\n' "$recs" | tail -n 1)" 9)"
t_eq "file: path at the newest commit is the new name" "$F" "$(field "$(printf '%s\n' "$recs" | head -n 1)" 9)"
t_eq "file: records are one line each" "$(printf '%s\n' "$recs" | grep -c .)" "$(printf '%s\n' "$recs" | wc -l | tr -d ' ')"
# git log --follow drops merge commits (a Git limitation); the repository scope keeps them.
all="$(shell::git::history::log repo "" "")"
t_has "repo: merge commit is listed" "Merge feat" "$(printf '%s\n' "$all" | cut -d "$US" -f14)"
merge_line="$(printf '%s\n' "$all" | grep "Merge feat" | head -n 1)"
t_eq "repo: merge flag" "1" "$(field "$merge_line" 8)"
t_eq "repo: a commit that is not a merge" "0" "$(field "$(printf '%s\n' "$all" | grep 'large diff' | head -n 1)" 8)"
long_line="$(printf '%s\n' "$recs" | grep "very long subject" | head -n 1)"
t_has "file: body is kept, newlines escaped" 'Body line one\n\nBody line two' "$(field "$long_line" 15)"
t_has "file: long subject is intact in the record" "very long subject very long subject" "$(field "$long_line" 14)"
t_eq "file: stats count the commits" "$(printf '%s\n' "$recs" | grep -c .)" "$(printf '%s\n' "$recs" | shell::git::history::stats | cut -f1)"

# --- function history: only the function's own lines are counted --------------
recs="$(shell::git::history::log function "$F" Logout)"
subj="$(printf '%s\n' "$recs" | cut -d "$US" -f14)"
t_has "function: commit that changed only Logout" "change logout" "$subj"
t_has "function: commit that changed both" "change both" "$subj"
t_has "function: the creation" "init" "$subj"
t_lacks "function: a commit that changed only Login is not listed" "change login" "$subj"
t_lacks "function: another file's commit is not listed" "touch another file only" "$subj"
both="$(printf '%s\n' "$recs" | grep "change both" | head -n 1)"
t_eq "function: additions are the function's lines only" "1" "$(field "$both" 5)"
t_eq "function: deletions are the function's lines only" "1" "$(field "$both" 6)"
t_eq "function: whole-commit additions are kept apart" "2" "$(field "$both" 11)"
t_eq "function: whole-commit deletions are kept apart" "2" "$(field "$both" 12)"
init_line="$(printf '%s\n' "$recs" | tail -n 1)"
t_eq "function: creation adds the 3 lines of the function" "3" "$(field "$init_line" 5)"
t_eq "function: follows the file rename (old path)" "src/auth/login file.go" "$(field "$init_line" 9)"
# a function rename is not AST tracking: the new name starts its own history at the rename
recs2="$(shell::git::history::log function "$F" SignIn)"
t_has "function: renamed function has its commits" "rename function" "$(printf '%s\n' "$recs2" | cut -d "$US" -f14)"
# deleted function: Helper is gone at HEAD, its history is still reachable
t_rc "function: deleted function" 0 shell::git::history::log function "$F" Helper
t_has "function: deleted function keeps its history" "init" "$(shell::git::history::log function "$F" Helper 2>/dev/null | cut -d "$US" -f14)"
t_has "function: deleted function is announced" "no longer at HEAD" "$(shell::git::history::log function "$F" Helper 2>&1 >/dev/null)"
t_rc "function: unknown function" 1 shell::git::history::log function "$F" DoesNotExist

# --- line range: follows the lines while the numbers shift --------------------
# Login is on lines 5-7 at HEAD (two header lines were added above it).
recs="$(shell::git::history::log lines "$F" 5,7)"
subj="$(printf '%s\n' "$recs" | cut -d "$US" -f14)"
t_has "lines: the creation" "init" "$subj"
t_has "lines: a change inside the range" "change login" "$subj"
t_lacks "lines: shifting the lines is not a change of them" "shift lines" "$subj"
t_lacks "lines: a change outside the range" "change logout" "$subj"

# --- code search: -S and -G ---------------------------------------------------
recs="$(shell::git::history::log search "" "b := 7")"
t_eq "search -S: one commit introduced the text" "1" "$(printf '%s\n' "$recs" | grep -c .)"
t_eq "search -S: it is the right commit" "feature change" "$(field "$recs" 14)"
t_eq "search -S with a file" "1" "$(shell::git::history::log search "$F" "b := 7" | grep -c .)"
t_eq "search -S: whole-commit numbers differ from the scope's when other files changed" "1" "$(shell::git::history::log search "$F" "b := 7" | awk -F"$US" '$11 >= $5 {c++} END {print c + 0}')"
recs="$(shell::git::history::log regex "" 'b := [23]')"
t_eq "search -G: same commits as git itself" "$(git log -G'b := [23]' --format=%h | wc -l | tr -d ' ')" "$(printf '%s\n' "$recs" | grep -c .)"
t_eq "search: nothing matches" "" "$(shell::git::history::log search "" "text that never existed")"

# --- statistics describe the scope, not the repository ------------------------
stats="$(shell::git::history::log function "$F" Logout | shell::git::history::stats)"
t_eq "stats: commits of the function" "4" "$(printf '%s' "$stats" | cut -f1)"
t_eq "stats: additions of the function only" "6" "$(printf '%s' "$stats" | cut -f2)"
t_eq "stats: deletions of the function only" "3" "$(printf '%s' "$stats" | cut -f3)"
t_eq "stats: single author" "1" "$(printf '%s' "$stats" | cut -f6)"
t_eq "stats: empty input" "0	0	0	-	-	0" "$(printf '' | shell::git::history::stats)"
repo_stats="$(shell::git::history::log repo "" "" | shell::git::history::stats)"
t_eq "stats: the large diff counts for the repository scope" "1" "$([ "$(printf '%s' "$repo_stats" | cut -f2)" -ge 3000 ] && echo 1 || echo 0)"

# --- max and no-merges --------------------------------------------------------
t_eq "max: limits the commits" "2" "$(shell::git::history::log file "$F" "" 2 | grep -c .)"
t_lacks "no-merges: merge left out" "Merge feat" "$(shell::git::history::log repo "" "" 500 false | cut -d "$US" -f14)"

# --- timeline -----------------------------------------------------------------
tl="$(shell::git::history::log file "$F" | shell::git::history::timeline -w 80)"
tl_repo="$(shell::git::history::log repo "" "" | shell::git::history::timeline -w 80)"
t_has "timeline: commit glyph" "● " "$tl"
t_has "timeline: merge glyph" "◆ " "$tl_repo"
t_has "timeline: merge is labelled" "merge" "$tl_repo"
t_has "timeline: connector" "│ tester" "$tl"
t_has "timeline: additions and deletions" "+1 -1" "$tl"
case "$(printf '%s\n' "$tl" | tail -n 1)" in "  tester  +"*) t_ok ;; *) t_bad "timeline: the last block has no connector" "$(printf '%s\n' "$tl" | tail -n 2)" ;; esac
t_lacks "timeline: no colour off a terminal" "$(printf '\033')" "$tl"
narrow="$(shell::git::history::log file "$F" | shell::git::history::timeline -w 30 | head -n 1)"
t_eq "timeline: narrow width cuts the subject" "1" "$([ "${#narrow}" -le 40 ] && echo 1 || echo 0)"
colored="$(shell::git::history::log file "$F" | shell::git::history::timeline -c -w 80)"
t_has "timeline: green additions" "$(printf '\033[32m')" "$colored"
t_has "timeline: red deletions" "$(printf '\033[31m')" "$colored"
t_has "timeline: cyan hashes" "$(printf '\033[36m')" "$colored"
sel="$(shell::git::history::log file "$F" | head -n 1 | cut -d "$US" -f2)"
t_has "timeline: selected commit is marked" "▶" "$(shell::git::history::log file "$F" | shell::git::history::timeline -s "$sel")"
rows="$(shell::git::history::log file "$F" | shell::git::history::timeline -r -w 100)"
t_eq "rows: one row per commit" "$(shell::git::history::log file "$F" | grep -c .)" "$(printf '%s\n' "$rows" | grep -c .)"
t_eq "rows: five tab separated columns" "5" "$(printf '%s\n' "$rows" | head -n 1 | awk -F'\t' '{print NF}')"
t_eq "rows: path column is never empty" "0" "$(printf '%s\n' "$rows" | awk -F'\t' '$2 == "" || $3 == "" {c++} END {print c + 0}')"

# --- dashboard ----------------------------------------------------------------
d="$(shell::git::history::dashboard -w 60 my-project develop function "src/auth/login.go" Login 18 248 132 2026-09-30 2026-10-28)"
t_has "dashboard: title" "GIT CHRONICLE" "$d"
t_has "dashboard: repository" "Repository: my-project" "$d"
t_has "dashboard: branch" "Branch: develop" "$d"
t_has "dashboard: scope" "SCOPE: FUNCTION" "$d"
t_has "dashboard: function" "Function: Login()" "$d"
t_has "dashboard: totals" "+248" "$d"
t_has "dashboard: totals deletions" "-132" "$d"
widths=""
while IFS= read -r l; do widths="$widths ${#l}"; done <<<"$d"
t_eq "dashboard: every row has the same width" "1" "$(printf '%s\n' $widths | sort -u | wc -l | tr -d ' ')"
dl="$(shell::git::history::dashboard -w 60 r b lines "$F" 1,5 1 1 1)"
t_has "dashboard: line range" "Lines: 1,5" "$dl"
dn="$(shell::git::history::dashboard -w 30 r b file src/a.go "" 1 1 1)"
t_lacks "dashboard: narrow width has no box" "╭" "$dn"
t_has "dashboard: narrow width keeps the numbers" "COMMITS" "$dn"
dp="$(shell::git::history::dashboard -w 50 r b file "$(printf 'dir/%.0s' 1 2 3 4 5 6 7 8 9 10 11 12)file.go" "" 1 1 1)"
t_has "dashboard: long paths keep their tail" "…" "$dp"
t_rc "dashboard: unknown option" 2 shell::git::history::dashboard --bogus

# --- print mode, dry run, usage -----------------------------------------------
t_rc "print: file" 0 shell::git::history::fzf --print "$F"
t_has "print: dashboard" "SCOPE: FILE" "$T_OUT"
t_has "print: timeline" "init" "$T_OUT"
t_rc "print: function" 0 shell::git::history::fzf --print --function Logout "$F"
t_has "print: function scope" "Function: Logout()" "$T_OUT"
t_rc "print: lines" 0 shell::git::history::fzf --print --lines 5,7 "$F"
t_has "print: lines scope" "Lines: 5,7" "$T_OUT"
t_rc "print: search" 0 shell::git::history::fzf --print --search "a := 4"
t_has "print: search scope" "CODE SEARCH (-S)" "$T_OUT"
t_rc "print: regex" 0 shell::git::history::fzf --print --regex 'a := [0-9]' "$F"
t_rc "print: empty history is a message, not an error" 0 shell::git::history::fzf --print --search "never existed"
t_has "print: empty state" "No commits found" "$T_OUT"
t_rc "print: whole repository" 0 shell::git::history::fzf --print
t_has "print: repository scope" "SCOPE: REPOSITORY" "$T_OUT"
t_rc "dry run" 0 shell::git::history::fzf -n --function Logout "$F"
t_has "dry run: shows git -L" "-L" "$T_OUT"
t_has "dry run: the path is quoted" "new login.go'" "$T_OUT"
t_rc "two scopes at once" 2 shell::git::history::fzf --function a --lines 1,2 "$F"
t_rc "scope option without a value" 2 shell::git::history::fzf --function
t_rc "unknown option" 2 shell::git::history::fzf --bogus
t_rc "function without a file" 1 shell::git::history::fzf --print --function Login
t_rc "unknown file" 1 shell::git::history::fzf --print nope.txt
t_rc "bad --max" 2 shell::git::history::fzf --max abc
t_rc "interactive with print" 2 shell::git::history::fzf -i -p
t_rc "help" 0 shell::git::history::fzf --help
t_has "help: shortcuts are documented" "Ctrl-Y" "$T_OUT"

# --- the fzf viewer -----------------------------------------------------------
reset_fzf
t_rc "fzf: file history runs" 0 shell::git::history::fzf "$F"
list="$(cat "$HOME/stdin.1")"
args="$(cat "$HOME/args.1")"
t_eq "fzf: one row per commit plus Back" "$(($(shell::git::history::log file "$F" | grep -c .) + 1))" "$(printf '%s\n' "$list" | grep -c .)"
t_has "fzf: Back is last" "Back" "$(printf '%s\n' "$list" | tail -n 1)"
t_has "fzf: dashboard in the header" "GIT CHRONICLE" "$args"
t_has "fzf: shortcuts in the header" "^Y copy hash" "$args"
t_has "fzf: preview follows the cursor" "show -s" "$args"
t_has "fzf: preview is restricted to the file" "{2}" "$args"
t_has "fzf: preview quotes the repository" "git -C" "$args"
t_has "fzf: copy and open are expected keys" "--expect=ctrl-y,ctrl-o,ctrl-f,ctrl-b" "$args"
t_has "fzf: chronological order is kept" "--no-sort" "$args"
reset_fzf
t_rc "fzf: function preview uses git log -L" 0 shell::git::history::fzf --function Logout "$F"
t_has "fzf: function preview" "log -L" "$(cat "$HOME/args.1")"
t_has "fzf: function preview falls back, never blank" "||" "$(cat "$HOME/args.1")"

# Enter: the scoped diff of the commit (output is not a terminal: plain, no pager).
both_row="$(shell::git::history::log function "$F" Logout | cut -d "$US" -f14 | grep -n 'change both' | cut -d: -f1)"
reset_fzf; FAKE_FZF_ROW="$both_row"
t_rc "fzf: Enter inspects" 0 shell::git::history::fzf --function Logout "$F"
t_has "fzf: inspect shows the message" "change both" "$T_OUT"
t_has "fzf: inspect shows the function's change" "+	b := 3" "$T_OUT"
t_lacks "fzf: inspect leaves out the other function" "a := 3" "$T_OUT"
t_eq "fzf: the list comes back until ESC" "2" "$(cat "$HOME/fzf.count")"
# Ctrl-F: the whole commit
reset_fzf; FAKE_FZF_ROW="$both_row"; FAKE_FZF_KEY=ctrl-f
t_rc "fzf: Ctrl-F shows the whole commit" 0 shell::git::history::fzf --function Logout "$F"
t_has "fzf: whole commit includes the other function" "a := 3" "$T_OUT"
# Ctrl-B: blame
reset_fzf; FAKE_FZF_ROW=1; FAKE_FZF_KEY=ctrl-b
t_rc "fzf: Ctrl-B blames the scope" 0 shell::git::history::fzf --function Logout "$F"
t_has "fzf: blame shows the author" "tester" "$T_OUT"
# Ctrl-Y: copy the hash (a fake clipboard tool)
cat >"$HOME/bin/pbcopy" <<'FAKE'
#!/bin/sh
cat >"$FAKE_FZF_DIR/clipboard"
FAKE
chmod +x "$HOME/bin/pbcopy" "$HOME/bin/xclip" 2>/dev/null
reset_fzf; FAKE_FZF_ROW=1; FAKE_FZF_KEY=ctrl-y
t_rc "fzf: Ctrl-Y runs" 0 shell::git::history::fzf "$F"
want="$(shell::git::history::log file "$F" | head -n 1 | cut -d "$US" -f1)"
if [ "$(shell::os::type)" = "macos" ] && [ -f "$HOME/clipboard" ]; then t_eq "fzf: Ctrl-Y copies the full hash" "$want" "$(cat "$HOME/clipboard")"; else t_has "fzf: Ctrl-Y copies the hash" "Copied" "$T_OUT"; fi
FAKE_FZF_KEY=""
# Back entry
n="$(($(shell::git::history::log file "$F" | grep -c .) + 1))"
reset_fzf; FAKE_FZF_ROW="$n"
t_rc "fzf: Back returns RETURN_BACK" 11 shell::git::history::fzf "$F"
t_eq "fzf: Back does not reopen the list" "1" "$(cat "$HOME/fzf.count")"
FAKE_FZF_ROW=""
reset_fzf
t_rc "fzf: ESC leaves quietly" 0 shell::git::history::fzf "$F"
reset_fzf
t_rc "fzf: empty history never opens fzf" 0 shell::git::history::fzf --search "never existed"
t_eq "fzf: empty history: fzf not called" "" "$(cat "$HOME/fzf.count" 2>/dev/null)"

# --- inspect directly ---------------------------------------------------------
sha="$(git log -n 1 --format=%H --grep='change login')"
t_rc "inspect: needs a commit" 1 shell::git::history::inspect /tmp function "$F" Login
t_rc "inspect: unknown option" 2 shell::git::history::inspect --bogus
t_rc "inspect: file scope" 0 shell::git::history::inspect "$HOME/repo" file "$F" "" "$sha" "src/auth/login file.go"
t_has "inspect: parents are shown" "Parents:" "$T_OUT"
t_has "inspect: the diff" "+	a := 2" "$T_OUT"
# commit that deleted a function: the scope cannot be resolved there, the file diff is shown
del="$(git log -n 1 --format=%H --grep='delete helper')"
t_rc "inspect: scope gone at that commit" 0 shell::git::history::inspect "$HOME/repo" function "$F" Helper "$del" "$F" ""
t_has "inspect: says what it shows instead" "showing the whole file diff" "$T_OUT"

# --- interactive scope picking ------------------------------------------------
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
# scripted picks: one line of FAKE_FZF_PICKS per call
n="$(cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0)"
n=$((n + 1)); echo "$n" >"$FAKE_FZF_STATE"
cat >"$FAKE_FZF_DIR/stdin.$n"
sed -n "${n}p" "$FAKE_FZF_DIR/picks"
FAKE
reset_fzf
printf '%s\n' "$F" "Function history" "Logout" >"$HOME/picks"
t_eq "pick: file, function, name" "function${US}$F${US}Logout" "$(shell::git::history::pick "$HOME/repo" 2>/dev/null)"
t_has "pick: function candidates come from the file" "Logout" "$(cat "$HOME/stdin.3")"
reset_fzf
printf '%s\n' "(whole repository)" "All commits" >"$HOME/picks"
t_eq "pick: whole repository" "repo${US}${US}" "$(shell::git::history::pick "$HOME/repo" 2>/dev/null)"
reset_fzf
printf '%s\n' "← Back" >"$HOME/picks"
t_rc "pick: Back at the first step" 11 shell::git::history::pick "$HOME/repo"
reset_fzf
printf '%s\n' "$F" "Line range" >"$HOME/picks"
t_eq "pick: line range asks for the range" "lines${US}$F${US}5,7" "$(printf '5,7\n' | shell::git::history::pick "$HOME/repo" 2>/dev/null)"

# --- the repository is never modified ------------------------------------------
before="$(git status --porcelain; git rev-parse HEAD; git for-each-ref)"
shell::git::history::fzf --print --function Logout "$F" >/dev/null 2>&1
shell::git::history::fzf --print "$F" >/dev/null 2>&1
t_eq "read-only: working tree, HEAD and refs are unchanged" "$before" "$(git status --porcelain; git rev-parse HEAD; git for-each-ref)"

t_done
