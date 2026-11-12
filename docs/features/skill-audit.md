# Cloudflare security-audit skill

`shell::skill::audit::*` integrates [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill) into **Claude Code** and **OpenCode**. The skill is _used_, not copied: this repository contains none of its files.

## How it works

```
~/.shell-config/skill/security-audit-skill/      managed shallow git clone (upstream)
        └── skills/security-audit/               the skill
              ▲                  ▲
~/.claude/skills/security-audit ─┘                symlink  (Claude Code, personal)
~/.config/opencode/skills/security-audit ─────────┘ symlink  (OpenCode, personal)
<project>/.claude/skills/security-audit            project scope
<project>/.opencode/skills/security-audit          project scope
```

`upgrade` fetches the newest upstream commit into the clone. Every symlink sees it immediately, so there is nothing to re-install. `--mode copy` places a real copy (for tools that do not follow symlinks) and `upgrade` re-copies it.

## Commands

| Command                          | Purpose                                                                  |
| -------------------------------- | ------------------------------------------------------------------------ |
| `shell::skill::audit::install`   | Clone upstream and link the skill (idempotent)                           |
| `shell::skill::audit::upgrade`   | Fetch the latest upstream content; refresh copies                        |
| `shell::skill::audit::status`    | Show the clone, its commit and every destination (`--check` asks remote) |
| `shell::skill::audit::uninstall` | Remove links/copies this module made (`--purge` also deletes the clone)  |

Common options: `-t claude|opencode|all`, `-s personal|project|all`, `-p <project-dir>`, `-n` (dry-run). `install` also takes `-m symlink|copy`, `-r <ref>` and `-f`. Defaults: install/upgrade/uninstall use scope `personal`; `status` looks at every scope.

After installing, restart the agent and ask: _"security audit this codebase"_.

## Safety

- Only the managed clone is fetched into or reset. A directory at that path that is not a git clone is refused.
- A link is "ours" only if it points at the clone's skill folder; a copy only if it holds the `.shell-skill-audit` marker. Anything else is never replaced or deleted. `--force` moves a foreign skill to `~/.shell-config/backup/skill-audit/` before replacing it.
- A fetched ref is checked to contain `skills/security-audit/SKILL.md` **before** the working tree changes, so a bad ref cannot break a working install.
- The skill is third-party prompt content (plus Node validator scripts) that your agent follows. To avoid tracking `main`, pin a reviewed commit: `shell::skill::audit::upgrade --ref <full 40-character SHA>`. The pin is remembered, so later plain upgrades stay on it; `--ref main` returns to the branch. Tags and branches work too; short SHAs do not (a `git fetch` limit).
- Upstream recommends running target code only inside an OS-enforced sandbox; see its README.

## Configuration

Set before sourcing the library (see `src/constant/skill.sh`):

| Variable                        | Default                                           |
| ------------------------------- | ------------------------------------------------- |
| `SHELL_SKILL_AUDIT_REPO_SLUG`   | `cloudflare/security-audit-skill`                 |
| `SHELL_SKILL_AUDIT_REPO_BRANCH` | `main`                                            |
| `SHELL_SKILL_AUDIT_REPO_URL`    | `https://github.com/<slug>.git` (mirrors / tests) |
| `SHELL_SKILL_AUDIT_DIR`         | `~/.shell-config/skill/security-audit-skill`      |

Related: the general `shell::skill::install|upgrade|sync` family installs the separate [pnguyen215/skills](https://github.com/pnguyen215/skills) collection.
