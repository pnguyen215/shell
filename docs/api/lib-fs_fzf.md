# lib/fs_fzf.sh

Interactive (fzf) file operations.

## Overview

Interactively selects a file to copy and a destination directory using fzf,
then copies the selected file to the destination directory.

This function leverages fzf to provide an interactive interface for choosing:
1. A source file (from the current directory and subdirectories).
2. A destination directory (from the current directory and subdirectories).
It then copies the source file to the destination directory using the original filename.

## Index

* [shell::fs::copy::fzf](#shellfscopyfzf)
* [shell::fs::move::fzf](#shellfsmovefzf)
* [shell::fs::remove::fzf](#shellfsremovefzf)
* [shell::fs::zip::fzf](#shellfszipfzf)
* [shell::fs::zip::current::fzf](#shellfszipcurrentfzf)
* [shell::telegram::send_document::fzf](#shelltelegramsend_documentfzf)

### shell::fs::copy::fzf

Interactively selects a file to copy and a destination directory using fzf,
then copies the selected file to the destination directory.

This function leverages fzf to provide an interactive interface for choosing:
1. A source file (from the current directory and subdirectories).
2. A destination directory (from the current directory and subdirectories).
It then copies the source file to the destination directory using the original filename.

#### Example

```bash
shell::fs::copy::fzf
```

#### Options

* **-h**

  Optional. Displays this help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::fs::move::fzf

Interactively selects a file to move and a destination directory using fzf,
then moves the selected file to the destination directory.

This function leverages fzf to provide an interactive interface for choosing:
1. A source file (from the current directory and subdirectories).
2. A destination directory (from the current directory and subdirectories).
It then moves the source file to the destination directory using the original filename.

#### Example

```bash
shell::fs::move::fzf
```

#### Options

* **-h**

  Optional. Displays this help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::fs::remove::fzf

Interactively selects a file or directory to remove using fzf,
then removes the selected file or directory.

This function leverages fzf to provide an interactive interface for choosing:
1. A file or directory (from the current directory and subdirectories).
It then removes the selected file or directory using the original path.

#### Example

```bash
shell::fs::remove::fzf
```

#### Options

* **-h**

  Optional. Displays this help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::fs::zip::fzf

Zips selected files from a specified folder and outputs the absolute path of the created zip file.

This function uses the 'find' command to list all files in the specified folder,
and then launches 'fzf' in multi-select mode to allow interactive file selection.
If one or more files are selected, a zip command is constructed to compress those files.
In dry-run mode (-n), the command is printed (via shell::logger::command_clip) without execution;
otherwise, it is executed using shell::exec::shell.
Finally, the absolute path of the created zip file is echoed.

#### Example

```bash
shell::fs::zip::fzf /path/to/folder
shell::fs::zip::fzf -n /path/to/folder  # Dry-run: prints the command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): folder_path: The folder (directory) from which to select files for zipping.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::fs::zip::current::fzf

Reuses shell::fs::zip::fzf to zip selected files from the current directory,
ensuring that when unzipped, the archive creates a single top-level folder.

This function obtains the current directory's name and its parent directory.
It then changes to the parent directory and calls shell::fs::zip::fzf on the folder name.
This ensures that the zip command is run with relative paths so that the resulting archive
contains only one top-level folder (the folder name). After zipping, it moves the zip file
back to the original (current) directory, echoes its absolute path, and copies the value to the clipboard.

#### Example

```bash
shell::fs::zip::current::fzf
shell::fs::zip::current::fzf -n  # Dry-run: prints the command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::telegram::send_document::fzf

Uses fzf to interactively select one or more files from a folder (default: current directory)
and sends them as attachments via the Telegram Bot API by reusing shell::telegram::send_document.

This function checks that the required parameters are provided and sets the folder path to the current directory if none is given.
It then uses the 'find' command and fzf (in multi-select mode) to let the user choose one or more files.
If files are selected, it calls shell::telegram::send_document (passing the dry-run flag if needed) with the selected filenames.

#### Example

```bash
shell::telegram::send_document::fzf 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 "Report"
shell::telegram::send_document::fzf -n 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 "Test" /path/to/folder
```

#### Options

* **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): token: The Telegram Bot API token.
* **$2** (string): chat_id: The chat identifier where the attachments are sent.
* **$3** (string): description: A text description appended to each attachment's caption along with a timestamp.
* **...** (string): folder_path: (Optional) The folder to search for files; defaults to the current directory if not provided.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

