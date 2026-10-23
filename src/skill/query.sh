#!/usr/bin/env bash
# @file skill/query.sh
# @brief Read-only queries: which skills exist upstream, which are installed here.
# @description
#   Both functions print tab-separated rows on stdout (so they can be piped to
#   `cut`, `awk` or `fzf`) and align them in columns when stdout is a terminal.
#   They change nothing on disk.

# @internal
# @description Print the path of the installer's manifest file.
#   The manifest (`manifest.tsv`) lives under `XDG_STATE_HOME` and has one
#   tab-separated row per installed skill:
#   `tool scope skill target source mode timestamp`.
# @stdout Absolute path (the file may not exist).
# @exitcode 0 Always.
# @example
#   cat "$(shell::skill::manifest::file)"
#
shell::skill::manifest::file() {
	printf '%s/%s/manifest.tsv\n' "${XDG_STATE_HOME:-$HOME/.local/state}" "$SHELL_SKILL_STATE_NAME"
}

# @internal
# @description Print rows to stdout, aligned in columns when stdout is a terminal.
# @arg $1 string Tab-separated rows (one per line).
# @stdout The rows, as-is when piped, column-aligned on a terminal.
# @exitcode 0 Always.
# @example
#   shell::skill::print::rows "$rows"
#
shell::skill::print::rows() {
	if [ -t 1 ] && command -v column >/dev/null 2>&1; then
		printf '%s\n' "${1-}" | column -t -s "$(printf '\t')"
	else
		printf '%s\n' "${1-}"
	fi
}

