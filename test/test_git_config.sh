#!/usr/bin/env bash
# shell::git::config::{list,get,set,unset,user::setup,fzf} against a real git, with an isolated
# HOME (so ~/.gitconfig is a temp file). fzf is faked (scripted picks, then ESC) and records its
# arguments, so the preview command can be checked.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

export GIT_CONFIG_NOSYSTEM=1
unset XDG_CONFIG_HOME GIT_CONFIG_GLOBAL

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
export SHELL_OS_TYPE=linux

reset_fzf() {
	find "$HOME" -maxdepth 1 \( -name 'stdin.*' -o -name 'args.*' \) -delete
	rm -f "$FAKE_FZF_STATE"
}
nl='
'
tab="$(printf '\t')"
B="$SHELL_FZF_BACK_LABEL"
# r <cmd...> -> output, then RC=<n>
r() {
	"$@" 2>&1
	echo "RC=$?"
}
mkrepo() {
	cd "$HOME" && rm -rf "$HOME/repo" "$HOME/.gitconfig" "$HOME/pwned" && mkdir "$HOME/repo" && cd "$HOME/repo" || exit 1
	git init -q
}
gl() { git config --local --get -- "$1" 2>/dev/null; }
gg() { git config --global --get -- "$1" 2>/dev/null; }

# =============================== validate ===============================================
for ok in user.name core.autocrlf init.defaultBranch remote.origin.url branch.feature/x.remote "url.https://h.com/.insteadOf" a-b.c-d; do
	shell::git::config::validate key "$ok"
	t_eq "valid key [$ok]" "0" "$?"
done
for bad in "" nodot "-x.y" ".a.b" "a.b." "a b.c" "a.1b" "a.b c" $'a.b\nc' "a;b.c" "a.b;c" "--global"; do
	shell::git::config::validate key "$bad"
	t_eq "invalid key [$bad]" "1" "$?"
done
for ok in "a@b.co" "first.last+tag@sub.example.org"; do
	shell::git::config::validate email "$ok"
	t_eq "valid email [$ok]" "0" "$?"
done
for bad in "" "a" "a@b" "@b.c" "a@" "a b@c.d" "a@b@c.d" "<a@b.c>"; do
	shell::git::config::validate email "$bad"
	t_eq "invalid email [$bad]" "1" "$?"
done
for ok in main feature/x release-1.0; do
	shell::git::config::validate branch "$ok"
	t_eq "valid branch [$ok]" "0" "$?"
done
for bad in "" "-x" "bad name" "a..b" "x~1" "a:b"; do
	shell::git::config::validate branch "$bad"
	t_eq "invalid branch [$bad]" "1" "$?"
done
for ok in true input false; do
	shell::git::config::validate autocrlf "$ok"
	t_eq "valid autocrlf [$ok]" "0" "$?"
done
shell::git::config::validate autocrlf maybe
t_eq "invalid autocrlf" "1" "$?"
shell::git::config::validate name "John <j@x.io>"
t_eq "name with <> rejected" "1" "$?"
shell::git::config::validate nonsense x
t_eq "unknown kind rejected" "1" "$?"

# =============================== list ===================================================
mkrepo
git config --global user.name "Glob"
git config --local user.email "loc@ex.com"
out="$(r shell::git::config::list)"
t_has "list: exit 0" "RC=0" "$out"
t_has "list: shows the origin file (.git/config)" "file:.git/config" "$out"
t_has "list: shows a local entry" "user.email=loc@ex.com" "$out"
t_has "list: git's own entries too" "core.bare=false" "$out"
t_lacks "list: local scope does not include global entries" "Glob" "$out"
t_eq "list: origin and entry are tab-separated" "file:.git/config${tab}user.email=loc@ex.com" "$(shell::git::config::list 2>/dev/null | grep 'user.email')"
t_has "list: starts with the origin (pipeable, no log noise)" "file:" "$(shell::git::config::list 2>/dev/null | head -n 1)"

out="$(r shell::git::config::list --global)"
t_eq "list --global: tab-separated" "file:$HOME/.gitconfig${tab}user.name=Glob" "$(printf '%s\n' "$out" | grep 'user.name')"
t_lacks "list --global: no local entries" "loc@ex.com" "$out"
out="$(r shell::git::config::list -g)"
t_has "list -g: short flag" "user.name=Glob" "$out"

