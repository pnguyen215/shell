#!/usr/bin/env bash
# Cloudflare security-audit skill integration. A local git repository stands in
# for the upstream, so nothing touches the network.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup
unset XDG_STATE_HOME

# --- fake upstream: a repo with skills/security-audit/SKILL.md -------------------
up="$HOME/upstream"
mkdir -p "$up/skills/security-audit"
git -C "$up" init -q -b main
git -C "$up" config user.email t@example.com
git -C "$up" config user.name t
echo "v1" >"$up/skills/security-audit/SKILL.md"
git -C "$up" add -A
git -C "$up" commit -q -m v1
c1_full="$(git -C "$up" rev-parse HEAD)"
c1="$(git -C "$up" rev-parse --short HEAD)"

export SHELL_SKILL_AUDIT_REPO_URL="file://$up"
export SHELL_SKILL_AUDIT_DIR="$HOME/clone"
proj="$HOME/proj"
mkdir "$proj"
src="$SHELL_SKILL_AUDIT_DIR/skills/security-audit"
claude="$HOME/.claude/skills/security-audit"
oc="$HOME/.config/opencode/skills/security-audit"

t_rc "install is defined" 0 type shell::skill::audit::install
t_rc "upgrade is defined" 0 type shell::skill::audit::upgrade
t_rc "private helper is not public" 1 type shell::skill::audit::is_managed

# --- dry-run changes nothing ----------------------------------------------------
t_rc "install -n" 0 shell::skill::audit::install -n
t_has "dry-run prints the fetch" "fetch" "$T_OUT"
t_has "dry-run prints the link" "ln -s" "$T_OUT"
t_rc "dry-run created no clone" 1 test -e "$SHELL_SKILL_AUDIT_DIR"
t_rc "dry-run created no link" 1 test -e "$claude"

# --- validation -----------------------------------------------------------------
t_rc "bad tool" 2 shell::skill::audit::install -n --tool vim
t_rc "bad scope" 2 shell::skill::audit::install -n --scope global
t_rc "bad mode" 2 shell::skill::audit::install -n --mode hardlink
t_rc "bad ref" 2 shell::skill::audit::install -n --ref "x; y"
t_rc "ref may not look like an option" 2 shell::skill::audit::install -n --ref --force
t_rc "option without value" 2 shell::skill::audit::install -n --tool
t_rc "unknown option" 2 shell::skill::audit::install -n --bogus
t_rc "--purge is uninstall-only" 2 shell::skill::audit::install -n --purge
t_rc "--force is install-only" 2 shell::skill::audit::upgrade -n --force
t_rc "--mode is install-only" 2 shell::skill::audit::upgrade -n --mode copy
t_rc "--check is status-only" 2 shell::skill::audit::install -n --check
t_rc "project dir must exist" 3 shell::skill::audit::install -n --project-dir "$HOME/nope"

# --- upgrade/status before install ----------------------------------------------
t_rc "upgrade before install" 3 shell::skill::audit::upgrade
t_rc "status before install" 0 shell::skill::audit::status
t_has "status says not installed" "not installed" "$T_OUT"

# --- install: symlink into both tools -------------------------------------------
t_rc "install" 0 shell::skill::audit::install
t_rc "claude link exists" 0 test -L "$claude"
t_rc "opencode link exists" 0 test -L "$oc"
t_eq "link points into the clone" "$src" "$(readlink "$claude")"
t_eq "skill content is readable through the link" "v1" "$(cat "$claude/SKILL.md")"
t_rc "nothing was vendored into this repo" 1 test -e "$SHELL_TEST_ROOT/skills"
t_rc "install is idempotent" 0 shell::skill::audit::install
t_has "second run is a no-op" "already linked" "$T_OUT"

# --- upgrade picks up new upstream content through the link ---------------------
echo "v2" >"$up/skills/security-audit/SKILL.md"
git -C "$up" commit -q -am v2
c2="$(git -C "$up" rev-parse --short HEAD)"
t_rc "status --check sees the update" 0 shell::skill::audit::status --check
t_has "update available is reported" "Update available" "$T_OUT"
t_rc "upgrade" 0 shell::skill::audit::upgrade
t_has "upgrade reports old -> new" "$c1 -> $c2" "$T_OUT"
t_eq "link now serves v2" "v2" "$(cat "$claude/SKILL.md")"
t_eq "opencode link serves v2" "v2" "$(cat "$oc/SKILL.md")"
t_rc "upgrade when current" 0 shell::skill::audit::upgrade
t_has "already up to date" "Already up to date" "$T_OUT"

