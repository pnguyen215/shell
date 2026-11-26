# Git toolkit: interactive-first Git functions, one per file

`shell::git::<group>::<action>` for **branch, commit, stage, log, remote, stash, repo and flow**. Every function
works with explicit arguments (scripts, no prompt) and, when run without arguments in a terminal, picks
interactively with fzf (or a numbered prompt when fzf is missing or too old). Anything that changes history or
throws work away is confirmed, dry-runnable and, for rewrites and discards, recoverable.

Each function lives in its own file, `src/lang/git/<group>/<action>.sh`; the private helpers live in
`src/lang/git/_core/`. Tests mirror them in `test/test_git_<group>.sh`, with fixtures in
`test/support/git_toolkit.sh`.

```
src/lang/git.sh                  # existing functions, untouched
src/lang/git/
├── index.sh                     # loader + explicit manifest (single source of truth)
├── _core/                       # env version state ui fzf confirm backup refs  +  one helper file per group
├── branch/   pick recent cleanup compare
├── commit/   pick fixup squash revert
├── stage/    pick patch unstage discard
├── log/      pick search file graph blame
├── remote/   sync compare fetch prune
├── stash/    pick save apply drop
├── repo/     health stats size summary
└── flow/     feature release hotfix sync
```

## Functions

| Function | Purpose | Changes things? |
|---|---|---|
| `branch::pick [-l\|-r] [-q text] [ref]` | Fuzzy-pick a local/remote branch, print it | no |
| `branch::recent [-l] [-c n]` | Pick among recently checked-out branches (from the reflog, existing ones only) | no |
| `branch::cleanup [-b base] [-a] [-y] [-n] [names]` | Delete **merged** local branches (`git branch -d` only, never `-D`) | yes |
| `branch::compare [-l n] [a] [b]` | Ahead/behind, commits on each side, changed files | no |
| `commit::pick [--multi] [--max n] [--rev r]` | Fuzzy-pick commits, print hashes | no |
| `commit::fixup [-n] [-y] [--autostash] [--allow-merges] [commit]` | Fixup commit from the staged changes, then autosquash | rewrites history |
| `commit::squash [-n] [-y] [-m msg] [--autostash] [--allow-merges] [count\|oldest]` | Squash a range into one commit | rewrites history |
| `commit::revert [-n] [-y] [-m parent] [commits]` | Revert commits, newest first; asks the parent of merge commits | yes |
| `stage::pick [-n] [-z] [paths]` | Stage files; staged and unstaged shown independently | yes |
| `stage::patch [-n] [paths]` | `git add -p` (needs a terminal) | yes |
| `stage::unstage [-n] [-z] [paths]` | Unstage files | yes |
| `stage::discard [-n] [-y] [--unstaged-only] [paths]` | Discard working-tree changes after a recovery snapshot | **destructive** |
| `log::pick [-m n] [-a] [-r rev] [--multi] [-- paths]` | Browse history in fzf with preview and key bindings | cherry-pick/revert on request |
| `log::search [--grep t \| -S t \| -G re] [-i] [-a] [-m n]` | Search messages, added/removed strings, or diffs | no |
| `log::file [-m n] [-p] [path]` | History of a file, following renames | no |
| `log::graph [-a] [-m n] [revs]` | Compact decorated graph | no |
| `log::blame [-L range] [-r rev] [--pick] [file]` | Blame a file or line range | no |
| `remote::sync [--merge\|--rebase\|--ff-only] [--autostash] [--no-fetch] [-y] [-n]` | Sync the current branch with its upstream | yes |
| `remote::compare [-r remote] [--plain]` | Local branches vs their remote counterparts | no |
| `remote::fetch [--prune] [-a] [-n] [remotes]` | Fetch; prune only when asked | yes |
| `remote::prune [-y] [-n] [remote]` | Dry-run preview, confirm, then prune | yes |
| `stash::pick [ref]` | Pick a stash, print its reference | no |
| `stash::save [-m name] [-u] [-k] [-n]` | Named stash; untracked files only with `-u` | yes |
| `stash::apply [--index] [-n] [ref]` | Apply a stash and keep it; conflicts exit 6 | yes |
| `stash::drop [-y] [-n] [ref]` | Drop a stash after confirmation, print its hash | destructive |
| `repo::health [--plain]` | State, divergence, branch/stash counts, merged/stale, conflicts | no |
| `repo::stats [--top n] [--max n] [--plain]` | Commits, authors, date range, top contributors (one log pass) | no |
| `repo::size [--plain]` | Object and pack sizes, size of the tree at HEAD | no |
| `repo::summary [--plain]` | Compact composition of the above | no |
| `flow::feature\|release\|hotfix [-n] [--autostash] [--fetch] [--base ref] name` | Start a prefixed branch from the base | yes |
| `flow::sync [--merge\|--rebase] [--autostash] [--fetch] [--base ref] [-y] [-n]` | Integrate the **base branch** into the current branch | yes |

