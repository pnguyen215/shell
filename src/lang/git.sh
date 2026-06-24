#!/bin/bash
# git.sh

# shell::git::telegram::history::send function
# Sends a historical GitHub-related message via Telegram using stored configuration keys.
#
# Usage:
#   shell::git::telegram::history::send [-n] <message>
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
#   shell::git::telegram::history::send "Historical message text"
#   shell::git::telegram::history::send -n "Dry-run historical message text"
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

# shell::git::repos::stats function
# Displays comprehensive statistics for a Git repository — works both for a
# local clone and for a remote URL (public or private with access). When a URL
# is supplied the repository is cloned to a temporary directory, stats are
# gathered, then the directory is removed.
#
# Usage:
#   shell::git::repos::stats [-n] [-h] [<path_or_url>]
#
# Parameters:
#   - -n, --dry-run     : Optional. Print planned git commands instead of executing.
#   - -h, --help        : Show this help message.
#   - <path_or_url>     : Optional. Local repo path OR remote URL
#                         (https://, http://, git@, ssh://). Defaults to CWD.
#
# Stat sections (v1 metric set):
#   A. Repository Identity      — name, URL, branches, age, first/last commit
#   B. Repository Size          — commits, branches, tags, contributors, files, LOC
#   C. Commit Activity          — windows (24h/7d/30d/90d/1y), velocity, trends
#   D. Contributors             — totals, active windows, top-10 leaderboard
#   E. Code Growth              — added/deleted/net lines, avg commit size
#   F. Code Churn               — churn rate, top modified files & directories
#   G. Commit Quality           — conventional breakdown, merge/revert/fixup counts
#   H. Branch Metrics           — local count, active vs stale (90-day threshold)
#   I. Tag Metrics              — total, latest, first
#   J. Time Distribution        — by weekday, top hours, working pattern %
#   K. Language Distribution    — file count by extension (top-15)
#   L. Repository Health Score  — 0-100 composite score
#
# Note: Section E (code growth) runs git log --numstat over the full history.
#       This can take several minutes on large repositories.
#
# Returns:
#   $RETURN_SUCCESS (0) on success.
#   $RETURN_FAILURE (non-zero) when the repository cannot be accessed or cloned.
#
# Example:
#   shell::git::repos::stats
#   shell::git::repos::stats /path/to/local/repo
#   shell::git::repos::stats https://github.com/owner/repo.git
#   shell::git::repos::stats git@github.com:owner/private-repo.git
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
	repo_age_days=$(( (now_ts - ${first_commit_ts:-$now_ts}) / 86400 ))
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

	since_24h=$(git log --oneline --since="1 day ago"   2>/dev/null | wc -l | tr -d ' ')
	since_7d=$( git log --oneline --since="7 days ago"  2>/dev/null | wc -l | tr -d ' ')
	since_30d=$(git log --oneline --since="30 days ago" 2>/dev/null | wc -l | tr -d ' ')
	since_90d=$(git log --oneline --since="90 days ago" 2>/dev/null | wc -l | tr -d ' ')
	since_1y=$( git log --oneline --since="1 year ago"  2>/dev/null | wc -l | tr -d ' ')

	avg_per_day=$(  awk "BEGIN{if(${repo_age_days}>0) printf \"%.2f\", ${total_commits}/${repo_age_days}; else print \"0.00\"}")
	avg_per_week=$( awk "BEGIN{if(${repo_age_days}>0) printf \"%.1f\",  ${total_commits}/(${repo_age_days}/7);  else print \"0.0\"}")
	avg_per_month=$(awk "BEGIN{if(${repo_age_days}>0) printf \"%.1f\",  ${total_commits}/(${repo_age_days}/30); else print \"0.0\"}")

	most_active_month=$( git log --format='%ad' --date=format:'%Y-%m' 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
	least_active_month=$(git log --format='%ad' --date=format:'%Y-%m' 2>/dev/null | sort | uniq -c | sort -n  | head -1 | awk '{print $2}')
	peak_day=$( git log --format='%ad' --date=format:'%A' 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
	peak_hour=$(git log --format='%ad' --date=format:'%H' 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $2":00"}')

	# ── D. CONTRIBUTORS ──────────────────────────────────────────────────────
	local active_7d active_30d active_90d top_contributors_raw contributor_commit_total

	active_7d=$( git log --since="7 days ago"  --format='%aN' 2>/dev/null | sort -u | wc -l | tr -d ' ')
	active_30d=$(git log --since="30 days ago" --format='%aN' 2>/dev/null | sort -u | wc -l | tr -d ' ')
	active_90d=$(git log --since="90 days ago" --format='%aN' 2>/dev/null | sort -u | wc -l | tr -d ' ')
	top_contributors_raw=$(git log --format='%aN' 2>/dev/null | sort | uniq -c | sort -rn | head -10)
	contributor_commit_total=$(echo "$top_contributors_raw" | awk '{s+=$1} END{print s+0}')

	# ── E. CODE GROWTH (slow — full --numstat scan) ───────────────────────────
	local total_added total_deleted net_growth avg_commit_size

	local _growth_raw
	_growth_raw=$(git log --numstat --format='' 2>/dev/null | awk '/^[0-9]/{a+=$1; d+=$2} END{print a+0, d+0}')
	total_added=$(  echo "$_growth_raw" | awk '{print $1}')
	total_deleted=$(echo "$_growth_raw" | awk '{print $2}')
	[ -z "$total_added" ]   && total_added=0
	[ -z "$total_deleted" ] && total_deleted=0
	net_growth=$(( total_added - total_deleted ))
	avg_commit_size=$(awk "BEGIN{if(${total_commits}>0) printf \"%.1f\", (${total_added}+${total_deleted})/${total_commits}; else print \"0.0\"}")

	# ── F. CODE CHURN ────────────────────────────────────────────────────────
	local churn_rate hotspot_files_raw hotspot_dirs_raw

	churn_rate=$(awk "BEGIN{if(${total_added}>0) printf \"%.2f\", ${total_deleted}/${total_added}; else print \"0.00\"}")
	hotspot_files_raw=$(git log --name-only --format='' 2>/dev/null | grep -v '^$' | sort | uniq -c | sort -rn | head -10)
	hotspot_dirs_raw=$( git log --name-only --format='' 2>/dev/null | grep -v '^$' | \
		sed 's|/[^/]*$||' | grep -v '^$' | sort | uniq -c | sort -rn | head -10)

	# ── G. COMMIT QUALITY ────────────────────────────────────────────────────
	local merge_commits revert_commits fixup_commits avg_msg_length conv_raw conv_total

	merge_commits=$( git log --merges --oneline 2>/dev/null | wc -l | tr -d ' ')
	revert_commits=$(git log --oneline --grep='^[Rr]evert' 2>/dev/null | wc -l | tr -d ' ')
	fixup_commits=$( git log --oneline --grep='^fixup!'    2>/dev/null | wc -l | tr -d ' ')
	avg_msg_length=$(git log --format='%s' 2>/dev/null | \
		awk '{t+=length($0); c++} END{if(c>0) printf "%.0f", t/c; else print "0"}')
	conv_raw=$(git log --format='%s' 2>/dev/null | \
		grep -oE '^(feat|fix|chore|docs|test|refactor|style|ci|build|perf)(\([^)]*\))?:' | \
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
		local_branch_count=$(( local_branch_count + 1 ))
		_bts=$(git log -1 --format='%ct' "${_bname}" 2>/dev/null || echo "0")
		[ -z "$_bts" ] && _bts=0
		if [ "${_bts}" -ge "${stale_threshold_ts}" ] 2>/dev/null; then
			active_branch_count=$(( active_branch_count + 1 ))
		else
			stale_branch_count=$(( stale_branch_count + 1 ))
		fi
	done < <(git branch | sed 's|^[* ]*||')

	oldest_branch=$(git for-each-ref --sort=committerdate refs/heads/ --format='%(refname:short)' 2>/dev/null | head -1)
	[ -n "$oldest_branch" ] && \
		oldest_branch_date=$(git log -1 --format='%ad' --date=format:'%Y-%m-%d' "${oldest_branch}" 2>/dev/null)

	# ── I. TAG METRICS ───────────────────────────────────────────────────────
	local latest_tag first_tag

	latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "(none)")
	first_tag=$(git tag --sort=version:refname 2>/dev/null | head -1)
	[ -z "$first_tag" ] && first_tag="(none)"

	# ── J. TIME DISTRIBUTION ─────────────────────────────────────────────────
	local by_weekday_raw by_hour_top5_raw office_pct after_hours_pct weekend_pct

	by_weekday_raw=$(  git log --format='%ad' --date=format:'%A' 2>/dev/null | sort | uniq -c | sort -rn)
	by_hour_top5_raw=$(git log --format='%ad' --date=format:'%H' 2>/dev/null | sort | uniq -c | sort -rn | head -5)

	# %u → ISO day number: 1=Mon … 7=Sun; h = hour (0-23)
	local _time_data office_c after_c weekend_c
	_time_data=$(git log --format='%ad' --date=format:'%H %u' 2>/dev/null)
	office_c=$( echo "$_time_data" | awk '{h=$1+0; d=$2+0; if(d<=5 && h>=9 && h<18) c++} END{print c+0}')
	after_c=$(  echo "$_time_data" | awk '{h=$1+0; d=$2+0; if(d<=5 && (h<9||h>=18)) c++} END{print c+0}')
	weekend_c=$(echo "$_time_data" | awk '{d=$2+0; if(d>=6) c++} END{print c+0}')

	office_pct=$(     awk "BEGIN{if(${total_commits}>0) printf \"%.1f\", ${office_c}*100/${total_commits};  else print \"0.0\"}")
	after_hours_pct=$(awk "BEGIN{if(${total_commits}>0) printf \"%.1f\", ${after_c}*100/${total_commits};   else print \"0.0\"}")
	weekend_pct=$(    awk "BEGIN{if(${total_commits}>0) printf \"%.1f\", ${weekend_c}*100/${total_commits}; else print \"0.0\"}")

	# ── K. LANGUAGE DISTRIBUTION ─────────────────────────────────────────────
	local lang_raw

	lang_raw=$(find . -type f -not -path './.git/*' 2>/dev/null | \
		grep -oE '\.[^./]+$' | tr '[:upper:]' '[:lower:]' | sort | uniq -c | sort -rn | head -15)

	# ── L. HEALTH SCORE ──────────────────────────────────────────────────────
	local score_activity score_contributors score_growth score_maintenance total_score

	# Activity  (0-25): commits_30d ≥ 10 → full score; linear below
	score_activity=$(    awk "BEGIN{s=(${since_30d}>=10)?25:int(${since_30d}*2.5); print s}")
	# Contributors (0-25): ≥3 active in 30d → full; linear below
	score_contributors=$(awk "BEGIN{s=(${active_30d}>=3)?25:int(${active_30d}*8); if(s>25)s=25; print s}")
	# Growth (0-25): net positive → 25, zero → 15, negative → 5
	if   [ "${net_growth}" -gt 0 ]; then score_growth=25
	elif [ "${net_growth}" -eq 0 ]; then score_growth=15
	else                                  score_growth=5; fi
	# Maintenance (0-25): conventional commit ratio × 25, capped
	score_maintenance=$(awk "BEGIN{if(${total_commits}>0 && ${conv_total}>0){s=int(${conv_total}*25/${total_commits}); if(s>25)s=25; print s}else print 0}")
	total_score=$(( score_activity + score_contributors + score_growth + score_maintenance ))

	# ── PRINT REPORT ─────────────────────────────────────────────────────────
	local _lw=28   # label column width for printf alignment
	local _hr="  ══════════════════════════════════════════════════════════"
	local _sr="  ──────────────────────────────────────────────────────────"

	shell::logger::info ""
	shell::logger::info "${_hr}"
	shell::logger::info "  GIT REPOSITORY STATS  ·  ${repo_name}"
	shell::logger::info "${_hr}"

	# ── A ──
	shell::logger::info ""
	shell::logger::info "  A. REPOSITORY IDENTITY"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Name"              "${repo_name}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "URL"               "${repo_url}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Default Branch"    "${default_branch}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Current Branch"    "${current_branch}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Repository Age"    "${repo_age_str}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "First Commit"      "${first_commit_date}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Last Commit"       "${last_commit_date}")"

	# ── B ──
	shell::logger::info ""
	shell::logger::info "  B. REPOSITORY SIZE"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Commits"      "${total_commits}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Branches (remote)" "${total_branches}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Tags"         "${total_tags}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Contributors" "${total_contributors}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Files"        "${total_files}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Directories"  "${total_dirs}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Current LOC"        "${total_loc}")"

	# ── C ──
	shell::logger::info ""
	shell::logger::info "  C. COMMIT ACTIVITY"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Last 24 hours"      "${since_24h}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Last 7 days"        "${since_7d}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Last 30 days"       "${since_30d}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Last 90 days"       "${since_90d}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Last year"          "${since_1y}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Avg per day"        "${avg_per_day}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Avg per week"       "${avg_per_week}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Avg per month"      "${avg_per_month}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Most active month"  "${most_active_month}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Least active month" "${least_active_month}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Peak day"           "${peak_day}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Peak hour"          "${peak_hour}")"

	# ── D ──
	shell::logger::info ""
	shell::logger::info "  D. CONTRIBUTORS"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total"              "${total_contributors}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Active (7d)"        "${active_7d}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Active (30d)"       "${active_30d}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Active (90d)"       "${active_90d}")"
	shell::logger::info ""
	shell::logger::info "  Top Contributors (by commits):"
	echo "$top_contributors_raw" | while IFS= read -r _line; do
		[ -z "$_line" ] && continue
		local _cnt _name _share
		_cnt=$(  echo "$_line" | awk '{print $1}')
		_name=$( echo "$_line" | awk '{$1=""; sub(/^ /,""); print}')
		_share=$(awk "BEGIN{if(${contributor_commit_total}>0) printf \"%.1f\", ${_cnt}*100/${contributor_commit_total}; else print \"0.0\"}")
		shell::logger::info "$(printf '    %-6s %-28s %s%%' "${_cnt}" "${_name}" "${_share}")"
	done

	# ── E ──
	shell::logger::info ""
	shell::logger::info "  E. CODE GROWTH"
	local _net_sign=""
	[ "${net_growth}" -ge 0 ] && _net_sign="+"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Added Lines"    "${total_added}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Deleted Lines"  "${total_deleted}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Net Growth"           "${_net_sign}${net_growth} lines")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Avg Commit Size"      "${avg_commit_size} lines (added+deleted)")"

	# ── F ──
	shell::logger::info ""
	shell::logger::info "  F. CODE CHURN"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Churn Rate"           "${churn_rate}  (deleted ÷ added)")"
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
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Merge Commits"        "${merge_commits}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Revert Commits"       "${revert_commits}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Fixup Commits"        "${fixup_commits}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Avg Message Length"   "${avg_msg_length} chars")"
	shell::logger::info ""
	shell::logger::info "  Conventional Commit Breakdown:"
	if [ -n "$conv_raw" ] && [ "${conv_total}" -gt 0 ]; then
		echo "$conv_raw" | while IFS= read -r _line; do
			[ -z "$_line" ] && continue
			local _cnt _type _pct
			_cnt=$( echo "$_line" | awk '{print $1}')
			_type=$(echo "$_line" | awk '{print $2}')
			_pct=$( awk "BEGIN{if(${total_commits}>0) printf \"%.1f\", ${_cnt}*100/${total_commits}; else print \"0.0\"}")
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
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Local Branches"  "${local_branch_count}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Remote Branches" "${total_branches}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Active (<= 90 days)"   "${active_branch_count}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Stale (> 90 days)"     "${stale_branch_count}")"
	if [ -n "$oldest_branch" ]; then
		shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Oldest Branch"      "${oldest_branch}  (${oldest_branch_date})")"
	fi

	# ── I ──
	shell::logger::info ""
	shell::logger::info "  I. TAG METRICS"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Total Tags"            "${total_tags}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Latest Tag"            "${latest_tag}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "First Tag"             "${first_tag}")"

	# ── J ──
	shell::logger::info ""
	shell::logger::info "  J. TIME DISTRIBUTION"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Peak Day"              "${peak_day}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Peak Hour"             "${peak_hour}")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Office Hours (9-18 M-F)" "${office_pct}%")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "After Hours"           "${after_hours_pct}%")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Weekend"               "${weekend_pct}%")"
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
		_hr=$(echo  "$_line" | awk '{print $2}')
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
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Activity (commits 30d)"     "${score_activity}/25")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Contributors (active 30d)"  "${score_contributors}/25")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Growth (net LOC)"           "${score_growth}/25")"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Maintenance (conv. commits)" "${score_maintenance}/25")"
	shell::logger::info "  ${_sr}"
	shell::logger::info "$(printf '  %-'"${_lw}"'s: %s' "Health Score"               "${total_score}/100")"

	shell::logger::info ""
	shell::logger::info "${_hr}"
	shell::logger::info ""

	# Return to original directory and remove temp clone if any.
	cd "$_orig_dir" 2>/dev/null
	[ -n "$_tmp_dir" ] && rm -rf "$_tmp_dir" 2>/dev/null

	return $RETURN_SUCCESS
}

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

