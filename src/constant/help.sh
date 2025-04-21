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
