#!/bin/bash
# help.sh

USAGE_SHELL_GEN_SSH_KEY="
shell::gen_ssh_key function
Generates an SSH key pair (private and public) and saves them to the SSH directory.

Usage:
  shell::gen_ssh_key [-n] [-t key_type] [-p passphrase] [-h] [email] [key_filename]

Parameters:
  - -n              : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
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
  - -n              : Optional dry-run flag. If provided, kill commands are printed using shell::on_evict instead of executed.
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
  - Leverages shell::run_cmd for command execution and shell::on_evict for dry-run mode.
"

USAGE_SHELL_LIST_SSH_TUNNEL="
shell::list_ssh_tunnels function
Displays information about active SSH tunnel forwarding processes in a line-by-line format.

Usage:
  shell::list_ssh_tunnels [-n] [-h]

Parameters:
  - -n              : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
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
  - Leverages shell::run_cmd_eval for command execution and shell::on_evict for dry-run mode
"

USAGE_SHELL_FZF_SSH_KEY="
shell::fzf_ssh_keys function
Interactively selects an SSH key file (private or public) from $HOME/.ssh using fzf,
displays the absolute path of the selected file, and copies the path to the clipboard.

Usage:
  shell::fzf_ssh_keys [-h]

Parameters:
  - -h              : Optional. Displays this help message.

Description:
  This function lists files within the user's SSH directory ($HOME/.ssh).
  It filters out common non-key files and then uses fzf to provide an interactive selection interface.
  Once a file is selected, its absolute path is determined, displayed to the user,
  and automatically copied to the system clipboard using the shell::clip_value function.

Example usage:
  shell::fzf_ssh_keys # Launch fzf to select an SSH key and copy its path.

Requirements:
  - fzf must be installed.
  - The user must have a $HOME/.ssh directory.
  - Assumes the presence of helper functions: shell::install_package, shell::colored_echo, shell::clip_value, and shell::is_command_available.
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
  - Assumes the presence of helper functions: shell::install_package, shell::colored_echo, shell::run_cmd_eval.
"

USAGE_SHELL_READ_CONF="
shell::read_conf function
Sources a configuration file, allowing its variables and functions to be loaded into the current shell.

Usage:
  shell::read_conf [-n] [-h] <filename>

Parameters:
  - -n              : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
  - -h              : Optional. Displays this help message.
  - <filename>      : The configuration file to source.

Description:
  The function checks that a filename is provided and that the specified file exists.
  If the file is not found, an error message is displayed.
  In dry-run mode, the command 'source <filename >' is printed using shell::on_evict.
  Otherwise, the file is sourced using shell::run_cmd to log the execution.

Example:
  shell::read_conf ~/.my-config                # Sources the configuration file.
  shell::read_conf -n ~/.my-config             # Prints the sourcing command without executing it.
"

USAGE_SHELL_ADD_CONF="
shell::add_conf function
Adds a configuration entry (key=value) to a constant configuration file.
The value is encoded using Base64 before being saved.

Usage:
  shell::add_conf [-n] [-h] <key> <value>

Parameters:
  - -n       : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
  - -h       : Optional. Displays this help message.
  - <key>    : The configuration key.
  - <value>  : The configuration value to be encoded and saved.

Description:
  The function first checks for an optional dry-run flag (-n) and verifies that both key and value are provided.
  It encodes the value using Base64 (with newline characters removed) and then appends a line in the format:
      key=encoded_value
  to a constant configuration file (defined by SHELL_KEY_CONF_FILE). If the configuration file does not exist, it is created.

Example:
  shell::add_conf my_setting \"some secret value\"         # Encodes the value and adds the entry.
  shell::add_conf -n my_setting \"some secret value\"      # Prints the command without executing it.
"

USAGE_SHELL_FZF_GET_CONF="
shell::fzf_get_conf function
Interactively selects a configuration key from a constant configuration file using fzf,
then decodes and displays its corresponding value.

Usage:
  shell::fzf_get_conf [-h]

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
  shell::fzf_get_conf      # Interactively select a key and display its decoded value.
"

USAGE_SHELL_GET_VALUE_CONF="
shell::get_value_conf function
Retrieves and outputs the decoded value for a given configuration key from the key configuration file.

Usage:
  shell::get_value_conf [-h] <key>

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
  shell::get_value_conf my_setting   # Outputs the decoded value for the key 'my_setting'.
"

USAGE_SHELL_FZF_REMOVE_CONF="
shell::fzf_remove_conf function
Interactively selects a configuration key from a constant configuration file using fzf,
then removes the corresponding entry from the configuration file.

Usage:
  shell::fzf_remove_conf [-n] [-h]

Parameters:
  - -n              : Optional dry-run flag. If provided, the removal command is printed using shell::on_evict instead of executed.
  - -h              : Optional. Displays this help message.

Description:
  The function reads the configuration file defined by the constant SHELL_KEY_CONF_FILE, where each entry is in the format:
      key=encoded_value
  It extracts only the keys (before the '=') and uses fzf for interactive selection.
  Once a key is selected, it constructs a command to remove the line that starts with \"key=\" from the configuration file.
  The command uses sed with different options depending on the operating system (macOS or Linux).
  In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.

Example:
  shell::fzf_remove_conf         # Interactively select a key and remove its configuration entry.
  shell::fzf_remove_conf -n      # Prints the removal command without executing it.
"

USAGE_SHELL_FZF_UPDATE_CONF="
shell::fzf_update_conf function
Interactively updates the value for a configuration key in a constant configuration file.
The new value is encoded using Base64 before updating the file.

Usage:
  shell::fzf_update_conf [-n] [-h]

Parameters:
  - -n              : Optional dry-run flag. If provided, the update command is printed using shell::on_evict instead of executed.
  - -h              : Optional. Displays this help message.

Description:
  The function reads the configuration file defined by SHELL_KEY_CONF_FILE, which contains entries in the format:
      key=encoded_value
  It extracts only the keys and uses fzf to allow interactive selection.
  Once a key is selected, the function prompts for a new value, encodes it using Base64 (with newlines removed),
  and then updates the corresponding configuration entry in the file by replacing the line starting with \"key=\".
  The sed command used for in-place update differs between macOS and Linux.

