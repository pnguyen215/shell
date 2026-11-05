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

# --- Homebrew ----------------------------------------------------------------
# Packages the unused-package scan (shell::brew::unused) never proposes to
# remove, because this library needs them. Space separated; extend it from
# your profile, e.g.  SHELL_BREW_PROTECTED="fzf git curl jq node".
: "${SHELL_BREW_PROTECTED:=fzf git curl jq}"
# A formula you installed yourself is "stale" when none of its files were
# touched for this many days (and none of its commands is in your shell history).
: "${SHELL_BREW_STALE_DAYS:=90}"

# --- Git commit messages -----------------------------------------------------
# Emoji in the messages built by shell::git::commit::create (sgcf) and ::predict.
# Conventional Commits 1.0.0 wants the type first, so the gitmoji shortcode goes
# AFTER the colon: `feat: :sparkles: add login`. false (default) | true.
# One call can override it with --emoji / --no-emoji.
: "${SHELL_GIT_COMMIT_EMOJI:=false}"

# `label|type|emoji` per line: the menu of shell::git::commit::create (sgcf) and
# ::predict (the label, in this order), the Conventional Commits type[(scope)] the
# message is written with, and the emoji used when SHELL_GIT_COMMIT_EMOJI is on.
# The type is one of build chore ci docs feat fix perf refactor revert style test
# (what shell::git::commit::message::validate accepts), so a label that is not a
# valid type itself ("initial source", "WIP", ...) is mapped onto one.
SHELL_GIT_COMMIT_TYPES="feat|feat|:sparkles:
fix|fix|:bug:
chore|chore|:wrench:
docs|docs|:books:
style|style|:art:
refactor|refactor|:recycle:
test|test|:white_check_mark:
perf|perf|:chart_with_upwards_trend:
WIP|chore(wip)|:construction:
improvement|perf|:zap:
revert|revert|:rewind:
security|fix(security)|:lock:
remove|refactor|:fire:
initial source|chore(init)|:tada:
logs|chore(logs)|:loud_sound:
config|chore(config)|:gear:
build|build|:hammer:
dependency|build(deps)|:package:
deployment|ci(deploy)|:rocket:
localization|feat(i18n)|:earth_americas:
search|feat(search)|:mag:
experimental|feat(experimental)|:alien:
version tag|chore(release)|:bookmark:
silent changes|chore|:mute:
deprecation|chore(deprecate)|:warning:
release|chore(release)|:gem:"

# `scope|description` per line: the second menu of shell::git::commit::create (sgcf).
# Once a type is picked (feat) the list is shown as a table, one row per scope:
# feat(docs), feat(git), ... plus "(no scope)", "custom" and "← Back". The same list
# is offered for every type, except those whose header already carries a scope
# (WIP → chore(wip), dependency → build(deps), ...). Extend or replace it from your
# profile; an explicitly empty value (SHELL_GIT_COMMIT_SCOPES="") skips the step.
: "${SHELL_GIT_COMMIT_SCOPES=api|Endpoints, handlers, request/response shapes
auth|Authentication and authorization
build|Build scripts, Makefile, packaging
ci|CI/CD pipelines and workflows
cli|Command-line interface, flags and help
config|Configuration and settings
core|Core logic and shared internals
db|Database, schema and migrations
deps|Dependencies and lockfiles
docs|Documentation, README and guides
git|Git helpers and hooks
i18n|Localization and translations
lib|Library and utility code
logs|Logging and diagnostics
perf|Performance
release|Versioning, changelog and release
security|Security hardening
test|Tests and fixtures
ui|User interface and styles}"

# `token|description` per line: the footers shell::git::commit::create (sgcf) offers
# under "Add footer" (Conventional Commits 1.0.0, rules 8-9: a token with `-` instead of
# spaces, except BREAKING CHANGE). Each one is committed as `Token: value`. Extend or
# replace the list from your profile; an explicitly empty value leaves only the
# "(custom token)" entry.
: "${SHELL_GIT_COMMIT_FOOTERS=BREAKING CHANGE|An incompatible API change (a MAJOR release)
Closes|Issue or pull request this commit closes
Fixes|Issue this commit fixes
Refs|Related issue, pull request, commit or document
Reviewed-by|Who reviewed the change
Co-authored-by|Co-author, as Name <email>
Signed-off-by|Sign-off (Developer Certificate of Origin)
Acked-by|Who acknowledged the change}"

# --- SSH ---------------------------------------------------------------------
# Keep-alive for tunnels and long sessions: seconds between probes, and how many
# unanswered probes are tolerated before ssh gives up (shell::ssh::tunnel::*).
: "${SHELL_SSH_KEEPALIVE_INTERVAL:=30}"
: "${SHELL_SSH_KEEPALIVE_COUNT:=3}"
# Seconds shell::ssh::check waits for the server.
: "${SHELL_SSH_CHECK_TIMEOUT:=5}"
# How long a multiplexed master connection stays open after its last session
# (ControlPersist written by shell::ssh::config::add --mux).
: "${SHELL_SSH_CONTROL_PERSIST:=10m}"

# --- rsync -------------------------------------------------------------------
# shell::rsync::mirror lets rsync delete at most this many files (--max-delete),
# then stops with status 25. A guard against a wrong source, not a preview: the
# files removed before the limit was reached stay removed.
: "${SHELL_RSYNC_MAX_DELETE:=1000}"
# Seconds without any data before rsync gives up (--timeout); used by shell::rsync::resume.
: "${SHELL_RSYNC_TIMEOUT:=120}"
# Where shell::rsync::resume keeps unfinished files, below the destination (--partial-dir).
: "${SHELL_RSYNC_PARTIAL_DIR:=.rsync-partial}"
# shell::rsync::resume starts rsync again this many times after a network failure,
# waiting <attempt> x SHELL_RSYNC_RETRY_DELAY seconds before each retry.
: "${SHELL_RSYNC_RETRIES:=5}"
: "${SHELL_RSYNC_RETRY_DELAY:=10}"

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

# --- Git history explorer ------------------------------------------------------
# Most commits loaded by shell::git::history::fzf (override with --max).
: "${SHELL_GIT_HISTORY_MAX:=500}"
# Widest the dashboard box is drawn (it shrinks to the terminal when narrower).
: "${SHELL_GIT_HISTORY_WIDTH:=72}"

# --- Logger style --------------------------------------------------------------
# Look of the level lines (debug / info / warn / error / fatal / success).
# Pick one with shell::logger::style::set (or ::set::fzf); see core/logger_style.sh.
SHELL_LOGGER_STYLES="simple classic"
# Used when nothing is saved and SHELL_LOGGER_STYLE is not exported.
: "${SHELL_LOGGER_STYLE_DEFAULT:=simple}"
SHELL_LOGGER_STYLE_DESC_SIMPLE="Coloured [tag] + plain message, as in pnguyen215/skills: [info]  text"
SHELL_LOGGER_STYLE_DESC_CLASSIC="Whole line coloured with a LEVEL: prefix (previous look): INFO: text"

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
