#!/usr/bin/env bash
# @file lang/nodejs.sh
# @brief Node.js project helpers.

# @description This function downloads the .gitignore file specifically for Node.js projects.
#
#   The .gitignore file is crucial for specifying which files and directories
#   should be ignored by Git, ensuring that the repository remains clean and
#   free of unnecessary files that do not need to be tracked.
#
#   It utilizes the shell::net::download function to fetch the .gitignore file
#   from the specified URL and saves it in the appropriate location within the
#   project structure.
# @noargs
# @exitcode 0 Success.
# @example
#   shell::nodejs::gitignore::add
#
shell::nodejs::gitignore::add() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Add .gitignore file for Node.js project"
		return $RETURN_SUCCESS
	fi
	shell::net::download ".gitignore" "$SHELL_URL_GITIGNORE_NODEJS"
	return $RETURN_SUCCESS
}
