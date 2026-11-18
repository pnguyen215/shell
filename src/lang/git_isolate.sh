#!/usr/bin/env bash
# @file lang/git_isolate.sh
# @brief Retrieve a commit, files or lines of another branch in an isolated worktree, never touching the current checkout.
# @description
#   Every operation creates a NEW branch in a NEW linked worktree (`git worktree add -b`), outside
#   the repository's working tree (under SHELL_GIT_ISOLATE_DIR). The user's checkout is never
#   switched, reset, cleaned, merged, rebased or stashed:
#
#     commit  the new branch starts at the chosen commit.
#     file    the new branch starts at the current HEAD; the chosen files are copied from the source
#             branch (staged in the worktree, nothing committed).
#     lines   the new branch starts at the current HEAD; only the chosen source lines are applied, as a
#             patch (`git apply --unidiff-zero --index`), never by replacing the file.
#
#   Safety rules shared by the three functions:
#   - A name that already exists (branch or directory) is never reused or overwritten: generated
#     names get a numeric suffix; an explicit `--branch` / `--dir` that exists is an error.
#   - The repository state (HEAD, branch, staged, unstaged and untracked files) is fingerprinted
#     before and after; a difference is reported as an error.
#   - A failure rolls back only what this call created (its branch and its worktree).
#   - Refs are resolved to full commit ids first, and paths are passed to git after `--` with
#     literal pathspecs; nothing goes through `eval`.
#   - Commits, files and lines are committed to nothing: you review, commit and push inside the
#     worktree, then remove it with `git worktree remove <dir>`.

# @internal
# @description Succeeds when a repository path is safe to pass to git: relative, no `..`, no leading
#   dash, no control characters.
# @arg $1 string Path (relative to the repository root).
# @exitcode 0 The path is acceptable.
# @exitcode 1 The path is empty, absolute, escapes the repository, starts with `-`, or has a control character.
# @example
#   _shell::git::isolate::valid_path "src/lib/a.sh"
#
_shell::git::isolate::valid_path() {
	case "${1-}" in
	'' | /* | -* | .. | ../* | */.. | */../*) return "$RETURN_FAILURE" ;;
	esac
	case "$1" in
	*$'\n'* | *$'\t'* | *$'\r'*) return "$RETURN_FAILURE" ;;
	esac
	return "$RETURN_SUCCESS"
}

# @internal
# @description Resolves a ref or commit-ish to a full commit id.
# @arg $1 string Ref, branch, tag or commit-ish.
# @stdout The 40 (or 64) hex commit id.
# @exitcode 0 Resolved.
# @exitcode 1 Empty, option-like or unknown.
# @example
#   sha="$(_shell::git::isolate::resolve origin/main)"
#
_shell::git::isolate::resolve() {
	case "${1-}" in
	'' | -*) return "$RETURN_FAILURE" ;;
	esac
	git rev-parse --verify --quiet "${1}^{commit}" 2>/dev/null
}

# @internal
# @description Turns free text into a branch/directory-safe slug (lowercase, `[a-z0-9._-]`, at most 32 characters).
# @arg $1 string Text.
# @stdout The slug (`x` when nothing is left).
# @exitcode 0 Always.
# @example
#   _shell::git::isolate::slug "Fix: the Login bug!"   # fix-the-login-bug
#
_shell::git::isolate::slug() {
	local out
	out="$(printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9._-]/-/g' -e 's/--*/-/g' -e 's/^[-.]*//' -e 's/[-.]*$//' | cut -c1-32 | sed -e 's/[-.]*$//')"
	printf '%s\n' "${out:-x}"
}

# @internal
# @description Prints a local branch name that does not exist yet (`name`, `name-2`, `name-3`, ...).
# @arg $1 string Wanted branch name.
# @stdout The free branch name.
# @exitcode 0 Found.
# @exitcode 1 No valid free name within 99 attempts.
# @example
#   _shell::git::isolate::unique_branch "isolate/file/main-readme"
#
_shell::git::isolate::unique_branch() {
	local base="${1-}" candidate n=1
	candidate="$base"
	while [ "$n" -le 99 ]; do
		if git check-ref-format --branch "$candidate" >/dev/null 2>&1 &&
			! git show-ref --verify --quiet "refs/heads/$candidate"; then
			printf '%s\n' "$candidate"
			return "$RETURN_SUCCESS"
		fi
		n=$((n + 1))
		candidate="${base}-${n}"
	done
	return "$RETURN_FAILURE"
}

# @internal
# @description Prints a snapshot hash of the state the user cares about, read-only (optional locks off):
#   HEAD, the checked-out branch, every ref, the index (`ls-files -s`), the status, the CONTENT hash of
#   every modified and untracked file, both diffs, the stash list and the linked worktrees.
#   The branch and worktree a session creates are excluded, so only what must NOT change is compared.
# @arg $1 string Optional. Repository root (default: the current one).
# @arg $2 string Optional. Branch to leave out (the session's own).
# @arg $3 string Optional. Worktree directory to leave out (the session's own).
# @stdout A checksum line.
# @exitcode 0 Always.
# @example
#   before="$(_shell::git::isolate::fingerprint "$top" "$branch" "$dir")"
#
_shell::git::isolate::fingerprint() {
	local top="${1-}" skip_branch="${2-}" skip_dir="${3-}"
	[ -n "$top" ] || top="$(git rev-parse --show-toplevel 2>/dev/null)"
	{
		git -C "$top" rev-parse HEAD 2>&1
		git -C "$top" symbolic-ref -q HEAD 2>&1
		git -C "$top" for-each-ref --format='%(refname) %(objectname)' 2>&1 | grep -v -x -F "refs/heads/${skip_branch:-@none@} $(git -C "$top" rev-parse --verify --quiet "refs/heads/${skip_branch:-@none@}" 2>/dev/null)"
		git -C "$top" ls-files -s 2>&1
		GIT_OPTIONAL_LOCKS=0 git -C "$top" status --porcelain=v1 --untracked-files=all 2>&1
		git -C "$top" -c core.quotepath=off ls-files -m -o --exclude-standard 2>/dev/null | git -C "$top" hash-object --stdin-paths 2>&1
		git -C "$top" diff --cached --raw --no-abbrev 2>&1
		git -C "$top" diff --raw --no-abbrev 2>&1
		git -C "$top" stash list 2>&1
		git -C "$top" worktree list --porcelain 2>&1 | awk -v RS= -v ORS="\n\n" -v skip="${skip_dir:-@none@}" 'index($0, "worktree " skip "\n") != 1 && $0 != "worktree " skip'
	} | cksum
}

