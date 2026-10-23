# Exit Codes and Return Values Constants for Bash/Shell

## Overview

This document defines standard exit codes and return values for bash/shell scripts. It follows the POSIX standard and includes reserved codes for common error scenarios.

## Standard Exit Code Constants

### System Exit Codes (0-2)

```bash
# Standard POSIX exit codes
readonly EXIT_SUCCESS=0                    # Successful termination
readonly EXIT_FAILURE=1                    # General error
readonly EXIT_INVALID_USAGE=2              # Misuse of shell builtins/invalid arguments
```

### Reserved System Exit Codes (125-255)

```bash
# Shell reserved exit codes
readonly EXIT_COMMAND_NOT_EXECUTABLE=126   # Command invoked cannot execute
readonly EXIT_COMMAND_NOT_FOUND=127        # Command not found
readonly EXIT_INVALID_EXIT_ARG=128         # Invalid argument to exit
readonly EXIT_FATAL_SIGNAL_BASE=128        # Base for signals (128 + signal number)
readonly EXIT_CTRL_C=130                   # Script terminated by Control-C (SIGINT)
readonly EXIT_OUT_OF_RANGE=255             # Exit status out of range
```

### Application-Specific Exit Codes (3-124)

```bash
# Configuration and setup errors (3-9)
readonly EXIT_CONFIG_ERROR=3               # Configuration file error
readonly EXIT_MISSING_DEPENDENCY=4         # Required dependency not found
readonly EXIT_PERMISSION_DENIED=5          # Insufficient permissions
readonly EXIT_INVALID_CONFIG=6             # Invalid configuration values
readonly EXIT_CONFIG_NOT_FOUND=7           # Configuration file not found
readonly EXIT_INITIALIZATION_FAILED=8      # Application initialization failed
readonly EXIT_ENVIRONMENT_ERROR=9          # Environment setup error

# Input/Output errors (10-19)
readonly EXIT_FILE_NOT_FOUND=10            # Required file not found
readonly EXIT_DIRECTORY_NOT_FOUND=11       # Required directory not found
readonly EXIT_FILE_READ_ERROR=12           # Cannot read file
readonly EXIT_FILE_WRITE_ERROR=13          # Cannot write file
readonly EXIT_DISK_FULL=14                 # No space left on device
readonly EXIT_IO_ERROR=15                  # General I/O error
readonly EXIT_FILE_EXISTS=16               # File already exists (when shouldn't)
readonly EXIT_INVALID_PATH=17              # Invalid file/directory path
readonly EXIT_SYMLINK_ERROR=18             # Symbolic link error
readonly EXIT_MOUNT_ERROR=19               # Mount/unmount error

# Network errors (20-29)
readonly EXIT_NETWORK_ERROR=20             # General network error
readonly EXIT_CONNECTION_FAILED=21         # Cannot connect to remote host
readonly EXIT_CONNECTION_TIMEOUT=22        # Connection timeout
readonly EXIT_DNS_ERROR=23                 # DNS resolution error
readonly EXIT_DOWNLOAD_FAILED=24           # Download/upload failed
readonly EXIT_SSL_ERROR=25                 # SSL/TLS error
readonly EXIT_AUTHENTICATION_FAILED=26     # Network authentication failed
readonly EXIT_PROXY_ERROR=27               # Proxy configuration error
readonly EXIT_FIREWALL_BLOCKED=28          # Firewall blocking connection
readonly EXIT_NETWORK_UNREACHABLE=29       # Network unreachable

# Database errors (30-39)
readonly EXIT_DATABASE_ERROR=30            # General database error
readonly EXIT_DATABASE_CONNECTION_FAILED=31 # Cannot connect to database
readonly EXIT_DATABASE_QUERY_FAILED=32     # Database query failed
readonly EXIT_DATABASE_SCHEMA_ERROR=33     # Database schema error
readonly EXIT_DATABASE_LOCK_ERROR=34       # Database lock/deadlock error
readonly EXIT_DATABASE_TIMEOUT=35          # Database operation timeout
readonly EXIT_DATABASE_PERMISSION=36       # Database permission denied
readonly EXIT_DATABASE_NOT_FOUND=37        # Database/table not found
readonly EXIT_DATABASE_CORRUPTION=38       # Database corruption detected
readonly EXIT_DATABASE_MIGRATION_FAILED=39 # Database migration failed

# Service and process errors (40-49)
readonly EXIT_SERVICE_ERROR=40             # General service error
readonly EXIT_SERVICE_NOT_RUNNING=41       # Required service not running
readonly EXIT_SERVICE_START_FAILED=42      # Failed to start service
readonly EXIT_SERVICE_STOP_FAILED=43       # Failed to stop service
readonly EXIT_PROCESS_NOT_FOUND=44         # Required process not found
readonly EXIT_PROCESS_KILL_FAILED=45       # Failed to kill process
readonly EXIT_DAEMON_ERROR=46              # Daemon operation error
readonly EXIT_LOCK_FILE_EXISTS=47          # Lock file exists (already running)
readonly EXIT_PID_FILE_ERROR=48            # PID file error
readonly EXIT_SERVICE_TIMEOUT=49           # Service operation timeout

# Validation and data errors (50-59)
readonly EXIT_VALIDATION_ERROR=50          # Input validation failed
readonly EXIT_DATA_FORMAT_ERROR=51         # Invalid data format
readonly EXIT_CHECKSUM_MISMATCH=52         # Checksum verification failed
readonly EXIT_DATA_CORRUPTION=53           # Data corruption detected
readonly EXIT_PARSE_ERROR=54               # Parsing error
readonly EXIT_ENCODING_ERROR=55            # Character encoding error
readonly EXIT_JSON_ERROR=56                # JSON parsing/validation error
readonly EXIT_XML_ERROR=57                 # XML parsing/validation error
readonly EXIT_CSV_ERROR=58                 # CSV parsing/validation error
readonly EXIT_REGEX_ERROR=59               # Regular expression error

# Security errors (60-69)
readonly EXIT_SECURITY_ERROR=60            # General security error
readonly EXIT_UNAUTHORIZED=61              # Unauthorized access
readonly EXIT_FORBIDDEN=63                 # Access forbidden
readonly EXIT_AUTHENTICATION_ERROR=64      # Authentication failed
readonly EXIT_CERTIFICATE_ERROR=65         # Certificate validation failed
readonly EXIT_ENCRYPTION_ERROR=66          # Encryption/decryption failed
readonly EXIT_SIGNATURE_ERROR=67           # Digital signature error
readonly EXIT_PRIVILEGE_ESCALATION=68      # Privilege escalation failed
readonly EXIT_SECURITY_POLICY_VIOLATION=69 # Security policy violation

# Resource errors (70-79)
readonly EXIT_RESOURCE_ERROR=70            # General resource error
readonly EXIT_MEMORY_ERROR=71              # Out of memory
readonly EXIT_CPU_LIMIT_EXCEEDED=72        # CPU limit exceeded
readonly EXIT_TIME_LIMIT_EXCEEDED=73       # Time limit exceeded
readonly EXIT_FILE_LIMIT_EXCEEDED=74       # File descriptor limit exceeded
readonly EXIT_QUOTA_EXCEEDED=75            # Disk quota exceeded
readonly EXIT_RESOURCE_BUSY=76             # Resource busy/locked
readonly EXIT_RESOURCE_UNAVAILABLE=77      # Resource temporarily unavailable
readonly EXIT_INSUFFICIENT_RESOURCES=78    # Insufficient resources
readonly EXIT_RESOURCE_CLEANUP_FAILED=79   # Resource cleanup failed

# Backup and restore errors (80-89)
readonly EXIT_BACKUP_ERROR=80              # General backup error
readonly EXIT_BACKUP_FAILED=81             # Backup operation failed
readonly EXIT_RESTORE_FAILED=82            # Restore operation failed
readonly EXIT_ARCHIVE_ERROR=83             # Archive creation/extraction error
readonly EXIT_COMPRESSION_ERROR=84         # Compression/decompression error
readonly EXIT_BACKUP_VERIFICATION_FAILED=85 # Backup verification failed
readonly EXIT_BACKUP_CORRUPTION=86         # Backup file corruption
readonly EXIT_BACKUP_NOT_FOUND=87          # Backup file not found
readonly EXIT_BACKUP_INCOMPLETE=88         # Backup incomplete
readonly EXIT_RESTORE_VERIFICATION_FAILED=89 # Restore verification failed

# External tool errors (90-99)
readonly EXIT_EXTERNAL_TOOL_ERROR=90       # External tool error
readonly EXIT_COMPILER_ERROR=91            # Compilation failed
readonly EXIT_LINTER_ERROR=92              # Code linting failed
readonly EXIT_TEST_FAILED=93               # Tests failed
readonly EXIT_BUILD_FAILED=94              # Build process failed
readonly EXIT_DEPLOYMENT_FAILED=95         # Deployment failed
readonly EXIT_PACKAGE_ERROR=96             # Package management error
readonly EXIT_VERSION_MISMATCH=97          # Version compatibility error
readonly EXIT_LICENSE_ERROR=98             # License validation error
readonly EXIT_EXTERNAL_API_ERROR=99        # External API error

# User and system errors (100-109)
readonly EXIT_USER_ERROR=100               # User-related error
readonly EXIT_USER_NOT_FOUND=101           # User does not exist
readonly EXIT_GROUP_NOT_FOUND=102          # Group does not exist
readonly EXIT_USER_EXISTS=103              # User already exists
readonly EXIT_PASSWORD_ERROR=104           # Password validation error
readonly EXIT_SESSION_ERROR=105            # Session management error
readonly EXIT_ACCOUNT_LOCKED=106           # User account locked
readonly EXIT_ACCOUNT_EXPIRED=107          # User account expired
readonly EXIT_SUDO_REQUIRED=108            # Root/sudo privileges required
readonly EXIT_SYSTEM_ERROR=109             # System-level error

# Application logic errors (110-124)
readonly EXIT_LOGIC_ERROR=110              # Application logic error
readonly EXIT_STATE_ERROR=111              # Invalid application state
readonly EXIT_WORKFLOW_ERROR=112           # Workflow execution error
readonly EXIT_TRANSACTION_FAILED=113       # Transaction failed
readonly EXIT_ROLLBACK_FAILED=114          # Rollback operation failed
readonly EXIT_SYNC_ERROR=115               # Synchronization error
readonly EXIT_CONFLICT_DETECTED=116        # Data/resource conflict
readonly EXIT_DEPENDENCY_CYCLE=117         # Circular dependency detected
readonly EXIT_VERSION_CONFLICT=118         # Version conflict
readonly EXIT_FEATURE_NOT_SUPPORTED=119    # Feature not supported
readonly EXIT_DEPRECATED_USAGE=120         # Deprecated feature used
readonly EXIT_EXPERIMENTAL_FEATURE=121     # Experimental feature error
readonly EXIT_MAINTENANCE_MODE=122         # System in maintenance mode
readonly EXIT_RATE_LIMIT_EXCEEDED=123      # Rate limit exceeded
readonly EXIT_QUOTA_LIMIT_EXCEEDED=124     # Quota limit exceeded
```

