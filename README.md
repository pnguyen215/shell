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

Open your terminal and typing:

| Command                          | Description                                                                                  | Example                                         |
| -------------------------------- | -------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `shell_version`                  | Get the shell version                                                                        |                                                 |
| `shell_upgrade`                  | Upgrade the shell CLI                                                                        |                                                 |
| `shell_uninstall`                | Uninstall the shell CLI                                                                      |                                                 |
| `get_os_type`                    | Determines the current operating system type and outputs a standardized string.              |                                                 |
| `colored_echo`                   | Prints text to the terminal with customizable colors using `tput` and ANSI escape sequences. | `colored_echo "Task completed" 46`              |
| `run_cmd`                        | Executes a command and prints it for logging purposes.                                       | `run_cmd ls -l`                                 |
| `run_cmd_eval`                   | Execute a command using `eval` and print it for logging purposes.                            | `run_cmd_eval ls -l`                            |
| `is_command_available`           | Check if a command is available in the system's PATH.                                        | `is_command_available git`                      |
| `install_package`                | Cross-platform package installation function that works on both macOS and Linux.             | `install_package git`                           |
| `uninstall_package`              | Cross-platform package uninstallation function that works on both macOS and Linux.           | `uninstall_package git`                         |
| `list_installed_packages`        | Lists all packages currently installed on Linux or macOS.                                    |                                                 |
| `list_path_installed_packages`   | Lists all packages installed via directory-based package installation on Linux or macOS.     |                                                 |
| `create_directory_if_not_exists` | Utility function to create a directory (including nested directories) if it doesn't exist.   | `create_directory_if_not_exists <dir>`          |
| `create_file_if_not_exists`      | Utility function to create a file if it doesn't exist.                                       | `create_file_if_not_exists <filename>`          |
| `grant777`                       | Sets full permissions (read, write, and execute) for the specified file or directory.        | `grant777 ./my_script.sh`                       |
| `clip_cwd`                       | Copies the current directory path to the clipboard.                                          |                                                 |
| `clip_value`                     | Copies the provided text value into the system clipboard.                                    | `clip_value "Hello, World!"`                    |
| `get_temp_dir`                   | Returns the appropriate temporary directory based on the detected kernel.                    | `TEMP_DIR=$(get_temp_dir)`                      |
| `on_evict`                       | Hook to print a command without executing it.                                                | `on_evict ls -l`                                |
| `port_check`                     | Checks if a specific TCP port is in use (listening).                                         | `port_check 8080 -n` or `port_check 8080`       |
| `port_kill`                      | Terminates all processes listening on the specified TCP port(s).                             | `port_kill 8080 -n` or `port_kill 8080`         |
| `copy_files`                     | Copies a source file to one or more destination filenames in the current working directory.  | `copy_files myfile.txt newfile.txt`             |
| `move_files`                     | Moves one or more files to a destination folder.                                             | `move_files /path/to/dest file1.txt file2.txt`  |
| `remove_dataset`                 | Removes a file or directory using `sudo rm -rf`.                                             | `remove_dataset my-dir`                         |
| `editor`                         | Open a selected file from a specified folder using a chosen text editor.                     | `editor ~/documents` or `editor -n ~/documents` |
| `download_dataset`               | Downloads a dataset file from a provided download link.                                      | `download_dataset data.zip https://e.com/e.zip` |
| `unarchive`                      | Extracts a compressed file based on its file extension.                                      | `unarchive [-n] <filename>`                     |
| `list_high_mem_usage`            | Displays processes with high memory consumption.                                             |                                                 |
| `open_link`                      | Opens the specified URL in the default web browser.                                          | `open_link [-n] <url>`                          |
| `loading_spinner`                | Displays a loading spinner in the console for a specified duration.                          | `loading_spinner [-n] [duration]`               |
| `measure_time`                   | Measures the execution time of a command and displays the elapsed time.                      | `measure_time sleep 2`                          |
| `async`                          | Executes a command or function asynchronously (in the background).                           | `async my_function arg1 arg2` or `async -n ls`  |
| `fzf_copy`                       | Interactively selects a file to copy and a destination directory using fzf                   |                                                 |
| `fzf_move`                       | Interactively selects a file to move and a destination directory using fzf                   |                                                 |
| `fzf_remove`                     | Interactively selects a file to remove and a destination directory using fzf                 |                                                 |
