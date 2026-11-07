#!/usr/bin/env bash
# @file constant/markdown.sh
# @brief Defaults and fixed strings of the Markdown builder (src/markdown/).
# @description
#   Output formats are `markdown` (CommonMark/GFM), `telegram` (Telegram Bot API
#   MarkdownV2) and `plain` (readable text, no markup).
#
#   The marker and separator characters are control characters that never occur
#   in normal text; the builder uses them internally and never prints them in a
#   rendered document.

# Format used by shell::markdown::init when none is given.
: "${SHELL_MARKDOWN_DEFAULT_FORMAT:=markdown}"

# Supported format identifiers (space separated).
SHELL_MARKDOWN_FORMATS="markdown telegram plain"

# Wraps a formatted inline fragment so block builders keep it verbatim
# instead of escaping it a second time.
SHELL_MARKDOWN_FRAG_START=$'\001'
SHELL_MARKDOWN_FRAG_END=$'\002'

# Separators of the table state (cells inside a row, rows inside the table).
SHELL_MARKDOWN_CELL_SEP=$'\037'
SHELL_MARKDOWN_ROW_SEP=$'\036'

# Horizontal rule where the format has no native one.
: "${SHELL_MARKDOWN_TELEGRAM_RULE:=────────────────────}"
: "${SHELL_MARKDOWN_PLAIN_RULE:=--------------------}"

# Bullets by nesting level (Telegram has no list syntax): level 0, 1, 2+.
: "${SHELL_MARKDOWN_TELEGRAM_BULLET_0:=•}"
: "${SHELL_MARKDOWN_TELEGRAM_BULLET_1:=◦}"
: "${SHELL_MARKDOWN_TELEGRAM_BULLET_2:=▪}"

# Spaces added per nesting level.
: "${SHELL_MARKDOWN_INDENT:=4}"
