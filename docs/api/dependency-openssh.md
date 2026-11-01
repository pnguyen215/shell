# dependency/openssh.sh

Ensure the OpenSSH client (`ssh`, plus `scp`, `sftp`, `ssh-keygen` ...) is installed.

## Overview

Make sure `ssh` is available, installing the OpenSSH client when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (SHELL_AUTO_INSTALL_DEPS). The package is `openssh-client`
(apt), `openssh-clients` (dnf, yum, zypper) or `openssh` (the others).

## Index

- [dependency/openssh.sh](#dependencyopensshsh)
  - [Overview](#overview)
  - [Index](#index)
    - [shell::dependency::openssh::ensure](#shelldependencyopensshensure)
      - [Example](#example)
      - [Exit codes](#exit-codes)
      - [See also](#see-also)

### shell::dependency::openssh::ensure

Make sure `ssh` is available, installing the OpenSSH client when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (SHELL_AUTO_INSTALL_DEPS). The package is `openssh-client`
(apt), `openssh-clients` (dnf, yum, zypper) or `openssh` (the others).

#### Example

```bash
shell::dependency::openssh::ensure || return
```

_Function has no arguments._

#### Exit codes

- **0**: `ssh` is available.
- **3**: `ssh` is missing and could not be installed.

#### See also

- [shell::dependency::ensure](#shelldependencyensure)
