# lib/brew.sh

Homebrew package commands: install, upgrade, pin, taps, services, bundle, cleanup ...

## Overview

One documented function per `brew` command, so everything in the Homebrew
cheat sheet (https://quickref.me/homebrew) is a `shell::brew::*` call with
the same flags, a `-n | --dry-run` switch and argument validation.

These functions manage **packages**. Installing or removing Homebrew itself
is `shell::homebrew::install` / `shell::homebrew::uninstall`
(src/dependency/homebrew.sh). The interactive (fzf) layer and the tools that
find unused packages live in lib/brew_fzf.sh.

Conventions shared by every function in this file:

- `-n | --dry-run` prints the `brew` command (and copies it to the
  clipboard) instead of running it. It never needs Homebrew to be installed.
- `-c | --cask` works on casks (GUI apps); `--formula` works on formulae.
  Without either, Homebrew picks by itself.
- `-f` always means `--force`; Homebrew's own dry-run is `-p | --preview`
  (our `-n` shows the command, `--preview` asks brew what it _would_ do).
- Package names are validated before brew sees them: a name can never start
  with `-`, so it cannot be mistaken for an option, and it cannot contain
  spaces, quotes, `$`, `;`, `..` or other shell metacharacters.
- brew is started argv style (no `eval`), so a value is never re-parsed.

What changed since the cheat sheet was written: `brew cask <cmd>` is now
`brew <cmd> --cask`, and `brew switch` was removed from Homebrew;
shell::brew::switch reproduces it with `unlink` + `link --overwrite`.

## Index

- [shell::brew::run](#shellbrewrun)
- [shell::brew::version](#shellbrewversion)
- [shell::brew::help](#shellbrewhelp)
- [shell::brew::doctor](#shellbrewdoctor)
- [shell::brew::config](#shellbrewconfig)
- [shell::brew::prefix](#shellbrewprefix)
- [shell::brew::cache](#shellbrewcache)
- [shell::brew::update](#shellbrewupdate)
- [shell::brew::outdated](#shellbrewoutdated)
- [shell::brew::upgrade](#shellbrewupgrade)
- [shell::brew::pin](#shellbrewpin)
- [shell::brew::unpin](#shellbrewunpin)
- [shell::brew::pinned](#shellbrewpinned)
- [shell::brew::tap](#shellbrewtap)
- [shell::brew::untap](#shellbrewuntap)
- [shell::brew::available](#shellbrewavailable)
- [shell::brew::search](#shellbrewsearch)
- [shell::brew::info](#shellbrewinfo)
- [shell::brew::list](#shellbrewlist)
- [shell::brew::versions](#shellbrewversions)
- [shell::brew::leaves](#shellbrewleaves)
- [shell::brew::deps](#shellbrewdeps)
- [shell::brew::uses](#shellbrewuses)
- [shell::brew::missing](#shellbrewmissing)
- [shell::brew::install](#shellbrewinstall)
- [shell::brew::reinstall](#shellbrewreinstall)
- [shell::brew::uninstall](#shellbrewuninstall)
- [shell::brew::link](#shellbrewlink)
- [shell::brew::unlink](#shellbrewunlink)
- [shell::brew::switch](#shellbrewswitch)
- [shell::brew::cleanup](#shellbrewcleanup)
- [shell::brew::autoremove](#shellbrewautoremove)
- [shell::brew::services](#shellbrewservices)
- [shell::brew::bundle::dump](#shellbrewbundledump)
- [shell::brew::bundle::install](#shellbrewbundleinstall)
- [shell::brew::bundle::cleanup](#shellbrewbundlecleanup)

### shell::brew::run

Run `brew <args>` (argv style) and echo the command first.
The single place that starts the brew executable for every mutating or
user-visible command. With `-n` it only prints `brew <args>` and copies it
to the clipboard; in that case Homebrew need not be installed.

#### Example

```bash
shell::brew::run install git
shell::brew::run -n upgrade --cask
```

#### Options

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **...** (string): The brew sub-command and its arguments, e.g. `install --cask firefox`.

#### Exit codes

- **0**: brew succeeded (or the dry-run printed).
- **2**: No sub-command was given.
- **3**: Homebrew is not installed.
- N Exit status of brew.

#### See also

- [shell::homebrew::install](#shellhomebrewinstall)

### shell::brew::version

Show the installed Homebrew version (`brew --version`).

#### Example

```bash
shell::brew::version
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Exit codes

- **0**: Success.
- **3**: Homebrew is not installed.

### shell::brew::help

Print help for Homebrew or for one brew sub-command (`brew help [cmd]`).

#### Example

```bash
shell::brew::help
shell::brew::help install
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): Optional sub-command, e.g. `install` (lower-case letters, digits, `-`).

#### Exit codes

- **0**: Success.
- **2**: The sub-command name is invalid.
- **3**: Homebrew is not installed.

### shell::brew::doctor

Check the system for potential problems (`brew doctor`).

#### Example

```bash
shell::brew::doctor
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Exit codes

- **0**: Success (brew reports its own warnings and exits non-zero when it finds any).
- **3**: Homebrew is not installed.

### shell::brew::config

Show the Homebrew configuration (`brew config`): prefix, versions, taps ...

#### Example

```bash
shell::brew::config
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Exit codes

- **0**: Success.
- **3**: Homebrew is not installed.

### shell::brew::prefix

Print the Homebrew prefix, or the prefix of one package (`brew --prefix [name]`).

#### Example

```bash
shell::brew::prefix
shell::brew::prefix openssl@3
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): Optional package name.

#### Exit codes

- **0**: Success.
- **2**: The package name is invalid.
- **3**: Homebrew is not installed.

#### Output on stdout

- The absolute path.

### shell::brew::cache

Print the download cache directory (`brew --cache`).

#### Example

```bash
du -sh "$(shell::brew::cache)"
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Exit codes

- **0**: Success.
- **3**: Homebrew is not installed.

#### Output on stdout

- The absolute path.

### shell::brew::update

Fetch the latest Homebrew and formula definitions (`brew update`).

#### Example

```bash
shell::brew::update
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-f** | **--force**

  Always do a slower, full update check.

#### Exit codes

- **0**: Success.
- **3**: Homebrew is not installed.

### shell::brew::outdated

List packages that have a newer version (`brew outdated`).

#### Example

```bash
shell::brew::outdated
shell::brew::outdated --cask --greedy
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-c** | **--cask**

  Only casks.

- **--formula**

  Only formulae.

- **-g** | **--greedy**

  Also include casks that update themselves (`auto_updates`) or are `latest`.

- **-q** | **--quiet**

  Names only.

- **-v** | **--verbose**

  Include the installed and the new version.

#### Arguments

- **...** (string): Optional package names to restrict the check to.

#### Exit codes

- **0**: Success.
- **2**: Invalid option or package name.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::upgrade](#shellbrewupgrade)

### shell::brew::upgrade

Upgrade outdated packages, or only the named ones (`brew upgrade`).

#### Example

```bash
shell::brew::upgrade
shell::brew::upgrade git jq
shell::brew::upgrade --cask --greedy
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-c** | **--cask**

  Only casks.

- **--formula**

  Only formulae.

- **-g** | **--greedy**

  Also upgrade casks that update themselves.

- **-f** | **--force**

  Install without checking whether the package is already up to date.

#### Arguments

- **...** (string): Optional package names. Without any, everything outdated and unpinned is upgraded.

#### Exit codes

- **0**: Success.
- **2**: Invalid option or package name.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::upgrade::fzf](#shellbrewupgradefzf)

### shell::brew::pin

Prevent packages from being upgraded (`brew pin`).

#### Example

```bash
shell::brew::pin node@20
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-c** | **--cask**

  Treat the names as casks.

- **--formula**

  Treat the names as formulae.

#### Arguments

- **...** (string): One or more installed package names.

#### Exit codes

- **0**: Success.
- **2**: No name, or an invalid one.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::unpin](#shellbrewunpin)

### shell::brew::unpin

Allow pinned packages to be upgraded again (`brew unpin`).

#### Example

```bash
shell::brew::unpin node@20
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-c** | **--cask**

  Treat the names as casks.

- **--formula**

  Treat the names as formulae.

#### Arguments

- **...** (string): One or more pinned package names.

#### Exit codes

- **0**: Success.
- **2**: No name, or an invalid one.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::pin](#shellbrewpin)

### shell::brew::pinned

List the pinned packages (`brew list --pinned`).

#### Example

```bash
shell::brew::pinned
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Exit codes

- **0**: Success.
- **3**: Homebrew is not installed.

### shell::brew::tap

List the taps, or add one (`brew tap [user/repo [url]]`).
With no argument it lists the current taps. With `user/repo` it taps
`https://github.com/user/homebrew-repo`; with a URL as well, that URL.

#### Example

```bash
shell::brew::tap
shell::brew::tap homebrew/cask-versions
shell::brew::tap acme/tools https://git.example.com/acme/homebrew-tools.git
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): Optional tap, `user/repo`.
- **$2** (string): Optional URL of the tap repository.

#### Exit codes

- **0**: Success.
- **2**: The tap or the URL is invalid.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::untap](#shellbrewuntap)

### shell::brew::untap

Remove one or more taps (`brew untap`).

#### Example

```bash
shell::brew::untap acme/tools
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-f** | **--force**

  Untap even if formulae or casks from it are installed.

#### Arguments

- **...** (string): One or more taps, `user/repo`.

#### Exit codes

- **0**: Success.
- **2**: No tap, or an invalid one.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::tap](#shellbrewtap)
- [shell::brew::untap::fzf](#shellbrewuntapfzf)

### shell::brew::available

List the packages that can be installed (`brew formulae` / `brew casks`).
Works from the local index, so it is fast and offline; run
shell::brew::update first to refresh it.

#### Example

```bash
shell::brew::available | grep -c .
shell::brew::available --cask
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-c** | **--cask**

  List casks instead of formulae.

#### Exit codes

- **0**: Success.
- **3**: Homebrew is not installed.

#### Output on stdout

- One package name per line.

#### See also

- [shell::brew::install::fzf](#shellbrewinstallfzf)

### shell::brew::search

Search formulae and casks by name, or by description (`brew search`).

#### Example

```bash
shell::brew::search python
shell::brew::search --desc --cask "video player"
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-c** | **--cask**

  Search casks only.

- **--formula**

  Search formulae only.

- **-d** | **--desc**

  Search the descriptions as well as the names.

#### Arguments

- **$1** (string): The text to look for; `/regex/` is supported by brew.

#### Exit codes

- **0**: Success.
- **2**: No text given.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::available](#shellbrewavailable)

### shell::brew::info

Show information about packages (`brew info`).

#### Example

```bash
shell::brew::info git
shell::brew::info --cask firefox
shell::brew::info --json --installed | jq '.formulae | length'
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-c** | **--cask**

  Treat the names as casks.

- **--formula**

  Treat the names as formulae.

- **-j** | **--json**

  Print JSON (`--json=v2`) instead of text.

- **-i** | **--installed**

  Describe every installed package (with --json: as JSON).

#### Arguments

- **...** (string): Package names.

#### Exit codes

- **0**: Success.
- **2**: An invalid name.
- **3**: Homebrew is not installed.

### shell::brew::list

List installed packages (`brew list`).

#### Example

```bash
shell::brew::list
shell::brew::list --cask --versions
shell::brew::list --versions --multiple
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-c** | **--cask**

  Only casks.

- **--formula**

  Only formulae.

- **-v** | **--versions**

  Show the installed versions.

- **-r** | **--requested**

  Only packages you installed yourself (not dependencies).

- **--multiple**

  With --versions, only packages with more than one version installed.

- **--pinned**

  Only pinned packages.

- **-1**

  One name per line.

#### Arguments

- **...** (string): Optional package names (list their files, or with --versions their versions).

#### Exit codes

- **0**: Success.
- **2**: Invalid option or name.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::versions](#shellbrewversions)

### shell::brew::versions

Show the installed versions of packages (`brew list --versions <name>`).

#### Example

```bash
shell::brew::versions git
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-c** | **--cask**

  Treat the names as casks.

#### Arguments

- **...** (string): One or more package names.

#### Exit codes

- **0**: Success.
- **2**: No name, or an invalid one.
- **3**: Homebrew is not installed.

### shell::brew::leaves

List installed formulae that nothing else depends on (`brew leaves`).
These are the packages you would remove first: they are what you asked for,
or leftovers of something you removed.

#### Example

```bash
shell::brew::leaves --requested
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-r** | **--requested**

  Only leaves you installed yourself.

- **-d** | **--dependency**

  Only leaves that were installed as a dependency.

#### Exit codes

- **0**: Success.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::unused](#shellbrewunused)

### shell::brew::deps

Show which formulae a package depends on (`brew deps`).

#### Example

```bash
shell::brew::deps --tree git
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-t** | **--tree**

  Print a dependency tree.

- **-i** | **--installed**

  Restrict to installed packages (works without a name).

- **-1** | **--direct**

  Only direct dependencies.

#### Arguments

- **...** (string): Package names.

#### Exit codes

- **0**: Success.
- **2**: Invalid option or name.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::uses](#shellbrewuses)

### shell::brew::uses

Show which formulae depend on a package (`brew uses`).
Always restricted to installed formulae unless `--all` is given, because
the unrestricted query has to read every formula and is very slow.

#### Example

```bash
shell::brew::uses openssl@3
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-a** | **--all**

  Look at every formula, not only the installed ones (slow).

- **-r** | **--recursive**

  Include indirect dependents.

#### Arguments

- **...** (string): One or more package names.

#### Exit codes

- **0**: Success.
- **2**: No name, or an invalid one.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::deps](#shellbrewdeps)

### shell::brew::missing

Check packages for missing dependencies (`brew missing`).

#### Example

```bash
shell::brew::missing
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **...** (string): Optional package names (default: all installed).

#### Exit codes

- **0**: Success.
- **2**: An invalid name.
- **3**: Homebrew is not installed.

### shell::brew::install

Install formulae or casks (`brew install`).

#### Example

```bash
shell::brew::install git jq
shell::brew::install --cask firefox
shell::brew::install -n node@20
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-c** | **--cask**

  Install casks (GUI apps) instead of formulae.

- **--formula**

  Treat the names as formulae.

- **-f** | **--force**

  Install even if already installed (overwrites conflicting files).

#### Arguments

- **...** (string): One or more package names.

#### Exit codes

- **0**: Success.
- **2**: No name, or an invalid one.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::install::fzf](#shellbrewinstallfzf)

### shell::brew::reinstall

Reinstall formulae or casks (`brew reinstall`).

#### Example

```bash
shell::brew::reinstall --cask firefox
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-c** | **--cask**

  Reinstall casks.

- **--formula**

  Treat the names as formulae.

- **-f** | **--force**

  Reinstall even if it is up to date.

#### Arguments

- **...** (string): One or more installed package names.

#### Exit codes

- **0**: Success.
- **2**: No name, or an invalid one.
- **3**: Homebrew is not installed.

### shell::brew::uninstall

Uninstall formulae or casks (`brew uninstall`).
`--zap` also removes the files a cask leaves in your home directory
(preferences, caches, support files); it only exists for casks, so it
implies `--cask`.

#### Example

```bash
shell::brew::uninstall wget
shell::brew::uninstall --zap firefox
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-c** | **--cask**

  Uninstall casks.

- **--formula**

  Treat the names as formulae.

- **-f** | **--force**

  Delete all installed versions, and uninstall even a cask whose files are gone.

- **-z** | **--zap**

  Also delete the cask's data and settings (implies --cask).

- **--ignore-dependencies**

  Uninstall even if other formulae need it. This can break them.

#### Arguments

- **...** (string): One or more installed package names.

#### Exit codes

- **0**: Success.
- **2**: No name, or an invalid one.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::uninstall::fzf](#shellbrewuninstallfzf)

### shell::brew::link

Symlink an installed formula into the Homebrew prefix (`brew link`).

#### Example

```bash
shell::brew::link git
shell::brew::link --overwrite --force node@20
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-f** | **--force**

  Allow keg-only formulae to be linked.

- **-o** | **--overwrite**

  Delete files that already exist in the prefix.

- **-p** | **--preview**

  Ask brew to show what it would do, without doing it.

#### Arguments

- **...** (string): One or more installed formula names.

#### Exit codes

- **0**: Success.
- **2**: No name, or an invalid one.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::unlink](#shellbrewunlink)
- [shell::brew::switch](#shellbrewswitch)

### shell::brew::unlink

Remove the symlinks of installed formulae from the prefix (`brew unlink`).
The formula stays installed; it is just no longer on your PATH.

#### Example

```bash
shell::brew::unlink git
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-p** | **--preview**

  Ask brew to show what it would do, without doing it.

#### Arguments

- **...** (string): One or more installed formula names.

#### Exit codes

- **0**: Success.
- **2**: No name, or an invalid one.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::link](#shellbrewlink)

### shell::brew::switch

Make another installed version of a formula the active one.
Replaces `brew switch`, which Homebrew removed. Versions of a formula are
separate formulae (`node@20`, `python@3.12`), so this unlinks `<formula>`
and links `<formula>@<version>` with `--overwrite --force`. The target must
already be installed (shell::brew::install node@20).

#### Example

```bash
shell::brew::switch node 20
shell::brew::switch -n python 3.12
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the commands instead of running them.

#### Arguments

- **$1** (string): Formula, e.g. `node`.
- **$2** (string): Version, e.g. `20`.

#### Exit codes

- **0**: The version is now linked.
- **2**: Missing or invalid formula / version.
- **3**: Homebrew is not installed, or `<formula>@<version>` is not installed.
- N Exit status of the failing brew step.

#### See also

- [shell::brew::link](#shellbrewlink)

### shell::brew::cleanup

Remove old versions and stale downloads (`brew cleanup`).
Use `--preview` first: it lists what would be removed and removes nothing
(this is `brew cleanup -n`; our own `-n` prints the command).

#### Example

```bash
shell::brew::cleanup --preview
shell::brew::cleanup --prune 30
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-p** | **--preview**

  Ask brew to list what it would remove, without removing it.

- **-s** | **--scrub**

  Also remove downloads of the latest versions (empties the cache).

- **--prune \<days\>**

  Remove cache files older than this many days (`all` = everything).

#### Arguments

- **...** (string): Optional package names (default: everything).

#### Exit codes

- **0**: Success.
- **2**: Invalid option, value or name.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::autoremove](#shellbrewautoremove)

### shell::brew::autoremove

Uninstall formulae that were only installed as a dependency and are
no longer needed (`brew autoremove`).
Run it with `--preview` first to see the list.

#### Example

```bash
shell::brew::autoremove --preview
shell::brew::autoremove
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-p** | **--preview**

  Ask brew to list what it would uninstall, without doing it.

#### Exit codes

- **0**: Success.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::unused::fzf](#shellbrewunusedfzf)

### shell::brew::services

Manage background services of installed formulae (`brew services`).
Actions: `list`, `info`, `run` (this session only), `start` (and at login),
`stop`, `restart`, `kill` and `cleanup` (remove unused service files).

#### Example

```bash
shell::brew::services list
shell::brew::services start postgresql@16
shell::brew::services restart --all
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-a** | **--all**

  Apply the action to every service.

#### Arguments

- **$1** (string): The action.
- **...** (string): Service (formula) names, for the actions that need them.

#### Exit codes

- **0**: Success.
- **2**: Unknown action, or a missing / invalid name.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::services::fzf](#shellbrewservicesfzf)

### shell::brew::bundle::dump

Write every installed tap, formula, cask (and more) to a Brewfile
(`brew bundle dump`). Keep the file in your dotfiles to rebuild a machine.

#### Example

```bash
shell::brew::bundle::dump --force --describe ~/dotfiles/Brewfile
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-f** | **--force**

  Overwrite an existing Brewfile.

- **-d** | **--describe**

  Add a comment with each package's description.

#### Arguments

- **$1** (string): Optional path of the Brewfile (default: `./Brewfile`).

#### Exit codes

- **0**: Success.
- **2**: Invalid option or path.
- **3**: Homebrew is not installed.

#### See also

- [shell::brew::bundle::install](#shellbrewbundleinstall)

### shell::brew::bundle::install

Install everything listed in a Brewfile (`brew bundle install`).

#### Example

```bash
shell::brew::bundle::install ~/dotfiles/Brewfile
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): Optional path of the Brewfile (default: `./Brewfile`).

#### Exit codes

- **0**: Success.
- **2**: Invalid option or path.
- **3**: Homebrew is not installed, or the Brewfile does not exist.

#### See also

- [shell::brew::bundle::dump](#shellbrewbundledump)

### shell::brew::bundle::cleanup

Find, or remove, what is installed but not listed in a Brewfile
(`brew bundle cleanup`). Without `--force` brew only lists what it would
remove; with it, it uninstalls.

#### Example

```bash
shell::brew::bundle::cleanup ~/dotfiles/Brewfile
shell::brew::bundle::cleanup --force ~/dotfiles/Brewfile
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-f** | **--force**

  Really uninstall what is not in the Brewfile.

#### Arguments

- **$1** (string): Optional path of the Brewfile (default: `./Brewfile`).

#### Exit codes

- **0**: Success.
- **2**: Invalid option or path.
- **3**: Homebrew is not installed, or the Brewfile does not exist.

#### See also

- [shell::brew::bundle::dump](#shellbrewbundledump)
