#!/usr/bin/env bash
# Back navigation: shell::ask::option::back, shell::git::commit::message::base --back
# and the step-by-step shell::git::commit::create. fzf is faked (scripted picks, then
# ESC) and text prompts read from stdin; every create run uses -n, so nothing is committed.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup
# Emoji are off by default; a SHELL_GIT_COMMIT_EMOJI exported by the person running the tests must not leak in.
SHELL_GIT_COMMIT_EMOJI=false

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
printf '%s\n' "$pick"
FAKE
chmod +x "$HOME/bin/fzf"
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_FZF_PICKS=""

reset_fzf() {
	find "$HOME" -maxdepth 1 \( -name 'stdin.*' -o -name 'args.*' \) -delete
	rm -f "$FAKE_FZF_STATE"
}
B="$SHELL_FZF_BACK_LABEL"
nl='
'

# run_create <picks> <stdin text> [create args...]  -> combined output
run_create() {
	local picks="$1" input="$2"
	shift 2
	reset_fzf
	printf '%s' "$input" | FAKE_FZF_PICKS="$picks" shell::git::commit::create "$@" 2>&1
}

mkdir "$HOME/repo" && git -C "$HOME/repo" init -q && cd "$HOME/repo" || exit 1

# --- shell::ask::option::back --------------------------------------------------------------
reset_fzf
out="$(FAKE_FZF_PICKS="beta" shell::ask::option::back a beta c 2>/dev/null)"
t_eq "ask back: choice is printed" "beta" "$out"
t_eq "ask back: back entry is the LAST line" "$B" "$(tail -n 1 "$HOME/stdin.1")"
t_eq "ask back: choices come first, in order" "a" "$(head -n 1 "$HOME/stdin.1")"
t_has "ask back: default prompt" "--prompt=Select an option: " "$(cat "$HOME/args.1")"

reset_fzf
out="$(FAKE_FZF_PICKS="$B" shell::ask::option::back a b 2>/dev/null)"
t_eq "ask back: picking Back prints nothing" "" "$out"
reset_fzf
FAKE_FZF_PICKS="$B" shell::ask::option::back a b >/dev/null 2>&1
t_eq "ask back: picking Back returns RETURN_BACK" "$RETURN_BACK" "$?"
reset_fzf
FAKE_FZF_PICKS="" shell::ask::option::back a b >/dev/null 2>&1
t_eq "ask back: ESC is a cancel, not a back" "$RETURN_CANCELLED" "$?"
reset_fzf
FAKE_FZF_PICKS="a" shell::ask::option::back -p "Env: " a b >/dev/null 2>&1
t_has "ask back: custom prompt" "--prompt=Env: " "$(cat "$HOME/args.1")"
shell::ask::option::back >/dev/null 2>&1
t_eq "ask back: no choices is invalid" "2" "$?"
shell::ask::option::back --bogus a >/dev/null 2>&1
t_eq "ask back: unknown option is invalid" "2" "$?"
shell::ask::option::back -p >/dev/null 2>&1
t_eq "ask back: -p needs a value" "2" "$?"
t_eq "RETURN_BACK is unique" "0" "$(printf '%s\n' "$RETURN_SUCCESS" "$RETURN_FAILURE" "$RETURN_INVALID" "$RETURN_NOT_FOUND" "$RETURN_NOT_SUPPORTED" "$RETURN_NOT_IMPLEMENTED" "$RETURN_PERMISSION_DENIED" "$RETURN_EXISTS" "$RETURN_EMPTY" "$RETURN_CANCELLED" "$RETURN_TIMEOUT" "$RETURN_BACK" | sort | uniq -d | wc -l | tr -d ' ')"

# --- shell::git::commit::message::base --back ---------------------------------------------
doc="Documentation and Non-Code Changes"
msg="docs: :books: add notes from the latest team meeting"
reset_fzf
out="$(FAKE_FZF_PICKS="Revert and Rollback${nl}${B}${nl}${doc}${nl}${msg}" shell::git::commit::message::base --back 2>/dev/null)"
t_eq "base --back: Back in the message menu returns to categories" "$msg" "$out"
t_eq "base --back: category menu was shown twice" "$B" "$(tail -n 1 "$HOME/stdin.3")"
t_has "base --back: ...as a category list" "Revert and Rollback" "$(cat "$HOME/stdin.3")"
t_eq "base --back: message menu has a Back entry" "$B" "$(tail -n 1 "$HOME/stdin.2")"

