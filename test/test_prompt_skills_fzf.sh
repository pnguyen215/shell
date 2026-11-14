#!/usr/bin/env bash
# Interactive shell::prompt::skills::*::fzf menus (src/lib/prompt_skills_fzf.sh): the list -> action -> list loop, status markers,
# multi-select, "← Back" (exit 11, nothing written), copy on every pass without installing, install / update / remove flows with
# confirmations, branch switching, dry-run, and the preview script (disk cache only, no network per cursor move).
#
# fzf is a fake (same as test_prompt_fzf.sh): call N reads line N of $FAKE_FZF_PICKS. A pick is `[key::]text[|text...]`: each
# text selects the first stdin line equal to (or containing) it. An empty line is ESC. Confirmations are read from stdin.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

t_lacks() { case "$3" in *"$2"*) t_bad "$1" "[$2] unexpectedly present in [$3]" ;; *) t_ok ;; esac }
mkdir "$HOME/bin" "$HOME/tmp" "$HOME/proj" "$HOME/fzfdir"
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
for a in "$@"; do case "$a" in --expect=*) expect=1 ;; esac; done
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
printf '#!/bin/sh\ncat\n' >"$HOME/bin/bat"
chmod +x "$HOME/bin/fzf" "$HOME/bin/pbcopy" "$HOME/bin/bat"
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME/fzfdir" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_CLIP="$HOME/clip.log" TMPDIR="$HOME/tmp" TERM=dumb
export SHELL_PROMPT_DIR="$HOME/store" XDG_CACHE_HOME="$HOME/cache" SHELL_PROMPT_SKILLS_PREFETCH=0
S="$SHELL_PROMPT_DIR"
B="$SHELL_FZF_BACK_LABEL"
sum_dir() { (cd "$1" && find . -type f | LC_ALL=C sort | xargs cksum 2>/dev/null); }
run() { # run <picks> <stdin> <command...> -> exit status; output in $HOME/out.log
	rm -f "$FAKE_FZF_STATE" "$FAKE_CLIP"
	find "$FAKE_FZF_DIR" -type f -delete
	printf '%s' "$2" | FAKE_FZF_PICKS="$1" "${@:3}" >"$HOME/out.log" 2>&1
	echo "$?"
}
calls() { cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0; }
clip() { cat "$FAKE_CLIP" 2>/dev/null; }
out() { cat "$HOME/out.log"; }
stdin_of() { cat "$FAKE_FZF_DIR/stdin.$1"; }

FX="$HOME/fx"
mkdir -p "$FX/master/prompts/review" "$FX/master/prompts/writing" "$FX/dev/prompts"
SPECIAL='You are "strict" $HOME `date` %s \n back\slash & é 日本 {not}'
printf '**Role:** Expert.\n\n%s\n\n  indented\n\n\n' "$SPECIAL" >"$FX/master/prompts/skill-optimizer.md"
printf -- '---\ntitle: Code Review\ndescription: Strict reviewer\ntags: Bash\n---\nReview {{lang|bash}} code\n' >"$FX/master/prompts/review/Code_Review.md"
printf '# Summary Writer\nSummarise {{topic}}.\n' >"$FX/master/prompts/writing/summary.md"
printf '# Dev Prompt\nbody\n' >"$FX/dev/prompts/dev-one.md"
export SHELL_PROMPT_SKILLS_LOCAL_DIR="$FX"
SO_SUM="$(cksum <"$FX/master/prompts/skill-optimizer.md")"

# --- Back: exit 11, nothing mutated -------------------------------------------------------------------------------
for fn in browse pick view; do
	t_eq "$fn::fzf: Back returns 11" "11" "$(run "$B" "" "shell::prompt::skills::$fn::fzf")"
	t_eq "$fn::fzf: Back asked fzf once" "1" "$(calls)"
