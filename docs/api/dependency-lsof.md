# dependency/lsof.sh

Ensure `lsof` is installed (open-files/port inspector used by shell::net::port::\*).

## Overview

Make sure `lsof` is available, installing it when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (`SHELL_AUTO_INSTALL_DEPS`).

## Index

- [dependency/lsof.sh](#dependencylsofsh)
  - [Overview](#overview)
  - [Index](#index)
    - [shell::dependency::lsof::ensure](#shelldependencylsofensure)
      - [Example](#example)
      - [Exit codes](#exit-codes)
      - [See also](#see-also)

### shell::dependency::lsof::ensure

Make sure `lsof` is available, installing it when allowed.
Thin wrapper around `shell::dependency::ensure`; see that function for the
install policy (`SHELL_AUTO_INSTALL_DEPS`).

#### Example

```bash
shell::dependency::lsof::ensure || return
```

_Function has no arguments._

#### Exit codes

- **0**: `lsof` is available.
- **3**: `lsof` is missing and could not be installed.

#### See also

- [shell::dependency::ensure](#shelldependencyensure)
