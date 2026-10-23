# lib/conf.sh

Encoded key/value configuration store with groups and protected keys.

## Overview

Sources a configuration file, allowing its variables and functions to be loaded into the current shell.

The function checks that a filename is provided and that the specified file exists.
If the file is not found, an error message is displayed.
In dry-run mode, the command "source <filename>" is printed using shell::logger::command_clip.
Otherwise, the file is sourced using shell::exec::command to log the execution.

## Index

* [shell::conf::read](#shellconfread)
* [shell::conf::key::add](#shellconfkeyadd)
* [shell::conf::key::comment](#shellconfkeycomment)
* [shell::conf::key::get::fzf](#shellconfkeygetfzf)
* [shell::conf::key::get](#shellconfkeyget)
* [shell::conf::key::remove::fzf](#shellconfkeyremovefzf)
* [shell::conf::key::update::fzf](#shellconfkeyupdatefzf)
* [shell::conf::key::exists](#shellconfkeyexists)
* [shell::conf::key::rename::fzf](#shellconfkeyrenamefzf)
* [shell::conf::protected::is](#shellconfprotectedis)
* [shell::conf::group::add::fzf](#shellconfgroupaddfzf)
* [shell::conf::group::read](#shellconfgroupread)
* [shell::conf::group::remove::fzf](#shellconfgroupremovefzf)
* [shell::conf::group::update::fzf](#shellconfgroupupdatefzf)
* [shell::conf::group::rename::fzf](#shellconfgrouprenamefzf)
* [shell::conf::group::list](#shellconfgrouplist)
* [shell::conf::group::view::fzf](#shellconfgroupviewfzf)
* [shell::conf::group::clone::fzf](#shellconfgroupclonefzf)
* [shell::conf::group::sync](#shellconfgroupsync)
* [shell::conf::key::view::fzf](#shellconfkeyviewfzf)
* [shell::conf::protected::add](#shellconfprotectedadd)
* [shell::conf::protected::add::fzf](#shellconfprotectedaddfzf)
* [shell::conf::protected::remove::fzf](#shellconfprotectedremovefzf)
* [shell::conf::protected::sync](#shellconfprotectedsync)

### shell::conf::read

Sources a configuration file, allowing its variables and functions to be loaded into the current shell.

The function checks that a filename is provided and that the specified file exists.
If the file is not found, an error message is displayed.
In dry-run mode, the command "source <filename>" is printed using shell::logger::command_clip.
Otherwise, the file is sourced using shell::exec::command to log the execution.

#### Example

```bash
shell::conf::read ~/.my-config                # Sources the configuration file.
shell::conf::read -n ~/.my-config             # Prints the sourcing command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): filename: The configuration file to source.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::key::add

Adds a configuration entry (key=value) to a constant configuration file.
The value is encoded using Base64 before being saved.

The function first checks for an optional dry-run flag (-n) and verifies that both key and value are provided.
It encodes the value using Base64 (with newline characters removed) and then appends a line in the format:
key=encoded_value
to a constant configuration file (defined by SHELL_KEY_FILE). If the configuration file does not exist, it is created.

#### Example

```bash
shell::conf::key::add my_setting "some secret value"         # Encodes the value and adds the entry.
shell::conf::key::add -n my_setting "some secret value"      # Prints the command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): key: The configuration key.
* **$2** (string): value: The configuration value to be encoded and saved.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::key::comment

Adds a configuration entry (key=value) with an optional comment to the constant configuration file.
The value is encoded using Base64 before being saved.

This function encodes the value using Base64 (with newline characters removed) and appends a line in the format:
# comment (if provided)
key=encoded_value
to the configuration file defined by SHELL_KEY_FILE.
If the key already exists, a warning is shown and the function exits.

#### Example

```bash
shell::conf::key::comment my_key "my secret" "This is a comment"
shell::conf::key::comment -n my_key "my secret" "Dry-run with comment"
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): key: The configuration key.
* **$2** (string): value: The configuration value to be encoded and saved.
* **...** (string): comment: Optional comment to be added above the key-value pair.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::key::get::fzf

Interactively selects a configuration key from a constant configuration file using fzf,
then decodes and displays its corresponding value.

The function reads the configuration file defined by the constant SHELL_KEY_FILE,
which is expected to have entries in the format:
key=encoded_value
Instead of listing the entire line, it extracts only the keys (before the '=') and uses fzf
for interactive selection. Once a key is selected, it looks up the full entry,
decodes the Base64-encoded value (using -D on macOS and -d on Linux), and then displays the key
and its decoded value.

#### Example

```bash
shell::conf::key::get::fzf      # Interactively select a key and display its decoded value.
```

#### Options

* **-h**

  Optional. Displays this help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::key::get

Retrieves and outputs the decoded value for a given configuration key from the key configuration file.

This function searches for the specified key in the configuration file defined by SHELL_KEY_FILE.
The configuration file is expected to have entries in the format:
key=encoded_value
If the key is found, the function decodes the associated Base64‑encoded value (using -D on macOS and -d on Linux)
and outputs the decoded value to standard output.

#### Example

```bash
shell::conf::key::get my_setting   # Outputs the decoded value for the key 'my_setting'.
```

#### Arguments

* **$1** (string): key: The configuration key whose value should be retrieved.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::key::remove::fzf

Interactively selects a configuration key from a constant configuration file using fzf,
then removes the corresponding entry from the configuration file.

The function reads the configuration file defined by the constant SHELL_KEY_FILE, where each entry is in the format:
key=encoded_value
It extracts only the keys (before the '=') and uses fzf for interactive selection.
Once a key is selected, it constructs a command to remove the line that starts with "key=" from the configuration file.
The command uses sed with different options depending on the operating system (macOS or Linux).
In dry-run mode, the command is printed using shell::logger::command_clip; otherwise, it is executed using shell::exec::shell.

#### Example

```bash
shell::conf::key::remove::fzf         # Interactively select a key and remove its configuration entry.
shell::conf::key::remove::fzf -n      # Prints the removal command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::key::update::fzf

Interactively updates the value for a configuration key in a constant configuration file.
The new value is encoded using Base64 before updating the file.

The function reads the configuration file defined by SHELL_KEY_FILE, which contains entries in the format:
key=encoded_value
It extracts only the keys and uses fzf to allow interactive selection.
Once a key is selected, the function prompts for a new value, encodes it using Base64 (with newlines removed),
and then updates the corresponding configuration entry in the file by replacing the line starting with "key=".
The sed command used for in-place update differs between macOS and Linux.

#### Example

```bash
shell::conf::key::update::fzf       # Interactively select a key, enter a new value, and update its entry.
shell::conf::key::update::fzf -n    # Prints the update command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the update command is printed using shell::logger::command_clip instead of executed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::key::exists

Checks if a configuration key exists in the key configuration file.

This function searches for the specified key in the configuration file defined by SHELL_KEY_FILE.
The configuration file should have entries in the format:
key=encoded_value
If a line starting with "key=" is found, the function echoes "true" and returns 0.
Otherwise, it echoes "false" and returns 1.

Sample Usage:
# Using the exit status:
if shell::conf::key::exists my_setting; then
echo "Key 'my_setting' exists."
else
echo "Key 'my_setting' does not exist."
fi

# Capturing the output:
result=$(shell::conf::key::exists my_setting)
if [ "$result" = "true" ]; then
echo "Key 'my_setting' exists."
else
echo "Key 'my_setting' does not exist."
fi

#### Example

```bash
shell::conf::key::exists my_setting   # Echoes "true" and returns 0 if 'my_setting' exists; otherwise, echoes "false" and returns 1.
```

#### Arguments

* **$1** (string): key: The configuration key to check.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::key::rename::fzf

Renames an existing configuration key in the key configuration file.

The function reads the configuration file defined by SHELL_KEY_FILE, which stores entries in the format:
key=encoded_value
It uses fzf to interactively select an existing key.
After selection, the function prompts for a new key name and checks if the new key already exists.
If the new key does not exist, it constructs a sed command to replace the old key with the new key in the file.
The sed command uses in-place editing options appropriate for macOS (sed -i '') or Linux (sed -i).
In dry-run mode, the command is printed via shell::logger::command_clip; otherwise, it is executed using shell::exec::shell.

#### Example

```bash
shell::conf::key::rename::fzf         # Interactively select a key and rename it.
shell::conf::key::rename::fzf -n      # Prints the renaming command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the renaming command is printed using shell::logger::command_clip instead of executed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::protected::is

Checks if the specified configuration key is protected.

This function iterates over the SHELL_PROTECTED_KEYS array to determine if the given key is marked as protected.
If the key is found in the array, the function echoes "true" and returns 0.
Otherwise, it echoes "false" and returns 1.

#### Example

```bash
if shell::conf::protected::is "HOST"; then
shell::console::print "ERR: 'HOST' is a protected key and cannot be modified." 196
return 1
fi
```

#### Arguments

* **$1** (string): key: The configuration key to check.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::group::add::fzf

Groups selected configuration keys under a specified group name.

This function prompts you to enter a group name, then uses fzf (with multi-select) to let you choose
one or more configuration keys (from SHELL_KEY_FILE). It then stores the group in SHELL_KEY_GROUP_FILE in the format:
group_name=key1,key2,...,keyN
If the group name already exists, the group entry is updated with the new selection.
An optional dry-run flag (-n) can be used to print the command via shell::logger::command_clip instead of executing it.

#### Example

```bash
shell::conf::group::add::fzf         # Prompts for a group name and lets you select keys to group.
shell::conf::group::add::fzf -n      # Prints the command for creating/updating the group without executing it.
```

#### Options

* **-h**

  Optional. Displays this help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::group::read

Reads and displays the configurations for a given group by group name.

This function looks up the group entry in SHELL_KEY_GROUP_FILE for the specified group name.
The group entry is expected to be in the format:
group_name=key1,key2,...,keyN
For each key in the group, the function retrieves the corresponding configuration entry from SHELL_KEY_FILE,
decodes the Base64-encoded value (using -D on macOS and -d on Linux), and groups the key-value pairs
into a JSON object which is displayed.

#### Example

```bash
shell::conf::group::read my_group   # Displays the configurations for the keys in the group 'my_group'.
```

#### Options

* **-h**

  Optional. Displays this help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::group::remove::fzf

Interactively selects a group name from the group configuration file using fzf,
then removes the corresponding group entry.

The function extracts group names from SHELL_KEY_GROUP_FILE and uses fzf for interactive selection.
Once a group is selected, it constructs a sed command (with appropriate in-place options for macOS or Linux)
to remove the line that starts with "group_name=".
If the file is not writable, sudo is prepended. In dry-run mode, the command is printed via shell::logger::command_clip.

#### Example

```bash
shell::conf::group::remove::fzf         # Interactively select a group and remove its entry.
shell::conf::group::remove::fzf -n      # Prints the removal command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::group::update::fzf

Interactively updates an existing group by letting you select new keys for that group.

The function reads SHELL_KEY_GROUP_FILE and uses fzf to let you select an existing group.
It then presents all available keys from SHELL_KEY_FILE (via fzf with multi-select) for you to choose the new group membership.
The selected keys are converted into a comma-separated list, and the group entry is updated in SHELL_KEY_GROUP_FILE
(using sed with options appropriate for macOS or Linux). If the file is not writable, sudo is used.

#### Example

```bash
shell::conf::group::update::fzf         # Interactively select a group, update its keys, and update the group entry.
shell::conf::group::update::fzf -n      # Prints the update command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the update command is printed using shell::logger::command_clip instead of executed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::group::rename::fzf

Renames an existing group in the group configuration file.

The function reads the group configuration file (SHELL_KEY_GROUP_FILE) where each line is in the format:
group_name=key1,key2,...,keyN
It uses fzf to let you select an existing group to rename.
After selection, the function prompts for a new group name.
It then constructs a sed command to replace the old group name with the new one in the configuration file.
The sed command uses in-place editing options appropriate for macOS (sed -i '') or Linux (sed -i).
In dry-run mode, the command is printed using shell::logger::command_clip; otherwise, it is executed using shell::exec::shell.

#### Example

```bash
shell::conf::group::rename::fzf         # Interactively select a group and rename it.
shell::conf::group::rename::fzf -n      # Prints the renaming command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the renaming command is printed using shell::logger::command_clip instead of executed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::group::list

Lists all group names defined in the group configuration file.

This function reads the configuration file defined by SHELL_KEY_GROUP_FILE,
where each line is in the format:
group_name=key1,key2,...,keyN
It extracts and displays the group names (the part before the '=')
using the 'cut' command.

#### Example

```bash
shell::conf::group::list       # Displays all group names.
```

#### Options

* **-h**

  Optional. Displays this help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::group::view::fzf

Interactively selects a group name from the group configuration file using fzf,
then lists all keys belonging to the selected group and uses fzf to choose one key,
finally displaying the decoded value for the selected key.

The function reads the configuration file defined by SHELL_KEY_GROUP_FILE, where each line is in the format:
group_name=key1,key2,...,keyN
It first uses fzf to allow interactive selection of a group name.
Once a group is selected, the function extracts the comma-separated list of keys,
converts them into a list (one per line), and uses fzf again to let you choose one key.
It then retrieves the corresponding configuration entry from SHELL_KEY_FILE (which stores entries as key=encoded_value),
decodes the Base64-encoded value (using -D on macOS and -d on Linux), and displays the group name, key, and decoded value.

#### Example

```bash
shell::conf::group::view::fzf   # Prompts to select a group, then a key within that group, and displays the decoded value.
```

#### Options

* **-h**

  Optional. Displays this help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::group::clone::fzf

Clones an existing group by creating a new group with the same keys.

The function reads the group configuration file (SHELL_KEY_GROUP_FILE) where each line is in the format:
group_name=key1,key2,...,keyN
It uses fzf to interactively select an existing group.
After selection, it prompts for a new group name.
The new group entry is then constructed with the new group name and the same comma-separated keys
as the selected group, and appended to SHELL_KEY_GROUP_FILE.
In dry-run mode, the final command is printed using shell::logger::command_clip; otherwise, it is executed using shell::exec::shell.

#### Example

```bash
shell::conf::group::clone::fzf         # Interactively select a group and create a clone with a new group name.
shell::conf::group::clone::fzf -n      # Prints the cloning command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the cloning command is printed using shell::logger::command_clip instead of executed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::group::sync

Synchronizes group configurations by ensuring that each group's keys exist in the key configuration file.
If a key listed in a group does not exist, it is removed from that group.
If a group ends up with no valid keys, that group entry is removed.

The function reads each group entry from SHELL_KEY_GROUP_FILE (entries in the format: group_name=key1,key2,...,keyN).
For each group, it splits the comma‑separated list of keys and checks each key using shell::conf::key::exists.
It builds a new list of valid keys. If the new list is non‑empty, the group entry is updated;
if it is empty, the group entry is omitted.
In dry‑run mode, the new group configuration is printed via shell::logger::command_clip without modifying the file.

#### Example

```bash
shell::conf::group::sync         # Synchronizes the group configuration file.
shell::conf::group::sync -n      # Displays the updated group configuration without modifying the file.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the new group configuration is printed using shell::logger::command_clip instead of being applied.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::key::view::fzf

Interactively selects a configuration key using fzf and displays its decoded value in real-time.

This function checks if the configuration file exists. If not, it displays an error.
It then uses fzf to interactively select a configuration key from the file, showing
the Base64-decoded value in real-time in a preview window, formatted as "key (value)"
with the key in yellow and the value in cyan. Once a key is selected, its decoded value
is copied to the clipboard unless in dry-run mode, where the copy command is printed.

Notes:
- Compatible with both macOS and Linux.
- Uses ANSI color codes for formatting (yellow for key, cyan for value).
- The configuration file is expected to contain key=value pairs with Base64-encoded values.

#### Example

```bash
shell::conf::key::view::fzf         # Select a key and copy its decoded value.
shell::conf::key::view::fzf -n      # Dry-run: print the clipboard copy command.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the clipboard copy command is printed instead of executed.

* **-h**

  Optional help flag. Displays this help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::protected::add

Adds a key to the protected key list stored in protected.conf.

This function appends a key to the protected.conf file located at $SHELL_CONFIG_DIR/protected.conf.
If the key already exists in the file, it will not be added again.

#### Example

```bash
shell::conf::protected::add
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): key: The key to mark as protected.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::protected::add::fzf

Interactively selects a key from the configuration file and adds it to the protected list.

This function uses fzf to select a key from the configuration file (excluding comments),
and adds it to the protected.conf file.

#### Example

```bash
shell::conf::protected::add::fzf
```

#### Options

* **-n**

  Optional. Dry-run mode. Prints the command without executing it.

* **-h**

  Optional. Displays this help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::protected::remove::fzf

Interactively selects a protected key using fzf and removes it from protected.conf.

This function reads the protected.conf file, uses fzf to let the user select a key,
and removes the selected key using sed. In dry-run mode, the command is printed instead of executed.

#### Example

```bash
shell::conf::protected::remove::fzf
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::conf::protected::sync

Synchronizes the protected.conf file by removing keys that no longer exist in key.conf.

This function compares the keys listed in protected.conf with those in key.conf.
Any protected key that is not found in key.conf will be removed.
In dry-run mode, the updated list is printed instead of being written to the file.

#### Example

```bash
shell::conf::protected::sync
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the updated protected.conf is printed using shell::logger::command_clip instead of being applied.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

