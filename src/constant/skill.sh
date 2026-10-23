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
