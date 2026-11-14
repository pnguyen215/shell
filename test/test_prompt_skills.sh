#!/usr/bin/env bash
# shell::prompt::skills::* (src/lib/prompt_skills.sh, scripts/prompt_skills_transport.sh): branch validation, index parsing
# and filtering, install / idempotent re-install / update / local modification / --force / conflicts / remove / rename,
# dry-run, path traversal, byte-exact bodies, copy. Nothing touches the network: fixture mode reads $HOME/fx/<branch>/prompts,
# and a fake `curl` on PATH serves canned GitHub answers for the HTTP paths (ETag, tarball fallback, 404, rate limit).
# The interactive menus are covered by test_prompt_skills_fzf.sh.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

t_lacks() { case "$3" in *"$2"*) t_bad "$1" "[$2] unexpectedly present in [$3]" ;; *) t_ok ;; esac }
sum_dir() { (cd "$1" && find . -type f | LC_ALL=C sort | xargs cksum 2>/dev/null); }
mode_of() { stat -f %Lp "$1" 2>/dev/null || stat -c %a "$1"; }
blobsha() { {
	printf 'blob %s\0' "$(wc -c <"$1" | tr -d ' ')"
	cat "$1"
} | { sha1sum 2>/dev/null || shasum -a 1; } | cut -d' ' -f1; }

mkdir "$HOME/bin" "$HOME/tmp" "$HOME/proj"
cat >"$HOME/bin/pbcopy" <<'FAKE'
#!/bin/sh
cat >>"$FAKE_CLIP"
printf '|' >>"$FAKE_CLIP"
FAKE
chmod +x "$HOME/bin/pbcopy"
export PATH="$HOME/bin:$PATH" FAKE_CLIP="$HOME/clip.log" TMPDIR="$HOME/tmp"
export SHELL_PROMPT_DIR="$HOME/store" XDG_CACHE_HOME="$HOME/cache"
S="$SHELL_PROMPT_DIR"
CACHE="$XDG_CACHE_HOME/shell/skills/pnguyen215__skills"
clip() { cat "$FAKE_CLIP" 2>/dev/null; }

# --- fixture repository ---------------------------------------------------------------------------------
FX="$HOME/fx"
mkdir -p "$FX/master/prompts/review" "$FX/master/prompts/writing" "$FX/master/prompts/a" "$FX/master/prompts/b" "$FX/dev/prompts"
SPECIAL='You are "strict" $HOME `date` %s \n back\slash & é 日本 {not} {{ }} ~'
printf '**Role:** Expert.\n\n%s\n\n  indented\n\n\n' "$SPECIAL" >"$FX/master/prompts/skill-optimizer.md"
printf -- '---\ntitle: Code Review\ndescription: Strict reviewer\ntags: Bash, Quality\n---\nReview {{lang|bash}} code\nsecond line\n' >"$FX/master/prompts/review/Code_Review.md"
printf '# Summary Writer\nSummarise {{topic}}.\n' >"$FX/master/prompts/writing/summary.md"
printf 'one\n' >"$FX/master/prompts/a/same.md"
printf 'two\n' >"$FX/master/prompts/b/same.md"
printf 'not a prompt\n' >"$FX/master/prompts/readme.txt"
printf 'no final newline' >"$FX/master/prompts/nonl.md"
printf '# Dev Prompt\nbody\n' >"$FX/dev/prompts/dev-one.md"
export SHELL_PROMPT_SKILLS_LOCAL_DIR="$FX"

# --- validation --------------------------------------------------------------------------------------------
for ok in master develop feature/x v1.2 a_b-c; do t_rc "valid_branch accepts $ok" 0 _shell::prompt::skills::valid_branch "$ok"; done
for bad in "" "-x" "/x" "x/" "a..b" "a//b" "a b" 'a;b' 'a$b' 'x.lock' "$(printf 'a\tb')"; do
	t_rc "valid_branch rejects '$bad'" 1 _shell::prompt::skills::valid_branch "$bad"
done
t_rc "valid_repo accepts owner/repo" 0 _shell::prompt::skills::valid_repo "pnguyen215/skills"
for bad in "" "x" "a/b/c" "../x" "a b/c" "/a/b" "-a/b"; do t_rc "valid_repo rejects '$bad'" 1 _shell::prompt::skills::valid_repo "$bad"; done
t_rc "--branch with an invalid name is rejected" 2 shell::prompt::skills::list --branch '../x'
t_rc "--branch needs a value" 2 shell::prompt::skills::list --branch
t_rc "--repo with an invalid name is rejected" 2 shell::prompt::skills::list --repo 'bad repo'
t_rc "unknown option is rejected" 2 shell::prompt::skills::list --bogus
t_rc "list: an option of another function is rejected" 2 shell::prompt::skills::list --force
t_rc "help" 0 shell::prompt::skills::pick --help
t_has "help names the function" "shell::prompt::skills::pick" "$T_OUT"

