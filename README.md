# shell

A comprehensive shell library to streamline your development environment setup on Linux and macOS. This lightweight library provides over 200 functions organized across multiple domains including file management, bookmark systems, configuration management, DevOps automation, language support, security utilities, and AI integration.

## Features

- **🔧 Core System Functions**: Version management, OS detection, package management
- **📁 File & Directory Management**: FZF-powered interactive file operations and archiving
- **🔖 Bookmark System**: Quick directory navigation with persistent bookmarks
- **⚙️ Configuration Management**: Key-value storage with Base64 encoding and grouping
- **🚀 Project Templates**: Support for Go, Node.js, Java, Angular, Python projects
- **🔄 DevOps & CI/CD**: GitHub Actions workflow generation
- **📦 Package Management**: Homebrew and Oh My Zsh integration
- **🔐 Security & Encryption**: AES-256-CBC encryption utilities
- **🧹 String Utilities**: Text sanitization and formatting functions
- **💬 Communication & Bots**: Telegram Bot API integration
- **🤖 AI & LLM Integration**: Gemini agent for translation and AI tasks
- **🌐 Git & Repository Management**: GitHub API integration and repository utilities
- **💼 Workspace Management**: SSH tunneling and workspace configuration
- **🔨 System Utilities**: Process management, port checking, and system analysis

## Structure

