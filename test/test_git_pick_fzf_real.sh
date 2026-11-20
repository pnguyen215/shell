#!/usr/bin/env bash
# shell::git::commit::pick::fzf against a REAL fzf in a REAL terminal (tmux), not the fake of
# test_git_pick_fzf.sh: what only a terminal can show. That Tab marks a row and the cursor stays on it,
# that the query, the marks and the cursor row come back after Back and after Ctrl-T (also when the query
# matches nothing), that the preview is on the right, and that the chosen files really get staged.
#
# Skipped unless tmux and fzf (0.35+) are installed. It runs the shell that runs this file (bash or zsh).
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

nl='
'
sh_name="bash"
if [ -n "${ZSH_VERSION-}" ]; then sh_name="zsh"; fi
sock="shell-test-$$"
SCREEN=""

term() { tmux -L "$sock" "$@"; }
tmux_new() { tmux -L "$sock" -f /dev/null "$@"; }
# snap: the current screen, as text, in SCREEN
snap() { SCREEN="$(term capture-pane -t t -p 2>/dev/null)"; }
# waitfor <text>: wait up to 10 s until the screen shows <text>; returns 1 when it never does
waitfor() {
	local i=0
	while [ "$i" -lt 50 ]; do
		snap
		case "$SCREEN" in *"$1"*) return 0 ;; esac
		sleep 0.2
		i=$((i + 1))
	done
	return 1
}
# keys <tmux keys...> / text <literal text>
keys() {
	term send-keys -t t "$@"
	sleep 0.3
}
text() {
	term send-keys -t t -l -- "$1"
	sleep 0.3
}
# start <function call>: the library loaded in a fresh shell inside tmux, in the test repository
start() {
	term kill-server 2>/dev/null
	tmux_new new-session -d -s t -x 150 -y 40 -c "$HOME/r" \
		"env HOME='$HOME' NO_COLOR=1 SHELL_AUTO_INSTALL_DEPS=0 SHELL_DIR='$SHELL_TEST_ROOT' PS1='' $sh_name -c '. \"$SHELL_TEST_ROOT/src/shell.sh\"; $1; echo \"RC=\$?\"; sleep 30'"
}
stop() { term kill-server 2>/dev/null; }
# row <text>: the screen line that contains <text>
row() { printf '%s\n' "$SCREEN" | grep -F -- "$1" | head -n 1; }
count_line() { printf '%s\n' "$SCREEN" | grep -F -m1 -- "/" | grep -o '[0-9]*/[0-9]* ([0-9]*)' | head -n 1; }

