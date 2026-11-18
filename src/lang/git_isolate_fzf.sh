#!/usr/bin/env bash
# @file lang/git_isolate_fzf.sh
# @brief Interactive picker for shell::git::isolate::*: source branch -> commit / files / lines -> preview -> confirm.

# @internal
# @description Runs fzf over `display<TAB>key` rows from stdin plus a "← Back" row, and prints the keys.
# @arg $1 string Prompt.
# @arg $2 string Header.
# @arg $3 string fzf preview command (`{2}` is the key).
# @arg $4 string `true` to allow several rows (Tab).
# @stdin Rows `display<TAB>key`.
# @stdout The chosen key(s), one per line.
# @exitcode 0 At least one row chosen.
# @exitcode 9 The user cancelled (ESC / Ctrl-C) or chose nothing.
# @exitcode 11 The user picked the "← Back" row.
# @example
#   printf 'a\ta\n' | _shell::git::isolate::fzf::rows "Pick: " "Enter" "echo {2}" false
#
_shell::git::isolate::fzf::rows() {
	local prompt="${1-}" header="${2-}" preview="${3-}" multi="${4-false}"
	local back="$SHELL_FZF_BACK_LABEL" tab=$'\t' picked rc keys
	local -a extra=()
	[ "$multi" = "true" ] && extra=(--multi --bind "ctrl-a:select-all")

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
# @description Lists local and remote branches (newest first) and prints the chosen one.
# @stdout The branch name.
# @exitcode 0 Chosen.
# @exitcode 9 Cancelled.
# @exitcode 11 Back.
# @example
#   src="$(_shell::git::isolate::fzf::branch)"
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
		_shell::git::isolate::fzf::rows "Source branch: " "Enter: choose   ESC: leave   ${SHELL_FZF_BACK_LABEL}: previous" "sh -c '$pv' _ {2}" false
}

# @internal
# @description Lists the commits of a ref (newest 500) and prints the chosen full commit id.
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
		_shell::git::isolate::fzf::rows "Commit: " "Enter: choose   ESC: leave   ${SHELL_FZF_BACK_LABEL}: previous" "sh -c '$pv' _ {2}" false
}

# @internal
# @description Lists the files of the source (those that differ from HEAD first, marked `≠`) and prints the chosen paths.
# @arg $1 string Commit id of the source.
# @arg $2 string `true` to allow several files.
# @stdout The chosen path(s), one per line.
# @exitcode 0 Chosen.
# @exitcode 9 Cancelled.
# @exitcode 11 Back.
# @example
#   files="$(_shell::git::isolate::fzf::files "$sha" true)"
#
_shell::git::isolate::fzf::files() {
	local sha="${1-}" multi="${2-false}" pv header
	pv='case "$1" in @back) echo "Go back without changing anything";; *) d="$(git --literal-pathspecs diff --color=always HEAD "$2" -- "$1")"; if [ -n "$d" ]; then printf "%s\n" "$d"; else git show "$2:$1" | head -n 300; fi ;; esac'
	header="≠ differs from HEAD, = identical   Enter: choose   ESC: leave   ${SHELL_FZF_BACK_LABEL}: previous"
	[ "$multi" = "true" ] && header="Tab: mark   Ctrl-A: all   ${header}"
	{
		git -c core.quotepath=off diff --name-only --no-renames --diff-filter=AM HEAD "$sha" 2>/dev/null | sed 's/^/C\t/'
		git -c core.quotepath=off ls-tree -r --name-only "$sha" 2>/dev/null | sed 's/^/A\t/'
	} | awk -F'\t' '
		$2 == "" { next }
		$1 == "C" { c[$2] = 1; printf "≠  %s\t%s\n", $2, $2; next }
		!($2 in c) { printf "=  %s\t%s\n", $2, $2 }' |
		_shell::git::isolate::fzf::rows "File: " "$header" "sh -c '$pv' _ {2} $sha" "$multi"
}

