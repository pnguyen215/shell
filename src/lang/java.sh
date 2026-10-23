#!/usr/bin/env bash
# @file lang/java.sh
# @brief Java project helpers.

# @description This function downloads the .gitignore file specifically for Java projects.
#
#   The .gitignore file is essential for specifying which files and directories
#   should be ignored by Git, helping to keep the repository clean and free of
#   unnecessary files that do not need to be tracked.
#
#   It utilizes the shell::net::download function to fetch the .gitignore file
#   from the specified URL and saves it in the appropriate location within the
#   project structure.
# @noargs
# @exitcode 0 Success.
# @example
#   shell::java::gitignore::add
#
shell::java::gitignore::add() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Add .gitignore file for Java project"
		return $RETURN_SUCCESS
	fi
	shell::net::download ".gitignore" "$SHELL_URL_GITIGNORE_JAVA"
	return $RETURN_SUCCESS
}
