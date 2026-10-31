#!/usr/bin/env bash
# @file lang/nvm_fzf.sh
# @brief Interactive nvm with fzf, and tools to find Node versions you no longer use.
# @description
#   Built on the plain commands of lang/nvm.sh. Every `*::fzf` function lists
#   something you can act on, lets you pick with a live preview of the global npm
#   packages of each Node version (Tab marks, Ctrl-A marks all, Enter confirms,
#   ESC cancels), asks before anything destructive, and then calls the matching
#   `shell::nvm::*` command.
#
#   Like the commands they use, `use::fzf`, `exec::fzf` and the menu run in the
#   **current shell**, so switching version there changes this terminal.
#
#   Finding what you no longer use (shell::nvm::unused, shell::nvm::unused::fzf)
#   looks at the installed versions and keeps every one that something refers to:
#   the version in use, every alias (so `default`, `lts/*`, `node`, `stable` and
#   yours), the `.nvmrc` of the current project and of the project directories
#   you name. What is left is reported as:
#
#   * **superseded**: a newer version of the same major (a newer patch) is installed;
#   * **unreferenced**: it is the newest of its major, but nothing refers to it.
#
#   Nothing is removed without you marking it and confirming it. Reading the
#   `.nvmrc` files of your projects is the one thing nvm itself cannot do for
#   you: name the directories with `--projects <dir>`, or in
#   `SHELL_NVM_PROJECT_ROOTS` (space separated), and a version that one of those
#   projects asks for is kept.
#
#   `-n | --dry-run` still lets you browse and choose, but prints the final nvm
#   command instead of running it. `-y | --yes` skips the confirmations.

# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

# @internal
# @description Pick one or many rows with fzf and print the first word of each.
#   Candidate rows come from **stdin**; the first word of a row is the value (a
#   version or an alias name), the rest is information shown to the user.
# @option -m | --multi Allow several picks (Tab to mark, Ctrl-A to mark all).
# @option -p | --prompt Text of the fzf prompt.
# @option -P | --preview Command shown in the preview pane; `{1}` is the first word.
# @option -H | --header Line of help shown above the list.
# @stdin The rows.
# @stdout The chosen values, one per line.
# @exitcode 0 At least one row was chosen.
# @exitcode 2 Unknown option.
# @exitcode 8 There were no rows.
# @exitcode 9 The user cancelled (ESC) or nothing matched.
# @exitcode 3 fzf is not installed.
# @example
#   v="$(shell::nvm::fzf::rows::installed | shell::nvm::fzf::pick -p "Version: ")"
#
shell::nvm::fzf::pick() {
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
		fzf_args+=("--preview=$preview" "--preview-window=right:50%:wrap")
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
# @description Ask for confirmation unless `--yes` was given.
# @arg $1 string `true` when the user passed `--yes`.
# @arg $2 string The question.
# @exitcode 0 Confirmed (or skipped because of --yes).
# @exitcode 1 The user answered no.
# @exitcode 9 Input ended.
# @example
#   shell::nvm::fzf::confirm "$assume_yes" "Uninstall v18.19.0?" || return 0
#
shell::nvm::fzf::confirm() {
	if [ "${1-}" = "true" ]; then
		return "$RETURN_SUCCESS"
	fi
	shell::ask::accept "${2-Continue?}"
}

# @internal
# @description Build the fzf preview command: the global npm packages of the focused version.
#   That is what you lose when you remove a version, and what
#   `--reinstall-packages-from` would carry over.
# @stdout The command, with `{1}` for fzf to fill in.
# @exitcode 0 Success.
# @exitcode 3 nvm is not installed.
# @example
#   --preview="$(shell::nvm::fzf::preview)"
#
shell::nvm::fzf::preview() {
	shell::dependency::nvm::load >/dev/null 2>&1 || return "$RETURN_NOT_FOUND"
	printf "echo 'Global npm packages:'; ls -1 '%s/versions/node/'{1}'/lib/node_modules' 2>/dev/null\n" "${NVM_DIR-}"
}

# @internal
# @description Print the installed Node versions, one per line, oldest first.
#   Taken from `nvm ls --no-colors --no-alias`: the first word of each line that is
#   a `vX.Y.Z` version (the `->` marker and the trailing `*` are dropped; `system`
#   and the io.js versions are not Node versions and are left out).
# @stdout The versions, e.g. `v20.11.1`.
# @exitcode 0 Success (possibly nothing installed).
# @exitcode 3 nvm is not installed.
# @example
#   shell::nvm::versions::installed
#
shell::nvm::versions::installed() {
	shell::nvm::query ls --no-colors --no-alias | awk '
        { sub(/^[ \t]*(->)?[ \t]*/, "") }
        $1 ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/ { print $1 }'
}

# @internal
# @description Print the versions that can be installed as rows, newest first:
#   version, label (`(LTS: Iron)`, `(Latest LTS: Iron)`), and `[installed]` for the ones you have.
#   Needs the network.
# @arg $@ string Extra arguments for `nvm ls-remote`, e.g. `--lts`.
# @stdout The rows.
# @exitcode 0 Success.
# @exitcode 3 nvm is not installed.
# @example
#   shell::nvm::versions::remote --lts | head
#
shell::nvm::versions::remote() {
	local installed
	installed="$(shell::nvm::versions::installed | tr '\n' ' ')"
	shell::nvm::query ls-remote --no-colors "$@" | awk -v inst=" $installed " '
        {
            line = $0
            sub(/^[ \t]*(->)?[ \t]*/, "", line)
            n = split(line, f, /[ \t]+/)
            v = f[1]
            if (v !~ /^v[0-9]+\.[0-9]+\.[0-9]+$/) next
            label = ""
            for (i = 2; i <= n; i++) {
                if (f[i] == "*") continue
                label = label (label == "" ? "" : " ") f[i]
            }
            rows[++r] = sprintf("%-12s %-24s %s", v, label, (index(inst, " " v " ") ? "[installed]" : ""))
        }
        END { for (i = r; i >= 1; i--) print rows[i] }'
}

# @internal
# @description Print the installed versions as rows for a picker: version, `[current]`
#   for the one in use, and the aliases that point at it (`default`, `work` ...).
#   The aliases nvm keeps for LTS lines (`lts/*`) are left out of the label.
# @stdout Rows `version  [current]  alias, alias`.
# @exitcode 0 Success (possibly nothing installed).
# @exitcode 3 nvm is not installed.
# @example
#   shell::nvm::fzf::rows::installed | shell::nvm::fzf::pick -m
#
shell::nvm::fzf::rows::installed() {
	local installed current aliases v labels mark
	installed="$(shell::nvm::versions::installed)"
	if [ -z "$installed" ]; then
		return "$RETURN_SUCCESS"
	fi
	current="$(shell::nvm::query current)"
	aliases="$(shell::nvm::query alias --no-colors)"
	while IFS= read -r v; do
		[ -n "$v" ] || continue
		labels="$(printf '%s\n' "$aliases" | awk -v v="$v" '
            $1 !~ /^lts\// {
                p = index($0, "(-> " v)
                if (p > 0) {
                    c = substr($0, p + 4 + length(v), 1)
                    if (c == " " || c == ")") printf "%s%s", (n++ ? ", " : ""), $1
                }
            }')"
		mark=""
		if [ "$v" = "$current" ]; then
			mark="[current]"
		fi
		printf '%-12s %-9s %s\n' "$v" "$mark" "$labels"
	done <<EOF
$installed
EOF
}

