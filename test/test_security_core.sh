#!/usr/bin/env bash
# Security foundation: finding model, sanitising, renderers (text/json/csv/markdown), argument parsing.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

S="$SHELL_SECURITY_SEP"
have_jq=0
command -v jq >/dev/null 2>&1 && have_jq=1
# t_json <name> <json>: valid JSON when jq exists (skipped, counted as pass, otherwise)
t_json() {
	if [ "$have_jq" = 1 ]; then
		if printf '%s' "$2" | jq -e . >/dev/null 2>&1; then t_ok; else t_bad "$1" "invalid JSON: $2"; fi
	else
		t_ok
	fi
}

# --- sanitize: one line, no control characters, no secrets -------------------
t_eq "sanitize: newline and tab become spaces" "a b c" "$(_shell::security::sanitize "$(printf 'a\nb\tc')")"
t_eq "sanitize: key=value masked" "run --password=[REDACTED] now" "$(_shell::security::sanitize 'run --password=hunter2 now')"
t_eq "sanitize: --token value masked" "x --token [REDACTED]" "$(_shell::security::sanitize 'x --token abc123')"
t_eq "sanitize: upper-case word masked" "API_KEY=[REDACTED]" "$(_shell::security::sanitize 'API_KEY=zzz')"
t_eq "sanitize: URL password masked" "curl https://bob:[REDACTED]@host/x" "$(_shell::security::sanitize 'curl https://bob:s3cret@host/x')"
out="$(_shell::security::sanitize "curl -H 'Authorization: Bearer tok123abc' https://h")"
t_lacks "sanitize: bearer token not leaked" "tok123abc" "$out"
t_eq "sanitize: ordinary text untouched" "ls -la /tmp" "$(_shell::security::sanitize 'ls -la /tmp')"

# --- severity / args ---------------------------------------------------------
t_eq "severity rank CRITICAL" "4" "$(_shell::security::severity::rank CRITICAL)"
t_eq "severity rank INFO" "0" "$(_shell::security::severity::rank INFO)"
t_rc "severity rank rejects unknown" 2 _shell::security::severity::rank URGENT
t_rc "args: default ok" 0 _shell::security::args::parse
t_rc "args: unknown format" 2 _shell::security::args::parse --format yaml
t_rc "args: unknown severity" 2 _shell::security::args::parse --min-severity URGENT
t_rc "args: unknown argument" 2 _shell::security::args::parse --bogus
t_rc "args: missing value" 2 _shell::security::args::parse --format
_shell::security::args::parse -f json --min-severity HIGH
t_eq "args: format parsed" "json" "$_SHELL_SECURITY_FORMAT"
t_eq "args: severity parsed" "HIGH" "$_SHELL_SECURITY_MIN_SEVERITY"

# --- finding store -----------------------------------------------------------
t_rc "finding: no session is refused" 2 _shell::security::finding::add process HIGH r d s why high i r
_shell::security::session::begin
t_eq "session: first begin owns the store" "1" "$_SHELL_SECURITY_OWNS"
store="$_SHELL_SECURITY_STORE"
t_eq "session: store is mode 600" "600" "$(shell::fs::stat mode "$store")"
t_rc "finding: bad severity" 2 _shell::security::finding::add process URGENT r d s why high i r
t_rc "finding: bad confidence" 2 _shell::security::finding::add process HIGH r d s why certain i r
_shell::security::finding::add process MEDIUM "pid 1" "first" "src" "why" medium "inv" "fix"
_shell::security::finding::add process MEDIUM "pid 1" "first" "src" "why" medium "inv" "fix"
t_eq "finding: identical finding stored once" "1" "$(wc -l <"$store" | tr -d ' ')"
_shell::security::finding::add process HIGH "pid 2" 'say "hi" \ back' "src" "why" high "inv" "fix"
_shell::security::finding::add host LOW "r3" "=HYPERLINK(\"x\")" "src" "why" low "inv" "fix"
_shell::security::finding::add host INFO "r4" "info one" "src" "why" high "inv" "fix"
_shell::security::session::begin
t_eq "session: nested begin joins, does not own" "0" "$_SHELL_SECURITY_OWNS"
t_eq "session: nested begin keeps the store" "$store" "$_SHELL_SECURITY_STORE"
_shell::security::session::finish 0 json INFO >/dev/null
t_rc "session: non-owner finish keeps the store" 0 test -f "$store"

