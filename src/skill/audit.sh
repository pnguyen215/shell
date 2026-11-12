#!/usr/bin/env bash
# @file skill/audit.sh
# @brief Integrate Cloudflare's security-audit skill into Claude Code and OpenCode.
# @description
#   Uses https://github.com/cloudflare/security-audit-skill **in place**: the
#   skill is never copied into this repository. It is cloned (shallow) into
#   `SHELL_SKILL_AUDIT_DIR` and the `skills/security-audit` folder inside that
#   clone is symlinked into each tool's skills directory:
#
#   | Tool        | Personal scope                     | Project scope                       |
#   |-------------|------------------------------------|-------------------------------------|
#   | Claude Code | `~/.claude/skills/security-audit`  | `<project>/.claude/skills/...`      |
#   | OpenCode    | `~/.config/opencode/skills/...`    | `<project>/.opencode/skills/...`    |
#
#   Because the links point into the clone, shell::skill::audit::upgrade only
#   has to fetch the latest upstream commit; every linked tool sees it at once.
#   `--mode copy` places a real copy instead (refreshed by upgrade) for setups
#   that do not follow symlinks.
#
#   Safety: only the managed clone is ever fetched into or reset, and only
#   links/copies that this module created (recognised by their target or a
#   marker file) are replaced or removed. A pre-existing skill of the same name
#   is left alone unless `--force` is given, which moves it to a backup first.
#
#   The skill is third-party instructions that your agent will follow, and its
#   validators are Node scripts. Pin a reviewed commit/tag with `--ref` if you
#   do not want to track the upstream branch. Restart the agent session
#   afterwards so the skill is loaded.

# @internal
# @description Print the directory of the skill inside the managed clone.
# @stdout Absolute path (it may not exist yet).
# @exitcode 0 Always.
# @example
#   src="$(_shell::skill::audit::source)"
#
_shell::skill::audit::source() {
	printf '%s/%s\n' "$SHELL_SKILL_AUDIT_DIR" "$SHELL_SKILL_AUDIT_SUBDIR"
}

# @internal
# @description Print the destination folder of the skill for one tool and scope.
# @arg $1 string Tool: `claude` or `opencode`.
# @arg $2 string Scope: `personal` or `project`.
# @arg $3 string Absolute project root (used by scope `project`).
# @stdout Absolute destination path.
# @exitcode 0 Always.
# @example
#   dest="$(_shell::skill::audit::dest claude project "$PWD")"
#
_shell::skill::audit::dest() {
	local base rel
	case "$2" in
	personal) base="$HOME" ;;
	*) base="$3" ;;
	esac
	case "$1:$2" in
	claude:personal) rel="$SHELL_SKILL_AUDIT_CLAUDE_PERSONAL" ;;
	claude:project) rel="$SHELL_SKILL_AUDIT_CLAUDE_PROJECT" ;;
	opencode:personal) rel="$SHELL_SKILL_AUDIT_OPENCODE_PERSONAL" ;;
	opencode:project) rel="$SHELL_SKILL_AUDIT_OPENCODE_PROJECT" ;;
	esac
	printf '%s/%s/%s\n' "$base" "$rel" "$SHELL_SKILL_AUDIT_NAME"
}

# @internal
# @description Tell whether a destination was created by this module.
#   A managed destination is a symlink to the clone's skill folder, or a real
#   directory carrying the marker file written by `--mode copy`.
# @arg $1 string Destination path.
# @exitcode 0 Managed by this module.
# @exitcode 1 Missing, or not ours.
# @example
#   _shell::skill::audit::is_managed "$HOME/.claude/skills/security-audit"
#
_shell::skill::audit::is_managed() {
	if [ -L "$1" ]; then
		[ "$(readlink "$1")" = "$(_shell::skill::audit::source)" ]
		return
	fi
	[ -d "$1" ] && [ -f "$1/$SHELL_SKILL_AUDIT_MARKER" ]
}

