# skill/query.sh

Read-only queries: which skills exist upstream, which are installed here.

## Overview

Both functions print tab-separated rows on stdout (so they can be piped to
`cut`, `awk` or `fzf`) and align them in columns when stdout is a terminal.
They change nothing on disk.

## Index

- [shell::skill::list](#shellskilllist)
- [shell::skill::installed](#shellskillinstalled)

### shell::skill::list

List the skills available upstream.
Downloads the upstream README and reads its generated skills table, so the
list is always current without cloning the repository.

#### Example

```bash
shell::skill::list
shell::skill::list golang
shell::skill::list --ref v1.0.0 security | cut -f2
```

#### Options

- **-r** | **--ref**

  Branch, tag or commit to read (default: SHELL_SKILL_REPO_BRANCH).

- **-h** | **--help**

  Show help and return.

#### Arguments

- **$1** (string): Optional case-insensitive text; only rows containing it are printed (category, slug or tag).

#### Exit codes

- **0**: At least one skill was printed.
- **1**: The README could not be downloaded or has no skills table.
- **2**: Invalid option or value.
- **8**: No skill matches the filter.

#### Output on stdout

- One row per skill: `category<TAB>skill<TAB>tags`.

### shell::skill::installed

List the skills installed by shell::skill::install.
Reads the installer's manifest, so it only reports what this tool placed
(not skills you added to the tool's directories by hand).

#### Example

```bash
shell::skill::installed
shell::skill::installed -t claude -s personal
shell::skill::installed golang | cut -f3
```

#### Options

- **-t** | **--tool**

  Only this tool: claude or opencode.

- **-s** | **--scope**

  Only this scope: personal or project.

- **-h** | **--help**

  Show help and return.

#### Arguments

- **$1** (string): Optional case-insensitive text; only rows containing it are printed.

#### Exit codes

- **0**: At least one installed skill was printed.
- **2**: Invalid option or value.
- **8**: Nothing is installed (or nothing matches).

#### Output on stdout

- One row per installed skill: `tool<TAB>scope<TAB>skill<TAB>mode<TAB>path`.
