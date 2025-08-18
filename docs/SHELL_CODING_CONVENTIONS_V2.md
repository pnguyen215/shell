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

#### Standard LSB Exit Codes (0-8)

```bash
# LSB Standard Exit Codes
readonly EXIT_SUCCESS=0                    # Successful termination
readonly EXIT_FAILURE=1                    # General error
readonly EXIT_MISUSE=2                     # Misuse of shell builtins
readonly EXIT_CANNOT_EXECUTE=126           # Command invoked cannot execute
readonly EXIT_COMMAND_NOT_FOUND=127        # Command not found
readonly EXIT_INVALID_EXIT_ARGUMENT=128    # Invalid argument to exit
readonly EXIT_FATAL_ERROR_SIGNAL_1=129     # Fatal error signal "1"
readonly EXIT_FATAL_ERROR_SIGNAL_2=130     # Fatal error signal "2" (Ctrl+C)
readonly EXIT_FATAL_ERROR_SIGNAL_3=131     # Fatal error signal "3"

# Reserved LSB Exit Codes (continuing through 165)
readonly EXIT_OUT_OF_RANGE=255             # Exit status out of range
```

#### Reserved Exit Codes (do not use)

- **0**: Success only
- **1**: General errors only
- **2**: Shell builtin misuse only
- **126-165**: Reserved by LSB
- **255**: Out of range (reserved)

#### Custom Application Exit Codes (3-125)

