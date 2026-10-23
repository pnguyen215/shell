# dependency/fzf.sh

Ensure `fzf` is installed (interactive fuzzy finder used by every \*::fzf function).

## Overview

Make sure `fzf` is available, installing it when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (`SHELL_AUTO_INSTALL_DEPS`).

## Index

- [dependency/fzf.sh](#dependencyfzfsh)
  - [Overview](#overview)
  - [Index](#index)
    - [shell::dependency::fzf::ensure](#shelldependencyfzfensure)
      - [Example](#example)
      - [Exit codes](#exit-codes)
      - [See also](#see-also)

### shell::dependency::fzf::ensure

Make sure `fzf` is available, installing it when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (`SHELL_AUTO_INSTALL_DEPS`).

#### Example

```bash
shell::dependency::fzf::ensure || return
```

_Function has no arguments._

#### Exit codes

- **0**: `fzf` is available.
- **3**: `fzf` is missing and could not be installed.

#### See also

- [shell::dependency::ensure](#shelldependencyensure)
