# Prompt Management

A local, file-based library of reusable AI prompts, managed from the terminal: create, review, view, edit, copy,
organise, search, version and share prompts. A **global** store works from any directory; an optional **project** store
(`./.prompts`) travels with a repository.

Source: [`src/lib/prompt.sh`](../../src/lib/prompt.sh) (store and CLI), [`src/lib/prompt_fzf.sh`](../../src/lib/prompt_fzf.sh)
(interactive menus). No new hard dependency: fzf for the menus; `bat`, `rg` and `jq` are not required.

```bash
shell::prompt::manage::fzf                       # the hub: add, view, edit, copy, clone, rename, remove, import, export, history
shell::prompt::add "Code review checklist" ./review.md
shell::prompt::copy code-review                  # render + copy to the clipboard
```

## Storage

| Store              | Location                                               | Selected by          |
| ------------------ | ------------------------------------------------------ | -------------------- |
| global (default)   | `$SHELL_PROMPT_DIR`, default `~/.shell-config/prompts` | always               |
| project (optional) | `./.prompts` (current directory)                       | exists, or `--local` |

```
<store>/
├── <slug>.md                              one prompt per file (mode 600)
└── .history/<slug>/<UTC-stamp>.md         snapshots taken before every edit, overwrite and removal
```

Directories are `700`, files `600`. Every write goes to a temp file in the same directory and is moved into place
(atomic); the store is never `rm -rf`-ed. A prompt is **removed by moving it into its history**, so it can be restored.

> The default lives under `SHELL_CONFIG_DIR` (like every other file this library writes), not in `~/.shell/prompts`.
> Set `SHELL_PROMPT_DIR` to put it anywhere.

| Variable                     | Default                     | Meaning                                     |
| ---------------------------- | --------------------------- | ------------------------------------------- |
| `SHELL_PROMPT_DIR`           | `$SHELL_CONFIG_DIR/prompts` | global store                                |
| `SHELL_PROMPT_LOCAL_NAME`    | `.prompts`                  | name of the project store directory         |
| `SHELL_PROMPT_HISTORY_LIMIT` | `20`                        | snapshots kept per prompt                   |
| `SHELL_PROMPT_MAX_BYTES`     | `1048576`                   | largest prompt accepted by `add` / `import` |

## File format

```markdown
---
title: Code review checklist
description: Strict reviewer persona for bash PRs
tags: review,bash,quality
created: 2026-11-14T10:00:00Z
updated: 2026-11-14T10:00:00Z
---

You are a strict reviewer of {{language|bash}} code. Review {{target}} ...
```

- The **slug** is the file name: lowercase `[a-z0-9-]`, derived from the title (`Code review checklist` →
  `code-review-checklist`). An existing slug is never overwritten. Slugs with `/`, `..`, a leading `-` or any other
  character are rejected.
