#!/usr/bin/env bash
# @file lib/fs.sh
# @brief Portable filesystem helpers (create, copy, move, remove, extract, list, browse).
# @description
#   Differences from the previous common.sh implementation:
#   * No implicit `sudo`. Privilege escalation is opt-in (`--sudo`), because
#     creating files under $HOME with sudo leaves them root-owned.
#   * No implicit `chmod 777`. New files/dirs use the caller's umask, or 600/700
#     with `--private` (used for anything holding secrets).
#   * Destructive operations refuse obviously dangerous targets (`/`, `$HOME`...).
#   * GNU/BSD (Linux/macOS) differences (`sed -i`, `stat`) are hidden here.

# @description Edit a file in place with sed, portably.
#   GNU sed (`sed -i`) and BSD sed (`sed -i ''`) disagree on how the in-place
#   flag takes its optional suffix. Attaching a suffix directly (`-i.bak`) is
#   understood by both, so the backup is created and then deleted.
# @arg $@ string sed arguments (scripts/options) followed by the file as the LAST argument.
# @exitcode 0 The file was edited.
# @exitcode 2 Fewer than two arguments were given.
# @exitcode 3 The target file does not exist.
# @exitcode N sed's exit status on failure.
# @example
#   shell::fs::sed_inplace 's/foo/bar/' config.txt
#   shell::fs::sed_inplace -e '/^#/d' -e 's/ *$//' config.txt
#
shell::fs::sed_inplace() {
	if [ "$#" -lt 2 ]; then
		shell::logger::error "Usage: shell::fs::sed_inplace <sed-args...> <file>"
		return "$RETURN_INVALID"
	fi

	# The file is the last argument. A portable loop replaces the bash-only ${!#}.
	local file arg
	for arg in "$@"; do
		file="$arg"
	done

	if [ ! -f "$file" ]; then
		shell::logger::error "File not found: $file"
		return "$RETURN_NOT_FOUND"
	fi

	if sed -i.shellbak "$@"; then
		rm -f "${file}.shellbak"
		return "$RETURN_SUCCESS"
	fi

	local rc=$?
	rm -f "${file}.shellbak"
	return "$rc"
}

# @description Print one stat attribute of a file, portably.
#   GNU `stat -c` (Linux) and BSD `stat -f` (macOS) use unrelated format
#   strings; this hides the difference.
# @arg $1 string Attribute: mode (octal, e.g. 644), perms (e.g. -rw-r--r--), size (bytes), mtime (YYYY-MM-DD HH:MM).
# @arg $2 string File path.
# @stdout The attribute value.
# @exitcode 0 Success.
# @exitcode 2 Unknown attribute or missing path.
# @exitcode 3 The file does not exist.
# @example
#   shell::fs::stat mode ~/.ssh/id_rsa    # -> 600
#
shell::fs::stat() {
	local attribute="${1-}"
	local file="${2-}"

	if [ -z "$attribute" ] || [ -z "$file" ]; then
		shell::logger::error "Usage: shell::fs::stat <mode|perms|size|mtime> <file>"
		return "$RETURN_INVALID"
	fi
	if [ ! -e "$file" ] && [ ! -L "$file" ]; then
		return "$RETURN_NOT_FOUND"
	fi

	# Detect the flavour once: GNU stat understands --version, BSD stat does not.
	if [ -z "${_SHELL_STAT_FLAVOR-}" ]; then
		if stat --version >/dev/null 2>&1; then
			_SHELL_STAT_FLAVOR="gnu"
		else
			_SHELL_STAT_FLAVOR="bsd"
		fi
	fi

	if [ "$_SHELL_STAT_FLAVOR" = "gnu" ]; then
		case "$attribute" in
		mode) stat -c '%a' "$file" ;;
		perms) stat -c '%A' "$file" ;;
		size) stat -c '%s' "$file" ;;
		mtime) stat -c '%y' "$file" | cut -c1-16 ;;
		*) return "$RETURN_INVALID" ;;
		esac
	else
		case "$attribute" in
		mode) stat -f '%Lp' "$file" ;;
		perms) stat -f '%Sp' "$file" ;;
		size) stat -f '%z' "$file" ;;
		mtime) stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$file" ;;
		*) return "$RETURN_INVALID" ;;
		esac
	fi
}

