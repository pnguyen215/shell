#!/usr/bin/env bash
# @file lib/prompt_skills.sh
# @brief Prompt Skills Sync: download prompts from a central GitHub repository into the prompt stores.
# @description
#   The `skills` repository (SHELL_PROMPT_SKILLS_REPO, directory SHELL_PROMPT_SKILLS_PATH, branch SHELL_PROMPT_SKILLS_BRANCH)
#   is the source of truth. Its `*.md` files are listed, viewed, copied, installed, updated and removed here; the installed
#   prompts are ordinary files of the GLOBAL store (default) or of the PERSONAL (per-project `local`) store, so every
#   `shell::prompt::*` function keeps working on them.
#
#       <store>/<slug>.md          the installed prompt (the normal prompt file format)
#       <store>/.skills.lock       provenance, TSV, mode 600:
#                                  slug  repo  branch  remote_path  remote_blob_sha  installed_utc  local_checksum
#
#   Network: ONE call to the Trees API lists the branch (cached with a TTL and an ETag), files come from
#   raw.githubusercontent.com, and more than SHELL_PROMPT_SKILLS_BULK_MIN missing files are fetched as ONE tarball. All of it
#   goes through scripts/prompt_skills_transport.sh (also used by the fzf preview, where no shell::* function exists).
#   Content is cached by git blob SHA, so a cached file is valid by construction and its integrity is verified on download.
#   Tests and offline use: SHELL_PROMPT_SKILLS_LOCAL_DIR=<dir> reads `<dir>/<branch>/<path>/**.md` instead of the network.
#
#   Safety: everything downloaded is data (never sourced, evaluated or executed), only `[A-Za-z0-9._/-]` paths ending in `.md`
#   without `..` are accepted, the token travels only in a private header file, files are 600 and directories 700, and
#   every write is a temp file + mv. Interactive menus live in lib/prompt_skills_fzf.sh.

# @internal
# @description Reset the per-call state to the defaults (repo, branch, flags). The `--repo`, `--branch` and `--refresh`
#   flags then override it.
# @exitcode 0 Always.
# @example
#   _shell::prompt::skills::reset
#
_shell::prompt::skills::reset() {
	_SK_REPO="$SHELL_PROMPT_SKILLS_REPO"
	_SK_BRANCH="$SHELL_PROMPT_SKILLS_BRANCH"
	_SK_REFRESH="false"
	_SK_EXPLICIT="false"
	_SK_SHIFT=0
	return "$RETURN_SUCCESS"
}

# @internal
# @description Tell whether a value is a valid `owner/repo`.
# @arg $1 string The candidate.
# @exitcode 0 Valid.
# @exitcode 1 Invalid.
# @example
#   _shell::prompt::skills::valid_repo "pnguyen215/skills"
#
_shell::prompt::skills::valid_repo() {
	case "${1-}" in
	'' | *[!A-Za-z0-9._/-]* | /* | */ | */*/* | *..* | -*) return "$RETURN_FAILURE" ;;
	*/*) return "$RETURN_SUCCESS" ;;
	esac
	return "$RETURN_FAILURE"
}

# @internal
# @description Tell whether a value is a valid branch name: `[A-Za-z0-9._/-]`, no `..`, no leading `-` or `/`, no
#   whitespace, no empty path component, at most 200 characters.
# @arg $1 string The candidate.
# @exitcode 0 Valid.
# @exitcode 1 Invalid.
# @example
#   _shell::prompt::skills::valid_branch "feature/x"
#
_shell::prompt::skills::valid_branch() {
	case "${1-}" in
	'' | -* | /* | */ | *..* | *//* | *.lock | *[!A-Za-z0-9._/-]*) return "$RETURN_FAILURE" ;;
	esac
	[ "${#1}" -le 200 ]
}

# @internal
# @description Consume one common option (`--repo <owner/repo>`, `--branch <name>`, `--refresh`) of the caller's loop.
#   The number of arguments used is left in `_SK_SHIFT`.
# @arg $@ string The remaining arguments; the first one is the option.
# @exitcode 0 Consumed.
# @exitcode 2 The value is missing or invalid (logged).
# @example
#   --repo | --branch | --refresh) _shell::prompt::skills::opt "$@" || return $?; shift "$_SK_SHIFT"; continue ;;
#
_shell::prompt::skills::opt() {
	case "${1-}" in
	--refresh)
		_SK_REFRESH="true"
		_SK_SHIFT=1
		return "$RETURN_SUCCESS"
		;;
	--repo | --branch)
		if [ "$#" -lt 2 ]; then
			shell::logger::error "Option $1 requires a value"
			return "$RETURN_INVALID"
		fi
		if [ "$1" = "--repo" ]; then
			_shell::prompt::skills::valid_repo "$2" || {
				shell::logger::error "Invalid repository '$2': expected owner/repo."
				return "$RETURN_INVALID"
			}
			_SK_REPO="$2"
		else
			_shell::prompt::skills::valid_branch "$2" || {
				shell::logger::error "Invalid branch '$2': use letters, digits, '.', '_', '-' and '/' (no '..', no leading '-', no spaces)."
				return "$RETURN_INVALID"
			}
			_SK_BRANCH="$2"
			_SK_EXPLICIT="true"
		fi
		_SK_SHIFT=2
		return "$RETURN_SUCCESS"
		;;
	esac
	return "$RETURN_INVALID"
}

# @internal
# @description Parse the options shared by the public functions into `_SK_*` globals: `_SK_DRY`, `_SK_SCOPE`
#   (`global`, `local`, `all` or empty), `_SK_FORCE`, `_SK_YES`, `_SK_AS`, `_SK_TAG`, `_SK_FILTER`, `_SK_NAMES` (array),
#   plus the common `--repo`, `--branch` and `--refresh`. Only the options named in the first argument are accepted.
# @arg $1 string Space-separated option groups allowed: `n scope all force yes as tag filter`.
# @arg $@ string The user's arguments.
# @exitcode 0 Parsed.
# @exitcode 2 Unknown option or bad value (logged).
# @example
#   _shell::prompt::skills::parse "n scope force as" "$@" || return $?
#
_shell::prompt::skills::parse() {
	local allowed=" ${1-} " nm
	shift
	_shell::prompt::skills::reset
	_SK_DRY="false"
	_SK_SCOPE=""
	_SK_FORCE="false"
	_SK_YES="false"
	_SK_AS=""
	_SK_TAG=""
	_SK_FILTER=""
	_SK_NAMES=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) nm="n" ;;
		--global | --personal | --project | --local) nm="scope" ;;
		--all-scopes) nm="all" ;;
		--force) nm="force" ;;
		-y | --yes) nm="yes" ;;
		--as) nm="as" ;;
		--tag) nm="tag" ;;
		--installed | --available | --outdated) nm="filter" ;;
		--repo | --branch | --refresh) nm="common" ;;
		--)
			shift
			while [ "$#" -gt 0 ]; do
				_SK_NAMES+=("$1")
				shift
			done
			break
			;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) nm="" ;;
		esac
		if [ -n "$nm" ] && [ "$nm" != "common" ]; then
			case "$allowed" in
			*" $nm "*) ;;
			*)
				shell::logger::error "Unknown option: $1"
				return "$RETURN_INVALID"
				;;
			esac
		fi
		case "$1" in
		-n | --dry-run) _SK_DRY="true" ;;
		--global) _SK_SCOPE="global" ;;
		--personal | --project | --local) _SK_SCOPE="local" ;;
		--all-scopes) _SK_SCOPE="all" ;;
		--force) _SK_FORCE="true" ;;
		-y | --yes) _SK_YES="true" ;;
		--as | --tag)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			if [ "$1" = "--as" ]; then _SK_AS="$2"; else _SK_TAG="$(_shell::prompt::norm_tags "$2")"; fi
			shift
			;;
		--installed) _SK_FILTER="installed" ;;
		--available) _SK_FILTER="available" ;;
		--outdated) _SK_FILTER="outdated" ;;
		--repo | --branch | --refresh)
			_shell::prompt::skills::opt "$@" || return $?
			shift "$((_SK_SHIFT - 1))"
			;;
		*) _SK_NAMES+=("$1") ;;
		esac
		shift
	done
	return "$RETURN_SUCCESS"
}

# @internal
# @description Print the cache directory of the current repo and branch:
#   `${XDG_CACHE_HOME:-$HOME/.cache}/shell/skills/<owner>__<repo>/<branch>` (a `/` in the branch becomes `%2F`).
# @stdout The directory.
# @exitcode 0 Always.
# @example
#   cdir="$(_shell::prompt::skills::cache_dir)"
#
_shell::prompt::skills::cache_dir() {
	printf '%s/shell/skills/%s__%s/%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}" "${_SK_REPO%%/*}" "${_SK_REPO#*/}" "$(printf '%s' "$_SK_BRANCH" | sed 's#/#%2F#g')"
}

