# zsh

`shell::zsh::*` makes zsh ready to use with this library and adds fzf pickers that feel native in zsh and work the same in bash.

- [`shell::zsh::install`](#shellzshinstall): wire the **already installed** library into `~/.zshrc`, safely and idempotently.
- [Pickers](#pickers): history, processes, ssh hosts, bookmarks, git worktrees, and a hub menu.
- [ZLE widgets](#zle-widgets-opt-in): paste a pick into the command line (zsh only, opt-in).
- [Cache](#cache), [performance](#performance), [tests](#tests).

Nothing in this module runs when the library is sourced: no command substitution, no file scan, no network. Everything happens on first use.

## shell::zsh::install

```sh
shell::zsh::install              # make zsh ready and hook the library into ~/.zshrc
shell::zsh::install -n           # dry run: print the hook block and the file operations, change nothing
shell::zsh::install --dir ~/dev/shell
shell::zsh::install --default    # also make zsh the login shell (chsh), after a confirmation
```

Alias: `szi` (`szi-n` for the dry run). Works from bash or zsh; the target is always `~/.zshrc`, and the hook is **never** sourced into the current session.

### What it does

1. **zsh exists.** `command -v zsh`; when missing, `shell::dependency::zsh::ensure` installs it through the native package manager (respects `SHELL_AUTO_INSTALL_DEPS`; never implicit `sudo` beyond the package layer). macOS ships `/bin/zsh`, so there it is a no-op.
2. **Which library?** The first candidate that holds `src/shell.sh` wins:

   | #   | Candidate                                  | Note                                                                   |
   | --- | ------------------------------------------ | ---------------------------------------------------------------------- |
   | 1   | `--dir <path>`                             | explicit; an unusable `--dir` is an **error**, never silently replaced |
   | 2   | `$SHELL_INSTALL_DIR`                       | only when changed from the default (the loader always sets it)         |
   | 3   | `$SHELL_DIR` of this session               |                                                                        |
   | 4   | the path in an existing hook of `~/.zshrc` | even a stale one; validated before it is trusted                       |
   | 5   | `$HOME/shell`                              | the `install.sh` default                                               |

   `""`, `/`, `$HOME`, relative paths and paths containing `"` `` ` `` `$` `\` are refused. With **no** valid candidate `~/.zshrc` is not touched; the `install.sh` one-liner is printed and the status is `3`. The chosen library and which candidate won are always printed. When your session runs a different library than a still-valid hook (for example a development checkout), you are asked before the hook is repointed; `--dir` decides without a question.

3. **`~/.zshrc`** is handled in every state, between the markers `install.sh` writes (`# >>> shell >>>` / `# <<< shell <<<`), so `uninstall.sh` keeps working:

   | State                                                       | Result                                                           |
   | ----------------------------------------------------------- | ---------------------------------------------------------------- |
   | file missing                                                | created (never clobbered) with the block                         |
   | no hook                                                     | block appended after one blank line                              |
   | hook of an old or moved directory                           | updated **in place**                                             |
   | legacy unmarked `source .../src/shell.sh` (or `. ...`) line | migrated into the block at the same position, duplicates dropped |
   | hook already correct                                        | no-op: the file is not touched, no backup is made                |
   | `# >>> shell >>>` block never closed                        | refused; nothing is guessed                                      |

4. **Safety.** Before any change `~/.zshrc` is copied to `~/.zshrc.shell-bak` (the uninstaller's convention). The new content is written to a temp file next to it (a copy of the original, so mode and owner survive) and moved into place. Every other line is kept as it is. A symbolic link (dotfile managers) is followed, so the link stays a link. No GNU-only `sed -i`.

The login shell is only changed with `--default`, after `shell::ask::accept`, and only if zsh is listed in `/etc/shells` (otherwise the `sudo tee -a` command is suggested, never run).

Return codes: `0` done / already done; `1` write failed or unclosed block; `2` bad option or dangerous `--dir`; `3` zsh missing or no valid installation; `9` not confirmed.

The markers and the default directory are constants in `src/constant/zsh.sh` and **must stay identical** to `install.sh` / `uninstall.sh`. The rewrite itself is one awk program, `src/data/zsh-hook.awk`.

## Pickers

All pickers use `shell::fzf::select` (same look and feel as the rest of the library), build their candidates once per call, show a row but act only on a separate value field (a display line is never evaluated), and fail fast with a clear error when there is no terminal. Every `-n | --dry-run` prints the command instead of running it.

| Function                                 | Alias | What it does                                                                                                                                                                                                                                                                                    |
| ---------------------------------------- | ----- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `shell::zsh::history::search::fzf`       | `szh` | Deduplicated, newest-first history of the running shell (zsh `fc`, bash `history`) or of a file (`--file`). Prints the command; `--push` (zsh) puts it in the next prompt. Never executes it. Multi-line entries are shown on one row.                                                          |
| `shell::zsh::process::kill::fzf`         | `szk` | Multi-select process picker (Tab marks, Ctrl-R refreshes on fzf 0.35+). SIGTERM first (`--signal` to change); after `SHELL_ZSH_KILL_GRACE` seconds the survivors are listed and SIGKILL is sent only if you agree. PID 1 and your shell are never signalled. Own processes only unless `--all`. |
| `shell::zsh::ssh::host::pick::fzf`       | `szs` | Host aliases of `~/.ssh/config` (via `shell::ssh::config::list`) with the alias's `Host` block as preview. Prints the alias; `--connect` hands it to `shell::ssh::connect`.                                                                                                                     |
| `shell::zsh::bookmark::goto::fzf`        | `szg` | Bookmarks with a directory preview (`eza` if present, else `ls`). The move is `shell::goto::run`, in the current shell; `--print` prints the directory.                                                                                                                                         |
| `shell::zsh::git::worktree::switch::fzf` | `szw` | Every `git worktree` of the repository (including `shell::git::isolate::*` ones), branch and flags shown, last commits as preview; changes directory in the current shell; `--print` prints the path.                                                                                           |
| `shell::zsh::manage::fzf`                | `szm` | Hub menu over all of the above plus the hook installer and the cache. `shell::fzf::loop --back`, cursor memory, ESC or `← Back` leaves.                                                                                                                                                         |

Examples:

```sh
cmd="$(shell::zsh::history::search::fzf -q 'docker ')"   # a command, to inspect or run yourself
shell::zsh::history::search::fzf --push                  # zsh: lands in the next prompt
shell::zsh::process::kill::fzf -n --all                  # see what would be killed
ssh "$(shell::zsh::ssh::host::pick::fzf)"
cd "$(shell::zsh::git::worktree::switch::fzf --print)"
```

Previews are single cheap processes, `{}`-based and quoted by fzf, with an explicit `--preview-window`; there is no network and no shell function call inside a preview (zsh does not export functions), so previews use `awk`, `ls`/`eza` and `git` directly.

## ZLE widgets (opt-in)

Plain `::fzf` functions work in bash. In an **interactive zsh** you can also paste a pick straight into the command line:

| Widget           | Default key | Effect                                                              |
| ---------------- | ----------- | ------------------------------------------------------------------- |
| `shell-history`  | `^Xh`       | replaces the line with a history entry (starts with what you typed) |
| `shell-ssh-host` | `^Xj`       | inserts a host alias at the cursor                                  |
| `shell-worktree` | `^Xw`       | inserts the quoted path of a worktree                               |
| `shell-bookmark` | `^Xb`       | inserts the quoted path of a bookmark                               |

Nothing is registered unless you opt in, before sourcing the library (or call `shell::zsh::widget::enable` yourself; `-n` prints what it would do):

```sh
export SHELL_ZSH_WIDGETS=1
source "$HOME/shell/src/shell.sh"
```

Keys are bound **only when they are still unbound**; a key that is taken (fzf's `^R`, yours) is left alone and reported. Change them with `SHELL_ZSH_KEY_HISTORY`, `SHELL_ZSH_KEY_SSH`, `SHELL_ZSH_KEY_WORKTREE`, `SHELL_ZSH_KEY_BOOKMARK`.

## Cache

Only the parse of a history **file** is cached (reading the running shell's memory is already a few ms). Entries live in `$SHELL_ZSH_CACHE_DIR` (default `~/.shell-config/cache/zsh`, mode 700, files 600) and are **stale-while-revalidate**: a fresh entry is served as it is, an entry older than `SHELL_ZSH_CACHE_TTL` (300 s) is served at once and rebuilt in the background, a missing one is built first. Writes are a temp file and a `mv`. `--refresh` rebuilds synchronously; `shell::zsh::cache::clear` (`szc`, `-n` for a dry run) deletes the cache files and nothing else.

## Settings

All in `src/constant/zsh.sh`, overridable from the environment before sourcing.

| Variable                       | Default                             | Meaning                                                  |
| ------------------------------ | ----------------------------------- | -------------------------------------------------------- |
| `SHELL_ZSH_WIDGETS`            | `0`                                 | `1` registers the ZLE widgets in an interactive zsh      |
| `SHELL_ZSH_KEY_*`              | `^Xh` `^Xj` `^Xw` `^Xb`             | widget keys (bound only when free)                       |
| `SHELL_ZSH_HISTORY_LIMIT`      | `50000`                             | most history entries offered                             |
| `SHELL_ZSH_KILL_GRACE`         | `3`                                 | seconds before SIGKILL is offered                        |
| `SHELL_ZSH_CACHE_DIR` / `_TTL` | `~/.shell-config/cache/zsh` / `300` | cache location / freshness                               |
| `SHELL_ZSH_NEWLINE_MARK`       | `⏎`                                 | stands for a line break inside a flattened history entry |

## Performance

Measured on macOS (Apple silicon), zsh 5.9, fzf 0.64:

| What                                                                         | Result                                                                            |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| `source src/shell.sh` with vs without the zsh module (20 runs, three rounds) | 75.3/74.3/72.3 ms vs 76.0/75.7/71.8 ms: within noise, nothing runs at source time |
| history candidates, 10k-entry file, cold                                     | 50 ms                                                                             |
| history candidates, 50k-entry file, cold / cache hit                         | 245 ms / 12 ms                                                                    |
| history candidates, running zsh (`fc -rl 1 \| awk`)                          | 4 ms for 30 entries                                                               |
| process candidates, real `ps -A` (850 rows)                                  | 46-52 ms                                                                          |
| bookmark candidates, 10k bookmarks                                           | 57 ms                                                                             |
| worktree candidates                                                          | 12-18 ms                                                                          |

fzf's own filtering dominates after that. Candidates are generated once per call with one awk pass (no per-line subshell); the process picker's Ctrl-R reload is a single `ps | awk`; no shell function runs per keystroke.

## Tests

`test/test_zsh_install.sh` (the hook in every state, the resolution order, dry run, symlink, mode, uninstaller compatibility, `--default`) and `test/test_zsh_fzf.sh` (parsing, picks, cancel, dry runs, real signals, real worktrees, the cache, the widgets in a real interactive zsh) run under bash (including macOS bash 3.2) and zsh in an isolated `HOME`; fzf, `ps`, `chsh` and the package layer are stubs.
