#!/usr/bin/env bash
# shell::prompt::* (src/lib/prompt.sh): slugs, front matter, add/get round trip, render, dry-run, history, import/export,
# local store, permissions. The interactive menus are covered by test_prompt_fzf.sh.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

# Isolated stores: the global one under $HOME, the project one in $HOME/proj/.prompts.
export SHELL_PROMPT_DIR="$HOME/store"
mkdir "$HOME/proj"
G="$SHELL_PROMPT_DIR"
mode_of() { stat -f %Lp "$1" 2>/dev/null || stat -c %a "$1"; }
sum_dir() { (cd "$1" && find . -type f | LC_ALL=C sort | xargs cksum 2>/dev/null); }

# --- slug generation -------------------------------------------------------
t_eq "slug: lowercase and dashes" "code-review-checklist" "$(_shell::prompt::slugify 'Code review  Checklist!')"
t_eq "slug: trims separators" "a-b" "$(_shell::prompt::slugify '  --A / B--  ')"
t_eq "slug: digits kept" "gpt-4-prompt" "$(_shell::prompt::slugify 'GPT 4 prompt')"
t_rc "slug: nothing usable is invalid" 2 _shell::prompt::slugify '!!!'
for bad in "" "-x" "a/b" "../x" "A" "a b" "a.b" "x;y"; do
	t_rc "valid_slug rejects '$bad'" 1 _shell::prompt::valid_slug "$bad"
done
t_rc "valid_slug accepts a-1" 0 _shell::prompt::valid_slug "a-1"
t_eq "tags: normalised" "review,bash,q_a" "$(_shell::prompt::norm_tags 'Review, bash  Q_A, bash ,')"

# --- add / get round trip --------------------------------------------------
SPECIAL='You are "strict" $HOME `date` %s \n back\slash & é 日本 {not} {{ }} ~'
printf '%s\n\n  indented\n\n\n' "$SPECIAL" >"$HOME/body.txt"
t_rc "add from file" 0 shell::prompt::add -t "Review, Bash" -d "Strict reviewer" "Code Review" "$HOME/body.txt"
t_eq "get is byte-exact (special chars, blank lines)" "$(cksum <"$HOME/body.txt")" "$(shell::prompt::get code-review | cksum)"
printf 'no final newline' | shell::prompt::add "No NL" - >/dev/null 2>&1
t_eq "get keeps a missing final newline" "no final newline" "$(shell::prompt::get no-nl)"
t_eq "get keeps a missing final newline (bytes)" "16" "$(shell::prompt::get no-nl | wc -c | tr -d ' ')"
t_rc "add refuses an existing slug" 7 shell::prompt::add "Code Review" "$HOME/body.txt"
t_eq "existing prompt not overwritten" "$(cksum <"$HOME/body.txt")" "$(shell::prompt::get code-review | cksum)"
t_rc "add: empty title" 2 shell::prompt::add "" "$HOME/body.txt"
printf '   \n\n' >"$HOME/blank.txt"
t_rc "add: blank body" 2 shell::prompt::add "Blank" "$HOME/blank.txt"
t_rc "add: missing file" 3 shell::prompt::add "Ghost" "$HOME/nope.txt"
t_rc "add: unknown option" 2 shell::prompt::add --bogus "X" "$HOME/body.txt"

