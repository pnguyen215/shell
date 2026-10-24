#!/usr/bin/env bash
# @file constant/defaults.sh
# @brief Tunable defaults. Every value can be overridden from the environment.
# @description
#   Use the `: "${VAR:=default}"` idiom so exported values win.

# --- Logging -----------------------------------------------------------------
# Minimum level printed: DEBUG | INFO | WARN | ERROR | FATAL
: "${SHELL_LOGGER_LEVEL:=DEBUG}"

# --- Dependencies ------------------------------------------------------------
# 1 = missing tools (fzf, jq ...) are installed automatically via the native
# package manager; 0 = only report what is missing and how to install it.
: "${SHELL_AUTO_INSTALL_DEPS:=1}"

# --- fzf ---------------------------------------------------------------------
# Options shared by every interactive picker (see shell::fzf::select).
SHELL_FZF_OPTS=(
	"--height=25%"
	"--layout=reverse"
	"--border=rounded"
	"--pointer=${SHELL_GLYPH_POINTER:-▶}"
	"--marker=${SHELL_GLYPH_MARKER:-✓}"
	"--ansi"
)

# Text of the "go back" entry added by shell::fzf::loop --back.
: "${SHELL_FZF_BACK_LABEL:=← Back}"

# --- INI parser --------------------------------------------------------------
# 0 = lenient parsing, 1 = reject malformed names/values.
: "${SHELL_INI_STRICT:=0}"
# 1 = `key=` (empty value) is accepted.
: "${SHELL_INI_ALLOW_EMPTY_VALUES:=1}"
# 1 = section/key names may contain spaces.
: "${SHELL_INI_ALLOW_SPACES_IN_NAMES:=1}"

# --- Network -----------------------------------------------------------------
# Seconds before curl gives up connecting / the whole transfer is aborted.
: "${SHELL_NET_CONNECT_TIMEOUT:=15}"
: "${SHELL_NET_MAX_TIME:=300}"

# --- Configuration keys that must never be removed interactively ------------
SHELL_PROTECTED_KEYS=(
	"SHELL_SHIELD_ENCRYPTION_KEY"
	"SHELL_SHIELD_ENCRYPTION_IV"
	"HOST"
	"PORT"
	"SHELL_DEVELOPER"
	"SHELL_HISTORICAL_GH_TELEGRAM_BOT_TOKEN"
	"SHELL_HISTORICAL_GH_TELEGRAM_CHAT_ID"
)