# @description Create directories (with parents) if they do not exist.
#   Tries as the current user first. Only with `--sudo` is privilege escalation
#   used, and ownership is then handed back to the current user.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the commands instead of running them.
# @option -p | --private Create with mode 700 (owner only).
# @option --sudo Retry with sudo when the parent is not writable.
# @arg $@ string Directory paths.
# @exitcode 0 Every directory exists afterwards.
# @exitcode 1 A directory could not be created.
# @exitcode 2 No path was given.
# @example
#   shell::fs::mkdir "$HOME/.config/app"
#   shell::fs::mkdir --private "$HOME/.shell-config"
#
shell::fs::mkdir() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Create directories (with parents) if they do not exist"
		shell::logger::usage "shell::fs::mkdir [-n] [-p] [--sudo] <dir> [dir ...]"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "-p, --private" "Create with mode 700"
		shell::logger::option "--sudo" "Retry with sudo if the parent is not writable"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::fs::mkdir --private \"\$HOME/.shell-config\""
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" private="false" use_sudo="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-p | --private) private="true" ;;
		--sudo) use_sudo="true" ;;
		--)
			shift
			break
			;;
		-*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done

	if [ "$#" -eq 0 ]; then
		shell::logger::error "No directory path provided."
		return "$RETURN_INVALID"
	fi

	local dir
	for dir in "$@"; do
		if [ -d "$dir" ]; then
			shell::logger::debug "Directory '$dir' already exists."
			continue
		fi

		if [ "$dry_run" = "true" ]; then
			shell::exec::command -n mkdir -p -- "$dir"
			continue
		fi

		# `-m 700` applies to the final directory; parents use the umask.
		if [ "$private" = "true" ]; then
			mkdir -p -m 700 -- "$dir" 2>/dev/null
		else
			mkdir -p -- "$dir" 2>/dev/null
		fi

		if [ ! -d "$dir" ] && [ "$use_sudo" = "true" ] && command -v sudo >/dev/null 2>&1; then
			sudo mkdir -p -- "$dir" && sudo chown "$(id -u):$(id -g)" "$dir"
		fi

		if [ ! -d "$dir" ]; then
			shell::logger::error "Failed to create directory '$dir'."
			return "$RETURN_FAILURE"
		fi
		shell::logger::debug "Created directory '$dir'."
	done

	return "$RETURN_SUCCESS"
}

