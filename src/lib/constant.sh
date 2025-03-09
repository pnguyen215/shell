#!/bin/bash
# constant.sh

# SHELL_CONF_WORKING constant
# This variable defines the working directory where the shell configuration files are stored.
# It is used as the base directory for both the key configuration file (SHELL_KEY_CONF_FILE) and the group configuration file (SHELL_GROUP_CONF_FILE).
# By default, this is set to "$HOME/.shell-config". You can change this value if you want to store your configuration files in a different location.
#
# Example:
#   SHELL_CONF_WORKING="$HOME/.shell-config"
SHELL_CONF_WORKING="$HOME/.shell-config"

# SHELL_KEY_CONF_FILE constant
# This variable defines the path to the key configuration file used by the shell bash library.
# The file stores individual configuration entries in the following format:
#   key=encoded_value
# where each value is encoded using Base64 (with newlines removed).
# Functions such as add_conf, get_conf, update_conf, and remove_conf use this file to store and manage configuration settings.
#
# Example:
#   SHELL_KEY_CONF_FILE="$HOME/.shell-config/key.conf"
SHELL_KEY_CONF_FILE="$HOME/.shell-config/key.conf"

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
SHELL_GROUP_CONF_FILE="$HOME/.shell-config/group.conf"

# SHELL_GH_CONF_FILE constant
# This variable defines the path to the GitHub configuration file used by the shell bash library.
# The file is intended to store settings related to GitHub or git activity, such as API tokens,
# repository preferences, or other git-related configurations.
#
# Example:
#   SHELL_GH_CONF_FILE="$HOME/.shell-config/gh.conf"
SHELL_GH_CONF_FILE="$HOME/.shell-config/gh.conf"
