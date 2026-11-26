#!/usr/bin/env bash
# @file lang/git/_core/flow.sh
# @brief Private helpers shared by the shell::git::flow::* functions.
# @description
#   Owned by the flow group. Functions here are named `_shell::git::core::flow_<name>`, are marked
#   `# @internal`, and are used by more than one action of the group (a helper used by one action
#   alone stays in that action's file, as its only other function is not allowed: one public
#   function per action file, so share through this file).
