# lib/ssh_tunnel.sh

SSH port forwarding: local (-L), remote (-R) and SOCKS (-D), by host or alias.

## Overview

Complements `shell::ssh::tunnel::open` (lib/ssh.sh), which builds one `-L` tunnel
from seven fixed arguments, with these three that take any target (user@host or
an alias of `~/.ssh/config`, jump hosts included) and the same options as the
other ssh commands.

Things worth knowing:

- The tunnel runs as `ssh -N -T -f ...`: no remote command, no terminal, and ssh
  goes to the background once the forward is established. `--foreground` keeps it
  in this terminal (Ctrl-C stops it).
- `ExitOnForwardFailure=yes` makes ssh fail at once when it cannot bind the port,
  instead of staying connected without a tunnel; `ServerAliveInterval` and
  `ServerAliveCountMax` (SHELL_SSH_KEEPALIVE_INTERVAL, SHELL_SSH_KEEPALIVE_COUNT)
  end it when the link dies. `--keepalive` overrides the interval.
- A background tunnel shows up in `shell::ssh::tunnel::list` and is stopped with
  `shell::ssh::tunnel::kill` or `shell::ssh::tunnel::kill::fzf`.
- Forwards bind to 127.0.0.1 unless the spec starts with a bind address
  (`0.0.0.0:8080:host:80` opens it to your network: be sure you want that). A
  remote bind other than localhost also needs `GatewayPorts` on the server.
- A spec can end in a Unix socket path instead of `host:port`
  (`3307:/var/run/mysqld/mysqld.sock`).

## Index

- [shell::ssh::tunnel::local](#shellsshtunnellocal)
- [shell::ssh::tunnel::remote](#shellsshtunnelremote)
- [shell::ssh::tunnel::socks](#shellsshtunnelsocks)

### shell::ssh::tunnel::local

Forward a local port to a service the server can reach (`ssh -L`).
`localhost:<port>` on this machine becomes the entry to `host:hostport` as seen
from the server (a database, an admin page ...).

#### Example

```bash
shell::ssh::tunnel::local deploy@bastion 5432:db.internal:5432
shell::ssh::tunnel::local -J bastion deploy@app1 3307:127.0.0.1:3306
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--foreground**

  Keep the tunnel in this terminal.

- **--keepalive \<sec\>**

  Keep-alive interval.

#### Arguments

- **$1** (string): The target.
- **$2** (string): The spec: `[bind:]port:host:hostport` or `[bind:]port:/socket`.

#### Exit codes

- **0**: The tunnel is up (or the dry run printed).
- **2**: Unknown option, wrong arguments, or an unsafe argument.
- **3**: ssh is missing.
- N Exit status of ssh (**255**: when it cannot connect or bind).

#### See also

- [shell::ssh::cmd](#shellsshcmd)
- [shell::ssh::tunnel::open](#shellsshtunnelopen)

### shell::ssh::tunnel::remote

Expose a local service on the server (`ssh -R`).
`port` on the server becomes the entry to `host:hostport` as seen from this
machine (a webhook receiver, a dev server to show someone ...).

#### Example

```bash
shell::ssh::tunnel::remote deploy@web1 9090:localhost:3000
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--foreground**

  Keep the tunnel in this terminal.

- **--keepalive \<sec\>**

  Keep-alive interval.

#### Arguments

- **$1** (string): The target.
- **$2** (string): The spec: `[bind:]port:host:hostport` or `[bind:]port:/socket`.

#### Exit codes

- **0**: The tunnel is up (or the dry run printed).
- **2**: Unknown option, wrong arguments, or an unsafe argument.
- **3**: ssh is missing.
- N Exit status of ssh (**255**: when it cannot connect or bind).

#### See also

- [shell::ssh::cmd](#shellsshcmd)

### shell::ssh::tunnel::socks

Start a SOCKS5 proxy that sends its traffic through the server (`ssh -D`).
Point a browser or `curl --socks5-hostname localhost:1080` at it.

#### Example

```bash
shell::ssh::tunnel::socks deploy@web1
shell::ssh::tunnel::socks deploy@web1 1081
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--foreground**

  Keep the tunnel in this terminal.

- **--keepalive \<sec\>**

  Keep-alive interval.

#### Arguments

- **$1** (string): The target.
- **$2** (integer): Local port (default 1080).

#### Exit codes

- **0**: The proxy is up (or the dry run printed).
- **2**: Unknown option, wrong arguments, or an unsafe argument.
- **3**: ssh is missing.
- N Exit status of ssh (**255**: when it cannot connect or bind).

#### See also

- [shell::ssh::cmd](#shellsshcmd)
