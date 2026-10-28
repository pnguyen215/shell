#!/usr/bin/env bash
# Commit message templates: the data file and its rules (shell::git::commit::message::validate),
# the user's own templates, the menu (shell::git::commit::message::base, fzf is faked), and a guard
# that every call reads the templates in ONE awk pass however many there are.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup
nl='
'

catalog="$(shell::git::commit::message::catalog)"

# --- the built-in templates (src/data/git-commit-messages.txt) -----------------------------------------
# The rules live in ONE place, shell::git::commit::message::validate; this is the guard that
# every template you add keeps to them. A header over 72 characters is a warning, not a failure.
out="$(shell::git::commit::message::validate 2>&1)"
t_has "built-in templates: no problem" "0 problem(s)" "$out"
shell::git::commit::message::validate >/dev/null 2>&1
t_eq "built-in templates: validate exits 0" "0" "$?"
t_eq "built-in templates: no problem line (only warnings, if any)" "0" "$(printf '%s\n' "$out" | grep -v 'warning:' | grep -c '^/.*:[0-9]*: ')"

check() { printf '%s\n' "$catalog" | awk -F'|' "$1"; }
t_eq "catalog is large" "1" "$([ "$(printf '%s\n' "$catalog" | wc -l)" -ge 300 ] && echo 1 || echo 0)"
t_eq "many categories" "1" "$([ "$(printf '%s\n' "$catalog" | cut -d'|' -f1 | sort -u | wc -l)" -ge 30 ] && echo 1 || echo 0)"
t_eq "every record has exactly 4 fields" "" "$(check 'NF != 4 { print NR": "$0 }')"
t_eq "built-in templates all carry an emoji" "" "$(check '$2 !~ /^:[a-z0-9_+-]+:$/ { print NR": "$2 }')"
t_eq "no category has fewer than 5 messages" "" "$(printf '%s\n' "$catalog" | cut -d'|' -f1 | sort | uniq -c | awk '$1 < 5 { print }')"
t_eq "breaking changes exist (edge case covered)" "1" "$([ "$(check '$3 ~ /!$/ { print }' | wc -l)" -ge 5 ] && echo 1 || echo 0)"
t_eq "revert type exists" "1" "$([ "$(check '$3 ~ /^revert/ { print }' | wc -l)" -ge 5 ] && echo 1 || echo 0)"
t_eq "all standard types are used" "11" "$(printf '%s\n' "$catalog" | cut -d'|' -f3 | sed 's/[(!].*//' | sort -u | wc -l | tr -d ' ')"
t_eq "the data lives in the data file, not in the code" "0" "$(grep -c '|ci(deploy)|' "$SHELL_TEST_ROOT/src/lang/git.sh")"
t_rc "the data file is there (in the repository)" 0 test -s "$SHELL_GIT_COMMIT_MESSAGES_SOURCE"

# --- the menu (fake fzf plays back picks, then ESC) ----------------------------------------
mkdir "$HOME/bin"
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
n="$(cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0)"
n=$((n + 1))
echo "$n" >"$FAKE_FZF_STATE"
cat >"$FAKE_FZF_DIR/stdin.$n"
pick="$(printf '%s\n' "$FAKE_FZF_PICKS" | sed -n "${n}p")"
[ -z "$pick" ] && exit 130
printf '%s\n' "$pick"
FAKE
chmod +x "$HOME/bin/fzf"
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_FZF_PICKS=""
reset_fzf() {
	find "$HOME" -maxdepth 1 -name 'stdin.*' -delete
	rm -f "$FAKE_FZF_STATE"
}
pick_msg() { # <category> <message-as-shown>  -> runs base with those two picks
	reset_fzf
	FAKE_FZF_PICKS="$(printf '%s\n%s' "$1" "$2")" shell::git::commit::message::base "${@:3}" 2>/dev/null
}

cat="Feature and Product Development"
out="$(pick_msg "$cat" "feat: :sparkles: add user-facing support for the requested workflow")"
t_eq "default: type first, emoji after the colon" "feat: :sparkles: add user-facing support for the requested workflow" "$out"
t_eq "default output is a parseable conventional header" "0" "$(printf '%s\n' "$out" | grep -Ec '^[a-z]+(\([a-z0-9.-]+\))?!?: ' | awk '{ print ($1 == 1) ? 0 : 1 }')"