# @internal
# @description Run a command, or only print it when dry-run is on.
#   Keeps one definition of every command line for both the real run and `-n`.
# @arg $1 string `true` for dry-run, anything else to execute.
# @arg $@ string The command and its arguments (argv style, no re-parsing).
# @exitcode 0 Printed, or the command succeeded.
# @exitcode N Exit status of the command.
# @example
#   _shell::skill::audit::x "$dry_run" ln -s "$src" "$dest"
#
_shell::skill::audit::x() {
	local dry="$1"
	shift
	if [ "$dry" = "true" ]; then
		shell::exec::command -n "$@"
		return
	fi
	"$@"
}

# @internal
# @description Remove a destination that this module manages.
#   Refuses anything `_shell::skill::audit::is_managed` does not recognise, so
#   a user's own skill can never be deleted through this path.
# @arg $1 string Destination path.
# @arg $2 string `true` for dry-run.
# @exitcode 0 Removed (or printed).
# @exitcode 7 The destination is not managed by this module.
# @example
#   _shell::skill::audit::remove "$dest" false
#
_shell::skill::audit::remove() {
	if ! _shell::skill::audit::is_managed "$1"; then
		shell::logger::error "Refusing to remove $1: not managed by shell::skill::audit"
		return "$RETURN_EXISTS"
	fi
	if [ -L "$1" ]; then
		_shell::skill::audit::x "$2" rm -f "$1"
	else
		_shell::skill::audit::x "$2" rm -rf "$1"
	fi
}

