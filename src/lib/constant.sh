#!/bin/bash
# constant.sh

# SHELL_CONF_FILE constant
# This variable defines the path to the configuration file used by the shell bash library.
# The configuration file is expected to contain entries in the following format:
#   key=encoded_value
# where each value is encoded using Base64. Functions such as add_conf and get_conf use this file
# to store and retrieve configuration settings.
#
# Example:
#   SHELL_CONF_FILE="$HOME/.my_config.conf"
SHELL_CONF_FILE="$HOME/.shell-config/key.conf"
