#!/bin/bash
# common.sh

# shell::get_os_type function
# Determines the current operating system type and outputs a standardized string.
#
# Outputs:
#   "linux"    - For Linux-based systems
#   "macos"    - For macOS/Darwin systems
#   "windows"  - For Windows-like environments (CYGWIN, MINGW, MSYS)
#   "unknown"  - For unrecognized operating systems
#
# Example usage:
# os_type=$(shell::get_os_type)
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
shell::get_os_type() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GET_OS_TYPE"
        return 0
    fi

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

# shell::colored_echo function
# Prints text to the terminal with customizable colors using `tput` and ANSI escape sequences.
#
# Usage:
#   shell::colored_echo <message> [color_code]
#
# Parameters:
#   - <message>: The text message to display.
#   - [color_code]: (Optional) A number from 0 to 255 representing the text color.
#       - 0-15: Standard colors (Black, Red, Green, etc.)
#       - 16-231: Extended 6x6x6 color cube
#       - 232-255: Grayscale shades
#
# Description:
#   The `shell::colored_echo` function prints a message in bold and a specific color, if a valid color code is provided.
#   It uses ANSI escape sequences for 256-color support. If no color code is specified, it defaults to blue (code 4).
#
# Options:
#   None
#
# Example usage:
#   shell::colored_echo "Hello, World!"          # Prints in default blue (code 4).
#   shell::colored_echo "Error occurred" 196     # Prints in bright red.
#   shell::colored_echo "Task completed" 46      # Prints in vibrant green.
#   shell::colored_echo "Shades of gray" 245     # Prints in a mid-gray shade.
#
# Notes:
#   - Requires a terminal with 256-color support.
#   - Use ANSI color codes for finer control over colors.
# shell::colored_echo() {
#     if [ "$1" = "-h" ]; then
#         echo "$USAGE_SHELL_COLORED_ECHO"
#         return 0
#     fi

#     local message=$1
#     local color_code=${2:-4} # Default to blue (ANSI color code 4)

#     # Validate color code range (0 to 255)
#     if [[ $color_code -lt 0 || $color_code -gt 255 ]]; then
#         echo "ERR: Invalid color code! Please provide a number between 0 and 255."
#         return 1
#     fi

#     # Check terminal capabilities
#     local has_color_support=true

#     # Check if terminal supports colors
#     if ! command -v tput &>/dev/null || [[ $(tput colors 2>/dev/null || echo 0) -lt 8 ]]; then
#         has_color_support=false
#     fi

#     if $has_color_support; then
#         # Use 256-color support if available
#         if [[ $(tput colors 2>/dev/null || echo 0) -ge 256 ]]; then
#             local color="\033[38;5;${color_code}m" # Foreground 256-color ANSI code
#             local bold="\033[1m"                   # Bold text attribute
#             local reset="\033[0m"                  # Reset all attributes
#             echo -e "${bold}${color}${message}${reset}"
#         else
#             # Fall back to basic 8 colors for limited terminals
#             # Map 256-color code to basic color (simplified mapping)
#             local basic_color=$((color_code % 8))
#             local bold="\033[1m"
#             local color="\033[3${basic_color}m"
#             local reset="\033[0m"
#             echo -e "${bold}${color}${message}${reset}"
#         fi
#     else
#         # No color support detected, print plain text
#         echo "${message}"
#     fi
# }

# shell::colored_echo function
# Prints text to the terminal with customizable colors using `tput` and ANSI escape sequences.
# Supports special characters and escape sequences commonly used in terminal environments.
#
# Usage:
# shell::colored_echo <message> [color_code] [options]
#
# Parameters:
# - <message>: The text message to display (supports escape sequences).
# - [color_code]: (Optional) A number from 0 to 255 representing the text color.
# - 0-15: Standard colors (Black, Red, Green, etc.)
# - 16-231: Extended 6x6x6 color cube
# - 232-255: Grayscale shades
# - [options]: (Optional) Additional flags for formatting control
#
# Options:
# -n: Do not output the trailing newline
# -e: Enable interpretation of backslash escapes (default behavior)
# -E: Disable interpretation of backslash escapes
#
# Description:
# The `shell::colored_echo` function prints a message in bold and a specific color, if a valid color code is provided.
# It uses ANSI escape sequences for 256-color support. If no color code is specified, it defaults to blue (code 4).
# The function supports common escape sequences like \n, \t, \r, \b, \a, \v, \f, and Unicode sequences.
#
# Supported Escape Sequences:
# \n - newline
# \t - horizontal tab
# \r - carriage return
# \b - backspace
# \a - alert (bell)
# \v - vertical tab
# \f - form feed
# \\ - literal backslash
# \" - literal double quote
# \' - literal single quote
# \xHH - hexadecimal escape sequence (e.g., \x41 for 'A')
# \uHHHH - Unicode escape sequence (e.g., \u03B1 for α)
# \UHHHHHHHH - Unicode escape sequence (32-bit)
#
# Example usage:
# shell::colored_echo "Hello, World!" # Prints in default blue (code 4).
# shell::colored_echo "Error occurred" 196 # Prints in bright red.
# shell::colored_echo "Task completed" 46 # Prints in vibrant green.
# shell::colored_echo "Line 1\nLine 2\tTabbed" 202 # Multi-line with tab
# shell::colored_echo "Bell sound\a" 226 # With bell character
# shell::colored_echo "Unicode: \u2713 \u2717" 118 # With Unicode check mark and X
# shell::colored_echo "Hex: \x48\x65\x6C\x6C\x6F" 93 # "Hello" in hex
# shell::colored_echo "No newline" 45 -n # Without trailing newline
# shell::colored_echo "Raw \t text" 120 -E # Disable escape interpretation
#
# Notes:
# - Requires a terminal with 256-color support for full color range.
# - Use ANSI color codes for finer control over colors.
# - The function automatically detects terminal capabilities and adjusts output accordingly.
# - Special characters are interpreted by default (equivalent to echo -e).
shell::colored_echo() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_COLORED_ECHO"
        return 0
    fi

    local message="$1"
    local color_code="${2:-4}" # Default to blue (ANSI color code 4)
    local enable_escapes=true
    local suppress_newline=false
    local shift_count=2

    # Parse additional options
    shift 2 2>/dev/null || shift $# # Shift past message and color_code
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -n)
            suppress_newline=true
            shift
            ;;
        -e)
            enable_escapes=true
            shift
            ;;
        -E)
            enable_escapes=false
            shift
            ;;
        *)
            # Unknown option, ignore
            shift
            ;;
        esac
    done

    # Validate color code range (0 to 255)
    if [[ ! "$color_code" =~ ^[0-9]+$ ]] || [[ $color_code -lt 0 || $color_code -gt 255 ]]; then
        echo "ERR: Invalid color code! Please provide a number between 0 and 255."
        return 1
    fi

    # Check terminal capabilities
    local has_color_support=true
    # Check if terminal supports colors
    if ! command -v tput &>/dev/null || [[ $(tput colors 2>/dev/null || echo 0) -lt 8 ]]; then
        has_color_support=false
    fi

    # Prepare echo options
    local echo_opts=""
    if $enable_escapes; then
        echo_opts="-e"
    fi
    if $suppress_newline; then
        echo_opts="$echo_opts -n"
    fi

    if $has_color_support; then
        # Use 256-color support if available
        if [[ $(tput colors 2>/dev/null || echo 0) -ge 256 ]]; then
            local color="\033[38;5;${color_code}m" # Foreground 256-color ANSI code
            local bold="\033[1m"                   # Bold text attribute
            local reset="\033[0m"                  # Reset all attributes
            echo $echo_opts "${bold}${color}${message}${reset}"
        else
            # Fall back to basic 8 colors for limited terminals
            # Map 256-color code to basic color (simplified mapping)
            local basic_color=$((color_code % 8))
            local bold="\033[1m"
            local color="\033[3${basic_color}m"
            local reset="\033[0m"
            echo $echo_opts "${bold}${color}${message}${reset}"
        fi
    else
        # No color support detected, print plain text
        if $enable_escapes; then
            if $suppress_newline; then
                echo -en "${message}"
            else
                echo -e "${message}"
            fi
        else
            if $suppress_newline; then
                echo -n "${message}"
            else
                echo "${message}"
            fi
        fi
    fi
}

# shell::run_cmd function
# Executes a command and prints it for logging purposes.
#
# Usage:
#   shell::run_cmd <command>
#
# Parameters:
#   - <command>: The command to be executed.
#
# Description:
#   The `shell::run_cmd` function prints the command for logging before executing it.
#
# Options:
#   None
#
# Example usage:
#   shell::run_cmd ls -l
#
# Instructions:
#   1. Use `shell::run_cmd` to execute a command.
#   2. The command will be printed before execution for logging.
#
# Notes:
#   - This function is useful for logging commands prior to execution.
shell::run_cmd() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_RUN_CMD"
        return 0
    fi

    local command="$*"

    # Capture the OS type output from shell::get_os_type
    local os_type
    os_type=$(shell::get_os_type)

    # Set appropriate color based on OS
    local color_code=36 # Default cyan
    if [ "$os_type" = "linux" ]; then
        color_code=34 # Blue for Linux
    elif [ "$os_type" = "macos" ]; then
        color_code=51 # Green for macOS
    fi

    # Print the command with OS-appropriate emoji
    local emoji="[em]"
    if [ "$os_type" = "linux" ]; then
        emoji="[v]" # Penguin for Linux
    elif [ "$os_type" = "macos" ]; then
        emoji="[v]" # Apple for macOS
    fi

    shell::colored_echo "$emoji $command" $color_code
    # Execute the command without using eval
    "$@"
}

# shell::run_cmd_eval function
# Execute a command using eval and print it for logging purposes.
#
# Usage:
#   shell::run_cmd_eval <command>
#
# Parameters:
#   - <command>: The command to be executed (as a single string).
#
# Description:
#   The 'shell::run_cmd_eval' function executes a command by passing it to the `eval` command.
#   This allows the execution of complex commands with arguments, pipes, or redirection
#   that are difficult to handle with standard execution.
#   It logs the command before execution to provide visibility into what is being run.
#
# Options:
#   None
#
# Example usage:
#   shell::run_cmd_eval "ls -l | grep txt"
#
# Instructions:
#   1. Use 'shell::run_cmd_eval' when executing commands that require interpretation by the shell.
#   2. It is particularly useful for running dynamically constructed commands or those with special characters.
#
# Notes:
#   - The use of `eval` can be risky if the input command contains untrusted data, as it can lead to
#     command injection vulnerabilities. Ensure the command is sanitized before using this function.
#   - Prefer the 'wsd_exe_cmd' function for simpler commands without special characters or pipes.
shell::run_cmd_eval() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_RUN_CMD_EVAL"
        return 0
    fi

    local command="$*"
    # Capture the OS type output from shell::get_os_type
    local os_type
    os_type=$(shell::get_os_type)

    # Set appropriate color based on OS
    local color_code=36 # Default cyan
    if [ "$os_type" = "linux" ]; then
        color_code=34 # Blue for Linux
    elif [ "$os_type" = "macos" ]; then
        color_code=51 # Green for macOS
    fi

    # Print the command with OS-appropriate emoji
    local emoji="[em]"
    if [ "$os_type" = "linux" ]; then
        emoji="[v]" # Penguin for Linux
    elif [ "$os_type" = "macos" ]; then
        emoji="[v]" # Apple for macOS
    fi

    shell::colored_echo "$emoji $command" $color_code
    eval "$command"
}

# shell::run_cmd_outlet function
# Executes a given command using the shell's eval function.
#
# Usage:
#   shell::run_cmd_outlet <command>
#
# Parameters:
#   - <command>: The command to be executed.
#
# Description:
#   This function takes a command as input and executes it using eval.
#   It is designed to handle commands that may require shell interpretation.
#   The function also checks for a help flag (-h) and displays usage information if present.
#
# Example usage:
#   shell::run_cmd_outlet "ls -l"
#
# Notes:
#   - The use of eval can be risky if the input command contains untrusted data,
#     as it can lead to command injection vulnerabilities. Ensure the command is
#     sanitized before using this function.
shell::run_cmd_outlet() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_RUN_CMD_OUTLET"
        return 0
    fi

    local command="$*"
    eval "$command"
}