# @description Create files (and their parent directories) if they do not exist.
#   Existing files are left untouched (content and permissions).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the commands instead of running them.
# @option -p | --private Create the file with mode 600 and new parents with 700.
# @arg $@ string File paths.
# @exitcode 0 Every file exists afterwards.
# @exitcode 1 A file or its parent could not be created.
# @exitcode 2 No path was given.
# @example
#   shell::fs::touch --private "$SHELL_KEY_FILE"
#
shell::fs::touch() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Create files (and parent directories) if they do not exist"
		shell::logger::usage "shell::fs::touch [-n] [-p] <file> [file ...]"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "-p, --private" "Create with mode 600 (parents 700)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::fs::touch --private \"\$HOME/.shell-config/key.conf\""
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" private="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		-p | --private) private="true" ;;
		--)
			shift
			break
			;;
		-*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done

	if [ "$#" -eq 0 ]; then
		shell::logger::error "No file path provided."
		return "$RETURN_INVALID"
	fi

	local file parent
	for file in "$@"; do
		[ -e "$file" ] && continue

		# `${file%/*}` is the dirname; a bare filename has no slash, so use ".".
		case "$file" in
		*/*) parent="${file%/*}" ;;
		*) parent="." ;;
		esac
		[ -z "$parent" ] && parent="/"

		if [ "$dry_run" = "true" ]; then
			local -a mkdir_flags=(-n)
			[ "$private" = "true" ] && mkdir_flags+=(--private)
			shell::fs::mkdir "${mkdir_flags[@]}" "$parent"
			shell::exec::command -n touch -- "$file"
			continue
		fi

		if [ "$private" = "true" ]; then
			shell::fs::mkdir --private "$parent" || return "$RETURN_FAILURE"
			# umask 077 makes the file 600 from the first byte (no 644 window).
			(umask 077 && touch -- "$file") || return "$RETURN_FAILURE"
		else
			shell::fs::mkdir "$parent" || return "$RETURN_FAILURE"
			touch -- "$file" || return "$RETURN_FAILURE"
		fi
	done

	return "$RETURN_SUCCESS"
}

# @description Copy one source file to one or more NEW filenames in the current directory.
#   Existing destinations are never overwritten.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the commands instead of running them.
# @arg $1 string Source file.
# @arg $@ string One or more new filenames.
# @exitcode 0 Every copy succeeded (or dry-run printed).
# @exitcode 1 At least one copy failed or was skipped.
# @exitcode 2 Fewer than two arguments were given.
# @exitcode 3 The source does not exist.
# @example
#   shell::fs::copy source.txt copy1.txt copy2.txt
#
shell::fs::copy() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Copy a file to one or more new filenames in the current directory"
		shell::logger::usage "shell::fs::copy [-n] <source> <new_name1> [new_name2 ...]"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::fs::copy source.txt dest1.txt dest2.txt"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if [ "$#" -lt 2 ]; then
		shell::logger::error "Usage: shell::fs::copy [-n] <source> <new_name1> [new_name2 ...]"
		return "$RETURN_INVALID"
	fi

	local source="$1"
	shift
	if [ ! -e "$source" ]; then
		shell::logger::error "Source '$source' does not exist."
		return "$RETURN_NOT_FOUND"
	fi

	local name failed=0
	for name in "$@"; do
		if [ -e "$PWD/$name" ]; then
			shell::logger::error "Destination file '$name' already exists."
			failed=1
			continue
		fi
		if [ "$dry_run" = "true" ]; then
			shell::exec::command -n cp -R -- "$source" "$PWD/$name"
		elif shell::exec::command cp -R -- "$source" "$PWD/$name"; then
			shell::logger::success "Copied to $PWD/$name"
		else
			failed=1
		fi
	done

	return "$failed"
}

# @description Move files into an existing destination directory.
#   Existing destination files are never overwritten.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the commands instead of running them.
# @arg $1 string Destination directory (must exist).
# @arg $@ string Files or directories to move.
# @exitcode 0 Every move succeeded (or dry-run printed).
# @exitcode 1 At least one move failed or was skipped.
# @exitcode 2 Fewer than two arguments were given.
# @exitcode 3 The destination directory does not exist.
# @example
#   shell::fs::move /path/to/dest file1.txt file2.txt
#
shell::fs::move() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Move files into an existing destination directory"
		shell::logger::usage "shell::fs::move [-n] <destination_dir> <file1> [file2 ...]"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::fs::move /path/to/dest file1.txt file2.txt"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if [ "$#" -lt 2 ]; then
		shell::logger::error "Usage: shell::fs::move [-n] <destination_dir> <file1> [file2 ...]"
		return "$RETURN_INVALID"
	fi

	local destination_dir="$1"
	shift
	if [ ! -d "$destination_dir" ]; then
		shell::logger::error "Destination folder '$destination_dir' does not exist."
		return "$RETURN_NOT_FOUND"
	fi

	local source target failed=0
	for source in "$@"; do
		if [ ! -e "$source" ]; then
			shell::logger::error "Source '$source' does not exist."
			failed=1
			continue
		fi
		target="$destination_dir/${source##*/}"
		if [ -e "$target" ]; then
			shell::logger::error "Destination '$target' already exists."
			failed=1
			continue
		fi
		if [ "$dry_run" = "true" ]; then
			shell::exec::command -n mv -- "$source" "$target"
		elif shell::exec::command mv -- "$source" "$target"; then
			shell::logger::success "Moved '$source' to $target"
		else
			failed=1
		fi
	done

	return "$failed"
}

