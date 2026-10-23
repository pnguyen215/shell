# Coding conventions

The reference style is `src/lang/*.sh`. This page is the checklist; `make lint` enforces the mechanical parts.

## 1. Where things go

| What | Where |
|---|---|
| A path, URL, colour, default, return code, list of protected keys | `src/constant/*.sh` — **never** inline in a function |
| Output, logging, prompts, OS detection, command execution | `src/core/` |
| Installing an external tool | `src/dependency/<tool>.sh` |
| Everything else | `src/lib/` (generic) or `src/lang/`, `src/devops/`, `src/shield/`, `src/bot/` |

Files are `lower_snake_case.sh`, start with `#!/usr/bin/env bash` and an `@file` / `@brief` shdoc header. Constants are `UPPER_SNAKE_CASE`, assigned with `: "${VAR:=default}"` when the user may override them, and are **not** `readonly` (the library can be re-sourced).

## 2. Naming

`shell::<category>::<name>` — lowercase, `::` separated, `_` inside words. Interactive (fzf) variants end in `::fzf`. The category is the module's domain (`git`, `conf`, `fs`, `net`...), not the file name. Private helpers use the same prefix and are marked `# @internal`.

Local variables: `lower_snake_case`, always declared with `local`. **Never** use names that are special in zsh: `status path options commands functions aliases parameters argv reply pipestatus`.

## 3. Function template

```bash
# @description One-sentence summary.
#   Optional longer explanation, including any non-obvious behaviour or security note.
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

**Never set a global `trap` in a function** (`trap ... EXIT` fires when the *shell* exits and replaces the user's own trap).

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

## 7. Documentation

`make docs` builds `docs/api/` with [shdoc](https://github.com/reconquest/shdoc) (`gawk` required). To install it: `git clone https://github.com/reconquest/shdoc && sudo make -C shdoc install`.