out="$(pick_msg "$cat" "feat: add user-facing support for the requested workflow" --plain)"
t_eq "--plain drops the emoji" "feat: add user-facing support for the requested workflow" "$out"

# Scope and breaking marker are rendered in front of the colon.
out="$(pick_msg "Breaking Changes and Deprecations" "feat(api)!: :boom: remove deprecated endpoints and drop v1 support")"
t_eq "scope and ! precede the colon" "feat(api)!: :boom: remove deprecated endpoints and drop v1 support" "$out"

# What the menu really offers (the fake fzf prints the picks verbatim, so look at what it was given).
reset_fzf
FAKE_FZF_PICKS="$(printf '%s\n%s' "$cat" "feat: add user-facing support for the requested workflow")" shell::git::commit::message::base --plain >/dev/null 2>&1
t_has "--plain: the message menu offers plain messages" "feat: add user-facing support for the requested workflow" "$(cat "$HOME/stdin.2")"
t_lacks "--plain: ...with no emoji anywhere" ":sparkles:" "$(cat "$HOME/stdin.2")"
reset_fzf
FAKE_FZF_PICKS="$cat" shell::git::commit::message::base >/dev/null 2>&1
t_has "default: the message menu offers the emoji form" "feat: :sparkles: add user-facing support for the requested workflow" "$(cat "$HOME/stdin.2")"
t_eq "render --plain: the emoji is dropped" "feat: add user-facing support for the requested workflow" "$(shell::git::commit::message::scan render "$cat" true | head -n 1)"
t_eq "render: the emoji form" "feat: :sparkles: add user-facing support for the requested workflow" "$(shell::git::commit::message::scan render "$cat" false | head -n 1)"

# The menus show the right lists.
reset_fzf
FAKE_FZF_PICKS="$cat" shell::git::commit::message::base >/dev/null 2>&1
t_has "category menu lists the first category" "CI/CD Pipeline Triggers" "$(cat "$HOME/stdin.1")"
t_has "category menu lists a new edge-case category" "Revert and Rollback" "$(cat "$HOME/stdin.1")"
t_has "message menu is limited to the category" "feat: :sparkles: support bulk actions for selected records" "$(cat "$HOME/stdin.2")"
t_lacks "message menu has no other category" "fix: :bug:" "$(cat "$HOME/stdin.2")"
t_lacks "no legacy emoji-first message is offered" ":sparkles: feat:" "$(cat "$HOME/stdin.2")"

# Cancelling is not an error and prints nothing.
reset_fzf
out="$(FAKE_FZF_PICKS="" shell::git::commit::message::base 2>/dev/null)"
t_eq "ESC at the category menu: nothing printed" "" "$out"
FAKE_FZF_PICKS="" shell::git::commit::message::base >/dev/null 2>&1
t_eq "ESC returns 0" "0" "$?"
reset_fzf
FAKE_FZF_PICKS="$cat" shell::git::commit::message::base >/dev/null 2>&1
t_eq "ESC at the message menu returns 0" "0" "$?"

shell::git::commit::message::base --bogus >/dev/null 2>&1
t_eq "unknown option is rejected" "2" "$?"
t_rc "help" 0 shell::git::commit::message::base -h
t_has "help mentions --plain" "--plain" "$T_OUT"

# =============================== the format, the rules, user templates =====================================
tdir="$HOME/tpl"
mkdir "$tdir"
v() { shell::git::commit::message::validate "$@" 2>&1; }

cat >"$tdir/good.txt" <<'GOOD'
# a comment, then a blank line

[First]
:rocket:|ci|trigger the pipeline for this branch
|feat(api)!|remove the deprecated endpoint from the public api
[Second]
:bug:|fix|handle an empty list without crashing
[First]
:memo:|docs|explain the new option in the readme
GOOD
out="$(v "$tdir/good.txt")"
t_has "validate: a good file" "4 template(s) in 2 categories, 0 problem(s), 0 warning(s)" "$out"
shell::git::commit::message::validate "$tdir/good.txt" >/dev/null 2>&1
t_eq "validate: a good file exits 0" "0" "$?"
t_eq "catalog: a repeated [Category] is merged into the first one" "First${nl}First${nl}First${nl}Second" "$(SHELL_GIT_COMMIT_MESSAGES_FILE="$tdir/good.txt" shell::git::commit::message::catalog | cut -d'|' -f1 | tr '\n' '~' | sed 's/~$//' | tr '~' "$nl")"
t_eq "catalog: an empty emoji is allowed and kept empty" "First||feat(api)!|remove the deprecated endpoint from the public api" "$(SHELL_GIT_COMMIT_MESSAGES_FILE="$tdir/good.txt" shell::git::commit::message::catalog | sed -n 2p)"

