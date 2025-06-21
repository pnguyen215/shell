#!/bin/bash
# ssh.sh

# shell::list_ssh_tunnels function
# Displays information about active SSH tunnel forwarding processes in a line-by-line format.
#
# Usage:
#   shell::list_ssh_tunnels [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#
# Description:
#   This function identifies and displays all SSH processes that are using port forwarding options
#   (-L, -R, or -D). It shows detailed information about each process including PID, username,
#   start time, elapsed time, command, and specific forwarding details (local port, forwarding type,
#   remote port, remote host). The function works cross-platform on both macOS and Linux systems.
#
# Output Fields:
#   - PID: Process ID of the SSH tunnel
#   - USER: Username running the SSH tunnel
#   - START: Start time of the process
#   - TIME: Elapsed time the process has been running
#   - COMMAND: The SSH command path
#   - LOCAL_PORT: The local port being forwarded
#   - FORWARD_TYPE: Type of forwarding (-L for local, -R for remote, -D for dynamic)
#   - REMOTE_PORT: The remote port
#   - REMOTE_HOST: The remote host
#
# Example usage:
#   shell::list_ssh_tunnels           # Display active SSH tunnels
#   shell::list_ssh_tunnels -n        # Show commands that would be executed (dry-run mode)
#
# Notes:
#   - Requires the 'ps' command to be available
#   - Works on both macOS and Linux systems
#   - Uses different parsing approaches based on the detected operating system
#   - Leverages shell::run_cmd_eval for command execution and shell::on_evict for dry-run mode
shell::list_ssh_tunnels() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_LIST_SSH_TUNNEL"
        return 0
    fi

    # Get the operating system type
    local os_type
    os_type=$(shell::get_os_type)

    # Create a temporary file for processing
    local temp_file
    temp_file=$(mktemp)

    # Base command for finding SSH tunnels differs by OS
    local ps_cmd=""
    if [ "$os_type" = "linux" ]; then
        ps_cmd="ps aux | grep ssh | grep -v grep | grep -E -- '-[DLR]' > \"$temp_file\""
    elif [ "$os_type" = "macos" ]; then
        ps_cmd="ps -ax -o pid,user,start,time,command | grep ssh | grep -v grep | grep -E -- '-[DLR]' > \"$temp_file\"" &>/dev/null
    else
        shell::colored_echo "ERR: Unsupported operating system: $os_type" 196
        rm -f "$temp_file"
        return 1
    fi

    # Execute or display the command based on dry-run flag
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$ps_cmd"
        rm -f "$temp_file"
        return 0
    else
        shell::run_cmd_eval "$ps_cmd"
    fi

    # If no SSH tunnels were found, display a message and exit
    if [ ! -s "$temp_file" ]; then
        shell::colored_echo "WARN: No active SSH tunnels found." 11
        rm -f "$temp_file"
        return 0
    fi

    # Process each line and extract SSH tunnel information
    local tunnel_count=0

    # Print a header
    # shell::colored_echo "SSH TUNNELS" 33
    # echo "==========================================================="

    while IFS= read -r line; do
        # Extract the base process information
        local pid user start_time elapsed_time cmd forward_type local_port remote_port remote_host

        if [ "$os_type" = "linux" ]; then
            # Extract the basic process information for Linux
            user=$(echo "$line" | awk '{print $1}')
            pid=$(echo "$line" | awk '{print $2}')
            start_time=$(echo "$line" | awk '{print $9}')
            elapsed_time=$(echo "$line" | awk '{print $10}')
            # Extract SSH command (everything after the 10th field)
            cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i}')
        elif [ "$os_type" = "macos" ]; then
            # Extract the basic process information for macOS
            pid=$(echo "$line" | awk '{print $1}')
            user=$(echo "$line" | awk '{print $2}')
            start_time=$(echo "$line" | awk '{print $3}')
            elapsed_time=$(echo "$line" | awk '{print $4}')
            # Extract SSH command (everything after the 4th field)
            cmd=$(echo "$line" | awk '{for(i=5;i<=NF;i++) printf "%s ", $i}')
        fi

        # Now parse the command to extract port forwarding information
        local ssh_options
        ssh_options=$(echo "$cmd" | grep -oE -- '-[DLR] [^ ]+' | head -1)

        if [ -n "$ssh_options" ]; then
            # Extract the forwarding type (-L, -R, or -D)
            forward_type=$(echo "$ssh_options" | cut -d ' ' -f 1)

            # Parse the port specifications based on the forwarding type
            case "$forward_type" in
            "-D")
                # Dynamic forwarding: -D [bind_address:]port
                local_port=$(echo "$ssh_options" | cut -d ' ' -f 2 | awk -F: '{print $NF}')
                remote_port="N/A"
                remote_host="N/A"
                ;;
            "-L" | "-R")
                # Local or remote forwarding: -L/-R [bind_address:]port:host:host_port
                local port_spec
                port_spec=$(echo "$ssh_options" | cut -d ' ' -f 2)

                # Extract the local port (for -L) or remote port (for -R)
                if [[ "$port_spec" == *:*:* ]]; then
                    # Format with bind address: [bind_address:]port:host:host_port
                    if [[ "$port_spec" == *:*:*:* ]]; then
                        # Has bind address
                        local_port=$(echo "$port_spec" | awk -F: '{print $2}')
                    else
                        # No bind address
                        local_port=$(echo "$port_spec" | awk -F: '{print $1}')
                    fi

                    # Extract the remote host and port
                    if [[ "$port_spec" == *:*:*:* ]]; then
                        remote_host=$(echo "$port_spec" | awk -F: '{print $3}')
                        remote_port=$(echo "$port_spec" | awk -F: '{print $4}')
                    else
                        remote_host=$(echo "$port_spec" | awk -F: '{print $2}')
                        remote_port=$(echo "$port_spec" | awk -F: '{print $3}')
                    fi
                else
                    # Simple format: port
                    local_port="$port_spec"
                    remote_port="Unknown"
                    remote_host="Unknown"
                fi
                ;;
            *)
                # Fallback for unexpected format
                local_port="Unknown"
                remote_port="Unknown"
                remote_host="Unknown"
                ;;
            esac

            # Extract just the SSH command without arguments for cleaner display
            cmd=$(echo "$cmd" | awk '{print $1}')

            # Increment the tunnel count
            ((tunnel_count++))

            # Print the tunnel information with clear labels in a line-by-line format
            echo "-----------------------------------------------------------"
            shell::colored_echo "TUNNEL #$tunnel_count" 46
            echo "PID:           $pid"
            echo "USER:          $user"
            echo "START:         $start_time"
            echo "RUNTIME:       $elapsed_time"
            echo "COMMAND:       $cmd"
            echo "LOCAL PORT:    $local_port"
            if [ "$forward_type" = "-L" ]; then
                echo "FORWARD TYPE:  Local ($forward_type)"
            elif [ "$forward_type" = "-R" ]; then
                echo "FORWARD TYPE:  Remote ($forward_type)"
            elif [ "$forward_type" = "-D" ]; then
                echo "FORWARD TYPE:  Dynamic ($forward_type)"
            else
                echo "FORWARD TYPE:  $forward_type"
            fi
            echo "REMOTE PORT:   $remote_port"
            echo "REMOTE HOST:   $remote_host"
        fi
    done <"$temp_file"

    # Print a summary if tunnels were found
    if [ "$tunnel_count" -gt 0 ]; then
        echo "==========================================================="
        shell::colored_echo "INFO: Found $tunnel_count active SSH tunnel(s)" 46
    fi

    # Clean up
    shell::run_cmd_eval rm -f "$temp_file"
}

