# Git isolate: take content from another branch without touching yours

`shell::git::isolate::*` retrieves **a commit, whole files, or only chosen lines** of another branch into a **new branch in a new `git worktree`**. Your current checkout is never switched, reset, cleaned, merged, rebased or stashed: the branch, `HEAD`, staged changes, unstaged changes and untracked files stay exactly as they are.

| Function                                             | Alias    | What it does                                                                      |
| ---------------------------------------------------- | -------- | --------------------------------------------------------------------------------- |
| `shell::git::isolate::fzf [-n]`                      | `sgisof` | Interactive: mode → source branch → commit / files / lines → preview → confirm    |
| `shell::git::isolate::commit <commit>`               |          | New branch **at that commit**                                                     |
| `shell::git::isolate::file <source> <path>…`         |          | New branch at the current `HEAD`, with the files copied from `<source>`           |
| `shell::git::isolate::lines <source> <path> <lines>` |          | New branch at the current `HEAD`, with only those source lines applied as a patch |

All three accept `-n/--dry-run` (print the git commands, create nothing), `-p/--preview` (show the diff, create nothing), `-b/--branch <name>` and `-d/--dir <path>`. `file` also accepts `-o/--overwrite`.

## Where things go

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

## Interactive flow

`shell::git::isolate::fzf`: pick the mode, then the source branch (local and remote, newest first, log preview), then the commit (`git show` preview), the files (those that differ from `HEAD` first, diff preview) or one file and its lines (Tab marks lines, contiguous ones become ranges). The resulting diff is printed through `--preview` (nothing is created), and you confirm with `y`. `← Back` goes back one step; ESC leaves.