# --- front matter ----------------------------------------------------------
F="$G/code-review.md"
t_eq "meta: title" "Code Review" "$(_shell::prompt::meta "$F" title)"
t_eq "meta: description" "Strict reviewer" "$(_shell::prompt::meta "$F" description)"
t_eq "meta: tags" "review,bash" "$(_shell::prompt::meta "$F" tags)"
t_has "meta: created is ISO" "T" "$(_shell::prompt::meta "$F" created)"
t_rc "meta: unknown key" 1 _shell::prompt::meta "$F" nope
t_eq "front matter: first line" "---" "$(sed -n 1p "$F")"
t_eq "body_offset" "8" "$(_shell::prompt::body_offset "$F")"
printf 'plain text\n' >"$HOME/plain.md"
t_rc "body_offset: no front matter" 1 _shell::prompt::body_offset "$HOME/plain.md"
printf -- '---\ntitle: x\nnever closed\n' >"$HOME/open.md"
t_rc "body_offset: unclosed" 1 _shell::prompt::body_offset "$HOME/open.md"
t_rc "validate: ok" 0 _shell::prompt::validate "$F"
printf -- '---\ndescription: d\n---\nbody\n' >"$HOME/notitle.md"
t_rc "validate: no title" 1 _shell::prompt::validate "$HOME/notitle.md"
printf -- '---\ntitle: t\n---\n  \n' >"$HOME/nobody.md"
t_rc "validate: blank body" 1 _shell::prompt::validate "$HOME/nobody.md"
printf -- '---\ntitle: t\n---\n---\nbody with --- line\n' >"$HOME/dashes.md"
t_eq "body may contain ---" "---
body with --- line" "$(_shell::prompt::body_stream "$HOME/dashes.md")"

# --- permissions -----------------------------------------------------------
t_eq "store dir is 700" "700" "$(mode_of "$G")"
t_eq "history dir is 700" "700" "$(mode_of "$G/.history")"
t_eq "prompt file is 600" "600" "$(mode_of "$F")"

# --- exists / list / search ------------------------------------------------
t_eq "exists: true" "true" "$(shell::prompt::exists code-review)"
t_eq "exists: false" "false" "$(shell::prompt::exists nope)"
t_rc "exists: false returns 1" 1 shell::prompt::exists nope
t_rc "exists: invalid slug returns 2" 2 shell::prompt::exists "../x"
t_rc "get: traversal rejected" 2 shell::prompt::get "../../etc/passwd"
t_rc "get: not found" 3 shell::prompt::get nope
list="$(shell::prompt::list)"
t_has "list: row" "G	code-review	Code Review	review,bash	" "$list"
t_has "list: second prompt" "G	no-nl	No NL" "$list"
t_eq "list --tag filters" "1" "$(shell::prompt::list --tag review | wc -l | tr -d ' ')"
t_eq "search: word in tags" "code-review" "$(shell::prompt::search BASH | awk -F'\t' '{print $2}')"
t_eq "search: word in body" "code-review" "$(shell::prompt::search strict back | awk -F'\t' '{print $2}')"
t_eq "search: all words must match" "" "$(shell::prompt::search strict zzzz)"
t_eq "search: description" "code-review" "$(shell::prompt::search reviewer | awk -F'\t' '{print $2}')"

# --- render / copy ----------------------------------------------------------
printf 'Hello {{who|world}}, tone: {{ tone | polite }}. {{who}} again. {{}} {{bad name}} {{a{{who}}\n' >"$HOME/tpl.txt"
shell::prompt::add "Greeting" "$HOME/tpl.txt" >/dev/null 2>&1
t_eq "render: defaults" "Hello world, tone: polite. world again. {{}} {{bad name}} {{aworld" "$(shell::prompt::render greeting </dev/null)"
t_eq "render: values win" "Hello Bob, tone: polite. Bob again. {{}} {{bad name}} {{aBob" "$(shell::prompt::render greeting who=Bob </dev/null)"
t_has "render: & and backslash literal" 'x&y\1$HOME' "$(shell::prompt::render greeting 'who=x&y\1$HOME' </dev/null)"
printf 'need {{required}}\n' | shell::prompt::add "Needs" - >/dev/null 2>&1
t_rc "render: missing value without default" 2 shell::prompt::render needs
t_has "render: names the missing value" "required" "$T_OUT"
t_eq "render: value given" "need ok" "$(shell::prompt::render needs required=ok </dev/null)"
t_rc "render: bad name=value" 2 shell::prompt::render needs "oops"
t_eq "vars: detected once with defaults" "who	1	world
tone	1	polite" "$(_shell::prompt::body_stream "$G/greeting.md" | _shell::prompt::vars)"
printf 'x\n\n\n' | shell::prompt::add "Trail" - >/dev/null 2>&1
shell::prompt::render trail </dev/null >"$HOME/trail.out"
t_eq "render keeps trailing newlines" "$(printf 'x\n\n\n' | cksum)" "$(cksum <"$HOME/trail.out")"