# shell::fzf_cwd_ssh_key function
# Interactively selects an SSH key file (private or public) from $HOME/.ssh using fzf,
# displays the absolute path of the selected file, and copies the path to the clipboard.
#
# Usage:
#   shell::fzf_cwd_ssh_key
#
# Description:
#   This function lists files within the user's SSH directory ($HOME/.ssh).
#   It filters out common non-key files and then uses fzf to provide an interactive selection interface.
#   Once a file is selected, its absolute path is determined, displayed to the user,
#   and automatically copied to the system clipboard using the shell::clip_value function.
#
# Example usage:
#   shell::fzf_cwd_ssh_key # Launch fzf to select an SSH key and copy its path.
#
# Requirements:
#   - fzf must be installed.
#   - The user must have a $HOME/.ssh directory.
#   - Assumes the presence of helper functions: shell::install_package, shell::colored_echo, shell::clip_value, and shell::is_command_available.
shell::fzf_cwd_ssh_key() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_CWD_SSH_KEY"
        return 0
    fi

    # Ensure fzf is installed.
    shell::install_package fzf

    # Define the SSH directory.
    # local ssh_dir="$HOME/.ssh"
    local ssh_dir="${SHELL_CONF_SSH_DIR_WORKING:-$HOME/.ssh}"

    # Check if the SSH directory exists.
    if [ ! -d "$ssh_dir" ]; then
        shell::colored_echo "ERR: SSH directory '"$ssh_dir"' not found." 196
        return 1
    fi

    # Find potential key files in the SSH directory, excluding common non-key files and directories.
    # Using find to get full paths for fzf.
    local key_files
    # key_files=$(find "$ssh_dir" -maxdepth 1 -type f \( ! -name "*.pub" ! -name "known_hosts*" ! -name "config" ! -name "authorized_keys*" ! -name "*.log" \) 2>/dev/null)
    key_files=$(find "$ssh_dir" -maxdepth 1 -type f \( ! -name "known_hosts*" ! -name "config" ! -name "authorized_keys*" ! -name "*.log" \) 2>/dev/null)

    # Check if any potential key files were found.
    if [ -z "$key_files" ]; then
        shell::colored_echo "WARN: No potential SSH key files found in '"$ssh_dir"'." 11
        return 0
    fi

    # Use fzf to select a key file interactively.
    local selected_key
    selected_key=$(echo "$key_files" | fzf --prompt="Select an SSH key file: ")

    # Check if a file was selected.
    if [ -z "$selected_key" ]; then
        shell::colored_echo "ERR: No SSH key file selected." 196
        return 1
    fi

    # Get the absolute path of the selected file.
    local abs_key_path
    # Use realpath if available for robustness, otherwise rely on find's output format.
    if shell::is_command_available realpath; then
        abs_key_path=$(realpath "$selected_key")
    else
        abs_key_path="$selected_key"
    fi

    # Display the absolute path and copy it to the clipboard.
    shell::colored_echo "[k] Selected SSH key: $abs_key_path" 33
    shell::clip_value "$abs_key_path"
    return 0
}