```bash
# Configuration and Setup Errors (10-19)
readonly EXIT_CONFIG_ERROR=10              # Configuration file error
readonly EXIT_CONFIG_MISSING=11            # Configuration file missing
readonly EXIT_CONFIG_INVALID=12            # Invalid configuration
readonly EXIT_DEPENDENCY_MISSING=13        # Missing dependencies
readonly EXIT_PERMISSION_DENIED=14         # Permission denied
readonly EXIT_DISK_FULL=15                 # Disk full
readonly EXIT_MEMORY_ERROR=16              # Out of memory
readonly EXIT_TEMP_DIR_ERROR=17            # Temporary directory error
readonly EXIT_LOCKFILE_ERROR=18            # Lock file error
readonly EXIT_ALREADY_RUNNING=19           # Process already running

# Network and Communication Errors (20-29)
readonly EXIT_NETWORK_ERROR=20             # Network error
readonly EXIT_CONNECTION_FAILED=21         # Connection failed
readonly EXIT_TIMEOUT=22                   # Timeout occurred
readonly EXIT_DNS_ERROR=23                 # DNS resolution error
readonly EXIT_SSL_ERROR=24                 # SSL/TLS error
readonly EXIT_AUTH_FAILED=25               # Authentication failed
readonly EXIT_SERVER_ERROR=26              # Server error
readonly EXIT_CLIENT_ERROR=27              # Client error
readonly EXIT_PROTOCOL_ERROR=28            # Protocol error
readonly EXIT_PROXY_ERROR=29               # Proxy error

# File and I/O Errors (30-39)
readonly EXIT_FILE_NOT_FOUND=30            # File not found
readonly EXIT_FILE_EXISTS=31               # File already exists
readonly EXIT_FILE_READ_ERROR=32           # File read error
readonly EXIT_FILE_WRITE_ERROR=33          # File write error
readonly EXIT_FILE_PERMISSION=34           # File permission error
readonly EXIT_DIRECTORY_ERROR=35           # Directory error
readonly EXIT_SYMLINK_ERROR=36             # Symlink error
readonly EXIT_FILESYSTEM_ERROR=37          # Filesystem error
readonly EXIT_MOUNT_ERROR=38               # Mount/unmount error
readonly EXIT_CHECKSUM_ERROR=39            # Checksum/integrity error

# Database and Data Errors (40-49)
readonly EXIT_DATABASE_ERROR=40            # Database error
readonly EXIT_DATABASE_CONNECTION=41       # Database connection error
readonly EXIT_DATABASE_QUERY=42            # Database query error
readonly EXIT_DATABASE_TRANSACTION=43      # Database transaction error
readonly EXIT_DATABASE_LOCK=44             # Database lock error
readonly EXIT_DATA_CORRUPTION=45           # Data corruption
readonly EXIT_DATA_FORMAT_ERROR=46         # Data format error
readonly EXIT_DATA_VALIDATION=47           # Data validation error
readonly EXIT_BACKUP_ERROR=48              # Backup error
readonly EXIT_RESTORE_ERROR=49             # Restore error

# Service and Process Errors (50-59)
readonly EXIT_SERVICE_ERROR=50             # Service error
readonly EXIT_SERVICE_START_FAILED=51      # Service start failed
readonly EXIT_SERVICE_STOP_FAILED=52       # Service stop failed
readonly EXIT_SERVICE_RESTART_FAILED=53    # Service restart failed
readonly EXIT_SERVICE_NOT_RUNNING=54       # Service not running
readonly EXIT_SERVICE_ALREADY_RUNNING=55   # Service already running
readonly EXIT_PROCESS_ERROR=56             # Process error
readonly EXIT_SIGNAL_ERROR=57              # Signal handling error
readonly EXIT_ZOMBIE_PROCESS=58            # Zombie process error
readonly EXIT_FORK_FAILED=59               # Fork failed

# User and Security Errors (60-69)
readonly EXIT_USER_ERROR=60                # User error
readonly EXIT_USER_NOT_FOUND=61            # User not found
readonly EXIT_GROUP_ERROR=62               # Group error
readonly EXIT_PRIVILEGE_ERROR=63           # Insufficient privileges
readonly EXIT_SECURITY_ERROR=64            # Security error
readonly EXIT_CERTIFICATE_ERROR=65         # Certificate error
readonly EXIT_ENCRYPTION_ERROR=66          # Encryption error
readonly EXIT_KEY_ERROR=67                 # Key error
readonly EXIT_TOKEN_ERROR=68               # Token error
readonly EXIT_SESSION_ERROR=69             # Session error

# Resource and System Errors (70-79)
readonly EXIT_RESOURCE_ERROR=70            # Resource error
readonly EXIT_CPU_ERROR=71                 # CPU error
readonly EXIT_MEMORY_LIMIT=72              # Memory limit exceeded
readonly EXIT_DISK_QUOTA=73                # Disk quota exceeded
readonly EXIT_BANDWIDTH_LIMIT=74           # Bandwidth limit exceeded
readonly EXIT_THREAD_ERROR=75              # Thread error
readonly EXIT_SEMAPHORE_ERROR=76           # Semaphore error
readonly EXIT_MUTEX_ERROR=77               # Mutex error
readonly EXIT_IPC_ERROR=78                 # Inter-process communication error
readonly EXIT_HARDWARE_ERROR=79            # Hardware error

# Application Logic Errors (80-89)
readonly EXIT_LOGIC_ERROR=80               # Logic error
readonly EXIT_STATE_ERROR=81               # Invalid state error
readonly EXIT_WORKFLOW_ERROR=82            # Workflow error
readonly EXIT_BUSINESS_RULE_ERROR=83       # Business rule violation
readonly EXIT_CONSTRAINT_ERROR=84          # Constraint violation
readonly EXIT_INVARIANT_ERROR=85           # Invariant violation
readonly EXIT_PRECONDITION_ERROR=86        # Precondition not met
readonly EXIT_POSTCONDITION_ERROR=87       # Postcondition not met
readonly EXIT_ASSERTION_ERROR=88           # Assertion failed
readonly EXIT_CONTRACT_ERROR=89            # Contract violation

# Input/Output and Validation Errors (90-99)
readonly EXIT_INPUT_ERROR=90               # Input error
readonly EXIT_OUTPUT_ERROR=91              # Output error
readonly EXIT_VALIDATION_ERROR=92          # Validation error
readonly EXIT_FORMAT_ERROR=93              # Format error
readonly EXIT_PARSING_ERROR=94             # Parsing error
readonly EXIT_ENCODING_ERROR=95            # Encoding error
readonly EXIT_COMPRESSION_ERROR=96         # Compression error
readonly EXIT_DECOMPRESSION_ERROR=97       # Decompression error
readonly EXIT_SERIALIZATION_ERROR=98       # Serialization error
readonly EXIT_DESERIALIZATION_ERROR=99     # Deserialization error

# External Dependencies and Integration (100-109)
readonly EXIT_EXTERNAL_COMMAND_ERROR=100  # External command error
readonly EXIT_API_ERROR=101                # API error
readonly EXIT_WEBHOOK_ERROR=102            # Webhook error
readonly EXIT_PLUGIN_ERROR=103             # Plugin error
readonly EXIT_MODULE_ERROR=104             # Module error
readonly EXIT_LIBRARY_ERROR=105            # Library error
readonly EXIT_DRIVER_ERROR=106             # Driver error
readonly EXIT_INTEGRATION_ERROR=107        # Integration error
readonly EXIT_COMPATIBILITY_ERROR=108      # Compatibility error
readonly EXIT_VERSION_ERROR=109            # Version error

# Testing and Quality Assurance (110-119)
readonly EXIT_TEST_ERROR=110               # Test error
readonly EXIT_TEST_FAILED=111              # Test failed
readonly EXIT_COVERAGE_ERROR=112           # Coverage error
readonly EXIT_QUALITY_ERROR=113            # Quality check failed
readonly EXIT_LINT_ERROR=114               # Lint error
readonly EXIT_SYNTAX_ERROR=115             # Syntax error
readonly EXIT_SEMANTIC_ERROR=116           # Semantic error
readonly EXIT_PERFORMANCE_ERROR=117        # Performance error
readonly EXIT_BENCHMARK_ERROR=118          # Benchmark error
readonly EXIT_PROFILING_ERROR=119          # Profiling error

# Custom Application Specific (120-125)
readonly EXIT_CUSTOM_ERROR_1=120           # Custom application error 1
readonly EXIT_CUSTOM_ERROR_2=121           # Custom application error 2
readonly EXIT_CUSTOM_ERROR_3=122           # Custom application error 3
readonly EXIT_CUSTOM_ERROR_4=123           # Custom application error 4
readonly EXIT_CUSTOM_ERROR_5=124           # Custom application error 5
readonly EXIT_CUSTOM_ERROR_6=125           # Custom application error 6
```

