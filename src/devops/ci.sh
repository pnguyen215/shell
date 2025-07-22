#!/bin/bash
# ci.sh

# shell::add_gh_wrk_base function
# This function downloads the continuous integration (CI) workflow configuration file
# for the DevOps process from the specified GitHub repository.
#
# It utilizes the shell::download_dataset function to fetch the file and save it
# in the appropriate location within the project structure.
#
# The CI workflow file is essential for automating the build, test, and deployment
# processes in a continuous integration environment.
shell::add_gh_wrk_base() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ADD_GH_WRK_BASE"
        return 0
    fi
    shell::download_dataset ".github/workflows/gh_wrk_base.yml" $SHELL_PROJECT_GITHUB_WORKFLOW_BASE
}

# shell::add_gh_wrk_news function
# This function downloads the GitHub Actions CI notification workflow configuration file
# from the specified GitHub repository. This file is crucial for setting up automated
# notifications related to CI events, ensuring that relevant stakeholders are informed
# about the status of the CI processes.
#
# It utilizes the shell::download_dataset function to fetch the file and save it
# in the appropriate location within the project structure.
shell::add_gh_wrk_news() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ADD_GH_WRK_NEWS"
        return 0
    fi
    shell::download_dataset ".github/workflows/gh_wrk_news.yml" $SHELL_PROJECT_GITHUB_WORKFLOW_NEWS
}

# shell::add_gh_wrk_sh_pretty function
# This function downloads the GitHub Actions workflow configuration file for shell script
# formatting from the specified GitHub repository. This file is essential for
# automating the formatting of shell scripts in the project, ensuring consistency and
# adherence to coding standards.
# It utilizes the shell::download_dataset function to fetch the file and save it
# in the appropriate location within the project structure.
shell::add_gh_wrk_sh_pretty() {
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_ADD_GH_WRK_SH_PRETTY"
        return 0
    fi
    shell::download_dataset ".github/workflows/gh_wrk_sh_pretty.yml" $SHELL_PROJECT_GITHUB_WORKFLOW_SH_PRETTY
}
