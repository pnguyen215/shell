#!/bin/bash
# python.sh

# Install packages in a virtual environment using pip and venv
# Link: https://packaging.python.org/en/latest/guides/installing-using-pip-and-virtual-environments/

# shell::python::install function
# Installs Python (python3) on macOS or Linux.
#
# Usage:
#   shell::python::install [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
#
# Description:
#   Installs Python 3 using the appropriate package manager based on the OS:
#   - On Linux: Uses apt-get, yum, or dnf (detected automatically), with a specific check for package installation state.
#   - On macOS: Uses Homebrew, checking Homebrew's package list.
#   Skips installation only if Python is confirmed installed via the package manager.
#
# Example:
#   shell::python::install       # Installs Python 3.
#   shell::python::install -n    # Prints the installation command without executing it.
shell::python::install() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Install Python3"
		shell::logger::usage "shell::python::install [-n | --dry-run] [-h | --help]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::python::install"
		shell::logger::example "shell::python::install -n"
		shell::logger::example "shell::python::install --dry-run"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local os_type=$(shell::get_os_type)

	local cmd=""
	if [ "$os_type" = "linux" ]; then
		local package="python3"
		if shell::is_command_available apt-get; then
			cmd="sudo apt-get update && sudo apt-get install -y $package"
		elif shell::is_command_available yum; then
			cmd="sudo yum install -y $package"
		elif shell::is_command_available dnf; then
			cmd="sudo dnf install -y $package"
		else
			shell::logger::error "Unsupported package manager on Linux."
			return $RETURN_FAILURE
		fi
	elif [ "$os_type" = "macos" ]; then
		if ! shell::is_command_available brew; then
			shell::logger::debug "Installing Homebrew first..."
			shell::install_homebrew
		fi
		cmd="brew install python3"
	else
		shell::logger::error "Unsupported package manager on MacOS"
		return $RETURN_FAILURE
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::cmd_copy "$cmd"
		return $RETURN_SUCCESS
	fi

	local is_installed=$(shell::python::is_installed)
	if [ "$is_installed" = "true" ]; then
		shell::logger::warn "Python3 is already installed via package manager. Skipping."
		return $RETURN_NOT_IMPLEMENTED
	fi

	shell::logger::exec_check "$cmd"
}

# shell::python::is_installed function
# Checks if Python (python3) is installed on the system.
#
# Usage:
#   shell::python::is_installed
#
# Returns:
#   - "true" if Python is installed.
#   - "false" if Python is not installed.
#
# Description:
#   Verifies the installation of Python 3 using the appropriate package manager:
#   - On Linux: Checks apt-get, yum, or dnf package lists.
#   - On macOS: Checks Homebrew's package list.
#   Returns "true" if Python is found, otherwise "false".
#
# Example:
#   shell::python::is_installed  # Outputs "true" or "false" based on installation status.
shell::python::is_installed() {
	local os_type=$(shell::get_os_type)
	local python_version="python3"
	local is_installed="false"

	# Check installation state more precisely
	if [ "$os_type" = "linux" ]; then
		if shell::is_command_available apt-get && shell::is_package_installed_linux "$python_version"; then
			is_installed="true"
		elif shell::is_command_available yum && rpm -q "$python_version" >/dev/null 2>&1; then
			is_installed="true"
		elif shell::is_command_available dnf && rpm -q "$python_version" >/dev/null 2>&1; then
			is_installed="true"
		fi
	elif [ "$os_type" = "macos" ]; then
		if shell::is_command_available brew && brew list --versions "$python_version" >/dev/null 2>&1; then
			is_installed="true"
		fi
	fi

	echo "$is_installed"
	return $RETURN_SUCCESS
}

# shell::python::uninstall function
# Removes Python (python3) and its core components from the system.
#
# Usage:
#   shell::python::uninstall [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
#
# Description:
#   Thoroughly uninstalls Python 3 using the appropriate package manager:
#   - On Linux: Uses `purge` with apt-get or `remove` with yum/dnf, followed by autoremove to clean dependencies.
#   - On macOS: Uses Homebrew with cleanup to remove all traces.
#   Warns about potential system impact on Linux due to Python dependencies.
#
# Example:
#   shell::python::uninstall       # Removes Python 3.
#   shell::python::uninstall -n    # Prints the removal command without executing it.
#
# Notes:
#   - Requires sudo privileges.
#   - On Linux, system tools may break if Python is a core dependency; use with caution.
shell::python::uninstall() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Uninstall Python3"
		shell::logger::usage "shell::python::uninstall [-n | --dry-run] [-h | --help]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::python::uninstall"
		shell::logger::example "shell::python::uninstall -n"
		shell::logger::example "shell::python::uninstall --dry-run"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local is_installed=$(shell::python::is_installed)
	if [ "$is_installed" = "false" ]; then
		shell::logger::warn "Python3 is not installed."
		return $RETURN_NOT_IMPLEMENTED
	fi

	local os_type=$(shell::get_os_type)
	local cmd=""

	if [ "$os_type" = "linux" ]; then
		local package="python3"
		if shell::is_command_available apt-get; then
			if shell::is_package_installed_linux "$package"; then
				cmd="sudo apt-get purge -y $package && sudo apt-get autoremove -y"
			fi
		elif shell::is_command_available yum; then
			if rpm -q "$package" >/dev/null 2>&1; then
				cmd="sudo yum remove -y $package"
			fi
		elif shell::is_command_available dnf; then
			if rpm -q "$package" >/dev/null 2>&1; then
				cmd="sudo dnf remove -y $package"
			fi
		else
			shell::logger::error "Unsupported package manager on Linux."
			return $RETURN_FAILURE
		fi
	elif [ "$os_type" = "macos" ]; then
		if shell::is_command_available brew; then
			if brew list --versions python3 >/dev/null 2>&1; then
				cmd="brew uninstall python3 && brew cleanup"
			fi
		else
			shell::logger::error "Homebrew is not installed on macOS."
			return $RETURN_FAILURE
		fi
	else
		shell::logger::error "Unsupported operating system."
		return $RETURN_FAILURE
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::cmd_copy "$cmd"
		return $RETURN_SUCCESS
	fi

	shell::logger::exec_check "$cmd"
}

