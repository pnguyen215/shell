#!/usr/bin/env bash
# shell::help / shell::function::explore against a REAL fzf in a REAL terminal (tmux): what the fake of
# test_function_fzf.sh cannot show. That the preview panel really renders a function's documentation
# (the preview runs outside the library), that search covers names and descriptions, that Enter alone
# runs nothing, and that "Run it..." runs the function in the shell the explorer was started from.
#
# Skipped unless tmux and fzf are installed. It runs the shell that runs this file (bash or zsh).
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
t_setup

sh_name="bash"
if [ -n "${ZSH_VERSION-}" ]; then sh_name="zsh"; fi
sock="shell-test-fn-$$"
SCREEN=""

term() { tmux -L "$sock" "$@"; }
snap() { SCREEN="$(term capture-pane -t t -p 2>/dev/null)"; }
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
keys() {
	term send-keys -t t "$@"
	sleep 0.3
}
text() {
	term send-keys -t t -l -- "$1"
	sleep 0.3
}
start() {
	term kill-server 2>/dev/null
	tmux -L "$sock" -f /dev/null new-session -d -s t -x 160 -y 40 -c "$HOME" \
		"env HOME='$HOME' NO_COLOR=1 SHELL_AUTO_INSTALL_DEPS=0 SHELL_DIR='$SHELL_TEST_ROOT' PS1='' $sh_name -c '. \"$SHELL_TEST_ROOT/src/shell.sh\"; shell::zzreal::mark() { echo ran-here > \"\$HOME/ran.out\"; }; $1; echo \"RC=\$?\"; sleep 30'"
}
stop() { term kill-server 2>/dev/null; }

real_tests() {
	# --- namespaces, search, preview -------------------------------------------------------------------
	start "shell::help"
	waitfor "Namespace:" || t_bad "real: the namespace list is shown"
	t_has "real: all functions come first" "All functions (" "$SCREEN"
	t_has "real: a namespace with its count" "angular (1)" "$SCREEN"
	text "os ("
	keys Enter
	waitfor "Function (os):" || t_bad "real: the function list of the namespace is shown"
	t_has "real: functions of the namespace" "shell::os::type" "$SCREEN"
	t_lacks "real: and no others" "shell::git::" "$SCREEN"
	text "operating"
	waitfor "1/" || true
	sleep 0.5
	snap
	t_has "real: search matches the description, not only the name" "shell::os::type" "$SCREEN"
	t_has "real: the preview panel shows the documentation (it runs outside the library)" "DESCRIPTION" "$SCREEN"
	t_has "real: ...of the function under the cursor" "Print the normalised operating-system name." "$SCREEN"
	t_has "real: ...with its place in the source" "src/core/os.sh" "$SCREEN"
	t_has "real: ...and it sits on the right of the list" "│ shell::os::type" "$SCREEN"
	keys Escape
	waitfor "RC=0" || t_bad "real: ESC closes the explorer"
	stop

	# --- Enter runs nothing; Run runs here ----------------------------------------------------------------
	rm -f "$HOME/ran.out"
	start "shell::help zzreal"
	waitfor "Function (zzreal):" || t_bad "real: a namespace given as the argument opens its list"
	keys Enter
	waitfor "Show details" || t_bad "real: Enter opens the action menu"
	t_has "real: the menu offers Run explicitly" "Run it..." "$SCREEN"
	t_eq "real: Enter on a function ran nothing" "no" "$([ -e "$HOME/ran.out" ] && echo yes || echo no)"
	keys Down Enter
	waitfor "Arguments for shell::zzreal::mark" || t_bad "real: Run asks for the arguments"
	keys Enter
	waitfor "(y/n)" || t_bad "real: ...then for a confirmation"
	t_eq "real: still nothing ran before the confirmation" "no" "$([ -e "$HOME/ran.out" ] && echo yes || echo no)"
	text "y"
	keys Enter
	waitfor "Exit status: 0" || t_bad "real: the function ran and its status is shown"
	t_eq "real: it ran in the explorer's own shell" "ran-here" "$(cat "$HOME/ran.out" 2>/dev/null)"
	keys Enter
	waitfor "Function (zzreal):" || t_bad "real: then the list comes back"
	keys Escape
	stop
}

if command -v tmux >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1; then
	real_tests
else
	printf '  (skipped: tmux and fzf are needed to drive the real fzf)\n'
fi
stop 2>/dev/null

t_done
