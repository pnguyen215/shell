#!/usr/bin/env bash
# @file lang/nvm.sh
# @brief nvm (Node Version Manager) commands: install, use, exec, alias, .nvmrc, auto-switch ...
# @description
#   One documented function per `nvm` command, so everything in the nvm cheat
#   sheets is a `shell::nvm::*` call with the same flags, a `-n | --dry-run`
#   switch and argument validation. The interactive (fzf) layer, and the tools
#   that find Node versions you no longer use, are in lang/nvm_fzf.sh.
#
#   Installing nvm itself is `shell::dependency::nvm::install`
#   (src/dependency/nvm.sh); `shell::nvm::install` is `nvm install <version>`.
#
#   Things worth knowing:
#
#   * nvm is a shell function, so these functions call it in the **current**
#     shell: `shell::nvm::use 20` changes the Node of the terminal you typed it
#     in, which is the whole point. For the same reason `use`, `deactivate`,
#     `unload` and `autouse` must not be run inside `$( ... )` or a pipeline.
#   * `-n | --dry-run` prints the `nvm` command (and copies it to the clipboard)
#     instead of running it. It never needs nvm to be installed. Put it (and
#     every other option) before the version.
#   * nvm's own flags keep their names (`--lts`, `--lts=<name>`, `--silent`,
#     `--no-colors`, `--reinstall-packages-from=<version>` ...).
#   * A version is anything nvm understands: `20`, `v20.11.1`, `node`, `stable`,
#     `lts/*`, `lts/iron`, `system`, `default` or an alias of yours. It is
#     checked before nvm sees it: it cannot start with `-` and cannot contain
#     spaces, quotes, `$`, `;` or `..`, so it can never be mistaken for an option.
#   * The exit status is nvm's own (for instance 3 for "version not found").
#
#   Not wrapped: `nvm root` and `nvm proxy` of the first cheat sheet belong to
#   nvm-windows; nvm for macOS / Linux has neither. Where nvm keeps its files is
#   `NVM_DIR`; a download proxy is the usual `HTTPS_PROXY` / `npm config set proxy`.

# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

