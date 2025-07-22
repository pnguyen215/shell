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
        echo "$USAGE_SHELL_ADD_GITHUB_WORKFLOW_CI"
        return 0
    fi
    shell::download_dataset ".github/workflows/gh_wrk_base.yml" $SHELL_PROJECT_GITHUB_WORKFLOW_CI_RELEASE
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
    shell::download_dataset ".github/workflows/gh_wrk_news.yml" $SHELL_PROJECT_GITHUB_WORKFLOW_CI_NOTIFICATION_RELEASE
}