#### Usage Examples

```bash
# Check configuration file
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file not found: $CONFIG_FILE" >&2
    exit $EXIT_CONFIG_MISSING
fi

# Check dependencies
if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is not installed" >&2
    exit $EXIT_DEPENDENCY_MISSING
fi

# Handle network errors
if ! curl -f "$API_URL" >/dev/null 2>&1; then
    echo "Error: Failed to connect to API" >&2
    exit $EXIT_CONNECTION_FAILED
fi

# Success
echo "Operation completed successfully"
exit $EXIT_SUCCESS
```

#### Exit Code Helper Functions

```bash
#######################################
# Exit with error message and code
# Arguments:
#   $1 - Exit code
#   $2 - Error message
#######################################
exit_with_error() {
    local exit_code="$1"
    local message="$2"
    local timestamp

    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $message" >&2
    exit "$exit_code"
}

# Usage examples
exit_with_error $EXIT_CONFIG_MISSING "Configuration file not found: $CONFIG_FILE"
exit_with_error $EXIT_PERMISSION_DENIED "Cannot write to directory: $OUTPUT_DIR"
exit_with_error $EXIT_NETWORK_ERROR "Failed to download file from: $URL"
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

### All Bash/Shell Constants and Variables

### Built-in Shell Variables

#### Positional Parameters

```bash
$0              # Script name
$1, $2, $3...   # Command line arguments
$#              # Number of arguments passed to script
$*              # All arguments as a single string
$@              # All arguments as separate strings
$              # Process ID of current shell
$!              # Process ID of last background command
$?              # Exit status of last executed command
$-              # Current shell options
$_              # Last argument of previous command
```

#### Special Variables

```bash
IFS             # Internal Field Separator (default: space, tab, newline)
PATH            # Command search path
HOME            # User's home directory
USER            # Current username
PWD             # Current working directory
OLDPWD          # Previous working directory
SHELL           # Current shell
TERM            # Terminal type
LANG            # Default locale
LC_ALL          # Override all locale settings
EDITOR          # Default editor
PAGER           # Default pager
TMPDIR          # Temporary directory
```

#### Bash-specific Variables

```bash
BASH            # Path to bash executable
BASH_VERSION    # Bash version string
BASHPID         # Process ID of current bash instance
BASH_SOURCE     # Array of source filenames
FUNCNAME        # Array of function names
LINENO          # Current line number
HOSTNAME        # System hostname
HOSTTYPE        # Machine type
MACHTYPE        # Machine type with OS
OSTYPE          # Operating system type
PPID            # Parent process ID
RANDOM          # Random integer (0-32767)
SECONDS         # Seconds since shell started
SHLVL           # Shell level (depth of nested shells)
UID             # User ID
EUID            # Effective user ID
GROUPS          # Array of user's group IDs
```

### Standard Environment Variables

#### System Information

```bash
readonly SYSTEM_NAME="$(uname -s)"         # Kernel name
readonly SYSTEM_RELEASE="$(uname -r)"      # Kernel release
readonly SYSTEM_VERSION="$(uname -v)"      # Kernel version
readonly MACHINE_TYPE="$(uname -m)"        # Machine type
readonly PROCESSOR="$(uname -p)"           # Processor type
readonly HARDWARE_PLATFORM="$(uname -i)"  # Hardware platform
readonly OPERATING_SYSTEM="$(uname -o)"   # Operating system
```

#### Path and Directory Constants

```bash
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
readonly CURRENT_DIR="$(pwd)"
readonly HOME_DIR="$HOME"
readonly TEMP_DIR="${TMPDIR:-/tmp}"
readonly LOG_DIR="/var/log"
readonly CONFIG_DIR="/etc"
readonly BIN_DIR="/usr/local/bin"
readonly LIB_DIR="/usr/local/lib"
readonly SHARE_DIR="/usr/local/share"
```

#### File and Permission Constants

```bash
readonly FILE_MODE_READ=0444
readonly FILE_MODE_WRITE=0222
readonly FILE_MODE_EXECUTE=0111
readonly FILE_MODE_RW=0666
readonly FILE_MODE_RWX=0777
readonly DIR_MODE_READ=0555
readonly DIR_MODE_WRITE=0333
readonly DIR_MODE_EXECUTE=0111
readonly DIR_MODE_RW=0666
readonly DIR_MODE_RWX=0777
readonly UMASK_SECURE=0077
readonly UMASK_NORMAL=0022
```

#### Time and Date Constants

```bash
readonly DATE_FORMAT_ISO='+%Y-%m-%d'
readonly DATE_FORMAT_US='+%m/%d/%Y'
readonly TIME_FORMAT_24='+%H:%M:%S'
readonly TIME_FORMAT_12='+%I:%M:%S %p'
readonly DATETIME_FORMAT_ISO='+%Y-%m-%d %H:%M:%S'
readonly DATETIME_FORMAT_FILENAME='+%Y%m%d_%H%M%S'
readonly TIMESTAMP_FORMAT='+%Y-%m-%d %H:%M:%S %Z'
readonly EPOCH_FORMAT='+%s'
```

#### Size and Limit Constants

```bash
readonly KB=1024
readonly MB=$((1024 * KB))
readonly GB=$((1024 * MB))
readonly TB=$((1024 * GB))