# shell::python::pip::uninstall function
# Uninstalls all pip and pip3 packages with user confirmation and optional dry-run.
#
# Usage:
#   shell::python::pip::uninstall [-n | --dry-run] [-h | --help] <pip_version>
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
#   - -h, --help : Displays this help message.
#   - pip_version : The pip version to uninstall (e.g., pip3, pip).
#
# Description:
#   Uninstalls all pip and pip3 packages using the specified pip version.
#   Prompts for confirmation before uninstalling.
#
# Example:
#   shell::python::pip::uninstall pip3       # Uninstalls all pip3 packages.
#   shell::python::pip::uninstall -n pip3    # Prints the uninstallation command without executing it.
#   shell::python::pip::uninstall --dry-run pip3  # Prints the uninstallation command without executing it.
#
# Notes:
#   - Requires sudo privileges.
shell::python::pip::uninstall() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Uninstall pip packages"
		shell::logger::usage "shell::python::pip::uninstall [-n | --dry-run] [-h | --help] <pip_version>"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::option "pip_version" "The pip version to uninstall (e.g., pip3, pip)"
		shell::logger::example "shell::python::pip::uninstall pip3"
		shell::logger::example "shell::python::pip::uninstall -n pip3"
		shell::logger::example "shell::python::pip::uninstall --dry-run pip3"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local pip_version="$1"
	if [ -z "$pip_version" ]; then
		shell::logger::error "pip version is required."
		return $RETURN_INVALID
	fi

	local pkg_files=$(mktemp)
	local freeze_cmd="$pip_version freeze --break-system-packages | grep -v '^-e' | grep -v '@' | cut -d= -f1 > $pkg_files"
	local uninstall_cmd="xargs $pip_version uninstall --break-system-packages -y < $pkg_files"
	local clean_up_cmd="rm $pkg_files"

	if [ "$dry_run" = "true" ]; then
		shell::logger::section "Uninstallation of $pip_version packages"
		shell::logger::step 1 "Freeze installed packages"
		shell::logger::cmd "$freeze_cmd"
		shell::logger::step 2 "Uninstall packages"
		shell::logger::cmd "$uninstall_cmd"
		shell::logger::step 3 "Clean up temporary files"
		shell::logger::cmd "$clean_up_cmd"
		return $RETURN_SUCCESS
	fi

	local is_installed=$(shell::python::is_installed)
	if [ "$is_installed" = "false" ]; then
		shell::logger::warn "Python3 is not installed."
		return $RETURN_NOT_IMPLEMENTED
	fi

	shell::logger::exec_check "$freeze_cmd"
	if [ -s "$pkg_files" ]; then
		shell::logger::exec_check "$uninstall_cmd"
	fi
	shell::logger::exec_check "$clean_up_cmd"
}

# shell::python::pip::uninstall_all function
# Uninstalls all pip and pip3 packages with user confirmation and optional dry-run.
#
# Usage:
#   shell::python::pip::uninstall_all [-n]
#
# Parameters:
#   -n: Optional flag to perform a dry-run (uses shell::logger::cmd_copy to print commands without executing).
#
# Description:
#   This function uninstalls all packages installed via pip and pip3, including system packages,
#   after user confirmation. It is designed to work on both Linux and macOS, with safety checks
#   and enhanced logging using shell::run_cmd_eval.
#
# Example usage:
#   shell::python::pip::uninstall_all       # Uninstalls all pip/pip3 packages after confirmation
#   shell::python::pip::uninstall_all -n    # Dry-run to preview commands
#
# Instructions:
#   1. Run the function with or without the -n flag.
#   2. Confirm the action when prompted (yes/y/Yes accepted).
#
# Notes:
#   - Use with caution: Uninstalling system packages may break your Python environment.
#   - Supports asynchronous execution via shell::async, though kept synchronous for user feedback.
#   - Temporary files are cleaned up automatically.
shell::python::pip::uninstall_all() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Uninstall all pip and pip3 packages"
		shell::logger::usage "shell::python::pip::uninstall_all [-n | --dry-run] [-h | --help]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::python::pip::uninstall_all"
		shell::logger::example "shell::python::pip::uninstall_all -n"
		shell::logger::example "shell::python::pip::uninstall_all --dry-run"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if [ "$dry_run" = "false" ]; then
		local asked=$(shell::ask "Are you absolutely sure you want to proceed?")
		if [ "$asked" = "no" ]; then
			shell::logger::warn "Uninstallation cancelled."
			return $RETURN_NOT_IMPLEMENTED
		fi
		if shell::is_command_available pip && shell::is_command_available pip3; then
			if [ "$(command -v pip)" = "$(command -v pip3)" ]; then
				shell::logger::warn "pip and pip3 are the same; uninstalling once."
				shell::python::pip::uninstall "pip"
			else
				shell::python::pip::uninstall "pip"
				shell::python::pip::uninstall "pip3"
			fi
		elif shell::is_command_available pip; then
			shell::python::pip::uninstall "pip"
		elif shell::is_command_available pip3; then
			shell::python::pip::uninstall "pip3"
		else
			shell::logger::warn "Neither pip nor pip3 is installed."
		fi
	fi

	if [ "$dry_run" = "true" ]; then
		shell::python::pip::uninstall -n "pip"
		shell::python::pip::uninstall -n "pip3"
	fi
	return $RETURN_SUCCESS
}

