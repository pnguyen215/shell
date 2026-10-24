#!/usr/bin/env bash
# Logger styles: default look, the classic fallback, routing and threshold
# (unchanged by style), saving/loading the choice, and the fzf picker.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup
unset SHELL_LOGGER_STYLE

# Like t_rc, but runs in the CURRENT shell: t_run uses $(...), which would throw
# away the SHELL_LOGGER_STYLE assignment these functions make.
t_run() {
	local name="$1" want="$2"
	shift 2
	"$@" >"$HOME/t_run.out" 2>&1
	T_RC=$?
	T_OUT="$(cat "$HOME/t_run.out")"
	if [ "$T_RC" -eq "$want" ]; then t_ok; else t_bad "$name" "expected rc=$want got rc=$T_RC; output: $T_OUT"; fi
}

# --- default: the simple style --------------------------------------------------
shell::logger::style::load
t_eq "default style is simple" "simple" "$(shell::logger::style::get)"
t_eq "info" "[info]  hello world" "$(shell::logger::info hello world 2>&1)"
t_eq "warn" "[warn]  careful" "$(shell::logger::warn careful 2>&1)"
t_eq "error" "[error] boom" "$(shell::logger::error boom 2>&1)"
t_eq "debug" "[debug] trace" "$(shell::logger::debug trace 2>&1)"
t_eq "success" "[ok]    done" "$(shell::logger::success "done" 2>&1)"
t_eq "fatal" "[fatal] dead" "$(shell::logger::fatal dead 2>&1)"
t_run "fatal still returns failure" 1 shell::logger::fatal dead

# --- routing is a contract and does not depend on the style ------------------------
t_eq "info goes to stdout" "[info]  x" "$(shell::logger::info x 2>/dev/null)"
t_eq "success goes to stdout" "[ok]    x" "$(shell::logger::success x 2>/dev/null)"
t_eq "error is not on stdout" "" "$(shell::logger::error x 2>/dev/null)"
t_eq "warn is not on stdout" "" "$(shell::logger::warn x 2>/dev/null)"

# --- the threshold still applies (and SUCCESS counts as INFO) -------------------------
SHELL_LOGGER_LEVEL=WARN
t_eq "info filtered at WARN" "" "$(shell::logger::info x 2>&1)"
t_eq "success filtered at WARN" "" "$(shell::logger::success x 2>&1)"
t_eq "error kept at WARN" "[error] x" "$(shell::logger::error x 2>&1)"
SHELL_LOGGER_LEVEL=INFO
t_eq "success kept at INFO" "[ok]    x" "$(shell::logger::success x 2>&1)"
t_eq "debug filtered at INFO" "" "$(shell::logger::debug x 2>&1)"
SHELL_LOGGER_LEVEL=DEBUG

# --- classic: the previous look ---------------------------------------------------------
t_run "set --session classic" 0 shell::logger::style::set --session classic
t_eq "classic info" "INFO: hello" "$(shell::logger::info hello 2>&1)"
t_eq "classic success keeps the INFO label" "INFO: done" "$(shell::logger::success "done" 2>&1)"
t_eq "classic error" "ERROR: boom" "$(shell::logger::error boom 2>&1)"
t_eq "classic fatal" "FATAL: dead" "$(shell::logger::fatal dead 2>&1)"
t_eq "--session did not save" "" "$(test -e "$SHELL_LOGGER_CONF_FILE" && echo saved)"
t_eq "get reflects the change" "classic" "$(shell::logger::style::get)"

# An unknown style (typo in the environment) falls back instead of breaking logging.
SHELL_LOGGER_STYLE=bogus
t_eq "unknown style falls back to default look" "[info]  x" "$(shell::logger::info x 2>&1)"
t_eq "get reports the default for an unknown style" "simple" "$(shell::logger::style::get)"
unset SHELL_LOGGER_STYLE

# --- set: validation, dry-run, saving ------------------------------------------------------
shell::logger::style::load
t_run "unknown style" 2 shell::logger::style::set neon
t_run "missing style" 2 shell::logger::style::set
t_run "unknown option" 2 shell::logger::style::set --force classic
t_run "two styles" 2 shell::logger::style::set simple classic
t_run "style with a space" 2 shell::logger::style::set "simple classic"
t_run "dry-run succeeds" 0 shell::logger::style::set -n classic
t_has "dry-run shows the change" "SHELL_LOGGER_STYLE=classic" "$T_OUT"
t_eq "dry-run changed nothing" "simple" "$(shell::logger::style::get)"
t_run "dry-run saved nothing" 1 test -e "$SHELL_LOGGER_CONF_FILE"

