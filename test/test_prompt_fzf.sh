#!/usr/bin/env bash
# Interactive shell::prompt::*::fzf menus (src/lib/prompt_fzf.sh): the list -> action -> list loop, copy on every pass,
# the "← Back" entry (exit 11, nothing written), the edit flow (snapshot, validation, atomic save), history/restore,
# tags, search reload, the hub, dry-run, the preview script and temp-dir cleanup.
#
# fzf is a fake: call N reads line N of $FAKE_FZF_PICKS. A pick is `[key::]text`: the first stdin line equal to (or
# containing) `text` is printed, preceded by `key` when fzf was given --expect. An empty line is ESC. stdin.N and args.N
# are logged. pbcopy appends what it gets to $FAKE_CLIP, each copy ended by "|". The editor is $HOME/bin/fake-editor.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

mkdir "$HOME/bin" "$HOME/tmp"
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
n="$(cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0)"
n=$((n + 1))
echo "$n" >"$FAKE_FZF_STATE"
cat >"$FAKE_FZF_DIR/stdin.$n"
printf '%s\n' "$@" >"$FAKE_FZF_DIR/args.$n"
pick="$(printf '%s\n' "$FAKE_FZF_PICKS" | sed -n "${n}p")"
[ -z "$pick" ] && exit 130
key=""
case "$pick" in *'::'*) key="${pick%%::*}"; pick="${pick#*::}" ;; esac
expect=0
cmd=""
for a in "$@"; do
	case "$a" in
	--expect=*) expect=1 ;;
	--bind=change:reload:*) cmd="${a#--bind=change:reload:}" ;;
	esac
done
if [ -n "$FAKE_RELOAD" ] && [ -n "$cmd" ]; then
	eval "$(printf '%s' "$cmd" | sed "s/{q}/'$FAKE_RELOAD'/")" >"$FAKE_FZF_DIR/reload.$n"
fi
[ "$expect" = 1 ] && printf '%s\n' "$key"
printf '%s\n' "$pick" | tr '|' '\n' | while IFS= read -r p; do
	line="$(grep -Fx -- "$p" "$FAKE_FZF_DIR/stdin.$n" | head -n 1)"
	[ -z "$line" ] && line="$(grep -F -- "$p" "$FAKE_FZF_DIR/stdin.$n" | head -n 1)"
	printf '%s\n' "$line"
done
FAKE
cat >"$HOME/bin/pbcopy" <<'FAKE'
#!/bin/sh
cat >>"$FAKE_CLIP"
printf '|' >>"$FAKE_CLIP"
FAKE
# Editor: FAKE_ED_MODE = append | none | break | brokenthenfix
cat >"$HOME/bin/fake-editor" <<'FAKE'
#!/bin/sh
f="$1"
case "$FAKE_ED_MODE" in
append) printf 'EDITED $VAR `x` "q" %%s\n' >>"$f" ;;
none) : ;;
break) grep -v '^title:' "$f" >"$f.new" && mv "$f.new" "$f" ;;
brokenthenfix)
	n="$(cat "$FAKE_ED_STATE" 2>/dev/null || echo 0)"
	echo $((n + 1)) >"$FAKE_ED_STATE"
	if [ "$n" = 0 ]; then grep -v '^title:' "$f" >"$f.new" && mv "$f.new" "$f"; else printf -- '---\ntitle: Fixed Title\n---\nfixed body\n' >"$f"; fi
	;;
esac
FAKE
cat >"$HOME/bin/bat" <<'FAKE'
#!/bin/sh
cat
FAKE
chmod +x "$HOME/bin/fzf" "$HOME/bin/pbcopy" "$HOME/bin/fake-editor" "$HOME/bin/bat"
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME/fzfdir" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_CLIP="$HOME/clip.log" FAKE_ED_STATE="$HOME/ed.count"
export EDITOR="$HOME/bin/fake-editor" VISUAL="" TMPDIR="$HOME/tmp" TERM=dumb
export SHELL_PROMPT_DIR="$HOME/store"
mkdir "$FAKE_FZF_DIR"
B="$SHELL_FZF_BACK_LABEL"
G="$SHELL_PROMPT_DIR"

