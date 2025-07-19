#!/bin/bash
# alias.sh

# Shell aliases
alias sve="shell::version"
alias sup="shell::upgrade"
alias sac="shell::add_key_conf"
alias sgc="shell::fzf_get_key_conf"
alias snv="shell::fzf_list_bookmark_up"              # list bookmarks with fzf
alias sre-boo="shell::fzf_rename_bookmark"           # rename bookmark
alias sre-boo-n="shell::fzf_rename_bookmark -n"      # rename bookmark with dry mode
alias srm-boo="shell::fzf_remove_bookmark"           # remove bookmark
alias srm-boo-n="shell::fzf_remove_bookmark -n"      # remove bookmark with dry mode
alias sec="shell::editor .shell-config"              # edit shell config
alias sec-n="shell::editor -n .shell-config"         # edit shell config with dry mode
alias srd="shell::fzf_rename_dir_base_bookmark"      # rename dir base bookmark
alias srd-n="shell::fzf_rename_dir_base_bookmark -n" # rename dir base bookmark with dry mode
alias sgemcheck='shell::eval_gemini_en_vi'           # check grammar english by Gemini
alias sgrammarai='shell::eval_gemini_en_vi'          # check grammar english by Gemini
alias seg='shell::eval_gemini_en_vi'                 # check grammar english by Gemini
alias sgemviconv='shell::eval_gemini_vi_en'          # convert vietnamese to english by Gemini
alias segvi='shell::eval_gemini_vi_en'               # convert vietnamese to english by Gemini
alias ser="shell::editor"                            # edit file with default editor
alias ser-n="shell::editor -n"                       # edit file with default editor in dry mode

# Kernel alias
alias c="clear"