## Function Return Value Constants

### Standard Return Values

```bash
# Basic success/failure
readonly RETURN_SUCCESS=0                  # Function succeeded
readonly RETURN_FAILURE=1                  # Function failed
readonly RETURN_INVALID_ARGS=2             # Invalid function arguments
readonly RETURN_NOT_IMPLEMENTED=3          # Function not implemented
readonly RETURN_NOT_SUPPORTED=4            # Operation not supported
```

### Validation Return Values

```bash
# Input validation results
readonly RETURN_VALID=0                    # Input is valid
readonly RETURN_INVALID=1                  # Input is invalid
readonly RETURN_EMPTY=2                    # Input is empty
readonly RETURN_TOO_SHORT=3                # Input too short
readonly RETURN_TOO_LONG=4                 # Input too long
readonly RETURN_INVALID_FORMAT=5           # Invalid format
readonly RETURN_INVALID_RANGE=6            # Value out of range
readonly RETURN_INVALID_TYPE=7             # Invalid data type
```

### Resource Check Return Values

```bash
# Resource availability checks
readonly RETURN_AVAILABLE=0                # Resource is available
readonly RETURN_NOT_FOUND=1                # Resource not found
readonly RETURN_EXISTS=2                   # Resource already exists
readonly RETURN_BUSY=3                     # Resource is busy
readonly RETURN_LOCKED=4                   # Resource is locked
readonly RETURN_PERMISSION_DENIED=5        # Access denied
readonly RETURN_CORRUPTED=6                # Resource is corrupted
readonly RETURN_EXPIRED=7                  # Resource has expired
```

