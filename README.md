# shell

A lightweight shell library that streamlines your development environment on **Linux** (Ubuntu 22.04 / 24.04 and other mainstream distributions) and **macOS**. About 330 documented functions for files, bookmarks, a key/value config store, INI files, SSH tunnels, workspaces, Git/GitHub, Python/Go project helpers, AES encryption and Telegram notifications — all with dry-run (`-n`) support.

Works when sourced from **bash ≥ 3.2** (the macOS system bash) and **zsh**.

## Install

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pnguyen215/shell/master/install.sh)"
```

The installer needs only `curl` and `tar`. It downloads to a staging directory, verifies the archive, swaps it into `~/shell` (keeping the previous version as `~/shell.bak`) and adds one `source` line to the profile your login shell reads. Re-running it is safe.

| Task | Command |
|---|---|
| Upgrade | `shell::upgrade` or `/bin/bash -c "$(curl -fsSL .../upgrade.sh)"` |
| Uninstall | `shell::uninstall` (keeps `~/.shell-config`; add `--purge` to delete it) |
| Check dependencies | `shell::dependency::doctor` |

Overrides: `SHELL_INSTALL_DIR`, `SHELL_REPO_BRANCH`, `SHELL_NO_PROFILE=1`.

## Quick start

```bash
shell::bookmark::add webapp            # remember the current directory
shell::goto::run webapp                # ...and jump back to it later
shell::conf::key::add API_KEY "s3cr3t" # Base64-encoded key/value store (files are mode 600)
shell::conf::key::get API_KEY
shell::git::branch::create -n feature_x   # -n = dry run: print the commands
shell::net::port::kill 3000            # SIGTERM whatever LISTENS on :3000
shell::fs::browse ~/docs               # pick a file with fzf, then act on it
```

Every function supports `-h / --help`. Most destructive or state-changing ones support `-n / --dry-run`, which prints the command (and copies it to the clipboard when a clipboard tool exists) instead of running it.

Short aliases live in [`src/alias/alias.sh`](src/alias/alias.sh) (e.g. `sgbb` = backup branch).

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

## Development

```bash
make test    # bash + zsh test suites
make lint    # naming, shdoc coverage, portability, shellcheck, shfmt
make docs    # regenerate docs/api (needs shdoc: https://github.com/reconquest/shdoc)
```

Read [docs/CONVENTIONS.md](docs/CONVENTIONS.md) before adding a function.

## License

MIT
