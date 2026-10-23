# dependency/ensure.sh

Generic "make sure this command exists" engine and dependency report.

## Overview

Every per-tool installer (`fzf.sh`, `jq.sh`, ...) is a one-line wrapper around
shell::dependency::ensure. Keeping the logic here means the install policy
(auto-install or only report) is controlled by one switch:
`SHELL_AUTO_INSTALL_DEPS` (constant/defaults.sh).

## Index

- [shell::dependency::ensure](#shelldependencyensure)
- [shell::dependency::doctor](#shelldependencydoctor)

### shell::dependency::ensure

Make sure a command is available, installing it if allowed.
Fast path: when the command already exists this is a single `command -v`
(no package-database query), which matters because pickers call it on every
invocation.

#### Example

```bash
shell::dependency::ensure jq || return
shell::dependency::ensure dig dnsutils
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Arguments

- **$1** (string): Command that must exist.
- **$2** (string): Package providing it (default: derived from the command name).

#### Exit codes

- **0**: The command is available.
- **2**: No command name was given.
- **3**: The command is missing and could not (or may not) be installed.

### shell::dependency::doctor

Report which declared dependencies are installed.
Reads `SHELL_DEPENDENCIES_REQUIRED` and `SHELL_DEPENDENCIES_OPTIONAL`.

#### Example

```bash
shell::dependency::doctor
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Exit codes

- **0**: Every REQUIRED dependency is installed.
- **3**: At least one REQUIRED dependency is missing.

#### Output on stdout

- One line per dependency with its status.