# copy: fake clipboard
mkdir "$HOME/bin"
printf '#!/bin/sh\ncat >"$FAKE_CLIP"\n' >"$HOME/bin/pbcopy"
chmod +x "$HOME/bin/pbcopy"
export PATH="$HOME/bin:$PATH" FAKE_CLIP="$HOME/clip.out"
shell::prompt::copy code-review >/dev/null 2>&1
t_eq "copy: clipboard holds the exact body" "$(cksum <"$HOME/body.txt")" "$(cksum <"$FAKE_CLIP")"
t_rc "copy: message names title and size" 0 shell::prompt::copy code-review
t_has "copy: confirmation shows the title" "Code Review" "$T_OUT"
t_lacks "copy: never logs the body" "strict" "$T_OUT"
rm -f "$FAKE_CLIP"
t_rc "copy -n: dry-run" 0 shell::prompt::copy -n code-review
t_lacks "copy -n: the body is not copied (only the command is shown)" "strict" "$(cat "$FAKE_CLIP" 2>/dev/null)"
rm -f "$FAKE_CLIP"
t_rc "copy: missing required value" 2 shell::prompt::copy needs
t_eq "copy: failed render leaves clipboard alone" "no" "$([ -e "$FAKE_CLIP" ] && echo yes || echo no)"
shell::prompt::copy greeting who=Ann </dev/null >/dev/null 2>&1
t_has "copy: renders before copying" "Hello Ann" "$(cat "$FAKE_CLIP")"

# --- dry-run never writes --------------------------------------------------
before="$(sum_dir "$G")"
t_rc "add -n" 0 shell::prompt::add -n "Dry One" "$HOME/body.txt"
t_rc "remove -n" 0 shell::prompt::remove -n code-review
t_rc "rename -n" 0 shell::prompt::rename -n code-review other
t_rc "clone -n" 0 shell::prompt::clone -n code-review other
t_rc "tag::add -n" 0 shell::prompt::tag::add -n code-review zzz
t_rc "tag::remove -n" 0 shell::prompt::tag::remove -n code-review bash
t_rc "export -n" 0 shell::prompt::export -n code-review "$HOME/out.md"
t_rc "export --all -n" 0 shell::prompt::export -n --all "$HOME/out.tar.gz"
t_rc "import -n" 0 shell::prompt::import -n "$HOME/plain.md"
t_eq "dry-run: store byte-identical" "$before" "$(sum_dir "$G")"
t_eq "dry-run: no export written" "no" "$([ -e "$HOME/out.md" ] || [ -e "$HOME/out.tar.gz" ] && echo yes || echo no)"
t_eq "dry-run: no new prompt" "false" "$(shell::prompt::exists dry-one)"