# @internal
# @description Common pre-flight: inside a non-bare repository that has a commit and supports worktrees.
# @exitcode 0 Ready.
# @exitcode 1 Not a repository, bare, or no commit.
# @exitcode 4 `git worktree` is not available.
# @example
#   _shell::git::isolate::guard || return $?
#
_shell::git::isolate::guard() {
	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		shell::logger::error "Not inside a Git repository"
		return "$RETURN_FAILURE"
	fi
	if [ "$(git rev-parse --is-bare-repository 2>/dev/null)" = "true" ]; then
		shell::logger::error "A bare repository has no working tree to isolate from"
		return "$RETURN_FAILURE"
	fi
	if ! git worktree list >/dev/null 2>&1; then
		shell::logger::error "This Git has no 'git worktree' (Git 2.5 or newer is required)"
		return "$RETURN_NOT_SUPPORTED"
	fi
	if ! git rev-parse --verify --quiet 'HEAD^{commit}' >/dev/null 2>&1; then
		shell::logger::error "The repository has no commit yet"
		return "$RETURN_FAILURE"
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Prints a command via shell::logger::command_clip with every word shell-quoted (dry-run helper).
# @arg $@ string The command words.
# @exitcode 0 Always.
# @example
#   _shell::git::isolate::show git worktree add -b b /tmp/d HEAD
#
_shell::git::isolate::show() {
	shell::logger::command_clip "$(printf '%q ' "$@")"
}

# @internal
# @description Removes what a failed call created: its worktree and its branch. Both names were
#   verified free before the call, so nothing pre-existing is ever touched.
# @arg $1 string Branch created by the call.
# @arg $2 string Worktree directory created by the call.
# @exitcode 0 Always.
# @example
#   _shell::git::isolate::rollback "$branch" "$dir"
#
_shell::git::isolate::rollback() {
	local branch="${1-}" dir="${2-}"
	if [ -n "$dir" ] && { [ -e "$dir" ] || [ -L "$dir" ]; }; then
		git worktree remove --force "$dir" >/dev/null 2>&1 || rm -rf -- "$dir"
	fi
	git worktree prune >/dev/null 2>&1
	if [ -n "$branch" ] && git show-ref --verify --quiet "refs/heads/$branch"; then
		git branch -D "$branch" >/dev/null 2>&1
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Chooses the new branch and worktree directory, then creates them (or prints the
#   command in dry-run). On success sets `_SHELL_GIT_ISOLATE_WT_BRANCH` and `_SHELL_GIT_ISOLATE_WT_DIR`.
#   On failure it rolls back what it created.
# @arg $1 string Kind: commit | file | lines.
# @arg $2 string Label used in the generated branch name.
# @arg $3 string Explicit branch name (may be empty).
# @arg $4 string Explicit directory (may be empty).
# @arg $5 string `true` for dry-run.
# @arg $6 string Start point (commit id).
# @exitcode 0 Created (or planned).
# @exitcode 1 The worktree could not be created.
# @exitcode 2 Invalid branch name or directory.
# @exitcode 7 The branch or directory already exists.
# @example
#   _shell::git::isolate::open file main-readme "" "" false "$base"
#
_shell::git::isolate::open() {
	local kind="${1-}" label="${2-}" branch_opt="${3-}" dir_opt="${4-}" dry_run="${5-false}" start="${6-}"
	local branch dir top out
	_SHELL_GIT_ISOLATE_WT_BRANCH=""
	_SHELL_GIT_ISOLATE_WT_DIR=""

	if [ -n "$branch_opt" ]; then
		if ! git check-ref-format --branch "$branch_opt" >/dev/null 2>&1; then
			shell::logger::error "'$branch_opt' is not a valid branch name"
			return "$RETURN_INVALID"
		fi
		if git show-ref --verify --quiet "refs/heads/$branch_opt"; then
			shell::logger::error "Branch '$branch_opt' already exists; it was left untouched. Choose another name or omit --branch."
			return "$RETURN_EXISTS"
		fi
		branch="$branch_opt"
	else
		branch="$(_shell::git::isolate::unique_branch "isolate/$kind/$label")" || {
			shell::logger::error "Could not find a free branch name for 'isolate/$kind/$label'"
			return "$RETURN_FAILURE"
		}
	fi

	top="$(git rev-parse --show-toplevel 2>/dev/null)"
	if [ -n "$dir_opt" ]; then
		case "$dir_opt" in
		/*) dir="$dir_opt" ;;
		*) dir="$PWD/$dir_opt" ;;
		esac
	else
		dir="$SHELL_GIT_ISOLATE_DIR/$(_shell::git::isolate::slug "$(basename "$top")")-$(printf '%s' "$top" | cksum | cut -d' ' -f1)/$(printf '%s' "$branch" | tr '/' '-')"
	fi
	if [ -e "$dir" ] || [ -L "$dir" ]; then
		shell::logger::error "Directory '$dir' already exists; it was left untouched."
		return "$RETURN_EXISTS"
	fi
	case "$dir/" in
	"$top"/*)
		shell::logger::error "The worktree must live outside the working tree ('$top'); use another --dir."
		return "$RETURN_INVALID"
		;;
	esac

	if [ "$dry_run" = "true" ]; then
		_shell::git::isolate::show git worktree add -b "$branch" "$dir" "$start"
		_SHELL_GIT_ISOLATE_WT_BRANCH="$branch"
		_SHELL_GIT_ISOLATE_WT_DIR="$dir"
		return "$RETURN_SUCCESS"
	fi

	mkdir -p "$(dirname "$dir")" || {
		shell::logger::error "Could not create '$(dirname "$dir")'"
		return "$RETURN_FAILURE"
	}
	if ! out="$(git -c core.hooksPath=/dev/null worktree add -q -b "$branch" "$dir" "$start" 2>&1)"; then
		shell::logger::error "Could not create the worktree: $out"
		_shell::git::isolate::rollback "$branch" "$dir"
		return "$RETURN_FAILURE"
	fi
	_SHELL_GIT_ISOLATE_WT_BRANCH="$branch"
	_SHELL_GIT_ISOLATE_WT_DIR="$dir"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Compares the repository fingerprint with the one taken before and reports the result.
# @arg $1 string Fingerprint taken before the operation.
# @exitcode 0 Unchanged; the success summary was printed.
# @exitcode 1 The repository state changed unexpectedly.
# @example
#   _shell::git::isolate::finish "$before"
#
_shell::git::isolate::finish() {
	local before="${1-}" after
	after="$(_shell::git::isolate::fingerprint "" "$_SHELL_GIT_ISOLATE_WT_BRANCH" "$_SHELL_GIT_ISOLATE_WT_DIR")"
	if [ "$before" != "$after" ]; then
		shell::logger::error "The current repository state changed unexpectedly during the operation; inspect it with 'git status'."
		return "$RETURN_FAILURE"
	fi
	shell::logger::success "Created branch '$_SHELL_GIT_ISOLATE_WT_BRANCH' in an isolated worktree"
	shell::logger::info "Worktree: $_SHELL_GIT_ISOLATE_WT_DIR"
	shell::logger::info "Your current branch, staged, unstaged and untracked changes were left untouched"
	shell::logger::command "cd $(printf '%q' "$_SHELL_GIT_ISOLATE_WT_DIR")"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Validates a line-range spec against the number of lines of the file and normalises it.
#   Accepts `N` and `A-B` items separated by commas or spaces. Rejects invalid items, ranges outside
#   `1..total`, and overlapping or duplicated ranges.
# @arg $1 string Spec, e.g. "3,10-20 25".
# @arg $2 string Number of lines in the file.
# @stdout Normalised, sorted spec (`3-3,10-20,25-25`) on success; a one-line reason on failure.
# @exitcode 0 Valid.
# @exitcode 2 Invalid, out of range, empty or overlapping.
# @example
#   _shell::git::isolate::ranges "3,10-20" 120
#
_shell::git::isolate::ranges() {
	printf '%s' "${1-}" | tr ', ' '\n\n' | awk -v total="${2-0}" '
		NF == 0 { next }
		{
			if ($0 ~ /^[0-9]+$/) { s = $0 + 0; e = s }
			else if ($0 ~ /^[0-9]+-[0-9]+$/) { split($0, p, "-"); s = p[1] + 0; e = p[2] + 0 }
			else { print "invalid line selection \"" $0 "\""; bad = 1; exit }
			if (s < 1 || e < s || e > total) { print "line range \"" $0 "\" is outside 1-" total; bad = 1; exit }
			S[++n] = s; E[n] = e
		}
		END {
			if (bad) exit 2
			if (n == 0) { print "no line selected"; exit 2 }
			for (i = 2; i <= n; i++) {
				ks = S[i]; ke = E[i]; j = i - 1
				while (j >= 1 && S[j] > ks) { S[j + 1] = S[j]; E[j + 1] = E[j]; j-- }
				S[j + 1] = ks; E[j + 1] = ke
			}
			for (i = 2; i <= n; i++)
				if (S[i] <= E[i - 1]) { print "overlapping line ranges " S[i - 1] "-" E[i - 1] " and " S[i] "-" E[i]; exit 2 }
			out = ""
			for (i = 1; i <= n; i++) out = out (i > 1 ? "," : "") S[i] "-" E[i]
			print out
		}
	'
}

# @internal
# @description Builds a zero-context patch (HEAD -> source) containing only the selected source lines.
#   A hunk whose added lines are all selected is applied whole (including the lines it replaces);
#   a partly selected hunk applies only the selected added lines and keeps the old lines; a hunk with
#   no selected line, and pure deletions, are skipped.
# @arg $1 string Base commit id (the new branch start).
# @arg $2 string Source commit id.
# @arg $3 string Path.
# @arg $4 string Normalised ranges (see _shell::git::isolate::ranges).
# @arg $5 string File that receives `full partial skipped` counters.
# @stdout The patch (empty when no selected line differs from the base).
# @exitcode 0 Always (an empty patch means nothing to apply).
# @example
#   _shell::git::isolate::patch "$base" "$sha" src/a.sh "3-5,9-9" "$stats" >"$patch"
#
_shell::git::isolate::patch() {
	git --literal-pathspecs -c core.quotepath=off diff --no-color --no-ext-diff --no-renames --ignore-submodules -U0 "$1" "$2" -- "$3" |
		awk -v ranges="$4" -v path="$3" -v stats="$5" '
			BEGIN {
				n = split(ranges, rr, ",")
				for (i = 1; i <= n; i++) {
					split(rr[i], p, "-")
					if (p[2] == "") p[2] = p[1]
					for (l = p[1] + 0; l <= p[2] + 0; l++) sel[l] = 1
				}
				delta = 0; full = 0; partial = 0; skipped = 0; out = ""; inh = 0
			}
			function flush(   k, cnt, start, body, P) {
				if (!inh) return
				inh = 0
				cnt = 0
				for (k = 1; k <= nad; k++) if ((ns + k - 1) in sel) cnt++
				if (nad > 0 && cnt == nad) {
					start = (ob > 0) ? oa : oa + 1
					body = "@@ -" oa "," ob " +" (start + delta) "," nad " @@\n"
					for (k = 1; k <= ndl; k++) body = body "-" dels[k] "\n"
					for (k = 1; k <= nad; k++) body = body "+" adds[k] "\n"
					out = out body; delta += nad - ndl; full++
				} else if (cnt > 0) {
					P = (ob > 0) ? oa + ob - 1 : oa
					body = "@@ -" P ",0 +" (P + 1 + delta) "," cnt " @@\n"
					for (k = 1; k <= nad; k++) if ((ns + k - 1) in sel) body = body "+" adds[k] "\n"
					out = out body; delta += cnt; partial++
				} else skipped++
			}
			/^@@ / {
				flush(); inh = 1; ndl = 0; nad = 0
				h = $2; sub(/^-/, "", h); split(h, x, ","); oa = x[1] + 0; ob = (x[2] == "") ? 1 : x[2] + 0
				h = $3; sub(/^\+/, "", h); split(h, y, ","); ns = y[1] + 0
				next
			}
			inh && /^-/ { dels[++ndl] = substr($0, 2); next }
			inh && /^\+/ { adds[++nad] = substr($0, 2); next }
			END {
				flush()
				if (out != "") printf "--- a/%s\n+++ b/%s\n%s", path, path, out
				printf "%d %d %d\n", full, partial, skipped > stats
			}
		'
}

# @description Creates a new branch at a commit of another branch, in an isolated worktree.
#
#   The current checkout is never touched. The new branch is `isolate/commit/<short-id>-<subject>`
#   (numeric suffix on collision) unless `--branch` is given; the worktree lives under
#   SHELL_GIT_ISOLATE_DIR unless `--dir` is given.
# @option -b | --branch <name> Optional. Name of the new branch (an existing name is an error).
# @option -d | --dir <path> Optional. Worktree directory (must not exist and must be outside the working tree).
# @option -p | --preview Optional. Show the commit and create nothing.
# @option -n | --dry-run Optional. Print the git command instead of running it.
# @option -h | --help Show this help message.
# @arg $1 string commit: Commit id, branch, tag or any commit-ish.
# @exitcode 0 Success (or preview / dry-run).
# @exitcode 1 Not a repository, or the worktree could not be created.
# @exitcode 2 Invalid arguments.
# @exitcode 3 The commit does not exist.
# @exitcode 7 The branch or directory already exists.
# @see shell::git::isolate::file
# @see shell::git::isolate::fzf
# @example
#   shell::git::isolate::commit a1b2c3d
#   shell::git::isolate::commit -b hotfix/from-release origin/release~2
#
shell::git::isolate::commit() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "New branch at a commit of another branch, in an isolated worktree (your checkout is never touched)"
		shell::logger::usage "shell::git::isolate::commit [-n] [-p] [-b <name>] [-d <dir>] [-h] <commit>"
		shell::logger::option "-b, --branch <name>" "Name of the new branch (default: isolate/commit/<id>-<subject>)"
		shell::logger::option "-d, --dir <path>" "Worktree directory (default under SHELL_GIT_ISOLATE_DIR)"
		shell::logger::option "-p, --preview" "Show the commit and create nothing"
		shell::logger::option "-n, --dry-run" "Print the git command instead of running it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::item "commit" "Commit id, branch, tag or any commit-ish"
		shell::logger::example "shell::git::isolate::commit a1b2c3d"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" preview="false" branch_opt="" dir_opt="" target=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-p | --preview) preview="true" ;;
		-b | --branch | -d | --dir)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			case "$1" in -b | --branch) branch_opt="$2" ;; *) dir_opt="$2" ;; esac
			shift
			;;
		-*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*)
			if [ -n "$target" ]; then
				shell::logger::error "Only one commit can be given"
				return "$RETURN_INVALID"
			fi
			target="$1"
			;;
		esac
		shift
	done
	if [ -z "$target" ]; then
		shell::logger::error "A commit is required"
		return "$RETURN_INVALID"
	fi

	_shell::git::isolate::guard || return $?
	local sha short subject before rc
	if ! sha="$(_shell::git::isolate::resolve "$target")"; then
		shell::logger::error "Commit '$target' does not exist (or was removed from this repository)"
		return "$RETURN_NOT_FOUND"
	fi
	short="$(git rev-parse --short=7 "$sha")"
	subject="$(git log -1 --format=%s "$sha")"

	if [ "$preview" = "true" ]; then
		git --no-pager show --stat --pretty=format:'commit %H%nAuthor: %an%nDate:   %ad%n%n    %s%n' "$sha"
		return "$RETURN_SUCCESS"
	fi

	before="$(_shell::git::isolate::fingerprint)"
	_shell::git::isolate::open commit "${short}-$(_shell::git::isolate::slug "$subject")" "$branch_opt" "$dir_opt" "$dry_run" "$sha" || return $?
	if [ "$dry_run" = "true" ]; then
		return "$RETURN_SUCCESS"
	fi
	shell::logger::info "Commit ${short}  ${subject}"
	_shell::git::isolate::finish "$before"
	rc=$?
	return "$rc"
}

# @description Retrieves whole files from another branch into a new branch, in an isolated worktree.
#
#   The new branch starts at the current HEAD (a detached HEAD is fine); the files are copied from
#   the source with their directory structure and staged in the worktree. Nothing else changes.
#   Before anything is created the files are checked: a file missing from the source, a path that is
#   not a regular file, and a file that already exists with different content at HEAD (it would be
#   overwritten in the new branch; allowed only with `--overwrite`). Uncommitted changes to the same
#   paths in your checkout stay where they are and are reported, because the new branch starts at
#   the committed HEAD.
# @option -o | --overwrite Optional. Replace files that exist at HEAD with different content (in the new branch only).
# @option -b | --branch <name> Optional. Name of the new branch (an existing name is an error).
# @option -d | --dir <path> Optional. Worktree directory (must not exist and must be outside the working tree).
# @option -p | --preview Optional. Show the diff that would be retrieved and create nothing.
# @option -n | --dry-run Optional. Print the git commands instead of running them.
# @option -h | --help Show this help message.
# @arg $1 string source: Branch, tag or commit to read the files from.
# @arg $@ string path: One or more repository-relative file paths.
# @exitcode 0 Success (or preview / dry-run).
# @exitcode 1 Not a repository, or the retrieval failed (everything created was rolled back).
# @exitcode 2 Invalid arguments or paths.
# @exitcode 3 The source or a file does not exist in the source.
# @exitcode 7 Overwrite needed but not allowed, or the branch / directory exists.
# @exitcode 8 Every file is already identical at HEAD; nothing was created.
# @see shell::git::isolate::lines
# @see shell::git::isolate::fzf
# @example
#   shell::git::isolate::file origin/feature src/lib/a.sh docs/a.md
#   shell::git::isolate::file -p release src/a.sh
#
shell::git::isolate::file() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Retrieve files of another branch into a new branch, in an isolated worktree"
		shell::logger::usage "shell::git::isolate::file [-n] [-p] [-o] [-b <name>] [-d <dir>] [-h] <source> <path>..."
		shell::logger::option "-o, --overwrite" "Replace files that exist at HEAD with different content (new branch only)"
		shell::logger::option "-b, --branch <name>" "Name of the new branch (default: isolate/file/<source>-<id>-<file>)"
		shell::logger::option "-d, --dir <path>" "Worktree directory (default under SHELL_GIT_ISOLATE_DIR)"
		shell::logger::option "-p, --preview" "Show the diff and create nothing"
		shell::logger::option "-n, --dry-run" "Print the git commands instead of running them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::item "source" "Branch, tag or commit to read from"
		shell::logger::item "path" "Repository-relative file path (one or more)"
		shell::logger::example "shell::git::isolate::file origin/feature src/a.sh"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" preview="false" overwrite="false" branch_opt="" dir_opt="" source_ref=""
	local -a paths=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-p | --preview) preview="true" ;;
		-o | --overwrite) overwrite="true" ;;
		-b | --branch | -d | --dir)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			case "$1" in -b | --branch) branch_opt="$2" ;; *) dir_opt="$2" ;; esac
			shift
			;;
		--)
			shift
			break
			;;
		-*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*)
			if [ -z "$source_ref" ]; then source_ref="$1"; else paths+=("$1"); fi
			;;
		esac
		shift
	done
	while [ "$#" -gt 0 ]; do
		if [ -z "$source_ref" ]; then source_ref="$1"; else paths+=("$1"); fi
		shift
	done
	if [ -z "$source_ref" ] || [ "${#paths[@]}" -eq 0 ]; then
		shell::logger::error "A source and at least one file path are required"
		return "$RETURN_INVALID"
	fi

	_shell::git::isolate::guard || return $?
	local sha base short p kind_of src_id base_id before rc label first
	local -a todo=() overwrites=() dirty=()
	if ! sha="$(_shell::git::isolate::resolve "$source_ref")"; then
		shell::logger::error "Source '$source_ref' does not exist"
		return "$RETURN_NOT_FOUND"
	fi
	base="$(git rev-parse HEAD)"
	short="$(git rev-parse --short=7 "$sha")"

	local identical=0
	for p in ${paths[@]+"${paths[@]}"}; do
		if ! _shell::git::isolate::valid_path "$p"; then
			shell::logger::error "Invalid path '$p' (use a repository-relative path without '..')"
			return "$RETURN_INVALID"
		fi
		kind_of="$(git cat-file -t "$sha:$p" 2>/dev/null)"
		if [ -z "$kind_of" ]; then
			shell::logger::error "'$p' does not exist in '$source_ref'"
			return "$RETURN_NOT_FOUND"
		fi
		if [ "$kind_of" != "blob" ]; then
			shell::logger::error "'$p' is a $kind_of in '$source_ref', not a file; list its files instead"
			return "$RETURN_INVALID"
		fi
		src_id="$(git rev-parse "$sha:$p")"
		base_id="$(git rev-parse --verify --quiet "$base:$p" 2>/dev/null)"
		if [ -n "$base_id" ] && [ "$base_id" = "$src_id" ]; then
			identical=$((identical + 1))
			shell::logger::info "$p is already identical at HEAD — skipped"
			continue
		fi
		[ -n "$base_id" ] && overwrites+=("$p")
		todo+=("$p")
		if [ -n "$(GIT_OPTIONAL_LOCKS=0 git --literal-pathspecs status --porcelain -- "$p" 2>/dev/null)" ]; then
			dirty+=("$p")
		fi
	done
	if [ "${#todo[@]}" -eq 0 ]; then
		shell::logger::warn "Nothing to retrieve: every file is already identical at HEAD"
		return "$RETURN_EMPTY"
	fi
	for p in ${dirty[@]+"${dirty[@]}"}; do
		shell::logger::warn "$p has uncommitted changes in your checkout; they stay there and are NOT part of the new branch"
	done
	if ! git symbolic-ref -q HEAD >/dev/null 2>&1; then
		shell::logger::warn "HEAD is detached; the new branch starts at ${base:0:7}"
	fi

	shell::logger::info "From '$source_ref' (${short}) into a new branch based on HEAD:"
	git --literal-pathspecs --no-pager diff --stat --no-color "$base" "$sha" -- "${todo[@]}"
	if [ "${#overwrites[@]}" -gt 0 ]; then
		for p in "${overwrites[@]}"; do
			shell::logger::warn "Conflict: $p exists at HEAD with different content; the new branch would get the version from '$source_ref'"
		done
		if [ "$overwrite" != "true" ] && [ "$preview" != "true" ]; then
			shell::logger::error "Nothing was created. Re-run with --overwrite to replace them in the new branch."
			return "$RETURN_EXISTS"
		fi
	fi
	if [ "$preview" = "true" ]; then
		git --literal-pathspecs --no-pager diff --no-color "$base" "$sha" -- "${todo[@]}"
		return "$RETURN_SUCCESS"
	fi

	first="$(printf '%s\n' "${todo[@]}" | head -n 1)"
	label="${short}-$(_shell::git::isolate::slug "$(basename "$first")")"
	before="$(_shell::git::isolate::fingerprint)"
	_shell::git::isolate::open file "$label" "$branch_opt" "$dir_opt" "$dry_run" "$base" || return $?
	if [ "$dry_run" = "true" ]; then
		_shell::git::isolate::show git --literal-pathspecs -C "$_SHELL_GIT_ISOLATE_WT_DIR" checkout "$sha" -- "${todo[@]}"
		return "$RETURN_SUCCESS"
	fi

	local out
	if ! out="$(git --literal-pathspecs -C "$_SHELL_GIT_ISOLATE_WT_DIR" checkout "$sha" -- "${todo[@]}" 2>&1)"; then
		shell::logger::error "Could not retrieve the files: $out"
		_shell::git::isolate::rollback "$_SHELL_GIT_ISOLATE_WT_BRANCH" "$_SHELL_GIT_ISOLATE_WT_DIR"
		return "$RETURN_FAILURE"
	fi
	git -C "$_SHELL_GIT_ISOLATE_WT_DIR" --no-pager diff --cached --stat --no-color
	_shell::git::isolate::finish "$before"
	rc=$?
	return "$rc"
}

# @description Retrieves only chosen lines of a file of another branch into a new branch, as a patch.
#
#   The new branch starts at the current HEAD, in an isolated worktree. The lines are NUMBERED IN THE
#   SOURCE file. The tool diffs HEAD against the source, keeps only what the selected lines touch and
#   applies that as a zero-context patch (`git apply --unidiff-zero --index`), so the rest of the file
#   is never replaced:
#   - a changed block whose added lines are ALL selected is applied whole (the lines it replaces go too);
#   - a block selected only in part inserts just the selected lines and keeps the old lines (reported);
#   - a block with no selected line, and a pure deletion, are skipped.
#   Ranges that are empty, invalid, outside the file or overlapping are rejected; so is a selection
#   that changes nothing at HEAD. The patch is checked with `git apply --check` in the worktree before
#   it is applied, and the resulting diff is shown. A file that does not exist at HEAD is created
#   with the selected lines.
# @option -b | --branch <name> Optional. Name of the new branch (an existing name is an error).
# @option -d | --dir <path> Optional. Worktree directory (must not exist and must be outside the working tree).
# @option -p | --preview Optional. Show the resulting diff and create nothing.
# @option -n | --dry-run Optional. Print the git commands (and the diff) instead of running them.
# @option -h | --help Show this help message.
# @arg $1 string source: Branch, tag or commit to read from.
# @arg $2 string path: Repository-relative file path.
# @arg $3 string lines: Source line numbers, e.g. "5", "10-20", "3,10-20 40".
# @exitcode 0 Success (or preview / dry-run).
# @exitcode 1 Not a repository, or the patch did not apply (everything created was rolled back).
# @exitcode 2 Invalid arguments, path, binary file, or invalid / overlapping / out-of-range lines.
# @exitcode 3 The source or the file does not exist in the source.
# @exitcode 7 The branch or directory already exists.
# @exitcode 8 The selected lines change nothing at HEAD.
# @see shell::git::isolate::file
# @see shell::git::isolate::fzf
# @example
#   shell::git::isolate::lines origin/feature src/a.sh "10-20,42"
#   shell::git::isolate::lines -p release src/a.sh 5-9
#
shell::git::isolate::lines() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Retrieve only chosen lines of a file of another branch into a new branch, as a patch, in an isolated worktree"
		shell::logger::usage "shell::git::isolate::lines [-n] [-p] [-b <name>] [-d <dir>] [-h] <source> <path> <lines>"
		shell::logger::option "-b, --branch <name>" "Name of the new branch (default: isolate/lines/<source>-<id>-<file>)"
		shell::logger::option "-d, --dir <path>" "Worktree directory (default under SHELL_GIT_ISOLATE_DIR)"
		shell::logger::option "-p, --preview" "Show the resulting diff and create nothing"
		shell::logger::option "-n, --dry-run" "Print the git commands instead of running them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::item "source" "Branch, tag or commit to read from"
		shell::logger::item "path" "Repository-relative file path"
		shell::logger::item "lines" "Source line numbers: 5, 10-20, \"3,10-20 40\""
		shell::logger::example "shell::git::isolate::lines origin/feature src/a.sh \"10-20,42\""
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" preview="false" branch_opt="" dir_opt=""
	local -a pos=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-p | --preview) preview="true" ;;
		-b | --branch | -d | --dir)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			case "$1" in -b | --branch) branch_opt="$2" ;; *) dir_opt="$2" ;; esac
			shift
			;;
		-*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) pos+=("$1") ;;
		esac
		shift
	done
	if [ "${#pos[@]}" -ne 3 ]; then
		shell::logger::error "Exactly a source, a file path and the lines are required"
		return "$RETURN_INVALID"
	fi
	# bash arrays start at 0 and zsh arrays at 1: read the three words as positional parameters.
	set -- "${pos[@]}"
	local source_ref="$1" rel="$2" spec="$3"

	_shell::git::isolate::guard || return $?
	local sha base short kind_of total ranges base_id before rc label empty_tree
	if ! sha="$(_shell::git::isolate::resolve "$source_ref")"; then
		shell::logger::error "Source '$source_ref' does not exist"
		return "$RETURN_NOT_FOUND"
	fi
	if ! _shell::git::isolate::valid_path "$rel"; then
		shell::logger::error "Invalid path '$rel' (use a repository-relative path without '..')"
		return "$RETURN_INVALID"
	fi
	kind_of="$(git cat-file -t "$sha:$rel" 2>/dev/null)"
	if [ -z "$kind_of" ]; then
		shell::logger::error "'$rel' does not exist in '$source_ref'"
		return "$RETURN_NOT_FOUND"
	fi
	if [ "$kind_of" != "blob" ]; then
		shell::logger::error "'$rel' is a $kind_of in '$source_ref', not a file"
		return "$RETURN_INVALID"
	fi
	base="$(git rev-parse HEAD)"
	short="$(git rev-parse --short=7 "$sha")"
	empty_tree="$(git hash-object -t tree /dev/null)"
	if git --literal-pathspecs diff --numstat "$empty_tree" "$sha" -- "$rel" | grep -q "$(printf '^-\t-\t')"; then
		shell::logger::error "'$rel' is a binary file; line selection needs text"
		return "$RETURN_INVALID"
	fi

	total="$(git cat-file blob "$sha:$rel" | awk 'END { print NR }')"
	if ! ranges="$(_shell::git::isolate::ranges "$spec" "$total")"; then
		shell::logger::error "$ranges"
		return "$RETURN_INVALID"
	fi

	local stats patch content_file out
	stats="$(mktemp "${TMPDIR:-/tmp}/shell-isolate-stats.XXXXXX")" || return "$RETURN_FAILURE"
	patch="$(mktemp "${TMPDIR:-/tmp}/shell-isolate-patch.XXXXXX")" || {
		rm -f "$stats"
		return "$RETURN_FAILURE"
	}
	content_file="$(mktemp "${TMPDIR:-/tmp}/shell-isolate-lines.XXXXXX")" || {
		rm -f "$stats" "$patch"
		return "$RETURN_FAILURE"
	}

	local new_file="false" full=0 partial=0 skipped=0
	base_id="$(git rev-parse --verify --quiet "$base:$rel" 2>/dev/null)"
	if [ -z "$base_id" ]; then
		new_file="true"
		git cat-file blob "$sha:$rel" | awk -v ranges="$ranges" '
			BEGIN { n = split(ranges, rr, ","); for (i = 1; i <= n; i++) { split(rr[i], p, "-"); for (l = p[1] + 0; l <= p[2] + 0; l++) sel[l] = 1 } }
			NR in sel' >"$content_file"
	else
		_shell::git::isolate::patch "$base" "$sha" "$rel" "$ranges" "$stats" >"$patch"
		read -r full partial skipped <"$stats"
		if [ ! -s "$patch" ]; then
			rm -f "$stats" "$patch" "$content_file"
			shell::logger::warn "The selected lines (${ranges}) change nothing at HEAD; nothing was created"
			return "$RETURN_EMPTY"
		fi
		if [ "${partial:-0}" -gt 0 ]; then
			shell::logger::warn "${partial} changed block(s) are selected only in part: just the selected lines are inserted and the lines they replace are kept"
		fi
		if [ "${skipped:-0}" -gt 0 ]; then
			shell::logger::info "${skipped} changed block(s) outside the selection (or pure deletions) are skipped"
		fi
	fi
	if [ -n "$(GIT_OPTIONAL_LOCKS=0 git --literal-pathspecs status --porcelain -- "$rel" 2>/dev/null)" ]; then
		shell::logger::warn "$rel has uncommitted changes in your checkout; they stay there and are NOT part of the new branch"
	fi
	if ! git symbolic-ref -q HEAD >/dev/null 2>&1; then
		shell::logger::warn "HEAD is detached; the new branch starts at ${base:0:7}"
	fi

	shell::logger::info "Lines ${ranges} of ${rel} from '${source_ref}' (${short}), as a patch on HEAD:"
	if [ "$new_file" = "true" ]; then
		shell::logger::info "$rel does not exist at HEAD; it would be created with the selected lines"
		sed 's/^/+/' "$content_file"
	else
		cat "$patch"
	fi

	if [ "$preview" = "true" ]; then
		rm -f "$stats" "$patch" "$content_file"
		return "$RETURN_SUCCESS"
	fi

	label="${short}-$(_shell::git::isolate::slug "$(basename "$rel")")"
	before="$(_shell::git::isolate::fingerprint)"
	_shell::git::isolate::open lines "$label" "$branch_opt" "$dir_opt" "$dry_run" "$base"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		rm -f "$stats" "$patch" "$content_file"
		return "$rc"
	fi
	if [ "$dry_run" = "true" ]; then
		if [ "$new_file" = "true" ]; then
			_shell::git::isolate::show git -C "$_SHELL_GIT_ISOLATE_WT_DIR" add -- "$rel"
		else
			_shell::git::isolate::show git -C "$_SHELL_GIT_ISOLATE_WT_DIR" apply --unidiff-zero --index "<patch above>"
		fi
		rm -f "$stats" "$patch" "$content_file"
		return "$RETURN_SUCCESS"
	fi

	if [ "$new_file" = "true" ]; then
		if ! { mkdir -p "$(dirname "$_SHELL_GIT_ISOLATE_WT_DIR/$rel")" && cp "$content_file" "$_SHELL_GIT_ISOLATE_WT_DIR/$rel" &&
			git --literal-pathspecs -C "$_SHELL_GIT_ISOLATE_WT_DIR" add -- "$rel"; } >/dev/null 2>&1; then
			shell::logger::error "Could not create '$rel' in the worktree"
			_shell::git::isolate::rollback "$_SHELL_GIT_ISOLATE_WT_BRANCH" "$_SHELL_GIT_ISOLATE_WT_DIR"
			rm -f "$stats" "$patch" "$content_file"
			return "$RETURN_FAILURE"
		fi
	else
		if ! out="$(git -C "$_SHELL_GIT_ISOLATE_WT_DIR" apply --unidiff-zero --index --check "$patch" 2>&1)" ||
			! out="$(git -C "$_SHELL_GIT_ISOLATE_WT_DIR" apply --unidiff-zero --index "$patch" 2>&1)"; then
			shell::logger::error "The selected lines do not apply cleanly (conflict): $out"
			_shell::git::isolate::rollback "$_SHELL_GIT_ISOLATE_WT_BRANCH" "$_SHELL_GIT_ISOLATE_WT_DIR"
			rm -f "$stats" "$patch" "$content_file"
			return "$RETURN_FAILURE"
		fi
	fi
	rm -f "$stats" "$patch" "$content_file"
	git -C "$_SHELL_GIT_ISOLATE_WT_DIR" --no-pager diff --cached --stat --no-color
	_shell::git::isolate::finish "$before"
	rc=$?
	return "$rc"
}

# ==============================================================================================
# Persistent session: shell::git::isolate
#
#   choose source -> choose strategy -> ONE branch + ONE worktree -> action menu (loop)
#
# Session state lives in `_SHELL_GIT_ISOLATE_S_*` globals (private, reset by every session):
#   TOP original repository root       BEFORE fingerprint of the original state
#   BRANCH / DIR destination branch and worktree   BASE / LABEL start commit and its description
#   SRC / SRCSHA source ref and its resolved commit  STRATEGY current | parent   PARENT parent ref
#   APPLIED number of actions applied  UNSAFE set when the original state could not be guaranteed
# Every write goes through `_shell::git::isolate::session::wt`, i.e. `git -C <worktree>`; the original
# working directory is only ever READ.
# ==============================================================================================

# @internal
# @description Runs git inside the session's isolated worktree (hooks off, literal pathspecs). It
#   refuses to run when the worktree is unset or is the original repository, so no write can ever
#   reach the original working tree.
# @arg $@ string Git arguments.
# @exitcode 0 Exit status of git.
# @exitcode 1 No isolated worktree, or it is the original repository.
# @example
#   _shell::git::isolate::session::wt checkout "$sha" -- "$path"
#
_shell::git::isolate::session::wt() {
	if [ -z "$_SHELL_GIT_ISOLATE_S_DIR" ] || [ "$_SHELL_GIT_ISOLATE_S_DIR" = "$_SHELL_GIT_ISOLATE_S_TOP" ]; then
		return "$RETURN_FAILURE"
	fi
	git -c core.hooksPath=/dev/null --literal-pathspecs -C "$_SHELL_GIT_ISOLATE_S_DIR" "$@"
}

# @internal
# @description Succeeds while the destination worktree is still usable: it exists, is a worktree
#   other than the original, and still has the destination branch checked out.
# @exitcode 0 Usable.
# @exitcode 1 Missing or changed.
# @example
#   _shell::git::isolate::session::alive || return "$RETURN_FAILURE"
#
_shell::git::isolate::session::alive() {
	[ -d "$_SHELL_GIT_ISOLATE_S_DIR" ] || return "$RETURN_FAILURE"
	[ "$(git -C "$_SHELL_GIT_ISOLATE_S_DIR" rev-parse --show-toplevel 2>/dev/null)" != "$_SHELL_GIT_ISOLATE_S_TOP" ] || return "$RETURN_FAILURE"
	[ "$(git -C "$_SHELL_GIT_ISOLATE_S_DIR" symbolic-ref -q --short HEAD 2>/dev/null)" = "$_SHELL_GIT_ISOLATE_S_BRANCH" ]
}

# @internal
# @description Compares the original repository with the fingerprint taken before the session. On a
#   difference the session is marked unsafe.
# @exitcode 0 Unchanged.
# @exitcode 1 The original repository state changed.
# @example
#   _shell::git::isolate::session::verify || break
#
_shell::git::isolate::session::verify() {
	local now
	now="$(_shell::git::isolate::fingerprint "$_SHELL_GIT_ISOLATE_S_TOP" "$_SHELL_GIT_ISOLATE_S_BRANCH" "$_SHELL_GIT_ISOLATE_S_DIR")"
	if [ "$now" != "$_SHELL_GIT_ISOLATE_S_BEFORE" ]; then
		_SHELL_GIT_ISOLATE_S_UNSAFE=1
		shell::logger::error "The original repository state changed during the session; stopping. Inspect it with 'git status'."
		return "$RETURN_FAILURE"
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Re-resolves the session's source ref to a commit id; warns when it moved.
# @stdout The commit id.
# @exitcode 0 Resolved.
# @exitcode 3 The source ref no longer exists.
# @example
#   sha="$(_shell::git::isolate::session::source_sha)" || return $?
#
_shell::git::isolate::session::source_sha() {
	local sha
	if ! sha="$(_shell::git::isolate::resolve "$_SHELL_GIT_ISOLATE_S_SRC")"; then
		shell::logger::error "Source '$_SHELL_GIT_ISOLATE_S_SRC' no longer exists; switch the source branch"
		return "$RETURN_NOT_FOUND"
	fi
	if [ "$sha" != "$_SHELL_GIT_ISOLATE_S_SRCSHA" ]; then
		shell::logger::warn "Source '$_SHELL_GIT_ISOLATE_S_SRC' moved (${_SHELL_GIT_ISOLATE_S_SRCSHA:0:7} -> ${sha:0:7}); using the new tip" >&2
		_SHELL_GIT_ISOLATE_S_SRCSHA="$sha"
	fi
	printf '%s\n' "$sha"
}

# @internal
# @description Discards whatever a failed action left in the DESTINATION worktree (`reset --hard HEAD`
#   there), restoring the state after the previous action. Never touches the original repository.
# @exitcode 0 Always.
# @example
#   _shell::git::isolate::session::revert
#
_shell::git::isolate::session::revert() {
	_shell::git::isolate::session::wt reset -q --hard HEAD >/dev/null 2>&1
	return "$RETURN_SUCCESS"
}

# @internal
# @description Commits what is staged in the destination worktree as one action of the session.
# @arg $1 string Commit message.
# @exitcode 0 Committed (the applied counter is incremented).
# @exitcode 1 The commit failed (the action is reverted).
# @exitcode 8 Nothing is staged.
# @example
#   _shell::git::isolate::session::commit "isolate: pick 2 file(s) from main"
#
_shell::git::isolate::session::commit() {
	local out
	if _shell::git::isolate::session::wt diff --cached --quiet; then
		return "$RETURN_EMPTY"
	fi
	if ! out="$(_shell::git::isolate::session::wt commit -q --no-verify -m "$1" 2>&1)"; then
		shell::logger::error "Could not commit in the destination (is user.name / user.email set?): $out"
		_shell::git::isolate::session::revert
		return "$RETURN_FAILURE"
	fi
	_SHELL_GIT_ISOLATE_S_APPLIED=$((_SHELL_GIT_ISOLATE_S_APPLIED + 1))
	return "$RETURN_SUCCESS"
}

# @internal
# @description Succeeds when no parent directory of a destination path is a symlink (a link could point
#   back into the original working tree).
# @arg $1 string Repository-relative path.
# @exitcode 0 Safe.
# @exitcode 1 A parent directory is a symlink.
# @example
#   _shell::git::isolate::session::safe_dest "src/a.sh"
#
_shell::git::isolate::session::safe_dest() {
	local walk="$_SHELL_GIT_ISOLATE_S_DIR" rest="${1%/*}" part
	[ "$rest" = "$1" ] && return "$RETURN_SUCCESS"
	while [ -n "$rest" ]; do
		part="${rest%%/*}"
		walk="$walk/$part"
		[ -L "$walk" ] && return "$RETURN_FAILURE"
		case "$rest" in */*) rest="${rest#*/}" ;; *) rest="" ;; esac
	done
	return "$RETURN_SUCCESS"
}

# @internal
# @description Interactive choice of source branch and target strategy (Back steps back one screen).
#   Sets `_SHELL_GIT_ISOLATE_S_SRC/SRCSHA/STRATEGY/PARENT/START/BRANCH_OPT/LABEL`.
# @exitcode 0 Ready to create the destination.
# @exitcode 9 The user cancelled (ESC).
# @exitcode 11 The user went Back from the first screen.
# @example
#   _shell::git::isolate::session::choose || return $?
#
_shell::git::isolate::session::choose() {
	local step="source" rc picked name current default_name
	while true; do
		case "$step" in
		source)
			picked="$(_shell::git::isolate::fzf::branch "Source branch: ")"
			rc=$?
			[ "$rc" -ne 0 ] && return "$rc"
			if ! _SHELL_GIT_ISOLATE_S_SRCSHA="$(_shell::git::isolate::resolve "$picked")"; then
				shell::logger::error "Source '$picked' could not be resolved"
				continue
			fi
			_SHELL_GIT_ISOLATE_S_SRC="$picked"
			step="strategy"
			;;
		strategy)
			picked="$(_shell::git::isolate::fzf::strategy)"
			rc=$?
			if [ "$rc" -eq "$RETURN_BACK" ]; then
				step="source"
				continue
			fi
			[ "$rc" -ne 0 ] && return "$rc"
			if [ "$picked" = "current" ]; then
				_SHELL_GIT_ISOLATE_S_STRATEGY="current"
				_SHELL_GIT_ISOLATE_S_PARENT=""
				_SHELL_GIT_ISOLATE_S_START="$(git -C "$_SHELL_GIT_ISOLATE_S_TOP" rev-parse HEAD)"
				current="$(git -C "$_SHELL_GIT_ISOLATE_S_TOP" symbolic-ref -q --short HEAD 2>/dev/null)"
				if [ -z "$current" ]; then
					shell::logger::warn "HEAD is detached; the isolated branch starts at ${_SHELL_GIT_ISOLATE_S_START:0:7}"
					current="detached"
				fi
				_SHELL_GIT_ISOLATE_S_BRANCH_OPT=""
				_SHELL_GIT_ISOLATE_S_LABEL="$(_shell::git::isolate::slug "$current")-$(git rev-parse --short=7 "$_SHELL_GIT_ISOLATE_S_START")"
				return "$RETURN_SUCCESS"
			fi
			step="parent"
			;;
		parent)
			picked="$(_shell::git::isolate::fzf::branch "Parent branch: ")"
			rc=$?
			if [ "$rc" -eq "$RETURN_BACK" ]; then
				step="strategy"
				continue
			fi
			[ "$rc" -ne 0 ] && return "$rc"
			if ! _SHELL_GIT_ISOLATE_S_START="$(_shell::git::isolate::resolve "$picked")"; then
				shell::logger::error "Parent '$picked' could not be resolved"
				continue
			fi
			_SHELL_GIT_ISOLATE_S_STRATEGY="parent"
			_SHELL_GIT_ISOLATE_S_PARENT="$picked"
			_SHELL_GIT_ISOLATE_S_LABEL="$(_shell::git::isolate::slug "$picked")-$(git rev-parse --short=7 "$_SHELL_GIT_ISOLATE_S_START")"
			step="name"
			;;
		name)
			default_name="$(_shell::git::isolate::unique_branch "isolate/session/$_SHELL_GIT_ISOLATE_S_LABEL")"
			shell::console::print "[e] New branch name, created from '$_SHELL_GIT_ISOLATE_S_PARENT' (empty = ${default_name}, '<' = back):" 208
			read -r name || return "$RETURN_CANCELLED"
			case "$name" in
			'<')
				step="parent"
				continue
				;;
			'')
				_SHELL_GIT_ISOLATE_S_BRANCH_OPT=""
				return "$RETURN_SUCCESS"
				;;
			esac
			if ! git check-ref-format --branch "$name" >/dev/null 2>&1; then
				shell::logger::error "'$name' is not a valid branch name"
				continue
			fi
			if git show-ref --verify --quiet "refs/heads/$name"; then
				shell::logger::error "Branch '$name' already exists; it was left untouched. Choose another name."
				continue
			fi
			_SHELL_GIT_ISOLATE_S_BRANCH_OPT="$name"
			return "$RETURN_SUCCESS"
			;;
		esac
	done
}

