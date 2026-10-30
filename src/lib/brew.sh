#!/usr/bin/env bash
# @file lib/brew.sh
# @brief Homebrew package commands: install, upgrade, pin, taps, services, bundle, cleanup ...
# @description
#   One documented function per `brew` command, so everything in the Homebrew
#   cheat sheet (https://quickref.me/homebrew) is a `shell::brew::*` call with
#   the same flags, a `-n | --dry-run` switch and argument validation.
#
#   These functions manage **packages**. Installing or removing Homebrew itself
#   is `shell::homebrew::install` / `shell::homebrew::uninstall`
#   (src/dependency/homebrew.sh). The interactive (fzf) layer and the tools that
#   find unused packages live in lib/brew_fzf.sh.
#
#   Conventions shared by every function in this file:
#
#   * `-n | --dry-run` prints the `brew` command (and copies it to the
#     clipboard) instead of running it. It never needs Homebrew to be installed.
#   * `-c | --cask` works on casks (GUI apps); `--formula` works on formulae.
#     Without either, Homebrew picks by itself.
#   * `-f` always means `--force`; Homebrew's own dry-run is `-p | --preview`
#     (our `-n` shows the command, `--preview` asks brew what it *would* do).
#   * Package names are validated before brew sees them: a name can never start
#     with `-`, so it cannot be mistaken for an option, and it cannot contain
#     spaces, quotes, `$`, `;`, `..` or other shell metacharacters.
#   * brew is started argv style (no `eval`), so a value is never re-parsed.
#
#   What changed since the cheat sheet was written: `brew cask <cmd>` is now
#   `brew <cmd> --cask`, and `brew switch` was removed from Homebrew;
#   shell::brew::switch reproduces it with `unlink` + `link --overwrite`.

# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

# @internal
# @description Tell whether a string is a safe Homebrew package name.
#   Accepts formula, cask, versioned (`node@20`, `gcc@13`), `c++` style and
#   tap-qualified (`user/repo/name`) names. Rejects an empty name, a leading `-`
#   or `.`, a `..` anywhere, and every character outside `A-Z a-z 0-9 @ + . _ / -`.
# @arg $1 string The candidate name.
# @exitcode 0 The name is safe.
# @exitcode 1 The name is not safe.
# @example
#   shell::brew::name::valid "node@20" && echo ok
#
shell::brew::name::valid() {
	case "${1-}" in
	'' | [!A-Za-z0-9]* | *..* | *[!A-Za-z0-9@+._/-]*) return 1 ;;
	esac
	return 0
}

# @internal
# @description Tell whether a string is a tap name: `user/repo`.
# @arg $1 string The candidate tap.
# @exitcode 0 It is `user/repo` made of `A-Z a-z 0-9 . _ -`.
# @exitcode 1 It is not.
# @example
#   shell::brew::tap::valid "homebrew/cask-versions" && echo ok
#
shell::brew::tap::valid() {
	case "${1-}" in
	'' | [!A-Za-z0-9]* | */ | /* | */*/* | *..* | *[!A-Za-z0-9._/-]*) return 1 ;;
	*/*) return 0 ;;
	esac
	return 1
}

# @internal
# @description Run a read-only `brew` query quietly and print its output.
#   Used by the interactive layer to gather data. Nothing is echoed or logged,
#   stderr is discarded and `HOMEBREW_NO_AUTO_UPDATE=1` keeps it fast.
# @arg $@ string Arguments for brew.
# @stdout What brew printed.
# @exitcode 0 brew succeeded.
# @exitcode 3 Homebrew is not installed.
# @exitcode N Exit status of brew.
# @example
#   shell::brew::query list --formula -1
#
shell::brew::query() {
	local brew_bin
	brew_bin="$(shell::homebrew::path)" || return "$RETURN_NOT_FOUND"
	HOMEBREW_NO_AUTO_UPDATE=1 "$brew_bin" "$@" 2>/dev/null
}

# @description Run `brew <args>` (argv style) and echo the command first.
#   The single place that starts the brew executable for every mutating or
#   user-visible command. With `-n` it only prints `brew <args>` and copies it
#   to the clipboard; in that case Homebrew need not be installed.
# @option -n | --dry-run Print the command instead of running it.
# @arg $@ string The brew sub-command and its arguments, e.g. `install --cask firefox`.
# @exitcode 0 brew succeeded (or the dry-run printed).
# @exitcode 2 No sub-command was given.
# @exitcode 3 Homebrew is not installed.
# @exitcode N Exit status of brew.
# @see shell::homebrew::install
# @example
#   shell::brew::run install git
#   shell::brew::run -n upgrade --cask
#
shell::brew::run() {
	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if [ "$#" -eq 0 ]; then
		shell::logger::error "A brew sub-command is required"
		return "$RETURN_INVALID"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "brew $*"
		return "$RETURN_SUCCESS"
	fi

	local brew_bin
	brew_bin="$(shell::homebrew::path)" || {
		shell::logger::error "Homebrew is not installed (install it with: shell::homebrew::install)"
		return "$RETURN_NOT_FOUND"
	}
	shell::exec::command "$brew_bin" "$@"
}