# @description Delete files or directories recursively.
#   Refuses `/`, `.`, `..`, `$HOME` and empty paths. Uses sudo only when
#   `--sudo` is passed (the earlier version always ran `sudo rm -rf`).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the commands instead of running them.
# @option --sudo Run rm through sudo.
# @arg $@ string Paths to delete.
# @exitcode 0 Every path was removed (or dry-run printed).
# @exitcode 1 A removal failed.
# @exitcode 2 No path given, or a path was refused as unsafe.
# @example
#   shell::fs::remove build dist
#   shell::fs::remove -n --sudo /var/tmp/stale
#
shell::fs::remove() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Delete files or directories recursively (guarded)"
		shell::logger::usage "shell::fs::remove [-n] [--sudo] <path> [path ...]"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "--sudo" "Run rm with sudo"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::fs::remove build dist"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false" use_sudo="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-n | --dry-run) dry_run="true" ;;
		--sudo) use_sudo="true" ;;
		--)
			shift
			break
			;;
		-*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*) break ;;
		esac
		shift
	done

	if [ "$#" -eq 0 ]; then
		shell::logger::error "No path provided."
		return "$RETURN_INVALID"
	fi

	local target
	for target in "$@"; do
		# Guard rails: these targets are almost never intended.
		case "$target" in
		"" | "/" | "." | ".." | "$HOME" | "$HOME/")
			shell::logger::error "Refusing to remove unsafe path '$target'."
			return "$RETURN_INVALID"
			;;
		esac
	done

	local -a rm_cmd=(rm -rf --)
	[ "$use_sudo" = "true" ] && rm_cmd=(sudo rm -rf --)

	for target in "$@"; do
		if [ "$dry_run" = "true" ]; then
			shell::exec::command -n "${rm_cmd[@]}" "$target"
		else
			shell::exec::command "${rm_cmd[@]}" "$target" || return "$RETURN_FAILURE"
		fi
	done
	return "$RETURN_SUCCESS"
}

# @description Extract an archive according to its extension.
#   Supported: .tar .tar.gz .tgz .tar.bz2 .tbz2 .tar.xz .txz .gz .bz2 .zip .rar .7z .Z
#   Extraction happens in the current directory. Required extractors
#   (unzip, unrar, 7z) are reported when missing.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string Archive file.
# @exitcode 0 Extracted (or dry-run printed).
# @exitcode 1 The extractor failed.
# @exitcode 2 Wrong arguments or unsupported extension.
# @exitcode 3 The archive or its extractor is missing.
# @example
#   shell::fs::unarchive release.tar.gz
#
shell::fs::unarchive() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Extract an archive according to its extension"
		shell::logger::usage "shell::fs::unarchive [-n] <archive>"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::fs::unarchive release.tar.gz"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if [ "$#" -ne 1 ]; then
		shell::logger::error "Usage: shell::fs::unarchive [-n] <archive>"
		return "$RETURN_INVALID"
	fi

	local file="$1"
	if [ ! -f "$file" ]; then
		shell::logger::error "'$file' is not a valid file."
		return "$RETURN_NOT_FOUND"
	fi

	# argv for the extractor and the binary it needs.
	local needs=""
	local -a cmd=()
	case "$file" in
	*.tar.bz2 | *.tbz2)
		needs="tar"
		cmd=(tar xjf "$file")
		;;
	*.tar.gz | *.tgz)
		needs="tar"
		cmd=(tar xzf "$file")
		;;
	*.tar.xz | *.txz)
		needs="tar"
		cmd=(tar xJf "$file")
		;;
	*.tar)
		needs="tar"
		cmd=(tar xf "$file")
		;;
	*.bz2)
		needs="bunzip2"
		cmd=(bunzip2 -k "$file")
		;;
	*.gz)
		needs="gunzip"
		cmd=(gunzip -k "$file")
		;;
	*.zip)
		needs="unzip"
		cmd=(unzip "$file")
		;;
	*.rar)
		needs="unrar"
		cmd=(unrar x "$file")
		;;
	*.7z)
		needs="7z"
		cmd=(7z x "$file")
		;;
	*.Z)
		needs="uncompress"
		cmd=(uncompress -k "$file")
		;;
	*)
		shell::logger::error "'$file' cannot be extracted: unsupported extension."
		return "$RETURN_INVALID"
		;;
	esac

	if [ "$dry_run" = "true" ]; then
		shell::exec::command -n "${cmd[@]}"
		return "$RETURN_SUCCESS"
	fi

	shell::dependency::ensure "$needs" || return "$RETURN_NOT_FOUND"
	shell::exec::command "${cmd[@]}"
}