# @internal
# @description Print the aliases you made, one per line, as nvm prints them
#   (`name -> target (-> resolved)`). nvm's own aliases (marked `(default)`) and the
#   `lts/*` ones it manages itself are left out.
# @stdout The alias lines.
# @exitcode 0 Success.
# @exitcode 3 nvm is not installed.
# @example
#   shell::nvm::aliases::user
#
shell::nvm::aliases::user() {
	shell::nvm::query alias --no-colors | awk 'NF && $0 !~ /\(default\)$/ && $1 !~ /^lts\// { print }'
}

# @internal
# @description Print kilobytes as a human size (K, M, G) in the 3rd tab-separated
#   column of every line, leaving the other columns alone.
# @stdin Tab-separated lines whose 3rd column is a size in KB.
# @stdout The same lines with a human size.
# @exitcode 0 Always.
# @example
#   printf 'v20\tx\t2048\ty\n' | shell::nvm::size::format
#
shell::nvm::size::format() {
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

# @internal
# @description Common failure of the interactive functions: nvm is missing.
# @exitcode 3 Always.
shell::nvm::fzf::missing() {
	shell::logger::error "nvm is not installed (install it with: shell::dependency::nvm::install)"
	return "$RETURN_NOT_FOUND"
}

# --------------------------------------------------------------------------
# Switch, install, uninstall
# --------------------------------------------------------------------------

# @description Pick an installed Node version and switch THIS shell to it.
#   The list shows the version in use and the aliases of each version. Runs in the
#   current shell: do not call it inside `$( ... )` or a pipeline.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the `nvm use` command instead of running it.
# @option --silent Print nothing of nvm's own.
# @exitcode 0 Done, or nothing chosen.
# @exitcode 3 nvm or fzf is not installed.
# @see shell::nvm::use
# @example
#   shell::nvm::use::fzf
#
shell::nvm::use::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick an installed Node version with fzf and switch this shell to it"
		shell::logger::usage "shell::nvm::use::fzf [-n] [--silent]"
		shell::logger::option "--silent" "Print nothing of nvm's own"
		shell::logger::option "-n, --dry-run" "Print the nvm use command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "Runs in the current shell; do not call it inside \$( ) or a pipeline."
		shell::logger::example "shell::nvm::use::fzf"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	local -a opts=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		--silent) opts+=(--silent) ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done
	shell::dependency::nvm::load >/dev/null 2>&1 || {
		shell::nvm::fzf::missing
		return $?
	}

	local picked rc
	picked="$(shell::nvm::fzf::rows::installed | shell::nvm::fzf::pick -p "Use Node: " -P "$(shell::nvm::fzf::preview)" \
		-H "Enter: switch this shell   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_EMPTY")
		shell::logger::info "No Node version is installed (try: shell::nvm::install --lts)"
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac

	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi
	shell::nvm::use ${opts[@]+"${opts[@]}"} "$picked"
}