reset_fzf
out="$(FAKE_FZF_PICKS="$B" shell::git::commit::message::base --back 2>/dev/null)"
t_eq "base --back: Back in the category menu prints nothing" "" "$out"
reset_fzf
FAKE_FZF_PICKS="$B" shell::git::commit::message::base --back >/dev/null 2>&1
t_eq "base --back: ...and returns RETURN_BACK" "$RETURN_BACK" "$?"

reset_fzf
FAKE_FZF_PICKS="$doc" shell::git::commit::message::base >/dev/null 2>&1
t_lacks "base without --back: no Back entry (unchanged behaviour)" "$B" "$(cat "$HOME/stdin.1")"
reset_fzf
FAKE_FZF_PICKS="" shell::git::commit::message::base --back >/dev/null 2>&1
t_eq "base --back: ESC still returns 0" "0" "$?"

# --- create, default mode ------------------------------------------------------------------
out="$(run_create "feat${nl}none${nl}Commit" "add login${nl}#12${nl}" -n)"
t_has "create: happy path" 'git commit -m "feat: add login #12"' "$out"
t_eq "create: type menu ends with a Back entry" "$B" "$(tail -n 1 "$HOME/stdin.1")"
t_eq "create: confirm menu is Commit / Abort / Back" "Commit${nl}Abort${nl}${B}" "$(cat "$HOME/stdin.3")"

out="$(run_create "feat${nl}none${nl}${B}${nl}Commit" "add login${nl}#1${nl}#2${nl}" -n)"
t_has "create: Back at confirm re-asks the issue number" 'add login #2"' "$out"
t_lacks "create: ...and the old issue number is replaced" "#1\"" "$out"

out="$(run_create "feat${nl}none${nl}${B}${nl}Commit" "add login${nl}#1${nl}${nl}" -n)"
t_has "create: Enter keeps the previous value" 'git commit -m "feat: add login #1"' "$out"
t_has "create: the previous value is shown in the prompt" "Enter keeps: #1" "$out"

out="$(run_create "feat${nl}none${nl}Commit" "first${nl}:back${nl}second${nl}#3${nl}" -n)"
t_has "create: :back at the issue prompt returns to the description" 'git commit -m "feat: second #3"' "$out"
t_has "create: ...which shows the previous description" "Enter keeps: first" "$out"

out="$(run_create "feat${nl}none${nl}scope:ui${nl}Commit" ":back${nl}y${nl}#4${nl}" -n)"
t_has "create: :back at the description returns to the scope menu" 'git commit -m "feat(ui): y #4"' "$out"
t_eq "create: ...so the scope menu was shown twice" "back" "$(tail -n 1 "$HOME/stdin.3" | cut -f1)"

out="$(run_create "dependency${nl}fix${nl}none${nl}Commit" ":back${nl}y${nl}#4${nl}" -n)"
t_has "create: :back at the description of a type without a scope menu returns to the type menu" 'git commit -m "fix: y #4"' "$out"
t_eq "create: ...so the type menu was shown twice" "$B" "$(tail -n 1 "$HOME/stdin.2")"

out="$(run_create "$B" "" -n)"
t_has "create: Back at the first step leaves" "Commit cancelled" "$out"
t_lacks "create: ...without committing" "git commit" "$out"
run_create "$B" "" -n >/dev/null
t_eq "create: ...with status 0" "0" "$?"

out="$(run_create "" "" -n)"
t_has "create: ESC at the type menu aborts" "No commit type selected" "$out"
t_lacks "create: ...without committing" "git commit" "$out"

out="$(run_create "feat${nl}none${nl}Abort" "x desc${nl}#1${nl}" -n)"
t_has "create: Abort at the confirmation" "Commit aborted" "$out"
t_lacks "create: ...does not commit" "git commit -m" "$out"

out="$(run_create "feat${nl}none" "x desc${nl}#1${nl}" -n)"
t_has "create: ESC at the confirmation aborts" "Commit aborted" "$out"

out="$(run_create "feat${nl}none" "" -n)"
t_has "create: end of input at a prompt aborts" "Input cancelled" "$out"

out="$(run_create "feat${nl}none${nl}Commit" "${nl}real description${nl}#5${nl}" -n)"
t_has "create: an empty first value is rejected, not accepted" "cannot be empty" "$out"
t_has "create: ...and the next value is used" "real description #5" "$out"

