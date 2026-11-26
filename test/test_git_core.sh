#!/usr/bin/env bash
# The private helpers of the Git toolkit (src/lang/git/_core), tested directly.
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
t_setup
. "$SHELL_TEST_ROOT/test/support/git_toolkit.sh"
_shell::git::core::boot

# --- version.sh
t_eq "version_num: plain" "24801" "$(_shell::git::core::version_num 2.48.1)"
t_eq "version_num: git --version line" "22300" "$(_shell::git::core::version_num 'git version 2.23.0')"
t_eq "version_num: vendor suffix" "24200" "$(_shell::git::core::version_num 'git version 2.42.0.windows.1')"
t_eq "version_num: two fields" "1900" "$(_shell::git::core::version_num '0.19')"
t_eq "version_num: fzf line" "6400" "$(_shell::git::core::version_num '0.64.0 (brew)')"
t_eq "version_num: garbage is 0" "0" "$(_shell::git::core::version_num 'nonsense')"
_shell::git::core::git_ge 2 11
t_eq "git_ge: this git is at least 2.11" "0" "$?"
_shell::git::core::git_ge 99 0
t_eq "git_ge: not 99.0" "1" "$?"

# --- ui.sh
_shell::git::core::colors 0
t_eq "colors off: empty" "" "$_SHELL_GIT_C_RED$_SHELL_GIT_C_RESET"
saved_no_color="${NO_COLOR-}"
unset NO_COLOR
_shell::git::core::colors 1
t_eq "colors on: ESC sequence" "$(printf '\033[31m')" "$_SHELL_GIT_C_RED"
(
	NO_COLOR=1
	export NO_COLOR
	_shell::git::core::colors 1
	printf '%s' "$_SHELL_GIT_C_RED"
) >"$HOME/nc.out"
t_eq "colors: NO_COLOR gives no escape" "" "$(cat "$HOME/nc.out")"
export NO_COLOR="$saved_no_color"
_shell::git::core::colors auto
t_eq "colors auto: stdout is not a terminal in tests" "" "$_SHELL_GIT_C_GREEN"
t_eq "err: stderr only" "error: boom" "$(_shell::git::core::err boom 2>&1 >/dev/null)"
t_eq "err: nothing on stdout" "" "$(_shell::git::core::err boom 2>/dev/null)"
t_eq "info: quiet mode" "" "$(SHELL_GIT_QUIET=1 _shell::git::core::info hi 2>&1)"
t_eq "quote: plain words" "git branch -d -- old" "$(_shell::git::core::quote git branch -d -- old)"
t_eq "quote: a space is escaped" 'git branch -d -- my\ branch' "$(_shell::git::core::quote git branch -d -- 'my branch')"
t_eq "quote: an empty argument stays visible" "git x ''" "$(_shell::git::core::quote git x '')"
t_eq "dry: prints the command on stdout" "git branch -d -- -rf" "$(_shell::git::core::dry git branch -d -- -rf 2>/dev/null)"
t_eq "align: pads all but the last column" "a    bbb  x
ccc  d    y" "$(printf 'a\tbbb\tx\nccc\td\ty\n' | _shell::git::core::align)"
unset NO_COLOR
_shell::git::core::colors 1
aligned="$(printf 'a\tb\nccc\td\n' | _shell::git::core::align 'CYAN,')"
t_has "align: colors the first column" "$(printf '\033[36m')a" "$aligned"
t_eq "align: color codes do not change the alignment" "a    b
ccc  d" "$(printf '%s\n' "$aligned" | sed "s/$(printf '\033')\\[[0-9;]*m//g")"
_shell::git::core::colors 0
export NO_COLOR=1

# --- refs.sh
t_rc "valid_branch: ordinary" 0 _shell::git::core::valid_branch feature/x
t_rc "valid_branch: leading dash" 1 _shell::git::core::valid_branch -rf
t_rc "valid_branch: empty" 1 _shell::git::core::valid_branch ""
t_rc "valid_branch: space" 1 _shell::git::core::valid_branch "a b"
t_rc "valid_branch: double dot" 1 _shell::git::core::valid_branch "a..b"
t_eq "mask_url: credentials hidden" "https://***@github.com/a/b.git" "$(_shell::git::core::mask_url 'https://me:secret@github.com/a/b.git')"
t_eq "mask_url: ssh url untouched" "git@github.com:a/b.git" "$(_shell::git::core::mask_url 'git@github.com:a/b.git')"
t_eq "mask_url: plain https untouched" "https://github.com/a/b.git" "$(_shell::git::core::mask_url 'https://github.com/a/b.git')"