# --- index, mapping, listing -------------------------------------------------------------------------------
t_eq "list: slugs (non-.md ignored, collisions prefixed with the directory)" "a-same
b-same
code-review
nonl
skill-optimizer
summary" "$(shell::prompt::skills::list | cut -f2)"
t_eq "list: nothing installed yet" "-" "$(shell::prompt::skills::list | cut -f1 | sort -u)"
t_eq "list: directories become tags" "review" "$(shell::prompt::skills::list | awk -F'\t' '$2 == "code-review" { print $4 }')"
t_eq "list --tag" "code-review" "$(shell::prompt::skills::list --tag review | cut -f2)"
t_eq "list --installed is empty" "" "$(shell::prompt::skills::list --installed)"
t_eq "list --available" "6" "$(shell::prompt::skills::list --available | wc -l | tr -d ' ')"
t_eq "list: title from the file name" "Skill Optimizer" "$(shell::prompt::skills::list | awk -F'\t' '$2 == "skill-optimizer" { print $3 }')"
t_eq "the blob sha is git's" "$(blobsha "$FX/master/prompts/skill-optimizer.md")" "$(_shell::prompt::skills::reset && _shell::prompt::skills::tx index "$HOME/idx.tsv" && awk -F'\t' '$1 == "prompts/skill-optimizer.md" { print $2 }' "$HOME/idx.tsv")"
if command -v git >/dev/null 2>&1; then
	t_eq "the blob sha equals git hash-object" "$(git hash-object "$FX/master/prompts/skill-optimizer.md")" "$(blobsha "$FX/master/prompts/skill-optimizer.md")"
fi
t_eq "cache directory is 700" "700" "$(mode_of "$CACHE/master")"

# --- view / copy (no install) -------------------------------------------------------------------------------
t_eq "view prints the file byte for byte" "$(cksum <"$FX/master/prompts/skill-optimizer.md")" "$(shell::prompt::skills::view skill-optimizer | cksum)"
t_rc "view: unknown prompt" 3 shell::prompt::skills::view nope
t_rc "view: needs one name" 2 shell::prompt::skills::view
t_eq "view installs nothing" "no" "$([ -e "$S" ] && echo yes || echo no)"
t_rc "copy: dry-run copies nothing" 0 shell::prompt::skills::copy -n skill-optimizer
t_lacks "copy -n copied the command, not the body" "Expert" "$(clip)"
rm -f "$FAKE_CLIP"
t_rc "copy: multi-line prompt" 0 shell::prompt::skills::copy skill-optimizer
t_eq "copy: byte-exact (quotes, \$, backticks, %, unicode, blank lines)" "$(cksum <"$FX/master/prompts/skill-optimizer.md")" "$(printf '%s' "$(clip)" | sed 's/|$//' | cksum)"
rm -f "$FAKE_CLIP"
t_rc "copy: placeholders filled" 0 shell::prompt::skills::copy code-review lang=zsh
t_eq "copy: rendered text" "Review zsh code
second line
|" "$(clip)"
t_rc "copy: a placeholder without value" 2 shell::prompt::skills::copy summary
t_rc "copy: bad name=value" 2 shell::prompt::skills::copy summary topic
t_eq "copy installed nothing" "no" "$([ -e "$S" ] && echo yes || echo no)"
t_lacks "copy never logs the body" "strict" "$(shell::prompt::skills::copy skill-optimizer 2>&1)"

# --- pick: install, byte-exact, idempotent ----------------------------------------------------------------------
t_rc "pick: install" 0 shell::prompt::skills::pick skill-optimizer
t_has "pick: summary line" "Summary: installed=1 updated=0 uptodate=0 skipped=0 failed=0" "$T_OUT"
t_eq "installed body is byte-exact (special characters, blank lines)" "$(cksum <"$FX/master/prompts/skill-optimizer.md")" "$(shell::prompt::get skill-optimizer | cksum)"
t_eq "installed file mode" "600" "$(mode_of "$S/skill-optimizer.md")"
t_eq "store directory mode" "700" "$(mode_of "$S")"
t_eq "lock mode" "600" "$(mode_of "$S/.skills.lock")"
t_eq "lock has 7 tab-separated fields" "7" "$(awk -F'\t' '{ print NF }' "$S/.skills.lock")"
t_eq "lock records repo, branch and path" "skill-optimizer	pnguyen215/skills	master	prompts/skill-optimizer.md" "$(cut -f1-4 "$S/.skills.lock")"
t_eq "lock records the blob sha" "$(blobsha "$FX/master/prompts/skill-optimizer.md")" "$(cut -f5 "$S/.skills.lock")"
t_eq "lock records the sha256 of the installed file" "$(shasum -a 256 "$S/skill-optimizer.md" | cut -d' ' -f1)" "$(cut -f7 "$S/.skills.lock")"
t_eq "the title comes from the file name" "Skill Optimizer" "$(_shell::prompt::meta "$S/skill-optimizer.md" title)"
t_has "existing prompt functions work on it" "skill-optimizer" "$(shell::prompt::list)"
t_eq "list shows it as installed" "G" "$(shell::prompt::skills::list | awk -F'\t' '$2 == "skill-optimizer" { print $1 }')"
before="$(sum_dir "$S")"
t_rc "pick again is a no-op" 0 shell::prompt::skills::pick skill-optimizer
t_has "second pick: up to date" "uptodate=1" "$T_OUT"
t_eq "second pick wrote nothing" "$before" "$(sum_dir "$S")"
t_eq "no snapshot was taken" "0" "$(find "$S/.history" -type f 2>/dev/null | wc -l | tr -d ' ')"