# shell::git::repos::version::latest function
# Retrieves the latest release tag from a GitHub repository using the GitHub API.
#
# Usage:
#   shell::git::repos::version::latest <owner/repo>
#
# Parameters:
#   - <owner/repo>: GitHub repository in the format 'owner/repo'
#
# Returns:
#   Outputs the latest release tag (e.g., v1.2.3), or an error message if failed.
#
# Example:
#   shell::git::repos::version::latest "cli/cli"
#
# Dependencies:
#   - curl
#   - jq (optional): For better JSON parsing. Falls back to grep/sed if unavailable.
#
# Notes:
#   - Requires internet access.
#   - Works on both macOS and Linux.
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

# shell::git::branch::sync function
# Syncs all remote branches to local: fetches and prunes all remotes, creates
# local tracking branches for new remote branches, and fast-forwards local
# branches that have no local-only commits ahead of origin.
#
# Usage:
#   shell::git::branch::sync [-n] [-h]
#
# Parameters:
#   - -n, --dry-run : Optional. Print each command via shell::logger::command_clip
#                     instead of executing it.
#   - -h, --help    : Show this help message.
#
# Description:
#   1. git fetch --all --prune         — update all remote-tracking refs, remove stale ones
#   2. For each remote branch in origin (excluding HEAD):
#        - Not present locally  → git branch --track <branch> origin/<branch>
#        - Currently checked out → skip with info (use shell::git::branch::checkout)
#        - local_ahead == 0     → git branch -f <branch> origin/<branch>  (fast-forward)
#        - local_ahead  > 0     → warn and skip
#
# Returns:
#   $RETURN_SUCCESS (0) on full success.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#   Non-zero exit code of the first failing git command otherwise.
#
# Example:
#   shell::git::branch::sync
#   shell::git::branch::sync -n
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

# shell::git::branch::remove function
# Deletes one or more Git branches both locally (force-delete) and on the remote
# origin, then restores the originally checked-out branch.
#
# Usage:
#   shell::git::branch::remove [-n] [-h] <branch> [<branch> ...]
#
# Parameters:
#   - -n, --dry-run : Optional. Print each command via shell::logger::command_clip
#                     instead of executing it.
#   - -h, --help    : Show this help message.
#   - <branch>...   : One or more branch names to delete.
#
# Description:
#   Captures the currently checked-out branch at function entry, then for each
#   provided branch name runs:
#     1. git branch -D <branch>            — force-delete the local branch
#     2. git push origin --delete <branch> — delete the branch on origin
#   After all branches are processed, restores the original branch via
#   git checkout. Each step is logged via shell::logger::assert and stops
#   the per-branch iteration on the first failure for that branch.
#
# Returns:
#   $RETURN_SUCCESS (0) on full success.
#   $RETURN_INVALID (1) when no branch arguments are provided.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#   Non-zero exit code of the first failing git command otherwise.
#
# Example:
#   shell::git::branch::remove feature_a feature_b
#   shell::git::branch::remove -n feature_a
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

