#!/usr/bin/env bash
# @file core/logger_style.sh
# @brief Pluggable look for log lines, plus functions to list, pick and save a style.
# @description
#   A *style* decides how one level line is drawn; it never changes whether the
#   line is printed (threshold, `SHELL_LOGGER_LEVEL`) or where it goes (INFO and
#   success on stdout, the rest on stderr).
#
#   | Style     | Look                       | Notes                                         |
#   |-----------|----------------------------|-----------------------------------------------|
#   | `simple`  | `[info]  text`             | Default. Only the tag is coloured, and only on a terminal (as in pnguyen215/skills). |
#   | `classic` | `INFO: text`               | The previous look: the whole line coloured.   |
#
#   Which style is active is resolved once at load time, first match wins:
#
#   1. `SHELL_LOGGER_STYLE` exported by the user before sourcing the library;
#   2. the style saved by shell::logger::style::set (`SHELL_LOGGER_CONF_FILE`);
#   3. `SHELL_LOGGER_STYLE_DEFAULT` (`simple`).
#
#   Only the level lines (debug, info, warn, error, fatal, success) follow the
#   style. Help blocks (usage / option / example), steps and sections keep their
#   own layout.

# @internal
# @description Check that a name is a known logger style.
# @arg $1 string Style name.
# @exitcode 0 Known style.
# @exitcode 1 Empty, contains whitespace, or unknown.
# @example
#   shell::logger::style::valid classic
#
shell::logger::style::valid() {
	case "${1-}" in
	'' | *[[:space:]]*) return 1 ;;
	esac
	case " $SHELL_LOGGER_STYLES " in
	*" $1 "*) return 0 ;;
	esac
	return 1
}

# @internal
# @description Render one level line in the `simple` style: `[tag]  message`.
#   The tag is coloured with a basic SGR code only when the target stream is a
#   terminal, colours are available and `NO_COLOR` is unset, so captured or
#   piped output stays free of escape sequences.
# @arg $1 string Level: DEBUG, INFO, WARN, ERROR, FATAL or SUCCESS.
# @arg $2 integer 256-colour code (ignored by this style).
# @arg $3 string Stream: "stdout" or "stderr".
# @arg $@ string Message words.
# @stdout The line, when the stream is stdout.
# @stderr The line, when the stream is stderr.
# @exitcode 0 Always.
# @example
#   shell::logger::style::simple INFO 33 stdout "hello"
#
shell::logger::style::simple() {
	local level="${1-}" stream="${3-stdout}"
	shift 3

	local word="" sgr=""
	case "$level" in
	DEBUG)
		word="$SHELL_LOGGER_TAG_DEBUG"
		sgr="$SHELL_LOGGER_SGR_DEBUG"
		;;
	INFO)
		word="$SHELL_LOGGER_TAG_INFO"
		sgr="$SHELL_LOGGER_SGR_INFO"
		;;
	WARN)
		word="$SHELL_LOGGER_TAG_WARN"
		sgr="$SHELL_LOGGER_SGR_WARN"
		;;
	ERROR)
		word="$SHELL_LOGGER_TAG_ERROR"
		sgr="$SHELL_LOGGER_SGR_ERROR"
		;;
	FATAL)
		word="$SHELL_LOGGER_TAG_FATAL"
		sgr="$SHELL_LOGGER_SGR_FATAL"
		;;
	SUCCESS)
		word="$SHELL_LOGGER_TAG_SUCCESS"
		sgr="$SHELL_LOGGER_SGR_SUCCESS"
		;;
	*) word="[$level]" ;;
	esac

	local fd=1
	if [ "$stream" = "stderr" ]; then
		fd=2
	fi

	local on="" off=""
	if [ -n "$sgr" ] && [ -t "$fd" ]; then
		shell::console::detect_colors
		if [ "$_SHELL_CONSOLE_COLORS" -ge 8 ]; then
			on=$'\033['"$sgr"'m'
			off=$'\033[0m'
		fi
	fi

	# Pad the tag so messages line up; always leave at least one space.
	local pad=$((SHELL_LOGGER_TAG_WIDTH - ${#word}))
	if [ "$pad" -lt 1 ]; then
		pad=1
	fi

	if [ "$fd" = "2" ]; then
		printf '%s%s%s%*s%s\n' "$on" "$word" "$off" "$pad" "" "$*" >&2
	else
		printf '%s%s%s%*s%s\n' "$on" "$word" "$off" "$pad" "" "$*"
	fi
}

# @internal
# @description Render one level line in the `classic` style: `LEVEL: message`.
#   The whole line is coloured with the level's 256-colour code (the look the
#   library had before styles existed).
# @arg $1 string Level: DEBUG, INFO, WARN, ERROR, FATAL or SUCCESS (printed as INFO).
# @arg $2 integer 256-colour code.
# @arg $3 string Stream: "stdout" or "stderr".
# @arg $@ string Message words.
# @stdout The line, when the stream is stdout.
# @stderr The line, when the stream is stderr.
# @exitcode 0 Always.
# @example
#   shell::logger::style::classic ERROR 196 stderr "disk full"
#
shell::logger::style::classic() {
	local label="${1-}" color="${2-}" stream="${3-stdout}"
	shift 3

	if [ "$label" = "SUCCESS" ]; then
		label="INFO"
	fi

	if [ "$stream" = "stderr" ]; then
		shell::console::print "$label: $*" "$color" >&2
	else
		shell::console::print "$label: $*" "$color"
	fi
}

# @internal
# @description Render one level line with a named style (no threshold check).
#   An unknown name falls back to `SHELL_LOGGER_STYLE_DEFAULT`, so a typo in
#   `SHELL_LOGGER_STYLE` never silences or breaks logging.
# @arg $1 string Style name.
# @arg $2 string Level: DEBUG, INFO, WARN, ERROR, FATAL or SUCCESS.
# @arg $3 integer 256-colour code.
# @arg $4 string Stream: "stdout" or "stderr".
# @arg $@ string Message words.
# @exitcode 0 Always.
# @example
#   shell::logger::style::render classic WARN 11 stderr "careful"
#
shell::logger::style::render() {
	local style="${1-}"
	shift

	if ! shell::logger::style::valid "$style"; then
		style="$SHELL_LOGGER_STYLE_DEFAULT"
	fi

	case "$style" in
	classic) shell::logger::style::classic "$@" ;;
	*) shell::logger::style::simple "$@" ;;
	esac
}

