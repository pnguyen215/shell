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
# Fetches a specific remote branch, checks it out, and syncs local state to the
# remote tip. Detects uncommitted changes and unpushed local commits, then shows
# an fzf strategy picker only when the local state requires a decision.
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
#   Step 1 — Switch to the target branch (skipped when already on it):
#     git fetch origin <branch>:<branch>   (blocked when already checked out — detected)
#     git checkout <branch>
#   Step 2 — Targeted fetch (guarantees refs/remotes/origin/<branch> exists):
#     git fetch origin <branch>
#   Step 3 — Sync all remotes and tags:
#     git fetch --all --tags
#   Step 4 — Detect local state and act:
#     clean (no uncommitted, no local commits) → auto git reset --hard origin/<branch>
#     local commits only                       → fzf: rebase (recommended) | reset --hard
#     uncommitted changes only                 → fzf: stash+reset+pop (recommended) | reset --hard
#     both uncommitted + local commits         → fzf: stash+rebase+pop (recommended) | reset --hard
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
		shell::logger::info "Fetch a remote branch, check it out, then sync to remote tip"
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

	# ---------------------------------------------------------------------------
	# Command variables — all git commands declared upfront for easy review.
	# ---------------------------------------------------------------------------
	local remote_ref="origin/${branch}"

	local cmd_fetch_refspec="git fetch origin \"${branch}\":\"${branch}\""
	local cmd_checkout="git checkout \"${branch}\""
	# Explicit refspec — forces refs/remotes/origin/<branch> to update even when
	# the remote has no default fetch refspec configured. Without this, a plain
	# 'git fetch origin <branch>' only writes FETCH_HEAD, leaving origin/<branch>
	# stale or missing, which breaks 'git reset --hard origin/<branch>'.
	local cmd_fetch_targeted="git fetch origin \"+refs/heads/${branch}:refs/remotes/origin/${branch}\""
	local cmd_fetch_all="git fetch --all --tags"
	local cmd_reset="git reset --hard \"${remote_ref}\""
	local cmd_rebase="git rebase \"${remote_ref}\""
	local cmd_stash="git stash"
	local cmd_stash_pop="git stash pop"

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_fetch_refspec"
		shell::logger::command_clip "$cmd_checkout"
		shell::logger::command_clip "$cmd_fetch_targeted"
		shell::logger::command_clip "$cmd_fetch_all"
		shell::logger::command_clip "$cmd_reset"
		shell::logger::command_clip "$cmd_stash && $cmd_reset && $cmd_stash_pop"
		shell::logger::command_clip "$cmd_rebase"
		shell::logger::command_clip "$cmd_stash && $cmd_rebase && $cmd_stash_pop"
		return $RETURN_SUCCESS
	fi

	# Step 1 — switch to target branch.
	# git fetch origin <b>:<b> is refused when <b> is already checked out.
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	if [ "$current_branch" = "$branch" ]; then
		shell::logger::info "Already on branch '${branch}' — skipping refspec fetch and checkout"
	else
		shell::logger::assert "$cmd_fetch_refspec" \
			"Branch '${branch}' fetched from origin" "Branch fetch from origin aborted" || return $?
		shell::logger::assert "$cmd_checkout" \
			"Checked out branch '${branch}'" "Branch checkout aborted" || return $?
	fi

	# Step 2 — targeted fetch: guarantees refs/remotes/origin/<branch> is created/updated.
	# A refspec fetch (origin <b>:<b>) only moves refs/heads/<b>; it never touches
	# refs/remotes/origin/<b>, so git reset --hard origin/<b> would fail without this step.
	shell::logger::assert "$cmd_fetch_targeted" \
		"Remote tracking ref for '${branch}' updated" "Targeted fetch aborted" || return $?

	# Verify the tracking ref now exists; bail out with a clear message if not.
	# Without this guard, 'git rev-list origin/<b>..HEAD --count 2>/dev/null || echo 0'
	# would silently return 0, falsely classifying the branch as clean and
	# triggering an immediate 'git reset --hard origin/<b>' that fails with
	# 'fatal: ambiguous argument'.
	if ! git rev-parse --verify --quiet "refs/remotes/${remote_ref}" >/dev/null; then
		shell::logger::error "Remote tracking ref 'refs/remotes/${remote_ref}' is missing after fetch — cannot continue"
		return $RETURN_FAILURE
	fi

	# Step 3 — sync all remotes and tags.
	shell::logger::assert "$cmd_fetch_all" \
		"All remotes and tags fetched" "Fetch all aborted" || return $?

	# Step 4 — detect local state and choose sync strategy.
	local has_uncommitted="false"
	if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
		has_uncommitted="true"
	fi

	local local_ahead=0
	local remote_ahead=0
	local_ahead=$(git rev-list "${remote_ref}..HEAD" --count 2>/dev/null || echo "0")
	remote_ahead=$(git rev-list "HEAD..${remote_ref}" --count 2>/dev/null || echo "0")

	shell::logger::info "Local state — uncommitted: ${has_uncommitted}, local commits ahead: ${local_ahead}, remote commits ahead: ${remote_ahead}"

	# Case 1: clean — auto-reset, no prompt needed.
	if [ "$has_uncommitted" = "false" ] && [ "${local_ahead}" -eq 0 ]; then
		shell::logger::info "Local branch is clean — auto-resetting to '${remote_ref}'"
		shell::logger::assert "$cmd_reset" \
			"Branch reset to ${remote_ref}" "Hard reset aborted" || return $?
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# fzf option labels — no colons inside labels (used as delimiter by select_key).
	# ---------------------------------------------------------------------------
	local opt_rebase="git rebase ${remote_ref}  (preserve ${local_ahead} local commit(s), replay onto remote) (recommended):rebase"
	local opt_reset="git reset --hard ${remote_ref}  (discard local commits and changes, match remote exactly):reset"
	local opt_stash_reset="stash + reset + stash pop  (save uncommitted changes, sync to remote, then restore) (recommended):stash_reset"
	local opt_stash_rebase="stash + rebase + stash pop  (save changes, replay ${local_ahead} local commit(s) onto remote, restore) (recommended):stash_rebase"

	# Cases -4: local changes detected — prompt via fzf.
	local strategy

	if [ "$has_uncommitted" = "false" ] && [ "${local_ahead}" -gt 0 ]; then
		# Case 2: local commits only, working tree clean.
		strategy=$(shell::options::select_key \
			"$opt_rebase" \
			"$opt_reset")

	elif [ "$has_uncommitted" = "true" ] && [ "${local_ahead}" -eq 0 ]; then
		# Case 3: uncommitted changes only, no local commits.
		strategy=$(shell::options::select_key \
			"$opt_stash_reset" \
			"$opt_reset")

	else
		# Case 4: both uncommitted changes and local commits.
		strategy=$(shell::options::select_key \
			"$opt_stash_rebase" \
			"$opt_reset")
	fi

	case "$strategy" in
		rebase)
			shell::logger::assert "$cmd_rebase" \
				"Branch rebased onto ${remote_ref}" "Rebase aborted" || return $?
			;;
		reset)
			shell::logger::assert "$cmd_reset" \
				"Branch reset to ${remote_ref}" "Hard reset aborted" || return $?
			;;
		stash_reset)
			shell::logger::assert "$cmd_stash" \
				"Uncommitted changes stashed" "Stash failed" || return $?
			shell::logger::assert "$cmd_reset" \
				"Branch reset to ${remote_ref}" "Hard reset aborted" || return $?
			shell::logger::assert "$cmd_stash_pop" \
				"Stashed changes restored" "Stash pop failed — run 'git stash pop' manually"
			;;
		stash_rebase)
			shell::logger::assert "$cmd_stash" \
				"Uncommitted changes stashed" "Stash failed" || return $?
			shell::logger::assert "$cmd_rebase" \
				"Branch rebased onto ${remote_ref}" "Rebase aborted" || return $?
			shell::logger::assert "$cmd_stash_pop" \
				"Stashed changes restored" "Stash pop failed — run 'git stash pop' manually"
			;;
	esac

	return $RETURN_SUCCESS
}