# @description Browse the Node versions that can be installed, and install the ones you pick.
#   Newest first, with the LTS line named and the versions you already have
#   tagged. Needs the network. Tab marks several, Ctrl-A marks all.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the install commands instead of running them.
# @option --lts Only LTS versions.
# @option --lts=<name> Only that LTS line, e.g. `--lts=iron`.
# @option --latest-npm Upgrade npm after each install.
# @option --default Make the (last) installed version the default.
# @exitcode 0 Done, or nothing chosen.
# @exitcode 1 An install failed (the others were still tried).
# @exitcode 3 nvm or fzf is not installed.
# @see shell::nvm::install
# @example
#   shell::nvm::install::fzf --lts
#
shell::nvm::install::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Browse installable Node versions with fzf and install the ones you pick"
		shell::logger::usage "shell::nvm::install::fzf [-n] [--lts[=<name>]] [--latest-npm] [--default]"
		shell::logger::option "--lts[=<name>]" "Only LTS versions (of that line)"
		shell::logger::option "--latest-npm" "Upgrade npm after each install"
		shell::logger::option "--default" "Make the last installed version the default"
		shell::logger::option "-n, --dry-run" "Print the install commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::install::fzf --lts"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	local -a list_opts=() install_opts=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		--lts | --lts=*) list_opts+=("$1") ;;
		--latest-npm | --default) install_opts+=("$1") ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done
	shell::dependency::nvm::load >/dev/null 2>&1 || {
		shell::nvm::fzf::missing
		return $?
	}

	local picked rc line failed=0
	local -a chosen=()
	picked="$(shell::nvm::versions::remote ${list_opts[@]+"${list_opts[@]}"} |
		shell::nvm::fzf::pick -m -p "Install Node: " -H "Tab: mark   Ctrl-A: mark all   Enter: install   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_EMPTY")
		shell::logger::warn "nvm listed no versions (is the network reachable?)"
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac

	if [ "$dry_run" = "true" ]; then
		install_opts+=(-n)
	fi
	while IFS= read -r line; do
		[ -n "$line" ] && chosen+=("$line")
	done <<EOF
$picked
EOF
	for line in "${chosen[@]}"; do
		shell::nvm::install ${install_opts[@]+"${install_opts[@]}"} "$line" || failed=1
	done
	return "$failed"
}

# @description Pick installed Node versions and uninstall them, after a safety check.
#   The version in use is skipped (nvm refuses to remove it); a version an alias
#   points at is removed only if you confirm, with the alias named in the question.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the uninstall commands instead of running them.
# @option -y | --yes Do not ask for confirmation.
# @exitcode 0 Done, nothing chosen, or the user declined.
# @exitcode 1 An uninstall failed (the others were still tried).
# @exitcode 3 nvm or fzf is not installed.
# @see shell::nvm::uninstall
# @see shell::nvm::unused::fzf
# @example
#   shell::nvm::uninstall::fzf
#
shell::nvm::uninstall::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick installed Node versions with fzf and uninstall them (asks first)"
		shell::logger::usage "shell::nvm::uninstall::fzf [-n] [-y]"
		shell::logger::option "-y, --yes" "Do not ask for confirmation"
		shell::logger::option "-n, --dry-run" "Print the uninstall commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::uninstall::fzf"
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
	shell::dependency::nvm::load >/dev/null 2>&1 || {
		shell::nvm::fzf::missing
		return $?
	}

	local picked rc line current labels failed=0 note=""
	local -a chosen=() removable=() opts=()
	picked="$(shell::nvm::fzf::rows::installed | shell::nvm::fzf::pick -m -p "Uninstall Node: " -P "$(shell::nvm::fzf::preview)" \
		-H "Tab: mark   Ctrl-A: mark all   Enter: uninstall   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_EMPTY")
		shell::logger::info "No Node version is installed"
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac

	current="$(shell::nvm::query current)"
	while IFS= read -r line; do
		[ -n "$line" ] && chosen+=("$line")
	done <<EOF
$picked
EOF
	for line in "${chosen[@]}"; do
		if [ "$line" = "$current" ]; then
			shell::logger::warn "Skipping $line: it is the version in use (switch first: shell::nvm::use)"
			continue
		fi
		labels="$(shell::nvm::fzf::rows::installed | awk -v v="$line" '$1 == v { $1 = ""; sub(/^ +/, ""); sub(/^\[current\] */, ""); print }')"
		if [ -n "$labels" ]; then
			note="${note:+$note; }$line is the target of: $labels"
		fi
		removable+=("$line")
	done
	if [ "${#removable[@]}" -eq 0 ]; then
		shell::logger::info "Nothing to uninstall"
		return "$RETURN_SUCCESS"
	fi

	shell::nvm::fzf::confirm "$assume_yes" "Uninstall ${removable[*]}${note:+ ($note)}?" || {
		shell::logger::info "Aborted"
		return "$RETURN_SUCCESS"
	}
	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi
	for line in "${removable[@]}"; do
		shell::nvm::uninstall ${opts[@]+"${opts[@]}"} "$line" || failed=1
	done
	return "$failed"
}

# --------------------------------------------------------------------------
# Default, aliases, .nvmrc
# --------------------------------------------------------------------------

# @description Pick the Node version new shells should start with (`nvm alias default`).
#   Besides the installed versions the list offers `lts/*` (the newest LTS, it
#   moves when you install a newer one) and `node` (the newest version installed).
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the command instead of running it.
# @exitcode 0 Done, or nothing chosen.
# @exitcode 3 nvm or fzf is not installed.
# @see shell::nvm::default
# @example
#   shell::nvm::default::fzf
#
shell::nvm::default::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick the default Node version with fzf (nvm alias default)"
		shell::logger::usage "shell::nvm::default::fzf [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::default::fzf"
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
	shell::dependency::nvm::load >/dev/null 2>&1 || {
		shell::nvm::fzf::missing
		return $?
	}

	local picked rc
	picked="$({
		printf '%-12s %s\n' 'lts/*' '(the newest LTS installed; follows new installs)'
		printf '%-12s %s\n' 'node' '(the newest version installed; follows new installs)'
		shell::nvm::fzf::rows::installed
	} | shell::nvm::fzf::pick -p "Default Node: " -P "$(shell::nvm::fzf::preview)" -H "Enter: set as default   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac

	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi
	shell::nvm::default ${opts[@]+"${opts[@]}"} "$picked"
}