# @internal
# @description The generic engine behind most commands: parse flags, validate
#   the names, then run `brew <verb> [flags] [names]`.
#
#   `spec` lists the flags the caller accepts, one per line, as
#   `short|long|brew-flag`. A brew-flag that ends with `=` takes a value
#   (`--prune|--prune|--prune=` accepts `--prune 30` and `--prune=30`). `-n` and
#   `--dry-run` are always accepted. Everything after `--` is a name.
#
#   `mode` decides how the names are checked: `pkg` (formula/cask names),
#   `sub` (a brew sub-command), `text` (free text, only non-empty), `tap` (the
#   first is `user/repo`, the second a URL), `taprepo` (all are `user/repo`).
# @arg $1 string The brew verb (`install`, `list`, `--prefix` ...).
# @arg $2 integer Minimum number of names.
# @arg $3 integer Maximum number of names (-1 = no limit).
# @arg $4 string Mode: pkg | sub | text | tap | taprepo.
# @arg $5 string What a name is called in messages (e.g. "package name").
# @arg $6 string The flag spec (multi-line).
# @arg $@ string The caller's own arguments.
# @exitcode 0 brew succeeded (or the dry-run printed).
# @exitcode 2 Unknown flag, a missing value, a wrong number of names or an unsafe name.
# @exitcode 3 Homebrew is not installed.
# @exitcode N Exit status of brew.
# @example
#   shell::brew::pkgcmd install 1 -1 pkg "package name" "-c|--cask|--cask" "$@"
#
shell::brew::pkgcmd() {
	local verb="${1-}" min="${2-0}" max="${3--1}" mode="${4-pkg}" what="${5-package name}" spec="${6-}"
	shift 6

	local dry_run="false" matched consume value s l f count index_name arg saw_dashes="false"
	local -a flags=() names=() run_opts=()

	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		--)
			shift
			saw_dashes="true"
			while [ "$#" -gt 0 ]; do
				names+=("$1")
				shift
			done
			;;
		-?*)
			matched=""
			consume=1
			while IFS='|' read -r s l f; do
				[ -n "$l" ] || continue
				case "$f" in
				*=)
					if [ "$1" = "$s" ] || [ "$1" = "$l" ]; then
						if [ "$#" -lt 2 ]; then
							shell::logger::error "Option $1 requires a value"
							return "$RETURN_INVALID"
						fi
						value="$2"
						consume=2
					else
						case "$1" in
						"$l"=*) value="${1#*=}" ;;
						*) continue ;;
						esac
					fi
					case "$value" in
					'' | *[!A-Za-z0-9._-]*)
						shell::logger::error "Invalid value for $l: '$value'"
						return "$RETURN_INVALID"
						;;
					esac
					matched="${f}${value}"
					break
					;;
				*)
					if { [ -n "$s" ] && [ "$1" = "$s" ]; } || [ "$1" = "$l" ]; then
						matched="$f"
						break
					fi
					;;
				esac
			done <<EOF
$spec
EOF
			if [ -z "$matched" ]; then
				shell::logger::error "Unknown option: $1"
				return "$RETURN_INVALID"
			fi
			flags+=("$matched")
			shift "$consume"
			;;
		*)
			names+=("$1")
			shift
			;;
		esac
	done

	count="${#names[@]}"
	if [ "$count" -lt "$min" ]; then
		shell::logger::error "At least $min ${what}(s) required"
		return "$RETURN_INVALID"
	fi
	if [ "$max" -ge 0 ] && [ "$count" -gt "$max" ]; then
		if [ "$max" -eq 0 ]; then
			shell::logger::error "This command takes no arguments (got '${names[0]}')"
		else
			shell::logger::error "Too many arguments: at most $max ${what}(s)"
		fi
		return "$RETURN_INVALID"
	fi

	index_name=0
	for arg in ${names[@]+"${names[@]}"}; do
		index_name=$((index_name + 1))
		case "$mode" in
		pkg)
			if ! shell::brew::name::valid "$arg"; then
				shell::logger::error "Invalid $what: '$arg'"
				return "$RETURN_INVALID"
			fi
			;;
		sub)
			case "$arg" in
			'' | [!a-z]* | *[!a-z0-9-]*)
				shell::logger::error "Invalid $what: '$arg'"
				return "$RETURN_INVALID"
				;;
			esac
			;;
		text)
			if [ -z "$arg" ]; then
				shell::logger::error "The $what cannot be empty"
				return "$RETURN_INVALID"
			fi
			;;
		tap)
			if [ "$index_name" -eq 1 ]; then
				if ! shell::brew::tap::valid "$arg"; then
					shell::logger::error "Invalid tap '$arg' (expected user/repo)"
					return "$RETURN_INVALID"
				fi
			else
				case "$arg" in
				'' | -* | *[[:space:]]*)
					shell::logger::error "Invalid tap URL: '$arg'"
					return "$RETURN_INVALID"
					;;
				esac
			fi
			;;
		taprepo)
			if ! shell::brew::tap::valid "$arg"; then
				shell::logger::error "Invalid tap '$arg' (expected user/repo)"
				return "$RETURN_INVALID"
			fi
			;;
		esac
	done

	if [ "$dry_run" = "true" ]; then
		run_opts=(-n)
	fi
	# Text given after `--` may start with a dash (`search -- -x`): keep the `--`
	# so brew does not take it for an option.
	if [ "$saw_dashes" = "true" ]; then
		for arg in ${names[@]+"${names[@]}"}; do
			case "$arg" in
			-*)
				flags+=(--)
				break
				;;
			esac
		done
	fi
	shell::brew::run ${run_opts[@]+"${run_opts[@]}"} "$verb" ${flags[@]+"${flags[@]}"} ${names[@]+"${names[@]}"}
}

# --------------------------------------------------------------------------
# Getting started and help
# --------------------------------------------------------------------------

# @description Show the installed Homebrew version (`brew --version`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @exitcode 0 Success.
# @exitcode 3 Homebrew is not installed.
# @example
#   shell::brew::version
#
shell::brew::version() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show the Homebrew version (brew --version)"
		shell::logger::usage "shell::brew::version [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::version"
		return "$RETURN_SUCCESS"
	fi
	shell::brew::pkgcmd --version 0 0 pkg "argument" "" "$@"
}

# @description Print help for Homebrew or for one brew sub-command (`brew help [cmd]`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string Optional sub-command, e.g. `install` (lower-case letters, digits, `-`).
# @exitcode 0 Success.
# @exitcode 2 The sub-command name is invalid.
# @exitcode 3 Homebrew is not installed.
# @example
#   shell::brew::help
#   shell::brew::help install
#
shell::brew::help() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show Homebrew help, or the help of one sub-command"
		shell::logger::usage "shell::brew::help [-n] [<sub-command>]"
		shell::logger::item "sub-command" "Optional brew command, e.g. install"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::help install"
		return "$RETURN_SUCCESS"
	fi
	shell::brew::pkgcmd help 0 1 sub "sub-command" "" "$@"
}

# @description Check the system for potential problems (`brew doctor`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @exitcode 0 Success (brew reports its own warnings and exits non-zero when it finds any).
# @exitcode 3 Homebrew is not installed.
# @example
#   shell::brew::doctor
#
shell::brew::doctor() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Check the system for potential Homebrew problems"
		shell::logger::usage "shell::brew::doctor [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::doctor"
		return "$RETURN_SUCCESS"
	fi
	shell::brew::pkgcmd doctor 0 0 pkg "argument" "" "$@"
}

# @description Show the Homebrew configuration (`brew config`): prefix, versions, taps ...
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @exitcode 0 Success.
# @exitcode 3 Homebrew is not installed.
# @example
#   shell::brew::config
#
shell::brew::config() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show the Homebrew configuration"
		shell::logger::usage "shell::brew::config [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::config"
		return "$RETURN_SUCCESS"
	fi
	shell::brew::pkgcmd config 0 0 pkg "argument" "" "$@"
}