# shell::git::branch::checkout::current function
# Checks out the currently active branch by name, effectively re-checking it out.
# This is useful for triggering branch-specific hooks or refreshing the working tree
# without switching to a different branch. If not inside a Git repository, an error
# is logged and the function returns with failure.
# 
# Usage:
#   shell::git::branch::checkout::current [-n] [-h]
# 
# Parameters:
#   - -n, --dry-run : Optional. Print the command via shell::logger::command_clip instead of executing it.
#   - -h, --help    : Show this help message.
# 
# Returns:
#   $RETURN_SUCCESS (0) on success.
#   $RETURN_FAILURE (non-zero) if not inside a Git repository or if the checkout command fails.
# 
# Example:
#   shell::git::branch::checkout::current
#   shell::git::branch::checkout::current -n
shell::git::branch::checkout::current() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Re-checkout the currently active Git branch"
		shell::logger::usage "shell::git::branch::checkout::current [-n] [-h]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::example "shell::git::branch::checkout::current"
		shell::logger::example "shell::git::branch::checkout::current -n"
		return $RETURN_SUCCESS
	fi
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
	if [ -z "$current_branch" ]; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi
	echo "$current_branch"
	shell::logger::info "Current branch: ${current_branch}"
	shell::git::branch::checkout "$current_branch"
}

