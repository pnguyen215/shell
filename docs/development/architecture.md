# Architecture

## Load sequence

`src/shell.sh` (sourced from `~/.bashrc` / `~/.zshrc`):

1. Resolves `SHELL_DIR` from its own path by parameter expansion, without a subshell (bash: `BASH_SOURCE`, zsh: `${(%):-%x}`); an exported `SHELL_DIR` wins.
2. Sources `constant/system.sh` (it defines `SHELL_SRC_DIR` and `SHELL_MODULE_GROUPS`) and `loader/lazy.sh` (the lazy-load machinery; it only defines functions).
3. Loads the module groups in `SHELL_MODULE_GROUPS` — `constant core dependency lib markdown skill lang lang/git devops security bot alias` — files alphabetically (`lang/git` is the Git toolkit's `index.sh`; its subdirectories are not globbed). Nothing in a group depends on file order _at load time_; functions only call each other at run time. By default this goes through the lazy cache (below); `SHELL_LAZY=0` or `SHELL_DEBUG=1` loads everything eagerly instead.
4. Sets the OS cache (`SHELL_OS_TYPE`) from `$OSTYPE`, so no `uname` runs at load.

A file that fails to load is reported on stderr and counted in `SHELL_LOAD_ERRORS`; the rest still loads. `SHELL_DEBUG=1` traces every file.

### Start-up cost and lazy loading

Sourcing all modules parsed about 2.5 MB of function bodies on every new shell (about +69 ms in bash and +79 ms in zsh over an empty shell, measured on Apple silicon). The loader now keeps a cache, `<install dir>/.cache/lazy.sh`, generated on the first start:

- every module that **only defines functions** is replaced by one-line stubs; the first call of any of its functions sources the module and repeats the call with the same arguments (`declare -F`, `type` and `shell::function::list` see the stubs as functions from the start);
- modules with **top-level statements** (constants, aliases, option defaults, widgets) stay eager and run at load exactly as before; a function defined by two modules forces both to stay eager;
- a function that was **redefined before its module loaded** (a user override, a test mock) is saved and put back after the module is sourced, so overrides behave as they did with eager loading;
- the staleness check uses the shell builtin `-nt` against every module, group directory and the loader (no fork); a missing or stale cache is rebuilt, written atomically (`mktemp` + `mv`), and any failure falls back to eager loading silently;
- the cache lives inside the install directory, so an upgrade (which replaces the directory) can never see an old cache and uninstall removes it with the rest; it is git-ignored in a checkout.

Result (median of 100 starts, added over an empty shell): bash 5 about +11 ms, zsh about +10 ms, bash 3.2 about +15 ms, **zero external processes at load**. `make test` runs `test/test_startup.sh`, which asserts the same function set as eager mode, a silent load, no leaked shell options, zero forks, idempotent re-sourcing, a path with spaces and the cache lifecycle.

**Contributor rule: no command substitutions, external commands, file reads or network at the top level of a module.** A module that breaks it silently stays eager and costs start-up time. Load-time work belongs behind a function that computes it on first use.

## Layers (a layer may call itself and the ones above it)

```
constant   data only; no functions
core       console → logger → os/command → exec → clipboard → fzf → ask
dependency package manager, ensure(), one file per tool, Homebrew, Oh My Zsh
lib        fs, net, process, permission, strings, conf, ini, profile, bookmark, goto, ssh, workspace,
           function (discovery of the library's own functions)
markdown   Markdown / Telegram MarkdownV2 / plain-text document builder (no dependencies besides core)
skill      agent-skills installer (install, upgrade, uninstall, sync, list), built on lib/net;
           audit.sh links Cloudflare's security-audit skill from a managed git clone
lang · devops · security · bot   domain modules built on lib
                                (security: crypto, and the security investigation modules security_*.sh, docs/features/security.md)
alias      aliases onto documented functions
```

`core/logger.sh` is the contract for output: DEBUG/WARN/ERROR/FATAL on **stderr**, INFO/success on **stdout**; the same module renders every `-h` help block.

## Function discovery

`shell::help` (and `shell::function::{list,info,explore}`, in `src/lib/function.sh`) answer "what functions exist and how do I use them". One mechanism feeds all of them: the shdoc block that `make lint` already requires above every function. Nothing is registered by hand.

```
src/**/*.sh --> data/function-catalog.awk --> _shell::function::catalog --> _shell::function::select
                  (+ names loaded in the shell)    (8-field records)              |
                                                       list (text) | info (one page) | explore (fzf) -> shell::help, sfn
                                                                      info + preview: data/function-doc.awk, data/function-preview.sh
```

- **Discovery and metadata** live in one place, `data/function-catalog.awk`; the rule it applies (a column-0 `shell::`/`_shell::` definition, documented by the `#` block directly above) is the one the lint checks enforce.
- **Public vs internal** is the `_shell::` prefix; **loaded** is what the current shell reports (`declare -F` in bash, `typeset +f` in zsh, asked in `_shell::function::loaded` only).
- `list`, `info` and `explore` are interfaces over the same `_shell::function::catalog` / `_shell::function::select`; do not add a second function list.
- To add a function to the system, write it with its shdoc block; to extend what is known about functions, extend the catalog record. Details: [function-discovery.md](../features/function-discovery.md).

`src/data/` holds files that are read, not sourced (commit message templates, the function-discovery awk programs and preview script); the loader never sources it.

## Where data lives

```
$SHELL_CONFIG_DIR (default ~/.shell-config, mode 700)
├── key.conf            KEY=base64(value)               mode 600
├── protected.conf      keys interactive removal refuses
├── group.conf          group=KEY1,KEY2
├── backup/
├── bookmarks/.bookmarks    <abs path>|<name>
└── workspace/          one INI file per workspace
```

All of it is derived from `src/constant/paths.sh`. Secrets are **encoded, not encrypted** (Base64); the mode bits are the protection. For real encryption use `shell::crypto::aes256cbc::*`.

## Dependencies

Declared in `constant/dependencies.sh`; installed on demand by `shell::dependency::<tool>::ensure`, which is a single `command -v` when the tool is present. Policy switch: `SHELL_AUTO_INSTALL_DEPS` (1 = install via the native package manager, 0 = report only).

## Exit codes

See `src/constant/returncodes.sh` (`RETURN_SUCCESS 0 … RETURN_TIMEOUT 10`). Functions document the codes they can return with `@exitcode`.

## Quality gates

`make lint` (syntax in bash and zsh, naming, shdoc coverage, zsh-reserved names, portability, constants location, no `exit`, shellcheck, shfmt) and `make test` (bash and zsh; about 100 assertions per shell). CI runs both on Ubuntu 22.04/latest and macOS 13/latest, plus the macOS system bash 3.2.
