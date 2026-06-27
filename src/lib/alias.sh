#!/bin/bash
# alias.sh

# ////////////////////
# Shell basic aliases
# ///////////////////

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

# ///////////////////
# Shell git aliases
# //////////////////

# shell::git::repos::stats
alias sgrs="shell::git::repos::stats"
alias sgrs-n="shell::git::repos::stats -n"
alias sgrst="shell::git::repos::stats"
alias sgrst-n="shell::git::repos::stats -n"
alias sgrstat="shell::git::repos::stats"
alias sgrstat-n="shell::git::repos::stats -n"
alias sgrstats="shell::git::repos::stats"
alias sgrstats-n="shell::git::repos::stats -n"
alias sgrepostats="shell::git::repos::stats"
alias sgrepostats-n="shell::git::repos::stats -n"

# shell::git::repos::fetch
alias sgreposf="shell::git::repos::fetch"
alias sgreposf-n="shell::git::repos::fetch -n"
alias sgrf="shell::git::repos::fetch"
alias sgrf-n="shell::git::repos::fetch -n"

# shell::git::repos::version::latest
alias sgrvl="shell::git::repos::version::latest"
alias sgrvl-n="shell::git::repos::version::latest -n"

# shell::git::branch::all::fzf
alias sgbaf="shell::git::branch::all::fzf"
alias sgbx="shell::git::branch::all::fzf"

# shell::git::branch::checkout
alias sgfb="shell::git::branch::checkout"
alias sgfb-n="shell::git::branch::checkout -n"

# shell::git::branch::checkout::current
alias sgfbc="shell::git::branch::checkout::current"
alias sgfbc-n="shell::git::branch::checkout::current -n"

# shell::git::branch::create
alias sgcb="shell::git::branch::create"
alias sgcb-n="shell::git::branch::create -n"

# shell::git::branch::remove
alias sgrmb="shell::git::branch::remove"
alias sgrmb-n="shell::git::branch::remove -n"

# shell::git::branch::backup
alias sgbb="shell::git::branch::backup"
alias sgbb-n="shell::git::branch::backup -n"

# shell::git::branch::backup::current
alias sgbbc="shell::git::branch::backup::current"
alias sgbbc-n="shell::git::branch::backup::current -n"

# shell::git::branch::rename
alias sgbr="shell::git::branch::rename"
alias sgbr-n="shell::git::branch::rename -n"

# shell::git::branch::rename::current
alias sgbrc="shell::git::branch::rename::current"
alias sgbrc-n="shell::git::branch::rename::current -n"

# shell::git::branch::rename::fzf
alias sgbrf="shell::git::branch::rename::fzf"
alias sgbrf-n="shell::git::branch::rename::fzf -n"

# shell::git::branch::sync
alias sgbs="shell::git::branch::sync"
alias sgbs-n="shell::git::branch::sync -n"

# shell::git::branch::push
alias sgpush="shell::git::branch::push"
alias sgpush-n="shell::git::branch::push -n"
alias sgpb="shell::git::branch::push"
alias sgpb-n="shell::git::branch::push -n"

# shell::git::branch::push::current
alias sgbpc="shell::git::branch::push::current"
alias sgbpc-n="shell::git::branch::push::current -n"
alias sgpushc="shell::git::branch::push::current"
alias sgpushc-n="shell::git::branch::push::current -n"

# shell::git::branch::push::current::force
alias sgbpcf="shell::git::branch::push::current::force"
alias sgbpcf-n="shell::git::branch::push::current::force -n"
alias sgpushcf="shell::git::branch::push::current::force"
alias sgpushcf-n="shell::git::branch::push::current::force -n"
alias sgpf="shell::git::branch::push::current::force"

# shell::git::branch::merge
alias sgm="shell::git::branch::merge"
alias sgm-n="shell::git::branch::merge -n"
alias sgmerge="shell::git::branch::merge"
alias sgmerge-n="shell::git::branch::merge -n"

# shell::git::branch::merge::fzf
alias sgmf="shell::git::branch::merge::fzf"
alias sgmf-n="shell::git::branch::merge::fzf -n"
alias sgmergef="shell::git::branch::merge::fzf"
alias sgmergef-n="shell::git::branch::merge::fzf -n"

# shell::git::branch::stash
alias sgstsh="shell::git::branch::stash"
alias sgstsh-n="shell::git::branch::stash -n"
alias sgstash="shell::git::branch::stash"
alias sgstash-n="shell::git::branch::stash -n"

# shell::git::branch::stash::remove::fzf
alias sgrmstshf="shell::git::branch::stash::remove::fzf"
alias sgrmstshf-n="shell::git::branch::stash::remove::fzf"
alias sgrmstsh="shell::git::branch::stash::remove::fzf"
alias sgrmstsh-n="shell::git::branch::stash::remove::fzf -n"
alias sgrmshf="shell::git::branch::stash::remove::fzf"
alias sgrmshf-n="shell::git::branch::stash::remove::fzf -n"