Every function takes `-h/--help`. Mutating functions take `-n/--dry-run` (prints the exact quoted command on
stdout and executes nothing) and `-y/--yes` (the explicit confirmation for non-interactive use). Options and
exit codes of each function are in its shdoc block at the top of its file (`make docs` renders them).

### Names that already existed

Not redefined, so existing behavior is unchanged: `shell::git::branch::sync` (syncs *local branches with
origin*; it is **not** an alias of `remote::sync`, which syncs the *current branch with its upstream*) and
`shell::git::commit::amend`. The library's older `commit::pick::*`, `commit::squash::fzf`, `commit::revert::fzf`,
`branch::merged`, `branch::stale` and `branch::rename` are untouched; `branch::cleanup` and `repo::health`
reuse `merged`/`stale`.

## Safety

| Operation | Protection |
|---|---|
| Delete local branch | not the current, base, protected or worktree-checked-out branch; `-d` only; list + confirm. Squash-merged branches are **not** detected by `--merged` |
| Drop stash | confirm; prints the dropped hash |
| Discard changes | exact file list + confirm, then a recovery snapshot ref, then discard; `git clean` only after a `-n` preview and confirmation |
| Rewrite history (fixup/squash) | clean tree or `--autostash`; warning if the commits are on a remote-tracking branch; merge commits refused unless confirmed; backup ref; confirm |
| Remote prune | `remote prune --dry-run` first, then confirm |
| Merge/rebase in `remote::sync`/`flow::sync` | divergence preview; confirm; never an automatic reset |

No `eval`, no `sudo`, no `reset --hard`, `clean -fd`, `push --force`, `gc --prune=now` or `reflog expire` run for
you. Hooks are never skipped; global/system git config is never changed. All branch, ref and path input is
validated and passed after `--`/`--end-of-options`, so a branch named `--weird` is never read as an option; paths
use NUL (`-z`, `read -d ''`). `GIT_TERMINAL_PROMPT=0` for every call, so nothing waits on a credential prompt;
`https://user:token@host` is masked when a remote is shown. Not a terminal and no arguments: exit 2, never a
hang.

### Backup refs and recovery

Rewrites and discards first record what they could lose under `refs/shell-backup/<op>/<UTC timestamp>` and print
how to restore it. Backup refs are plain refs, never removed for you.

```bash
git for-each-ref refs/shell-backup                                   # list them
git reset --hard refs/shell-backup/fixup/20260101T120000Z            # undo a rewrite of the current branch (your decision)
git restore --source=refs/shell-backup/discard/20260101T120000Z --worktree -- <paths>   # get discarded files back
git show refs/shell-backup/discard/<ts>^2:<path>                     # the staged (index) version of a discarded file
git update-ref -d refs/shell-backup/<op>/<ts>                        # delete one when you no longer need it
```

The discard snapshot is built with a temporary index, so it also covers **untracked** files and is limited to the
chosen paths (`git stash create` would cover neither); the real index and working tree are not touched.

## Interactive use

fzf key bindings (a picker never uses `ctrl-c` for a feature: it aborts; `ctrl-s` is swallowed by terminal flow
control; `ctrl-d` quits fzf on an empty query). No collision with the library's other pickers, which use only
`ctrl-y/o/f/b/d/u` and `ctrl-/`.

| Key | Where | Action |
|---|---|---|
| `tab` / `shift-tab` | multi-select pickers | mark / unmark |
| `ctrl-/` | every picker with a preview | toggle the preview |
| `esc`, `ctrl-c` | every picker | abort, no side effects, exit 5 |
| `enter` | `log::pick` | details (`show --stat`) on stderr, hash on stdout |
| `alt-d` / `alt-f` / `alt-i` | `log::pick` | full diff / changed files / full info of the focused commit |
| `alt-p` / `alt-r` | `log::pick` | cherry-pick / revert the focused commit (confirm; conflicts exit 6; merge commits refused, use `commit::revert`) |
| `alt-m` | `log::pick` (no path filter) | load more history |
| `?` | `log::pick` | key help |

`log::pick`'s extended bindings need fzf 0.38; older fzf keeps `enter` and the preview and says so. Previews use
`delta`/`bat` when present and plain git output otherwise; neither is required. `SHELL_GIT_FZF_OPTS` is appended
to every picker. Colors: green = current/added, yellow = modified/warning, red = deleted/error, cyan = names and
hashes, blue = remotes, dim = dates; off under `NO_COLOR` or when stdout is not a terminal.

