#!/bin/bash
# settings.sh

# SHELL_CONF_WORKING constant
# This variable defines the working directory where the shell configuration files are stored.
# It is used as the base directory for both the key configuration file (SHELL_KEY_CONF_FILE) and the group configuration file (SHELL_GROUP_CONF_FILE).
# By default, this is set to "$HOME/.shell-config". You can change this value if you want to store your configuration files in a different location.
#
# Example:
#   SHELL_CONF_WORKING="$HOME/.shell-config"
SHELL_CONF_WORKING="$HOME/.shell-config"

# SHELL_CONF_WORKING_BACKUP constant
# This variable defines the path to the backup directory within the shell configuration working directory.
# It is used to store backup copies of configuration files, allowing for easy restoration in case of accidental changes or deletions.
# By default, this is set to "$SHELL_CONF_WORKING/backup". You can change this value if you want to store your backups in a different location.
SHELL_CONF_WORKING_BACKUP="$SHELL_CONF_WORKING/backup"

# SHELL_CONF_WORKING_AGENT constant
# This variable defines the path to the agents directory within the shell configuration working directory.
# It is used to store agent-specific configurations and scripts, allowing for easy management of different agents.
# By default, this is set to "$SHELL_CONF_WORKING/agents". You can change this value if you want to store your agents in a different location.
SHELL_CONF_WORKING_AGENT="$SHELL_CONF_WORKING/agents"

# SHELL_CONF_WORKING_WORKSPACE constant
# This variable defines the path to the workspace directory within the shell configuration working directory.
# It is used to store user-specific or profile-specific configurations and data.
# This separation helps in organizing configuration files related to different profiles or projects.
#
# Example:
#   SHELL_CONF_WORKING_WORKSPACE="$SHELL_CONF_WORKING/workspace"
SHELL_CONF_WORKING_WORKSPACE="$SHELL_CONF_WORKING/workspace"

# SHELL_CONF_WORKING_BOOKMARK constant
# This variable defines the path to the bookmarks directory within the shell configuration working directory.
# It is used to store bookmark files that allow quick navigation to frequently used directories.
# By default, this is set to "$SHELL_CONF_WORKING/bookmarks". You can change this value if you want to store your bookmarks in a different location.
#
# Example:
#   SHELL_CONF_WORKING_BOOKMARK="$SHELL_CONF_WORKING/bookmarks"
SHELL_CONF_WORKING_BOOKMARK="$SHELL_CONF_WORKING/bookmarks"

# SHELL_KEY_CONF_FILE constant
# This variable defines the path to the key configuration file used by the shell bash library.
# The file stores individual configuration entries in the following format:
#   key=encoded_value
# where each value is encoded using Base64 (with newlines removed).
# Functions such as shell::add_key_conf, shell::fzf_get_key_conf, shell::fzf_update_key_conf, and shell::fzf_remove_key_conf use this file to store and manage configuration settings.
#
# Example:
#   SHELL_KEY_CONF_FILE="$HOME/.shell-config/key.conf"
SHELL_KEY_CONF_FILE="$SHELL_CONF_WORKING/key.conf"

# SHELL_KEY_CONF_FILE_PROTECTED constant
# This variable defines the path to the protected key configuration file used by the shell bash library.
# The file stores protected configuration entries that should not be modified or removed through interactive functions.
# It is intended for critical settings that are essential for the shell's operation.
SHELL_KEY_CONF_FILE_PROTECTED="$SHELL_CONF_WORKING/protected.conf"

# SHELL_KEY_CONF_VPN_FILE constant
# This variable defines the path to the VPN configuration file used by the shell bash library.
# The file stores VPN-related configuration entries, allowing users to manage their VPN settings easily.
# It is typically used to store VPN connection details, such as server addresses, authentication credentials, and other relevant settings.
# By default, this is set to "$SHELL_CONF_WORKING/vpn.conf". You can change this value if you want to store your VPN configurations in a different location.
SHELL_KEY_CONF_VPN_FILE="$SHELL_CONF_WORKING/vpn.conf"

