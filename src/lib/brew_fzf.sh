#!/usr/bin/env bash
# @file lib/brew_fzf.sh
# @brief Interactive Homebrew management with fzf, and tools to find unused packages.
# @description
#   Built on the plain commands of lib/brew.sh. Every `*::fzf` function lists
#   something you can act on, lets you pick one or many entries with a live
#   `brew info` preview (Tab marks, Ctrl-A marks all, Enter confirms, ESC
#   cancels), asks before anything destructive, and then calls the matching
#   `shell::brew::*` command.
#
#   Finding what you no longer need (shell::brew::unused, shell::brew::unused::fzf)
#   looks for two kinds of packages:
#
#   * **orphan**: installed only as a dependency and now needed by nothing
#     (exactly what `brew autoremove` would remove);
#   * **stale**: a formula you installed yourself, that no other formula needs,
#     whose files have not been touched for SHELL_BREW_STALE_DAYS days and none of
#     whose commands appears in your shell history.
#
#   Stale is a *hint*, not proof: Homebrew does not record when a command was
#   last run. That is why nothing is removed without you marking it and
#   confirming it, and why the packages in SHELL_BREW_PROTECTED (fzf, git, curl,
#   jq: what this library needs) are never proposed.
#
#   `-n | --dry-run` still lets you browse and choose, but prints the final
#   brew command instead of running it. `-y | --yes` skips the confirmations.

# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

# @internal
# @description Pick one or many rows with fzf and print the first word of each.
#   Candidate rows come from **stdin**; the first word of a row is the package
#   name, the rest is information shown to the user.
# @option -m | --multi Allow several picks (Tab to mark, Ctrl-A to mark all).
# @option -p | --prompt Text of the fzf prompt.
# @option -P | --preview Command shown in the preview pane; `{1}` is the package name.
# @option -H | --header Line of help shown above the list.
# @stdin The rows.
# @stdout The chosen names, one per line.
# @exitcode 0 At least one row was chosen.
# @exitcode 2 Unknown option.
# @exitcode 8 There were no rows.
# @exitcode 9 The user cancelled (ESC) or nothing matched.
# @exitcode 3 fzf is not installed.
# @example
#   names="$(shell::brew::list -1 | shell::brew::fzf::pick -m -p "Remove: ")"
#
shell::brew::fzf::pick() {
	local multi="false" prompt="Select: " preview="" header=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-m | --multi)
			multi="true"
			shift
			;;
		-p | --prompt | -P | --preview | -H | --header)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			case "$1" in
			-p | --prompt) prompt="$2" ;;
			-P | --preview) preview="$2" ;;
			-H | --header) header="$2" ;;
			esac
			shift 2
			;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
	done

	local rows
	rows="$(cat)"
	if [ -z "$rows" ]; then
		return "$RETURN_EMPTY"
	fi

	local -a fzf_args=("--prompt=$prompt")
	if [ "$multi" = "true" ]; then
		fzf_args+=(--multi "--bind=ctrl-a:select-all")
	fi
	if [ -n "$preview" ]; then
		fzf_args+=("--preview=$preview" "--preview-window=right:60%:wrap")
	fi
	if [ -n "$header" ]; then
		fzf_args+=("--header=$header")
	fi

	local picked rc
	picked="$(printf '%s\n' "$rows" | shell::fzf::select "${fzf_args[@]}")"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		return "$rc"
	fi
	printf '%s\n' "$picked" | awk 'NF { print $1 }'
}

# @internal
# @description Build the fzf preview command that shows `brew info` for the focused row.
# @arg $1 string Optional `--cask` to preview a cask.
# @stdout The command, with `{1}` for fzf to fill in.
# @exitcode 0 Success.
# @exitcode 3 Homebrew is not installed.
# @example
#   --preview="$(shell::brew::fzf::preview --cask)"
#
shell::brew::fzf::preview() {
	local brew_bin
	brew_bin="$(shell::homebrew::path)" || return "$RETURN_NOT_FOUND"
	printf "'%s' info %s{1}\n" "$brew_bin" "${1:+$1 }"
}

# @internal
# @description Ask for confirmation unless `--yes` was given.
# @arg $1 string `true` when the user passed `--yes`.
# @arg $2 string The question.
# @exitcode 0 Confirmed (or skipped because of --yes).
# @exitcode 1 The user answered no.
# @exitcode 9 Input ended.
# @example
#   shell::brew::fzf::confirm "$assume_yes" "Uninstall git?" || return 0
#
shell::brew::fzf::confirm() {
	if [ "${1-}" = "true" ]; then
		return "$RETURN_SUCCESS"
	fi
	shell::ask::accept "${2-Continue?}"
}

# @internal
# @description Print the installed packages as rows: name, versions, `[pinned]`.
# @arg $1 string Optional `--cask` for casks (default: formulae).
# @stdout Rows `name  version  [pinned]`.
# @exitcode 0 Success.
# @exitcode 3 Homebrew is not installed.
# @example
#   shell::brew::fzf::rows::installed --cask | shell::brew::fzf::pick -m
#
shell::brew::fzf::rows::installed() {
	local kind="--formula" pinned
	if [ "${1-}" = "--cask" ]; then
		kind="--cask"
	fi
	shell::homebrew::path >/dev/null 2>&1 || return "$RETURN_NOT_FOUND"
	pinned="$(shell::brew::query list "$kind" --pinned | tr '\n' ' ')"
	shell::brew::query list "$kind" --versions | awk -v pinned=" $pinned " '
		NF {
			v = $2
			if (NF > 2) v = v "+" (NF - 2)
			printf "%-34s %-22s %s\n", $1, v, (index(pinned, " " $1 " ") ? "[pinned]" : "")
		}'
}

