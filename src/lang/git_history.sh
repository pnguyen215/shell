#!/usr/bin/env bash
# @file lang/git_history.sh
# @brief Git history explorer: a dashboard, a vertical commit timeline and an fzf viewer.
# @description
#   Shows how a file, a function, a line range or a piece of code evolved, one commit at a
#   time. The layers are kept apart on purpose:
#
#     context  -> scope   -> log  -> stats -> dashboard / timeline -> fzf -> preview / inspect
#     (where)    (what)      (git)   (numbers)  (render)                (interact)  (show a commit)
#
#   - Git data is retrieved once, as *commit records* (see shell::git::history::log), and every
#     other layer reads those records from stdin. Nothing renders while it retrieves.
#   - A record is one line, fields separated by US (0x1f, `$'\037'`) so empty fields survive:
#       1 full hash   2 short hash   3 author   4 date (YYYY-MM-DD)
#       5 additions   6 deletions    7 files changed (in the scope)   8 merge (0|1)
#       9 path at that commit   10 path before a rename   11-13 additions, deletions, files of
#       the WHOLE commit   14 subject   15 body (newlines written as the two characters `\n`)
#       16 branch (added by shell::git::history::branches; may be empty)
#   - The scope kinds are told apart because Git tracks them differently: a file is followed
#     with `git log --follow`, a function or a line range with `git log -L`, code with
#     `git log -S` / `-G`. For function and line scopes the additions and deletions are those of
#     the selected lines only, never the whole commit.
#   - Nothing here writes to the working tree, the index or the repository.

