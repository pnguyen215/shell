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
        shell::colored_echo "🔴 Unsupported operating system: $os_type" 196
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
        shell::colored_echo "🟡 No active SSH tunnels found." 11
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
        shell::colored_echo "🔍 Found $tunnel_count active SSH tunnel(s)" 46
    fi

    # Clean up
    shell::run_cmd_eval rm -f "$temp_file"
}

# shell::fzf_ssh_keys function
# Interactively selects an SSH key file (private or public) from $HOME/.ssh using fzf,
# displays the absolute path of the selected file, and copies the path to the clipboard.
#
# Usage:
#   shell::fzf_ssh_keys
#
# Description:
#   This function lists files within the user's SSH directory ($HOME/.ssh).
#   It filters out common non-key files and then uses fzf to provide an interactive selection interface.
#   Once a file is selected, its absolute path is determined, displayed to the user,
#   and automatically copied to the system clipboard using the shell::clip_value function.
#
# Example usage:
#   shell::fzf_ssh_keys # Launch fzf to select an SSH key and copy its path.
#
# Requirements:
#   - fzf must be installed.
#   - The user must have a $HOME/.ssh directory.
#   - Assumes the presence of helper functions: shell::install_package, shell::colored_echo, shell::clip_value, and shell::is_command_available.
shell::fzf_ssh_keys() {
    # Ensure fzf is installed.
    shell::install_package fzf

    # Define the SSH directory.
    # local ssh_dir="$HOME/.ssh"
    local ssh_dir="$SHELL_CONF_SSH_DIR_WORKING"

    # Check if the SSH directory exists.
    if [ ! -d "$ssh_dir" ]; then
        shell::colored_echo "🔴 Error: SSH directory '"$ssh_dir"' not found." 196
        return 1
    fi

    # Find potential key files in the SSH directory, excluding common non-key files and directories.
    # Using find to get full paths for fzf.
    local key_files
    # key_files=$(find "$ssh_dir" -maxdepth 1 -type f \( ! -name "*.pub" ! -name "known_hosts*" ! -name "config" ! -name "authorized_keys*" ! -name "*.log" \) 2>/dev/null)
    key_files=$(find "$ssh_dir" -maxdepth 1 -type f \( ! -name "known_hosts*" ! -name "config" ! -name "authorized_keys*" ! -name "*.log" \) 2>/dev/null)

    # Check if any potential key files were found.
    if [ -z "$key_files" ]; then
        shell::colored_echo "🟡 No potential SSH key files found in '"$ssh_dir"'." 11
        return 0
    fi

    # Use fzf to select a key file interactively.
    local selected_key
    selected_key=$(echo "$key_files" | fzf --prompt="Select an SSH key file: ")

    # Check if a file was selected.
    if [ -z "$selected_key" ]; then
        shell::colored_echo "🔴 No SSH key file selected." 196
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
    shell::colored_echo "🔑 Selected SSH key: $abs_key_path" 33
    shell::clip_value "$abs_key_path"
    shell::colored_echo "🟢 Absolute path copied to clipboard." 46
    return 0
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
    # Ensure fzf is installed.
    shell::install_package fzf
    shell::colored_echo "🔍 Searching for active SSH tunnel processes..." 33

    # Find SSH processes with tunnel flags (-L, -R, -D).
    # Using ps and grep, compatible with both Linux and MacOS.
    # Exclude the grep command itself from the results.
    local ssh_tunnels_info

    # Use different ps options based on OS for wider compatibility, similar to shell::list_ssh_tunnels
    local os_type
    os_type=$(shell::get_os_type) # Assuming shell::get_os_type exists and works

    if [ "$os_type" = "Linux" ]; then
        # Use 'ax' for all processes, 'u' for user-oriented format (PID, user, command etc.)
        # Use 'ww' to show full command line without truncation.
        # Filter for 'ssh' command and tunnel flags, excluding the grep process.
        ssh_tunnels_info=$(ps auxww | grep --color=never '[s]sh' | grep --color=never -E -- '-[LRD]')
    elif [ "$os_type" = "Darwin" ]; then # MacOS
        # Use 'ax' for all processes, '-o' for custom format including PID, user, command.
        # Use 'www' to show full command line.
        # Filter for 'ssh' command and tunnel flags, excluding the grep process.
        ssh_tunnels_info=$(ps auxwww | grep --color=never '[s]sh' | grep --color=never -E -- '-[LRD]')
    else
        shell::colored_echo "🟡 Warning: Unknown OS type '$os_type'. Using generic ps auxww command, results may vary." 11
        ssh_tunnels_info=$(ps auxww | grep --color=never '[s]sh' | grep --color=never -E -- '-[LRD]')
    fi

    # Check if any potential tunnels were found.
    if [ -z "$ssh_tunnels_info" ]; then
        shell::colored_echo "🟡 No active SSH tunnel processes found." 11
        return 0
    fi

    shell::colored_echo "✅ Found potential SSH tunnels. Use fzf to select one or more to kill (Tab to select multiple):" 46

    # Use fzf to select tunnels. Pipe the info and let fzf handle the selection.
    # --multi allows selecting multiple lines.
    local selected_tunnels
    selected_tunnels=$(echo "$ssh_tunnels_info" | fzf --multi --prompt="Select tunnels to kill: ")

    # Check if any tunnels were selected.
    if [ -z "$selected_tunnels" ]; then
        shell::colored_echo "🔴 No SSH tunnels selected." 196
        return 1
    fi

    shell::colored_echo "Selected tunnels:" 33
    echo "$selected_tunnels" # Display selected tunnels to the user

    # Extract PIDs from selected lines (PID is typically the second column in ps aux/ax output).
    local pids_to_kill
    pids_to_kill=$(echo "$selected_tunnels" | awk '{print $2}') # Assuming PID is the second column

    # Ask for confirmation before killing.
    shell::colored_echo "🟡 Are you sure you want to kill the following PID(s)? $pids_to_kill" 208
    read -r "Confirm (y/N): " confirmation

    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        shell::colored_echo "🔪 Killing PID(s): $pids_to_kill" 208
        # Kill the selected processes.
        # Use command substitution to pass PIDs to kill.
        # shell::run_cmd_eval "kill $pids_to_kill" # Using the helper if preferred
        kill $pids_to_kill # Direct kill command

        # Optional: Add a small delay and check if processes are still running
        # sleep 1
        # if ps -p $pids_to_kill > /dev/null 2>&1; then
        #     shell::colored_echo "🔴 Failed to kill one or more processes." 196
        # else
        #     shell::colored_echo "🟢 Successfully killed PID(s): $pids_to_kill" 46
        # fi
        shell::colored_echo "🟢 Kill command sent for PID(s): $pids_to_kill. Verify they are stopped." 46

    else
        shell::colored_echo "❌ Kill operation cancelled." 11
        return 0
    fi

    return 0
}