# --- tags / rename / clone -------------------------------------------------
shell::prompt::tag::add code-review "Quality  Extra" >/dev/null 2>&1
t_eq "tag::add normalises and appends" "review,bash,quality,extra" "$(_shell::prompt::meta "$F" tags)"
shell::prompt::tag::remove code-review bash extra >/dev/null 2>&1
t_eq "tag::remove" "review,quality" "$(_shell::prompt::meta "$F" tags)"
t_eq "tag change keeps the body" "$(cksum <"$HOME/body.txt")" "$(shell::prompt::get code-review | cksum)"
t_eq "tag change snapshots first" "2" "$(shell::prompt::history code-review | wc -l | tr -d ' ')"
t_rc "tag::add needs a tag" 2 shell::prompt::tag::add code-review
shell::prompt::clone code-review cr-copy >/dev/null 2>&1
t_eq "clone: title gets (copy)" "Code Review (copy)" "$(_shell::prompt::meta "$G/cr-copy.md" title)"
t_eq "clone: body identical" "$(cksum <"$HOME/body.txt")" "$(shell::prompt::get cr-copy | cksum)"
t_rc "clone: target exists" 7 shell::prompt::clone code-review cr-copy
t_rc "clone: invalid target" 2 shell::prompt::clone code-review "../x"
t_rc "rename: target exists" 7 shell::prompt::rename cr-copy greeting
shell::prompt::rename cr-copy cr-renamed >/dev/null 2>&1
t_eq "rename: old gone" "false" "$(shell::prompt::exists cr-copy)"
t_eq "rename: new there" "true" "$(shell::prompt::exists cr-renamed)"
t_rc "rename: invalid target" 2 shell::prompt::rename cr-renamed "-bad"

# --- remove -> history -> restore ------------------------------------------
t_rc "remove: declined without a terminal keeps the prompt" 0 shell::prompt::remove cr-renamed </dev/null
t_eq "remove: still there after decline" "true" "$(shell::prompt::exists cr-renamed)"
t_rc "remove -y" 0 shell::prompt::remove -y cr-renamed
t_eq "remove: gone" "false" "$(shell::prompt::exists cr-renamed)"
t_has "remove: listed as removed" "cr-renamed" "$(shell::prompt::list --removed)"
stamp="$(shell::prompt::history cr-renamed | head -n 1 | cut -f1)"
t_rc "history of a removed prompt" 0 shell::prompt::history cr-renamed
t_rc "restore a removed prompt" 0 shell::prompt::restore cr-renamed "$stamp"
t_eq "restore: prompt back" "true" "$(shell::prompt::exists cr-renamed)"
t_eq "restore: body identical" "$(cksum <"$HOME/body.txt")" "$(shell::prompt::get cr-renamed | cksum)"
t_eq "restore: file is 600" "600" "$(mode_of "$G/cr-renamed.md")"
t_rc "restore: bad stamp" 2 shell::prompt::restore cr-renamed "../../x"
t_rc "restore: unknown stamp" 3 shell::prompt::restore cr-renamed 20000101T000000Z
t_rc "history: unknown prompt" 3 shell::prompt::history nope

# snapshots of an overwrite, then restore the old version
printf 'version one\n' | shell::prompt::add "Versioned" - >/dev/null 2>&1
mkdir "$HOME/imp"
printf -- '---\ntitle: Versioned\ntags: a,b\n---\nversion two\n' >"$HOME/imp/versioned.md"
shell::prompt::import -y "$HOME/imp/versioned.md" >/dev/null 2>&1
t_eq "import -y replaced the body" "version two" "$(shell::prompt::get versioned)"
t_eq "import kept the tags" "a,b" "$(_shell::prompt::meta "$G/versioned.md" tags)"
old="$(shell::prompt::history versioned | head -n 1 | cut -f1)"
shell::prompt::restore versioned "$old" >/dev/null 2>&1
t_eq "restore brings the old body back" "version one" "$(shell::prompt::get versioned)"
t_eq "restore snapshots the version it replaces" "2" "$(shell::prompt::history versioned | wc -l | tr -d ' ')"

# history limit
export SHELL_PROMPT_HISTORY_LIMIT=3
i=0
while [ "$i" -lt 6 ]; do
	printf 'body %s\n' "$i" >"$HOME/imp/versioned.md"
	shell::prompt::import -y "$HOME/imp/versioned.md" >/dev/null 2>&1
	i=$((i + 1))
done
t_eq "history keeps only the newest N snapshots" "3" "$(shell::prompt::history versioned | wc -l | tr -d ' ')"
export SHELL_PROMPT_HISTORY_LIMIT=20

