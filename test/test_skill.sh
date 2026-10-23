#!/usr/bin/env bash
# Agent-skills integration: option validation, command construction, exit-code
# mapping, and the read-only queries. Nothing here touches the network: a fake
# curl serves the "downloaded" scripts and the README.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup
unset XDG_STATE_HOME

base="https://raw.githubusercontent.com/pnguyen215/skills/master"

# --- loading ------------------------------------------------------------------
t_has "module group is registered" "skill" "${SHELL_MODULE_GROUPS[*]}"
t_rc "install is defined" 0 type shell::skill::install
t_rc "sync is defined" 0 type shell::skill::sync

# --- dry-run builds the right command -----------------------------------------
t_rc "install -n succeeds" 0 shell::skill::install -n
t_has "install -n: url" "$base/install.sh" "$T_OUT"
t_has "install -n: runs with bash" "| bash" "$T_OUT"

t_rc "install -n with options" 0 shell::skill::install -n --tool claude -s project -m copy -k golang,security-secure-coding -y
t_has "install -n: tool" "--tool claude" "$T_OUT"
t_has "install -n: scope" "--scope project" "$T_OUT"
t_has "install -n: mode" "--mode copy" "$T_OUT"
t_has "install -n: skills flag" "--skills golang" "$T_OUT"
t_has "install -n: second skill" "security-secure-coding" "$T_OUT"
t_has "install -n: yes" "--yes" "$T_OUT"

t_rc "--opt=value form" 0 shell::skill::install -n --tool=opencode
t_has "--opt=value is forwarded" "--tool opencode" "$T_OUT"

t_rc "--preview becomes the script's --dry-run" 0 shell::skill::install -n --preview
t_has "preview forwarded" "--dry-run" "$T_OUT"

t_rc "upgrade -n --no-new" 0 shell::skill::upgrade -n --no-new
t_has "upgrade url" "$base/upgrade.sh" "$T_OUT"
t_has "upgrade flag" "--no-new" "$T_OUT"

t_rc "uninstall -n --purge" 0 shell::skill::uninstall -n --purge --no-sweep
t_has "uninstall url" "$base/uninstall.sh" "$T_OUT"
t_has "uninstall flag" "--purge" "$T_OUT"

t_rc "sync claude -n" 0 shell::skill::sync claude -n --no-prune
t_has "sync_claude url" "$base/sync_claude.sh" "$T_OUT"
t_rc "sync opencode -n" 0 shell::skill::sync opencode -n
t_has "sync_opencode url" "$base/sync_opencode.sh" "$T_OUT"

t_rc "--ref changes the url" 0 shell::skill::install -n --ref v1.2.0
t_has "ref in url" "/pnguyen215/skills/v1.2.0/install.sh" "$T_OUT"
t_has "ref forwarded" "--ref v1.2.0" "$T_OUT"

# A fork is selected through the constants, with no code change.
SHELL_SKILL_REPO_SLUG="acme/skills" shell::skill::install -n >"$HOME/fork.out" 2>&1
t_has "fork slug is honoured" "/acme/skills/master/install.sh" "$(cat "$HOME/fork.out")"

# --- validation: nothing is downloaded on bad input ----------------------------
t_rc "bad tool" 2 shell::skill::install -n --tool vim
t_rc "bad scope" 2 shell::skill::install -n --scope global
t_rc "bad mode" 2 shell::skill::install -n --mode hardlink
t_rc "bad ref" 2 shell::skill::install -n --ref "x; y"
t_rc "ref may not look like an option" 2 shell::skill::install -n --ref --yes
t_rc "skills with uppercase/space" 2 shell::skill::install -n --skills "Go Lang"
t_rc "option without value" 2 shell::skill::install -n --tool
t_rc "unknown option" 2 shell::skill::install -n --force
t_rc "stray argument" 2 shell::skill::install -n golang
t_rc "--no-new is upgrade-only" 2 shell::skill::install -n --no-new
t_rc "--purge is uninstall-only" 2 shell::skill::upgrade -n --purge
t_rc "sync needs a tool" 2 shell::skill::sync -n
t_rc "sync rejects other tools" 2 shell::skill::sync vim -n
t_rc "sync tool is fixed" 2 shell::skill::sync claude -n --tool opencode
t_rc "project dir must exist" 3 shell::skill::install -n --scope project --project-dir "$HOME/nope"
mkdir "$HOME/proj"
t_rc "project dir accepted" 0 shell::skill::install -n --scope project --project-dir "$HOME/proj"

# Regression guard: an injection attempt is rejected and nothing is executed.
marker="$HOME/PWNED"
t_rc "injection in --skills is rejected" 2 shell::skill::install -n --skills "a;touch $marker"
t_rc "injection in --tool is rejected" 2 shell::skill::install -n --tool "claude;touch $marker"
t_rc "no command ran" 1 test -e "$marker"

# --- help ----------------------------------------------------------------------
t_rc "install -h" 0 shell::skill::install -h
t_has "help shows usage" "shell::skill::install" "$T_OUT"
t_rc "sync -h" 0 shell::skill::sync --help