# @internal
# @description Print kilobytes as a human size (K, M, G) in the 3rd tab-separated
#   column of every line, leaving the other columns alone.
# @stdin Tab-separated lines whose 3rd column is a size in KB.
# @stdout The same lines with a human size.
# @exitcode 0 Always.
# @example
#   printf 'git\tstale\t2048\tx\n' | shell::brew::size::format
#
shell::brew::size::format() {
	awk -F'\t' 'BEGIN { OFS = "\t" }
		{
			kb = $3 + 0
			if (kb >= 1048576) h = sprintf("%.1fG", kb / 1048576)
			else if (kb >= 1024) h = sprintf("%.1fM", kb / 1024)
			else h = sprintf("%dK", kb)
			$3 = h
			print
		}'
}

# --------------------------------------------------------------------------
# Install, uninstall, upgrade
# --------------------------------------------------------------------------

# @description Browse everything Homebrew can install and install what you pick.
#   Lists every formula (or cask) with a live `brew info` preview; packages that
#   are already installed are tagged. Tab marks several, Ctrl-A marks all.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the install command instead of running it.
# @option -c | --cask Browse casks (GUI apps) instead of formulae.
# @exitcode 0 Done, or nothing chosen.
# @exitcode 3 Homebrew or fzf is not installed.
# @see shell::brew::install
# @example
#   shell::brew::install::fzf
#   shell::brew::install::fzf --cask
#
shell::brew::install::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Browse installable packages with fzf and install the ones you pick"
		shell::logger::usage "shell::brew::install::fzf [-n] [-c]"
		shell::logger::option "-c, --cask" "Browse casks instead of formulae"
		shell::logger::option "-n, --dry-run" "Print the install command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::install::fzf --cask"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" cask="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-c | --cask) cask="true" ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done

	shell::homebrew::path >/dev/null 2>&1 || {
		shell::logger::error "Homebrew is not installed (install it with: shell::homebrew::install)"
		return "$RETURN_NOT_FOUND"
	}

	local list_verb="formulae" kind="--formula" kind_arg="" installed
	local -a opts=()
	if [ "$cask" = "true" ]; then
		list_verb="casks"
		kind="--cask"
		kind_arg="--cask"
		opts+=(--cask)
	fi
	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi

	installed="$(shell::brew::query list "$kind" -1 | tr '\n' ' ')"
	local names rc line
	names="$(shell::brew::query "$list_verb" | awk -v inst="$installed" '
		BEGIN { n = split(inst, a, " "); for (i = 1; i <= n; i++) have[a[i]] = 1 }
		NF { print $1 (($1 in have) ? "  [installed]" : "") }' |
		shell::brew::fzf::pick -m -p "Install: " -P "$(shell::brew::fzf::preview "$kind_arg")" \
			-H "Tab: mark   Ctrl-A: mark all   Enter: install   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_EMPTY")
		shell::logger::warn "Homebrew lists nothing to install (run shell::brew::update first)"
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac

	local -a chosen=()
	while IFS= read -r line; do
		[ -n "$line" ] && chosen+=("$line")
	done <<EOF
$names
EOF
	shell::brew::install ${opts[@]+"${opts[@]}"} ${chosen[@]+"${chosen[@]}"}
}

# @description Pick installed packages and uninstall them, after a safety check.
#   Formulae that another installed formula needs are **skipped with an
#   explanation** instead of breaking that formula (Homebrew would refuse
#   them too); packages you mark together are checked against each other.
#   You are asked to confirm before anything is removed.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the uninstall command instead of running it.
# @option -c | --cask Work on casks.
# @option -z | --zap Also delete the casks' data and settings (implies --cask).
# @option -y | --yes Do not ask for confirmation.
# @exitcode 0 Done, nothing chosen, or the user declined.
# @exitcode 3 Homebrew or fzf is not installed.
# @see shell::brew::uninstall
# @see shell::brew::unused::fzf
# @example
#   shell::brew::uninstall::fzf
#   shell::brew::uninstall::fzf --zap
#
shell::brew::uninstall::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick installed packages with fzf and uninstall them (asks first)"
		shell::logger::usage "shell::brew::uninstall::fzf [-n] [-c] [-z] [-y]"
		shell::logger::option "-c, --cask" "Work on casks"
		shell::logger::option "-z, --zap" "Also delete the casks' data and settings (implies --cask)"
		shell::logger::option "-y, --yes" "Do not ask for confirmation"
		shell::logger::option "-n, --dry-run" "Print the uninstall command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::uninstall::fzf --zap"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" cask="false" zap="false" assume_yes="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-c | --cask) cask="true" ;;
		-z | --zap)
			zap="true"
			cask="true"
			;;
		-y | --yes) assume_yes="true" ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done

	shell::homebrew::path >/dev/null 2>&1 || {
		shell::logger::error "Homebrew is not installed (install it with: shell::homebrew::install)"
		return "$RETURN_NOT_FOUND"
	}

	local kind_arg=""
	if [ "$cask" = "true" ]; then
		kind_arg="--cask"
	fi

	local names rc
	names="$(shell::brew::fzf::rows::installed ${kind_arg:+"$kind_arg"} |
		shell::brew::fzf::pick -m -p "Uninstall: " -P "$(shell::brew::fzf::preview "$kind_arg")" \
			-H "Tab: mark   Ctrl-A: mark all   Enter: uninstall   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_EMPTY")
		shell::logger::info "Nothing is installed"
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac

	# Formulae: leave out the ones another installed formula needs, unless that
	# formula is being removed in the same go.
	local line dependents blocking dep
	local -a chosen=() removable=()
	while IFS= read -r line; do
		[ -n "$line" ] && chosen+=("$line")
	done <<EOF