# --- import ------------------------------------------------------------------
printf 'plain body {{x}}\n' >"$HOME/imp/my_plain-note.md"
t_rc "import: file without front matter" 0 shell::prompt::import "$HOME/imp/my_plain-note.md"
t_eq "import: title from file name" "my plain note" "$(_shell::prompt::meta "$G/my-plain-note.md" title)"
t_eq "import: body verbatim" "plain body {{x}}" "$(shell::prompt::get my-plain-note)"
printf 'a\000b\n' >"$HOME/imp/bin.md"
t_rc "import: binary rejected" 2 shell::prompt::import "$HOME/imp/bin.md"
t_eq "import: binary not stored" "false" "$(shell::prompt::exists bin)"
printf -- '---\ndescription: no title\n---\nbody\n' >"$HOME/imp/broken.md"
t_rc "import: invalid front matter rejected" 2 shell::prompt::import "$HOME/imp/broken.md"
: >"$HOME/imp/empty.md"
t_rc "import: empty file rejected" 2 shell::prompt::import "$HOME/imp/empty.md"
t_rc "import: missing path" 3 shell::prompt::import "$HOME/imp/nope.md"
printf 'changed\n' >"$HOME/imp/my_plain-note.md"
t_rc "import: collision without a terminal is skipped" 0 shell::prompt::import "$HOME/imp/my_plain-note.md" </dev/null
t_eq "import: skipped collision left the prompt alone" "plain body {{x}}" "$(shell::prompt::get my-plain-note)"
mkdir "$HOME/imp2"
printf 'one\n' >"$HOME/imp2/one.md"
printf 'two\n' >"$HOME/imp2/two.md"
printf 'nope\n' >"$HOME/imp2/skip.txt"
t_rc "import: directory" 0 shell::prompt::import "$HOME/imp2"
t_eq "import: directory brought .md files" "true true" "$(shell::prompt::exists one) $(shell::prompt::exists two)"
t_rc "import: missing directory" 3 shell::prompt::import "$HOME/imp3-missing"
t_rc "import: URL needs a terminal to confirm" 1 shell::prompt::import https://example.invalid/x.md </dev/null
t_has "import: URL shows its source" "example.invalid" "$T_OUT"
t_eq "import: URL imported nothing" "false" "$(shell::prompt::exists x)"

# --- export ------------------------------------------------------------------
mkdir "$HOME/exp"
t_rc "export: one prompt into a directory" 0 shell::prompt::export code-review "$HOME/exp"
t_eq "export: file content matches" "$(cksum <"$G/code-review.md")" "$(cksum <"$HOME/exp/code-review.md")"
t_eq "export: file is 600" "600" "$(mode_of "$HOME/exp/code-review.md")"
t_rc "export --all" 0 shell::prompt::export --all "$HOME/exp/all.tar.gz"
t_has "export --all: archive holds the prompts" "code-review.md" "$(tar -tzf "$HOME/exp/all.tar.gz")"
t_lacks "export --all: no history inside" ".history" "$(tar -tzf "$HOME/exp/all.tar.gz")"
t_rc "export: unknown prompt" 3 shell::prompt::export nope "$HOME/exp"
t_rc "export: declined overwrite keeps the file" 0 shell::prompt::export code-review "$HOME/exp/code-review.md" </dev/null
t_eq "export: file untouched after decline" "$(cksum <"$G/code-review.md")" "$(cksum <"$HOME/exp/code-review.md")"