### Operation Status Return Values

```bash
# Operation results
readonly RETURN_COMPLETED=0                # Operation completed
readonly RETURN_PARTIAL=1                  # Partially completed
readonly RETURN_SKIPPED=2                  # Operation skipped
readonly RETURN_CANCELLED=3                # Operation cancelled
readonly RETURN_TIMEOUT=4                  # Operation timed out
readonly RETURN_RETRY_NEEDED=5             # Operation should be retried
readonly RETURN_PERMANENT_FAILURE=6        # Permanent failure, don't retry
readonly RETURN_TEMPORARY_FAILURE=7        # Temporary failure, retry later
```

## Usage Examples

### Using Exit Code Constants

```bash
#!/bin/bash
set -euo pipefail

# Include exit code constants
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1
readonly EXIT_INVALID_USAGE=2
readonly EXIT_CONFIG_ERROR=3
readonly EXIT_MISSING_DEPENDENCY=4
readonly EXIT_FILE_NOT_FOUND=10
readonly EXIT_NETWORK_ERROR=20

check_config_file() {
    local config_file="$1"

    if [[ -z "$config_file" ]]; then
        echo "Error: Configuration file path required" >&2
        return $EXIT_INVALID_USAGE
    fi

    if [[ ! -f "$config_file" ]]; then
        echo "Error: Configuration file not found: $config_file" >&2
        return $EXIT_FILE_NOT_FOUND
    fi

    if [[ ! -r "$config_file" ]]; then
        echo "Error: Cannot read configuration file: $config_file" >&2
        return $EXIT_CONFIG_ERROR
    fi

    return $EXIT_SUCCESS
}

main() {
    local config_file="${1:-}"

    # Check configuration
    if ! check_config_file "$config_file"; then
        exit $EXIT_CONFIG_ERROR
    fi

    # Check dependencies
    if ! command -v curl >/dev/null 2>&1; then
        echo "Error: curl is required but not installed" >&2
        exit $EXIT_MISSING_DEPENDENCY
    fi

    # Perform network operation
    if ! curl -s "https://api.example.com/status" >/dev/null; then
        echo "Error: Cannot connect to API" >&2
        exit $EXIT_NETWORK_ERROR
    fi

    echo "All checks passed"
    exit $EXIT_SUCCESS
}

main "$@"
```