# @internal
# @description Shows the numbered lines of a file of the source and prints the chosen line numbers as a range spec.
# @arg $1 string Commit id of the source.
# @arg $2 string Repository-relative path.
# @stdout Range spec such as `3-5,9-9`.
# @exitcode 0 Chosen.
# @exitcode 9 Cancelled.
# @exitcode 11 Back.
# @example
#   spec="$(_shell::git::isolate::fzf::lines "$sha" src/a.sh)"
#
_shell::git::isolate::fzf::lines() {
	local sha="${1-}" rel="${2-}" pv picked rc
	pv='git --literal-pathspecs diff --color=always -U1 HEAD "$1" -- "$SHELL_GIT_ISOLATE_PREVIEW_PATH" | head -n 300'
	export SHELL_GIT_ISOLATE_PREVIEW_PATH="$rel"
	picked="$(git cat-file blob "$sha:$rel" 2>/dev/null | awk '{ printf "%5d  %s\t%d\n", NR, $0, NR }' |
		_shell::git::isolate::fzf::rows "Lines: " "Tab: mark a line   Shift-Tab: unmark   Ctrl-A: all   Enter: choose   ${SHELL_FZF_BACK_LABEL}: previous (preview = changes vs HEAD)" "sh -c '$pv' _ $sha" true)"
	rc=$?
	unset SHELL_GIT_ISOLATE_PREVIEW_PATH
	if [ "$rc" -ne 0 ]; then
		return "$rc"
	fi
	# Contiguous line numbers become ranges: 3 4 5 9 -> 3-5,9-9.
	printf '%s\n' "$picked" | sort -n | awk '
		NF == 0 { next }
		{
			if (n > 0 && $1 == e + 1) { e = $1 }
			else { if (n > 0) out = out (out == "" ? "" : ",") s "-" e; s = $1; e = $1; n++ }
		}
		END { if (n > 0) out = out (out == "" ? "" : ",") s "-" e; print out }'
}