done
t_has "Back says what was not done" "Back — nothing was installed" "$(
	run "$B" "" shell::prompt::skills::pick::fzf >/dev/null
	out
)"
t_eq "Back never creates a store" "no" "$([ -e "$S" ] && echo yes || echo no)"
t_eq "ESC closes with 0" "0" "$(run "" "" shell::prompt::skills::browse::fzf)"
t_eq "unknown option is rejected" "2" "$(run "" "" shell::prompt::skills::browse::fzf --nope)"
t_eq "invalid branch is rejected" "2" "$(run "" "" shell::prompt::skills::browse::fzf --branch '../x')"
t_eq "names are rejected" "2" "$(run "" "" shell::prompt::skills::browse::fzf foo)"
t_eq "unknown branch" "3" "$(run "" "" shell::prompt::skills::browse::fzf --branch nope)"
t_eq "update::fzf: nothing installed yet -> nothing to update" "0" "$(run "" "" shell::prompt::skills::update::fzf)"
t_eq "update::fzf: no fzf call when everything is current" "0" "$(calls)"
t_eq "remove::fzf: nothing installed" "0" "$(run "" "" shell::prompt::skills::remove::fzf)"
t_eq "remove::fzf: no fzf call" "0" "$(calls)"
run "$B" "" shell::prompt::skills::browse::fzf >/dev/null
t_eq "browse: Back row is last" "$B	$B" "$(tail -n 1 "$FAKE_FZF_DIR/stdin.1")"
t_has "browse: rows carry the status marker" "skill-optimizer	[-]" "$(stdin_of 1)"
t_has "browse: slugs and tags" "code-review" "$(stdin_of 1)"
t_has "browse: multi-select" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "browse: --expect keys" "--expect=ctrl-y,ctrl-g,ctrl-p,ctrl-b" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "browse: header shows the key hints" "^Y copy" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "browse: live preview command" "skills_preview.sh" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "browse: the prompt names repo and branch" "pnguyen215/skills@master" "$(cat "$FAKE_FZF_DIR/args.1")"
run "$B" "" shell::prompt::skills::view::fzf >/dev/null
t_lacks "view: single selection" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"

# --- copy works on every pass, without installing -----------------------------------------------------------------------
t_eq "Ctrl-Y twice then Back" "11" "$(run "ctrl-y::skill-optimizer
ctrl-y::skill-optimizer
$B" "" shell::prompt::skills::browse::fzf)"
t_eq "list came back after each copy" "3" "$(calls)"
c="$(clip)"
t_eq "two copies reached the clipboard" "2" "$(printf '%s' "$c" | tr -cd '|' | wc -c | tr -d ' ')"
t_eq "clipboard text is byte-exact" "$SO_SUM" "$(printf '%s' "${c%%|*}" | cksum)"
t_lacks "copy never logs the body" "strict" "$(out)"
t_eq "copy installed nothing" "no" "$([ -e "$S" ] && echo yes || echo no)"
t_eq "view::fzf Ctrl-Y copies too" "11" "$(run "ctrl-y::skill-optimizer
$B" "" shell::prompt::skills::view::fzf)"
t_eq "view::fzf copy: byte-exact" "$SO_SUM" "$(printf '%s' "$(clip)" | sed 's/|$//' | cksum)"
t_eq "Ctrl-Y on a prompt with placeholders copies the defaults (no terminal)" "11" "$(run "ctrl-y::code-review
$B" "" shell::prompt::skills::browse::fzf)"
t_eq "rendered with the default" "Review bash code
|" "$(clip)"
t_eq "Enter -> actions -> Copy" "11" "$(run "skill-optimizer
Copy
$B" "" shell::prompt::skills::browse::fzf)"
t_eq "action Copy: clipboard" "$SO_SUM" "$(printf '%s' "$(clip)" | sed 's/|$//' | cksum)"
t_eq "action menu lists the actions, Back last" "Install global
Install personal
View
Copy
Update
Remove
Switch branch
$B" "$(stdin_of 2)"
t_eq "Back in the action menu returns to the list" "11" "$(run "skill-optimizer
$B
$B" "" shell::prompt::skills::browse::fzf)"
t_has "Back in the action menu is logged" "Back — nothing was changed" "$(out)"
t_eq "...and the list was shown again" "3" "$(calls)"

