# Commit messages

Every commit must follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/) — the same format the library's own commit-message feature builds ([git-commit-messages.md](../features/git-commit-messages.md)). The subject is the first line (what `git log --oneline` shows); the body below it is free-form and never checked.

## The rules

| Rule                     | Detail                                                                                              |
| ------------------------ | ---------------------------------------------------------------------------------------------------- |
| Format                   | `type(scope)!: description` — scope and `!` (breaking change) are optional                              |
| Types                    | `build` `chore` `ci` `docs` `feat` `fix` `perf` `refactor` `revert` `style` `test`                     |
| Scope                    | when present: lower case, `a-z 0-9 . -` (for example `git`, `core-git`, `ci`)                          |
| Length                   | the whole subject at most **72** characters (the length git recommends)                                 |
| Mood                     | imperative: `add`, not `added` — the checker rejects a subject that starts with a past-tense verb       |
| Punctuation              | no final period, no leading/trailing space in the description                                          |
| Issue reference          | `#123` anywhere in the message (the repo's habit is the end of the subject) — **should**, the hook only hints |
| Exemptions               | `Merge ...`, `Revert "..."`, `fixup! ...` and `squash! ...` — git writes these, not you                 |

Examples:

```text
feat(auth): add OAuth2 login support #1
fix(runner): isolate scratch space per run #1
refactor(git)!: drop the v1 history format #1
```

```text
fixed stuff                          # no type
feat(auth): added OAuth2 login       # past tense
docs: update README.                 # final period
```

## Enforcement

The rules live in one place, `scripts/check_commit_msg.sh`, so the hook, CI and the tests can never disagree about what a valid message is.

- **Locally (opt-in): `make hooks`** installs the `commit-msg` hook (a copy of `scripts/hooks/commit-msg.sh`) into `$(git rev-parse --git-path hooks)`. A commit with an invalid subject is rejected before it is created, with the rule it broke printed on stderr; a missing issue reference is only a hint. If the checker cannot be found the hook warns and lets the commit through — CI is the hard gate, the hook is a convenience.
- **CI: the `commit-messages` job** (`.github/workflows/ci.yml`) validates every commit: on a pull request it checks the commits of the PR, on a push to `master` the new commits. Merge commits are skipped.

Fixing a bad message: `git commit --amend` for the last one, `git rebase -i` (reword) for older ones on your own branch.