# SHELL_KEY_CONF_AGENT_GEMINI_FILE constant
# This variable defines the path to the Gemini agent configuration file used by the shell bash library.
# The file stores configurations specific to the Gemini agent, which may include settings for interacting with the Gemini AI model or service.
# It is typically used to manage configurations for the Gemini agent, such as API keys, model parameters, and other relevant settings.
# By default, this is set to "$SHELL_CONF_WORKING_AGENT/gemini.conf". You can change this value if you want to store your Gemini agent configurations in a different location.
SHELL_KEY_CONF_AGENT_GEMINI_FILE="$SHELL_CONF_WORKING_AGENT/gemini.conf"

# SHELL_KEY_CONF_AGENT_OPENAI_FILE constant
# This variable defines the path to the OpenAI agent configuration file used by the shell bash library.
# The file stores configurations specific to the OpenAI agent, which may include settings for interacting with OpenAI's models or services.
# It is typically used to manage configurations for the OpenAI agent, such as API keys, model parameters, and other relevant settings.
# By default, this is set to "$SHELL_CONF_WORKING_AGENT/openai.conf". You can change this value if you want to store your OpenAI agent configurations in a different location.
SHELL_KEY_CONF_AGENT_OPENAI_FILE="$SHELL_CONF_WORKING_AGENT/openai.conf"

# SHELL_KEY_CONF_FILE_WORKSPACE constant
# This variable defines the path to the profile-specific configuration file within the workspace directory.
# It is used to store configuration settings specific to a user's profile, allowing for personalized shell environments.
# This file typically contains settings that override or complement the main key configuration file.
#
# Example:
#   SHELL_KEY_CONF_FILE_WORKSPACE="$SHELL_CONF_WORKING_WORKSPACE/profile.conf"
SHELL_KEY_CONF_FILE_WORKSPACE="$SHELL_CONF_WORKING_WORKSPACE/profile.conf"

# SHELL_KEY_CONF_SETTING_WORKSPACE constant
# This variable defines the path to the settings configuration file within the workspace directory.
# It is used to store user-specific settings that may affect the behavior of the shell environment.
# This file can include various configurations that are not tied to specific keys or groups.
#
# Example:
#   SHELL_KEY_CONF_SETTING_WORKSPACE="$SHELL_CONF_WORKING_WORKSPACE/settings.conf"
SHELL_KEY_CONF_SETTING_WORKSPACE="$SHELL_CONF_WORKING_WORKSPACE/settings.conf"

# SHELL_KEY_CONF_FILE_BOOKMARK constant
# This variable defines the path to the bookmarks file within the shell configuration bookmarks directory.
# It is used to store individual bookmark entries, allowing for quick access to frequently used directories.
# By default, this is set to "$SHELL_CONF_WORKING_BOOKMARK/.bookmarks". You can change this value if you want to store your bookmarks in a different location.
SHELL_KEY_CONF_FILE_BOOKMARK="$SHELL_CONF_WORKING_BOOKMARK/.bookmarks"

# SHELL_GROUP_CONF_FILE constant
# This variable defines the path to the group configuration file used by the shell bash library.
# The file stores group definitions in the following format:
#   group_name=key1,key2,...,keyN
# Each group maps a name to a comma-separated list of keys from the key configuration file.
# Functions such as shell::fzf_add_group_key_conf, shell::read_group_key_conf, shell::fzf_remove_group_key_conf, shell::fzf_update_group_key_conf, and shell::fzf_clone_group_key_conf use this file
# to manage groups of configuration keys.
#
# Example:
#   SHELL_GROUP_CONF_FILE="$HOME/.shell-config/group.conf"
SHELL_GROUP_CONF_FILE="$SHELL_CONF_WORKING/group.conf"

# SHELL_GROUP_CONF_BACKUP_FILE constant
# This variable defines the path to the backup group configuration file used by the shell bash library.
# The file is intended to store backup copies of group configurations, allowing for easy restoration in case of accidental changes or deletions.
# By default, this is set to "$SHELL_CONF_WORKING_BACKUP/group.conf.bak". You can change this value if you want to store your group backups in a different location.
SHELL_GROUP_CONF_BACKUP_FILE="$SHELL_CONF_WORKING_BACKUP/group.conf.bak"

# SHELL_GH_CONF_FILE constant
# This variable defines the path to the GitHub configuration file used by the shell bash library.
# The file is intended to store settings related to GitHub or git activity, such as API tokens,
# repository preferences, or other git-related configurations.
#
# Example:
#   SHELL_GH_CONF_FILE="$HOME/.shell-config/gh.conf"
SHELL_GH_CONF_FILE="$SHELL_CONF_WORKING/gh.conf"