# --- install from the hub ---------------------------------------------------------------------------------------------------
t_eq "Enter -> Install global" "11" "$(run "skill-optimizer
Install global
$B" "" shell::prompt::skills::browse::fzf)"
t_eq "installed (byte-exact)" "$SO_SUM" "$(shell::prompt::get skill-optimizer | cksum)"
t_eq "installed into the global store with a lock" "skill-optimizer" "$(cut -f1 "$S/.skills.lock")"
t_has "the refreshed list shows [G]" "skill-optimizer	[G]" "$(stdin_of 3)"
t_has "the other prompts are still [-]" "summary	[-]" "$(stdin_of 3)"
t_eq "multi-select install with Ctrl-G" "11" "$(run "ctrl-g::code-review|summary
$B" "" shell::prompt::skills::browse::fzf)"
t_eq "both installed" "yes" "$([ -f "$S/code-review.md" ] && [ -f "$S/summary.md" ] && echo yes || echo no)"
t_eq "the picks are in the lock" "3" "$(wc -l <"$S/.skills.lock" | tr -d ' ')"
t_has "progress for several prompts" "[2/2]" "$(out)"
t_eq "Ctrl-P installs into the personal store" "11" "$(cd "$HOME/proj" && run "ctrl-p::summary
$B" "" shell::prompt::skills::browse::fzf)"
t_eq "personal store" "yes" "$([ -f "$HOME/proj/.prompts/summary.md" ] && [ -f "$HOME/proj/.prompts/.skills.lock" ] && echo yes || echo no)"
t_has "personal tip" "git-ignored" "$(out)"
t_has "the list shows both stores" "summary	[G,P]" "$(stdin_of 2)"
rm -rf "$HOME/proj/.prompts"
before="$(sum_dir "$S")"
t_eq "dry-run install" "11" "$(run "dev-one
Install global
$B" "" shell::prompt::skills::browse::fzf -n --branch dev)"
t_eq "dry-run wrote nothing" "$before" "$(sum_dir "$S")"
t_has "dry-run printed the command" "install pnguyen215/skills@dev:prompts/dev-one.md" "$(out)"

# --- pick::fzf: scope menu --------------------------------------------------------------------------------------------------
t_eq "pick: Personal" "11" "$(cd "$HOME/proj" && run "dev-one
Personal
$B" "" shell::prompt::skills::pick::fzf --branch dev)"
t_eq "pick: scope menu offers Global first and ends with Back" "Global (any directory)
Personal (this project: .prompts)
$B" "$(stdin_of 2)"
t_eq "pick: personal install" "yes" "$([ -f "$HOME/proj/.prompts/dev-one.md" ] && echo yes || echo no)"
t_eq "pick: nothing global" "no" "$([ -f "$S/dev-one.md" ] && echo yes || echo no)"
rm -rf "$HOME/proj/.prompts"
t_eq "pick: Back at the scope menu installs nothing and returns to the list" "11" "$(run "dev-one
$B
$B" "" shell::prompt::skills::pick::fzf --branch dev)"
t_has "pick: Back in the scope menu is logged" "Back — nothing was installed" "$(out)"
t_eq "pick: ...and wrote nothing" "no" "$([ -f "$S/dev-one.md" ] && echo yes || echo no)"
t_eq "pick: Global" "11" "$(run "dev-one
Global
$B" "" shell::prompt::skills::pick::fzf --branch dev)"
t_eq "pick: global install records the branch" "dev" "$(awk -F'\t' '$1 == "dev-one" { print $3 }' "$S/.skills.lock")"

# --- conflicts and confirmation ------------------------------------------------------------------------------------------------
printf 'mine\n' | shell::prompt::add "Dev Two" - >/dev/null 2>&1
printf '# Dev Two\nremote\n' >"$FX/dev/prompts/dev-two.md"
t_eq "an existing user prompt is skipped, then declined" "11" "$(run "dev-two
Install global
$B" "n
" shell::prompt::skills::browse::fzf --branch dev)"
t_eq "declined: yours is untouched" "mine" "$(shell::prompt::get dev-two)"
t_has "the skip is reported" "Skipped 'dev-two'" "$(out)"
t_has "the overwrite is asked" "Overwrite them?" "$(out)"
t_eq "accepted: overwritten" "11" "$(run "dev-two
Install global
$B" "y
" shell::prompt::skills::browse::fzf --branch dev)"
t_has "accepted: remote content" "remote" "$(shell::prompt::get dev-two)"
t_has "accepted: yours is in history" "mine" "$(cat "$S/.history/dev-two/"*.md)"

