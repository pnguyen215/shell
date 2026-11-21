#!/usr/bin/env bash
# @file lib/zsh.sh
# @brief Make zsh ready to use with this library (shell::zsh::install).
# @description
#   `shell::zsh::install` wires the ALREADY-INSTALLED library into `~/.zshrc`:
#   it makes sure zsh exists, finds where the library lives, and writes (or
#   repairs) the same marked block that `install.sh` writes and `uninstall.sh`
#   removes. Re-running it is always safe.
#
#   The interactive pickers of the zsh category are in zsh_fzf.sh, the cache in
#   zsh_cache.sh and the optional ZLE widgets in zsh_widget.sh.

# @internal
# @description Succeed when zsh is on PATH.
#   A function of its own so a test can pretend zsh is missing.
# @noargs
# @exitcode 0 zsh is installed.
# @exitcode 1 zsh is not installed.
# @example
#   _shell::zsh::have || shell::dependency::zsh::ensure
#
_shell::zsh::have() {
	command -v zsh >/dev/null 2>&1
}

# @internal
# @description Normalise and vet an installation directory.
#   Refuses "", "/", $HOME, relative paths, and characters that would break the
#   double-quoted `source "<dir>/src/shell.sh"` line (quote, backtick, $, backslash, newline).
# @arg $1 string The directory.
# @stdout The directory without trailing slashes.
# @exitcode 0 The directory is acceptable.
# @exitcode 2 The directory is dangerous or unusable.
# @example
#   dir="$(_shell::zsh::install::clean_dir "$HOME/shell/")" || return
#
_shell::zsh::install::clean_dir() {
	local dir="${1-}"
	case "$dir" in
	"" | "/" | "$HOME" | "$HOME/") return "$RETURN_INVALID" ;;
	/*) ;;
	*) return "$RETURN_INVALID" ;;
	esac
	case "$dir" in
	*'"'* | *'`'* | *'$'* | *'\'* | *$'\n'*) return "$RETURN_INVALID" ;;
	esac
	while [ "${dir%/}" != "$dir" ]; do dir="${dir%/}"; done
	case "$dir" in
	"" | "$HOME") return "$RETURN_INVALID" ;;
	esac
	printf '%s\n' "$dir"
}

# @internal
# @description Pick the installation directory of the library.
#   Candidates, first valid (a directory that holds `src/shell.sh`) wins:
#   `--dir`, `$SHELL_INSTALL_DIR` (only when it was changed from the default,
#   because the loader always sets it), `$SHELL_DIR` of this session, the path in
#   the existing hook of `~/.zshrc`, and the default `$HOME/shell`.
#   An explicit `--dir` that is unusable is an error: it is never replaced silently.
# @arg $1 string The `--dir` value, or empty.
# @arg $2 string The directory named by the existing hook, or empty.
# @stdout `<source><TAB><dir>`, source being one of: argument, SHELL_INSTALL_DIR, session, hook, default.
# @exitcode 0 A directory was found.
# @exitcode 2 `--dir` is dangerous.
# @exitcode 3 No valid installation was found.
# @example
#   picked="$(_shell::zsh::install::resolve "" "")"
#
_shell::zsh::install::resolve() {
	local explicit="${1-}" hook="${2-}" dir

	if [ -n "$explicit" ]; then
		dir="$(_shell::zsh::install::clean_dir "$explicit")" || {
			shell::logger::error "Refusing --dir '$explicit': use an absolute, dedicated directory (not /, not \$HOME)."
			return "$RETURN_INVALID"
		}
		if [ ! -f "$dir/src/shell.sh" ]; then
			shell::logger::error "--dir '$dir' does not contain src/shell.sh."
			return "$RETURN_NOT_FOUND"
		fi
		printf 'argument\t%s\n' "$dir"
		return "$RETURN_SUCCESS"
	fi

	if [ -n "${SHELL_INSTALL_DIR-}" ] && [ "$SHELL_INSTALL_DIR" != "$HOME/shell" ]; then
		dir="$(_shell::zsh::install::clean_dir "$SHELL_INSTALL_DIR")" && [ -f "$dir/src/shell.sh" ] && {
			printf 'SHELL_INSTALL_DIR\t%s\n' "$dir"
			return "$RETURN_SUCCESS"
		}
	fi
	if [ -n "${SHELL_DIR-}" ]; then
		dir="$(_shell::zsh::install::clean_dir "$SHELL_DIR")" && [ -f "$dir/src/shell.sh" ] && {
			printf 'session\t%s\n' "$dir"
			return "$RETURN_SUCCESS"
		}
	fi
	if [ -n "$hook" ]; then
		dir="$(_shell::zsh::install::clean_dir "$hook")" && [ -f "$dir/src/shell.sh" ] && {
			printf 'hook\t%s\n' "$dir"
			return "$RETURN_SUCCESS"
		}
	fi
	dir="$(_shell::zsh::install::clean_dir "$SHELL_ZSH_DEFAULT_DIR")" && [ -f "$dir/src/shell.sh" ] && {
		printf 'default\t%s\n' "$dir"
		return "$RETURN_SUCCESS"
	}
	return "$RETURN_NOT_FOUND"
}

# @internal
# @description Run the hook awk program (src/data/zsh-hook.awk) on stdin.
#   `dir` prints the directory of the first hook; `rewrite <dir>` prints the file
#   with exactly one marked hook for <dir>. Bytes are handled as bytes (LC_ALL=C).
# @arg $1 string Mode: dir | rewrite.
# @arg $2 string The installation directory (rewrite only).
# @stdin The content of the profile.
# @stdout The directory, or the rewritten profile.
# @exitcode 0 Success.
# @exitcode 3 The awk program is missing.
# @exitcode 4 rewrite: a marked block is never closed (nothing is guessed).
# @example
#   printf '%s' "$content" | _shell::zsh::install::awk dir
#
_shell::zsh::install::awk() {
	if [ ! -f "$SHELL_ZSH_HOOK_AWK" ]; then
		shell::logger::error "Missing $SHELL_ZSH_HOOK_AWK"
		return "$RETURN_NOT_FOUND"
	fi
	LC_ALL=C awk -v mode="$1" -v dir="${2-}" -v home="$HOME" \
		-v begin="$SHELL_ZSH_HOOK_BEGIN" -v end="$SHELL_ZSH_HOOK_END" \
		-f "$SHELL_ZSH_HOOK_AWK" || {
		[ "$1" = "rewrite" ] && return "$RETURN_NOT_SUPPORTED"
		return "$RETURN_FAILURE"
	}
}

# @internal
# @description Follow symbolic links of a profile (dotfile managers link ~/.zshrc).
#   Only `readlink` without options is used, so it works on macOS and Linux.
# @arg $1 string The path.
# @stdout The path of the real file.
# @exitcode 0 Always.
# @example
#   target="$(_shell::zsh::install::real_path "$HOME/.zshrc")"
#
_shell::zsh::install::real_path() {
	local file="$1" link n=0
	while [ -L "$file" ] && [ "$n" -lt 10 ]; do
		link="$(readlink "$file")" || break
		case "$link" in
		/*) file="$link" ;;
		*) file="$(dirname "$file")/$link" ;;
		esac
		n=$((n + 1))
	done
	printf '%s\n' "$file"
}

# @internal
# @description Write the profile atomically: backup, temp file next to it, then mv.
#   The temp file starts as a copy of the profile, so its mode and owner survive.
# @arg $1 string The profile as the user sees it (~/.zshrc).
# @arg $2 string The complete new content.
# @arg $3 string "true" when the profile exists and must be backed up first.
# @exitcode 0 Written.
# @exitcode 1 The backup or the write failed (the profile is left as it was).
# @example
#   _shell::zsh::install::write "$HOME/.zshrc" "$new" true
#
_shell::zsh::install::write() {
	local rc_file="$1" content="$2" existed="$3" target tmp
	local backup="$rc_file$SHELL_ZSH_BACKUP_SUFFIX"

	if [ "$existed" = "true" ]; then
		cp -p "$rc_file" "$backup" || {
			shell::logger::error "Cannot back up $rc_file to $backup; nothing was changed."
			return "$RETURN_FAILURE"
		}
	fi

	target="$(_shell::zsh::install::real_path "$rc_file")"
	tmp="$target.shell-tmp.$$"
	if [ -f "$target" ]; then
		cp -p "$target" "$tmp" || return "$RETURN_FAILURE"
	fi
	if ! printf '%s' "$content" >"$tmp" || ! mv -f "$tmp" "$target"; then
		rm -f "$tmp"
		shell::logger::error "Cannot write $target; it was left as it was."
		return "$RETURN_FAILURE"
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Make zsh the login shell with `chsh`, after an explicit confirmation.
#   Nothing is done when zsh already is the login shell. The shell must be listed
#   in /etc/shells; adding it needs root, so only the command is suggested.
# @arg $1 string "true" for a dry run (print the command, ask nothing).
# @exitcode 0 Changed, or nothing to change, or dry run.
# @exitcode 1 chsh failed, or the shell is not listed in $SHELL_ZSH_SHELLS_FILE.
# @exitcode 3 chsh is not installed.
# @exitcode 9 The user did not confirm.
# @example
#   _shell::zsh::install::login_shell false
#
_shell::zsh::install::login_shell() {
	local dry_run="$1" zsh_bin candidate
	case "${SHELL-}" in
	*/zsh)
		shell::logger::info "zsh is already your login shell ($SHELL)."
		return "$RETURN_SUCCESS"
		;;
	esac

	zsh_bin="$(command -v zsh 2>/dev/null)"
	[ -n "$zsh_bin" ] || zsh_bin="zsh"
	if [ "$dry_run" != "true" ] && ! grep -qxF "$zsh_bin" "$SHELL_ZSH_SHELLS_FILE" 2>/dev/null; then
		for candidate in /bin/zsh /usr/bin/zsh; do
			if grep -qxF "$candidate" "$SHELL_ZSH_SHELLS_FILE" 2>/dev/null && [ -x "$candidate" ]; then
				zsh_bin="$candidate"
				break
			fi
		done
		if ! grep -qxF "$zsh_bin" "$SHELL_ZSH_SHELLS_FILE" 2>/dev/null; then
			shell::logger::error "$zsh_bin is not listed in $SHELL_ZSH_SHELLS_FILE. Add it first, then run again:"
			shell::logger::command "echo '$zsh_bin' | sudo tee -a $SHELL_ZSH_SHELLS_FILE"
			return "$RETURN_FAILURE"
		fi
	fi

	if [ "$dry_run" = "true" ]; then
		shell::exec::command -n chsh -s "$zsh_bin"
		return "$RETURN_SUCCESS"
	fi
	if ! command -v chsh >/dev/null 2>&1; then
		shell::logger::error "chsh is not installed; change the login shell with your system settings."
		return "$RETURN_NOT_FOUND"
	fi
	shell::ask::accept "Change your login shell to $zsh_bin (chsh)?" || return "$RETURN_CANCELLED"
	shell::exec::command chsh -s "$zsh_bin" || return "$RETURN_FAILURE"
}