# @description Pick an installed version, then name an alias for it (`nvm alias <name> <version>`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the command instead of running it.
# @exitcode 0 Done, or nothing chosen.
# @exitcode 2 The alias name is not valid.
# @exitcode 3 nvm or fzf is not installed.
# @see shell::nvm::alias
# @example
#   shell::nvm::alias::fzf
#
shell::nvm::alias::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick a Node version with fzf, then name an alias for it"
		shell::logger::usage "shell::nvm::alias::fzf [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::alias::fzf"
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
	shell::dependency::nvm::load >/dev/null 2>&1 || {
		shell::nvm::fzf::missing
		return $?
	}

	local picked rc name
	picked="$(shell::nvm::fzf::rows::installed | shell::nvm::fzf::pick -p "Alias for: " -P "$(shell::nvm::fzf::preview)" \
		-H "Enter: choose this version   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_EMPTY")
		shell::logger::info "No Node version is installed"
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac

	name="$(shell::ask::text "Alias name for $picked?")" || return "$RETURN_SUCCESS"
	if ! shell::nvm::alias::valid "$name"; then
		shell::logger::error "Invalid alias name: '$name' (letters, digits, . _ / -)"
		return "$RETURN_INVALID"
	fi
	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi
	shell::nvm::alias ${opts[@]+"${opts[@]}"} "$name" "$picked"
}

# @description Pick the aliases you made and delete them (`nvm unalias`).
#   nvm's own aliases (`node`, `stable`, `lts/*` ...) are never listed.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the commands instead of running them.
# @option -y | --yes Do not ask for confirmation.
# @exitcode 0 Done, no aliases of yours, nothing chosen, or the user declined.
# @exitcode 1 A removal failed (the others were still tried).
# @exitcode 3 nvm or fzf is not installed.
# @see shell::nvm::unalias
# @example
#   shell::nvm::unalias::fzf
#
shell::nvm::unalias::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick your aliases with fzf and delete them"
		shell::logger::usage "shell::nvm::unalias::fzf [-n] [-y]"
		shell::logger::option "-y, --yes" "Do not ask for confirmation"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::unalias::fzf"
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
	shell::dependency::nvm::load >/dev/null 2>&1 || {
		shell::nvm::fzf::missing
		return $?
	}

	local picked rc line failed=0
	local -a chosen=() opts=()
	picked="$(shell::nvm::aliases::user | shell::nvm::fzf::pick -m -p "Delete alias: " -H "Tab: mark   Enter: delete   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_EMPTY")
		shell::logger::info "You have no aliases of your own"
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac

	while IFS= read -r line; do
		[ -n "$line" ] && chosen+=("$line")
	done <<EOF
$picked
EOF
	shell::nvm::fzf::confirm "$assume_yes" "Delete the alias(es) ${chosen[*]}?" || {
		shell::logger::info "Aborted"
		return "$RETURN_SUCCESS"
	}
	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi
	for line in "${chosen[@]}"; do
		shell::nvm::unalias ${opts[@]+"${opts[@]}"} "$line" || failed=1
	done
	return "$failed"
}

# @description Pick the Node version a project should use and write its `.nvmrc`.
#   The list offers the installed versions plus `lts/*` and `node`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print what would be written instead of writing it.
# @option -f | --force Overwrite an existing `.nvmrc`.
# @exitcode 0 Written, or nothing chosen.
# @exitcode 7 A `.nvmrc` exists and `--force` was not given.
# @exitcode 3 nvm or fzf is not installed.
# @see shell::nvm::nvmrc::write
# @example
#   shell::nvm::nvmrc::fzf
#
shell::nvm::nvmrc::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick the Node version of this project with fzf and write its .nvmrc"
		shell::logger::usage "shell::nvm::nvmrc::fzf [-n] [-f]"
		shell::logger::option "-f, --force" "Overwrite an existing .nvmrc"
		shell::logger::option "-n, --dry-run" "Print what would be written instead of writing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::nvmrc::fzf"
		return "$RETURN_SUCCESS"
	fi

	local -a opts=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) opts+=(-n) ;;
		-f | --force) opts+=(-f) ;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done
	shell::dependency::nvm::load >/dev/null 2>&1 || {
		shell::nvm::fzf::missing
		return $?
	}

	local picked rc
	picked="$({
		printf '%-12s %s\n' 'lts/*' '(always the newest LTS)'
		printf '%-12s %s\n' 'node' '(always the newest release)'
		shell::nvm::fzf::rows::installed
	} | shell::nvm::fzf::pick -p ".nvmrc: " -P "$(shell::nvm::fzf::preview)" -H "Enter: pin this version   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac
	shell::nvm::nvmrc::write ${opts[@]+"${opts[@]}"} "$picked"
}

# --------------------------------------------------------------------------
# Run with a chosen version, move packages
# --------------------------------------------------------------------------

# @internal
# @description Shared body of shell::nvm::exec::fzf and shell::nvm::run::fzf: pick a
#   version, then run `nvm exec` / `nvm run` with the caller's arguments.
# @arg $1 string `exec` or `run`.
# @arg $@ string Options (`-n`) and then the command (exec) or node arguments (run).
# @exitcode 0 Done, or nothing chosen.
# @exitcode 2 No command was given.
# @exitcode 3 nvm or fzf is not installed.
# @exitcode N Exit status of the command.
shell::nvm::fzf::with_version() {
	local action="${1-}"
	shift

	local dry_run="false"
	local -a opts=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run)
			dry_run="true"
			shift
			;;
		--silent)
			opts+=(--silent)
			shift
			;;
		*) break ;;
		esac
	done
	if [ "$#" -eq 0 ]; then
		shell::logger::error "Give what to run after the options, e.g. shell::nvm::${action}::fzf npm test"
		return "$RETURN_INVALID"
	fi
	shell::dependency::nvm::load >/dev/null 2>&1 || {
		shell::nvm::fzf::missing
		return $?
	}

	local picked rc
	picked="$(shell::nvm::fzf::rows::installed | shell::nvm::fzf::pick -p "Node for ${action}: " -P "$(shell::nvm::fzf::preview)" \
		-H "Enter: run with this version   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_EMPTY")
		shell::logger::info "No Node version is installed"
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac

	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi
	"shell::nvm::${action}" ${opts[@]+"${opts[@]}"} "$picked" "$@"
}

