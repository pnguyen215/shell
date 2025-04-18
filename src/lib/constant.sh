#!/bin/bash
# constant.sh

# SHELL_CONF_WORKING constant
# This variable defines the working directory where the shell configuration files are stored.
# It is used as the base directory for both the key configuration file (SHELL_KEY_CONF_FILE) and the group configuration file (SHELL_GROUP_CONF_FILE).
# By default, this is set to "$HOME/.shell-config". You can change this value if you want to store your configuration files in a different location.
#
# Example:
#   SHELL_CONF_WORKING="$HOME/.shell-config"
readonly SHELL_CONF_WORKING="$HOME/.shell-config"

# SHELL_CONF_WORKING_WORKSPACE constant
# This variable defines the path to the workspace directory within the shell configuration working directory.
# It is used to store user-specific or profile-specific configurations and data.
# This separation helps in organizing configuration files related to different profiles or projects.
#
# Example:
#   SHELL_CONF_WORKING_WORKSPACE="$SHELL_CONF_WORKING/workspace"
readonly SHELL_CONF_WORKING_WORKSPACE="$SHELL_CONF_WORKING/workspace"

# SHELL_KEY_CONF_FILE constant
# This variable defines the path to the key configuration file used by the shell bash library.
# The file stores individual configuration entries in the following format:
#   key=encoded_value
# where each value is encoded using Base64 (with newlines removed).
# Functions such as shell::add_conf, shell::get_conf, update_conf, and shell::remove_conf use this file to store and manage configuration settings.
#
# Example:
#   SHELL_KEY_CONF_FILE="$HOME/.shell-config/key.conf"
readonly SHELL_KEY_CONF_FILE="$SHELL_CONF_WORKING/key.conf"

# SHELL_KEY_CONF_FILE_WORKSPACE constant
# This variable defines the path to the profile-specific configuration file within the workspace directory.
# It is used to store configuration settings specific to a user's profile, allowing for personalized shell environments.
# This file typically contains settings that override or complement the main key configuration file.
#
# Example:
#   SHELL_KEY_CONF_FILE_WORKSPACE="$SHELL_CONF_WORKING_WORKSPACE/profile.conf"
readonly SHELL_KEY_CONF_FILE_WORKSPACE="$SHELL_CONF_WORKING_WORKSPACE/profile.conf"

# SHELL_KEY_CONF_SETTING_WORKSPACE constant
# This variable defines the path to the settings configuration file within the workspace directory.
# It is used to store user-specific settings that may affect the behavior of the shell environment.
# This file can include various configurations that are not tied to specific keys or groups.
#
# Example:
#   SHELL_KEY_CONF_SETTING_WORKSPACE="$SHELL_CONF_WORKING_WORKSPACE/settings.conf"
readonly SHELL_KEY_CONF_SETTING_WORKSPACE="$SHELL_CONF_WORKING_WORKSPACE/settings.conf"

# SHELL_GROUP_CONF_FILE constant
# This variable defines the path to the group configuration file used by the shell bash library.
# The file stores group definitions in the following format:
#   group_name=key1,key2,...,keyN
# Each group maps a name to a comma-separated list of keys from the key configuration file.
# Functions such as add_group, read_group, remove_group, update_group, and clone_group use this file
# to manage groups of configuration keys.
#
# Example:
#   SHELL_GROUP_CONF_FILE="$HOME/.shell-config/group.conf"
readonly SHELL_GROUP_CONF_FILE="$SHELL_CONF_WORKING/group.conf"

# SHELL_GH_CONF_FILE constant
# This variable defines the path to the GitHub configuration file used by the shell bash library.
# The file is intended to store settings related to GitHub or git activity, such as API tokens,
# repository preferences, or other git-related configurations.
#
# Example:
#   SHELL_GH_CONF_FILE="$HOME/.shell-config/gh.conf"
readonly SHELL_GH_CONF_FILE="$SHELL_CONF_WORKING/gh.conf"

# SHELL_PROTECTED_KEYS array
# This array lists configuration keys that are considered constant and must not be removed, updated,
# or renamed through interactive functions.
#
# You can include keys that are critical for the shell's operation, security, or stability.
#
# Example:
#   SHELL_PROTECTED_KEYS=("HOST" "PORT" "API_TOKEN")
readonly SHELL_PROTECTED_KEYS=("HOST" "PORT" "SHELL_DEVELOPER" "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN" "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID")

