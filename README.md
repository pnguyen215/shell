# shell

A lightweight shell library to streamline your development environment setup on Linux and macOS.

## Structure

```bash
shell/
├── install.sh
├── upgrade.sh
├── uninstall.sh
└── src/
    ├── shell.sh  # Main entry point
    └── lib/
        ├── utils.sh
        ├── git.sh
        ├── docker.sh
        └── ...  # Add more as needed
```

## Installation

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pnguyen215/shell/master/install.sh)"
```

## Upgrade

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pnguyen215/shell/master/upgrade.sh)"
```

## Uninstallation

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pnguyen215/shell/master/uninstall.sh)"
```

## Usage

Access the shell library by opening your terminal and using the commands below. Each command is designed to streamline development environment management on Linux and macOS. Examples are provided where applicable.

- **`shell_version`**  
  Displays the current version of the shell library.  
  _Example:_ `shell_version`

- **`shell_upgrade`**  
  Upgrades the shell CLI to the latest version available.  
  _Example:_ `shell_upgrade`

- **`shell_uninstall`**  
  Removes the shell CLI and its associated files from the system.  
  _Example:_ `shell_uninstall`

- **`get_os_type`**  
  Identifies and returns the current operating system type as a standardized string (e.g., "linux" or "macos").  
  _Example:_ `get_os_type`

- **`colored_echo`**  
  Outputs text to the terminal with customizable foreground colors using `tput` and ANSI escape sequences. Requires a message and a color code (e.g., 46 for cyan).  
  _Example:_ `colored_echo "Task completed" 46`

- **`run_cmd`**  
  Executes a specified command and logs it to the terminal for tracking purposes.  
  _Example:_ `run_cmd ls -l`

- **`run_cmd_eval`**  
  Executes a command using `eval` and logs it, useful for dynamic command construction.  
  _Example:_ `run_cmd_eval ls -l`

- **`is_command_available`**  
  Checks if a given command exists in the system's PATH, returning a success or failure status.  
  _Example:_ `is_command_available git`

- **`install_package`**  
  Installs a package using the appropriate package manager for the OS (e.g., `apt` for Linux, `brew` for macOS).  
  _Example:_ `install_package git`

- **`uninstall_package`**  
  Uninstalls a package using the OS-appropriate package manager.  
  _Example:_ `uninstall_package git`

- **`list_installed_packages`**  
  Lists all packages installed on the system via the native package manager.  
  _Example:_ `list_installed_packages`

- **`list_path_installed_packages`**  
  Lists packages installed in directory-based locations (e.g., `/usr/local`).  
  _Example:_ `list_path_installed_packages`

- **`create_directory_if_not_exists`**  
  Creates a directory (including nested paths) if it does not already exist.  
  _Example:_ `create_directory_if_not_exists /path/to/dir`

- **`create_file_if_not_exists`**  
  Creates a file if it does not exist, leaving existing files unchanged.  
  _Example:_ `create_file_if_not_exists config.txt`

- **`grant777`**  
  Assigns full permissions (read, write, execute; `chmod 777`) to a file or directory.  
  _Example:_ `grant777 ./my_script.sh`

- **`clip_cwd`**  
  Copies the current working directory path to the system clipboard.  
  _Example:_ `clip_cwd`

- **`clip_value`**  
  Copies a specified text string to the system clipboard.  
  _Example:_ `clip_value "Hello, World!"`

- **`get_temp_dir`**  
  Returns the OS-appropriate temporary directory path (e.g., `/tmp` on Linux).  
  _Example:_ `TEMP_DIR=$(get_temp_dir)`

- **`on_evict`**  
  Prints a command to the terminal without executing it, useful for debugging or logging.  
  _Example:_ `on_evict ls -l`

- **`port_check`**  
  Checks if a TCP port is in use (listening). Use `-n` to suppress output and return a status only.  
  _Examples:_

  - `port_check 8080`
  - `port_check 8080 -n`

- **`port_kill`**  
  Terminates all processes listening on a specified TCP port. Use `-n` for silent operation.  
  _Examples:_

  - `port_kill 8080`
  - `port_kill 8080 -n`

- **`copy_files`**  
  Copies a source file to one or more destination filenames in the current directory.  
  _Example:_ `copy_files source.txt dest1.txt dest2.txt`

- **`move_files`**  
  Moves one or more files to a specified destination directory.  
  _Example:_ `move_files /path/to/dest file1.txt file2.txt`

- **`remove_dataset`**  
  Deletes a file or directory recursively with elevated privileges (`sudo rm -rf`). Use with caution.  
  _Example:_ `remove_dataset obsolete-dir`

- **`editor`**  
  Opens a file from a specified directory in a chosen text editor. Use `-n` to open in a new instance (if supported).  
  _Examples:_

  - `editor ~/documents`
  - `editor -n ~/documents`

- **`download_dataset`**  
  Downloads a file from a URL and saves it with the specified filename.  
  _Example:_ `download_dataset data.zip https://example.com/data.zip`

- **`unarchive`**  
  Extracts a compressed file based on its extension (e.g., `.zip`, `.tar.gz`). Use `-n` for no-overwrite mode.  
  _Examples:_

  - `unarchive archive.zip`
  - `unarchive -n archive.tar.gz`

- **`list_high_mem_usage`**  
  Displays processes consuming significant memory, sorted by usage.  
  _Example:_ `list_high_mem_usage`

- **`open_link`**  
  Opens a URL in the default web browser. Use `-n` for silent operation (no output).  
  _Examples:_

  - `open_link https://example.com`
  - `open_link -n https://example.com`

- **`loading_spinner`**  
  Displays a console loading spinner for a specified duration (in seconds). Use `-n` to run indefinitely until stopped.  
  _Examples:_

  - `loading_spinner 10`
  - `loading_spinner -n 10`

- **`measure_time`**  
  Measures and reports the execution time of a command in seconds.  
  _Example:_ `measure_time sleep 2`

- **`async`**  
  Runs a command or function asynchronously in the background. Use `-n` for no output.  
  _Examples:_

  - `async my_function arg1 arg2`
  - `async -n ls`

- **`fzf_copy`**  
  Interactively selects a file to copy and a destination directory using `fzf` for fuzzy finding.  
  _Example:_ `fzf_copy`

- **`fzf_move`**  
  Interactively selects a file to move and a destination directory using `fzf`.  
  _Example:_ `fzf_move`

- **`fzf_remove`**  
  Interactively selects a file or directory to remove using `fzf`.  
  _Example:_ `fzf_remove`