# @description List the skills available upstream.
#   Downloads the upstream README and reads its generated skills table, so the
#   list is always current without cloning the repository.
# @option -r | --ref Branch, tag or commit to read (default: SHELL_SKILL_REPO_BRANCH).
# @option -h | --help Show help and return.
# @arg $1 string Optional case-insensitive text; only rows containing it are printed (category, slug or tag).
# @stdout One row per skill: `category<TAB>skill<TAB>tags`.
# @exitcode 0 At least one skill was printed.
# @exitcode 1 The README could not be downloaded or has no skills table.
# @exitcode 2 Invalid option or value.
# @exitcode 8 No skill matches the filter.
# @example
#   shell::skill::list
#   shell::skill::list golang
#   shell::skill::list --ref v1.0.0 security | cut -f2
#
shell::skill::list() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List the agent skills available upstream"
		shell::logger::usage "shell::skill::list [-r <ref>] [filter]"
		shell::logger::item "filter" "Only rows containing this text (category, slug or tag)"
		shell::logger::option "-r, --ref <ref>" "Branch, tag or commit (default: $SHELL_SKILL_REPO_BRANCH)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::skill::list"
		shell::logger::example "shell::skill::list golang"
		return "$RETURN_SUCCESS"
	fi

	local ref="" filter="" opt val
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-r | --ref | --ref=*)
			opt="$1"
			case "$opt" in
			--ref=*)
				val="${opt#*=}"
				shift
				;;
			*)
				if [ "$#" -lt 2 ]; then
					shell::logger::error "Option $opt requires a value"
					return "$RETURN_INVALID"
				fi
				val="$2"
				shift 2
				;;
			esac
			ref="$val"
			;;
		-*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*)
			if [ -n "$filter" ]; then
				shell::logger::error "Only one filter is accepted"
				return "$RETURN_INVALID"
			fi
			filter="$1"
			shift
			;;
		esac
	done

	if [ -n "$ref" ] && ! shell::skill::validate::ref "$ref"; then
		shell::logger::error "Invalid --ref '$ref'"
		return "$RETURN_INVALID"
	fi

	shell::dependency::curl::ensure || return $?

	local url="$SHELL_SKILL_URL_RAW_HOST/$SHELL_SKILL_REPO_SLUG/${ref:-$SHELL_SKILL_REPO_BRANCH}/README.md"
	local readme
	if ! readme="$(curl -fsSL --connect-timeout "$SHELL_NET_CONNECT_TIMEOUT" --max-time "$SHELL_NET_MAX_TIME" "$url")"; then
		shell::logger::error "Failed to download $url"
		return "$RETURN_FAILURE"
	fi

	# Table rows look like: | `category` | `skill` | `tag`, `tag` |
	local rows
	rows="$(printf '%s\n' "$readme" | awk -F'|' -v start="$SHELL_SKILL_TABLE_START" -v end="$SHELL_SKILL_TABLE_END" '
		index($0, start) { on = 1; next }
		index($0, end) { on = 0 }
		on && $0 ~ /^\|/ {
			for (i = 2; i <= 4; i++) {
				gsub(/`/, "", $i)
				gsub(/^[ \t]+|[ \t]+$/, "", $i)
			}
			if ($2 == "Category" || $2 ~ /^-+$/) next
			printf "%s\t%s\t%s\n", $2, $3, $4
		}')"

	if [ -z "$rows" ]; then
		shell::logger::error "No skills table found in $url"
		return "$RETURN_FAILURE"
	fi

	if [ -n "$filter" ]; then
		rows="$(printf '%s\n' "$rows" | grep -iF -- "$filter")"
		if [ -z "$rows" ]; then
			shell::logger::warn "No skill matches '$filter'"
			return "$RETURN_EMPTY"
		fi
	fi

	shell::skill::print::rows "$rows"
}

# @description List the skills installed by shell::skill::install.
#   Reads the installer's manifest, so it only reports what this tool placed
#   (not skills you added to the tool's directories by hand).
# @option -t | --tool Only this tool: claude or opencode.
# @option -s | --scope Only this scope: personal or project.
# @option -h | --help Show help and return.
# @arg $1 string Optional case-insensitive text; only rows containing it are printed.
# @stdout One row per installed skill: `tool<TAB>scope<TAB>skill<TAB>mode<TAB>path`.
# @exitcode 0 At least one installed skill was printed.
# @exitcode 2 Invalid option or value.
# @exitcode 8 Nothing is installed (or nothing matches).
# @example
#   shell::skill::installed
#   shell::skill::installed -t claude -s personal
#   shell::skill::installed golang | cut -f3
#
shell::skill::installed() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List the agent skills installed by shell::skill::install"
		shell::logger::usage "shell::skill::installed [-t <tool>] [-s <scope>] [filter]"
		shell::logger::item "filter" "Only rows containing this text"
		shell::logger::option "-t, --tool <name>" "claude | opencode"
		shell::logger::option "-s, --scope <name>" "personal | project"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::skill::installed"
		shell::logger::example "shell::skill::installed -t claude -s personal"
		return "$RETURN_SUCCESS"
	fi

	local tool="" scope="" filter="" opt val
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-t | --tool | -s | --scope | --tool=* | --scope=*)
			opt="$1"
			case "$opt" in
			--*=*)
				val="${opt#*=}"
				opt="${opt%%=*}"
				shift
				;;
			*)
				if [ "$#" -lt 2 ]; then
					shell::logger::error "Option $opt requires a value"
					return "$RETURN_INVALID"
				fi
				val="$2"
				shift 2
				;;
			esac
			case "$opt" in
			-t | --tool) tool="$val" ;;
			-s | --scope) scope="$val" ;;
			esac
			;;
		-*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*)
			if [ -n "$filter" ]; then
				shell::logger::error "Only one filter is accepted"
				return "$RETURN_INVALID"
			fi
			filter="$1"
			shift
			;;
		esac
	done

	if [ -n "$tool" ] && ! shell::skill::validate::choice "$tool" "claude opencode"; then
		shell::logger::error "Invalid --tool '$tool' (expected: claude opencode)"
		return "$RETURN_INVALID"
	fi
	if [ -n "$scope" ] && ! shell::skill::validate::choice "$scope" "personal project"; then
		shell::logger::error "Invalid --scope '$scope' (expected: personal project)"
		return "$RETURN_INVALID"
	fi

	local file
	file="$(shell::skill::manifest::file)"
	if [ ! -s "$file" ]; then
		shell::logger::warn "No skills installed yet (run shell::skill::install)"
		return "$RETURN_EMPTY"
	fi

	# manifest columns: 1 tool, 2 scope, 3 skill, 4 target, 5 source, 6 mode, 7 timestamp
	local rows
	rows="$(awk -F'\t' -v t="$tool" -v s="$scope" '
		(t == "" || $1 == t) && (s == "" || $2 == s) { printf "%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $6, $4 }
	' "$file")"

	if [ -n "$filter" ] && [ -n "$rows" ]; then
		rows="$(printf '%s\n' "$rows" | grep -iF -- "$filter")"
	fi

	if [ -z "$rows" ]; then
		shell::logger::warn "No installed skill matches"
		return "$RETURN_EMPTY"
	fi

	shell::skill::print::rows "$rows"
}
