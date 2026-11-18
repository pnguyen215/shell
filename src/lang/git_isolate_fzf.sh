#!/usr/bin/env bash
# @file lang/git_isolate_fzf.sh
# @brief fzf pickers and menus of the persistent shell::git::isolate session.
# @description
#   Every picker returns one of three codes, so a caller can tell the outcomes apart:
#     0   something was chosen (on stdout)
#     9   the user cancelled (ESC / Ctrl-C), RETURN_CANCELLED
#     11  the user picked the "← Back" row (SHELL_FZF_BACK_LABEL), RETURN_BACK
#   Previews are read-only (`git show`, `git diff`, `git log`).

# @internal
# @description Runs fzf over `display<TAB>key` rows from stdin plus a "← Back" row, and prints the keys.
# @arg $1 string Prompt.
# @arg $2 string Header.
# @arg $3 string fzf preview command (`{2}` is the key).
# @arg $4 string `true` to allow several rows (Tab).
# @arg $5 string Optional. Key to start the cursor on (cursor memory).
# @stdin Rows `display<TAB>key`.
# @stdout The chosen key(s), one per line.
# @exitcode 0 At least one row chosen.
# @exitcode 9 The user cancelled (ESC / Ctrl-C) or chose nothing.
# @exitcode 11 The user picked the "← Back" row.
# @example
#   printf 'a\ta\n' | _shell::git::isolate::fzf::rows "Pick: " "Enter" "echo {2}" false
#
_shell::git::isolate::fzf::rows() {
	local prompt="${1-}" header="${2-}" preview="${3-}" multi="${4-false}" initial="${5-}"
	local back="$SHELL_FZF_BACK_LABEL" tab=$'\t' picked rc keys
	local -a extra=()
	[ "$multi" = "true" ] && extra=(--multi --bind "ctrl-a:select-all")
	[ -n "$initial" ] && extra+=(--initial "$initial" --initial-field 2)

	picked="$({
		cat
		printf '%s\t%s\n' "$back" "@back"
	} | shell::fzf::select ${extra[@]+"${extra[@]}"} \
		--prompt="$prompt" \
		--header="$header" \
		--delimiter="$tab" --with-nth=1 \
		--preview="$preview" --preview-window="right:60%:wrap" \
		--height=80%)"
	rc=$?
	if [ "$rc" -ne 0 ] || [ -z "$picked" ]; then
		return "$RETURN_CANCELLED"
	fi
	keys="$(printf '%s\n' "$picked" | awk -F'\t' '{ print $2 }')"
	case "$(printf '%s\n' "$keys" | head -n 1)" in
	@back) return "$RETURN_BACK" ;;
	esac
	printf '%s\n' "$keys" | grep -vx '@back'
	return "$RETURN_SUCCESS"
}

# @internal
# @description Lists local and remote branches (newest first, current one marked, date and subject) with a
#   history preview, and prints the chosen branch name.
# @arg $1 string Optional. Prompt (default "Branch: ").
# @stdout The branch name.
# @exitcode 0 Chosen.
# @exitcode 9 Cancelled.
# @exitcode 11 Back.
# @example
#   src="$(_shell::git::isolate::fzf::branch "Source branch: ")"
#
_shell::git::isolate::fzf::branch() {
	local current pv
	current="$(git symbolic-ref -q --short HEAD 2>/dev/null)"
	pv='case "$1" in @back) echo "Go back without changing anything";; *) git log --color=always --decorate --date=short -n 40 --format="%C(yellow)%h%C(reset) %C(green)%ad%C(reset) %C(cyan)%an%C(reset) %s%C(auto)%d" "$1" -- ;; esac'
	git for-each-ref --sort=-committerdate --format='%(refname:short)%09%(committerdate:short)%09%(subject)' refs/heads refs/remotes 2>/dev/null |
		awk -F'\t' -v cur="$current" '
			$1 ~ /\/HEAD$/ || $1 !~ /./ { next }
			{
				mark = ($1 == cur) ? " (current)" : ""
				printf "%s%s  %s  %s\t%s\n", $1, mark, $2, $3, $1
			}' |
		_shell::git::isolate::fzf::rows "${1:-Branch: }" "Enter: choose   ESC: leave   ${SHELL_FZF_BACK_LABEL}: previous" "sh -c '$pv' _ {2}" false
}

