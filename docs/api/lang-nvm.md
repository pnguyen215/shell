# lang/nvm.sh

nvm (Node Version Manager) commands: install, use, exec, alias, .nvmrc, auto-switch ...

## Overview

One documented function per `nvm` command, so everything in the nvm cheat
sheets is a `shell::nvm::*` call with the same flags, a `-n | --dry-run`
switch and argument validation. The interactive (fzf) layer, and the tools
that find Node versions you no longer use, are in lang/nvm_fzf.sh.

Installing nvm itself is `shell::dependency::nvm::install`
(src/dependency/nvm.sh); `shell::nvm::install` is `nvm install <version>`.

Things worth knowing:

- nvm is a shell function, so these functions call it in the **current**
  shell: `shell::nvm::use 20` changes the Node of the terminal you typed it
  in, which is the whole point. For the same reason `use`, `deactivate`,
  `unload` and `autouse` must not be run inside `$( ... )` or a pipeline.
- `-n | --dry-run` prints the `nvm` command (and copies it to the clipboard)
  instead of running it. It never needs nvm to be installed. Put it (and
  every other option) before the version.
- nvm's own flags keep their names (`--lts`, `--lts=<name>`, `--silent`,
  `--no-colors`, `--reinstall-packages-from=<version>` ...).
- A version is anything nvm understands: `20`, `v20.11.1`, `node`, `stable`,
  `lts/*`, `lts/iron`, `system`, `default` or an alias of yours. It is
  checked before nvm sees it: it cannot start with `-` and cannot contain
  spaces, quotes, `$`, `;` or `..`, so it can never be mistaken for an option.
- The exit status is nvm's own (for instance 3 for "version not found").

Not wrapped: `nvm root` and `nvm proxy` of the first cheat sheet belong to
nvm-windows; nvm for macOS / Linux has neither. Where nvm keeps its files is
`NVM_DIR`; a download proxy is the usual `HTTPS_PROXY` / `npm config set proxy`.

## Index