cat >"$tdir/bad.txt" <<'BAD'
# fixture: line numbers below are asserted
[Bad]
sparkles|feat|add something that is long enough
:sparkles:|feature|add something that is long enough
:sparkles:|feat(API)|add something that is long enough
:sparkles:|feat|short
:sparkles:|feat|Add something that is long enough
:sparkles:|feat|add something that is long enough.
:sparkles:|feat| add something that is long enough
:sparkles:|feat|add "quoted" something that is long enough
:sparkles:|feat|add $HOME something that is long enough
:sparkles:|feat|add `ticks` something that is long enough
:sparkles:|feat|add a back\slash something that is long enough
:sparkles:|feat|add it's something that is long enough
:sparkles:|feat
:sparkles:|feat|one|two
:sparkles:|feat|add a valid template exactly once
:rocket:|feat|add a valid template exactly once
:sparkles:|feat|add something so very long that the whole header with its emoji goes well past one hundred characters
[Empty]
BAD
out="$(v "$tdir/bad.txt")"
t_has "validate: a bad emoji" "bad.txt:3: emoji must be a :shortcode: or empty" "$out"
t_has "validate: a type that is not conventional" "bad.txt:4: header \"feature\"" "$out"
t_has "validate: an upper-case scope" "bad.txt:5: header \"feat(API)\"" "$out"
t_has "validate: a too short description" "bad.txt:6: description is shorter than 12" "$out"
t_has "validate: an upper-case start" "bad.txt:7: description must start with a lower-case" "$out"
t_has "validate: a final period" "bad.txt:8: description must not end with a period" "$out"
t_has "validate: a leading space" "bad.txt:9: description has leading or trailing spaces" "$out"
t_has "validate: a double quote" "bad.txt:10: description has a character that is unsafe" "$out"
t_has "validate: a dollar sign" "bad.txt:11: description has a character that is unsafe" "$out"
t_has "validate: a backtick" "bad.txt:12: description has a character that is unsafe" "$out"
t_has "validate: a backslash" "bad.txt:13: description has a character that is unsafe" "$out"
t_has "validate: a single quote" "bad.txt:14: description has a character that is unsafe" "$out"
t_has "validate: too few fields" "bad.txt:15: expected emoji|type(scope)!|description (2 fields)" "$out"
t_has "validate: too many fields" "bad.txt:16: expected emoji|type(scope)!|description (4 fields)" "$out"
t_has "validate: a duplicate names the first one" "bad.txt:18: duplicate of $tdir/bad.txt:17" "$out"
t_has "validate: over 100 characters is an error" "bad.txt:19: header is" "$out"
t_has "validate: ...with the limit" "the limit is 100" "$out"
t_has "validate: an empty category" 'category "Empty" has no templates' "$out"
shell::git::commit::message::validate "$tdir/bad.txt" >/dev/null 2>&1
t_eq "validate: problems exit 1" "1" "$?"
t_has "validate: the summary counts them" "problem(s)" "$out"

printf '[Cat]\n:rocket:|ci|a valid template placed first here\n' >"$tdir/orphan.txt"
printf ':rocket:|ci|a template before any category header\n' >"$tdir/nocat.txt"
t_has "validate: a template outside a category" "nocat.txt:1: template outside a [Category]" "$(v "$tdir/nocat.txt")"
printf '[ ]\n:rocket:|ci|a template under an empty category name\n' >"$tdir/emptyname.txt"
t_has "validate: an empty category name" "emptyname.txt:1: empty category name" "$(v "$tdir/emptyname.txt")"

printf '[Long]\n:rocket:|feat(scope)|%s\n' "describe a change with a header that is over the recommended length" >"$tdir/long.txt"
out="$(v "$tdir/long.txt")"
t_has "validate: 72+ characters is only a warning" "long.txt:2: warning: header is" "$out"
t_has "validate: ...counted as a warning, not a problem" "0 problem(s), 1 warning(s)" "$out"
shell::git::commit::message::validate "$tdir/long.txt" >/dev/null 2>&1
t_eq "validate: ...so it exits 0" "0" "$?"
out="$(v --strict "$tdir/long.txt")"
t_has "validate --strict: the warning becomes a problem" "1 problem(s), 1 warning(s)" "$out"
shell::git::commit::message::validate --strict "$tdir/long.txt" >/dev/null 2>&1
t_eq "validate --strict: exits 1" "1" "$?"

