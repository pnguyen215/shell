#!/usr/bin/env bash
# @file shell.sh
# @brief Library entry point: resolves its own location and loads every module.
# @description
#   Source this file from `~/.bashrc` or `~/.zshrc`:
#
#       source "$HOME/shell/src/shell.sh"
#
#   Works in bash (>= 3.2, i.e. the macOS system bash) and zsh.
#
#   Load order: constants first (system.sh before the rest), then each group in
#   SHELL_MODULE_GROUPS (core, dependency, lib, lang, devops, shield, bot,
#   alias), files alphabetically within a group.
#
#   Unlike the previous loader this one does NOT hide errors: a module that
#   fails to load is reported on stderr with its path, and the failure count is
#   left in SHELL_LOAD_ERRORS. Set SHELL_DEBUG=1 to trace every loaded file.
#
#   The naming rule `shell::<category>::...` does not apply to this file.

# --- 1. Locate the library root
# An explicit SHELL_DIR (exported by the user) always wins.
if [ -z "${SHELL_DIR-}" ]; then
	if [ -n "${ZSH_VERSION-}" ]; then
		# ${(%):-%x} is the zsh idiom for "path of the file being sourced"; it is
		# evaluated lazily so bash never tries to parse the zsh-only syntax.
		eval '_shell_self="${(%):-%x}"'
	elif [ -n "${BASH_VERSION-}" ]; then
		_shell_self="${BASH_SOURCE[0]}"
	else
		_shell_self="$HOME/shell/src/shell.sh"
	fi
	# src/shell.sh -> <root>/src -> <root>
	SHELL_DIR="$(cd "$(dirname "$_shell_self")/.." 2>/dev/null && pwd)"
	unset _shell_self
fi

# --- 2. Directory loader

# @description Source every `*.sh` file of a directory, in alphabetical order.
#   A failing file is reported (with its path) and counted in
#   `SHELL_LOAD_ERRORS`; loading then continues with the next file.
# @arg $1 string Directory to load.
# @set SHELL_LOAD_ERRORS integer Incremented once per file that failed to load.
# @exitcode 0 The directory was processed.
# @exitcode 1 The directory does not exist.
# @example
#   shell::source_directory "$SHELL_SRC_DIR/lib"
#
shell::source_directory() {
	local dir="${1-}"
	local file

	if [ ! -d "$dir" ]; then
		return 1
	fi

	# zsh aborts the whole loop when a glob matches nothing; null_glob makes an
	# empty match expand to nothing instead. (bash keeps the literal pattern,
	# which the -f test below filters out.)
	if [ -n "${ZSH_VERSION-}" ]; then
		setopt local_options null_glob
	fi

	for file in "$dir"/*.sh; do
		[ -f "$file" ] || continue

		if [ -n "${SHELL_DEBUG-}" ]; then
			printf 'shell: loading %s\n' "$file" >&2
		fi

		# shellcheck source=/dev/null
		if ! source "$file"; then
			printf 'shell: failed to load %s\n' "$file" >&2
			SHELL_LOAD_ERRORS=$((SHELL_LOAD_ERRORS + 1))
		fi
	done
	return 0
}

# --- 3. Load everything
SHELL_LOAD_ERRORS=0

# system.sh defines SHELL_SRC_DIR and the group list, so it must come first.
# shellcheck source=/dev/null
if ! source "$SHELL_DIR/src/constant/system.sh"; then
	printf 'shell: cannot load %s/src/constant/system.sh (is SHELL_DIR correct?)\n' "$SHELL_DIR" >&2
	return 1 2>/dev/null || exit 1
fi

for _shell_group in "${SHELL_MODULE_GROUPS[@]}"; do
	shell::source_directory "$SHELL_SRC_DIR/$_shell_group"
done
unset _shell_group

# Detect the OS once, in the current shell (not a subshell) so the result is
# cached in SHELL_OS_TYPE and every later shell::os::type call is fork-free.
shell::os::type >/dev/null 2>&1

SHELL_LOADED=1

# --- 4. Lifecycle commands

# @description Print the latest released version of the library.
# @noargs
# @stdout Release information from the GitHub API.
# @exitcode 0 Success.
# @exitcode 1 The release lookup failed.
# @example
#   shell::version
#
shell::version() {
	shell::git::repos::version::latest "$SHELL_REPO_SLUG"
}

# @description Upgrade the library to the latest version.
#   Runs the installer, which stages the new version, verifies it and only then
#   swaps it into place, keeping the previous one as `<dir>.bak`. The old
#   implementation deleted the installation first and downloaded afterwards, so
#   a network failure left the user with nothing.
# @option -h | --help Show help and return.
# @exitcode 0 Upgraded and reloaded.
# @exitcode 1 The installer failed (the old version is kept).
# @example
#   shell::upgrade
#
shell::upgrade() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Upgrade the shell library to the latest version"
		shell::logger::usage "shell::upgrade"
		shell::logger::option "-h, --help" "Display this help message"
		return "$RETURN_SUCCESS"
	fi

	shell::logger::info "Upgrading shell..."
	shell::net::run_remote_script "$SHELL_URL_INSTALL" bash || {
		shell::logger::error "Upgrade failed; the current installation was left untouched."
		return "$RETURN_FAILURE"
	}

	# Load the new version into this session.
	# shellcheck source=/dev/null
	source "$SHELL_DIR/src/shell.sh"
	shell::logger::success "shell upgraded and reloaded."
}

# @description Uninstall the library.
#   Delegates to uninstall.sh, which removes the installation directory and the
#   `source` line from your shell profile. Your data in `~/.shell-config` is
#   kept unless `--purge` is given.
# @option -h | --help Show help and return.
# @option --purge Also delete the configuration directory (SHELL_CONFIG_DIR).
# @exitcode 0 Uninstalled.
# @exitcode 1 uninstall.sh was not found or failed.
# @example
#   shell::uninstall
#   shell::uninstall --purge
#
shell::uninstall() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Uninstall the shell library"
		shell::logger::usage "shell::uninstall [--purge]"
		shell::logger::option "--purge" "Also delete ~/.shell-config"
		shell::logger::option "-h, --help" "Display this help message"
		return "$RETURN_SUCCESS"
	fi

	local script="$SHELL_DIR/uninstall.sh"
	if [ ! -f "$script" ]; then
		shell::logger::error "uninstall.sh not found at $script"
		return "$RETURN_NOT_FOUND"
	fi
	SHELL_DIR="$SHELL_DIR" bash "$script" "$@"
}
