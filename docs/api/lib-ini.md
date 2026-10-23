# lib/ini.sh

INI file parser/editor with interactive viewers.

## Overview

Reads the value of a specified key from a given section in an INI file.

This function reads an INI file and retrieves the value associated with a
specified key within a given section. It validates the presence of the file,
section, and key, and applies strict validation rules if `SHELL_INI_STRICT` is set.
The function handles comments, empty lines, and quoted values within the INI file.

Notes:

- Relies on the shell::console::print function for output.
- The behavior is controlled by the `SHELL_INI_STRICT` environment variable.

## Index

- [lib/ini.sh](#libinish)
  - [Overview](#overview)
  - [Index](#index)
    - [shell::ini::read](#shelliniread)
      - [Example](#example)
      - [Arguments](#arguments)
      - [Exit codes](#exit-codes)
    - [shell::ini::validate::section](#shellinivalidatesection)
      - [Example](#example-1)
      - [Arguments](#arguments-1)
      - [Exit codes](#exit-codes-1)
    - [shell::ini::validate::key](#shellinivalidatekey)
      - [Example](#example-2)
      - [Options](#options)
      - [Arguments](#arguments-2)
      - [Exit codes](#exit-codes-2)
    - [shell::ini::temp_file](#shellinitemp_file)
      - [Example](#example-3)
      - [Exit codes](#exit-codes-3)
    - [shell::ini::trim](#shellinitrim)
      - [Example](#example-4)
      - [Arguments](#arguments-3)
      - [Exit codes](#exit-codes-4)
    - [shell::ini::escape_regex](#shelliniescape_regex)
      - [Example](#example-5)
      - [Arguments](#arguments-4)
      - [Exit codes](#exit-codes-5)
    - [shell::ini::check](#shellinicheck)
      - [Example](#example-6)
      - [Arguments](#arguments-5)
      - [Exit codes](#exit-codes-6)
    - [shell::ini::section::list](#shellinisectionlist)
      - [Example](#example-7)
      - [Options](#options-1)
      - [Arguments](#arguments-6)
      - [Exit codes](#exit-codes-7)
    - [shell::ini::key::list](#shellinikeylist)
      - [Example](#example-8)
      - [Options](#options-2)
      - [Arguments](#arguments-7)
      - [Exit codes](#exit-codes-8)
    - [shell::ini::section::exists](#shellinisectionexists)
      - [Example](#example-9)
      - [Options](#options-3)
      - [Arguments](#arguments-8)
      - [Exit codes](#exit-codes-9)
    - [shell::ini::section::add](#shellinisectionadd)
      - [Example](#example-10)
      - [Options](#options-4)
      - [Arguments](#arguments-9)
      - [Exit codes](#exit-codes-10)
    - [shell::ini::write](#shelliniwrite)
      - [Example](#example-11)
      - [Options](#options-5)
      - [Arguments](#arguments-10)
      - [Exit codes](#exit-codes-11)
    - [shell::ini::section::remove](#shellinisectionremove)
      - [Example](#example-12)
      - [Arguments](#arguments-11)
      - [Exit codes](#exit-codes-12)
    - [shell::ini::key::remove::fzf](#shellinikeyremovefzf)
      - [Example](#example-13)
      - [Options](#options-6)
      - [Arguments](#arguments-12)
      - [Exit codes](#exit-codes-13)
    - [shell::ini::key::remove](#shellinikeyremove)
      - [Example](#example-14)
      - [Options](#options-7)
      - [Arguments](#arguments-13)
      - [Exit codes](#exit-codes-14)
    - [shell::ini::array::set](#shelliniarrayset)
      - [Example](#example-15)
      - [Options](#options-8)
      - [Arguments](#arguments-14)
      - [Exit codes](#exit-codes-15)
    - [shell::ini::array::get](#shelliniarrayget)
      - [Example](#example-16)
      - [Options](#options-9)
      - [Arguments](#arguments-15)
      - [Exit codes](#exit-codes-16)
    - [shell::ini::key::exists](#shellinikeyexists)
      - [Example](#example-17)
      - [Options](#options-10)
      - [Arguments](#arguments-16)
      - [Exit codes](#exit-codes-17)
    - [shell::ini::env::expose](#shellinienvexpose)
      - [Example](#example-18)
      - [Options](#options-11)
      - [Arguments](#arguments-17)
      - [Exit codes](#exit-codes-18)
    - [shell::ini::env::destroy](#shellinienvdestroy)
      - [Example](#example-19)
      - [Options](#options-12)
      - [Arguments](#arguments-18)
      - [Exit codes](#exit-codes-19)
    - [shell::ini::value::get_or_default](#shellinivalueget_or_default)
      - [Example](#example-20)
      - [Options](#options-13)
      - [Arguments](#arguments-19)
      - [Exit codes](#exit-codes-20)
    - [shell::ini::section::rename](#shellinisectionrename)
      - [Example](#example-21)
      - [Options](#options-14)
      - [Arguments](#arguments-20)
      - [Exit codes](#exit-codes-21)
    - [shell::ini::section::rename::fzf](#shellinisectionrenamefzf)
      - [Example](#example-22)
      - [Options](#options-15)
      - [Arguments](#arguments-21)
      - [Exit codes](#exit-codes-22)
    - [shell::ini::section::clone](#shellinisectionclone)
      - [Example](#example-23)
      - [Options](#options-16)
      - [Arguments](#arguments-22)
      - [Exit codes](#exit-codes-23)
    - [shell::ini::section::clone::fzf](#shellinisectionclonefzf)
      - [Example](#example-24)
      - [Options](#options-17)
      - [Arguments](#arguments-23)
      - [Exit codes](#exit-codes-24)
    - [shell::ini::section::remove::fzf](#shellinisectionremovefzf)
      - [Example](#example-25)
      - [Options](#options-18)
      - [Arguments](#arguments-24)
      - [Exit codes](#exit-codes-25)
    - [shell::ini::view::fzf](#shelliniviewfzf)
      - [Example](#example-26)
      - [Arguments](#arguments-25)
      - [Exit codes](#exit-codes-26)
    - [shell::ini::view::super::fzf](#shelliniviewsuperfzf)
      - [Example](#example-27)
      - [Options](#options-19)
      - [Arguments](#arguments-26)
      - [Exit codes](#exit-codes-27)
    - [shell::ini::view::control::fzf](#shelliniviewcontrolfzf)
      - [Example](#example-28)
      - [Options](#options-20)
      - [Arguments](#arguments-27)
      - [Exit codes](#exit-codes-28)
    - [shell::ini::edit::fzf](#shellinieditfzf)
      - [Example](#example-29)
      - [Arguments](#arguments-28)
      - [Exit codes](#exit-codes-29)
    - [shell::ini::dump::json](#shellinidumpjson)
      - [Example](#example-30)
      - [Arguments](#arguments-29)
      - [Exit codes](#exit-codes-30)

### shell::ini::read

Reads the value of a specified key from a given section in an INI file.

This function reads an INI file and retrieves the value associated with a
specified key within a given section. It validates the presence of the file,
section, and key, and applies strict validation rules if `SHELL_INI_STRICT` is set.
The function handles comments, empty lines, and quoted values within the INI file.

Notes:

- Relies on the shell::console::print function for output.
- The behavior is controlled by the `SHELL_INI_STRICT` environment variable.

#### Example

```bash
shell::ini::read config.ini MySection MyKey  # Retrieves the value of MyKey in MySection.
```

#### Arguments

- **$1** (string): file: The path to the INI file.
- **$2** (string): section: The section within the INI file to search.
- **$3** (string): key: The key within the section whose value is to be retrieved.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::validate::section

Validates an INI section name based on defined strictness levels.
It checks for empty names and disallowed characters or spaces according to
`SHELL_INI_STRICT` and `SHELL_INI_ALLOW_SPACES_IN_NAMES` variables.

This function takes a section name as input and applies validation rules.
An empty section name is always considered invalid.
If `SHELL_INI_STRICT` is set to 1, the function checks for the presence of
illegal characters: square brackets (`[` and `]`) and the equals sign (`=`).
If `SHELL_INI_ALLOW_SPACES_IN_NAMES` is set to 0, the function checks for
the presence of spaces within the section name.
Error messages are displayed using the shell::console::print function.

Notes:

- Relies on the shell::console::print function for output.
- The behavior is controlled by the `SHELL_INI_STRICT` and
  `SHELL_INI_ALLOW_SPACES_IN_NAMES` environment variables or constants.

#### Example

```bash
# Assuming SHELL_INI_STRICT=1 and SHELL_INI_ALLOW_SPACES_IN_NAMES=0
shell::ini::validate::section "MySection"   # Valid
shell::ini::validate::section "My Section"  # Invalid (contains space)
shell::ini::validate::section "My[Section]" # Invalid (contains illegal character)
shell::ini::validate::section ""            # Invalid (empty)
```

#### Arguments

- **$1** (string): section_name: The name of the INI section to validate.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::validate::key

Validates an INI key name based on defined strictness levels.

Notes:

- Relies on the shell::console::print function for output.
- The behavior is controlled by the `SHELL_INI_STRICT` and
  `SHELL_INI_ALLOW_SPACES_IN_NAMES` environment variables or constants.

#### Example

```bash
shell::ini::validate::key
```

#### Options

- **-h**

  Optional. Displays this help message.

#### Arguments

- **$1** (string): key_name: The name of the INI key to validate.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::temp_file

Creates a temporary file with a unique name in the system's temporary directory.

This function generates a temporary file using the mktemp command.
The file is created in the directory specified by the TMPDIR environment variable,
or in /tmp if TMPDIR is not set. The filename is prefixed with 'shell*ini*' and
followed by a series of random characters to ensure uniqueness.

#### Example

```bash
temp_file=$(shell::ini::temp_file)  # Creates a temporary file and stores its path in temp_file.
```

_Function has no arguments._

#### Exit codes

- **0**: Success.

### shell::ini::trim

Trims leading and trailing whitespace from a given string.

This function takes a string as input and removes any leading and trailing
whitespace characters. It uses parameter expansion to efficiently trim
the whitespace and then outputs the cleaned string.

#### Example

```bash
trimmed_string=$(shell::ini::trim "  example string  ")  # Outputs "example string"
```

#### Arguments

- **$1** (string): string: The string from which to remove leading and trailing whitespace.

#### Exit codes

- **0**: Success.

### shell::ini::escape_regex

Escapes special characters in a string for regex matching.

This function takes a string as input and escapes special characters
that are used in regular expressions. It uses the sed command to
prepend a backslash to each special character, ensuring the string
can be safely used in regex operations.

#### Example

```bash
escaped_string=$(shell::ini::escape_regex "example(string)")  # Outputs "example\(string\)"
```

#### Arguments

- **$1** (string): string: The string in which to escape special regex characters.

#### Exit codes

- **0**: Success.

### shell::ini::check

Validates the existence and write ability of a specified file, creating it if necessary.

This function checks if a specified file exists and is writable. If the file does not exist,
it attempts to create the file and its parent directory if necessary. It ensures the file
is writable before returning success. If any step fails, it outputs an error message and
returns a non-zero status.

#### Example

```bash
shell::ini::check /path/to/config.ini  # Checks or creates the file at the specified path.
```

#### Arguments

- **$1** (string): file: The path to the file to check or create.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::section::list

Lists all section names from a given INI file.

This function reads an INI file and extracts all section names.
It validates the presence of the file and outputs the section names
without the enclosing square brackets.

Notes:

- Relies on the shell::console::print function for output.

#### Example

```bash
shell::ini::section::list config.ini  # Lists all sections in config.ini.
```

#### Options

- **-h**

  Optional. Displays this help message.

#### Arguments

- **$1** (string): file: The path to the INI file.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::key::list

Lists all key names from a specified section in a given INI file.

This function reads an INI file and extracts all key names from a specified section.
It validates the presence of the file and section, and applies strict validation rules
if `SHELL_INI_STRICT` is set. The function handles comments and empty lines within the INI file.

Notes:

- Relies on the shell::console::print function for output.

#### Example

```bash
shell::ini::key::list config.ini MySection  # Lists all keys in MySection.
```

#### Options

- **-h**

  Optional. Displays this help message.

#### Arguments

- **$1** (string): file: The path to the INI file.
- **$2** (string): section: The section within the INI file to search for keys.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::section::exists

Checks if a specified section exists in a given INI file.

This function checks whether a specified section exists in an INI file.
It validates the presence of the file and section, and applies strict
validation rules if `SHELL_INI_STRICT` is set. The function uses regex
to search for the section header within the file.

#### Example

```bash
shell::ini::section::exists config.ini MySection  # Checks if MySection exists in config.ini.
```

#### Options

- **-h**

  Optional. Displays this help message.

#### Arguments

- **$1** (string): file: The path to the INI file.
- **$2** (string): section: The section within the INI file to check for existence.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::section::add

Adds a new section to a specified INI file if it does not already exist.

This function checks if a specified section exists in an INI file and adds it if not.
It validates the presence of the file and section, and applies strict validation rules
if `SHELL_INI_STRICT` is set. The function handles the creation of the file if it does not exist.

#### Example

```bash
shell::ini::section::add config.ini NewSection  # Adds NewSection to config.ini if it doesn't exist.
```

#### Options

- **-h**

  Optional. Displays this help message.

#### Arguments

- **$1** (string): file: The path to the INI file.
- **$2** (string): section: The section to be added to the INI file.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::write

Writes a key-value pair to a specified section in an INI file.

This function writes a key-value pair to a specified section in an INI file.
It validates the presence of the file, section, and key, and applies strict
validation rules if `SHELL_INI_STRICT` is set. The function handles the creation
of the file and section if they do not exist. It also manages special characters
in values by quoting them if necessary.

#### Example

```bash
shell::ini::write config.ini MySection MyKey MyValue  # Writes MyKey=MyValue in MySection.
```

#### Options

- **-h**

  Optional. Displays this help message.

#### Arguments

- **$1** (string): file: The path to the INI file.
- **$2** (string): section: The section within the INI file to write the key-value pair.
- **$3** (string): key: The key to be written in the specified section.
- **$4** (string): value: The value associated with the key.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::section::remove

Removes a specified section and its key-value pairs from an INI formatted file.

This function processes an INI file line by line. It identifies the start of the
section to be removed and skips all subsequent lines until another section
header is encountered or the end of the file is reached. The remaining lines
(before the target section and after it) are written to a temporary file,
which then replaces the original file.

Notes:

- Assumes the INI file has sections enclosed in square brackets (e.g., [section]).
- Empty lines and lines outside of sections are preserved.
- Relies on helper functions like shell::console::print, shell::ini::escape_regex,
  shell::ini::temp_file, and optionally shell::ini::validate::section
  if SHELL_INI_STRICT is enabled. (Note: shell::ini::escape_regex and
  shell::ini::temp_file are not provided in this snippet, but are assumed
  to exist based on usage.)
- Uses atomic operation (mv) to replace the original file, reducing risk of data loss.

#### Example

```bash
shell::ini::section::remove /path/to/config.ini "database"
```

#### Arguments

- **$1** (string): file: The path to the INI file.
- **$2** (string): section: The name of the section to remove (without the square brackets).

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::key::remove::fzf

Interactively selects a key from a specific section in an INI file using fzf
and then removes the selected key from that section.

This function validates the input file and section, lists keys within the section
using shell::ini::key::list, presents the keys for interactive selection using fzf,
and then removes the chosen key-value pair from the specified section in the INI file.
It handles cases where the file or section does not exist and provides feedback
using shell::console::print.

#### Example

```bash
shell::ini::key::remove::fzf config.ini "Database"  # Interactively remove a key from the Database section.
shell::ini::key::remove::fzf -n settings.ini "API"  # Dry-run: show commands to remove a key from the API section.
```

#### Options

- **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

#### Arguments

- **$1** (string): file: The path to the INI file.
- **$2** (string): section: The section within the INI file from which to remove a key.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::key::remove

Removes a specified key from a specific section in an INI formatted file.

This function processes an INI file line by line. It identifies the start of the
target section and then skips the line containing the specified key within that section.
All other lines (before the target section, in the target section but not matching the key,
and after the target section) are written to a temporary file, which then replaces
the original file.

Notes:

- Assumes the INI file has sections enclosed in square brackets (e.g., [section]) and key=value pairs.
- Empty lines and lines outside of sections are preserved.
- Relies on helper functions like shell::console::print, shell::ini::escape_regex,
  shell::ini::temp_file, and optionally shell::ini::validate::section,
  shell::ini::validate::key if SHELL_INI_STRICT is enabled.
- Uses atomic operation (mv) to replace the original file, reducing risk of data loss.

#### Example

```bash
shell::ini::key::remove /path/to/config.ini "database" "username"
shell::ini::key::remove -n /path/to/config.ini "api" "api_key" # Dry-run mode
```

#### Options

- **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

#### Arguments

- **$1** (string): file: The path to the INI file.
- **$2** (string): section: The section within the INI file from which to remove the key.
- **$3** (string): key: The key to be removed from the specified section.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::array::set

Writes an array of values to a specified key in an INI file.

This function processes a list of values, formats them into a comma-separated
string, and writes this string as the value for a specified key in an INI file.
Values containing spaces, commas, or double quotes are automatically enclosed
in double quotes, and internal double quotes are escaped (e.g., "value with \"quote\"").
The final formatted string is passed to 'shell::ini::write' for atomic writing,
which handles file and section existence, creation, and updates.

Notes:

- Relies on 'shell::console::print' for output and 'shell::ini::write' for file operations.
- Interaction with `SHELL_INI_STRICT` in 'shell::ini::write': If `SHELL_INI_STRICT` is set
  to 1, 'shell::ini::write' might re-quote the entire array string generated by this
  function if it contains spaces or quotes, potentially leading to double-quoting
  (e.g., value becoming ""item1\",\"item 2""). This function aims to produce a
  standard, internally-quoted INI array value.

#### Example

```bash
shell::ini::array::set config.ini MySection MyList "alpha" "beta gamma" "delta,epsilon"
# This would result in MyList=alpha,"beta gamma","delta,epsilon" in config.ini
```

#### Options

- **-h**

  Optional. Displays this help message.

#### Arguments

- **$1** (string): file: The path to the INI file.
- **$2** (string): section: The section within the INI file to write the array to.
- **$3** (string): key: The key to be associated with the array of values.
- **...** (string): valueN: Optional. One or more values to be written as part of the array.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::array::get

Reads and parses an array of values from a specified key in an INI file.

This function first reads the raw string value of a specified key from an INI file
using 'shell::ini::read'. It then meticulously parses this string to extract
individual array elements. The parsing logic correctly handles comma delimiters
and preserves values enclosed in double quotes, including those containing
spaces, commas, or escaped double quotes within the value itself.
Each extracted item is then trimmed of leading/trailing whitespace.
The function outputs each parsed array item on a new line to standard output.

Notes:

- Relies on 'shell::ini::read' to retrieve the raw value.
- Relies on 'shell::ini::trim' for whitespace removal from individual items.
- The parsing logic is custom-built to handle INI-style quoted comma-separated lists.
- Interaction with `SHELL_INI_STRICT` in 'shell::ini::write': Values formatted by
  'shell::ini::array::set' (which are read by this function) are intended to be
  interpreted as single strings by 'shell::ini::write'. If '`SHELL_INI_STRICT`' is 1
  during writing, the entire formatted string might be re-quoted. This function correctly
  parses values regardless of outer re-quoting, as it targets the internal array structure.

#### Example

```bash
# Assuming 'my_config.ini' contains:
# [Settings]
# MyArray=item1,\"item with spaces\",\"item,with,commas\",\"item with \\\"escaped\\\" quotes\"
shell::ini::array::get my_config.ini Settings MyArray
# Expected output:
# item1
# item with spaces
# item,with,commas
# item with "escaped" quotes
```

#### Options

- **-h**

  Optional. Displays this help message.

#### Arguments

- **$1** (string): file: The path to the INI file.
- **$2** (string): section: The section within the INI file to read the array from.
- **$3** (string): key: The key whose array of values is to be retrieved.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::key::exists

Checks if a specified key exists within a section in an INI file.

This function provides a convenient way to verify the presence of a specific
key within a designated section of an INI configuration file. It acts as a
wrapper around 'shell::ini::read', using its capabilities to determine if
the key can be successfully retrieved.
If strict mode is active (`SHELL_INI_STRICT` is set to 1), it first
validates the format of the section and key names, returning an error if
they do not conform to the defined naming conventions.
The function ensures its own output is clean by suppressing the internal
logging of 'shell::ini::read', providing clear, colored messages indicating
whether the key was found or not.

Notes:

- This function does not output the value of the key, only its existence status.
- It leverages 'shell::ini::read' and other 'shell::ini*validate*\*' functions for its operations.
- For detailed reasons why a key might not be found (e.g., file doesn't exist,
  section doesn't exist), 'shell::ini::read' or 'shell::ini::section::exists'
  will provide their own specific error messages if called directly.

#### Example

```bash
# Check if a 'port' key exists in the 'Network' section of 'settings.ini'
if shell::ini::key::exists settings.ini Network port; then
shell::console::print "Found 'port' setting." 46
else
shell::console::print "The 'port' setting is missing." 196
fi
```

#### Options

- **-h**

  Optional. Displays this help message.

#### Arguments

- **$1** (string): file: The path to the INI file.
- **$2** (string): section: The section within the INI file to check.
- **$3** (string): key: The key to check for existence.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::env::expose

Exports key-value pairs from an INI file as environment variables.

This function provides a convenient way to load INI configuration into the
current shell's environment. It iterates through the specified INI file,
reading section and key-value pairs, and then uses the 'export' command
to make them available as environment variables.

To ensure compatibility with shell variable naming conventions, all section
and key names used in the environment variable name (e.g., SECTION_KEY) are
automatically sanitized. This involves converting them to uppercase and
replacing any non-alphanumeric or non-underscore characters with underscores.

If a specific section is provided, only the keys within that section are
processed. If no section is given, all readable sections and their keys
across the entire file are exported.

Notes:

- This function does not modify the INI file.
- Variable names in the environment are derived from sanitized section and
  key names. For instance, a section '[My Config]' and key 'api-key' would
  become 'MY_CONFIG_API_KEY'.
- Values containing special characters are exported as-is; it's the calling
  script's responsibility to handle such values.
- This function uses process substitution (`< <(...)`) for portability
  when iterating over lists of sections/keys, making it compatible with
  older Bash versions (e.g., Bash 3 on macOS) as well as newer ones.
- If a key's value cannot be read (e.g., key not found by ini_read), that
  specific key will be skipped in the export process, and a warning will be
  logged.

#### Example

```bash
# Export database credentials from 'db.ini' with 'DB_APP' prefix
# assuming db.ini contains:
# [production]
# host=localhost
# user=db.user
# pass=db.pass
shell::ini::env::expose db.ini DB_APP production
echo $DB_APP_PRODUCTION_HOST # Outputs 'localhost'
```

#### Options

- **-h**

  Optional. Displays this help message.

#### Arguments

- **$1** (string): file: The path to the INI file to read.
- **...** (string): section: Optional. If specified, only keys from this specific section will be exported. If omitted, keys from all sections will be exported.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::env::destroy

Unsets environment variables previously exported from an INI file.

This function serves to clean up environment variables that were previously
populated using 'shell::ini::env::expose'. It reconstructs the expected names of
these environment variables by parsing the provided INI file (or a specified
subset) and applying the same sanitization and prefixing logic as
'shell::ini::env::expose'.

For each potential environment variable name, the function checks if it is
currently set in the shell's environment. If found, the variable is
then unset, effectively removing it from the current session. This helps in
maintaining a clean environment or switching between different configurations.

It's important to use the identical parameters (file, prefix, section) that
were supplied during the initial export to ensure that the correct set of
variables is targeted for destruction.

Notes:

- This function does not report individual errors if a variable was expected
  but not found or already unset; it simply proceeds.
- The function's effectiveness relies on matching the naming convention of
  'shell::ini::env::expose'.
- This function uses process substitution (`< <(...)`) for portability
  when iterating over lists of sections/keys, making it compatible with
  older Bash versions (e.g., Bash 3 on macOS) as well as newer ones.

#### Example

```bash
# To export variables from 'dev.ini' with prefix 'DEV_APP':
# shell::ini::env::expose dev.ini DEV_APP
# To then destroy these variables:
# shell::ini::env::destroy dev.ini DEV_APP
```

#### Options

- **-h**

  Optional. Displays this help message.

#### Arguments

- **$1** (string): file: The path to the INI file that was used for exporting variables.
- **...** (string): section: Optional. If specified, only variables corresponding to keys from this specific section will be unset. If omitted, keys from all sections (matching the prefix, if given) will be targeted.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::value::get_or_default

Reads a key's value from an INI file or returns a default if not found.

This function attempts to retrieve a configuration value from an INI file.
It takes the file path, section name, and key as mandatory arguments.
An optional 'default_value' can be provided.

The function first tries to read the key's value using 'shell::ini::read'.
If 'shell::ini::read' successfully finds and returns a value (exit status 0),
that value is echoed to standard output.
If 'shell::ini::read' fails to find the key or encounters any other issue
(e.g., file not found, section not found), the 'default_value' is echoed
to standard output instead. If 'default_value' is not provided, an empty
string is used as the default.

This function always returns 0 on completion (indicating that a value,
either read or default, was provided), unless there are missing mandatory
parameters.

Notes:

- 'shell::ini::read' error messages (e.g., "File not found", "Key not found") are
  suppressed to avoid clutter when a default value is being returned.
  This function provides its own consolidated logging.
- Ensures cross-platform compatibility by relying on standard Bash features
  and existing cross-platform helper functions.

#### Example

```bash
# Read 'timeout' from 'Network' section, default to '30'
TIMEOUT=$(shell::ini::value::get_or_default app.ini Network timeout 30)
echo "Connection Timeout: $TIMEOUT seconds"
# Read 'feature_flag' or default to empty string
FLAG=$(shell::ini::value::get_or_default settings.ini Features feature_flag)
if [ "$FLAG" = "enabled" ]; then
echo "Feature is ON."
fi
```

#### Options

- **-h**

  Optional. Displays this help message.

#### Arguments

- **$1** (string): file: The path to the INI file.
- **$2** (string): section: The section within the INI file to search.
- **$3** (string): key: The key whose value is to be retrieved.
- **...** (string): default_value: Optional. The value to return if the key is not found or if reading fails. Defaults to an empty string if omitted.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::section::rename

Renames an existing section in an INI file.

This function renames a section within an INI file by replacing its header.
It performs validation to ensure the file exists, the old section exists,
and the new section name does not already exist. It also applies strict
validation rules for section names if `SHELL_INI_STRICT` is enabled.
The function uses 'sed' for in-place editing, adapting its syntax for
macOS (BSD sed) and Linux (GNU sed) for cross-platform compatibility.

Notes:

- Relies on shell::console::print, shell::ini::check, shell::ini::section::exists,
  shell::ini::escape_regex, shell::ini::validate::section, and shell::exec::shell.

#### Example

```bash
shell::ini::section::rename config.ini "OldSection" "NewSection"
shell::ini::section::rename -n settings.ini "Database" "ProductionDB" # Dry-run mode
```

#### Options

- **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

#### Arguments

- **$1** (string): file: The path to the INI file.
- **$2** (string): old_section: The current name of the section to be renamed.
- **$3** (string): new_section: The new name for the section.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::section::rename::fzf

Interactively selects a section from an INI file using fzf and renames it.

This function first lists all sections in the specified INI file using
shell::ini::section::list. It then presents these sections to the user
via fzf for interactive selection. Once a section is chosen, the user is
prompted to enter a new name for it. The renaming operation is then
delegated to the shell::ini::section::rename function.
It includes checks for file existence and fzf installation.

Notes:

- Relies on shell::console::print, shell::package::install, shell::ini::section::list,
  and shell::ini::section::rename.

#### Example

```bash
shell::ini::section::rename::fzf config.ini  # Interactively rename a section in config.ini.
shell::ini::section::rename::fzf -n settings.ini # Dry-run: show commands to rename a section.
```

#### Options

- **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

- **-h**

  Optional help flag. Displays this help message.

#### Arguments

- **$1** (string): file: The path to the INI file.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::section::clone

Clones an existing section to a new section within the same INI file.
All key-value pairs from the source section are copied to the destination section.

This function first validates that the source section exists in the INI file.
It then checks if the destination section already exists, warning the user if it does.
It reads all key-value pairs from the source section and writes them sequentially
to the new destination section. This is achieved by iterating through the file content
between the source section header and the next section header (or end of file).
The function ensures file integrity by writing to a temporary file and then atomically
replacing the original file.

Notes:

- Relies on shell::console::print, shell::ini::section::exists, shell::ini::section::add,
  shell::ini::write, shell::ini::temp_file, and shell::ini::escape_regex.
- Honors SHELL_INI_STRICT for section name validation.

#### Example

```bash
shell::ini::section::clone config.ini "Development" "Staging"
shell::ini::section::clone -n config.ini "Production" "Backup_Prod"
```

#### Options

- **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

#### Arguments

- **$1** (string): file: The path to the INI file.
- **$2** (string): source_section: The name of the section to clone.
- **$3** (string): destination_section: The name of the new section to create and copy keys into.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::section::clone::fzf

Interactively selects a section to clone from an INI file using fzf,
prompts for a new name (with "\_clone" prefix), and then clones the section.

This function first ensures fzf is installed. It then lists all sections in the
given INI file and uses fzf to allow the user to interactively select a section.
After selection, it prompts the user for a new section name, appending "\_clone"
to the selected section name as a suggestion. Finally, it calls
shell::ini::section::clone to perform the cloning operation.
The function handles dry-run mode, where it only prints the commands that would be executed.

Notes:

- Relies on shell::console::print, shell::package::install, shell::ini::section::list,
  shell::ini::section::clone, and shell::logger::command_clip.
- Provides interactive selection and auto-suggestion for the cloned section name.

#### Example

```bash
shell::ini::section::clone::fzf config.ini   # Interactively clone a section.
shell::ini::section::clone::fzf -n config.ini # Dry-run: show commands to clone a section.
```

#### Options

- **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

#### Arguments

- **$1** (string): file: The path to the INI file.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::section::remove::fzf

Interactively selects multiple sections to remove from an INI file using fzf.

This function first ensures fzf is installed. It then lists all sections in the
given INI file and uses fzf to allow the user to interactively select one or
more sections for removal. After selection, it proceeds to remove the selected
sections and their contents from the INI file.
The function handles dry-run mode, where it only prints the commands that would be executed.

Notes:

- Relies on shell::console::print, shell::package::install, shell::ini::section::list,
  shell::exec::shell, shell::logger::command_clip, and shell::ini::escape_regex.
- Uses fzf's multi-select feature (TAB key) for selecting multiple sections.

#### Example

```bash
shell::ini::section::remove::fzf config.ini   # Interactively remove sections.
shell::ini::section::remove::fzf -n config.ini # Dry-run: show commands to remove sections.
```

#### Options

- **-n**

  Optional dry-run flag. If provided, commands are printed using shell::logger::command_clip instead of executed.

- **-h**

  Optional help flag. Displays this help message.

#### Arguments

- **$1** (string): file: The path to the INI file.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::view::fzf

Interactively previews all key-value pairs in each section of an INI file using fzf in a real-time wrapped vertical layout.

This function lists all sections in the specified INI file using shell::ini::section::list,
and uses fzf to preview all key-value pairs in each section in real-time.
The preview window wraps lines and simulates a tree-like layout for readability.

#### Example

```bash
shell::ini::view::fzf config.ini
shell::ini::view::fzf -n config.ini
```

#### Arguments

- **$1** (string): file: The path to the INI file.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::view::super::fzf

Interactively previews all key-value pairs in each section of an INI file using fzf in a real-time wrapped vertical layout.

This function lists all sections in the specified INI file using shell::ini::section::list,
and uses fzf to preview all key-value pairs in each section in real-time.
The preview window wraps lines and simulates a tree-like layout for readability.
It supports exporting the selected section as JSON or YAML, or selecting multiple keys for export.

#### Example

```bash
shell::ini::view::super::fzf config.ini
shell::ini::view::super::fzf config.ini --json
shell::ini::view::super::fzf config.ini --multi
```

#### Options

- **--json**

  Optional. Export the selected section as JSON.

- **--yaml**

  Optional. Export the selected section as YAML.

- **--multi**

  Optional. Allow multi-key selection and export.

#### Arguments

- **$1** (string): file: The path to the INI file.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::view::control::fzf

Interactively previews all key-value pairs in each section of an INI file using fzf in a real-time wrapped vertical layout.

This function lists all sections in the specified INI file using shell::ini::section::list,
and uses fzf to preview all key-value pairs in each section in real-time.
The preview window wraps lines and simulates a tree-like layout for readability.
It supports exporting the selected section as JSON or YAML, or selecting multiple keys for export.
A [Previous Section] option is included to allow users to return to section selection.

#### Example

```bash
shell::ini::view::control::fzf config.ini
shell::ini::view::control::fzf config.ini --json
shell::ini::view::control::fzf config.ini --multi
```

#### Options

- **--json**

  Optional. Export the selected section as JSON.

- **--yaml**

  Optional. Export the selected section as YAML.

- **--multi**

  Optional. Allow multi-key selection and export.

#### Arguments

- **$1** (string): file: The path to the INI file.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.

### shell::ini::edit::fzf

Interactively edits or renames a key in an INI file using fzf.

This function allows the user to select a section and a key from an INI file,
then choose to either edit the value of the key or rename the key.
It uses fzf for interactive selection and sed for in-place editing.

#### Example

```bash
shell::ini::edit::fzf config.ini
```

#### Arguments

- **$1** (string): file: The path to the INI file.

#### Exit codes

- **0**: Success.

### shell::ini::dump::json

Dumps all sections and their key-value pairs from an INI file as a JSON object.

This function reads all sections and their keys from the specified INI file,
decodes their values, and outputs them as a structured JSON object.

#### Example

```bash
shell::ini::dump::json
```

#### Arguments

- **$1** (string): file: The path to the INI file.

#### Exit codes

- **0**: Success.
- **1**: The operation failed.
