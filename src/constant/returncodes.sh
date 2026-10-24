#!/usr/bin/env bash
# @file constant/returncodes.sh
# @brief Return codes used by every shell::* function.
# @description
#   Each code has a UNIQUE value so a caller can tell failure modes apart.
#   (The previous revision reused 0/1/2 across several names, which made
#   `RETURN_INVALID` indistinguishable from `RETURN_FAILURE`.)
#
#   Codes stay in 0..125 so they never collide with the shell's reserved
#   statuses (126 = not executable, 127 = not found, 128+N = signal N).

RETURN_SUCCESS=0           # The operation completed.
RETURN_FAILURE=1           # Generic failure (a command failed, I/O error ...).
RETURN_INVALID=2           # Invalid or missing argument / usage error.
RETURN_NOT_FOUND=3         # A required file, directory, command or key is absent.
RETURN_NOT_SUPPORTED=4     # The feature is not available on this OS / shell.
RETURN_NOT_IMPLEMENTED=5   # The feature is declared but intentionally not built yet.
RETURN_PERMISSION_DENIED=6 # The caller lacks the privileges for the operation.
RETURN_EXISTS=7            # The target already exists and was not overwritten.
RETURN_EMPTY=8             # A required value or result set is empty.
RETURN_CANCELLED=9         # The user aborted an interactive prompt (ESC / Ctrl-C).
RETURN_TIMEOUT=10          # The operation exceeded its time budget.
RETURN_BACK=11             # The user picked the "back" entry of a menu (not a cancel).