# @description Print the Homebrew prefix, or the prefix of one package (`brew --prefix [name]`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string Optional package name.
# @stdout The absolute path.
# @exitcode 0 Success.
# @exitcode 2 The package name is invalid.
# @exitcode 3 Homebrew is not installed.
# @example
#   shell::brew::prefix
#   shell::brew::prefix openssl@3
#
shell::brew::prefix() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Print the Homebrew prefix, or the prefix of one package"
		shell::logger::usage "shell::brew::prefix [-n] [<name>]"
		shell::logger::item "name" "Optional formula name"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::prefix openssl@3"
		return "$RETURN_SUCCESS"
	fi
	shell::brew::pkgcmd --prefix 0 1 pkg "package name" "" "$@"
}

# @description Print the download cache directory (`brew --cache`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @stdout The absolute path.
# @exitcode 0 Success.
# @exitcode 3 Homebrew is not installed.
# @example
#   du -sh "$(shell::brew::cache)"
#
shell::brew::cache() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Print the Homebrew download cache directory"
		shell::logger::usage "shell::brew::cache [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "du -sh \"\$(shell::brew::cache)\""
		return "$RETURN_SUCCESS"
	fi
	shell::brew::pkgcmd --cache 0 0 pkg "argument" "" "$@"
}

# --------------------------------------------------------------------------
# Updates
# --------------------------------------------------------------------------

# @description Fetch the latest Homebrew and formula definitions (`brew update`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -f | --force Always do a slower, full update check.
# @exitcode 0 Success.
# @exitcode 3 Homebrew is not installed.
# @example
#   shell::brew::update
#
shell::brew::update() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Fetch the latest Homebrew and formulae"
		shell::logger::usage "shell::brew::update [-n] [-f]"
		shell::logger::option "-f, --force" "Always do a full update check"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::update"
		return "$RETURN_SUCCESS"
	fi
	shell::brew::pkgcmd update 0 0 pkg "argument" "-f|--force|--force" "$@"
}

# @description List packages that have a newer version (`brew outdated`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -c | --cask Only casks.
# @option --formula Only formulae.
# @option -g | --greedy Also include casks that update themselves (`auto_updates`) or are `latest`.
# @option -q | --quiet Names only.
# @option -v | --verbose Include the installed and the new version.
# @arg $@ string Optional package names to restrict the check to.
# @exitcode 0 Success.
# @exitcode 2 Invalid option or package name.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::upgrade
# @example
#   shell::brew::outdated
#   shell::brew::outdated --cask --greedy
#
shell::brew::outdated() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List installed packages that have a newer version"
		shell::logger::usage "shell::brew::outdated [-n] [-c | --formula] [-g] [-q | -v] [<name>...]"
		shell::logger::option "-c, --cask" "Only casks"
		shell::logger::option "--formula" "Only formulae"
		shell::logger::option "-g, --greedy" "Include self-updating and 'latest' casks"
		shell::logger::option "-q, --quiet" "Names only"
		shell::logger::option "-v, --verbose" "Show installed and new versions"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::outdated --cask --greedy"
		return "$RETURN_SUCCESS"
	fi
	local spec="-c|--cask|--cask
|--formula|--formula
-g|--greedy|--greedy
-q|--quiet|--quiet
-v|--verbose|--verbose"
	shell::brew::pkgcmd outdated 0 -1 pkg "package name" "$spec" "$@"
}

# @description Upgrade outdated packages, or only the named ones (`brew upgrade`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -c | --cask Only casks.
# @option --formula Only formulae.
# @option -g | --greedy Also upgrade casks that update themselves.
# @option -f | --force Install without checking whether the package is already up to date.
# @arg $@ string Optional package names. Without any, everything outdated and unpinned is upgraded.
# @exitcode 0 Success.
# @exitcode 2 Invalid option or package name.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::upgrade::fzf
# @example
#   shell::brew::upgrade
#   shell::brew::upgrade git jq
#   shell::brew::upgrade --cask --greedy
#
shell::brew::upgrade() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Upgrade all outdated and unpinned packages, or only the named ones"
		shell::logger::usage "shell::brew::upgrade [-n] [-c | --formula] [-g] [-f] [<name>...]"
		shell::logger::option "-c, --cask" "Only casks"
		shell::logger::option "--formula" "Only formulae"
		shell::logger::option "-g, --greedy" "Include self-updating casks"
		shell::logger::option "-f, --force" "Do not check whether the package is up to date"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::upgrade git jq"
		return "$RETURN_SUCCESS"
	fi
	local spec="-c|--cask|--cask
|--formula|--formula
-g|--greedy|--greedy
-f|--force|--force"
	shell::brew::pkgcmd upgrade 0 -1 pkg "package name" "$spec" "$@"
}

# @description Prevent packages from being upgraded (`brew pin`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -c | --cask Treat the names as casks.
# @option --formula Treat the names as formulae.
# @arg $@ string One or more installed package names.
# @exitcode 0 Success.
# @exitcode 2 No name, or an invalid one.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::unpin
# @example
#   shell::brew::pin node@20
#
shell::brew::pin() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Prevent packages from being upgraded"
		shell::logger::usage "shell::brew::pin [-n] [-c | --formula] <name>..."
		shell::logger::item "name" "Installed package(s) to pin"
		shell::logger::option "-c, --cask" "Treat the names as casks"
		shell::logger::option "--formula" "Treat the names as formulae"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::pin node@20"
		return "$RETURN_SUCCESS"
	fi
	local spec="-c|--cask|--cask
|--formula|--formula"
	shell::brew::pkgcmd pin 1 -1 pkg "package name" "$spec" "$@"
}

# @description Allow pinned packages to be upgraded again (`brew unpin`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -c | --cask Treat the names as casks.
# @option --formula Treat the names as formulae.
# @arg $@ string One or more pinned package names.
# @exitcode 0 Success.
# @exitcode 2 No name, or an invalid one.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::pin
# @example
#   shell::brew::unpin node@20
#
shell::brew::unpin() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Allow pinned packages to be upgraded again"
		shell::logger::usage "shell::brew::unpin [-n] [-c | --formula] <name>..."
		shell::logger::item "name" "Pinned package(s)"
		shell::logger::option "-c, --cask" "Treat the names as casks"
		shell::logger::option "--formula" "Treat the names as formulae"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::unpin node@20"
		return "$RETURN_SUCCESS"
	fi
	local spec="-c|--cask|--cask
|--formula|--formula"
	shell::brew::pkgcmd unpin 1 -1 pkg "package name" "$spec" "$@"
}