# run <picks> <stdin> <command...> -> exit status; output in $HOME/out.log
run() {
	rm -f "$FAKE_FZF_STATE" "$FAKE_CLIP" "$FAKE_ED_STATE"
	find "$FAKE_FZF_DIR" -type f -delete
	printf '%s' "$2" | FAKE_FZF_PICKS="$1" "${@:3}" >"$HOME/out.log" 2>&1
	echo "$?"
}
calls() { cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0; }
clip() { cat "$FAKE_CLIP" 2>/dev/null; }
sum_dir() { (cd "$1" && find . -type f | LC_ALL=C sort | xargs cksum 2>/dev/null); }
mode_of() { stat -f %Lp "$1" 2>/dev/null || stat -c %a "$1"; }
out() { cat "$HOME/out.log"; }

SPECIAL='You are "strict" $HOME `date` %s \n back\slash & é 日本 {not}'
printf '%s\n\nsecond line\n\n' "$SPECIAL" >"$HOME/body.txt"
shell::prompt::add -t "review,bash" -d "Strict reviewer" "Code Review" "$HOME/body.txt" >/dev/null 2>&1
printf 'Hello {{who|world}}, tone {{tone|polite}}.\n' | shell::prompt::add -t "writing" "Greeting" - >/dev/null 2>&1
printf 'need {{required}}\n' | shell::prompt::add "Needs" - >/dev/null 2>&1
BODY_SUM="$(cksum <"$HOME/body.txt")"

# --- Back: exit 11, nothing mutated ----------------------------------------
before="$(sum_dir "$G")"
for fn in view edit search tag manage; do
	t_eq "$fn::fzf: Back returns 11" "11" "$(run "$B" "" "shell::prompt::$fn::fzf")"
	t_eq "$fn::fzf: Back asked fzf once" "1" "$(calls)"
done
t_eq "history::fzf: nothing to show yet returns Back, no fzf" "11" "$(run "$B" "" shell::prompt::history::fzf)"
t_eq "Back never mutates the store" "$before" "$(sum_dir "$G")"
run "$B" "" shell::prompt::view::fzf >/dev/null
t_eq "view: Back row is last" "$B	$B" "$(tail -n 1 "$FAKE_FZF_DIR/stdin.1")"
t_has "view: rows carry the [G] scope marker" "G/code-review	[G] code-review" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "view: --expect keys are passed" "--expect=ctrl-y,ctrl-r,ctrl-e,ctrl-d" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "view: header lists the key hints" "^Y copy" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "view: live preview command" "preview.sh" "$(cat "$FAKE_FZF_DIR/args.1")"
t_eq "ESC closes the loop with 0" "0" "$(run "" "" shell::prompt::view::fzf)"
t_eq "unknown option is rejected" "2" "$(run "" "" shell::prompt::view::fzf --nope)"

# --- copy works on every pass ------------------------------------------------
t_eq "Ctrl-Y twice then Back" "11" "$(run "ctrl-y::G/code-review
ctrl-y::G/code-review
$B" "" shell::prompt::view::fzf)"
t_eq "list came back after each copy" "3" "$(calls)"
c="$(clip)"
t_eq "two copies reached the clipboard" "2" "$(printf '%s' "$c" | tr -cd '|' | wc -c | tr -d ' ')"
first="${c%%|*}"
t_eq "clipboard text is byte-exact (quotes, \$, backticks, %, unicode, newlines)" "$BODY_SUM" "$(printf '%s' "$first" | cksum)"
t_lacks "copy never logs the body" "strict" "$(out)"
t_has "copy logs title and size" "Copied prompt 'Code Review'" "$(out)"