# @internal
# @description Print the saved style name, if there is a valid one.
# @stdout The saved style (nothing when none is saved or the file is invalid).
# @exitcode 0 Always.
# @example
#   saved="$(shell::logger::style::read)"
#
shell::logger::style::read() {
	local key value
	[ -r "$SHELL_LOGGER_CONF_FILE" ] || return "$RETURN_SUCCESS"

	while IFS='=' read -r key value || [ -n "$key" ]; do
		if [ "$key" = "style" ] && shell::logger::style::valid "$value"; then
			printf '%s\n' "$value"
			return "$RETURN_SUCCESS"
		fi
	done <"$SHELL_LOGGER_CONF_FILE"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Save a style so future sessions start with it.
#   Written atomically (temp file, then rename) with mode 600 in a mode 700
#   directory; nothing is left behind on failure and no trap is installed.
# @arg $1 string A valid style name.
# @exitcode 0 Saved.
# @exitcode 1 The file could not be written.
# @example
#   shell::logger::style::save classic
#
shell::logger::style::save() {
	local style="${1-}"
	local dir="${SHELL_LOGGER_CONF_FILE%/*}"
	local tmp="$SHELL_LOGGER_CONF_FILE.tmp.$$"

	if [ ! -d "$dir" ]; then
		mkdir -p "$dir" && chmod 700 "$dir" || return "$RETURN_FAILURE"
	fi

	if ! (umask 077 && printf 'style=%s\n' "$style" >"$tmp"); then
		rm -f "$tmp"
		return "$RETURN_FAILURE"
	fi
	mv -f "$tmp" "$SHELL_LOGGER_CONF_FILE" || {
		rm -f "$tmp"
		return "$RETURN_FAILURE"
	}
}

# @internal
# @description Resolve the active style once: exported variable, then saved, then default.
#   Called by the loader (src/shell.sh) after every module is sourced. An
#   invalid `SHELL_LOGGER_STYLE` is ignored.
# @set SHELL_LOGGER_STYLE string The resolved style name.
# @exitcode 0 Always.
# @example
#   shell::logger::style::load
#
shell::logger::style::load() {
	if [ -n "${SHELL_LOGGER_STYLE-}" ] && shell::logger::style::valid "$SHELL_LOGGER_STYLE"; then
		return "$RETURN_SUCCESS"
	fi

	local saved=""
	if [ -r "$SHELL_LOGGER_CONF_FILE" ]; then
		saved="$(shell::logger::style::read)"
	fi
	SHELL_LOGGER_STYLE="${saved:-$SHELL_LOGGER_STYLE_DEFAULT}"
	return "$RETURN_SUCCESS"
}

# @description Print the name of the active logger style.
# @option -h | --help Show help and return.
# @stdout The style name (`simple` or `classic`).
# @exitcode 0 Always.
# @example
#   shell::logger::style::get
#
shell::logger::style::get() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Print the active logger style"
		shell::logger::usage "shell::logger::style::get"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::logger::style::get"
		return "$RETURN_SUCCESS"
	fi

	local style="${SHELL_LOGGER_STYLE:-$SHELL_LOGGER_STYLE_DEFAULT}"
	if ! shell::logger::style::valid "$style"; then
		style="$SHELL_LOGGER_STYLE_DEFAULT"
	fi
	printf '%s\n' "$style"
}

