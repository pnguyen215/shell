# Function discovery: find, read and run any `shell::` function

The library has over 1,100 functions (about 630 public). `shell::help` is the way in: it shows what exists, what each function does and how to call it, without opening a source file.

```bash
shell::help                  # explore: namespaces -> search -> documentation -> run / copy
shell::help git              # open the git namespace   (alias: sfn git)
shell::help pick commit      # words that are not a namespace are the initial search

shell::function::list                         # plain text, grouped by namespace   (alias: sfl)
shell::function::list --namespace git::commit pick
shell::function::list --names --namespace ssh # names only, for scripts
shell::function::info git::commit::pick::fzf  # description, options, examples     (alias: sfi)
```

## The explorer

```
shell::help
  Namespace:  All functions (636) | angular (1) | ask (13) | ... | git (105) | ...   preview: its functions
        Enter
  Function (git):  name + description, fuzzy search over both                       preview: documentation
        Enter                                                    (Enter never runs anything)
  Action menu:  Show details | Run it... | Show its own help (-h) | Copy the name | ← Back
        Run it...  ->  usage is shown, you type the arguments, the command line is shown,
                       you confirm  ->  it runs in YOUR shell  ->  back to the list
```

- Choosing a function only opens the menu. **Nothing runs until you pick "Run it..." and confirm.**
- "Run it..." runs the function in the current shell, as if you had typed the line at the prompt: quoting works, and a function that changes the directory or sets a variable does so in your shell. The arguments are your own command line (a `;` in them is yours), so only type what you would type anyway.
- ESC closes; **← Back** goes up one level; after an action the list comes back with the cursor on the same function.
- `--internal` (`-i`) includes the `_shell::*` helpers; `--unloaded` shows functions that are in the source tree but not loaded in this shell.
- **fzf is optional.** Without it, or when the output is not a terminal (a pipe, `$(...)`), `shell::help` prints the plain list. `--plain` forces the list, `--interactive` forces fzf.

## Research summary: how the library is organised

| Question           | Finding                                                                                                                                                                                                                           |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Layout             | `src/<group>/<module>.sh`; groups load in the order of `SHELL_MODULE_GROUPS`. About 1,126 functions in 100 files.                                                                                                                 |
| Loading            | Eager: `src/shell.sh` sources every file at start. Nothing is lazy, nothing is exported (`export -f` is not used): the functions exist because the file was sourced into the current shell.                                       |
| Name to file       | There is no mapping to maintain, and the file name does not follow the namespace (`shell::git::*` is spread over `git.sh`, `git_history.sh`, ...). The definition line is the only reliable link.                                 |
| Public vs internal | The `_shell::` prefix; `make lint` enforces prefix `<=>` `# @internal`.                                                                                                                                                           |
| Documentation      | Every function carries a shdoc block directly above `name() {` (`make lint` fails without it): `@description`, `@option`, `@arg`, `@stdout`, `@exitcode`, `@see`, `@example`, `@internal`. `make docs` renders it to `docs/api/`. |
| Existing help      | Each public function has its own `-h`, printed by `shell::logger::*` at run time; there was no listing, search or completion.                                                                                                     |
| Interactive parts  | `shell::fzf::select` (cursor memory), `shell::ask::*`, `shell::clipboard::copy`, the "list -> action -> list" pattern of `shell::git::manage::fzf`. fzf is installed on demand elsewhere; here it is optional.                    |
| Names              | No `shell::help`, `shell::list` or `shell::explore` existed. `sh` is the system shell and was not touched.                                                                                                                        |
| `docs/api`         | Generated and **not authoritative for discovery**: at the time of writing it lists 464 of the 632 public functions, and 2 names in it no longer exist.                                                                            |

### Approaches compared

| Approach                                                  | Verdict                                                                                                                                                                            |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Read `docs/api`                                           | Stale unless regenerated, needs `shdoc`/`gawk`, and not present in an installed copy. Rejected.                                                                                    |
| Ask the shell (`declare -F` / `typeset +f`) only          | Complete for what is loaded, but has no descriptions or file, differs between bash and zsh, and cannot tell "not loaded" from "not existing". Used **only** for the "loaded" flag. |
| A hand-kept registry of names and descriptions            | A second list to forget to update. Rejected.                                                                                                                                       |
| New metadata format (a `# @category` tag, a JSON index)   | Unneeded: the shdoc block already has everything. Rejected; a tag can be added later where the namespace is not enough.                                                            |
| **Scan `src/` for the shdoc blocks, flag what is loaded** | Always in step with the code, works in bash and zsh, no new format. **Chosen.**                                                                                                    |
| Execute `fn -h` to get usage                              | Runs arbitrary code to read documentation; output is not uniform. Only offered as an explicit menu action.                                                                         |
| Shell completion                                          | Valuable, but different in bash and zsh and needs setup; the data it needs is `shell::function::list --names`. Left for a follow-up; the foundation is in place.                   |
| Recently used / analytics                                 | Needs state; deferred.                                                                                                                                                             |

## Architecture

