# lib/rsync.sh

rsync commands for local, ssh and daemon transfers: sync, mirror, move, resume, diff, list.

## Overview

The commands of the rsync cheat sheets ([Linuxize](https://linuxize.com/cheatsheet/rsync/),
[Dev Cheatsheets](https://michaelcurrin.github.io/dev-cheatsheets/cheatsheets/shell/commands/rsync.html),
[DeployHQ](https://www.deployhq.com/cheatsheets/rsync),
[ditig](https://www.ditig.com/rsync-cheat-sheet)), grouped by what you want to do instead of
by flag, each with a `-n | --dry-run` switch and argument validation:

- `shell::rsync::sync` copy what changed (`rsync -a src/ dest/`), anywhere to anywhere
- `shell::rsync::mirror` make the destination identical to the source, with guard rails
- `shell::rsync::move` copy, then remove the files from the source
- `shell::rsync::resume` copy over a bad link: keep unfinished files, time out, retry
- `shell::rsync::diff` show what a sync would change, changing nothing
- `shell::rsync::list` list a source without copying (`--list-only`)
- `shell::rsync::version` print the rsync version

`shell::ssh::rsync::push` and `shell::ssh::rsync::pull` (lib/ssh_transfer.sh) stay the
short form for `rsync -avz -e ssh`; this file is for everything else.

Things worth knowing:

- A location is a path, `[user@]host:path` (ssh), `[user@]host::module` or
  `rsync://[user@]host[:port]/module` (daemon), written as rsync writes them. Both sides
  cannot be remote. A local path with a colon before any slash would be read as a host:
  write it `./backup:2024`.
- Trailing `/` on a source: `src/` copies the contents, `src` copies the directory
  itself. `mirror` always copies the contents.
- Options go **before** the locations. Nothing is run through `eval`: arguments reach
  rsync as they are, so spaces and quotes are safe, and a location, port or pattern that
  could be taken for an option is refused up front.
- `-n | --dry-run` prints the command (quoted so it can be pasted) and copies it to the
  clipboard; rsync need not be installed. rsync's own `-n` is `--simulate`.
- The ssh options are those of the other ssh commands: `-p -i -J -F -o --batch
--accept-new` (rsync receives them through `-e "ssh ..."`). For a daemon, `-p` is
  `--port`. `--sudo` runs rsync as root on the server (`--rsync-path="sudo rsync"`).
- `--timeout` is rsync's I/O timeout (no data for that long: give up), not the ssh
  connect timeout; use `-o ConnectTimeout=<s>` for that.
- Compression is off unless you ask for `-z`: it helps on a slow link and wastes CPU on a
  LAN, on a local copy and on files that are already compressed.
- `--delete` is rsync's `--delete-after`: nothing is removed until the transfer worked, so
  a killed rsync leaves the destination as it was, not half emptied.
- The exit status is rsync's own. 23 (some files not transferred) and 24 (files vanished)
  are partial successes; 25 means the `--max-delete` limit stopped the deletions.
- `--total-progress` needs rsync 3.1 and `--append` rsync 3.0. macOS ships an old (or
  openrsync) build: `brew install rsync` for a current one.

## Index

- [shell::rsync::sync](#shellrsyncsync)
- [shell::rsync::mirror](#shellrsyncmirror)
- [shell::rsync::move](#shellrsyncmove)
- [shell::rsync::resume](#shellrsyncresume)
- [shell::rsync::diff](#shellrsyncdiff)
- [shell::rsync::list](#shellrsynclist)
- [shell::rsync::version](#shellrsyncversion)

### shell::rsync::sync

Copy what changed from one place to another (`rsync -a source/ dest/`).
Works for local paths, `[user@]host:path` over ssh and rsync daemons, and picks the
transport from the locations. Nothing is deleted, compressed or limited unless you ask.
Mind the trailing `/` of the source (see the file description) and `--delete`.

#### Example

```bash
shell::rsync::sync ./site/ /mnt/backup/site/
shell::rsync::sync -z --exclude node_modules --exclude .git -p 2222 ./app/ deploy@web1:/srv/app/
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--simulate**

  Let rsync show what it would do, changing nothing.

- **--delete**

  Delete at the destination what is not at the source (`--delete-after`).

- **--exclude \<pattern\>**

  Skip matching files (repeatable).

- **-z** | **--compress**

  Compress the data on the wire.

- **--bwlimit \<rate\>**

  Limit the speed (`5m`, `10240`).

- **-p** | **--port \<n\>**

  Server port (ssh) or daemon port.

#### Arguments

- **...** (string): One or more sources, then the destination.

#### Exit codes

- **0**: Success.
- **2**: Unknown option, missing arguments, or an unsafe argument.
- **3**: rsync, ssh, or a local source, is missing.
- N Exit status of rsync.

#### See also

- [shell::rsync::mirror](#shellrsyncmirror)
- [shell::rsync::diff](#shellrsyncdiff)
- [shell::ssh::rsync::push](#shellsshrsyncpush)

### shell::rsync::mirror

Make the destination identical to the source (`rsync -a --delete-after --max-delete=N`).
The source is a directory whose **contents** are mirrored (a trailing `/` is added).
Guard rails: nothing is deleted before the transfer succeeded; at most
`SHELL_RSYNC_MAX_DELETE` files are deleted (rsync then stops with status 25, and
what it already removed stays removed); an empty or missing local source and the
destination `/` are refused. Look at `shell::rsync::diff` first the first time.

#### Example

```bash
shell::rsync::mirror --simulate ./build deploy@web1:/var/www/releases/new
shell::rsync::mirror --max-delete 50 ./photos /mnt/backup/photos
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--simulate**

  Let rsync show what it would do, changing nothing.

- **--max-delete \<n\>**

  Delete at most n files.

- **--allow-empty**

  Mirror an empty source too (it empties the destination).

- **--exclude \<pattern\>**

  Skip matching files (repeatable); they are not deleted either.

#### Arguments

- **$1** (string): The source directory.
- **$2** (string): The destination.

#### Exit codes

- **0**: Success.
- **2**: Unknown option, wrong arguments, an unsafe argument, or a source that is not a directory.
- **3**: rsync, ssh, or the local source, is missing.
- **8**: The local source is empty.
- **25**: The deletion limit was reached.
- N Exit status of rsync.

#### See also

- [shell::rsync::diff](#shellrsyncdiff)

### shell::rsync::move

Move files: copy them, then remove them from the source (`rsync -a --remove-source-files`).
Only files are removed after they arrived intact; the empty directories stay at the source.
`--delete` is not available here.

#### Example

```bash
shell::rsync::move ./incoming/ /mnt/archive/
shell::rsync::move --simulate --exclude '*.part' ./downloads/ nas:/volume1/inbox/
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--simulate**

  Let rsync show what it would do, changing nothing.

- **--exclude \<pattern\>**

  Skip matching files (repeatable).

#### Arguments

- **...** (string): One or more sources, then the destination.

#### Exit codes

- **0**: Success.
- **2**: Unknown option, missing arguments, or an unsafe argument.
- **3**: rsync, ssh, or a local source, is missing.
- N Exit status of rsync.

#### See also

- [shell::rsync::sync](#shellrsyncsync)

### shell::rsync::resume

Copy over an unreliable link and pick up where it stopped.
Unfinished files are kept in a hidden directory below the destination
(`--partial-dir`, `SHELL_RSYNC_PARTIAL_DIR`), so a half file never shows under its
final name; `--timeout` (`SHELL_RSYNC_TIMEOUT`) ends a dead connection; and when rsync
stops for a network reason (status 10, 12, 30, 35 or 255) it is started again, up to
`--retries` times (`SHELL_RSYNC_RETRIES`), waiting longer each time. Any other failure is
not retried. `--append` resumes huge files by appending instead (rsync cannot combine it
with a partial directory); it trusts that the file only grows.

#### Example

```bash
shell::rsync::resume --total-progress ./backup.tar.gz deploy@web1:/srv/backups/
shell::rsync::resume --retries 10 --bwlimit 2m -p 2222 ./build/ deploy@web1:/srv/app/
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--retries \<n\>**

  Start again up to n times after a network failure.

- **--timeout \<sec\>**

  Give up a stalled connection after this long.

- **--append**

  Resume by appending (rsync 3.0).

- **--total-progress**

  One progress line for the whole transfer (rsync 3.1).

#### Arguments

- **...** (string): One or more sources, then the destination.

#### Exit codes

- **0**: Success.
- **2**: Unknown option, missing arguments, or an unsafe argument.
- **3**: rsync, ssh, or a local source, is missing.
- N Exit status of the last rsync run.

#### See also

- [shell::rsync::sync](#shellrsyncsync)

### shell::rsync::diff

Show what a sync would change, changing nothing (`rsync -a -n -i --delete`).
One line per difference, as rsync itemizes it: `>f+++++++++` a new file, `>f.st......`
a file whose size or time differs, `.d..t......` a directory whose time differs,
`*deleting` a file that exists only at the destination. The output is rsync's own, so
it can be piped. Use it before a `mirror` or a `--delete`. Files that exist only at the
destination are listed as deletions; `--no-delete` leaves them out.

#### Example

```bash
shell::rsync::diff ./build/ deploy@web1:/var/www/current/
shell::rsync::diff --no-delete --exclude .git ./a/ ./b/
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--no-delete**

  Do not report files that exist only at the destination.

- **-c** | **--checksum**

  Compare checksums, not size and time (slow).

- **--exclude \<pattern\>**

  Skip matching files (repeatable).

#### Arguments

- **$1** (string): The source.
- **$2** (string): The destination.

#### Exit codes

- **0**: Success (whether or not there are differences).
- **2**: Unknown option, wrong arguments, or an unsafe argument.
- **3**: rsync, ssh, or a local source, is missing.
- N Exit status of rsync.

#### See also

- [shell::rsync::mirror](#shellrsyncmirror)

### shell::rsync::list

List a source without copying anything (`rsync --list-only`).
Works on local paths, `[user@]host:path` and daemons; `rsync://host/` lists the modules
of a daemon. Add `-r` to go into directories.

#### Example

```bash
shell::rsync::list deploy@web1:/var/www/
shell::rsync::list -r --human rsync://mirror.example.com/pub/
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-r** | **--recursive**

  Go into directories.

- **--human**

  Print sizes in a readable form.

#### Arguments

- **$1** (string): The location to list.

#### Exit codes

- **0**: Success.
- **2**: Unknown option, no location, or an unsafe argument.
- **3**: rsync or ssh is missing, or the local path does not exist.
- N Exit status of rsync.

### shell::rsync::version

Print the version of the installed rsync (`rsync --version`, first line).
Several options depend on it: `--total-progress` needs 3.1, `--append` needs 3.0.

#### Example

```bash
shell::rsync::version
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Exit codes

- **0**: Success.
- **3**: rsync is not installed.

#### Output on stdout

- The version line.
