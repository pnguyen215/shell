# Homebrew

`shell::brew::*` wraps the `brew` commands of the [Homebrew cheat sheet](https://quickref.me/homebrew) and adds fzf pickers and a finder for packages you no longer use. Installing or removing **Homebrew itself** is `shell::homebrew::install` / `shell::homebrew::uninstall`.

Every function has `-h` and `-n | --dry-run` (print the `brew` command, run nothing). Package names are checked before brew sees them: a name cannot start with `-`, contain spaces, quotes, `$`, `;` or `..`, so it can never be mistaken for an option. brew is started argv style, never through `eval`.

> The cheat sheet is older than Homebrew: `brew cask <cmd>` is now `brew <cmd> --cask`, and `brew switch` was removed. Use `--cask`, and `shell::brew::switch`.

## Cheat sheet → function

| brew                               | Function                                                                       |
| ---------------------------------- | ------------------------------------------------------------------------------ |
| `brew --version`, `help`, `doctor` | `version`, `help [cmd]`, `doctor` (also `config`, `prefix`, `cache`)           |
| `brew update`                      | `update`                                                                       |
| `brew outdated` / `upgrade [name]` | `outdated`, `upgrade [name...]` (`--cask`, `--greedy`)                         |
| `brew pin` / `unpin`               | `pin`, `unpin`, `pinned`                                                       |
| `brew tap` / `untap`               | `tap [user/repo [url]]`, `untap`                                               |
| `brew list [--versions]`           | `list`, `versions <name>`, `leaves`                                            |
| `brew search`, `info`              | `search`, `info`, `available` (every installable name)                         |
| `brew install` / `uninstall`       | `install`, `reinstall`, `uninstall` (`--cask`, `--zap`)                        |
| `brew cask ...`                    | the same functions with `-c \| --cask`                                         |
| `brew link` / `unlink` / `switch`  | `link`, `unlink`, `switch <formula> <version>`                                 |
| `brew cleanup [-n]`                | `cleanup` (`--preview` is `brew cleanup -n`)                                   |
| `brew deps`, `uses`, `missing`     | `deps`, `uses`, `missing`                                                      |
| also                               | `autoremove`, `services`, `bundle::dump`, `bundle::install`, `bundle::cleanup` |

`-f` always means `--force`. Homebrew's own dry run is `--preview`; our `-n` shows the command instead of running it.

## Interactive (fzf)

Tab marks several entries, Ctrl-A marks all, Enter confirms, ESC cancels. A preview pane shows `brew info`.

| Function                  | Alias               | What it does                                                          |
| ------------------------- | ------------------- | --------------------------------------------------------------------- |
| `manage`                  | `sbm`               | one menu for everything below                                         |
| `install::fzf [--cask]`   | `sbi`               | browse every formula/cask (installed ones are tagged) and install     |
| `uninstall::fzf`          | `sbrm`              | pick installed packages; asks first; skips ones another formula needs |
| `upgrade::fzf`            | `sbup`              | pick from `brew outdated`                                             |
| `info::fzf`               | `sbin`              | browse installed packages                                             |
| `pin::fzf` / `unpin::fzf` | `sbpin` / `sbunpin` | pin or unpin                                                          |
| `services::fzf`           | `sbsv`              | pick a service, then start / stop / restart ...                       |
| `untap::fzf`              | `sbut`              | remove taps (`homebrew/core` and `homebrew/cask` are never listed)    |

Append `-n` to any of them (or use the `-n` alias): you still choose, but the final command is printed instead of run. `-y` skips the confirmations.

## Finding what you no longer use

```bash
shell::brew::unused              # report only (alias sbun)
shell::brew::unused::fzf         # pick and remove (alias sbunf)
shell::brew::size                # biggest packages first (alias sbsz)
shell::brew::tidy                # preview, then autoremove + cleanup (alias sbtidy)
```

Two kinds of candidates:

- **orphan**: installed only as a dependency and needed by nothing now. This is exactly what `brew autoremove` removes.
- **stale**: a formula you installed yourself, that nothing depends on, whose files were not touched for 90 days (`--days`, or `SHELL_BREW_STALE_DAYS`) and none of whose commands appears in your shell history (`$HISTFILE`, `~/.zsh_history`, `~/.bash_history`; only read, never sent anywhere).

_Stale is a hint, not proof._ Homebrew does not record when a command last ran, and a library used by your own code has no command to find. That is why nothing is pre-selected, nothing is removed without a confirmation, and `unused::fzf` offers `autoremove` afterwards for dependencies the removal orphaned. Without a readable history the report says "shell history not checked" instead of claiming a package is unused. Casks are not analysed; use `size --cask` and `uninstall::fzf --cask`.

| Option                          | Effect                                                                               |
| ------------------------------- | ------------------------------------------------------------------------------------ |
| `-d, --days <n>`                | days without activity before a formula is stale                                      |
| `-H, --no-history`              | age only                                                                             |
| `-o, --orphans` / `-s, --stale` | only that kind                                                                       |
| `-q, --names`                   | names only, for scripts: `shell::brew::unused -q \| xargs shell::brew::uninstall -n` |

## Settings

```bash
# Never proposed for removal. The default is what this library itself needs.
SHELL_BREW_PROTECTED="fzf git curl jq node"
SHELL_BREW_STALE_DAYS=60
```

## Back up and restore

```bash
shell::brew::bundle::dump --force --describe ~/dotfiles/Brewfile    # alias sbbd
shell::brew::bundle::install ~/dotfiles/Brewfile                    # alias sbbi
shell::brew::bundle::cleanup ~/dotfiles/Brewfile                    # lists what is not in it; --force removes
```