# @internal
# @description Pick Files: choose files of the source, preview the diff against the DESTINATION, confirm,
#   apply them in the destination worktree and commit them there as one action.
#   A file that exists in the destination with different content needs an explicit confirmation.
# @exitcode 0 Applied.
# @exitcode 1 The action failed and was reverted.
# @exitcode 3 Missing source or file.
# @exitcode 8 Everything is already identical in the destination.
# @exitcode 9 The user cancelled or went back.
# @example
#   _shell::git::isolate::session::act::files
#
_shell::git::isolate::session::act::files() {
	local sha picked rc p kind_of src_id dst_id out question
	local -a todo=() overwrites=()
	sha="$(_shell::git::isolate::session::source_sha)" || return $?
	picked="$(_shell::git::isolate::fzf::files "$sha" true "$_SHELL_GIT_ISOLATE_S_DIR")"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		return "$RETURN_CANCELLED"
	fi
	while IFS= read -r p; do
		[ -n "$p" ] || continue
		if ! _shell::git::isolate::valid_path "$p"; then
			shell::logger::error "Invalid path '$p'"
			return "$RETURN_INVALID"
		fi
		kind_of="$(git cat-file -t "$sha:$p" 2>/dev/null)"
		if [ "$kind_of" != "blob" ]; then
			shell::logger::error "'$p' is not a file in '$_SHELL_GIT_ISOLATE_S_SRC'"
			return "$RETURN_NOT_FOUND"
		fi
		src_id="$(git rev-parse "$sha:$p")"
		dst_id="$(_shell::git::isolate::session::wt rev-parse --verify --quiet "HEAD:$p" 2>/dev/null)"
		if [ "$dst_id" = "$src_id" ]; then
			shell::logger::info "$p is already identical in the destination — skipped"
			continue
		fi
		_shell::git::isolate::session::safe_dest "$p" || {
			shell::logger::error "A parent directory of '$p' is a symlink in the destination; refusing to write through it"
			return "$RETURN_FAILURE"
		}
		[ -n "$dst_id" ] && overwrites+=("$p")
		todo+=("$p")
	done <<<"$picked"
	if [ "${#todo[@]}" -eq 0 ]; then
		shell::logger::warn "Nothing to apply: everything selected is already in the destination"
		return "$RETURN_EMPTY"
	fi

	shell::logger::info "From '$_SHELL_GIT_ISOLATE_S_SRC' into '$_SHELL_GIT_ISOLATE_S_BRANCH':"
	_shell::git::isolate::session::wt --no-pager diff --stat --no-color HEAD "$sha" -- "${todo[@]}"
	_shell::git::isolate::session::wt --no-pager diff --no-color HEAD "$sha" -- "${todo[@]}"
	question="Apply ${#todo[@]} file(s) to the isolated destination?"
	if [ "${#overwrites[@]}" -gt 0 ]; then
		for p in "${overwrites[@]}"; do
			shell::logger::warn "Conflict: $p already exists in the destination with different content"
		done
		question="${#overwrites[@]} file(s) already exist in the destination with different content. Overwrite them and apply ${#todo[@]} file(s)?"
	fi
	shell::ask::accept "$question" || {
		shell::logger::info "Cancelled — the destination was not changed"
		return "$RETURN_CANCELLED"
	}
	if ! out="$(_shell::git::isolate::session::wt checkout "$sha" -- "${todo[@]}" 2>&1)"; then
		shell::logger::error "Could not apply the files: $out"
		_shell::git::isolate::session::revert
		return "$RETURN_FAILURE"
	fi
	_shell::git::isolate::session::commit "isolate: pick ${#todo[@]} file(s) from $_SHELL_GIT_ISOLATE_S_SRC (${sha:0:7})" || return $?
	shell::logger::success "Applied ${#todo[@]} file(s)"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Pick Commit: choose a commit of the source, preview it and apply ITS CHANGES onto the
#   existing destination branch (`cherry-pick --no-commit`, then a commit that keeps the original message
#   and author). It never recreates the destination. Merge commits are refused (ambiguous parent); a
#   commit already in the destination is reported; conflicts are listed and the destination is restored.
# @exitcode 0 Applied.
# @exitcode 1 Conflict or failure (the destination is restored).
# @exitcode 2 A merge commit, which cannot be applied unambiguously.
# @exitcode 8 The changes are already in the destination.
# @exitcode 9 The user cancelled or went back.
# @example
#   _shell::git::isolate::session::act::commit
#
_shell::git::isolate::session::act::commit() {
	local sha csha rc out parents conflicts
	sha="$(_shell::git::isolate::session::source_sha)" || return $?
	csha="$(_shell::git::isolate::fzf::commit "$sha")"
	rc=$?
	[ "$rc" -ne 0 ] && return "$RETURN_CANCELLED"
	if ! csha="$(_shell::git::isolate::resolve "$csha")"; then
		shell::logger::error "That commit no longer exists"
		return "$RETURN_NOT_FOUND"
	fi
	parents="$(git rev-list --parents -n 1 "$csha" | wc -w | tr -d ' ')"
	if [ "$parents" -gt 2 ]; then
		shell::logger::error "${csha:0:7} is a merge commit: which parent to follow is ambiguous, so it is not applied. Pick one of the commits it merged, or use Pick Files / Pick Lines."
		return "$RETURN_INVALID"
	fi
	if _shell::git::isolate::session::wt merge-base --is-ancestor "$csha" HEAD 2>/dev/null; then
		shell::logger::info "${csha:0:7} is already part of the destination history — nothing to apply"
		return "$RETURN_EMPTY"
	fi
	_shell::git::history::show "$_SHELL_GIT_ISOLATE_S_TOP" commit "" "$csha" . "" full never
	shell::ask::accept "Apply the changes of ${csha:0:7} onto '$_SHELL_GIT_ISOLATE_S_BRANCH' (new commit, original message and author kept)?" || {
		shell::logger::info "Cancelled — the destination was not changed"
		return "$RETURN_CANCELLED"
	}
	if ! out="$(_shell::git::isolate::session::wt cherry-pick --no-commit "$csha" 2>&1)"; then
		conflicts="$(_shell::git::isolate::session::wt diff --name-only --diff-filter=U 2>/dev/null)"
		shell::logger::error "The commit does not apply cleanly onto the destination: ${conflicts:-$out}"
		_shell::git::isolate::session::revert
		return "$RETURN_FAILURE"
	fi
	if _shell::git::isolate::session::wt diff --cached --quiet; then
		shell::logger::info "The changes of ${csha:0:7} are already present in the destination"
		_shell::git::isolate::session::revert
		return "$RETURN_EMPTY"
	fi
	if ! out="$(_shell::git::isolate::session::wt commit -q --no-verify -C "$csha" 2>&1)"; then
		shell::logger::error "Could not commit in the destination (is user.name / user.email set?): $out"
		_shell::git::isolate::session::revert
		return "$RETURN_FAILURE"
	fi
	_SHELL_GIT_ISOLATE_S_APPLIED=$((_SHELL_GIT_ISOLATE_S_APPLIED + 1))
	shell::logger::success "Applied ${csha:0:7} onto '$_SHELL_GIT_ISOLATE_S_BRANCH'"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Pick Lines: choose a file and lines of the source, preview the patch against the DESTINATION
#   content, confirm, apply only those lines (`git apply --unidiff-zero --index` in the destination) and
#   commit them there. Invalid, empty, out-of-range and overlapping selections, binary files and lines
#   that change nothing are refused; the rest of the destination file is never replaced.
# @exitcode 0 Applied.
# @exitcode 1 The patch did not apply (the destination is unchanged).
# @exitcode 2 Invalid selection.
# @exitcode 8 The selected lines are already in the destination.
# @exitcode 9 The user cancelled or went back.
# @example
#   _shell::git::isolate::session::act::lines
#
_shell::git::isolate::session::act::lines() {
	local sha rel spec rc kind_of total ranges tree dst_id empty_tree out
	local stats patch content full=0 partial=0 skipped=0 new_file="false"
	sha="$(_shell::git::isolate::session::source_sha)" || return $?
	rel="$(_shell::git::isolate::fzf::files "$sha" false "$_SHELL_GIT_ISOLATE_S_DIR")"
	rc=$?
	[ "$rc" -ne 0 ] && return "$RETURN_CANCELLED"
	spec="$(_shell::git::isolate::fzf::lines "$sha" "$rel" "$_SHELL_GIT_ISOLATE_S_DIR")"
	rc=$?
	[ "$rc" -ne 0 ] && return "$RETURN_CANCELLED"

	if ! _shell::git::isolate::valid_path "$rel"; then
		shell::logger::error "Invalid path '$rel'"
		return "$RETURN_INVALID"
	fi
	kind_of="$(git cat-file -t "$sha:$rel" 2>/dev/null)"
	if [ "$kind_of" != "blob" ]; then
		shell::logger::error "'$rel' is not a file in '$_SHELL_GIT_ISOLATE_S_SRC'"
		return "$RETURN_NOT_FOUND"
	fi
	empty_tree="$(git hash-object -t tree /dev/null)"
	if git --literal-pathspecs diff --numstat "$empty_tree" "$sha" -- "$rel" | grep -q "$(printf '^-\t-\t')"; then
		shell::logger::error "'$rel' is a binary file; line selection needs text"
		return "$RETURN_INVALID"
	fi
	total="$(git cat-file blob "$sha:$rel" | awk 'END { print NR }')"
	if ! ranges="$(_shell::git::isolate::ranges "$spec" "$total")"; then
		shell::logger::error "$ranges"
		return "$RETURN_INVALID"
	fi
	_shell::git::isolate::session::safe_dest "$rel" || {
		shell::logger::error "A parent directory of '$rel' is a symlink in the destination; refusing to write through it"
		return "$RETURN_FAILURE"
	}

	stats="$(mktemp "${TMPDIR:-/tmp}/shell-isolate-stats.XXXXXX")" || return "$RETURN_FAILURE"
	patch="$(mktemp "${TMPDIR:-/tmp}/shell-isolate-patch.XXXXXX")" || {
		rm -f "$stats"
		return "$RETURN_FAILURE"
	}
	content="$(mktemp "${TMPDIR:-/tmp}/shell-isolate-lines.XXXXXX")" || {
		rm -f "$stats" "$patch"
		return "$RETURN_FAILURE"
	}

	tree="$(_shell::git::isolate::session::wt write-tree 2>/dev/null)"
	dst_id="$(_shell::git::isolate::session::wt rev-parse --verify --quiet ":0:$rel" 2>/dev/null)"
	if [ -z "$dst_id" ]; then
		new_file="true"
		git cat-file blob "$sha:$rel" | awk -v ranges="$ranges" '
			BEGIN { n = split(ranges, rr, ","); for (i = 1; i <= n; i++) { split(rr[i], p, "-"); for (l = p[1] + 0; l <= p[2] + 0; l++) sel[l] = 1 } }
			NR in sel' >"$content"
	else
		_shell::git::isolate::patch "$tree" "$sha" "$rel" "$ranges" "$stats" >"$patch"
		read -r full partial skipped <"$stats"
		if [ ! -s "$patch" ]; then
			rm -f "$stats" "$patch" "$content"
			shell::logger::info "The selected lines (${ranges}) change nothing in the destination (already applied, or identical)"
			return "$RETURN_EMPTY"
		fi
		[ "${partial:-0}" -gt 0 ] && shell::logger::warn "${partial} changed block(s) are selected only in part: just the selected lines are inserted and the lines they replace are kept"
		[ "${skipped:-0}" -gt 0 ] && shell::logger::info "${skipped} changed block(s) outside the selection (or pure deletions) are skipped"
	fi

	shell::logger::info "Lines ${ranges} of ${rel} from '${_SHELL_GIT_ISOLATE_S_SRC}' into '${_SHELL_GIT_ISOLATE_S_BRANCH}':"
	if [ "$new_file" = "true" ]; then
		shell::logger::info "$rel does not exist in the destination; it would be created with the selected lines"
		sed 's/^/+/' "$content"
	else
		cat "$patch"
	fi
	if ! shell::ask::accept "Apply only these lines to the isolated destination?"; then
		rm -f "$stats" "$patch" "$content"
		shell::logger::info "Cancelled — the destination was not changed"
		return "$RETURN_CANCELLED"
	fi

	if [ "$new_file" = "true" ]; then
		if ! { mkdir -p "$(dirname "$_SHELL_GIT_ISOLATE_S_DIR/$rel")" && cp "$content" "$_SHELL_GIT_ISOLATE_S_DIR/$rel" &&
			_shell::git::isolate::session::wt add -- "$rel"; } >/dev/null 2>&1; then
			shell::logger::error "Could not create '$rel' in the destination"
			_shell::git::isolate::session::revert
			rm -f "$stats" "$patch" "$content"
			return "$RETURN_FAILURE"
		fi
	elif ! out="$(_shell::git::isolate::session::wt apply --unidiff-zero --index --check "$patch" 2>&1)" ||
		! out="$(_shell::git::isolate::session::wt apply --unidiff-zero --index "$patch" 2>&1)"; then
		shell::logger::error "The selected lines do not apply cleanly (conflict): $out"
		_shell::git::isolate::session::revert
		rm -f "$stats" "$patch" "$content"
		return "$RETURN_FAILURE"
	fi
	rm -f "$stats" "$patch" "$content"
	_shell::git::isolate::session::commit "isolate: pick lines ${ranges} of ${rel} from $_SHELL_GIT_ISOLATE_S_SRC (${sha:0:7})" || return $?
	shell::logger::success "Applied lines ${ranges} of ${rel}"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Switch Source Branch: pick another source. Only the session's source reference changes;
#   the destination branch, the worktree and everything already applied are kept.
# @exitcode 0 Switched.
# @exitcode 9 The user cancelled or went back (the source is unchanged).
# @example
#   _shell::git::isolate::session::act::switch
#
_shell::git::isolate::session::act::switch() {
	local picked rc sha
	picked="$(_shell::git::isolate::fzf::branch "Source branch: ")"
	rc=$?
	[ "$rc" -ne 0 ] && return "$RETURN_CANCELLED"
	if ! sha="$(_shell::git::isolate::resolve "$picked")"; then
		shell::logger::error "Source '$picked' could not be resolved; the source is unchanged"
		return "$RETURN_NOT_FOUND"
	fi
	_SHELL_GIT_ISOLATE_S_SRC="$picked"
	_SHELL_GIT_ISOLATE_S_SRCSHA="$sha"
	shell::logger::info "Source branch is now '$picked' (${sha:0:7}); the destination and its changes are untouched"
	return "$RETURN_SUCCESS"
}

# @internal
# @description The persistent action loop: Pick Files / Pick Commit / Pick Lines / Switch Source Branch /
#   Back. An action ending in success, cancellation, "nothing to do" or a recoverable failure returns to
#   the menu; only Back, ESC, an unavailable destination or a changed original state end the loop.
# @exitcode 0 Left with ESC.
# @exitcode 1 The session is no longer safe.
# @exitcode 11 Left with Back.
# @example
#   _shell::git::isolate::session::loop
#
_shell::git::isolate::session::loop() {
	local action rc init=""
	while true; do
		if ! _shell::git::isolate::session::alive; then
			_SHELL_GIT_ISOLATE_S_UNSAFE=1
			shell::logger::error "The isolated worktree '$_SHELL_GIT_ISOLATE_S_DIR' is no longer available (or no longer on '$_SHELL_GIT_ISOLATE_S_BRANCH'); ending the session"
			return "$RETURN_FAILURE"
		fi
		action="$(_shell::git::isolate::fzf::menu "$init")"
		rc=$?
		case "$rc" in
		0) ;;
		"$RETURN_BACK") return "$RETURN_BACK" ;;
		*) return "$RETURN_SUCCESS" ;;
		esac
		init="$action"
		case "$action" in
		files) _shell::git::isolate::session::act::files ;;
		commit) _shell::git::isolate::session::act::commit ;;
		lines) _shell::git::isolate::session::act::lines ;;
		switch) _shell::git::isolate::session::act::switch ;;
		esac
		# Every outcome (applied, cancelled, nothing to do, failed and reverted) returns to the menu.
		_shell::git::isolate::session::verify || return "$RETURN_FAILURE"
	done
}

