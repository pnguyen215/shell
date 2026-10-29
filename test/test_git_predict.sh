#!/usr/bin/env bash
# shell::git::commit::predict — the prediction engine (candidates), the branch → issue
# guess, the shared helpers extracted from sgcf, and the interactive flow (pick a
# prediction / enter manually / edit / back). fzf is faked (scripted picks, then ESC) and
# text prompts read stdin. Most runs use -n; the real-commit cases stub the push/Telegram step.
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
M="Enter manually (sgcf style)"
nl='
'
tab="$(printf '\t')"

# run_predict <picks> <stdin text> [predict args...]  -> combined output
run_predict() {
	local picks="$1" input="$2"
	shift 2
	reset_fzf
	printf '%s' "$input" | FAKE_FZF_PICKS="$picks" shell::git::commit::predict "$@" 2>&1
}

# cand <branch> <hint> <name-status lines...>  -> engine output
cand() {
	local branch="$1" hint="$2"
	shift 2
	printf '%s\n' "$@" | shell::git::commit::predict::candidates --branch "$branch" --hint "$hint"
}

# --- shared helpers (extracted from sgcf) -----------------------------------------------------
t_eq "emoji: feat" ":sparkles:" "$(shell::git::commit::emoji feat)"
t_eq "emoji: a type with a space" ":tada:" "$(shell::git::commit::emoji "initial source")"
t_eq "emoji: unknown type is empty" "" "$(shell::git::commit::emoji nope)"
t_eq "emoji: no prefix matching" "" "$(shell::git::commit::emoji fea)"
t_eq "types: 26 of them" "26" "$(shell::git::commit::types | wc -l | tr -d ' ')"
t_eq "types: feat first (menu order)" "feat" "$(shell::git::commit::types | head -n 1)"
t_eq "types: release last" "release" "$(shell::git::commit::types | tail -n 1)"
t_eq "types: every type has an emoji" "0" "$(shell::git::commit::types | while IFS= read -r ty; do [ -z "$(shell::git::commit::emoji "$ty")" ] && echo "$ty"; done | wc -l | tr -d ' ')"
t_eq "format: sgcf style" "feat: add x #1" "$(shell::git::commit::predict::format feat "add x" "#1")"
t_eq "format: issue is optional" "fix: y" "$(shell::git::commit::predict::format fix y)"
t_eq "format: unknown type has no leading space" "nope: y" "$(shell::git::commit::predict::format nope y)"

# --- emoji: off by default, after the colon when on, never before the type (Conventional Commits) --
t_eq "emoji setting: off by default" "false" "$(env -u SHELL_GIT_COMMIT_EMOJI SHELL_AUTO_INSTALL_DEPS=0 bash -c '. "$SHELL_TEST_ROOT/src/shell.sh" >/dev/null 2>&1; printf %s "$SHELL_GIT_COMMIT_EMOJI"')"
emoji_on() { SHELL_GIT_COMMIT_EMOJI="$1" shell::git::commit::emoji::enabled "${2-}" && echo on || echo off; }
t_eq "enabled: false is off" "off" "$(emoji_on false)"
t_eq "enabled: empty is off" "off" "$(emoji_on '')"
t_eq "enabled: garbage is off" "off" "$(emoji_on maybe)"
t_eq "enabled: 0 / no / off are off" "off off off" "$(emoji_on 0) $(emoji_on no) $(emoji_on off)"
t_eq "enabled: true / 1 / yes / on are on" "on on on on" "$(emoji_on true) $(emoji_on 1) $(emoji_on yes) $(emoji_on on)"
t_eq "enabled: any case" "on on" "$(emoji_on TRUE) $(emoji_on Yes)"
t_eq "enabled: an explicit true beats the setting" "on" "$(emoji_on false true)"
t_eq "enabled: an explicit false beats the setting" "off" "$(emoji_on true false)"

