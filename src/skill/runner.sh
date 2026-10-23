#!/usr/bin/env bash
# @file skill/runner.sh
# @brief Shared engine behind shell::skill::install / upgrade / uninstall / sync.
# @description
#   The skills library (https://github.com/pnguyen215/skills) is a set of
#   standalone installers (`install.sh`, `upgrade.sh`, `uninstall.sh`,
#   `sync_claude.sh`, `sync_opencode.sh`). This module does not re-implement
#   them: it validates the options, downloads the matching script from
#   `SHELL_SKILL_REPO_SLUG` and runs it with `bash`, through
#   `shell::net::run_remote_script` (download first, check it is not empty,
#   then execute; no `curl | bash`).
#
#   The scripts never use `sudo` and only write below `$HOME` or an explicit
#   `--project-dir`.

# @internal
# @description Check that a value is exactly one of a list of words.
#   The list is matched as a string, so it behaves the same in bash and zsh
#   (an unquoted `for w in $list` does not word-split in zsh).
# @arg $1 string Value to check.
# @arg $2 string Space-separated list of accepted words.
# @exitcode 0 The value is in the list.
# @exitcode 1 The value is empty, contains whitespace, or is not in the list.
# @example
#   shell::skill::validate::choice "claude" "$SHELL_SKILL_TOOLS"
#
shell::skill::validate::choice() {
	case "${1-}" in
	'' | *[[:space:]]*) return 1 ;;
	esac
	case " ${2-} " in
	*" $1 "*) return 0 ;;
	esac
	return 1
}

# @internal
# @description Check a comma-separated list of skill slugs (`a,b,c`).
#   Slugs are kebab-case, so only `a-z`, `0-9`, `-` and `,` are accepted and
#   the value may not start with `-` (it would be read as an option).
# @arg $1 string Skill list.
# @exitcode 0 Valid.
# @exitcode 1 Invalid.
# @example
#   shell::skill::validate::slugs "golang,security-secure-coding"
#
shell::skill::validate::slugs() {
	case "${1-}" in
	'' | -* | *[!a-z0-9,-]*) return 1 ;;
	esac
	return 0
}

# @internal
# @description Check a git ref (branch, tag or commit).
# @arg $1 string Ref name.
# @exitcode 0 Valid.
# @exitcode 1 Invalid (empty, starts with `-`, or has unusual characters).
# @example
#   shell::skill::validate::ref "v1.2.0"
#
shell::skill::validate::ref() {
	case "${1-}" in
	'' | -* | *[!A-Za-z0-9._/-]*) return 1 ;;
	esac
	return 0
}

# @internal
# @description Print the options shared by every skill command, for `-h`.
#   Only the options that make sense for the command are listed, selected by
#   the first argument.
# @arg $1 string Command kind: `install`, `upgrade`, `uninstall` or `sync`.
# @stdout The option lines of a help block.
# @exitcode 0 Always.
# @example
#   shell::skill::help::options install
#
shell::skill::help::options() {
	local kind="${1-}"

	if [ "$kind" != "sync" ]; then
		shell::logger::option "-t, --tool <name>" "claude | opencode | all (default: all)"
	fi
	shell::logger::option "-s, --scope <name>" "personal | project | all (default: personal)"
	shell::logger::option "-p, --project-dir <dir>" "Project root for scope project/all (default: current dir)"
	if [ "$kind" != "uninstall" ]; then
		shell::logger::option "-m, --mode <name>" "auto | symlink | copy (default: auto)"
	fi
	shell::logger::option "-k, --skills <a,b,c>" "Only act on these skill slugs (default: all)"
	shell::logger::option "-r, --ref <ref>" "Branch, tag or commit (default: $SHELL_SKILL_REPO_BRANCH)"
	case "$kind" in
	upgrade) shell::logger::option "--no-new" "Do not install skills added upstream" ;;
	uninstall)
		shell::logger::option "--purge" "Also delete the manifest, backups and cached clone"
		shell::logger::option "--no-sweep" "Only remove manifest-tracked entries"
		;;
	sync) shell::logger::option "--no-prune" "Keep skills that were deleted upstream" ;;
	esac
	shell::logger::option "-y, --yes" "Assume yes to prompts (required when not interactive)"
	shell::logger::option "-v, --verbose" "Print debug-level lines from the skills installer"
	shell::logger::option "--preview" "Let the installer print what it would do, changing nothing"
	shell::logger::option "-n, --dry-run" "Print the download command instead of running it"
	shell::logger::option "-h, --help" "Display this help message"
}

