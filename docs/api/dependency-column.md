# dependency/column.sh

Ensure `column` is installed (column formatter used by shell::fs::ls).

## Overview

Make sure `column` is available, installing it when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (`SHELL_AUTO_INSTALL_DEPS`).

## Index

- [dependency/column.sh](#dependencycolumnsh)
  - [Overview](#overview)
  - [Index](#index)
    - [shell::dependency::column::ensure](#shelldependencycolumnensure)
      - [Example](#example)
      - [Exit codes](#exit-codes)
      - [See also](#see-also)

### shell::dependency::column::ensure

Make sure `column` is available, installing it when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (`SHELL_AUTO_INSTALL_DEPS`).

#### Example

```bash
shell::dependency::column::ensure || return
```

_Function has no arguments._

#### Exit codes

- **0**: `column` is available.
- **3**: `column` is missing and could not be installed.

#### See also

- [shell::dependency::ensure](#shelldependencyensure)