# @description List the pinned packages (`brew list --pinned`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @exitcode 0 Success.
# @exitcode 3 Homebrew is not installed.
# @example
#   shell::brew::pinned
#
shell::brew::pinned() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List the pinned packages"
		shell::logger::usage "shell::brew::pinned [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::pinned"
		return "$RETURN_SUCCESS"
	fi
	shell::brew::pkgcmd list 0 0 pkg "argument" "|--pinned|--pinned" --pinned "$@"
}

# --------------------------------------------------------------------------
# Taps (repositories)
# --------------------------------------------------------------------------

# @description List the taps, or add one (`brew tap [user/repo [url]]`).
#   With no argument it lists the current taps. With `user/repo` it taps
#   `https://github.com/user/homebrew-repo`; with a URL as well, that URL.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string Optional tap, `user/repo`.
# @arg $2 string Optional URL of the tap repository.
# @exitcode 0 Success.
# @exitcode 2 The tap or the URL is invalid.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::untap
# @example
#   shell::brew::tap
#   shell::brew::tap homebrew/cask-versions
#   shell::brew::tap acme/tools https://git.example.com/acme/homebrew-tools.git
#
shell::brew::tap() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List the taps, or tap a repository"
		shell::logger::usage "shell::brew::tap [-n] [<user/repo> [<url>]]"
		shell::logger::item "user/repo" "Tap to add (omit to list the taps)"
		shell::logger::item "url" "Clone the tap from this URL instead of GitHub"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::tap homebrew/cask-versions"
		return "$RETURN_SUCCESS"
	fi
	shell::brew::pkgcmd tap 0 2 tap "tap argument" "" "$@"
}

# @description Remove one or more taps (`brew untap`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -f | --force Untap even if formulae or casks from it are installed.
# @arg $@ string One or more taps, `user/repo`.
# @exitcode 0 Success.
# @exitcode 2 No tap, or an invalid one.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::tap
# @see shell::brew::untap::fzf
# @example
#   shell::brew::untap acme/tools
#
shell::brew::untap() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Remove taps"
		shell::logger::usage "shell::brew::untap [-n] [-f] <user/repo>..."
		shell::logger::item "user/repo" "Tap(s) to remove"
		shell::logger::option "-f, --force" "Untap even if packages from it are installed"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::untap acme/tools"
		return "$RETURN_SUCCESS"
	fi
	shell::brew::pkgcmd untap 1 -1 taprepo "tap" "-f|--force|--force" "$@"
}

# --------------------------------------------------------------------------
# Search, info, list
# --------------------------------------------------------------------------

# @description List the packages that can be installed (`brew formulae` / `brew casks`).
#   Works from the local index, so it is fast and offline; run
#   shell::brew::update first to refresh it.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -c | --cask List casks instead of formulae.
# @stdout One package name per line.
# @exitcode 0 Success.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::install::fzf
# @example
#   shell::brew::available | grep -c .
#   shell::brew::available --cask
#
shell::brew::available() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List every installable formula (or cask)"
		shell::logger::usage "shell::brew::available [-n] [-c]"
		shell::logger::option "-c, --cask" "List casks instead of formulae"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::available --cask"
		return "$RETURN_SUCCESS"
	fi
	local arg verb="formulae"
	local -a rest=()
	for arg in "$@"; do
		case "$arg" in
		-c | --cask) verb="casks" ;;
		*) rest+=("$arg") ;;
		esac
	done
	shell::brew::pkgcmd "$verb" 0 0 pkg "argument" "" ${rest[@]+"${rest[@]}"}
}

# @description Search formulae and casks by name, or by description (`brew search`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -c | --cask Search casks only.
# @option --formula Search formulae only.
# @option -d | --desc Search the descriptions as well as the names.
# @arg $1 string The text to look for; `/regex/` is supported by brew.
# @exitcode 0 Success.
# @exitcode 2 No text given.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::available
# @example
#   shell::brew::search python
#   shell::brew::search --desc --cask "video player"
#
shell::brew::search() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Search formulae and casks"
		shell::logger::usage "shell::brew::search [-n] [-c | --formula] [-d] <text>"
		shell::logger::item "text" "Text or /regex/ to look for"
		shell::logger::option "-c, --cask" "Casks only"
		shell::logger::option "--formula" "Formulae only"
		shell::logger::option "-d, --desc" "Also search descriptions"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::search --desc \"video player\""
		return "$RETURN_SUCCESS"
	fi
	local spec="-c|--cask|--cask
|--formula|--formula
-d|--desc|--desc"
	shell::brew::pkgcmd search 1 1 text "search text" "$spec" "$@"
}

# @description Show information about packages (`brew info`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -c | --cask Treat the names as casks.
# @option --formula Treat the names as formulae.
# @option -j | --json Print JSON (`--json=v2`) instead of text.
# @option -i | --installed Describe every installed package (with --json: as JSON).
# @arg $@ string Package names.
# @exitcode 0 Success.
# @exitcode 2 An invalid name.
# @exitcode 3 Homebrew is not installed.
# @example
#   shell::brew::info git
#   shell::brew::info --cask firefox
#   shell::brew::info --json --installed | jq '.formulae | length'
#
shell::brew::info() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show information about packages"
		shell::logger::usage "shell::brew::info [-n] [-c | --formula] [-j] [-i] [<name>...]"
		shell::logger::item "name" "Package name(s)"
		shell::logger::option "-c, --cask" "Treat the names as casks"
		shell::logger::option "--formula" "Treat the names as formulae"
		shell::logger::option "-j, --json" "Print JSON (v2)"
		shell::logger::option "-i, --installed" "Every installed package"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::info --cask firefox"
		return "$RETURN_SUCCESS"
	fi
	local spec="-c|--cask|--cask
|--formula|--formula
-j|--json|--json=v2
-i|--installed|--installed"
	shell::brew::pkgcmd info 0 -1 pkg "package name" "$spec" "$@"
}

# @description List installed packages (`brew list`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -c | --cask Only casks.
# @option --formula Only formulae.
# @option -v | --versions Show the installed versions.
# @option -r | --requested Only packages you installed yourself (not dependencies).
# @option --multiple With --versions, only packages with more than one version installed.
# @option --pinned Only pinned packages.
# @option -1 One name per line.
# @arg $@ string Optional package names (list their files, or with --versions their versions).
# @exitcode 0 Success.
# @exitcode 2 Invalid option or name.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::versions
# @example
#   shell::brew::list
#   shell::brew::list --cask --versions
#   shell::brew::list --versions --multiple
#
shell::brew::list() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List installed packages"
		shell::logger::usage "shell::brew::list [-n] [-c | --formula] [-v] [-r] [--multiple] [--pinned] [-1] [<name>...]"
		shell::logger::option "-c, --cask" "Only casks"
		shell::logger::option "--formula" "Only formulae"
		shell::logger::option "-v, --versions" "Show installed versions"
		shell::logger::option "-r, --requested" "Only packages you installed (not dependencies)"
		shell::logger::option "--multiple" "With --versions: more than one version installed"
		shell::logger::option "--pinned" "Only pinned packages"
		shell::logger::option "-1" "One name per line"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::list --versions --multiple"
		return "$RETURN_SUCCESS"
	fi
	local spec="-c|--cask|--cask