# @internal
# @description Describe the repository and, optionally, a file inside it.
#   Resolves a relative or absolute path to a path relative to the repository root, checks that
#   the file is (or was) part of the repository, and names the branch (`(detached at <hash>)`
#   on a detached HEAD, the unborn branch name before the first commit).
# @arg $1 string Optional. File path, relative to the current directory or absolute.
# @stdout One line, fields separated by US: root, repository name, branch, path relative to root.
# @stderr The reason when the context cannot be resolved.
# @exitcode 0 Resolved.
# @exitcode 1 Not a repository, or the file does not belong to it.
# @example
#   IFS=$'\037' read -r root name branch rel <<<"$(shell::git::history::context src/a.sh)"
#
shell::git::history::context() {
	local file="${1-}" us=$'\037'
	local root name branch rel="" prefix dir base canon

	root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
		shell::logger::error "Not inside a Git repository"
		return "$RETURN_FAILURE"
	}
	name="${root##*/}"
	branch="$(git symbolic-ref --short -q HEAD 2>/dev/null)" || branch=""
	if [ -z "$branch" ]; then
		branch="(detached at $(git rev-parse --short HEAD 2>/dev/null || echo '?'))"
	fi

	if [ -n "$file" ]; then
		case "$file" in
		/*)
			dir="${file%/*}"
			base="${file##*/}"
			if [ -d "${dir:-/}" ]; then
				canon="$(cd "${dir:-/}" && pwd -P)/$base"
			else
				canon="$file"
			fi
			case "$canon" in
			"$root"/*) rel="${canon#"$root"/}" ;;
			*)
				shell::logger::error "File is outside the repository: $file"
				return "$RETURN_FAILURE"
				;;
			esac
			;;
		*)
			prefix="$(git rev-parse --show-prefix 2>/dev/null)"
			dir="$(dirname -- "$file")"
			base="${file##*/}"
			if [ -d "$dir" ]; then
				canon="$(cd "$dir" && pwd -P)/$base"
				case "$canon" in
				"$root"/*) rel="${canon#"$root"/}" ;;
				*)
					shell::logger::error "File is outside the repository: $file"
					return "$RETURN_FAILURE"
					;;
				esac
			else
				# The directory is gone (a deleted file): fall back to the prefix.
				file="${file#./}"
				rel="${prefix}${file}"
			fi
			;;
		esac

		if ! git -C "$root" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1 &&
			[ -z "$(git -C "$root" log -n 1 --format=%H -- "$rel" 2>/dev/null)" ]; then
			shell::logger::error "'$file' is not in this repository (not tracked, never committed)"
			return "$RETURN_FAILURE"
		fi
	fi

	printf '%s%s%s%s%s%s%s\n' "$root" "$us" "$name" "$us" "$branch" "$us" "$rel"
}

# @internal
# @description Normalize and validate a history scope.
#   Types: `repo` (every commit), `file`, `function`, `lines`, `search` (git -S: commits that
#   changed the NUMBER of occurrences of a string) and `regex` (git -G: commits whose diff
#   matches a regular expression). `file` is optional for `search` and `regex`.
#   A line range is `START,END` (also written `START:END` or `START-END`), 1-based and
#   inclusive; it is checked against the file at HEAD. A function name is a plain identifier
#   (letters, digits and `_ . $ : ~ # @ -`); it is resolved by Git's per-language function
#   patterns, not by a parser.
# @arg $1 string Scope type.
# @arg $2 string Path relative to the repository root (may be empty for repo/search/regex).
# @arg $3 string Function name, line range or search text.
# @stdout One line, fields separated by US: type, file, spec (a range is normalized to `S,E`).
# @stderr The reason when the scope is invalid.
# @exitcode 0 Valid scope.
# @exitcode 1 Unsupported type, missing argument, or invalid range / name.
# @example
#   shell::git::history::scope lines src/a.sh 10-40
#
shell::git::history::scope() {
	local type="${1-}" file="${2-}" spec="${3-}" us=$'\037'
	local start end total

	case "$type" in
	repo) file="" spec="" ;;
	file)
		[ -n "$file" ] || {
			shell::logger::error "A file is required for the file scope"
			return "$RETURN_FAILURE"
		}
		spec=""
		;;
	function)
		[ -n "$file" ] || {
			shell::logger::error "A file is required for the function scope"
			return "$RETURN_FAILURE"
		}
		case "$spec" in
		'' | [!A-Za-z_]* | *[!A-Za-z0-9_.\$:~#@-]*)
			shell::logger::error "Invalid function name: '$spec' (use a plain identifier)"
			return "$RETURN_FAILURE"
			;;
		esac
		;;
	lines)
		[ -n "$file" ] || {
			shell::logger::error "A file is required for the line-range scope"
			return "$RETURN_FAILURE"
		}
		case "$spec" in
		*,*) start="${spec%%,*}" end="${spec#*,}" ;;
		*:*) start="${spec%%:*}" end="${spec#*:}" ;;
		*-*) start="${spec%%-*}" end="${spec#*-}" ;;
		*) start="" end="" ;;
		esac
		case "$start$end" in
		'' | *[!0-9]*)
			shell::logger::error "Invalid line range: '$spec' (use START,END, e.g. 10,40)"
			return "$RETURN_FAILURE"
			;;
		esac
		if [ -z "$start" ] || [ -z "$end" ] || [ "$start" -lt 1 ] || [ "$end" -lt "$start" ]; then
			shell::logger::error "Invalid line range: '$spec' (START must be >= 1 and <= END)"
			return "$RETURN_FAILURE"
		fi
		total="$(git show "HEAD:$file" 2>/dev/null | wc -l | tr -d ' ')"
		if [ "${total:-0}" -eq 0 ]; then
			shell::logger::error "'$file' does not exist at HEAD: a line range needs an existing file"
			return "$RETURN_FAILURE"
		fi
		if [ "$end" -gt "$total" ]; then
			shell::logger::error "Line range ends at $end but '$file' has $total lines"
			return "$RETURN_FAILURE"
		fi
		spec="${start},${end}"
		;;
	search | regex)
		[ -n "$spec" ] || {
			shell::logger::error "Search text is empty"
			return "$RETURN_FAILURE"
		}
		;;
	*)
		shell::logger::error "Unsupported scope: '$type' (repo, file, function, lines, search, regex)"
		return "$RETURN_FAILURE"
		;;
	esac

	printf '%s%s%s%s%s\n' "$type" "$us" "$file" "$us" "$spec"
}

# @internal
# @description Turn a function name into the `-L` argument of `git log`.
#   The single place that knows how a function is located. It uses Git's own funcname
#   patterns (`:<name>:<file>`), which are line based, not AST based: renamed functions are
#   not linked to their old name, and languages Git has no pattern for fall back to a generic
#   "line starts with a letter" rule. Define a function with this name AFTER loading the
#   library (for example one backed by tree-sitter that prints `START,END:<file>`) to improve
#   it without touching the rest of the explorer. A `:` in the name is written `[:]` because Git
#   splits the argument at the first colon.
# @arg $1 string Path relative to the repository root.
# @arg $2 string Function name.
# @stdout The `-L` argument.
# @exitcode 0 Always.
# @example
#   shell::git::history::function::resolve src/a.sh Login   # :Login:src/a.sh
#
shell::git::history::function::resolve() {
	local file="${1-}" name="${2-}" re=""
	local rest="$name"
	while :; do
		case "$rest" in
		*:*)
			re="${re}${rest%%:*}[:]"
			rest="${rest#*:}"
			;;
		*)
			re="${re}${rest}"
			break
			;;
		esac
	done
	printf ':%s:%s\n' "$re" "$file"
}

# @internal
# @description The arguments of the `git log` that retrieves a scope, one per line (without `git`).
#   Machine-readable output only: a fixed `--format` with control-character delimiters, plus
#   `--numstat` (file, string and repository scopes) or `-p` (`-L`, which supports no other
#   diff format). Merge commits are kept unless asked otherwise; Git only lists a merge when it
#   changed the path itself.
# @arg $1 string Scope type.
# @arg $2 string File (relative to the root, may be empty).
# @arg $3 string Function name, line range or search text.
# @arg $4 integer Optional. Most commits (default: SHELL_GIT_HISTORY_MAX).
# @arg $5 string Optional. `false` leaves merge commits out (default: true).
# @arg $6 string Optional. Revision to start from (used to reach a function that was deleted).
# @arg $7 string Optional. Branch to walk. Empty walks every branch (`--all`). Ignored when $6 is set.
# @stdout The arguments, one per line.
# @exitcode 0 Success.
# @exitcode 1 Unsupported scope type.
# @example
#   shell::git::history::log::args file src/a.sh "" 50
#
shell::git::history::log::args() {
	local type="${1-}" file="${2-}" spec="${3-}" max="${4:-$SHELL_GIT_HISTORY_MAX}" merges="${5:-true}" rev="${6-}" branch="${7-}"

	printf '%s\n' -c core.quotepath=off log --no-color --date=short "-n${max}" \
		'--format=%x1e%H%x1f%h%x1f%an%x1f%ad%x1f%P%x1f%s%x1f%b%x1f'
	[ "$merges" = "false" ] && printf '%s\n' --no-merges

	case "$type" in
	repo) printf '%s\n' --numstat -M ;;
	file) printf '%s\n' --follow --numstat -M ;;
	function)
		printf '%s\n' -L "$(shell::git::history::function::resolve "$file" "$spec")" \
			-p --src-prefix=a/ --dst-prefix=b/
		;;
	lines) printf '%s\n' -L "${spec}:${file}" -p --src-prefix=a/ --dst-prefix=b/ ;;
	search) printf '%s\n' "-S${spec}" --numstat -M ;;
	regex) printf '%s\n' "-G${spec}" --numstat -M ;;
	*) return "$RETURN_FAILURE" ;;
	esac

	if [ -n "$rev" ]; then
		printf '%s\n' "$rev"
	elif [ -n "$branch" ]; then
		printf '%s\n' "$branch"
	else
		printf '%s\n' --all
	fi
	case "$type" in
	file | search | regex) [ -n "$file" ] && printf '%s\n%s\n' -- "$file" ;;
	esac
	return "$RETURN_SUCCESS"
}

# @description Retrieves the commits of a scope as normalized commit records.
#   Records are newest first, one per line, fields separated by US (see the file header for the
#   field list). A function that no longer exists at HEAD is looked up from the commit before
#   it was removed, so its history is still reachable (the removing commit itself is not part
#   of a `git log -L` walk). Whole-commit numbers (fields 11-13) come from a second, batched
#   `git log --no-walk`, so a commit that touched other code can be told apart from the part
#   that touched the scope.
# @arg $1 string Scope type: repo, file, function, lines, search or regex.
# @arg $2 string File relative to the repository root (may be empty).
# @arg $3 string Function name, line range or search text.
# @arg $4 integer Optional. Most commits (default: SHELL_GIT_HISTORY_MAX).
# @arg $5 string Optional. `false` leaves merge commits out.
# @arg $6 string Optional. Branch to walk (default: every branch).
# @stdout The records. Empty when the scope has no history.
# @stderr Diagnostics.
# @exitcode 0 Success (an empty history is not an error).
# @exitcode 1 Git failed (unknown function, bad range ...).
# @example
#   shell::git::history::log function src/auth/login.go Login 100
#
shell::git::history::log() {
	local type="${1-}" file="${2-}" spec="${3-}" max="${4-}" merges="${5-}" branch="${6-}"
	local us=$'\037' line removed rev="" raw shas
	local -a args=()

	git rev-parse --verify -q HEAD >/dev/null 2>&1 || return "$RETURN_SUCCESS"

	if [ "$type" = "function" ]; then
		while IFS= read -r line; do args+=("$line"); done < <(shell::git::history::log::args "$type" "$file" "$spec" 1 true "" "$branch")
		if ! git "${args[@]}" >/dev/null 2>&1; then
			# Gone at HEAD? Start from the commit before the one that removed it.
			removed="$(git log -n 1 --format=%H "-S${spec}" ${branch:---all} -- "$file" 2>/dev/null)"
			rev="${removed:+${removed}^}"
			args=()
			while IFS= read -r line; do args+=("$line"); done < <(shell::git::history::log::args "$type" "$file" "$spec" 1 true "$rev" "$branch")
			if [ -z "$rev" ] || ! git "${args[@]}" >/dev/null 2>&1; then
				shell::logger::error "Function '$spec' was not found in '$file' (Git matches function headers per language; try --lines)"
				return "$RETURN_FAILURE"
			fi
			shell::logger::warn "Function '$spec' is no longer at HEAD: showing its history up to the commit before it was removed"
		fi
	fi

	args=()
	while IFS= read -r line; do args+=("$line"); done < <(shell::git::history::log::args "$type" "$file" "$spec" "$max" "$merges" "$rev" "$branch")
	raw="$(git "${args[@]}" 2>/dev/null)" || {
		shell::logger::error "git log failed for the $type scope"
		return "$RETURN_FAILURE"
	}
	[ -n "$raw" ] || return "$RETURN_SUCCESS"

	# Pass 1: parse. `-L` prints patches, everything else prints numstat lines.
	local mode="numstat"
	case "$type" in function | lines) mode="patch" ;; esac
	local records
	records="$(printf '%s\n' "$raw" | awk -v mode="$mode" -v scopefile="$file" '
		BEGIN { FS = "\037"; OFS = "\037"; inhdr = 0; have = 0 }
		function expand(p,   a, b, k, pre, rest, close_, mid, post) {
			NEWP = p; OLDP = ""
			if (p !~ / => /) return
			if (index(p, "{") > 0 && p ~ /\{.* => .*\}/) {
				pre = substr(p, 1, index(p, "{") - 1)
				rest = substr(p, index(p, "{") + 1)
				close_ = index(rest, "}")
				mid = substr(rest, 1, close_ - 1)
				post = substr(rest, close_ + 1)
				k = index(mid, " => ")
				a = substr(mid, 1, k - 1); b = substr(mid, k + 4)
				NEWP = pre b post; OLDP = pre a post
				gsub("//", "/", NEWP); gsub("//", "/", OLDP)
			} else {
				k = index(p, " => ")
				OLDP = substr(p, 1, k - 1); NEWP = substr(p, k + 4)
			}
		}
		function strip(s) { sub(/\t.*$/, "", s); sub(/^[ab]\//, "", s); return s }
		function flush(   merge, au, su, bo, mb, B, bj, i, par) {
			if (!have) return
			if (mode == "patch") {
				pth = (newp == "/dev/null" || newp == "") ? oldp : newp
				opth = (oldp != "" && oldp != "/dev/null" && oldp != pth) ? oldp : ""
			} else if (files != 1) {
				pth = scopefile; opth = ""
			}
			merge = (split(f[5], par, " ") > 1) ? 1 : 0
			au = f[3]; su = f[6]; bo = f[7]
			gsub(/\t/, " ", au); gsub(/\t/, " ", su)
			gsub(/\\/, "\\&\\&", bo); gsub(/\t/, " ", bo)
			mb = split(bo, B, "\n"); bj = ""
			for (i = 1; i <= mb; i++) bj = bj (i > 1 ? "\\n" : "") B[i]
			sub(/(\\n)+$/, "", bj)
			print f[1], f[2], au, f[4], adds, dels, files, merge, pth, opth, "", "", "", su, bj
			have = 0
		}
		function body_line(ln,   t) {
			if (mode == "numstat") {
				if (ln ~ /^[0-9-]+\t[0-9-]+\t/) {
					split(ln, t, "\t")
					adds += t[1] + 0; dels += t[2] + 0; files++
					expand(t[3]); pth = NEWP; opth = OLDP
				}
				return
			}
			if (ln ~ /^diff --git /) { inhunk = 0; files++; return }
			if (!inhunk && ln ~ /^--- /) { oldp = strip(substr(ln, 5)); return }
			if (!inhunk && ln ~ /^\+\+\+ /) { newp = strip(substr(ln, 5)); return }
			if (ln ~ /^@@/) { inhunk = 1; return }
			if (inhunk) {
				c = substr(ln, 1, 1)
				if (c == "+") adds++
				else if (c == "-") dels++
			}
		}
		function header_done(   n, k, tmp) {
			# 7 US characters close the header; the text after the 7th is the first body line.
			tmp = hdr; k = gsub(/\037/, "&", tmp)
			return (k >= 7)
		}
		{
			ln = $0
			if (substr(ln, 1, 1) == "\036") {
				flush()
				hdr = substr(ln, 2); inhdr = 1; have = 0
			} else if (inhdr) {
				hdr = hdr "\n" ln
			} else if (have) {
				body_line(ln)
				next
			} else next
			if (inhdr && header_done()) {
				# "[\037]" is a regex: with a one-character separator BWK awk (macOS) also splits at newlines.
				n = split(hdr, f, "[\037]")
				adds = 0; dels = 0; files = 0; pth = ""; opth = ""; inhunk = 0; oldp = ""; newp = ""
				inhdr = 0; have = 1
				if (f[8] != "") body_line(f[8])
			}
		}
		END { flush() }')"
	[ -n "$records" ] || return "$RETURN_SUCCESS"

	# Pass 2: whole-commit numbers, batched. Only the scopes that can touch other code need it.
	case "$type" in
	repo)
		printf '%s\n' "$records" | awk 'BEGIN{FS=OFS="\037"} {$11=$5; $12=$6; $13=$7; print}'
		;;
	search | regex)
		if [ -z "$file" ]; then
			printf '%s\n' "$records" | awk 'BEGIN{FS=OFS="\037"} {$11=$5; $12=$6; $13=$7; print}'
			return "$RETURN_SUCCESS"
		fi
		shas="$(printf '%s\n' "$records" | cut -d "$us" -f1)"
		awk 'BEGIN { FS = OFS = "\037" }
			FNR == NR { split($0, p, "\t"); F[p[1]] = p[2]; A[p[1]] = p[3]; D[p[1]] = p[4]; next }
			{ $11 = ($1 in A) ? A[$1] : $5; $12 = ($1 in D) ? D[$1] : $6; $13 = ($1 in F) ? F[$1] : $7; print }' \
			<(shell::git::history::log::whole "$shas") <(printf '%s\n' "$records")
		;;
	*)
		shas="$(printf '%s\n' "$records" | cut -d "$us" -f1)"
		awk 'BEGIN { FS = OFS = "\037" }
			FNR == NR { split($0, p, "\t"); F[p[1]] = p[2]; A[p[1]] = p[3]; D[p[1]] = p[4]; next }
			{ $11 = ($1 in A) ? A[$1] : $5; $12 = ($1 in D) ? D[$1] : $6; $13 = ($1 in F) ? F[$1] : $7; print }' \
			<(shell::git::history::log::whole "$shas") <(printf '%s\n' "$records")
		;;
	esac
	return "$RETURN_SUCCESS"
}

# @internal
# @description Whole-commit numbers for a list of commits, in one `git log --no-walk` call.
# @arg $1 string Full commit hashes, one per line.
# @stdout One line per commit, tab separated: hash, files, additions, deletions.
# @exitcode 0 Always.
# @example
#   shell::git::history::log::whole "$shas"
#
shell::git::history::log::whole() {
	printf '%s\n' "${1-}" | git log --no-walk=unsorted --stdin --numstat --format='%x1e%H' 2>/dev/null |
		awk 'BEGIN { FS = "\t"; RS = "\036" }
			$0 == "" { next }
			{ n = split($0, L, "\n"); h = L[1]; a = 0; d = 0; f = 0
			  for (i = 2; i <= n; i++) if (L[i] ~ /^[0-9-]+\t[0-9-]+\t/) { split(L[i], t, "\t"); a += t[1] + 0; d += t[2] + 0; f++ }
			  printf "%s\t%d\t%d\t%d\n", h, f, a, d }'
}

# @description Appends the branch of every commit record as field 16.
#   With a branch name every record gets that name. Without one (all branches walked) the
#   branch is the nearest branch tip that reaches the commit (`git name-rev`): local branches
#   first, then remote-tracking ones. Commits reachable from no branch get an empty field.
# @stdin Commit records (see shell::git::history::log).
# @arg $1 string Optional. Branch every commit belongs to.
# @stdout The records with the branch appended.
# @exitcode 0 Always.
# @example
#   shell::git::history::log repo "" "" 100 | shell::git::history::branches
#
shell::git::history::branches() {
	local fixed="${1-}" records hashes
	records="$(cat)"
	[ -n "$records" ] || return "$RETURN_SUCCESS"
	if [ -n "$fixed" ]; then
		printf '%s\n' "$records" | awk -v b="$fixed" 'BEGIN { FS = OFS = "\037" } { $16 = b; print }'
		return "$RETURN_SUCCESS"
	fi
	hashes="$(printf '%s\n' "$records" | cut -d $'\037' -f1)"
	awk 'BEGIN { FS = OFS = "\037" }
		function clean(n) { sub(/^remotes\//, "", n); sub(/[~^].*$/, "", n); return (n == "undefined" || n ~ /(^|\/)HEAD$/) ? "" : n }
		FILENAME == ARGV[1] { L[FNR] = clean($0); next }
		FILENAME == ARGV[2] { R[FNR] = clean($0); next }
		{ $16 = (L[FNR] != "" ? L[FNR] : R[FNR]); print }' \
		<(printf '%s\n' "$hashes" | git name-rev --name-only --annotate-stdin --refs='refs/heads/*' 2>/dev/null) \
		<(printf '%s\n' "$hashes" | git name-rev --name-only --annotate-stdin --refs='refs/remotes/*' 2>/dev/null) \
		<(printf '%s\n' "$records")
	return "$RETURN_SUCCESS"
}

# @description Calculates the statistics of a set of commit records for the dashboard.
#   Only what the records say is counted, so the numbers describe the selected scope: for a
#   function or a line range they are the lines of that function or range, not of the commit.
# @stdin Commit records (see shell::git::history::log).
# @stdout One line, tab separated: commits, additions, deletions, earliest date, latest date, authors.
#   Dates are `-` when there is no commit.
# @exitcode 0 Always.
# @example
#   shell::git::history::log file src/a.sh | shell::git::history::stats
#
shell::git::history::stats() {
	awk 'BEGIN { FS = "\037"; c = 0; a = 0; d = 0; lo = ""; hi = "" }
		NF < 8 { next }
		{ c++; a += $5; d += $6
		  if (lo == "" || $4 < lo) lo = $4
		  if (hi == "" || $4 > hi) hi = $4
		  if (!($3 in seen)) { seen[$3] = 1; au++ } }
		END { printf "%d\t%d\t%d\t%s\t%s\t%d\n", c, a, d, (lo == "" ? "-" : lo), (hi == "" ? "-" : hi), au }'
}

# @internal
# @description The terminal width to draw for: `--width`, else COLUMNS, else `tput cols`, else 80.
# @arg $1 integer Optional. Requested width.
# @stdout The width.
# @exitcode 0 Always.
# @example
#   w="$(shell::git::history::width)"
#
shell::git::history::width() {
	local w="${1-}"
	# A value under 20 is "unknown" (zsh sets COLUMNS=0 when there is no terminal).
	case "$w" in '' | *[!0-9]*) w="${COLUMNS-}" ;; esac
	case "$w" in '' | *[!0-9]*) w=0 ;; esac
	[ "$w" -lt 20 ] && w="$(tput cols 2>/dev/null)"
	case "$w" in '' | *[!0-9]*) w=0 ;; esac
	[ "$w" -lt 20 ] && w=80
	printf '%s\n' "$w"
}

# @internal
# @description Cut a string to a length, with an ellipsis. A path keeps its tail.
# @arg $1 string Text.
# @arg $2 integer Longest result.
# @arg $3 string Optional. `tail` keeps the end of the text (paths) instead of the start.
# @stdout The text, shortened when needed.
# @exitcode 0 Always.
# @example
#   shell::git::history::fit "$long_path" 30 tail
#
shell::git::history::fit() {
	local text="${1-}" max="${2:-0}" mode="${3-}"
	if [ "$max" -lt 2 ]; then
		printf '%s\n' ""
		return 0
	fi
	if [ "${#text}" -le "$max" ]; then
		printf '%s\n' "$text"
	elif [ "$mode" = "tail" ]; then
		printf '…%s\n' "${text: -$((max - 1))}"
	else
		printf '%s…\n' "${text:0:$((max - 1))}"
	fi
}

# @internal
# @description Print one row of the dashboard box: text padded to the inner width, then the border.
# @arg $1 integer Inner content width.
# @arg $2 string Border colour code.
# @arg $3 string Reset code.
# @arg $4 string Text colour code.
# @arg $5 string Plain text.
# @stdout The row.
# @exitcode 0 Always.
# @example
#   shell::git::history::dashboard::row 60 "" "" "" "Branch: main"
#
shell::git::history::dashboard::row() {
	local cw="${1:-0}" dim="${2-}" off="${3-}" paint="${4-}" text="${5-}" pad
	pad=$((cw - ${#text}))
	[ "$pad" -lt 0 ] && pad=0
	printf '%s│%s  %s%s%s%*s%s│%s\n' "$dim" "$off" "$paint" "$text" "$off" "$pad" '' "$dim" "$off"
}

# @description Renders the history dashboard: repository, scope and totals.
#   A rounded box on a terminal that is wide enough; a plain list when the width is under 44
#   columns. Long paths are shortened from the left. Colours only with `--color`.
# @option -w | --width Width to draw for (default: the terminal, at most SHELL_GIT_HISTORY_WIDTH).
# @option -c | --color Use ANSI colours.
# @option -h | --help Show this help message.
# @arg $1 string Repository name.
# @arg $2 string Branch.
# @arg $3 string Scope type.
# @arg $4 string File (may be empty).
# @arg $5 string Function name, line range or search text (may be empty).
# @arg $6 integer Commits.
# @arg $7 integer Additions.
# @arg $8 integer Deletions.
# @arg $9 string Optional. Earliest date.
# @arg $10 string Optional. Latest date.
# @stdout The dashboard.
# @exitcode 0 Success.
# @exitcode 2 Unknown option.
# @example
#   shell::git::history::dashboard -c my-project develop function src/a.go Login 18 248 132
#
shell::git::history::dashboard() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Render the history dashboard"
		shell::logger::usage "shell::git::history::dashboard [-w N] [-c] <repo> <branch> <type> <file> <spec> <commits> <adds> <dels> [first] [last]"
		shell::logger::option "-w, --width <n>" "Width to draw for"
		shell::logger::option "-c, --color" "Use ANSI colours"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::example "shell::git::history::dashboard -c my-project develop file src/a.sh '' 18 248 132"
		return "$RETURN_SUCCESS"
	fi

	local width="" color="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-w | --width) width="${2-}"; shift ;;
		-c | --color) color="true" ;;
		-*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done

	local repo="${1-}" branch="${2-}" type="${3-}" file="${4-}" spec="${5-}"
	local commits="${6:-0}" adds="${7:-0}" dels="${8:-0}" first="${9:--}" last="${10:--}"
	local esc=$'\033' bold="" cyan="" yellow="" green="" red="" dim="" off=""
	if [ "$color" = "true" ]; then
		bold="${esc}[1m" cyan="${esc}[36m" yellow="${esc}[33m" green="${esc}[32m" red="${esc}[31m" dim="${esc}[2m" off="${esc}[0m"
	fi

	width="$(shell::git::history::width "$width")"
	[ "$width" -gt "${SHELL_GIT_HISTORY_WIDTH:-72}" ] && width="${SHELL_GIT_HISTORY_WIDTH:-72}"

	local scope_label
	case "$type" in
	repo) scope_label="REPOSITORY" ;;
	file) scope_label="FILE" ;;
	function) scope_label="FUNCTION" ;;
	lines) scope_label="LINE RANGE" ;;
	search) scope_label="CODE SEARCH (-S)" ;;
	regex) scope_label="CODE SEARCH (-G)" ;;
	*) scope_label="$(printf '%s' "$type" | tr '[:lower:]' '[:upper:]')" ;;
	esac

	# Content lines, plain text first (so padding is exact); colour is applied around them.
	# An entry is `<style>:<text>` with style t (title), s (scope), d (dim) or n (none), so no
	# array is indexed (bash counts from 0, zsh from 1).
	local -a head_rows=() scope_rows=()
	local cw=$((width - 4)) detail_label="" detail=""
	[ "$cw" -lt 12 ] && cw=12
	head_rows+=("t:GIT CHRONICLE")
	head_rows+=("n:Repository: $(shell::git::history::fit "$repo" $((cw - 12)))")
	head_rows+=("n:Branch: $(shell::git::history::fit "$branch" $((cw - 8)))")

	scope_rows+=("s:SCOPE: $scope_label")
	[ -n "$file" ] && scope_rows+=("n:File: $(shell::git::history::fit "$file" $((cw - 6)) tail)")
	case "$type" in
	function) detail_label="Function" detail="${spec}()" ;;
	lines) detail_label="Lines" detail="$spec" ;;
	search | regex) detail_label="Pattern" detail="$spec" ;;
	esac
	if [ -n "$detail_label" ]; then
		scope_rows+=("n:${detail_label}: $(shell::git::history::fit "$detail" $((cw - ${#detail_label} - 2)))")
	fi
	[ "$first" != "-" ] && scope_rows+=("d:Span: ${first} → ${last}")

	local colw=$((cw / 3)) pad
	local h1 h2 h3 v1 v2 v3
	printf -v h1 '%-*s' "$colw" "COMMITS"
	printf -v h2 '%-*s' "$colw" "ADDITIONS"
	h3="DELETIONS"
	printf -v v1 '%-*s' "$colw" "$commits"
	printf -v v2 '%-*s' "$colw" "+${adds}"
	v3="-${dels}"

	local entry style text paint
	if [ "$width" -ge 44 ]; then
		local bar="" k=0
		while [ "$k" -lt $((width - 2)) ]; do
			bar="${bar}─"
			k=$((k + 1))
		done
		printf '%s╭%s╮%s\n' "$dim" "$bar" "$off"
		for entry in "${head_rows[@]}"; do
			style="${entry%%:*}" text="${entry#*:}"
			case "$style" in t) paint="${bold}${cyan}" ;; *) paint="" ;; esac
			shell::git::history::dashboard::row "$cw" "$dim" "$off" "$paint" "$text"
		done
		printf '%s├%s┤%s\n' "$dim" "$bar" "$off"
		for entry in "${scope_rows[@]}"; do
			style="${entry%%:*}" text="${entry#*:}"
			case "$style" in s) paint="${bold}${yellow}" ;; d) paint="$dim" ;; *) paint="" ;; esac
			shell::git::history::dashboard::row "$cw" "$dim" "$off" "$paint" "$text"
		done
		printf '%s├%s┤%s\n' "$dim" "$bar" "$off"
		pad=$((cw - colw * 2 - ${#h3}))
		[ "$pad" -lt 0 ] && pad=0
		printf '%s│%s  %s%s%s%s%s%*s%s│%s\n' "$dim" "$off" "$yellow" "$h1$h2$h3" "$off" "" "" "$pad" '' "$dim" "$off"
		pad=$((cw - colw * 2 - ${#v3}))
		[ "$pad" -lt 0 ] && pad=0
		printf '%s│%s  %s%s%s%s%s%s%s%s%s%*s%s│%s\n' "$dim" "$off" "$bold" "$v1" "$off" "$green" "$v2" "$off" "$red" "$v3" "$off" "$pad" '' "$dim" "$off"
		printf '%s╰%s╯%s\n' "$dim" "$bar" "$off"
	else
		# Narrow terminal: no box, one value per line.
		for entry in "${head_rows[@]}"; do
			style="${entry%%:*}" text="${entry#*:}"
			case "$style" in t) paint="${bold}${cyan}" ;; *) paint="" ;; esac
			printf '%s%s%s\n' "$paint" "$text" "$off"
		done
		for entry in "${scope_rows[@]}"; do
			style="${entry%%:*}" text="${entry#*:}"
			case "$style" in s) paint="${bold}${yellow}" ;; d) paint="$dim" ;; *) paint="" ;; esac
			printf '%s%s%s\n' "$paint" "$text" "$off"
		done
		printf '%sCOMMITS%s %s  %s+%s%s  %s-%s%s\n' "$yellow" "$off" "$commits" "$green" "$adds" "$off" "$red" "$dels" "$off"
	fi
}

# @description Renders commit records as a vertical timeline, or as fzf rows.
#   Default output: one block per commit, newest first:
#
#       ● 2026-10-28  a81f32c  Fix token expiration
#       │ alice       +18 -6
#       │
#
#   `●` is a commit and `◆` a merge; the last block has no connector. Additions are green,
#   deletions red, hashes cyan, dates and authors yellow. Subjects are cut to the width.
#   With `--rows` each commit is one fzf row instead, tab separated:
#   full hash, path, path before rename, summary, display line. The path columns are never
#   empty (`.` and the path), so they are safe in a pathspec; the summary says how much of the
#   commit belongs to the scope.
# @option -r | --rows Print fzf rows instead of the multi-line timeline.
# @option -c | --color Use ANSI colours.
# @option -w | --width Width to draw for (default: the terminal).
# @option -s | --selected Mark the commit with this (short or full) hash with `▶`.
# @option -t | --type Scope type, used to word the summary (default: file).
# @option -h | --help Show this help message.
# @stdin Commit records (see shell::git::history::log).
# @stdout The timeline or the rows.
# @exitcode 0 Success.
# @exitcode 2 Unknown option.
# @example
#   shell::git::history::log file src/a.sh | shell::git::history::timeline -c
#
shell::git::history::timeline() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Render commit records as a vertical timeline"
		shell::logger::usage "<records> | shell::git::history::timeline [-r] [-c] [-w N] [-s hash] [-t type]"
		shell::logger::option "-r, --rows" "Print fzf rows instead of the multi-line timeline"
		shell::logger::option "-c, --color" "Use ANSI colours"
		shell::logger::option "-w, --width <n>" "Width to draw for"
		shell::logger::option "-s, --selected <hash>" "Mark this commit"
		shell::logger::option "-t, --type <type>" "Scope type (wording of the summary)"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::example "shell::git::history::log file src/a.sh | shell::git::history::timeline -c"
		return "$RETURN_SUCCESS"
	fi

	local rows="false" color="false" width="" selected="" type="file"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-r | --rows) rows="true" ;;
		-c | --color) color="true" ;;
		-w | --width) width="${2-}"; shift ;;
		-s | --selected) selected="${2-}"; shift ;;
		-t | --type) type="${2-}"; shift ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done

	local esc=$'\033' tab=$'\t' us=$'\037'
	local cyan="" yellow="" green="" red="" dim="" bold="" off=""
	if [ "$color" = "true" ]; then
		cyan="${esc}[36m" yellow="${esc}[33m" green="${esc}[32m" red="${esc}[31m" dim="${esc}[2m" bold="${esc}[1m" off="${esc}[0m"
	fi
	width="$(shell::git::history::width "$width")"

	local full short author date adds dels files merge fpath opath ra rd rf subject body cbranch
	local glyph room subj summary track="${SHELL_GLYPH_TRACK:-│}" branch_tag="" cbranch
	# Read everything first so the last block can drop its connector.
	local all
	all="$(cat)"
	[ -n "$all" ] || return "$RETURN_SUCCESS"
	local total
	total="$(printf '%s\n' "$all" | wc -l | tr -d ' ')"
	local n=0
	while IFS="$us" read -r full short author date adds dels files merge fpath opath ra rd rf subject body cbranch; do
		[ -n "$full" ] || continue
		branch_tag=""
		[ -n "$cbranch" ] && branch_tag=" (${cbranch})"
		n=$((n + 1))
		glyph="${SHELL_GLYPH_COMMIT:-●}"
		[ "$merge" = "1" ] && glyph="${SHELL_GLYPH_MERGE:-◆}"
		if [ -n "$selected" ] && [ "$rows" != "true" ]; then
			case "$full" in "$selected"*) glyph="▶" ;; *) case "$short" in "$selected"*) glyph="▶" ;; esac ;; esac
		fi

		if [ "$rows" = "true" ]; then
			room=$((width * 45 / 100 - 36 - ${#author} - ${#branch_tag}))
			[ "$room" -lt 12 ] && room=12
			subj="$(shell::git::history::fit "$subject" "$room")"
			case "$type" in
			function | lines)
				summary="Selected ${type}: +${adds} -${dels}"
				if [ $((ra + rd)) -gt $((adds + dels)) ]; then
					summary="${summary} | rest of this commit: +$((ra - adds)) -$((rd - dels)) (${rf} file(s) in total) is outside the scope"
				fi
				;;
			*)
				if [ "$type" = "repo" ] || [ -z "$fpath" ]; then
					summary="Whole commit: ${rf} file(s) +${ra} -${rd}"
				else
					summary="This file: +${adds} -${dels}"
					if [ "${rf:-0}" -gt "${files:-0}" ]; then
						summary="${summary} | whole commit: ${rf} file(s) +${ra} -${rd}"
					fi
				fi
				;;
			esac
			[ "$merge" = "1" ] && summary="Merge commit | ${summary}"
			printf '%s%s%s%s%s%s%s%s%s' "$full" "$tab" "${fpath:-.}" "$tab" "${opath:-${fpath:-.}}" "$tab" "$summary" "$tab" ""
			printf '%s%s %s%s  %s%s%s%s  %s  %s%s%s  %s+%s%s %s-%s%s\n' \
				"${yellow}" "$glyph" "${off}" "$date" "${cyan}" "$short" "$branch_tag" "${off}" "$subj" "${dim}" "$author" "${off}" \
				"${green}" "$adds" "${off}" "${red}" "$dels" "${off}"
			continue
		fi

		room=$((width - 28 - ${#branch_tag}))
		[ "$room" -lt 10 ] && room=10
		subj="$(shell::git::history::fit "$subject" "$room")"
		printf '%s%s%s %s%s%s  %s%s%s%s  %s\n' "$bold" "$glyph" "$off" "$yellow" "$date" "$off" "$cyan" "$short" "$branch_tag" "$off" "$subj"
		if [ "$n" -lt "$total" ]; then
			printf '%s%s%s %s%s%s  %s+%s%s %s-%s%s' "$dim" "$track" "$off" "$yellow" "$(shell::git::history::fit "$author" 18)" "$off" "$green" "$adds" "$off" "$red" "$dels" "$off"
			[ "$merge" = "1" ] && printf '  %smerge%s' "$dim" "$off"
			printf '\n%s%s%s\n' "$dim" "$track" "$off"
		else
			printf '  %s%s%s  %s+%s%s %s-%s%s' "$yellow" "$(shell::git::history::fit "$author" 18)" "$off" "$green" "$adds" "$off" "$red" "$dels" "$off"
			[ "$merge" = "1" ] && printf '  %smerge%s' "$dim" "$off"
			printf '\n'
		fi
	done <<<"$all"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Pick the tool that colours a diff: `delta`, else `bat`, else Git's own colours.
# @stdout The name: delta, bat or git.
# @exitcode 0 Always.
# @example
#   hl="$(shell::git::history::highlighter)"
#
shell::git::history::highlighter() {
	if command -v delta >/dev/null 2>&1; then
		printf 'delta\n'
	elif command -v bat >/dev/null 2>&1; then
		printf 'bat\n'
	else
		printf 'git\n'
	fi
}

# @internal
# @description Show standard input in a pager that waits (`less -R`, or $PAGER), or just print it
#   when stdout is not a terminal. Short output must not vanish when fzf redraws.
# @stdin Text to show.
# @exitcode 0 Always.
# @example
#   git show HEAD | shell::git::history::page
#
shell::git::history::page() {
	if [ ! -t 1 ]; then
		cat
		return 0
	fi
	case "${PAGER-}" in
	'' | less | less\ *) less -R ;;
	*) "$PAGER" ;;
	esac
}

# @internal
# @description Print a commit's header, then the part of it that belongs to the scope.
#   Function and line scopes use `git log -L` limited to that commit, which shows only the
#   hunks of the selected lines. When Git cannot resolve the scope at that commit (the commit
#   removed the function), the whole file diff is shown with a note, never silence.
# @arg $1 string Repository root.
# @arg $2 string Scope type.
# @arg $3 string Function name, line range or search text.
# @arg $4 string Commit hash.
# @arg $5 string Path at that commit (`.` for all files).
# @arg $6 string Path before a rename.
# @arg $7 string Optional. `full` shows the whole commit instead of the scope.
# @arg $8 string Optional. Git colour mode (default: never).
# @stdout The header and the diff.
# @exitcode 0 Always.
# @example
#   shell::git::history::show "$root" function Login "$sha" src/a.go src/a.go
#
shell::git::history::show() {
	local root="${1-}" type="${2-}" spec="${3-}" sha="${4-}" fpath="${5:-.}" opath="${6-}" which="${7-}" color="${8:-never}"
	local larg

	git -C "$root" show -s "--color=$color" --format='%C(yellow)commit %H%Creset%nParents: %p%nAuthor:  %an <%ae>%nDate:    %ad%n%n    %s%n%n%b' --date=iso "$sha"
	printf '\n'
	if [ "$which" = "full" ]; then
		printf 'Whole commit\n\n'
		git -C "$root" show --format= -M "--color=$color" "$sha"
		return 0
	fi
	case "$type" in
	function | lines)
		if [ "$type" = "function" ]; then
			larg="$(shell::git::history::function::resolve "$fpath" "$spec")"
		else
			larg="${spec}:${fpath}"
		fi
		if [ "$type" = "lines" ] || ! git -C "$root" log -L "$larg" -n 1 --format= "--color=$color" "$sha" 2>/dev/null; then
			if [ "$type" = "lines" ]; then
				git -C "$root" log -L "$larg" -n 1 --format= "--color=$color" "$sha" 2>/dev/null && return 0
			fi
			printf 'Note: Git cannot resolve the selected %s at this commit (it may have been removed here); showing the whole file diff.\n\n' "$type"
			git -C "$root" show --format= -M "--color=$color" "$sha" -- "$fpath" "${opath:-$fpath}"
		fi
		;;
	*)
		printf 'Changes to %s\n\n' "$fpath"
		git -C "$root" show --format= -M "--color=$color" "$sha" -- "$fpath" "${opath:-$fpath}"
		;;
	esac
	return 0
}

# @description Inspects one commit of the history in a pager.
#   Shows the header (hashes, parents, author, date, message) and the diff that belongs to the
#   scope, or the whole commit with `full`; `blame` shows the lines of the scope as they were at
#   that commit. Read-only: it never changes the repository.
# @option -f | --full Show the complete commit, not only the scope.
# @option -b | --blame Show `git blame` of the scope at that commit.
# @option -h | --help Show this help message.
# @arg $1 string Repository root.
# @arg $2 string Scope type.
# @arg $3 string File (relative to the root).
# @arg $4 string Function name, line range or search text.
# @arg $5 string Commit hash.
# @arg $6 string Optional. Path at that commit.
# @arg $7 string Optional. Path before a rename.
# @stdout The commit, through a pager when stdout is a terminal.
# @exitcode 0 Success.
# @exitcode 1 No commit given.
# @exitcode 2 Unknown option.
# @example
#   shell::git::history::inspect "$root" function src/a.go Login "$sha" src/a.go
#
shell::git::history::inspect() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Inspect one commit of a history in a pager"
		shell::logger::usage "shell::git::history::inspect [-f] [-b] <root> <type> <file> <spec> <commit> [path] [old path]"
		shell::logger::option "-f, --full" "Show the complete commit, not only the scope"
		shell::logger::option "-b, --blame" "Show git blame of the scope at that commit"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::example "shell::git::history::inspect \"\$root\" function src/a.go Login \"\$sha\""
		return "$RETURN_SUCCESS"
	fi

	local which="" blame="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-f | --full) which="full" ;;
		-b | --blame) blame="true" ;;
		-*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done

	local root="${1-}" type="${2-}" file="${3-}" spec="${4-}" sha="${5-}" fpath="${6-}" opath="${7-}"
	if [ -z "$sha" ]; then
		shell::logger::error "A commit is required"
		return "$RETURN_FAILURE"
	fi
	[ -n "$fpath" ] || fpath="${file:-.}"

	local color="never" hl
	if [ -t 1 ]; then color="always"; fi
	hl="$(shell::git::history::highlighter)"

	if [ "$blame" = "true" ]; then
		local -a bargs=()
		case "$type" in
		function) bargs=(-L ":$(printf '%s' "$spec" | sed 's/:/[:]/g')") ;;
		lines) bargs=(-L "$spec") ;;
		esac
		if [ "$fpath" = "." ]; then
			shell::logger::warn "Blame needs a file: this commit changed several files"
			return "$RETURN_FAILURE"
		fi
		git -C "$root" blame "${bargs[@]}" "$sha" -- "$fpath" 2>&1 | shell::git::history::page
		return "$RETURN_SUCCESS"
	fi

	if [ "$color" = "always" ] && [ "$hl" = "bat" ]; then color="never"; fi
	case "$hl" in
	delta)
		[ -t 1 ] || hl="git"
		;;
	bat) [ -t 1 ] || hl="git" ;;
	esac
	case "$hl" in
	delta) shell::git::history::show "$root" "$type" "$spec" "$sha" "$fpath" "$opath" "$which" "$color" | delta --paging=never | shell::git::history::page ;;
	bat) shell::git::history::show "$root" "$type" "$spec" "$sha" "$fpath" "$opath" "$which" "$color" | bat -l diff --paging=never --style=plain --color=always | shell::git::history::page ;;
	*) shell::git::history::show "$root" "$type" "$spec" "$sha" "$fpath" "$opath" "$which" "$color" | shell::git::history::page ;;
	esac
	return "$RETURN_SUCCESS"
}

# @internal
# @description Build the fzf preview command of a history: commit header, scope summary, diff.
#   fzf runs it for the row under the cursor, filling `{1}` (hash), `{2}` (path), `{3}` (path
#   before a rename) and `{4}` (summary). It is plain `git`, so it works in fzf's own shell
#   where library functions do not exist; paths and names are quoted, nothing is evaluated.
# @arg $1 string Repository root.
# @arg $2 string Scope type.
# @arg $3 string Function name, line range or search text.
# @arg $4 string Git colour mode (`always` or `never`).
# @arg $5 string Highlighter: delta, bat or git.
# @stdout The command.
# @exitcode 0 Always.
# @example
#   preview="$(shell::git::history::preview::command "$root" function Login always delta)"
#
shell::git::history::preview::command() {
	local root="${1-}" type="${2-}" spec="${3-}" color="${4:-never}" hl="${5:-git}"
	local q_root head body larg pipe=""
	q_root="$(shell::git::commit::spec::quote "$root")"
	head="git -C ${q_root} show -s --color=${color} --date=iso --format='%C(yellow)commit %H%Creset%nParents: %p%nAuthor:  %an%nDate:    %ad%n%n    %s%n%n%b' {1}; printf '\\n%s\\n\\n' {4}"
	case "$hl" in
	delta) pipe=" | delta --paging=never" ;;
	bat) pipe=" | bat -l diff --paging=never --style=plain --color=always" ;;
	esac
	case "$type" in
	function)
		larg="$(shell::git::history::function::resolve "@@" "$spec")"
		larg="${larg%:@@}"
		body="{ git -C ${q_root} log -L $(shell::git::commit::spec::quote "$larg"):{2} -n 1 --format= --color=${color} {1} 2>/dev/null || git -C ${q_root} show --format= -M --color=${color} {1} -- {2} {3}; }"
		;;
	lines)
		body="{ git -C ${q_root} log -L $(shell::git::commit::spec::quote "$spec"):{2} -n 1 --format= --color=${color} {1} 2>/dev/null || git -C ${q_root} show --format= -M --color=${color} {1} -- {2} {3}; }"
		;;
	*)
		body="git -C ${q_root} show --format= -M --color=${color} {1} -- {2} {3}"
		;;
	esac
	printf "case {1} in '%s') echo 'Go back';; *) { %s; %s;}%s;; esac\n" "${SHELL_FZF_BACK_LABEL}" "$head" "$body" "$pipe"
}

# @internal
# @description Candidate function names of a file, for the interactive picker.
#   A line-based heuristic (`function`, `def`, `func`, `fn`, `sub` keywords and `name()` shell
#   style), read from the file at HEAD. It is a convenience: any name can still be typed.
# @arg $1 string Repository root.
# @arg $2 string File relative to the root.
# @stdout One name per line, in file order, without duplicates.
# @exitcode 0 Always.
# @example
#   shell::git::history::function::candidates "$root" src/a.sh
#
shell::git::history::function::candidates() {
	git -C "${1-}" show "HEAD:${2-}" 2>/dev/null | sed -nE \
		-e 's/^[[:space:]]*(export[[:space:]]+)?(async[[:space:]]+)?(pub[[:space:]]+)?(function|def|func|fn|sub)[[:space:]]+(\([^)]*\)[[:space:]]*)?([A-Za-z_][A-Za-z0-9_.$:-]*).*/\6/p' \
		-e 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_:.-]*)[[:space:]]*\(\)[[:space:]]*\{?.*/\1/p' | awk '!seen[$0]++'
}

