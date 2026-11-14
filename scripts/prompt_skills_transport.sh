#!/bin/sh
# Transport of the Prompt Skills Sync (src/lib/prompt_skills.sh): the ONLY place that talks to GitHub (or to a
# fixture directory in tests). Plain POSIX sh with no shell::* dependency, so the fzf preview subshell and the
# background prefetch can run it too.
#
# Usage: prompt_skills_transport.sh <command> [args]
#   index <out.tsv>             write `path<TAB>blob_sha<TAB>size` of every <SKILLS_PATH>/**/*.md of the branch
#   file <path> <blob_sha>      download one file into $SKILLS_BLOBS/<blob_sha> (sha verified)
#   archive <index.tsv|->       download the branch tarball once; fill $SKILLS_BLOBS and (optionally) write the index
#   branches                    print the branch names, one per line
#
# Environment (all set by the library): SKILLS_REPO (owner/repo), SKILLS_BRANCH, SKILLS_PATH, SKILLS_CACHE (cache dir
# of the branch), SKILLS_BLOBS (content-addressed files), SKILLS_LOCAL_DIR (fixture mode: <dir>/<branch>/<path>/...),
# SKILLS_LOG (optional request log), GITHUB_TOKEN (optional; only ever written to a private header file).
#
# Exit codes: 0 ok | 1 failure | 3 no downloader | 10 not modified (304) | 44 not found | 45 rate limited | 46 truncated.

set -u

umask 077
CONNECT="${SHELL_NET_CONNECT_TIMEOUT:-10}"
MAXTIME="${SHELL_PROMPT_SKILLS_MAX_TIME:-60}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/skills-tx.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

log_request() {
	[ -n "${SKILLS_LOG:-}" ] && printf '%s\n' "$1" >>"$SKILLS_LOG" 2>/dev/null
	return 0
}

# Blob SHA-1 exactly as git computes it: sha1("blob <size>\0" + content).
blobsha() {
	_size="$(wc -c <"$1" | tr -d ' ')"
	{
		printf 'blob %s\0' "$_size"
		cat "$1"
	} | if command -v sha1sum >/dev/null 2>&1; then sha1sum; else shasum -a 1; fi | cut -d' ' -f1
}

# Keep only safe relative paths: [A-Za-z0-9._/-], no "..", no leading "/" or ".", ends in .md, under $SKILLS_PATH/.
safe_paths() {
	awk -F'\t' -v base="$SKILLS_PATH/" '
		{ p = $1 }
		p !~ /^[A-Za-z0-9._\/-]+\.md$/ { next }
		p ~ /(^|\/)\.\.?(\/|$)/ || p ~ /\/\// || p ~ /(^|\/)\./ { next }
		substr(p, 1, length(base)) != base { next }
		{ print }'
}

# --- HTTP ---------------------------------------------------------------------------------------------
HDR="$WORK/auth"
if [ -n "${GITHUB_TOKEN:-}" ]; then
	printf 'Authorization: Bearer %s\n' "$GITHUB_TOKEN" >"$HDR"
fi

# http_get <url> <out> [etag-in-file] [headers-out]  -> prints the HTTP status; 000 on transport failure.
http_get() {
	_url="$1"
	_out="$2"
	_etag="${3:-}"
	_hdrout="${4:-$WORK/resp.hdr}"
	log_request "GET $_url"
	if command -v curl >/dev/null 2>&1; then
		set -- -sS -L --connect-timeout "$CONNECT" --max-time "$MAXTIME" --retry 2 -o "$_out" -D "$_hdrout" -w '%{http_code}'
		[ -f "$HDR" ] && set -- "$@" -H "@$HDR"
		if [ -n "$_etag" ] && [ -s "$_etag" ]; then
			set -- "$@" -H "If-None-Match: $(cat "$_etag")"
		fi
		curl "$@" "$_url" 2>/dev/null || printf '000'
	elif command -v wget >/dev/null 2>&1; then
		# wget cannot send a header from a file (a token on the command line would show in `ps`), cannot
		# make conditional requests and hides the status code: tokens and ETags are not supported here.
		: >"$_hdrout"
		if wget -q -T "$CONNECT" -t 3 -O "$_out" "$_url" 2>/dev/null; then printf '200'; else printf '404'; fi
	else
		printf '000'
		return 3
	fi
}

need_downloader() {
	if [ -n "${SKILLS_LOCAL_DIR:-}" ]; then return 0; fi
	command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || {
		printf 'Neither curl nor wget is installed.\n' >&2
		exit 3
	}
}