$names
EOF
	if [ "$cask" = "true" ]; then
		removable=(${chosen[@]+"${chosen[@]}"})
	else
		local picked=" ${chosen[*]} "
		for line in ${chosen[@]+"${chosen[@]}"}; do
			dependents="$(shell::brew::query uses --installed "$line")"
			blocking=""
			while IFS= read -r dep; do
				[ -n "$dep" ] || continue
				case "$picked" in
				*" $dep "*) ;;
				*) blocking="${blocking:+$blocking }$dep" ;;
				esac
			done <<EOF
$dependents
EOF
			if [ -n "$blocking" ]; then
				shell::logger::warn "Skipping $line: still needed by $blocking"
			else
				removable+=("$line")
			fi
		done
	fi

	if [ "${#removable[@]}" -eq 0 ]; then
		shell::logger::info "Nothing to uninstall"
		return "$RETURN_SUCCESS"
	fi

	local question="Uninstall ${removable[*]}?"
	if [ "$zap" = "true" ]; then
		question="Uninstall ${removable[*]} and DELETE their data and settings?"
	fi
	shell::brew::fzf::confirm "$assume_yes" "$question" || {
		shell::logger::info "Aborted"
		return "$RETURN_SUCCESS"
	}

	local -a opts=()
	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi
	if [ "$cask" = "true" ]; then
		opts+=(--cask)
	fi
	if [ "$zap" = "true" ]; then
		opts+=(--zap)
	fi
	shell::brew::uninstall ${opts[@]+"${opts[@]}"} "${removable[@]}"
}

# @description Pick outdated packages and upgrade them.
#   Lists what `brew outdated` reports, with the installed and the new version.
#   Tab marks several, Ctrl-A marks all. Pinned packages never show up.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the upgrade command instead of running it.
# @option -c | --cask Casks only.
# @option --formula Formulae only.
# @option -g | --greedy Also list casks that update themselves.
# @exitcode 0 Done, everything is up to date, or nothing chosen.
# @exitcode 3 Homebrew or fzf is not installed.
# @see shell::brew::upgrade
# @see shell::brew::outdated
# @example
#   shell::brew::upgrade::fzf
#   shell::brew::upgrade::fzf --cask --greedy
#
shell::brew::upgrade::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick outdated packages with fzf and upgrade them"
		shell::logger::usage "shell::brew::upgrade::fzf [-n] [-c | --formula] [-g]"
		shell::logger::option "-c, --cask" "Casks only"
		shell::logger::option "--formula" "Formulae only"
		shell::logger::option "-g, --greedy" "Also list self-updating casks"
		shell::logger::option "-n, --dry-run" "Print the upgrade command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::upgrade::fzf --cask --greedy"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	local -a kind_opts=() opts=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-c | --cask) kind_opts+=(--cask) ;;
		--formula) kind_opts+=(--formula) ;;
		-g | --greedy) kind_opts+=(--greedy) ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done

	shell::homebrew::path >/dev/null 2>&1 || {
		shell::logger::error "Homebrew is not installed (install it with: shell::homebrew::install)"
		return "$RETURN_NOT_FOUND"
	}

	local names rc
	names="$(shell::brew::query outdated --verbose ${kind_opts[@]+"${kind_opts[@]}"} |
		shell::brew::fzf::pick -m -p "Upgrade: " -P "$(shell::brew::fzf::preview)" \
			-H "Tab: mark   Ctrl-A: mark all   Enter: upgrade   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_EMPTY")
		shell::logger::success "Everything is up to date"
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac

	local line
	local -a chosen=()
	while IFS= read -r line; do
		[ -n "$line" ] && chosen+=("$line")
	done <<EOF
$names
EOF
	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi
	shell::brew::upgrade ${opts[@]+"${opts[@]}"} ${kind_opts[@]+"${kind_opts[@]}"} "${chosen[@]}"
}

# @description Browse installed packages and read their `brew info`.
#   The list stays open after each look; ESC leaves. The preview pane shows the
#   same information live as you move.
# @option -h | --help Show help and return.
# @option -c | --cask Browse casks.
# @exitcode 0 Done.
# @exitcode 3 Homebrew or fzf is not installed.
# @see shell::brew::info
# @example
#   shell::brew::info::fzf
#
shell::brew::info::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Browse installed packages and show their brew info"
		shell::logger::usage "shell::brew::info::fzf [-c]"
		shell::logger::option "-c, --cask" "Browse casks"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::info::fzf --cask"
		return "$RETURN_SUCCESS"
	fi

	local kind_arg=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-c | --cask) kind_arg="--cask" ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done

	shell::homebrew::path >/dev/null 2>&1 || {
		shell::logger::error "Homebrew is not installed (install it with: shell::homebrew::install)"
		return "$RETURN_NOT_FOUND"
	}

	local name rc
	while true; do
		name="$(shell::brew::fzf::rows::installed ${kind_arg:+"$kind_arg"} |
			shell::brew::fzf::pick -p "Package: " -P "$(shell::brew::fzf::preview "$kind_arg")" \
				-H "Enter: show full info   ESC: leave")"
		rc=$?
		case "$rc" in
		0) ;;
		"$RETURN_EMPTY")
			shell::logger::info "Nothing is installed"
			return "$RETURN_SUCCESS"
			;;
		"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
		*) return "$rc" ;;
		esac
		shell::brew::info ${kind_arg:+"$kind_arg"} "$name"
	done
}

