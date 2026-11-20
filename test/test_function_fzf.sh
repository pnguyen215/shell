#!/usr/bin/env bash
# The function explorer (shell::function::explore, shell::help): namespace list -> function list -> action menu.
# fzf is faked: each call outputs the stdin lines that match the scripted picks (exact line first, then
# substring) and records what it was given. What a real fzf draws is in test_function_fzf_real.sh.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

mkdir "$HOME/bin"
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
n="$(cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0)"
n=$((n + 1))
echo "$n" >"$FAKE_FZF_STATE"
cat >"$FAKE_FZF_DIR/stdin.$n"
printf '%s\n' "$@" >"$FAKE_FZF_DIR/args.$n"
rec="$(printf '%s\n' "$FAKE_FZF_PICKS" | awk -v n="$n" 'BEGIN { c = 1 } /^---$/ { c++; next } c == n { print }')"
[ -z "$rec" ] && exit 130
printf '%s\n' "$rec" | while IFS= read -r want; do
	[ -z "$want" ] && continue
	line="$(grep -F -x -- "$want" "$FAKE_FZF_DIR/stdin.$n" | head -n 1)"
	[ -z "$line" ] && line="$(grep -F -- "$want" "$FAKE_FZF_DIR/stdin.$n" | head -n 1)"
	[ -n "$line" ] && printf '%s\n' "$line"
done
exit 0
FAKE
chmod +x "$HOME/bin/fzf"
# clipboard tools that record what they are given
for tool in pbcopy xclip xsel wl-copy; do
	printf '#!/bin/sh\ncat >"$HOME/clip.out"\n' >"$HOME/bin/$tool"
	chmod +x "$HOME/bin/$tool"
done
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_FZF_PICKS=""

nl='
'
tab="$(printf '\t')"
B="$SHELL_FZF_BACK_LABEL"
reset_fzf() {
	find "$HOME" -maxdepth 1 \( -name 'stdin.*' -o -name 'args.*' \) -delete
	rm -f "$FAKE_FZF_STATE"
}
picks() {
	local first="true" rec
	for rec in "$@"; do
		if [ "$first" = "false" ]; then printf -- '---\n'; fi
		first="false"
		printf '%s\n' "$rec"
	done
}
# run <picks> <function...> -> output, then RC=<n> (stdin is empty, so a prompt sees EOF)
run() {
	local p="$1"
	shift
	reset_fzf
	FAKE_FZF_PICKS="$p" "$@" 2>&1 </dev/null
	echo "RC=$?"
}
calls() { cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0; }
lines() { wc -l <"$1" | tr -d ' '; }
args_of() { cat "$HOME/args.$1"; }
rows_of() { cat "$HOME/stdin.$1"; }

# --- namespace list ---------------------------------------------------------------------------------------
out="$(run "$(picks "os (" "$B")" shell::function::explore --interactive)"
t_has "explore: exit 0" "RC=0" "$out"
t_has "explore: starts with the namespaces: all functions first" "all${tab}All functions (" "$(head -n 1 "$HOME/stdin.1")"
t_eq "explore: ...the back row is last" "@back${tab}$B" "$(tail -n 1 "$HOME/stdin.1")"
t_has "explore: ...with the function count of each namespace" "git${tab}git (" "$(rows_of 1)"
t_eq "explore: ...one row per namespace (+ all + back)" "$(($(shell::function::list --namespaces | wc -l | tr -d ' ') + 2))" "$(lines "$HOME/stdin.1")"
t_eq "explore: ...counts agree with the plain list" "$(shell::function::list --namespaces | awk '$1 == "os" { print $2 }')" "$(grep "^os${tab}" "$HOME/stdin.1" | sed -E 's/.*\(([0-9]+)\)/\1/')"
t_has "explore: the namespace list previews its functions" "--preview=awk" "$(args_of 1)"
t_has "explore: ...on the right" "--preview-window=right:60%:wrap" "$(args_of 1)"
t_has "explore: only the label is shown and searched" "--with-nth=2" "$(args_of 1)"
t_has "explore: then the functions of that namespace" "shell::os::type" "$(rows_of 2)"
t_eq "explore: ...only that namespace (+ back)" "$(($(shell::function::list --names -c os | wc -l | tr -d ' ') + 1))" "$(lines "$HOME/stdin.2")"
t_lacks "explore: ...no other namespace" "shell::git::" "$(rows_of 2)"
t_eq "explore: the function rows have 8 fields (7 hidden + display)" "8" "$(head -n 1 "$HOME/stdin.2" | awk -F'\t' '{ print NF }')"
t_has "explore: the display is the name and the description" "shell::os::type  " "$(grep '^shell::os::type	' "$HOME/stdin.2" | cut -f8)"
t_has "explore: ...searchable by either (the display field is shown)" "--with-nth=8" "$(args_of 2)"
t_has "explore: the preview is the shared script" "--preview=sh \"\$SHELL_FUNCTION_PREVIEW_SH\" {1} {2} {3} {4} {5} {6} {7}" "$(args_of 2)"
t_has "explore: ...on the right" "--preview-window=right:50%:wrap" "$(args_of 2)"
t_has "explore: the prompt names the namespace" "--prompt=Function (os): " "$(args_of 2)"
t_has "explore: the header says nothing runs on Enter" "nothing runs until you choose Run" "$(args_of 2)"
t_eq "explore: the back row of the function list" "@back${tab}-${tab}-${tab}-${tab}0${tab}0${tab}-${tab}$B" "$(tail -n 1 "$HOME/stdin.2")"
t_eq "explore: no internal helper unless asked" "0" "$(grep -c '^_shell::' "$HOME/stdin.2")"