readonly MAX_FILE_SIZE=$((100 * MB))      # 100 MB
readonly MAX_LOG_SIZE=$((10 * MB))        # 10 MB
readonly MAX_BACKUP_SIZE=$((1 * GB))      # 1 GB
readonly MAX_MEMORY_USAGE=$((512 * MB))   # 512 MB

readonly DEFAULT_TIMEOUT=30               # 30 seconds
readonly LONG_TIMEOUT=300                 # 5 minutes
readonly SHORT_TIMEOUT=5                  # 5 seconds
readonly NETWORK_TIMEOUT=60               # 1 minute
```

#### Color and Formatting Constants

```bash
# ANSI Color Codes
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_PURPLE='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[0;37m'
readonly COLOR_BLACK='\033[0;30m'

# Bright Colors
readonly COLOR_BRIGHT_RED='\033[1;31m'
readonly COLOR_BRIGHT_GREEN='\033[1;32m'
readonly COLOR_BRIGHT_YELLOW='\033[1;33m'
readonly COLOR_BRIGHT_BLUE='\033[1;34m'
readonly COLOR_BRIGHT_PURPLE='\033[1;35m'
readonly COLOR_BRIGHT_CYAN='\033[1;36m'
readonly COLOR_BRIGHT_WHITE='\033[1;37m'