# @description List the available logger styles.
# @option -h | --help Show help and return.
# @stdout One row per style: `name<TAB>description`.
# @exitcode 0 Always.
# @example
#   shell::logger::style::list
#   shell::logger::style::list | cut -f1
#
shell::logger::style::list() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List the available logger styles"
		shell::logger::usage "shell::logger::style::list"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::logger::style::list"
		return "$RETURN_SUCCESS"
	fi

	printf 'simple\t%s\n' "$SHELL_LOGGER_STYLE_DESC_SIMPLE"
	printf 'classic\t%s\n' "$SHELL_LOGGER_STYLE_DESC_CLASSIC"
}

# @description Show one sample line per level in a style, without changing it.
#   Ignores the log threshold so every level is always shown.
# @option -h | --help Show help and return.
# @arg $1 string Style to preview (default: the active style).
# @stdout Six sample lines (debug, info, warn, error, fatal, success).
# @exitcode 0 Shown.
# @exitcode 2 Unknown style.
# @example
#   shell::logger::style::preview
#   shell::logger::style::preview classic
#
shell::logger::style::preview() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show a sample of every log level in a style"
		shell::logger::usage "shell::logger::style::preview [style]"
		shell::logger::item "style" "Style to preview (default: the active one)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::logger::style::preview classic"
		return "$RETURN_SUCCESS"
	fi

	local style="${1:-$(shell::logger::style::get)}"
	if ! shell::logger::style::valid "$style"; then
		shell::logger::error "Unknown logger style '$style' (expected: $SHELL_LOGGER_STYLES)"
		return "$RETURN_INVALID"
	fi

	shell::logger::style::render "$style" DEBUG "$SHELL_COLOR_DEBUG" stdout "Sample debug message"
	shell::logger::style::render "$style" INFO "$SHELL_COLOR_INFO" stdout "Sample info message"
	shell::logger::style::render "$style" WARN "$SHELL_COLOR_WARN" stdout "Sample warning message"
	shell::logger::style::render "$style" ERROR "$SHELL_COLOR_ERROR" stdout "Sample error message"
	shell::logger::style::render "$style" FATAL "$SHELL_COLOR_FATAL" stdout "Sample fatal message"
	shell::logger::style::render "$style" SUCCESS "$SHELL_COLOR_SUCCESS" stdout "Sample success message"
}

# @description Apply a logger style, and save it for future sessions.
#   The style takes effect immediately in the current shell. Unless
#   `--session` is given it is also written to `SHELL_LOGGER_CONF_FILE`, so new
#   shells start with it. An exported `SHELL_LOGGER_STYLE` still wins over the
#   saved value at load time.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print what would change instead of changing it.
# @option -s | --session Apply to this shell only; do not save.
# @arg $1 string Style name: `simple` or `classic`.
# @set SHELL_LOGGER_STYLE string The new style.
# @exitcode 0 Applied (and saved, unless --session).
# @exitcode 1 Applied, but saving failed.
# @exitcode 2 Missing or unknown style, or unknown option.
# @see shell::logger::style::set::fzf
# @example
#   shell::logger::style::set classic
#   shell::logger::style::set --session simple
#   shell::logger::style::set -n classic
#
shell::logger::style::set() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Apply a logger style (and save it for future sessions)"
		shell::logger::usage "shell::logger::style::set [-n] [-s] <style>"
		shell::logger::item "style" "simple | classic"
		shell::logger::option "-n, --dry-run" "Print what would change instead of changing it"
		shell::logger::option "-s, --session" "Apply to this shell only; do not save"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::logger::style::set classic"
		shell::logger::example "shell::logger::style::set --session simple"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" save="true" style=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		-s | --session)
			save="false"
			shift
			;;
		-*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*)
			if [ -n "$style" ]; then
				shell::logger::error "Only one style can be given"
				return "$RETURN_INVALID"
			fi
			style="$1"
			shift
			;;
		esac
	done

	if [ -z "$style" ]; then
		shell::logger::error "A style is required (expected: $SHELL_LOGGER_STYLES)"
		return "$RETURN_INVALID"
	fi
	if ! shell::logger::style::valid "$style"; then
		shell::logger::error "Unknown logger style '$style' (expected: $SHELL_LOGGER_STYLES)"
		return "$RETURN_INVALID"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "SHELL_LOGGER_STYLE=$style"
		if [ "$save" = "true" ]; then
			shell::logger::command_clip "printf 'style=%s\\n' $style > $SHELL_LOGGER_CONF_FILE"
		fi
		return "$RETURN_SUCCESS"
	fi

	SHELL_LOGGER_STYLE="$style"

	if [ "$save" = "true" ]; then
		if ! shell::logger::style::save "$style"; then
			shell::logger::warn "Logger style '$style' applied, but could not be saved to $SHELL_LOGGER_CONF_FILE"
			return "$RETURN_FAILURE"
		fi
		shell::logger::success "Logger style set to '$style' (saved)"
	else
		shell::logger::success "Logger style set to '$style' (this shell only)"
	fi
}