# shell::python::venv::create function
# Creates a Python virtual environment for development, isolating it from system packages.
#
# Usage:
#   shell::python::venv::create [-n] [-p <path>] [-v <version>]
#
# Parameters:
#   - -n          : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
#   - -p <path>   : Optional. Specifies the path where the virtual environment will be created (defaults to ./venv).
#   - -v <version>: Optional. Specifies the Python version (e.g., 3.10); defaults to system Python3.
#
# Description:
#   This function sets up a Python virtual environment to avoid package conflicts with the system OS:
#   - Ensures Python3 and pip are installed using shell::python::install.
#   - Creates a virtual environment at the specified or default path using the specified or default Python version.
#   - Upgrades pip and installs basic tools (wheel, setuptools) in the virtual environment.
#   - Supports asynchronous execution for pip upgrades to speed up setup.
#   - Verifies the environment and provides activation instructions.
#
# Example:
#   shell::python::venv::create                # Creates a virtual env at ./venv with default Python3.
#   shell::python::venv::create -n             # Prints commands without executing them.
#   shell::python::venv::create -p ~/my_env     # Creates a virtual env at ~/my_env.
#   shell::python::venv::create -v 3.10        # Uses Python 3.10 for the virtual env.
#
# Notes:
#   - Requires Python3 to be available on the system.
#   - On Linux, uses python3-venv package if needed.
#   - Activation command is copied to clipboard for convenience.
shell::python::venv::create() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Create Python virtual environment"
		shell::logger::usage "shell::python::venv::create [-n | --dry-run] [-h | --help] [-p | --path <path>] [-v | --version <version>]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::option "-p, --path" "Specify the path where the virtual environment will be created (defaults to ./venv)"
		shell::logger::option "-v, --version" "Specify the Python version (e.g., 3.10); defaults to system Python3"
		shell::logger::example "shell::python::venv::create -n -p ~/my_env -v 3.10"
		shell::logger::example "shell::python::venv::create -n -p ~/my_env"
		shell::logger::example "shell::python::venv::create -n"
		shell::logger::example "shell::python::venv::create -n -v 3.10"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	local venv_path="./venv"
	local python_version="python3"

	while [ $# -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		-p | --path)
			venv_path="$2"
			shift 2
			;;
		-v | --version)
			python_version="python$2"
			shift 2
			;;
		*)
			shell::logger::error "Invalid option: $1"
			return $RETURN_FAILURE
			;;
		esac
	done

	local os_type=$(shell::get_os_type)

	if [ "$dry_run" = "false" ]; then
		if ! shell::is_command_available "$python_version"; then
			shell::logger::debug "Installing $python_version..."
			if [ "$os_type" = "linux" ]; then
				shell::python::install
				if ! shell::is_package_installed_linux "$python_version-venv"; then
					shell::install_package "$python_version-venv"
				fi
			elif [ "$os_type" = "macos" ]; then
				shell::python::install
			else
				shell::logger::error "Unsupported operating system."
				return $RETURN_FAILURE
			fi
		fi
	fi

	if [ "$dry_run" = "false" ]; then
		if [ -d "$venv_path" ]; then
			shell::logger::warn "Virtual environment already exists at '$venv_path'. Skipping creation."
			local ask=$(shell::ask "Do you want to overwrite the existing virtual environment?")
			if [ "$ask" = "yes" ]; then
				shell::logger::debug "Overwriting existing virtual environment at '$venv_path'..."
				shell::remove_files "$venv_path"
			else
				shell::logger::warn "Skipping overwriting existing virtual environment."
				return $RETURN_SUCCESS
			fi
		fi
		shell::logger::debug "Creating virtual environment at '$venv_path' with $python_version..."
		local cmd="$python_version -m venv \"$venv_path\""
		shell::logger::exec_check "$cmd"
		if [ -d "$venv_path" ]; then
			shell::logger::info "Virtual environment created successfully at '$venv_path'."
		else
			shell::logger::error "Failed to create virtual environment."
			return $RETURN_FAILURE
		fi
		local pip_cmd="$venv_path/bin/pip"
		if shell::is_command_available "$pip_cmd"; then
			shell::logger::debug "Upgrading pip in the virtual environment at '$venv_path'..."
			local upgrade_cmd="$pip_cmd install --upgrade pip wheel setuptools"
			shell::logger::exec_check "$upgrade_cmd"
			if [ $? -eq 0 ]; then
				shell::logger::info "Pip upgraded successfully at '$venv_path'."
			else
				shell::logger::error "Failed to upgrade pip at '$venv_path'."
				return $RETURN_FAILURE
			fi
		fi
		local activate_cmd="source \"$venv_path/bin/activate\""
		shell::logger::info "Virtual environment created successfully at '$venv_path'."
		shell::logger::debug "To activate, run: $activate_cmd"
		shell::clip_value "$activate_cmd"
		return $RETURN_SUCCESS
	fi

	if [ "$dry_run" = "true" ]; then
		local cmd="$python_version -m venv \"$venv_path\""
		local upgrade_cmd="$venv_path/bin/pip install --upgrade pip wheel setuptools"
		local activate_cmd="source \"$venv_path/bin/activate\""
		shell::logger::section "Create Python virtual environment"
		shell::logger::step 1 "Creating virtual environment at '$venv_path' with $python_version..."
		shell::logger::cmd "$cmd"
		shell::logger::step 2 "Upgrading pip in the virtual environment..."
		shell::logger::cmd "$upgrade_cmd"
		shell::logger::step 3 "Activating virtual environment..."
		shell::logger::cmd "$activate_cmd"
		return $RETURN_SUCCESS
	fi
}