# @description Pick an installed Node version and run a command with it (`nvm exec`).
#   Put the options (`-n`, `--silent`) first; everything after them is the command,
#   passed untouched.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the command instead of running it.
# @option --silent Print nothing of nvm's own.
# @arg $@ string The command and its arguments, e.g. `npm test`.
# @exitcode 0 Done, or nothing chosen.
# @exitcode 2 No command was given.
# @exitcode 3 nvm or fzf is not installed.
# @exitcode N Exit status of the command.
# @see shell::nvm::exec
# @example
#   shell::nvm::exec::fzf npm test
#
shell::nvm::exec::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick a Node version with fzf and run a command with it (nvm exec)"
		shell::logger::usage "shell::nvm::exec::fzf [-n] [--silent] <command> [<arguments>...]"
		shell::logger::item "command" "What to run, passed untouched"
		shell::logger::option "--silent" "Print nothing of nvm's own"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::exec::fzf npm test"
		return "$RETURN_SUCCESS"
	fi
	shell::nvm::fzf::with_version exec "$@"
}

# @description Pick an installed Node version and run `node` with it (`nvm run`).
#   Put the options (`-n`, `--silent`) first; everything after them goes to node.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the command instead of running it.
# @option --silent Print nothing of nvm's own.
# @arg $@ string Arguments for node, e.g. `app.js`.
# @exitcode 0 Done, or nothing chosen.
# @exitcode 2 No argument was given.
# @exitcode 3 nvm or fzf is not installed.
# @exitcode N Exit status of node.
# @see shell::nvm::run
# @example
#   shell::nvm::run::fzf app.js
#
shell::nvm::run::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick a Node version with fzf and run node with it (nvm run)"
		shell::logger::usage "shell::nvm::run::fzf [-n] [--silent] <node arguments>..."
		shell::logger::item "node arguments" "Passed to node untouched, e.g. app.js"
		shell::logger::option "--silent" "Print nothing of nvm's own"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::run::fzf app.js"
		return "$RETURN_SUCCESS"
	fi
	shell::nvm::fzf::with_version run "$@"
}

# @description Install a newer Node and carry your global npm packages over.
#   Pick the version to move **from** (the preview shows its global packages),
#   then what to move **to**: the latest LTS, the latest release, or a version
#   from the list. It runs `nvm install <target> --reinstall-packages-from=<from>`.
#   The old version is not removed: do that afterwards with `unused::fzf`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the install command instead of running it.
# @exitcode 0 Done, or nothing chosen.
# @exitcode 3 nvm or fzf is not installed.
# @see shell::nvm::install
# @see shell::nvm::unused::fzf
# @example
#   shell::nvm::migrate::fzf
#
shell::nvm::migrate::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Install a newer Node and carry your global npm packages over"
		shell::logger::usage "shell::nvm::migrate::fzf [-n]"
		shell::logger::option "-n, --dry-run" "Print the install command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::migrate::fzf"
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
	shell::dependency::nvm::load >/dev/null 2>&1 || {
		shell::nvm::fzf::missing
		return $?
	}

	local from rc target choice
	from="$(shell::nvm::fzf::rows::installed | shell::nvm::fzf::pick -p "Move packages from: " -P "$(shell::nvm::fzf::preview)" \
		-H "Enter: take the global npm packages of this version   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_EMPTY")
		shell::logger::info "No Node version is installed"
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac

	choice="$(shell::ask::option::back --prompt "Install and move to: " "Latest LTS" "Latest release" "A version from the list")"
	rc=$?
	case "$rc" in
	0) ;;
	*) return "$RETURN_SUCCESS" ;;
	esac

	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi
	case "$choice" in
	"Latest LTS")
		shell::nvm::install ${opts[@]+"${opts[@]}"} --reinstall-packages-from "$from" --lts
		;;
	"Latest release")
		shell::nvm::install ${opts[@]+"${opts[@]}"} --reinstall-packages-from "$from" node
		;;
	*)
		target="$(shell::nvm::versions::remote | shell::nvm::fzf::pick -p "Move to: " -H "Enter: install this version   ESC: cancel")"
		rc=$?
		if [ "$rc" -ne 0 ]; then
			return "$RETURN_SUCCESS"
		fi
		shell::nvm::install ${opts[@]+"${opts[@]}"} --reinstall-packages-from "$from" "$target"
		;;
	esac
}

# @description Pick a version and copy its global npm packages into the one in use
#   (`nvm reinstall-packages`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the command instead of running it.
# @exitcode 0 Done, or nothing chosen.
# @exitcode 3 nvm or fzf is not installed.
# @see shell::nvm::reinstall_packages
# @example
#   shell::nvm::reinstall_packages::fzf
#
shell::nvm::reinstall_packages::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick a version with fzf and copy its global npm packages into this one"
		shell::logger::usage "shell::nvm::reinstall_packages::fzf [-n]"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::reinstall_packages::fzf"
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
	shell::dependency::nvm::load >/dev/null 2>&1 || {
		shell::nvm::fzf::missing
		return $?
	}

	local picked rc current
	current="$(shell::nvm::query current)"
	picked="$(shell::nvm::fzf::rows::installed | awk -v c="$current" '$1 != c' |
		shell::nvm::fzf::pick -p "Copy packages from: " -P "$(shell::nvm::fzf::preview)" \
			-H "Into the version in use (${current:-none}).   Enter: copy   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_EMPTY")
		shell::logger::info "No other Node version is installed"
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac

	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi
	shell::nvm::reinstall_packages ${opts[@]+"${opts[@]}"} "$picked"
}

