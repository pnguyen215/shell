#!/usr/bin/env bash
# @file constant/system.sh
# @brief Project identity, directory layout and module load order.
# @description
#   Single source of truth for every path that belongs to the library itself.
#   This file MUST be the first constant file sourced because every other
#   constant file derives its values from `SHELL_DIR`.
#
#   Every value is assigned with the `: "${VAR:=default}"` idiom so that a user
#   can override it from the environment *before* sourcing `src/shell.sh`:
#
#       export SHELL_DIR="$HOME/dev/shell"
#       source "$SHELL_DIR/src/shell.sh"
#
#   NOTE: constants are intentionally not declared `readonly`. The library is
#   re-sourced by `shell::upgrade`, and re-assigning a readonly variable is a
#   fatal error in both bash and zsh.

# --- Project identity --------------------------------------------------------

# Short project name, used in log prefixes and temp-file names.
: "${SHELL_NAME:=shell}"

# GitHub "owner/repo" slug that hosts the library.
: "${SHELL_REPO_SLUG:=pnguyen215/shell}"

# Branch used by install / upgrade.
: "${SHELL_REPO_BRANCH:=master}"

# Default installation directory (used by install.sh, upgrade.sh, uninstall.sh).
: "${SHELL_INSTALL_DIR:=$HOME/shell}"

# --- Directory layout --------------------------------------------------------

# Root of the library checkout. The loader (src/shell.sh) resolves this from its
# own location; the fallback only applies when sourced through an unusual path.
: "${SHELL_DIR:=$SHELL_INSTALL_DIR}"

SHELL_SRC_DIR="$SHELL_DIR/src"

# --- Module load order -------------------------------------------------------

# Groups (sub-directories of src/) in the order the loader sources them.
# Within a group, files are sourced alphabetically. `constant` is always
# loaded first by the loader itself and is listed here for documentation.
SHELL_MODULE_GROUPS=(constant core dependency lib lang devops shield bot alias)

# --- Supported platforms -----------------------------------------------------

# Values returned by shell::os::type that the library fully supports.
SHELL_SUPPORTED_OS=(linux macos)