# shell::python::venv::pkg::install function
# Installs Python packages into an existing virtual environment using pip, avoiding system package conflicts.
#
# Usage:
#   shell::python::venv::pkg::install [-n] [-p <path>] <package1> [package2 ...]
#
# Parameters:
#   - -n          : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
#   - -p <path>   : Optional. Specifies the path to the virtual environment (defaults to ./venv).
#   - <package1> [package2 ...] : One or more Python package names to install (e.g., numpy, requests).
#
# Description:
#   This function installs specified Python packages into an existing virtual environment:
#   - Verifies the virtual environment exists at the specified or default path.
#   - Uses the virtual environment's pip to install packages, ensuring isolation from system Python.
#   - Supports asynchronous execution for package installation to improve performance.
#   - Provides feedback on success or failure, with dry-run support for previewing commands.
#
# Example:
#   shell::python::venv::pkg::install numpy pandas    # Installs numpy and pandas in ./venv.
#   shell::python::venv::pkg::install -n requests     # Prints installation command without executing.
#   shell::python::venv::pkg::install -p ~/my_env flask  # Installs flask in ~/my_env.
#
# Notes:
#   - Requires an existing virtual environment (use shell::python::venv::create to create one if needed).
#   - Assumes pip is available in the virtual environment (upgraded by shell::python::venv::create).
#   - Compatible with both Linux (Ubuntu 22.04 LTS) and macOS.
shell::python::venv::pkg::install() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Install Python packages into an existing virtual environment using pip."
		shell::logger::usage "Usage: shell::python::venv::pkg::install [-n | --dry-run] [-h | --help] [-p <path>] <package1> [package2 ...]"
		shell::logger::option "-n | --dry-run" "Preview installation commands without executing."
		shell::logger::option "-p | --path" "Specify the path to the virtual environment (default: ./venv)."
		shell::logger::option "<package1> [package2 ...]" "One or more Python package names to install (e.g., numpy, requests)."
		shell::logger::example "shell::python::venv::pkg::install numpy pandas"
		shell::logger::example "shell::python::venv::pkg::install -n requests"
		shell::logger::example "shell::python::venv::pkg::install -p ~/my_env flask"
		shell::logger::example "shell::python::venv::pkg::install -n -p ~/my_env flask"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	local venv_path="./venv"
	local packages=()

	# Parse optional arguments
	while [ $# -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		-p | --path)
			venv_path="$2"
			shift 2
			;;
		*)
			packages+=("$1")
			shift
			;;
		esac
	done

	# Validate that at least one package is specified
	if [ ${#packages[@]} -eq 0 ]; then
		shell::logger::error "No packages specified"
		return $RETURN_FAILURE
	fi

	local os_type=$(shell::get_os_type)
	local pip_cmd="$venv_path/bin/pip"

	if [ "$dry_run" = "false" ]; then
		# Check if the virtual environment exists
		if [ ! -d "$venv_path" ] || [ ! -f "$venv_path/bin/pip" ]; then
			shell::logger::error "Virtual environment at '$venv_path' does not exist or is invalid"
			return $RETURN_FAILURE
		fi

		# Ensure pip command is available
		if ! shell::is_command_available "$pip_cmd"; then
			shell::logger::error "pip not found in virtual environment at '$venv_path'"
			return $RETURN_FAILURE
		fi
	fi

	local install_cmd="$pip_cmd install"
	for pkg in "${packages[@]}"; do
		install_cmd="$install_cmd \"$pkg\""
	done

	if [ "$dry_run" = "true" ]; then
		shell::logger::cmd_copy "$install_cmd"
		return $RETURN_SUCCESS
	fi

	shell::logger::exec_check "$install_cmd"
}

# shell::python::venv::pkg::uninstall function
# Uninstalls Python packages from a virtual environment using pip or pip3.
#
# Usage:
#   shell::python::venv::pkg::uninstall [-n] [-p <path>] <package1> [package2 ...]
#
# Parameters:
#   - -n          : Optional dry-run flag.
#                     If provided, commands are printed using shell::logger::cmd_copy
#                     instead of executed.
#   - -p <path>   : Optional.
#                     Specifies the path to the virtual environment (defaults to ./venv).
#   - <package1> [package2 ...] : One or more Python package names to uninstall
#                     (e.g., numpy, requests).
#
# Description:
#   This function uninstalls specified Python packages from an existing virtual
#   environment:
#   - Verifies the virtual environment exists at the specified or default path.
#   - Uses the virtual environment's pip to uninstall packages, ensuring
#     uninstallation is isolated to the virtual environment.
#   - Supports asynchronous execution for package uninstallation to improve
#     performance.
#   - Provides feedback on success or failure, with dry-run support for
#     previewing commands.
#
# Example:
#   shell::python::venv::pkg::uninstall numpy pandas    # Uninstalls numpy and pandas from ./venv.
#   shell::python::venv::pkg::uninstall -n requests     # Prints uninstallation command without executing.
#   shell::python::venv::pkg::uninstall -p ~/my_env flask  # Uninstalls flask from ~/my_env.
#
# Notes:
#   - Requires an existing virtual environment (use shell::python::venv::create
#     to create one if needed).
#   - Assumes pip is available in the virtual environment.
#   - Compatible with both Linux (Ubuntu 22.04 LTS) and macOS.
shell::python::venv::pkg::uninstall() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Uninstall Python packages from an existing virtual environment using pip."
		shell::logger::usage "Usage: shell::python::venv::pkg::uninstall [-n | --dry-run] [-h | --help] [-p <path>] <package1> [package2 ...]"
		shell::logger::option "-n | --dry-run" "Preview uninstallation commands without executing."
		shell::logger::option "-p | --path" "Specify the path to the virtual environment (default: ./venv)."
		shell::logger::option "<package1> [package2 ...]" "One or more Python package names to uninstall (e.g., numpy, requests)."
		shell::logger::example "shell::python::venv::pkg::uninstall numpy pandas"
		shell::logger::example "shell::python::venv::pkg::uninstall -n requests"
		shell::logger::example "shell::python::venv::pkg::uninstall -p ~/my_env flask"
		shell::logger::example "shell::python::venv::pkg::uninstall -n -p ~/my_env flask"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	local venv_path="./venv"
	local packages=()

	# Parse optional arguments
	while [ $# -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		-p | --path)
			venv_path="$2"
			shift 2
			;;
		*)
			packages+=("$1")
			shift
			;;
		esac
	done

	# Validate that at least one package is specified
	if [ ${#packages[@]} -eq 0 ]; then
		shell::logger::error "No packages specified"
		return $RETURN_FAILURE
	fi

	local pip_cmd="$venv_path/bin/pip"

	if [ "$dry_run" = "false" ]; then
		# Check if the virtual environment exists
		if [ ! -d "$venv_path" ] || [ ! -f "$venv_path/bin/pip" ]; then
			shell::logger::error "Virtual environment at '$venv_path' does not exist or is invalid. Create it with shell::python::venv::create first."
			return $RETURN_FAILURE
		fi

		# Ensure pip command is available
		if ! shell::is_command_available "$pip_cmd"; then
			shell::logger::error "pip not found in virtual environment at '$venv_path'"
			return $RETURN_FAILURE
		fi
	fi

	local uninstall_cmd="$pip_cmd uninstall -y" # -y to skip confirmation
	for pkg in "${packages[@]}"; do
		uninstall_cmd="$uninstall_cmd \"$pkg\""
	done

	if [ "$dry_run" = "true" ]; then
		shell::logger::cmd_copy "$uninstall_cmd"
		return $RETURN_SUCCESS
	fi

	shell::logger::exec_check "$uninstall_cmd"
}

# shell::python::venv::pkg::uninstall_fzf function
# Interactively uninstalls Python packages from a virtual environment using fzf for package selection.
#
# Usage:
#   shell::python::venv::pkg::uninstall_fzf [-n] [-p <path>]
#
# Parameters:
#   - -n          : Optional dry-run flag.
#                     If provided, commands are printed using shell::logger::cmd_copy
#                     instead of executed.
#   - -p <path>   : Optional.
#                     Specifies the path to the virtual environment (defaults to ./venv).
#
# Description:
#   This function enhances Python package uninstallation by:
#   - Using fzf to allow interactive selection of packages to uninstall.
#   - Reusing shell::python::venv::pkg::uninstall to perform the actual uninstallation.
#   - Supports dry-run and asynchronous execution.
#
# Example:
#   shell::python::venv::pkg::uninstall_fzf          # Uninstalls packages from ./venv after interactive selection.
#   shell::python::venv::pkg::uninstall_fzf -n -p ~/my_env  # Prints uninstallation commands for ~/my_env without executing.
#
# Notes:
#   - Requires fzf and an existing virtual environment.
shell::python::venv::pkg::uninstall_fzf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Uninstall Python packages from an existing virtual environment using fzf for interactive selection."
		shell::logger::usage "Usage: shell::python::venv::pkg::uninstall_fzf [-n | --dry-run] [-h | --help] [-p <path>]"
		shell::logger::option "-n | --dry-run" "Preview uninstallation commands without executing."
		shell::logger::option "-p | --path" "Specify the path to the virtual environment (default: ./venv)."
		shell::logger::example "shell::python::venv::pkg::uninstall_fzf"
		shell::logger::example "shell::python::venv::pkg::uninstall_fzf -n -p ~/my_env"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	local venv_path="./venv"

	# Parse optional arguments
	while [ $# -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		-p | --path)
			venv_path="$2"
			shift 2
			;;
		*)
			shell::logger::error "Unknown option '$1'"
			return $RETURN_FAILURE
			;;
		esac
	done

	# Check if fzf is installed
	shell::install_package fzf
	local pip_cmd="$venv_path/bin/pip"

	# Check if the virtual environment exists
	if [ ! -d "$venv_path" ] || [ ! -f "$pip_cmd" ]; then
		shell::logger::error "Virtual environment at '$venv_path' does not exist or is invalid. Create it with shell::python::venv::create first."
		return $RETURN_FAILURE
	fi

	# Ensure pip command is available
	if ! shell::is_command_available "$pip_cmd"; then
		shell::logger::error "pip not found in virtual environment at '$venv_path'"
		return $RETURN_FAILURE
	fi

	# Get list of installed packages
	local installed_packages
	installed_packages=$("$pip_cmd" freeze | grep -v '^-e' | grep -v '@' | cut -d= -f1)

	# Use fzf to select packages to uninstall
	local selected_packages
	selected_packages=$(echo "$installed_packages" | fzf --multi --prompt="Select packages to uninstall: ")

	# Handle no selection
	if [ -z "$selected_packages" ]; then
		shell::logger::warn "No packages selected for uninstallation."
		return $RETURN_SUCCESS
	fi

	# Prepare arguments for shell::python::venv::pkg::uninstall
	local uninstall_args=()
	if [ "$dry_run" = "true" ]; then
		uninstall_args+=("-n")
	fi
	uninstall_args+=("-p")
	uninstall_args+=("$venv_path")

	# Add selected packages to the arguments
	IFS=$'\n'
	local selected_packages_array=()
	while IFS= read -r package; do
		selected_packages_array+=("$package")
	done <<<"$selected_packages"
	unset IFS

	uninstall_args+=("${selected_packages_array[@]}")

	if [ "$dry_run" = "true" ]; then
		shell::logger::section "Fzf: Uninstall Python packages from an existing virtual environment."
		shell::logger::step 1 "Get list of installed packages"
		shell::logger::cmd "$pip_cmd freeze | grep -v '^-e' | grep -v '@' | cut -d= -f1"
		shell::logger::step 2 "Selected packages to uninstall"
		shell::logger::cmd "\"$selected_packages\""
		shell::logger::step 3 "Uninstall selected packages"
		shell::logger::cmd "$pip_cmd uninstall ${selected_packages_array[@]}"
		return $RETURN_SUCCESS
	fi

	shell::python::venv::pkg::uninstall "${uninstall_args[@]}"
}

# shell::python::venv::activate_fzf function
# Interactively selects a Python virtual environment using fzf and activates/deactivates it.
#
# Usage:
#   shell::python::venv::activate_fzf [-n] [-p <path>]
#
# Parameters:
#   - -n          : Optional dry-run flag.
#                     If provided, commands are printed using shell::logger::cmd_copy
#                     instead of executed.
#   - -p <path>   : Optional.
#                     Specifies the parent path to search for virtual environments (defaults to current directory).
#
# Description:
#   This function enhances virtual environment management by:
#   - Using fzf to allow interactive selection of a virtual environment.
#   - Activating the selected virtual environment.
#   - Providing an option to deactivate the current environment.
#   - Supports dry-run.
#
# Example:
#   shell::python::venv::activate_fzf          # Select and activate a venv from the current directory.
#   shell::python::venv::activate_fzf -n -p ~/projects  # Prints activation command for a venv in ~/projects without executing.
#
# Notes:
#   - Requires fzf.
shell::python::venv::activate_fzf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a Python virtual environment using fzf and activates/deactivates it."
		shell::logger::usage "Usage: shell::python::venv::activate_fzf [-n | --dry-run] [-h | --help] [-p <path>]"
		shell::logger::option "-n | --dry-run" "Preview activation commands without executing."
		shell::logger::option "-p | --path" "Specify the parent path to search for virtual environments (default: current directory)."
		shell::logger::example "shell::python::venv::activate_fzf"
		shell::logger::example "shell::python::venv::activate_fzf -n -p ~/projects"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	local parent_path="." # Default to current directory

	# Parse optional arguments
	while [ $# -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		-p | --path)
			parent_path="$2"
			shift 2
			;;
		*)
			shell::logger::error "Unknown option '$1'"
			return $RETURN_FAILURE
			;;
		esac
	done

	# Check if fzf is installed
	shell::install_package fzf

	# Find virtual environments
	local venv_dirs=$(find "$parent_path" -type d -name "bin" -print0 | xargs -0 -I {} dirname {} | grep -v "__pycache__")

	# Use fzf to select a virtual environment
	local selected_venv=$(echo "$venv_dirs" | fzf --prompt="Select a virtual environment: ")

	# Handle no selection
	if [ -z "$selected_venv" ]; then
		shell::logger::warn "No virtual environment selected."
		return $RETURN_SUCCESS
	fi

	# Construct the activation command
	local activate_cmd="source \"$selected_venv/bin/activate\""
	local deactivate_cmd=""

	# Handle deactivation if already in a virtual environment
	if [ -n "$VIRTUAL_ENV" ]; then
		local ask=$(shell::ask "Do you want to deactivate it first?")
		if [ "$ask" = "yes" ]; then
			deactivate_cmd="deactivate"
		fi
	fi

	if [ "$dry_run" = "true" ]; then
		local step=1
		shell::logger::section "Fzf: Activate a Python virtual environment."
		shell::logger::step $((step++)) "Find virtual environments"
		shell::logger::cmd "find \"$parent_path\" -type d -name \"bin\" -print0 | xargs -0 -I {} dirname {} | grep -v \"__pycache__\""
		shell::logger::step $((step++)) "Selected virtual environment"
		shell::logger::cmd "\"$selected_venv\""
		if [ -n "$deactivate_cmd" ]; then
			shell::logger::step $((step++)) "Deactivate current environment"
			shell::logger::cmd "$deactivate_cmd"
		fi
		shell::logger::step $((step++)) "Activate selected environment"
		shell::logger::cmd "$activate_cmd"
		return $RETURN_SUCCESS
	fi

	if [ -n "$deactivate_cmd" ]; then
		shell::logger::exec_check "$deactivate_cmd"
	fi

	shell::logger::exec_check "$activate_cmd"
}