# @internal
# @description Fetch an upstream ref into the managed clone and check it out.
#   Works for a branch, tag or commit (shallow fetch, detached checkout). The
#   new content is verified to hold the skill before the working tree is
#   touched, so a bad ref leaves the installed version intact. The ref is
#   remembered in the clone so upgrade keeps following it.
# @arg $1 string Ref to fetch.
# @arg $2 string `true` for dry-run.
# @exitcode 0 The clone is at the requested ref (or the commands were printed).
# @exitcode 1 git failed (network, unknown ref).
# @exitcode 3 The ref does not contain the skill.
# @exitcode 7 The clone directory exists but is not a git clone.
# @example
#   _shell::skill::audit::fetch main false
#
_shell::skill::audit::fetch() {
	local ref="$1" dry="$2" dir="$SHELL_SKILL_AUDIT_DIR"

	if [ ! -d "$dir/.git" ]; then
		if [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
			shell::logger::error "$dir exists and is not a git clone; move it away first"
			return "$RETURN_EXISTS"
		fi
		_shell::skill::audit::x "$dry" mkdir -p "$dir" || return "$RETURN_FAILURE"
		_shell::skill::audit::x "$dry" git -C "$dir" init -q || return "$RETURN_FAILURE"
		_shell::skill::audit::x "$dry" git -C "$dir" remote add origin "$SHELL_SKILL_AUDIT_REPO_URL" || return "$RETURN_FAILURE"
	else
		_shell::skill::audit::x "$dry" git -C "$dir" remote set-url origin "$SHELL_SKILL_AUDIT_REPO_URL" || return "$RETURN_FAILURE"
	fi

	if [ "$dry" = "true" ]; then
		shell::exec::command -n git -C "$dir" fetch -q --depth 1 origin "$ref"
		shell::exec::command -n git -C "$dir" checkout -q -f --detach FETCH_HEAD
		return "$RETURN_SUCCESS"
	fi

	shell::logger::step "Fetching $SHELL_SKILL_AUDIT_REPO_SLUG@$ref"
	if ! GIT_TERMINAL_PROMPT=0 git -C "$dir" fetch -q --depth 1 origin "$ref"; then
		shell::logger::error "Could not fetch '$ref' from $SHELL_SKILL_AUDIT_REPO_URL (a commit must be a full 40-character SHA)"
		return "$RETURN_FAILURE"
	fi
	if ! git -C "$dir" cat-file -e "FETCH_HEAD:$SHELL_SKILL_AUDIT_SUBDIR/SKILL.md" 2>/dev/null; then
		shell::logger::error "'$ref' has no $SHELL_SKILL_AUDIT_SUBDIR/SKILL.md; upstream layout changed?"
		return "$RETURN_NOT_FOUND"
	fi
	git -C "$dir" -c advice.detachedHead=false checkout -q -f --detach FETCH_HEAD || return "$RETURN_FAILURE"
	git -C "$dir" config shell.auditRef "$ref"
}

# @internal
# @description Call a function once for every selected tool/scope pair.
#   Written without word-splitting loops so it behaves the same in bash and
#   zsh. The callback receives `tool scope dest` followed by any extra
#   arguments. The first non-zero status is returned, but every pair is visited.
# @arg $1 string Callback function name.
# @arg $2 string Tool: claude, opencode or all.
# @arg $3 string Scope: personal, project or all.
# @arg $4 string Absolute project root.
# @arg $@ string Extra arguments for the callback.
# @exitcode 0 Every callback succeeded.
# @exitcode N The first non-zero status of a callback.
# @example
#   _shell::skill::audit::foreach _shell::skill::audit::on_status all personal "$PWD"
#
_shell::skill::audit::foreach() {
	local cb="$1" tool="$2" scope="$3" proj="$4" rc=0 one
	shift 4
	# Plain calls (not a loop over words) so zsh and bash agree.
	if [ "$tool" = "claude" ] || [ "$tool" = "all" ]; then
		if [ "$scope" = "personal" ] || [ "$scope" = "all" ]; then
			"$cb" claude personal "$(_shell::skill::audit::dest claude personal "$proj")" "$@" || {
				one=$?
				[ "$rc" -eq 0 ] && rc=$one
			}
		fi
		if [ "$scope" = "project" ] || [ "$scope" = "all" ]; then
			"$cb" claude project "$(_shell::skill::audit::dest claude project "$proj")" "$@" || {
				one=$?
				[ "$rc" -eq 0 ] && rc=$one
			}
		fi
	fi
	if [ "$tool" = "opencode" ] || [ "$tool" = "all" ]; then
		if [ "$scope" = "personal" ] || [ "$scope" = "all" ]; then
			"$cb" opencode personal "$(_shell::skill::audit::dest opencode personal "$proj")" "$@" || {
				one=$?
				[ "$rc" -eq 0 ] && rc=$one
			}
		fi
		if [ "$scope" = "project" ] || [ "$scope" = "all" ]; then
			"$cb" opencode project "$(_shell::skill::audit::dest opencode project "$proj")" "$@" || {
				one=$?
				[ "$rc" -eq 0 ] && rc=$one
			}
		fi
	fi
	return "$rc"
}

# @internal
# @description Place the skill at one destination (callback of foreach).
#   Idempotent. Replaces a managed link/copy, refuses a foreign one unless
#   forced (then it is moved to the backup directory first).
# @arg $1 string Tool.
# @arg $2 string Scope.
# @arg $3 string Destination path.
# @arg $4 string Mode: symlink or copy.
# @arg $5 string `true` to back up and replace a foreign destination.
# @arg $6 string `true` for dry-run.
# @exitcode 0 Placed, or already in place.
# @exitcode 1 A filesystem command failed.
# @exitcode 7 A foreign skill is in the way and --force was not given.
# @example
#   _shell::skill::audit::on_install claude personal "$dest" symlink false false
#
_shell::skill::audit::on_install() {
	local tool="$1" scope="$2" dest="$3" mode="$4" force="$5" dry="$6"
	local src
	src="$(_shell::skill::audit::source)"

	if _shell::skill::audit::is_managed "$dest"; then
		if [ "$mode" = "symlink" ] && [ -L "$dest" ]; then
			shell::logger::info "$tool/$scope: already linked ($dest)"
			return "$RETURN_SUCCESS"
		fi
		_shell::skill::audit::remove "$dest" "$dry" || return "$RETURN_FAILURE"
	elif [ -e "$dest" ] || [ -L "$dest" ]; then
		if [ "$force" != "true" ]; then
			shell::logger::error "$tool/$scope: $dest already exists and is not managed here (use --force to back it up and replace it)"
			return "$RETURN_EXISTS"
		fi
		local backup
		backup="$SHELL_CONFIG_BACKUP_DIR/skill-audit/$tool-$scope-$(date +%Y%m%d%H%M%S)"
		_shell::skill::audit::x "$dry" mkdir -p "$backup" || return "$RETURN_FAILURE"
		_shell::skill::audit::x "$dry" mv "$dest" "$backup/$SHELL_SKILL_AUDIT_NAME" || return "$RETURN_FAILURE"
		shell::logger::warn "$tool/$scope: existing skill moved to $backup"
	fi

	_shell::skill::audit::x "$dry" mkdir -p "$(dirname "$dest")" || return "$RETURN_FAILURE"
	if [ "$mode" = "copy" ]; then
		_shell::skill::audit::x "$dry" cp -R "$src" "$dest" || return "$RETURN_FAILURE"
		_shell::skill::audit::x "$dry" touch "$dest/$SHELL_SKILL_AUDIT_MARKER" || return "$RETURN_FAILURE"
	else
		_shell::skill::audit::x "$dry" ln -s "$src" "$dest" || return "$RETURN_FAILURE"
	fi
	[ "$dry" = "true" ] || shell::logger::success "$tool/$scope: installed ($mode) -> $dest"
	return "$RETURN_SUCCESS"
}

# @internal
# @description Refresh one destination after the clone was updated (callback).
#   A symlink already sees the new content; a managed copy is re-copied.
#   Destinations that this module does not manage are skipped silently.
# @arg $1 string Tool.
# @arg $2 string Scope.
# @arg $3 string Destination path.
# @arg $4 string `true` for dry-run.
# @exitcode 0 Refreshed or skipped.
# @exitcode 1 A filesystem command failed.
# @example
#   _shell::skill::audit::on_upgrade claude personal "$dest" false
#
_shell::skill::audit::on_upgrade() {
	local dest="$3"
	_shell::skill::audit::is_managed "$dest" || return "$RETURN_SUCCESS"
	if [ -L "$dest" ]; then
		shell::logger::info "$1/$2: linked, already current ($dest)"
		return "$RETURN_SUCCESS"
	fi
	_shell::skill::audit::on_install "$1" "$2" "$dest" copy false "$4"
}

# @internal
# @description Remove one destination if this module manages it (callback).
# @arg $1 string Tool.
# @arg $2 string Scope.
# @arg $3 string Destination path.
# @arg $4 string `true` for dry-run.
# @exitcode 0 Removed, or nothing of ours was there.
# @exitcode 1 Removal failed.
# @example
#   _shell::skill::audit::on_uninstall claude personal "$dest" false
#
_shell::skill::audit::on_uninstall() {
	if _shell::skill::audit::is_managed "$3"; then
		_shell::skill::audit::remove "$3" "$4" || return "$RETURN_FAILURE"
		[ "$4" = "true" ] || shell::logger::success "$1/$2: removed $3"
	elif [ -e "$3" ] || [ -L "$3" ]; then
		shell::logger::warn "$1/$2: $3 is not managed here, left untouched"
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Print one status row for a destination (callback).
# @arg $1 string Tool.
# @arg $2 string Scope.
# @arg $3 string Destination path.
# @stdout `tool<TAB>scope<TAB>state<TAB>path`; state is symlink, copy, foreign or absent.
# @exitcode 0 Always.
# @example
#   _shell::skill::audit::on_status claude personal "$dest"
#
_shell::skill::audit::on_status() {
	local state="absent"
	if _shell::skill::audit::is_managed "$3"; then
		if [ -L "$3" ]; then state="symlink"; else state="copy"; fi
	elif [ -e "$3" ] || [ -L "$3" ]; then
		state="foreign"
	fi
	printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$state" "$3"
}

# @internal
# @description Parse the options shared by the audit commands, then act.
#   Value options accept `--opt value` and `--opt=value`. Everything is
#   validated before git or the filesystem is touched.
# @option -t | --tool Target tool: claude, opencode or all.
# @option -s | --scope Scope: personal, project or all.
# @option -p | --project-dir Project root for scope project/all.
# @option -m | --mode Placement: symlink or copy (install only).
# @option -r | --ref Branch, tag or commit (install, upgrade).
# @option -f | --force Back up and replace a foreign skill (install only).
# @option --check Compare with upstream without changing anything (status only).
# @option --purge Also delete the managed clone (uninstall only).
# @option -n | --dry-run Print the commands instead of running them.
# @arg $1 string Action: install, upgrade, uninstall or status.
# @arg $@ string Options (see above).
# @exitcode 0 Success (or the commands were printed).
# @exitcode 1 git or a filesystem command failed.
# @exitcode 2 Invalid option or value.
# @exitcode 3 git, the project directory or the installation was not found.
# @exitcode 7 A foreign skill is in the way and --force was not given.
# @example
#   _shell::skill::audit::run install --tool claude
#
_shell::skill::audit::run() {
	local action="$1"
	shift

	local dry_run="false" force="false" check="false" purge="false"
	local tool="all" scope="personal" project_dir="" mode="symlink" ref=""
	local opt val

	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		-f | --force)
			case "$action" in
			install) force="true" ;;
			*)
				shell::logger::error "Option $1 is not supported by '$action'"
				return "$RETURN_INVALID"
				;;
			esac
			shift
			;;
		--check)
			case "$action" in
			status) check="true" ;;
			*)
				shell::logger::error "Option $1 is not supported by '$action'"
				return "$RETURN_INVALID"
				;;
			esac
			shift
			;;
		--purge)
			case "$action" in
			uninstall) purge="true" ;;
			*)
				shell::logger::error "Option $1 is not supported by '$action'"
				return "$RETURN_INVALID"
				;;
			esac
			shift
			;;
		-t | --tool | -s | --scope | -p | --project-dir | -m | --mode | -r | --ref | --tool=* | --scope=* | --project-dir=* | --mode=* | --ref=*)
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
			case "$action:$opt" in
			install:-m | install:--mode | install:-r | install:--ref | upgrade:-r | upgrade:--ref) ;;
			*:-m | *:--mode | *:-r | *:--ref)
				shell::logger::error "Option $opt is not supported by '$action'"
				return "$RETURN_INVALID"
				;;
			esac
			case "$opt" in
			-t | --tool) tool="$val" ;;
			-s | --scope) scope="$val" ;;
			-p | --project-dir) project_dir="$val" ;;
			-m | --mode) mode="$val" ;;
			-r | --ref) ref="$val" ;;
			esac
			;;
		*)
			shell::logger::error "Unknown option or argument: $1"
			return "$RETURN_INVALID"
			;;
		esac
	done

	# --- Validate everything first
	if ! _shell::skill::validate::choice "$tool" "$SHELL_SKILL_TOOLS"; then
		shell::logger::error "Invalid --tool '$tool' (expected: $SHELL_SKILL_TOOLS)"
		return "$RETURN_INVALID"
	fi
	if ! _shell::skill::validate::choice "$scope" "$SHELL_SKILL_SCOPES"; then
		shell::logger::error "Invalid --scope '$scope' (expected: $SHELL_SKILL_SCOPES)"
		return "$RETURN_INVALID"
	fi
	if ! _shell::skill::validate::choice "$mode" "$SHELL_SKILL_AUDIT_MODES"; then
		shell::logger::error "Invalid --mode '$mode' (expected: $SHELL_SKILL_AUDIT_MODES)"
		return "$RETURN_INVALID"
	fi
	if [ -n "$ref" ] && ! _shell::skill::validate::ref "$ref"; then
		shell::logger::error "Invalid --ref '$ref'"
		return "$RETURN_INVALID"
	fi
	case "$project_dir" in
	-*)
		shell::logger::error "Invalid --project-dir '$project_dir'"
		return "$RETURN_INVALID"
		;;
	esac
	if [ -z "$project_dir" ]; then
		project_dir="$PWD"
	fi
	if [ ! -d "$project_dir" ]; then
		shell::logger::error "Project directory not found: $project_dir"
		return "$RETURN_NOT_FOUND"
	fi
	project_dir="$(cd "$project_dir" && pwd)"

	local dir="$SHELL_SKILL_AUDIT_DIR"

	case "$action" in
	install)
		if [ "$dry_run" != "true" ]; then
			shell::dependency::git::ensure || return "$RETURN_NOT_FOUND"
		fi
		local want="${ref:-$SHELL_SKILL_AUDIT_REPO_BRANCH}"
		_shell::skill::audit::fetch "$want" "$dry_run" || return $?
		_shell::skill::audit::foreach _shell::skill::audit::on_install "$tool" "$scope" "$project_dir" "$mode" "$force" "$dry_run" || return $?
		[ "$dry_run" = "true" ] || shell::logger::note "Restart Claude Code / OpenCode so the skill is loaded."
		;;
	upgrade)
		if [ "$dry_run" != "true" ]; then
			shell::dependency::git::ensure || return "$RETURN_NOT_FOUND"
		fi
		if [ ! -d "$dir/.git" ]; then
			shell::logger::error "Not installed: run shell::skill::audit::install first"
			return "$RETURN_NOT_FOUND"
		fi
		local before after kept
		before="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)"
		kept="$(git -C "$dir" config --get shell.auditRef 2>/dev/null)"
		_shell::skill::audit::fetch "${ref:-${kept:-$SHELL_SKILL_AUDIT_REPO_BRANCH}}" "$dry_run" || return $?
		if [ "$dry_run" != "true" ]; then
			after="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)"
			if [ "$before" = "$after" ]; then
				shell::logger::info "Already up to date ($after)"
			else
				shell::logger::success "Upgraded $before -> $after"
			fi
		fi
		_shell::skill::audit::foreach _shell::skill::audit::on_upgrade "$tool" "$scope" "$project_dir" "$dry_run" || return $?
		;;
	uninstall)
		_shell::skill::audit::foreach _shell::skill::audit::on_uninstall "$tool" "$scope" "$project_dir" "$dry_run" || return $?
		if [ "$purge" = "true" ]; then
			if [ ! -d "$dir/.git" ]; then
				shell::logger::info "No managed clone to delete"
			else
				_shell::skill::audit::x "$dry_run" rm -rf "$dir" || return "$RETURN_FAILURE"
				[ "$dry_run" = "true" ] || shell::logger::success "Deleted $dir"
			fi
		fi
		;;
	status)
		shell::logger::section "Cloudflare security-audit skill"
		if [ -d "$dir/.git" ]; then
			local pinned head date remote
			pinned="$(git -C "$dir" config --get shell.auditRef 2>/dev/null)"
			head="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)"
			date="$(git -C "$dir" log -1 --format=%cs 2>/dev/null)"
			printf 'clone\t%s\nrepo\t%s\nref\t%s\ncommit\t%s (%s)\n' "$dir" "$SHELL_SKILL_AUDIT_REPO_URL" "${pinned:-$SHELL_SKILL_AUDIT_REPO_BRANCH}" "$head" "$date"
			if [ "$check" = "true" ]; then
				remote="$(GIT_TERMINAL_PROMPT=0 git -C "$dir" ls-remote origin "${pinned:-$SHELL_SKILL_AUDIT_REPO_BRANCH}" 2>/dev/null | cut -c1-7 | sed -n 1p)"
				if [ -z "$remote" ]; then
					shell::logger::warn "Could not reach upstream to compare"
				elif [ "$remote" = "$head" ]; then
					shell::logger::info "Up to date"
				else
					shell::logger::warn "Update available ($remote): run shell::skill::audit::upgrade"
				fi
			fi
		else
			printf 'clone\t(not installed)\n'
		fi
		_shell::skill::audit::foreach _shell::skill::audit::on_status "$tool" "$scope" "$project_dir"
		;;
	esac
}