# @internal
# @description Picks the target strategy of a session.
# @stdout `current` (isolated copy of the current branch) or `parent` (new branch from a parent branch).
# @exitcode 0 Chosen.
# @exitcode 9 Cancelled.
# @exitcode 11 Back.
# @example
#   strategy="$(_shell::git::isolate::fzf::strategy)"
#
_shell::git::isolate::fzf::strategy() {
	printf '%s\t%s\n' \
		"Apply to current branch (isolated copy)" current \
		"Create new branch from a parent branch" parent |
		_shell::git::isolate::fzf::rows "Target: " "Chosen once: one isolated branch + worktree for the whole session" \
			'case "$1" in current) echo "A new branch at the current HEAD, in a separate worktree. The current branch is never modified.";; parent) echo "Pick a parent branch and a name: the new branch starts at the parent, in a separate worktree. The parent is never modified.";; *) echo "Go back";; esac' false
}

# @internal
# @description The persistent action menu. Its preview shows the destination (branch, worktree, applied commits).
# @arg $1 string Optional. Action to start the cursor on.
# @stdout files | commit | lines | switch
# @exitcode 0 An action was chosen.
# @exitcode 9 The user pressed ESC.
# @exitcode 11 The user picked "← Back".
# @example
#   action="$(_shell::git::isolate::fzf::menu files)"
#
_shell::git::isolate::fzf::menu() {
	local pv
	pv='printf "Destination  %s\nWorktree     %s\nSource       %s\nApplied      %s action(s)\n\n" "$SHELL_GIT_ISOLATE_PREVIEW_BRANCH" "$SHELL_GIT_ISOLATE_PREVIEW_DIR" "$SHELL_GIT_ISOLATE_PREVIEW_SRC" "$SHELL_GIT_ISOLATE_PREVIEW_APPLIED"; git -C "$SHELL_GIT_ISOLATE_PREVIEW_DIR" log --color=always --oneline --decorate -n 15 2>/dev/null'
	export SHELL_GIT_ISOLATE_PREVIEW_BRANCH="$_SHELL_GIT_ISOLATE_S_BRANCH" SHELL_GIT_ISOLATE_PREVIEW_DIR="$_SHELL_GIT_ISOLATE_S_DIR" \
		SHELL_GIT_ISOLATE_PREVIEW_SRC="$_SHELL_GIT_ISOLATE_S_SRC" SHELL_GIT_ISOLATE_PREVIEW_APPLIED="$_SHELL_GIT_ISOLATE_S_APPLIED"
	printf '%s\t%s\n' \
		"Pick Files" files \
		"Pick Commit" commit \
		"Pick Lines" lines \
		"Switch Source Branch" switch |
		_shell::git::isolate::fzf::rows "Isolate: " "Source ${_SHELL_GIT_ISOLATE_S_SRC} → ${_SHELL_GIT_ISOLATE_S_BRANCH}   Enter: action   ESC/${SHELL_FZF_BACK_LABEL}: leave (worktree is kept)" "sh -c '$pv' _ {2}" false "${1-}"
	local rc=$?
	unset SHELL_GIT_ISOLATE_PREVIEW_BRANCH SHELL_GIT_ISOLATE_PREVIEW_DIR SHELL_GIT_ISOLATE_PREVIEW_SRC SHELL_GIT_ISOLATE_PREVIEW_APPLIED
	return "$rc"
}

# @internal
# @description Lists the commits of the source (newest 500: short hash, date, author, subject) with a
#   `git show` preview (changed files and diff) and prints the chosen full commit id.
# @arg $1 string Commit id of the source.
# @stdout The commit id.
# @exitcode 0 Chosen.
# @exitcode 9 Cancelled.
# @exitcode 11 Back.
# @example
#   c="$(_shell::git::isolate::fzf::commit "$sha")"
#
_shell::git::isolate::fzf::commit() {
	local sha="${1-}" pv
	pv='case "$1" in @back) echo "Go back without changing anything";; *) git show --color=always --stat --patch "$1" | head -n 400 ;; esac'
	git log -n 500 --date=short --format='%h  %ad  %an  %s%x09%H' "$sha" 2>/dev/null |
		_shell::git::isolate::fzf::rows "Commit: " "Enter: choose   ESC: cancel   ${SHELL_FZF_BACK_LABEL}: previous" "sh -c '$pv' _ {2}" false
}

