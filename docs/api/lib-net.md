# lib/net.sh

Networking helpers: downloads, URLs, remote scripts, ports, address validation.

## Overview

Download a file over HTTP(S) safely.
Improvements over `shell::download_dataset`:

- `curl -f` makes HTTP 4xx/5xx a failure; previously a "404 Not Found" HTML
  page was saved under the requested filename and reported as success.
- The data is written to a temporary file in the same directory and moved
  into place only after a complete download (no truncated files).
- Connect and total timeouts come from `SHELL_NET_CONNECT_TIMEOUT` / `MAX_TIME`.
- Declining the overwrite prompt now really aborts.

## Index

- [shell::net::download](#shellnetdownload)
- [shell::net::open_url](#shellnetopen_url)
- [shell::net::run_remote_script](#shellnetrun_remote_script)
- [shell::net::port::check](#shellnetportcheck)
- [shell::net::port::kill](#shellnetportkill)
- [shell::validate::ip::address](#shellvalidateipaddress)
- [shell::validate::hostname](#shellvalidatehostname)

### shell::net::download

Download a file over HTTP(S) safely.
Improvements over `shell::download_dataset`:

- `curl -f` makes HTTP 4xx/5xx a failure; previously a "404 Not Found" HTML
  page was saved under the requested filename and reported as success.
- The data is written to a temporary file in the same directory and moved
  into place only after a complete download (no truncated files).
- Connect and total timeouts come from `SHELL_NET_CONNECT_TIMEOUT` / `MAX_TIME`.
- Declining the overwrite prompt now really aborts.

#### Example

```bash
shell::net::download .gitignore "$SHELL_URL_GITIGNORE_GO"
shell::net::download -f data.zip https://example.com/data.zip
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the curl command instead of running it.

- **-f** | **--force**

  Overwrite an existing file without asking.

#### Arguments

- **$1** (string): Destination file (parent directories are created).
- **$2** (string): Source URL.

#### Exit codes

- **0**: Downloaded (or dry-run printed).
- **1**: The transfer failed.
- **2**: Wrong arguments.
- **7**: The file exists and the user declined to overwrite it.

### shell::net::open_url

Open a URL in the default browser.
macOS: `open`. Linux: `xdg-open`. WSL: `wslview` or `explorer.exe`.

#### Example

```bash
shell::net::open_url https://example.com
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **$1** (string): The URL.

#### Exit codes

- **0**: The opener was launched (or dry-run printed).
- **2**: No URL given.
- **3**: No opener is installed.
- **4**: Unsupported operating system.

### shell::net::run_remote_script

Download a script and run it with an interpreter.
Replaces the `sh -c "$(curl ...)"` idiom. If curl fails, `$(...)` expands to
an empty string and `sh -c ""` _succeeds_, so a failed download used to be
reported as a successful install. Here the script is saved first, checked
for being non-empty, then executed.

Environment variables set by the caller (e.g. `RUNZSH=no`) are inherited by
the script. Any arguments after the interpreter are passed to the script
unchanged (argv style, so spaces and quotes survive).

#### Example

```bash
RUNZSH=no shell::net::run_remote_script "$SHELL_URL_OHMYZSH_INSTALL" sh
shell::net::run_remote_script "$url" bash --yes --tool claude
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the equivalent pipeline instead of running it.

#### Arguments

- **$1** (string): Script URL.
- **$2** (string): Interpreter (default: sh).
- **...** (string): Arguments passed to the script (everything after the interpreter).

#### Exit codes

- **0**: The script ran successfully (or dry-run printed).
- **1**: Download failed, the script was empty, or it exited non-zero.
- **2**: No URL given.
- N Exit status of the script when it exits non-zero.

### shell::net::port::check

Show which process is listening on a TCP port.

#### Example

```bash
shell::net::port::check 8080 && echo "8080 is busy"
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the lsof command instead of running it.

#### Arguments

- **$1** (integer): TCP port (1-65535).

#### Exit codes

- **0**: The port is in use.
- **1**: The port is free.
- **2**: Invalid port.

#### Output on stdout

- lsof's listing of the listener(s).

### shell::net::port::kill

Terminate the processes listening on one or more TCP ports.
Sends SIGTERM by default so programs can shut down cleanly; use `-9` to
force. Only LISTENING processes are targeted (the old implementation also
killed _clients_ connected to the port).

#### Example

```bash
shell::net::port::kill 3000 8080
shell::net::port::kill -9 -n 8080
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the kill commands instead of running them.

- **-9** | **--force**

  Send SIGKILL instead of SIGTERM.

#### Arguments

- **...** (integer): One or more ports.

#### Exit codes

- **0**: Done (ports with no listener only produce a warning).
- **1**: A kill failed.
- **2**: No port given or an invalid port.

### shell::validate::ip::address

Validate an IPv4 or IPv6 address.

#### Example

```bash
shell::validate::ip::address 192.168.1.10
shell::validate::ip::address 2001:db8::1
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Arguments

- **$1** (string): The address.

#### Exit codes

- **0**: The address is valid.
- **1**: The address is not valid.
- **2**: No address given.

#### Output on stdout

- "INFO: '<ip>' is a valid IPv4/IPv6 address."

### shell::validate::hostname

Validate a hostname and report whether it resolves.
Syntax is checked against RFC 1123 (labels of 1-63 letters, digits and
hyphens, total length <= 253). Resolution uses whichever of `getent`,
`host` or `nslookup` is available; if none is, only the syntax is checked.

#### Example

```bash
shell::validate::hostname example.com
```

#### Options

- **-h** | **--help**

  Show help and return.

#### Arguments

- **$1** (string): The hostname.

#### Exit codes

- **0**: The hostname is syntactically valid (resolution only warns).
- **1**: The hostname is not valid.
- **2**: No hostname given.

#### Output on stdout

- Validity and resolution status.