# @description List the current directory with type icons and optional details.
#   Rewritten to be side-effect free: the earlier version installed an
#   `EXIT` trap, silently replacing any trap the user had set in their shell.
# @option -h | --help Show help and return.
# @option -a Include hidden entries.
# @option -l Long format: permissions, size, modified time.
# @stdout A column-aligned listing. `[d]` directory, `[e]` executable, `[f]` file.
# @exitcode 0 Success.
# @exitcode 1 The directory could not be read.
# @exitcode 2 Unknown option.
# @example
#   shell::fs::ls -al
#
shell::fs::ls() {
	local show_hidden="false" long_format="false"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-a) show_hidden="true" ;;
		-l) long_format="true" ;;
		-al | -la)
			show_hidden="true"
			long_format="true"
			;;
		-h | --help)
			shell::logger::reset_options
			shell::logger::info "List the current directory with type icons"
			shell::logger::usage "shell::fs::ls [-a] [-l]"
			shell::logger::option "-a" "Include hidden entries"
			shell::logger::option "-l" "Long format (permissions, size, modified)"
			shell::logger::option "-h, --help" "Display this help message"
			return "$RETURN_SUCCESS"
			;;
		*)
			shell::logger::error "Invalid option: $1. Usage: shell::fs::ls [-a] [-l]"
			return "$RETURN_INVALID"
			;;
		esac
		shift
	done

	if [ ! -r . ]; then
		shell::logger::error "No read permission for the current directory."
		return "$RETURN_FAILURE"
	fi

	# -A lists dotfiles but omits "." and "..".
	local ls_flag="-1"
	[ "$show_hidden" = "true" ] && ls_flag="-1A"

	local listing
	listing="$(ls "$ls_flag" 2>&1)" || {
		shell::logger::error "Failed to list directory contents: $listing"
		return "$RETURN_FAILURE"
	}
	if [ -z "$listing" ]; then
		shell::logger::info "No files or directories found."
		return "$RETURN_SUCCESS"
	fi

	local entry icon perms size mtime
	{
		[ "$long_format" = "true" ] && printf 'Type Permissions Size Modified Name\n'
		while IFS= read -r entry; do
			if [ -d "$entry" ]; then
				icon="[d]"
			elif [ -x "$entry" ]; then
				icon="[e]"
			else
				icon="[f]"
			fi

			if [ "$long_format" = "true" ]; then
				perms="$(shell::fs::stat perms "$entry" 2>/dev/null || printf -- '-')"
				size="$(shell::fs::stat size "$entry" 2>/dev/null || printf -- '-')"
				# Join date and time with "_" so `column -t` keeps them in one column.
				mtime="$(shell::fs::stat mtime "$entry" 2>/dev/null | tr ' ' '_')"
				printf '%s %s %s %s %s\n' "$icon" "$perms" "$size" "${mtime:--}" "$entry"
			else
				printf '%s %s\n' "$icon" "$entry"
			fi
		done <<<"$listing"
	} | if command -v column >/dev/null 2>&1; then column -t; else cat; fi
}

# @description Create hard links from a pair of paths or from a `.link` file.
#   A `.link` file holds one `source → destination` pair per line; blank lines
#   and lines starting with `#` are ignored.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the commands instead of running them.
# @arg $1 string Source file (omit both arguments to read ./.link).
# @arg $2 string Destination path.
# @exitcode 0 Every link was created (or dry-run printed).
# @exitcode 1 A source is missing or `ln` failed.
# @exitcode 2 Invalid arguments, malformed `.link` entry, or destination exists.
# @example
#   shell::link::hard data.db backup/data.db
#   shell::link::hard            # reads ./.link
#
shell::link::hard() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Create hard links from two paths or from a .link file"
		shell::logger::usage "shell::link::hard [-n] [<source> <destination>]"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::link::hard data.db backup/data.db"
		shell::logger::note "Without arguments, ./.link is read: one 'source → destination' per line."
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if [ "$#" -ne 0 ] && [ "$#" -ne 2 ]; then
		shell::logger::error "Provide both source and destination, or no paths to use .link"
		return "$RETURN_INVALID"
	fi

	# Each pair is stored as "source<US>destination" (US = ASCII 0x1F "unit
	# separator"), a byte that cannot appear in a normal path.
	local separator=$'\037'
	local -a pairs=()
	local line source destination

	if [ "$#" -eq 2 ]; then
		pairs+=("$1${separator}$2")
	else
		if [ ! -f ".link" ]; then
			shell::logger::error "Link specification file not found: .link"
			return "$RETURN_NOT_FOUND"
		fi
		while IFS= read -r line || [ -n "$line" ]; do
			# Skip blank lines and comments.
			[ -z "$line" ] && continue
			case "$line" in
			"#"* | " "*"#"*) continue ;;
			esac
			case "$line" in
			*"→"*) ;;
			*)
				shell::logger::error "Invalid .link entry (missing '→'): $line"
				return "$RETURN_INVALID"
				;;
			esac
			source="$(shell::strings::trim "${line%%→*}")"
			destination="$(shell::strings::trim "${line#*→}")"
			if [ -z "$source" ] || [ -z "$destination" ]; then
				shell::logger::error "Invalid .link entry: $line"
				return "$RETURN_INVALID"
			fi
			pairs+=("${source}${separator}${destination}")
		done <".link"
	fi

	local pair
	for pair in "${pairs[@]}"; do
		source="${pair%%"$separator"*}"
		destination="${pair#*"$separator"}"

		if [ ! -f "$source" ]; then
			shell::logger::error "Source file not found: $source"
			return "$RETURN_FAILURE"
		fi
		if [ -e "$destination" ]; then
			shell::logger::error "Destination already exists: $destination"
			return "$RETURN_INVALID"
		fi

		if [ "$dry_run" = "true" ]; then
			shell::exec::command -n ln -- "$source" "$destination"
		else
			shell::exec::command ln -- "$source" "$destination" || return "$RETURN_FAILURE"
			shell::logger::success "Hard link created: $destination"
		fi
	done
	return "$RETURN_SUCCESS"
}