# --------------------------------------------------------------------------
# Disk usage and unused versions
# --------------------------------------------------------------------------

# @description Show which installed Node versions take the most disk space.
#   Measures each version's directory in `NVM_DIR`, biggest first, and the download cache.
# @option -h | --help Show help and return.
# @arg $1 integer How many versions to show (default: 20).
# @stdout One line per version: size, version. Then the cache.
# @exitcode 0 Success.
# @exitcode 2 The count is not a positive integer.
# @exitcode 3 nvm is not installed.
# @see shell::nvm::unused::fzf
# @see shell::nvm::cache
# @example
#   shell::nvm::size
#   shell::nvm::size 5
#
shell::nvm::size() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show the installed Node versions that take the most disk space"
		shell::logger::usage "shell::nvm::size [count]"
		shell::logger::item "count" "How many versions to show (default 20)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::nvm::size 5"
		return "$RETURN_SUCCESS"
	fi

	local count="${1:-20}"
	if [ "$#" -gt 1 ]; then
		shell::logger::error "Only one count can be given"
		return "$RETURN_INVALID"
	fi
	case "$count" in
	'' | *[!0-9]* | 0)
		shell::logger::error "Count must be a positive integer"
		return "$RETURN_INVALID"
		;;
	esac
	shell::dependency::nvm::load >/dev/null 2>&1 || {
		shell::nvm::fzf::missing
		return $?
	}

	local v kb cache_dir cache_kb installed
	installed="$(shell::nvm::versions::installed)"
	if [ -z "$installed" ]; then
		shell::logger::info "No Node version is installed"
		return "$RETURN_SUCCESS"
	fi
	while IFS= read -r v; do
		[ -n "$v" ] || continue
		kb="$(du -sk "${NVM_DIR-}/versions/node/$v" 2>/dev/null | awk '{ print $1 }')"
		printf '%s\t\t%s\n' "$v" "${kb:-0}"
	done <<EOF | sort -t "$(printf '\t')" -k3,3nr | head -n "$count" | shell::nvm::size::format | awk -F'\t' '{ printf "%8s  %s\n", $3, $1 }'
$installed
EOF
	cache_dir="$(shell::nvm::query cache dir)"
	if [ -n "$cache_dir" ] && [ -d "$cache_dir" ]; then
		cache_kb="$(du -sk "$cache_dir" 2>/dev/null | awk '{ print $1 }')"
		printf '%s\t\t%s\n' "download cache" "${cache_kb:-0}" | shell::nvm::size::format | awk -F'\t' '{ printf "%8s  %s\n", $3, $1 }'
	fi
}

# @internal
# @description Find the installed Node versions that nothing refers to and print them,
#   one per line, as `version<TAB>reason<TAB>size-in-KB<TAB>why`. The reason is
#   `superseded` or `unreferenced`. See the file header for what is kept.
# @option -s | --superseded Only the superseded ones.
# @option -p | --projects Directory to search for `.nvmrc` files (repeatable; depth 4).
# @stdout The candidates, tab separated.
# @exitcode 0 Success (possibly nothing found).
# @exitcode 2 Invalid option.
# @exitcode 3 nvm is not installed.
# @example
#   shell::nvm::unused::scan --projects ~/code | cut -f1
#
shell::nvm::unused::scan() {
	local only_superseded="false"
	local -a roots=()
	local root
	for root in ${SHELL_NVM_PROJECT_ROOTS-}; do
		roots+=("$root")
	done
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-s | --superseded) only_superseded="true" ;;
		-p | --projects)
			if [ "$#" -lt 2 ]; then
				shell::logger::error "Option $1 requires a value"
				return "$RETURN_INVALID"
			fi
			roots+=("$2")
			shift
			;;
		*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done

	shell::dependency::nvm::load >/dev/null 2>&1 || {
		shell::nvm::fzf::missing
		return $?
	}

	local installed current kept="" aliases rc_file wanted resolved line v reason size why name
	installed="$(shell::nvm::versions::installed)"
	if [ -z "$installed" ]; then
		return "$RETURN_SUCCESS"
	fi
	current="$(shell::nvm::query current)"
	kept=" $current "

	# Every version an alias resolves to ("name -> target (-> v20.11.1 *)").
	aliases="$(shell::nvm::query alias --no-colors)"
	kept="$kept$(printf '%s\n' "$aliases" | awk '
        {
            p = index($0, "(-> v")
            if (p == 0) next
            s = substr($0, p + 4)
            sub(/[ )].*$/, "", s)
            printf " %s ", s
        }')"

	# The .nvmrc of the current project, and of the project directories named.
	if rc_file="$(shell::nvm::nvmrc::find)"; then
		wanted="$(shell::nvm::nvmrc::read 2>/dev/null)"
		if [ -n "$wanted" ]; then
			resolved="$(shell::nvm::query version "$wanted")"
			kept="$kept $resolved "
		fi
	fi
	for root in ${roots[@]+"${roots[@]}"}; do
		[ -d "$root" ] || continue
		while IFS= read -r rc_file; do
			[ -n "$rc_file" ] || continue
			wanted="$(head -n 1 "$rc_file" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
			if [ -n "$wanted" ] && shell::nvm::version::valid "$wanted"; then
				resolved="$(shell::nvm::query version "$wanted")"
				kept="$kept $resolved "
			fi
		done <<EOF