# @description Persistent interactive session: take commits, files and lines of other branches into ONE
#   isolated branch and worktree, as many times as you like, without touching your checkout.
#
#   1. Pick the source branch (local and remote; the current one is marked; log preview).
#   2. Pick the target strategy, once:
#        - Apply to the current branch (isolated copy): a new branch at the current HEAD;
#        - Create a new branch from a parent branch: pick the parent, then a name (empty = generated).
#      Exactly one branch and one linked worktree (outside the working tree, under SHELL_GIT_ISOLATE_DIR)
#      are created; the strategy cannot change during the session.
#   3. The action menu stays open: Pick Files, Pick Commit, Pick Lines, Switch Source Branch, Back.
#      Each action previews, asks for confirmation, applies inside the worktree and commits there (one
#      commit per action, so a failed action is reverted without losing earlier ones), then returns to
#      the menu. Cancelling a picker or a failing action returns to the menu too.
#   4. Back or ESC leaves. The branch and worktree are KEPT (a summary shows where); only a session that
#      applied nothing offers to remove its empty worktree, and only after an explicit yes.
#
#   The original repository is never written: every write is `git -C <worktree>`. Its HEAD, branch, refs,
#   index, tracked / modified / untracked file contents, stash and other worktrees are fingerprinted before
#   the session, after every action and at the end; a difference stops the session.
# @option -n | --dry-run Optional. Choose source and strategy, print the worktree command, create nothing.
# @option -h | --help Show this help message.
# @exitcode 0 The session ended (ESC, or a dry run).
# @exitcode 1 Not a repository, the worktree could not be created, or the session stopped for safety.
# @exitcode 2 Unknown option.
# @exitcode 7 The chosen branch or directory already exists.
# @exitcode 11 The user went Back.
# @see shell::git::isolate::commit
# @see shell::git::isolate::file
# @see shell::git::isolate::lines
# @example
#   shell::git::isolate
#   shell::git::isolate -n
#
shell::git::isolate() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Persistent session: pick files, commits and lines of other branches into one isolated branch and worktree"
		shell::logger::usage "shell::git::isolate [-n] [-h]"
		shell::logger::option "-n, --dry-run" "Print the worktree command and stop (nothing is created)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "Your checkout is never written. The action menu stays open until Back or ESC; the branch and worktree are kept on exit."
		shell::logger::example "shell::git::isolate"
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

	_shell::git::isolate::guard || return $?
	shell::dependency::fzf::ensure

	_SHELL_GIT_ISOLATE_S_TOP="$(git rev-parse --show-toplevel)"
	_SHELL_GIT_ISOLATE_S_BEFORE="$(_shell::git::isolate::fingerprint "$_SHELL_GIT_ISOLATE_S_TOP")"
	_SHELL_GIT_ISOLATE_S_BRANCH=""
	_SHELL_GIT_ISOLATE_S_DIR=""
	_SHELL_GIT_ISOLATE_S_SRC=""
	_SHELL_GIT_ISOLATE_S_SRCSHA=""
	_SHELL_GIT_ISOLATE_S_STRATEGY=""
	_SHELL_GIT_ISOLATE_S_PARENT=""
	_SHELL_GIT_ISOLATE_S_START=""
	_SHELL_GIT_ISOLATE_S_BRANCH_OPT=""
	_SHELL_GIT_ISOLATE_S_LABEL=""
	_SHELL_GIT_ISOLATE_S_APPLIED=0
	_SHELL_GIT_ISOLATE_S_UNSAFE=0

	local rc final
	_shell::git::isolate::session::choose
	rc=$?
	if [ "$rc" -eq "$RETURN_BACK" ]; then
		shell::logger::info "Back — nothing was changed"
		return "$RETURN_BACK"
	fi
	if [ "$rc" -ne 0 ]; then
		shell::logger::info "Closed"
		return "$RETURN_SUCCESS"
	fi

	_shell::git::isolate::open session "$_SHELL_GIT_ISOLATE_S_LABEL" "$_SHELL_GIT_ISOLATE_S_BRANCH_OPT" "" "$dry_run" "$_SHELL_GIT_ISOLATE_S_START" || return $?
	_SHELL_GIT_ISOLATE_S_BRANCH="$_SHELL_GIT_ISOLATE_WT_BRANCH"
	_SHELL_GIT_ISOLATE_S_DIR="$_SHELL_GIT_ISOLATE_WT_DIR"
	if [ "$dry_run" = "true" ]; then
		shell::logger::info "Dry run: no session was started"
		return "$RETURN_SUCCESS"
	fi
	if ! _shell::git::isolate::session::verify; then
		_shell::git::isolate::rollback "$_SHELL_GIT_ISOLATE_S_BRANCH" "$_SHELL_GIT_ISOLATE_S_DIR"
		return "$RETURN_FAILURE"
	fi
	shell::logger::success "Isolated destination ready: branch '$_SHELL_GIT_ISOLATE_S_BRANCH' in $_SHELL_GIT_ISOLATE_S_DIR"
	shell::logger::info "Source '$_SHELL_GIT_ISOLATE_S_SRC'; base ${_SHELL_GIT_ISOLATE_S_START:0:7}${_SHELL_GIT_ISOLATE_S_PARENT:+ (from '$_SHELL_GIT_ISOLATE_S_PARENT')}"

	_shell::git::isolate::session::loop
	rc=$?
	final=0
	_shell::git::isolate::session::verify || final=1

	if [ "$_SHELL_GIT_ISOLATE_S_UNSAFE" -ne 1 ]; then
		shell::logger::info "Session summary: ${_SHELL_GIT_ISOLATE_S_APPLIED} action(s) applied"
	fi
	shell::logger::info "Destination branch: $_SHELL_GIT_ISOLATE_S_BRANCH"
	shell::logger::info "Worktree: $_SHELL_GIT_ISOLATE_S_DIR"
	if [ "$_SHELL_GIT_ISOLATE_S_APPLIED" -eq 0 ] && [ "$_SHELL_GIT_ISOLATE_S_UNSAFE" -ne 1 ] && _shell::git::isolate::session::alive; then
		if shell::ask::accept "Nothing was applied. Remove the empty worktree and branch '$_SHELL_GIT_ISOLATE_S_BRANCH'?"; then
			_shell::git::isolate::rollback "$_SHELL_GIT_ISOLATE_S_BRANCH" "$_SHELL_GIT_ISOLATE_S_DIR"
			shell::logger::info "Removed the empty worktree and branch"
			[ "$final" -eq 0 ] && return "$rc"
			return "$RETURN_FAILURE"
		fi
	fi
	shell::logger::command "cd $(printf '%q' "$_SHELL_GIT_ISOLATE_S_DIR")"
	shell::logger::info "Your checkout was left untouched. Remove later with: git worktree remove $(printf '%q' "$_SHELL_GIT_ISOLATE_S_DIR")"
	[ "$final" -ne 0 ] && return "$RETURN_FAILURE"
	return "$rc"
}
