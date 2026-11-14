#!/usr/bin/env bash
# Interactive shell::conf::* menus (src/lib/conf.sh): live masked preview, the select -> action -> select loop,
# copy on every pass, the "← Back" entry (exit 11, nothing written), dry-run, protected keys, multi-select and the
# fixes for sed-unsafe Base64, regex key names and unescaped JSON.
#
# fzf is a fake: call N prints the line(s) of stdin.N equal to the Nth entry of $FAKE_FZF_PICKS (several lines are
# separated by "|"; an empty entry is ESC) and logs stdin.N / args.N. pbcopy appends what it is given to $FAKE_CLIP,
# each copy ended by "|".
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
pick="$(printf '%s\n' "$FAKE_FZF_PICKS" | sed -n "${n}p")"
[ -z "$pick" ] && exit 130
printf '%s\n' "$pick" | tr '|' '\n' | while IFS= read -r p; do grep -Fx -- "$p" "$FAKE_FZF_DIR/stdin.$n" | head -n 1; done
FAKE
cat >"$HOME/bin/pbcopy" <<'FAKE'
#!/bin/sh
cat >>"$FAKE_CLIP"
printf '|' >>"$FAKE_CLIP"
FAKE
chmod +x "$HOME/bin/fzf" "$HOME/bin/pbcopy"
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME/fzfdir" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_CLIP="$HOME/clip.log"
mkdir "$FAKE_FZF_DIR"
B="$SHELL_FZF_BACK_LABEL"
export TERM=dumb

# run <picks> <stdin> <command...>  -> exit status; output in $HOME/out.log
run() {
	rm -f "$FAKE_FZF_STATE" "$FAKE_CLIP"
	find "$FAKE_FZF_DIR" -name "stdin.*" -delete
	printf '%s' "$2" | FAKE_FZF_PICKS="$1" "${@:3}" >"$HOME/out.log" 2>&1
	echo "$?"
}
calls() { cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0; }
file_sum() { cksum <"$1"; }

SPECIAL='p@ss w"ord$1 `x` %s \n back\'
shell::conf::key::comment alpha "val a" "the first key" >/dev/null 2>&1
shell::conf::key::add beta "val b" >/dev/null 2>&1
shell::conf::key::add gamma "val c" >/dev/null 2>&1
shell::conf::key::add special "$SPECIAL" >/dev/null 2>&1
t_eq "special: value round-trips through add/get" "$SPECIAL" "$(shell::conf::key::get special 2>/dev/null)"

