#!/bin/bash
# logger.sh

# shell::fatal function
# Prints a fatal error message along with the function call stack, then exits the script.
#
# Usage:
#   shell::fatal [<message>]
#
# Parameters:
#   - <message> : (Optional) A custom error message describing the fatal error.
#
# Description:
#   The function first verifies that it has received 0 to 1 argument using shell::verify_arg_count.
#   It then constructs a stack trace from the FUNCNAME array, prints the error message with red formatting,
#   and outputs the call stack in yellow before exiting with a non-zero status.
#
# Example:
#   shell::fatal "Configuration file not found."
shell::fatal() {
    # Verify argument count: expects between 0 and 1 argument.
    shell::verify_arg_count "$#" 0 1 || exit 1

    # Declare positional argument (readonly) for the error message.
    declare -r msg="${1:-"Unspecified fatal error."}"

    # Declare variable to hold the call stack.
    declare stack

    # Build a string showing the function call stack.
    stack="${FUNCNAME[*]}"
    stack="${stack// / <- }"

    # Print the fatal error message with red color.
    printf "%b\\n" "${SHELL_C_AES_RED}Fatal error. ${msg}${SHELL_C_AES_RESET}" 1>&2

    # Print the call stack with yellow color.
    printf "%b\\n" "${SHELL_C_AES_YELLOW}[${stack}]${SHELL_C_AES_RESET}" 1>&2

    exit 1
}