# shell::git::branch::create function
# Creates one or more local Git branches, pushes each to origin with upstream
# tracking, then restores the original branch.
#
# Usage:
#   shell::git::branch::create [-n] [-h] <branch> [<branch> ...]
#
# Parameters:
#   - -n, --dry-run : Optional. Print each command via shell::logger::command_clip
#                     instead of executing it.
#   - -h, --help    : Show this help message.
#   - <branch>...   : One or more branch names to create. Each name must match
#                     the regex ^[a-zA-Z0-9_-]+$ (letters, digits, hyphen,
#                     underscore). Invalid names are skipped with a warning.
#
# Description:
#   For each valid branch name, runs:
#     1. git checkout -b <branch>          — create and switch to the new branch
#     2. git push -u origin <branch>       — push and set upstream tracking
#   After all branches are processed, returns to the originally checked-out branch
#   captured at function entry. Each step is logged via shell::logger::assert
#   and stops the per-branch loop on the first failure for that branch.
#
# Returns:
#   $RETURN_SUCCESS (0) on full success.
#   $RETURN_INVALID (1) when no branch arguments are provided.
#   Non-zero exit code of the first failing git command otherwise.
#
# Example:
#   shell::git::branch::create feature_a feature_b
#   shell::git::branch::create -n feature_a feature_b
shell::git::branch::create() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Create local branches, push them to origin with upstream tracking, then restore current branch"
		shell::logger::usage "shell::git::branch::create [-n] [-h] <branch> [<branch> ...]"
		shell::logger::item "branch" "Branch name(s) matching ^[a-zA-Z0-9_-]+$"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::example "shell::git::branch::create feature_a feature_b"
		shell::logger::example "shell::git::branch::create -n feature_a"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if [ "$#" -eq 0 ]; then
		shell::logger::error "At least one branch name is required"
		return $RETURN_INVALID
	fi

	# Capture the currently checked-out branch so we can restore it at the end.
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	if [ -z "$current_branch" ]; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	local branch_regex='^[a-zA-Z0-9_-]+$'
	local branch
	local cmd_checkout_new
	local cmd_push_upstream

	for branch in "$@"; do
		if ! [[ "$branch" =~ $branch_regex ]]; then
			shell::logger::warn "Invalid branch name '${branch}' — only letters, digits, hyphens, and underscores allowed; skipping"
			continue
		fi

		cmd_checkout_new="git checkout -b \"${branch}\""
		cmd_push_upstream="git push -u origin \"${branch}\""

		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "$cmd_checkout_new"
			shell::logger::command_clip "$cmd_push_upstream"
			continue
		fi

		shell::logger::assert "$cmd_checkout_new" \
			"Branch '${branch}' created and checked out" "Branch checkout aborted" || return $?
		shell::logger::assert "$cmd_push_upstream" \
			"Branch '${branch}' pushed to origin with upstream tracking" "Branch push aborted" || return $?
	done

	# Restore the original branch.
	local cmd_restore="git checkout \"${current_branch}\""

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_restore"
	else
		shell::logger::assert "$cmd_restore" \
			"Restored original branch '${current_branch}'" "Branch restore aborted" || return $?
	fi

	return $RETURN_SUCCESS
}

# shell::git::repos::fetch function
# Clones a remote Git repository as a shallow clone (depth 1) into a specified
# local folder name.
#
# Usage:
#   shell::git::repos::fetch [-n] [-h] <repo_uri> <folder_name>
#
# Parameters:
#   - -n, --dry-run    : Optional. Print the command via shell::logger::command_clip
#                        instead of executing it.
#   - -h, --help       : Show this help message.
#   - <repo_uri>       : The URI of the remote Git repository to clone.
#   - <folder_name>    : The local directory name to clone into.
#
# Description:
#   Runs:
#     git clone --depth 1 <repo_uri> <folder_name>
#   The --depth 1 flag creates a shallow clone with only the latest commit,
#   minimising download size and clone time. The command is logged via
#   shell::logger::assert.
#
# Returns:
#   $RETURN_SUCCESS (0) on full success.
#   $RETURN_INVALID (1) when either argument is missing.
#   Non-zero exit code of the failing git command otherwise.
#
# Example:
#   shell::git::repos::fetch "https://github.com/org/repo.git" "my-repo"
#   shell::git::repos::fetch -n "https://github.com/org/repo.git" "my-repo"
shell::git::repos::fetch() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Shallow-clone a remote Git repository into a local folder"
		shell::logger::usage "shell::git::repos::fetch [-n] [-h] <repo_uri> <folder_name>"
		shell::logger::item "repo_uri" "URI of the remote Git repository"
		shell::logger::item "folder_name" "Local directory name to clone into"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::example "shell::git::repos::fetch \"https://github.com/org/repo.git\" \"my-repo\""
		shell::logger::example "shell::git::repos::fetch -n \"https://github.com/org/repo.git\" \"my-repo\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local repo_uri="$1"
	local folder_name="$2"

	if [ -z "$repo_uri" ]; then
		shell::logger::error "Repository URI is required"
		return $RETURN_INVALID
	fi

	if [ -z "$folder_name" ]; then
		shell::logger::error "Folder name is required"
		return $RETURN_INVALID
	fi

	local cmd_clone="git clone --depth 1 \"${repo_uri}\" \"${folder_name}\""

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_clone"
		return $RETURN_SUCCESS
	fi

	shell::logger::assert "$cmd_clone" \
		"Repository cloned into '${folder_name}'" "Repository clone aborted" || return $?

	return $RETURN_SUCCESS
}
