# lib/workspace.sh

Workspace definitions (INI based) with SSH tunnel integration.

## Overview

Ensures that the workspace directory exists.

Checks if the workspace directory ($SHELL_CONFIG_DIR/workspace) exists.
If it does not exist, creates it using mkdir -p.

## Index

* [shell::workspace::ensure](#shellworkspaceensure)
* [shell::workspace::ssh::populate](#shellworkspacesshpopulate)
* [shell::workspace::add](#shellworkspaceadd)
* [shell::workspace::ssh::add](#shellworkspacesshadd)
* [shell::workspace::ssh::add::fzf](#shellworkspacesshaddfzf)
* [shell::workspace::remove](#shellworkspaceremove)
* [shell::workspace::view::fzf](#shellworkspaceviewfzf)
* [shell::workspace::edit::fzf](#shellworkspaceeditfzf)
* [shell::workspace::remove::fzf](#shellworkspaceremovefzf)
* [shell::workspace::rename](#shellworkspacerename)
* [shell::workspace::rename::fzf](#shellworkspacerenamefzf)
* [shell::workspace::manage::fzf](#shellworkspacemanagefzf)
* [shell::workspace::clone](#shellworkspaceclone)
* [shell::workspace::clone::fzf](#shellworkspaceclonefzf)
* [shell::workspace::dump::json](#shellworkspacedumpjson)
* [shell::workspace::ssh::tunnel::open](#shellworkspacesshtunnelopen)
* [shell::workspace::ssh::tunnel::open::fzf](#shellworkspacesshtunnelopenfzf)
* [shell::workspace::ssh::tunnel::tune](#shellworkspacesshtunneltune)
* [shell::workspace::ssh::tunnel::tune::fzf](#shellworkspacesshtunneltunefzf)

### shell::workspace::ensure

Ensures that the workspace directory exists.

Checks if the workspace directory ($SHELL_CONFIG_DIR/workspace) exists.
If it does not exist, creates it using mkdir -p.

#### Example

```bash
shell::workspace::ensure
```

#### Options

* **-h**

  Optional. Displays this help message.

#### Exit codes

* **0**: Success.

### shell::workspace::ssh::populate

Populates a .conf file with default [base], [dev], and [uat] blocks using shell::ini::write.

This function writes default SSH tunnel configuration blocks to the specified .conf file.
It includes a [base] block with shared SSH settings, and [dev] and [uat] blocks with
environment-specific overrides. Additional service-specific keys are added based on the
file name (e.g., kafka.conf, nginx.conf).

The function uses shell::ini::write to write each key-value pair into the appropriate section.
Port numbers are assigned based on a predefined mapping, with +1 offset for UAT.

#### Example

```bash
shell::workspace::ssh::populate "$HOME/.shell-config/workspace/my-app/.ssh/server.conf" "server.conf"
```

#### Arguments

* **$1** (string): file_path: The full path to the .conf file to populate.
* **$2** (string): file_name: The name of the .conf file (e.g., server.conf, kafka.conf).

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::workspace::add

Creates a new workspace with profile.conf and default .ssh/*.conf templates populated via shell::ini::write.

This function creates a new workspace directory under $SHELL_WORKSPACE_DIR/workspace/<workspace_name>,
initializes a profile.conf file and a .ssh/ directory with default SSH config templates (db.conf, redis.conf, etc.).
It uses shell::ini::write to populate each .conf file with [dev] and [uat] blocks.

#### Example

```bash
shell::workspace::add dxc
```

#### Options

* **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): workspace_name: The name of the workspace to create.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::workspace::ssh::add

Adds a missing SSH configuration file to a specified workspace.

This function checks if the specified SSH configuration file exists in the workspace's .ssh directory.
If it does not exist, it creates the file and populates it using shell::workspace::ssh::populate.

#### Example

```bash
shell::workspace::ssh::add my-app kafka.conf
shell::workspace::ssh::add -n my-app kafka.conf
```

#### Options

* **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): workspace_name: The name of the workspace.
* **$2** (string): ssh_conf_name: The name of the SSH configuration file to add (e.g., kafka.conf).

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::workspace::ssh::add::fzf

Interactively selects a workspace and SSH config to add using fzf.

This function uses fzf to select a workspace and a missing SSH configuration file.
It then calls shell::workspace::ssh::add to add the selected file if it does not exist.

#### Example

```bash
shell::workspace::ssh::add::fzf
shell::workspace::ssh::add::fzf -n
```

#### Options

* **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::workspace::remove

Removes a workspace directory after confirmation.

Prompts for confirmation before deleting the workspace directory.

#### Example

```bash
shell::workspace::remove dxc
```

#### Options

* **-n**

  Optional dry-run flag.

#### Arguments

* **$1** (string): workspace_name: The name of the workspace to remove.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::workspace::view::fzf

Interactively selects a .ssh/*.conf file from a workspace and previews it using shell::ini::view::fzf.

This function locates all .conf files under $SHELL_WORKSPACE_DIR/<workspace_name>/.ssh/,
and uses fzf to let the user select one. The selected file is then passed to shell::ini::view::fzf
for real-time preview of all decoded values.

#### Example

```bash
shell::workspace::view::fzf dxc
```

#### Arguments

* **$1** (string): workspace_name: The name of the workspace to view.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::workspace::edit::fzf

Interactively selects a .ssh/*.conf file from a workspace and opens it for editing using shell::ini::edit::fzf.

This function locates all .conf files under $SHELL_WORKSPACE_DIR/<workspace_name>/.ssh/,
and uses fzf to let the user select one. The selected file is then passed to shell::ini::edit::fzf
for editing.

#### Example

```bash
shell::workspace::edit::fzf dxc
```

#### Arguments

* **$1** (string): workspace_name: The name of the workspace to edit.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::workspace::remove::fzf

Interactively selects a workspace using fzf and removes it after confirmation.

This function lists all workspace directories under $SHELL_WORKSPACE_DIR,
uses fzf to let the user select one, and then calls shell::workspace::remove to delete it.

#### Example

```bash
shell::workspace::remove::fzf
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::workspace::rename

Renames a workspace directory from an old name to a new name.

This function renames a workspace directory under $SHELL_WORKSPACE_DIR
from <old_name> to <new_name>. It checks for the existence of the old workspace
and ensures the new name does not already exist. If valid, it renames the directory.

#### Example

```bash
shell::workspace::rename dxc dxc-renamed
shell::workspace::rename -n dxc dxc-renamed
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the rename command is printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): old_name: The current name of the workspace.
* **$2** (string): new_name: The new name for the workspace.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::workspace::rename::fzf

Interactively selects a workspace using fzf and renames it.

This function lists all workspace directories under $SHELL_WORKSPACE_DIR,
uses fzf to let the user select one, prompts for a new name, and then calls shell::workspace::rename
to rename the selected workspace.

#### Example

```bash
shell::workspace::rename::fzf
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the rename command is printed using shell::logger::command_clip instead of executed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::workspace::manage::fzf

Interactively selects a workspace and performs an action (view, edit, rename, remove) using fzf.

This function lists all workspace directories under $SHELL_WORKSPACE_DIR,
uses fzf to let the user select one, then presents a list of actions to perform on the selected workspace.
Supported actions include: view, edit, rename, and remove.

#### Example

```bash
shell::workspace::manage::fzf
```

#### Options

* **-n**

  Optional dry-run flag. If provided, actions that support dry-run will be executed in dry-run mode.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::workspace::clone

Clones an existing workspace to a new workspace directory.

This function clones a workspace directory under $SHELL_WORKSPACE_DIR
from <source_workspace> to <destination_workspace>. It checks for the existence of the source
and ensures the destination does not already exist. If valid, it copies the entire directory.

#### Example

```bash
shell::workspace::clone dxc dxc-clone
shell::workspace::clone -n dxc dxc-clone
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the clone command is printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): source_workspace: The name of the existing workspace to clone.
* **$2** (string): destination_workspace: The name of the new workspace to create.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::workspace::clone::fzf

Interactively selects a workspace using fzf and clones it to a new workspace.

This function lists all workspace directories under $SHELL_WORKSPACE_DIR,
uses fzf to let the user select one, prompts for a new name, and then calls shell::workspace::clone
to clone the selected workspace.

#### Example

```bash
shell::workspace::clone::fzf
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the clone command is printed using shell::logger::command_clip instead of executed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::workspace::dump::json

Interactively selects a workspace, section, and fields to export as JSON from .ssh/*.conf files.

This function uses fzf to let the user select a workspace, then a section (e.g., [dev], [uat]),
and then one or more fields to export. It reads values from .ssh/*.conf files and outputs a JSON
structure to the terminal and copies it to the clipboard.

#### Example

```bash
shell::workspace::dump::json
```

#### Options

* **-h**

  Show help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::workspace::ssh::tunnel::open

Opens an SSH tunnel using configuration from a workspace .ssh/*.conf file.

This function reads the [base] section first, then overrides with values from the specified section.
It delegates the actual SSH tunnel execution to shell::ssh::tunnel::open.

#### Example

```bash
shell::workspace::ssh::tunnel::open my-app kafka.conf dev
shell::workspace::ssh::tunnel::open -n my-app kafka.conf uat
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip.

#### Arguments

* **$1** (string): workspace_name: The name of the workspace.
* **$2** (string): conf_name: The name of the SSH configuration file (e.g., kafka.conf).
* **$3** (string): section: The section to use (e.g., dev, uat).

#### Exit codes

* **0**: Success.

### shell::workspace::ssh::tunnel::open::fzf

Interactively selects a workspace and SSH config section to open an SSH tunnel.

Uses fzf to select a workspace and a .conf file, then selects a section (dev or uat),
and opens an SSH tunnel using shell::workspace::ssh::tunnel::open.

#### Example

```bash
shell::workspace::ssh::tunnel::open::fzf
shell::workspace::ssh::tunnel::open::fzf -n
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip.

#### Exit codes

* **0**: Success.

### shell::workspace::ssh::tunnel::tune

Opens an SSH tunnel using configuration from a workspace .ssh/*.conf file, with tuning options.

This function reads the [base] section first, then overrides with values from the specified section.
It delegates the actual SSH tunnel execution to shell::ssh::tunnel::tune.

#### Example

```bash
shell::workspace::ssh::tunnel::tune my-app kafka.conf dev
shell::workspace::ssh::tunnel::tune -n my-app kafka.conf uat
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip.

#### Arguments

* **$1** (string): workspace_name: The name of the workspace.
* **$2** (string): conf_name: The name of the SSH configuration file (e.g., kafka.conf).
* **$3** (string): section: The section to use (e.g., dev, uat).

#### Exit codes

* **0**: Success.

### shell::workspace::ssh::tunnel::tune::fzf

Interactively selects a workspace and SSH config section to tune an SSH tunnel.

Uses fzf to select a workspace and a .conf file, then selects a section (dev or uat),
and tunes an SSH tunnel using shell::workspace::ssh::tunnel::tune.

#### Example

```bash
shell::workspace::ssh::tunnel::tune::fzf
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip.

#### Exit codes

* **0**: Success.