# Map an HTTP status of the API to an exit code (rate limit = 403/429 with the limit exhausted).
status_exit() {
	case "$1" in
	200) return 0 ;;
	304) return 10 ;;
	404) return 44 ;;
	429) return 45 ;;
	403)
		if grep -qi '^x-ratelimit-remaining: *0' "${2:-$WORK/resp.hdr}" 2>/dev/null || grep -qi 'rate limit' "${3:-/dev/null}" 2>/dev/null; then return 45; fi
		return 1
		;;
	*) return 1 ;;
	esac
}

# --- JSON (POSIX): the Trees API answer -> path<TAB>sha<TAB>size of the blobs --------------------------
parse_tree() {
	tr -d '\n\r' <"$1" | sed 's/{/\
{/g' | awk '
		function field(s, k,   r) {
			if (match(s, "\"" k "\" *: *\"[^\"]*\"")) { r = substr(s, RSTART, RLENGTH); sub("^\"" k "\" *: *\"", "", r); sub("\"$", "", r); return r }
			if (match(s, "\"" k "\" *: *[0-9]+")) { r = substr(s, RSTART, RLENGTH); sub("^\"" k "\" *: *", "", r); return r }
			return ""
		}
		/"type" *: *"blob"/ { p = field($0, "path"); s = field($0, "sha"); z = field($0, "size"); if (p != "" && s != "") printf "%s\t%s\t%s\n", p, s, z }'
}

# --- Fixture mode ----------------------------------------------------------------------------------------
fixture_root() {
	printf '%s/%s\n' "$SKILLS_LOCAL_DIR" "$SKILLS_BRANCH"
}

fixture_index() {
	_root="$(fixture_root)"
	[ -d "$_root/$SKILLS_PATH" ] || return 44
	log_request "fixture index $SKILLS_BRANCH"
	(cd "$_root" && find "$SKILLS_PATH" -type f -name '*.md' ! -type l | LC_ALL=C sort) | while IFS= read -r _p; do
		printf '%s\t%s\t%s\n' "$_p" "$(blobsha "$_root/$_p")" "$(wc -c <"$_root/$_p" | tr -d ' ')"
	done | safe_paths >"$1"
}

# --- Commands --------------------------------------------------------------------------------------------
cmd_index() {
	out="${1:?index needs an output file}"
	if [ -n "${SKILLS_LOCAL_DIR:-}" ]; then
		fixture_index "$WORK/idx" || exit $?
		mv -f "$WORK/idx" "$out"
		return 0
	fi
	need_downloader
	api_ref="$(printf '%s' "$SKILLS_BRANCH" | sed 's#/#%2F#g')"
	etag_file="${SKILLS_CACHE:-$WORK}/index.etag"
	code="$(http_get "https://api.github.com/repos/$SKILLS_REPO/git/trees/$api_ref?recursive=1" "$WORK/tree.json" "$etag_file" "$WORK/resp.hdr")"
	status_exit "$code" "$WORK/resp.hdr" "$WORK/tree.json"
	rc=$?
	[ "$rc" -eq 0 ] || exit "$rc"
	if grep -Eq '"truncated" *: *true' "$WORK/tree.json"; then exit 46; fi
	parse_tree "$WORK/tree.json" | safe_paths >"$out.tmp" || exit 1
	mv -f "$out.tmp" "$out"
	# Remember the ETag for the next conditional request.
	tag="$(sed -n 's/^[Ee][Tt][Aa][Gg]: *//p' "$WORK/resp.hdr" | tail -n 1 | tr -d '\r')"
	if [ -n "$tag" ] && [ -n "${SKILLS_CACHE:-}" ]; then printf '%s' "$tag" >"$etag_file"; fi
	return 0
}

cmd_file() {
	path="${1:?file needs a path}"
	sha="${2:?file needs a blob sha}"
	dest="$SKILLS_BLOBS/$sha"
	[ -f "$dest" ] && exit 0
	mkdir -p "$SKILLS_BLOBS" || exit 1
	if [ -n "${SKILLS_LOCAL_DIR:-}" ]; then
		log_request "fixture file $path"
		src="$(fixture_root)/$path"
		[ -f "$src" ] && [ ! -L "$src" ] || exit 44
		cp "$src" "$WORK/blob" || exit 1
	else
		need_downloader
		code="$(http_get "https://raw.githubusercontent.com/$SKILLS_REPO/$SKILLS_BRANCH/$path" "$WORK/blob" "" "$WORK/resp.hdr")"
		case "$code" in
		200) ;;
		404) exit 44 ;;
		*) exit 1 ;;
		esac
	fi
	# Integrity: the content must be the blob the index announced (it also catches a branch moved meanwhile).
	[ "$(blobsha "$WORK/blob")" = "$sha" ] || {
		printf 'Checksum mismatch for %s (the branch changed; refresh the index).\n' "$path" >&2
		exit 1
	}
	chmod 600 "$WORK/blob"
	mv -f "$WORK/blob" "$dest.$$" && mv -f "$dest.$$" "$dest"
}

