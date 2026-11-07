# Git history explorer

`shell::git::history::fzf` shows **how a file, a function, a line range or a piece of code evolved**, one commit at a time: a dashboard, a vertical commit timeline and an fzf viewer with a live diff preview. It only reads the repository.

```
╭──────────────────────────────────────────────────────────────────────╮
│  GIT CHRONICLE                                                       │
│  Repository: my-project                                              │
│  Branch: develop                                                     │
├──────────────────────────────────────────────────────────────────────┤
│  SCOPE: FUNCTION                                                     │
│  File: src/auth/login.go                                             │
│  Function: Login()                                                   │
├──────────────────────────────────────────────────────────────────────┤
│  COMMITS           ADDITIONS         DELETIONS                       │
│  18                +248              -132                            │
╰──────────────────────────────────────────────────────────────────────╯

● 2026-10-28  a81f32c  Fix token expiration
│ alice  +18 -6
│
● 2026-10-21  c92b741  Add refresh token support
│ bob  +32 -4
│
● 2026-09-30  f32d110  Initial implementation
  alice  +76 -0
```

## Usage

```bash
shell::git::history::fzf src/auth/login.go                       # file history (git log --follow)
shell::git::history::fzf --function Login src/auth/login.go      # function history (git log -L :Login:file)
shell::git::history::fzf --lines 40,80 src/auth/login.go         # line range (git log -L 40,80:file)
shell::git::history::fzf --search refreshToken                   # commits that added/removed the text (git log -S)
shell::git::history::fzf --regex 'TODO|FIXME' src/auth/login.go  # commits whose diff matches (git log -G)
shell::git::history::fzf --interactive                           # pick the file, then the scope, in fzf
shell::git::history::fzf                                         # every commit of the repository
shell::git::history::fzf --print --function Login src/a.go       # dashboard + timeline on stdout, no fzf
shell::git::history::fzf -n --function Login src/a.go            # print the git command only
```

Other options: `--max <n>` (default 500, `SHELL_GIT_HISTORY_MAX`), `--no-merges`, `-b <branch>` (default: all branches), `-r`/`--sync` (fetch the remote first, silently; `SHELL_GIT_HISTORY_SYNC`, default off; `--no-sync` overrides; timeout `SHELL_GIT_HISTORY_SYNC_TIMEOUT`, default 60 s), `-h`.

## Keys

| Key             | Action                                                                       |
| --------------- | ---------------------------------------------------------------------------- |
| Up / Down       | Move; the preview follows the commit under the cursor                        |
| type            | Filter by message, author, date or hash (the order stays chronological)      |
| Enter           | Inspect: commit header + the diff **of the scope**, in a pager (`q` returns) |
| Ctrl-F          | The whole commit, including parts outside the scope                          |
| Ctrl-B          | `git blame` of the scope as it was at that commit                            |
| Ctrl-Y          | Copy the full commit hash                                                    |
| Ctrl-O          | Open the commit on GitHub / GitLab / Bitbucket (`shell::git::open::browser`) |
| Ctrl-D / Ctrl-U | Scroll the preview                                                           |
| `← Back`        | Leave with `RETURN_BACK` (11) so a caller can step back; ESC just quits      |

## What each scope means

Git tracks these differently, so they are **not** interchangeable:

| Scope    | Git mechanism                     | Additions / deletions shown                           |
| -------- | --------------------------------- | ----------------------------------------------------- |
| file     | `git log --follow -M`             | the file, across renames                              |
| function | `git log -L :<name>:<file>`       | the lines of **that function** only                   |
| lines    | `git log -L <start>,<end>:<file>` | the lines of **that range** only                      |
| search   | `git log -S<text>`                | the commits where the _number of occurrences_ changed |
| regex    | `git log -G<re>`                  | the commits whose diff has a matching line            |

In the viewer, the row summary (and the preview) separates what belongs to the scope from the rest of the commit, for example `Selected function: +1 -1 | rest of this commit: +1 -1 (2 file(s) in total) is outside the scope`. The dashboard totals are the scope's, never the whole repository's.

### Limits you should know

- **Function tracking is not AST tracking.** Git finds a function with per-language header patterns (a generic "line starts with a letter" rule when a language has none; add `*.ext diff=<lang>` in `.gitattributes` for better patterns). A renamed function starts a new history under its new name; the file rename itself is followed. Function names may contain `: . $ ~ # @ -` (a `::` is escaped for Git).
- `_shell::git::history::function::resolve` is the single place that turns a name into Git's `-L` argument. Redefine it (for example with a tree-sitter lookup printing `START,END:<file>`) to improve function resolution without touching the rest.
- **Deleted function:** if the function no longer exists at HEAD, its history is shown up to the commit _before_ the one that removed it (a `git log -L` walk cannot start from a revision where the function is gone). The removing commit is still inspectable from the file or repository scope; in the viewer a commit that removed the function falls back to the file diff, with a note.
- `git log --follow` and `-L` do not list merge commits that only combine two sides; the repository, `--search` and `--regex` scopes do, marked `◆`.
- A line range must exist at HEAD.
- Records use control characters (US `0x1f`, RS `0x1e`) as delimiters; a commit message containing them would corrupt only its own row.

## Design (for contributors)

The layers are separate and talk through one record format on stdin/stdout, so each is testable alone:

```
context → scope → log → stats → dashboard / timeline → fzf → preview / inspect
```

| Function                                  | Responsibility                                                                                                                                         |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `_shell::git::history::context`           | Repo root, name, branch (detached HEAD), file → repo-relative path, validation                                                                         |
| `_shell::git::history::scope`             | Normalize and validate the scope (range → `S,E`, function name charset)                                                                                |
| `shell::git::history::log`                | Retrieve **commit records**: full/short hash, author, date, scoped +/-, files, merge flag, path (and pre-rename path), whole-commit +/-, subject, body |
| `shell::git::history::stats`              | Commits, additions, deletions, earliest/latest, authors — from records                                                                                 |
| `shell::git::history::dashboard`          | The box (plain list under 44 columns)                                                                                                                  |
| `shell::git::history::timeline`           | The vertical timeline, or `--rows` for fzf                                                                                                             |
| `_shell::git::history::preview::command`  | The fzf preview command (plain `git`, quoted, no `eval`)                                                                                               |
| `shell::git::history::inspect` / `::show` | Pager view of one commit: scope diff, `--full`, `--blame`                                                                                              |
| `shell::git::history::pick`               | Interactive file → scope selection                                                                                                                     |
| `shell::git::history::fzf`                | The command: options, loop, key handling                                                                                                               |

A commit record is one line, fields separated by `$'\037'`: `full short author date adds dels files merge path oldpath whole_adds whole_dels whole_files subject body` (newlines in the body are written `\n`). Git is called with a fixed `--format` and `--numstat` (`-p` for `-L`, which supports nothing else); nothing parses human-readable output.

Colours need a terminal with 8+ colours (`NO_COLOR` is honoured). Diffs are highlighted with `delta` when installed, else `bat`, else Git's own colours; the pager is `$PAGER` or `less -R`. Only `git` and `fzf` are required.

## Tests

`test/test_git_history.sh` builds a throwaway repository (several functions, one-function and multi-function commits, a file rename, a function rename, a deleted function, shifted lines, a merge, a path with spaces, a long message, a 3000-line diff, an empty repository) and checks the scope accuracy, the statistics, the rendering and the fzf flow with a fake fzf. Run it with `test/run_tests.sh git_history`.
