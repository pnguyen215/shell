#!/bin/bash
# git.sh

# shell::git::telegram::send_activity function
# Sends a historical GitHub-related message via Telegram using stored configuration keys.
#
# Usage:
#   shell::git::telegram::send_activity [-n] <message>
#
# Parameters:
#   - -n         : Optional dry-run flag. If provided, the command will be printed using shell::logger::command_clip instead of executed.
#   - <message>  : The message text to send.
#
# Description:
#   The function first checks if the dry-run flag is provided. It then verifies the existence of the
#   configuration keys "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN" and "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID".
#   If either key is missing, a warning is printed and the corresponding key is copied to the clipboard
#   to prompt the user to add it using shell::add_key_conf. If both keys exist, it retrieves their values and
#   calls shell::telegram::send (with the dry-run flag, if enabled) to send the message.
#
# Example:
#   shell::git::telegram::send_activity "Historical message text"
#   shell::git::telegram::send_activity -n "Dry-run historical message text"
shell::git::telegram::send_activity() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Send historical GitHub message via Telegram"
		shell::logger::usage "shell::git::telegram::send_activity [-n] [-h] <message>"
		shell::logger::item "message" "The message text to send"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::example "shell::git::telegram::send_activity \"Hello, World!\""
		shell::logger::example "shell::git::telegram::send_activity -n \"Hello, World!\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local message="$1"

	if [ -z "$message" ]; then
		shell::logger::error "Message is required"
		return $RETURN_INVALID
	fi

	# Verify that the Telegram Bot token configuration exists.
	local hasToken
	hasToken=$(shell::exist_key_conf "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN")
	if [ "$hasToken" = "false" ]; then
		shell::logger::warn "The key 'SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN' does not exist. Please consider adding it by using shell::add_key_conf"
		shell::clip_value "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN"
		return $RETURN_INVALID
	fi

	# Verify that the Telegram Chat ID configuration exists.
	local hasChatID
	hasChatID=$(shell::exist_key_conf "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID")
	if [ "$hasChatID" = "false" ]; then
		shell::logger::warn "The key 'SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID' does not exist. Please consider adding it by using shell::add_key_conf"
		shell::clip_value "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID"
		return $RETURN_INVALID
	fi

	# Retrieve the configuration values.
	local token
	token=$(shell::get_key_conf_value "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN")
	local chatID
	chatID=$(shell::get_key_conf_value "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID")

	if [ "$dry_run" = "true" ]; then
		shell::telegram::send -n "$token" "$chatID" "$message"
	else
		shell::telegram::send "$token" "$chatID" "$message"
	fi
}

# shell::git::release::version::get function
# Retrieves the latest release tag from a GitHub repository using the GitHub API.
#
# Usage:
#   shell::git::release::version::get <owner/repo>
#
# Parameters:
#   - <owner/repo>: GitHub repository in the format 'owner/repo'
#
# Returns:
#   Outputs the latest release tag (e.g., v1.2.3), or an error message if failed.
#
# Example:
#   shell::git::release::version::get "cli/cli"
#
# Dependencies:
#   - curl
#   - jq (optional): For better JSON parsing. Falls back to grep/sed if unavailable.
#
# Notes:
#   - Requires internet access.
#   - Works on both macOS and Linux.
shell::git::release::version::get() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Retrieve latest release tag from GitHub repository"
		shell::logger::usage "shell::git::release::version::get <owner/repo>"
		shell::logger::item "owner/repo" "GitHub repository in the format 'owner/repo'"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::example "shell::git::release::version::get \"cli/cli\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local repo="$1"

	if [ -z "$repo" ]; then
		shell::logger::error "Repository is required"
		return $RETURN_INVALID
	fi

	local api_url="https://api.github.com/repos/${repo}/releases/latest"
	local cmd_with_jq="curl --silent \"$api_url\" | jq -r '.tag_name'"
	local cmd_with_grep="curl --silent \"$api_url\" | grep '\"tag_name\":' | sed -E 's/.*\"([^\"]+)\".*/\1/'"

	if [ "$dry_run" = "true" ]; then
		if shell::is_command_available jq; then
			shell::logger::command_clip "$cmd_with_jq"
		else
			shell::logger::command_clip "$cmd_with_grep"
		fi
	else
		if shell::is_command_available jq; then
			shell::logger::assert "$cmd_with_jq" "GitHub latest release retrieved" "GitHub latest release aborted"
		else
			shell::logger::assert "$cmd_with_grep" "GitHub latest release retrieved" "GitHub latest release aborted"
		fi
	fi
	return $RETURN_SUCCESS
}