t_run "set classic saves" 0 shell::logger::style::set classic
t_eq "saved file content" "style=classic" "$(cat "$SHELL_LOGGER_CONF_FILE")"
t_eq "saved file is 600" "600" "$(shell::fs::stat mode "$SHELL_LOGGER_CONF_FILE")"
t_eq "config dir is 700" "700" "$(shell::fs::stat mode "$SHELL_CONFIG_DIR")"
t_eq "no temp files left" "0" "$(find "$SHELL_CONFIG_DIR" -name 'logger.conf.tmp.*' | wc -l | tr -d ' ')"

# A new session (variable unset) starts with the saved style...
unset SHELL_LOGGER_STYLE
shell::logger::style::load
t_eq "saved style is loaded" "classic" "$(shell::logger::style::get)"
# ...unless the user exported one, which wins.
SHELL_LOGGER_STYLE=simple
shell::logger::style::load
t_eq "exported style wins over the saved one" "simple" "$(shell::logger::style::get)"
# A corrupted file is ignored.
unset SHELL_LOGGER_STYLE
printf 'style=; rm -rf /\n' >"$SHELL_LOGGER_CONF_FILE"
shell::logger::style::load
t_eq "invalid saved value falls back to default" "simple" "$(shell::logger::style::get)"

# --- reset ------------------------------------------------------------------------------------
shell::logger::style::set classic >/dev/null 2>&1
t_run "reset -n" 0 shell::logger::style::reset -n
t_eq "reset -n changed nothing" "classic" "$(shell::logger::style::get)"
t_run "reset" 0 shell::logger::style::reset
t_eq "reset restores the default" "simple" "$(shell::logger::style::get)"
t_run "reset forgets the saved style" 1 test -e "$SHELL_LOGGER_CONF_FILE"
t_run "reset: unknown option" 2 shell::logger::style::reset --all

# --- list / preview ---------------------------------------------------------------------------
t_eq "list: style names" "simple
classic" "$(shell::logger::style::list | cut -f1)"
t_eq "preview: six lines" "6" "$(shell::logger::style::preview classic | wc -l | tr -d ' ')"
t_eq "preview ignores the threshold" "6" "$(SHELL_LOGGER_LEVEL=FATAL shell::logger::style::preview simple | wc -l | tr -d ' ')"
t_has "preview classic look" "WARN: Sample warning message" "$(shell::logger::style::preview classic)"
t_has "preview simple look" "[warn]  Sample warning message" "$(shell::logger::style::preview simple)"
t_eq "preview does not change the style" "simple" "$(shell::logger::style::get)"
t_run "preview: unknown style" 2 shell::logger::style::preview neon

# --- fzf picker (fake fzf: prints the first row starting with $FAKE_PICK) -------------------------
mkdir "$HOME/bin"
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
cat >"$FAKE_FZF_STDIN"
[ -z "$FAKE_PICK" ] && exit 130
grep "^$FAKE_PICK" "$FAKE_FZF_STDIN"
FAKE
chmod +x "$HOME/bin/fzf"
export PATH="$HOME/bin:$PATH" FAKE_FZF_STDIN="$HOME/fzf.in" FAKE_PICK=""

FAKE_PICK=classic t_run "picker applies the choice" 0 shell::logger::style::set::fzf
t_eq "picker: style is now classic" "classic" "$(shell::logger::style::get)"
t_eq "picker: choice was saved" "style=classic" "$(cat "$SHELL_LOGGER_CONF_FILE")"
t_has "picker: shows a preview of the new style" "WARN: Sample warning message" "$T_OUT"
t_has "picker: marks the current style" "[info]  text  (current)" "$(cat "$FAKE_FZF_STDIN")"
t_lacks "picker: marks only the current style" "INFO: text  (current)" "$(cat "$FAKE_FZF_STDIN")"
t_has "picker: lists simple too" "simple " "$(cat "$FAKE_FZF_STDIN")"

FAKE_PICK=simple t_run "picker --session" 0 shell::logger::style::set::fzf --session
t_eq "picker --session: applied" "simple" "$(shell::logger::style::get)"
t_eq "picker --session: not saved" "style=classic" "$(cat "$SHELL_LOGGER_CONF_FILE")"

FAKE_PICK=classic t_run "picker -n" 0 shell::logger::style::set::fzf -n
t_eq "picker -n changed nothing" "simple" "$(shell::logger::style::get)"

FAKE_PICK="" t_run "picker: ESC is a cancel" 9 shell::logger::style::set::fzf
t_eq "picker: cancel changed nothing" "simple" "$(shell::logger::style::get)"
t_run "picker: unknown option" 2 shell::logger::style::set::fzf --bogus

# --- help -----------------------------------------------------------------------------------------
t_run "set -h" 0 shell::logger::style::set -h
t_has "set help" "shell::logger::style::set" "$T_OUT"

t_done
