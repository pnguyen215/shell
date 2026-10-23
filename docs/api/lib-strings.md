# lib/strings.sh

String sanitising, trimming and case-formatting helpers.

## Overview

Pure text helpers. They print their result on stdout and never modify the
caller's variables. `printf '%s\n'` is used everywhere instead of `echo`,
because `echo "$x"` misbehaves when `$x` is `-n`, `-e` or contains
backslashes (and behaves differently in bash, zsh and sh).

## Index

* [shell::strings::trim](#shellstringstrim)
* [shell::strings::sanitize::upper](#shellstringssanitizeupper)
* [shell::strings::sanitize::lower](#shellstringssanitizelower)
* [shell::strings::sanitize::capitalize](#shellstringssanitizecapitalize)
* [shell::strings::sanitize::lower_preserve](#shellstringssanitizelower_preserve)
* [shell::strings::format::camel](#shellstringsformatcamel)
* [shell::strings::format::title](#shellstringsformattitle)
* [shell::strings::sanitize::escape](#shellstringssanitizeescape)

### shell::strings::trim

Remove leading and trailing whitespace.
Pure parameter expansion - no external process is forked.

#### Example

```bash
shell::strings::trim "   hello  "    # -> hello
```

#### Arguments

* **$1** (string): Text to trim.

#### Exit codes

* **0**: Always.

#### Output on stdout

* The trimmed text.

### shell::strings::sanitize::upper

Upper-case a string and replace every char outside [A-Z0-9_] with `_`.
Intended for building environment-variable names.

#### Example

```bash
shell::strings::sanitize::upper "my var-name"   # -> MY_VAR_NAME
```

#### Arguments

* **$1** (string): Text to convert.

#### Exit codes

* **0**: Always.

#### Output on stdout

* The sanitised, upper-case text.

### shell::strings::sanitize::lower

Lower-case a string and replace every char outside [a-z0-9_] with `_`.

#### Example

```bash
shell::strings::sanitize::lower "My Var-Name"   # -> my_var_name
```

#### Arguments

* **$1** (string): Text to convert.

#### Exit codes

* **0**: Always.

#### Output on stdout

* The sanitised, lower-case text.

### shell::strings::sanitize::capitalize

Capitalise the first letter and collapse non-alphanumerics to `_`.
Leading and trailing underscores are removed.

#### Example

```bash
shell::strings::sanitize::capitalize "hello world"   # -> Hello_world
```

#### Arguments

* **$1** (string): Text to convert.

#### Exit codes

* **0**: Always.

#### Output on stdout

* The sanitised text (empty for empty input).

### shell::strings::sanitize::lower_preserve

Lower-case a string and collapse non-alphanumerics to `_` (no capitalisation).

#### Example

```bash
shell::strings::sanitize::lower_preserve "Hello, World"   # -> hello_world
```

#### Arguments

* **$1** (string): Text to convert.

#### Exit codes

* **0**: Always.

#### Output on stdout

* The sanitised, lower-case text (empty for empty input).

### shell::strings::format::camel

Convert text to PascalCase ("my var name" -> "MyVarName").
Despite the historical name `camel`, the first letter IS capitalised.

#### Example

```bash
shell::strings::format::camel "my_var name"   # -> MyVarName
```

#### Arguments

* **$1** (string): Text to convert.

#### Exit codes

* **0**: Always.

#### Output on stdout

* The PascalCase text.

### shell::strings::format::title

Capitalise the first letter of every space-separated word.

#### Example

```bash
shell::strings::format::title "hello big world"   # -> Hello Big World
```

#### Options

* **-h** | **--help**

  Show help and return.

#### Arguments

* **$1** (string): Text to convert.

#### Exit codes

* **0**: Success.
* **2**: Not exactly one argument was given.

#### Output on stdout

* The title-cased text.

### shell::strings::sanitize::escape

Escape text so it can be embedded in a double-quoted shell string.
Escapes backslash, forward slash, double quote and single quote, flattens
newlines/tabs to spaces, squeezes repeated spaces and trims the ends.

#### Example

```bash
shell::strings::sanitize::escape 'say "hi" / there'
```

#### Arguments

* **$1** (string): Text to escape.

#### Exit codes

* **0**: Always.

#### Output on stdout

* The escaped single-line text (no trailing newline).

