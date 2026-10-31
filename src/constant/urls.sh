#!/usr/bin/env bash
# @file constant/urls.sh
# @brief Every remote endpoint the library talks to.
# @description
#   Keeping URLs here (never inline in functions) lets an air-gapped or
#   mirrored environment re-point the library by overriding one variable.

# --- This repository ---------------------------------------------------------
SHELL_URL_RAW="https://raw.githubusercontent.com/${SHELL_REPO_SLUG}/${SHELL_REPO_BRANCH}"
SHELL_URL_INSTALL="${SHELL_URL_RAW}/install.sh"
SHELL_URL_GITHUB_API="https://api.github.com"
SHELL_URL_LATEST_RELEASE="${SHELL_URL_GITHUB_API}/repos/${SHELL_REPO_SLUG}/releases/latest"

# --- Template store (gitignore files, CI workflows, Makefiles) ---------------
: "${SHELL_URL_STORE:=https://raw.githubusercontent.com/pnguyen215/shell-devops-stores/refs/heads/master}"

SHELL_URL_GITIGNORE_GO="${SHELL_URL_STORE}/gitignores/.golangignore"
SHELL_URL_GITIGNORE_JAVA="${SHELL_URL_STORE}/gitignores/.javaignore"
SHELL_URL_GITIGNORE_ANGULAR="${SHELL_URL_STORE}/gitignores/.angularignore"
SHELL_URL_GITIGNORE_NODEJS="${SHELL_URL_STORE}/gitignores/.nodeignore"
SHELL_URL_GITIGNORE_PYTHON="${SHELL_URL_STORE}/gitignores/.pythonignore"

SHELL_URL_WORKFLOW_BASE="${SHELL_URL_STORE}/ci-cd/github-actions/gh_wrk_base.yml"
SHELL_URL_WORKFLOW_NEWS="${SHELL_URL_STORE}/ci-cd/github-actions/gh_wrk_news.yml"
SHELL_URL_WORKFLOW_NEWS_GO="${SHELL_URL_STORE}/ci-cd/github-actions/gh_wrk_news_go.yml"
SHELL_URL_WORKFLOW_SH_PRETTY="${SHELL_URL_STORE}/ci-cd/github-actions/gh_wrk_sh_pretty.yml"

SHELL_URL_DOC_VERSIONING="${SHELL_URL_STORE}/docs/VERSIONING.md"
SHELL_URL_GO_MAKEFILE="${SHELL_URL_STORE}/languages/golang/sdk/Makefile"

# --- Third-party installers --------------------------------------------------

# Homebrew installation scripts
SHELL_URL_HOMEBREW_INSTALL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
SHELL_URL_HOMEBREW_UNINSTALL="https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh"

# Oh My Zsh installation script
SHELL_URL_OHMYZSH_INSTALL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

# nvm (Node Version Manager). The installer is pinned to a release: it is
# executed, and `master` could change under you. Override SHELL_NVM_VERSION to
# install another release (shell::dependency::nvm::install -v <version> does it per call).
: "${SHELL_NVM_VERSION:=v0.40.8}"
SHELL_URL_NVM_RAW="https://raw.githubusercontent.com/nvm-sh/nvm"

# --- Messaging ---------------------------------------------------------------
SHELL_URL_TELEGRAM_API="https://api.telegram.org"
