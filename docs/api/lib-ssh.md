# lib/ssh.sh

SSH key and tunnel management.

## Overview

Displays information about active SSH tunnel forwarding processes in a line-by-line format.

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

Notes:

- Requires the 'ps' command to be available
- Works on both macOS and Linux systems
- Uses different parsing approaches based on the detected operating system
- Leverages shell::exec::shell for command execution and shell::logger::command_clip for dry-run mode

## Index

- [lib/ssh.sh](#libsshsh)
  - [Overview](#overview)
  - [Index](#index)
    - [shell::ssh::tunnel::list](#shellsshtunnellist)
      - [Example](#example)
      - [Options](#options)
      - [Exit codes](#exit-codes)
    - [shell::ssh::key::cwd::fzf](#shellsshkeycwdfzf)
      - [Example](#example-1)
      - [Options](#options-1)
      - [Exit codes](#exit-codes-1)
    - [shell::ssh::key::copy::fzf](#shellsshkeycopyfzf)
      - [Example](#example-2)
      - [Options](#options-2)
      - [Exit codes](#exit-codes-2)
    - [shell::ssh::tunnel::kill::fzf](#shellsshtunnelkillfzf)
      - [Example](#example-3)
      - [Options](#options-3)
      - [Exit codes](#exit-codes-3)
    - [shell::ssh::tunnel::kill](#shellsshtunnelkill)
      - [Example](#example-4)
      - [Options](#options-4)
      - [Exit codes](#exit-codes-4)
    - [shell::ssh::key::generate](#shellsshkeygenerate)
      - [Example](#example-5)
      - [Options](#options-5)
      - [Arguments](#arguments)
      - [Exit codes](#exit-codes-5)
    - [shell::ssh::key::view::fzf](#shellsshkeyviewfzf)
      - [Example](#example-6)
      - [Options](#options-6)
      - [Exit codes](#exit-codes-6)
    - [shell::ssh::key::remove::fzf](#shellsshkeyremovefzf)
      - [Example](#example-7)
      - [Options](#options-7)
      - [Exit codes](#exit-codes-7)
    - [shell::ssh::tunnel::open](#shellsshtunnelopen)
      - [Example](#example-8)
      - [Options](#options-8)
      - [Arguments](#arguments-1)
      - [Exit codes](#exit-codes-8)
    - [shell::ssh::tunnel::open::builder](#shellsshtunnelopenbuilder)
      - [Example](#example-9)
      - [Options](#options-9)
      - [Exit codes](#exit-codes-9)
    - [shell::ssh::tunnel::tune](#shellsshtunneltune)
      - [Example](#example-10)
      - [Options](#options-10)
      - [Arguments](#arguments-2)
      - [Exit codes](#exit-codes-10)
    - [shell::ssh::tunnel::tune::builder](#shellsshtunneltunebuilder)
      - [Example](#example-11)
      - [Options](#options-11)
      - [Exit codes](#exit-codes-11)
    - [shell::ssh::key::rename](#shellsshkeyrename)
      - [Example](#example-12)
      - [Options](#options-12)
      - [Arguments](#arguments-3)
      - [Exit codes](#exit-codes-12)
    - [shell::ssh::key::rename::fzf](#shellsshkeyrenamefzf)
      - [Example](#example-13)
      - [Options](#options-13)
      - [Exit codes](#exit-codes-13)

### shell::ssh::tunnel::list

Displays information about active SSH tunnel forwarding processes in a line-by-line format.

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

Notes:

- Requires the 'ps' command to be available
- Works on both macOS and Linux systems
- Uses different parsing approaches based on the detected operating system
- Leverages shell::exec::shell for command execution and shell::logger::command_clip for dry-run mode

#### Example

```bash
shell::ssh::tunnel::list           # Display active SSH tunnels
shell::ssh::tunnel::list -n        # Show commands that would be executed (dry-run mode)
```

#### Options

- **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ssh::key::cwd::fzf

Interactively selects an SSH key file (private or public) from $HOME/.ssh using fzf,
displays the absolute path of the selected file, and copies the path to the clipboard.

This function lists files within the user's SSH directory ($HOME/.ssh).
It filters out common non-key files and then uses fzf to provide an interactive selection interface.
Once a file is selected, its absolute path is determined, displayed to the user,
and automatically copied to the system clipboard using the shell::clipboard::copy function.

#### Example

```bash
shell::ssh::key::cwd::fzf # Launch fzf to select an SSH key and copy its path.
```

#### Options

- **-h**

  Optional. Displays this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ssh::key::copy::fzf

Uses fzf to select an SSH key file and copies its contents to the clipboard using shell::clipboard::copy.

This function searches for SSH key files in ~/.ssh, filters out public keys and config files,
and presents them via fzf for selection. Once selected, the contents of the file
are copied to the clipboard using shell::clipboard::copy.

#### Example

```bash
shell::ssh::key::copy::fzf
```

#### Options

- **-h**

  Optional help flag. Displays this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ssh::tunnel::kill::fzf

Interactively selects one or more SSH tunnel processes using fzf and kills them.

This function identifies potential SSH tunnel processes by searching for 'ssh'
commands with port forwarding flags (-L, -R, or -D). It presents a list of
these processes, including their PIDs and command details, in an fzf interface
for interactive selection. The user can select one or multiple processes.
After selection, the user is prompted for confirmation before the selected
processes are terminated using the `kill` command.

#### Example

```bash
shell::ssh::tunnel::kill::fzf # Launch fzf to select and kill SSH tunnels.
```

#### Options

- **-h**

  Optional. Displays this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ssh::tunnel::kill

Kills all active SSH tunnel forwarding processes.

This function identifies all SSH processes that are using port forwarding options
(-L, -R, or -D) [cite: 12] and attempts to terminate them using the 'kill' command.
It works cross-platform on both macOS and Linux systems.
Confirmation is requested before killing processes unless the dry-run flag is used.

Notes:

- Requires the 'ps' and 'kill' commands to be available.
- Works on both macOS and Linux systems.
- Uses different parsing approaches based on the detected operating system.
- Leverages shell::exec::command for command execution and shell::logger::command_clip for dry-run mode.

#### Example

```bash
shell::ssh::tunnel::kill       # Kills active SSH tunnels after confirmation.
shell::ssh::tunnel::kill -n    # Shows kill commands that would be executed (dry-run mode).
```

#### Options

- **-n**

  Optional dry-run flag. If provided, kill commands are printed using shell::logger::command_clip instead of executed.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ssh::key::generate

Generates an SSH key pair (private and public) and saves them to the SSH directory.

This function creates the SSH directory (defaults to $HOME/.ssh)
if it doesn't exist and generates an SSH key pair using ssh-keygen. It supports specifying the key type,
passphrase, email comment, and filename. The function ensures the ssh-keygen command is available,
checks for existing keys, and sets appropriate permissions on generated files.

Notes:

- Uses 4096-bit keys for rsa; ed25519 uses its default key size.
- Sets key file permissions to 600 (private) and 644 (public) for security.
- Relies on shell::fs::mkdir, shell::exec::shell, and shell::command::exists.
- Validates the presence of ssh-keygen in the system's PATH.

#### Example

```bash
shell::ssh::key::generate                                  # Generates rsa key in ~/.ssh/id_rsa with no comment or passphrase.
shell::ssh::key::generate "user@example.com"              # Generates rsa key with email, saved as ~/.ssh/id_rsa.
shell::ssh::key::generate -t ed25519 "user@example.com"   # Generates ed25519 key with email.
shell::ssh::key::generate "" "my_key"                     # Generates rsa key with no comment, saved as ~/.ssh/my_key.
shell::ssh::key::generate -n "user@example.com" "my_key"  # Dry-run: prints the command without executing.
shell::ssh::key::generate -h                              # Displays this help message.
```

#### Options

- **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed. - -t key_type : Optional. Specifies the key type (e.g., rsa, ed25519). Defaults to rsa. - -p passphrase : Optional. Specifies the passphrase for the key. Defaults to empty (no passphrase).

- **-h**

  Optional. Displays this help message.

#### Arguments

- **...** (string): key_filename: Optional. The name of the key file to generate within the SSH directory. Defaults to 'id_rsa' if not provided.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ssh::key::view::fzf

Interactively selects an SSH key file from $HOME/.ssh using fzf,
and previews its contents in real-time in a wrapped preview window.

This function lists files within the user's SSH directory ($HOME/.ssh),
excluding common non-key files. It uses fzf to provide an interactive
selection interface with a preview window that shows the contents of
each file in real-time. The preview is wrapped for readability.

#### Example

```bash
shell::ssh::key::view::fzf       # Launch fzf to preview SSH key files.
shell::ssh::key::view::fzf -n    # Dry-run: show the preview command without executing.
```

#### Options

- **-n**

  Optional dry-run flag. If provided, the preview command is printed using shell::logger::command_clip instead of executed.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ssh::key::remove::fzf

Interactively selects one or more SSH key files from $HOME/.ssh using fzf and removes them.

This function lists SSH key files in the user's SSH directory ($HOME/.ssh),
excluding common non-key files. It uses fzf with multi-select to allow the user
to choose one or more files to delete. After confirmation, the selected files
are removed using `rm`. In dry-run mode, the removal commands are printed instead.

#### Example

```bash
shell::ssh::key::remove::fzf       # Launch fzf to select and delete SSH key files.
shell::ssh::key::remove::fzf -n    # Dry-run: show the removal commands without executing.
```

#### Options

- **-n**

  Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ssh::tunnel::open

Opens a direct SSH tunnel connection using provided arguments.

Opens an SSH tunnel using the provided parameters. Supports dry-run mode.

#### Example

```bash
shell::ssh::tunnel::open ~/.ssh/id_rsa 8080 127.0.0.1 80 sysadmin 192.168.1.10 22
```

#### Options

- **-n**

  Optional dry-run flag.

#### Arguments

- **$1** (string): key_file: Path to the SSH private key.
- **$2** (string): local_port: Local port to bind.
- **$3** (string): target_addr: Target service address on the server.
- **$4** (string): target_port: Target service port on the server.
- **$5** (string): user: SSH username.
- **$6** (string): server_addr: SSH server address.
- **$7** (string): server_port: SSH server port.
- **...** (string): timeout: Optional. ConnectTimeout (default: 10).

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ssh::tunnel::open::builder

Interactively builds and opens an SSH tunnel by prompting for each required field.

This function prompts the user to enter each required field for an SSH tunnel connection.
It uses fzf to select the SSH private key file from $HOME/.ssh and then calls shell::ssh::tunnel::open.

#### Example

```bash
shell::ssh::tunnel::open::builder
shell::ssh::tunnel::open::builder -n
```

#### Options

- **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ssh::tunnel::tune

Opens an interactive SSH session using the provided SSH configuration parameters.

This function constructs and executes an SSH command to connect to a remote server using the specified credentials.
It supports dry-run mode for previewing the command.

#### Example

```bash
shell::ssh::tunnel::tune ~/.ssh/id_rsa sysadmin 192.168.1.10 22
shell::ssh::tunnel::tune -n ~/.ssh/id_rsa sysadmin example.com 2222
```

#### Options

- **-n**

  Optional dry-run flag. If provided, the SSH command is printed using shell::logger::command_clip instead of executed.

#### Arguments

- **$1** (string): private_key: Path to the SSH private key file.
- **$2** (string): user: SSH username.
- **$3** (string): host: SSH server address.
- **$4** (string): port: SSH server port.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ssh::tunnel::tune::builder

Interactively builds and opens an SSH tunnel by prompting for each required field.

This function prompts the user to enter each required field for an SSH tunnel connection.
It uses fzf to select the SSH private key file from $HOME/.ssh and then calls shell::ssh::tunnel::tune.

#### Example

```bash
shell::ssh::tunnel::tune::builder
shell::ssh::tunnel::tune::builder -n
```

#### Options

- **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ssh::key::rename

Renames an SSH key file (private or public) in the SSH directory.

This function renames an SSH key file in the user's SSH directory ($HOME/.ssh).
It checks if the SSH directory exists, verifies that the old file exists,
and ensures that the old file is not a known_hosts file. If the dry-run flag is set,
it prints the rename command instead of executing it. Otherwise, it renames the file using `mv`.

#### Example

```bash
shell::ssh::key::rename old_key_name new_key_name
```

#### Options

- **-n**

  Optional dry-run flag. If provided, the rename command is printed using shell::logger::command_clip.

#### Arguments

- **$1** (string): old_name: The current name of the SSH key file.
- **$2** (string): new_name: The new name for the SSH key file.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ssh::key::rename::fzf

Interactively selects an SSH key file and renames it.

This function lists SSH key files in the user's SSH directory ($HOME/.ssh),
excluding common non-key files. It uses fzf to provide an interactive selection interface
for renaming an SSH key file. The user is prompted to enter a new name for the selected key.
If the dry-run flag is set, it prints the rename command instead of executing it.

#### Example

```bash
shell::ssh::key::rename::fzf
```

#### Options

- **-n**

  Optional dry-run flag. If provided, the rename command is printed using shell::logger::command_clip.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
