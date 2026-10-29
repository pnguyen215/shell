# shell

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell: bash >= 3.2, zsh](https://img.shields.io/badge/Shell-bash%20%3E%3D%203.2%20%7C%20zsh-blue.svg)](https://github.com/pnguyen215/shell)
[![Platform: Linux, macOS](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS-green.svg)](https://github.com/pnguyen215/shell)

A lightweight shell library that streamlines your development environment on **Linux** (Ubuntu 22.04/24.04 and other mainstream distributions) and **macOS**. It provides ~330 documented functions for files, bookmarks, a key/value config store, INI files, SSH tunnels, workspaces, Git/GitHub, Python/Go project helpers, AES encryption, and Telegram notifications — all with dry-run (`-n`) support.

Works when sourced from **bash ≥ 3.2** (including the macOS system bash) and **zsh**.

## Prerequisites

- `curl` and `tar` (preinstalled on macOS and most Linux distributions)
- `bash ≥ 3.2` or `zsh`
- Optional: `git`, `fzf` (required for many interactive workflows). Others are installed on demand.

## Installation

Download and run the installer. This installs to `~/shell` by default and sources it from your shell profile.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pnguyen215/shell/master/install.sh)"
```

After installation, restart your terminal or source your profile:

```bash
# For zsh
source ~/.zshrc

# For bash (macOS login shell)
source ~/.bash_profile

# For bash (Linux)
source ~/.bashrc
```

### Customization

| Environment Variable | Default            | Description                       |
| -------------------- | ------------------ | --------------------------------- |
| `SHELL_INSTALL_DIR`  | `~/shell`          | Override the install directory    |
| `SHELL_REPO_SLUG`    | `pnguyen215/shell` | Override the GitHub repository    |
| `SHELL_REPO_BRANCH`  | `master`           | Install from a specific branch    |
| `SHELL_NO_PROFILE=1` | `0`                | Skip modifying your shell profile |

## Upgrade

### Via curl script (works even if shell is not currently sourced)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pnguyen215/shell/master/upgrade.sh)"
```

### From a sourced shell

```bash
shell::upgrade
```

The upgrader stages the new version, verifies it, and only then swaps it in (keeping the previous version as `~/shell.bak`).

## Uninstall

### Via curl script

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pnguyen215/shell/master/uninstall.sh)"
```

### From a sourced shell

```bash
shell::uninstall
```

### Remove all data too

By default, user data in `~/.shell-config/` (keys, bookmarks, workspaces) is preserved. To delete it:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pnguyen215/shell/master/uninstall.sh)" -- --purge
# or
shell::uninstall --purge
```

The uninstaller removes the installation directory, deletes `~/shell.bak` if present, and strips the `source` hook from `~/.zshrc`, `~/.bashrc`, and `~/.bash_profile` (backing up each profile as `*.shell-bak`).

## Check Dependencies

```bash
shell::dependency::doctor
```

To report only (without auto-installing):

```bash
SHELL_AUTO_INSTALL_DEPS=0 shell::dependency::doctor
```

## Quick Start

```bash
shell::bookmark::add webapp              # remember the current directory
shell::goto::run webapp                  # jump back to it later
shell::conf::key::add API_KEY "s3cr3t"   # store a key (Base64, written with mode 600)
shell::conf::key::get API_KEY
shell::git::branch::create -n feature_x # -n = dry run: print commands without executing
shell::net::port::kill 3000              # SIGTERM whatever is listening on :3000
shell::fs::browse ~/docs                 # pick a file with fzf, then act on it
```

- Every function supports `-h` / `--help`.
- Most destructive or state-changing functions support `-n` / `--dry-run` (prints the command and copies it to the clipboard if available).
- Short aliases are defined in [`src/alias/alias.sh`](src/alias/alias.sh) (e.g., `sgbb` = backup branch).

## Agent Skills