printf '[Cat]\r\n:rocket:|ci|a template saved with windows line endings\r\n' >"$tdir/crlf.txt"
t_has "validate: CRLF files are accepted" "1 template(s) in 1 categories, 0 problem(s)" "$(v "$tdir/crlf.txt")"
t_eq "render: ...and no carriage return leaks into the message" "0" "$(SHELL_GIT_COMMIT_MESSAGES_FILE="$tdir/crlf.txt" shell::git::commit::message::scan render Cat false | grep -c "$(printf '\r')")"

out="$(v "$tdir/good.txt" "$tdir/bad.txt")"
t_has "validate: several files are checked together (4 + 1 valid templates, 4 categories)" "5 template(s) in 4 categories" "$out"
t_has "validate: ...and the lines name their own file" "bad.txt:3:" "$out"
t_lacks "validate: ...without blaming the good one" "good.txt:" "$out"
out="$(v "$tdir/missing.txt")"
t_has "validate: a missing file" "Cannot read: $tdir/missing.txt" "$out"
shell::git::commit::message::validate "$tdir/missing.txt" >/dev/null 2>&1
t_eq "validate: a missing file exits 1" "1" "$?"
shell::git::commit::message::validate --bogus >/dev/null 2>&1
t_eq "validate: an unknown option exits 2" "2" "$?"
t_rc "validate -h" 0 shell::git::commit::message::validate -h
t_has "validate help" "--strict" "$T_OUT"

# --- your own templates (SHELL_GIT_COMMIT_MESSAGES_USER_FILE) -----------------------------------------------
cat >"$tdir/user.txt" <<'USER'
[Feature and Product Development]
:sparkles:|feat(team)|add the team specific onboarding checklist item
:sparkles:|feat|add user-facing support for the requested workflow

[My Own Category]
:tada:|chore(team)|celebrate the release with the whole team

[Broken Section]
:tada:|feature|this one has an invalid type but is only skipped
:tada:|chore|and this one is valid so it is kept in the menu
USER
cats="$(SHELL_GIT_COMMIT_MESSAGES_USER_FILE="$tdir/user.txt" shell::git::commit::message::scan categories 2>"$tdir/stderr")"
t_eq "user file: a new category is appended at the end" "Broken Section${nl}My Own Category" "$(printf '%s\n' "$cats" | tail -n 2 | sort)"
t_eq "user file: the built-in category order is untouched" "$(printf '%s\n' "$catalog" | cut -d'|' -f1 | awk '!s[$1]++' | head -n 1)" "$(printf '%s\n' "$cats" | head -n 1)"
t_has "user file: a bad line is reported once, with file and line" "user.txt:9: header \"feature\"" "$(cat "$tdir/stderr")"
t_eq "user file: ...exactly one problem" "1" "$(grep -c . "$tdir/stderr")"
out="$(SHELL_GIT_COMMIT_MESSAGES_USER_FILE="$tdir/user.txt" shell::git::commit::message::scan render "Feature and Product Development" false 2>&1)"
t_has "user file: your template joins an existing category" "feat(team): :sparkles: add the team specific onboarding checklist item" "$out"
t_has "user file: ...after the built-in ones" "feat: :sparkles: support bulk actions for selected records" "$out"
t_eq "user file: a template that duplicates a built-in one is kept once" "1" "$(printf '%s\n' "$out" | grep -c 'feat: :sparkles: add user-facing support for the requested workflow')"
t_eq "user file: render stays quiet about bad lines (no repeated warnings)" "0" "$(printf '%s\n' "$out" | grep -c 'user.txt:')"
t_has "user file: the valid line of a broken section is kept" "chore: :tada: and this one is valid so it is kept in the menu" "$(SHELL_GIT_COMMIT_MESSAGES_USER_FILE="$tdir/user.txt" shell::git::commit::message::scan render "Broken Section" false 2>&1)"
t_eq "user file: the invalid line is not offered" "0" "$(SHELL_GIT_COMMIT_MESSAGES_USER_FILE="$tdir/user.txt" shell::git::commit::message::scan render "Broken Section" false 2>&1 | grep -c 'invalid type')"
t_eq "user file: a missing file is simply ignored" "$catalog" "$(SHELL_GIT_COMMIT_MESSAGES_USER_FILE="$tdir/nope.txt" shell::git::commit::message::catalog)"
t_eq "user file: validate checks it too when no file is named" "1" "$(
	SHELL_GIT_COMMIT_MESSAGES_USER_FILE="$tdir/user.txt" shell::git::commit::message::validate >/dev/null 2>&1
	echo $?
)"

