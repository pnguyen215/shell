#!/usr/bin/env bash
# @file lib/permission.sh
# @brief File permission helpers: set, secure, unlock, explain.

# @description Restrict a path to its owner: 600 for files, 700 for directories.
#   Use this for anything holding secrets (tokens, keys, credentials). It is
#   the safe replacement for the old habit of `chmod 777` on config files.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string File or directory.
# @exitcode 0 Permissions were applied (or already correct, or dry-run printed).
# @exitcode 1 chmod failed.
# @exitcode 2 No path given.
# @exitcode 3 The path does not exist.
# @example
#   shell::permission::secure "$SHELL_KEY_FILE"
#
shell::permission::secure() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Restrict a path to its owner (600 file / 700 directory)"
		shell::logger::usage "shell::permission::secure [-n] <path>"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::permission::secure \"\$HOME/.shell-config/key.conf\""
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local target="${1-}"
	if [ -z "$target" ]; then
		shell::logger::error "Usage: shell::permission::secure [-n] <path>"
		return "$RETURN_INVALID"
	fi
	if [ ! -e "$target" ]; then
		shell::logger::error "Target '$target' does not exist."
		return "$RETURN_NOT_FOUND"
	fi

	local mode=600
	[ -d "$target" ] && mode=700

	# Skip the syscall when the mode is already right.
	if [ "$(shell::fs::stat mode "$target")" = "$mode" ]; then
		return "$RETURN_SUCCESS"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::exec::command -n chmod "$mode" "$target"
		return "$RETURN_SUCCESS"
	fi
	chmod "$mode" "$target" || return "$RETURN_FAILURE"
}

# @description Grant read/write/execute to everyone (`chmod -R 777`). **Dangerous.**
#   Kept for explicit, deliberate use (e.g. a throw-away shared scratch dir).
#   The library itself no longer calls it on configuration files: use
#   shell::permission::secure for anything sensitive.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --sudo Run chmod through sudo.
# @arg $1 string File or directory.
# @exitcode 0 Permissions applied, already 777, or dry-run printed.
# @exitcode 1 chmod failed.
# @exitcode 2 No path given.
# @exitcode 3 The path does not exist.
# @example
#   shell::permission::unlock ./shared-scratch
#
shell::permission::unlock() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Grant rwx to everyone (chmod -R 777). Dangerous."
		shell::logger::usage "shell::permission::unlock [-n] [--sudo] <path>"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "--sudo" "Run chmod with sudo"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "Prefer shell::permission::secure for files holding secrets."
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" use_sudo="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		--sudo) use_sudo="true" ;;
		*) break ;;
		esac
		shift
	done

	local target="${1-}"
	if [ -z "$target" ]; then
		shell::logger::error "Usage: shell::permission::unlock [-n] [--sudo] <path>"
		return "$RETURN_INVALID"
	fi
	if [ ! -e "$target" ]; then
		shell::logger::error "Target '$target' does not exist."
		return "$RETURN_NOT_FOUND"
	fi

	local -a cmd=(chmod -R 777 "$target")
	[ "$use_sudo" = "true" ] && cmd=(sudo chmod -R 777 "$target")

	if [ "$dry_run" = "true" ]; then
		shell::exec::command -n "${cmd[@]}"
		return "$RETURN_SUCCESS"
	fi

	if [ "$(shell::fs::stat mode "$target")" = "777" ]; then
		return "$RETURN_SUCCESS"
	fi
	"${cmd[@]}" || return "$RETURN_FAILURE"
	shell::logger::debug "Permissions set to rwxrwxrwx for '$target'"
}