# @internal
# @description Export the settings of the transport script in the current (sub)shell.
# @exitcode 0 Always.
# @example
#   ( _shell::prompt::skills::txexport; sh "$script" index "$out" )
#
_shell::prompt::skills::txexport() {
	local cdir
	cdir="$(_shell::prompt::skills::cache_dir)"
	export SKILLS_REPO="$_SK_REPO" SKILLS_BRANCH="$_SK_BRANCH" SKILLS_PATH="$SHELL_PROMPT_SKILLS_PATH"
	export SKILLS_CACHE="$cdir" SKILLS_BLOBS="$cdir/blobs" SKILLS_LOCAL_DIR="${SHELL_PROMPT_SKILLS_LOCAL_DIR-}" SKILLS_LOG="$cdir/requests.log"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Run the transport script (the only code that touches the network or the fixture directory).
# @arg $@ string The transport command and its arguments (`index`, `file`, `archive`, `branches`).
# @exitcode 0 Done.
# @exitcode N The script's exit code (10 not modified, 44 not found, 45 rate limited, 46 truncated, 3 no downloader).
# @example
#   _shell::prompt::skills::tx branches
#
_shell::prompt::skills::tx() {
	(
		_shell::prompt::skills::txexport
		sh "$SHELL_DIR/scripts/prompt_skills_transport.sh" "$@"
	)
}

# @internal
# @description Fetch the index of the branch into a file (`path<TAB>blob_sha<TAB>size`).
# @arg $1 string The output file.
# @exitcode 0 Written. 10 Not modified. 44 Not found. 45 Rate limited. 46 Truncated. Other: failure.
# @example
#   _shell::prompt::skills::fetch_index "$cdir/index.new"
#
_shell::prompt::skills::fetch_index() {
	_shell::prompt::skills::tx index "${1-}"
}

# @internal
# @description Download one file (verified against its blob sha) into the cache.
# @arg $1 string The remote path.
# @arg $2 string The blob sha announced by the index.
# @exitcode 0 Cached.
# @exitcode 1 Failed (nothing partial is left).
# @example
#   _shell::prompt::skills::fetch_file prompts/a.md 0123abc...
#
_shell::prompt::skills::fetch_file() {
	_shell::prompt::skills::tx file "${1-}" "${2-}"
}

# @internal
# @description Download the whole branch as ONE tarball and cache every prompt in it; optionally rebuild the index.
# @arg $1 string Optional. A file for the index, or `-` (default) for none.
# @exitcode 0 Cached.
# @exitcode 1 Failed.
# @example
#   _shell::prompt::skills::fetch_archive -
#
_shell::prompt::skills::fetch_archive() {
	_shell::prompt::skills::tx archive "${1:--}"
}

# @internal
# @description Make sure a fresh index of the current repo/branch is in the cache. A fresh one (younger than the TTL) is
#   used as it is; an older one is revalidated with a conditional request (a 304 costs no rate-limit quota). A truncated
#   or rate-limited API answer falls back to the tarball; a network failure falls back to the stale cache with a warning.
#   An unknown branch is an error, never a silent fallback to another branch.
# @exitcode 0 `index.tsv` is ready in the cache directory.
# @exitcode 1 No index and no network.
# @exitcode 3 The branch (or repository) was not found.
# @example
#   _shell::prompt::skills::index || return $?
#
_shell::prompt::skills::index() {
	local cdir idx fetched now rc=0
	cdir="$(_shell::prompt::skills::cache_dir)"
	idx="$cdir/index.tsv"
	(umask 077 && mkdir -p "$cdir/blobs") || {
		shell::logger::error "Could not create the cache directory '$cdir'."
		return "$RETURN_FAILURE"
	}
	now="$(date +%s)"
	if [ -f "$idx" ] && [ "$_SK_REFRESH" != "true" ] && [ -z "${SHELL_PROMPT_SKILLS_LOCAL_DIR-}" ]; then
		fetched="$(cat "$cdir/index.fetched" 2>/dev/null)"
		case "$fetched" in '' | *[!0-9]*) fetched=0 ;; esac
		if [ "$((now - fetched))" -lt "$SHELL_PROMPT_SKILLS_CACHE_TTL" ]; then
			return "$RETURN_SUCCESS"
		fi
	fi
	[ -f "$idx" ] || rm -f "$cdir/index.etag"
	_shell::prompt::skills::fetch_index "$cdir/index.new" || rc=$?
	case "$rc" in
	0) ;;
	10) rc=0 ;;
	44)
		shell::logger::error "Branch '${_SK_BRANCH}' not found in ${_SK_REPO} (list them with: shell::prompt::skills::branches)."
		return "$RETURN_NOT_FOUND"
		;;
	45 | 46)
		shell::logger::warn "The GitHub API answer is $([ "$rc" = 45 ] && echo rate-limited || echo truncated) - using the tarball instead"
		rc=0
		_shell::prompt::skills::fetch_archive "$cdir/index.new" || rc=$?
		if [ "$rc" -eq 44 ]; then
			shell::logger::error "Branch '${_SK_BRANCH}' not found in ${_SK_REPO} (list them with: shell::prompt::skills::branches)."
			return "$RETURN_NOT_FOUND"
		fi
		;;
	3)
		shell::logger::error "Neither curl nor wget is installed."
		return "$RETURN_NOT_FOUND"
		;;
	esac
	if [ "$rc" -ne 0 ]; then
		rm -f "$cdir/index.new"
		if [ -f "$idx" ]; then
			shell::logger::warn "Could not reach GitHub - using the cached index of ${_SK_REPO}@${_SK_BRANCH}"
			return "$RETURN_SUCCESS"
		fi
		shell::logger::error "Could not download the index of ${_SK_REPO}@${_SK_BRANCH} (network error or rate limit)."
		return "$RETURN_FAILURE"
	fi
	if [ -f "$cdir/index.new" ]; then
		mv -f "$cdir/index.new" "$idx" || return "$RETURN_FAILURE"
	fi
	printf '%s\n' "$now" >"$cdir/index.fetched"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Turn the cached index into prompt entries: `slug<TAB>path<TAB>sha<TAB>size<TAB>tags`, sorted by slug.
#   The slug is the file name when it already is a valid slug, otherwise it is slugified. Directories under the prompt
#   path become tags; on a slug collision between different directories the later ones get the directory as a prefix.
# @stdout One line per prompt.
# @exitcode 0 Always.
# @example
#   _shell::prompt::skills::entries | cut -f1
#
_shell::prompt::skills::entries() {
	local idx
	idx="$(_shell::prompt::skills::cache_dir)/index.tsv"
	[ -f "$idx" ] || return "$RETURN_SUCCESS"
	SK_BASE="$SHELL_PROMPT_SKILLS_PATH/" awk -F'\t' '
		function slugify(s,   t) {
			t = tolower(s); gsub(/[^a-z0-9]+/, "-", t); sub(/^-/, "", t); sub(/-$/, "", t)
			t = substr(t, 1, 80); sub(/-$/, "", t); return t
		}
		BEGIN { base = ENVIRON["SK_BASE"] }
		{
			p = $1; rel = substr(p, length(base) + 1); n = split(rel, parts, "/")
			f = parts[n]; sub(/\.md$/, "", f)
			d = ""; t = ""
			for (i = 1; i < n; i++) { d = d (i > 1 ? "-" : "") parts[i]; t = t (i > 1 ? "," : "") slugify(parts[i]) }
			s = f
			if (s !~ /^[a-z0-9][a-z0-9-]*$/ || length(s) > 100) s = slugify(f)
			if (s == "") next
			c++; S[c] = s; D[c] = d; P[c] = p; H[c] = $2; Z[c] = $3; T[c] = t; cnt[s]++
		}
		END {
			for (i = 1; i <= c; i++) {
				s = S[i]
				if (cnt[s] > 1 && D[i] != "") { s = slugify(D[i] "-" S[i]); if (s == "") continue }
				if (s in seen) continue
				seen[s] = 1
				printf "%s\t%s\t%s\t%s\t%s\n", s, P[i], H[i], Z[i], T[i]
			}
		}' "$idx" | LC_ALL=C sort
}

# @internal
# @description Find one entry by slug or by remote path (exact match).
# @arg $1 string The name.
# @stdout The entry line (`slug path sha size tags`).
# @exitcode 0 Found.
# @exitcode 3 Not found (logged).
# @example
#   entry="$(_shell::prompt::skills::find skill-optimizer)" || return $?
#
_shell::prompt::skills::find() {
	local line
	line="$(_shell::prompt::skills::entries | SK_NAME="${1-}" awk -F'\t' '$1 == ENVIRON["SK_NAME"] || $2 == ENVIRON["SK_NAME"] { print; exit }')"
	if [ -z "$line" ]; then
		shell::logger::error "Prompt '${1-}' not found in ${_SK_REPO}@${_SK_BRANCH} (list them with: shell::prompt::skills::list)."
		return "$RETURN_NOT_FOUND"
	fi
	printf '%s\n' "$line"
}

# @internal
# @description Print the SHA-256 of a file (`sha256sum` on Linux, `shasum -a 256` on macOS).
# @arg $1 string The file.
# @stdout The hex digest.
# @exitcode 0 Printed.
# @exitcode 1 No tool or unreadable file.
# @example
#   sum="$(_shell::prompt::skills::sha256 "$file")"
#
_shell::prompt::skills::sha256() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum -- "${1-}" | cut -d' ' -f1
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 -- "${1-}" | cut -d' ' -f1
	else
		return "$RETURN_FAILURE"
	fi
}

# @internal
# @description Print the path of the provenance lock of a store.
# @arg $1 string `global` or `local`.
# @stdout The path.
# @exitcode 0 Always.
# @example
#   lock="$(_shell::prompt::skills::lock::file global)"
#
_shell::prompt::skills::lock::file() {
	printf '%s/%s\n' "$(_shell::prompt::dir "${1-global}")" "$SHELL_PROMPT_SKILLS_LOCK_NAME"
}