# shell::python::venv::pkg::upgrade function
# Upgrades Python packages in a virtual environment using pip.
#
# Usage:
#   shell::python::venv::pkg::upgrade [-n] [-p <path>] <package1> [package2 ...]
#
# Parameters:
#   - -n          : Optional dry-run flag.
#                     If provided, commands are printed using shell::logger::cmd_copy instead of executed.
#   - -p <path>   : Optional.
#                     Specifies the path to the virtual environment (defaults to ./venv).
#   - <package1> [package2 ...]: One or more Python package names to upgrade.
#
# Description:
#   This function upgrades specified Python packages within an existing virtual environment:
#   - Verifies the virtual environment exists at the specified or default path.
#   - Uses the virtual environment's pip to upgrade packages.
#   - Supports dry-run mode to preview commands.
#   - Implements asynchronous execution for the upgrade process.
#
# Example:
#   shell::python::venv::pkg::upgrade numpy pandas   # Upgrades numpy and pandas in ./venv.
#   shell::python::venv::pkg::upgrade -n requests    # Prints upgrade command without executing.
#   shell::python::venv::pkg::upgrade -p ~/my_env flask  # Upgrades flask in ~/my_env.
#
# Notes:
#   - Requires an existing virtual environment.
#   - Assumes pip is available in the virtual environment.
shell::python::venv::pkg::upgrade() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Upgrades Python packages in a virtual environment using pip."
		shell::logger::usage "Usage: shell::python::venv::pkg::upgrade [-n] [-p <path>] <package1> [package2 ...]"
		shell::logger::option "-n" "Preview upgrade commands without executing."
		shell::logger::option "-p <path>" "Specify the path to the virtual environment (default: ./venv)."
		shell::logger::example "shell::python::venv::pkg::upgrade numpy pandas"
		shell::logger::example "shell::python::venv::pkg::upgrade -n requests"
		shell::logger::example "shell::python::venv::pkg::upgrade -p ~/my_env flask"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	local venv_path="./venv"
	local packages=()

	# Parse optional arguments
	while [ $# -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		-p | --path)
			venv_path="$2"
			shift 2
			;;
		*)
			packages+=("$1")
			shift
			;;
		esac
	done

	# Validate that at least one package is specified
	if [ ${#packages[@]} -eq 0 ]; then
		shell::logger::error "No packages specified."
		return $RETURN_FAILURE
	fi

	local pip_cmd="$venv_path/bin/pip"

	# Check if the virtual environment exists
	if [ ! -d "$venv_path" ] || [ ! -f "$pip_cmd" ]; then
		shell::logger::error "Virtual environment at '$venv_path' does not exist or is invalid."
		return $RETURN_FAILURE
	fi

	# Ensure pip command is available
	if ! shell::is_command_available "$pip_cmd"; then
		shell::logger::error "pip not found in virtual environment at '$venv_path'."
		return $RETURN_FAILURE
	fi

	# Construct the upgrade command
	local upgrade_cmd="$pip_cmd install --upgrade"
	for pkg in "${packages[@]}"; do
		upgrade_cmd="$upgrade_cmd \"$pkg\""
	done

	if [ "$dry_run" = "true" ]; then
		shell::logger::cmd "$upgrade_cmd"
		return $RETURN_SUCCESS
	fi

	shell::logger::exec_check "$upgrade_cmd"
}

# shell::python::venv::pkg::upgrade_fzf function
# Interactively upgrades Python packages in a virtual environment using fzf for package selection.
#
# Usage:
#   shell::python::venv::pkg::upgrade_fzf [-n] [-p <path>]
#
# Parameters:
#   - -n          : Optional dry-run flag.
#                     If provided, commands are printed using shell::logger::cmd_copy
#                     instead of executed.
#   - -p <path>   : Optional.
#                     Specifies the path to the virtual environment (defaults to ./venv).
#
# Description:
#   This function provides an interactive way to upgrade Python packages within a virtual environment by:
#   - Using fzf to allow selection of packages to upgrade.
#   - Constructing and executing pip upgrade commands.
#   - Supporting dry-run mode to preview commands.
#
# Example:
#   shell::python::venv::pkg::upgrade_fzf          # Upgrades packages in ./venv after interactive selection.
#   shell::python::venv::pkg::upgrade_fzf -n -p ~/my_env  # Prints upgrade commands for ~/my_env without executing.
#
# Notes:
#   - Requires fzf and an existing virtual environment.
shell::python::venv::pkg::upgrade_fzf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively upgrades Python packages in a virtual environment using fzf for package selection."
		shell::logger::usage "Usage: shell::python::venv::pkg::upgrade_fzf [-n | --dry-run] [-h | --help] [-p <path>]"
		shell::logger::option "-n | --dry-run" "Preview upgrade commands without executing."
		shell::logger::option "-p | --path" "Specify the path to the virtual environment (default: ./venv)."
		shell::logger::example "shell::python::venv::pkg::upgrade_fzf"
		shell::logger::example "shell::python::venv::pkg::upgrade_fzf -n -p ~/my_env"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	local venv_path="./venv"

	# Parse optional arguments
	while [ $# -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		-p | --path)
			venv_path="$2"
			shift 2
			;;
		*)
			shell::logger::error "Unknown option '$1'"
			return $RETURN_FAILURE
			;;
		esac
	done

	# Check if fzf is installed
	shell::install_package fzf
	local pip_cmd="$venv_path/bin/pip"

	# Check if the virtual environment exists
	if [ ! -d "$venv_path" ] || [ ! -f "$pip_cmd" ]; then
		shell::logger::error "Virtual environment at '$venv_path' does not exist or is invalid."
		return $RETURN_FAILURE
	fi

	# Ensure pip command is available
	if ! shell::is_command_available "$pip_cmd"; then
		shell::logger::error "pip not found in virtual environment at '$venv_path'."
		return $RETURN_FAILURE
	fi

	# Get list of installed packages
	local installed_packages="$("$pip_cmd" freeze | grep -v '^-e' | grep -v '@' | cut -d= -f1)"

	# Use fzf to select packages to upgrade
	local selected_packages=$(echo "$installed_packages" | fzf --multi --prompt="Select packages to upgrade: ")

	# Handle no selection
	if [ -z "$selected_packages" ]; then
		shell::logger::warn "No packages selected for upgrade."
		return $RETURN_SUCCESS
	fi

	# Prepare upgrade commands
	local upgrade_commands=()
	IFS=$'\n'
	local selected_packages_array=()
	while IFS= read -r package; do
		selected_packages_array+=("$package")
	done <<<"$selected_packages"
	unset IFS

	for pkg in "${selected_packages_array[@]}"; do
		upgrade_commands+=("$pip_cmd install --upgrade \"$pkg\"")
	done

	if [ "$dry_run" = "true" ]; then
		local step=1
		shell::logger::section "Fzf: Interactively upgrades Python packages in a virtual environment"
		shell::logger::step $((step++)) "Get list of installed packages"
		shell::logger::cmd "\"$pip_cmd freeze | grep -v '^-e' | grep -v '@' | cut -d= -f1\""
		shell::logger::step $((step++)) "Selected packages for upgrade"
		shell::logger::cmd "\"$selected_packages\""
		shell::logger::step $((step++)) "Upgrade commands"
		for cmd in "${upgrade_commands[@]}"; do
			shell::logger::cmd "$cmd"
		done
		return $RETURN_SUCCESS
	fi
	
	for cmd in "${upgrade_commands[@]}"; do
		shell::logger::exec_check "$cmd"
	done
}

