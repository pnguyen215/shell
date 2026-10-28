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
#     ├── git/
#     │   ├── git-commit-messages.txt       installed copy of src/data/ (see git::commit::message::sync)
#     │   └── git-commit-messages.user.txt  your own commit message templates (never overwritten)
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

# Saved logger style (written by shell::logger::style::set).
SHELL_LOGGER_CONF_FILE="$SHELL_CONFIG_DIR/logger.conf"

# Bookmarks: one "name=/absolute/path" per line.
SHELL_BOOKMARK_FILE="$SHELL_BOOKMARK_DIR/.bookmarks"

# SSH material managed by shell::ssh::*.
: "${SHELL_SSH_DIR:=$HOME/.ssh}"

# Git commit message templates (shell::git::commit::message::*).
#   SOURCE     the file shipped in the repository (source of truth).
#   INSTALLED  the copy install.sh / upgrade.sh / ::sync place under SHELL_CONFIG_DIR.
#   FILE       the file that is read; defaults to the installed copy. When that
#              copy does not exist yet, the default path falls back to SOURCE.
#   USER_FILE  optional templates of your own, merged after the built-in ones.
SHELL_GIT_COMMIT_MESSAGES_SOURCE="$SHELL_SRC_DIR/data/git-commit-messages.txt"
SHELL_GIT_COMMIT_MESSAGES_INSTALLED="$SHELL_CONFIG_DIR/git/git-commit-messages.txt"
: "${SHELL_GIT_COMMIT_MESSAGES_FILE:=$SHELL_GIT_COMMIT_MESSAGES_INSTALLED}"
: "${SHELL_GIT_COMMIT_MESSAGES_USER_FILE:=$SHELL_CONFIG_DIR/git/git-commit-messages.user.txt}"