# @description Install the Cloudflare security-audit skill into Claude Code and/or OpenCode.
#   Clones https://github.com/cloudflare/security-audit-skill once and links the
#   skill into the selected tools; nothing is copied into this repository.
#   Idempotent. A pre-existing skill with the same name is kept unless `--force`.
# @option -t | --tool Target tool: claude, opencode or all (default: all).
# @option -s | --scope Scope: personal, project or all (default: personal).
# @option -p | --project-dir Project root for scope project/all (default: current directory).
# @option -m | --mode Placement: symlink or copy (default: symlink).
# @option -r | --ref Branch, tag or commit to track (default: SHELL_SKILL_AUDIT_REPO_BRANCH).
# @option -f | --force Back up a foreign skill of the same name and replace it.
# @option -n | --dry-run Print the commands instead of running them.
# @option -h | --help Show help and return.
# @exitcode 0 Installed (or the commands were printed).
# @exitcode 1 git or a filesystem command failed.
# @exitcode 2 Invalid option or value.
# @exitcode 3 git, the project directory or the skill in the ref was not found.
# @exitcode 7 A foreign skill is in the way and --force was not given.
# @example
#   shell::skill::audit::install
#   shell::skill::audit::install --tool claude --scope project
#   shell::skill::audit::install --ref <commit> --mode copy
#   shell::skill::audit::install -n
#
shell::skill::audit::install() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Install Cloudflare's security-audit skill into Claude Code / OpenCode"
		shell::logger::usage "shell::skill::audit::install [options]"
		shell::logger::option "-t, --tool <name>" "claude | opencode | all (default: all)"
		shell::logger::option "-s, --scope <name>" "personal | project | all (default: personal)"
		shell::logger::option "-p, --project-dir <dir>" "Project root for scope project/all (default: current dir)"
		shell::logger::option "-m, --mode <name>" "symlink | copy (default: symlink)"
		shell::logger::option "-r, --ref <ref>" "Branch, tag or commit to track (default: $SHELL_SKILL_AUDIT_REPO_BRANCH)"
		shell::logger::option "-f, --force" "Back up a foreign skill of the same name and replace it"
		shell::logger::option "-n, --dry-run" "Print the commands instead of running them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::skill::audit::install"
		shell::logger::example "shell::skill::audit::install --tool claude --scope project"
		shell::logger::example "shell::skill::audit::install -n"
		return "$RETURN_SUCCESS"
	fi

	_shell::skill::audit::run install "$@"
}