# Background Colors
readonly BG_RED='\033[41m'
readonly BG_GREEN='\033[42m'
readonly BG_YELLOW='\033[43m'
readonly BG_BLUE='\033[44m'
readonly BG_PURPLE='\033[45m'
readonly BG_CYAN='\033[46m'
readonly BG_WHITE='\033[47m'

# Text Formatting
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly ITALIC='\033[3m'
readonly UNDERLINE='\033[4m'
readonly BLINK='\033[5m'
readonly REVERSE='\033[7m'
readonly STRIKETHROUGH='\033[9m'

# Reset
readonly COLOR_RESET='\033[0m'
readonly RESET='\033[0m'
```

#### Signal Constants

```bash
readonly SIGHUP=1          # Hangup
readonly SIGINT=2          # Interrupt (Ctrl+C)
readonly SIGQUIT=3         # Quit (Ctrl+\)
readonly SIGILL=4          # Illegal instruction
readonly SIGTRAP=5         # Trace/breakpoint trap
readonly SIGABRT=6         # Abort
readonly SIGBUS=7          # Bus error
readonly SIGFPE=8          # Floating point exception
readonly SIGKILL=9         # Kill (cannot be caught)
readonly SIGUSR1=10        # User-defined signal 1
readonly SIGSEGV=11        # Segmentation violation
readonly SIGUSR2=12        # User-defined signal 2
readonly SIGPIPE=13        # Broken pipe
readonly SIGALRM=14        # Alarm clock
readonly SIGTERM=15        # Termination
readonly SIGSTKFLT=16      # Stack fault
readonly SIGCHLD=17        # Child status changed
readonly SIGCONT=18        # Continue
readonly SIGSTOP=19        # Stop (cannot be caught)
readonly SIGTSTP=20        # Keyboard stop (Ctrl+Z)
readonly SIGTTIN=21        # Background read from tty
readonly SIGTTOU=22        # Background write to tty
readonly SIGURG=23         # Urgent condition on socket
readonly SIGXCPU=24        # CPU limit exceeded
readonly SIGXFSZ=25        # File size limit exceeded
readonly SIGVTALRM=26      # Virtual alarm clock
readonly SIGPROF=27        # Profiling alarm clock
readonly SIGWINCH=28       # Window size change
readonly SIGIO=29          # I/O now possible
readonly SIGPWR=30         # Power failure restart
readonly SIGSYS=31         # Bad system call
```

#### HTTP Status Code Constants

```bash
# Informational responses (100-199)
readonly HTTP_CONTINUE=100
readonly HTTP_SWITCHING_PROTOCOLS=101

# Successful responses (200-299)
readonly HTTP_OK=200
readonly HTTP_CREATED=201
readonly HTTP_ACCEPTED=202
readonly HTTP_NO_CONTENT=204

# Redirection messages (300-399)
readonly HTTP_MOVED_PERMANENTLY=301
readonly HTTP_FOUND=302
readonly HTTP_NOT_MODIFIED=304

# Client error responses (400-499)
readonly HTTP_BAD_REQUEST=400
readonly HTTP_UNAUTHORIZED=401
readonly HTTP_FORBIDDEN=403
readonly HTTP_NOT_FOUND=404
readonly HTTP_METHOD_NOT_ALLOWED=405
readonly HTTP_CONFLICT=409
readonly HTTP_UNPROCESSABLE_ENTITY=422
readonly HTTP_TOO_MANY_REQUESTS=429