# front matter is reused; directory tags are merged
t_rc "pick: file with front matter" 0 shell::prompt::skills::pick code-review
t_eq "front matter: title" "Code Review" "$(_shell::prompt::meta "$S/code-review.md" title)"
t_eq "front matter: description" "Strict reviewer" "$(_shell::prompt::meta "$S/code-review.md" description)"
t_eq "front matter: tags merged with the directory" "bash,quality,review" "$(_shell::prompt::meta "$S/code-review.md" tags)"
t_eq "front matter: body" "Review {{lang|bash}} code
second line" "$(shell::prompt::get code-review)"
t_rc "pick: heading becomes the title" 0 shell::prompt::skills::pick summary
t_eq "heading title" "Summary Writer" "$(_shell::prompt::meta "$S/summary.md" title)"
t_eq "heading file keeps its first line in the body" "# Summary Writer" "$(shell::prompt::get summary | head -n 1)"
t_eq "directory tag" "writing" "$(_shell::prompt::meta "$S/summary.md" tags)"
t_rc "pick: no final newline survives" 0 shell::prompt::skills::pick nonl
t_eq "missing final newline kept (bytes)" "16" "$(shell::prompt::get nonl | wc -c | tr -d ' ')"

# --- conflicts ---------------------------------------------------------------------------------------------------
printf 'my own\n' | shell::prompt::add "Same" - >/dev/null 2>&1
printf 'remote same\n' >"$FX/master/prompts/same.md"
t_rc "untracked slug: refused" 7 shell::prompt::skills::pick same
t_has "untracked slug: skipped in the summary" "skipped=1" "$T_OUT"
t_eq "untracked prompt is untouched" "my own" "$(shell::prompt::get same)"
t_rc "--as installs under another slug" 0 shell::prompt::skills::pick --as same-remote same
t_eq "--as content" "remote same" "$(shell::prompt::get same-remote)"
t_rc "--as with two names" 2 shell::prompt::skills::pick --as x same nonl
t_rc "--as with an invalid slug" 2 shell::prompt::skills::pick --as 'Bad Slug' same
t_rc "--force replaces the untracked prompt" 0 shell::prompt::skills::pick --force same
t_eq "forced content" "remote same" "$(shell::prompt::get same)"
t_eq "--force snapshotted yours" "my own" "$(cat "$S/.history/same/"*.md | sed -n '/^---$/,$p' | tail -n 1)"
t_rc "pick: unknown name" 3 shell::prompt::skills::pick nope
t_rc "pick: no name" 2 shell::prompt::skills::pick
t_rc "pick: path traversal as a name" 3 shell::prompt::skills::pick '../../etc/passwd'
t_rc "pick: invalid --as is a slug error" 2 shell::prompt::skills::pick --as '../x' summary

# --- update ------------------------------------------------------------------------------------------------------
t_eq "status: clean" "Summary: repo=pnguyen215/skills branch=master tracked=6 outdated=0 modified=0 missing_remote=0 missing_file=0" "$(shell::prompt::skills::status)"
printf '# Summary Writer\nSummarise {{topic}} in v2.\n' >"$FX/master/prompts/writing/summary.md"
t_has "status: outdated" "outdated	G	summary" "$(shell::prompt::skills::status)"
t_eq "list marks the update" "G*" "$(shell::prompt::skills::list | awk -F'\t' '$2 == "summary" { print $1 }')"
t_eq "list --outdated" "summary" "$(shell::prompt::skills::list --outdated | cut -f2)"
before="$(sum_dir "$S")"
t_rc "update -n" 0 shell::prompt::skills::update -n
t_has "update -n prints the command" "install pnguyen215/skills@master:prompts/writing/summary.md" "$T_OUT"
t_eq "update -n wrote nothing" "$before" "$(sum_dir "$S")"
t_rc "update" 0 shell::prompt::skills::update
t_has "update: one updated" "updated=1" "$T_OUT"
t_eq "updated body" "Summarise {{topic}} in v2." "$(shell::prompt::get summary | tail -n 1)"
t_eq "update snapshotted the old version" "1" "$(find "$S/.history/summary" -type f | wc -l | tr -d ' ')"
t_eq "lock holds the new sha" "$(blobsha "$FX/master/prompts/writing/summary.md")" "$(awk -F'\t' '$1 == "summary" { print $5 }' "$S/.skills.lock")"
t_eq "created is kept on update" "$(_shell::prompt::meta "$S/summary.md" created)" "$(_shell::prompt::meta "$S/summary.md" created)"
before="$(sum_dir "$S")"
t_rc "update again is a no-op" 0 shell::prompt::skills::update
t_eq "second update wrote nothing" "$before" "$(sum_dir "$S")"
t_rc "update a named prompt that is up to date" 0 shell::prompt::skills::update summary