# the menu offers them
reset_fzf
SHELL_GIT_COMMIT_MESSAGES_USER_FILE="$tdir/user.txt" FAKE_FZF_PICKS="$(printf '%s\n%s' "My Own Category" "chore(team): :tada: celebrate the release with the whole team")" shell::git::commit::message::base >"$tdir/picked" 2>/dev/null
t_has "base: the category menu lists your category" "My Own Category" "$(cat "$HOME/stdin.1")"
t_eq "base: ...and your template can be picked" "chore(team): :tada: celebrate the release with the whole team" "$(cat "$tdir/picked")"
reset_fzf
SHELL_GIT_COMMIT_MESSAGES_USER_FILE="$tdir/user.txt" FAKE_FZF_PICKS="$(printf '%s\n%s' "My Own Category" "chore(team): celebrate the release with the whole team")" shell::git::commit::message::base --plain >"$tdir/picked" 2>/dev/null
t_eq "base --plain: your template without the emoji" "chore(team): celebrate the release with the whole team" "$(cat "$tdir/picked")"

# a template file of your own choosing replaces the built-in one
reset_fzf
SHELL_GIT_COMMIT_MESSAGES_FILE="$tdir/good.txt" FAKE_FZF_PICKS="$(printf '%s\n%s' "Second" "fix: :bug: handle an empty list without crashing")" shell::git::commit::message::base >"$tdir/picked" 2>/dev/null
t_eq "SHELL_GIT_COMMIT_MESSAGES_FILE: the menu lists only its categories" "First${nl}Second" "$(sort "$HOME/stdin.1")"
t_eq "SHELL_GIT_COMMIT_MESSAGES_FILE: ...and an empty emoji renders without one" "fix: :bug: handle an empty list without crashing" "$(cat "$tdir/picked")"
reset_fzf
SHELL_GIT_COMMIT_MESSAGES_FILE="$tdir/good.txt" FAKE_FZF_PICKS="$(printf '%s\n%s' "First" "feat(api)!: remove the deprecated endpoint from the public api")" shell::git::commit::message::base >"$tdir/picked" 2>/dev/null
t_eq "base: a template with no emoji is printed as it is" "feat(api)!: remove the deprecated endpoint from the public api" "$(cat "$tdir/picked")"
t_eq "render: an unknown category prints nothing" "" "$(shell::git::commit::message::scan render "No Such Category" false)"

# missing data file
out="$(SHELL_GIT_COMMIT_MESSAGES_FILE="$tdir/gone.txt" shell::git::commit::message::base 2>&1)"
t_has "missing data file: says where it looked" "Commit message templates not found: $tdir/gone.txt" "$out"
SHELL_GIT_COMMIT_MESSAGES_FILE="$tdir/gone.txt" shell::git::commit::message::base >/dev/null 2>&1
t_eq "missing data file: base fails (exit 1)" "1" "$?"
SHELL_GIT_COMMIT_MESSAGES_FILE="$tdir/gone.txt" shell::git::commit::message::catalog >/dev/null 2>&1
t_eq "missing data file: catalog fails (exit 1)" "1" "$?"

# the library does not load the data file as code
t_eq "the data file is never sourced (no load errors)" "0" "$SHELL_LOAD_ERRORS"
t_eq "SHELL_GIT_COMMIT_MESSAGES_SOURCE is the file shipped in src/data" "$SHELL_TEST_ROOT/src/data/git-commit-messages.txt" "$SHELL_GIT_COMMIT_MESSAGES_SOURCE"
t_eq "SHELL_GIT_COMMIT_MESSAGES_INSTALLED is ~/.shell-config/git/git-commit-messages.txt" "$SHELL_CONFIG_DIR/git/git-commit-messages.txt" "$SHELL_GIT_COMMIT_MESSAGES_INSTALLED"
t_eq "SHELL_GIT_COMMIT_MESSAGES_FILE defaults to the installed copy" "$SHELL_GIT_COMMIT_MESSAGES_INSTALLED" "$SHELL_GIT_COMMIT_MESSAGES_FILE"
t_eq "SHELL_GIT_COMMIT_MESSAGES_USER_FILE is next to it" "$SHELL_CONFIG_DIR/git/git-commit-messages.user.txt" "$SHELL_GIT_COMMIT_MESSAGES_USER_FILE"

