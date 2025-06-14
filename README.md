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

- **`shell::version`**  
  Displays the current version of the shell library.  
  _Example:_ `shell::version`

- **`shell::upgrade`**  
  Upgrades the shell CLI to the latest version available.  
  _Example:_ `shell::upgrade`

- **`shell::uninstall`**  
  Removes the shell CLI and its associated files from the system.  
  _Example:_ `shell::uninstall`

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

- **`shell::install_package`**  
  Installs a package using the appropriate package manager for the OS (e.g., `apt` for Linux, `brew` for macOS).  
  _Example:_ `shell::install_package git`

- **`shell::remove_package`**  
  Uninstalls a package using the OS-appropriate package manager.  
  _Example:_ `shell::remove_package git`

- **`shell::list_packages_installed`**  
  Lists all packages installed on the system via the native package manager.  
  _Example:_ `shell::list_packages_installed`

- **`shell::create_directory_if_not_exists`**  
  Creates a directory (including nested paths) if it does not already exist.  
  _Example:_ `shell::create_directory_if_not_exists /path/to/dir`

- **`shell::create_file_if_not_exists`**  
  Creates a file if it does not exist, leaving existing files unchanged.  
  _Example:_ `shell::create_file_if_not_exists config.txt`

- **`shell::unlock_permissions`**  
  Assigns full permissions (read, write, execute; `chmod 777`) to a file or directory.  
  _Example:_ `shell::unlock_permissions ./my_script.sh`

- **`shell::clip_cwd`**  
  Copies the current working directory path to the system clipboard.  
  _Example:_ `shell::clip_cwd`

- **`shell::clip_value`**  
  Copies a specified text string to the system clipboard.  
  _Example:_ `shell::clip_value "Hello, World!"`

- **`shell::get_temp_dir`**  
  Returns the OS-appropriate temporary directory path (e.g., `/tmp` on Linux).  
  _Example:_ `TEMP_DIR=$(shell::get_temp_dir)`

- **`shell::on_evict`**  
  Prints a command to the terminal without executing it, useful for debugging or logging.  
  _Example:_ `shell::on_evict ls -l`

- **`shell::check_port`**  
  Checks if a TCP port is in use (listening). Use `-n` to suppress output and return a status only.  
  _Examples:_

  - `shell::check_port 8080`
  - `shell::check_port 8080 -n`

- **`shell::port_kill`**  
  Terminates all processes listening on a specified TCP port. Use `-n` for silent operation.  
  _Examples:_

  - `shell::port_kill 8080`
  - `shell::port_kill 8080 -n`

- **`shell::copy_files`**  
  Copies a source file to one or more destination filenames in the current directory.  
  _Example:_ `shell::copy_files source.txt dest1.txt dest2.txt`

- **`shell::move_files`**  
  Moves one or more files to a specified destination directory.  
  _Example:_ `shell::move_files /path/to/dest file1.txt file2.txt`

- **`shell::remove_files`**  
  Deletes a file or directory recursively with elevated privileges (`sudo rm -rf`). Use with caution.  
  _Example:_ `shell::remove_files obsolete-dir`

- **`shell::editor`**  
  Opens a file from a specified directory in a chosen text editor. Use `-n` to open in a new instance (if supported).  
  _Examples:_

  - `shell::editor ~/documents`
  - `shell::editor -n ~/documents`

- **`shell::download_dataset`**  
  Downloads a file from a URL and saves it with the specified filename.  
  _Example:_ `shell::download_dataset data.zip https://example.com/data.zip`

- **`shell::unarchive`**  
  Extracts a compressed file based on its extension (e.g., `.zip`, `.tar.gz`). Use `-n` for no-overwrite mode.  
  _Examples:_

  - `shell::unarchive archive.zip`
  - `shell::unarchive -n archive.tar.gz`

- **`shell::list_high_mem_usage`**  
  Displays processes consuming significant memory, sorted by usage.  
  _Example:_ `shell::list_high_mem_usage`

- **`shell::open_link`**  
  Opens a URL in the default web browser. Use `-n` for silent operation (no output).  
  _Examples:_

  - `shell::open_link https://example.com`
  - `shell::open_link -n https://example.com`