# shell::fzf_copy_ssh_key_value function
# Uses fzf to select an SSH key file and copies its contents to the clipboard using shell::clip_value.
#
# Usage:
#   shell::fzf_copy_ssh_key_value [-h]
#
# Parameters:
#   - -h : Optional help flag. Displays this help message.
#
# Description:
#   This function searches for SSH key files in ~/.ssh, filters out public keys and config files,
#   and presents them via fzf for selection. Once selected, the contents of the file
#   are copied to the clipboard using shell::clip_value.
#
# Requirements:
#   - fzf must be installed.
#   - The 'shell::clip_value' function must be available.
#   - Helper functions: shell::install_package, shell::colored_echo, shell::clip_value.
#
# Example usage:
#   shell::fzf_copy_ssh_key_value
shell::fzf_copy_ssh_key_value() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_COPY_SSH_KEY_VALUE"
        return 0
    fi

    # Ensure fzf is installed.
    shell::install_package fzf

    # Check the SSH directory.
    # Use the configured SSH directory or default to $HOME/.ssh.
    local ssh_dir="${SHELL_CONF_SSH_DIR_WORKING:-$HOME/.ssh}"
    if [ ! -d "$ssh_dir" ]; then
        shell::colored_echo "ERR: SSH directory '$ssh_dir' not found." 196
        return 1
    fi

    # Find potential key files in the SSH directory, excluding common non-key files and directories.
    # Using find to get full paths for fzf.
    local key_files
    key_files=$(find "$ssh_dir" -maxdepth 1 -type f \( ! -name "known_hosts*" ! -name "config" ! -name "authorized_keys*" ! -name "*.log" \) 2>/dev/null)

    # Check if any potential key files were found.
    if [ -z "$key_files" ]; then
        shell::colored_echo "WARN: No potential SSH key files found in '"$ssh_dir"'." 11
        return 0
    fi

    # Use fzf to select a key file interactively.
    local selected_key
    selected_key=$(echo "$key_files" | fzf --prompt="Select an SSH key file to copy: ")

    # Check if a file was selected.
    if [ ! -f "$selected_key" ]; then
        shell::colored_echo "ERR: Selected file '$selected_key' does not exist." 196
        return 1
    fi

    # Get the absolute path of the selected file.
    local abs_key_path
    # Use realpath if available for robustness, otherwise rely on find's output format.
    if shell::is_command_available realpath; then
        abs_key_path=$(realpath "$selected_key")
    else
        abs_key_path="$selected_key"
    fi

    local content
    content=$(cat "$abs_key_path")

    shell::clip_value "$content"
    shell::colored_echo "INFO: SSH key file '$abs_key_path' copied to clipboard." 46
}

