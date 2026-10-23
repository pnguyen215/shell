#!/usr/bin/env bash
# @file skill/manage.sh
# @brief Install, upgrade, uninstall and sync agent skills (Claude Code, OpenCode).
# @description
#   Wrappers around the installers of https://github.com/pnguyen215/skills.
#   Skills are `SKILL.md` folders placed (symlinked by default) in:
#
#   | Tool        | Personal scope                      | Project scope                      |
#   |-------------|-------------------------------------|------------------------------------|
#   | Claude Code | `~/.claude/skills/<name>`           | `<project>/.claude/skills/<name>`  |
#   | OpenCode    | `~/.config/opencode/skills/<name>`  | `<project>/.opencode/skills/<name>`|
#
#   Every function validates its options, downloads the matching script and
#   runs it with bash (see shell::skill::run). Restart your Claude Code /
#   OpenCode session afterwards so the new skills are loaded.
#
#   The upstream repository can be changed with `SHELL_SKILL_REPO_SLUG` and
#   `SHELL_SKILL_REPO_BRANCH` (see constant/skill.sh).

# @description Install skills into Claude Code and/or OpenCode.
#   Idempotent: running it again with the same options changes nothing. Any
#   pre-existing, non-managed skill directory is backed up before it is
#   replaced. Nothing is ever written outside `$HOME` or `--project-dir`.
# @option -t | --tool Target tool: claude, opencode or all (default: all).
# @option -s | --scope Scope: personal, project or all (default: personal).
# @option -p | --project-dir Project root for scope project/all (default: current directory).
# @option -m | --mode Placement: auto, symlink or copy (default: auto).
# @option -k | --skills Comma-separated skill slugs (default: every skill).
# @option -r | --ref Branch, tag or commit to install from.
# @option -y | --yes Assume yes to prompts (required when not interactive).
# @option -v | --verbose Verbose installer output.
# @option --preview Let the installer print what it would do, changing nothing.
# @option -n | --dry-run Print the download command instead of running it.
# @option -h | --help Show help and return.
# @exitcode 0 Installed (or the command was printed).
# @exitcode 1 Download or installation failed.
# @exitcode 2 Invalid option or value.
# @exitcode 3 The project directory or a prerequisite was not found.
# @example
#   shell::skill::install --tool claude --yes
#   shell::skill::install -t all -s project -k golang,security-secure-coding
#   shell::skill::install -n --tool opencode
#
shell::skill::install() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Install agent skills into Claude Code and/or OpenCode"
		shell::logger::usage "shell::skill::install [options]"
		shell::skill::help::options install
		shell::logger::example "shell::skill::install --tool claude --yes"
		shell::logger::example "shell::skill::install -t all -s project -k golang,security-secure-coding"
		shell::logger::example "shell::skill::install -n --tool opencode"
		return "$RETURN_SUCCESS"
	fi

	shell::skill::run install "$@"
}

# @description Upgrade installed skills to the latest content.
#   Refreshes every installed skill (keeping its symlink/copy mode) and, unless
#   `--no-new` is given, installs skills added upstream into the tool/scope
#   directories you already use. Skills removed upstream are reported, never
#   deleted (use shell::skill::sync or shell::skill::uninstall for that).
#
#   NOTE: if you installed only a few skills (`-k a,b`) and want to keep it
#   that way, pass `--no-new`; otherwise every new upstream skill is added.
# @option -t | --tool Target tool: claude, opencode or all (default: all).
# @option -s | --scope Scope: personal, project or all (default: personal).
# @option -p | --project-dir Project root for scope project/all (default: current directory).
# @option -m | --mode Placement: auto, symlink or copy (default: auto).
# @option -k | --skills Comma-separated skill slugs (default: every installed skill).
# @option -r | --ref Branch, tag or commit to upgrade to.
# @option --no-new Do not install skills that are new upstream.
# @option -y | --yes Assume yes to prompts (required when not interactive).
# @option -v | --verbose Verbose installer output.
# @option --preview Let the installer print what it would do, changing nothing.
# @option -n | --dry-run Print the download command instead of running it.
# @option -h | --help Show help and return.
# @exitcode 0 Upgraded (or the command was printed).
# @exitcode 1 Download or upgrade failed.
# @exitcode 2 Invalid option or value.
# @exitcode 3 The project directory or a prerequisite was not found.
# @example
#   shell::skill::upgrade --yes
#   shell::skill::upgrade -k golang --yes
#   shell::skill::upgrade -n --no-new
#
shell::skill::upgrade() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Upgrade installed agent skills to the latest content"
		shell::logger::usage "shell::skill::upgrade [options]"
		shell::skill::help::options upgrade
		shell::logger::example "shell::skill::upgrade --yes"
		shell::logger::example "shell::skill::upgrade -k golang --yes"
		shell::logger::example "shell::skill::upgrade -n --no-new"
		return "$RETURN_SUCCESS"
	fi

	shell::skill::run upgrade "$@"
}