out="$(r shell::git::config::list -n)"
t_has "list -n: prints the command" "git config --local --list --show-origin" "$out"
t_lacks "list -n: lists nothing" "core.bare" "$out"
out="$(r shell::git::config::list -g -n)"
t_has "list -g -n" "git config --global --list --show-origin" "$out"

rm -f "$HOME/.gitconfig"
out="$(r shell::git::config::list --global)"
t_has "list --global without a file: explained" "No global Git configuration found" "$out"
t_has "list --global without a file: exit 1" "RC=1" "$out"
: >"$HOME/.gitconfig"
out="$(r shell::git::config::list --global)"
t_eq "list --global with an empty file: exit 0, prints nothing" "RC=0" "$out"

cd "$HOME" && mkdir -p "$HOME/norepo" && cd "$HOME/norepo" || exit 1
out="$(r shell::git::config::list)"
t_has "list outside a repo: refused" "Not inside a Git repository" "$out"
t_has "list outside a repo: exit 1" "RC=1" "$out"
git config --global user.name "Glob"
out="$(r shell::git::config::list --global)"
t_has "list --global outside a repo works" "user.name=Glob" "$out"
out="$(r shell::git::config::list extra)"
t_has "list: stray argument" "RC=2" "$out"
out="$(r shell::git::config::list --bogus)"
t_has "list: unknown option" "RC=2" "$out"
t_rc "list -h" 0 shell::git::config::list -h

# =============================== get ====================================================
mkrepo
git config --global user.name "Glob"
git config --global init.defaultBranch trunk
git config --local user.email "loc@ex.com"
git config --local user.name "Local Name"
t_eq "get: local value" "loc@ex.com" "$(shell::git::config::get user.email 2>/dev/null)"
t_eq "get: effective value (local overrides global)" "Local Name" "$(shell::git::config::get user.name 2>/dev/null)"
t_eq "get -g: the global one" "Glob" "$(shell::git::config::get -g user.name 2>/dev/null)"
t_eq "get: falls back to global when not set locally" "trunk" "$(shell::git::config::get init.defaultBranch 2>/dev/null)"
t_eq "get: option after the key" "Glob" "$(shell::git::config::get user.name --global 2>/dev/null)"
t_eq "get: key case is normalised by git" "Local Name" "$(shell::git::config::get USER.Name 2>/dev/null)"
out="$(r shell::git::config::get no.such.key)"
t_has "get: missing key warns" "Key not found: no.such.key" "$out"
t_has "get: missing key exit 1" "RC=1" "$out"
t_eq "get: missing key prints nothing on stdout" "" "$(shell::git::config::get no.such.key 2>/dev/null)"
t_eq "get -g: local-only key is not found" "1" "$(
	shell::git::config::get -g user.email >/dev/null 2>&1
	echo $?
)"

git config --local test.spaced "  two  spaces  "
t_eq "get: value kept exactly (spaces)" "  two  spaces  " "$(shell::git::config::get test.spaced 2>/dev/null)"
git config --local --add test.multi first
git config --local --add test.multi second
t_eq "get: several values -> the last" "second" "$(shell::git::config::get test.multi 2>/dev/null)"
t_eq "get: stdout is only the value" "loc@ex.com" "$(shell::git::config::get user.email 2>/dev/null)"

for bad in "" nodot "-x.y" "a b.c" "a.1b"; do
	out="$(r shell::git::config::get "$bad")"
	t_has "get: invalid key [$bad]" "RC=2" "$out"
done
out="$(r shell::git::config::get)"
t_has "get: no key" "RC=2" "$out"
out="$(r shell::git::config::get a.b c.d)"
t_has "get: two keys" "RC=2" "$out"
out="$(r shell::git::config::get -n user.name)"
t_has "get: -n is not an option" "RC=2" "$out"
t_eq "get: -- ends options" "Local Name" "$(shell::git::config::get -- user.name 2>/dev/null)"
cd "$HOME/norepo" || exit 1
t_eq "get outside a repo: reads the global config" "Glob" "$(shell::git::config::get user.name 2>/dev/null)"
t_rc "get -h" 0 shell::git::config::get -h

# =============================== set ====================================================
mkrepo
out="$(r shell::git::config::set user.name "John Doe")"
t_has "set: exit 0" "RC=0" "$out"
t_has "set: shows the command" "git config --local -- user.name" "$out"
t_eq "set: written to the local config" "John Doe" "$(gl user.name)"
t_eq "set: global untouched" "" "$(gg user.name)"
t_eq "set: in .git/config" "1" "$(grep -c 'name = John Doe' .git/config)"

