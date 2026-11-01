# lib/ssh_known_hosts.sh

The known_hosts file: look a host up, forget it, or learn its keys.

## Overview

`known_hosts` is where ssh remembers the key of every server it has met, so that
it can tell when a server is replaced by an impostor.

Things worth knowing:

- `shell::ssh::known_hosts::remove` is the cure for "WARNING: REMOTE HOST
  IDENTIFICATION HAS CHANGED!" **after you have checked that the change is
  legitimate** (a reinstalled server, a new IP). ssh-keygen keeps the old file
  as `known_hosts.old`.
- A host on a port other than 22 is stored as `[host]:port`; the commands add
  the brackets for you when you pass `-p`.
- `shell::ssh::known_hosts::scan --add` trusts whatever the server answers _right
  now_, which is exactly the "yes" you would type at the first connection. It
  prints the fingerprints so you can compare them with the ones the server owner
  gave you, and never replaces a host that is already known. For unattended
  setups it is a convenience; for anything sensitive compare the fingerprints.
- The file used is `SHELL_SSH_KNOWN_HOSTS_FILE` unless you pass `-f`.

## Index

- [shell::ssh::known_hosts::find](#shellsshknown_hostsfind)
- [shell::ssh::known_hosts::remove](#shellsshknown_hostsremove)
- [shell::ssh::known_hosts::scan](#shellsshknown_hostsscan)

### shell::ssh::known_hosts::find

Look a host up in known_hosts (`ssh-keygen -F host`).
Prints the stored key line(s) when the host is known.

#### Example

```bash
shell::ssh::known_hosts::find github.com
shell::ssh::known_hosts::find -p 2222 10.0.0.5
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-p** | **--port \<n\>**

  The port the host listens on (looked up as `[host]:port`).

- **-f** | **--file \<path\>**

  Another known_hosts file.

#### Arguments

- **$1** (string): The host name or address.

#### Exit codes

- **0**: The host is known.
- **2**: Unknown option, no host, or an invalid host or port.
- **3**: ssh-keygen is missing, or the host is not in the file.

#### Output on stdout

- The stored key line(s).

### shell::ssh::known_hosts::remove

Forget a host (`ssh-keygen -R host`).
Use it after a server was reinstalled or got a new key, and you have checked that
this is legitimate. The previous file is kept as `known_hosts.old`.

#### Example

```bash
shell::ssh::known_hosts::remove 10.0.0.5
shell::ssh::known_hosts::remove -p 2222 web1.example.com
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-p** | **--port \<n\>**

  The port the host listens on (removed as `[host]:port`).

- **-f** | **--file \<path\>**

  Another known_hosts file.

#### Arguments

- **$1** (string): The host name or address.

#### Exit codes

- **0**: The host was removed.
- **2**: Unknown option, no host, or an invalid host or port.
- **3**: ssh-keygen is missing, or the host is not in the file.
- N Exit status of ssh-keygen.

### shell::ssh::known_hosts::scan

Fetch the public keys of servers (`ssh-keyscan host`), and optionally trust them.
Without `--add` the keys are only printed. With `--add` each host that is not yet
in known_hosts gets its keys appended (hashed, as `HashKnownHosts` does), after the
fingerprints are printed for you to check; known hosts are left alone. See the
file description for what that trusts.

#### Example

```bash
shell::ssh::known_hosts::scan github.com
shell::ssh::known_hosts::scan --add -t ed25519 git.example.com
shell::ssh::known_hosts::scan --add -p 2222 10.0.0.5
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the commands instead of running them.

- **-p** | **--port \<n\>**

  The port the servers listen on.

- **-t** | **--type \<list\>**

  Key types to fetch, comma separated (e.g. `ed25519,rsa`).

- **-f** | **--file \<path\>**

  Another known_hosts file (with --add).

- **--add**

  Append the keys of unknown hosts to known_hosts.

#### Arguments

- **...** (string): One or more host names or addresses.

#### Exit codes

- **0**: Success.
- **1**: No key was received from at least one host.
- **2**: Unknown option, no host, or an invalid host, port or type.
- **3**: ssh-keyscan or ssh-keygen is missing.

#### Output on stdout

- The keys, in known_hosts format (without --add).
