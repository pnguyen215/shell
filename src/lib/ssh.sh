#!/bin/bash
# ssh.sh

# shell::list_ssh_tunnel function
# Displays information about active SSH tunnel forwarding processes in a well-formatted table.
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

    # Process the tunnels and store results
    local results_file
    results_file=$(mktemp)

    # Process each line in the temp file and store structured data
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

            # Store result in structured format with field separator
            echo "$pid|$user|$start_time|$elapsed_time|$cmd|$local_port|$forward_type|$remote_port|$remote_host" >>"$results_file"
        fi
    done <"$temp_file"

    # If we found SSH tunnels, display them in a nice table
    if [ -s "$results_file" ]; then
        # Use terminal width if available, otherwise default to 100 columns
        local term_width
        if command -v tput &>/dev/null; then
            term_width=$(tput cols)
        else
            term_width=100
        fi

        # Print a nice header with box-drawing characters
        echo "┌──────────┬──────────┬────────────────────┬────────────────────┬────────────────────┬──────────┬────────────────────┬────────────────────┬────────────────────┐"
        # Color the header with shell::colored_echo
        shell::colored_echo "│ PID      │ USER     │ START              │ TIME               │ COMMAND            │ L.PORT   │ FORWARD_TYPE        │ REMOTE_PORT        │ REMOTE_HOST        │" 33
        echo "├──────────┼──────────┼────────────────────┼────────────────────┼────────────────────┼──────────┼────────────────────┼────────────────────┼────────────────────┤"

        # Print each line of results with nice formatting
        while IFS='|' read -r pid user start_time elapsed_time cmd local_port forward_type remote_port remote_host; do
            # Truncate fields if necessary to fit the fixed column width
            pid=$(printf "%-8s" "${pid:0:8}")
            user=$(printf "%-8s" "${user:0:8}")
            start_time=$(printf "%-18s" "${start_time:0:18}")
            elapsed_time=$(printf "%-18s" "${elapsed_time:0:18}")
            cmd=$(printf "%-18s" "${cmd:0:18}")
            local_port=$(printf "%-8s" "${local_port:0:8}")
            forward_type=$(printf "%-18s" "${forward_type:0:18}")
            remote_port=$(printf "%-18s" "${remote_port:0:18}")
            remote_host=$(printf "%-18s" "${remote_host:0:18}")

            # Print the row
            echo "│ $pid │ $user │ $start_time │ $elapsed_time │ $cmd │ $local_port │ $forward_type │ $remote_port │ $remote_host │"
        done <"$results_file"

        # Close the table
        echo "└──────────┴──────────┴────────────────────┴────────────────────┴────────────────────┴──────────┴────────────────────┴────────────────────┴────────────────────┘"
    fi

    # Alternative output formatting method using simple columns
    if [ -s "$results_file" ]; then
        # Print header with background color if supported
        echo ""
        shell::colored_echo "PID        USER       START                TIME                 COMMAND              LOCAL_PORT  FORWARD_TYPE         REMOTE_PORT         REMOTE_HOST" 33
        echo "---------- ---------- -------------------- -------------------- -------------------- ---------- -------------------- -------------------- --------------------"

        # Print each line of results with nice formatting
        while IFS='|' read -r pid user start_time elapsed_time cmd local_port forward_type remote_port remote_host; do
            # Pad fields to fixed width
            printf "%-10s %-10s %-20s %-20s %-20s %-10s %-20s %-20s %-20s\n" \
                "$pid" "$user" "$start_time" "$elapsed_time" "$cmd" "$local_port" "$forward_type" "$remote_port" "$remote_host"
        done <"$results_file"
        echo ""
    fi

    # Clean up
    rm -f "$temp_file" "$results_file"
}
