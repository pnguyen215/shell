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

## Empty commits

`shell::git::commit::create --empty` picks a ready-made message from the templates and runs `git commit --allow-empty`. It follows the same switch: templates are shown without their emoji unless emoji are on. The templates live in `~/.shell-config/git/git-commit-messages.txt` (installed from [`src/data/`](../src/data/git-commit-messages.txt)); add your own in `git-commit-messages.user.txt` next to it, and check either file with `shell::git::commit::message::validate`.