fields="$(head -1 "$store" | awk -F"$S" '{print NF}')"
t_eq "finding: record has 11 fields" "11" "$fields"
id="$(head -1 "$store" | cut -d"$S" -f1)"
case "$id" in FND-PROCESS-????????) t_ok ;; *) t_bad "finding: id format" "$id" ;; esac

# JSON
json="$(_shell::security::render::findings json INFO)"
t_json "json: whole report is valid JSON" "$json"
t_has "json: schema" '"schema":"shell-security-findings/1"' "$json"
t_has "json: summary counts" '"HIGH":1,"MEDIUM":1,"LOW":1,"INFO":1,"total":4' "$json"
t_has "json: quotes and backslash escaped" 'say \"hi\" \\ back' "$json"
if [ "$have_jq" = 1 ]; then
	t_eq "json: most severe first" "HIGH" "$(printf '%s' "$json" | jq -r '.findings[0].severity')"
	t_eq "json: description round-trips" 'say "hi" \ back' "$(printf '%s' "$json" | jq -r '.findings[0].description')"
	t_eq "json: every field present" "11" "$(printf '%s' "$json" | jq '.findings[0] | keys | length')"
fi
t_eq "min-severity MEDIUM hides LOW/INFO" "2" "$(_shell::security::render::findings json MEDIUM | grep -o '"severity"' | wc -l | tr -d ' ')"
t_has "min-severity: summary counts only shown findings" '"total":2' "$(_shell::security::render::findings json MEDIUM)"

# CSV
csv="$(_shell::security::render::findings csv INFO)"
t_eq "csv: header + 4 rows" "5" "$(printf '%s\n' "$csv" | wc -l | tr -d ' ')"
t_has "csv: formula is neutralised" "\"'=HYPERLINK(\"\"x\"\")\"" "$csv"
t_has "csv: cells quoted" '"HIGH"' "$csv"

# Markdown
md="$(_shell::security::render::findings markdown INFO)"
t_has "markdown: title" "# Security findings" "$md"
t_has "markdown: table header" "| ID" "$md"
t_has "markdown: per-finding heading" "### $id (" "$md"
t_has "markdown: not-proof notice" "not proof of compromise" "$md"

# Text
txt="$(_shell::security::render::findings text INFO)"
t_has "text: severity tag" "[HIGH]" "$txt"
t_has "text: confidence" "confidence: high" "$txt"
t_has "text: summary line" "HIGH 1 | MEDIUM 1 | LOW 1 | INFO 1 (4 total)" "$txt"
t_lacks "text: no ANSI codes when NO_COLOR is set" "$(printf '\033')" "$txt"

# Finish by the owner renders and removes the store
out="$(_shell::security::session::finish 1 json INFO)"
t_json "finish: owner output valid JSON" "$out"
# (command substitution ran finish in a subshell; remove the real store ourselves)
rm -f "$store"
_SHELL_SECURITY_STORE=""

# Empty session: explicit "no findings", valid JSON, header-only CSV
_shell::security::session::begin
empty_store="$_SHELL_SECURITY_STORE"
t_has "empty: text says not a clean result" "not a clean result" "$(_shell::security::render::findings text INFO)"
t_json "empty: valid JSON" "$(_shell::security::render::findings json INFO)"
t_has "empty: total 0" '"total":0' "$(_shell::security::render::findings json INFO)"
t_eq "empty: csv is header only" "1" "$(_shell::security::render::findings csv INFO | wc -l | tr -d ' ')"
_shell::security::finding::unavailable network "listening sockets" "no ss"
t_has "unavailable: recorded as INFO 'Not inspected'" "Not inspected: listening sockets" "$(_shell::security::render::findings text INFO)"
t_has "unavailable: says unknown, not clean" "unknown, not clean" "$(_shell::security::render::findings text INFO)"
rm -f "$empty_store"
_SHELL_SECURITY_STORE=""