# @description Open a directory in the platform file manager.
#   macOS: Finder (via AppleScript). Linux: `xdg-open`.
# @option -h | --help Show help and return.
# @arg $1 string Directory (default: current directory).
# @exitcode 0 The file manager was launched.
# @exitcode 1 The directory is missing or the launcher failed.
# @exitcode 2 More than one argument.
# @exitcode 4 Unsupported operating system.
# @example
#   shell::directory::open ~/Downloads
#
shell::directory::open() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Open a directory in the platform file manager"
		shell::logger::usage "shell::directory::open [directory]"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::directory::open ~/Downloads"
		return "$RETURN_SUCCESS"
	fi

	if [ "$#" -gt 1 ]; then
		shell::logger::error "At most one directory path is allowed"
		return "$RETURN_INVALID"
	fi

	local dir="${1:-$PWD}"
	if [ ! -d "$dir" ]; then
		shell::logger::error "Directory not found: ${dir}"
		return "$RETURN_NOT_FOUND"
	fi

	case "$(shell::os::type)" in
	macos)
		# `open` is the simplest, and avoids the Accessibility permission the
		# previous System Events keystroke approach required.
		open "$dir" || {
			shell::logger::error "Failed to open Finder for: ${dir}"
			return "$RETURN_FAILURE"
		}
		;;
	linux)
		if ! command -v xdg-open >/dev/null 2>&1; then
			shell::logger::error "xdg-open is not installed (install xdg-utils)."
			return "$RETURN_NOT_FOUND"
		fi
		xdg-open "$dir" >/dev/null 2>&1 || {
			shell::logger::error "Failed to open file manager for: ${dir}"
			return "$RETURN_FAILURE"
		}
		;;
	*)
		shell::logger::error "Unsupported operating system: $(shell::os::type)"
		return "$RETURN_NOT_SUPPORTED"
		;;
	esac
}

# @description Change to the previous working directory (`cd -`).
# @option -h | --help Show help and return.
# @exitcode 0 Directory changed.
# @exitcode 1 There is no previous directory, or it is not accessible.
# @exitcode 2 Arguments were given.
shell::directory::back() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Change to the previous working directory"
		shell::logger::usage "shell::directory::back"
		shell::logger::option "-h, --help" "Display this help message"
		return "$RETURN_SUCCESS"
	fi

	if [ "$#" -ne 0 ]; then
		shell::logger::error "This function does not accept arguments"
		return "$RETURN_INVALID"
	fi
	if [ -z "${OLDPWD-}" ]; then
		shell::logger::error "No previous directory is available"
		return "$RETURN_FAILURE"
	fi
	cd -- "$OLDPWD" || {
		shell::logger::error "Cannot access previous directory: ${OLDPWD}"
		return "$RETURN_FAILURE"
	}
}