# shell::is_command_available function
# Check if a command is available in the system's PATH.
#
# Usage:
#   shell::is_command_available <command>
#
# Parameters:
#   - <command>: The command to check
#
# Returns:
#   0 if the command is available, 1 otherwise
#
# Example usage:
#   if shell::is_command_available git; then
#     echo "Git is installed"
#   else
#     echo "Git is not installed"
#   fi
shell::is_command_available() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_IS_COMMAND_AVAILABLE"
        return 0
    fi

    command -v "$1" &>/dev/null
    return $?
}

# shell::install_package function
# Cross-platform package installation function that works on both macOS and Linux.
#
# Usage:
#   shell::install_package <package_name>
#
# Parameters:
#   - <package_name>: The name of the package to install
#
# Example usage:
#   shell::install_package git
shell::install_package() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_INSTALL_PACKAGE"
        return 0
    fi

    local package="$1"
    if [ -z "$package" ]; then
        shell::colored_echo "ERR: No package name provided." 196
        return 1
    fi

    local os_type
    os_type=$(shell::get_os_type)

    if [ "$os_type" = "linux" ]; then # Linux
        # Check if the package is already installed on Linux.
        if shell::is_package_installed_linux "$package"; then
            shell::colored_echo "[x] $package is already installed. Skipping." 244
            return 0
        fi

        # Check for snapcraft and try to install via snap first
        if shell::is_command_available snap; then
            if shell::run_cmd_eval "sudo snap install $package" 2>/dev/null; then
                shell::colored_echo "[v] Successfully installed $package via snap." 46
                return 0
            else
                shell::colored_echo "WARN: Snap installation failed or package not available in snap store. Trying traditional package managers..." 33
            fi
        fi

        # Fallback to traditional package managers
        if shell::is_command_available apt-get; then
            shell::run_cmd_eval "sudo apt-get update && sudo apt-get install -y $package"
        elif shell::is_command_available yum; then
            shell::run_cmd_eval "sudo yum install -y $package"
        elif shell::is_command_available dnf; then
            shell::run_cmd_eval "sudo dnf install -y $package"
        else
            shell::colored_echo "ERR: Unsupported package manager on Linux." 196
            return 1
        fi
    elif [ "$os_type" = "macos" ]; then # macOS
        if ! shell::is_command_available brew; then
            shell::colored_echo "Homebrew is not installed. Installing Homebrew..." 33
            shell::install_homebrew
        fi
        # Check if the package is already installed by Homebrew; skip if installed.
        if brew list --versions "$package" >/dev/null 2>&1; then
            shell::colored_echo "[x] $package is already installed. Skipping." 244
            return 0
        fi
        shell::run_cmd_eval "brew install $package"
    else
        shell::colored_echo "ERR: Unsupported operating system." 196
        return 1
    fi
}

# shell::remove_package function
# Cross-platform package uninstallation function for macOS and Linux.
#
# Usage:
#   shell::remove_package <package_name>
#
# Parameters:
#   - <package_name>: The name of the package to uninstall
#
# Example usage:
#   shell::remove_package git
shell::remove_package() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_REMOVE_PACKAGE"
        return 0
    fi

    local package="$1"
    local os_type
    os_type=$(shell::get_os_type)

    if [ "$os_type" = "linux" ]; then
        # Check if package is installed via snap and remove it
        if shell::is_command_available snap; then
            if snap list "$package" >/dev/null 2>&1; then
                shell::run_cmd_eval "sudo snap remove $package"
                return $?
            fi
        fi

        # Check if the package is installed via traditional package managers
        if shell::is_command_available apt-get; then
            if shell::is_package_installed_linux "$package"; then
                shell::run_cmd_eval "sudo apt-get remove -y $package"
            else
                shell::colored_echo "WARN: $package is not installed. Skipping uninstallation." 33
            fi
        elif shell::is_command_available yum; then
            if rpm -q "$package" >/dev/null 2>&1; then
                shell::run_cmd_eval "sudo yum remove -y $package"
            else
                shell::colored_echo "WARN: $package is not installed. Skipping uninstallation." 33
            fi
        elif shell::is_command_available dnf; then
            if rpm -q "$package" >/dev/null 2>&1; then
                shell::run_cmd_eval "sudo dnf remove -y $package"
            else
                shell::colored_echo "WARN: $package is not installed. Skipping uninstallation." 33
            fi
        else
            shell::colored_echo "ERR: Unsupported package manager on Linux." 196
            return 1
        fi
    elif [ "$os_type" = "macos" ]; then
        if shell::is_command_available brew; then
            if brew list --versions "$package" >/dev/null 2>&1; then
                shell::run_cmd_eval "brew uninstall $package"
            else
                shell::colored_echo "WARN: $package is not installed. Skipping uninstallation." 33
            fi
        else
            shell::colored_echo "ERR: Homebrew is not installed on macOS." 196
            return 1
        fi
    else
        shell::colored_echo "ERR: Unsupported operating system." 196
        return 1
    fi
}

# shell::list_packages_installed function
# Lists all packages currently installed on Linux or macOS.
#
# Usage:
#   shell::list_packages_installed
#
# Description:
#   On Linux:
#     - If apt-get is available, it uses dpkg to list installed packages.
#     - If yum or dnf is available, it uses rpm to list installed packages.
#   On macOS:
#     - If Homebrew is available, it lists installed Homebrew packages.
#
# Example usage:
#   shell::list_packages_installed
shell::list_packages_installed() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_LIST_PACKAGES_INSTALLED"
        return 0
    fi

    local os_type
    os_type=$(shell::get_os_type)

    if [ "$os_type" = "linux" ]; then
        if shell::is_command_available apt-get; then
            shell::colored_echo "Listing installed packages (APT/Debian-based):" 34
            shell::run_cmd_eval dpkg -l
        elif shell::is_command_available yum || shell::is_command_available dnf; then
            shell::colored_echo "Listing installed packages (RPM-based):" 34
            shell::run_cmd_eval rpm -qa | sort
        else
            shell::colored_echo "ERR: Unsupported package manager on Linux." 196
            return 1
        fi
    elif [ "$os_type" = "macos" ]; then
        if shell::is_command_available brew; then
            shell::colored_echo "Listing installed packages (Homebrew):" 32
            shell::run_cmd_eval brew list
        else
            shell::colored_echo "ERR: Homebrew is not installed on macOS." 196
            return 1
        fi
    else
        shell::colored_echo "ERR: Unsupported operating system." 196
        return 1
    fi
}

# shell::is_package_installed_linux function
# Checks if a package is installed on Linux.
#
# Usage:
#   shell::is_package_installed_linux <package_name>
#
# Parameters:
#   - <package_name>: The name of the package to check
#
# Returns:
#   0 if the package is installed, 1 otherwise.
shell::is_package_installed_linux() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_IS_PACKAGE_INSTALLED_LINUX"
        return 0
    fi

    local package="$1"
    if [ -z "$package" ]; then
        shell::colored_echo "ERR: No package name provided." 196
        return 1
    fi

    # Check if package is installed via snap
    if shell::is_command_available snap; then
        if snap list "$package" >/dev/null 2>&1; then
            return 0
        fi
    fi

    # Check traditional package managers
    if shell::is_command_available apt-get; then
        # Debian-based: Check using dpkg.
        dpkg -s "$package" >/dev/null 2>&1
    elif shell::is_command_available rpm; then
        # RPM-based: Check using rpm query.
        rpm -q "$package" >/dev/null 2>&1
    else
        shell::colored_echo "ERR: Unsupported package manager for Linux." 196
        return 1
    fi
}