Install the [pnguyen215/skills](https://github.com/pnguyen215/skills) collection (`SKILL.md` files) into Claude Code and/or OpenCode:

```bash
shell::skill::list golang                          # browse upstream skills (filter by category / slug / tag)
shell::skill::install --tool claude --yes          # all skills, personal scope, symlinked
shell::skill::install -t all -s project -k golang,security-secure-coding
shell::skill::installed                            # what shell::skill::install placed
shell::skill::upgrade --yes                        # refresh, and add skills new upstream (--no-new to skip)
shell::skill::sync claude --yes                    # mirror the repo exactly, pruning deleted skills
shell::skill::uninstall --tool all --scope all --yes
```

Add `-n` to print the download command instead of running it, or `--preview` to let the installer show what it would change. Restart your Claude Code / OpenCode session afterwards. Use a fork with `SHELL_SKILL_REPO_SLUG` / `SHELL_SKILL_REPO_BRANCH`. Full reference: [`docs/api/skill-manage.md`](docs/api/skill-manage.md), [`skill-query.md`](docs/api/skill-query.md). Aliases: `ssk-in`, `ssk-up`, `ssk-rm`, `ssk-sync`, `ssk-ls`, `ssk-lsi`.

## Naming

Every function is named **`shell::<category>::<name>`**, with an optional `::fzf` suffix for the interactive variant:

```
shell::git::branch::checkout       shell::git::branch::checkout::fzf
shell::conf::key::get              shell::conf::key::get::fzf
shell::fs::copy                    shell::fs::copy::fzf
```

The only exceptions are the four lifecycle functions in [`src/shell.sh`](src/shell.sh) (`shell::version`, `shell::upgrade`, `shell::uninstall`, `shell::source_directory`). Upgrading from an older release? See [docs/MIGRATION.md](docs/MIGRATION.md) for the complete old → new table.

## Layout

```
.
├── install.sh  upgrade.sh  uninstall.sh   # bootstrap scripts (curl-able)
├── Makefile                               # make test | lint | fmt | docs | doctor
├── docs/
│   ├── ARCHITECTURE.md  CONVENTIONS.md  MIGRATION.md
│   └── api/                               # generated reference (make docs)
├── scripts/                               # lint.sh, gen_docs.sh
├── test/                                  # run under bash and zsh
├── .github/workflows/                     # CI: lint, test (Linux+macOS), docs
└── src/
    ├── shell.sh        # loader / entry point
    ├── constant/       # ALL configuration: paths, URLs, colours, defaults, return codes
    ├── core/           # console, logger, os, exec, clipboard, fzf, ask (prompts)
    ├── dependency/     # one installer per external tool (fzf, jq, curl, git, ...), package manager, Homebrew, Oh My Zsh
    ├── lib/            # fs, net, process, permission, strings, conf, ini, profile, bookmark, goto, ssh, workspace
    ├── skill/          # agent skills for Claude Code / OpenCode: install, upgrade, uninstall, sync
    ├── lang/           # git, go, python, java, nodejs, angular
    ├── devops/         # GitHub Actions scaffolding
    ├── shield/         # AES-256-CBC helpers
    ├── bot/            # Telegram
    └── alias/          # short aliases
```

## Configuration

All constants are in [`src/constant/`](src/constant) and can be overridden from the environment **before** sourcing:

```bash
export SHELL_CONFIG_DIR="$HOME/.config/shell"   # default: ~/.shell-config
export SHELL_LOGGER_LEVEL=INFO                  # DEBUG | INFO | WARN | ERROR | FATAL
export SHELL_AUTO_INSTALL_DEPS=0                # only report missing tools, never install
source "$HOME/shell/src/shell.sh"
```

User data (keys, bookmarks, workspaces) lives under `SHELL_CONFIG_DIR` with mode 700/600.

## Dependencies

Required: `git`, `curl`, `fzf`. Optional (installed on demand): `jq`, `openssl`, `lsof`, `column`, `ssh-keygen`. Installation uses the native package manager (apt, dnf, yum, pacman, zypper, apk, Homebrew) — see [`src/dependency/`](src/dependency). Run `make doctor` for a report.

## Troubleshooting

- **"curl/tar not found"**: Install `curl` and `tar` via your package manager (e.g., `apt install curl tar` or `brew install curl`).
- **Profile not updated**: Set `SHELL_NO_PROFILE=1` and manually add `source "$HOME/shell/src/shell.sh"` to your shell profile.
- **Functions not available after upgrade**: Restart your terminal or run `source "$HOME/shell/src/shell.sh"`.
- **Missing dependencies**: Run `shell::dependency::doctor` to see what's missing. Many can be auto-installed if `SHELL_AUTO_INSTALL_DEPS=1` (default).
- **Permission issues**: Config files are written with restrictive modes (`~/.shell-config` 700, `key.conf` 600). Ensure your home directory permissions are correct.

### Commit messages and emoji

`shell::git::commit::create` (`sgcf`) and `shell::git::commit::predict` write [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) headers: `<type>[(scope)]: <description>`. The type is always the prefix. Menu labels that are not conventional types are mapped onto one (`WIP` → `chore(wip)`, `dependency` → `build(deps)`, `initial source` → `chore(init)`).

Emoji are **off by default**. When on, the gitmoji goes after the colon, so the header stays valid:

```bash
shell::git::commit::create                  # feat: add login #12
shell::git::commit::create --emoji          # feat: :sparkles: add login #12
export SHELL_GIT_COMMIT_EMOJI=true          # turn them on everywhere (put it in your ~/.zshrc or ~/.bashrc)
shell::git::commit::create --no-emoji       # ...and off for one commit
```

`--emoji` / `--no-emoji` win over `SHELL_GIT_COMMIT_EMOJI`. Both commands accept them.

## Development

```bash
make test    # run bash + zsh test suites
make test T=squash                         # only test files whose name contains "squash"
make test-fn F=shell::git::commit::squash  # only test files that mention this function
make test-list F=shell::git::commit::squash  # just list which files would run
SHELLS=bash make test T=squash             # skip zsh for a faster loop
make lint    # naming, shdoc coverage, portability, shellcheck, shfmt
make docs    # regenerate docs/api (requires shdoc: https://github.com/reconquest/shdoc)
make doctor  # report installed dependencies
```

Read [docs/CONVENTIONS.md](docs/CONVENTIONS.md) before adding a function. For architecture details, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## License

This project is licensed under the [MIT License](LICENSE).

Copyright © 2026 [pnguyen215](https://github.com/pnguyen215).
