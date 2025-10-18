#!/bin/bash
# nodejs.sh

# shell::nodejs::gitignore::add function
# This function downloads the .gitignore file specifically for Node.js projects.
#
# The .gitignore file is crucial for specifying which files and directories
# should be ignored by Git, ensuring that the repository remains clean and
# free of unnecessary files that do not need to be tracked.
#
# It utilizes the shell::download_dataset function to fetch the .gitignore file
# from the specified URL and saves it in the appropriate location within the
# project structure.
shell::nodejs::gitignore::add() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Add .gitignore file for Node.js project"
		return $RETURN_SUCCESS
	fi
	shell::download_dataset ".gitignore" $SHELL_PROJECT_GITIGNORE_NODEJS
	return $RETURN_SUCCESS
}