```bash
shell/
├── install.sh                 # Installation script
├── upgrade.sh                 # Upgrade script
├── uninstall.sh               # Uninstallation script
├── Makefile                   # Build and test automation
└── src/
    ├── shell.sh               # Main entry point
    ├── lib/                   # Core library functions
    │   ├── common.sh          # System utilities and basic operations
    │   ├── bookmark.sh        # Bookmark management system
    │   ├── key.sh             # Configuration key-value management
    │   ├── fuzzy.sh           # FZF-powered file operations
    │   ├── goto.sh            # Directory navigation utilities
    │   ├── workspace.sh       # Workspace and SSH management
    │   ├── ssh.sh             # SSH key and tunnel management
    │   ├── strings.sh         # String manipulation utilities
    │   ├── homebrew.sh        # Homebrew package manager
    │   ├── oh_my_zsh.sh       # Oh My Zsh integration
    │   └── ...                # Additional utility modules
    ├── lang/                  # Language-specific support
    │   ├── go.sh              # Go development utilities
    │   ├── python.sh          # Python environment management
    │   ├── nodejs.sh          # Node.js project utilities
    │   ├── java.sh            # Java project utilities
    │   ├── angular.sh         # Angular project utilities
    │   └── git.sh             # Git and GitHub integration
    ├── devops/                # DevOps and CI/CD utilities
    │   └── ci.sh              # GitHub Actions workflow generation
    ├── shield/                # Security and encryption
    │   └── crypto.sh          # Cryptographic utilities
    ├── bot/                   # Communication integrations
    │   └── telegram.sh        # Telegram Bot API
    └── llm/                   # AI and LLM integration
        └── agents/
            └── gemini.sh      # Google Gemini AI agent
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

Access the shell library by opening your terminal and using the commands below. Each command is designed to streamline development environment management on Linux and macOS. Functions are organized by category for easy navigation.

## Complete Function Reference

### Core System Functions

Core functions for system management, version control, and basic operations.

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

- **`shell::stdout`**  
  Outputs text to the terminal with customizable foreground colors using `tput` and ANSI escape sequences. Requires a message and a color code (e.g., 46 for cyan).  
  _Example:_ `shell::stdout "Task completed" 46`

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

- **`shell::uninstall_package`**  
  Uninstalls a package using the OS-appropriate package manager.  
  _Example:_ `shell::uninstall_package git`

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

- **`shell::logger::cmd_copy`**  
  Prints a command to the terminal without executing it, useful for debugging or logging.  
  _Example:_ `shell::logger::cmd_copy ls -l`

- **`shell::check_port`**  
  Checks if a TCP port is in use (listening). Use `-n` to suppress output and return a status only.  
  _Examples:_

  - `shell::check_port 8080`
  - `shell::check_port 8080 -n`

- **`shell::kill_port`**  
  Terminates all processes listening on a specified TCP port. Use `-n` for silent operation.  
  _Examples:_

  - `shell::kill_port 8080`
  - `shell::kill_port 8080 -n`

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

- **`shell::list_bookmark`**
  Displays a formatted list of all bookmarks.
  _Example:_ `shell::list_bookmark`

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

- **`shell::add_key_conf`**
  Adds a configuration entry (key=value) to a constant configuration file.
  The value is encoded using Base64 before being saved.
  _Example:_

  - `shell::add_key_conf [-n] <key> <value>`
  - `shell::add_key_conf my_setting "some secret value" `
  - `shell::add_key_conf -n my_setting "some secret value"`

- **`shell::fzf_get_key_conf`**
  Interactively selects a configuration key from a constant configuration file using fzf,
  then decodes and displays its corresponding value.

- **`shell::get_key_conf_value`**
  Retrieves and outputs the decoded value for a given configuration key from the key configuration file.
  _Example:_

  - `shell::get_key_conf_value my_setting`

- **`shell::fzf_remove_key_conf`**
  Interactively selects a configuration key from a constant configuration file using fzf,
  then removes the corresponding entry from the configuration file.
  _Example:_

  - `shell::fzf_remove_key_conf`
  - `shell::fzf_remove_key_conf -n`

- **`shell::fzf_update_key_conf`**
  Interactively updates the value for a configuration key in a constant configuration file.
  The new value is encoded using Base64 before updating the file.
  _Example:_

  - `shell::fzf_update_key_conf`
  - `shell::fzf_update_key_conf -n`

- **`shell::exist_key_conf`**
  Checks if a configuration key exists in the key configuration file.
  _Example:_

  - `shell::exist_key_conf <key>`
  - `shell::exist_key_conf my_setting`

- **`shell::fzf_rename_key_conf`**
  Renames an existing configuration key in the key configuration file.
  _Example:_

  - `shell::fzf_rename_key_conf [-n]`

- **`shell::is_protected_key_conf`**
  Checks if the specified configuration key is protected.
  _Example:_

  - `shell::is_protected_key_conf <key>`

- **`shell::fzf_add_group_key_conf`**
  Groups selected configuration keys under a specified group name.
  _Example:_

  - `shell::fzf_add_group_key_conf [-n]`

- **`shell::read_group_key_conf`**
  Reads and displays the configurations for a given group by group name.
  _Example:_

  - `shell::read_group_key_conf <group_name>`
  - `shell::read_group_key_conf my_group`

- **`shell::fzf_remove_group_key_conf`**
  Interactively selects a group name from the group configuration file using fzf,
  then removes the corresponding group entry.
  _Example:_

  - `shell::fzf_remove_group_key_conf [-n]`

- **`shell::fzf_update_group_key_conf`**
  Interactively updates an existing group by letting you select new keys for that group.
  _Example:_

  - `shell::fzf_update_group_key_conf [-n]`

- **`shell::fzf_rename_group_key_conf`**
  Renames an existing group in the group configuration file.
  _Example:_

  - `shell::fzf_rename_group_key_conf [-n]`

- **`shell::list_group_key_conf`**
  Lists all group names defined in the group configuration file.

- **`shell::fzf_view_group_key_conf`**
  Interactively selects a group name from the group configuration file using fzf,
  then lists all keys belonging to the selected group and uses fzf to choose one key,
  finally displaying the decoded value for the selected key.

- **`shell::fzf_clone_group_key_conf`**
  Clones an existing group by creating a new group with the same keys.
  _Example:_

  - `shell::fzf_clone_group_key_conf [-n]`

- **`shell::sync_group_key_conf`**
  Synchronizes group configurations by ensuring that each group's keys exist in the key configuration file.
  If a key listed in a group does not exist, it is removed from that group.
  If a group ends up with no valid keys, that group entry is removed.
  _Example:_

  - `shell::sync_group_key_conf [-n]`

- **`shell::telegram::send`**
  Sends a message via the Telegram Bot API.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
    - token : The Telegram Bot API token.
    - chat_id : The chat identifier where the message should be sent.
    - message : The message text to send.

  - `shell::telegram::send [-n] <token> <chat_id> <message>`

- **`shell::git::telegram::send_activity`**
  Sends a historical GitHub-related message via Telegram using stored configuration keys.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
    - message : The message text to send.

  - `shell::git::telegram::send_activity [-n] <message>`

- **`shell::telegram::send_document`**
  Sends one or more attachments (files) via Telegram using the Bot API asynchronously.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
    - token : The Telegram Bot API token.
    - chat_id : The chat identifier where the message should be sent.
    - description: A text description that is appended to each attachment's caption along with a timestamp.
    - filename_X: One or more filenames of the attachments to send.

  - `shell::telegram::send_document [-n] <token> <chat_id> <description> [filename_1] [filename_2] [filename_3] ...`

- **`shell::fzf_zip_attachment`**
  Zips selected files from a specified folder and outputs the absolute path of the created zip file.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
    - folder_path : The folder (directory) from which to select files for zipping.

  - `shell::fzf_zip_attachment [-n] <folder_path>`

- **`shell::fzf_current_zip_attachment`**
  Reuses shell::fzf_zip_attachment to zip selected files from the current directory, then renames the resulting zip file to use the current directory's basename and places it inside the current directory.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.

  - `shell::fzf_current_zip_attachment [-n]`

- **`shell::fzf_send_telegram_attachment`**
  Uses fzf to interactively select one or more files from a folder (default: current directory), and sends them as attachments via the Telegram Bot API by reusing shell::telegram::send_document.

  - _Parameters_:

    - -n : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
    - token: The Telegram Bot API token.
    - chat_id: The chat identifier where the attachments are sent.
    - description: A text description appended to each attachment's caption along with a timestamp.
    - folder_path: (Optional) The folder to search for files; defaults to the current directory if not provided.

  - `shell::fzf_send_telegram_attachment [-n] <token> <chat_id> <description> [folder_path]`

### File & Directory Management

Interactive file operations powered by FZF (fuzzy finder) for enhanced user experience.

- **`shell::create_directory_if_not_exists`**  
  Creates a directory (including nested paths) if it does not already exist.  
  _Example:_ `shell::create_directory_if_not_exists /path/to/dir`

- **`shell::create_file_if_not_exists`**  
  Creates a file if it does not exist, leaving existing files unchanged.  
  _Example:_ `shell::create_file_if_not_exists config.txt`

- **`shell::copy_files`**  
  Copies a source file to one or more destination filenames in the current directory.  
  _Example:_ `shell::copy_files source.txt dest1.txt dest2.txt`

- **`shell::move_files`**  
  Moves one or more files to a specified destination directory.  
  _Example:_ `shell::move_files /path/to/dest file1.txt file2.txt`

- **`shell::remove_files`**  
  Deletes a file or directory recursively with elevated privileges (`sudo rm -rf`). Use with caution.  
  _Example:_ `shell::remove_files obsolete-dir`

- **`shell::unarchive`**  
  Extracts a compressed file based on its extension (e.g., `.zip`, `.tar.gz`). Use `-n` for no-overwrite mode.  
  _Examples:_

  - `shell::unarchive archive.zip`
  - `shell::unarchive -n archive.tar.gz`

- **`shell::fzf_copy`**  
  Interactively selects a file to copy and a destination directory using `fzf` for fuzzy finding.  
  _Example:_ `shell::fzf_copy`

- **`shell::fzf_move`**  
  Interactively selects a file to move and a destination directory using `fzf`.  
  _Example:_ `shell::fzf_move`

- **`shell::fzf_remove`**  
  Interactively selects a file or directory to remove using `fzf`.  
  _Example:_ `shell::fzf_remove`

- **`shell::unlock_permissions`**  
  Assigns full permissions (read, write, execute; `chmod 777`) to a file or directory.  
  _Example:_ `shell::unlock_permissions ./my_script.sh`

- **`shell::set_permissions`**  
  Sets specific permissions on files or directories.  
  _Example:_ `shell::set_permissions 755 ./script.sh`

- **`shell::fzf_set_permissions`**  
  Interactively select files and set permissions using FZF.  
  _Example:_ `shell::fzf_set_permissions`

- **`shell::analyze_permissions`**  
  Analyzes and displays permissions for files in a directory.  
  _Example:_ `shell::analyze_permissions`

### Bookmark System

Persistent bookmark system for quick directory navigation.

- **`shell::add_bookmark`**
  Adds a bookmark for the current directory with the specified name.
  _Example:_

  - `shell::add_bookmark project1`

- **`shell::remove_bookmark`**
  Deletes a bookmark with the specified name from the bookmarks file.
  _Example:_

  - `shell::remove_bookmark project1`

- **`shell::list_bookmark`**
  Displays a formatted list of all bookmarks.
  _Example:_ `shell::list_bookmark`

- **`shell::go_bookmark`**
  Navigates to the directory associated with the specified bookmark name.
  _Example:_

  - `shell::go_bookmark project1`

- **`shell::fzf_list_bookmark`**
  Interactively browse and navigate to bookmarks using FZF.
  _Example:_ `shell::fzf_list_bookmark`

- **`shell::fzf_remove_bookmark`**
  Interactively select and remove bookmarks using FZF.
  _Example:_ `shell::fzf_remove_bookmark`

- **`shell::rename_bookmark`**
  Renames an existing bookmark.
  _Example:_ `shell::rename_bookmark old_name new_name`

- **`shell::fzf_rename_bookmark`**
  Interactively rename bookmarks using FZF.
  _Example:_ `shell::fzf_rename_bookmark`

- **`shell::goto`**
  Main function to handle user commands and navigate directories.
  _Example:_
  - `shell::goto [command]`
  - Use `shell::goto` for help

### Configuration Management

Secure key-value storage system with Base64 encoding and group management.

- **`shell::read_conf`**
  Sources a configuration file, allowing its variables and functions to be loaded into the current shell.
  _Example:_

  - `shell::read_conf ~/.my-config`
  - `shell::read_conf -n ~/.my-config`

- **`shell::add_key_conf`**
  Adds a configuration entry (key=value) to a constant configuration file.
  The value is encoded using Base64 before being saved.
  _Example:_

  - `shell::add_key_conf my_setting "some secret value"`
  - `shell::add_key_conf -n my_setting "some secret value"`

- **`shell::get_key_conf_value`**
  Retrieves and outputs the decoded value for a given configuration key from the key configuration file.
  _Example:_

  - `shell::get_key_conf_value my_setting`

- **`shell::fzf_get_key_conf`**
  Interactively selects a configuration key from a constant configuration file using fzf,
  then decodes and displays its corresponding value.
  _Example:_ `shell::fzf_get_key_conf`

- **`shell::fzf_remove_key_conf`**
  Interactively selects a configuration key from a constant configuration file using fzf,
  then removes the corresponding entry from the configuration file.
  _Example:_ `shell::fzf_remove_key_conf`

- **`shell::fzf_update_key_conf`**
  Interactively updates the value for a configuration key in a constant configuration file.
  _Example:_ `shell::fzf_update_key_conf`

- **`shell::exist_key_conf`**
  Checks if a configuration key exists in the key configuration file.
  _Example:_ `shell::exist_key_conf my_setting`

- **`shell::fzf_rename_key_conf`**
  Renames an existing configuration key in the key configuration file.
  _Example:_ `shell::fzf_rename_key_conf`

#### Configuration Groups

Group-based configuration management for organizing related keys.

- **`shell::fzf_add_group_key_conf`**
  Groups selected configuration keys under a specified group name.
  _Example:_ `shell::fzf_add_group_key_conf`

- **`shell::read_group_key_conf`**
  Reads and displays the configurations for a given group by group name.
  _Example:_ `shell::read_group_key_conf my_group`

- **`shell::fzf_remove_group_key_conf`**
  Interactively selects a group name from the group configuration file using fzf,
  then removes the corresponding group entry.
  _Example:_ `shell::fzf_remove_group_key_conf`

- **`shell::list_group_key_conf`**
  Lists all group names defined in the group configuration file.
  _Example:_ `shell::list_group_key_conf`

- **`shell::fzf_view_group_key_conf`**
  Interactively selects a group and displays key values.
  _Example:_ `shell::fzf_view_group_key_conf`

- **`shell::sync_group_key_conf`**
  Synchronizes group configurations by ensuring that each group's keys exist in the key configuration file.
  _Example:_ `shell::sync_group_key_conf`

### Project Templates & Language Support

Utilities for various programming languages and project initialization.

#### Go Development

- **`shell::go::module::create`**
  Creates a new Go application with proper structure.
  _Example:_ `shell::go::module::create myapp`

- **`shell::go::env::set_private`**
  Sets up private Go module configuration.
  _Example:_ `shell::go::env::set_private github.com/myorg`

- **`shell::go::env::get_private`**
  Retrieves current private Go module settings.
  _Example:_ `shell::go::env::get_private`

- **`shell::go::env::remove_private_fzf`**
  Interactively remove private Go module settings.
  _Example:_ `shell::go::env::remove_private_fzf`

- **`shell::go::gitignore::add`**
  Adds Go-specific .gitignore file to the current project.
  _Example:_ `shell::go::gitignore::add`

#### Python Development

- **`shell::python::install`**
  Installs Python using the system package manager.
  _Example:_ `shell::python::install 3.11`

- **`shell::python::venv::create`**
  Creates a new Python virtual environment.
  _Example:_ `shell::python::venv::create myenv`

- **`shell::python::venv::activate_fzf`**
  Interactively activate a Python virtual environment.
  _Example:_ `shell::python::venv::activate_fzf`

- **`shell::python::venv::pkg::install`**
  Installs packages in the active Python environment.
  _Example:_ `shell::python::venv::pkg::install requests pandas`

- **`shell::python::venv::pkg::freeze`**
  Generates requirements.txt from current environment.
  _Example:_ `shell::python::venv::pkg::freeze`

- **`shell::python::gitignore::add`**
  Adds Python-specific .gitignore file to the current project.
  _Example:_ `shell::python::gitignore::add`

#### Node.js Development

- **`shell::nodejs::gitignore::add`**
  Adds Node.js-specific .gitignore file to the current project.
  _Example:_ `shell::nodejs::gitignore::add`

#### Java Development

- **`shell::java::gitignore::add`**
  Adds Java-specific .gitignore file to the current project.
  _Example:_ `shell::java::gitignore::add`

#### Angular Development

- **`shell::angular::gitignore::add`**
  Adds Angular-specific .gitignore file to the current project.
  _Example:_ `shell::angular::gitignore::add`

### DevOps & CI/CD

GitHub Actions workflow generation and DevOps automation.

- **`shell::gh::workflow::base::add`**
  Adds a base GitHub Actions workflow configuration.
  _Example:_ `shell::gh::workflow::base::add`

- **`shell::gh::workflow::news::add`**
  Adds a news/notification GitHub Actions workflow.
  _Example:_ `shell::gh::workflow::news::add`

- **`shell::gh::workflow::bash::add_format`**
  Adds a shell script formatting GitHub Actions workflow.
  _Example:_ `shell::gh::workflow::bash::add_format`

### Package Management

System package managers and development tool installation.

#### Homebrew Integration

- **`shell::install_homebrew`**
  Installs Homebrew using the official installation script.
  _Example:_ `shell::install_homebrew`

- **`shell::removal_homebrew`**
  Uninstalls Homebrew from the system.
  _Example:_ `shell::removal_homebrew`

#### Oh My Zsh Integration

- **`shell::install_oh_my_zsh`**
  Installs Oh My Zsh if it is not already present on the system.
  _Example:_ `shell::install_oh_my_zsh`

- **`shell::removal_oh_my_zsh`**
  Uninstalls Oh My Zsh by removing its directory and restoring the original .zshrc backup if available.
  _Example:_ `shell::removal_oh_my_zsh`

### Security & Encryption

AES-256-CBC encryption utilities for secure data handling.

- **`shell::generate_random_key`**
  Generates a random encryption key for use with AES-256-CBC.
  _Example:_ `shell::generate_random_key`

### String Utilities

Text manipulation and sanitization functions.

- **`shell::strings::sanitize::upper`**
  Converts text to uppercase variable naming convention.
  _Example:_ `shell::strings::sanitize::upper "my variable name"`

- **`shell::sanitize_lower_var_name`**
  Converts text to lowercase variable naming convention.
  _Example:_ `shell::sanitize_lower_var_name "My Variable Name"`

- **`shell::camel_case`**
  Converts text to camelCase format.
  _Example:_ `shell::camel_case "my variable name"`

- **`shell::capitalize_each_word`**
  Capitalizes the first letter of each word.
  _Example:_ `shell::capitalize_each_word "hello world"`

- **`shell::sanitize_text`**
  General text sanitization function.
  _Example:_ `shell::sanitize_text "text with special chars!"`

### Communication & Bots

Telegram Bot API integration for notifications and file sharing.

- **`shell::telegram::send`**
  Sends a message via the Telegram Bot API.
  _Parameters_:

  - -n : Optional dry-run flag
  - token : The Telegram Bot API token
  - chat_id : The chat identifier where the message should be sent
  - message : The message text to send
    _Example:_ `shell::telegram::send <token> <chat_id> "Hello, World!"`

- **`shell::telegram::send_document`**
  Sends one or more attachments (files) via Telegram using the Bot API asynchronously.
  _Example:_ `shell::telegram::send_document <token> <chat_id> "Files" file1.txt file2.txt`

- **`shell::git::telegram::send_activity`**
  Sends a historical GitHub-related message via Telegram using stored configuration keys.
  _Example:_ `shell::git::telegram::send_activity "Deployment completed"`

### AI & LLM Integration

Google Gemini AI agent integration for translation and AI tasks.

- **`shell::make_gemini_request`**
  Makes a request to the Google Gemini API.
  _Example:_ `shell::make_gemini_request "Translate this text"`

- **`shell::eval_gemini_en_vi`**
  Translates English text to Vietnamese using Gemini.
  _Example:_ `shell::eval_gemini_en_vi "Hello, how are you?"`

- **`shell::eval_gemini_vi_en`**
  Translates Vietnamese text to English using Gemini.
  _Example:_ `shell::eval_gemini_vi_en "Xin chào, bạn khỏe không?"`

- **`shell::populate_gemini_conf`**
  Sets up Gemini configuration.
  _Example:_ `shell::populate_gemini_conf`

- **`shell::fzf_view_gemini_conf`**
  Interactively view Gemini configuration using FZF.
  _Example:_ `shell::fzf_view_gemini_conf`

### Git & Repository Management

GitHub API integration and repository utilities.

- **`shell::git::release::version::get`**
  Retrieves the latest release information from a GitHub repository.
  _Example:_ `shell::git::release::version::get pnguyen215/shell`

- **`shell::retrieve_gh_repository_info`**
  Retrieves repository information from GitHub.
  _Example:_ `shell::retrieve_gh_repository_info pnguyen215/shell`

- **`shell::retrieve_current_gh_default_branch`**
  Gets the default branch of the current repository.
  _Example:_ `shell::retrieve_current_gh_default_branch`

- **`shell::retrieve_current_gh_current_branch`**
  Gets the current branch of the repository.
  _Example:_ `shell::retrieve_current_gh_current_branch`

### Workspace Management

SSH tunneling and workspace configuration management.

- **`shell::add_workspace`**
  Adds a new workspace configuration.
  _Example:_ `shell::add_workspace myworkspace`

- **`shell::fzf_view_workspace`**
  Interactively view workspace configurations.
  _Example:_ `shell::fzf_view_workspace`

- **`shell::fzf_manage_workspace`**
  Interactively manage workspace configurations.
  _Example:_ `shell::fzf_manage_workspace`

- **`shell::open_workspace_ssh_tunnel`**
  Opens SSH tunnel for a workspace.
  _Example:_ `shell::open_workspace_ssh_tunnel myworkspace`

- **`shell::fzf_open_workspace_ssh_tunnel`**
  Interactively open SSH tunnels using FZF.
  _Example:_ `shell::fzf_open_workspace_ssh_tunnel`

### SSH Management

SSH key and tunnel management utilities.

- **`shell::gen_ssh_key`**
  Generates a new SSH key pair.
  _Example:_ `shell::gen_ssh_key mykey`

- **`shell::fzf_view_ssh_key`**
  Interactively view SSH keys using FZF.
  _Example:_ `shell::fzf_view_ssh_key`

- **`shell::open_ssh_tunnel`**
  Opens an SSH tunnel with specified parameters.
  _Example:_ `shell::open_ssh_tunnel user@host:port`

- **`shell::list_ssh_tunnels`**
  Lists active SSH tunnels.
  _Example:_ `shell::list_ssh_tunnels`

- **`shell::fzf_kill_ssh_tunnels`**
  Interactively kill SSH tunnels using FZF.
  _Example:_ `shell::fzf_kill_ssh_tunnels`

### System Utilities

Process management, port checking, and system analysis tools.

- **`shell::get_os_type`**  
  Identifies and returns the current operating system type as a standardized string (e.g., "linux" or "macos").  
  _Example:_ `shell::get_os_type`

- **`shell::stdout`**  
  Outputs text to the terminal with customizable foreground colors using `tput` and ANSI escape sequences. Requires a message and a color code (e.g., 46 for cyan).  
  _Example:_ `shell::stdout "Task completed" 46`

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

- **`shell::uninstall_package`**  
  Uninstalls a package using the OS-appropriate package manager.  
  _Example:_ `shell::uninstall_package git`

- **`shell::list_packages_installed`**  
  Lists all packages installed on the system via the native package manager.  
  _Example:_ `shell::list_packages_installed`

- **`shell::clip_cwd`**  
  Copies the current working directory path to the system clipboard.  
  _Example:_ `shell::clip_cwd`

- **`shell::clip_value`**  
  Copies a specified text string to the system clipboard.  
  _Example:_ `shell::clip_value "Hello, World!"`

- **`shell::get_temp_dir`**  
  Returns the OS-appropriate temporary directory path (e.g., `/tmp` on Linux).  
  _Example:_ `TEMP_DIR=$(shell::get_temp_dir)`

- **`shell::check_port`**  
  Checks if a TCP port is in use (listening). Use `-n` to suppress output and return a status only.  
  _Examples:_

  - `shell::check_port 8080`
  - `shell::check_port 8080 -n`

- **`shell::kill_port`**  
  Terminates all processes listening on a specified TCP port. Use `-n` for silent operation.  
  _Examples:_

  - `shell::kill_port 8080`
  - `shell::kill_port 8080 -n`

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

- **`shell::editor`**  
  Opens a file from a specified directory in a chosen text editor. Use `-n` to open in a new instance (if supported).  
  _Examples:_

  - `shell::editor ~/documents`
  - `shell::editor -n ~/documents`

- **`shell::download_dataset`**  
  Downloads a file from a URL and saves it with the specified filename.  
  _Example:_ `shell::download_dataset data.zip https://example.com/data.zip`