- **`shell::loading_spinner`**  
  Displays a console loading spinner for a specified duration (in seconds). Use `-n` to run indefinitely until stopped.  
  _Examples:_

  - `shell::loading_spinner 10`
  - `shell::loading_spinner -n 10`

- **`shell::measure_time`**  
  Measures and reports the execution time of a command in seconds.  
  _Example:_ `shell::measure_time sleep 2`

- **`shell::async`**  
  Runs a command or function asynchronously in the background. Use `-n` for no output.  
  _Examples:_

  - `shell::async my_function arg1 arg2`
  - `shell::async -n ls`

- **`shell::fzf_copy`**  
  Interactively selects a file to copy and a destination directory using `fzf` for fuzzy finding.  
  _Example:_ `shell::fzf_copy`

- **`shell::fzf_move`**  
  Interactively selects a file to move and a destination directory using `fzf`.  
  _Example:_ `shell::fzf_move`

- **`shell::fzf_remove`**  
  Interactively selects a file or directory to remove using `fzf`.  
  _Example:_ `shell::fzf_remove`

- **`shell::add_bookmark`**
  Adds a bookmark for the current directory with the specified name.
  _Example:_

  - `shell::add_bookmark <bookmark name>`

- **`shell::remove_bookmark`**
  Deletes a bookmark with the specified name from the bookmarks file.
  _Example:_

  - `shell::remove_bookmark <bookmark_name>`

- **`shell::remove_bookmark_linux`**
  Deletes a bookmark with the specified name from the bookmarks file.
  _Example:_

  - `shell::remove_bookmark_linux <bookmark_name>`

- **`shell::show_bookmark`**
  Displays a formatted list of all bookmarks.
  _Example:_ `shell::show_bookmark`

- **`shell::go_bookmark`**
  Navigates to the directory associated with the specified bookmark name.
  _Example:_

  - `shell::go_bookmark <bookmark name>`

- **`shell::go_back`**
  Navigates to the previous working directory.

- **`shell::goto_version`**
  Displays the version of the goto script.

- **`shell::goto`**
  Main function to handle user commands and navigate directories.
  _Example:_

  - `shell::goto [command]`
  - `shell::goto_usage`

- **`shell::install_homebrew`**
  Installs Homebrew using the official installation script.

- **`shell::removal_homebrew`**
  Uninstalls Homebrew from the system.

- **`shell::install_oh_my_zsh`**
  Installs Oh My Zsh if it is not already present on the system.
  _Example:_

  - `shell::install_oh_my_zsh`
  - `shell::install_oh_my_zsh -n`

- **`shell::removal_oh_my_zsh`**
  Uninstalls Oh My Zsh by removing its directory and restoring the original .zshrc backup if available.
  _Example:_

  - `shell::removal_oh_my_zsh`
  - `shell::removal_oh_my_zsh -n`

- **`shell::read_conf`**
  Sources a configuration file, allowing its variables and functions to be loaded into the current shell.
  _Example:_

  - `shell::read_conf [-n] <filename>`
  - `shell::read_conf ~/.my-config`
  - `shell::read_conf -n ~/.my-config `

- **`shell::add_conf`**
  Adds a configuration entry (key=value) to a constant configuration file.
  The value is encoded using Base64 before being saved.
  _Example:_

  - `shell::add_conf [-n] <key> <value>`
  - `shell::add_conf my_setting "some secret value" `
  - `shell::add_conf -n my_setting "some secret value"`

- **`shell::fzf_get_conf`**
  Interactively selects a configuration key from a constant configuration file using fzf,
  then decodes and displays its corresponding value.

- **`shell::get_value_conf`**
  Retrieves and outputs the decoded value for a given configuration key from the key configuration file.
  _Example:_

  - `shell::get_value_conf my_setting`

- **`shell::fzf_remove_conf`**
  Interactively selects a configuration key from a constant configuration file using fzf,
  then removes the corresponding entry from the configuration file.
  _Example:_

  - `shell::fzf_remove_conf`
  - `shell::fzf_remove_conf -n`

- **`shell::fzf_update_conf`**
  Interactively updates the value for a configuration key in a constant configuration file.
  The new value is encoded using Base64 before updating the file.
  _Example:_

  - `shell::fzf_update_conf`
  - `shell::fzf_update_conf -n`