t_eq "Enter -> action menu -> Copy, twice" "11" "$(run "G/code-review
Copy
G/code-review
Copy
$B" "" shell::prompt::view::fzf)"
t_eq "action flow asked fzf 5 times" "5" "$(calls)"
t_eq "action menu ends with Back" "$B" "$(tail -n 1 "$FAKE_FZF_DIR/stdin.2")"
t_eq "action menu lists the actions" "Copy
Copy rendered
Edit
Open pager
Tags
History
Remove
$B" "$(cat "$FAKE_FZF_DIR/stdin.2")"
t_eq "action Copy: clipboard exact (twice)" "2" "$(printf '%s' "$(clip)" | tr -cd '|' | wc -c | tr -d ' ')"
t_eq "Back in the action menu just returns to the list" "11" "$(run "G/code-review
$B
$B" "" shell::prompt::view::fzf)"
t_eq "clipboard untouched by Back" "" "$(clip)"
t_eq "ESC in the action menu returns to the list" "11" "$(run "G/code-review

$B" "" shell::prompt::view::fzf)"

# dry-run copy: nothing reaches the clipboard but the command
run "ctrl-y::G/code-review
$B" "" shell::prompt::view::fzf -n >/dev/null
t_lacks "dry-run copy: the body is not on the clipboard" "strict" "$(clip)"
t_has "dry-run copy: the command is shown" "shell::clipboard::copy" "$(out)"

# no clipboard tool: the text is printed with a warning
mv "$HOME/bin/pbcopy" "$HOME/bin/pbcopy.off"
SAVED_PATH="$PATH"
PATH="$HOME/bin:/usr/bin:/bin"
if ! command -v xclip >/dev/null 2>&1 && ! command -v wl-copy >/dev/null 2>&1 && ! command -v xsel >/dev/null 2>&1 && ! command -v pbcopy >/dev/null 2>&1; then
	run "ctrl-y::G/greeting
$B" "" shell::prompt::view::fzf >/dev/null
	t_has "no clipboard tool: warns" "No clipboard tool found" "$(out)"
	t_has "no clipboard tool: prints the prompt instead" "Hello {{who|world}}" "$(out)"
fi
PATH="$SAVED_PATH"
mv "$HOME/bin/pbcopy.off" "$HOME/bin/pbcopy"

# --- copy rendered ------------------------------------------------------------
t_eq "Ctrl-R with defaults: preview, copy, back" "11" "$(run "ctrl-r::G/greeting
Copy to clipboard
$B" "" shell::prompt::view::fzf)"
t_eq "rendered text reached the clipboard" "Hello world, tone polite.
|" "$(clip)"
t_has "rendered preview file is offered" "head -c 20000" "$(cat "$FAKE_FZF_DIR/args.2")"
run "ctrl-r::G/greeting
$B
$B" "" shell::prompt::view::fzf >/dev/null
t_eq "cancelling the rendered preview copies nothing" "" "$(clip)"
t_has "cancel is reported" "nothing was copied" "$(out)"
run "ctrl-r::G/needs
$B" "" shell::prompt::view::fzf >/dev/null
t_eq "a placeholder without value cancels, copies nothing" "" "$(clip)"
run "ctrl-r::G/code-review
$B" "" shell::prompt::view::fzf >/dev/null
t_eq "no placeholders: copied as is" "$BODY_SUM" "$(printf '%s' "$(clip)" | sed 's/|$//' | cksum)"
t_has "no placeholders: says so" "No {{placeholders}}" "$(out)"

