#!/usr/bin/env bash
# @file lang/angular.sh
# @brief Angular project helpers.

# @description This function downloads the .gitignore file specifically for Angular projects.
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
#   shell::angular::gitignore::add
#
shell::angular::gitignore::add() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Add .gitignore file for Angular project"
		return $RETURN_SUCCESS
	fi
	shell::net::download ".gitignore" "$SHELL_URL_GITIGNORE_ANGULAR"
	return $RETURN_SUCCESS
}