# @description Upgrade the security-audit skill to the latest upstream content.
#   Fetches the tracked ref (or `--ref`) into the managed clone. Symlinked
#   installs see the new content immediately; managed copies are re-copied.
# @option -t | --tool Target tool: claude, opencode or all (default: all).
# @option -s | --scope Scope: personal, project or all (default: personal).
# @option -p | --project-dir Project root for scope project/all (default: current directory).
# @option -r | --ref Branch, tag or commit to move to (default: the ref given at install).
# @option -n | --dry-run Print the commands instead of running them.
# @option -h | --help Show help and return.
# @exitcode 0 Upgraded or already current (or the commands were printed).
# @exitcode 1 git or a filesystem command failed.
# @exitcode 2 Invalid option or value.
# @exitcode 3 Not installed, or git / the skill in the ref was not found.
# @example
#   shell::skill::audit::upgrade
#   shell::skill::audit::upgrade --ref main
#   shell::skill::audit::upgrade -n
#
shell::skill::audit::upgrade() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Upgrade the security-audit skill to the latest upstream content"
		shell::logger::usage "shell::skill::audit::upgrade [options]"
		shell::logger::option "-t, --tool <name>" "claude | opencode | all (default: all)"
		shell::logger::option "-s, --scope <name>" "personal | project | all (default: personal)"
		shell::logger::option "-p, --project-dir <dir>" "Project root for scope project/all (default: current dir)"
		shell::logger::option "-r, --ref <ref>" "Branch, tag or commit to move to (default: the ref used at install)"
		shell::logger::option "-n, --dry-run" "Print the commands instead of running them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::skill::audit::upgrade"
		shell::logger::example "shell::skill::audit::upgrade --ref main"
		return "$RETURN_SUCCESS"
	fi

	_shell::skill::audit::run upgrade "$@"
}

