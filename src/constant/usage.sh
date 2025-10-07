#!/bin/bash
# usage.sh

USAGE_SHELL_GEN_SSH_KEY="
shell::gen_ssh_key function
Generates an SSH key pair (private and public) and saves them to the SSH directory.

Usage:
  shell::gen_ssh_key [-n] [-t key_type] [-p passphrase] [-h] [email] [key_filename]

Parameters:
  - -n              : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -t key_type     : Optional. Specifies the key type (e.g., rsa, ed25519). Defaults to rsa.
  - -p passphrase   : Optional. Specifies the passphrase for the key. Defaults to empty (no passphrase).
  - -h              : Optional. Displays this help message.
  - [email]         : Optional. The email address to be included in the comment field of the SSH key.
                      Defaults to an empty string if not provided.
  - [key_filename]  : Optional. The name of the key file to generate within the SSH directory.
                      Defaults to 'id_rsa' if not provided.

Description:
  This function creates the SSH directory (defaults to $HOME/.ssh)
  if it doesn't exist and generates an SSH key pair using ssh-keygen. It supports specifying the key type,
  passphrase, email comment, and filename. The function ensures the ssh-keygen command is available,
  checks for existing keys, and sets appropriate permissions on generated files.

Example usage:
  shell::gen_ssh_key                                    # Generates rsa key in ~/.ssh/id_rsa with no comment or passphrase.
  shell::gen_ssh_key \"user@example.com\"               # Generates rsa key with email, saved as ~/.ssh/id_rsa.
  shell::gen_ssh_key -t ed25519 \"user@example.com\"    # Generates ed25519 key with email.
  shell::gen_ssh_key \"\" \"my_key\"                    # Generates rsa key with no comment, saved as ~/.ssh/my_key.
  shell::gen_ssh_key -n \"user@example.com\" \"my_key\" # Dry-run: prints the command without executing.
  shell::gen_ssh_key -h                                 # Displays this help message.
"

USAGE_SHELL_KILL_SSH_TUNNEL="
shell::kill_ssh_tunnels function
Kills all active SSH tunnel forwarding processes.

Usage:
  shell::kill_ssh_tunnels [-n] [-h]

Parameters:
  - -n              : Optional dry-run flag. If provided, kill commands are printed using shell::logger::cmd_copy instead of executed.
  - -h              : Optional. Displays this help message.

Description:
  This function identifies all SSH processes that are using port forwarding options
  (-L, -R, or -D) [cite: 12] and attempts to terminate them using the 'kill' command.
  It works cross-platform on both macOS and Linux systems.
  Confirmation is requested before killing processes unless the dry-run flag is used.

Example usage:
  shell::kill_ssh_tunnels       # Kills active SSH tunnels after confirmation.
  shell::kill_ssh_tunnels -n    # Shows kill commands that would be executed (dry-run mode).

Notes:
  - Requires the 'ps' and 'kill' commands to be available.
  - Works on both macOS and Linux systems.
  - Uses different parsing approaches based on the detected operating system.
  - Leverages shell::run_cmd for command execution and shell::logger::cmd_copy for dry-run mode.
"

USAGE_SHELL_LIST_SSH_TUNNEL="
shell::list_ssh_tunnels function
Displays information about active SSH tunnel forwarding processes in a line-by-line format.

Usage:
  shell::list_ssh_tunnels [-n] [-h]

Parameters:
  - -n              : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
  - -h              : Optional. Displays this help message.

Description:
  This function identifies and displays all SSH processes that are using port forwarding options
  (-L, -R, or -D). It shows detailed information about each process including PID, username,
  start time, elapsed time, command, and specific forwarding details (local port, forwarding type,
  remote port, remote host). The function works cross-platform on both macOS and Linux systems.

Output Fields:
  - PID: Process ID of the SSH tunnel
  - USER: Username running the SSH tunnel
  - START: Start time of the process
  - TIME: Elapsed time the process has been running
  - COMMAND: The SSH command path
  - LOCAL_PORT: The local port being forwarded
  - FORWARD_TYPE: Type of forwarding (-L for local, -R for remote, -D for dynamic)
  - REMOTE_PORT: The remote port
  - REMOTE_HOST: The remote host

Example usage:
  shell::list_ssh_tunnels           # Display active SSH tunnels
  shell::list_ssh_tunnels -n        # Show commands that would be executed (dry-run mode)

Notes:
  - Requires the 'ps' command to be available
  - Works on both macOS and Linux systems
  - Uses different parsing approaches based on the detected operating system
  - Leverages shell::run_cmd_eval for command execution and shell::logger::cmd_copy for dry-run mode
"

USAGE_SHELL_FZF_CWD_SSH_KEY="
shell::fzf_cwd_ssh_key function
Interactively selects an SSH key file (private or public) from $HOME/.ssh using fzf,
displays the absolute path of the selected file, and copies the path to the clipboard.

Usage:
  shell::fzf_cwd_ssh_key [-h]

Parameters:
  - -h              : Optional. Displays this help message.

Description:
  This function lists files within the user's SSH directory ($HOME/.ssh).
  It filters out common non-key files and then uses fzf to provide an interactive selection interface.
  Once a file is selected, its absolute path is determined, displayed to the user,
  and automatically copied to the system clipboard using the shell::clip_value function.

Example usage:
  shell::fzf_cwd_ssh_key # Launch fzf to select an SSH key and copy its path.

Requirements:
  - fzf must be installed.
  - The user must have a $HOME/.ssh directory.
  - Assumes the presence of helper functions: shell::install_package, shell::stdout, shell::clip_value, and shell::is_command_available.
"

USAGE_SHELL_FZF_KILL_SSH_TUNNEL="
shell::fzf_kill_ssh_tunnels function
Interactively selects one or more SSH tunnel processes using fzf and kills them.

Usage:
  shell::fzf_kill_ssh_tunnels [-h]

Parameters:
  - -h              : Optional. Displays this help message.

Description:
  This function identifies potential SSH tunnel processes by searching for 'ssh'
  commands with port forwarding flags (-L, -R, or -D). It presents a list of
  these processes, including their PIDs and command details, in an fzf interface
  for interactive selection. The user can select one or multiple processes.
  After selection, the user is prompted for confirmation before the selected
  processes are terminated using the (kill) command.

Example usage:
  shell::fzf_kill_ssh_tunnels # Launch fzf to select and kill SSH tunnels.

Requirements:
  - fzf must be installed.
  - Assumes the presence of helper functions: shell::install_package, shell::stdout, shell::run_cmd_eval.
"

USAGE_SHELL_READ_CONF="
shell::read_conf function
Sources a configuration file, allowing its variables and functions to be loaded into the current shell.

Usage:
  shell::read_conf [-n] [-h] <filename>

Parameters:
  - -n              : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h              : Optional. Displays this help message.
  - <filename>      : The configuration file to source.

Description:
  The function checks that a filename is provided and that the specified file exists.
  If the file is not found, an error message is displayed.
  In dry-run mode, the command 'source <filename >' is printed using shell::logger::cmd_copy.
  Otherwise, the file is sourced using shell::run_cmd to log the execution.

Example:
  shell::read_conf ~/.my-config                # Sources the configuration file.
  shell::read_conf -n ~/.my-config             # Prints the sourcing command without executing it.
"

USAGE_SHELL_ADD_KEY_CONF="
shell::add_key_conf function
Adds a configuration entry (key=value) to a constant configuration file.
The value is encoded using Base64 before being saved.

Usage:
  shell::add_key_conf [-n] [-h] <key> <value>

Parameters:
  - -n       : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h       : Optional. Displays this help message.
  - <key>    : The configuration key.
  - <value>  : The configuration value to be encoded and saved.

Description:
  The function first checks for an optional dry-run flag (-n) and verifies that both key and value are provided.
  It encodes the value using Base64 (with newline characters removed) and then appends a line in the format:
      key=encoded_value
  to a constant configuration file (defined by SHELL_KEY_CONF_FILE). If the configuration file does not exist, it is created.

Example:
  shell::add_key_conf my_setting \"some secret value\"         # Encodes the value and adds the entry.
  shell::add_key_conf -n my_setting \"some secret value\"      # Prints the command without executing it.
"

USAGE_SHELL_FZF_GET_KEY_CONF="
shell::fzf_get_key_conf function
Interactively selects a configuration key from a constant configuration file using fzf,
then decodes and displays its corresponding value.

Usage:
  shell::fzf_get_key_conf [-h]

Parameters:
  - -h              : Optional. Displays this help message.

Description:
  The function reads the configuration file defined by the constant SHELL_KEY_CONF_FILE,
  which is expected to have entries in the format:
      key=encoded_value
  Instead of listing the entire line, it extracts only the keys (before the '=') and uses fzf
  for interactive selection. Once a key is selected, it looks up the full entry,
  decodes the Base64-encoded value (using -D on macOS and -d on Linux), and then displays the key
  and its decoded value.

Example:
  shell::fzf_get_key_conf      # Interactively select a key and display its decoded value.
"

USAGE_SHELL_GET_KEY_CONF_VALUE="
shell::get_key_conf_value function
Retrieves and outputs the decoded value for a given configuration key from the key configuration file.

Usage:
  shell::get_key_conf_value [-h] <key>

Parameters:
  - -h              : Optional. Displays this help message.
  - <key>           : The configuration key whose value should be retrieved.

Description:
  This function searches for the specified key in the configuration file defined by SHELL_KEY_CONF_FILE.
  The configuration file is expected to have entries in the format:
      key=encoded_value
  If the key is found, the function decodes the associated Base64‑encoded value (using -D on macOS and -d on Linux)
  and outputs the decoded value to standard output.

Example:
  shell::get_key_conf_value my_setting   # Outputs the decoded value for the key 'my_setting'.
"

USAGE_SHELL_FZF_REMOVE_KEY_CONF="
shell::fzf_remove_key_conf function
Interactively selects a configuration key from a constant configuration file using fzf,
then removes the corresponding entry from the configuration file.

Usage:
  shell::fzf_remove_key_conf [-n] [-h]

Parameters:
  - -n              : Optional dry-run flag. If provided, the removal command is printed using shell::logger::cmd_copy instead of executed.
  - -h              : Optional. Displays this help message.

Description:
  The function reads the configuration file defined by the constant SHELL_KEY_CONF_FILE, where each entry is in the format:
      key=encoded_value
  It extracts only the keys (before the '=') and uses fzf for interactive selection.
  Once a key is selected, it constructs a command to remove the line that starts with \"key=\" from the configuration file.
  The command uses sed with different options depending on the operating system (macOS or Linux).
  In dry-run mode, the command is printed using shell::logger::cmd_copy; otherwise, it is executed using shell::run_cmd_eval.

Example:
  shell::fzf_remove_key_conf         # Interactively select a key and remove its configuration entry.
  shell::fzf_remove_key_conf -n      # Prints the removal command without executing it.
"

USAGE_SHELL_FZF_UPDATE_KEY_CONF="
shell::fzf_update_key_conf function
Interactively updates the value for a configuration key in a constant configuration file.
The new value is encoded using Base64 before updating the file.

Usage:
  shell::fzf_update_key_conf [-n] [-h]

Parameters:
  - -n              : Optional dry-run flag. If provided, the update command is printed using shell::logger::cmd_copy instead of executed.
  - -h              : Optional. Displays this help message.

Description:
  The function reads the configuration file defined by SHELL_KEY_CONF_FILE, which contains entries in the format:
      key=encoded_value
  It extracts only the keys and uses fzf to allow interactive selection.
  Once a key is selected, the function prompts for a new value, encodes it using Base64 (with newlines removed),
  and then updates the corresponding configuration entry in the file by replacing the line starting with \"key=\".
  The sed command used for in-place update differs between macOS and Linux.

Example:
  shell::fzf_update_key_conf       # Interactively select a key, enter a new value, and update its entry.
  shell::fzf_update_key_conf -n    # Prints the update command without executing it.
"

USAGE_SHELL_EXIST_KEY_CONF="
shell::exist_key_conf function
Checks if a configuration key exists in the key configuration file.

Usage:
  shell::exist_key_conf [-h] <key>

Parameters:
  - -h   : Optional. Displays this help message.
  - <key>: The configuration key to check.

Description:
  This function searches for the specified key in the configuration file defined by SHELL_KEY_CONF_FILE.
  The configuration file should have entries in the format:
      key=encoded_value
  If a line starting with \"key=\" is found, the function echoes \"true\" and returns 0.
  Otherwise, it echoes \"false\" and returns 1.
"

USAGE_SHELL_FZF_RENAME_KEY_CONF="
shell::fzf_rename_key_conf function
Renames an existing configuration key in the key configuration file.

Usage:
  shell::fzf_rename_key_conf [-n] [-h]

Parameters:
  - -n   : Optional dry-run flag. If provided, the renaming command is printed using shell::logger::cmd_copy instead of executed.
  - -h   : Optional. Displays this help message.

Description:
  The function reads the configuration file defined by SHELL_KEY_CONF_FILE, which stores entries in the format:
      key=encoded_value
  It uses fzf to interactively select an existing key.
  After selection, the function prompts for a new key name and checks if the new key already exists.
  If the new key does not exist, it constructs a sed command to replace the old key with the new key in the file.
  The sed command uses in-place editing options appropriate for macOS (sed -i '') or Linux (sed -i).
  In dry-run mode, the command is printed via shell::logger::cmd_copy; otherwise, it is executed using shell::run_cmd_eval.

Example:
  shell::fzf_rename_key_conf         # Interactively select a key and rename it.
  shell::fzf_rename_key_conf -n      # Prints the renaming command without executing it.
"

USAGE_SHELL_IS_PROTECTED_KEY_CONF="
shell::is_protected_key_conf function
Checks if the specified configuration key is protected.

Usage:
  shell::is_protected_key_conf [-h] <key>

Parameters:
  - -h   : Optional. Displays this help message.
  - <key>: The configuration key to check.

Description:
  This function iterates over the SHELL_PROTECTED_KEYS array to determine if the given key is marked as protected.
  If the key is found in the array, the function echoes "true" and returns 0.
  Otherwise, it echoes "false" and returns 1.
"

USAGE_SHELL_FZF_ADD_GROUP_KEY_CONF="
shell::fzf_add_group_key_conf function
Groups selected configuration keys under a specified group name.

Usage:
  shell::fzf_add_group_key_conf [-n] [-h]

Parameters:
  - -h   : Optional. Displays this help message.

Description:
  This function prompts you to enter a group name, then uses fzf (with multi-select) to let you choose
  one or more configuration keys (from SHELL_KEY_CONF_FILE). It then stores the group in SHELL_GROUP_CONF_FILE in the format:
      group_name=key1,key2,...,keyN
  If the group name already exists, the group entry is updated with the new selection.
  An optional dry-run flag (-n) can be used to print the command via shell::logger::cmd_copy instead of executing it.

Example:
  shell::fzf_add_group_key_conf         # Prompts for a group name and lets you select keys to group.
  shell::fzf_add_group_key_conf -n      # Prints the command for creating/updating the group without executing it.
"

USAGE_SHELL_READ_GROUP_KEY_CONF="
shell::read_group_key_conf function
Reads and displays the configurations for a given group by group name.

Usage:
  shell::read_group_key_conf [-h] <group_name>

Parameters:
  - -h   : Optional. Displays this help message.

Description:
  This function looks up the group entry in SHELL_GROUP_CONF_FILE for the specified group name.
  The group entry is expected to be in the format:
      group_name=key1,key2,...,keyN
  For each key in the group, the function retrieves the corresponding configuration entry from SHELL_KEY_CONF_FILE,
  decodes the Base64-encoded value (using -D on macOS and -d on Linux), and groups the key-value pairs
  into a JSON object which is displayed.
"

USAGE_SHELL_FZF_REMOVE_GROUP_KEY_CONF="
shell::fzf_remove_group_key_conf function
Interactively selects a group name from the group configuration file using fzf,
then removes the corresponding group entry.

Usage:
  shell::fzf_remove_group_key_conf [-n] [-h]

Parameters:
  - -n   : Optional dry-run flag. If provided, the removal command is printed using shell::logger::cmd_copy instead of executed.
  - -h   : Optional. Displays this help message.

Description:
  The function extracts group names from SHELL_GROUP_CONF_FILE and uses fzf for interactive selection.
  Once a group is selected, it constructs a sed command (with appropriate in-place options for macOS or Linux)
  to remove the line that starts with \"group_name=\".
  If the file is not writable, sudo is prepended. In dry-run mode, the command is printed via shell::logger::cmd_copy.

Example:
  shell::fzf_remove_group_key_conf         # Interactively select a group and remove its entry.
  shell::fzf_remove_group_key_conf -n      # Prints the removal command without executing it.
"

USAGE_SHELL_FZF_UPDATE_GROUP_KEY_CONF="
shell::fzf_update_group_key_conf function
Interactively updates an existing group by letting you select new keys for that group.

