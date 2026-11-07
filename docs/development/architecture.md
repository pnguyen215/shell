# Architecture

## Load sequence

`src/shell.sh` (sourced from `~/.bashrc` / `~/.zshrc`):

1. Resolves `SHELL_DIR` from its own path (bash: `BASH_SOURCE`, zsh: `${(%):-%x}`); an exported `SHELL_DIR` wins.
2. Sources `constant/system.sh` (it defines `SHELL_SRC_DIR` and `SHELL_MODULE_GROUPS`).
3. Sources each group in `SHELL_MODULE_GROUPS` — `constant core dependency lib skill lang devops shield bot alias` — files alphabetically. Nothing in a group depends on file order _at load time_; functions only call each other at run time.
4. Primes the OS cache (`shell::os::type`) in the current shell so later calls fork nothing.

A file that fails to load is reported on stderr and counted in `SHELL_LOAD_ERRORS`; the rest still loads. `SHELL_DEBUG=1` traces every file.

## Layers (a layer may call itself and the ones above it)

```
constant   data only; no functions
core       console → logger → os/command → exec → clipboard → fzf → ask
dependency package manager, ensure(), one file per tool, Homebrew, Oh My Zsh
lib        fs, net, process, permission, strings, conf, ini, profile, bookmark, goto, ssh, workspace
skill      agent-skills installer (install, upgrade, uninstall, sync, list), built on lib/net
lang · devops · shield · bot   domain modules built on lib
alias      aliases onto documented functions
```

`core/logger.sh` is the contract for output: DEBUG/WARN/ERROR/FATAL on **stderr**, INFO/success on **stdout**; the same module renders every `-h` help block.

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
