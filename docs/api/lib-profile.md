# lib/profile.sh

Profile management built on the INI store.

## Overview

Returns the path to the profile directory for a given profile name.

Constructs and returns the path to the profile directory within the workspace,
located at $SHELL_CONFIG_DIR/workspace.

## Index

* [shell::profile::path](#shellprofilepath)
* [shell::profile::add](#shellprofileadd)
* [shell::profile::read](#shellprofileread)
* [shell::profile::update](#shellprofileupdate)
* [shell::profile::remove](#shellprofileremove)
* [shell::profile::get](#shellprofileget)
* [shell::profile::rename](#shellprofilerename)
* [shell::profile::conf::add](#shellprofileconfadd)
* [shell::profile::conf::get](#shellprofileconfget)
* [shell::profile::conf::value](#shellprofileconfvalue)
* [shell::profile::conf::remove](#shellprofileconfremove)
* [shell::profile::conf::update](#shellprofileconfupdate)
* [shell::profile::conf::exists](#shellprofileconfexists)
* [shell::profile::conf::rename](#shellprofileconfrename)
* [shell::profile::conf::clone](#shellprofileconfclone)
* [shell::profile::conf::list](#shellprofileconflist)

### shell::profile::path

Returns the path to the profile directory for a given profile name.

Constructs and returns the path to the profile directory within the workspace,
located at $SHELL_CONFIG_DIR/workspace.

#### Example

```bash
profile_dir=$(shell::profile::path "my_profile")  # Returns "$SHELL_CONFIG_DIR/workspace/my_profile"
```

#### Arguments

* **$1** (string): profile_name: The name of the profile.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::profile::add

Creates a new profile directory and initializes it with a profile.conf file.

Ensures the workspace directory exists, then creates a new directory for the specified profile
and initializes it with an empty profile.conf file. If the profile already exists, it prints a warning.

#### Example

```bash
shell::profile::add my_profile         # Creates the profile directory and profile.conf.
shell::profile::add -n my_profile      # Prints the commands without executing them.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): profile_name: The name of the profile to create.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::profile::read

Sources the profile.conf file from the specified profile directory.

Checks if the specified profile exists and sources its profile.conf file to load configurations
into the current shell session. If the profile or file does not exist, it prints an error.

#### Example

```bash
shell::profile::read my_profile         # Sources profile.conf from my_profile.
shell::profile::read -n my_profile      # Prints the sourcing command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): profile_name: The name of the profile to read.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::profile::update

Opens the profile.conf file of the specified profile in the default editor.

Checks if the specified profile exists and opens its profile.conf file in the editor specified
by the EDITOR environment variable (defaults to 'nano' if unset).

#### Example

```bash
shell::profile::update my_profile         # Opens profile.conf in the default editor.
shell::profile::update -n my_profile      # Prints the editor command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): profile_name: The name of the profile to update.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::profile::remove

Deletes the specified profile directory after user confirmation.

Prompts for confirmation before deleting the profile directory and its contents.
If confirmed, removes the directory; otherwise, aborts the operation.

#### Example

```bash
shell::profile::remove my_profile         # Prompts to confirm deletion of my_profile.
shell::profile::remove -n my_profile      # Prints the removal command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): profile_name: The name of the profile to remove.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::profile::get

Displays the contents of the profile.conf file for the specified profile.

Checks if the specified profile exists and displays the contents of its profile.conf file.
If the profile or file does not exist, it prints an error.

#### Example

```bash
shell::profile::get my_profile         # Displays the contents of profile.conf for my_profile.
```

#### Arguments

* **$1** (string): profile_name: The name of the profile to display.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::profile::rename

Renames the specified profile directory.

Checks if the old profile exists and the new profile name does not already exist,
then renames the directory accordingly.

#### Example

```bash
shell::profile::rename old_profile new_profile         # Renames old_profile to new_profile.
shell::profile::rename -n old_profile new_profile      # Prints the rename command without executing it.
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): old_name: The current name of the profile.
* **$2** (string): new_name: The new name for the profile.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::profile::conf::add

Adds a configuration entry (key=value) to the profile.conf file of a specified profile.
The value is encoded using Base64 before being saved.

The function checks for an optional dry-run flag (-n) and ensures that the profile name, key, and value are provided.
It encodes the value using Base64 (with newline characters removed) and appends a line in the format:
key=encoded_value
to the profile.conf file in the specified profile directory. If the profile directory or the profile.conf file does not exist, they are created.

#### Example

```bash
shell::profile::conf::add my_profile my_setting "some secret value"         # Encodes the value and adds the entry to my_profile/profile.conf
shell::profile::conf::add -n my_profile my_setting "some secret value"      # Prints the command without executing it
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.

#### Arguments

* **$1** (string): profile_name: The name of the profile.
* **$2** (string): key: The configuration key.
* **$3** (string): value: The configuration value to be encoded and saved.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::profile::conf::get

Retrieves a configuration profile value by prompting the user to select a config key from the profile's configuration file.

This function locates the profile directory and its configuration file, verifies that the profile exists,
and then ensures that the interactive fuzzy finder (fzf) is installed. It uses fzf to let the user select a configuration key,
decodes its base64-encoded value (using the appropriate flag for macOS or Linux), displays the selected key,
and finally copies the decoded value to the clipboard asynchronously.

#### Example

```bash
shell::profile::conf::get my_profile          # Retrieves and processes the 'my_profile' profile.
shell::profile::conf::get -n my_profile       # Dry-run mode: prints the commands without executing them.
```

#### Arguments

* **$1** (string): profile_name: The name of the configuration profile.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::profile::conf::value

Retrieves a configuration value for a given profile and key by decoding its base64-encoded value.

This function ensures that the workspace exists and locates the profile directory
and configuration file. It then extracts the configuration line matching the provided key,
decodes the associated base64-encoded value (using the appropriate flag for macOS or Linux),
asynchronously copies the decoded value to the clipboard, and finally outputs the decoded value.

#### Example

```bash
shell::profile::conf::value my_profile API_KEY
shell::profile::conf::value -n my_profile API_KEY   # Dry-run: prints commands without executing them.
```

#### Arguments

* **$1** (string): profile_name: The name of the configuration profile.
* **$2** (string): key: The configuration key whose value will be retrieved.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::profile::conf::remove

Removes a configuration key from a given profile's configuration file.

This function locates the profile directory and its configuration file, verifies their existence,
and then uses fzf to let the user select a configuration key to remove.
It builds an OS-specific sed command to delete the line containing the selected key.
In dry-run mode, the command is printed using shell::logger::command_clip; otherwise, it is executed asynchronously
using shell::exec::async with shell::exec::shell.

#### Example

```bash
shell::profile::conf::remove my_profile
shell::profile::conf::remove -n my_profile   # Dry-run: prints the removal command without executing.
```

#### Arguments

* **$1** (string): profile_name: The name of the configuration profile.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::profile::conf::update

Updates a specified configuration key in a given profile by replacing its value.

The function retrieves the profile configuration file, prompts the user to select a key (using fzf),
asks for the new value, encodes it in base64, and constructs a sed command to update the key.
The sed command is executed asynchronously via the shell::exec::async function (unless in dry-run mode).

#### Example

```bash
shell::profile::conf::update my_profile
shell::profile::conf::update -n my_profile   # dry-run mode
```

#### Options

* **-n**

  Optional dry-run flag. If provided, the update command is printed using shell::logger::command_clip without executing.

#### Arguments

* **$1** (string): profile_name: The name of the profile to update.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::profile::conf::exists

Checks whether a specified key exists in the configuration file of a given profile.

The function constructs the path to the profile's configuration file and verifies that the profile directory exists.
It then checks if the configuration file exists. If both exist, it searches for the specified key using grep.
The function outputs "true" if the key is found and "false" otherwise.

#### Example

```bash
shell::profile::conf::exists my_profile my_key
```

#### Arguments

* **$1** (string): profile_name: The name of the profile.
* **$2** (string): key: The configuration key to search for.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::profile::conf::rename

Renames an existing configuration key in a given profile.

The function checks that the profile directory and configuration file exist.
It then uses fzf to allow the user to select the existing key to rename.
After prompting for a new key name and verifying that it does not already exist,
the function constructs an OS-specific sed command to replace the old key with the new one.
In dry-run mode, the command is printed via shell::logger::command_clip; otherwise, it is executed using shell::exec::shell.

#### Example

```bash
shell::profile::conf::rename my_profile
shell::profile::conf::rename -n my_profile   # dry-run mode
```

#### Options

* **-n**

  Optional dry-run flag. If provided, prints the sed command using shell::logger::command_clip without executing.

#### Arguments

* **$1** (string): profile_name: The name of the profile whose key should be renamed.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::profile::conf::clone

Clones a configuration profile by copying its profile.conf from a source profile to a destination profile.

This function retrieves the source and destination profile directories using shell::profile::path,
verifies that the source profile exists and has a profile.conf file, and ensures that the destination
profile does not already exist. If validations pass, it clones the configuration by creating the destination
directory and copying the profile.conf file from the source to the destination. When the dry-run flag (-n)
is provided, it prints the command without executing it.

#### Example

```bash
shell::profile::conf::clone my_profile backup_profile   # Clones profile.conf from 'my_profile' to 'backup_profile'
```

#### Options

* **-n**

  (Optional) Dry-run flag. If provided, the command is printed but not executed.

#### Arguments

* **$1** (string): source_profile: The name of the source profile.
* **$2** (string): destination_profile: The name of the destination profile.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::profile::conf::list

Lists all available configuration profiles in the workspace.

This function checks that the workspace directory ($SHELL_CONFIG_DIR/workspace) exists.
It then finds all subdirectories (each representing a profile) and prints their names.
If no profiles are found, an appropriate message is displayed.

#### Example

```bash
shell::profile::conf::list       # Displays the names of all profiles in the workspace.
```

#### Options

* **-h**

  Optional. Displays this help message.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

