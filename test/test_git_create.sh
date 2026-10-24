#!/usr/bin/env bash
# Back navigation: shell::ask::option::back, shell::git::commit::message::base --back
# and the step-by-step shell::git::commit::create. fzf is faked (scripted picks, then
# ESC) and text prompts read from stdin; every create run uses -n, so nothing is committed.
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
out="$(run_create "feat${nl}Commit" "add login${nl}#12${nl}" -n)"
t_has "create: happy path" 'git commit -m ":sparkles: feat: add login #12"' "$out"
t_eq "create: type menu ends with a Back entry" "$B" "$(tail -n 1 "$HOME/stdin.1")"
t_eq "create: confirm menu is Commit / Abort / Back" "Commit${nl}Abort${nl}${B}" "$(cat "$HOME/stdin.2")"

out="$(run_create "feat${nl}${B}${nl}Commit" "add login${nl}#1${nl}#2${nl}" -n)"
t_has "create: Back at confirm re-asks the issue number" 'add login #2"' "$out"
t_lacks "create: ...and the old issue number is replaced" "#1\"" "$out"

out="$(run_create "feat${nl}${B}${nl}Commit" "add login${nl}#1${nl}${nl}" -n)"
t_has "create: Enter keeps the previous value" 'git commit -m ":sparkles: feat: add login #1"' "$out"
t_has "create: the previous value is shown in the prompt" "Enter keeps: #1" "$out"

out="$(run_create "feat${nl}Commit" "first${nl}:back${nl}second${nl}#3${nl}" -n)"
t_has "create: :back at the issue prompt returns to the description" 'git commit -m ":sparkles: feat: second #3"' "$out"
t_has "create: ...which shows the previous description" "Enter keeps: first" "$out"

out="$(run_create "feat${nl}fix${nl}Commit" ":back${nl}y${nl}#4${nl}" -n)"
t_has "create: :back at the description returns to the type menu" 'git commit -m ":bug: fix: y #4"' "$out"
t_eq "create: ...so the type menu was shown twice" "$B" "$(tail -n 1 "$HOME/stdin.2")"

out="$(run_create "$B" "" -n)"
t_has "create: Back at the first step leaves" "Commit cancelled" "$out"
t_lacks "create: ...without committing" "git commit" "$out"
run_create "$B" "" -n >/dev/null
t_eq "create: ...with status 0" "0" "$?"

out="$(run_create "" "" -n)"
t_has "create: ESC at the type menu aborts" "No commit type selected" "$out"
t_lacks "create: ...without committing" "git commit" "$out"

out="$(run_create "feat${nl}Abort" "x desc${nl}#1${nl}" -n)"
t_has "create: Abort at the confirmation" "Commit aborted" "$out"
t_lacks "create: ...does not commit" "git commit -m" "$out"

out="$(run_create "feat" "x desc${nl}#1${nl}" -n)"
t_has "create: ESC at the confirmation aborts" "Commit aborted" "$out"

out="$(run_create "feat" "" -n)"
t_has "create: end of input at a prompt aborts" "Input cancelled" "$out"

out="$(run_create "feat${nl}Commit" "${nl}real description${nl}#5${nl}" -n)"
t_has "create: an empty first value is rejected, not accepted" "cannot be empty" "$out"
t_has "create: ...and the next value is used" "real description #5" "$out"

# --- create, empty mode --------------------------------------------------------------------
cat="CI/CD Pipeline Triggers"
ci="ci: :construction_worker: trigger CI build to test configuration changes"
out="$(run_create "${cat}${nl}${ci}${nl}Create empty commit" "" -n --empty)"
t_has "empty: happy path" "git commit --allow-empty -m \"$ci\"" "$out"

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

t_done
