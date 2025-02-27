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

    # Capture the OS type output from get_os_type
    local os_type
    os_type=$(get_os_type)

    # Set appropriate color based on OS
    local color_code=36 # Default cyan
    if [ "$os_type" = "linux" ]; then
        color_code=34 # Blue for Linux
    elif [ "$os_type" = "macos" ]; then
        color_code=32 # Green for macOS
    fi

    # Print the command with OS-appropriate emoji
    local emoji="🔍"
    if [ "$os_type" = "linux" ]; then
        emoji="🐧" # Penguin for Linux
    elif [ "$os_type" = "macos" ]; then
        emoji="🍎" # Apple for macOS
    fi

    colored_echo "$emoji $command" $color_code
    # Execute the command without using eval
    "$@"
}

# run_cmd_eval function
# Execute a command using eval and print it for logging purposes.
#
# Usage:
#   run_cmd_eval <command>
#
# Parameters:
#   - <command>: The command to be executed (as a single string).
#
# Description:
#   The 'run_cmd_eval' function executes a command by passing it to the `eval` command.
#   This allows the execution of complex commands with arguments, pipes, or redirection
#   that are difficult to handle with standard execution.
#   It logs the command before execution to provide visibility into what is being run.
#
# Options:
#   None
#
# Example usage:
#   run_cmd_eval "ls -l | grep txt"
#
# Instructions:
#   1. Use 'run_cmd_eval' when executing commands that require interpretation by the shell.
#   2. It is particularly useful for running dynamically constructed commands or those with special characters.
#
# Notes:
#   - The use of `eval` can be risky if the input command contains untrusted data, as it can lead to
#     command injection vulnerabilities. Ensure the command is sanitized before using this function.
#   - Prefer the 'wsd_exe_cmd' function for simpler commands without special characters or pipes.
function run_cmd_eval() {
    local command="$*"
    # Capture the OS type output from get_os_type
    local os_type
    os_type=$(get_os_type)

    # Set appropriate color based on OS
    local color_code=36 # Default cyan
    if [ "$os_type" = "linux" ]; then
        color_code=34 # Blue for Linux
    elif [ "$os_type" = "macos" ]; then
        color_code=32 # Green for macOS
    fi

    # Print the command with OS-appropriate emoji
    local emoji="🔍"
    if [ "$os_type" = "linux" ]; then
        emoji="🐧" # Penguin for Linux
    elif [ "$os_type" = "macos" ]; then
        emoji="🍎" # Apple for macOS
    fi

    colored_echo "$emoji $command" $color_code
    eval "$command"
}

# is_command_available function
# Check if a command is available in the system's PATH.
#
# Usage:
#   is_command_available <command>
#
# Parameters:
#   - <command>: The command to check
#
# Returns:
#   0 if the command is available, 1 otherwise
#
# Example usage:
#   if is_command_available git; then
#     echo "Git is installed"
#   else
#     echo "Git is not installed"
#   fi
function is_command_available() {
    command -v "$1" &>/dev/null
    return $?
}

# install_package function
# Cross-platform package installation function that works on both macOS and Linux.
#
# Usage:
#   install_package <package_name>
#
# Parameters:
#   - <package_name>: The name of the package to install
#
# Example usage:
#   install_package git
function install_package() {
    local package="$1"

    local os_type
    os_type=$(get_os_type)

    if [ "$os_type" = "linux" ]; then # Linux
        # Check if the package is already installed on Linux.
        if is_package_installed_linux "$package"; then
            colored_echo "🟡 $package is already installed. Skipping." 33
            return 0
        fi

        if is_command_available apt-get; then
            run_cmd_eval "sudo apt-get update && sudo apt-get install -y $package"
        elif is_command_available yum; then
            run_cmd_eval "sudo yum install -y $package"
        elif is_command_available dnf; then
            run_cmd_eval "sudo dnf install -y $package"
        else
            colored_echo "🔴 Error: Unsupported package manager on Linux." 31
            return 1
        fi
    elif [ "$os_type" = "macos" ]; then # macOS
        if ! is_command_available brew; then
            colored_echo "Homebrew is not installed. Installing Homebrew..." 33
            install_homebrew
        fi
        # Check if the package is already installed by Homebrew; skip if installed.
        if brew list --versions "$package" >/dev/null 2>&1; then
            colored_echo "🟡 $package is already installed. Skipping." 32
            return 0
        fi
        run_cmd_eval "brew install $package"
    else
        colored_echo "🔴 Error: Unsupported operating system." 31
        return 1
    fi
}

