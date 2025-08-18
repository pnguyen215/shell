# Bash/Shell Script Coding Conventions

> **Version 2.1** - A comprehensive guide for modern shell scripting with best practices, security considerations, and CI/CD integration.

## Table of Contents

### Quick Reference

1. [Quick Start Guide](#quick-start-guide) - Essential patterns and examples
2. [Common Patterns Cheat Sheet](#common-patterns-cheat-sheet) - Copy-paste ready snippets

### Core Conventions

3. [General Guidelines](#general-guidelines) - Fundamental principles
4. [File Structure](#file-structure) - How to organize your scripts
5. [Naming Conventions](#naming-conventions) - Consistent naming patterns
6. [Variables and Constants](#variables-and-constants) - Declaration and usage
7. [Functions](#functions) - Design and documentation patterns

### Essential Practices

8. [Error Handling](#error-handling) - Robust error management
9. [Exit Codes](#exit-codes) - Simplified exit code reference
10. [Formatting and Style](#formatting-and-style) - Readable code standards
11. [Comments and Documentation](#comments-and-documentation) - Self-documenting code

### Advanced Topics

12. [Security Guidelines](#security-guidelines) - Secure coding practices
13. [Performance Optimization](#performance-optimization) - Writing efficient scripts
14. [Testing and Quality](#testing-and-quality) - Testing frameworks and quality assurance
15. [Debugging and Troubleshooting](#debugging-and-troubleshooting) - Common issues and solutions

### Modern Shell Practices

16. [CI/CD Integration](#cicd-integration) - Using shell scripts in automation
17. [Container Considerations](#container-considerations) - Shell scripts in Docker/containers
18. [Cross-Platform Compatibility](#cross-platform-compatibility) - Linux, macOS, and Windows considerations
19. [Package Management Integration](#package-management-integration) - Working with system packages

### Reference

20. [Complete Examples](#complete-examples) - Real-world script examples
21. [Quick Decision Trees](#quick-decision-trees) - When to use what
22. [Quality Checklists](#quality-checklists) - Script review guidelines
23. [Regex Patterns Reference](#regex-patterns-reference) - Common validation patterns

---

## Quick Start Guide

> **TL;DR** - Essential patterns for immediate use. Copy, adapt, and deploy.

### Script Template

```bash
#!/bin/bash
set -euo pipefail

# Script metadata
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="1.0.0"

# Configuration
readonly CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/myapp/config"
readonly LOG_FILE="/tmp/${SCRIPT_NAME%.*}.log"

# Global variables
VERBOSE=false
DRY_RUN=false

# Cleanup function
cleanup() {
    local exit_code=$?
    [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    exit $exit_code
}
trap cleanup EXIT INT TERM

# Main function
main() {
    # Your code here
    echo "Hello, World!"
}

# Script entry point
main "$@"
```

### Essential Patterns

#### Argument Parsing

```bash
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose) VERBOSE=true; shift ;;
            -n|--dry-run) DRY_RUN=true; shift ;;
            -h|--help) show_help; exit 0 ;;
            -*) echo "Unknown option: $1" >&2; exit 2 ;;
            *) break ;;
        esac
    done
}
```

#### File Operations

```bash
# Safe file operations
backup_file() {
    local file="$1"
    [[ -f "$file" ]] && cp "$file" "${file}.bak.$(date +%s)"
}

# Check file permissions
ensure_writable() {
    local dir="$1"
    [[ ! -d "$dir" ]] && mkdir -p "$dir"
    [[ ! -w "$dir" ]] && { echo "Error: $dir not writable" >&2; return 1; }
}
```

#### Logging

```bash
log() {
    local level="$1"; shift
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $*" | tee -a "$LOG_FILE"
}
```

## Common Patterns Cheat Sheet

### Quick Checks

```bash
# Command exists?
command -v git >/dev/null || { echo "git not found" >&2; exit 1; }

# File operations
[[ -f "$file" ]] && echo "File exists"
[[ -r "$file" ]] && echo "File readable"
[[ -w "$file" ]] && echo "File writable"
[[ -x "$file" ]] && echo "File executable"

# Directory operations
[[ -d "$dir" ]] || mkdir -p "$dir"

# Variable checks
[[ -n "$var" ]] && echo "Variable set"
[[ -z "$var" ]] && echo "Variable empty"
```

### Array Operations

```bash
# Declare and use arrays
declare -a files=("file1" "file2" "file3")
declare -A config=([host]="localhost" [port]="8080")

# Iterate safely
for file in "${files[@]}"; do
    echo "Processing: $file"
done

# Check if array key exists
[[ -n "${config[host]:-}" ]] && echo "Host: ${config[host]}"
```

### String Operations

```bash
# Extract components
filename="${path##*/}"          # basename
directory="${path%/*}"          # dirname
extension="${file##*.}"         # extension
basename="${file%.*}"          # filename without extension

# String replacement
new_string="${string/old/new}"          # Replace first
new_string="${string//old/new}"         # Replace all
```

### Process Management

```bash
# Background process with cleanup
start_background_task() {
    some_long_running_command &
    BACKGROUND_PID=$!
    trap 'kill $BACKGROUND_PID 2>/dev/null || true' EXIT
}

# Wait with timeout
timeout 30 some_command || echo "Command timed out"
```

---

## General Guidelines

### Shebang

Always start your script with an appropriate shebang:

```bash
#!/bin/bash              # For bash-specific scripts
#!/bin/sh               # For POSIX-compliant scripts
#!/usr/bin/env bash     # For portable bash scripts
```

### Shell Options

Set strict mode at the beginning of your script:

```bash
set -euo pipefail
# -e: Exit immediately if a command exits with a non-zero status
# -u: Treat unset variables as an error when substituting
# -o pipefail: The return value of a pipeline is the status of the last command to exit with a non-zero status
```

---

## File Structure

Organize your script in the following order:

```bash
#!/bin/bash
#
# File header with description, author, version, etc.
#

# Shell options
set -euo pipefail

# Constants
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Global variables
VERBOSE=false

# Functions (in logical order)
function_name() {
    # Function body
}

# Main execution
main() {
    # Main logic
}

# Script entry point
main "$@"
```

---

## Naming Conventions

### Variables

**Global Variables:**

- Use `UPPER_SNAKE_CASE` for global variables and constants
- Declare constants with `readonly` or `declare -r`

```bash
readonly CONFIG_FILE="/etc/myapp/config.conf"
readonly MAX_RETRY_COUNT=3
DEFAULT_TIMEOUT=30
```

**Local Variables:**

- Use `lower_snake_case` for local variables
- Always declare with `local` keyword inside functions

```bash
process_file() {
    local input_file="$1"
    local output_dir="$2"
    local temp_file="/tmp/processing.tmp"
}
```

### Functions

- Use `lower_snake_case` for function names
- Use descriptive names with verb + noun pattern
- Avoid abbreviations

```bash
# Good
check_file_exists() { }
validate_email_address() { }
backup_database() { }
cleanup_temp_files() { }

# Bad
chkFile() { }
validateEmail() { }
bkup() { }
clean() { }
```

### Files and Directories

- Use `lower_snake_case` for script files
- Add `.sh` extension for shell scripts
- Use descriptive names

```bash
# Good
backup_database.sh
user_management.sh
system_monitor.sh

# Bad
bkup.sh
usrmgmt.sh
sysmon.sh
```

---

## Variables and Constants

### Declaration Principles

**Constants and Readonly Variables:**

- Use `UPPER_SNAKE_CASE` for constants and global configuration
- Always use `readonly` for values that shouldn't change
- Group related constants together

```bash
# Application constants
readonly APP_NAME="MyApp"
readonly APP_VERSION="2.1.0"
readonly CONFIG_DIR="/etc/myapp"
readonly LOG_DIR="/var/log/myapp"

# System constants
readonly TEMP_DIR="$(mktemp -d)"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

**Local Variables:**

- Use `lower_snake_case` for local variables
- Always declare with `local` in functions
- Initialize with default values when appropriate

```bash
process_file() {
    local input_file="$1"
    local output_dir="${2:-./output}"
    local temp_file="/tmp/processing.$$"
    local max_retries=3
}
```

### Variable Usage

Always quote variables to prevent word splitting and pathname expansion:

```bash
# Good
cp "$source_file" "$destination_dir"
echo "User input: '$user_input'"

# Bad - can break with spaces or special characters
cp $source_file $destination_dir
echo User input: $user_input
```

### Parameter Expansion

Use parameter expansion for default values and string manipulation:

```bash
# Default values
config_file="${CONFIG_FILE:-/etc/default.conf}"
username="${1:-$(whoami)}"

# String manipulation
file_path="/path/to/file.txt"
filename="${file_path##*/}"        # file.txt
directory="${file_path%/*}"        # /path/to
extension="${file_path##*.}"       # txt
basename="${file_path%.*}"         # /path/to/file
```

---

## Functions

### Function Declaration

Use the `function_name()` syntax (preferred):

```bash
# Preferred
check_prerequisites() {
    local dependency="$1"
    # Function body
}
```

### Function Parameters

- Always declare parameters as local variables
- Validate parameters at the beginning of the function
- Use meaningful parameter names

```bash
create_user() {
    local username="$1"
    local email="$2"
    local role="${3:-user}"  # Default role

    # Parameter validation
    if [[ -z "$username" ]]; then
        echo "Error: Username is required" >&2
        return 1
    fi

    if [[ -z "$email" ]]; then
        echo "Error: Email is required" >&2
        return 1
    fi

    # Function logic here
}
```

### Function Return Values

Use return codes to indicate success/failure:

```bash
file_exists() {
    local file_path="$1"

    if [[ -f "$file_path" ]]; then
        return 0    # Success
    else
        return 1    # Failure
    fi
}

# Usage
if file_exists "/path/to/file"; then
    echo "File exists"
else
    echo "File not found"
fi
```

Use echo/printf for returning data:

```bash
get_current_timestamp() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
}

# Usage
timestamp=$(get_current_timestamp)
echo "Current time: $timestamp"
```

---

## Error Handling

### Command Execution

```bash
# Check if command exists
if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is not installed" >&2
    exit 1
fi

# Check command execution
if ! mkdir -p "$backup_dir"; then
    echo "Error: Failed to create backup directory: $backup_dir" >&2
    exit 1
fi

# Capture and check output
if ! output=$(command 2>&1); then
    echo "Error: Command failed with output: $output" >&2
    exit 1
fi
```

### Error Logging

```bash
readonly LOG_FILE="/var/log/myapp.log"

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $message" | tee -a "$LOG_FILE" >&2
}

log_info() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] INFO: $message" | tee -a "$LOG_FILE"
}
```

### Cleanup on Exit

```bash
cleanup() {
    local exit_code=$?

    # Remove temporary files
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi

    # Kill background processes
    if [[ -n "${BACKGROUND_PID:-}" ]]; then
        kill "$BACKGROUND_PID" 2>/dev/null || true
    fi

    exit $exit_code
}

# Set trap for cleanup
trap cleanup EXIT INT TERM
```

---

## Exit Codes

### Quick Reference

**Standard Exit Codes (Always Use These)**

```bash
readonly EXIT_SUCCESS=0        # Success
readonly EXIT_FAILURE=1        # General error
readonly EXIT_USAGE=2         # Invalid usage/arguments
readonly EXIT_CONFIG=3        # Configuration error
readonly EXIT_PERMISSION=4    # Permission denied
readonly EXIT_NOT_FOUND=5     # File/resource not found
readonly EXIT_TIMEOUT=6       # Operation timeout
```

### Common Categories

**System Errors (10-19)**

```bash
readonly EXIT_DEPENDENCY=10   # Missing dependency
readonly EXIT_DISK_SPACE=11   # Insufficient disk space
readonly EXIT_NETWORK=12      # Network error
readonly EXIT_SERVICE=13      # Service unavailable
```

**Application Errors (20-29)**

```bash
readonly EXIT_VALIDATION=20   # Input validation failed
readonly EXIT_PROCESSING=21   # Processing error
readonly EXIT_OUTPUT=22       # Output error
```

### Usage Examples

```bash
# Check dependencies
command -v git >/dev/null || exit $EXIT_DEPENDENCY

# Validate input
[[ -n "$input_file" ]] || { echo "Input file required" >&2; exit $EXIT_USAGE; }

# Check permissions
[[ -r "$config_file" ]] || { echo "Cannot read config" >&2; exit $EXIT_PERMISSION; }

# Exit with helper function
exit_with_error() {
    local code="$1"; shift
    echo "ERROR: $*" >&2
    exit "$code"
}
```

### Function Return Values

```bash
# Success/Failure
return 0        # Success
return 1        # General failure
return 2        # Invalid arguments
return 3        # Resource not available
return 4        # Operation not permitted
```

---

## Formatting and Style

### Indentation

- Use 4 spaces for indentation (no tabs)
- Be consistent throughout the script

```bash
if [[ condition ]]; then
    if [[ nested_condition ]]; then
        command
        another_command
    fi
fi
```

### Line Length

- Keep lines under 80-100 characters
- Break long lines logically

```bash
# Good
rsync -avz --delete \
    --exclude='*.log' \
    --exclude='tmp/' \
    "$source_dir/" \
    "$backup_dir/"

# Bad
rsync -avz --delete --exclude='*.log' --exclude='tmp/' "$source_dir/" "$backup_dir/"
```

### Spacing

```bash
# Good spacing
if [[ "$variable" == "value" ]]; then
    command --option="value" --flag
fi

for file in "${files[@]}"; do
    process_file "$file"
done

# Bad spacing
if [["$variable"=="value"]];then
command --option="value"--flag
fi

for file in "${files[@]}";do
process_file "$file"
done
```

### Brackets and Quotes

```bash
# Use [[ ]] for tests (bash builtin)
if [[ -f "$file" && -r "$file" ]]; then
    echo "File is readable"
fi

# Use [ ] only for POSIX compatibility
if [ -f "$file" ]; then
    echo "POSIX compatible test"
fi

# Always quote variables
echo "Processing file: '$filename'"
cp "$source" "$destination"
```

---

## Comments and Documentation

### File Header

```bash
#!/bin/bash
#
# Script Name: backup_system.sh
# Description: Automated system backup with rotation and compression
# Author: John Doe <john.doe@example.com>
# Version: 2.1.0
# Created: 2024-01-15
# Modified: 2024-08-18
#
# Usage: ./backup_system.sh [OPTIONS] SOURCE_DIR BACKUP_DIR
#
# Dependencies:
#   - rsync
#   - gzip
#   - tar
#
# Exit Codes:
#   0 - Success
#   1 - General error
#   2 - Invalid arguments
#   3 - Missing dependencies
#
```

### Function Documentation

```bash
#######################################
# Validates email address format using regex
#
# Checks if the provided email address matches
# a valid email format pattern.
#
# Arguments:
#   $1 - Email address to validate
#
# Returns:
#   0 - Valid email format
#   1 - Invalid email format
#
# Examples:
#   validate_email "user@example.com"
#   validate_email "invalid.email"
#######################################
validate_email() {
    local email="$1"
    local pattern="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"

    if [[ "$email" =~ $pattern ]]; then
        return 0
    else
        return 1
    fi
}
```

### Inline Comments

```bash
# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            # Unknown option
            echo "Error: Unknown option $1" >&2
            show_help
            exit 2
            ;;
    esac
done

# Validate required parameters
if [[ -z "$source_dir" ]]; then
    echo "Error: Source directory is required" >&2
    exit 2
fi
```

---

## Security Guidelines

### Input Validation and Sanitization

**Path Validation**

```bash
validate_path() {
    local path="$1"
    local allow_absolute="${2:-false}"

    # Check for path traversal attempts
    if [[ "$path" == *..* ]]; then
        echo "Error: Path traversal detected" >&2
        return 1
    fi

    # Check for absolute paths if not allowed
    if [[ "$path" == /* ]] && [[ "$allow_absolute" != "true" ]]; then
        echo "Error: Absolute paths not allowed" >&2
        return 1
    fi

    # Check for dangerous characters
    if [[ "$path" =~ [[:space:]';|&$`] ]]; then
        echo "Error: Dangerous characters in path" >&2
        return 1
    fi

    return 0
}
```

**Input Sanitization**

```bash
sanitize_input() {
    local input="$1"
    local allowed_pattern="$2"

    # Default to alphanumeric, dash, underscore, dot
    allowed_pattern="${allowed_pattern:-'^[a-zA-Z0-9._-]+$'}"

    if [[ "$input" =~ $allowed_pattern ]]; then
        echo "$input"
        return 0
    else
        echo "Error: Invalid characters in input: $input" >&2
        return 1
    fi
}
```

### Secure File Operations

**Safe Temporary Files**

```bash
create_secure_temp() {
    local template="${1:-secure.XXXXXX}"
    local temp_file

    # Create with restrictive permissions
    umask 0077
    temp_file=$(mktemp "/tmp/$template")

    # Verify permissions
    if [[ "$(stat -f %A "$temp_file" 2>/dev/null || stat -c %a "$temp_file")" != "600" ]]; then
        rm -f "$temp_file"
        echo "Error: Failed to create secure temp file" >&2
        return 1
    fi

    echo "$temp_file"
}
```

**Avoid Command Injection**

```bash
# BAD - Vulnerable to injection
execute_bad() {
    local user_input="$1"
    eval "ls $user_input"  # NEVER DO THIS
}

# GOOD - Safe execution
execute_safe() {
    local user_input="$1"
    local safe_input

    # Validate input first
    if ! safe_input=$(sanitize_input "$user_input" '^[a-zA-Z0-9/_.-]+$'); then
        return 1
    fi

    # Use array for command execution
    local cmd=(ls "$safe_input")
    "${cmd[@]}"
}
```

### Secrets Management

```bash
# Load secrets securely
load_secrets() {
    local secrets_file="$1"

    # Check file permissions
    local perms
    perms=$(stat -f %A "$secrets_file" 2>/dev/null || stat -c %a "$secrets_file")
    if [[ "$perms" != "600" ]]; then
        echo "Warning: Secrets file has loose permissions: $perms" >&2
    fi

    # Source secrets file safely
    if [[ -f "$secrets_file" ]]; then
        # shellcheck source=/dev/null
        source "$secrets_file"
    fi
}

# Never log secrets
log_safe() {
    local message="$1"
    # Remove potential secrets before logging
    message="${message//password=*/password=***}"
    message="${message//token=*/token=***}"
    echo "$message" | tee -a "$LOG_FILE"
}
```

---

## Performance Optimization

### Efficient Patterns

**Use Built-ins Over External Commands**

```bash
# SLOW - External commands
get_basename_slow() {
    basename "$1"
}

get_dirname_slow() {
    dirname "$1"
}

# FAST - Built-in parameter expansion
get_basename_fast() {
    echo "${1##*/}"
}

get_dirname_fast() {
    echo "${1%/*}"
}
```

**Optimize Loops and Conditionals**

```bash
# SLOW - Multiple external calls
check_files_slow() {
    local count=0
    for file in "$@"; do
        if [[ -f "$file" ]]; then
            count=$((count + 1))
        fi
    done
    echo "$count"
}

# FAST - Minimize external calls
check_files_fast() {
    local count=0
    local -a existing_files=()

    # Collect existing files first
    for file in "$@"; do
        [[ -f "$file" ]] && existing_files+=("$file")
    done

    echo "${#existing_files[@]}"
}
```

### Memory and Resource Management

**Large File Processing**

```bash
process_large_file() {
    local file="$1"
    local chunk_size="${2:-1000}"

    # Process in chunks instead of loading entire file
    while IFS= read -r -N "$chunk_size" chunk || [[ -n "$chunk" ]]; do
        # Process chunk
        process_chunk "$chunk"
    done < "$file"
}

# Use process substitution for pipes
process_with_substitution() {
    local logfile="$1"

    # Instead of: cat "$logfile" | grep "ERROR" | wc -l
    # Use process substitution:
    while IFS= read -r line; do
        [[ "$line" == *ERROR* ]] && echo "$line"
    done < <(cat "$logfile")
}
```

**Parallel Processing**

```bash
parallel_processing() {
    local -a files=("$@")
    local max_jobs=4
    local job_count=0

    for file in "${files[@]}"; do
        # Process in background
        process_file "$file" &

        # Limit concurrent jobs
        if (( ++job_count >= max_jobs )); then
            wait -n  # Wait for any job to complete
            ((job_count--))
        fi
    done

    # Wait for remaining jobs
    wait
}
```

---

## Testing and Quality

### Testing Framework

**Simple Test Runner**

```bash
#!/bin/bash
# test_runner.sh

# Test configuration
readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_UNDER_TEST="$TEST_DIR/../src/my_script.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
setup() {
    # Create test environment
    TEST_TEMP_DIR=$(mktemp -d)
    export TEST_TEMP_DIR
}

teardown() {
    # Cleanup test environment
    [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]] && rm -rf "$TEST_TEMP_DIR"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="${3:-assertion}"

    ((TESTS_RUN++))

    if [[ "$expected" == "$actual" ]]; then
        echo "✓ $test_name"
        ((TESTS_PASSED++))
    else
        echo "✗ $test_name"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        ((TESTS_FAILED++))
    fi
}

assert_file_exists() {
    local file="$1"
    local test_name="${2:-file exists: $file}"

    ((TESTS_RUN++))

    if [[ -f "$file" ]]; then
        echo "✓ $test_name"
        ((TESTS_PASSED++))
    else
        echo "✗ $test_name"
        echo "  File does not exist: $file"
        ((TESTS_FAILED++))
    fi
}

# Individual test functions
test_function_validation() {
    # Source the script
    source "$SCRIPT_UNDER_TEST"

    # Test valid input
    local result
    result=$(validate_email "test@example.com" 2>/dev/null; echo $?)
    assert_equals "0" "$result" "validate_email accepts valid email"

    # Test invalid input
    result=$(validate_email "invalid-email" 2>/dev/null; echo $?)
    assert_equals "1" "$result" "validate_email rejects invalid email"
}

# Test runner
run_tests() {
    echo "Running tests for $(basename "$SCRIPT_UNDER_TEST")"
    echo "================================================"

    setup

    # Run all test functions
    test_function_validation

    teardown

    # Summary
    echo
    echo "Test Summary:"
    echo "============="
    echo "Tests run: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "All tests passed! ✓"
        exit 0
    else
        echo "Some tests failed! ✗"
        exit 1
    fi
}

# Run tests if script is executed directly
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && run_tests "$@"
```

### Quality Assurance

**Linting and Static Analysis**

```bash
# Quality check script
quality_check() {
    local script="$1"
    local exit_code=0

    echo "Running quality checks on $script"
    echo "================================="

    # Shellcheck
    if command -v shellcheck >/dev/null; then
        echo "Running shellcheck..."
        if ! shellcheck "$script"; then
            echo "✗ Shellcheck failed"
            exit_code=1
        else
            echo "✓ Shellcheck passed"
        fi
    fi

    # Basic syntax check
    echo "Checking syntax..."
    if ! bash -n "$script"; then
        echo "✗ Syntax check failed"
        exit_code=1
    else
        echo "✓ Syntax check passed"
    fi

    # Check for common issues
    echo "Checking common issues..."

    # Unquoted variables
    if grep -n '\$[A-Za-z_][A-Za-z0-9_]*[^"]' "$script" | grep -v '#'; then
        echo "⚠ Found potentially unquoted variables"
        exit_code=1
    fi

    # Missing error handling
    if ! grep -q 'set -e\|set -euo\|set -eu' "$script"; then
        echo "⚠ Consider using 'set -euo pipefail' for better error handling"
    fi

    return $exit_code
}
```

---

## Debugging and Troubleshooting

### Debugging Techniques

**Debug Mode**

```bash
# Enable debug mode with environment variable
if [[ "${DEBUG:-}" == "true" ]]; then
    set -x  # Enable command tracing
    PS4='+ ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }' # Better trace format
fi

# Debug function
debug() {
    [[ "${DEBUG:-}" == "true" ]] && echo "DEBUG: $*" >&2
}

# Usage
debug "Processing file: $filename"
debug "Current working directory: $(pwd)"
```

**Error Tracing**

```bash
# Enhanced error handling with stack trace
error_handler() {
    local exit_code=$?
    local line_num=$1

    echo "Error occurred in script $0 at line $line_num" >&2
    echo "Exit code: $exit_code" >&2
    echo "Call stack:" >&2

    local i=0
    while caller $i >&2; do
        ((i++))
    done

    exit $exit_code
}

# Set up error trap
trap 'error_handler $LINENO' ERR
```

### Common Issues and Solutions

**Variable Scoping Issues**

```bash
# PROBLEM: Global variable unexpectedly changed
counter=0

increment_wrong() {
    counter=$((counter + 1))  # Modifies global
}

# SOLUTION: Use local variables and return values
increment_correct() {
    local current_value="$1"
    echo $((current_value + 1))
}

# Usage
counter=$(increment_correct "$counter")
```

**Array Handling Issues**

```bash
# PROBLEM: Array elements with spaces
files=("file with spaces.txt" "another file.txt")

# WRONG - Will break with spaces
for file in ${files[@]}; do  # Unquoted expansion
    echo "Processing: $file"
done

# CORRECT - Proper array iteration
for file in "${files[@]}"; do  # Quoted expansion
    echo "Processing: $file"
done
```

**Pipeline Error Handling**

```bash
# PROBLEM: Pipeline errors not caught
if cat nonexistent_file | grep "pattern"; then
    echo "Found pattern"
fi

# SOLUTION: Use pipefail and proper error checking
set -o pipefail

if cat nonexistent_file 2>/dev/null | grep "pattern"; then
    echo "Found pattern"
else
    echo "Error in pipeline or pattern not found"
fi
```

---

## CI/CD Integration

### GitHub Actions

**Basic Shell Script CI**

```yaml
# .github/workflows/shell-ci.yml
name: Shell Script CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y shellcheck bats

      - name: Lint shell scripts
        run: |
          find . -name "*.sh" -type f | xargs shellcheck

      - name: Run tests
        run: |
          # Run all test files
          find tests/ -name "*.bats" -exec bats {} \;

      - name: Check formatting
        run: |
          # Check if scripts follow conventions
          ./scripts/quality_check.sh src/*.sh
```

### Automated Testing Setup

**CI Test Runner**

```bash
#!/bin/bash
# ci/test-runner.sh
set -euo pipefail

readonly CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$CI_DIR")"

# Configuration
readonly COVERAGE_THRESHOLD=80
readonly MAX_COMPLEXITY=200

run_quality_checks() {
    echo "Running quality checks..."

    # Shellcheck all scripts
    find "$PROJECT_ROOT" -name "*.sh" -type f | while read -r script; do
        echo "Checking $script"
        shellcheck "$script" || return 1
    done

    # Check complexity (simple line count for now)
    find "$PROJECT_ROOT" -name "*.sh" -type f | while read -r script; do
        local lines
        lines=$(wc -l < "$script")
        if [[ $lines -gt $MAX_COMPLEXITY ]]; then
            echo "Warning: $script has $lines lines (threshold: $MAX_COMPLEXITY)"
        fi
    done
}

run_tests() {
    echo "Running tests..."

    # Run all test suites
    if [[ -d "$PROJECT_ROOT/tests" ]]; then
        bats "$PROJECT_ROOT/tests"/*.bats
    fi

    # Run integration tests
    if [[ -f "$PROJECT_ROOT/tests/integration.sh" ]]; then
        "$PROJECT_ROOT/tests/integration.sh"
    fi
}

main() {
    echo "Starting CI pipeline..."

    run_quality_checks
    run_tests

    echo "CI pipeline completed successfully!"
}

main "$@"
```

---

## Container Considerations

### Docker Best Practices

**Multi-stage Build for Shell Scripts**

```dockerfile
# Dockerfile for shell script deployment
FROM ubuntu:22.04 AS builder

# Install tools for linting and testing
RUN apt-get update && apt-get install -y \
    shellcheck \
    bats \
    && rm -rf /var/lib/apt/lists/*

COPY scripts/ /app/scripts/
COPY tests/ /app/tests/

WORKDIR /app

# Lint and test scripts
RUN find scripts/ -name "*.sh" | xargs shellcheck
RUN bats tests/*.bats

# Production stage
FROM ubuntu:22.04

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -s /bin/false scriptuser

# Copy validated scripts
COPY --from=builder /app/scripts/ /opt/scripts/

# Set proper permissions
RUN chmod +x /opt/scripts/*.sh \
    && chown -R scriptuser:scriptuser /opt/scripts/

USER scriptuser
ENTRYPOINT ["/opt/scripts/main.sh"]
```

**Container-Aware Shell Scripts**

```bash
#!/bin/bash
# container-aware.sh

# Detect if running in container
is_container() {
    [[ -f /.dockerenv ]] || grep -q 'container' /proc/1/cgroup 2>/dev/null
}

# Container-specific configuration
setup_container_env() {
    if is_container; then
        echo "Running in container environment"

        # Use environment variables for configuration
        readonly CONFIG_FILE="${CONFIG_FILE:-/config/app.conf}"
        readonly LOG_FILE="${LOG_FILE:-/logs/app.log}"
        readonly DATA_DIR="${DATA_DIR:-/data}"

        # Ensure directories exist
        mkdir -p "$(dirname "$CONFIG_FILE")" \
                 "$(dirname "$LOG_FILE")" \
                 "$DATA_DIR"
    else
        echo "Running in host environment"

        # Use traditional paths
        readonly CONFIG_FILE="${HOME}/.config/app/config.conf"
        readonly LOG_FILE="/tmp/app.log"
        readonly DATA_DIR="${HOME}/.local/share/app"
    fi
}

# Graceful shutdown handling for containers
graceful_shutdown() {
    echo "Received shutdown signal, cleaning up..."

    # Stop background processes
    if [[ -n "${BACKGROUND_PID:-}" ]]; then
        kill -TERM "$BACKGROUND_PID" 2>/dev/null || true
        wait "$BACKGROUND_PID" 2>/dev/null || true
    fi

    # Flush logs
    sync

    exit 0
}

# Set up signal handlers for container orchestration
trap graceful_shutdown TERM INT

main() {
    setup_container_env

    echo "Starting application..."

    # Your application logic here
    while true; do
        echo "Application running... (PID: $$)"
        sleep 30
    done
}

main "$@"
```

---

## Cross-Platform Compatibility

### Platform Detection

```bash
# Comprehensive platform detection
detect_platform() {
    local os arch

    # Detect OS
    case "${OSTYPE:-$(uname -s)}" in
        linux*)   os="linux" ;;
        darwin*)  os="macos" ;;
        cygwin*)  os="windows" ;;
        msys*)    os="windows" ;;
        win32*)   os="windows" ;;
        *)        os="unknown" ;;
    esac

    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64) arch="x64" ;;
        i386|i686)    arch="x86" ;;
        arm64|aarch64) arch="arm64" ;;
        armv7l)       arch="arm" ;;
        *)            arch="unknown" ;;
    esac

    echo "${os}-${arch}"
}
```

### Portable Commands

```bash
# Cross-platform command wrappers
portable_date() {
    # Different date command syntax across platforms
    if date --version >/dev/null 2>&1; then
        # GNU date (Linux)
        date "$@"
    else
        # BSD date (macOS)
        case "$1" in
            -d) shift; date -j -f "%Y-%m-%d %H:%M:%S" "$1" "$@" ;;
            *)  date "$@" ;;
        esac
    fi
}

portable_stat() {
    local file="$1"
    local format="$2"

    if stat --version >/dev/null 2>&1; then
        # GNU stat (Linux)
        stat -c "$format" "$file"
    else
        # BSD stat (macOS)
        stat -f "$format" "$file"
    fi
}

# Example usage
get_file_size() {
    local file="$1"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        portable_stat "$file" "%z"
    else
        portable_stat "$file" "%s"
    fi
}
```

---

## Package Management Integration

```bash
# Multi-package manager support
detect_package_manager() {
    if command -v apt-get >/dev/null; then
        echo "apt"
    elif command -v yum >/dev/null; then
        echo "yum"
    elif command -v dnf >/dev/null; then
        echo "dnf"
    elif command -v brew >/dev/null; then
        echo "brew"
    elif command -v pacman >/dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

install_package() {
    local package="$1"
    local pm
    pm=$(detect_package_manager)

    case "$pm" in
        apt)
            sudo apt-get update && sudo apt-get install -y "$package"
            ;;
        yum)
            sudo yum install -y "$package"
            ;;
        dnf)
            sudo dnf install -y "$package"
            ;;
        brew)
            brew install "$package"
            ;;
        pacman)
            sudo pacman -S --noconfirm "$package"
            ;;
        *)
            echo "Error: Unknown package manager" >&2
            return 1
            ;;
    esac
}

# Check and install dependencies
ensure_dependencies() {
    local -a required_packages=("$@")
    local -a missing_packages=()

    # Check which packages are missing
    for package in "${required_packages[@]}"; do
        if ! command -v "$package" >/dev/null; then
            missing_packages+=("$package")
        fi
    done

    # Install missing packages
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        echo "Installing missing packages: ${missing_packages[*]}"
        for package in "${missing_packages[@]}"; do
            if ! install_package "$package"; then
                echo "Error: Failed to install $package" >&2
                return 1
            fi
        done
    fi
}

# Usage
ensure_dependencies curl jq git
```

---

## Complete Examples

### Production-Ready Backup Script

```bash
#!/bin/bash
#
# Production Backup Script
# Demonstrates best practices for real-world shell scripting
#

set -euo pipefail

# Script metadata
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
readonly CONFIG_FILE="${BACKUP_CONFIG:-/etc/backup/config.conf}"
readonly LOG_DIR="/var/log/backup"
readonly LOCK_FILE="/var/run/backup.lock"

# Default values
readonly DEFAULT_RETENTION_DAYS=7
readonly DEFAULT_COMPRESSION="gzip"

# Global variables
VERBOSE=false
DRY_RUN=false
FORCE=false

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_USAGE=2
readonly EXIT_CONFIG=3
readonly EXIT_LOCK=4
readonly EXIT_BACKUP_FAILED=5

# Load configuration
load_config() {
    local config_file="$1"

    if [[ -f "$config_file" ]]; then
        # Source config with validation
        source "$config_file"

        # Validate required variables
        : "${BACKUP_SOURCE:?BACKUP_SOURCE not set in config}"
        : "${BACKUP_DESTINATION:?BACKUP_DESTINATION not set in config}"

        # Set defaults for optional variables
        RETENTION_DAYS="${RETENTION_DAYS:-$DEFAULT_RETENTION_DAYS}"
        COMPRESSION="${COMPRESSION:-$DEFAULT_COMPRESSION}"
    else
        echo "Error: Configuration file not found: $config_file" >&2
        exit $EXIT_CONFIG
    fi
}

# Logging functions
setup_logging() {
    mkdir -p "$LOG_DIR"
    readonly LOG_FILE="$LOG_DIR/backup-$(date +%Y%m%d).log"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
}

log() {
    local level="$1"; shift
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $*"
}

# Lock file management
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null)

        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            if [[ "$FORCE" == "true" ]]; then
                log "WARN" "Removing stale lock file (forced)"
                rm -f "$LOCK_FILE"
            else
                log "ERROR" "Another backup process is running (PID: $pid)"
                exit $EXIT_LOCK
            fi
        else
            log "WARN" "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi

    echo $$ > "$LOCK_FILE"
    log "INFO" "Acquired lock"
}

release_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
        log "INFO" "Released lock"
    fi
}

# Cleanup function
cleanup() {
    local exit_code=$?
    log "INFO" "Cleaning up..."

    release_lock

    exit $exit_code
}

# Main backup function
perform_backup() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="backup_${timestamp}"
    local backup_path="${BACKUP_DESTINATION}/${backup_name}"

    log "INFO" "Starting backup: $backup_name"
    log "INFO" "Source: $BACKUP_SOURCE"
    log "INFO" "Destination: $backup_path"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would create backup at $backup_path"
        return 0
    fi

    # Create backup directory
    mkdir -p "$BACKUP_DESTINATION"

    # Perform backup based on compression type
    case "$COMPRESSION" in
        gzip)
            tar -czf "${backup_path}.tar.gz" -C "$(dirname "$BACKUP_SOURCE")" "$(basename "$BACKUP_SOURCE")"
            ;;
        bzip2)
            tar -cjf "${backup_path}.tar.bz2" -C "$(dirname "$BACKUP_SOURCE")" "$(basename "$BACKUP_SOURCE")"
            ;;
        xz)
            tar -cJf "${backup_path}.tar.xz" -C "$(dirname "$BACKUP_SOURCE")" "$(basename "$BACKUP_SOURCE")"
            ;;
        none)
            cp -r "$BACKUP_SOURCE" "$backup_path"
            ;;
        *)
            log "ERROR" "Unknown compression type: $COMPRESSION"
            return 1
            ;;
    esac

    # Verify backup
    if [[ "$COMPRESSION" != "none" ]]; then
        local backup_file
        case "$COMPRESSION" in
            gzip) backup_file="${backup_path}.tar.gz" ;;
            bzip2) backup_file="${backup_path}.tar.bz2" ;;
            xz) backup_file="${backup_path}.tar.xz" ;;
        esac

        if [[ -f "$backup_file" ]]; then
            local size
            size=$(du -h "$backup_file" | cut -f1)
            log "INFO" "Backup created successfully: $(basename "$backup_file") ($size)"
        else
            log "ERROR" "Backup file not found after creation"
            return 1
        fi
    fi

    # Cleanup old backups
    cleanup_old_backups
}

cleanup_old_backups() {
    log "INFO" "Cleaning up backups older than $RETENTION_DAYS days"

    if [[ "$DRY_RUN" == "true" ]]; then
        find "$BACKUP_DESTINATION" -name "backup_*" -type f -mtime +$RETENTION_DAYS
        return 0
    fi

    local removed_count=0
    while IFS= read -r -d '' old_backup; do
        if rm "$old_backup"; then
            log "INFO" "Removed old backup: $(basename "$old_backup")"
            ((removed_count++))
        else
            log "WARN" "Failed to remove: $(basename "$old_backup")"
        fi
    done < <(find "$BACKUP_DESTINATION" -name "backup_*" -type f -mtime +$RETENTION_DAYS -print0)

    log "INFO" "Removed $removed_count old backup(s)"
}

# Usage information
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION - Production Backup Script

USAGE:
    $SCRIPT_NAME [OPTIONS]

OPTIONS:
    -c, --config FILE    Configuration file (default: $CONFIG_FILE)
    -v, --verbose        Enable verbose output
    -n, --dry-run        Show what would be done without executing
    -f, --force          Force execution (remove lock file if exists)
    -h, --help           Show this help message

CONFIGURATION:
    The script requires a configuration file with the following variables:

    BACKUP_SOURCE="/path/to/source"          # Required
    BACKUP_DESTINATION="/path/to/backups"    # Required
    RETENTION_DAYS=7                         # Optional (default: 7)
    COMPRESSION="gzip"                       # Optional (gzip|bzip2|xz|none)

```

## Regex Patterns Reference

### Common Validation Patterns

```bash
# Email validation
readonly REGEX_EMAIL='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

# IP address validation
readonly REGEX_IPV4='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
readonly REGEX_IPV6='^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$'

# URL validation
readonly REGEX_URL='^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$'

# Phone number (US format)
readonly REGEX_PHONE_US='^(\+1[-.\s]?)?(\([0-9]{3}\)|[0-9]{3})[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}$'

# Date formats
readonly REGEX_DATE_ISO='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
readonly REGEX_DATE_US='^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
readonly REGEX_DATETIME_ISO='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{3})?Z?$'

# Identifiers and names
readonly REGEX_VARIABLE_NAME='^[a-zA-Z_][a-zA-Z0-9_]*$'
readonly REGEX_FILENAME='^[a-zA-Z0-9._-]+$'
readonly REGEX_SLUG='^[a-z0-9-]+$'

# Version numbers
readonly REGEX_SEMVER='^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$'
readonly REGEX_VERSION_SIMPLE='^[0-9]+(\.[0-9]+)*$'

# Network and system
readonly REGEX_PORT='^([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$'
readonly REGEX_MAC_ADDRESS='^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$'

# Security patterns
readonly REGEX_PASSWORD_STRONG='^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#$%^&*]).{8,}$'
readonly REGEX_API_KEY='^[a-zA-Z0-9_-]{32,}$'
readonly REGEX_UUID='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

# File paths
readonly REGEX_UNIX_PATH='^(/[^/\0]+)*/?$'
readonly REGEX_RELATIVE_PATH='^[^/].*$'
readonly REGEX_ABSOLUTE_PATH='^/.*$'
```

### Validation Functions

```bash
# Generic validation function
validate_format() {
    local input="$1"
    local pattern="$2"
    local description="${3:-input}"

    if [[ "$input" =~ $pattern ]]; then
        return 0
    else
        echo "Error: Invalid $description format: $input" >&2
        return 1
    fi
}

# Specific validation functions
validate_email() {
    validate_format "$1" "$REGEX_EMAIL" "email address"
}

validate_ip() {
    local ip="$1"
    if validate_format "$ip" "$REGEX_IPV4" "IPv4 address" 2>/dev/null; then
        return 0
    elif validate_format "$ip" "$REGEX_IPV6" "IPv6 address" 2>/dev/null; then
        return 0
    else
        echo "Error: Invalid IP address: $ip" >&2
        return 1
    fi
}

validate_url() {
    validate_format "$1" "$REGEX_URL" "URL"
}

validate_version() {
    validate_format "$1" "$REGEX_SEMVER" "version number"
}

# Usage examples
if validate_email "user@example.com"; then
    echo "Valid email"
fi

if validate_ip "192.168.1.1"; then
    echo "Valid IP"
fi
```

---

This comprehensive coding convention guide covers all aspects of modern bash/shell script development, from basic naming conventions to advanced error handling, security considerations, and modern DevOps practices. Following these guidelines will result in maintainable, readable, and robust shell scripts suitable for production environments.
