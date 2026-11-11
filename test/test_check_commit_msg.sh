#!/usr/bin/env bash
# scripts/check_commit_msg.sh: the Conventional Commits gate behind `make hooks`
# (commit-msg hook) and the CI commit-messages job. Tests the script itself; the
# rules it enforces are documented in docs/development/commit-messages.md.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

CHECKER="$SHELL_TEST_ROOT/scripts/check_commit_msg.sh"

# --- --subject: what passes
t_rc "type(scope): description passes" 0 bash "$CHECKER" --subject "feat(auth): add OAuth2 login support #1"
t_rc "type: description (no scope) passes" 0 bash "$CHECKER" --subject "docs: update README #1"
t_rc "breaking-change marker passes" 0 bash "$CHECKER" --subject "feat(api)!: drop the v1 endpoints #1"
t_rc "dashed scope passes" 0 bash "$CHECKER" --subject "refactor(core-git): split the module #1"
t_rc "issue reference in subject passes" 0 bash "$CHECKER" --subject "fix(runner): isolate scratch space per run #42"

# --- --subject: git-written messages are exempt
t_rc "merge subject passes" 0 bash "$CHECKER" --subject "Merge branch 'developer' into master"
t_rc "revert subject passes" 0 bash "$CHECKER" --subject 'Revert "feat(auth): add OAuth2 login support #1"'
t_rc "fixup subject passes" 0 bash "$CHECKER" --subject "fixup! feat(auth): add OAuth2 login support"
t_rc "squash subject passes" 0 bash "$CHECKER" --subject "squash! feat(auth): add OAuth2 login support"

# --- --subject: what fails
t_rc "missing type fails" 1 bash "$CHECKER" --subject "fixed stuff"
t_has "missing type names the format" "type(scope)!: description" "$T_OUT"
t_rc "unknown type fails" 1 bash "$CHECKER" --subject "feature(auth): add OAuth2 login support"
t_rc "upper-case scope fails" 1 bash "$CHECKER" --subject "feat(Auth): add OAuth2 login support"
t_rc "space before the scope fails" 1 bash "$CHECKER" --subject "feat (auth): add OAuth2 login support"
t_rc "missing colon fails" 1 bash "$CHECKER" --subject "feat(auth) add OAuth2 login support"
t_rc "empty subject fails" 1 bash "$CHECKER" --subject ""
t_rc "past tense fails" 1 bash "$CHECKER" --subject "fix(auth): added OAuth2 login support"
t_has "past tense names the rule" "imperative" "$T_OUT"
t_rc "final period fails" 1 bash "$CHECKER" --subject "feat(auth): add OAuth2 login support."
t_rc "trailing space fails" 1 bash "$CHECKER" --subject "feat(auth): add OAuth2 login support "
t_rc "over-long subject fails" 1 bash "$CHECKER" --subject "feat(ci): add a commit message subject that runs past the seventy-two character limit git recommends"
t_has "over-long subject names the limit" "the limit is 72" "$T_OUT"
out="$(bash "$CHECKER" --subject "feat(auth): add OAuth2 login support" 2>&1)"
t_lacks "no issue hint in --subject mode" "hint:" "$out"

# --- --file: the commit-msg hook mode (subject plus a free-form body)
msg="$HOME/COMMIT_MSG"
printf 'feat(ci): add the validation step #1\n\nThe body is free-form and never checked.\n' >"$msg"
t_rc "--file: valid message passes" 0 bash "$CHECKER" --file "$msg"
out="$(bash "$CHECKER" --file "$msg" 2>&1)"
t_lacks "--file: no hint with an issue reference" "hint:" "$out"
printf 'feat(ci): add the validation step\n\nNo issue number anywhere in the body.\n' >"$msg"
t_rc "--file: valid subject without an issue still passes" 0 bash "$CHECKER" --file "$msg"
out="$(bash "$CHECKER" --file "$msg" 2>&1)"
t_has "--file: hint without an issue reference" "hint:" "$out"
printf 'fixed stuff\n\nbody\n' >"$msg"
t_rc "--file: invalid subject fails" 1 bash "$CHECKER" --file "$msg"
printf 'Merge branch "developer" into master\n\nmerge body\n' >"$msg"
t_rc "--file: merge message passes" 0 bash "$CHECKER" --file "$msg"

# --- --range: every subject in a git range
repo="$HOME/cmrepo"
mkdir "$repo" && cd "$repo" && git init -q && git config user.email t@t && git config user.name t
git commit -q --allow-empty -m "feat(core): seed the range repository #1"
t_rc "--range: valid commit passes" 0 bash "$CHECKER" --range HEAD
git commit -q --allow-empty -m "fixed stuff"
t_rc "--range: invalid commit fails" 1 bash "$CHECKER" --range HEAD
out="$(bash "$CHECKER" --range HEAD 2>&1)"
t_has "--range: names the failing commit" "does not follow the rules" "$out"
git commit -q --allow-empty -m "chore: remove stale branches #1"
t_rc "--range: only the checked range matters" 0 bash "$CHECKER" --range "HEAD~1..HEAD"

# --- usage errors
t_rc "no arguments is a usage error" 2 bash "$CHECKER"
t_rc "unknown mode is a usage error" 2 bash "$CHECKER" --bogus value
t_rc "missing value is a usage error" 2 bash "$CHECKER" --subject
t_rc "unknown range is a usage error" 2 bash "$CHECKER" --range "no-such-ref..HEAD"
t_rc "unreadable file is a usage error" 2 bash "$CHECKER" --file "$HOME/does-not-exist"

t_done