# @description Print the MIME type of a file.
#   Looks the extension up first (fast, deterministic across platforms); for
#   unknown or missing extensions it asks `file --mime-type`, and finally falls
#   back to `application/octet-stream` (the earlier default of `text/plain`
#   mislabelled binary files).
# @option -h | --help Show help and return.
# @arg $1 string File path.
# @stdout The MIME type.
# @exitcode 0 Success.
# @exitcode 2 No path given.
# @exitcode 3 The file does not exist.
# @example
#   shell::file::mime report.pdf   # -> application/pdf
#
shell::file::mime() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Print the MIME type of a file"
		shell::logger::usage "shell::file::mime <file>"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::file::mime report.pdf"
		return "$RETURN_SUCCESS"
	fi

	local file="${1-}"
	if [ -z "$file" ]; then
		shell::logger::error "File path is required"
		return "$RETURN_INVALID"
	fi
	if [ ! -f "$file" ]; then
		shell::logger::error "File '${file}' does not exist"
		return "$RETURN_NOT_FOUND"
	fi

	# A file without a dot has no extension; `${file##*.}` would return the whole name.
	local extension=""
	case "${file##*/}" in
	*.*) extension="$(printf '%s' "${file##*.}" | tr '[:upper:]' '[:lower:]')" ;;
	esac

	case "$extension" in
	txt | log) printf 'text/plain\n' ;;
	json) printf 'application/json\n' ;;
	csv) printf 'text/csv\n' ;;
	md | mdx) printf 'text/markdown\n' ;;
	html | htm) printf 'text/html\n' ;;
	xml) printf 'application/xml\n' ;;
	jpg | jpeg) printf 'image/jpeg\n' ;;
	png) printf 'image/png\n' ;;
	webp) printf 'image/webp\n' ;;
	gif) printf 'image/gif\n' ;;
	svg) printf 'image/svg+xml\n' ;;
	ico) printf 'image/x-icon\n' ;;
	pdf) printf 'application/pdf\n' ;;
	docx) printf 'application/vnd.openxmlformats-officedocument.wordprocessingml.document\n' ;;
	xlsx) printf 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\n' ;;
	pptx) printf 'application/vnd.openxmlformats-officedocument.presentationml.presentation\n' ;;
	zip) printf 'application/zip\n' ;;
	tar) printf 'application/x-tar\n' ;;
	gz) printf 'application/gzip\n' ;;
	bz2) printf 'application/x-bzip2\n' ;;
	xz) printf 'application/x-xz\n' ;;
	mp3) printf 'audio/mpeg\n' ;;
	wav) printf 'audio/wav\n' ;;
	ogg) printf 'audio/ogg\n' ;;
	mp4) printf 'video/mp4\n' ;;
	avi) printf 'video/x-msvideo\n' ;;
	mkv) printf 'video/x-matroska\n' ;;
	flv) printf 'video/x-flv\n' ;;
	webm) printf 'video/webm\n' ;;
	yaml | yml) printf 'application/x-yaml\n' ;;
	sh | bash | zsh) printf 'application/x-sh\n' ;;
	py) printf 'text/x-python\n' ;;
	js | mjs) printf 'application/javascript\n' ;;
	ts | tsx) printf 'application/typescript\n' ;;
	css) printf 'text/css\n' ;;
	sql) printf 'application/sql\n' ;;
	rs) printf 'text/x-rust\n' ;;
	go) printf 'text/x-go\n' ;;
	c) printf 'text/x-csrc\n' ;;
	h) printf 'text/x-chdr\n' ;;
	cpp | cxx | cc) printf 'text/x-c++src\n' ;;
	java) printf 'text/x-java-source\n' ;;
	kt | kts) printf 'text/x-kotlin\n' ;;
	rb) printf 'text/x-ruby\n' ;;
	pl) printf 'text/x-perl\n' ;;
	php) printf 'application/x-php\n' ;;
	swift) printf 'text/x-swift\n' ;;
	lua) printf 'text/x-lua\n' ;;
	dart) printf 'application/dart\n' ;;
	scala) printf 'text/x-scala\n' ;;
	cs) printf 'text/x-csharp\n' ;;
	vue) printf 'text/x-vue\n' ;;
	svelte) printf 'text/x-svelte\n' ;;
	*)
		# Unknown extension: ask libmagic, which exists on both Linux and macOS.
		if command -v file >/dev/null 2>&1; then
			file --mime-type -b "$file" 2>/dev/null || printf 'application/octet-stream\n'
		else
			printf 'application/octet-stream\n'
		fi
		;;
	esac
}

