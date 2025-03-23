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
shell::colored_echo() {
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
    local command="$*"

    # Capture the OS type output from shell::get_os_type
    local os_type
    os_type=$(shell::get_os_type)

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
    local command="$*"
    # Capture the OS type output from shell::get_os_type
    local os_type
    os_type=$(shell::get_os_type)

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

    shell::colored_echo "$emoji $command" $color_code
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
    local package="$1"

    local os_type
    os_type=$(shell::get_os_type)

    if [ "$os_type" = "linux" ]; then # Linux
        # Check if the package is already installed on Linux.
        if shell::is_package_installed_linux "$package"; then
            shell::colored_echo "🟡 $package is already installed. Skipping." 33
            return 0
        fi

        if shell::is_command_available apt-get; then
            shell::run_cmd_eval "sudo apt-get update && sudo apt-get install -y $package"
        elif shell::is_command_available yum; then
            shell::run_cmd_eval "sudo yum install -y $package"
        elif shell::is_command_available dnf; then
            shell::run_cmd_eval "sudo dnf install -y $package"
        else
            shell::colored_echo "🔴 Error: Unsupported package manager on Linux." 31
            return 1
        fi
    elif [ "$os_type" = "macos" ]; then # macOS
        if ! shell::is_command_available brew; then
            shell::colored_echo "Homebrew is not installed. Installing Homebrew..." 33
            install_homebrew
        fi
        # Check if the package is already installed by Homebrew; skip if installed.
        if brew list --versions "$package" >/dev/null 2>&1; then
            shell::colored_echo "🟡 $package is already installed. Skipping." 32
            return 0
        fi
        shell::run_cmd_eval "brew install $package"
    else
        shell::colored_echo "🔴 Error: Unsupported operating system." 31
        return 1
    fi
}

# shell::removal_package function
# Cross-platform package uninstallation function for macOS and Linux.
#
# Usage:
#   shell::removal_package <package_name>
#
# Parameters:
#   - <package_name>: The name of the package to uninstall
#
# Example usage:
#   shell::removal_package git
shell::removal_package() {
    local package="$1"
    local os_type
    os_type=$(shell::get_os_type)

    if [ "$os_type" = "linux" ]; then
        if shell::is_command_available apt-get; then
            if shell::is_package_installed_linux "$package"; then
                shell::run_cmd_eval "sudo apt-get remove -y $package"
            else
                shell::colored_echo "🟡 $package is not installed. Skipping uninstallation." 33
            fi
        elif shell::is_command_available yum; then
            if rpm -q "$package" >/dev/null 2>&1; then
                shell::run_cmd_eval "sudo yum remove -y $package"
            else
                shell::colored_echo "🟡 $package is not installed. Skipping uninstallation." 33
            fi
        elif shell::is_command_available dnf; then
            if rpm -q "$package" >/dev/null 2>&1; then
                shell::run_cmd_eval "sudo dnf remove -y $package"
            else
                shell::colored_echo "🟡 $package is not installed. Skipping uninstallation." 33
            fi
        else
            shell::colored_echo "🔴 Error: Unsupported package manager on Linux." 31
            return 1
        fi
    elif [ "$os_type" = "macos" ]; then
        if shell::is_command_available brew; then
            if brew list --versions "$package" >/dev/null 2>&1; then
                shell::run_cmd_eval "brew uninstall $package"
            else
                shell::colored_echo "🟡 $package is not installed. Skipping uninstallation." 33
            fi
        else
            shell::colored_echo "🔴 Error: Homebrew is not installed on macOS." 31
            return 1
        fi
    else
        shell::colored_echo "🔴 Error: Unsupported operating system." 31
        return 1
    fi
}

# shell::list_installed_packages function
# Lists all packages currently installed on Linux or macOS.
#
# Usage:
#   shell::list_installed_packages
#
# Description:
#   On Linux:
#     - If apt-get is available, it uses dpkg to list installed packages.
#     - If yum or dnf is available, it uses rpm to list installed packages.
#   On macOS:
#     - If Homebrew is available, it lists installed Homebrew packages.
#
# Example usage:
#   shell::list_installed_packages
shell::list_installed_packages() {
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
            shell::colored_echo "🔴 Error: Unsupported package manager on Linux." 31
            return 1
        fi
    elif [ "$os_type" = "macos" ]; then
        if shell::is_command_available brew; then
            shell::colored_echo "Listing installed packages (Homebrew):" 32
            shell::run_cmd_eval brew list
        else
            shell::colored_echo "🔴 Error: Homebrew is not installed on macOS." 31
            return 1
        fi
    else
        shell::colored_echo "🔴 Error: Unsupported operating system." 31
        return 1
    fi
}

