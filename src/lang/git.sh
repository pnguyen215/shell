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
#   to prompt the user to add it using shell::add_conf. If both keys exist, it retrieves their values and
#   calls shell::send_telegram_message (with the dry-run flag, if enabled) to send the message.
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

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_SEND_TELEGRAM_HISTORICAL_GH_MESSAGE"
        return 0
    fi

    # Ensure that a message argument is provided.
    if [ $# -lt 1 ]; then
        echo "Usage: shell::send_telegram_historical_gh_message [-n] <message>"
        return 1
    fi

    # Verify that the Telegram Bot token configuration exists.
    local hasToken
    hasToken=$(shell::exist_key_conf "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN")
    if [ "$hasToken" = "false" ]; then
        shell::colored_echo "🟡 The key 'SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN' does not exist. Please consider adding it by using shell::add_conf" 11
        shell::clip_value "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN"
        return 1
    fi

    # Verify that the Telegram Chat ID configuration exists.
    local hasChatID
    hasChatID=$(shell::exist_key_conf "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID")
    if [ "$hasChatID" = "false" ]; then
        shell::colored_echo "🟡 The key 'SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID' does not exist. Please consider adding it by using shell::add_conf" 11
        shell::clip_value "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID"
        return 1
    fi

    # Retrieve the configuration values.
    local message="$1"
    local token
    token=$(shell::get_value_conf "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN")
    local chatID
    chatID=$(shell::get_value_conf "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID")

    # Call shell::send_telegram_message with or without dry-run flag.
    if [ "$dry_run" = "true" ]; then
        shell::send_telegram_message -n "$token" "$chatID" "$message"
    else
        shell::send_telegram_message "$token" "$chatID" "$message"
    fi
}

# shell::retrieve_gh_latest_release function
# Retrieves the latest release tag from a GitHub repository using the GitHub API.
#
# Usage:
#   shell::retrieve_gh_latest_release <owner/repo>
#
# Parameters:
#   - <owner/repo>: GitHub repository in the format 'owner/repo'
#
# Returns:
#   Outputs the latest release tag (e.g., v1.2.3), or an error message if failed.
#
# Example:
#   shell::retrieve_gh_latest_release "cli/cli"
#
# Dependencies:
#   - curl
#   - jq (optional): For better JSON parsing. Falls back to grep/sed if unavailable.
#
# Notes:
#   - Requires internet access.
#   - Works on both macOS and Linux.
shell::retrieve_gh_latest_release() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_RETRIEVE_GH_LATEST_RELEASE"
        return 0
    fi

    if [ -z "$1" ]; then
        shell::colored_echo "🔴 Usage: shell::retrieve_gh_latest_release <owner/repo>" 196
        return 1
    fi

    local repo="$1"
    local api_url="https://api.github.com/repos/${repo}/releases/latest"

    shell::colored_echo "🧪 Fetching latest release for $repo..." 36

    # Use jq if available, otherwise fallback
    if shell::is_command_available jq; then
        curl --silent "$api_url" | jq -r '.tag_name'
    else
        curl --silent "$api_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
    fi
}

# shell::retrieve_gh_repository_info function
# Retrieves and formats extensive information about the current Git repository
# using Markdown syntax for Telegram notifications.
#
# Usage:
#   shell::retrieve_gh_repository_info
#
# Description:
#   This function checks if the current directory is a Git repository and, if so,
#   retrieves extensive details such as the repository name, URLs (Git and HTTPS),
#   default branch, current branch, number of commits, latest commit hash, author,
#   date, recent commit messages, information about tags, and the status of the
#   working tree.
#   The collected information is then formatted into a single string response
#   using Markdown for compatibility with platforms like Telegram.
#
# Returns:
#   A Markdown-formatted string containing repository information if successful,
#   or an error message if not in a Git repository.
#
# Example usage:
#   repo_info=$(shell::retrieve_gh_repository_info)
#   echo "$repo_info"
#
# Notes:
#   - Requires the 'git' command to be available.
#   - Assumes the remote name is 'origin'.
#   - Uses existing helper functions: shell::colored_echo and shell::run_cmd_outlet.
#   - The Markdown formatting is tailored for platforms supporting basic Markdown (like Telegram).
shell::retrieve_gh_repository_info() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_RETRIEVE_GH_REPOSITORY_INFO"
        return 0
    fi

    # Check if the current directory is a Git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        shell::colored_echo "🔴 Error: Not in a Git repository." 196
        return 1
    fi

    local repo_name
    repo_name=$(shell::run_cmd_outlet "basename $(git rev-parse --show-toplevel)")
    if [ $? -ne 0 ]; then
        repo_name="N/A"
    fi

    local git_url
    git_url=$(shell::run_cmd_outlet "git remote get-url origin --all 2>/dev/null | grep ^git")
    if [ $? -ne 0 ]; then
        git_url="N/A"
    fi

    local https_url
    https_url=$(shell::run_cmd_outlet "git remote get-url origin --all 2>/dev/null | grep ^https")
    if [ $? -ne 0 ]; then
        https_url="N/A"
    fi

    local default_branch
    default_branch=$(shell::run_cmd_outlet "git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print \$NF}'")
    if [ $? -ne 0 ]; then
        default_branch="N/A"
    fi

    local current_branch
    current_branch=$(shell::run_cmd_outlet "git rev-parse --abbrev-ref HEAD")
    if [ $? -ne 0 ]; then
        current_branch="N/A"
    fi

    local commit_count
    commit_count=$(shell::run_cmd_outlet "git rev-list --count HEAD")
    if [ $? -ne 0 ]; then
        commit_count="N/A"
    fi

    local latest_commit_hash
    latest_commit_hash=$(shell::run_cmd_outlet "git log -1 --format=\"%H\"")
    if [ $? -ne 0 ]; then
        latest_commit_hash="N/A"
    fi

    local latest_commit_author
    latest_commit_author=$(shell::run_cmd_outlet "git log -1 --format=\"%aN\"")
    if [ $? -ne 0 ]; then
        latest_commit_author="N/A"
    fi

    local latest_commit_date
    latest_commit_date=$(shell::run_cmd_outlet "git log -1 --format=\"%aD\"")
    if [ $? -ne 0 ]; then
        latest_commit_date="N/A"
    fi

    local recent_commits
    recent_commits=$(shell::run_cmd_outlet "git log --oneline -n 5")

    local tags
    tags=$(shell::run_cmd_outlet "git tag --sort=-v:refname")

    # Format the output string with Markdown
    local response="*Repository:* $repo_name\n"
    response+="*Git URL:* \`$git_url\`\n"
    response+="*HTTPS URL:* \`$https_url\`\n"
    response+="*Default Branch:* \`$default_branch\`\n"
    response+="*Current Branch:* \`$current_branch\`\n"
    response+="*Total Commits:* \`$commit_count\`\n"
    response+="*Latest Commit:* \`$latest_commit_hash\`\n"
    response+="*Latest Commit Date:* \`$latest_commit_date\`\n"
    if [ ! -z "$tags" ]; then
        response+="*Tags:*\n\`\`\`\n$tags\n\`\`\`"
    fi
    # response+="*Author:* $latest_commit_author\n"
    # response+="*Recent Commits:*\n\`\`\`\n$recent_commits\n\`\`\`\n"
    echo "$response"
    return 0
}