# @description Print a file's contents as a single-line Base64 string.
#   Streams through `base64 | tr -d '\n'` (GNU base64 wraps at 76 columns, BSD
#   does not; deleting newlines gives identical output on both). No temp file.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @arg $1 string File path.
# @stdout The Base64 text without newlines.
# @exitcode 0 Success.
# @exitcode 1 Encoding failed.
# @exitcode 2 Not exactly one path was given.
# @exitcode 3 The file does not exist.
# @example
#   b64="$(shell::encode::file::base64 logo.png)"
#
shell::encode::file::base64() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Encode a file as single-line Base64"
		shell::logger::usage "shell::encode::file::base64 [-n] <file>"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::encode::file::base64 logo.png"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	if [ "$#" -ne 1 ]; then
		shell::logger::error "Exactly one file path is required"
		return "$RETURN_INVALID"
	fi
	local file="$1"
	if [ ! -f "$file" ]; then
		shell::logger::error "File not found: ${file}"
		return "$RETURN_NOT_FOUND"
	fi

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "base64 < \"${file}\" | tr -d '\\n'"
		return "$RETURN_SUCCESS"
	fi

	local encoded
	encoded="$(base64 <"$file")" || {
		shell::logger::error "Failed to encode '${file}' as Base64"
		return "$RETURN_FAILURE"
	}
	# Delete the line wraps GNU base64 inserts every 76 columns.
	printf '%s' "${encoded//$'\n'/}"
}

# @description Pick a file with fzf and run an action on it.
#   Replaces `shell::editor`. Actions: cat, less, more, vim, nano, remove,
#   base64, clip-base64, path, clip, unlock, permissions, ex-permissions,
#   mime-type.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the chosen command instead of running it.
# @arg $1 string Directory whose files are offered (default: current directory).
# @exitcode 0 The action completed.
# @exitcode 1 The action failed.
# @exitcode 3 The directory does not exist or holds no files.
# @exitcode 9 The user cancelled a selection.
# @example
#   shell::fs::browse ~/documents
#   shell::fs::browse -n .
#
shell::fs::browse() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Pick a file with fzf and run an action on it"
		shell::logger::usage "shell::fs::browse [-n] [directory]"
		shell::logger::option "-n, --dry-run" "Print the chosen command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::fs::browse ~/documents"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local folder="${1:-.}"
	if [ ! -d "$folder" ]; then
		shell::logger::error "'$folder' is not a valid directory."
		return "$RETURN_NOT_FOUND"
	fi

	# Absolute path without realpath/readlink -f (neither is portable to stock macOS).
	local base
	base="$(cd "$folder" && pwd -P)" || return "$RETURN_FAILURE"

	local selected
	selected="$(find "$base" -type f 2>/dev/null | shell::fzf::select --prompt="Select a file: ")" || return "$RETURN_CANCELLED"
	if [ -z "$selected" ]; then
		shell::logger::error "No files found in '$folder'."
		return "$RETURN_NOT_FOUND"
	fi

	local action
	action="$(printf '%s\n' cat less more vim nano remove base64 clip-base64 path clip unlock permissions ex-permissions mime-type |
		shell::fzf::select --prompt="Select an action: ")" || return "$RETURN_CANCELLED"

	local -a flag=()
	[ "$dry_run" = "true" ] && flag=(-n)

	case "$action" in
	remove) shell::fs::remove ${flag[@]+"${flag[@]}"} "$selected" ;;
	base64) shell::encode::file::base64 ${flag[@]+"${flag[@]}"} "$selected" ;;
	clip-base64) shell::clipboard::copy "$(shell::encode::file::base64 "$selected")" ;;
	path) shell::clipboard::copy "$selected" ;;
	clip) shell::clipboard::copy "$(cat "$selected")" ;;
	unlock) shell::permission::unlock ${flag[@]+"${flag[@]}"} "$selected" ;;
	permissions) shell::permission::set::fzf ${flag[@]+"${flag[@]}"} "$selected" ;;
	ex-permissions) shell::permission::analyze --file "$selected" ;;
	mime-type) shell::logger::info "MIME type of '$selected': $(shell::file::mime "$selected")" ;;
	cat | less | more | vim | nano)
		if [ "$dry_run" = "true" ]; then
			shell::logger::command_clip "$action \"$selected\""
		else
			shell::exec::command "$action" "$selected"
		fi
		;;
	*)
		shell::logger::error "Unknown action '$action'."
		return "$RETURN_INVALID"
		;;
	esac
}
