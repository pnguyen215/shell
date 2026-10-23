# dependency/clipboard.sh

Ensure a clipboard tool is installed (macOS has pbcopy built in).

## Overview

Make sure a clipboard tool is available.
macOS ships `pbcopy`. On Linux, `wl-copy` (wl-clipboard) is installed under
Wayland and `xclip` otherwise.

## Index

- [dependency/clipboard.sh](#dependencyclipboardsh)
  - [Overview](#overview)
  - [Index](#index)
    - [shell::dependency::clipboard::ensure](#shelldependencyclipboardensure)
      - [Exit codes](#exit-codes)
      - [See also](#see-also)

### shell::dependency::clipboard::ensure

Make sure a clipboard tool is available.
macOS ships `pbcopy`. On Linux, `wl-copy` (wl-clipboard) is installed under
Wayland and `xclip` otherwise.

_Function has no arguments._

#### Exit codes

- **0**: A clipboard tool is available.
- **3**: No tool is available and none could be installed.

#### See also

- [shell::clipboard::copy](#shellclipboardcopy)