# --- create: the scope menu (second level, after the type) ----------------------------------
# Rows are "<kind><TAB><display>": none, scope:<name> ..., custom, back.
out="$(run_create "feat${nl}scope:docs${nl}Commit" "add login${nl}#12${nl}" -n)"
t_has "scope: feat(docs) is committed" 'git commit -m "feat(docs): add login #12"' "$out"
kinds="$(cut -f1 "$HOME/stdin.2")"
t_eq "scope: the menu starts with (no scope)" "none" "$(printf '%s\n' "$kinds" | head -n 1)"
t_eq "scope: ...ends with Back" "back" "$(printf '%s\n' "$kinds" | tail -n 1)"
t_eq "scope: ...with a custom entry just before it" "custom" "$(printf '%s\n' "$kinds" | tail -n 2 | head -n 1)"
t_has "scope: ...and one row per catalog scope" "scope:docs" "$kinds"
t_has "scope: ...shown as <type>(<scope>)" "feat(docs)" "$(cut -f2 "$HOME/stdin.2")"
t_has "scope: ...a table of two columns (display is the 2nd)" "--with-nth=2" "$(cat "$HOME/args.2")"
t_has "scope: ...the Back row carries the Back label" "$B" "$(grep '^back' "$HOME/stdin.2" | cut -f2)"

out="$(run_create "feat${nl}none${nl}Commit" "add login${nl}#12${nl}" -n)"
t_has "scope: (no scope) keeps the plain type" 'git commit -m "feat: add login #12"' "$out"

out="$(run_create "feat${nl}back${nl}fix${nl}scope:git${nl}Commit" "x${nl}#1${nl}" -n)"
t_has "scope: Back returns to the type menu" 'git commit -m "fix(git): x #1"' "$out"
t_eq "scope: ...the type menu is shown again" "feat" "$(head -n 1 "$HOME/stdin.3")"

out="$(run_create "feat" "" -n)"
t_has "scope: ESC at the scope menu aborts" "No commit scope selected" "$out"
t_lacks "scope: ...without committing" "git commit -m" "$out"

# A type that already maps onto a scoped header has no scope menu.
out="$(run_create "dependency${nl}Commit" "bump the parser${nl}#2${nl}" -n)"
t_has "scope: 'dependency' keeps build(deps)" 'git commit -m "build(deps): bump the parser #2"' "$out"
t_eq "scope: ...and gets no scope menu (the 2nd menu is the confirmation)" "Commit${nl}Abort${nl}${B}" "$(cat "$HOME/stdin.2")"
t_eq "scope: ...so there is no 3rd menu" "no" "$([ -e "$HOME/stdin.3" ] && echo yes || echo no)"

# A label mapped onto another type shows (and commits) that type, with its own emoji.
out="$(run_create "improvement${nl}scope:docs${nl}Commit" "faster${nl}#3${nl}" -n --emoji)"
t_has "scope: 'improvement' is committed as perf(docs), with its emoji" 'git commit -m "perf(docs): :zap: faster #3"' "$out"
t_has "scope: ...the rows show the committed header" "perf(docs)" "$(cut -f2 "$HOME/stdin.2")"

# Custom scope.
out="$(run_create "feat${nl}custom${nl}Commit" "api${nl}add x${nl}#1${nl}" -n)"
t_has "scope: a custom scope is committed" 'git commit -m "feat(api): add x #1"' "$out"
out="$(run_create "feat${nl}custom${nl}custom${nl}Commit" "bad scope${nl}api${nl}add x${nl}#1${nl}" -n)"
t_has "scope: a scope with a space is refused" "may only contain" "$out"
t_has "scope: ...and the next custom scope is used" 'git commit -m "feat(api): add x #1"' "$out"
out="$(run_create "feat${nl}custom${nl}scope:ui${nl}Commit" ":back${nl}x${nl}#1${nl}" -n)"
t_has "scope: :back at the custom prompt returns to the scope menu" 'git commit -m "feat(ui): x #1"' "$out"

# The catalog: replaced from the profile, or switched off.
out="$(SHELL_GIT_COMMIT_SCOPES="web|Web app${nl}worker|Background jobs" run_create "feat${nl}scope:web${nl}Commit" "x${nl}#1${nl}" -n)"
t_has "scope: SHELL_GIT_COMMIT_SCOPES replaces the list" 'git commit -m "feat(web): x #1"' "$out"
t_eq "scope: ...only its scopes are offered" "none${nl}scope:web${nl}scope:worker${nl}custom${nl}back" "$(cut -f1 "$HOME/stdin.2")"
out="$(SHELL_GIT_COMMIT_SCOPES="" run_create "feat${nl}Commit" "add login${nl}#12${nl}" -n)"
t_has "scope: an empty SHELL_GIT_COMMIT_SCOPES skips the menu" 'git commit -m "feat: add login #12"' "$out"

