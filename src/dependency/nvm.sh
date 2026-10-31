#!/usr/bin/env bash
# @file dependency/nvm.sh
# @brief Find, load, install and remove nvm (Node Version Manager).
# @description
#   nvm is a **shell function**, not a program: `nvm use` changes the PATH of the
#   shell it runs in, so it cannot be started as a child process and has to be
#   *sourced* (`. "$NVM_DIR/nvm.sh"`). That is what shell::dependency::nvm::load
#   does, once, so every `shell::nvm::*` command can call `nvm` in the current
#   shell, where `use` and `deactivate` keep their effect.
#
#   nvm is looked for in `$NVM_DIR`, `~/.nvm`, `$XDG_CONFIG_HOME/nvm` and the
#   Homebrew prefixes (`brew install nvm`). It is loaded with `--no-use`, so
#   loading never switches your Node version or slows anything down.
#
#   The commands themselves are in lang/nvm.sh (shell::nvm::*). The name
#   `shell::nvm::install` is `nvm install <version>`, which is why installing nvm
#   itself is `shell::dependency::nvm::install`.

# @description Print the path of nvm's `nvm.sh`, searching the usual places.
#   Order: `$NVM_DIR`, `~/.nvm`, `$XDG_CONFIG_HOME/nvm` (default `~/.config/nvm`),
#   then the Homebrew prefixes for Apple Silicon, Intel and Linux.
# @noargs
# @stdout Absolute path to `nvm.sh`.
# @exitcode 0 nvm.sh was found.
# @exitcode 3 nvm is not installed.
# @example
#   nvm_sh="$(shell::dependency::nvm::path)" || echo "no nvm"
#
shell::dependency::nvm::path() {
	local candidate
	for candidate in \
		"${NVM_DIR:+$NVM_DIR/nvm.sh}" \
		"$HOME/.nvm/nvm.sh" \
		"${XDG_CONFIG_HOME:-$HOME/.config}/nvm/nvm.sh" \
		/opt/homebrew/opt/nvm/nvm.sh \
		/usr/local/opt/nvm/nvm.sh \
		/home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh; do
		if [ -n "$candidate" ] && [ -s "$candidate" ]; then
			printf '%s\n' "$candidate"
			return "$RETURN_SUCCESS"
		fi
	done
	return "$RETURN_NOT_FOUND"
}

# @description Make the `nvm` function available in the current shell.
#   Does nothing when `nvm` is already a function (for instance because your
#   profile loaded it). Otherwise it sources `nvm.sh` with `--no-use`, after
#   exporting `NVM_DIR` (the directory of nvm.sh, or `~/.nvm` when nvm comes from
#   Homebrew, whose nvm.sh lives outside your data directory).
# @noargs
# @exitcode 0 `nvm` is available.
# @exitcode 3 nvm is not installed (install it with shell::dependency::nvm::install).
# @see shell::dependency::nvm::install
# @example
#   shell::dependency::nvm::load && nvm --version
#
shell::dependency::nvm::load() {
	if type nvm 2>/dev/null | grep -q "function"; then
		return "$RETURN_SUCCESS"
	fi

	local nvm_sh nvm_home
	nvm_sh="$(shell::dependency::nvm::path)" || return "$RETURN_NOT_FOUND"
	nvm_home="$(dirname "$nvm_sh")"

	# A Homebrew nvm.sh is not the data directory: keep the user's NVM_DIR or use ~/.nvm.
	case "$nvm_home" in
	*/opt/nvm)
		nvm_home="${NVM_DIR:-$HOME/.nvm}"
		mkdir -p "$nvm_home" 2>/dev/null
		;;
	esac
	export NVM_DIR="${NVM_DIR:-$nvm_home}"

	# shellcheck source=/dev/null
	. "$nvm_sh" --no-use
}

# @description Install nvm with its official installer, then load it.
#   The installer is pinned to a release (`SHELL_NVM_VERSION`) and run only after
#   it was downloaded completely. It adds the loader lines to your shell profile,
#   unless `--no-profile` is given. Nothing happens when nvm is already installed.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the installer command instead of running it.
# @option -v | --version Release to install, e.g. `v0.40.8` (default: SHELL_NVM_VERSION).
# @option -p | --no-profile Do not touch your shell profile (`PROFILE=/dev/null`).
# @exitcode 0 Installed, already installed, or dry-run printed.
# @exitcode 1 The installer failed.
# @exitcode 2 Invalid option or version.
# @see shell::dependency::nvm::uninstall
# @example
#   shell::dependency::nvm::install
#   shell::dependency::nvm::install -n -v v0.40.8
#
shell::dependency::nvm::install() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Install nvm (Node Version Manager) with the official installer"
		shell::logger::usage "shell::dependency::nvm::install [-n] [-v <version>] [-p]"
		shell::logger::option "-v, --version <tag>" "Release to install, e.g. v0.40.8 (default SHELL_NVM_VERSION)"
		shell::logger::option "-p, --no-profile" "Do not add the loader lines to your shell profile"
		shell::logger::option "-n, --dry-run" "Print the installer command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::dependency::nvm::install -n"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" version="$SHELL_NVM_VERSION" no_profile="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-p | --no-profile) no_profile="true" ;;
		-v | --version)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			version="$2"
			shift
			;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done

	case "$version" in
	v[0-9]*.[0-9]*.[0-9]* | [0-9]*.[0-9]*.[0-9]*) ;;
	*)
		shell::logger::error "Invalid nvm version: '$version' (expected a release such as v0.40.8)"
		return "$RETURN_INVALID"
		;;
	esac
	case "$version" in
	*[!0-9A-Za-z.]*)
		shell::logger::error "Invalid nvm version: '$version'"
		return "$RETURN_INVALID"
		;;
	esac
	case "$version" in
	v*) ;;
	*) version="v$version" ;;
	esac

	local url="${SHELL_URL_NVM_RAW}/${version}/install.sh"
	local target="${NVM_DIR:-$HOME/.nvm}"
	local -a run_opts=()
	if [ "$dry_run" = "true" ]; then
		run_opts=(-n)
	elif shell::dependency::nvm::path >/dev/null 2>&1; then
		shell::logger::warn "nvm is already installed ($(shell::dependency::nvm::path))."
		shell::dependency::nvm::load
		return "$RETURN_SUCCESS"
	fi

	if [ "$dry_run" = "false" ]; then
		# The installer needs git, or curl / wget.
		shell::dependency::curl::ensure || return "$RETURN_FAILURE"
		shell::logger::info "Installing nvm $version..."
	fi
	# PROFILE is only set when asked for: an empty one would hide the one you already export.
	if [ "$no_profile" = "true" ]; then
		NVM_DIR="$target" PROFILE="/dev/null" shell::net::run_remote_script ${run_opts[@]+"${run_opts[@]}"} "$url" bash || return "$RETURN_FAILURE"
	else
		NVM_DIR="$target" shell::net::run_remote_script ${run_opts[@]+"${run_opts[@]}"} "$url" bash || return "$RETURN_FAILURE"
	fi
	if [ "$dry_run" = "true" ]; then
		return "$RETURN_SUCCESS"
	fi

	export NVM_DIR="$target"
	shell::dependency::nvm::load || return "$RETURN_FAILURE"
	shell::logger::success "nvm installed. Try: shell::nvm::install --lts"
}