# --- local modification --------------------------------------------------------------------------------------------
printf 'MY EDIT\n' >>"$S/skill-optimizer.md"
t_eq "list marks the local change" "G!" "$(shell::prompt::skills::list | awk -F'\t' '$2 == "skill-optimizer" { print $1 }')"
t_has "status: modified" "modified	G	skill-optimizer" "$(shell::prompt::skills::status)"
printf '**Role:** Expert v2.\n' >"$FX/master/prompts/skill-optimizer.md"
mine="$(cksum <"$S/skill-optimizer.md")"
t_rc "update skips a modified prompt" 0 shell::prompt::skills::update
t_has "skip is reported" "modified locally" "$T_OUT"
t_eq "modified prompt untouched" "$mine" "$(cksum <"$S/skill-optimizer.md")"
t_rc "pick of a modified prompt is skipped too" 7 shell::prompt::skills::pick skill-optimizer
t_eq "pick left it alone" "$mine" "$(cksum <"$S/skill-optimizer.md")"
t_rc "update --force -n shows the command" 0 shell::prompt::skills::update --force -n
t_eq "update --force -n wrote nothing" "$mine" "$(cksum <"$S/skill-optimizer.md")"
t_rc "update --force" 0 shell::prompt::skills::update --force
t_eq "--force restored the remote version" "**Role:** Expert v2." "$(shell::prompt::get skill-optimizer)"
t_has "history keeps the modified version" "MY EDIT" "$(cat "$S/.history/skill-optimizer/"*.md)"
t_eq "status is clean again" "outdated=0 modified=0" "$(shell::prompt::skills::status | sed -n 's/.*\(outdated=0 modified=0\).*/\1/p')"
printf 'LOCAL\n' >>"$S/nonl.md"
t_rc "modified and remote unchanged: --force restores" 0 shell::prompt::skills::update --force nonl
t_eq "restored" "no final newline" "$(shell::prompt::get nonl)"

# --- remove / rename / clone ----------------------------------------------------------------------------------------
t_rc "remove: a user-made prompt is refused" 3 shell::prompt::skills::remove -y same-remote nope
t_rc "remove: user-made prompt (untracked slug)" 3 shell::prompt::skills::remove -y mine
t_rc "remove: no name" 2 shell::prompt::skills::remove
before="$(sum_dir "$S")"
t_rc "remove -n" 0 shell::prompt::skills::remove -n summary
t_eq "remove -n wrote nothing" "$before" "$(sum_dir "$S")"
t_rc "remove" 0 shell::prompt::skills::remove -y summary
t_eq "removed" "no" "$([ -e "$S/summary.md" ] && echo yes || echo no)"
t_eq "lock entry is gone" "0" "$(grep -c '^summary	' "$S/.skills.lock")"
t_has "history keeps it" "Summarise" "$(cat "$S/.history/summary/"*.md)"
t_rc "restore from history" 0 shell::prompt::restore summary "$(shell::prompt::history summary | tail -n 1 | cut -f1)"
t_eq "restored prompt exists" "yes" "$([ -e "$S/summary.md" ] && echo yes || echo no)"
t_eq "a restored prompt is no longer tracked" "0" "$(grep -c '^summary	' "$S/.skills.lock")"
t_rc "rename" 0 shell::prompt::rename nonl no-newline
t_eq "rename moved the lock entry" "no-newline	pnguyen215/skills	master	prompts/nonl.md" "$(awk -F'\t' '$1 == "no-newline" { print $1 "\t" $2 "\t" $3 "\t" $4 }' "$S/.skills.lock")"
t_eq "rename left no old lock entry" "0" "$(grep -c '^nonl	' "$S/.skills.lock")"
t_eq "renamed prompt is still tracked (status)" "G" "$(shell::prompt::skills::list | awk -F'\t' '$2 == "nonl" { print $1 }')"
t_rc "clone" 0 shell::prompt::clone no-newline no-newline-copy
t_eq "clone does not copy the lock entry" "0" "$(grep -c '^no-newline-copy	' "$S/.skills.lock")"
t_rc "remove: the cloned prompt is not an installed skill" 3 shell::prompt::skills::remove -y no-newline-copy
t_rc "remove the renamed one" 0 shell::prompt::skills::remove -y no-newline
t_eq "lock only keeps the other entries" "0" "$(grep -c '^no-newline	' "$S/.skills.lock")"
rm "$S/code-review.md"
t_has "a lock entry without file is reported" "missing-file	G	code-review" "$(shell::prompt::skills::status)"
t_rc "re-install after the file vanished" 0 shell::prompt::skills::pick code-review
t_eq "back again" "yes" "$([ -e "$S/code-review.md" ] && echo yes || echo no)"
rm "$S/skill-optimizer.md"
t_rc "remove drops a stale lock entry (file missing)" 0 shell::prompt::skills::remove -y skill-optimizer
t_eq "the stale entry is gone" "0" "$(grep -c '^skill-optimizer	' "$S/.skills.lock")"