# shell::git::branch::stash::preview::fzf
alias sgstshpf="shell::git::branch::stash::preview::fzf"
alias sgstshpf-n="shell::git::branch::stash::preview::fzf -n"
alias sgstshp="shell::git::branch::stash::preview::fzf"
alias sgstshp-n="shell::git::branch::stash::preview::fzf -n"
alias sgstshpreview="shell::git::branch::stash::preview::fzf"
alias sgstshpreview-n="shell::git::branch::stash::preview::fzf -n"

# shell::git::branch::stash::apply::fzf
alias sgstshaf="shell::git::branch::stash::apply::fzf"
alias sgstshaf-n="shell::git::branch::stash::apply::fzf -n"
alias sgstshapplyf="shell::git::branch::stash::apply::fzf"
alias sgstshapplyf-n="shell::git::branch::stash::apply::fzf -n"
alias sgstshapply="shell::git::branch::stash::apply::fzf"
alias sgstshapply-n="shell::git::branch::stash::apply::fzf -n"

# shell::git::commit::message::base
alias sgcmb="shell::git::commit::message::base"
alias sgcmb-n="shell::git::commit::message::base -n"

# shell::git::commit::spec
alias sgcs="shell::git::commit::spec"
alias sgcs-n="shell::git::commit::spec -n"

# shell::git::commit::spec::current
alias sgcsc="shell::git::commit::spec::current"
alias sgcsc-n="shell::git::commit::spec::current -n"
alias sgchc="shell::git::commit::spec::current"
alias sgchc-n="shell::git::commit::spec::current -n"
alias sgbcc="shell::git::commit::spec::current"
alias sgbcc-n="shell::git::commit::spec::current -n"
alias sgh="shell::git::commit::spec::current"
alias sgh-n="shell::git::commit::spec::current -n"
alias sgbh="shell::git::commit::spec::current"
alias sgbh-n="shell::git::commit::spec::current -n"
alias sglog="shell::git::commit::spec::current"
alias sglog-n="shell::git::commit::spec::current -n"

# shell::git::commit::all
alias sgca="shell::git::commit::all"
alias sgca-n="shell::git::commit::all -n"

# shell::git::commit::spec::fzf
alias sgcsf="shell::git::commit::spec::fzf"
alias sgcsf-n="shell::git::commit::spec::fzf -n"

# shell::git::commit::spec::search
alias sgcss="shell::git::commit::spec::search"
alias sgcss-n="shell::git::commit::spec::search -n"
alias sgcp="shell::git::commit::spec::search"
alias sgcp-n="shell::git::commit::spec::search -n"
alias sgcmp="shell::git::commit::spec::search"
alias sgcmp-n="shell::git::commit::spec::search -n"
alias sgcommitpick="shell::git::commit::spec::search"

# shell::git::commit::spec::search::current
alias sgcssc="shell::git::commit::spec::search::current"
alias sgcssc-n="shell::git::commit::spec::search::current -n"
alias sgcpick="shell::git::commit::spec::search::current"
alias sgcpick-n="shell::git::commit::spec::search::current -n"

# shell::git::commit::all::search
alias sgcas="shell::git::commit::all::search"
alias sgcas-n="shell::git::commit::all::search -n"

# shell::git::commit::pick::local
alias sgcpickl="shell::git::commit::pick::local"
alias sgcpickl-n="shell::git::commit::pick::local -n"

# shell::git::commit::pick::remote
alias sgcpickr="shell::git::commit::pick::remote"
alias sgcpickr-n="shell::git::commit::pick::remote -n"

# shell::git::commit::create
alias sgcc="shell::git::commit::create"
alias sgcc-n="shell::git::commit::create -n"
alias sgcf="shell::git::commit::create"
alias sgcf-n="shell::git::commit::create -n"

# shell::git::commit::checkout
alias sgco="shell::git::commit::checkout"
alias sgco-n="shell::git::commit::checkout -n"

# shell::git::commit::checkout::fzf
alias sgcof="shell::git::commit::checkout::fzf"
alias sgcof-n="shell::git::commit::checkout::fzf -n"

# shell::git::tag::create
alias sgtc="shell::git::tag::create"
alias sgtc-n="shell::git::tag::create -n"

# shell::git::tag::remove
alias sgrmt="shell::git::tag::remove"
alias sgrmt-n="shell::git::tag::remove -n"

# shell::git::tag::checkout
alias sgtco="shell::git::tag::checkout"
alias sgtco-n="shell::git::tag::checkout -n"

# shell::git::tag::checkout::fzf
alias sgtcof="shell::git::tag::checkout::fzf"
alias sgtcof-n="shell::git::tag::checkout::fzf -n"

# shell::git::tag::all
alias sgta="shell::git::tag::all"
alias sgta-n="shell::git::tag::all -n"

# shell::git::tag::remove::fzf
alias sgrmtf="shell::git::tag::remove::fzf"
alias sgrmtf-n="shell::git::tag::remove::fzf -n"