# shell::git::branch::push function
# Presents an interactive fzf picker of git push strategies for a given branch,
# confirms with the user, then executes the selected command.
#
# Usage:
#   shell::git::branch::push [-n] [-h] <branch>
#
# Parameters:
#   - -n, --dry-run : Optional. After selection and confirmation, print the
#                     selected command via shell::logger::command_clip instead
#                     of executing it.
#   - -h, --help    : Show this help message.
#   - <branch>      : Branch name to substitute into push commands.
#
# Description:
#   Builds a set of labelled push strategies (label:command pairs), presents
#   them via shell::options::select_key (fzf), prompts for confirmation, then
#   runs the selected git command via shell::logger::assert.
#   Available strategies:
#     - Set upstream tracking        git push -u origin <branch>
#     - Push all branches            git push --all origin
#     - Push all tags                git push --tags origin
#     - Force-push (unsafe)          git push --force origin <branch>
#     - Force-push with lease (safe) git push --force-with-lease origin <branch>
#     - Delete branch from remote    git push --delete origin <branch>
#     - Mirror local repo            git push --mirror origin
#     - Simulate push (dry-run)      git push --dry-run origin <branch>
#     - Push with CI skip            git push -o ci.skip origin <branch>
#     - Prune deleted remote refs    git push --prune origin
#     - Push with GPG signing        git push --signed origin <branch>
#     - Simple push                  git push
#
# Returns:
#   $RETURN_SUCCESS (0) on success or user-initiated abort.
#   $RETURN_INVALID (1) when <branch> is omitted.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#   Non-zero exit code of the failing git command otherwise.
#
# Example:
#   shell::git::branch::push "main"
#   shell::git::branch::push -n "feature/my-branch"
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
	# Push command options — Label:command pairs for shell::options::select_key.
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
	selected_cmd=$(shell::options::select_key "${push_options[@]}")

	if [ -z "$selected_cmd" ]; then
		shell::logger::warn "No push command selected — aborting"
		return $RETURN_SUCCESS
	fi

	shell::logger::info "Selected command: ${selected_cmd}"

	if shell::out::confirmz "Execute this push command?"; then
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

# shell::git::branch::push::current function
# Convenience wrapper around shell::git::branch::push that automatically detects
# the currently checked-out branch and invokes the push command for it.
#
# Usage:
#   shell::git::branch::push::current [-n] [-h]
#
# Parameters:
#   - -n, --dry-run : Optional. Print the command via shell::logger::command_clip instead of executing it.
#   - -h, --help    : Show this help message.
#
# Returns:
#   $RETURN_SUCCESS (0) on success or user-initiated abort.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#   Non-zero exit code of the failing git command otherwise.
#
# Example:
#   shell::git::branch::push::current
#   shell::git::branch::push::current -n
shell::git::branch::push::current() {
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	if [ -z "$current_branch" ]; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	shell::git::branch::push "$current_branch"
}

# shell::git::branch::push::current::force function
# Convenience wrapper around shell::git::branch::push that automatically detects
# the currently checked-out branch and invokes a force-push command for it.
# This is a specialized function for the common case of needing to force-push the
# current branch to origin. It prompts for confirmation before executing the force-push.
# 
# Usage:
#   shell::git::branch::push::current::force [-h]
#
# Parameters:
#   - -h, --help : Show this help message.
#
# Returns:
#   $RETURN_SUCCESS (0) on success or user-initiated abort.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#   Non-zero exit code of the git push command if the force-push fails.
#
# Example:
#   shell::git::branch::push::current::force
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

	if shell::out::confirmz "Force-push the current branch '${current_branch}' to origin?"; then
		shell::logger::info "Force-push aborted"
		return $RETURN_SUCCESS
	fi

	shell::logger::assert "$force_cmd" \
		"Force-push executed successfully" "Force-push failed" || return $?

	return $RETURN_SUCCESS
}

# shell::git::branch::backup function
# Creates a local backup branch pointing to the same commit as the given source
# branch, without switching HEAD. Sends a Telegram activity notification on success.
#
# Usage:
#   shell::git::branch::backup [-n] [-h] <branch>
#
# Parameters:
#   - -n, --dry-run : Optional. Print the git branch command via
#                     shell::logger::command_clip instead of executing it.
#   - -h, --help    : Show this help message.
#   - <branch>      : Source branch name to back up.
#
# Backup name pattern:
#   backup/<sanitized-branch>/<YYYYMMDD.HHMMSS>
#
#   <sanitized-branch> is the source branch name with every '/' replaced by '--'
#   (double-dash) so that the backup hierarchy is always exactly two levels deep
#   and single dashes inside branch names remain unambiguous.
#
#   Examples:
#     main                 → backup/main/20260618.215830
#     feature/TM-1234      → backup/feature--TM-1234/20260618.215830
#     release/v2.0/hotfix  → backup/release--v2.0--hotfix/20260618.215830
#
# Description:
#   Step 1 — Validate that the source branch exists locally.
#             If it is only on origin, offers a clear error message.
#   Step 2 — Build the backup branch name from the sanitized source name
#             and a timestamp (YYYYMMDD.HHMMSS).
#   Step 3 — Run: git branch <backup_name> <source_branch>
#             This creates the backup branch at the same commit as the source
#             WITHOUT switching HEAD — the working tree is never disturbed.
#   Step 4 — Push the backup branch to origin with upstream tracking:
#             git push -u origin <backup_name>
#   Step 5 — Log the backup name, copy it to the clipboard via shell::clip_value,
#             and send a Telegram activity notification.
#
# Safety notes:
#   • No checkout / restore cycle: HEAD never moves, so in-progress work is safe.
#   • The backup branch is pushed to origin immediately for remote storage.
#   • Backup names are collision-resistant: timestamp precision is 1 second.
#
# Returns:
#   $RETURN_SUCCESS (0) on success.
#   $RETURN_INVALID (1) when <branch> is omitted.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository or the source
#                   branch does not exist locally.
#
# Example:
#   shell::git::branch::backup "main"
#   shell::git::branch::backup "feature/TM-1234"
#   shell::git::branch::backup -n "release/v2.0"
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
	shell::clip_value "${backup_name}"

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

# shell::git::branch::backup::current function
# Creates a local backup branch of the currently checked-out branch without switching HEAD. Sends a Telegram activity notification on success.
#
# Usage:
#   shell::git::branch::backup::current [-n] [-h]
#
# Parameters:
#   - -n, --dry-run : Optional. Print the git branch command via
#                     shell::logger::command_clip instead of executing it.
#   - -h, --help    : Show this help message.
# 
# Description:
#   1. Determine the currently checked-out branch.
#   2. Call shell::git::branch::backup with the current branch name.
# 
# Returns:
#   $RETURN_SUCCESS (0) on success.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
# 
# Example:
#   shell::git::branch::backup::current
shell::git::branch::backup::current() {
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

	if [ -z "$current_branch" ]; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	shell::git::branch::backup "${current_branch}"
}

# shell::git::branch::rename function
# Renames a local Git branch both locally and on the remote origin, then
# restores the originally checked-out branch and sends a Telegram notification.
#
# Usage:
#   shell::git::branch::rename [-n] [-h] <old_name> <new_name>
#
# Parameters:
#   - -n, --dry-run : Optional. Print each command via shell::logger::command_clip
#                     instead of executing it.
#   - -h, --help    : Show this help message.
#   - <old_name>    : Current branch name.
#   - <new_name>    : Desired new branch name.
#
# Description:
#   Step 1 — git branch -m <old_name> <new_name>      — rename locally
#   Step 2 — git push -u origin <new_name>            — push new name with upstream tracking
#   Step 3 — git push origin --delete <old_name>      — remove old name from origin
#             (failure is logged and warned but does not abort — the old name
#              may not exist on origin if it was never pushed)
#   Step 4 — git checkout <original_branch>           — restore originally checked-out branch
#   Step 5 — shell::git::telegram::send_activity      — Telegram notification
#
# Returns:
#   $RETURN_SUCCESS (0) on full success.
#   $RETURN_INVALID (1) when either argument is missing.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository or a critical step fails.
#
# Example:
#   shell::git::branch::rename "feature/old-name" "feature/new-name"
#   shell::git::branch::rename -n "main" "mainline"
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
	shell::git::telegram::send_activity "${telegram_message}"

	return $RETURN_SUCCESS
}

# shell::git::branch::rename::current function
# Renames the currently checked-out branch to a new name, both locally and on
# the remote origin. Delegates entirely to shell::git::branch::rename.
#
# Usage:
#   shell::git::branch::rename::current [-n] [-h] <new_name>
#
# Parameters:
#   - -n, --dry-run : Optional. Print the commands instead of executing them.
#   - -h, --help    : Show this help message.
#   - <new_name>    : Desired new branch name.
#
# Returns:
#   $RETURN_SUCCESS (0) on success.
#   $RETURN_INVALID (1) when <new_name> is omitted.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository or rename fails.
#
# Example:
#   shell::git::branch::rename::current "feature/new-name"
#   shell::git::branch::rename::current -n "feature/new-name"
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

# shell::git::branch::rename::fzf function
# Presents an fzf picker of all local branches, prompts for a new name via
# stdin, then delegates to shell::git::branch::rename.
#
# Usage:
#   shell::git::branch::rename::fzf [-n] [-h]
#
# Parameters:
#   - -n, --dry-run : Optional. Print the commands instead of executing them.
#   - -h, --help    : Show this help message.
#
# Description:
#   Step 1 — Collect all local branch names and present via shell::options::select.
#   Step 2 — Prompt for the desired new branch name (loops until non-empty).
#   Step 3 — Confirm and delegate to shell::git::branch::rename.
#
# Returns:
#   $RETURN_SUCCESS (0) on success or user-initiated abort.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository or rename fails.
#
# Example:
#   shell::git::branch::rename::fzf
#   shell::git::branch::rename::fzf -n
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
	old_name=$(shell::options::select "${local_branches[@]}")

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

	if shell::out::confirmz "Proceed with rename?"; then
		shell::logger::info "Rename aborted"
		return $RETURN_SUCCESS
	fi

	if [ "$dry_run" = "true" ]; then
		shell::git::branch::rename -n "${old_name}" "${new_name}"
	else
		shell::git::branch::rename "${old_name}" "${new_name}"
	fi
}

