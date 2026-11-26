#!/usr/bin/env bash
# @file lang/git/_core/stage.sh
# @brief Private helpers shared by the shell::git::stage::* functions.
# @description
#   Owned by the stage group. Functions here are named `_shell::git::core::stage_<name>`, are marked
#   `# @internal`, and are used by more than one action of the group (a helper used by one action
#   alone stays in that action's file, as its only other function is not allowed: one public
#   function per action file, so share through this file).