# --- edit flow ------------------------------------------------------------------
snaps() { shell::prompt::history "$1" 2>/dev/null | wc -l | tr -d ' '; }
FAKE_ED_MODE="append"
export FAKE_ED_MODE
s0="$(snaps code-review)"
upd0="$(_shell::prompt::meta "$G/code-review.md" updated)"
t_eq "Ctrl-E edits, then the list returns; Ctrl-Y copies the new text" "11" "$(run "ctrl-e::G/code-review
ctrl-y::G/code-review
$B" "" shell::prompt::view::fzf)"
t_has "edit: body changed" 'EDITED $VAR `x` "q" %s' "$(shell::prompt::get code-review)"
t_has "edit: copy after edit has the new body" 'EDITED $VAR' "$(clip)"
t_eq "edit: one snapshot added" "$((s0 + 1))" "$(snaps code-review)"
t_eq "edit: file is 600" "600" "$(mode_of "$G/code-review.md")"
t_eq "edit: title kept" "Code Review" "$(_shell::prompt::meta "$G/code-review.md" title)"
t_eq "edit: tags kept" "review,bash" "$(_shell::prompt::meta "$G/code-review.md" tags)"
t_eq "edit: created kept" "$(_shell::prompt::meta "$G/code-review.md" created)" "$(_shell::prompt::meta "$G/code-review.md" created)"
t_has "edit: updated refreshed (ISO)" "T" "$(_shell::prompt::meta "$G/code-review.md" updated)"
last="$(shell::prompt::history code-review | head -n 1 | cut -f1)"
t_eq "edit: the snapshot is the version before" "$BODY_SUM" "$(_shell::prompt::body_stream "$G/.history/code-review/$last.md" | cksum)"
t_eq "edit: snapshot is 600" "600" "$(mode_of "$G/.history/code-review/$last.md")"
t_eq "edit: no temp file left in the store" "0" "$(find "$G" -name '.tmp.*' | wc -l | tr -d ' ')"
_ignore="$upd0"

FAKE_ED_MODE="none"
export FAKE_ED_MODE
before="$(sum_dir "$G")"
run "G/code-review
Edit
$B" "" shell::prompt::view::fzf >/dev/null
t_has "edit: no changes is reported" "No changes" "$(out)"
t_eq "edit: no changes writes nothing" "$before" "$(sum_dir "$G")"

FAKE_ED_MODE="break"
export FAKE_ED_MODE
before="$(sum_dir "$G")"
t_eq "edit: invalid then Discard" "11" "$(run "ctrl-e::G/code-review
Discard my changes
$B" "" shell::prompt::view::fzf)"
t_has "edit: validation error shown" "needs a non-empty 'title:'" "$(out)"
t_eq "edit: invalid menu offers re-open, discard, back" "Re-open the editor
Discard my changes
$B" "$(cat "$FAKE_FZF_DIR/stdin.2")"
t_eq "edit: invalid + Discard leaves the store untouched" "$before" "$(sum_dir "$G")"
run "ctrl-e::G/code-review
$B
$B" "" shell::prompt::view::fzf >/dev/null
t_eq "edit: invalid + Back leaves the store untouched" "$before" "$(sum_dir "$G")"
run "ctrl-e::G/code-review

$B" "" shell::prompt::view::fzf >/dev/null
t_eq "edit: invalid + ESC leaves the store untouched" "$before" "$(sum_dir "$G")"

FAKE_ED_MODE="brokenthenfix"
export FAKE_ED_MODE
t_eq "edit: invalid, re-open, fixed, saved" "11" "$(run "ctrl-e::G/needs
Re-open the editor
$B" "" shell::prompt::view::fzf)"
t_eq "edit: re-opened edit saved" "fixed body" "$(shell::prompt::get needs)"
t_eq "edit: re-opened edit took the new title" "Fixed Title" "$(_shell::prompt::meta "$G/needs.md" title)"
t_eq "edit: the slug does not change with the title" "true" "$(shell::prompt::exists needs)"

# edit::fzf: Enter edits directly; -n does not open the editor
FAKE_ED_MODE="append"
export FAKE_ED_MODE
t_eq "edit::fzf edits on Enter then returns to the list" "11" "$(run "G/greeting
$B" "" shell::prompt::edit::fzf)"
t_has "edit::fzf saved" "EDITED" "$(shell::prompt::get greeting)"
before="$(sum_dir "$G")"
run "G/greeting
$B" "" shell::prompt::edit::fzf -n >/dev/null
t_eq "edit::fzf -n writes nothing" "$before" "$(sum_dir "$G")"
t_has "edit::fzf -n prints the command" "snapshot + atomic replace" "$(out)"