# shell::fzf_kill_ssh_tunnels function
# Interactively selects one or more SSH tunnel processes using fzf and kills them.
#
# Usage:
#   shell::fzf_kill_ssh_tunnels
#
# Description:
#   This function identifies potential SSH tunnel processes by searching for 'ssh'
#   commands with port forwarding flags (-L, -R, or -D). It presents a list of
#   these processes, including their PIDs and command details, in an fzf interface
#   for interactive selection. The user can select one or multiple processes.
#   After selection, the user is prompted for confirmation before the selected
#   processes are terminated using the `kill` command.
#
# Example usage:
#   shell::fzf_kill_ssh_tunnels # Launch fzf to select and kill SSH tunnels.
#
# Requirements:
#   - fzf must be installed.
#   - Assumes the presence of helper functions: shell::install_package, shell::colored_echo, shell::run_cmd_eval.
shell::fzf_kill_ssh_tunnels() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_KILL_SSH_TUNNEL"
        return 0
    fi

    # Ensure fzf is installed.
    shell::install_package fzf

    # Find SSH processes with tunnel flags (-L, -R, -D).
    # Using ps and grep, compatible with both Linux and MacOS.
    # Exclude the grep command itself from the results.
    local ssh_tunnels_info

    # Use different ps options based on OS for wider compatibility, similar to shell::list_ssh_tunnels
    local os_type
    os_type=$(shell::get_os_type) # Assuming shell::get_os_type exists and works

    if [ "$os_type" = "linux" ]; then
        # Use 'ax' for all processes, 'u' for user-oriented format (PID, user, command etc.)
        # Use 'ww' to show full command line without truncation.
        # Filter for 'ssh' command and tunnel flags, excluding the grep process.
        ssh_tunnels_info=$(ps auxww | grep --color=never '[s]sh' | grep --color=never -E -- '-[LRD]')
    elif [ "$os_type" = "macos" ]; then # MacOS
        # Use 'ax' for all processes, '-o' for custom format including PID, user, command.
        # Use 'www' to show full command line.
        # Filter for 'ssh' command and tunnel flags, excluding the grep process.
        ssh_tunnels_info=$(ps auxwww | grep --color=never '[s]sh' | grep --color=never -E -- '-[LRD]')
    else
        shell::colored_echo "WARN: Warning: Unknown OS type '$os_type'. Using generic ps auxww command, results may vary." 11
        ssh_tunnels_info=$(ps auxww | grep --color=never '[s]sh' | grep --color=never -E -- '-[LRD]')
    fi

    # Check if any potential tunnels were found.
    if [ -z "$ssh_tunnels_info" ]; then
        shell::colored_echo "WARN: No active SSH tunnel processes found." 11
        return 0
    fi

    # Use fzf to select tunnels. Pipe the info and let fzf handle the selection.
    # --multi allows selecting multiple lines.
    local selected_tunnels
    selected_tunnels=$(echo "$ssh_tunnels_info" | fzf --prompt="Select tunnels to kill: ")

    # Check if any tunnels were selected.
    if [ -z "$selected_tunnels" ]; then
        shell::colored_echo "ERR: No SSH tunnels selected." 196
        return 1
    fi

    shell::colored_echo "DEBUG: Selected tunnels:" 244
    echo "$selected_tunnels" # Display selected tunnels to the user

    # Extract PIDs from selected lines (PID is typically the second column in ps aux/ax output).
    local pids_to_kill
    pids_to_kill=$(echo "$selected_tunnels" | awk '{print $2}') # Assuming PID is the second column

    # Ask for confirmation before killing.
    shell::colored_echo "[q] Are you sure you want to kill the following PID(s)? $pids_to_kill [y/N]" 208
    read -r confirmation

    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        shell::colored_echo "DEBUG: Killing PID(s): $pids_to_kill" 244
        # Kill the selected processes.
        # Use command substitution to pass PIDs to kill.
        # shell::run_cmd_eval "kill $pids_to_kill" # Using the helper if preferred
        kill $pids_to_kill # Direct kill command

        # Optional: Add a small delay and check if processes are still running
        # sleep 1
        # if ps -p $pids_to_kill > /dev/null 2>&1; then
        #     shell::colored_echo "ERR: Failed to kill one or more processes." 196
        # else
        #     shell::colored_echo "INFO: Successfully killed PID(s): $pids_to_kill" 46
        # fi
        shell::colored_echo "INFO: Kill command sent for PID(s): $pids_to_kill. Verify they are stopped." 46

    else
        shell::colored_echo "WARN: Kill operation cancelled." 11
        return 0
    fi

    return 0
}

