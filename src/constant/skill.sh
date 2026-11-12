#!/usr/bin/env bash
# @file constant/skill.sh
# @brief Settings for the agent-skills integration (src/skill/).
# @description
#   The skills library (https://github.com/pnguyen215/skills) ships its own
#   installers. `shell::skill::*` downloads and runs them, so everything that
#   identifies the upstream repository lives here and can be overridden from
#   the environment *before* sourcing `src/shell.sh`:
#
#       export SHELL_SKILL_REPO_SLUG="yourname/skills"   # use a fork
#       export SHELL_SKILL_REPO_BRANCH="develop"

# --- Upstream repository -----------------------------------------------------

# GitHub "owner/repo" slug of the skills library.
: "${SHELL_SKILL_REPO_SLUG:=pnguyen215/skills}"

# Branch or tag used when --ref is not given.
: "${SHELL_SKILL_REPO_BRANCH:=master}"

# Host that serves raw files. URLs are assembled as <host>/<slug>/<ref>/<file>.
: "${SHELL_SKILL_URL_RAW_HOST:=https://raw.githubusercontent.com}"

# Directory name the skills installer uses under XDG_STATE_HOME. It holds the
# manifest (manifest.tsv) that records every installed skill.
: "${SHELL_SKILL_STATE_NAME:=pnguyen215-skills}"

# Markers that delimit the skills table inside the upstream README.md.
SHELL_SKILL_TABLE_START="<!-- skills-table:start -->"
SHELL_SKILL_TABLE_END="<!-- skills-table:end -->"

# --- Accepted option values --------------------------------------------------
# Kept as space-separated words so a `case` / loop works in bash 3.2 and zsh.

SHELL_SKILL_TOOLS="claude opencode all"
SHELL_SKILL_SCOPES="personal project all"
SHELL_SKILL_MODES="auto symlink copy"

# --- Cloudflare security-audit skill (shell::skill::audit::*) -----------------
# https://github.com/cloudflare/security-audit-skill is NOT vendored here. It is
# cloned into SHELL_SKILL_AUDIT_DIR and the skill folder inside it is linked into
# each tool's skills directory, so shell::skill::audit::upgrade only has to
# fast-forward that one clone. Override before sourcing `src/shell.sh`:
#
#       export SHELL_SKILL_AUDIT_REPO_SLUG="yourname/security-audit-skill"
#       export SHELL_SKILL_AUDIT_REPO_URL="file:///path/to/mirror.git"

: "${SHELL_SKILL_AUDIT_REPO_SLUG:=cloudflare/security-audit-skill}"
: "${SHELL_SKILL_AUDIT_REPO_BRANCH:=main}"
: "${SHELL_SKILL_AUDIT_REPO_URL:=https://github.com/${SHELL_SKILL_AUDIT_REPO_SLUG}.git}"

# Folder name the skill gets in a tool's skills directory (must equal the
# `name:` in its SKILL.md), and where that folder lives inside the clone.
: "${SHELL_SKILL_AUDIT_NAME:=security-audit}"
: "${SHELL_SKILL_AUDIT_SUBDIR:=skills/security-audit}"

# Managed clone. Only this directory is ever fetched into or reset.
: "${SHELL_SKILL_AUDIT_DIR:=${SHELL_CONFIG_DIR:-$HOME/.shell-config}/skill/security-audit-skill}"

# Marker written into a copied (--mode copy) skill so it is recognised as ours.
SHELL_SKILL_AUDIT_MARKER=".shell-skill-audit"

# Skills directories, relative to $HOME (personal) or the project root (project).
SHELL_SKILL_AUDIT_CLAUDE_PERSONAL=".claude/skills"
SHELL_SKILL_AUDIT_CLAUDE_PROJECT=".claude/skills"
SHELL_SKILL_AUDIT_OPENCODE_PERSONAL=".config/opencode/skills"
SHELL_SKILL_AUDIT_OPENCODE_PROJECT=".opencode/skills"

SHELL_SKILL_AUDIT_MODES="symlink copy"