# SHELL_PROTECTED_KEYS array
# This array lists configuration keys that are considered constant and must not be removed, updated,
# or renamed through interactive functions.
#
# You can include keys that are critical for the shell's operation, security, or stability.
#
# Example:
#   SHELL_PROTECTED_KEYS=("HOST" "PORT" "API_TOKEN")
SHELL_PROTECTED_KEYS=("SHELL_SHIELD_ENCRYPTION_KEY" "SHELL_SHIELD_ENCRYPTION_IV" "HOST" "PORT" "SHELL_DEVELOPER" "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN" "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID")

##########SSH Settings#############
######### Aris Nguyen 2025 ########
##########SSH Settings#############

# SHELL_CONF_SSH_DIR_WORKING constant
# This variable defines the path to the SSH configuration directory in the user's home directory.
# It is used to store and manage SSH related configurations.
SHELL_CONF_SSH_DIR_WORKING="$HOME/.ssh"

# SHELL_C_AES_RED constant
# This variable defines the ANSI escape code for red text color. It is used to highlight error messages or critical alerts in the shell.
# if [ -z "${SHELL_C_AES_RED+x}" ]; then
#     declare -gr SHELL_C_AES_RED="\\033[0;31m"
# fi
SHELL_C_AES_RED="\\033[0;31m"

# SHELL_C_AES_RESET constant
# This variable defines the ANSI escape code to reset text formatting to default. It is used to clear any previous text color or style.
# if [ -z "${SHELL_C_AES_RESET+x}" ]; then
#     declare -gr SHELL_C_AES_RESET="\\033[0m"
# fi
SHELL_C_AES_RESET="\\033[0m"

# SHELL_C_AES_YELLOW constant
# This variable defines the ANSI escape code for yellow text color. It is used to highlight warnings or important information in the shell.
# if [ -z "${SHELL_C_AES_YELLOW+x}" ]; then
#     declare -gr SHELL_C_AES_YELLOW="\\033[0;33m"
# fi
SHELL_C_AES_YELLOW="\\033[0;33m"

# SHELL_INI_STRICT constant
# This variable determines the strictness of validation for section and key names in INI files.
# When set to 1, it enforces strict validation rules, ensuring that section and key names
# adhere to specific naming conventions and do not contain illegal characters.
# Example usage:
#   export SHELL_INI_STRICT=0  # Disables strict validation
#   export SHELL_INI_STRICT=1  # Enables strict validation
SHELL_INI_STRICT=${SHELL_INI_STRICT:-0} # Default is 0, meaning strict validation is disabled

# SHELL_INI_ALLOW_EMPTY_VALUES constant
# This variable determines whether empty values are permitted in INI files.
# When set to 1, it allows empty values, providing flexibility in configuration.
# Example usage:
#   export SHELL_INI_ALLOW_EMPTY_VALUES=0  # Disables empty values
#   export SHELL_INI_ALLOW_EMPTY_VALUES=1  # Enables empty values
SHELL_INI_ALLOW_EMPTY_VALUES=${SHELL_INI_ALLOW_EMPTY_VALUES:-1} # Default is 1, meaning empty values are allowed

# SHELL_INI_ALLOW_SPACES_IN_NAMES constant
# This variable determines whether spaces are allowed in section and key names within INI files.
# When set to 1, it permits spaces, providing flexibility in naming conventions.
# Example usage:
#   export SHELL_INI_ALLOW_SPACES_IN_NAMES=0  # Disables spaces in names
#   export SHELL_INI_ALLOW_SPACES_IN_NAMES=1  # Enables spaces in names
SHELL_INI_ALLOW_SPACES_IN_NAMES=${SHELL_INI_ALLOW_SPACES_IN_NAMES:-1} # Default is 1, meaning spaces are allowed

##########Developers Settings#############
######### Aris Nguyen 2025 ###############
##########Developers Settings#############

# SHELL_PROJECT_GITIGNORE_GO constant
# This variable holds the URL to the Go .gitignore template. It is used to provide a standard .gitignore file for Go projects.
SHELL_PROJECT_GITIGNORE_GO="https://raw.githubusercontent.com/pnguyen215/shell-devops-stores/refs/heads/master/gitignores/.golangignore"