# --- state.sh and refs.sh on a repository
mkdir "$HOME/notrepo"
(cd "$HOME/notrepo" && _shell::git::core::require_repo >/dev/null 2>&1)
t_eq "require_repo: outside a repository is 3" "3" "$?"
gt_init "$HOME/repo"
t_rc "require_repo: inside a repository" 0 _shell::git::core::require_repo --worktree
gt_commit "first"
t_eq "head_branch" "main" "$(_shell::git::core::head_branch)"
_shell::git::core::upstream >/dev/null 2>&1
t_eq "upstream: none" "1" "$?"
t_eq "base: main" "main" "$(_shell::git::core::base)"
t_eq "base: SHELL_GIT_BASE_BRANCH wins when it exists" "main" "$(SHELL_GIT_BASE_BRANCH=main _shell::git::core::base)"
SHELL_GIT_BASE_BRANCH=nope _shell::git::core::base >/dev/null 2>&1
t_eq "base: a configured name that does not exist is refused" "1" "$?"
t_eq "rev: resolves a branch" "$(git rev-parse HEAD)" "$(_shell::git::core::rev main)"
_shell::git::core::rev -rf >/dev/null 2>&1
t_eq "rev: a leading dash never reaches git" "1" "$?"
_shell::git::core::rev nope >/dev/null 2>&1
t_eq "rev: unknown" "1" "$?"
git checkout -q -b side
gt_commit "side work"
git checkout -q main
git branch -- "--weird" 2>/dev/null
t_eq "ahead_behind: main vs side" "0 1" "$(_shell::git::core::ahead_behind main side)"
t_eq "ahead_behind: side vs main" "1 0" "$(_shell::git::core::ahead_behind side main)"
t_eq "tree_counts: clean" "0 0 0 0" "$(_shell::git::core::tree_counts)"
printf 'x\n' >>file1.txt
printf 'n\n' >untracked.txt
printf 'y\n' >staged.txt
git add staged.txt
t_eq "tree_counts: 1 staged, 1 unstaged, 1 untracked" "1 1 1 0" "$(_shell::git::core::tree_counts)"
_shell::git::core::require_clean "" >/dev/null 2>&1
t_eq "require_clean: dirty tree is exit 7" "7" "$?"
t_eq "require_clean: the message says why" "1" "$(_shell::git::core::require_clean "" 2>&1 | grep -c 'uncommitted')"
snap="$(gt_snapshot)"
_shell::git::core::require_clean "" >/dev/null 2>&1
t_eq "require_clean: refusing changes nothing" "$snap" "$(gt_snapshot)"
_shell::git::core::require_clean autostash >/dev/null 2>&1
t_eq "require_clean autostash: ok" "0" "$?"
t_eq "require_clean autostash: the tree is now clean" "0 0 1 0" "$(_shell::git::core::tree_counts)"
t_eq "require_clean autostash: a stash exists" "1" "$(git stash list | wc -l | tr -d ' ')"
git stash pop -q 2>/dev/null
git reset -q --hard HEAD 2>/dev/null
rm -f untracked.txt

# operations in progress
t_eq "operation: idle" "" "$(_shell::git::core::operation)"
t_rc "require_idle: idle" 0 _shell::git::core::require_idle
git checkout -q -b conflict-a
gt_commit "a" "clash.txt" "from a"
git checkout -q main
git checkout -q -b conflict-b
gt_commit "b" "clash.txt" "from b"
git merge conflict-a >/dev/null 2>&1
t_eq "operation: merge in progress" "merge" "$(_shell::git::core::operation)"
_shell::git::core::require_idle "amend" >/dev/null 2>&1
t_eq "require_idle: blocks with 7" "7" "$?"
t_has "require_idle: names the operation and how to leave it" "git merge --abort" "$(_shell::git::core::require_idle 2>&1)"
t_eq "conflicts: lists the unmerged path (NUL separated)" "clash.txt" "$(_shell::git::core::conflicts | tr '\0' '\n')"
t_eq "tree_counts: one conflicted entry" "1" "$(_shell::git::core::tree_counts | cut -d' ' -f4)"
git merge --abort
t_eq "operation: idle again" "" "$(_shell::git::core::operation)"
git checkout -q main
git checkout -q --detach
t_rc "head_branch: detached HEAD is 1" 1 _shell::git::core::head_branch
git checkout -q main

# --- backup.sh
head_before="$(git rev-parse HEAD)"
ref="$(_shell::git::core::backup_ref amend HEAD 2>/dev/null)"
t_has "backup_ref: under refs/shell-backup/amend/" "refs/shell-backup/amend/" "$ref"
t_eq "backup_ref: points at HEAD" "$head_before" "$(git rev-parse "$ref")"
t_has "backup_ref: prints the restore command on stderr" "git reset --hard $ref" "$(_shell::git::core::backup_ref amend HEAD 2>&1 >/dev/null)"
t_eq "backup_ref: two calls in the same second get distinct refs" "2" "$(git for-each-ref refs/shell-backup/amend | wc -l | tr -d ' ')"
_shell::git::core::backup_ref amend nope >/dev/null 2>&1
t_eq "backup_ref: a revision that is not a commit fails" "1" "$?"