# --- real execution against a fake curl ----------------------------------------
mkdir "$HOME/bin"
cat >"$HOME/bin/curl" <<'FAKE'
#!/bin/sh
# Emulates the two requests the module makes: -o <file> <url> (a script) and <url> (the README).
out=""
while [ "$#" -gt 0 ]; do
	case "$1" in
	-o) out="$2"; shift 2 ;;
	-*) shift ;;
	*) url="$1"; shift ;;
	esac
done
case "$url" in
*README.md)
	[ -n "${FAKE_NO_README-}" ] && exit 22
	cat <<'README'
# skills

<!-- skills-table:start -->
| Category          | Skill                  | Tags                         |
| ----------------- | ---------------------- | ---------------------------- |
| `language-specific` | `golang`             | `golang`, `go-modules`       |
| `security`        | `security-secure-coding` | `security`, `owasp`        |
| `testing`         | `testing-unit-testing` | `testing`, `tdd`             |
<!-- skills-table:end -->
README
	;;
*)
	[ -n "${FAKE_EMPTY-}" ] && : >"$out" && exit 0
	cat >"$out" <<'SCRIPT'
printf '%s\n' "$@" >"$FAKE_ARGS_LOG"
echo "repo=$AGENT_SKILLS_REPO ref=$AGENT_SKILLS_REF" >>"$FAKE_ARGS_LOG"
exit "${FAKE_EXIT:-0}"
SCRIPT
	;;
esac
FAKE
chmod +x "$HOME/bin/curl"
export PATH="$HOME/bin:$PATH" FAKE_ARGS_LOG="$HOME/args.log"

t_rc "install runs the downloaded script" 0 shell::skill::install --tool claude -k golang --yes
log="$(cat "$FAKE_ARGS_LOG")"
t_has "script got --yes" "--yes" "$log"
t_has "script got --tool claude" "claude" "$log"
t_has "script got the skill list" "golang" "$log"
t_has "repo/ref exported to the script" "repo=pnguyen215/skills ref=master" "$log"
t_eq "env does not leak into this shell" "" "${AGENT_SKILLS_REPO-}"

# Arguments with spaces stay one word (argv style, no re-parsing).
mkdir "$HOME/my proj"
shell::skill::install --scope project --project-dir "$HOME/my proj" >/dev/null 2>&1
t_has "path with a space is one argument" "$HOME/my proj" "$(cat "$FAKE_ARGS_LOG")"

# The installer's exit status maps to the library's return codes.
FAKE_EXIT=2 t_rc "script exit 2 -> RETURN_INVALID" 2 shell::skill::upgrade --yes
FAKE_EXIT=3 t_rc "script exit 3 -> RETURN_NOT_FOUND" 3 shell::skill::upgrade --yes
FAKE_EXIT=5 t_rc "script exit 5 (network) -> RETURN_FAILURE" 1 shell::skill::upgrade --yes
FAKE_EMPTY=1 t_rc "an empty download fails" 1 shell::skill::install --yes

# --- list ---------------------------------------------------------------------
out="$(shell::skill::list 2>/dev/null)"
t_eq "list: three skills" "3" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
t_eq "list: tab-separated row" "security	security-secure-coding	security, owasp" "$(printf '%s\n' "$out" | sed -n 2p)"
t_eq "list: header and separator are skipped" "0" "$(printf '%s\n' "$out" | grep -c 'Category\|---')"
t_eq "list: filter is case-insensitive" "testing-unit-testing" "$(shell::skill::list TDD 2>/dev/null | cut -f2)"
t_rc "list: no match" 8 shell::skill::list zzz-nothing
FAKE_NO_README=1 t_rc "list: download failure" 1 shell::skill::list
t_rc "list: bad ref" 2 shell::skill::list --ref "a b"
t_rc "list: unknown option" 2 shell::skill::list --bogus

# --- installed ----------------------------------------------------------------
t_rc "installed: nothing yet" 8 shell::skill::installed
state="$HOME/.local/state/pnguyen215-skills"
mkdir -p "$state"
printf 'claude\tpersonal\tgolang\t/h/.claude/skills/golang\t/src/golang\tsymlink\t2026-01-01T00:00:00Z\n' >"$state/manifest.tsv"
printf 'opencode\tproject\ttesting-unit-testing\t/p/.opencode/skills/t\t/src/t\tcopy\t2026-01-01T00:00:00Z\n' >>"$state/manifest.tsv"
t_eq "installed: all rows" "2" "$(shell::skill::installed 2>/dev/null | wc -l | tr -d ' ')"
t_eq "installed: row layout" "claude	personal	golang	symlink	/h/.claude/skills/golang" "$(shell::skill::installed -t claude 2>/dev/null)"
t_eq "installed: scope filter" "testing-unit-testing" "$(shell::skill::installed --scope=project 2>/dev/null | cut -f3)"
t_eq "installed: text filter" "golang" "$(shell::skill::installed GOLANG 2>/dev/null | cut -f3)"
t_rc "installed: no match" 8 shell::skill::installed -t opencode -s personal
t_rc "installed: bad tool" 2 shell::skill::installed -t vim
t_rc "installed: bad scope" 2 shell::skill::installed -s global

# --- run_remote_script forwards arguments (used by the module) ------------------
shell::net::run_remote_script "$base/install.sh" bash "a b" '$HOME' >/dev/null 2>&1
t_eq "run_remote_script: args reach the script verbatim" 'a b
$HOME' "$(sed -n 1,2p "$FAKE_ARGS_LOG")"

t_done