# --------------------------------------------------------------------------
# Pin, unpin
# --------------------------------------------------------------------------

# @description Pick installed packages and pin them, so `brew upgrade` skips them.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the pin command instead of running it.
# @option -c | --cask Work on casks.
# @exitcode 0 Done, or nothing chosen.
# @exitcode 3 Homebrew or fzf is not installed.
# @see shell::brew::pin
# @see shell::brew::unpin::fzf
# @example
#   shell::brew::pin::fzf
#
shell::brew::pin::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick installed packages with fzf and pin them"
		shell::logger::usage "shell::brew::pin::fzf [-n] [-c]"
		shell::logger::option "-c, --cask" "Work on casks"
		shell::logger::option "-n, --dry-run" "Print the pin command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::pin::fzf"
		return "$RETURN_SUCCESS"
	fi
	shell::brew::pin::apply pin "$@"
}

# @description Pick pinned packages and unpin them, so `brew upgrade` upgrades them again.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the unpin command instead of running it.
# @option -c | --cask Work on casks.
# @exitcode 0 Done, nothing is pinned, or nothing chosen.
# @exitcode 3 Homebrew or fzf is not installed.
# @see shell::brew::unpin
# @see shell::brew::pin::fzf
# @example
#   shell::brew::unpin::fzf
#
shell::brew::unpin::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick pinned packages with fzf and unpin them"
		shell::logger::usage "shell::brew::unpin::fzf [-n] [-c]"
		shell::logger::option "-c, --cask" "Work on casks"
		shell::logger::option "-n, --dry-run" "Print the unpin command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::unpin::fzf"
		return "$RETURN_SUCCESS"
	fi
	shell::brew::pin::apply unpin "$@"
}

# @internal
# @description Shared body of shell::brew::pin::fzf and shell::brew::unpin::fzf.
# @arg $1 string `pin` or `unpin`.
# @arg $@ string The options of the public function.
# @exitcode 0 Done, or nothing to do.
# @exitcode 2 Unknown option.
# @exitcode 3 Homebrew or fzf is not installed.
shell::brew::pin::apply() {
	local action="${1-}"
	shift

	local dry_run="false" kind="--formula" kind_arg=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-c | --cask)
			kind="--cask"
			kind_arg="--cask"
			;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done

	shell::homebrew::path >/dev/null 2>&1 || {
		shell::logger::error "Homebrew is not installed (install it with: shell::homebrew::install)"
		return "$RETURN_NOT_FOUND"
	}

	local rows names rc
	if [ "$action" = "pin" ]; then
		rows="$(shell::brew::fzf::rows::installed ${kind_arg:+"$kind_arg"} | grep -v '\[pinned\]$')"
	else
		rows="$(shell::brew::query list "$kind" --pinned)"
	fi
	names="$(printf '%s\n' "$rows" | shell::brew::fzf::pick -m -p "${action}: " -P "$(shell::brew::fzf::preview "$kind_arg")" \
		-H "Tab: mark   Enter: ${action}   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_EMPTY")
		if [ "$action" = "pin" ]; then
			shell::logger::info "Nothing left to pin"
		else
			shell::logger::info "Nothing is pinned"
		fi
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac

	local line
	local -a chosen=() opts=()
	while IFS= read -r line; do
		[ -n "$line" ] && chosen+=("$line")
	done <<EOF
$names
EOF
	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi
	if [ -n "$kind_arg" ]; then
		opts+=(--cask)
	fi
	if [ "$action" = "pin" ]; then
		shell::brew::pin ${opts[@]+"${opts[@]}"} "${chosen[@]}"
	else
		shell::brew::unpin ${opts[@]+"${opts[@]}"} "${chosen[@]}"
	fi
}

# --------------------------------------------------------------------------
# Taps and services
# --------------------------------------------------------------------------

# @description Pick taps and remove them.
#   `homebrew/core` and `homebrew/cask` are not listed: they are Homebrew's own
#   catalogue and removing them breaks `brew install`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the untap command instead of running it.
# @option -f | --force Untap even if packages from the tap are installed.
# @option -y | --yes Do not ask for confirmation.
# @exitcode 0 Done, no removable taps, or nothing chosen.
# @exitcode 3 Homebrew or fzf is not installed.
# @see shell::brew::untap
# @example
#   shell::brew::untap::fzf
#
shell::brew::untap::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick taps with fzf and remove them"
		shell::logger::usage "shell::brew::untap::fzf [-n] [-f] [-y]"
		shell::logger::option "-f, --force" "Untap even if packages from it are installed"
		shell::logger::option "-y, --yes" "Do not ask for confirmation"
		shell::logger::option "-n, --dry-run" "Print the untap command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::untap::fzf"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" assume_yes="false"
	local -a opts=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-f | --force) opts+=(--force) ;;
		-y | --yes) assume_yes="true" ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done

	shell::homebrew::path >/dev/null 2>&1 || {
		shell::logger::error "Homebrew is not installed (install it with: shell::homebrew::install)"
		return "$RETURN_NOT_FOUND"
	}

	local names rc
	names="$(shell::brew::query tap | grep -v -E '^homebrew/(core|cask)$' |
		shell::brew::fzf::pick -m -p "Untap: " -H "Tab: mark   Enter: untap   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_EMPTY")
		shell::logger::info "No removable taps"
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac

	local line
	local -a chosen=()
	while IFS= read -r line; do
		[ -n "$line" ] && chosen+=("$line")
	done <<EOF