t_eq "resolve: a conventional label is unchanged" "feat" "$(shell::git::commit::type::resolve feat)"
t_eq "resolve: a label with a space becomes a valid type" "chore(init)" "$(shell::git::commit::type::resolve "initial source")"
t_eq "resolve: WIP" "chore(wip)" "$(shell::git::commit::type::resolve WIP)"
t_eq "resolve: dependency" "build(deps)" "$(shell::git::commit::type::resolve dependency)"
t_eq "resolve: an unknown type is returned unchanged" "ci" "$(shell::git::commit::type::resolve ci)"
# Every menu label must map to something shell::git::commit::message::validate accepts.
map_file="$HOME/map.txt"
{
	echo "[Mapping]"
	i=0
	shell::git::commit::types | while IFS= read -r ty; do
		i=$((i + 1))
		printf '%s|%s|check mapping number %d here\n' "$(shell::git::commit::emoji "$ty")" "$(shell::git::commit::type::resolve "$ty")" "$i"
	done
} >"$map_file"
out="$(shell::git::commit::message::validate "$map_file" 2>&1)"
t_has "resolve: all 26 labels map to a valid type, scope and emoji" "26 template(s) in 1 categories, 0 problem(s)" "$out"

t_eq "format: the emoji goes after the colon" "feat: :sparkles: add x #1" "$(shell::git::commit::predict::format feat "add x" "#1" true)"
t_eq "format: a mapped type keeps the type first" "chore(init): :tada: first commit" "$(shell::git::commit::predict::format "initial source" "first commit" "" true)"
t_eq "format: off is plain, with a mapped type" "chore(init): first commit" "$(shell::git::commit::predict::format "initial source" "first commit")"
t_eq "format: the setting turns the emoji on" "feat: :sparkles: add x" "$(SHELL_GIT_COMMIT_EMOJI=true shell::git::commit::predict::format feat "add x")"
t_eq "format: an explicit false beats the setting" "feat: add x" "$(SHELL_GIT_COMMIT_EMOJI=true shell::git::commit::predict::format feat "add x" "" false)"
t_eq "format: no known emoji, no emoji (and no stray space)" "nope: y" "$(shell::git::commit::predict::format nope y "" true)"
t_eq "format: every label is a Conventional Commits header, emoji on or off" "0" "$(
	for on in true false; do
		shell::git::commit::types | while IFS= read -r ty; do shell::git::commit::predict::format "$ty" "some description" "" "$on"; done
	done | grep -cvE '^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([a-z0-9.-]+\))?: (:[a-z0-9_+-]+: )?some description$'
)"

# --- branch → issue ---------------------------------------------------------------------------
t_eq "issue: feat/123-login" "#123" "$(shell::git::commit::predict::issue feat/123-login)"
t_eq "issue: fix/issue-45" "#45" "$(shell::git::commit::predict::issue fix/issue-45)"
t_eq "issue: tracker key" "ABC-77" "$(shell::git::commit::predict::issue feature/ABC-77-thing)"
t_eq "issue: #9 segment" "#9" "$(shell::git::commit::predict::issue 'chore/#9-cleanup')"
t_eq "issue: main has none" "" "$(shell::git::commit::predict::issue main)"
t_eq "issue: a version is not an issue" "" "$(shell::git::commit::predict::issue release/1.2.3)"
t_eq "issue: a year is not an issue" "" "$(shell::git::commit::predict::issue 2024-cleanup)"
t_eq "issue: 2fa is not an issue" "" "$(shell::git::commit::predict::issue feat/2fa-login)"
t_eq "issue: empty branch" "" "$(shell::git::commit::predict::issue '')"

# --- the engine: what is the change? ----------------------------------------------------------
out="$(cand "" "" "A${tab}src/login.sh")"
t_eq "engine: a new code file is a feat" "feat|add login" "$(printf '%s\n' "$out" | head -n 1)"
t_eq "engine: 3 predictions by default" "3" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"

out="$(cand "" "" "M${tab}src/login.sh")"
t_eq "engine: modified code → improvement first" "improvement|improve login" "$(printf '%s\n' "$out" | head -n 1)"
t_has "engine: ...with fix and refactor as alternatives" "fix|fix login" "$out"

out="$(cand "" " fix the crash " "M${tab}src/login.sh")"
t_eq "engine: fix words in the added lines → fix first" "fix|fix login" "$(printf '%s\n' "$out" | head -n 1)"
out="$(cand "" " prefix suffix debugging " "M${tab}src/login.sh")"
t_eq "engine: ...whole words only (prefix is not fix)" "improvement|improve login" "$(printf '%s\n' "$out" | head -n 1)"
out="$(cand "" " fix " "A${tab}src/new.sh")"
t_eq "engine: ...and only for modified files" "feat|add new" "$(printf '%s\n' "$out" | head -n 1)"

