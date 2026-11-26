#!/usr/bin/env bash
# @file lang/git/_core/remote.sh
# @brief Private helpers shared by the shell::git::remote::* functions.
# @description
#   Owned by the remote group. Functions here are named `_shell::git::core::remote_<name>`, are marked
#   `# @internal`, and are used by more than one action of the group (a helper used by one action
#   alone stays in that action's file, as its only other function is not allowed: one public
#   function per action file, so share through this file).