# Server error responses (500-599)
readonly HTTP_INTERNAL_SERVER_ERROR=500
readonly HTTP_NOT_IMPLEMENTED=501
readonly HTTP_BAD_GATEWAY=502
readonly HTTP_SERVICE_UNAVAILABLE=503
readonly HTTP_GATEWAY_TIMEOUT=504
```

#### Regex Pattern Constants

````bash
readonly REGEX_EMAIL='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}

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
````

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
readonly REGEX_IP_V4='^([0-9]{1,3}\.){3}[0-9]{1,3}

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
readonly REGEX_IP_V6='^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}

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
readonly REGEX_URL='^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.\*)?

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
readonly REGEX_PHONE_US='^(\+1[-.\s]?)?(\(?[0-9]{3}\)?[-.\s]?)[0-9]{3}[-.\s]?[0-9]{4}

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
readonly REGEX_DATE_ISO='^[0-9]{4}-[0-9]{2}-[0-9]{2}

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
readonly REGEX_TIME_24='^([01]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]

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
readonly REGEX_UUID='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}

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
readonly REGEX_ALPHANUMERIC='^[a-zA-Z0-9]+

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
readonly REGEX_LOWERCASE='^[a-z]+

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
readonly REGEX_UPPERCASE='^[A-Z]+

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
readonly REGEX_DIGITS='^[0-9]+

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
readonly REGEX*FILENAME='^[a-zA-Z0-9.*-]+

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
readonly REGEX*VARIABLE_NAME='^[a-zA-Z*][a-zA-Z0-9_]\*

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

````

#### Common File Extensions
```bash
readonly EXT_SHELL='.sh'
readonly EXT_BASH='.bash'
readonly EXT_LOG='.log'
readonly EXT_CONF='.conf'
readonly EXT_CONFIG='.config'
readonly EXT_JSON='.json'
readonly EXT_YAML='.yaml'
readonly EXT_YML='.yml'
readonly EXT_XML='.xml'
readonly EXT_CSV='.csv'
readonly EXT_TXT='.txt'
readonly EXT_TAR='.tar'
readonly EXT_GZ='.gz'
readonly EXT_ZIP='.zip'
readonly EXT_BACKUP='.bak'
readonly EXT_TEMP='.tmp'
readonly EXT_LOCK='.lock'
readonly EXT_PID='.pid'
````

#### Application Constants Template

```bash
# Application Information
readonly APP_NAME="MyApplication"
readonly APP_VERSION="1.0.0"
readonly APP_DESCRIPTION="Application description"
readonly APP_AUTHOR="Your Name <email@example.com>"
readonly APP_LICENSE="MIT"
readonly APP_URL="https://github.com/user/repo"

# Application Directories
readonly APP_HOME="/opt/${APP_NAME,,}"
readonly APP_CONFIG_DIR="/etc/${APP_NAME,,}"
readonly APP_LOG_DIR="/var/log/${APP_NAME,,}"
readonly APP_DATA_DIR="/var/lib/${APP_NAME,,}"
readonly APP_CACHE_DIR="/var/cache/${APP_NAME,,}"
readonly APP_RUN_DIR="/var/run/${APP_NAME,,}"
readonly APP_TEMP_DIR="/tmp/${APP_NAME,,}"

# Configuration Files
readonly APP_CONFIG_FILE="${APP_CONFIG_DIR}/config.conf"
readonly APP_LOG_FILE="${APP_LOG_DIR}/app.log"
readonly APP_PID_FILE="${APP_RUN_DIR}/app.pid"
readonly APP_LOCK_FILE="${APP_RUN_DIR}/app.lock"

# Default Values
readonly DEFAULT_PORT=8080
readonly DEFAULT_HOST="localhost"
readonly DEFAULT_USER="nobody"
readonly DEFAULT_GROUP="nogroup"
readonly DEFAULT_LOG_LEVEL="INFO"
readonly DEFAULT_MAX_CONNECTIONS=100
readonly DEFAULT_WORKER_PROCESSES=4
```

## Best Practices

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
