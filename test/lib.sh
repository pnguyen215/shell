#!/usr/bin/env bash
# Minimal assertion helpers shared by every test file. Written in the common
# subset of bash and zsh so the same tests run under both shells.
#
# Usage in a test file:
#   . "$SHELL_TEST_ROOT/test/lib.sh"; t_setup
#   t_eq "name" "expected" "$(some_function)"
#   t_done

: "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh}"
T_PASS=0
T_FAIL=0

# Create an isolated HOME, then load the library into the current shell.
t_setup() {
	T_HOME="$(mktemp -d "${TMPDIR:-/tmp}/shell-test.XXXXXX")"
	# Canonicalise: on macOS $TMPDIR ends in "/" and /var is a symlink to /private/var,
	# so the logical path ($PWD) and the mktemp path would otherwise differ.
	T_HOME="$(cd "$T_HOME" && pwd -P)"
	export HOME="$T_HOME" NO_COLOR=1 SHELL_AUTO_INSTALL_DEPS=0 SHELL_LOGGER_LEVEL=DEBUG
	export SHELL_DIR="$SHELL_TEST_ROOT"
	# shellcheck source=/dev/null
	. "$SHELL_TEST_ROOT/src/shell.sh"
	cd "$T_HOME" || exit 1
}

t_ok() {
	T_PASS=$((T_PASS + 1))
}
t_bad() {
	T_FAIL=$((T_FAIL + 1))
	printf '  FAIL: %s\n' "$1"
	[ -n "${2-}" ] && printf '        %s\n' "$2"
}

# t_eq <name> <expected> <actual>
t_eq() {
	if [ "$2" = "$3" ]; then t_ok; else t_bad "$1" "expected [$2] got [$3]"; fi
}

# t_has <name> <needle> <haystack>
t_has() {
	case "$3" in *"$2"*) t_ok ;; *) t_bad "$1" "[$2] not found in [$3]" ;; esac
}

# t_lacks <name> <needle> <haystack>
t_lacks() {
	case "$3" in *"$2"*) t_bad "$1" "[$2] unexpectedly present in [$3]" ;; *) t_ok ;; esac
}

# t_rc <name> <expected_rc> <command...>  -> sets T_OUT and T_RC
t_rc() {
	local name="$1" want="$2"
	shift 2
	T_OUT="$("$@" 2>&1)"
	T_RC=$?
	if [ "$T_RC" -eq "$want" ]; then t_ok; else t_bad "$name" "expected rc=$want got rc=$T_RC; output: $T_OUT"; fi
}

t_done() {
	rm -rf "${T_HOME:-/nonexistent-never}" 2>/dev/null
	printf '  %s: %d passed, %d failed\n' "$(basename "${SHELL_TEST_FILE:-$0}")" "$T_PASS" "$T_FAIL"
	[ "$T_FAIL" -eq 0 ]
}
