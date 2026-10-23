# lang/git.sh

Git and GitHub helpers.

## Overview

Sends a historical GitHub-related message via Telegram using stored configuration keys.

The function first checks if the dry-run flag is provided. It then verifies the existence of the
configuration keys "`SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN`" and "`SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID`".
If either key is missing, a warning is printed and the corresponding key is copied to the clipboard
to prompt the user to add it using `shell::conf::key::add`. If both keys exist, it retrieves their values and
calls `shell::telegram::send` (with the dry-run flag, if enabled) to send the message.

## Index

- [lang/git.sh](#langgitsh)
  - [Overview](#overview)
  - [Index](#index)
    - [shell::git::telegram::history::send](#shellgittelegramhistorysend)
      - [Example](#example)
      - [Options](#options)
      - [Arguments](#arguments)
      - [Exit codes](#exit-codes)
    - [shell::git::repos::stats](#shellgitreposstats)
      - [Example](#example-1)
      - [Options](#options-1)
      - [Arguments](#arguments-1)
      - [Exit codes](#exit-codes-1)
    - [shell::git::repos::fetch](#shellgitreposfetch)
      - [Example](#example-2)
      - [Options](#options-2)
      - [Arguments](#arguments-2)
      - [Exit codes](#exit-codes-2)
    - [shell::git::repos::version::latest](#shellgitreposversionlatest)
      - [Example](#example-3)
      - [Arguments](#arguments-3)
      - [Exit codes](#exit-codes-3)
    - [shell::git::branch::checkout](#shellgitbranchcheckout)
      - [Example](#example-4)
      - [Options](#options-3)
      - [Arguments](#arguments-4)
      - [Exit codes](#exit-codes-4)
    - [shell::git::branch::checkout::current](#shellgitbranchcheckoutcurrent)
      - [Example](#example-5)
      - [Options](#options-4)
      - [Exit codes](#exit-codes-5)
    - [shell::git::branch::create](#shellgitbranchcreate)
      - [Example](#example-6)
      - [Options](#options-5)
      - [Arguments](#arguments-5)
      - [Exit codes](#exit-codes-6)
    - [shell::git::branch::sync](#shellgitbranchsync)
      - [Example](#example-7)
      - [Options](#options-6)
      - [Exit codes](#exit-codes-7)
    - [shell::git::branch::remove](#shellgitbranchremove)
      - [Example](#example-8)
      - [Options](#options-7)
      - [Arguments](#arguments-6)
      - [Exit codes](#exit-codes-8)
    - [shell::git::branch::push](#shellgitbranchpush)
      - [Example](#example-9)
      - [Options](#options-8)
      - [Arguments](#arguments-7)
      - [Exit codes](#exit-codes-9)
    - [shell::git::branch::push::current](#shellgitbranchpushcurrent)
      - [Example](#example-10)
      - [Options](#options-9)
      - [Exit codes](#exit-codes-10)
    - [shell::git::branch::push::current::force](#shellgitbranchpushcurrentforce)
      - [Example](#example-11)
      - [Options](#options-10)
      - [Exit codes](#exit-codes-11)
    - [shell::git::branch::backup](#shellgitbranchbackup)
      - [Example](#example-12)
      - [Options](#options-11)
      - [Arguments](#arguments-8)
      - [Exit codes](#exit-codes-12)
    - [shell::git::branch::backup::current](#shellgitbranchbackupcurrent)
      - [Example](#example-13)
      - [Options](#options-12)
      - [Exit codes](#exit-codes-13)
    - [shell::git::branch::rename](#shellgitbranchrename)
      - [Example](#example-14)
      - [Options](#options-13)
      - [Arguments](#arguments-9)
      - [Exit codes](#exit-codes-14)
    - [shell::git::branch::rename::current](#shellgitbranchrenamecurrent)
      - [Example](#example-15)
      - [Options](#options-14)
      - [Arguments](#arguments-10)
      - [Exit codes](#exit-codes-15)
    - [shell::git::branch::rename::fzf](#shellgitbranchrenamefzf)
      - [Example](#example-16)
      - [Options](#options-15)
      - [Exit codes](#exit-codes-16)
    - [shell::git::branch::all::fzf](#shellgitbranchallfzf)
      - [Example](#example-17)
      - [Options](#options-16)
      - [Arguments](#arguments-11)
      - [Exit codes](#exit-codes-17)
    - [shell::git::branch::merge](#shellgitbranchmerge)
      - [Example](#example-18)
      - [Options](#options-17)
      - [Arguments](#arguments-12)
      - [Exit codes](#exit-codes-18)
    - [shell::git::branch::merge::fzf](#shellgitbranchmergefzf)
      - [Example](#example-19)
      - [Options](#options-18)
      - [Exit codes](#exit-codes-19)
    - [shell::git::branch::stash](#shellgitbranchstash)
      - [Example](#example-20)
      - [Options](#options-19)
      - [Arguments](#arguments-13)
      - [Exit codes](#exit-codes-20)
    - [shell::git::branch::stash::remove::fzf](#shellgitbranchstashremovefzf)
      - [Example](#example-21)
      - [Options](#options-20)
      - [Exit codes](#exit-codes-21)
    - [shell::git::branch::stash::preview::fzf](#shellgitbranchstashpreviewfzf)
      - [Example](#example-22)
      - [Options](#options-21)
      - [Exit codes](#exit-codes-22)
    - [shell::git::branch::stash::apply::fzf](#shellgitbranchstashapplyfzf)
      - [Example](#example-23)
      - [Options](#options-22)
      - [Exit codes](#exit-codes-23)
    - [shell::git::commit::spec](#shellgitcommitspec)
      - [Example](#example-24)
      - [Options](#options-23)
      - [Arguments](#arguments-14)
      - [Exit codes](#exit-codes-24)
    - [shell::git::commit::spec::current](#shellgitcommitspeccurrent)
      - [Example](#example-25)
      - [Options](#options-24)
      - [Exit codes](#exit-codes-25)
    - [shell::git::commit::all](#shellgitcommitall)
      - [Example](#example-26)
      - [Options](#options-25)
      - [Exit codes](#exit-codes-26)
    - [shell::git::commit::spec::fzf](#shellgitcommitspecfzf)
      - [Example](#example-27)
      - [Options](#options-26)
      - [Exit codes](#exit-codes-27)
    - [shell::git::commit::spec::search](#shellgitcommitspecsearch)
      - [Example](#example-28)
      - [Options](#options-27)
      - [Arguments](#arguments-15)
      - [Exit codes](#exit-codes-28)
    - [shell::git::commit::spec::search::current](#shellgitcommitspecsearchcurrent)
      - [Example](#example-29)
      - [Options](#options-28)
      - [Exit codes](#exit-codes-29)
    - [shell::git::commit::all::search](#shellgitcommitallsearch)
      - [Example](#example-30)
      - [Options](#options-29)
      - [Exit codes](#exit-codes-30)
    - [shell::git::commit::pick::local](#shellgitcommitpicklocal)
      - [Example](#example-31)
      - [Options](#options-30)
      - [Arguments](#arguments-16)
      - [Exit codes](#exit-codes-31)
    - [shell::git::commit::pick::remote](#shellgitcommitpickremote)
      - [Example](#example-32)
      - [Options](#options-31)
      - [Arguments](#arguments-17)
      - [Exit codes](#exit-codes-32)
    - [shell::git::commit::message::base](#shellgitcommitmessagebase)
      - [Example](#example-33)
      - [Options](#options-32)
      - [Exit codes](#exit-codes-33)
    - [shell::git::commit::create](#shellgitcommitcreate)
      - [Example](#example-34)
      - [Options](#options-33)
      - [Exit codes](#exit-codes-34)
    - [shell::git::commit::checkout](#shellgitcommitcheckout)
      - [Example](#example-35)
      - [Options](#options-34)
      - [Arguments](#arguments-18)
      - [Exit codes](#exit-codes-35)
    - [shell::git::commit::checkout::fzf](#shellgitcommitcheckoutfzf)
      - [Example](#example-36)
      - [Options](#options-35)
      - [Exit codes](#exit-codes-36)
    - [shell::git::tag::create](#shellgittagcreate)
      - [Example](#example-37)
      - [Options](#options-36)
      - [Arguments](#arguments-19)
      - [Exit codes](#exit-codes-37)
    - [shell::git::tag::remove](#shellgittagremove)
      - [Example](#example-38)
      - [Options](#options-37)
      - [Arguments](#arguments-20)
      - [Exit codes](#exit-codes-38)
    - [shell::git::tag::checkout](#shellgittagcheckout)
      - [Example](#example-39)
      - [Options](#options-38)
      - [Arguments](#arguments-21)
      - [Exit codes](#exit-codes-39)
    - [shell::git::tag::checkout::fzf](#shellgittagcheckoutfzf)
      - [Example](#example-40)
      - [Options](#options-39)
      - [Exit codes](#exit-codes-40)
    - [shell::git::tag::all](#shellgittagall)
      - [Example](#example-41)
      - [Options](#options-40)
      - [Exit codes](#exit-codes-41)
    - [shell::git::tag::remove::fzf](#shellgittagremovefzf)
      - [Example](#example-42)
      - [Options](#options-41)
      - [Exit codes](#exit-codes-42)
    - [shell::git::commit::revert::fzf](#shellgitcommitrevertfzf)
      - [Example](#example-43)
      - [Options](#options-42)
      - [Exit codes](#exit-codes-43)
    - [shell::git::commit::spec::history::fzf](#shellgitcommitspechistoryfzf)
      - [Example](#example-44)
      - [Options](#options-43)
      - [Arguments](#arguments-22)
      - [Exit codes](#exit-codes-44)
    - [shell::git::commit::spec::history::fzf::current](#shellgitcommitspechistoryfzfcurrent)
      - [Example](#example-45)
      - [Options](#options-44)
      - [Exit codes](#exit-codes-45)

### shell::git::telegram::history::send

Sends a historical GitHub-related message via Telegram using stored configuration keys.

The function first checks if the dry-run flag is provided. It then verifies the existence of the
configuration keys "`SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN`" and "`SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID`".
If either key is missing, a warning is printed and the corresponding key is copied to the clipboard
to prompt the user to add it using `shell::conf::key::add`. If both keys exist, it retrieves their values and
calls `shell::telegram::send` (with the dry-run flag, if enabled) to send the message.

#### Example

```bash
shell::git::telegram::history::send "Historical message text"
shell::git::telegram::history::send -n "Dry-run historical message text"
```

#### Options

- **-n**

  Optional dry-run flag. If provided, the command will be printed using `shell::logger::command_clip` instead of executed.

#### Arguments

- **$1** (string): message: The message text to send.

#### Exit codes

- **0**: Success.
- **2**: Invalid or missing arguments.

### shell::git::repos::stats

Displays comprehensive statistics for a Git repository — works both for a
local clone and for a remote URL (public or private with access). When a URL
is supplied the repository is cloned to a temporary directory, stats are
gathered, then the directory is removed.

Notes:
Section E (code growth) runs `git log --numstat` over the full history.
This can take several minutes on large repositories.

#### Example

```bash
shell::git::repos::stats
shell::git::repos::stats /path/to/local/repo
shell::git::repos::stats https://github.com/owner/repo.git
shell::git::repos::stats git@github.com:owner/private-repo.git
```

#### Options

- **-n** | **--dry-run**

  Optional. Print planned git commands instead of executing.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **$1** (string): path_or_url: Optional. Local repo path OR remote URL (https://, http://, git(at), ssh://). Defaults to CWD. Stat sections (v1 metric set): A. Repository Identity — name, URL, branches, age, first/last commit B. Repository Size — commits, branches, tags, contributors, files, LOC C. Commit Activity — windows (24h/7d/30d/90d/1y), velocity, trends D. Contributors — totals, active windows, top-10 leaderboard E. Code Growth — added/deleted/net lines, avg commit size F. Code Churn — churn rate, top modified files & directories G. Commit Quality — conventional breakdown, merge/revert/fixup counts H. Branch Metrics — local count, active vs stale (90-day threshold) I. Tag Metrics — total, latest, first J. Time Distribution — by weekday, top hours, working pattern % K. Language Distribution — file count by extension (top-15) L. Repository Health Score — 0-100 composite score

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::repos::fetch

Clones a remote Git repository as a shallow clone (depth 1) into a specified
local folder name.

Runs:
git clone --depth 1 <repo_uri> <folder_name>
The --depth 1 flag creates a shallow clone with only the latest commit,
minimising download size and clone time. The command is logged via
shell::logger::assert.

#### Example

```bash
shell::git::repos::fetch "https://github.com/org/repo.git" "my-repo"
shell::git::repos::fetch -n "https://github.com/org/repo.git" "my-repo"
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **$1** (string): repo_uri: The URI of the remote Git repository to clone.
- **$2** (string): folder_name: The local directory name to clone into.

#### Exit codes

- **0**: Success.
- **2**: Invalid or missing arguments.

### shell::git::repos::version::latest

Retrieves the latest release tag from a GitHub repository using the GitHub API.

Notes:

- Requires internet access.
- Works on both macOS and Linux.

#### Example

```bash
shell::git::repos::version::latest "cli/cli"
```

#### Arguments

- **$1** (string): owner/repo: GitHub repository in the format 'owner/repo'

#### Exit codes

- **0**: Success.
- **2**: Invalid or missing arguments.

### shell::git::branch::checkout

Fetches a specific remote branch, checks it out, and syncs local state to the
remote tip. Detects uncommitted changes and unpushed local commits, then shows
an fzf strategy picker only when the local state requires a decision.

Step 1 — Switch to the target branch (skipped when already on it):
git fetch origin <branch>:<branch> (blocked when already checked out — detected)
git checkout <branch>
Step 2 — Targeted fetch (guarantees refs/remotes/origin/<branch> exists):
git fetch origin <branch>
Step 3 — Sync all remotes and tags:
git fetch --all --tags
Step 4 — Detect local state and act:
clean (no uncommitted, no local commits) → auto git reset --hard origin/<branch>
local commits only → fzf: rebase (recommended) | reset --hard
uncommitted changes only → fzf: stash+reset+pop (recommended) | reset --hard
both uncommitted + local commits → fzf: stash+rebase+pop (recommended) | reset --hard

#### Example

```bash
shell::git::branch::checkout "feature/my-branch"
shell::git::branch::checkout -n "feature/my-branch"
```

#### Options

- **-n** | **--dry-run**

  Optional. Print each command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **$1** (string): branch: Name of the remote branch to fetch and check out.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
- **2**: Invalid or missing arguments.

### shell::git::branch::checkout::current

Checks out the currently active branch by name, effectively re-checking it out.
This is useful for triggering branch-specific hooks or refreshing the working tree
without switching to a different branch. If not inside a Git repository, an error
is logged and the function returns with failure.

#### Example

```bash
shell::git::branch::checkout::current
shell::git::branch::checkout::current -n
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::branch::create

Creates one or more local Git branches, pushes each to origin with upstream
tracking, then restores the original branch.

For each valid branch name, runs:

1. git checkout -b <branch> — create and switch to the new branch
2. git push -u origin <branch> — push and set upstream tracking
   After all branches are processed, returns to the originally checked-out branch
   captured at function entry. Each step is logged via shell::logger::assert
   and stops the per-branch loop on the first failure for that branch.

#### Example

```bash
shell::git::branch::create feature_a feature_b
shell::git::branch::create -n feature_a feature_b
```

#### Options

- **-n** | **--dry-run**

  Optional. Print each command via `shell::logger::command_clip` instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **...** (string): branch...: One or more branch names to create. Each name must match the regex ^[a-zA-Z0-9_-]+$ (letters, digits, hyphen, underscore). Invalid names are skipped with a warning.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
- **2**: Invalid or missing arguments.

### shell::git::branch::sync

Syncs all remote branches to local: fetches and prunes all remotes, creates
local tracking branches for new remote branches, and fast-forwards local
branches that have no local-only commits ahead of origin.

1. git fetch --all --prune — update all remote-tracking refs, remove stale ones
2. For each remote branch in origin (excluding HEAD):

- Not present locally → git branch --track <branch> origin/<branch>
- Currently checked out → skip with info (use shell::git::branch::checkout)
- local_ahead == 0 → git branch -f <branch> origin/<branch> (fast-forward)
- local_ahead > 0 → warn and skip

#### Example

```bash
shell::git::branch::sync
shell::git::branch::sync -n
```

#### Options

- **-n** | **--dry-run**

  Optional. Print each command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::branch::remove

Deletes one or more Git branches both locally (force-delete) and on the remote
origin, then restores the originally checked-out branch.

Captures the currently checked-out branch at function entry, then for each
provided branch name runs:

1. git branch -D <branch> — force-delete the local branch
2. git push origin --delete <branch> — delete the branch on origin
   After all branches are processed, restores the original branch via
   git checkout. Each step is logged via shell::logger::assert and stops
   the per-branch iteration on the first failure for that branch.

#### Example

```bash
shell::git::branch::remove feature_a feature_b
shell::git::branch::remove -n feature_a
```

#### Options

- **-n** | **--dry-run**

  Optional. Print each command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **...** (string): branch...: One or more branch names to delete.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
- **2**: Invalid or missing arguments.

### shell::git::branch::push

Presents an interactive fzf picker of git push strategies for a given branch,
confirms with the user, then executes the selected command.

Builds a set of labelled push strategies (label:command pairs), presents
them via shell::ask::option::value (fzf), prompts for confirmation, then
runs the selected git command via shell::logger::assert.
Available strategies:

- Set upstream tracking git push -u origin <branch>
- Push all branches git push --all origin
- Push all tags git push --tags origin
- Force-push (unsafe) git push --force origin <branch>
- Force-push with lease (safe) git push --force-with-lease origin <branch>
- Delete branch from remote git push --delete origin <branch>
- Mirror local repo git push --mirror origin
- Simulate push (dry-run) git push --dry-run origin <branch>
- Push with CI skip git push -o ci.skip origin <branch>
- Prune deleted remote refs git push --prune origin
- Push with GPG signing git push --signed origin <branch>
- Simple push git push

#### Example

```bash
shell::git::branch::push "main"
shell::git::branch::push -n "feature/my-branch"
```

#### Options

- **-n** | **--dry-run**

  Optional. After selection and confirmation, print the selected command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **$1** (string): branch: Branch name to substitute into push commands.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
- **2**: Invalid or missing arguments.

### shell::git::branch::push::current

Convenience wrapper around shell::git::branch::push that automatically detects
the currently checked-out branch and invokes the push command for it.

#### Example

```bash
shell::git::branch::push::current
shell::git::branch::push::current -n
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **1**: The operation failed.

### shell::git::branch::push::current::force

Convenience wrapper around shell::git::branch::push that automatically detects
the currently checked-out branch and invokes a force-push command for it.
This is a specialized function for the common case of needing to force-push the
current branch to origin. It prompts for confirmation before executing the force-push.

#### Example

```bash
shell::git::branch::push::current::force
```

#### Options

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::branch::backup

Creates a local backup branch pointing to the same commit as the given source
branch, without switching HEAD. Sends a Telegram activity notification on success.

Step 1 — Validate that the source branch exists locally.
If it is only on origin, offers a clear error message.
Step 2 — Build the backup branch name from the sanitized source name
and a timestamp (YYYYMMDD.HHMMSS).
Step 3 — Run: git branch <backup_name> <source_branch>
This creates the backup branch at the same commit as the source
WITHOUT switching HEAD — the working tree is never disturbed.
Step 4 — Push the backup branch to origin with upstream tracking:
git push -u origin <backup_name>
Step 5 — Log the backup name, copy it to the clipboard via shell::clipboard::copy,
and send a Telegram activity notification.

Safety notes:
• No checkout / restore cycle: HEAD never moves, so in-progress work is safe.
• The backup branch is pushed to origin immediately for remote storage.
• Backup names are collision-resistant: timestamp precision is 1 second.

#### Example

```bash
main                 → backup/main/20260618.215830
feature/TM-1234      → backup/feature--TM-1234/20260618.215830
release/v2.0/hotfix  → backup/release--v2.0--hotfix/20260618.215830
shell::git::branch::backup "main"
shell::git::branch::backup "feature/TM-1234"
shell::git::branch::backup -n "release/v2.0"
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the git branch command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **$1** (string): branch: Source branch name to back up. Backup name pattern: backup/<sanitized-branch>/<YYYYMMDD.HHMMSS> <sanitized-branch> is the source branch name with every '/' replaced by '--' (double-dash) so that the backup hierarchy is always exactly two levels deep and single dashes inside branch names remain unambiguous.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
- **2**: Invalid or missing arguments.

### shell::git::branch::backup::current

Creates a local backup branch of the currently checked-out branch without switching HEAD. Sends a Telegram activity notification on success.

1. Determine the currently checked-out branch.
2. Call shell::git::branch::backup with the current branch name.

#### Example

```bash
shell::git::branch::backup::current
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the git branch command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **1**: The operation failed.

### shell::git::branch::rename

Renames a local Git branch both locally and on the remote origin, then
restores the originally checked-out branch and sends a Telegram notification.

Step 1 — git branch -m <old_name> <new_name> — rename locally
Step 2 — git push -u origin <new_name> — push new name with upstream tracking
Step 3 — git push origin --delete <old_name> — remove old name from origin
(failure is logged and warned but does not abort — the old name
may not exist on origin if it was never pushed)
Step 4 — git checkout <original_branch> — restore originally checked-out branch
Step 5 — shell::git::telegram::send_activity — Telegram notification

#### Example

```bash
shell::git::branch::rename "feature/old-name" "feature/new-name"
shell::git::branch::rename -n "main" "mainline"
```

#### Options

- **-n** | **--dry-run**

  Optional. Print each command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **$1** (string): old_name: Current branch name.
- **$2** (string): new_name: Desired new branch name.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
- **2**: Invalid or missing arguments.

### shell::git::branch::rename::current

Renames the currently checked-out branch to a new name, both locally and on
the remote origin. Delegates entirely to shell::git::branch::rename.

#### Example

```bash
shell::git::branch::rename::current "feature/new-name"
shell::git::branch::rename::current -n "feature/new-name"
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the commands instead of executing them.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **$1** (string): new_name: Desired new branch name.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
- **2**: Invalid or missing arguments.

### shell::git::branch::rename::fzf

Presents an fzf picker of all local branches, prompts for a new name via
stdin, then delegates to shell::git::branch::rename.

Step 1 — Collect all local branch names and present via shell::ask::option.
Step 2 — Prompt for the desired new branch name (loops until non-empty).
Step 3 — Confirm and delegate to shell::git::branch::rename.

#### Example

```bash
shell::git::branch::rename::fzf
shell::git::branch::rename::fzf -n
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the commands instead of executing them.

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::branch::all::fzf

Lists all local and remote branches with sync-state labels, presents a
multi-select picker, then shows an action menu to act on the selected
branches using existing shell::git::\* functions.

#### Example

```bash
shell::git::branch::all::fzf
```

#### Options

- **-h** | **--help**

  Show this help message. Branch label format (columns are fixed-width for alignment in fzf):

#### Arguments

- **...** (string): REMOTE : <branch> — exists only on origin, not present locally The ' : ' separator uses ':' which is prohibited in git branch names, making it a reliable extraction anchor in the space-joined multiselect output. Action menu (presented after branch selection via shell::ask::option::value): • Checkout → shell::git::branch::checkout (first selected) • View commit history → shell::git::commit::spec (first selected) • Browse commits and copy info → shell::git::commit::spec::search (first selected) • Cherry-pick commits onto current → shell::git::commit::pick::local (first selected) • Cherry-pick commits then push → shell::git::commit::pick::remote (first selected) • Backup selected branch(es) → shell::git::branch::backup (each selected) • Push selected branch(es) to remote → shell::git::branch::push (each selected) • Remove selected branch(es) → shell::git::branch::remove (all selected) • Sync all remote branches to local → shell::git::branch::sync (ignores selection) • Exit — noop → return immediately

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::branch::merge

Merges a source branch into a target branch with conflict detection and an
interactive push step after a successful merge.

Step 1 — Capture the currently checked-out branch so it can be restored.
Step 2 — Checkout <target_branch>.
Step 3 — Run: git merge --no-commit <source_branch>
(stages changes without auto-creating the merge commit).
Step 4 — If unmerged files are present, list them with conflict counts
and return $RETURN_FAILURE so the user can resolve manually.
Step 5 — Confirm and commit: git commit -m "Merged <source> into <target>"
Step 6 — Delegate push to shell::git::branch::push (interactive strategy).
Step 7 — Restore the original branch.
Step 8 — Send Telegram activity notification.

#### Example

```bash
shell::git::branch::merge "feature/my-feature" "develop"
shell::git::branch::merge -n "feature/my-feature" "main"
```

#### Options

- **-n** | **--dry-run**

  Optional. Print each command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **$1** (string): source_branch: Branch whose changes will be merged in.
- **$2** (string): target_branch: Branch that will receive the changes.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
- **2**: Invalid or missing arguments.

### shell::git::branch::merge::fzf

Interactively selects source and target branches via fzf, then delegates to
shell::git::branch::merge to perform the merge.

Step 1 — Collect all local branch names.
Step 2 — Present source branch picker via shell::ask::option (fzf).
Step 3 — Present target branch picker via shell::ask::option (fzf),
excluding the source branch from the list.
Step 4 — Confirm the merge plan with the user.
Step 5 — Delegate to shell::git::branch::merge [-n] <source> <target>.

#### Example

```bash
shell::git::branch::merge::fzf
shell::git::branch::merge::fzf -n
```

#### Options

- **-n** | **--dry-run**

  Optional. Forward dry-run flag to shell::git::branch::merge.

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::branch::stash

Stashes all changes (tracked and untracked) in the current Git repository
with an optional message. Defaults to a timestamped message including the
current branch name.

Runs: git stash save --include-untracked "<message>"
The default message format follows the convention: "WIP on <branch>: <date>"
This ensures stashes are traceable to their branch of origin.

#### Example

```bash
shell::git::branch::stash
shell::git::branch::stash "Work in progress on feature"
shell::git::branch::stash -n
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the git stash command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **$1** (string): message: Optional. Custom stash message. Defaults to current date.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::branch::stash::remove::fzf

Presents an fzf picker of stashes for the current branch, then removes the
selected stash after confirmation.

Step 1 — Verify the git repository and capture the current branch.
Step 2 — Build a list of stashes filtered to the current branch.
Step 3 — Present a single-select picker via shell::ask::option.
Step 4 — Extract the stash reference (stash@{N}) from the selection.
Step 5 — Confirm removal with the user.
Step 6 — Execute: git stash drop <stash_ref>

#### Example

```bash
shell::git::branch::stash::remove::fzf
shell::git::branch::stash::remove::fzf -n
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::branch::stash::preview::fzf

Presents an fzf picker of stashes for the current branch for browsing only.
No stash is modified — this is a read-only viewer.

Step 1 — Verify the git repository and capture the current branch.
Step 2 — Build a list of stashes filtered to the current branch.
Step 3 — Present a single-select picker via shell::ask::option.
Step 4 — Show the diff of the selected stash via git stash show -p.
Step 5 — Copy the stash reference to clipboard for convenience.

#### Example

```bash
shell::git::branch::stash::preview::fzf
shell::git::branch::stash::preview::fzf -n
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the git stash list command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::branch::stash::apply::fzf

Presents an fzf multi-select picker of stashes for the current branch,
then applies each selected stash in order. Continues on individual failures.

Step 1 — Verify the git repository and capture the current branch.
Step 2 — Build a list of stashes filtered to the current branch.
Step 3 — Present a multi-select picker via shell::ask::options.
Step 4 — Extract stash references (stash@{N}) from the selection.
Step 5 — Apply each selected stash in order, continuing on failure.
Step 6 — Summarize success/failure counts.

#### Example

```bash
shell::git::branch::stash::apply::fzf
shell::git::branch::stash::apply::fzf -n
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the commands via shell::logger::command_clip instead of executing them.

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::commit::spec

Displays a decorated commit graph for a specific branch.

Runs git log with a coloured, decorated graph format scoped to the given
branch. Format: full hash (short hash) — relative time author refs subject.

#### Example

```bash
shell::git::commit::spec "main"
shell::git::commit::spec -n "feature/my-branch"
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **$1** (string): branch: The branch whose commit history to display.

#### Exit codes

- **0**: Success.
- **2**: Invalid or missing arguments.

### shell::git::commit::spec::current

Displays a decorated commit graph for the currently active branch.

Detects the currently active branch and forwards it to shell::git::commit::spec
to display its commit graph. If not inside a Git repository, an error is logged
and the function returns with failure.

#### Example

```bash
shell::git::commit::spec::current
shell::git::commit::spec::current -n
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **1**: The operation failed.

### shell::git::commit::all

Displays a decorated commit graph across all refs in the current repository.

Runs git log --all with a coloured, decorated graph format, covering all
local branches, remote-tracking branches, and tags in the repository.

#### Example

```bash
shell::git::commit::all
shell::git::commit::all -n
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **0**: Success.

### shell::git::commit::spec::fzf

Interactively selects a branch via fzf, then displays its commit history.

Collects all local and remote branches from the current repository,
deduplicates them, and presents them in an fzf picker. The selected branch
is forwarded to shell::git::commit::spec to display its commit graph.

#### Example

```bash
shell::git::commit::spec::fzf
shell::git::commit::spec::fzf -n
```

#### Options

- **-n** | **--dry-run**

  Optional. After branch selection, print the git log command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::commit::spec::search

Presents a multi-select picker of all commits on a given branch, then prints
each selected commit's info to the console and copies it to the clipboard.

Builds a coloured commit list via git log for the specified branch, then
delegates to shell::ask::options (TAB to select multiple entries).
For each selected commit, logs the message via shell::logger::info and copies
it to the clipboard via shell::clipboard::copy.

Hash extraction is ANSI-safe: uses grep -oE to locate every 40-char hex hash
in the multiselect output — no sed ANSI stripping required.

#### Example

```bash
shell::git::commit::spec::search "main"
shell::git::commit::spec::search "feature/my-branch"
```

#### Options

- **-h** | **--help**

  Show this help message.

#### Arguments

- **$1** (string): branch: Required. Branch name whose commits to browse and select from.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
- **2**: Invalid or missing arguments.

### shell::git::commit::spec::search::current

Presents a multi-select picker of all commits on the currently active branch,
then prints each selected commit's info to the console and copies it to the clipboard.

Detects the currently active branch and forwards it to shell::git::commit::spec::search
to present the commit multi-select for that branch. If not inside a Git repository, an error is logged and the function returns with failure.

#### Example

```bash
shell::git::commit::spec::search::current
```

#### Options

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **1**: The operation failed.

### shell::git::commit::all::search

Presents a multi-select picker of all commits across all refs in the repository,
then prints each selected commit's info to the console and copies it to the clipboard.

Builds a coloured commit list via git log --all covering all local branches,
remote-tracking branches, and tags, then delegates to
shell::ask::options (TAB to select multiple entries).
For each selected commit, logs the message via shell::logger::info and copies
it to the clipboard via shell::clipboard::copy.

Hash extraction is ANSI-safe: uses grep -oE to locate every 40-char hex hash
in the multiselect output — no sed ANSI stripping required.

#### Example

```bash
shell::git::commit::all::search
```

#### Options

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::commit::pick::local

Multi-selects commits from a source branch (or across all refs) via fzf, then
cherry-picks the selected commits onto the current branch in chronological order.

Step 1 — Verify the git repository and capture the current (target) branch.
Step 2 — Build a coloured commit list:
• With <source_branch>: git log <source_branch>
• Without : git log --all
Step 3 — Present a multi-select picker (TAB to select multiple commits).
Step 4 — Extract 40-char hex hashes from the selection in git-log order
(newest first), then reverse them to chronological order
(oldest first) — the required replay order for cherry-pick.
Step 5 — Display the ordered cherry-pick plan and confirm with the user.
Step 6 — Execute: git cherry-pick <hash1> <hash2> ...
On conflict, git stops automatically; the user must resolve it
manually and run 'git cherry-pick --continue', or abort with
'git cherry-pick --abort'.

#### Example

```bash
shell::git::commit::pick::local
shell::git::commit::pick::local "feature/my-branch"
shell::git::commit::pick::local -n "main"
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the cherry-pick command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **$1** (string): source_branch: Optional. Branch whose commits to browse and pick from. When omitted, commits from ALL refs are shown (--all).

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::commit::pick::remote

Multi-selects commits from a source branch (or across all refs) via fzf,
cherry-picks them onto the current branch in chronological order, then
pushes the current branch to the remote via an interactive push strategy picker.

Identical to shell::git::commit::pick::local with one additional step:
Step 7 — After a successful cherry-pick, delegates to shell::git::branch::push
to present an interactive fzf push strategy picker and push the
current branch to origin.

Step 1 — Verify the git repository and capture the current (target) branch.
Step 2 — Build a coloured commit list:
• With <source_branch>: git log <source_branch>
• Without : git log --all
Step 3 — Present a multi-select picker (TAB to select multiple commits).
Step 4 — Extract 40-char hex hashes, reverse to chronological order
(oldest first) — the required replay order for cherry-pick.
Step 5 — Display the ordered cherry-pick plan and confirm with the user.
Step 6 — Execute: git cherry-pick <hash1> <hash2> ...
Step 7 — Push the current branch via shell::git::branch::push (interactive).

#### Example

```bash
shell::git::commit::pick::remote
shell::git::commit::pick::remote "feature/my-branch"
shell::git::commit::pick::remote -n "main"
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the cherry-pick and push commands via shell::logger::command_clip instead of executing them.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **$1** (string): source_branch: Optional. Branch whose commits to browse and pick from. When omitted, commits from ALL refs are shown (--all).

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::commit::message::base

Presents a two-level interactive menu — first a commit message category,
then a pre-defined message within that category — and prints the selected
message to stdout. Designed as a reusable scaffold for scripted or empty
commits, callable independently or from shell::git::commit::create.

#### Example

```bash
shell::git::commit::message::base
selected=$(shell::git::commit::message::base)
```

#### Options

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **0**: Success.

### shell::git::commit::create

Interactively builds and commits a formatted Git commit message. In default
mode, prompts for commit type (with emoji), description, and issue number,
then commits, sends a Telegram activity notification, and pushes to origin.
In --empty mode, presents pre-defined empty commit messages grouped by
category for selection via fzf, then runs git commit --allow-empty.

Default mode:

1. Select commit type (feat, fix, chore, …) via shell::ask::option
2. Map type → emoji code via case lookup
3. Read commit description (loops until non-empty)
4. Read issue number (loops until non-empty)
5. Build message: <emoji> <type>: <description> <issue>
6. Confirm → git commit -m "<message>"
7. Send Telegram notification via shell::git::telegram::history::send
8. git push origin <current_branch>
   Empty mode (--empty):
9. Select category via shell::ask::option
10. Select pre-defined message from category via shell::ask::option
11. Confirm → git commit --allow-empty -m "<message>"

#### Example

```bash
shell::git::commit::create
shell::git::commit::create --empty
shell::git::commit::create -n
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the git commit command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

- **-e** | **--empty**

  Optional. Switch to empty-commit mode — select a pre-defined message and run git commit --allow-empty.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::commit::checkout

Checks out a specific commit hash (detached HEAD). Optionally creates a new
branch from that commit. Supports dry-run mode.

Step 1 — Verify the commit hash exists in the repository.
Step 2 — If -b is provided, run: git checkout -b <branch_name> <commit_hash>
Otherwise, run: git checkout <commit_hash>
Step 3 — Log the result via shell::logger::assert.

Safety notes:
• When -b is omitted, HEAD enters detached state. Run 'git checkout <branch>'
or 'git switch -' to return to a branch.
• When -b is provided, the new branch is created at the commit and checked
out immediately (no detached HEAD).

#### Example

```bash
shell::git::commit::checkout "abc1234"
shell::git::commit::checkout -b "hotfix-legacy" "abc1234"
shell::git::commit::checkout -n "abc1234"
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

- **-b** | **--branch**

  Optional. Create and checkout a new branch from the commit instead of detached HEAD.

#### Arguments

- **$1** (string): commit_hash: Required. Full or short commit hash to checkout.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
- **2**: Invalid or missing arguments.

### shell::git::commit::checkout::fzf

Presents a multi-select picker of all commits across all refs via fzf,
then checks out the first selected commit via shell::git::commit::checkout.
Optionally creates a new branch from the selected commit.

Step 1 — Verify the git repository.
Step 2 — Build a coloured commit list via git log --all covering all local
branches, remote-tracking branches, and tags.
Step 3 — Present a multi-select picker (TAB to mark multiple entries).
Step 4 — Extract the first 40-char hex hash from the selection.
Step 5 — Forward to shell::git::commit::checkout with the extracted hash.
If -b was provided, the branch name is forwarded as well.

#### Example

```bash
shell::git::commit::checkout::fzf
shell::git::commit::checkout::fzf -b "legacy-fix"
shell::git::commit::checkout::fzf -n
```

#### Options

- **-n** | **--dry-run**

  Optional. After selection, print the checkout command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

- **-b** | **--branch**

  Optional. Create and checkout a new branch from the selected commit instead of detached HEAD.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::tag::create

Checks out a specified branch, creates an annotated Git tag on the latest
commit, pushes the tag to origin, restores the original branch, and sends a
Telegram activity notification via shell::git::telegram::history::send.

1. git checkout <branch> — switch to target branch
2. Collect commit metadata — short hash, author, date
3. git tag -a <tag> -m <message> — create annotated tag with metadata
4. git push origin <tag> — push tag to origin
5. git checkout <original_branch> — restore original branch
6. shell::git::telegram::history::send — send Telegram notification

#### Example

```bash
shell::git::tag::create "main" "v1.0.0"
shell::git::tag::create -n "release/1.0" "v1.0.0"
```

#### Options

- **-n** | **--dry-run**

  Optional. Print each command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **$1** (string): branch: Branch name to check out before tagging.
- **$2** (string): tag: Annotated tag name/version to create (e.g. v1.2.3).

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
- **2**: Invalid or missing arguments.

### shell::git::tag::remove

Deletes an annotated or lightweight Git tag both locally and on the remote
origin, then sends a Telegram activity notification.

1. git tag -d <tag> — delete the tag locally
2. git push origin :refs/tags/<tag> — delete the tag on origin
3. shell::git::telegram::history::send — send Telegram notification

#### Example

```bash
shell::git::tag::remove "v1.0.0"
shell::git::tag::remove -n "v1.0.0"
```

#### Options

- **-n** | **--dry-run**

  Optional. Print each command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **$1** (string): tag: The tag name/version to delete (e.g. v1.2.3).

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
- **2**: Invalid or missing arguments.

### shell::git::tag::checkout

Checks out a specific Git tag into a detached HEAD state. Optionally creates
a new branch from the tag. Supports dry-run mode.

Step 1 — Verify the tag exists locally or on origin.
Step 2 — If -b is provided, run: git checkout -b <branch_name> <tag>
Otherwise, run: git checkout <tag>
Step 3 — Log the result via shell::logger::assert.

Safety notes:
• When -b is omitted, HEAD enters detached state at the tag commit.
Run 'git checkout <branch>' or 'git switch -' to return to a branch.
• When -b is provided, the new branch is created at the tag commit and
checked out immediately (no detached HEAD).
• Tags are immutable references; checking out a tag directly is read-only.

#### Example

```bash
shell::git::tag::checkout "v1.0.0"
shell::git::tag::checkout -b "release-1.0" "v1.0.0"
shell::git::tag::checkout -n "v1.0.0"
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

- **-b** | **--branch**

  Optional. Create and checkout a new branch from the tag instead of detached HEAD.

#### Arguments

- **$1** (string): tag: Required. The tag name/version to checkout (e.g. v1.2.3).

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
- **2**: Invalid or missing arguments.

### shell::git::tag::checkout::fzf

Presents a picker of all Git tags (local + remote) with origin markers,
then checks out the selected tag via shell::git::tag::checkout.
Optionally creates a new branch from the selected tag.

Step 1 — Verify the git repository.
Step 2 — Collect all local tags and remote tags from origin.
Step 3 — Build display lines with origin markers:
[LOCAL ] : <tag> — exists only locally
[REMOTE ] : <tag> — exists only on origin
[BOTH ] : <tag> — exists on both local and origin
Step 4 — Present a single-select picker via shell::ask::option.
Step 5 — Extract the tag name from the selection using the ' : ' separator.
Step 6 — Forward to shell::git::tag::checkout with the extracted tag name.
If -b was provided, the branch name is forwarded as well.

#### Example

```bash
shell::git::tag::checkout::fzf
shell::git::tag::checkout::fzf -b "release-1.0"
shell::git::tag::checkout::fzf -n
```

#### Options

- **-n** | **--dry-run**

  Optional. After selection, print the checkout command via shell::logger::command_clip instead of executing it.

- **-h** | **--help**

  Show this help message.

- **-b** | **--branch**

  Optional. Create and checkout a new branch from the selected tag instead of detached HEAD.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::tag::all

Displays all Git tags in the repository, both local and remote, with origin
markers and associated commit metadata.

Collects all local tags and remote tags from origin, deduplicates them,
and prints a formatted table showing:
• Tag name
• Origin marker: [LOCAL] | [REMOTE] | [BOTH]
• Commit hash (short)
• Commit date
• Commit message (first line)
• Tagger name (for annotated tags) or author (for lightweight tags)

#### Example

```bash
shell::git::tag::all
shell::git::tag::all -n
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the git commands via shell::logger::command_clip instead of executing them.

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::tag::remove::fzf

Presents a picker of all Git tags (local + remote) with origin markers,
then removes the selected tag via shell::git::tag::remove.

Step 1 — Verify the git repository.
Step 2 — Collect all local tags and remote tags from origin.
Step 3 — Build display lines with origin markers:
[LOCAL ] : <tag> — exists only locally
[REMOTE ] : <tag> — exists only on origin
[BOTH ] : <tag> — exists on both local and origin
Step 4 — Present a single-select picker via shell::ask::option.
Step 5 — Extract the tag name from the selection using the ' : ' separator.
Step 6 — Confirm removal with the user.
Step 7 — Forward to shell::git::tag::remove with the extracted tag name.

#### Example

```bash
shell::git::tag::remove::fzf
shell::git::tag::remove::fzf -n
```

#### Options

- **-n** | **--dry-run**

  Optional. After selection, print the remove commands via shell::logger::command_clip instead of executing them.

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::commit::revert::fzf

Presents a multi-select picker of all commits across all refs in the repository,
then shows an action menu to revert the selected commits with various strategies.
Supports creating a new revert branch, handling conflicts, and pushing to remote.

Step 1 — Verify the git repository.
Step 2 — Build a coloured commit list via git log --all covering all local
branches, remote-tracking branches, and tags.
Step 3 — Present a multi-select picker (TAB to mark multiple commits).
Step 4 — Extract 40-char hex hashes from the selection.
Step 5 — Build a revert branch name: rev/<YYYYMMDD.HHMMSS>.<sanitized-source>
Step 6 — Present an action menu with revert strategies:
• Revert commits (auto-commit) — git revert <hash1> <hash2> ...
• Revert commits (no-commit) — git revert -n <hash1> <hash2> ...
• Revert merge commit (-m 1) — git revert -m 1 <merge-hash>
• Revert range (oldest..newest) — git revert <old>..<new>
• Revert with custom message — git revert --edit <hash1> ...
• Revert quietly (no editor) — git revert --no-edit <hash1> ...
Step 7 — Create revert branch, execute revert, handle conflicts.
Step 8 — Prompt: commit to local / push to remote / both.
Step 9 — Execute chosen action and send Telegram notification.

Branch naming pattern:
rev/<YYYYMMDD.HHMMSS>.<sanitized-source>
<sanitized-source> is derived from current branch or first commit hash.

#### Example

```bash
shell::git::commit::revert::fzf
shell::git::commit::revert::fzf -n
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the commands via shell::logger::command_clip instead of executing them.

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::git::commit::spec::history::fzf

Interactive commit history browser: selects a commit via fzf, then loops
through view-action picks until the user explicitly chooses Exit.

Step 1 — Verify git repository and resolve target branch.
Step 2 — Build a coloured commit list (full 40-char hash per entry).
Step 3 — Present commit picker via shell::ask::option (fzf wrapper).
Step 4 — Extract 40-char commit hash from the selected line.
Step 5 — Collect commit metadata (author, date, subject).
Step 6–7 (loop) — Repeatedly present view-action picker via
shell::ask::option::value, render the selected view in a tmux
display-popup (90 × 90 %) or less, then return to the picker.
Available actions:
• diff — full git show (what changed in this commit)
• blame — git blame per file at this commit (who wrote each line)
• file_history — git log --follow -p per file (full change history)
• stat — files changed with line-count stats only
• exit — leave the view loop and return to the terminal
Step 8 — Log commit info and copy to clipboard via shell::clipboard::copy.

#### Example

```bash
shell::git::commit::spec::history::fzf
shell::git::commit::spec::history::fzf "feature/my-branch"
shell::git::commit::spec::history::fzf -n
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the git log command instead of executing.

- **-h** | **--help**

  Show this help message.

#### Arguments

- **$1** (string): branch: Optional. Branch to inspect. Defaults to current branch.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
- **2**: Invalid or missing arguments.

### shell::git::commit::spec::history::fzf::current

Convenience wrapper around shell::git::commit::spec::history::fzf that
automatically detects the currently checked-out branch and opens the
interactive commit history viewer for it.

#### Example

```bash
shell::git::commit::spec::history::fzf::current
shell::git::commit::spec::history::fzf::current -n
```

#### Options

- **-n** | **--dry-run**

  Optional. Print the commands instead of executing them.

- **-h** | **--help**

  Show this help message.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