out="$(r shell::git::config::set -g core.editor nvim)"
t_has "set -g: exit 0" "RC=0" "$out"
t_eq "set -g: written to the global config" "nvim" "$(gg core.editor)"
t_eq "set -g: local untouched" "" "$(gl core.editor)"

shell::git::config::set user.name "Jane Roe" >/dev/null 2>&1
t_eq "set: overwrites" "Jane Roe" "$(gl user.name)"
out="$(r shell::git::config::set user.name "Jane Roe")"
t_has "set: same value -> nothing to do" "already has this value" "$out"
t_has "set: same value exit 0" "RC=0" "$out"
t_lacks "set: same value runs no git command" "▶" "$out"

out="$(r shell::git::config::set -n user.name "Dry Run")"
t_has "set -n: prints the command" "git config --local -- user.name" "$out"
t_eq "set -n: changes nothing" "Jane Roe" "$(gl user.name)"
out="$(r shell::git::config::set -n -g core.editor vim)"
t_eq "set -n -g: global unchanged" "nvim" "$(gg core.editor)"

git config --local --add remote.o.fetch a
git config --local --add remote.o.fetch b
out="$(r shell::git::config::set remote.o.fetch c)"
t_has "set: multi-valued key refused" "has 2 values" "$out"
t_has "set: multi-valued key exit 1" "RC=1" "$out"
t_eq "set: multi-valued key untouched" "2" "$(git config --local --get-all remote.o.fetch | wc -l | tr -d ' ')"

out="$(r shell::git::config::set)"
t_has "set: nothing given" "RC=2" "$out"
out="$(r shell::git::config::set user.name)"
t_has "set: value missing" "RC=2" "$out"
out="$(r shell::git::config::set a.b c d)"
t_has "set: too many arguments" "RC=2" "$out"
out="$(r shell::git::config::set --bogus a.b c)"
t_has "set: unknown option" "RC=2" "$out"
for bad in "" nodot "-x.y" "a b.c" "a.1b" "core.editor;touch" "--global"; do
	out="$(r shell::git::config::set "$bad" value)"
	t_has "set: invalid key [$bad]" "RC=2" "$out"
done

out="$(r shell::git::config::set test.empty "")"
t_has "set: an empty value is allowed" "RC=0" "$out"
t_eq "set: ...and stored as empty" "1" "$(git config --local --get-all test.empty | wc -l | tr -d ' ')"
out="$(r shell::git::config::set -- core.pager -F)"
t_has "set: -- lets a value start with a dash" "RC=0" "$out"
t_eq "set: ...stored as given" "-F" "$(gl core.pager)"
out="$(r shell::git::config::set test.opt value -g)"
t_has "set: option after the positionals" "RC=0" "$out"
t_eq "set: ...applies (global)" "value" "$(gg test.opt)"

special='a "quoted" $HOME `ticks` ; & | > < \ done'
shell::git::config::set test.special "$special" >/dev/null 2>&1
t_eq "set: special characters round-trip literally" "$special" "$(gl test.special)"
shell::git::config::set test.inject '$(touch '"$HOME"'/pwned)' >/dev/null 2>&1
t_rc "set: a \$(...) value is never executed" 1 test -e "$HOME/pwned"
shell::git::config::set "x.y;touch $HOME/pwned" v >/dev/null 2>&1
t_rc "set: a key with shell syntax is rejected, nothing runs" 1 test -e "$HOME/pwned"

cd "$HOME/norepo" || exit 1
out="$(r shell::git::config::set user.name X)"
t_has "set outside a repo: local refused" "Not inside a Git repository" "$out"
t_has "set outside a repo: exit 1" "RC=1" "$out"
out="$(r shell::git::config::set -g test.outside yes)"
t_has "set -g outside a repo works" "RC=0" "$out"
t_rc "set -h" 0 shell::git::config::set -h

