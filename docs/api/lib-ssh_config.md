# lib/ssh_config.sh

Manage the Host aliases of ~/.ssh/config: add, list, show, remove, and connect by picking one.

## Overview

A `Host` block in `~/.ssh/config` turns `ssh -p 2222 -i ~/.ssh/key deploy@10.0.0.5`
into `ssh web1`, and every command of the ssh library (`shell::ssh::connect`,
`scp::upload`, `tunnel::local` ...) accepts such an alias wherever it wants a host.

Things worth knowing:

- `shell::ssh::config::add` puts the new block **before** the first `Host *`
  block, because ssh keeps the first value it finds for an option: a specific host
  placed after `Host *` would never override it. Without `Host *` the block goes
  at the end.
- Before the file is changed it is copied to `SHELL_SSH_CONFIG_BACKUP_FILE`
  (mode 600). The file keeps its owner and mode; a new one is created with 600,
  which ssh requires.
- Only plain aliases are listed and removed: patterns (`Host *.example.com`) and
  `Match` blocks are never touched. A `Host` line that names several aliases
  (`Host web1 web2`) is not edited either; split it by hand first.
- Comments are kept, including the ones right above a block you remove.
- `Include`d files are read by `shell::ssh::config::show` (it asks ssh itself) but
  not by `list`, `add` or `remove`, which work on the one file.
- `--mux` writes the ControlMaster lines that make later connections to the host
  reuse the first one (instant logins). See `shell::ssh::mux::check` and `::stop`.
- Every command takes `-f | --file <path>` to work on another config file.

## Index