# @internal
# @description Lists the files of the source; those that differ from the DESTINATION worktree come first
#   (`≠`), identical ones are marked `=`. The preview is the diff against the destination.
# @arg $1 string Commit id of the source.
# @arg $2 string `true` to allow several files.
# @arg $3 string Destination worktree directory (the comparison base).
# @stdout The chosen path(s), one per line.
# @exitcode 0 Chosen.
# @exitcode 9 Cancelled.
# @exitcode 11 Back.
# @example
#   files="$(_shell::git::isolate::fzf::files "$sha" true "$dir")"
#
_shell::git::isolate::fzf::files() {
	local sha="${1-}" multi="${2-false}" dir="${3-}" pv header rc
	pv='case "$1" in @back) echo "Go back without changing anything";; *) d="$(git -C "$SHELL_GIT_ISOLATE_PREVIEW_DIR" --literal-pathspecs diff --color=always HEAD "$2" -- "$1")"; if [ -n "$d" ]; then printf "%s\n" "$d"; else git show "$2:$1" | head -n 300; fi ;; esac'
	header="≠ differs from the destination, = identical   Enter: choose   ESC: cancel   ${SHELL_FZF_BACK_LABEL}: previous"
	[ "$multi" = "true" ] && header="Tab: mark   Ctrl-A: all   ${header}"
	export SHELL_GIT_ISOLATE_PREVIEW_DIR="$dir"
	{
		git -C "$dir" -c core.quotepath=off diff --name-only --no-renames --diff-filter=AM HEAD "$sha" 2>/dev/null | sed 's/^/C\t/'
		git -c core.quotepath=off ls-tree -r --name-only "$sha" 2>/dev/null | sed 's/^/A\t/'
	} | awk -F'\t' '
		$2 == "" { next }
		$1 == "C" { c[$2] = 1; printf "≠  %s\t%s\n", $2, $2; next }
		!($2 in c) { printf "=  %s\t%s\n", $2, $2 }' |
		_shell::git::isolate::fzf::rows "File: " "$header" "sh -c '$pv' _ {2} $sha" "$multi"
	rc=$?
	unset SHELL_GIT_ISOLATE_PREVIEW_DIR
	return "$rc"
}

# @internal
# @description Shows the numbered lines of a file of the source and prints the chosen line numbers as a
#   range spec (contiguous lines are merged: 3 4 5 9 -> 3-5,9-9). The preview is the diff against the destination.
# @arg $1 string Commit id of the source.
# @arg $2 string Repository-relative path.
# @arg $3 string Destination worktree directory.
# @stdout Range spec such as `3-5,9-9`.
# @exitcode 0 Chosen.
# @exitcode 9 Cancelled.
# @exitcode 11 Back.
# @example
#   spec="$(_shell::git::isolate::fzf::lines "$sha" src/a.sh "$dir")"
#
_shell::git::isolate::fzf::lines() {
	local sha="${1-}" rel="${2-}" dir="${3-}" pv picked rc
	pv='git -C "$SHELL_GIT_ISOLATE_PREVIEW_DIR" --literal-pathspecs diff --color=always -U1 HEAD "$1" -- "$SHELL_GIT_ISOLATE_PREVIEW_PATH" | head -n 300'
	export SHELL_GIT_ISOLATE_PREVIEW_PATH="$rel" SHELL_GIT_ISOLATE_PREVIEW_DIR="$dir"
	picked="$(git cat-file blob "$sha:$rel" 2>/dev/null | awk '{ printf "%5d  %s\t%d\n", NR, $0, NR }' |
		_shell::git::isolate::fzf::rows "Lines: " "Tab: mark a line   Shift-Tab: unmark   Ctrl-A: all   Enter: choose   ESC: cancel   ${SHELL_FZF_BACK_LABEL}: previous (preview = changes vs destination)" "sh -c '$pv' _ $sha" true)"
	rc=$?
	unset SHELL_GIT_ISOLATE_PREVIEW_PATH SHELL_GIT_ISOLATE_PREVIEW_DIR
	if [ "$rc" -ne 0 ]; then
		return "$rc"
	fi
	printf '%s\n' "$picked" | sort -n | awk '
		NF == 0 { next }
		{
			if (n > 0 && $1 == e + 1) { e = $1 }
			else { if (n > 0) out = out (out == "" ? "" : ",") s "-" e; s = $1; e = $1; n++ }
		}
		END { if (n > 0) out = out (out == "" ? "" : ",") s "-" e; print out }'
}

# @description Alias of shell::git::isolate, kept for compatibility: the persistent interactive session.
# @option -n | --dry-run Optional. Choose source and strategy, print the worktree command, create nothing.
# @option -h | --help Show this help message.
# @exitcode 0 The session ended.
# @exitcode 1 Not a repository, or the session stopped for safety.
# @exitcode 11 The user went Back.
# @see shell::git::isolate
# @example
#   shell::git::isolate::fzf
#
shell::git::isolate::fzf() {
	shell::git::isolate "$@"
}