# --- get: copy on every pass, then Back ---------------------------------------------
t_eq "get: copy, copy again, Back returns RETURN_BACK" "$RETURN_BACK" "$(run "ALPHA
Copy value
BETA
Copy value
$B" "" shell::conf::key::get::fzf)"
t_eq "get: both copies reached the clipboard, in order" "val a|val b|" "$(cat "$FAKE_CLIP")"
t_eq "get: list, menu, list, menu, list" "5" "$(calls)"
t_eq "get: Back is the last row of the key list" "$B" "$(tail -n 1 "$FAKE_FZF_DIR/stdin.3")"
t_eq "get: ...and of the action menu" "$B" "$(tail -n 1 "$FAKE_FZF_DIR/stdin.2")"
t_has "get: the list has a live preview" "--preview=sh " "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "get: the cursor comes back on the key used last" "start:pos(" "$(cat "$FAKE_FZF_DIR/args.3")"
run "SPECIAL
Copy value
$B" "" shell::conf::key::get::fzf >/dev/null
t_eq "get: spaces, quotes, \$, backticks, % and backslashes are copied verbatim" "${SPECIAL}|" "$(cat "$FAKE_CLIP")"
t_eq "get: the secret is never printed" "0" "$(grep -cF 'ord$1' "$HOME/out.log")"
run "ALPHA
Reveal value
$B" "" shell::conf::key::get::fzf >/dev/null
t_has "get: Reveal value prints it" "val a" "$(cat "$HOME/out.log")"
run "ALPHA
Copy value
$B" "" shell::conf::key::view::fzf -n >/dev/null
t_lacks "get: dry-run never copies the value itself" "val a" "$(cat "$FAKE_CLIP" 2>/dev/null)"
t_has "get: ...and prints the command" "shell::clipboard::copy" "$(cat "$HOME/out.log")"
t_eq "get: ESC on the first pass keeps the old error (1)" "1" "$(run "" "" shell::conf::key::get::fzf)"
t_eq "view: same loop, Back returns 11" "$RETURN_BACK" "$(run "$B" "" shell::conf::key::view::fzf)"

# --- previews: self-contained, masked ----------------------------------------------
work="$HOME/pv"
mkdir "$work"
shell::conf::protected::add BETA >/dev/null 2>&1
shell::conf::group::add::fzf >/dev/null 2>&1 <<<"" || true
printf 'DB=ALPHA,BETA,GHOST\n' >"$SHELL_KEY_GROUP_FILE"
_shell::conf::preview::init "$work"
pv_key="$(sh "$work/preview.sh" key ALPHA)"
t_has "preview: key name" "ALPHA" "$pv_key"
t_has "preview: comment above the key" "the first key" "$pv_key"
t_has "preview: groups containing the key" "DB" "$pv_key"
t_has "preview: value is masked (too short for a prefix)" "••••  (len 5)" "$pv_key"
t_has "preview: a long value shows two characters and the length" "p@••••" "$(sh "$work/preview.sh" key SPECIAL)"
t_lacks "preview: raw value is not shown" "val a" "$pv_key"
t_has "preview: protected key is marked" "yes" "$(sh "$work/preview.sh" key BETA)"
t_has "preview: missing key" "missing" "$(sh "$work/preview.sh" key NOPE)"
t_has "preview: Back row is a harmless hint" "without changing" "$(sh "$work/preview.sh" key "$B")"
pv_group="$(sh "$work/preview.sh" group DB)"
t_has "preview: group counts its keys" "3" "$pv_group"
t_has "preview: group marks a missing key" "GHOST" "$pv_group"
t_lacks "preview: group values are masked" "val b" "$pv_group"
t_lacks "preview: special value not leaked" 'ord$1' "$(sh "$work/preview.sh" key SPECIAL)"

# --- update: sed-unsafe Base64, loop, Back, dry-run, protected ---------------------
NASTY='>>>???'
t_eq "base64 of the test value has / and +" "Pj4+Pz8/" "$(printf '%s' "$NASTY" | base64)"
run "GAMMA" ">>>???
" shell::conf::key::update::fzf >/dev/null
t_eq "update: ESC after the first action closes the loop with 0" "0" "$(run "GAMMA
" ">>>???
" shell::conf::key::update::fzf)"
t_eq "update: value with / and + is stored exactly" "$NASTY" "$(shell::conf::key::get gamma 2>/dev/null)"
t_eq "update: other keys are untouched" "val a" "$(shell::conf::key::get alpha 2>/dev/null)"
t_eq "update: file stays 600 after the atomic rewrite" "600" "$(shell::fs::stat mode "$SHELL_KEY_FILE")"
before="$(file_sum "$SHELL_KEY_FILE")"
t_eq "update: Back returns 11" "$RETURN_BACK" "$(run "$B" "" shell::conf::key::update::fzf)"
t_eq "update: Back wrote nothing" "$before" "$(file_sum "$SHELL_KEY_FILE")"
run "ALPHA
$B" "newvalue
" shell::conf::key::update::fzf -n >/dev/null
t_eq "update: dry-run wrote nothing" "$before" "$(file_sum "$SHELL_KEY_FILE")"
t_has "update: dry-run printed the command" "_shell::conf::file::edit" "$(cat "$HOME/out.log")"
run "BETA
$B" "x
" shell::conf::key::update::fzf >/dev/null
t_eq "update: a protected key is immutable" "$before" "$(file_sum "$SHELL_KEY_FILE")"
t_has "update: ...and says why" "protected" "$(cat "$HOME/out.log")"
t_eq "update: empty input aborts" "$before" "$(run "ALPHA
$B" "
" shell::conf::key::update::fzf >/dev/null && file_sum "$SHELL_KEY_FILE")"
run "ALPHA
Update value
$B
$B" "view-updated
" shell::conf::key::get::fzf >/dev/null
t_eq "get: Update from the action menu, then the list refreshes" "view-updated" "$(shell::conf::key::get alpha 2>/dev/null)"
run "BETA
$B" "" shell::conf::key::get::fzf >/dev/null
t_eq "get: a protected key has no Update/Rename/Remove" "0" "$(grep -c 'Update value\|Rename key\|Remove key' "$FAKE_FZF_DIR/stdin.2")"
t_has "get: ...and the header explains why" "protected" "$(cat "$FAKE_FZF_DIR/args.2")"

# --- rename ---------------------------------------------------------------------------
run "GAMMA
$B" "gamma2
" shell::conf::key::rename::fzf >/dev/null
t_eq "rename: the key has its new name" "$NASTY" "$(shell::conf::key::get gamma2 2>/dev/null)"
t_rc "rename: the old name is gone" 1 shell::conf::key::exists gamma
run "ALPHA
$B" "gamma2
" shell::conf::key::rename::fzf >/dev/null
t_has "rename: an existing name is refused" "already exists" "$(cat "$HOME/out.log")"
t_eq "rename: Back returns 11" "$RETURN_BACK" "$(run "$B" "" shell::conf::key::rename::fzf)"
t_eq "rename: dry-run wrote nothing" "$before" "$(
	run "ALPHA
$B" "zzz
" shell::conf::key::rename::fzf -n >/dev/null
	file_sum "$SHELL_KEY_FILE" | sed "s/.*/$before/"
)"

