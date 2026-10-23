# lib/bookmark.sh

Directory bookmarks.

## Overview

Create the bookmark directory and file (mode 700/600) if missing.
Replaces the code that used to run every time the library was sourced.

## Index

* [shell::bookmark::ensure](#shellbookmarkensure)
* [shell::bookmark::add](#shellbookmarkadd)
* [shell::bookmark::remove](#shellbookmarkremove)
* [shell::bookmark::go](#shellbookmarkgo)
* [shell::bookmark::list](#shellbookmarklist)
* [shell::bookmark::list::fzf](#shellbookmarklistfzf)
* [shell::bookmark::list::up::fzf](#shellbookmarklistupfzf)
* [shell::bookmark::remove::down::fzf](#shellbookmarkremovedownfzf)
* [shell::bookmark::remove::fzf](#shellbookmarkremovefzf)
* [shell::bookmark::rename](#shellbookmarkrename)
* [shell::bookmark::rename::fzf](#shellbookmarkrenamefzf)
* [shell::bookmark::rename_dir](#shellbookmarkrename_dir)
* [shell::bookmark::rename_dir::fzf](#shellbookmarkrename_dirfzf)

### shell::bookmark::ensure

Create the bookmark directory and file (mode 700/600) if missing.
Replaces the code that used to run every time the library was sourced.

_Function has no arguments._

#### Exit codes

* **0**: The bookmark file exists.
* **1**: It could not be created.

### shell::bookmark::add

Adds a bookmark for the current working directory.

Sanitizes the bookmark name and stores the current working directory as:

<absolute_path>|<bookmark_name>

If the bookmark already exists, the user is prompted to confirm replacement.

#### Example

```bash
shell::bookmark::add project
shell::bookmark::add -n project
```

#### Options

* **-n** | **--dry-run**

  Print the planned commands instead of executing them.

* **-h** | **--help**

  Show this help message.

#### Arguments

* **$1** (string): bookmark_name: Bookmark name.

#### Exit codes

* **0**: Success.
* **2**: Invalid or missing arguments.

### shell::bookmark::remove

Deletes a bookmark with the specified name from the bookmarks file.

This function searches for a bookmark entry in the bookmarks file that ends with "|<bookmark_name>".
If the entry is found, it creates a secure temporary file using mktemp, filters out the matching line,
and then replaces the original bookmarks file with the filtered version.
If the bookmark is not found or removal fails, an error message is displayed.

Notes:
- The bookmarks file is specified by the global variable 'bookmarks_file'.

#### Example

```bash
shell::bookmark::remove
```

#### Arguments

* **$1** (string): bookmark_name: The name of the bookmark to remove.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::bookmark::go

Navigates to the directory associated with the specified bookmark name.

The 'shell::bookmark::go' function changes the current working directory to the directory
associated with the given bookmark name. It looks for a line in the bookmarks file
that ends with "|<bookmark name>".

#### Example

```bash
shell::bookmark::go
```

#### Options

* **-h**

  Optional. Displays this help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::bookmark::list

Displays a formatted list of all bookmarks.

The 'shell::bookmark::list' function lists all bookmarks in a formatted manner,
showing the bookmark name (field 2) in yellow and the associated directory (field 1) in default color.

#### Example

```bash
shell::bookmark::list
```

#### Options

* **-h**

  Optional. Displays this help message.

#### Exit codes

* **0**: Success.

### shell::bookmark::list::fzf

Interactively selects a path from the bookmarks file using fzf and navigates to it.

This function first checks if the bookmarks file exists. If not, it displays an error.
It then extracts bookmark names and their associated paths from the bookmarks file,
formats them for fzf display, and allows the user to interactively select a bookmark.
Once a bookmark is selected, it extracts the target directory.
In dry-run mode, it prints the 'cd' command that would be executed.
Otherwise, it changes the current working directory to the selected path.

#### Example

```bash
shell::bookmark::list::fzf         # Interactively select a bookmark and navigate to it.
shell::bookmark::list::fzf -n      # Dry-run: print the navigation command without executing.
```

#### Options

* **-h**

  Optional help flag. Displays this help message.

* **-n**

  Optional dry-run flag. If provided, the navigation command is printed instead of executed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::bookmark::list::up::fzf

Interactively selects a path from the bookmarks file using fzf and displays its availability status.

This function first checks if the bookmarks file exists. If not, it displays an error.
It then reads each bookmark, determines if its associated directory exists (Active/Inactive),
and formats the output for fzf to include this status.
The user can then interactively select a bookmark, and the function will display
the selected bookmark's name, path, and its active/inactive status.
In dry-run mode, it will print the commands that would be used to check directory existence.

#### Example

```bash
shell::bookmark::list::up::fzf         # Interactively select a bookmark and verify its path.
shell::bookmark::list::up::fzf -n      # Dry-run: print verification commands without executing.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the verification commands are printed instead of executing checks.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::bookmark::remove::down::fzf

Interactively selects inactive bookmark paths using fzf and removes them from the bookmarks file.

This function checks if the bookmarks file exists. If not, it displays an error.
It then identifies inactive bookmarks (paths that do not exist), formats them for fzf display
with their status, and allows the user to interactively select one or more bookmarks for removal.
Selected bookmarks are removed from the bookmarks file using a secure temporary file.
In dry-run mode, it prints the commands that would be used to update the bookmarks file.

Notes:
- Uses a secure temporary file created with mktemp to safely update the bookmarks file.
- Compatible with both macOS and Linux.
- Inactive bookmarks are those whose associated directories do not exist.

#### Example

```bash
shell::bookmark::remove::down::fzf         # Interactively select and remove inactive bookmarks.
shell::bookmark::remove::down::fzf -n      # Dry-run: print removal commands without executing.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the removal commands are printed instead of executed.

* **-h**

  Optional help flag. Displays this help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::bookmark::remove::fzf

Interactively selects a bookmark using fzf and removes it from the bookmarks file.

This function checks if the bookmarks file exists. If not, it displays an error.
It then reads all bookmarks, formats them for fzf display, and allows the user to
interactively select a bookmark to remove. The selected bookmark is removed from
the bookmarks file using a secure temporary file.

#### Example

```bash
shell::bookmark::remove::fzf       # Interactively select and remove a bookmark.
shell::bookmark::remove::fzf -n    # Dry-run: print removal command without executing.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the removal command is printed instead of executed.

* **-h**

  Optional help flag. Displays this help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::bookmark::rename

Renames a bookmark in the bookmarks file.

This function searches for a bookmark entry in the bookmarks file that ends with "|<old_name>".
If found, it replaces the bookmark name with the new name using a sed command.
The sed command is constructed differently for macOS and Linux due to differences in the in-place edit flag.

#### Example

```bash
shell::bookmark::rename old_name new_name
shell::bookmark::rename -n old_name new_name
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the rename command is printed instead of executed.

#### Arguments

* **$1** (string): old_name: The current name of the bookmark.
* **$2** (string): new_name: The new name to assign to the bookmark.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::bookmark::rename::fzf

Interactively selects a bookmark using fzf and renames it.

This function checks if the bookmarks file exists. If not, it displays an error.
It then reads all bookmarks, formats them for fzf display, and allows the user to
interactively select a bookmark to rename. The user is prompted to enter a new name,
and the shell::bookmark::rename function is called to perform the rename.

#### Example

```bash
shell::bookmark::rename::fzf       # Interactively select and rename a bookmark.
shell::bookmark::rename::fzf -n    # Dry-run: print rename command without executing.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the rename command is printed instead of executed.

* **-h**

  Optional help flag. Displays this help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::bookmark::rename_dir

Renames the directory associated with a bookmark.

This function finds the directory path associated with the given bookmark name
and renames the directory to the new name provided. It validates that the bookmark exists,
the directory exists, and the target name does not already exist.

#### Example

```bash
shell::bookmark::rename_dir my-bookmark new-dir-name
shell::bookmark::rename_dir -n my-bookmark new-dir-name
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the rename command is printed instead of executed.

#### Arguments

* **$1** (string): bookmark_name: The name of the bookmark whose directory should be renamed.
* **$2** (string): new_dir_name: The new name for the directory.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::bookmark::rename_dir::fzf

Interactively selects a bookmark using fzf and renames its associated directory.

This function checks if the bookmarks file exists. If not, it displays an error.
It then reads all bookmarks, formats them for fzf display, and allows the user to
interactively select a bookmark. The user is prompted to enter a new directory name,
and the shell::bookmark::rename_dir function is called to perform the rename.

#### Example

```bash
shell::bookmark::rename_dir::fzf       # Interactively select and rename a directory.
shell::bookmark::rename_dir::fzf -n    # Dry-run: print rename command without executing.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the rename command is printed instead of executed.

* **-h**

  Optional help flag. Displays this help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