# --- tags -----------------------------------------------------------------------
t_eq "Tags -> Add tags (typed answer)" "11" "$(run "G/code-review
Tags
Add tags
$B" "Fresh, Extra
" shell::prompt::view::fzf)"
t_eq "tags added" "review,bash,fresh,extra" "$(_shell::prompt::meta "$G/code-review.md" tags)"
t_eq "Tags -> Remove tags (multi)" "11" "$(run "G/code-review
Tags
Remove tags
fresh|extra
$B" "" shell::prompt::view::fzf)"
t_eq "tags removed" "review,bash" "$(_shell::prompt::meta "$G/code-review.md" tags)"

# --- history / restore -------------------------------------------------------------
stamp="$(shell::prompt::history code-review | tail -n 1 | cut -f1)"
t_eq "History action: pick a snapshot, restore it" "11" "$(run "G/code-review
History
$stamp
Restore this version
$B
$B" "y
" shell::prompt::view::fzf)"
t_eq "restored the oldest body" "$BODY_SUM" "$(shell::prompt::get code-review | cksum)"
t_has "snapshot rows have a diff preview" " hist G/code-review {1}" "$(cat "$FAKE_FZF_DIR/args.3")"
run "G/code-review
History
$stamp
Restore this version
$B
$B" "n
" shell::prompt::view::fzf >/dev/null
t_has "declined restore is reported" "nothing was restored" "$(out)"

# --- remove ----------------------------------------------------------------------------
before="$(sum_dir "$G")"
run "ctrl-d::G/greeting
$B" "n
" shell::prompt::view::fzf >/dev/null
t_eq "Ctrl-D declined: nothing removed" "true" "$(shell::prompt::exists greeting)"
t_eq "Ctrl-D declined: store untouched" "$before" "$(sum_dir "$G")"
run "ctrl-d::G/greeting
$B" "y
" shell::prompt::view::fzf >/dev/null
t_eq "Ctrl-D confirmed: removed" "false" "$(shell::prompt::exists greeting)"
t_has "removed: kept in history" "greeting" "$(shell::prompt::list --removed)"
t_has "the refreshed list no longer shows it" "needs" "$(cat "$FAKE_FZF_DIR/stdin.2")"
t_lacks "the refreshed list no longer shows it (2)" "G/greeting" "$(cat "$FAKE_FZF_DIR/stdin.2")"
t_eq "remove -n" "11" "$(run "ctrl-d::G/needs
$B" "" shell::prompt::view::fzf -n)"
t_eq "remove -n: still there" "true" "$(shell::prompt::exists needs)"

# history::fzf lists removed prompts and restores them
t_eq "history::fzf restores a removed prompt" "11" "$(run "G/greeting
$(shell::prompt::history greeting | head -n 1 | cut -f1)
Restore this version
$B
$B" "y
" shell::prompt::history::fzf)"
t_has "history::fzf row marks removed prompts" "removed" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_eq "history::fzf: prompt restored" "true" "$(shell::prompt::exists greeting)"