# shell::create_directory_if_not_exists function
# Utility function to create a directory (including nested directories) if it
# doesn't exist.
#
# Usage:
#   shell::create_directory_if_not_exists <directory_path>
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
#   shell::create_directory_if_not_exists /path/to/nested/directory
shell::create_directory_if_not_exists() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_CREATE_DIRECTORY_IF_NOT_EXISTS"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::create_directory_if_not_exists <directory_path>"
        return 1
    fi

    local dir="$1"
    local os
    os=$(shell::get_os_type)

    # On macOS, if the provided path is not absolute, assume it's relative to $HOME.
    if [[ "$os" == "macos" ]]; then
        if [[ "$dir" != /* ]]; then
            dir="$HOME/$dir"
        fi
    fi

    # Check if the directory exists.
    if [ ! -d "$dir" ]; then
        shell::colored_echo "WARN: Directory '$dir' does not exist. Creating the directory (including nested directories) with admin privileges..." 11
        shell::run_cmd_eval 'sudo mkdir -p "$dir"' # Use sudo to create the directory and its parent directories.
        if [ $? -eq 0 ]; then
            shell::colored_echo "INFO: Directory created successfully." 46
            shell::unlock_permissions "$dir"
            return 0
        else
            shell::colored_echo "ERR: Failed to create the directory." 196
            return 1
        fi
    else
        shell::colored_echo "INFO: Directory '$dir' already exists." 46
    fi
}

# shell::create_file_if_not_exists function
# Utility function to create a file if it doesn't exist, ensuring all parent directories are created.
#
# Usage:
#   shell::create_file_if_not_exists <filename>
#
# Parameters:
#   - <filename>: The name (or path) of the file to be created. Can be relative or absolute.
#
# Description:
#   This function converts the provided filename to an absolute path based on the current working directory
#   if it is not already absolute. It then extracts the parent directory path and ensures it exists,
#   creating it with admin privileges using `sudo mkdir -p` if necessary. Finally, it creates the file
#   using `sudo touch` if it does not already exist. Optional permission settings for the directory
#   and file are included but commented out.
#
# Example usage:
#   shell::create_file_if_not_exists ./demo/sub/text.txt   # Creates all necessary directories and the file relative to the current directory.
#   shell::create_file_if_not_exists /absolute/path/to/file.txt
shell::create_file_if_not_exists() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_CREATE_FILE_IF_NOT_EXISTS"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::create_file_if_not_exists <filename>"
        return 1
    fi

    local filename="$1"
    local abs_filename

    # Convert filename to absolute path
    if [[ "$filename" = /* ]]; then
        abs_filename="$filename"
    else
        abs_filename="$PWD/$filename"
    fi

    local directory
    directory="$(dirname "$abs_filename")"

    # Check if the parent directory exists.
    if [ ! -d "$directory" ]; then
        shell::colored_echo "WARN: Creating directory '$directory'..." 11
        shell::run_cmd_eval "sudo mkdir -p \"$directory\""
        if [ $? -eq 0 ]; then
            shell::colored_echo "INFO: Directory created successfully." 46
            # Optionally set directory permissions
            shell::unlock_permissions "$directory" # # shell::run_cmd_eval "sudo chmod 700 \"$directory\""
        else
            shell::colored_echo "ERR: Failed to create the directory." 196
            return 1
        fi
    fi

    # Check if the file exists.
    if [ ! -e "$abs_filename" ]; then
        shell::colored_echo "WARN: Creating file '$abs_filename'..." 11
        shell::run_cmd_eval "sudo touch \"$abs_filename\""
        if [ $? -eq 0 ]; then
            shell::colored_echo "INFO: File created successfully." 46
            # Optionally set file permissions
            shell::unlock_permissions "$abs_filename" # shell::run_cmd_eval "sudo chmod 600 \"$abs_filename\""
            return 0
        else
            shell::colored_echo "ERR: Failed to create the file." 196
            return 1
        fi
    fi
    return 0
}

# shell::clip_cwd function
# Copies the current directory path to the clipboard.
#
# Usage:
#   shell::clip_cwd
#
# Description:
#   The 'shell::clip_cwd' function copies the current directory path to the clipboard using the 'pbcopy' command.
shell::clip_cwd() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_CLIP_CWD"
        return 0
    fi

    local adr="$PWD"
    local os
    os=$(shell::get_os_type)

    if [[ "$os" == "macos" ]]; then
        echo -n "$adr" | pbcopy
        shell::colored_echo "DEBUG: Path copied to clipboard using pbcopy" 244
    elif [[ "$os" == "linux" ]]; then
        if shell::is_command_available xclip; then
            echo -n "$adr" | xclip -selection clipboard
            shell::colored_echo "DEBUG: Path copied to clipboard using xclip" 244
        elif shell::is_command_available xsel; then
            echo -n "$adr" | xsel --clipboard --input
            shell::colored_echo "DEBUG: Path copied to clipboard using xsel" 244
        else
            shell::colored_echo "ERR: Clipboard tool not found. Please install xclip or xsel." 196
            return 1
        fi
    else
        shell::colored_echo "ERR: Clipboard copying not supported on this OS." 196
        return 1
    fi
}

# shell::clip_value function
# Copies the provided text value into the system clipboard.
#
# Usage:
#   shell::clip_value <text>
#
# Parameters:
#   <text> - The text string or value to copy to the clipboard.
#
# Description:
#   This function first checks if a value has been provided. It then determines the current operating
#   system using the shell::get_os_type function. On macOS, it uses pbcopy to copy the value to the clipboard.
#   On Linux, it first checks if xclip is available and uses it; if not, it falls back to xsel.
#   If no clipboard tool is found or the OS is unsupported, an error message is displayed.
#
# Dependencies:
#   - shell::get_os_type: To detect the operating system.
#   - shell::is_command_available: To check for the availability of xclip or xsel on Linux.
#   - shell::colored_echo: To print colored status messages.
#
# Example:
#   shell::clip_value "Hello, World!"
shell::clip_value() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_CLIP_VALUE"
        return 0
    fi

    local value="$1"
    if [[ -z "$value" ]]; then
        shell::colored_echo "ERR: No value provided to copy." 196
        return 1
    fi

    local os
    os=$(shell::get_os_type)

    if [[ "$os" == "macos" ]]; then
        echo -n "$value" | pbcopy
        shell::colored_echo "DEBUG: Value copied to clipboard using pbcopy." 244
    elif [[ "$os" == "linux" ]]; then
        if shell::is_command_available xclip; then
            echo -n "$value" | xclip -selection clipboard
            shell::colored_echo "DEBUG: Value copied to clipboard using xclip." 244
        elif shell::is_command_available xsel; then
            echo -n "$value" | xsel --clipboard --input
            shell::colored_echo "DEBUG: Value copied to clipboard using xsel." 244
        else
            shell::colored_echo "ERR: Clipboard tool not found. Please install xclip or xsel." 196
            return 1
        fi
    else
        shell::colored_echo "ERR: Clipboard copying not supported on this OS." 196
        return 1
    fi
}

# shell::get_temp_dir function
# Returns the appropriate temporary directory based on the detected kernel.
#
# Usage:
#   shell::get_temp_dir
#
# Returns:
#   The path to the temporary directory for the current operating system.
#
# Example usage:
#   TEMP_DIR=$(shell::get_temp_dir)
#   echo "Using temporary directory: $TEMP_DIR"
shell::get_temp_dir() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GET_TEMP_DIR"
        return 0
    fi

    shell::get_os_type
    local os=$?

    if [ "$os" = "linux" ]; then # Linux
        echo "/tmp"
    elif [ "$os" = "macos" ]; then # macOS
        echo "/private/tmp"
    else
        # Fallback to a common temporary directory
        echo "/tmp"
    fi
}

# shell::on_evict function
# Hook to print a command without executing it.
#
# Usage:
#   shell::on_evict <command>
#
# Parameters:
#   - <command>: The command to be printed.
#
# Description:
#   The 'shell::on_evict' function prints a command without executing it.
#   It is designed as a hook for logging or displaying commands without actual execution.
#
# Example usage:
#   shell::on_evict ls -l
#
# Instructions:
#   1. Use 'shell::on_evict' to print a command without executing it.
#
# Notes:
#   - This function is useful for displaying commands in logs or hooks without execution.
shell::on_evict() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ON_EVICT"
        return 0
    fi

    local command="$*"
    shell::colored_echo "[prev] $command" 49
    shell::clip_value "$command"
}

# shell::check_port function
# Checks if a specific TCP port is in use (listening).
#
# Usage:
#   shell::check_port <port> [-n]
#
# Parameters:
#   - <port> : The TCP port number to check.
#   - -n     : Optional flag to enable dry-run mode (prints the command without executing it).
#
# Description:
#   This function uses lsof to determine if any process is actively listening on the specified TCP port.
#   It filters the output for lines containing "LISTEN", which indicates that the port is in use.
#   When the dry-run flag (-n) is provided, the command is printed using shell::on_evict instead of being executed.
#
# Example:
#   shell::check_port 8080        # Executes the command.
#   shell::check_port 8080 -n     # Prints the command (dry-run mode) without executing it.
shell::check_port() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_CHECK_PORT"
        return 0
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::check_port <port> [-n]"
        return 1
    fi

    local port="$1"
    local dry_run="false"

    # Check if a dry-run flag (-n) is provided.
    if [ "$2" = "-n" ]; then
        dry_run="true"
    fi

    local cmd="lsof -nP -iTCP:\"$port\" | grep LISTEN"

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::run_cmd_eval "$cmd"
    fi
}

# shell::kill_port function
# Terminates all processes listening on the specified TCP port(s).
#
# Usage:
#   shell::kill_port [-n] <port> [<port> ...]
#
# Parameters:
#   - -n    : Optional flag to enable dry-run mode (print commands without execution).
#   - <port>: One or more TCP port numbers.
#
# Description:
#   This function checks each specified port to determine if any processes are listening on it,
#   using lsof. If any are found, it forcefully terminates them by sending SIGKILL (-9).
#   In dry-run mode (enabled by the -n flag), the kill command is printed using shell::on_evict instead of executed.
#
# Example:
#   shell::kill_port 8080              # Kills processes on port 8080.
#   shell::kill_port -n 8080 3000       # Prints the kill commands for ports 8080 and 3000 without executing.
#
# Notes:
#   - Ensure you have the required privileges to kill processes.
#   - Use with caution, as forcefully terminating processes may cause data loss.
shell::kill_port() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_KILL_PORT"
        return 0
    fi

    local dry_run="false"

    # Check for the dry-run flag.
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_KILL_PORT"
        return 0
    fi

    if [ "$#" -eq 0 ]; then
        shell::colored_echo "WARN: No ports specified. Usage: shell::kill_port [-n] PORT [PORT...]" 11
        return 1
    fi

    for port in "$@"; do
        # Find PIDs of processes listening on the specified port.
        local pids
        pids=$(lsof -ti :"$port")

        if [ -n "$pids" ]; then
            shell::colored_echo "INFO: Processing port $port with PIDs: $pids" 46
            for pid in $pids; do
                # Construct the kill command as an array to reuse it for both shell::on_evict and shell::run_cmd.
                local cmd=("kill" "-9" "$pid")
                # local cmd="kill -9 $pid"
                if [ "$dry_run" = "true" ]; then
                    # shell::on_evict "$cmd"
                    shell::on_evict "${cmd[*]}"
                else
                    # shell::run_cmd kill -9 "$pid"
                    shell::run_cmd "${cmd[@]}"
                fi
            done
        else
            shell::colored_echo "WARN: No processes found on port $port" 11
        fi
    done
}

# shell::copy_files function
# Copies a source file to one or more destination filenames in the current working directory.
#
# Usage:
#   shell::copy_files [-n] <source_filename> <new_filename1> [<new_filename2> ...]
#
# Parameters:
#   - -n             : Optional dry-run flag. If provided, the command will be printed using shell::on_evict instead of executed.
#   - <source_filename> : The file to copy.
#   - <new_filenameX>   : One or more new filenames (within the current working directory) where the source file will be copied.
#
# Description:
#   The function first checks for a dry-run flag (-n). It then verifies that at least two arguments remain.
#   For each destination filename, it checks if the file already exists in the current working directory.
#   If not, it builds the command to copy the source file (using sudo) to the destination.
#   In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.
#
# Example:
#   shell::copy_files myfile.txt newfile.txt            # Copies myfile.txt to newfile.txt.
#   shell::copy_files -n myfile.txt newfile1.txt newfile2.txt  # Prints the copy commands without executing them.
shell::copy_files() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_COPY_FILES"
        return 0
    fi

    local dry_run="false"

    # Check for the optional dry-run flag (-n).
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_COPY_FILES"
        return 0
    fi

    if [ $# -lt 2 ]; then
        echo "Usage: shell::copy_files [-n] <source_filename> <new_filename1> [<new_filename2> ...]"
        return 1
    fi

    local source="$1"
    shift # Remove the source file from the arguments.
    local destination="$PWD"

    for filename in "$@"; do
        local destination_file="$destination/$filename"

        if [ -e "$destination_file" ]; then
            shell::colored_echo "ERR: Destination file '$filename' already exists." 196
            continue
        fi

        # Build the copy command.
        local cmd="sudo cp \"$source\" \"$destination_file\""
        if [ "$dry_run" = "true" ]; then
            shell::on_evict "$cmd"
        else
            shell::run_cmd_eval "$cmd"
            shell::colored_echo "INFO: File copied successfully to $destination_file" 46
        fi
    done
}

# shell::move_files function
# Moves one or more files to a destination folder.
#
# Usage:
#   shell::move_files [-n] <destination_folder> <file1> <file2> ... <fileN>
#
# Parameters:
#   - -n                  : Optional dry-run flag. If provided, the command will be printed using shell::on_evict instead of executed.
#   - <destination_folder>: The target directory where the files will be moved.
#   - <fileX>             : One or more source files to be moved.
#
# Description:
#   The function first checks for an optional dry-run flag (-n). It then verifies that the destination folder exists.
#   For each source file provided:
#     - It checks whether the source file exists.
#     - It verifies that the destination file (using the basename of the source) does not already exist in the destination folder.
#     - It builds the command to move the file (using sudo mv).
#   In dry-run mode, the command is printed using shell::on_evict; otherwise, the command is executed using shell::run_cmd.
#   If an error occurs for a particular file (e.g., missing source or destination file conflict), the error is logged and the function continues with the next file.
#
# Example:
#   shell::move_files /path/to/dest file1.txt file2.txt              # Moves file1.txt and file2.txt to /path/to/dest.
#   shell::move_files -n /path/to/dest file1.txt file2.txt             # Prints the move commands without executing them.
shell::move_files() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_MOVE_FILES"
        return 0
    fi

    local dry_run="false"

    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -lt 2 ]; then
        echo "Usage: shell::move_files [-n] <destination_folder> <file1> <file2> ... <fileN>"
        return 1
    fi

    local destination_folder="$1"
    shift

    if [ ! -d "$destination_folder" ]; then
        shell::colored_echo "ERR: Destination folder '$destination_folder' does not exist." 196
        return 1
    fi

    for source in "$@"; do
        if [ ! -e "$source" ]; then
            shell::colored_echo "ERR: Source file '$source' does not exist." 196
            continue
        fi

        local destination="$destination_folder/$(basename "$source")"

        if [ -e "$destination" ]; then
            shell::colored_echo "ERR: Destination file '$destination' already exists." 196
            continue
        fi

        local cmd="sudo mv \"$source\" \"$destination\""
        if [ "$dry_run" = "true" ]; then
            shell::on_evict "$cmd"
        else
            shell::run_cmd sudo mv "$source" "$destination"
            if [ $? -eq 0 ]; then
                shell::colored_echo "INFO: File '$source' moved successfully to $destination" 46
            else
                shell::colored_echo "ERR: moving file '$source'." 196
            fi
        fi
    done
}

# shell::remove_files function
# Removes a file or directory using sudo rm -rf.
#
# Usage:
#   shell::remove_files [-n] <filename/dir>
#
# Parameters:
#   - -n           : Optional dry-run flag. If provided, the command will be printed using shell::on_evict instead of executed.
#   - <filename/dir>: The file or directory to remove.
#
# Description:
#   The function first checks for an optional dry-run flag (-n). It then verifies that a target argument is provided.
#   It builds the command to remove the specified target using "sudo rm -rf".
#   In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd.
#
# Example:
#   shell::remove_files my-dir          # Removes the directory 'my-dir'.
#   shell::remove_files -n myfile.txt  # Prints the removal command without executing it.
shell::remove_files() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_REMOVE_FILES"
        return 0
    fi

    local dry_run="false"

    # Check for the optional dry-run flag (-n).
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ -z "$1" ]; then
        echo "Usage: shell::remove_files [-n] <filename/dir>"
        return 1
    fi

    local target="$1"
    local cmd="sudo rm -rf \"$target\""

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::run_cmd sudo rm -rf "$target"
    fi
}

# shell::editor function
# Open a selected file from a specified folder using a chosen text editor.
#
# Usage:
#   shell::editor [-n] <folder>
#
# Parameters:
#   - -n       : Optional dry-run flag. If provided, the command will be printed using shell::on_evict instead of executed.
#   - <folder> : The directory containing the files you want to edit.
#
# Description:
#   The 'shell::editor' function provides an interactive way to select a file from the specified
#   folder and open it using a chosen text editor. It uses 'fzf' for fuzzy file and command selection.
#   The function supports a dry-run mode where the command is printed without execution.
#
# Supported Text Editors:
#   - cat
#   - less
#   - more
#   - vim
#   - nano
#
# Example:
#   shell::editor ~/documents          # Opens a file in the selected text editor.
#   shell::editor -n ~/documents       # Prints the command that would be used, without executing it.
#
# Requirements:
#   - fzf must be installed.
#   - Helper functions: shell::run_cmd, shell::on_evict, shell::colored_echo, and shell::get_os_type.
shell::editor() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_EDITOR"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::editor [-n] <folder>"
        return 1
    fi

    local folder="$1"
    if [ ! -d "$folder" ]; then
        shell::colored_echo "ERR: '$folder' is not a valid directory." 196
        return 1
    fi

    # Determine absolute path command based on OS.
    local os_type
    os_type=$(shell::get_os_type)
    local abs_command=()
    if [ "$os_type" = "macos" ]; then
        if command -v realpath >/dev/null 2>&1; then
            abs_command=(realpath)
        else
            abs_command=(echo) # Fallback: use echo (paths will remain relative)
        fi
    else
        abs_command=(readlink -f)
    fi

    # Get list of files with absolute paths.
    local file_list
    file_list=$(find "$folder" -type f -exec "${abs_command[@]}" {} \;)
    if [ -z "$file_list" ]; then
        shell::colored_echo "ERR: No files found in '$folder'." 196
        return 1
    fi

    # Use fzf to select a file.
    local selected_file
    selected_file=$(echo "$file_list" | fzf --prompt="Select a file: ")
    if [ -z "$selected_file" ]; then
        shell::colored_echo "ERR: No file selected." 196
        return 1
    fi

    # Use fzf to select the text editor command.
    local selected_command
    selected_command=$(echo "cat;less;more;vim;nano;remove;base64;clip-base64;path;clip;unlock;permissions;ex-permissions;mime-type" | tr ';' '\n' | fzf --prompt="Select an action: ")
    if [ -z "$selected_command" ]; then
        shell::colored_echo "ERR: No action selected." 196
        return 1
    fi

    # Check if the selected command is 'remove'.
    if [ "$selected_command" = "remove" ]; then
        if [ "$dry_run" = "true" ]; then
            shell::remove_files -n "$selected_file"
        else
            shell::remove_files "$selected_file"
        fi
        if [ $? -eq 0 ]; then
            shell::colored_echo "INFO: File '$selected_file' removed successfully." 46
            return 0
        else
            shell::colored_echo "ERR: Failed to remove file '$selected_file'." 196
            return 1
        fi
    fi

    # Check if the selected command is 'base64'.
    if [ "$selected_command" = "base64" ]; then
        if [ "$dry_run" = "true" ]; then
            shell::encode_base64_file -n "$selected_file"
        else
            shell::encode_base64_file "$selected_file"
        fi
        if [ $? -eq 0 ]; then
            shell::colored_echo "INFO: File '$selected_file' encoded base64 successfully." 46
            return 0
        else
            shell::colored_echo "ERR: Failed to encode file '$selected_file'." 196
            return 1
        fi
    fi

    # Check if the selected command is 'clip-base64'.
    if [ "$selected_command" = "clip-base64" ]; then
        local base64_value
        local base64_cmd
        if [ "$os_type" = "macos" ]; then
            base64_cmd="base64 -i \"$selected_file\""
        else
            base64_cmd="base64 -w 0 \"$selected_file\""
        fi
        base64_value=$(eval "$base64_cmd")
        if [ -z "$base64_value" ]; then
            shell::colored_echo "ERR: Failed to encode file '$selected_file' to base64." 196
            return 1
        fi
        shell::clip_value "$base64_value"
        if [ $? -eq 0 ]; then
            shell::colored_echo "INFO: Base64 value of '$selected_file' copied to clipboard." 46
            return 0
        else
            shell::colored_echo "ERR: Failed to copy base64 value to clipboard." 196
            return 1
        fi
    fi

    # Check if the selected command is 'path'.
    if [ "$selected_command" = "path" ]; then
        shell::clip_value "$selected_file"
        return 0
    fi

    # Check if the selected command is 'clip'.
    if [ "$selected_command" = "clip" ]; then
        local clip_value
        clip_value=$(cat "$selected_file")
        shell::clip_value "$clip_value"
        return 0
    fi

    # Check if the selected command is 'unlock'.
    if [ "$selected_command" = "unlock" ]; then
    if [ "$dry_run" = "true" ]; then
            shell::unlock_permissions -n "$selected_file"
        else
            shell::unlock_permissions "$selected_file"
        fi
        if [ $? -eq 0 ]; then
            shell::colored_echo "INFO: Permissions for '$selected_file' unlocked successfully." 46
            return 0
        else
            shell::colored_echo "ERR: Failed to unlock permissions for '$selected_file'." 196
            return 1
        fi
    fi

    # Check if the selected command is 'permissions'.
    if [ "$selected_command" = "permissions" ]; then
        if [ "$dry_run" = "true" ]; then
            shell::fzf_set_permissions -n "$selected_file"
        else
            shell::fzf_set_permissions "$selected_file"
        fi
        if [ $? -eq 0 ]; then
            shell::colored_echo "INFO: Permissions for '$selected_file' upgraded successfully." 46
            return 0
        else
            shell::colored_echo "ERR: Failed to upgrade permissions for '$selected_file'." 196
            return 1
        fi
    fi

    # Check if the selected command is 'ex-permissions'.
    if [ "$selected_command" = "ex-permissions" ]; then
        if [ "$dry_run" = "true" ]; then
            shell::analyze_permissions --file "$selected_file" --debug
        else
            shell::analyze_permissions --file "$selected_file"
        fi
        if [ $? -eq 0 ]; then
            shell::colored_echo "INFO: Permissions for '$selected_file' analyzed successfully." 46
            return 0
        else
            shell::colored_echo "ERR: Failed to analyze permissions for '$selected_file'." 196
            return 1
        fi
    fi

    # Check if the selected command is 'mine-type'.
    if [ "$selected_command" = "mime-type" ]; then
        local mime_type
        mime_type=$(shell::get_mime_type "$selected_file")
        if [ -z "$mime_type" ]; then
            shell::colored_echo "ERR: Failed to determine MIME type for '$selected_file'." 196
            return 1
        fi
        shell::colored_echo "INFO: MIME type of '$selected_file': $mime_type" 46
        return 0
    fi

    # Build the command string.
    local cmd="$selected_command \"$selected_file\""
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::run_cmd $selected_command "$selected_file"
    fi
}

# shell::download_dataset function
# Downloads a dataset file from a provided download link.
#
# Usage:
#   shell::download_dataset [-n] <filename_with_extension> <download_link>
#
# Parameters:
#   - -n                     : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - <filename_with_extension> : The target filename (with path) where the dataset will be saved.
#   - <download_link>         : The URL from which the dataset will be downloaded.
#
# Description:
#   This function downloads a file from a given URL and saves it under the specified filename.
#   It extracts the directory from the filename, ensures the directory exists, and changes to that directory
#   before attempting the download. If the file already exists, it prompts the user for confirmation before
#   overwriting it. In dry-run mode, the function uses shell::on_evict to display the commands without executing them.
#
# Example:
#   shell::download_dataset mydata.zip https://example.com/mydata.zip
#   shell::download_dataset -n mydata.zip https://example.com/mydata.zip  # Displays the commands without executing them.
shell::download_dataset() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_DOWNLOAD_DATASET"
        return 0
    fi

    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -ne 2 ]; then
        echo "Usage: shell::download_dataset [-n] <filename_with_extension> <download_link>"
        return 1
    fi

    local filename="$1"
    local link="$2"

    # Ensure the directory exists; create it if it doesn't
    shell::create_file_if_not_exists "$filename"

    local base="$filename"
    # Check if the file already exists
    if [ -e "$base" ]; then
        local confirm=""
        while [ -z "$confirm" ]; do
            echo -n "[q] Do you want to overwrite the existing file? (y/n): "
            read confirm
            if [ -z "$confirm" ]; then
                shell::colored_echo "ERR: Invalid input. Please enter y or n." 196
            fi
        done

        if [ "$confirm" != "y" ]; then
            shell::colored_echo "WARN: Download canceled. The file already exists." 11
            return 1
        fi

        # Remove the existing file before downloading (using shell::on_evict in dry-run mode)
        if [ "$dry_run" = "true" ]; then
            shell::on_evict "sudo rm \"$base\""
        else
            shell::run_cmd sudo rm "$base"
        fi
    fi

    # Return to the original directory
    cd - >/dev/null || return 1

    # Build the download command
    local download_cmd="curl -LJ \"$link\" -o \"$filename\""
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$download_cmd"
        shell::colored_echo "WARN: Dry-run mode: Displayed download command for $filename" 11
        return 0
    else
        shell::run_cmd curl -s -LJ "$link" -o "$filename"
        if [ $? -eq 0 ]; then
            shell::colored_echo "INFO: Successfully downloaded: $filename" 46
        else
            shell::colored_echo "ERR: Download failed for $link" 196
        fi
    fi
}

# shell::unarchive function
# Extracts a compressed file based on its file extension.
#
# Usage:
#   shell::unarchive [-n] <filename>
#
# Parameters:
#   - -n        : Optional dry-run flag. If provided, the extraction command is printed using shell::on_evict instead of executed.
#   - <filename>: The compressed file to extract.
#
# Description:
#   The function first checks for an optional dry-run flag (-n) and then verifies that exactly one argument (the filename) is provided.
#   It checks if the given file exists and, if so, determines the correct extraction command based on the file extension.
#   In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.
#
# Example:
#   shell::unarchive archive.tar.gz           # Extracts archive.tar.gz.
#   shell::unarchive -n archive.zip           # Prints the unzip command without executing it.
shell::unarchive() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_UNARCHIVE"
        return 0
    fi

    local dry_run="false"

    # Check for the optional dry-run flag (-n).
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -ne 1 ]; then
        echo "Usage: shell::unarchive [-n] <filename>"
        return 1
    fi

    local file="$1"

    if [ -f "$file" ]; then
        case "$file" in
        *.tar.bz2)
            local cmd="tar xvjf \"$file\""
            ;;
        *.tar.gz)
            local cmd="tar xvzf \"$file\""
            ;;
        *.bz2)
            local cmd="bunzip2 \"$file\""
            ;;
        *.rar)
            local cmd="unrar x \"$file\""
            ;;
        *.gz)
            local cmd="gunzip \"$file\""
            ;;
        *.tar)
            local cmd="tar xvf \"$file\""
            ;;
        *.tbz2)
            local cmd="tar xvjf \"$file\""
            ;;
        *.tgz)
            local cmd="tar xvzf \"$file\""
            ;;
        *.zip)
            local cmd="unzip \"$file\""
            ;;
        *.Z)
            local cmd="uncompress \"$file\""
            ;;
        *.7z)
            local cmd="7z x \"$file\""
            ;;
        *)
            shell::colored_echo "ERR: '$file' cannot be extracted via shell::unarchive()" 196
            return 1
            ;;
        esac

        if [ "$dry_run" = "true" ]; then
            shell::on_evict "$cmd"
        else
            shell::run_cmd_eval "$cmd"
        fi
    else
        shell::colored_echo "ERR: '$file' is not a valid file" 196
        return 1
    fi
}

# shell::list_high_mem_usage function
# Displays processes with high memory consumption.
#
# Usage:
#   shell::list_high_mem_usage [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#
# Description:
#   This function retrieves the operating system type using shell::get_os_type. For macOS, it uses 'top' to sort processes by resident size (RSIZE)
#   and filters the output to display processes consuming at least 100 MB. For Linux, it uses 'ps' to list processes sorted by memory usage.
#   In dry-run mode, the constructed command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.
#
# Example:
#   shell::list_high_mem_usage       # Displays processes with high memory consumption.
#   shell::list_high_mem_usage -n    # Prints the command without executing it.
shell::list_high_mem_usage() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_LIST_HIGH_MEM_USAGE"
        return 0
    fi

    # Determine the OS type using shell::get_os_type
    local os_type
    os_type=$(shell::get_os_type)

    local cmd=""
    if [ "$os_type" = "macos" ]; then
        # Build the command string for macOS
        cmd="top -o RSIZE -n 10 -l 1 | grep -E '^\s*[0-9]+ (root|[^r])' | awk '{if (\$3 >= 100) print \"PID: \" \$1 \", Application: \" \$2}'"
    elif [ "$os_type" = "linux" ]; then
        # Build the command string for Linux
        cmd="ps -axo pid,user,%mem,command --sort=-%mem | head -n 11 | tail -n +2"
    else
        shell::colored_echo "ERR: Unsupported OS for shell::list_high_mem_usage function." 196
        return 1
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::run_cmd_eval "$cmd"
    fi
}

# shell::open_link function
# Opens the specified URL in the default web browser.
#
# Usage:
#   shell::open_link [-n] <url>
#
# Parameters:
#   - -n   : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#   - <url>: The URL to open in the default web browser.
#
# Description:
#   This function determines the current operating system using shell::get_os_type. On macOS, it uses the 'open' command;
#   on Linux, it uses 'xdg-open' (if available). If the required command is missing on Linux, an error is displayed.
#   In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.
#
# Example:
#   shell::open_link https://example.com         # Opens the URL in the default browser.
#   shell::open_link -n https://example.com      # Prints the command without executing it.
shell::open_link() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n).
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_OPEN_LINK"
        return 0
    fi

    if [ -z "$1" ]; then
        echo "Usage: shell::open_link [-n] <url>"
        return 1
    fi

    local url="$1"
    local os_type
    os_type=$(shell::get_os_type)
    local cmd=""

    if [ "$os_type" = "macos" ]; then
        cmd="open \"$url\""
    elif [ "$os_type" = "linux" ]; then
        if shell::is_command_available xdg-open; then
            cmd="xdg-open \"$url\""
        else
            shell::colored_echo "ERR: xdg-open is not installed on Linux." 196
            return 1
        fi
    else
        shell::colored_echo "ERR: Unsupported OS for shell::open_link function." 196
        return 1
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::run_cmd_eval "$cmd"
    fi
}

# shell::loading_spinner function
# Displays a loading spinner in the console for a specified duration.
#
# Usage:
#   shell::loading_spinner [-n] [duration]
#
# Parameters:
#   - -n        : Optional dry-run flag. If provided, the spinner command is printed using shell::on_evict instead of executed.
#   - [duration]: Optional. The duration in seconds for which the spinner should be displayed. Default is 3 seconds.
#
# Description:
#   The function calculates an end time based on the provided duration and then iterates,
#   printing a sequence of spinner characters to create a visual loading effect.
#   In dry-run mode, it uses shell::on_evict to display a message indicating what would be executed,
#   without actually running the spinner.
#
# Example usage:
#   shell::loading_spinner          # Displays the spinner for 3 seconds.
#   shell::loading_spinner 10       # Displays the spinner for 10 seconds.
#   shell::loading_spinner -n 5     # Prints the spinner command for 5 seconds without executing it.
shell::loading_spinner() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_LOADING_SPINNER"
        return 0
    fi

    local duration="${1:-3}" # Default duration is 3 seconds
    local spinner="/-\|"
    local end_time=$((SECONDS + duration))

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "Display loading spinner for ${duration} seconds"
        return 0
    fi

    while [ $SECONDS -lt $end_time ]; do
        for i in $(seq 0 3); do
            echo -n "${spinner:$i:1}"
            sleep 0.1
            echo -ne "\b#"
        done
    done

    echo -e
}

# shell::measure_time function
# Measures the execution time of a command and displays the elapsed time.
#
# Usage:
#   shell::measure_time <command> [arguments...]
#
# Parameters:
#   - <command> [arguments...]: The command (with its arguments) to execute.
#
# Description:
#   This function captures the start time, executes the provided command, and then captures the end time.
#   It calculates the elapsed time in milliseconds and displays the result in seconds and milliseconds.
#   On macOS, if GNU date (gdate) is available, it is used for millisecond precision; otherwise, it falls back
#   to the built-in SECONDS variable (providing second-level precision). On Linux, it uses date +%s%3N.
#
# Example:
#   shell::measure_time sleep 2    # Executes 'sleep 2' and displays the execution time.
shell::measure_time() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_MEASURE_TIME"
        return 0
    fi

    local os_type
    os_type=$(shell::get_os_type)

    local exit_code

    if [ "$os_type" = "macos" ]; then
        if shell::is_command_available gdate; then
            local start_time
            start_time=$(gdate +%s%3N)
            "$@"
            exit_code=$?
            local end_time
            end_time=$(gdate +%s%3N)
            local elapsed=$((end_time - start_time))
            local seconds=$((elapsed / 1000))
            local milliseconds=$((elapsed % 1000))
            shell::colored_echo "Execution time: ${seconds}s ${milliseconds}ms" 33
            return $exit_code
        else
            # Fallback: use SECONDS (resolution in seconds)
            local start_seconds=$SECONDS
            "$@"
            exit_code=$?
            local end_seconds=$SECONDS
            local elapsed_seconds=$((end_seconds - start_seconds))
            shell::colored_echo "Execution time: ${elapsed_seconds}s" 33
            return $exit_code
        fi
    else
        # For Linux: use date with millisecond precision
        local start_time
        start_time=$(date +%s%3N)
        "$@"
        exit_code=$?
        local end_time
        end_time=$(date +%s%3N)
        local elapsed=$((end_time - start_time))
        local seconds=$((elapsed / 1000))
        local milliseconds=$((elapsed % 1000))
        shell::colored_echo "Execution time: ${seconds}s ${milliseconds}ms" 33
        return $exit_code
    fi
}

# shell::async function
# Executes a command or function asynchronously (in the background).
#
# Usage:
#   shell::async [-n] <command> [arguments...]
#
# Parameters:
#   - -n        : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#   - <command> [arguments...]: The command (or function) with its arguments to be executed asynchronously.
#
# Description:
#   The shell::async function builds the command from the provided arguments and runs it in the background.
#   If the optional dry-run flag (-n) is provided, the command is printed using shell::on_evict instead of executing it.
#   Otherwise, the command is executed asynchronously using eval, and the process ID (PID) is displayed.
#
# Example:
#   shell::async my_function arg1 arg2      # Executes my_function with arguments asynchronously.
#   shell::async -n ls -l                   # Prints the 'ls -l' command that would be executed in the background.
shell::async() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ASYNC"
        return 0
    fi

    local dry_run="false"

    # Check for the optional dry-run flag (-n).
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Build the command string from all arguments.
    local cmd="$*"

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd &"
        return 0
    else
        # Execute the command asynchronously (in the background)
        eval "$cmd" &
        local pid=$!
        shell::colored_echo "DEBUG: Async process started with PID: $pid" 244
        return 0
    fi
}

# shell::execute_or_evict function
# Executes a command or prints it based on dry-run mode.
#
# Usage:
#   shell::execute_or_evict <dry_run> <command>
#
# Parameters:
#   - <dry_run>: "true" to print the command, "false" to execute it.
#   - <command>: The command to execute or print.
#
# Example:
#   shell::execute_or_evict "true" "echo Hello"
shell::execute_or_evict() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_EXECUTE_OR_EVICT"
        return 0
    fi

    local dry_run="$1"
    local command="$2"
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$command"
    else
        shell::run_cmd_eval "$command"
    fi
}

# shell::ls function
# Lists files and folders in the current directory with a beautiful, easy-to-read layout.
#
# Usage:
#   shell::ls [-a] [-l] [-h] [--debug]
#
# Parameters:
#   - -a : Optional. Include hidden files and directories (similar to ls -a).
#   - -l : Optional. Use long format, showing permissions, size, and last modified date.
#   - -h : Optional. Displays this help message.
#   - --debug : Optional. Enables debug output to trace command execution.
#
# Description:
#   This function lists all files and folders in the current directory with a visually appealing layout.
#   It uses colors to differentiate file types (blue for directories, green for executables, white for regular files),
#   includes icons ([d] for directories, [f] for files, [e] for executables), and aligns output in a tabulated format.
#   The long format (-l) includes permissions, human-readable file size, and last modified date.
#   The function is compatible with both macOS and Linux, handling differences in ls and stat commands.
#
# Requirements:
#   - Standard tools: ls, stat, awk, column.
#   - Helper functions: shell::colored_echo, shell::get_os_type.
#
# Example usage:
#   shell::ls           # List files and folders in a simple, colored format.
#   shell::ls -a       # Include hidden files.
#   shell::ls -l       # Show detailed listing with permissions, size, and modified date.
#   shell::ls -a -l    # Show detailed listing including hidden files.
#   shell::ls --debug  # Enable debug output for troubleshooting.
#
# Returns:
#   0 on success, 1 on failure (e.g., current directory inaccessible).
#
# Notes:
#   - Colors are applied using ANSI codes via tput.
#   - File metadata is retrieved using stat, with OS-specific formats.
#   - Uses ls for listing, with proper argument handling via arrays.
shell::ls() {
    local show_hidden="false"
    local long_format="false"
    local debug="false"

    # Parse command-line options
    while [ $# -gt 0 ]; do
        case "$1" in
        -a) show_hidden="true" ;;
        -l) long_format="true" ;;
        -h)
            echo "Usage: shell::ls [-a] [-l] [-h] [--debug]"
            echo "  -a : Include hidden files and directories."
            echo "  -l : Use long format (permissions, size, modified date)."
            echo "  -h : Display this help message."
            echo "  --debug : Enable debug output."
            return 0
            ;;
        --debug) debug="true" ;;
        *)
            shell::colored_echo "ERR: Invalid option: $1. Usage: shell::ls [-a] [-l] [-h] [--debug]" 196
            return 1
            ;;
        esac
        shift
    done

    # Check if current directory is accessible and readable
    if ! pwd >/dev/null 2>&1; then
        shell::colored_echo "ERR: Cannot access current directory." 196
        return 1
    fi
    if ! [ -r . ]; then
        shell::colored_echo "ERR: No read permission for current directory." 196
        return 1
    fi

    # Define ANSI color codes using tput
    local blue=$(tput setaf 4)  # Blue for directories
    local green=$(tput setaf 2) # Green for executables
    local white=$(tput setaf 7) # White for regular files
    local normal=$(tput sgr0)   # Reset to normal

    # Temporary file to store formatted output
    local tmp_file
    tmp_file=$(mktemp) || {
        shell::colored_echo "ERR: Failed to create temporary file." 196
        return 1
    }
    trap 'rm -f "$tmp_file"' EXIT

    # Header for long format
    if [ "$long_format" = "true" ]; then
        echo "Type Permissions Size Modified Name" >"$tmp_file"
        echo "---- ---------- ---- -------- ----" >>"$tmp_file"
    fi

    # Set ls command as an array
    local ls_cmd=(/bin/ls -1)
    if [ "$show_hidden" = "true" ]; then
        ls_cmd=(/bin/ls -1A)
    fi

    [ "$debug" = "true" ] && echo "Running ls command: ${ls_cmd[*]}" >&2

    # Try listing with ls
    local ls_output
    if ! ls_output=$("${ls_cmd[@]}" 2>&1); then
        [ "$debug" = "true" ] && shell::colored_echo "ERR: ls failed: $ls_output" 196
        shell::colored_echo "ERR: Failed to list directory contents with ls." 196
        rm -f "$tmp_file"
        trap - EXIT
        return 1
    fi

    # Process each file
    local file_count=0
    while IFS= read -r file; do
        # Skip empty entries or . and .. when show_hidden is true
        [ -z "$file" ] && continue
        if [ "$show_hidden" = "true" ] && { [ "$file" = "." ] || [ "$file" = ".." ]; }; then
            continue
        fi

        [ "$debug" = "true" ] && echo "Processing file: $file" >&2

        # Determine file type and icon
        local icon="[f]"
        local color="$white"
        if [ -d "$file" ]; then
            icon="[d]"
            color="$blue"
        elif [ -x "$file" ] && [ ! -d "$file" ]; then
            icon="[e]"
            color="$green"
        fi

        if [ "$long_format" = "true" ]; then
            # Get file metadata
            local perms size modified
            local os_type
            os_type=$(shell::get_os_type)
            if [ "$os_type" = "macos" ]; then
                perms=$(stat -f "%Sp" "$file" 2>/dev/null || echo "-")
                size=$(stat -f "%z" "$file" 2>/dev/null | awk '{if ($1 < 1024) print $1 " B"; else if ($1 < 1048576) print sprintf("%.1f KB", $1/1024); else print sprintf("%.1f MB", $1/1048576)}')
                modified=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$file" 2>/dev/null || echo "-")
            else
                perms=$(stat --format="%A" "$file" 2>/dev/null || echo "-")
                size=$(stat --format="%s" "$file" 2>/dev/null | awk '{if ($1 < 1024) print $1 " B"; else if ($1 < 1048576) print sprintf("%.1f KB", $1/1024); else print sprintf("%.1f MB", $1/1048576)}')
                modified=$(stat --format="%y" "$file" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
            fi

            # Write formatted line to temporary file
            echo "$icon $perms $size $modified ${color}${file}${normal}" >>"$tmp_file"
        else
            # Simple format: just icon and file name
            echo "$icon ${color}${file}${normal}" >>"$tmp_file"
        fi
        ((file_count++))
    done <<<"$ls_output"

    # Check if any files were processed
    if [ $file_count -eq 0 ]; then
        shell::colored_echo "INFO: No files or directories found." 46
        rm -f "$tmp_file"
        trap - EXIT
        return 0
    fi

    # Display the output using column
    column -t "$tmp_file"

    # Clean up
    trap - EXIT
    rm -f "$tmp_file"
    return 0
}

# shell::set_permissions function
# Sets file or directory permissions using human-readable group syntax.
#
# Usage:
# shell::set_permissions [-n] <target> [owner=...] [group=...] [others=...]
#
# Description:
#   This function allows you to set permissions on a file or directory using a human-readable format.
#   It supports specifying permissions for the owner, group, and others using keywords like read, write, and execute.
#   The function constructs a chmod command based on the provided arguments and executes it.
#   If the -n flag is provided, it prints the command instead of executing it.
#   The function checks if the target exists and is accessible before attempting to change permissions.
#   It also validates the permission groups and provides error messages for invalid inputs.
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#   - <target> : The file or directory to set permissions on.
#   - [owner=...] : Optional. Set permissions for the owner (e.g., owner=read,write).
#   - [group=...] : Optional. Set permissions for the group (e.g., group=read,execute).
#   - [others=...] : Optional. Set permissions for others (e.g., others=read).
#
# Example:
# shell::set_permissions myfile.txt owner=read,write group=read others=read
# shell::set_permissions -n script.sh owner=read,write,execute group=read,execute others=none
shell::set_permissions() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_SET_PERMISSIONS"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -lt 2 ]; then
        echo "Usage: shell::set_permissions [-n] <target> [owner=...] [group=...] [others=...]"
        return 1
    fi

    local target="$1"
    shift

    if [ ! -e "$target" ]; then
        shell::colored_echo "ERR: Target '$target' does not exist." 196
        return 1
    fi

    # Owner, group, and others permissions initialized to 0
    # These variables will hold the numeric values for each permission group.
    local owner_perm="0"
    local group_perm="0"
    local others_perm="0"

    # Process each permission argument
    # This loop iterates over each argument provided after the target.
    # It extracts the entity (owner, group, others) and the permissions string,
    # calculates the corresponding numeric value, and assigns it to the appropriate variable.
    # The permissions are expected in the format: owner=..., group=..., others=...
    # Each permission string can include read, write, and execute keywords.
    # The function supports multiple permission groups and calculates the octal value for chmod.
    # It also handles errors for unknown permission groups and invalid formats.
    for arg in "$@"; do
        local entity="${arg%%=*}"
        local perms="${arg#*=}"
        local value=0

        [[ "$perms" =~ read ]] && ((value += 4))
        [[ "$perms" =~ write ]] && ((value += 2))
        [[ "$perms" =~ execute ]] && ((value += 1))

        case "$entity" in
        owner) owner_perm="$value" ;;
        group) group_perm="$value" ;;
        others) others_perm="$value" ;;
        *)
            shell::colored_echo "ERR: Unknown permission group '$entity'. Use owner=..., group=..., others=..." 196
            return 1
            ;;
        esac
    done

    local mode="${owner_perm}${group_perm}${others_perm}"
    local cmd="chmod $mode \"$target\""

    # If dry-mode is enabled, print the command instead of executing it
    # This allows for a dry-run to see what would happen without making changes.
    # This is useful for testing or when you want to ensure the command is correct before applying it.
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd"
    else
        shell::run_cmd_eval "$cmd"
        shell::colored_echo "INFO: Permissions set to $mode for '$target'" 46
    fi
}

# shell::unlock_permissions function
# Sets full permissions (read, write, and execute) for the specified file or directory.
#
# Usage:
#   shell::unlock_permissions [-n] <file/dir>
#
# Parameters:
#   - -n (optional): Dry-run mode. Instead of executing the command, prints it using shell::on_evict.
#   - <file/dir> : The path to the file or directory to modify.
#
# Description:
#   This function checks the current permission of the target. If it is already set to 777,
#   it logs a message and exits without making any changes.
#   Otherwise, it builds and executes (or prints, in dry-run mode) the chmod command asynchronously
#   to grant full permissions recursively.
#
# Example:
#   shell::unlock_permissions ./my_script.sh
#   shell::unlock_permissions -n ./my_script.sh  # Dry-run: prints the command without executing.
shell::unlock_permissions() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_UNLOCK_PERMISSIONS"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check if a target is provided
    # If no target is provided, print usage information and exit.
    if [ $# -lt 1 ]; then
        echo "Usage: shell::unlock_permissions [-n] <file/dir>"
        return 1
    fi

    # Check if the target exists
    # If the target does not exist, print an error message and exit.
    # If the target is a directory, it will be created if it does not exist.
    local target="$1"
    if [ ! -e "$target" ]; then
        shell::colored_echo "ERR: Target '$target' does not exist." 196
        return 1
    fi

    # Determine the current permission of the target
    # This is done using the `stat` command, which varies between macOS and Linux.
    # On macOS, use `stat -f "%Lp"`; on Linux, use `stat -c "%a"`.
    # The current permission is stored in the variable `current_perm`.
    # This will be used to check if the target already has 777 permissions.
    local current_perm=""
    local os_type
    os_type=$(shell::get_os_type)
    if [ "$os_type" = "macos" ]; then
        current_perm=$(stat -f "%Lp" "$target")
    else
        current_perm=$(stat -c "%a" "$target")
    fi

    # Build the chmod command to set full permissions (777) recursively.
    # This command will be executed asynchronously.
    local chmod_cmd="sudo chmod -R 777 \"$target\""

    # If dry-run mode is enabled, print the command instead of executing it.
    # If the target already has 777 permissions, skip execution.
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$chmod_cmd"
    else
        # If the current permission is not 777, execute the chmod command.
        if [ "$current_perm" -eq 777 ]; then
            return 0
        fi
        shell::run_cmd_eval "$chmod_cmd"
        shell::colored_echo "DEBUG: Permissions set to (read,write,execute) for '$target'" 244
        return 0
    fi
}

# shell::fzf_set_permissions function
# Interactively selects permissions for a file or directory using fzf and applies them via shell::set_permissions.
#
# Usage:
# shell::fzf_set_permissions [-n] <target>
#
# Parameters:
# - -n : Optional dry-run flag. If provided, the chmod command is printed using shell::on_evict instead of executed.
# - <target> : The file or directory to modify permissions for.
#
# Description:
# This function prompts the user to select permissions for owner, group, and others using fzf.
# It then delegates the permission setting to shell::set_permissions.
shell::fzf_set_permissions() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_FZF_SET_PERMISSIONS"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::fzf_set_permissions [-n] <target>"
        return 1
    fi

    local target="$1"
    if [ ! -e "$target" ]; then
        shell::colored_echo "ERR: Target '$target' does not exist." 196
        return 1
    fi

    # Ensure fzf is installed
    shell::install_package fzf

    # Define permission options
    # This array contains the different permission levels that can be selected.
    local perms=("none" "read" "write" "execute" "read,write" "read,execute" "write,execute" "read,write,execute")

    # Prompt user to select permissions for owner, group, and others
    # The user is prompted to select permissions for each category (owner, group, others) using fzf.
    # The selected permissions are stored in variables for later use.
    local owner=$(printf "%s\n" "${perms[@]}" | fzf --prompt="Select owner permissions: ")
    local group=$(printf "%s\n" "${perms[@]}" | fzf --prompt="Select group permissions: ")
    local others=$(printf "%s\n" "${perms[@]}" | fzf --prompt="Select others permissions: ")

    # Check if any permission selection is empty
    # If any of the selections are empty, an error message is displayed and the function exits.
    if [ -z "$owner" ] || [ -z "$group" ] || [ -z "$others" ]; then
        shell::colored_echo "ERR: Permission selection incomplete. Aborting." 196
        return 1
    fi

    # If dry-run mode is enabled, print the command instead of executing it
    # This allows the user to see what permissions would be set without actually changing them.
    # If dry_run is true, the command is printed using shell::on_evict.
    # Otherwise, the command is executed to set the permissions.
    if [ "$dry_run" = "true" ]; then
        shell::set_permissions "-n" "$target" "owner=$owner" "group=$group" "others=$others"
    else
        shell::set_permissions "$target" "owner=$owner" "group=$group" "others=$others"
    fi
}

# shell::analyze_permissions function
# Explains a file permission string (e.g., -rwxr-xr-x) in a human-readable way for developers.
#
# Usage:
#   shell::analyze_permissions [-h] [--file <path>] [--debug] [permission_string]
#
# Parameters:
#   - -h : Optional. Displays this help message.
#   - --file <path> : Optional. Use the permissions of the specified file.
#   - --debug : Optional. Enables debug output to trace execution.
#   - permission_string : Optional. A permission string (e.g., -rwxr-xr-x). If omitted and --file is not used, defaults to -rw-r--r--.
#
# Description:
#   This function parses a file permission string or extracts permissions from a file and explains them in a clear, professional manner.
#   It describes the file type (e.g., regular file, directory), permissions for owner, group, and others (read, write, execute),
#   and provides the octal equivalent (e.g., 644). The output includes developer-relevant context, such as implications for scripts,
#   security considerations, and common use cases (e.g., 755 for executables). The function is compatible with macOS and Linux.
#
# Requirements:
#   - Standard tools: stat, tput.
#   - Helper functions: shell::colored_echo, shell::get_os_type.
#
# Example usage:
#   shell::analyze_permissions -rwxr-xr-x       # Explain -rwxr-xr-x permissions.
#   shell::analyze_permissions --file script.sh # Explain permissions of script.sh.
#   shell::analyze_permissions -h               # Show help message.
#   shell::analyze_permissions --debug          # Explain default permissions with debug output.
#
# Returns:
#   0 on success, 1 on failure (e.g., invalid permission string, file not found).
#
# Notes:
#   - Colors are applied using tput for consistency with shell::colored_echo.
#   - Supports standard Unix permission strings (10 characters).
#   - Provides octal values for use with chmod.
shell::analyze_permissions() {
    local permission_string=""
    local file_path=""
    local debug="false"

    # Parse command-line options
    while [ $# -gt 0 ]; do
        case "$1" in
        -h)
            echo "Usage: shell::analyze_permissions [-h] [--file <path>] [--debug] [permission_string]"
            echo "  -h : Display this help message."
            echo "  --file <path> : Use permissions of the specified file."
            echo "  --debug : Enable debug output."
            echo "  permission_string : A permission string (e.g., -rwxr-xr-x). Defaults to -rw-r--r--."
            return 0
            ;;
        --file)
            if [ -z "$2" ]; then
                shell::colored_echo "ERR: --file requires a path." 196
                return 1
            fi
            file_path="$2"
            shift 2
            ;;
        --debug)
            debug="true"
            shift
            ;;
        *)
            if [ -n "$permission_string" ]; then
                shell::colored_echo "ERR: Multiple permission strings provided." 196
                return 1
            fi
            permission_string="$1"
            shift
            ;;
        esac
    done

    # If file_path is provided, get its permissions
    if [ -n "$file_path" ]; then
        if [ ! -e "$file_path" ]; then
            shell::colored_echo "ERR: File '$file_path' does not exist." 196
            return 1
        fi
        local os_type
        os_type=$(shell::get_os_type)
        if [ "$os_type" = "macos" ]; then
            permission_string=$(stat -f "%Sp" "$file_path" 2>/dev/null)
        else
            permission_string=$(stat --format="%A" "$file_path" 2>/dev/null)
        fi
        if [ -z "$permission_string" ]; then
            shell::colored_echo "ERR: Failed to get permissions for '$file_path'." 196
            return 1
        fi
        [ "$debug" = "true" ] && echo "Retrieved permissions: $permission_string" >&2
    fi

    # Default permission string if none provided
    if [ -z "$permission_string" ]; then
        permission_string="-rw-r--r--"
        [ "$debug" = "true" ] && echo "Using default permissions: $permission_string" >&2
    fi

    # Validate permission string (10 characters, valid format)
    if ! echo "$permission_string" | grep -Eq '^[-d]([-r][-w][-x]){3}$'; then
        shell::colored_echo "ERR: Invalid permission string '$permission_string'. Expected format like -rwxr-xr-x." 196
        return 1
    fi

    # Define ANSI color codes using tput
    local blue=$(tput setaf 4)   # Blue for emphasis
    local green=$(tput setaf 2)  # Green for permissions
    local yellow=$(tput setaf 3) # Yellow for octal
    local normal=$(tput sgr0)    # Reset to normal

    # Parse permission string
    local file_type=${permission_string:0:1}
    local owner_perms=${permission_string:1:3}
    local group_perms=${permission_string:4:3}
    local others_perms=${permission_string:7:3}

    # Describe file type
    local file_type_desc
    case "$file_type" in
    "-") file_type_desc="regular file" ;;
    "d") file_type_desc="directory" ;;
    *) file_type_desc="unknown type" ;; # Shouldn't occur due to validation
    esac

    # Convert permissions to human-readable
    local owner_desc=""
    [ "${owner_perms:0:1}" = "r" ] && owner_desc+="read, "
    [ "${owner_perms:1:1}" = "w" ] && owner_desc+="write, "
    [ "${owner_perms:2:1}" = "x" ] && owner_desc+="execute"
    owner_desc=${owner_desc%, } # Remove trailing comma
    [ -z "$owner_desc" ] && owner_desc="no permissions"

    local group_desc=""
    [ "${group_perms:0:1}" = "r" ] && group_desc+="read, "
    [ "${group_perms:1:1}" = "w" ] && group_desc+="write, "
    [ "${group_perms:2:1}" = "x" ] && group_desc+="execute"
    group_desc=${group_desc%, }
    [ -z "$group_desc" ] && group_desc="no permissions"

    local others_desc=""
    [ "${others_perms:0:1}" = "r" ] && others_desc+="read, "
    [ "${others_perms:1:1}" = "w" ] && others_desc+="write, "
    [ "${others_perms:2:1}" = "x" ] && others_desc+="execute"
    others_desc=${others_desc%, }
    [ -z "$others_desc" ] && others_desc="no permissions"

    # Calculate octal value
    local octal=0
    for perms in "$owner_perms" "$group_perms" "$others_perms"; do
        local value=0
        [ "${perms:0:1}" = "r" ] && ((value += 4))
        [ "${perms:1:1}" = "w" ] && ((value += 2))
        [ "${perms:2:1}" = "x" ] && ((value += 1))
        octal=$((octal * 8 + value))
    done
    octal=$(printf "%03d" "$octal") # Ensure 3 digits

    # Developer context
    local dev_context=""
    if [ "$permission_string" = "-rwxr-xr-x" ]; then
        dev_context="This is a common permission for executable scripts or binaries (octal 755). The owner can modify and run the file, while group members and others can read and execute it. Ideal for shared tools or scripts in a team environment, ensuring only the owner can edit."
    elif [ "$permission_string" = "-rw-r--r--" ]; then
        dev_context="This is typical for configuration files or source code (octal 644). The owner can edit the file, while group and others can only read it. Suitable for files in version control (e.g., Git) or server configs where read-only access is sufficient for most users."
    elif [ "${others_perms:1:1}" = "w" ]; then
        dev_context="Warning: Write permissions for 'others' can be a security risk, as any user can modify the file. Avoid this in production environments, especially for scripts or configs on shared servers."
    elif [ "$file_type" = "d" ] && [ "$owner_perms" = "rwx" ]; then
        dev_context="This directory allows the owner full control (read, write, execute). Execute permission is required to enter the directory or list its contents. Common for project directories where the owner manages all files."
    else
        dev_context="These permissions control file access in development workflows. Ensure execute permissions for scripts (chmod +x) and restrict write access for sensitive files (e.g., API keys) to the owner."
    fi

    # Output explanation
    shell::colored_echo "INFO: Permission Explanation for ${blue}${permission_string}${normal}" 46
    echo
    echo "${green}File Type${normal}: The first character '${blue}${file_type}${normal}' indicates a ${file_type_desc}."
    echo "${green}Owner Permissions${normal}: '${blue}${owner_perms}${normal}' means the owner has ${owner_desc}."
    echo "${green}Group Permissions${normal}: '${blue}${group_perms}${normal}' means group members have ${group_desc}."
    echo "${green}Others Permissions${normal}: '${blue}${others_perms}${normal}' means others have ${others_desc}."
    echo "${green}Octal Value${normal}: ${yellow}${octal}${normal} (use with 'chmod ${octal}')."
    echo
    echo "${green}Developer Context${normal}: $dev_context"
    [ "$debug" = "true" ] && echo "Debug: Parsed file type='$file_type', owner='$owner_perms', group='$group_perms', others='$others_perms', octal='$octal'" >&2

    return 0
}

# shell::uplink function
# Creates a hard link between the specified source and destination.
#
# Usage:
#   shell::uplink <source name> <destination name>
#
# Description:
#   The 'shell::uplink' function creates a hard link between the specified source file and destination file.
#   This allows multiple file names to refer to the same file content.
#
# Dependencies:
#   - The 'ln' command for creating hard links.
#   - The 'chmod' command to modify file permissions.
shell::uplink() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_UPLINK"
        return 0
    fi

    # If two arguments are provided, use them as source and destination.
    if [ "$#" -eq 2 ]; then
        local src="$1"
        local dest="$2"
        ln -vif "$src" "$dest" && chmod +x "$dest"
        return $?
    fi

    # Otherwise, expect a .link file containing link pairs separated by "→".
    local link_file=".link"
    if [[ ! -f $link_file ]]; then
        shell::colored_echo "No link file found" 196
        return 1
    fi

    # Process each line in the .link file that contains the delimiter "→".
    while IFS= read -r line; do
        if echo "$line" | grep -q "→"; then
            # Extract the source and destination, trimming any extra whitespace.
            local src
            local dest
            src=$(echo "$line" | cut -d'→' -f1 | xargs)
            dest=$(echo "$line" | cut -d'→' -f2 | xargs)
            if [ -n "$src" ] && [ -n "$dest" ]; then
                ln -vif "$src" "$dest" && chmod +x "$dest"
            else
                shell::colored_echo "ERR: Invalid link specification in .link: $line" 196
            fi
        fi
    done <"$link_file"
}

# shell::opent function
# Opens the specified directory in a new Finder tab (Mac OS only).
#
# Usage:
#   shell::opent [directory]
#
# Description:
#   The 'shell::opent' function opens the specified directory in a new Finder tab on Mac OS.
#   If no directory is specified, it opens the current directory.
#
# Dependencies:
#   - The 'osascript' command for AppleScript support.
shell::opent() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_OPENT"
        return 0
    fi

    local os
    os=$(shell::get_os_type)

    local dir
    local name

    # If no directory is provided, use the current directory.
    if [ "$#" -eq 0 ]; then
        dir=$(pwd)
        name=$(basename "$dir")
    else
        dir="$1"
        name=$(basename "$dir")
    fi

    if [ "$os" = "macos" ]; then
        osascript -e 'tell application "Finder"' \
            -e 'activate' \
            -e 'tell application "System Events"' \
            -e 'keystroke "t" using command down' \
            -e 'end tell' \
            -e 'set target of front Finder window to ("'"$dir"'" as POSIX file)' \
            -e 'end tell' \
            -e '--say "'"$name"'"'
    elif [ "$os" = "linux" ]; then
        # Use xdg-open to open the directory in the default file manager.
        xdg-open "$dir"
    else
        shell::colored_echo "ERR: Unsupported operating system for shell::opent function." 196
        return 1
    fi

    shell::colored_echo "DEBUG: Opening \"$name\" ..." 244
}

# shell::go_back function
# Navigates to the previous working directory.
#
# Usage:
#   shell::go_back
#
# Description:
#   The 'shell::go_back' function changes the current working directory to the previous directory in the history.
shell::go_back() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GO_BACK"
        return 0
    fi

    cd $OLDPWD
}

# shell::validate_ip_addr function
# Validates whether a given string is a valid IPv4 or IPv6 address.
#
# Usage:
# shell::validate_ip_addr <ip_address>
#
# Parameters:
# - <ip_address> : The IP address string to validate.
#
# Description:
# This function checks if the input string is a valid IPv4 or IPv6 address.
# IPv4 format: X.X.X.X where each X is 0-255.
# IPv6 format: eight groups of four hexadecimal digits separated by colons.
#
# Example:
# shell::validate_ip_addr 192.168.1.1       # Valid IPv4
# shell::validate_ip_addr fe80::1ff:fe23::1 # Valid IPv6
shell::validate_ip_addr() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_VALIDATE_IP_ADDR"
        return 0
    fi

    if [ $# -ne 1 ]; then
        echo "Usage: shell::validate_ip_addr <ip_address>"
        return 1
    fi

    local ip="$1"

    # Validate IPv4
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -r o1 o2 o3 o4 <<<"$ip"
        for octet in "$o1" "$o2" "$o3" "$o4"; do
            if ((octet < 0 || octet > 255)); then
                shell::colored_echo "ERR: IPv4 octet '$octet' out of range (0-255)." 196
                return 1
            fi
        done
        shell::colored_echo "INFO: '$ip' is a valid IPv4 address." 46
        return 0
    fi

    # Validate IPv6
    if [[ "$ip" =~ ^([0-9a-fA-F]{1,4}:){1,7}[0-9a-fA-F]{1,4}$ ]]; then
        shell::colored_echo "INFO: '$ip' is a valid IPv6 address." 46
        return 0
    fi

    shell::colored_echo "ERR: '$ip' is not a valid IPv4 or IPv6 address." 196
    return 1
}

# shell::validate_hostname function
# Validates whether a given string is a valid hostname using regex and DNS resolution.
#
# Usage:
# shell::validate_hostname <hostname>
#
# Description:
# A valid hostname:
# - Contains only letters, digits, and hyphens.
# - Labels are separated by dots.
# - Each label is 1-63 characters long.
# - The full hostname is up to 253 characters.
# - Labels cannot start or end with a hyphen.
# Also checks if the hostname resolves via DNS.
shell::validate_hostname() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_VALIDATE_HOSTNAME"
        return 0
    fi

    if [ $# -ne 1 ]; then
        echo "Usage: shell::validate_hostname <hostname>"
        return 1
    fi

    local hostname="$1"

    # Check total length
    if [ "${#hostname}" -gt 253 ]; then
        shell::colored_echo "ERR: Hostname exceeds 253 characters." 196
        return 1
    fi

    # Regex for full hostname validation
    # Allows single or multiple labels, each 1-63 characters, no leading/trailing hyphen
    if ! [[ "$hostname" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        shell::colored_echo "ERR: '$hostname' is not a valid hostname format." 196
        return 1
    fi

    # DNS resolution check
    if nslookup "$hostname" >/dev/null 2>&1; then
        shell::colored_echo "INFO: '$hostname' is a valid hostname and resolves via DNS." 46
        return 0
    else
        shell::colored_echo "WARN: '$hostname' is valid but does not resolve via DNS." 11
        return 0
    fi
}

# shell::get_mime_type function
# Determines the MIME type of a file.
#
# Usage:
#   shell::get_mime_type [-h] <file_path>
#
# Parameters:
#   - -h         : Optional. Displays this help message.
#   - <file_path>: The path to the file.
#
# Description:
#   Returns the appropriate MIME type based on file extension.
#
# Example:
#   mime_type=$(shell::get_mime_type "document.pdf")
shell::get_mime_type() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_GET_MIME_TYPE"
        return 0
    fi

    if [ $# -ne 1 ]; then
        echo "Usage: shell::get_mime_type <file_path>"
        return 1
    fi

    if [ -z "$1" ]; then
        shell::colored_echo "ERR: File path is required" 196
        return 1
    fi

    # Check if the file exists
    if [ ! -f "$1" ]; then
        shell::colored_echo "ERR: File '$1' does not exist." 196
        return 1
    fi

    local file_path="$1"
    local extension="${file_path##*.}"

    case "$extension" in
        txt|log) echo "text/plain" ;;
        json) echo "application/json" ;;
        csv) echo "text/csv" ;;
        md) echo "text/markdown" ;;
        html) echo "text/html" ;;
        xml) echo "application/xml" ;;
        jpg|jpeg) echo "image/jpeg" ;;
        png) echo "image/png" ;;
        webp) echo "image/webp" ;;
        gif) echo "image/gif" ;;
        pdf) echo "application/pdf" ;;
        docx) echo "application/vnd.openxmlformats-officedocument.wordprocessingml.document" ;;
        xlsx) echo "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" ;;
        pptx) echo "application/vnd.openxmlformats-officedocument.presentationml.presentation" ;;
        zip) echo "application/zip" ;;
        tar) echo "application/x-tar" ;;
        gz) echo "application/gzip" ;;
        bz2) echo "application/x-bzip2" ;;
        xz) echo "application/x-xz" ;;
        mp3) echo "audio/mpeg" ;;
        wav) echo "audio/wav" ;;
        ogg) echo "audio/ogg" ;;
        mp4) echo "video/mp4" ;;
        avi) echo "video/x-msvideo" ;;
        mkv) echo "video/x-matroska" ;;
        flv) echo "video/x-flv" ;;
        webm) echo "video/webm" ;;
        svg) echo "image/svg+xml" ;;
        ico) echo "image/x-icon" ;;
        json5) echo "application/json5" ;;
        yaml|yml) echo "application/x-yaml" ;;
        sh) echo "application/x-sh" ;;
        py) echo "text/x-python" ;;
        js) echo "application/javascript" ;;
        css) echo "text/css" ;;
        sql) echo "application/sql" ;;
        mdx) echo "text/markdown" ;;
        rs) echo "text/x-rust" ;;
        go) echo "text/x-go" ;;
        ts) echo "application/typescript" ;;
        cpp|cxx|cc) echo "text/x-c++src" ;;
        c) echo "text/x-csrc" ;;
        h) echo "text/x-chdr" ;;
        rb) echo "text/x-ruby" ;;
        pl) echo "text/x-perl" ;;
        java) echo "text/x-java-source" ;;
        kotlin) echo "text/x-kotlin" ;;
        dart) echo "application/dart" ;;
        scala) echo "text/x-scala" ;;
        swift) echo "text/x-swift" ;;
        lua) echo "text/x-lua" ;;
        rust) echo "text/x-rust" ;;
        asm|s) echo "text/x-asm" ;;
        v|vlang) echo "text/x-vlang" ;;
        nim) echo "text/x-nim" ;;
        clj|cljs) echo "text/x-clojure" ;;
        el|elisp) echo "text/x-emacs-lisp" ;;
        haskell|hs) echo "text/x-haskell" ;;
        erlang|erl) echo "text/x-erlang" ;;
        crystal) echo "text/x-crystal" ;;
        php) echo "application/x-php" ;;
        asp|aspx) echo "application/x-aspx" ;;
        jsp) echo "application/x-jsp" ;;
        cs|cshtml) echo "text/x-csharp" ;;
        vb|vbs) echo "text/vbscript" ;;
        tsx) echo "application/typescript" ;;
        vue) echo "text/x-vue" ;;
        svelte) echo "text/x-svelte" ;;
        rsx) echo "text/x-rsx" ;;
        dart) echo "application/dart" ;;
        nim) echo "text/x-nim" ;;
        clojure|clj) echo "text/x-clojure" ;;
        *) echo "text/plain" ;;
    esac
}

# shell::encode_base64_file function
# Encodes a file to base64 for API submission.
#
# Usage:
#   shell::encode_base64_file [-n] [-h] <file_path>
#
# Parameters:
#   - -n         : Optional dry-run flag. If provided, commands are printed using shell::on_evict instead of executed.
#   - -h         : Optional. Displays this help message.
#   - <file_path>: The path to the file to encode.
#
# Description:
#   Encodes the specified file to base64 format for API consumption.
#   Handles platform differences between macOS and Linux.
#
# Example:
#   shell::encode_base64_file "document.pdf"
#   shell::encode_base64_file -n "image.jpg"
shell::encode_base64_file() {
     if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ENCODE_BASE64_FILE"
        return 0
    fi

    local dry_run="false"
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -ne 1 ]; then
        echo "Usage: shell::encode_base64_file [-n] [-h] <file_path>"
        return 1
    fi

    # Check if the file exists
    # If the file does not exist, print an error message and exit.
    local file_path="$1"
    if [ ! -f "$file_path" ]; then
        shell::colored_echo "ERR: File not found: $file_path" 196
        return 1
    fi

    local os_type=$(shell::get_os_type)
    local base64_cmd=""

    if [ "$os_type" = "macos" ]; then
        base64_cmd="base64 -i \"$file_path\""
    else
        base64_cmd="base64 -w 0 \"$file_path\""
    fi

    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$base64_cmd"
    else
        shell::run_cmd_eval "$base64_cmd"
    fi
}

#!/bin/bash

# File viewer function using fzf with line highlighting and selection
# Compatible with Linux and macOS
view_file() {
    local file="$1"
    # Check if file argument is provided
    if [[ -z "$file" ]]; then
        echo "Usage: view_file <filename>"
        echo "View file content with line highlighting and selection using fzf"
        return 1
    fi
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo "Error: File '$file' not found"
        return 1
    fi
    # Check file extension and exclude unsupported formats
    local ext="${file##*.}"
    case "${ext,,}" in
        xls|xlsx|xlsm|xlsb|ods)
            echo "Error: Excel files are not supported"
            return 1
            ;;
        ppt|pptx|pps|ppsx|odp)
            echo "Error: PowerPoint files are not supported"
            return 1
            ;;
        doc|docx|odt)
            echo "Error: Word documents are not supported"
            return 1
            ;;
    esac
    # Check if fzf is installed
    if ! command -v fzf &> /dev/null; then
        echo "Error: fzf is not installed. Please install fzf first."
        return 1
    fi
    # Create temporary file for line numbers and content
    local temp_file=$(mktemp)
    trap "rm -f '$temp_file'" EXIT
    # Add line numbers to content
    nl -ba "$file" > "$temp_file"
    # Main fzf interface
    local selected_lines
    selected_lines=$(cat "$temp_file" | fzf \
        --multi \
        --bind 'enter:accept' \
        --bind 'ctrl-c:abort' \
        --bind 'ctrl-a:select-all' \
        --bind 'ctrl-d:deselect-all' \
        --bind 'tab:toggle' \
        --bind 'shift-tab:toggle+up' \
        --header="File: $file | TAB: select line | CTRL+A: select all | ENTER: copy selected | ESC: exit" \
        --preview-window="right:50%" \
        --preview="echo 'Selected lines will be copied to clipboard'" \
        --height=100% \
        --border \
        --ansi)
    # Check if user made a selection
    if [[ -n "$selected_lines" ]]; then
        # Extract only the content (remove line numbers)
        local content_to_copy
        content_to_copy=$(echo "$selected_lines" | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')
        # Copy to clipboard based on OS
        # if command -v pbcopy &> /dev/null; then
        #     # macOS
        #     echo "$content_to_copy" | pbcopy
        #     echo "Selected lines copied to clipboard (macOS)"
        # elif command -v xclip &> /dev/null; then
        #     # Linux with xclip
        #     echo "$content_to_copy" | xclip -selection clipboard
        #     echo "Selected lines copied to clipboard (Linux - xclip)"
        # elif command -v xsel &> /dev/null; then
        #     # Linux with xsel
        #     echo "$content_to_copy" | xsel --clipboard --input
        #     echo "Selected lines copied to clipboard (Linux - xsel)"
        # else
        #     echo "Clipboard utility not found. Selected content:"
        #     echo "----------------------------------------"
        #     echo "$content_to_copy"
        #     echo "----------------------------------------"
        # fi
        # Show what was copied
        local line_count=$(echo "$selected_lines" | wc -l)
        echo "Copied $line_count line(s) from '$file'"
    else
        echo "No lines selected"
    fi
}

# Enhanced version with range selection
view_file_range() {
    local file="$1"
    # Check if file argument is provided
    if [[ -z "$file" ]]; then
        echo "Usage: view_file_range <filename>"
        echo "View file content with range selection using fzf"
        return 1
    fi
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo "Error: File '$file' not found"
        return 1
    fi
    # Check file extension and exclude unsupported formats
    local ext="${file##*.}"
    case "${ext,,}" in
        xls|xlsx|xlsm|xlsb|ods)
            echo "Error: Excel files are not supported"
            return 1
            ;;
        ppt|pptx|pps|ppsx|odp)
            echo "Error: PowerPoint files are not supported"
            return 1
            ;;
        doc|docx|odt)
            echo "Error: Word documents are not supported"
            return 1
            ;;
    esac
    # Check if fzf is installed
    if ! command -v fzf &> /dev/null; then
        echo "Error: fzf is not installed. Please install fzf first."
        return 1
    fi
    # Create temporary file for line numbers and content
    local temp_file=$(mktemp)
    trap "rm -f '$temp_file'" EXIT
    # Add line numbers to content
    nl -ba "$file" > "$temp_file"
    echo "Select starting line:"
    local start_line
    start_line=$(cat "$temp_file" | fzf \
        --header="Select START line for range | ENTER: confirm | ESC: cancel" \
        --preview-window="right:50%" \
        --preview="echo 'This will be the START of your selection range'" \
        --height=100% \
        --border)
    if [[ -z "$start_line" ]]; then
        echo "No starting line selected"
        return 0
    fi
    local start_num=$(echo "$start_line" | awk '{print $1}')
    echo "Starting line selected: $start_num"
    echo "Select ending line:"
    local end_line
    end_line=$(cat "$temp_file" | fzf \
        --header="Select END line for range | ENTER: confirm | ESC: cancel" \
        --preview-window="right:50%" \
        --preview="echo 'Range: line $start_num to this line'" \
        --height=100% \
        --border)
    if [[ -z "$end_line" ]]; then
        echo "No ending line selected"
        return 0
    fi
    local end_num=$(echo "$end_line" | awk '{print $1}')
    echo "Ending line selected: $end_num"
    # Ensure start is less than or equal to end
    if [[ $start_num -gt $end_num ]]; then
        local temp=$start_num
        start_num=$end_num
        end_num=$temp
        echo "Swapped range: lines $start_num to $end_num"
    fi
    # Extract the range
    local content_to_copy
    content_to_copy=$(sed -n "${start_num},${end_num}p" "$file")
    # Copy to clipboard based on OS
    # if command -v pbcopy &> /dev/null; then
    #     # macOS
    #     echo "$content_to_copy" | pbcopy
    #     echo "Lines $start_num-$end_num copied to clipboard (macOS)"
    # elif command -v xclip &> /dev/null; then
    #     # Linux with xclip
    #     echo "$content_to_copy" | xclip -selection clipboard
    #     echo "Lines $start_num-$end_num copied to clipboard (Linux - xclip)"
    # elif command -v xsel &> /dev/null; then
    #     # Linux with xsel
    #     echo "$content_to_copy" | xsel --clipboard --input
    #     echo "Lines $start_num-$end_num copied to clipboard (Linux - xsel)"
    # else
    #     echo "Clipboard utility not found. Selected content (lines $start_num-$end_num):"
    #     echo "----------------------------------------"
    #     echo "$content_to_copy"
    #     echo "----------------------------------------"
    # fi
    local line_count=$((end_num - start_num + 1))
    echo "Copied $line_count line(s) from '$file' (lines $start_num-$end_num)"
}

# Alias for easier use
alias vf='view_file'
alias vfr='view_file_range'

# Help function
view_file_help() {
    echo "File Viewer with fzf - Help"
    echo "============================"
    echo ""
    echo "Functions:"
    echo "  view_file <filename>       - View file with multi-line selection"
    echo "  view_file_range <filename> - View file with range selection"
    echo ""
    echo "Aliases:"
    echo "  vf  - shortcut for view_file"
    echo "  vfr - shortcut for view_file_range"
    echo ""
    echo "Key bindings in fzf:"
    echo "  TAB         - Toggle line selection"
    echo "  Shift+TAB   - Toggle selection and move up"
    echo "  CTRL+A      - Select all lines"
    echo "  CTRL+D      - Deselect all lines"
    echo "  ENTER       - Copy selected lines to clipboard"
    echo "  ESC         - Exit without copying"
    echo ""
    echo "Supported platforms:"
    echo "  - Linux (requires xclip or xsel for clipboard)"
    echo "  - macOS (uses pbcopy for clipboard)"
    echo ""
    echo "Excluded file types:"
    echo "  - Excel files (.xls, .xlsx, .xlsm, .xlsb, .ods)"
    echo "  - PowerPoint files (.ppt, .pptx, .pps, .ppsx, .odp)"
    echo "  - Word documents (.doc, .docx, .odt)"
}

alias vfh='view_file_help'