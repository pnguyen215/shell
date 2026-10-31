# lang/nvm_fzf.sh

Interactive nvm with fzf, and tools to find Node versions you no longer use.

## Overview

Built on the plain commands of lang/nvm.sh. Every `*::fzf` function lists
something you can act on, lets you pick with a live preview of the global npm
packages of each Node version (Tab marks, Ctrl-A marks all, Enter confirms,
ESC cancels), asks before anything destructive, and then calls the matching
`shell::nvm::*` command.

Like the commands they use, `use::fzf`, `exec::fzf` and the menu run in the
**current shell**, so switching version there changes this terminal.

Finding what you no longer use (shell::nvm::unused, shell::nvm::unused::fzf)
looks at the installed versions and keeps every one that something refers to:
the version in use, every alias (so `default`, `lts/*`, `node`, `stable` and
yours), the `.nvmrc` of the current project and of the project directories
you name. What is left is reported as:

- **superseded**: a newer version of the same major (a newer patch) is installed;
- **unreferenced**: it is the newest of its major, but nothing refers to it.

Nothing is removed without you marking it and confirming it. Reading the
`.nvmrc` files of your projects is the one thing nvm itself cannot do for
you: name the directories with `--projects <dir>`, or in
`SHELL_NVM_PROJECT_ROOTS` (space separated), and a version that one of those
projects asks for is kept.

`-n | --dry-run` still lets you browse and choose, but prints the final nvm
command instead of running it. `-y | --yes` skips the confirmations.

## Index

