# Git pick: choose commits, or only some of their files, from another branch

`shell::git::commit::pick::fzf` is the interactive front end of the `shell::git::commit::pick::*` family. Without arguments it is a guided workflow; the rest of the family (`apply`, `range`, `backport`, `status`, `continue`, ...) is unchanged and is what does the work.

```
shell::git::commit::pick::fzf [-n] [-c <N>] [--include-head] [--all | <source>]
```

## The workflow

```
1. Source branch   local and remote-tracking, newest first, log preview on the right
2. Mode            Pick by commit  |  Pick by files        (Ctrl-T flips between them later)
3. Picker          fzf, multi-select with Tab, preview on the right
4. Action          by commit: cherry-pick / with -x / without committing / preview
                   by files:  apply to the working tree (staged, no commit) / preview
```

Every stage has a way back and ESC cancels without changing anything. Commits already in `HEAD` and merge commits are not listed (`--include-head` lists the former).

### 1. Source branch

One row per branch, `[local]` or `[remote]`, with the date and subject of its tip. The branch you are on, and `<remote>/HEAD`, are not offered. A remote branch that points at the same commit as the local branch of the same name is not repeated: the local row says `(= origin)`. When the two differ (one is ahead), both rows are listed. Each row carries the **full ref** (`refs/heads/x`, `refs/remotes/origin/x`), so a local `x` and a remote `origin/x` can never be mixed up. The commits listed are those of that ref that are not in `HEAD`.

### 2. Pick by commit

Lists the branch's commits (short hash, age, author, refs, subject; the full hash is hidden). Mark with **Tab**; the commits are replayed **oldest first** whatever order you marked them in, through `shell::git::commit::pick::apply`.

### 2. Pick by files

Lists the files the branch's commits changed, **one row per commit and file**, grouped by path with the newest commit first:

```
a           3f9c1d2 2026-11-20 T - x3: a again
a           9ccd8cb 2026-11-20 T - x1: add a
sp ace.txt  a2ef9cb 2026-11-20 T - x4: touch sp
```

A file changed by several commits therefore appears once per commit, with that commit beside it: you always know which change you are taking. The preview shows that commit's change to that file only. Applying takes, for each chosen commit (oldest first), the commit's own change to the chosen files, with `git apply --index --3way`: the result is **staged, not committed**. Paths are read from `git log -z` and passed as literal pathspecs, so spaces, quotes, non-ASCII, a leading `-`, a tab or a newline in a name are safe (a tab or newline is shown as `\t` / `\n`).

Limits: a commit's change applies only where its base exists (taking `a` from a later commit without the earlier one, onto a tree that has no `a`, stops with an error and stages nothing for that commit; mark both). Rename detection is off, so a renamed file is a delete plus an add. A conflict leaves conflict markers and stops; the commits applied before it stay staged (`git reset --hard` undoes them). It is not a cherry-pick: nothing is recorded in the cherry-pick state, so `shell::git::commit::pick::continue` / `abort` do not apply to it.

## Keys, cursor and state

| Key             | Does                                                                                  |
| --------------- | ------------------------------------------------------------------------------------- |
| Tab / Shift-Tab | mark or unmark the row **and leave the cursor on it** (fzf's default also moves down) |
| Ctrl-T          | flip to the other mode                                                                |
| Enter           | choose the marked rows, or the row under the cursor when none is marked               |
| ESC             | cancel everything                                                                     |

The query, the marked rows and the cursor row of each picker are saved when you leave it and restored when it is shown again: after Back from an action menu, and after flipping modes with Ctrl-T (each mode keeps its own). A mark hidden by the current query is kept. This also holds when the query matches nothing: Ctrl-T still flips. The state lives in a temporary directory for the duration of one run.

How it is done: fzf starts with a single chained `start` binding (`pos(N)+toggle` for each mark, then `change-query(...)`, then `pos(row)`), because fzf keeps only one `start` binding and `pos` counts rows of the _filtered_ list. The picker records the cursor row on every `focus` event, and `$FZF_QUERY` / `$FZF_SELECT_COUNT` on Ctrl-T, through `execute-silent`. Developed and tested against fzf 0.64; it relies on the `focus` event and on `$FZF_POS`, `$FZF_QUERY` and `$FZF_SELECT_COUNT` being set for `execute`, so use a recent fzf.

## Other forms (unchanged)

| Call                                                                       | Does                                                                                            |
| -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `fzf --all`                                                                | the former default: one list of the commits of **all refs** not in `HEAD`, then the action menu |
| `fzf <source>`                                                             | one list of that revision's history, then the action menu (no source or mode step)              |
| `fzf::local`, `::remote`, `::branch`, `::range`, `::current`, `::backport` | as before; they share the picker, so Tab no longer moves the cursor and Back restores the marks |

`-n` / `--dry-run` prints the commands instead of running them; `-c <N>` limits the commits listed (default 500).

## Compatibility

`shell::git::commit::pick::fzf` with **no arguments** used to list the commits of all refs at once; it now starts the workflow above. Use `--all` for the old behavior. Every other call form and the other `pick::*` functions behave as before. The `shell::git::manage` hub's _commit → pick_ entry gets the new workflow.
