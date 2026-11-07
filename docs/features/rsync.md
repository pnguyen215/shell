# rsync

`shell::rsync::*` wraps the commands of the rsync cheat sheets ([Linuxize](https://linuxize.com/cheatsheet/rsync/), [Dev Cheatsheets](https://michaelcurrin.github.io/dev-cheatsheets/cheatsheets/shell/commands/rsync.html), [DeployHQ](https://www.deployhq.com/cheatsheets/rsync), [ditig](https://www.ditig.com/rsync-cheat-sheet)), grouped by what you want to do rather than by flag. `shell::ssh::rsync::push` and `pull` stay the short form for `rsync -avz -e ssh`.

Every function has `-h` and `-n | --dry-run` (print the command, copy it to the clipboard, run nothing; rsync need not be installed). Options go **before** the locations. Nothing is run through `eval`, and a location, port, jump list or pattern that could be taken for an option is refused before rsync sees it. The exit status is rsync's own.

## Commands

| Function  | What it does                                                     | Default flags                                   |
| --------- | ---------------------------------------------------------------- | ----------------------------------------------- |
| `sync`    | copy what changed, anywhere to anywhere                          | `-a`                                            |
| `mirror`  | make the destination identical to the source (guard rails below) | `-a --delete-after --max-delete=N`              |
| `move`    | copy, then remove the files from the source                      | `-a --remove-source-files`                      |
| `resume`  | copy over a bad link: keep unfinished files, time out, retry     | `-a --partial-dir=.rsync-partial --timeout=120` |
| `diff`    | show what a sync would change, changing nothing                  | `-a -n -i --delete`                             |
| `list`    | list a source without copying                                    | `--list-only`                                   |
| `version` | print the rsync version                                          | `rsync --version`                               |

A location is a path, `[user@]host:path` (ssh), `[user@]host::module` or `rsync://[user@]host[:port]/module` (daemon). The transport is picked from the locations; both sides cannot be remote.

## One vocabulary

| Option                                                   | rsync                                             | Commands                            |
| -------------------------------------------------------- | ------------------------------------------------- | ----------------------------------- |
| `-n, --dry-run`                                          | (prints the command)                              | all                                 |
| `--simulate`                                             | `-n`                                              | sync mirror move resume             |
| `-v -q --human`                                          | `-v -q -h`                                        | all                                 |
| `-p -i -J -F -o --batch --accept-new`                    | passed through `-e "ssh ..."`                     | all (`-p` is `--port` for a daemon) |
| `--sudo`, `--rsync-path <cmd>`                           | `--rsync-path="sudo rsync"`                       | all                                 |
| `-z --bwlimit --timeout --chmod`                         | same                                              | sync mirror move resume             |
| `--partial --partial-dir --append`                       | `--partial`, `--partial-dir=`, `--append-verify`  | sync mirror move resume             |
| `--progress --total-progress --stats --itemize`          | `--progress`, `--info=progress2`, `--stats`, `-i` | sync mirror move resume             |
| `--exclude --include --exclude-from`                     | same, **in the order typed**                      | sync mirror move resume diff        |
| `-c -u --ignore-existing -L -H --omit-dir-times`         | same                                              | sync mirror move resume diff        |
| `--delete`                                               | `--delete-after`                                  | sync resume                         |
| `--max-delete <n>`                                       | `--max-delete=`                                   | sync resume mirror                  |
| `--allow-empty` / `--no-delete` / `--retries <n>` / `-r` | -                                                 | mirror / diff / resume / list       |

An option a command does not take is refused (`diff -z`, `move --delete`), not silently ignored.

## Cheat sheet → function

| Cheat sheet                                                      | Function                                                    |
| ---------------------------------------------------------------- | ----------------------------------------------------------- |
| `rsync -a src/ dest/`, `src dest/`                               | `sync` (mind the trailing `/`)                              |
| `rsync -a src/ user@host:/path/`, `host:/path/ dest/`            | `sync`                                                      |
| `-e "ssh -p 2222 -i key"`                                        | `sync -p 2222 -i key`                                       |
| `-avzP`                                                          | `sync -z --partial --progress`, or `resume`                 |
| `--dry-run`                                                      | `--simulate` (`-n` prints the command)                      |
| `--exclude`, `--exclude-from`, `--include='*.jpg' --exclude='*'` | `--exclude`, `--exclude-from`, `--include` then `--exclude` |
| `--delete`, `--delete-after --max-delete=N`                      | `sync --delete`, `mirror`                                   |
| `-avn --delete --itemize-changes a/ b/`                          | `diff`                                                      |
| `--remove-source-files`                                          | `move`                                                      |
| `--partial-dir`, `--timeout`, retry loop with backoff            | `resume`                                                    |
| `--partial --append-verify`                                      | `resume --append`                                           |
| `--bwlimit=5m`, `--info=progress2`, `--stats`, `-i`              | `--bwlimit`, `--total-progress`, `--stats`, `--itemize`     |
| `--chmod`, `-H`, `-L`, `--omit-dir-times`                        | same names                                                  |
| `--rsync-path="sudo rsync"`                                      | `--sudo`                                                    |
| `rsync rsync://host/module/ ./`, `rsync rsync://host/`           | `sync`, `list`                                              |
| `rsync --version`                                                | `version`                                                   |

Not wrapped: `--delete-excluded`, `--link-dest`, `--backup-dir`, `--files-from`, ACL/xattr flags, and the atomic-release pattern (rsync into a fresh directory, then `ln -sfn`; the second step is `shell::ssh::exec`). Use plain `rsync` for those.

## Things worth knowing

- **Trailing `/`.** `src/` copies the contents, `src` copies the directory itself. `mirror` always copies the contents (it adds the `/`). `sync --delete` on a directory without `/` warns, because it removes everything else in the destination.
- **`--delete` is `--delete-after`.** Nothing is removed until the transfer worked, so a killed rsync leaves the destination as it was, not half emptied.
- **`--max-delete` is a brake, not a preview.** rsync deletes up to the limit and then stops with status 25; the files already removed stay removed. (Some cheat sheets say it aborts before touching anything; it does not.) Run `diff` first. `mirror` also refuses an empty or missing local source and the destination `/`; `--allow-empty` overrides the first.
- **`--partial-dir` and `--append` exclude each other** (rsync: `--append cannot be used with --partial-dir`). `resume` keeps unfinished files in a hidden directory by default, so a half file never shows under its final name; `--append` resumes huge, growing files by appending after checking what is there.
- **`resume` retries only network failures**: rsync status 10, 12, 30, 35 and 255, up to `--retries` times, waiting longer each time. Anything else (a usage error, status 23 ...) is returned at once.
- **Status codes.** 23 (some files not transferred) and 24 (files vanished) are partial successes and get a hint; 25 is the `--max-delete` limit.
- **`--timeout` is rsync's I/O timeout** (no data for that long: give up), not the ssh connect timeout; use `-o ConnectTimeout=<s>` for that. This differs from `shell::ssh::*`, where `--timeout` is the connect timeout.
- **Compression is off** unless you ask for `-z`: it helps on a slow link and wastes CPU on a LAN, on a local copy and on already compressed files.
- **`--sudo`** runs rsync as root on the server and needs `sudo` without a password. There is no implicit sudo.
- **Versions.** `--total-progress` needs rsync 3.1 and `--append` rsync 3.0. macOS ships 2.6.9 or openrsync: `brew install rsync` for a current one. `shell::rsync::version` shows what you have.
- **Local names with a colon.** `backup:2024` is read as a host, as rsync reads it; write `./backup:2024`.

## Tunables

`src/constant/defaults.sh`, overridable from the environment:

| Variable                  | Default          | Used by                                       |
| ------------------------- | ---------------- | --------------------------------------------- |
| `SHELL_RSYNC_MAX_DELETE`  | `1000`           | `mirror`: deletion limit                      |
| `SHELL_RSYNC_TIMEOUT`     | `120`            | `resume`: seconds without data                |
| `SHELL_RSYNC_PARTIAL_DIR` | `.rsync-partial` | `resume`: where unfinished files are kept     |
| `SHELL_RSYNC_RETRIES`     | `5`              | `resume`: retries after a network failure     |
| `SHELL_RSYNC_RETRY_DELAY` | `10`             | `resume`: retry N waits N × this many seconds |

## Aliases

`srsy` sync, `srmi` mirror, `srmv` move, `srrs` resume, `srdf` diff; `srsy-n`, `srmi-n`, `srmv-n` and `srrs-n` print the command instead of running it.
