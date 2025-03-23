#!/bin/bash
# constant.sh

# SHELL_CONF_WORKING constant
# This variable defines the working directory where the shell configuration files are stored.
# It is used as the base directory for both the key configuration file (SHELL_KEY_CONF_FILE) and the group configuration file (SHELL_GROUP_CONF_FILE).
# By default, this is set to "$HOME/.shell-config". You can change this value if you want to store your configuration files in a different location.
#
# Example:
#   SHELL_CONF_WORKING="$HOME/.shell-config"
declare -r SHELL_CONF_WORKING="$HOME/.shell-config"

# SHELL_CONF_WORKING_WORKSPACE constant
# This variable defines the path to the workspace directory within the shell configuration working directory.
# It is used to store user-specific or profile-specific configurations and data.
# This separation helps in organizing configuration files related to different profiles or projects.
#
# Example:
#   SHELL_CONF_WORKING_WORKSPACE="$SHELL_CONF_WORKING/workspace"
declare -r SHELL_CONF_WORKING_WORKSPACE="$SHELL_CONF_WORKING/workspace"

# SHELL_KEY_CONF_FILE constant
# This variable defines the path to the key configuration file used by the shell bash library.
# The file stores individual configuration entries in the following format:
#   key=encoded_value
# where each value is encoded using Base64 (with newlines removed).
# Functions such as add_conf, get_conf, update_conf, and remove_conf use this file to store and manage configuration settings.
#
# Example:
#   SHELL_KEY_CONF_FILE="$HOME/.shell-config/key.conf"
declare -r SHELL_KEY_CONF_FILE="$SHELL_CONF_WORKING/key.conf"

# SHELL_KEY_CONF_FILE_WORKSPACE constant
# This variable defines the path to the profile-specific configuration file within the workspace directory.
# It is used to store configuration settings specific to a user's profile, allowing for personalized shell environments.
# This file typically contains settings that override or complement the main key configuration file.
#
# Example:
#   SHELL_KEY_CONF_FILE_WORKSPACE="$SHELL_CONF_WORKING_WORKSPACE/profile.conf"
declare -r SHELL_KEY_CONF_FILE_WORKSPACE="$SHELL_CONF_WORKING_WORKSPACE/profile.conf"

# SHELL_KEY_CONF_SETTING_WORKSPACE constant
# This variable defines the path to the settings configuration file within the workspace directory.
# It is used to store user-specific settings that may affect the behavior of the shell environment.
# This file can include various configurations that are not tied to specific keys or groups.
#
# Example:
#   SHELL_KEY_CONF_SETTING_WORKSPACE="$SHELL_CONF_WORKING_WORKSPACE/settings.conf"
declare -r SHELL_KEY_CONF_SETTING_WORKSPACE="$SHELL_CONF_WORKING_WORKSPACE/settings.conf"

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
declare -r SHELL_GROUP_CONF_FILE="$SHELL_CONF_WORKING/group.conf"

# SHELL_GH_CONF_FILE constant
# This variable defines the path to the GitHub configuration file used by the shell bash library.
# The file is intended to store settings related to GitHub or git activity, such as API tokens,
# repository preferences, or other git-related configurations.
#
# Example:
#   SHELL_GH_CONF_FILE="$HOME/.shell-config/gh.conf"
declare -r SHELL_GH_CONF_FILE="$SHELL_CONF_WORKING/gh.conf"

# SHELL_PROTECTED_KEYS array
# This array lists configuration keys that are considered constant and must not be removed, updated,
# or renamed through interactive functions.
#
# You can include keys that are critical for the shell's operation, security, or stability.
#
# Example:
#   SHELL_PROTECTED_KEYS=("HOST" "PORT" "API_TOKEN")
declare -r -a SHELL_PROTECTED_KEYS=("HOST" "PORT" "SHELL_DEVELOPER" "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN" "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID")