# @internal
# @description Print the lock line of a prompt.
# @arg $1 string The scope.
# @arg $2 string The slug.
# @stdout The TSV line.
# @exitcode 0 Found.
# @exitcode 1 Not tracked.
# @example
#   line="$(_shell::prompt::skills::lock::get global my-prompt)"
#
_shell::prompt::skills::lock::get() {
	local lock line
	lock="$(_shell::prompt::skills::lock::file "${1-global}")"
	[ -f "$lock" ] || return "$RETURN_FAILURE"
	line="$(LK_SLUG="${2-}" awk -F'\t' '$1 == ENVIRON["LK_SLUG"] { print; exit }' "$lock")"
	[ -n "$line" ] || return "$RETURN_FAILURE"
	printf '%s\n' "$line"
}

# @internal
# @description Rewrite a lock atomically: drop the entry of a slug and optionally append a new line (temp file + mv, mode 600).
# @arg $1 string The scope.
# @arg $2 string The slug to drop.
# @arg $3 string Optional. A full TSV line to append.
# @exitcode 0 Written.
# @exitcode 1 The write failed (the old lock is untouched).
# @example
#   _shell::prompt::skills::lock::rewrite global old ""
#
_shell::prompt::skills::lock::rewrite() {
	local scope="${1-global}" slug="${2-}" line="${3-}" lock dir tmp
	lock="$(_shell::prompt::skills::lock::file "$scope")"
	dir="${lock%/*}"
	[ -d "$dir" ] || return "$RETURN_SUCCESS"
	tmp="$(umask 077 && mktemp "$dir/.tmp.XXXXXX")" || return "$RETURN_FAILURE"
	{
		if [ -f "$lock" ]; then LK_SLUG="$slug" awk -F'\t' '$1 != ENVIRON["LK_SLUG"]' "$lock"; fi
		if [ -n "$line" ]; then printf '%s\n' "$line"; fi
	} >"$tmp" || {
		rm -f -- "$tmp"
		return "$RETURN_FAILURE"
	}
	if [ ! -s "$tmp" ]; then
		rm -f -- "$tmp" "$lock"
		return "$RETURN_SUCCESS"
	fi
	chmod 600 "$tmp" 2>/dev/null
	mv -f -- "$tmp" "$lock" || {
		rm -f -- "$tmp"
		return "$RETURN_FAILURE"
	}
	return "$RETURN_SUCCESS"
}

# @internal
# @description Record where an installed prompt came from.
# @arg $1 string The scope.
# @arg $2 string The slug.
# @arg $3 string The repo.
# @arg $4 string The branch.
# @arg $5 string The remote path.
# @arg $6 string The remote blob sha.
# @arg $7 string The SHA-256 of the installed file.
# @exitcode 0 Written.
# @exitcode 1 Failed.
# @example
#   _shell::prompt::skills::lock::put global a pnguyen215/skills master prompts/a.md 0123 abcd
#
_shell::prompt::skills::lock::put() {
	local tab
	tab="$(printf '\t')"
	_shell::prompt::skills::lock::rewrite "${1-}" "${2-}" "${2-}${tab}${3-}${tab}${4-}${tab}${5-}${tab}${6-}${tab}$(_shell::prompt::now)${tab}${7-}"
}

# @internal
# @description Forget a prompt (used by remove).
# @arg $1 string The scope.
# @arg $2 string The slug.
# @exitcode 0 Always (a prompt that is not tracked is fine).
# @example
#   _shell::prompt::skills::lock::del global a
#
_shell::prompt::skills::lock::del() {
	_shell::prompt::skills::lock::get "${1-global}" "${2-}" >/dev/null 2>&1 || return "$RETURN_SUCCESS"
	_shell::prompt::skills::lock::rewrite "${1-global}" "${2-}" "" || shell::logger::warn "Could not update the skills lock of '${2-}'."
	return "$RETURN_SUCCESS"
}

# @internal
# @description Move a lock entry to a new slug (used by rename).
# @arg $1 string The scope.
# @arg $2 string The old slug.
# @arg $3 string The new slug.
# @exitcode 0 Always.
# @example
#   _shell::prompt::skills::lock::move global old new
#
_shell::prompt::skills::lock::move() {
	local line tab
	line="$(_shell::prompt::skills::lock::get "${1-global}" "${2-}")" || return "$RETURN_SUCCESS"
	tab="$(printf '\t')"
	_shell::prompt::skills::lock::rewrite "${1-global}" "${2-}" "" || return "$RETURN_SUCCESS"
	_shell::prompt::skills::lock::rewrite "${1-global}" "${3-}" "${3-}${tab}${line#*"$tab"}" || shell::logger::warn "Could not move the skills lock entry to '${3-}'."
	return "$RETURN_SUCCESS"
}

# @internal
# @description Turn a downloaded file into prompt parts. With valid front matter (a `title`) the title, description, tags
#   and body are reused; otherwise the title is the first `# ` heading (or the prettified file name), the description is
#   empty and the body is the whole file byte for byte. The directories under the prompt path are added to the tags.
#   Sets `_SK_TITLE`, `_SK_DESC` and `_SK_TAGS`.
# @arg $1 string The downloaded file.
# @arg $2 string The remote path.
# @arg $3 string The file that receives the body.
# @exitcode 0 Converted.
# @exitcode 1 Failed.
# @example
#   _shell::prompt::skills::convert "$blob" prompts/a.md "$work/body"
#
_shell::prompt::skills::convert() {
	local file="${1-}" rpath="${2-}" body="${3-}" rel dir dtags ftitle heading base
	rel="${rpath#"$SHELL_PROMPT_SKILLS_PATH"/}"
	dir="${rel%/*}"
	[ "$dir" = "$rel" ] && dir=""
	dtags="$(_shell::prompt::norm_tags "$(printf '%s' "$dir" | tr '/' ' ')")"
	ftitle=""
	if _shell::prompt::body_offset "$file" >/dev/null 2>&1; then
		ftitle="$(_shell::prompt::clean_line "$(_shell::prompt::meta "$file" title)")"
	fi
	if [ -n "$ftitle" ]; then
		_SK_TITLE="$ftitle"
		_SK_DESC="$(_shell::prompt::clean_line "$(_shell::prompt::meta "$file" description)")"
		_SK_TAGS="$(_shell::prompt::norm_tags "$(_shell::prompt::meta "$file" tags),${dtags}")"
		_shell::prompt::body_stream "$file" >"$body" || return "$RETURN_FAILURE"
	else
		heading="$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^# *//')"
		heading="$(_shell::prompt::clean_line "$heading")"
		if [ -z "$heading" ]; then
			base="${rel##*/}"
			base="${base%.md}"
			heading="$(printf '%s' "$base" | tr '_-' '  ' | awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2); print }')"
		fi
		_SK_TITLE="$heading"
		_SK_DESC=""
		_SK_TAGS="$dtags"
		cp -- "$file" "$body" || return "$RETURN_FAILURE"
	fi
	_SK_TITLE="$(printf '%s' "$_SK_TITLE" | cut -c1-200)"
	[ -n "$_SK_TITLE" ] || _SK_TITLE="${rel##*/}"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Make sure the given files are in the cache. Input on stdin: `path<TAB>sha` per line. At most
#   SHELL_PROMPT_SKILLS_BULK_MIN missing files are downloaded one by one (SHELL_PROMPT_SKILLS_JOBS in parallel); more than
#   that is ONE tarball. A failed tarball falls back to the per-file route.
# @stdin Lines `path<TAB>sha`.
# @exitcode 0 Everything needed is cached.
# @exitcode 1 Some files could not be downloaded (the rest is cached).
# @example
#   printf '%s\t%s\n' prompts/a.md 0123 | _shell::prompt::skills::ensure_blobs
#
_shell::prompt::skills::ensure_blobs() {
	local blobs rpath sha missing="" n=0 jobs="$SHELL_PROMPT_SKILLS_JOBS" tab
	tab="$(printf '\t')"
	blobs="$(_shell::prompt::skills::cache_dir)/blobs"
	(umask 077 && mkdir -p "$blobs") || return "$RETURN_FAILURE"
	while IFS="$tab" read -r rpath sha; do
		[ -n "$sha" ] || continue
		[ -f "$blobs/$sha" ] && continue
		missing="${missing}${rpath}${tab}${sha}"$'\n'
		n=$((n + 1))
	done
	[ "$n" -gt 0 ] || return "$RETURN_SUCCESS"
	case "$jobs" in '' | *[!0-9]* | 0) jobs=4 ;; esac
	if [ "$n" -gt "$SHELL_PROMPT_SKILLS_BULK_MIN" ]; then
		_shell::prompt::skills::fetch_archive - >/dev/null 2>&1 || true
	fi
	(
		_shell::prompt::skills::txexport
		printf '%s' "$missing" | while IFS="$tab" read -r rpath sha; do
			[ -f "$blobs/$sha" ] || printf '%s %s\n' "$rpath" "$sha"
		done | xargs -n 2 -P "$jobs" sh "$SHELL_DIR/scripts/prompt_skills_transport.sh" file >/dev/null 2>&1
	) || true
	printf '%s' "$missing" | while IFS="$tab" read -r rpath sha; do
		[ -f "$blobs/$sha" ] || return "$RETURN_FAILURE"
	done
}

