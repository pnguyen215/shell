#!/usr/bin/env bash
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

# --- loader -------------------------------------------------------------------
t_eq "loader reports no load errors" "0" "$SHELL_LOAD_ERRORS"

# --- os -----------------------------------------------------------------------
case "$(shell::os::type)" in linux | macos) t_ok ;; *) t_bad "os::type is linux|macos" ;; esac
# Regression: get_temp_dir used to print "linux" before the path.
t_eq "temp_dir is one clean line" "1" "$(shell::os::temp_dir | wc -l | tr -d ' ')"
TMPDIR="/var/x/" t_eq "temp_dir strips trailing slash" "/var/x" "$(TMPDIR=/var/x/ shell::os::temp_dir)"

# --- logger -------------------------------------------------------------------
# Regression: fatal used to `exit 1`, killing the sourcing shell.
shell::logger::fatal "boom" >/dev/null 2>&1
t_eq "logger::fatal returns instead of exiting" "1" "$?"
SHELL_LOGGER_LEVEL=ERROR
t_has "level=ERROR still runs execute()" "ran" "$(shell::logger::execute 'echo ran' 2>&1)"
t_lacks "level=ERROR hides info" "hidden" "$(shell::logger::info hidden 2>&1)"
SHELL_LOGGER_LEVEL=DEBUG
t_eq "can(): unknown level is rejected" "1" "$(
	shell::logger::can NOPE
	echo $?
)"

# --- exec ---------------------------------------------------------------------
# Regression: exec::safe printed for BOTH true and false and never ran anything.
t_has "exec::safe true only prints" "▶ echo NOPE" "$(shell::exec::safe true 'echo NOPE' 2>&1)"
t_lacks "exec::safe true does not run" "NOPE
" "$(shell::exec::safe true 'echo NOPE' 2>&1)"
t_has "exec::safe false runs" "YES" "$(shell::exec::safe false 'echo YES' 2>&1)"
t_rc "exec::command propagates failure" 1 shell::exec::command false
t_rc "exec::safe rejects junk flag" 2 shell::exec::safe maybe 'echo x'

# --- ask ----------------------------------------------------------------------
# Regression: accept looped forever on "yes"; EOF looped forever too.
printf 'yes\n' | shell::ask::accept "go?" >/dev/null 2>&1
t_eq "ask::accept yes -> 0" "0" "$?"
printf 'no\n' | shell::ask::accept "go?" >/dev/null 2>&1
t_eq "ask::accept no -> 1" "1" "$?"
shell::ask::accept "go?" </dev/null >/dev/null 2>&1
t_eq "ask::accept EOF -> 9 (cancelled)" "9" "$?"
printf 'abc\n42\n' | shell::ask::number "n?" >/dev/null 2>&1
t_eq "ask::number retries then accepts" "0" "$?"

# --- strings ------------------------------------------------------------------
t_eq "trim" "a b" "$(shell::strings::trim '   a b  ')"
t_eq "sanitize::upper" "MY_VAR_1" "$(shell::strings::sanitize::upper 'my var-1')"
t_eq "format::camel" "MyVarName" "$(shell::strings::format::camel 'my_var name')"
t_eq "format::title" "Hello Big World" "$(shell::strings::format::title 'hello big world')"
t_eq "printf-safe: value -n is not eaten" "-n" "$(shell::strings::trim '-n')"

# --- clipboard ----------------------------------------------------------------
t_rc "clipboard: empty value invalid" 2 shell::clipboard::copy ""
t_rc "clipboard --best-effort never fails" 0 shell::clipboard::copy --best-effort "x"

# --- measure ------------------------------------------------------------------
ms="$(shell::exec::now_ms)"
case "$ms" in '' | *[!0-9]*) t_bad "now_ms is an integer" "$ms" ;; *) t_ok ;; esac
t_has "measure keeps command output and reports time" "Execution time: 0s" "$(shell::exec::measure true 2>&1)"

t_done