t_eq "engine: README → docs" "docs|update documentation for README" "$(cand "" "" "M${tab}README.md" | head -n 1)"
t_eq "engine: docs/ → docs" "docs|add documentation for guide" "$(cand "" "" "A${tab}docs/guide.md" | head -n 1)"
t_eq "engine: test file → test" "test|update tests for test_git" "$(cand "" "" "M${tab}test/test_git.sh" | head -n 1)"
t_eq "engine: _test suffix → test" "test|add tests for login_test" "$(cand "" "" "A${tab}pkg/login_test.go" | head -n 1)"
t_eq "engine: lockfiles → dependency" "dependency|update dependencies (go)" "$(cand "" "" "M${tab}go.mod" "M${tab}go.sum" | head -n 1)"
t_eq "engine: workflow → build" "build|update build configuration (ci)" "$(cand "" "" "M${tab}.github/workflows/ci.yml" | head -n 1)"
t_eq "engine: Makefile → build" "build|update build configuration (Makefile)" "$(cand "" "" "M${tab}Makefile" | head -n 1)"
t_eq "engine: Dockerfile → deployment" "deployment|update deployment configuration (Dockerfile)" "$(cand "" "" "M${tab}Dockerfile" | head -n 1)"
t_eq "engine: css → style" "style|update styles of app" "$(cand "" "" "M${tab}web/app.css" | head -n 1)"
t_eq "engine: dotfile → config" "config|update configuration (.gitignore)" "$(cand "" "" "M${tab}.gitignore" | head -n 1)"
t_eq "engine: locales → localization" "localization|update translations (vi)" "$(cand "" "" "M${tab}locales/vi.json" | head -n 1)"
t_eq "engine: only deletions → remove" "remove|remove old" "$(cand "" "" "D${tab}src/old.sh" | head -n 1)"
t_eq "engine: ...then a clean-up" "refactor|clean up old" "$(cand "" "" "D${tab}src/old.sh" | sed -n 2p)"
t_has "engine: a rename suggests refactor" "refactor|refactor b" "$(cand "" "" "R100${tab}src/a.sh${tab}src/b.sh")"
t_eq "engine: initial commit" "initial source|bootstrap the project" "$(printf 'A\tmain.sh\n' | shell::git::commit::predict::candidates --initial true | head -n 1)"

# Mixed commits: code outweighs the rest; otherwise every kind of file is offered.
out="$(cand "" "" "A${tab}src/login.sh" "A${tab}test/test_login.sh" "M${tab}README.md")"
t_eq "engine: code + tests + docs → feat" "feat|add login" "$(printf '%s\n' "$out" | head -n 1)"
out="$(cand "" "" "M${tab}README.md" "A${tab}test/test_a.sh")"
t_eq "engine: docs and test only: docs first (tie)" "docs|update documentation for README" "$(printf '%s\n' "$out" | sed -n 1p)"
t_eq "engine: ...each described by its own files" "test|add tests for test_a" "$(printf '%s\n' "$out" | sed -n 2p)"
out="$(cand "" "" "M${tab}README.md" "M${tab}docs/a.md" "M${tab}docs/b.md" "M${tab}src/x.sh")"
t_eq "engine: docs outweigh one code file" "docs" "$(printf '%s\n' "$out" | head -n 1 | cut -d'|' -f1)"

# A mixed change: "add" talks only about what was added.
out="$(cand "" "" "M${tab}src/hello.sh" "A${tab}src/bye.sh")"
t_eq "engine: feat names only the added files" "feat|add bye" "$(printf '%s\n' "$out" | head -n 1)"
t_eq "engine: ...while improvement names the whole change" "improvement|improve hello, bye" "$(printf '%s\n' "$out" | sed -n 2p)"

# Many files → the common directory.
out="$(cand "" "" "A${tab}src/lang/a.sh" "A${tab}src/lang/b.sh" "A${tab}src/lang/c.sh" "A${tab}src/lang/d.sh")"
t_eq "engine: 4 files → common directory" "feat|add src/lang (4 files)" "$(printf '%s\n' "$out" | head -n 1)"
out="$(cand "" "" "A${tab}a/x.sh" "A${tab}b/y.sh" "A${tab}c/z.sh" "A${tab}d/w.sh")"
t_eq "engine: no common directory → a count" "feat|add 4 files" "$(printf '%s\n' "$out" | head -n 1)"