# =============================== unset ==================================================
mkrepo
git config --local user.signingkey ABC
git config --global user.signingkey GLOBALKEY
out="$(r shell::git::config::unset user.signingkey)"
t_has "unset: exit 0" "RC=0" "$out"
t_has "unset: shows the command" "git config --local --unset -- user.signingkey" "$out"
t_eq "unset: removed locally" "" "$(gl user.signingkey)"
t_eq "unset: the global value is untouched" "GLOBALKEY" "$(gg user.signingkey)"
out="$(r shell::git::config::unset user.signingkey)"
t_has "unset: absent key -> not found" "Key not found in the local configuration" "$out"
t_has "unset: absent key exit 1" "RC=1" "$out"
out="$(r shell::git::config::unset -g user.signingkey)"
t_has "unset -g: exit 0" "RC=0" "$out"
t_eq "unset -g: removed globally" "" "$(gg user.signingkey)"

git config --local test.keep 1
out="$(r shell::git::config::unset -n test.keep)"
t_has "unset -n: prints the command" "--unset -- test.keep" "$out"
t_eq "unset -n: changes nothing" "1" "$(gl test.keep)"

git config --local --add remote.o.fetch a
git config --local --add remote.o.fetch b
out="$(r shell::git::config::unset remote.o.fetch)"
t_has "unset: multi-valued key refused" "has 2 values" "$out"
t_has "unset: multi-valued exit 1" "RC=1" "$out"
t_eq "unset: multi-valued key intact" "2" "$(git config --local --get-all remote.o.fetch | wc -l | tr -d ' ')"

for bad in "" nodot "-x.y" "a b.c"; do
	out="$(r shell::git::config::unset "$bad")"
	t_has "unset: invalid key [$bad]" "RC=2" "$out"
done
out="$(r shell::git::config::unset)"
t_has "unset: no key" "RC=2" "$out"
out="$(r shell::git::config::unset a.b c.d)"
t_has "unset: two keys" "RC=2" "$out"
cd "$HOME/norepo" || exit 1
out="$(r shell::git::config::unset test.keep)"
t_has "unset outside a repo: local refused" "RC=1" "$out"
t_rc "unset -h" 0 shell::git::config::unset -h

# =============================== user::setup ============================================
# run_setup <picks> <stdin> [args...] -> output, then RC=
run_setup() {
	local picks="$1" input="$2"
	shift 2
	reset_fzf
	printf '%s' "$input" | FAKE_FZF_PICKS="$picks" shell::git::config::user::setup "$@" 2>&1
	echo "RC=$?"
}
mkrepo
out="$(run_setup "Apply" "John Doe${nl}john@ex.com${nl}trunk${nl}false${nl}")"
t_has "setup: succeeded" "RC=0" "$out"
t_eq "setup: user.name" "John Doe" "$(gl user.name)"
t_eq "setup: user.email" "john@ex.com" "$(gl user.email)"
t_eq "setup: init.defaultBranch" "trunk" "$(gl init.defaultBranch)"
t_eq "setup: core.autocrlf" "false" "$(gl core.autocrlf)"
t_eq "setup: nothing written globally" "" "$(gg user.name)"
t_eq "setup: the apply menu offered Apply / Cancel" "Apply${nl}Cancel" "$(cat "$HOME/stdin.1")"

t_has "setup: nothing to change the second time" "Nothing to change" "$(run_setup "" "John Doe${nl}john@ex.com${nl}trunk${nl}false${nl}")"
t_eq "setup: ...and no confirmation was asked" "0" "$(test -e "$HOME/fzf.count" && echo 1 || echo 0)"

mkrepo
out="$(run_setup "Apply" "N${nl}e@x.io${nl}${nl}${nl}")"
t_eq "setup: default branch is main" "main" "$(gl init.defaultBranch)"
t_eq "setup: default autocrlf is input on Linux" "input" "$(gl core.autocrlf)"
mkrepo
out="$(SHELL_OS_TYPE=macos run_setup "Apply" "N${nl}e@x.io${nl}${nl}${nl}")"
t_eq "setup: default autocrlf is input on macOS" "input" "$(gl core.autocrlf)"
mkrepo
out="$(SHELL_OS_TYPE=windows run_setup "Apply" "N${nl}e@x.io${nl}${nl}${nl}")"
t_eq "setup: default autocrlf is true on Windows" "true" "$(gl core.autocrlf)"

