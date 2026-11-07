# Coding conventions

The reference style is `src/lang/*.sh`. This page is the checklist; `make lint` enforces the mechanical parts.

## 1. Where things go

| What                                                              | Where                                                                         |
| ----------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| A path, URL, colour, default, return code, list of protected keys | `src/constant/*.sh` — **never** inline in a function                          |
| Output, logging, prompts, OS detection, command execution         | `src/core/`                                                                   |
| Installing an external tool                                       | `src/dependency/<tool>.sh`                                                    |
| Installing / upgrading agent skills (Claude Code, OpenCode)       | `src/skill/`                                                                  |
| Building Markdown / Telegram MarkdownV2 text                      | `src/markdown/` (`shell::markdown::*`); never write a second escaper          |
| Everything else                                                   | `src/lib/` (generic) or `src/lang/`, `src/devops/`, `src/shield/`, `src/bot/` |

Files are `lower_snake_case.sh`, start with `#!/usr/bin/env bash` and an `@file` / `@brief` shdoc header. Constants are `UPPER_SNAKE_CASE`, assigned with `: "${VAR:=default}"` when the user may override them, and are **not** `readonly` (the library can be re-sourced).

## 2. Naming

`shell::<category>::<name>` — lowercase, `::` separated, `_` inside words. Interactive (fzf) variants end in `::fzf`. The category is the module's domain (`git`, `conf`, `fs`, `net`...), not the file name.

### Visibility: public vs private

The prefix decides whether a function is part of the public API and whether it shows up in the interactive terminal. Typing `shell::` and pressing Tab must list **only** public functions.

| Form                         | Visibility                | Exported | Shown on `shell::<Tab>` |
| ---------------------------- | ------------------------- | -------- | ----------------------- |
| `shell::<category>::<name>`  | Public (user-facing API)  | **yes**  | yes                     |
| `_shell::<category>::<name>` | Private (internal helper) | **no**   | no                      |

Rules:

- **Public** functions keep the `shell::` prefix, are exported, and **must** have a full shdoc block (see §3). Renaming or removing one is a breaking change.
- **Private** functions use the `_shell::` prefix (a leading underscore) and are **never** exported. They **must** also have a full shdoc block, and that block **must** include the `# @internal` annotation so shdoc keeps them out of the public `docs/api/` reference. They may change or disappear at any time; callers outside the library must not rely on them.
- Never give a private helper the `shell::` prefix "just for convenience" — it would leak into autocomplete. Conversely, never call a `_shell::` function from the user's interactive session or from another script; call the public wrapper.
- A function used by more than one file is still private unless users are meant to type it. Visibility is about the user, not about file boundaries.
- When a helper becomes useful to users, promote it: rename `_shell::x::y` → `shell::x::y`, export it, add the full shdoc block and a test, and update every caller.
- Every function, public or private, has shdoc. A `_shell::*` function without `# @internal`, or a `shell::*` function with it, is a bug.
- Export only `shell::*` names. An exported `_shell::*` function is a bug.

Local variables: `lower_snake_case`, always declared with `local`. **Never** use names that are special in zsh: `status path options commands functions aliases parameters argv reply pipestatus`.

## 3. Function template

This template (shdoc block + `-h|--help` handling) applies to **public** (`shell::*`, exported) functions. Private `_shell::*` functions use the same shdoc block, plus `# @internal`; the `-h|--help` handling is optional for them.

```bash
# @description One-sentence summary.
#   Optional longer explanation, including any non-obvious behaviour or security note.
# @internal   (private `_shell::*` functions only — omit on public ones)
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string Name of the thing.
# @stdout What is printed on stdout (when it is data meant to be captured).
# @exitcode 0 Success.
# @exitcode 2 Invalid or missing arguments.
# @example
#   shell::category::verb -n "thing"
#
shell::category::verb() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "One-sentence summary"
		shell::logger::usage "shell::category::verb [-n] <thing>"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::category::verb -n \"thing\""
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local thing="${1-}"
	if [ -z "$thing" ]; then
		shell::logger::error "A thing is required"
		return "$RETURN_INVALID"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::exec::command -n do_it "$thing"
		return "$RETURN_SUCCESS"
	fi
	shell::exec::command do_it "$thing"
}
```

shdoc notes: put `@example` **last** and end the block with a lone `#` (an example swallows following lines until a blank comment line); `@option` takes at most two flag forms joined by `|`.

## 4. Rules

**Return codes.** Use `RETURN_*` from `constant/returncodes.sh`; every code is unique. A function that reports success must return 0 — and the reverse. (A whole family of bugs in earlier releases returned 1 right after printing "success".)

**Never `exit` in a function.** The library is sourced into the user's interactive shell; `exit` closes their terminal. Use `return`.

**Never set a global `trap` in a function** (`trap ... EXIT` fires when the _shell_ exits and replaces the user's own trap).

**Prefer argv over `eval`.** `shell::exec::command prog "$arg"` keeps `$arg` as one word. If a command string is unavoidable (pipes, redirects), quote every interpolated value and never pass untrusted input (message text, filenames from the network).

**Quote expansions; fill arrays with a `while read` loop**, not `arr=($(cmd))` (file names contain spaces).

**No implicit `sudo`, no `chmod 777`.** Use `shell::fs::mkdir --private` / `shell::fs::touch --private` for anything holding secrets (modes 700/600).

**Dry run.** Anything that changes state accepts `-n`, prints the command via `shell::logger::command_clip`, and changes nothing.

**Interactive prompts must be cancellable.** ESC / EOF returns `RETURN_CANCELLED`; never loop forever.

**Dependencies.** Call `shell::dependency::<tool>::ensure` (cheap when the tool exists) instead of `shell::package::install` inline.

## 5. Portability (Linux + macOS, bash 3.2 + zsh)

Not allowed: `declare -A`, `mapfile`/`readarray`, `local -n`, `${x,,}`/`${x^^}`, `${!var}`, `BASH_REMATCH`, `[[ -v ]]`, `wait -n`, `echo -e`, `read -a`, GNU-only `sed -i`, `readlink -f`, `date -d`, `base64 -w`, `grep -P`, `stat -c`, `ps --sort`, `xargs -r`.

Use instead: `case` statements, parameter expansion, `printf`, `shell::fs::sed_inplace`, `shell::fs::stat`, `shell::os::type` for the rare real branch (`pbcopy` vs `xclip`, `open` vs `xdg-open`). `BSD` and `GNU` userlands differ; when in doubt, test with the CI macOS runners.

## 6. Tests

Add a case to `test/test_*.sh` for every bug you fix. Tests run under bash **and** zsh (`make test`); they use an isolated `HOME`, and a fake `curl` for anything networked.

Scratch space: `test/run_tests.sh` creates one folder, `$HOME/shell-test/run.<pid>` (override the base with `SHELL_TEST_BASE`), exports it as `SHELL_TEST_RUN` and points `TMPDIR` into it. `t_setup` creates each file's isolated `HOME` there, and the runner deletes the whole folder when the run ends, even after Ctrl-C or a crash. A test must never write outside `$HOME` of its own `t_setup`, and must not call `mktemp` with a path of its own.

## 7. Documentation

Every function carries shdoc. Private `_shell::*` functions are marked `# @internal`, so they do not appear in the public API docs. `make docs` builds `docs/api/` with [shdoc](https://github.com/reconquest/shdoc) (`gawk` required). To install it: `git clone https://github.com/reconquest/shdoc && sudo make -C shdoc install`.