$names
EOF
	shell::brew::fzf::confirm "$assume_yes" "Untap ${chosen[*]}?" || {
		shell::logger::info "Aborted"
		return "$RETURN_SUCCESS"
	}
	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi
	shell::brew::untap ${opts[@]+"${opts[@]}"} "${chosen[@]}"
}

# @description Pick a background service, then pick what to do with it.
#   Shows `brew services list` (name, status, user), then offers start, stop,
#   restart, run (this session only), kill and info. The list is shown again
#   after each action so you see the new status; ESC or Back leaves.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the services command instead of running it.
# @exitcode 0 Done.
# @exitcode 3 Homebrew or fzf is not installed.
# @see shell::brew::services
# @example
#   shell::brew::services::fzf
#
shell::brew::services::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick a Homebrew service with fzf, then start / stop / restart it"
		shell::logger::usage "shell::brew::services::fzf [-n]"
		shell::logger::option "-n, --dry-run" "Print the services command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::services::fzf"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	local -a opts=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done
	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi

	shell::homebrew::path >/dev/null 2>&1 || {
		shell::logger::error "Homebrew is not installed (install it with: shell::homebrew::install)"
		return "$RETURN_NOT_FOUND"
	}

	local name action rc
	while true; do
		name="$(shell::brew::query services list | awk 'NR > 1 && NF' |
			shell::brew::fzf::pick -p "Service: " -H "Enter: choose an action   ESC: leave")"
		rc=$?
		case "$rc" in
		0) ;;
		"$RETURN_EMPTY")
			shell::logger::info "No services found"
			return "$RETURN_SUCCESS"
			;;
		"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
		*) return "$rc" ;;
		esac

		action="$(shell::ask::option::back --prompt "$name: " start stop restart run kill info)"
		rc=$?
		case "$rc" in
		0) ;;
		"$RETURN_BACK") continue ;;
		*) return "$RETURN_SUCCESS" ;;
		esac
		shell::brew::services ${opts[@]+"${opts[@]}"} "$action" "$name"
	done
}

# --------------------------------------------------------------------------
# Disk usage and unused packages
# --------------------------------------------------------------------------

# @description Show which installed packages take the most disk space.
#   Measures every directory of the Cellar (or the Caskroom with `--cask`),
#   biggest first.
# @option -h | --help Show help and return.
# @option -c | --cask Measure casks instead of formulae.
# @arg $1 integer How many packages to show (default: 20).
# @stdout One line per package: size, name.
# @exitcode 0 Success.
# @exitcode 2 The count is not a positive integer.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::unused::fzf
# @example
#   shell::brew::size
#   shell::brew::size --cask 10
#
shell::brew::size() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show the installed packages that take the most disk space"
		shell::logger::usage "shell::brew::size [-c] [count]"
		shell::logger::item "count" "How many packages to show (default 20)"
		shell::logger::option "-c, --cask" "Measure casks instead of formulae"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::size --cask 10"
		return "$RETURN_SUCCESS"
	fi

	local root_verb="--cellar" count="20" counted="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-c | --cask) root_verb="--caskroom" ;;
		-*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*)
			if [ "$counted" = "true" ]; then
				shell::logger::error "Only one count can be given"
				return "$RETURN_INVALID"
			fi
			count="$1"
			counted="true"
			;;
		esac
		shift
	done
	case "$count" in
	'' | *[!0-9]* | 0)
		shell::logger::error "Count must be a positive integer"
		return "$RETURN_INVALID"
		;;
	esac

	shell::homebrew::path >/dev/null 2>&1 || {
		shell::logger::error "Homebrew is not installed (install it with: shell::homebrew::install)"
		return "$RETURN_NOT_FOUND"
	}
	local root
	root="$(shell::brew::query "$root_verb")"
	if [ -z "$root" ] || [ ! -d "$root" ]; then
		shell::logger::info "Nothing is installed"
		return "$RETURN_SUCCESS"
	fi

	find "$root" -mindepth 1 -maxdepth 1 -exec du -sk {} + 2>/dev/null |
		sort -k1,1nr | head -n "$count" |
		awk -F'\t' 'BEGIN { OFS = "\t" } { n = split($2, p, "/"); print n ? p[n] : $2, "", $1 }' |
		shell::brew::size::format |
		awk -F'\t' '{ printf "%8s  %s\n", $3, $1 }'
}