# --- search ------------------------------------------------------------------------------
t_eq "search::fzf" "11" "$(FAKE_RELOAD="strict" run "G/code-review
Copy
$B" "" shell::prompt::search::fzf)"
t_has "search: fzf is not filtering itself" "--disabled" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "search: reload on every keystroke" "--bind=change:reload:sh " "$(cat "$FAKE_FZF_DIR/args.1")"
FAKE_RELOAD="strict" run "$B" "" shell::prompt::search::fzf >/dev/null
t_has "search reload matches the BODY" "G/code-review" "$(cat "$FAKE_FZF_DIR/reload.1")"
t_lacks "search reload hides non-matching prompts" "G/needs" "$(cat "$FAKE_FZF_DIR/reload.1")"
t_eq "search reload keeps the Back row" "$B	$B" "$(tail -n 1 "$FAKE_FZF_DIR/reload.1")"
FAKE_RELOAD="zzznomatch" run "$B" "" shell::prompt::search::fzf >/dev/null
t_eq "search reload with no match: only Back" "$B	$B" "$(cat "$FAKE_FZF_DIR/reload.1")"
FAKE_RELOAD="bash" run "$B" "" shell::prompt::search::fzf >/dev/null
t_has "search reload matches tags" "G/code-review" "$(cat "$FAKE_FZF_DIR/reload.1")"