# shell::git::branch::all::fzf function
# Lists all local and remote branches with sync-state labels, presents a
# multi-select picker, then shows an action menu to act on the selected
# branches using existing shell::git::* functions.
#
# Usage:
#   shell::git::branch::all::fzf [-h]
#
# Parameters:
#   - -h, --help : Show this help message.
#
# Branch label format (columns are fixed-width for alignment in fzf):
#   * [LOCAL | synced    ] : <branch>  — currently checked-out, in sync with origin
#     [LOCAL | synced    ] : <branch>  — local, in sync with origin
#     [LOCAL | +N/-M     ] : <branch>  — N local commits ahead, M remote commits behind
#     [LOCAL | no-remote ] : <branch>  — local-only, no remote tracking ref
#     [REMOTE            ] : <branch>  — exists only on origin, not present locally
#
#   The ' : ' separator uses ':' which is prohibited in git branch names,
#   making it a reliable extraction anchor in the space-joined multiselect output.
#
# Action menu (presented after branch selection via shell::options::select_key):
#   • Checkout                              → shell::git::branch::checkout      (first selected)
#   • View commit history                   → shell::git::commit::spec           (first selected)
#   • Browse commits and copy info          → shell::git::commit::spec::search   (first selected)
#   • Cherry-pick commits onto current      → shell::git::commit::pick::local    (first selected)
#   • Cherry-pick commits then push         → shell::git::commit::pick::remote   (first selected)
#   • Backup selected branch(es)            → shell::git::branch::backup         (each selected)
#   • Push selected branch(es) to remote    → shell::git::branch::push           (each selected)
#   • Remove selected branch(es)            → shell::git::branch::remove         (all selected)
#   • Sync all remote branches to local     → shell::git::branch::sync           (ignores selection)
#   • Exit — noop                           → return immediately
#
# Returns:
#   $RETURN_SUCCESS (0) on success or when no branches/action are selected.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository or an action fails.
#
# Example:
#   shell::git::branch::all::fzf
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
			[ "$b" = "$rb" ] && { is_local="true"; break; }
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
	selected_output=$(shell::options::multiselect "${branch_lines[@]}")

	if [ -z "$selected_output" ]; then
		shell::logger::warn "No branches selected — aborting"
		return $RETURN_SUCCESS
	fi

	# ---------------------------------------------------------------------------
	# Step 2 — extract branch names from the space-joined multiselect output.
	#
	# shell::options::multiselect joins selected lines with spaces (newlines → spaces).
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
	# Uses shell::options::select_key which splits each entry on the first ':'
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
	action=$(shell::options::select_key "${action_options[@]}")

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
			if shell::out::confirmz "Proceed with removal?"; then
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

# shell::git::branch::merge function
# Merges a source branch into a target branch with conflict detection and an
# interactive push step after a successful merge.
#
# Usage:
#   shell::git::branch::merge [-n] [-h] <source_branch> <target_branch>
#
# Parameters:
#   - -n, --dry-run       : Optional. Print each command via
#                           shell::logger::command_clip instead of executing it.
#   - -h, --help          : Show this help message.
#   - <source_branch>     : Branch whose changes will be merged in.
#   - <target_branch>     : Branch that will receive the changes.
#
# Description:
#   Step 1 — Capture the currently checked-out branch so it can be restored.
#   Step 2 — Checkout <target_branch>.
#   Step 3 — Run: git merge --no-commit <source_branch>
#             (stages changes without auto-creating the merge commit).
#   Step 4 — If unmerged files are present, list them with conflict counts
#             and return $RETURN_FAILURE so the user can resolve manually.
#   Step 5 — Confirm and commit: git commit -m "Merged <source> into <target>"
#   Step 6 — Delegate push to shell::git::branch::push (interactive strategy).
#   Step 7 — Restore the original branch.
#   Step 8 — Send Telegram activity notification.
#
# Returns:
#   $RETURN_SUCCESS (0) on full success or user-initiated abort.
#   $RETURN_INVALID (1) when <source_branch> or <target_branch> is omitted.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository or conflicts exist.
#   Non-zero exit code of the first failing git command otherwise.
#
# Example:
#   shell::git::branch::merge "feature/my-feature" "develop"
#   shell::git::branch::merge -n "feature/my-feature" "main"
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

	if shell::out::confirmz "Proceed with this merge commit?"; then
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

# shell::git::branch::merge::fzf function
# Interactively selects source and target branches via fzf, then delegates to
# shell::git::branch::merge to perform the merge.
#
# Usage:
#   shell::git::branch::merge::fzf [-n] [-h]
#
# Parameters:
#   - -n, --dry-run : Optional. Forward dry-run flag to shell::git::branch::merge.
#   - -h, --help    : Show this help message.
#
# Description:
#   Step 1 — Collect all local branch names.
#   Step 2 — Present source branch picker via shell::options::select (fzf).
#   Step 3 — Present target branch picker via shell::options::select (fzf),
#             excluding the source branch from the list.
#   Step 4 — Confirm the merge plan with the user.
#   Step 5 — Delegate to shell::git::branch::merge [-n] <source> <target>.
#
# Returns:
#   $RETURN_SUCCESS (0) on success or user-initiated abort.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#   Return value of shell::git::branch::merge otherwise.
#
# Example:
#   shell::git::branch::merge::fzf
#   shell::git::branch::merge::fzf -n
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
	source_branch=$(shell::options::select "${all_branches[@]}")

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
	target_branch=$(shell::options::select "${target_candidates[@]}")

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

	if shell::out::confirmz "Proceed with merging '${source_branch}' into '${target_branch}'?"; then
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

# shell::git::branch::stash function
# Stashes all changes (tracked and untracked) in the current Git repository
# with an optional message. Defaults to a timestamped message including the
# current branch name.
#
# Usage:
#   shell::git::branch::stash [-n] [-h] [<message>]
#
# Parameters:
#   - -n, --dry-run : Optional. Print the git stash command via
#                     shell::logger::command_clip instead of executing it.
#   - -h, --help    : Show this help message.
#   - <message>      : Optional. Custom stash message. Defaults to current date.
#
# Description:
#   Runs: git stash save --include-untracked "<message>"
#   The default message format follows the convention: "WIP on <branch>: <date>"
#   This ensures stashes are traceable to their branch of origin.
#
# Returns:
#   $RETURN_SUCCESS (0) on success.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#   Non-zero exit code of the git stash command otherwise.
#
# Example:
#   shell::git::branch::stash
#   shell::git::branch::stash "Work in progress on feature"
#   shell::git::branch::stash -n
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

# shell::git::branch::stash::remove::fzf function
# Presents an fzf picker of stashes for the current branch, then removes the
# selected stash after confirmation.
#
# Usage:
#   shell::git::branch::stash::remove::fzf [-n] [-h]
#
# Parameters:
#   - -n, --dry-run : Optional. Print the command via
#                     shell::logger::command_clip instead of executing it.
#   - -h, --help    : Show this help message.
#
# Description:
#   Step 1 — Verify the git repository and capture the current branch.
#   Step 2 — Build a list of stashes filtered to the current branch.
#   Step 3 — Present a single-select picker via shell::options::select.
#   Step 4 — Extract the stash reference (stash@{N}) from the selection.
#   Step 5 — Confirm removal with the user.
#   Step 6 — Execute: git stash drop <stash_ref>
#
# Returns:
#   $RETURN_SUCCESS (0) on success or user-initiated abort.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#   Non-zero exit code of the git stash drop command otherwise.
#
# Example:
#   shell::git::branch::stash::remove::fzf
#   shell::git::branch::stash::remove::fzf -n
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
	selected_output=$(shell::options::select "${stash_lines[@]}")

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
	if shell::out::confirmz "Remove ${stash_ref}?"; then
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

# shell::git::branch::stash::preview::fzf function
# Presents an fzf picker of stashes for the current branch for browsing only.
# No stash is modified — this is a read-only viewer.
#
# Usage:
#   shell::git::branch::stash::preview::fzf [-n] [-h]
#
# Parameters:
#   - -n, --dry-run : Optional. Print the git stash list command via
#                     shell::logger::command_clip instead of executing it.
#   - -h, --help    : Show this help message.
#
# Description:
#   Step 1 — Verify the git repository and capture the current branch.
#   Step 2 — Build a list of stashes filtered to the current branch.
#   Step 3 — Present a single-select picker via shell::options::select.
#   Step 4 — Show the diff of the selected stash via git stash show -p.
#   Step 5 — Copy the stash reference to clipboard for convenience.
#
# Returns:
#   $RETURN_SUCCESS (0) on success or user-initiated abort.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#
# Example:
#   shell::git::branch::stash::preview::fzf
#   shell::git::branch::stash::preview::fzf -n
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
	selected_output=$(shell::options::select "${stash_lines[@]}")

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
	if shell::is_command_available delta; then
		eval "$cmd_show" 2>/dev/null | delta --no-gitconfig --line-numbers --navigate --dark 2>/dev/null \
			|| eval "$cmd_show"
	else
		eval "$cmd_show"
	fi

	# Step 5 — copy stash reference to clipboard.
	shell::clip_value "${stash_ref}"
	shell::logger::info "Stash reference copied to clipboard: ${stash_ref}"

	return $RETURN_SUCCESS
}

# shell::git::branch::stash::apply::fzf function
# Presents an fzf multi-select picker of stashes for the current branch,
# then applies each selected stash in order. Continues on individual failures.
#
# Usage:
#   shell::git::branch::stash::apply::fzf [-n] [-h]
#
# Parameters:
#   - -n, --dry-run : Optional. Print the commands via
#                     shell::logger::command_clip instead of executing them.
#   - -h, --help    : Show this help message.
#
# Description:
#   Step 1 — Verify the git repository and capture the current branch.
#   Step 2 — Build a list of stashes filtered to the current branch.
#   Step 3 — Present a multi-select picker via shell::options::multiselect.
#   Step 4 — Extract stash references (stash@{N}) from the selection.
#   Step 5 — Apply each selected stash in order, continuing on failure.
#   Step 6 — Summarize success/failure counts.
#
# Returns:
#   $RETURN_SUCCESS (0) on success or user-initiated abort.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#
# Example:
#   shell::git::branch::stash::apply::fzf
#   shell::git::branch::stash::apply::fzf -n
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
	selected_output=$(shell::options::multiselect "${stash_lines[@]}")

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
			success_count=$(( success_count + 1 ))
		else
			failure_count=$(( failure_count + 1 ))
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

# shell::git::commit::spec function
# Displays a decorated commit graph for a specific branch.
#
# Usage:
#   shell::git::commit::spec [-n] [-h] <branch>
#
# Parameters:
#   - -n, --dry-run : Optional. Print the command via shell::logger::command_clip
#                     instead of executing it.
#   - -h, --help    : Show this help message.
#   - <branch>      : The branch whose commit history to display.
#
# Description:
#   Runs git log with a coloured, decorated graph format scoped to the given
#   branch. Format: full hash (short hash) — relative time  author  refs  subject.
#
# Returns:
#   $RETURN_SUCCESS (0) on success.
#   $RETURN_INVALID (1) when <branch> is omitted.
#   Non-zero exit code of the failing git command otherwise.
#
# Example:
#   shell::git::commit::spec "main"
#   shell::git::commit::spec -n "feature/my-branch"
shell::git::commit::spec() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show decorated commit graph history for a specific branch"
		shell::logger::usage "shell::git::commit::spec [-n] [-h] <branch>"
		shell::logger::item "branch" "Branch whose commit history to display"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::example "shell::git::commit::spec \"main\""
		shell::logger::example "shell::git::commit::spec -n \"feature/my-branch\""
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
	# Log format — coloured graph: hash, relative time, absolute time, author, refs, subject.
	# ---------------------------------------------------------------------------
	local log_format="%C(bold blue)%H (%h)%C(reset) - %C(bold green)(%ar at %ad)%C(reset) %C(white)%an%C(reset)%C(bold yellow)%d%C(reset) %C(dim white)- %s%C(reset)"
	local cmd_log="git log --graph --decorate --date=format:'%Y-%m-%d %H:%M:%S' --format=format:\"${log_format}\" \"${branch}\""

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_log"
		return $RETURN_SUCCESS
	fi

	shell::logger::assert "$cmd_log" \
		"Commit history for branch '${branch}' displayed" "Git log aborted" || return $?

	return $RETURN_SUCCESS
}

