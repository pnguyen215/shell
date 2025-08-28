#!/bin/bash
# java.sh

# shell::add_java_gitignore function
# This function downloads the .gitignore file specifically for Java projects.
#
# The .gitignore file is essential for specifying which files and directories
# should be ignored by Git, helping to keep the repository clean and free of
# unnecessary files that do not need to be tracked.
#
# It utilizes the shell::download_dataset function to fetch the .gitignore file
# from the specified URL and saves it in the appropriate location within the
# project structure.
shell::add_java_gitignore() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Add .gitignore file for Java project"
		return $RETURN_SUCCESS
	fi
	shell::download_dataset ".gitignore" $SHELL_PROJECT_GITIGNORE_JAVA
	return $RETURN_SUCCESS
}
