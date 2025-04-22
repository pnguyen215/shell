#!/bin/bash
# args.sh

# shell::verify_arg_count function
# Verifies that the number of provided arguments falls within an expected range.
#
# Usage:
#   shell::verify_arg_count <actual_arg_count> <expected_arg_count_min> <expected_arg_count_max>
#
# Parameters:
#   - <actual_arg_count>     : The number of arguments that were passed.
#   - <expected_arg_count_min>: The minimum number of arguments expected.
#   - <expected_arg_count_max>: The maximum number of arguments expected.
#
# Description:
#   The function first checks that exactly three arguments are provided.
#   It then verifies that all arguments are integers.
#   Finally, it compares the actual argument count to the expected range.
#   If the count is outside the expected range, it prints an error message in red and returns 1.
#
# Example:
#   shell::verify_arg_count "$#" 0 1   # Verifies that the function was called with 0 or 1 argument.
shell::verify_arg_count() {
    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_VERIFY_ARG_COUNT"
        return 0
    fi

    # Ensure exactly three parameters are provided to the function.
    if [[ "$#" -ne "3" ]]; then
        shell::fatal "Invalid number of arguments. Expected 3, received $#."
    fi
    declare -r actual_arg_count="$1"
    declare -r expected_arg_count_min="$2"
    declare -r expected_arg_count_max="$3"
    declare -r regex="^[0-9]+$"
    declare error_msg

    # Verify that actual_arg_count is an integer.
    if ! [[ "${actual_arg_count}" =~ ${regex} ]]; then
        shell::fatal "\"${actual_arg_count}\" is not an integer."
    fi
    # Verify that expected_arg_count_min is an integer.
    if ! [[ "${expected_arg_count_min}" =~ ${regex} ]]; then
        shell::fatal "\"${expected_arg_count_min}\" is not an integer."
    fi
    # Verify that expected_arg_count_max is an integer.
    if ! [[ "${expected_arg_count_max}" =~ ${regex} ]]; then
        shell::fatal "\"${expected_arg_count_max}\" is not an integer."
    fi

    # Check if the actual argument count falls outside the expected range.
    if [[ "${actual_arg_count}" -lt "${expected_arg_count_min}" ||
        "${actual_arg_count}" -gt "${expected_arg_count_max}" ]]; then
        if [[ "${expected_arg_count_min}" -eq "${expected_arg_count_max}" ]]; then
            error_msg="Invalid number of arguments. Expected "
            error_msg+="${expected_arg_count_min}, received ${actual_arg_count}."
        else
            error_msg="Invalid number of arguments. Expected between "
            error_msg+="${expected_arg_count_min} and ${expected_arg_count_max}, "
            error_msg+="received ${actual_arg_count}."
        fi
        printf "%b\\n" "${SHELL_C_AES_RED}Error. ${error_msg}${SHELL_C_AES_RESET}" 1>&2
        return 1
    fi
}