# Branch prefix wins.
t_eq "engine: fix/ branch" "fix" "$(cand fix/12-crash "" "A${tab}src/new.sh" | head -n 1 | cut -d'|' -f1)"
t_eq "engine: hotfix- branch" "fix" "$(cand hotfix-urgent "" "M${tab}src/a.sh" | head -n 1 | cut -d'|' -f1)"
t_eq "engine: feature/ branch" "feat" "$(cand feature/x "" "M${tab}src/a.sh" | head -n 1 | cut -d'|' -f1)"
t_eq "engine: docs/ branch" "docs" "$(cand docs/readme "" "M${tab}src/a.sh" | head -n 1 | cut -d'|' -f1)"
t_eq "engine: ci/ branch → build" "build" "$(cand ci/speed "" "M${tab}src/a.sh" | head -n 1 | cut -d'|' -f1)"
t_eq "engine: unknown prefix is ignored" "improvement" "$(cand banana/split "" "M${tab}src/a.sh" | head -n 1 | cut -d'|' -f1)"
t_eq "engine: main is ignored" "improvement" "$(cand main "" "M${tab}src/a.sh" | head -n 1 | cut -d'|' -f1)"
t_eq "engine: no duplicate types" "0" "$(cand fix/1 " fix " "M${tab}src/a.sh" | cut -d'|' -f1 | sort | uniq -d | wc -l | tr -d ' ')"

# Safety: whatever the file is called, the description is safe to paste into a message.
out="$(cand "" "" "A${tab}src/we\"ird\$(x)\`y\`;|n.sh")"
t_lacks "engine: no double quote in the output" '"' "$out"
t_lacks "engine: no dollar in the output" '$' "$out"
t_lacks "engine: no backtick in the output" '`' "$out"
t_eq "engine: one line per prediction (no pipe injected)" "3" "$(printf '%s\n' "$out" | awk -F'|' 'NF == 2' | wc -l | tr -d ' ')"

# Counting and nothing to predict.
t_eq "engine: --count 1" "1" "$(printf 'A\ta.sh\n' | shell::git::commit::predict::candidates --count 1 | wc -l | tr -d ' ')"
t_eq "engine: --count 9 is capped by what is relevant" "5" "$(printf 'A\ta.sh\n' | shell::git::commit::predict::candidates --count 9 | wc -l | tr -d ' ')"
t_eq "engine: empty input, empty output" "" "$(printf '' | shell::git::commit::predict::candidates)"
t_eq "engine: garbage lines are skipped" "" "$(printf 'hello\n' | shell::git::commit::predict::candidates)"
printf 'A\ta.sh\n' | shell::git::commit::predict::candidates --count 0 >/dev/null 2>&1
t_eq "engine: --count 0 is invalid" "2" "$?"
printf 'A\ta.sh\n' | shell::git::commit::predict::candidates --count 10 >/dev/null 2>&1
t_eq "engine: --count 10 is invalid" "2" "$?"
printf 'A\ta.sh\n' | shell::git::commit::predict::candidates --count x >/dev/null 2>&1
t_eq "engine: --count x is invalid" "2" "$?"
printf 'A\ta.sh\n' | shell::git::commit::predict::candidates --branch >/dev/null 2>&1
t_eq "engine: an option without a value is invalid" "2" "$?"
printf 'A\ta.sh\n' | shell::git::commit::predict::candidates --bogus >/dev/null 2>&1
t_eq "engine: unknown option is invalid" "2" "$?"

# --- guards -----------------------------------------------------------------------------------
t_rc "predict -h" 0 shell::git::commit::predict -h
t_has "predict help mentions sgcf" "sgcf" "$T_OUT"
t_has "predict help explains Back" "Back" "$T_OUT"
(cd "$HOME" && run_predict "" "" -n >/dev/null)
t_eq "predict: outside a git repository fails" "1" "$?"
mkdir "$HOME/repo" && git -C "$HOME/repo" init -q && cd "$HOME/repo" || exit 1
git config user.email t@example.com && git config user.name Tester
git checkout -q -b feat/7-hello 2>/dev/null
run_predict "" "" --bogus >/dev/null
t_eq "predict: unknown option is invalid" "2" "$?"
run_predict "" "" -c >/dev/null
t_eq "predict: -c needs a value" "2" "$?"
run_predict "" "" -c 0 >/dev/null
t_eq "predict: -c 0 is invalid" "2" "$?"