# the preview script, run the way fzf runs it
prev_row="$(grep '^shell::os::type	' "$HOME/stdin.2")"
prev() { # prev <row>: run the preview script with the row's hidden fields
	local n v l f s d r
	IFS="$tab" read -r n v l f s d r _ <<EOP
$1
EOP
	SHELL_FUNCTION_DOC_AWK="$SHELL_FUNCTION_DOC_AWK" sh "$SHELL_FUNCTION_PREVIEW_SH" "$n" "$v" "$l" "$f" "$s" "$d" "$r"
}
pv="$(prev "$prev_row")"
t_has "preview: the name" "shell::os::type" "$pv"
t_has "preview: the description" "Print the normalised operating-system name." "$pv"
t_has "preview: where it lives" "src/core/os.sh" "$pv"
t_has "preview: its examples" "EXAMPLES" "$pv"
t_has "preview: the back row" "Go back" "$(prev "@back${tab}-${tab}-${tab}-${tab}0${tab}0${tab}-${tab}x")"
t_has "preview: a function with no source" "not defined in the library's source tree" "$(prev "shell::x::y${tab}public${tab}yes${tab}-${tab}0${tab}0${tab}-${tab}x")"
t_has "preview: a function with no documentation block" "no documentation block" "$(prev "shell::x::y${tab}public${tab}yes${tab}$SHELL_DIR/src/shell.sh${tab}7${tab}7${tab}src/shell.sh${tab}x")"

# --- navigation: cancel, back -------------------------------------------------------------------------------
out="$(run "" shell::function::explore --interactive)"
t_has "explore: ESC at the namespaces closes" "RC=0" "$out"
t_eq "explore: ...after one screen" "1" "$(calls)"
out="$(run "$(picks "$B")" shell::function::explore --interactive)"
t_has "explore: Back at the namespaces" "RC=11" "$out"
out="$(run "$(picks "os (")" shell::function::explore --interactive)"
t_has "explore: ESC at the functions closes" "RC=0" "$out"
out="$(run "$(picks "os (" "$B" "$B")" shell::function::explore --interactive)"
t_has "explore: Back at the functions returns to the namespaces (shown again)" "RC=11" "$out"
t_eq "explore: ...the same list" "$(rows_of 1)" "$(rows_of 3)"
t_has "explore: ...with the cursor on the namespace left" "--bind=start:pos(" "$(args_of 3)"
t_eq "explore: ...three screens in all" "3" "$(calls)"