# --- kv and table renderers --------------------------------------------------
kv="$(printf 'a%sone\nb%s"two"\n' "$S" "$S" | _shell::security::render::kv json k v "$S")"
t_json "kv json valid" "$kv"
t_eq "kv json exact" '{"a":"one","b":"\"two\""}' "$kv"
t_has "kv csv header" '"k","v"' "$(printf 'a%sone\n' "$S" | _shell::security::render::kv csv k v "$S")"
t_has "kv markdown table" "| k" "$(printf 'a%sone\n' "$S" | _shell::security::render::kv markdown k v "$S")"
_shell::security::render::kv yaml k v "$S" </dev/null >/dev/null 2>&1
t_eq "kv unknown format" "2" "$?"

rows="$(printf 'x y%s=cmd%s3\n' "$S" "$S")"
t_json "table json valid" "$(printf '%s\n' "$rows" | _shell::security::render::table json "name cmd n" "$S")"
t_has "table csv neutralises formulas" "\"'=cmd\"" "$(printf '%s\n' "$rows" | _shell::security::render::table csv "name cmd n" "$S")"
t_eq "table text: header + row" "2" "$(printf '%s\n' "$rows" | _shell::security::render::table text "name cmd n" "$S" | wc -l | tr -d ' ')"
t_eq "table json: empty input is []" "[]" "$(printf '' | _shell::security::render::table json "a b" "$S")"
printf '' | _shell::security::render::table markdown "only" "$S" >/dev/null 2>&1
t_eq "table markdown: 1 column is invalid" "2" "$?"

# --- capabilities and host info ---------------------------------------------
caps="$(shell::security::capabilities --format json)"
t_json "capabilities: valid JSON" "$caps"
t_has "capabilities: lists process-list" '"process-list"' "$caps"
t_rc "capabilities: bad format" 2 shell::security::capabilities --format yaml
info="$(shell::security::host::info --format json)"
t_json "host info: valid JSON" "$info"
t_has "host info: os_family" '"os_family"' "$info"
t_has "host info: collected_at is UTC ISO-8601" 'Z"' "$info"
t_rc "host info: bad arg" 2 shell::security::host::info --nope

# --- help on every public function ------------------------------------------
for fn in capabilities host::info host::users hunt::processes hunt::network hunt::connections; do
	t_rc "help: $fn" 0 shell::security::$fn --help
	t_has "help: $fn usage" "shell::security::$fn" "$T_OUT"
done

# --- structural rules --------------------------------------------------------
all_src="$(cat "$SHELL_TEST_ROOT"/src/security/security_*.sh)"
public="$(printf '%s\n' "$all_src" | grep -oE '^shell::[a-z_]+::[a-z_:]+\(\)' | sed 's/()//' | sort | tr '\n' ' ')"
t_eq "public API is exactly the documented six" "shell::security::capabilities shell::security::host::info shell::security::host::users shell::security::hunt::connections shell::security::hunt::network shell::security::hunt::processes " "$public"
t_rc "no sudo anywhere in the security modules" 1 sh -c 'printf "%s\n" "$1" | grep -qE "(^|[^a-z_#])sudo "' _ "$all_src"
t_rc "no state-changing commands in the security modules" 1 sh -c 'printf "%s\n" "$1" | grep -qE "^[^#]*[[:space:]](rm -rf|kill |pkill |iptables |ufw |launchctl (unload|remove))"' _ "$all_src"

t_done