# uninstall_package function
# Cross-platform package uninstallation function for macOS and Linux.
#
# Usage:
#   uninstall_package <package_name>
#
# Parameters:
#   - <package_name>: The name of the package to uninstall
#
# Example usage:
#   uninstall_package git
uninstall_package() {
    local package="$1"
    local os_type
    os_type=$(get_os_type)

    if [ "$os_type" = "linux" ]; then
        if is_command_available apt-get; then
            if is_package_installed_linux "$package"; then
                run_cmd_eval "sudo apt-get remove -y $package"
            else
                colored_echo "🟡 $package is not installed. Skipping uninstallation." 33
            fi
        elif is_command_available yum; then
            if rpm -q "$package" >/dev/null 2>&1; then
                run_cmd_eval "sudo yum remove -y $package"
            else
                colored_echo "🟡 $package is not installed. Skipping uninstallation." 33
            fi
        elif is_command_available dnf; then
            if rpm -q "$package" >/dev/null 2>&1; then
                run_cmd_eval "sudo dnf remove -y $package"
            else
                colored_echo "🟡 $package is not installed. Skipping uninstallation." 33
            fi
        else
            colored_echo "🔴 Error: Unsupported package manager on Linux." 31
            return 1
        fi
    elif [ "$os_type" = "macos" ]; then
        if is_command_available brew; then
            if brew list --versions "$package" >/dev/null 2>&1; then
                run_cmd_eval "brew uninstall $package"
            else
                colored_echo "🟡 $package is not installed. Skipping uninstallation." 33
            fi
        else
            colored_echo "🔴 Error: Homebrew is not installed on macOS." 31
            return 1
        fi
    else
        colored_echo "🔴 Error: Unsupported operating system." 31
        return 1
    fi
}

# list_installed_packages function
# Lists all packages currently installed on Linux or macOS.
#
# Usage:
#   list_installed_packages
#
# Description:
#   On Linux:
#     - If apt-get is available, it uses dpkg to list installed packages.
#     - If yum or dnf is available, it uses rpm to list installed packages.
#   On macOS:
#     - If Homebrew is available, it lists installed Homebrew packages.
#
# Example usage:
#   list_installed_packages
list_installed_packages() {
    local os_type
    os_type=$(get_os_type)

    if [ "$os_type" = "linux" ]; then
        if is_command_available apt-get; then
            colored_echo "Listing installed packages (APT/Debian-based):" 34
            run_cmd_eval dpkg -l
        elif is_command_available yum || is_command_available dnf; then
            colored_echo "Listing installed packages (RPM-based):" 34
            run_cmd_eval rpm -qa | sort
        else
            colored_echo "🔴 Error: Unsupported package manager on Linux." 31
            return 1
        fi
    elif [ "$os_type" = "macos" ]; then
        if is_command_available brew; then
            colored_echo "Listing installed packages (Homebrew):" 32
            run_cmd_eval brew list
        else
            colored_echo "🔴 Error: Homebrew is not installed on macOS." 31
            return 1
        fi
    else
        colored_echo "🔴 Error: Unsupported operating system." 31
        return 1
    fi
}

# list_path_installed_packages function
# Lists all packages installed via directory-based package installation on Linux or macOS,
# along with their installation paths.
#
# Usage:
#   list_path_installed_packages [base_install_path]
#
# Parameters:
#   - [base_install_path]: Optional. The base directory where packages are installed.
#         Defaults to:
#           - /usr/local on macOS
#           - /opt on Linux
#
# Example usage:
#   list_path_installed_packages
#   list_path_installed_packages /custom/install/path
list_path_installed_packages() {
    local base_path="$1"
    local os_type
    os_type=$(get_os_type)

    # Set default installation directory if not provided.
    if [ -z "$base_path" ]; then
        if [ "$os_type" = "macos" ]; then
            base_path="/usr/local"
        elif [ "$os_type" = "linux" ]; then
            base_path="/opt"
        else
            colored_echo "🔴 Error: Unsupported operating system for package path listing." 31
            return 1
        fi
    fi

    # Verify the base installation directory exists.
    if [ ! -d "$base_path" ]; then
        colored_echo "🔴 Error: The specified installation path '$base_path' does not exist." 31
        return 1
    fi

    colored_echo "Listing packages installed in: $base_path" 36
    # List only directories (assumed to be package folders) at one level below base_path.
    find "$base_path" -maxdepth 1 -mindepth 1 -type d | sort | while read -r package_dir; do
        local package_name
        package_name=$(basename "$package_dir")
        colored_echo "📦 Package: $package_name 👉 Path: $package_dir"
    done
}