Usage:
  shell::fzf_update_group_key_conf [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the update command is printed using shell::logger::cmd_copy instead of executed.
  - -h   : Optional. Displays this help message.

Description:
  The function reads SHELL_GROUP_CONF_FILE and uses fzf to let you select an existing group.
  It then presents all available keys from SHELL_KEY_CONF_FILE (via fzf with multi-select) for you to choose the new group membership.
  The selected keys are converted into a comma-separated list, and the group entry is updated in SHELL_GROUP_CONF_FILE
  (using sed with options appropriate for macOS or Linux). If the file is not writable, sudo is used.

Example:
  shell::fzf_update_group_key_conf         # Interactively select a group, update its keys, and update the group entry.
  shell::fzf_update_group_key_conf -n      # Prints the update command without executing it.
"

USAGE_SHELL_FZF_RENAME_GROUP_KEY_CONF="
shell::fzf_rename_group_key_conf function
Renames an existing group in the group configuration file.

Usage:
  shell::fzf_rename_group_key_conf [-n] [-h]

Parameters:
  - -n   : Optional dry-run flag. If provided, the renaming command is printed using shell::logger::cmd_copy instead of executed.
  - -h   : Optional. Displays this help message.

Description:
  The function reads the group configuration file (SHELL_GROUP_CONF_FILE) where each line is in the format:
      group_name=key1,key2,...,keyN
  It uses fzf to let you select an existing group to rename.
  After selection, the function prompts for a new group name.
  It then constructs a sed command to replace the old group name with the new one in the configuration file.
  The sed command uses in-place editing options appropriate for macOS (sed -i '') or Linux (sed -i).
  In dry-run mode, the command is printed using shell::logger::cmd_copy; otherwise, it is executed using shell::run_cmd_eval.

Example:
  shell::fzf_rename_group_key_conf         # Interactively select a group and rename it.
  shell::fzf_rename_group_key_conf -n      # Prints the renaming command without executing it.
"

USAGE_SHELL_LIST_GROUP_KEY_CONF="
shell::list_group_key_conf function
Lists all group names defined in the group configuration file.

Usage:
  shell::list_group_key_conf [-h]

Parameters:
  - -h   : Optional. Displays this help message.

Description:
  This function reads the configuration file defined by SHELL_GROUP_CONF_FILE,
  where each line is in the format:
      group_name=key1,key2,...,keyN
  It extracts and displays the group names (the part before the '=')
  using the 'cut' command.
"

USAGE_SHELL_FZF_VIEW_GROUP_KEY_CONF="
shell::fzf_view_group_key_conf function
Interactively selects a group name from the group configuration file using fzf,
then lists all keys belonging to the selected group and uses fzf to choose one key,
finally displaying the decoded value for the selected key.

Usage:
  shell::fzf_view_group_key_conf [-h]

Parameters:
  - -h   : Optional. Displays this help message.

Description:
  The function reads the configuration file defined by SHELL_GROUP_CONF_FILE, where each line is in the format:
      group_name=key1,key2,...,keyN
  It first uses fzf to allow interactive selection of a group name.
  Once a group is selected, the function extracts the comma-separated list of keys,
  converts them into a list (one per line), and uses fzf again to let you choose one key.
  It then retrieves the corresponding configuration entry from SHELL_KEY_CONF_FILE (which stores entries as key=encoded_value),
  decodes the Base64-encoded value (using -D on macOS and -d on Linux), and displays the group name, key, and decoded value.
"

USAGE_SHELL_FZF_CLONE_GROUP_KEY_CONF="
shell::fzf_clone_group_key_conf function
Clones an existing group by creating a new group with the same keys.

Usage:
  shell::fzf_clone_group_key_conf [-n] [-h]

Parameters:
  - -n   : Optional dry-run flag. If provided, the cloning command is printed using shell::logger::cmd_copy instead of executed.
  - -h   : Optional. Displays this help message.

Description:
  The function reads the group configuration file (SHELL_GROUP_CONF_FILE) where each line is in the format:
      group_name=key1,key2,...,keyN
  It uses fzf to interactively select an existing group.
  After selection, it prompts for a new group name.
  The new group entry is then constructed with the new group name and the same comma-separated keys
  as the selected group, and appended to SHELL_GROUP_CONF_FILE.
  In dry-run mode, the final command is printed using shell::logger::cmd_copy; otherwise, it is executed using shell::run_cmd_eval.
"

USAGE_SHELL_SYNC_GROUP_KEY_CONF="
shell::sync_group_key_conf function
Synchronizes group configurations by ensuring that each group's keys exist in the key configuration file.
If a key listed in a group does not exist, it is removed from that group.
If a group ends up with no valid keys, that group entry is removed.

Usage:
  shell::sync_group_key_conf [-n] [-h]

Parameters:
  - -n   : Optional dry-run flag. If provided, the new group configuration is printed using shell::logger::cmd_copy instead of being applied.
  - -h   : Optional. Displays this help message.

Description:
  The function reads each group entry from SHELL_GROUP_CONF_FILE (entries in the format: group_name=key1,key2,...,keyN).
  For each group, it splits the comma-separated list of keys and checks each key using shell::exist_key_conf.
  It builds a new list of valid keys. If the new list is non-empty, the group entry is updated;
  if it is empty, the group entry is omitted.
  In dry-run mode, the new group configuration is printed via shell::logger::cmd_copy without modifying the file.
"

USAGE_SHELL_ADD_ANGULAR_GITIGNORE="
shell::add_angular_gitignore function
This function downloads the .gitignore file specifically for Angular projects.

Usage:
  shell::add_angular_gitignore [-h]

Parameters:
  - -h                              : Optional. Displays this help message.
"

USAGE_SHELL_ADD_GH_WRK_BASE="
shell::add_gh_wrk_base function
This function downloads the continuous integration (CI) workflow configuration file
for the DevOps process from the specified GitHub repository.

Usage:
  shell::add_gh_wrk_base [-h]

Parameters:
  - -h                              : Optional. Displays this help message.
"

USAGE_SHELL_ADD_GH_WRK_NEWS="
shell::add_gh_wrk_news function
This function downloads the GitHub Actions CI notification workflow configuration file
from the specified GitHub repository. This file is crucial for setting up automated
notifications related to CI events, ensuring that relevant stakeholders are informed
about the status of the CI processes.

Usage:
  shell::add_gh_wrk_news [-h]

Parameters:
  - -h                              : Optional. Displays this help message.
"

USAGE_SHELL_ADD_GH_WRK_SH_PRETTY="
shell::add_gh_wrk_sh_pretty function
This function downloads the GitHub Actions workflow configuration file for shell script
formatting from the specified GitHub repository. This file is essential for
automating the formatting of shell scripts in the project, ensuring consistency and
adherence to coding standards.

Usage:
  shell::add_gh_wrk_sh_pretty [-h]

Parameters:
  - -h                              : Optional. Displays this help message.
"

USAGE_SHELL_ADD_GH_WRK_NEWS_GO="
shell::add_gh_wrk_news_go function
This function downloads the GitHub Actions workflow configuration file for Go language
notifications from the specified GitHub repository. This file is crucial for
automating notifications related to Go language CI events, ensuring that relevant
stakeholders are informed about the status of the Go language CI processes.

Usage:
  shell::add_gh_wrk_news_go [-h]

Parameters:
  - -h                              : Optional. Displays this help message.
"

USAGE_SHELL_SEND_TELEGRAM_HISTORICAL_GH_MESSAGE="
shell::send_telegram_historical_gh_message function
Sends a historical GitHub-related message via Telegram using stored configuration keys.

Usage:
  shell::send_telegram_historical_gh_message [-n] [-h] <message>

Parameters:
  - -n              : Optional dry-run flag. If provided, the command will be printed using shell::logger::cmd_copy instead of executed.
  - -h              : Optional. Displays this help message.
  - <message>       : The message text to send.

Description:
  The function first checks if the dry-run flag is provided. It then verifies the existence of the
  configuration keys \"SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN\" and \"SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID\".
  If either key is missing, a warning is printed and the corresponding key is copied to the clipboard
  to prompt the user to add it using shell::add_key_conf. If both keys exist, it retrieves their values and
  calls shell::send_telegram_message (with the dry-run flag, if enabled) to send the message.

Example:
  shell::send_telegram_historical_gh_message \"Historical message text\"
  shell::send_telegram_historical_gh_message -n \"Dry-run historical message text\"
"

USAGE_SHELL_RETRIEVE_GH_LATEST_RELEASE="
shell::retrieve_gh_latest_release function
Retrieves the latest release tag from a GitHub repository using the GitHub API.

Usage:
  shell::retrieve_gh_latest_release <owner/repo>

Parameters:
  - <owner/repo>: GitHub repository in the format 'owner/repo'

Returns:
  Outputs the latest release tag (e.g., v1.2.3), or an error message if failed.

Example:
  shell::retrieve_gh_latest_release \"cli/cli\"

Dependencies:
  - curl
  - jq (optional): For better JSON parsing. Falls back to grep/sed if unavailable.
"

USAGE_SHELL_GET_GO_PRIVATES="
shell::get_go_privates function

Description:
  Retrieves and prints the value of the GOPRIVATE environment variable.
  The GOPRIVATE variable is used by Go tools to determine which modules
  should be considered private, affecting how Go commands handle dependencies.

Usage:
  shell::get_go_privates [-n] [-h]

Parameters:
    - -n     : Optional. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
    - -h     : Optional. Displays this help message.

Example:
  shell::get_go_privates
  shell::get_go_privates -n
"

USAGE_SHELL_SET_GO_PRIVATES="
shell::set_go_privates function

Description:
  Sets the GOPRIVATE environment variable to the provided value.
  If GOPRIVATE already has values, the new values are appended
  to the existing comma-separated list.
  This variable is used by Go tools to determine which modules
  should be considered private, affecting how Go commands handle dependencies.

Usage:
  shell::set_go_privates [-n] [-h] <repository1> [repository2] ...

Parameters:
  - -n                              : Optional. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h                              : Optional. Displays this help message.
  - <repository1>                   : The first repository to add to GOPRIVATE.
  - [repository2] [repository3] ... : Additional repositories to add to GOPRIVATE.

Options:
  None

Example:
  shell::set_go_privates \"example.com/private1\"
  shell::set_go_privates -n \"example.com/private1\" \"example.com/internal\"
"

USAGE_SHELL_FZF_REMOVE_GO_PRIVATES="
shell::fzf_remove_go_privates function

Description:
  Uses fzf to interactively select and remove entries from the GOPRIVATE environment variable.
  The GOPRIVATE variable is used by Go tools to determine which modules should be considered private,
  affecting how Go commands handle authenticated access to dependencies.

Usage:
  shell::fzf_remove_go_privates [-n] [-h]

Parameters:
  - -n                              : Optional. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h                              : Optional. Displays this help message.

Example:
  shell::fzf_remove_go_privates           # Interactively remove entries from GOPRIVATE.
  shell::fzf_remove_go_privates -n        # Preview the command without executing it.
"

USAGE_SHELL_CREATE_GO_APP="
shell::create_go_app function
Creates a new Go application by initializing a Go module and tidying dependencies
within a specified target folder.

Usage:
  shell::create_go_app [-n] [-h] <app_name|github_url> [target_folder]

Parameters:
  - -n : Optional dry-run flag.
         If provided, the commands are printed using shell::logger::cmd_copy instead of being executed.
  - -h : Optional. Displays this help message.
  - <app_name|github_url> : The name of the application or a GitHub URL to initialize the module.
  - [target_folder] : Optional. The path to the folder where the Go application should be created.
                      If not provided, the application is created in the current directory.

Description:
  This function checks if the provided application name is a valid URL.
  If it is, it extracts the module name from the URL.
  If a target folder is specified, the function ensures the folder exists,
  changes into that directory, initializes the Go module using (go mod init),
  and tidies the dependencies using (go mod tidy).
  After execution, it returns to the original directory.
  In dry-run mode, the commands are displayed without execution.

Example:
  shell::create_go_app my_app                      # Initializes a Go module named 'my_app' in the current directory.
  shell::create_go_app my_app /path/to/my/folder   # Initializes 'my_app' in the specified folder.
  shell::create_go_app -n my_app                   # Previews the initialization commands without executing them.
  shell::create_go_app -n my_app /tmp/go_projects  # Previews initialization in a target folder.
  shell::create_go_app https://github.com/user/repo /home/user/src # Initializes from a GitHub URL in a target folder.
"

USAGE_SHELL_ADD_GO_APP_SETTINGS="
shell::add_go_app_settings function
This function downloads essential configuration files for a Go application.

Usage:
  shell::add_go_app_settings [-h]

Parameters:
  - -h                              : Optional. Displays this help message.

It retrieves the following files:
- VERSION_RELEASE.md: Contains the version release information for the application.
- Makefile: A build script that defines how to compile and manage the application.
- ci.yml: A GitHub Actions workflow configuration for continuous integration.
- ci_notify.yml: A GitHub Actions workflow configuration for notifications related to CI events.
"

USAGE_SHELL_ADD_GO_GITIGNORE="
shell::add_go_gitignore function
This function downloads the .gitignore file for a Go project.

Usage:
  shell::add_go_gitignore [-h]

Parameters:
  - -h                              : Optional. Displays this help message.
"

USAGE_SHELL_ADD_JAVA_GITIGNORE="
shell::add_java_gitignore function
This function downloads the .gitignore file specifically for Java projects.

Usage:
  shell::add_java_gitignore [-h]

Parameters:
  - -h                              : Optional. Displays this help message.
"

USAGE_SHELL_ADD_NODEJS_GITIGNORE="
shell::add_nodejs_gitignore function
This function downloads the .gitignore file specifically for Node.js projects.

Usage:
  shell::add_nodejs_gitignore [-h]

Parameters:
  - -h                              : Optional. Displays this help message.
"

USAGE_SHELL_ADD_PYTHON_GITIGNORE="
shell::add_python_gitignore function
This function downloads the .gitignore file specifically for Python projects.

Usage:
  shell::add_python_gitignore [-h]

Parameters:
  - -h                              : Optional. Displays this help message.
"

USAGE_SHELL_INSTALL_PYTHON="
shell::python::install function
Installs Python (python3) on macOS or Linux.

Usage:
  shell::python::install [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h : Optional. Displays this help message.

Description:
  Installs Python 3 using the appropriate package manager based on the OS:
  - On Linux: Uses apt-get, yum, or dnf (detected automatically), with a specific check for package installation state.
  - On macOS: Uses Homebrew, checking Homebrew's package list.
  Skips installation only if Python is confirmed installed via the package manager.

Example:
  shell::python::install       # Installs Python 3.
  shell::python::install -n    # Prints the installation command without executing it.
"

USAGE_SHELL_UNINSTALL_PYTHON="
shell::uninstall_python function
Removes Python (python3) and its core components from the system.

Usage:
  shell::uninstall_python [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h : Optional. Displays this help message.

Description:
  Thoroughly uninstalls Python 3 using the appropriate package manager:
  - On Linux: Uses \"purge\" with apt-get or \"remove\" with yum/dnf, followed by autoremove to clean dependencies.
  - On macOS: Uses Homebrew with cleanup to remove all traces.
  Warns about potential system impact on Linux due to Python dependencies.

Example:
  shell::uninstall_python       # Removes Python 3.
  shell::uninstall_python -n    # Prints the removal command without executing it.
"

USAGE_SHELL_UNINSTALL_PYTHON_PIP_DEPS="
shell::uninstall_pip_pkg function
Uninstalls all pip and pip3 packages with user confirmation and optional dry-run.

Usage:
  shell::uninstall_pip_pkg [-n] [-h]

Parameters:
  - -n  : Optional flag to perform a dry-run (uses shell::logger::cmd_copy to print commands without executing).
  - -h  : Optional. Displays this help message.

Description:
  This function uninstalls all packages installed via pip and pip3, including system packages,
  after user confirmation. It is designed to work on both Linux and macOS, with safety checks
  and enhanced logging using shell::run_cmd_eval.

Example usage:
  shell::uninstall_pip_pkg       # Uninstalls all pip/pip3 packages after confirmation
  shell::uninstall_pip_pkg -n    # Dry-run to preview commands
"

USAGE_SHELL_UNINSTALL_PYTHON_PIP_DEPS_LATEST="
shell::uninstall_pip_pkg::latest function
Uninstalls all pip and pip3 packages with user confirmation and optional dry-run.

Usage:
  shell::uninstall_pip_pkg::latest [-n] [-h]

Parameters:
  - -n  : Optional flag to perform a dry-run (uses shell::logger::cmd_copy to print commands without executing).
  - -h  : Optional. Displays this help message.

Description:
  This function uninstalls all packages installed via pip and pip3, including system packages,
  after user confirmation. It is designed to work on both Linux and macOS, with safety checks.
  In non-dry-run mode, it executes the uninstallation commands asynchronously using shell::async,
  ensuring that the function returns once the background process completes.

Example usage:
  shell::uninstall_pip_pkg::latest       # Uninstalls all pip/pip3 packages after confirmation
  shell::uninstall_pip_pkg::latest -n    # Dry-run to preview commands
"

USAGE_SHELL_CREATE_PYTHON_ENV="
shell::create_python_env function
Creates a Python virtual environment for development, isolating it from system packages.

Usage:
  shell::create_python_env [-n] [-h] [-p <path>] [-v <version>]

Parameters:
  - -n          : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
  - -h          : Optional. Displays this help message.
  - -p <path>   : Optional. Specifies the path where the virtual environment will be created (defaults to ./venv).
  - -v <version>: Optional. Specifies the Python version (e.g., 3.10); defaults to system Python3.

Description:
  This function sets up a Python virtual environment to avoid package conflicts with the system OS:
  - Ensures Python3 and pip are installed using shell::python::install.
  - Creates a virtual environment at the specified or default path using the specified or default Python version.
  - Upgrades pip and installs basic tools (wheel, setuptools) in the virtual environment.
  - Supports asynchronous execution for pip upgrades to speed up setup.
  - Verifies the environment and provides activation instructions.

Example:
  shell::create_python_env                # Creates a virtual env at ./venv with default Python3.
  shell::create_python_env -n             # Prints commands without executing them.
  shell::create_python_env -p ~/my_env     # Creates a virtual env at ~/my_env.
  shell::create_python_env -v 3.10        # Uses Python 3.10 for the virtual env.
"

USAGE_SHELL_INSTALL_PKG_PYTHON_ENV="
shell::install_pkg_python_env function
Installs Python packages into an existing virtual environment using pip, avoiding system package conflicts.

Usage:
  shell::install_pkg_python_env [-n] [-h] [-p <path>] <package1> [package2 ...]

Parameters:
  - -n          : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
  - -h          : Optional. Displays this help message.
  - -p <path>   : Optional. Specifies the path to the virtual environment (defaults to ./venv).
  - <package1> [package2 ...] : One or more Python package names to install (e.g., numpy, requests).

Description:
  This function installs specified Python packages into an existing virtual environment:
  - Verifies the virtual environment exists at the specified or default path.
  - Uses the virtual environment's pip to install packages, ensuring isolation from system Python.
  - Supports asynchronous execution for package installation to improve performance.
  - Provides feedback on success or failure, with dry-run support for previewing commands.

Example:
  shell::install_pkg_python_env numpy pandas    # Installs numpy and pandas in ./venv.
  shell::install_pkg_python_env -n requests     # Prints installation command without executing.
  shell::install_pkg_python_env -p ~/my_env flask  # Installs flask in ~/my_env.
"

USAGE_SHELL_UNINSTALL_PKG_PYTHON_ENV="
shell::uninstall_pkg_python_env function
Uninstalls Python packages from a virtual environment using pip or pip3.

Usage:
  shell::uninstall_pkg_python_env [-n] [-h] [-p <path>] <package1> [package2 ...]

Parameters:
  - -n          : Optional dry-run flag.
                    If provided, commands are printed using shell::logger::cmd_copy
                    instead of executed.
  - -h          : Optional. Displays this help message.
  - -p <path>   : Optional.
                    Specifies the path to the virtual environment (defaults to ./venv).
  - <package1> [package2 ...] : One or more Python package names to uninstall
                    (e.g., numpy, requests).

Description:
  This function uninstalls specified Python packages from an existing virtual
  environment:
  - Verifies the virtual environment exists at the specified or default path.
  - Uses the virtual environment's pip to uninstall packages, ensuring
    uninstallation is isolated to the virtual environment.
  - Supports asynchronous execution for package uninstallation to improve
    performance.
  - Provides feedback on success or failure, with dry-run support for
    previewing commands.

Example:
  shell::uninstall_pkg_python_env numpy pandas    # Uninstalls numpy and pandas from ./venv.
  shell::uninstall_pkg_python_env -n requests     # Prints uninstallation command without executing.
  shell::uninstall_pkg_python_env -p ~/my_env flask  # Uninstalls flask from ~/my_env.
"

USAGE_SHELL_FZF_UNINSTALL_PKG_PYTHON_ENV="
shell::fzf_uninstall_pkg_python_env function
Interactively uninstalls Python packages from a virtual environment using fzf for package selection.

Usage:
  shell::fzf_uninstall_pkg_python_env [-n] [-h] [-p <path>]

Parameters:
  - -n          : Optional dry-run flag.
                    If provided, commands are printed using shell::logger::cmd_copy
                    instead of executed.
  - -h          : Optional. Displays this help message.
  - -p <path>   : Optional.
                    Specifies the path to the virtual environment (defaults to ./venv).

Description:
  This function enhances Python package uninstallation by:
  - Using fzf to allow interactive selection of packages to uninstall.
  - Reusing shell::uninstall_pkg_python_env to perform the actual uninstallation.
  - Supports dry-run and asynchronous execution.

Example:
  shell::fzf_uninstall_pkg_python_env          # Uninstalls packages from ./venv after interactive selection.
  shell::fzf_uninstall_pkg_python_env -n -p ~/my_env  # Prints uninstallation commands for ~/my_env without executing.
"

USAGE_SHELL_FZF_USE_PYTHON_ENV="
shell::fzf_use_python_env function
Interactively selects a Python virtual environment using fzf and activates/deactivates it.

Usage:
  shell::fzf_use_python_env [-n] [-h] [-p <path>]

Parameters:
  - -n          : Optional dry-run flag.
                    If provided, commands are printed using shell::logger::cmd_copy
                    instead of executed.
  - -h          : Optional. Displays this help message.
  - -p <path>   : Optional.
                    Specifies the parent path to search for virtual environments (defaults to current directory).

Description:
  This function enhances virtual environment management by:
  - Using fzf to allow interactive selection of a virtual environment.
  - Activating the selected virtual environment.
  - Providing an option to deactivate the current environment.
  - Supports dry-run.

Example:
  shell::fzf_use_python_env          # Select and activate a venv from the current directory.
  shell::fzf_use_python_env -n -p ~/projects  # Prints activation command for a venv in ~/projects without executing.
"

USAGE_SHELL_FZF_UPGRADE_PKG_PYTHON_ENV="
shell::fzf_upgrade_pkg_python_env function
Interactively upgrades Python packages in a virtual environment using fzf for package selection.

Usage:
  shell::fzf_upgrade_pkg_python_env [-n] [-h] [-p <path>]

Parameters:
  - -n          : Optional dry-run flag.
                    If provided, commands are printed using shell::logger::cmd_copy
                    instead of executed.
  - -h          : Optional. Displays this help message.
  - -p <path>   : Optional.
                    Specifies the path to the virtual environment (defaults to ./venv).

Description:
  This function provides an interactive way to upgrade Python packages within a virtual environment by:
  - Using fzf to allow selection of packages to upgrade.
  - Constructing and executing pip upgrade commands.
  - Supporting dry-run mode to preview commands.

Example:
  shell::fzf_upgrade_pkg_python_env          # Upgrades packages in ./venv after interactive selection.
  shell::fzf_upgrade_pkg_python_env -n -p ~/my_env  # Prints upgrade commands for ~/my_env without executing.
"

USAGE_SHELL_UPGRADE_PKG_PYTHON_ENV="
shell::upgrade_pkg_python_env function
Upgrades Python packages in a virtual environment using pip.

Usage:
  shell::upgrade_pkg_python_env [-n] [-h] [-p <path>] <package1> [package2 ...]

Parameters:
  - -n          : Optional dry-run flag.
                    If provided, commands are printed using shell::logger::cmd_copy instead of executed.
  - -h          : Optional. Displays this help message.
  - -p <path>   : Optional.
                    Specifies the path to the virtual environment (defaults to ./venv).
  - <package1> [package2 ...]: One or more Python package names to upgrade.

Description:
  This function upgrades specified Python packages within an existing virtual environment:
  - Verifies the virtual environment exists at the specified or default path.
  - Uses the virtual environment's pip to upgrade packages.
  - Supports dry-run mode to preview commands.
  - Implements asynchronous execution for the upgrade process.

Example:
  shell::upgrade_pkg_python_env numpy pandas   # Upgrades numpy and pandas in ./venv.
  shell::upgrade_pkg_python_env -n requests    # Prints upgrade command without executing.
  shell::upgrade_pkg_python_env -p ~/my_env flask  # Upgrades flask in ~/my_env.
"

USAGE_SHELL_FREEZE_PKG_PYTHON_ENV="
shell::freeze_pkg_python_env function
Exports a list of installed packages and their versions from a Python virtual environment to a requirements.txt file.

Usage:
  shell::freeze_pkg_python_env [-n] [-h] [-p <path>]

Parameters:
  - -n          : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
  - -h          : Optional. Displays this help message.
  - -p <path>   : Optional. Specifies the path to the virtual environment (defaults to ./venv).

Description:
  This function uses pip freeze to generate a requirements.txt file, capturing the current state of the virtual environment's packages.
  - It checks for the existence of the virtual environment.
  - It constructs the appropriate pip freeze command.
  - It supports dry-run mode to preview the command.
  - It implements asynchronous execution for the freeze operation.

Example:
  shell::freeze_pkg_python_env         # Exports requirements from ./venv.
  shell::freeze_pkg_python_env -n -p ~/my_env  # Prints the export command for ~/my_env without executing.
"

USAGE_SHELL_PIP_INSTALL_REQUIREMENTS_ENV="
shell::pip_install_requirements_env function
Installs Python packages from a requirements.txt file into a virtual environment.

Usage:
  shell::pip_install_requirements_env [-n] [-h] [-p <path>]

Parameters:
  - -n          : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
  - -h          : Optional. Displays this help message.
  - -p <path>   : Optional. Specifies the path to the virtual environment (defaults to ./venv).

Description:
  This function uses pip install -r to install packages from a requirements.txt file into the specified virtual environment.
  - It checks for the existence of the virtual environment and the requirements.txt file.
  - It constructs the appropriate pip install command.
  - It supports dry-run mode to preview the command.
  - It implements asynchronous execution for the installation process.

Example:
  shell::pip_install_requirements_env         # Installs from requirements.txt in ./venv.
  shell::pip_install_requirements_env -n -p ~/my_env  # Prints the installation command for ~/my_env without executing.
"

USAGE_SHELL_UPLINK="
shell::uplink function
Creates a hard link between the specified source and destination.

Usage:
  shell::uplink [-h] <source name> <destination name>

Parameters:
  - -h          : Optional. Displays this help message.

Description:
  The 'shell::uplink' function creates a hard link between the specified source file and destination file.
  This allows multiple file names to refer to the same file content.
"

USAGE_SHELL_OPENT="
shell::opent function
Opens the specified directory in a new Finder tab (Mac OS only).

Usage:
  shell::opent [-h] [directory]

Parameters:
  - -h          : Optional. Displays this help message.

Description:
  The 'shell::opent' function opens the specified directory in a new Finder tab on Mac OS.
  If no directory is specified, it opens the current directory.
"

USAGE_SHELL_ADD_BOOKMARK="
shell::add_bookmark function
Adds a bookmark for the current directory with the specified name.

Usage:
  shell::add_bookmark [-h] <bookmark name>

Parameters:
  - -h          : Optional. Displays this help message.

Description:
  The 'shell::add_bookmark' function creates a bookmark for the current directory with the given name.
  It allows quick navigation to the specified directory using the bookmark name.
"

USAGE_SHELL_REMOVE_BOOKMARK="
shell::remove_bookmark function
Deletes a bookmark with the specified name from the bookmarks file.

Usage:
  shell::remove_bookmark [-h] <bookmark_name>

Parameters:
  - -h              : Optional. Displays this help message.
  - <bookmark_name> : The name of the bookmark to remove.

Description:
  This function searches for a bookmark entry in the bookmarks file that ends with \"|<bookmark_name>\".
  If the entry is found, it creates a secure temporary file using mktemp, filters out the matching line,
  and then replaces the original bookmarks file with the filtered version.
  If the bookmark is not found or removal fails, an error message is displayed.
"

USAGE_SHELL_REMOVE_BOOKMARK_LINUX="
shell::remove_bookmark_linux function
Deletes a bookmark with the specified name from the bookmarks file.

Usage:
  shell::remove_bookmark_linux [-h] <bookmark_name>

Parameters:
  - -h              : Optional. Displays this help message.
  - <bookmark_name> : The name of the bookmark to remove.

Description:
  This function searches for a bookmark entry in the bookmarks file that ends with \"|<bookmark_name>\".
  If the entry is found, it uses sed to delete the line from the file.
  The sed command is constructed differently for macOS and Linux due to differences in the in-place edit flag.
"

USAGE_SHELL_LIST_BOOKMARK="
shell::list_bookmark function
Displays a formatted list of all bookmarks.

Usage:
  shell::list_bookmark [-h]

Parameters:
  - -h              : Optional. Displays this help message.

Description:
  The 'shell::list_bookmark' function lists all bookmarks in a formatted manner,
  showing the bookmark name (field 2) in yellow and the associated directory (field 1) in default color.
"

USAGE_SHELL_GO_BOOKMARK="
shell::go_bookmark function
Navigates to the directory associated with the specified bookmark name.

Usage:
  shell::go_bookmark [-h] <bookmark name>

Parameters:
  - -h              : Optional. Displays this help message.

Description:
  The 'shell::go_bookmark' function changes the current working directory to the directory
  associated with the given bookmark name. It looks for a line in the bookmarks file
  that ends with \"|<bookmark name>\".
"

USAGE_SHELL_GO_BACK="
shell::go_back function
Navigates to the previous working directory.

Usage:
  shell::go_back [-h]

Parameters:
  - -h              : Optional. Displays this help message.

Description:
  The 'shell::go_back' function changes the current working directory to the previous directory in the history.
"

USAGE_SHELL_GET_OS_TYPE="
shell::get_os_type function
Determines the current operating system type and outputs a standardized string.

Usage:
  shell::get_os_type [-h]

Parameters:
  - -h              : Optional. Displays this help message.

Outputs:
  \"linux\"    - For Linux-based systems
  \"macos\"    - For macOS/Darwin systems
  \"windows\"  - For Windows-like environments (CYGWIN, MINGW, MSYS)
  \"unknown\"  - For unrecognized operating systems
"

USAGE_SHELL_COLORED_ECHO="
shell::stdout function
Prints text to the terminal with customizable colors using (tput) and ANSI escape sequences.
Supports special characters and escape sequences commonly used in terminal environments.

Usage:
shell::stdout [-h] <message> [color_code] [options]

Parameters:
  - -h          : Optional. Displays this help message.
  - <message>   : The text message to display (supports escape sequences).
  - [color_code]: (Optional) A number from 0 to 255 representing the text color.
    - 0-15: Standard colors (Black, Red, Green, etc.)
    - 16-231: Extended 6x6x6 color cube
    - 232-255: Grayscale shades
  - [options]: (Optional) Additional flags for formatting control

Options:
-n: Do not output the trailing newline
-e: Enable interpretation of backslash escapes (default behavior)
-E: Disable interpretation of backslash escapes

Description:
The (shell::stdout) function prints a message in bold and a specific color, if a valid color code is provided.
It uses ANSI escape sequences for 256-color support. If no color code is specified, it defaults to blue (code 4).

Supported Escape Sequences:
newline
horizontal tab
carriage return
backspace
alert (bell)
vertical tab
form feed
literal backslash
literal double quote
literal single quote
hexadecimal escape sequence
Unicode escape sequence

Example color codes:
  - 0: Black
  - 1: Red
  - 2: Green
  - 3: Yellow
  - 4: Blue (default)
  - 5: Magenta
  - 6: Cyan
  - 7: White
  - 196: Bright Red
  - 46: Vibrant Green
  - 202: Bright Yellow
  - 118: Bright Cyan

Example usage:
_shell::stdout \"Hello, World!\" # Prints in default blue (code 4).
_shell::stdout \"Error occurred\" 196 # Prints in bright red.
_shell::stdout \"Task completed\" 46 # Prints in vibrant green.
_shell::stdout \"Line 1'\nLine 2'\tTabbed\" 202 # Multi-line with tab
_shell::stdout \"Bell sound'\a\" 226 # With bell character
_shell::stdout \"Unicode: \u2713 \u2717\" 118 # With Unicode check mark and X
_shell::stdout \"Hex: \x48\x65\x6C\x6C\x6F\" 93 # "Hello" in hex
_shell::stdout \"No newline\" 45 -n # Without trailing newline
_shell::stdout \"Raw '\t text\" 120 -E # Disable escape interpretation

Notes:
- Requires a terminal with 256-color support for full color range.
- Use ANSI color codes for finer control over colors.
- The function automatically detects terminal capabilities and adjusts output accordingly.
- Special characters are interpreted by default (equivalent to echo -e).
"

USAGE_SHELL_RUN_CMD="
shell::run_cmd function
Executes a command and prints it for logging purposes.

Usage:
  shell::run_cmd [-h] <command>

Parameters:
    - -h              : Optional. Displays this help message.
    - <command>       : The command to be executed.

Description:
  The \`shell::run_cmd\` function prints the command for logging before executing it.

Example usage:
  shell::run_cmd ls -l
"

USAGE_SHELL_RUN_CMD_EVAL="
shell::run_cmd_eval function
Execute a command using eval and print it for logging purposes.

Usage:
  shell::run_cmd_eval [-h] <command>

Parameters:
    - -h              : Optional. Displays this help message.
    - <command>       : The command to be executed (as a single string).

Description:
  The 'shell::run_cmd_eval' function executes a command by passing it to the \`eval\` command.
  This allows the execution of complex commands with arguments, pipes, or redirection
  that are difficult to handle with standard execution.
  It logs the command before execution to provide visibility into what is being run.

Options:
  None

Example usage:
  shell::run_cmd_eval \"ls -l | grep txt\"
"

USAGE_SHELL_IS_COMMAND_AVAILABLE="
shell::is_command_available function
Check if a command is available in the system's PATH.

Usage:
  shell::is_command_available [-h] <command>

Parameters:
    - -h              : Optional. Displays this help message.
    - <command>       : The command to check

Returns:
  0 if the command is available, 1 otherwise
"

USAGE_SHELL_INSTALL_PACKAGE="
shell::install_package function
Cross-platform package installation function that works on both macOS and Linux.

Usage:
  shell::install_package [-h] <package_name>

Parameters:
    - -h                : Optional. Displays this help message.
    - <package_name>    : The name of the package to install

Example usage:
  shell::install_package git
"

USAGE_SHELL_UNINSTALL_PACKAGE="
shell::uninstall_package function
Cross-platform package uninstallation function for macOS and Linux.

Usage:
  shell::uninstall_package [-h] <package_name>

Parameters:
    - -h                : Optional. Displays this help message.
    - <package_name>    : The name of the package to uninstall

Example usage:
  shell::uninstall_package git
"

USAGE_SHELL_IS_PACKAGE_INSTALLED_LINUX="
shell::is_package_installed_linux function
Checks if a package is installed on Linux.

Usage:
  shell::is_package_installed_linux [-h] <package_name>

Parameters:
    - -h            : Optional. Displays this help message.
    - <package_name>: The name of the package to check
"

USAGE_SHELL_CREATE_DIRECTORY_IF_NOT_EXISTS="
shell::create_directory_if_not_exists function
Utility function to create a directory (including nested directories) if it
doesn't exist. Enhanced to detect file paths and create parent directories.

Usage:
  shell::create_directory_if_not_exists [-h] <directory_path_or_file_path>

Parameters:
    - -h                              : Optional. Displays this help message.
    - <directory_path_or_file_path>   : The path of the directory to be created, or a file path
                                        from which the parent directory will be extracted and created.

Description:
  This function checks if the specified path is a file path (contains a file extension)
  or a directory path. If it's a file path, it extracts the parent directory using dirname.
  If it's a directory path, it uses the path as-is. The function then checks if the target
  directory exists, and if not, creates it (including any necessary parent directories) using
  sudo to ensure proper privileges.

Examples:
  shell::create_directory_if_not_exists /path/to/nested/directory
  shell::create_directory_if_not_exists /path/to/file.txt                    # Creates /path/to/
  shell::create_directory_if_not_exists .github/workflows/workflow.yml      # Creates .github/workflows/
  shell::create_directory_if_not_exists .github/workflows                   # Creates .github/workflows/
"

USAGE_SHELL_CREATE_FILE_IF_NOT_EXISTS="
shell::create_file_if_not_exists function
Utility function to create a file if it doesn't exist, ensuring all parent directories are created.

Usage:
  shell::create_file_if_not_exists [-h] <filename>

Parameters:
    - -h            : Optional. Displays this help message.
    - <filename>    : The name (or path) of the file to be created. Can be relative or absolute.

Description:
  This function converts the provided filename to an absolute path based on the current working directory
  if it is not already absolute. It then extracts the parent directory path and ensures it exists,
  creating it with admin privileges using (sudo mkdir -p) if necessary. Finally, it creates the file
  using (sudo touch) if it does not already exist. Optional permission settings for the directory
  and file are included but commented out.

Example usage:
  shell::create_file_if_not_exists ./demo/sub/text.txt   # Creates all necessary directories and the file relative to the current directory.
  shell::create_file_if_not_exists /absolute/path/to/file.txt
"

USAGE_SHELL_UNLOCK_PERMISSIONS="
shell::unlock_permissions function
Sets full permissions (read, write, and execute) for the specified file or directory.

Usage:
  shell::unlock_permissions [-n] [-h] <file/dir>

Parameters:
  - -n (optional)   : Dry-run mode. Instead of executing the command, prints it using shell::logger::cmd_copy.
  - -h              : Optional. Displays this help message.
  - <file/dir>      : The path to the file or directory to modify.

Description:
  This function checks the current permission of the target. If it is already set to 777,
  it logs a message and exits without making any changes.
  Otherwise, it builds and executes (or prints, in dry-run mode) the chmod command asynchronously
  to grant full permissions recursively.

Example:
  shell::unlock_permissions ./my_script.sh
  shell::unlock_permissions -n ./my_script.sh  # Dry-run: prints the command without executing.
"

USAGE_SHELL_CLIP_CWD="
shell::clip_cwd function
Copies the current directory path to the clipboard.

Usage:
  shell::clip_cwd [-h]

Parameters:
  - -h              : Optional. Displays this help message.

Description:
  The 'shell::clip_cwd' function copies the current directory path to the clipboard using the 'pbcopy' command.
"

USAGE_SHELL_CLIP_VALUE="
shell::clip_value function
Copies the provided text value into the system clipboard.

Usage:
  shell::clip_value [-h] <text>

Parameters:
    - -h              : Optional. Displays this help message.
    - <text>          : The text string or value to copy to the clipboard.

Description:
  This function first checks if a value has been provided. It then determines the current operating
  system using the shell::get_os_type function. On macOS, it uses pbcopy to copy the value to the clipboard.
  On Linux, it first checks if xclip is available and uses it; if not, it falls back to xsel.
  If no clipboard tool is found or the OS is unsupported, an error message is displayed.

Example:
  shell::clip_value \"Hello, World!\"
"

USAGE_SHELL_GET_TEMP_DIR="
shell::get_temp_dir function
Returns the appropriate temporary directory based on the detected kernel.

Usage:
  shell::get_temp_dir [-h]

Parameters:
    - -h         : Optional. Displays this help message.

Returns:
  The path to the temporary directory for the current operating system.
"

USAGE_SHELL_ON_EVICT="
shell::logger::cmd_copy function
Hook to print a command without executing it.

Usage:
  shell::logger::cmd_copy [-h] <command>

Parameters:
    - -h            : Optional. Displays this help message.
    - <command>     : The command to be printed.

Description:
  The 'shell::logger::cmd_copy' function prints a command without executing it.
  It is designed as a hook for logging or displaying commands without actual execution.

Example usage:
  shell::logger::cmd_copy ls -l
"

USAGE_SHELL_CHECK_PORT="
shell::check_port function
Checks if a specific TCP port is in use (listening).

Usage:
  shell::check_port [-h] <port> [-n]

Parameters:
    - -h     : Optional. Displays this help message.
    - <port> : The TCP port number to check.
    - -n     : Optional flag to enable dry-run mode (prints the command without executing it).

Description:
  This function uses lsof to determine if any process is actively listening on the specified TCP port.
  It filters the output for lines containing \"LISTEN\", which indicates that the port is in use.
  When the dry-run flag (-n) is provided, the command is printed using shell::logger::cmd_copy instead of being executed.

Example:
  shell::check_port 8080        # Executes the command.
  shell::check_port 8080 -n     # Prints the command (dry-run mode) without executing it.
"

USAGE_SHELL_KILL_PORT="
shell::kill_port function
Terminates all processes listening on the specified TCP port(s).

Usage:
  shell::kill_port [-n] [-h] <port> [<port> ...]

Parameters:
    - -n        : Optional flag to enable dry-run mode (print commands without execution).
    - -h        : Optional. Displays this help message.
    - <port>    : One or more TCP port numbers.

Description:
  This function checks each specified port to determine if any processes are listening on it,
  using lsof. If any are found, it forcefully terminates them by sending SIGKILL (-9).
  In dry-run mode (enabled by the -n flag), the kill command is printed using shell::logger::cmd_copy instead of executed.

Example:
  shell::kill_port 8080              # Kills processes on port 8080.
  shell::kill_port -n 8080 3000       # Prints the kill commands for ports 8080 and 3000 without executing.
"

USAGE_SHELL_COPY_FILES="
shell::copy_files function
Copies a source file to one or more destination filenames in the current working directory.

Usage:
  shell::copy_files [-n] [-h] <source_filename> <new_filename1> [<new_filename2> ...]

Parameters:
    - -n                : Optional dry-run flag. If provided, the command will be printed using shell::logger::cmd_copy instead of executed.
    - -h                : Optional. Displays this help message.
    - <source_filename> : The file to copy.
    - <new_filenameX>   : One or more new filenames (within the current working directory) where the source file will be copied.

Description:
  The function first checks for a dry-run flag (-n). It then verifies that at least two arguments remain.
  For each destination filename, it checks if the file already exists in the current working directory.
  If not, it builds the command to copy the source file (using sudo) to the destination.
  In dry-run mode, the command is printed using shell::logger::cmd_copy; otherwise, it is executed using shell::run_cmd_eval.

Example:
  shell::copy_files myfile.txt newfile.txt            # Copies myfile.txt to newfile.txt.
  shell::copy_files -n myfile.txt newfile1.txt newfile2.txt  # Prints the copy commands without executing them.
"
USAGE_SHELL_KILL_PORT="
shell::kill_port function
Terminates all processes listening on the specified TCP port(s).

Usage:
  shell::kill_port [-n] [-h] <port> [<port> ...]

Parameters:
  - -n    : Optional flag to enable dry-run mode (print commands without execution).
  - -h    : Optional. Displays this help message.
  - <port>: One or more TCP port numbers.

Description:
  This function checks each specified port to determine if any processes are listening on it,
  using lsof. If any are found, it forcefully terminates them by sending SIGKILL (-9).
  In dry-run mode (enabled by the -n flag), the kill command is printed using shell::logger::cmd_copy instead of executed.

Example:
  shell::kill_port 8080              # Kills processes on port 8080.
  shell::kill_port -n 8080 3000      # Prints the kill commands for ports 8080 and 3000 without executing.
"

USAGE_SHELL_COPY_FILES="
shell::copy_files function
Copies a source file to one or more destination filenames in the current working directory.

Usage:
  shell::copy_files [-n] [-h] <source_filename> <new_filename1> [<new_filename2> ...]

Parameters:
  - -n                : Optional dry-run flag. If provided, the command will be printed using shell::logger::cmd_copy instead of executed.
  - -h                : Optional. Displays this help message.
  - <source_filename> : The file to copy.
  - <new_filenameX>   : One or more new filenames (within the current working directory) where the source file will be copied.

Description:
  The function first checks for a dry-run flag (-n). It then verifies that at least two arguments remain.
  For each destination filename, it checks if the file already exists in the current working directory.
  If not, it builds the command to copy the source file (using sudo) to the destination.
  In dry-run mode, the command is printed using shell::logger::cmd_copy; otherwise, it is executed using shell::run_cmd_eval.

Example:
  shell::copy_files myfile.txt newfile.txt                   # Copies myfile.txt to newfile.txt.
  shell::copy_files -n myfile.txt newfile1.txt newfile2.txt  # Prints the copy commands without executing them.
"

USAGE_SHELL_MOVE_FILES="
shell::move_files function
Moves one or more files to a destination folder.

Usage:
  shell::move_files [-n] [-h] <destination_folder> <file1> <file2> ... <fileN>

Parameters:
  - -n                  : Optional dry-run flag. If provided, the command will be printed using shell::logger::cmd_copy instead of executed.
  - -h                  : Optional. Displays this help message.
  - <destination_folder>: The target directory where the files will be moved.
  - <fileX>             : One or more source files to be moved.

Description:
  The function first checks for an optional dry-run flag (-n). It then verifies that the destination folder exists.
  For each source file provided:
    - It checks whether the source file exists.
    - It verifies that the destination file (using the basename of the source) does not already exist in the destination folder.
    - It builds the command to move the file (using sudo mv).
  In dry-run mode, the command is printed using shell::logger::cmd_copy; otherwise, the command is executed using shell::run_cmd.
  If an error occurs for a particular file (e.g., missing source or destination file conflict), the error is logged and the function continues with the next file.

Example:
  shell::move_files /path/to/dest file1.txt file2.txt        # Moves file1.txt and file2.txt to /path/to/dest.
  shell::move_files -n /path/to/dest file1.txt file2.txt     # Prints the move commands without executing them.
"

USAGE_SHELL_REMOVE_FILES="
shell::remove_files function
Removes a file or directory using sudo rm -rf.

Usage:
  shell::remove_files [-n] [-h] <filename/dir>

Parameters:
  - -n            : Optional dry-run flag. If provided, the command will be printed using shell::logger::cmd_copy instead of executed.
  - -h            : Optional. Displays this help message.
  - <filename/dir>: The file or directory to remove.

Description:
  The function first checks for an optional dry-run flag (-n). It then verifies that a target argument is provided.
  It builds the command to remove the specified target using \"sudo rm -rf\".
  In dry-run mode, the command is printed using shell::logger::cmd_copy; otherwise, it is executed using shell::run_cmd.

Example:
  shell::remove_files my-dir         # Removes the directory 'my-dir'.
  shell::remove_files -n myfile.txt  # Prints the removal command without executing it.
"

USAGE_SHELL_EDITOR="
shell::editor function
Open a selected file from a specified folder using a chosen text editor.

Usage:
  shell::editor [-n] [-h] <folder>

Parameters:
  - -n       : Optional dry-run flag. If provided, the command will be printed using shell::logger::cmd_copy instead of executed.
  - -h       : Optional. Displays this help message.
  - <folder> : The directory containing the files you want to edit.

Description:
  The 'shell::editor' function provides an interactive way to select a file from the specified
  folder and open it using a chosen text editor. It uses 'fzf' for fuzzy file and command selection.
  The function supports a dry-run mode where the command is printed without execution.

Supported Text Editors:
  - cat
  - less
  - more
  - vim
  - nano

Example:
  shell::editor ~/documents          # Opens a file in the selected text editor.
  shell::editor -n ~/documents       # Prints the command that would be used, without executing it.
"

USAGE_SHELL_DOWNLOAD_DATASET="
shell::download_dataset function
Downloads a dataset file from a provided download link.

Usage:
  shell::download_dataset [-n] [-h] <filename_with_extension> <download_link>

Parameters:
  - -n                        : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
  - -h                        : Optional. Displays this help message.
  - <filename_with_extension> : The target filename (with path) where the dataset will be saved.
  - <download_link>           : The URL from which the dataset will be downloaded.

Description:
  This function downloads a file from a given URL and saves it under the specified filename.
  It extracts the directory from the filename, ensures the directory exists, and changes to that directory
  before attempting the download. If the file already exists, it prompts the user for confirmation before
  overwriting it. In dry-run mode, the function uses shell::logger::cmd_copy to display the commands without executing them.

Example:
  shell::download_dataset mydata.zip https://example.com/mydata.zip
  shell::download_dataset -n mydata.zip https://example.com/mydata.zip  # Displays the commands without executing them.
"

USAGE_SHELL_UNARCHIVE="
shell::unarchive function
Extracts a compressed file based on its file extension.

Usage:
  shell::unarchive [-n] [-h] <filename>

Parameters:
  - -n        : Optional dry-run flag. If provided, the extraction command is printed using shell::logger::cmd_copy instead of executed.
  - -h        : Optional. Displays this help message.
  - <filename>: The compressed file to extract.

Description:
  The function first checks for an optional dry-run flag (-n) and then verifies that exactly one argument (the filename) is provided.
  It checks if the given file exists and, if so, determines the correct extraction command based on the file extension.
  In dry-run mode, the command is printed using shell::logger::cmd_copy; otherwise, it is executed using shell::run_cmd_eval.

Example:
  shell::unarchive archive.tar.gz           # Extracts archive.tar.gz.
  shell::unarchive -n archive.zip           # Prints the unzip command without executing it.
"

USAGE_SHELL_LIST_HIGH_MEM_USAGE="
shell::list_high_mem_usage function
Displays processes with high memory consumption.

Usage:
  shell::list_high_mem_usage [-n] [-h]

Parameters:
  - -n        : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h        : Optional. Displays this help message.

Description:
  This function retrieves the operating system type using shell::get_os_type. For macOS, it uses 'top' to sort processes by resident size (RSIZE)
  and filters the output to display processes consuming at least 100 MB. For Linux, it uses 'ps' to list processes sorted by memory usage.
  In dry-run mode, the constructed command is printed using shell::logger::cmd_copy; otherwise, it is executed using shell::run_cmd_eval.

Example:
  shell::list_high_mem_usage       # Displays processes with high memory consumption.
  shell::list_high_mem_usage -n    # Prints the command without executing it.
"

USAGE_SHELL_OPEN_LINK="
shell::open_link function
Opens the specified URL in the default web browser.

Usage:
  shell::open_link [-n] [-h] <url>

Parameters:
  - -n   : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h   : Optional. Displays this help message.
  - <url>: The URL to open in the default web browser.

Description:
  This function determines the current operating system using shell::get_os_type. On macOS, it uses the 'open' command;
  on Linux, it uses 'xdg-open' (if available). If the required command is missing on Linux, an error is displayed.
  In dry-run mode, the command is printed using shell::logger::cmd_copy; otherwise, it is executed using shell::run_cmd_eval.

Example:
  shell::open_link https://example.com         # Opens the URL in the default browser.
  shell::open_link -n https://example.com      # Prints the command without executing it.
"

USAGE_SHELL_LOADING_SPINNER="
shell::loading_spinner function
Displays a loading spinner in the console for a specified duration.

Usage:
  shell::loading_spinner [-n] [-h] [duration]

Parameters:
  - -n        : Optional dry-run flag. If provided, the spinner command is printed using shell::logger::cmd_copy instead of executed.
  - -h        : Optional. Displays this help message.
  - [duration]: Optional. The duration in seconds for which the spinner should be displayed. Default is 3 seconds.

Description:
  The function calculates an end time based on the provided duration and then iterates,
  printing a sequence of spinner characters to create a visual loading effect.
  In dry-run mode, it uses shell::logger::cmd_copy to display a message indicating what would be executed,
  without actually running the spinner.

Example usage:
  shell::loading_spinner          # Displays the spinner for 3 seconds.
  shell::loading_spinner 10       # Displays the spinner for 10 seconds.
  shell::loading_spinner -n 5     # Prints the spinner command for 5 seconds without executing it.
"

USAGE_SHELL_MEASURE_TIME="
shell::measure_time function
Measures the execution time of a command and displays the elapsed time.

Usage:
  shell::measure_time [-h] <command> [arguments...]

Parameters:
  - -h                      : Optional. Displays this help message.
  - <command> [arguments...]: The command (with its arguments) to execute.

Description:
  This function captures the start time, executes the provided command, and then captures the end time.
  It calculates the elapsed time in milliseconds and displays the result in seconds and milliseconds.
  On macOS, if GNU date (gdate) is available, it is used for millisecond precision; otherwise, it falls back
  to the built-in SECONDS variable (providing second-level precision). On Linux, it uses date +%s%3N.

Example:
  shell::measure_time sleep 2    # Executes 'sleep 2' and displays the execution time.
"

USAGE_SHELL_ASYNC="
shell::async function
Executes a command or function asynchronously (in the background).

Usage:
  shell::async [-n] [-h] <command> [arguments...]

Parameters:
  - -n                      : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h                      : Optional. Displays this help message.
  - <command> [arguments...]: The command (or function) with its arguments to be executed asynchronously.

Description:
  The shell::async function builds the command from the provided arguments and runs it in the background.
  If the optional dry-run flag (-n) is provided, the command is printed using shell::logger::cmd_copy instead of executing it.
  Otherwise, the command is executed asynchronously using eval, and the process ID (PID) is displayed.

Example:
  shell::async my_function arg1 arg2      # Executes my_function with arguments asynchronously.
  shell::async -n ls -l                   # Prints the 'ls -l' command that would be executed in the background.
"

USAGE_SHELL_EXECUTE_OR_EVICT="
shell::execute_or_evict function
Executes a command or prints it based on dry-run mode.

Usage:
  shell::execute_or_evict [-h] <dry_run> <command>

Parameters:
  - -h       : Optional. Displays this help message.
  - <dry_run>: \"true\" to print the command, \"false\" to execute it.
  - <command>: The command to execute or print.

Example:
  shell::execute_or_evict \"true\" \"echo Hello\"
"

USAGE_SHELL_FZF_COPY="
shell::fzf_copy function
Interactively selects a file to copy and a destination directory using fzf,
then copies the selected file to the destination directory.

Usage:
  shell::fzf_copy [-h]

Parameters:
  - -h       : Optional. Displays this help message.

Description:
  This function leverages fzf to provide an interactive interface for choosing:
    1. A source file (from the current directory and subdirectories).
    2. A destination directory (from the current directory and subdirectories).
  It then copies the source file to the destination directory using the original filename.
"

USAGE_SHELL_FZF_MOVE="
shell::fzf_move function
Interactively selects a file to move and a destination directory using fzf,
then moves the selected file to the destination directory.

Usage:
  shell::fzf_move [-h]

Parameters:
  - -h       : Optional. Displays this help message.

Description:
  This function leverages fzf to provide an interactive interface for choosing:
    1. A source file (from the current directory and subdirectories).
    2. A destination directory (from the current directory and subdirectories).
  It then moves the source file to the destination directory using the original filename.
"

USAGE_SHELL_FZF_REMOVE="
shell::fzf_remove function
Interactively selects a file or directory to remove using fzf,
then removes the selected file or directory.

Usage:
  shell::fzf_remove [-h]

Parameters:
  - -h       : Optional. Displays this help message.

Description:
  This function leverages fzf to provide an interactive interface for choosing:
    1. A file or directory (from the current directory and subdirectories).
  It then removes the selected file or directory using the original path.
"

USAGE_SHELL_FZF_ZIP_ATTACHMENT="
shell::fzf_zip_attachment function
Zips selected files from a specified folder and outputs the absolute path of the created zip file.

Usage:
  shell::fzf_zip_attachment [-n] [-h] <folder_path>

Parameters:
  - -n            : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h            : Optional. Displays this help message.
  - <folder_path> : The folder (directory) from which to select files for zipping.

Description:
  This function uses the 'find' command to list all files in the specified folder,
  and then launches 'fzf' in multi-select mode to allow interactive file selection.
  If one or more files are selected, a zip command is constructed to compress those files.
  In dry-run mode (-n), the command is printed (via shell::logger::cmd_copy) without execution;
  otherwise, it is executed using shell::run_cmd_eval.
  Finally, the absolute path of the created zip file is echoed.

Example:
  shell::fzf_zip_attachment /path/to/folder
  shell::fzf_zip_attachment -n /path/to/folder  # Dry-run: prints the command without executing it.
"

USAGE_SHELL_FZF_CURRENT_ZIP_ATTACHMENT="
shell::fzf_current_zip_attachment function
Reuses shell::fzf_zip_attachment to zip selected files from the current directory,
ensuring that when unzipped, the archive creates a single top-level folder.

Usage:
  shell::fzf_current_zip_attachment [-n] [-h]

Parameters:
  - -n         : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h         : Optional. Displays this help message.

Description:
  This function obtains the current directory's name and its parent directory.
  It then changes to the parent directory and calls shell::fzf_zip_attachment on the folder name.
  This ensures that the zip command is run with relative paths so that the resulting archive
  contains only one top-level folder (the folder name). After zipping, it moves the zip file
  back to the original (current) directory, echoes its absolute path, and copies the value to the clipboard.

Example:
  shell::fzf_current_zip_attachment
  shell::fzf_current_zip_attachment -n  # Dry-run: prints the command without executing it.
"

USAGE_SHELL_FZF_SEND_TELEGRAM_ATTACHMENT="
shell::fzf_send_telegram_attachment function
Uses fzf to interactively select one or more files from a folder (default: current directory)
and sends them as attachments via the Telegram Bot API by reusing shell::send_telegram_attachment.

Usage:
  shell::fzf_send_telegram_attachment [-n] [-h] <token> <chat_id> <description> [folder_path]

Parameters:
  - -n           : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
  - -h           : Optional. Displays this help message.
  - <token>      : The Telegram Bot API token.
  - <chat_id>    : The chat identifier where the attachments are sent.
  - <description>: A text description appended to each attachment's caption along with a timestamp.
  - [folder_path]: (Optional) The folder to search for files; defaults to the current directory if not provided.

Description:
  This function checks that the required parameters are provided and sets the folder path to the current directory if none is given.
  It then uses the 'find' command and fzf (in multi-select mode) to let the user choose one or more files.
  If files are selected, it calls shell::send_telegram_attachment (passing the dry-run flag if needed) with the selected filenames.

Example:
  shell::fzf_send_telegram_attachment 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 \"Report\"
  shell::fzf_send_telegram_attachment -n 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 \"Test\" /path/to/folder
"

USAGE_SHELL_INSTALL_HOMEBREW="
shell::install_homebrew function
Installs Homebrew using the official installation script.

Usage:
  shell::install_homebrew [-h]

Parameters:
  - -h           : Optional. Displays this help message.

Description:
  This function downloads and executes the official Homebrew installation
  script via curl. The command is executed using shell::run_cmd_eval, which logs
  the command before executing it.
"

USAGE_SHELL_REMOVAL_HOMEBREW="
shell::removal_homebrew function
Uninstalls Homebrew from the system.

Usage:
  shell::removal_homebrew [-h]

Parameters:
  - -h           : Optional. Displays this help message.

Description:
  This function first checks if Homebrew is installed using shell::is_command_available.
  If Homebrew is detected, it uninstalls Homebrew by running the official uninstall
  script. Additionally, it removes Homebrew-related lines from the user's shell
  profile (e.g., $HOME/.zprofile) using sed. The commands are executed via
  shell::run_cmd_eval to ensure they are logged prior to execution.
"

USAGE_SHELL_INSTALL_OH_MY_ZSH="
shell::install_oh_my_zsh function
Installs Oh My Zsh if it is not already present on the system.

Usage:
  shell::install_oh_my_zsh [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the installation command is printed using shell::logger::cmd_copy instead of executed.
  - -h : Optional. Displays this help message.

Description:
  The function checks whether the Oh My Zsh directory ($HOME/.oh-my-zsh) exists.
  If it exists, it prints a message indicating that Oh My Zsh is already installed.
  Otherwise, it proceeds to install Oh My Zsh by executing the installation script fetched via curl.
  In dry-run mode, the command is displayed using shell::logger::cmd_copy; otherwise, it is executed using shell::run_cmd_eval.

Example:
  shell::install_oh_my_zsh         # Installs Oh My Zsh if needed.
  shell::install_oh_my_zsh -n      # Prints the installation command without executing it.
"

USAGE_SHELL_REMOVAL_OH_MY_ZSH="
shell::removal_oh_my_zsh function
Uninstalls Oh My Zsh by removing its directory and restoring the original .zshrc backup if available.

Usage:
  shell::removal_oh_my_zsh [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the uninstallation commands are printed using shell::logger::cmd_copy instead of executed.
  - -h : Optional. Displays this help message.

Description:
  This function checks whether the Oh My Zsh directory ($HOME/.oh-my-zsh) exists.
  If it does, the function proceeds to remove it using 'rm -rf'. Additionally, if a backup of the original .zshrc
  (stored as $HOME/.zshrc.pre-oh-my-zsh) exists, it restores that backup by moving it back to $HOME/.zshrc.
  In dry-run mode, the commands are displayed using shell::logger::cmd_copy; otherwise, they are executed using shell::run_cmd_eval.

Example:
  shell::removal_oh_my_zsh         # Uninstalls Oh My Zsh if installed.
  shell::removal_oh_my_zsh -n      # Displays the uninstallation commands without executing them.
"

USAGE_SHELL_SEND_TELEGRAM_MESSAGE="
shell::send_telegram_message function
Sends a message via the Telegram Bot API.

Usage:
  shell::send_telegram_message [-n] [-h] <token> <chat_id> <message>

Parameters:
  - -n          : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h          : Optional. Displays this help message.
  - <token>     : The Telegram Bot API token.
  - <chat_id>   : The chat identifier where the message should be sent.
  - <message>   : The message text to send.

Description:
  The function first checks for an optional dry-run flag. It then verifies that at least three arguments are provided.
  If the bot token or chat ID is missing, it prints an error message. Otherwise, it constructs a curl command to send
  the message via Telegram's API. In dry-run mode, the command is printed using shell::logger::cmd_copy; otherwise, it is executed using shell::run_cmd_eval.

Example:
  shell::send_telegram_message 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 \"Hello, World!\"
  shell::send_telegram_message -n 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 \"Dry-run: Hello, World!\"
"

USAGE_SHELL_SEND_TELEGRAM_ATTACHMENT="
shell::send_telegram_attachment function
Sends one or more attachments (files) via Telegram using the Bot API asynchronously.

Usage:
  shell::send_telegram_attachment [-n] [-h] <token> <chat_id> <description> [filename_1] [filename_2] [filename_3] ...

Parameters:
  - -n           : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h          : Optional. Displays this help message.
  - <token>      : The Telegram Bot API token.
  - <chat_id>    : The chat identifier to which the attachments are sent.
  - <description>: A text description that is appended to each attachment's caption along with a timestamp.
  - [filename_X] : One or more filenames of the attachments to send.

Description:
  The function first checks for an optional dry-run flag (-n) and verifies that the required parameters
  are provided. For each provided file, if the file exists, it builds a curl command to send the file
  asynchronously via Telegram's API. In dry-run mode, the command is printed using shell::logger::cmd_copy.

Example:
  shell::send_telegram_attachment 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 \"Report\" file1.pdf file2.pdf
  shell::send_telegram_attachment -n 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 \"Report\" file1.pdf
"

USAGE_SHELL_GET_PROFILE_PATH="
shell::get_profile_path function
Returns the path to the profile directory for a given profile name.

Usage:
  shell::get_profile_path [-h] <profile_name>

Parameters:
  - -h            : Optional. Displays this help message.
  - <profile_name>: The name of the profile.

Description:
  Constructs and returns the path to the profile directory within the workspace,
  located at SHELL_CONF_WORKING/workspace.
"

USAGE_SHELL_ENSURE_WORKSPACE="
shell::ensure_workspace function
Ensures that the workspace directory exists.

Usage:
  shell::ensure_workspace [-h]

Parameters:
  - -h    : Optional. Displays this help message.

Description:
  Checks if the workspace directory (SHELL_CONF_WORKING/workspace) exists.
  If it does not exist, creates it using mkdir -p.
"

USAGE_SHELL_ADD_PROFILE="
shell::add_profile function
Creates a new profile directory and initializes it with a profile.conf file.

Usage:
  shell::add_profile [-n] [-h] <profile_name>

Parameters:
  - -n             : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
  - -h             : Optional. Displays this help message.
  - <profile_name> : The name of the profile to create.

Description:
  Ensures the workspace directory exists, then creates a new directory for the specified profile
  and initializes it with an empty profile.conf file. If the profile already exists, it prints a warning.

Example:
  shell::add_profile my_profile         # Creates the profile directory and profile.conf.
  shell::add_profile -n my_profile      # Prints the commands without executing them.
"

USAGE_SHELL_READ_PROFILE="
shell::read_profile function
Sources the profile.conf file from the specified profile directory.

Usage:
  shell::read_profile [-n] [-h] <profile_name>

Parameters:
  - -n             : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h             : Optional. Displays this help message.
  - <profile_name> : The name of the profile to read.

Description:
  Checks if the specified profile exists and sources its profile.conf file to load configurations
  into the current shell session. If the profile or file does not exist, it prints an error.

Example:
  shell::read_profile my_profile         # Sources profile.conf from my_profile.
  shell::read_profile -n my_profile      # Prints the sourcing command without executing it.
"

USAGE_SHELL_UPDATE_PROFILE="
shell::update_profile function
Opens the profile.conf file of the specified profile in the default editor.

Usage:
  shell::update_profile [-n] [-h] <profile_name>

Parameters:
  - -n             : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h             : Optional. Displays this help message.
  - <profile_name> : The name of the profile to update.

Description:
  Checks if the specified profile exists and opens its profile.conf file in the editor specified
  by the EDITOR environment variable (defaults to 'nano' if unset).

Example:
  shell::update_profile my_profile         # Opens profile.conf in the default editor.
  shell::update_profile -n my_profile      # Prints the editor command without executing it.
"

USAGE_SHELL_REMOVE_PROFILE="
shell::remove_profile function
Deletes the specified profile directory after user confirmation.

Usage:
  shell::remove_profile [-n] [-h] <profile_name>

Parameters:
  - -n             : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h             : Optional. Displays this help message.
  - <profile_name> : The name of the profile to remove.

Description:
  Prompts for confirmation before deleting the profile directory and its contents.
  If confirmed, removes the directory; otherwise, aborts the operation.

Example:
  shell::remove_profile my_profile         # Prompts to confirm deletion of my_profile.
  shell::remove_profile -n my_profile      # Prints the removal command without executing it.
"

USAGE_SHELL_GET_PROFILE="
shell::get_profile function
Displays the contents of the profile.conf file for the specified profile.

Usage:
  shell::get_profile [-h] <profile_name>

Parameters:
  - -h             : Optional. Displays this help message.
  - <profile_name> : The name of the profile to display.

Description:
  Checks if the specified profile exists and displays the contents of its profile.conf file.
  If the profile or file does not exist, it prints an error.

Example:
  shell::get_profile my_profile         # Displays the contents of profile.conf for my_profile.
"

USAGE_SHELL_RENAME_PROFILE="
shell::rename_profile function
Renames the specified profile directory.

Usage:
  shell::rename_profile [-n] [-h] <old_name> <new_name>

Parameters:
  - -n             : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h             : Optional. Displays this help message.
  - <old_name>     : The current name of the profile.
  - <new_name>     : The new name for the profile.

Description:
  Checks if the old profile exists and the new profile name does not already exist,
  then renames the directory accordingly.

Example:
  shell::rename_profile old_profile new_profile         # Renames old_profile to new_profile.
  shell::rename_profile -n old_profile new_profile      # Prints the rename command without executing it.
"

USAGE_SHELL_ADD_PROFILE_CONF="
shell::add_profile_conf function
Adds a configuration entry (key=value) to the profile.conf file of a specified profile.
The value is encoded using Base64 before being saved.

Usage:
  shell::add_profile_conf [-n] [-h] <profile_name> <key> <value>

Parameters:
  - -n             : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - -h             : Optional. Displays this help message.
  - <profile_name> : The name of the profile.
  - <key>          : The configuration key.
  - <value>        : The configuration value to be encoded and saved.

Description:
  The function checks for an optional dry-run flag (-n) and ensures that the profile name, key, and value are provided.
  It encodes the value using Base64 (with newline characters removed) and appends a line in the format:
      key=encoded_value
  to the profile.conf file in the specified profile directory. If the profile directory or the profile.conf file does not exist, they are created.

Example:
  shell::add_profile_conf my_profile my_setting \"some secret value\"         # Encodes the value and adds the entry to my_profile/profile.conf
  shell::add_profile_conf -n my_profile my_setting \"some secret value\"      # Prints the command without executing it
"

USAGE_SHELL_GET_PROFILE_CONF="
shell::get_profile_conf function
Retrieves a configuration profile value by prompting the user to select a config key from the profile's configuration file.

Usage:
  shell::get_profile_conf [-n] [-h] <profile_name>

Parameters:
  - -n (optional)   : Dry-run mode. Instead of executing commands, prints them using shell::logger::cmd_copy.
  - -h              : Optional. Displays this help message.
  - <profile_name>  : The name of the configuration profile.

Description:
  This function locates the profile directory and its configuration file, verifies that the profile exists,
  and then ensures that the interactive fuzzy finder (fzf) is installed. It uses fzf to let the user select a configuration key,
  decodes its base64-encoded value (using the appropriate flag for macOS or Linux), displays the selected key,
  and finally copies the decoded value to the clipboard asynchronously.

Example:
  shell::get_profile_conf my_profile          # Retrieves and processes the 'my_profile' profile.
  shell::get_profile_conf -n my_profile       # Dry-run mode: prints the commands without executing them.
"

USAGE_SHELL_GET_PROFILE_CONF_VALUE="
shell::get_profile_conf_value function
Retrieves a configuration value for a given profile and key by decoding its base64-encoded value.

Usage:
  shell::get_profile_conf_value [-n] [-h] <profile_name> <key>

Parameters:
  - -n (optional)   : Dry-run mode. Instead of executing commands, prints them using shell::logger::cmd_copy.
  - -h              : Optional. Displays this help message.
  - <profile_name>  : The name of the configuration profile.
  - <key>           : The configuration key whose value will be retrieved.

Description:
  This function ensures that the workspace exists and locates the profile directory
  and configuration file. It then extracts the configuration line matching the provided key,
  decodes the associated base64-encoded value (using the appropriate flag for macOS or Linux),
  asynchronously copies the decoded value to the clipboard, and finally outputs the decoded value.

Example:
  shell::get_profile_conf_value my_profile API_KEY
  shell::get_profile_conf_value -n my_profile API_KEY   # Dry-run: prints commands without executing them.
"

USAGE_SHELL_REMOVE_PROFILE_CONF="
shell::remove_profile_conf function
Removes a configuration key from a given profile's configuration file.

Usage:
  shell::remove_profile_conf [-n] [-h] <profile_name>

Parameters:
  - -n (optional)   : Dry-run mode. Instead of executing commands, prints them using shell::logger::cmd_copy.
  - -h              : Optional. Displays this help message.
  - <profile_name>  : The name of the configuration profile.

Description:
  This function locates the profile directory and its configuration file, verifies their existence,
  and then uses fzf to let the user select a configuration key to remove.
  It builds an OS-specific sed command to delete the line containing the selected key.
  In dry-run mode, the command is printed using shell::logger::cmd_copy; otherwise, it is executed asynchronously
  using shell::async with shell::run_cmd_eval.

Example:
  shell::remove_profile_conf my_profile
  shell::remove_profile_conf -n my_profile   # Dry-run: prints the removal command without executing.
"

USAGE_SHELL_UPDATE_PROFILE_CONF="
shell::update_profile_conf function
Updates a specified configuration key in a given profile by replacing its value.

Usage:
  shell::update_profile_conf [-n] [-h] <profile_name>

Parameters:
  - -n              : Optional dry-run flag. If provided, the update command is printed using shell::logger::cmd_copy without executing.
  - -h              : Optional. Displays this help message.
  - <profile_name>  : The name of the profile to update.

Description:
  The function retrieves the profile configuration file, prompts the user to select a key (using fzf),
  asks for the new value, encodes it in base64, and constructs a sed command to update the key.
  The sed command is executed asynchronously via the shell::async function (unless in dry-run mode).

Example:
  shell::update_profile_conf my_profile
  shell::update_profile_conf -n my_profile   # dry-run mode
"

USAGE_SHELL_EXIST_PROFILE_CONF_KEY="
shell::exist_profile_conf_key function
Checks whether a specified key exists in the configuration file of a given profile.

Usage:
  shell::exist_profile_conf_key [-h] <profile_name> <key>

Parameters:
  - -h            : Optional. Displays this help message.
  - <profile_name>: The name of the profile.
  - <key>         : The configuration key to search for.

Description:
  The function constructs the path to the profile's configuration file and verifies that the profile directory exists.
  It then checks if the configuration file exists. If both exist, it searches for the specified key using grep.
  The function outputs "true" if the key is found and "false" otherwise.

Example:
  shell::exist_profile_conf_key my_profile my_key
"

USAGE_SHELL_RENAME_PROFILE_CONF_KEY="
shell::rename_profile_conf_key function
Renames an existing configuration key in a given profile.

Usage:
  shell::rename_profile_conf_key [-n] [-h] <profile_name>

Parameters:
  - -n            : Optional dry-run flag. If provided, prints the sed command using shell::logger::cmd_copy without executing.
  - -h            : Optional. Displays this help message.
  - <profile_name>: The name of the profile whose key should be renamed.

Description:
  The function checks that the profile directory and configuration file exist.
  It then uses fzf to allow the user to select the existing key to rename.
  After prompting for a new key name and verifying that it does not already exist,
  the function constructs an OS-specific sed command to replace the old key with the new one.
  In dry-run mode, the command is printed via shell::logger::cmd_copy; otherwise, it is executed using shell::run_cmd_eval.

Example:
  shell::rename_profile_conf_key my_profile
  shell::rename_profile_conf_key -n my_profile   # dry-run mode
"

USAGE_SHELL_CLONE_PROFILE_CONF="
shell::clone_profile_conf function
Clones a configuration profile by copying its profile.conf from a source profile to a destination profile.

Usage:
  shell::clone_profile_conf [-n] [-h] <source_profile> <destination_profile>

Parameters:
  - -n                    : (Optional) Dry-run flag. If provided, the command is printed but not executed.
  - -h                    : Optional. Displays this help message.
  - <source_profile>      : The name of the source profile.
  - <destination_profile> : The name of the destination profile.

Description:
  This function retrieves the source and destination profile directories using shell::get_profile_path,
  verifies that the source profile exists and has a profile.conf file, and ensures that the destination
  profile does not already exist. If validations pass, it clones the configuration by creating the destination
  directory and copying the profile.conf file from the source to the destination. When the dry-run flag (-n)
  is provided, it prints the command without executing it.

Example:
  shell::clone_profile_conf my_profile backup_profile   # Clones profile.conf from 'my_profile' to 'backup_profile'
"

USAGE_SHELL_LIST_PROFILE_CONF="
shell::list_profile_conf function
Lists all available configuration profiles in the workspace.

Usage:
  shell::list_profile_conf [-h]

Parameters:
  - -h      : Optional. Displays this help message.

Description:
  This function checks that the workspace directory (SHELL_CONF_WORKING/workspace) exists.
  It then finds all subdirectories (each representing a profile) and prints their names.
  If no profiles are found, an appropriate message is displayed.

Example:
  shell::list_profile_conf       # Displays the names of all profiles in the workspace.
"

USAGE_SHELL_RETRIEVE_GH_REPOSITORY_INFO="
shell::retrieve_gh_repository_info function
Retrieves and formats extensive information about the current Git repository
using Markdown syntax for Telegram notifications.

Usage:
  shell::retrieve_gh_repository_info [-h]

Parameters:
  - -h      : Optional. Displays this help message.

Description:
  This function checks if the current directory is a Git repository and, if so,
  retrieves extensive details such as the repository name, URLs (Git and HTTPS),
  default branch, current branch, number of commits, latest commit hash, author,
  date, recent commit messages, information about tags, and the status of the
  working tree.
  The collected information is then formatted into a single string response
  using Markdown for compatibility with platforms like Telegram.

Returns:
  A Markdown-formatted string containing repository information if successful,
  or an error message if not in a Git repository.
"

USAGE_SHELL_RUN_CMD_OUTLET="
shell::run_cmd_outlet function
Executes a given command using the shell's eval function.

Usage:
  shell::run_cmd_outlet [-h] <command>

Parameters:
  - -h        : Optional. Displays this help message.
  - <command> : The command to be executed.

Description:
  This function takes a command as input and executes it using eval.
  It is designed to handle commands that may require shell interpretation.
  The function also checks for a help flag (-h) and displays usage information if present.

Example usage:
  shell::run_cmd_outlet \"ls -l\"
"

USAGE_SHELL_RETRIEVE_CURRENT_GH_DEFAULT_BRANCH="
shell::retrieve_current_gh_default_branch function
Retrieves the default branch for the current Git repository.

Usage:
  shell::retrieve_current_gh_default_branch [-h]

Parameters:
  - -h        : Optional. Displays this help message.

Description:
  This function checks if the current directory is a Git repository and, if so,
  determines the default branch by inspecting the 'origin' remote using
  'git remote show origin'. It utilizes shell::run_cmd_eval for command
  execution and logging.
"

USAGE_SHELL_RETRIEVE_CURRENT_GH_CURRENT_BRANCH="
shell::retrieve_current_gh_current_branch function
Retrieves the current branch for the current Git repository.

Usage:
  shell::retrieve_current_gh_current_branch [-h]

Parameters:
  - -h        : Optional. Displays this help message.

Description:
  This function checks if the current directory is a Git repository and, if so,
  determines the name of the currently active branch.
  It utilizes shell::run_cmd_outlet for command execution and output capture.
"

USAGE_SHELL_VALIDATE_INI_SECTION_NAME="
shell::validate_ini_section_name function
Validates an INI section name based on defined strictness levels.
It checks for empty names and disallowed characters or spaces according to
SHELL_INI_STRICT and SHELL_INI_ALLOW_SPACES_IN_NAMES variables.

Usage:
  shell::validate_ini_section_name [-h] <section_name>

Parameters:
  - -h              : Optional. Displays this help message.
  - <section_name>  : The name of the INI section to validate.

Description:
  This function takes a section name as input and applies validation rules.
  An empty section name is always considered invalid.
  If SHELL_INI_STRICT is set to 1, the function checks for the presence of
  illegal characters: square brackets and the equals sign ($(=)).
  If SHELL_INI_ALLOW_SPACES_IN_NAMES is set to 0, the function checks for
  the presence of spaces within the section name.
  Error messages are displayed using the shell::stdout function.

Example usage:
  # Assuming SHELL_INI_STRICT=1 and SHELL_INI_ALLOW_SPACES_IN_NAMES=0
  shell::validate_ini_section_name \"MySection\"   # Valid
  shell::validate_ini_section_name \"My Section\"  # Invalid (contains space)
  shell::validate_ini_section_name \"My[Section]\" # Invalid (contains illegal character)
  shell::validate_ini_section_name \"\"            # Invalid (empty)
"

USAGE_SHELL_VALIDATE_INI_KEY_NAME="
shell::validate_ini_key_name function
Validates an INI key name based on defined strictness levels.
It checks for empty names and disallowed characters or spaces according to
SHELL_INI_STRICT and SHELL_INI_ALLOW_SPACES_IN_NAMES variables.

Usage:
  shell::validate_ini_key_name [-h] <key_name>

Parameters:
  - -h         : Optional. Displays this help message.
  - <key_name> : The name of the INI key to validate.
"

USAGE_SHELL_TRIM_INI="
shell::trim_ini function
Trims leading and trailing whitespace from a given string.

Usage:
  shell::trim_ini [-h] <string>

Parameters:
  - -h          : Optional. Displays this help message.
  - <string>    : The string from which to remove leading and trailing whitespace.

Returns:
  The trimmed string with no leading or trailing whitespace.

Description:
  This function takes a string as input and removes any leading and trailing
  whitespace characters. It uses parameter expansion to efficiently trim
  the whitespace and then outputs the cleaned string.
"

USAGE_SHELL_INI_ESCAPE_FOR_REGEX="
shell::ini_escape_for_regex function
Escapes special characters in a string for regex matching.

Usage:
  shell::ini_escape_for_regex [-h] <string>

Parameters:
  - -h          : Optional. Displays this help message.
  - <string>    : The string in which to escape special regex characters.

Returns:
  The string with special regex characters escaped.

Description:
  This function takes a string as input and escapes special characters
  that are used in regular expressions. It uses the sed command to
  prepend a backslash to each special character, ensuring the string
  can be safely used in regex operations.

Example:
  escaped_string=(shell::ini_escape_for_regex \"example(string)\")  # Outputs \"example\(string\)\"
"

USAGE_SHELL_READ_INI="
shell::read_ini function
Reads the value of a specified key from a given section in an INI file.

Usage:
  shell::read_ini [-h] <file> <section> <key>

Parameters:
  - -h        : Optional. Displays this help message.
  - <file>    : The path to the INI file.
  - <section> : The section within the INI file to search.
  - <key>     : The key within the section whose value is to be retrieved.

Description:
  This function reads an INI file and retrieves the value associated with a
  specified key within a given section. It validates the presence of the file,
  section, and key, and applies strict validation rules if SHELL_INI_STRICT is set.
  The function handles comments, empty lines, and quoted values within the INI file.

Example:
  shell::read_ini config.ini MySection MyKey  # Retrieves the value of MyKey in MySection.
"

USAGE_SHELL_LIST_INI_SECTIONS="
shell::list_ini_sections function
Lists all section names from a given INI file.

Usage:
  shell::list_ini_sections [-h] <file>

Parameters:
  - -h     : Optional. Displays this help message.
  - <file> : The path to the INI file.

Description:
  This function reads an INI file and extracts all section names.
  It validates the presence of the file and outputs the section names
  without the enclosing square brackets.

Example:
  shell::list_ini_sections config.ini  # Lists all sections in config.ini.
"

USAGE_SHELL_LIST_INI_KEYS="
shell::list_ini_keys function
Lists all key names from a specified section in a given INI file.

Usage:
  shell::list_ini_keys [-h] <file> <section>

Parameters:
  - -h        : Optional. Displays this help message.
  - <file>    : The path to the INI file.
  - <section> : The section within the INI file to search for keys.

Description:
  This function reads an INI file and extracts all key names from a specified section.
  It validates the presence of the file and section, and applies strict validation rules
  if SHELL_INI_STRICT is set. The function handles comments and empty lines within the INI file.

Example:
  shell::list_ini_keys config.ini MySection  # Lists all keys in MySection.
"

USAGE_SHELL_EXIST_INI_SECTION="
shell::exist_ini_section function
Checks if a specified section exists in a given INI file.

Usage:
  shell::exist_ini_section [-h] <file> <section>

Parameters:
  - -h        : Optional. Displays this help message.
  - <file>    : The path to the INI file.
  - <section> : The section within the INI file to check for existence.

Description:
  This function checks whether a specified section exists in an INI file.
  It validates the presence of the file and section, and applies strict
  validation rules if SHELL_INI_STRICT is set. The function uses regex
  to search for the section header within the file.

Example:
  shell::exist_ini_section config.ini MySection  # Checks if MySection exists in config.ini.
"

USAGE_SHELL_ADD_INI_SECTION="
shell::add_ini_section function
Adds a new section to a specified INI file if it does not already exist.

Usage:
  shell::add_ini_section [-h] <file> <section>

Parameters:
  - -h        : Optional. Displays this help message.
  - <file>    : The path to the INI file.
  - <section> : The section to be added to the INI file.

Description:
  This function checks if a specified section exists in an INI file and adds it if not.
  It validates the presence of the file and section, and applies strict validation rules
  if SHELL_INI_STRICT is set. The function handles the creation of the file if it does not exist.

Example:
  shell::add_ini_section config.ini NewSection  # Adds NewSection to config.ini if it doesn't exist.
"

USAGE_SHELL_WRITE_INI="
shell::write_ini function
Writes a key-value pair to a specified section in an INI file.

Usage:
  shell::write_ini [-h] <file> <section> <key> <value>

Parameters:
  - -h        : Optional. Displays this help message.
  - <file>    : The path to the INI file.
  - <section> : The section within the INI file to write the key-value pair.
  - <key>     : The key to be written in the specified section.
  - <value>   : The value associated with the key.

Description:
  This function writes a key-value pair to a specified section in an INI file.
  It validates the presence of the file, section, and key, and applies strict
  validation rules if SHELL_INI_STRICT is set. The function handles the creation
  of the file and section if they do not exist. It also manages special characters
  in values by quoting them if necessary.

Example:
  shell::write_ini config.ini MySection MyKey MyValue  # Writes MyKey=MyValue in MySection.
"

USAGE_SHELL_REMOVE_INI_SECTION="
shell::remove_ini_section function
Removes a specified section and its key-value pairs from an INI formatted file.

Usage:
  shell::remove_ini_section [-h] <file> <section>

Parameters:
  - -h        : Optional. Displays this help message.
  - <file>    : The path to the INI file.
  - <section> : The name of the section to remove (without the square brackets).

Description:
  This function processes an INI file line by line. It identifies the start of the
  section to be removed and skips all subsequent lines until another section
  header is encountered or the end of the file is reached. The remaining lines
  (before the target section and after it) are written to a temporary file,
  which then replaces the original file.

Example usage:
  shell::remove_ini_section /path/to/config.ini \"database\"
"

USAGE_SHELL_FZF_REMOVE_INI_KEY="
shell::fzf_remove_ini_key function
Interactively selects a key from a specific section in an INI file using fzf
and then removes the selected key from that section.

Usage:
  shell::fzf_remove_ini_key [-n] <file> <section>

Parameters:
  - -n        : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
  - <file>    : The path to the INI file.
  - <section> : The section within the INI file from which to remove a key.

Description:
  This function validates the input file and section, lists keys within the section
  using shell::list_ini_keys, presents the keys for interactive selection using fzf,
  and then removes the chosen key-value pair from the specified section in the INI file.
  It handles cases where the file or section does not exist and provides feedback
  using shell::stdout.

Example:
  shell::fzf_remove_ini_key config.ini \"Database\"  # Interactively remove a key from the Database section.
  shell::fzf_remove_ini_key -n settings.ini \"API\"  # Dry-run: show commands to remove a key from the API section.
"

USAGE_SHELL_REMOVE_INI_KEY="
shell::remove_ini_key function
Removes a specified key from a specific section in an INI formatted file.

Usage:
  shell::remove_ini_key [-n] <file> <section> <key>

Parameters:
  - -n        : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
  - <file>    : The path to the INI file.
  - <section> : The section within the INI file from which to remove the key.
  - <key>     : The key to be removed from the specified section.

Description:
  This function processes an INI file line by line. It identifies the start of the
  target section and then skips the line containing the specified key within that section.
  All other lines (before the target section, in the target section but not matching the key,
  and after the target section) are written to a temporary file, which then replaces
  the original file.

Example usage:
  shell::remove_ini_key /path/to/config.ini \"database\" \"username\"
  shell::remove_ini_key -n /path/to/config.ini \"api\" \"api_key\" # Dry-run mode
"

USAGE_SHELL_SET_ARRAY_INI_VALUE="
shell::set_array_ini_value function
Writes an array of values to a specified key in an INI file.

Usage:
  shell::set_array_ini_value [-h] <file> <section> <key> [value1] [value2 ...]

Parameters:
  - -h        : Optional. Displays this help message.
  - <file>    : The path to the INI file.
  - <section> : The section within the INI file to write the array to.
  - <key>     : The key to be associated with the array of values.
  - [valueN]  : Optional. One or more values to be written as part of the array.

Description:
  This function processes a list of values, formats them into a comma-separated
  string, and writes this string as the value for a specified key in an INI file.
  Values containing spaces, commas, or double quotes are automatically enclosed
  in double quotes, and internal double quotes are escaped (e.g., \"value with \"quote\"\").
  The final formatted string is passed to 'shell::write_ini' for atomic writing,
  which handles file and section existence, creation, and updates.

Example:
  shell::set_array_ini_value config.ini MySection MyList \"alpha\" \"beta gamma\" \"delta,epsilon\"
  # This would result in MyList=alpha,\"beta gamma\",\"delta,epsilon\" in config.ini
"

USAGE_SHELL_GET_ARRAY_INI_VALUE="
shell::get_array_ini_value function
Reads and parses an array of values from a specified key in an INI file.

Usage:
  shell::get_array_ini_value [-h] <file> <section> <key>

Parameters:
  - -h        : Optional. Displays this help message.
  - <file>    : The path to the INI file.
  - <section> : The section within the INI file to read the array from.
  - <key>     : The key whose array of values is to be retrieved.

Description:
  This function first reads the raw string value of a specified key from an INI file
  using 'shell::read_ini'. It then meticulously parses this string to extract
  individual array elements. The parsing logic correctly handles comma delimiters
  and preserves values enclosed in double quotes, including those containing
  spaces, commas, or escaped double quotes within the value itself.
  Each extracted item is then trimmed of leading/trailing whitespace.
  The function outputs each parsed array item on a new line to standard output.

Example:
  # Assuming 'my_config.ini' contains:
  # [Settings]
  # MyArray=item1,\"item with spaces\",\"item,with,commas\",\"item with \\\"escaped\\\" quotes\"

  shell::get_array_ini_value my_config.ini Settings MyArray
  # Expected output:
  # item1
  # item with spaces
  # item,with,commas
  # item with "escaped" quotes
"

USAGE_SHELL_EXIST_INI_KEY="
shell::exist_ini_key function
Checks if a specified key exists within a section in an INI file.

Usage:
  shell::exist_ini_key [-h] <file> <section> <key>

Parameters:
  - -h        : Optional. Displays this help message.
  - <file>    : The path to the INI file.
  - <section> : The section within the INI file to check.
  - <key>     : The key to check for existence.

Description:
  This function provides a convenient way to verify the presence of a specific
  key within a designated section of an INI configuration file. It acts as a
  wrapper around 'shell::read_ini', using its capabilities to determine if
  the key can be successfully retrieved.
  If strict mode is active (SHELL_INI_STRICT is set to 1), it first
  validates the format of the section and key names, returning an error if
  they do not conform to the defined naming conventions.
  The function ensures its own output is clean by suppressing the internal
  logging of 'shell::read_ini', providing clear, colored messages indicating
  whether the key was found or not.

Example:
  # Check if a 'port' key exists in the 'Network' section of 'settings.ini'
  if shell::exist_ini_key settings.ini Network port; then
    shell::stdout \"Found 'port' setting.\" 46
  else
    shell::stdout \"The 'port' setting is missing.\" 196
  fi
"

USAGE_SHELL_EXPOSE_INI_ENV="
shell::expose_ini_env function
Exports key-value pairs from an INI file as environment variables.

Usage:
  shell::expose_ini_env [-h] <file> [prefix] [section]

Parameters:
  - -h        : Optional. Displays this help message.
  - <file>    : The path to the INI file to read.
  - [prefix]  : Optional. A string prefix to prepend to all environment variable names.
                If provided, variables will be named like \`PREFIX_SECTION_KEY\`.
                If omitted, variables will be named like \`SECTION_KEY\`.
  - [section] : Optional. If specified, only keys from this specific section will
                be exported. If omitted, keys from all sections will be exported.

Description:
  This function parses an INI file and exports its key-value pairs as environment
  variables in the current shell session. It allows for an optional prefix to be
  added to the variable names and can target a specific section or export from all
  sections.
  Variable names are automatically sanitized (converted to uppercase, and
  non-alphanumeric/underscore characters replaced with underscores) to ensure they
  are valid shell variable names.

Example:
  # Export all keys from config.ini without a prefix
  shell::expose_ini_env config.ini

  # Export all keys from config.ini with 'APP_CONFIG' prefix
  shell::expose_ini_env config.ini APP_CONFIG

  # Export keys from 'Database' section of config.ini with 'DB' prefix
  shell::expose_ini_env config.ini DB Database

Returns:
  0 on success, 1 on failure (e.g., missing file, invalid parameters, or issues
  during key reading).
  Outputs colored messages indicating status and actions.

Notes:
  - Affects the current shell session's environment.
  - Relies on 'shell::list_ini_sections', 'shell::list_ini_keys', 'shell::read_ini',
    'shell::sanitize_upper_var_name', and 'shell::stdout'.
  - If SHELL_INI_STRICT is enabled, section and key names will be validated prior
    to reading.
"

USAGE_SHELL_DESTROY_INI_ENV="
shell::destroy_ini_env function
Unsets environment variables previously exported from an INI file.

Usage:
  shell::destroy_ini_env [-h] <file> [prefix] [section]

Parameters:
  - -h        : Optional. Displays this help message.
  - <file>    : The path to the INI file that was used for exporting variables.
  - [prefix]  : Optional. The same prefix that was used during the export (e.g., 'APP_CONFIG').
                If provided, only variables with this prefix will be targeted.
  - [section] : Optional. If specified, only variables corresponding to keys from
                this specific section will be unset. If omitted, keys from all
                sections (matching the prefix, if given) will be targeted.

Description:
  This function reverses the action of 'shell::expose_ini_env'. It reads the specified
  INI file (or a specific section within it) and generates the expected environment
  variable names based on the file's structure and the provided prefix (if any).
  For each generated variable name, it checks if the variable is currently set
  in the environment and, if so, unsets it.

  It's crucial to provide the *exact same* 'file', 'prefix', and 'section' arguments
  that were used when calling 'shell::expose_ini_env' to ensure the correct variables
  are targeted for unsetting. Variable names are sanitized using the same logic
  as 'shell::expose_ini_env' to accurately match previously exported variables.

Example:
  # To unset all variables exported from 'config.ini' without a prefix:
  shell::destroy_ini_env config.ini

  # To unset variables exported from 'config.ini' with the 'APP_CONFIG' prefix:
  shell::destroy_ini_env config.ini APP_CONFIG

  # To unset variables from the 'Database' section of 'config.ini' with the 'DB' prefix:
  shell::destroy_ini_env config.ini DB Database

Returns:
  0 on successful completion, 1 on failure (e.g., missing file, invalid parameters).
  Outputs colored messages indicating status and actions.

Notes:
  - This function attempts to unset variables; it does not report an error if a
    variable was not found or was already unset.
  - Relies on 'shell::list_ini_sections', 'shell::list_ini_keys',
    'shell::sanitize_upper_var_name', and 'shell::stdout'.
  - It does NOT rely on 'shell::read_ini' for values, only for deriving names.
"

USAGE_SHELL_GET_OR_DEFAULT_INI_VALUE="
shell::get_or_default_ini_value function
Reads a key's value from an INI file or returns a default if not found.

Usage:
  shell::get_or_default_ini_value [-h] <file> <section> <key> [default_value]

Parameters:
  - -h          : Optional. Displays this help message.
  - <file>      : The path to the INI file.
  - <section>   : The section within the INI file to search.
  - <key>       : The key whose value is to be retrieved.
  - [default_value]: Optional. The value to return if the key is not found
                    or if reading fails. Defaults to an empty string if omitted.

Description:
  This function attempts to read the value of a specified key from a given
  section in an INI file. If the key is successfully found, its value is
  printed to standard output. If the key is not found, or if there is an
  issue reading the file/section (e.g., file not found, section not found),
  the provided 'default_value' is printed instead. If no 'default_value'
  is supplied, an empty string is returned as the default.

Example:
  # Get 'api_key' from 'Settings' or return 'no_key' if not found
  api_key=(shell::get_or_default_ini_value config.ini Settings api_key "no_key")
  echo \"API Key: $api_key\"

  # Get 'debug_mode' or default to empty string if not found
  debug_mode=(shell::get_or_default_ini_value app.ini General debug_mode)
  if [ -n \"$debug_mode\" ]; then
    echo \"Debug mode is enabled.\"
  fi

Returns:
  0 on success (value found or default returned), 1 on failure (missing parameters).
  The retrieved value or the default value is echoed to standard output.

Notes:
  - Relies on 'shell::read_ini' for file parsing.
  - Error messages from 'shell::read_ini' are suppressed, as this function
    provides its own feedback regarding value retrieval or default usage.
  - Console logging is used for status updates.
"

USAGE_SHELL_GENERATE_RANDOM_KEY="
shell::generate_random_key function
Generates a random encryption key of specified length (in bytes) and outputs it to standard output.

Usage:
  shell::generate_random_key [-h] [bytes]

Parameters:
  - -h        : Optional. Displays this help message.
  - [bytes]   : Optional. The length of the key to generate, in bytes. Defaults to 32 bytes.

Description:
  This function uses OpenSSL to generate a random key of the specified length in hexadecimal format.
"

USAGE_SHELL_ENCODE_AES256CBC="
shell::encode::aes256cbc function
Encrypts a string using AES-256-CBC encryption and encodes the result in Base64.

Usage:
  shell::encode::aes256cbc [-h] <string> [key] [iv]

Parameters:
  - -h        : Optional. Displays this help message.
  - <string>  : The string to encrypt.
  - [key]     : Optional. The encryption key (32 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_KEY.
  - [iv]      : Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV.

Description:
  This function encrypts the input string using AES-256-CBC with OpenSSL, using either the provided key
  or the SHELL_SHIELD_ENCRYPTION_KEY environment variable. The encrypted output is Base64-encoded for safe storage
  in configuration files, aligning with the library's existing Base64 usage. It checks for OpenSSL availability
  and validates the key length. The function is compatible with both macOS and Linux.
"

USAGE_SHELL_DECODE_AES256CBC="
shell::decode::aes256cbc function
Decodes a Base64-encoded string and decrypts it using AES-256-CBC.

Usage:
  shell::decode::aes256cbc [-h] <string> [key] [iv]

Parameters:
  - -h        : Optional. Displays this help message.
  - <string>  : The Base64-encoded string to decrypt.
  - [key]     : Optional. The encryption key (32 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_KEY.
  - [iv]      : Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV.

Description:
  This function decodes the Base64-encoded input string and decrypts it using AES-256-CBC with OpenSSL,
  using either the provided key or the SHELL_SHIELD_ENCRYPTION_KEY environment variable.
"

USAGE_SHELL_CRYPTOGRAPHY_CREATE_PASSWORD_HASH="
shell::cryptography::create_password_hash function
Creates a password hash using a specified OpenSSL algorithm.

Usage:
  shell::cryptography::create_password_hash [-h] <algorithm> <password>

Parameters:
  - -h          : Optional. Displays this help message.
  - <algorithm> : Hashing algorithm.
                  - 1 for Use the MD5 based BSD password algorithm 1 (default)
                  - apr1 for Use the apr1 algorithm (Apache variant of the BSD algorithm).
                  - aixmd5 for Use the AIX MD5 algorithm (AIX variant of the BSD algorithm).
                  - 5 for Use the SHA-256 based hash algorithm.
                  - 6 for Use the SHA-512 based hash algorithm.
  - <password>  : The password to hash.

Description:
  This function uses (openssl passwd) to generate a cryptographic hash of a password.
  It supports various algorithms, including modern secure hashing algorithms like 1 for Use the MD5 based BSD password algorithm 1 (default) 
  and SHA-based hashes ('5' for SHA256, '6' for SHA512).
  The output includes the salt and the hashed password, suitable for storage.   

Example:
  hashed_pass=(shell::cryptography::create_password_hash 1 "MySecurePassword123!")
"

USAGE_SHELL_RENAME_INI_SECTION="
shell::rename_ini_section function
Renames a section in an INI file.

Usage:
  shell::rename_ini_section [-n] [-h] <file> <old_section> <new_section>

Parameters:
  - -n        : Optional. Dry-run mode. Prints the command without executing it.
  - -h        : Optional. Displays this help message.
  - <file>    : The path to the INI file.
  - <old_section> : The name of the section to rename.
  - <new_section> : The new name for the section.

Description:
  This function renames a section in an INI file.
"

USAGE_SHELL_FZF_RENAME_INI_SECTION="
shell::fzf_rename_ini_section function
Interactively renames a section in an INI file using fzf.

Usage:  
  shell::fzf_rename_ini_section [-n] [-h] <file>

Parameters:
  - -n        : Optional. Dry-run mode. Prints the command without executing it.
  - -h        : Optional. Displays this help message.
  - <file>    : The path to the INI file.

Description:
  This function renames a section in an INI file using fzf.
"

USAGE_SHELL_CLONE_INI_SECTION="
shell::clone_ini_section function
Clones a section from one INI file to another.

Usage:
  shell::clone_ini_section [-n] [-h] <file> <source_section> <destination_section> 

Parameters:
  - -n                    : Optional. Dry-run mode. Prints the command without executing it.
  - -h                    : Optional. Displays this help message.
  - <file>                : The path to the INI file.
  - <source_section>      : The name of the section to clone from.
  - <destination_section> : The name of the section to create.

Description:
  This function clones a section from one INI file to another.
"

USAGE_SHELL_FZF_CLONE_INI_SECTION="
shell::fzf_clone_ini_section function
Interactively clones a section from one INI file to another using fzf.

Usage:
  shell::fzf_clone_ini_section [-n] [-h] <file>

Parameters:
  - -n        : Optional. Dry-run mode. Prints the command without executing it.
  - -h        : Optional. Displays this help message.
  - <file>    : The path to the INI file.

Description:
  This function clones a section from one INI file to another using fzf.
"

USAGE_SHELL_FZF_REMOVE_INI_SECTIONS="
shell::fzf_remove_ini_sections function
Interactively removes sections from an INI file using fzf.

Usage:
  shell::fzf_remove_ini_sections [-n] [-h] <file>

Parameters:
  - -n        : Optional. Dry-run mode. Prints the command without executing it.
  - -h        : Optional. Displays this help message.
  - <file>    : The path to the INI file.

Description:
  This function removes sections from an INI file using fzf.
"

USAGE_SHELL_FZF_LIST_BOOKMARK="
shell::fzf_list_bookmark function
Interactively selects a path from the bookmarks file using fzf and navigates to it.

Usage:
  shell::fzf_list_bookmark [-n] [-h]

Parameters:
  - -n        : Optional. Dry-run mode. Prints the command without executing it.
  - -h        : Optional. Displays this help message.

Description:
  This function selects a path from the bookmarks file using fzf and navigates to it.
"

USAGE_SHELL_FZF_LIST_BOOKMARK_UP="
shell::fzf_list_bookmark_up function
Interactively selects a path from the bookmarks file using fzf and displays its availability status.

Usage:
  shell::fzf_list_bookmark_up [-n] [-h]

Parameters:
  - -n        : Optional. Dry-run mode. Prints the command without executing it.
  - -h        : Optional. Displays this help message.

Description:
  This function selects a path from the bookmarks file using fzf and displays its availability status.
"

USAGE_SHELL_ENCODE_FILE_AES256CBC="
shell::encode::file::aes256cbc function
Encrypts a file using AES-256-CBC encryption and encodes the result in Base64.

Usage:
  shell::encode::file::aes256cbc [-n] [-h] <input_file> <output_file> [key] [iv]

Parameters:
  - -n           : Optional. Dry-run mode. Prints the command without executing it.
  - -h           : Optional. Displays this help message.
  - <input_file> : The path to the file to encrypt.
  - <output_file>: The path where the encrypted file will be saved.
  - [key]        : Optional. The encryption key (32 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_KEY.
  - [iv]         : Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV.

Description:
  This function encrypts the specified input file using AES-256-CBC with OpenSSL, using either the provided key
  or the SHELL_SHIELD_ENCRYPTION_KEY environment variable. The encrypted output is saved to the specified output file.
  It checks for OpenSSL availability, validates the key and IV lengths, and ensures the input file exists.
  The function is compatible with both macOS and Linux. In dry-run mode, it prints the encryption command without executing it.

Example:
  shell::encode::file::aes256cbc input.txt encrypted.bin "my64byteKey1234567890123456789012345678901234567890"  # Encrypts with specified key
  export SHELL_SHIELD_ENCRYPTION_KEY="my64byteKey1234567890123456789012345678901234567890"
  shell::encode::file::aes256cbc -n input.txt encrypted.bin  # Prints encryption command without executing
"

USAGE_SHELL_DECODE_FILE_AES256CBC="
shell::decode::file::aes256cbc function
Decodes a Base64-encoded file and decrypts it using AES-256-CBC.

Usage:
  shell::decode::file::aes256cbc [-n] [-h] <input_file> <output_file> [key] [iv]

Parameters:
  - -n           : Optional. Dry-run mode. Prints the command without executing it.
  - -h           : Optional. Displays this help message.
  - <input_file> : The path to the file to decrypt.
  - <output_file>: The path where the decrypted file will be saved.
  - [key]        : Optional. The encryption key (32 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_KEY.
  - [iv]         : Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV.

Description:
  This function decrypts the specified input file using AES-256-CBC with OpenSSL, using either the provided key
  or the SHELL_SHIELD_ENCRYPTION_KEY environment variable. The decrypted output is saved to the specified output file.
  It checks for OpenSSL availability, validates the key and IV lengths, and ensures the input file exists.
  The function is compatible with both macOS and Linux. In dry-run mode, it prints the decryption command without executing it.

Example:
  shell::decode::file::aes256cbc encrypted.bin decrypted.txt "my64byteKey1234567890123456789012345678901234567890"  # Decrypts with specified key
  export SHELL_SHIELD_ENCRYPTION_KEY="my64byteKey1234567890123456789012345678901234567890"
  shell::decode::file::aes256cbc -n encrypted.bin decrypted.txt  # Prints decryption command without executing
"

USAGE_SHELL_FZF_REMOVE_BOOKMARK_DOWN="
shell::fzf_remove_bookmark_down function
Interactively selects inactive bookmark paths using fzf and removes them from the bookmarks file.

Usage:
  shell::fzf_remove_bookmark_down [-n] [-h]

Parameters:
  - -n        : Optional. Dry-run mode. Prints the command without executing it.
  - -h        : Optional. Displays this help message.

Description:
  This function removes inactive bookmark paths from the bookmarks file using fzf.
"

USAGE_SHELL_ADD_KEY_CONF_COMMENT="
shell::add_key_conf_comment function
Adds a configuration entry (key=value) with an optional comment to the constant configuration file.
The value is encoded using Base64 before being saved.

Usage:
shell::add_key_conf_comment [-n] <key> <value> [comment]

Parameters:
  - -n        : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - <key>     : The configuration key.
  - <value>   : The configuration value to be encoded and saved.
  - [comment] : Optional comment to be added above the key-value pair.

Description:
This function encodes the value using Base64 (with newline characters removed) and appends a line in the format:
# comment (if provided)
key=encoded_value
to the configuration file defined by SHELL_KEY_CONF_FILE.
If the key already exists, a warning is shown and the function exits.
"

USAGE_SHELL_ADD_PROTECTED_KEY_CONF="
shell::add_protected_key_conf function
Adds a key to the protected key list stored in protected.conf.

Usage:
shell::add_protected_key_conf [-n] [-h] <key>

Parameters:
  - -n        : Optional. Dry-run mode. Prints the command without executing it.
  - -h        : Optional. Displays this help message.
  - <key>     : The key to mark as protected.

Parameters:
  - -n    : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - <key> : The key to mark as protected.
"

USAGE_SHELL_FZF_ADD_PROTECTED_KEY_CONF="
shell::fzf_add_protected_key_conf function
Interactively selects a key from the configuration file and adds it to the protected list.

Usage:
shell::fzf_add_protected_key_conf [-n] [-h]

Parameters:
  - -n        : Optional. Dry-run mode. Prints the command without executing it.
  - -h        : Optional. Displays this help message.

Description:
This function uses fzf to select a key from the configuration file (excluding comments),
and adds it to the protected.conf file.
"

USAGE_SHELL_FZF_REMOVE_PROTECTED_KEY_CONF="
shell::fzf_remove_protected_key_conf function
Interactively selects a protected key using fzf and removes it from protected.conf.

Usage:
shell::fzf_remove_protected_key_conf [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the removal command is printed using shell::logger::cmd_copy instead of executed.
  - -h : Optional. Displays this help message.

Description:
This function reads the protected.conf file, uses fzf to let the user select a key,
and removes the selected key using sed. In dry-run mode, the command is printed instead of executed.
"

USAGE_SHELL_SYNC_PROTECTED_KEY_CONF="
shell::sync_protected_key_conf function
Synchronizes the protected.conf file by removing keys that no longer exist in key.conf.

Usage:
shell::sync_protected_key_conf [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the updated protected.conf is printed using shell::logger::cmd_copy instead of being applied.
  - -h : Optional. Displays this help message.

Description:
This function compares the keys listed in protected.conf with those in key.conf.
Any protected key that is not found in key.conf will be removed.
In dry-run mode, the updated list is printed instead of being written to the file.
"

USAGE_SHELL_SET_PERMISSIONS="
shell::set_permissions function
Sets file or directory permissions using human-readable group syntax.

Usage:
shell::set_permissions [-n] <target> [owner=...] [group=...] [others=...]

Parameters:
  - -n          : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
  - <target>    : The file or directory to set permissions on.
  - [owner=...] : Optional. Set permissions for the owner (e.g., owner=read,write).
  - [group=...] : Optional. Set permissions for the group (e.g., group=read,execute).
  - [others=...]: Optional. Set permissions for others (e.g., others=read).

Description:
  This function allows you to set permissions on a file or directory using a human-readable format.
  It supports specifying permissions for the owner, group, and others using keywords like read, write, and execute.
  The function constructs a chmod command based on the provided arguments and executes it.
  If the -n flag is provided, it prints the command instead of executing it.
  The function checks if the target exists and is accessible before attempting to change permissions.
  It also validates the permission groups and provides error messages for invalid inputs.
"

USAGE_SHELL_FZF_SET_PERMISSIONS="
shell::fzf_set_permissions function
Interactively selects permissions for a file or directory using fzf and applies them via shell::set_permissions.

Usage:
shell::fzf_set_permissions [-n] [-h] <target>

Parameters:
  - -n        : Optional dry-run flag. If provided, the chmod command is printed using shell::logger::cmd_copy instead of executed.
  - -h        : Optional. Displays this help message.
  - <target>  : The file or directory to modify permissions for.

Description:
This function prompts the user to select permissions for owner, group, and others using fzf.
It then delegates the permission setting to shell::set_permissions.
"

USAGE_SHELL_FZF_VIEW_SSH_KEY="
shell::fzf_view_ssh_key function
Interactively selects an SSH key file from HOME/.ssh using fzf,
and previews its contents in real-time in a wrapped preview window.

Usage:
shell::fzf_view_ssh_key [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the preview command is printed using shell::logger::cmd_copy instead of executed.
  - -h : Optional. Displays this help message.

Description:
This function lists files within the user's SSH directory (HOME/.ssh),
excluding common non-key files. It uses fzf to provide an interactive
selection interface with a preview window that shows the contents of
each file in real-time. The preview is wrapped for readability.
"

USAGE_SHELL_FZF_REMOVE_SSH_KEYS="
shell::fzf_remove_ssh_keys function
Interactively selects one or more SSH key files from HOME/.ssh using fzf and removes them.

Usage:
shell::fzf_remove_ssh_keys [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the removal command is printed using shell::logger::cmd_copy instead of executed.
  - -h : Optional. Displays this help message.

Description:
This function lists SSH key files in the user's SSH directory (HOME/.ssh),
excluding common non-key files. It uses fzf with multi-select to allow the user
to choose one or more files to delete. After confirmation, the selected files
are removed using (rm). In dry-run mode, the removal commands are printed instead.
"

USAGE_SHELL_FZF_VIEW_KEY_CONF_VISUALIZATION="
shell::fzf_view_key_conf_viz function
Interactively selects a configuration key using fzf and displays its decoded value in real-time.

Usage:
  shell::fzf_view_key_conf_viz [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the clipboard copy command is printed instead of executed.
  - -h : Optional help flag. Displays this help message.

Description:
  This function checks if the configuration file exists. If not, it displays an error.
  It then uses fzf to interactively select a configuration key from the file, showing
  the Base64-decoded value in real-time in a preview window, formatted as "key-value"
  with the key in yellow and the value in cyan. Once a key is selected, its decoded value
  is copied to the clipboard unless in dry-run mode, where the copy command is printed.
"

USAGE_SHELL_FZF_VIEW_INI_VIZ="
shell::fzf_view_ini_viz function
Interactively previews all key-value pairs in each section of an INI file using fzf in a real-time wrapped vertical layout.

Usage:
shell::fzf_view_ini_viz <file>

Parameters:
  - <file> : The path to the INI file.

Description:
This function lists all sections in the specified INI file using shell::list_ini_sections,
and uses fzf to preview all key-value pairs in each section in real-time.
The preview window wraps lines and simulates a tree-like layout for readability.
"

USAGE_SHELL_FZF_VIEW_INI_VIZ_SUPER="
shell::fzf_view_ini_viz_super function
Interactively previews all key-value pairs in each section of an INI file using fzf in a real-time wrapped vertical layout.

Usage:
shell::fzf_view_ini_viz_super <file> [--json|--yaml|--multi]

Parameters:
  - <file>  : The path to the INI file.
  - --json  : Optional. Export the selected section as JSON.
  - --yaml  : Optional. Export the selected section as YAML.
  - --multi : Optional. Allow multi-key selection and export.

Description:
This function lists all sections in the specified INI file using shell::list_ini_sections,
and uses fzf to preview all key-value pairs in each section in real-time.
The preview window wraps lines and simulates a tree-like layout for readability.
It supports exporting the selected section as JSON or YAML, or selecting multiple keys for export.

Example:
shell::fzf_view_ini_viz_super config.ini
shell::fzf_view_ini_viz_super config.ini --json
shell::fzf_view_ini_viz_super config.ini --multi
"

USAGE_SHELL_FZF_EDIT_INI_VIZ="
shell::fzf_edit_ini_viz function
Interactively edits or renames a key in an INI file using fzf.

Usage:
shell::fzf_edit_ini_viz [-h] <file>

Parameters:
  - -h        : Optional. Displays this help message.
  - <file>    : The path to the INI file.

Description:
This function allows the user to select a section and a key from an INI file,
then choose to either edit the value of the key or rename the key.
It uses fzf for interactive selection and sed for in-place editing.
"

USAGE_SHELL_ADD_WORKSPACE="
shell::add_workspace function
Creates a new workspace with profile.conf and default .ssh/*.conf templates populated via shell::write_ini.

Usage:
shell::add_workspace [-n] [-h] <workspace_name>

Parameters:
  - -n                : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
  - -h                : Optional. Displays this help message.
  - <workspace_name>  : The name of the workspace to create.

Description:
This function creates a new workspace directory under $SHELL_CONF_WORKING_WORKSPACE/<workspace_name>,
initializes a profile.conf file and a .ssh/ directory with default SSH config templates (db.conf, redis.conf, etc.).
It uses shell::write_ini to populate each .conf file with [dev] and [uat] blocks.
"

USAGE_SHELL_REMOVE_WORKSPACE="
shell::remove_workspace function
Removes a workspace directory after confirmation.

Usage:
shell::remove_workspace [-n] [-h] <workspace_name>

Parameters:
  - -n               : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
  - -h               : Optional. Displays this help message.
  - <workspace_name> : The name of the workspace to remove.

Description:
Prompts for confirmation before deleting the workspace directory.
"

USAGE_SHELL_FZF_VIEW_WORKSPACE="
shell::fzf_view_workspace function
Interactively selects a .ssh/*.conf file from a workspace and previews it using shell::fzf_view_ini_viz.

Usage:
shell::fzf_view_workspace [-h] <workspace_name>

Parameters:
  - -h                : Optional. Displays this help message.
  - <workspace_name>  : The name of the workspace to view.

Description:
This function locates all .conf files under $SHELL_CONF_WORKING_WORKSPACE/<workspace_name>/.ssh/,
and uses fzf to let the user select one. The selected file is then passed to shell::fzf_view_ini_viz
for real-time preview of all decoded values.
"

USAGE_SHELL_FZF_EDIT_WORKSPACE="
shell::fzf_edit_workspace function
Interactively selects a .ssh/*.conf file from a workspace and opens it for editing using shell::fzf_edit_ini_viz.
Usage:
shell::fzf_edit_workspace [-h] <workspace_name>

Parameters:
  - -h                : Optional. Displays this help message.
  - <workspace_name>  : The name of the workspace to edit.

Description:
This function locates all .conf files under $SHELL_CONF_WORKING_WORKSPACE/<workspace_name>/.ssh/,
and uses fzf to let the user select one. The selected file is then passed to shell::fzf_edit_ini_viz
for editing.
"

USAGE_SHELL_FZF_REMOVE_WORKSPACE="
shell::fzf_remove_workspace function
Interactively selects a workspace using fzf and removes it after confirmation.

Usage:
shell::fzf_remove_workspace [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the removal command is printed using shell::logger::cmd_copy instead of executed.
  - -h : Optional. Displays this help message.

Description:
This function lists all workspace directories under $SHELL_CONF_WORKING_WORKSPACE,
uses fzf to let the user select one, and then calls shell::remove_workspace to delete it.
"

USAGE_SHELL_RENAME_WORKSPACE="
shell::rename_workspace function
Renames a workspace directory from an old name to a new name.

Usage:
shell::rename_workspace [-n] [-h] <old_name> <new_name>

Parameters:
  - -n          : Optional dry-run flag. If provided, the rename command is printed using shell::logger::cmd_copy instead of executed.
  - -h          : Optional. Displays this help message.
  - <old_name>  : The current name of the workspace.
  - <new_name>  : The new name for the workspace.

Description:
This function renames a workspace directory under $SHELL_CONF_WORKING_WORKSPACE
from <old_name> to <new_name>. It checks for the existence of the old workspace
and ensures the new name does not already exist. If valid, it renames the directory.
"

USAGE_SHELL_FZF_RENAME_WORKSPACE="
shell::fzf_rename_workspace function
Interactively selects a workspace using fzf and renames it.

Usage:
shell::fzf_rename_workspace [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the rename command is printed using shell::logger::cmd_copy instead of executed.
  - -h : Optional. Displays this help message.

Description:
This function lists all workspace directories under $SHELL_CONF_WORKING_WORKSPACE,
uses fzf to let the user select one, prompts for a new name, and then calls shell::rename_workspace
to rename the selected workspace.
"

USAGE_SHELL_FZF_MANAGE_WORKSPACE="
shell::fzf_manage_workspace function
Interactively selects a workspace and performs an action (view, edit, rename, remove) using fzf.

Usage:
shell::fzf_manage_workspace [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, actions that support dry-run will be executed in dry-run mode.
  - -h : Optional. Displays this help message.

Description:
This function lists all workspace directories under $SHELL_CONF_WORKING_WORKSPACE,
uses fzf to let the user select one, then presents a list of actions to perform on the selected workspace.
Supported actions include: view, edit, rename, and remove.
"

USAGE_SHELL_CLONE_WORKSPACE="
shell::clone_workspace function
Clones an existing workspace to a new workspace directory.

Usage:
shell::clone_workspace [-n] [-h] <source_workspace> <destination_workspace>

Parameters:
  - -n                      : Optional dry-run flag. If provided, the clone command is printed using shell::logger::cmd_copy instead of executed.
  - -h                      : Optional. Displays this help message.
  - <source_workspace>      : The name of the existing workspace to clone.
  - <destination_workspace> : The name of the new workspace to create.

Description:
This function clones a workspace directory under $SHELL_CONF_WORKING_WORKSPACE
from <source_workspace> to <destination_workspace>. It checks for the existence of the source
and ensures the destination does not already exist. If valid, it copies the entire directory.
"

USAGE_SHELL_FZF_CLONE_WORKSPACE="
shell::fzf_clone_workspace function
Interactively selects a workspace using fzf and clones it to a new workspace.

Usage:
shell::fzf_clone_workspace [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the clone command is printed using shell::logger::cmd_copy instead of executed.
  - -h : Optional. Displays this help message.

Description:
This function lists all workspace directories under $SHELL_CONF_WORKING_WORKSPACE,
uses fzf to let the user select one, prompts for a new name, and then calls shell::clone_workspace
to clone the selected workspace.
"

USAGE_SHELL_DUMP_WORKSPACE_JSON="
shell::dump_workspace_json function
Interactively selects a workspace, section, and fields to export as JSON from .ssh/*.conf files.

Usage:
shell::dump_workspace_json [-h]

Parameters:
  - -h        : Optional. Displays this help message.

Description:
This function uses fzf to let the user select a workspace, then a section (e.g., [dev], [uat]),
and then one or more fields to export. It reads values from .ssh/*.conf files and outputs a JSON
structure to the terminal and copies it to the clipboard.
"

USAGE_SHELL_POPULATE_SSH_CONF="
shell::populate_ssh_conf function
Populates a .conf file with default [base], [dev], and [uat] blocks using shell::write_ini.

Usage:
shell::populate_ssh_conf [-h] <file_path> <file_name>

Parameters:
  - -h          : Optional. Displays this help message.
  - <file_path> : The full path to the .conf file to populate.
  - <file_name> : The name of the .conf file (e.g., server.conf, kafka.conf).

Description:
This function writes default SSH tunnel configuration blocks to the specified .conf file.
It includes a [base] block with shared SSH settings, and [dev] and [uat] blocks with
environment-specific overrides. Additional service-specific keys are added based on the
file name (e.g., kafka.conf, nginx.conf).

The function uses shell::write_ini to write each key-value pair into the appropriate section.
Port numbers are assigned based on a predefined mapping, with +1 offset for UAT.

Example:
shell::populate_ssh_conf "$HOME/.shell-config/workspace/my-app/.ssh/server.conf" "server.conf"
"

USAGE_SHELL_ADD_WORKSPACE_SSH_CONF="
shell::add_workspace_ssh_conf function
Adds a missing SSH configuration file to a specified workspace.

Usage:
shell::add_workspace_ssh_conf [-n] [-h] <workspace_name> <ssh_conf_name>

Parameters:
  - -n                : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
  - -h                : Optional. Displays this help message.
  - <workspace_name>  : The name of the workspace.
  - <ssh_conf_name>   : The name of the SSH configuration file to add (e.g., kafka.conf).

Description:
This function checks if the specified SSH configuration file exists in the workspace's .ssh directory.
If it does not exist, it creates the file and populates it using shell::populate_ssh_conf.

Example:
shell::add_workspace_ssh_conf my-app kafka.conf
shell::add_workspace_ssh_conf -n my-app kafka.conf
"

USAGE_SHELL_FZF_ADD_WORKSPACE_SSH_CONF="
shell::fzf_add_workspace_ssh_conf function
Interactively selects a workspace and SSH config to add using fzf.

Usage:
shell::fzf_add_workspace_ssh_conf [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
  - -h : Optional. Displays this help message.

Description:
This function uses fzf to select a workspace and a missing SSH configuration file.
It then calls shell::add_workspace_ssh_conf to add the selected file if it does not exist.

Example:
shell::fzf_add_workspace_ssh_conf
shell::fzf_add_workspace_ssh_conf -n
"

USAGE_SHELL_FZF_REMOVE_BOOKMARK="
shell::fzf_remove_bookmark function
Interactively selects a bookmark using fzf and removes it from the bookmarks file.

Usage:
  shell::fzf_remove_bookmark [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the removal command is printed instead of executed.
  - -h : Optional help flag. Displays this help message.

Description:
  This function checks if the bookmarks file exists. If not, it displays an error.
  It then reads all bookmarks, formats them for fzf display, and allows the user to
  interactively select a bookmark to remove. The selected bookmark is removed from
  the bookmarks file using a secure temporary file.

Example usage:
  shell::fzf_remove_bookmark       # Interactively select and remove a bookmark.
  shell::fzf_remove_bookmark -n    # Dry-run: print removal command without executing.
"

USAGE_SHELL_RENAME_BOOKMARK="
shell::rename_bookmark function
Renames a bookmark in the bookmarks file.

Usage:
  shell::rename_bookmark [-n] [-h] <old_name> <new_name>

Parameters:
  - -n          : Optional dry-run flag. If provided, the rename command is printed instead of executed.
  - -h          : Optional. Displays this help message.
  - <old_name>  : The current name of the bookmark.
  - <new_name>  : The new name to assign to the bookmark.

Description:
  This function searches for a bookmark entry in the bookmarks file that ends with <old_name>.
  If found, it replaces the bookmark name with the new name using a sed command.
  The sed command is constructed differently for macOS and Linux due to differences in the in-place edit flag.

Example usage:
  shell::rename_bookmark old_name new_name
  shell::rename_bookmark -n old_name new_name
"

USAGE_SHELL_FZF_RENAME_BOOKMARK="
shell::fzf_rename_bookmark function
Interactively selects a bookmark using fzf and renames it.

Usage:
  shell::fzf_rename_bookmark [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the rename command is printed instead of executed.
  - -h : Optional help flag. Displays this help message.

Description:
  This function checks if the bookmarks file exists. If not, it displays an error.
  It then reads all bookmarks, formats them for fzf display, and allows the user to
  interactively select a bookmark to rename. The user is prompted to enter a new name,
  and the shell::rename_bookmark function is called to perform the rename.

Example usage:
  shell::fzf_rename_bookmark       # Interactively select and rename a bookmark.
  shell::fzf_rename_bookmark -n    # Dry-run: print rename command without executing.
"

USAGE_SHELL_RENAME_DIR_BASE_BOOKMARK="
shell::rename_dir_base_bookmark function
Renames the directory associated with a bookmark.

Usage:
  shell::rename_dir_base_bookmark [-n] [-h] <bookmark_name> <new_dir_name>

Parameters:
  - -n              : Optional dry-run flag. If provided, the rename command is printed instead of executed.
  - -h              : Optional help flag. Displays this help message.
  - <bookmark_name> : The name of the bookmark whose directory should be renamed.
  - <new_dir_name>  : The new name for the directory.

Description:
  This function finds the directory path associated with the given bookmark name
  and renames the directory to the new name provided. It validates that the bookmark exists,
  the directory exists, and the target name does not already exist.

Example usage:
  shell::rename_dir_base_bookmark my-bookmark new-dir-name
  shell::rename_dir_base_bookmark -n my-bookmark new-dir-name
"

USAGE_SHELL_FZF_RENAME_DIR_BASE_BOOKMARK="
shell::fzf_rename_dir_base_bookmark function
Interactively selects a bookmark using fzf and renames its associated directory.

Usage:
  shell::fzf_rename_dir_base_bookmark [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the rename command is printed instead of executed.
  - -h : Optional help flag. Displays this help message.

Description:
  This function checks if the bookmarks file exists. If not, it displays an error.
  It then reads all bookmarks, formats them for fzf display, and allows the user to
  interactively select a bookmark. The user is prompted to enter a new directory name,
  and the shell::rename_dir_base_bookmark function is called to perform the rename.

Example usage:
  shell::fzf_rename_dir_base_bookmark       # Interactively select and rename a directory.
  shell::fzf_rename_dir_base_bookmark -n    # Dry-run: print rename command without executing.
"

USAGE_SHELL_FZF_COPY_SSH_KEY_VALUE="
shell::fzf_copy_ssh_key_value function
Uses fzf to select an SSH key file and copies its contents to the clipboard using shell::clip_value.

Usage:
  shell::fzf_copy_ssh_key_value [-h]

Parameters:
  - -h : Optional help flag. Displays this help message.

Description:
  This function searches for SSH key files in ~/.ssh, filters out public keys and config files,
  and presents them via fzf for selection. Once selected, the contents of the file
  are copied to the clipboard using shell::clip_value.
"

USAGE_SHELL_OPEN_SSH_TUNNEL="
shell::open_ssh_tunnel function
Opens a direct SSH tunnel connection using provided arguments.

Usage:
shell::open_ssh_tunnel [-n] [-h] <key_file> <local_port> <target_addr> <target_port> <user> <server_addr> <server_port> [alive_interval] [timeout]

Parameters:
- -n               : Optional dry-run flag.
- -h               : Optional. Displays this help message.
- <key_file>       : Path to the SSH private key.
- <local_port>     : Local port to bind.
- <target_addr>    : Target service address on the server.
- <target_port>    : Target service port on the server.
- <user>           : SSH username.
- <server_addr>    : SSH server address.
- <server_port>    : SSH server port.
- [alive_interval] : Optional. ServerAliveInterval seconds (default: 60).
- [timeout]        : Optional. ConnectTimeout seconds (default: 10).

Description:
Opens an SSH tunnel using the provided parameters. Supports dry-run mode.

Example:
shell::open_ssh_tunnel ~/.ssh/id_rsa 8080 127.0.0.1 80 sysadmin 192.168.1.10 22
"

USAGE_SHELL_OPEN_WORKSPACE_SSH_TUNNEL="
shell::open_workspace_ssh_tunnel function
Opens an SSH tunnel using configuration from a workspace .ssh/*.conf file.

Usage:
shell::open_workspace_ssh_tunnel [-n] [-h] <workspace_name> <conf_name> <section>

Parameters:
- -n               : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy.
- -h               : Optional. Displays this help message.
- <workspace_name> : The name of the workspace.
- <conf_name>      : The name of the SSH configuration file (e.g., kafka.conf).
- <section>        : The section to use (e.g., dev, uat).

Description:
This function reads the [base] section first, then overrides with values from the specified section.
It delegates the actual SSH tunnel execution to shell::open_ssh_tunnel.

Example:
shell::open_workspace_ssh_tunnel my-app db.conf dev
shell::open_workspace_ssh_tunnel -n my-app kafka.conf uat
"

USAGE_SHELL_FZF_OPEN_WORKSPACE_SSH_TUNNEL="
shell::fzf_open_workspace_ssh_tunnel function
Interactively selects a workspace and SSH config section to open an SSH tunnel.

Usage:
shell::fzf_open_workspace_ssh_tunnel [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy.
  - -h : Optional. Displays this help message.

Description:
Uses fzf to select a workspace and a .conf file, then selects a section (dev or uat),
and opens an SSH tunnel using shell::open_workspace_ssh_tunnel.

Example:
shell::fzf_open_workspace_ssh_tunnel
shell::fzf_open_workspace_ssh_tunnel -n
"

USAGE_SHELL_VALIDATE_IP_ADDR="
shell::validate_ip_addr function
Validates whether a given string is a valid IPv4 or IPv6 address.

Usage:
shell::validate_ip_addr [-h] <ip_address>

Parameters:
  - -h        : Optional. Displays this help message.
  - <ip_address> : The IP address string to validate.

Description:
This function checks if the input string is a valid IPv4 or IPv6 address.
IPv4 format: X.X.X.X where each X is 0-255.
IPv6 format: eight groups of four hexadecimal digits separated by colons.

Example:
shell::validate_ip_addr 192.168.1.1       # Valid IPv4
shell::validate_ip_addr fe80::1ff:fe23::1 # Valid IPv6
"

USAGE_SHELL_VALIDATE_HOSTNAME="
shell::validate_hostname function
Validates whether a given string is a valid hostname.

Usage:
shell::validate_hostname [-h] <hostname>

Parameters:
  - -h        : Optional. Displays this help message.
  - <hostname> : The hostname string to validate.

Description:
This function checks if the input string is a valid hostname.
A valid hostname:
- Contains only letters, digits, and hyphens.
- Each label is 1-63 characters long.
- The full hostname is up to 253 characters.
- Labels cannot start or end with a hyphen.

Example:
shell::validate_hostname example.com       # Valid
shell::validate_hostname -invalid-hostname # Invalid
"

USAGE_SHELL_OPEN_SSH_TUNNEL_BUILDER="
shell::open_ssh_tunnel_builder function
Interactively builds and opens an SSH tunnel by prompting for each required field.

Usage:
shell::open_ssh_tunnel_builder [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy.
  - -h : Optional. Displays this help message.

Description:
This function prompts the user to enter each required field for an SSH tunnel connection.
It uses fzf to select the SSH private key file from HOME/.ssh and then calls shell::open_ssh_tunnel.

Example:
shell::open_ssh_tunnel_builder
shell::open_ssh_tunnel_builder -n
"

USAGE_SHELL_RENAME_SSH_KEY="
shell::rename_ssh_key function
Renames an SSH key file (private or public) in the SSH directory.

Usage:
shell::rename_ssh_key [-n] [-h] <old_name> <new_name>

Parameters:
  - -n          : Optional dry-run flag. If provided, the rename command is printed using shell::logger::cmd_copy instead of executed.
  - -h          : Optional. Displays this help message.
  - <old_name>  : The current name of the SSH key file.
  - <new_name>  : The new name for the SSH key file.

Description:
This function renames an SSH key file in the user's SSH directory (HOME/.ssh).
It checks if the old key file exists, ensures the new name does not already exist,
and performs the rename operation.

Example:
shell::rename_ssh_key old_key_name new_key_name
"

USAGE_SHELL_FZF_RENAME_SSH_KEY="
shell::fzf_rename_ssh_key function
Interactively selects an SSH key file and renames it.

Usage:
shell::fzf_rename_ssh_key [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the rename command is printed using shell::logger::cmd_copy.
  - -h : Optional. Displays this help message.

Description:
This function lists SSH key files in the user's SSH directory (HOME/.ssh),
excluding common non-key files. It uses fzf to provide an interactive selection interface
for renaming an SSH key file. The user is prompted to enter a new name for the selected key.
If the dry-run flag is set, it prints the rename command instead of executing it.
"

USAGE_SHELL_TUNE_SSH_TUNNEL="
shell::tune_ssh_tunnel function
Opens an interactive SSH session using the provided SSH configuration parameters.

Usage:
shell::tune_ssh_tunnel [-n] [-h] <private_key> <user> <host> <port>

Parameters:
  - -n            : Optional dry-run flag. If provided, the SSH command is printed using shell::logger::cmd_copy instead of executed.
  - -h            : Optional. Displays this help message.
  - <private_key> : Path to the SSH private key file.
  - <user>        : SSH username.
  - <host>        : SSH server address.
  - <port>        : SSH server port.

Description:
This function constructs and executes an SSH command to connect to a remote server using the specified credentials.
It supports dry-run mode for previewing the command.

Example:
shell::tune_ssh_tunnel ~/.ssh/id_rsa sysadmin 192.168.1.10 22
shell::tune_ssh_tunnel -n ~/.ssh/id_rsa sysadmin example.com 2222
"

USAGE_SHELL_TUNE_SSH_TUNNEL_BUILDER="
shell::tune_ssh_tunnel_builder function
Interactively builds and opens an SSH tunnel by prompting for each required field.

Usage:
shell::tune_ssh_tunnel_builder [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy.
  - -h : Optional. Displays this help message.

Description:
This function prompts the user to enter each required field for an SSH tunnel connection.
It uses fzf to select the SSH private key file from HOME/.ssh and then calls shell::tune_ssh_tunnel.

Example:
shell::tune_ssh_tunnel_builder
shell::tune_ssh_tunnel_builder -n
"

USAGE_SHELL_TUNE_WORKSPACE_SSH_TUNNEL="
shell::tune_workspace_ssh_tunnel function
Opens an SSH tunnel using configuration from a workspace .ssh/*.conf file, with tuning options.

Usage:
shell::tune_workspace_ssh_tunnel [-n] [-h] <workspace_name> <conf_name> <section>

Parameters:
  - -n               : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy.
  - -h               : Optional. Displays this help message.
  - <workspace_name> : The name of the workspace.
  - <conf_name>      : The name of the SSH configuration file (e.g., kafka.conf).
  - <section>        : The section to use (e.g., dev, uat).

Description:
This function reads the [base] section first, then overrides with values from the specified section.
It delegates the actual SSH tunnel execution to shell::tune_ssh_tunnel.

Example:
shell::tune_workspace_ssh_tunnel my-app kafka.conf dev
shell::tune_workspace_ssh_tunnel -n my-app kafka.conf uat
"

USAGE_SHELL_FZF_TUNE_WORKSPACE_SSH_TUNNEL="
shell::fzf_tune_workspace_ssh_tunnel function
Interactively selects a workspace and SSH config section to tune an SSH tunnel.

Usage:
shell::fzf_tune_workspace_ssh_tunnel [-n]

Parameters:
- -n : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy.

Description:
Uses fzf to select a workspace and a .conf file, then selects a section (dev or uat),
and tunes an SSH tunnel using shell::tune_workspace_ssh_tunnel.
"

USAGE_SHELL_POPULATE_GEMINI_CONF="
shell::populate_gemini_conf function
Populates the Gemini agent configuration file with default keys if they do not already exist.

Usage:
shell::populate_gemini_conf [-h] [file_path]

Parameters:
  - -h          : Optional. Displays this help message.
  - [file_path] : Optional. The path to the Gemini configuration file. Defaults to SHELL_KEY_CONF_AGENT_GEMINI_FILE.

Description:
This function writes default Gemini configuration keys to the specified file under the [gemini] section.
It checks if each key already exists before writing. Values are encoded using Base64 and written using shell::write_ini.

Example:
shell::populate_gemini_conf
shell::populate_gemini_conf "User/.config/gemini.conf"
"

USAGE_SHELL_DUMP_BASE_JSON="
shell::dump_ini_json function
Dumps all sections and their key-value pairs from an INI file as a JSON object.

Usage:
shell::dump_ini_json [-h] <file>

Parameters:
  - -h      : Optional. Displays this help message.
  - <file>  : The path to the INI file.

Description:
This function reads all sections and their keys from the specified INI file,
decodes their values, and outputs them as a structured JSON object.
"

USAGE_SHELL_DUMP_GEMINI_CONF_JSON="
shell::dump_gemini_conf_json function
Dumps all sections from the Gemini config file as JSON.

Usage:
shell::dump_gemini_conf_json [-h]

Parameters:
  - -h : Optional. Displays this help message.

Description:
This function calls shell::dump_ini_json using SHELL_KEY_CONF_AGENT_GEMINI_FILE.
"

USAGE_SHELL_EVAL_GEMINI_EN_VI="
shell::eval_gemini_en_vi function
Sends an English sentence to Gemini for grammar evaluation and interactively displays corrections and examples.

Usage:
shell::eval_gemini_en_vi [-n] [-d] [-h] <sentence_english>

Parameters:
  - -n : Optional dry-run flag. If provided, the curl command is printed using shell::logger::cmd_copy instead of executed.
  - -d : Optional debugging flag. If provided, debug information is printed.
  - -h : Optional help flag. If provided, displays usage information.

Description:
This function reads a prompt from ~/.shell-config/agents/gemini/prompts/english_translation_tutor_request.txt,
sends it to the Gemini API using curl, and uses jq and fzf to interactively select and display
the suggested correction and example sentences.
"

USAGE_SHELL_MAKE_GEMINI_REQUEST="
shell::make_gemini_request function
Sends a request to the Gemini API with the provided payload.

Usage:
shell::make_gemini_request [-n] [-d] [-h] <request_payload>

Parameters:
  - -n : Optional dry-run flag. If provided, the curl command is printed using shell::logger::cmd_copy instead of executed.
  - -d : Optional debugging flag. If provided, debug information is printed.
  - -h : Optional help flag. If provided, displays usage information.
  - <request_payload> : The JSON payload to send to the Gemini API.

Description:
This function reads the Gemini configuration file, constructs a request to the Gemini API,
and sends the provided payload. It handles errors, sanitizes the response, and returns the parsed JSON.
It also supports debugging and dry-run modes.
"

USAGE_SHELL_GET_MIME_TYPE="
shell::get_mime_type function
Determines the MIME type of a file.

Usage:
  shell::get_mime_type [-h] <file_path>

Parameters:
  - -h         : Optional. Displays this help message.
  - <file_path>: The path to the file.

Description:
  Returns the appropriate MIME type based on file extension.
"

USAGE_SHELL_ENCODE_BASE64_FILE="
shell::encode_base64_file function
Encodes a file to base64 for API submission.

Usage:
  shell::encode_base64_file [-n] [-h] <file_path>

Parameters:
  - -n         : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
  - -h         : Optional. Displays this help message.
  - <file_path>: The path to the file to encode.

Description:
  Encodes the specified file to base64 format for API consumption.
  Handles platform differences between macOS and Linux.
"

USAGE_SHELL_ENTER="
shell::enter function
Prompts the user with a question and returns the entered value.
The function will keep prompting until a non-empty value is entered.

Usage:
  shell::enter [-h] <question>

Parameters:
  - -h          : Optional. Displays this help message.
  - <question>  : The question/prompt to display to the user.

Returns:
  The non-empty value entered by the user (as output to stdout)

Description:
  This function prompts the user with a question and waits for input.
  It validates that the user enters a non-empty value and will continue
  prompting until a valid value is provided.
  The function supports a help flag (-h) to display usage information.
  Unlike shell::ask which expects yes/no answers, this function accepts any text input
  but requires it to be non-empty.

Example:
  name=(shell::enter \"What is your name?\")
  echo \"Hello, $name\"
  email=(shell::enter \"Enter your email address?\")
  echo \"Email: $email\"
"

USAGE_SHELL_ASK="
shell::ask function
Interactively asks a yes/no question and returns 1 for yes, 0 for no.

Usage:
  shell::ask [-h] <question>

Parameters:
  - -h          : Optional help flag. Displays this help message.
  - <question>  : The question to ask the user.

Description:
  This function prompts the user with a yes/no question and waits for input.
  It returns 1 if the user answers "yes" (or "y"), and 0 for "no" (or "n").
  The function loops until a valid response is received.
  If the user provides an invalid response, it will continue to prompt.
  The function supports a help flag (-h) to display usage information.

Example:
  shell::ask \"Do you want to continue?\"
  if shell::ask \"Do you want to proceed?\"; then
      echo \"User answered yes.\"
  else
      echo \"User answered no.\"
"

USAGE_SHELL_SELECT="
shell::select function
Prompts the user to select an option from a list of choices.

Usage:
  shell::select [-h] <option1> <option2> ... <optionN>

Parameters:
  - -h        	: Optional. Displays this help message.
  - <option1>...: A list of strings representing the choices.

Returns:
  The selected option string (as output to stdout).

Description:
  This function displays a numbered list of options to the user and prompts
  them to enter the number corresponding to their choice. It validates that
  the input is a number and falls within the valid range of options.
  The prompt and error messages are printed to stderr, so only the final
  selected value is sent to stdout, making it safe for command substitution.

Example:
  options=(\"Apple\" \"Banana\" \"Cherry\")
  fruit=&(shell::select \"&{options[@]}\")
  echo \"You selected: $fruit\"

  theme=&(shell::select \"Dark\" \"Light\" \"System\")
  echo \"Chosen theme: $theme\"
"

USAGE_SHELL_SELECT_KEY="
shell::select_key function
Prompts the user to select an option from a list of labels using fzf,
and returns the corresponding key.

Usage:
  shell::select_key [-h] \"Label1:Key1\" \"Label2:Key2\" ...

Parameters:
  - -h        	: Optional. Displays this help message.
  - \"Label:Key\"	: A list of strings, each containing a display label and a
                 	  return key, separated by a colon (:).

Returns:
  The key corresponding to the selected label (as output to stdout).
  The function will not return until a selection has been made.

Description:
  This function displays a list of user-friendly labels and allows the user
  to select one using fzf. It then returns the corresponding key value that
  was associated with the selected label. This is useful for presenting
  human-readable options while working with machine-readable identifiers.

Example:
  options=(\"User-Friendly Name:machine_name_1\" \"Production Server:prod_srv\")
  chosen_key=\$(shell::select_key \"\${options[@]}\")
  echo \"The script will now use the key: \$chosen_key\"
"

USAGE_SHELL_MULTISELECT="
shell::multiselect function
Prompts the user to select multiple options from a list of choices using fzf.

Usage:
  shell::multiselect [-h] <option1> <option2> ... <optionN>

Parameters:
  - -h        	: Optional. Displays this help message.
  - <option1>...: A list of strings representing the choices.

Returns:
  The selected option strings as space-separated values (as output to stdout).
  Returns empty string if no selections are made.

Description:
  This function uses fzf with multi-select capability to allow users to
  select multiple options from a provided list. Users can select options
  using Tab or Shift+Tab, and confirm their selection with Enter.
  The function handles empty selections gracefully and returns all
  selected options as a space-separated string.

Example:
  options=(\"Development\" \"Staging\" \"Production\")
  selected=\$(shell::multiselect \"\${options[@]}\")
  echo \"Selected environments: \$selected\"

  features=\$(shell::multiselect \"Feature A\" \"Feature B\" \"Feature C\")
  echo \"Selected features: \$features\"
"

USAGE_SHELL_MULTISELECT_KEY="
shell::multiselect_key function
Prompts the user to select multiple options from a list of labels using fzf,
and returns the corresponding keys.

Usage:
  shell::multiselect_key [-h] \"Label1:Key1\" \"Label2:Key2\" ...

Parameters:
  - -h        	: Optional. Displays this help message.
  - \"Label:Key\"	: A list of strings, each containing a display label and a
                 	  return key, separated by a colon (:).

Returns:
  The keys corresponding to the selected labels as space-separated values
  (as output to stdout). Returns empty string if no selections are made.

Description:
  This function displays a list of user-friendly labels and allows the user
  to select multiple options using fzf with multi-select capability. It then
  returns the corresponding key values that were associated with the selected
  labels. This is useful for presenting human-readable options while working
  with machine-readable identifiers in multi-selection scenarios.

Example:
  options=(\"Development:dev\" \"Staging:staging\" \"Production:prod\")
  environments=\$(shell::multiselect_key \"\${options[@]}\")
  echo \"Selected environments: \$environments\"

  services=(\"Web Server:nginx\" \"Database:postgresql\" \"Cache:redis\")
  selected=\$(shell::multiselect_key \"\${services[@]}\")
  echo \"Selected services: \$selected\"
"