# --- install::all, dry-run, personal store ---------------------------------------------------------------------------
export SHELL_PROMPT_DIR="$HOME/store2"
S="$SHELL_PROMPT_DIR"
t_rc "install::all -n" 0 shell::prompt::skills::install::all -n
t_has "dry-run prints commands" "install pnguyen215/skills@master:prompts/review/Code_Review.md" "$T_OUT"
t_eq "dry-run created no store" "no" "$([ -e "$S" ] && echo yes || echo no)"
t_rc "install::all" 0 shell::prompt::skills::install::all
t_has "install::all: summary" "Summary: installed=7 updated=0 uptodate=0 skipped=0 failed=0" "$T_OUT"
t_has "install::all: progress" "[7/7]" "$T_OUT"
before="$(sum_dir "$S")"
t_rc "install::all again" 0 shell::prompt::skills::install::all
t_has "install::all again: no-op" "installed=0 updated=0 uptodate=7" "$T_OUT"
t_eq "install::all again wrote nothing" "$before" "$(sum_dir "$S")"
t_rc "install::all takes no names" 2 shell::prompt::skills::install::all x
cd "$HOME/proj" || exit 1
t_rc "install::all --personal" 0 shell::prompt::skills::install::all --personal
t_has "personal: tip about .gitignore" "git-ignored" "$T_OUT"
t_eq "personal store is under the project" "yes" "$([ -f "$HOME/proj/.prompts/skill-optimizer.md" ] && echo yes || echo no)"
t_eq "personal lock" "7" "$(wc -l <"$HOME/proj/.prompts/.skills.lock" | tr -d ' ')"
t_eq "list shows both stores" "G,P" "$(shell::prompt::skills::list | awk -F'\t' '$2 == "summary" { print $1 }')"
t_eq "gitignore is never edited" "no" "$([ -e "$HOME/proj/.gitignore" ] && echo yes || echo no)"
t_rc "remove --personal" 0 shell::prompt::skills::remove -y --personal summary
t_eq "removed from the personal store only" "G" "$(shell::prompt::skills::list | awk -F'\t' '$2 == "summary" { print $1 }')"
t_rc "update --personal" 0 shell::prompt::skills::update --personal
cd "$HOME" || exit 1

# --- branches --------------------------------------------------------------------------------------------------------
t_eq "branches" "  dev
* master" "$(shell::prompt::skills::branches)"
t_eq "list --branch dev" "dev-one" "$(shell::prompt::skills::list --branch dev | cut -f2)"
t_rc "unknown branch" 3 shell::prompt::skills::list --branch nope
t_has "unknown branch: clear message" "Branch 'nope' not found in pnguyen215/skills" "$T_OUT"
t_has "unknown branch: hint" "shell::prompt::skills::branches" "$T_OUT"
t_rc "the branch is never silently replaced" 3 shell::prompt::skills::pick --branch nope summary
t_rc "pick from another branch" 0 shell::prompt::skills::pick --branch dev dev-one
t_eq "lock records the branch" "dev" "$(awk -F'\t' '$1 == "dev-one" { print $3 }' "$S/.skills.lock")"
t_eq "the cache is per branch" "yes" "$([ -d "$CACHE/dev/blobs" ] && [ -d "$CACHE/master/blobs" ] && echo yes || echo no)"
printf '# Dev Prompt\nbody v2\n' >"$FX/dev/prompts/dev-one.md"
t_has "status compares with the recorded branch" "outdated	G	dev-one" "$(shell::prompt::skills::status)"
t_rc "update follows the recorded branch" 0 shell::prompt::skills::update dev-one
t_eq "updated from dev" "body v2" "$(shell::prompt::get dev-one | tail -n 1)"
t_rc "update --branch switches (dry-run shows it)" 0 shell::prompt::skills::update -n --branch master dev-one
t_has "switching reports that the prompt is gone there" "no longer exists" "$T_OUT"
cp -R "$FX/master" "$FX/release%2Fx" 2>/dev/null
mkdir -p "$FX/rel/one/prompts" && printf 'slashed\n' >"$FX/rel/one/prompts/slashed.md"
t_eq "a branch with a slash" "slashed" "$(shell::prompt::skills::list --branch rel/one | cut -f2)"
t_eq "a branch with a slash: cache dir is encoded" "yes" "$([ -d "$CACHE/rel%2Fone" ] && echo yes || echo no)"