# shell::git::commit::spec::current function
# Displays a decorated commit graph for the currently active branch.
#
# Usage:
#   shell::git::commit::spec::current [-n] [-h]
#
# Parameters:
#   - -n, --dry-run : Optional. Print the command via shell::logger::command_clip
#                     instead of executing it.
#   - -h, --help    : Show this help message.
#
# Description:
#   Detects the currently active branch and forwards it to shell::git::commit::spec
#   to display its commit graph. If not inside a Git repository, an error is logged
#   and the function returns with failure.
#
# Returns:
#   $RETURN_SUCCESS (0) on success.
#   $RETURN_FAILURE (non-zero) if not inside a Git repository or if the git log command fails.
#
# Example:
#   shell::git::commit::spec::current
#   shell::git::commit::spec::current -n
shell::git::commit::spec::current() {
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
	if [ -z "$current_branch" ]; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi
	shell::git::commit::spec "$current_branch"
}

# shell::git::commit::all function
# Displays a decorated commit graph across all refs in the current repository.
#
# Usage:
#   shell::git::commit::all [-n] [-h]
#
# Parameters:
#   - -n, --dry-run : Optional. Print the command via shell::logger::command_clip
#                     instead of executing it.
#   - -h, --help    : Show this help message.
#
# Description:
#   Runs git log --all with a coloured, decorated graph format, covering all
#   local branches, remote-tracking branches, and tags in the repository.
#
# Returns:
#   $RETURN_SUCCESS (0) on success.
#   Non-zero exit code of the failing git command otherwise.
#
# Example:
#   shell::git::commit::all
#   shell::git::commit::all -n
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

# shell::git::commit::spec::fzf function
# Interactively selects a branch via fzf, then displays its commit history.
#
# Usage:
#   shell::git::commit::spec::fzf [-n] [-h]
#
# Parameters:
#   - -n, --dry-run : Optional. After branch selection, print the git log command
#                     via shell::logger::command_clip instead of executing it.
#   - -h, --help    : Show this help message.
#
# Description:
#   Collects all local and remote branches from the current repository,
#   deduplicates them, and presents them in an fzf picker. The selected branch
#   is forwarded to shell::git::commit::spec to display its commit graph.
#
# Returns:
#   $RETURN_SUCCESS (0) on success.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository or no branch
#                   is selected from fzf.
#
# Example:
#   shell::git::commit::spec::fzf
#   shell::git::commit::spec::fzf -n
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
	selected_branch=$(shell::options::select "${branch_list[@]}")

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

# shell::git::commit::spec::search function
# Presents a multi-select picker of all commits on a given branch, then prints
# each selected commit's info to the console and copies it to the clipboard.
#
# Usage:
#   shell::git::commit::spec::search [-h] <branch>
#
# Parameters:
#   - -h, --help : Show this help message.
#   - <branch>   : Required. Branch name whose commits to browse and select from.
#
# Description:
#   Builds a coloured commit list via git log for the specified branch, then
#   delegates to shell::options::multiselect (TAB to select multiple entries).
#   For each selected commit, logs the message via shell::logger::info and copies
#   it to the clipboard via shell::clip_value.
#
#   Hash extraction is ANSI-safe: uses grep -oE to locate every 40-char hex hash
#   in the multiselect output — no sed ANSI stripping required.
#
# Returns:
#   $RETURN_SUCCESS (0) on success or when no commits are selected.
#   $RETURN_INVALID (1) when <branch> is omitted.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#
# Example:
#   shell::git::commit::spec::search "main"
#   shell::git::commit::spec::search "feature/my-branch"
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

	# Build per-line array — one element per commit — for shell::options::multiselect.
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
	selected_output=$(shell::options::multiselect "${commit_lines[@]}")

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
		shell::clip_value "${notify_message}"
	done < <(printf '%s' "$selected_output" | grep -oE '[0-9a-f]{40}')

	return $RETURN_SUCCESS
}

# shell::git::commit::spec::search::current function
# Presents a multi-select picker of all commits on the currently active branch,
# then prints each selected commit's info to the console and copies it to the clipboard.
#
# Usage:
#   shell::git::commit::spec::search::current [-h]
#
# Parameters:
#   - -h, --help : Show this help message.
#
# Description:
#   Detects the currently active branch and forwards it to shell::git::commit::spec::search
#   to present the commit multi-select for that branch. If not inside a Git repository, an error is logged and the function returns with failure.
shell::git::commit::spec::search::current() {
	local current_branch
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
	if [ -z "$current_branch" ]; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi
	shell::git::commit::spec::search "$current_branch"
}

# shell::git::commit::all::search function
# Presents a multi-select picker of all commits across all refs in the repository,
# then prints each selected commit's info to the console and copies it to the clipboard.
#
# Usage:
#   shell::git::commit::all::search [-h]
#
# Parameters:
#   - -h, --help : Show this help message.
#
# Description:
#   Builds a coloured commit list via git log --all covering all local branches,
#   remote-tracking branches, and tags, then delegates to
#   shell::options::multiselect (TAB to select multiple entries).
#   For each selected commit, logs the message via shell::logger::info and copies
#   it to the clipboard via shell::clip_value.
#
#   Hash extraction is ANSI-safe: uses grep -oE to locate every 40-char hex hash
#   in the multiselect output — no sed ANSI stripping required.
#
# Returns:
#   $RETURN_SUCCESS (0) on success or when no commits are selected.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#
# Example:
#   shell::git::commit::all::search
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

	# Build per-line array — one element per commit — for shell::options::multiselect.
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
	selected_output=$(shell::options::multiselect "${commit_lines[@]}")

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
		shell::clip_value "${notify_message}"
	done < <(printf '%s' "$selected_output" | grep -oE '[0-9a-f]{40}')

	return $RETURN_SUCCESS
}

# shell::git::commit::pick::local function
# Multi-selects commits from a source branch (or across all refs) via fzf, then
# cherry-picks the selected commits onto the current branch in chronological order.
#
# Usage:
#   shell::git::commit::pick::local [-n] [-h] [<source_branch>]
#
# Parameters:
#   - -n, --dry-run     : Optional. Print the cherry-pick command via
#                         shell::logger::command_clip instead of executing it.
#   - -h, --help        : Show this help message.
#   - <source_branch>   : Optional. Branch whose commits to browse and pick from.
#                         When omitted, commits from ALL refs are shown (--all).
#
# Description:
#   Step 1 — Verify the git repository and capture the current (target) branch.
#   Step 2 — Build a coloured commit list:
#               • With <source_branch>: git log <source_branch>
#               • Without            : git log --all
#   Step 3 — Present a multi-select picker (TAB to select multiple commits).
#   Step 4 — Extract 40-char hex hashes from the selection in git-log order
#             (newest first), then reverse them to chronological order
#             (oldest first) — the required replay order for cherry-pick.
#   Step 5 — Display the ordered cherry-pick plan and confirm with the user.
#   Step 6 — Execute: git cherry-pick <hash1> <hash2> ...
#             On conflict, git stops automatically; the user must resolve it
#             manually and run 'git cherry-pick --continue', or abort with
#             'git cherry-pick --abort'.
#
# Returns:
#   $RETURN_SUCCESS (0) on success or user-initiated abort.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository or cherry-pick fails.
#
# Example:
#   shell::git::commit::pick::local
#   shell::git::commit::pick::local "feature/my-branch"
#   shell::git::commit::pick::local -n "main"
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
	selected_output=$(shell::options::multiselect "${commit_lines[@]}")

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

	if shell::out::confirmz "Cherry-pick ${#hashes_oldest_first[@]} commit(s) onto '${current_branch}'?"; then
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

# shell::git::commit::pick::remote function
# Multi-selects commits from a source branch (or across all refs) via fzf,
# cherry-picks them onto the current branch in chronological order, then
# pushes the current branch to the remote via an interactive push strategy picker.
#
# Usage:
#   shell::git::commit::pick::remote [-n] [-h] [<source_branch>]
#
# Parameters:
#   - -n, --dry-run     : Optional. Print the cherry-pick and push commands via
#                         shell::logger::command_clip instead of executing them.
#   - -h, --help        : Show this help message.
#   - <source_branch>   : Optional. Branch whose commits to browse and pick from.
#                         When omitted, commits from ALL refs are shown (--all).
#
# Description:
#   Identical to shell::git::commit::pick::local with one additional step:
#   Step 7 — After a successful cherry-pick, delegates to shell::git::branch::push
#             to present an interactive fzf push strategy picker and push the
#             current branch to origin.
#
#   Step 1 — Verify the git repository and capture the current (target) branch.
#   Step 2 — Build a coloured commit list:
#               • With <source_branch>: git log <source_branch>
#               • Without            : git log --all
#   Step 3 — Present a multi-select picker (TAB to select multiple commits).
#   Step 4 — Extract 40-char hex hashes, reverse to chronological order
#             (oldest first) — the required replay order for cherry-pick.
#   Step 5 — Display the ordered cherry-pick plan and confirm with the user.
#   Step 6 — Execute: git cherry-pick <hash1> <hash2> ...
#   Step 7 — Push the current branch via shell::git::branch::push (interactive).
#
# Returns:
#   $RETURN_SUCCESS (0) on success or user-initiated abort.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository or cherry-pick fails.
#
# Example:
#   shell::git::commit::pick::remote
#   shell::git::commit::pick::remote "feature/my-branch"
#   shell::git::commit::pick::remote -n "main"
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
	selected_output=$(shell::options::multiselect "${commit_lines[@]}")

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

	if shell::out::confirmz "Cherry-pick ${#hashes_oldest_first[@]} commit(s) onto '${current_branch}' and push to remote?"; then
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

