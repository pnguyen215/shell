# lib/ssh_transfer.sh

Copy and sync files over SSH: scp, rsync and sftp.

## Overview

`shell::ssh::scp::upload` and `shell::ssh::scp::download` are `scp`,
`shell::ssh::rsync::push` and `shell::ssh::rsync::pull` are `rsync -avz -e ssh`,
and `shell::ssh::sftp::connect` is an interactive `sftp`. They share the
options of the other ssh commands (`-p`, `-i`, `-J`, `-F`, `-o` ...) and are
run by the engine in lib/ssh_cmd.sh.

Things worth knowing:

- A remote location is `[user@]host:path`, written exactly as scp and rsync
  write it. The host is checked like any ssh target; IPv6 literals do not fit
  that form, use an alias of `~/.ssh/config`.
- A local path such as `backup:2024.tgz` would be read by scp as "file 2024.tgz
  on host backup"; it is passed as `./backup:2024.tgz`.
- Local sources must exist (unless this is a dry run). Several downloads need
  an existing local directory as destination.
- rsync follows its own rule about a trailing `/` on the source: `src/` copies
  the contents, `src` copies the directory itself.
- `--delete` removes files at the destination (the server for `push`, **your
  machine** for `pull`). Try it first with `--simulate`, or with `-n`.
- Recent scp (OpenSSH 9) talks the sftp protocol and needs no quoting for a
  remote path with spaces; older scp passes it to a remote shell.

## Index

- [shell::ssh::scp::upload](#shellsshscpupload)
- [shell::ssh::scp::download](#shellsshscpdownload)
- [shell::ssh::rsync::push](#shellsshrsyncpush)
- [shell::ssh::rsync::pull](#shellsshrsyncpull)
- [shell::ssh::sftp::connect](#shellsshsftpconnect)

### shell::ssh::scp::upload

Copy local files or directories to a server (`scp file user@host:/path`).
The last argument is the destination, as `[user@]host:path`. Use `-r` for a
directory.

#### Example

```bash
shell::ssh::scp::upload notes.txt deploy@web1:/home/deploy/
shell::ssh::scp::upload -r -p 2222 ./site deploy@web1:/var/www
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-r** | **--recursive**

  Copy directories recursively.

- **-p** | **--port \<n\>**

  Server port (scp -P).

- **-i** | **--identity \<file\>**

  Private key.

#### Arguments

- **...** (string): One or more local paths, then the remote destination.

#### Exit codes

- **0**: Success.
- **2**: Unknown option, missing arguments, or an unsafe argument.
- **3**: scp, or a local source, is missing.
- N Exit status of scp.

#### See also

- [shell::ssh::cmd](#shellsshcmd)
- [shell::ssh::rsync::push](#shellsshrsyncpush)

### shell::ssh::scp::download

Copy files or directories from a server to this machine (`scp user@host:/path dest/`).
The last argument is the local destination; the others are remote locations
written `[user@]host:path`. Use `-r` for a directory. With several sources
the destination must be an existing directory.

#### Example

```bash
shell::ssh::scp::download deploy@web1:/var/log/app.log .
shell::ssh::scp::download -r deploy@web1:/etc/nginx ./backup/
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-r** | **--recursive**

  Copy directories recursively.

- **-p** | **--port \<n\>**

  Server port (scp -P).

- **-i** | **--identity \<file\>**

  Private key.

#### Arguments

- **...** (string): One or more remote locations, then the local destination.

#### Exit codes

- **0**: Success.
- **2**: Unknown option, missing arguments, or an unsafe argument.
- **3**: scp is missing.
- N Exit status of scp.

#### See also

- [shell::ssh::cmd](#shellsshcmd)
- [shell::ssh::rsync::pull](#shellsshrsyncpull)

### shell::ssh::rsync::push

Sync local files to a server (`rsync -avz -e ssh src user@host:dst`).
Only what changed is sent, compressed. Mind the trailing `/` of the source
(see the file description) and `--delete`, which removes files on the server.

#### Example

```bash
shell::ssh::rsync::push ./site/ deploy@web1:/var/www/site/
shell::ssh::rsync::push --delete --simulate --exclude .git ./site/ deploy@web1:/var/www/site/
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--delete**

  Delete files on the server that are not here.

- **--exclude \<pattern\>**

  Skip matching files (repeatable).

- **--simulate**

  Let rsync show what it would do, changing nothing.

#### Arguments

- **...** (string): One or more local paths, then the remote destination.

#### Exit codes

- **0**: Success.
- **2**: Unknown option, missing arguments, or an unsafe argument.
- **3**: rsync, ssh, or a local source, is missing.
- N Exit status of rsync.

#### See also

- [shell::ssh::cmd](#shellsshcmd)
- [shell::ssh::rsync::pull](#shellsshrsyncpull)

### shell::ssh::rsync::pull

Sync files from a server to this machine (`rsync -avz -e ssh user@host:src dst`).
Only what changed is fetched, compressed. `--delete` removes files **on this
machine** that the server does not have: try it with `--simulate` first.

#### Example

```bash
shell::ssh::rsync::pull deploy@web1:/var/www/site/ ./site/
shell::ssh::rsync::pull --progress -p 2222 deploy@web1:/var/backups/ ./backups/
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--delete**

  Delete local files that are not on the server.

- **--exclude \<pattern\>**

  Skip matching files (repeatable).

- **--simulate**

  Let rsync show what it would do, changing nothing.

#### Arguments

- **...** (string): One or more remote locations, then the local destination.

#### Exit codes

- **0**: Success.
- **2**: Unknown option, missing arguments, or an unsafe argument.
- **3**: rsync or ssh is missing.
- N Exit status of rsync.

#### See also

- [shell::ssh::cmd](#shellsshcmd)
- [shell::ssh::rsync::push](#shellsshrsyncpush)

### shell::ssh::sftp::connect

Open an interactive SFTP session (`sftp [user@]host`).
Inside the session `get` and `put` move files, `ls cd pwd` browse the server
and `lls lcd lpwd` this machine.

#### Example

```bash
shell::ssh::sftp::connect deploy@web1
shell::ssh::sftp::connect -p 2222 deploy@web1
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-p** | **--port \<n\>**

  Server port (sftp -P).

- **-i** | **--identity \<file\>**

  Private key.

#### Arguments

- **$1** (string): The target.

#### Exit codes

- **0**: Success.
- **2**: Unknown option, no target, or an unsafe argument.
- **3**: sftp is missing.
- N Exit status of sftp.

#### See also

- [shell::ssh::cmd](#shellsshcmd)