# @description Pick the logger style interactively with fzf.
#   Lists every style with its description (the active one is marked), then
#   applies the choice with shell::logger::style::set and shows a sample of
#   every level in it.
# @option -h | --help Show help and return.
# @option -n | --dry-run Pick, then print what would change instead of changing it.
# @option -s | --session Apply to this shell only; do not save.
# @exitcode 0 Applied.
# @exitcode 1 Applied, but saving failed.
# @exitcode 3 fzf is not installed and could not be installed.
# @exitcode 9 The user cancelled.
# @see shell::logger::style::set
# @example
#   shell::logger::style::set::fzf
#   shell::logger::style::set::fzf --session
#
shell::logger::style::set::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick the logger style with fzf"
		shell::logger::usage "shell::logger::style::set::fzf [-n] [-s]"
		shell::logger::option "-n, --dry-run" "Print what would change instead of changing it"
		shell::logger::option "-s, --session" "Apply to this shell only; do not save"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::logger::style::set::fzf"
		shell::logger::example "shell::logger::style::set::fzf --session"
		return "$RETURN_SUCCESS"
	fi

	local flags=()
	local dry_run="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			flags+=("-n")
			shift
			;;
		-s | --session)
			flags+=("-s")
			shift
			;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
	done

	local current name description marker rows=""
	current="$(shell::logger::style::get)"
	while IFS=$'\t' read -r name description; do
		marker=""
		if [ "$name" = "$current" ]; then
			marker="  (current)"
		fi
		rows="${rows}$(printf '%-9s %s%s' "$name" "$description" "$marker")"$'\n'
	done < <(shell::logger::style::list)

	local selection rc
	selection="$(printf '%s' "$rows" | shell::fzf::select --prompt="Logger style: ")"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		return "$rc"
	fi

	# The name is the first word of the chosen row.
	local chosen="${selection%% *}"
	shell::logger::style::set ${flags[@]+"${flags[@]}"} "$chosen" || return $?

	if [ "$dry_run" = "false" ]; then
		shell::logger::style::preview "$chosen"
	fi
}

# @description Go back to the default logger style and forget the saved one.
#   Applies `SHELL_LOGGER_STYLE_DEFAULT` now and deletes `SHELL_LOGGER_CONF_FILE`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print what would change instead of changing it.
# @set SHELL_LOGGER_STYLE string The default style.
# @exitcode 0 Reset.
# @exitcode 1 The saved file could not be removed.
# @exitcode 2 Unknown option.
# @example
#   shell::logger::style::reset
#   shell::logger::style::reset -n
#
shell::logger::style::reset() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Restore the default logger style and forget the saved one"
		shell::logger::usage "shell::logger::style::reset [-n]"
		shell::logger::option "-n, --dry-run" "Print what would change instead of changing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::logger::style::reset"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	case "${1-}" in
	'') ;;
	-n | --dry-run) dry_run="true" ;;
	*)
		shell::logger::error "Unknown option: $1"
		return "$RETURN_INVALID"
		;;
	esac

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "SHELL_LOGGER_STYLE=$SHELL_LOGGER_STYLE_DEFAULT"
		shell::logger::command_clip "rm -f $SHELL_LOGGER_CONF_FILE"
		return "$RETURN_SUCCESS"
	fi

	SHELL_LOGGER_STYLE="$SHELL_LOGGER_STYLE_DEFAULT"
	rm -f "$SHELL_LOGGER_CONF_FILE" || {
		shell::logger::error "Could not remove $SHELL_LOGGER_CONF_FILE"
		return "$RETURN_FAILURE"
	}
	shell::logger::success "Logger style reset to '$SHELL_LOGGER_STYLE_DEFAULT'"
}