# shell::python::venv::pkg::freeze function
# Exports a list of installed packages and their versions from a Python virtual environment to a requirements.txt file.
#
# Usage:
#   shell::python::venv::pkg::freeze [-n] [-p <path>]
#
# Parameters:
#   - -n          : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
#   - -p <path>   : Optional. Specifies the path to the virtual environment (defaults to ./venv).
#
# Description:
#   This function uses pip freeze to generate a requirements.txt file, capturing the current state of the virtual environment's packages.
#   - It checks for the existence of the virtual environment.
#   - It constructs the appropriate pip freeze command.
#   - It supports dry-run mode to preview the command.
#   - It implements asynchronous execution for the freeze operation.
#
# Example:
#   shell::python::venv::pkg::freeze         # Exports requirements from ./venv.
#   shell::python::venv::pkg::freeze -n -p ~/my_env  # Prints the export command for ~/my_env without executing.
#
# Notes:
#   - Requires an existing virtual environment.
#   - Assumes pip is available in the virtual environment.
shell::python::venv::pkg::freeze() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Exports a list of installed packages and their versions from a Python virtual environment to a requirements.txt file."
		shell::logger::usage "shell::python::venv::pkg::freeze [-n | --dry-run] [-h | --help] [-p <path>]"
		shell::logger::option "-n | --dry-run" "Preview export commands without executing."
		shell::logger::option "-p | --path" "Specify the path to the virtual environment (default: ./venv)."
		shell::logger::example "shell::python::venv::pkg::freeze"
		shell::logger::example "shell::python::venv::pkg::freeze -n -p ~/my_env"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	local venv_path="./venv"

	# Parse optional arguments
	while [ $# -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		-p | --path)
			venv_path="$2"
			shift 2
			;;
		*)
			shell::logger::error "Unknown option '$1'"
			return $RETURN_FAILURE
			;;
		esac
	done

	local pip_cmd="$venv_path/bin/pip"

	# Check if the virtual environment exists
	if [ ! -d "$venv_path" ] || [ ! -f "$pip_cmd" ]; then
		shell::logger::error "Virtual environment at '$venv_path' does not exist or is invalid."
		return $RETURN_FAILURE
	fi

	# Ensure pip command is available
	if ! shell::is_command_available "$pip_cmd"; then
		shell::logger::error "pip not found in virtual environment at '$venv_path'."
		return $RETURN_FAILURE
	fi

	# Construct the freeze command
	local freeze_cmd="$pip_cmd freeze > $venv_path/requirements.txt"

	if [ "$dry_run" = "true" ]; then
		shell::logger::cmd_copy "$freeze_cmd"
		return $RETURN_SUCCESS
	fi

	shell::logger::exec_check "$freeze_cmd"
}

