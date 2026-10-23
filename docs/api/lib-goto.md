# lib/goto.sh

`goto` command: bookmark navigation front-end.

## Overview

Print the goto version.

## Index

* [shell::goto::version](#shellgotoversion)
* [shell::goto::usage](#shellgotousage)
* [shell::goto::run](#shellgotorun)

### shell::goto::version

Print the goto version.

_Function has no arguments._

#### Exit codes

* **0**: Always.

#### Output on stdout

* "goto v0.0.1".

### shell::goto::usage

Print the goto command reference.

_Function has no arguments._

#### Exit codes

* **0**: Always.

#### Output on stdout

* The command list.

### shell::goto::run

Navigate and manage directory bookmarks with a single command.
Fixes: `-b` used to be shadowed by the "save" branch so `back | -b` never
ran; `$2` was passed unquoted, which broke names containing spaces.

#### Example

```bash
shell::goto myproject
shell::goto -s myproject
shell::goto back
```

#### Options

* **-s** | **-b**

  Save the current directory as a bookmark (needs a name).

* **-d**

  Delete a bookmark (needs a name).

* **-l** | **--list**

  List bookmarks (`-list` and `-all` are accepted too).

* **-v** | **--version**

  Show the version (`-ver` is accepted too).

* **-h |**

  help Show the command reference.

#### Arguments

* **$1** (string): A bookmark name to jump to, or `back`.

#### Exit codes

* **0**: Success.
* **2**: A command that needs a bookmark name did not get one.