# @internal
# @description Tell whether a string is a version nvm can be asked about.
#   Accepts `20`, `v20.11.1`, `node`, `lts/*`, `lts/iron`, `my-alias`. Rejects an
#   empty string, a leading `-` or `.`, a `..`, and every character outside
#   `A-Z a-z 0-9 . _ / * + -`.
# @arg $1 string The candidate.
# @exitcode 0 It is safe.
# @exitcode 1 It is not.
# @example
#   shell::nvm::version::valid "lts/*" && echo ok
#
shell::nvm::version::valid() {
	case "${1-}" in
	'' | [!A-Za-z0-9]* | *..* | *[!A-Za-z0-9._/*+-]*) return 1 ;;
	esac
	return 0
}

# @internal
# @description Tell whether a string is a valid alias name (or alias pattern).
# @arg $1 string The candidate.
# @exitcode 0 It is `A-Z a-z 0-9 . _ / -`, starts with a letter or digit, and has no `..`.
# @exitcode 1 It is not.
# @example
#   shell::nvm::alias::valid "work" && echo ok
#
shell::nvm::alias::valid() {
	case "${1-}" in
	'' | [!A-Za-z0-9]* | *..* | *[!A-Za-z0-9._/-]*) return 1 ;;
	esac
	return 0
}

# @internal
# @description Run `nvm <args>` in the current shell and echo the command first.
#   The single place that starts nvm for every user-visible command. nvm is loaded
#   on demand. With `-n` it only prints `nvm <args>`; in that case nvm need not be
#   installed.
# @option -n | --dry-run Print the command instead of running it.
# @arg $@ string The nvm sub-command and its arguments.
# @exitcode 0 nvm succeeded (or the dry-run printed).
# @exitcode 2 No sub-command was given.
# @exitcode 3 nvm is not installed.
# @exitcode N Exit status of nvm.
# @example
#   shell::nvm::invoke use 20
#
shell::nvm::invoke() {
	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if [ "$#" -eq 0 ]; then
		shell::logger::error "An nvm sub-command is required"
		return "$RETURN_INVALID"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "nvm $*"
		return "$RETURN_SUCCESS"
	fi

	shell::dependency::nvm::load || {
		shell::logger::error "nvm is not installed (install it with: shell::dependency::nvm::install)"
		return "$RETURN_NOT_FOUND"
	}
	shell::exec::command nvm "$@"
}

# @internal
# @description Run a read-only `nvm` query quietly and print its output.
#   Nothing is echoed and stderr is discarded. Used by the interactive layer to
#   gather data; it is safe in `$( ... )` because it changes nothing.
# @arg $@ string Arguments for nvm.
# @stdout What nvm printed.
# @exitcode 0 nvm succeeded.
# @exitcode 3 nvm is not installed.
# @exitcode N Exit status of nvm.
# @example
#   shell::nvm::query ls --no-colors --no-alias
#
shell::nvm::query() {
	shell::dependency::nvm::load >/dev/null 2>&1 || return "$RETURN_NOT_FOUND"
	nvm "$@" 2>/dev/null
}

# @internal
# @description The engine behind the commands: parse flags, validate the arguments,
#   then run `nvm <verb> [flags] [arguments]`.
#
#   `spec` lists the flags the caller accepts, one per line, as
#   `short|long|nvm-flag`. A nvm-flag ending in `=` takes a required value
#   (`--alias=` accepts `--alias work` and `--alias=work`); one ending in `?`
#   takes an optional value written inline (`--lts` or `--lts=iron`).
#   `-n` and `--dry-run` are always accepted.
#
#   `mode` decides what the arguments are: `ver` (versions), `alias` (an alias
#   name, then a version), `text`, `colors` (five colour letters), `none`, or
#   `rest` (a version, then a command or arguments passed on **verbatim**; with
#   `--lts` there is no version and everything is verbatim).
# @arg $1 string The nvm verb (`install`, `ls`, `--version` ...).
# @arg $2 integer Minimum number of arguments (for `rest`: counted with the version).
# @arg $3 integer Maximum number of arguments (-1 = no limit).
# @arg $4 string Mode: ver | alias | text | colors | none | rest.
# @arg $5 string What an argument is called in messages.
# @arg $6 string The flag spec (multi-line).
# @arg $@ string The caller's own arguments.
# @exitcode 0 nvm succeeded (or the dry-run printed).
# @exitcode 2 Unknown flag, a missing value, a wrong number of arguments or an unsafe argument.
# @exitcode 3 nvm is not installed.
# @exitcode N Exit status of nvm.
# @example
#   shell::nvm::cmd use 0 1 ver version "--silent|--silent|--silent" "$@"
#
shell::nvm::cmd() {
	local verb="${1-}" min="${2-0}" max="${3--1}" mode="${4-ver}" what="${5-version}" spec="${6-}"
	shift 6

	local dry_run="false" matched consume value s l f count index_name arg lts_seen="false"
	local -a flags=() names=() run_opts=()

	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
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
					'' | [!A-Za-z0-9*]* | *[!A-Za-z0-9._/*+-]*)
						shell::logger::error "Invalid value for $l: '$value'"
						return "$RETURN_INVALID"
						;;
					esac
					matched="${f}${value}"
					break
					;;
				*\?)
					if [ "$1" = "$l" ]; then
						matched="${f%\?}"
						break
					fi
					case "$1" in
					"$l"=*)
						value="${1#*=}"
						case "$value" in
						'' | [!A-Za-z0-9*]* | *[!A-Za-z0-9._*+-]*)
							shell::logger::error "Invalid value for $l: '$value'"
							return "$RETURN_INVALID"
							;;
						esac
						matched="${f%\?}=${value}"
						break
						;;
					esac
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
			case "$matched" in
			--lts | --lts=*) lts_seen="true" ;;
			esac
			flags+=("$matched")
			shift "$consume"
			;;
		*)
			names+=("$1")
			shift
			if [ "$mode" = "rest" ]; then
				# What follows the version belongs to the command being run.
				while [ "$#" -gt 0 ]; do
					names+=("$1")
					shift
				done
			fi
			;;
		esac
	done

	if [ "$mode" = "rest" ] && [ "$lts_seen" = "true" ]; then
		min=$((min - 1))
	fi
	count="${#names[@]}"
	if [ "$count" -lt "$min" ]; then
		shell::logger::error "A $what is required"
		return "$RETURN_INVALID"
	fi
	if [ "$mode" != "rest" ] && [ "$max" -ge 0 ] && [ "$count" -gt "$max" ]; then
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
		ver)
			if ! shell::nvm::version::valid "$arg"; then
				shell::logger::error "Invalid $what: '$arg'"
				return "$RETURN_INVALID"
			fi
			;;
		alias)
			if [ "$index_name" -eq 1 ]; then
				if ! shell::nvm::alias::valid "$arg"; then
					shell::logger::error "Invalid alias name: '$arg'"
					return "$RETURN_INVALID"
				fi
			elif ! shell::nvm::version::valid "$arg"; then
				shell::logger::error "Invalid version: '$arg'"
				return "$RETURN_INVALID"
			fi
			;;
		text)
			if [ -z "$arg" ]; then
				shell::logger::error "The $what cannot be empty"
				return "$RETURN_INVALID"
			fi
			;;
		colors)
			case "$arg" in
			[rgbcmykeRGBCMYKEW][rgbcmykeRGBCMYKEW][rgbcmykeRGBCMYKEW][rgbcmykeRGBCMYKEW][rgbcmykeRGBCMYKEW]) ;;
			*)
				shell::logger::error "Invalid colors '$arg': give five letters from r g b c m y k e (W and upper case = bold), e.g. cgYmW"
				return "$RETURN_INVALID"
				;;
			esac
			;;
		rest)
			if [ "$index_name" -eq 1 ] && [ "$lts_seen" = "false" ] && ! shell::nvm::version::valid "$arg"; then
				shell::logger::error "Invalid version: '$arg'"
				return "$RETURN_INVALID"
			fi
			;;
		esac
	done

	if [ "$dry_run" = "true" ]; then
		run_opts=(-n)
	fi
	shell::nvm::invoke ${run_opts[@]+"${run_opts[@]}"} "$verb" ${flags[@]+"${flags[@]}"} ${names[@]+"${names[@]}"}
}

# @internal
# @description Succeed when the arguments name a version or `--lts`; used by the
#   commands that cannot work without one.
# @arg $@ string The caller's arguments.
# @exitcode 0 A version or `--lts` is among them.
# @exitcode 1 Neither is.
# @example
#   shell::nvm::has_target "$@" || return 2
#
shell::nvm::has_target() {
	local arg
	for arg in "$@"; do
		case "$arg" in
		-n | --dry-run) ;;
		--lts | --lts=*) return 0 ;;
		-*) ;;
		*) return 0 ;;
		esac
	done
	return 1
}

# --------------------------------------------------------------------------
# Help, version, current state
# --------------------------------------------------------------------------

# @description Print the installed nvm version (`nvm --version`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @stdout The version, e.g. `0.40.8`.
# @exitcode 0 Success.
# @exitcode 3 nvm is not installed.
# @example
#   shell::nvm::version
#
shell::nvm::version() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Print the installed nvm version (nvm --version)"
		shell::logger::usage "shell::nvm::version [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::version"
		return "$RETURN_SUCCESS"
	fi
	shell::nvm::cmd --version 0 0 none "argument" "" "$@"
}

# @description Show nvm's own help (`nvm --help`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @exitcode 0 Success.
# @exitcode 3 nvm is not installed.
# @example
#   shell::nvm::help
#
shell::nvm::help() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show nvm's own help (nvm --help)"
		shell::logger::usage "shell::nvm::help [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::help"
		return "$RETURN_SUCCESS"
	fi
	shell::nvm::cmd --help 0 0 none "argument" "" "$@"
}

# @description Print the Node version this shell uses (`nvm current`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @stdout `v20.11.1`, `system` (the Node outside nvm) or `none`.
# @exitcode 0 Success.
# @exitcode 3 nvm is not installed.
# @example
#   shell::nvm::current
#
shell::nvm::current() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show the Node version this shell uses (nvm current)"
		shell::logger::usage "shell::nvm::current [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::current"
		return "$RETURN_SUCCESS"
	fi
	shell::nvm::cmd current 0 0 none "argument" "" "$@"
}

# @description Print the path of an installed Node (`nvm which`).
#   Without a version, the one `.nvmrc` asks for; `current` is the active one.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --silent Print nothing but the path (no message when a version is omitted).
# @arg $1 string Optional version, or `current`.
# @stdout The absolute path of the `node` binary.
# @exitcode 0 Success.
# @exitcode 2 Invalid option or version.
# @exitcode 3 nvm is not installed, or that version is not installed.
# @example
#   shell::nvm::which 22
#   shell::nvm::which current
#
shell::nvm::which() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Print the path of an installed Node version (nvm which)"
		shell::logger::usage "shell::nvm::which [-n] [--silent] [<version> | current]"
		shell::logger::item "version" "Version or 'current' (default: the one .nvmrc asks for)"
		shell::logger::option "--silent" "Print nothing but the path"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::which 22"
		return "$RETURN_SUCCESS"
	fi
	shell::nvm::cmd which 0 1 ver version "|--silent|--silent" "$@"
}

# @description List the installed Node versions (`nvm ls`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --no-colors Plain text, no colour codes.
# @option --no-alias Do not list the aliases.
# @arg $1 string Optional version to filter by, e.g. `20`.
# @stdout One line per version; `->` marks the one in use.
# @exitcode 0 Success.
# @exitcode 2 Invalid option or version.
# @exitcode 3 nvm is not installed.
# @see shell::nvm::ls::remote
# @example
#   shell::nvm::ls
#   shell::nvm::ls --no-colors --no-alias 20
#
shell::nvm::ls() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List the installed Node versions (nvm ls)"
		shell::logger::usage "shell::nvm::ls [-n] [--no-colors] [--no-alias] [<version>]"
		shell::logger::item "version" "Optional filter, e.g. 20"
		shell::logger::option "--no-colors" "Plain text"
		shell::logger::option "--no-alias" "Do not list the aliases"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::ls --no-colors --no-alias"
		return "$RETURN_SUCCESS"
	fi
	local spec="|--no-colors|--no-colors
|--no-alias|--no-alias"
	shell::nvm::cmd ls 0 1 ver version "$spec" "$@"
}

# @description List the Node versions that can be installed (`nvm ls-remote`).
#   Needs the network. `--lts` keeps the long-term-support versions only.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --lts Only LTS versions.
# @option --lts=<name> Only that LTS line, e.g. `--lts=iron`.
# @option --no-colors Plain text, no colour codes.
# @arg $1 string Optional version to filter by, e.g. `22`.
# @stdout One line per version, oldest first.
# @exitcode 0 Success.
# @exitcode 2 Invalid option or version.
# @exitcode 3 nvm is not installed.
# @see shell::nvm::install::fzf
# @example
#   shell::nvm::ls::remote --lts
#   shell::nvm::ls::remote 22
#
shell::nvm::ls::remote() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List the Node versions available for install (nvm ls-remote)"
		shell::logger::usage "shell::nvm::ls::remote [-n] [--lts[=<name>]] [--no-colors] [<version>]"
		shell::logger::item "version" "Optional filter, e.g. 22"
		shell::logger::option "--lts" "Only LTS versions"
		shell::logger::option "--lts=<name>" "Only that LTS line, e.g. iron"
		shell::logger::option "--no-colors" "Plain text"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::ls::remote --lts"
		return "$RETURN_SUCCESS"
	fi
	local spec="|--lts|--lts?
|--no-colors|--no-colors"
	shell::nvm::cmd ls-remote 0 1 ver version "$spec" "$@"
}

# @description Resolve a description to one installed version (`nvm version`).
#   `20` becomes the newest installed 20.x, e.g. `v20.11.1`; `N/A` when none is installed.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string The version description.
# @stdout The resolved version, or `N/A` (and exit status 3).
# @exitcode 0 Success.
# @exitcode 2 Missing or invalid version.
# @exitcode 3 nvm is not installed, or no installed version matches.
# @example
#   shell::nvm::version::local 20
#
shell::nvm::version::local() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Resolve a description to one INSTALLED version (nvm version)"
		shell::logger::usage "shell::nvm::version::local [-n] <version>"
		shell::logger::item "version" "e.g. 20, node, lts/*"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::version::local 20"
		return "$RETURN_SUCCESS"
	fi
	shell::nvm::cmd version 1 1 ver version "" "$@"
}

# @description Resolve a description to one version that can be installed (`nvm version-remote`).
#   Needs the network. `--lts` resolves against the LTS versions.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --lts Choose among the LTS versions.
# @option --lts=<name> Choose among that LTS line.
# @arg $1 string The version description (not needed with `--lts`).
# @stdout The resolved version.
# @exitcode 0 Success.
# @exitcode 2 Missing or invalid version.
# @exitcode 3 nvm is not installed, or nothing matches.
# @example
#   shell::nvm::version::remote 22
#   shell::nvm::version::remote --lts=iron
#
shell::nvm::version::remote() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Resolve a description to one REMOTE version (nvm version-remote)"
		shell::logger::usage "shell::nvm::version::remote [-n] [--lts[=<name>]] [<version>]"
		shell::logger::item "version" "e.g. 22 (not needed with --lts)"
		shell::logger::option "--lts" "Choose among the LTS versions"
		shell::logger::option "--lts=<name>" "Choose among that LTS line"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::version::remote --lts=iron"
		return "$RETURN_SUCCESS"
	fi
	if ! shell::nvm::has_target "$@"; then
		shell::logger::error "A version or --lts is required"
		return "$RETURN_INVALID"
	fi
	shell::nvm::cmd version-remote 0 1 ver version "|--lts|--lts?" "$@"
}

# --------------------------------------------------------------------------
# Install, uninstall
# --------------------------------------------------------------------------

# @description Download and install a Node version (`nvm install`).
#   Without a version it installs the one `.nvmrc` asks for.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -s Skip the binary download, build from source only.
# @option -b Skip the source download, install from the binary only.
# @option --lts Install the latest LTS version.
# @option --lts=<name> Install the latest of that LTS line, e.g. `--lts=iron`.
# @option --reinstall-packages-from <version> Reinstall the global npm packages of that version.
# @option --skip-default-packages Ignore the `default-packages` file.
# @option --latest-npm After installing, upgrade npm to the latest working version.
# @option --no-progress Hide the download progress bar.
# @option --alias <name> After installing, point that alias at the version.
# @option --default After installing, make it the default version.
# @arg $1 string Optional version, e.g. `22`, `20.11.1`, `node`, `lts/iron`.
# @exitcode 0 Success.
# @exitcode 2 Invalid option or version.
# @exitcode 3 nvm is not installed.
# @exitcode N Exit status of nvm.
# @see shell::nvm::install::fzf
# @see shell::nvm::migrate::fzf
# @example
#   shell::nvm::install --lts
#   shell::nvm::install --reinstall-packages-from=20 --default 22
#   shell::nvm::install -n 20.11.1
#
shell::nvm::install() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Download and install a Node version (nvm install)"
		shell::logger::usage "shell::nvm::install [-n] [options] [<version>]"
		shell::logger::item "version" "e.g. 22, 20.11.1, node, lts/iron (default: .nvmrc)"
		shell::logger::option "-s" "Skip the binary download (source only)"
		shell::logger::option "-b" "Skip the source download (binary only)"
		shell::logger::option "--lts[=<name>]" "Install the latest LTS (of that line)"
		shell::logger::option "--reinstall-packages-from <v>" "Reinstall the global npm packages of <v>"
		shell::logger::option "--skip-default-packages" "Ignore the default-packages file"
		shell::logger::option "--latest-npm" "Upgrade npm afterwards"
		shell::logger::option "--no-progress" "Hide the progress bar"
		shell::logger::option "--alias <name>" "Point an alias at the new version"
		shell::logger::option "--default" "Make it the default version"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::install --lts --default"
		return "$RETURN_SUCCESS"
	fi
	local spec="-s|-s|-s
-b|-b|-b
|--lts|--lts?
|--reinstall-packages-from|--reinstall-packages-from=
|--skip-default-packages|--skip-default-packages
|--latest-npm|--latest-npm
|--no-progress|--no-progress
|--alias|--alias=
|--default|--default"
	shell::nvm::cmd install 0 1 ver version "$spec" "$@"
}

# @description Remove an installed Node version (`nvm uninstall`).
#   nvm refuses to remove the version that is in use: switch first.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --lts Remove the version the `lts/*` alias points to.
# @option --lts=<name> Remove the version of that LTS line.
# @arg $1 string The version (not needed with `--lts`).
# @exitcode 0 Success.
# @exitcode 2 No version, or an invalid one.
# @exitcode 3 nvm is not installed.
# @exitcode N Exit status of nvm (1 for the version in use).
# @see shell::nvm::uninstall::fzf
# @see shell::nvm::unused::fzf
# @example
#   shell::nvm::uninstall 18.19.0
#   shell::nvm::uninstall --lts=hydrogen
#
shell::nvm::uninstall() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Remove an installed Node version (nvm uninstall)"
		shell::logger::usage "shell::nvm::uninstall [-n] [--lts[=<name>]] [<version>]"
		shell::logger::item "version" "Installed version to remove"
		shell::logger::option "--lts[=<name>]" "Remove the version of the LTS alias"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::uninstall 18.19.0"
		return "$RETURN_SUCCESS"
	fi
	if ! shell::nvm::has_target "$@"; then
		shell::logger::error "A version or --lts is required"
		return "$RETURN_INVALID"
	fi
	shell::nvm::cmd uninstall 0 1 ver version "|--lts|--lts?" "$@"
}

# --------------------------------------------------------------------------
# Use, run, exec
# --------------------------------------------------------------------------

# @description Switch THIS shell to a Node version (`nvm use`).
#   Changes `PATH` of the current terminal only. Without a version it uses the
#   one `.nvmrc` asks for. Do not run it inside `$( ... )` or a pipeline: the
#   change would be lost with the subshell.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --silent Print nothing.
# @option --lts Use the version the `lts/*` alias points to.
# @option --lts=<name> Use that LTS line, e.g. `--lts=iron`.
# @arg $1 string Optional version, e.g. `20`, `node`, `lts/iron`, an alias.
# @exitcode 0 Success.
# @exitcode 2 Invalid option or version.
# @exitcode 3 nvm is not installed.
# @exitcode N Exit status of nvm (for instance 3 when the version is not installed).
# @see shell::nvm::use::fzf
# @example
#   shell::nvm::use 20
#   shell::nvm::use --lts
#   shell::nvm::use            # from the .nvmrc of the project
#
shell::nvm::use() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Switch this shell to a Node version (nvm use)"
		shell::logger::usage "shell::nvm::use [-n] [--silent] [--lts[=<name>]] [<version>]"
		shell::logger::item "version" "e.g. 20, node, lts/iron, an alias (default: .nvmrc)"
		shell::logger::option "--silent" "Print nothing"
		shell::logger::option "--lts[=<name>]" "Use the LTS alias"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "Changes PATH of this terminal only; do not run it inside \$( ) or a pipeline."
		shell::logger::example "shell::nvm::use --lts"
		return "$RETURN_SUCCESS"
	fi
	local spec="|--silent|--silent
|--lts|--lts?"
	shell::nvm::cmd use 0 1 ver version "$spec" "$@"
}

# @description Run `node` on a given version with the arguments you pass (`nvm run`).
#   The shell's own version is not changed. Everything after the version is
#   handed to node untouched, so `--version` there is node's, not ours.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --silent Print nothing of nvm's own.
# @option --lts Use the LTS alias; then there is no version, only node's arguments.
# @option --lts=<name> Use that LTS line.
# @arg $1 string The version (not given with `--lts`).
# @arg $@ string Arguments for node, e.g. `app.js`.
# @exitcode 0 Success.
# @exitcode 2 Missing or invalid version.
# @exitcode 3 nvm is not installed.
# @exitcode N Exit status of node.
# @see shell::nvm::exec
# @example
#   shell::nvm::run 20 app.js
#   shell::nvm::run 18 --version
#   shell::nvm::run --lts app.js
#
shell::nvm::run() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Run node on a given version (nvm run)"
		shell::logger::usage "shell::nvm::run [-n] [--silent] [--lts[=<name>]] <version> [<node arguments>...]"
		shell::logger::item "version" "e.g. 20, node, lts/iron"
		shell::logger::item "node arguments" "Passed to node untouched, e.g. app.js"
		shell::logger::option "--silent" "Print nothing of nvm's own"
		shell::logger::option "--lts[=<name>]" "Use the LTS alias (then no version is given)"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::run 20 app.js"
		return "$RETURN_SUCCESS"
	fi
	local spec="|--silent|--silent
|--lts|--lts?"
	shell::nvm::cmd run 1 -1 rest version "$spec" "$@"
}

# @description Run any command with a given Node on the PATH (`nvm exec`).
#   The shell's own version is not changed. Everything after the version is the
#   command, passed untouched.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --silent Print nothing of nvm's own.
# @option --lts Use the LTS alias; then there is no version, only the command.
# @option --lts=<name> Use that LTS line.
# @arg $1 string The version, or `current` (not given with `--lts`).
# @arg $@ string The command and its arguments, e.g. `npm test`.
# @exitcode 0 Success.
# @exitcode 2 Missing version or command, or an invalid version.
# @exitcode 3 nvm is not installed.
# @exitcode N Exit status of the command.
# @see shell::nvm::run
# @see shell::nvm::exec::fzf
# @example
#   shell::nvm::exec 20 npm test
#   shell::nvm::exec current node -p process.version
#   shell::nvm::exec --lts npm ci
#
shell::nvm::exec() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Run a command with a given Node on the PATH (nvm exec)"
		shell::logger::usage "shell::nvm::exec [-n] [--silent] [--lts[=<name>]] <version> <command> [<arguments>...]"
		shell::logger::item "version" "e.g. 20, current, lts/iron"
		shell::logger::item "command" "The command to run, passed untouched"
		shell::logger::option "--silent" "Print nothing of nvm's own"
		shell::logger::option "--lts[=<name>]" "Use the LTS alias (then no version is given)"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::exec 20 npm test"
		return "$RETURN_SUCCESS"
	fi
	local spec="|--silent|--silent
|--lts|--lts?"
	shell::nvm::cmd exec 2 -1 rest "version and a command" "$spec" "$@"
}

# @description Undo nvm's effect on this shell (`nvm deactivate`): the system Node is back.
#   Run it in the current shell, not in `$( ... )`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --silent Print nothing.
# @exitcode 0 Success.
# @exitcode 3 nvm is not installed.
# @example
#   shell::nvm::deactivate
#
shell::nvm::deactivate() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Undo nvm's effect on this shell (nvm deactivate)"
		shell::logger::usage "shell::nvm::deactivate [-n] [--silent]"
		shell::logger::option "--silent" "Print nothing"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::deactivate"
		return "$RETURN_SUCCESS"
	fi
	shell::nvm::cmd deactivate 0 0 none "argument" "|--silent|--silent" "$@"
}

# @description Remove nvm from this shell session (`nvm unload`): the `nvm` function is gone.
#   Nothing on disk changes; the next `shell::nvm::*` call loads nvm again.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @exitcode 0 Success.
# @exitcode 3 nvm is not installed.
# @example
#   shell::nvm::unload
#
shell::nvm::unload() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Remove nvm from this shell session (nvm unload)"
		shell::logger::usage "shell::nvm::unload [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::unload"
		return "$RETURN_SUCCESS"
	fi
	shell::nvm::cmd unload 0 0 none "argument" "" "$@"
}

# --------------------------------------------------------------------------
# Aliases
# --------------------------------------------------------------------------

# @description List aliases, or point an alias at a version (`nvm alias`).
#   With no argument: every alias. With one: the aliases that start with it.
#   With two: `alias <name> <version>` creates or changes an alias.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --no-colors Plain text, no colour codes.
# @arg $1 string Optional alias name, or a prefix to list.
# @arg $2 string Optional version to point the alias at.
# @exitcode 0 Success.
# @exitcode 2 Invalid option, name or version.
# @exitcode 3 nvm is not installed.
# @see shell::nvm::default
# @see shell::nvm::unalias
# @example
#   shell::nvm::alias
#   shell::nvm::alias work 20.11.1
#
shell::nvm::alias() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List aliases, or point an alias at a version (nvm alias)"
		shell::logger::usage "shell::nvm::alias [-n] [--no-colors] [<name-or-prefix> [<version>]]"
		shell::logger::item "name" "Alias name (or a prefix, to list)"
		shell::logger::item "version" "Version to point the alias at"
		shell::logger::option "--no-colors" "Plain text"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::alias work 20.11.1"
		return "$RETURN_SUCCESS"
	fi
	shell::nvm::cmd alias 0 2 alias "alias argument" "|--no-colors|--no-colors" "$@"
}

# @description Show, or set, the default version new shells start with (`nvm alias default`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string Optional version: `22`, `lts/*`, `node` ...; without it the current default is shown.
# @exitcode 0 Success.
# @exitcode 2 Invalid option or version.
# @exitcode 3 nvm is not installed.
# @see shell::nvm::default::fzf
# @example
#   shell::nvm::default
#   shell::nvm::default 22
#   shell::nvm::default 'lts/*'
#
shell::nvm::default() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show, or set, the default Node version (nvm alias default)"
		shell::logger::usage "shell::nvm::default [-n] [<version>]"
		shell::logger::item "version" "e.g. 22, lts/*, node (omit to show the default)"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::default 22"
		return "$RETURN_SUCCESS"
	fi
	shell::nvm::cmd alias 0 2 alias "version" "" default "$@"
}

# @description Delete an alias (`nvm unalias`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string The alias name.
# @exitcode 0 Success.
# @exitcode 2 Missing or invalid name.
# @exitcode 3 nvm is not installed.
# @see shell::nvm::unalias::fzf
# @example
#   shell::nvm::unalias work
#
shell::nvm::unalias() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Delete an alias (nvm unalias)"
		shell::logger::usage "shell::nvm::unalias [-n] <name>"
		shell::logger::item "name" "Alias to delete"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::unalias work"
		return "$RETURN_SUCCESS"
	fi
	shell::nvm::cmd unalias 1 1 alias "alias name" "" "$@"
}

# --------------------------------------------------------------------------
# npm, colours, cache
# --------------------------------------------------------------------------

# @description Upgrade npm to the latest version that works with the current Node
#   (`nvm install-latest-npm`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @exitcode 0 Success.
# @exitcode 3 nvm is not installed.
# @example
#   shell::nvm::install::latest_npm
#
shell::nvm::install::latest_npm() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Upgrade npm to the latest version that works with this Node"
		shell::logger::usage "shell::nvm::install::latest_npm [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::install::latest_npm"
		return "$RETURN_SUCCESS"
	fi
	shell::nvm::cmd install-latest-npm 0 0 none "argument" "" "$@"
}

# @description Copy the global npm packages of another version into the current one
#   (`nvm reinstall-packages`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string The version to copy the packages from.
# @exitcode 0 Success.
# @exitcode 2 Missing or invalid version.
# @exitcode 3 nvm is not installed.
# @see shell::nvm::migrate::fzf
# @example
#   shell::nvm::use 22 && shell::nvm::reinstall_packages 20
#
shell::nvm::reinstall_packages() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Reinstall the global npm packages of another version here"
		shell::logger::usage "shell::nvm::reinstall_packages [-n] <version>"
		shell::logger::item "version" "Version to copy the packages from"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::reinstall_packages 20"
		return "$RETURN_SUCCESS"
	fi
	shell::nvm::cmd reinstall-packages 1 1 ver version "" "$@"
}

# @description Show or empty nvm's download cache (`nvm cache dir` / `nvm cache clear`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string `dir` (default) prints the path; `clear` empties the cache.
# @stdout With `dir`, the cache directory.
# @exitcode 0 Success.
# @exitcode 2 Unknown action.
# @exitcode 3 nvm is not installed.
# @example
#   shell::nvm::cache
#   shell::nvm::cache clear
#
shell::nvm::cache() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show or empty nvm's download cache"
		shell::logger::usage "shell::nvm::cache [-n] [dir | clear]"
		shell::logger::item "dir" "Print the cache directory (default)"
		shell::logger::item "clear" "Empty the cache"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::cache clear"
		return "$RETURN_SUCCESS"
	fi
	local arg action="" dry_run="false"
	for arg in "$@"; do
		case "$arg" in
		-n | --dry-run) dry_run="true" ;;
		dir | clear)
			if [ -n "$action" ]; then
				shell::logger::error "Only one action can be given (dir or clear)"
				return "$RETURN_INVALID"
			fi
			action="$arg"
			;;
		-*)
			shell::logger::error "Unknown option: $arg"
			return "$RETURN_INVALID"
			;;
		*)
			shell::logger::error "Unknown action: '$arg' (use dir or clear)"
			return "$RETURN_INVALID"
			;;
		esac
	done
	if [ "$dry_run" = "true" ]; then
		shell::nvm::cmd cache 1 1 text "action" "" -n "${action:-dir}"
	else
		shell::nvm::cmd cache 1 1 text "action" "" "${action:-dir}"
	fi
}

# @description Set the five colours nvm prints with (`nvm set-colors`).
#   Give five letters: installed, system, current, not installed, default.
#   `r g b c m y k e` are the colours, upper case is bold, `W` is white.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string Five colour letters, e.g. `cgYmW`; omit to see the current ones.
# @exitcode 0 Success.
# @exitcode 2 Not five valid colour letters.
# @exitcode 3 nvm is not installed.
# @example
#   shell::nvm::set_colors cgYmW
#
shell::nvm::set_colors() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Set the five colours nvm prints with (nvm set-colors)"
		shell::logger::usage "shell::nvm::set_colors [-n] [<five letters>]"
		shell::logger::item "letters" "e.g. cgYmW: r g b c m y k e, upper case = bold, W = white"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::set_colors cgYmW"
		return "$RETURN_SUCCESS"
	fi
	shell::nvm::cmd set-colors 0 1 colors "colour letters" "" "$@"
}

# --------------------------------------------------------------------------
# .nvmrc: one Node version per project
# --------------------------------------------------------------------------

# @description Print the path of the nearest `.nvmrc`, looking in a directory and its parents.
# @option -h | --help Show help and return.
# @arg $1 string Directory to start from (default: the current one).
# @stdout The path of the `.nvmrc`.
# @exitcode 0 One was found.
# @exitcode 3 There is none.
# @example
#   rc="$(shell::nvm::nvmrc::find)" && echo "pinned by $rc"
#
shell::nvm::nvmrc::find() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Print the path of the nearest .nvmrc"
		shell::logger::usage "shell::nvm::nvmrc::find [<dir>]"
		shell::logger::item "dir" "Directory to start from (default: current)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::nvmrc::find"
		return "$RETURN_SUCCESS"
	fi
	local dir="${1:-$PWD}" parent
	while true; do
		if [ -f "$dir/.nvmrc" ]; then
			printf '%s\n' "$dir/.nvmrc"
			return "$RETURN_SUCCESS"
		fi
		parent="$(dirname "$dir")"
		if [ "$parent" = "$dir" ]; then
			break
		fi
		dir="$parent"
	done
	return "$RETURN_NOT_FOUND"
}

# @description Print the version the nearest `.nvmrc` asks for.
# @option -h | --help Show help and return.
# @arg $1 string Directory to start from (default: the current one).
# @stdout The first line of the `.nvmrc`, trimmed (e.g. `20.11.1` or `lts/iron`).
# @exitcode 0 Success.
# @exitcode 3 There is no `.nvmrc`.
# @exitcode 8 The `.nvmrc` is empty.
# @example
#   shell::nvm::install "$(shell::nvm::nvmrc::read)"
#
shell::nvm::nvmrc::read() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Print the version the nearest .nvmrc asks for"
		shell::logger::usage "shell::nvm::nvmrc::read [<dir>]"
		shell::logger::item "dir" "Directory to start from (default: current)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::nvmrc::read"
		return "$RETURN_SUCCESS"
	fi
	local rc_file value
	rc_file="$(shell::nvm::nvmrc::find "$@")" || return "$RETURN_NOT_FOUND"
	value="$(head -n 1 "$rc_file" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
	if [ -z "$value" ]; then
		shell::logger::warn "$rc_file is empty"
		return "$RETURN_EMPTY"
	fi
	printf '%s\n' "$value"
}

# @description Pin a Node version for a project by writing its `.nvmrc`.
#   Without a version it pins the one this shell uses now. An existing `.nvmrc`
#   is kept unless `--force` is given.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print what would be written instead of writing it.
# @option -f | --force Overwrite an existing `.nvmrc`.
# @option -d | --dir Directory to write into (default: the current one).
# @arg $1 string Optional version: `22`, `20.11.1`, `lts/iron`, `node` ...
# @exitcode 0 Written.
# @exitcode 2 Invalid option, directory or version, or no Node is active to pin.
# @exitcode 7 A `.nvmrc` exists and `--force` was not given.
# @see shell::nvm::use
# @example
#   shell::nvm::nvmrc::write 22
#   shell::nvm::nvmrc::write --force lts/iron
#   shell::nvm::nvmrc::write             # pins the active version
#
shell::nvm::nvmrc::write() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pin a Node version for a project (write .nvmrc)"
		shell::logger::usage "shell::nvm::nvmrc::write [-n] [-f] [-d <dir>] [<version>]"
		shell::logger::item "version" "e.g. 22, 20.11.1, lts/iron (default: the active version)"
		shell::logger::option "-f, --force" "Overwrite an existing .nvmrc"
		shell::logger::option "-d, --dir <dir>" "Directory to write into (default: current)"
		shell::logger::option "-n, --dry-run" "Print what would be written instead of writing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::nvmrc::write 22"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" force="false" dir="$PWD" version=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-f | --force) force="true" ;;
		-d | --dir)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			dir="$2"
			shift
			;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*)
			if [ -n "$version" ]; then
				shell::logger::error "Only one version can be given"
				return "$RETURN_INVALID"
			fi
			version="$1"
			;;
		esac
		shift
	done

	if [ ! -d "$dir" ]; then
		shell::logger::error "Directory not found: $dir"
		return "$RETURN_INVALID"
	fi
	if [ -z "$version" ]; then
		version="$(shell::nvm::query current)"
		case "$version" in
		v[0-9]*) ;;
		*)
			shell::logger::error "No Node version is active to pin (give one: shell::nvm::nvmrc::write 22)"
			return "$RETURN_INVALID"
			;;
		esac
	fi
	if ! shell::nvm::version::valid "$version"; then
		shell::logger::error "Invalid version: '$version'"
		return "$RETURN_INVALID"
	fi

	local target="$dir/.nvmrc"
	if [ -e "$target" ] && [ "$force" != "true" ]; then
		shell::logger::warn "$target already exists ($(head -n 1 "$target")); use --force to replace it"
		return "$RETURN_EXISTS"
	fi
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "echo \"$version\" > \"$target\""
		return "$RETURN_SUCCESS"
	fi
	printf '%s\n' "$version" >"$target" || return "$RETURN_FAILURE"
	shell::logger::success "Pinned $version in $target"
}

# --------------------------------------------------------------------------
# Automatic switching
# --------------------------------------------------------------------------

# @internal
# @description Switch to the version of the nearest `.nvmrc` when the directory changed.
#   Registered by shell::nvm::autouse::on. It does nothing when the directory is
#   the same as the last time, or when there is no `.nvmrc` (your version is left alone).
#   A version the `.nvmrc` asks for that is not installed is reported, not installed.
# @noargs
# @exitcode 0 Always.
# @example
#   shell::nvm::autouse::hook
#
shell::nvm::autouse::hook() {
	if [ "$PWD" = "${SHELL_NVM_AUTOUSE_PWD-}" ]; then
		return "$RETURN_SUCCESS"
	fi
	SHELL_NVM_AUTOUSE_PWD="$PWD"

	local wanted
	wanted="$(shell::nvm::nvmrc::read 2>/dev/null)" || return "$RETURN_SUCCESS"
	shell::dependency::nvm::load >/dev/null 2>&1 || return "$RETURN_SUCCESS"
	if ! nvm use --silent >/dev/null 2>&1; then
		shell::logger::warn ".nvmrc asks for Node '$wanted', which is not installed (shell::nvm::install)"
	fi
	return "$RETURN_SUCCESS"
}

# @description Switch Node automatically when you `cd` into a project with a `.nvmrc`.
#   Registers a hook for this shell session only (zsh: `chpwd`; bash:
#   `PROMPT_COMMAND`) and applies it once for the current directory. Add the call
#   to your profile to keep it. Directories without a `.nvmrc` leave your version alone.
#   Run it in the current shell, not in `$( ... )`.
# @option -h | --help Show help and return.
# @exitcode 0 The hook is registered.
# @exitcode 3 nvm is not installed.
# @see shell::nvm::autouse::off
# @example
#   shell::nvm::autouse::on
#
shell::nvm::autouse::on() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Switch Node automatically when you cd into a project with a .nvmrc"
		shell::logger::usage "shell::nvm::autouse::on"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "Per session; add the call to your profile to keep it."
		shell::logger::example "shell::nvm::autouse::on"
		return "$RETURN_SUCCESS"
	fi
	shell::dependency::nvm::load >/dev/null 2>&1 || {
		shell::logger::error "nvm is not installed (install it with: shell::dependency::nvm::install)"
		return "$RETURN_NOT_FOUND"
	}

	if [ "${SHELL_NVM_AUTOUSE-}" = "on" ]; then
		shell::logger::info "Automatic switching is already on"
		return "$RETURN_SUCCESS"
	fi
	if [ -n "${ZSH_VERSION-}" ]; then
		autoload -Uz add-zsh-hook
		add-zsh-hook chpwd shell::nvm::autouse::hook
	else
		case "${PROMPT_COMMAND-}" in
		*shell::nvm::autouse::hook*) ;;
		*) PROMPT_COMMAND="shell::nvm::autouse::hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
		esac
	fi
	SHELL_NVM_AUTOUSE="on"
	SHELL_NVM_AUTOUSE_PWD=""
	shell::nvm::autouse::hook
	shell::logger::success "Automatic switching is on: Node follows the .nvmrc of the directory you are in"
}

# @description Stop switching Node automatically (undo shell::nvm::autouse::on).
# @option -h | --help Show help and return.
# @exitcode 0 The hook is removed (or was not registered).
# @see shell::nvm::autouse::on
# @example
#   shell::nvm::autouse::off
#
shell::nvm::autouse::off() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Stop switching Node automatically"
		shell::logger::usage "shell::nvm::autouse::off"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::autouse::off"
		return "$RETURN_SUCCESS"
	fi
	if [ -n "${ZSH_VERSION-}" ]; then
		autoload -Uz add-zsh-hook
		add-zsh-hook -d chpwd shell::nvm::autouse::hook 2>/dev/null
	else
		PROMPT_COMMAND="${PROMPT_COMMAND//shell::nvm::autouse::hook;/}"
		PROMPT_COMMAND="${PROMPT_COMMAND//shell::nvm::autouse::hook/}"
	fi
	SHELL_NVM_AUTOUSE="off"
	shell::logger::success "Automatic switching is off"
}

# @description Tell whether automatic switching is on in this shell.
# @option -h | --help Show help and return.
# @stdout `on` or `off`.
# @exitcode 0 It is on.
# @exitcode 1 It is off.
# @example
#   shell::nvm::autouse::status
#
shell::nvm::autouse::status() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Tell whether automatic switching is on"
		shell::logger::usage "shell::nvm::autouse::status"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::autouse::status"
		return "$RETURN_SUCCESS"
	fi
	if [ "${SHELL_NVM_AUTOUSE-}" = "on" ]; then
		printf 'on\n'
		return "$RETURN_SUCCESS"
	fi
	printf 'off\n'
	return "$RETURN_FAILURE"
}

# --------------------------------------------------------------------------
# Check-up
# --------------------------------------------------------------------------

# @description Check the nvm set-up and say what is wrong, if anything.
#   Reports where nvm is, its version, the Node in use, the default, the version
#   the nearest `.nvmrc` asks for (and whether it is installed), and whether the
#   `node` on your PATH is the one nvm manages.
# @option -h | --help Show help and return.
# @stdout One line per check, `ok`, `warn` or `fail` first.
# @exitcode 0 Nothing is wrong (warnings are allowed).
# @exitcode 1 Something is wrong.
# @exitcode 3 nvm is not installed.
# @example
#   shell::nvm::doctor
#
shell::nvm::doctor() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Check the nvm set-up"
		shell::logger::usage "shell::nvm::doctor"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::doctor"
		return "$RETURN_SUCCESS"
	fi

	local nvm_sh current default wanted rc_file resolved node_path problems=0
	nvm_sh="$(shell::dependency::nvm::path)" || {
		printf 'fail  nvm is not installed (shell::dependency::nvm::install)\n'
		return "$RETURN_NOT_FOUND"
	}
	shell::dependency::nvm::load >/dev/null 2>&1 || {
		printf 'fail  nvm.sh was found (%s) but could not be loaded\n' "$nvm_sh"
		return "$RETURN_FAILURE"
	}
	printf 'ok    nvm %s (%s)\n' "$(shell::nvm::query --version)" "$nvm_sh"
	printf 'ok    NVM_DIR=%s\n' "${NVM_DIR-}"

	current="$(shell::nvm::query current)"
	case "$current" in
	v[0-9]*) printf 'ok    in use: %s\n' "$current" ;;
	*) printf 'warn  no nvm-managed Node is active in this shell (in use: %s); try shell::nvm::use --lts\n' "${current:-none}" ;;
	esac

	default="$(shell::nvm::query alias default | head -n 1)"
	if [ -n "$default" ]; then
		printf 'ok    default: %s\n' "$default"
	else
		printf 'warn  no default version: new terminals start without Node (shell::nvm::default --help)\n'
	fi

	if rc_file="$(shell::nvm::nvmrc::find)"; then
		wanted="$(shell::nvm::nvmrc::read)"
		resolved="$(shell::nvm::query version "$wanted")"
		if [ -n "$resolved" ] && [ "$resolved" != "N/A" ]; then
			if [ "$resolved" = "$current" ]; then
				printf 'ok    %s asks for %s, which is the one in use\n' "$rc_file" "$wanted"
			else
				printf 'warn  %s asks for %s (%s) but %s is in use: shell::nvm::use\n' "$rc_file" "$wanted" "$resolved" "$current"
			fi
		else
			printf 'fail  %s asks for %s, which is not installed: shell::nvm::install\n' "$rc_file" "$wanted"
			problems=1
		fi
	else
		printf 'ok    no .nvmrc here or above\n'
	fi

	node_path="$(command -v node 2>/dev/null)"
	case "$node_path" in
	'') printf 'warn  no node on the PATH\n' ;;
	"${NVM_DIR-}"/*) printf 'ok    node on the PATH is managed by nvm (%s)\n' "$node_path" ;;
	*) printf 'warn  node on the PATH (%s) is not the one nvm manages\n' "$node_path" ;;
	esac

	if [ "$problems" -ne 0 ]; then
		return "$RETURN_FAILURE"
	fi
	return "$RETURN_SUCCESS"
}