# shell::git::branch::checkout function
# Fetches a specific remote branch locally, checks it out, syncs all remotes and
# tags, then auto-detects divergence and prompts for a sync strategy.
#
# Usage:
#   shell::git::branch::checkout [-n] [-h] <branch>
#
# Parameters:
#   - -n, --dry-run : Optional. Print each command via shell::logger::command_clip
#                     instead of executing it.
#   - -h, --help    : Show this help message.
#   - <branch>      : Name of the remote branch to fetch and check out.
#
# Description:
#   Runs the following sequence against the current Git repository:
#     1. git fetch origin <branch>:<branch>  — create/update the local tracking branch
#     2. git checkout <branch>               — switch to the branch
#     3. git fetch --all --tags              — sync all remotes and tags
#     4. Detects divergence (local commits ahead vs remote commits ahead), then
#        prompts via shell::options::select_key to choose one of two strategies:
#          - git pull --rebase              — replay local commits onto the remote tip
#                                             (recommended when local commits exist)
#          - git reset --hard origin/<branch> — discard all local commits, match remote
#                                             exactly (recommended when local is clean)
#        The recommended option is placed first in the fzf picker (default selection).
#   Each step is logged via shell::logger::assert. The function stops and
#   propagates the exit code on the first failure.
#
# Returns:
#   $RETURN_SUCCESS (0) on full success.
#   $RETURN_INVALID (1) when <branch> is omitted.
#   Non-zero exit code of the first failing git command otherwise.
#
# Example:
#   shell::git::branch::checkout "feature/my-branch"
#   shell::git::branch::checkout -n "feature/my-branch"
shell::git::branch::checkout() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Fetch a remote branch, check it out, then choose a sync strategy"
		shell::logger::usage "shell::git::branch::checkout [-n] [-h] <branch>"
		shell::logger::item "branch" "Name of the remote branch to fetch and check out"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::example "shell::git::branch::checkout \"feature/my-branch\""
		shell::logger::example "shell::git::branch::checkout -n \"feature/my-branch\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local branch="$1"

	if [ -z "$branch" ]; then
		shell::logger::error "Branch name is required"
		return $RETURN_INVALID
	fi

	local cmd_fetch="git fetch origin \"${branch}\":\"${branch}\""
	local cmd_checkout="git checkout \"${branch}\""
	local cmd_fetch_all="git fetch --all --tags"

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_fetch"
		shell::logger::command_clip "$cmd_checkout"
		shell::logger::command_clip "$cmd_fetch_all"
		shell::logger::command_clip "git pull --rebase"
		shell::logger::command_clip "git reset --hard \"origin/${branch}\""
		return $RETURN_SUCCESS
	fi

	# Detect if the target branch is already checked out.
	# git fetch origin <branch>:<branch> is rejected by Git when the branch is
	# currently checked out — use plain git fetch origin in that case.
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	if [ "$current_branch" = "$branch" ]; then
		shell::logger::info "Already on branch '${branch}' — using git fetch origin instead of refspec fetch"
		shell::logger::assert "git fetch origin" "Fetched origin" "Fetch origin aborted" || return $?
	else
		shell::logger::assert "$cmd_fetch" "Branch '${branch}' fetched from origin" "Branch fetch from origin aborted" || return $?
		shell::logger::assert "$cmd_checkout" "Checked out branch '${branch}'" "Branch checkout aborted" || return $?
	fi
	shell::logger::assert "$cmd_fetch_all" "All remotes and tags fetched" "Fetch all aborted" || return $?

	# Detect divergence between local HEAD and remote tracking branch.
	local local_ahead=0
	local remote_ahead=0
	local_ahead=$(git rev-list "origin/${branch}..HEAD" --count 2>/dev/null || echo "0")
	remote_ahead=$(git rev-list "HEAD..origin/${branch}" --count 2>/dev/null || echo "0")

	shell::logger::info "Divergence — local: ${local_ahead} commit(s) ahead, remote: ${remote_ahead} commit(s) ahead"

	# Build fzf option labels — no colons allowed inside labels (used as delimiter).
	local label_rebase="git pull --rebase  (preserve ${local_ahead} local commit(s), replay onto remote)"
	local label_reset="git reset --hard origin/${branch}  (discard local commits, match remote exactly)"

	# Place the recommended strategy first so fzf pre-selects it.
	local strategy
	if [ "${local_ahead}" -gt 0 ]; then
		shell::logger::info "Local commits detected — rebase recommended"
		strategy=$(shell::options::select_key \
			"${label_rebase} (recommended):rebase" \
			"${label_reset}:reset")
	else
		shell::logger::info "No local commits ahead — hard reset recommended"
		strategy=$(shell::options::select_key \
			"${label_reset} (recommended):reset" \
			"${label_rebase}:rebase")
	fi

	if [ "$strategy" = "rebase" ]; then
		shell::logger::assert "git pull --rebase" "Branch synced via rebase" "Rebase pull aborted" || return $?
	elif [ "$strategy" = "reset" ]; then
		shell::logger::assert "git reset --hard \"origin/${branch}\"" "Branch reset to origin/${branch}" "Hard reset aborted" || return $?
	fi

	return $RETURN_SUCCESS
}
