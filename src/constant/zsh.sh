#!/usr/bin/env bash
# @file constant/zsh.sh
# @brief Constants of the zsh module (shell::zsh::*).
# @description
#   Data only: nothing here runs a command, so sourcing the library stays free.
#   Every value can be overridden from the environment before sourcing.

# --- Profile hook ------------------------------------------------------------
# These two markers and the default directory MUST stay identical to the ones in
# install.sh and uninstall.sh (the uninstaller deletes the block between the
# markers). Change all three together, or `shell::zsh::install` and the
# uninstaller stop understanding each other.
SHELL_ZSH_HOOK_BEGIN="# >>> shell >>>"
SHELL_ZSH_HOOK_END="# <<< shell <<<"
# Same default as install.sh (default install location $HOME/shell).
: "${SHELL_ZSH_DEFAULT_DIR:=$HOME/shell}"
# Profile edited by shell::zsh::install (relative to $HOME) and the suffix of its backup (as uninstall.sh).
SHELL_ZSH_RC_NAME=".zshrc"
SHELL_ZSH_BACKUP_SUFFIX=".shell-bak"
# File listing the login shells chsh accepts.
: "${SHELL_ZSH_SHELLS_FILE:=/etc/shells}"
# awk program that finds and rewrites the hook (read, not sourced).
SHELL_ZSH_HOOK_AWK="$SHELL_SRC_DIR/data/zsh-hook.awk"

# --- Pickers -----------------------------------------------------------------
# Most recent history entries offered by shell::zsh::history::search::fzf.
: "${SHELL_ZSH_HISTORY_LIMIT:=50000}"
# Seconds a TERM'd process gets to exit before shell::zsh::process::kill::fzf offers SIGKILL.
: "${SHELL_ZSH_KILL_GRACE:=3}"
# Shown in place of a line break when a multi-line history entry is flattened onto one row.
: "${SHELL_ZSH_NEWLINE_MARK:=⏎}"
# Preview windows (fzf --preview-window).
SHELL_ZSH_PREVIEW_WINDOW="right,55%,border-left,wrap"

# --- Cache -------------------------------------------------------------------
# Slow candidate sources are cached here (mode 700 / 600), refreshed in the
# background once older than the TTL (stale-while-revalidate).
: "${SHELL_ZSH_CACHE_DIR:=$SHELL_CONFIG_DIR/cache/zsh}"
: "${SHELL_ZSH_CACHE_TTL:=300}"

# --- Data files read by previews ----------------------------------------------
SHELL_ZSH_SSH_BLOCK_AWK="$SHELL_SRC_DIR/data/zsh-ssh-block.awk"
SHELL_ZSH_HISTORY_AWK="$SHELL_SRC_DIR/data/zsh-history.awk"
SHELL_ZSH_PROCESS_AWK="$SHELL_SRC_DIR/data/zsh-process.awk"

# --- ZLE widgets (zsh only, opt-in) --------------------------------------------
# 1 = register the shell-* widgets when the library is sourced in an interactive zsh.
# Keys are bound only when they are still unbound; override them freely.
: "${SHELL_ZSH_WIDGETS:=0}"
: "${SHELL_ZSH_KEY_HISTORY:=^Xh}"
: "${SHELL_ZSH_KEY_SSH:=^Xj}"
: "${SHELL_ZSH_KEY_WORKTREE:=^Xw}"
: "${SHELL_ZSH_KEY_BOOKMARK:=^Xb}"
