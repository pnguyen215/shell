# lib/ssh_key.sh

SSH keys: install on a server, derive the public key, fingerprints, passphrase, comment, and the permissions ssh insists on.

## Overview

Complements lib/ssh.sh (which generates, views, renames and removes key files)
with the other key commands of the SSH cheat sheets. The agent has its own
file (lib/ssh_agent.sh) and so have known_hosts (lib/ssh_known_hosts.sh) and
`~/.ssh/config` (lib/ssh_config.sh).

Things worth knowing:

- No passphrase is ever taken on the command line (it would show up in `ps` and
  in your history): commands that need one let ssh-keygen ask for it.
- `shell::ssh::key::public` and `shell::ssh::key::fingerprint` print data and
  nothing else, so they are safe inside `$( ... )`.
- `shell::ssh::permission::fix` is the answer to "Permissions 0644 for
  '~/.ssh/id_rsa' are too open" and to "Bad owner or permissions on
  ~/.ssh/config": it sets 700 on the directory, 600 on private keys, the
  config and authorized_keys, and 644 on public keys and known_hosts.

## Index

- [shell::ssh::key::copy_id](#shellsshkeycopy_id)
- [shell::ssh::key::public](#shellsshkeypublic)
- [shell::ssh::key::fingerprint](#shellsshkeyfingerprint)
- [shell::ssh::key::passphrase](#shellsshkeypassphrase)
- [shell::ssh::key::comment](#shellsshkeycomment)
- [shell::ssh::permission::fix](#shellsshpermissionfix)

### shell::ssh::key::copy_id

Install your public key on a server (`ssh-copy-id [-i key.pub] [user@]host`).
After this, `ssh host` logs in with the key instead of the password. ssh-copy-id
skips keys the server already has.

#### Example

```bash
shell::ssh::key::copy_id deploy@web1
shell::ssh::key::copy_id -i ~/.ssh/id_ed25519.pub -p 2222 deploy@web1
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-i** | **--identity \<file\>**

  The key to install (default: the agent's keys, or ~/.ssh/id\_\*.pub).

- **-p** | **--port \<n\>**

  Server port.

#### Arguments

- **$1** (string): The target.

#### Exit codes

- **0**: Success.
- **2**: Unknown option, no target, or an unsafe argument.
- **3**: ssh-copy-id, or the key given with -i, is missing.
- N Exit status of ssh-copy-id.

#### See also

- [shell::ssh::cmd](#shellsshcmd)
- [shell::ssh::key::generate](#shellsshkeygenerate)

### shell::ssh::key::public

Print the public key of a private key (`ssh-keygen -y -f key`).
Handy when the `.pub` file is lost. With `--save` the result is written to
`<key>.pub` (mode 644) instead of printed; an existing file is kept unless you
add `--force`. ssh-keygen asks for the passphrase when the key has one.

#### Example

```bash
shell::ssh::key::public ~/.ssh/id_ed25519
shell::ssh::key::public --save ~/.ssh/id_ed25519
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-s** | **--save**

  Write `<key>.pub` instead of printing.

- **--force**

  Overwrite an existing `<key>.pub` (with --save).

#### Arguments

- **$1** (string): The private key file.

#### Exit codes

- **0**: Success.
- **1**: ssh-keygen failed (wrong passphrase, not a key ...).
- **2**: Unknown option, or no key.
- **3**: ssh-keygen or the key is missing.
- **7**: `<key>.pub` exists and --force was not given.

#### Output on stdout

- The public key line (without --save).

### shell::ssh::key::fingerprint

Show the fingerprint of SSH keys (`ssh-keygen -l -f key`).
Without arguments it covers every public key in `~/.ssh`. The fingerprint is
what to compare with the one a server or GitHub shows. Prints data only, so it
can be used inside `$( ... )`.

#### Example

```bash
shell::ssh::key::fingerprint
shell::ssh::key::fingerprint ~/.ssh/id_ed25519.pub
shell::ssh::key::fingerprint --md5 ~/.ssh/id_rsa.pub
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the commands instead of running them.

- **--md5**

  Show the old MD5 form instead of SHA256.

#### Arguments

- **...** (string): Optional key files (private or public).

#### Exit codes

- **0**: Success.
- **1**: ssh-keygen failed for at least one key.
- **2**: Unknown option.
- **3**: ssh-keygen or a key is missing.
- **8**: No key to show.

#### Output on stdout

- One line per key: bits, fingerprint, comment, type.

### shell::ssh::key::passphrase

Change the passphrase of a private key (`ssh-keygen -p -f key`).
ssh-keygen asks for the old and the new passphrase; an empty new one removes
the protection. Nothing is taken on the command line.

#### Example

```bash
shell::ssh::key::passphrase ~/.ssh/id_ed25519
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): The private key file.

#### Exit codes

- **0**: Success.
- **2**: Unknown option, or no key.
- **3**: ssh-keygen or the key is missing.
- N Exit status of ssh-keygen.

### shell::ssh::key::comment

Change the comment stored in a key (`ssh-keygen -c -C comment -f key`).
The comment is the free text at the end of the public key (often an e-mail).
ssh-keygen asks for the passphrase when the key has one.

#### Example

```bash
shell::ssh::key::comment ~/.ssh/id_ed25519 "alice@work-laptop"
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): The private key file.
- **$2** (string): The new comment.

#### Exit codes

- **0**: Success.
- **2**: Unknown option, missing arguments, or a comment with control characters.
- **3**: ssh-keygen or the key is missing.
- N Exit status of ssh-keygen.

### shell::ssh::permission::fix

Set the permissions ssh insists on for `~/.ssh` (700 / 600 / 644).
Directory 700 (and `sockets` 700), private keys, `config`, `authorized_keys`
600, public keys and `known_hosts` 644. Only what differs is changed and
reported; links are skipped. Nothing is made more open than it was asked.

#### Example

```bash
shell::ssh::permission::fix
shell::ssh::permission::fix -n
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the chmod commands instead of running them.

- **-d** | **--dir \<path\>**

  Another SSH directory (default: SHELL_SSH_DIR).

#### Exit codes

- **0**: Done (also when nothing needed changing).
- **2**: Unknown option.
- **3**: The SSH directory does not exist.

#### See also

- [shell::ssh::key::candidates](#shellsshkeycandidates)
