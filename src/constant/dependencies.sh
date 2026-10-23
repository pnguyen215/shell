#!/usr/bin/env bash
# @file constant/dependencies.sh
# @brief Declarative list of external tools the library relies on.
# @description
#   `shell::dependency::doctor` reads these arrays to report what is installed.
#   The per-tool installers live in src/dependency/<tool>.sh.
#
#   REQUIRED: the library cannot do its main job without them.
#   OPTIONAL: only specific functions need them; they are installed on demand.

SHELL_DEPENDENCIES_REQUIRED=(git curl fzf)
SHELL_DEPENDENCIES_OPTIONAL=(jq openssl lsof column ssh-keygen)