# SHELL_C_AES_RED constant
# This variable defines the ANSI escape code for red text color. It is used to highlight error messages or critical alerts in the shell.
if [ -z "${SHELL_C_AES_RED+x}" ]; then
    declare -gr SHELL_C_AES_RED="\\033[0;31m"
fi

# SHELL_C_AES_RESET constant
# This variable defines the ANSI escape code to reset text formatting to default. It is used to clear any previous text color or style.
if [ -z "${SHELL_C_AES_RESET+x}" ]; then
    declare -gr SHELL_C_AES_RESET="\\033[0m"
fi

# SHELL_C_AES_YELLOW constant
# This variable defines the ANSI escape code for yellow text color. It is used to highlight warnings or important information in the shell.
if [ -z "${SHELL_C_AES_YELLOW+x}" ]; then
    declare -gr SHELL_C_AES_YELLOW="\\033[0;33m"
fi

##########Developers Settings#############
######### Aris Nguyen 2025 ###############
##########Developers Settings#############

# SHELL_PROJECT_GITIGNORE_GO constant
# This variable holds the URL to the Go .gitignore template. It is used to provide a standard .gitignore file for Go projects.
readonly SHELL_PROJECT_GITIGNORE_GO="https://raw.githubusercontent.com/pnguyen215/wsdkit.keys/master/gitignores/go_gitignore.txt"

# SHELL_PROJECT_GITIGNORE_JAVA constant
# This variable holds the URL to the Java .gitignore template. It is used to provide a standard .gitignore file for Java projects.
readonly SHELL_PROJECT_GITIGNORE_JAVA="https://raw.githubusercontent.com/pnguyen215/wsdkit.keys/master/gitignores/java_gitignore.txt"

# SHELL_PROJECT_GITIGNORE_ANGULAR constant
# This variable holds the URL to the Angular .gitignore template. It is used to provide a standard .gitignore file for Angular projects.
readonly SHELL_PROJECT_GITIGNORE_ANGULAR="https://raw.githubusercontent.com/pnguyen215/wsdkit.keys/master/gitignores/angular_gitignore.txt"

# SHELL_PROJECT_GITIGNORE_NODEJS constant
# This variable holds the URL to the Node.js .gitignore template. It is used to provide a standard .gitignore file for Node.js projects.
readonly SHELL_PROJECT_GITIGNORE_NODEJS="https://raw.githubusercontent.com/pnguyen215/wsdkit.keys/master/gitignores/node.js_gitignore.txt"

# SHELL_PROJECT_GITIGNORE_PYTHON constant
# This variable holds the URL to the Python .gitignore template. It is used to provide a standard .gitignore file for Python projects.
readonly SHELL_PROJECT_GITIGNORE_PYTHON="https://raw.githubusercontent.com/pnguyen215/wsdkit.keys/master/gitignores/python3_gitignore.txt"

# SHELL_PROJECT_GITHUB_WORKFLOW_CI constant
# This variable holds the URL to the GitHub Actions CI workflow configuration file.
# It is used to define the continuous integration process for projects using GitHub.
readonly SHELL_PROJECT_GITHUB_WORKFLOW_CI="https://raw.githubusercontent.com/pnguyen215/wsdkit.keys/master/devops/github_workflow/ci.yml"

# SHELL_PROJECT_GITHUB_WORKFLOW_CI_NOTIFICATION constant
# This variable holds the URL to the GitHub Actions CI notification workflow configuration file.
# It is used to define the notification process for projects using GitHub Actions,
# allowing for automated notifications based on CI events.
readonly SHELL_PROJECT_GITHUB_WORKFLOW_CI_NOTIFICATION="https://raw.githubusercontent.com/pnguyen215/wsdkit.keys/master/devops/github_workflow/ci_notify.yml"

# SHELL_PROJECT_DOC_VERSION_RELEASE constant
# This variable holds the URL to the documentation release notes.
# It is used to provide access to the latest release information for the project,
# allowing developers and users to stay informed about updates and changes.
readonly SHELL_PROJECT_DOC_VERSION_RELEASE="https://raw.githubusercontent.com/pnguyen215/wsdkit.keys/master/docs/RELEASE.md"

# SHELL_PROJECT_GO_MAKEFILE constant
# This variable holds the URL to the Makefile template for Go projects.
# It is used to provide a standard Makefile configuration, which can help automate
# the build process and other tasks for Go applications.
readonly SHELL_PROJECT_GO_MAKEFILE="https://raw.githubusercontent.com/pnguyen215/wsdkit.keys/master/cmd/go/Makefile"