# @description Make zsh ready and wire the installed library into ~/.zshrc.
#   Safe to run again and again:
#
#   1. zsh is installed when missing (shell::dependency::zsh::ensure).
#   2. The library is looked up, first valid wins (valid = holds `src/shell.sh`):
#      `--dir`, `$SHELL_INSTALL_DIR` (when changed from the default), the
#      `$SHELL_DIR` of this session, the path of an existing hook in `~/.zshrc`
#      (even a stale one), and the default `$HOME/shell`. `/`, `$HOME` and
#      relative paths are refused. With none valid, `~/.zshrc` is left alone and
#      the install one-liner is printed.
#   3. `~/.zshrc` is created, extended or repaired between the `# >>> shell >>>`
#      and `# <<< shell <<<` markers of install.sh, so uninstall.sh keeps working:
#      no hook, the block is appended; a hook of an old or moved directory is
#      updated in place; a legacy unmarked `source .../src/shell.sh` line is
#      migrated into the block; a correct hook is a no-op that touches nothing.
#   4. Before any change `~/.zshrc` is copied to `~/.zshrc.shell-bak`; the new file
#      is written to a temp file and moved into place. Every other line is kept as it
#      was. A symbolic link is followed.
#
#   The hook is never sourced into the current shell, and the login shell is
#   never changed unless `--default` is passed and you confirm.
#   When the session's library shadows a different valid hook, you are asked first
#   (pass `--dir` to decide without a question).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the hook block and the file operations; change nothing.
# @option --dir <path> Install location of the library (must hold src/shell.sh).
# @option --default Also make zsh the login shell (chsh), after a confirmation.
# @exitcode 0 The hook is in place (or was already), or the dry run was printed.
# @exitcode 1 Writing the profile failed, or an unclosed marker block was found.
# @exitcode 2 Unknown option, or a dangerous --dir.
# @exitcode 3 zsh is missing and could not be installed, or no valid installation was found.
# @exitcode 9 The user did not confirm.
# @see shell::dependency::zsh::ensure
# @example
#   shell::zsh::install
#   shell::zsh::install -n
#   shell::zsh::install --dir "$HOME/dev/shell"
#
shell::zsh::install() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Make zsh ready and wire the installed library into ~/.zshrc"
		shell::logger::usage "shell::zsh::install [-n] [--dir <path>] [--default]"
		shell::logger::option "--dir <path>" "Where the library is installed (must hold src/shell.sh)"
		shell::logger::option "--default" "Also make zsh your login shell (asks first)"
		shell::logger::option "-n, --dry-run" "Print the hook block and file operations; change nothing"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::zsh::install"
		shell::logger::example "shell::zsh::install -n"
		shell::logger::example "shell::zsh::install --dir \"\$HOME/dev/shell\""
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" dir_arg="" make_default="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		--default) make_default="true" ;;
		--dir)
			if [ "$#" -lt 2 ] || [ -z "$2" ]; then
				shell::logger::error "Option --dir requires a path"
				return "$RETURN_INVALID"
			fi
			dir_arg="$2"
			shift
			;;
		--dir=*) dir_arg="${1#--dir=}" ;;
		-h | --help)
			shell::zsh::install --help
			return "$RETURN_SUCCESS"
			;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done

	local nl=$'\n' rc_file="$HOME/$SHELL_ZSH_RC_NAME"

	# 1. zsh itself.
	if ! _shell::zsh::have; then
		if [ "$dry_run" = "true" ]; then
			shell::logger::warn "zsh is not installed; it would be installed first:"
			shell::logger::command_clip "shell::dependency::zsh::ensure"
		else
			shell::dependency::zsh::ensure || {
				shell::logger::error "zsh is not available; $rc_file was not touched."
				return "$RETURN_NOT_FOUND"
			}
		fi
	fi

	# 2. The profile as it is now, and where it points.
	local existed="false" current=""
	if [ -f "$rc_file" ]; then
		existed="true"
		current="$(
			cat "$rc_file"
			printf x
		)"
		current="${current%x}"
		# A last line without newline is compared as if it had one; a no-op never rewrites the file.
		case "$current" in
		"" | *"$nl") ;;
		*) current="$current$nl" ;;
		esac
	fi
	local hook_dir
	hook_dir="$(printf '%s' "$current" | _shell::zsh::install::awk dir)"

	local picked rc source_name dir
	picked="$(_shell::zsh::install::resolve "$dir_arg" "$hook_dir")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_NOT_FOUND")
		if [ -z "$dir_arg" ]; then
			shell::logger::error "No installed library found (looked for src/shell.sh); $rc_file was not touched."
			shell::logger::info "Install it first:"
			shell::logger::command "/bin/bash -c \"\$(curl -fsSL $SHELL_URL_INSTALL)\""
		fi
		return "$RETURN_NOT_FOUND"
		;;
	*) return "$rc" ;;
	esac
	source_name="${picked%%$'\t'*}"
	dir="${picked#*$'\t'}"
	shell::logger::info "Library: $dir ($source_name)"

	# The session's library may shadow a different, valid hook (e.g. a development checkout).
	if [ "$source_name" = "session" ] && [ -n "$hook_dir" ] && [ "$hook_dir" != "$dir" ] && [ -f "$hook_dir/src/shell.sh" ]; then
		shell::logger::warn "$rc_file points to a valid installation ($hook_dir), but this session runs $dir."
		if [ "$dry_run" != "true" ]; then
			shell::ask::accept "Point $rc_file to $dir?" || {
				shell::logger::info "Nothing changed. Use --dir to choose explicitly."
				return "$RETURN_CANCELLED"
			}
		fi
	fi

	# 3. What the profile should contain.
	local updated
	updated="$(printf '%s' "$current" | _shell::zsh::install::awk rewrite "$dir" && printf x)"
	case "$updated" in
	*x) updated="${updated%x}" ;;
	*)
		shell::logger::error "$rc_file has a '$SHELL_ZSH_HOOK_BEGIN' block that is never closed ('$SHELL_ZSH_HOOK_END'); fix it by hand. Nothing was changed."
		return "$RETURN_FAILURE"
		;;
	esac

	local has_block="false" action
	case "$current" in
	"$SHELL_ZSH_HOOK_BEGIN"* | *"$nl$SHELL_ZSH_HOOK_BEGIN"*) has_block="true" ;;
	esac
	if [ "$existed" != "true" ]; then
		action="create"
	elif [ "$updated" = "$current" ]; then
		action="noop"
	elif [ "$has_block" = "true" ]; then
		action="update"
	elif [ -n "$hook_dir" ]; then
		action="migrate"
	else
		action="append"
	fi

	local block="$SHELL_ZSH_HOOK_BEGIN${nl}source \"$dir/src/shell.sh\"${nl}$SHELL_ZSH_HOOK_END"
	case "$action" in
	noop) shell::logger::success "$rc_file already sources the library from $dir; nothing to do." ;;
	*)
		if [ "$dry_run" = "true" ]; then
			shell::logger::info "Dry run (action: $action). Nothing is written. The hook block is:"
			shell::logger::info "  $SHELL_ZSH_HOOK_BEGIN"
			shell::logger::info "  source \"$dir/src/shell.sh\""
			shell::logger::info "  $SHELL_ZSH_HOOK_END"
			if [ "$existed" = "true" ]; then
				shell::logger::command_clip "cp -p '$rc_file' '$rc_file$SHELL_ZSH_BACKUP_SUFFIX'"
			fi
			case "$action" in
			create) shell::logger::command_clip "write '$rc_file' = the block   # temp file + mv" ;;
			append) shell::logger::command_clip "write '$rc_file' = current content + a blank line + the block   # temp file + mv" ;;
			*) shell::logger::command_clip "write '$rc_file' = current content with the hook replaced in place   # temp file + mv" ;;
			esac
		else
			_shell::zsh::install::write "$rc_file" "$updated" "$existed" || return "$RETURN_FAILURE"
			case "$action" in
			create) shell::logger::success "Created $rc_file with the hook for $dir." ;;
			append) shell::logger::success "Added the hook for $dir to $rc_file (backup: $rc_file$SHELL_ZSH_BACKUP_SUFFIX)." ;;
			update) shell::logger::success "Updated the hook in $rc_file to $dir (backup: $rc_file$SHELL_ZSH_BACKUP_SUFFIX)." ;;
			migrate) shell::logger::success "Migrated the legacy line of $rc_file into the marked block for $dir (backup: $rc_file$SHELL_ZSH_BACKUP_SUFFIX)." ;;
			esac
			shell::logger::info "Open a new zsh, or run: exec zsh"
		fi
		;;
	esac

	if [ "$make_default" = "true" ]; then
		_shell::zsh::install::login_shell "$dry_run" || return $?
	fi
	return "$RETURN_SUCCESS"
}
