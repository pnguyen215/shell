# Architecture

## Load sequence

`src/shell.sh` (sourced from `~/.bashrc` / `~/.zshrc`):

1. Resolves `SHELL_DIR` from its own path (bash: `BASH_SOURCE`, zsh: `${(%):-%x}`); an exported `SHELL_DIR` wins.
2. Sources `constant/system.sh` (it defines `SHELL_SRC_DIR` and `SHELL_MODULE_GROUPS`).
3. Sources each group in `SHELL_MODULE_GROUPS` — `constant core dependency lib markdown skill lang devops security bot alias` — files alphabetically. Nothing in a group depends on file order _at load time_; functions only call each other at run time.
4. Primes the OS cache (`shell::os::type`) in the current shell so later calls fork nothing.

A file that fails to load is reported on stderr and counted in `SHELL_LOAD_ERRORS`; the rest still loads. `SHELL_DEBUG=1` traces every file.

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