|--formula|--formula
-v|--versions|--versions
-r|--requested|--installed-on-request
|--multiple|--multiple
|--pinned|--pinned
-1|-1|-1"
	shell::brew::pkgcmd list 0 -1 pkg "package name" "$spec" "$@"
}

# @description Show the installed versions of packages (`brew list --versions <name>`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -c | --cask Treat the names as casks.
# @arg $@ string One or more package names.
# @exitcode 0 Success.
# @exitcode 2 No name, or an invalid one.
# @exitcode 3 Homebrew is not installed.
# @example
#   shell::brew::versions git
#
shell::brew::versions() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show the installed versions of packages"
		shell::logger::usage "shell::brew::versions [-n] [-c] <name>..."
		shell::logger::item "name" "Package name(s)"
		shell::logger::option "-c, --cask" "Treat the names as casks"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::versions git"
		return "$RETURN_SUCCESS"
	fi
	local spec="-c|--cask|--cask
|--versions|--versions"
	shell::brew::pkgcmd list 1 -1 pkg "package name" "$spec" --versions "$@"
}

# @description List installed formulae that nothing else depends on (`brew leaves`).
#   These are the packages you would remove first: they are what you asked for,
#   or leftovers of something you removed.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -r | --requested Only leaves you installed yourself.
# @option -d | --dependency Only leaves that were installed as a dependency.
# @exitcode 0 Success.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::unused
# @example
#   shell::brew::leaves --requested
#
shell::brew::leaves() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List installed formulae that no other formula depends on"
		shell::logger::usage "shell::brew::leaves [-n] [-r | -d]"
		shell::logger::option "-r, --requested" "Only leaves you installed yourself"
		shell::logger::option "-d, --dependency" "Only leaves installed as a dependency"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::leaves --requested"
		return "$RETURN_SUCCESS"
	fi
	local spec="-r|--requested|--installed-on-request
-d|--dependency|--installed-as-dependency"
	shell::brew::pkgcmd leaves 0 0 pkg "argument" "$spec" "$@"
}

# @description Show which formulae a package depends on (`brew deps`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -t | --tree Print a dependency tree.
# @option -i | --installed Restrict to installed packages (works without a name).
# @option -1 | --direct Only direct dependencies.
# @arg $@ string Package names.
# @exitcode 0 Success.
# @exitcode 2 Invalid option or name.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::uses
# @example
#   shell::brew::deps --tree git
#
shell::brew::deps() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show the dependencies of packages"
		shell::logger::usage "shell::brew::deps [-n] [-t] [-i] [-1] [<name>...]"
		shell::logger::option "-t, --tree" "Print a tree"
		shell::logger::option "-i, --installed" "Installed packages only"
		shell::logger::option "-1, --direct" "Direct dependencies only"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::deps --tree git"
		return "$RETURN_SUCCESS"
	fi
	local spec="-t|--tree|--tree
-i|--installed|--installed
-1|--direct|--direct"
	shell::brew::pkgcmd deps 0 -1 pkg "package name" "$spec" "$@"
}

# @description Show which formulae depend on a package (`brew uses`).
#   Always restricted to installed formulae unless `--all` is given, because
#   the unrestricted query has to read every formula and is very slow.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -a | --all Look at every formula, not only the installed ones (slow).
# @option -r | --recursive Include indirect dependents.
# @arg $@ string One or more package names.
# @exitcode 0 Success.
# @exitcode 2 No name, or an invalid one.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::deps
# @example
#   shell::brew::uses openssl@3
#
shell::brew::uses() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show which installed formulae depend on a package"
		shell::logger::usage "shell::brew::uses [-n] [-a] [-r] <name>..."
		shell::logger::item "name" "Package name(s)"
		shell::logger::option "-a, --all" "Every formula, not only installed ones (slow)"
		shell::logger::option "-r, --recursive" "Include indirect dependents"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::uses openssl@3"
		return "$RETURN_SUCCESS"
	fi
	local arg all="false"
	local -a rest=()
	for arg in "$@"; do
		case "$arg" in
		-a | --all) all="true" ;;
		*) rest+=("$arg") ;;
		esac
	done
	local spec="-r|--recursive|--recursive
-i|--installed|--installed"
	if [ "$all" = "true" ]; then
		shell::brew::pkgcmd uses 1 -1 pkg "package name" "$spec" ${rest[@]+"${rest[@]}"}
	else
		shell::brew::pkgcmd uses 1 -1 pkg "package name" "$spec" --installed ${rest[@]+"${rest[@]}"}
	fi
}

# @description Check packages for missing dependencies (`brew missing`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $@ string Optional package names (default: all installed).
# @exitcode 0 Success.
# @exitcode 2 An invalid name.
# @exitcode 3 Homebrew is not installed.
# @example
#   shell::brew::missing
#
shell::brew::missing() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Check installed packages for missing dependencies"
		shell::logger::usage "shell::brew::missing [-n] [<name>...]"
		shell::logger::item "name" "Optional package name(s)"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::missing"
		return "$RETURN_SUCCESS"
	fi
	shell::brew::pkgcmd missing 0 -1 pkg "package name" "" "$@"
}

# --------------------------------------------------------------------------
# Install, reinstall, uninstall
# --------------------------------------------------------------------------

# @description Install formulae or casks (`brew install`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -c | --cask Install casks (GUI apps) instead of formulae.
# @option --formula Treat the names as formulae.
# @option -f | --force Install even if already installed (overwrites conflicting files).
# @arg $@ string One or more package names.
# @exitcode 0 Success.
# @exitcode 2 No name, or an invalid one.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::install::fzf
# @example
#   shell::brew::install git jq
#   shell::brew::install --cask firefox
#   shell::brew::install -n node@20
#
shell::brew::install() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Install formulae or casks"
		shell::logger::usage "shell::brew::install [-n] [-c | --formula] [-f] <name>..."
		shell::logger::item "name" "Package name(s)"
		shell::logger::option "-c, --cask" "Install casks (GUI apps)"
		shell::logger::option "--formula" "Treat the names as formulae"
		shell::logger::option "-f, --force" "Install even if already installed"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::install git jq"
		shell::logger::example "shell::brew::install --cask firefox"
		return "$RETURN_SUCCESS"
	fi
	local spec="-c|--cask|--cask
