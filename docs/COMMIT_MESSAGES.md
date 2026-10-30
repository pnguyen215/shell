# Commit messages

`shell::git::commit::create` (aliases `sgcc`, `sgcf`) and `shell::git::commit::predict` (`sgcpd`, `sgcfpd`) write commit messages that follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/), so tools such as commitlint, semantic-release and release-please can read them.

## Format

```
<type>[(scope)]: <description> [<issue>]
```

The type is always the prefix. The issue is optional in the format; `create` asks for it, and `predict` pre-fills it from the branch name (`feat/123-login` → `#123`).

Both commands pass the message to `git commit -m` as a single argument, so quotes, `$` and backticks in a description are stored as typed.

## Emoji

Emoji are **off by default**. When they are on, the gitmoji goes **after** the colon, as part of the description, so the header stays a valid Conventional Commits header:

```
feat: add login #12               # off (default)
feat: :sparkles: add login #12    # on
```

Turn them on for one call with `--emoji`, or everywhere with an environment variable (read at call time, so it can go in `~/.zshrc` / `~/.bashrc` before or after sourcing the library):

```bash
shell::git::commit::create --emoji
shell::git::commit::predict --list --emoji
export SHELL_GIT_COMMIT_EMOJI=true      # on for every commit
shell::git::commit::create --no-emoji   # off again for one commit
```

The first rule that applies wins:

| Order | Source                                  | Effect                                     |
| ----- | --------------------------------------- | ------------------------------------------ |
| 1     | `--emoji` / `--no-emoji` (the last one) | that call only                             |
| 2     | `SHELL_GIT_COMMIT_EMOJI`                | `true`, `1`, `yes` or `on` (any case) = on |
| 3     | default                                 | off                                        |

## Menu labels and the type they produce

The type menu keeps its familiar labels. A label that is not a Conventional Commits type (`initial source` has a space, `WIP` is not a type) is committed as one that is, and the confirmation step shows the final message before anything is committed.

| Label            | Committed as         | Emoji (when on)              |
| ---------------- | -------------------- | ---------------------------- |
| `feat`           | `feat`               | `:sparkles:`                 |
| `fix`            | `fix`                | `:bug:`                      |
| `chore`          | `chore`              | `:wrench:`                   |
| `docs`           | `docs`               | `:books:`                    |
| `style`          | `style`              | `:art:`                      |
| `refactor`       | `refactor`           | `:recycle:`                  |
| `test`           | `test`               | `:white_check_mark:`         |
| `perf`           | `perf`               | `:chart_with_upwards_trend:` |
| `WIP`            | `chore(wip)`         | `:construction:`             |
| `improvement`    | `perf`               | `:zap:`                      |
| `revert`         | `revert`             | `:rewind:`                   |
| `security`       | `fix(security)`      | `:lock:`                     |
| `remove`         | `refactor`           | `:fire:`                     |
| `initial source` | `chore(init)`        | `:tada:`                     |
| `logs`           | `chore(logs)`        | `:loud_sound:`               |
| `config`         | `chore(config)`      | `:gear:`                     |
| `build`          | `build`              | `:hammer:`                   |
| `dependency`     | `build(deps)`        | `:package:`                  |
| `deployment`     | `ci(deploy)`         | `:rocket:`                   |
| `localization`   | `feat(i18n)`         | `:earth_americas:`           |
| `search`         | `feat(search)`       | `:mag:`                      |
| `experimental`   | `feat(experimental)` | `:alien:`                    |
| `version tag`    | `chore(release)`     | `:bookmark:`                 |
| `silent changes` | `chore`              | `:mute:`                     |
| `deprecation`    | `chore(deprecate)`   | `:warning:`                  |
| `release`        | `chore(release)`     | `:gem:`                      |

The mapping is the `SHELL_GIT_COMMIT_TYPES` constant in [`src/constant/defaults.sh`](../src/constant/defaults.sh), one `label|type|emoji` per line. The type must be one of `build chore ci docs feat fix perf refactor revert style test`, with an optional lower-case scope; `make test` fails if a label maps to anything else.