# --- cache -----------------------------------------------------------------------------------------------------------
t_rc "cache::clear -n" 0 shell::prompt::skills::cache::clear -n
t_eq "cache::clear -n kept the cache" "yes" "$([ -d "$CACHE/master" ] && echo yes || echo no)"
t_rc "cache::clear" 0 shell::prompt::skills::cache::clear
t_eq "cache::clear removed this branch" "no" "$([ -d "$CACHE/master" ] && echo yes || echo no)"
t_eq "...and kept the others" "yes" "$([ -d "$CACHE/dev" ] && echo yes || echo no)"
t_rc "cache::clear --all" 0 shell::prompt::skills::cache::clear --all
t_eq "cache::clear --all" "no" "$([ -d "$XDG_CACHE_HOME/shell/skills" ] && echo yes || echo no)"
t_eq "installed prompts survive a cache clear" "yes" "$([ -f "$S/skill-optimizer.md" ] && echo yes || echo no)"
t_rc "cache::clear on an empty cache" 0 shell::prompt::skills::cache::clear

# --- HTTP paths with a fake curl (no network) --------------------------------------------------------------------------
unset SHELL_PROMPT_SKILLS_LOCAL_DIR
GH="$HOME/gh"
export FAKE_GH="$GH"
mkdir -p "$GH/raw/prompts/deep" "$GH/tar/skills-master/prompts"
cat >"$HOME/bin/curl" <<'FAKE'
#!/bin/sh
out=""; hdr=""; etag=""; url=""
while [ $# -gt 0 ]; do
	case "$1" in
	-o) out="$2"; shift ;;
	-D) hdr="$2"; shift ;;
	-w) shift ;;
	-H) case "$2" in If-None-Match:*) etag="${2#If-None-Match: }" ;; @*) [ -f "${2#@}" ] && cp "${2#@}" "$FAKE_GH/last-auth" ;; esac; shift ;;
	--connect-timeout | --max-time | --retry) shift ;;
	-*) ;;
	*) url="$1" ;;
	esac
	shift
done
printf '%s\n' "$url" >>"$FAKE_GH/requests"
code=200
case "$url" in
*/git/trees/*)
	code="$(cat "$FAKE_GH/tree.code" 2>/dev/null || echo 200)"
	if [ "$etag" = '"v1"' ] && [ "$code" = 200 ]; then code=304; : >"$out"; else cp "$FAKE_GH/tree.json" "$out"; fi
	printf 'ETag: "v1"\r\nX-RateLimit-Remaining: %s\r\n' "$(cat "$FAKE_GH/ratelimit" 2>/dev/null || echo 50)" >"$hdr"
	;;
*/repos/o/r/*) code=404; : >"$out" ;;
*/branches*) printf '[ {"name": "master"}, {"name": "dev"} ]' >"$out" ;;
https://raw.githubusercontent.com/*/master/*) f="$FAKE_GH/raw/${url#*/master/}"; if [ -f "$f" ]; then cp "$f" "$out"; else code=404; : >"$out"; fi ;;
https://codeload.github.com/*) cp "$FAKE_GH/repo.tgz" "$out" ;;
*) code=404; : >"$out" ;;
esac
printf '%s' "$code"
FAKE
chmod +x "$HOME/bin/curl"
printf 'alpha\n' >"$GH/raw/prompts/alpha.md"
printf '# Deep one\ndeep\n' >"$GH/raw/prompts/deep/deep-one.md"
tree() { # tree [extra-json-objects] -> $GH/tree.json (GitHub's pretty-printed shape)
	{
		printf '{\n  "sha": "abc",\n  "tree": [\n    { "path": "prompts", "mode": "040000", "type": "tree", "sha": "0000" },\n'
		for f in prompts/alpha.md prompts/deep/deep-one.md; do
			printf '    {\n      "path": "%s",\n      "mode": "100644",\n      "type": "blob",\n      "sha": "%s",\n      "size": %s\n    },\n' "$f" "$(blobsha "$GH/raw/$f")" "$(wc -c <"$GH/raw/$f" | tr -d ' ')"
		done
		printf '%s\n' "${1-}"
		printf '    { "path": "README.md", "mode": "100644", "type": "blob", "sha": "1111", "size": 5 }\n  ],\n  "truncated": %s\n}\n' "${2:-false}"
	} >"$GH/tree.json"
}
# Hostile entries: traversal, absolute, hidden, odd characters, a symlink-looking blob, a non-.md file.
tree '    { "path": "prompts/../../etc/evil.md", "mode": "100644", "type": "blob", "sha": "2222", "size": 1 },
    { "path": "/abs/evil.md", "mode": "100644", "type": "blob", "sha": "3333", "size": 1 },
    { "path": "prompts/.hidden.md", "mode": "100644", "type": "blob", "sha": "4444", "size": 1 },
    { "path": "prompts/has space.md", "mode": "100644", "type": "blob", "sha": "5555", "size": 1 },
    { "path": "prompts/x;rm.md", "mode": "100644", "type": "blob", "sha": "6666", "size": 1 },
    { "path": "prompts/link.md", "mode": "120000", "type": "commit", "sha": "7777", "size": 1 },
    { "path": "prompts/notes.txt", "mode": "100644", "type": "blob", "sha": "8888", "size": 1 },
    { "path": "other/outside.md", "mode": "100644", "type": "blob", "sha": "9999", "size": 1 },'