# @description Set permissions from `owner=`, `group=` and `others=` descriptions.
#   Each description is a comma-separated mix of `read`, `write`, `execute` (or
#   `none`). Unspecified classes get no permission.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string File or directory.
# @arg $@ string One or more of owner=<perms> group=<perms> others=<perms>.
# @exitcode 0 Permissions applied (or dry-run printed).
# @exitcode 1 chmod failed.
# @exitcode 2 Wrong arguments or an unknown class.
# @exitcode 3 The target does not exist.
# @example
#   shell::permission::set ./run.sh owner=read,write,execute group=read,execute others=read
#
shell::permission::set() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Set permissions using owner=/group=/others= descriptions"
		shell::logger::usage "shell::permission::set [-n] <target> owner=<p> [group=<p>] [others=<p>]"
		shell::logger::item "<p>" "Comma-separated read,write,execute (or none)"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::permission::set ./run.sh owner=read,write,execute group=read,execute others=read"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if [ "$#" -lt 2 ]; then
		shell::logger::error "Usage: shell::permission::set [-n] <target> owner=... [group=...] [others=...]"
		return "$RETURN_INVALID"
	fi

	local target="$1"
	shift
	if [ ! -e "$target" ]; then
		shell::logger::error "Target '$target' does not exist."
		return "$RETURN_NOT_FOUND"
	fi

	local owner_bits=0 group_bits=0 others_bits=0
	local arg klass perms bits
	for arg in "$@"; do
		klass="${arg%%=*}"
		perms="${arg#*=}"

		# Add r=4, w=2, x=1 for each word present.
		bits=0
		case "$perms" in *read*) bits=$((bits + 4)) ;; esac
		case "$perms" in *write*) bits=$((bits + 2)) ;; esac
		case "$perms" in *execute*) bits=$((bits + 1)) ;; esac

		case "$klass" in
		owner) owner_bits="$bits" ;;
		group) group_bits="$bits" ;;
		others) others_bits="$bits" ;;
		*)
			shell::logger::error "Unknown permission class '$klass'. Use owner=..., group=..., others=..."
			return "$RETURN_INVALID"
			;;
		esac
	done

	local mode="${owner_bits}${group_bits}${others_bits}"
	if [ "$dry_run" = "true" ]; then
		shell::exec::command -n chmod "$mode" "$target"
		return "$RETURN_SUCCESS"
	fi

	shell::exec::command chmod "$mode" "$target" || return "$RETURN_FAILURE"
	shell::logger::success "Permissions set to $mode for '$target'"
}

# @description Pick owner/group/others permissions with fzf and apply them.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string File or directory.
# @exitcode 0 Permissions applied (or dry-run printed).
# @exitcode 2 No target given.
# @exitcode 3 The target does not exist.
# @exitcode 9 The user cancelled a selection.
# @see shell::permission::set
shell::permission::set::fzf() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Choose permissions interactively (fzf) and apply them"
		shell::logger::usage "shell::permission::set::fzf [-n] <target>"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local target="${1-}"
	if [ -z "$target" ]; then
		shell::logger::error "Usage: shell::permission::set::fzf [-n] <target>"
		return "$RETURN_INVALID"
	fi
	if [ ! -e "$target" ]; then
		shell::logger::error "Target '$target' does not exist."
		return "$RETURN_NOT_FOUND"
	fi

	local choices="none
read
write
execute
read,write
read,execute
write,execute
read,write,execute"

	local owner group others
	owner="$(printf '%s\n' "$choices" | shell::fzf::select --prompt="Select owner permissions: ")" || return "$RETURN_CANCELLED"
	group="$(printf '%s\n' "$choices" | shell::fzf::select --prompt="Select group permissions: ")" || return "$RETURN_CANCELLED"
	others="$(printf '%s\n' "$choices" | shell::fzf::select --prompt="Select others permissions: ")" || return "$RETURN_CANCELLED"

	local -a flag=()
	[ "$dry_run" = "true" ] && flag=(-n)
	shell::permission::set ${flag[@]+"${flag[@]}"} "$target" "owner=$owner" "group=$group" "others=$others"
}