## How `predict` decides

`predict` reads the change itself, not just the file names, and ranks its guesses by evidence. Everything runs locally and is deterministic: no model, no network, the same diff gives the same messages.

| What it sees in the diff                                   | What it predicts                                              |
| ---------------------------------------------------------- | ------------------------------------------------------------- |
| a guard added inside `shell::auth::login()`                | `fix(session): handle missing values in auth::login`          |
| new functions `a::one`, `a::two`, `a::three`               | `feat(session): add a::one, a::two and a::three`              |
| `## Installation` and `## Commit prediction` added to docs | `docs: document installation and commit prediction in README` |
| `lodash` `^4.17.0` → `^4.17.21` in `package.json`          | `build(deps): bump lodash to 4.17.21`                         |
| `go.mod`: one module bumped, one added                     | `build(deps): bump cobra and add testify`                     |
| two `Test…` functions added                                | `test(auth): add 2 test cases for login`                      |
| a file renamed or moved                                    | `refactor: rename login to signin` / `move login to auth`     |
| a function deleted                                         | `refactor(session): remove auth::old`                         |
| new code, plus its tests and a docs change                 | `feat(auth): add Refresh with tests and docs`                 |

What it uses:

- **Symbols.** The functions, classes and types that were added, modified or removed (bash, Go, Python, JS/TS, Rust, Java/Kotlin/C#, SQL), from the added and removed lines and from the hunk headers. A function that only _sits before_ newly added code is not reported as modified.
- **Intent.** Words in the added code decide between a fix (and which kind: typo, crash, race, timeout, missing values, error handling…), a performance change (cache, batch, parallel…) and hardening (sanitize, escape…). A guard such as `if x is None` reads as a fix; Go's `if err != nil` does not. Without such evidence the fix description stays generic rather than pretending.
- **Scope.** The area most of the changed files live in (`src/auth/login.go` → `auth`; `src/lang/git.sh` → `git`, because `lang` is only a bucket). It is left out when it would repeat the description, when the files disagree, or when your last commits show you do not use scopes at all (8 or more conventional commits, fewer than 15 % scoped).
- **History.** A description your recent commits already used is pushed down, so accepting the first suggestion every time does not give a string of identical messages.
- **Length.** The header is kept to about 72 characters by naming fewer symbols (`a, b and 3 more`), never by cutting a word.
- **Honesty.** If there is nothing meaningful to say (only new functions, a pure rename) it offers fewer messages instead of vague ones, and `improvement` (committed as `perf`) is only offered when the branch is called `improvement/…`.

`shell::git::commit::predict::candidates` still works with just `git diff --name-status` on stdin, exactly as before; the smart behaviour switches on with `--patch-file` / `--history-file`, which `predict` always passes.

Known limits: a method indented inside a class shows the class as the enclosing symbol (`-U0` hunk headers only name top-level lines); file names and identifiers are reduced to ASCII so a description is always safe to paste; the engine reads at most the first 400 KB of the patch.

### Prior art

No code from other projects is included. While designing this, the open-source tools below were looked at; a few ideas (a scope derived from the project layout, learning from recent history to avoid repeats, a deterministic offline mode) also exist there, and credit is due:

- [andev0x/gitmit](https://github.com/andev0x/gitmit): heuristic analysis of the diff, with optional local-LLM generation and history tracking.
- [BallSpins/commit-gen](https://github.com/BallSpins/commit-gen): smart prediction with scope detection from the project structure.
- [razakadam74/gitmsg](https://github.com/razakadam74/gitmsg): fast, offline, deterministic Conventional Commits generator.

## Empty commits

`shell::git::commit::create --empty` picks a ready-made message from the templates and runs `git commit --allow-empty`. It follows the same switch: templates are shown without their emoji unless emoji are on. The templates live in `~/.shell-config/git/git-commit-messages.txt` (installed from [`src/data/`](../src/data/git-commit-messages.txt)); add your own in `git-commit-messages.user.txt` next to it, and check either file with `shell::git::commit::message::validate`.
