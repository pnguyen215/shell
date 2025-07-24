#!/bin/bash
# test_common.sh - Unit tests for common.sh

# Source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../src/lib"
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

# Test shell::create_directory_if_not_exists with enhanced file path detection
test_shell::create_directory_if_not_exists() {
	local test_base_dir="/tmp/shell_test_$$"

	# Clean up any previous test data
	rm -rf "$test_base_dir"

	echo "Testing shell::create_directory_if_not_exists functionality..."

	# Test 1: Regular directory path (existing behavior)
	local dir_path="$test_base_dir/test/directory"
	shell::create_directory_if_not_exists "$dir_path" >/dev/null 2>&1
	if [ -d "$dir_path" ]; then
		echo "PASS: Regular directory creation"
		((total_tests++))
	else
		echo "FAIL: Regular directory creation failed"
		((total_tests++))
		((failed_tests++))
	fi

	# Test 2: File path with extension - should create parent directory
	local file_path="$test_base_dir/.github/workflows/test.yml"
	local expected_dir="$test_base_dir/.github/workflows"
	shell::create_directory_if_not_exists "$file_path" >/dev/null 2>&1
	if [ -d "$expected_dir" ] && [ ! -d "$file_path" ]; then
		echo "PASS: File path detection creates parent directory"
		((total_tests++))
	else
		echo "FAIL: File path detection - expected parent dir '$expected_dir' to exist, file dir '$file_path' should not exist"
		((total_tests++))
		((failed_tests++))
	fi

	# Test 3: Another file path example
	local file_path2="$test_base_dir/config/database.conf"
	local expected_dir2="$test_base_dir/config"
	shell::create_directory_if_not_exists "$file_path2" >/dev/null 2>&1
	if [ -d "$expected_dir2" ] && [ ! -d "$file_path2" ]; then
		echo "PASS: Additional file path detection works"
		((total_tests++))
	else
		echo "FAIL: Additional file path detection failed"
		((total_tests++))
		((failed_tests++))
	fi

	# Test 4: Directory without extension (should still work as before)
	local dir_without_ext="$test_base_dir/some/directory/without/extension"
	shell::create_directory_if_not_exists "$dir_without_ext" >/dev/null 2>&1
	if [ -d "$dir_without_ext" ]; then
		echo "PASS: Directory without extension still works"
		((total_tests++))
	else
		echo "FAIL: Directory without extension failed"
		((total_tests++))
		((failed_tests++))
	fi

	# Test 5: Relative file path
	local rel_file_path="test_scripts_$$/$$/build.sh"
	local current_dir=$(pwd)
	local expected_rel_dir="$current_dir/test_scripts_$$/$$"
	shell::create_directory_if_not_exists "$rel_file_path" >/dev/null 2>&1
	if [ -d "$expected_rel_dir" ] && [ ! -d "$current_dir/$rel_file_path" ]; then
		echo "PASS: Relative file path detection works"
		((total_tests++))
		# Clean up the relative directory created during test
		sudo rm -rf "$current_dir/test_scripts_$$" 2>/dev/null
	else
		echo "FAIL: Relative file path detection failed"
		((total_tests++))
		((failed_tests++))
		# Clean up anyway
		sudo rm -rf "$current_dir/test_scripts_$$" 2>/dev/null
	fi

	# Clean up test directories
	rm -rf "$test_base_dir"
}

# Run tests
echo "Running tests for common.sh..."
test_shell::get_os_type
test_shell::create_directory_if_not_exists
echo "Tests completed: $total_tests run, $failed_tests failed"
exit $failed_tests
