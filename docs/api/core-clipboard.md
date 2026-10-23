# core/clipboard.sh

Cross-platform clipboard access.

## Overview

Tool detection order: `pbcopy` (macOS), `wl-copy` (Wayland), `xclip` and
`xsel` (X11), `clip.exe` (WSL). The previous implementation returned exit
status 1 on *success* and 0 on *failure*; both are now correct.

## Index

* [shell::clipboard::copy](#shellclipboardcopy)
* [shell::clipboard::copy_cwd](#shellclipboardcopy_cwd)

### shell::clipboard::copy

Copy text to the system clipboard.

#### Example

```bash
shell::clipboard::copy "hello"
echo "data" | shell::clipboard::copy "$(cat)"
```

#### Options

* **-h** | **--help**

  Show help and return.

* **-q** | **--quiet**

  Stay silent when no clipboard tool exists (used by dry-run helpers).

* **-b** | **--best-effort**

  Never fail: copying is a convenience, not the purpose of the caller.

#### Arguments

* **$1** (string): Text to copy (copied verbatim, no trailing newline added).

#### Exit codes

* **0**: Text copied.
* **2**: No text was given.
* **3**: No clipboard tool is installed.
* **1**: The clipboard tool failed.

#### Output on stdout

* "✨ Copied (<tool>)" on success (unless --quiet).

### shell::clipboard::copy_cwd

Copy the current working directory to the clipboard.

#### Options

* **-h** | **--help**

  Show help and return.

#### Exit codes

* **0**: Path copied.
* **3**: No clipboard tool is installed.

#### Output on stdout

* "✨ Copied (<tool>)".

#### See also

* [shell::clipboard::copy](#shellclipboardcopy)

