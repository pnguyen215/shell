#!/bin/bash
# ci.sh

# shell::add_github_workflow_ci function
# This function downloads the continuous integration (CI) workflow configuration file
# for the DevOps process from the specified GitHub repository.
#
# It utilizes the shell::download_dataset function to fetch the file and save it
# in the appropriate location within the project structure.
#
# The CI workflow file is essential for automating the build, test, and deployment
# processes in a continuous integration environment.
shell::add_github_workflow_ci() {
    shell::download_dataset ".github/workflows/ci.yml" $SHELL_PROJECT_GITHUB_WORKFLOW_CI
}

# shell::add_github_workflow_ci_notification function
# This function downloads the GitHub Actions CI notification workflow configuration file
# from the specified GitHub repository. This file is crucial for setting up automated
# notifications related to CI events, ensuring that relevant stakeholders are informed
# about the status of the CI processes.
#
# It utilizes the shell::download_dataset function to fetch the file and save it
# in the appropriate location within the project structure.
shell::add_github_workflow_ci_notification() {
    shell::download_dataset ".github/workflows/ci_notify.yml" $SHELL_PROJECT_GITHUB_WORKFLOW_CI_NOTIFICATION
}
