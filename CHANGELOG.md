# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Git toolkit** (`src/lang/git/`, one public function per file): `branch::{pick,recent,cleanup,compare}`,
  `commit::{pick,fixup,squash,revert}`, `stage::{pick,patch,unstage,discard}`,
  `log::{pick,search,file,graph,blame}`, `remote::{sync,compare,fetch,prune}`,
  `stash::{pick,save,apply,drop}`, `repo::{health,stats,size,summary}` and
  `flow::{feature,release,hotfix,sync}`. Interactive with fzf (numbered fallback), `-n` dry-run, explicit
  confirmations, `refs/shell-backup/*` recovery refs for rewrites and discards, exit codes 0-7. See
  `docs/features/git-toolkit.md`. `branch::sync` and `commit::amend` already existed and are unchanged.
- `test/test_startup.sh`, `test_git_*.sh` and `test_install_toolkit.sh`.

### Changed

- **Start-up is about 60 ms faster** (bash +69 ms to about +11 ms over an empty shell, zsh +79 ms to about +10 ms,
  zero external processes at load): modules that only define functions are loaded lazily through a cache in
  `<install dir>/.cache/lazy.sh`; user overrides of library functions keep working. `SHELL_LAZY=0` restores eager
  loading. `SHELL_DIR`, the OS and the logger style are resolved without forks at load; the logger style is read
  on the first message.

## [2.0.11] - 2026-11-26

### Added

- `shell::git::diff::fzf --pick` renders the commit list with ANSI colors on
  terminals that support at least 8 colors: hash yellow, author cyan and relative
  date green, with `--ansi` passed to fzf. The plain `%h %s (%an, %ar)` format is
  kept when colors are unavailable, so piped or low-color output is unchanged.

### Changed

- `shell::git::commit::pick::fzf`: source-branch rows now show the commit time
  (`HH:MM`) next to the date, color `[local]` rows green and `[remote]` rows cyan,
  and pad branch names so the date/time and subject columns line up. The full ref
  in the second, tab-separated column is unchanged, so selection behavior is the
  same.
- `README.md` is organized into collapsible sections with a table of contents and
  stable anchors; the configuration and dependency reference moved into their own
  subsections, and the development commands moved under "Testing & Benchmarks".
- The test suite now refuses to run unless it is started through
  `test/run_tests.sh` (for example `make test`), and pins `GIT_CONFIG_GLOBAL` and
  `GIT_CONFIG_NOSYSTEM` inside its sandbox, so a test run can no longer read or
  write your real `~/.gitconfig`.

### Fixed

- `shell::git::history` function and line scopes now walk `HEAD` instead of
  `--all`, fixing `git log -L` failing with `fatal: More than one commit to dig
from` when no branch was given. File, search and regex scopes still walk every
  branch.

[2.0.11]: https://github.com/pnguyen215/shell/compare/v2.0.10...v2.0.11