# shell::git::commit::create function
# Interactively builds and commits a formatted Git commit message. In default
# mode, prompts for commit type (with emoji), description, and issue number,
# then commits, sends a Telegram activity notification, and pushes to origin.
# In --empty mode, presents pre-defined empty commit messages grouped by
# category for selection via fzf, then runs git commit --allow-empty.
#
# Usage:
#   shell::git::commit::create [-n] [-h] [-e]
#
# Parameters:
#   - -n, --dry-run : Optional. Print the git commit command via
#                     shell::logger::command_clip instead of executing it.
#   - -h, --help    : Show this help message.
#   - -e, --empty   : Optional. Switch to empty-commit mode — select a
#                     pre-defined message and run git commit --allow-empty.
#
# Description:
#   Default mode:
#     1. Select commit type (feat, fix, chore, …) via shell::options::select
#     2. Map type → emoji code via case lookup
#     3. Read commit description (loops until non-empty)
#     4. Read issue number (loops until non-empty)
#     5. Build message: <emoji> <type>: <description> <issue>
#     6. Confirm → git commit -m "<message>"
#     7. Send Telegram notification via shell::git::telegram::history::send
#     8. git push origin <current_branch>
#   Empty mode (--empty):
#     1. Select category via shell::options::select
#     2. Select pre-defined message from category via shell::options::select
#     3. Confirm → git commit --allow-empty -m "<message>"
#
# Returns:
#   $RETURN_SUCCESS (0) on success or user-initiated abort.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#   Non-zero exit code of the first failing git command otherwise.
#
# Example:
#   shell::git::commit::create
#   shell::git::commit::create --empty
#   shell::git::commit::create -n
shell::git::commit::create() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively build and commit a formatted Git commit message"
		shell::logger::usage "shell::git::commit::create [-n] [-h] [-e]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the git commit command instead of executing it"
		shell::logger::option "-e, --empty" "Use a pre-defined empty commit message (--allow-empty)"
		shell::logger::example "shell::git::commit::create"
		shell::logger::example "shell::git::commit::create --empty"
		shell::logger::example "shell::git::commit::create -n"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local empty_mode="false"
	if [ "$1" = "-e" ] || [ "$1" = "--empty" ]; then
		empty_mode="true"
		shift
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return $RETURN_FAILURE
	fi

	# ===========================================================================
	# Empty commit mode — select a pre-defined message from a category.
	# ===========================================================================
	if [ "$empty_mode" = "true" ]; then

		local -a ci_cd_messages=(
			":rocket: chore: trigger CI build to test configuration changes"
			":rocket: chore: deploy latest version to production environment"
			":white_check_mark: test: force re-run of test suite for validation purposes"
		)
		local -a docs_non_code_messages=(
			":books: docs: document recent architectural decisions and trade-offs"
			":books: docs: add notes from the latest team meeting"
			":package: dependency: document dependency updates in README.md"
		)
		local -a workflow_maintenance_messages=(
			":recycle: chore: refresh stale pull request to resolve merge conflicts"
			":recycle: chore: sync with main branch to keep feature branch up-to-date"
			":sparkles: feat: initialize new feature branch setup"
		)
		local -a team_communication_messages=(
			":tada: chore: announce upcoming team building event"
			":warning: chore: notify team about planned server maintenance downtime"
			":bookmark: docs: share details about achieving a key project milestone"
		)
		local -a experimental_research_messages=(
			":alien: experimental: start working on experimental feature for research purposes"
			":chart_with_upwards_trend: perf: log results of recent performance testing"
			":books: docs: document feedback from recent user testing session"
		)
		local -a miscellaneous_messages=(
			":busts_in_silhouette: chore: add new contributor to the project"
			":memo: docs: record internal decision about project direction"
			":bookmark: docs: mark completion of project milestone"
		)

		local selected_category
		selected_category=$(shell::options::select \
			"CI/CD Pipeline Triggers" \
			"Documentation and Non-Code Changes" \
			"Workflow and Repository Maintenance" \
			"Project and Team Communication" \
			"Experimental and Research Purposes" \
			"Miscellaneous")

		if [ -z "$selected_category" ]; then
			shell::logger::warn "No category selected — aborting"
			return $RETURN_SUCCESS
		fi

		local -a messages
		case "$selected_category" in
			"CI/CD Pipeline Triggers")             messages=("${ci_cd_messages[@]}") ;;
			"Documentation and Non-Code Changes")  messages=("${docs_non_code_messages[@]}") ;;
			"Workflow and Repository Maintenance")  messages=("${workflow_maintenance_messages[@]}") ;;
			"Project and Team Communication")      messages=("${team_communication_messages[@]}") ;;
			"Experimental and Research Purposes")  messages=("${experimental_research_messages[@]}") ;;
			"Miscellaneous")                       messages=("${miscellaneous_messages[@]}") ;;
		esac

		local selected_message
		selected_message=$(shell::options::select "${messages[@]}")

		if [ -z "$selected_message" ]; then
			shell::logger::warn "No message selected — aborting"
			return $RETURN_SUCCESS
		fi

		shell::logger::info "Selected commit message: ${selected_message}"

		if shell::out::confirmz "Proceed with this empty commit?"; then
			shell::logger::info "Commit aborted"
		else
			local cmd_commit_empty="git commit --allow-empty -m \"${selected_message}\""
			if [ "$dry_run" = "true" ]; then
				shell::logger::command_clip "$cmd_commit_empty"
			else
				shell::logger::assert "$cmd_commit_empty" \
					"Empty commit created successfully" "Empty commit aborted" || return $?

				# Push the commit via interactive push command picker.
				local empty_branch
				empty_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
				shell::git::branch::push "${empty_branch}"
			fi
		fi

		return $RETURN_SUCCESS
	fi

	# ===========================================================================
	# Default mode — formatted commit: type + emoji + description + issue.
	# ===========================================================================

	# Step 1 — select commit type via fzf.
	local selected_type
	selected_type=$(shell::options::select \
		"feat" "fix" "chore" "docs" "style" "refactor" "test" "perf" \
		"WIP" "improvement" "revert" "security" "remove" "initial source" \
		"logs" "config" "build" "dependency" "deployment" "localization" \
		"search" "experimental" "version tag" "silent changes" "deprecation" "release")

	if [ -z "$selected_type" ]; then
		shell::logger::warn "No commit type selected — aborting"
		return $RETURN_SUCCESS
	fi

	# Step 2 — map commit type → emoji code.
	local emoji
	case "$selected_type" in
		feat)              emoji=":sparkles:" ;;
		fix)               emoji=":bug:" ;;
		chore)             emoji=":wrench:" ;;
		docs)              emoji=":books:" ;;
		style)             emoji=":art:" ;;
		refactor)          emoji=":recycle:" ;;
		test)              emoji=":white_check_mark:" ;;
		perf)              emoji=":chart_with_upwards_trend:" ;;
		WIP)               emoji=":construction:" ;;
		improvement)       emoji=":zap:" ;;
		revert)            emoji=":rewind:" ;;
		security)          emoji=":lock:" ;;
		remove)            emoji=":fire:" ;;
		"initial source")  emoji=":tada:" ;;
		logs)              emoji=":loud_sound:" ;;
		config)            emoji=":gear:" ;;
		build)             emoji=":hammer:" ;;
		dependency)        emoji=":package:" ;;
		deployment)        emoji=":rocket:" ;;
		localization)      emoji=":earth_americas:" ;;
		search)            emoji=":mag:" ;;
		experimental)      emoji=":alien:" ;;
		"version tag")     emoji=":bookmark:" ;;
		"silent changes")  emoji=":mute:" ;;
		deprecation)       emoji=":warning:" ;;
		release)           emoji=":gem:" ;;
		*)                 emoji="" ;;
	esac

	# Step 3 — read commit description (non-empty, looped).
	local commit_description=""
	while [ -z "$commit_description" ]; do
		shell::logger::info "Enter a concise and clear commit description:"
		read -r commit_description
		if [ -z "$commit_description" ]; then
			shell::logger::warn "Commit description cannot be empty — please try again"
		fi
	done

	# Step 4 — read issue number (non-empty, looped).
	local issue_number=""
	while [ -z "$issue_number" ]; do
		shell::logger::info "Enter issue number (e.g. #1):"
		read -r issue_number
		if [ -z "$issue_number" ]; then
			shell::logger::warn "Issue number cannot be empty — please try again"
		fi
	done

	# Step 5 — build and display commit message.
	local commit_message="${emoji} ${selected_type}: ${commit_description} ${issue_number}"
	shell::logger::info "Commit message: ${commit_message}"

	if shell::out::confirmz "Proceed with this commit?"; then
		shell::logger::info "Commit aborted"
		return $RETURN_SUCCESS
	fi

	# Step 6 — commit.
	local cmd_commit="git commit -m \"${commit_message}\""

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_commit"
		return $RETURN_SUCCESS
	fi

	shell::logger::assert "$cmd_commit" \
		"Commit created: ${commit_message}" "Commit aborted" || return $?

	# Step 7 — collect metadata and send Telegram notification.
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

	# Step 8 — push current branch to origin via interactive push command picker.
	shell::git::branch::push "${current_branch}"

	return $RETURN_SUCCESS
}

# shell::git::commit::checkout function
# Checks out a specific commit hash (detached HEAD). Optionally creates a new
# branch from that commit. Supports dry-run mode.
#
# Usage:
#   shell::git::commit::checkout [-n] [-h] [-b <branch_name>] <commit_hash>
#
# Parameters:
#   - -n, --dry-run     : Optional. Print the command via shell::logger::command_clip
#                         instead of executing it.
#   - -h, --help        : Show this help message.
#   - -b, --branch      : Optional. Create and checkout a new branch from the
#                         commit instead of detached HEAD.
#   - <commit_hash>      : Required. Full or short commit hash to checkout.
#
# Description:
#   Step 1 — Verify the commit hash exists in the repository.
#   Step 2 — If -b is provided, run: git checkout -b <branch_name> <commit_hash>
#            Otherwise, run: git checkout <commit_hash>
#   Step 3 — Log the result via shell::logger::assert.
#
# Safety notes:
#   • When -b is omitted, HEAD enters detached state. Run 'git checkout <branch>'
#     or 'git switch -' to return to a branch.
#   • When -b is provided, the new branch is created at the commit and checked
#     out immediately (no detached HEAD).
#
# Returns:
#   $RETURN_SUCCESS (0) on success.
#   $RETURN_INVALID (1) when <commit_hash> is omitted.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository or commit
#                   does not exist.
#   Non-zero exit code of the failing git command otherwise.
#
# Example:
#   shell::git::commit::checkout "abc1234"
#   shell::git::commit::checkout -b "hotfix-legacy" "abc1234"
#   shell::git::commit::checkout -n "abc1234"
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