# shell::list_path_installed_packages function
# Lists all packages installed via directory-based package installation on Linux or macOS,
# along with their installation paths.
#
# Usage:
#   shell::list_path_installed_packages [base_install_path]
#
# Parameters:
#   - [base_install_path]: Optional. The base directory where packages are installed.
#         Defaults to:
#           - /usr/local on macOS
#           - /opt on Linux
#
# Example usage:
#   shell::list_path_installed_packages
#   shell::list_path_installed_packages /custom/install/path
shell::list_path_installed_packages() {
    local base_path="$1"
    local os_type
    os_type=$(shell::get_os_type)

    # Set default installation directory if not provided.
    if [ -z "$base_path" ]; then
        if [ "$os_type" = "macos" ]; then
            base_path="/usr/local"
        elif [ "$os_type" = "linux" ]; then
            base_path="/opt"
        else
            shell::colored_echo "🔴 Error: Unsupported operating system for package path listing." 31
            return 1
        fi
    fi

    # Verify the base installation directory exists.
    if [ ! -d "$base_path" ]; then
        shell::colored_echo "🔴 Error: The specified installation path '$base_path' does not exist." 31
        return 1
    fi

    shell::colored_echo "Listing packages installed in: $base_path" 36
    # List only directories (assumed to be package folders) at one level below base_path.
    find "$base_path" -maxdepth 1 -mindepth 1 -type d | sort | while read -r package_dir; do
        local package_name
        package_name=$(basename "$package_dir")
        shell::colored_echo "📦 Package: $package_name 👉 Path: $package_dir"
    done
}

# shell::list_path_installed_packages_details function
# Lists detailed information (including full path, directory size, and modification date)
# for all packages installed via directory-based methods on Linux or macOS.
#
# Usage:
#   shell::list_path_installed_packages_details [base_install_path]
#
# Parameters:
#   - [base_install_path]: Optional. The base directory where packages are installed.
#         Defaults to:
#           - /usr/local on macOS
#           - /opt on Linux
#
# Example usage:
#   shell::list_path_installed_packages_details
#   shell::list_path_installed_packages_details /custom/install/path
shell::list_path_installed_packages_details() {
    local base_path="$1"
    local os_type
    os_type=$(shell::get_os_type)

    # Set default base path if none is provided.
    if [ -z "$base_path" ]; then
        if [ "$os_type" = "macos" ]; then
            base_path="/usr/local"
        elif [ "$os_type" = "linux" ]; then
            base_path="/opt"
        else
            shell::colored_echo "🔴 Error: Unsupported operating system for package details listing." 31
            return 1
        fi
    fi

    # Verify that the base installation directory exists.
    if [ ! -d "$base_path" ]; then
        shell::colored_echo "🔴 Error: The specified installation path '$base_path' does not exist." 31
        return 1
    fi

    shell::colored_echo "Listing details of packages installed in: $base_path" 36

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
    local package="$1"

    if shell::is_command_available apt-get; then
        # Debian-based: Check using dpkg.
        dpkg -s "$package" >/dev/null 2>&1
    elif shell::is_command_available rpm; then
        # RPM-based: Check using rpm query.
        rpm -q "$package" >/dev/null 2>&1
    else
        shell::colored_echo "🔴 Error: Unsupported package manager for Linux." 31
        return 1
    fi
}

###############################################################################
# shell::create_directory_if_not_exists function
###############################################################################
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
        shell::colored_echo "📁 Directory '$dir' does not exist. Creating the directory (including nested directories) with admin privileges..." 11
        shell::run_cmd_eval 'sudo mkdir -p "$dir"' # Use sudo to create the directory and its parent directories.
        if [ $? -eq 0 ]; then
            shell::colored_echo "🟢 Directory created successfully." 46
            shell::setPerms::777 "$dir"
            return 0
        else
            shell::colored_echo "🔴 Error: Failed to create the directory." 196
            return 1
        fi
    else
        shell::colored_echo "🟢 Directory '$dir' already exists." 46
    fi
}

