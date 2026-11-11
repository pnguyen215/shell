# Documentation

| Folder                        | What it holds                                         | Audience     |
| ----------------------------- | ----------------------------------------------------- | ------------ |
| [`features/`](features)       | One guide per user-facing feature                     | Users        |
| [`development/`](development) | How the library works and the rules for changing it   | Contributors |
| [`api/`](api)                 | Function reference generated from shdoc (`make docs`) | Everyone     |

## features/

- [git-commit-messages.md](features/git-commit-messages.md) — Conventional Commits, `create` and `predict`
- [git-history.md](features/git-history.md) — history explorer for files, functions and line ranges
- [homebrew.md](features/homebrew.md) — `shell::brew::*`
- [markdown.md](features/markdown.md) — `shell::markdown::*`: Markdown, Telegram MarkdownV2 and plain-text builder
- [nvm.md](features/nvm.md) — `shell::nvm::*`
- [ssh.md](features/ssh.md) — `shell::ssh::*` (see also [rsync.md](features/rsync.md))
- [rsync.md](features/rsync.md) — `shell::rsync::*`

## development/

Recommended reading order for contributors:

1. [architecture.md](development/architecture.md) — load sequence, layers, data layout
2. [conventions.md](development/conventions.md) — coding rules checklist (`make lint` enforces them)
3. [commit-messages.md](development/commit-messages.md) — the git commit rules (commit-msg hook, CI gate)

New feature guides go in `features/` as `lower-kebab-case.md`; contributor docs go in `development/`. `api/` is generated: do not edit it by hand.