# shell::kill_ssh_tunnels function
# Kills all active SSH tunnel forwarding processes.
#
# Usage:
#   shell::kill_ssh_tunnels [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, kill commands are printed using shell::on_evict instead of executed.
#
# Description:
#   This function identifies all SSH processes that are using port forwarding options
#   (-L, -R, or -D) [cite: 12] and attempts to terminate them using the 'kill' command.
#   It works cross-platform on both macOS and Linux systems.
#   Confirmation is requested before killing processes unless the dry-run flag is used.
#
# Example usage:
#   shell::kill_ssh_tunnels       # Kills active SSH tunnels after confirmation.
#   shell::kill_ssh_tunnels -n    # Shows kill commands that would be executed (dry-run mode).
#
# Notes:
#   - Requires the 'ps' and 'kill' commands to be available.
#   - Works on both macOS and Linux systems.
#   - Uses different parsing approaches based on the detected operating system.
#   - Leverages shell::run_cmd for command execution and shell::on_evict for dry-run mode.
shell::kill_ssh_tunnels() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_KILL_SSH_TUNNEL"
        return 0
    fi

    # Get the operating system type
    local os_type
    os_type=$(shell::get_os_type)

    # Create a temporary file for processing PIDs
    local temp_pids
    temp_pids=$(mktemp)

    # Command to find PIDs of SSH tunnels differs by OS
    local ps_cmd=""
    if [ "$os_type" = "linux" ]; then
        ps_cmd="ps aux | grep ssh | grep -v grep | grep -E -- '-[DLR]' | awk '{print \$2}' > \"$temp_pids\""
    elif [ "$os_type" = "macos" ]; then
        ps_cmd="ps -ax -o pid,command | grep ssh | grep -v grep | grep -E -- '-[DLR]' | awk '{print \$1}' > \"$temp_pids\""
    else
        shell::colored_echo "ERR: Unsupported operating system: $os_type" 196
        rm -f "$temp_pids"
        return 1
    fi

    # Execute the command to get PIDs
    # Using eval because the command string contains pipes and redirection
    eval "$ps_cmd"

    # Check if any SSH tunnel PIDs were found
    if [ ! -s "$temp_pids" ]; then
        shell::colored_echo "WARN: No active SSH tunnels found to kill." 11
        rm -f "$temp_pids"
        return 0
    fi

    # Read PIDs into an array
    local pids_to_kill=()
    while IFS= read -r pid; do
        # Basic validation to ensure it's a number
        if [[ "$pid" =~ ^[0-9]+$ ]]; then
            pids_to_kill+=("$pid")
        fi
    done <"$temp_pids"

    # Clean up the temporary file
    rm -f "$temp_pids"

    # Check again if any valid PIDs were collected
    if [ ${#pids_to_kill[@]} -eq 0 ]; then
        shell::colored_echo "WARN: No valid SSH tunnel PIDs found to kill." 11
        return 0
    fi

    shell::colored_echo "DEBUG: SSH tunnel(s) PIDs were found:" 244
    echo "${pids_to_kill[*]}"

    if [ "$dry_run" = "true" ]; then
        for pid in "${pids_to_kill[@]}"; do
            local kill_cmd="kill $pid"
            shell::on_evict "$kill_cmd"
        done
    else
        # Ask for confirmation before killing
        # Use printf for prompt to avoid issues with colored_echo potentially adding newlines
        printf "%s" "$(shell::colored_echo '[q] Do you want to kill these processes? (y/N): ' 208)"
        read -r confirm

        if [[ $confirm =~ ^[Yy]$ ]]; then
            shell::colored_echo "DEBUG: Killing SSH tunnels..." 244
            local kill_count=0
            for pid in "${pids_to_kill[@]}"; do
                if shell::run_cmd kill "$pid"; then
                    shell::colored_echo "INFO: Killed PID $pid successfully." 46
                    ((kill_count++))
                else
                    shell::colored_echo "ERR: Failed to kill PID $pid." 196
                fi
            done
            shell::colored_echo "INFO: Killed $kill_count out of ${#pids_to_kill[@]} SSH tunnel process(es)." 46
        else
            shell::colored_echo "WARN: Aborted by user. No processes were killed." 11
        fi
    fi

    return 0
}

# shell::gen_ssh_key function
# Generates an SSH key pair (private and public) and saves them to the SSH directory.
#
# Usage:
#   shell::gen_ssh_key [-n] [-t key_type] [-p passphrase] [-h] [email] [key_filename]
#
# Parameters:
#   - -n              : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#   - -t key_type     : Optional. Specifies the key type (e.g., rsa, ed25519). Defaults to rsa.
#   - -p passphrase   : Optional. Specifies the passphrase for the key. Defaults to empty (no passphrase).
#   - -h              : Optional. Displays this help message.
#   - [email]         : Optional. The email address to be included in the comment field of the SSH key.
#                       Defaults to an empty string if not provided.
#   - [key_filename]  : Optional. The name of the key file to generate within the SSH directory.
#                       Defaults to 'id_rsa' if not provided.
#
# Description:
#   This function creates the SSH directory (defaults to $HOME/.ssh)
#   if it doesn't exist and generates an SSH key pair using ssh-keygen. It supports specifying the key type,
#   passphrase, email comment, and filename. The function ensures the ssh-keygen command is available,
#   checks for existing keys, and sets appropriate permissions on generated files.
#
# Example usage:
#   shell::gen_ssh_key                                  # Generates rsa key in ~/.ssh/id_rsa with no comment or passphrase.
#   shell::gen_ssh_key "user@example.com"              # Generates rsa key with email, saved as ~/.ssh/id_rsa.
#   shell::gen_ssh_key -t ed25519 "user@example.com"   # Generates ed25519 key with email.
#   shell::gen_ssh_key "" "my_key"                     # Generates rsa key with no comment, saved as ~/.ssh/my_key.
#   shell::gen_ssh_key -n "user@example.com" "my_key"  # Dry-run: prints the command without executing.
#   shell::gen_ssh_key -h                              # Displays this help message.
#
# Notes:
#   - Uses 4096-bit keys for rsa; ed25519 uses its default key size.
#   - Sets key file permissions to 600 (private) and 644 (public) for security.
#   - Relies on shell::create_directory_if_not_exists, shell::run_cmd_eval, and shell::is_command_available.
#   - Validates the presence of ssh-keygen in the system's PATH.
shell::gen_ssh_key() {
    local dry_run="false"
    local key_type="rsa"
    local passphrase=""

    # Parse options
    while [[ "$1" == -* ]]; do
        case "$1" in
        -n)
            dry_run="true"
            shift
            ;;
        -t)
            key_type="$2"
            shift 2
            ;;
        -p)
            passphrase="$2"
            shift 2
            ;;
        -h)
            echo "$USAGE_SHELL_GEN_SSH_KEY"
            return 0
            ;;
        *)
            shell::colored_echo "ERR: Unknown option: $1" 196
            echo "$USAGE_SHELL_GEN_SSH_KEY"
            return 1
            ;;
        esac
    done

    local email="${1:-}"              # Default to empty string if no email
    local key_filename="${2:-id_rsa}" # Default to id_rsa if no filename

    # Sanitize the bookmark name to ensure it is a valid variable name.
    # This is to ensure the key filename is safe and follows conventions.
    # shell::sanitize_lower_var_name is assumed to be a function that sanitizes the variable name.
    key_filename=$(shell::sanitize_lower_var_name "$key_filename")

    local ssh_dir="${SHELL_CONF_SSH_DIR_WORKING:-$HOME/.ssh}"
    local full_key_path="$ssh_dir/$key_filename"

    # Validate ssh-keygen availability
    if ! shell::is_command_available ssh-keygen; then
        shell::colored_echo "ERR: ssh-keygen is not available. Please install openssh-client." 196
        return 1
    fi

    # Validate key type
    case "$key_type" in
    rsa | ed25519) ;;
    *)
        shell::colored_echo "ERR: Unsupported key type '$key_type'. Supported types: rsa, ed25519." 196
        return 1
        ;;
    esac

    # Ensure SSH directory exists
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "shell::create_directory_if_not_exists \"$ssh_dir\""
    else
        shell::create_directory_if_not_exists "$ssh_dir"
        if [ $? -ne 0 ]; then
            shell::colored_echo "ERR: Failed to create SSH directory '$ssh_dir'." 196
            return 1
        fi
    fi

    # Check if key file already exists
    if [ -f "$full_key_path" ]; then
        shell::colored_echo "WARN: SSH key '$full_key_path' already exists. Skipping generation." 11
        return 0
    fi

    # Build ssh-keygen command
    local ssh_keygen_cmd="ssh-keygen -t $key_type"
    if [ "$key_type" = "rsa" ]; then
        ssh_keygen_cmd="$ssh_keygen_cmd -b 4096"
    fi
    ssh_keygen_cmd="$ssh_keygen_cmd -C \"$email\" -f \"$full_key_path\""
    if [ -n "$passphrase" ]; then
        ssh_keygen_cmd="$ssh_keygen_cmd -N \"$passphrase\""
    else
        ssh_keygen_cmd="$ssh_keygen_cmd -N ''"
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$ssh_keygen_cmd"
    else
        shell::colored_echo "Generating SSH key pair: $full_key_path" 33
        shell::run_cmd_eval "$ssh_keygen_cmd"
        if [ $? -eq 0 ]; then
            shell::run_cmd_eval chmod 600 "$full_key_path"
            shell::run_cmd_eval chmod 644 "${full_key_path}.pub"
            shell::colored_echo "INFO: SSH key pair generated successfully:" 46
            shell::colored_echo "  Private key: $full_key_path" 46
            shell::colored_echo "  Public key:  ${full_key_path}.pub" 46
        else
            shell::colored_echo "ERR: Failed to generate SSH key pair." 196
            return 1
        fi
    fi

    return 0
}

