#!/bin/bash
# run_tests.sh - Runs all unit tests

TEST_DIR="$HOME/shell/test"
total_failed=0

echo "Starting unit tests..."
for test_file in "$TEST_DIR"/test_*.sh; do
	if [ -f "$test_file" ]; then
		echo "--------------------------------"
		bash "$test_file"
		status=$?
		if [ $status -ne 0 ]; then
			((total_failed++))
			echo "Test $test_file failed with status $status"
		fi
	fi
done
echo "--------------------------------"
echo "All tests completed. Failed suites: $total_failed"
exit $total_failed