|--formula|--formula
-f|--force|--force"
	shell::brew::pkgcmd install 1 -1 pkg "package name" "$spec" "$@"
}

# @description Reinstall formulae or casks (`brew reinstall`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -c | --cask Reinstall casks.
# @option --formula Treat the names as formulae.
# @option -f | --force Reinstall even if it is up to date.
# @arg $@ string One or more installed package names.
# @exitcode 0 Success.
# @exitcode 2 No name, or an invalid one.
# @exitcode 3 Homebrew is not installed.
# @example
#   shell::brew::reinstall --cask firefox
#
shell::brew::reinstall() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Reinstall formulae or casks"
		shell::logger::usage "shell::brew::reinstall [-n] [-c | --formula] [-f] <name>..."
		shell::logger::item "name" "Installed package name(s)"
		shell::logger::option "-c, --cask" "Reinstall casks"
		shell::logger::option "--formula" "Treat the names as formulae"
		shell::logger::option "-f, --force" "Reinstall even if up to date"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::reinstall --cask firefox"
		return "$RETURN_SUCCESS"
	fi
	local spec="-c|--cask|--cask
|--formula|--formula
-f|--force|--force"
	shell::brew::pkgcmd reinstall 1 -1 pkg "package name" "$spec" "$@"
}

# @description Uninstall formulae or casks (`brew uninstall`).
#   `--zap` also removes the files a cask leaves in your home directory
#   (preferences, caches, support files); it only exists for casks, so it
#   implies `--cask`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -c | --cask Uninstall casks.
# @option --formula Treat the names as formulae.
# @option -f | --force Delete all installed versions, and uninstall even a cask whose files are gone.
# @option -z | --zap Also delete the cask's data and settings (implies --cask).
# @option --ignore-dependencies Uninstall even if other formulae need it. This can break them.
# @arg $@ string One or more installed package names.
# @exitcode 0 Success.
# @exitcode 2 No name, or an invalid one.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::uninstall::fzf
# @example
#   shell::brew::uninstall wget
#   shell::brew::uninstall --zap firefox
#
shell::brew::uninstall() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Uninstall formulae or casks"
		shell::logger::usage "shell::brew::uninstall [-n] [-c | --formula] [-f] [-z] [--ignore-dependencies] <name>..."
		shell::logger::item "name" "Installed package name(s)"
		shell::logger::option "-c, --cask" "Uninstall casks"
		shell::logger::option "--formula" "Treat the names as formulae"
		shell::logger::option "-f, --force" "Delete all installed versions"
		shell::logger::option "-z, --zap" "Also delete the cask's data and settings (implies --cask)"
		shell::logger::option "--ignore-dependencies" "Uninstall even if other formulae need it"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::uninstall --zap firefox"
		return "$RETURN_SUCCESS"
	fi
	local spec="-c|--cask|--cask
|--formula|--formula
-f|--force|--force
-z|--zap|--zap
|--ignore-dependencies|--ignore-dependencies"
	local arg has_cask="false" has_zap="false"
	for arg in "$@"; do
		case "$arg" in
		-c | --cask) has_cask="true" ;;
		-z | --zap) has_zap="true" ;;
		esac
	done
	if [ "$has_zap" = "true" ] && [ "$has_cask" = "false" ]; then
		shell::brew::pkgcmd uninstall 1 -1 pkg "package name" "$spec" --cask "$@"
		return $?
	fi
	shell::brew::pkgcmd uninstall 1 -1 pkg "package name" "$spec" "$@"
}

# --------------------------------------------------------------------------
# Link, unlink, switch
# --------------------------------------------------------------------------

# @description Symlink an installed formula into the Homebrew prefix (`brew link`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -f | --force Allow keg-only formulae to be linked.
# @option -o | --overwrite Delete files that already exist in the prefix.
# @option -p | --preview Ask brew to show what it would do, without doing it.
# @arg $@ string One or more installed formula names.
# @exitcode 0 Success.
# @exitcode 2 No name, or an invalid one.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::unlink
# @see shell::brew::switch
# @example
#   shell::brew::link git
#   shell::brew::link --overwrite --force node@20
#
shell::brew::link() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Symlink installed formulae into the Homebrew prefix"
		shell::logger::usage "shell::brew::link [-n] [-f] [-o] [-p] <name>..."
		shell::logger::item "name" "Installed formula name(s)"
		shell::logger::option "-f, --force" "Allow keg-only formulae"
		shell::logger::option "-o, --overwrite" "Delete files that already exist"
		shell::logger::option "-p, --preview" "Let brew show what it would do"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::link --overwrite --force node@20"
		return "$RETURN_SUCCESS"
	fi
	local spec="-f|--force|--force
-o|--overwrite|--overwrite
-p|--preview|--dry-run"
	shell::brew::pkgcmd link 1 -1 pkg "formula name" "$spec" "$@"
}

# @description Remove the symlinks of installed formulae from the prefix (`brew unlink`).
#   The formula stays installed; it is just no longer on your PATH.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -p | --preview Ask brew to show what it would do, without doing it.
# @arg $@ string One or more installed formula names.
# @exitcode 0 Success.
# @exitcode 2 No name, or an invalid one.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::link
# @example
#   shell::brew::unlink git
#
shell::brew::unlink() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Remove the symlinks of installed formulae (they stay installed)"
		shell::logger::usage "shell::brew::unlink [-n] [-p] <name>..."
		shell::logger::item "name" "Installed formula name(s)"
		shell::logger::option "-p, --preview" "Let brew show what it would do"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::unlink git"
		return "$RETURN_SUCCESS"
	fi
	local spec="-p|--preview|--dry-run"
	shell::brew::pkgcmd unlink 1 -1 pkg "formula name" "$spec" "$@"
}

