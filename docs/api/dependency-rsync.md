# dependency/rsync.sh

Ensure `rsync` is installed (used by shell::ssh::rsync::\*).

## Overview

Make sure `rsync` is available, installing it when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (SHELL_AUTO_INSTALL_DEPS).

## Index

- [dependency/rsync.sh](#dependencyrsyncsh)
  - [Overview](#overview)
  - [Index](#index)
    - [shell::dependency::rsync::ensure](#shelldependencyrsyncensure)
      - [Example](#example)
      - [Exit codes](#exit-codes)
      - [See also](#see-also)

### shell::dependency::rsync::ensure

Make sure `rsync` is available, installing it when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (SHELL_AUTO_INSTALL_DEPS).

#### Example

```bash
shell::dependency::rsync::ensure || return
```

_Function has no arguments._

#### Exit codes

- **0**: `rsync` is available.
- **3**: `rsync` is missing and could not be installed.

#### See also

- [shell::dependency::ensure](#shelldependencyensure)