# @description Remove the security-audit skill from Claude Code and/or OpenCode.
#   Only links/copies created by this module are removed; a foreign skill of
#   the same name is reported and left untouched. `--purge` also deletes the
#   managed clone (do it only once every scope you used has been uninstalled).
# @option -t | --tool Target tool: claude, opencode or all (default: all).
# @option -s | --scope Scope: personal, project or all (default: personal).
# @option -p | --project-dir Project root for scope project/all (default: current directory).
# @option --purge Also delete the managed clone.
# @option -n | --dry-run Print the commands instead of running them.
# @option -h | --help Show help and return.
# @exitcode 0 Removed (or the commands were printed).
# @exitcode 1 A removal failed.
# @exitcode 2 Invalid option or value.
# @exitcode 3 The project directory was not found.
# @example
#   shell::skill::audit::uninstall
#   shell::skill::audit::uninstall --scope all --purge
#
shell::skill::audit::uninstall() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Remove the security-audit skill from Claude Code / OpenCode"
		shell::logger::usage "shell::skill::audit::uninstall [options]"
		shell::logger::option "-t, --tool <name>" "claude | opencode | all (default: all)"
		shell::logger::option "-s, --scope <name>" "personal | project | all (default: personal)"
		shell::logger::option "-p, --project-dir <dir>" "Project root for scope project/all (default: current dir)"
		shell::logger::option "--purge" "Also delete the managed clone"
		shell::logger::option "-n, --dry-run" "Print the commands instead of running them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::skill::audit::uninstall"
		shell::logger::example "shell::skill::audit::uninstall --scope all --purge"
		return "$RETURN_SUCCESS"
	fi

	_shell::skill::audit::run uninstall "$@"
}

