# lib/brew_fzf.sh

Interactive Homebrew management with fzf, and tools to find unused packages.

## Overview

Built on the plain commands of lib/brew.sh. Every `*::fzf` function lists
something you can act on, lets you pick one or many entries with a live
`brew info` preview (Tab marks, Ctrl-A marks all, Enter confirms, ESC
cancels), asks before anything destructive, and then calls the matching
`shell::brew::*` command.

Finding what you no longer need (shell::brew::unused, shell::brew::unused::fzf)
looks for two kinds of packages:

- **orphan**: installed only as a dependency and now needed by nothing
  (exactly what `brew autoremove` would remove);
- **stale**: a formula you installed yourself, that no other formula needs,
  whose files have not been touched for SHELL_BREW_STALE_DAYS days and none of
  whose commands appears in your shell history.

Stale is a _hint_, not proof: Homebrew does not record when a command was
last run. That is why nothing is removed without you marking it and
confirming it, and why the packages in SHELL_BREW_PROTECTED (fzf, git, curl,
jq: what this library needs) are never proposed.

`-n | --dry-run` still lets you browse and choose, but prints the final
brew command instead of running it. `-y | --yes` skips the confirmations.

## Index

- [shell::brew::install::fzf](#shellbrewinstallfzf)
- [shell::brew::uninstall::fzf](#shellbrewuninstallfzf)
- [shell::brew::upgrade::fzf](#shellbrewupgradefzf)
- [shell::brew::info::fzf](#shellbrewinfofzf)
- [shell::brew::pin::fzf](#shellbrewpinfzf)
- [shell::brew::unpin::fzf](#shellbrewunpinfzf)
- [shell::brew::untap::fzf](#shellbrewuntapfzf)
- [shell::brew::services::fzf](#shellbrewservicesfzf)
- [shell::brew::size](#shellbrewsize)
- [shell::brew::unused](#shellbrewunused)
- [shell::brew::unused::fzf](#shellbrewunusedfzf)
- [shell::brew::tidy](#shellbrewtidy)
- [shell::brew::manage](#shellbrewmanage)

### shell::brew::install::fzf

Browse everything Homebrew can install and install what you pick.
Lists every formula (or cask) with a live `brew info` preview; packages that
are already installed are tagged. Tab marks several, Ctrl-A marks all.

#### Example

```bash
shell::brew::install::fzf
shell::brew::install::fzf --cask
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the install command instead of running it.

- **-c** | **--cask**

  Browse casks (GUI apps) instead of formulae.

#### Exit codes

- **0**: Done, or nothing chosen.
- **3**: Homebrew or fzf is not installed.

#### See also

- [shell::brew::install](#shellbrewinstall)

### shell::brew::uninstall::fzf

Pick installed packages and uninstall them, after a safety check.
Formulae that another installed formula needs are **skipped with an
explanation** instead of breaking that formula (Homebrew would refuse
them too); packages you mark together are checked against each other.
You are asked to confirm before anything is removed.

#### Example

```bash
shell::brew::uninstall::fzf
shell::brew::uninstall::fzf --zap
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the uninstall command instead of running it.

- **-c** | **--cask**

  Work on casks.

- **-z** | **--zap**

  Also delete the casks' data and settings (implies --cask).

- **-y** | **--yes**

  Do not ask for confirmation.

#### Exit codes

- **0**: Done, nothing chosen, or the user declined.
- **3**: Homebrew or fzf is not installed.

#### See also

- [shell::brew::uninstall](#shellbrewuninstall)
- [shell::brew::unused::fzf](#shellbrewunusedfzf)

### shell::brew::upgrade::fzf

Pick outdated packages and upgrade them.
Lists what `brew outdated` reports, with the installed and the new version.
Tab marks several, Ctrl-A marks all. Pinned packages never show up.

#### Example

```bash
shell::brew::upgrade::fzf
shell::brew::upgrade::fzf --cask --greedy
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the upgrade command instead of running it.

- **-c** | **--cask**

  Casks only.

- **--formula**

  Formulae only.

- **-g** | **--greedy**

  Also list casks that update themselves.

#### Exit codes

- **0**: Done, everything is up to date, or nothing chosen.
- **3**: Homebrew or fzf is not installed.

#### See also

- [shell::brew::upgrade](#shellbrewupgrade)
- [shell::brew::outdated](#shellbrewoutdated)

### shell::brew::info::fzf

Browse installed packages and read their `brew info`.
The list stays open after each look; ESC leaves. The preview pane shows the
same information live as you move.

#### Example

```bash
shell::brew::info::fzf
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-c** | **--cask**

  Browse casks.

#### Exit codes

- **0**: Done.
- **3**: Homebrew or fzf is not installed.

#### See also

- [shell::brew::info](#shellbrewinfo)

### shell::brew::pin::fzf

Pick installed packages and pin them, so `brew upgrade` skips them.

#### Example

```bash
shell::brew::pin::fzf
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the pin command instead of running it.

- **-c** | **--cask**

  Work on casks.

#### Exit codes

- **0**: Done, or nothing chosen.
- **3**: Homebrew or fzf is not installed.

#### See also

- [shell::brew::pin](#shellbrewpin)
- [shell::brew::unpin::fzf](#shellbrewunpinfzf)

### shell::brew::unpin::fzf

Pick pinned packages and unpin them, so `brew upgrade` upgrades them again.

#### Example

```bash
shell::brew::unpin::fzf
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the unpin command instead of running it.

- **-c** | **--cask**

  Work on casks.

#### Exit codes

- **0**: Done, nothing is pinned, or nothing chosen.
- **3**: Homebrew or fzf is not installed.

#### See also

- [shell::brew::unpin](#shellbrewunpin)
- [shell::brew::pin::fzf](#shellbrewpinfzf)

### shell::brew::untap::fzf

Pick taps and remove them.
`homebrew/core` and `homebrew/cask` are not listed: they are Homebrew's own
catalogue and removing them breaks `brew install`.

#### Example

```bash
shell::brew::untap::fzf
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the untap command instead of running it.

- **-f** | **--force**

  Untap even if packages from the tap are installed.

- **-y** | **--yes**

  Do not ask for confirmation.

#### Exit codes

- **0**: Done, no removable taps, or nothing chosen.
- **3**: Homebrew or fzf is not installed.

#### See also

- [shell::brew::untap](#shellbrewuntap)

### shell::brew::services::fzf

Pick a background service, then pick what to do with it.
Shows `brew services list` (name, status, user), then offers start, stop,
restart, run (this session only), kill and info. The list is shown again
after each action so you see the new status; ESC or Back leaves.

#### Example

```bash
shell::brew::services::fzf
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the services command instead of running it.

#### Exit codes

- **0**: Done.
- **3**: Homebrew or fzf is not installed.

#### See also

- [shell::brew::services](#shellbrewservices)

### shell::brew::size

Show which installed packages take the most disk space.
Measures every directory of the Cellar (or the Caskroom with `--cask`),
biggest first.

#### Example

```bash
shell::brew::size
shell::brew::size --cask 10
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-c** | **--cask**

  Measure casks instead of formulae.

#### Arguments

- **$1** (integer): How many packages to show (default: 20).

#### Exit codes

- **0**: Success.
- **2**: The count is not a positive integer.
- **3**: Homebrew is not installed.

#### Output on stdout

- One line per package: size, name.

#### See also

- [shell::brew::unused::fzf](#shellbrewunusedfzf)

### shell::brew::unused

List the installed packages that look unused: orphans and stale formulae.
Read-only: it only reports. To remove what it finds, use
shell::brew::unused::fzf.

- `orphan`: installed as a dependency and needed by nothing now.
- `stale`: a formula you installed, that nothing depends on, whose files were
  untouched for `--days` days and none of whose commands is in your shell
  history. A hint, not proof (see the file header).

#### Example

```bash
shell::brew::unused
shell::brew::unused --days 30 --orphans
shell::brew::unused --names | xargs shell::brew::uninstall -n
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-d** | **--days**

  Days without activity before a formula is stale (default: SHELL_BREW_STALE_DAYS, 90).

- **-H** | **--no-history**

  Ignore the shell history (age only).

- **-o** | **--orphans**

  Only orphans.

- **-s** | **--stale**

  Only stale formulae.

- **-q** | **--names**

  Print only the names, one per line (for scripts).

#### Exit codes

- **0**: Success, even when nothing was found.
- **2**: Invalid option or day count.
- **3**: Homebrew is not installed.

#### Output on stdout

- A table: package, reason, size, why. With `--names`, just the names.

#### See also

- [shell::brew::unused::fzf](#shellbrewunusedfzf)
- [shell::brew::size](#shellbrewsize)

### shell::brew::unused::fzf

Find unused packages, pick the ones to remove, and remove them.
Runs shell::brew::unused::scan, lists the candidates (package, reason, size,
why) with a preview of `brew info` and of what depends on each, and lets you
mark the ones to uninstall (Tab marks, Ctrl-A marks all). After a
confirmation it uninstalls them, then offers `brew autoremove` for the
dependencies that became orphans because of it.

Nothing is pre-selected and nothing is removed without your confirmation.
Packages in SHELL_BREW_PROTECTED are never listed.

#### Example

```bash
shell::brew::unused::fzf
shell::brew::unused::fzf --orphans
shell::brew::unused::fzf -n --days 30
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the commands instead of running them.

- **-d** | **--days**

  Days without activity before a formula is stale (default 90).

- **-H** | **--no-history**

  Ignore the shell history (age only).

- **-o** | **--orphans**

  Only orphans.

- **-s** | **--stale**

  Only stale formulae.

- **-y** | **--yes**

  Do not ask for confirmation (also runs autoremove afterwards).

#### Exit codes

- **0**: Done, nothing found, nothing chosen, or the user declined.
- **2**: Invalid option or day count.
- **3**: Homebrew or fzf is not installed.

#### See also

- [shell::brew::unused](#shellbrewunused)
- [shell::brew::autoremove](#shellbrewautoremove)

### shell::brew::tidy

One-stop clean-up: autoremove, then cleanup, each previewed first.
For each step it shows what brew _would_ do (`--dry-run`), asks, and only then
does it: 1. uninstall dependencies nothing needs (`brew autoremove`); 2. delete old versions and stale downloads (`brew cleanup`).

#### Example

```bash
shell::brew::tidy
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Show the previews, then print the real commands instead of running them.

- **-y** | **--yes**

  Do not ask for confirmation.

#### Exit codes

- **0**: Done, or the user declined a step.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::autoremove](#shellbrewautoremove)
- [shell::brew::cleanup](#shellbrewcleanup)

### shell::brew::manage

The Homebrew control panel: one fzf menu for everything above.
Install, uninstall, upgrade, browse, find unused packages, tidy up, see disk
usage, pin, services, taps, update and doctor. Each entry opens its own
picker; "← Back" in the picker returns here, and ESC or "← Back" in the menu
leaves.

#### Example

```bash
shell::brew::manage
shell::brew::manage -n
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Pass `--dry-run` to every entry: choices are made but nothing is changed.

#### Exit codes

- **0**: The user left the menu.
- **3**: Homebrew or fzf is not installed.

#### See also

- [shell::brew::install::fzf](#shellbrewinstallfzf)
- [shell::brew::unused::fzf](#shellbrewunusedfzf)