# --- update::fzf ---------------------------------------------------------------------------------------------------------------
printf '# Summary Writer\nSummarise {{topic}} in v2.\n' >"$FX/master/prompts/writing/summary.md"
printf 'MY EDIT\n' >>"$S/code-review.md"
t_eq "update::fzf: only changed prompts are listed" "11" "$(run "$B" "" shell::prompt::skills::update::fzf --refresh)"
t_has "update: outdated row" "G/summary	[G*]" "$(stdin_of 1)"
t_has "update: modified row" "G/code-review	[G!]" "$(stdin_of 1)"
t_lacks "update: current prompts are not listed" "skill-optimizer" "$(stdin_of 1)"
t_eq "update: Back row last" "$B	$B" "$(tail -n 1 "$FAKE_FZF_DIR/stdin.1")"
t_has "update: Back is logged" "Back — nothing was updated" "$(out)"
t_eq "update the outdated one" "11" "$(run "G/summary
$B" "" shell::prompt::skills::update::fzf)"
t_has "updated" "in v2" "$(shell::prompt::get summary)"
t_has "the refreshed list no longer has it" "G/code-review" "$(stdin_of 2)"
t_lacks "...gone from the list" "G/summary" "$(stdin_of 2)"
mine="$(cksum <"$S/code-review.md")"
t_eq "a modified prompt is skipped, overwrite declined" "11" "$(run "G/code-review
$B" "n
" shell::prompt::skills::update::fzf)"
t_eq "declined: untouched" "$mine" "$(cksum <"$S/code-review.md")"
t_eq "overwrite accepted (snapshot first); the list is then empty" "0" "$(run "G/code-review
$B" "y
" shell::prompt::skills::update::fzf)"
t_lacks "restored: the edit is gone" "MY EDIT" "$(cat "$S/code-review.md")"
t_has "restored: the edit is in history" "MY EDIT" "$(cat "$S/.history/code-review/"*.md)"
t_eq "update::fzf: everything current -> returns without asking" "0" "$(run "" "" shell::prompt::skills::update::fzf)"

# --- remove::fzf -----------------------------------------------------------------------------------------------------------------
t_eq "remove::fzf: only installed prompts" "11" "$(run "$B" "" shell::prompt::skills::remove::fzf)"
t_has "remove: lists installed" "G/skill-optimizer" "$(stdin_of 1)"
t_lacks "remove: user-made prompts are not listed" "G/mine" "$(stdin_of 1)"
t_has "remove: Back is logged" "Back — nothing was removed" "$(out)"
t_eq "remove: declined" "11" "$(run "G/summary
$B" "n
" shell::prompt::skills::remove::fzf)"
t_eq "declined: still there" "yes" "$([ -f "$S/summary.md" ] && echo yes || echo no)"
before="$(sum_dir "$S")"
t_eq "remove -n" "11" "$(run "G/summary
$B" "" shell::prompt::skills::remove::fzf -n)"
t_eq "remove -n wrote nothing" "$before" "$(sum_dir "$S")"
t_eq "remove: accepted" "11" "$(run "G/summary|G/dev-two
$B" "y
y
" shell::prompt::skills::remove::fzf)"
t_eq "removed" "no" "$([ -f "$S/summary.md" ] && echo yes || echo no)"
t_eq "lock entries removed" "0" "$(grep -c '^summary	\|^dev-two	' "$S/.skills.lock")"
t_has "recoverable from history" "Summarise" "$(cat "$S/.history/summary/"*.md)"
t_eq "remove: a modified prompt asks a stronger question" "11" "$(
	printf 'x\n' >>"$S/skill-optimizer.md"
	run "G/skill-optimizer
$B" "n
" shell::prompt::skills::remove::fzf
)"
t_has "remove: local modifications are mentioned" "local modifications" "$(out)"
t_eq "remove: declined keeps it" "yes" "$([ -f "$S/skill-optimizer.md" ] && echo yes || echo no)"