# shell::pip_install_requirements_env function
# Installs Python packages from a requirements.txt file into a virtual environment.
#
# Usage:
#   shell::pip_install_requirements_env [-n] [-p <path>]
#
# Parameters:
#   - -n          : Optional dry-run flag. If provided, commands are printed using shell::logger::cmd_copy instead of executed.
#   - -p <path>   : Optional. Specifies the path to the virtual environment (defaults to ./venv).
#
# Description:
#   This function uses pip install -r to install packages from a requirements.txt file into the specified virtual environment.
#   - It checks for the existence of the virtual environment and the requirements.txt file.
#   - It constructs the appropriate pip install command.
#   - It supports dry-run mode to preview the command.
#   - It implements asynchronous execution for the installation process.
#
# Example:
#   shell::pip_install_requirements_env         # Installs from requirements.txt in ./venv.
#   shell::pip_install_requirements_env -n -p ~/my_env  # Prints the installation command for ~/my_env without executing.
#
# Notes:
#   - Requires an existing virtual environment and a requirements.txt file.
#   - Assumes pip is available in the virtual environment.
shell::pip_install_requirements_env() {
	if [ "$1" = "-h" ]; then
		echo "$USAGE_SHELL_PIP_INSTALL_REQUIREMENTS_ENV"
		return 0
	fi

	local dry_run="false"
	local venv_path="./venv"

	# Parse optional arguments
	while [ $# -gt 0 ]; do
		case "$1" in
		-n)
			dry_run="true"
			shift
			;;
		-p)
			venv_path="$2"
			shift 2
			;;
		*)
			shell::stdout "ERR: Unknown option '$1'." 196
			shell::stdout "Usage: shell::pip_install_requirements_env [-n] [-p <path>]"
			return 1
			;;
		esac
	done

	# Check if the virtual environment exists
	if [ ! -d "$venv_path" ] || [ ! -f "$venv_path/bin/pip" ]; then
		shell::stdout "ERR: Virtual environment at '$venv_path' does not exist or is invalid." 196
		return 1
	fi

	# Construct path to requirements.txt
	local requirements_file="$venv_path/requirements.txt"

	# Check if the requirements.txt file exists
	if [ ! -f "$requirements_file" ]; then
		shell::stdout "ERR: requirements.txt file not found at '$requirements_file'." 196
		return 1
	fi

	local pip_cmd="$venv_path/bin/pip"

	# Ensure pip command is available
	if ! shell::is_command_available "$pip_cmd"; then
		shell::stdout "ERR: pip not found in virtual environment at '$venv_path'." 196
		return 1
	fi

	# Construct the install command
	local install_cmd="$pip_cmd install -r $requirements_file"

	# Execute or preview the install command
	shell::stdout "🔍 Installing packages from $requirements_file into $venv_path..." 36
	if [ "$dry_run" = "true" ]; then
		shell::logger::cmd_copy "$install_cmd"
	else
		# Execute the install command asynchronously
		shell::async "$install_cmd" &
		local pid=$!
		wait $pid
		if [ $? -eq 0 ]; then
			shell::stdout "INFO: Packages installed successfully from $requirements_file." 46
		else
			shell::stdout "ERR: Failed to install packages." 196
			return 1
		fi
	fi
}

# shell::add_python_gitignore function
# This function downloads the .gitignore file specifically for Python projects.
#
# The .gitignore file is essential for specifying which files and directories
# should be ignored by Git, helping to keep the repository clean and free of
# unnecessary files that do not need to be tracked.
#
# It utilizes the shell::download_dataset function to fetch the .gitignore file
# from the specified URL and saves it in the appropriate location within the
# project structure.
shell::add_python_gitignore() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Add .gitignore file for Python project"
		return $RETURN_SUCCESS
	fi
	shell::download_dataset ".gitignore" $SHELL_PROJECT_GITIGNORE_PYTHON
	return $RETURN_SUCCESS
}