# @internal
# @description Find the packages that look unused and print them, one per line, as
#   `name<TAB>reason<TAB>size-in-KB<TAB>why`. The reason is `orphan` or `stale`.
#   See the file header for what those mean. Packages in SHELL_BREW_PROTECTED are
#   skipped. Shell history (`$HISTFILE`, `~/.zsh_history`, `~/.bash_history`) is
#   only read, never sent anywhere.
# @option -d | --days Days without activity before a formula is stale (default SHELL_BREW_STALE_DAYS).
# @option -H | --no-history Do not look at the shell history.
# @option -o | --orphans Only orphans.
# @option -s | --stale Only stale formulae.
# @stdout The candidates, tab separated.
# @exitcode 0 Success (possibly nothing found).
# @exitcode 2 Invalid option or day count.
# @exitcode 3 Homebrew is not installed.
# @example
#   shell::brew::unused::scan --days 30 | cut -f1
#
shell::brew::unused::scan() {
	local days="${SHELL_BREW_STALE_DAYS:-90}" use_history="true" want_orphans="true" want_stale="true"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-d | --days)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			days="$2"
			shift
			;;
		-H | --no-history) use_history="false" ;;
		-o | --orphans) want_stale="false" ;;
		-s | --stale) want_orphans="false" ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done
	case "$days" in
	'' | *[!0-9]* | 0)
		shell::logger::error "Days must be a positive integer (got '$days')"
		return "$RETURN_INVALID"
		;;
	esac

	shell::homebrew::path >/dev/null 2>&1 || {
		shell::logger::error "Homebrew is not installed (install it with: shell::homebrew::install)"
		return "$RETURN_NOT_FOUND"
	}

	local protected=" ${SHELL_BREW_PROTECTED-} "
	local cellar prefix name size exes recent detail orphans="" words="" leaves hist_file
	cellar="$(shell::brew::query --cellar)"
	prefix="$(shell::brew::query --prefix)"

	# `brew autoremove --dry-run` prints "==> Would autoremove N unneeded formulae:"
	# and then one name per line.
	orphans="$(shell::brew::query autoremove --dry-run |
		awk '/^==>/ { on = ($0 ~ /unneeded/); next } on && NF == 1 { print $1 }')"

	if [ "$want_orphans" = "true" ]; then
		while IFS= read -r name; do
			[ -n "$name" ] || continue
			case "$protected" in
			*" $name "*) continue ;;
			esac
			size="$(du -sk "$cellar/$name" 2>/dev/null | awk '{ print $1 }')"
			printf '%s\torphan\t%s\t%s\n' "$name" "${size:-0}" "a dependency nothing needs any more"
		done <<EOF
$orphans
EOF
	fi

	if [ "$want_stale" = "false" ]; then
		return "$RETURN_SUCCESS"
	fi

	# One list of every word found in the shell history, to look commands up in.
	if [ "$use_history" = "true" ]; then
		words="$(mktemp "${TMPDIR:-/tmp}/brew-words.XXXXXX" 2>/dev/null)"
		if [ -n "$words" ]; then
			for hist_file in "${HISTFILE-}" "$HOME/.zsh_history" "$HOME/.bash_history"; do
				if [ -n "$hist_file" ] && [ -r "$hist_file" ]; then
					cat "$hist_file" 2>/dev/null
				fi
			done | LC_ALL=C tr -c 'A-Za-z0-9._+-' '\n' | grep -v '^$' | LC_ALL=C sort -u >"$words"
			if [ ! -s "$words" ]; then
				rm -f "$words"
				words=""
			fi
		fi
	fi

	leaves="$(shell::brew::query leaves --installed-on-request)"
	while IFS= read -r name; do
		[ -n "$name" ] || continue
		case "$protected" in
		*" $name "*) continue ;;
		esac
		[ -d "$cellar/$name" ] || continue
		case "
$orphans
" in
		*"
$name
"*) continue ;;
		esac

		# Touched recently: not stale.
		recent="$(find "$cellar/$name" -mindepth 1 -maxdepth 1 -mtime "-$days" 2>/dev/null | head -n 1)"
		[ -z "$recent" ] || continue

		exes="$({
			ls -1 "$prefix/opt/$name/bin"
			ls -1 "$prefix/opt/$name/sbin"
		} 2>/dev/null)"
		if [ -n "$words" ]; then
			if [ -z "$exes" ]; then
				detail="no commands (a library?), untouched for ${days}+ days"
			elif printf '%s\n' "$exes" | grep -Fxq -f "$words"; then
				continue
			else
				detail="untouched for ${days}+ days, none of its commands in your shell history"
			fi
		else
			detail="untouched for ${days}+ days (shell history not checked)"
		fi
		size="$(du -sk "$cellar/$name" 2>/dev/null | awk '{ print $1 }')"
		printf '%s\tstale\t%s\t%s\n' "$name" "${size:-0}" "$detail"
	done <<EOF
$leaves
EOF

	if [ -n "$words" ]; then
		rm -f "$words"
	fi
	return "$RETURN_SUCCESS"
}