$(find "$root" -maxdepth 4 -name .nvmrc -type f -not -path '*/node_modules/*' 2>/dev/null)
EOF
	done

	# Oldest first, as nvm lists them: a version is superseded when a later one has the same major.
	while IFS=$'\t' read -r v reason; do
		[ -n "$v" ] || continue
		case "$kept" in
		*" $v "*) continue ;;
		esac
		if [ "$only_superseded" = "true" ] && [ "$reason" != "superseded" ]; then
			continue
		fi
		if [ "$reason" = "superseded" ]; then
			why="a newer ${v%%.*} release is installed"
		else
			why="no alias, .nvmrc or open shell uses it"
		fi
		size="$(du -sk "${NVM_DIR-}/versions/node/$v" 2>/dev/null | awk '{ print $1 }')"
		printf '%s\t%s\t%s\t%s\n' "$v" "$reason" "${size:-0}" "$why"
	done <<EOF
$(printf '%s\n' "$installed" | awk '
        {
            major = $1
            sub(/^v/, "", major)
            sub(/\..*/, "", major)
            ord[NR] = $1
            mj[NR] = major
            last[major] = NR
        }
        END {
            for (i = 1; i <= NR; i++) printf "%s\t%s\n", ord[i], (i < last[mj[i]] ? "superseded" : "unreferenced")
        }')
EOF
	return "$RETURN_SUCCESS"
}

# @description List the installed Node versions that nothing refers to.
#   Read-only. A version is kept when it is the one in use, the target of any
#   alias (`default`, `lts/*`, `node` and yours), or asked for by the `.nvmrc` of
#   the current project or of the directories given with `--projects`. The rest is
#   `superseded` (a newer release of the same major is installed) or
#   `unreferenced` (the newest of its major, but nothing uses it).
# @option -h | --help Show help and return.
# @option -s | --superseded Only the superseded versions.
# @option -p | --projects Directory whose projects' `.nvmrc` files keep a version (repeatable).
# @option -q | --names Print only the versions, one per line (for scripts).
# @stdout A table: version, reason, size, why. With `--names`, just the versions.
# @exitcode 0 Success, even when nothing was found.
# @exitcode 2 Invalid option.
# @exitcode 3 nvm is not installed.
# @see shell::nvm::unused::fzf
# @example
#   shell::nvm::unused
#   shell::nvm::unused --superseded --projects ~/code
#   shell::nvm::unused --names | xargs -n1 shell::nvm::uninstall -n
#
shell::nvm::unused() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List installed Node versions that nothing refers to"
		shell::logger::usage "shell::nvm::unused [-s] [-p <dir>]... [-q]"
		shell::logger::option "-s, --superseded" "Only versions with a newer release of the same major installed"
		shell::logger::option "-p, --projects <dir>" "Keep versions that .nvmrc files under <dir> ask for (repeatable)"
		shell::logger::option "-q, --names" "Versions only, one per line"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "Read-only. Remove what it finds with shell::nvm::unused::fzf."
		shell::logger::example "shell::nvm::unused --superseded --projects ~/code"
		return "$RETURN_SUCCESS"
	fi

	local names_only="false"
	local -a scan_args=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-q | --names) names_only="true" ;;
		-p | --projects)
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
	found="$(shell::nvm::unused::scan ${scan_args[@]+"${scan_args[@]}"})"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		return "$rc"
	fi
	if [ -z "$found" ]; then
		shell::logger::success "No unused Node versions found"
		return "$RETURN_SUCCESS"
	fi
	if [ "$names_only" = "true" ]; then
		printf '%s\n' "$found" | cut -f1
		return "$RETURN_SUCCESS"
	fi
	{
		printf 'VERSION\tREASON\tSIZE\tWHY\n'
		printf '%s\n' "$found" | sort -t "$(printf '\t')" -k3,3nr | shell::nvm::size::format
	} | awk -F'\t' '{ printf "%-12s %-13s %8s  %s\n", $1, $2, $3, $4 }'
}