## Output contract and exit codes

stdout carries results only (refs, hashes, paths, tables, dry-run commands); stderr carries messages, warnings,
prompts. `--plain` (and any non-terminal stdout) gives tab-separated rows.

| Code | Meaning |
|---|---|
| 0 | ok |
| 1 | failure |
| 2 | usage / invalid argument, or a prompt was needed but there is no terminal and no `--yes` |
| 3 | not a git repository (or a bare one where a working tree is needed) |
| 4 | missing dependency |
| 5 | aborted by the user (esc, ctrl-c, declined confirmation): nothing changed |
| 6 | conflicts: resolve by hand (the exact `--continue`/`--abort` commands are printed) |
| 7 | blocked by a dirty tree or an operation in progress |
| 130 | interrupted |

`repo::health --plain` uses its own severity code: 0 healthy, 1 warnings, 2 problems.

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `SHELL_GIT_BASE_BRANCH` | `origin/HEAD`, then `main`, `master`, `develop` | base branch for cleanup, health, flow |
| `SHELL_GIT_FEATURE_PREFIX` / `RELEASE_PREFIX` / `HOTFIX_PREFIX` | `feature/` `release/` `hotfix/` | flow branch prefixes |
| `SHELL_GIT_RELEASE_BASE` | the base branch | where release branches start |
| `SHELL_GIT_STALE_DAYS` | 90 | age of a stale branch |
| `SHELL_GIT_PROTECTED_BRANCHES` | `main master develop` | never deleted by cleanup |
| `SHELL_GIT_FZF_OPTS` | empty | extra fzf options |
| `SHELL_GIT_LOG_FALLBACK`, `SHELL_GIT_BLAME_MAX_LINES` | see the files | numbered-list size without fzf; blame size limit (20000) |
| `SHELL_GIT_ASSUME_YES=1` / `SHELL_GIT_INPUT=<file>` / `SHELL_GIT_QUIET=1` / `SHELL_GIT_FORCE_FZF=1` | unset | automation and test hooks: auto-confirm, scripted answers, no info lines, fzf without a terminal |

Defaults are applied on first use, never at shell start. The toolkit leaks only these `SHELL_GIT_*` variables and
the `_SHELL_GIT_*` caches.

## Minimum versions

git 2.11 (`status --porcelain=v2`); newer options are gated one by one (`restore`/`switch` 2.23,
`--end-of-options` 2.30 with a guarded fallback, `stash push` 2.13, `remote::compare` uses
`%(upstream:track,nobracket)`, 2.13). fzf 0.19 for `--read0`/`--print0`, 0.38 for `log::pick`'s extended
bindings; without a usable fzf every picker falls back to a numbered prompt. bash 3.2 and zsh are supported.

## Loader

`index.sh` is the manifest: one documented stub per public function. A call sources the `_core` helpers once,
then the action file, then repeats the call with the same arguments, standard streams and exit status
(`declare -F`/`type` show the function from the start). Nothing is globbed and a stray file is never executed;
`test/test_git_loader.sh` checks that the manifest and the files agree and that every file has no top-level
statement and exactly one public function. `lang/git` is a module group of its own, so `src/lang/git.sh` is not
touched and stays lazily loaded (adding a `source` line to it would have made its 578 KB eager again).
Measured: the toolkit adds **no measurable start-up cost** (within ±0.4 ms of the same library without it, budget
5 ms); see [architecture](../development/architecture.md) for the library-wide numbers.

**Contributor rule: no command substitutions, external commands, file reads, or network at top level.** An action
file defines one function and sets nothing else; shared logic goes in `_core/`.

## Backlog (not implemented, not documented as available)

`branch::{rename,worktree,merged,stale,prune}` (older `merged`/`stale`/`rename` exist in the library),
`commit::{edit,undo,split,reword,cherry-pick}`, `stage::{diff,reset,partial,restore}`,
`log::{range,contributors,recent,bisect}`, `remote::{ahead,behind,tracking,url,pick}`, `stash::{pop,diff,branch}`,
`repo::{large,orphans,integrity,conflicts,contributors,activity}`, `flow::{finish,update,prune,publish}`.

## Known limitations

- `branch::pick` builds its list with one `for-each-ref`: about 400 ms for 5,000 branches (budget 300 ms).
- `commit::pick` writes its list to a temp file before fzf (default cap 5,000 commits; 50,000 take about 2 s).
- Squash-merged branches are not detected as merged.
- File names containing the control characters 037 or 036 are not supported by the pickers.
- `log::pick`'s previews and bindings are asserted to be passed to fzf, not exercised inside a real fzf.
- Prompt answers read from `SHELL_GIT_INPUT` are positional per process; scripted tests supply one answer per command.
