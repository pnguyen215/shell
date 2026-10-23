#!/usr/bin/env bash
# @file devops/ci.sh
# @brief GitHub Actions workflow scaffolding.

# @description This function downloads the continuous integration (CI) workflow configuration file
#   for the DevOps process from the specified GitHub repository.
#
#   It utilizes the shell::net::download function to fetch the file and save it
#   in the appropriate location within the project structure.
#
#   The CI workflow file is essential for automating the build, test, and deployment
#   processes in a continuous integration environment.
# @noargs
# @exitcode 0 Success.
# @example
#   shell::gh::workflow::base::add
#
shell::gh::workflow::base::add() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Add GitHub Actions workflow file for continuous integration"
		return $RETURN_SUCCESS
	fi
	shell::net::download ".github/workflows/gh_wrk_base.yml" "$SHELL_URL_WORKFLOW_BASE"
	return $RETURN_SUCCESS
}

# @description This function downloads the GitHub Actions CI notification workflow configuration file
#   from the specified GitHub repository. This file is crucial for setting up automated
#   notifications related to CI events, ensuring that relevant stakeholders are informed
#   about the status of the CI processes.
#
#   It utilizes the shell::net::download function to fetch the file and save it
#   in the appropriate location within the project structure.
# @noargs
# @exitcode 0 Success.
# @example
#   shell::gh::workflow::news::add
#
shell::gh::workflow::news::add() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Add GitHub Actions workflow file for continuous integration notification"
		return $RETURN_SUCCESS
	fi
	shell::net::download ".github/workflows/gh_wrk_news.yml" "$SHELL_URL_WORKFLOW_NEWS"
	return $RETURN_SUCCESS
}

# @description This function downloads the GitHub Actions workflow configuration file for shell script
#   formatting from the specified GitHub repository. This file is essential for
#   automating the formatting of shell scripts in the project, ensuring consistency and
#   adherence to coding standards.
#   It utilizes the shell::net::download function to fetch the file and save it
#   in the appropriate location within the project structure.
# @noargs
# @exitcode 0 Success.
# @example
#   shell::gh::workflow::bash::add_format
#
shell::gh::workflow::bash::add_format() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Add GitHub Actions workflow file for shell script formatting"
		return $RETURN_SUCCESS
	fi
	shell::net::download ".github/workflows/gh_wrk_sh_pretty.yml" "$SHELL_URL_WORKFLOW_SH_PRETTY"
	return $RETURN_SUCCESS
}

# @description This function downloads the GitHub Actions workflow configuration file for Go language
#   notifications from the specified GitHub repository. This file is crucial for
#   automating notifications related to Go language CI events, ensuring that relevant
#   stakeholders are informed about the status of the Go language CI processes.
#   It utilizes the shell::net::download function to fetch the file and save it
#   in the appropriate location within the project structure.
# @noargs
# @exitcode 0 Success.
# @example
#   shell::gh::workflow::go::news::add
#
shell::gh::workflow::go::news::add() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Add GitHub Actions workflow file for Go language notification"
		return $RETURN_SUCCESS
	fi
	shell::net::download ".github/workflows/gh_wrk_news_go.yml" "$SHELL_URL_WORKFLOW_NEWS_GO"
	return $RETURN_SUCCESS
}
