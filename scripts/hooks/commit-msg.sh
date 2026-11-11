#!/usr/bin/env bash
# git commit-msg hook: reject commit messages that break the repo's rules.
#
# Installed (copied, not symlinked) into $(git rev-parse --git-path hooks)/commit-msg
# by `make hooks`. Thin by design: every rule lives in scripts/check_commit_msg.sh,
# so the hook, CI and the tests can never disagree about what a valid message is.
# When the checker cannot be found (the repository was moved or trimmed) the hook
# warns and lets the commit through: CI is the hard gate, the hook is a convenience.
set -u

root="$(git rev-parse --show-toplevel 2>/dev/null)" || root=""
checker="${root}/scripts/check_commit_msg.sh"

if [ -z "$root" ] || [ ! -r "$checker" ]; then
	printf 'commit-msg: %s not found, skipping the check\n' "$checker" >&2
	exit 0
fi

bash "$checker" --file "$1"
