#!/bin/bash
# test_logger_safe.sh - Unit tests for safe logger execution functions

# Source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../src/lib"
source "$LIB_DIR/logger.sh"
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

assert_exit_code() {
	((total_tests++))
	if [ "$1" -eq "$2" ]; then
		echo "PASS: $3"
	else
		echo "FAIL: $3 (Expected exit code '$1', got '$2')"
		((failed_tests++))
	fi
}

# Test shell::logger::exec_safe
test_shell_logger_exec_safe() {
	echo "Testing shell::logger::exec_safe..."
	
	# Test 1: Simple command execution
	echo "Test 1: Simple command"
	shell::logger::exec_safe "echo 'test simple command'" >/dev/null 2>&1
	local exit_code=$?
	assert_exit_code 0 $exit_code "exec_safe should succeed with simple echo command"
	
	# Test 2: Empty command should fail
	echo "Test 2: Empty command"
	shell::logger::exec_safe "" >/dev/null 2>&1
	local exit_code=$?
	assert_exit_code 1 $exit_code "exec_safe should fail with empty command"
	
	# Test 3: Command with pipes
	echo "Test 3: Command with pipes"
	shell::logger::exec_safe "echo 'hello world' | grep 'hello'" >/dev/null 2>&1
	local exit_code=$?
	assert_exit_code 0 $exit_code "exec_safe should handle pipes correctly"
	
	# Test 4: Command injection attempt should be blocked
	echo "Test 4: Command injection prevention"
	shell::logger::exec_safe "echo test; rm -rf /tmp/nonexistent" >/dev/null 2>&1
	local exit_code=$?
	assert_exit_code 1 $exit_code "exec_safe should block dangerous rm -rf patterns"
	
	# Test 5: Backtick injection attempt should be blocked
	echo "Test 5: Backtick injection prevention"
	shell::logger::exec_safe "echo \`whoami\`" >/dev/null 2>&1
	local exit_code=$?
	assert_exit_code 1 $exit_code "exec_safe should block backtick command substitution"
}

# Test shell::logger::exec_safe_check
test_shell_logger_exec_safe_check() {
	echo "Testing shell::logger::exec_safe_check..."
	
	# Test 1: Successful command
	echo "Test 1: Successful command"
	shell::logger::exec_safe_check "true" >/dev/null 2>&1
	local exit_code=$?
	assert_exit_code 0 $exit_code "exec_safe_check should return 0 for successful command"
	
	# Test 2: Failed command
	echo "Test 2: Failed command"
	shell::logger::exec_safe_check "false" >/dev/null 2>&1
	local exit_code=$?
	assert_exit_code 1 $exit_code "exec_safe_check should return 1 for failed command"
	
	# Test 3: Custom success/failure messages
	echo "Test 3: Custom messages"
	shell::logger::exec_safe_check "true" "Custom Success" "Custom Failure" >/dev/null 2>&1
	local exit_code=$?
	assert_exit_code 0 $exit_code "exec_safe_check should work with custom messages"
	
	# Test 4: Empty command should fail
	echo "Test 4: Empty command"
	shell::logger::exec_safe_check "" >/dev/null 2>&1
	local exit_code=$?
	assert_exit_code 1 $exit_code "exec_safe_check should fail with empty command"
	
	# Test 5: Command injection attempt should be blocked
	echo "Test 5: Command injection prevention"
	shell::logger::exec_safe_check "echo test; sudo rm -rf /tmp" >/dev/null 2>&1
	local exit_code=$?
	assert_exit_code 1 $exit_code "exec_safe_check should block dangerous sudo rm patterns"
	
	# Test 6: Command substitution attempt should be blocked
	echo "Test 6: Command substitution prevention"
	shell::logger::exec_safe_check "echo \$(whoami)" >/dev/null 2>&1
	local exit_code=$?
	assert_exit_code 1 $exit_code "exec_safe_check should block command substitution"
	
	# Test 7: Test with redirects (should work)
	echo "Test 7: Command with redirects"
	shell::logger::exec_safe_check "echo 'test' > /dev/null" >/dev/null 2>&1
	local exit_code=$?
	assert_exit_code 0 $exit_code "exec_safe_check should handle redirects correctly"
	
	# Test 8: Test that legitimate commands with semicolons but no dangerous patterns work
	echo "Test 8: Safe semicolon usage"
	shell::logger::exec_safe_check "echo 'first'; echo 'second'" >/dev/null 2>&1
	local exit_code=$?
	assert_exit_code 0 $exit_code "exec_safe_check should allow safe semicolon usage"
}

# Run tests
echo "Running tests for logger safe execution functions..."
test_shell_logger_exec_safe
test_shell_logger_exec_safe_check
echo "Tests completed: $total_tests run, $failed_tests failed"
exit $failed_tests