### Using Function Return Constants

```bash
#!/bin/bash
set -euo pipefail

# Function return value constants
readonly RETURN_SUCCESS=0
readonly RETURN_FAILURE=1
readonly RETURN_INVALID_ARGS=2
readonly RETURN_NOT_FOUND=1
readonly RETURN_EXISTS=2
readonly RETURN_VALID=0
readonly RETURN_INVALID=1
readonly RETURN_EMPTY=2

validate_email() {
    local email="$1"
    local pattern="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"

    # Check if email is provided
    if [[ -z "$email" ]]; then
        return $RETURN_EMPTY
    fi

    # Validate email format
    if [[ "$email" =~ $pattern ]]; then
        return $RETURN_VALID
    else
        return $RETURN_INVALID
    fi
}

check_user_exists() {
    local username="$1"

    if [[ -z "$username" ]]; then
        return $RETURN_INVALID_ARGS
    fi

    if id "$username" >/dev/null 2>&1; then
        return $RETURN_EXISTS
    else
        return $RETURN_NOT_FOUND
    fi
}

# Usage examples
case $(validate_email "$user_email") in
    $RETURN_VALID)
        echo "Valid email address"
        ;;
    $RETURN_INVALID)
        echo "Invalid email format" >&2
        exit $EXIT_VALIDATION_ERROR
        ;;
    $RETURN_EMPTY)
        echo "Email address is required" >&2
        exit $EXIT_INVALID_USAGE
        ;;
esac

case $(check_user_exists "$username") in
    $RETURN_EXISTS)
        echo "User already exists: $username"
        ;;
    $RETURN_NOT_FOUND)
        echo "Creating new user: $username"
        ;;
    $RETURN_INVALID_ARGS)
        echo "Invalid username provided" >&2
        exit $EXIT_INVALID_USAGE
        ;;
esac
```

