# dependency/git.sh

Ensure `git` is installed (version control used by shell::git::*).

## Overview

Make sure `git` is available, installing it when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (SHELL_AUTO_INSTALL_DEPS).

## Index

* [shell::dependency::git::ensure](#shelldependencygitensure)

### shell::dependency::git::ensure

Make sure `git` is available, installing it when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (SHELL_AUTO_INSTALL_DEPS).

#### Example

```bash
shell::dependency::git::ensure || return
```

_Function has no arguments._

#### Exit codes

* **0**: `git` is available.
* **3**: `git` is missing and could not be installed.

#### See also

* [shell::dependency::ensure](#shelldependencyensure)