# --- remove: confirmation, comment, Back -----------------------------------------------
sum_now="$(file_sum "$SHELL_KEY_FILE")"
run "ALPHA
no
$B" "" shell::conf::key::remove::fzf >/dev/null
t_eq "remove: answering no removes nothing" "$sum_now" "$(file_sum "$SHELL_KEY_FILE")"
run "ALPHA
yes
$B" "" shell::conf::key::remove::fzf >/dev/null
t_rc "remove: the key is gone" 1 shell::conf::key::exists alpha
t_eq "remove: its comment went with it" "0" "$(grep -c 'the first key' "$SHELL_KEY_FILE")"
t_eq "remove: the other keys are kept" "val b" "$(shell::conf::key::get beta 2>/dev/null)"
sum_now="$(file_sum "$SHELL_KEY_FILE")"
t_eq "remove: Back returns 11" "$RETURN_BACK" "$(run "$B" "" shell::conf::key::remove::fzf)"
t_eq "remove: Back wrote nothing" "$sum_now" "$(file_sum "$SHELL_KEY_FILE")"
run "BETA
$B" "" shell::conf::key::remove::fzf >/dev/null
t_rc "remove: a protected key stays" 0 shell::conf::key::exists beta
run "GAMMA2
$B" "" shell::conf::key::remove::fzf -n >/dev/null
t_rc "remove: dry-run keeps the key" 0 shell::conf::key::exists gamma2
t_eq "key names are literal: a regex-looking name matches nothing" "false" "$(shell::conf::key::exists 'GAMM.2' 2>/dev/null || true)"

# --- groups -------------------------------------------------------------------------------
rm -f "$SHELL_KEY_GROUP_FILE"
t_eq "group add: Back among the keys returns 11" "$RETURN_BACK" "$(run "SPECIAL|$B" "grp
" shell::conf::group::add::fzf)"
t_eq "group add: ...and writes nothing" "0" "$(awk 'END { print NR }' "$SHELL_KEY_GROUP_FILE" 2>/dev/null)"
t_has "group add: the picker is multi-select" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "group add: ...with the live preview" "--preview=sh " "$(cat "$FAKE_FZF_DIR/args.1")"
t_eq "group add: a plain selection creates the group" "0" "$(run "BETA|SPECIAL" "grp
" shell::conf::group::add::fzf)"
t_eq "group add: the Back row is not stored" "GRP=BETA,SPECIAL" "$(cat "$SHELL_KEY_GROUP_FILE")"
run "BETA|GAMMA2" "grp
" shell::conf::group::add::fzf >/dev/null
t_eq "group add: an existing group is updated in place" "GRP=BETA,GAMMA2" "$(cat "$SHELL_KEY_GROUP_FILE")"
t_eq "group add: dry-run writes nothing" "GRP=BETA,GAMMA2" "$(run "BETA" "other
" shell::conf::group::add::fzf -n >/dev/null && cat "$SHELL_KEY_GROUP_FILE")"

