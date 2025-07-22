#!/bin/bash
# test_common.sh - Unit tests for common.sh

# Source the library
LIB_DIR="$HOME/shell/src/lib"
source "$LIB_DIR/common.sh"

# Test counter
total_tests=0
failed_tests=0

# Assertion helper
assert_equals() {
	((total_tests++))
	if [ "$1" = "$2" ]; then
		echo "PASS: $3"
	else
		echo "FAIL: $3 (Expected '$1', got '$2')"
		((failed_tests++))
	fi
}

# Test shell::get_os_type
test_shell::get_os_type() {
	local os_type=$(shell::get_os_type)
	case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
	darwin*)
		assert_equals "macos" "$os_type" "shell::get_os_type should return 'macos' on macOS"
		;;
	linux*)
		assert_equals "linux" "$os_type" "shell::get_os_type should return 'linux' on Linux"
		;;
	*)
		assert_equals "unknown" "$os_type" "shell::get_os_type should return 'unknown' on unsupported OS"
		;;
	esac
}

# Run tests
echo "Running tests for common.sh..."
test_shell::get_os_type
echo "Tests completed: $total_tests run, $failed_tests failed"
exit $failed_tests