### Complete Constants Header Template

```bash
#!/bin/bash
#
# Exit Code and Return Value Constants
# Include this section at the top of your scripts
#

set -euo pipefail

#######################################
# Standard Exit Codes
#######################################
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1
readonly EXIT_INVALID_USAGE=2

#######################################
# Application Exit Codes (3-124)
#######################################
# Configuration errors (3-9)
readonly EXIT_CONFIG_ERROR=3
readonly EXIT_MISSING_DEPENDENCY=4
readonly EXIT_PERMISSION_DENIED=5
readonly EXIT_INVALID_CONFIG=6
readonly EXIT_CONFIG_NOT_FOUND=7
readonly EXIT_INITIALIZATION_FAILED=8
readonly EXIT_ENVIRONMENT_ERROR=9

# File/Directory errors (10-19)
readonly EXIT_FILE_NOT_FOUND=10
readonly EXIT_DIRECTORY_NOT_FOUND=11
readonly EXIT_FILE_READ_ERROR=12
readonly EXIT_FILE_WRITE_ERROR=13
readonly EXIT_DISK_FULL=14
readonly EXIT_IO_ERROR=15
readonly EXIT_FILE_EXISTS=16
readonly EXIT_INVALID_PATH=17
readonly EXIT_SYMLINK_ERROR=18
readonly EXIT_MOUNT_ERROR=19

# Network errors (20-29)
readonly EXIT_NETWORK_ERROR=20
readonly EXIT_CONNECTION_FAILED=21
readonly EXIT_CONNECTION_TIMEOUT=22
readonly EXIT_DNS_ERROR=23
readonly EXIT_DOWNLOAD_FAILED=24
readonly EXIT_SSL_ERROR=25
readonly EXIT_AUTHENTICATION_FAILED=26
readonly EXIT_PROXY_ERROR=27
readonly EXIT_FIREWALL_BLOCKED=28
readonly EXIT_NETWORK_UNREACHABLE=29

# Database errors (30-39)
readonly EXIT_DATABASE_ERROR=30
readonly EXIT_DATABASE_CONNECTION_FAILED=31
readonly EXIT_DATABASE_QUERY_FAILED=32
readonly EXIT_DATABASE_SCHEMA_ERROR=33
readonly EXIT_DATABASE_LOCK_ERROR=34
readonly EXIT_DATABASE_TIMEOUT=35
readonly EXIT_DATABASE_PERMISSION=36
readonly EXIT_DATABASE_NOT_FOUND=37
readonly EXIT_DATABASE_CORRUPTION=38
readonly EXIT_DATABASE_MIGRATION_FAILED=39

# Service errors (40-49)
readonly EXIT_SERVICE_ERROR=40
readonly EXIT_SERVICE_NOT_RUNNING=41
readonly EXIT_SERVICE_START_FAILED=42
readonly EXIT_SERVICE_STOP_FAILED=43
readonly EXIT_PROCESS_NOT_FOUND=44
readonly EXIT_PROCESS_KILL_FAILED=45
readonly EXIT_DAEMON_ERROR=46
readonly EXIT_LOCK_FILE_EXISTS=47
readonly EXIT_PID_FILE_ERROR=48
readonly EXIT_SERVICE_TIMEOUT=49

# Validation errors (50-59)
readonly EXIT_VALIDATION_ERROR=50
readonly EXIT_DATA_FORMAT_ERROR=51
readonly EXIT_CHECKSUM_MISMATCH=52
readonly EXIT_DATA_CORRUPTION=53
readonly EXIT_PARSE_ERROR=54
readonly EXIT_ENCODING_ERROR=55
readonly EXIT_JSON_ERROR=56
readonly EXIT_XML_ERROR=57
readonly EXIT_CSV_ERROR=58
readonly EXIT_REGEX_ERROR=59

# Security errors (60-69)
readonly EXIT_SECURITY_ERROR=60
readonly EXIT_UNAUTHORIZED=61
readonly EXIT_FORBIDDEN=63
readonly EXIT_AUTHENTICATION_ERROR=64
readonly EXIT_CERTIFICATE_ERROR=65
readonly EXIT_ENCRYPTION_ERROR=66
readonly EXIT_SIGNATURE_ERROR=67
readonly EXIT_PRIVILEGE_ESCALATION=68
readonly EXIT_SECURITY_POLICY_VIOLATION=69

# Resource errors (70-79)
readonly EXIT_RESOURCE_ERROR=70
readonly EXIT_MEMORY_ERROR=71
readonly EXIT_CPU_LIMIT_EXCEEDED=72
readonly EXIT_TIME_LIMIT_EXCEEDED=73
readonly EXIT_FILE_LIMIT_EXCEEDED=74
readonly EXIT_QUOTA_EXCEEDED=75
readonly EXIT_RESOURCE_BUSY=76
readonly EXIT_RESOURCE_UNAVAILABLE=77
readonly EXIT_INSUFFICIENT_RESOURCES=78
readonly EXIT_RESOURCE_CLEANUP_FAILED=79

# Backup/Archive errors (80-89)
readonly EXIT_BACKUP_ERROR=80
readonly EXIT_BACKUP_FAILED=81
readonly EXIT_RESTORE_FAILED=82
readonly EXIT_ARCHIVE_ERROR=83
readonly EXIT_COMPRESSION_ERROR=84
readonly EXIT_BACKUP_VERIFICATION_FAILED=85
readonly EXIT_BACKUP_CORRUPTION=86
readonly EXIT_BACKUP_NOT_FOUND=87
readonly EXIT_BACKUP_INCOMPLETE=88
readonly EXIT_RESTORE_VERIFICATION_FAILED=89

# External tool errors (90-99)
readonly EXIT_EXTERNAL_TOOL_ERROR=90
readonly EXIT_COMPILER_ERROR=91
readonly EXIT_LINTER_ERROR=92
readonly EXIT_TEST_FAILED=93
readonly EXIT_BUILD_FAILED=94
readonly EXIT_DEPLOYMENT_FAILED=95
readonly EXIT_PACKAGE_ERROR=96
readonly EXIT_VERSION_MISMATCH=97
readonly EXIT_LICENSE_ERROR=98
readonly EXIT_EXTERNAL_API_ERROR=99

# User/System errors (100-109)
readonly EXIT_USER_ERROR=100
readonly EXIT_USER_NOT_FOUND=101
readonly EXIT_GROUP_NOT_FOUND=102
readonly EXIT_USER_EXISTS=103
readonly EXIT_PASSWORD_ERROR=104
readonly EXIT_SESSION_ERROR=105
readonly EXIT_ACCOUNT_LOCKED=106
readonly EXIT_ACCOUNT_EXPIRED=107
readonly EXIT_SUDO_REQUIRED=108
readonly EXIT_SYSTEM_ERROR=109

# Application logic errors (110-124)
readonly EXIT_LOGIC_ERROR=110
readonly EXIT_STATE_ERROR=111
readonly EXIT_WORKFLOW_ERROR=112
readonly EXIT_TRANSACTION_FAILED=113
readonly EXIT_ROLLBACK_FAILED=114
readonly EXIT_SYNC_ERROR=115
readonly EXIT_CONFLICT_DETECTED=116
readonly EXIT_DEPENDENCY_CYCLE=117
readonly EXIT_VERSION_CONFLICT=118
readonly EXIT_FEATURE_NOT_SUPPORTED=119
readonly EXIT_DEPRECATED_USAGE=120
readonly EXIT_EXPERIMENTAL_FEATURE=121
readonly EXIT_MAINTENANCE_MODE=122
readonly EXIT_RATE_LIMIT_EXCEEDED=123
readonly EXIT_QUOTA_LIMIT_EXCEEDED=124

#######################################
# System Reserved Exit Codes (125-255)
#######################################
readonly EXIT_COMMAND_NOT_EXECUTABLE=126
readonly EXIT_COMMAND_NOT_FOUND=127
readonly EXIT_INVALID_EXIT_ARG=128
readonly EXIT_FATAL_SIGNAL_BASE=128
readonly EXIT_CTRL_C=130
readonly EXIT_OUT_OF_RANGE=255

#######################################
# Function Return Value Constants
#######################################
# Basic return values
readonly RETURN_SUCCESS=0
readonly RETURN_FAILURE=1
readonly RETURN_INVALID_ARGS=2
readonly RETURN_NOT_IMPLEMENTED=3
readonly RETURN_NOT_SUPPORTED=4

# Validation return values
readonly RETURN_VALID=0
readonly RETURN_INVALID=1
readonly RETURN_EMPTY=2
readonly RETURN_TOO_SHORT=3
readonly RETURN_TOO_LONG=4
readonly RETURN_INVALID_FORMAT=5
readonly RETURN_INVALID_RANGE=6
readonly RETURN_INVALID_TYPE=7

# Resource return values
readonly RETURN_AVAILABLE=0
readonly RETURN_NOT_FOUND=1
readonly RETURN_EXISTS=2
readonly RETURN_BUSY=3
readonly RETURN_LOCKED=4
readonly RETURN_PERMISSION_DENIED=5
readonly RETURN_CORRUPTED=6
readonly RETURN_EXPIRED=7

# Operation return values
readonly RETURN_COMPLETED=0
readonly RETURN_PARTIAL=1
readonly RETURN_SKIPPED=2
readonly RETURN_CANCELLED=3
readonly RETURN_TIMEOUT=4
readonly RETURN_RETRY_NEEDED=5
readonly RETURN_PERMANENT_FAILURE=6
readonly RETURN_TEMPORARY_FAILURE=7
```