# list_path_installed_packages_details function
# Lists detailed information (including full path, directory size, and modification date)
# for all packages installed via directory-based methods on Linux or macOS.
#
# Usage:
#   list_path_installed_packages_details [base_install_path]
#
# Parameters:
#   - [base_install_path]: Optional. The base directory where packages are installed.
#         Defaults to:
#           - /usr/local on macOS
#           - /opt on Linux
#
# Example usage:
#   list_path_installed_packages_details
#   list_path_installed_packages_details /custom/install/path
list_path_installed_packages_details() {
    local base_path="$1"
    local os_type
    os_type=$(get_os_type)

    # Set default base path if none is provided.
    if [ -z "$base_path" ]; then
        if [ "$os_type" = "macos" ]; then
            base_path="/usr/local"
        elif [ "$os_type" = "linux" ]; then
            base_path="/opt"
        else
            colored_echo "🔴 Error: Unsupported operating system for package details listing." 31
            return 1
        fi
    fi

    # Verify that the base installation directory exists.
    if [ ! -d "$base_path" ]; then
        colored_echo "🔴 Error: The specified installation path '$base_path' does not exist." 31
        return 1
    fi

    colored_echo "Listing details of packages installed in: $base_path" 36

    # Use find to list only subdirectories (assumed to be package folders)
    find "$base_path" -maxdepth 1 -mindepth 1 -type d | sort | while IFS= read -r package_dir; do
        local package_name
        package_name=$(basename "$package_dir")
        local details

        # Get detailed information using stat, with different formatting for Linux and macOS.
        if [ "$os_type" = "linux" ]; then
            # Linux: %n for name, %s for size, %y for last modification date.
            details=$(stat -c "👉 Path: %n, Size: %s bytes, Modified: %y" "$package_dir")
        elif [ "$os_type" = "macos" ]; then
            # macOS: %N for name, %z for size, %Sm for last modification date.
            details=$(stat -f "👉 Path: %N, Size: %z bytes, Modified: %Sm" "$package_dir")
        else
            details="Unsupported OS for detailed stat."
        fi

        echo "----------------------------------------"
        echo "📦 Package: $package_name"
        echo "$details"
    done
}

# is_package_installed_linux function
# Checks if a package is installed on Linux.
#
# Usage:
#   is_package_installed_linux <package_name>
#
# Parameters:
#   - <package_name>: The name of the package to check
#
# Returns:
#   0 if the package is installed, 1 otherwise.
is_package_installed_linux() {
    local package="$1"

    if is_command_available apt-get; then
        # Debian-based: Check using dpkg.
        dpkg -s "$package" >/dev/null 2>&1
    elif is_command_available rpm; then
        # RPM-based: Check using rpm query.
        rpm -q "$package" >/dev/null 2>&1
    else
        colored_echo "🔴 Error: Unsupported package manager for Linux." 31
        return 1
    fi
}

###############################################################################
# create_directory_if_not_exists function
###############################################################################
# Utility function to create a directory (including nested directories) if it
# doesn't exist.
#
# Usage:
#   create_directory_if_not_exists <directory_path>
#
# Parameters:
#   <directory_path> : The path of the directory to be created.
#
# Description:
#   This function checks if the specified directory exists. If it does not,
#   it creates the directory (including any necessary parent directories) using
#   sudo to ensure proper privileges.
#
# Example:
#   create_directory_if_not_exists /path/to/nested/directory
function create_directory_if_not_exists() {
    if [ $# -lt 1 ]; then
        echo "Usage: create_directory_if_not_exists <directory_path>"
        return 1
    fi

    local dir="$1"
    local os
    os=$(get_os_type)

    # On macOS, if the provided path is not absolute, assume it's relative to $HOME.
    if [[ "$os" == "macos" ]]; then
        if [[ "$dir" != /* ]]; then
            dir="$HOME/$dir"
        fi
    fi

    # Check if the directory exists.
    if [ ! -d "$dir" ]; then
        colored_echo "📁 Directory '$dir' does not exist. Creating the directory (including nested directories) with admin privileges..." 33
        run_cmd_eval 'sudo mkdir -p "$dir"' # Use sudo to create the directory and its parent directories.
        if [ $? -eq 0 ]; then
            colored_echo "🟢 Directory created successfully." 46
            return 0
        else
            colored_echo "🔴 Error: Failed to create the directory." 196
            return 1
        fi
    else
        colored_echo "🟢 Directory '$dir' already exists." 46
    fi
}
