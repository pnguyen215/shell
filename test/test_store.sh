#!/usr/bin/env bash
# Key store, INI, profile, bookmarks: persistence and the bugs fixed during migration.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

# --- key store ----------------------------------------------------------------
shell::conf::key::add my_key "hello world & more" >/dev/null 2>&1
t_eq "conf: value round-trips" "hello world & more" "$(shell::conf::key::get my_key 2>/dev/null)"
# Regression: add upper-cased the key but get/exists did not, so lookups failed.
t_eq "conf: lookup is case-insensitive" "hello world & more" "$(shell::conf::key::get MY_KEY 2>/dev/null)"
t_rc "conf: exists" 0 shell::conf::key::exists my_key
t_rc "conf: missing key" 1 shell::conf::key::exists nope
# Regression: config used to be chmod 777 (it holds tokens/keys).
t_eq "conf: file is 600" "600" "$(shell::fs::stat mode "$SHELL_KEY_FILE")"
t_eq "conf: dir is 700" "700" "$(shell::fs::stat mode "$SHELL_CONFIG_DIR")"

# --- ini ----------------------------------------------------------------------
# Regression: write returned 1 on success.
t_rc "ini: write succeeds with rc 0" 0 shell::ini::write "$HOME/a.ini" dev HOST localhost
t_eq "ini: read back" "localhost" "$(shell::ini::read "$HOME/a.ini" dev HOST 2>/dev/null)"
t_has "ini: section list" "dev" "$(shell::ini::section::list "$HOME/a.ini" 2>/dev/null)"
t_rc "ini: key exists" 0 shell::ini::key::exists "$HOME/a.ini" dev HOST
# Regression: `[ -z "$file"]` (missing space) made the validation a no-op.
t_rc "ini: remove section needs a file" 1 shell::ini::section::remove ""
t_has "ini: dump json is valid-looking" '"host"' "$(shell::ini::dump::json "$HOME/a.ini" 2>/dev/null)"

# --- bookmarks ----------------------------------------------------------------
# Regression: loading the library used to create bookmark files as a side effect.
t_rc "bookmark file is created lazily" 1 test -f "$SHELL_BOOKMARK_FILE"
mkdir "$HOME/proj" && cd "$HOME/proj" || exit 1
shell::bookmark::add My-Proj >/dev/null 2>&1
t_eq "bookmark stored sanitised" "$HOME/proj|my_proj" "$(cat "$SHELL_BOOKMARK_FILE")"
t_eq "bookmark file is 600" "600" "$(shell::fs::stat mode "$SHELL_BOOKMARK_FILE")"
cd "$HOME" || exit 1
shell::goto::run my_proj >/dev/null 2>&1
t_eq "goto changes directory" "$HOME/proj" "$PWD"
cd "$HOME" || exit 1
# Regression: removing the LAST bookmark used to fail (grep -v exits 1 on empty output).
shell::bookmark::remove my_proj >/dev/null 2>&1
t_eq "removing the last bookmark works" "0" "$(wc -c <"$SHELL_BOOKMARK_FILE" | tr -d ' ')"
[ -n "${ZSH_VERSION-}" ] || t_eq "no EXIT trap leaked into the shell" "" "$(trap -p EXIT)"
t_rc "goto -s needs a name" 2 shell::goto::run -s

t_done