# shell::git::commit::checkout::fzf function
# Presents a multi-select picker of all commits across all refs via fzf,
# then checks out the first selected commit via shell::git::commit::checkout.
# Optionally creates a new branch from the selected commit.
#
# Usage:
#   shell::git::commit::checkout::fzf [-n] [-h] [-b <branch_name>]
#
# Parameters:
#   - -n, --dry-run     : Optional. After selection, print the checkout command
#                         via shell::logger::command_clip instead of executing it.
#   - -h, --help        : Show this help message.
#   - -b, --branch      : Optional. Create and checkout a new branch from the
#                         selected commit instead of detached HEAD.
#
# Description:
#   Step 1 — Verify the git repository.
#   Step 2 — Build a coloured commit list via git log --all covering all local
#            branches, remote-tracking branches, and tags.
#   Step 3 — Present a multi-select picker (TAB to mark multiple entries).
#   Step 4 — Extract the first 40-char hex hash from the selection.
#   Step 5 — Forward to shell::git::commit::checkout with the extracted hash.
#            If -b was provided, the branch name is forwarded as well.
#
# Returns:
#   $RETURN_SUCCESS (0) on success or user-initiated abort.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository or checkout fails.
#
# Example:
#   shell::git::commit::checkout::fzf
#   shell::git::commit::checkout::fzf -b "legacy-fix"
#   shell::git::commit::checkout::fzf -n
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

	# Build per-line array — one element per commit — for shell::options::multiselect.
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
	selected_output=$(shell::options::multiselect "${commit_lines[@]}")

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

# shell::git::tag::create function
# Checks out a specified branch, creates an annotated Git tag on the latest
# commit, pushes the tag to origin, restores the original branch, and sends a
# Telegram activity notification via shell::git::telegram::history::send.
#
# Usage:
#   shell::git::tag::create [-n] [-h] <branch> <tag>
#
# Parameters:
#   - -n, --dry-run : Optional. Print each command via shell::logger::command_clip
#                     instead of executing it.
#   - -h, --help    : Show this help message.
#   - <branch>      : Branch name to check out before tagging.
#   - <tag>         : Annotated tag name/version to create (e.g. v1.2.3).
#
# Description:
#   1. git checkout <branch>                — switch to target branch
#   2. Collect commit metadata              — short hash, author, date
#   3. git tag -a <tag> -m <message>        — create annotated tag with metadata
#   4. git push origin <tag>                — push tag to origin
#   5. git checkout <original_branch>       — restore original branch
#   6. shell::git::telegram::history::send  — send Telegram notification
#
# Returns:
#   $RETURN_SUCCESS (0) on full success.
#   $RETURN_INVALID (1) when <branch> or <tag> is omitted.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#   Non-zero exit code of the first failing git command otherwise.
#
# Example:
#   shell::git::tag::create "main" "v1.0.0"
#   shell::git::tag::create -n "release/1.0" "v1.0.0"
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

# shell::git::tag::remove function
# Deletes an annotated or lightweight Git tag both locally and on the remote
# origin, then sends a Telegram activity notification.
#
# Usage:
#   shell::git::tag::remove [-n] [-h] <tag>
#
# Parameters:
#   - -n, --dry-run : Optional. Print each command via shell::logger::command_clip
#                     instead of executing it.
#   - -h, --help    : Show this help message.
#   - <tag>         : The tag name/version to delete (e.g. v1.2.3).
#
# Description:
#   1. git tag -d <tag>                    — delete the tag locally
#   2. git push origin :refs/tags/<tag>    — delete the tag on origin
#   3. shell::git::telegram::history::send — send Telegram notification
#
# Returns:
#   $RETURN_SUCCESS (0) on full success.
#   $RETURN_INVALID (1) when <tag> is omitted.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#   Non-zero exit code of the first failing git command otherwise.
#
# Example:
#   shell::git::tag::remove "v1.0.0"
#   shell::git::tag::remove -n "v1.0.0"
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

# shell::git::tag::checkout function
# Checks out a specific Git tag into a detached HEAD state. Optionally creates
# a new branch from the tag. Supports dry-run mode.
#
# Usage:
#   shell::git::tag::checkout [-n] [-h] [-b <branch_name>] <tag>
#
# Parameters:
#   - -n, --dry-run     : Optional. Print the command via shell::logger::command_clip
#                         instead of executing it.
#   - -h, --help        : Show this help message.
#   - -b, --branch      : Optional. Create and checkout a new branch from the
#                         tag instead of detached HEAD.
#   - <tag>             : Required. The tag name/version to checkout (e.g. v1.2.3).
#
# Description:
#   Step 1 — Verify the tag exists locally or on origin.
#   Step 2 — If -b is provided, run: git checkout -b <branch_name> <tag>
#            Otherwise, run: git checkout <tag>
#   Step 3 — Log the result via shell::logger::assert.
#
# Safety notes:
#   • When -b is omitted, HEAD enters detached state at the tag commit.
#     Run 'git checkout <branch>' or 'git switch -' to return to a branch.
#   • When -b is provided, the new branch is created at the tag commit and
#     checked out immediately (no detached HEAD).
#   • Tags are immutable references; checking out a tag directly is read-only.
#
# Returns:
#   $RETURN_SUCCESS (0) on success.
#   $RETURN_INVALID (1) when <tag> is omitted.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository or tag
#                   does not exist.
#   Non-zero exit code of the failing git command otherwise.
#
# Example:
#   shell::git::tag::checkout "v1.0.0"
#   shell::git::tag::checkout -b "release-1.0" "v1.0.0"
#   shell::git::tag::checkout -n "v1.0.0"
shell::git::tag::checkout() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Checkout a specific Git tag (detached HEAD or new branch)"
		shell::logger::usage "shell::git::tag::checkout [-n] [-h] [-b <branch_name>] <tag>"
		shell::logger::item "tag" "Tag name/version to checkout (e.g. v1.2.3)"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-b, --branch <name>" "Create and checkout a new branch from the tag"
		shell::logger::example "shell::git::tag::checkout "v1.0.0""
		shell::logger::example "shell::git::tag::checkout -b "release-1.0" "v1.0.0""
		shell::logger::example "shell::git::tag::checkout -n "v1.0.0""
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
		cmd_checkout="git checkout -b "${branch_name}" "${tag}""
	else
		cmd_checkout="git checkout "${tag}""
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd_checkout"
		return $RETURN_SUCCESS
	fi

	# Execute checkout.
	if [ -n "$branch_name" ]; then
		shell::logger::assert "$cmd_checkout" 			"Created and checked out branch '${branch_name}' from tag ${tag} (${commit_hash:0:8})" 			"Tag checkout aborted" || return $?
	else
		shell::logger::assert "$cmd_checkout" 			"Checked out tag ${tag} (${commit_hash:0:8}) — detached HEAD" 			"Tag checkout aborted" || return $?
	fi

	return $RETURN_SUCCESS
}

# shell::git::tag::checkout::fzf function
# Presents a picker of all Git tags (local + remote) with origin markers,
# then checks out the selected tag via shell::git::tag::checkout.
# Optionally creates a new branch from the selected tag.
#
# Usage:
#   shell::git::tag::checkout::fzf [-n] [-h] [-b <branch_name>]
#
# Parameters:
#   - -n, --dry-run     : Optional. After selection, print the checkout command
#                         via shell::logger::command_clip instead of executing it.
#   - -h, --help        : Show this help message.
#   - -b, --branch      : Optional. Create and checkout a new branch from the
#                         selected tag instead of detached HEAD.
#
# Description:
#   Step 1 — Verify the git repository.
#   Step 2 — Collect all local tags and remote tags from origin.
#   Step 3 — Build display lines with origin markers:
#              [LOCAL  ] : <tag>  — exists only locally
#              [REMOTE ] : <tag>  — exists only on origin
#              [BOTH   ] : <tag>  — exists on both local and origin
#   Step 4 — Present a single-select picker via shell::options::select.
#   Step 5 — Extract the tag name from the selection using the ' : ' separator.
#   Step 6 — Forward to shell::git::tag::checkout with the extracted tag name.
#            If -b was provided, the branch name is forwarded as well.
#
# Returns:
#   $RETURN_SUCCESS (0) on success or user-initiated abort.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository or checkout fails.
#
# Example:
#   shell::git::tag::checkout::fzf
#   shell::git::tag::checkout::fzf -b "release-1.0"
#   shell::git::tag::checkout::fzf -n
shell::git::tag::checkout::fzf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Select a tag via fzf and check it out"
		shell::logger::usage "shell::git::tag::checkout::fzf [-n] [-h] [-b <branch_name>]"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the checkout command instead of executing it"
		shell::logger::option "-b, --branch <name>" "Create and checkout a new branch from the selected tag"
		shell::logger::example "shell::git::tag::checkout::fzf"
		shell::logger::example "shell::git::tag::checkout::fzf -b "release-1.0""
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
			[ "$t" = "$rt" ] && { is_remote="true"; break; }
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
			[ "$t" = "$rt" ] && { is_local="true"; break; }
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
	selected_output=$(shell::options::select "${tag_lines[@]}")

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

# shell::git::tag::all function
# Displays all Git tags in the repository, both local and remote, with origin
# markers and associated commit metadata.
#
# Usage:
#   shell::git::tag::all [-n] [-h]
#
# Parameters:
#   - -n, --dry-run : Optional. Print the git commands via
#                     shell::logger::command_clip instead of executing them.
#   - -h, --help    : Show this help message.
#
# Description:
#   Collects all local tags and remote tags from origin, deduplicates them,
#   and prints a formatted table showing:
#     • Tag name
#     • Origin marker: [LOCAL] | [REMOTE] | [BOTH]
#     • Commit hash (short)
#     • Commit date
#     • Commit message (first line)
#     • Tagger name (for annotated tags) or author (for lightweight tags)
#
# Returns:
#   $RETURN_SUCCESS (0) on success.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#
# Example:
#   shell::git::tag::all
#   shell::git::tag::all -n
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
			[ "$t" = "$rt" ] && { is_remote="true"; break; }
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
			[ "$t" = "$rt" ] && { is_local="true"; break; }
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
	local _lw=14   # label column width for printf alignment
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