# @description Picks what to explore, step by step: a file, then how to follow it.
#   Step 1 — pick a file (or the whole repository). Step 2 — pick the scope: file history,
#   function history (a function chosen from the file, or typed), line range, or a code search.
#   Every step has a "← Back" entry.
# @arg $1 string Repository root.
# @stdout One line, fields separated by US: type, file, spec.
# @exitcode 0 A scope was chosen.
# @exitcode 9 The user cancelled.
# @exitcode 11 The user picked "← Back" at the first step.
# @example
#   IFS=$'\037' read -r type file spec <<<"$(shell::git::history::pick "$root")"
#
shell::git::history::pick() {
	local root="${1-}" us=$'\037' back="$SHELL_FZF_BACK_LABEL"
	local whole="(whole repository)" file choice name spec
	while true; do
		file="$({
			printf '%s\n' "$whole"
			git -C "$root" ls-files 2>/dev/null
			printf '%s\n' "$back"
		} | shell::fzf::select --prompt="History of: " --preview="git -C $(shell::git::commit::spec::quote "$root") log -n 8 --format='%h %ad %an  %s' --date=short -- {} 2>/dev/null")" || return "$RETURN_CANCELLED"
		[ -n "$file" ] || return "$RETURN_CANCELLED"
		[ "$file" = "$back" ] && return "$RETURN_BACK"

		if [ "$file" = "$whole" ]; then
			choice="$(printf '%s\n' "All commits" "Search code (-S string)" "Search code (-G regex)" "$back" |
				shell::fzf::select --prompt="Repository: ")" || return "$RETURN_CANCELLED"
			case "$choice" in
			"All commits")
				printf 'repo%s%s%s\n' "$us" "$us" ""
				return "$RETURN_SUCCESS"
				;;
			"Search code (-S"*)
				spec="$(shell::ask::text "Text to search for?")" || return "$RETURN_CANCELLED"
				printf 'search%s%s%s%s\n' "$us" "$us" "$us" "$spec"
				return "$RETURN_SUCCESS"
				;;
			"Search code (-G"*)
				spec="$(shell::ask::text "Regular expression?")" || return "$RETURN_CANCELLED"
				printf 'regex%s%s%s%s\n' "$us" "$us" "$us" "$spec"
				return "$RETURN_SUCCESS"
				;;
			*) continue ;;
			esac
		fi

		choice="$(printf '%s\n' "File history" "Function history" "Line range" "Search code (-S string)" "Search code (-G regex)" "$back" |
			shell::fzf::select --prompt="${file}: ")" || return "$RETURN_CANCELLED"
		case "$choice" in
		"File history")
			printf 'file%s%s%s\n' "$us" "$file" "$us"
			return "$RETURN_SUCCESS"
			;;
		"Function history")
			name="$({
				shell::git::history::function::candidates "$root" "$file"
				printf '%s\n' "(type a name)" "$back"
			} | shell::fzf::select --prompt="Function: ")" || return "$RETURN_CANCELLED"
			[ "$name" = "$back" ] && continue
			if [ "$name" = "(type a name)" ]; then
				name="$(shell::ask::text "Function name?")" || return "$RETURN_CANCELLED"
			fi
			printf 'function%s%s%s%s\n' "$us" "$file" "$us" "$name"
			return "$RETURN_SUCCESS"
			;;
		"Line range")
			spec="$(shell::ask::text "Line range (START,END)?")" || return "$RETURN_CANCELLED"
			printf 'lines%s%s%s%s\n' "$us" "$file" "$us" "$spec"
			return "$RETURN_SUCCESS"
			;;
		"Search code (-S"*)
			spec="$(shell::ask::text "Text to search for?")" || return "$RETURN_CANCELLED"
			printf 'search%s%s%s%s\n' "$us" "$file" "$us" "$spec"
			return "$RETURN_SUCCESS"
			;;
		"Search code (-G"*)
			spec="$(shell::ask::text "Regular expression?")" || return "$RETURN_CANCELLED"
			printf 'regex%s%s%s%s\n' "$us" "$file" "$us" "$spec"
			return "$RETURN_SUCCESS"
			;;
		*) continue ;;
		esac
	done
}