### Signal-Based Exit Codes

```bash
# Signal exit codes (128 + signal number)
readonly EXIT_SIGHUP=$((128 + 1))          # 129 - Hangup
readonly EXIT_SIGINT=$((128 + 2))          # 130 - Interrupt (Ctrl+C)
readonly EXIT_SIGQUIT=$((128 + 3))         # 131 - Quit
readonly EXIT_SIGILL=$((128 + 4))          # 132 - Illegal instruction
readonly EXIT_SIGTRAP=$((128 + 5))         # 133 - Trace/breakpoint trap
readonly EXIT_SIGABRT=$((128 + 6))         # 134 - Abort
readonly EXIT_SIGBUS=$((128 + 7))          # 135 - Bus error
readonly EXIT_SIGFPE=$((128 + 8))          # 136 - Floating point exception
readonly EXIT_SIGKILL=$((128 + 9))         # 137 - Kill (cannot be caught)
readonly EXIT_SIGUSR1=$((128 + 10))        # 138 - User signal 1
readonly EXIT_SIGSEGV=$((128 + 11))        # 139 - Segmentation violation
readonly EXIT_SIGUSR2=$((128 + 12))        # 140 - User signal 2
readonly EXIT_SIGPIPE=$((128 + 13))        # 141 - Broken pipe
readonly EXIT_SIGALRM=$((128 + 14))        # 142 - Alarm clock
readonly EXIT_SIGTERM=$((128 + 15))        # 143 - Termination
readonly EXIT_SIGCHLD=$((128 + 17))        # 145 - Child status changed
readonly EXIT_SIGCONT=$((128 + 18))        # 146 - Continue
readonly EXIT_SIGSTOP=$((128 + 19))        # 147 - Stop (cannot be caught)
readonly EXIT_SIGTSTP=$((128 + 20))        # 148 - Keyboard stop (Ctrl+Z)
```

