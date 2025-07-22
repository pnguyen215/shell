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
	if [ "$1" = "-h" ]; then
		echo "$USAGE_SHELL_ADD_JAVA_GITIGNORE"
		return 0
	fi
	shell::download_dataset ".gitignore" $SHELL_PROJECT_GITIGNORE_JAVA
}