# shell::git::tag::remove::fzf function
# Presents a picker of all Git tags (local + remote) with origin markers,
# then removes the selected tag via shell::git::tag::remove.
#
# Usage:
#   shell::git::tag::remove::fzf [-n] [-h]
#
# Parameters:
#   - -n, --dry-run : Optional. After selection, print the remove commands
#                     via shell::logger::command_clip instead of executing them.
#   - -h, --help    : Show this help message.
#
# Description:
#   Step 1 — Verify the git repository.
#   Step 2 — Collect all local tags and remote tags from origin.
#   Step 3 — Build display lines with origin markers:
#              [LOCAL  ] : <tag>  — exists only locally
#              [REMOTE ] : <tag>  — exists only on origin
#              [BOTH   ] : <tag>  — exists on both local and origin
#   Step 4 — Present a single-select picker via shell::options::select.
#   Step 5 — Extract the tag name from the selection using the ' : ' separator.
#   Step 6 — Confirm removal with the user.
#   Step 7 — Forward to shell::git::tag::remove with the extracted tag name.
#
# Returns:
#   $RETURN_SUCCESS (0) on success or user-initiated abort.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository or removal fails.
#
# Example:
#   shell::git::tag::remove::fzf
#   shell::git::tag::remove::fzf -n
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
			[ "$t" = "$rt" ] && { is_remote="true"; break; }
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
			[ "$t" = "$rt" ] && { is_local="true"; break; }
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
	selected_output=$(shell::options::select "${tag_lines[@]}")

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
	if shell::out::confirmz "Remove tag '${selected_tag}' from local and origin?"; then
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

# shell::git::commit::revert::fzf function
# Presents a multi-select picker of all commits across all refs in the repository,
# then shows an action menu to revert the selected commits with various strategies.
# Supports creating a new revert branch, handling conflicts, and pushing to remote.
#
# Usage:
#   shell::git::commit::revert::fzf [-n] [-h]
#
# Parameters:
#   - -n, --dry-run : Optional. Print the commands via shell::logger::command_clip
#                     instead of executing them.
#   - -h, --help    : Show this help message.
#
# Description:
#   Step 1 — Verify the git repository.
#   Step 2 — Build a coloured commit list via git log --all covering all local
#            branches, remote-tracking branches, and tags.
#   Step 3 — Present a multi-select picker (TAB to mark multiple commits).
#   Step 4 — Extract 40-char hex hashes from the selection.
#   Step 5 — Build a revert branch name: rev/<YYYYMMDD.HHMMSS>.<sanitized-source>
#   Step 6 — Present an action menu with revert strategies:
#            • Revert commits (auto-commit)         — git revert <hash1> <hash2> ...
#            • Revert commits (no-commit)           — git revert -n <hash1> <hash2> ...
#            • Revert merge commit (-m 1)           — git revert -m 1 <merge-hash>
#            • Revert range (oldest..newest)        — git revert <old>..<new>
#            • Revert with custom message           — git revert --edit <hash1> ...
#            • Revert quietly (no editor)           — git revert --no-edit <hash1> ...
#   Step 7 — Create revert branch, execute revert, handle conflicts.
#   Step 8 — Prompt: commit to local / push to remote / both.
#   Step 9 — Execute chosen action and send Telegram notification.
#
# Branch naming pattern:
#   rev/<YYYYMMDD.HHMMSS>.<sanitized-source>
#   <sanitized-source> is derived from current branch or first commit hash.
#
# Returns:
#   $RETURN_SUCCESS (0) on success or user-initiated abort.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository or revert fails.
#
# Example:
#   shell::git::commit::revert::fzf
#   shell::git::commit::revert::fzf -n
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
	selected_output=$(shell::options::multiselect "${commit_lines[@]}")

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
	action=$(shell::options::select_key "${action_options[@]}")

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

	# shell::out::confirmz returns 1 for YES, 0 for NO
	# So: if confirmz; then → true (0) = NO chosen → abort
	#     if confirmz; then → false (1) = YES chosen → continue
	if shell::out::confirmz "Proceed with revert on new branch '${revert_branch}'?"; then
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
	apply_action=$(shell::options::select_key "${apply_options[@]}")

	if [ -z "$apply_action" ] || [ "$apply_action" = "local" ]; then
		shell::logger::info "Revert committed locally on branch '${revert_branch}'"
		shell::clip_value "${revert_branch}"
	elif [ "$apply_action" = "remote" ] || [ "$apply_action" = "both" ]; then
		local cmd_push="git push -u origin \"${revert_branch}\""
		shell::logger::assert "$cmd_push" \
			"Revert branch '${revert_branch}' pushed to origin" \
			"Push failed — run 'git push -u origin ${revert_branch}' manually" || return $?
	fi

	if [ "$apply_action" = "both" ]; then
		shell::clip_value "${revert_branch}"
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
		if shell::out::confirmz "Return to original branch '${current_branch}'?"; then
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

# shell::git::commit::spec::history::fzf function
# Interactive commit history browser: selects a commit via fzf, then loops
# through view-action picks until the user explicitly chooses Exit.
#
# Usage:
#   shell::git::commit::spec::history::fzf [-n] [-h] [<branch>]
#
# Parameters:
#   - -n, --dry-run : Optional. Print the git log command instead of executing.
#   - -h, --help    : Show this help message.
#   - <branch>      : Optional. Branch to inspect. Defaults to current branch.
#
# Description:
#   Step 1 — Verify git repository and resolve target branch.
#   Step 2 — Build a coloured commit list (full 40-char hash per entry).
#   Step 3 — Present commit picker via shell::options::select (fzf wrapper).
#   Step 4 — Extract 40-char commit hash from the selected line.
#   Step 5 — Collect commit metadata (author, date, subject).
#   Step 6–7 (loop) — Repeatedly present view-action picker via
#             shell::options::select_key, render the selected view in a tmux
#             display-popup (90 × 90 %) or less, then return to the picker.
#             Available actions:
#              • diff          — full git show (what changed in this commit)
#              • blame         — git blame per file at this commit (who wrote each line)
#              • file_history  — git log --follow -p per file (full change history)
#              • stat          — files changed with line-count stats only
#              • exit          — leave the view loop and return to the terminal
#   Step 8 — Log commit info and copy to clipboard via shell::clip_value.
#
# Returns:
#   $RETURN_SUCCESS (0) on success or user-initiated abort.
#   $RETURN_INVALID (1) when the branch does not exist.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#
# Example:
#   shell::git::commit::spec::history::fzf
#   shell::git::commit::spec::history::fzf "feature/my-branch"
#   shell::git::commit::spec::history::fzf -n
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

	if ! git rev-parse --verify --quiet "refs/heads/${target_branch}" >/dev/null 2>&1 && \
	   ! git rev-parse --verify --quiet "refs/remotes/origin/${target_branch}" >/dev/null 2>&1; then
		shell::logger::error "Branch '${target_branch}' does not exist locally or on origin"
		return $RETURN_INVALID
	fi

	# ---------------------------------------------------------------------------
	# Step 2 — Build coloured commit list.
	# ---------------------------------------------------------------------------
	shell::install_package fzf >/dev/null 2>&1

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
	# Step 3 — Commit picker via shell::options::select (fzf wrapper).
	# ---------------------------------------------------------------------------
	local selected_line
	selected_line=$(shell::options::select "${commit_lines[@]}")

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
	shell::is_command_available delta && has_delta="true"

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
		action=$(shell::options::select_key "${action_options[@]}")

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
		} > "$tmpfile"

		case "$action" in
			# -------------------------------------------------------------------
			diff)
				if [ "$has_delta" = "true" ]; then
					git show --color=always "$commit_hash" 2>/dev/null \
						| delta --no-gitconfig --line-numbers --navigate --dark 2>/dev/null \
						>> "$tmpfile" \
						|| git show --color=always "$commit_hash" 2>/dev/null >> "$tmpfile"
				else
					git show --color=always "$commit_hash" 2>/dev/null >> "$tmpfile"
				fi
				;;

			# -------------------------------------------------------------------
			blame)
				local -a changed_files_blame
				while IFS= read -r f; do
					[ -n "$f" ] && changed_files_blame+=("$f")
				done < <(git diff-tree --no-commit-id --name-only -r "$commit_hash" 2>/dev/null)

				if [ "${#changed_files_blame[@]}" -eq 0 ]; then
					printf "  (no files changed in this commit)\n" >> "$tmpfile"
				else
					printf "\033[1;35m  Files changed: %d\033[0m\n\n" "${#changed_files_blame[@]}" >> "$tmpfile"
					local f_blame
					for f_blame in "${changed_files_blame[@]}"; do
						{
							printf "\033[1;34m────────────────────────────────────────────────────────────\033[0m\n"
							printf "\033[1;33m  %-6s %s\033[0m\n" "File:" "$f_blame"
							printf "\033[1;34m────────────────────────────────────────────────────────────\033[0m\n"
							git blame --date=short -c "${commit_hash}" -- "$f_blame" 2>/dev/null \
								|| printf "  (blame not available for this file at this commit)\n"
							printf "\n"
						} >> "$tmpfile"
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
					printf "  (no files changed in this commit)\n" >> "$tmpfile"
				else
					printf "\033[1;35m  Files changed: %d\033[0m\n\n" "${#changed_files_hist[@]}" >> "$tmpfile"
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
								-- "$f_hist" 2>/dev/null \
								|| printf "  (history not available for this file)\n"
							printf "\n"
						} >> "$tmpfile"
					done
				fi
				;;

			# -------------------------------------------------------------------
			stat)
				git show --stat --color=always "$commit_hash" 2>/dev/null >> "$tmpfile"
				;;
		esac

		# Show in tmux display-popup (blocking with -E) or fall back to less.
		if [ -n "${TMUX:-}" ] && shell::is_command_available tmux; then
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
	shell::clip_value "${notify_message}"

	return $RETURN_SUCCESS
}

# shell::git::commit::spec::history::fzf::current function
# Convenience wrapper around shell::git::commit::spec::history::fzf that
# automatically detects the currently checked-out branch and opens the
# interactive commit history viewer for it.
#
# Usage:
#   shell::git::commit::spec::history::fzf::current [-n] [-h]
#
# Parameters:
#   - -n, --dry-run : Optional. Print the commands instead of executing them.
#   - -h, --help    : Show this help message.
#
# Returns:
#   $RETURN_SUCCESS (0) on success.
#   $RETURN_FAILURE (non-zero) when not inside a Git repository.
#
# Example:
#   shell::git::commit::spec::history::fzf::current
#   shell::git::commit::spec::history::fzf::current -n
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