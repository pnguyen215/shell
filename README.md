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

- **`shell::get_os_type`**  
  Identifies and returns the current operating system type as a standardized string (e.g., "linux" or "macos").  
  _Example:_ `shell::get_os_type`

- **`shell::colored_echo`**  
  Outputs text to the terminal with customizable foreground colors using `tput` and ANSI escape sequences. Requires a message and a color code (e.g., 46 for cyan).  
  _Example:_ `shell::colored_echo "Task completed" 46`

- **`shell::run_cmd`**  
  Executes a specified command and logs it to the terminal for tracking purposes.  
  _Example:_ `shell::run_cmd ls -l`

- **`shell::run_cmd_eval`**  
  Executes a command using `eval` and logs it, useful for dynamic command construction.  
  _Example:_ `shell::run_cmd_eval ls -l`

- **`shell::is_command_available`**  
  Checks if a given command exists in the system's PATH, returning a success or failure status.  
  _Example:_ `shell::is_command_available git`

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

- **`add_bookmark`**
  Adds a bookmark for the current directory with the specified name.
  _Example:_

  - `add_bookmark <bookmark name>`

- **`remove_bookmark`**
  Deletes a bookmark with the specified name from the bookmarks file.
  _Example:_

  - `remove_bookmark <bookmark_name>`

- **`remove_bookmark_linux`**
  Deletes a bookmark with the specified name from the bookmarks file.
  _Example:_

  - `remove_bookmark_linux <bookmark_name>`

- **`show_bookmark`**
  Displays a formatted list of all bookmarks.
  _Example:_ `show_bookmark`

- **`go_bookmark`**
  Navigates to the directory associated with the specified bookmark name.
  _Example:_

  - `go_bookmark <bookmark name>`

- **`go_back`**
  Navigates to the previous working directory.

- **`goto_version`**
  Displays the version of the goto script.

- **`goto`**
  Main function to handle user commands and navigate directories.
  _Example:_

  - `goto [command]`
  - `goto_usage`

- **`install_homebrew`**
  Installs Homebrew using the official installation script.

- **`uninstall_homebrew`**
  Uninstalls Homebrew from the system.

- **`install_oh_my_zsh`**
  Installs Oh My Zsh if it is not already present on the system.
  _Example:_

  - `install_oh_my_zsh`
  - `install_oh_my_zsh -n`

- **`uninstall_oh_my_zsh`**
  Uninstalls Oh My Zsh by removing its directory and restoring the original .zshrc backup if available.
  _Example:_

  - `uninstall_oh_my_zsh`
  - `uninstall_oh_my_zsh -n`

- **`read_conf`**
  Sources a configuration file, allowing its variables and functions to be loaded into the current shell.
  _Example:_

  - `read_conf [-n] <filename>`
  - `read_conf ~/.my-config`
  - `read_conf -n ~/.my-config `

- **`add_conf`**
  Adds a configuration entry (key=value) to a constant configuration file.
  The value is encoded using Base64 before being saved.
  _Example:_

  - `add_conf [-n] <key> <value>`
  - `add_conf my_setting "some secret value" `
  - `add_conf -n my_setting "some secret value"`

- **`get_conf`**
  Interactively selects a configuration key from a constant configuration file using fzf,
  then decodes and displays its corresponding value.

- **`get_value_conf`**
  Retrieves and outputs the decoded value for a given configuration key from the key configuration file.
  _Example:_

  - `get_value_conf my_setting`

- **`remove_conf`**
  Interactively selects a configuration key from a constant configuration file using fzf,
  then removes the corresponding entry from the configuration file.
  _Example:_

  - `remove_conf`
  - `remove_conf -n`

- **`update_conf`**
  Interactively updates the value for a configuration key in a constant configuration file.
  The new value is encoded using Base64 before updating the file.
  _Example:_

  - `update_conf`
  - `update_conf -n`

- **`exist_key_conf`**
  Checks if a configuration key exists in the key configuration file.
  _Example:_

  - `exist_key_conf <key>`
  - `exist_key_conf my_setting`

- **`rename_key_conf`**
  Renames an existing configuration key in the key configuration file.
  _Example:_

  - `rename_key_conf [-n]`

- **`is_protected_key`**
  Checks if the specified configuration key is protected.
  _Example:_

  - `is_protected_key <key>`

- **`add_group`**
  Groups selected configuration keys under a specified group name.
  _Example:_

  - `add_group [-n]`

- **`read_group`**
  Reads and displays the configurations for a given group by group name.
  _Example:_

  - `read_group <group_name>`
  - `read_group my_group`

- **`remove_group`**
  Interactively selects a group name from the group configuration file using fzf,
  then removes the corresponding group entry.
  _Example:_

  - `remove_group [-n]`

- **`update_group`**
  Interactively updates an existing group by letting you select new keys for that group.
  _Example:_

  - `update_group [-n]`

- **`rename_group`**
  Renames an existing group in the group configuration file.
  _Example:_

  - `rename_group [-n]`

- **`list_groups`**
  Lists all group names defined in the group configuration file.

- **`select_group`**
  Interactively selects a group name from the group configuration file using fzf,
  then lists all keys belonging to the selected group and uses fzf to choose one key,
  finally displaying the decoded value for the selected key.

- **`clone_group`**
  Clones an existing group by creating a new group with the same keys.
  _Example:_

  - `clone_group [-n]`

- **`sync_key_group_conf`**
  Synchronizes group configurations by ensuring that each group's keys exist in the key configuration file.
  If a key listed in a group does not exist, it is removed from that group.
  If a group ends up with no valid keys, that group entry is removed.
  _Example:_

  - `sync_key_group_conf [-n]`

- **`send_telegram_message`**
  Sends a message via the Telegram Bot API.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
    - token : The Telegram Bot API token.
    - chat_id : The chat identifier where the message should be sent.
    - message : The message text to send.

  - `send_telegram_message [-n] <token> <chat_id> <message>`

- **`send_telegram_historical_gh_message`**
  Sends a historical GitHub-related message via Telegram using stored configuration keys.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
    - message : The message text to send.

  - `send_telegram_historical_gh_message [-n] <message>`

- **`send_telegram_attachment`**
  Sends one or more attachments (files) via Telegram using the Bot API asynchronously.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
    - token : The Telegram Bot API token.
    - chat_id : The chat identifier where the message should be sent.
    - description: A text description that is appended to each attachment's caption along with a timestamp.
    - filename_X: One or more filenames of the attachments to send.

  - `send_telegram_attachment [-n] <token> <chat_id> <description> [filename_1] [filename_2] [filename_3] ...`

- **`fzf_zip_attachment`**
  Zips selected files from a specified folder and outputs the absolute path of the created zip file.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
    - folder_path : The folder (directory) from which to select files for zipping.

  - `fzf_zip_attachment [-n] <folder_path>`

- **`fzf_current_zip_attachment`**
  Reuses fzf_zip_attachment to zip selected files from the current directory, then renames the resulting zip file to use the current directory's basename and places it inside the current directory.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.

  - `fzf_current_zip_attachment [-n]`

- **`fzf_send_telegram_attachment`**
  Uses fzf to interactively select one or more files from a folder (default: current directory), and sends them as attachments via the Telegram Bot API by reusing send_telegram_attachment.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
    - token: The Telegram Bot API token.
    - chat_id: The chat identifier where the attachments are sent.
    - description: A text description appended to each attachment's caption along with a timestamp.
    - folder_path: (Optional) The folder to search for files; defaults to the current directory if not provided.

  - `fzf_send_telegram_attachment [-n] <token> <chat_id> <description> [folder_path]`
