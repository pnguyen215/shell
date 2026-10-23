# dependency/jq.sh

Ensure `jq` is installed (JSON processor used by the \*::dump::json functions).

## Overview

Make sure `jq` is available, installing it when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (`SHELL_AUTO_INSTALL_DEPS`).

## Index

- [shell::dependency::jq::ensure](#shelldependencyjqensure)

### shell::dependency::jq::ensure

Make sure `jq` is available, installing it when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (`SHELL_AUTO_INSTALL_DEPS`).

#### Example

```bash
shell::dependency::jq::ensure || return
```

_Function has no arguments._

#### Exit codes

- **0**: `jq` is available.
- **3**: `jq` is missing and could not be installed.

#### See also

- [shell::dependency::ensure](#shelldependencyensure)