- **`shell::exist_key_conf`**
  Checks if a configuration key exists in the key configuration file.
  _Example:_

  - `shell::exist_key_conf <key>`
  - `shell::exist_key_conf my_setting`

- **`shell::fzf_rename_key_conf`**
  Renames an existing configuration key in the key configuration file.
  _Example:_

  - `shell::fzf_rename_key_conf [-n]`

- **`shell::is_protected_key`**
  Checks if the specified configuration key is protected.
  _Example:_

  - `shell::is_protected_key <key>`

- **`shell::add_group`**
  Groups selected configuration keys under a specified group name.
  _Example:_

  - `shell::add_group [-n]`

- **`shell::read_group`**
  Reads and displays the configurations for a given group by group name.
  _Example:_

  - `shell::read_group <group_name>`
  - `shell::read_group my_group`

- **`shell::fzf_remove_group`**
  Interactively selects a group name from the group configuration file using fzf,
  then removes the corresponding group entry.
  _Example:_

  - `shell::fzf_remove_group [-n]`

- **`shell::fzf_update_group`**
  Interactively updates an existing group by letting you select new keys for that group.
  _Example:_

  - `shell::fzf_update_group [-n]`

- **`shell::fzf_rename_group`**
  Renames an existing group in the group configuration file.
  _Example:_

  - `shell::fzf_rename_group [-n]`

- **`shell::list_groups`**
  Lists all group names defined in the group configuration file.

- **`shell::fzf_select_group`**
  Interactively selects a group name from the group configuration file using fzf,
  then lists all keys belonging to the selected group and uses fzf to choose one key,
  finally displaying the decoded value for the selected key.

- **`shell::fzf_clone_group`**
  Clones an existing group by creating a new group with the same keys.
  _Example:_

  - `shell::fzf_clone_group [-n]`

- **`shell::sync_key_group_conf`**
  Synchronizes group configurations by ensuring that each group's keys exist in the key configuration file.
  If a key listed in a group does not exist, it is removed from that group.
  If a group ends up with no valid keys, that group entry is removed.
  _Example:_

  - `shell::sync_key_group_conf [-n]`

- **`shell::send_telegram_message`**
  Sends a message via the Telegram Bot API.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
    - token : The Telegram Bot API token.
    - chat_id : The chat identifier where the message should be sent.
    - message : The message text to send.

  - `shell::send_telegram_message [-n] <token> <chat_id> <message>`

- **`shell::send_telegram_historical_gh_message`**
  Sends a historical GitHub-related message via Telegram using stored configuration keys.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
    - message : The message text to send.

  - `shell::send_telegram_historical_gh_message [-n] <message>`

- **`shell::send_telegram_attachment`**
  Sends one or more attachments (files) via Telegram using the Bot API asynchronously.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
    - token : The Telegram Bot API token.
    - chat_id : The chat identifier where the message should be sent.
    - description: A text description that is appended to each attachment's caption along with a timestamp.
    - filename_X: One or more filenames of the attachments to send.

  - `shell::send_telegram_attachment [-n] <token> <chat_id> <description> [filename_1] [filename_2] [filename_3] ...`

- **`shell::fzf_zip_attachment`**
  Zips selected files from a specified folder and outputs the absolute path of the created zip file.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
    - folder_path : The folder (directory) from which to select files for zipping.

  - `shell::fzf_zip_attachment [-n] <folder_path>`

- **`shell::fzf_current_zip_attachment`**
  Reuses shell::fzf_zip_attachment to zip selected files from the current directory, then renames the resulting zip file to use the current directory's basename and places it inside the current directory.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.

  - `shell::fzf_current_zip_attachment [-n]`

- **`shell::fzf_send_telegram_attachment`**
  Uses fzf to interactively select one or more files from a folder (default: current directory), and sends them as attachments via the Telegram Bot API by reusing shell::send_telegram_attachment.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
    - token: The Telegram Bot API token.
    - chat_id: The chat identifier where the attachments are sent.
    - description: A text description appended to each attachment's caption along with a timestamp.
    - folder_path: (Optional) The folder to search for files; defaults to the current directory if not provided.

  - `shell::fzf_send_telegram_attachment [-n] <token> <chat_id> <description> [folder_path]`