- **`shell::validate_ip_addr`**
  Validates if a string is a valid IP address.
  _Example:_ `shell::validate_ip_addr 192.168.1.1`

- **`shell::validate_hostname`**
  Validates if a string is a valid hostname.
  _Example:_ `shell::validate_hostname example.com`

- **`shell::get_mime_type`**
  Gets the MIME type of a file.
  _Example:_ `shell::get_mime_type document.pdf`

## Practical Usage Examples

### Configuration Management Workflow

```bash
# Add configuration keys
shell::add_key_conf database_url "postgresql://user:pass@localhost:5432/mydb"
shell::add_key_conf api_key "your-secret-api-key"
shell::add_key_conf debug_mode "true"

# Group related configurations
shell::fzf_add_group_key_conf  # Select keys and group them as "development"

# Retrieve configuration values
DB_URL=$(shell::get_key_conf_value database_url)
API_KEY=$(shell::get_key_conf_value api_key)

# View all configurations in a group
shell::read_group_key_conf development
```

### Bookmark System Usage

```bash
# Navigate to project directories and bookmark them
cd ~/projects/webapp
shell::add_bookmark webapp

cd ~/projects/api-service
shell::add_bookmark api

cd ~/projects/mobile-app
shell::add_bookmark mobile

# Quick navigation
shell::go_bookmark webapp        # Direct navigation
shell::fzf_list_bookmark        # Interactive selection
shell::list_bookmark            # View all bookmarks
```