Example:
  shell::fzf_update_conf       # Interactively select a key, enter a new value, and update its entry.
  shell::fzf_update_conf -n    # Prints the update command without executing it.
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
  - -n   : Optional dry-run flag. If provided, the renaming command is printed using shell::on_evict instead of executed.
  - -h   : Optional. Displays this help message.

Description:
  The function reads the configuration file defined by SHELL_KEY_CONF_FILE, which stores entries in the format:
      key=encoded_value
  It uses fzf to interactively select an existing key.
  After selection, the function prompts for a new key name and checks if the new key already exists.
  If the new key does not exist, it constructs a sed command to replace the old key with the new key in the file.
  The sed command uses in-place editing options appropriate for macOS (sed -i '') or Linux (sed -i).
  In dry-run mode, the command is printed via shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.

Example:
  shell::fzf_rename_key_conf         # Interactively select a key and rename it.
  shell::fzf_rename_key_conf -n      # Prints the renaming command without executing it.
"

USAGE_SHELL_PROTECTED_KEY="
shell::is_protected_key function
Checks if the specified configuration key is protected.

Usage:
  shell::is_protected_key [-h] <key>

Parameters:
  - -h   : Optional. Displays this help message.
  - <key>: The configuration key to check.

Description:
  This function iterates over the SHELL_PROTECTED_KEYS array to determine if the given key is marked as protected.
  If the key is found in the array, the function echoes "true" and returns 0.
  Otherwise, it echoes "false" and returns 1.
"

USAGE_SHELL_ADD_GROUP="
shell::add_group function
Groups selected configuration keys under a specified group name.

Usage:
  shell::add_group [-n] [-h]

Parameters:
  - -h   : Optional. Displays this help message.

Description:
  This function prompts you to enter a group name, then uses fzf (with multi-select) to let you choose
  one or more configuration keys (from SHELL_KEY_CONF_FILE). It then stores the group in SHELL_GROUP_CONF_FILE in the format:
      group_name=key1,key2,...,keyN
  If the group name already exists, the group entry is updated with the new selection.
  An optional dry-run flag (-n) can be used to print the command via shell::on_evict instead of executing it.

Example:
  shell::add_group         # Prompts for a group name and lets you select keys to group.
  shell::add_group -n      # Prints the command for creating/updating the group without executing it.
"

USAGE_SHELL_READ_GROUP="
shell::read_group function
Reads and displays the configurations for a given group by group name.

Usage:
  shell::read_group [-h] <group_name>

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

USAGE_SHELL_FZF_REMOVE_GROUP="
shell::fzf_remove_group function
Interactively selects a group name from the group configuration file using fzf,
then removes the corresponding group entry.

Usage:
  shell::fzf_remove_group [-n] [-h]

Parameters:
  - -n   : Optional dry-run flag. If provided, the removal command is printed using shell::on_evict instead of executed.
  - -h   : Optional. Displays this help message.

Description:
  The function extracts group names from SHELL_GROUP_CONF_FILE and uses fzf for interactive selection.
  Once a group is selected, it constructs a sed command (with appropriate in-place options for macOS or Linux)
  to remove the line that starts with \"group_name=\".
  If the file is not writable, sudo is prepended. In dry-run mode, the command is printed via shell::on_evict.

Example:
  shell::fzf_remove_group         # Interactively select a group and remove its entry.
  shell::fzf_remove_group -n      # Prints the removal command without executing it.
"

USAGE_SHELL_FZF_UPDATE_GROUP="
shell::fzf_update_group function
Interactively updates an existing group by letting you select new keys for that group.