# @description Interactive hub: pick another branch, then a commit, files or lines, preview, confirm, and
#   retrieve them into a NEW branch in an isolated worktree (your checkout is never touched).
#
#   1. Mode: commit, file(s) or line(s).
#   2. Source branch: local and remote branches, newest first, with a live log preview.
#   3. Commit: the commits of that branch with `git show` preview.
#      File: the files of that branch, the ones that differ from HEAD first, with a diff preview.
#      Lines: pick one file, then mark the lines (Tab) — they become ranges; the preview shows what
#      differs from HEAD.
#   4. The resulting diff is printed (shell::git::isolate::* --preview, nothing is created), and you
#      confirm or cancel. Only then the branch and worktree are created.
#   "← Back" (SHELL_FZF_BACK_LABEL) returns to the previous step; ESC leaves. See
#   shell::git::isolate::commit, ::file and ::lines for what each mode does and guarantees.
# @option -n | --dry-run Optional. Confirmed operations print their git commands instead of running them.
# @option -h | --help Show this help message.
# @exitcode 0 Success, cancelled, or closed with ESC.
# @exitcode 1 Not inside a repository, or the operation failed.
# @exitcode 2 Unknown option.
# @exitcode 11 The user picked "← Back" at the mode list.
# @see shell::git::isolate::commit
# @see shell::git::isolate::file
# @see shell::git::isolate::lines
# @example
#   shell::git::isolate::fzf
#   shell::git::isolate::fzf -n
#
shell::git::isolate::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick a commit, files or lines of another branch and retrieve them into a new branch in an isolated worktree"
		shell::logger::usage "shell::git::isolate::fzf [-n] [-h]"
		shell::logger::option "-n, --dry-run" "Print the git commands instead of running them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "Your current branch, staged, unstaged and untracked changes are never touched. Pick '$SHELL_FZF_BACK_LABEL' to step back (returns ${RETURN_BACK} at the mode list)."
		shell::logger::example "shell::git::isolate::fzf"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	local -a flag=()
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		flag=(-n)
		shift
	fi
	if [ "$#" -gt 0 ]; then
		shell::logger::error "Unknown argument: $1"
		return "$RETURN_INVALID"
	fi

	_shell::git::isolate::guard || return $?
	shell::dependency::fzf::ensure

	local mode rc src sha target spec
	local -a targets=()
	while true; do
		mode="$(printf '%s\t%s\n' \
			"commit   new branch at a commit of another branch" commit \
			"file     files of another branch, into a new branch" file \
			"lines    only chosen lines of a file, as a patch" lines |
			_shell::git::isolate::fzf::rows "Retrieve: " "Isolated: a new branch in a new worktree; your checkout is never touched" "echo {2}" false)"
		rc=$?
		case "$rc" in
		"$RETURN_BACK")
			shell::logger::info "Back — nothing was changed"
			return "$RETURN_BACK"
			;;
		0) ;;
		*)
			shell::logger::info "Closed"
			return "$RETURN_SUCCESS"
			;;
		esac

		src="$(_shell::git::isolate::fzf::branch)"
		rc=$?
		[ "$rc" -eq "$RETURN_CANCELLED" ] && {
			shell::logger::info "Closed"
			return "$RETURN_SUCCESS"
		}
		[ "$rc" -ne 0 ] && continue
		if ! sha="$(_shell::git::isolate::resolve "$src")"; then
			shell::logger::error "Source '$src' could not be resolved"
			continue
		fi

		case "$mode" in
		commit)
			target="$(_shell::git::isolate::fzf::commit "$sha")"
			rc=$?
			[ "$rc" -eq "$RETURN_CANCELLED" ] && {
				shell::logger::info "Closed"
				return "$RETURN_SUCCESS"
			}
			[ "$rc" -ne 0 ] && continue
			shell::git::isolate::commit --preview "$target" || continue
			shell::ask::accept "Create a new branch at this commit in an isolated worktree?" || {
				shell::logger::info "Cancelled — nothing was changed"
				continue
			}
			shell::git::isolate::commit ${flag[@]+"${flag[@]}"} "$target"
			return $?
			;;
		file)
			target="$(_shell::git::isolate::fzf::files "$sha" true)"
			rc=$?
			[ "$rc" -eq "$RETURN_CANCELLED" ] && {
				shell::logger::info "Closed"
				return "$RETURN_SUCCESS"
			}
			[ "$rc" -ne 0 ] && continue
			targets=()
			while IFS= read -r spec; do
				[ -n "$spec" ] && targets+=("$spec")
			done <<<"$target"
			shell::git::isolate::file --preview "$sha" "${targets[@]}" || continue
			shell::ask::accept "Create a new branch and retrieve these files (replacing differing ones in the new branch only)?" || {
				shell::logger::info "Cancelled — nothing was changed"
				continue
			}
			shell::git::isolate::file --overwrite ${flag[@]+"${flag[@]}"} "$sha" "${targets[@]}"
			return $?
			;;
		lines)
			target="$(_shell::git::isolate::fzf::files "$sha" false)"
			rc=$?
			[ "$rc" -eq "$RETURN_CANCELLED" ] && {
				shell::logger::info "Closed"
				return "$RETURN_SUCCESS"
			}
			[ "$rc" -ne 0 ] && continue
			spec="$(_shell::git::isolate::fzf::lines "$sha" "$target")"
			rc=$?
			[ "$rc" -eq "$RETURN_CANCELLED" ] && {
				shell::logger::info "Closed"
				return "$RETURN_SUCCESS"
			}
			[ "$rc" -ne 0 ] && continue
			shell::git::isolate::lines --preview "$sha" "$target" "$spec" || continue
			shell::ask::accept "Create a new branch and apply only these lines as a patch?" || {
				shell::logger::info "Cancelled — nothing was changed"
				continue
			}
			shell::git::isolate::lines ${flag[@]+"${flag[@]}"} "$sha" "$target" "$spec"
			return $?
			;;
		esac
	done
}