# shell::fzf_view_ssh_key function
# Interactively selects an SSH key file from $HOME/.ssh using fzf,
# and previews its contents in real-time in a wrapped preview window.
#
# Usage:
# shell::fzf_view_ssh_key [-n]
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the preview command is printed using shell::on_evict instead of executed.
#
# Description:
# This function lists files within the user's SSH directory ($HOME/.ssh),
# excluding common non-key files. It uses fzf to provide an interactive
# selection interface with a preview window that shows the contents of
# each file in real-time. The preview is wrapped for readability.
#
# Example usage:
# shell::fzf_view_ssh_key       # Launch fzf to preview SSH key files.
# shell::fzf_view_ssh_key -n    # Dry-run: show the preview command without executing.
shell::fzf_view_ssh_key() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_VIEW_SSH_KEY"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Ensure fzf is installed
    shell::install_package fzf

    # Define the SSH directory
    local ssh_dir="${SHELL_CONF_SSH_DIR_WORKING:-$HOME/.ssh}"

    # Check if the SSH directory exists
    if [ ! -d "$ssh_dir" ]; then
        shell::colored_echo "ERR: SSH directory '$ssh_dir' not found." 196
        return 1
    fi

    # Find potential key files in the SSH directory
    # Exclude common non-key files and directories.
    # Using find to get full paths for fzf.
    local key_files
    key_files=$(find "$ssh_dir" -maxdepth 1 -type f \( ! -name "known_hosts*" ! -name "config" ! -name "authorized_keys*" ! -name "*.log" \) 2>/dev/null)

    # Check if any potential key files were found
    if [ -z "$key_files" ]; then
        shell::colored_echo "WARN: No potential SSH key files found in '$ssh_dir'." 11
        return 0
    fi

    # Use fzf to select a key file interactively with a preview
    # The preview shows the contents of the selected file in a wrapped window.
    # Using --ansi to allow colored output in the preview.
    # Using --preview-window=up:wrap to show the preview above the selection.
    # Using echo to pass the key files to fzf.
    local fzf_cmd
    fzf_cmd="echo \"$key_files\" | fzf --ansi --prompt='Preview SSH key file: ' --preview='cat {}' --preview-window=up:wrap"

    # If dry-run is enabled, print the command instead of executing it
    # This allows the user to see what would happen without making changes.
    # If not dry-run, execute the command.
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$fzf_cmd"
        return 0
    else
        eval "$fzf_cmd"
    fi
}