# --- branches ----------------------------------------------------------------------------------------------------------------------
FAKE_FZF_PICKS="dev" run "dev" "" true >/dev/null
export SHELL_PROMPT_SKILLS_BRANCH=""
unset SHELL_PROMPT_SKILLS_BRANCH
: "${SHELL_PROMPT_SKILLS_BRANCH:=master}"
rm -f "$FAKE_FZF_STATE"
FAKE_FZF_PICKS="dev" shell::prompt::skills::branch::fzf >/dev/null 2>&1
t_eq "branch::fzf exports the session branch (no file)" "dev" "$SHELL_PROMPT_SKILLS_BRANCH"
t_eq "branch menu marks the current one and ends with Back" "  master
dev" "$(stdin_of 1 | sed 's/  (current)//' | head -n 2 | sort -r | sed 's/^master$/  master/')"
t_has "branch menu: Back last" "$B" "$(tail -n 1 "$FAKE_FZF_DIR/stdin.1")"
rm -f "$FAKE_FZF_STATE"
t_eq "the session branch drives list (dev)" "dev-one
dev-two" "$(shell::prompt::skills::list | cut -f2)"
t_eq "...and browse" "11" "$(run "$B" "" shell::prompt::skills::browse::fzf)"
t_has "...shows dev in the prompt" "@dev" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "...lists dev prompts" "dev-one" "$(stdin_of 1)"
rm -f "$FAKE_FZF_STATE"
FAKE_FZF_PICKS="$B" shell::prompt::skills::branch::fzf >"$HOME/out.log" 2>&1
t_eq "branch::fzf Back returns 11" "11" "$?"
t_eq "branch::fzf Back changes nothing" "dev" "$SHELL_PROMPT_SKILLS_BRANCH"
t_has "branch::fzf Back is logged" "Back — nothing was switched" "$(out)"
export SHELL_PROMPT_SKILLS_BRANCH=master
# Ctrl-B inside the hub switches the branch and the list reflects it
rm -f "$FAKE_FZF_STATE"
FAKE_FZF_PICKS="ctrl-b::skill-optimizer
dev
$B" shell::prompt::skills::browse::fzf >"$HOME/out.log" 2>&1
t_eq "hub: Ctrl-B switched the session branch" "dev" "$SHELL_PROMPT_SKILLS_BRANCH"
t_has "hub: the list after the switch shows the dev prompts" "dev-one" "$(stdin_of 3)"
t_lacks "hub: ...and not the master ones" "skill-optimizer" "$(stdin_of 3)"
export SHELL_PROMPT_SKILLS_BRANCH=master

# --- preview script (disk cache only) -------------------------------------------------------------------------------------------------
w="$(mktemp -d "$HOME/tmp/pv.XXXXXX")"
_shell::prompt::skills::reset
_shell::prompt::skills::index
_shell::prompt::skills::preview::init "$w"
_shell::prompt::skills::view::build "$w" remote >/dev/null
pv() { FZF_PREVIEW_COLUMNS=60 FZF_PREVIEW_LINES=30 sh "$w/skills_preview.sh" "$@"; }
p="$(pv code-review)"
t_has "preview: title" "Code Review" "$p"
t_has "preview: tags" "review" "$p"
t_has "preview: source path and branch" "pnguyen215/skills@master:prompts/review/Code_Review.md" "$p"
t_has "preview: blob sha (short)" "blob" "$p"
t_has "preview: status" "installed, up to date" "$p"
t_has "preview: variables" "lang" "$p"
t_has "preview: size" "chars" "$p"
t_has "preview: body" "Review {{lang|bash}} code" "$p"
rm -f "$S/summary.md"
_shell::prompt::skills::view::build "$w" remote >/dev/null
t_has "preview: a not-installed prompt" "not installed" "$(pv summary)"
t_has "preview: Back row" "Go back without changing anything" "$(pv "$B")"
t_eq "preview: unknown key prints nothing" "" "$(pv 'nope')"
t_eq "preview: traversal key prints nothing" "" "$(pv '../../etc/passwd')"
printf 'MY EDIT\n' >>"$S/code-review.md"
_shell::prompt::skills::view::build "$w" remote >/dev/null
t_has "preview: modified status" "modified locally" "$(pv code-review)"
t_has "preview: a diff for a modified prompt" "installed -> remote" "$(pv code-review)"
t_has "preview: the diff shows the local edit" "-MY EDIT" "$(pv code-review)"
rm -rf "$XDG_CACHE_HOME"
t_has "preview: a cache miss loads the file once" "Review {{lang|bash}} code" "$(
	pv skill-optimizer
	pv code-review
)"
t_eq "preview: ...and the file is cached afterwards" "yes" "$([ -f "$XDG_CACHE_HOME/shell/skills/pnguyen215__skills/master/blobs/$(sed -n '1p' "$w/view.tsv" | cut -f3)" ] || [ -n "$(find "$XDG_CACHE_HOME" -type f -path '*blobs*' | head -n 1)" ] && echo yes || echo no)"
rm -rf "$w"

# --- cleanup -----------------------------------------------------------------------------------------------------------------------------
t_eq "no work directory is left behind" "0" "$(find "$HOME/tmp" -maxdepth 1 \( -name 'shell-prompt.*' -o -name 'skills-tx.*' -o -name 'shell-skills-branch.*' \) | wc -l | tr -d ' ')"

t_done