# @description List the installed packages that look unused: orphans and stale formulae.
#   Read-only: it only reports. To remove what it finds, use
#   shell::brew::unused::fzf.
#
#   * `orphan`: installed as a dependency and needed by nothing now.
#   * `stale`: a formula you installed, that nothing depends on, whose files were
#     untouched for `--days` days and none of whose commands is in your shell
#     history. A hint, not proof (see the file header).
# @option -h | --help Show help and return.
# @option -d | --days Days without activity before a formula is stale (default: SHELL_BREW_STALE_DAYS, 90).
# @option -H | --no-history Ignore the shell history (age only).
# @option -o | --orphans Only orphans.
# @option -s | --stale Only stale formulae.
# @option -q | --names Print only the names, one per line (for scripts).
# @stdout A table: package, reason, size, why. With `--names`, just the names.
# @exitcode 0 Success, even when nothing was found.
# @exitcode 2 Invalid option or day count.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::unused::fzf
# @see shell::brew::size
# @example
#   shell::brew::unused
#   shell::brew::unused --days 30 --orphans
#   shell::brew::unused --names | xargs shell::brew::uninstall -n
#
shell::brew::unused() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List installed packages that look unused (orphans and stale formulae)"
		shell::logger::usage "shell::brew::unused [-d <days>] [-H] [-o | -s] [-q]"
		shell::logger::option "-d, --days <n>" "Days without activity before a formula is stale (default 90)"
		shell::logger::option "-H, --no-history" "Ignore the shell history (age only)"
		shell::logger::option "-o, --orphans" "Only orphans (dependencies nothing needs)"
		shell::logger::option "-s, --stale" "Only stale formulae you installed"
		shell::logger::option "-q, --names" "Names only, one per line"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "Read-only. Remove what it finds with shell::brew::unused::fzf."
		shell::logger::example "shell::brew::unused --days 30 --orphans"
		return "$RETURN_SUCCESS"
	fi

	local names_only="false"
	local -a scan_args=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-q | --names) names_only="true" ;;
		-d | --days)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			scan_args+=("$1" "$2")
			shift
			;;
		*) scan_args+=("$1") ;;
		esac
		shift
	done

	local found rc
	found="$(shell::brew::unused::scan ${scan_args[@]+"${scan_args[@]}"})"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		return "$rc"
	fi
	if [ -z "$found" ]; then
		shell::logger::success "No unused packages found"
		return "$RETURN_SUCCESS"
	fi

	if [ "$names_only" = "true" ]; then
		printf '%s\n' "$found" | cut -f1
		return "$RETURN_SUCCESS"
	fi

	{
		printf 'PACKAGE\tREASON\tSIZE\tWHY\n'
		printf '%s\n' "$found" | sort -t "$(printf '\t')" -k3,3nr | shell::brew::size::format
	} | awk -F'\t' '{ printf "%-30s %-8s %8s  %s\n", $1, $2, $3, $4 }'
}

# @description Find unused packages, pick the ones to remove, and remove them.
#   Runs shell::brew::unused::scan, lists the candidates (package, reason, size,
#   why) with a preview of `brew info` and of what depends on each, and lets you
#   mark the ones to uninstall (Tab marks, Ctrl-A marks all). After a
#   confirmation it uninstalls them, then offers `brew autoremove` for the
#   dependencies that became orphans because of it.
#
#   Nothing is pre-selected and nothing is removed without your confirmation.
#   Packages in SHELL_BREW_PROTECTED are never listed.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the commands instead of running them.
# @option -d | --days Days without activity before a formula is stale (default 90).
# @option -H | --no-history Ignore the shell history (age only).
# @option -o | --orphans Only orphans.
# @option -s | --stale Only stale formulae.
# @option -y | --yes Do not ask for confirmation (also runs autoremove afterwards).
# @exitcode 0 Done, nothing found, nothing chosen, or the user declined.
# @exitcode 2 Invalid option or day count.
# @exitcode 3 Homebrew or fzf is not installed.
# @see shell::brew::unused
# @see shell::brew::autoremove
# @example
#   shell::brew::unused::fzf
#   shell::brew::unused::fzf --orphans
#   shell::brew::unused::fzf -n --days 30
#
shell::brew::unused::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Find unused Homebrew packages, pick some with fzf and uninstall them"
		shell::logger::usage "shell::brew::unused::fzf [-n] [-d <days>] [-H] [-o | -s] [-y]"
		shell::logger::option "-d, --days <n>" "Days without activity before a formula is stale (default 90)"
		shell::logger::option "-H, --no-history" "Ignore the shell history (age only)"
		shell::logger::option "-o, --orphans" "Only orphans (dependencies nothing needs)"
		shell::logger::option "-s, --stale" "Only stale formulae you installed"
		shell::logger::option "-y, --yes" "Do not ask for confirmation"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "Nothing is pre-selected; nothing is removed without your confirmation."
		shell::logger::example "shell::brew::unused::fzf --orphans"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" assume_yes="false"
	local -a scan_args=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-y | --yes) assume_yes="true" ;;
		-d | --days)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			scan_args+=("$1" "$2")
			shift
			;;
		*) scan_args+=("$1") ;;
		esac
		shift
	done

	local found rc
	found="$(shell::brew::unused::scan ${scan_args[@]+"${scan_args[@]}"})"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		return "$rc"
	fi
	if [ -z "$found" ]; then
		shell::logger::success "No unused packages found"
		return "$RETURN_SUCCESS"
	fi

	local brew_bin preview names
	brew_bin="$(shell::homebrew::path)"
	preview="'$brew_bin' info {1}; echo; echo 'Needed by:'; '$brew_bin' uses --installed {1}"
	names="$(printf '%s\n' "$found" | sort -t "$(printf '\t')" -k3,3nr | shell::brew::size::format |
		awk -F'\t' '{ printf "%-30s %-8s %8s  %s\n", $1, $2, $3, $4 }' |
		shell::brew::fzf::pick -m -p "Remove: " -P "$preview" \
			-H "Tab: mark   Ctrl-A: mark all   Enter: uninstall   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac

	local line
	local -a chosen=() opts=()
	while IFS= read -r line; do
		[ -n "$line" ] && chosen+=("$line")
	done <<EOF
