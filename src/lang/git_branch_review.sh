#!/usr/bin/env bash
# @file lang/git_branch_review.sh
# @brief Read-only branch review: which branches are merged into the base branch, which are stale.
# @description
#   Report-only helpers for tidying a repository. Nothing here deletes or changes anything.
#   Every list is built from ONE `git for-each-ref` call (plus one `git worktree list` where
#   needed), never one git call per branch, and parsed from machine formats only.
#
#   Settings (environment, all optional):
#     SHELL_GIT_BASE_BRANCH         the base branch (default: origin/HEAD, else main, master, develop)
#     SHELL_GIT_PROTECTED_BRANCHES  space separated names never listed as merged (default: "main master develop")
#     SHELL_GIT_STALE_DAYS          age in days after which a branch is stale (default: 90)

: "${SHELL_GIT_PROTECTED_BRANCHES:=main master develop}"
: "${SHELL_GIT_STALE_DAYS:=90}"

# @internal
# @description Resolve the base branch of the repository: the one other branches are compared with.
#   Order: `SHELL_GIT_BASE_BRANCH`, the branch `origin/HEAD` points at, then the first of
#   `main`, `master`, `develop` that exists locally. Never hardcodes a name that does not exist.
# @stdout The local branch name.
# @exitcode 0 A base branch was found.
# @exitcode 1 None was found.
# @example
#   base="$(_shell::git::branch::base)"
#
_shell::git::branch::base() {
	local cand
	if [ -n "${SHELL_GIT_BASE_BRANCH-}" ]; then
		if git rev-parse --verify --quiet "refs/heads/${SHELL_GIT_BASE_BRANCH}" >/dev/null 2>&1; then
			printf '%s\n' "$SHELL_GIT_BASE_BRANCH"
			return "$RETURN_SUCCESS"
		fi
		return "$RETURN_FAILURE"
	fi
	cand="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
	cand="${cand#origin/}"
	if [ -n "$cand" ] && git rev-parse --verify --quiet "refs/heads/${cand}" >/dev/null 2>&1; then
		printf '%s\n' "$cand"
		return "$RETURN_SUCCESS"
	fi
	for cand in main master develop; do
		if git rev-parse --verify --quiet "refs/heads/${cand}" >/dev/null 2>&1; then
			printf '%s\n' "$cand"
			return "$RETURN_SUCCESS"
		fi
	done
	return "$RETURN_FAILURE"
}

# @description List the local branches that are already merged into the base branch.
#   Candidates for clean-up: the base branch, the branch you are on, the protected names
#   and any branch checked out in a worktree are left out. Report only: nothing is deleted.
#   A branch that was squash-merged is NOT detected (its commits are not in the base's history).
# @option -b | --base Optional. Compare with this branch instead of the detected base.
# @option -h | --help Show this help message.
# @stdout One branch name per line.
# @exitcode 0 The list was printed (it may be empty).
# @exitcode 1 Not a repository, or no base branch could be determined.
# @exitcode 2 Invalid usage.
# @example
#   shell::git::branch::merged
#   shell::git::branch::merged --base develop
#
shell::git::branch::merged() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List local branches already merged into the base branch (report only)"
		shell::logger::usage "shell::git::branch::merged [-b <base>]"
		shell::logger::option "-b, --base <branch>" "Compare with this branch (default: detected base)"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::note "Squash-merged branches are not detected. Nothing is deleted."
		shell::logger::example "shell::git::branch::merged"
		return "$RETURN_SUCCESS"
	fi

	local base=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-b | --base)
			if [ -z "${2-}" ]; then
				shell::logger::error "--base needs a branch name"
				return "$RETURN_INVALID"
			fi
			base="$2"
			shift
			;;
		*)
			shell::logger::error "Unknown argument: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return "$RETURN_FAILURE"
	fi
	if [ -n "$base" ]; then
		if ! git rev-parse --verify --quiet "refs/heads/${base}" >/dev/null 2>&1; then
			shell::logger::error "Unknown base branch: $base"
			return "$RETURN_FAILURE"
		fi
	else
		base="$(_shell::git::branch::base)" || {
			shell::logger::error "Cannot determine the base branch (set SHELL_GIT_BASE_BRANCH or pass --base)"
			return "$RETURN_FAILURE"
		}
	fi

	local current worktrees
	current="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)"
	# Branches checked out in any worktree (one call); `branch refs/heads/<name>` lines.
	worktrees="$(git worktree list --porcelain 2>/dev/null | awk '$1 == "branch" { sub("^refs/heads/", "", $2); printf "%s ", $2 }')"

	GIT_OPTIONAL_LOCKS=0 git for-each-ref "--merged=refs/heads/${base}" '--format=%(refname:short)' refs/heads 2>/dev/null |
		awk -v base="$base" -v cur="$current" -v prot="$SHELL_GIT_PROTECTED_BRANCHES" -v wt="$worktrees" '
			BEGIN {
				n = split(prot, p, " "); for (i = 1; i <= n; i++) skip[p[i]] = 1
				n = split(wt, w, " "); for (i = 1; i <= n; i++) if (w[i] != "") skip[w[i]] = 1
				skip[base] = 1; if (cur != "") skip[cur] = 1
			}
			!($0 in skip) { print }'
	return "$RETURN_SUCCESS"
}

