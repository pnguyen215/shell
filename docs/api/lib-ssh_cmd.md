# lib/ssh_cmd.sh

SSH client commands (connect, exec, script, check, multiplexing) and the engine shared by every ssh / scp / sftp / rsync wrapper.

## Overview

One documented function per command of the SSH cheat sheets, each with a
`-n | --dry-run` switch and argument validation, so that
`ssh -p 2222 -i key user@host` is `shell::ssh::connect -p 2222 -i key user@host`.

The commands live in four files, all built on `shell::ssh::cmd` below:

- lib/ssh_cmd.sh connect, exec, script, check, version, mux::check, mux::stop
- lib/ssh_transfer.sh scp::upload, scp::download, rsync::push, rsync::pull, sftp::connect
- lib/ssh_tunnel.sh tunnel::local (-L), tunnel::remote (-R), tunnel::socks (-D)
- lib/ssh_key.sh key::copy_id, key::public, key::fingerprint ... (and ssh_agent.sh,
  ssh_known_hosts.sh, ssh_config.sh for the agent, known_hosts and ~/.ssh/config)

Things worth knowing:

- One vocabulary for every command: `-p | --port`, `-i | --identity`,
  `-J | --jump`, `-F | --config`, `-o | --option`. The letter each program
  really uses is chosen for you (scp and sftp want `-P`, rsync gets it
  through `-e "ssh ..."`), so you never have to remember it.
- Options go **before** the target. For `connect` and `exec`, everything
  after the target is the remote command, passed on untouched.
- Nothing is run through `eval`: arguments reach the program as they are,
  so spaces and quotes are safe. A target, a port, a jump list or a
  forwarding spec that could be mistaken for an option is refused up front.
- `-n | --dry-run` prints the command (quoted so that it can be pasted) and
  copies it to the clipboard. It never needs the program to be installed.
- The exit status is the program's own (255 when ssh cannot connect).
- The safe options are preferred over the famous unsafe ones: there is
  `--accept-new` (trust a host the first time only) and no
  `StrictHostKeyChecking=no` shortcut.

## Index

- [shell::ssh::connect](#shellsshconnect)
- [shell::ssh::exec](#shellsshexec)
- [shell::ssh::script](#shellsshscript)
- [shell::ssh::check](#shellsshcheck)
- [shell::ssh::version](#shellsshversion)
- [shell::ssh::mux::check](#shellsshmuxcheck)
- [shell::ssh::mux::stop](#shellsshmuxstop)

### shell::ssh::connect

Open an SSH session, or run one command on the server (`ssh [user@]host [command]`).
The target is `user@host`, `host`, or a `Host` alias of `~/.ssh/config`. Words
after the target are the remote command; like ssh, they are joined with spaces
and parsed by the remote shell, so give one quoted string when you need a
pipe or a redirect.

#### Example

```bash
shell::ssh::connect deploy@10.0.0.5
shell::ssh::connect -p 2222 -i ~/.ssh/id_ed25519 deploy@10.0.0.5 uptime
shell::ssh::connect -J bastion deploy@10.0.0.5
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-p** | **--port \<n\>**

  Server port.

- **-i** | **--identity \<file\>**

  Private key.

- **-J** | **--jump \<hosts\>**

  Jump host(s).

#### Arguments

- **$1** (string): The target.
- **...** (string): Optional remote command.

#### Exit codes

- **0**: Success.
- **2**: Unknown option, no target, or an unsafe argument.
- **3**: ssh, or a file given with -i or -F, is missing.
- N Exit status of ssh (**255**: when it cannot connect).

#### See also

- [shell::ssh::cmd](#shellsshcmd)
- [shell::ssh::connect::fzf](#shellsshconnectfzf)

### shell::ssh::exec

Run a command on the server and return (`ssh [user@]host command`).
Same as `shell::ssh::connect` with a command, except that the command is
mandatory. Add `-t` for commands that need a terminal, such as `sudo`.

#### Example

```bash
shell::ssh::exec deploy@web1 'df -h'
shell::ssh::exec -t deploy@web1 sudo systemctl restart nginx
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-t** | **--tty**

  Force a terminal.

#### Arguments

- **$1** (string): The target.
- **...** (string): The remote command (one or more words).

#### Exit codes

- **0**: Success.
- **2**: Unknown option, no target or no command, or an unsafe argument.
- **3**: ssh, or a file given with -i or -F, is missing.
- N Exit status of the remote command (**255**: when ssh cannot connect).

#### See also

- [shell::ssh::cmd](#shellsshcmd)

### shell::ssh::script

Run a local script on the server (`ssh host bash -s < script.sh`).
The file is streamed to `bash -s` on the server, so nothing is copied there.
Extra arguments become the script's `$1`, `$2` ... and are quoted for you. The
server needs `bash`.

#### Example

```bash
shell::ssh::script deploy@web1 ./bootstrap.sh
shell::ssh::script deploy@web1 ./backup.sh daily "my database"
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): The target.
- **$2** (string): The local script.
- **...** (string): Optional arguments for the script.

#### Exit codes

- **0**: Success.
- **2**: Unknown option, missing arguments, or an unsafe argument.
- **3**: ssh or the script is missing.
- N Exit status of the script (**255**: when ssh cannot connect).

#### See also

- [shell::ssh::cmd](#shellsshcmd)

### shell::ssh::check

Test that a server can be reached and accepts your login.
Runs `true` on the server in batch mode (no password prompt) and says whether
it worked. The wait is `SHELL_SSH_CHECK_TIMEOUT` seconds unless you pass
`--timeout`. A host never seen before fails in batch mode: add `--accept-new`.

#### Example

```bash
shell::ssh::check deploy@web1
shell::ssh::check --accept-new -p 2222 deploy@web1
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): The target.

#### Exit codes

- **0**: The server accepted the login.
- **1**: It could not be reached, or refused the login.
- **2**: Unknown option, no target, or an unsafe argument.
- **3**: ssh is missing.

#### See also

- [shell::ssh::cmd](#shellsshcmd)

### shell::ssh::version

Print the version of the installed OpenSSH client (`ssh -V`).

#### Example

```bash
shell::ssh::version
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Exit codes

- **0**: Success.
- **3**: ssh is not installed.

#### Output on stdout

- The version line (ssh prints it on stderr; it is brought to stdout).

### shell::ssh::mux::check

Tell whether the shared connection to a host is alive (`ssh -O check`).
It looks at the control socket your ssh config names (`ControlPath`); write
one with `shell::ssh::config::add --mux`.

#### Example

```bash
shell::ssh::mux::check web1
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): The target (the alias or the user@host the connection was opened with).

#### Exit codes

- **0**: The master connection is running.
- **2**: Unknown option, no target, or an unsafe argument.
- **3**: ssh is missing.
- N Exit status of ssh (**255**: when there is no master connection).

#### See also

- [shell::ssh::mux::stop](#shellsshmuxstop)
- [shell::ssh::config::add](#shellsshconfigadd)

### shell::ssh::mux::stop

Close the shared connection to a host (`ssh -O exit`).
Sessions already open end with it; the next `ssh` to the host starts a new master.

#### Example

```bash
shell::ssh::mux::stop web1
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): The target (the alias or the user@host the connection was opened with).

#### Exit codes

- **0**: The master connection was told to exit.
- **2**: Unknown option, no target, or an unsafe argument.
- **3**: ssh is missing.
- N Exit status of ssh (**255**: when there is no master connection).

#### See also

- [shell::ssh::mux::check](#shellsshmuxcheck)