- [shell::nvm::use::fzf](#shellnvmusefzf)
- [shell::nvm::install::fzf](#shellnvminstallfzf)
- [shell::nvm::uninstall::fzf](#shellnvmuninstallfzf)
- [shell::nvm::default::fzf](#shellnvmdefaultfzf)
- [shell::nvm::alias::fzf](#shellnvmaliasfzf)
- [shell::nvm::unalias::fzf](#shellnvmunaliasfzf)
- [shell::nvm::nvmrc::fzf](#shellnvmnvmrcfzf)
- [shell::nvm::exec::fzf](#shellnvmexecfzf)
- [shell::nvm::run::fzf](#shellnvmrunfzf)
- [shell::nvm::migrate::fzf](#shellnvmmigratefzf)
- [shell::nvm::reinstall_packages::fzf](#shellnvmreinstall_packagesfzf)
- [shell::nvm::size](#shellnvmsize)
- [shell::nvm::unused](#shellnvmunused)
- [shell::nvm::unused::fzf](#shellnvmunusedfzf)
- [shell::nvm::manage](#shellnvmmanage)

### shell::nvm::use::fzf

Pick an installed Node version and switch THIS shell to it.
The list shows the version in use and the aliases of each version. Runs in the
current shell: do not call it inside `$( ... )` or a pipeline.

#### Example

```bash
shell::nvm::use::fzf
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the `nvm use` command instead of running it.

- **--silent**

  Print nothing of nvm's own.

#### Exit codes

- **0**: Done, or nothing chosen.
- **3**: nvm or fzf is not installed.

#### See also

- [shell::nvm::use](#shellnvmuse)

### shell::nvm::install::fzf

Browse the Node versions that can be installed, and install the ones you pick.
Newest first, with the LTS line named and the versions you already have
tagged. Needs the network. Tab marks several, Ctrl-A marks all.

#### Example

```bash
shell::nvm::install::fzf --lts
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the install commands instead of running them.

- **--lts**

  Only LTS versions.

- **--lts=\<name\>**

  Only that LTS line, e.g. `--lts=iron`.

- **--latest-npm**

  Upgrade npm after each install.

- **--default**

  Make the (last) installed version the default.

#### Exit codes

- **0**: Done, or nothing chosen.
- **1**: An install failed (the others were still tried).
- **3**: nvm or fzf is not installed.

#### See also

- [shell::nvm::install](#shellnvminstall)

### shell::nvm::uninstall::fzf

Pick installed Node versions and uninstall them, after a safety check.
The version in use is skipped (nvm refuses to remove it); a version an alias
points at is removed only if you confirm, with the alias named in the question.

#### Example

```bash
shell::nvm::uninstall::fzf
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the uninstall commands instead of running them.

- **-y** | **--yes**

  Do not ask for confirmation.

#### Exit codes

- **0**: Done, nothing chosen, or the user declined.
- **1**: An uninstall failed (the others were still tried).
- **3**: nvm or fzf is not installed.

#### See also

- [shell::nvm::uninstall](#shellnvmuninstall)
- [shell::nvm::unused::fzf](#shellnvmunusedfzf)

### shell::nvm::default::fzf

Pick the Node version new shells should start with (`nvm alias default`).
Besides the installed versions the list offers `lts/*` (the newest LTS, it
moves when you install a newer one) and `node` (the newest version installed).

#### Example

```bash
shell::nvm::default::fzf
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the command instead of running it.

#### Exit codes

- **0**: Done, or nothing chosen.
- **3**: nvm or fzf is not installed.

#### See also

- [shell::nvm::default](#shellnvmdefault)

### shell::nvm::alias::fzf

Pick an installed version, then name an alias for it (`nvm alias <name> <version>`).

#### Example

```bash
shell::nvm::alias::fzf
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the command instead of running it.

#### Exit codes

- **0**: Done, or nothing chosen.
- **2**: The alias name is not valid.
- **3**: nvm or fzf is not installed.

#### See also

- [shell::nvm::alias](#shellnvmalias)

### shell::nvm::unalias::fzf

Pick the aliases you made and delete them (`nvm unalias`).
nvm's own aliases (`node`, `stable`, `lts/*` ...) are never listed.

#### Example

```bash
shell::nvm::unalias::fzf
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the commands instead of running them.

- **-y** | **--yes**

  Do not ask for confirmation.

#### Exit codes

- **0**: Done, no aliases of yours, nothing chosen, or the user declined.
- **1**: A removal failed (the others were still tried).
- **3**: nvm or fzf is not installed.

#### See also

- [shell::nvm::unalias](#shellnvmunalias)

### shell::nvm::nvmrc::fzf

Pick the Node version a project should use and write its `.nvmrc`.
The list offers the installed versions plus `lts/*` and `node`.

#### Example

```bash
shell::nvm::nvmrc::fzf
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print what would be written instead of writing it.

- **-f** | **--force**

  Overwrite an existing `.nvmrc`.

#### Exit codes

- **0**: Written, or nothing chosen.
- **7**: A `.nvmrc` exists and `--force` was not given.
- **3**: nvm or fzf is not installed.

#### See also

- [shell::nvm::nvmrc::write](#shellnvmnvmrcwrite)

### shell::nvm::exec::fzf

Pick an installed Node version and run a command with it (`nvm exec`).
Put the options (`-n`, `--silent`) first; everything after them is the command,
passed untouched.

#### Example

```bash
shell::nvm::exec::fzf npm test
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the command instead of running it.

- **--silent**

  Print nothing of nvm's own.

#### Arguments

- **...** (string): The command and its arguments, e.g. `npm test`.

#### Exit codes

- **0**: Done, or nothing chosen.
- **2**: No command was given.
- **3**: nvm or fzf is not installed.
- N Exit status of the command.

#### See also

- [shell::nvm::exec](#shellnvmexec)

### shell::nvm::run::fzf

Pick an installed Node version and run `node` with it (`nvm run`).
Put the options (`-n`, `--silent`) first; everything after them goes to node.

#### Example

```bash
shell::nvm::run::fzf app.js
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the command instead of running it.

- **--silent**

  Print nothing of nvm's own.

#### Arguments

- **...** (string): Arguments for node, e.g. `app.js`.

#### Exit codes

- **0**: Done, or nothing chosen.
- **2**: No argument was given.
- **3**: nvm or fzf is not installed.
- N Exit status of node.

#### See also

- [shell::nvm::run](#shellnvmrun)

### shell::nvm::migrate::fzf

Install a newer Node and carry your global npm packages over.
Pick the version to move **from** (the preview shows its global packages),
then what to move **to**: the latest LTS, the latest release, or a version
from the list. It runs `nvm install <target> --reinstall-packages-from=<from>`.
The old version is not removed: do that afterwards with `unused::fzf`.

#### Example

```bash
shell::nvm::migrate::fzf
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the install command instead of running it.

#### Exit codes

- **0**: Done, or nothing chosen.
- **3**: nvm or fzf is not installed.

#### See also

- [shell::nvm::install](#shellnvminstall)
- [shell::nvm::unused::fzf](#shellnvmunusedfzf)

### shell::nvm::reinstall_packages::fzf

Pick a version and copy its global npm packages into the one in use
(`nvm reinstall-packages`).

#### Example

```bash
shell::nvm::reinstall_packages::fzf
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the command instead of running it.

#### Exit codes

- **0**: Done, or nothing chosen.
- **3**: nvm or fzf is not installed.

#### See also

- [shell::nvm::reinstall_packages](#shellnvmreinstall_packages)

### shell::nvm::size

Show which installed Node versions take the most disk space.
Measures each version's directory in `NVM_DIR`, biggest first, and the download cache.

#### Example

```bash
shell::nvm::size
shell::nvm::size 5
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Arguments

- **$1** (integer): How many versions to show (default: 20).

#### Exit codes

- **0**: Success.
- **2**: The count is not a positive integer.
- **3**: nvm is not installed.

#### Output on stdout

- One line per version: size, version. Then the cache.

#### See also

- [shell::nvm::unused::fzf](#shellnvmunusedfzf)
- [shell::nvm::cache](#shellnvmcache)

### shell::nvm::unused

List the installed Node versions that nothing refers to.
Read-only. A version is kept when it is the one in use, the target of any
alias (`default`, `lts/*`, `node` and yours), or asked for by the `.nvmrc` of
the current project or of the directories given with `--projects`. The rest is
`superseded` (a newer release of the same major is installed) or
`unreferenced` (the newest of its major, but nothing uses it).

#### Example

```bash
shell::nvm::unused
shell::nvm::unused --superseded --projects ~/code
shell::nvm::unused --names | xargs -n1 shell::nvm::uninstall -n
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-s** | **--superseded**

  Only the superseded versions.

- **-p** | **--projects**

  Directory whose projects' `.nvmrc` files keep a version (repeatable).

- **-q** | **--names**

  Print only the versions, one per line (for scripts).

#### Exit codes

- **0**: Success, even when nothing was found.
- **2**: Invalid option.
- **3**: nvm is not installed.

#### Output on stdout

- A table: version, reason, size, why. With `--names`, just the versions.

#### See also

- [shell::nvm::unused::fzf](#shellnvmunusedfzf)

### shell::nvm::unused::fzf

Find unused Node versions, pick the ones to remove, and remove them.
Runs shell::nvm::unused::scan, lists the candidates (version, reason, size,
why) with a preview of each version's global npm packages, and lets you mark
the ones to uninstall. After a confirmation it runs `nvm uninstall` on each.
Nothing is pre-selected and nothing is removed without your confirmation.

#### Example

```bash
shell::nvm::unused::fzf
shell::nvm::unused::fzf --superseded
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Choose, but print the uninstall commands instead of running them.

- **-s** | **--superseded**

  Only the superseded versions.

- **-p** | **--projects**

  Directory whose projects' `.nvmrc` files keep a version (repeatable).

- **-y** | **--yes**

  Do not ask for confirmation.

#### Exit codes

- **0**: Done, nothing found, nothing chosen, or the user declined.
- **1**: An uninstall failed (the others were still tried).
- **3**: nvm or fzf is not installed.

#### See also

- [shell::nvm::unused](#shellnvmunused)
- [shell::nvm::uninstall](#shellnvmuninstall)

### shell::nvm::manage

The nvm control panel: one fzf menu for everything above.
Switch, install, uninstall, set the default, aliases, `.nvmrc`, automatic
switching, moving global packages, finding unused versions, disk usage, the
download cache and the check-up. Each entry opens its own picker; ESC or
"← Back" in the menu leaves. Runs in the current shell, so "Switch" changes
this terminal.

#### Example

```bash
shell::nvm::manage
shell::nvm::manage -n
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Pass `--dry-run` to every entry: choices are made but nothing is changed.

#### Exit codes

- **0**: The user left the menu.
- **3**: nvm or fzf is not installed.

#### See also

- [shell::nvm::use::fzf](#shellnvmusefzf)
- [shell::nvm::unused::fzf](#shellnvmunusedfzf)