real_tests() {
	export GIT_CONFIG_NOSYSTEM=1 GIT_EDITOR=true
	git config --global user.email "t@example.com"
	git config --global user.name "T"
	mkdir "$HOME/r" && cd "$HOME/r" || exit 1
	git init -q && git checkout -q -b main
	echo base >f && git add f && git commit -q -m "base"
	git checkout -q -b feature
	echo one >a && git add a && git commit -q -m "x1: add a"
	echo s1 >"sp ace.txt"
	printf 'tab\n' >"ta	b.txt"
	printf 'nl\n' >"new${nl}line.txt"
	echo d >-dash.txt
	git add -A && git commit -q -m "x2: specials"
	echo two >>a && git add a && git commit -q -m "x3: a again"
	git checkout -q main

	# --- Tab marks and leaves the cursor where it is ------------------------------------------------------
	start "shell::git::commit::pick::fzf"
	waitfor "Source branch" || t_bad "real: the source list is shown"
	t_has "real: the source preview is on the right (a git log next to the list)" "x3: a again" "$SCREEN"
	keys Enter
	waitfor "Pick by files" || t_bad "real: the mode menu is shown"
	keys Down Enter
	waitfor "Files of feature" || t_bad "real: the files picker is shown"
	t_has "real: the preview is on the right of the list" "│ commit " "$SCREEN"
	t_has "real: a file of two commits appears on two rows" "a  " "$SCREEN"
	keys Down Tab
	snap
	t_has "real: Tab marks the row..." "(1)" "$SCREEN"
	t_has "real: ...and the cursor is still on it (pointer and mark on one row)" "▶✓" "$SCREEN"
	cursor_row="$(printf '%s\n' "$SCREEN" | grep -n '▶' | head -n 1 | cut -d: -f1)"
	keys Tab
	snap
	t_has "real: Tab again unmarks it" "(0)" "$SCREEN"
	t_eq "real: ...the cursor did not move either time" "$cursor_row" "$(printf '%s\n' "$SCREEN" | grep -n '▶' | head -n 1 | cut -d: -f1)"
	keys BTab
	snap
	t_has "real: Shift-Tab toggles without moving too" "(1)" "$SCREEN"
	t_eq "real: ...the cursor still did not move" "$cursor_row" "$(printf '%s\n' "$SCREEN" | grep -n '▶' | head -n 1 | cut -d: -f1)"
	keys Escape
	waitfor "RC=1" || t_bad "real: ESC cancels the whole workflow"
	t_has "real: ...and says so" "Cancelled" "$SCREEN"
	stop

	# --- query, marks and cursor survive Ctrl-T (also with no match) and Back ------------------------------
	start "shell::git::commit::pick::fzf"
	waitfor "Source branch" && keys Enter
	waitfor "Pick by files" && keys Down Enter
	waitfor "Files of feature" || t_bad "real: files picker (2)"
	text "a"
	keys Tab Down Tab
	snap
	t_has "real: two files marked under the query" "(2)" "$SCREEN"
	marked_before="$(printf '%s\n' "$SCREEN" | grep -c '✓')"
	pointer_before="$(printf '%s\n' "$SCREEN" | grep '▶' | head -n 1 | sed 's/^[^▶]*//')"
	keys C-t
	waitfor "Ctrl-T: pick by files" || t_bad "real: Ctrl-T opens the commit picker"
	t_has "real: Ctrl-T shows the other mode" "Commits of feature" "$SCREEN"
	keys C-t
	waitfor "Files of feature" || t_bad "real: Ctrl-T flips back"
	sleep 0.5
	snap
	t_has "real: back in the files picker the marks are still there" "(2)" "$SCREEN"
	t_has "real: ...and the query" "Files of feature (Tab to mark): a" "$SCREEN"
	t_eq "real: ...the same rows are marked" "$marked_before" "$(printf '%s\n' "$SCREEN" | grep -c '✓')"
	t_eq "real: ...and the cursor is on the same row" "$pointer_before" "$(printf '%s\n' "$SCREEN" | grep '▶' | head -n 1 | sed 's/^[^▶]*//')"
	text "(zz+"
	snap
	t_has "real: a query that matches nothing" "0/" "$SCREEN"
	keys C-t
	waitfor "Commits of feature" || t_bad "real: Ctrl-T works with nothing matching (and does not cancel)"
	keys C-t
	waitfor "Files of feature" || t_bad "real: ...and comes back"
	sleep 0.5
	snap
	t_has "real: the query, with brackets and a plus sign, is restored verbatim" "(zz+" "$SCREEN"
	t_has "real: ...and the marks hidden by it are kept" "(2)" "$SCREEN"
	keys Escape
	stop

	# --- Back from the action menu restores the picker -----------------------------------------------------
	start "shell::git::commit::pick::fzf"
	waitfor "Source branch" && keys Enter
	waitfor "Pick by files" && keys Enter
	waitfor "Commits of feature" || t_bad "real: commit picker"
	keys Tab Down Down Tab Up
	snap
	pointer_before="$(printf '%s\n' "$SCREEN" | grep '▶' | head -n 1 | sed 's/^[^▶]*//')"
	keys Enter
	waitfor "Apply the selected commits" || t_bad "real: the action menu is shown"
	t_has "real: the plan lists the commits oldest first" "2 commit(s) selected, oldest first" "$SCREEN"
	text "Back"
	keys Enter
	waitfor "Commits of feature" || t_bad "real: Back returns to the picker"
	sleep 0.5
	snap
	t_has "real: Back: the two marks are restored" "(2)" "$SCREEN"
	t_eq "real: Back: the cursor is on the same commit" "$pointer_before" "$(printf '%s\n' "$SCREEN" | grep '▶' | head -n 1 | sed 's/^[^▶]*//')"
	keys Escape
	stop

	# --- really apply files: special names, from the terminal ----------------------------------------------
	start "shell::git::commit::pick::fzf"
	waitfor "Source branch" && keys Enter
	waitfor "Pick by files" && keys Down Enter
	waitfor "Files of feature" || t_bad "real: files picker (3)"
	text "sp ace"
	keys Tab C-u
	text 'ta\tb'
	keys Tab C-u
	text 'new\nline'
	keys Tab C-u
	text "-dash"
	keys Tab C-u
	text "x1"
	keys Tab C-u
	snap
	t_has "real: five rows marked across five different queries" "(5)" "$SCREEN"
	keys Enter
	waitfor "Apply the selected files" || t_bad "real: the files action menu"
	keys Enter
	waitfor "RC=0" || t_bad "real: the files are applied"
	stop
	t_eq "real: exactly those files are staged" "-dash.txt|a|new${nl}line.txt|sp ace.txt|ta	b.txt|" "$(git diff --cached --name-only -z | tr '\0' '|')"
	t_eq "real: ...nothing is committed" "main" "$(git symbolic-ref --short HEAD)"
	t_eq "real: ...and the content is right" "one" "$(git show :a)"
}

if command -v tmux >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1; then
	real_tests
else
	printf '  (skipped: tmux and fzf are needed to drive the real fzf)\n'
fi
stop 2>/dev/null

t_done
