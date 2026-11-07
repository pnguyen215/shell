# nvm (Node Version Manager)

`shell::nvm::*` wraps the `nvm` commands of the nvm cheat sheets and adds fzf pickers, `.nvmrc` helpers, automatic switching and a finder for Node versions you no longer use. Installing or removing **nvm itself** is `shell::dependency::nvm::install` / `::uninstall`.

Every function has `-h` and `-n | --dry-run` (print the `nvm` command, run nothing; nvm need not be installed). Put the options before the version. A version is checked before nvm sees it: it cannot start with `-` or contain spaces, quotes, `$`, `;` or `..`, so it can never be taken for an option. The exit status is nvm's own.

nvm is a **shell function**, so these functions run it in the _current_ shell: `shell::nvm::use 20` changes the Node of the terminal you typed it in. For that reason `use`, `deactivate`, `unload` and `autouse` must not be run inside `$( ... )` or a pipeline.

## Cheat sheet → function

| nvm                             | Function                                                                                                                  |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `nvm --help`, `--version`       | `help`, `version`                                                                                                         |
| `nvm ls`, `ls-remote [--lts]`   | `ls`, `ls::remote` (`--no-colors`, `--no-alias`, `--lts[=<name>]`)                                                        |
| `nvm install [<v>]`             | `install` (`-s`, `-b`, `--lts[=<name>]`, `--reinstall-packages-from <v>`, `--latest-npm`, `--alias <n>`, `--default` ...) |
| `nvm uninstall <v>` / `--lts`   | `uninstall`                                                                                                               |
| `nvm use [<v>]`                 | `use` (`--silent`, `--lts[=<name>]`)                                                                                      |
| `nvm run <v> <args>`            | `run` — what follows the version goes to node untouched                                                                   |
| `nvm exec <v> <cmd>`            | `exec` — what follows the version is the command, untouched                                                               |
| `nvm current`, `which <v>`      | `current`, `which`                                                                                                        |
| `nvm version`, `version-remote` | `version::local`, `version::remote`                                                                                       |
| `nvm alias`, `alias <n> <v>`    | `alias`, `default [<v>]` (= `alias default`)                                                                              |
| `nvm unalias <n>`               | `unalias`                                                                                                                 |
| `nvm deactivate`, `unload`      | `deactivate`, `unload`                                                                                                    |
| `nvm install-latest-npm`        | `install::latest_npm`                                                                                                     |
| `nvm reinstall-packages <v>`    | `reinstall_packages`                                                                                                      |
| `nvm cache dir` / `clear`       | `cache [dir \| clear]`                                                                                                    |
| `nvm set-colors cgYmW`          | `set_colors`                                                                                                              |
| `.nvmrc` workflow               | `nvmrc::find`, `nvmrc::read`, `nvmrc::write [<v>]`                                                                        |
| auto-switch on `cd`             | `autouse::on`, `autouse::off`, `autouse::status`                                                                          |
| (check-up)                      | `doctor`                                                                                                                  |

`nvm root` and `nvm proxy` (first cheat sheet) are **nvm-windows** commands; nvm for macOS / Linux has neither, so they are not wrapped. nvm keeps its files in `NVM_DIR`; a download proxy is the usual `HTTPS_PROXY`.

## Interactive (fzf)

Tab marks several entries, Ctrl-A marks all, Enter confirms, ESC cancels. The preview pane shows the **global npm packages** of the focused Node version (what you would lose by removing it, and what `--reinstall-packages-from` carries over).

| Function                      | Alias            | What it does                                                                                   |
| ----------------------------- | ---------------- | ---------------------------------------------------------------------------------------------- |
| `manage`                      | `snm`            | one menu for everything below                                                                  |
| `use::fzf`                    | `snmu`           | pick an installed version and switch **this** shell to it                                      |
| `install::fzf [--lts]`        | `snmi`, `snmil`  | browse every release (newest first, LTS line named) and install                                |
| `uninstall::fzf`              | `snmrm`          | pick versions; the one in use is skipped; an alias target is flagged                           |
| `default::fzf`                | `snmd`           | pick the default (also `lts/*` and `node`, which follow new installs)                          |
| `alias::fzf` / `unalias::fzf` | `snma` / `snmua` | name an alias for a version / delete aliases of yours (nvm's own are never listed)             |
| `nvmrc::fzf`                  | `snmrc`          | pick this project's version and write its `.nvmrc`                                             |
| `exec::fzf`, `run::fzf`       | `snmx`           | pick a version, then run `<command>` / `node <args>` with it                                   |
| `migrate::fzf`                | `snmmv`          | install a newer Node (latest LTS, latest, or from the list) and carry the global packages over |
| `reinstall_packages::fzf`     |                  | copy the global packages of a picked version into the one in use                               |

Append `-n` to any of them (or use the `-n` alias): you still choose, but the final command is printed instead of run. `-y` skips the confirmations.

## Finding what you no longer use

```bash
shell::nvm::unused                     # report only (alias snmun)
shell::nvm::unused::fzf                # pick and remove (alias snmunf)
shell::nvm::size                       # biggest versions first, and the download cache (alias snmsz)
shell::nvm::unused --superseded --projects ~/code
```

An installed version is **kept** when something refers to it: the version in use, every alias (`default`, `lts/*`, `node`, `stable` and yours), the `.nvmrc` of the current project, and the `.nvmrc` files (up to 4 levels deep, `node_modules` skipped) under the directories you name with `--projects`, or in `SHELL_NVM_PROJECT_ROOTS` (space separated). What is left is:

- **superseded**: a newer release of the same major is installed (`v20.9.0` while `v20.11.1` exists);
- **unreferenced**: the newest of its major, but nothing refers to it.

nvm cannot know which projects you have, so name your project directories once to keep their versions safe. Nothing is pre-selected, nothing is removed without your confirmation, and the version in use cannot be removed (nvm refuses too).

## Project versions and automatic switching

```bash
shell::nvm::nvmrc::write 22         # pin; refuses to overwrite without --force
shell::nvm::use                     # in the project: follows .nvmrc
shell::nvm::autouse::on             # switch on cd (zsh: chpwd, bash: PROMPT_COMMAND); add the call to your profile
```

Directories without a `.nvmrc` leave your version alone; a `.nvmrc` that asks for a version that is not installed is reported, not silently installed.

## Installing and removing nvm

```bash
shell::dependency::nvm::install              # official installer, pinned to SHELL_NVM_VERSION (v0.40.8)
shell::dependency::nvm::install -n -v v0.40.8
shell::dependency::nvm::install --no-profile # do not touch ~/.zshrc / ~/.bashrc
shell::dependency::nvm::uninstall -n         # shows what would go
```

The uninstaller deletes `NVM_DIR` **and every Node version in it**. It only removes a directory that contains `nvm.sh`, refuses `/`, your home directory and relative paths, leaves a Homebrew nvm to `brew uninstall nvm`, asks first (`-y` skips), and keeps `<file>.nvm-backup` of every profile file it edits.

## Tests

`test/test_nvm*.sh` run against a fake nvm. `test_nvm_real.sh` runs the same commands against a real `nvm.sh` and is skipped unless you point it at one:

```bash
git clone --depth 1 https://github.com/nvm-sh/nvm /tmp/nvm-src
SHELL_TEST_NVM_SRC=/tmp/nvm-src test/run_tests.sh nvm_real
```