mkrepo
out="$(run_setup "Apply" "Name <x>${nl}Good Name${nl}bad${nl}e@x.io${nl}bad branch${nl}dev${nl}maybe${nl}true${nl}")"
t_has "setup: invalid name asked again" "not a valid name" "$out"
t_has "setup: invalid email asked again" "not a valid email" "$out"
t_has "setup: invalid branch asked again" "not a valid branch" "$out"
t_has "setup: invalid autocrlf asked again" "not a valid autocrlf" "$out"
t_has "setup: ...then succeeds" "RC=0" "$out"
t_eq "setup: the valid answers were used" "Good Name|e@x.io|dev|true" "$(gl user.name)|$(gl user.email)|$(gl init.defaultBranch)|$(gl core.autocrlf)"

mkrepo
out="$(run_setup "${nl}" "")"
t_has "setup: end of input at the first prompt cancels" "RC=1" "$out"
mkrepo
out="$(run_setup "Cancel" "N${nl}e@x.io${nl}${nl}${nl}")"
t_has "setup: Cancel -> exit 1" "RC=1" "$out"
t_eq "setup: Cancel -> nothing written" "" "$(gl user.name)"
mkrepo
out="$(run_setup "" "N${nl}e@x.io${nl}${nl}${nl}")"
t_has "setup: ESC at the apply menu cancels" "RC=1" "$out"
t_eq "setup: ESC -> nothing written" "" "$(gl user.email)"
mkrepo
out="$(run_setup "" "N${nl}")"
t_has "setup: end of input midway cancels" "RC=1" "$out"

mkrepo
git config --global user.name "Global Name"
git config --global user.email "g@x.io"
out="$(run_setup "Apply" "${nl}${nl}${nl}${nl}")"
t_has "setup: the inherited name is offered as the default" "user.name [Global Name]" "$out"
t_eq "setup: Enter keeps it (pinned locally)" "Global Name" "$(gl user.name)"
mkrepo
git config --global user.name "Global Name"
git config --global user.email "g@x.io"
out="$(run_setup "Apply" "Project Name${nl}proj@x.io${nl}${nl}${nl}")"
t_eq "setup: a project-specific identity overrides global" "Project Name" "$(gl user.name)"
t_eq "setup: ...and the global one is untouched" "Global Name" "$(gg user.name)"

mkrepo
out="$(run_setup "Apply" "G Name${nl}g@x.io${nl}main${nl}input${nl}" --global)"
t_has "setup --global: succeeded" "RC=0" "$out"
t_eq "setup --global: written to ~/.gitconfig" "G Name" "$(gg user.name)"
t_eq "setup --global: local untouched" "" "$(gl user.name)"

mkrepo
out="$(run_setup "" "N${nl}e@x.io${nl}${nl}${nl}" -n)"
t_has "setup -n: exit 0" "RC=0" "$out"
t_has "setup -n: prints the commands" "git config --local -- user.name" "$out"
t_eq "setup -n: writes nothing" "" "$(gl user.name)"
t_eq "setup -n: asks no confirmation" "0" "$(test -e "$HOME/fzf.count" && echo 1 || echo 0)"

cd "$HOME/norepo" || exit 1
out="$(run_setup "" "")"
t_has "setup outside a repo: refused before asking" "Not inside a Git repository" "$out"
out="$(r shell::git::config::user::setup --bogus)"
t_has "setup: unknown option" "RC=2" "$out"
t_rc "setup -h" 0 shell::git::config::user::setup -h

# =============================== fzf ====================================================
run_fzf() {
	local picks="$1" input="$2"
	shift 2
	reset_fzf
	printf '%s' "$input" | FAKE_FZF_PICKS="$picks" shell::git::config::fzf "$@" 2>&1
	echo "RC=$?"
}
mkrepo
git config --local user.name "Old Name"
git config --local user.email "old@x.io"
git config --global user.name "Glob"

out="$(run_fzf "user.name${nl}Edit value" "New Name${nl}")"
t_has "fzf edit: exit 0 (a change was made)" "RC=0" "$out"
t_eq "fzf edit: value changed" "New Name" "$(gl user.name)"
t_eq "fzf edit: global untouched" "Glob" "$(gg user.name)"
t_has "fzf: the preview shows the value and its file for the scope" "--preview=git config --local --show-origin --get-all -- {}" "$(cat "$HOME/args.1")"
t_has "fzf: the keys are listed" "user.email" "$(cat "$HOME/stdin.1")"
t_eq "fzf: the Back entry is last" "$B" "$(tail -n 1 "$HOME/stdin.1")"
t_eq "fzf: the action menu" "Edit value${nl}Unset (Delete) key${nl}Cancel" "$(cat "$HOME/stdin.2")"
t_eq "fzf: a key appears once" "1" "$(grep -c '^core.bare$' "$HOME/stdin.1")"
t_eq "fzf: the list is shown again after the action" "1" "$([ -e "$HOME/stdin.3" ] && echo 1 || echo 0)"

