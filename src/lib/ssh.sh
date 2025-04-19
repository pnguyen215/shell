#!/bin/bash
# ssh.sh

# shell::list_ssh_tunnel function
# Displays information about active SSH tunnel forwarding processes in a line-by-line format.
#
# Usage:
#   shell::list_ssh_tunnel [-n]
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
#   shell::list_ssh_tunnel           # Display active SSH tunnels
#   shell::list_ssh_tunnel -n        # Show commands that would be executed (dry-run mode)
#
# Notes:
#   - Requires the 'ps' command to be available
#   - Works on both macOS and Linux systems
#   - Uses different parsing approaches based on the detected operating system
#   - Leverages shell::run_cmd_eval for command execution and shell::on_evict for dry-run mode
shell::list_ssh_tunnel() {
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
    local cmd=""
    if [ "$os_type" = "linux" ]; then
        # Linux processing
        cmd="ps aux | grep ssh | grep -v grep | grep -E -- '-[DLR]' > \"$temp_file\""
    elif [ "$os_type" = "macos" ]; then
        # macOS processing
        cmd="ps -ax -o pid,user,start,time,command | grep ssh | grep -v grep | grep -E -- '-[DLR]' > \"$temp_file\""
    else
        shell::colored_echo "🔴 Unsupported operating system: $os_type" 196
        rm -f "$temp_file"
        return 1
    fi

    # Execute or display the command based on dry-run flag
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
        rm -f "$temp_file"
        return 0
    else
        shell::run_cmd_eval "$cmd"
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
    shell::colored_echo "SSH TUNNELS" 33
    echo "==========================================================="

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
            cmd=$(echo "$cmd" | awk '{print $1}') &>/dev/null

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