### Practical Usage Functions

```bash
#######################################
# Exit with appropriate code and message
# Arguments:
#   $1 - Exit code constant
#   $2 - Error message (optional)
#######################################
die() {
    local exit_code="$1"
    local message="${2:-}"

    if [[ -n "$message" ]]; then
        echo "$message" >&2
    fi

    exit "$exit_code"
}

#######################################
# Check command availability
# Arguments:
#   $1 - Command name
# Returns:
#   EXIT_SUCCESS if available
#   EXIT_MISSING_DEPENDENCY if not found
#######################################
require_command() {
    local cmd="$1"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "$EXIT_MISSING_DEPENDENCY" "Error: Required command not found: $cmd"
    fi
}

#######################################
# Validate file exists and is readable
# Arguments:
#   $1 - File path
# Returns:
#   RETURN_SUCCESS if valid
#   RETURN_NOT_FOUND if file doesn't exist
#   RETURN_PERMISSION_DENIED if not readable
#######################################
validate_readable_file() {
    local file_path="$1"

    if [[ ! -e "$file_path" ]]; then
        return $RETURN_NOT_FOUND
    fi

    if [[ ! -r "$file_path" ]]; then
        return $RETURN_PERMISSION_DENIED
    fi

    return $RETURN_SUCCESS
}

# Usage examples
require_command "git"
require_command "docker"

case $(validate_readable_file "$config_file") in
    $RETURN_SUCCESS)
        echo "Configuration file is valid"
        ;;
    $RETURN_NOT_FOUND)
        die "$EXIT_CONFIG_NOT_FOUND" "Configuration file not found: $config_file"
        ;;
    $RETURN_PERMISSION_DENIED)
        die "$EXIT_PERMISSION_DENIED" "Cannot read configuration file: $config_file"
        ;;
esac
```