# @description Make another installed version of a formula the active one.
#   Replaces `brew switch`, which Homebrew removed. Versions of a formula are
#   separate formulae (`node@20`, `python@3.12`), so this unlinks `<formula>`
#   and links `<formula>@<version>` with `--overwrite --force`. The target must
#   already be installed (shell::brew::install node@20).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the commands instead of running them.
# @arg $1 string Formula, e.g. `node`.
# @arg $2 string Version, e.g. `20`.
# @exitcode 0 The version is now linked.
# @exitcode 2 Missing or invalid formula / version.
# @exitcode 3 Homebrew is not installed, or `<formula>@<version>` is not installed.
# @exitcode N Exit status of the failing brew step.
# @see shell::brew::link
# @example
#   shell::brew::switch node 20
#   shell::brew::switch -n python 3.12
#
shell::brew::switch() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Switch the active version of a formula (replacement for 'brew switch')"
		shell::logger::usage "shell::brew::switch [-n] <formula> <version>"
		shell::logger::item "formula" "Formula name, e.g. node"
		shell::logger::item "version" "Installed version, e.g. 20 (links node@20)"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::switch node 20"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi
	if [ "$#" -ne 2 ]; then
		shell::logger::error "Usage: shell::brew::switch [-n] <formula> <version>"
		return "$RETURN_INVALID"
	fi

	local formula="$1" version="$2" target
	if ! shell::brew::name::valid "$formula" || [ "${formula#*@}" != "$formula" ]; then
		shell::logger::error "Invalid formula name: '$formula' (give the plain name, e.g. node)"
		return "$RETURN_INVALID"
	fi
	case "$version" in
	'' | [!0-9]* | *[!A-Za-z0-9._-]*)
		shell::logger::error "Invalid version: '$version' (e.g. 20 or 3.12)"
		return "$RETURN_INVALID"
		;;
	esac
	target="${formula}@${version}"

	local -a run_opts=()
	if [ "$dry_run" = "true" ]; then
		run_opts=(-n)
	elif ! shell::homebrew::path >/dev/null 2>&1; then
		shell::logger::error "Homebrew is not installed (install it with: shell::homebrew::install)"
		return "$RETURN_NOT_FOUND"
	elif ! shell::brew::query list --versions "$target" | grep -q .; then
		shell::logger::error "$target is not installed (install it with: shell::brew::install $target)"
		return "$RETURN_NOT_FOUND"
	fi

	shell::brew::run ${run_opts[@]+"${run_opts[@]}"} unlink "$formula" || return $?
	shell::brew::run ${run_opts[@]+"${run_opts[@]}"} link --overwrite --force "$target"
}

# --------------------------------------------------------------------------
# Cleanup and autoremove
# --------------------------------------------------------------------------

# @description Remove old versions and stale downloads (`brew cleanup`).
#   Use `--preview` first: it lists what would be removed and removes nothing
#   (this is `brew cleanup -n`; our own `-n` prints the command).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -p | --preview Ask brew to list what it would remove, without removing it.
# @option -s | --scrub Also remove downloads of the latest versions (empties the cache).
# @option --prune <days> Remove cache files older than this many days (`all` = everything).
# @arg $@ string Optional package names (default: everything).
# @exitcode 0 Success.
# @exitcode 2 Invalid option, value or name.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::autoremove
# @example
#   shell::brew::cleanup --preview
#   shell::brew::cleanup --prune 30
#
shell::brew::cleanup() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Remove old versions of installed packages and stale downloads"
		shell::logger::usage "shell::brew::cleanup [-n] [-p] [-s] [--prune <days>] [<name>...]"
		shell::logger::item "name" "Optional package name(s)"
		shell::logger::option "-p, --preview" "List what would be removed, remove nothing (brew cleanup -n)"
		shell::logger::option "-s, --scrub" "Also remove downloads of the latest versions"
		shell::logger::option "--prune <days>" "Remove cache files older than <days> (or 'all')"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::cleanup --preview"
		return "$RETURN_SUCCESS"
	fi
	local spec="-p|--preview|--dry-run
-s|--scrub|--scrub
|--prune|--prune="
	# brew accepts a number of days or `all`; anything else would only fail later.
	local arg prev="" days
	for arg in "$@"; do
		days=""
		case "$arg" in
		--prune=*) days="${arg#--prune=}" ;;
		*) [ "$prev" = "--prune" ] && days="$arg" ;;
		esac
		prev="$arg"
		case "$days" in
		'' | all | *[!0-9]*)
			if [ -n "$days" ] && [ "$days" != "all" ]; then
				shell::logger::error "--prune needs a number of days or 'all' (got '$days')"
				return "$RETURN_INVALID"
			fi
			;;
		esac
	done
	shell::brew::pkgcmd cleanup 0 -1 pkg "package name" "$spec" "$@"
}

# @description Uninstall formulae that were only installed as a dependency and are
#   no longer needed (`brew autoremove`).
#   Run it with `--preview` first to see the list.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -p | --preview Ask brew to list what it would uninstall, without doing it.
# @exitcode 0 Success.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::unused::fzf
# @example
#   shell::brew::autoremove --preview
#   shell::brew::autoremove
#
shell::brew::autoremove() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Uninstall dependencies that nothing needs any more"
		shell::logger::usage "shell::brew::autoremove [-n] [-p]"
		shell::logger::option "-p, --preview" "List what would be uninstalled, do nothing"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::autoremove --preview"
		return "$RETURN_SUCCESS"
	fi
	local spec="-p|--preview|--dry-run"
	shell::brew::pkgcmd autoremove 0 0 pkg "argument" "$spec" "$@"
}

# --------------------------------------------------------------------------
# Services
# --------------------------------------------------------------------------

# @description Manage background services of installed formulae (`brew services`).
#   Actions: `list`, `info`, `run` (this session only), `start` (and at login),
#   `stop`, `restart`, `kill` and `cleanup` (remove unused service files).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -a | --all Apply the action to every service.
# @arg $1 string The action.
# @arg $@ string Service (formula) names, for the actions that need them.
# @exitcode 0 Success.
# @exitcode 2 Unknown action, or a missing / invalid name.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::services::fzf
# @example
#   shell::brew::services list
#   shell::brew::services start postgresql@16
#   shell::brew::services restart --all
#
shell::brew::services() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Manage background services of installed formulae"
		shell::logger::usage "shell::brew::services [-n] [-a] <list|info|run|start|stop|restart|kill|cleanup> [<name>...]"
		shell::logger::item "action" "list, info, run, start, stop, restart, kill or cleanup"
		shell::logger::item "name" "Service (formula) name(s)"
		shell::logger::option "-a, --all" "Apply to every service"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::services start postgresql@16"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" all="false" action="" arg
	local -a names=() run_opts=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-a | --all) all="true" ;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*)
			if [ -z "$action" ]; then
				action="$1"
			else
				names+=("$1")
			fi
			;;
		esac
		shift
	done

	case "$action" in
	list | cleanup)
		if [ "${#names[@]}" -gt 0 ] || [ "$all" = "true" ]; then
			shell::logger::error "'$action' takes no name and no --all"
			return "$RETURN_INVALID"
		fi
		;;
	info | run | start | stop | restart | kill)
		if [ "${#names[@]}" -eq 0 ] && [ "$all" = "false" ]; then
			shell::logger::error "'$action' needs a service name or --all"
			return "$RETURN_INVALID"
		fi
		;;
	'')
		shell::logger::error "An action is required (list, info, run, start, stop, restart, kill, cleanup)"
		return "$RETURN_INVALID"
		;;
	*)
		shell::logger::error "Unknown action: '$action'"
		return "$RETURN_INVALID"
		;;
	esac

	for arg in ${names[@]+"${names[@]}"}; do
		if ! shell::brew::name::valid "$arg"; then
			shell::logger::error "Invalid service name: '$arg'"
			return "$RETURN_INVALID"
		fi
	done

	if [ "$dry_run" = "true" ]; then
		run_opts=(-n)
	fi
	if [ "$all" = "true" ]; then
		shell::brew::run ${run_opts[@]+"${run_opts[@]}"} services "$action" --all
	else
		shell::brew::run ${run_opts[@]+"${run_opts[@]}"} services "$action" ${names[@]+"${names[@]}"}
	fi
}