# @description Remove nvm, **every Node version installed through it**, and its
#   loader lines from your shell profile.
#   Safety rules: only a directory that contains `nvm.sh` is removed; `/`, your
#   home directory and relative paths are refused; an nvm installed by
#   Homebrew is left to `brew uninstall nvm`. Each profile file that is changed
#   keeps a copy named `<file>.nvm-backup`. You are asked first unless `-y`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print what would be removed instead of removing it.
# @option -y | --yes Do not ask for confirmation.
# @exitcode 0 Removed, nothing to remove, or the user declined.
# @exitcode 1 A removal step failed.
# @exitcode 2 Invalid option, or `NVM_DIR` is not a safe directory to delete.
# @see shell::dependency::nvm::install
# @example
#   shell::dependency::nvm::uninstall -n
#   shell::dependency::nvm::uninstall -y
#
shell::dependency::nvm::uninstall() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Remove nvm, its Node versions and its shell-profile lines"
		shell::logger::usage "shell::dependency::nvm::uninstall [-n] [-y]"
		shell::logger::option "-n, --dry-run" "Print what would be removed instead of removing it"
		shell::logger::option "-y, --yes" "Skip the confirmation prompt"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::dependency::nvm::uninstall -n"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" assume_yes="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-y | --yes) assume_yes="true" ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done

	local nvm_sh dir
	nvm_sh="$(shell::dependency::nvm::path)" || {
		shell::logger::warn "nvm is not installed. Nothing to uninstall."
		return "$RETURN_SUCCESS"
	}
	dir="${NVM_DIR:-$(dirname "$nvm_sh")}"

	case "$nvm_sh" in
	*/opt/nvm/nvm.sh)
		shell::logger::warn "nvm was installed by Homebrew; remove it with: brew uninstall nvm"
		return "$RETURN_SUCCESS"
		;;
	esac
	case "$dir" in
	'' | / | "$HOME" | "$HOME"/ | [!/]*)
		shell::logger::error "Refusing to delete '$dir': NVM_DIR must be an absolute path other than / or your home directory"
		return "$RETURN_INVALID"
		;;
	esac
	if [ ! -f "$dir/nvm.sh" ]; then
		shell::logger::error "Refusing to delete '$dir': it does not contain nvm.sh"
		return "$RETURN_INVALID"
	fi

	local rc_file versions=0
	local -a rc_files=()
	for rc_file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zprofile"; do
		if [ -f "$rc_file" ] && grep -q -E 'NVM_DIR' "$rc_file" 2>/dev/null; then
			rc_files+=("$rc_file")
		fi
	done
	if [ -d "$dir/versions/node" ]; then
		versions="$(find "$dir/versions/node" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "rm -rf \"$dir\""
		for rc_file in ${rc_files[@]+"${rc_files[@]}"}; do
			shell::logger::info "Would remove the nvm lines from $rc_file (a copy is kept as ${rc_file}.nvm-backup)"
		done
		return "$RETURN_SUCCESS"
	fi

	if [ "$assume_yes" != "true" ]; then
		shell::ask::accept "Delete $dir with $versions installed Node version(s) and the nvm lines of your shell profile?" || {
			shell::logger::info "Aborted."
			return "$RETURN_SUCCESS"
		}
	fi

	# Undo the effects of nvm in this shell first (PATH, the nvm functions).
	if type nvm 2>/dev/null | grep -q "function"; then
		nvm deactivate >/dev/null 2>&1
		nvm unload >/dev/null 2>&1
	fi

	rm -rf "$dir" || return "$RETURN_FAILURE"
	for rc_file in ${rc_files[@]+"${rc_files[@]}"}; do
		cp "$rc_file" "${rc_file}.nvm-backup" || return "$RETURN_FAILURE"
		shell::fs::sed_inplace -e '/^export NVM_DIR=/d' -e '/NVM_DIR\/nvm\.sh/d' -e '/NVM_DIR\/bash_completion/d' "$rc_file" || return "$RETURN_FAILURE"
	done
	unset NVM_DIR
	shell::logger::success "nvm removed ($dir)."
}
