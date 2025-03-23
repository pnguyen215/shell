#!/bin/bash
# git.sh

# shell::send_telegram_historical_gh_message function
# Sends a historical GitHub-related message via Telegram using stored configuration keys.
#
# Usage:
#   shell::send_telegram_historical_gh_message [-n] <message>
#
# Parameters:
#   - -n         : Optional dry-run flag. If provided, the command will be printed using shell::on_evict instead of executed.
#   - <message>  : The message text to send.
#
# Description:
#   The function first checks if the dry-run flag is provided. It then verifies the existence of the
#   configuration keys "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN" and "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID".
#   If either key is missing, a warning is printed and the corresponding key is copied to the clipboard
#   to prompt the user to add it using add_conf. If both keys exist, it retrieves their values and
#   calls send_telegram_message (with the dry-run flag, if enabled) to send the message.
#
# Example:
#   shell::send_telegram_historical_gh_message "Historical message text"
#   shell::send_telegram_historical_gh_message -n "Dry-run historical message text"
shell::send_telegram_historical_gh_message() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Ensure that a message argument is provided.
    if [ $# -lt 1 ]; then
        echo "Usage: shell::send_telegram_historical_gh_message [-n] <message>"
        return 1
    fi

    # Verify that the Telegram Bot token configuration exists.
    local hasToken
    hasToken=$(exist_key_conf "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN")
    if [ "$hasToken" = "false" ]; then
        shell::colored_echo "🟡 The key 'SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN' does not exist. Please consider adding it by using add_conf" 11
        shell::clip_value "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN"
        return 1
    fi

    # Verify that the Telegram Chat ID configuration exists.
    local hasChatID
    hasChatID=$(exist_key_conf "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID")
    if [ "$hasChatID" = "false" ]; then
        shell::colored_echo "🟡 The key 'SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID' does not exist. Please consider adding it by using add_conf" 11
        shell::clip_value "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID"
        return 1
    fi

    # Retrieve the configuration values.
    local message="$1"
    local token
    token=$(get_value_conf "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN")
    local chatID
    chatID=$(get_value_conf "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID")

    # Call send_telegram_message with or without dry-run flag.
    if [ "$dry_run" = "true" ]; then
        send_telegram_message -n "$token" "$chatID" "$message"
    else
        send_telegram_message "$token" "$chatID" "$message"
    fi
}