# --- starting inside a namespace or a search -----------------------------------------------------------------
out="$(run "$(picks "$B")" shell::function::explore --interactive git)"
t_has "explore git: opens that namespace" "--prompt=Function (git): " "$(args_of 1)"
t_has "explore git: Back leaves (there is no namespace list to return to)" "RC=11" "$out"
t_eq "explore git: one screen" "1" "$(calls)"
run "" shell::function::explore --interactive -c ssh >/dev/null
t_has "explore -c ssh" "--prompt=Function (ssh): " "$(args_of 1)"
run "" shell::function::explore --interactive --namespace=ssh >/dev/null
t_has "explore --namespace=ssh" "--prompt=Function (ssh): " "$(args_of 1)"
run "" shell::function::explore --interactive pick commit >/dev/null
t_has "explore: words that are not a namespace are the initial search" "--query=pick commit" "$(args_of 1)"
t_has "explore: ...over all functions" "--prompt=Function: " "$(args_of 1)"
t_has "explore: ...in the function list" "shell::git::commit::pick::fzf" "$(rows_of 1)"
run "" shell::function::explore --interactive git::commit >/dev/null
t_has "explore: a nested namespace opens too" "--prompt=Function (git::commit): " "$(args_of 1)"
run "" shell::function::explore --interactive -i -c function >/dev/null
t_has "explore -i: internal helpers are included" "_shell::function::catalog" "$(rows_of 1)"
t_has "explore -i: ...with the public ones" "shell::function::explore" "$(rows_of 1)"
out="$(run "" shell::function::explore --interactive --unloaded)"
t_has "explore --unloaded: nothing to explore when everything is loaded" "RC=8" "$out"
t_eq "explore: ...and no screen was shown" "0" "$(calls)"
t_rc "explore: missing value" 2 shell::function::explore -c
t_rc "explore: unknown option" 2 shell::function::explore --interactive --bogus

# --- the action menu: nothing runs by itself ---------------------------------------------------------------
shell::zzdemo::boom() { : >"$HOME/boom"; }
shell::zzdemo::cd() {
	cd "$HOME/sub" || return 1
	ZZ_VAR="set-by-the-function"
	printf '%s|' "$@" >"$HOME/zz.args"
}
shell::zzdemo::help() { [ "${1-}" = "-h" ] && echo "HELP-OF-ZZDEMO"; }
mkdir "$HOME/sub"
t_has "demo: a function defined in the shell is explored" "shell::zzdemo::boom" "$(shell::function::list --names -c zzdemo)"

out="$(run "$(picks "zzdemo (" "shell::zzdemo::boom")" shell::function::explore --interactive)"
t_eq "action: choosing a function does not run it" "no" "$([ -e "$HOME/boom" ] && echo yes || echo no)"
out="$(run "$(picks "zzdemo (" "shell::zzdemo::boom" "Show details")" shell::function::explore --interactive)"
t_eq "action: the menu of a function" "Show details${nl}Run it...${nl}Show its own help (-h)${nl}Copy the name${nl}$B" "$(rows_of 3)"
t_has "action: the menu is titled with the function" "--prompt=shell::zzdemo::boom: " "$(args_of 3)"
t_has "action: Show details shows the page" "shell::zzdemo::boom" "$out"
t_has "action: ...which says where it came from" "no documentation" "$out"
t_eq "action: ...and still runs nothing" "no" "$([ -e "$HOME/boom" ] && echo yes || echo no)"
t_has "action: then the list comes back" "RC=0" "$out"
t_eq "action: ...as a fourth screen" "4" "$(calls)"
t_has "action: ...with the cursor on the function" "--bind=start:pos(" "$(args_of 4)"
out="$(run "$(picks "zzdemo (" "shell::zzdemo::boom" "$B")" shell::function::explore --interactive)"
t_eq "action: Back from the menu runs nothing" "no" "$([ -e "$HOME/boom" ] && echo yes || echo no)"
out="$(run "$(picks "zzdemo (" "shell::zzdemo::help" "Show its own help")" shell::function::explore --interactive)"
t_has "action: its own help" "HELP-OF-ZZDEMO" "$out"
rm -f "$HOME/clip.out"
out="$(run "$(picks "zzdemo (" "shell::zzdemo::boom" "Copy the name")" shell::function::explore --interactive)"
t_eq "action: copy the name" "shell::zzdemo::boom" "$(cat "$HOME/clip.out" 2>/dev/null)"

