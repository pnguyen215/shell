#!/usr/bin/env bash
# @file constant/paths.sh
# @brief Locations of the user-level configuration, data and backups.
# @description
#   Everything the library WRITES lives under SHELL_CONFIG_DIR. Override
#   SHELL_CONFIG_DIR (before sourcing) to relocate all of it at once.
#
#   Layout:
#     ~/.shell-config/
#     ├── key.conf            key=base64(value) entries
#     ├── protected.conf      keys that interactive removal must refuse
#     ├── group.conf          group=key1,key2,... definitions
#     ├── backup/             automatic backups
#     ├── bookmarks/.bookmarks
#     └── workspace/          one INI file per workspace

: "${SHELL_CONFIG_DIR:=$HOME/.shell-config}"
SHELL_CONFIG_BACKUP_DIR="$SHELL_CONFIG_DIR/backup"
SHELL_WORKSPACE_DIR="$SHELL_CONFIG_DIR/workspace"
SHELL_BOOKMARK_DIR="$SHELL_CONFIG_DIR/bookmarks"

# Key/value store (values are Base64 encoded, newlines stripped).
SHELL_KEY_FILE="$SHELL_CONFIG_DIR/key.conf"
SHELL_KEY_PROTECTED_FILE="$SHELL_CONFIG_DIR/protected.conf"
SHELL_KEY_GROUP_FILE="$SHELL_CONFIG_DIR/group.conf"
SHELL_KEY_GROUP_BACKUP_FILE="$SHELL_CONFIG_BACKUP_DIR/group.conf.bak"

# Bookmarks: one "name=/absolute/path" per line.
SHELL_BOOKMARK_FILE="$SHELL_BOOKMARK_DIR/.bookmarks"

# SSH material managed by shell::ssh::*.
: "${SHELL_SSH_DIR:=$HOME/.ssh}"
