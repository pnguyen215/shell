#!/bin/bash
# shell.sh - Main entry point for the shell library

# Define the shell library directory
# This variable sets the path to the shell library directory, defaulting to $HOME/shell if not already defined.
SHELL_DIR="${SHELL_DIR:-$HOME/shell}"
LIB_DIR="$SHELL_DIR/src/lib"
LANG_DIR="$SHELL_DIR/src/lang"
CONST_DIR="$SHELL_DIR/src/constant"
DEVOPS_DIR="$SHELL_DIR/src/devops"
LLM_DIR="$SHELL_DIR/src/llm"
SHIELD_DIR="$SHELL_DIR/src/shield"
BOT_DIR="$SHELL_DIR/src/bot"
LLM_AGENT_DIR="$SHELL_DIR/src/llm/agents"
LLM_PROMPTS_DIR="$SHELL_DIR/src/llm/prompts"

# This function sources all .sh scripts in the specified directory.
# It takes one argument: the directory containing the scripts.
# Scripts are sourced sequentially to ensure definitions are loaded in a predictable order.
#
# Usage:
#   shell::source_directory <directory_path>
#
# Parameters:
#   <directory_path>: The path to the directory containing .sh scripts to be sourced.
#
# Description:
#   The function checks if the provided path is a valid directory. If so, it iterates
#   through all files ending in .sh within that directory and sources them into the
#   current shell environment. This makes any functions or variables defined in
#   those scripts available for use. Error messages are suppressed for individual
#   source commands to keep the output clean, but the function checks for directory
#   existence.
#
# Example:
#   shell::source_directory "$LIB_DIR" # Sources all .sh files in the library directory.
shell::source_directory() {
	local dir="$1"

	# Check if the directory exists before attempting to source files.
	if [ -d "$dir" ]; then
		# Iterate through .sh files in the directory and source them.
		# Using a find loop is generally more robust than globbing for handling
		# filenames with spaces or special characters, although for simple .sh
		# files in a controlled environment, globbing might be slightly faster.
		# Sticking with a simple glob loop for potentially better performance
		# given the context of sourcing many small files, and assuming
		# standard file naming conventions for configuration/library scripts.
		for script in "$dir"/*.sh; do
			# Check if the file exists and is a regular file before sourcing.
			if [ -f "$script" ]; then
				# Source the script. Redirecting stdout and stderr to /dev/null
				# to prevent verbose output during sourcing unless there's a critical error.
				source "$script" >/dev/null 2>&1
			fi
		done
		# else
		# Optional: Add an error message if a directory is not found, but suppressing
		# this for cleaner output during standard sourcing.
		# shell::colored_echo "WARN: Warning: Source directory '$dir' not found." 11
	fi
}

# Source configuration, library, and language scripts in order.
# The callback functionality was removed as sourcing is synchronous and
# sequential execution of the directories ensures order.
shell::source_directory "$CONST_DIR"
shell::source_directory "$LIB_DIR"
shell::source_directory "$DEVOPS_DIR"
shell::source_directory "$LANG_DIR"
shell::source_directory "$LLM_DIR"
shell::source_directory "$SHIELD_DIR"
shell::source_directory "$BOT_DIR"
shell::source_directory "$LLM_AGENT_DIR"

# shell::version function
# This function outputs the current version of the shell library.
# It is useful for users to check which version they are running.
# Usage:
#   shell::version
# Example:
#   shell::version  # Outputs: shell v0.0.1
shell::version() {
	shell::retrieve_gh_latest_release "pnguyen215/shell"
}

# shell::upgrade function
# This function upgrades the shell library by removing the existing installation
# and downloading the latest version from the specified GitHub repository.
#
# Usage:
#   shell::upgrade
#
# Description:
#   - Displays a message indicating the upgrade process has started.
#   - Sets the installation directory to $HOME/shell.
#   - Removes the existing installation directory if it exists.
#   - Downloads and executes the install script from the GitHub repository.
#   - Informs the user that the shell has been upgraded and provides instructions
#     to restart the terminal or source the appropriate shell configuration file.
#
#   It checks for the presence of the source command in the user's .zshrc or .bashrc
#   files and executes the appropriate command to ensure the new version is loaded.
shell::upgrade() {
	local shell_pkg="$HOME/shell"
	if [ -d "$shell_pkg" ]; then
		rm -rf "$shell_pkg"
	fi

	# Download and install the latest version of the shell
	bash -c "$(curl -fsSL https://raw.githubusercontent.com/pnguyen215/shell/master/install.sh)"
	
	if [ -f "$HOME/.zshrc" ] && grep -q "source $shell_pkg/src/shell.sh" "$HOME/.zshrc"; then
		shell::logger::exec_check "source ~/.zshrc" "shell upgraded" "shell upgrade aborted"
	elif [ -f "$HOME/.bashrc" ] && grep -q "source $shell_pkg/src/shell.sh" "$HOME/.bashrc"; then
		shell::logger::exec_check "source ~/.bashrc" "shell upgraded" "shell upgrade aborted"
	else
		shell::logger::warn "No .zshrc found. Falling back to .bashrc."
		shell::logger::exec_check "source ~/.bashrc" "shell upgraded" "shell upgrade aborted"
	fi
}

# shell::uninstall function
# This function uninstalls the shell library by removing the installation directory
# and informing the user about the uninstallation process.
#
# Usage:
#   shell::uninstall
#
# Description:
#   - Displays a message indicating that the uninstallation process has started.
#   - Sets the installation directory to $HOME/shell.
#   - Checks if the installation directory exists; if it does, it removes it.
#   - Informs the user that the shell has been uninstalled and provides instructions
#     to manually remove the source command from their shell configuration file
#     (e.g., ~/.zshrc or ~/.bashrc).
shell::uninstall() {
	local shell_pkg="$HOME/shell"
	if [ -d "$shell_pkg" ]; then
		rm -rf "$shell_pkg"
	fi
	shell::logger::info "shell uninstalled. Please remove 'source $shell_pkg/src/shell.sh' from your shell config (e.g., ~/.zshrc or ~/.bashrc)."
}