# shell::git::commit::revert::fzf
alias sgcrf="shell::git::commit::revert::fzf"
alias sgcrf-n="shell::git::commit::revert::fzf -n"
alias sgcrevertf="shell::git::commit::revert::fzf"
alias sgcrevertf-n="shell::git::commit::revert::fzf -n"
alias sgcrevert="shell::git::commit::revert::fzf"
alias sgcrevert-n="shell::git::commit::revert::fzf -n"

# shell::git::commit::spec::history::fzf
alias sgchf="shell::git::commit::spec::history::fzf"
alias sgchf-n="shell::git::commit::spec::history::fzf -n"
alias sgchistoryf="shell::git::commit::spec::history::fzf"
alias sgchistoryf-n="shell::git::commit::spec::history::fzf -n"
alias sgchistory="shell::git::commit::spec::history::fzf"
alias sgchistory-n="shell::git::commit::spec::history::fzf -n"

# shell::git::commit::spec::history::fzf::current
alias sgchfc="shell::git::commit::spec::history::fzf::current"
alias sgchfc-n="shell::git::commit::spec::history::fzf::current -n"
alias sgchistoryfc="shell::git::commit::spec::history::fzf::current"
alias sgchistoryfc-n="shell::git::commit::spec::history::fzf::current -n"
alias sgchistoryc="shell::git::commit::spec::history::fzf::current"
alias sgchistoryc-n="shell::git::commit::spec::history::fzf::current -n"

# ////////////////////
# Shell git basic aliases
# ///////////////////

# git add
alias sga="git add"
# git add all
alias sgaa="git add ."
# git status
alias sgs="git status"
alias sgst="sgs"
# git status -s
alias sgsst="git status -s"

# ////////////////////
# Shell kernel aliases
# ///////////////////

# clear
alias c="clear"

# ////////////////////
# Shell python aliases
# ///////////////////

# shell::python::install
alias spi="shell::python::install"
alias spi-n="shell::python::install -n"

# shell::python::is_installed
alias spii="shell::python::is_installed"
alias spii-n="shell::python::is_installed -n"

# shell::python::uninstall
alias spu="shell::python::uninstall"
alias spu-n="shell::python::uninstall -n"

# shell::python::pip::uninstall
alias spipu="shell::python::pip::uninstall"
alias spipu-n="shell::python::pip::uninstall -n"

# shell::python::pip::uninstall::all
alias spipua="shell::python::pip::uninstall::all"
alias spipua-n="shell::python::pip::uninstall::all -n"
alias sipuall="shell::python::pip::uninstall::all"
alias sipuall-n="shell::python::pip::uninstall::all -n"

# shell::python::venv::create
alias spvc="shell::python::venv::create"
alias spvc-n="shell::python::venv::create -n"

# shell::python::venv::pkg::install
alias spvpi="shell::python::venv::pkg::install"
alias spvpi-n="shell::python::venv::pkg::install -n"

# shell::python::venv::pkg::uninstall
alias spvpu="shell::python::venv::pkg::uninstall"
alias spvpu-n="shell::python::venv::pkg::uninstall -n"

# shell::python::venv::pkg::uninstall::fzf
alias spvpuf="shell::python::venv::pkg::uninstall::fzf"
alias spvpuf-n="shell::python::venv::pkg::uninstall::fzf -n"

# shell::python::venv::activate::fzf
alias spvaf="shell::python::venv::activate::fzf"
alias spvaf-n="shell::python::venv::activate::fzf -n"

# shell::python::venv::pkg::upgrade
alias spvpug="shell::python::venv::pkg::upgrade"
alias spvpug-n="shell::python::venv::pkg::upgrade -n"
alias spvupgrade="shell::python::venv::pkg::upgrade"
alias spvupgrade-n="shell::python::venv::pkg::upgrade -n"

# shell::python::venv::pkg::upgrade::fzf
alias spvpugf="shell::python::venv::pkg::upgrade::fzf"
alias spvpugf-n="shell::python::venv::pkg::upgrade::fzf -n"
alias spvupgradef="shell::python::venv::pkg::upgrade::fzf"
alias spvupgradef-n="shell::python::venv::pkg::upgrade::fzf -n"

# shell::python::venv::pkg::freeze
alias spvpfr="shell::python::venv::pkg::freeze"
alias spvpfr-n="shell::python::venv::pkg::freeze -n"
alias spvfreeze="shell::python::venv::pkg::freeze"
alias spvfreeze-n="shell::python::venv::pkg::freeze -n"

# shell::python::venv::pkg::install::requirements
alias spvpir="shell::python::venv::pkg::install::requirements"
alias spvpir-n="shell::python::venv::pkg::install::requirements -n"
alias spvinstallr="shell::python::venv::pkg::install::requirements"
alias spvinstallr-n="shell::python::venv::pkg::install::requirements -n"
alias spvinstallrequirements="shell::python::venv::pkg::install::requirements"
alias spvinstallrequirements-n="shell::python::venv::pkg::install::requirements -n"

# shell::python::gitignore::add
alias spgiga="shell::python::gitignore::add"
alias spgiga-n="shell::python::gitignore::add -n"
alias spgitignoreadd="shell::python::gitignore::add"
alias spgitignoreadd-n="shell::python::gitignore::add -n"
