# Git isolate: take content from another branch without touching yours

`shell::git::isolate::*` retrieves **a commit, whole files, or only chosen lines** of another branch into a **new branch in a new `git worktree`**. Your current checkout is never switched, reset, cleaned, merged, rebased or stashed: the branch, `HEAD`, staged changes, unstaged changes and untracked files stay exactly as they are.

## The session: `shell::git::isolate` (alias `sgiso`, `sgisof`)

```
shell::git::isolate
  1. Source branch        local + remote, current one marked, date + subject, log preview
  2. Target strategy      (chosen ONCE)
       Apply to current branch (isolated copy)   new branch at the current HEAD
       Create new branch from a parent branch    pick parent -> type a name (empty = generated)
  3. ONE branch + ONE linked worktree are created, outside your working tree
  4. Action menu (loops until Back / ESC)
       Pick Files · Pick Commit · Pick Lines · Switch Source Branch · Back
```

- **Every action** previews, asks for confirmation, applies inside the worktree (`git -C <worktree>`) and commits there (one commit per action), then **returns to the menu**. Cancelling a picker, "nothing to apply", a conflict or a failed action also return to the menu; a failed action is reverted in the worktree only (`reset --hard HEAD` there), so earlier actions are never lost.
- **Pick Files** — several files, `≠` marks those that differ from the destination, diff preview; a file that exists in the destination with different content needs an explicit yes.
- **Pick Commit** — the source's commits (hash, date, author, subject, `git show` preview); the commit's _changes_ are applied onto the existing destination with `cherry-pick --no-commit` and committed with the original message and author. Merge commits are refused (ambiguous parent), commits already in the destination and conflicts are reported and the destination is restored.
- **Pick Lines** — pick a file, mark lines (Tab; contiguous lines become ranges), the patch against the _destination's_ content is previewed and applied with `git apply --unidiff-zero --index`.
- **Switch Source Branch** — changes only the source reference; destination, worktree and applied changes are kept. If the source ref moves during the session the new tip is used (with a warning).
- **Back** (`SHELL_FZF_BACK_LABEL`, returns 11) and **ESC** (returns 0) leave. The branch and worktree are **kept**; a summary prints where. A session that applied nothing offers to remove its empty worktree, only on an explicit yes. Remove later with `git worktree remove <dir>`.
- `-n/--dry-run` chooses source and strategy, prints the `git worktree add` command and creates nothing.

Pickers return 0 (chosen), 9 (cancelled) or 11 (Back), so cancelling and going back are never confused; no non-zero code ends the session by itself.

### Preservation

The original repository is only ever **read**; every write is `git -C <worktree>`, and the helper refuses to run when the worktree is unset or is the original. Before the session, after every action and at the end, a fingerprint is compared: HEAD, branch, every ref, the index, the status, the **content hash** of every modified and untracked file, both diffs, the stash list and the other worktrees (the session's own branch and worktree excluded). A difference, or a destination worktree that vanished or left its branch, ends the session with exit 1 and an explanation. Hooks are disabled for the worktree operations, parent symlinks in the destination are refused, and a failed worktree creation is rolled back (only what this session created).

## One-shot functions

These create their own branch + worktree for a single operation (no menu).

| Function                                             | What it does                                                                      |
| ---------------------------------------------------- | --------------------------------------------------------------------------------- |
| `shell::git::isolate::commit <commit>`               | New branch **at that commit**                                                     |
| `shell::git::isolate::file <source> <path>…`         | New branch at the current `HEAD`, with the files copied from `<source>`           |
| `shell::git::isolate::lines <source> <path> <lines>` | New branch at the current `HEAD`, with only those source lines applied as a patch |

All three accept `-n/--dry-run` (print the git commands, create nothing), `-p/--preview` (show the diff, create nothing), `-b/--branch <name>` and `-d/--dir <path>`. `file` also accepts `-o/--overwrite`. `shell::git::isolate::fzf` is kept as an alias of `shell::git::isolate`.

## Where things go (one-shot functions; a session commits one action at a time)

- **Branch name**: `isolate/<commit|file|lines>/<short-id>-<subject-or-file>`; if it exists, `-2`, `-3`… A name you pass with `--branch` that already exists is an **error**; it is never reused.
- **Worktree**: `$SHELL_GIT_ISOLATE_DIR/<repo>-<hash>/<branch>` (default `~/.shell-config/git-isolate`), always **outside** the working tree. An existing directory is never reused.
- The result is staged in the worktree and **not committed**. Review, commit and push there; remove it with `git worktree remove <dir>`.

## Files

Paths are repository-relative and keep their directory structure. Before anything is created:

- a file missing from the source, a directory, or a path with `..` is refused;
- a file already **identical** at `HEAD` is skipped (nothing left → exit 8, nothing created);
- a file that exists at `HEAD` with **different content** is a conflict: it is listed, and nothing is created unless `--overwrite` (the replacement only ever happens in the new branch);
- uncommitted changes to the same path in your checkout are reported; they stay where they are and are not part of the new branch.

## Lines

Lines are numbered **in the source file** (`5`, `10-20`, `"3,10-20 40"`). The tool diffs `HEAD` against the source, keeps only what the selected lines touch and applies it as a zero-context patch (`git apply --unidiff-zero --index`), so the rest of the file is never replaced.

- A changed block whose added lines are **all** selected is applied whole (the lines it replaces go too).
- A block selected **only in part** inserts just the selected lines and keeps the old ones (reported).
- Unselected blocks and pure deletions are skipped.
- Empty, invalid, reversed, out-of-range and **overlapping** selections are rejected; so is a selection that changes nothing at `HEAD` (exit 8) and a binary file.
- The patch is checked with `git apply --check` in the worktree before it is applied, and the resulting diff is shown. A file that does not exist at `HEAD` is created from the selected lines.

## Safety guarantees

1. `git worktree add -b` is the only operation on the repository; the current checkout is not an argument of any command that writes.
2. A fingerprint of `HEAD`, the branch, the status, both diffs and the stash list is taken before and after; a difference is reported as an error.
3. A failure rolls back **only what the call created** (its branch and its worktree). Names are verified free first, so a pre-existing branch, directory or worktree is never removed or overwritten.
4. Refs are resolved to full commit ids first; paths follow `--` with literal pathspecs; nothing is passed through `eval`.
5. A detached `HEAD` works (the new branch starts at that commit, with a warning); an empty repository, a bare repository and Git without `worktree` are refused with a message.

## Exit codes

`0` success · `1` failure (rolled back) · `2` invalid argument, path or lines · `3` source, commit or file not found · `7` branch / directory exists, or overwrite needed · `8` nothing to retrieve · `11` Back.
