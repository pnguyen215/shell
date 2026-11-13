#!/usr/bin/env bash
# Run test_*.sh files under bash and (when installed) zsh.
#
# Usage:
#   test/run_tests.sh                     run every test file (what CI does)
#   test/run_tests.sh <name> [<name>...]  only files whose name contains <name>
#   test/run_tests.sh -f <function>       only files that mention <function>
#   test/run_tests.sh -l [...]            list the files that would run, run nothing
#   test/run_tests.sh -h                  this help
#
# Environment:
#   SHELLS="bash"   shells to run under (default: bash, plus zsh when installed)
#   SHELL_TEST_BASE where test scratch space lives (default: $HOME/shell-test)
#
# Everything a test creates (isolated HOMEs, temp files, fake repositories) lives under
# $SHELL_TEST_BASE/run.<pid>, which is deleted when the run ends (also on Ctrl-C, kill or
# a crash); $SHELL_TEST_BASE itself is removed when it is left empty. Nothing else is
# written outside the repository's own checkout.
#
# <name> may also be a path (test/test_git_squash.sh); only its file name is used.
# Kept to bash 3.2 syntax (macOS system bash): no arrays, no mapfile.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export SHELL_TEST_ROOT="$ROOT"

usage() {
	sed -n '2,/^set -u/p' "$0" | sed '$d; s/^# \{0,1\}//'
	exit "${1:-0}"
}

func=""
list=0
filters=""
while [ $# -gt 0 ]; do
	case "$1" in
	-f | --func)
		[ $# -ge 2 ] || {
			echo "run_tests: $1 needs a function name" >&2
			exit 2
		}
		func="$2"
		shift 2
		;;
	-l | --list)
		list=1
		shift
		;;
	-h | --help) usage 0 ;;
	-*)
		echo "run_tests: unknown option $1" >&2
		usage 2 >&2
		;;
	*)
		filters="$filters ${1##*/}"
		shift
		;;
	esac
done

# Select the files. After this loop "$@" holds them (safe even when the path has spaces).
set --
for file in "$ROOT"/test/test_*.sh; do
	base="${file##*/}"
	if [ -n "$func" ] && ! grep -qF -- "$func" "$file"; then continue; fi
	if [ -n "$filters" ]; then
		hit=0
		for f in $filters; do
			case "$base" in *"$f"*) hit=1 ;; esac
		done
		[ "$hit" -eq 1 ] || continue
	fi
	set -- "$@" "$file"
done

if [ $# -eq 0 ]; then
	if [ -n "$func" ]; then
		echo "run_tests: no test file mentions '$func'. Add a case to test/test_*.sh." >&2
	else
		echo "run_tests: no test file matches:${filters:- (none)}" >&2
	fi
	exit 1
fi

if [ "$list" -eq 1 ]; then
	for file in "$@"; do printf '%s\n' "${file##*/}"; done
	exit 0
fi

shells="${SHELLS:-bash}"
if [ -z "${SHELLS:-}" ] && command -v zsh >/dev/null 2>&1; then shells="bash zsh"; fi

# One scratch tree per run, always removed. The real $HOME is read once, here, and is never
# modified except for this folder.
SHELL_TEST_BASE="${SHELL_TEST_BASE:-$HOME/shell-test}"
case "$SHELL_TEST_BASE" in
/ | "" | "$HOME" | [!/]*) # CHANGED: also refuse a relative path
	echo "run_tests: refusing to use '$SHELL_TEST_BASE' as the scratch directory" >&2
	exit 2
	;;
esac
SHELL_TEST_RUN="$SHELL_TEST_BASE/run.$$"
mkdir -p "$SHELL_TEST_RUN/tmp" || {
	echo "run_tests: cannot create $SHELL_TEST_RUN" >&2
	exit 2
}
export SHELL_TEST_RUN
export TMPDIR="$SHELL_TEST_RUN/tmp"

# CHANGED: variables of the user's real shell that point into the real home would make the library
# write there even though HOME is redirected (the library keeps a pre-set SHELL_CONFIG_DIR, nvm keeps
# NVM_DIR, ...). Tests that need them set their own.
unset NVM_DIR NVM_BIN NVM_INC NVM_CD_FLAGS SHELL_CONFIG_DIR SHELL_INSTALL_DIR SHELL_SSH_DIR \
	XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME

# CHANGED: leak check, part 1. Top-level entries of the REAL home before the run.
REAL_HOME="$HOME"
home_before="$(ls -A "$REAL_HOME" 2>/dev/null)"

cleanup() {
	# Only this run's folder is removed; the base folder only when it is empty.
	[ -n "${SHELL_TEST_RUN:-}" ] && [ "${SHELL_TEST_RUN%/run.*}" = "$SHELL_TEST_BASE" ] && rm -rf "$SHELL_TEST_RUN"
	rmdir "$SHELL_TEST_BASE" 2>/dev/null
	return 0
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

failed=0
for sh in $shells; do
	printf '== %s ==\n' "$sh"
	for file in "$@"; do
		SHELL_TEST_FILE="$file" "$sh" "$file" || failed=$((failed + 1))
	done
done

printf '\nFailed suites: %d\n' "$failed"

# CHANGED: leak check, part 2. Anything new at the top level of the real home (other than the scratch
# folder) was created by a test or by the library it exercises; list it and fail. Nothing is deleted.
leaked=""
home_after="$(ls -A "$REAL_HOME" 2>/dev/null)"
while IFS= read -r entry; do
	[ -n "$entry" ] || continue
	[ "$REAL_HOME/$entry" = "$SHELL_TEST_BASE" ] && continue
	if ! printf '%s\n' "$home_before" | grep -qxF -- "$entry"; then leaked="$leaked  $REAL_HOME/$entry"$'\n'; fi
done <<LEAKEOF
$home_after
LEAKEOF
if [ -n "$leaked" ]; then
	printf '\nLEAK: the tests created entries outside %s (remove them by hand):\n%s' "$SHELL_TEST_BASE" "$leaked" >&2
	failed=$((failed + 1))
fi

[ "$failed" -eq 0 ]
