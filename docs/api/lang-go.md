# lang/go.sh

Go project helpers.

## Overview

Retrieves and prints the value of the GOPRIVATE environment variable.
The GOPRIVATE variable is used by Go tools to determine which modules
should be considered private, affecting how Go commands handle dependencies.

Notes:
-   This function is compatible with both Linux and macOS.
-   It uses `go env GOPRIVATE` to reliably fetch the GOPRIVATE setting.
1.  Run `shell::go::env::get_private` to display the current GOPRIVATE value.
2.  Use `shell::go::env::get_private -n` to preview the command.

## Index

* [shell::go::env::get_private](#shellgoenvget_private)
* [shell::go::env::set_private](#shellgoenvset_private)
* [shell::go::env::remove_private_fzf](#shellgoenvremove_private_fzf)
* [shell::go::module::create](#shellgomodulecreate)
* [shell::go::scaffold::add](#shellgoscaffoldadd)
* [shell::go::gitignore::add](#shellgogitignoreadd)

### shell::go::env::get_private

Retrieves and prints the value of the GOPRIVATE environment variable.
The GOPRIVATE variable is used by Go tools to determine which modules
should be considered private, affecting how Go commands handle dependencies.

Notes:
-   This function is compatible with both Linux and macOS.
-   It uses `go env GOPRIVATE` to reliably fetch the GOPRIVATE setting.
1.  Run `shell::go::env::get_private` to display the current GOPRIVATE value.
2.  Use `shell::go::env::get_private -n` to preview the command.

#### Example

```bash
shell::go::env::get_private
shell::go::env::get_private -n
```

#### Options

* **-n**

  Optional. If provided, the command is printed using shell::logger::command_clip instead of executed. None

#### Exit codes

* **0**: Success.

### shell::go::env::set_private

Sets the GOPRIVATE environment variable to the provided value.
If GOPRIVATE already has values, the new values are appended
to the existing comma-separated list.
This variable is used by Go tools to determine which modules
should be considered private, affecting how Go commands handle dependencies.

Notes:
-   This function is compatible with both Linux and macOS.
-   It uses `go env -w GOPRIVATE=<value>` to set the GOPRIVATE setting.
-   It supports dry-run and asynchronous execution.
1.  Run `shell::go::env::set_private <repository1> [repository2] ...` to set or append to the GOPRIVATE variable.
2.  Use `shell::go::env::set_private -n <repository1> [repository2] ...` to preview the command.

#### Example

```bash
shell::go::env::set_private "example.com/private1"
shell::go::env::set_private -n "example.com/private1" "example.com/internal"
```

#### Options

* **-n**

  Optional. If provided, the command is printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): repository1: The first repository to add to GOPRIVATE. [repository2] [repository3] ...: Additional repositories to add to GOPRIVATE. None

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::go::env::remove_private_fzf

Uses fzf to interactively select and remove entries from the GOPRIVATE environment variable.
The GOPRIVATE variable is used by Go tools to determine which modules should be considered private,
affecting how Go commands handle authenticated access to dependencies.

Notes:
- Requires fzf and Go to be installed; fzf is installed automatically if missing.
- Uses `go env GOPRIVATE` to retrieve the current value.
- Uses `go env -w GOPRIVATE=<new_value>` to set the updated value.
- Supports dry-run and asynchronous execution via shell::logger::command_clip and shell::exec::async.
- Compatible with both Linux (Ubuntu 22.04 LTS) and macOS.
1. Run `shell::go::env::remove_private_fzf` to select and remove GOPRIVATE entries via fzf.
2. Use `shell::go::env::remove_private_fzf -n` to see the command that would be executed.

#### Example

```bash
shell::go::env::remove_private_fzf           # Interactively remove entries from GOPRIVATE.
shell::go::env::remove_private_fzf -n        # Preview the command without executing it.
```

#### Options

* **-n**

  Optional. If provided, the command is printed using shell::logger::command_clip instead of executed. None

#### Exit codes

* **0**: Success.
* **5**: Not implemented.
* **8**: Nothing to process (empty input or result).

### shell::go::module::create

Creates a new Go application by initializing a Go module and tidying dependencies
within a specified target folder.

This function checks if the provided application name is a valid URL.
If it is, it extracts the module name from the URL.
If a target folder is specified, the function ensures the folder exists,
changes into that directory, initializes the Go module using `go mod init`,
and tidies the dependencies using `go mod tidy`.
After execution, it returns to the original directory.
In dry-run mode, the commands are displayed without execution.

#### Example

```bash
shell::go::module::create my_app                      # Initializes a Go module named 'my_app' in the current directory.
shell::go::module::create my_app /path/to/my/folder   # Initializes 'my_app' in the specified folder.
shell::go::module::create -n my_app                   # Previews the initialization commands without executing them.
shell::go::module::create -n my_app /tmp/go_projects  # Previews initialization in a target folder.
shell::go::module::create https://github.com/user/repo /home/user/src # Initializes from a GitHub URL in a target folder.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the commands are printed using shell::logger::command_clip instead of being executed.

#### Arguments

* **$1** (string): app_name|github_url: The name of the application or a GitHub URL to initialize the module.
* **...** (string): target_folder: Optional. The path to the folder where the Go application should be created. If not provided, the application is created in the current directory.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::go::scaffold::add

This function downloads essential configuration files for a Go application.

It retrieves the following files:
- VERSION_RELEASE.md: Contains the version release information for the application.
- Makefile: A build script that defines how to compile and manage the application.
- ci.yml: A GitHub Actions workflow configuration for continuous integration.
- ci_notify.yml: A GitHub Actions workflow configuration for notifications related to CI events.

Each file is downloaded using the shell::net::download function, which ensures that the files are
fetched from the specified URLs and saved in the appropriate locations.

#### Example

```bash
shell::go::scaffold::add
```

_Function has no arguments._

#### Exit codes

* **0**: Success.

### shell::go::gitignore::add

This function downloads the .gitignore file for a Go project.

It utilizes the shell::net::download function to fetch the .gitignore file
from the specified URL and saves it in the appropriate location within the project structure.

The .gitignore file is essential for specifying which files and directories
should be ignored by Git, helping to keep the repository clean and free of unnecessary files.

#### Example

```bash
shell::go::gitignore::add
```

_Function has no arguments._

#### Exit codes

* **0**: Success.