# @internal
# @description Install (or update) ONE prompt, honouring the conflict rules. The outcome is left in `_SK_RESULT`:
#   `installed`, `updated`, `uptodate`, `skipped` (conflict or local modification), `would` (dry-run) or `failed`.
#   Conflict matrix: new -> install; tracked and clean -> update (snapshot first) or `uptodate`; tracked and locally modified
#   -> skipped unless force (snapshot first); same slug but NOT tracked (user-created) -> skipped unless force (snapshot
#   first). Nothing is written in dry-run mode.
# @arg $1 string The work directory.
# @arg $2 string `true` for dry-run.
# @arg $3 string `true` for force.
# @arg $4 string The scope.
# @arg $5 string The target slug.
# @arg $6 string The remote path.
# @arg $7 string The remote blob sha.
# @exitcode 0 Done, skipped as a no-op or dry-run.
# @exitcode 1 Failed.
# @exitcode 7 Skipped because the slug exists and is not an installed skill (or is modified).
# @example
#   _shell::prompt::skills::install::one "$work" false false global skill-optimizer prompts/skill-optimizer.md "$sha"
#
_shell::prompt::skills::install::one() {
	local work="${1-}" dry="${2-false}" force="${3-false}" scope="${4-global}" slug="${5-}" rpath="${6-}" sha="${7-}"
	local file blob lock lslug lrepo lbranch lpath lsha linst lchk sum mode="new" created="" tab
	tab="$(printf '\t')"
	_SK_RESULT="failed"
	_shell::prompt::need_slug "$slug" || return "$RETURN_INVALID"
	case "$rpath" in *..* | /* | '') return "$RETURN_INVALID" ;; esac
	file="$(_shell::prompt::file "$scope" "$slug")"
	blob="$(_shell::prompt::skills::cache_dir)/blobs/$sha"
	if [ -f "$file" ]; then
		lock="$(_shell::prompt::skills::lock::get "$scope" "$slug")" || lock=""
		if [ -n "$lock" ]; then
			IFS="$tab" read -r lslug lrepo lbranch lpath lsha linst lchk <<EOF
$lock
EOF
			sum="$(_shell::prompt::skills::sha256 "$file")"
			if [ "$sum" != "$lchk" ] && [ "$force" != "true" ]; then
				shell::logger::warn "Skipped '${slug}' (${scope}): modified locally. Use --force to replace it (your version is kept in history)."
				_SK_RESULT="skipped"
				return "$RETURN_EXISTS"
			fi
			if [ "$lpath" != "$rpath" ] && [ "$force" != "true" ]; then
				shell::logger::warn "Skipped '${slug}' (${scope}): it was installed from '${lpath}', not '${rpath}'. Use --force or --as <slug>."
				_SK_RESULT="skipped"
				return "$RETURN_EXISTS"
			fi
			if [ "$lpath" = "$rpath" ] && [ "$lsha" = "$sha" ] && [ "$sum" = "$lchk" ]; then
				if [ "$lrepo" = "$_SK_REPO" ] && [ "$lbranch" = "$_SK_BRANCH" ]; then
					_SK_RESULT="uptodate"
					return "$RETURN_SUCCESS"
				fi
				# Same content on another branch/repo: only the provenance changes.
				if [ "$dry" = "true" ]; then
					shell::logger::command_clip "lock ${slug}: ${lrepo}@${lbranch} -> ${_SK_REPO}@${_SK_BRANCH}"
					_SK_RESULT="would"
					return "$RETURN_SUCCESS"
				fi
				_shell::prompt::skills::lock::put "$scope" "$slug" "$_SK_REPO" "$_SK_BRANCH" "$rpath" "$sha" "$sum" || return "$RETURN_FAILURE"
				_SK_RESULT="updated"
				return "$RETURN_SUCCESS"
			fi
		else
			if [ "$force" != "true" ]; then
				shell::logger::warn "Skipped '${slug}' (${scope}): a prompt with that slug exists and was not installed from skills. Use --force (it is kept in history) or --as <other-slug>."
				_SK_RESULT="skipped"
				return "$RETURN_EXISTS"
			fi
		fi
		mode="replace"
		created="$(_shell::prompt::meta "$file" created)"
	fi
	if [ "$dry" = "true" ]; then
		shell::logger::command_clip "install ${_SK_REPO}@${_SK_BRANCH}:${rpath} -> ${file} (${mode})"
		_SK_RESULT="would"
		return "$RETURN_SUCCESS"
	fi
	if [ ! -f "$blob" ]; then
		_shell::prompt::skills::fetch_file "$rpath" "$sha" >/dev/null 2>&1 || {
			shell::logger::error "Could not download '${rpath}'."
			return "$RETURN_FAILURE"
		}
	fi
	_shell::prompt::skills::convert "$blob" "$rpath" "$work/body" || {
		shell::logger::error "Could not read '${rpath}'."
		return "$RETURN_FAILURE"
	}
	if [ "$(wc -c <"$work/body" | tr -d ' ')" -gt "$SHELL_PROMPT_MAX_BYTES" ]; then
		shell::logger::error "Skipped '${rpath}': larger than ${SHELL_PROMPT_MAX_BYTES} bytes."
		return "$RETURN_FAILURE"
	fi
	if ! grep -q '[^[:space:]]' "$work/body"; then
		shell::logger::error "Skipped '${rpath}': the body is empty."
		return "$RETURN_FAILURE"
	fi
	_shell::prompt::store "$scope" "$slug" "$_SK_TITLE" "$_SK_DESC" "$_SK_TAGS" "$created" "$work/body" "$mode" || return "$RETURN_FAILURE"
	sum="$(_shell::prompt::skills::sha256 "$file")" || sum=""
	_shell::prompt::skills::lock::put "$scope" "$slug" "$_SK_REPO" "$_SK_BRANCH" "$rpath" "$sha" "$sum" || {
		shell::logger::error "Installed '${slug}' but could not write the skills lock."
		return "$RETURN_FAILURE"
	}
	if [ "$mode" = "replace" ]; then _SK_RESULT="updated"; else _SK_RESULT="installed"; fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Install every entry listed in a file (`slug<TAB>path<TAB>sha`), with `n/total` progress and a summary
#   line `Summary: installed=N updated=N uptodate=N skipped=N failed=N` on stdout. Missing files are fetched first, in bulk.
# @arg $1 string The work directory.
# @arg $2 string `true` for dry-run.
# @arg $3 string `true` for force.
# @arg $4 string The scope.
# @arg $5 string The file with the entries.
# @exitcode 0 Nothing failed and something was done or was already current.
# @exitcode 1 At least one file failed.
# @exitcode 7 Everything was skipped because of conflicts.
# @example
#   _shell::prompt::skills::install::many "$work" false false global "$work/todo"
#
_shell::prompt::skills::install::many() {
	local work="${1-}" dry="${2-false}" force="${3-false}" scope="${4-global}" todo="${5-}" tab total i=0 slug rpath sha
	local c_inst=0 c_upd=0 c_ok=0 c_skip=0 c_fail=0 c_would=0 rc=0
	tab="$(printf '\t')"
	total="$(wc -l <"$todo" | tr -d ' ')"
	if [ "$dry" != "true" ]; then
		awk -F'\t' '{ print $2 "\t" $3 }' "$todo" | _shell::prompt::skills::ensure_blobs || true
	fi
	while IFS="$tab" read -r slug rpath sha <&4; do
		[ -n "$slug" ] || continue
		i=$((i + 1))
		shell::logger::info "[${i}/${total}] ${slug}"
		_shell::prompt::skills::install::one "$work" "$dry" "$force" "$scope" "$slug" "$rpath" "$sha" || true
		case "$_SK_RESULT" in
		installed) c_inst=$((c_inst + 1)) ;;
		updated) c_upd=$((c_upd + 1)) ;;
		uptodate) c_ok=$((c_ok + 1)) ;;
		skipped)
			c_skip=$((c_skip + 1))
			printf '%s\t%s\t%s\n' "$slug" "$rpath" "$sha" >>"$work/skipped.$scope"
			;;
		would) c_would=$((c_would + 1)) ;;
		*) c_fail=$((c_fail + 1)) ;;
		esac
	done 4<"$todo"
	printf 'Summary: installed=%s updated=%s uptodate=%s skipped=%s failed=%s\n' "$c_inst" "$c_upd" "$c_ok" "$c_skip" "$c_fail"
	if [ "$scope" = "local" ] && [ "$((c_inst + c_upd))" -gt 0 ]; then
		shell::logger::info "Tip: the personal store '$(_shell::prompt::dir local)' may need to be git-ignored in this project (.gitignore is not edited for you)."
	fi
	[ "$c_fail" -eq 0 ] || return "$RETURN_FAILURE"
	if [ "$c_skip" -gt 0 ] && [ "$((c_inst + c_upd + c_ok + c_would))" -eq 0 ]; then rc="$RETURN_EXISTS"; fi
	return "$rc"
}

# @internal
# @description Map a scope flag to a store name (`global`, `local`); empty means `global`.
# @arg $1 string The scope flag.
# @stdout `global` or `local`.
# @exitcode 0 Always.
# @example
#   scope="$(_shell::prompt::skills::scope_of "$_SK_SCOPE")"
#
_shell::prompt::skills::scope_of() {
	case "${1-}" in
	local) printf 'local\n' ;;
	*) printf 'global\n' ;;
	esac
}

# @internal
# @description Report the state of every tracked prompt against the current index. Rows:
#   `<G|P><TAB>slug<TAB>local<TAB>remote<TAB>path<TAB>lock_branch<TAB>lock_sha<TAB>remote_sha` where local is `ok`, `modified`
#   or `nofile` and remote is `same`, `newer`, `switch` (another branch is requested) or `gone`.
# @arg $1 string Scopes: `global`, `local` or `all`.
# @arg $2 string Optional. Only entries recorded for this branch.
# @stdout The rows.
# @exitcode 0 Always.
# @example
#   _shell::prompt::skills::locks_state all ""
#
_shell::prompt::skills::locks_state() {
	local scopes="${1-all}" only="${2-}" sc ch lock slug repo branch rpath lsha linst lchk file loc rem rsha idx tab
	tab="$(printf '\t')"
	idx="$(_shell::prompt::skills::cache_dir)/index.tsv"
	for sc in global local; do
		[ "$scopes" = "all" ] || [ "$scopes" = "$sc" ] || continue
		lock="$(_shell::prompt::skills::lock::file "$sc")"
		[ -f "$lock" ] || continue
		ch="G"
		[ "$sc" = "local" ] && ch="P"
		while IFS="$tab" read -r slug repo branch rpath lsha linst lchk <&6; do
			[ -n "$slug" ] || continue
			[ "$repo" = "$_SK_REPO" ] || continue
			[ -z "$only" ] || [ "$branch" = "$only" ] || continue
			file="$(_shell::prompt::file "$sc" "$slug")"
			if [ ! -f "$file" ]; then
				loc="nofile"
			elif [ "$(_shell::prompt::skills::sha256 "$file")" = "$lchk" ]; then
				loc="ok"
			else
				loc="modified"
			fi
			rsha=""
			[ -f "$idx" ] && rsha="$(SK_P="$rpath" awk -F'\t' '$1 == ENVIRON["SK_P"] { print $2; exit }' "$idx")"
			if [ -z "$rsha" ]; then
				rem="gone"
			elif [ "$branch" != "$_SK_BRANCH" ]; then
				rem="switch"
			elif [ "$rsha" != "$lsha" ]; then
				rem="newer"
			else
				rem="same"
			fi
			printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$ch" "$slug" "$loc" "$rem" "$rpath" "$branch" "$lsha" "$rsha"
		done 6<"$lock"
	done
	return "$RETURN_SUCCESS"
}

# @internal
# @description Build the table behind the lists: one row per remote prompt with its install status.
#   Columns: `slug path sha size tags status` where status is `-` (not installed) or `G`/`P` (installed), followed by `*`
#   (a newer version exists) or `!` (modified locally); several stores are joined with `,`.
# @stdout The rows, sorted by slug.
# @exitcode 0 Always.
# @example
#   _shell::prompt::skills::table | cut -f1,6
#
_shell::prompt::skills::table() {
	local states
	states="$(_shell::prompt::skills::locks_state all "")"
	{
		printf '%s\n' "$states" | awk -F'\t' 'NF >= 5 && $3 != "nofile" { print "S\t" $1 "\t" $3 "\t" $4 "\t" $5 }'
		_shell::prompt::skills::entries | awk -F'\t' '{ print "E\t" $0 }'
	} | awk -F'\t' '
		$1 == "S" {
			f = ($3 == "modified") ? "!" : (($4 == "newer" || $4 == "switch") ? "*" : "")
			st[$5] = st[$5] (st[$5] == "" ? "" : ",") $2 f
			next
		}
		$1 == "E" {
			s = (($3 in st) ? st[$3] : "-")
			printf "%s\t%s\t%s\t%s\t%s\t%s\n", $2, $3, $4, $5, $6, s
		}' | LC_ALL=C sort
}

# @internal
# @description Prettify a slug for display (`skill-optimizer` -> `Skill Optimizer`).
# @arg $1 string The slug.
# @stdout The title.
# @exitcode 0 Always.
# @example
#   _shell::prompt::skills::pretty skill-optimizer
#
_shell::prompt::skills::pretty() {
	printf '%s' "${1-}" | tr '-' ' ' | awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2); print }'
}

# @internal
# @description Resolve names into entries, one `slug<TAB>path<TAB>sha` line each, into a file. A name that is not found is
#   logged and counted.
# @arg $1 string The output file.
# @arg $@ string The names.
# @exitcode 0 All found.
# @exitcode 3 At least one was not found (the others are still written).
# @example
#   _shell::prompt::skills::resolve_names "$work/todo" a b
#
_shell::prompt::skills::resolve_names() {
	local out="${1-}" name entry rc=0
	shift
	: >"$out"
	for name in "$@"; do
		entry="$(_shell::prompt::skills::find "$name")" || {
			rc="$RETURN_NOT_FOUND"
			continue
		}
		printf '%s\n' "$entry" | awk -F'\t' '{ print $1 "\t" $2 "\t" $3 }' >>"$out"
	done
	return "$rc"
}

# @internal
# @description Run a function once per branch that matters: the explicit `--branch` (this is how a branch switch is asked
#   for) or, by default, every branch recorded in the locks of the chosen scopes. The index of each branch is loaded first.
#   The function receives `<only-branch|empty> <scopes>` followed by the extra arguments.
# @arg $1 string The function.
# @arg $2 string The scopes (`global`, `local`, `all`).
# @arg $@ string Extra arguments for the function.
# @exitcode 0 Done.
# @exitcode N The last non-zero status of the function or of the index load.
# @example
#   _shell::prompt::skills::each_branch _shell::prompt::skills::status::branch all "$work"
#
_shell::prompt::skills::each_branch() {
	local fn="${1-}" scopes="${2-all}" saved="$_SK_BRANCH" b sc lock rc=0 list=""
	shift 2
	if [ "$_SK_EXPLICIT" = "true" ]; then
		_shell::prompt::skills::index || return $?
		"$fn" "" "$scopes" "$@"
		return $?
	fi
	for sc in global local; do
		[ "$scopes" = "all" ] || [ "$scopes" = "$sc" ] || continue
		lock="$(_shell::prompt::skills::lock::file "$sc")"
		[ -f "$lock" ] || continue
		list="${list}$(awk -F'\t' -v r="$_SK_REPO" '$2 == r { print $3 }' "$lock")"$'\n'
	done
	list="$(printf '%s' "$list" | awk 'NF && !s[$0]++')"
	if [ -z "$list" ]; then
		shell::logger::info "Nothing installed from ${_SK_REPO} in the selected store(s)."
		return "$RETURN_SUCCESS"
	fi
	while IFS= read -r b <&5; do
		[ -n "$b" ] || continue
		_SK_BRANCH="$b"
		_shell::prompt::skills::index || {
			rc=$?
			continue
		}
		"$fn" "$b" "$scopes" "$@" || rc=$?
	done 5<<EOF
$list
EOF
	_SK_BRANCH="$saved"
	return "$rc"
}

# @internal
# @description Update the tracked prompts of ONE branch (see each_branch). Candidates: newer, switched or locally modified
#   (modified ones are skipped and reported unless force). `names` limits the slugs.
# @arg $1 string Only entries of this branch (empty = all).
# @arg $2 string The scopes.
# @arg $3 string The work directory.
# @arg $4 string `true` for dry-run.
# @arg $5 string `true` for force.
# @arg $@ string Optional. Installed slugs to limit the update to.
# @exitcode 0 Done.
# @exitcode 1 Something failed.
# @example
#   _shell::prompt::skills::update::branch "" all "$work" false false
#
_shell::prompt::skills::update::branch() {
	local only="${1-}" scopes="${2-all}" work="${3-}" dry="${4-false}" force="${5-false}" rc=0 sc ch tab
	local c slug loc rem rpath lbranch lsha rsha n found todo
	shift 5
	tab="$(printf '\t')"
	for sc in global local; do
		[ "$scopes" = "all" ] || [ "$scopes" = "$sc" ] || continue
		ch="G"
		[ "$sc" = "local" ] && ch="P"
		todo="$work/todo.$sc"
		: >"$todo"
		while IFS="$tab" read -r c slug loc rem rpath lbranch lsha rsha <&7; do
			[ "$c" = "$ch" ] || continue
			if [ "$#" -gt 0 ]; then
				found="false"
				for n in "$@"; do [ "$n" = "$slug" ] && found="true"; done
				[ "$found" = "true" ] || continue
			fi
			[ "$loc" = "nofile" ] && continue
			if [ "$rem" = "gone" ]; then
				shell::logger::warn "'${slug}' (${sc}) no longer exists in ${_SK_REPO}@${_SK_BRANCH} - kept as it is."
				continue
			fi
			if [ "$rem" = "same" ] && [ "$loc" = "ok" ]; then continue; fi
			if [ "$rem" = "same" ] && [ "$loc" = "modified" ] && [ "$force" != "true" ]; then
				shell::logger::warn "Skipped '${slug}' (${sc}): modified locally; the remote did not change. Use --force to restore the remote version."
				continue
			fi
			printf '%s\t%s\t%s\n' "$slug" "$rpath" "$rsha" >>"$todo"
		done 7<<EOF
$(_shell::prompt::skills::locks_state "$sc" "$only")
EOF
		if [ -s "$todo" ]; then
			_shell::prompt::skills::install::many "$work" "$dry" "$force" "$sc" "$todo" || rc=$?
			# Everything skipped because of local changes is reported, not an error: that is what update promises.
			[ "$rc" -ne "$RETURN_EXISTS" ] || rc=0
		fi
	done
	return "$rc"
}

# @internal
# @description Print the drift of ONE branch (see each_branch): one row per tracked prompt that is not clean, then counts.
# @arg $1 string Only entries of this branch.
# @arg $2 string The scopes.
# @exitcode 0 Always.
# @example
#   _shell::prompt::skills::status::branch "" all
#
_shell::prompt::skills::status::branch() {
	_shell::prompt::skills::locks_state "${2-all}" "${1-}" | awk -F'\t' -v repo="$_SK_REPO" -v br="$_SK_BRANCH" '
		{ n++ }
		$3 == "nofile" { printf "missing-file\t%s\t%s\t%s\n", $1, $2, $5; nf++; next }
		$3 == "modified" { printf "modified\t%s\t%s\t%s\n", $1, $2, $5; mo++ }
		$4 == "newer" || $4 == "switch" { printf "outdated\t%s\t%s\t%s\n", $1, $2, $5; ou++ }
		$4 == "gone" { printf "missing-remote\t%s\t%s\t%s\n", $1, $2, $5; gn++ }
		END { printf "Summary: repo=%s branch=%s tracked=%d outdated=%d modified=%d missing_remote=%d missing_file=%d\n", repo, br, n, ou, mo, gn, nf }'
}

# @internal
# @description Remove tracked prompts of one scope: only prompts installed from skills (a user-made prompt is never touched
#   here), a locally modified one needs an explicit confirmation, and everything is snapshotted into history first.
# @arg $1 string The work directory (unused, kept for the scoped runner).
# @arg $2 string `true` for dry-run.
# @arg $3 string `true` to skip confirmations.
# @arg $4 string The scope.
# @arg $@ string The installed slugs.
# @exitcode 0 Done (or declined).
# @exitcode 1 A removal failed.
# @exitcode 3 A name is not an installed skill.
# @example
#   _shell::prompt::scoped _shell::prompt::skills::remove::inner false false global a b
#
_shell::prompt::skills::remove::inner() {
	local dry="${2-false}" yes="${3-false}" scope="${4-global}" slug lock file lchk tab rc=0 ok
	shift 4
	tab="$(printf '\t')"
	for slug in "$@"; do
		_shell::prompt::need_slug "$slug" || {
			rc="$RETURN_INVALID"
			continue
		}
		lock="$(_shell::prompt::skills::lock::get "$scope" "$slug")" || {
			shell::logger::error "'${slug}' is not an installed skill in the ${scope} store (nothing was removed)."
			rc="$RETURN_NOT_FOUND"
			continue
		}
		file="$(_shell::prompt::file "$scope" "$slug")"
		if [ ! -f "$file" ]; then
			shell::logger::warn "'${slug}' has no file in the ${scope} store; dropping its stale lock entry."
			[ "$dry" = "true" ] || _shell::prompt::skills::lock::del "$scope" "$slug"
			continue
		fi
		lchk="${lock##*"$tab"}"
		if [ "$dry" != "true" ] && [ "$yes" != "true" ] && [ "$(_shell::prompt::skills::sha256 "$file")" != "$lchk" ]; then
			ok="false"
			shell::ask::accept "'${slug}' has local modifications. Remove it anyway? (kept in history)" && ok="true"
			if [ "$ok" != "true" ]; then
				shell::logger::info "Cancelled - '${slug}' was not removed"
				continue
			fi
			_shell::prompt::remove::do "$scope" "$slug" "$dry" true || rc=$?
		else
			_shell::prompt::remove::do "$scope" "$slug" "$dry" "$yes" || rc=$?
		fi
	done
	return "$rc"
}

# @internal
# @description Copy a remote prompt to the clipboard without installing it. `{{placeholders}}` are filled from `name=value`
#   arguments (asked on a terminal, defaults otherwise); the body never reaches the logger.
# @arg $1 string The work directory.
# @arg $2 string `true` for dry-run.
# @arg $3 string `true` to ask for missing values.
# @arg $4 string The prompt name.
# @arg $@ string Optional. Values as `name=value`.
# @exitcode 0 Copied (or dry-run).
# @exitcode 1 Failed.
# @exitcode 2 Invalid input or a placeholder without value.
# @exitcode 3 Not found.
# @example
#   _shell::prompt::scoped _shell::prompt::skills::copy::inner false false skill-optimizer
#
_shell::prompt::skills::copy::inner() {
	local work="${1-}" dry="${2-false}" ask="${3-false}" name="${4-}" entry slug rpath sha blob vars
	shift 4
	_shell::prompt::skills::index || return $?
	entry="$(_shell::prompt::skills::find "$name")" || return $?
	IFS=$'\t' read -r slug rpath sha _ <<EOF
$entry
EOF
	blob="$(_shell::prompt::skills::cache_dir)/blobs/$sha"
	if [ ! -f "$blob" ]; then
		printf '%s\t%s\n' "$rpath" "$sha" | _shell::prompt::skills::ensure_blobs || {
			shell::logger::error "Could not download '${rpath}'."
			return "$RETURN_FAILURE"
		}
	fi
	_shell::prompt::skills::convert "$blob" "$rpath" "$work/body" || return "$RETURN_FAILURE"
	vars="$(_shell::prompt::vars <"$work/body")"
	if [ -n "$vars" ]; then
		_shell::prompt::write "$work/p.md" "$_SK_TITLE" "" "" "x" "x" "$work/body" || return "$RETURN_FAILURE"
		_shell::prompt::render::file "$work/p.md" "$work/out" "$ask" "$@" || return $?
	else
		cp -- "$work/body" "$work/out" || return "$RETURN_FAILURE"
	fi
	_shell::prompt::copy_file "$_SK_TITLE" "$work/out" "$dry"
}

# @internal
# @description Run the inner function of `list`: print the rows of the table, filtered.
# @arg $1 string The work directory (unused).
# @arg $2 string The tag filter.
# @arg $3 string The status filter (`installed`, `available`, `outdated` or empty).
# @stdout `status<TAB>slug<TAB>title<TAB>tags<TAB>path`.
# @exitcode 0 Printed.
# @example
#   _shell::prompt::skills::list::inner "$work" "" outdated
#
_shell::prompt::skills::list::inner() {
	local tag="${2-}" filter="${3-}"
	_shell::prompt::skills::index || return $?
	_shell::prompt::skills::table | awk -F'\t' -v tag="$tag" -v flt="$filter" '
		function pretty(s,   n, a, i, r) { n = split(s, a, "-"); r = ""; for (i = 1; i <= n; i++) r = r (i > 1 ? " " : "") toupper(substr(a[i], 1, 1)) substr(a[i], 2); return r }
		tag != "" && ("," $5 ",") !~ ("," tag ",") { next }
		flt == "installed" && $6 == "-" { next }
		flt == "available" && $6 != "-" { next }
		flt == "outdated" && $6 !~ /[*!]/ { next }
		{ printf "%s\t%s\t%s\t%s\t%s\n", $6, $1, pretty($1), $5, $2 }'
}

# @description List the prompts of the skills repository with their install status: `-` not installed, `G` / `P` installed
#   in the global / personal store, `*` an update is available, `!` modified locally.
# @option --tag <tag> Optional. Only prompts with this tag (directories of the repo are tags).
# @option --installed | --available | --outdated Optional. Filter by status.
# @option --repo <owner/repo> Optional. Another repository.
# @option --branch <name> Optional. Another branch (default: SHELL_PROMPT_SKILLS_BRANCH = master).
# @option --refresh Optional. Ask GitHub again even when the cached index is fresh.
# @option -h | --help Show help and return.
# @stdout One line per prompt: status, slug, title, tags, remote path.
# @exitcode 0 Success.
# @exitcode 1 Network failure and no cache.
# @exitcode 2 Invalid option.
# @exitcode 3 Branch not found.
# @example
#   shell::prompt::skills::list
#   shell::prompt::skills::list --outdated --branch develop
#
shell::prompt::skills::list() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "List the prompts of the skills repository with their install status (- G P * !)" \
			"shell::prompt::skills::list [--tag <t>] [--installed|--available|--outdated] [--repo <o/r>] [--branch <b>] [--refresh]" \
			"shell::prompt::skills::list --outdated" "--tag <t>::Only prompts with this tag" "--installed::Only installed prompts" \
			"--available::Only prompts not installed" "--outdated::Only prompts with an update or a local change" \
			"--repo <owner/repo>::Another repository" "--branch <name>::Branch to read (default master)" \
			"--refresh::Ignore the cached index" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::skills::parse "tag filter" "$@" || return $?
	_shell::prompt::scoped _shell::prompt::skills::list::inner "$_SK_TAG" "$_SK_FILTER"
}

# @description Print a remote prompt as it is in the repository, without installing it.
# @option --repo <owner/repo> Optional. Another repository.
# @option --branch <name> Optional. Another branch.
# @option --refresh Optional. Ask GitHub again.
# @option -h | --help Show help and return.
# @arg $1 string The prompt name (slug or remote path).
# @stdout The file content.
# @exitcode 0 Printed.
# @exitcode 1 Download failed.
# @exitcode 2 Invalid input.
# @exitcode 3 Not found.
# @example
#   shell::prompt::skills::view skill-optimizer
#
shell::prompt::skills::view() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Print a remote prompt without installing it" "shell::prompt::skills::view [--repo <o/r>] [--branch <b>] [--refresh] <name>" \
			"shell::prompt::skills::view skill-optimizer" "--repo <owner/repo>::Another repository" "--branch <name>::Branch to read (default master)" \
			"--refresh::Ignore the cached index" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::skills::parse "" "$@" || return $?
	[ "${#_SK_NAMES[@]}" -eq 1 ] || {
		shell::logger::error "Usage: shell::prompt::skills::view [--branch <b>] <name>"
		return "$RETURN_INVALID"
	}
	set -- "${_SK_NAMES[@]}"
	_shell::prompt::scoped _shell::prompt::skills::view::inner "$1"
}

# @internal
# @description Inner function of `view`: print the cached remote file.
# @arg $1 string The work directory.
# @arg $2 string The name.
# @stdout The file.
# @exitcode 0 Printed.
# @example
#   _shell::prompt::scoped _shell::prompt::skills::view::inner skill-optimizer
#
_shell::prompt::skills::view::inner() {
	local entry slug rpath sha blob
	_shell::prompt::skills::index || return $?
	entry="$(_shell::prompt::skills::find "${2-}")" || return $?
	IFS=$'\t' read -r slug rpath sha _ <<EOF
$entry
EOF
	printf '%s\t%s\n' "$rpath" "$sha" | _shell::prompt::skills::ensure_blobs || {
		shell::logger::error "Could not download '${rpath}'."
		return "$RETURN_FAILURE"
	}
	blob="$(_shell::prompt::skills::cache_dir)/blobs/$sha"
	cat -- "$blob"
}

# @description Copy a remote prompt to the clipboard WITHOUT installing it. `{{name}}` placeholders are filled from
#   `name=value` arguments (asked on a terminal, their default otherwise). Without a clipboard tool the text is printed.
# @option -n Optional dry-run flag. The command is printed and nothing is copied.
# @option --repo <owner/repo> Optional. Another repository.
# @option --branch <name> Optional. Another branch.
# @option --refresh Optional. Ask GitHub again.
# @option -h | --help Show help and return.
# @arg $1 string The prompt name.
# @arg $@ string Optional. Values as `name=value`.
# @exitcode 0 Copied (or printed, or dry-run).
# @exitcode 1 Failed.
# @exitcode 2 Invalid input or a placeholder without value.
# @exitcode 3 Not found.
# @example
#   shell::prompt::skills::copy skill-optimizer
#   shell::prompt::skills::copy summary topic="release notes"
#
shell::prompt::skills::copy() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Copy a remote prompt to the clipboard without installing it" \
			"shell::prompt::skills::copy [-n] [--repo <o/r>] [--branch <b>] <name> [name=value ...]" "shell::prompt::skills::copy skill-optimizer" \
			"-n::Dry-run: print the command instead of executing it" "--repo <owner/repo>::Another repository" "--branch <name>::Branch to read (default master)" \
			"--refresh::Ignore the cached index" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::skills::parse "n" "$@" || return $?
	[ "${#_SK_NAMES[@]}" -ge 1 ] || {
		shell::logger::error "Usage: shell::prompt::skills::copy [-n] [--branch <b>] <name> [name=value ...]"
		return "$RETURN_INVALID"
	}
	local dry="$_SK_DRY"
	set -- "${_SK_NAMES[@]}"
	local name="$1"
	shift
	_shell::prompt::kv_check "$@" || return "$RETURN_INVALID"
	_shell::prompt::scoped _shell::prompt::skills::copy::inner "$dry" true "$name" "$@"
}

# @description Install the chosen prompts from the skills repository (default: the GLOBAL store). An existing prompt that
#   was not installed from skills is never overwritten unless `--force` (its old version is snapshotted) or `--as <slug>`.
# @option -n Optional dry-run flag. Commands are printed and nothing is written.
# @option --global | --personal Optional. The target store (`--project` and `--local` are aliases of `--personal`).
# @option --force Optional. Overwrite a conflicting or locally modified prompt (snapshotted first).
# @option --as <slug> Optional. Install under another slug (exactly one name).
# @option --repo <owner/repo> Optional. Another repository.
# @option --branch <name> Optional. Another branch.
# @option --refresh Optional. Ask GitHub again.
# @option -h | --help Show help and return.
# @arg $@ string The prompt names.
# @stdout A summary line: `Summary: installed=N updated=N uptodate=N skipped=N failed=N`.
# @exitcode 0 Done.
# @exitcode 1 A download or write failed.
# @exitcode 2 Invalid input.
# @exitcode 3 A name was not found.
# @exitcode 7 Everything was skipped because the slugs already exist.
# @example
#   shell::prompt::skills::pick skill-optimizer
#   shell::prompt::skills::pick --personal --as my-opt skill-optimizer
#
shell::prompt::skills::pick() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Install the chosen prompts from the skills repository (default: global store)" \
			"shell::prompt::skills::pick [-n] [--global|--personal] [--force] [--as <slug>] [--branch <b>] <name...>" \
			"shell::prompt::skills::pick skill-optimizer" "-n::Dry-run: print the commands instead of executing them" \
			"--global::Install into the global store (default)" "--personal::Install into the project store (aliases: --project, --local)" \
			"--force::Overwrite a conflicting or modified prompt (snapshotted first)" "--as <slug>::Install under another slug" \
			"--repo <owner/repo>::Another repository" "--branch <name>::Branch to read (default master)" "--refresh::Ignore the cached index" \
			"-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::skills::parse "n scope force as" "$@" || return $?
	[ "${#_SK_NAMES[@]}" -ge 1 ] || {
		shell::logger::error "Usage: shell::prompt::skills::pick [-n] [--global|--personal] [--force] [--as <slug>] <name...>"
		return "$RETURN_INVALID"
	}
	if [ -n "$_SK_AS" ] && [ "${#_SK_NAMES[@]}" -ne 1 ]; then
		shell::logger::error "--as needs exactly one prompt name."
		return "$RETURN_INVALID"
	fi
	[ -z "$_SK_AS" ] || _shell::prompt::need_slug "$_SK_AS" || return "$RETURN_INVALID"
	_shell::prompt::scoped _shell::prompt::skills::pick::inner "$(_shell::prompt::skills::scope_of "$_SK_SCOPE")" "$_SK_AS" "${_SK_NAMES[@]}"
}

# @internal
# @description Inner function of `pick`.
# @arg $1 string The work directory.
# @arg $2 string The scope.
# @arg $3 string The slug override (may be empty).
# @arg $@ string The names.
# @exitcode 0 Done.
# @example
#   _shell::prompt::scoped _shell::prompt::skills::pick::inner global "" skill-optimizer
#
_shell::prompt::skills::pick::inner() {
	local work="${1-}" scope="${2-global}" as="${3-}" rc=0
	shift 3
	_shell::prompt::skills::index || return $?
	_shell::prompt::skills::resolve_names "$work/todo" "$@" || rc=$?
	if [ -n "$as" ] && [ -s "$work/todo" ]; then
		awk -F'\t' -v s="$as" '{ print s "\t" $2 "\t" $3 }' "$work/todo" >"$work/todo.as"
		mv -f "$work/todo.as" "$work/todo"
	fi
	if [ -s "$work/todo" ]; then
		_shell::prompt::skills::install::many "$work" "$_SK_DRY" "$_SK_FORCE" "$scope" "$work/todo" || rc=$?
	fi
	return "$rc"
}

# @description Install EVERY prompt under the prompt path of the skills repository (default: the GLOBAL store). The files are
#   fetched with one tarball when many are missing. Running it twice does no writes the second time.
# @option -n Optional dry-run flag. Commands are printed and nothing is written.
# @option --global | --personal Optional. The target store (`--project` and `--local` are aliases of `--personal`).
# @option --force Optional. Overwrite conflicting or locally modified prompts (snapshotted first).
# @option --repo <owner/repo> Optional. Another repository.
# @option --branch <name> Optional. Another branch.
# @option --refresh Optional. Ask GitHub again.
# @option -h | --help Show help and return.
# @stdout A summary line: `Summary: installed=N updated=N uptodate=N skipped=N failed=N`.
# @exitcode 0 Done.
# @exitcode 1 A download or write failed.
# @exitcode 2 Invalid option.
# @exitcode 3 The branch was not found.
# @exitcode 7 Everything was skipped because the slugs already exist.
# @example
#   shell::prompt::skills::install::all
#   shell::prompt::skills::install::all --personal --branch develop
#
shell::prompt::skills::install::all() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Install every prompt of the skills repository (default: global store)" \
			"shell::prompt::skills::install::all [-n] [--global|--personal] [--force] [--repo <o/r>] [--branch <b>] [--refresh]" \
			"shell::prompt::skills::install::all" "-n::Dry-run: print the commands instead of executing them" \
			"--global::Install into the global store (default)" "--personal::Install into the project store (aliases: --project, --local)" \
			"--force::Overwrite conflicting or modified prompts (snapshotted first)" "--repo <owner/repo>::Another repository" \
			"--branch <name>::Branch to read (default master)" "--refresh::Ignore the cached index" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::skills::parse "n scope force" "$@" || return $?
	[ "${#_SK_NAMES[@]}" -eq 0 ] || {
		shell::logger::error "install::all takes no names (use shell::prompt::skills::pick)."
		return "$RETURN_INVALID"
	}
	_shell::prompt::scoped _shell::prompt::skills::all::inner "$(_shell::prompt::skills::scope_of "$_SK_SCOPE")"
}

# @internal
# @description Inner function of `install::all`.
# @arg $1 string The work directory.
# @arg $2 string The scope.
# @exitcode 0 Done.
# @example
#   _shell::prompt::scoped _shell::prompt::skills::all::inner global
#
_shell::prompt::skills::all::inner() {
	local work="${1-}" scope="${2-global}"
	_shell::prompt::skills::index || return $?
	_shell::prompt::skills::entries | awk -F'\t' '{ print $1 "\t" $2 "\t" $3 }' >"$work/todo"
	if [ ! -s "$work/todo" ]; then
		shell::logger::warn "No prompt found under '${SHELL_PROMPT_SKILLS_PATH}/' in ${_SK_REPO}@${_SK_BRANCH}."
		return "$RETURN_SUCCESS"
	fi
	_shell::prompt::skills::install::many "$work" "$_SK_DRY" "$_SK_FORCE" "$scope" "$work/todo"
}

# @description Update the prompts installed from skills whose remote version changed. A prompt modified locally is skipped
#   and reported unless `--force` (your version is snapshotted first). With `--branch` the recorded branch is switched, shown
#   in the dry-run; without it each prompt is compared with the branch recorded in the lock.
# @option -n Optional dry-run flag. Commands are printed and nothing is written.
# @option --global | --personal | --all-scopes Optional. Which store (default: both).
# @option --force Optional. Replace locally modified prompts (snapshotted first).
# @option --repo <owner/repo> Optional. Another repository.
# @option --branch <name> Optional. Switch the prompts to this branch.
# @option --refresh Optional. Ask GitHub again.
# @option -h | --help Show help and return.
# @arg $@ string Optional. Installed slugs to limit the update to.
# @stdout A summary line per store and branch.
# @exitcode 0 Done.
# @exitcode 1 A download or write failed.
# @exitcode 2 Invalid option.
# @exitcode 3 The branch was not found.
# @example
#   shell::prompt::skills::update
#   shell::prompt::skills::update -n --branch develop
#
shell::prompt::skills::update() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Update the prompts installed from skills whose remote version changed" \
			"shell::prompt::skills::update [-n] [--global|--personal|--all-scopes] [--force] [--branch <b>] [<name...>]" \
			"shell::prompt::skills::update" "-n::Dry-run: print the commands instead of executing them" "--global::Only the global store" \
			"--personal::Only the project store" "--all-scopes::Both stores (default)" "--force::Replace locally modified prompts (snapshotted first)" \
			"--repo <owner/repo>::Another repository" "--branch <name>::Switch to this branch" "--refresh::Ignore the cached index" \
			"-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::skills::parse "n scope all force" "$@" || return $?
	local scopes="${_SK_SCOPE:-all}"
	_shell::prompt::scoped _shell::prompt::skills::update::run "$scopes" ${_SK_NAMES[@]+"${_SK_NAMES[@]}"}
}

# @internal
# @description Inner function of `update`.
# @arg $1 string The work directory.
# @arg $2 string The scopes.
# @arg $@ string Optional. Slugs.
# @exitcode 0 Done.
# @example
#   _shell::prompt::scoped _shell::prompt::skills::update::run all
#
_shell::prompt::skills::update::run() {
	local work="${1-}" scopes="${2-all}"
	shift 2
	_shell::prompt::skills::each_branch _shell::prompt::skills::update::branch "$scopes" "$work" "$_SK_DRY" "$_SK_FORCE" "$@"
}

# @description Remove prompts installed from skills. Only prompts tracked in the skills lock are touched (a prompt you wrote
#   yourself is refused); each one is snapshotted into history first, so `shell::prompt::restore` brings it back. A locally
#   modified prompt asks for confirmation.
# @option -n Optional dry-run flag. Commands are printed and nothing is removed.
# @option --global | --personal Optional. The store (default: global).
# @option -y | --yes Optional. Skip the confirmations.
# @option -h | --help Show help and return.
# @arg $@ string The installed slugs.
# @exitcode 0 Removed, declined or dry-run.
# @exitcode 1 A removal failed.
# @exitcode 2 Invalid input.
# @exitcode 3 A name is not an installed skill.
# @example
#   shell::prompt::skills::remove skill-optimizer
#   shell::prompt::skills::remove -n --personal skill-optimizer
#
shell::prompt::skills::remove() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Remove prompts installed from skills (kept in history, recoverable)" \
			"shell::prompt::skills::remove [-n] [--global|--personal] [-y] <name...>" "shell::prompt::skills::remove skill-optimizer" \
			"-n::Dry-run: print the commands instead of executing them" "--global::The global store (default)" \
			"--personal::The project store (aliases: --project, --local)" "-y, --yes::Skip the confirmations" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::skills::parse "n scope yes" "$@" || return $?
	[ "${#_SK_NAMES[@]}" -ge 1 ] || {
		shell::logger::error "Usage: shell::prompt::skills::remove [-n] [--global|--personal] <name...>"
		return "$RETURN_INVALID"
	}
	_shell::prompt::scoped _shell::prompt::skills::remove::inner "$_SK_DRY" "$_SK_YES" "$(_shell::prompt::skills::scope_of "$_SK_SCOPE")" "${_SK_NAMES[@]}"
}

# @description Summarise the drift of the installed skills: outdated, modified locally, missing remotely or without a file.
# @option --global | --personal | --all-scopes Optional. Which store (default: both).
# @option --repo <owner/repo> Optional. Another repository.
# @option --branch <name> Optional. Compare with this branch.
# @option --refresh Optional. Ask GitHub again.
# @option -h | --help Show help and return.
# @stdout Rows `state scope slug path` and a `Summary:` line per branch.
# @exitcode 0 Success.
# @exitcode 2 Invalid option.
# @example
#   shell::prompt::skills::status
#
shell::prompt::skills::status() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Summarise outdated, modified and missing installed skills" \
			"shell::prompt::skills::status [--global|--personal|--all-scopes] [--repo <o/r>] [--branch <b>] [--refresh]" "shell::prompt::skills::status" \
			"--global::Only the global store" "--personal::Only the project store" "--all-scopes::Both stores (default)" \
			"--repo <owner/repo>::Another repository" "--branch <name>::Compare with this branch" "--refresh::Ignore the cached index" \
			"-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::skills::parse "scope all" "$@" || return $?
	[ "${#_SK_NAMES[@]}" -eq 0 ] || {
		shell::logger::error "status takes no names."
		return "$RETURN_INVALID"
	}
	_shell::prompt::skills::each_branch _shell::prompt::skills::status::branch "${_SK_SCOPE:-all}"
}

# @description List the branches of the skills repository (the current one is marked with `*`).
# @option --repo <owner/repo> Optional. Another repository.
# @option -h | --help Show help and return.
# @stdout One branch per line.
# @exitcode 0 Listed.
# @exitcode 1 Network failure.
# @exitcode 3 The repository was not found.
# @example
#   shell::prompt::skills::branches
#
shell::prompt::skills::branches() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "List the branches of the skills repository" "shell::prompt::skills::branches [--repo <owner/repo>]" \
			"shell::prompt::skills::branches" "--repo <owner/repo>::Another repository" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	_shell::prompt::skills::parse "" "$@" || return $?
	local out rc=0 b
	(umask 077 && mkdir -p "$(_shell::prompt::skills::cache_dir)") || return "$RETURN_FAILURE"
	out="$(_shell::prompt::skills::tx branches)" || rc=$?
	case "$rc" in
	0) ;;
	44)
		shell::logger::error "Repository '${_SK_REPO}' not found."
		return "$RETURN_NOT_FOUND"
		;;
	3)
		shell::logger::error "Neither curl nor wget is installed."
		return "$RETURN_NOT_FOUND"
		;;
	*)
		shell::logger::error "Could not list the branches of ${_SK_REPO} (network error or rate limit)."
		return "$RETURN_FAILURE"
		;;
	esac
	while IFS= read -r b; do
		[ -n "$b" ] || continue
		if [ "$b" = "$_SK_BRANCH" ]; then printf '* %s\n' "$b"; else printf '  %s\n' "$b"; fi
	done <<EOF
$out
EOF
}

# @description Delete the downloaded cache (index, ETag and file contents) of the repository and branch, or of everything with
#   `--all`. Installed prompts and their locks are not touched.
# @option -n Optional dry-run flag. The command is printed and nothing is deleted.
# @option --all Optional. Clear the cache of every repository and branch.
# @option --repo <owner/repo> Optional. Another repository.
# @option --branch <name> Optional. Another branch.
# @option -h | --help Show help and return.
# @exitcode 0 Cleared (or nothing to clear, or dry-run).
# @exitcode 1 The removal failed.
# @exitcode 2 Invalid option.
# @example
#   shell::prompt::skills::cache::clear
#   shell::prompt::skills::cache::clear --all
#
shell::prompt::skills::cache::clear() {
	case "${1-}" in
	-h | --help)
		_shell::prompt::help "Delete the downloaded skills cache" "shell::prompt::skills::cache::clear [-n] [--all] [--repo <o/r>] [--branch <b>]" \
			"shell::prompt::skills::cache::clear" "-n::Dry-run: print the command instead of executing it" "--all::Every repository and branch" \
			"--repo <owner/repo>::Another repository" "--branch <name>::Another branch" "-h, --help::Display this help message"
		return "$RETURN_SUCCESS"
		;;
	esac
	local all="false" args=() a
	for a in "$@"; do
		if [ "$a" = "--all" ]; then all="true"; else args+=("$a"); fi
	done
	_shell::prompt::skills::parse "n" ${args[@]+"${args[@]}"} || return $?
	local target
	if [ "$all" = "true" ]; then
		target="${XDG_CACHE_HOME:-$HOME/.cache}/shell/skills"
	else
		target="$(_shell::prompt::skills::cache_dir)"
	fi
	case "$target" in
	*/shell/skills | */shell/skills/*__*/*) ;;
	*)
		shell::logger::error "Refusing to clear an unexpected path."
		return "$RETURN_FAILURE"
		;;
	esac
	if [ "$_SK_DRY" = "true" ]; then
		shell::logger::command_clip "rm -rf $(printf '%q' "$target")"
		return "$RETURN_SUCCESS"
	fi
	if [ ! -d "$target" ]; then
		shell::logger::info "Nothing to clear"
		return "$RETURN_SUCCESS"
	fi
	rm -rf -- "$target" || return "$RETURN_FAILURE"
	shell::logger::success "Cleared the skills cache ($target)"
}