# @description Explain a permission string in plain language.
#   Reads the permissions of a file, or analyses a literal string such as
#   `-rwxr-xr-x`, and prints owner/group/others meaning, the octal value and a
#   short developer-oriented hint.
# @option -h | --help Show help and return.
# @option --file <path> Use the permissions of this file.
# @option --debug Print the parsed components to stderr.
# @arg $1 string Permission string like -rwxr-xr-x (default: -rw-r--r--).
# @stdout The explanation.
# @exitcode 0 Success.
# @exitcode 1 The permissions could not be read.
# @exitcode 2 Bad arguments or malformed permission string.
# @exitcode 3 The file does not exist.
# @example
#   shell::permission::analyze -rwxr-xr-x
#   shell::permission::analyze --file ./deploy.sh
#
shell::permission::analyze() {
	local permission_string="" file_path="" debug="false"

	while [ "$#" -gt 0 ]; do
		case "$1" in
		-h | --help)
			shell::logger::reset_options
			shell::logger::info "Explain a permission string or a file's permissions"
			shell::logger::usage "shell::permission::analyze [--file <path>] [--debug] [permission_string]"
			shell::logger::option "--file <path>" "Use the permissions of this file"
			shell::logger::option "--debug" "Print parsed components to stderr"
			shell::logger::option "-h, --help" "Display this help message"
			shell::logger::example "shell::permission::analyze -rwxr-xr-x"
			return "$RETURN_SUCCESS"
			;;
		--file)
			if [ -z "${2-}" ]; then
				shell::logger::error "--file requires a path."
				return "$RETURN_INVALID"
			fi
			file_path="$2"
			shift 2
			;;
		--debug)
			debug="true"
			shift
			;;
		*)
			if [ -n "$permission_string" ]; then
				shell::logger::error "Multiple permission strings provided."
				return "$RETURN_INVALID"
			fi
			permission_string="$1"
			shift
			;;
		esac
	done

	if [ -n "$file_path" ]; then
		if [ ! -e "$file_path" ]; then
			shell::logger::error "File '$file_path' does not exist."
			return "$RETURN_NOT_FOUND"
		fi
		permission_string="$(shell::fs::stat perms "$file_path")" || {
			shell::logger::error "Failed to get permissions for '$file_path'."
			return "$RETURN_FAILURE"
		}
	fi
	[ -z "$permission_string" ] && permission_string="-rw-r--r--"

	# Accept "-" (file), "d" (dir) or "l" (symlink) followed by 9 permission chars.
	# (s/S/t/T special bits are matched in the execute slot as well.)
	if ! printf '%s' "$permission_string" | grep -Eq '^[-dl]([-r][-w][-xsStT]){3}$'; then
		shell::logger::error "Invalid permission string '$permission_string'. Expected e.g. -rwxr-xr-x."
		return "$RETURN_INVALID"
	fi

	local file_type="${permission_string:0:1}"
	local owner="${permission_string:1:3}"
	local group="${permission_string:4:3}"
	local others="${permission_string:7:3}"

	local type_desc
	case "$file_type" in
	-) type_desc="regular file" ;;
	d) type_desc="directory" ;;
	l) type_desc="symbolic link" ;;
	esac

	# Describe one rwx triplet and compute its octal digit; writes two globals
	# to avoid subshells (kept local to this function through the names below).
	local owner_desc group_desc others_desc owner_bits group_bits others_bits
	shell::permission::describe "$owner"
	owner_desc="$_SHELL_PERM_DESC"
	owner_bits="$_SHELL_PERM_BITS"
	shell::permission::describe "$group"
	group_desc="$_SHELL_PERM_DESC"
	group_bits="$_SHELL_PERM_BITS"
	shell::permission::describe "$others"
	others_desc="$_SHELL_PERM_DESC"
	others_bits="$_SHELL_PERM_BITS"

	local octal="${owner_bits}${group_bits}${others_bits}"

	local hint
	if [ "$permission_string" = "-rwxr-xr-x" ]; then
		hint="Typical for executable scripts and binaries (755): the owner can edit and run; everyone else can read and run."
	elif [ "$permission_string" = "-rw-r--r--" ]; then
		hint="Typical for config files and source code (644): the owner can edit; everyone else can only read."
	elif [ "${others:1:1}" = "w" ]; then
		hint="WARNING: 'others' can write. Any user on the machine can modify this; avoid it outside throw-away directories."
	elif [ "$file_type" = "d" ] && [ "$owner" = "rwx" ]; then
		hint="The owner has full control. Execute permission on a directory is what allows entering and listing it."
	else
		hint="Ensure scripts are executable (chmod +x) and restrict write access to what is really needed."
	fi

	shell::logger::info "Permission explanation for ${permission_string}"
	printf '\n'
	printf 'File type : %s (%s)\n' "$file_type" "$type_desc"
	printf 'Owner     : %s -> %s\n' "$owner" "$owner_desc"
	printf 'Group     : %s -> %s\n' "$group" "$group_desc"
	printf 'Others    : %s -> %s\n' "$others" "$others_desc"
	printf 'Octal     : %s (chmod %s)\n' "$octal" "$octal"
	printf '\nHint      : %s\n' "$hint"

	if [ "$debug" = "true" ]; then
		printf 'Debug: type=%s owner=%s group=%s others=%s octal=%s\n' \
			"$file_type" "$owner" "$group" "$others" "$octal" >&2
	fi
	return "$RETURN_SUCCESS"
}

# @internal
# @description Describe one `rwx` triplet in words and compute its octal digit.
# @arg $1 string Three characters such as `r-x`.
# @set _SHELL_PERM_DESC string Human-readable description, e.g. "read, execute".
# @set _SHELL_PERM_BITS integer Octal digit 0-7.
# @exitcode 0 Always.
shell::permission::describe() {
	local triplet="$1"
	local words="" bits=0

	case "${triplet:0:1}" in r)
		words="read"
		bits=$((bits + 4))
		;;
	esac
	case "${triplet:1:1}" in w)
		words="${words:+$words, }write"
		bits=$((bits + 2))
		;;
	esac
	# x, s and t all imply the execute bit; S and T do not.
	case "${triplet:2:1}" in x | s | t)
		words="${words:+$words, }execute"
		bits=$((bits + 1))
		;;
	esac

	_SHELL_PERM_DESC="${words:-no permissions}"
	_SHELL_PERM_BITS="$bits"
}
