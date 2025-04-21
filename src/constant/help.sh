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
