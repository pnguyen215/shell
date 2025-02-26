#!/bin/bash
# common.sh

# get_os_type function
# Determines the current operating system type and outputs a standardized string.
#
# Outputs:
#   "linux"    - For Linux-based systems
#   "macos"    - For macOS/Darwin systems
#   "windows"  - For Windows-like environments (CYGWIN, MINGW, MSYS)
#   "unknown"  - For unrecognized operating systems
#
# Example usage:
# os_type=$(get_os_type)
# case "$os_type" in
#   "linux")
#     echo "Linux system detected"
#     ;;
#   "macos")
#     echo "macOS system detected"
#     ;;
#   "windows")
#     echo "Windows environment detected"
#     ;;
#   *)
#     echo "Unrecognized system"
#     ;;
# esac
get_os_type() {
    local os_name
    os_name=$(uname -s | tr '[:upper:]' '[:lower:]')

    case "$os_name" in
    linux*)
        echo "linux"
        ;;
    darwin*)
        echo "macos"
        ;;
    cygwin* | mingw* | msys*)
        echo "windows"
        ;;
    *)
        # Additional check for WSL (Windows Subsystem for Linux)
        if [[ $(uname -r) == *microsoft* ]]; then
            echo "windows"
        else
            echo "unknown"
        fi
        ;;
    esac
}

# colored_echo function
# Prints text to the terminal with customizable colors using `tput` and ANSI escape sequences.
#
# Usage:
#   colored_echo <message> [color_code]
#
# Parameters:
#   - <message>: The text message to display.
#   - [color_code]: (Optional) A number from 0 to 255 representing the text color.
#       - 0-15: Standard colors (Black, Red, Green, etc.)
#       - 16-231: Extended 6x6x6 color cube
#       - 232-255: Grayscale shades
#
# Description:
#   The `colored_echo` function prints a message in bold and a specific color, if a valid color code is provided.
#   It uses ANSI escape sequences for 256-color support. If no color code is specified, it defaults to blue (code 4).
#
# Options:
#   None
#
# Example usage:
#   colored_echo "Hello, World!"          # Prints in default blue (code 4).
#   colored_echo "Error occurred" 196     # Prints in bright red.
#   colored_echo "Task completed" 46      # Prints in vibrant green.
#   colored_echo "Shades of gray" 245     # Prints in a mid-gray shade.
#
# Notes:
#   - Requires a terminal with 256-color support.
#   - Use ANSI color codes for finer control over colors.
colored_echo() {
    local message=$1
    local color_code=${2:-4} # Default to blue (ANSI color code 4)

    # Validate color code range (0 to 255)
    if [[ $color_code -lt 0 || $color_code -gt 255 ]]; then
        echo "🔴 Invalid color code! Please provide a number between 0 and 255."
        return 1
    fi

    # Check terminal capabilities
    local has_color_support=true

    # Check if terminal supports colors
    if ! command -v tput &>/dev/null || [[ $(tput colors 2>/dev/null || echo 0) -lt 8 ]]; then
        has_color_support=false
    fi

    if $has_color_support; then
        # Use 256-color support if available
        if [[ $(tput colors 2>/dev/null || echo 0) -ge 256 ]]; then
            local color="\033[38;5;${color_code}m" # Foreground 256-color ANSI code
            local bold="\033[1m"                   # Bold text attribute
            local reset="\033[0m"                  # Reset all attributes
            echo -e "${bold}${color}${message}${reset}"
        else
            # Fall back to basic 8 colors for limited terminals
            # Map 256-color code to basic color (simplified mapping)
            local basic_color=$((color_code % 8))
            local bold="\033[1m"
            local color="\033[3${basic_color}m"
            local reset="\033[0m"
            echo -e "${bold}${color}${message}${reset}"
        fi
    else
        # No color support detected, print plain text
        echo "${message}"
    fi
}

# run_cmd function
# Executes a command and prints it for logging purposes.
#
# Usage:
#   run_cmd <command>
#
# Parameters:
#   - <command>: The command to be executed.
#
# Description:
#   The `run_cmd` function prints the command for logging before executing it.
#
# Options:
#   None
#
# Example usage:
#   run_cmd ls -l
#
# Instructions:
#   1. Use `run_cmd` to execute a command.
#   2. The command will be printed before execution for logging.
#
# Notes:
#   - This function is useful for logging commands prior to execution.
run_cmd() {
    local command="$*"

    # Use detect_kernel to determine OS-specific behavior
    get_os_type
    local os_type=$?

    # Set appropriate color based on OS
    local color_code=36 # Default cyan
    if [ $os_type -eq "linux" ]; then
        # Linux - use blue
        color_code=34
    elif [ $os_type -eq "macos" ]; then
        # macOS - use green
        color_code=32
    fi

    # Print the command with OS-appropriate emoji
    local emoji="🔍"
    if [ $os_type -eq 1 ]; then
        emoji="🐧" # Penguin for Linux
    elif [ $os_type -eq 2 ]; then
        emoji="🍎" # Apple for macOS
    fi

    color_echo "$emoji $command" $color_code
    # Execute the command without using eval
    "$@"
}
