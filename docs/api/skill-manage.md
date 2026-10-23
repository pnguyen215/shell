# skill/manage.sh

Install, upgrade, uninstall and sync agent skills (Claude Code, OpenCode).

## Overview

Wrappers around the installers of https://github.com/pnguyen215/skills.
Skills are `SKILL.md` folders placed (symlinked by default) in:

| Tool        | Personal scope                     | Project scope                       |
| ----------- | ---------------------------------- | ----------------------------------- |
| Claude Code | `~/.claude/skills/<name>`          | `<project>/.claude/skills/<name>`   |
| OpenCode    | `~/.config/opencode/skills/<name>` | `<project>/.opencode/skills/<name>` |

Every function validates its options, downloads the matching script and
runs it with bash (see shell::skill::run). Restart your Claude Code /
OpenCode session afterwards so the new skills are loaded.

The upstream repository can be changed with `SHELL_SKILL_REPO_SLUG` and
`SHELL_SKILL_REPO_BRANCH` (see constant/skill.sh).

## Index

- [skill/manage.sh](#skillmanagesh)
  - [Overview](#overview)
  - [Index](#index)
    - [shell::skill::install](#shellskillinstall)
      - [Example](#example)
      - [Options](#options)
      - [Exit codes](#exit-codes)
    - [shell::skill::upgrade](#shellskillupgrade)
      - [Example](#example-1)
      - [Options](#options-1)
      - [Exit codes](#exit-codes-1)
    - [shell::skill::uninstall](#shellskilluninstall)
      - [Example](#example-2)
      - [Options](#options-2)
      - [Exit codes](#exit-codes-2)
    - [shell::skill::sync](#shellskillsync)
      - [Example](#example-3)
      - [Options](#options-3)
      - [Arguments](#arguments)
      - [Exit codes](#exit-codes-3)

### shell::skill::install

Install skills into Claude Code and/or OpenCode.
Idempotent: running it again with the same options changes nothing. Any
pre-existing, non-managed skill directory is backed up before it is
replaced. Nothing is ever written outside `$HOME` or `--project-dir`.

#### Example

```bash
shell::skill::install --tool claude --yes
shell::skill::install -t all -s project -k golang,security-secure-coding
shell::skill::install -n --tool opencode
```

#### Options

- **-t** | **--tool**

  Target tool: claude, opencode or all (default: all).

- **-s** | **--scope**

  Scope: personal, project or all (default: personal).

- **-p** | **--project-dir**

  Project root for scope project/all (default: current directory).

- **-m** | **--mode**

  Placement: auto, symlink or copy (default: auto).

- **-k** | **--skills**

  Comma-separated skill slugs (default: every skill).

- **-r** | **--ref**

  Branch, tag or commit to install from.

- **-y** | **--yes**

  Assume yes to prompts (required when not interactive).

- **-v** | **--verbose**

  Verbose installer output.

- **--preview**

  Let the installer print what it would do, changing nothing.

- **-n** | **--dry-run**

  Print the download command instead of running it.

- **-h** | **--help**

  Show help and return.

#### Exit codes

- **0**: Installed (or the command was printed).
- **1**: Download or installation failed.
- **2**: Invalid option or value.
- **3**: The project directory or a prerequisite was not found.

### shell::skill::upgrade

Upgrade installed skills to the latest content.
Refreshes every installed skill (keeping its symlink/copy mode) and, unless
`--no-new` is given, installs skills added upstream into the tool/scope
directories you already use. Skills removed upstream are reported, never
deleted (use shell::skill::sync or shell::skill::uninstall for that).

NOTE: if you installed only a few skills (`-k a,b`) and want to keep it
that way, pass `--no-new`; otherwise every new upstream skill is added.

#### Example

```bash
shell::skill::upgrade --yes
shell::skill::upgrade -k golang --yes
shell::skill::upgrade -n --no-new
```

#### Options

- **-t** | **--tool**

  Target tool: claude, opencode or all (default: all).

- **-s** | **--scope**

  Scope: personal, project or all (default: personal).

- **-p** | **--project-dir**

  Project root for scope project/all (default: current directory).

- **-m** | **--mode**

  Placement: auto, symlink or copy (default: auto).

- **-k** | **--skills**

  Comma-separated skill slugs (default: every installed skill).

- **-r** | **--ref**

  Branch, tag or commit to upgrade to.

- **--no-new**

  Do not install skills that are new upstream.

- **-y** | **--yes**

  Assume yes to prompts (required when not interactive).

- **-v** | **--verbose**

  Verbose installer output.

- **--preview**

  Let the installer print what it would do, changing nothing.

- **-n** | **--dry-run**

  Print the download command instead of running it.

- **-h** | **--help**

  Show help and return.

#### Exit codes

- **0**: Upgraded (or the command was printed).
- **1**: Download or upgrade failed.
- **2**: Invalid option or value.
- **3**: The project directory or a prerequisite was not found.

### shell::skill::uninstall

Uninstall skills that shell::skill::install placed.
Only entries recorded in the installer's manifest (and leftover symlinks
that point into its own cache) are removed; anything else is untouched.
`--purge` also deletes the manifest, backups and the cached clone.

#### Example

```bash
shell::skill::uninstall --tool all --scope all --yes
shell::skill::uninstall -k golang --yes
shell::skill::uninstall -n --purge
```

#### Options

- **-t** | **--tool**

  Target tool: claude, opencode or all (default: all).

- **-s** | **--scope**

  Scope: personal, project or all (default: personal).

- **-p** | **--project-dir**

  Project root for scope project/all (default: current directory).

- **-k** | **--skills**

  Comma-separated skill slugs (default: every installed skill).

- **--purge**

  Also delete the manifest, backups and the cached clone.

- **--no-sweep**

  Only remove manifest-tracked entries; skip the leftover-symlink sweep.

- **-y** | **--yes**

  Assume yes to prompts (required when not interactive).

- **-v** | **--verbose**

  Verbose installer output.

- **--preview**

  Let the installer print what it would do, changing nothing.

- **-n** | **--dry-run**

  Print the download command instead of running it.

- **-h** | **--help**

  Show help and return.

#### Exit codes

- **0**: Uninstalled (or the command was printed).
- **1**: Download or removal failed.
- **2**: Invalid option or value.
- **3**: The project directory or a prerequisite was not found.

### shell::skill::sync

Make one tool's skills directory mirror the repository exactly.
Pulls the latest content, installs missing skills, refreshes existing ones
and (unless `--no-prune`) removes skills that were deleted upstream. Works
even if shell::skill::install was never run.

#### Example

```bash
shell::skill::sync claude --yes
shell::skill::sync opencode -s project --no-prune --yes
shell::skill::sync claude -n
```

#### Options

- **-s** | **--scope**

  Scope: personal, project or all (default: personal).

- **-p** | **--project-dir**

  Project root for scope project/all (default: current directory).

- **-m** | **--mode**

  Placement: auto, symlink or copy (default: auto).

- **-k** | **--skills**

  Comma-separated skill slugs (default: every skill).

- **-r** | **--ref**

  Branch, tag or commit to sync with.

- **--no-prune**

  Keep skills that were deleted upstream.

- **-y** | **--yes**

  Assume yes to prompts (required when not interactive).

- **-v** | **--verbose**

  Verbose installer output.

- **--preview**

  Let the installer print what it would do, changing nothing.

- **-n** | **--dry-run**

  Print the download command instead of running it.

- **-h** | **--help**

  Show help and return.

#### Arguments

- **$1** (string): Tool to sync: `claude` or `opencode`.

#### Exit codes

- **0**: Synced (or the command was printed).
- **1**: Download or sync failed.
- **2**: The tool is missing or unknown, or an option is invalid.
- **3**: The project directory or a prerequisite was not found.