printf 'tracked change\n' >>file1.txt
printf 'staged change\n' >>file2.txt
git add file2.txt
printf 'only on disk\n' >untracked-file.txt
snap="$(gt_snapshot)"
snapref="$(_shell::git::core::backup_snapshot discard -- file1.txt untracked-file.txt 2>/dev/null)"
t_has "backup_snapshot: under refs/shell-backup/discard/" "refs/shell-backup/discard/" "$snapref"
t_eq "backup_snapshot: leaves the repository as it was (but for the new ref)" "$(printf '%s\n' "$snap" | grep -v shell-backup)" "$(gt_snapshot | grep -v shell-backup)"
t_eq "backup_snapshot: the real index is untouched" "file2.txt" "$(git diff --cached --name-only)"
t_eq "backup_snapshot: holds the tracked change" "1" "$(git show "${snapref}:file1.txt" | grep -c 'tracked change')"
t_eq "backup_snapshot: holds the untracked file" "only on disk" "$(git show "${snapref}:untracked-file.txt")"
t_eq "backup_snapshot: second parent holds the staged version" "1" "$(git show "${snapref}^2:file2.txt" | grep -c 'staged change')"
git checkout -q -- file1.txt
rm -f untracked-file.txt
git restore --source="$snapref" --worktree -- file1.txt untracked-file.txt 2>/dev/null || git checkout "$snapref" -- file1.txt untracked-file.txt
t_eq "backup_snapshot: restore brings the tracked change back" "1" "$(grep -c 'tracked change' file1.txt)"
t_eq "backup_snapshot: restore brings the untracked file back" "only on disk" "$(cat untracked-file.txt)"
git reset -q --hard HEAD
git clean -fdq

# --- confirm.sh (answers come from SHELL_GIT_INPUT)
gt_input y
t_rc "confirm: y" 0 _shell::git::core::confirm "Go?"
_shell::git::core::input_close
gt_input n
_shell::git::core::confirm "Go?" >/dev/null 2>&1
t_eq "confirm: n is 5" "5" "$?"
_shell::git::core::input_close
gt_input ""
_shell::git::core::confirm "Go?" >/dev/null 2>&1
t_eq "confirm: empty answer is no (5)" "5" "$?"
_shell::git::core::input_close
gt_input
_shell::git::core::confirm "Go?" >/dev/null 2>&1
t_eq "confirm: end of input is 5" "5" "$?"
_shell::git::core::input_close
t_rc "confirm: --yes needs no input" 0 _shell::git::core::confirm "Go?" yes
unset SHELL_GIT_INPUT
_SHELL_GIT_INPUT_OPEN=""
out="$(_shell::git::core::confirm "Go?" </dev/null 2>&1)"
t_eq "confirm: non-interactive without --yes is 2" "2" "$(
	_shell::git::core::confirm 'Go?' </dev/null >/dev/null 2>&1
	echo $?
)"
t_has "confirm: ...and says how to proceed" "--yes" "$out"
gt_input "wrong" "drop"
_shell::git::core::confirm_typed "Dangerous." drop >/dev/null 2>&1
t_eq "confirm_typed: the wrong word is 5" "5" "$?"
_shell::git::core::confirm_typed "Dangerous." drop >/dev/null 2>&1
t_eq "confirm_typed: the right word is 0" "0" "$?"
_shell::git::core::input_close
t_eq "confirm_typed: --yes passes only when given explicitly" "0" "$(
	_shell::git::core::confirm_typed x drop yes >/dev/null 2>&1
	echo $?
)"
unset SHELL_GIT_INPUT
_SHELL_GIT_INPUT_OPEN=""