- [shell::ssh::config::add](#shellsshconfigadd)
- [shell::ssh::config::list](#shellsshconfiglist)
- [shell::ssh::config::show](#shellsshconfigshow)
- [shell::ssh::config::remove](#shellsshconfigremove)
- [shell::ssh::config::remove::fzf](#shellsshconfigremovefzf)
- [shell::ssh::connect::fzf](#shellsshconnectfzf)

### shell::ssh::config::add

Add a Host alias to ~/.ssh/config (`Host alias` + `HostName`, `User`, `Port` ...).
Afterwards `ssh <alias>` (or `shell::ssh::connect <alias>`) is all you type. The
block goes before the first `Host *` block (see the file description), the file
is backed up first, and an alias that already exists is refused unless you add
`--force`, which replaces its block.

#### Example

```bash
shell::ssh::config::add web1 10.0.0.5 -u deploy
shell::ssh::config::add -u deploy -p 2222 -i ~/.ssh/id_ed25519 --mux web1 10.0.0.5
shell::ssh::config::add --force -J bastion db1 10.0.1.9
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Show the block that would be written, change nothing.

- **-u** | **--user \<name\>**

  `User`.

- **-p** | **--port \<n\>**

  `Port`.

- **-i** | **--identity \<file\>**

  `IdentityFile`, with `IdentitiesOnly yes` so the agent does not offer other keys.

- **-J** | **--jump \<hosts\>**

  `ProxyJump`.

- **--keepalive \<sec\>**

  `ServerAliveInterval` (with `ServerAliveCountMax`).

- **--forward-agent**

  `ForwardAgent yes`.

- **--mux**

  `ControlMaster auto`, `ControlPath`, `ControlPersist`.

- **--force**

  Replace the block of an existing alias.

- **-f** | **--file \<path\>**

  Another config file.

#### Arguments

- **$1** (string): The alias.
- **$2** (string): The real host name or address.

#### Exit codes

- **0**: The block was written (or shown, with -n).
- **1**: The file could not be written.
- **2**: Unknown option, missing arguments, or an invalid alias, host, user, port, key or jump list.
- **7**: The alias already exists and --force was not given.

#### See also

- [shell::ssh::config::list](#shellsshconfiglist)
- [shell::ssh::connect](#shellsshconnect)

### shell::ssh::config::list

List the Host aliases of ~/.ssh/config with their host, user, port, key and jump.
Only plain aliases are listed (no patterns, no `Match`). With `--names` the output
is the bare alias list, one per line, ready for a loop or for fzf.

#### Example

```bash
shell::ssh::config::list
for h in $(shell::ssh::config::list --names); do shell::ssh::check "$h"; done
```

#### Options

- **-h** | **--help**

  Show help and return.

- **--names**

  Print only the alias names.

- **-f** | **--file \<path\>**

  Another config file.

#### Exit codes

- **0**: Success.
- **2**: Unknown option.
- **3**: The config file does not exist.
- **8**: The file has no alias.

#### Output on stdout

- A table (or the names).

#### See also

- [shell::ssh::config::show](#shellsshconfigshow)

### shell::ssh::config::show

Show how ssh resolves a host (`ssh -G host`): host name, user, port, keys, jump ...
It is the truth ssh will act on, with defaults, `Include`s and `Host *` applied, so it
is the first thing to look at when a login goes to the wrong user or key. By default
only the useful settings are shown.

#### Example

```bash
shell::ssh::config::show web1
shell::ssh::config::show --all web1
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--all**

  Show every setting ssh resolved.

- **-f** | **--file \<path\>**

  Another config file (ssh -F).

#### Arguments

- **$1** (string): The alias or host.

#### Exit codes

- **0**: Success.
- **2**: Unknown option, no host, or an unsafe host.
- **3**: ssh is missing, or the file does not exist.
- N Exit status of ssh.

#### Output on stdout

- `setting value` lines.

### shell::ssh::config::remove

Remove a Host alias from ~/.ssh/config.
Only its block goes (see the file description for what that means), after a
confirmation unless `--yes`, and after a backup of the file.

#### Example

```bash
shell::ssh::config::remove web1
shell::ssh::config::remove --yes web1
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Say what would be removed, change nothing.

- **-y** | **--yes**

  Do not ask for confirmation.

- **-f** | **--file \<path\>**

  Another config file.

#### Arguments

- **$1** (string): The alias.

#### Exit codes

- **0**: The block was removed (or the dry run reported it).
- **1**: The file could not be written.
- **2**: Unknown option, no alias, or an invalid alias.
- **3**: The file or the alias does not exist.
- **4**: The alias shares its `Host` line with other names: edit the file by hand.
- **9**: You answered no, or input ended.

#### See also

- [shell::ssh::config::remove::fzf](#shellsshconfigremovefzf)

### shell::ssh::config::remove::fzf

Pick a Host alias with fzf and remove it.
Same as `shell::ssh::config::remove`, with the alias chosen from a list. It still
asks for confirmation unless `--yes`.

#### Example

```bash
shell::ssh::config::remove::fzf
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Say what would be removed, change nothing.

- **-y** | **--yes**

  Do not ask for confirmation.

- **-f** | **--file \<path\>**

  Another config file.

#### Exit codes

- **0**: The block was removed (or the dry run reported it).
- **3**: The file does not exist.
- **8**: The file has no alias.
- **9**: The selection or the confirmation was cancelled.

#### See also

- [shell::ssh::config::remove](#shellsshconfigremove)

### shell::ssh::connect::fzf

Pick a Host alias with fzf and connect to it.
The list is the Host aliases of `~/.ssh/config`; the preview shows how ssh
resolves the highlighted one. Any option of `shell::ssh::connect` can be given
first (`-n` to only print the command, `-v`, `-A` ...).

#### Example

```bash
shell::ssh::connect::fzf
shell::ssh::connect::fzf -n
shell::ssh::connect::fzf -A
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-F** | **--config \<file\>**

  Another ssh config file (used for the list and for ssh).

#### Exit codes

- **0**: Success.
- **3**: The config file does not exist, or ssh or fzf is missing.
- **8**: The config file has no alias.
- **9**: The selection was cancelled.
- N Exit status of shell::ssh::connect.

#### See also

- [shell::ssh::connect](#shellsshconnect)
- [shell::ssh::config::add](#shellsshconfigadd)
