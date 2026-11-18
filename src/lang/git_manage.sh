#!/usr/bin/env bash
# @file lang/git_manage.sh
# @brief Live fzf hub for Git: pick an area, run an action, come back to the list.

# @description Live hub for Git: pick an area, run an action, come back to the list (loop).
#
#   Lists the Git areas of the current repository (branch, commit, tag, stash, diff, config, patch)
#   with a live preview on the right (current branch, upstream, ahead/behind, working tree counts,
#   recent commits, tags and stashes). Enter opens an action menu for that area; every action is an
#   existing fzf workflow (shell::git::branch::merge::fzf, shell::git::diff::fzf, ...). When an action
#   finishes the area list is shown again with the cursor on the same area and a fresh preview, so the
#   flow is list -> action -> list. It ends only with ESC / Ctrl-C or "← Back" (SHELL_FZF_BACK_LABEL)
#   at the area list; Back at the action menu returns to the list. Back never changes anything, and
#   every action keeps its own confirmations.
# @option -n | --dry-run Optional. Run the actions in dry-run mode (they print their git commands instead of executing them).
# @option -h | --help Show this help message.
# @exitcode 0 Success (closed with ESC / Ctrl-C).
# @exitcode 1 Not inside a Git repository, or a temporary directory could not be created.
# @exitcode 2 Unknown option.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @see shell::workspace::manage::fzf
# @see shell::git::diff::fzf
# @example
#   shell::git::manage::fzf
#   shell::git::manage::fzf -n
#
shell::git::manage::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Live hub for Git: preview, branch, commit, tag, stash, diff, config, patch (loops back to the list)"
		shell::logger::usage "shell::git::manage::fzf [-n] [-h]"
		shell::logger::option "-n, --dry-run" "Run the actions in dry-run mode (print the git commands)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "The list comes back after every action; leave with ESC or '$SHELL_FZF_BACK_LABEL' (returns ${RETURN_BACK})."
		shell::logger::example "shell::git::manage::fzf"
		shell::logger::example "shell::git::manage::fzf -n"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi
	if [ "$#" -gt 0 ]; then
		shell::logger::error "Unknown argument: $1"
		return "$RETURN_INVALID"
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return "$RETURN_FAILURE"
	fi

	shell::dependency::fzf::ensure

	local work rc=0
	work="$(mktemp -d "${TMPDIR:-/tmp}/shell-git.XXXXXX")" || {
		shell::logger::error "Could not create a temporary directory."
		return "$RETURN_FAILURE"
	}
	_shell::git::manage::loop "$dry_run" "$work" || rc=$?
	rm -rf "$work"
	return "$rc"
}

# @internal
# @description Writes one preview file per Git area (`<dir>/git.<area>`) from the current repository state.
# @arg $1 string Output directory (created if missing).
# @exitcode 0 Success.
# @example
#   _shell::git::manage::previews "$work/g"
#
_shell::git::manage::previews() {
	local out="${1-}"
	[ -n "$out" ] || return "$RETURN_INVALID"
	mkdir -p "$out" || return "$RETURN_FAILURE"

	local branch upstream counts ahead="-" behind="-" staged unstaged untracked
	branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
	upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"
	if [ -n "$upstream" ]; then
		counts="$(git rev-list --left-right --count "HEAD...$upstream" 2>/dev/null)"
		ahead="${counts%%[[:space:]]*}"
		behind="${counts##*[[:space:]]}"
	fi
	staged="$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')"
	unstaged="$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')"
	untracked="$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')"

	{
		printf 'Branch    %s\n' "${branch:-?}"
		printf 'Upstream  %s  (ahead %s, behind %s)\n\n' "${upstream:-none}" "$ahead" "$behind"
		git branch -vv --sort=-committerdate --color=never 2>/dev/null | head -n 15
	} >"$out/git.branch"

	{
		printf 'Branch    %s\n\n' "${branch:-?}"
		git log -n 20 --date=short --pretty=format:'%h %ad %<(14,trunc)%an %s' 2>/dev/null
		printf '\n'
	} >"$out/git.commit"

	{
		printf 'Tags      %s\n\n' "$(git tag 2>/dev/null | wc -l | tr -d ' ')"
		git tag --sort=-creatordate 2>/dev/null | head -n 20
	} >"$out/git.tag"

	{
		printf 'Stashes   %s\n\n' "$(git stash list 2>/dev/null | wc -l | tr -d ' ')"
		git stash list 2>/dev/null | head -n 20
	} >"$out/git.stash"

	{
		printf 'Staged %s   Unstaged %s   Untracked %s\n\n' "$staged" "$unstaged" "$untracked"
		git status --short 2>/dev/null | head -n 30
	} >"$out/git.diff"

	{
		printf 'Local config\n\n'
		git config --local --list 2>/dev/null | head -n 30
	} >"$out/git.config"

	printf 'Create patches from commits, or apply a directory of .patch files.\n\nBranch    %s\n' "${branch:-?}" >"$out/git.patch"
	printf 'Go back without changing anything\n' >"$out/git.@back"
}