- [shell::nvm::version](#shellnvmversion)
- [shell::nvm::help](#shellnvmhelp)
- [shell::nvm::current](#shellnvmcurrent)
- [shell::nvm::which](#shellnvmwhich)
- [shell::nvm::ls](#shellnvmls)
- [shell::nvm::ls::remote](#shellnvmlsremote)
- [shell::nvm::version::local](#shellnvmversionlocal)
- [shell::nvm::version::remote](#shellnvmversionremote)
- [shell::nvm::install](#shellnvminstall)
- [shell::nvm::uninstall](#shellnvmuninstall)
- [shell::nvm::use](#shellnvmuse)
- [shell::nvm::run](#shellnvmrun)
- [shell::nvm::exec](#shellnvmexec)
- [shell::nvm::deactivate](#shellnvmdeactivate)
- [shell::nvm::unload](#shellnvmunload)
- [shell::nvm::alias](#shellnvmalias)
- [shell::nvm::default](#shellnvmdefault)
- [shell::nvm::unalias](#shellnvmunalias)
- [shell::nvm::install::latest_npm](#shellnvminstalllatest_npm)
- [shell::nvm::reinstall_packages](#shellnvmreinstall_packages)
- [shell::nvm::cache](#shellnvmcache)
- [shell::nvm::set_colors](#shellnvmset_colors)
- [shell::nvm::nvmrc::find](#shellnvmnvmrcfind)
- [shell::nvm::nvmrc::read](#shellnvmnvmrcread)
- [shell::nvm::nvmrc::write](#shellnvmnvmrcwrite)
- [shell::nvm::autouse::on](#shellnvmautouseon)
- [shell::nvm::autouse::off](#shellnvmautouseoff)
- [shell::nvm::autouse::status](#shellnvmautousestatus)
- [shell::nvm::doctor](#shellnvmdoctor)

### shell::nvm::version

Print the installed nvm version (`nvm --version`).

#### Example

```bash
shell::nvm::version
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Exit codes

- **0**: Success.
- **3**: nvm is not installed.

#### Output on stdout

- The version, e.g. `0.40.8`.

### shell::nvm::help

Show nvm's own help (`nvm --help`).

#### Example

```bash
shell::nvm::help
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Exit codes

- **0**: Success.
- **3**: nvm is not installed.

### shell::nvm::current

Print the Node version this shell uses (`nvm current`).

#### Example

```bash
shell::nvm::current
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Exit codes

- **0**: Success.
- **3**: nvm is not installed.

#### Output on stdout

- `v20.11.1`, `system` (the Node outside nvm) or `none`.

### shell::nvm::which

Print the path of an installed Node (`nvm which`).
Without a version, the one `.nvmrc` asks for; `current` is the active one.

#### Example

```bash
shell::nvm::which 22
shell::nvm::which current
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--silent**

  Print nothing but the path (no message when a version is omitted).

#### Arguments

- **$1** (string): Optional version, or `current`.

#### Exit codes

- **0**: Success.
- **2**: Invalid option or version.
- **3**: nvm is not installed, or that version is not installed.

#### Output on stdout

- The absolute path of the `node` binary.

### shell::nvm::ls

List the installed Node versions (`nvm ls`).

#### Example

```bash
shell::nvm::ls
shell::nvm::ls --no-colors --no-alias 20
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--no-colors**

  Plain text, no colour codes.

- **--no-alias**

  Do not list the aliases.

#### Arguments

- **$1** (string): Optional version to filter by, e.g. `20`.

#### Exit codes

- **0**: Success.
- **2**: Invalid option or version.
- **3**: nvm is not installed.

#### Output on stdout

- One line per version; `->` marks the one in use.

#### See also

- [shell::nvm::ls::remote](#shellnvmlsremote)

### shell::nvm::ls::remote

List the Node versions that can be installed (`nvm ls-remote`).
Needs the network. `--lts` keeps the long-term-support versions only.

#### Example

```bash
shell::nvm::ls::remote --lts
shell::nvm::ls::remote 22
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--lts**

  Only LTS versions.

- **--lts=\<name\>**

  Only that LTS line, e.g. `--lts=iron`.

- **--no-colors**

  Plain text, no colour codes.

#### Arguments

- **$1** (string): Optional version to filter by, e.g. `22`.

#### Exit codes

- **0**: Success.
- **2**: Invalid option or version.
- **3**: nvm is not installed.

#### Output on stdout

- One line per version, oldest first.

#### See also

- [shell::nvm::install::fzf](#shellnvminstallfzf)

### shell::nvm::version::local

Resolve a description to one installed version (`nvm version`).
`20` becomes the newest installed 20.x, e.g. `v20.11.1`; `N/A` when none is installed.

#### Example

```bash
shell::nvm::version::local 20
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): The version description.

#### Exit codes

- **0**: Success.
- **2**: Missing or invalid version.
- **3**: nvm is not installed, or no installed version matches.

#### Output on stdout

- The resolved version, or `N/A` (and exit status 3).

### shell::nvm::version::remote

Resolve a description to one version that can be installed (`nvm version-remote`).
Needs the network. `--lts` resolves against the LTS versions.

#### Example

```bash
shell::nvm::version::remote 22
shell::nvm::version::remote --lts=iron
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--lts**

  Choose among the LTS versions.

- **--lts=\<name\>**

  Choose among that LTS line.

#### Arguments

- **$1** (string): The version description (not needed with `--lts`).

#### Exit codes

- **0**: Success.
- **2**: Missing or invalid version.
- **3**: nvm is not installed, or nothing matches.

#### Output on stdout

- The resolved version.

### shell::nvm::install

Download and install a Node version (`nvm install`).
Without a version it installs the one `.nvmrc` asks for.

#### Example

```bash
shell::nvm::install --lts
shell::nvm::install --reinstall-packages-from=20 --default 22
shell::nvm::install -n 20.11.1
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-s**

  Skip the binary download, build from source only.

- **-b**

  Skip the source download, install from the binary only.

- **--lts**

  Install the latest LTS version.

- **--lts=\<name\>**

  Install the latest of that LTS line, e.g. `--lts=iron`.

- **--reinstall-packages-from \<version\>**

  Reinstall the global npm packages of that version.

- **--skip-default-packages**

  Ignore the `default-packages` file.

- **--latest-npm**

  After installing, upgrade npm to the latest working version.

- **--no-progress**

  Hide the download progress bar.

- **--alias \<name\>**

  After installing, point that alias at the version.

- **--default**

  After installing, make it the default version.

#### Arguments

- **$1** (string): Optional version, e.g. `22`, `20.11.1`, `node`, `lts/iron`.

#### Exit codes

- **0**: Success.
- **2**: Invalid option or version.
- **3**: nvm is not installed.
- N Exit status of nvm.

#### See also

- [shell::nvm::install::fzf](#shellnvminstallfzf)
- [shell::nvm::migrate::fzf](#shellnvmmigratefzf)

### shell::nvm::uninstall

Remove an installed Node version (`nvm uninstall`).
nvm refuses to remove the version that is in use: switch first.

#### Example

```bash
shell::nvm::uninstall 18.19.0
shell::nvm::uninstall --lts=hydrogen
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--lts**

  Remove the version the `lts/*` alias points to.

- **--lts=\<name\>**

  Remove the version of that LTS line.

#### Arguments

- **$1** (string): The version (not needed with `--lts`).

#### Exit codes

- **0**: Success.
- **2**: No version, or an invalid one.
- **3**: nvm is not installed.
- N Exit status of nvm (**1**: for the version in use).

#### See also

- [shell::nvm::uninstall::fzf](#shellnvmuninstallfzf)
- [shell::nvm::unused::fzf](#shellnvmunusedfzf)

### shell::nvm::use

Switch THIS shell to a Node version (`nvm use`).
Changes `PATH` of the current terminal only. Without a version it uses the
one `.nvmrc` asks for. Do not run it inside `$( ... )` or a pipeline: the
change would be lost with the subshell.

#### Example

```bash
shell::nvm::use 20
shell::nvm::use --lts
shell::nvm::use            # from the .nvmrc of the project
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--silent**

  Print nothing.

- **--lts**

  Use the version the `lts/*` alias points to.

- **--lts=\<name\>**

  Use that LTS line, e.g. `--lts=iron`.

#### Arguments

- **$1** (string): Optional version, e.g. `20`, `node`, `lts/iron`, an alias.

#### Exit codes

- **0**: Success.
- **2**: Invalid option or version.
- **3**: nvm is not installed.
- N Exit status of nvm (for instance **3**: when the version is not installed).

#### See also

- [shell::nvm::use::fzf](#shellnvmusefzf)

### shell::nvm::run

Run `node` on a given version with the arguments you pass (`nvm run`).
The shell's own version is not changed. Everything after the version is
handed to node untouched, so `--version` there is node's, not ours.

#### Example

```bash
shell::nvm::run 20 app.js
shell::nvm::run 18 --version
shell::nvm::run --lts app.js
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--silent**

  Print nothing of nvm's own.

- **--lts**

  Use the LTS alias; then there is no version, only node's arguments.

- **--lts=\<name\>**

  Use that LTS line.

#### Arguments

- **$1** (string): The version (not given with `--lts`).
- **...** (string): Arguments for node, e.g. `app.js`.

#### Exit codes

- **0**: Success.
- **2**: Missing or invalid version.
- **3**: nvm is not installed.
- N Exit status of node.

#### See also

- [shell::nvm::exec](#shellnvmexec)

### shell::nvm::exec

Run any command with a given Node on the PATH (`nvm exec`).
The shell's own version is not changed. Everything after the version is the
command, passed untouched.

#### Example

```bash
shell::nvm::exec 20 npm test
shell::nvm::exec current node -p process.version
shell::nvm::exec --lts npm ci
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--silent**

  Print nothing of nvm's own.

- **--lts**

  Use the LTS alias; then there is no version, only the command.

- **--lts=\<name\>**

  Use that LTS line.

#### Arguments

- **$1** (string): The version, or `current` (not given with `--lts`).
- **...** (string): The command and its arguments, e.g. `npm test`.

#### Exit codes

- **0**: Success.
- **2**: Missing version or command, or an invalid version.
- **3**: nvm is not installed.
- N Exit status of the command.

#### See also

- [shell::nvm::run](#shellnvmrun)
- [shell::nvm::exec::fzf](#shellnvmexecfzf)

### shell::nvm::deactivate

Undo nvm's effect on this shell (`nvm deactivate`): the system Node is back.
Run it in the current shell, not in `$( ... )`.

#### Example

```bash
shell::nvm::deactivate
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--silent**

  Print nothing.

#### Exit codes

- **0**: Success.
- **3**: nvm is not installed.

### shell::nvm::unload

Remove nvm from this shell session (`nvm unload`): the `nvm` function is gone.
Nothing on disk changes; the next `shell::nvm::*` call loads nvm again.

#### Example

```bash
shell::nvm::unload
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Exit codes

- **0**: Success.
- **3**: nvm is not installed.

### shell::nvm::alias

List aliases, or point an alias at a version (`nvm alias`).
With no argument: every alias. With one: the aliases that start with it.
With two: `alias <name> <version>` creates or changes an alias.

#### Example

```bash
shell::nvm::alias
shell::nvm::alias work 20.11.1
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--no-colors**

  Plain text, no colour codes.

#### Arguments

- **$1** (string): Optional alias name, or a prefix to list.
- **$2** (string): Optional version to point the alias at.

#### Exit codes

- **0**: Success.
- **2**: Invalid option, name or version.
- **3**: nvm is not installed.

#### See also

- [shell::nvm::default](#shellnvmdefault)
- [shell::nvm::unalias](#shellnvmunalias)

### shell::nvm::default

Show, or set, the default version new shells start with (`nvm alias default`).

#### Example

```bash
shell::nvm::default
shell::nvm::default 22
shell::nvm::default 'lts/*'
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): Optional version: `22`, `lts/*`, `node` ...; without it the current default is shown.

#### Exit codes

- **0**: Success.
- **2**: Invalid option or version.
- **3**: nvm is not installed.

#### See also

- [shell::nvm::default::fzf](#shellnvmdefaultfzf)

### shell::nvm::unalias

Delete an alias (`nvm unalias`).

#### Example

```bash
shell::nvm::unalias work
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): The alias name.

#### Exit codes

- **0**: Success.
- **2**: Missing or invalid name.
- **3**: nvm is not installed.

#### See also

- [shell::nvm::unalias::fzf](#shellnvmunaliasfzf)

### shell::nvm::install::latest_npm

Upgrade npm to the latest version that works with the current Node
(`nvm install-latest-npm`).

#### Example

```bash
shell::nvm::install::latest_npm
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Exit codes

- **0**: Success.
- **3**: nvm is not installed.

### shell::nvm::reinstall_packages

Copy the global npm packages of another version into the current one
(`nvm reinstall-packages`).

#### Example

```bash
shell::nvm::use 22 && shell::nvm::reinstall_packages 20
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): The version to copy the packages from.

#### Exit codes

- **0**: Success.
- **2**: Missing or invalid version.
- **3**: nvm is not installed.

#### See also

- [shell::nvm::migrate::fzf](#shellnvmmigratefzf)

### shell::nvm::cache

Show or empty nvm's download cache (`nvm cache dir` / `nvm cache clear`).

#### Example

```bash
shell::nvm::cache
shell::nvm::cache clear
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): `dir` (default) prints the path; `clear` empties the cache.

#### Exit codes

- **0**: Success.
- **2**: Unknown action.
- **3**: nvm is not installed.

#### Output on stdout

- With `dir`, the cache directory.

### shell::nvm::set_colors

Set the five colours nvm prints with (`nvm set-colors`).
Give five letters: installed, system, current, not installed, default.
`r g b c m y k e` are the colours, upper case is bold, `W` is white.

#### Example

```bash
shell::nvm::set_colors cgYmW
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): Five colour letters, e.g. `cgYmW`; omit to see the current ones.

#### Exit codes

- **0**: Success.
- **2**: Not five valid colour letters.
- **3**: nvm is not installed.

### shell::nvm::nvmrc::find

Print the path of the nearest `.nvmrc`, looking in a directory and its parents.

#### Example

```bash
rc="$(shell::nvm::nvmrc::find)" && echo "pinned by $rc"
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Arguments

- **$1** (string): Directory to start from (default: the current one).

#### Exit codes

- **0**: One was found.
- **3**: There is none.

#### Output on stdout

- The path of the `.nvmrc`.

### shell::nvm::nvmrc::read

Print the version the nearest `.nvmrc` asks for.

#### Example

```bash
shell::nvm::install "$(shell::nvm::nvmrc::read)"
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Arguments

- **$1** (string): Directory to start from (default: the current one).

#### Exit codes

- **0**: Success.
- **3**: There is no `.nvmrc`.
- **8**: The `.nvmrc` is empty.

#### Output on stdout

- The first line of the `.nvmrc`, trimmed (e.g. `20.11.1` or `lts/iron`).

### shell::nvm::nvmrc::write

Pin a Node version for a project by writing its `.nvmrc`.
Without a version it pins the one this shell uses now. An existing `.nvmrc`
is kept unless `--force` is given.

#### Example

```bash
shell::nvm::nvmrc::write 22
shell::nvm::nvmrc::write --force lts/iron
shell::nvm::nvmrc::write             # pins the active version
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print what would be written instead of writing it.

- **-f** | **--force**

  Overwrite an existing `.nvmrc`.

- **-d** | **--dir**

  Directory to write into (default: the current one).

#### Arguments

- **$1** (string): Optional version: `22`, `20.11.1`, `lts/iron`, `node` ...

#### Exit codes

- **0**: Written.
- **2**: Invalid option, directory or version, or no Node is active to pin.
- **7**: A `.nvmrc` exists and `--force` was not given.

#### See also

- [shell::nvm::use](#shellnvmuse)

### shell::nvm::autouse::on

Switch Node automatically when you `cd` into a project with a `.nvmrc`.
Registers a hook for this shell session only (zsh: `chpwd`; bash:
`PROMPT_COMMAND`) and applies it once for the current directory. Add the call
to your profile to keep it. Directories without a `.nvmrc` leave your version alone.
Run it in the current shell, not in `$( ... )`.

#### Example

```bash
shell::nvm::autouse::on
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Exit codes

- **0**: The hook is registered.
- **3**: nvm is not installed.

#### See also

- [shell::nvm::autouse::off](#shellnvmautouseoff)

### shell::nvm::autouse::off

Stop switching Node automatically (undo shell::nvm::autouse::on).

#### Example

```bash
shell::nvm::autouse::off
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Exit codes

- **0**: The hook is removed (or was not registered).

#### See also

- [shell::nvm::autouse::on](#shellnvmautouseon)

### shell::nvm::autouse::status

Tell whether automatic switching is on in this shell.

#### Example

```bash
shell::nvm::autouse::status
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Exit codes

- **0**: It is on.
- **1**: It is off.

#### Output on stdout

- `on` or `off`.

### shell::nvm::doctor

Check the nvm set-up and say what is wrong, if anything.
Reports where nvm is, its version, the Node in use, the default, the version
the nearest `.nvmrc` asks for (and whether it is installed), and whether the
`node` on your PATH is the one nvm manages.

#### Example

```bash
shell::nvm::doctor
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Exit codes

- **0**: Nothing is wrong (warnings are allowed).
- **1**: Something is wrong.
- **3**: nvm is not installed.

#### Output on stdout

- One line per check, `ok`, `warn` or `fail` first.