# shell::fzf_remove_ssh_keys function
# Interactively selects one or more SSH key files from $HOME/.ssh using fzf and removes them.
#
# Usage:
# shell::fzf_remove_ssh_keys [-n]
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the removal command is printed using shell::on_evict instead of executed.
#
# Description:
# This function lists SSH key files in the user's SSH directory ($HOME/.ssh),
# excluding common non-key files. It uses fzf with multi-select to allow the user
# to choose one or more files to delete. After confirmation, the selected files
# are removed using `rm`. In dry-run mode, the removal commands are printed instead.
#
# Example usage:
# shell::fzf_remove_ssh_keys       # Launch fzf to select and delete SSH key files.
# shell::fzf_remove_ssh_keys -n    # Dry-run: show the removal commands without executing.
shell::fzf_remove_ssh_keys() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_REMOVE_SSH_KEYS"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Ensure fzf is installed
    shell::install_package fzf

    # Define the SSH directory
    local ssh_dir="${SHELL_CONF_SSH_DIR_WORKING:-$HOME/.ssh}"

    # Check if the SSH directory exists
    if [ ! -d "$ssh_dir" ]; then
        shell::colored_echo "ERR: SSH directory '$ssh_dir' not found." 196
        return 1
    fi

    # Find potential key files in the SSH directory
    local key_files
    key_files=$(find "$ssh_dir" -maxdepth 1 -type f \( ! -name "known_hosts*" ! -name "config" ! -name "authorized_keys*" ! -name "*.log" \) 2>/dev/null)

    if [ -z "$key_files" ]; then
        shell::colored_echo "WARN: No SSH key files found in '$ssh_dir'." 11
        return 0
    fi

    # Use fzf to select one or more files
    # --multi allows selecting multiple files.
    # --prompt sets the prompt text.
    # --preview shows the contents of the selected file in a wrapped window.
    local selected_files
    selected_files=$(echo "$key_files" | fzf --multi --prompt="Select SSH key files to remove: ")

    # Check if any files were selected
    if [ -z "$selected_files" ]; then
        shell::colored_echo "ERR: No SSH key files selected." 196
        return 1
    fi

    shell::colored_echo "DEBUG: Selected files for removal:" 244
    echo "$selected_files"

    # Ask for confirmation before deleting
    # If dry-run is disabled, prompt the user for confirmation.
    if [ "$dry_run" = "false" ]; then
        shell::colored_echo "[q] Are you sure you want to delete the selected file(s)? [y/N]" 208
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            shell::colored_echo "WARN: Deletion cancelled." 11
            return 0
        fi
    fi

    # Remove each selected file
    # Using a while loop to read each line (file path) from the selected files.
    # Using sudo rm -f to ensure files are removed even if they are protected.
    while IFS= read -r file; do
        local cmd="sudo rm -f \"$file\""
        if [ "$dry_run" = "true" ]; then
            shell::on_evict "$cmd"
        else
            shell::run_cmd_eval "$cmd"
            shell::colored_echo "INFO: SSH key file removal process completed." 46
        fi
    done <<<"$selected_files"
    return 0
}