out="$(run_fzf "user.email${nl}Unset (Delete) key${nl}Unset user.email" "")"
t_has "fzf unset: exit 0" "RC=0" "$out"
t_eq "fzf unset: removed" "" "$(gl user.email)"
t_eq "fzf unset: confirm menu" "Unset user.email${nl}Cancel" "$(cat "$HOME/stdin.3")"

mkrepo
git config --local user.name "Keep"
out="$(run_fzf "user.name${nl}Cancel" "")"
t_has "fzf Cancel: returns to the list, exit 1 (nothing done)" "RC=1" "$out"
t_eq "fzf Cancel: value kept" "Keep" "$(gl user.name)"
t_eq "fzf Cancel: the list was shown again" "1" "$([ -e "$HOME/stdin.3" ] && echo 1 || echo 0)"
out="$(run_fzf "user.name${nl}Unset (Delete) key${nl}Cancel" "")"
t_has "fzf unset declined: exit 1" "RC=1" "$out"
t_eq "fzf unset declined: key kept" "Keep" "$(gl user.name)"
out="$(run_fzf "user.name${nl}Edit value" "${nl}")"
t_has "fzf edit with Enter keeps the value: nothing changed" "RC=1" "$out"
out="$(run_fzf "user.name${nl}Edit value" "")"
t_has "fzf edit cancelled with Ctrl-D" "Edit cancelled" "$out"
t_eq "fzf edit cancelled: value kept" "Keep" "$(gl user.name)"
out="$(run_fzf "$B" "")"
t_has "fzf: Back ends the session (exit 1, nothing done)" "RC=1" "$out"
out="$(run_fzf "" "")"
t_has "fzf: ESC ends the session" "RC=1" "$out"

mkrepo
git config --local user.name "A"
git config --local user.email "a@x.io"
out="$(run_fzf "user.name${nl}Edit value${nl}user.email${nl}Edit value" "B${nl}b@x.io${nl}")"
t_has "fzf: several edits in one session" "RC=0" "$out"
t_eq "fzf: both keys changed" "B|b@x.io" "$(gl user.name)|$(gl user.email)"

mkrepo
git config --local --add remote.o.fetch a
git config --local --add remote.o.fetch b
out="$(run_fzf "remote.o.fetch${nl}Edit value" "x${nl}")"
t_has "fzf edit: a multi-valued key is refused" "has 2 values" "$out"
t_has "fzf edit: ...which counts as a failure (exit 1)" "RC=1" "$out"
t_eq "fzf edit: ...and nothing changed" "2" "$(git config --local --get-all remote.o.fetch | wc -l | tr -d ' ')"

mkrepo
git config --global user.name "GlobalOnly"
out="$(run_fzf "user.name${nl}Edit value" "Changed${nl}" -g)"
t_has "fzf -g: exit 0" "RC=0" "$out"
t_eq "fzf -g: the global config was edited" "Changed" "$(gg user.name)"
t_has "fzf -g: the preview reads the global config" "--preview=git config --global --show-origin --get-all -- {}" "$(cat "$HOME/args.1")"

mkrepo
git config --local user.name "Same"
out="$(run_fzf "user.name${nl}Edit value" "Planned${nl}" -n)"
t_has "fzf -n: prints the command" "git config --local -- user.name" "$out"
t_has "fzf -n: counts as planned (exit 0)" "RC=0" "$out"
t_eq "fzf -n: changes nothing" "Same" "$(gl user.name)"

rm -f "$HOME/.gitconfig"
out="$(run_fzf "" "" -g)"
t_has "fzf -g with no global keys" "No keys in the global configuration" "$out"
t_has "fzf: ...exit 1" "RC=1" "$out"
t_eq "fzf: ...and no picker was opened" "0" "$(test -e "$HOME/fzf.count" && echo 1 || echo 0)"
cd "$HOME/norepo" || exit 1
out="$(run_fzf "" "")"
t_has "fzf outside a repo: refused" "Not inside a Git repository" "$out"
out="$(r shell::git::config::fzf --bogus)"
t_has "fzf: unknown option" "RC=2" "$out"
t_rc "fzf -h" 0 shell::git::config::fzf -h

t_done