# --- which file is read: the installed copy, else (default path only) the repository's --------------
t_rc "setup: nothing is installed in this test home" 1 test -e "$SHELL_GIT_COMMIT_MESSAGES_INSTALLED"
t_eq "not installed yet: the repository copy is read" "$catalog" "$(shell::git::commit::message::catalog)"
mkdir -p "$SHELL_CONFIG_DIR/git"
printf '[Installed Only]\n:rocket:|ci|trigger the pipeline from the installed copy\n' >"$SHELL_GIT_COMMIT_MESSAGES_INSTALLED"
t_eq "installed: the installed copy wins over the repository's" "Installed Only|:rocket:|ci|trigger the pipeline from the installed copy" "$(shell::git::commit::message::catalog)"
t_eq "installed: ...and the menu categories come from it" "Installed Only" "$(shell::git::commit::message::scan categories)"
rm -rf "$SHELL_CONFIG_DIR/git"
SHELL_GIT_COMMIT_MESSAGES_FILE="$tdir/not-the-default.txt" shell::git::commit::message::catalog >/dev/null 2>&1
t_eq "a path you set yourself never falls back to the repository copy" "1" "$?"

# --- shell::git::commit::message::sync -------------------------------------------------------------------
inst="$SHELL_GIT_COMMIT_MESSAGES_INSTALLED"
out="$(shell::git::commit::message::sync -n 2>&1)"
t_has "sync -n: says what it would do" "Would copy $SHELL_GIT_COMMIT_MESSAGES_SOURCE to $inst" "$out"
t_rc "sync -n: copies nothing" 1 test -e "$inst"
t_rc "sync -n: creates no directory" 1 test -d "$SHELL_CONFIG_DIR/git"
out="$(shell::git::commit::message::sync 2>&1)"
t_has "sync: reports the install" "Templates installed: $inst" "$out"
t_rc "sync: the file is there" 0 test -f "$inst"
t_rc "sync: identical to the repository copy" 0 cmp -s "$SHELL_GIT_COMMIT_MESSAGES_SOURCE" "$inst"
t_eq "sync: the directory is private (700)" "1" "$(find "$SHELL_CONFIG_DIR/git" -maxdepth 0 -perm 700 | wc -l | tr -d ' ')"
t_rc "sync: no backup when there was nothing to replace" 1 test -e "$inst.bak"
t_eq "sync: no temporary file left" "0" "$(find "$SHELL_CONFIG_DIR/git" -name '*.tmp.*' | wc -l | tr -d ' ')"
out="$(shell::git::commit::message::sync 2>&1)"
t_has "sync: a second run has nothing to do" "Already up to date: $inst" "$out"
t_rc "sync: ...and makes no backup" 1 test -e "$inst.bak"

printf '\n# my manual edit\n' >>"$inst"
out="$(shell::git::commit::message::sync 2>&1)"
t_has "sync: a differing copy is replaced" "Templates installed" "$out"
t_has "sync: ...and the old one is kept" "kept as $inst.bak" "$out"
t_rc "sync: ...the new copy is the repository's again" 0 cmp -s "$SHELL_GIT_COMMIT_MESSAGES_SOURCE" "$inst"
t_has "sync: ...the backup holds the edit" "# my manual edit" "$(cat "$inst.bak")"
printf '\n# a second manual edit\n' >>"$inst"
shell::git::commit::message::sync >/dev/null 2>&1
t_has "sync: only ONE backup is kept (the latest edit)" "# a second manual edit" "$(cat "$inst.bak")"
t_eq "sync: ...the first edit is gone from it" "0" "$(grep -c 'my manual edit' "$inst.bak")"
out="$(
	printf '\n# dry\n' >>"$inst"
	shell::git::commit::message::sync -n 2>&1
)"
t_has "sync -n: a differing copy is announced" "The current file would be kept as $inst.bak" "$out"
t_has "sync -n: ...and left alone" "# dry" "$(cat "$inst")"
shell::git::commit::message::sync >/dev/null 2>&1

