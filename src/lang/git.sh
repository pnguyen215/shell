#!/usr/bin/env bash
# @file lang/git.sh
# @brief Git and GitHub helpers.

# @description Sends a historical GitHub-related message via Telegram using stored configuration keys.
#
#   The function first checks if the dry-run flag is provided. It then verifies the existence of the
#   configuration keys "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN" and "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID".
#   If either key is missing, a warning is printed and the corresponding key is copied to the clipboard
#   to prompt the user to add it using shell::conf::key::add. If both keys exist, it retrieves their values and
#   calls shell::telegram::send (with the dry-run flag, if enabled) to send the message.
# @option -n Optional dry-run flag. If provided, the command will be printed using shell::logger::command_clip instead of executed.
# @arg $1 string message: The message text to send.
# @exitcode 0 Success.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::telegram::history::send "Historical message text"
#   shell::git::telegram::history::send -n "Dry-run historical message text"
#
shell::git::telegram::history::send() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Send historical GitHub message via Telegram"
		shell::logger::usage "shell::git::telegram::history::send [-n] [-h] <message>"
		shell::logger::item "message" "The message text to send"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::example "shell::git::telegram::history::send \"Hello, World!\""
		shell::logger::example "shell::git::telegram::history::send -n \"Hello, World!\""
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
	hasToken=$(shell::conf::key::exists "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN")
	if [ "$hasToken" = "false" ]; then
		shell::logger::warn "The key 'SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN' does not exist. Please consider adding it by using shell::conf::key::add"
		shell::clipboard::copy --best-effort "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN"
		return $RETURN_INVALID
	fi

	# Verify that the Telegram Chat ID configuration exists.
	local hasChatID
	hasChatID=$(shell::conf::key::exists "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID")
	if [ "$hasChatID" = "false" ]; then
		shell::logger::warn "The key 'SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID' does not exist. Please consider adding it by using shell::conf::key::add"
		shell::clipboard::copy --best-effort "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID"
		return $RETURN_INVALID
	fi

	# Retrieve the configuration values.
	local token
	token=$(shell::conf::key::get "SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN")
	local chatID
	chatID=$(shell::conf::key::get "SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID")

	if [ "$dry_run" = "true" ]; then
		shell::telegram::send -n "$token" "$chatID" "$message"
	else
		shell::telegram::send "$token" "$chatID" "$message"
	fi
}

# @description Displays comprehensive statistics for a Git repository — works both for a
#   local clone and for a remote URL (public or private with access). When a URL
#   is supplied the repository is cloned to a temporary directory, stats are
#   gathered, then the directory is removed.
#
#   Notes:
#   Section E (code growth) runs git log --numstat over the full history.
#   This can take several minutes on large repositories.
# @option -n | --dry-run Optional. Print planned git commands instead of executing.
# @option -h | --help Show this help message.
# @arg $1 string path_or_url: Optional. Local repo path OR remote URL (https://, http://, git(at), ssh://). Defaults to CWD. Stat sections (v1 metric set): A. Repository Identity      — name, URL, branches, age, first/last commit B. Repository Size          — commits, branches, tags, contributors, files, LOC C. Commit Activity          — windows (24h/7d/30d/90d/1y), velocity, trends D. Contributors             — totals, active windows, top-10 leaderboard E. Code Growth              — added/deleted/net lines, avg commit size F. Code Churn               — churn rate, top modified files & directories G. Commit Quality           — conventional breakdown, merge/revert/fixup counts H. Branch Metrics           — local count, active vs stale (90-day threshold) I. Tag Metrics              — total, latest, first J. Time Distribution        — by weekday, top hours, working pattern % K. Language Distribution    — file count by extension (top-15) L. Repository Health Score  — 0-100 composite score
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::repos::stats
#   shell::git::repos::stats /path/to/local/repo
#   shell::git::repos::stats https://github.com/owner/repo.git
#   shell::git::repos::stats git@github.com:owner/private-repo.git
#
shell::git::repos::stats() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Display comprehensive statistics for a Git repository (local or URL)"
		shell::logger::usage "shell::git::repos::stats [-n] [-h] [<path_or_url>]"
		shell::logger::item "path_or_url" "Local path or remote URL (https://, git@, ssh://). Defaults to CWD."
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print planned commands instead of executing"
		shell::logger::example "shell::git::repos::stats"
		shell::logger::example "shell::git::repos::stats /path/to/repo"
		shell::logger::example "shell::git::repos::stats https://github.com/owner/repo.git"
		shell::logger::example "shell::git::repos::stats git@github.com:owner/repo.git"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local target="${1:-}"
	local _repo_dir=""
	local _tmp_dir=""

	# ---------------------------------------------------------------------------
	# Determine repo location — URL clone vs local path vs CWD.
	# ---------------------------------------------------------------------------
	if echo "$target" | grep -qE '^(https?://|git@|ssh://)'; then
		_tmp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t 'git_stats')
		shell::logger::info "Cloning '${target}' into temp directory (full history required)..."
		if ! git clone --quiet "$target" "$_tmp_dir" 2>&1; then
			shell::logger::error "Failed to clone: ${target}"
			rm -rf "$_tmp_dir" 2>/dev/null
			return $RETURN_FAILURE
		fi
		_repo_dir="$_tmp_dir"
	elif [ -n "$target" ]; then
		_repo_dir="$target"
	else
		_repo_dir="$PWD"
	fi

	if ! git -C "$_repo_dir" rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not a Git repository: ${_repo_dir}"
		[ -n "$_tmp_dir" ] && rm -rf "$_tmp_dir" 2>/dev/null
		return $RETURN_FAILURE
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "git -C \"${_repo_dir}\" log --numstat --format=''  # gather code growth"
		shell::logger::command_clip "git -C \"${_repo_dir}\" log --format='%ad %aN ...' # gather activity / contributor data"
		shell::logger::command_clip "find \"${_repo_dir}\" -type f -not -path '*/.git/*' | xargs wc -l  # compute LOC"
		[ -n "$_tmp_dir" ] && rm -rf "$_tmp_dir" 2>/dev/null
		return $RETURN_SUCCESS
	fi

	# Change into repo for the duration of stats gathering so all git / find
	# commands work without an explicit -C / path prefix.
	local _orig_dir="$PWD"
	cd "$_repo_dir" 2>/dev/null || {
		shell::logger::error "Cannot access directory: ${_repo_dir}"
		[ -n "$_tmp_dir" ] && rm -rf "$_tmp_dir" 2>/dev/null
		return $RETURN_FAILURE
	}

	shell::logger::info "Gathering repository statistics…"
	shell::logger::info "(Section E — code growth — may be slow on large repositories)"

	# ── A. REPOSITORY IDENTITY ───────────────────────────────────────────────
	local repo_name repo_url default_branch current_branch
	local first_commit_date last_commit_date first_commit_ts now_ts
	local repo_age_days repo_age_years repo_age_str

	repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
	repo_url=$(git config --get remote.origin.url 2>/dev/null || echo "(no remote)")
	default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|.*/||')
	[ -z "$default_branch" ] && default_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
	first_commit_date=$(git log --reverse --format='%ad' --date=format:'%Y-%m-%d' 2>/dev/null | head -1)
	last_commit_date=$(git log -1 --format='%ad' --date=format:'%Y-%m-%d' 2>/dev/null)
	first_commit_ts=$(git log --reverse --format='%ct' 2>/dev/null | head -1)
	now_ts=$(date +%s)
	repo_age_days=$(((now_ts - ${first_commit_ts:-$now_ts}) / 86400))
	repo_age_years=$(awk "BEGIN{printf \"%.1f\", ${repo_age_days}/365}")
	repo_age_str="${repo_age_years} years (${repo_age_days} days)"

	# ── B. OBJECT COUNTS ─────────────────────────────────────────────────────
	local total_commits total_branches total_tags total_contributors
	local total_files total_dirs total_loc

	total_commits=$(git rev-list --count HEAD 2>/dev/null || echo "0")
	total_branches=$(git branch -r 2>/dev/null | grep -v 'HEAD' | wc -l | tr -d ' ')
	total_tags=$(git tag 2>/dev/null | wc -l | tr -d ' ')
	total_contributors=$(git log --format='%aN' 2>/dev/null | sort -u | wc -l | tr -d ' ')
	total_files=$(find . -type f -not -path './.git/*' 2>/dev/null | wc -l | tr -d ' ')
	total_dirs=$(find . -mindepth 1 -type d -not -path './.git/*' -not -name '.git' 2>/dev/null | wc -l | tr -d ' ')
	total_loc=$(find . -type f -not -path './.git/*' 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
	[ -z "$total_loc" ] && total_loc="0"

	# ── C. COMMIT ACTIVITY ───────────────────────────────────────────────────
	local since_24h since_7d since_30d since_90d since_1y
	local avg_per_day avg_per_week avg_per_month
	local most_active_month least_active_month peak_day peak_hour

	since_24h=$(git log --oneline --since="1 day ago" 2>/dev/null | wc -l | tr -d ' ')
	since_7d=$(git log --oneline --since="7 days ago" 2>/dev/null | wc -l | tr -d ' ')
	since_30d=$(git log --oneline --since="30 days ago" 2>/dev/null | wc -l | tr -d ' ')
	since_90d=$(git log --oneline --since="90 days ago" 2>/dev/null | wc -l | tr -d ' ')
	since_1y=$(git log --oneline --since="1 year ago" 2>/dev/null | wc -l | tr -d ' ')

	avg_per_day=$(awk "BEGIN{if(${repo_age_days}>0) printf \"%.2f\", ${total_commits}/${repo_age_days}; else print \"0.00\"}")
	avg_per_week=$(awk "BEGIN{if(${repo_age_days}>0) printf \"%.1f\",  ${total_commits}/(${repo_age_days}/7);  else print \"0.0\"}")
	avg_per_month=$(awk "BEGIN{if(${repo_age_days}>0) printf \"%.1f\",  ${total_commits}/(${repo_age_days}/30); else print \"0.0\"}")

	most_active_month=$(git log --format='%ad' --date=format:'%Y-%m' 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
	least_active_month=$(git log --format='%ad' --date=format:'%Y-%m' 2>/dev/null | sort | uniq -c | sort -n | head -1 | awk '{print $2}')
	peak_day=$(git log --format='%ad' --date=format:'%A' 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
	peak_hour=$(git log --format='%ad' --date=format:'%H' 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $2":00"}')

	# ── D. CONTRIBUTORS ──────────────────────────────────────────────────────
	local active_7d active_30d active_90d top_contributors_raw contributor_commit_total

	active_7d=$(git log --since="7 days ago" --format='%aN' 2>/dev/null | sort -u | wc -l | tr -d ' ')
	active_30d=$(git log --since="30 days ago" --format='%aN' 2>/dev/null | sort -u | wc -l | tr -d ' ')
	active_90d=$(git log --since="90 days ago" --format='%aN' 2>/dev/null | sort -u | wc -l | tr -d ' ')
	top_contributors_raw=$(git log --format='%aN' 2>/dev/null | sort | uniq -c | sort -rn | head -10)
	contributor_commit_total=$(echo "$top_contributors_raw" | awk '{s+=$1} END{print s+0}')

	# ── E. CODE GROWTH (slow — full --numstat scan) ───────────────────────────
	local total_added total_deleted net_growth avg_commit_size

	local _growth_raw
	_growth_raw=$(git log --numstat --format='' 2>/dev/null | awk '/^[0-9]/{a+=$1; d+=$2} END{print a+0, d+0}')
	total_added=$(echo "$_growth_raw" | awk '{print $1}')
	total_deleted=$(echo "$_growth_raw" | awk '{print $2}')
	[ -z "$total_added" ] && total_added=0
	[ -z "$total_deleted" ] && total_deleted=0
	net_growth=$((total_added - total_deleted))
	avg_commit_size=$(awk "BEGIN{if(${total_commits}>0) printf \"%.1f\", (${total_added}+${total_deleted})/${total_commits}; else print \"0.0\"}")

	# ── F. CODE CHURN ────────────────────────────────────────────────────────
	local churn_rate hotspot_files_raw hotspot_dirs_raw

	churn_rate=$(awk "BEGIN{if(${total_added}>0) printf \"%.2f\", ${total_deleted}/${total_added}; else print \"0.00\"}")
	hotspot_files_raw=$(git log --name-only --format='' 2>/dev/null | grep -v '^$' | sort | uniq -c | sort -rn | head -10)
	hotspot_dirs_raw=$(git log --name-only --format='' 2>/dev/null | grep -v '^$' |
		sed 's|/[^/]*$||' | grep -v '^$' | sort | uniq -c | sort -rn | head -10)

	# ── G. COMMIT QUALITY ────────────────────────────────────────────────────
	local merge_commits revert_commits fixup_commits avg_msg_length conv_raw conv_total

	merge_commits=$(git log --merges --oneline 2>/dev/null | wc -l | tr -d ' ')
	revert_commits=$(git log --oneline --grep='^[Rr]evert' 2>/dev/null | wc -l | tr -d ' ')
	fixup_commits=$(git log --oneline --grep='^fixup!' 2>/dev/null | wc -l | tr -d ' ')
	avg_msg_length=$(git log --format='%s' 2>/dev/null |
		awk '{t+=length($0); c++} END{if(c>0) printf "%.0f", t/c; else print "0"}')
	conv_raw=$(git log --format='%s' 2>/dev/null |
		grep -oE '^(feat|fix|chore|docs|test|refactor|style|ci|build|perf)(\([^)]*\))?:' |
		sed 's/([^)]*)//g; s/://' | sort | uniq -c | sort -rn)
	conv_total=$(echo "$conv_raw" | awk '{s+=$1} END{print s+0}')

	# ── H. BRANCH METRICS ────────────────────────────────────────────────────
	local local_branch_count=0 active_branch_count=0 stale_branch_count=0
	local oldest_branch oldest_branch_date stale_threshold_ts

	# Cross-platform: macOS date -v, Linux date -d
	stale_threshold_ts=$(date -v-90d +%s 2>/dev/null || date -d "90 days ago" +%s 2>/dev/null || echo "0")

	local _bname _bts
	while IFS= read -r _bname; do
		[ -z "$_bname" ] && continue
		local_branch_count=$((local_branch_count + 1))
		_bts=$(git log -1 --format='%ct' "${_bname}" 2>/dev/null || echo "0")
		[ -z "$_bts" ] && _bts=0
		if [ "${_bts}" -ge "${stale_threshold_ts}" ] 2>/dev/null; then
			active_branch_count=$((active_branch_count + 1))
		else
			stale_branch_count=$((stale_branch_count + 1))
		fi
	done < <(git branch | sed 's|^[* ]*||')

	oldest_branch=$(git for-each-ref --sort=committerdate refs/heads/ --format='%(refname:short)' 2>/dev/null | head -1)
	[ -n "$oldest_branch" ] &&
		oldest_branch_date=$(git log -1 --format='%ad' --date=format:'%Y-%m-%d' "${oldest_branch}" 2>/dev/null)

	# ── I. TAG METRICS ───────────────────────────────────────────────────────
	local latest_tag first_tag

	latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "(none)")
	first_tag=$(git tag --sort=version:refname 2>/dev/null | head -1)
	[ -z "$first_tag" ] && first_tag="(none)"

	# ── J. TIME DISTRIBUTION ─────────────────────────────────────────────────
	local by_weekday_raw by_hour_top5_raw office_pct after_hours_pct weekend_pct

	by_weekday_raw=$(git log --format='%ad' --date=format:'%A' 2>/dev/null | sort | uniq -c | sort -rn)
	by_hour_top5_raw=$(git log --format='%ad' --date=format:'%H' 2>/dev/null | sort | uniq -c | sort -rn | head -5)

	# %u → ISO day number: 1=Mon … 7=Sun; h = hour (0-23)
	local _time_data office_c after_c weekend_c
	_time_data=$(git log --format='%ad' --date=format:'%H %u' 2>/dev/null)
	office_c=$(echo "$_time_data" | awk '{h=$1+0; d=$2+0; if(d<=5 && h>=9 && h<18) c++} END{print c+0}')
	after_c=$(echo "$_time_data" | awk '{h=$1+0; d=$2+0; if(d<=5 && (h<9||h>=18)) c++} END{print c+0}')
	weekend_c=$(echo "$_time_data" | awk '{d=$2+0; if(d>=6) c++} END{print c+0}')

	office_pct=$(awk "BEGIN{if(${total_commits}>0) printf \"%.1f\", ${office_c}*100/${total_commits};  else print \"0.0\"}")
	after_hours_pct=$(awk "BEGIN{if(${total_commits}>0) printf \"%.1f\", ${after_c}*100/${total_commits};   else print \"0.0\"}")
	weekend_pct=$(awk "BEGIN{if(${total_commits}>0) printf \"%.1f\", ${weekend_c}*100/${total_commits}; else print \"0.0\"}")

	# ── K. LANGUAGE DISTRIBUTION ─────────────────────────────────────────────
	local lang_raw

	lang_raw=$(find . -type f -not -path './.git/*' 2>/dev/null |
		grep -oE '\.[^./]+$' | tr '[:upper:]' '[:lower:]' | sort | uniq -c | sort -rn | head -15)

	# ── L. HEALTH SCORE ──────────────────────────────────────────────────────
	local score_activity score_contributors score_growth score_maintenance total_score

	# Activity  (0-25): commits_30d ≥ 10 → full score; linear below
	score_activity=$(awk "BEGIN{s=(${since_30d}>=10)?25:int(${since_30d}*2.5); print s}")
	# Contributors (0-25): ≥3 active in 30d → full; linear below
	score_contributors=$(awk "BEGIN{s=(${active_30d}>=3)?25:int(${active_30d}*8); if(s>25)s=25; print s}")
	# Growth (0-25): net positive → 25, zero → 15, negative → 5
	if [ "${net_growth}" -gt 0 ]; then
		score_growth=25
	elif [ "${net_growth}" -eq 0 ]; then
		score_growth=15
	else score_growth=5; fi
	# Maintenance (0-25): conventional commit ratio × 25, capped
	score_maintenance=$(awk "BEGIN{if(${total_commits}>0 && ${conv_total}>0){s=int(${conv_total}*25/${total_commits}); if(s>25)s=25; print s}else print 0}")
	total_score=$((score_activity + score_contributors + score_growth + score_maintenance))

	# ── PRINT REPORT ─────────────────────────────────────────────────────────
	local _lw=28 # label column width for printf alignment
	local _hr="  ══════════════════════════════════════════════════════════"
	local _sr="  ──────────────────────────────────────────────────────────"

	shell::logger::info ""
	shell::logger::info "${_hr}"
	shell::logger::info "  GIT REPOSITORY STATS  ·  ${repo_name}"
	shell::logger::info "${_hr}"

	# ── A ──
	shell::logger::info ""
	shell::logger::info "  A. REPOSITORY IDENTITY"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Name" "${repo_name}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "URL" "${repo_url}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Default Branch" "${default_branch}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Current Branch" "${current_branch}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Repository Age" "${repo_age_str}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "First Commit" "${first_commit_date}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Last Commit" "${last_commit_date}")"

	# ── B ──
	shell::logger::info ""
	shell::logger::info "  B. REPOSITORY SIZE"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Commits" "${total_commits}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Branches (remote)" "${total_branches}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Tags" "${total_tags}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Contributors" "${total_contributors}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Files" "${total_files}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Directories" "${total_dirs}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Current LOC" "${total_loc}")"

	# ── C ──
	shell::logger::info ""
	shell::logger::info "  C. COMMIT ACTIVITY"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Last 24 hours" "${since_24h}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Last 7 days" "${since_7d}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Last 30 days" "${since_30d}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Last 90 days" "${since_90d}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Last year" "${since_1y}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Avg per day" "${avg_per_day}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Avg per week" "${avg_per_week}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Avg per month" "${avg_per_month}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Most active month" "${most_active_month}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Least active month" "${least_active_month}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Peak day" "${peak_day}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Peak hour" "${peak_hour}")"

	# ── D ──
	shell::logger::info ""
	shell::logger::info "  D. CONTRIBUTORS"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total" "${total_contributors}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Active (7d)" "${active_7d}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Active (30d)" "${active_30d}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Active (90d)" "${active_90d}")"
	shell::logger::info ""
	shell::logger::info "  Top Contributors (by commits):"
	echo "$top_contributors_raw" | while IFS= read -r _line; do
		[ -z "$_line" ] && continue
		local _cnt _name _share
		_cnt=$(echo "$_line" | awk '{print $1}')
		_name=$(echo "$_line" | awk '{$1=""; sub(/^ /,""); print}')
		_share=$(awk "BEGIN{if(${contributor_commit_total}>0) printf \"%.1f\", ${_cnt}*100/${contributor_commit_total}; else print \"0.0\"}")
		shell::logger::info "$(printf '    %-6s %-28s %s%%' "${_cnt}" "${_name}" "${_share}")"
	done

	# ── E ──
	shell::logger::info ""
	shell::logger::info "  E. CODE GROWTH"
	local _net_sign=""
	[ "${net_growth}" -ge 0 ] && _net_sign="+"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Added Lines" "${total_added}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Deleted Lines" "${total_deleted}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Net Growth" "${_net_sign}${net_growth} lines")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Avg Commit Size" "${avg_commit_size} lines (added+deleted)")"

	# ── F ──
	shell::logger::info ""
	shell::logger::info "  F. CODE CHURN"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Churn Rate" "${churn_rate}  (deleted ÷ added)")"
	shell::logger::info ""
	shell::logger::info "  Top 10 Most Modified Files:"
	echo "$hotspot_files_raw" | while IFS= read -r _line; do
		[ -n "$_line" ] && shell::logger::info "    ${_line}"
	done
	shell::logger::info ""
	shell::logger::info "  Top 10 Most Modified Directories:"
	echo "$hotspot_dirs_raw" | while IFS= read -r _line; do
		[ -n "$_line" ] && shell::logger::info "    ${_line}"
	done

	# ── G ──
	shell::logger::info ""
	shell::logger::info "  G. COMMIT QUALITY"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Merge Commits" "${merge_commits}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Revert Commits" "${revert_commits}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Fixup Commits" "${fixup_commits}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Avg Message Length" "${avg_msg_length} chars")"
	shell::logger::info ""
	shell::logger::info "  Conventional Commit Breakdown:"
	if [ -n "$conv_raw" ] && [ "${conv_total}" -gt 0 ]; then
		echo "$conv_raw" | while IFS= read -r _line; do
			[ -z "$_line" ] && continue
			local _cnt _type _pct
			_cnt=$(echo "$_line" | awk '{print $1}')
			_type=$(echo "$_line" | awk '{print $2}')
			_pct=$(awk "BEGIN{if(${total_commits}>0) printf \"%.1f\", ${_cnt}*100/${total_commits}; else print \"0.0\"}")
			shell::logger::info "$(printf '    %-12s %6s commits  %s%%' "${_type}" "${_cnt}" "${_pct}")"
		done
		shell::logger::info "$(printf '    %-12s %6s commits' "(conventional)" "${conv_total}")"
		shell::logger::info "$(printf '    %-12s %6s commits' "(total)" "${total_commits}")"
	else
		shell::logger::info "    (no conventional commits detected)"
	fi

	# ── H ──
	shell::logger::info ""
	shell::logger::info "  H. BRANCH METRICS"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Local Branches" "${local_branch_count}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Remote Branches" "${total_branches}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Active (<= 90 days)" "${active_branch_count}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Stale (> 90 days)" "${stale_branch_count}")"
	if [ -n "$oldest_branch" ]; then
		shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Oldest Branch" "${oldest_branch}  (${oldest_branch_date})")"
	fi

	# ── I ──
	shell::logger::info ""
	shell::logger::info "  I. TAG METRICS"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Tags" "${total_tags}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Latest Tag" "${latest_tag}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "First Tag" "${first_tag}")"

	# ── J ──
	shell::logger::info ""
	shell::logger::info "  J. TIME DISTRIBUTION"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Peak Day" "${peak_day}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Peak Hour" "${peak_hour}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Office Hours (9-18 M-F)" "${office_pct}%")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "After Hours" "${after_hours_pct}%")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Weekend" "${weekend_pct}%")"
	shell::logger::info ""
	shell::logger::info "  Commits by Weekday:"
	echo "$by_weekday_raw" | while IFS= read -r _line; do
		[ -z "$_line" ] && continue
		local _cnt _day _pct
		_cnt=$(echo "$_line" | awk '{print $1}')
		_day=$(echo "$_line" | awk '{print $2}')
		_pct=$(awk "BEGIN{if(${total_commits}>0) printf \"%.1f\", ${_cnt}*100/${total_commits}; else print \"0.0\"}")
		shell::logger::info "$(printf '    %-12s %6s commits  %s%%' "${_day}" "${_cnt}" "${_pct}")"
	done
	shell::logger::info ""
	shell::logger::info "  Top 5 Busiest Hours (UTC):"
	echo "$by_hour_top5_raw" | while IFS= read -r _line; do
		[ -z "$_line" ] && continue
		local _cnt _hr
		_cnt=$(echo "$_line" | awk '{print $1}')
		_hr=$(echo "$_line" | awk '{print $2}')
		shell::logger::info "$(printf '    %s:00        %6s commits' "${_hr}" "${_cnt}")"
	done

	# ── K ──
	shell::logger::info ""
	shell::logger::info "  K. LANGUAGE DISTRIBUTION"
	if [ -n "$lang_raw" ]; then
		echo "$lang_raw" | while IFS= read -r _line; do
			[ -z "$_line" ] && continue
			local _cnt _ext _pct
			_cnt=$(echo "$_line" | awk '{print $1}')
			_ext=$(echo "$_line" | awk '{print $2}')
			_pct=$(awk "BEGIN{if(${total_files}>0) printf \"%.1f\", ${_cnt}*100/${total_files}; else print \"0.0\"}")
			shell::logger::info "$(printf '    %-12s %6s files    %s%%' "${_ext}" "${_cnt}" "${_pct}")"
		done
	else
		shell::logger::info "    (no files found)"
	fi

	# ── L ──
	shell::logger::info ""
	shell::logger::info "  L. REPOSITORY HEALTH SCORE"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Activity (commits 30d)" "${score_activity}/25")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Contributors (active 30d)" "${score_contributors}/25")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Growth (net LOC)" "${score_growth}/25")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Maintenance (conv. commits)" "${score_maintenance}/25")"
	shell::logger::info "  ${_sr}"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Health Score" "${total_score}/100")"

	shell::logger::info ""
	shell::logger::info "${_hr}"
	shell::logger::info ""

	# Return to original directory and remove temp clone if any.
	cd "$_orig_dir" 2>/dev/null
	[ -n "$_tmp_dir" ] && rm -rf "$_tmp_dir" 2>/dev/null

	return $RETURN_SUCCESS
}

# @description Clones a remote Git repository as a shallow clone (depth 1) into a specified
#   local folder name.
#
#   Runs:
#   git clone --depth 1 <repo_uri> <folder_name>
#   The --depth 1 flag creates a shallow clone with only the latest commit,
#   minimising download size and clone time. The command is logged via
#   shell::logger::assert.
# @option -n | --dry-run Optional. Print the command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @arg $1 string repo_uri: The URI of the remote Git repository to clone.
# @arg $2 string folder_name: The local directory name to clone into.
# @exitcode 0 Success.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::repos::fetch "https://github.com/org/repo.git" "my-repo"
#   shell::git::repos::fetch -n "https://github.com/org/repo.git" "my-repo"
#
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

# @description Retrieves the latest release tag from a GitHub repository using the GitHub API.
#
#   Notes:
#   - Requires internet access.
#   - Works on both macOS and Linux.
# @arg $1 string owner/repo: GitHub repository in the format 'owner/repo'
# @exitcode 0 Success.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::repos::version::latest "cli/cli"
#
shell::git::repos::version::latest() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Retrieve latest release tag from GitHub repository"
		shell::logger::usage "shell::git::repos::version::latest <owner/repo>"
		shell::logger::item "owner/repo" "GitHub repository in the format 'owner/repo'"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::example "shell::git::repos::version::latest \"cli/cli\""
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
		if shell::command::exists jq; then
			shell::logger::command_clip "$cmd_with_jq"
		else
			shell::logger::command_clip "$cmd_with_grep"
		fi
	else
		if shell::command::exists jq; then
			shell::logger::assert "$cmd_with_jq" "GitHub latest release retrieved" "GitHub latest release aborted"
		else
			shell::logger::assert "$cmd_with_grep" "GitHub latest release retrieved" "GitHub latest release aborted"
		fi
	fi
	return $RETURN_SUCCESS
}

# @description Fetches a specific remote branch, checks it out, and syncs local state to the
#   remote tip. Detects uncommitted changes and unpushed local commits, then shows
#   an fzf strategy picker only when the local state requires a decision.
#
#   Step 1 — Switch to the target branch (skipped when already on it):
#   git fetch origin <branch>:<branch>   (blocked when already checked out — detected)
#   git checkout <branch>
#   Step 2 — Targeted fetch (guarantees refs/remotes/origin/<branch> exists):
#   git fetch origin <branch>
#   Step 3 — Sync all remotes and tags:
#   git fetch --all --tags
#   Step 4 — Detect local state and act:
#   clean (no uncommitted, no local commits) → auto git reset --hard origin/<branch>
#   local commits only                       → fzf: rebase (recommended) | reset --hard
#   uncommitted changes only                 → fzf: stash+reset+pop (recommended) | reset --hard
#   both uncommitted + local commits         → fzf: stash+rebase+pop (recommended) | reset --hard
# @option -n | --dry-run Optional. Print each command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @arg $1 string branch: Name of the remote branch to fetch and check out.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::branch::checkout "feature/my-branch"
#   shell::git::branch::checkout -n "feature/my-branch"
#
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
		strategy=$(shell::ask::option::value \
			"$opt_rebase" \
			"$opt_reset")

	elif [ "$has_uncommitted" = "true" ] && [ "${local_ahead}" -eq 0 ]; then
		# Case 3: uncommitted changes only, no local commits.
		strategy=$(shell::ask::option::value \
			"$opt_stash_reset" \
			"$opt_reset")

	else
		# Case 4: both uncommitted changes and local commits.
		strategy=$(shell::ask::option::value \
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

# @description Checks out the currently active branch by name, effectively re-checking it out.
#   This is useful for triggering branch-specific hooks or refreshing the working tree
#   without switching to a different branch. If not inside a Git repository, an error
#   is logged and the function returns with failure.
# @option -n | --dry-run Optional. Print the command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::branch::checkout::current
#   shell::git::branch::checkout::current -n
#
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

# @description Creates one or more local Git branches, pushes each to origin with upstream
#   tracking, then restores the original branch.
#
#   For each valid branch name, runs:
#   1. git checkout -b <branch>          — create and switch to the new branch
#   2. git push -u origin <branch>       — push and set upstream tracking
#   After all branches are processed, returns to the originally checked-out branch
#   captured at function entry. Each step is logged via shell::logger::assert
#   and stops the per-branch loop on the first failure for that branch.
# @option -n | --dry-run Optional. Print each command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @arg $@ string branch...: One or more branch names to create. Each name must match the regex ^[a-zA-Z0-9_-]+$ (letters, digits, hyphen, underscore). Invalid names are skipped with a warning.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::branch::create feature_a feature_b
#   shell::git::branch::create -n feature_a feature_b
#
shell::git::branch::create() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Create local branches, push them to origin with upstream tracking, then restore current branch"
		shell::logger::usage "shell::git::branch::create [-n] [-h] <branch> [<branch> ...]"
		shell::logger::item "branch" "Branch name(s) matching ^[a-zA-Z0-9_./-]+$"
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

	local branch_regex='^[a-zA-Z0-9_./-]+$'
	local branch
	local cmd_checkout_new
	local cmd_push_upstream

	for branch in "$@"; do
		if ! [[ "$branch" =~ $branch_regex ]]; then
			shell::logger::warn "Invalid branch name '${branch}' — only letters, digits, hyphens, underscores, dots, and slashes allowed; skipping"
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

	return $RETURN_SUCCESS
}

# @description Syncs all remote branches to local: fetches and prunes all remotes, creates
#   local tracking branches for new remote branches, and fast-forwards local
#   branches that have no local-only commits ahead of origin.
#
#   1. git fetch --all --prune         — update all remote-tracking refs, remove stale ones
#   2. For each remote branch in origin (excluding HEAD):
#   - Not present locally  → git branch --track <branch> origin/<branch>
#   - Currently checked out → skip with info (use shell::git::branch::checkout)
#   - local_ahead == 0     → git branch -f <branch> origin/<branch>  (fast-forward)
#   - local_ahead  > 0     → warn and skip
# @option -n | --dry-run Optional. Print each command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::branch::sync
#   shell::git::branch::sync -n
#
shell::git::branch::sync() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Sync all remote branches to local — fetch, prune, create, and fast-forward"
		shell::logger::usage "shell::git::branch::sync [-n] [-h]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::example "shell::git::branch::sync"
		shell::logger::example "shell::git::branch::sync -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	if [ -z "$current_branch" ]; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	local cmd_fetch_prune="git fetch --all --prune"

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_fetch_prune"
		shell::logger::command_clip "git branch --track <branch> origin/<branch>  # per new remote branch"
		shell::logger::command_clip "git branch -f <branch> origin/<branch>       # per clean local branch"
		return $RETURN_SUCCESS
	fi

	shell::logger::assert "$cmd_fetch_prune" \
		"All remotes fetched and stale tracking refs pruned" "Fetch all aborted" || return $?

	local remote_branch
	local branch
	local local_ahead
	local cmd_create
	local cmd_update

	while IFS= read -r remote_branch; do
		# Strip leading whitespace and "origin/" prefix.
		branch=$(echo "$remote_branch" | sed 's|^[[:space:]]*origin/||')

		if ! git rev-parse --verify --quiet "refs/heads/${branch}" >/dev/null 2>&1; then
			# Local branch does not exist — create a local tracking branch.
			cmd_create="git branch --track \"${branch}\" \"origin/${branch}\""
			shell::logger::assert "$cmd_create" \
				"Local tracking branch '${branch}' created" "Failed to create local branch '${branch}'"

		elif [ "$branch" = "$current_branch" ]; then
			# Currently checked out — divergence must be resolved by the user.
			shell::logger::info "Branch '${branch}' is currently checked out — skipping (use shell::git::branch::checkout to sync)"

		else
			# Local branch exists and is not checked out — fast-forward if clean.
			local_ahead=$(git rev-list "origin/${branch}..refs/heads/${branch}" --count 2>/dev/null || echo "0")
			if [ "${local_ahead}" -eq 0 ]; then
				cmd_update="git branch -f \"${branch}\" \"origin/${branch}\""
				shell::logger::assert "$cmd_update" \
					"Branch '${branch}' fast-forwarded to origin/${branch}" "Failed to fast-forward branch '${branch}'"
			else
				shell::logger::warn "Branch '${branch}' has ${local_ahead} local commit(s) ahead of origin — skipping"
			fi
		fi
	done < <(git branch -r | grep 'origin/' | grep -v 'HEAD')

	return $RETURN_SUCCESS
}

# @description Deletes one or more Git branches both locally (force-delete) and on the remote
#   origin, then restores the originally checked-out branch.
#
#   Captures the currently checked-out branch at function entry, then for each
#   provided branch name runs:
#   1. git branch -D <branch>            — force-delete the local branch
#   2. git push origin --delete <branch> — delete the branch on origin
#   After all branches are processed, restores the original branch via
#   git checkout. Each step is logged via shell::logger::assert and stops
#   the per-branch iteration on the first failure for that branch.
# @option -n | --dry-run Optional. Print each command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @arg $@ string branch...: One or more branch names to delete.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::branch::remove feature_a feature_b
#   shell::git::branch::remove -n feature_a
#
shell::git::branch::remove() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Force-delete local and remote Git branches, then restore current branch"
		shell::logger::usage "shell::git::branch::remove [-n] [-h] <branch> [<branch> ...]"
		shell::logger::item "branch" "One or more branch names to delete"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::example "shell::git::branch::remove feature_a feature_b"
		shell::logger::example "shell::git::branch::remove -n feature_a"
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

	local branch
	local cmd_delete_local
	local cmd_delete_remote
	local remote_failed="false"

	for branch in "$@"; do
		cmd_delete_local="git branch -D \"${branch}\""
		cmd_delete_remote="git push origin --delete \"${branch}\""

		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "$cmd_delete_local"
			shell::logger::command_clip "$cmd_delete_remote"
			continue
		fi

		# Local delete: hard stop on failure — if the local branch is gone
		# already (or another local error), there is nothing safe to continue with.
		shell::logger::assert "$cmd_delete_local" \
			"Branch '${branch}' deleted locally" "Local branch delete aborted" || return $?

		# Remote delete: log the error but continue so remaining branches in the
		# list are still processed (common case: branch never pushed to origin).
		if ! shell::logger::assert "$cmd_delete_remote" \
			"Branch '${branch}' deleted on origin" \
			"Remote delete failed for '${branch}' — branch may not exist on origin; continuing"; then
			remote_failed="true"
		fi
	done

	# Surface a summary warning when at least one remote delete was skipped.
	if [ "$remote_failed" = "true" ]; then
		shell::logger::warn "One or more remote branch deletes failed — run 'git push origin --delete <branch>' manually for those branches"
	fi

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

# @description Presents an interactive fzf picker of git push strategies for a given branch,
#   confirms with the user, then executes the selected command.
#
#   Builds a set of labelled push strategies (label:command pairs), presents
#   them via shell::ask::option::value (fzf), prompts for confirmation, then
#   runs the selected git command via shell::logger::assert.
#   Available strategies:
#   - Set upstream tracking        git push -u origin <branch>
#   - Push all branches            git push --all origin
#   - Push all tags                git push --tags origin
#   - Force-push (unsafe)          git push --force origin <branch>
#   - Force-push with lease (safe) git push --force-with-lease origin <branch>
#   - Delete branch from remote    git push --delete origin <branch>
#   - Mirror local repo            git push --mirror origin
#   - Simulate push (dry-run)      git push --dry-run origin <branch>
#   - Push with CI skip            git push -o ci.skip origin <branch>
#   - Prune deleted remote refs    git push --prune origin
#   - Push with GPG signing        git push --signed origin <branch>
#   - Simple push                  git push
# @option -n | --dry-run Optional. After selection and confirmation, print the selected command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @arg $1 string branch: Branch name to substitute into push commands.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::branch::push "main"
#   shell::git::branch::push -n "feature/my-branch"
#
shell::git::branch::push() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively select and execute a git push command for a branch"
		shell::logger::usage "shell::git::branch::push [-n] [-h] <branch>"
		shell::logger::item "branch" "Branch name to use in push commands"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the selected command instead of executing it"
		shell::logger::example "shell::git::branch::push \"main\""
		shell::logger::example "shell::git::branch::push -n \"feature/my-branch\""
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

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# ---------------------------------------------------------------------------
	# Push command options — Label:command pairs for shell::ask::option::value.
	# Labels are human-readable (no colons); keys are the git commands to run.
	# ---------------------------------------------------------------------------
	local -a push_options=(
		"Push and set upstream tracking:git push -u origin \"${branch}\""
		"Push all branches to remote:git push --all origin"
		"Push all tags to remote:git push --tags origin"
		"Force-push the branch (unsafe):git push --force origin \"${branch}\""
		"Force-push with lease (safe):git push --force-with-lease origin \"${branch}\""
		"Delete branch from remote:git push --delete origin \"${branch}\""
		"Mirror local repo to remote:git push --mirror origin"
		"Simulate push without changes:git push --dry-run origin \"${branch}\""
		"Push with CI skip option:git push -o ci.skip origin \"${branch}\""
		"Prune deleted remote branches:git push --prune origin"
		"Push with GPG signing:git push --signed origin \"${branch}\""
		"Simple push to remote:git push"
	)

	local selected_cmd
	selected_cmd=$(shell::ask::option::value "${push_options[@]}")

	if [ -z "$selected_cmd" ]; then
		shell::logger::warn "No push command selected — aborting"
		return $RETURN_SUCCESS
	fi

	shell::logger::info "Selected command: ${selected_cmd}"

	if shell::ask::deny "Execute this push command?"; then
		shell::logger::info "Push aborted"
		return $RETURN_SUCCESS
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$selected_cmd"
		return $RETURN_SUCCESS
	fi

	shell::logger::assert "$selected_cmd" \
		"Push executed successfully" "Push failed" || return $?

	return $RETURN_SUCCESS
}

# @description Convenience wrapper around shell::git::branch::push that automatically detects
#   the currently checked-out branch and invokes the push command for it.
# @option -n | --dry-run Optional. Print the command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @exitcode 1 The operation failed.
# @example
#   shell::git::branch::push::current
#   shell::git::branch::push::current -n
#
shell::git::branch::push::current() {
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	if [ -z "$current_branch" ]; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	shell::git::branch::push "$current_branch"
}

# @description Convenience wrapper around shell::git::branch::push that automatically detects
#   the currently checked-out branch and invokes a force-push command for it.
#   This is a specialized function for the common case of needing to force-push the
#   current branch to origin. It prompts for confirmation before executing the force-push.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::branch::push::current::force
#
shell::git::branch::push::current::force() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Force-push the currently active Git branch to origin"
		shell::logger::usage "shell::git::branch::push::current::force [-h]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::example "shell::git::branch::push::current::force"
		return $RETURN_SUCCESS
	fi

	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	if [ -z "$current_branch" ]; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	local force_cmd="git push --force origin \"${current_branch}\""

	if shell::ask::deny "Force-push the current branch '${current_branch}' to origin?"; then
		shell::logger::info "Force-push aborted"
		return $RETURN_SUCCESS
	fi

	shell::logger::assert "$force_cmd" \
		"Force-push executed successfully" "Force-push failed" || return $?

	return $RETURN_SUCCESS
}

# @description Creates a local backup branch pointing to the same commit as the given source
#   branch, without switching HEAD. Sends a Telegram activity notification on success.
#
#   Step 1 — Validate that the source branch exists locally.
#   If it is only on origin, offers a clear error message.
#   Step 2 — Build the backup branch name from the sanitized source name
#   and a timestamp (YYYYMMDD.HHMMSS).
#   Step 3 — Run: git branch <backup_name> <source_branch>
#   This creates the backup branch at the same commit as the source
#   WITHOUT switching HEAD — the working tree is never disturbed.
#   Step 4 — Push the backup branch to origin with upstream tracking:
#   git push -u origin <backup_name>
#   Step 5 — Log the backup name, copy it to the clipboard via shell::clipboard::copy,
#   and send a Telegram activity notification.
#
#   Safety notes:
#   • No checkout / restore cycle: HEAD never moves, so in-progress work is safe.
#   • The backup branch is pushed to origin immediately for remote storage.
#   • Backup names are collision-resistant: timestamp precision is 1 second.
# @option -n | --dry-run Optional. Print the git branch command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @arg $1 string branch: Source branch name to back up. Backup name pattern: backup/<sanitized-branch>/<YYYYMMDD.HHMMSS> <sanitized-branch> is the source branch name with every '/' replaced by '--' (double-dash) so that the backup hierarchy is always exactly two levels deep and single dashes inside branch names remain unambiguous.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid or missing arguments.
# @example
#   main                 → backup/main/20260618.215830
#   feature/TM-1234      → backup/feature--TM-1234/20260618.215830
#   release/v2.0/hotfix  → backup/release--v2.0--hotfix/20260618.215830
#   shell::git::branch::backup "main"
#   shell::git::branch::backup "feature/TM-1234"
#   shell::git::branch::backup -n "release/v2.0"
#
shell::git::branch::backup() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Create a local backup branch from a source branch without switching HEAD"
		shell::logger::usage "shell::git::branch::backup [-n] [-h] <branch>"
		shell::logger::item "branch" "Source branch name to back up"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the git branch command instead of executing it"
		shell::logger::example "shell::git::branch::backup \"main\""
		shell::logger::example "shell::git::branch::backup \"feature/TM-1234\""
		shell::logger::example "shell::git::branch::backup -n \"release/v2.0\""
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

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# Step 1 — verify the source branch exists locally.
	# git branch -f requires a local ref; refuse early with a helpful hint when
	# the branch lives only on the remote.
	if ! git rev-parse --verify --quiet "refs/heads/${branch}" >/dev/null 2>&1; then
		# Check whether it exists on origin so the error message is actionable.
		if git rev-parse --verify --quiet "refs/remotes/origin/${branch}" >/dev/null 2>&1; then
			shell::logger::error "Branch '${branch}' exists on origin but not locally — run 'git checkout ${branch}' first, then backup"
		else
			shell::logger::error "Branch '${branch}' does not exist locally or on origin"
		fi
		return $RETURN_FAILURE
	fi

	# Step 2 — build the backup branch name.
	# Replace every '/' in the source branch name with '--' (double-dash) so the
	# backup hierarchy is always exactly two levels deep:
	#   backup/<sanitized-branch>/<YYYYMMDD.HHMMSS>
	# Double-dash is chosen over single-dash to keep single dashes inside the
	# original branch name (e.g. "TM-1234") visually unambiguous.
	local sanitized_branch
	sanitized_branch=$(printf '%s' "${branch}" | tr '/' '-' | sed 's/-/-/g; s|/|--|g')
	# tr '/' replaces each '/' with '-'; for multi-segment names like
	# "feature/scope/detail", we want '--' not '-'. Re-process with parameter
	# substitution for portability:
	sanitized_branch=$(printf '%s' "${branch}" | sed 's|/|--|g')

	local timestamp
	timestamp=$(date +"%Y%m%d.%H%M%S")

	local backup_name="backup/${sanitized_branch}/${timestamp}"

	# ---------------------------------------------------------------------------
	# Commands — git branch (not checkout) so HEAD is never moved, then push.
	# ---------------------------------------------------------------------------
	local cmd_backup="git branch \"${backup_name}\" \"${branch}\""
	local cmd_push="git push -u origin \"${backup_name}\""

	shell::logger::info "Source branch  : ${branch}"
	shell::logger::info "Backup branch  : ${backup_name}"

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_backup"
		shell::logger::command_clip "$cmd_push"
		return $RETURN_SUCCESS
	fi

	# Step 3 — create backup branch (no HEAD movement).
	shell::logger::assert "$cmd_backup" \
		"Backup branch '${backup_name}' created from '${branch}'" \
		"Backup failed — branch creation aborted" || return $?

	# Step 4 — push backup branch to origin with upstream tracking.
	shell::logger::assert "$cmd_push" \
		"Backup branch '${backup_name}' pushed to origin" \
		"Backup push failed — run 'git push -u origin ${backup_name}' manually" || return $?

	# Step 5 — copy the backup branch name to the clipboard for easy reference.
	shell::clipboard::copy --best-effort "${backup_name}"

	# Collect metadata for the Telegram notification.
	local repository_path
	local repository_name
	local git_username
	local server_remote_url
	local notify_timestamp

	repository_path=$(git rev-parse --show-toplevel 2>/dev/null)
	repository_name=$(basename "${repository_path}")
	git_username=$(git config user.name 2>/dev/null)
	server_remote_url=$(git config --get remote.origin.url 2>/dev/null)
	notify_timestamp=$(date "+%Y-%m-%d %H:%M:%S")

	local telegram_message="Branch Backup Successfully (Local & Remote) | source: ${branch} | backup: ${backup_name} | repository: ${repository_name} (${server_remote_url}) | username: ${git_username} | timestamp: ${notify_timestamp}"
	shell::git::telegram::history::send "${telegram_message}"

	return $RETURN_SUCCESS
}

# @description Creates a local backup branch of the currently checked-out branch without switching HEAD. Sends a Telegram activity notification on success.
#
#   1. Determine the currently checked-out branch.
#   2. Call shell::git::branch::backup with the current branch name.
# @option -n | --dry-run Optional. Print the git branch command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @exitcode 1 The operation failed.
# @example
#   shell::git::branch::backup::current
#
shell::git::branch::backup::current() {
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	if [ -z "$current_branch" ]; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	shell::git::branch::backup "${current_branch}"
}

# @description Renames a local Git branch both locally and on the remote origin, then
#   restores the originally checked-out branch and sends a Telegram notification.
#
#   Step 1 — git branch -m <old_name> <new_name>      — rename locally
#   Step 2 — git push -u origin <new_name>            — push new name with upstream tracking
#   Step 3 — git push origin --delete <old_name>      — remove old name from origin
#   (failure is logged and warned but does not abort — the old name
#   may not exist on origin if it was never pushed)
#   Step 4 — git checkout <original_branch>           — restore originally checked-out branch
#   Step 5 — shell::git::telegram::send_activity      — Telegram notification
# @option -n | --dry-run Optional. Print each command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @arg $1 string old_name: Current branch name.
# @arg $2 string new_name: Desired new branch name.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::branch::rename "feature/old-name" "feature/new-name"
#   shell::git::branch::rename -n "main" "mainline"
#
shell::git::branch::rename() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Rename a Git branch locally and on remote origin, then restore current branch"
		shell::logger::usage "shell::git::branch::rename [-n] [-h] <old_name> <new_name>"
		shell::logger::item "old_name" "Current branch name"
		shell::logger::item "new_name" "Desired new branch name"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::example "shell::git::branch::rename \"feature/old-name\" \"feature/new-name\""
		shell::logger::example "shell::git::branch::rename -n \"main\" \"mainline\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local old_name="$1"
	local new_name="$2"

	if [ -z "$old_name" ]; then
		shell::logger::error "Old branch name is required"
		return $RETURN_INVALID
	fi

	if [ -z "$new_name" ]; then
		shell::logger::error "New branch name is required"
		return $RETURN_INVALID
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# Capture current branch so we can restore it after renaming.
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	# ---------------------------------------------------------------------------
	# Commands — declared upfront for dry-run printing and execution.
	# ---------------------------------------------------------------------------
	local cmd_rename="git branch -m \"${old_name}\" \"${new_name}\""
	local cmd_push_new="git push -u origin \"${new_name}\""
	local cmd_delete_old="git push origin --delete \"${old_name}\""
	local cmd_restore="git checkout \"${current_branch}\""

	shell::logger::info "Renaming branch  : '${old_name}' → '${new_name}'"

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_rename"
		shell::logger::command_clip "$cmd_push_new"
		shell::logger::command_clip "$cmd_delete_old"
		shell::logger::command_clip "$cmd_restore"
		return $RETURN_SUCCESS
	fi

	# Step 1 — rename locally.
	shell::logger::assert "$cmd_rename" \
		"Branch '${old_name}' renamed to '${new_name}' locally" \
		"Local branch rename aborted" || return $?

	# Step 2 — push new name to origin with upstream tracking.
	shell::logger::assert "$cmd_push_new" \
		"Branch '${new_name}' pushed to origin with upstream tracking" \
		"Push of renamed branch aborted" || return $?

	# Step 3 — delete old name on origin.
	# Non-fatal: the old name may never have been pushed to origin.
	if ! shell::logger::assert "$cmd_delete_old" \
		"Old branch '${old_name}' deleted on origin" \
		"Failed to delete '${old_name}' on origin — it may not exist remotely; continuing"; then
		shell::logger::warn "Run 'git push origin --delete ${old_name}' manually if the old remote branch still exists"
	fi

	# Step 4 — restore originally checked-out branch.
	# When the renamed branch was checked out, git branch -m already moved HEAD
	# to the new name, so we only need to restore if we were on a different branch.
	if [ "$current_branch" != "$old_name" ]; then
		shell::logger::assert "$cmd_restore" \
			"Restored original branch '${current_branch}'" \
			"Branch restore aborted" || return $?
	fi

	# Step 5 — Telegram notification.
	local repository_path
	local repository_name
	local git_username
	local server_remote_url
	local notify_timestamp

	repository_path=$(git rev-parse --show-toplevel 2>/dev/null)
	repository_name=$(basename "${repository_path}")
	git_username=$(git config user.name 2>/dev/null)
	server_remote_url=$(git config --get remote.origin.url 2>/dev/null)
	notify_timestamp=$(date "+%Y-%m-%d %H:%M:%S")

	local telegram_message="Branch Renamed Successfully | old: ${old_name} | new: ${new_name} | repository: ${repository_name} (${server_remote_url}) | username: ${git_username} | timestamp: ${notify_timestamp}"
	shell::git::telegram::history::send "${telegram_message}"

	return $RETURN_SUCCESS
}

# @description Renames the currently checked-out branch to a new name, both locally and on
#   the remote origin. Delegates entirely to shell::git::branch::rename.
# @option -n | --dry-run Optional. Print the commands instead of executing them.
# @option -h | --help Show this help message.
# @arg $1 string new_name: Desired new branch name.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::branch::rename::current "feature/new-name"
#   shell::git::branch::rename::current -n "feature/new-name"
#
shell::git::branch::rename::current() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Rename the currently checked-out branch locally and on remote origin"
		shell::logger::usage "shell::git::branch::rename::current [-n] [-h] <new_name>"
		shell::logger::item "new_name" "Desired new branch name"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::example "shell::git::branch::rename::current \"feature/new-name\""
		shell::logger::example "shell::git::branch::rename::current -n \"feature/new-name\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local new_name="$1"

	if [ -z "$new_name" ]; then
		shell::logger::error "New branch name is required"
		return $RETURN_INVALID
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	if [ -z "$current_branch" ]; then
		shell::logger::error "Could not determine current branch"
		return $RETURN_FAILURE
	fi

	if [ "$dry_run" = "true" ]; then
		shell::git::branch::rename -n "${current_branch}" "${new_name}"
	else
		shell::git::branch::rename "${current_branch}" "${new_name}"
	fi
}

# @description Presents an fzf picker of all local branches, prompts for a new name via
#   stdin, then delegates to shell::git::branch::rename.
#
#   Step 1 — Collect all local branch names and present via shell::ask::option.
#   Step 2 — Prompt for the desired new branch name (loops until non-empty).
#   Step 3 — Confirm and delegate to shell::git::branch::rename.
# @option -n | --dry-run Optional. Print the commands instead of executing them.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::branch::rename::fzf
#   shell::git::branch::rename::fzf -n
#
shell::git::branch::rename::fzf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Select a local branch via fzf and rename it locally and on remote origin"
		shell::logger::usage "shell::git::branch::rename::fzf [-n] [-h]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::example "shell::git::branch::rename::fzf"
		shell::logger::example "shell::git::branch::rename::fzf -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# Step 1 — collect local branch names.
	local -a local_branches
	while IFS= read -r b; do
		local_branches+=("$b")
	done < <(git branch | sed 's|^[* ]*||')

	if [ "${#local_branches[@]}" -eq 0 ]; then
		shell::logger::warn "No local branches found — aborting"
		return $RETURN_SUCCESS
	fi

	local old_name
	old_name=$(shell::ask::option "${local_branches[@]}")

	if [ -z "$old_name" ]; then
		shell::logger::warn "No branch selected — aborting"
		return $RETURN_SUCCESS
	fi

	# Step 2 — prompt for new name (loops until non-empty input).
	local new_name=""
	while [ -z "$new_name" ]; do
		shell::logger::info "Selected branch: ${old_name}"
		shell::logger::info "Enter new branch name:"
		read -r new_name
		if [ -z "$new_name" ]; then
			shell::logger::warn "New branch name cannot be empty — please try again"
		fi
	done

	# Step 3 — confirm and execute.
	shell::logger::info "Rename '${old_name}' → '${new_name}'"

	if shell::ask::deny "Proceed with rename?"; then
		shell::logger::info "Rename aborted"
		return $RETURN_SUCCESS
	fi

	if [ "$dry_run" = "true" ]; then
		shell::git::branch::rename -n "${old_name}" "${new_name}"
	else
		shell::git::branch::rename "${old_name}" "${new_name}"
	fi
}

# @description Lists all local and remote branches with sync-state labels, presents a
#   multi-select picker, then shows an action menu to act on the selected
#   branches using existing shell::git::* functions.
# @option -h | --help Show this help message. Branch label format (columns are fixed-width for alignment in fzf):
# @arg $@ string LOCAL | synced    : <branch>  — currently checked-out, in sync with origin
# @arg $@ string LOCAL | synced    : <branch>  — local, in sync with origin
# @arg $@ string LOCAL | +N/-M     : <branch>  — N local commits ahead, M remote commits behind
# @arg $@ string LOCAL | no-remote : <branch>  — local-only, no remote tracking ref
# @arg $@ string REMOTE            : <branch>  — exists only on origin, not present locally The ' : ' separator uses ':' which is prohibited in git branch names, making it a reliable extraction anchor in the space-joined multiselect output. Action menu (presented after branch selection via shell::ask::option::value): • Checkout                              → shell::git::branch::checkout      (first selected) • View commit history                   → shell::git::commit::spec           (first selected) • Browse commits and copy info          → shell::git::commit::spec::search   (first selected) • Cherry-pick commits onto current      → shell::git::commit::pick::local    (first selected) • Cherry-pick commits then push         → shell::git::commit::pick::remote   (first selected) • Backup selected branch(es)            → shell::git::branch::backup         (each selected) • Push selected branch(es) to remote    → shell::git::branch::push           (each selected) • Remove selected branch(es)            → shell::git::branch::remove         (all selected) • Sync all remote branches to local     → shell::git::branch::sync           (ignores selection) • Exit — noop                           → return immediately
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::branch::all::fzf
#
shell::git::branch::all::fzf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List all branches with sync labels, multi-select, then run an action"
		shell::logger::usage "shell::git::branch::all::fzf [-h]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::example "shell::git::branch::all::fzf"
		return $RETURN_SUCCESS
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# Refresh remote-tracking refs so sync status reflects the current remote state.
	shell::logger::info "Fetching remote refs to determine sync status..."
	git fetch --all --quiet 2>/dev/null

	# Capture the currently checked-out branch for the '*' active marker.
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	# ---------------------------------------------------------------------------
	# Collect local and remote branch names.
	# ---------------------------------------------------------------------------
	local -a local_branches
	while IFS= read -r b; do
		local_branches+=("$b")
	done < <(git branch | sed 's|^[* ]*||')

	local -a remote_branches
	while IFS= read -r b; do
		remote_branches+=("$b")
	done < <(git branch -r | grep 'origin/' | grep -v 'HEAD' | sed 's|^[[:space:]]*origin/||')

	# ---------------------------------------------------------------------------
	# Build display lines.
	#
	# Format: "M [LABEL              ] : branch_name"
	#   M     — '*' for the checked-out branch, ' ' otherwise
	#   LABEL — printf-padded to 20 chars for alignment:
	#             [LOCAL | %-10s]  (9 + 10 + 1 = 20)
	#             [%-18s]          (1 + 18 + 1 = 20)
	#   ' : ' — field separator; ':' is prohibited in git branch names so this
	#             token is a safe extraction anchor in the space-joined multiselect output
	# ---------------------------------------------------------------------------
	local -a branch_lines
	local b
	local label
	local status_str
	local local_ahead
	local remote_ahead
	local marker

	for b in "${local_branches[@]}"; do
		if git rev-parse --verify --quiet "refs/remotes/origin/${b}" >/dev/null 2>&1; then
			local_ahead=$(git rev-list "origin/${b}..refs/heads/${b}" --count 2>/dev/null || echo "0")
			remote_ahead=$(git rev-list "refs/heads/${b}..origin/${b}" --count 2>/dev/null || echo "0")
			if [ "${local_ahead}" -eq 0 ] && [ "${remote_ahead}" -eq 0 ]; then
				status_str="synced"
			else
				status_str="+${local_ahead}/-${remote_ahead}"
			fi
		else
			status_str="no-remote"
		fi

		label=$(printf "[LOCAL | %-10s]" "$status_str")
		marker=" "
		[ "$b" = "$current_branch" ] && marker="*"

		branch_lines+=("${marker} ${label} : ${b}")
	done

	# Add remote-only branches (branches on origin that have no local counterpart).
	local rb
	local is_local
	local remote_label
	remote_label=$(printf "[%-18s]" "REMOTE")

	for rb in "${remote_branches[@]}"; do
		is_local="false"
		for b in "${local_branches[@]}"; do
			[ "$b" = "$rb" ] && {
				is_local="true"
				break
			}
		done
		if [ "$is_local" = "false" ]; then
			branch_lines+=("  ${remote_label} : ${rb}")
		fi
	done

	if [ "${#branch_lines[@]}" -eq 0 ]; then
		shell::logger::warn "No branches found in this repository — aborting"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 1 — multi-select branch picker (TAB to mark multiple entries, Enter to confirm).
	# ---------------------------------------------------------------------------
	local selected_output
	selected_output=$(shell::ask::options "${branch_lines[@]}")

	if [ -z "$selected_output" ]; then
		shell::logger::warn "No branches selected — aborting"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 2 — extract branch names from the space-joined multiselect output.
	#
	# shell::ask::options joins selected lines with spaces (newlines → spaces).
	# The ' : ' separator (colon is prohibited in git ref names) followed by
	# non-space chars uniquely identifies each branch name in the joined string.
	#
	# Example joined output:
	#   "* [LOCAL | synced    ] : main   [LOCAL | +2/-0     ] : feature/TM-1234"
	# grep -oE ': [^ ]+' → [": main", ": feature/TM-1234"]
	# sed 's/: //'        → ["main", "feature/TM-1234"]
	# ---------------------------------------------------------------------------
	local -a selected_branches
	while IFS= read -r bname; do
		[ -n "$bname" ] && selected_branches+=("$bname")
	done < <(printf '%s' "$selected_output" | grep -oE ': [^ ]+' | sed 's/: //')

	if [ "${#selected_branches[@]}" -eq 0 ]; then
		shell::logger::warn "Could not parse branch names from selection — aborting"
		return $RETURN_SUCCESS
	fi

	# Resolve first selected branch in a cross-shell way.
	# bash uses 0-based array indexing; zsh uses 1-based indexing, so
	# ${array[0]} returns empty in zsh. Iterating and breaking after the
	# first element is index-free and works in both shells.
	local first_branch
	for first_branch in "${selected_branches[@]}"; do break; done

	local count="${#selected_branches[@]}"
	local branch_word="branch"
	[ "${count}" -gt 1 ] && branch_word="branches"

	# Log the selection for visibility.
	shell::logger::info "Selected ${count} ${branch_word}:"
	local _b
	for _b in "${selected_branches[@]}"; do
		shell::logger::info "  • ${_b}"
	done

	# ---------------------------------------------------------------------------
	# Step 3 — action menu.
	#
	# Uses shell::ask::option::value which splits each entry on the first ':'
	# to separate the display label from the key. Labels must not contain ':'.
	# Single-branch actions warn and apply to the first selected branch only.
	# Multi-branch actions iterate over (or pass) all selected branches.
	# ---------------------------------------------------------------------------
	local -a action_options=(
		"Checkout — first selected branch:checkout"
		"View commit history — first selected branch:view_commits"
		"Browse commits and copy info — first selected branch:search_commits"
		"Cherry-pick commits onto current branch — first selected branch:pick_local"
		"Cherry-pick commits onto current branch then push — first selected branch:pick_remote"
		"Backup ${count} selected ${branch_word} — local and remote:backup"
		"Push ${count} selected ${branch_word} to remote:push"
		"Remove ${count} selected ${branch_word} from local and remote:remove"
		"Sync all remote branches to local — ignores selection:sync"
		"Exit — noop:noop"
	)

	local action
	action=$(shell::ask::option::value "${action_options[@]}")

	if [ -z "$action" ] || [ "$action" = "noop" ]; then
		shell::logger::info "No action taken — exiting"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 4 — execute the selected action.
	# ---------------------------------------------------------------------------
	case "$action" in
	checkout)
		[ "${count}" -gt 1 ] && shell::logger::warn "Multiple branches selected — checkout applies to first: ${first_branch}"
		shell::git::branch::checkout "${first_branch}"
		;;

	view_commits)
		[ "${count}" -gt 1 ] && shell::logger::warn "Multiple branches selected — commit history applies to first: ${first_branch}"
		shell::git::commit::spec "${first_branch}"
		;;

	search_commits)
		[ "${count}" -gt 1 ] && shell::logger::warn "Multiple branches selected — commit browse applies to first: ${first_branch}"
		shell::git::commit::spec::search "${first_branch}"
		;;

	pick_local)
		[ "${count}" -gt 1 ] && shell::logger::warn "Multiple branches selected — cherry-pick source is first: ${first_branch}"
		shell::git::commit::pick::local "${first_branch}"
		;;

	pick_remote)
		[ "${count}" -gt 1 ] && shell::logger::warn "Multiple branches selected — cherry-pick source is first: ${first_branch}"
		shell::git::commit::pick::remote "${first_branch}"
		;;

	backup)
		shell::logger::info "Backing up ${count} ${branch_word}..."
		for _b in "${selected_branches[@]}"; do
			shell::logger::info "Backing up: ${_b}"
			shell::git::branch::backup "${_b}" || shell::logger::warn "Backup failed for '${_b}' — continuing with remaining branches"
		done
		;;

	push)
		shell::logger::info "Pushing ${count} ${branch_word} to remote..."
		for _b in "${selected_branches[@]}"; do
			shell::logger::info "Pushing: ${_b}"
			shell::git::branch::push "${_b}"
		done
		;;

	remove)
		# Extra confirmation before destructive removal.
		shell::logger::warn "This will permanently remove ${count} ${branch_word} from local and origin"
		for _b in "${selected_branches[@]}"; do
			shell::logger::warn "  • ${_b}"
		done
		if shell::ask::deny "Proceed with removal?"; then
			shell::logger::info "Remove aborted"
			return $RETURN_SUCCESS
		fi
		shell::git::branch::remove "${selected_branches[@]}"
		;;

	sync)
		shell::git::branch::sync
		;;
	esac

	return $RETURN_SUCCESS
}

# @description Merges a source branch into a target branch with conflict detection and an
#   interactive push step after a successful merge.
#
#   Step 1 — Capture the currently checked-out branch so it can be restored.
#   Step 2 — Checkout <target_branch>.
#   Step 3 — Run: git merge --no-commit <source_branch>
#   (stages changes without auto-creating the merge commit).
#   Step 4 — If unmerged files are present, list them with conflict counts
#   and return $RETURN_FAILURE so the user can resolve manually.
#   Step 5 — Confirm and commit: git commit -m "Merged <source> into <target>"
#   Step 6 — Delegate push to shell::git::branch::push (interactive strategy).
#   Step 7 — Restore the original branch.
#   Step 8 — Send Telegram activity notification.
# @option -n | --dry-run Optional. Print each command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @arg $1 string source_branch: Branch whose changes will be merged in.
# @arg $2 string target_branch: Branch that will receive the changes.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::branch::merge "feature/my-feature" "develop"
#   shell::git::branch::merge -n "feature/my-feature" "main"
#
shell::git::branch::merge() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Merge a source branch into a target branch with conflict detection and push"
		shell::logger::usage "shell::git::branch::merge [-n] [-h] <source_branch> <target_branch>"
		shell::logger::item "source_branch" "Branch whose changes will be merged in"
		shell::logger::item "target_branch" "Branch that will receive the changes"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::example "shell::git::branch::merge \"feature/my-feature\" \"develop\""
		shell::logger::example "shell::git::branch::merge -n \"feature/my-feature\" \"main\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local source_branch="$1"
	local target_branch="$2"

	if [ -z "$source_branch" ]; then
		shell::logger::error "Source branch is required"
		return $RETURN_INVALID
	fi

	if [ -z "$target_branch" ]; then
		shell::logger::error "Target branch is required"
		return $RETURN_INVALID
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# ---------------------------------------------------------------------------
	# Step 1 — Capture current branch to restore later.
	# ---------------------------------------------------------------------------
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	# ---------------------------------------------------------------------------
	# Command variables — declared upfront for dry-run printing.
	# ---------------------------------------------------------------------------
	local cmd_checkout="git checkout \"${target_branch}\""
	local cmd_merge="git merge --no-commit --no-ff \"${source_branch}\""
	local commit_msg="Merged ${source_branch} into ${target_branch}"
	local cmd_commit="git commit -m \"${commit_msg}\""
	local cmd_restore="git checkout \"${current_branch}\""

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_checkout"
		shell::logger::command_clip "$cmd_merge"
		shell::logger::command_clip "$cmd_commit"
		shell::logger::command_clip "git push --force-with-lease origin \"${target_branch}\""
		shell::logger::command_clip "$cmd_restore"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 2 — Checkout target branch.
	# ---------------------------------------------------------------------------
	shell::logger::assert "$cmd_checkout" \
		"Checked out '${target_branch}'" "Checkout of '${target_branch}' failed" || return $?

	# ---------------------------------------------------------------------------
	# Step 3 — Merge source into target (no auto-commit, force merge commit).
	# --no-ff ensures a merge commit is always created even when the merge is
	# a fast-forward, guaranteeing staged changes exist for the commit step.
	# ---------------------------------------------------------------------------
	shell::logger::info "Merging '${source_branch}' into '${target_branch}' (no-commit, no-ff) ..."
	if ! eval "$cmd_merge"; then
		# Merge command itself failed (e.g., invalid branch ref).
		shell::logger::error "Merge command failed — aborting"
		git merge --abort 2>/dev/null
		eval "$cmd_restore" 2>/dev/null
		return $RETURN_FAILURE
	fi

	# ---------------------------------------------------------------------------
	# Step 4 — Detect unmerged (conflict) files.
	# ---------------------------------------------------------------------------
	local -a unmerged_files
	while IFS= read -r f; do
		[ -n "$f" ] && unmerged_files+=("$f")
	done < <(git ls-files --unmerged 2>/dev/null | awk '{print $NF}' | sort -u)

	if [ "${#unmerged_files[@]}" -gt 0 ]; then
		shell::logger::error "Merge conflicts detected in ${#unmerged_files[@]} file(s):"
		local f conflict_count
		for f in "${unmerged_files[@]}"; do
			conflict_count=$(grep -c '<<<<<<< ' "$f" 2>/dev/null || echo 0)
			shell::logger::error "  • ${f}  (${conflict_count} conflict marker(s))"
		done
		shell::logger::info "Resolve the conflicts, then run:"
		shell::logger::info "  git add <file>..."
		shell::logger::info "  git commit -m \"${commit_msg}\""
		shell::logger::info "Or abort the merge with: git merge --abort"
		return $RETURN_FAILURE
	fi

	# ---------------------------------------------------------------------------
	# Step 5 — Confirm and commit.
	# ---------------------------------------------------------------------------
	shell::logger::info "No conflicts detected — ready to commit"
	shell::logger::info "Commit message: ${commit_msg}"

	if shell::ask::deny "Proceed with this merge commit?"; then
		shell::logger::info "Merge commit aborted — staged changes remain on '${target_branch}'"
		shell::logger::info "To discard: git merge --abort"
		return $RETURN_SUCCESS
	fi

	shell::logger::assert "$cmd_commit" \
		"Merge commit created on '${target_branch}'" "Commit failed" || return $?

	# ---------------------------------------------------------------------------
	# Step 6 — Push target branch via interactive push strategy picker.
	# ---------------------------------------------------------------------------
	shell::git::branch::push "${target_branch}"

	# ---------------------------------------------------------------------------
	# Step 7 — Restore original branch.
	# ---------------------------------------------------------------------------
	shell::logger::assert "$cmd_restore" \
		"Restored original branch '${current_branch}'" "Branch restore aborted" || return $?

	# ---------------------------------------------------------------------------
	# Step 8 — Send Telegram notification.
	# ---------------------------------------------------------------------------
	local git_username repo_path repo_name remote_url timestamp
	git_username=$(git config user.name 2>/dev/null)
	repo_path=$(git rev-parse --show-toplevel 2>/dev/null)
	repo_name=$(basename "${repo_path}")
	remote_url=$(git config --get remote.origin.url 2>/dev/null)
	timestamp=$(date "+%Y-%m-%d %H:%M:%S")

	local telegram_message="Merge | source: ${source_branch} → target: ${target_branch} | repository: ${repo_name} (${remote_url}) | username: ${git_username} | timestamp: ${timestamp}"
	shell::git::telegram::history::send "${telegram_message}"

	return $RETURN_SUCCESS
}

# @description Interactively selects source and target branches via fzf, then delegates to
#   shell::git::branch::merge to perform the merge.
#
#   Step 1 — Collect all local branch names.
#   Step 2 — Present source branch picker via shell::ask::option (fzf).
#   Step 3 — Present target branch picker via shell::ask::option (fzf),
#   excluding the source branch from the list.
#   Step 4 — Confirm the merge plan with the user.
#   Step 5 — Delegate to shell::git::branch::merge [-n] <source> <target>.
# @option -n | --dry-run Optional. Forward dry-run flag to shell::git::branch::merge.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::branch::merge::fzf
#   shell::git::branch::merge::fzf -n
#
shell::git::branch::merge::fzf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively select source and target branches for a merge via fzf"
		shell::logger::usage "shell::git::branch::merge::fzf [-n] [-h]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::example "shell::git::branch::merge::fzf"
		shell::logger::example "shell::git::branch::merge::fzf -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# ---------------------------------------------------------------------------
	# Step 1 — Collect all local branch names.
	# ---------------------------------------------------------------------------
	local -a all_branches
	while IFS= read -r b; do
		[ -n "$b" ] && all_branches+=("$b")
	done < <(git branch 2>/dev/null | sed 's|^[* ]*||')

	if [ "${#all_branches[@]}" -lt 2 ]; then
		shell::logger::error "At least 2 local branches are required for a merge"
		return $RETURN_FAILURE
	fi

	# ---------------------------------------------------------------------------
	# Step 2 — Pick source branch.
	# ---------------------------------------------------------------------------
	shell::logger::info "Select SOURCE branch (the branch to merge FROM):"
	local source_branch
	source_branch=$(shell::ask::option "${all_branches[@]}")

	if [ -z "$source_branch" ]; then
		shell::logger::warn "No source branch selected — aborting"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 3 — Pick target branch (source excluded).
	# ---------------------------------------------------------------------------
	local -a target_candidates
	local b
	for b in "${all_branches[@]}"; do
		[ "$b" != "$source_branch" ] && target_candidates+=("$b")
	done

	shell::logger::info "Select TARGET branch (the branch to merge INTO):"
	local target_branch
	target_branch=$(shell::ask::option "${target_candidates[@]}")

	if [ -z "$target_branch" ]; then
		shell::logger::warn "No target branch selected — aborting"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 4 — Confirm.
	# ---------------------------------------------------------------------------
	shell::logger::info "Merge plan:"
	shell::logger::info "  Source : ${source_branch}"
	shell::logger::info "  Target : ${target_branch}"

	if shell::ask::deny "Proceed with merging '${source_branch}' into '${target_branch}'?"; then
		shell::logger::info "Merge aborted"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 5 — Delegate to shell::git::branch::merge.
	# ---------------------------------------------------------------------------
	if [ "$dry_run" = "true" ]; then
		shell::git::branch::merge -n "${source_branch}" "${target_branch}"
	else
		shell::git::branch::merge "${source_branch}" "${target_branch}"
	fi
}

# @description Stashes all changes (tracked and untracked) in the current Git repository
#   with an optional message. Defaults to a timestamped message including the
#   current branch name.
#
#   Runs: git stash save --include-untracked "<message>"
#   The default message format follows the convention: "WIP on <branch>: <date>"
#   This ensures stashes are traceable to their branch of origin.
# @option -n | --dry-run Optional. Print the git stash command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @arg $1 string message: Optional. Custom stash message. Defaults to current date.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::branch::stash
#   shell::git::branch::stash "Work in progress on feature"
#   shell::git::branch::stash -n
#
shell::git::branch::stash() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Stash all changes including untracked files"
		shell::logger::usage "shell::git::branch::stash [-n] [-h] [<message>]"
		shell::logger::item "message" "Optional stash message. Defaults to current date"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::example "shell::git::branch::stash"
		shell::logger::example "shell::git::branch::stash \"WIP: refactoring auth module\""
		shell::logger::example "shell::git::branch::stash -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	local message="${1:-$(date +%Y-%m-%d)}"
	local stash_message="WIP on ${current_branch}: ${message}"

	local cmd_stash="git stash save --include-untracked \"${stash_message}\""

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_stash"
		return $RETURN_SUCCESS
	fi

	shell::logger::assert "$cmd_stash" \
		"All changes stashed on '${current_branch}': ${stash_message}" \
		"Stash failed" || return $?

	return $RETURN_SUCCESS
}

# @description Presents an fzf picker of stashes for the current branch, then removes the
#   selected stash after confirmation.
#
#   Step 1 — Verify the git repository and capture the current branch.
#   Step 2 — Build a list of stashes filtered to the current branch.
#   Step 3 — Present a single-select picker via shell::ask::option.
#   Step 4 — Extract the stash reference (stash@{N}) from the selection.
#   Step 5 — Confirm removal with the user.
#   Step 6 — Execute: git stash drop <stash_ref>
# @option -n | --dry-run Optional. Print the command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::branch::stash::remove::fzf
#   shell::git::branch::stash::remove::fzf -n
#
shell::git::branch::stash::remove::fzf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Select a stash via fzf and remove it"
		shell::logger::usage "shell::git::branch::stash::remove::fzf [-n] [-h]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::example "shell::git::branch::stash::remove::fzf"
		shell::logger::example "shell::git::branch::stash::remove::fzf -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# Step 1 — capture current branch for filtering.
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	# Step 2 — build stash list filtered to current branch.
	# Stash list format: stash@{N}: WIP on <branch>: <message>
	local -a stash_lines
	while IFS= read -r line; do
		[ -n "$line" ] && stash_lines+=("$line")
	done < <(git stash list 2>/dev/null | grep "WIP on ${current_branch}:")

	if [ "${#stash_lines[@]}" -eq 0 ]; then
		shell::logger::warn "No stashes found for branch '${current_branch}' — aborting"
		return $RETURN_SUCCESS
	fi

	shell::logger::info "Found ${#stash_lines[@]} stash(es) for branch '${current_branch}'"

	# Step 3 — present single-select picker.
	local selected_output
	selected_output=$(shell::ask::option "${stash_lines[@]}")

	if [ -z "$selected_output" ]; then
		shell::logger::warn "No stash selected — aborting"
		return $RETURN_SUCCESS
	fi

	# Step 4 — extract stash reference: stash@{N}
	local stash_ref
	stash_ref=$(printf '%s' "$selected_output" | grep -oE 'stash@\{[0-9]+\}')

	if [ -z "$stash_ref" ]; then
		shell::logger::warn "Could not extract stash reference from selection — aborting"
		return $RETURN_SUCCESS
	fi

	shell::logger::info "Selected: ${stash_ref}"

	# Step 5 — confirm removal.
	if shell::ask::deny "Remove ${stash_ref}?"; then
		shell::logger::info "Stash removal aborted"
		return $RETURN_SUCCESS
	fi

	# Step 6 — execute removal.
	local cmd_drop="git stash drop \"${stash_ref}\""

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_drop"
		return $RETURN_SUCCESS
	fi

	shell::logger::assert "$cmd_drop" \
		"${stash_ref} removed successfully" \
		"Failed to remove ${stash_ref}" || return $?

	return $RETURN_SUCCESS
}

# @description Presents an fzf picker of stashes for the current branch for browsing only.
#   No stash is modified — this is a read-only viewer.
#
#   Step 1 — Verify the git repository and capture the current branch.
#   Step 2 — Build a list of stashes filtered to the current branch.
#   Step 3 — Present a single-select picker via shell::ask::option.
#   Step 4 — Show the diff of the selected stash via git stash show -p.
#   Step 5 — Copy the stash reference to clipboard for convenience.
# @option -n | --dry-run Optional. Print the git stash list command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::branch::stash::preview::fzf
#   shell::git::branch::stash::preview::fzf -n
#
shell::git::branch::stash::preview::fzf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Browse stashes via fzf and view their contents"
		shell::logger::usage "shell::git::branch::stash::preview::fzf [-n] [-h]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the git stash list command instead of executing it"
		shell::logger::example "shell::git::branch::stash::preview::fzf"
		shell::logger::example "shell::git::branch::stash::preview::fzf -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# Step 1 — capture current branch for filtering.
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	# Step 2 — build stash list filtered to current branch.
	local -a stash_lines
	while IFS= read -r line; do
		[ -n "$line" ] && stash_lines+=("$line")
	done < <(git stash list 2>/dev/null | grep "WIP on ${current_branch}:")

	if [ "${#stash_lines[@]}" -eq 0 ]; then
		shell::logger::warn "No stashes found for branch '${current_branch}' — aborting"
		return $RETURN_SUCCESS
	fi

	shell::logger::info "Found ${#stash_lines[@]} stash(es) for branch '${current_branch}'"

	# Step 3 — present single-select picker.
	local selected_output
	selected_output=$(shell::ask::option "${stash_lines[@]}")

	if [ -z "$selected_output" ]; then
		shell::logger::warn "No stash selected — aborting"
		return $RETURN_SUCCESS
	fi

	# Step 4 — extract stash reference and show its diff.
	local stash_ref
	stash_ref=$(printf '%s' "$selected_output" | grep -oE 'stash@\{[0-9]+\}')

	if [ -z "$stash_ref" ]; then
		shell::logger::warn "Could not extract stash reference from selection — aborting"
		return $RETURN_SUCCESS
	fi

	shell::logger::info "Selected: ${stash_ref}"

	local cmd_show="git stash show -p \"${stash_ref}\""

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_show"
		return $RETURN_SUCCESS
	fi

	# Display the stash diff.
	shell::logger::info "Showing diff for ${stash_ref}:"
	if shell::command::exists delta; then
		eval "$cmd_show" 2>/dev/null | delta --no-gitconfig --line-numbers --navigate --dark 2>/dev/null ||
			eval "$cmd_show"
	else
		eval "$cmd_show"
	fi

	# Step 5 — copy stash reference to clipboard.
	shell::clipboard::copy --best-effort "${stash_ref}"
	shell::logger::info "Stash reference copied to clipboard: ${stash_ref}"

	return $RETURN_SUCCESS
}

# @description Presents an fzf multi-select picker of stashes for the current branch,
#   then applies each selected stash in order. Continues on individual failures.
#
#   Step 1 — Verify the git repository and capture the current branch.
#   Step 2 — Build a list of stashes filtered to the current branch.
#   Step 3 — Present a multi-select picker via shell::ask::options.
#   Step 4 — Extract stash references (stash@{N}) from the selection.
#   Step 5 — Apply each selected stash in order, continuing on failure.
#   Step 6 — Summarize success/failure counts.
# @option -n | --dry-run Optional. Print the commands via shell::logger::command_clip instead of executing them.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::branch::stash::apply::fzf
#   shell::git::branch::stash::apply::fzf -n
#
shell::git::branch::stash::apply::fzf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Multi-select stashes via fzf and apply them to the current branch"
		shell::logger::usage "shell::git::branch::stash::apply::fzf [-n] [-h]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::example "shell::git::branch::stash::apply::fzf"
		shell::logger::example "shell::git::branch::stash::apply::fzf -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# Step 1 — capture current branch for filtering.
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	# Step 2 — build stash list filtered to current branch.
	local -a stash_lines
	while IFS= read -r line; do
		[ -n "$line" ] && stash_lines+=("$line")
	done < <(git stash list 2>/dev/null | grep "WIP on ${current_branch}:")

	if [ "${#stash_lines[@]}" -eq 0 ]; then
		shell::logger::warn "No stashes found for branch '${current_branch}' — aborting"
		return $RETURN_SUCCESS
	fi

	shell::logger::info "Found ${#stash_lines[@]} stash(es) for branch '${current_branch}'"

	# Step 3 — present multi-select picker.
	local selected_output
	selected_output=$(shell::ask::options "${stash_lines[@]}")

	if [ -z "$selected_output" ]; then
		shell::logger::warn "No stashes selected — aborting"
		return $RETURN_SUCCESS
	fi

	# Step 4 — extract stash references.
	local -a stash_refs
	while IFS= read -r ref; do
		[ -n "$ref" ] && stash_refs+=("$ref")
	done < <(printf '%s' "$selected_output" | grep -oE 'stash@\{[0-9]+\}')

	if [ "${#stash_refs[@]}" -eq 0 ]; then
		shell::logger::warn "Could not extract stash references from selection — aborting"
		return $RETURN_SUCCESS
	fi

	shell::logger::info "Selected ${#stash_refs[@]} stash(es) to apply"

	# Step 5 — apply each stash, continuing on failure.
	local success_count=0
	local failure_count=0
	local ref
	local cmd_apply

	for ref in "${stash_refs[@]}"; do
		cmd_apply="git stash apply \"${ref}\""

		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "$cmd_apply"
			continue
		fi

		if shell::logger::assert "$cmd_apply" \
			"Applied ${ref} successfully" \
			"Failed to apply ${ref} — continuing with remaining stashes"; then
			success_count=$((success_count + 1))
		else
			failure_count=$((failure_count + 1))
		fi
	done

	# Step 6 — summarize results.
	if [ "$dry_run" = "false" ]; then
		shell::logger::info "Apply complete: ${success_count} succeeded, ${failure_count} failed"
		if [ "${failure_count}" -gt 0 ]; then
			shell::logger::warn "Resolve conflicts for failed applies, then run 'git stash drop <ref>' manually"
		fi
	fi

	return $RETURN_SUCCESS
}

# @internal
# @description Quote one argument so a printed command can be pasted back into a shell.
#   Safe words are left as they are; anything else is wrapped in single quotes
#   (an embedded `'` becomes `'\''`). Used for display only: the command itself
#   is never built as a string.
# @arg $1 string The argument.
# @stdout The quoted argument.
# @exitcode 0 Always.
# @example
#   shell::git::commit::spec::quote "John Doe"   # 'John Doe'
#
shell::git::commit::spec::quote() {
	local value="${1-}"

	case "$value" in
	'') printf "''" ;;
	*[!A-Za-z0-9_./:=@%+,-]*) printf "'%s'" "$(printf '%s' "$value" | sed "s/'/'\\\\''/g")" ;;
	*) printf '%s' "$value" ;;
	esac
}

# @description Displays a decorated commit graph for a specific branch.
#
#   Runs git log with a coloured, decorated graph format scoped to the given
#   branch. Format: full hash (short hash) — relative time  author  refs  subject.
#   With no options the commits listed are exactly what they always were (each
#   one now ends with a newline, so the status line is no longer glued to the
#   last commit); the options below narrow or reshape it. They can come before
#   or after the branch, and paths go after `--`, for example
#   `shell::git::commit::spec main -c 10 --author Alice --no-merges -- src docs`.
#
#   git is run directly (never through `eval`), so a branch name, an author or a
#   pattern containing quotes, `$(...)` or other shell syntax is passed to git as
#   plain text. `-n` is the dry-run flag of this library, so the number of commits
#   is `-c` (git's own `-n`).
# @option -n | --dry-run Optional. Print the command via shell::logger::command_clip instead of executing it.
# @option -c | --count Optional. Show only the N most recent commits (a positive integer).
# @option -s | --since Optional. Only commits after this date ("2024-01-01", "2 weeks ago").
# @option -u | --until Optional. Only commits before this date.
# @option -a | --author Optional. Only commits whose author matches this pattern.
# @option -g | --grep Optional. Only commits whose message matches this pattern.
# @option --no-merges Optional. Hide merge commits.
# @option --first-parent Optional. Follow only the first parent of merges (the branch's own history).
# @option --no-graph Optional. Plain list instead of the ASCII graph.
# @option --oneline Optional. Compact format: short hash and relative time only.
# @option --reverse Optional. Oldest first (needs --no-graph).
# @option --stat Optional. Show the files changed by each commit.
# @option -h | --help Show this help message.
# @arg $1 string branch: The branch whose commit history to display.
# @arg $2 string -- paths: After `--`, limit the history to commits that touch these paths.
# @exitcode 0 Success.
# @exitcode 1 git log failed (for example an unknown branch).
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::commit::spec "main"
#   shell::git::commit::spec -n "feature/my-branch"
#   shell::git::commit::spec main -c 10
#   shell::git::commit::spec main --author Alice --since "2 weeks ago" --no-merges
#   shell::git::commit::spec main --grep fix -- src/
#
shell::git::commit::spec() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show decorated commit graph history for a specific branch"
		shell::logger::usage "shell::git::commit::spec [-n] [options] <branch> [-- <path>...]"
		shell::logger::item "branch" "Branch whose commit history to display"
		shell::logger::item "path" "After --, only commits that touch these paths"
		shell::logger::option "-c, --count <N>" "Show only the N most recent commits"
		shell::logger::option "-s, --since <date>" "Only commits after this date (e.g. \"2 weeks ago\")"
		shell::logger::option "-u, --until <date>" "Only commits before this date"
		shell::logger::option "-a, --author <pattern>" "Only commits by an author matching the pattern"
		shell::logger::option "-g, --grep <pattern>" "Only commits whose message matches the pattern"
		shell::logger::option "--no-merges" "Hide merge commits"
		shell::logger::option "--first-parent" "Follow only the first parent of merges"
		shell::logger::option "--no-graph" "Plain list instead of the graph"
		shell::logger::option "--oneline" "Compact format (short hash, relative time)"
		shell::logger::option "--reverse" "Oldest first (needs --no-graph)"
		shell::logger::option "--stat" "Show the files changed by each commit"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::note "-n is the dry-run flag; the number of commits is -c."
		shell::logger::example "shell::git::commit::spec \"main\""
		shell::logger::example "shell::git::commit::spec -n \"feature/my-branch\""
		shell::logger::example "shell::git::commit::spec main -c 10"
		shell::logger::example "shell::git::commit::spec main --author Alice --since \"2 weeks ago\" --no-merges"
		shell::logger::example "shell::git::commit::spec main --grep fix -- src/"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" end_opts="false" branch="" have_branch="false"
	local count="" since_date="" until_date="" author="" grep_pattern=""
	local graph="true" compact="false" no_merges="false" first_parent="false" reverse="false" stat="false"
	local opt val rc
	local -a paths=()

	while [ "$#" -gt 0 ]; do
		if [ "$end_opts" = "true" ]; then
			paths+=("$1")
			shift
			continue
		fi
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		--no-merges)
			no_merges="true"
			shift
			;;
		--first-parent)
			first_parent="true"
			shift
			;;
		--no-graph)
			graph="false"
			shift
			;;
		--oneline)
			compact="true"
			shift
			;;
		--reverse)
			reverse="true"
			shift
			;;
		--stat)
			stat="true"
			shift
			;;
		-h | --help)
			shell::git::commit::spec --help
			return "$RETURN_SUCCESS"
			;;
		--)
			end_opts="true"
			shift
			;;
		-c | --count | -s | --since | -u | --until | -a | --author | -g | --grep | --count=* | --since=* | --until=* | --author=* | --grep=*)
			opt="$1"
			case "$opt" in
			--*=*)
				val="${opt#*=}"
				opt="${opt%%=*}"
				shift
				;;
			*)
				if [ "$#" -lt 2 ]; then
					shell::logger::error "Option $opt requires a value"
					return "$RETURN_INVALID"
				fi
				val="$2"
				shift 2
				;;
			esac
			case "$opt" in
			-c | --count)
				case "$val" in
				'' | *[!0-9]* | 0*)
					shell::logger::error "--count must be a positive whole number (got '$val')"
					return "$RETURN_INVALID"
					;;
				esac
				count="$val"
				;;
			*)
				if [ -z "$val" ]; then
					shell::logger::error "Option $opt requires a non-empty value"
					return "$RETURN_INVALID"
				fi
				case "$opt" in
				-s | --since) since_date="$val" ;;
				-u | --until) until_date="$val" ;;
				-a | --author) author="$val" ;;
				-g | --grep) grep_pattern="$val" ;;
				esac
				;;
			esac
			;;
		-*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*)
			if [ "$have_branch" = "true" ]; then
				shell::logger::error "Unexpected argument '$1' (the branch is '$branch'; put paths after --)"
				return "$RETURN_INVALID"
			fi
			branch="$1"
			have_branch="true"
			shift
			;;
		esac
	done

	if [ "$have_branch" = "false" ] || [ -z "$branch" ]; then
		shell::logger::error "Branch name is required"
		return "$RETURN_INVALID"
	fi
	if [ "$reverse" = "true" ] && [ "$graph" = "true" ]; then
		shell::logger::error "--reverse cannot be combined with the graph; add --no-graph"
		return "$RETURN_INVALID"
	fi

	# ---------------------------------------------------------------------------
	# Log format — coloured graph: hash, relative time, absolute time, author, refs, subject.
	# ---------------------------------------------------------------------------
	local log_format="%C(bold blue)%H (%h)%C(reset) - %C(bold green)(%ar at %ad)%C(reset) %C(white)%an%C(reset)%C(bold yellow)%d%C(reset) %C(dim white)- %s%C(reset)"
	if [ "$compact" = "true" ]; then
		log_format="%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%an%C(reset)%C(bold yellow)%d%C(reset) %C(dim white)- %s%C(reset)"
	fi

	# The command is an argument list, never a string: every value reaches git as
	# one word, whatever characters it contains.
	local -a log_args=(log)
	if [ "$graph" = "true" ]; then
		log_args+=(--graph)
	fi
	log_args+=(--decorate "--date=format:%Y-%m-%d %H:%M:%S")
	if [ -n "$count" ]; then log_args+=("--max-count=$count"); fi
	if [ -n "$since_date" ]; then log_args+=("--since=$since_date"); fi
	if [ -n "$until_date" ]; then log_args+=("--until=$until_date"); fi
	if [ -n "$author" ]; then log_args+=("--author=$author"); fi
	if [ -n "$grep_pattern" ]; then log_args+=("--grep=$grep_pattern"); fi
	if [ "$no_merges" = "true" ]; then log_args+=(--no-merges); fi
	if [ "$first_parent" = "true" ]; then log_args+=(--first-parent); fi
	if [ "$reverse" = "true" ]; then log_args+=(--reverse); fi
	if [ "$stat" = "true" ]; then log_args+=(--stat); fi
	log_args+=("--format=tformat:${log_format}" "$branch" --)
	if [ "${#paths[@]}" -gt 0 ]; then
		log_args+=("${paths[@]}")
	fi

	# What is shown (and copied) is a quoted, pasteable rendering of that list.
	local display="git" arg
	for arg in "${log_args[@]}"; do
		display="${display} $(shell::git::commit::spec::quote "$arg")"
	done

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$display"
		return "$RETURN_SUCCESS"
	fi

	shell::logger::command "$display"
	git "${log_args[@]}"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		shell::logger::error "Git log aborted (exit code: ${rc})"
		return "$rc"
	fi
	shell::logger::success "Commit history for branch '${branch}' displayed"
	return "$RETURN_SUCCESS"
}

# @description Displays a decorated commit graph for the currently active branch.
#
#   Detects the currently active branch and forwards it to shell::git::commit::spec
#   to display its commit graph, together with every option you pass, so all the
#   filters of shell::git::commit::spec work here too (the branch is added for
#   you; paths go after `--`). In a detached HEAD the history of HEAD is shown.
#   If not inside a Git repository, an error is logged and the function returns
#   with failure.
# @option -n | --dry-run Optional. Print the command via shell::logger::command_clip instead of executing it.
# @option -c | --count Optional. Show only the N most recent commits.
# @option -s | --since Optional. Only commits after this date.
# @option -u | --until Optional. Only commits before this date.
# @option -a | --author Optional. Only commits whose author matches this pattern.
# @option -g | --grep Optional. Only commits whose message matches this pattern.
# @option --no-merges Optional. Hide merge commits.
# @option --first-parent Optional. Follow only the first parent of merges.
# @option --no-graph Optional. Plain list instead of the ASCII graph.
# @option --oneline Optional. Compact format.
# @option --reverse Optional. Oldest first (needs --no-graph).
# @option --stat Optional. Show the files changed by each commit.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed (not inside a Git repository, or git log failed).
# @exitcode 2 Invalid arguments.
# @example
#   shell::git::commit::spec::current
#   shell::git::commit::spec::current -n
#   shell::git::commit::spec::current -c 10
#   shell::git::commit::spec::current --author Alice --since "1 month ago" -- src/
#
shell::git::commit::spec::current() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show the decorated commit graph of the current branch"
		shell::logger::usage "shell::git::commit::spec::current [-n] [options] [-- <path>...]"
		shell::logger::item "path" "After --, only commits that touch these paths"
		shell::logger::option "-c, --count <N>" "Show only the N most recent commits"
		shell::logger::option "-s, --since <date>" "Only commits after this date (e.g. \"2 weeks ago\")"
		shell::logger::option "-u, --until <date>" "Only commits before this date"
		shell::logger::option "-a, --author <pattern>" "Only commits by an author matching the pattern"
		shell::logger::option "-g, --grep <pattern>" "Only commits whose message matches the pattern"
		shell::logger::option "--no-merges" "Hide merge commits"
		shell::logger::option "--first-parent" "Follow only the first parent of merges"
		shell::logger::option "--no-graph" "Plain list instead of the graph"
		shell::logger::option "--oneline" "Compact format (short hash, relative time)"
		shell::logger::option "--reverse" "Oldest first (needs --no-graph)"
		shell::logger::option "--stat" "Show the files changed by each commit"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::note "-n is the dry-run flag; the number of commits is -c."
		shell::logger::example "shell::git::commit::spec::current"
		shell::logger::example "shell::git::commit::spec::current -c 10"
		shell::logger::example "shell::git::commit::spec::current --author Alice --since \"1 month ago\" -- src/"
		return "$RETURN_SUCCESS"
	fi

	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
	if [ -z "$current_branch" ]; then
		shell::logger::error "Not inside a Git repository"
		return "$RETURN_FAILURE"
	fi

	# The branch goes first; every option the user gave follows it.
	shell::git::commit::spec "$current_branch" "$@"
}

# @description Displays a decorated commit graph across all refs in the current repository.
#
#   Runs git log --all with a coloured, decorated graph format, covering all
#   local branches, remote-tracking branches, and tags in the repository.
# @option -n | --dry-run Optional. Print the command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @example
#   shell::git::commit::all
#   shell::git::commit::all -n
#
shell::git::commit::all() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show decorated commit graph history across all refs in the repository"
		shell::logger::usage "shell::git::commit::all [-n] [-h]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::example "shell::git::commit::all"
		shell::logger::example "shell::git::commit::all -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	# ---------------------------------------------------------------------------
	# Log format — coloured graph: hash, relative time, absolute time, author, refs, subject.
	# ---------------------------------------------------------------------------
	local log_format="%C(bold blue)%H (%h)%C(reset) - %C(bold green)(%ar at %ad)%C(reset) %C(white)%an%C(reset)%C(bold yellow)%d%C(reset) %C(dim white)- %s%C(reset)"
	local cmd_log="git log --graph --decorate --all --date=format:'%Y-%m-%d %H:%M:%S' --format=format:\"${log_format}\""

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_log"
		return $RETURN_SUCCESS
	fi

	shell::logger::assert "$cmd_log" \
		"Full repository commit history displayed" "Git log aborted" || return $?

	return $RETURN_SUCCESS
}

# @description Interactively selects a branch via fzf, then displays its commit history.
#
#   Collects all local and remote branches from the current repository,
#   deduplicates them, and presents them in an fzf picker. The selected branch
#   is forwarded to shell::git::commit::spec to display its commit graph.
# @option -n | --dry-run Optional. After branch selection, print the git log command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::commit::spec::fzf
#   shell::git::commit::spec::fzf -n
#
shell::git::commit::spec::fzf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Select a branch via fzf and display its commit history"
		shell::logger::usage "shell::git::commit::spec::fzf [-n] [-h]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the git log command instead of executing it"
		shell::logger::example "shell::git::commit::spec::fzf"
		shell::logger::example "shell::git::commit::spec::fzf -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# Collect all local and remote branch names, strip prefixes, deduplicate.
	local -a branch_list
	while IFS= read -r _b; do
		branch_list+=("$_b")
	done < <(
		{
			git branch | sed 's|^[* ]*||'
			git branch -r | grep 'origin/' | grep -v 'HEAD' | sed 's|^[[:space:]]*origin/||'
		} | sort -u
	)

	if [ "${#branch_list[@]}" -eq 0 ]; then
		shell::logger::warn "No branches found — aborting"
		return $RETURN_FAILURE
	fi

	local selected_branch
	selected_branch=$(shell::ask::option "${branch_list[@]}")

	if [ -z "$selected_branch" ]; then
		shell::logger::warn "No branch selected — aborting"
		return $RETURN_FAILURE
	fi

	if [ "$dry_run" = "true" ]; then
		shell::git::commit::spec -n "$selected_branch"
	else
		shell::git::commit::spec "$selected_branch"
	fi
}

# @description Presents a multi-select picker of all commits on a given branch, then prints
#   each selected commit's info to the console and copies it to the clipboard.
#
#   Builds a coloured commit list via git log for the specified branch, then
#   delegates to shell::ask::options (TAB to select multiple entries).
#   For each selected commit, logs the message via shell::logger::info and copies
#   it to the clipboard via shell::clipboard::copy.
#
#   Hash extraction is ANSI-safe: uses grep -oE to locate every 40-char hex hash
#   in the multiselect output — no sed ANSI stripping required.
# @option -h | --help Show this help message.
# @arg $1 string branch: Required. Branch name whose commits to browse and select from.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::commit::spec::search "main"
#   shell::git::commit::spec::search "feature/my-branch"
#
shell::git::commit::spec::search() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Multi-select commits on a branch via fzf and copy their info to the clipboard"
		shell::logger::usage "shell::git::commit::spec::search [-h] <branch>"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::item "branch" "Branch name whose commits to browse and select from"
		shell::logger::example "shell::git::commit::spec::search \"main\""
		shell::logger::example "shell::git::commit::spec::search \"feature/my-branch\""
		return $RETURN_SUCCESS
	fi

	local branch="$1"

	if [ -z "$branch" ]; then
		shell::logger::error "Branch name is required"
		return $RETURN_INVALID
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	local repository
	repository=$(git rev-parse --show-toplevel 2>/dev/null)

	# ---------------------------------------------------------------------------
	# Log format — coloured: full hash, short hash, relative time, absolute time, author, refs, subject.
	# Matches the format used by shell::git::commit::spec and shell::git::commit::all.
	# ---------------------------------------------------------------------------
	local log_format="%C(bold blue)%H (%h)%C(reset) - %C(bold green)(%ar at %ad)%C(reset) %C(white)%an%C(reset)%C(bold yellow)%d%C(reset) %C(dim white)- %s%C(reset)"

	# Build per-line array — one element per commit — for shell::ask::options.
	local -a commit_lines
	while IFS= read -r line; do
		commit_lines+=("$line")
	done < <(git log --format=format:"${log_format}" --date=format:'%Y-%m-%d %H:%M:%S' --color=always "${branch}" 2>/dev/null)

	if [ "${#commit_lines[@]}" -eq 0 ]; then
		shell::logger::warn "No commits found on branch '${branch}' — aborting"
		return $RETURN_SUCCESS
	fi

	# Present multi-select picker via codebase helper (TAB to select multiple).
	local selected_output
	selected_output=$(shell::ask::options "${commit_lines[@]}")

	if [ -z "$selected_output" ]; then
		shell::logger::warn "No commits selected — aborting"
		return $RETURN_SUCCESS
	fi

	# Extract every 40-char hex hash from the (ANSI-coded, space-joined) output.
	# grep -oE is robust against ANSI escape sequences and works on GNU + BSD grep.
	local commit_hash
	local commit_subject
	local notify_message

	while IFS= read -r commit_hash; do
		# Retrieve the clean subject from git to avoid parsing ANSI-coded output.
		commit_subject=$(git log -1 --format='%s' "$commit_hash" 2>/dev/null)
		notify_message="Hash: ${commit_hash} | Subject: ${commit_subject} | Repository: ${repository}"
		shell::logger::info "${notify_message}"
		shell::clipboard::copy --best-effort "${notify_message}"
	done < <(printf '%s' "$selected_output" | grep -oE '[0-9a-f]{40}')

	return $RETURN_SUCCESS
}

# @description Presents a multi-select picker of all commits on the currently active branch,
#   then prints each selected commit's info to the console and copies it to the clipboard.
#
#   Detects the currently active branch and forwards it to shell::git::commit::spec::search
#   to present the commit multi-select for that branch. If not inside a Git repository, an error is logged and the function returns with failure.
# @option -h | --help Show this help message.
# @exitcode 1 The operation failed.
# @example
#   shell::git::commit::spec::search::current
#
shell::git::commit::spec::search::current() {
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
	if [ -z "$current_branch" ]; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi
	shell::git::commit::spec::search "$current_branch"
}

# @description Presents a multi-select picker of all commits across all refs in the repository,
#   then prints each selected commit's info to the console and copies it to the clipboard.
#
#   Builds a coloured commit list via git log --all covering all local branches,
#   remote-tracking branches, and tags, then delegates to
#   shell::ask::options (TAB to select multiple entries).
#   For each selected commit, logs the message via shell::logger::info and copies
#   it to the clipboard via shell::clipboard::copy.
#
#   Hash extraction is ANSI-safe: uses grep -oE to locate every 40-char hex hash
#   in the multiselect output — no sed ANSI stripping required.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::commit::all::search
#
shell::git::commit::all::search() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Multi-select commits across all refs via fzf and copy their info to the clipboard"
		shell::logger::usage "shell::git::commit::all::search [-h]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::example "shell::git::commit::all::search"
		return $RETURN_SUCCESS
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	local repository
	repository=$(git rev-parse --show-toplevel 2>/dev/null)

	# ---------------------------------------------------------------------------
	# Log format — coloured: full hash, short hash, relative time, author, refs, subject.
	# Matches the format used by shell::git::commit::all and shell::git::commit::spec.
	# ---------------------------------------------------------------------------
	local log_format="%C(bold blue)%H (%h)%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%an%C(reset)%C(bold yellow)%d%C(reset) %C(dim white)- %s%C(reset)"

	# Build per-line array — one element per commit — for shell::ask::options.
	local -a commit_lines
	while IFS= read -r line; do
		commit_lines+=("$line")
	done < <(git log --format=format:"${log_format}" --all --color=always 2>/dev/null)

	if [ "${#commit_lines[@]}" -eq 0 ]; then
		shell::logger::warn "No commits found in repository — aborting"
		return $RETURN_SUCCESS
	fi

	# Present multi-select picker via codebase helper (TAB to select multiple).
	local selected_output
	selected_output=$(shell::ask::options "${commit_lines[@]}")

	if [ -z "$selected_output" ]; then
		shell::logger::warn "No commits selected — aborting"
		return $RETURN_SUCCESS
	fi

	# Extract every 40-char hex hash from the (ANSI-coded, space-joined) output.
	# grep -oE is robust against ANSI escape sequences and works on GNU + BSD grep.
	local commit_hash
	local commit_subject
	local notify_message

	while IFS= read -r commit_hash; do
		# Retrieve the clean subject from git to avoid parsing ANSI-coded output.
		commit_subject=$(git log -1 --format='%s' "$commit_hash" 2>/dev/null)
		notify_message="Hash: ${commit_hash} | Subject: ${commit_subject} | Repository: ${repository}"
		shell::logger::info "${notify_message}"
		shell::clipboard::copy --best-effort "${notify_message}"
	done < <(printf '%s' "$selected_output" | grep -oE '[0-9a-f]{40}')

	return $RETURN_SUCCESS
}

# @description Multi-selects commits from a source branch (or across all refs) via fzf, then
#   cherry-picks the selected commits onto the current branch in chronological order.
#
#   Step 1 — Verify the git repository and capture the current (target) branch.
#   Step 2 — Build a coloured commit list:
#   • With <source_branch>: git log <source_branch>
#   • Without            : git log --all
#   Step 3 — Present a multi-select picker (TAB to select multiple commits).
#   Step 4 — Extract 40-char hex hashes from the selection in git-log order
#   (newest first), then reverse them to chronological order
#   (oldest first) — the required replay order for cherry-pick.
#   Step 5 — Display the ordered cherry-pick plan and confirm with the user.
#   Step 6 — Execute: git cherry-pick <hash1> <hash2> ...
#   On conflict, git stops automatically; the user must resolve it
#   manually and run 'git cherry-pick --continue', or abort with
#   'git cherry-pick --abort'.
# @option -n | --dry-run Optional. Print the cherry-pick command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @arg $1 string source_branch: Optional. Branch whose commits to browse and pick from. When omitted, commits from ALL refs are shown (--all).
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::commit::pick::local
#   shell::git::commit::pick::local "feature/my-branch"
#   shell::git::commit::pick::local -n "main"
#
shell::git::commit::pick::local() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Multi-select commits from a branch (or all refs) and cherry-pick them onto the current branch"
		shell::logger::usage "shell::git::commit::pick::local [-n] [-h] [<source_branch>]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the cherry-pick command instead of executing it"
		shell::logger::item "source_branch" "Branch whose commits to browse; omit to browse all refs"
		shell::logger::example "shell::git::commit::pick::local"
		shell::logger::example "shell::git::commit::pick::local \"feature/my-branch\""
		shell::logger::example "shell::git::commit::pick::local -n \"main\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# Step 1 — capture the current (target) branch that will receive the commits.
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	local source_branch="$1"

	# ---------------------------------------------------------------------------
	# Log format — coloured: full hash, short hash, relative time, author, refs, subject.
	# Matches the format used by all other shell::git::commit::* functions.
	# ---------------------------------------------------------------------------
	local log_format="%C(bold blue)%H (%h)%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%an%C(reset)%C(bold yellow)%d%C(reset) %C(dim white)- %s%C(reset)"

	# Step 2 — build commit list; scope to source_branch when provided.
	local -a commit_lines

	if [ -n "$source_branch" ]; then
		shell::logger::info "Browsing commits on branch '${source_branch}' → cherry-pick target: '${current_branch}'"
		while IFS= read -r line; do
			commit_lines+=("$line")
		done < <(git log --format=format:"${log_format}" --color=always "${source_branch}" 2>/dev/null)

		if [ "${#commit_lines[@]}" -eq 0 ]; then
			shell::logger::warn "No commits found on branch '${source_branch}' — aborting"
			return $RETURN_SUCCESS
		fi
	else
		shell::logger::info "Browsing commits across all refs → cherry-pick target: '${current_branch}'"
		while IFS= read -r line; do
			commit_lines+=("$line")
		done < <(git log --format=format:"${log_format}" --all --color=always 2>/dev/null)

		if [ "${#commit_lines[@]}" -eq 0 ]; then
			shell::logger::warn "No commits found in repository — aborting"
			return $RETURN_SUCCESS
		fi
	fi

	# Step 3 — present multi-select picker (TAB to mark commits).
	local selected_output
	selected_output=$(shell::ask::options "${commit_lines[@]}")

	if [ -z "$selected_output" ]; then
		shell::logger::warn "No commits selected — aborting"
		return $RETURN_SUCCESS
	fi

	# Step 4 — extract hashes (newest-first per git log) then reverse to oldest-first.
	# cherry-pick must replay commits in chronological order so each commit builds
	# on top of the previous one without unnecessary conflicts.
	local -a hashes_newest_first
	while IFS= read -r h; do
		hashes_newest_first+=("$h")
	done < <(printf '%s' "$selected_output" | grep -oE '[0-9a-f]{40}')

	if [ "${#hashes_newest_first[@]}" -eq 0 ]; then
		shell::logger::warn "No valid commit hashes extracted — aborting"
		return $RETURN_SUCCESS
	fi

	# Reverse array: prepend each element so the last becomes the first.
	# Prepend-based reversal is index-free and works in both bash (0-based arrays)
	# and zsh (1-based arrays), avoiding the off-by-one that a C-style index loop
	# (i = count-1 down to 0) produces in zsh where index 0 returns empty string.
	local -a hashes_oldest_first
	local _h
	for _h in "${hashes_newest_first[@]}"; do
		hashes_oldest_first=("$_h" "${hashes_oldest_first[@]}")
	done

	# Step 5 — display cherry-pick plan and confirm.
	shell::logger::info "Cherry-pick target branch: ${current_branch}"
	shell::logger::info "Commits to apply (oldest → newest):"
	local h
	local subj
	for h in "${hashes_oldest_first[@]}"; do
		subj=$(git log -1 --format='%s' "$h" 2>/dev/null)
		shell::logger::info "  ${h:0:8}  ${subj}"
	done

	# Build the command string (hashes space-joined for display / dry-run).
	local cmd_cherry_pick="git cherry-pick ${hashes_oldest_first[*]}"

	if shell::ask::deny "Cherry-pick ${#hashes_oldest_first[@]} commit(s) onto '${current_branch}'?"; then
		shell::logger::info "Cherry-pick aborted"
		return $RETURN_SUCCESS
	fi

	# Step 6 — execute.
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_cherry_pick"
		return $RETURN_SUCCESS
	fi

	shell::logger::assert "$cmd_cherry_pick" \
		"${#hashes_oldest_first[@]} commit(s) cherry-picked onto '${current_branch}'" \
		"Cherry-pick failed — resolve conflicts then run 'git cherry-pick --continue', or abort with 'git cherry-pick --abort'" || return $?

	return $RETURN_SUCCESS
}

# @description Multi-selects commits from a source branch (or across all refs) via fzf,
#   cherry-picks them onto the current branch in chronological order, then
#   pushes the current branch to the remote via an interactive push strategy picker.
#
#   Identical to shell::git::commit::pick::local with one additional step:
#   Step 7 — After a successful cherry-pick, delegates to shell::git::branch::push
#   to present an interactive fzf push strategy picker and push the
#   current branch to origin.
#
#   Step 1 — Verify the git repository and capture the current (target) branch.
#   Step 2 — Build a coloured commit list:
#   • With <source_branch>: git log <source_branch>
#   • Without            : git log --all
#   Step 3 — Present a multi-select picker (TAB to select multiple commits).
#   Step 4 — Extract 40-char hex hashes, reverse to chronological order
#   (oldest first) — the required replay order for cherry-pick.
#   Step 5 — Display the ordered cherry-pick plan and confirm with the user.
#   Step 6 — Execute: git cherry-pick <hash1> <hash2> ...
#   Step 7 — Push the current branch via shell::git::branch::push (interactive).
# @option -n | --dry-run Optional. Print the cherry-pick and push commands via shell::logger::command_clip instead of executing them.
# @option -h | --help Show this help message.
# @arg $1 string source_branch: Optional. Branch whose commits to browse and pick from. When omitted, commits from ALL refs are shown (--all).
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::commit::pick::remote
#   shell::git::commit::pick::remote "feature/my-branch"
#   shell::git::commit::pick::remote -n "main"
#
shell::git::commit::pick::remote() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Multi-select commits, cherry-pick them onto the current branch, then push to remote"
		shell::logger::usage "shell::git::commit::pick::remote [-n] [-h] [<source_branch>]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the cherry-pick and push commands instead of executing them"
		shell::logger::item "source_branch" "Branch whose commits to browse; omit to browse all refs"
		shell::logger::example "shell::git::commit::pick::remote"
		shell::logger::example "shell::git::commit::pick::remote \"feature/my-branch\""
		shell::logger::example "shell::git::commit::pick::remote -n \"main\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# Step 1 — capture the current (target) branch that will receive the commits.
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	local source_branch="$1"

	# ---------------------------------------------------------------------------
	# Log format — coloured: full hash, short hash, relative time, author, refs, subject.
	# Matches the format used by all other shell::git::commit::* functions.
	# ---------------------------------------------------------------------------
	local log_format="%C(bold blue)%H (%h)%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%an%C(reset)%C(bold yellow)%d%C(reset) %C(dim white)- %s%C(reset)"

	# Step 2 — build commit list; scope to source_branch when provided.
	local -a commit_lines

	if [ -n "$source_branch" ]; then
		shell::logger::info "Browsing commits on branch '${source_branch}' → cherry-pick target: '${current_branch}'"
		while IFS= read -r line; do
			commit_lines+=("$line")
		done < <(git log --format=format:"${log_format}" --color=always "${source_branch}" 2>/dev/null)

		if [ "${#commit_lines[@]}" -eq 0 ]; then
			shell::logger::warn "No commits found on branch '${source_branch}' — aborting"
			return $RETURN_SUCCESS
		fi
	else
		shell::logger::info "Browsing commits across all refs → cherry-pick target: '${current_branch}'"
		while IFS= read -r line; do
			commit_lines+=("$line")
		done < <(git log --format=format:"${log_format}" --all --color=always 2>/dev/null)

		if [ "${#commit_lines[@]}" -eq 0 ]; then
			shell::logger::warn "No commits found in repository — aborting"
			return $RETURN_SUCCESS
		fi
	fi

	# Step 3 — present multi-select picker (TAB to mark commits).
	local selected_output
	selected_output=$(shell::ask::options "${commit_lines[@]}")

	if [ -z "$selected_output" ]; then
		shell::logger::warn "No commits selected — aborting"
		return $RETURN_SUCCESS
	fi

	# Step 4 — extract hashes (newest-first per git log) then reverse to oldest-first.
	# cherry-pick must replay commits in chronological order so each commit builds
	# on top of the previous one without unnecessary conflicts.
	local -a hashes_newest_first
	while IFS= read -r h; do
		hashes_newest_first+=("$h")
	done < <(printf '%s' "$selected_output" | grep -oE '[0-9a-f]{40}')

	if [ "${#hashes_newest_first[@]}" -eq 0 ]; then
		shell::logger::warn "No valid commit hashes extracted — aborting"
		return $RETURN_SUCCESS
	fi

	# Reverse array: prepend each element so the last becomes the first.
	# Prepend-based reversal is index-free and works in both bash (0-based arrays)
	# and zsh (1-based arrays), avoiding the off-by-one that a C-style index loop
	# (i = count-1 down to 0) produces in zsh where index 0 returns empty string.
	local -a hashes_oldest_first
	local _h
	for _h in "${hashes_newest_first[@]}"; do
		hashes_oldest_first=("$_h" "${hashes_oldest_first[@]}")
	done

	# Step 5 — display cherry-pick plan and confirm.
	shell::logger::info "Cherry-pick target branch: ${current_branch}"
	shell::logger::info "Commits to apply (oldest → newest):"
	local h
	local subj
	for h in "${hashes_oldest_first[@]}"; do
		subj=$(git log -1 --format='%s' "$h" 2>/dev/null)
		shell::logger::info "  ${h:0:8}  ${subj}"
	done

	# Build the command string (hashes space-joined for display / dry-run).
	local cmd_cherry_pick="git cherry-pick ${hashes_oldest_first[*]}"

	if shell::ask::deny "Cherry-pick ${#hashes_oldest_first[@]} commit(s) onto '${current_branch}' and push to remote?"; then
		shell::logger::info "Cherry-pick aborted"
		return $RETURN_SUCCESS
	fi

	# Step 6 — execute cherry-pick.
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_cherry_pick"
		# Show push dry-run without executing.
		shell::git::branch::push -n "${current_branch}"
		return $RETURN_SUCCESS
	fi

	shell::logger::assert "$cmd_cherry_pick" \
		"${#hashes_oldest_first[@]} commit(s) cherry-picked onto '${current_branch}'" \
		"Cherry-pick failed — resolve conflicts then run 'git cherry-pick --continue', or abort with 'git cherry-pick --abort'" || return $?

	# Step 7 — push current branch via interactive push strategy picker.
	shell::git::branch::push "${current_branch}"

	return $RETURN_SUCCESS
}

# @internal
# @description The one parser behind every commit message template function.
#   Reads the template files in a single `awk` pass: the installed copy
#   `SHELL_GIT_COMMIT_MESSAGES_FILE` (`~/.shell-config/git/git-commit-messages.txt`,
#   or, when it is not installed yet, the repository's own copy) and, after it,
#   the user's own `SHELL_GIT_COMMIT_MESSAGES_USER_FILE` when it exists. Keeping the parsing and
#   the rules in one place means the menu, the checker and the tests can never
#   disagree about what a valid template is.
#
#   File format (see the header of the data file): `[Category]` lines open a
#   category; every other non-blank, non-`#` line is `emoji|type(scope)!|description`.
#   A category that appears in both files is merged (built-in templates first),
#   a template that appears twice is kept once, and a record that breaks a rule
#   is skipped (reported when listing categories, so a typo in your own file
#   shows up once, not on every keystroke).
#
#   Modes:
#   - `records`: every valid record as `category|emoji|header|description`.
#   - `categories`: the category names, in first-seen order.
#   - `render <category> <plain>`: the messages of one category, ready to commit.
#   - `validate [--strict] [file...]`: check the given files (default: the template
#     files) and print `file:line: problem` on stderr and a summary on stdout.
#     Style recommendations are reported as warnings; `--strict` makes them problems.
#
#   The rules. Problems (checked by `validate`; the other modes skip such records):
#   conventional type, optional lower-case scope, optional `!`; emoji `:shortcode:`
#   or empty; description starts lower case or a digit, at least 12 characters, no
#   final period, no surrounding space, none of `"`, `$`, a backtick, `\` or `'`;
#   the header (with the emoji) at most 100 characters; no duplicates. A warning,
#   which never hides a template: `type(scope)!: description` over 72 characters,
#   the length git recommends.
# @arg $1 string Mode: records, categories, render or validate.
# @arg $@ string For `render`: the category and `true` to drop the emoji. For `validate`: files.
# @stdout Depends on the mode (see above).
# @stderr Problems found in the files.
# @exitcode 0 Success (validate: no problem).
# @exitcode 1 The template file is missing, or (validate) a problem was found.
# @example
#   shell::git::commit::message::scan render "Release and Versioning" false
#
shell::git::commit::message::scan() {
	local mode="${1-}"
	shift

	local category="" plain="false" warn="0" strict="0"
	local -a files=()
	case "$mode" in
	render)
		category="${1-}"
		plain="${2-false}"
		;;
	validate)
		if [ "${1-}" = "--strict" ]; then
			strict="1"
			shift
		fi
		files=("$@")
		;;
	categories) warn="1" ;;
	esac

	local main_file="$SHELL_GIT_COMMIT_MESSAGES_FILE"
	if [ "${#files[@]}" -eq 0 ]; then
		# Not installed yet (running from a clone, before install/upgrade): read the
		# copy in the repository. Only for the default location; a path you set
		# yourself is never silently replaced by another file.
		if [ ! -r "$main_file" ] && [ "$main_file" = "$SHELL_GIT_COMMIT_MESSAGES_INSTALLED" ] &&
			[ -r "$SHELL_GIT_COMMIT_MESSAGES_SOURCE" ]; then
			main_file="$SHELL_GIT_COMMIT_MESSAGES_SOURCE"
		fi
		if [ ! -r "$main_file" ]; then
			shell::logger::error "Commit message templates not found: ${main_file}"
			return "$RETURN_FAILURE"
		fi
		files+=("$main_file")
		if [ -r "$SHELL_GIT_COMMIT_MESSAGES_USER_FILE" ]; then
			files+=("$SHELL_GIT_COMMIT_MESSAGES_USER_FILE")
		fi
	fi

	local result problems
	result="$(awk -v mode="$mode" -v want="$category" -v plain="$plain" -v warn="$warn" -v strict="$strict" \
		-v builtin="$main_file" '
		BEGIN {
			FS = "|"
			HDR = "^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\\([a-z0-9][a-z0-9.-]*\\))?!?$"
			apos = sprintf("%c", 39)
		}

		# Report a problem with a record; the record is then skipped.
		function bad(msg) {
			problems++
			if (mode == "validate" || (warn == 1 && FILENAME != builtin)) {
				printf "%s:%d: %s\n", FILENAME, FNR, msg > "/dev/stderr"
			}
			ok = 0
		}

		# A style recommendation: the template is still loaded. With --strict it counts as a problem.
		function style(msg) {
			warnings++
			if (mode == "validate") {
				printf "%s:%d: warning: %s\n", FILENAME, FNR, msg > "/dev/stderr"
				if (strict == 1) problems++
			}
		}

		function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

		FNR == 1 { files++ }
		{ sub(/\r$/, "") }

		# Blank lines and comments.
		/^[ \t]*(#.*)?$/ { next }

		# A category header.
		/^\[.*\]$/ {
			cur = trim(substr($0, 2, length($0) - 2))
			if (cur == "") {
				problems++
				if (mode == "validate") printf "%s:%d: empty category name\n", FILENAME, FNR > "/dev/stderr"
				next
			}
			if (!(cur in seen)) { seen[cur] = ++ncat; cats[ncat] = cur; cnt[cur] = 0 }
			next
		}

		# A template record: emoji|header|description.
		{
			ok = 1
			if (cur == "") { bad("template outside a [Category]"); next }
			if (NF != 3) { bad("expected emoji|type(scope)!|description (" NF " fields)"); next }

			emoji = $1; header = $2; desc = $3
			if (emoji != "" && emoji !~ /^:[a-z0-9_+-]+:$/) bad("emoji must be a :shortcode: or empty (got \"" emoji "\")")
			if (header !~ HDR) bad("header \"" header "\" is not type[(scope)][!] with a conventional type")
			if (length(desc) < 12) bad("description is shorter than 12 characters")
			if (desc !~ /^[a-z0-9]/) bad("description must start with a lower-case letter or a digit")
			if (desc ~ /\.$/) bad("description must not end with a period")
			if (desc ~ /^ / || desc ~ / $/) bad("description has leading or trailing spaces")
			if (index(desc, "\"") || index(desc, "$") || index(desc, "`") || index(desc, "\\") || index(desc, apos)) {
				bad("description has a character that is unsafe for git commit -m (\" $ ` \\ or a single quote)")
			}
			plainlen = length(header) + 2 + length(desc)
			fulllen = plainlen
			if (emoji != "") fulllen = plainlen + 1 + length(emoji)
			if (fulllen > 100) bad("header is " fulllen " characters with the emoji; the limit is 100")
			else if (plainlen > 72) style("header is " plainlen " characters; git recommends at most 72")

			key = header SUBSEP desc
			# A repeated template is harmless: skipped quietly, and only `validate` reports it.
			if (key in first) {
				if (mode == "validate") bad("duplicate of " first[key])
				else ok = 0
			}
			if (!ok) next
			first[key] = FILENAME ":" FNR

			n = ++cnt[cur]
			E[cur, n] = emoji; H[cur, n] = header; D[cur, n] = desc
			total++
		}

		END {
			if (mode == "validate") {
				for (i = 1; i <= ncat; i++) if (cnt[cats[i]] == 0) {
					printf "category \"%s\" has no templates\n", cats[i] > "/dev/stderr"
					problems++
				}
				# The first field is the problem count: the shell turns it into the exit status.
				printf "%d\t%d template(s) in %d categories, %d problem(s), %d warning(s)\n", problems, total, ncat, problems, warnings + 0
			} else if (mode == "categories") {
				for (i = 1; i <= ncat; i++) if (cnt[cats[i]] > 0) print cats[i]
			} else {
				for (i = 1; i <= ncat; i++) {
					c = cats[i]
					if (mode == "render" && c != want) continue
					for (n = 1; n <= cnt[c]; n++) {
						if (mode == "records") print c "|" E[c, n] "|" H[c, n] "|" D[c, n]
						else if (plain == "true" || E[c, n] == "") print H[c, n] ": " D[c, n]
						else print H[c, n] ": " E[c, n] " " D[c, n]
					}
				}
			}
		}' "${files[@]}")" || return "$RETURN_FAILURE"

	if [ "$mode" = "validate" ]; then
		problems="${result%%$'\t'*}"
		printf '%s\n' "${result#*$'\t'}"
		if [ "${problems:-1}" -ne 0 ]; then
			return "$RETURN_FAILURE"
		fi
		return "$RETURN_SUCCESS"
	fi
	if [ -n "$result" ]; then
		printf '%s\n' "$result"
	fi
}

# @description Check commit message template files and report every problem.
#   Run it after adding a template: each rule that a record breaks is printed
#   as `file:line: problem` (for example a type that is not conventional, a
#   description that ends with a period, a header over 100 characters, or a
#   template that appears twice), and a one-line summary follows. A header over
#   72 characters (the length git recommends) is only a warning. With no argument it
#   checks the installed templates and, when it exists, your own file
#   (`~/.shell-config/git/git-commit-messages.user.txt`); with arguments, only those files.
#   The rules are those of Conventional Commits 1.0.0 plus a few that keep a
#   message safe to pass to `git commit -m`; they are listed in the header of
#   the data file.
# @option --strict Optional. Treat style warnings (a header over 72 characters) as problems, for CI.
# @option -h | --help Show this help message.
# @arg $@ string file: Optional. Template files to check instead of the default ones.
# @stdout A summary line: `N template(s) in M categories, P problem(s), W warning(s)`.
# @stderr One `file:line: problem` line per problem.
# @exitcode 0 Every template is valid.
# @exitcode 1 At least one problem was found, or a file is missing.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::message::base
# @example
#   shell::git::commit::message::validate
#   shell::git::commit::message::validate ./my-templates.txt
#
shell::git::commit::message::validate() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Check commit message templates against the format rules"
		shell::logger::usage "shell::git::commit::message::validate [--strict] [-h] [<file>...]"
		shell::logger::item "file" "Template files to check (default: the built-in and your own file)"
		shell::logger::option "--strict" "Treat style warnings (such as a header over 72 characters) as problems"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::note "Problems are printed as file:line: message; the exit status is 1 when there is any."
		shell::logger::example "shell::git::commit::message::validate"
		shell::logger::example "shell::git::commit::message::validate ./my-templates.txt"
		return "$RETURN_SUCCESS"
	fi

	local file strict=""
	if [ "${1-}" = "--strict" ]; then
		strict="--strict"
		shift
	fi
	for file in "$@"; do
		case "$file" in
		-*)
			shell::logger::error "Unknown option: $file"
			return "$RETURN_INVALID"
			;;
		esac
		if [ ! -r "$file" ]; then
			shell::logger::error "Cannot read: ${file}"
			return "$RETURN_FAILURE"
		fi
	done

	shell::git::commit::message::scan validate ${strict:+"$strict"} "$@"
}

# @internal
# @description Print the commit message catalog, one record per line:
#   `category|emoji|header|description`.
#
#   Every record renders to a header that follows Conventional Commits 1.0.0:
#
#       <type>[(scope)][!]: <description>
#
#   - `header` is `type`, `type(scope)`, `type!` or `type(scope)!`. The type is
#     one of build, chore, ci, docs, feat, fix, perf, refactor, revert, style,
#     test (the set used by the spec's examples and `@commitlint/config-conventional`).
#   - A trailing `!` marks a breaking change (MAJOR); the description then says
#     what breaks.
#   - `feat` is a new capability (MINOR) and `fix` a bug fix (PATCH). Everything
#     that changes neither is `refactor`, `perf`, `style` (formatting only),
#     `test`, `docs`, `build` (build system, dependencies), `ci` (pipelines) or
#     `chore` (the rest). Deprecating public API is `feat`, because SemVer
#     treats it as a MINOR change.
#   - `description` starts in lower case, is imperative, has no final period
#     and never contains `"`, `$`, a backtick or a backslash, so it is safe to
#     pass to `git commit -m` and through `eval`.
#   - `emoji` is a gitmoji shortcode, placed *after* the colon when used, so the
#     type stays the prefix of the message.
# @stdout The catalog (about 330 records in 36 categories, first-seen order).
# @exitcode 0 Always.
# @example
#   shell::git::commit::message::catalog | cut -d'|' -f1 | sort -u
#
shell::git::commit::message::catalog() {
	cat <<'EOF'
CI/CD Pipeline Triggers|:construction_worker:|ci|trigger CI build to test configuration changes
CI/CD Pipeline Triggers|:rocket:|ci(deploy)|deploy latest version to production environment
CI/CD Pipeline Triggers|:construction_worker:|ci|force re-run of test suite for validation purposes
CI/CD Pipeline Triggers|:construction_worker:|ci|validate GitHub Actions workflow after config update
CI/CD Pipeline Triggers|:rocket:|ci(deploy)|re-trigger deployment after infrastructure provisioning
CI/CD Pipeline Triggers|:wrench:|ci|bypass cache and force full rebuild of all pipeline stages
CI/CD Pipeline Triggers|:construction_worker:|ci|re-run failed pipeline after transient runner outage
CI/CD Pipeline Triggers|:construction_worker:|ci(preview)|rebuild preview environment for this branch
CI/CD Pipeline Triggers|:construction_worker:|ci|trigger scheduled workflow outside its normal window
CI/CD Pipeline Triggers|:construction_worker:|ci|re-trigger webhook delivery to the downstream pipeline
Documentation and Non-Code Changes|:books:|docs|document recent architectural decisions and trade-offs
Documentation and Non-Code Changes|:books:|docs|add notes from the latest team meeting
Documentation and Non-Code Changes|:books:|docs(readme)|document dependency updates in README.md
Documentation and Non-Code Changes|:books:|docs(api)|update API reference with new endpoint specifications
Documentation and Non-Code Changes|:books:|docs(contributing)|clarify setup instructions in CONTRIBUTING.md
Documentation and Non-Code Changes|:memo:|docs|add inline comments for complex business logic sections
Documentation and Non-Code Changes|:pencil2:|docs|fix typos and broken links in documentation
Documentation and Non-Code Changes|:books:|docs(changelog)|backfill missing entries in the changelog
Documentation and Non-Code Changes|:books:|docs|add architecture diagram for the request lifecycle
Documentation and Non-Code Changes|:books:|docs(adr)|record architecture decision for the storage choice
Documentation and Non-Code Changes|:books:|docs|add troubleshooting guide for common setup failures
Documentation and Non-Code Changes|:books:|docs(readme)|add quick start and usage examples
Feature and Product Development|:sparkles:|feat|add user-facing support for the requested workflow
Feature and Product Development|:sparkles:|feat|implement initial version of the new product capability
Feature and Product Development|:sparkles:|feat|add validation and clear feedback to the form flow
Feature and Product Development|:sparkles:|feat|introduce configurable behavior for the new integration
Feature and Product Development|:sparkles:|feat|add pagination and filtering to the resource listing
Feature and Product Development|:sparkles:|feat|support bulk actions for selected records
Feature and Product Development|:sparkles:|feat(search)|add full-text search with relevance ranking
Feature and Product Development|:sparkles:|feat(export)|allow exporting results as CSV
Feature and Product Development|:sparkles:|feat(notifications)|send email notification on status change
Feature and Product Development|:triangular_flag_on_post:|feat(flags)|hide unfinished feature behind a feature flag
Bug Fixes and Error Handling|:bug:|fix|prevent null reference error when optional data is missing
Bug Fixes and Error Handling|:bug:|fix|handle API timeout and retry transient request failures
Bug Fixes and Error Handling|:bug:|fix|correct edge case in date and timezone conversion
Bug Fixes and Error Handling|:bug:|fix|preserve user input after client-side validation fails
Bug Fixes and Error Handling|:bug:|fix|resolve race condition during concurrent update requests
Bug Fixes and Error Handling|:bug:|fix|return actionable error response for invalid request payload
Bug Fixes and Error Handling|:bug:|fix|handle empty collection without throwing an error
Bug Fixes and Error Handling|:bug:|fix|correct off-by-one error at the pagination boundary
Bug Fixes and Error Handling|:bug:|fix|escape special characters in user-provided search input
Bug Fixes and Error Handling|:bug:|fix|handle leap years and daylight saving transitions
Bug Fixes and Error Handling|:adhesive_bandage:|fix|correct typo in user-facing error message
Bug Fixes and Error Handling|:bug:|fix|prevent memory leak caused by unreleased event listeners
Bug Fixes and Error Handling|:bug:|fix|truncate text without splitting unicode characters
Bug Fixes and Error Handling|:bug:|fix|stop duplicate form submission on repeated clicks
Testing and Quality Assurance|:white_check_mark:|test|add regression coverage for reported production issue
Testing and Quality Assurance|:white_check_mark:|test|add unit tests for new validation rules
Testing and Quality Assurance|:white_check_mark:|test|cover API error responses and authorization paths
Testing and Quality Assurance|:white_check_mark:|test|add integration test for end-to-end checkout flow
Testing and Quality Assurance|:white_check_mark:|test|stabilize flaky test by waiting for async state
Testing and Quality Assurance|:white_check_mark:|test|add fixtures for representative edge-case data
Testing and Quality Assurance|:white_check_mark:|test(e2e)|add smoke test for the critical user journey
Testing and Quality Assurance|:white_check_mark:|test|quarantine flaky test and link the tracking issue
Testing and Quality Assurance|:camera_flash:|test|add snapshot tests for rendered components
Testing and Quality Assurance|:white_check_mark:|test(contract)|add consumer contract tests for the public API
Testing and Quality Assurance|:clown_face:|test|mock external service to remove network dependency
Testing and Quality Assurance|:white_check_mark:|test|add failing test that reproduces the reported bug
Performance and Reliability|:zap:|perf|reduce redundant database queries in request path
Performance and Reliability|:zap:|perf|cache expensive calculation for repeated lookups
Performance and Reliability|:zap:|perf(web)|reduce bundle size by lazy loading non-critical module
Performance and Reliability|:chart_with_upwards_trend:|test(perf)|add benchmark for critical query performance
Performance and Reliability|:goal_net:|fix(resilience)|add graceful fallback when dependency is unavailable
Performance and Reliability|:card_file_box:|perf(db)|add index to improve frequently filtered query
Performance and Reliability|:zap:|perf|stream large responses instead of buffering in memory
Performance and Reliability|:zap:|perf|batch writes to reduce database round trips
Performance and Reliability|:goal_net:|fix(resilience)|add timeout and circuit breaker to outbound calls
Performance and Reliability|:zap:|perf(db)|fix N+1 query when loading related records
API and Data Contracts|:sparkles:|feat(api)|add endpoint for managing resource settings
API and Data Contracts|:recycle:|refactor(api)|align API response with shared contract
API and Data Contracts|:safety_vest:|feat(api)|add schema validation for incoming payloads
API and Data Contracts|:card_file_box:|fix(db)|make database migration safe to run repeatedly
API and Data Contracts|:card_file_box:|feat(db)|add audit fields to persisted domain records
API and Data Contracts|:boom:|feat(api)!|remove deprecated field from public response
API and Data Contracts|:sparkles:|feat(api)|add versioned route for the new response format
API and Data Contracts|:bug:|fix(api)|return correct status code for validation errors
API and Data Contracts|:memo:|docs(api)|publish OpenAPI specification for public endpoints
API and Data Contracts|:sparkles:|feat(api)|add idempotency key support for create endpoints
API and Data Contracts|:sparkles:|feat(api)|support cursor-based pagination
Dependencies and Build Tooling|:package:|build|upgrade runtime to supported LTS version
Dependencies and Build Tooling|:arrow_up:|build(deps)|update direct dependencies to compatible versions
Dependencies and Build Tooling|:hammer:|build|configure reproducible local development build
Dependencies and Build Tooling|:construction_worker:|ci|cache package dependencies in CI workflow
Dependencies and Build Tooling|:heavy_minus_sign:|build(deps)|remove unused dependency from project manifest
Dependencies and Build Tooling|:green_heart:|ci|split test jobs to reduce pipeline duration
Dependencies and Build Tooling|:arrow_up:|build(deps)|bump all packages to latest stable versions
Dependencies and Build Tooling|:pushpin:|build(deps)|pin transitive dependency to a known good version
Dependencies and Build Tooling|:arrow_up:|fix(deps)|upgrade vulnerable dependency to patched release
Dependencies and Build Tooling|:package:|build(deps)|regenerate lockfile to fix integrity mismatch
Dependencies and Build Tooling|:heavy_plus_sign:|build(deps)|add runtime dependency required by the feature
Dependencies and Build Tooling|:arrow_down:|build(deps)|downgrade dependency to avoid regression in latest release
Architecture and Refactoring|:recycle:|refactor|extract shared business rules into dedicated service
Architecture and Refactoring|:recycle:|refactor|separate persistence concerns from application logic
Architecture and Refactoring|:recycle:|refactor|replace duplicated logic with reusable utility
Architecture and Refactoring|:building_construction:|refactor|reorganize module boundaries by domain
Architecture and Refactoring|:recycle:|refactor|simplify conditional flow for easier maintenance
Architecture and Refactoring|:recycle:|refactor|standardize error handling conventions across modules
Architecture and Refactoring|:truck:|refactor|move files to match the new directory structure
Architecture and Refactoring|:coffin:|refactor|remove dead code and unused exports
Architecture and Refactoring|:recycle:|refactor|replace inheritance with composition in domain model
Architecture and Refactoring|:recycle:|refactor|introduce interface to decouple from third-party client
Workflow and Repository Maintenance|:twisted_rightwards_arrows:|chore|refresh stale pull request to resolve merge conflicts
Workflow and Repository Maintenance|:twisted_rightwards_arrows:|chore|sync with main branch to keep feature branch up-to-date
Workflow and Repository Maintenance|:construction:|chore|set up scaffolding for the new feature branch
Workflow and Repository Maintenance|:wastebasket:|chore|clean up obsolete branches and outdated references
Workflow and Repository Maintenance|:twisted_rightwards_arrows:|chore|rebase feature branch on top of latest main
Workflow and Repository Maintenance|:bookmark:|chore(release)|tag release candidate for QA testing
Workflow and Repository Maintenance|:twisted_rightwards_arrows:|chore|resolve merge conflicts with the base branch
Workflow and Repository Maintenance|:twisted_rightwards_arrows:|chore|resolve lockfile conflicts after rebase
Workflow and Repository Maintenance|:bug:|fix|restore changes lost during conflict resolution
Workflow and Repository Maintenance|:wrench:|chore|squash fixup commits before merging
Workflow and Repository Maintenance|:wrench:|chore|add pull request and issue templates
Workflow and Repository Maintenance|:wrench:|chore|add CODEOWNERS to route reviews automatically
Project and Team Communication|:tada:|chore(team)|announce upcoming team building event
Project and Team Communication|:warning:|chore(infra)|notify team about planned server maintenance downtime
Project and Team Communication|:bookmark:|docs|share details about achieving a key project milestone
Project and Team Communication|:busts_in_silhouette:|chore(team)|onboard new team member with initial access setup
Project and Team Communication|:warning:|docs(api)|broadcast breaking API change notice to all consumers
Project and Team Communication|:books:|docs|summarize sprint retrospective findings and action items
Project and Team Communication|:books:|docs|add on-call handover notes for the next rotation
Project and Team Communication|:books:|docs|publish post-incident review and follow-up actions
Project and Team Communication|:books:|docs|record decisions from the planning session
Project and Team Communication|:busts_in_silhouette:|chore(team)|offboard former member and revoke repository access
Hotfix and Emergency Patches|:ambulance:|fix|apply emergency patch for critical production outage
Hotfix and Emergency Patches|:ambulance:|fix(auth)|hotfix login failure affecting all authenticated users
Hotfix and Emergency Patches|:lock:|fix(security)|patch critical vulnerability in authentication layer
Hotfix and Emergency Patches|:ambulance:|fix(db)|restore database connection pool after exhaustion
Hotfix and Emergency Patches|:rewind:|revert|roll back breaking change causing unexpected data loss
Hotfix and Emergency Patches|:triangular_flag_on_post:|fix(flags)|disable malfunctioning feature flag in production
Hotfix and Emergency Patches|:ambulance:|fix(config)|restore service after bad configuration rollout
Hotfix and Emergency Patches|:ambulance:|fix|stop error spike by guarding the failing code path
Hotfix and Emergency Patches|:ambulance:|fix(payments)|prevent duplicate charge on payment retry
Hotfix and Emergency Patches|:ambulance:|fix|patch regression introduced in the latest release
Database and Migration|:seedling:|chore(db)|seed development database with realistic test data
Database and Migration|:card_file_box:|chore(db)|run pending migrations on staging environment
Database and Migration|:card_file_box:|test(db)|verify migration rollback procedure on pre-production
Database and Migration|:package:|chore(db)|archive legacy records before destructive schema migration
Database and Migration|:card_file_box:|perf(db)|restructure table indexes for improved query performance
Database and Migration|:gear:|chore(db)|update connection pool settings for load testing scenario
Database and Migration|:card_file_box:|feat(db)|add nullable column first to allow zero-downtime rollout
Database and Migration|:card_file_box:|fix(db)|backfill missing values before adding not-null constraint
Database and Migration|:card_file_box:|feat(db)|add down migration so the change can be rolled back
Database and Migration|:card_file_box:|refactor(db)|split large migration into smaller reversible steps
Database and Migration|:card_file_box:|fix(db)|resolve migration ordering conflict between branches
Infrastructure and DevOps|:bricks:|chore(infra)|provision new cloud resources for auto-scaling group
Infrastructure and DevOps|:rocket:|ci(deploy)|update Kubernetes manifests for blue-green deployment
Infrastructure and DevOps|:wrench:|chore(infra)|rotate expiring SSL certificates across all environments
Infrastructure and DevOps|:gear:|chore(infra)|tune load balancer health check thresholds
Infrastructure and DevOps|:hammer:|build(docker)|update Dockerfile base image to latest LTS version
Infrastructure and DevOps|:loud_sound:|chore(infra)|configure centralized log aggregation for microservices
Infrastructure and DevOps|:hammer:|build(docker)|use multi-stage build to shrink the image
Infrastructure and DevOps|:bricks:|chore(infra)|add resource limits and requests to workloads
Infrastructure and DevOps|:bricks:|feat(infra)|add terraform module for the shared network
Infrastructure and DevOps|:stethoscope:|feat(infra)|add readiness and liveness probes
Infrastructure and DevOps|:bricks:|chore(infra)|schedule shutdown of idle environments to cut cost
Code Quality and Cleanup|:art:|style|enforce consistent formatting across entire codebase
Code Quality and Cleanup|:coffin:|refactor|eliminate dead code and unused import statements
Code Quality and Cleanup|:wrench:|chore|configure pre-commit hooks for automated lint checks
Code Quality and Cleanup|:white_check_mark:|test|raise minimum code coverage threshold to 80 percent
Code Quality and Cleanup|:recycle:|refactor|resolve all outstanding static analysis warnings
Code Quality and Cleanup|:recycle:|refactor|apply naming convention updates per team coding standards
Code Quality and Cleanup|:art:|style|reformat files with the project formatter
Code Quality and Cleanup|:label:|refactor|add missing type annotations
Code Quality and Cleanup|:pencil2:|style|fix whitespace and trailing newline issues
Code Quality and Cleanup|:wrench:|chore(lint)|enable stricter linter rules for new code
Security and Compliance|:lock:|fix(security)|rotate exposed API keys and invalidate compromised tokens
Security and Compliance|:lock:|feat(security)|enforce strict Content Security Policy headers
Security and Compliance|:arrow_up:|fix(deps)|upgrade dependency to remediate a known CVE
Security and Compliance|:lock:|feat(security)|enable multi-factor authentication for admin accounts
Security and Compliance|:books:|docs(security)|update security disclosure policy and process
Security and Compliance|:lock:|chore(security)|audit third-party integrations for privacy compliance
Security and Compliance|:closed_lock_with_key:|fix(security)|remove committed secret and move it to a secret manager
Security and Compliance|:lock:|fix(security)|sanitize user input to prevent injection attacks
Security and Compliance|:lock:|fix(security)|validate redirect targets to prevent open redirects
Security and Compliance|:lock:|feat(security)|add rate limiting to authentication endpoints
Security and Compliance|:lock:|ci(security)|add automated secret scanning to the pipeline
Release and Versioning|:bookmark:|chore(release)|cut stable release with full changelog
Release and Versioning|:bookmark:|chore(release)|mark stable release point for production rollout
Release and Versioning|:bookmark:|chore(release)|prepare hotfix release branch for patch deployment
Release and Versioning|:bookmark:|chore(release)|bump version to the next minor
Release and Versioning|:books:|docs(changelog)|finalize release notes for upcoming minor version
Release and Versioning|:rocket:|ci(release)|trigger automated release pipeline for major launch
Release and Versioning|:bookmark:|chore(release)|prepare first release candidate for QA
Release and Versioning|:bookmark:|chore(release)|bump version after publishing the release
Release and Versioning|:bookmark:|chore(release)|promote release candidate to stable
Experimental and Research Purposes|:alembic:|feat(experimental)|start working on experimental feature for research
Experimental and Research Purposes|:chart_with_upwards_trend:|docs(perf)|log results of recent performance benchmark
Experimental and Research Purposes|:books:|docs|document feedback from recent user testing session
Experimental and Research Purposes|:alembic:|feat(experimental)|prototype new caching strategy for evaluation
Experimental and Research Purposes|:construction:|chore(spike)|spike on feasibility of real-time collaboration feature
Experimental and Research Purposes|:alembic:|feat(experimental)|evaluate alternative state management approaches
Experimental and Research Purposes|:alembic:|feat(experimental)|add proof of concept behind an off-by-default flag
Experimental and Research Purposes|:alembic:|chore(spike)|time-box investigation of third-party library fit
Experimental and Research Purposes|:fire:|chore(experimental)|remove concluded experiment and its flags
Miscellaneous|:busts_in_silhouette:|chore|add new contributor to the project
Miscellaneous|:memo:|docs|record internal decision about project direction
Miscellaneous|:bookmark:|docs|mark completion of project milestone
Miscellaneous|:see_no_evil:|chore|update .gitignore to exclude new generated file types
Miscellaneous|:mute:|style|apply minor formatting fix with no functional impact
Miscellaneous|:loud_sound:|chore(logging)|temporarily enable verbose logging for active debugging
Miscellaneous|:wastebasket:|chore|remove unused assets and stale generated files
Miscellaneous|:pencil2:|chore|fix typo in code comment
Miscellaneous|:bulb:|docs|update outdated code comments
Miscellaneous|:page_facing_up:|chore|update copyright year in license headers
Breaking Changes and Deprecations|:boom:|feat(api)!|remove deprecated endpoints and drop v1 support
Breaking Changes and Deprecations|:boom:|feat!|require authentication for previously public endpoints
Breaking Changes and Deprecations|:boom:|refactor!|rename public configuration keys
Breaking Changes and Deprecations|:boom:|build!|drop support for end-of-life runtime versions
Breaking Changes and Deprecations|:boom:|fix(api)!|return 400 instead of 200 for invalid payloads
Breaking Changes and Deprecations|:wastebasket:|feat(api)|deprecate legacy endpoint in favor of its replacement
Breaking Changes and Deprecations|:wastebasket:|feat(cli)|deprecate old command flags and print warnings
Breaking Changes and Deprecations|:boom:|refactor(db)!|replace integer ids with UUIDs in public identifiers
Breaking Changes and Deprecations|:boom:|refactor(config)!|remove legacy configuration format
Breaking Changes and Deprecations|:books:|docs|add migration guide for the upcoming breaking release
Revert and Rollback|:rewind:|revert|undo last change that broke the production build
Revert and Rollback|:rewind:|revert|roll back feature release pending further validation
Revert and Rollback|:rewind:|revert|revert dependency upgrade that caused runtime errors
Revert and Rollback|:rewind:|revert|undo accidental merge of unfinished branch
Revert and Rollback|:rewind:|revert(db)|roll back database migration that failed on staging
Revert and Rollback|:rewind:|revert(config)|restore previous configuration after failed rollout
Revert and Rollback|:rewind:|revert|undo experimental change that degraded performance
Revert and Rollback|:bug:|fix|reapply reverted change with the root cause addressed
Initial Setup and Project Bootstrap|:tada:|chore|initial commit
Initial Setup and Project Bootstrap|:tada:|feat|initialize project skeleton with baseline structure
Initial Setup and Project Bootstrap|:wrench:|chore|add editorconfig, linter and formatter configuration
Initial Setup and Project Bootstrap|:construction_worker:|ci|add baseline CI workflow for build and tests
Initial Setup and Project Bootstrap|:books:|docs|add README with project overview and setup steps
Initial Setup and Project Bootstrap|:page_facing_up:|chore|add license file
Initial Setup and Project Bootstrap|:hammer:|build|scaffold build tooling and package manifest
Initial Setup and Project Bootstrap|:see_no_evil:|chore|add gitignore for the project toolchain
Initial Setup and Project Bootstrap|:white_check_mark:|test|set up test framework and first smoke test
Monorepo and Workspace|:package:|build(workspace)|add new package to the monorepo
Monorepo and Workspace|:recycle:|refactor(workspace)|extract shared code into internal library package
Monorepo and Workspace|:arrow_up:|build(deps)|align dependency versions across workspace packages
Monorepo and Workspace|:construction_worker:|ci|run checks only for packages affected by the change
Monorepo and Workspace|:hammer:|build(workspace)|configure incremental builds and project references
Monorepo and Workspace|:wrench:|chore(workspace)|hoist common dev dependencies to the root
Monorepo and Workspace|:bookmark:|chore(release)|version and publish changed packages together
Monorepo and Workspace|:fire:|refactor(workspace)|remove unused package from the workspace
Configuration and Environment|:wrench:|chore(config)|add .env.example listing required variables
Configuration and Environment|:bug:|fix(config)|fall back to safe default when variable is unset
Configuration and Environment|:triangular_flag_on_post:|feat(flags)|add runtime feature flag for gradual rollout
Configuration and Environment|:fire:|refactor(config)|remove hard-coded environment values from source
Configuration and Environment|:gear:|chore(config)|separate settings for dev, staging and production
Configuration and Environment|:bug:|fix(config)|validate configuration at startup and fail fast
Configuration and Environment|:closed_lock_with_key:|chore(config)|move secrets out of config files into a vault
Configuration and Environment|:fire:|chore(flags)|remove feature flag after full rollout
Frontend and User Interface|:lipstick:|feat(ui)|add dark mode with persisted preference
Frontend and User Interface|:lipstick:|style(ui)|adjust spacing and alignment to match design
Frontend and User Interface|:iphone:|fix(ui)|fix layout overflow on small mobile screens
Frontend and User Interface|:wheelchair:|fix(a11y)|add missing labels and keyboard focus handling
Frontend and User Interface|:bug:|fix(ui)|prevent layout shift while images load
Frontend and User Interface|:lipstick:|feat(ui)|add loading skeletons and empty states
Frontend and User Interface|:zap:|perf(ui)|debounce expensive input handlers
Frontend and User Interface|:children_crossing:|feat(ux)|improve error messages shown to the user
Frontend and User Interface|:art:|style(ui)|align components with the updated design tokens
Localization and Accessibility|:globe_with_meridians:|feat(i18n)|add translation keys and localized strings
Localization and Accessibility|:globe_with_meridians:|fix(i18n)|format dates, numbers and currency by locale
Localization and Accessibility|:globe_with_meridians:|fix(i18n)|handle right-to-left layouts
Localization and Accessibility|:globe_with_meridians:|chore(i18n)|sync translations from the localization platform
Localization and Accessibility|:wheelchair:|fix(a11y)|meet color contrast requirements
Localization and Accessibility|:wheelchair:|feat(a11y)|add screen reader announcements for dynamic updates
Localization and Accessibility|:globe_with_meridians:|fix(i18n)|replace hard-coded text with translated strings
Localization and Accessibility|:globe_with_meridians:|fix(i18n)|apply the correct plural rules for each language
Mobile and Cross-Platform|:iphone:|fix(ios)|fix crash on app launch after OS update
Mobile and Cross-Platform|:iphone:|fix(android)|fix back button handling in nested navigation
Mobile and Cross-Platform|:bookmark:|chore(release)|bump build number for store submission
Mobile and Cross-Platform|:hammer:|build(ios)|raise minimum deployment target
Mobile and Cross-Platform|:bug:|fix|normalize file paths across Windows, macOS and Linux
Mobile and Cross-Platform|:bug:|fix|handle CRLF and LF line endings consistently
Mobile and Cross-Platform|:bug:|fix(compat)|add fallback for browsers missing the required API
Mobile and Cross-Platform|:construction_worker:|ci|add build matrix for supported operating systems
Observability and Monitoring|:loud_sound:|feat(logging)|add structured logging with correlation ids
Observability and Monitoring|:chart_with_upwards_trend:|feat(metrics)|expose request latency and error rate metrics
Observability and Monitoring|:wrench:|chore(alerts)|tune alert thresholds to reduce noisy pages
Observability and Monitoring|:loud_sound:|feat(tracing)|propagate trace context across service calls
Observability and Monitoring|:mute:|fix(logging)|redact sensitive fields from log output
Observability and Monitoring|:books:|docs(runbook)|add runbook for the new alert
Observability and Monitoring|:mute:|fix(logging)|reduce log noise from expected errors
Observability and Monitoring|:stethoscope:|feat(health)|add health check endpoint for orchestration
Authentication and Authorization|:passport_control:|feat(auth)|add OAuth2 login with an external identity provider
Authentication and Authorization|:bug:|fix(auth)|refresh expired access tokens transparently
Authentication and Authorization|:passport_control:|feat(auth)|add role-based access control for admin routes
Authentication and Authorization|:lock:|fix(auth)|invalidate sessions on password change
Authentication and Authorization|:bug:|fix(auth)|account for clock skew when validating token expiry
Authentication and Authorization|:lock:|fix(auth)|enforce authorization checks on object ownership
Authentication and Authorization|:lock:|feat(auth)|lock account after repeated failed sign-in attempts
Authentication and Authorization|:passport_control:|feat(auth)|support single sign-on for enterprise customers
Data Processing and Background Jobs|:bug:|fix(jobs)|make background job idempotent to survive retries
Data Processing and Background Jobs|:sparkles:|feat(jobs)|add dead-letter queue for failed messages
Data Processing and Background Jobs|:zap:|perf|process large files in streams instead of loading into memory
Data Processing and Background Jobs|:bug:|fix(queue)|prevent duplicate message processing
Data Processing and Background Jobs|:sparkles:|feat(export)|stream large CSV exports to avoid timeouts
Data Processing and Background Jobs|:bug:|fix(jobs)|release locks when a scheduled job crashes
Data Processing and Background Jobs|:bug:|fix(jobs)|use UTC for scheduled job triggers
Data Processing and Background Jobs|:sparkles:|feat(jobs)|add retry with exponential backoff
Third-Party Integrations|:sparkles:|feat(webhook)|add webhook endpoint for the external service
Third-Party Integrations|:lock:|fix(webhook)|verify request signatures before processing
Third-Party Integrations|:bug:|fix(integration)|respect upstream rate limits with backoff
Third-Party Integrations|:arrow_up:|build(deps)|update vendor SDK to the latest supported version
Third-Party Integrations|:bug:|fix(integration)|tolerate unexpected fields in upstream responses
Third-Party Integrations|:recycle:|refactor(integration)|wrap vendor client behind an adapter interface
Third-Party Integrations|:bug:|fix(payments)|handle webhook retries without double processing
Third-Party Integrations|:fire:|chore(integration)|remove integration with discontinued service
Legacy Code and Migration|:recycle:|refactor|migrate callbacks to async and await
Legacy Code and Migration|:recycle:|refactor(legacy)|wrap legacy module behind an adapter
Legacy Code and Migration|:truck:|refactor|move legacy code into a dedicated package
Legacy Code and Migration|:arrow_up:|build|migrate to the new build tool
Legacy Code and Migration|:recycle:|refactor|replace legacy implementation incrementally, keeping behavior
Legacy Code and Migration|:wastebasket:|chore|retire legacy code paths that are no longer used
Legacy Code and Migration|:white_check_mark:|test|add characterization tests before refactoring legacy code
Legacy Code and Migration|:fire:|refactor|delete legacy module after migration completes
Licensing and Repository Governance|:page_facing_up:|chore|add license file and SPDX headers
Licensing and Repository Governance|:page_facing_up:|docs|add third-party notices and attributions
Licensing and Repository Governance|:books:|docs|add code of conduct
Licensing and Repository Governance|:lock:|docs(security)|add SECURITY.md with reporting instructions
Licensing and Repository Governance|:books:|docs(contributing)|add contribution guide and review checklist
Licensing and Repository Governance|:busts_in_silhouette:|chore|update maintainers list
Licensing and Repository Governance|:wrench:|ci(license)|add dependency license compliance check to the pipeline
Git Hygiene and Housekeeping|:fire:|chore|remove accidentally committed build artifacts
Git Hygiene and Housekeeping|:see_no_evil:|chore|stop tracking local environment files
Git Hygiene and Housekeeping|:wrench:|chore|normalize line endings with gitattributes
Git Hygiene and Housekeeping|:package:|chore|track large binary assets with Git LFS
Git Hygiene and Housekeeping|:wrench:|chore|configure commit message linting
Git Hygiene and Housekeeping|:see_no_evil:|chore|ignore editor and operating system files
Work in Progress and Checkpoints|:construction:|chore(wip)|save checkpoint before switching tasks
Work in Progress and Checkpoints|:construction:|chore(wip)|partial implementation, tests still failing
Work in Progress and Checkpoints|:construction:|chore(wip)|scaffold structure only, behavior to follow
Work in Progress and Checkpoints|:construction:|chore(wip)|draft for early feedback, not ready to merge
Work in Progress and Checkpoints|:construction:|chore(wip)|stash progress to discuss the approach
Developer Experience|:technologist:|chore(dx)|add scripts for one-command local setup
Developer Experience|:technologist:|chore(devcontainer)|add development container configuration
Developer Experience|:technologist:|build|speed up local rebuilds with incremental caching
Developer Experience|:technologist:|chore(dx)|add make targets for common tasks
Developer Experience|:technologist:|chore(dx)|add debug launch configurations for the editor
API Design and Contracts|:memo:|feat(api)|implement field masking for sensitive data in responses
API Design and Contracts|:boom:|feat(api)!|standardize error response payload to RFC 7807 format
API Design and Contracts|:lock:|feat(api)|add ETag and If-None-Match headers for caching support
API Design and Contracts|:white_check_mark:|test(api)|add contract tests using Pact to prevent breaking changes
API Design and Contracts|:books:|docs(api)|publish OpenAPI 3.1 specification with strict validation rules
API Design and Contracts|:recycle:|refactor(api)|replace REST endpoints with GraphQL federation gateway
API Design and Contracts|:zap:|perf(api)|implement cursor-based pagination for large datasets
Performance and Scalability|:chart_with_upwards_trend:|perf(db)|add composite index for slow query in reporting dashboard
Performance and Scalability|:fire:|refactor(cache)|switch from LRU to LFU eviction policy in Redis
Performance and Scalability|:rocket:|perf(net)|enable HTTP/3 and QUIC protocol at the edge CDN
Performance and Scalability|:construction_worker:|ci(perf)|add automated k6 load testing to the CI pipeline
Performance and Scalability|:mag:|chore(metrics)|add p99 latency SLI for the payment processing service
Performance and Scalability|:wrench:|chore(sre)|define error budget policy and SLO burn rate alerts
Performance and Scalability|:stopwatch:|perf(app)|optimize event loop blocking operations using worker threads
Distributed Systems|:link:|feat(saga)|implement orchestrator pattern for cross-service transactions
Distributed Systems|:shield:|feat(resilience)|add circuit breaker with exponential backoff fallback
Distributed Systems|:package:|refactor(messaging)|ensure exactly-once delivery semantics using idempotency keys
Distributed Systems|:alembic:|feat(cqrs)|separate read and write models for the audit log subsystem
Distributed Systems|:loud_sound:|feat(tracing)|inject W3C Trace Context headers across all gRPC calls
Distributed Systems|:rewind:|feat(events)|implement outbox pattern to guarantee reliable event publishing
Distributed Systems|:recycle:|refactor(sync)|replace synchronous HTTP calls with asynchronous domain events
Security and Compliance (Advanced)|:closed_lock_with_key:|feat(auth)|implement mutual TLS (mTLS) for service-to-service communication
Security and Compliance (Advanced)|:lock:|fix(security)|remediate Server-Side Request Forgery (SSRF) vulnerability
Security and Compliance (Advanced)|:passport_control:|feat(auth)|enforce short-lived JWTs with sliding refresh token rotation
Security and Compliance (Advanced)|:shield:|feat(security)|add content security policy (CSP) reporting endpoint
Security and Compliance (Advanced)|:bookmark:|chore(compliance)|generate SBOM (Software Bill of Materials) during build
Security and Compliance (Advanced)|:lock:|fix(security)|sanitize untrusted HTML inputs using DOMPurify on the server
Data Engineering and Pipelines|:card_file_box:|feat(etl)|add incremental Change Data Capture (CDC) for user tables
Data Engineering and Pipelines|:arrows_counterclockwise:|fix(pipeline)|ensure idempotent data ingestion to prevent duplicates
Data Engineering and Pipelines|:hourglass_flowing_sand:|chore(backfill)|trigger historical data backfill for Q3 metrics
Data Engineering and Pipelines|:white_check_mark:|test(data)|add data quality assertions on schema and nullability
Data Engineering and Pipelines|:wastebasket:|chore(archival)|move cold storage records to S3 Glacier lifecycle policy
Data Engineering and Pipelines|:sparkles:|feat(streaming)|implement exactly-once windowing in Apache Flink job
Testing Strategy and Reliability|:test_tube:|test(e2e)|add visual regression tests for critical user journeys
Testing Strategy and Reliability|:alembic:|test(mutation)|integrate Stryker to measure test suite effectiveness
Testing Strategy and Reliability|:bug:|test(fix)|add a reproduction test for the race condition bug
Testing Strategy and Reliability|:crystal_ball:|test(property)|add property-based testing for the pricing engine
Testing Strategy and Reliability|:construction_worker:|ci(tests)|parallelize end-to-end test execution across shards
Testing Strategy and Reliability|:hammer_and_wrench:|test(fixtures)|replace hardcoded mocks with dynamically generated test data
Cloud Native and Kubernetes|:whale:|build(k8s)|implement zero-downtime rolling updates with preStop hooks
Cloud Native and Kubernetes|:shield:|feat(k8s)|enforce Pod Security Standards (Restricted) via Kyverno policies
Cloud Native and Kubernetes|:chart_with_upwards_trend:|feat(k8s)|configure Vertical Pod Autoscaler (VPA) recommendations
Cloud Native and Kubernetes|:package:|feat(helm)|extract shared subcharts for common deployment templates
Cloud Native and Kubernetes|:lock:|feat(secrets)|integrate External Secrets Operator with HashiCorp Vault
Cloud Native and Kubernetes|:fire:|refactor(k8s)|remove deprecated Kubernetes API versions before cluster upgrade
Observability and Telemetry|:chart_with_upwards_trend:|feat(metrics)|expose custom Prometheus histogram for API latency
Observability and Telemetry|:mag:|feat(tracing)|propagate OpenTelemetry baggage across microservices
Observability and Telemetry|:books:|docs(runbook)|document incident response steps for high-severity alerts
Observability and Telemetry|:loud_sound:|feat(logging)|add structured JSON logging with correlation IDs
Observability and Telemetry|:zap:|perf(observability)|sample tracing dynamically based on traffic volume
Database and Schema Evolution|:card_file_box:|feat(db)|add partial index to optimize soft-deleted queries
Database and Schema Evolution|:lock:|feat(db)|enable row-level security policies for multi-tenancy
Database and Schema Evolution|:recycle:|refactor(db)|normalize redundant tables to eliminate update anomalies
Database and Schema Evolution|:zap:|perf(db)|introduce materialized views for complex aggregation dashboards
Database and Schema Evolution|:fire:|fix(db)|correct collation mismatch causing inconsistent string sorting
State Management and Frontend Architecture|:recycle:|refactor(state)|migrate global state to a unidirectional data flow pattern
State Management and Frontend Architecture|:zap:|perf(state)|memoize expensive derived state selectors
State Management and Frontend Architecture|:package:|build(deps)|replace deprecated state library with modern alternative
State Management and Frontend Architecture|:lipstick:|feat(ssr)|hydrate server-rendered components without layout shift
State Management and Frontend Architecture|:fire:|refactor(components)|extract complex logic into custom composables
State Management and Frontend Architecture|:bug:|fix(routing)|preserve query parameters during nested route transitions
Machine Learning Operations|:robot:|feat(ml)|register new model version in the model registry
Machine Learning Operations|:chart_with_upwards_trend:|perf(ml)|quantize model weights to reduce inference latency
Machine Learning Operations|:alembic:|feat(experiment)|track hyperparameter tuning results in MLflow
Machine Learning Operations|:construction_worker:|ci(ml)|add automated bias detection to the training pipeline
Machine Learning Operations|:arrow_up:|build(deps)|upgrade torch version for latest operator support
Machine Learning Operations|:fire:|chore(ml)|prune stale model checkpoints from the artifact store
EOF
}

# @description Pick a pre-defined commit message from a categorized menu and print it.
#   A two-level fzf menu (category, then message) over the catalog of
#   shell::git::commit::message::catalog. Meant for scripted or empty commits
#   (`git commit --allow-empty`); shell::git::commit::create --empty uses it.
#
#   Every message follows Conventional Commits 1.0.0, `<type>[(scope)][!]: <description>`,
#   so the type is always the prefix and tools such as commitlint, semantic-release
#   or release-please can parse it. By default a gitmoji shortcode is placed
#   **after** the colon (`feat: :sparkles: add ...`), which keeps the message
#   valid; `--plain` leaves it out (`feat: add ...`).
#
#   With `--back` both menus get a "← Back" entry: in the message menu it returns
#   to the category menu; in the category menu it leaves with `RETURN_BACK`, so
#   a caller can step back one screen (ESC still aborts).
# @option -h | --help Show this help message.
# @option -p | --plain Omit the emoji: print `type(scope)!: description` only.
# @option -b | --back Add a "← Back" entry to both menus.
# @stdout The selected commit message (nothing when the menu is cancelled or left with Back).
# @exitcode 0 A message was printed, or the menu was cancelled (ESC).
# @exitcode 2 Unknown option.
# @exitcode 11 --back: "Back" was picked in the category menu.
# @see shell::git::commit::create
# @see shell::ask::option::back
# @example
#   shell::git::commit::message::base
#   shell::git::commit::message::base --plain
#   shell::git::commit::message::base --back
#   git commit --allow-empty -m "$(shell::git::commit::message::base)"
#
shell::git::commit::message::base() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Select a Conventional Commits message from a categorized menu"
		shell::logger::usage "shell::git::commit::message::base [-p] [-b]"
		shell::logger::option "-p, --plain" "Omit the emoji (type(scope)!: description)"
		shell::logger::option "-b, --back" "Add a back entry to both menus"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::example "shell::git::commit::message::base"
		shell::logger::example "shell::git::commit::message::base --plain"
		shell::logger::example "shell::git::commit::message::base --back"
		shell::logger::example "git commit --allow-empty -m \"\$(shell::git::commit::message::base)\""
		return "$RETURN_SUCCESS"
	fi

	local plain="false" back="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-p | --plain)
			plain="true"
			shift
			;;
		-b | --back)
			back="true"
			shift
			;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
	done

	local catalog
	catalog="$(shell::git::commit::message::catalog)"

	# Categories, in the order they first appear in the catalog.
	local -a categories=()
	local line
	while IFS= read -r line; do
		categories+=("$line")
	done < <(printf '%s\n' "$catalog" | awk -F'|' '!seen[$1]++ { print $1 }')

	# The picker is the plain menu, or the one with a "← Back" entry.
	local -a pick=(shell::ask::option)
	if [ "$back" = "true" ]; then
		pick=(shell::ask::option::back)
	fi

	# Declared once, before the loop (re-declaring a local in a loop prints in zsh).
	local selected_category selected_message rc
	local category emoji header description
	local -a messages=()

	while true; do
		# Step 1 — category.
		selected_category="$("${pick[@]}" "${categories[@]}")"
		rc=$?
		if [ "$rc" -eq "$RETURN_BACK" ]; then
			return "$RETURN_BACK"
		fi
		if [ "$rc" -ne 0 ] || [ -z "$selected_category" ]; then
			shell::logger::warn "No category selected — aborting"
			return "$RETURN_SUCCESS"
		fi

		# Step 2 — render the messages of that category.
		messages=()
		while IFS='|' read -r category emoji header description; do
			if [ "$category" != "$selected_category" ]; then
				continue
			fi
			if [ "$plain" = "true" ] || [ -z "$emoji" ]; then
				messages+=("${header}: ${description}")
			else
				messages+=("${header}: ${emoji} ${description}")
			fi
		done < <(printf '%s\n' "$catalog")

		# Step 3 — pick one. Back returns to the category menu.
		selected_message="$("${pick[@]}" "${messages[@]}")"
		rc=$?
		if [ "$rc" -eq "$RETURN_BACK" ]; then
			continue
		fi
		if [ "$rc" -ne 0 ] || [ -z "$selected_message" ]; then
			shell::logger::warn "No message selected — aborting"
			return "$RETURN_SUCCESS"
		fi

		printf '%s\n' "$selected_message"
		return "$RETURN_SUCCESS"
	done
}

# @internal
# @description Read one line of text for a wizard step, with back support.
#   The prompt goes to stderr and the value to stdout, so the function can be
#   used in `$(...)`. Typing `:back` returns `RETURN_BACK`. An empty line keeps
#   `current` when there is one (it is shown in the prompt), otherwise the
#   question is asked again. End of input (Ctrl-D) is a cancel.
# @arg $1 string Prompt text.
# @arg $2 string Current value, kept on an empty line (optional).
# @stdout The entered (or kept) value.
# @exitcode 0 A value was entered or kept.
# @exitcode 9 End of input (Ctrl-D).
# @exitcode 11 The user typed `:back`.
# @example
#   value="$(shell::git::commit::input "Issue number" "$issue")"
#
shell::git::commit::input() {
	local prompt="${1-}" current="${2-}" value=""

	while true; do
		if [ -n "$current" ]; then
			printf '%s [Enter keeps: %s] (:back to go back): ' "$prompt" "$current" >&2
		else
			printf '%s (:back to go back): ' "$prompt" >&2
		fi

		if ! read -r value; then
			printf '\n' >&2
			return "$RETURN_CANCELLED"
		fi

		case "$value" in
		:back) return "$RETURN_BACK" ;;
		'')
			if [ -n "$current" ]; then
				printf '%s\n' "$current"
				return "$RETURN_SUCCESS"
			fi
			shell::logger::warn "This value cannot be empty — please try again"
			;;
		*)
			printf '%s\n' "$value"
			return "$RETURN_SUCCESS"
			;;
		esac
	done
}

# @description Interactively builds and commits a formatted Git commit message, one
#   step at a time. Every menu has a "← Back" entry (and the text prompts accept
#   `:back`), so a wrong choice is fixed by stepping back instead of aborting.
#   ESC / Ctrl-C still abort the whole command. In default mode it prompts for
#   commit type (with emoji), description and issue number, then commits, sends a
#   Telegram activity notification and pushes to origin. In --empty mode it
#   presents pre-defined empty commit messages grouped by category and runs
#   git commit --allow-empty.
#
#   Default mode (Back returns to the previous step; at step 1 it leaves):
#   1. Select commit type (feat, fix, chore, …)            [Back = leave]
#   2. Read commit description (kept when going back)       [:back = step 1]
#   3. Read issue number (kept when going back)             [:back = step 2]
#   4. Build `<emoji> <type>: <description> <issue>`, then Commit / Abort [Back = step 3]
#   5. git commit -m "<message>"
#   6. Send Telegram notification via shell::git::telegram::history::send
#   7. git push origin <current_branch>
#
#   Empty mode (--empty):
#   1. Select category, then a message (shell::git::commit::message::base --back)
#      [Back in the message list = categories; Back in the categories = leave]
#   2. Choose Create empty commit / Abort                    [Back = step 1]
#   3. git commit --allow-empty -m "<message>"
# @option -n | --dry-run Optional. Print the git commit command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @option -e | --empty Optional. Switch to empty-commit mode — select a pre-defined message and run git commit --allow-empty.
# @exitcode 0 Success, or the user backed out / cancelled.
# @exitcode 1 The operation failed.
# @see shell::ask::option::back
# @see shell::git::commit::message::base
# @example
#   shell::git::commit::create
#   shell::git::commit::create --empty
#   shell::git::commit::create -n
#
shell::git::commit::create() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively build and commit a formatted Git commit message (with Back navigation)"
		shell::logger::usage "shell::git::commit::create [-n] [-h] [-e]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the git commit command instead of executing it"
		shell::logger::option "-e, --empty" "Use a pre-defined empty commit message (--allow-empty)"
		shell::logger::note "Pick '$SHELL_FZF_BACK_LABEL' in a menu, or type :back at a text prompt, to return to the previous step."
		shell::logger::example "shell::git::commit::create"
		shell::logger::example "shell::git::commit::create --empty"
		shell::logger::example "shell::git::commit::create -n"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local empty_mode="false"
	if [ "${1-}" = "-e" ] || [ "${1-}" = "--empty" ]; then
		empty_mode="true"
		shift
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return "$RETURN_FAILURE"
	fi

	# Declared once, before any loop: re-declaring a local inside a loop prints
	# its value in zsh.
	local rc choice value step
	local selected_message selected_type emoji commit_message
	local commit_description="" issue_number=""
	local cmd_commit_empty cmd_commit empty_branch

	# ===========================================================================
	# Empty commit mode — delegate the pick to shell::git::commit::message::base.
	# ===========================================================================
	if [ "$empty_mode" = "true" ]; then
		while true; do
			selected_message="$(shell::git::commit::message::base --plain --back)"
			rc=$?

			# Back from the first screen, or ESC: nothing to commit.
			if [ "$rc" -eq "$RETURN_BACK" ] || [ -z "$selected_message" ]; then
				return "$RETURN_SUCCESS"
			fi

			shell::logger::info "Selected commit message: ${selected_message}"

			choice="$(shell::ask::option::back --prompt "Create this empty commit? " "Create empty commit" "Abort")"
			rc=$?
			case "$rc" in
			0) ;;
			"$RETURN_BACK") continue ;;
			*)
				shell::logger::info "Commit aborted"
				return "$RETURN_SUCCESS"
				;;
			esac

			if [ "$choice" != "Create empty commit" ]; then
				shell::logger::info "Commit aborted"
				return "$RETURN_SUCCESS"
			fi
			break
		done

		cmd_commit_empty="git commit --allow-empty -m \"${selected_message}\""
		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "$cmd_commit_empty"
			return "$RETURN_SUCCESS"
		fi

		shell::logger::assert "$cmd_commit_empty" \
			"Empty commit created successfully" "Empty commit aborted" || return $?

		# Push the commit via interactive push command picker.
		empty_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
		shell::git::branch::push "${empty_branch}"

		return "$RETURN_SUCCESS"
	fi

	# ===========================================================================
	# Default mode — formatted commit: type + emoji + description + issue.
	# A small state machine: each step can send the user back to the previous one.
	# ===========================================================================
	step="type"
	while true; do
		case "$step" in
		type)
			selected_type="$(shell::ask::option::back --prompt "Commit type: " \
				"feat" "fix" "chore" "docs" "style" "refactor" "test" "perf" \
				"WIP" "improvement" "revert" "security" "remove" "initial source" \
				"logs" "config" "build" "dependency" "deployment" "localization" \
				"search" "experimental" "version tag" "silent changes" "deprecation" "release")"
			rc=$?

			# Back from the first step leaves the command.
			if [ "$rc" -eq "$RETURN_BACK" ]; then
				shell::logger::info "Commit cancelled"
				return "$RETURN_SUCCESS"
			fi
			if [ "$rc" -ne 0 ] || [ -z "$selected_type" ]; then
				shell::logger::warn "No commit type selected — aborting"
				return "$RETURN_SUCCESS"
			fi

			# Map commit type → emoji code.
			case "$selected_type" in
			feat) emoji=":sparkles:" ;;
			fix) emoji=":bug:" ;;
			chore) emoji=":wrench:" ;;
			docs) emoji=":books:" ;;
			style) emoji=":art:" ;;
			refactor) emoji=":recycle:" ;;
			test) emoji=":white_check_mark:" ;;
			perf) emoji=":chart_with_upwards_trend:" ;;
			WIP) emoji=":construction:" ;;
			improvement) emoji=":zap:" ;;
			revert) emoji=":rewind:" ;;
			security) emoji=":lock:" ;;
			remove) emoji=":fire:" ;;
			"initial source") emoji=":tada:" ;;
			logs) emoji=":loud_sound:" ;;
			config) emoji=":gear:" ;;
			build) emoji=":hammer:" ;;
			dependency) emoji=":package:" ;;
			deployment) emoji=":rocket:" ;;
			localization) emoji=":earth_americas:" ;;
			search) emoji=":mag:" ;;
			experimental) emoji=":alien:" ;;
			"version tag") emoji=":bookmark:" ;;
			"silent changes") emoji=":mute:" ;;
			deprecation) emoji=":warning:" ;;
			release) emoji=":gem:" ;;
			*) emoji="" ;;
			esac
			step="description"
			;;

		description)
			value="$(shell::git::commit::input "Enter a concise and clear commit description" "$commit_description")"
			rc=$?
			case "$rc" in
			0)
				commit_description="$value"
				step="issue"
				;;
			"$RETURN_BACK") step="type" ;;
			*)
				shell::logger::warn "Input cancelled — aborting"
				return "$RETURN_SUCCESS"
				;;
			esac
			;;

		issue)
			value="$(shell::git::commit::input "Enter issue number (e.g. #1)" "$issue_number")"
			rc=$?
			case "$rc" in
			0)
				issue_number="$value"
				step="confirm"
				;;
			"$RETURN_BACK") step="description" ;;
			*)
				shell::logger::warn "Input cancelled — aborting"
				return "$RETURN_SUCCESS"
				;;
			esac
			;;

		confirm)
			commit_message="${emoji} ${selected_type}: ${commit_description} ${issue_number}"
			shell::logger::info "Commit message: ${commit_message}"

			choice="$(shell::ask::option::back --prompt "Proceed with this commit? " "Commit" "Abort")"
			rc=$?
			case "$rc" in
			0)
				if [ "$choice" = "Commit" ]; then
					break
				fi
				shell::logger::info "Commit aborted"
				return "$RETURN_SUCCESS"
				;;
			"$RETURN_BACK") step="issue" ;;
			*)
				shell::logger::info "Commit aborted"
				return "$RETURN_SUCCESS"
				;;
			esac
			;;
		esac
	done

	# Commit.
	cmd_commit="git commit -m \"${commit_message}\""

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_commit"
		return "$RETURN_SUCCESS"
	fi

	shell::logger::assert "$cmd_commit" \
		"Commit created: ${commit_message}" "Commit aborted" || return $?

	# Collect metadata and send Telegram notification.
	local git_username
	local current_branch
	local commit_hash
	local repository_path
	local repository_name
	local server_remote_url
	local timestamp

	git_username=$(git config user.name 2>/dev/null)
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
	commit_hash=$(git rev-parse HEAD 2>/dev/null)
	repository_path=$(git rev-parse --show-toplevel 2>/dev/null)
	repository_name=$(basename "${repository_path}")
	server_remote_url=$(git config --get remote.origin.url 2>/dev/null)
	timestamp=$(date "+%Y-%m-%d %H:%M:%S")

	local telegram_message="username: ${git_username} | repository: ${repository_name} (${server_remote_url}) | branch: ${current_branch} | hash: ${commit_hash} | message: ${commit_message} | timestamp: ${timestamp}"
	shell::git::telegram::history::send "${telegram_message}"

	# Push current branch to origin via interactive push command picker.
	shell::git::branch::push "${current_branch}"

	return "$RETURN_SUCCESS"
}

# @description Checks out a specific commit hash (detached HEAD). Optionally creates a new
#   branch from that commit. Supports dry-run mode.
#
#   Step 1 — Verify the commit hash exists in the repository.
#   Step 2 — If -b is provided, run: git checkout -b <branch_name> <commit_hash>
#   Otherwise, run: git checkout <commit_hash>
#   Step 3 — Log the result via shell::logger::assert.
#
#   Safety notes:
#   • When -b is omitted, HEAD enters detached state. Run 'git checkout <branch>'
#   or 'git switch -' to return to a branch.
#   • When -b is provided, the new branch is created at the commit and checked
#   out immediately (no detached HEAD).
# @option -n | --dry-run Optional. Print the command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @option -b | --branch Optional. Create and checkout a new branch from the commit instead of detached HEAD.
# @arg $1 string commit_hash: Required. Full or short commit hash to checkout.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::commit::checkout "abc1234"
#   shell::git::commit::checkout -b "hotfix-legacy" "abc1234"
#   shell::git::commit::checkout -n "abc1234"
#
shell::git::commit::checkout() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Checkout a specific commit hash (detached HEAD or new branch)"
		shell::logger::usage "shell::git::commit::checkout [-n] [-h] [-b <branch_name>] <commit_hash>"
		shell::logger::item "commit_hash" "Full or short commit hash to checkout"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-b, --branch <name>" "Create and checkout a new branch from the commit"
		shell::logger::example "shell::git::commit::checkout \"abc1234\""
		shell::logger::example "shell::git::commit::checkout -b \"hotfix-legacy\" \"abc1234\""
		shell::logger::example "shell::git::commit::checkout -n \"abc1234\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local branch_name=""
	if [ "$1" = "-b" ] || [ "$1" = "--branch" ]; then
		branch_name="$2"
		shift 2
	fi

	local commit_hash="$1"

	if [ -z "$commit_hash" ]; then
		shell::logger::error "Commit hash is required"
		return $RETURN_INVALID
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# Verify the commit hash exists.
	if ! git rev-parse --verify --quiet "${commit_hash}" >/dev/null 2>&1; then
		shell::logger::error "Commit '${commit_hash}' does not exist in this repository"
		return $RETURN_FAILURE
	fi

	# Resolve the full hash for logging.
	local full_hash
	full_hash=$(git rev-parse "${commit_hash}" 2>/dev/null)

	# Build the checkout command.
	local cmd_checkout
	if [ -n "$branch_name" ]; then
		cmd_checkout="git checkout -b \"${branch_name}\" \"${commit_hash}\""
	else
		cmd_checkout="git checkout \"${commit_hash}\""
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_checkout"
		return $RETURN_SUCCESS
	fi

	# Execute checkout.
	if [ -n "$branch_name" ]; then
		shell::logger::assert "$cmd_checkout" \
			"Created and checked out branch '${branch_name}' from commit ${full_hash:0:8}" \
			"Checkout aborted" || return $?
	else
		shell::logger::assert "$cmd_checkout" \
			"Checked out commit ${full_hash:0:8} (detached HEAD)" \
			"Checkout aborted" || return $?
	fi

	return $RETURN_SUCCESS
}

# @description Presents a multi-select picker of all commits across all refs via fzf,
#   then checks out the first selected commit via shell::git::commit::checkout.
#   Optionally creates a new branch from the selected commit.
#
#   Step 1 — Verify the git repository.
#   Step 2 — Build a coloured commit list via git log --all covering all local
#   branches, remote-tracking branches, and tags.
#   Step 3 — Present a multi-select picker (TAB to mark multiple entries).
#   Step 4 — Extract the first 40-char hex hash from the selection.
#   Step 5 — Forward to shell::git::commit::checkout with the extracted hash.
#   If -b was provided, the branch name is forwarded as well.
# @option -n | --dry-run Optional. After selection, print the checkout command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @option -b | --branch Optional. Create and checkout a new branch from the selected commit instead of detached HEAD.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::commit::checkout::fzf
#   shell::git::commit::checkout::fzf -b "legacy-fix"
#   shell::git::commit::checkout::fzf -n
#
shell::git::commit::checkout::fzf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Select a commit via fzf and check it out"
		shell::logger::usage "shell::git::commit::checkout::fzf [-n] [-h] [-b <branch_name>]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the checkout command instead of executing it"
		shell::logger::option "-b, --branch <name>" "Create and checkout a new branch from the selected commit"
		shell::logger::example "shell::git::commit::checkout::fzf"
		shell::logger::example "shell::git::commit::checkout::fzf -b \"legacy-fix\""
		shell::logger::example "shell::git::commit::checkout::fzf -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local branch_name=""
	if [ "$1" = "-b" ] || [ "$1" = "--branch" ]; then
		branch_name="$2"
		shift 2
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# ---------------------------------------------------------------------------
	# Log format — coloured: full hash, short hash, relative time, author, refs, subject.
	# Matches the format used by all other shell::git::commit::* functions.
	# ---------------------------------------------------------------------------
	local log_format="%C(bold blue)%H (%h)%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%an%C(reset)%C(bold yellow)%d%C(reset) %C(dim white)- %s%C(reset)"

	# Build per-line array — one element per commit — for shell::ask::options.
	local -a commit_lines
	while IFS= read -r line; do
		commit_lines+=("$line")
	done < <(git log --format=format:"${log_format}" --all --color=always 2>/dev/null)

	if [ "${#commit_lines[@]}" -eq 0 ]; then
		shell::logger::warn "No commits found in repository — aborting"
		return $RETURN_SUCCESS
	fi

	# Present multi-select picker via codebase helper (TAB to select multiple).
	local selected_output
	selected_output=$(shell::ask::options "${commit_lines[@]}")

	if [ -z "$selected_output" ]; then
		shell::logger::warn "No commit selected — aborting"
		return $RETURN_SUCCESS
	fi

	# Extract the first 40-char hex hash from the (ANSI-coded, space-joined) output.
	# grep -oE is robust against ANSI escape sequences and works on GNU + BSD grep.
	local commit_hash
	commit_hash=$(printf '%s' "$selected_output" | grep -oE '[0-9a-f]{40}' | head -1)

	if [ -z "$commit_hash" ]; then
		shell::logger::warn "Could not extract commit hash from selection — aborting"
		return $RETURN_SUCCESS
	fi

	# Retrieve subject for logging.
	local commit_subject
	commit_subject=$(git log -1 --format='%s' "$commit_hash" 2>/dev/null)

	shell::logger::info "Selected commit: ${commit_hash:0:8}  ${commit_subject}"

	# Forward to shell::git::commit::checkout with the extracted hash.
	if [ "$dry_run" = "true" ]; then
		if [ -n "$branch_name" ]; then
			shell::git::commit::checkout -n -b "$branch_name" "$commit_hash"
		else
			shell::git::commit::checkout -n "$commit_hash"
		fi
	else
		if [ -n "$branch_name" ]; then
			shell::git::commit::checkout -b "$branch_name" "$commit_hash"
		else
			shell::git::commit::checkout "$commit_hash"
		fi
	fi

	return $RETURN_SUCCESS
}

# @description Checks out a specified branch, creates an annotated Git tag on the latest
#   commit, pushes the tag to origin, restores the original branch, and sends a
#   Telegram activity notification via shell::git::telegram::history::send.
#
#   1. git checkout <branch>                — switch to target branch
#   2. Collect commit metadata              — short hash, author, date
#   3. git tag -a <tag> -m <message>        — create annotated tag with metadata
#   4. git push origin <tag>                — push tag to origin
#   5. git checkout <original_branch>       — restore original branch
#   6. shell::git::telegram::history::send  — send Telegram notification
# @option -n | --dry-run Optional. Print each command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @arg $1 string branch: Branch name to check out before tagging.
# @arg $2 string tag: Annotated tag name/version to create (e.g. v1.2.3).
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::tag::create "main" "v1.0.0"
#   shell::git::tag::create -n "release/1.0" "v1.0.0"
#
shell::git::tag::create() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Checkout a branch, create and push an annotated tag, restore original branch, then notify via Telegram"
		shell::logger::usage "shell::git::tag::create [-n] [-h] <branch> <tag>"
		shell::logger::item "branch" "Branch name to check out before tagging"
		shell::logger::item "tag" "Annotated tag name/version to create (e.g. v1.2.3)"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::example "shell::git::tag::create \"main\" \"v1.0.0\""
		shell::logger::example "shell::git::tag::create -n \"release/1.0\" \"v1.0.0\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local branch="$1"
	local tag="$2"

	if [ -z "$branch" ]; then
		shell::logger::error "Branch name is required"
		return $RETURN_INVALID
	fi

	if [ -z "$tag" ]; then
		shell::logger::error "Tag version is required"
		return $RETURN_INVALID
	fi

	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	if [ -z "$current_branch" ]; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# ---------------------------------------------------------------------------
	# Command variables — all git commands declared upfront for easy review.
	# ---------------------------------------------------------------------------
	local cmd_checkout="git checkout \"${branch}\""
	local cmd_tag_push="git push origin \"${tag}\""
	local cmd_tag_restore="git checkout \"${current_branch}\""

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_checkout"
		shell::logger::command_clip "git tag -a \"${tag}\" -m \"<release_message>\""
		shell::logger::command_clip "$cmd_tag_push"
		shell::logger::command_clip "$cmd_tag_restore"
		return $RETURN_SUCCESS
	fi

	# Step 1 — switch to target branch.
	shell::logger::assert "$cmd_checkout" \
		"Checked out branch '${branch}'" "Branch checkout aborted" || return $?

	# Step 2 — collect commit metadata for the tag annotation.
	local current_commit
	local commit_author
	local commit_date

	current_commit=$(git rev-parse --short HEAD 2>/dev/null)
	commit_author=$(git log -1 --format='%an' 2>/dev/null)
	commit_date=$(git log -1 --format='%ad' --date=format:'%Y-%m-%d %H:%M:%S' 2>/dev/null)

	# Step 3 — build release message and create annotated tag.
	local release_message="Release ${tag} | Branch: ${branch} | Commit: ${current_commit} | Author: ${commit_author} | Date: ${commit_date}"
	local cmd_tag="git tag -a \"${tag}\" -m \"${release_message}\""

	shell::logger::assert "$cmd_tag" \
		"Tag '${tag}' created on '${branch}' at ${current_commit}" "Tag creation aborted" || return $?

	# Step 4 — push tag to origin.
	shell::logger::assert "$cmd_tag_push" \
		"Tag '${tag}' pushed to origin" "Tag push aborted" || return $?

	# Step 5 — restore original branch.
	shell::logger::assert "$cmd_tag_restore" \
		"Restored original branch '${current_branch}'" "Branch restore aborted" || return $?

	# Step 6 — send Telegram activity notification.
	local telegram_message="Branch: ${branch} | Commit: ${current_commit} | Author: ${commit_author} | Date: ${commit_date} | Tag ${tag} has been successfully created and pushed."
	shell::git::telegram::history::send "${telegram_message}"

	return $RETURN_SUCCESS
}

# @description Deletes an annotated or lightweight Git tag both locally and on the remote
#   origin, then sends a Telegram activity notification.
#
#   1. git tag -d <tag>                    — delete the tag locally
#   2. git push origin :refs/tags/<tag>    — delete the tag on origin
#   3. shell::git::telegram::history::send — send Telegram notification
# @option -n | --dry-run Optional. Print each command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @arg $1 string tag: The tag name/version to delete (e.g. v1.2.3).
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::tag::remove "v1.0.0"
#   shell::git::tag::remove -n "v1.0.0"
#
shell::git::tag::remove() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Delete a Git tag locally and on origin, then notify via Telegram"
		shell::logger::usage "shell::git::tag::remove [-n] [-h] <tag>"
		shell::logger::item "tag" "Tag name/version to delete (e.g. v1.2.3)"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::example "shell::git::tag::remove \"v1.0.0\""
		shell::logger::example "shell::git::tag::remove -n \"v1.0.0\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local tag="$1"

	if [ -z "$tag" ]; then
		shell::logger::error "Tag name is required"
		return $RETURN_INVALID
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# ---------------------------------------------------------------------------
	# Command variables — all git commands declared upfront for easy review.
	# ---------------------------------------------------------------------------
	local cmd_delete_local="git tag -d \"${tag}\""
	local cmd_delete_remote="git push origin \":refs/tags/${tag}\""

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_delete_local"
		shell::logger::command_clip "$cmd_delete_remote"
		return $RETURN_SUCCESS
	fi

	# Step 1 — delete the tag locally.
	shell::logger::assert "$cmd_delete_local" \
		"Tag '${tag}' deleted locally" "Local tag delete aborted" || return $?

	# Step 2 — delete the tag on origin.
	shell::logger::assert "$cmd_delete_remote" \
		"Tag '${tag}' deleted on origin" "Remote tag delete aborted" || return $?

	# Step 3 — send Telegram activity notification.
	shell::git::telegram::history::send "Tag ${tag} has been removed from local and origin."

	return $RETURN_SUCCESS
}

# @description Checks out a specific Git tag into a detached HEAD state. Optionally creates
#   a new branch from the tag. Supports dry-run mode.
#
#   Step 1 — Verify the tag exists locally or on origin.
#   Step 2 — If -b is provided, run: git checkout -b <branch_name> <tag>
#   Otherwise, run: git checkout <tag>
#   Step 3 — Log the result via shell::logger::assert.
#
#   Safety notes:
#   • When -b is omitted, HEAD enters detached state at the tag commit.
#   Run 'git checkout <branch>' or 'git switch -' to return to a branch.
#   • When -b is provided, the new branch is created at the tag commit and
#   checked out immediately (no detached HEAD).
#   • Tags are immutable references; checking out a tag directly is read-only.
# @option -n | --dry-run Optional. Print the command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @option -b | --branch Optional. Create and checkout a new branch from the tag instead of detached HEAD.
# @arg $1 string tag: Required. The tag name/version to checkout (e.g. v1.2.3).
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::tag::checkout "v1.0.0"
#   shell::git::tag::checkout -b "release-1.0" "v1.0.0"
#   shell::git::tag::checkout -n "v1.0.0"
#
shell::git::tag::checkout() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Checkout a specific Git tag (detached HEAD or new branch)"
		shell::logger::usage "shell::git::tag::checkout [-n] [-h] [-b <branch_name>] <tag>"
		shell::logger::item "tag" "Tag name/version to checkout (e.g. v1.2.3)"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-b, --branch <name>" "Create and checkout a new branch from the tag"
		shell::logger::example "shell::git::tag::checkout \"v1.0.0\""
		shell::logger::example "shell::git::tag::checkout -b \"release-1.0\" \"v1.0.0\""
		shell::logger::example "shell::git::tag::checkout -n \"v1.0.0\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local branch_name=""
	if [ "$1" = "-b" ] || [ "$1" = "--branch" ]; then
		branch_name="$2"
		shift 2
	fi

	local tag="$1"

	if [ -z "$tag" ]; then
		shell::logger::error "Tag name is required"
		return $RETURN_INVALID
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# Step 1 — verify the tag exists locally or on origin.
	local tag_exists="false"
	if git rev-parse --verify --quiet "refs/tags/${tag}" >/dev/null 2>&1; then
		tag_exists="true"
	elif git ls-remote --tags origin "refs/tags/${tag}" >/dev/null 2>&1; then
		tag_exists="true"
	fi

	if [ "$tag_exists" = "false" ]; then
		shell::logger::error "Tag '${tag}' does not exist locally or on origin"
		return $RETURN_FAILURE
	fi

	# Resolve the commit hash for logging.
	local commit_hash
	commit_hash=$(git rev-list -n 1 "${tag}" 2>/dev/null)

	# Build the checkout command.
	local cmd_checkout
	if [ -n "$branch_name" ]; then
		cmd_checkout="git checkout -b \"${branch_name}\" \"${tag}\""
	else
		cmd_checkout="git checkout \"${tag}\""
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_checkout"
		return $RETURN_SUCCESS
	fi

	# Execute checkout.
	if [ -n "$branch_name" ]; then
		shell::logger::assert "$cmd_checkout" "Created and checked out branch '${branch_name}' from tag ${tag} (${commit_hash:0:8})" "Tag checkout aborted" || return $?
	else
		shell::logger::assert "$cmd_checkout" "Checked out tag ${tag} (${commit_hash:0:8}) — detached HEAD" "Tag checkout aborted" || return $?
	fi

	return $RETURN_SUCCESS
}

# @description Presents a picker of all Git tags (local + remote) with origin markers,
#   then checks out the selected tag via shell::git::tag::checkout.
#   Optionally creates a new branch from the selected tag.
#
#   Step 1 — Verify the git repository.
#   Step 2 — Collect all local tags and remote tags from origin.
#   Step 3 — Build display lines with origin markers:
#   [LOCAL  ] : <tag>  — exists only locally
#   [REMOTE ] : <tag>  — exists only on origin
#   [BOTH   ] : <tag>  — exists on both local and origin
#   Step 4 — Present a single-select picker via shell::ask::option.
#   Step 5 — Extract the tag name from the selection using the ' : ' separator.
#   Step 6 — Forward to shell::git::tag::checkout with the extracted tag name.
#   If -b was provided, the branch name is forwarded as well.
# @option -n | --dry-run Optional. After selection, print the checkout command via shell::logger::command_clip instead of executing it.
# @option -h | --help Show this help message.
# @option -b | --branch Optional. Create and checkout a new branch from the selected tag instead of detached HEAD.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::tag::checkout::fzf
#   shell::git::tag::checkout::fzf -b "release-1.0"
#   shell::git::tag::checkout::fzf -n
#
shell::git::tag::checkout::fzf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Select a tag via fzf and check it out"
		shell::logger::usage "shell::git::tag::checkout::fzf [-n] [-h] [-b <branch_name>]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the checkout command instead of executing it"
		shell::logger::option "-b, --branch <name>" "Create and checkout a new branch from the selected tag"
		shell::logger::example "shell::git::tag::checkout::fzf"
		shell::logger::example "shell::git::tag::checkout::fzf -b \"release-1.0\""
		shell::logger::example "shell::git::tag::checkout::fzf -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local branch_name=""
	if [ "$1" = "-b" ] || [ "$1" = "--branch" ]; then
		branch_name="$2"
		shift 2
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# ---------------------------------------------------------------------------
	# Collect local and remote tags.
	# ---------------------------------------------------------------------------
	local -a local_tags
	while IFS= read -r t; do
		[ -n "$t" ] && local_tags+=("$t")
	done < <(git tag -l 2>/dev/null | sort -u)

	local -a remote_tags
	while IFS= read -r t; do
		[ -n "$t" ] && remote_tags+=("$t")
	done < <(git ls-remote --tags origin 2>/dev/null | awk '{print $2}' | sed 's|refs/tags/||' | sort -u)

	# ---------------------------------------------------------------------------
	# Build display lines with origin markers.
	#
	# Format: "[LABEL     ] : tag_name"
	#   LABEL — printf-padded to 9 chars:
	#             [%-9s]  (1 + 9 + 1 = 11)
	#   ' : ' — field separator; ':' is prohibited in git tag names so this
	#             token is a safe extraction anchor.
	# ---------------------------------------------------------------------------
	local -a tag_lines
	local t
	local label
	local is_local
	local is_remote
	local local_label="$(printf "[%-9s]" "LOCAL")"
	local remote_label="$(printf "[%-9s]" "REMOTE")"
	local both_label="$(printf "[%-9s]" "BOTH")"

	# Process local tags first.
	for t in "${local_tags[@]}"; do
		is_remote="false"
		for rt in "${remote_tags[@]}"; do
			[ "$t" = "$rt" ] && {
				is_remote="true"
				break
			}
		done
		if [ "$is_remote" = "true" ]; then
			label="$both_label"
		else
			label="$local_label"
		fi
		tag_lines+=("${label} : ${t}")
	done

	# Add remote-only tags (tags on origin with no local counterpart).
	for rt in "${remote_tags[@]}"; do
		is_local="false"
		for t in "${local_tags[@]}"; do
			[ "$t" = "$rt" ] && {
				is_local="true"
				break
			}
		done
		if [ "$is_local" = "false" ]; then
			tag_lines+=("${remote_label} : ${rt}")
		fi
	done

	if [ "${#tag_lines[@]}" -eq 0 ]; then
		shell::logger::warn "No tags found in this repository — aborting"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 4 — single-select tag picker.
	# ---------------------------------------------------------------------------
	local selected_output
	selected_output=$(shell::ask::option "${tag_lines[@]}")

	if [ -z "$selected_output" ]; then
		shell::logger::warn "No tag selected — aborting"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 5 — extract tag name from the selection.
	#
	# The ' : ' separator (colon is prohibited in git ref names) followed by
	# non-space chars uniquely identifies the tag name.
	# ---------------------------------------------------------------------------
	local selected_tag
	selected_tag=$(printf '%s' "$selected_output" | grep -oE ': [^ ]+' | sed 's/: //')

	if [ -z "$selected_tag" ]; then
		shell::logger::warn "Could not extract tag name from selection — aborting"
		return $RETURN_SUCCESS
	fi

	shell::logger::info "Selected tag: ${selected_tag}"

	# Step 6 — forward to shell::git::tag::checkout with the extracted tag.
	if [ "$dry_run" = "true" ]; then
		if [ -n "$branch_name" ]; then
			shell::git::tag::checkout -n -b "$branch_name" "$selected_tag"
		else
			shell::git::tag::checkout -n "$selected_tag"
		fi
	else
		if [ -n "$branch_name" ]; then
			shell::git::tag::checkout -b "$branch_name" "$selected_tag"
		else
			shell::git::tag::checkout "$selected_tag"
		fi
	fi

	return $RETURN_SUCCESS
}

# @description Displays all Git tags in the repository, both local and remote, with origin
#   markers and associated commit metadata.
#
#   Collects all local tags and remote tags from origin, deduplicates them,
#   and prints a formatted table showing:
#   • Tag name
#   • Origin marker: [LOCAL] | [REMOTE] | [BOTH]
#   • Commit hash (short)
#   • Commit date
#   • Commit message (first line)
#   • Tagger name (for annotated tags) or author (for lightweight tags)
# @option -n | --dry-run Optional. Print the git commands via shell::logger::command_clip instead of executing them.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::tag::all
#   shell::git::tag::all -n
#
shell::git::tag::all() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Display all local and remote tags with metadata"
		shell::logger::usage "shell::git::tag::all [-n] [-h]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::example "shell::git::tag::all"
		shell::logger::example "shell::git::tag::all -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# ---------------------------------------------------------------------------
	# Command variables — declared upfront for dry-run printing.
	# ---------------------------------------------------------------------------
	local cmd_local_tags="git tag -l"
	local cmd_remote_tags="git ls-remote --tags origin"

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_local_tags"
		shell::logger::command_clip "$cmd_remote_tags"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Collect local and remote tags.
	# ---------------------------------------------------------------------------
	local -a local_tags
	while IFS= read -r t; do
		[ -n "$t" ] && local_tags+=("$t")
	done < <(git tag -l 2>/dev/null | sort -u)

	local -a remote_tags
	while IFS= read -r t; do
		[ -n "$t" ] && remote_tags+=("$t")
	done < <(git ls-remote --tags origin 2>/dev/null | awk '{print $2}' | sed 's|refs/tags/||' | sort -u)

	# ---------------------------------------------------------------------------
	# Build a unified tag list with origin markers.
	# ---------------------------------------------------------------------------
	local -a all_tags
	local t
	local is_remote
	local origin_marker
	local commit_hash
	local commit_date
	local commit_msg
	local tagger_name

	# Process local tags.
	for t in "${local_tags[@]}"; do
		is_remote="false"
		for rt in "${remote_tags[@]}"; do
			[ "$t" = "$rt" ] && {
				is_remote="true"
				break
			}
		done
		if [ "$is_remote" = "true" ]; then
			origin_marker="BOTH"
		else
			origin_marker="LOCAL"
		fi
		all_tags+=("${t}:${origin_marker}")
	done

	# Add remote-only tags.
	for rt in "${remote_tags[@]}"; do
		is_local="false"
		for t in "${local_tags[@]}"; do
			[ "$t" = "$rt" ] && {
				is_local="true"
				break
			}
		done
		if [ "$is_local" = "false" ]; then
			all_tags+=("${rt}:REMOTE")
		fi
	done

	if [ "${#all_tags[@]}" -eq 0 ]; then
		shell::logger::warn "No tags found in this repository"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Print formatted table.
	# ---------------------------------------------------------------------------
	local _lw=14 # label column width for printf alignment
	local _hr="  ════════════════════════════════════════════════════════════════════════════════════════"

	shell::logger::info ""
	shell::logger::info "${_hr}"
	shell::logger::info "  GIT TAGS  ·  $(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"
	shell::logger::info "${_hr}"
	shell::logger::info ""
	shell::logger::info "  $(printf '%-20s %-10s %-12s %-20s %-30s %s' "Tag" "Origin" "Commit" "Date" "Message" "Tagger")"
	shell::logger::info "  $(printf '%-20s %-10s %-12s %-20s %-30s %s' "----" "------" "------" "----" "-------" "------")"

	local entry
	local tag_name
	local marker
	for entry in "${all_tags[@]}"; do
		tag_name="${entry%%:*}"
		marker="${entry##*:}"

		# Get commit metadata for the tag.
		commit_hash=$(git rev-list -n 1 "${tag_name}" 2>/dev/null | cut -c1-12)
		commit_date=$(git log -1 --format='%ad' --date=format:'%Y-%m-%d %H:%M' "${tag_name}" 2>/dev/null)
		commit_msg=$(git log -1 --format='%s' "${tag_name}" 2>/dev/null)

		# Truncate commit message to 30 chars for alignment.
		if [ "${#commit_msg}" -gt 30 ]; then
			commit_msg="${commit_msg:0:27}..."
		fi

		# Try to get tagger for annotated tags, fallback to author for lightweight tags.
		tagger_name=$(git for-each-ref --format='%(taggername)' "refs/tags/${tag_name}" 2>/dev/null)
		if [ -z "$tagger_name" ]; then
			tagger_name=$(git log -1 --format='%an' "${tag_name}" 2>/dev/null)
		fi
		# Truncate tagger name to 20 chars.
		if [ "${#tagger_name}" -gt 20 ]; then
			tagger_name="${tagger_name:0:17}..."
		fi

		shell::logger::info "  $(printf '%-20s %-10s %-12s %-20s %-30s %s' "${tag_name}" "${marker}" "${commit_hash}" "${commit_date}" "${commit_msg}" "${tagger_name}")"
	done

	shell::logger::info ""
	shell::logger::info "${_hr}"
	shell::logger::info "  Total: ${#all_tags[@]} tags"
	shell::logger::info "${_hr}"
	shell::logger::info ""

	return $RETURN_SUCCESS
}

# @description Presents a picker of all Git tags (local + remote) with origin markers,
#   then removes the selected tag via shell::git::tag::remove.
#
#   Step 1 — Verify the git repository.
#   Step 2 — Collect all local tags and remote tags from origin.
#   Step 3 — Build display lines with origin markers:
#   [LOCAL  ] : <tag>  — exists only locally
#   [REMOTE ] : <tag>  — exists only on origin
#   [BOTH   ] : <tag>  — exists on both local and origin
#   Step 4 — Present a single-select picker via shell::ask::option.
#   Step 5 — Extract the tag name from the selection using the ' : ' separator.
#   Step 6 — Confirm removal with the user.
#   Step 7 — Forward to shell::git::tag::remove with the extracted tag name.
# @option -n | --dry-run Optional. After selection, print the remove commands via shell::logger::command_clip instead of executing them.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::tag::remove::fzf
#   shell::git::tag::remove::fzf -n
#
shell::git::tag::remove::fzf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Select a tag via fzf and remove it from local and origin"
		shell::logger::usage "shell::git::tag::remove::fzf [-n] [-h]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the remove commands instead of executing them"
		shell::logger::example "shell::git::tag::remove::fzf"
		shell::logger::example "shell::git::tag::remove::fzf -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# ---------------------------------------------------------------------------
	# Collect local and remote tags.
	# ---------------------------------------------------------------------------
	local -a local_tags
	while IFS= read -r t; do
		[ -n "$t" ] && local_tags+=("$t")
	done < <(git tag -l 2>/dev/null | sort -u)

	local -a remote_tags
	while IFS= read -r t; do
		[ -n "$t" ] && remote_tags+=("$t")
	done < <(git ls-remote --tags origin 2>/dev/null | awk '{print $2}' | sed 's|refs/tags/||' | sort -u)

	# ---------------------------------------------------------------------------
	# Build display lines with origin markers.
	# ---------------------------------------------------------------------------
	local -a tag_lines
	local t
	local label
	local is_local
	local is_remote
	local local_label="$(printf "[%-9s]" "LOCAL")"
	local remote_label="$(printf "[%-9s]" "REMOTE")"
	local both_label="$(printf "[%-9s]" "BOTH")"

	# Process local tags.
	for t in "${local_tags[@]}"; do
		is_remote="false"
		for rt in "${remote_tags[@]}"; do
			[ "$t" = "$rt" ] && {
				is_remote="true"
				break
			}
		done
		if [ "$is_remote" = "true" ]; then
			label="$both_label"
		else
			label="$local_label"
		fi
		tag_lines+=("${label} : ${t}")
	done

	# Add remote-only tags.
	for rt in "${remote_tags[@]}"; do
		is_local="false"
		for t in "${local_tags[@]}"; do
			[ "$t" = "$rt" ] && {
				is_local="true"
				break
			}
		done
		if [ "$is_local" = "false" ]; then
			tag_lines+=("${remote_label} : ${rt}")
		fi
	done

	if [ "${#tag_lines[@]}" -eq 0 ]; then
		shell::logger::warn "No tags found in this repository — aborting"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 4 — single-select tag picker.
	# ---------------------------------------------------------------------------
	local selected_output
	selected_output=$(shell::ask::option "${tag_lines[@]}")

	if [ -z "$selected_output" ]; then
		shell::logger::warn "No tag selected — aborting"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 5 — extract tag name from the selection.
	# ---------------------------------------------------------------------------
	local selected_tag
	selected_tag=$(printf '%s' "$selected_output" | grep -oE ': [^ ]+' | sed 's/: //')

	if [ -z "$selected_tag" ]; then
		shell::logger::warn "Could not extract tag name from selection — aborting"
		return $RETURN_SUCCESS
	fi

	shell::logger::warn "Selected tag for removal: ${selected_tag}"

	# Step 6 — confirm removal.
	if shell::ask::deny "Remove tag '${selected_tag}' from local and origin?"; then
		shell::logger::info "Tag removal aborted"
		return $RETURN_SUCCESS
	fi

	# Step 7 — forward to shell::git::tag::remove with the extracted tag.
	if [ "$dry_run" = "true" ]; then
		shell::git::tag::remove -n "$selected_tag"
	else
		shell::git::tag::remove "$selected_tag"
	fi

	return $RETURN_SUCCESS
}

# @description Presents a multi-select picker of all commits across all refs in the repository,
#   then shows an action menu to revert the selected commits with various strategies.
#   Supports creating a new revert branch, handling conflicts, and pushing to remote.
#
#   Step 1 — Verify the git repository.
#   Step 2 — Build a coloured commit list via git log --all covering all local
#   branches, remote-tracking branches, and tags.
#   Step 3 — Present a multi-select picker (TAB to mark multiple commits).
#   Step 4 — Extract 40-char hex hashes from the selection.
#   Step 5 — Build a revert branch name: rev/<YYYYMMDD.HHMMSS>.<sanitized-source>
#   Step 6 — Present an action menu with revert strategies:
#   • Revert commits (auto-commit)         — git revert <hash1> <hash2> ...
#   • Revert commits (no-commit)           — git revert -n <hash1> <hash2> ...
#   • Revert merge commit (-m 1)           — git revert -m 1 <merge-hash>
#   • Revert range (oldest..newest)        — git revert <old>..<new>
#   • Revert with custom message           — git revert --edit <hash1> ...
#   • Revert quietly (no editor)           — git revert --no-edit <hash1> ...
#   Step 7 — Create revert branch, execute revert, handle conflicts.
#   Step 8 — Prompt: commit to local / push to remote / both.
#   Step 9 — Execute chosen action and send Telegram notification.
#
#   Branch naming pattern:
#   rev/<YYYYMMDD.HHMMSS>.<sanitized-source>
#   <sanitized-source> is derived from current branch or first commit hash.
# @option -n | --dry-run Optional. Print the commands via shell::logger::command_clip instead of executing them.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::commit::revert::fzf
#   shell::git::commit::revert::fzf -n
#
shell::git::commit::revert::fzf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Multi-select commits via fzf and revert them with professional strategies"
		shell::logger::usage "shell::git::commit::revert::fzf [-n] [-h]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::example "shell::git::commit::revert::fzf"
		shell::logger::example "shell::git::commit::revert::fzf -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	local repository_path
	local repository_name
	local git_username
	local server_remote_url
	local notify_timestamp

	repository_path=$(git rev-parse --show-toplevel 2>/dev/null)
	repository_name=$(basename "${repository_path}")
	git_username=$(git config user.name 2>/dev/null)
	server_remote_url=$(git config --get remote.origin.url 2>/dev/null)
	notify_timestamp=$(date "+%Y-%m-%d %H:%M:%S")

	# ---------------------------------------------------------------------------
	# Step 1 — Build coloured commit list via git log --all.
	# ---------------------------------------------------------------------------
	local log_format="%C(bold blue)%H (%h)%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%an%C(reset)%C(bold yellow)%d%C(reset) %C(dim white)- %s%C(reset)"

	local -a commit_lines
	while IFS= read -r line; do
		commit_lines+=("$line")
	done < <(git log --format=format:"${log_format}" --all --color=always 2>/dev/null)

	if [ "${#commit_lines[@]}" -eq 0 ]; then
		shell::logger::warn "No commits found in repository — aborting"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 2 — Multi-select commit picker (TAB to mark multiple entries).
	# ---------------------------------------------------------------------------
	local selected_output
	selected_output=$(shell::ask::options "${commit_lines[@]}")

	if [ -z "$selected_output" ]; then
		shell::logger::warn "No commits selected — aborting"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 3 — Extract 40-char hex hashes from selection.
	# ---------------------------------------------------------------------------
	local -a selected_hashes
	while IFS= read -r h; do
		[ -n "$h" ] && selected_hashes+=("$h")
	done < <(printf '%s' "$selected_output" | grep -oE '[0-9a-f]{40}')

	if [ "${#selected_hashes[@]}" -eq 0 ]; then
		shell::logger::warn "No valid commit hashes extracted — aborting"
		return $RETURN_SUCCESS
	fi

	local count="${#selected_hashes[@]}"
	local hash_word="commit"
	[ "${count}" -gt 1 ] && hash_word="commits"

	shell::logger::info "Selected ${count} ${hash_word}:"
	local h subj
	for h in "${selected_hashes[@]}"; do
		subj=$(git log -1 --format='%s' "$h" 2>/dev/null)
		shell::logger::info "  • ${h:0:8}  ${subj}"
	done

	# ---------------------------------------------------------------------------
	# Step 4 — Build revert branch name.
	# Pattern: rev/<YYYYMMDD.HHMMSS>.<sanitized-source>
	# ---------------------------------------------------------------------------
	local timestamp
	timestamp=$(date +"%Y%m%d.%H%M%S")

	local sanitized_source
	if [ -n "$current_branch" ] && [ "$current_branch" != "HEAD" ]; then
		sanitized_source=$(printf '%s' "${current_branch}" | sed 's|/|--|g')
	else
		# Fallback to first selected commit short hash
		# Cross-shell: iterate and break after first element
		local first_hash
		for first_hash in "${selected_hashes[@]}"; do break; done
		sanitized_source=$(printf '%s' "${first_hash}" | cut -c1-7)
	fi

	local revert_branch="rev/${timestamp}.${sanitized_source}"

	shell::logger::info "Revert branch will be: ${revert_branch}"

	# ---------------------------------------------------------------------------
	# Step 5 — Detect if any selected commit is a merge commit.
	# A merge commit has more than one parent (format '%P' outputs space-separated parents).
	# ---------------------------------------------------------------------------
	local has_merge="false"
	local merge_hashes=""
	for h in "${selected_hashes[@]}"; do
		local parents
		parents=$(git log -1 --format='%P' "$h" 2>/dev/null)
		if [ -n "$parents" ] && echo "$parents" | grep -q ' '; then
			has_merge="true"
			merge_hashes="${merge_hashes}${h} "
		fi
	done

	if [ "$has_merge" = "true" ]; then
		shell::logger::warn "Merge commits detected in selection — merge revert requires -m flag"
	fi

	# ---------------------------------------------------------------------------
	# Step 6 — Build revert action menu.
	#
	# Action keys:
	#   revert_auto       — git revert <hash1> <hash2> ... (auto-commit, may open editor)
	#   revert_no_commit  — git revert -n <hash1> <hash2> ... (apply changes, no commit)
	#   revert_no_edit    — git revert --no-edit <hash1> ... (auto-commit, skip editor)
	#   revert_edit       — git revert --edit <hash1> ... (force open editor)
	#   revert_merge_m1   — git revert -m 1 <merge-hash> (mainline parent = 1)
	#   revert_range      — git revert <oldest>..<newest> (range revert)
	#   revert_quiet      — git revert -q <hash1> ... (silent mode)
	# ---------------------------------------------------------------------------
	local -a action_options=(
		"Revert selected commits (auto-commit, default):revert_auto"
		"Revert selected commits without creating commit (stage only):revert_no_commit"
		"Revert selected commits quietly — skip editor prompt:revert_no_edit"
		"Revert selected commits with custom message — open editor:revert_edit"
		"Revert merge commit using mainline parent 1 (-m 1):revert_merge_m1"
		"Revert as a range (oldest..newest, single commit):revert_range"
		"Revert in silent mode (reduce output):revert_quiet"
	)

	local action
	action=$(shell::ask::option::value "${action_options[@]}")

	if [ -z "$action" ]; then
		shell::logger::info "No revert action selected — aborting"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 7 — Build the revert command based on selected action.
	# ---------------------------------------------------------------------------
	local cmd_revert=""
	local revert_description=""

	case "$action" in
	revert_auto)
		cmd_revert="git revert ${selected_hashes[*]}"
		revert_description="Reverted ${count} ${hash_word} (auto-commit)"
		;;
	revert_no_commit)
		cmd_revert="git revert -n ${selected_hashes[*]}"
		revert_description="Reverted ${count} ${hash_word} (staged, no commit)"
		;;
	revert_no_edit)
		cmd_revert="git revert --no-edit ${selected_hashes[*]}"
		revert_description="Reverted ${count} ${hash_word} (auto-commit, no editor)"
		;;
	revert_edit)
		cmd_revert="git revert --edit ${selected_hashes[*]}"
		revert_description="Reverted ${count} ${hash_word} (custom message via editor)"
		;;
	revert_merge_m1)
		if [ "$has_merge" = "false" ]; then
			shell::logger::warn "No merge commits in selection — falling back to standard revert"
			cmd_revert="git revert ${selected_hashes[*]}"
			revert_description="Reverted ${count} ${hash_word} (auto-commit, fallback from merge)"
		else
			# Use the first merge hash for -m 1 revert
			local first_merge
			first_merge=$(printf '%s' "$merge_hashes" | awk '{print $1}')
			cmd_revert="git revert -m 1 ${first_merge}"
			revert_description="Reverted merge commit ${first_merge:0:8} (mainline parent 1)"
		fi
		;;
	revert_range)
		if [ "${count}" -lt 2 ]; then
			shell::logger::warn "Range revert requires at least 2 commits — falling back to standard revert"
			cmd_revert="git revert ${selected_hashes[*]}"
			revert_description="Reverted ${count} ${hash_word} (auto-commit, fallback from range)"
		else
			# Hashes are newest-first from git log; range needs oldest..newest
			# Cross-shell: iterate to find first and last elements
			local first_h last_h tmp_h
			first_h=""
			last_h=""
			for tmp_h in "${selected_hashes[@]}"; do
				if [ -z "$first_h" ]; then
					first_h="${tmp_h}"
				fi
				last_h="${tmp_h}"
			done
			# first_h = newest (first in git log order), last_h = oldest (last in git log order)
			# Range syntax: git revert <oldest>..<newest> reverts everything AFTER oldest up to newest
			cmd_revert="git revert ${last_h}..${first_h}"
			revert_description="Reverted range ${last_h:0:8}..${first_h:0:8}"
		fi
		;;
	revert_quiet)
		cmd_revert="git revert -q ${selected_hashes[*]}"
		revert_description="Reverted ${count} ${hash_word} (quiet mode)"
		;;
	esac

	# ---------------------------------------------------------------------------
	# Step 8 — Confirm and execute.
	# ---------------------------------------------------------------------------
	shell::logger::info "Revert strategy: ${action}"
	shell::logger::info "Command: ${cmd_revert}"

	# shell::ask::deny returns 1 for YES, 0 for NO
	# So: if confirmz; then → true (0) = NO chosen → abort
	#     if confirmz; then → false (1) = YES chosen → continue
	if shell::ask::deny "Proceed with revert on new branch '${revert_branch}'?"; then
		shell::logger::info "Revert aborted"
		return $RETURN_SUCCESS
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "git checkout -b \"${revert_branch}\""
		shell::logger::command_clip "$cmd_revert"
		shell::logger::command_clip "git status  # check for conflicts"
		shell::logger::command_clip "git revert --abort  # if needed"
		shell::logger::command_clip "git revert --continue  # after resolving conflicts"
		return $RETURN_SUCCESS
	fi

	# Create revert branch from current branch.
	local cmd_create_branch="git checkout -b \"${revert_branch}\""
	shell::logger::assert "$cmd_create_branch" \
		"Created revert branch '${revert_branch}'" \
		"Failed to create revert branch" || return $?

	# Execute revert.
	shell::logger::info "Executing revert..."
	if ! eval "$cmd_revert"; then
		shell::logger::error "Revert failed — conflicts may have occurred"
		shell::logger::info "Options:"
		shell::logger::info "  • Resolve conflicts, then run: git revert --continue"
		shell::logger::info "  • Abort the revert and return to original state: git revert --abort"
		shell::logger::info "  • Skip the conflicting commit: git revert --skip"
		shell::logger::info "Current branch: ${revert_branch}"
		return $RETURN_FAILURE
	fi

	shell::logger::success "${revert_description}"

	# ---------------------------------------------------------------------------
	# Step 9 — Prompt where to apply: local / remote / both.
	# ---------------------------------------------------------------------------
	local -a apply_options=(
		"Commit to local only (no push):local"
		"Push to remote origin (with upstream):remote"
		"Commit locally AND push to remote:both"
	)

	local apply_action
	apply_action=$(shell::ask::option::value "${apply_options[@]}")

	if [ -z "$apply_action" ] || [ "$apply_action" = "local" ]; then
		shell::logger::info "Revert committed locally on branch '${revert_branch}'"
		shell::clipboard::copy --best-effort "${revert_branch}"
	elif [ "$apply_action" = "remote" ] || [ "$apply_action" = "both" ]; then
		local cmd_push="git push -u origin \"${revert_branch}\""
		shell::logger::assert "$cmd_push" \
			"Revert branch '${revert_branch}' pushed to origin" \
			"Push failed — run 'git push -u origin ${revert_branch}' manually" || return $?
	fi

	if [ "$apply_action" = "both" ]; then
		shell::clipboard::copy --best-effort "${revert_branch}"
	fi

	# ---------------------------------------------------------------------------
	# Step 10 — Send Telegram notification.
	# ---------------------------------------------------------------------------
	local telegram_message="Revert Executed | branch: ${revert_branch} | strategy: ${action} | ${revert_description} | repository: ${repository_name} (${server_remote_url}) | username: ${git_username} | timestamp: ${notify_timestamp}"
	shell::git::telegram::history::send "${telegram_message}"

	# ---------------------------------------------------------------------------
	# Step 11 — Offer to return to original branch.
	# ---------------------------------------------------------------------------
	if [ "$current_branch" != "$revert_branch" ] && [ -n "$current_branch" ]; then
		if shell::ask::deny "Return to original branch '${current_branch}'?"; then
			# User answered NO (return 0) → stay on revert branch
			:
		else
			# User answered YES (return 1) → return to original branch
			local cmd_return="git checkout \"${current_branch}\""
			shell::logger::assert "$cmd_return" \
				"Returned to original branch '${current_branch}'" \
				"Failed to return to original branch" || return $?
		fi
	fi

	return $RETURN_SUCCESS
}

# @description Interactive commit history browser: selects a commit via fzf, then loops
#   through view-action picks until the user explicitly chooses Exit.
#
#   Step 1 — Verify git repository and resolve target branch.
#   Step 2 — Build a coloured commit list (full 40-char hash per entry).
#   Step 3 — Present commit picker via shell::ask::option (fzf wrapper).
#   Step 4 — Extract 40-char commit hash from the selected line.
#   Step 5 — Collect commit metadata (author, date, subject).
#   Step 6-7 (loop) — Repeatedly present view-action picker via
#   shell::ask::option::value, render the selected view in a tmux
#   display-popup (90 × 90 %) or less, then return to the picker.
#   Available actions:
#   • diff          — full git show (what changed in this commit)
#   • blame         — git blame per file at this commit (who wrote each line)
#   • file_history  — git log --follow -p per file (full change history)
#   • stat          — files changed with line-count stats only
#   • exit          — leave the view loop and return to the terminal
#   Step 8 — Log commit info and copy to clipboard via shell::clipboard::copy.
# @option -n | --dry-run Optional. Print the git log command instead of executing.
# @option -h | --help Show this help message.
# @arg $1 string branch: Optional. Branch to inspect. Defaults to current branch.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::commit::spec::history::fzf
#   shell::git::commit::spec::history::fzf "feature/my-branch"
#   shell::git::commit::spec::history::fzf -n
#
shell::git::commit::spec::history::fzf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactive commit history browser — select commit via fzf, view details in tmux popup"
		shell::logger::usage "shell::git::commit::spec::history::fzf [-n] [-h] [<branch>]"
		shell::logger::item "branch" "Branch to inspect. Defaults to current branch."
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the git log command instead of executing"
		shell::logger::example "shell::git::commit::spec::history::fzf"
		shell::logger::example "shell::git::commit::spec::history::fzf \"feature/my-branch\""
		shell::logger::example "shell::git::commit::spec::history::fzf -n"
		shell::logger::info ""
		shell::logger::info "View actions (selected after picking a commit):"
		shell::logger::info "  diff          Full diff — what changed in this commit (git show)"
		shell::logger::info "  blame         Per-file blame — who wrote each line at this commit"
		shell::logger::info "  file_history  Per-file change history with diffs (git log --follow -p)"
		shell::logger::info "  stat          Files changed with +/- line counts only"
		shell::logger::info "  exit          Leave the view loop and return to the terminal"
		shell::logger::info ""
		shell::logger::info "Inside the tmux popup / less pager:"
		shell::logger::info "  j / k         Scroll line by line"
		shell::logger::info "  d / u         Scroll half page"
		shell::logger::info "  /pattern      Search forward"
		shell::logger::info "  n / N         Next / previous search result"
		shell::logger::info "  g / G         Go to top / bottom"
		shell::logger::info "  q             Close and return"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# ---------------------------------------------------------------------------
	# Step 1 — Resolve target branch.
	# ---------------------------------------------------------------------------
	local target_branch="${1:-}"
	if [ -z "$target_branch" ]; then
		target_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
	fi

	if ! git rev-parse --verify --quiet "refs/heads/${target_branch}" >/dev/null 2>&1 &&
		! git rev-parse --verify --quiet "refs/remotes/origin/${target_branch}" >/dev/null 2>&1; then
		shell::logger::error "Branch '${target_branch}' does not exist locally or on origin"
		return $RETURN_INVALID
	fi

	# ---------------------------------------------------------------------------
	# Step 2 — Build coloured commit list.
	# ---------------------------------------------------------------------------
	shell::dependency::fzf::ensure >/dev/null 2>&1

	local log_format="%C(bold blue)%H (%h)%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%an%C(reset)%C(bold yellow)%d%C(reset) %C(dim white)- %s%C(reset)"
	local -a commit_lines
	while IFS= read -r line; do
		commit_lines+=("$line")
	done < <(git log --format=format:"${log_format}" --color=always "${target_branch}" 2>/dev/null)

	if [ "${#commit_lines[@]}" -eq 0 ]; then
		shell::logger::warn "No commits found on branch '${target_branch}' — aborting"
		return $RETURN_SUCCESS
	fi

	shell::logger::info "Loaded ${#commit_lines[@]} commits from '${target_branch}'"

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "git log --format=format:\"${log_format}\" --color=always \"${target_branch}\" | fzf --ansi"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 3 — Commit picker via shell::ask::option (fzf wrapper).
	# ---------------------------------------------------------------------------
	local selected_line
	selected_line=$(shell::ask::option "${commit_lines[@]}")

	if [ -z "$selected_line" ]; then
		shell::logger::warn "No commit selected — aborting"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 4 — Extract 40-char commit hash.
	# ---------------------------------------------------------------------------
	local commit_hash
	commit_hash=$(printf '%s' "$selected_line" | grep -oE '[0-9a-f]{40}' | head -1)

	if [ -z "$commit_hash" ]; then
		shell::logger::warn "Could not extract commit hash from selection — aborting"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 5 — Collect commit metadata.
	# ---------------------------------------------------------------------------
	local commit_subject commit_author commit_author_email commit_date
	commit_subject=$(git log -1 --format='%s' "$commit_hash" 2>/dev/null)
	commit_author=$(git log -1 --format='%an' "$commit_hash" 2>/dev/null)
	commit_author_email=$(git log -1 --format='%ae' "$commit_hash" 2>/dev/null)
	commit_date=$(git log -1 --format='%ad' --date=format:'%Y-%m-%d %H:%M:%S' "$commit_hash" 2>/dev/null)

	local repo_path repo_name
	repo_path=$(git rev-parse --show-toplevel 2>/dev/null)
	repo_name=$(basename "${repo_path}")

	local has_delta="false"
	shell::command::exists delta && has_delta="true"

	shell::logger::info "Selected: ${commit_hash:0:12}  ${commit_subject}"
	shell::logger::info "Author  : ${commit_author} <${commit_author_email}>"
	shell::logger::info "Date    : ${commit_date}"

	# ---------------------------------------------------------------------------
	# Steps 6–7 (loop) — Action picker → render view → repeat until Exit.
	# ---------------------------------------------------------------------------
	local -a action_options=(
		"View full diff — what changed in this commit (git show):diff"
		"View blame — who wrote each line at this commit (git blame per file):blame"
		"View file history — full change log with diffs per file (git log --follow -p):file_history"
		"View stat — files changed with +/- line counts only:stat"
		"Exit — return to terminal:exit"
	)

	while true; do
		local action
		action=$(shell::ask::option::value "${action_options[@]}")

		# Empty selection (ESC) or explicit exit → leave the loop.
		if [ -z "$action" ] || [ "$action" = "exit" ]; then
			shell::logger::info "Exiting commit viewer"
			break
		fi

		# Build content into a tmpfile.
		local tmpfile
		tmpfile=$(mktemp 2>/dev/null || mktemp -t 'git_hist_view')

		# Common header.
		{
			printf "\033[1;36m══════════════════════════════════════════════════════════════\033[0m\n"
			printf "\033[1;33m  Commit:  \033[0m%s\n" "${commit_hash:0:12}  —  ${commit_subject}"
			printf "\033[1;33m  Author:  \033[0m%s <%s>\n" "${commit_author}" "${commit_author_email}"
			printf "\033[1;33m  Date:    \033[0m%s\n" "${commit_date}"
			printf "\033[1;33m  Branch:  \033[0m%s\n" "${target_branch}"
			printf "\033[1;33m  Repo:    \033[0m%s\n" "${repo_name}"
			printf "\033[1;36m══════════════════════════════════════════════════════════════\033[0m\n\n"
		} >"$tmpfile"

		case "$action" in
		# -------------------------------------------------------------------
		diff)
			if [ "$has_delta" = "true" ]; then
				git show --color=always "$commit_hash" 2>/dev/null |
					delta --no-gitconfig --line-numbers --navigate --dark 2>/dev/null \
						>>"$tmpfile" ||
					git show --color=always "$commit_hash" 2>/dev/null >>"$tmpfile"
			else
				git show --color=always "$commit_hash" 2>/dev/null >>"$tmpfile"
			fi
			;;

		# -------------------------------------------------------------------
		blame)
			local -a changed_files_blame
			while IFS= read -r f; do
				[ -n "$f" ] && changed_files_blame+=("$f")
			done < <(git diff-tree --no-commit-id --name-only -r "$commit_hash" 2>/dev/null)

			if [ "${#changed_files_blame[@]}" -eq 0 ]; then
				printf "  (no files changed in this commit)\n" >>"$tmpfile"
			else
				printf "\033[1;35m  Files changed: %d\033[0m\n\n" "${#changed_files_blame[@]}" >>"$tmpfile"
				local f_blame
				for f_blame in "${changed_files_blame[@]}"; do
					{
						printf "\033[1;34m────────────────────────────────────────────────────────────\033[0m\n"
						printf "\033[1;33m  %-6s %s\033[0m\n" "File:" "$f_blame"
						printf "\033[1;34m────────────────────────────────────────────────────────────\033[0m\n"
						git blame --date=short -c "${commit_hash}" -- "$f_blame" 2>/dev/null ||
							printf "  (blame not available for this file at this commit)\n"
						printf "\n"
					} >>"$tmpfile"
				done
			fi
			;;

		# -------------------------------------------------------------------
		file_history)
			local -a changed_files_hist
			while IFS= read -r f; do
				[ -n "$f" ] && changed_files_hist+=("$f")
			done < <(git diff-tree --no-commit-id --name-only -r "$commit_hash" 2>/dev/null)

			if [ "${#changed_files_hist[@]}" -eq 0 ]; then
				printf "  (no files changed in this commit)\n" >>"$tmpfile"
			else
				printf "\033[1;35m  Files changed: %d\033[0m\n\n" "${#changed_files_hist[@]}" >>"$tmpfile"
				local f_hist hist_fmt
				hist_fmt="%C(bold blue)%H (%h)%C(reset) %C(bold green)%ad%C(reset) %C(white)%an%C(reset) - %s"
				for f_hist in "${changed_files_hist[@]}"; do
					{
						printf "\033[1;34m────────────────────────────────────────────────────────────\033[0m\n"
						printf "\033[1;33m  History: %s\033[0m\n" "$f_hist"
						printf "\033[1;34m────────────────────────────────────────────────────────────\033[0m\n"
						git log --color=always --follow -p \
							--format="${hist_fmt}" \
							--date=format:'%Y-%m-%d %H:%M:%S' \
							-- "$f_hist" 2>/dev/null ||
							printf "  (history not available for this file)\n"
						printf "\n"
					} >>"$tmpfile"
				done
			fi
			;;

		# -------------------------------------------------------------------
		stat)
			git show --stat --color=always "$commit_hash" 2>/dev/null >>"$tmpfile"
			;;
		esac

		# Show in tmux display-popup (blocking with -E) or fall back to less.
		if [ -n "${TMUX:-}" ] && shell::command::exists tmux; then
			tmux display-popup -E \
				-d "#{pane_current_path}" \
				-w "90%" -h "90%" -xC -yC \
				"less -R '${tmpfile}'"
		else
			less -R "$tmpfile"
		fi
		rm -f "$tmpfile" 2>/dev/null
	done

	# ---------------------------------------------------------------------------
	# Step 8 — Log summary and copy to clipboard.
	# ---------------------------------------------------------------------------
	local notify_message="Hash: ${commit_hash} | Subject: ${commit_subject} | Author: ${commit_author} | Date: ${commit_date} | Branch: ${target_branch} | Repository: ${repo_name}"
	shell::logger::info "${notify_message}"
	shell::clipboard::copy --best-effort "${notify_message}"

	return $RETURN_SUCCESS
}

# @description Convenience wrapper around shell::git::commit::spec::history::fzf that
#   automatically detects the currently checked-out branch and opens the
#   interactive commit history viewer for it.
# @option -n | --dry-run Optional. Print the commands instead of executing them.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::git::commit::spec::history::fzf::current
#   shell::git::commit::spec::history::fzf::current -n
#
shell::git::commit::spec::history::fzf::current() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Open interactive commit history viewer for the currently checked-out branch"
		shell::logger::usage "shell::git::commit::spec::history::fzf::current [-n] [-h]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::example "shell::git::commit::spec::history::fzf::current"
		shell::logger::example "shell::git::commit::spec::history::fzf::current -n"
		return $RETURN_SUCCESS
	fi

	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	if [ -z "$current_branch" ]; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		shell::git::commit::spec::history::fzf -n "${current_branch}"
	else
		shell::git::commit::spec::history::fzf "${current_branch}"
	fi
}

# @internal
# @description Percent-encode a URL path, keeping `/` as the separator.
#   Letters, digits and `. _ ~ -` stay as they are; every other byte (space,
#   `#`, `?`, `%`, `&`, non-ASCII ...) becomes `%XX`. A branch such as
#   `feature/a b#1` therefore stays one valid path.
# @arg $1 string Path to encode.
# @stdout The encoded path, without a trailing newline.
# @exitcode 0 Always.
# @example
#   shell::git::open::encode_path "feature/a b#1"   # feature/a%20b%231
#
shell::git::open::encode_path() {
	printf '%s' "${1-}" | LC_ALL=C awk '
		BEGIN { for (i = 1; i < 256; i++) hex[sprintf("%c", i)] = sprintf("%%%02X", i) }
		{
			n = length($0)
			out = ""
			for (j = 1; j <= n; j++) {
				c = substr($0, j, 1)
				if (c ~ /[A-Za-z0-9._~\/-]/) out = out c
				else out = out hex[c]
			}
			printf "%s", out
		}'
}

# @internal
# @description Turn a git remote URL into the base URL of its web page.
#   Understands the scp-like form (`git@host:owner/repo.git`) and the
#   `https://`, `http://`, `ssh://`, `git://` forms. The result never contains
#   credentials (`user:token@` is dropped), the `.git` suffix or a trailing
#   slash; ssh and git remotes become `https://`, an explicit http(s) port is
#   kept, an ssh port is dropped. The host must be plain (`a-z 0-9 . -`) and the
#   path is percent-encoded, so the URL is safe to hand to a browser opener.
#   SSH config aliases of the form `github.com-work` map back to `github.com`.
# @arg $1 string Remote URL.
# @stdout The web base URL, e.g. `https://github.com/owner/repo`.
# @exitcode 0 A web URL was produced.
# @exitcode 1 The remote is not a web-hostable URL (local path, `file://`, empty ...).
# @example
#   shell::git::open::web_base "git@github.com:owner/repo.git"   # https://github.com/owner/repo
#
shell::git::open::web_base() {
	local url="${1-}"
	local web_scheme="https" authority="" host="" port="" repo_path=""
	local scheme rest before

	if [ -z "$url" ]; then
		return 1
	fi

	case "$url" in
	*://*)
		scheme="${url%%://*}"
		rest="${url#*://}"
		case "$scheme" in
		http | https | ssh | git | git+ssh | ssh+git) ;;
		*) return 1 ;;
		esac
		authority="${rest%%/*}"
		if [ "$rest" = "$authority" ]; then
			return 1
		fi
		repo_path="${rest#*/}"
		authority="${authority##*@}"
		case "$authority" in
		*:*)
			host="${authority%%:*}"
			port="${authority#*:}"
			;;
		*) host="$authority" ;;
		esac
		case "$scheme" in
		http | https) web_scheme="$scheme" ;;
		*) port="" ;;
		esac
		;;
	/* | ./* | ../* | [A-Za-z]:*) return 1 ;;
	*:*)
		before="${url%%:*}"
		case "$before" in
		*/*) return 1 ;;
		esac
		host="${before##*@}"
		repo_path="${url#*:}"
		;;
	*) return 1 ;;
	esac

	host="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')"
	case "$host" in
	github.com-*) host="github.com" ;;
	gitlab.com-*) host="gitlab.com" ;;
	bitbucket.org-*) host="bitbucket.org" ;;
	esac
	case "$host" in
	'' | *[!a-z0-9.-]* | -* | .*) return 1 ;;
	esac
	case "$port" in
	*[!0-9]*) return 1 ;;
	esac

	repo_path="${repo_path#/}"
	repo_path="${repo_path%/}"
	repo_path="${repo_path%.git}"
	repo_path="${repo_path%/}"
	if [ -z "$repo_path" ]; then
		return 1
	fi

	if [ -n "$port" ]; then
		host="$host:$port"
	fi
	printf '%s://%s/%s\n' "$web_scheme" "$host" "$(shell::git::open::encode_path "$repo_path")"
}

# @internal
# @description Name the hosting provider of a web base URL.
#   Taken from the host (`github`, `gitlab`, `bitbucket` anywhere in it, so
#   GitHub Enterprise and self-hosted GitLab work). When the host gives no hint,
#   `git config shell.provider <github|gitlab|bitbucket>` decides.
# @arg $1 string Web base URL (from shell::git::open::web_base).
# @stdout `github`, `gitlab` or `bitbucket`.
# @exitcode 0 The provider is known.
# @exitcode 1 Unknown provider (or an invalid `shell.provider` value).
# @example
#   shell::git::open::provider "https://gitlab.example.com/group/repo"   # gitlab
#
shell::git::open::provider() {
	local host="${1-}"
	host="${host#*://}"
	host="${host%%/*}"
	host="${host%%:*}"

	local override
	override="$(git config --get shell.provider 2>/dev/null)"
	case "$override" in
	github | gitlab | bitbucket)
		printf '%s\n' "$override"
		return 0
		;;
	'') ;;
	*) return 1 ;;
	esac

	case "$host" in
	*github*) printf 'github\n' ;;
	*gitlab*) printf 'gitlab\n' ;;
	*bitbucket*) printf 'bitbucket\n' ;;
	*) return 1 ;;
	esac
}

# @internal
# @description Build the web URL of a repository, a branch or a commit.
#
#   | Provider  | Branch            | Commit             |
#   |-----------|-------------------|--------------------|
#   | github    | `/tree/<branch>`  | `/commit/<sha>`    |
#   | gitlab    | `/-/tree/<branch>`| `/-/commit/<sha>`  |
#   | bitbucket | `/src/<branch>`   | `/commits/<sha>`   |
# @arg $1 string Provider: github, gitlab or bitbucket.
# @arg $2 string Web base URL.
# @arg $3 string Kind: repo, branch or commit.
# @arg $4 string Branch name or commit hash (not used for `repo`).
# @stdout The URL.
# @exitcode 0 URL printed.
# @exitcode 1 Unknown provider or kind.
# @example
#   shell::git::open::url github "https://github.com/o/r" branch feature/x
#
shell::git::open::url() {
	local provider="${1-}" base="${2-}" kind="${3-}" ref="${4-}"
	local encoded=""
	if [ "$kind" = "branch" ]; then
		encoded="$(shell::git::open::encode_path "$ref")"
	else
		encoded="$ref"
	fi

	case "$kind" in
	repo) printf '%s\n' "$base" ;;
	branch)
		case "$provider" in
		github) printf '%s/tree/%s\n' "$base" "$encoded" ;;
		gitlab) printf '%s/-/tree/%s\n' "$base" "$encoded" ;;
		bitbucket) printf '%s/src/%s\n' "$base" "$encoded" ;;
		*) return 1 ;;
		esac
		;;
	commit)
		case "$provider" in
		github) printf '%s/commit/%s\n' "$base" "$encoded" ;;
		gitlab) printf '%s/-/commit/%s\n' "$base" "$encoded" ;;
		bitbucket) printf '%s/commits/%s\n' "$base" "$encoded" ;;
		*) return 1 ;;
		esac
		;;
	*) return 1 ;;
	esac
}

# @internal
# @description Choose which git remote to open.
#   Order: the explicit name, then (for a branch) the remote it tracks, then
#   `origin`, then the only remote. Fails when none applies.
# @arg $1 string Explicit remote name (may be empty).
# @arg $2 string Branch whose tracked remote is preferred (may be empty).
# @stdout The remote name.
# @stderr The reason when no remote can be chosen.
# @exitcode 0 A remote was chosen.
# @exitcode 1 No remote, an unknown remote, or several remotes and no `origin`.
# @example
#   remote="$(shell::git::open::remote "" "$branch")"
#
shell::git::open::remote() {
	local wanted="${1-}" branch="${2-}"
	local remotes tracked count

	remotes="$(git remote 2>/dev/null)"
	if [ -z "$remotes" ]; then
		shell::logger::error "This repository has no remote configured"
		return 1
	fi

	if [ -n "$wanted" ]; then
		if printf '%s\n' "$remotes" | grep -Fxq -- "$wanted"; then
			printf '%s\n' "$wanted"
			return 0
		fi
		shell::logger::error "Unknown remote: $wanted"
		return 1
	fi

	if [ -n "$branch" ]; then
		tracked="$(git config --get "branch.$branch.remote" 2>/dev/null)"
		if [ -n "$tracked" ] && [ "$tracked" != "." ] && printf '%s\n' "$remotes" | grep -Fxq -- "$tracked"; then
			printf '%s\n' "$tracked"
			return 0
		fi
	fi

	if printf '%s\n' "$remotes" | grep -Fxq -- "origin"; then
		printf 'origin\n'
		return 0
	fi

	count="$(printf '%s\n' "$remotes" | wc -l | tr -d ' ')"
	if [ "$count" = "1" ]; then
		printf '%s\n' "$remotes"
		return 0
	fi

	shell::logger::error "Several remotes and none is named origin; choose one with --remote"
	return 1
}

# @description Opens the current repository, branch, or specific commit in the web browser.
#
#   Step 1 — Detect the remote provider (GitHub, GitLab, Bitbucket) from the
#   remote URL. SSH and HTTPS remotes both work; credentials in the URL are
#   never copied, `.git` is dropped and SSH config aliases such as
#   `github.com-work` are mapped back to `github.com`.
#   Step 2 — Determine the target from the argument: the repository (default),
#   the current branch (its upstream branch name when it differs), or any
#   commit-ish (a hash, a short hash, a tag, `HEAD~2` ...), resolved to a full hash.
#   Step 3 — Construct the correct web URL for that provider.
#   Step 4 — Open it with shell::net::open_url (`open` on macOS, `xdg-open`
#   on Linux, `wslview` / `explorer.exe` on WSL).
#
#   A warning is printed when the branch or commit is not on the remote yet,
#   because the page would answer 404 until it is pushed. For a self-hosted
#   server whose host name does not contain github, gitlab or bitbucket, run
#   `git config shell.provider <github|gitlab|bitbucket>` once. Bitbucket
#   Server / Data Center uses different URLs and is not supported.
# @option -h | --help Show this help message.
# @option -n | --dry-run Print the open command instead of running it.
# @option -p | --print Print the URL on stdout and do not open it.
# @option -r | --remote Remote to use (default: the branch's tracked remote, then origin, then the only remote).
# @arg $1 string target: Optional. "repo" (default), "branch", or a specific commit hash (any commit-ish).
# @stdout With --print: the URL.
# @exitcode 0 Success.
# @exitcode 1 The operation failed (not a repository, no usable remote, unknown provider, invalid commit, detached HEAD for "branch").
# @exitcode 2 Invalid usage.
# @exitcode 3 No URL opener is installed.
# @exitcode 4 Unsupported operating system for opening a browser.
# @see shell::net::open_url
# @example
#   shell::git::open::browser
#   shell::git::open::browser branch
#   shell::git::open::browser HEAD~2
#   shell::git::open::browser --print a1b2c3d
#   shell::git::open::browser -r upstream branch
#
shell::git::open::browser() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Open the repository, current branch or a commit in the web browser"
		shell::logger::usage "shell::git::open::browser [-n] [-p] [-r <remote>] [repo|branch|<commit>]"
		shell::logger::item "repo" "The repository page (default)"
		shell::logger::item "branch" "The current branch"
		shell::logger::item "<commit>" "A hash, short hash, tag or HEAD~2"
		shell::logger::option "-n, --dry-run" "Print the open command instead of running it"
		shell::logger::option "-p, --print" "Print the URL and do not open it"
		shell::logger::option "-r, --remote <name>" "Remote to use (default: tracked remote, origin, or the only one)"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::example "shell::git::open::browser"
		shell::logger::example "shell::git::open::browser branch"
		shell::logger::example "shell::git::open::browser HEAD~2"
		shell::logger::example "shell::git::open::browser --print a1b2c3d"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" print_only="false" remote="" target=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		-p | --print)
			print_only="true"
			shift
			;;
		-r | --remote)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			remote="$2"
			shift 2
			;;
		--remote=*)
			remote="${1#*=}"
			shift
			;;
		-*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*)
			if [ -n "$target" ]; then
				shell::logger::error "Only one target is accepted (got '$target' and '$1')"
				return "$RETURN_INVALID"
			fi
			target="$1"
			shift
			;;
		esac
	done
	target="${target:-repo}"

	case "$remote" in
	-*)
		shell::logger::error "Invalid remote name: $remote"
		return "$RETURN_INVALID"
		;;
	esac

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return "$RETURN_FAILURE"
	fi

	# Step 2 — what to open.
	local kind="repo" branch="" sha=""
	case "$target" in
	repo) kind="repo" ;;
	branch)
		branch="$(git symbolic-ref --short -q HEAD 2>/dev/null)"
		if [ -z "$branch" ]; then
			shell::logger::error "HEAD is detached; pass a commit hash instead of 'branch'"
			return "$RETURN_FAILURE"
		fi
		kind="branch"
		;;
	-*)
		shell::logger::error "Invalid target: $target"
		return "$RETURN_INVALID"
		;;
	*)
		if ! sha="$(git rev-parse --verify --quiet "${target}^{commit}" 2>/dev/null)"; then
			shell::logger::error "Not a valid commit: $target"
			return "$RETURN_FAILURE"
		fi
		kind="commit"
		;;
	esac

	# Step 1 — remote and provider.
	local remote_name remote_url base provider
	remote_name="$(shell::git::open::remote "$remote" "$branch")" || return "$RETURN_FAILURE"

	remote_url="$(git remote get-url "$remote_name" 2>/dev/null)"
	if [ -z "$remote_url" ]; then
		remote_url="$(git config --get "remote.$remote_name.url" 2>/dev/null)"
	fi

	if ! base="$(shell::git::open::web_base "$remote_url")"; then
		shell::logger::error "Remote '$remote_name' is not a web-hostable URL (local path or unsupported scheme)"
		return "$RETURN_FAILURE"
	fi

	if ! provider="$(shell::git::open::provider "$base")"; then
		local web_host="${base#*://}"
		web_host="${web_host%%/*}"
		shell::logger::error "Unknown provider for '$web_host'; run: git config shell.provider <github|gitlab|bitbucket>"
		return "$RETURN_FAILURE"
	fi

	# Step 3 — the ref and the URL.
	local ref="$sha"
	if [ "$kind" = "branch" ]; then
		ref="$branch"
		local tracked_remote merge_ref
		tracked_remote="$(git config --get "branch.$branch.remote" 2>/dev/null)"
		merge_ref="$(git config --get "branch.$branch.merge" 2>/dev/null)"
		if [ "$tracked_remote" = "$remote_name" ] && [ -n "$merge_ref" ]; then
			ref="${merge_ref#refs/heads/}"
		fi
		if ! git rev-parse --verify --quiet "refs/remotes/$remote_name/$ref" >/dev/null 2>&1; then
			shell::logger::warn "Branch '$ref' is not on remote '$remote_name' yet; the page may not exist until you push"
		fi
	elif [ "$kind" = "commit" ]; then
		if [ -z "$(git for-each-ref --contains "$sha" --count=1 --format='%(refname)' "refs/remotes/$remote_name" 2>/dev/null)" ]; then
			shell::logger::warn "Commit $(printf '%.7s' "$sha") is not on remote '$remote_name' yet; the page may not exist until you push"
		fi
	fi

	local url
	url="$(shell::git::open::url "$provider" "$base" "$kind" "$ref")" || return "$RETURN_FAILURE"

	if [ "$print_only" = "true" ]; then
		printf '%s\n' "$url"
		return "$RETURN_SUCCESS"
	fi

	# Step 4 — open it.
	if [ "$dry_run" = "true" ]; then
		shell::net::open_url -n "$url"
		return $?
	fi

	shell::logger::info "Opening $url"
	shell::net::open_url "$url"
}

# @internal
# @description Check that the repository is in a state where squashing is safe.
#   Squashing is `git reset --soft` followed by `git commit`, so it refuses to
#   start when that could lose or mix up work:
#   - not inside a repository, or the repository has no commit;
#   - detached HEAD (the new commit would belong to no branch);
#   - a merge, cherry-pick, revert, bisect or rebase is in progress;
#   - there are staged changes (they would be silently folded into the squash).
#   Unstaged edits and untracked files are fine: the soft reset leaves them alone.
# @stderr The reason when the state is not safe.
# @exitcode 0 Safe to squash.
# @exitcode 1 Not safe (the reason is printed).
# @example
#   shell::git::commit::squash::preflight || return $?
#
shell::git::commit::squash::preflight() {
	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return "$RETURN_FAILURE"
	fi
	if ! git rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
		shell::logger::error "This repository has no commits yet"
		return "$RETURN_FAILURE"
	fi
	if ! git symbolic-ref -q HEAD >/dev/null 2>&1; then
		shell::logger::error "HEAD is detached; check out a branch before squashing"
		return "$RETURN_FAILURE"
	fi

	local marker
	for marker in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG rebase-merge rebase-apply; do
		if [ -e "$(git rev-parse --git-path "$marker")" ]; then
			shell::logger::error "A ${marker} operation is in progress; finish or abort it first"
			return "$RETURN_FAILURE"
		fi
	done

	if ! git diff --cached --quiet 2>/dev/null; then
		shell::logger::error "There are staged changes; commit or unstage them first (they would be folded into the squash)"
		return "$RETURN_FAILURE"
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Build the "combined" message for a squash.
#   The full message of the base commit (the one the others are squashed into),
#   then a blank line and one `- <subject>` line per commit folded into it,
#   oldest first. The base message keeps its own type and scope, so a
#   Conventional Commits header stays valid.
# @arg $1 string Hash of the base (oldest) commit.
# @stdout The message (ends with a newline).
# @exitcode 0 Always.
# @example
#   shell::git::commit::squash::message "$base_hash"
#
shell::git::commit::squash::message() {
	local base="${1-}" body folded
	body="$(git log -1 --format=%B "$base" 2>/dev/null)"
	folded="$(git log --first-parent --reverse --format='- %s' "$base..HEAD" 2>/dev/null)"

	if [ -n "$folded" ]; then
		printf '%s\n\n%s\n' "$body" "$folded"
	else
		printf '%s\n' "$body"
	fi
}

# @internal
# @description Put the branch back where it was after a failed squash commit.
#   A soft reset to the old HEAD keeps the index and the working tree as they
#   are. When the squash started from the root commit (no parent), the branch
#   reference was deleted, so it is recreated instead.
# @arg $1 string The HEAD hash before the squash.
# @arg $2 string The base commit's parent (empty for a root commit).
# @stderr A warning, or an error when restoring fails.
# @exitcode 0 History restored.
# @exitcode 1 Restoring failed (the hash is printed so it can be done by hand).
# @example
#   shell::git::commit::squash::restore "$old_head" "$parent_hash"
#
shell::git::commit::squash::restore() {
	local old_head="${1-}" parent="${2-}"

	if [ -n "$parent" ]; then
		git reset --soft "$old_head" >/dev/null 2>&1
	else
		git update-ref HEAD "$old_head" >/dev/null 2>&1
	fi

	if [ "$(git rev-parse HEAD 2>/dev/null)" = "$old_head" ]; then
		shell::logger::warn "The original history was restored (HEAD is back at ${old_head})"
		return "$RETURN_SUCCESS"
	fi
	shell::logger::error "Could not restore automatically; run: git reset --soft ${old_head}"
	return "$RETURN_FAILURE"
}

# @description Interactively squashes multiple recent commits into a single commit.
#
#   Step 1 — Fetch the last N commits (default 20) using `git log --oneline`
#   (first-parent history, so the list matches what is squashed).
#   Step 2 — Present an fzf picker to select the "base" commit (the oldest
#   commit to squash into). HEAD itself cannot be the base: squashing needs at
#   least two commits.
#   Step 3 — Choose the message: the combined messages (the base message plus a
#   bullet per folded commit), a new one-line message, or the combined messages
#   opened in your editor. Review the plan and confirm.
#   Step 4 — Perform a soft reset to the parent of the selected base commit:
#   `git reset --soft <hash>^` (a base that is the root commit is handled with
#   `git update-ref -d HEAD`, since it has no parent).
#   Step 5 — Create the new squashed commit with `git commit -F <message file>`.
#
#   Nothing is changed until you confirm, so cancelling at any point leaves the
#   repository untouched; every menu has a "← Back" entry (and the text prompt
#   accepts `:back`). If the commit then fails (a hook rejects it, no identity,
#   an empty message), the original history is restored automatically. On
#   success the previous HEAD is printed so the squash can be undone with
#   `git reset --soft <hash>`.
#
#   It refuses to start on a detached HEAD, during a merge/rebase/cherry-pick,
#   or with staged changes. It warns when the range contains merge commits
#   (their side branches are flattened) or commits already on the upstream
#   branch (a `git push --force-with-lease` will be needed; this function never
#   pushes).
# @option -n | --dry-run Optional. Print planned git commands instead of executing.
# @option -c | --count Optional. Number of recent commits to list (default 20, minimum 2).
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed or canceled.
# @exitcode 2 Invalid usage (bad option or --count).
# @see shell::ask::option::back
# @see shell::git::commit::input
# @example
#   shell::git::commit::squash::fzf
#   shell::git::commit::squash::fzf -n
#   shell::git::commit::squash::fzf --count 50
#
shell::git::commit::squash::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively squash recent commits into a single commit"
		shell::logger::usage "shell::git::commit::squash::fzf [-n] [-c <count>] [-h]"
		shell::logger::option "-n, --dry-run" "Print the planned git commands instead of executing them"
		shell::logger::option "-c, --count <N>" "Number of recent commits to list (default 20, minimum 2)"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::note "Nothing changes until you confirm. Pick '$SHELL_FZF_BACK_LABEL' (or type :back) to go back a step."
		shell::logger::example "shell::git::commit::squash::fzf"
		shell::logger::example "shell::git::commit::squash::fzf -n"
		shell::logger::example "shell::git::commit::squash::fzf --count 50"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" count="20"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		-c | --count)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			count="$2"
			shift 2
			;;
		--count=*)
			count="${1#*=}"
			shift
			;;
		*)
			shell::logger::error "Unknown option or argument: $1"
			return "$RETURN_INVALID"
			;;
		esac
	done

	case "$count" in
	'' | *[!0-9]*)
		shell::logger::error "--count must be a whole number (got '$count')"
		return "$RETURN_INVALID"
		;;
	esac
	if [ "$count" -lt 2 ]; then
		shell::logger::error "--count must be at least 2 (got '$count')"
		return "$RETURN_INVALID"
	fi

	shell::git::commit::squash::preflight || return "$RETURN_FAILURE"

	if [ "$(git rev-list --first-parent --count HEAD 2>/dev/null)" -lt 2 ]; then
		shell::logger::error "Squashing needs at least two commits on this branch"
		return "$RETURN_FAILURE"
	fi

	# Declared once, before the loop: re-declaring a local inside a loop prints
	# its value in zsh.
	local -a lines=()
	local line step choice value rc
	local base_hash parent_hash range n_commits merge_count
	local message="" custom_message="" use_editor="false"
	local upstream published branch old_head msg_file new_head

	# ---------------------------------------------------------------------------
	# Step 1 — the last N commits (first-parent history).
	# ---------------------------------------------------------------------------
	while IFS= read -r line; do
		lines+=("$line")
	done < <(git log --oneline --first-parent -n "$count" 2>/dev/null)

	branch="$(git symbolic-ref --short -q HEAD 2>/dev/null)"
	old_head="$(git rev-parse HEAD 2>/dev/null)"

	# ---------------------------------------------------------------------------
	# Steps 2-3 — pick the base, the message, and confirm (each step can go back).
	# ---------------------------------------------------------------------------
	step="base"
	while true; do
		case "$step" in
		base)
			choice="$(shell::ask::option::back --prompt "Squash into (oldest commit to include): " "${lines[@]}")"
			rc=$?
			if [ "$rc" -ne 0 ] || [ -z "$choice" ]; then
				shell::logger::warn "Squash cancelled — nothing was changed"
				return "$RETURN_FAILURE"
			fi

			base_hash="$(git rev-parse --verify --quiet "${choice%% *}^{commit}" 2>/dev/null)"
			if [ -z "$base_hash" ]; then
				shell::logger::error "Could not resolve the selected commit: ${choice%% *}"
				return "$RETURN_FAILURE"
			fi

			if parent_hash="$(git rev-parse --verify --quiet "${base_hash}^" 2>/dev/null)"; then
				range="${parent_hash}..HEAD"
			else
				parent_hash=""
				range="HEAD"
			fi
			n_commits="$(git rev-list --first-parent --count "$range" 2>/dev/null)"

			if [ "${n_commits:-0}" -lt 2 ]; then
				shell::logger::warn "That is the latest commit; pick an older one (squashing needs at least two commits)"
				continue
			fi
			step="message"
			;;

		message)
			shell::logger::info "These ${n_commits} commits will become one:"
			git log --first-parent --format='  • %h %s' "$range" 2>/dev/null

			choice="$(shell::ask::option::back --prompt "Commit message: " \
				"Combined messages" "Write a new message" "Edit combined messages in my editor")"
			rc=$?
			case "$rc" in
			0) ;;
			"$RETURN_BACK")
				step="base"
				continue
				;;
			*)
				shell::logger::warn "Squash cancelled — nothing was changed"
				return "$RETURN_FAILURE"
				;;
			esac

			case "$choice" in
			"Combined messages")
				message="$(shell::git::commit::squash::message "$base_hash")"
				use_editor="false"
				step="confirm"
				;;
			"Edit combined messages in my editor")
				message="$(shell::git::commit::squash::message "$base_hash")"
				use_editor="true"
				step="confirm"
				;;
			"Write a new message")
				value="$(shell::git::commit::input "Enter the new commit message" "$custom_message")"
				rc=$?
				case "$rc" in
				0)
					custom_message="$value"
					message="$value"
					use_editor="false"
					step="confirm"
					;;
				"$RETURN_BACK") ;;
				*)
					shell::logger::warn "Squash cancelled — nothing was changed"
					return "$RETURN_FAILURE"
					;;
				esac
				;;
			esac
			;;

		confirm)
			merge_count="$(git rev-list --first-parent --merges --count "$range" 2>/dev/null)"
			published=""
			upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)"
			if [ -n "$upstream" ] && git merge-base --is-ancestor "$base_hash" "$upstream" 2>/dev/null; then
				published="$upstream"
			fi

			shell::logger::info "Plan: squash ${n_commits} commits on '${branch}' into one"
			if [ "${merge_count:-0}" -gt 0 ]; then
				shell::logger::warn "The range contains ${merge_count} merge commit(s); their side branches are flattened"
			fi
			if [ -n "$published" ]; then
				shell::logger::warn "Some of these commits are already on ${published}; you will need a force push afterwards"
			fi
			if [ "$use_editor" = "true" ]; then
				shell::logger::info "The message will open in your editor. Draft:"
			else
				shell::logger::info "New commit message:"
			fi
			printf '%s\n' "$message" | sed 's/^/    /'

			choice="$(shell::ask::option::back --prompt "Squash ${n_commits} commits? " "Squash" "Abort")"
			rc=$?
			case "$rc" in
			0)
				if [ "$choice" = "Squash" ]; then
					break
				fi
				shell::logger::info "Squash aborted — nothing was changed"
				return "$RETURN_FAILURE"
				;;
			"$RETURN_BACK") step="message" ;;
			*)
				shell::logger::info "Squash aborted — nothing was changed"
				return "$RETURN_FAILURE"
				;;
			esac
			;;
		esac
	done

	# ---------------------------------------------------------------------------
	# Step 4 — soft reset to the parent of the base commit.
	# ---------------------------------------------------------------------------
	if [ "$dry_run" = "true" ]; then
		if [ -n "$parent_hash" ]; then
			shell::exec::command -n git reset --soft "$parent_hash"
		else
			shell::exec::command -n git update-ref -d HEAD
		fi
		if [ "$use_editor" = "true" ]; then
			shell::logger::command_clip "git commit -e -m $(printf '%q' "$message")"
		else
			shell::logger::command_clip "git commit -m $(printf '%q' "$message")"
		fi
		return "$RETURN_SUCCESS"
	fi

	if [ -n "$parent_hash" ]; then
		shell::exec::command git reset --soft "$parent_hash" || {
			shell::logger::error "git reset failed — nothing was changed"
			return "$RETURN_FAILURE"
		}
	else
		shell::exec::command git update-ref -d HEAD || {
			shell::logger::error "git update-ref failed — nothing was changed"
			return "$RETURN_FAILURE"
		}
	fi

	# ---------------------------------------------------------------------------
	# Step 5 — commit. The message goes through a file (-F), so quotes, $ and
	# newlines are never re-parsed by a shell.
	# ---------------------------------------------------------------------------
	msg_file="$(mktemp "$(shell::os::temp_dir)/squash-msg.XXXXXX")" || msg_file=""
	if [ -z "$msg_file" ]; then
		shell::logger::error "Could not create a temporary file for the message"
		shell::git::commit::squash::restore "$old_head" "$parent_hash"
		return "$RETURN_FAILURE"
	fi
	printf '%s\n' "$message" >"$msg_file"

	if [ "$use_editor" = "true" ]; then
		shell::exec::command git commit -e -F "$msg_file"
	else
		shell::exec::command git commit -F "$msg_file"
	fi
	rc=$?
	rm -f "$msg_file"

	if [ "$rc" -ne 0 ]; then
		shell::logger::error "The commit failed (hook, identity or empty message)"
		shell::git::commit::squash::restore "$old_head" "$parent_hash"
		return "$RETURN_FAILURE"
	fi

	new_head="$(git rev-parse --short HEAD 2>/dev/null)"
	shell::logger::success "Squashed ${n_commits} commits into ${new_head}"
	shell::logger::info "Previous HEAD: ${old_head} (undo with: git reset --soft ${old_head})"
	if [ -n "$published" ]; then
		shell::logger::warn "History was rewritten; update the remote with: git push --force-with-lease"
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Work out where an amended branch must be pushed.
#   The remote and branch the current branch tracks (the upstream branch name
#   may differ from the local one); without an upstream, `origin` (or the only
#   remote) and the local branch name.
# @arg $1 string The local branch name.
# @stdout Two lines: the remote name, then the branch name on that remote.
# @stderr The reason when no target can be chosen.
# @exitcode 0 A target was printed.
# @exitcode 1 No remote, several remotes and none is `origin`, or a name that looks like an option.
# @example
#   target="$(shell::git::commit::amend::push_target "$branch")" || return $?
#
shell::git::commit::amend::push_target() {
	local branch="${1-}" remote merge remotes

	remote="$(git config --get "branch.$branch.remote" 2>/dev/null)"
	merge="$(git config --get "branch.$branch.merge" 2>/dev/null)"

	if [ -n "$remote" ] && [ "$remote" != "." ] && [ -n "$merge" ]; then
		branch="${merge#refs/heads/}"
	else
		remotes="$(git remote 2>/dev/null)"
		if [ -z "$remotes" ]; then
			shell::logger::error "This repository has no remote to push to"
			return "$RETURN_FAILURE"
		fi
		if printf '%s\n' "$remotes" | grep -Fxq -- "origin"; then
			remote="origin"
		elif [ "$(printf '%s\n' "$remotes" | wc -l | tr -d ' ')" = "1" ]; then
			remote="$remotes"
		else
			shell::logger::error "Several remotes and none is named origin; set an upstream first (git branch -u <remote>/<branch>)"
			return "$RETURN_FAILURE"
		fi
	fi

	case "$remote$branch" in
	-* | *$'\n'*)
		shell::logger::error "Refusing to push to a remote or branch whose name looks like an option"
		return "$RETURN_FAILURE"
		;;
	esac
	case "$branch" in
	-*)
		shell::logger::error "Refusing to push to a branch whose name looks like an option"
		return "$RETURN_FAILURE"
		;;
	esac

	printf '%s\n%s\n' "$remote" "$branch"
}

# @description Amends the most recent commit.
#
#   Step 1 — Check what would be amended. Staged changes are folded into the
#   commit; with none staged, the default (editor) mode only rewords the message.
#   `--no-edit` needs staged changes, because without them it would amend
#   nothing (it would only change the commit hash and date), so it stops there.
#   Step 2 — Execute `git commit --amend` (with `--no-edit` when asked; the
#   editor opens otherwise).
#   Step 3 — Push with `--force-with-lease`: automatically with `--push`, or,
#   when the amended commit was already on the upstream branch (so a force push
#   is needed), by asking. `--force-with-lease` refuses to overwrite commits
#   somebody else pushed meanwhile, which a plain `--force` would destroy.
#
#   The push target is checked before anything is changed, so a missing remote
#   never leaves a half-done amend. If the amend itself fails (a hook, an empty
#   message) the commit is left exactly as it was. If only the push fails, the
#   amended commit stays local and the previous hash is printed.
# @option -e | --edit Optional. Open the editor to edit the commit message (default opens editor).
# @option --no-edit Optional. Amend the commit without changing the message.
# @option -p | --push Optional. Automatically push after amending using --force-with-lease.
# @option -n | --dry-run Optional. Print planned git commands instead of executing.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed (not a repository, nothing to amend, hook, no push target, push rejected).
# @exitcode 2 Invalid usage (unknown option, or --edit together with --no-edit).
# @example
#   shell::git::commit::amend --no-edit -p
#   shell::git::commit::amend -n
#
shell::git::commit::amend() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Amend the most recent commit (staged changes and/or message)"
		shell::logger::usage "shell::git::commit::amend [-e | --no-edit] [-p] [-n] [-h]"
		shell::logger::option "-e, --edit" "Open the editor to edit the message (the default)"
		shell::logger::option "--no-edit" "Keep the message; needs staged changes"
		shell::logger::option "-p, --push" "Push afterwards with --force-with-lease"
		shell::logger::option "-n, --dry-run" "Print the planned git commands instead of executing them"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::example "shell::git::commit::amend --no-edit -p"
		shell::logger::example "shell::git::commit::amend -n"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" edit="false" no_edit="false" push="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-e | --edit)
			edit="true"
			shift
			;;
		--no-edit)
			no_edit="true"
			shift
			;;
		-p | --push)
			push="true"
			shift
			;;
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		*)
			shell::logger::error "Unknown option or argument: $1"
			return "$RETURN_INVALID"
			;;
		esac
	done

	if [ "$edit" = "true" ] && [ "$no_edit" = "true" ]; then
		shell::logger::error "--edit and --no-edit cannot be combined"
		return "$RETURN_INVALID"
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return "$RETURN_FAILURE"
	fi
	if ! git rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
		shell::logger::error "There is no commit to amend yet"
		return "$RETURN_FAILURE"
	fi

	# Declared once, before any branching (re-declaring a local prints in zsh).
	local has_staged="true" unstaged_count branch upstream published="false"
	local old_head new_head target remote_name remote_branch choice rc
	local -a amend_cmd=(git commit --amend)

	# ---------------------------------------------------------------------------
	# Step 1 — what will be amended?
	# ---------------------------------------------------------------------------
	if git diff --cached --quiet 2>/dev/null; then
		has_staged="false"
	fi
	unstaged_count="$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')"

	if [ "$has_staged" = "false" ]; then
		if [ "$no_edit" = "true" ]; then
			shell::logger::error "Nothing is staged, so --no-edit would amend nothing; stage changes (git add) or drop --no-edit to reword"
			return "$RETURN_FAILURE"
		fi
		shell::logger::info "No staged changes: only the commit message will be edited"
	fi
	if [ "${unstaged_count:-0}" -gt 0 ]; then
		shell::logger::info "${unstaged_count} file(s) with unstaged changes are not part of the amend (git add them first)"
	fi

	branch="$(git symbolic-ref --short -q HEAD 2>/dev/null)"
	if [ -n "$branch" ]; then
		upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)"
	fi
	if [ -n "$upstream" ] && git merge-base --is-ancestor HEAD "$upstream" 2>/dev/null; then
		published="true"
		shell::logger::warn "This commit is already on ${upstream}; amending rewrites it and needs a force push"
	fi

	# Resolve the push target now, before anything is changed.
	if [ "$push" = "true" ]; then
		if [ -z "$branch" ]; then
			shell::logger::error "--push needs a branch, but HEAD is detached"
			return "$RETURN_FAILURE"
		fi
		target="$(shell::git::commit::amend::push_target "$branch")" || return "$RETURN_FAILURE"
		remote_name="${target%%$'\n'*}"
		remote_branch="${target#*$'\n'}"
	fi

	if [ "$no_edit" = "true" ]; then
		amend_cmd+=(--no-edit)
	elif [ "$edit" = "true" ]; then
		amend_cmd+=(--edit)
	fi

	# ---------------------------------------------------------------------------
	# Dry-run — print the plan, change nothing.
	# ---------------------------------------------------------------------------
	if [ "$dry_run" = "true" ]; then
		shell::exec::command -n "${amend_cmd[@]}"
		if [ "$push" = "true" ]; then
			shell::exec::command -n git push --force-with-lease "$remote_name" "refs/heads/${branch}:refs/heads/${remote_branch}"
		elif [ "$published" = "true" ]; then
			shell::logger::info "It would then ask whether to push with --force-with-lease"
		fi
		return "$RETURN_SUCCESS"
	fi

	# ---------------------------------------------------------------------------
	# Step 2 — amend.
	# ---------------------------------------------------------------------------
	old_head="$(git rev-parse HEAD 2>/dev/null)"
	shell::exec::command "${amend_cmd[@]}"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		shell::logger::error "git commit --amend failed; the commit was left unchanged"
		return "$RETURN_FAILURE"
	fi

	new_head="$(git rev-parse --short HEAD 2>/dev/null)"
	shell::logger::success "Amended: ${new_head}"
	shell::logger::info "Previous commit: ${old_head} (to go back and keep your changes staged: git reset --soft ${old_head})"

	# ---------------------------------------------------------------------------
	# Step 3 — push with --force-with-lease (asked for, or offered when needed).
	# ---------------------------------------------------------------------------
	if [ "$push" != "true" ] && [ "$published" = "true" ]; then
		choice="$(shell::ask::option "Push with --force-with-lease" "Don't push")"
		if [ "$choice" = "Push with --force-with-lease" ]; then
			target="$(shell::git::commit::amend::push_target "$branch")" || return "$RETURN_FAILURE"
			remote_name="${target%%$'\n'*}"
			remote_branch="${target#*$'\n'}"
			push="true"
		else
			shell::logger::info "Not pushed. When ready: git push --force-with-lease"
		fi
	fi

	if [ "$push" = "true" ]; then
		if ! shell::exec::command git push --force-with-lease "$remote_name" "refs/heads/${branch}:refs/heads/${remote_branch}"; then
			shell::logger::error "Push failed (the remote may have new commits: fetch and review them before retrying). The amended commit is still local"
			return "$RETURN_FAILURE"
		fi
		shell::logger::success "Pushed to ${remote_name}/${remote_branch} with --force-with-lease"
	fi

	return "$RETURN_SUCCESS"
}

# @internal
# @description Validate a value used by the `shell::git::config::*` functions.
#   Kinds:
#   - `key`: `section[.subsection].name`. The section is letters, digits and `-`;
#     the name starts with a letter; no leading `-` (it would be read as an
#     option) and no newline.
#   - `name`: not empty, no `<`, `>` or newline (git strips them from identities).
#   - `email`: `something@something.something`, no spaces, `<`, `>` or second `@`.
#   - `branch`: a valid branch name, as `git check-ref-format --branch` sees it.
#   - `autocrlf`: `true`, `input` or `false`.
# @arg $1 string Kind: key, name, email, branch or autocrlf.
# @arg $2 string The value to check.
# @exitcode 0 Valid.
# @exitcode 1 Invalid (or unknown kind).
# @example
#   shell::git::config::validate key "user.email" && echo ok
#
shell::git::config::validate() {
	local kind="${1-}" value="${2-}" section leaf

	case "$kind" in
	key)
		case "$value" in
		'' | -* | .* | *. | *$'\n'*) return 1 ;;
		*.*) ;;
		*) return 1 ;;
		esac
		section="${value%%.*}"
		leaf="${value##*.}"
		case "$section" in
		'' | *[!A-Za-z0-9-]*) return 1 ;;
		esac
		case "$leaf" in
		'' | [!A-Za-z]* | *[!A-Za-z0-9-]*) return 1 ;;
		esac
		;;
	name)
		case "$value" in
		'' | *'<'* | *'>'* | *$'\n'*) return 1 ;;
		esac
		;;
	email)
		case "$value" in
		'' | *[[:space:]]* | *'<'* | *'>'* | *@*@*) return 1 ;;
		?*@?*.?*) ;;
		*) return 1 ;;
		esac
		;;
	branch)
		case "$value" in
		'' | -*) return 1 ;;
		esac
		git check-ref-format --branch "$value" >/dev/null 2>&1 || return 1
		;;
	autocrlf)
		case "$value" in
		true | input | false) ;;
		*) return 1 ;;
		esac
		;;
	*) return 1 ;;
	esac
	return 0
}

# @internal
# @description Check that git exists and that the scope can be used.
#   `local` needs a repository; `global` works anywhere.
# @arg $1 string Scope: local or global.
# @stderr The reason when the scope cannot be used.
# @exitcode 0 Usable.
# @exitcode 1 git is missing, or `local` outside a repository.
# @example
#   shell::git::config::preflight local || return $?
#
shell::git::config::preflight() {
	local scope="${1-}"

	if ! command -v git >/dev/null 2>&1; then
		shell::logger::error "git is not installed"
		return "$RETURN_FAILURE"
	fi
	if [ "$scope" = "local" ] && ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository (use --global for the user configuration)"
		return "$RETURN_FAILURE"
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Count how many values a key has in one scope.
#   Uses the NUL-terminated form of `git config`, so a value that contains a
#   newline still counts once.
# @arg $1 string Scope: local or global.
# @arg $2 string Key.
# @stdout The number of values (0 when the key is absent).
# @exitcode 0 Always.
# @example
#   [ "$(shell::git::config::count local remote.origin.fetch)" -gt 1 ]
#
shell::git::config::count() {
	git config "--${1-}" --get-all -z -- "${2-}" 2>/dev/null | tr -cd '\000' | wc -c | tr -d ' '
}

# @internal
# @description Ask for one line of text, with a default and optional validation.
#   The prompt goes to stderr and the value to stdout (usable in `$(...)`).
#   Enter accepts the default; an invalid or empty answer asks again; end of
#   input (Ctrl-D) cancels.
# @arg $1 string Prompt label.
# @arg $2 string Default value (may be empty: the answer is then required).
# @arg $3 string Validation kind for shell::git::config::validate (optional).
# @stdout The accepted value, trimmed.
# @exitcode 0 A value was accepted.
# @exitcode 9 End of input (Ctrl-D).
# @example
#   email="$(shell::git::config::prompt "user.email" "$current" email)" || return $?
#
shell::git::config::prompt() {
	local label="${1-}" default="${2-}" kind="${3-}" value=""

	while true; do
		if [ -n "$default" ]; then
			printf '%s [%s]: ' "$label" "$default" >&2
		else
			printf '%s: ' "$label" >&2
		fi

		if ! read -r value; then
			printf '\n' >&2
			return "$RETURN_CANCELLED"
		fi

		value="${value#"${value%%[![:space:]]*}"}"
		value="${value%"${value##*[![:space:]]}"}"
		if [ -z "$value" ]; then
			value="$default"
		fi

		if [ -z "$value" ]; then
			shell::logger::warn "A value is required"
			continue
		fi
		if [ -n "$kind" ] && ! shell::git::config::validate "$kind" "$value"; then
			shell::logger::warn "'${value}' is not a valid ${kind}; try again"
			continue
		fi

		printf '%s\n' "$value"
		return "$RETURN_SUCCESS"
	done
}

# @description Lists all Git configuration key-value pairs with their origin file.
#
#   Defaults to listing the local project configuration (.git/config).
#   Use the --global flag to list the user's global configuration (~/.gitconfig).
#   Each line is `file:<path><TAB><key>=<value>` (git's `--show-origin` format),
#   on stdout, so it can be piped to `grep`, `cut` or `column`.
#
# @option -g | --global Optional. List global configuration instead of local.
# @option -n | --dry-run Optional. Print the planned git command instead of executing.
# @option -h | --help Show this help message.
# @stdout The configuration, one entry per line, with its origin file.
# @exitcode 0 Success.
# @exitcode 1 The operation failed or not in a git repository (when listing local).
# @exitcode 2 Invalid usage.
# @example
#   shell::git::config::list
#   shell::git::config::list --global
#
shell::git::config::list() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List Git configuration entries with their origin file"
		shell::logger::usage "shell::git::config::list [-g] [-n] [-h]"
		shell::logger::option "-g, --global" "List the global configuration instead of the local one"
		shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::example "shell::git::config::list"
		shell::logger::example "shell::git::config::list --global"
		return "$RETURN_SUCCESS"
	fi

	local scope="local" dry_run="false" out rc
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-g | --global)
			scope="global"
			shift
			;;
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		*)
			shell::logger::error "Unknown option or argument: $1"
			return "$RETURN_INVALID"
			;;
		esac
	done

	shell::git::config::preflight "$scope" || return "$RETURN_FAILURE"

	if [ "$dry_run" = "true" ]; then
		shell::exec::command -n git config "--$scope" --list --show-origin
		return "$RETURN_SUCCESS"
	fi

	out="$(git config "--$scope" --list --show-origin 2>&1)"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		case "$out" in
		*"unable to read config file"*)
			shell::logger::warn "No ${scope} Git configuration found yet"
			;;
		*)
			shell::logger::error "git config failed: ${out}"
			;;
		esac
		return "$RETURN_FAILURE"
	fi

	if [ -n "$out" ]; then
		printf '%s\n' "$out"
	fi
	return "$RETURN_SUCCESS"
}

# @description Retrieves the value of a specific Git configuration key.
#
#   Without `--global` the effective value is returned, the one git itself would
#   use (local, then global, then system), and it works outside a repository too.
#   With `--global` only the user's global configuration is read. The value is
#   printed alone on stdout, exactly as stored, so `$(shell::git::config::get k)`
#   is safe to use. A key with several values returns the last one.
#
# @arg $1 string key: The configuration key to retrieve (e.g., "user.email", "core.autocrlf").
# @option -g | --global Optional. Get the value from the global configuration.
# @option -h | --help Show this help message.
# @stdout The value.
# @exitcode 0 Success (key found and value printed).
# @exitcode 1 Key not found or operation failed.
# @exitcode 2 Missing or invalid key, or invalid usage.
# @example
#   shell::git::config::get "user.name"
#   shell::git::config::get -g "init.defaultBranch"
#
shell::git::config::get() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Print the value of a Git configuration key"
		shell::logger::usage "shell::git::config::get [-g] [-h] <key>"
		shell::logger::item "key" "e.g. user.email, core.autocrlf"
		shell::logger::option "-g, --global" "Read only the global configuration"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::example "shell::git::config::get user.name"
		shell::logger::example "shell::git::config::get -g init.defaultBranch"
		return "$RETURN_SUCCESS"
	fi

	local global="false" end_opts="false" key="" have_key="false" rc
	while [ "$#" -gt 0 ]; do
		if [ "$end_opts" = "false" ]; then
			case "$1" in
			-g | --global)
				global="true"
				shift
				continue
				;;
			--)
				end_opts="true"
				shift
				continue
				;;
			-*)
				shell::logger::error "Unknown option: $1"
				return "$RETURN_INVALID"
				;;
			esac
		fi
		if [ "$have_key" = "true" ]; then
			shell::logger::error "Only one key is accepted (got '$key' and '$1')"
			return "$RETURN_INVALID"
		fi
		key="$1"
		have_key="true"
		shift
	done

	if [ "$have_key" = "false" ]; then
		shell::logger::error "A key is required, e.g. user.email"
		return "$RETURN_INVALID"
	fi
	if ! shell::git::config::validate key "$key"; then
		shell::logger::error "Invalid key: '$key' (expected section.name, e.g. user.email)"
		return "$RETURN_INVALID"
	fi
	if ! command -v git >/dev/null 2>&1; then
		shell::logger::error "git is not installed"
		return "$RETURN_FAILURE"
	fi

	if [ "$global" = "true" ]; then
		git config --global --get -- "$key"
	else
		git config --get -- "$key"
	fi
	rc=$?

	if [ "$rc" -ne 0 ]; then
		shell::logger::warn "Key not found: ${key}"
		return "$RETURN_FAILURE"
	fi
	return "$RETURN_SUCCESS"
}

# @description Sets or updates a Git configuration key-value pair.
#
#   If the key already exists, its value is overwritten.
#   Defaults to the local project configuration.
#   The value is passed to git as one argument (never through `eval`), so
#   quotes, `$` and spaces are stored exactly as given; an empty value is allowed.
#   A value that starts with `-` must follow `--` (`set -- core.pager -F`).
#   A key that already has several values (such as `remote.origin.fetch`) is
#   refused instead of being collapsed to one; setting the same value again
#   changes nothing.
#
# @arg $1 string key: The configuration key (e.g., "user.email").
# @arg $2 string value: The value to set.
# @option -g | --global Optional. Set the value in the global configuration.
# @option -n | --dry-run Optional. Print the planned git command instead of executing.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed (not in a repository for local, key with several values).
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::git::config::set "user.name" "John Doe"
#   shell::git::config::set -g "core.editor" "nvim"
#
shell::git::config::set() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Set (or update) a Git configuration key"
		shell::logger::usage "shell::git::config::set [-g] [-n] [-h] [--] <key> <value>"
		shell::logger::item "key" "e.g. user.email"
		shell::logger::item "value" "The new value (may be empty; use -- if it starts with -)"
		shell::logger::option "-g, --global" "Write to the global configuration instead of the local one"
		shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::example "shell::git::config::set user.name \"John Doe\""
		shell::logger::example "shell::git::config::set -g core.editor nvim"
		return "$RETURN_SUCCESS"
	fi

	local scope="local" dry_run="false" end_opts="false"
	local key="" value="" have_key="false" have_value="false"
	local count old
	while [ "$#" -gt 0 ]; do
		if [ "$end_opts" = "false" ]; then
			case "$1" in
			-g | --global)
				scope="global"
				shift
				continue
				;;
			-n | --dry-run)
				dry_run="true"
				shift
				continue
				;;
			--)
				end_opts="true"
				shift
				continue
				;;
			-*)
				shell::logger::error "Unknown option: $1 (put -- before a value that starts with -)"
				return "$RETURN_INVALID"
				;;
			esac
		fi
		if [ "$have_key" = "false" ]; then
			key="$1"
			have_key="true"
		elif [ "$have_value" = "false" ]; then
			value="$1"
			have_value="true"
		else
			shell::logger::error "Too many arguments; expected <key> <value>"
			return "$RETURN_INVALID"
		fi
		shift
	done

	if [ "$have_key" = "false" ] || [ "$have_value" = "false" ]; then
		shell::logger::error "Usage: shell::git::config::set [-g] [-n] <key> <value>"
		return "$RETURN_INVALID"
	fi
	if ! shell::git::config::validate key "$key"; then
		shell::logger::error "Invalid key: '$key' (expected section.name, e.g. user.email)"
		return "$RETURN_INVALID"
	fi

	shell::git::config::preflight "$scope" || return "$RETURN_FAILURE"

	count="$(shell::git::config::count "$scope" "$key")"
	if [ "${count:-0}" -gt 1 ]; then
		shell::logger::error "'${key}' has ${count} values in the ${scope} configuration; refusing to collapse them (use git config --replace-all)"
		return "$RETURN_FAILURE"
	fi
	if [ "${count:-0}" -eq 1 ]; then
		old="$(git config "--$scope" --get -- "$key" 2>/dev/null)"
		if [ "$old" = "$value" ]; then
			shell::logger::info "'${key}' already has this value in the ${scope} configuration"
			return "$RETURN_SUCCESS"
		fi
	fi

	if [ "$dry_run" = "true" ]; then
		shell::exec::command -n git config "--$scope" -- "$key" "$value"
		return "$RETURN_SUCCESS"
	fi

	if ! shell::exec::command git config "--$scope" -- "$key" "$value"; then
		shell::logger::error "Could not set '${key}' in the ${scope} configuration"
		return "$RETURN_FAILURE"
	fi
	shell::logger::success "Set ${key} in the ${scope} configuration"
	return "$RETURN_SUCCESS"
}

# @description Removes a specific key from the Git configuration.
#
#   Only the chosen scope is touched: removing a local key leaves the global
#   value in place (and the other way round). A key with several values is
#   refused instead of being wiped.
#
# @arg $1 string key: The configuration key to remove.
# @option -g | --global Optional. Remove the key from the global configuration.
# @option -n | --dry-run Optional. Print the planned git command instead of executing.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 Key not found or operation failed.
# @exitcode 2 Missing or invalid key, or invalid usage.
# @example
#   shell::git::config::unset "user.signingkey"
#   shell::git::config::unset -g "credential.helper"
#
shell::git::config::unset() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Remove a key from the Git configuration"
		shell::logger::usage "shell::git::config::unset [-g] [-n] [-h] <key>"
		shell::logger::item "key" "e.g. user.signingkey"
		shell::logger::option "-g, --global" "Remove from the global configuration instead of the local one"
		shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::example "shell::git::config::unset user.signingkey"
		shell::logger::example "shell::git::config::unset -g credential.helper"
		return "$RETURN_SUCCESS"
	fi

	local scope="local" dry_run="false" end_opts="false" key="" have_key="false" count
	while [ "$#" -gt 0 ]; do
		if [ "$end_opts" = "false" ]; then
			case "$1" in
			-g | --global)
				scope="global"
				shift
				continue
				;;
			-n | --dry-run)
				dry_run="true"
				shift
				continue
				;;
			--)
				end_opts="true"
				shift
				continue
				;;
			-*)
				shell::logger::error "Unknown option: $1"
				return "$RETURN_INVALID"
				;;
			esac
		fi
		if [ "$have_key" = "true" ]; then
			shell::logger::error "Only one key is accepted (got '$key' and '$1')"
			return "$RETURN_INVALID"
		fi
		key="$1"
		have_key="true"
		shift
	done

	if [ "$have_key" = "false" ]; then
		shell::logger::error "A key is required, e.g. user.signingkey"
		return "$RETURN_INVALID"
	fi
	if ! shell::git::config::validate key "$key"; then
		shell::logger::error "Invalid key: '$key' (expected section.name, e.g. user.signingkey)"
		return "$RETURN_INVALID"
	fi

	shell::git::config::preflight "$scope" || return "$RETURN_FAILURE"

	count="$(shell::git::config::count "$scope" "$key")"
	if [ "${count:-0}" -eq 0 ]; then
		shell::logger::warn "Key not found in the ${scope} configuration: ${key}"
		return "$RETURN_FAILURE"
	fi
	if [ "${count:-0}" -gt 1 ]; then
		shell::logger::error "'${key}' has ${count} values in the ${scope} configuration; refusing to remove them all (use git config --unset-all)"
		return "$RETURN_FAILURE"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::exec::command -n git config "--$scope" --unset -- "$key"
		return "$RETURN_SUCCESS"
	fi

	if ! shell::exec::command git config "--$scope" --unset -- "$key"; then
		shell::logger::error "Could not remove '${key}' from the ${scope} configuration"
		return "$RETURN_FAILURE"
	fi
	shell::logger::success "Removed ${key} from the ${scope} configuration"
	return "$RETURN_SUCCESS"
}

# @description Interactively sets up standard user identity and default branch for a scope.
#
#   Prompts the user for:
#   1. user.name
#   2. user.email
#   3. init.defaultBranch (defaults to "main")
#   4. core.autocrlf (defaults to "input" for Linux/Mac, "true" for Windows)
#
#   Enter accepts the value shown in brackets: the one already set in the
#   scope, otherwise (for name and email in a repository) the one inherited from
#   the global configuration, otherwise the default above. Answers are
#   validated (a real e-mail shape, a valid branch name, true/input/false) and
#   asked again when wrong. A summary is shown, and nothing is written until you
#   choose Apply; keys whose value does not change are skipped.
#
#   This is highly useful when cloning a new project and needing to override
#   global settings with project-specific credentials.
#
# @option -g | --global Optional. Setup the global configuration instead of local.
# @option -n | --dry-run Optional. Print the planned git commands instead of executing.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed or canceled.
# @exitcode 2 Invalid usage.
# @see shell::git::config::set
# @example
#   shell::git::config::user::setup
#   shell::git::config::user::setup --global
#
shell::git::config::user::setup() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively set user.name, user.email, init.defaultBranch and core.autocrlf"
		shell::logger::usage "shell::git::config::user::setup [-g] [-n] [-h]"
		shell::logger::option "-g, --global" "Configure the global settings instead of the repository's"
		shell::logger::option "-n, --dry-run" "Print the git commands instead of executing them"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::note "Enter accepts the value in brackets; Ctrl-D cancels; nothing is written until you choose Apply."
		shell::logger::example "shell::git::config::user::setup"
		shell::logger::example "shell::git::config::user::setup --global"
		return "$RETURN_SUCCESS"
	fi

	local scope="local" dry_run="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-g | --global)
			scope="global"
			shift
			;;
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		*)
			shell::logger::error "Unknown option or argument: $1"
			return "$RETURN_INVALID"
			;;
		esac
	done

	shell::git::config::preflight "$scope" || return "$RETURN_FAILURE"

	# Declared once (re-declaring a local in a loop prints its value in zsh).
	local name email branch crlf
	local cur_name cur_email cur_branch cur_crlf
	local def_name def_email def_branch def_crlf os_default
	local key value current choice failed=0 changed=0
	local -a set_flags=()

	cur_name="$(git config "--$scope" --get -- user.name 2>/dev/null)"
	cur_email="$(git config "--$scope" --get -- user.email 2>/dev/null)"
	cur_branch="$(git config "--$scope" --get -- init.defaultBranch 2>/dev/null)"
	cur_crlf="$(git config "--$scope" --get -- core.autocrlf 2>/dev/null)"

	def_name="$cur_name"
	def_email="$cur_email"
	if [ "$scope" = "local" ]; then
		# Show what the repository inherits, so Enter can keep it.
		[ -n "$def_name" ] || def_name="$(git config --get -- user.name 2>/dev/null)"
		[ -n "$def_email" ] || def_email="$(git config --get -- user.email 2>/dev/null)"
	fi
	def_branch="${cur_branch:-main}"
	if [ "$(shell::os::type)" = "windows" ]; then
		os_default="true"
	else
		os_default="input"
	fi
	def_crlf="${cur_crlf:-$os_default}"

	shell::logger::info "Configuring the ${scope} Git settings (Enter accepts the value in brackets, Ctrl-D cancels)"

	name="$(shell::git::config::prompt "user.name" "$def_name" name)" || {
		shell::logger::warn "Setup cancelled — nothing was changed"
		return "$RETURN_FAILURE"
	}
	email="$(shell::git::config::prompt "user.email" "$def_email" email)" || {
		shell::logger::warn "Setup cancelled — nothing was changed"
		return "$RETURN_FAILURE"
	}
	branch="$(shell::git::config::prompt "init.defaultBranch" "$def_branch" branch)" || {
		shell::logger::warn "Setup cancelled — nothing was changed"
		return "$RETURN_FAILURE"
	}
	crlf="$(shell::git::config::prompt "core.autocrlf (true | input | false)" "$def_crlf" autocrlf)" || {
		shell::logger::warn "Setup cancelled — nothing was changed"
		return "$RETURN_FAILURE"
	}

	shell::logger::info "Summary for the ${scope} configuration:"
	for key in user.name user.email init.defaultBranch core.autocrlf; do
		case "$key" in
		user.name)
			value="$name"
			current="$cur_name"
			;;
		user.email)
			value="$email"
			current="$cur_email"
			;;
		init.defaultBranch)
			value="$branch"
			current="$cur_branch"
			;;
		*)
			value="$crlf"
			current="$cur_crlf"
			;;
		esac
		if [ "$value" = "$current" ]; then
			shell::logger::info "  ${key} = ${value}  (unchanged)"
		else
			shell::logger::info "  ${key} = ${value}"
			changed=$((changed + 1))
		fi
	done

	if [ "$changed" -eq 0 ]; then
		shell::logger::info "Nothing to change"
		return "$RETURN_SUCCESS"
	fi

	if [ "$scope" = "global" ]; then
		set_flags+=(--global)
	fi
	if [ "$dry_run" = "true" ]; then
		set_flags+=(--dry-run)
	else
		choice="$(shell::ask::option "Apply" "Cancel")"
		if [ "$choice" != "Apply" ]; then
			shell::logger::info "Setup cancelled — nothing was changed"
			return "$RETURN_FAILURE"
		fi
	fi

	[ "$name" = "$cur_name" ] || shell::git::config::set ${set_flags[@]+"${set_flags[@]}"} -- user.name "$name" || failed=$((failed + 1))
	[ "$email" = "$cur_email" ] || shell::git::config::set ${set_flags[@]+"${set_flags[@]}"} -- user.email "$email" || failed=$((failed + 1))
	[ "$branch" = "$cur_branch" ] || shell::git::config::set ${set_flags[@]+"${set_flags[@]}"} -- init.defaultBranch "$branch" || failed=$((failed + 1))
	[ "$crlf" = "$cur_crlf" ] || shell::git::config::set ${set_flags[@]+"${set_flags[@]}"} -- core.autocrlf "$crlf" || failed=$((failed + 1))

	if [ "$failed" -gt 0 ]; then
		shell::logger::error "${failed} setting(s) could not be written"
		return "$RETURN_FAILURE"
	fi
	return "$RETURN_SUCCESS"
}

# @description Presents an interactive fzf picker to view, edit, or delete Git configurations.
#
#   Step 1 — List all config keys and values for the chosen scope (local or global).
#   Step 2 — Present an fzf picker with a preview window showing the current value
#   (and the file it comes from).
#   Step 3 — Present an action menu upon selection:
#   • Edit value
#   • Unset (Delete) key
#   • Cancel
#
#   After an action (or Cancel) the key list is shown again, so several keys can
#   be managed in one session; leave with ESC or the "← Back" entry. Editing
#   asks for the new value (Enter keeps the current one) and goes through
#   shell::git::config::set; unsetting asks for confirmation first and goes
#   through shell::git::config::unset, so a key with several values is never
#   changed by accident. Returns 0 when at least one change was made (or
#   planned, with -n) and nothing failed, 1 otherwise.
#
# @option -g | --global Optional. Manage global configuration instead of local.
# @option -n | --dry-run Optional. Print the planned git commands instead of executing.
# @option -h | --help Show this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed or canceled.
# @exitcode 2 Invalid usage.
# @see shell::git::config::set
# @see shell::git::config::unset
# @example
#   shell::git::config::fzf
#   shell::git::config::fzf -g
#
shell::git::config::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Browse Git configuration keys in fzf, then edit or delete them"
		shell::logger::usage "shell::git::config::fzf [-g] [-n] [-h]"
		shell::logger::option "-g, --global" "Manage the global configuration instead of the local one"
		shell::logger::option "-n, --dry-run" "Print the git commands instead of executing them"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::note "ESC or '$SHELL_FZF_BACK_LABEL' ends the session; Cancel in the action menu returns to the list."
		shell::logger::example "shell::git::config::fzf"
		shell::logger::example "shell::git::config::fzf -g"
		return "$RETURN_SUCCESS"
	fi

	local scope="local" dry_run="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-g | --global)
			scope="global"
			shift
			;;
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		*)
			shell::logger::error "Unknown option or argument: $1"
			return "$RETURN_INVALID"
			;;
		esac
	done

	shell::git::config::preflight "$scope" || return "$RETURN_FAILURE"

	# Declared once, before the loop.
	local keys choice key action current new_value confirm rc preview
	local changed=0 failed=0
	local -a flags=()
	if [ "$scope" = "global" ]; then
		flags+=(--global)
	fi
	if [ "$dry_run" = "true" ]; then
		flags+=(--dry-run)
	fi

	# The preview runs the same read-only command for the highlighted key; fzf
	# quotes {} for the shell, so odd key names are safe.
	preview="git config --${scope} --show-origin --get-all -- {} 2>/dev/null"

	while true; do
		# Step 1 — keys of the scope (re-read every time: edits change the list).
		keys="$(git config "--$scope" --name-only --list 2>/dev/null | sort -u)"
		if [ -z "$keys" ]; then
			shell::logger::warn "No keys in the ${scope} configuration"
			break
		fi

		# Step 2 — picker with a value preview.
		choice="$(printf '%s\n%s\n' "$keys" "$SHELL_FZF_BACK_LABEL" |
			shell::fzf::select --prompt="Git ${scope} config: " \
				--preview="$preview" --preview-window="right:55%:wrap")"
		rc=$?
		if [ "$rc" -ne 0 ] || [ -z "$choice" ] || [ "$choice" = "$SHELL_FZF_BACK_LABEL" ]; then
			break
		fi
		key="$choice"

		# Step 3 — action menu.
		action="$(shell::ask::option "Edit value" "Unset (Delete) key" "Cancel")"
		case "$action" in
		"Edit value")
			current="$(git config "--$scope" --get -- "$key" 2>/dev/null)"
			new_value="$(shell::git::config::prompt "New value for ${key}" "$current")"
			rc=$?
			if [ "$rc" -ne 0 ]; then
				shell::logger::info "Edit cancelled"
				continue
			fi
			if [ "$new_value" = "$current" ]; then
				shell::logger::info "Value unchanged"
				continue
			fi
			if shell::git::config::set ${flags[@]+"${flags[@]}"} -- "$key" "$new_value"; then
				changed=$((changed + 1))
			else
				failed=$((failed + 1))
			fi
			;;
		"Unset (Delete) key")
			confirm="$(shell::ask::option "Unset ${key}" "Cancel")"
			if [ "$confirm" != "Unset ${key}" ]; then
				shell::logger::info "Unset cancelled"
				continue
			fi
			if shell::git::config::unset ${flags[@]+"${flags[@]}"} -- "$key"; then
				changed=$((changed + 1))
			else
				failed=$((failed + 1))
			fi
			;;
		*)
			shell::logger::info "Cancelled — back to the list"
			;;
		esac
	done

	if [ "$changed" -gt 0 ] && [ "$failed" -eq 0 ]; then
		return "$RETURN_SUCCESS"
	fi
	return "$RETURN_FAILURE"
}

# @internal
# @description Tell whether a cherry-pick (or a multi-commit sequence) is in progress.
#   True when `CHERRY_PICK_HEAD` exists (stopped on a commit) or the sequencer
#   still has a to-do list (stopped between two commits). Paths come from
#   `git rev-parse --git-path`, so it also works in linked worktrees.
# @exitcode 0 A cherry-pick is in progress.
# @exitcode 1 None is in progress (or not in a repository).
# @example
#   shell::git::commit::pick::in_progress && echo "busy"
#
shell::git::commit::pick::in_progress() {
    local head_file todo_file
    head_file="$(git rev-parse --git-path CHERRY_PICK_HEAD 2>/dev/null)"
    todo_file="$(git rev-parse --git-path sequencer/todo 2>/dev/null)"

    if [ -n "$head_file" ] && [ -e "$head_file" ]; then
        return 0
    fi
    if [ -n "$todo_file" ] && [ -s "$todo_file" ]; then
        return 0
    fi
    return 1
}

# @internal
# @description Check that a new cherry-pick can start.
#   Refuses when: not in a repository; no commit yet; a cherry-pick, merge or
#   revert is already in progress; or (commit mode) there are staged changes,
#   which git itself refuses to mix into a pick. Unstaged edits and untracked
#   files are fine.
# @arg $1 string Mode: `commit` (default, creates commits) or `stage` (--no-commit).
# @stderr The reason when the state is not safe.
# @exitcode 0 Safe to start.
# @exitcode 1 Not safe (the reason is printed).
# @example
#   shell::git::commit::pick::guard commit || return $?
#
shell::git::commit::pick::guard() {
    local mode="${1:-commit}" marker

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        shell::logger::error "Not inside a Git repository"
        return "$RETURN_FAILURE"
    fi
    if ! git rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
        shell::logger::error "This repository has no commits yet"
        return "$RETURN_FAILURE"
    fi
    if shell::git::commit::pick::in_progress; then
        shell::logger::error "A cherry-pick is already in progress; finish it (shell::git::commit::pick::continue / skip) or cancel it (abort / quit)"
        return "$RETURN_FAILURE"
    fi
    for marker in MERGE_HEAD REVERT_HEAD; do
        if [ -e "$(git rev-parse --git-path "$marker")" ]; then
            shell::logger::error "A ${marker} operation is in progress; finish or abort it first"
            return "$RETURN_FAILURE"
        fi
    done
    if [ "$mode" = "commit" ] && ! git diff --cached --quiet 2>/dev/null; then
        shell::logger::error "There are staged changes; commit or unstage them first (or use --no-commit)"
        return "$RETURN_FAILURE"
    fi
    return "$RETURN_SUCCESS"
}

# @internal
# @description Decide which of the resolved commits will really be applied.
#   Drops what would leave git stuck half-way (it keeps the repository in
#   "cherry-pick in progress" for a commit that becomes empty):
#   - a commit already contained in the base is skipped, with a warning;
#   - so is one whose patch is already there under another hash (it was
#     cherry-picked before; found with `git cherry`);
#   - an empty commit is skipped, with a warning, unless `allow_empty` is true;
#   - duplicates are skipped.
#   Merge commits are checked against the mainline: a merge without a mainline
#   (or a mainline larger than its parent count) and a mainline on a non-merge
#   commit are errors, and nothing is returned.
# @arg $1 string Mainline parent number (empty for none).
# @arg $2 string `true` to keep empty commits.
# @arg $3 string Base revision the commits will be applied onto (HEAD, or a target branch).
# @arg $@ string Full commit hashes, in the order they should be applied.
# @stdout The hashes to apply, one per line, in the same order.
# @stderr Warnings for skipped commits and the reason for errors.
# @exitcode 0 At least one commit remains.
# @exitcode 1 An error, or nothing is left to apply.
# @example
#   hashes="$(shell::git::commit::pick::plan "" false HEAD "$h1" "$h2")" || return $?
#
shell::git::commit::pick::plan() {
    local mainline="${1-}" allow_empty="${2-false}" base="${3-HEAD}"
    shift 3

    local hash parents equal errors=0 kept=0 seen=" " out=""
    for hash in "$@"; do
        case "$seen" in
        *" $hash "*) continue ;;
        esac
        seen="$seen$hash "

        parents="$(git rev-list --parents -n 1 "$hash" 2>/dev/null | wc -w | tr -d ' ')"
        parents=$((parents - 1))

        if [ "$parents" -gt 1 ]; then
            if [ -z "$mainline" ]; then
                shell::logger::error "$(git log -1 --format='%h %s' "$hash") is a merge commit; use shell::git::commit::pick::merge -m <parent-number> (1 = the branch the merge was made on)"
                errors=$((errors + 1))
                continue
            fi
            if [ "$mainline" -gt "$parents" ]; then
                shell::logger::error "$(git log -1 --format='%h' "$hash") has only ${parents} parents; -m ${mainline} is out of range"
                errors=$((errors + 1))
                continue
            fi
        elif [ -n "$mainline" ]; then
            shell::logger::error "$(git log -1 --format='%h %s' "$hash") is not a merge commit; -m ${mainline} only applies to merges"
            errors=$((errors + 1))
            continue
        fi

        if git merge-base --is-ancestor "$hash" "$base" 2>/dev/null; then
            shell::logger::warn "Skipping $(git log -1 --format='%h %s' "$hash"): already contained in ${base}"
            continue
        fi

        # A commit that was cherry-picked before has another hash but the same
        # patch; picking it again would end in an empty commit and a stuck state.
        if [ "$parents" -eq 1 ]; then
            equal="$(git cherry "$base" "$hash" "${hash}^" 2>/dev/null | head -n 1)"
            case "$equal" in
            -*)
                shell::logger::warn "Skipping $(git log -1 --format='%h %s' "$hash"): a patch-equivalent commit is already in ${base}"
                continue
                ;;
            esac
        fi

        if [ "$parents" -le 1 ] && [ "$allow_empty" != "true" ] &&
            [ -z "$(git diff-tree --no-commit-id --name-only -r --root "$hash" 2>/dev/null)" ]; then
            shell::logger::warn "Skipping $(git log -1 --format='%h %s' "$hash"): it is an empty commit (use --allow-empty to keep it)"
            continue
        fi

        out="$out$hash"$'\n'
        kept=$((kept + 1))
    done

    if [ "$errors" -gt 0 ]; then
        return "$RETURN_FAILURE"
    fi
    if [ "$kept" -eq 0 ]; then
        shell::logger::warn "Nothing to apply"
        return "$RETURN_FAILURE"
    fi
    printf '%s' "$out"
}

# @description Validates that revisions resolve to commits.
#
#   Each argument may be anything git accepts: a hash (full or short), a branch,
#   a tag, `HEAD~2`, `origin/main^`. Tags are peeled to the commit they point
#   at. When every argument is valid, the full 40-character hashes are printed,
#   one per line, in the order given; when any is not, nothing is printed on
#   stdout and each bad argument is reported on stderr. Handy before an
#   automatic cherry-pick and in scripts: `hash="$(shell::git::commit::pick::validate v1.2)"`.
# @option -q | --quiet Optional. Print nothing at all; only the exit status tells.
# @option -h | --help Show this help message.
# @arg $@ string revision: One or more revisions.
# @stdout The full hash of each revision, one per line (only when all are valid).
# @exitcode 0 Every revision is a valid commit.
# @exitcode 1 At least one revision is not a valid commit, or not in a repository.
# @exitcode 2 No revision given, or invalid usage.
# @example
#   shell::git::commit::pick::validate HEAD~2
#   shell::git::commit::pick::validate -q a1b2c3d || echo "not a commit"
#
shell::git::commit::pick::validate() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Check that revisions resolve to commits and print their full hashes"
        shell::logger::usage "shell::git::commit::pick::validate [-q] [-h] <revision>..."
        shell::logger::item "revision" "A hash, branch, tag, HEAD~2, ..."
        shell::logger::option "-q, --quiet" "Print nothing; only the exit status tells"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::validate HEAD~2"
        shell::logger::example "shell::git::commit::pick::validate -q a1b2c3d"
        return "$RETURN_SUCCESS"
    fi

    local quiet="false" end_opts="false" rev hash bad=0 out=""
    local -a revs=()
    while [ "$#" -gt 0 ]; do
        if [ "$end_opts" = "false" ]; then
            case "$1" in
            -q | --quiet)
                quiet="true"
                shift
                continue
                ;;
            --)
                end_opts="true"
                shift
                continue
                ;;
            -?*)
                shell::logger::error "Unknown option: $1"
                return "$RETURN_INVALID"
                ;;
            esac
        fi
        revs+=("$1")
        shift
    done

    if [ "${#revs[@]}" -eq 0 ]; then
        shell::logger::error "At least one revision is required"
        return "$RETURN_INVALID"
    fi
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        if [ "$quiet" = "false" ]; then shell::logger::error "Not inside a Git repository"; fi
        return "$RETURN_FAILURE"
    fi

    for rev in "${revs[@]}"; do
        hash=""
        case "$rev" in
        '' | -*) ;;
        *) hash="$(git rev-parse --verify --quiet "${rev}^{commit}" 2>/dev/null)" ;;
        esac
        if [ -z "$hash" ]; then
            bad=$((bad + 1))
            if [ "$quiet" = "false" ]; then
                shell::logger::error "Not a valid commit: '${rev}'"
            fi
            continue
        fi
        out="$out$hash"$'\n'
    done

    if [ "$bad" -gt 0 ]; then
        return "$RETURN_FAILURE"
    fi
    if [ "$quiet" = "false" ]; then
        printf '%s' "$out"
    fi
    return "$RETURN_SUCCESS"
}

# @internal
# @description Print the paths that are still in conflict (unmerged), one per line.
#   Works whenever the index has unmerged entries, not only during a cherry-pick.
#   Paths are printed as they are (no quoting of unusual characters).
# @stdout The unmerged paths.
# @exitcode 0 Always.
# @example
#   [ -n "$(shell::git::commit::pick::conflict_files)" ] && echo "still conflicted"
#
shell::git::commit::pick::conflict_files() {
    git -c core.quotepath=off diff --name-only --diff-filter=U 2>/dev/null
}

# @description Cherry-picks one or more commits onto the current branch.
#
#   The general entry point behind the other `shell::git::commit::pick::*`
#   functions, which only add one flag each. Revisions are validated and applied
#   in the order given (use shell::git::commit::pick::range for a range, which
#   orders them for you). Before git runs, commits that would leave it stuck
#   half-way are dropped with a warning: ones already in HEAD (by hash, or by
#   patch when they were cherry-picked before), and empty ones (unless
#   `--allow-empty`). A merge commit needs `-m`.
#
#   It refuses to start during another cherry-pick, merge or revert, or with
#   staged changes (unless `--no-commit`). On a conflict git stops and the
#   repository is left for you to continue with shell::git::commit::pick::status,
#   conflicts, resolve and continue (or skip / abort).
# @option -x | --reference Optional. Append "(cherry picked from commit ...)" to each message.
# @option -s | --signoff Optional. Add a Signed-off-by trailer.
# @option --no-commit Optional. Apply the changes to the index and working tree without committing.
# @option --ff Optional. Fast-forward when HEAD is the parent of the commit (not with -x, -s or --no-commit).
# @option --allow-empty Optional. Keep commits that were empty to begin with.
# @option -m | --mainline Optional. Parent number to follow when the commit is a merge.
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @arg $@ string revision: One or more commits (hash, tag, HEAD~2, ...).
# @exitcode 0 Success (or the dry-run command was printed).
# @exitcode 1 The operation failed, stopped on a conflict, or there was nothing to apply.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::validate
# @see shell::git::commit::pick::range
# @example
#   shell::git::commit::pick::apply a1b2c3d
#   shell::git::commit::pick::apply -x a1b2c3d e4f5a6b
#   shell::git::commit::pick::apply -n --no-commit feature~2
#
shell::git::commit::pick::apply() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Cherry-pick one or more commits onto the current branch"
        shell::logger::usage "shell::git::commit::pick::apply [-n] [-x] [-s] [--no-commit] [--ff] [--allow-empty] [-m <N>] [--] <revision>..."
        shell::logger::item "revision" "Commits to apply, in the order given"
        shell::logger::option "-x, --reference" "Record the source commit in each message"
        shell::logger::option "-s, --signoff" "Add a Signed-off-by trailer"
        shell::logger::option "--no-commit" "Apply to the index/working tree without committing"
        shell::logger::option "--ff" "Fast-forward when possible (not with -x, -s, --no-commit)"
        shell::logger::option "--allow-empty" "Keep commits that were empty to begin with"
        shell::logger::option "-m, --mainline <N>" "Parent number to follow for a merge commit"
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::apply a1b2c3d"
        shell::logger::example "shell::git::commit::pick::apply -x a1b2c3d e4f5a6b"
        shell::logger::example "shell::git::commit::pick::apply -n --no-commit feature~2"
        return "$RETURN_SUCCESS"
    fi

    local dry_run="false" reference="false" signoff="false" no_commit="false" ff="false"
    local allow_empty="false" mainline="" end_opts="false" opt val
    local -a revs=()
    while [ "$#" -gt 0 ]; do
        if [ "$end_opts" = "false" ]; then
            case "$1" in
            -n | --dry-run)
                dry_run="true"
                shift
                continue
                ;;
            -x | --reference)
                reference="true"
                shift
                continue
                ;;
            -s | --signoff)
                signoff="true"
                shift
                continue
                ;;
            --no-commit)
                no_commit="true"
                shift
                continue
                ;;
            --ff)
                ff="true"
                shift
                continue
                ;;
            --allow-empty)
                allow_empty="true"
                shift
                continue
                ;;
            --)
                end_opts="true"
                shift
                continue
                ;;
            -m | --mainline | --mainline=*)
                opt="$1"
                case "$opt" in
                --mainline=*)
                    val="${opt#*=}"
                    shift
                    ;;
                *)
                    if [ "$#" -lt 2 ]; then
                        shell::logger::error "Option $opt requires a value"
                        return "$RETURN_INVALID"
                    fi
                    val="$2"
                    shift 2
                    ;;
                esac
                case "$val" in
                '' | *[!0-9]* | 0*)
                    shell::logger::error "--mainline must be a positive whole number (got '$val')"
                    return "$RETURN_INVALID"
                    ;;
                esac
                mainline="$val"
                continue
                ;;
            -?*)
                shell::logger::error "Unknown option: $1"
                return "$RETURN_INVALID"
                ;;
            esac
        fi
        revs+=("$1")
        shift
    done

    if [ "${#revs[@]}" -eq 0 ]; then
        shell::logger::error "At least one commit is required"
        return "$RETURN_INVALID"
    fi
    if [ "$ff" = "true" ] && { [ "$reference" = "true" ] || [ "$signoff" = "true" ] || [ "$no_commit" = "true" ]; }; then
        shell::logger::error "--ff cannot be combined with -x, -s or --no-commit (git refuses it)"
        return "$RETURN_INVALID"
    fi

    local guard_mode="commit"
    if [ "$no_commit" = "true" ]; then guard_mode="stage"; fi
    shell::git::commit::pick::guard "$guard_mode" || return "$RETURN_FAILURE"

    # Resolve, then keep only what can really be applied.
    local resolved planned hash branch count=0
    local -a hashes=() pick_args=(cherry-pick)
    resolved="$(shell::git::commit::pick::validate -- "${revs[@]}")" || return "$RETURN_FAILURE"
    while IFS= read -r hash; do
        if [ -n "$hash" ]; then hashes+=("$hash"); fi
    done <<EOF
$resolved
EOF

    planned="$(shell::git::commit::pick::plan "$mainline" "$allow_empty" HEAD "${hashes[@]}")" || return "$RETURN_FAILURE"
    hashes=()
    while IFS= read -r hash; do
        if [ -n "$hash" ]; then hashes+=("$hash"); fi
    done <<EOF
$planned
EOF
    count="${#hashes[@]}"

    if [ "$reference" = "true" ]; then pick_args+=(-x); fi
    if [ "$signoff" = "true" ]; then pick_args+=(-s); fi
    if [ "$no_commit" = "true" ]; then pick_args+=(--no-commit); fi
    if [ "$ff" = "true" ]; then pick_args+=(--ff); fi
    if [ "$allow_empty" = "true" ]; then pick_args+=(--allow-empty); fi
    if [ -n "$mainline" ]; then pick_args+=(-m "$mainline"); fi
    pick_args+=("${hashes[@]}")

    branch="$(git symbolic-ref --short -q HEAD 2>/dev/null)"
    shell::logger::info "Applying ${count} commit(s) onto '${branch:-detached HEAD}', oldest first:"
    for hash in "${hashes[@]}"; do
        shell::logger::info "  • $(git log -1 --format='%h %s' "$hash")"
    done

    if [ "$dry_run" = "true" ]; then
        shell::exec::command -n git "${pick_args[@]}"
        return "$RETURN_SUCCESS"
    fi

    if shell::exec::command git "${pick_args[@]}"; then
        if [ "$no_commit" = "true" ]; then
            shell::logger::success "Applied ${count} commit(s) to the index; review them and run git commit when ready"
        else
            shell::logger::success "Applied ${count} commit(s) onto '${branch:-detached HEAD}'"
        fi
        return "$RETURN_SUCCESS"
    fi

    if shell::git::commit::pick::in_progress; then
        if [ -z "$(shell::git::commit::pick::conflict_files)" ] && git diff --cached --quiet 2>/dev/null; then
            shell::logger::warn "The last commit became empty here (its changes are already in the branch); drop it with shell::git::commit::pick::skip, or stop with abort / quit"
        else
            shell::logger::warn "Stopped; resolve it with shell::git::commit::pick::status, conflicts, resolve, then continue (or skip / abort)"
        fi
    else
        shell::logger::error "git cherry-pick failed; nothing was left in progress"
    fi
    return "$RETURN_FAILURE"
}

# @description Cherry-picks commits without committing them.
#   Applies the changes to the index and working tree and stops, so several
#   commits can be squashed into one commit of your own, or edited first.
#   `git cherry-pick --no-commit`; see shell::git::commit::pick::apply for the
#   other options.
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @arg $@ string revision: One or more commits.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::apply
# @example
#   shell::git::commit::pick::no_commit a1b2c3d e4f5a6b
#
shell::git::commit::pick::no_commit() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Apply commits to the index and working tree without committing"
        shell::logger::usage "shell::git::commit::pick::no_commit [-n] [-h] <revision>..."
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::no_commit a1b2c3d e4f5a6b"
        return "$RETURN_SUCCESS"
    fi
    shell::git::commit::pick::apply --no-commit "$@"
}

# @description Cherry-picks commits, fast-forwarding when git can.
#   When HEAD is exactly the parent of the commit, the branch is moved to the
#   commit itself (same hash, linear history); otherwise git cherry-picks as
#   usual. `git cherry-pick --ff`; git refuses it together with -x, -s or --no-commit.
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @arg $@ string revision: One or more commits.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::apply
# @example
#   shell::git::commit::pick::ff a1b2c3d
#
shell::git::commit::pick::ff() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Cherry-pick, fast-forwarding when HEAD is the commit's parent"
        shell::logger::usage "shell::git::commit::pick::ff [-n] [-h] <revision>..."
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::ff a1b2c3d"
        return "$RETURN_SUCCESS"
    fi
    shell::git::commit::pick::apply --ff "$@"
}

# @description Cherry-picks a merge commit, following the parent you name.
#   `-m` says which parent is the mainline: `1` is the branch the merge was made
#   on (the usual choice), `2` the branch that was merged in. It is required, and
#   every revision must really be a merge with at least that many parents.
#   `git cherry-pick -m <N>`.
# @option -m | --mainline Required. Parent number to follow (1 = the branch merged into).
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @arg $@ string revision: One or more merge commits.
# @exitcode 0 Success.
# @exitcode 1 The operation failed (not a merge, mainline too large, conflict).
# @exitcode 2 Invalid usage, or -m missing.
# @see shell::git::commit::pick::apply
# @example
#   shell::git::commit::pick::merge -m 1 a1b2c3d
#
shell::git::commit::pick::merge() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Cherry-pick a merge commit, following the parent given with -m"
        shell::logger::usage "shell::git::commit::pick::merge [-n] -m <parent-number> [-h] <revision>..."
        shell::logger::option "-m, --mainline <N>" "Parent to follow: 1 = branch merged into, 2 = branch merged in"
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::merge -m 1 a1b2c3d"
        return "$RETURN_SUCCESS"
    fi

    local arg has_mainline="false"
    for arg in "$@"; do
        case "$arg" in
        --) break ;;
        -m | --mainline | --mainline=*) has_mainline="true" ;;
        esac
    done
    if [ "$has_mainline" = "false" ]; then
        shell::logger::error "-m <parent-number> is required (1 = the branch the merge was made on)"
        return "$RETURN_INVALID"
    fi
    shell::git::commit::pick::apply "$@"
}

# @description Cherry-picks commits, keeping the ones that were empty.
#   A commit with no changes is normally skipped (git would stop on it); this
#   keeps it, which preserves its message and metadata. `git cherry-pick --allow-empty`.
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @arg $@ string revision: One or more commits.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::apply
# @example
#   shell::git::commit::pick::empty a1b2c3d
#
shell::git::commit::pick::empty() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Cherry-pick commits, keeping those that were empty"
        shell::logger::usage "shell::git::commit::pick::empty [-n] [-h] <revision>..."
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::empty a1b2c3d"
        return "$RETURN_SUCCESS"
    fi
    shell::git::commit::pick::apply --allow-empty "$@"
}

# @description Cherry-picks commits and records where they came from.
#   Appends a line `(cherry picked from commit <hash>)` to each message, so a
#   backport can be traced to its source. `git cherry-pick -x`.
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @arg $@ string revision: One or more commits.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::apply
# @example
#   shell::git::commit::pick::with_reference a1b2c3d
#
shell::git::commit::pick::with_reference() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Cherry-pick and add a '(cherry picked from commit ...)' line"
        shell::logger::usage "shell::git::commit::pick::with_reference [-n] [-h] <revision>..."
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::with_reference a1b2c3d"
        return "$RETURN_SUCCESS"
    fi
    shell::git::commit::pick::apply -x "$@"
}

# @description Cherry-picks commits with a Signed-off-by trailer.
#   For projects that require the Developer Certificate of Origin. Uses your
#   `user.name` and `user.email`. `git cherry-pick -s`.
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @arg $@ string revision: One or more commits.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::apply
# @example
#   shell::git::commit::pick::signoff a1b2c3d
#
shell::git::commit::pick::signoff() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Cherry-pick and add a Signed-off-by trailer"
        shell::logger::usage "shell::git::commit::pick::signoff [-n] [-h] <revision>..."
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::signoff a1b2c3d"
        return "$RETURN_SUCCESS"
    fi
    shell::git::commit::pick::apply -s "$@"
}

# @description Cherry-picks a range of commits, oldest first.
#
#   Takes a git range `A..B` (commits reachable from B but not from A; use `A^..B`
#   to include A itself). The commits are listed in dependency order, parents
#   before children, and applied in that order. A range containing merge commits
#   is refused unless `--no-merges` leaves them out. Commits already in HEAD and
#   empty commits are skipped with a warning, as in shell::git::commit::pick::apply,
#   which also takes care of the rest (conflicts, -x, -s, --no-commit, ...).
# @option -x | --reference Optional. Record each source commit in the message.
# @option -s | --signoff Optional. Add a Signed-off-by trailer.
# @option --no-commit Optional. Apply without committing.
# @option --allow-empty Optional. Keep commits that were empty to begin with.
# @option --no-merges Optional. Leave merge commits out of the range.
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @arg $1 string range: `A..B`, e.g. `main..feature`, `v1.0..HEAD`, `a1b2c3d^..e4f5a6b`.
# @exitcode 0 Success.
# @exitcode 1 The operation failed, the range is empty, or it contains merges.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::apply
# @example
#   shell::git::commit::pick::range main..feature
#   shell::git::commit::pick::range -x --no-merges release/1.2..main
#
shell::git::commit::pick::range() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Cherry-pick a range of commits, oldest first"
        shell::logger::usage "shell::git::commit::pick::range [-n] [-x] [-s] [--no-commit] [--allow-empty] [--no-merges] <A..B>"
        shell::logger::item "A..B" "Commits reachable from B but not from A (A^..B includes A)"
        shell::logger::option "-x, --reference" "Record each source commit in the message"
        shell::logger::option "-s, --signoff" "Add a Signed-off-by trailer"
        shell::logger::option "--no-commit" "Apply without committing"
        shell::logger::option "--allow-empty" "Keep commits that were empty to begin with"
        shell::logger::option "--no-merges" "Leave merge commits out of the range"
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::range main..feature"
        shell::logger::example "shell::git::commit::pick::range -x --no-merges release/1.2..main"
        return "$RETURN_SUCCESS"
    fi

    local no_merges="false" end_opts="false" range="" have_range="false"
    local -a pass=()
    while [ "$#" -gt 0 ]; do
        if [ "$end_opts" = "false" ]; then
            case "$1" in
            --no-merges)
                no_merges="true"
                shift
                continue
                ;;
            -n | --dry-run | -x | --reference | -s | --signoff | --no-commit | --allow-empty)
                pass+=("$1")
                shift
                continue
                ;;
            --)
                end_opts="true"
                shift
                continue
                ;;
            -?*)
                shell::logger::error "Unknown option: $1"
                return "$RETURN_INVALID"
                ;;
            esac
        fi
        if [ "$have_range" = "true" ]; then
            shell::logger::error "Only one range is accepted (got '$range' and '$1')"
            return "$RETURN_INVALID"
        fi
        range="$1"
        have_range="true"
        shift
    done

    if [ "$have_range" = "false" ]; then
        shell::logger::error "A range is required, e.g. main..feature"
        return "$RETURN_INVALID"
    fi
    case "$range" in
    *...*)
        shell::logger::error "A three-dot range (A...B) has no order to replay; use A..B"
        return "$RETURN_INVALID"
        ;;
    *..*) ;;
    *)
        shell::logger::error "Not a range: '${range}' (expected A..B)"
        return "$RETURN_INVALID"
        ;;
    esac
    case "$range" in
    -*)
        shell::logger::error "Invalid range: '${range}'"
        return "$RETURN_INVALID"
        ;;
    esac
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        shell::logger::error "Not inside a Git repository"
        return "$RETURN_FAILURE"
    fi

    local side
    for side in "${range%%..*}" "${range#*..}"; do
        if [ -n "$side" ] && ! git rev-parse --verify --quiet "${side}^{commit}" >/dev/null 2>&1; then
            shell::logger::error "Not a valid commit in the range: '${side}'"
            return "$RETURN_FAILURE"
        fi
    done

    local merges list hash
    local -a hashes=() list_args=(rev-list --reverse --topo-order)
    merges="$(git rev-list --merges --count "$range" 2>/dev/null)"
    if [ "${merges:-0}" -gt 0 ]; then
        if [ "$no_merges" = "true" ]; then
            list_args+=(--no-merges)
        else
            shell::logger::error "The range contains ${merges} merge commit(s); add --no-merges to leave them out, or pick them one by one with shell::git::commit::pick::merge"
            return "$RETURN_FAILURE"
        fi
    fi

    list="$(git "${list_args[@]}" "$range" 2>/dev/null)"
    while IFS= read -r hash; do
        if [ -n "$hash" ]; then hashes+=("$hash"); fi
    done <<EOF
$list
EOF
    if [ "${#hashes[@]}" -eq 0 ]; then
        shell::logger::warn "No commits in ${range}"
        return "$RETURN_FAILURE"
    fi

    shell::logger::info "Range ${range}: ${#hashes[@]} commit(s)"
    shell::git::commit::pick::apply ${pass[@]+"${pass[@]}"} -- "${hashes[@]}"
}

# @description Shows what a commit contains before it is applied.
#
#   For each commit: its metadata (author, committer, dates, full message), the
#   files it changes, and the patch. Notes warn when the commit is a merge,
#   is already in HEAD, or is empty, since those would not apply as expected.
#   Read-only.
# @option -S | --stat Optional. Show only the metadata and the file summary, not the patch.
# @option -h | --help Show this help message.
# @arg $@ string revision: One or more commits.
# @exitcode 0 Success.
# @exitcode 1 A revision is not a valid commit, or not in a repository.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::validate
# @example
#   shell::git::commit::pick::preview a1b2c3d
#   shell::git::commit::pick::preview --stat feature~2 feature~1
#
shell::git::commit::pick::preview() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Show a commit's metadata, file summary and patch before applying it"
        shell::logger::usage "shell::git::commit::pick::preview [-S] [-h] <revision>..."
        shell::logger::option "-S, --stat" "Metadata and file summary only (no patch)"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::preview a1b2c3d"
        shell::logger::example "shell::git::commit::pick::preview --stat feature~2"
        return "$RETURN_SUCCESS"
    fi

    local stat_only="false" end_opts="false" resolved hash parents
    local -a revs=() show_args=()
    while [ "$#" -gt 0 ]; do
        if [ "$end_opts" = "false" ]; then
            case "$1" in
            -S | --stat)
                stat_only="true"
                shift
                continue
                ;;
            --)
                end_opts="true"
                shift
                continue
                ;;
            -?*)
                shell::logger::error "Unknown option: $1"
                return "$RETURN_INVALID"
                ;;
            esac
        fi
        revs+=("$1")
        shift
    done

    if [ "${#revs[@]}" -eq 0 ]; then
        shell::logger::error "At least one commit is required"
        return "$RETURN_INVALID"
    fi
    resolved="$(shell::git::commit::pick::validate -- "${revs[@]}")" || return "$RETURN_FAILURE"

    # --stat alone prints the summary without the patch; --patch adds the patch.
    show_args=(show --format=fuller --stat)
    if [ "$stat_only" = "false" ]; then
        show_args+=(--patch)
    fi

    while IFS= read -r hash; do
        if [ -z "$hash" ]; then continue; fi
        parents="$(git rev-list --parents -n 1 "$hash" 2>/dev/null | wc -w | tr -d ' ')"
        if [ "$((parents - 1))" -gt 1 ]; then
            shell::logger::warn "$(git log -1 --format='%h' "$hash") is a merge commit; applying it needs -m (shell::git::commit::pick::merge)"
        fi
        if git merge-base --is-ancestor "$hash" HEAD 2>/dev/null; then
            shell::logger::warn "$(git log -1 --format='%h' "$hash") is already contained in HEAD"
        fi
        if [ "$((parents - 1))" -le 1 ] && [ -z "$(git diff-tree --no-commit-id --name-only -r --root "$hash" 2>/dev/null)" ]; then
            shell::logger::warn "$(git log -1 --format='%h' "$hash") is an empty commit; applying it needs --allow-empty"
        fi
        git "${show_args[@]}" "$hash"
    done <<EOF
$resolved
EOF
    return "$RETURN_SUCCESS"
}

# @description Checks whether commits already exist on another branch, by patch.
#
#   Uses `git cherry`, which compares the *patch* of a commit with the commits
#   of the target, so a fix that was cherry-picked (a different hash, the same
#   change) is recognised. Use it before a backport to see what is still missing.
#   One line per commit on stdout: `<status><TAB><hash><TAB><subject>`, where the
#   status is `contained` (the commit itself is in the target), `equivalent`
#   (an equal patch is in the target), `missing`, or `unsupported` (merge and
#   root commits have no comparable patch).
# @option -t | --target Optional. The branch or revision to look in (default: HEAD).
# @option -q | --quiet Optional. Print nothing; only the exit status tells.
# @option -h | --help Show this help message.
# @arg $@ string revision: One or more commits to look for.
# @stdout One `status<TAB>hash<TAB>subject` line per commit.
# @exitcode 0 Every commit is already in the target (contained or equivalent).
# @exitcode 1 At least one is missing or unsupported, or a revision is invalid.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::validate
# @example
#   shell::git::commit::pick::equivalent a1b2c3d
#   shell::git::commit::pick::equivalent -t release/1.2 a1b2c3d e4f5a6b
#
shell::git::commit::pick::equivalent() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Check whether commits already exist on another branch (patch-equivalent)"
        shell::logger::usage "shell::git::commit::pick::equivalent [-t <target>] [-q] [-h] <revision>..."
        shell::logger::option "-t, --target <rev>" "Branch or revision to look in (default: HEAD)"
        shell::logger::option "-q, --quiet" "Print nothing; only the exit status tells"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::note "Status: contained | equivalent | missing | unsupported (merge or root commit). Exit 0 only when none is missing."
        shell::logger::example "shell::git::commit::pick::equivalent a1b2c3d"
        shell::logger::example "shell::git::commit::pick::equivalent -t release/1.2 a1b2c3d e4f5a6b"
        return "$RETURN_SUCCESS"
    fi

    local target="HEAD" quiet="false" end_opts="false" opt val resolved target_hash
    local hash parents status_word line missing=0 subject
    local -a revs=()
    while [ "$#" -gt 0 ]; do
        if [ "$end_opts" = "false" ]; then
            case "$1" in
            -q | --quiet)
                quiet="true"
                shift
                continue
                ;;
            -t | --target | --target=*)
                opt="$1"
                case "$opt" in
                --target=*)
                    val="${opt#*=}"
                    shift
                    ;;
                *)
                    if [ "$#" -lt 2 ]; then
                        shell::logger::error "Option $opt requires a value"
                        return "$RETURN_INVALID"
                    fi
                    val="$2"
                    shift 2
                    ;;
                esac
                target="$val"
                continue
                ;;
            --)
                end_opts="true"
                shift
                continue
                ;;
            -?*)
                shell::logger::error "Unknown option: $1"
                return "$RETURN_INVALID"
                ;;
            esac
        fi
        revs+=("$1")
        shift
    done

    if [ "${#revs[@]}" -eq 0 ]; then
        shell::logger::error "At least one commit is required"
        return "$RETURN_INVALID"
    fi
    if [ -z "$target" ]; then
        shell::logger::error "--target needs a value"
        return "$RETURN_INVALID"
    fi

    target_hash="$(shell::git::commit::pick::validate -- "$target")" || return "$RETURN_FAILURE"
    resolved="$(shell::git::commit::pick::validate -- "${revs[@]}")" || return "$RETURN_FAILURE"

    while IFS= read -r hash; do
        if [ -z "$hash" ]; then continue; fi
        subject="$(git log -1 --format='%s' "$hash" 2>/dev/null)"
        parents="$(git rev-list --parents -n 1 "$hash" 2>/dev/null | wc -w | tr -d ' ')"
        parents=$((parents - 1))

        if git merge-base --is-ancestor "$hash" "$target_hash" 2>/dev/null; then
            status_word="contained"
        elif [ "$parents" -ne 1 ]; then
            status_word="unsupported"
        else
            line="$(git cherry "$target_hash" "$hash" "${hash}^" 2>/dev/null | head -n 1)"
            case "$line" in
            -*) status_word="equivalent" ;;
            *) status_word="missing" ;;
            esac
        fi

        case "$status_word" in
        contained | equivalent) ;;
        *) missing=$((missing + 1)) ;;
        esac
        if [ "$quiet" = "false" ]; then
            printf '%s\t%s\t%s\n' "$status_word" "$hash" "$subject"
        fi
    done <<EOF
$resolved
EOF

    if [ "$missing" -gt 0 ]; then
        return "$RETURN_FAILURE"
    fi
    return "$RETURN_SUCCESS"
}

# @internal
# @description Print the sequencer's to-do list as `hash<TAB>subject`, one line per commit.
#   While git is stopped on a commit, that commit is the first line (it is also
#   `CHERRY_PICK_HEAD`). Comment lines are ignored and a `# ` in front of the
#   subject (newer git versions) is removed.
# @stdout The to-do entries.
# @exitcode 0 Always (nothing printed when there is no to-do list).
# @example
#   shell::git::commit::pick::todo | head -n 1
#
shell::git::commit::pick::todo() {
    local todo_file line rest hash subject
    todo_file="$(git rev-parse --git-path sequencer/todo 2>/dev/null)"
    if [ -z "$todo_file" ] || [ ! -s "$todo_file" ]; then
        return "$RETURN_SUCCESS"
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
        '' | '#'*) continue ;;
        esac
        rest="${line#* }"
        hash="${rest%% *}"
        subject=""
        case "$rest" in
        *' '*) subject="${rest#* }" ;;
        esac
        subject="${subject#\# }"
        printf '%s\t%s\n' "$hash" "$subject"
    done <"$todo_file"
}

# @internal
# @description Print the full hash git is stopped on (`CHERRY_PICK_HEAD`), if any.
# @stdout The 40-character hash.
# @exitcode 0 A commit is being picked.
# @exitcode 1 There is no `CHERRY_PICK_HEAD`.
# @example
#   hash="$(shell::git::commit::pick::head_hash)" || return $?
#
shell::git::commit::pick::head_hash() {
    local head_file hash
    head_file="$(git rev-parse --git-path CHERRY_PICK_HEAD 2>/dev/null)"
    if [ -z "$head_file" ] || [ ! -e "$head_file" ]; then
        return "$RETURN_FAILURE"
    fi
    hash="$(git rev-parse --verify --quiet CHERRY_PICK_HEAD 2>/dev/null)"
    if [ -z "$hash" ]; then
        return "$RETURN_FAILURE"
    fi
    printf '%s\n' "$hash"
}

# @description Shows the state of a cherry-pick in progress.
#
#   Reports the commit git is stopped on, how many commits are still waiting,
#   the files in conflict, and what is already staged, followed by the next step.
#   Exit status 0 means a cherry-pick is in progress and 1 that there is none,
#   so it can be used in a condition (`if shell::git::commit::pick::status -q`).
# @option -q | --quiet Optional. Print nothing; only the exit status tells.
# @option -h | --help Show this help message.
# @stdout The report (nothing with --quiet).
# @exitcode 0 A cherry-pick is in progress.
# @exitcode 1 No cherry-pick is in progress, or not in a repository.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::conflicts
# @see shell::git::commit::pick::continue
# @example
#   shell::git::commit::pick::status
#   shell::git::commit::pick::status -q && echo "busy"
#
shell::git::commit::pick::status() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Show the state of a cherry-pick in progress"
        shell::logger::usage "shell::git::commit::pick::status [-q] [-h]"
        shell::logger::option "-q, --quiet" "Print nothing; exit 0 when a cherry-pick is in progress, 1 otherwise"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::status"
        shell::logger::example "shell::git::commit::pick::status -q && echo busy"
        return "$RETURN_SUCCESS"
    fi

    local quiet="false"
    while [ "$#" -gt 0 ]; do
        case "$1" in
        -q | --quiet)
            quiet="true"
            shift
            ;;
        *)
            shell::logger::error "Unknown option or argument: $1"
            return "$RETURN_INVALID"
            ;;
        esac
    done

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        if [ "$quiet" = "false" ]; then shell::logger::error "Not inside a Git repository"; fi
        return "$RETURN_FAILURE"
    fi
    if ! shell::git::commit::pick::in_progress; then
        if [ "$quiet" = "false" ]; then shell::logger::info "No cherry-pick in progress"; fi
        return "$RETURN_FAILURE"
    fi
    if [ "$quiet" = "true" ]; then
        return "$RETURN_SUCCESS"
    fi

    local current="" current_line="" branch conflicts staged hash subject remaining=0 conflict_count=0 file
    local first="true"

    branch="$(git symbolic-ref --short -q HEAD 2>/dev/null)"
    current="$(shell::git::commit::pick::head_hash)" || current=""
    if [ -n "$current" ]; then
        current_line="$(git log -1 --format='%h %s' "$current" 2>/dev/null)"
    fi

    # The first to-do entry is the commit being handled (git drops it on --continue,
    # whether it stopped on it or you already committed it by hand); the rest wait.
    while IFS="$(printf '\t')" read -r hash subject; do
        if [ -z "$hash" ]; then continue; fi
        if [ "$first" = "true" ]; then
            first="false"
            continue
        fi
        remaining=$((remaining + 1))
    done <<EOF
$(shell::git::commit::pick::todo)
EOF

    conflicts="$(shell::git::commit::pick::conflict_files)"
    if [ -n "$conflicts" ]; then
        conflict_count="$(printf '%s\n' "$conflicts" | wc -l | tr -d ' ')"
    fi
    # Unmerged paths show up in --cached too; they are counted as conflicts, not as staged.
    staged="$(git diff --cached --name-only --diff-filter=ACDMRT 2>/dev/null | wc -l | tr -d ' ')"

    shell::logger::info "Cherry-pick in progress on '${branch:-detached HEAD}'"
    if [ -n "$current_line" ]; then
        shell::logger::info "  Stopped on : ${current_line}"
    else
        shell::logger::info "  Stopped between commits (you committed by hand; git carries on with the next one)"
    fi
    shell::logger::info "  Remaining  : ${remaining} commit(s) after it"
    shell::logger::info "  Staged     : ${staged} file(s)"
    shell::logger::info "  Conflicts  : ${conflict_count} file(s)"
    if [ -n "$conflicts" ]; then
        while IFS= read -r file; do
            shell::logger::info "    ✗ ${file}"
        done <<EOF
$conflicts
EOF
        shell::logger::info "Next: fix the files, then shell::git::commit::pick::resolve and shell::git::commit::pick::continue (or skip / abort)"
    else
        shell::logger::info "Next: shell::git::commit::pick::continue (or skip / abort)"
    fi
    return "$RETURN_SUCCESS"
}

# @description Shows the commit git is currently trying to apply.
#   That is the commit `CHERRY_PICK_HEAD` points to, the one that stopped with a
#   conflict. Exit status 1 when there is none.
# @option --hash Optional. Print only the full hash, for scripts.
# @option -h | --help Show this help message.
# @stdout The commit (hash, author, dates, message) or, with --hash, its full hash.
# @exitcode 0 A commit is being picked.
# @exitcode 1 No commit is being picked, or not in a repository.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::status
# @example
#   shell::git::commit::pick::current
#   hash="$(shell::git::commit::pick::current --hash)"
#
shell::git::commit::pick::current() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Show the commit currently being cherry-picked (CHERRY_PICK_HEAD)"
        shell::logger::usage "shell::git::commit::pick::current [--hash] [-h]"
        shell::logger::option "--hash" "Print only the full hash"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::current"
        shell::logger::example "shell::git::commit::pick::current --hash"
        return "$RETURN_SUCCESS"
    fi

    local hash_only="false" hash
    while [ "$#" -gt 0 ]; do
        case "$1" in
        --hash)
            hash_only="true"
            shift
            ;;
        *)
            shell::logger::error "Unknown option or argument: $1"
            return "$RETURN_INVALID"
            ;;
        esac
    done

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        shell::logger::error "Not inside a Git repository"
        return "$RETURN_FAILURE"
    fi
    if ! hash="$(shell::git::commit::pick::head_hash)"; then
        shell::logger::warn "No commit is being cherry-picked (CHERRY_PICK_HEAD not found)"
        return "$RETURN_FAILURE"
    fi

    if [ "$hash_only" = "true" ]; then
        printf '%s\n' "$hash"
        return "$RETURN_SUCCESS"
    fi
    git show --format=fuller --stat "$hash"
}

# @description Lists the files that are still in conflict.
#   One path per line on stdout, so it can be piped (`... | xargs`). Works for
#   any unresolved merge state, not only a cherry-pick. Exit status 0 means at
#   least one file is listed and 1 that there is no conflict.
# @option -h | --help Show this help message.
# @stdout The conflicted paths.
# @exitcode 0 At least one file is in conflict.
# @exitcode 1 No conflicts, or not in a repository.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::resolve
# @example
#   shell::git::commit::pick::conflicts
#   shell::git::commit::pick::conflicts | xargs "${EDITOR:-vi}"
#
shell::git::commit::pick::conflicts() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "List the files that are still in conflict"
        shell::logger::usage "shell::git::commit::pick::conflicts [-h]"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::conflicts"
        return "$RETURN_SUCCESS"
    fi
    if [ "$#" -gt 0 ]; then
        shell::logger::error "Unknown option or argument: $1"
        return "$RETURN_INVALID"
    fi
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        shell::logger::error "Not inside a Git repository"
        return "$RETURN_FAILURE"
    fi

    local files
    files="$(shell::git::commit::pick::conflict_files)"
    if [ -z "$files" ]; then
        shell::logger::info "No conflicted files" >&2
        return "$RETURN_FAILURE"
    fi
    printf '%s\n' "$files"
}

# @description Marks conflicted files as resolved (`git add`).
#
#   With no file names, every conflicted file is staged; otherwise only the
#   files you name, which must be in conflict. A file that still contains
#   conflict markers (`<<<<<<<` and `>>>>>>>` lines) is refused, because staging
#   it would commit the markers; `--force` overrides that. A file you deleted
#   to resolve a modify/delete conflict is staged as a deletion.
# @option -f | --force Optional. Stage files even if they still contain conflict markers.
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @arg $@ string file: Optional. Conflicted files to mark resolved (default: all of them).
# @exitcode 0 Success.
# @exitcode 1 No conflicts, a file still has markers, or git failed.
# @exitcode 2 A named file is not in conflict, or invalid usage.
# @see shell::git::commit::pick::conflicts
# @see shell::git::commit::pick::continue
# @example
#   shell::git::commit::pick::resolve
#   shell::git::commit::pick::resolve src/main.c docs/README.md
#
shell::git::commit::pick::resolve() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Mark conflicted files as resolved (git add)"
        shell::logger::usage "shell::git::commit::pick::resolve [-n] [-f] [--] [<file>...]"
        shell::logger::item "file" "Conflicted files to stage (default: all of them)"
        shell::logger::option "-f, --force" "Stage files even if conflict markers remain"
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::resolve"
        shell::logger::example "shell::git::commit::pick::resolve src/main.c"
        return "$RETURN_SUCCESS"
    fi

    local dry_run="false" force="false" end_opts="false" conflicts file left marked=0
    local -a files=() with_markers=()
    while [ "$#" -gt 0 ]; do
        if [ "$end_opts" = "false" ]; then
            case "$1" in
            -n | --dry-run)
                dry_run="true"
                shift
                continue
                ;;
            -f | --force)
                force="true"
                shift
                continue
                ;;
            --)
                end_opts="true"
                shift
                continue
                ;;
            -?*)
                shell::logger::error "Unknown option: $1"
                return "$RETURN_INVALID"
                ;;
            esac
        fi
        files+=("$1")
        shift
    done

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        shell::logger::error "Not inside a Git repository"
        return "$RETURN_FAILURE"
    fi
    conflicts="$(shell::git::commit::pick::conflict_files)"
    if [ -z "$conflicts" ]; then
        shell::logger::warn "There are no conflicted files"
        return "$RETURN_FAILURE"
    fi

    if [ "${#files[@]}" -eq 0 ]; then
        while IFS= read -r file; do
            if [ -n "$file" ]; then files+=("$file"); fi
        done <<EOF
$conflicts
EOF
    else
        for file in "${files[@]}"; do
            if ! printf '%s\n' "$conflicts" | grep -Fxq -- "$file"; then
                shell::logger::error "Not a conflicted file: ${file}"
                return "$RETURN_INVALID"
            fi
        done
    fi

    if [ "$force" = "false" ]; then
        for file in "${files[@]}"; do
            if [ -f "$file" ] && grep -Eq '^<<<<<<<( |$)' -- "$file" 2>/dev/null &&
                grep -Eq '^>>>>>>>( |$)' -- "$file" 2>/dev/null; then
                with_markers+=("$file")
            fi
        done
        if [ "${#with_markers[@]}" -gt 0 ]; then
            shell::logger::error "Conflict markers are still in ${#with_markers[@]} file(s); fix them first (or use --force):"
            for file in "${with_markers[@]}"; do
                shell::logger::error "  ✗ ${file}"
            done
            return "$RETURN_FAILURE"
        fi
    fi

    if [ "$dry_run" = "true" ]; then
        shell::exec::command -n git add -- "${files[@]}"
        return "$RETURN_SUCCESS"
    fi
    if ! shell::exec::command git add -- "${files[@]}"; then
        shell::logger::error "git add failed"
        return "$RETURN_FAILURE"
    fi

    left="$(shell::git::commit::pick::conflict_files)"
    if [ -n "$left" ]; then
        marked="$(printf '%s\n' "$left" | wc -l | tr -d ' ')"
        shell::logger::success "Marked ${#files[@]} file(s) as resolved; ${marked} still in conflict"
    else
        shell::logger::success "Marked ${#files[@]} file(s) as resolved; no conflicts left"
    fi
    return "$RETURN_SUCCESS"
}

# @description Lists the commits still waiting in a cherry-pick sequence.
#   Read from git's sequencer: the commits that come after the one it is
#   handling (stopped on, or already committed by hand), as
#   `<short hash> <subject>`, in the order they will be applied.
#   Exit status 0 means at least one is waiting and 1 that none is.
# @option -h | --help Show this help message.
# @stdout One `<short hash> <subject>` line per waiting commit.
# @exitcode 0 At least one commit is waiting.
# @exitcode 1 None is waiting, no cherry-pick is in progress, or not in a repository.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::status
# @example
#   shell::git::commit::pick::remaining
#
shell::git::commit::pick::remaining() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "List the commits still waiting in a cherry-pick sequence"
        shell::logger::usage "shell::git::commit::pick::remaining [-h]"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::remaining"
        return "$RETURN_SUCCESS"
    fi
    if [ "$#" -gt 0 ]; then
        shell::logger::error "Unknown option or argument: $1"
        return "$RETURN_INVALID"
    fi
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        shell::logger::error "Not inside a Git repository"
        return "$RETURN_FAILURE"
    fi
    if ! shell::git::commit::pick::in_progress; then
        shell::logger::info "No cherry-pick in progress" >&2
        return "$RETURN_FAILURE"
    fi

    local hash subject first="true" count=0

    # The first to-do entry is the commit being handled; the ones after it wait.
    while IFS="$(printf '\t')" read -r hash subject; do
        if [ -z "$hash" ]; then continue; fi
        if [ "$first" = "true" ]; then
            first="false"
            continue
        fi
        printf '%s %s\n' "$hash" "$subject"
        count=$((count + 1))
    done <<EOF
$(shell::git::commit::pick::todo)
EOF

    if [ "$count" -eq 0 ]; then
        shell::logger::info "No commits are waiting after the current one" >&2
        return "$RETURN_FAILURE"
    fi
    return "$RETURN_SUCCESS"
}

# @internal
# @description Run `git cherry-pick --continue | --skip | --abort | --quit`.
#   Shared by the four public functions. It checks that a cherry-pick really is
#   in progress (git's own message is unclear otherwise; `--quit` would even
#   "succeed" doing nothing) and, for `continue`, that no file is still in
#   conflict. When the sequence stops again on another conflict, it says so.
# @arg $1 string Action: continue, skip, abort or quit.
# @arg $@ string Options: `-n`/`--dry-run`, and `--no-edit` (continue only).
# @exitcode 0 Done.
# @exitcode 1 Nothing in progress, conflicts left, stopped again, or git failed.
# @exitcode 2 Invalid usage.
# @example
#   shell::git::commit::pick::control continue --no-edit
#
shell::git::commit::pick::control() {
    local action="${1-}"
    shift

    local dry_run="false" no_edit="false" conflicts count file
    while [ "$#" -gt 0 ]; do
        case "$1" in
        -n | --dry-run)
            dry_run="true"
            shift
            ;;
        --no-edit)
            if [ "$action" != "continue" ]; then
                shell::logger::error "--no-edit only applies to continue"
                return "$RETURN_INVALID"
            fi
            no_edit="true"
            shift
            ;;
        *)
            shell::logger::error "Unknown option or argument: $1"
            return "$RETURN_INVALID"
            ;;
        esac
    done

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        shell::logger::error "Not inside a Git repository"
        return "$RETURN_FAILURE"
    fi
    if ! shell::git::commit::pick::in_progress; then
        shell::logger::warn "No cherry-pick in progress; nothing to ${action}"
        return "$RETURN_FAILURE"
    fi

    if [ "$action" = "continue" ]; then
        conflicts="$(shell::git::commit::pick::conflict_files)"
        if [ -n "$conflicts" ]; then
            count="$(printf '%s\n' "$conflicts" | wc -l | tr -d ' ')"
            shell::logger::error "${count} file(s) are still in conflict; resolve them first (shell::git::commit::pick::resolve):"
            while IFS= read -r file; do
                shell::logger::error "  ✗ ${file}"
            done <<EOF
$conflicts
EOF
            return "$RETURN_FAILURE"
        fi
    fi

    local -a git_args=(cherry-pick "--${action}")
    if [ "$no_edit" = "true" ]; then
        git_args+=(--no-edit)
    fi

    if [ "$dry_run" = "true" ]; then
        shell::exec::command -n git "${git_args[@]}"
        return "$RETURN_SUCCESS"
    fi

    if [ "$action" = "abort" ]; then
        shell::logger::warn "Aborting puts HEAD back where the cherry-pick started and drops what it changed"
    fi

    if shell::exec::command git "${git_args[@]}"; then
        case "$action" in
        continue) shell::logger::success "Cherry-pick continued and completed" ;;
        skip) shell::logger::success "Commit skipped; the cherry-pick completed" ;;
        abort) shell::logger::success "Cherry-pick aborted; the branch is back where it started" ;;
        quit) shell::logger::success "Cherry-pick state cleared; the index and working tree were left as they are" ;;
        esac
        return "$RETURN_SUCCESS"
    fi

    if shell::git::commit::pick::in_progress; then
        shell::logger::warn "Stopped again (another conflict); see shell::git::commit::pick::status"
    else
        shell::logger::error "git cherry-pick --${action} failed"
    fi
    return "$RETURN_FAILURE"
}

# @description Continues a cherry-pick after the conflicts are resolved.
#   Refuses while any file is still in conflict (stage them with
#   shell::git::commit::pick::resolve first). It commits the commit git stopped
#   on and goes on with the rest of the sequence; if another conflict comes up
#   it stops there again.
# @option --no-edit Optional. Keep the commit message as it is instead of opening the editor.
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @exitcode 0 The cherry-pick completed.
# @exitcode 1 Nothing in progress, conflicts remain, or it stopped again.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::resolve
# @example
#   shell::git::commit::pick::continue
#   shell::git::commit::pick::continue --no-edit
#
shell::git::commit::pick::continue() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Continue a cherry-pick after the conflicts are resolved"
        shell::logger::usage "shell::git::commit::pick::continue [-n] [--no-edit] [-h]"
        shell::logger::option "--no-edit" "Keep the commit message without opening the editor"
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::continue --no-edit"
        return "$RETURN_SUCCESS"
    fi
    shell::git::commit::pick::control continue "$@"
}

# @description Skips the commit git is stopped on and goes on with the sequence.
#   Drops the pick that conflicted (its changes are discarded) and carries on
#   with the commits after it. `git cherry-pick --skip`.
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @exitcode 0 The sequence completed.
# @exitcode 1 Nothing in progress, or it stopped again.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::status
# @example
#   shell::git::commit::pick::skip
#
shell::git::commit::pick::skip() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Skip the commit that stopped the cherry-pick and carry on"
        shell::logger::usage "shell::git::commit::pick::skip [-n] [-h]"
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::skip"
        return "$RETURN_SUCCESS"
    fi
    shell::git::commit::pick::control skip "$@"
}

# @description Cancels the cherry-pick in progress and restores the branch.
#   Puts HEAD back where the whole sequence started and drops what it changed,
#   including commits already made by it and any conflict resolution you did.
#   `git cherry-pick --abort`. For a version that asks first, use
#   shell::git::commit::pick::fzf::abort.
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @exitcode 0 Aborted.
# @exitcode 1 Nothing in progress, or git failed.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::quit
# @see shell::git::commit::pick::fzf::abort
# @example
#   shell::git::commit::pick::abort
#
shell::git::commit::pick::abort() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Cancel the cherry-pick and restore the branch to where it started"
        shell::logger::usage "shell::git::commit::pick::abort [-n] [-h]"
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::note "This discards the cherry-pick's changes, including your conflict resolution."
        shell::logger::example "shell::git::commit::pick::abort"
        return "$RETURN_SUCCESS"
    fi
    shell::git::commit::pick::control abort "$@"
}

# @description Stops the cherry-pick but keeps everything as it is now.
#   Forgets the sequence (so a new cherry-pick can start) without touching HEAD,
#   the index or the working tree: whatever was applied stays, conflict markers
#   included. `git cherry-pick --quit`.
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @exitcode 0 The state was cleared.
# @exitcode 1 Nothing in progress, or git failed.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::abort
# @example
#   shell::git::commit::pick::quit
#
shell::git::commit::pick::quit() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Forget the cherry-pick state but keep the index and working tree"
        shell::logger::usage "shell::git::commit::pick::quit [-n] [-h]"
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::quit"
        return "$RETURN_SUCCESS"
    fi
    shell::git::commit::pick::control quit "$@"
}

# @description Applies commits onto a release or maintenance branch (a backport).
#
#   Step 1 — Check the state: a clean working tree (the branch is switched), no
#   cherry-pick in progress, a valid target and valid commits.
#   Step 2 — Work out what is really missing from the target: commits already in
#   it, and empty ones, are left out with a warning.
#   Step 3 — Create a new branch `backport/<target>/<short hash>` from the target
#   (or, with `--in-place`, switch to the target branch itself).
#   Step 4 — Cherry-pick the commits in the order given, with `-x` so each message
#   records its source (`--no-reference` turns that off).
#   Step 5 — Report the branch and the next step (push it, open a pull request).
#
#   A conflict leaves you on the backport branch, mid-cherry-pick, with the same
#   recovery as any cherry-pick (status, conflicts, resolve, continue / skip / abort).
#   If nothing could be applied, the new branch is removed and you are back where
#   you started. Nothing is ever pushed.
# @option -b | --branch Optional. Name of the new branch (an existing name is refused).
# @option --in-place Optional. Apply directly on the local target branch instead of a new branch.
# @option --no-reference Optional. Do not add the "(cherry picked from commit ...)" line.
# @option -s | --signoff Optional. Add a Signed-off-by trailer.
# @option --allow-empty Optional. Keep commits that were empty to begin with.
# @option -n | --dry-run Optional. Print the git commands instead of executing them.
# @option -h | --help Show this help message.
# @arg $1 string target: The release/maintenance branch (local or remote-tracking, e.g. `release/1.2`, `origin/release/1.2`).
# @arg $@ string revision: One or more commits to backport, oldest first.
# @exitcode 0 Success (or the dry-run commands were printed).
# @exitcode 1 The operation failed, stopped on a conflict, or there was nothing to apply.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::equivalent
# @see shell::git::commit::pick::fzf::backport
# @example
#   shell::git::commit::pick::backport release/1.2 a1b2c3d
#   shell::git::commit::pick::backport -n --in-place maintenance/2.x a1b2c3d e4f5a6b
#
shell::git::commit::pick::backport() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Backport commits onto a release or maintenance branch"
        shell::logger::usage "shell::git::commit::pick::backport [-n] [-b <name>] [--in-place] [--no-reference] [-s] [--allow-empty] <target> <revision>..."
        shell::logger::item "target" "Release branch (local or remote-tracking)"
        shell::logger::item "revision" "Commits to backport, oldest first"
        shell::logger::option "-b, --branch <name>" "Name of the new branch (default: backport/<target>/<hash>)"
        shell::logger::option "--in-place" "Apply on the local target branch itself"
        shell::logger::option "--no-reference" "Do not add the '(cherry picked from commit ...)' line"
        shell::logger::option "-s, --signoff" "Add a Signed-off-by trailer"
        shell::logger::option "--allow-empty" "Keep commits that were empty to begin with"
        shell::logger::option "-n, --dry-run" "Print the git commands instead of executing them"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::backport release/1.2 a1b2c3d"
        shell::logger::example "shell::git::commit::pick::backport -n --in-place maintenance/2.x a1b2c3d e4f5a6b"
        return "$RETURN_SUCCESS"
    fi

    local dry_run="false" custom="" in_place="false" reference="true" signoff="false" allow_empty="false"
    local end_opts="false" target="" have_target="false" opt val
    local -a revs=()
    while [ "$#" -gt 0 ]; do
        if [ "$end_opts" = "false" ]; then
            case "$1" in
            -n | --dry-run)
                dry_run="true"
                shift
                continue
                ;;
            --in-place)
                in_place="true"
                shift
                continue
                ;;
            --no-reference)
                reference="false"
                shift
                continue
                ;;
            -s | --signoff)
                signoff="true"
                shift
                continue
                ;;
            --allow-empty)
                allow_empty="true"
                shift
                continue
                ;;
            -b | --branch | --branch=*)
                opt="$1"
                case "$opt" in
                --branch=*)
                    val="${opt#*=}"
                    shift
                    ;;
                *)
                    if [ "$#" -lt 2 ]; then
                        shell::logger::error "Option $opt requires a value"
                        return "$RETURN_INVALID"
                    fi
                    val="$2"
                    shift 2
                    ;;
                esac
                custom="$val"
                continue
                ;;
            --)
                end_opts="true"
                shift
                continue
                ;;
            -?*)
                shell::logger::error "Unknown option: $1"
                return "$RETURN_INVALID"
                ;;
            esac
        fi
        if [ "$have_target" = "false" ]; then
            target="$1"
            have_target="true"
        else
            revs+=("$1")
        fi
        shift
    done

    if [ "$have_target" = "false" ] || [ -z "$target" ]; then
        shell::logger::error "A target branch is required"
        return "$RETURN_INVALID"
    fi
    if [ "${#revs[@]}" -eq 0 ]; then
        shell::logger::error "At least one commit to backport is required"
        return "$RETURN_INVALID"
    fi
    if [ "$in_place" = "true" ] && [ -n "$custom" ]; then
        shell::logger::error "--branch and --in-place cannot be combined"
        return "$RETURN_INVALID"
    fi
    if [ -n "$custom" ] && ! git check-ref-format --branch "$custom" >/dev/null 2>&1; then
        shell::logger::error "Invalid branch name: '${custom}'"
        return "$RETURN_INVALID"
    fi

    # Step 1 — state.
    shell::git::commit::pick::guard commit || return "$RETURN_FAILURE"
    local dirty
    dirty="$(git status --porcelain --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')"
    if [ "${dirty:-0}" -gt 0 ]; then
        shell::logger::error "The working tree has ${dirty} uncommitted change(s); commit or stash them first (the branch is switched)"
        return "$RETURN_FAILURE"
    fi

    local target_hash resolved planned hash orig_branch orig_hash name short n=2 base_name count
    local -a hashes=() flags=()
    target_hash="$(shell::git::commit::pick::validate -- "$target")" || return "$RETURN_FAILURE"
    if [ "$in_place" = "true" ] && ! git show-ref --verify --quiet "refs/heads/${target}"; then
        shell::logger::error "--in-place needs a local branch; '${target}' is not one"
        return "$RETURN_FAILURE"
    fi
    resolved="$(shell::git::commit::pick::validate -- "${revs[@]}")" || return "$RETURN_FAILURE"
    while IFS= read -r hash; do
        if [ -n "$hash" ]; then hashes+=("$hash"); fi
    done <<EOF
$resolved
EOF

    # Step 2 — what is really missing from the target.
    planned="$(shell::git::commit::pick::plan "" "$allow_empty" "$target_hash" "${hashes[@]}")" || return "$RETURN_FAILURE"
    hashes=()
    while IFS= read -r hash; do
        if [ -n "$hash" ]; then hashes+=("$hash"); fi
    done <<EOF
$planned
EOF
    count="${#hashes[@]}"

    orig_branch="$(git symbolic-ref --short -q HEAD 2>/dev/null)"
    orig_hash="$(git rev-parse HEAD 2>/dev/null)"

    # Step 3 — the branch to work on.
    if [ "$in_place" = "true" ]; then
        name="$target"
    else
        if [ -n "$custom" ]; then
            name="$custom"
            if git show-ref --verify --quiet "refs/heads/${name}"; then
                shell::logger::error "A branch named '${name}' already exists"
                return "$RETURN_FAILURE"
            fi
        else
            short="$(git rev-parse --short "$(printf '%s\n' "${hashes[@]}" | head -n 1)" 2>/dev/null)"
            base_name="backport/$(printf '%s' "$target" | sed 's#[^A-Za-z0-9._-]#-#g')/${short}"
            name="$base_name"
            while git show-ref --verify --quiet "refs/heads/${name}"; do
                name="${base_name}-${n}"
                n=$((n + 1))
            done
        fi
    fi

    if [ "$reference" = "true" ]; then flags+=(-x); fi
    if [ "$signoff" = "true" ]; then flags+=(-s); fi
    if [ "$allow_empty" = "true" ]; then flags+=(--allow-empty); fi

    shell::logger::info "Backport ${count} commit(s) to '${name}' (target ${target}):"
    for hash in "${hashes[@]}"; do
        shell::logger::info "  • $(git log -1 --format='%h %s' "$hash")"
    done

    if [ "$dry_run" = "true" ]; then
        if [ "$in_place" = "true" ]; then
            shell::exec::command -n git checkout "$target"
        else
            shell::exec::command -n git checkout -b "$name" --no-track "$target"
        fi
        shell::exec::command -n git cherry-pick ${flags[@]+"${flags[@]}"} "${hashes[@]}"
        return "$RETURN_SUCCESS"
    fi

    # Step 3 — switch.
    if [ "$in_place" = "true" ]; then
        shell::exec::command git checkout "$target" || {
            shell::logger::error "Could not switch to '${target}'"
            return "$RETURN_FAILURE"
        }
    else
        shell::exec::command git checkout -b "$name" --no-track "$target" || {
            shell::logger::error "Could not create '${name}' from '${target}'"
            return "$RETURN_FAILURE"
        }
    fi
    local start_hash
    start_hash="$(git rev-parse HEAD 2>/dev/null)"

    # Step 4 — apply.
    if shell::git::commit::pick::apply ${flags[@]+"${flags[@]}"} -- "${hashes[@]}"; then
        shell::logger::success "Backported ${count} commit(s) to '${name}'"
        shell::logger::info "You were on '${orig_branch:-${orig_hash}}'. Next: git push -u <remote> ${name}, then open a pull request"
        return "$RETURN_SUCCESS"
    fi

    if shell::git::commit::pick::in_progress; then
        shell::logger::warn "Stopped on '${name}'. Resolve and continue, or cancel everything: shell::git::commit::pick::abort, then git checkout ${orig_branch:-${orig_hash}}$([ "$in_place" = "false" ] && printf ' and git branch -D %s' "$name")"
        return "$RETURN_FAILURE"
    fi

    # Nothing was applied: undo the switch so no empty branch is left behind.
    if [ "$in_place" = "false" ] && [ "$(git rev-parse HEAD 2>/dev/null)" = "$start_hash" ]; then
        if [ -n "$orig_branch" ]; then
            git checkout --quiet "$orig_branch" 2>/dev/null
        else
            git checkout --quiet --detach "$orig_hash" 2>/dev/null
        fi
        git branch -D "$name" >/dev/null 2>&1
        shell::logger::warn "Nothing was applied; '${name}' was removed and you are back on '${orig_branch:-${orig_hash}}'"
    fi
    return "$RETURN_FAILURE"
}

# @internal
# @description List the branches that can be a source or a target, newest first.
#   Local branches, and optionally remote-tracking ones. The branch you are on
#   and the symbolic `<remote>/HEAD` refs are left out (a symbolic ref's short
#   name can look like a plain remote name, so the full ref name is checked).
# @arg $1 string `true` to include remote-tracking branches.
# @stdout One branch name per line.
# @exitcode 0 Always.
# @example
#   shell::git::commit::pick::branches true
#
shell::git::commit::pick::branches() {
    local current
    local -a refs=(refs/heads)
    if [ "${1-false}" = "true" ]; then
        refs+=(refs/remotes)
    fi
    current="$(git symbolic-ref --short -q HEAD 2>/dev/null)"
    git for-each-ref --sort=-committerdate --format='%(refname) %(refname:short)' "${refs[@]}" 2>/dev/null |
        awk -v cur="$current" '$1 !~ /\/HEAD$/ && $2 != cur { print $2 }'
}

# @internal
# @description List commits for a picker, newest first, as `hash<TAB>coloured line`.
#   Dependency order (`--topo-order`), merge commits left out (a merge needs `-m`
#   and is cherry-picked with shell::git::commit::pick::merge), capped at N.
#   The first column is the full hash, used by the picker's preview and by the
#   selection; fzf hides it.
# @arg $1 string Maximum number of commits.
# @arg $@ string Arguments for `git log` (revisions, `--all`, `--not HEAD`, ...).
# @stdout The picker lines.
# @exitcode 0 Always.
# @example
#   shell::git::commit::pick::fzf::candidates 500 --all --not HEAD
#
shell::git::commit::pick::fzf::candidates() {
    local count="${1-500}"
    shift
    git log --topo-order --no-merges "--max-count=${count}" --color=always \
        '--format=%H%x09%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%an%C(reset)%C(bold yellow)%d%C(reset) %C(dim white)- %s%C(reset)' \
        "$@" 2>/dev/null
}

# @internal
# @description Pick several commits with fzf and print their hashes, oldest first.
#   Multi-select (Tab marks), with a preview of the highlighted commit. The
#   hashes come back in dependency order (parents before children), which is the
#   order a cherry-pick must replay them in, whatever order they were marked in.
# @arg $1 string The candidate lines from shell::git::commit::pick::fzf::candidates.
# @arg $2 string Prompt text.
# @stdout The selected full hashes, one per line, oldest first.
# @exitcode 0 At least one commit was selected.
# @exitcode 9 Cancelled (ESC) or nothing selected.
# @example
#   hashes="$(shell::git::commit::pick::fzf::choose "$candidates" "Pick: ")" || return $?
#
shell::git::commit::pick::fzf::choose() {
    local candidates="${1-}" prompt="${2-Select commits: }" selected hashes
    local tab
    tab="$(printf '\t')"

    selected="$(printf '%s\n' "$candidates" | shell::fzf::select --multi --height=80% \
        "--delimiter=${tab}" --with-nth=2.. --prompt="$prompt" \
        '--preview=git show --stat --patch --color=always {1} | head -n 300' \
        --preview-window='right:55%:wrap')" || return "$RETURN_CANCELLED"
    if [ -z "$selected" ]; then
        return "$RETURN_CANCELLED"
    fi

    hashes="$(printf '%s\n' "$selected" | cut -f1 | tr '\n' ' ')"
    printf '%s\n' "$candidates" | awk -F'\t' -v sel="$hashes" '
        BEGIN { n = split(sel, a, " "); for (i = 1; i <= n; i++) s[a[i]] = 1 }
        ($1 in s) { list[++c] = $1 }
        END { for (i = c; i >= 1; i--) print list[i] }'
}

# @internal
# @description Pick commits with fzf, choose how to apply them, and apply them onto HEAD.
#   The shared engine of shell::git::commit::pick::fzf and its `local`, `remote`,
#   `branch` and `range` variants. Flow, every step with a way back:
#   1. a multi-select picker; 2. a menu: cherry-pick, cherry-pick with `-x`, apply
#   without committing, or preview (which returns to the menu); 3. the apply,
#   through shell::git::commit::pick::apply. ESC cancels.
# @arg $1 string `true` for a dry-run.
# @arg $2 string Maximum number of commits listed.
# @arg $3 string Picker prompt.
# @arg $@ string Arguments for `git log` selecting the commits to list.
# @exitcode 0 The commits were applied (or the dry-run commands printed).
# @exitcode 1 Cancelled, nothing to pick, or the apply failed or stopped on a conflict.
# @example
#   shell::git::commit::pick::fzf::engine false 500 "Pick: " --all --not HEAD
#
shell::git::commit::pick::fzf::engine() {
    local dry_run="${1-false}" count="${2-500}" prompt="${3-Select commits: }"
    shift 3

    shell::git::commit::pick::guard stage || return "$RETURN_FAILURE"

    local candidates step choice rc hash
    local -a hashes=() flags=()
    candidates="$(shell::git::commit::pick::fzf::candidates "$count" "$@")"
    if [ -z "$candidates" ]; then
        shell::logger::warn "No commits to pick from"
        return "$RETURN_FAILURE"
    fi

    step="pick"
    while true; do
        case "$step" in
        pick)
            choice="$(shell::git::commit::pick::fzf::choose "$candidates" "$prompt")"
            rc=$?
            if [ "$rc" -ne 0 ] || [ -z "$choice" ]; then
                shell::logger::info "Cancelled — nothing was applied"
                return "$RETURN_FAILURE"
            fi
            hashes=()
            while IFS= read -r hash; do
                if [ -n "$hash" ]; then hashes+=("$hash"); fi
            done <<EOF
$choice
EOF
            step="action"
            ;;
        action)
            shell::logger::info "${#hashes[@]} commit(s) selected, oldest first:"
            for hash in "${hashes[@]}"; do
                shell::logger::info "  • $(git log -1 --format='%h %s' "$hash")"
            done
            choice="$(shell::ask::option::back --prompt "Apply the selected commits: " \
                "Cherry-pick" "Cherry-pick with reference (-x)" "Apply without committing (--no-commit)" "Preview only")"
            rc=$?
            case "$rc" in
            0) ;;
            "$RETURN_BACK")
                step="pick"
                continue
                ;;
            *)
                shell::logger::info "Cancelled — nothing was applied"
                return "$RETURN_FAILURE"
                ;;
            esac

            flags=()
            case "$choice" in
            "Preview only")
                shell::git::commit::pick::preview -- "${hashes[@]}"
                continue
                ;;
            "Cherry-pick with reference (-x)") flags+=(-x) ;;
            "Apply without committing (--no-commit)") flags+=(--no-commit) ;;
            esac
            if [ "$dry_run" = "true" ]; then flags+=(-n); fi
            shell::git::commit::pick::apply ${flags[@]+"${flags[@]}"} -- "${hashes[@]}"
            return $?
            ;;
        esac
    done
}

# @internal
# @description Parse the options every picker shares: `-n`, `-c <N>` and `-h`.
#   Sets `fzf_dry_run` and `fzf_count` in the caller (the callers declare them)
#   and leaves the remaining arguments in `fzf_rest` (a newline-separated string).
# @arg $@ string The caller's arguments.
# @stderr The reason for an invalid option.
# @exitcode 0 Parsed.
# @exitcode 2 Invalid usage.
# @example
#   shell::git::commit::pick::fzf::parse "$@" || return $?
#
shell::git::commit::pick::fzf::parse() {
    fzf_dry_run="false"
    fzf_count="500"
    fzf_rest=""
    local opt val
    while [ "$#" -gt 0 ]; do
        case "$1" in
        -n | --dry-run)
            fzf_dry_run="true"
            shift
            ;;
        -c | --count | --count=*)
            opt="$1"
            case "$opt" in
            --count=*)
                val="${opt#*=}"
                shift
                ;;
            *)
                if [ "$#" -lt 2 ]; then
                    shell::logger::error "Option $opt requires a value"
                    return "$RETURN_INVALID"
                fi
                val="$2"
                shift 2
                ;;
            esac
            case "$val" in
            '' | *[!0-9]* | 0*)
                shell::logger::error "--count must be a positive whole number (got '$val')"
                return "$RETURN_INVALID"
                ;;
            esac
            fzf_count="$val"
            ;;
        --)
            shift
            while [ "$#" -gt 0 ]; do
                fzf_rest="${fzf_rest}${1}"$'\n'
                shift
            done
            ;;
        -?*)
            if [ "${fzf_extra_ok-}" = "true" ]; then
                fzf_rest="${fzf_rest}${1}"$'\n'
                shift
            else
                shell::logger::error "Unknown option: $1"
                return "$RETURN_INVALID"
            fi
            ;;
        *)
            fzf_rest="${fzf_rest}${1}"$'\n'
            shift
            ;;
        esac
    done
    return "$RETURN_SUCCESS"
}

# @description Finds commits with fzf and cherry-picks the ones you select.
#
#   Lists the commits of all refs (or of one revision) that are not yet in HEAD,
#   newest first, with a preview of the highlighted one. Mark one or more with
#   Tab, choose how to apply them (cherry-pick, with `-x`, without committing, or
#   just preview), and they are replayed oldest first. Merge commits are not
#   listed. A back entry in the menu returns to the list; ESC cancels.
# @option --include-head Optional. Also list commits already in HEAD (they are skipped when applied).
# @option -c | --count Optional. Maximum number of commits listed (default 500).
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @arg $1 string source: Optional. Limit the list to the history of this revision (branch, tag, ...).
# @exitcode 0 The commits were applied.
# @exitcode 1 Cancelled, nothing to pick, or the cherry-pick failed or stopped on a conflict.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::apply
# @example
#   shell::git::commit::pick::fzf
#   shell::git::commit::pick::fzf feature/login
#   shell::git::commit::pick::fzf -c 100 -n
#
shell::git::commit::pick::fzf() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Find commits with fzf (preview, multi-select) and cherry-pick them"
        shell::logger::usage "shell::git::commit::pick::fzf [-n] [-c <N>] [--include-head] [<source>]"
        shell::logger::item "source" "Only the history of this revision (default: all refs)"
        shell::logger::option "--include-head" "Also list commits already in HEAD"
        shell::logger::option "-c, --count <N>" "Maximum commits listed (default 500)"
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::note "Tab marks several commits; they are applied oldest first."
        shell::logger::example "shell::git::commit::pick::fzf"
        shell::logger::example "shell::git::commit::pick::fzf feature/login"
        return "$RETURN_SUCCESS"
    fi

    local fzf_dry_run fzf_count fzf_rest include_head="false" source="" item
    local fzf_extra_ok="true"
    shell::git::commit::pick::fzf::parse "$@" || return $?

    local -a rest=() log_args=()
    while IFS= read -r item; do
        case "$item" in
        '') ;;
        --include-head) include_head="true" ;;
        -*)
            shell::logger::error "Unknown option: $item"
            return "$RETURN_INVALID"
            ;;
        *)
            if [ -n "$source" ]; then
                shell::logger::error "Only one source is accepted (got '$source' and '$item')"
                return "$RETURN_INVALID"
            fi
            source="$item"
            ;;
        esac
    done <<EOF
$fzf_rest
EOF

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        shell::logger::error "Not inside a Git repository"
        return "$RETURN_FAILURE"
    fi
    if [ -n "$source" ]; then
        shell::git::commit::pick::validate -q -- "$source" || {
            shell::logger::error "Not a valid commit: '${source}'"
            return "$RETURN_FAILURE"
        }
        log_args+=("$source")
    else
        log_args+=(--all)
    fi
    if [ "$include_head" = "false" ]; then log_args+=(--not HEAD); fi

    shell::git::commit::pick::fzf::engine "$fzf_dry_run" "$fzf_count" "Cherry-pick (Tab to mark): " "${log_args[@]}"
}

# @description Picks commits from the local branches and cherry-picks them.
#   Like shell::git::commit::pick::fzf, but listing only commits that live on
#   local branches and are not in HEAD. An optional argument narrows the
#   branches: the exact name of one branch, or a glob such as `feature/*`.
# @option --include-head Optional. Also list commits already in HEAD.
# @option -c | --count Optional. Maximum number of commits listed (default 500).
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @arg $1 string pattern: Optional. A branch name, or a glob selecting branches (e.g. `feature/*`).
# @exitcode 0 The commits were applied.
# @exitcode 1 Cancelled, nothing to pick, or the cherry-pick failed.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::fzf
# @example
#   shell::git::commit::pick::fzf::local
#   shell::git::commit::pick::fzf::local 'hotfix/*'
#
shell::git::commit::pick::fzf::local() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Pick commits from the local branches with fzf and cherry-pick them"
        shell::logger::usage "shell::git::commit::pick::fzf::local [-n] [-c <N>] [--include-head] [<branch-glob>]"
        shell::logger::item "branch-glob" "Only branches matching this glob (e.g. 'feature/*')"
        shell::logger::option "--include-head" "Also list commits already in HEAD"
        shell::logger::option "-c, --count <N>" "Maximum commits listed (default 500)"
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::fzf::local"
        shell::logger::example "shell::git::commit::pick::fzf::local 'hotfix/*'"
        return "$RETURN_SUCCESS"
    fi

    local fzf_dry_run fzf_count fzf_rest include_head="false" pattern="" item
    local fzf_extra_ok="true"
    shell::git::commit::pick::fzf::parse "$@" || return $?
    while IFS= read -r item; do
        case "$item" in
        '') ;;
        --include-head) include_head="true" ;;
        -*)
            shell::logger::error "Unknown option: $item"
            return "$RETURN_INVALID"
            ;;
        *)
            if [ -n "$pattern" ]; then
                shell::logger::error "Only one branch pattern is accepted"
                return "$RETURN_INVALID"
            fi
            pattern="$item"
            ;;
        esac
    done <<EOF
$fzf_rest
EOF

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        shell::logger::error "Not inside a Git repository"
        return "$RETURN_FAILURE"
    fi
    local -a log_args=()
    if [ -z "$pattern" ]; then
        log_args+=(--branches)
    else
        case "$pattern" in
        *[\*\?\[]*) log_args+=("--branches=${pattern}") ;;
        *)
            # git reads a pattern without glob characters as "<pattern>/*", which
            # would miss the branch of that exact name; an existing branch is used as is.
            if git show-ref --verify --quiet "refs/heads/${pattern}"; then
                log_args+=("$pattern")
            else
                log_args+=("--branches=${pattern}")
            fi
            ;;
        esac
    fi
    if [ "$include_head" = "false" ]; then log_args+=(--not HEAD); fi

    shell::git::commit::pick::fzf::engine "$fzf_dry_run" "$fzf_count" "Cherry-pick from local branches: " "${log_args[@]}"
}

# @description Picks commits from the remote-tracking branches and cherry-picks them.
#   Like shell::git::commit::pick::fzf, but listing only commits reachable from
#   remote-tracking refs (what the last fetch brought) and not in HEAD. An
#   optional remote name narrows it, e.g. `origin`.
# @option --include-head Optional. Also list commits already in HEAD.
# @option -c | --count Optional. Maximum number of commits listed (default 500).
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @arg $1 string remote: Optional. Only this remote (e.g. `origin`).
# @exitcode 0 The commits were applied.
# @exitcode 1 Cancelled, nothing to pick, or the cherry-pick failed.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::fzf
# @example
#   shell::git::commit::pick::fzf::remote
#   shell::git::commit::pick::fzf::remote origin
#
shell::git::commit::pick::fzf::remote() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Pick commits from the remote-tracking branches with fzf and cherry-pick them"
        shell::logger::usage "shell::git::commit::pick::fzf::remote [-n] [-c <N>] [--include-head] [<remote>]"
        shell::logger::item "remote" "Only this remote (e.g. origin)"
        shell::logger::option "--include-head" "Also list commits already in HEAD"
        shell::logger::option "-c, --count <N>" "Maximum commits listed (default 500)"
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::note "Run git fetch first: only what is already fetched can be listed."
        shell::logger::example "shell::git::commit::pick::fzf::remote origin"
        return "$RETURN_SUCCESS"
    fi

    local fzf_dry_run fzf_count fzf_rest include_head="false" remote="" item
    local fzf_extra_ok="true"
    shell::git::commit::pick::fzf::parse "$@" || return $?
    while IFS= read -r item; do
        case "$item" in
        '') ;;
        --include-head) include_head="true" ;;
        -*)
            shell::logger::error "Unknown option: $item"
            return "$RETURN_INVALID"
            ;;
        *)
            if [ -n "$remote" ]; then
                shell::logger::error "Only one remote is accepted"
                return "$RETURN_INVALID"
            fi
            remote="$item"
            ;;
        esac
    done <<EOF
$fzf_rest
EOF

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        shell::logger::error "Not inside a Git repository"
        return "$RETURN_FAILURE"
    fi
    local -a log_args=()
    if [ -n "$remote" ]; then
        log_args+=("--remotes=${remote}")
    else
        log_args+=(--remotes)
    fi
    if [ "$include_head" = "false" ]; then log_args+=(--not HEAD); fi

    shell::git::commit::pick::fzf::engine "$fzf_dry_run" "$fzf_count" "Cherry-pick from remote branches: " "${log_args[@]}"
}

# @description Picks a local branch first, then the commits to cherry-pick from it.
#   Two steps: choose the source branch (most recently updated first, with a
#   preview of its latest commits), then mark commits from it that are not in
#   HEAD. Narrowing to one branch keeps the commit list short.
# @option -c | --count Optional. Maximum number of commits listed (default 500).
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @exitcode 0 The commits were applied.
# @exitcode 1 Cancelled, nothing to pick, or the cherry-pick failed.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::fzf
# @example
#   shell::git::commit::pick::fzf::branch
#
shell::git::commit::pick::fzf::branch() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Choose a local branch with fzf, then pick its commits to cherry-pick"
        shell::logger::usage "shell::git::commit::pick::fzf::branch [-n] [-c <N>] [-h]"
        shell::logger::option "-c, --count <N>" "Maximum commits listed (default 500)"
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::fzf::branch"
        return "$RETURN_SUCCESS"
    fi

    local fzf_dry_run fzf_count fzf_rest
    local fzf_extra_ok="false"
    shell::git::commit::pick::fzf::parse "$@" || return $?
    if [ -n "$fzf_rest" ]; then
        shell::logger::error "Unexpected argument: ${fzf_rest%%$'\n'*}"
        return "$RETURN_INVALID"
    fi
    shell::git::commit::pick::guard stage || return "$RETURN_FAILURE"

    local branches picked
    branches="$(shell::git::commit::pick::branches false)"
    if [ -z "$branches" ]; then
        shell::logger::warn "There is no other local branch"
        return "$RETURN_FAILURE"
    fi

    picked="$(printf '%s\n' "$branches" | shell::fzf::select --height=60% --prompt="Source branch: " \
        '--preview=git log --oneline --color=always -n 15 {}' --preview-window='right:55%:wrap')" || {
        shell::logger::info "Cancelled — nothing was applied"
        return "$RETURN_FAILURE"
    }
    if [ -z "$picked" ]; then
        return "$RETURN_FAILURE"
    fi

    shell::git::commit::pick::fzf::engine "$fzf_dry_run" "$fzf_count" "Cherry-pick from ${picked}: " "$picked" --not HEAD
}

# @description Picks commits from the current branch's own history.
#   Lists the history of the current branch, lets you mark commits, then asks
#   which other local branch should receive them and applies them there (the
#   branch is switched, with `-x`). The commits are already in HEAD, so applying
#   them onto the same branch would do nothing; this is for moving or copying
#   commits made on the wrong branch. Needs a clean working tree.
# @option -c | --count Optional. Maximum number of commits listed (default 500).
# @option -n | --dry-run Optional. Print the git commands instead of executing them.
# @option -h | --help Show this help message.
# @exitcode 0 The commits were applied on the other branch.
# @exitcode 1 Cancelled, nothing to pick, or the backport failed or stopped on a conflict.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::backport
# @example
#   shell::git::commit::pick::fzf::current
#
shell::git::commit::pick::fzf::current() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Pick commits from this branch's history and apply them onto another branch"
        shell::logger::usage "shell::git::commit::pick::fzf::current [-n] [-c <N>] [-h]"
        shell::logger::option "-c, --count <N>" "Maximum commits listed (default 500)"
        shell::logger::option "-n, --dry-run" "Print the git commands instead of executing them"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::note "These commits are already in HEAD, so they are applied onto a branch you choose next."
        shell::logger::example "shell::git::commit::pick::fzf::current"
        return "$RETURN_SUCCESS"
    fi

    local fzf_dry_run fzf_count fzf_rest
    local fzf_extra_ok="false"
    shell::git::commit::pick::fzf::parse "$@" || return $?
    if [ -n "$fzf_rest" ]; then
        shell::logger::error "Unexpected argument: ${fzf_rest%%$'\n'*}"
        return "$RETURN_INVALID"
    fi
    shell::git::commit::pick::guard stage || return "$RETURN_FAILURE"

    local current candidates branches step choice rc hash target
    local -a hashes=() backport_args=() branch_list=()
    current="$(git symbolic-ref --short -q HEAD 2>/dev/null)"
    candidates="$(shell::git::commit::pick::fzf::candidates "$fzf_count" HEAD)"
    if [ -z "$candidates" ]; then
        shell::logger::warn "No commits to pick from"
        return "$RETURN_FAILURE"
    fi
    branches="$(shell::git::commit::pick::branches false)"
    if [ -z "$branches" ]; then
        shell::logger::warn "There is no other local branch to apply the commits onto"
        return "$RETURN_FAILURE"
    fi
    while IFS= read -r hash; do
        if [ -n "$hash" ]; then branch_list+=("$hash"); fi
    done <<EOF
$branches
EOF

    step="pick"
    while true; do
        case "$step" in
        pick)
            choice="$(shell::git::commit::pick::fzf::choose "$candidates" "Commits of ${current:-HEAD} (Tab to mark): ")"
            rc=$?
            if [ "$rc" -ne 0 ] || [ -z "$choice" ]; then
                shell::logger::info "Cancelled — nothing was applied"
                return "$RETURN_FAILURE"
            fi
            hashes=()
            while IFS= read -r hash; do
                if [ -n "$hash" ]; then hashes+=("$hash"); fi
            done <<EOF
$choice
EOF
            step="target"
            ;;
        target)
            choice="$(shell::ask::option::back --prompt "Apply onto branch: " "${branch_list[@]}")"
            rc=$?
            case "$rc" in
            0) target="$choice" ;;
            "$RETURN_BACK")
                step="pick"
                continue
                ;;
            *)
                shell::logger::info "Cancelled — nothing was applied"
                return "$RETURN_FAILURE"
                ;;
            esac
            step="confirm"
            ;;
        confirm)
            shell::logger::info "${#hashes[@]} commit(s) from '${current}' will be applied onto '${target}' (the branch is switched):"
            for hash in "${hashes[@]}"; do
                shell::logger::info "  • $(git log -1 --format='%h %s' "$hash")"
            done
            choice="$(shell::ask::option::back --prompt "Proceed? " "Apply onto ${target}" "Abort")"
            rc=$?
            case "$rc" in
            0) ;;
            "$RETURN_BACK")
                step="target"
                continue
                ;;
            *)
                shell::logger::info "Cancelled — nothing was applied"
                return "$RETURN_FAILURE"
                ;;
            esac
            if [ "$choice" != "Apply onto ${target}" ]; then
                shell::logger::info "Cancelled — nothing was applied"
                return "$RETURN_FAILURE"
            fi
            backport_args=(--in-place)
            if [ "$fzf_dry_run" = "true" ]; then backport_args+=(-n); fi
            shell::git::commit::pick::backport "${backport_args[@]}" "$target" "${hashes[@]}"
            return $?
            ;;
        esac
    done
}

# @description Picks the commits of a range one by one and cherry-picks the chosen ones.
#   Where shell::git::commit::pick::range applies the whole range, this lists the
#   commits of `A..B` so you can mark only some of them. They are applied oldest
#   first.
# @option -c | --count Optional. Maximum number of commits listed (default 500).
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @arg $1 string range: `A..B`, e.g. `main..feature`.
# @exitcode 0 The chosen commits were applied.
# @exitcode 1 Cancelled, the range is empty, or the cherry-pick failed.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::range
# @example
#   shell::git::commit::pick::fzf::range main..feature
#
shell::git::commit::pick::fzf::range() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Choose some of the commits of a range with fzf and cherry-pick them"
        shell::logger::usage "shell::git::commit::pick::fzf::range [-n] [-c <N>] [-h] <A..B>"
        shell::logger::item "A..B" "Commits reachable from B but not from A"
        shell::logger::option "-c, --count <N>" "Maximum commits listed (default 500)"
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::fzf::range main..feature"
        return "$RETURN_SUCCESS"
    fi

    local fzf_dry_run fzf_count fzf_rest range side
    local fzf_extra_ok="false"
    shell::git::commit::pick::fzf::parse "$@" || return $?
    range="${fzf_rest%%$'\n'*}"
    if [ -z "$range" ]; then
        shell::logger::error "A range is required, e.g. main..feature"
        return "$RETURN_INVALID"
    fi
    if [ "$(printf '%s' "$fzf_rest" | grep -c .)" -gt 1 ]; then
        shell::logger::error "Only one range is accepted"
        return "$RETURN_INVALID"
    fi
    case "$range" in
    *...*)
        shell::logger::error "A three-dot range (A...B) has no order to replay; use A..B"
        return "$RETURN_INVALID"
        ;;
    *..*) ;;
    *)
        shell::logger::error "Not a range: '${range}' (expected A..B)"
        return "$RETURN_INVALID"
        ;;
    esac
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        shell::logger::error "Not inside a Git repository"
        return "$RETURN_FAILURE"
    fi
    for side in "${range%%..*}" "${range#*..}"; do
        if [ -n "$side" ] && ! git rev-parse --verify --quiet "${side}^{commit}" >/dev/null 2>&1; then
            shell::logger::error "Not a valid commit in the range: '${side}'"
            return "$RETURN_FAILURE"
        fi
    done

    shell::git::commit::pick::fzf::engine "$fzf_dry_run" "$fzf_count" "Cherry-pick from ${range}: " "$range"
}

# @description Picks commits with fzf and backports them to a release branch.
#   Three steps, each with a way back: choose the target branch (local or
#   remote-tracking; pass it to skip this step), mark the commits to backport
#   (only those missing from the target are listed), then confirm. The work is
#   done by shell::git::commit::pick::backport: a new branch from the target
#   (or the target itself with `--in-place`), cherry-picked with `-x`.
# @option -s | --source Optional. Only list commits from the history of this revision (e.g. `main`).
# @option --in-place Optional. Apply on the local target branch instead of a new branch.
# @option -b | --branch Optional. Name of the new branch.
# @option -c | --count Optional. Maximum number of commits listed (default 500).
# @option -n | --dry-run Optional. Print the git commands instead of executing them.
# @option -h | --help Show this help message.
# @arg $1 string target: Optional. The release branch; omit to choose it with fzf.
# @exitcode 0 The commits were backported.
# @exitcode 1 Cancelled, nothing to pick, or the backport failed or stopped on a conflict.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::backport
# @example
#   shell::git::commit::pick::fzf::backport
#   shell::git::commit::pick::fzf::backport release/1.2 --source main
#
shell::git::commit::pick::fzf::backport() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Pick commits with fzf and backport them to a release branch"
        shell::logger::usage "shell::git::commit::pick::fzf::backport [-n] [-c <N>] [-s <rev>] [--in-place] [-b <name>] [<target>]"
        shell::logger::item "target" "Release branch; omit to choose it with fzf"
        shell::logger::option "-s, --source <rev>" "Only commits from the history of this revision"
        shell::logger::option "--in-place" "Apply on the local target branch itself"
        shell::logger::option "-b, --branch <name>" "Name of the new branch"
        shell::logger::option "-c, --count <N>" "Maximum commits listed (default 500)"
        shell::logger::option "-n, --dry-run" "Print the git commands instead of executing them"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::fzf::backport"
        shell::logger::example "shell::git::commit::pick::fzf::backport release/1.2 --source main"
        return "$RETURN_SUCCESS"
    fi

    local dry_run="false" count="500" source="" in_place="false" custom="" target="" opt val
    while [ "$#" -gt 0 ]; do
        case "$1" in
        -n | --dry-run)
            dry_run="true"
            shift
            ;;
        --in-place)
            in_place="true"
            shift
            ;;
        -c | --count | --count=* | -s | --source | --source=* | -b | --branch | --branch=*)
            opt="$1"
            case "$opt" in
            --*=*)
                val="${opt#*=}"
                opt="${opt%%=*}"
                shift
                ;;
            *)
                if [ "$#" -lt 2 ]; then
                    shell::logger::error "Option $opt requires a value"
                    return "$RETURN_INVALID"
                fi
                val="$2"
                shift 2
                ;;
            esac
            case "$opt" in
            -c | --count)
                case "$val" in
                '' | *[!0-9]* | 0*)
                    shell::logger::error "--count must be a positive whole number (got '$val')"
                    return "$RETURN_INVALID"
                    ;;
                esac
                count="$val"
                ;;
            -s | --source) source="$val" ;;
            -b | --branch) custom="$val" ;;
            esac
            ;;
        -?*)
            shell::logger::error "Unknown option: $1"
            return "$RETURN_INVALID"
            ;;
        *)
            if [ -n "$target" ]; then
                shell::logger::error "Only one target is accepted (got '$target' and '$1')"
                return "$RETURN_INVALID"
            fi
            target="$1"
            shift
            ;;
        esac
    done

    shell::git::commit::pick::guard stage || return "$RETURN_FAILURE"
    if [ -n "$source" ]; then
        shell::git::commit::pick::validate -q -- "$source" || {
            shell::logger::error "Not a valid source revision: '${source}'"
            return "$RETURN_FAILURE"
        }
    fi
    if [ -n "$target" ]; then
        shell::git::commit::pick::validate -q -- "$target" || {
            shell::logger::error "Not a valid target: '${target}'"
            return "$RETURN_FAILURE"
        }
    fi

    local targets candidates step choice rc hash
    local -a hashes=() backport_args=() log_args=() target_list=()
    targets="$(shell::git::commit::pick::branches true)"
    while IFS= read -r hash; do
        if [ -n "$hash" ]; then target_list+=("$hash"); fi
    done <<EOF
$targets
EOF

    if [ -n "$target" ]; then
        step="pick"
    else
        if [ -z "$targets" ]; then
            shell::logger::warn "There is no other branch to backport onto"
            return "$RETURN_FAILURE"
        fi
        step="target"
    fi

    while true; do
        case "$step" in
        target)
            choice="$(shell::ask::option::back --prompt "Backport onto: " "${target_list[@]}")"
            rc=$?
            if [ "$rc" -ne 0 ] || [ -z "$choice" ]; then
                shell::logger::info "Cancelled — nothing was applied"
                return "$RETURN_FAILURE"
            fi
            target="$choice"
            step="pick"
            ;;
        pick)
            # Only commits the target does not have yet.
            log_args=()
            if [ -n "$source" ]; then log_args+=("$source"); else log_args+=(--all); fi
            log_args+=(--not "$target")
            candidates="$(shell::git::commit::pick::fzf::candidates "$count" "${log_args[@]}")"
            if [ -z "$candidates" ]; then
                shell::logger::warn "Every commit is already in '${target}'; nothing to backport"
                return "$RETURN_FAILURE"
            fi
            choice="$(shell::git::commit::pick::fzf::choose "$candidates" "Backport to ${target} (Tab to mark): ")"
            rc=$?
            if [ "$rc" -ne 0 ] || [ -z "$choice" ]; then
                shell::logger::info "Cancelled — nothing was applied"
                return "$RETURN_FAILURE"
            fi
            hashes=()
            while IFS= read -r hash; do
                if [ -n "$hash" ]; then hashes+=("$hash"); fi
            done <<EOF
$choice
EOF
            step="confirm"
            ;;
        confirm)
            shell::logger::info "${#hashes[@]} commit(s) will be backported to '${target}', oldest first:"
            for hash in "${hashes[@]}"; do
                shell::logger::info "  • $(git log -1 --format='%h %s' "$hash")"
            done
            choice="$(shell::ask::option::back --prompt "Proceed? " "Backport" "Abort")"
            rc=$?
            case "$rc" in
            0) ;;
            "$RETURN_BACK")
                step="pick"
                continue
                ;;
            *)
                shell::logger::info "Cancelled — nothing was applied"
                return "$RETURN_FAILURE"
                ;;
            esac
            if [ "$choice" != "Backport" ]; then
                shell::logger::info "Cancelled — nothing was applied"
                return "$RETURN_FAILURE"
            fi
            backport_args=()
            if [ "$dry_run" = "true" ]; then backport_args+=(-n); fi
            if [ "$in_place" = "true" ]; then backport_args+=(--in-place); fi
            if [ -n "$custom" ]; then backport_args+=(-b "$custom"); fi
            shell::git::commit::pick::backport ${backport_args[@]+"${backport_args[@]}"} "$target" "${hashes[@]}"
            return $?
            ;;
        esac
    done
}

# @description Chooses a conflicted file with fzf and resolves it.
#   Lists the files still in conflict, with a preview of their conflict diff.
#   For the one you choose, a menu offers: open it in your editor (`$VISUAL` or
#   `$EDITOR`), show its diff, take our version (the branch you are on) or their
#   version (the commit being picked) and stage it, or mark it resolved. Taking
#   a side overwrites the file, so it asks first. The list is shown again after
#   each action until no conflict is left; leave with ESC or the back entry.
# @option -n | --dry-run Optional. Print the git commands instead of executing them.
# @option -h | --help Show this help message.
# @exitcode 0 At least one file was handled.
# @exitcode 1 There are no conflicts, you left without doing anything, or an action failed.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::resolve
# @see shell::git::commit::pick::conflicts
# @example
#   shell::git::commit::pick::fzf::conflicts
#
shell::git::commit::pick::fzf::conflicts() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Choose a conflicted file with fzf: open, diff, take ours/theirs, or mark resolved"
        shell::logger::usage "shell::git::commit::pick::fzf::conflicts [-n] [-h]"
        shell::logger::option "-n, --dry-run" "Print the git commands instead of executing them"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::note "Ours = the branch you are on; theirs = the commit being picked."
        shell::logger::example "shell::git::commit::pick::fzf::conflicts"
        return "$RETURN_SUCCESS"
    fi

    local dry_run="false"
    while [ "$#" -gt 0 ]; do
        case "$1" in
        -n | --dry-run)
            dry_run="true"
            shift
            ;;
        *)
            shell::logger::error "Unknown option or argument: $1"
            return "$RETURN_INVALID"
            ;;
        esac
    done
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        shell::logger::error "Not inside a Git repository"
        return "$RETURN_FAILURE"
    fi

    local files choice file action sure side rc editor handled=0 failed=0
    local -a res_flags=()
    if [ "$dry_run" = "true" ]; then res_flags+=(-n); fi

    while true; do
        files="$(shell::git::commit::pick::conflict_files)"
        if [ -z "$files" ]; then
            shell::logger::info "No conflicted files"
            break
        fi

        choice="$(printf '%s\n%s\n' "$files" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select --height=60% \
            --prompt="Conflicted file: " '--preview=git diff --color=always -- {} | head -n 200' \
            --preview-window='right:60%:wrap')" || break
        if [ -z "$choice" ] || [ "$choice" = "$SHELL_FZF_BACK_LABEL" ]; then
            break
        fi
        file="$choice"

        action="$(shell::ask::option::back --prompt "${file}: " \
            "Open in editor" "Show diff" "Take ours (current branch) and mark resolved" \
            "Take theirs (picked commit) and mark resolved" "Mark as resolved")"
        rc=$?
        if [ "$rc" -ne 0 ]; then
            continue
        fi

        case "$action" in
        "Open in editor")
            editor="${VISUAL:-${EDITOR:-vi}}"
            if [ "$dry_run" = "true" ]; then
                shell::logger::command_clip "${editor} $(shell::git::commit::spec::quote "$file")"
                handled=$((handled + 1))
            elif sh -c "${editor} \"\$1\"" _ "$file"; then
                handled=$((handled + 1))
            else
                failed=$((failed + 1))
            fi
            ;;
        "Show diff")
            git diff -- "$file"
            ;;
        "Take ours"* | "Take theirs"*)
            case "$action" in
            "Take ours"*) side="ours" ;;
            *) side="theirs" ;;
            esac
            sure="$(shell::ask::option "Overwrite ${file} with the ${side} version" "Cancel")"
            if [ "$sure" != "Overwrite ${file} with the ${side} version" ]; then
                shell::logger::info "Cancelled"
                continue
            fi
            if [ "$dry_run" = "true" ]; then
                shell::exec::command -n git checkout "--${side}" -- "$file"
                shell::exec::command -n git add -- "$file"
                handled=$((handled + 1))
            elif shell::exec::command git checkout "--${side}" -- "$file" && shell::exec::command git add -- "$file"; then
                handled=$((handled + 1))
            else
                shell::logger::error "Could not take the ${side} version of ${file}"
                failed=$((failed + 1))
            fi
            ;;
        "Mark as resolved")
            if shell::git::commit::pick::resolve ${res_flags[@]+"${res_flags[@]}"} -- "$file"; then
                handled=$((handled + 1))
            else
                failed=$((failed + 1))
            fi
            ;;
        esac
    done

    if [ "$handled" -gt 0 ] && [ "$failed" -eq 0 ]; then
        return "$RETURN_SUCCESS"
    fi
    return "$RETURN_FAILURE"
}

# @description Shows the cherry-pick state and asks before continuing it.
#   Prints shell::git::commit::pick::status, then a menu: continue or cancel.
#   It does not stage anything; files still in conflict make the continue refuse.
# @option --no-edit Optional. Keep the commit message without opening the editor.
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @exitcode 0 Continued and completed.
# @exitcode 1 Nothing in progress, cancelled, or it could not continue.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::continue
# @example
#   shell::git::commit::pick::fzf::continue
#
shell::git::commit::pick::fzf::continue() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Show the cherry-pick state, then ask before continuing"
        shell::logger::usage "shell::git::commit::pick::fzf::continue [-n] [--no-edit] [-h]"
        shell::logger::option "--no-edit" "Keep the commit message without opening the editor"
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::fzf::continue"
        return "$RETURN_SUCCESS"
    fi

    local arg
    for arg in "$@"; do
        case "$arg" in
        -n | --dry-run | --no-edit) ;;
        *)
            shell::logger::error "Unknown option or argument: $arg"
            return "$RETURN_INVALID"
            ;;
        esac
    done

    shell::git::commit::pick::status || return "$RETURN_FAILURE"
    local choice
    choice="$(shell::ask::option "Continue the cherry-pick" "Cancel")"
    if [ "$choice" != "Continue the cherry-pick" ]; then
        shell::logger::info "Cancelled — the cherry-pick was left as it is"
        return "$RETURN_FAILURE"
    fi
    shell::git::commit::pick::continue "$@"
}

# @description Shows the commit that is blocking the cherry-pick and asks before skipping it.
#   Prints the commit being picked, then a menu: skip it or cancel. Skipping
#   discards that commit's changes and carries on with the rest.
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @exitcode 0 Skipped; the cherry-pick completed.
# @exitcode 1 Nothing in progress, cancelled, or it stopped again.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::skip
# @example
#   shell::git::commit::pick::fzf::skip
#
shell::git::commit::pick::fzf::skip() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Show the commit being picked, then ask before skipping it"
        shell::logger::usage "shell::git::commit::pick::fzf::skip [-n] [-h]"
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::fzf::skip"
        return "$RETURN_SUCCESS"
    fi

    local arg
    for arg in "$@"; do
        case "$arg" in
        -n | --dry-run) ;;
        *)
            shell::logger::error "Unknown option or argument: $arg"
            return "$RETURN_INVALID"
            ;;
        esac
    done

    if ! shell::git::commit::pick::in_progress; then
        shell::logger::warn "No cherry-pick in progress; nothing to skip"
        return "$RETURN_FAILURE"
    fi
    local hash choice
    if hash="$(shell::git::commit::pick::head_hash)"; then
        shell::logger::info "Commit that will be skipped:"
        git show --format=fuller --stat "$hash"
    fi
    choice="$(shell::ask::option "Skip this commit" "Cancel")"
    if [ "$choice" != "Skip this commit" ]; then
        shell::logger::info "Cancelled — the cherry-pick was left as it is"
        return "$RETURN_FAILURE"
    fi
    shell::git::commit::pick::skip "$@"
}

# @description Shows the cherry-pick state and asks before aborting it.
#   Prints shell::git::commit::pick::status and a reminder of what an abort
#   discards, then a menu: abort or cancel. Cancel is the first-line safety net
#   against aborting a long sequence by mistake.
# @option -n | --dry-run Optional. Print the git command instead of executing it.
# @option -h | --help Show this help message.
# @exitcode 0 Aborted.
# @exitcode 1 Nothing in progress, cancelled, or git failed.
# @exitcode 2 Invalid usage.
# @see shell::git::commit::pick::abort
# @example
#   shell::git::commit::pick::fzf::abort
#
shell::git::commit::pick::fzf::abort() {
    if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
        shell::logger::reset_options
        shell::logger::info "Show the cherry-pick state, then ask before aborting it"
        shell::logger::usage "shell::git::commit::pick::fzf::abort [-n] [-h]"
        shell::logger::option "-n, --dry-run" "Print the git command instead of executing it"
        shell::logger::option "-h, --help" "Show this help message"
        shell::logger::example "shell::git::commit::pick::fzf::abort"
        return "$RETURN_SUCCESS"
    fi

    local arg
    for arg in "$@"; do
        case "$arg" in
        -n | --dry-run) ;;
        *)
            shell::logger::error "Unknown option or argument: $arg"
            return "$RETURN_INVALID"
            ;;
        esac
    done

    shell::git::commit::pick::status || return "$RETURN_FAILURE"
    shell::logger::warn "Aborting drops everything the cherry-pick changed, your conflict resolution included"
    local choice
    choice="$(shell::ask::option "Abort the cherry-pick" "Cancel")"
    if [ "$choice" != "Abort the cherry-pick" ]; then
        shell::logger::info "Cancelled — the cherry-pick was left as it is"
        return "$RETURN_FAILURE"
    fi
    shell::git::commit::pick::abort "$@"
}
