#!/usr/bin/env bash
# _shell::git::telegram::notify and the git notifications built on shell::markdown::*
# (src/lang/git.sh), plus shell::telegram::send --parse-mode (src/bot/telegram.sh).
# curl is a fake that records its arguments; nothing is sent anywhere.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

NL=$'\n'
bs='\'
mkdir "$HOME/bin"
cat >"$HOME/bin/curl" <<'FAKE'
#!/bin/sh
printf '%s\n' "$@" >"$FAKE_CURL_LOG"
echo '{"ok":true}'
FAKE
chmod +x "$HOME/bin/curl"
export PATH="$HOME/bin:$PATH" FAKE_CURL_LOG="$HOME/curl.log"
sent() { cat "$FAKE_CURL_LOG"; }
# The fake curl prints one argument per line; the text= argument runs up to the last line (the URL).
text_of() { sent | awk '/^text=/ {on = 1; sub(/^text=/, "")} on' | sed '$d'; }

# --- shell::telegram::send --parse-mode
shell::telegram::send "1:T" "42" "hi" >/dev/null 2>&1
t_has "send: default parse mode stays markdown" "parse_mode=markdown" "$(sent)"
shell::telegram::send -m markdownv2 "1:T" "42" "hi" >/dev/null 2>&1
t_has "send: -m markdownv2" "parse_mode=MarkdownV2" "$(sent)"
shell::telegram::send --parse-mode markdownv2 "1:T" "42" "a.b" >/dev/null 2>&1
t_eq "send: text is passed verbatim" "a.b" "$(text_of)"
shell::telegram::send -n -m markdownv2 "123456:SECRET" 42 hi >"$HOME/dry.out" 2>&1
t_has "send: dry-run shows the parse mode" "parse_mode=MarkdownV2" "$(cat "$HOME/dry.out")"
t_lacks "send: dry-run still masks the token" "SECRET" "$(cat "$HOME/dry.out")"
t_rc "send: unknown parse mode" 2 shell::telegram::send -m html "1:T" 42 hi
t_has "send: unknown parse mode is explained" "markdownv2" "$T_OUT"
t_rc "send: -m without a value" 2 shell::telegram::send -m

# --- configuration keys are required
t_rc "history::send: missing configuration" 2 shell::git::telegram::history::send -m markdownv2 "x"
shell::conf::key::add SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN "123456:SECRET" >/dev/null 2>&1
shell::conf::key::add SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID "42" >/dev/null 2>&1
shell::git::telegram::history::send "plain" >/dev/null 2>&1
t_has "history::send: default mode is markdown" "parse_mode=markdown" "$(sent)"
shell::git::telegram::history::send -m markdownv2 "plain" >/dev/null 2>&1
t_has "history::send: -m is passed through" "parse_mode=MarkdownV2" "$(sent)"
t_rc "history::send: no message" 2 shell::git::telegram::history::send -m markdownv2

# --- a repository to read the context from
git init -q "$HOME/proj" && cd "$HOME/proj" || exit 1
git config user.name "Jane Doe"
git config user.email "jane@example.com"
git remote add origin "https://user:s3cret@github.com/acme/widget.git"

_shell::git::telegram::notify "Branch renamed" Old "feat/a" New "feat/b" >/dev/null 2>&1
t_eq "notify: succeeds" "0" "$?"
msg="$(text_of)"
t_has "notify: sent as MarkdownV2" "parse_mode=MarkdownV2" "$(sent)"
t_has "notify: bold title" "*Branch renamed*" "$msg"
t_has "notify: identifiers are code, special characters escaped only outside code" '*Old:* `feat/a`' "$msg"
t_has "notify: second field" '*New:* `feat/b`' "$msg"
t_has "notify: repository links to the web page" "*Repository:* [proj](https://github.com/acme/widget)" "$msg"
t_has "notify: user" "*User:* Jane Doe" "$msg"
t_has "notify: time" "*Time:* 20" "$msg"
t_lacks "notify: credentials of the remote are never sent" "s3cret" "$(sent)"
t_lacks "notify: no pipe-separated legacy layout" " | old:" "$msg"
t_eq "notify: title first, then the fields, then the context" "*Branch renamed*" "$(printf '%s\n' "$msg" | sed -n 1p)"
t_eq "notify: blank line after the title" "" "$(printf '%s\n' "$msg" | sed -n 2p)"
t_eq "notify: blank line before the context" "" "$(printf '%s\n' "$msg" | sed -n 5p)"

# escaping of hostile and special values
_shell::git::telegram::notify "Commit created" Branch "feat/x_1" Hash "abc123" Message 'fix: handle a.b (v1.2) *now* [ok] _x_ \ ! #1' >/dev/null 2>&1
msg="$(text_of)"
t_has "notify: branch with an underscore sits in code" '*Branch:* `feat/x_1`' "$msg"
t_has "notify: message is escaped as MarkdownV2" '*Message:* fix: handle a\.b \(v1\.2\) \*now\* \[ok\] \_x\_ \\ \! \#1' "$msg"
t_has "notify: title with special characters" "*Tag v1${bs}.2 created*" "$(_shell::git::telegram::notify "Tag v1.2 created" Tag v1.2 >/dev/null 2>&1; text_of)"
_shell::git::telegram::notify "T" Message 'line one
line two' >/dev/null 2>&1
t_has "notify: newline in a value is flattened" "*Message:* line one line two" "$(text_of)"
long="$(printf 'x%.0s' $(seq 1 600))"
_shell::git::telegram::notify "T" Message "$long" >/dev/null 2>&1
t_eq "notify: long values are cut" "$SHELL_GIT_NOTIFY_VALUE_MAX" "$(text_of | sed -n 's/^\*Message:\* //p' | sed 's/\\\././g' | tr -d '\n' | awk '{print length($0)}')"
_shell::git::telegram::notify "T" Scope "" Branch "main" >/dev/null 2>&1
t_lacks "notify: empty values are left out" "Scope" "$(text_of)"
_shell::git::telegram::notify "Only context" >/dev/null 2>&1
t_has "notify: works without event fields" "*Only context*" "$(text_of)"
t_has "notify: and still has the context" "*Repository:*" "$(text_of)"

# the caller's own document is not touched
shell::markdown::init -f markdown
shell::markdown::paragraph "mine"
_shell::git::telegram::notify "T" Branch main >/dev/null 2>&1
t_eq "notify: the caller's document is untouched" "mine" "$(shell::markdown::render)"
t_eq "notify: the caller's format is untouched" "markdown" "$(shell::markdown::get_format)"

# a remote that is not web-hostable: only the name
git remote set-url origin "/srv/git/widget.git"
_shell::git::telegram::notify "T" Branch main >/dev/null 2>&1
t_has "notify: local remote gives the repository name only" "*Repository:* proj" "$(text_of)"
t_lacks "notify: no link for a local remote" "](" "$(text_of)"

# invalid use
t_rc "notify: no title" 2 _shell::git::telegram::notify
t_rc "notify: label without value" 2 _shell::git::telegram::notify "T" Branch
rm -f "$FAKE_CURL_LOG"
_shell::git::telegram::notify "" >/dev/null 2>&1
t_rc "notify: nothing is sent on invalid input" 1 test -e "$FAKE_CURL_LOG"

# the old pipe-separated sentences are gone from the sources
t_eq "git.sh no longer builds telegram_message strings" "0" "$(grep -c 'local telegram_message=' "$SHELL_TEST_ROOT/src/lang/git.sh")"

t_done