Usage:
  shell::fzf_update_group [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the update command is printed using shell::on_evict instead of executed.
  - -h   : Optional. Displays this help message.

Description:
  The function reads SHELL_GROUP_CONF_FILE and uses fzf to let you select an existing group.
  It then presents all available keys from SHELL_KEY_CONF_FILE (via fzf with multi-select) for you to choose the new group membership.
  The selected keys are converted into a comma-separated list, and the group entry is updated in SHELL_GROUP_CONF_FILE
  (using sed with options appropriate for macOS or Linux). If the file is not writable, sudo is used.

Example:
  shell::fzf_update_group         # Interactively select a group, update its keys, and update the group entry.
  shell::fzf_update_group -n      # Prints the update command without executing it.
"

USAGE_SHELL_FZF_RENAME_GROUP="
shell::fzf_rename_group function
Renames an existing group in the group configuration file.

Usage:
  shell::fzf_rename_group [-n] [-h]

Parameters:
  - -n   : Optional dry-run flag. If provided, the renaming command is printed using shell::on_evict instead of executed.
  - -h   : Optional. Displays this help message.

Description:
  The function reads the group configuration file (SHELL_GROUP_CONF_FILE) where each line is in the format:
      group_name=key1,key2,...,keyN
  It uses fzf to let you select an existing group to rename.
  After selection, the function prompts for a new group name.
  It then constructs a sed command to replace the old group name with the new one in the configuration file.
  The sed command uses in-place editing options appropriate for macOS (sed -i '') or Linux (sed -i).
  In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.

Example:
  shell::fzf_rename_group         # Interactively select a group and rename it.
  shell::fzf_rename_group -n      # Prints the renaming command without executing it.
"

USAGE_SHELL_LIST_GROUP="
shell::list_groups function
Lists all group names defined in the group configuration file.

Usage:
  shell::list_groups [-h]

Parameters:
  - -h   : Optional. Displays this help message.

Description:
  This function reads the configuration file defined by SHELL_GROUP_CONF_FILE,
  where each line is in the format:
      group_name=key1,key2,...,keyN
  It extracts and displays the group names (the part before the '=')
  using the 'cut' command.
"

USAGE_SHELL_FZF_SELECT_GROUP="
shell::fzf_select_group function
Interactively selects a group name from the group configuration file using fzf,
then lists all keys belonging to the selected group and uses fzf to choose one key,
finally displaying the decoded value for the selected key.

Usage:
  shell::fzf_select_group [-h]

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

USAGE_SHELL_FZF_CLONE_GROUP="
shell::fzf_clone_group function
Clones an existing group by creating a new group with the same keys.

Usage:
  shell::fzf_clone_group [-n] [-h]

Parameters:
  - -n   : Optional dry-run flag. If provided, the cloning command is printed using shell::on_evict instead of executed.
  - -h   : Optional. Displays this help message.

Description:
  The function reads the group configuration file (SHELL_GROUP_CONF_FILE) where each line is in the format:
      group_name=key1,key2,...,keyN
  It uses fzf to interactively select an existing group.
  After selection, it prompts for a new group name.
  The new group entry is then constructed with the new group name and the same comma-separated keys
  as the selected group, and appended to SHELL_GROUP_CONF_FILE.
  In dry-run mode, the final command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.
"

USAGE_SHELL_SYNC_KEY_GROUP_CONF="
shell::sync_key_group_conf function
Synchronizes group configurations by ensuring that each group's keys exist in the key configuration file.
If a key listed in a group does not exist, it is removed from that group.
If a group ends up with no valid keys, that group entry is removed.

Usage:
  shell::sync_key_group_conf [-n] [-h]

Parameters:
  - -n   : Optional dry-run flag. If provided, the new group configuration is printed using shell::on_evict instead of being applied.
  - -h   : Optional. Displays this help message.

Description:
  The function reads each group entry from SHELL_GROUP_CONF_FILE (entries in the format: group_name=key1,key2,...,keyN).
  For each group, it splits the comma-separated list of keys and checks each key using shell::exist_key_conf.
  It builds a new list of valid keys. If the new list is non-empty, the group entry is updated;
  if it is empty, the group entry is omitted.
  In dry-run mode, the new group configuration is printed via shell::on_evict without modifying the file.
"

USAGE_SHELL_LOAD_INI_CONF="
shell::load_ini_conf function
Reads a .ini.conf file and loads key-value pairs as environment variables.
Lines starting with '#' or ';' are treated as comments and ignored.
Empty lines are also ignored.
Each valid line in 'key=value' format is exported as an environment variable.

Usage:
  shell::load_ini_conf [-h] <file_path>

Parameters:
    - -h            : Optional. Displays this help message.
    - <file_path>   : The path to the .ini.conf file to load.

Description:
  This function parses the specified configuration file. For each line that is
  not a comment or empty, it attempts to split the line at the first '=' sign.
  The part before the '=' is treated as the variable name (key), and the part
  after the '=' is treated as the variable value. Leading and trailing whitespace
  is trimmed from both the key and the value. The resulting key-value pair is
  then exported as an environment variable in the current shell. This makes the
  configuration settings available to subsequently executed commands and scripts.
  The function provides feedback on whether the file was found and loaded.

Example usage:
  shell::load_ini_conf \"CONF_DIR/my_app.ini.conf\" # Load configurations from my_app.ini.conf

Requirements:
  - Assumes the presence of helper function: shell::colored_echo.
"

USAGE_SHELL_FATAL="
shell::fatal function
Prints a fatal error message along with the function call stack, then exits the script.

Usage:
  shell::fatal [-h] [<message>]

Parameters:
    - -h            : Optional. Displays this help message.
    - <message>     : (Optional) A custom error message describing the fatal error.

Description:
  The function first verifies that it has received 0 to 1 argument using shell::verify_arg_count.
  It then constructs a stack trace from the FUNCNAME array, prints the error message with red formatting,
  and outputs the call stack in yellow before exiting with a non-zero status.

Example:
  shell::fatal \"Configuration file not found.\"
"

USAGE_SHELL_VERIFY_ARG_COUNT="
shell::verify_arg_count function
Verifies that the number of provided arguments falls within an expected range.

Usage:
  shell::verify_arg_count [-h] <actual_arg_count> <expected_arg_count_min> <expected_arg_count_max>

Parameters:
  - -h                      : Optional. Displays this help message.
  - <actual_arg_count>      : The number of arguments that were passed.
  - <expected_arg_count_min>: The minimum number of arguments expected.
  - <expected_arg_count_max>: The maximum number of arguments expected.

Description:
  The function first checks that exactly three arguments are provided.
  It then verifies that all arguments are integers.
  Finally, it compares the actual argument count to the expected range.
  If the count is outside the expected range, it prints an error message in red and returns 1.

Example:
  shell::verify_arg_count \"$#\" 0 1   # Verifies that the function was called with 0 or 1 argument.
"

USAGE_SHELL_ADD_ANGULAR_GITIGNORE="
shell::add_angular_gitignore function
This function downloads the .gitignore file specifically for Angular projects.

Usage:
  shell::add_angular_gitignore [-h]

Parameters:
  - -h                              : Optional. Displays this help message.
"

USAGE_SHELL_ADD_GITHUB_WORKFLOW_CI="
shell::add_github_workflow_ci function
This function downloads the continuous integration (CI) workflow configuration file
for the DevOps process from the specified GitHub repository.

Usage:
  shell::add_github_workflow_ci [-h]

Parameters:
  - -h                              : Optional. Displays this help message.
"

USAGE_SHELL_ADD_GITHUB_WORKFLOW_CI_NOTIFICATION="
shell::add_github_workflow_ci_notification function
This function downloads the GitHub Actions CI notification workflow configuration file
from the specified GitHub repository. This file is crucial for setting up automated
notifications related to CI events, ensuring that relevant stakeholders are informed
about the status of the CI processes.

Usage:
  shell::add_github_workflow_ci_notification [-h]

Parameters:
  - -h                              : Optional. Displays this help message.
"

USAGE_SHELL_SEND_TELEGRAM_HISTORICAL_GH_MESSAGE="
shell::send_telegram_historical_gh_message function
Sends a historical GitHub-related message via Telegram using stored configuration keys.

Usage:
  shell::send_telegram_historical_gh_message [-n] [-h] <message>

Parameters:
  - -n              : Optional dry-run flag. If provided, the command will be printed using shell::on_evict instead of executed.
  - -h              : Optional. Displays this help message.
  - <message>       : The message text to send.

Description:
  The function first checks if the dry-run flag is provided. It then verifies the existence of the
  configuration keys \"SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN\" and \"SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID\".
  If either key is missing, a warning is printed and the corresponding key is copied to the clipboard
  to prompt the user to add it using shell::add_conf. If both keys exist, it retrieves their values and
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
    - -n     : Optional. If provided, the command is printed using shell::on_evict instead of executed.
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
  - -n                              : Optional. If provided, the command is printed using shell::on_evict instead of executed.
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
  - -n                              : Optional. If provided, the command is printed using shell::on_evict instead of executed.
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
         If provided, the commands are printed using shell::on_evict instead of being executed.
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
shell::install_python function
Installs Python (python3) on macOS or Linux.

Usage:
  shell::install_python [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
  - -h : Optional. Displays this help message.

Description:
  Installs Python 3 using the appropriate package manager based on the OS:
  - On Linux: Uses apt-get, yum, or dnf (detected automatically), with a specific check for package installation state.
  - On macOS: Uses Homebrew, checking Homebrew's package list.
  Skips installation only if Python is confirmed installed via the package manager.

Example:
  shell::install_python       # Installs Python 3.
  shell::install_python -n    # Prints the installation command without executing it.
"

USAGE_SHELL_UNINSTALL_PYTHON="
shell::uninstall_python function
Removes Python (python3) and its core components from the system.

Usage:
  shell::uninstall_python [-n] [-h]

Parameters:
  - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
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
shell::uninstall_python_pip_deps function
Uninstalls all pip and pip3 packages with user confirmation and optional dry-run.

Usage:
  shell::uninstall_python_pip_deps [-n] [-h]

Parameters:
  - -n  : Optional flag to perform a dry-run (uses shell::on_evict to print commands without executing).
  - -h  : Optional. Displays this help message.

Description:
  This function uninstalls all packages installed via pip and pip3, including system packages,
  after user confirmation. It is designed to work on both Linux and macOS, with safety checks
  and enhanced logging using shell::run_cmd_eval.

Example usage:
  shell::uninstall_python_pip_deps       # Uninstalls all pip/pip3 packages after confirmation
  shell::uninstall_python_pip_deps -n    # Dry-run to preview commands
"

USAGE_SHELL_UNINSTALL_PYTHON_PIP_DEPS_LATEST="
shell::uninstall_python_pip_deps::latest function
Uninstalls all pip and pip3 packages with user confirmation and optional dry-run.

Usage:
  shell::uninstall_python_pip_deps::latest [-n] [-h]

Parameters:
  - -n  : Optional flag to perform a dry-run (uses shell::on_evict to print commands without executing).
  - -h  : Optional. Displays this help message.

Description:
  This function uninstalls all packages installed via pip and pip3, including system packages,
  after user confirmation. It is designed to work on both Linux and macOS, with safety checks.
  In non-dry-run mode, it executes the uninstallation commands asynchronously using shell::async,
  ensuring that the function returns once the background process completes.

Example usage:
  shell::uninstall_python_pip_deps::latest       # Uninstalls all pip/pip3 packages after confirmation
  shell::uninstall_python_pip_deps::latest -n    # Dry-run to preview commands
"

USAGE_SHELL_CREATE_PYTHON_ENV="
shell::create_python_env function
Creates a Python virtual environment for development, isolating it from system packages.

Usage:
  shell::create_python_env [-n] [-h] [-p <path>] [-v <version>]

Parameters:
  - -n          : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
  - -h          : Optional. Displays this help message.
  - -p <path>   : Optional. Specifies the path where the virtual environment will be created (defaults to ./venv).
  - -v <version>: Optional. Specifies the Python version (e.g., 3.10); defaults to system Python3.

Description:
  This function sets up a Python virtual environment to avoid package conflicts with the system OS:
  - Ensures Python3 and pip are installed using shell::install_python.
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
  - -n          : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
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
                    If provided, commands are printed using shell::on_evict
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
                    If provided, commands are printed using shell::on_evict
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
                    If provided, commands are printed using shell::on_evict
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
                    If provided, commands are printed using shell::on_evict
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
                    If provided, commands are printed using shell::on_evict instead of executed.
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
  - -n          : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
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
  - -n          : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
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

USAGE_SHELL_SHOW_BOOKMARK="
shell::show_bookmark function
Displays a formatted list of all bookmarks.

Usage:
  shell::show_bookmark [-h]

Parameters:
  - -h              : Optional. Displays this help message.

Description:
  The 'shell::show_bookmark' function lists all bookmarks in a formatted manner,
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
shell::colored_echo function
Prints text to the terminal with customizable colors using (tput) and ANSI escape sequences.

Usage:
  shell::colored_echo [-h] <message> [color_code]

Parameters:
  - -h              : Optional. Displays this help message.
  - <message>       : The text message to display.
  - [color_code]    : (Optional) A number from 0 to 255 representing the text color.
      - 0-15: Standard colors (Black, Red, Green, etc.)
      - 16-231: Extended 6x6x6 color cube
      - 232-255: Grayscale shades

Description:
  The (shell::colored_echo) function prints a message in bold and a specific color, if a valid color code is provided.
  It uses ANSI escape sequences for 256-color support. If no color code is specified, it defaults to blue (code 4).

Options:
  None

Example usage:
  shell::colored_echo \"Hello, World!\"          # Prints in default blue (code 4).
  shell::colored_echo \"Error occurred\" 196     # Prints in bright red.
  shell::colored_echo \"Task completed\" 46      # Prints in vibrant green.
  shell::colored_echo \"Shades of gray\" 245     # Prints in a mid-gray shade.
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

USAGE_SHELL_REMOVAL_PACKAGE="
shell::removal_package function
Cross-platform package uninstallation function for macOS and Linux.

Usage:
  shell::removal_package [-h] <package_name>

Parameters:
    - -h                : Optional. Displays this help message.
    - <package_name>    : The name of the package to uninstall

Example usage:
  shell::removal_package git
"

USAGE_SHELL_LIST_INSTALLED_PACKAGES="
shell::list_installed_packages function
Lists all packages currently installed on Linux or macOS.

Usage:
  shell::list_installed_packages [-h]

Parameters:
    - -h                : Optional. Displays this help message.

Description:
  On Linux:
    - If apt-get is available, it uses dpkg to list installed packages.
    - If yum or dnf is available, it uses rpm to list installed packages.
  On macOS:
    - If Homebrew is available, it lists installed Homebrew packages.
"

USAGE_SHELL_LIST_PATH_INSTALLED_PACKAGES="
shell::list_path_installed_packages function
Lists all packages installed via directory-based package installation on Linux or macOS,
along with their installation paths.

Usage:
  shell::list_path_installed_packages [-h] [base_install_path]

Parameters:
    - -h                 : Optional. Displays this help message.
    - [base_install_path]: Optional. The base directory where packages are installed.
        Defaults to:
          - /usr/local on macOS
          - /opt on Linux

Example usage:
  shell::list_path_installed_packages
  shell::list_path_installed_packages /custom/install/path
"

USAGE_SHELL_LIST_PATH_INSTALLED_PACKAGES_DETAILS="
shell::list_path_installed_packages_details function
Lists detailed information (including full path, directory size, and modification date)
for all packages installed via directory-based methods on Linux or macOS.

Usage:
  shell::list_path_installed_packages_details [-h] [base_install_path]

Parameters:
    - -h                 : Optional. Displays this help message.
    - [base_install_path]: Optional. The base directory where packages are installed.
        Defaults to:
          - /usr/local on macOS
          - /opt on Linux

Example usage:
  shell::list_path_installed_packages_details
  shell::list_path_installed_packages_details /custom/install/path
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
doesn't exist.

Usage:
  shell::create_directory_if_not_exists [-h] <directory_path>

Parameters:
    - -h                : Optional. Displays this help message.
    - <directory_path>  : The path of the directory to be created.

Description:
  This function checks if the specified directory exists. If it does not,
  it creates the directory (including any necessary parent directories) using
  sudo to ensure proper privileges.

Example:
  shell::create_directory_if_not_exists /path/to/nested/directory
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

USAGE_SHELL_SET_PERMS_777="
shell::setPerms::777 function
Sets full permissions (read, write, and execute) for the specified file or directory.

Usage:
  shell::setPerms::777 [-n] [-h] <file/dir>

Parameters:
  - -n (optional)   : Dry-run mode. Instead of executing the command, prints it using shell::on_evict.
  - -h              : Optional. Displays this help message.
  - <file/dir>      : The path to the file or directory to modify.

Description:
  This function checks the current permission of the target. If it is already set to 777,
  it logs a message and exits without making any changes.
  Otherwise, it builds and executes (or prints, in dry-run mode) the chmod command asynchronously
  to grant full permissions recursively.

Example:
  shell::setPerms::777 ./my_script.sh
  shell::setPerms::777 -n ./my_script.sh  # Dry-run: prints the command without executing.
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
shell::on_evict function
Hook to print a command without executing it.

Usage:
  shell::on_evict [-h] <command>

Parameters:
    - -h            : Optional. Displays this help message.
    - <command>     : The command to be printed.

Description:
  The 'shell::on_evict' function prints a command without executing it.
  It is designed as a hook for logging or displaying commands without actual execution.

Example usage:
  shell::on_evict ls -l
"

USAGE_SHELL_PORT_CHECK="
shell::port_check function
Checks if a specific TCP port is in use (listening).

Usage:
  shell::port_check [-h] <port> [-n]

Parameters:
    - -h     : Optional. Displays this help message.
    - <port> : The TCP port number to check.
    - -n     : Optional flag to enable dry-run mode (prints the command without executing it).

Description:
  This function uses lsof to determine if any process is actively listening on the specified TCP port.
  It filters the output for lines containing \"LISTEN\", which indicates that the port is in use.
  When the dry-run flag (-n) is provided, the command is printed using shell::on_evict instead of being executed.

Example:
  shell::port_check 8080        # Executes the command.
  shell::port_check 8080 -n     # Prints the command (dry-run mode) without executing it.
"

USAGE_SHELL_PORT_KILL="
shell::port_kill function
Terminates all processes listening on the specified TCP port(s).

Usage:
  shell::port_kill [-n] [-h] <port> [<port> ...]

Parameters:
    - -n        : Optional flag to enable dry-run mode (print commands without execution).
    - -h        : Optional. Displays this help message.
    - <port>    : One or more TCP port numbers.

Description:
  This function checks each specified port to determine if any processes are listening on it,
  using lsof. If any are found, it forcefully terminates them by sending SIGKILL (-9).
  In dry-run mode (enabled by the -n flag), the kill command is printed using shell::on_evict instead of executed.

Example:
  shell::port_kill 8080              # Kills processes on port 8080.
  shell::port_kill -n 8080 3000       # Prints the kill commands for ports 8080 and 3000 without executing.
"

USAGE_SHELL_COPY_FILES="
shell::copy_files function
Copies a source file to one or more destination filenames in the current working directory.

Usage:
  shell::copy_files [-n] [-h] <source_filename> <new_filename1> [<new_filename2> ...]

Parameters:
    - -n                : Optional dry-run flag. If provided, the command will be printed using shell::on_evict instead of executed.
    - -h                : Optional. Displays this help message.
    - <source_filename> : The file to copy.
    - <new_filenameX>   : One or more new filenames (within the current working directory) where the source file will be copied.

Description:
  The function first checks for a dry-run flag (-n). It then verifies that at least two arguments remain.
  For each destination filename, it checks if the file already exists in the current working directory.
  If not, it builds the command to copy the source file (using sudo) to the destination.
  In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.

Example:
  shell::copy_files myfile.txt newfile.txt            # Copies myfile.txt to newfile.txt.
  shell::copy_files -n myfile.txt newfile1.txt newfile2.txt  # Prints the copy commands without executing them.
"
USAGE_SHELL_PORT_KILL="
shell::port_kill function
Terminates all processes listening on the specified TCP port(s).

Usage:
  shell::port_kill [-n] [-h] <port> [<port> ...]

Parameters:
  - -n    : Optional flag to enable dry-run mode (print commands without execution).
  - -h    : Optional. Displays this help message.
  - <port>: One or more TCP port numbers.

Description:
  This function checks each specified port to determine if any processes are listening on it,
  using lsof. If any are found, it forcefully terminates them by sending SIGKILL (-9).
  In dry-run mode (enabled by the -n flag), the kill command is printed using shell::on_evict instead of executed.

Example:
  shell::port_kill 8080              # Kills processes on port 8080.
  shell::port_kill -n 8080 3000      # Prints the kill commands for ports 8080 and 3000 without executing.
"

USAGE_SHELL_COPY_FILES="
shell::copy_files function
Copies a source file to one or more destination filenames in the current working directory.

Usage:
  shell::copy_files [-n] [-h] <source_filename> <new_filename1> [<new_filename2> ...]

Parameters:
  - -n                : Optional dry-run flag. If provided, the command will be printed using shell::on_evict instead of executed.
  - -h                : Optional. Displays this help message.
  - <source_filename> : The file to copy.
  - <new_filenameX>   : One or more new filenames (within the current working directory) where the source file will be copied.

Description:
  The function first checks for a dry-run flag (-n). It then verifies that at least two arguments remain.
  For each destination filename, it checks if the file already exists in the current working directory.
  If not, it builds the command to copy the source file (using sudo) to the destination.
  In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.

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
  - -n                  : Optional dry-run flag. If provided, the command will be printed using shell::on_evict instead of executed.
  - -h                  : Optional. Displays this help message.
  - <destination_folder>: The target directory where the files will be moved.
  - <fileX>             : One or more source files to be moved.

Description:
  The function first checks for an optional dry-run flag (-n). It then verifies that the destination folder exists.
  For each source file provided:
    - It checks whether the source file exists.
    - It verifies that the destination file (using the basename of the source) does not already exist in the destination folder.
    - It builds the command to move the file (using sudo mv).
  In dry-run mode, the command is printed using shell::on_evict; otherwise, the command is executed using shell::run_cmd.
  If an error occurs for a particular file (e.g., missing source or destination file conflict), the error is logged and the function continues with the next file.

Example:
  shell::move_files /path/to/dest file1.txt file2.txt        # Moves file1.txt and file2.txt to /path/to/dest.
  shell::move_files -n /path/to/dest file1.txt file2.txt     # Prints the move commands without executing them.
"

USAGE_SHELL_REMOVE_DATASET="
shell::remove_dataset function
Removes a file or directory using sudo rm -rf.

Usage:
  shell::remove_dataset [-n] [-h] <filename/dir>

Parameters:
  - -n            : Optional dry-run flag. If provided, the command will be printed using shell::on_evict instead of executed.
  - -h            : Optional. Displays this help message.
  - <filename/dir>: The file or directory to remove.

Description:
  The function first checks for an optional dry-run flag (-n). It then verifies that a target argument is provided.
  It builds the command to remove the specified target using \"sudo rm -rf\".
  In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd.

Example:
  shell::remove_dataset my-dir         # Removes the directory 'my-dir'.
  shell::remove_dataset -n myfile.txt  # Prints the removal command without executing it.
"

USAGE_SHELL_EDITOR="
shell::editor function
Open a selected file from a specified folder using a chosen text editor.

Usage:
  shell::editor [-n] [-h] <folder>

Parameters:
  - -n       : Optional dry-run flag. If provided, the command will be printed using shell::on_evict instead of executed.
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
  - -n                        : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
  - -h                        : Optional. Displays this help message.
  - <filename_with_extension> : The target filename (with path) where the dataset will be saved.
  - <download_link>           : The URL from which the dataset will be downloaded.

Description:
  This function downloads a file from a given URL and saves it under the specified filename.
  It extracts the directory from the filename, ensures the directory exists, and changes to that directory
  before attempting the download. If the file already exists, it prompts the user for confirmation before
  overwriting it. In dry-run mode, the function uses shell::on_evict to display the commands without executing them.

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
  - -n        : Optional dry-run flag. If provided, the extraction command is printed using shell::on_evict instead of executed.
  - -h        : Optional. Displays this help message.
  - <filename>: The compressed file to extract.

Description:
  The function first checks for an optional dry-run flag (-n) and then verifies that exactly one argument (the filename) is provided.
  It checks if the given file exists and, if so, determines the correct extraction command based on the file extension.
  In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.

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
  - -n        : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
  - -h        : Optional. Displays this help message.

Description:
  This function retrieves the operating system type using shell::get_os_type. For macOS, it uses 'top' to sort processes by resident size (RSIZE)
  and filters the output to display processes consuming at least 100 MB. For Linux, it uses 'ps' to list processes sorted by memory usage.
  In dry-run mode, the constructed command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.

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
  - -n   : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
  - -h   : Optional. Displays this help message.
  - <url>: The URL to open in the default web browser.

Description:
  This function determines the current operating system using shell::get_os_type. On macOS, it uses the 'open' command;
  on Linux, it uses 'xdg-open' (if available). If the required command is missing on Linux, an error is displayed.
  In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.

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
  - -n        : Optional dry-run flag. If provided, the spinner command is printed using shell::on_evict instead of executed.
  - -h        : Optional. Displays this help message.
  - [duration]: Optional. The duration in seconds for which the spinner should be displayed. Default is 3 seconds.

Description:
  The function calculates an end time based on the provided duration and then iterates,
  printing a sequence of spinner characters to create a visual loading effect.
  In dry-run mode, it uses shell::on_evict to display a message indicating what would be executed,
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
  - -n                      : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
  - -h                      : Optional. Displays this help message.
  - <command> [arguments...]: The command (or function) with its arguments to be executed asynchronously.

Description:
  The shell::async function builds the command from the provided arguments and runs it in the background.
  If the optional dry-run flag (-n) is provided, the command is printed using shell::on_evict instead of executing it.
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
  - -n            : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
  - -h            : Optional. Displays this help message.
  - <folder_path> : The folder (directory) from which to select files for zipping.

Description:
  This function uses the 'find' command to list all files in the specified folder,
  and then launches 'fzf' in multi-select mode to allow interactive file selection.
  If one or more files are selected, a zip command is constructed to compress those files.
  In dry-run mode (-n), the command is printed (via shell::on_evict) without execution;
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
  - -n         : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
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
  - -n           : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
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
  - -n : Optional dry-run flag. If provided, the installation command is printed using shell::on_evict instead of executed.
  - -h : Optional. Displays this help message.

Description:
  The function checks whether the Oh My Zsh directory ($HOME/.oh-my-zsh) exists.
  If it exists, it prints a message indicating that Oh My Zsh is already installed.
  Otherwise, it proceeds to install Oh My Zsh by executing the installation script fetched via curl.
  In dry-run mode, the command is displayed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.

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
  - -n : Optional dry-run flag. If provided, the uninstallation commands are printed using shell::on_evict instead of executed.
  - -h : Optional. Displays this help message.

Description:
  This function checks whether the Oh My Zsh directory ($HOME/.oh-my-zsh) exists.
  If it does, the function proceeds to remove it using 'rm -rf'. Additionally, if a backup of the original .zshrc
  (stored as $HOME/.zshrc.pre-oh-my-zsh) exists, it restores that backup by moving it back to $HOME/.zshrc.
  In dry-run mode, the commands are displayed using shell::on_evict; otherwise, they are executed using shell::run_cmd_eval.

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
  - -n          : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
  - -h          : Optional. Displays this help message.
  - <token>     : The Telegram Bot API token.
  - <chat_id>   : The chat identifier where the message should be sent.
  - <message>   : The message text to send.

Description:
  The function first checks for an optional dry-run flag. It then verifies that at least three arguments are provided.
  If the bot token or chat ID is missing, it prints an error message. Otherwise, it constructs a curl command to send
  the message via Telegram's API. In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.

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
  - -n           : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
  - -h          : Optional. Displays this help message.
  - <token>      : The Telegram Bot API token.
  - <chat_id>    : The chat identifier to which the attachments are sent.
  - <description>: A text description that is appended to each attachment's caption along with a timestamp.
  - [filename_X] : One or more filenames of the attachments to send.

Description:
  The function first checks for an optional dry-run flag (-n) and verifies that the required parameters
  are provided. For each provided file, if the file exists, it builds a curl command to send the file
  asynchronously via Telegram's API. In dry-run mode, the command is printed using shell::on_evict.

Example:
  shell::send_telegram_attachment 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 \"Report\" file1.pdf file2.pdf
  shell::send_telegram_attachment -n 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 \"Report\" file1.pdf
"

USAGE_SHELL_GET_PROFILE_DIR="
shell::get@_profile_dir function
Returns the path to the profile directory for a given profile name.

Usage:
  shell::get@_profile_dir [-h] <profile_name>

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
  - -n             : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
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
  - -n             : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
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
  - -n             : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
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
  - -n             : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
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
  - -n             : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
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

USAGE_SHELL_ADD_CONF_PROFILE="
shell::add_conf_profile function
Adds a configuration entry (key=value) to the profile.conf file of a specified profile.
The value is encoded using Base64 before being saved.

Usage:
  shell::add_conf_profile [-n] [-h] <profile_name> <key> <value>

Parameters:
  - -n             : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
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
  shell::add_conf_profile my_profile my_setting \"some secret value\"         # Encodes the value and adds the entry to my_profile/profile.conf
  shell::add_conf_profile -n my_profile my_setting \"some secret value\"      # Prints the command without executing it
"

USAGE_SHELL_GET_CONF_PROFILE="
shell::get_conf_profile function
Retrieves a configuration profile value by prompting the user to select a config key from the profile's configuration file.

Usage:
  shell::get_conf_profile [-n] [-h] <profile_name>

Parameters:
  - -n (optional)   : Dry-run mode. Instead of executing commands, prints them using shell::on_evict.
  - -h              : Optional. Displays this help message.
  - <profile_name>  : The name of the configuration profile.

Description:
  This function locates the profile directory and its configuration file, verifies that the profile exists,
  and then ensures that the interactive fuzzy finder (fzf) is installed. It uses fzf to let the user select a configuration key,
  decodes its base64-encoded value (using the appropriate flag for macOS or Linux), displays the selected key,
  and finally copies the decoded value to the clipboard asynchronously.

Example:
  shell::get_conf_profile my_profile          # Retrieves and processes the 'my_profile' profile.
  shell::get_conf_profile -n my_profile       # Dry-run mode: prints the commands without executing them.
"

USAGE_SHELL_GET_VALUE_CONF_PROFILE="
shell::get_value_conf_profile function
Retrieves a configuration value for a given profile and key by decoding its base64-encoded value.

Usage:
  shell::get_value_conf_profile [-n] [-h] <profile_name> <key>

Parameters:
  - -n (optional)   : Dry-run mode. Instead of executing commands, prints them using shell::on_evict.
  - -h              : Optional. Displays this help message.
  - <profile_name>  : The name of the configuration profile.
  - <key>           : The configuration key whose value will be retrieved.

Description:
  This function ensures that the workspace exists and locates the profile directory
  and configuration file. It then extracts the configuration line matching the provided key,
  decodes the associated base64-encoded value (using the appropriate flag for macOS or Linux),
  asynchronously copies the decoded value to the clipboard, and finally outputs the decoded value.

Example:
  shell::get_value_conf_profile my_profile API_KEY
  shell::get_value_conf_profile -n my_profile API_KEY   # Dry-run: prints commands without executing them.
"

USAGE_SHELL_REMOVE_CONF_PROFILE="
shell::remove_conf_profile function
Removes a configuration key from a given profile's configuration file.

Usage:
  shell::remove_conf_profile [-n] [-h] <profile_name>

Parameters:
  - -n (optional)   : Dry-run mode. Instead of executing commands, prints them using shell::on_evict.
  - -h              : Optional. Displays this help message.
  - <profile_name>  : The name of the configuration profile.

Description:
  This function locates the profile directory and its configuration file, verifies their existence,
  and then uses fzf to let the user select a configuration key to remove.
  It builds an OS-specific sed command to delete the line containing the selected key.
  In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed asynchronously
  using shell::async with shell::run_cmd_eval.

Example:
  shell::remove_conf_profile my_profile
  shell::remove_conf_profile -n my_profile   # Dry-run: prints the removal command without executing.
"

USAGE_SHELL_UPDATE_CONF_PROFILE="
shell::update_conf_profile function
Updates a specified configuration key in a given profile by replacing its value.

Usage:
  shell::update_conf_profile [-n] [-h] <profile_name>

Parameters:
  - -n              : Optional dry-run flag. If provided, the update command is printed using shell::on_evict without executing.
  - -h              : Optional. Displays this help message.
  - <profile_name>  : The name of the profile to update.

Description:
  The function retrieves the profile configuration file, prompts the user to select a key (using fzf),
  asks for the new value, encodes it in base64, and constructs a sed command to update the key.
  The sed command is executed asynchronously via the shell::async function (unless in dry-run mode).

Example:
  shell::update_conf_profile my_profile
  shell::update_conf_profile -n my_profile   # dry-run mode
"

USAGE_SHELL_EXIST_KEY_CONF_PROFILE="
shell::exist_key_conf_profile function
Checks whether a specified key exists in the configuration file of a given profile.

Usage:
  shell::exist_key_conf_profile [-h] <profile_name> <key>

Parameters:
  - -h            : Optional. Displays this help message.
  - <profile_name>: The name of the profile.
  - <key>         : The configuration key to search for.

Description:
  The function constructs the path to the profile's configuration file and verifies that the profile directory exists.
  It then checks if the configuration file exists. If both exist, it searches for the specified key using grep.
  The function outputs "true" if the key is found and "false" otherwise.

Example:
  shell::exist_key_conf_profile my_profile my_key
"

USAGE_SHELL_RENAME_KEY_CONF_PROFILE="
shell::rename_key_conf_profile function
Renames an existing configuration key in a given profile.

Usage:
  shell::rename_key_conf_profile [-n] [-h] <profile_name>

Parameters:
  - -n            : Optional dry-run flag. If provided, prints the sed command using shell::on_evict without executing.
  - -h            : Optional. Displays this help message.
  - <profile_name>: The name of the profile whose key should be renamed.

Description:
  The function checks that the profile directory and configuration file exist.
  It then uses fzf to allow the user to select the existing key to rename.
  After prompting for a new key name and verifying that it does not already exist,
  the function constructs an OS-specific sed command to replace the old key with the new one.
  In dry-run mode, the command is printed via shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.

Example:
  shell::rename_key_conf_profile my_profile
  shell::rename_key_conf_profile -n my_profile   # dry-run mode
"

USAGE_SHELL_CLONE_CONF_PROFILE="
shell::clone_conf_profile function
Clones a configuration profile by copying its profile.conf from a source profile to a destination profile.

Usage:
  shell::clone_conf_profile [-n] [-h] <source_profile> <destination_profile>

Parameters:
  - -n                    : (Optional) Dry-run flag. If provided, the command is printed but not executed.
  - -h                    : Optional. Displays this help message.
  - <source_profile>      : The name of the source profile.
  - <destination_profile> : The name of the destination profile.

Description:
  This function retrieves the source and destination profile directories using shell::get@_profile_dir,
  verifies that the source profile exists and has a profile.conf file, and ensures that the destination
  profile does not already exist. If validations pass, it clones the configuration by creating the destination
  directory and copying the profile.conf file from the source to the destination. When the dry-run flag (-n)
  is provided, it prints the command without executing it.

Example:
  shell::clone_conf_profile my_profile backup_profile   # Clones profile.conf from 'my_profile' to 'backup_profile'
"

USAGE_SHELL_LIST_CONF_PROFILE="
shell::list_conf_profile function
Lists all available configuration profiles in the workspace.

Usage:
  shell::list_conf_profile [-h]

Parameters:
  - -h      : Optional. Displays this help message.

Description:
  This function checks that the workspace directory (SHELL_CONF_WORKING/workspace) exists.
  It then finds all subdirectories (each representing a profile) and prints their names.
  If no profiles are found, an appropriate message is displayed.

Example:
  shell::list_conf_profile       # Displays the names of all profiles in the workspace.
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

USAGE_SHELL_INI_VALIDATE_SECTION_NAME="
shell::ini_validate_section_name function
Validates an INI section name based on defined strictness levels.
It checks for empty names and disallowed characters or spaces according to
SHELL_INI_STRICT and SHELL_INI_ALLOW_SPACES_IN_NAMES variables.

Usage:
  shell::ini_validate_section_name [-h] <section_name>

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
  Error messages are displayed using the shell::colored_echo function.

Example usage:
  # Assuming SHELL_INI_STRICT=1 and SHELL_INI_ALLOW_SPACES_IN_NAMES=0
  shell::ini_validate_section_name \"MySection\"   # Valid
  shell::ini_validate_section_name \"My Section\"  # Invalid (contains space)
  shell::ini_validate_section_name \"My[Section]\" # Invalid (contains illegal character)
  shell::ini_validate_section_name \"\"            # Invalid (empty)
"

USAGE_SHELL_INI_VALIDATE_KEY_NAME="
shell::ini_validate_key_name function
Validates an INI key name based on defined strictness levels.
It checks for empty names and disallowed characters or spaces according to
SHELL_INI_STRICT and SHELL_INI_ALLOW_SPACES_IN_NAMES variables.

Usage:
  shell::ini_validate_key_name [-h] <key_name>

Parameters:
  - -h         : Optional. Displays this help message.
  - <key_name> : The name of the INI key to validate.
"

USAGE_SHELL_INI_TRIM="
shell::ini_trim function
Trims leading and trailing whitespace from a given string.

Usage:
  shell::ini_trim [-h] <string>

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