# --- local store -------------------------------------------------------------
cd "$HOME/proj" || exit 1
t_eq "local: not listed before it exists" "0" "$(shell::prompt::list | awk -F'\t' '$1=="L"' | wc -l | tr -d ' ')"
t_rc "add --local creates ./.prompts" 0 shell::prompt::add --local "Project Only" "$HOME/body.txt"
t_eq "local: dir is 700" "700" "$(mode_of "$HOME/proj/.prompts")"
t_eq "local: file is 600" "600" "$(mode_of "$HOME/proj/.prompts/project-only.md")"
t_eq "local: not written to the global store" "false" "$(shell::prompt::exists --global project-only)"
t_eq "local: listed with the L marker" "L" "$(shell::prompt::list | awk -F'\t' '$2=="project-only" {print $1}')"
t_eq "list --local only shows local" "project-only" "$(shell::prompt::list --local | awk -F'\t' '{print $2}')"
t_eq "list --global hides local" "0" "$(shell::prompt::list --global | grep -c project-only)"
printf 'local version\n' | shell::prompt::add --local "Code Review" - >/dev/null 2>&1
t_eq "same slug is allowed in both stores" "local version" "$(shell::prompt::get code-review)"
t_eq "--global reads the global one" "$(cksum <"$HOME/body.txt")" "$(shell::prompt::get --global code-review | cksum)"
t_rc "remove --local removes only the local copy" 0 shell::prompt::remove -y --local code-review
t_eq "global copy survives" "true" "$(shell::prompt::exists --global code-review)"
cd "$HOME" || exit 1

# --- real terminal: questions must read the tty (stdin is a pty here) ---------
# pty_run <shell code> [<expect> <send>]...: run the code in a bash with the library loaded, on a pseudo-terminal, typing
# <send> whenever <expect> appears in the output. Prints everything the program wrote.
pty_run() {
	python3 - "$@" <<'PY'
import os, pty, select, sys, time
code, steps = sys.argv[1], list(zip(sys.argv[2::2], sys.argv[3::2]))
env = dict(os.environ, NO_COLOR="1", SHELL_AUTO_INSTALL_DEPS="0", TERM="dumb")
pid, fd = pty.fork()
if pid == 0:
    os.execvpe("bash", ["bash", "--noprofile", "--norc", "-c", '. "$SHELL_DIR/src/shell.sh"; ' + code], env)
buf, seen, deadline = b"", 0, time.time() + 20
while time.time() < deadline:
    r, _, _ = select.select([fd], [], [], 0.2)
    if r:
        try:
            data = os.read(fd, 4096)
        except OSError:
            break
        if not data:
            break
        buf += data
        if seen < len(steps) and steps[seen][0].encode() in buf:
            os.write(fd, steps[seen][1].replace("\\n", "\n").encode())
            seen += 1
            buf += b"\n"
sys.stdout.write(buf.decode("utf-8", "replace").replace("\r", ""))
PY
}
if command -v python3 >/dev/null 2>&1; then
	export SHELL_DIR="$SHELL_TEST_ROOT"
	o="$(pty_run 'shell::prompt::render greeting' '[world]' 'Zed\n' '[polite]' '\n')"
	t_has "tty: render asks each placeholder and uses the typed value" "Hello Zed, tone: polite." "$o"
	o="$(pty_run 'shell::prompt::render greeting who=Amy' '[polite]' 'formal\n')"
	t_has "tty: values given as arguments are not asked again" "Hello Amy, tone: formal." "$o"
	o="$(pty_run 'shell::prompt::remove needs' 'restored' 'y\n')"
	t_has "tty: remove asks on the terminal" "Removed prompt 'needs'" "$o"
	t_eq "tty: and removed it" "false" "$(shell::prompt::exists needs)"
	mkdir "$HOME/imp4"
	printf 'second try\n' >"$HOME/imp4/versioned.md"
	o="$(pty_run "shell::prompt::import $HOME/imp4" 'Replace it' 'y\n')"
	t_eq "tty: directory import confirms collisions on the terminal" "second try" "$(shell::prompt::get versioned)"
else
	printf '  (python3 not found: pty tests skipped)\n'
fi

# --- help ---------------------------------------------------------------------
for fn in add add::clipboard get render copy exists list search remove rename clone tag::add tag::remove export import history restore \
	view::fzf edit::fzf search::fzf history::fzf tag::fzf manage::fzf; do
	t_rc "help: shell::prompt::$fn -h" 0 "shell::prompt::$fn" -h
	t_has "help: $fn shows usage" "shell::prompt::" "$T_OUT"
done

t_done
