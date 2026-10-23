# lib/fs.sh

Portable filesystem helpers (create, copy, move, remove, extract, list, browse).

## Overview

Differences from the previous common.sh implementation:

- No implicit `sudo`. Privilege escalation is opt-in (`--sudo`), because
  creating files under $HOME with sudo leaves them root-owned.
- No implicit `chmod 777`. New files/dirs use the caller's umask, or 600/700
  with `--private` (used for anything holding secrets).
- Destructive operations refuse obviously dangerous targets (`/`, `$HOME`...).
- GNU/BSD (Linux/macOS) differences (`sed -i`, `stat`) are hidden here.

## Index

- [shell::fs::sed_inplace](#shellfssed_inplace)
- [shell::fs::stat](#shellfsstat)
- [shell::fs::mkdir](#shellfsmkdir)
- [shell::fs::touch](#shellfstouch)
- [shell::fs::copy](#shellfscopy)
- [shell::fs::move](#shellfsmove)
- [shell::fs::remove](#shellfsremove)
- [shell::fs::unarchive](#shellfsunarchive)
- [shell::fs::ls](#shellfsls)
- [shell::link::hard](#shelllinkhard)
- [shell::directory::open](#shelldirectoryopen)
- [shell::directory::back](#shelldirectoryback)
- [shell::file::mime](#shellfilemime)
- [shell::encode::file::base64](#shellencodefilebase64)
- [shell::fs::browse](#shellfsbrowse)

### shell::fs::sed_inplace

Edit a file in place with sed, portably.
GNU sed (`sed -i`) and BSD sed (`sed -i ''`) disagree on how the in-place
flag takes its optional suffix. Attaching a suffix directly (`-i.bak`) is
understood by both, so the backup is created and then deleted.

#### Example

```bash
shell::fs::sed_inplace 's/foo/bar/' config.txt
shell::fs::sed_inplace -e '/^#/d' -e 's/ *$//' config.txt
```

#### Arguments

- **...** (string): sed arguments (scripts/options) followed by the file as the LAST argument.

#### Exit codes

- **0**: The file was edited.
- **2**: Fewer than two arguments were given.
- **3**: The target file does not exist.
- N sed's exit status on failure.

### shell::fs::stat

Print one stat attribute of a file, portably.
GNU `stat -c` (Linux) and BSD `stat -f` (macOS) use unrelated format
strings; this hides the difference.

#### Example

```bash
shell::fs::stat mode ~/.ssh/id_rsa    # -> 600
```

#### Arguments

- **$1** (string): Attribute: mode (octal, e.g. 644), perms (e.g. -rw-r--r--), size (bytes), mtime (YYYY-MM-DD HH:MM).
- **$2** (string): File path.

#### Exit codes

- **0**: Success.
- **2**: Unknown attribute or missing path.
- **3**: The file does not exist.

#### Output on stdout

- The attribute value.

### shell::fs::mkdir

Create directories (with parents) if they do not exist.
Tries as the current user first. Only with `--sudo` is privilege escalation
used, and ownership is then handed back to the current user.

#### Example

```bash
shell::fs::mkdir "$HOME/.config/app"
shell::fs::mkdir --private "$HOME/.shell-config"
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the commands instead of running them.

- **-p** | **--private**

  Create with mode 700 (owner only).

- **--sudo**

  Retry with sudo when the parent is not writable.

#### Arguments

- **...** (string): Directory paths.

#### Exit codes

- **0**: Every directory exists afterwards.
- **1**: A directory could not be created.
- **2**: No path was given.

### shell::fs::touch

Create files (and their parent directories) if they do not exist.
Existing files are left untouched (content and permissions).

#### Example

```bash
shell::fs::touch --private "$SHELL_KEY_FILE"
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the commands instead of running them.

- **-p** | **--private**

  Create the file with mode 600 and new parents with 700.

#### Arguments

- **...** (string): File paths.

#### Exit codes

- **0**: Every file exists afterwards.
- **1**: A file or its parent could not be created.
- **2**: No path was given.

### shell::fs::copy

Copy one source file to one or more NEW filenames in the current directory.
Existing destinations are never overwritten.

#### Example

```bash
shell::fs::copy source.txt copy1.txt copy2.txt
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the commands instead of running them.

#### Arguments

- **$1** (string): Source file.
- **...** (string): One or more new filenames.

#### Exit codes

- **0**: Every copy succeeded (or dry-run printed).
- **1**: At least one copy failed or was skipped.
- **2**: Fewer than two arguments were given.
- **3**: The source does not exist.

### shell::fs::move

Move files into an existing destination directory.
Existing destination files are never overwritten.

#### Example

```bash
shell::fs::move /path/to/dest file1.txt file2.txt
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the commands instead of running them.

#### Arguments

- **$1** (string): Destination directory (must exist).
- **...** (string): Files or directories to move.

#### Exit codes

- **0**: Every move succeeded (or dry-run printed).
- **1**: At least one move failed or was skipped.
- **2**: Fewer than two arguments were given.
- **3**: The destination directory does not exist.

### shell::fs::remove

Delete files or directories recursively.
Refuses `/`, `.`, `..`, `$HOME` and empty paths. Uses sudo only when
`--sudo` is passed (the earlier version always ran `sudo rm -rf`).

#### Example

```bash
shell::fs::remove build dist
shell::fs::remove -n --sudo /var/tmp/stale
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the commands instead of running them.

- **--sudo**

  Run rm through sudo.

#### Arguments

- **...** (string): Paths to delete.

#### Exit codes

- **0**: Every path was removed (or dry-run printed).
- **1**: A removal failed.
- **2**: No path given, or a path was refused as unsafe.

### shell::fs::unarchive

Extract an archive according to its extension.
Supported: .tar .tar.gz .tgz .tar.bz2 .tbz2 .tar.xz .txz .gz .bz2 .zip .rar .7z .Z
Extraction happens in the current directory. Required extractors
(unzip, unrar, 7z) are reported when missing.

#### Example

```bash
shell::fs::unarchive release.tar.gz
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): Archive file.

#### Exit codes

- **0**: Extracted (or dry-run printed).
- **1**: The extractor failed.
- **2**: Wrong arguments or unsupported extension.
- **3**: The archive or its extractor is missing.

### shell::fs::ls

List the current directory with type icons and optional details.
Rewritten to be side-effect free: the earlier version installed an
`EXIT` trap, silently replacing any trap the user had set in their shell.

#### Example

```bash
shell::fs::ls -al
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-a**

  Include hidden entries.

- **-l**

  Long format: permissions, size, modified time.

#### Exit codes

- **0**: Success.
- **1**: The directory could not be read.
- **2**: Unknown option.

#### Output on stdout

- A column-aligned listing. `[d]` directory, `[e]` executable, `[f]` file.

### shell::link::hard

Create hard links from a pair of paths or from a `.link` file.
A `.link` file holds one `source → destination` pair per line; blank lines
and lines starting with `#` are ignored.

#### Example

```bash
shell::link::hard data.db backup/data.db
shell::link::hard            # reads ./.link
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the commands instead of running them.

#### Arguments

- **$1** (string): Source file (omit both arguments to read ./.link).
- **$2** (string): Destination path.

#### Exit codes

- **0**: Every link was created (or dry-run printed).
- **1**: A source is missing or `ln` failed.
- **2**: Invalid arguments, malformed `.link` entry, or destination exists.

### shell::directory::open

Open a directory in the platform file manager.
macOS: Finder (via AppleScript). Linux: `xdg-open`.

#### Example

```bash
shell::directory::open ~/Downloads
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Arguments

- **$1** (string): Directory (default: current directory).

#### Exit codes

- **0**: The file manager was launched.
- **1**: The directory is missing or the launcher failed.
- **2**: More than one argument.
- **4**: Unsupported operating system.

### shell::directory::back

Change to the previous working directory (`cd -`).

#### Options

- **-h** | **--help**

  Show help and return.

#### Exit codes

- **0**: Directory changed.
- **1**: There is no previous directory, or it is not accessible.
- **2**: Arguments were given.

### shell::file::mime

Print the MIME type of a file.
Looks the extension up first (fast, deterministic across platforms); for
unknown or missing extensions it asks `file --mime-type`, and finally falls
back to `application/octet-stream` (the earlier default of `text/plain`
mislabelled binary files).

#### Example

```bash
shell::file::mime report.pdf   # -> application/pdf
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Arguments

- **$1** (string): File path.

#### Exit codes

- **0**: Success.
- **2**: No path given.
- **3**: The file does not exist.

#### Output on stdout

- The MIME type.

### shell::encode::file::base64

Print a file's contents as a single-line Base64 string.
Streams through `base64 | tr -d '\n'` (GNU base64 wraps at 76 columns, BSD
does not; deleting newlines gives identical output on both). No temp file.

#### Example

```bash
b64="$(shell::encode::file::base64 logo.png)"
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): File path.

#### Exit codes

- **0**: Success.
- **1**: Encoding failed.
- **2**: Not exactly one path was given.
- **3**: The file does not exist.

#### Output on stdout

- The Base64 text without newlines.

### shell::fs::browse

Pick a file with fzf and run an action on it.
Replaces `shell::editor`. Actions: cat, less, more, vim, nano, remove,
base64, clip-base64, path, clip, unlock, permissions, ex-permissions,
mime-type.

#### Example

```bash
shell::fs::browse ~/documents
shell::fs::browse -n .
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the chosen command instead of running it.

#### Arguments

- **$1** (string): Directory whose files are offered (default: current directory).

#### Exit codes

- **0**: The action completed.
- **1**: The action failed.
- **3**: The directory does not exist or holds no files.
- **9**: The user cancelled a selection.
