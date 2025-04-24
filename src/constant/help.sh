#!/bin/bash
# help.sh

USAGE_SHELL_GEN_SSH_KEY="
Usage:
  shell::gen_ssh_key [-n] [-h] [email] [key_filename]

Parameters:
  - -n           : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
  - -h           : Optional. Displays this help message.
  - [email]      : Optional. The email address to be included in the comment field of the SSH key.
                   Defaults to an empty string if not provided.
  - [key_filename]: Optional. The name of the key file to generate within \$HOME/.ssh.
                   Defaults to 'id_rsa' if not provided.

Description:
  This function creates the \$HOME/.ssh directory if it doesn't exist and then uses the
  ssh-keygen command to generate an RSA key pair. The function allows specifying a comment
  (typically an email) and a custom filename for the key.
  It uses shell::create_directory_if_not_exists to ensure the target directory exists
  and shell::run_cmd to execute the ssh-keygen command.

Example usage:
  shell::gen_ssh_key                                  # Generates id_rsa key in ~/.ssh with no comment.
  shell::gen_ssh_key \"user@example.com\"               # Generates id_rsa key in ~/.ssh with specified email, saving as ~/.ssh/id_rsa.
  shell::gen_ssh_key \"\" \"my_key\"                      # Generates key with no comment, saving as ~/.ssh/my_key.
  shell::gen_ssh_key \"user@example.com\" \"my_key\"      # Generates key with specified email, saving as ~/.ssh/my_key.
  shell::gen_ssh_key -n \"user@example.com\" \"my_key\"   # Dry-run: prints the command without executing.
  shell::gen_ssh_key -h                               # Displays this help message.

Notes:
  - The function uses a 4096-bit RSA key type by default.
  - ssh-keygen will prompt for a passphrase unless -N '' is used (not included by default
    to encourage passphrase usage).
  - Relies on the 'ssh-keygen' command being available in the system's PATH.
  - Uses shell::create_directory_if_not_exists and shell::run_cmd helper functions.
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
  processes are terminated using the $(kill) command.

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
  shell::load_ini_conf \"$CONF_DIR/my_app.ini.conf\" # Load configurations from my_app.ini.conf

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
  changes into that directory, initializes the Go module using $(go mod init),
  and tidies the dependencies using $(go mod tidy).
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
Prints text to the terminal with customizable colors using $(tput) and ANSI escape sequences.

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
  The $(shell::colored_echo) function prints a message in bold and a specific color, if a valid color code is provided.
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
  creating it with admin privileges using $(sudo mkdir -p) if necessary. Finally, it creates the file
  using $(sudo touch) if it does not already exist. Optional permission settings for the directory
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
