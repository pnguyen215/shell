#!/usr/bin/env bash
# Security regressions: command injection, secret exposure, safe defaults.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

# A fake curl records its arguments and answers like Telegram would.
mkdir "$HOME/bin"
cat >"$HOME/bin/curl" <<'FAKE'
#!/bin/sh
printf '%s\n' "$@" >"$FAKE_CURL_LOG"
echo '{"ok":true}'
FAKE
chmod +x "$HOME/bin/curl"
export PATH="$HOME/bin:$PATH" FAKE_CURL_LOG="$HOME/curl.log"

marker="$HOME/PWNED"
payload="\"; touch $marker; echo \"\$(touch $marker)\`touch $marker\`"
shell::telegram::send "123456:SECRET" "42" "$payload" >/dev/null 2>&1
t_eq "telegram: send succeeds" "0" "$?"
t_rc "telegram: message text is NOT executed" 1 test -e "$marker"
t_has "telegram: text passed verbatim, urlencoded" "text=$payload" "$(cat "$FAKE_CURL_LOG")"

out="$(shell::telegram::send -n "123456:SECRET" 42 hi 2>&1)"
t_lacks "telegram: dry-run masks the token" "SECRET" "$out"
t_has "telegram: dry-run shows masked token" "bot1234****" "$out"

printf '{"ok":false,"description":"bad"}' >/dev/null
cat >"$HOME/bin/curl" <<'FAKE'
#!/bin/sh
echo '{"ok":false,"description":"chat not found"}'
FAKE
shell::telegram::send "123456:SECRET" "42" "hi" >/dev/null 2>&1
t_eq "telegram: ok:false is reported as failure" "1" "$?"

# download: HTTP errors must fail and must not leave/replace a file.
cat >"$HOME/bin/curl" <<'FAKE'
#!/bin/sh
# emulate `curl -f` on a 404: exit 22, write nothing
exit 22
FAKE
printf 'original' >"$HOME/keep.txt"
shell::net::download -f "$HOME/keep.txt" "http://example.invalid/x" >/dev/null 2>&1
t_eq "download: failure returns 1" "1" "$?"
t_eq "download: existing file untouched on failure" "original" "$(cat "$HOME/keep.txt")"
t_eq "download: no temp files left" "0" "$(find "$HOME" -maxdepth 1 -name 'keep.txt.*' | wc -l | tr -d ' ')"

# run_remote_script: a failed download must NOT look like success.
shell::net::run_remote_script "http://example.invalid/i.sh" sh >/dev/null 2>&1
t_eq "remote script: failed download is a failure" "1" "$?"

# Package manager commands are argv-built: a hostile name stays one argument.
out="$(shell::package::install -n 'git; touch '"$marker" 2>&1)"
t_rc "package: hostile name not executed" 1 test -e "$marker"

t_done