# @description Show where the security-audit skill is installed and which commit it is on.
#   Read-only. `--check` asks the upstream remote whether a newer commit exists.
# @option -t | --tool Target tool: claude, opencode or all (default: all).
# @option -s | --scope Scope: personal, project or all (default: all).
# @option -p | --project-dir Project root for scope project/all (default: current directory).
# @option --check Compare with upstream (needs network).
# @option -h | --help Show help and return.
# @stdout Clone details, then one row per destination: `tool<TAB>scope<TAB>state<TAB>path`.
# @exitcode 0 Always (unless the options are invalid).
# @exitcode 2 Invalid option or value.
# @example
#   shell::skill::audit::status
#   shell::skill::audit::status --check
#
shell::skill::audit::status() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show the security-audit skill's installation state"
		shell::logger::usage "shell::skill::audit::status [options]"
		shell::logger::option "-t, --tool <name>" "claude | opencode | all (default: all)"
		shell::logger::option "-s, --scope <name>" "personal | project | all (default: all)"
		shell::logger::option "-p, --project-dir <dir>" "Project root for scope project/all (default: current dir)"
		shell::logger::option "--check" "Compare with upstream (needs network)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::skill::audit::status --check"
		return "$RETURN_SUCCESS"
	fi

	# Unlike the others, status looks everywhere unless told otherwise.
	_shell::skill::audit::run status --scope all "$@"
}
