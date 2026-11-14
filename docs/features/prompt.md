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

| Store | Location | Selected by |
|-------|----------|-------------|
| global (default) | `$SHELL_PROMPT_DIR`, default `~/.shell-config/prompts` | always |
| project (optional) | `./.prompts` (current directory) | exists, or `--local` |

```
<store>/
├── <slug>.md                              one prompt per file (mode 600)
└── .history/<slug>/<UTC-stamp>.md         snapshots taken before every edit, overwrite and removal
```

Directories are `700`, files `600`. Every write goes to a temp file in the same directory and is moved into place
(atomic); the store is never `rm -rf`-ed. A prompt is **removed by moving it into its history**, so it can be restored.

> The default lives under `SHELL_CONFIG_DIR` (like every other file this library writes), not in `~/.shell/prompts`.
> Set `SHELL_PROMPT_DIR` to put it anywhere.

| Variable | Default | Meaning |
|----------|---------|---------|
| `SHELL_PROMPT_DIR` | `$SHELL_CONFIG_DIR/prompts` | global store |
| `SHELL_PROMPT_LOCAL_NAME` | `.prompts` | name of the project store directory |
| `SHELL_PROMPT_HISTORY_LIMIT` | `20` | snapshots kept per prompt |
| `SHELL_PROMPT_MAX_BYTES` | `1048576` | largest prompt accepted by `add` / `import` |

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

| Function | Purpose |
|----------|---------|
| `shell::prompt::add [-n] [--local] [-d desc] [-t tags] <title> [file\|-]` | add a prompt; body from a file, stdin, or the editor when omitted |
| `shell::prompt::add::clipboard [-n] [--local] <title>` | store the current clipboard |
| `shell::prompt::get <slug>` | raw body to stdout (byte-exact, pipe-friendly) |
| `shell::prompt::render <slug> [name=value ...]` | fill the placeholders, print the result |
| `shell::prompt::copy [-n] <slug> [name=value ...]` | render + copy to the clipboard |
| `shell::prompt::exists <slug>` | prints `true` / `false` (exit 0 / 1) |
| `shell::prompt::list [--local\|--global\|--all] [--tag t] [--removed]` | scope, slug, title, tags, updated (tab-separated) |
| `shell::prompt::search <words...>` | all words must appear in title, description, tags or body |
| `shell::prompt::remove [-n] [-y] <slug>` | confirm, then move into history |
| `shell::prompt::rename [-n] <old> <new>` | rename slug and file; history follows |
| `shell::prompt::clone [-n] <slug> <new>` | copy under a new slug (`title (copy)`) |
| `shell::prompt::tag::add\|remove [-n] <slug> <tag...>` | change tags (snapshot first) |
| `shell::prompt::export [-n] <slug\|--all> <file\|dir>` | `.md` for one prompt, `.tar.gz` for the store |
| `shell::prompt::import [-n] [-y] <file\|dir\|url>` | validate, never replace without confirmation |
| `shell::prompt::history <slug>` | list snapshots (also for a removed prompt) |
| `shell::prompt::restore [-n] <slug> <timestamp>` | restore a snapshot (the current version is snapshotted first) |

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

| Function | What it does |
|----------|--------------|
| `shell::prompt::manage::fzf` | hub: Add, View, Edit, Copy, Clone, Rename, Remove, Import, Export, History, Back |
| `shell::prompt::view::fzf` | browse with a live preview; Enter = Copy, Copy rendered, Edit, Open pager, Tags, History, Remove, Back |
| `shell::prompt::edit::fzf` | pick, edit in `$VISUAL`/`$EDITOR`, validate, save, back to the list |
| `shell::prompt::search::fzf` | search as you type, **including the body** (fzf reloads from the store on every keystroke) |
| `shell::prompt::history::fzf` | snapshots with a coloured diff against the current version; Restore / View |
| `shell::prompt::tag::fzf` | pick a tag (with counts), browse its prompts with the same actions |

Keys on the list: `Enter` actions, `Ctrl-Y` copy, `Ctrl-R` copy rendered, `Ctrl-E` edit, `Ctrl-D` remove,
`Ctrl-/` toggle the preview, `ESC` leave. (`?` is not bound: it would stop you typing a question mark in the query.)

**Live preview**: title, tags, scope, updated, description, the `{{variables}}` found, size, then the body (coloured with
`bat` when installed, wrapped with `fold` otherwise). fzf runs it in a separate process where no `shell::*` function
exists, so it is a POSIX `sh` script written into a private temp directory that is removed on exit, error, Ctrl-C and kill.

**Copy** is done by the function itself, after fzf exits (never by fzf `execute`), with `printf '%s'`; quotes, `$`,
backticks, `%`, `\`, unicode and trailing newlines survive, on every pass of the loop. An empty prompt is never copied;
only the title and the size are logged, never the body. Without a clipboard tool the text is printed with a warning.
(`--best-effort` is deliberately not used: it would hide the missing tool.)

**Edit** flow: copy to a private temp file → editor → *no change*: nothing is written → validate (front matter, non-empty
title, non-blank body) → on failure choose *Re-open the editor* / *Discard* / *Back* (nothing is written in the last two)
→ snapshot the old version → refresh `updated:` (`created:` is kept) → atomic replace → prune snapshots beyond the limit.
The slug never changes with the title; use `rename`.

**Copy rendered** asks for each placeholder (default shown), previews the final text and copies only on *Copy to
clipboard*; Back, ESC or Ctrl-D copy nothing.

## Safety

- Prompts can hold secrets: files `600`, directories `700`, temp files `600` in a private directory, the body is never
  passed to `shell::logger::*` or put on a command line, and nothing is sent over the network.
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