# --------------------------------------------------------------------------
# Brewfile (bundle): back up and restore everything you installed
# --------------------------------------------------------------------------

# @internal
# @description Shared implementation of the `shell::brew::bundle::*` functions.
# @arg $1 string The bundle sub-command: dump, install or cleanup.
# @arg $@ string Options and an optional file.
# @exitcode 0 Success.
# @exitcode 2 Invalid option or file name.
# @exitcode 3 Homebrew is not installed, or the Brewfile to read does not exist.
# @exitcode N Exit status of brew.
shell::brew::bundle::run() {
	local action="${1-}"
	shift

	local dry_run="false" force="false" describe="false" file=""
	local -a run_opts=() extra=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-f | --force) force="true" ;;
		-d | --describe) describe="true" ;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*)
			if [ -n "$file" ]; then
				shell::logger::error "Only one Brewfile can be given"
				return "$RETURN_INVALID"
			fi
			file="$1"
			;;
		esac
		shift
	done

	if [ "$describe" = "true" ] && [ "$action" != "dump" ]; then
		shell::logger::error "--describe only applies to dump"
		return "$RETURN_INVALID"
	fi
	if [ "$force" = "true" ] && [ "$action" = "install" ]; then
		shell::logger::error "--force does not apply to install"
		return "$RETURN_INVALID"
	fi

	if [ -n "$file" ]; then
		case "$file" in
		-* | *[[:space:]]*)
			shell::logger::error "Invalid Brewfile path: '$file'"
			return "$RETURN_INVALID"
			;;
		esac
		if [ "$action" != "dump" ] && [ "$dry_run" = "false" ] && [ ! -f "$file" ]; then
			shell::logger::error "Brewfile not found: $file"
			return "$RETURN_NOT_FOUND"
		fi
		extra+=("--file=$file")
	fi
	if [ "$force" = "true" ]; then
		extra+=(--force)
	fi
	if [ "$describe" = "true" ]; then
		extra+=(--describe)
	fi

	if [ "$dry_run" = "true" ]; then
		run_opts=(-n)
	fi
	shell::brew::run ${run_opts[@]+"${run_opts[@]}"} bundle "$action" ${extra[@]+"${extra[@]}"}
}

# @description Write every installed tap, formula, cask (and more) to a Brewfile
#   (`brew bundle dump`). Keep the file in your dotfiles to rebuild a machine.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -f | --force Overwrite an existing Brewfile.
# @option -d | --describe Add a comment with each package's description.
# @arg $1 string Optional path of the Brewfile (default: `./Brewfile`).
# @exitcode 0 Success.
# @exitcode 2 Invalid option or path.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::bundle::install
# @example
#   shell::brew::bundle::dump --force --describe ~/dotfiles/Brewfile
#
shell::brew::bundle::dump() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Write everything installed to a Brewfile"
		shell::logger::usage "shell::brew::bundle::dump [-n] [-f] [-d] [<file>]"
		shell::logger::item "file" "Brewfile path (default ./Brewfile)"
		shell::logger::option "-f, --force" "Overwrite an existing Brewfile"
		shell::logger::option "-d, --describe" "Add each package's description as a comment"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::bundle::dump --force ~/dotfiles/Brewfile"
		return "$RETURN_SUCCESS"
	fi
	shell::brew::bundle::run dump "$@"
}

# @description Install everything listed in a Brewfile (`brew bundle install`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string Optional path of the Brewfile (default: `./Brewfile`).
# @exitcode 0 Success.
# @exitcode 2 Invalid option or path.
# @exitcode 3 Homebrew is not installed, or the Brewfile does not exist.
# @see shell::brew::bundle::dump
# @example
#   shell::brew::bundle::install ~/dotfiles/Brewfile
#
shell::brew::bundle::install() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Install everything listed in a Brewfile"
		shell::logger::usage "shell::brew::bundle::install [-n] [<file>]"
		shell::logger::item "file" "Brewfile path (default ./Brewfile)"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::bundle::install ~/dotfiles/Brewfile"
		return "$RETURN_SUCCESS"
	fi
	shell::brew::bundle::run install "$@"
}

# @description Find, or remove, what is installed but not listed in a Brewfile
#   (`brew bundle cleanup`). Without `--force` brew only lists what it would
#   remove; with it, it uninstalls.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -f | --force Really uninstall what is not in the Brewfile.
# @arg $1 string Optional path of the Brewfile (default: `./Brewfile`).
# @exitcode 0 Success.
# @exitcode 2 Invalid option or path.
# @exitcode 3 Homebrew is not installed, or the Brewfile does not exist.
# @see shell::brew::bundle::dump
# @example
#   shell::brew::bundle::cleanup ~/dotfiles/Brewfile
#   shell::brew::bundle::cleanup --force ~/dotfiles/Brewfile
#
shell::brew::bundle::cleanup() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List (or with --force, uninstall) what is not in a Brewfile"
		shell::logger::usage "shell::brew::bundle::cleanup [-n] [-f] [<file>]"
		shell::logger::item "file" "Brewfile path (default ./Brewfile)"
		shell::logger::option "-f, --force" "Really uninstall (default: only list)"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::bundle::cleanup ~/dotfiles/Brewfile"
		return "$RETURN_SUCCESS"
	fi
	shell::brew::bundle::run cleanup "$@"
}