### Constants File for Reuse

```bash
# constants.sh - Shared constants file
#!/bin/bash
#
# Shared exit codes and return values for all scripts
# Source this file in other scripts: source ./constants.sh
#

# Prevent multiple inclusions
if [[ -n "${_CONSTANTS_LOADED:-}" ]]; then
    return 0
fi
readonly _CONSTANTS_LOADED=true

# Standard exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1
readonly EXIT_INVALID_USAGE=2

# Application exit codes (add your specific codes here)
readonly EXIT_CONFIG_ERROR=3
readonly EXIT_MISSING_DEPENDENCY=4
readonly EXIT_PERMISSION_DENIED=5
readonly EXIT_FILE_NOT_FOUND=10
readonly EXIT_NETWORK_ERROR=20
readonly EXIT_DATABASE_ERROR=30

# Function return values
readonly RETURN_SUCCESS=0
readonly RETURN_FAILURE=1
readonly RETURN_INVALID_ARGS=2
readonly RETURN_NOT_FOUND=1
readonly RETURN_EXISTS=2
readonly RETURN_VALID=0
readonly RETURN_INVALID=1

# Usage in other scripts:
# source "$(dirname "${BASH_SOURCE[0]}")/constants.sh"
```

## Best Practices for Exit Codes

1. **Consistency**: Use the same exit codes across all scripts in your project
2. **Documentation**: Always document what each exit code means
3. **Ranges**: Group related errors in ranges (e.g., 10-19 for file errors)
4. **Avoid Conflicts**: Don't use system reserved codes (125-255)
5. **Meaningful Names**: Use descriptive constant names
6. **Early Exit**: Exit as soon as an error is detected
7. **Propagation**: Preserve exit codes when calling other scripts

```bash
# Good: Preserve exit codes
if ! ./other_script.sh; then
    exit $?  # Preserve the exact exit code
fi

# Better: Handle specific cases
case $? in
    $EXIT_CONFIG_ERROR)
        echo "Configuration error in other_script.sh" >&2
        exit $EXIT_CONFIG_ERROR
        ;;
    $EXIT_NETWORK_ERROR)
        echo "Network error in other_script.sh" >&2
        exit $EXIT_NETWORK_ERROR
        ;;
    *)
        echo "Unknown error in other_script.sh" >&2
        exit $EXIT_FAILURE
        ;;
esac
```

This comprehensive set of constants provides a standardized way to handle exit codes and return values across all your bash/shell scripts, making them more maintainable and easier to debug.