cmd_archive() {
	index_out="${1:--}"
	mkdir -p "$SKILLS_BLOBS" "$WORK/x" || exit 1
	if [ -n "${SKILLS_LOCAL_DIR:-}" ]; then
		log_request "fixture archive $SKILLS_BRANCH"
		root="$(fixture_root)"
		[ -d "$root/$SKILLS_PATH" ] || exit 44
		(cd "$root" && find "$SKILLS_PATH" -type f ! -type l -name '*.md' -exec sh -c 'for f; do mkdir -p "$0/$(dirname "$f")" && cp "$f" "$0/$f"; done' "$WORK/x" {} +)
	else
		need_downloader
		code="$(http_get "https://codeload.github.com/$SKILLS_REPO/tar.gz/refs/heads/$SKILLS_BRANCH" "$WORK/repo.tgz" "" "$WORK/resp.hdr")"
		case "$code" in
		200) ;;
		404) exit 44 ;;
		*) exit 1 ;;
		esac
		# Member names of regular files only (a symlink, hardlink or odd name is never extracted); the first
		# path component is GitHub's "<repo>-<ref>/" wrapper.
		tar -tvzf "$WORK/repo.tgz" 2>/dev/null | awk '
			substr($0, 1, 1) != "-" { next }
			/ -> | link to / { next }
			{ print $NF }' >"$WORK/members" || exit 1
		awk -v base="$SKILLS_PATH/" '
			{ n = index($0, "/"); if (n == 0) next; r = substr($0, n + 1) }
			r !~ /^[A-Za-z0-9._\/-]+\.md$/ || r ~ /(^|\/)\.\.?(\/|$)/ || r ~ /\/\// || r ~ /(^|\/)\./ { next }
			substr(r, 1, length(base)) != base { next }
			{ print $0 }' "$WORK/members" >"$WORK/wanted_members"
		if [ -s "$WORK/wanted_members" ]; then
			(cd "$WORK/x" && tar -xzf "$WORK/repo.tgz" --strip-components=1 -T "$WORK/wanted_members") || exit 1
		fi
	fi
	: >"$WORK/archive.idx"
	(cd "$WORK/x" && find . -type f ! -type l -name '*.md' 2>/dev/null | sed 's#^\./##' | LC_ALL=C sort) | while IFS= read -r p; do
		s="$(blobsha "$WORK/x/$p")"
		[ -f "$SKILLS_BLOBS/$s" ] || {
			cp "$WORK/x/$p" "$SKILLS_BLOBS/$s.$$" && chmod 600 "$SKILLS_BLOBS/$s.$$" && mv -f "$SKILLS_BLOBS/$s.$$" "$SKILLS_BLOBS/$s"
		}
		printf '%s\t%s\t%s\n' "$p" "$s" "$(wc -c <"$WORK/x/$p" | tr -d ' ')"
	done | safe_paths >"$WORK/archive.idx"
	[ "$index_out" = "-" ] || mv -f "$WORK/archive.idx" "$index_out"
	return 0
}

cmd_branches() {
	if [ -n "${SKILLS_LOCAL_DIR:-}" ]; then
		[ -d "$SKILLS_LOCAL_DIR" ] || exit 44
		(cd "$SKILLS_LOCAL_DIR" && find . -mindepth 1 -maxdepth 1 -type d | sed 's#^\./##' | LC_ALL=C sort)
		return 0
	fi
	need_downloader
	code="$(http_get "https://api.github.com/repos/$SKILLS_REPO/branches?per_page=100" "$WORK/branches.json" "" "$WORK/resp.hdr")"
	status_exit "$code" "$WORK/resp.hdr" "$WORK/branches.json"
	rc=$?
	[ "$rc" -eq 0 ] || exit "$rc"
	tr -d '\n\r' <"$WORK/branches.json" | sed 's/{/\
{/g' | sed -n 's/^{ *"name" *: *"\([^"]*\)".*/\1/p'
}

cmd="${1:-}"
[ "$#" -gt 0 ] && shift
case "$cmd" in
index) cmd_index "$@" ;;
file) cmd_file "$@" ;;
archive) cmd_archive "$@" ;;
branches) cmd_branches ;;
*)
	printf 'usage: %s index|file|archive|branches\n' "$0" >&2
	exit 2
	;;
esac