# --- no changes at all: straight to manual entry ----------------------------------------------
run_predict "" "" --list >/dev/null
t_eq "list: nothing to predict returns RETURN_EMPTY" "$RETURN_EMPTY" "$?"
out="$(run_predict "feat${nl}Commit" "first thing${nl}#1${nl}" -n)"
t_has "no changes: says so" "No changes found to predict from" "$out"
t_has "no changes: sgcf-style manual entry" 'git commit -m "feat: first thing #1"' "$out"
t_eq "no changes: no predictions menu, so the type menu is the first" "feat" "$(head -n 1 "$HOME/stdin.1")"
out="$(run_predict "$B" "" -n)"
t_has "no changes: Back at the type menu leaves" "Commit cancelled" "$out"
t_lacks "no changes: ...without committing" "git commit" "$out"

# --- predictions from the staged diff ----------------------------------------------------------
mkdir -p src && echo 'echo hello' >src/hello.sh && git add src/hello.sh
git commit -q -m "base" 2>/dev/null
echo 'echo hello again' >src/hello.sh && echo 'echo bye' >src/bye.sh && git add src/hello.sh src/bye.sh

list="$(shell::git::commit::predict --list 2>&1)"
t_eq "list: 3 predictions" "3" "$(printf '%s\n' "$list" | wc -l | tr -d ' ')"
t_eq "list: best guess (branch feat/ + a new file)" "feat: add bye #7" "$(printf '%s\n' "$list" | head -n 1)"
t_has "list: the issue comes from the branch" " #7" "$(printf '%s\n' "$list" | sed -n 2p)"
t_eq "list --emoji: the emoji follows the type" "feat: :sparkles: add bye #7" "$(shell::git::commit::predict --list --emoji 2>&1 | head -n 1)"
t_eq "list: SHELL_GIT_COMMIT_EMOJI=true does the same" "feat: :sparkles: add bye #7" "$(SHELL_GIT_COMMIT_EMOJI=true shell::git::commit::predict --list 2>&1 | head -n 1)"
t_eq "list --no-emoji beats the setting" "feat: add bye #7" "$(SHELL_GIT_COMMIT_EMOJI=true shell::git::commit::predict --list --no-emoji 2>&1 | head -n 1)"
t_eq "list: no prediction starts with an emoji" "0" "$(shell::git::commit::predict --list --emoji 2>&1 | grep -c '^:')"
t_eq "list: -c 1" "1" "$(shell::git::commit::predict --list -c 1 2>&1 | wc -l | tr -d ' ')"
t_eq "list: prints nothing else (no logging noise)" "0" "$(printf '%s\n' "$list" | grep -c 'WARN\|warn\|INFO\|info')"
first="$(printf '%s\n' "$list" | head -n 1)"
second="$(printf '%s\n' "$list" | sed -n 2p)"

# Pick a prediction.
out="$(run_predict "${first}${nl}Commit" "" -n)"
t_has "pick: commits the predicted message" "git commit -m \"$first\"" "$out"
t_lacks "pick: nothing to type" "Enter a concise" "$out"
t_has "pick: the menu offers the predictions" "$second" "$(cat "$HOME/stdin.1")"
t_eq "pick: ...then the manual entry" "$M" "$(sed -n 4p "$HOME/stdin.1")"
t_eq "pick: ...then Back (last, so Enter never lands on it)" "$B" "$(tail -n 1 "$HOME/stdin.1")"
t_has "pick: the menu has a prompt" "--prompt=Predicted commit message: " "$(cat "$HOME/args.1")"
t_eq "pick: the confirmation offers Commit first" "Commit" "$(head -n 1 "$HOME/stdin.2")"
t_has "pick: ...Edit message" "Edit message" "$(cat "$HOME/stdin.2")"
t_has "pick: ...and Abort" "Abort" "$(cat "$HOME/stdin.2")"

out="$(run_predict "${second}${nl}Commit" "" -n)"
t_has "pick: the second prediction works too" "git commit -m \"$second\"" "$out"

