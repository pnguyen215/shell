#!/usr/bin/env bash
# Run every test_*.sh under bash and (when installed) zsh.
# Usage: test/run_tests.sh [name-filter]
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export SHELL_TEST_ROOT="$ROOT"
filter="${1-}"
failed=0

shells="bash"
command -v zsh >/dev/null 2>&1 && shells="bash zsh"

for sh in $shells; do
	printf '== %s ==\n' "$sh"
	for file in "$ROOT"/test/test_*.sh; do
		case "$file" in *"$filter"*) ;; *) continue ;; esac
		SHELL_TEST_FILE="$file" "$sh" "$file" || failed=$((failed + 1))
	done
done

printf '\nFailed suites: %d\n' "$failed"
[ "$failed" -eq 0 ]