# @internal
# @description Validate the options, then download and run one skills script.
#   Value options accept `--opt value` and `--opt=value`. Every value is
#   validated here, before anything is downloaded, and is passed to the script
#   as a separate argument (never through `eval`).
#
#   `-n` / `--dry-run` follows the library convention: print the command and
#   change nothing. The installer's own preview (`--dry-run` upstream) is
#   exposed as `--preview`.
#
#   Exit statuses of the script are mapped to the library's return codes.
# @option -t | --tool Target tool: claude, opencode or all (not for sync).
# @option -s | --scope Install scope: personal, project or all.
# @option -p | --project-dir Project root used by scope project/all.
# @option -m | --mode How content is placed: auto, symlink or copy.
# @option -k | --skills Comma-separated skill slugs.
# @option -r | --ref Git ref to fetch.
# @option -y | --yes Assume yes to prompts.
# @option -v | --verbose Verbose installer output.
# @option --preview Run the installer in its own dry-run mode.
# @option -n | --dry-run Print the download command; do not run it.
# @arg $1 string Script name without `.sh`: install, upgrade, uninstall, sync_claude or sync_opencode.
# @arg $@ string Options (see above) plus the script-specific flags `--no-new`, `--purge`, `--no-sweep`, `--no-prune`.
# @exitcode 0 The script succeeded (or dry-run printed the command).
# @exitcode 1 Download failed, or the script failed (filesystem or network error).
# @exitcode 2 Invalid or unknown option, or invalid value.
# @exitcode 3 A required directory or prerequisite was not found.
# @example
#   shell::skill::run install --tool claude --yes
#   shell::skill::run upgrade -n --scope project --project-dir "$PWD"
#
shell::skill::run() {
	local script="${1-}"
	if [ -z "$script" ]; then
		shell::logger::error "A skills script name is required"
		return "$RETURN_INVALID"
	fi
	shift

	local dry_run="false"
	local tool="" scope="" project_dir="" mode="" skills="" ref=""
	local opt val
	local fwd=()

	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		--preview)
			fwd+=("--dry-run")
			shift
			;;
		-y | --yes)
			fwd+=("--yes")
			shift
			;;
		-v | --verbose)
			fwd+=("--verbose")
			shift
			;;
		--no-new | --purge | --no-sweep | --no-prune)
			# Script-specific flags: accepted only by the script that owns them.
			case "$script:$1" in
			upgrade:--no-new | uninstall:--purge | uninstall:--no-sweep | sync_claude:--no-prune | sync_opencode:--no-prune)
				fwd+=("$1")
				shift
				;;
			*)
				shell::logger::error "Option $1 is not supported by '$script'"
				return "$RETURN_INVALID"
				;;
			esac
			;;
		-t | --tool | -s | --scope | -p | --project-dir | -m | --mode | -k | --skills | -r | --ref | --tool=* | --scope=* | --project-dir=* | --mode=* | --skills=* | --ref=*)
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
			-p | --project-dir) project_dir="$val" ;;
			-m | --mode) mode="$val" ;;
			-k | --skills) skills="$val" ;;
			-r | --ref) ref="$val" ;;
			esac
			;;
		*)
			shell::logger::error "Unknown option or argument: $1"
			return "$RETURN_INVALID"
			;;
		esac
	done

	# --- Validate everything before any network access
	if [ -n "$tool" ]; then
		case "$script" in
		sync_*)
			shell::logger::error "--tool is fixed for '$script'"
			return "$RETURN_INVALID"
			;;
		esac
		if ! shell::skill::validate::choice "$tool" "$SHELL_SKILL_TOOLS"; then
			shell::logger::error "Invalid --tool '$tool' (expected: $SHELL_SKILL_TOOLS)"
			return "$RETURN_INVALID"
		fi
	fi
	if [ -n "$scope" ] && ! shell::skill::validate::choice "$scope" "$SHELL_SKILL_SCOPES"; then
		shell::logger::error "Invalid --scope '$scope' (expected: $SHELL_SKILL_SCOPES)"
		return "$RETURN_INVALID"
	fi
	if [ -n "$mode" ] && ! shell::skill::validate::choice "$mode" "$SHELL_SKILL_MODES"; then
		shell::logger::error "Invalid --mode '$mode' (expected: $SHELL_SKILL_MODES)"
		return "$RETURN_INVALID"
	fi
	if [ -n "$skills" ] && ! shell::skill::validate::slugs "$skills"; then
		shell::logger::error "Invalid --skills '$skills' (use comma-separated kebab-case slugs)"
		return "$RETURN_INVALID"
	fi
	if [ -n "$ref" ] && ! shell::skill::validate::ref "$ref"; then
		shell::logger::error "Invalid --ref '$ref'"
		return "$RETURN_INVALID"
	fi
	if [ -n "$project_dir" ]; then
		case "$project_dir" in
		-*)
			shell::logger::error "Invalid --project-dir '$project_dir'"
			return "$RETURN_INVALID"
			;;
		esac
		if [ ! -d "$project_dir" ]; then
			shell::logger::error "Project directory not found: $project_dir"
			return "$RETURN_NOT_FOUND"
		fi
	fi

	# --- Build the script's argument list (only what the caller set)
	if [ -n "$tool" ]; then fwd+=(--tool "$tool"); fi
	if [ -n "$scope" ]; then fwd+=(--scope "$scope"); fi
	if [ -n "$project_dir" ]; then fwd+=(--project-dir "$project_dir"); fi
	if [ -n "$mode" ]; then fwd+=(--mode "$mode"); fi
	if [ -n "$skills" ]; then fwd+=(--skills "$skills"); fi
	if [ -n "$ref" ]; then fwd+=(--ref "$ref"); fi

	local effective_ref="${ref:-$SHELL_SKILL_REPO_BRANCH}"
	local url="$SHELL_SKILL_URL_RAW_HOST/$SHELL_SKILL_REPO_SLUG/$effective_ref/$script.sh"

	if [ "$dry_run" = "true" ]; then
		AGENT_SKILLS_REPO="$SHELL_SKILL_REPO_SLUG" AGENT_SKILLS_REF="$effective_ref" \
			shell::net::run_remote_script -n "$url" bash ${fwd[@]+"${fwd[@]}"}
		return "$RETURN_SUCCESS"
	fi

	# AGENT_SKILLS_* tell the script which repository/ref to fetch the skill
	# content (and its helper lib.sh) from; they apply to this call only.
	local rc=0
	AGENT_SKILLS_REPO="$SHELL_SKILL_REPO_SLUG" AGENT_SKILLS_REF="$effective_ref" \
		shell::net::run_remote_script "$url" bash ${fwd[@]+"${fwd[@]}"} || rc=$?

	case "$rc" in
	0) return "$RETURN_SUCCESS" ;;
	2) rc="$RETURN_INVALID" ;;
	3) rc="$RETURN_NOT_FOUND" ;;
	*) rc="$RETURN_FAILURE" ;;
	esac
	shell::logger::error "$script.sh failed (return code $rc)"
	return "$rc"
}