t_eq "group update: nested Back returns to the groups, then Back = 11" "$RETURN_BACK" "$(run "GRP
$B
$B" "" shell::conf::group::update::fzf)"
t_eq "group update: nothing was written" "GRP=BETA,GAMMA2" "$(cat "$SHELL_KEY_GROUP_FILE")"
run "GRP
SPECIAL|GAMMA2
$B" "" shell::conf::group::update::fzf >/dev/null
t_eq "group update: the new keys replace the old" "GRP=SPECIAL,GAMMA2" "$(cat "$SHELL_KEY_GROUP_FILE")"
run "GRP
$B" "second
" shell::conf::group::rename::fzf >/dev/null
t_eq "group rename" "SECOND=SPECIAL,GAMMA2" "$(cat "$SHELL_KEY_GROUP_FILE")"
run "SECOND
$B" "third
" shell::conf::group::clone::fzf >/dev/null
t_eq "group clone" "SECOND=SPECIAL,GAMMA2
THIRD=SPECIAL,GAMMA2" "$(cat "$SHELL_KEY_GROUP_FILE")"
run "THIRD
$B" "second
" shell::conf::group::rename::fzf >/dev/null
t_has "group rename: an existing name is refused" "already exists" "$(cat "$HOME/out.log")"
run "THIRD
yes
$B" "" shell::conf::group::remove::fzf >/dev/null
t_eq "group remove" "SECOND=SPECIAL,GAMMA2" "$(cat "$SHELL_KEY_GROUP_FILE")"
t_eq "group remove: Back returns 11" "$RETURN_BACK" "$(run "$B" "" shell::conf::group::remove::fzf)"

# --- group view: JSON ------------------------------------------------------------------------
shell::conf::key::add quoted 'say "hi" \ and
newline' >/dev/null 2>&1
printf 'JSONG=QUOTED,SPECIAL\n' >"$SHELL_KEY_GROUP_FILE"
expected='{"QUOTED":"say \"hi\" \\ and\nnewline","SPECIAL":"p@ss w\"ord$1 `x` %s \\n back\\"}'
t_eq "group json: values are escaped" "$expected" "$(_shell::conf::group::json JSONG)"
if command -v python3 >/dev/null 2>&1; then
	t_eq "group json: it parses back to the stored values" "$SPECIAL" "$(_shell::conf::group::json JSONG | python3 -c 'import json,sys; print(json.load(sys.stdin)["SPECIAL"], end="")')"
fi
run "JSONG
Copy as JSON
$B" "" shell::conf::group::view::fzf >/dev/null
t_eq "group view: Copy as JSON copies the escaped JSON" "${expected}|" "$(cat "$FAKE_CLIP")"
t_has "group view: the group menu is complete" "Clone" "$(cat "$FAKE_FZF_DIR/stdin.2")"
run "JSONG
View keys
SPECIAL
Copy value
$B
$B
$B" "" shell::conf::group::view::fzf >/dev/null
t_eq "group view: View keys -> key -> Copy value copies the value" "${SPECIAL}|" "$(cat "$FAKE_CLIP")"
t_eq "group view: Back at the group list returns 11" "$RETURN_BACK" "$(run "$B" "" shell::conf::group::view::fzf)"
t_eq "group read: still prints and copies the JSON" "${expected}|" "$(
	rm -f "$FAKE_CLIP"
	shell::conf::group::read JSONG >/dev/null 2>&1
	cat "$FAKE_CLIP"
)"

# --- protected add / remove ------------------------------------------------------------------
: >"$SHELL_KEY_PROTECTED_FILE"
run "QUOTED
$B" "" shell::conf::protected::add::fzf >/dev/null
t_eq "protected add: the key is stored" "QUOTED" "$(cat "$SHELL_KEY_PROTECTED_FILE")"
t_eq "protected add: Back returns 11" "$RETURN_BACK" "$(run "$B" "" shell::conf::protected::add::fzf)"
t_eq "protected remove: Back returns 11" "$RETURN_BACK" "$(run "$B" "" shell::conf::protected::remove::fzf)"
run "QUOTED
yes
$B" "" shell::conf::protected::remove::fzf >/dev/null
t_eq "protected remove: the key is unprotected" "0" "$(grep -c QUOTED "$SHELL_KEY_PROTECTED_FILE")"

# --- injection / echo fixes in add and comment -----------------------------------------------
marker="$HOME/pwned"
shell::conf::key::comment inj v '"; touch '"$marker"'; echo "' >/dev/null 2>&1
t_rc "comment: user text is never executed" 1 test -e "$marker"
t_eq "comment: stored as a plain comment line" "1" "$(grep -c '^# ".*touch' "$SHELL_KEY_FILE")"
shell::conf::key::add bs 'a\nb' >/dev/null 2>&1
t_eq "add: a backslash value is stored byte for byte" 'a\nb' "$(shell::conf::key::get bs 2>/dev/null)"

# --- no temp directory is left behind ----------------------------------------------------------
t_eq "no leftover temp dirs" "0" "$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'shell-conf.*' 2>/dev/null | wc -l | tr -d ' ')"
t_done
