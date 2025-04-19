#!/bin/bash
# ssh.sh

# shell::list_ssh_tunnel function
# Displays information about active SSH tunnel forwarding processes.
#
# Usage:
#   shell::list_ssh_tunnel
#
# Description:
#   This function identifies and displays all SSH processes that are using port forwarding options
#   (-L, -R, or -D). It shows detailed information about each process including PID, username,
#   start time, elapsed time, command, and specific forwarding details (local port, forwarding type,
#   remote port, remote host). The function works cross-platform on both macOS and Linux systems.
#
# Output Columns:
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
#   shell::list_ssh_tunnel
#
# Notes:
#   - Requires the 'ps' command to be available
#   - Works on both macOS and Linux systems
#   - Uses different parsing approaches based on the detected operating system
shell::list_ssh_tunnel() {
    # Get the operating system type
    local os_type
    os_type=$(shell::get_os_type)

    # Define the common column headers
    local header_format="%-10s %-10s %-20s %-20s %-20s %-10s %-20s %-20s %-20s\n"
    local header_values=("PID" "USER" "START" "TIME" "COMMAND" "LOCAL_PORT" "FORWARD_TYPE" "REMOTE_PORT" "REMOTE_HOST")

    # Print the header
    printf "$header_format" "${header_values[@]}"

    # Create a temporary file for processing
    local temp_file
    temp_file=$(mktemp)

    # Find all SSH processes that use port forwarding
    if [ "$os_type" = "linux" ]; then
        # Linux processing
        ps aux | grep ssh | grep -v grep | grep -E -- '-[DLR]' >"$temp_file"
    elif [ "$os_type" = "macos" ]; then
        # macOS processing
        ps -ax -o pid,user,start,time,command | grep ssh | grep -v grep | grep -E -- '-[DLR]' >"$temp_file"
    else
        shell::colored_echo "🔴 Unsupported operating system: $os_type" 196
        rm -f "$temp_file"
        return 1
    fi

    # If no SSH tunnels were found, display a message and exit
    if [ ! -s "$temp_file" ]; then
        shell::colored_echo "🟡 No active SSH tunnels found." 11
        rm -f "$temp_file"
        return 0
    fi

    # Process each line in the temp file
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
                # Local or remote forwarding: -L/-R [bind_address:]port:host:hostport
                local port_spec
                port_spec=$(echo "$ssh_options" | cut -d ' ' -f 2)

                # Extract the local port (for -L) or remote port (for -R)
                if [[ "$port_spec" == *:*:* ]]; then
                    # Format with bind address: [bind_address:]port:host:hostport
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

            # Limit the command display to just 'ssh' for cleaner output
            cmd=$(echo "$cmd" | awk '{print $1}')

            # Print the formatted line
            printf "$header_format" "$pid" "$user" "$start_time" "$elapsed_time" "$cmd" "$local_port" "$forward_type" "$remote_port" "$remote_host"
        fi
    done <"$temp_file"

    # Clean up
    rm -f "$temp_file"
}