# --- a ref that lacks the skill leaves the install untouched ---------------------
git -C "$up" checkout -q -b broken
git -C "$up" rm -q -r skills
git -C "$up" commit -q -m broken
git -C "$up" checkout -q main
t_rc "ref without the skill" 3 shell::skill::audit::upgrade --ref broken
t_eq "install still serves v2" "v2" "$(cat "$claude/SKILL.md")"

# --- pinning a ref sticks across upgrades ---------------------------------------
t_rc "pin to the first commit" 0 shell::skill::audit::upgrade --ref "$c1_full"
t_rc "short sha is rejected clearly" 1 shell::skill::audit::upgrade --ref "$c1"
t_has "short sha hint" "full 40-character SHA" "$T_OUT"
t_eq "pinned content" "v1" "$(cat "$claude/SKILL.md")"
t_rc "plain upgrade keeps the pin" 0 shell::skill::audit::upgrade
t_eq "still pinned" "v1" "$(cat "$claude/SKILL.md")"
t_rc "back to the branch" 0 shell::skill::audit::upgrade --ref main
t_eq "branch content" "v2" "$(cat "$claude/SKILL.md")"

# --- status ---------------------------------------------------------------------
t_rc "status" 0 shell::skill::audit::status --tool claude --scope personal
t_has "status row" "claude	personal	symlink	$claude" "$T_OUT"

# --- a foreign skill is never overwritten ---------------------------------------
shell::skill::audit::uninstall >/dev/null 2>&1
t_rc "uninstall removed the claude link" 1 test -e "$claude"
t_rc "clone stays without --purge" 0 test -d "$SHELL_SKILL_AUDIT_DIR/.git"
mkdir -p "$claude"
echo "mine" >"$claude/SKILL.md"
t_rc "foreign skill blocks install" 7 shell::skill::audit::install --tool claude
t_eq "foreign skill untouched" "mine" "$(cat "$claude/SKILL.md")"
t_rc "uninstall skips a foreign skill" 0 shell::skill::audit::uninstall --tool claude
t_has "uninstall explains" "not managed" "$T_OUT"
t_eq "foreign skill survives uninstall" "mine" "$(cat "$claude/SKILL.md")"
t_rc "--force backs up and replaces" 0 shell::skill::audit::install --tool claude --force
t_rc "replaced by a link" 0 test -L "$claude"
t_rc "backup was made" 0 test -n "$(find "$SHELL_CONFIG_BACKUP_DIR/skill-audit" -name SKILL.md 2>/dev/null)"

# --- copy mode and project scope ------------------------------------------------
shell::skill::audit::uninstall --scope all >/dev/null 2>&1
t_rc "install copy, project scope" 0 shell::skill::audit::install --mode copy --scope project --project-dir "$proj"
p_claude="$proj/.claude/skills/security-audit"
p_oc="$proj/.opencode/skills/security-audit"
t_rc "copy is a real directory" 1 test -L "$p_claude"
t_eq "copied content" "v2" "$(cat "$p_claude/SKILL.md")"
t_rc "opencode project copy" 0 test -f "$p_oc/SKILL.md"
t_rc "personal scope untouched" 1 test -e "$claude"
echo "v3" >"$up/skills/security-audit/SKILL.md"
git -C "$up" commit -q -am v3
t_rc "upgrade refreshes the copy" 0 shell::skill::audit::upgrade --scope project --project-dir "$proj"
t_eq "copy refreshed" "v3" "$(cat "$p_claude/SKILL.md")"

# --- uninstall --purge ----------------------------------------------------------
t_rc "uninstall -n touches nothing" 0 shell::skill::audit::uninstall -n --scope project --project-dir "$proj" --purge
t_rc "dry-run kept the copy" 0 test -d "$p_claude"
t_rc "uninstall --purge" 0 shell::skill::audit::uninstall --scope project --project-dir "$proj" --purge
t_rc "copy removed" 1 test -e "$p_claude"
t_rc "clone removed" 1 test -e "$SHELL_SKILL_AUDIT_DIR"

# --- a non-git directory in the way of the clone is refused ---------------------
mkdir -p "$SHELL_SKILL_AUDIT_DIR"
echo x >"$SHELL_SKILL_AUDIT_DIR/file"
t_rc "non-git clone dir is refused" 7 shell::skill::audit::install
t_eq "its content is intact" "x" "$(cat "$SHELL_SKILL_AUDIT_DIR/file")"

# --- help -----------------------------------------------------------------------
t_rc "install -h" 0 shell::skill::audit::install -h
t_has "help shows usage" "shell::skill::audit::install" "$T_OUT"
t_rc "status -h" 0 shell::skill::audit::status --help

t_done