export SHELL_PROMPT_DIR="$HOME/store3"
S="$SHELL_PROMPT_DIR"
export SHELL_PROMPT_SKILLS_CACHE_TTL=300
t_rc "http: list" 0 shell::prompt::skills::list
t_eq "http: only safe, in-path .md blobs are listed (traversal, absolute, hidden, odd names rejected)" "alpha
deep-one" "$(shell::prompt::skills::list | cut -f2)"
t_eq "http: one Trees API call" "1" "$(grep -c '/git/trees/master?recursive=1' "$GH/requests")"
t_has "http: the ref is URL-encoded and recursive" "https://api.github.com/repos/pnguyen215/skills/git/trees/master?recursive=1" "$(cat "$GH/requests")"
t_eq "http: a fresh index is not requested again" "1" "$(grep -c '/git/trees/' "$GH/requests")"
t_eq "http: no file was fetched to list" "0" "$(grep -c raw.githubusercontent "$GH/requests")"
t_eq "http: cache file mode" "600" "$(mode_of "$CACHE/master/index.tsv")"
SHELL_PROMPT_SKILLS_CACHE_TTL=0 shell::prompt::skills::list >/dev/null
t_eq "http: an expired index is revalidated" "2" "$(grep -c '/git/trees/' "$GH/requests")"
t_eq "http: the ETag is remembered" '"v1"' "$(cat "$CACHE/master/index.etag")"
t_eq "http: a 304 keeps the listing" "alpha
deep-one" "$(SHELL_PROMPT_SKILLS_CACHE_TTL=0 shell::prompt::skills::list | cut -f2)"
t_rc "http: view fetches one raw file" 0 shell::prompt::skills::view alpha
t_eq "http: view content" "alpha" "$(shell::prompt::skills::view alpha)"
t_eq "http: raw URL" "https://raw.githubusercontent.com/pnguyen215/skills/master/prompts/alpha.md" "$(grep raw.githubusercontent "$GH/requests" | head -n 1)"
t_eq "http: the file is cached (one raw request for two views)" "1" "$(grep -c raw.githubusercontent "$GH/requests")"
t_eq "http: content is cached by blob sha" "yes" "$([ -f "$CACHE/master/blobs/$(blobsha "$GH/raw/prompts/alpha.md")" ] && echo yes || echo no)"
t_rc "http: install" 0 shell::prompt::skills::pick alpha deep-one
t_eq "http: installed" "deep" "$(shell::prompt::get deep-one | tail -n 1)"
t_eq "http: nested directory becomes a tag" "deep" "$(_shell::prompt::meta "$S/deep-one.md" tags)"
t_eq "http: 2 files = 2 raw requests, no tarball" "0" "$(grep -c codeload "$GH/requests")"
# integrity: a branch that moved between the index and the download
printf 'tampered\n' >"$GH/raw/prompts/alpha.md"
rm -rf "$CACHE/master/blobs"
rm -f "$S/alpha.md"
t_rc "http: a checksum mismatch is a failure" 1 shell::prompt::skills::pick alpha
t_eq "http: nothing partial was installed" "no" "$([ -e "$S/alpha.md" ] && echo yes || echo no)"
t_eq "http: nothing partial in the cache" "0" "$(find "$CACHE/master/blobs" -type f 2>/dev/null | wc -l | tr -d ' ')"
printf 'alpha\n' >"$GH/raw/prompts/alpha.md"
# token: only in a header file, never in the arguments or the cache
GITHUB_TOKEN="ghp_SECRETTOKEN" shell::prompt::skills::list --refresh >/dev/null 2>&1
t_eq "http: the token reached curl through a header file" "Authorization: Bearer ghp_SECRETTOKEN" "$(cat "$GH/last-auth")"
t_lacks "http: the token is not in the request log" "SECRETTOKEN" "$(cat "$GH/requests")"
t_eq "http: the token is not in the cache" "0" "$(grep -rl SECRETTOKEN "$XDG_CACHE_HOME" 2>/dev/null | wc -l | tr -d ' ')"
# 404 and fallbacks
echo 404 >"$GH/tree.code"
t_rc "http: unknown branch (404)" 3 shell::prompt::skills::list --branch ghost
t_has "http: 404 message" "Branch 'ghost' not found" "$T_OUT"
# tarball: truncated or rate-limited tree -> one archive request
for n in 01 02 03 04 05 06 07 08 09 10; do printf '# P%s\nbody %s\n' "$n" "$n" >"$GH/tar/skills-master/prompts/p$n.md"; done
(cd "$GH/tar" && tar -czf "$GH/repo.tgz" skills-master)
echo 403 >"$GH/tree.code"
echo 0 >"$GH/ratelimit"
: >"$GH/requests"
rm -rf "$XDG_CACHE_HOME/shell/skills"
t_eq "http: a rate-limited API falls back to the tarball" "10" "$(shell::prompt::skills::list 2>/dev/null | wc -l | tr -d ' ')"
t_eq "http: ...with one codeload request" "1" "$(grep -c codeload.github.com "$GH/requests")"
t_has "http: codeload URL" "https://codeload.github.com/pnguyen215/skills/tar.gz/refs/heads/master" "$(cat "$GH/requests")"
: >"$GH/requests"
t_rc "http: install::all uses the cached tarball content" 0 shell::prompt::skills::install::all
t_has "http: ten installed" "installed=10" "$T_OUT"
t_eq "http: no per-file request after the tarball" "0" "$(grep -c raw.githubusercontent "$GH/requests")"
echo 200 >"$GH/tree.code"
echo 50 >"$GH/ratelimit"
tree '' true
rm -rf "$XDG_CACHE_HOME/shell/skills"
: >"$GH/requests"
t_eq "http: a truncated tree falls back to the tarball" "10" "$(shell::prompt::skills::list 2>/dev/null | wc -l | tr -d ' ')"
tree
rm -rf "$XDG_CACHE_HOME/shell/skills" "$S"
: >"$GH/requests"
for n in 01 02 03 04 05 06 07 08 09 10; do cp "$GH/tar/skills-master/prompts/p$n.md" "$GH/raw/prompts/p$n.md"; done
cp "$GH/raw/prompts/alpha.md" "$GH/tar/skills-master/prompts/alpha.md"
(cd "$GH/tar" && tar -czf "$GH/repo.tgz" skills-master)
{
	printf '{ "tree": [\n'
	for f in "$GH"/raw/prompts/*.md; do printf '{ "path": "prompts/%s", "type": "blob", "sha": "%s", "size": 1 },\n' "$(basename "$f")" "$(blobsha "$f")"; done
	printf '{ "path": "README.md", "type": "blob", "sha": "1", "size": 1 } ], "truncated": false }\n'
} >"$GH/tree.json"
t_rc "http: install::all (bulk)" 0 shell::prompt::skills::install::all
t_has "http: bulk: 11 prompts" "installed=11" "$T_OUT"
t_eq "http: bulk = one tarball request" "1" "$(grep -c codeload "$GH/requests")"
t_eq "http: bulk = one index request" "1" "$(grep -c '/git/trees/' "$GH/requests")"
t_eq "http: archive-extracted content equals the index sha" "yes" "$([ -f "$CACHE/master/blobs/$(blobsha "$GH/tar/skills-master/prompts/p03.md")" ] && echo yes || echo no)"
before="$(sum_dir "$S")"
: >"$GH/requests"
t_rc "http: second install::all" 0 shell::prompt::skills::install::all
t_has "http: second install::all is a no-op" "installed=0 updated=0 uptodate=11" "$T_OUT"
t_eq "http: second install::all wrote nothing" "$before" "$(sum_dir "$S")"
t_eq "http: second install::all made no download" "0" "$(grep -c 'raw.githubusercontent\|codeload' "$GH/requests")"
t_eq "http: branches" "* master
  dev" "$(shell::prompt::skills::branches)"
t_rc "http: branches of a missing repo" 3 shell::prompt::skills::branches --repo o/r
# no downloader at all: a PATH with only the few tools the script needs before it looks for curl / wget
nobin="$HOME/nobin"
mkdir "$nobin"
for tool in mktemp rm tr awk sed cat; do ln -s "$(command -v "$tool")" "$nobin/$tool"; done
PATH="$nobin" SKILLS_REPO=a/b SKILLS_BRANCH=master SKILLS_PATH=prompts SKILLS_CACHE="$HOME/nc" SKILLS_BLOBS="$HOME/nc/b" /bin/sh "$SHELL_TEST_ROOT/scripts/prompt_skills_transport.sh" branches >/dev/null 2>&1
t_eq "http: neither curl nor wget -> exit 3" "3" "$?"

# --- cleanup ------------------------------------------------------------------------------------------------------------
t_eq "no work directory is left behind" "0" "$(find "$HOME/tmp" -maxdepth 1 \( -name 'shell-prompt.*' -o -name 'skills-tx.*' \) | wc -l | tr -d ' ')"

t_done
