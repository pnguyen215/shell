# SSH

`shell::ssh::*` wraps the commands of the SSH cheat sheets ([quickref](https://quickref.me/ssh), [Linux Basecamp](https://linuxbasecamp.com/cheat-sheets/ssh), [Linuxize](https://linuxize.com/cheatsheet/ssh/), [raw.org](https://raw.org/cheat-sheet/ssh/), [phoenixNAP](https://phoenixnap.com/kb/wp-content/uploads/2024/09/ssh-commands-cheat-sheet-1.pdf), the [Ultimate SSH cheat sheet](https://gist.github.com/Sharique55/7b461776a3bef9b9fb8e2d4fdff41511)) on top of the key and tunnel helpers that were already in `lib/ssh.sh`.

Every function has `-h` and `-n | --dry-run` (print the command, copy it to the clipboard, run nothing; the program need not be installed). Options go **before** the target; for `connect` and `exec` everything after the target is the remote command, passed untouched. Nothing is run through `eval`, and a target, port, jump list or forwarding spec that could be taken for an option is refused before ssh sees it. The exit status is the program's own (255 when ssh cannot connect).

## One vocabulary

The connection commands share their options, and the letter each program really uses is picked for you (scp and sftp want `-P`; rsync receives them through `-e "ssh ..."`):

| Option                                     | Meaning                                                                |
| ------------------------------------------ | ---------------------------------------------------------------------- |
| `-p, --port <n>`                           | server port                                                            |
| `-i, --identity <f>`                       | private key (must exist, except in a dry run)                          |
| `-J, --jump <hosts>`                       | ProxyJump list                                                         |
| `-F, --config <f>`                         | another ssh config file                                                |
| `-o, --option <k=v>`                       | any ssh option, repeatable                                             |
| `--timeout <s>`                            | `ConnectTimeout`                                                       |
| `--keepalive <s>`                          | `ServerAliveInterval`                                                  |
| `--batch`                                  | `BatchMode=yes`: never ask for a password                              |
| `--accept-new`                             | `StrictHostKeyChecking=accept-new`: trust a host once, refuse a change |
| `-v -q -C`                                 | verbose, quiet, compress (ssh, scp, sftp)                              |
| `-A -X -t`                                 | forward agent, forward X11, force a terminal (ssh)                     |
| `-r`, `--preserve`                         | recursive, keep times and modes (scp)                                  |
| `--delete --exclude --simulate --progress` | rsync's own options                                                    |

There is deliberately no `StrictHostKeyChecking=no` shortcut: use `--accept-new`, or look at the fingerprint with `shell::ssh::known_hosts::scan`.

Defaults of a command (the keep-alive of a tunnel, the timeout of `check`) are put **after** your options, and ssh keeps the first value it sees, so your `--timeout` or `--keepalive` wins. Tunables: `SHELL_SSH_KEEPALIVE_INTERVAL`, `SHELL_SSH_KEEPALIVE_COUNT`, `SHELL_SSH_CHECK_TIMEOUT`, `SHELL_SSH_CONTROL_PERSIST` (`src/constant/defaults.sh`).

## Cheat sheet → function

| Cheat sheet                                         | Function                                                                                                     |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `ssh user@host`, `-p`, `-i`, `-J`, `-v`, `-A`, `-X` | `connect`                                                                                                    |
| `ssh host 'cmd'`, `ssh -t host sudo ...`            | `exec` (`-t`)                                                                                                |
| `ssh host bash -s < script.sh`                      | `script <target> <file> [args...]`                                                                           |
| (is the server reachable?)                          | `check`                                                                                                      |
| `ssh -V`                                            | `version`                                                                                                    |
| `scp file host:/dir`, `scp -r`, `-P`, `-p`          | `scp::upload`, `scp::download`                                                                               |
| `rsync -avz [--delete] -e ssh`                      | `rsync::push`, `rsync::pull` (everything else about rsync: [RSYNC.md](RSYNC.md))                             |
| `sftp host`                                         | `sftp::connect`                                                                                              |
| `ssh -L` / `-R` / `-D`, `-N`, `-f`, `-NnT`          | `tunnel::local`, `tunnel::remote`, `tunnel::socks` (background by default, `--foreground`)                   |
| (existing) tunnel with a key and 7 arguments        | `tunnel::open`, `tunnel::list`, `tunnel::kill`, `tunnel::kill::fzf`                                          |
| `ssh-keygen -t ed25519 ...`                         | (existing) `key::generate`                                                                                   |
| `ssh-copy-id [-i key.pub] host`                     | `key::copy_id`                                                                                               |
| `ssh-keygen -y -f key`                              | `key::public` (`--save`)                                                                                     |
| `ssh-keygen -lf key`                                | `key::fingerprint` (`--md5`)                                                                                 |
| `ssh-keygen -p -f key`, `-c`                        | `key::passphrase`, `key::comment`                                                                            |
| `chmod 700 ~/.ssh; chmod 600 ...`                   | `permission::fix`                                                                                            |
| `eval "$(ssh-agent -s)"`, `ssh-agent -k`            | `agent::start`, `agent::stop`                                                                                |
| `ssh-add`, `-l`, `-L`, `-d`, `-D`, `-t`             | `agent::add` (`--lifetime`, `--keychain`), `agent::list`, `agent::remove`, `agent::clear`, `agent::add::fzf` |
| `ssh-keygen -F`, `-R`, `ssh-keyscan`                | `known_hosts::find`, `known_hosts::remove`, `known_hosts::scan` (`--add`)                                    |
| `~/.ssh/config` `Host` blocks                       | `config::add`, `config::list`, `config::show` (`ssh -G`), `config::remove`, `config::remove::fzf`            |
| pick a host and `ssh` into it                       | `connect::fzf`                                                                                               |
| `ControlMaster`, `ssh -O check` / `exit`            | `config::add --mux`, `mux::check`, `mux::stop`                                                               |

Not wrapped: remote `mv` / `rm` / `chmod` / `df` / `tail -f` (they are `exec`), `tar` over ssh (use `rsync::push`), `sshfs`, the cipher and protocol flags, and server hardening (`sshd_config`), which needs root on the other machine.

## Things worth knowing

- **Aliases.** Every command accepts a `Host` alias of `~/.ssh/config` wherever it wants a host. `config::add web1 10.0.0.5 -u deploy -p 2222 -i ~/.ssh/id_ed25519` turns the first example into `shell::ssh::connect web1`.
- **`config::add` puts the block before `Host *`**, because ssh keeps the first value it finds for an option; a specific host placed after `Host *` would never override it. The file is backed up to `SHELL_SSH_CONFIG_BACKUP_FILE` first and keeps its mode (a new one is created with 600). Patterns, `Match` blocks and `Host` lines naming several aliases are never edited.
- **Scp paths.** A local name such as `backup:2024.tgz` would be read by scp as a host; it is passed as `./backup:2024.tgz`. Remote locations are `[user@]host:path`; IPv6 literals do not fit that form, use an alias.
- **`rsync --delete`** removes files at the destination: the server for `push`, **your machine** for `pull`. Try `--simulate` first.
- **Tunnels** run as `ssh -N -T -f` with `ExitOnForwardFailure=yes`, so a busy port is an error (255), not a silent tunnel that does nothing. A background tunnel shows in `tunnel::list` and is stopped with `tunnel::kill::fzf`.
- **The agent** is started in the current shell: do not run `agent::start` inside `$( ... )` or a pipeline. It does nothing when an agent already answers, so it is safe in a profile.
- **`known_hosts::remove`** is the cure for "REMOTE HOST IDENTIFICATION HAS CHANGED" _after you have checked that the change is legitimate_. `scan --add` trusts what the server answers now; it prints the fingerprints so you can compare them.
- No passphrase is ever taken on the command line.