# --- fzf.sh: picker with a fake fzf, the numbered fallback, cancel and no-terminal behavior
gt_fake_fzf
recs="$(
	_shell::git::core::rec main "main  current"
	_shell::git::core::rec side "side  work"
)"
out="$(printf '%s\n' "$recs" | FAKE_FZF_PICKS="side  work" _shell::git::core::pick --prompt branch --header "enter: pick" 2>/dev/null)"
t_eq "pick: returns the raw first field, not the display" "side" "$out"
t_has "pick: the hidden-field options reach fzf" "--with-nth=2.." "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "pick: --ansi reaches fzf" "--ansi" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "pick: the header reaches fzf" "enter: pick" "$(cat "$FAKE_FZF_DIR/args.1")"
out="$(printf '%s\n' "$recs" | FAKE_FZF_PICKS="@all" _shell::git::core::pick --multi 2>/dev/null)"
t_eq "pick --multi: every selection, one per line" "main
side" "$out"
t_has "pick --multi: --multi reaches fzf" "--multi" "$(cat "$FAKE_FZF_DIR/args.2")"
t_eq "pick: esc (fzf 130) is exit 5" "5" "$(
	printf '%s\n' "$recs" | FAKE_FZF_PICKS="" _shell::git::core::pick >/dev/null 2>&1
	echo $?
)"
t_eq "pick: esc prints nothing on stdout" "" "$(printf '%s\n' "$recs" | FAKE_FZF_PICKS="" _shell::git::core::pick 2>/dev/null)"
t_eq "pick: fzf exit 1 (no match) is exit 5" "5" "$(
	printf '%s\n' "$recs" | FAKE_FZF_PICKS="@rc=1" _shell::git::core::pick >/dev/null 2>&1
	echo $?
)"
t_eq "pick -0: NUL records in, NUL-terminated raw fields out (a name with a newline survives)" "a
b|other|" "$(printf 'a\nb\037shown\0other\037x\0' | FAKE_FZF_PICKS="@all" _shell::git::core::pick -0 --multi 2>/dev/null | tr '\0' '|')"
t_eq "pick: SHELL_GIT_FZF_OPTS reaches fzf" "1" "$(
	printf '%s\n' "$recs" | FAKE_FZF_PICKS="@first" SHELL_GIT_FZF_OPTS="--height=40%" _shell::git::core::pick >/dev/null 2>&1
	grep -c -- '--height=40%' "$FAKE_FZF_DIR/args.$(cat "$FAKE_FZF_DIR/count")"
)"
# numbered fallback (no fzf): force it by hiding fzf and giving scripted answers
oldpath="$PATH"
PATH="$(printf '%s' "$PATH" | sed "s|$HOME/gt-bin:||")"
_SHELL_GIT_VER_FZF=0
unset SHELL_GIT_FORCE_FZF
gt_input 2
t_eq "pick fallback: a number picks that record" "side" "$(printf '%s\n' "$recs" | _shell::git::core::pick 2>/dev/null)"
_shell::git::core::input_close
gt_input "1 2"
t_eq "pick fallback --multi: several numbers" "main
side" "$(printf '%s\n' "$recs" | _shell::git::core::pick --multi 2>/dev/null)"
_shell::git::core::input_close
gt_input 9
_shell::git::core::pick </dev/null >/dev/null 2>&1 <<<"$recs"
t_eq "pick fallback: out of range is 5" "5" "$?"
_shell::git::core::input_close
gt_input ""
t_eq "pick fallback: empty answer is 5" "5" "$(
	printf '%s\n' "$recs" | _shell::git::core::pick >/dev/null 2>&1
	echo $?
)"
_shell::git::core::input_close
gt_input 1
t_has "pick fallback: lists the display column on stderr" "side  work" "$(printf '%s\n' "$recs" | _shell::git::core::pick 2>&1 >/dev/null)"
_shell::git::core::input_close
unset SHELL_GIT_INPUT
_SHELL_GIT_INPUT_OPEN=""
t_eq "pick: no terminal and no scripted input is exit 2" "2" "$(
	printf '%s\n' "$recs" | _shell::git::core::pick >/dev/null 2>&1 </dev/null
	echo $?
)"
t_has "pick: ...and says to pass the value" "argument" "$(printf '%s\n' "$recs" | _shell::git::core::pick 2>&1 </dev/null)"
PATH="$oldpath"

# --- split / nth helpers (the bash/zsh array differences live here)
_shell::git::core::split "a b  c"
t_eq "split: three words" "3" "${#_SHELL_GIT_WORDS[@]}"
_shell::git::core::nth 2 x y z
t_eq "nth: 1-based" "y" "$_SHELL_GIT_NTH"

# --- no eval anywhere in the toolkit, no sudo, no shell::exec::shell
t_eq "design: no eval in the toolkit" "0" "$(grep -rhE '(^|[^a-z_])eval[ (]' "$SHELL_TEST_ROOT/src/lang/git" | grep -vE '^[[:space:]]*#' | wc -l | tr -d ' ')"
t_eq "design: no sudo, shell::exec::shell or shell::remove_files in the toolkit" "0" "$(grep -rhE 'sudo|shell::exec::shell|shell::remove_files' "$SHELL_TEST_ROOT/src/lang/git" | grep -vE '^[[:space:]]*#' | wc -l | tr -d ' ')"

t_done