$names
EOF
	shell::brew::fzf::confirm "$assume_yes" "Uninstall ${chosen[*]}?" || {
		shell::logger::info "Aborted"
		return "$RETURN_SUCCESS"
	}

	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi
	shell::brew::uninstall ${opts[@]+"${opts[@]}"} "${chosen[@]}" || return $?

	# Removing a leaf can orphan its own dependencies.
	if [ "$dry_run" = "false" ]; then
		if shell::brew::fzf::confirm "$assume_yes" "Also run 'brew autoremove' for dependencies nothing needs now?"; then
			shell::brew::autoremove
		fi
	fi
	return "$RETURN_SUCCESS"
}

# @description One-stop clean-up: autoremove, then cleanup, each previewed first.
#   For each step it shows what brew *would* do (`--dry-run`), asks, and only then
#   does it: 1. uninstall dependencies nothing needs (`brew autoremove`);
#   2. delete old versions and stale downloads (`brew cleanup`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Show the previews, then print the real commands instead of running them.
# @option -y | --yes Do not ask for confirmation.
# @exitcode 0 Done, or the user declined a step.
# @exitcode 3 Homebrew is not installed.
# @see shell::brew::autoremove
# @see shell::brew::cleanup
# @example
#   shell::brew::tidy
#
shell::brew::tidy() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Preview, then run, brew autoremove and brew cleanup"
		shell::logger::usage "shell::brew::tidy [-n] [-y]"
		shell::logger::option "-y, --yes" "Do not ask for confirmation"
		shell::logger::option "-n, --dry-run" "Print the real commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::tidy"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" assume_yes="false"
	local -a opts=()
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
	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi

	shell::homebrew::path >/dev/null 2>&1 || {
		shell::logger::error "Homebrew is not installed (install it with: shell::homebrew::install)"
		return "$RETURN_NOT_FOUND"
	}

	shell::logger::section "1/2 Dependencies nothing needs"
	shell::brew::autoremove --preview
	if shell::brew::fzf::confirm "$assume_yes" "Run brew autoremove?"; then
		shell::brew::autoremove ${opts[@]+"${opts[@]}"}
	fi

	shell::logger::section "2/2 Old versions and stale downloads"
	shell::brew::cleanup --preview
	if shell::brew::fzf::confirm "$assume_yes" "Run brew cleanup?"; then
		shell::brew::cleanup ${opts[@]+"${opts[@]}"}
	fi
	return "$RETURN_SUCCESS"
}

# --------------------------------------------------------------------------
# The menu
# --------------------------------------------------------------------------

# @description The Homebrew control panel: one fzf menu for everything above.
#   Install, uninstall, upgrade, browse, find unused packages, tidy up, see disk
#   usage, pin, services, taps, update and doctor. Each entry opens its own
#   picker; "← Back" in the picker returns here, and ESC or "← Back" in the menu
#   leaves.
# @option -h | --help Show help and return.
# @option -n | --dry-run Pass `--dry-run` to every entry: choices are made but nothing is changed.
# @exitcode 0 The user left the menu.
# @exitcode 3 Homebrew or fzf is not installed.
# @see shell::brew::install::fzf
# @see shell::brew::unused::fzf
# @example
#   shell::brew::manage
#   shell::brew::manage -n
#
shell::brew::manage() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Homebrew control panel: install, uninstall, upgrade, find unused packages ..."
		shell::logger::usage "shell::brew::manage [-n]"
		shell::logger::option "-n, --dry-run" "Print the changing commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::brew::manage"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	local -a opts=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done
	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi

	shell::homebrew::path >/dev/null 2>&1 || {
		shell::logger::error "Homebrew is not installed (install it with: shell::homebrew::install)"
		return "$RETURN_NOT_FOUND"
	}

	local choice rc
	while true; do
		choice="$(shell::ask::option::back --prompt "Homebrew: " \
			"Install packages" \
			"Uninstall packages" \
			"Upgrade outdated packages" \
			"Browse installed packages" \
			"Find unused packages" \
			"Tidy up (autoremove + cleanup)" \
			"Largest packages" \
			"Pin a package" \
			"Unpin a package" \
			"Services" \
			"Taps" \
			"Update Homebrew" \
			"Health check (doctor)")"
		rc=$?
		case "$rc" in
		0) ;;
		*) return "$RETURN_SUCCESS" ;;
		esac

		case "$choice" in
		"Install packages") shell::brew::install::fzf ${opts[@]+"${opts[@]}"} ;;
		"Uninstall packages") shell::brew::uninstall::fzf ${opts[@]+"${opts[@]}"} ;;
		"Upgrade outdated packages") shell::brew::upgrade::fzf ${opts[@]+"${opts[@]}"} ;;
		"Browse installed packages") shell::brew::info::fzf ;;
		"Find unused packages") shell::brew::unused::fzf ${opts[@]+"${opts[@]}"} ;;
		"Tidy up (autoremove + cleanup)") shell::brew::tidy ${opts[@]+"${opts[@]}"} ;;
		"Largest packages") shell::brew::size ;;
		"Pin a package") shell::brew::pin::fzf ${opts[@]+"${opts[@]}"} ;;
		"Unpin a package") shell::brew::unpin::fzf ${opts[@]+"${opts[@]}"} ;;
		"Services") shell::brew::services::fzf ${opts[@]+"${opts[@]}"} ;;
		"Taps") shell::brew::untap::fzf ${opts[@]+"${opts[@]}"} ;;
		"Update Homebrew") shell::brew::update ${opts[@]+"${opts[@]}"} ;;
		"Health check (doctor)") shell::brew::doctor ;;
		esac
	done
}
