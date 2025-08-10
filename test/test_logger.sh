#!/bin/bash
# test_logger.sh - Unit tests for logger.sh exec_check function

# Source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../src/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/logger.sh"

# Test counter
total_tests=0
failed_tests=0

# Assertion helper
assert_exit_code() {
	((total_tests++))
	if [ "$1" -eq "$2" ]; then
		echo "PASS: $3 (exit code: $1)"
	else
		echo "FAIL: $3 (Expected exit code $2, got $1)"
		((failed_tests++))
	fi
}

assert_contains() {
	((total_tests++))
	if echo "$1" | grep -q "$2"; then
		echo "PASS: $3 (contains '$2')"
	else
		echo "FAIL: $3 (Expected to contain '$2', got: $1)"
		((failed_tests++))
	fi
}

# Test 1: Successful command
test_exec_check_success() {
	echo "=== Testing successful command ==="
	local output
	output=$(shell::logger::exec_check "echo 'test success'" 2>&1)
	local exit_code=$?
	
	assert_exit_code $exit_code 0 "Successful command should return exit code 0"
	assert_contains "$output" "✓" "Successful command should show success indicator"
	assert_contains "$output" "Success" "Successful command should show default success message"
}

# Test 2: Failing command
test_exec_check_failure() {
	echo "=== Testing failing command ==="
	local output
	output=$(shell::logger::exec_check "ls /definitely/nonexistent/path" 2>&1)
	local exit_code=$?
	
	assert_exit_code $exit_code 2 "Failing command should return exit code 2"
	assert_contains "$output" "✗" "Failing command should show failure indicator"
	assert_contains "$output" "Aborted" "Failing command should show default failure message"
	assert_contains "$output" "Output:" "Failing command should show output"
}

# Test 3: Custom messages
test_exec_check_custom_messages() {
	echo "=== Testing custom messages ==="
	local output
	output=$(shell::logger::exec_check "echo 'test'" "Custom Success" "Custom Failure" 2>&1)
	local exit_code=$?
	
	assert_exit_code $exit_code 0 "Command with custom messages should succeed"
	assert_contains "$output" "Custom Success" "Should use custom success message"
}

# Test 4: Error pattern detection (exit code 0 but error in output)
test_exec_check_error_pattern() {
	echo "=== Testing error pattern detection ==="
	local output
	# Create a command that returns 0 but has error-like output
	output=$(shell::logger::exec_check "echo 'Error: something went wrong'; exit 0" 2>&1)
	local exit_code=$?
	
	assert_exit_code $exit_code 1 "Command with error pattern should return exit code 1"
	assert_contains "$output" "✗" "Command with error pattern should show failure indicator"
}

# Test 5: Fast timeout test (create a command that would normally take longer)
test_exec_check_timeout() {
	echo "=== Testing timeout functionality ==="
	local output
	# Use a 2-second timeout for a command that would sleep for 5 seconds
	output=$(shell::logger::exec_check "sleep 5" "Success" "Failed" "2" 2>&1)
	local exit_code=$?
	
	assert_exit_code $exit_code 124 "Timeout command should return exit code 124"
	assert_contains "$output" "Timeout after 2s" "Timeout command should show timeout message"
}

# Test 6: Empty command
test_exec_check_empty_command() {
	echo "=== Testing empty command ==="
	local output
	output=$(shell::logger::exec_check "" 2>&1)
	local exit_code=$?
	
	assert_exit_code $exit_code 1 "Empty command should return exit code 1"
}

# Test 7: Command with special characters
test_exec_check_special_chars() {
	echo "=== Testing command with special characters ==="
	local output
	output=$(shell::logger::exec_check "echo 'Hello & \"World\"'" 2>&1)
	local exit_code=$?
	
	assert_exit_code $exit_code 0 "Command with special characters should succeed"
}

# Run tests
echo "Running tests for shell::logger::exec_check..."
test_exec_check_success
test_exec_check_failure  
test_exec_check_custom_messages
test_exec_check_error_pattern
test_exec_check_timeout
test_exec_check_empty_command
test_exec_check_special_chars

echo "================================"
echo "Tests completed: $total_tests run, $failed_tests failed"
exit $failed_tests