# The helpers.
shell::git::commit::scope::applies feat
t_eq "scope::applies: feat" "0" "$?"
shell::git::commit::scope::applies "silent changes"
t_eq "scope::applies: a type with a plain header" "0" "$?"
shell::git::commit::scope::applies WIP
t_eq "scope::applies: WIP is chore(wip), no" "1" "$?"
shell::git::commit::scope::applies dependency
t_eq "scope::applies: dependency is build(deps), no" "1" "$?"
SHELL_GIT_COMMIT_SCOPES="" shell::git::commit::scope::applies feat
t_eq "scope::applies: an empty catalog, no" "1" "$?"

# --- create: emoji (off by default; after the colon, never before the type) ------------------
out="$(run_create "feat${nl}none${nl}Commit" "add login${nl}#12${nl}" -n)"
t_lacks "create: no emoji by default" ":sparkles:" "$out"
out="$(run_create "feat${nl}none${nl}Commit" "add login${nl}#12${nl}" -n --emoji)"
t_has "create --emoji: the emoji is after the colon" 'git commit -m "feat: :sparkles: add login #12"' "$out"
t_lacks "create --emoji: ...never before the type" '-m ":sparkles:' "$out"
out="$(SHELL_GIT_COMMIT_EMOJI=true run_create "feat${nl}none${nl}Commit" "add login${nl}#12${nl}" -n)"
t_has "create: SHELL_GIT_COMMIT_EMOJI=true turns it on" 'git commit -m "feat: :sparkles: add login #12"' "$out"
out="$(SHELL_GIT_COMMIT_EMOJI=true run_create "feat${nl}none${nl}Commit" "add login${nl}#12${nl}" -n --no-emoji)"
t_has "create --no-emoji beats the setting" 'git commit -m "feat: add login #12"' "$out"
out="$(run_create "feat${nl}none${nl}Commit" "add login${nl}#12${nl}" -n --emoji --no-emoji)"
t_has "create: the last of --emoji / --no-emoji wins" 'git commit -m "feat: add login #12"' "$out"
out="$(run_create "feat${nl}none${nl}Commit" "add login${nl}#12${nl}" --emoji -n)"
t_has "create: options work in any order" 'git commit -m "feat: :sparkles: add login #12"' "$out"

# A menu label that is not a Conventional Commits type is mapped onto one, so the type stays the prefix.
out="$(run_create "initial source${nl}Commit" "first commit${nl}#1${nl}" -n)"
t_has "create: 'initial source' is committed as chore(init)" 'git commit -m "chore(init): first commit #1"' "$out"
out="$(run_create "initial source${nl}Commit" "first commit${nl}#1${nl}" -n --emoji)"
t_has "create: ...and keeps its emoji, after the colon" 'git commit -m "chore(init): :tada: first commit #1"' "$out"
out="$(run_create "dependency${nl}Commit" "bump the parser${nl}#2${nl}" -n)"
t_has "create: 'dependency' is committed as build(deps)" 'git commit -m "build(deps): bump the parser #2"' "$out"
out="$(run_create "WIP${nl}Commit" "half done${nl}#3${nl}" -n)"
t_has "create: 'WIP' is committed as chore(wip)" 'git commit -m "chore(wip): half done #3"' "$out"
out="$(run_create "feat${nl}none${nl}Commit" "add login${nl}#12${nl}" -n --emoji)"
t_has "create: the confirmation shows the final message" "Commit message: feat: :sparkles: add login #12" "$out"

