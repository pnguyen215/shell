# dependency/curl.sh

Ensure `curl` is installed (HTTP client used by downloads, Telegram and GitHub API calls).

## Overview

Make sure `curl` is available, installing it when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (`SHELL_AUTO_INSTALL_DEPS`).

## Index

- [dependency/curl.sh](#dependencycurlsh)
  - [Overview](#overview)
  - [Index](#index)
    - [shell::dependency::curl::ensure](#shelldependencycurlensure)
      - [Example](#example)
      - [Exit codes](#exit-codes)
      - [See also](#see-also)

### shell::dependency::curl::ensure

Make sure `curl` is available, installing it when allowed.
Thin wrapper around shell::dependency::ensure; see that function for the
install policy (`SHELL_AUTO_INSTALL_DEPS`).

#### Example

```bash
shell::dependency::curl::ensure || return
```

_Function has no arguments._

#### Exit codes

- **0**: `curl` is available.
- **3**: `curl` is missing and could not be installed.

#### See also

- [shell::dependency::ensure](#shelldependencyensure)