# Abort / Back / ESC.
out="$(run_predict "${first}${nl}Abort" "" -n)"
t_has "pick: Abort" "Commit aborted" "$out"
t_lacks "pick: ...does not commit" "git commit" "$out"
out="$(run_predict "$B" "" -n)"
t_has "pick: Back in the predictions leaves" "Commit cancelled" "$out"
t_lacks "pick: ...without committing" "git commit" "$out"
out="$(run_predict "" "" -n)"
t_has "pick: ESC aborts" "No commit message selected" "$out"
t_lacks "pick: ...without committing" "git commit" "$out"
out="$(run_predict "${first}${nl}${B}${nl}${second}${nl}Commit" "" -n)"
t_has "pick: Back at the confirmation picks again" "git commit -m \"$second\"" "$out"
t_lacks "pick: ...and the first one is not committed" "git commit -m \"$first\"" "$out"
out="$(run_predict "${first}${nl}" "" -n)"
t_lacks "pick: ESC at the confirmation does not commit" "git commit" "$out"

# Edit the predicted message.
out="$(run_predict "${first}${nl}Edit message${nl}Commit" "my own words${nl}" -n)"
t_has "edit: the typed message is committed" 'git commit -m "my own words"' "$out"
t_lacks "edit: ...instead of the prediction" "$first\"" "$out"
out="$(run_predict "${first}${nl}Edit message${nl}Commit" "${nl}" -n)"
t_has "edit: Enter keeps the prediction" "git commit -m \"$first\"" "$out"
out="$(run_predict "${first}${nl}Edit message${nl}Commit" ":back${nl}" -n)"
t_has "edit: :back keeps the prediction" "git commit -m \"$first\"" "$out"

# --- manual entry: exactly the sgcf steps ------------------------------------------------------
out="$(run_predict "${M}${nl}fix${nl}Commit" "a real fix${nl}#99${nl}" -n)"
t_has "manual: sgcf-style message" 'git commit -m "fix: a real fix #99"' "$out"
t_eq "manual: the type menu is sgcf's (feat first)" "feat" "$(head -n 1 "$HOME/stdin.2")"
t_eq "manual: ...with all 26 types and Back" "27" "$(wc -l <"$HOME/stdin.2" | tr -d ' ')"
t_has "manual: ...and a type prompt" "--prompt=Commit type: " "$(cat "$HOME/args.2")"

out="$(run_predict "${M}${nl}feat${nl}Commit" "thing${nl}#7${nl}" -n --emoji)"
t_has "manual --emoji: the emoji is after the colon" 'git commit -m "feat: :sparkles: thing #7"' "$out"
t_lacks "manual --emoji: ...never before the type" '-m ":sparkles:' "$out"
out="$(run_predict "${M}${nl}initial source${nl}Commit" "first commit${nl}#1${nl}" -n)"
t_has "manual: a label that is not a type is mapped onto one" 'git commit -m "chore(init): first commit #1"' "$out"
out="$(run_predict "${M}${nl}WIP${nl}Commit" "half done${nl}#1${nl}" -n --emoji)"
t_has "manual: ...and keeps its emoji when they are on" 'git commit -m "chore(wip): :construction: half done #1"' "$out"

out="$(run_predict "${M}${nl}feat${nl}Commit" "thing${nl}${nl}" -n)"
t_has "manual: Enter at the issue prompt keeps the branch's issue" 'git commit -m "feat: thing #7"' "$out"
out="$(run_predict "${M}${nl}feat${nl}Commit" "thing${nl}ABC-1${nl}" -n)"
t_has "manual: ...which can be overwritten" 'git commit -m "feat: thing ABC-1"' "$out"
out="$(run_predict "${M}${nl}feat${nl}Commit" "${nl}real${nl}#2${nl}" -n)"
t_has "manual: an empty description is refused" "This value cannot be empty" "$out"
t_has "manual: ...and asked again" 'git commit -m "feat: real #2"' "$out"

# Back through the manual steps.
out="$(run_predict "${M}${nl}${B}${nl}${first}${nl}Commit" "" -n)"
t_has "manual: Back at the type menu returns to the predictions" "git commit -m \"$first\"" "$out"
out="$(run_predict "${M}${nl}feat${nl}fix${nl}Commit" ":back${nl}better${nl}#3${nl}" -n)"
t_has "manual: :back at the description returns to the type menu" 'git commit -m "fix: better #3"' "$out"
out="$(run_predict "${M}${nl}feat${nl}Commit" "first${nl}:back${nl}second${nl}#4${nl}" -n)"
t_has "manual: :back at the issue returns to the description" 'git commit -m "feat: second #4"' "$out"
out="$(run_predict "${M}${nl}feat${nl}${B}${nl}Commit" "kept${nl}#5${nl}${nl}" -n)"
t_has "manual: Back at the confirmation returns to the issue (value kept)" 'git commit -m "feat: kept #5"' "$out"
out="$(run_predict "${M}${nl}feat${nl}Edit message${nl}Commit" "kept${nl}#5${nl}tweaked: ok${nl}" -n)"
t_has "manual: the message can still be edited" 'git commit -m "tweaked: ok"' "$out"
out="$(run_predict "${M}${nl}feat" "" -n)"
t_has "manual: EOF at the description aborts" "Input cancelled" "$out"
t_lacks "manual: ...without committing" "git commit" "$out"
out="$(run_predict "${M}${nl}" "" -n)"
t_has "manual: ESC at the type menu aborts" "No commit type selected" "$out"