# shell::create_file_if_not_exists function
# Utility function to create a file if it doesn't exist.
#
# Usage:
#   shell::create_file_if_not_exists <filename>
#
# Parameters:
#   - <filename>: The name (or path) of the file to be created.
#
# Description:
#   This function checks if a file exists. If not, it ensures that the parent directory
#   exists (creating it with admin privileges if necessary) and then creates the file.
#   On macOS, if a relative path is provided, it is assumed to be relative to $HOME.
#   After creation, directory permissions are set to 700 and file permissions to 600,
#   allowing read and write access only for the owner.
#
# Example usage:
#   shell::create_file_if_not_exists /path/to/file.txt
#   shell::create_file_if_not_exists demo/file.txt   (On macOS, this creates "$HOME/demo/file.txt")
shell::create_file_if_not_exists() {
    if [ $# -lt 1 ]; then
        echo "Usage: shell::create_file_if_not_exists <filename>"
        return 1
    fi

    local filename="$1"
    local directory
    directory="$(dirname "$filename")"
    local os
    os=$(shell::get_os_type)

    # On macOS, if the provided directory path is not absolute, assume it's relative to $HOME.
    if [[ "$os" == "macos" ]]; then
        if [[ "$directory" != /* ]]; then
            directory="$HOME/$directory"
        fi
        # Also, if the filename itself is relative, update it.
        if [[ "$filename" != /* ]]; then
            filename="$HOME/$filename"
        fi
    fi

    # Check if the parent directory exists.
    if [ ! -d "$directory" ]; then
        shell::colored_echo "📁 Directory '$directory' does not exist. Creating with admin privileges..." 11
        shell::run_cmd_eval "sudo mkdir -p \"$directory\""
        if [ $? -eq 0 ]; then
            shell::colored_echo "🟢 Directory created successfully." 46
            # shell::run_cmd_eval "sudo chmod 700 \"$directory\"" # Set directory permissions to 700 (owner can read, write, and execute)
        else
            shell::colored_echo "🔴 Error: Failed to create the directory." 196
            return 1
        fi
    fi

    # Check if the file exists.
    if [ ! -e "$filename" ]; then
        shell::colored_echo "📄 File '$filename' does not exist. Creating with admin privileges..." 11
        shell::run_cmd_eval "sudo touch \"$filename\""
        if [ $? -eq 0 ]; then
            shell::colored_echo "🟢 File created successfully." 46
            # shell::run_cmd_eval "sudo chmod 600 \"$filename\"" # Set file permissions to 600 (owner can read and write; no permissions for others)
            return 0
        else
            shell::colored_echo "🔴 Error: Failed to create the file." 196
            return 1
        fi
    fi
    return 0
}

# shell::setPerms::777 function
# Sets full permissions (read, write, and execute) for the specified file or directory.
#
# Usage:
#   shell::setPerms::777 [-n] <file/dir>
#
# Parameters:
#   - -n (optional): Dry-run mode. Instead of executing the command, prints it using on_evict.
#   - <file/dir> : The path to the file or directory to modify.
#
# Description:
#   This function checks the current permission of the target. If it is already set to 777,
#   it logs a message and exits without making any changes.
#   Otherwise, it builds and executes (or prints, in dry-run mode) the chmod command asynchronously
#   to grant full permissions recursively.
#
# Example:
#   shell::setPerms::777 ./my_script.sh
#   shell::setPerms::777 -n ./my_script.sh  # Dry-run: prints the command without executing.
shell::setPerms::777() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: shell::setPerms::777 [-n] <file/dir>"
        return 1
    fi

    local target="$1"

    # Verify that the target exists
    if [ ! -e "$target" ]; then
        shell::colored_echo "🔴 Target '$target' does not exist." 196
        return 1
    fi

    # Determine the current permission of the target
    local current_perm=""
    local os_type
    os_type=$(shell::get_os_type)
    if [ "$os_type" = "macos" ]; then
        current_perm=$(stat -f "%Lp" "$target")
    else
        current_perm=$(stat -c "%a" "$target")
    fi

    # Build the chmod command
    local chmod_cmd="sudo chmod -R 777 \"$target\""

    # Execute the chmod command asynchronously or print it in dry-run mode
    if [ "$dry_run" = "true" ]; then
        on_evict "$chmod_cmd"
    else
        # If the target already has 777 permissions, skip execution.
        if [ "$current_perm" -eq 777 ]; then
            # shell::colored_echo "🟡 Permissions for '$target' already set to full (777)" 33
            return 0
        fi
        shell::run_cmd_eval "$chmod_cmd"
        shell::colored_echo "🟢 Permissions for '$target' set to full (read, write, and execute - 777)" 46
    fi
}

# clip_cwd function
# Copies the current directory path to the clipboard.
#
# Usage:
#   clip_cwd
#
# Description:
#   The 'clip_cwd' function copies the current directory path to the clipboard using the 'pbcopy' command.
clip_cwd() {
    local adr="$PWD"
    local os
    os=$(shell::get_os_type)

    if [[ "$os" == "macos" ]]; then
        echo -n "$adr" | pbcopy
        shell::colored_echo "🟢 Path copied to clipboard using pbcopy" 46
    elif [[ "$os" == "linux" ]]; then
        if shell::is_command_available xclip; then
            echo -n "$adr" | xclip -selection clipboard
            shell::colored_echo "🟢 Path copied to clipboard using xclip" 46
        elif shell::is_command_available xsel; then
            echo -n "$adr" | xsel --clipboard --input
            shell::colored_echo "🟢 Path copied to clipboard using xsel" 46
        else
            shell::colored_echo "🔴 Clipboard tool not found. Please install xclip or xsel." 196
            return 1
        fi
    else
        shell::colored_echo "🔴 Clipboard copying not supported on this OS." 196
        return 1
    fi
}

# clip_value function
# Copies the provided text value into the system clipboard.
#
# Usage:
#   clip_value <text>
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
#   clip_value "Hello, World!"
clip_value() {
    local value="$1"
    if [[ -z "$value" ]]; then
        shell::colored_echo "🔴 Error: No value provided to copy." 196
        return 1
    fi

    local os
    os=$(shell::get_os_type)

    if [[ "$os" == "macos" ]]; then
        echo -n "$value" | pbcopy
        shell::colored_echo "🟢 Value copied to clipboard using pbcopy." 46
    elif [[ "$os" == "linux" ]]; then
        if shell::is_command_available xclip; then
            echo -n "$value" | xclip -selection clipboard
            shell::colored_echo "🟢 Value copied to clipboard using xclip." 46
        elif shell::is_command_available xsel; then
            echo -n "$value" | xsel --clipboard --input
            shell::colored_echo "🟢 Value copied to clipboard using xsel." 46
        else
            shell::colored_echo "🔴 Clipboard tool not found. Please install xclip or xsel." 196
            return 1
        fi
    else
        shell::colored_echo "🔴 Clipboard copying not supported on this OS." 196
        return 1
    fi
}

# get_temp_dir function
# Returns the appropriate temporary directory based on the detected kernel.
#
# Usage:
#   get_temp_dir
#
# Returns:
#   The path to the temporary directory for the current operating system.
#
# Example usage:
#   TEMP_DIR=$(get_temp_dir)
#   echo "Using temporary directory: $TEMP_DIR"
get_temp_dir() {
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

# port_check function
# Checks if a specific TCP port is in use (listening).
#
# Usage:
#   port_check <port>
#
# Parameters:
#   - <port> : The port number to check.
#
# Description:
#   This function uses lsof to determine if any process is actively listening on the specified
#   TCP port. It filters the output for lines containing "LISTEN", which indicates that the port is in use.
#
# Example:
#   port_check 8080
#
# Notes:
#   - Ensure that lsof is installed on your system.
# function port_check() {
#     if [ $# -ne 1 ]; then
#         echo "Usage: port_check <port>"
#         return 1
#     fi

#     local port="$1"
#     shell::run_cmd lsof -nP -iTCP:"$port" | grep LISTEN
# }

# on_evict function
# Hook to print a command without executing it.
#
# Usage:
#   on_evict <command>
#
# Parameters:
#   - <command>: The command to be printed.
#
# Description:
#   The 'on_evict' function prints a command without executing it.
#   It is designed as a hook for logging or displaying commands without actual execution.
#
# Example usage:
#   on_evict ls -l
#
# Instructions:
#   1. Use 'on_evict' to print a command without executing it.
#
# Notes:
#   - This function is useful for displaying commands in logs or hooks without execution.
on_evict() {
    local command="$*"
    shell::colored_echo "CLI: $command" 3
    clip_value "$command"
}

# port_check function
# Checks if a specific TCP port is in use (listening).
#
# Usage:
#   port_check <port> [-n]
#
# Parameters:
#   - <port> : The TCP port number to check.
#   - -n     : Optional flag to enable dry-run mode (prints the command without executing it).
#
# Description:
#   This function uses lsof to determine if any process is actively listening on the specified TCP port.
#   It filters the output for lines containing "LISTEN", which indicates that the port is in use.
#   When the dry-run flag (-n) is provided, the command is printed using on_evict instead of being executed.
#
# Example:
#   port_check 8080        # Executes the command.
#   port_check 8080 -n     # Prints the command (dry-run mode) without executing it.
port_check() {
    if [ $# -lt 1 ]; then
        echo "Usage: port_check <port> [-n]"
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
        on_evict "$cmd"
    else
        # shell::run_cmd lsof -nP -iTCP:"$port" | grep LISTEN
        shell::run_cmd_eval "$cmd"
    fi
}

# port_kill function
# Terminates all processes listening on the specified TCP port(s).
#
# Usage:
#   port_kill [-n] <port> [<port> ...]
#
# Parameters:
#   - -n    : Optional flag to enable dry-run mode (print commands without execution).
#   - <port>: One or more TCP port numbers.
#
# Description:
#   This function checks each specified port to determine if any processes are listening on it,
#   using lsof. If any are found, it forcefully terminates them by sending SIGKILL (-9).
#   In dry-run mode (enabled by the -n flag), the kill command is printed using on_evict instead of executed.
#
# Example:
#   port_kill 8080              # Kills processes on port 8080.
#   port_kill -n 8080 3000       # Prints the kill commands for ports 8080 and 3000 without executing.
#
# Notes:
#   - Ensure you have the required privileges to kill processes.
#   - Use with caution, as forcefully terminating processes may cause data loss.
port_kill() {
    local dry_run="false"

    # Check for the dry-run flag.
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ "$#" -eq 0 ]; then
        shell::colored_echo "🟡 No ports specified. Usage: port_kill [-n] PORT [PORT...]" 11
        return 1
    fi

    for port in "$@"; do
        # Find PIDs of processes listening on the specified port.
        local pids
        pids=$(lsof -ti :"$port")

        if [ -n "$pids" ]; then
            shell::colored_echo "🟢 Processing port $port with PIDs: $pids" 46
            for pid in $pids; do
                # Construct the kill command as an array to reuse it for both on_evict and shell::run_cmd.
                local cmd=("kill" "-9" "$pid")
                # local cmd="kill -9 $pid"
                if [ "$dry_run" = "true" ]; then
                    # on_evict "$cmd"
                    on_evict "${cmd[*]}"
                else
                    # shell::run_cmd kill -9 "$pid"
                    shell::run_cmd "${cmd[@]}"
                fi
            done
        else
            shell::colored_echo "🟠 No processes found on port $port" 11
        fi
    done
}

# copy_files function
# Copies a source file to one or more destination filenames in the current working directory.
#
# Usage:
#   copy_files [-n] <source_filename> <new_filename1> [<new_filename2> ...]
#
# Parameters:
#   - -n             : Optional dry-run flag. If provided, the command will be printed using on_evict instead of executed.
#   - <source_filename> : The file to copy.
#   - <new_filenameX>   : One or more new filenames (within the current working directory) where the source file will be copied.
#
# Description:
#   The function first checks for a dry-run flag (-n). It then verifies that at least two arguments remain.
#   For each destination filename, it checks if the file already exists in the current working directory.
#   If not, it builds the command to copy the source file (using sudo) to the destination.
#   In dry-run mode, the command is printed using on_evict; otherwise, it is executed using shell::run_cmd_eval.
#
# Example:
#   copy_files myfile.txt newfile.txt            # Copies myfile.txt to newfile.txt.
#   copy_files -n myfile.txt newfile1.txt newfile2.txt  # Prints the copy commands without executing them.
copy_files() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n).
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -lt 2 ]; then
        echo "Usage: copy_files [-n] <source_filename> <new_filename1> [<new_filename2> ...]"
        return 1
    fi

    local source="$1"
    shift # Remove the source file from the arguments.
    local destination="$PWD"

    for filename in "$@"; do
        local destination_file="$destination/$filename"

        if [ -e "$destination_file" ]; then
            shell::colored_echo "🔴 Error: Destination file '$filename' already exists." 196
            continue
        fi

        # Build the copy command.
        local cmd="sudo cp \"$source\" \"$destination_file\""
        if [ "$dry_run" = "true" ]; then
            on_evict "$cmd"
        else
            shell::run_cmd_eval "$cmd"
            shell::colored_echo "🟢 File copied successfully to $destination_file" 46
        fi
    done
}

# move_files function
# Moves one or more files to a destination folder.
#
# Usage:
#   move_files [-n] <destination_folder> <file1> <file2> ... <fileN>
#
# Parameters:
#   - -n                  : Optional dry-run flag. If provided, the command will be printed using on_evict instead of executed.
#   - <destination_folder>: The target directory where the files will be moved.
#   - <fileX>             : One or more source files to be moved.
#
# Description:
#   The function first checks for an optional dry-run flag (-n). It then verifies that the destination folder exists.
#   For each source file provided:
#     - It checks whether the source file exists.
#     - It verifies that the destination file (using the basename of the source) does not already exist in the destination folder.
#     - It builds the command to move the file (using sudo mv).
#   In dry-run mode, the command is printed using on_evict; otherwise, the command is executed using shell::run_cmd.
#   If an error occurs for a particular file (e.g., missing source or destination file conflict), the error is logged and the function continues with the next file.
#
# Example:
#   move_files /path/to/dest file1.txt file2.txt              # Moves file1.txt and file2.txt to /path/to/dest.
#   move_files -n /path/to/dest file1.txt file2.txt             # Prints the move commands without executing them.
move_files() {
    local dry_run="false"

    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -lt 2 ]; then
        echo "Usage: move_files [-n] <destination_folder> <file1> <file2> ... <fileN>"
        return 1
    fi

    local destination_folder="$1"
    shift

    if [ ! -d "$destination_folder" ]; then
        shell::colored_echo "🔴 Error: Destination folder '$destination_folder' does not exist." 196
        return 1
    fi

    for source in "$@"; do
        if [ ! -e "$source" ]; then
            shell::colored_echo "🔴 Error: Source file '$source' does not exist." 196
            continue
        fi

        local destination="$destination_folder/$(basename "$source")"

        if [ -e "$destination" ]; then
            shell::colored_echo "🔴 Error: Destination file '$destination' already exists." 196
            continue
        fi

        local cmd="sudo mv \"$source\" \"$destination\""
        if [ "$dry_run" = "true" ]; then
            on_evict "$cmd"
        else
            shell::run_cmd sudo mv "$source" "$destination"
            if [ $? -eq 0 ]; then
                shell::colored_echo "🟢 File '$source' moved successfully to $destination" 46
            else
                shell::colored_echo "🔴 Error moving file '$source'." 196
            fi
        fi
    done
}

# remove_dataset function
# Removes a file or directory using sudo rm -rf.
#
# Usage:
#   remove_dataset [-n] <filename/dir>
#
# Parameters:
#   - -n           : Optional dry-run flag. If provided, the command will be printed using on_evict instead of executed.
#   - <filename/dir>: The file or directory to remove.
#
# Description:
#   The function first checks for an optional dry-run flag (-n). It then verifies that a target argument is provided.
#   It builds the command to remove the specified target using "sudo rm -rf".
#   In dry-run mode, the command is printed using on_evict; otherwise, it is executed using shell::run_cmd.
#
# Example:
#   remove_dataset my-dir          # Removes the directory 'my-dir'.
#   remove_dataset -n myfile.txt  # Prints the removal command without executing it.
remove_dataset() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n).
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ -z "$1" ]; then
        echo "Usage: remove_dataset [-n] <filename/dir>"
        return 1
    fi

    local target="$1"
    local cmd="sudo rm -rf \"$target\""

    if [ "$dry_run" = "true" ]; then
        on_evict "$cmd"
    else
        shell::run_cmd sudo rm -rf "$target"
    fi
}

# editor function
# Open a selected file from a specified folder using a chosen text editor.
#
# Usage:
#   editor [-n] <folder>
#
# Parameters:
#   - -n       : Optional dry-run flag. If provided, the command will be printed using on_evict instead of executed.
#   - <folder> : The directory containing the files you want to edit.
#
# Description:
#   The 'editor' function provides an interactive way to select a file from the specified
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
#   editor ~/documents          # Opens a file in the selected text editor.
#   editor -n ~/documents       # Prints the command that would be used, without executing it.
#
# Requirements:
#   - fzf must be installed.
#   - Helper functions: shell::run_cmd, on_evict, shell::colored_echo, and shell::get_os_type.
editor() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n).
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -lt 1 ]; then
        echo "Usage: editor [-n] <folder>"
        return 1
    fi

    local folder="$1"
    if [ ! -d "$folder" ]; then
        shell::colored_echo "🔴 Error: '$folder' is not a valid directory." 196
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
        shell::colored_echo "🔴 No files found in '$folder'." 196
        return 1
    fi

    # Use fzf to select a file.
    local selected_file
    selected_file=$(echo "$file_list" | fzf --prompt="Select a file: ")
    if [ -z "$selected_file" ]; then
        shell::colored_echo "🔴 No file selected." 196
        return 1
    fi

    # Use fzf to select the text editor command.
    local selected_command
    selected_command=$(echo "cat;less;more;vim;nano" | tr ';' '\n' | fzf --prompt="Select an action: ")
    if [ -z "$selected_command" ]; then
        shell::colored_echo "🔴 No action selected." 196
        return 1
    fi

    # Build the command string.
    local cmd="$selected_command \"$selected_file\""
    if [ "$dry_run" = "true" ]; then
        on_evict "$cmd"
    else
        shell::run_cmd $selected_command "$selected_file"
    fi
}

# download_dataset function
# Downloads a dataset file from a provided download link.
#
# Usage:
#   download_dataset [-n] <filename_with_extension> <download_link>
#
# Parameters:
#   - -n                     : Optional dry-run flag. If provided, commands are printed using on_evict instead of executed.
#   - <filename_with_extension> : The target filename (with path) where the dataset will be saved.
#   - <download_link>         : The URL from which the dataset will be downloaded.
#
# Description:
#   This function downloads a file from a given URL and saves it under the specified filename.
#   It extracts the directory from the filename, ensures the directory exists, and changes to that directory
#   before attempting the download. If the file already exists, it prompts the user for confirmation before
#   overwriting it. In dry-run mode, the function uses on_evict to display the commands without executing them.
#
# Example:
#   download_dataset mydata.zip https://example.com/mydata.zip
#   download_dataset -n mydata.zip https://example.com/mydata.zip  # Displays the commands without executing them.
download_dataset() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -ne 2 ]; then
        echo "Usage: download_dataset [-n] <filename_store_with_extension> <download_link>"
        return 1
    fi

    local filename="$1"
    local link="$2"

    # Extract the directory path from the filename
    local directory
    directory=$(dirname "$filename")

    # Ensure the directory exists; create it if it doesn't
    shell::create_file_if_not_exists "$directory"

    # Change to the directory for downloading the file
    cd "$directory" || return 1

    local base="$directory/$(basename "$filename")"
    # Check if the file already exists
    if [ -e "$base" ]; then
        local confirm=""
        while [ -z "$confirm" ]; do
            echo -n "❓ Do you want to overwrite the existing file? (y/n): "
            read confirm
            if [ -z "$confirm" ]; then
                shell::colored_echo "🔴 Invalid input. Please enter y or n." 196
            fi
        done

        if [ "$confirm" != "y" ]; then
            shell::colored_echo "🍌 Download canceled. The file already exists." 11
            return 1
        fi

        # Remove the existing file before downloading (using on_evict in dry-run mode)
        if [ "$dry_run" = "true" ]; then
            on_evict "sudo rm \"$base\""
        else
            shell::run_cmd sudo rm "$base"
        fi
    fi

    # Return to the original directory
    cd - >/dev/null || return 1

    # Build the download command
    local download_cmd="curl -LJ \"$link\" -o \"$filename\""
    if [ "$dry_run" = "true" ]; then
        on_evict "$download_cmd"
        shell::colored_echo "💡 Dry-run mode: Displayed download command for $filename" 11
    else
        shell::run_cmd curl -LJ "$link" -o "$filename"
        if [ $? -eq 0 ]; then
            shell::colored_echo "🟢 Successfully downloaded: $filename" 46
        else
            shell::colored_echo "🔴 Error: Download failed for $link" 196
        fi
    fi
}

# unarchive function
# Extracts a compressed file based on its file extension.
#
# Usage:
#   unarchive [-n] <filename>
#
# Parameters:
#   - -n        : Optional dry-run flag. If provided, the extraction command is printed using on_evict instead of executed.
#   - <filename>: The compressed file to extract.
#
# Description:
#   The function first checks for an optional dry-run flag (-n) and then verifies that exactly one argument (the filename) is provided.
#   It checks if the given file exists and, if so, determines the correct extraction command based on the file extension.
#   In dry-run mode, the command is printed using on_evict; otherwise, it is executed using shell::run_cmd_eval.
#
# Example:
#   unarchive archive.tar.gz           # Extracts archive.tar.gz.
#   unarchive -n archive.zip           # Prints the unzip command without executing it.
unarchive() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n).
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ $# -ne 1 ]; then
        echo "Usage: unarchive [-n] <filename>"
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
            shell::colored_echo "🔴 Error: '$file' cannot be extracted via unarchive()" 196
            return 1
            ;;
        esac

        if [ "$dry_run" = "true" ]; then
            on_evict "$cmd"
        else
            shell::run_cmd_eval "$cmd"
        fi
    else
        shell::colored_echo "🔴 Error: '$file' is not a valid file" 196
        return 1
    fi
}

# list_high_mem_usage function
# Displays processes with high memory consumption.
#
# Usage:
#   list_high_mem_usage [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
#
# Description:
#   This function retrieves the operating system type using shell::get_os_type. For macOS, it uses 'top' to sort processes by resident size (RSIZE)
#   and filters the output to display processes consuming at least 100 MB. For Linux, it uses 'ps' to list processes sorted by memory usage.
#   In dry-run mode, the constructed command is printed using on_evict; otherwise, it is executed using shell::run_cmd_eval.
#
# Example:
#   list_high_mem_usage       # Displays processes with high memory consumption.
#   list_high_mem_usage -n    # Prints the command without executing it.
list_high_mem_usage() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
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
        shell::colored_echo "🔴 Error: Unsupported OS for list_high_mem_usage function." 196
        return 1
    fi

    if [ "$dry_run" = "true" ]; then
        on_evict "$cmd"
    else
        shell::run_cmd_eval "$cmd"
    fi
}

# open_link function
# Opens the specified URL in the default web browser.
#
# Usage:
#   open_link [-n] <url>
#
# Parameters:
#   - -n   : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
#   - <url>: The URL to open in the default web browser.
#
# Description:
#   This function determines the current operating system using shell::get_os_type. On macOS, it uses the 'open' command;
#   on Linux, it uses 'xdg-open' (if available). If the required command is missing on Linux, an error is displayed.
#   In dry-run mode, the command is printed using on_evict; otherwise, it is executed using shell::run_cmd_eval.
#
# Example:
#   open_link https://example.com         # Opens the URL in the default browser.
#   open_link -n https://example.com      # Prints the command without executing it.
open_link() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n).
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    if [ -z "$1" ]; then
        echo "Usage: open_link [-n] <url>"
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
            shell::colored_echo "🔴 Error: xdg-open is not installed on Linux." 196
            return 1
        fi
    else
        shell::colored_echo "🔴 Error: Unsupported OS for open_link function." 196
        return 1
    fi

    if [ "$dry_run" = "true" ]; then
        on_evict "$cmd"
    else
        shell::run_cmd_eval "$cmd"
    fi
}

# loading_spinner function
# Displays a loading spinner in the console for a specified duration.
#
# Usage:
#   loading_spinner [-n] [duration]
#
# Parameters:
#   - -n        : Optional dry-run flag. If provided, the spinner command is printed using on_evict instead of executed.
#   - [duration]: Optional. The duration in seconds for which the spinner should be displayed. Default is 3 seconds.
#
# Description:
#   The function calculates an end time based on the provided duration and then iterates,
#   printing a sequence of spinner characters to create a visual loading effect.
#   In dry-run mode, it uses on_evict to display a message indicating what would be executed,
#   without actually running the spinner.
#
# Example usage:
#   loading_spinner          # Displays the spinner for 3 seconds.
#   loading_spinner 10       # Displays the spinner for 10 seconds.
#   loading_spinner -n 5     # Prints the spinner command for 5 seconds without executing it.
loading_spinner() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    local duration="${1:-3}" # Default duration is 3 seconds
    local spinner="/-\|"
    local end_time=$((SECONDS + duration))

    if [ "$dry_run" = "true" ]; then
        on_evict "Display loading spinner for ${duration} seconds"
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

# measure_time function
# Measures the execution time of a command and displays the elapsed time.
#
# Usage:
#   measure_time <command> [arguments...]
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
#   measure_time sleep 2    # Executes 'sleep 2' and displays the execution time.
measure_time() {
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
            shell::colored_echo "🕒 Execution time: ${seconds}s ${milliseconds}ms" 33
            return $exit_code
        else
            # Fallback: use SECONDS (resolution in seconds)
            local start_seconds=$SECONDS
            "$@"
            exit_code=$?
            local end_seconds=$SECONDS
            local elapsed_seconds=$((end_seconds - start_seconds))
            shell::colored_echo "🕒 Execution time: ${elapsed_seconds}s" 33
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
        shell::colored_echo "🕒 Execution time: ${seconds}s ${milliseconds}ms" 33
        return $exit_code
    fi
}

# async function
# Executes a command or function asynchronously (in the background).
#
# Usage:
#   async [-n] <command> [arguments...]
#
# Parameters:
#   - -n        : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
#   - <command> [arguments...]: The command (or function) with its arguments to be executed asynchronously.
#
# Description:
#   The async function builds the command from the provided arguments and runs it in the background.
#   If the optional dry-run flag (-n) is provided, the command is printed using on_evict instead of executing it.
#   Otherwise, the command is executed asynchronously using eval, and the process ID (PID) is displayed.
#
# Example:
#   async my_function arg1 arg2      # Executes my_function with arguments asynchronously.
#   async -n ls -l                   # Prints the 'ls -l' command that would be executed in the background.
async() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n).
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Build the command string from all arguments.
    local cmd="$*"

    if [ "$dry_run" = "true" ]; then
        on_evict "$cmd &"
        return 0
    else
        # Execute the command asynchronously (in the background)
        eval "$cmd" &
        local pid=$!
        shell::colored_echo "🕒 Async process started with PID: $pid" 33
        return 0
    fi
}

# execute_or_evict function
# Executes a command or prints it based on dry-run mode.
#
# Usage:
#   execute_or_evict <dry_run> <command>
#
# Parameters:
#   - <dry_run>: "true" to print the command, "false" to execute it.
#   - <command>: The command to execute or print.
#
# Example:
#   execute_or_evict "true" "echo Hello"
execute_or_evict() {
    local dry_run="$1"
    local command="$2"
    if [ "$dry_run" = "true" ]; then
        on_evict "$command"
    else
        shell::run_cmd_eval "$command"
    fi
}