# --- Run: explicit, confirmed, in the current shell ---------------------------------------------------------
# runin <picks> <stdin file> <output file>: the explorer in THIS shell (no subshell), prompts read the file
runin() {
	reset_fzf
	FAKE_FZF_PICKS="$1" shell::function::explore --interactive >"$3" 2>&1 <"$2"
}
cd "$HOME" || exit 1
printf '%s\n' 'one "two words"' y >"$HOME/in.txt"
runin "$(picks "zzdemo (" "shell::zzdemo::cd" "Run it...")" "$HOME/in.txt" "$HOME/run.out"
reset_rc=$?
t_eq "run: exit 0" "0" "$reset_rc"
t_eq "run: the arguments reach the function, quoting intact" "one|two words|" "$(cat "$HOME/zz.args" 2>/dev/null)"
t_eq "run: it ran in the current shell: the directory changed" "$HOME/sub" "$PWD"
t_eq "run: ...and the variable it set is here" "set-by-the-function" "${ZZ_VAR-}"
t_has "run: the usage is shown first" "shell::zzdemo::cd" "$(cat "$HOME/run.out")"
t_has "run: the command line is shown for confirmation" "Run: shell::zzdemo::cd one \"two words\"" "$(cat "$HOME/run.out")"
t_has "run: the exit status is reported" "Exit status: 0" "$(cat "$HOME/run.out")"
cd "$HOME" || exit 1
ZZ_VAR=""
rm -f "$HOME/zz.args"
printf '\n' >"$HOME/in.txt"
printf 'y\n' >>"$HOME/in.txt"
runin "$(picks "zzdemo (" "shell::zzdemo::cd" "Run it...")" "$HOME/in.txt" /dev/null
t_eq "run: no arguments is fine" "|" "$(cat "$HOME/zz.args" 2>/dev/null | tr -d '\n' | sed 's/^$/|/')"
cd "$HOME" || exit 1
rm -f "$HOME/zz.args"
printf 'x\nn\n' >"$HOME/in.txt"
runin "$(picks "zzdemo (" "shell::zzdemo::cd" "Run it...")" "$HOME/in.txt" "$HOME/run.out"
t_eq "run: answering no does not run it" "no" "$([ -e "$HOME/zz.args" ] && echo yes || echo no)"
t_has "run: ...and says so" "Not run" "$(cat "$HOME/run.out")"
runin "$(picks "zzdemo (" "shell::zzdemo::cd" "Run it...")" /dev/null "$HOME/run.out"
t_eq "run: Ctrl-D at the arguments cancels" "no" "$([ -e "$HOME/zz.args" ] && echo yes || echo no)"
printf 'a; touch %s/injected\ny\n' "$HOME" >"$HOME/in.txt"
runin "$(picks "zzdemo (" "shell::zzdemo::cd" "Run it...")" "$HOME/in.txt" /dev/null
t_eq "run: the line is the user's own command line (a second command is theirs)" "yes" "$([ -e "$HOME/injected" ] && echo yes || echo no)"
cd "$HOME" || exit 1
unset -f shell::zzdemo::boom shell::zzdemo::cd shell::zzdemo::help

# --- fzf is optional --------------------------------------------------------------------------------------
reset_fzf
out="$(shell::function::explore git::commit::pick 2>&1)"
t_has "auto: without a terminal the plain list is printed" "shell::git::commit::pick::fzf" "$out"
t_eq "auto: ...fzf was not used" "0" "$(calls)"
out="$(shell::help --plain os::type 2>&1)"
t_has "help --plain" "shell::os::type" "$out"
nofzf="$HOME/nofzf"
mkdir "$nofzf"
for t in awk sed find sort tr cut grep wc mktemp rm head tail cat uname mkdir dirname basename date tput stty sh; do
	p="$(command -v "$t" 2>/dev/null)"
	case "$p" in /*) ln -s "$p" "$nofzf/$t" ;; esac
done
save_path="$PATH"
PATH="$nofzf"
t_eq "no fzf: really not found" "no" "$(command -v fzf >/dev/null 2>&1 && echo yes || echo no)"
out="$(shell::function::explore --interactive os::type 2>&1)"
rc=$?
PATH="$save_path"
t_has "no fzf: a note that it is optional" "fzf is not installed (it is optional)" "$out"
t_has "no fzf: the plain list instead" "shell::os::type" "$out"
t_eq "no fzf: exit 0" "0" "$rc"

t_done