# --- create: a real commit is passed to git verbatim (it used to be eval'd) ----------------------
git config user.email t@example.com && git config user.name Tester
shell::git::commit::publish() { printf 'PUBLISHED<%s>\n' "$1"; }
echo one >one.txt && git add one.txt
out="$(run_create "fix${nl}none${nl}Commit" 'quote " and $HOME and `id` and \ done'"${nl}#8${nl}")"
t_eq "create: a nasty message is stored verbatim" 'fix: quote " and $HOME and `id` and \ done #8' "$(git log -1 --format=%s)"
t_has "create: ...reported and published" "PUBLISHED<fix: quote" "$out"
echo two >two.txt && git add two.txt
nasty='$(touch '"$HOME"'/pwned)'
run_create "fix${nl}none${nl}Commit" "${nasty}${nl}#9${nl}" >/dev/null
t_eq "create: a command substitution in the description is not executed" "no" "$([ -e "$HOME/pwned" ] && echo yes || echo no)"
t_eq "create: ...it is just text in the subject" "fix: ${nasty} #9" "$(git log -1 --format=%s)"
echo three >three.txt && git add three.txt
out="$(run_create "feat${nl}none${nl}Commit" "add login${nl}#12${nl}" --emoji)"
t_eq "create --emoji: the committed subject has the type first" "feat: :sparkles: add login #12" "$(git log -1 --format=%s)"
echo four >four.txt && git add four.txt
git config --local core.hooksPath "$HOME/nohooks"
mkdir "$HOME/nohooks"
printf '#!/bin/sh\nexit 1\n' >"$HOME/nohooks/commit-msg"
chmod +x "$HOME/nohooks/commit-msg"
out="$(run_create "feat${nl}none${nl}Commit" "will be rejected${nl}#1${nl}")"
t_lacks "create: a rejected commit is not published" "PUBLISHED<" "$out"
run_create "feat${nl}none${nl}Commit" "will be rejected${nl}#1${nl}" >/dev/null
t_eq "create: ...and the failure is returned" "1" "$?"
git config --local --unset core.hooksPath
git reset -q

# --- create, empty mode --------------------------------------------------------------------
cat="CI/CD Pipeline Triggers"
ci="ci: :construction_worker: trigger CI build to test configuration changes"
out="$(run_create "${cat}${nl}${ci}${nl}Create empty commit" "" -n --empty)"
t_has "empty: happy path" "git commit --allow-empty -m \"$ci\"" "$out"
t_has "empty: the messages are plain by default" "ci: trigger CI build to test configuration changes" "$(cat "$HOME/stdin.2")"
t_lacks "empty: ...without the emoji" ":construction_worker:" "$(cat "$HOME/stdin.2")"
run_create "${cat}${nl}${ci}${nl}Create empty commit" "" -n --empty --emoji >/dev/null
t_has "empty --emoji: the emoji is shown, after the colon" "$ci" "$(cat "$HOME/stdin.2")"
SHELL_GIT_COMMIT_EMOJI=true run_create "${cat}${nl}${ci}${nl}Create empty commit" "" -n --empty >/dev/null
t_has "empty: SHELL_GIT_COMMIT_EMOJI=true shows the emoji" "$ci" "$(cat "$HOME/stdin.2")"
out="$(run_create "${cat}${nl}${ci}${nl}Create empty commit" "" --empty -n)"
t_has "empty: -e and -n work in either order" "git commit --allow-empty -m \"$ci\"" "$out"

rv="revert: :rewind: undo last change that broke the production build"
out="$(run_create "${cat}${nl}${B}${nl}Revert and Rollback${nl}${rv}${nl}Create empty commit" "" -n --empty)"
t_has "empty: Back in the message list returns to the categories" "git commit --allow-empty -m \"$rv\"" "$out"

out="$(run_create "$B" "" -n --empty)"
t_lacks "empty: Back in the category list leaves without committing" "git commit" "$out"
run_create "$B" "" -n --empty >/dev/null
t_eq "empty: ...with status 0" "0" "$?"

out="$(run_create "${cat}${nl}${ci}${nl}${B}${nl}${doc}${nl}${msg}${nl}Create empty commit" "" -n --empty)"
t_has "empty: Back at the confirmation picks a message again" "git commit --allow-empty -m \"$msg\"" "$out"
t_lacks "empty: ...and the first message is not committed" "$ci\"" "$out"

out="$(run_create "${cat}${nl}${ci}${nl}Abort" "" -n --empty)"
t_has "empty: Abort" "Commit aborted" "$out"
t_lacks "empty: ...does not commit" "git commit" "$out"

out="$(run_create "" "" -n --empty)"
t_lacks "empty: ESC leaves without committing" "git commit" "$out"

# --- guards ---------------------------------------------------------------------------------
(cd "$HOME" && run_create "feat" "" -n >/dev/null)
t_eq "create: outside a git repository fails" "1" "$?"
t_rc "create -h" 0 shell::git::commit::create -h
t_has "create help explains Back" "Back" "$T_OUT"
t_has "create help documents the emoji switch" "--no-emoji" "$T_OUT"
t_rc "create: -h after another option still shows the help" 0 shell::git::commit::create -n -h
t_has "create: ...the help" "--emoji" "$T_OUT"
t_rc "create: an unknown option is invalid" 2 shell::git::commit::create --bogus
t_has "create: ...and says which" "Unknown option: --bogus" "$T_OUT"

t_done
