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