# SHELL_PROJECT_GITIGNORE_JAVA constant
# This variable holds the URL to the Java .gitignore template. It is used to provide a standard .gitignore file for Java projects.
SHELL_PROJECT_GITIGNORE_JAVA="https://raw.githubusercontent.com/pnguyen215/shell-devops-stores/refs/heads/master/gitignores/.javaignore"

# SHELL_PROJECT_GITIGNORE_ANGULAR constant
# This variable holds the URL to the Angular .gitignore template. It is used to provide a standard .gitignore file for Angular projects.
SHELL_PROJECT_GITIGNORE_ANGULAR="https://raw.githubusercontent.com/pnguyen215/shell-devops-stores/refs/heads/master/gitignores/.angularignore"

# SHELL_PROJECT_GITIGNORE_NODEJS constant
# This variable holds the URL to the Node.js .gitignore template. It is used to provide a standard .gitignore file for Node.js projects.
SHELL_PROJECT_GITIGNORE_NODEJS="https://raw.githubusercontent.com/pnguyen215/shell-devops-stores/refs/heads/master/gitignores/.nodeignore"

# SHELL_PROJECT_GITIGNORE_PYTHON constant
# This variable holds the URL to the Python .gitignore template. It is used to provide a standard .gitignore file for Python projects.
SHELL_PROJECT_GITIGNORE_PYTHON="https://raw.githubusercontent.com/pnguyen215/shell-devops-stores/refs/heads/master/gitignores/.pythonignore"

# SHELL_PROJECT_GITHUB_WORKFLOW_BASE constant
# This variable holds the URL to the GitHub Actions CI workflow configuration file.
# It is used to define the continuous integration process for projects using GitHub.
SHELL_PROJECT_GITHUB_WORKFLOW_BASE="https://raw.githubusercontent.com/pnguyen215/shell-devops-stores/refs/heads/master/ci-cd/github-actions/gh_wrk_base.yml"

# SHELL_PROJECT_GITHUB_WORKFLOW_NEWS constant
# This variable holds the URL to the GitHub Actions CI notification workflow configuration file.
# It is used to define the notification process for projects using GitHub Actions,
# allowing for automated notifications based on CI events.
SHELL_PROJECT_GITHUB_WORKFLOW_NEWS="https://raw.githubusercontent.com/pnguyen215/shell-devops-stores/refs/heads/master/ci-cd/github-actions/gh_wrk_news.yml"

# SHELL_PROJECT_GITHUB_WORKFLOW_NEWS_GO constant
# This variable holds the URL to the GitHub Actions CI notification workflow configuration file for Go projects.
# It is used to define the notification process specifically for Go projects using GitHub Actions,
# allowing for automated notifications based on CI events.
SHELL_PROJECT_GITHUB_WORKFLOW_NEWS_GO="https://raw.githubusercontent.com/pnguyen215/shell-devops-stores/refs/heads/master/ci-cd/github-actions/gh_wrk_news_go.yml"

# SHELL_PROJECT_GITHUB_WORKFLOW_SH_PRETTY constant
# This variable holds the URL to the GitHub Actions CI workflow configuration file for shell scripts.
# It is used to define the continuous integration process for shell script projects using GitHub Actions.
# This workflow is designed to ensure that shell scripts are properly formatted and adhere to best practices.
SHELL_PROJECT_GITHUB_WORKFLOW_SH_PRETTY="https://raw.githubusercontent.com/pnguyen215/shell-devops-stores/refs/heads/master/ci-cd/github-actions/gh_wrk_sh_pretty.yml"

# SHELL_PROJECT_DOC_VERSION_RELEASE constant
# This variable holds the URL to the documentation release notes.
# It is used to provide access to the latest release information for the project,
# allowing developers and users to stay informed about updates and changes.
SHELL_PROJECT_DOC_VERSION_RELEASE="https://raw.githubusercontent.com/pnguyen215/shell-devops-stores/refs/heads/master/docs/VERSIONING.md"

# SHELL_PROJECT_GO_MAKEFILE constant
# This variable holds the URL to the Makefile template for Go projects.
# It is used to provide a standard Makefile configuration, which can help automate
# the build process and other tasks for Go applications.
SHELL_PROJECT_GO_MAKEFILE="https://raw.githubusercontent.com/pnguyen215/shell-devops-stores/refs/heads/master/languages/golang/sdk/Makefile"
