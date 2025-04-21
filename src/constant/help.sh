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
