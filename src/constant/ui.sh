#!/usr/bin/env bash
# @file constant/ui.sh
# @brief Terminal colours (ANSI 256-colour codes) and glyphs used by the logger.
# @description
#   Colour values are ANSI 256-colour palette indexes (0-255) consumed by
#   shell::console::print. Change a value here to re-theme the whole library.

# --- Log levels --------------------------------------------------------------
SHELL_COLOR_DEBUG=244
SHELL_COLOR_INFO=33
SHELL_COLOR_WARN=11
SHELL_COLOR_ERROR=196
SHELL_COLOR_FATAL=160
SHELL_COLOR_SUCCESS=46

# --- Help / documentation blocks --------------------------------------------
SHELL_COLOR_USAGE=39
SHELL_COLOR_EXAMPLE=42
SHELL_COLOR_ITEM=245
SHELL_COLOR_DESCRIPTION=250
SHELL_COLOR_NOTE=248
SHELL_COLOR_STEP=33
SHELL_COLOR_SECTION=39
SHELL_COLOR_SEPARATOR=240
SHELL_COLOR_COMMAND=111

# --- Interactive prompts -----------------------------------------------------
SHELL_COLOR_PROMPT=208

# --- Glyphs ------------------------------------------------------------------
SHELL_GLYPH_COMMAND="▶"
SHELL_GLYPH_OK="[✓]"
SHELL_GLYPH_FAIL="[✗]"
SHELL_GLYPH_COPIED="✨"
SHELL_GLYPH_POINTER="▶"
SHELL_GLYPH_MARKER="✓"