# @internal
# @description The loop of shell::git::manage::fzf: area list -> action menu -> list.
# @arg $1 string `true` for dry-run.
# @arg $2 string Work directory for the previews.
# @exitcode 0 The user left with ESC / Ctrl-C.
# @exitcode 11 The user picked "← Back" at the area list.
# @example
#   _shell::git::manage::loop false "$work"
#
_shell::git::manage::loop() {
	local dry_run="${1-false}" work="${2-}"
	local back="$SHELL_FZF_BACK_LABEL" tab=$'\t'
	local picked rc idx selected action
	local -a init=() flag=() actions=()
	[ "$dry_run" = "true" ] && flag=(-n)

	while true; do
		rm -rf "$work/g"
		_shell::git::manage::previews "$work/g" || return "$RETURN_FAILURE"

		picked="$({
			printf '%s\t%s\n' "branch" "branch"
			printf '%s\t%s\n' "commit" "commit"
			printf '%s\t%s\n' "tag" "tag"
			printf '%s\t%s\n' "stash" "stash"
			printf '%s\t%s\n' "diff" "diff"
			printf '%s\t%s\n' "config" "config"
			printf '%s\t%s\n' "patch" "patch"
			printf '%s\t%s\n' "$back" "@back"
		} | shell::fzf::select ${init[@]+"${init[@]}"} \
			--prompt="Git: " \
			--header="Enter: actions   ESC: leave   ${back}: previous" \
			--delimiter="$tab" --with-nth=1 --initial-field 1 \
			--preview="cat '$work'/g/git.{2}" --preview-window="right:60%:wrap" \
			--height=60%)"
		rc=$?
		if [ "$rc" -ne 0 ] || [ -z "$picked" ]; then
			shell::logger::info "Closed"
			return "$RETURN_SUCCESS"
		fi
		selected="${picked%%"$tab"*}"
		idx="${picked##*"$tab"}"
		if [ "$idx" = "@back" ]; then
			shell::logger::info "Back — nothing was changed"
			return "$RETURN_BACK"
		fi
		init=(--initial "$selected")

		case "$selected" in
		branch) actions=("browse all" merge rename sync) ;;
		commit) actions=(history pick checkout revert squash amend) ;;
		tag) actions=(checkout remove) ;;
		stash) actions=(apply preview remove) ;;
		diff) actions=(working staged "pick commit") ;;
		config) actions=(browse) ;;
		patch) actions=(apply) ;;
		*) actions=() ;;
		esac

		action="$(printf '%s\n' "${actions[@]}" "$back" | shell::fzf::select \
			--prompt="Action: " \
			--header="Git ${selected}" \
			--height=40%)"
		rc=$?
		if [ "$rc" -ne 0 ] || [ -z "$action" ]; then
			shell::logger::info "Closed"
			return "$RETURN_SUCCESS"
		fi
		if [ "$action" = "$back" ]; then
			continue
		fi

		# Each action runs in this shell and then the area list comes back.
		case "$selected:$action" in
		"branch:browse all") shell::git::branch::all::fzf ${flag[@]+"${flag[@]}"} || true ;;
		branch:merge) shell::git::branch::merge::fzf ${flag[@]+"${flag[@]}"} || true ;;
		branch:rename) shell::git::branch::rename::fzf ${flag[@]+"${flag[@]}"} || true ;;
		branch:sync) shell::git::branch::sync ${flag[@]+"${flag[@]}"} || true ;;
		commit:history) shell::git::commit::spec::history::fzf::current ${flag[@]+"${flag[@]}"} || true ;;
		commit:pick) shell::git::commit::pick::fzf ${flag[@]+"${flag[@]}"} || true ;;
		commit:checkout) shell::git::commit::checkout::fzf ${flag[@]+"${flag[@]}"} || true ;;
		commit:revert) shell::git::commit::revert::fzf ${flag[@]+"${flag[@]}"} || true ;;
		commit:squash) shell::git::commit::squash::fzf ${flag[@]+"${flag[@]}"} || true ;;
		commit:amend) shell::git::commit::amend ${flag[@]+"${flag[@]}"} || true ;;
		tag:checkout) shell::git::tag::checkout::fzf ${flag[@]+"${flag[@]}"} || true ;;
		tag:remove) shell::git::tag::remove::fzf ${flag[@]+"${flag[@]}"} || true ;;
		stash:apply) shell::git::branch::stash::apply::fzf ${flag[@]+"${flag[@]}"} || true ;;
		stash:preview) shell::git::branch::stash::preview::fzf ${flag[@]+"${flag[@]}"} || true ;;
		stash:remove) shell::git::branch::stash::remove::fzf ${flag[@]+"${flag[@]}"} || true ;;
		diff:working) shell::git::diff::fzf ${flag[@]+"${flag[@]}"} || true ;;
		diff:staged) shell::git::diff::fzf --staged ${flag[@]+"${flag[@]}"} || true ;;
		"diff:pick commit") shell::git::diff::fzf --pick ${flag[@]+"${flag[@]}"} || true ;;
		config:browse) shell::git::config::fzf ${flag[@]+"${flag[@]}"} || true ;;
		patch:apply) shell::git::patch::apply::fzf ${flag[@]+"${flag[@]}"} || true ;;
		*) shell::logger::error "Invalid action." ;;
		esac
	done
}