# @description Find unused Node versions, pick the ones to remove, and remove them.
#   Runs shell::nvm::unused::scan, lists the candidates (version, reason, size,
#   why) with a preview of each version's global npm packages, and lets you mark
#   the ones to uninstall. After a confirmation it runs `nvm uninstall` on each.
#   Nothing is pre-selected and nothing is removed without your confirmation.
# @option -h | --help Show help and return.
# @option -n | --dry-run Choose, but print the uninstall commands instead of running them.
# @option -s | --superseded Only the superseded versions.
# @option -p | --projects Directory whose projects' `.nvmrc` files keep a version (repeatable).
# @option -y | --yes Do not ask for confirmation.
# @exitcode 0 Done, nothing found, nothing chosen, or the user declined.
# @exitcode 1 An uninstall failed (the others were still tried).
# @exitcode 3 nvm or fzf is not installed.
# @see shell::nvm::unused
# @see shell::nvm::uninstall
# @example
#   shell::nvm::unused::fzf
#   shell::nvm::unused::fzf --superseded
#
shell::nvm::unused::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Find unused Node versions, pick some with fzf and uninstall them"
		shell::logger::usage "shell::nvm::unused::fzf [-n] [-s] [-p <dir>]... [-y]"
		shell::logger::option "-s, --superseded" "Only versions with a newer release of the same major installed"
		shell::logger::option "-p, --projects <dir>" "Keep versions that .nvmrc files under <dir> ask for (repeatable)"
		shell::logger::option "-y, --yes" "Do not ask for confirmation"
		shell::logger::option "-n, --dry-run" "Print the uninstall commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "Nothing is pre-selected; nothing is removed without your confirmation."
		shell::logger::example "shell::nvm::unused::fzf --superseded"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" assume_yes="false"
	local -a scan_args=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-y | --yes) assume_yes="true" ;;
		-p | --projects)
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

	local found rc picked line failed=0
	local -a chosen=() opts=()
	found="$(shell::nvm::unused::scan ${scan_args[@]+"${scan_args[@]}"})"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		return "$rc"
	fi
	if [ -z "$found" ]; then
		shell::logger::success "No unused Node versions found"
		return "$RETURN_SUCCESS"
	fi

	picked="$(printf '%s\n' "$found" | sort -t "$(printf '\t')" -k3,3nr | shell::nvm::size::format |
		awk -F'\t' '{ printf "%-12s %-13s %8s  %s\n", $1, $2, $3, $4 }' |
		shell::nvm::fzf::pick -m -p "Remove Node: " -P "$(shell::nvm::fzf::preview)" \
			-H "Tab: mark   Ctrl-A: mark all   Enter: uninstall   ESC: cancel")"
	rc=$?
	case "$rc" in
	0) ;;
	"$RETURN_CANCELLED") return "$RETURN_SUCCESS" ;;
	*) return "$rc" ;;
	esac

	while IFS= read -r line; do
		[ -n "$line" ] && chosen+=("$line")
	done <<EOF
$picked
EOF
	shell::nvm::fzf::confirm "$assume_yes" "Uninstall ${chosen[*]}?" || {
		shell::logger::info "Aborted"
		return "$RETURN_SUCCESS"
	}
	if [ "$dry_run" = "true" ]; then
		opts+=(-n)
	fi
	for line in "${chosen[@]}"; do
		shell::nvm::uninstall ${opts[@]+"${opts[@]}"} "$line" || failed=1
	done
	return "$failed"
}

# --------------------------------------------------------------------------
# The menu
# --------------------------------------------------------------------------

# @description The nvm control panel: one fzf menu for everything above.
#   Switch, install, uninstall, set the default, aliases, `.nvmrc`, automatic
#   switching, moving global packages, finding unused versions, disk usage, the
#   download cache and the check-up. Each entry opens its own picker; ESC or
#   "← Back" in the menu leaves. Runs in the current shell, so "Switch" changes
#   this terminal.
# @option -h | --help Show help and return.
# @option -n | --dry-run Pass `--dry-run` to every entry: choices are made but nothing is changed.
# @exitcode 0 The user left the menu.
# @exitcode 3 nvm or fzf is not installed.
# @see shell::nvm::use::fzf
# @see shell::nvm::unused::fzf
# @example
#   shell::nvm::manage
#   shell::nvm::manage -n
#
shell::nvm::manage() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "nvm control panel: switch, install, uninstall, aliases, .nvmrc, unused versions ..."
		shell::logger::usage "shell::nvm::manage [-n]"
		shell::logger::option "-n, --dry-run" "Print the changing commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "Runs in the current shell, so 'Switch' changes this terminal."
		shell::logger::example "shell::nvm::manage"
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
	shell::dependency::nvm::load >/dev/null 2>&1 || {
		shell::nvm::fzf::missing
		return $?
	}

	local choice rc
	while true; do
		choice="$(shell::ask::option::back --prompt "nvm: " \
			"Switch Node version" \
			"Install Node versions" \
			"Install the latest LTS" \
			"Uninstall Node versions" \
			"Set the default version" \
			"Create an alias" \
			"Delete aliases" \
			"Pin this project (.nvmrc)" \
			"Move global packages to a newer Node" \
			"Find unused Node versions" \
			"Disk usage" \
			"Clear the download cache" \
			"Automatic switching on" \
			"Automatic switching off" \
			"Health check (doctor)")"
		rc=$?
		case "$rc" in
		0) ;;
		*) return "$RETURN_SUCCESS" ;;
		esac

		case "$choice" in
		"Switch Node version") shell::nvm::use::fzf ${opts[@]+"${opts[@]}"} ;;
		"Install Node versions") shell::nvm::install::fzf ${opts[@]+"${opts[@]}"} ;;
		"Install the latest LTS") shell::nvm::install ${opts[@]+"${opts[@]}"} --lts ;;
		"Uninstall Node versions") shell::nvm::uninstall::fzf ${opts[@]+"${opts[@]}"} ;;
		"Set the default version") shell::nvm::default::fzf ${opts[@]+"${opts[@]}"} ;;
		"Create an alias") shell::nvm::alias::fzf ${opts[@]+"${opts[@]}"} ;;
		"Delete aliases") shell::nvm::unalias::fzf ${opts[@]+"${opts[@]}"} ;;
		"Pin this project (.nvmrc)") shell::nvm::nvmrc::fzf ${opts[@]+"${opts[@]}"} ;;
		"Move global packages to a newer Node") shell::nvm::migrate::fzf ${opts[@]+"${opts[@]}"} ;;
		"Find unused Node versions") shell::nvm::unused::fzf ${opts[@]+"${opts[@]}"} ;;
		"Disk usage") shell::nvm::size ;;
		"Clear the download cache") shell::nvm::cache ${opts[@]+"${opts[@]}"} clear ;;
		"Automatic switching on") shell::nvm::autouse::on ;;
		"Automatic switching off") shell::nvm::autouse::off ;;
		"Health check (doctor)") shell::nvm::doctor ;;
		esac
	done
}
