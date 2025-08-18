# Bash/Shell Script Coding Conventions

## Table of Contents

1. [General Guidelines](#general-guidelines)
2. [File Structure](#file-structure)
3. [Naming Conventions](#naming-conventions)
4. [Variables](#variables)
5. [Functions](#functions)
6. [Exit Codes and Return Values](#exit-codes-and-return-values)
7. [Error Handling](#error-handling)
8. [Formatting and Style](#formatting-and-style)
9. [Comments and Documentation](#comments-and-documentation)
10. [Best Practices](#best-practices)
11. [Security Considerations](#security-considerations)
12. [Testing](#testing)
13. [Example Script](#example-script)

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

**Environment Variables:**

- Use `UPPER_SNAKE_CASE`
- Prefix custom environment variables with your application name

```bash
export MYAPP_CONFIG_DIR="/etc/myapp"
export MYAPP_LOG_LEVEL="INFO"
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

## Variables

### Declaration and Assignment

```bash
# String variables
name="John Doe"
config_file="/etc/app.conf"

# Numeric variables
count=0
max_attempts=5

# Arrays
declare -a file_list=("file1.txt" "file2.txt" "file3.txt")
declare -A config_map=([host]="localhost" [port]="8080")

# Constants
readonly SCRIPT_VERSION="1.2.0"
declare -r LOG_DIR="/var/log"
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

## Functions

### Function Declaration

Use the `function_name()` syntax (preferred) or `function function_name()`:

```bash
# Preferred
check_prerequisites() {
    local dependency="$1"
    # Function body
}

# Alternative
function check_prerequisites() {
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

## Exit Codes and Return Values

### Exit Codes for Scripts

Follow the Linux Standard Base (LSB) exit codes:

```bash
# Success
exit 0

# General errors
exit 1          # General error
exit 2          # Misuse of shell builtins

# Custom application errors
exit 10         # Configuration error
exit 11         # Network error
exit 12         # Database error

# System errors
exit 126        # Command invoked cannot execute
exit 127        # Command not found
exit 128        # Invalid argument to exit
exit 130        # Script terminated by Control-C
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

### Best Practices

```bash
validate_input() {
    local input="$1"

    if [[ -z "$input" ]]; then
        echo "Error: Input cannot be empty" >&2
        return 2    # Invalid argument
    fi

    if [[ ${#input} -lt 3 ]]; then
        echo "Error: Input too short" >&2
        return 1    # Validation failed
    fi

    return 0    # Success
}

# Usage with proper error handling
if ! validate_input "$user_input"; then
    exit 1
fi
```

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

## Best Practices

### Use Shellcheck

Always run your scripts through shellcheck to catch common issues:

```bash
shellcheck your_script.sh
```

### Readonly Variables

Use readonly for constants and configuration:

```bash
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/myapp/config"
```

### Array Handling

```bash
# Declare arrays properly
declare -a files=()
declare -A config=()

# Populate arrays
files=("file1.txt" "file2.txt" "file3.txt")
config=([host]="localhost" [port]="8080")

# Iterate over arrays safely
for file in "${files[@]}"; do
    echo "Processing: $file"
done

# Check if array element exists
if [[ -n "${config[host]:-}" ]]; then
    echo "Host: ${config[host]}"
fi
```

### Command Substitution

Use `$()` instead of backticks:

```bash
# Good
current_date=$(date '+%Y-%m-%d')
file_count=$(find "$directory" -type f | wc -l)

# Bad
current_date=`date '+%Y-%m-%d'`
file_count=`find "$directory" -type f | wc -l`
```

### Process Substitution

```bash
# Compare outputs of two commands
diff <(command1) <(command2)

# Read from command output
while IFS= read -r line; do
    echo "Processing: $line"
done < <(find "$directory" -name "*.txt")
```

## Security Considerations

### Input Validation

```bash
validate_path() {
    local path="$1"

    # Check for path traversal
    if [[ "$path" == *..* ]]; then
        echo "Error: Path traversal detected" >&2
        return 1
    fi

    # Check for absolute paths when expecting relative
    if [[ "$path" == /* ]] && [[ "$ALLOW_ABSOLUTE_PATHS" != "true" ]]; then
        echo "Error: Absolute paths not allowed" >&2
        return 1
    fi

    return 0
}
```

### Safe Temporary Files

```bash
# Create secure temporary directory
TEMP_DIR=$(mktemp -d)
readonly TEMP_DIR

# Ensure cleanup
trap 'rm -rf "$TEMP_DIR"' EXIT

# Create temporary files
temp_file=$(mktemp "$TEMP_DIR/process.XXXXXX")
```

### Avoid Command Injection

```bash
# Bad - vulnerable to injection
eval "ls $user_input"

# Good - safe execution
if [[ "$user_input" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
    ls "$user_input"
else
    echo "Error: Invalid input" >&2
    exit 1
fi
```

## Testing

### Basic Testing Framework

```bash
#!/bin/bash
# test_functions.sh

# Source the script to test
source "./my_script.sh"

# Test counter
tests_run=0
tests_passed=0

# Test function
run_test() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    ((tests_run++))

    if [[ "$actual" == "$expected" ]]; then
        echo "✓ $test_name"
        ((tests_passed++))
    else
        echo "✗ $test_name"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
    fi
}

# Run tests
test_validate_email() {
    validate_email "user@example.com"
    run_test "Valid email" "0" "$?"

    validate_email "invalid-email"
    run_test "Invalid email" "1" "$?"
}

# Execute tests
test_validate_email

# Summary
echo
echo "Tests run: $tests_run"
echo "Tests passed: $tests_passed"
echo "Tests failed: $((tests_run - tests_passed))"

if [[ $tests_passed -eq $tests_run ]]; then
    exit 0
else
    exit 1
fi
```

## Example Script

```bash
#!/bin/bash
#
# Script Name: file_backup.sh
# Description: Create compressed backups with rotation
# Author: DevOps Team <devops@company.com>
# Version: 2.0.0
# Created: 2024-01-15
#
# Usage: ./file_backup.sh [OPTIONS] SOURCE_DIR BACKUP_DIR
#
# Options:
#   -c, --compress      Compression method (gzip|bzip2|xz)
#   -r, --retention N   Keep N backup files
#   -v, --verbose       Enable verbose output
#   -n, --dry-run       Show what would be done
#   -h, --help         Show help message
#
# Exit Codes:
#   0 - Success
#   1 - General error
#   2 - Invalid arguments
#   3 - Missing dependencies
#

set -euo pipefail

#######################################
# Constants
#######################################
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="2.0.0"
readonly DEFAULT_COMPRESSION="gzip"
readonly DEFAULT_RETENTION=7

#######################################
# Global Variables
#######################################
COMPRESSION="$DEFAULT_COMPRESSION"
RETENTION="$DEFAULT_RETENTION"
VERBOSE=false
DRY_RUN=false
SOURCE_DIR=""
BACKUP_DIR=""

#######################################
# Display help message
#######################################
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Create compressed backups with rotation support.

USAGE:
    $SCRIPT_NAME [OPTIONS] SOURCE_DIR BACKUP_DIR

OPTIONS:
    -c, --compress METHOD   Compression method (gzip|bzip2|xz) [default: $DEFAULT_COMPRESSION]
    -r, --retention N       Keep N backup files [default: $DEFAULT_RETENTION]
    -v, --verbose           Enable verbose output
    -n, --dry-run          Show what would be done without executing
    -h, --help             Show this help message

EXAMPLES:
    $SCRIPT_NAME /home/user/documents /backup
    $SCRIPT_NAME -c bzip2 -r 14 /var/www /backup
    $SCRIPT_NAME --verbose --dry-run /etc /backup

EXIT CODES:
    0   Success
    1   General error
    2   Invalid arguments
    3   Missing dependencies
EOF
}

#######################################
# Log message with timestamp
# Arguments:
#   $1 - Log level (INFO, WARN, ERROR)
#   $2 - Message
#######################################
log_message() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        ERROR)
            echo "[$timestamp] [$level] $message" >&2
            ;;
        *)
            echo "[$timestamp] [$level] $message"
            ;;
    esac
}

#######################################
# Check if required commands are available
# Returns:
#   0 - All dependencies available
#   3 - Missing dependencies
#######################################
check_dependencies() {
    local missing_deps=()
    local required_commands=("tar" "find" "sort")

    # Add compression-specific commands
    case "$COMPRESSION" in
        gzip)
            required_commands+=("gzip")
            ;;
        bzip2)
            required_commands+=("bzip2")
            ;;
        xz)
            required_commands+=("xz")
            ;;
    esac

    # Check each required command
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_message "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        return 3
    fi

    return 0
}

#######################################
# Validate input arguments
# Returns:
#   0 - Valid arguments
#   2 - Invalid arguments
#######################################
validate_arguments() {
    # Check source directory
    if [[ ! -d "$SOURCE_DIR" ]]; then
        log_message "ERROR" "Source directory does not exist: $SOURCE_DIR"
        return 2
    fi

    if [[ ! -r "$SOURCE_DIR" ]]; then
        log_message "ERROR" "Source directory is not readable: $SOURCE_DIR"
        return 2
    fi

    # Check backup directory
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_message "INFO" "Creating backup directory: $BACKUP_DIR"
        if ! mkdir -p "$BACKUP_DIR"; then
            log_message "ERROR" "Failed to create backup directory: $BACKUP_DIR"
            return 2
        fi
    fi

    if [[ ! -w "$BACKUP_DIR" ]]; then
        log_message "ERROR" "Backup directory is not writable: $BACKUP_DIR"
        return 2
    fi

    # Validate compression method
    case "$COMPRESSION" in
        gzip|bzip2|xz)
            ;;
        *)
            log_message "ERROR" "Invalid compression method: $COMPRESSION"
            return 2
            ;;
    esac

    # Validate retention count
    if ! [[ "$RETENTION" =~ ^[0-9]+$ ]] || [[ "$RETENTION" -lt 1 ]]; then
        log_message "ERROR" "Retention must be a positive number: $RETENTION"
        return 2
    fi

    return 0
}

#######################################
# Create backup archive
# Returns:
#   0 - Backup created successfully
#   1 - Backup failed
#######################################
create_backup() {
    local source_name
    local timestamp
    local backup_filename
    local backup_path
    local tar_compression_flag
    local file_extension

    source_name=$(basename "$SOURCE_DIR")
    timestamp=$(date '+%Y%m%d_%H%M%S')

    # Set compression options
    case "$COMPRESSION" in
        gzip)
            tar_compression_flag="z"
            file_extension="tar.gz"
            ;;
        bzip2)
            tar_compression_flag="j"
            file_extension="tar.bz2"
            ;;
        xz)
            tar_compression_flag="J"
            file_extension="tar.xz"
            ;;
    esac

    backup_filename="${source_name}_${timestamp}.${file_extension}"
    backup_path="$BACKUP_DIR/$backup_filename"

    log_message "INFO" "Creating backup: $backup_filename"
    log_message "INFO" "Source: $SOURCE_DIR"
    log_message "INFO" "Destination: $backup_path"
    log_message "INFO" "Compression: $COMPRESSION"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_message "INFO" "DRY RUN: Would create backup at $backup_path"
        return 0
    fi

    # Create the backup
    local tar_options="-c${tar_compression_flag}f"
    if [[ "$VERBOSE" == "true" ]]; then
        tar_options="${tar_options}v"
    fi

    if tar $tar_options "$backup_path" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"; then
        local backup_size
        backup_size=$(du -h "$backup_path" | cut -f1)
        log_message "INFO" "Backup created successfully: $backup_filename ($backup_size)"
        return 0
    else
        log_message "ERROR" "Failed to create backup"
        return 1
    fi
}

#######################################
# Remove old backups based on retention policy
# Returns:
#   0 - Cleanup completed
#   1 - Cleanup failed
#######################################
cleanup_old_backups() {
    local source_name
    local pattern
    local old_backups
    local removed_count=0

    source_name=$(basename "$SOURCE_DIR")
    pattern="${source_name}_[0-9]*_[0-9]*"

    log_message "INFO" "Cleaning up old backups (retention: $RETENTION)"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_message "INFO" "DRY RUN: Would remove old backups matching pattern: $pattern"
        return 0
    fi

    # Find and sort backups by modification time (oldest first)
    mapfile -t old_backups < <(find "$BACKUP_DIR" -maxdepth 1 -name "${pattern}.*" -type f -printf '%T@ %p\n' | sort -n | head -n -"$RETENTION" | cut -d' ' -f2-)

    # Remove old backups
    for backup in "${old_backups[@]}"; do
        if [[ -n "$backup" ]] && rm -f "$backup"; then
            log_message "INFO" "Removed old backup: $(basename "$backup")"
            ((removed_count++))
        else
            log_message "WARN" "Failed to remove old backup: $(basename "$backup")"
        fi
    done

    if [[ $removed_count -gt 0 ]]; then
        log_message "INFO" "Removed $removed_count old backup(s)"
    else
        log_message "INFO" "No old backups to remove"
    fi

    return 0
}

#######################################
# Parse command line arguments
# Arguments:
#   All command line arguments
# Returns:
#   0 - Arguments parsed successfully
#   2 - Invalid arguments
#######################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--compress)
                if [[ -z "${2:-}" ]]; then
                    log_message "ERROR" "Compression method required for $1"
                    return 2
                fi
                COMPRESSION="$2"
                shift 2
                ;;
            -r|--retention)
                if [[ -z "${2:-}" ]]; then
                    log_message "ERROR" "Retention count required for $1"
                    return 2
                fi
                RETENTION="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_message "ERROR" "Unknown option: $1"
                show_help
                return 2
                ;;
            *)
                if [[ -z "$SOURCE_DIR" ]]; then
                    SOURCE_DIR="$1"
                elif [[ -z "$BACKUP_DIR" ]]; then
                    BACKUP_DIR="$1"
                else
                    log_message "ERROR" "Too many arguments: $1"
                    show_help
                    return 2
                fi
                shift
                ;;
        esac
    done

    # Check required arguments
    if [[ -z "$SOURCE_DIR" ]]; then
        log_message "ERROR" "Source directory is required"
        show_help
        return 2
    fi

    if [[ -z "$BACKUP_DIR" ]]; then
        log_message "ERROR" "Backup directory is required"
        show_help
        return 2
    fi

    return 0
}

#######################################
# Main function
# Arguments:
#   All command line arguments
#######################################
main() {
    log_message "INFO" "$SCRIPT_NAME v$SCRIPT_VERSION started"

    # Parse command line arguments
    if ! parse_arguments "$@"; then
        exit 2
    fi

    # Show configuration if verbose
    if [[ "$VERBOSE" == "true" ]]; then
        log_message "INFO" "Configuration:"
        log_message "INFO" "  Source: $SOURCE_DIR"
        log_message "INFO" "  Backup: $BACKUP_DIR"
        log_message "INFO" "  Compression: $COMPRESSION"
        log_message "INFO" "  Retention: $RETENTION"
        log_message "INFO" "  Dry run: $DRY_RUN"
    fi

    # Check dependencies
    if ! check_dependencies; then
        exit 3
    fi

    # Validate arguments
    if ! validate_arguments; then
        exit 2
    fi

    # Create backup
    if ! create_backup; then
        log_message "ERROR" "Backup creation failed"
        exit 1
    fi

    # Cleanup old backups
    if ! cleanup_old_backups; then
        log_message "WARN" "Backup cleanup failed, but backup was created successfully"
    fi

    log_message "INFO" "$SCRIPT_NAME completed successfully"
    exit 0
}

# Script entry point
main "$@"
```

This comprehensive coding convention guide covers all aspects of bash/shell script development, from basic naming conventions to advanced error handling and security considerations. Following these guidelines will result in maintainable, readable, and robust shell scripts.