### Project Initialization

```bash
# Initialize a Go project
shell::go::module::create mygoapp
cd mygoapp
shell::go::gitignore::add

# Set up Python environment
shell::python::venv::create myproject
shell::python::venv::activate_fzf  # Activate environment
shell::python::venv::pkg::install requests flask pandas
shell::python::venv::pkg::freeze > requirements.txt
```

### DevOps Integration

```bash
# Add GitHub Actions workflows
shell::gh::workflow::base::add          # Base CI/CD workflow
shell::gh::workflow::news::add          # Notification workflow
shell::gh::workflow::bash::add_format     # Shell script formatting

# Send deployment notifications
shell::git::telegram::send_activity "Deployment to production completed successfully"
```

### Encryption Utilities

```bash
# Generate encryption key
KEY=$(shell::generate_random_key)

# Store sensitive configuration securely
shell::add_key_conf encryption_key "$KEY"
shell::add_key_conf database_password "super-secret-password"

# Keys are automatically Base64 encoded for storage
```

### Workspace and SSH Management

```bash
# Set up workspace
shell::add_workspace production
shell::add_workspace_ssh_conf production

# Generate SSH key
shell::gen_ssh_key production-key

# Open SSH tunnel
shell::open_ssh_tunnel user@production-server.com:22

# Interactive workspace management
shell::fzf_manage_workspace
shell::fzf_open_workspace_ssh_tunnel
```