# --- the dry-run command is shell-safe ---------------------------------------------------------
out="$(run_predict "${M}${nl}feat${nl}Commit" 'say "hi" $HOME `id`'"${nl}#1${nl}" -n)"
t_has "dry-run: quotes, \$ and backticks are escaped in the printed command" 'git commit -m "feat: say \"hi\" \$HOME \`id\` #1"' "$out"

# --- a real commit -----------------------------------------------------------------------------
# The push / Telegram step is interactive and networked: stub it, and check it is reached.
shell::git::commit::publish() { printf 'PUBLISHED<%s>\n' "$1"; }

out="$(run_predict "${first}${nl}Commit" "")"
t_has "commit: the commit succeeds" "Commit created: $first" "$out"
t_eq "commit: ...with exactly the predicted subject" "$first" "$(git log -1 --format=%s)"
t_has "commit: ...then the Telegram + push step runs" "PUBLISHED<$first>" "$out"
t_eq "commit: ...and it consumed the staged files" "" "$(git diff --cached --name-only)"

echo 'echo x' >src/q.sh && git add src/q.sh
out="$(run_predict "${M}${nl}fix${nl}Commit" 'quote " and $HOME and `id` and \ done'"${nl}#8${nl}")"
t_eq "commit: a nasty message is stored verbatim (no shell interpretation)" 'fix: quote " and $HOME and `id` and \ done #8' "$(git log -1 --format=%s)"
t_has "commit: ...and still published" "PUBLISHED<" "$out"

# A failing commit stops the flow before the publish step.
git config --local core.hooksPath "$HOME/nohooks"
mkdir "$HOME/nohooks"
printf '#!/bin/sh\nexit 1\n' >"$HOME/nohooks/commit-msg"
chmod +x "$HOME/nohooks/commit-msg"
echo 'echo y' >src/r.sh && git add src/r.sh
out="$(run_predict "${M}${nl}fix${nl}Commit" "will be rejected${nl}#1${nl}")"
t_lacks "commit: a rejected commit is not published" "PUBLISHED<" "$out"
run_predict "${M}${nl}fix${nl}Commit" "will be rejected${nl}#1${nl}" >/dev/null
t_eq "commit: ...and the failure is returned" "1" "$?"
git config --local --unset core.hooksPath

# --- nothing staged: the working tree is analysed ----------------------------------------------
git reset -q
rm -f src/r.sh
echo 'echo wip' >src/hello.sh
echo 'brand new' >src/untracked.sh
out="$(run_predict "$B" "" -n)"
t_has "worktree: warns that nothing is staged" "Nothing is staged" "$out"
list="$(shell::git::commit::predict --list 2>&1)"
t_eq "worktree: tracked and untracked files are both analysed" "feat: add untracked" "$(printf '%s\n' "$list" | head -n 1 | sed 's/ #.*//')"

# --- sgcf still works on top of the shared helpers ---------------------------------------------
reset_fzf
out="$(printf 'my change\n#12\n' | FAKE_FZF_PICKS="feat${nl}Commit" shell::git::commit::create -n 2>&1)"
t_has "predict help documents the emoji switch" "--no-emoji" "$(shell::git::commit::predict -h 2>&1)"
t_has "sgcf: unchanged by the refactor" 'git commit -m "feat: my change #12"' "$out"
t_eq "sgcf: same type menu (26 types + Back)" "27" "$(wc -l <"$HOME/stdin.1" | tr -d ' ')"
t_eq "sgcf: ...in the same order" "$(shell::git::commit::types | head -n 3 | tr '\n' ',')" "$(head -n 3 "$HOME/stdin.1" | tr '\n' ',')"

t_done