# @description Uninstall skills that shell::skill::install placed.
#   Only entries recorded in the installer's manifest (and leftover symlinks
#   that point into its own cache) are removed; anything else is untouched.
#   `--purge` also deletes the manifest, backups and the cached clone.
# @option -t | --tool Target tool: claude, opencode or all (default: all).
# @option -s | --scope Scope: personal, project or all (default: personal).
# @option -p | --project-dir Project root for scope project/all (default: current directory).
# @option -k | --skills Comma-separated skill slugs (default: every installed skill).
# @option --purge Also delete the manifest, backups and the cached clone.
# @option --no-sweep Only remove manifest-tracked entries; skip the leftover-symlink sweep.
# @option -y | --yes Assume yes to prompts (required when not interactive).
# @option -v | --verbose Verbose installer output.
# @option --preview Let the installer print what it would do, changing nothing.
# @option -n | --dry-run Print the download command instead of running it.
# @option -h | --help Show help and return.
# @exitcode 0 Uninstalled (or the command was printed).
# @exitcode 1 Download or removal failed.
# @exitcode 2 Invalid option or value.
# @exitcode 3 The project directory or a prerequisite was not found.
# @example
#   shell::skill::uninstall --tool all --scope all --yes
#   shell::skill::uninstall -k golang --yes
#   shell::skill::uninstall -n --purge
#
shell::skill::uninstall() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Uninstall agent skills installed by shell::skill::install"
		shell::logger::usage "shell::skill::uninstall [options]"
		shell::skill::help::options uninstall
		shell::logger::example "shell::skill::uninstall --tool all --scope all --yes"
		shell::logger::example "shell::skill::uninstall -k golang --yes"
		shell::logger::example "shell::skill::uninstall -n --purge"
		return "$RETURN_SUCCESS"
	fi

	shell::skill::run uninstall "$@"
}

# @description Make one tool's skills directory mirror the repository exactly.
#   Pulls the latest content, installs missing skills, refreshes existing ones
#   and (unless `--no-prune`) removes skills that were deleted upstream. Works
#   even if shell::skill::install was never run.
# @arg $1 string Tool to sync: `claude` or `opencode`.
# @option -s | --scope Scope: personal, project or all (default: personal).
# @option -p | --project-dir Project root for scope project/all (default: current directory).
# @option -m | --mode Placement: auto, symlink or copy (default: auto).
# @option -k | --skills Comma-separated skill slugs (default: every skill).
# @option -r | --ref Branch, tag or commit to sync with.
# @option --no-prune Keep skills that were deleted upstream.
# @option -y | --yes Assume yes to prompts (required when not interactive).
# @option -v | --verbose Verbose installer output.
# @option --preview Let the installer print what it would do, changing nothing.
# @option -n | --dry-run Print the download command instead of running it.
# @option -h | --help Show help and return.
# @exitcode 0 Synced (or the command was printed).
# @exitcode 1 Download or sync failed.
# @exitcode 2 The tool is missing or unknown, or an option is invalid.
# @exitcode 3 The project directory or a prerequisite was not found.
# @example
#   shell::skill::sync claude --yes
#   shell::skill::sync opencode -s project --no-prune --yes
#   shell::skill::sync claude -n
#
shell::skill::sync() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Mirror one tool's skills directory to the repository"
		shell::logger::usage "shell::skill::sync <claude|opencode> [options]"
		shell::logger::item "claude | opencode" "Tool whose skills directory is synced"
		shell::skill::help::options sync
		shell::logger::example "shell::skill::sync claude --yes"
		shell::logger::example "shell::skill::sync opencode -s project --no-prune --yes"
		shell::logger::example "shell::skill::sync claude -n"
		return "$RETURN_SUCCESS"
	fi

	local target="${1-}"
	case "$target" in
	claude | opencode) shift ;;
	*)
		shell::logger::error "The first argument must be 'claude' or 'opencode'"
		return "$RETURN_INVALID"
		;;
	esac

	shell::skill::run "sync_$target" "$@"
}