- The **body** is stored byte for byte (quotes, `$`, backticks, `%`, `\`, unicode, trailing newlines, even a `---` line).
- Only these five front-matter fields are kept; other keys are dropped when the file is rewritten.
- **Placeholders**: `{{name}}` or `{{name|default}}`; names are `[A-Za-z_][A-Za-z0-9_.-]*`. Anything else (`{{}}`,
  `{{two words}}`) stays literal.

## Non-interactive functions

Every function accepts `-h` / `--help`; mutating ones accept `-n` (dry-run: the command is printed with
`shell::logger::command_clip`, nothing is written). `--local` / `--global` pick a store (reads look in the project store
first, then the global one; writes go to the global store unless `--local`).

| Function                                                                  | Purpose                                                           |
| ------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `shell::prompt::add [-n] [--local] [-d desc] [-t tags] <title> [file\|-]` | add a prompt; body from a file, stdin, or the editor when omitted |
| `shell::prompt::add::clipboard [-n] [--local] <title>`                    | store the current clipboard                                       |
| `shell::prompt::get <slug>`                                               | raw body to stdout (byte-exact, pipe-friendly)                    |
| `shell::prompt::render <slug> [name=value ...]`                           | fill the placeholders, print the result                           |
| `shell::prompt::copy [-n] <slug> [name=value ...]`                        | render + copy to the clipboard                                    |
| `shell::prompt::exists <slug>`                                            | prints `true` / `false` (exit 0 / 1)                              |
| `shell::prompt::list [--local\|--global\|--all] [--tag t] [--removed]`    | scope, slug, title, tags, updated (tab-separated)                 |
| `shell::prompt::search <words...>`                                        | all words must appear in title, description, tags or body         |
| `shell::prompt::remove [-n] [-y] <slug>`                                  | confirm, then move into history                                   |
| `shell::prompt::rename [-n] <old> <new>`                                  | rename slug and file; history follows                             |
| `shell::prompt::clone [-n] <slug> <new>`                                  | copy under a new slug (`title (copy)`)                            |
| `shell::prompt::tag::add\|remove [-n] <slug> <tag...>`                    | change tags (snapshot first)                                      |
| `shell::prompt::export [-n] <slug\|--all> <file\|dir>`                    | `.md` for one prompt, `.tar.gz` for the store                     |
| `shell::prompt::import [-n] [-y] <file\|dir\|url>`                        | validate, never replace without confirmation                      |
| `shell::prompt::history <slug>`                                           | list snapshots (also for a removed prompt)                        |
| `shell::prompt::restore [-n] <slug> <timestamp>`                          | restore a snapshot (the current version is snapshotted first)     |

Exit codes: `0` success, `1` failure, `2` invalid input, `3` not found, `7` already exists, `11` back (menus).

```bash
shell::prompt::add "Code review checklist" ./review.md
echo 'Summarise {{topic}} in {{words|100}} words' | shell::prompt::add -t "writing,summary" "Summary" -
shell::prompt::add::clipboard "Bug report template"
shell::prompt::get code-review | pbcopy
shell::prompt::render summary topic="the release notes"
shell::prompt::copy summary topic="the release notes" words=50
[ "$(shell::prompt::exists code-review)" = true ] && echo found
shell::prompt::list --tag review
shell::prompt::search bash review
shell::prompt::tag::add code-review quality
shell::prompt::clone code-review code-review-strict
shell::prompt::rename code-review-strict review-strict
shell::prompt::remove old-draft                 # moved into history, restorable
shell::prompt::list --removed
shell::prompt::history review-strict            # stamp  size  title
shell::prompt::restore review-strict 20261114T100000Z
shell::prompt::export --all ~/prompts-backup.tar.gz
shell::prompt::import ~/Downloads/prompts/      # every *.md; a file without front matter becomes a prompt
shell::prompt::import https://example.com/prompts/review.md   # shows the source, always asks, text only
shell::prompt::add -n --local "Release notes"   # dry-run
```

**Rendering.** Values given as `name=value` win; every other placeholder is asked on the terminal with its default shown
(Enter accepts it). Without a terminal a missing value falls back to its default, or fails (exit 2) when it has none.

## Interactive menus

Every list and menu goes through `shell::fzf::select` and ends with `← Back` (exit **11**, nothing mutated). After an
action the list comes back, rebuilt, with the cursor on the same prompt. ESC / Ctrl-C leave with `0`. `[G]` / `[L]` marks
the global / project store. An empty store offers **Create your first prompt** and Back.

| Function                      | What it does                                                                                           |
| ----------------------------- | ------------------------------------------------------------------------------------------------------ |
| `shell::prompt::manage::fzf`  | hub: Add, View, Edit, Copy, Clone, Rename, Remove, Import, Export, History, Back                       |
| `shell::prompt::view::fzf`    | browse with a live preview; Enter = Copy, Copy rendered, Edit, Open pager, Tags, History, Remove, Back |
| `shell::prompt::edit::fzf`    | pick, edit in `$VISUAL`/`$EDITOR`, validate, save, back to the list                                    |
| `shell::prompt::search::fzf`  | search as you type, **including the body** (fzf reloads from the store on every keystroke)             |
| `shell::prompt::history::fzf` | snapshots with a coloured diff against the current version; Restore / View                             |
| `shell::prompt::tag::fzf`     | pick a tag (with counts), browse its prompts with the same actions                                     |

Keys on the list: `Enter` actions, `Ctrl-Y` copy, `Ctrl-R` copy rendered, `Ctrl-E` edit, `Ctrl-D` remove,
`Ctrl-/` toggle the preview, `ESC` leave. (`?` is not bound: it would stop you typing a question mark in the query.)

**Live preview**: title, tags, scope, updated, description, the `{{variables}}` found, size, then the body (coloured with
`bat` when installed, wrapped with `fold` otherwise). fzf runs it in a separate process where no `shell::*` function
exists, so it is a POSIX `sh` script written into a private temp directory that is removed on exit, error, Ctrl-C and kill.

**Copy** is done by the function itself, after fzf exits (never by fzf `execute`), with `printf '%s'`; quotes, `$`,
backticks, `%`, `\`, unicode and trailing newlines survive, on every pass of the loop. An empty prompt is never copied;
only the title and the size are logged, never the body. Without a clipboard tool the text is printed with a warning.
(`--best-effort` is deliberately not used: it would hide the missing tool.)

**Edit** flow: copy to a private temp file → editor → _no change_: nothing is written → validate (front matter, non-empty
title, non-blank body) → on failure choose _Re-open the editor_ / _Discard_ / _Back_ (nothing is written in the last two)
→ snapshot the old version → refresh `updated:` (`created:` is kept) → atomic replace → prune snapshots beyond the limit.
The slug never changes with the title; use `rename`.

**Copy rendered** asks for each placeholder (default shown), previews the final text and copies only on _Copy to
clipboard_; Back, ESC or Ctrl-D copy nothing.

## Prompt Skills Sync

The [`pnguyen215/skills`](https://github.com/pnguyen215/skills) repository (directory `prompts/`, branch `master`) is the
single source of truth for shared prompts. `shell::prompt::skills::*` downloads them into the **global** store (default,
available from any directory) or the **personal** store (`--personal`, alias `--project` / `--local`: the per-project
`./.prompts`). Installed prompts are ordinary store files, so `list`, `search`, `view::fzf`, `copy`, `render`, `edit`,
`history` and `restore` work on them unchanged.

Source: [`src/lib/prompt_skills.sh`](../../src/lib/prompt_skills.sh) (logic),
[`src/lib/prompt_skills_fzf.sh`](../../src/lib/prompt_skills_fzf.sh) (menus) and
[`scripts/prompt_skills_transport.sh`](../../scripts/prompt_skills_transport.sh) (the only code that talks to GitHub).
Needs `curl` (or `wget`, without token and ETag support), `tar`, `awk`, `sed`, and fzf for the menus; `jq` is not used.

```bash
shell::prompt::skills::list                         # remote prompts with a status: - not installed, G/P installed, * update, ! modified locally
shell::prompt::skills::list --tag review --available
shell::prompt::skills::view skill-optimizer         # print the remote file, install nothing
shell::prompt::skills::copy summary topic="release notes"   # fill {{placeholders}} and copy, install nothing
shell::prompt::skills::pick skill-optimizer         # install into the global store
shell::prompt::skills::pick --personal --as my-opt skill-optimizer
shell::prompt::skills::install::all                 # EVERY prompt, global store; run twice = no writes the second time
shell::prompt::skills::install::all --personal --branch develop
shell::prompt::skills::status                       # drift: outdated / modified / missing remotely
shell::prompt::skills::update [-n] [--force] [name...]   # update what changed remotely (modified prompts are skipped and reported)
shell::prompt::skills::update --branch develop      # switch the installed prompts to another branch (shown in the dry-run)
shell::prompt::skills::remove skill-optimizer       # snapshot to history first, so shell::prompt::restore brings it back
shell::prompt::skills::branches                     # branches of the repository
shell::prompt::skills::cache::clear [--all]

shell::prompt::skills::browse::fzf                  # hub: preview, Install global/personal, View, Copy, Update, Remove, Switch branch
shell::prompt::skills::pick::fzf                    # multi-select -> scope (Global preselected) -> install
shell::prompt::skills::view::fzf                    # Enter: pager, Ctrl-Y: copy to the clipboard
shell::prompt::skills::update::fzf                  # only outdated / modified prompts, with a diff preview
shell::prompt::skills::remove::fzf                  # installed-from-skills prompts, confirmed one by one
shell::prompt::skills::branch::fzf                  # exports SHELL_PROMPT_SKILLS_BRANCH for this session (no file)
```

Common options: `--repo <owner/repo>`, `--branch <name>` (default `master`), `--refresh` (ask GitHub again even when the
cached index is fresh), `-n` (dry-run: print the commands, write nothing) and `-h`. Every `::fzf` menu ends with
`← Back` (exit 11, nothing is changed) and loops list → action → refreshed list; Tab selects several prompts.

**Settings** (environment variables, constants in `src/constant/paths.sh`): `SHELL_PROMPT_SKILLS_REPO`
(`pnguyen215/skills`), `SHELL_PROMPT_SKILLS_BRANCH` (`master`), `SHELL_PROMPT_SKILLS_PATH` (`prompts`),
`SHELL_PROMPT_SKILLS_CACHE_TTL` (300 s), `SHELL_PROMPT_SKILLS_BULK_MIN` (8), `SHELL_PROMPT_SKILLS_JOBS` (4),
`SHELL_PROMPT_SKILLS_PREFETCH=0` (no background cache warm-up), `GITHUB_TOKEN` (optional: higher rate limit, private repos;
sent only in a private header file, never logged and never cached).

**Mapping.** `prompts/<dir>/<Name>.md` becomes the slug `<name>` (kept when it already is a valid slug, otherwise
slugified) and the directories become tags; on a slug collision between different directories the later ones are prefixed
with the directory (`a-same`, `b-same`). A file with front matter (`title:`) keeps its title, description and tags; a file
without it gets the first `# ` heading (or the prettified file name) as title, no description, and the whole file, byte for
byte, as body. Only `*.md` files under `prompts/` with `[A-Za-z0-9._/-]` paths and no `..` are accepted.

**Provenance.** `<store>/.skills.lock` (TSV, 600): `slug repo branch remote_path remote_blob_sha installed_utc local_checksum`.
The prompt file format is untouched, so editing a prompt never drops provenance; the SHA-256 recorded at install time is how
local modifications (`!`) are detected. `rename` moves the entry, `remove` deletes it, `clone` does not copy it, and a prompt
restored from history is no longer tracked.

| Situation                            | `pick` / `install::all`                                           | `update`                               |
| ------------------------------------ | ----------------------------------------------------------------- | -------------------------------------- |
| new slug                             | installed                                                         | –                                      |
| tracked, clean, same blob sha        | no-op (`uptodate`)                                                | no-op                                  |
| tracked, clean, remote changed       | updated (old version snapshotted)                                 | updated                                |
| tracked, modified locally            | skipped + reported; `--force` snapshots yours and replaces        | skipped + reported; `--force` replaces |
| same slug, not installed from skills | skipped (exit 7); `--force` snapshots yours, or use `--as <slug>` | –                                      |

**Network.** One Trees API call lists the branch (`git/trees/<branch>?recursive=1`), cached under
`${XDG_CACHE_HOME:-$HOME/.cache}/shell/skills/<owner>__<repo>/<branch>/` (700/600) for the TTL and then revalidated with
`If-None-Match` (a 304 costs no rate-limit quota). Files come from `raw.githubusercontent.com`, cached by git blob SHA and
verified against it; more than `BULK_MIN` missing files are fetched as ONE tarball (`codeload.github.com`), otherwise up to
`JOBS` raw requests run in parallel. A truncated or rate-limited API answer falls back to the tarball; a network failure
falls back to the cached index with a warning. The fzf preview only reads the disk cache (a miss shows `loading...` and
downloads that one file once; the cache is warmed in the background when a list opens). A branch that does not exist is an
error with a hint, never a silent fallback to another branch.

**Offline / tests.** `SHELL_PROMPT_SKILLS_LOCAL_DIR=<dir>` reads `<dir>/<branch>/prompts/**/*.md` instead of the network
(branches are the sub-directories), which is how the tests run.

Personal-scope installs write into the project: the store may need to be git-ignored (a one-line tip is printed;
`.gitignore` is never edited for you).

## Safety

- Prompts can hold secrets: files `600`, directories `700`, temp files `600` in a private directory, the body is never
  passed to `shell::logger::*` or put on a command line, and nothing is sent over the network (except the explicit `shell::prompt::skills::*` downloads below).
- `import` from a URL shows the source, **always** asks for confirmation (also with `-y`), needs a terminal, enforces the
  size limit and rejects non-text content.
- Slugs and paths are validated (no `/`, `..`, leading `-`); lookups are exact file names, never regular expressions.
- Temp work happens in a subshell with its own `trap`, so the traps of your interactive shell are never replaced.

## Limits and follow-ups

- No index cache: listing and search read the files (one `awk` pass), which is instant for hundreds of prompts.
  A `.meta/index.tsv` can be added without changing the file format.
- Sync across machines: put `SHELL_PROMPT_DIR` in a git repository, or commit the project store `./.prompts`.
- Encryption at rest could reuse `src/security/crypto.sh`; today the protection is file permissions only.
- Windows is out of scope (like the rest of the library): Linux and macOS.