printf '[Mine]\n:tada:|chore|celebrate with a template of my own\n' >"$SHELL_GIT_COMMIT_MESSAGES_USER_FILE"
before="$(cat "$SHELL_GIT_COMMIT_MESSAGES_USER_FILE")"
printf 'x\n' >>"$inst"
shell::git::commit::message::sync >/dev/null 2>&1
t_eq "sync: your own file is never touched" "$before" "$(cat "$SHELL_GIT_COMMIT_MESSAGES_USER_FILE")"
rm -f "$SHELL_GIT_COMMIT_MESSAGES_USER_FILE" "$inst.bak"

shell::git::commit::message::sync -n --bogus >/dev/null 2>&1
t_eq "sync: an unknown option exits 2" "2" "$?"
t_rc "sync -h" 0 shell::git::commit::message::sync -h
t_has "sync help" "never touched" "$T_OUT"
SHELL_GIT_COMMIT_MESSAGES_SOURCE="$tdir/no-source.txt" shell::git::commit::message::sync >/dev/null 2>&1
t_eq "sync: a missing source exits 1" "1" "$?"
: >"$tdir/a-file"
out="$(SHELL_GIT_COMMIT_MESSAGES_FILE="$tdir/a-file/sub/messages.txt" shell::git::commit::message::sync 2>&1)"
t_has "sync: a destination that cannot be created is reported" "Cannot create the directory" "$out"
SHELL_GIT_COMMIT_MESSAGES_FILE="$tdir/a-file/sub/messages.txt" shell::git::commit::message::sync >/dev/null 2>&1
t_eq "sync: ...exit 1" "1" "$?"
out="$(SHELL_GIT_COMMIT_MESSAGES_FILE="$tdir/custom/place.txt" shell::git::commit::message::sync 2>&1)"
t_rc "sync: a destination you chose is honoured" 0 cmp -s "$SHELL_GIT_COMMIT_MESSAGES_SOURCE" "$tdir/custom/place.txt"
out="$(SHELL_GIT_COMMIT_MESSAGES_FILE="$SHELL_GIT_COMMIT_MESSAGES_SOURCE" shell::git::commit::message::sync 2>&1)"
t_has "sync: source and destination being the same file is a no-op" "Already up to date" "$out"
rm -rf "$SHELL_CONFIG_DIR/git"

# --- performance guard: ONE awk pass per call, however many templates there are ------------------------------
real_awk="$(command -v awk)"
mkdir "$HOME/awkbin"
printf '#!/bin/sh\necho x >>"%s/awk.calls"\nexec "%s" "$@"\n' "$HOME" "$real_awk" >"$HOME/awkbin/awk"
chmod +x "$HOME/awkbin/awk"
{
	printf '[Scaling]\n'
	i=0
	while [ "$i" -lt 1600 ]; do
		printf ':rocket:|chore|add template number %s for the scaling check\n' "$i"
		i=$((i + 1))
	done
} >"$tdir/big.txt"
calls() { cat "$HOME/awk.calls" 2>/dev/null | wc -l | tr -d ' '; }
saved_path="$PATH"
export PATH="$HOME/awkbin:$PATH"
rm -f "$HOME/awk.calls"
SHELL_GIT_COMMIT_MESSAGES_FILE="$tdir/big.txt" shell::git::commit::message::scan categories >/dev/null 2>&1
t_eq "performance: listing categories of 1600 templates is ONE awk process" "1" "$(calls)"
rm -f "$HOME/awk.calls"
n="$(SHELL_GIT_COMMIT_MESSAGES_FILE="$tdir/big.txt" shell::git::commit::message::scan render Scaling false | wc -l | tr -d ' ')"
t_eq "performance: rendering a category of 1600 templates is ONE awk process" "1" "$(calls)"
t_eq "performance: ...and all 1600 come out" "1600" "$n"
rm -f "$HOME/awk.calls"
shell::git::commit::message::catalog >/dev/null 2>&1
t_eq "performance: the whole built-in catalog is ONE awk process" "1" "$(calls)"
rm -f "$HOME/awk.calls"
reset_fzf
FAKE_FZF_PICKS="$(printf '%s\n%s' "$cat" "feat: :sparkles: add user-facing support for the requested workflow")" shell::git::commit::message::base >/dev/null 2>&1
t_eq "performance: a whole menu session is two awk processes (categories, then the chosen one)" "2" "$(calls)"
export PATH="$saved_path"

t_done