# @description Explores the history of a file, a function, a line range or a piece of code.
#
#   Opens an fzf viewer: the left side is the commit timeline (newest first, `●` commit, `◆`
#   merge, additions in green, deletions in red), the right side is a live preview of the
#   commit under the cursor, and the header is a dashboard with the repository, the branch,
#   the scope and the totals. Type to filter by message, author, date or hash.
#
#   Scopes (they are different things in Git, and are tracked differently):
#
#   - `<file>`: `git log --follow`, across renames.
#   - `--function <name>`: `git log -L :<name>:<file>`. Only the hunks of that function are
#     shown and counted. Git finds a function by language patterns, it does not parse code.
#   - `--lines <start,end>`: `git log -L`, the range follows the lines through the history.
#   - `--search <text>` (`-S`): commits that changed how many times the text occurs.
#   - `--regex <re>` (`-G`): commits whose diff contains a line matching the expression.
#   - no scope: every commit of the repository.
#
#   Keys: Up/Down move, Enter inspect (scoped diff in a pager), Ctrl-F the whole commit,
#   Ctrl-B git blame of the scope at that commit, Ctrl-Y copy the hash, Ctrl-O open it on
#   GitHub/GitLab/Bitbucket, Ctrl-D / Ctrl-U scroll the preview, ESC quit. The repository is
#   never modified.
# @option -f | --function Follow this function (needs a file).
# @option -L | --lines Follow this line range, START,END (needs a file).
# @option -S | --search Commits that added or removed this text (file optional).
# @option -G | --regex Commits whose diff matches this regular expression (file optional).
# @option -i | --interactive Pick the file and the scope in fzf first.
# @option -m | --max Most commits to load (default: SHELL_GIT_HISTORY_MAX, 500).
# @option --no-merges Leave merge commits out.
# @option -p | --print Print the dashboard and the timeline and exit (no fzf, good for pipes).
# @option -n | --dry-run Print the git command instead of running it.
# @option -h | --help Show this help message.
# @arg $1 string Optional. File to explore (relative to the current directory, or absolute).
# @stdout With --print: the dashboard and the timeline.
# @exitcode 0 Success, or the user left with ESC.
# @exitcode 1 Not a repository, unknown file, invalid scope, or Git failed.
# @exitcode 2 Invalid usage.
# @exitcode 11 The user picked "← Back".
# @see shell::git::history::log
# @example
#   shell::git::history::fzf src/auth/login.go
#   shell::git::history::fzf --function Login src/auth/login.go
#   shell::git::history::fzf --lines 40,80 src/auth/login.go
#   shell::git::history::fzf --search "refreshToken"
#   shell::git::history::fzf --regex "TODO|FIXME" src/auth/login.go
#   shell::git::history::fzf --interactive
#   shell::git::history::fzf --print --function Login src/auth/login.go
#
shell::git::history::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Explore the history of a file, function, line range or code"
		shell::logger::usage "shell::git::history::fzf [-f name | -L start,end | -S text | -G regex] [-b branch] [-i] [-m N] [--no-merges] [-p] [-n] [-h] [file]"
		shell::logger::option "-f, --function <name>" "Follow a function (git log -L)"
		shell::logger::option "-L, --lines <start,end>" "Follow a line range (git log -L)"
		shell::logger::option "-S, --search <text>" "Commits that added or removed the text (git log -S)"
		shell::logger::option "-G, --regex <re>" "Commits whose diff matches the expression (git log -G)"
		shell::logger::option "-b, --branch <name>" "Only this branch (default: all branches)"
		shell::logger::option "-i, --interactive" "Pick the file and the scope in fzf first"
		shell::logger::option "-m, --max <n>" "Most commits to load (default: 500)"
		shell::logger::option "--no-merges" "Leave merge commits out"
		shell::logger::option "-p, --print" "Print the dashboard and timeline, no fzf"
		shell::logger::option "-n, --dry-run" "Print the git command instead of running it"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::item "Enter" "Inspect the commit (scoped diff, in a pager)"
		shell::logger::item "Ctrl-F" "The whole commit"
		shell::logger::item "Ctrl-B" "git blame of the scope at that commit"
		shell::logger::item "Ctrl-Y" "Copy the commit hash"
		shell::logger::item "Ctrl-O" "Open the commit on GitHub / GitLab / Bitbucket"
		shell::logger::item "Ctrl-D / Ctrl-U" "Scroll the preview"
		shell::logger::item "ESC" "Quit"
		shell::logger::example "shell::git::history::fzf src/auth/login.go"
		shell::logger::example "shell::git::history::fzf --function Login src/auth/login.go"
		shell::logger::example "shell::git::history::fzf --lines 40,80 src/auth/login.go"
		shell::logger::example "shell::git::history::fzf --search refreshToken"
		shell::logger::example "shell::git::history::fzf --interactive"
		return "$RETURN_SUCCESS"
	fi

	local type="" spec="" file_arg="" branch_arg="" interactive="false" print_only="false" dry_run="false"
	local max="${SHELL_GIT_HISTORY_MAX:-500}" merges="true"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-f | --function | -L | --lines | -S | --search | -G | --regex)
			if [ -n "$type" ]; then
				shell::logger::error "Choose one of --function, --lines, --search, --regex"
				return "$RETURN_INVALID"
			fi
			if [ "$#" -lt 2 ]; then
				shell::logger::error "$1 needs a value"
				return "$RETURN_INVALID"
			fi
			case "$1" in
			-f | --function) type="function" ;;
			-L | --lines) type="lines" ;;
			-S | --search) type="search" ;;
			-G | --regex) type="regex" ;;
			esac
			spec="$2"
			shift
			;;
		-b | --branch)
			branch_arg="${2-}"
			if [ -z "$branch_arg" ]; then
				shell::logger::error "--branch needs a branch name"
				return "$RETURN_INVALID"
			fi
			shift
			;;
		-i | --interactive) interactive="true" ;;
		-m | --max)
			max="${2-}"
			case "$max" in '' | *[!0-9]* | 0)
				shell::logger::error "--max needs a positive number"
				return "$RETURN_INVALID"
				;;
			esac
			shift
			;;
		--no-merges) merges="false" ;;
		-p | --print) print_only="true" ;;
		-n | --dry-run) dry_run="true" ;;
		-*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*)
			if [ -n "$file_arg" ]; then
				shell::logger::error "Only one file can be explored at a time"
				return "$RETURN_INVALID"
			fi
			file_arg="$1"
			;;
		esac
		shift
	done

	shell::dependency::git::ensure || return "$RETURN_FAILURE"

	local us=$'\037' tab=$'\t' ctx root name branch rel
	ctx="$(shell::git::history::context "$file_arg")" || return "$RETURN_FAILURE"
	IFS="$us" read -r root name branch rel <<<"$ctx"
	if [ -n "$branch_arg" ]; then
		if ! git rev-parse --verify -q "${branch_arg}^{commit}" >/dev/null 2>&1; then
			shell::logger::error "Branch '${branch_arg}' does not exist"
			return "$RETURN_FAILURE"
		fi
		branch="$branch_arg"
	else
		branch="all branches"
	fi

	local descriptor file
	if [ "$interactive" = "true" ]; then
		if [ "$print_only" = "true" ] || [ "$dry_run" = "true" ]; then
			shell::logger::error "--interactive cannot be combined with --print or --dry-run"
			return "$RETURN_INVALID"
		fi
		descriptor="$(shell::git::history::pick "$root")" || return "$?"
		IFS="$us" read -r type file spec <<<"$descriptor"
		rel="$file"
	elif [ -z "$type" ]; then
		if [ -n "$rel" ]; then type="file"; else type="repo"; fi
	fi

	descriptor="$(shell::git::history::scope "$type" "$rel" "$spec")" || return "$RETURN_FAILURE"
	IFS="$us" read -r type rel spec <<<"$descriptor"

	if [ "$dry_run" = "true" ]; then
		local -a dargs=()
		local dline dcmd="git -C $(shell::git::commit::spec::quote "$root")"
		while IFS= read -r dline; do dargs+=("$dline"); done < <(shell::git::history::log::args "$type" "$rel" "$spec" "$max" "$merges" "" "$branch_arg")
		for dline in "${dargs[@]}"; do dcmd="${dcmd} $(shell::git::commit::spec::quote "$dline")"; done
		shell::logger::command_clip "$dcmd"
		return "$RETURN_SUCCESS"
	fi

	# Retrieve once; everything below only reads the records.
	local records
	records="$(shell::git::history::log "$type" "$rel" "$spec" "$max" "$merges" "$branch_arg")" || return "$RETURN_FAILURE"
	records="$(printf '%s\n' "$records" | shell::git::history::branches "$branch_arg")"

	local commits=0 adds=0 dels=0 first="-" last="-"
	if [ -n "$records" ]; then
		IFS="$tab" read -r commits adds dels first last _ <<<"$(printf '%s\n' "$records" | shell::git::history::stats)"
	fi

	local use_color="false"
	shell::console::detect_colors
	if [ -t 1 ] && [ "${_SHELL_CONSOLE_COLORS:-0}" -ge 8 ]; then use_color="true"; fi
	local -a dash_flags=()
	[ "$use_color" = "true" ] && dash_flags+=(-c)

	if [ "$print_only" = "true" ]; then
		shell::git::history::dashboard "${dash_flags[@]}" "$name" "$branch" "$type" "$rel" "$spec" "$commits" "$adds" "$dels" "$first" "$last"
		if [ -z "$records" ]; then
			printf '\nNo commits found for this scope.\n'
		else
			printf '\n'
			printf '%s\n' "$records" | shell::git::history::timeline "${dash_flags[@]}" -t "$type"
		fi
		return "$RETURN_SUCCESS"
	fi

	if [ -z "$records" ]; then
		shell::git::history::dashboard "${dash_flags[@]}" "$name" "$branch" "$type" "$rel" "$spec" 0 0 0
		shell::logger::warn "No commits found for this scope"
		return "$RETURN_SUCCESS"
	fi

	# Interaction.
	local hl color_flag="never"
	hl="$(shell::git::history::highlighter)"
	if [ "$use_color" = "true" ] && [ "$hl" != "bat" ]; then color_flag="always"; fi

	local dashboard shortcuts header rows preview
	dashboard="$(shell::git::history::dashboard "${dash_flags[@]}" "$name" "$branch" "$type" "$rel" "$spec" "$commits" "$adds" "$dels" "$first" "$last")"
	shortcuts="Enter inspect  ^F whole commit  ^B blame  ^Y copy hash  ^O open on web  ^D/^U scroll  ESC quit"
	header="${dashboard}"$'\n'"${shortcuts}"
	rows="$(printf '%s\n' "$records" | shell::git::history::timeline -r "${dash_flags[@]}" -t "$type")"
	rows="${rows}"$'\n'"${SHELL_FZF_BACK_LABEL}${tab}:back${tab}${tab}${tab}"
	preview="$(shell::git::history::preview::command "$root" "$type" "$spec" "$color_flag" "$hl")"

	local out key sel full fpath opath
	while true; do
		out="$(printf '%s\n' "$rows" | shell::fzf::select \
			--height=100% \
			--prompt="History: " \
			--header="$header" \
			--header-first \
			--delimiter="$tab" \
			--with-nth=5 \
			--no-sort \
			--tiebreak=index \
			--expect=ctrl-y,ctrl-o,ctrl-f,ctrl-b \
			--preview="$preview" \
			--preview-window="right:55%:wrap" \
			--bind="ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up")" || break
		[ -n "$out" ] || break

		# --expect: first line is the key that ended the selection (empty for Enter).
		key="${out%%$'\n'*}"
		case "$out" in *$'\n'*) sel="${out#*$'\n'}" ;; *) sel="$out" key="" ;; esac
		[ -n "$sel" ] || break
		full="${sel%%$tab*}"
		if [ "$full" = "$SHELL_FZF_BACK_LABEL" ]; then
			shell::logger::info "Back — left the history explorer"
			return "$RETURN_BACK"
		fi
		fpath="$(printf '%s' "$sel" | cut -f2)"
		opath="$(printf '%s' "$sel" | cut -f3)"

		case "$key" in
		ctrl-y)
			shell::clipboard::copy "$full" && shell::logger::info "Copied ${full}"
			[ -t 0 ] && sleep 1
			;;
		ctrl-o)
			shell::git::open::browser "$full" || shell::logger::warn "Could not open the commit on the web"
			[ -t 0 ] && sleep 1
			;;
		ctrl-f) shell::git::history::inspect --full "$root" "$type" "$rel" "$spec" "$full" "$fpath" "$opath" ;;
		ctrl-b) shell::git::history::inspect --blame "$root" "$type" "$rel" "$spec" "$full" "$fpath" "$opath" ;;
		*) shell::git::history::inspect "$root" "$type" "$rel" "$spec" "$full" "$fpath" "$opath" ;;
		esac
	done

	return "$RETURN_SUCCESS"
}