```
                 src/**/*.sh   (the code, each function with its shdoc block)
                      |
        data/function-catalog.awk          the only code that recognises a function and its block
                      |      + names loaded in the shell (declare -F | typeset +f)
                      v
        _shell::function::catalog          8-field records, sorted        <- the single source
                      |
        _shell::function::select           filters: visibility, namespace, keywords, load state
           |                   |                     |
  shell::function::list   shell::function::info   shell::function::explore  <- user interfaces
  (text, scripts)         (one page)              (fzf)  --> shell::help, aliases sfn / sfl / sfi
                               |                     |
                  data/function-doc.awk   data/function-preview.sh  (preview panel: runs outside the library)
```

| Where                           | Responsibility                                                                                                                                                                       |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `src/lib/function.sh`           | The module: namespace `shell::function::*`. Public: `list`, `info`, `explore`. Private: `catalog`, `select`, `find`, `loaded`, `is_loaded`, `rows`, `act`, `invoke`, `explore_loop`. |
| `src/data/function-catalog.awk` | **Discovery and metadata.** Reads the source files, emits one record per function.                                                                                                   |
| `src/data/function-doc.awk`     | Renders one shdoc block as a reference page (`info` and the preview).                                                                                                                |
| `src/data/function-preview.sh`  | The explorer's preview command: a standalone script, because fzf runs previews in a process where the library's functions are not defined.                                           |
| `src/shell.sh`                  | `shell::help`, the short entry point (a one-line wrapper, like `shell::version`).                                                                                                    |
| `src/constant/paths.sh`         | The paths of the three data files.                                                                                                                                                   |
| `src/alias/alias.sh`            | `sfn`, `sfl`, `sfi`.                                                                                                                                                                 |

Why a module under `lib/`: it is generic (it depends only on `core`), it is about the library as a whole rather than one domain, and `lib/` already holds `fs`, `conf`, `workspace`. Why separate files in `data/`: the awk programs and the preview script must be runnable on their own (the preview is a child process), and they keep parsing out of the bash.

### The catalog record

`name  visibility  category  loaded  file  first-line  def-line  summary` (tab separated)

| Field                      | Source                                                                                                                                                                                          |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| name                       | the line `name() {` at column 0 starting with `shell::` or `_shell::`                                                                                                                           |
| visibility                 | `public`, or `internal` when the name starts with `_`                                                                                                                                           |
| category                   | the namespace after `shell::` (`git`); `shell` for top-level names such as `shell::version`                                                                                                     |
| loaded                     | `yes` when the current shell has the function, `no` when it is only in the tree                                                                                                                 |
| file, first-line, def-line | where the shdoc block starts and where the function is defined (relative to the library root); `-` for a function that is loaded but not in the tree (for instance one defined in your profile) |
| summary                    | the first line of the `@description` (the text on the tag line, or the first text line after a bare tag)                                                                                        |

A function is recognised **the way `make lint` already recognises it** (naming, shdoc coverage and visibility checks use the same rule), and its documentation is the block of `#` lines directly above it. A blank line detaches a block; a file header (`@file`) is not a function's description. There is no attempt to parse shell syntax: nothing but the column-0 definition line and the comment block is read, so a string that merely contains `shell::x() {` is not a function.

### Bash and zsh

Only one place asks the shell for its functions (`_shell::function::loaded`): `declare -F` in bash, `typeset +f` in zsh. Everything else is text processing (`awk`, `sort`, `sed`, all POSIX options), arrays are avoided or guarded, and `${x:+--flag "$y"}` expansions (which zsh does not split) are not used. Tests run under both.

## Adding to the system

**A new function needs nothing extra.** Write it with its shdoc block, as `make lint` already requires, and it appears in `list`, `info` and the explorer. Write the first line of `@description` as a complete sentence that stands alone: it is what the list and the search show.

To extend discovery, change the one layer that owns the concern:

| You want                                                      | Change                                                                                                    |
| ------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| a new field (a category tag, a "since" version, dependencies) | read it in `function-catalog.awk` (add a field at the end of the record), render it in `function-doc.awk` |
| a new filter or view                                          | `_shell::function::select` and `shell::function::list`                                                    |
| shell completion                                              | feed it from `shell::function::list --names [--namespace ..]`; add the completion function to this module |
| usage analytics / recent functions                            | record in the explorer's `_shell::function::act`, keep the data under `SHELL_CONFIG_DIR`                  |
| another front end (a web page, `man`)                         | consume `shell::function::list --tsv` or call `_shell::function::catalog`                                 |

Never keep a second list of functions: use the catalog.

## Limits

- The catalog is built on every call (about 0.15 s for the whole tree). Nothing is cached, so it is always current.
- Only the first line of the description is in the catalog; `info` and the preview render the whole block.
- Functions defined at run time by something other than a file in `src/` (a profile, `eval`) are listed as loaded but have no documentation.
- "Run it..." needs a terminal on stdin: prompts read from it.
- If the library is installed without its `src/` tree (it is not by the installers), only loaded functions are listed.