# @description Report the local branches whose last commit is older than a number of days.
#   Report only: nothing is deleted. Oldest first. On a terminal the branch names are
#   cyan and the columns are aligned; elsewhere (or with `-q`) each line is
#   `name<TAB>days<TAB>date<TAB>hash`, ready for scripts.
# @option -d | --days Optional. Age threshold in days (default `SHELL_GIT_STALE_DAYS`, 90).
# @option -q | --plain Optional. Tab separated, no colour, no alignment.
# @option -h | --help Show this help message.
# @stdout One line per stale branch.
# @exitcode 0 The report was printed (it may be empty).
# @exitcode 1 Not inside a Git repository.
# @exitcode 2 Invalid usage.
# @example
#   shell::git::branch::stale
#   shell::git::branch::stale --days 30 --plain
#
shell::git::branch::stale() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Report local branches with no commit for N days (report only)"
		shell::logger::usage "shell::git::branch::stale [-d <days>] [-q]"
		shell::logger::option "-d, --days <n>" "Age threshold in days (default: SHELL_GIT_STALE_DAYS, 90)"
		shell::logger::option "-q, --plain" "Tab separated, no colour"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::example "shell::git::branch::stale --days 30"
		return "$RETURN_SUCCESS"
	fi

	local days="$SHELL_GIT_STALE_DAYS" plain="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-d | --days)
			days="${2-}"
			shift
			;;
		-q | --plain) plain="true" ;;
		*)
			shell::logger::error "Unknown argument: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done
	case "$days" in
	'' | *[!0-9]*)
		shell::logger::error "--days must be a whole number (got '${days}')"
		return "$RETURN_INVALID"
		;;
	esac
	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return "$RETURN_FAILURE"
	fi

	local current now color="0"
	current="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)"
	now="$(date +%s)"
	if [ "$plain" = "false" ] && [ -t 1 ] && [ -z "${NO_COLOR-}" ]; then color="1"; fi

	GIT_OPTIONAL_LOCKS=0 git for-each-ref --sort=committerdate \
		'--format=%(refname:short)%09%(committerdate:unix)%09%(committerdate:format:%Y-%m-%d %H:%M)%09%(objectname:short)' \
		refs/heads 2>/dev/null |
		awk -F'\t' -v now="$now" -v days="$days" -v cur="$current" -v color="$color" '
			$1 == cur { next }
			{ age = int((now - $2) / 86400)
			  if (age < days) next
			  n++; nm[n] = $1; ag[n] = age; dt[n] = $3; hs[n] = $4
			  if (length($1) > w) w = length($1) }
			END {
				esc = sprintf("%c", 27)
				for (i = 1; i <= n; i++) {
					if (color == "1")
						printf "%s[36m%s%s[0m%s  %s[2m%5dd  %s  %s%s[0m\n", esc, nm[i], esc, sprintf("%" (w - length(nm[i])) "s", ""), esc, ag[i], dt[i], hs[i], esc
					else
						printf "%s\t%d\t%s\t%s\n", nm[i], ag[i], dt[i], hs[i]
				}
			}'
	return "$RETURN_SUCCESS"
}