# --- tag::fzf --------------------------------------------------------------------------------
t_eq "tag::fzf: tag -> prompts -> Back -> tags -> Back" "11" "$(run "review (
$B
$B" "" shell::prompt::tag::fzf)"
t_has "tag::fzf lists tags with counts" "review (1)" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "tag::fzf shows only that tag's prompts" "G/code-review" "$(cat "$FAKE_FZF_DIR/stdin.2")"
t_lacks "tag::fzf hides other prompts" "G/needs" "$(cat "$FAKE_FZF_DIR/stdin.2")"
t_has "tag::fzf prompt names the tag" "Tag review: " "$(cat "$FAKE_FZF_DIR/args.2")"

# --- empty store ---------------------------------------------------------------------------------
OLD_STORE="$SHELL_PROMPT_DIR"
export SHELL_PROMPT_DIR="$HOME/empty-store"
t_eq "empty store: Back" "11" "$(run "$B" "" shell::prompt::view::fzf)"
t_eq "empty store offers to create the first prompt" "Create your first prompt
$B" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_eq "empty store: nothing created by Back" "no" "$([ -e "$SHELL_PROMPT_DIR" ] && echo yes || echo no)"
t_eq "empty store: create the first prompt (typed body)" "11" "$(run "Create your first prompt
Paste here
$B" "First One
starter
the body
" shell::prompt::view::fzf)"
t_eq "empty store: prompt created" "the body" "$(shell::prompt::get first-one)"
t_eq "empty store: tags saved" "starter" "$(_shell::prompt::meta "$SHELL_PROMPT_DIR/first-one.md" tags)"
t_has "empty store: list shows it afterwards" "G/first-one" "$(cat "$FAKE_FZF_DIR/stdin.3")"
t_eq "empty history: info, no error" "11" "$(run "" "" shell::prompt::history::fzf)"
t_eq "tag::fzf in a store with one tag: ESC" "0" "$(run "" "" shell::prompt::tag::fzf)"
export SHELL_PROMPT_DIR="$OLD_STORE"

# --- local store marker --------------------------------------------------------------------------------
mkdir "$HOME/proj"
cd "$HOME/proj" || exit 1
printf 'local body\n' | shell::prompt::add --local "Local One" - >/dev/null 2>&1
run "$B" "" shell::prompt::view::fzf >/dev/null
t_has "local store: [L] marker" "L/local-one	[L] local-one" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "local store: [G] still there" "G/code-review" "$(cat "$FAKE_FZF_DIR/stdin.1")"
run "$B" "" shell::prompt::view::fzf --local >/dev/null
t_lacks "--local hides global prompts" "G/code-review" "$(cat "$FAKE_FZF_DIR/stdin.1")"
run "$B" "" shell::prompt::view::fzf --global >/dev/null
t_lacks "--global hides local prompts" "L/local-one" "$(cat "$FAKE_FZF_DIR/stdin.1")"
run "ctrl-y::L/local-one
$B" "" shell::prompt::view::fzf >/dev/null
t_eq "copy from the local store" "local body
|" "$(clip)"
cd "$HOME" || exit 1

# --- hub -------------------------------------------------------------------------------------------------
printf 'hub body {{x|1}}\n' >"$HOME/hub-body.txt"
printf -- '---\ntitle: Imported Hub\n---\nimported body\n' >"$HOME/imp-hub.md"
t_eq "manage::fzf walks every entry and returns Back" "11" "$(run "Add
File
View
ctrl-y::G/hub-title
$B
Clone
G/hub-title
$B
Rename
G/hub-clone
$B
Remove
G/hub-renamed
$B
History
$B
Export
All prompts
Import
$B" "Hub Title
hubtag
$HOME/hub-body.txt
hub-clone
hub-renamed
y
$HOME/hubexp.tar.gz
$HOME/imp-hub.md
" shell::prompt::manage::fzf)"
t_has "hub: Add created the prompt" "hub body" "$(shell::prompt::get hub-title)"
t_eq "hub: copy from View" "hub body {{x|1}}
|" "$(clip)"
t_eq "hub: Clone made hub-clone, Rename renamed it, Remove removed it" "true false false" "$(shell::prompt::exists hub-title) $(shell::prompt::exists hub-clone) $(shell::prompt::exists hub-renamed)"
t_has "hub: removed prompt is in history" "hub-renamed" "$(shell::prompt::list --removed)"
t_has "hub: Export wrote an archive" "hub-title.md" "$(tar -tzf "$HOME/hubexp.tar.gz")"
t_eq "hub: Import added the file (slug from the file name)" "imported body" "$(shell::prompt::get imp-hub)"
t_eq "hub menu entries, Back last" "Add
View
Edit
Copy
Clone
Rename
Remove
Import
Export
History
$B" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_eq "hub: ESC closes with 0" "0" "$(run "" "" shell::prompt::manage::fzf)"

before="$(sum_dir "$G")"
run "Remove
G/hub-title
$B
$B" "" shell::prompt::manage::fzf -n >/dev/null
t_eq "hub -n: Remove only prints the command" "$before" "$(sum_dir "$G")"

# --- preview script --------------------------------------------------------------------------------------
w="$(mktemp -d "$HOME/tmp/pv.XXXXXX")"
_shell::prompt::preview::init "$w" "" ""
pv() { FZF_PREVIEW_COLUMNS=60 FZF_PREVIEW_LINES=30 sh "$w/preview.sh" "$@"; }
p="$(pv G/code-review)"
t_has "preview: title" "Code Review" "$p"
t_has "preview: tags" "review,bash" "$p"
t_has "preview: description" "Strict reviewer" "$p"
t_has "preview: updated" "updated" "$p"
t_has "preview: variables row" "variables" "$p"
t_has "preview: size row" "chars" "$p"
t_has "preview: body" "second line" "$p"
t_has "preview: variables detected" "who, tone" "$(pv G/greeting)"
t_has "preview: Back row" "Go back without changing anything" "$(pv "$B")"
t_eq "preview: traversal key prints nothing" "" "$(pv 'G/../../etc/passwd')"
t_eq "preview: unknown scope prints nothing" "" "$(pv 'X/code-review')"
t_has "preview: missing prompt" "not found" "$(pv G/does-not-exist)"
shell::prompt::remove -y hub-title >/dev/null 2>&1
t_has "preview: a removed prompt shows its last snapshot" "removed" "$(pv G/hub-title)"
st="$(shell::prompt::history code-review | tail -n 1 | cut -f1)"
t_has "preview: history mode diffs against the current version" "current -> this snapshot" "$(pv hist G/code-review "$st")"
t_eq "preview: bad stamp prints nothing" "" "$(pv hist G/code-review '../x')"
t_eq "rows.sh: the list the search reloads" "$B	$B" "$(sh "$w/rows.sh" zzznomatch)"
rm -rf "$w"

# --- cleanup ---------------------------------------------------------------------------------------------
t_eq "no work directory is left behind" "0" "$(find "$HOME/tmp" -maxdepth 1 -name 'shell-prompt.*' | wc -l | tr -d ' ')"

t_done
