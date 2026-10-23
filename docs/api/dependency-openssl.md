# dependency/openssl.sh

Ensure `openssl` is installed (cryptography toolkit used by shell::crypto::*).

## Overview

Make sure `openssl` is available, installing it when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (SHELL_AUTO_INSTALL_DEPS).

## Index

* [shell::dependency::openssl::ensure](#shelldependencyopensslensure)

### shell::dependency::openssl::ensure

Make sure `openssl` is available, installing it when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (SHELL_AUTO_INSTALL_DEPS).

#### Example

```bash
shell::dependency::openssl::ensure || return
```

_Function has no arguments._

#### Exit codes

* **0**: `openssl` is available.
* **3**: `openssl` is missing and could not be installed.

#### See also

* [shell::dependency::ensure](#shelldependencyensure)