### AI Integration Workflow

```bash
# Set up Gemini configuration
shell::populate_gemini_conf

# Translation services
shell::eval_gemini_en_vi "Hello, how are you today?"
shell::eval_gemini_vi_en "Xin chào, bạn khỏe không?"

# Make custom AI requests
shell::make_gemini_request "Explain the benefits of shell scripting"
```

## Advanced Features

### Interactive FZF Integration

Most functions support FZF (fuzzy finder) for enhanced interactivity:

- `shell::fzf_*` functions provide interactive selection interfaces
- Real-time filtering and search capabilities
- Keyboard navigation with arrow keys and Enter to select

### Secure Configuration Management

- All configuration values are Base64 encoded for basic obfuscation
- Group-based organization for related settings
- Protected keys system for sensitive data
- Synchronization utilities to maintain data integrity

### Cross-Platform Compatibility

- Automatic OS detection and appropriate command usage
- macOS-specific functions (e.g., `shell::opent` for Finder integration)
- Linux-specific optimizations
- Package manager abstraction (Homebrew for macOS, apt/yum for Linux)

### Asynchronous Operations

- Background execution support with `shell::async`
- Non-blocking operations for time-intensive tasks
- Process management and monitoring utilities

## Contributing

This library follows a modular architecture. Each module is self-contained and focuses on specific functionality:

- Add new functions to appropriate modules in `src/lib/`, `src/lang/`, etc.
- Follow the `shell::function_name` naming convention
- Include comprehensive documentation and examples
- Test your functions with both Linux and macOS environments

## License

This project is open source and available under the MIT License.
