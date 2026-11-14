#!/usr/bin/env bash
# @file lib/conf.sh
# @brief Encoded key/value configuration store with groups and protected keys.

# @description Sources a configuration file, allowing its variables and functions to be loaded into the current shell.
#
#   The function checks that a filename is provided and that the specified file exists.
#   If the file is not found, an error message is displayed.
#   In dry-run mode, the command "source <filename>" is printed using shell::logger::command_clip.
#   Otherwise, the file is sourced using shell::exec::command to log the execution.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.
# @arg $1 string filename: The configuration file to source.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::read ~/.my-config                # Sources the configuration file.
#   shell::conf::read -n ~/.my-config             # Prints the sourcing command without executing it.
#
shell::conf::read() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Sources a configuration file, allowing its variables and functions to be loaded into the current shell"
		shell::logger::usage "shell::conf::read [-n] [-h] <filename>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "filename" "The configuration file to source."
		shell::logger::example "shell::conf::read ~/.my-config"
		shell::logger::example "shell::conf::read -n ~/.my-config"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check if a filename is provided.
	if [ $# -lt 1 ]; then
		echo "Usage: shell::conf::read [-n] <filename>"
		return 1
	fi

	local filename="$1"

	# Verify that the configuration file exists.
	if [[ ! -f "$filename" ]]; then
		shell::logger::error "Conf file '$filename' not found."
		return 1
	fi

	# Check if dry mode is enabled.
	# If so, print the command to source the file.
	# Otherwise, source the file.
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "source \"$filename\""
	else
		shell::exec::command source "$filename"
	fi
}

# @description Adds a configuration entry (key=value) to a constant configuration file.
#   The value is encoded using Base64 before being saved.
#
#   The function first checks for an optional dry-run flag (-n) and verifies that both key and value are provided.
#   It encodes the value using Base64 (with newline characters removed) and then appends a line in the format:
#   key=encoded_value
#   to a constant configuration file (defined by SHELL_KEY_FILE). If the configuration file does not exist, it is created.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.
# @arg $1 string key: The configuration key.
# @arg $2 string value: The configuration value to be encoded and saved.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::key::add my_setting "some secret value"         # Encodes the value and adds the entry.
#   shell::conf::key::add -n my_setting "some secret value"      # Prints the command without executing it.
#
shell::conf::key::add() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Adds a configuration entry (key=value) to a constant configuration file"
		shell::logger::usage "shell::conf::key::add [-n] [-h] <key> <value>"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "key" "The configuration key."
		shell::logger::item "value" "The configuration value to be encoded and saved."
		shell::logger::example "shell::conf::key::add my_setting \"some secret value\""
		shell::logger::example "shell::conf::key::add -n my_setting \"some secret value\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	# Check if a key and value are provided.
	# If not, print usage information and return an error.
	if [ $# -lt 2 ]; then
		echo "Usage: shell::conf::key::add [-n] <key> <value>"
		return 1
	fi

	local key="$1"
	local value="$2"
	key=$(shell::strings::sanitize::upper "$key")

	# Encode the value using Base64 and remove any newlines.
	local encoded_value
	encoded_value="$(_shell::conf::b64encode "$value")"

	# Ensure the configuration file exists.
	shell::fs::touch --private "$SHELL_KEY_FILE"
	shell::permission::secure "$SHELL_KEY_FILE"

	# Build the command to append the key and encoded value to the configuration file.
	local cmd="echo \"$key=$encoded_value\" >> \"$SHELL_KEY_FILE\""

	# Check if the dry mode is enabled.
	# If so, print the command to be executed.
	# Otherwise, execute the command to add the configuration entry.
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
	else
		result=$(shell::conf::key::exists $key)
		if [ "$result" = "true" ]; then
			shell::logger::warn "The key '$key' exists. Please consider updating it by using shell::conf::key::update::fzf"
			return 0
		fi
		shell::exec::shell "$cmd"
		shell::logger::success "Added configuration: $key (encoded value)"
	fi
}

# @description Adds a configuration entry (key=value) with an optional comment to the constant configuration file.
#   The value is encoded using Base64 before being saved.
#
#   This function encodes the value using Base64 (with newline characters removed) and appends a line in the format:
#   # comment (if provided)
#   key=encoded_value
#   to the configuration file defined by SHELL_KEY_FILE.
#   If the key already exists, a warning is shown and the function exits.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.
# @arg $1 string key: The configuration key.
# @arg $2 string value: The configuration value to be encoded and saved.
# @arg $@ string comment: Optional comment to be added above the key-value pair.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::key::comment my_key "my secret" "This is a comment"
#   shell::conf::key::comment -n my_key "my secret" "Dry-run with comment"
#
shell::conf::key::comment() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Adds a configuration entry (key=value) with an optional comment to the constant configuration file"
		shell::logger::usage "shell::conf::key::comment [-n] <key> <value> [comment]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed."
		shell::logger::item "key" "The configuration key."
		shell::logger::item "value" "The configuration value to be encoded and saved."
		shell::logger::item "comment" "Optional comment to be added above the key-value pair."
		shell::logger::option "-h, --help" "Display this help message"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	if [ $# -lt 2 ]; then
		echo "Usage: shell::conf::key::comment [-n] <key> <value> [comment]"
		return 1
	fi

	local key="$1"
	local value="$2"
	local comment="${3-}"

	key=$(shell::strings::sanitize::upper "$key")

	# Encode the value using Base64 and remove any newlines
	local encoded_value
	encoded_value="$(_shell::conf::b64encode "$value")"

	# Ensure the configuration file exists
	shell::fs::touch --private "$SHELL_KEY_FILE"
	shell::permission::secure "$SHELL_KEY_FILE"

	# Check if the key already exists
	if [ "$(shell::conf::key::exists "$key")" = "true" ]; then
		shell::logger::warn "The key '$key' exists. Please consider updating it by using shell::conf::key::update::fzf"
		return 0
	fi

	# A comment is one line; the text is user-controlled, so it is never evaluated (printf, not exec::shell).
	comment="$(printf '%s' "$comment" | tr '\r\n' '  ')"

	# Build the command to append the comment and key-value pair
	local cmd=""
	if [ -n "$comment" ]; then
		cmd="printf '%s\\n' $(printf '%q' "# $comment") >> \"$SHELL_KEY_FILE\" && "
	fi
	cmd+="echo \"$key=$encoded_value\" >> \"$SHELL_KEY_FILE\""

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
	else
		if [ -n "$comment" ]; then
			printf '%s\n' "# $comment" >>"$SHELL_KEY_FILE"
		fi
		printf '%s\n' "$key=$encoded_value" >>"$SHELL_KEY_FILE"
		shell::logger::success "Added configuration: $key (encoded value) with comment"
	fi
}

# ------------------------------------------------------------------------------------------------
# Live browser internals (shared by every interactive shell::conf::* menu)
# ------------------------------------------------------------------------------------------------

# @internal
# @description Decode a Base64 value (OS-aware: `-D` on macOS, `-d` elsewhere).
# @arg $1 string The encoded value.
# @stdout The decoded bytes (no trailing newline is added).
# @exitcode 0 Decoded.
# @exitcode 1 Not valid Base64.
# @example
#   value="$(_shell::conf::b64decode "$encoded")"
#
_shell::conf::b64decode() {
	if [ "$(shell::os::type)" = "macos" ]; then
		printf '%s' "${1-}" | base64 -D 2>/dev/null
	else
		printf '%s' "${1-}" | base64 -d 2>/dev/null
	fi
}

# @internal
# @description Encode a value as one-line Base64. `printf '%s'` (not echo) keeps backslashes and a leading `-n` intact.
# @arg $1 string The value.
# @stdout The encoded value.
# @exitcode 0 Always.
# @example
#   encoded="$(_shell::conf::b64encode "$value")"
#
_shell::conf::b64encode() {
	printf '%s' "${1-}" | base64 | tr -d '\n'
}

# @internal
# @description Single-quote a string so a POSIX `sh` reads it back verbatim (used to build the preview commands).
# @arg $1 string The text.
# @stdout The quoted text.
# @exitcode 0 Always.
# @example
#   cmd="sh $(_shell::conf::sq "$script") key {}"
#
_shell::conf::sq() {
	printf "'%s'" "$(printf '%s' "${1-}" | sed "s/'/'\\\\''/g")"
}

# @internal
# @description Print the value stored for a name in a `NAME=value` file, matching the name literally (never as a regex).
#   Comment lines are ignored.
# @arg $1 string The file.
# @arg $2 string The name.
# @stdout The raw text after the first `=`.
# @exitcode 0 Found.
# @exitcode 1 Not found.
# @exitcode 3 The file does not exist.
# @example
#   encoded="$(_shell::conf::entry "$SHELL_KEY_FILE" "MY_KEY")"
#
_shell::conf::entry() {
	local file="${1-}"
	[ -f "$file" ] || return "$RETURN_NOT_FOUND"
	CONF_NAME="${2-}" awk -F= '
		/^[ \t]*#/ { next }
		index($0, "=") && $1 == ENVIRON["CONF_NAME"] { print substr($0, length($1) + 2); found = 1; exit }
		END { exit(found ? 0 : 1) }' "$file"
}

# @internal
# @description List the names stored in a `NAME=value` file (comments and lines without `=` are skipped).
# @arg $1 string The file.
# @stdout One name per line.
# @exitcode 0 Always.
# @example
#   _shell::conf::names "$SHELL_KEY_FILE"
#
_shell::conf::names() {
	[ -f "${1-}" ] || return 0
	awk -F= '/^[ \t]*#/ { next } index($0, "=") { print $1 }' "$1"
}

# @internal
# @description List the keys written in the protected-key file (one per line, comments and blanks skipped).
# @stdout One key per line.
# @exitcode 0 Always.
# @example
#   _shell::conf::protected::stored
#
_shell::conf::protected::stored() {
	[ -f "$SHELL_KEY_PROTECTED_FILE" ] || return 0
	grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$SHELL_KEY_PROTECTED_FILE" || true
}

# @internal
# @description Mask a value for display: first two characters (only when it is long enough), bullets and the length.
#   The raw value is never shown.
# @arg $1 string The value.
# @stdout The masked text.
# @exitcode 0 Always.
# @example
#   _shell::conf::mask "s3cr3t-token"   # -> s3••••  (len 12)
#
_shell::conf::mask() {
	local value="${1-}" head=""
	if [ "${#value}" -ge 6 ]; then
		head="$(printf '%s' "$value" | awk 'NR == 1 { print substr($0, 1, 2) }' | tr -cd '[:print:]')"
	fi
	printf '%s••••  (len %s)' "$head" "${#value}"
}

# @internal
# @description Escape a string for use inside a JSON string literal (`"`, `\`, newline, tab, CR and other control characters).
# @arg $1 string The text.
# @stdout The escaped text, without the surrounding quotes.
# @exitcode 0 Always.
# @example
#   printf '"%s"' "$(_shell::conf::json_escape 'say "hi"')"
#
_shell::conf::json_escape() {
	printf '%s' "${1-}" | awk '
		BEGIN { for (i = 1; i < 32; i++) ctl[sprintf("%c", i)] = sprintf("\\u%04x", i); ctl["\t"] = "\\t"; ctl["\r"] = "\\r" }
		{
			out = ""
			for (i = 1; i <= length($0); i++) {
				c = substr($0, i, 1)
				if (c == "\\") out = out "\\\\"
				else if (c == "\"") out = out "\\\""
				else if (c in ctl) out = out ctl[c]
				else out = out c
			}
			printf "%s%s", (NR > 1 ? "\\n" : ""), out
		}'
}

# @internal
# @description Build the JSON object of a group: `{"KEY":"value",...}`. Keys missing from the key file are skipped.
# @arg $1 string The group name.
# @stdout The JSON text (always valid JSON: values are escaped).
# @exitcode 0 Built.
# @exitcode 1 The group has no keys.
# @exitcode 3 The group does not exist.
# @example
#   json="$(_shell::conf::group::json "DB")"
#
_shell::conf::group::json() {
	local csv key encoded value json="{" first=1
	local -a keys_array=()
	csv="$(_shell::conf::entry "$SHELL_KEY_GROUP_FILE" "${1-}")" || return "$RETURN_NOT_FOUND"
	[ -n "$csv" ] || return "$RETURN_FAILURE"
	if [ -n "${BASH_VERSION-}" ]; then
		IFS=',' read -r -a keys_array <<<"$csv"
	else
		IFS=',' read -rA keys_array <<<"$csv"
	fi
	for key in ${keys_array[@]+"${keys_array[@]}"}; do
		encoded="$(_shell::conf::entry "$SHELL_KEY_FILE" "$key")" || continue
		value="$(_shell::conf::b64decode "$encoded")"
		if [ "$first" -eq 0 ]; then json+=","; else first=0; fi
		json+="\"$(_shell::conf::json_escape "$key")\":\"$(_shell::conf::json_escape "$value")\""
	done
	json+="}"
	printf '%s' "$json"
}

# @internal
# @description Atomically change one `NAME=value` file (temp file in the same directory + `mv`, mode 600).
#   The name is matched literally and the value is passed through the environment, so Base64 containing `/`,
#   `+`, `&` or `=` is safe (the old `sed s/…/…/` edits broke on those).
#
#   Operations: `replace` (set the value of an existing name), `rename` (VALUE is the new name), `delete`
#   (drop the entry and the `#` comment written directly above it), `delete_line` (drop a bare line equal to NAME,
#   for protected.conf) and `upsert` (replace, or append when missing).
# @arg $1 string The file.
# @arg $2 string The operation.
# @arg $3 string The name.
# @arg $4 string Optional. The value (or the new name for `rename`).
# @exitcode 0 Written.
# @exitcode 1 Writing failed.
# @exitcode 2 Unknown operation.
# @exitcode 3 The file or the name does not exist.
# @example
#   _shell::conf::file::edit "$SHELL_KEY_FILE" replace "MY_KEY" "$encoded"
#
_shell::conf::file::edit() {
	local file="${1-}" op="${2-}" name="${3-}" value="${4-}" tmp rc=0
	case "$op" in
	replace | rename | delete | delete_line | upsert) ;;
	*) return "$RETURN_INVALID" ;;
	esac
	[ -f "$file" ] || return "$RETURN_NOT_FOUND"
	tmp="$(mktemp "${file}.XXXXXX")" || return "$RETURN_FAILURE"
	CONF_NAME="$name" CONF_VALUE="$value" CONF_OP="$op" awk '
		function flush() { if (has) { print pending; has = 0 } }
		BEGIN { k = ENVIRON["CONF_NAME"]; v = ENVIRON["CONF_VALUE"]; op = ENVIRON["CONF_OP"] }
		{
			line = $0
			if (op == "delete_line") {
				if (line == k) { done = 1; next }
				print line
				next
			}
			if (line ~ /^[ \t]*#/) { flush(); pending = line; has = 1; next }
			eq = index(line, "=")
			if (eq > 0 && substr(line, 1, eq - 1) == k) {
				done = 1
				if (op == "delete") { has = 0; next }
				flush()
				if (op == "rename") print v substr(line, eq)
				else print k "=" v
				next
			}
			flush()
			print line
		}
		END {
			flush()
			if (op == "upsert" && !done) { print k "=" v; done = 1 }
			if (!done) exit 3
		}' "$file" >"$tmp" || rc=$?
	if [ "$rc" -ne 0 ]; then
		rm -f "$tmp"
		[ "$rc" -eq 3 ] && return "$RETURN_NOT_FOUND"
		return "$RETURN_FAILURE"
	fi
	shell::permission::secure "$tmp" >/dev/null 2>&1
	mv -f "$tmp" "$file" || {
		rm -f "$tmp"
		return "$RETURN_FAILURE"
	}
	return "$RETURN_SUCCESS"
}

# @internal
# @description Run (or, in dry-run mode, only print) one change made by _shell::conf::file::edit and report the outcome.
# @arg $1 string `true` for dry-run.
# @arg $2 string The success message.
# @arg $3 string The file.
# @arg $4 string The operation (see _shell::conf::file::edit).
# @arg $5 string The name.
# @arg $6 string Optional. The value.
# @exitcode 0 Written (or printed in dry-run mode).
# @exitcode 1 Writing failed or the name was not found.
# @example
#   _shell::conf::write "$dry_run" "Updated key" "$SHELL_KEY_FILE" replace "MY_KEY" "$encoded"
#
_shell::conf::write() {
	local dry_run="${1-false}" ok="${2-}" file="${3-}" op="${4-}" name="${5-}" value="${6-}" rc=0
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "_shell::conf::file::edit $(printf '%q' "$file") $op $(printf '%q' "$name") $(printf '%q' "$value")"
		return "$RETURN_SUCCESS"
	fi
	_shell::conf::file::edit "$file" "$op" "$name" "$value" || rc=$?
	case "$rc" in
	0)
		shell::logger::success "$ok"
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_NOT_FOUND")
		shell::logger::error "'${name}' was not found in '${file}'."
		return "$RETURN_FAILURE"
		;;
	*)
		shell::logger::error "Could not write '${file}'."
		return "$RETURN_FAILURE"
		;;
	esac
}

# @internal
# @description Copy a value to the clipboard and say what happened. Never copies an empty value.
#   The value travels in a variable (no fzf `execute`, no preview subshell), so it works on every pass of a menu
#   loop and keeps spaces, quotes, `$`, backticks, `%`, `\` and newlines intact. Without a clipboard tool the value is
#   printed instead, with a warning. In dry-run mode only the command is shown (the value is never printed).
# @arg $1 string What is copied (for the messages).
# @arg $2 string The value.
# @arg $3 string `true` for dry-run.
# @arg $4 string Optional. How to show the value in dry-run mode (default: a placeholder).
# @exitcode 0 Copied (or printed, or dry-run).
# @exitcode 1 The clipboard tool failed.
# @exitcode 2 The value is empty.
# @example
#   _shell::conf::copy "value of MY_KEY" "$value" "$dry_run"
#
_shell::conf::copy() {
	local label="${1-}" value="${2-}" dry_run="${3-false}" shown="${4-}" rc=0
	if [ -z "$value" ]; then
		shell::logger::error "Nothing to copy: ${label} is empty"
		return "$RETURN_INVALID"
	fi
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "shell::clipboard::copy \"${shown:-<${label}>}\""
		return "$RETURN_SUCCESS"
	fi
	shell::clipboard::copy "$value" || rc=$?
	case "$rc" in
	0)
		shell::logger::success "Copied ${label}"
		return "$RETURN_SUCCESS"
		;;
	"$RETURN_NOT_FOUND")
		shell::logger::warn "No clipboard tool found — printing ${label} instead"
		printf '%s\n' "$value"
		return "$RETURN_SUCCESS"
		;;
	*)
		shell::logger::error "Could not copy ${label}"
		return "$RETURN_FAILURE"
		;;
	esac
}

# @internal
# @description Write the self-contained live-preview script of the menus into a work directory and refresh the
#   list of protected keys it reads. fzf runs `--preview` in a separate process where no `shell::*` function exists,
#   so the script is plain POSIX `sh` (awk, grep, tr, base64) and has every path baked in. One awk pass per cursor
#   move; values are always masked.
# @arg $1 string The work directory.
# @exitcode 0 Written.
# @example
#   _shell::conf::preview::init "$work"
#
_shell::conf::preview::init() {
	local work="${1-}"
	{
		_shell::conf::protected::stored
		printf '%s\n' ${SHELL_PROTECTED_KEYS[@]+"${SHELL_PROTECTED_KEYS[@]}"}
	} >"$work/prot"
	[ -f "$work/preview.sh" ] && return "$RETURN_SUCCESS"
	{
		printf 'KEYF=%s\nGRPF=%s\nPROTF=%s\nBACK=%s\n' \
			"$(_shell::conf::sq "$SHELL_KEY_FILE")" "$(_shell::conf::sq "$SHELL_KEY_GROUP_FILE")" \
			"$(_shell::conf::sq "$work/prot")" "$(_shell::conf::sq "$SHELL_FZF_BACK_LABEL")"
		cat <<-'EOS'
			mode="$1"
			item="$2"
			esc="$(printf '\033')"
			dim="${esc}[2m"
			rst="${esc}[0m"
			yel="${esc}[33m"
			grn="${esc}[32m"
			red="${esc}[31m"
			if [ "$item" = "$BACK" ]; then
				printf '%sGo back without changing anything%s\n' "$dim" "$rst"
				mode=back
			fi
				dec() {
				v="$(printf '%s' "$1" | base64 -d 2>/dev/null)" || v="$(printf '%s' "$1" | base64 -D 2>/dev/null)"
				printf '%s' "$v"
			}
				mask() {
				v="$1"
				n="${#v}"
				h=""
				if [ "$n" -ge 6 ]; then h="$(printf '%s' "$v" | awk 'NR == 1 { print substr($0, 1, 2) }' | tr -cd '[:print:]')"; fi
				printf '%s••••  (len %s)' "$h" "$n"
			}
				row() { printf '%s%-10s%s %s\n' "$dim" "$1" "$rst" "$2"; }
				lookup() {
				CONF_NAME="$2" awk -F= '/^[ \t]*#/ { next } index($0, "=") && $1 == ENVIRON["CONF_NAME"] { print substr($0, length($1) + 2); f = 1; exit } END { exit(f ? 0 : 1) }' "$1"
			}
				shown() {
				if [ -z "$1" ]; then printf '(empty)'; return; fi
				v="$(dec "$1")"
				if [ -z "$v" ]; then printf '(invalid base64)'; else mask "$v"; fi
			}
			case "$mode" in
			key)
				printf '%s%s%s\n' "$yel" "$item" "$rst"
				if grep -Fxq -- "$item" "$PROTF" 2>/dev/null; then
					row protected "🔒 yes - update, rename and remove are disabled"
				else
					row protected "no"
				fi
				if enc="$(lookup "$KEYF" "$item")"; then
					c="$(CONF_NAME="$item" awk -F= '
						index($0, "=") && $0 !~ /^[ \t]*#/ && $1 == ENVIRON["CONF_NAME"] { if (p ~ /^[ \t]*#/) { sub(/^[ \t]*#[ \t]*/, "", p); print p } exit }
						{ p = $0 }' "$KEYF")"
					[ -n "$c" ] && row comment "$c"
					g="$(CONF_NAME="$item" awk -F= '
						index($0, "=") && $0 !~ /^[ \t]*#/ { n = split($2, a, ","); for (i = 1; i <= n; i++) if (a[i] == ENVIRON["CONF_NAME"]) { printf "%s%s", (c++ ? ", " : ""), $1; break } }' "$GRPF" 2>/dev/null)"
					row groups "${g:--}"
					row value "$(shown "$enc")"
				else
					row status "${red}missing${rst} from the key file"
				fi
				;;
			group)
				printf '%s%s%s\n' "$yel" "$item" "$rst"
				csv="$(lookup "$GRPF" "$item")" || csv="$(printf '\001')"
				if [ "$csv" = "$(printf '\001')" ]; then
					row status "${red}not found${rst}"
					csv=""
				fi
				row keys "$(printf '%s\n' "$csv" | tr ',' '\n' | grep -c .)"
				tab="$(CONF_CSV="$csv" awk -F= '
					BEGIN { n = split(ENVIRON["CONF_CSV"], a, ","); for (i = 1; i <= n; i++) w[a[i]] = 1 }
					/^[ \t]*#/ { next }
					index($0, "=") && ($1 in w) { print $1 "\t" substr($0, length($1) + 2) }' "$KEYF")"
				printf '%s\n' "$csv" | tr ',' '\n' | while IFS= read -r k; do
					[ -n "$k" ] || continue
					if line="$(printf '%s\n' "$tab" | CONF_NAME="$k" awk -F'\t' '$1 == ENVIRON["CONF_NAME"] { print substr($0, length($1) + 2); f = 1; exit } END { exit(f ? 0 : 1) }')"; then
						printf '  %s✓%s %-28s %s\n' "$grn" "$rst" "$k" "$(shown "$line")"
					else
						printf '  %s✗%s %-28s %smissing%s\n' "$red" "$rst" "$k" "$dim" "$rst"
					fi
				done
				;;
			esac
		EOS
	} >"$work/preview.sh"
}

# @internal
# @description Build the list shown by a menu (one name per line, without the Back row).
# @arg $1 string The kind: `key`, `group` or `protected` (the keys listed in protected.conf).
# @stdout The names.
# @exitcode 0 Always.
# @example
#   list="$(_shell::conf::list key)"
#
_shell::conf::list() {
	case "${1-}" in
	group) _shell::conf::names "$SHELL_KEY_GROUP_FILE" ;;
	protected) _shell::conf::protected::stored ;;
	*) _shell::conf::names "$SHELL_KEY_FILE" ;;
	esac
}

# @internal
# @description Show a list with the live masked preview and a trailing "← Back" row, through shell::fzf::select.
# @arg $1 string The work directory (holds the preview script, see _shell::conf::preview::init).
# @arg $2 string The preview kind: `key` or `group`.
# @arg $3 string The prompt.
# @arg $4 string The header (key hints).
# @arg $5 string The name to put the cursor on (may be empty).
# @arg $6 string The names, one per line (without the Back row).
# @arg $@ string Optional. Extra fzf arguments (for example `--multi`).
# @stdout The selected line(s); the Back row is returned as SHELL_FZF_BACK_LABEL.
# @exitcode 0 Something was selected.
# @exitcode 9 Cancelled (ESC / Ctrl-C).
# @example
#   _shell::conf::pick "$work" key "Select key: " "Enter: actions" "$last" "$list"
#
_shell::conf::pick() {
	local work="${1-}" kind="${2-key}" prompt="${3-}" header="${4-}" initial="${5-}" list="${6-}"
	shift 6
	local -a init=()
	if [ -n "$initial" ]; then init=(--initial "$initial"); fi
	printf '%s\n%s\n' "$list" "$SHELL_FZF_BACK_LABEL" | shell::fzf::select ${init[@]+"${init[@]}"} \
		--prompt="$prompt" --header="$header" \
		--preview="sh $(_shell::conf::sq "$work/preview.sh") ${kind} {}" --preview-window="right:55%:wrap" \
		--height=60% "$@"
}

# @internal
# @description Tell whether a key is protected (protected.conf or SHELL_PROTECTED_KEYS), through shell::conf::protected::is.
# @arg $1 string The key.
# @exitcode 0 The key is protected.
# @exitcode 1 It is not.
# @example
#   _shell::conf::key::is_protected "HOST" && echo locked
#
_shell::conf::key::is_protected() {
	[ "$(shell::conf::protected::is "${1-}" 2>/dev/null)" = "true" ]
}

# @internal
# @description Copy the decoded value of a key (the key is printed, the value never is).
# @arg $1 string The key.
# @arg $2 string `true` for dry-run.
# @exitcode 0 Copied.
# @exitcode 1 The key is missing or the copy failed.
# @example
#   _shell::conf::key::copy "MY_KEY" false
#
_shell::conf::key::copy() {
	local key="${1-}" dry_run="${2-false}" encoded value
	encoded="$(_shell::conf::entry "$SHELL_KEY_FILE" "$key")" || {
		shell::logger::error "Key '$key' not found in configuration."
		return "$RETURN_FAILURE"
	}
	value="$(_shell::conf::b64decode "$encoded")"
	shell::console::print "[k] Key: $key" 33
	_shell::conf::copy "value of ${key}" "$value" "$dry_run" "<value of ${key}>"
}

# @internal
# @description Print the decoded value of a key. Only reached through the explicit "Reveal value" action.
# @arg $1 string The key.
# @exitcode 0 Printed.
# @exitcode 1 The key is missing.
# @example
#   _shell::conf::key::reveal "MY_KEY"
#
_shell::conf::key::reveal() {
	local key="${1-}" encoded
	encoded="$(_shell::conf::entry "$SHELL_KEY_FILE" "$key")" || {
		shell::logger::error "Key '$key' not found in configuration."
		return "$RETURN_FAILURE"
	}
	shell::console::print "[k] Key: $key" 33
	printf '%s\n' "$(_shell::conf::b64decode "$encoded")"
}

# @internal
# @description Ask for a new value (hidden input) and store it, Base64-encoded, for a key.
# @arg $1 string The key.
# @arg $2 string `true` for dry-run.
# @exitcode 0 Updated (or printed in dry-run mode).
# @exitcode 1 The key is protected, the input was empty or the write failed.
# @example
#   _shell::conf::key::update "MY_KEY" false
#
_shell::conf::key::update() {
	local key="${1-}" dry_run="${2-false}" new_value
	if _shell::conf::key::is_protected "$key"; then
		shell::logger::error "'$key' is a protected key and cannot be modified."
		return "$RETURN_FAILURE"
	fi
	shell::console::print ">> Enter new value for key '$key' (input is hidden):" 33
	read -rs new_value
	printf '\n'
	if [ -z "$new_value" ]; then
		shell::logger::error "No new value entered. Update aborted."
		return "$RETURN_FAILURE"
	fi
	_shell::conf::write "$dry_run" "Updated configuration for key: $key" "$SHELL_KEY_FILE" replace "$key" "$(_shell::conf::b64encode "$new_value")"
}

# @internal
# @description Ask for a new name and rename a key (the value is untouched).
# @arg $1 string The key.
# @arg $2 string `true` for dry-run.
# @exitcode 0 Renamed (or printed in dry-run mode).
# @exitcode 1 The key is protected, the name is empty or taken, or the write failed.
# @example
#   _shell::conf::key::rename "OLD_KEY" false
#
_shell::conf::key::rename() {
	local old_key="${1-}" dry_run="${2-false}" new_key
	if _shell::conf::key::is_protected "$old_key"; then
		shell::logger::error "'$old_key' is a protected key and cannot be modified."
		return "$RETURN_FAILURE"
	fi
	shell::console::print "Enter new key name for '$old_key':" 33
	read -r new_key
	if [ -z "$new_key" ]; then
		shell::logger::error "No new key name entered. Aborting rename."
		return "$RETURN_FAILURE"
	fi
	new_key="$(shell::strings::sanitize::upper "$new_key")"
	if _shell::conf::entry "$SHELL_KEY_FILE" "$new_key" >/dev/null; then
		shell::logger::error "Key '$new_key' already exists. Aborting rename."
		return "$RETURN_FAILURE"
	fi
	_shell::conf::write "$dry_run" "Renamed key '$old_key' to '$new_key'" "$SHELL_KEY_FILE" rename "$old_key" "$new_key"
}

# @internal
# @description Remove a key (and the comment written directly above it) after a yes/no confirmation.
# @arg $1 string The key.
# @arg $2 string `true` for dry-run (no confirmation, nothing is removed).
# @exitcode 0 Removed, declined (nothing changed) or printed in dry-run mode.
# @exitcode 1 The key is protected or the write failed.
# @example
#   _shell::conf::key::remove "MY_KEY" false
#
_shell::conf::key::remove() {
	local key="${1-}" dry_run="${2-false}" answer
	if _shell::conf::key::is_protected "$key"; then
		shell::logger::error "'$key' is a protected key and cannot be modified."
		return "$RETURN_FAILURE"
	fi
	if [ "$dry_run" != "true" ]; then
		answer="$(shell::ask::reply "Remove the key '${key}'?")"
		if [ "$answer" != "yes" ]; then
			shell::logger::info "Nothing was removed"
			return "$RETURN_SUCCESS"
		fi
	fi
	_shell::conf::write "$dry_run" "Removed configuration for key: $key" "$SHELL_KEY_FILE" delete "$key"
}

# @internal
# @description The action menu of one key: copy, reveal, update, rename, remove, back. Protected keys only get
#   the read actions, and the header says why. Runs one action and returns, so the caller shows the list again.
# @arg $1 string The key.
# @arg $2 string `true` for dry-run.
# @arg $3 string The work directory.
# @exitcode 0 Always (the outcome of the action is logged; Back and ESC just return).
# @example
#   _shell::conf::key::hub "MY_KEY" false "$work"
#
_shell::conf::key::hub() {
	local key="${1-}" dry_run="${2-false}" work="${3-}" back="$SHELL_FZF_BACK_LABEL"
	local items header action nl=$'\n'
	items="Copy value${nl}Reveal value"
	header="Key ${key}   Enter: run   ESC: back"
	if _shell::conf::key::is_protected "$key"; then
		header="Key ${key} — protected: update, rename and remove are disabled"
	else
		items="${items}${nl}Update value${nl}Rename key${nl}Remove key"
	fi
	items="${items}${nl}${back}"
	action="$(printf '%s\n' "$items" | shell::fzf::select \
		--prompt="Action: " --header="$header" \
		--preview="sh $(_shell::conf::sq "$work/preview.sh") key $(_shell::conf::sq "$key")" \
		--preview-window="right:55%:wrap" --height=60%)" || return "$RETURN_SUCCESS"
	case "$action" in
	"Copy value") _shell::conf::key::copy "$key" "$dry_run" || true ;;
	"Reveal value") _shell::conf::key::reveal "$key" || true ;;
	"Update value") _shell::conf::key::update "$key" "$dry_run" || true ;;
	"Rename key") _shell::conf::key::rename "$key" "$dry_run" || true ;;
	"Remove key") _shell::conf::key::remove "$key" "$dry_run" || true ;;
	esac
	return "$RETURN_SUCCESS"
}

# @internal
# @description Pick one or more keys (multi-select with the masked live preview and a Back row).
# @arg $1 string The work directory.
# @arg $2 string The prompt.
# @arg $3 string The header.
# @stdout The selected keys, one per line, without the Back row.
# @exitcode 0 Keys were selected.
# @exitcode 1 Nothing was selected (ESC, or no key exists).
# @exitcode 11 The Back row was part of the selection; nothing is returned.
# @example
#   keys="$(_shell::conf::key::pick_many "$work" "Keys: " "TAB: mark")" || return
#
_shell::conf::key::pick_many() {
	local work="${1-}" prompt="${2-}" header="${3-}" list picked
	list="$(_shell::conf::list key)"
	[ -n "$list" ] || return "$RETURN_FAILURE"
	picked="$(_shell::conf::pick "$work" key "$prompt" "$header" "" "$list" --multi)" || return "$RETURN_FAILURE"
	if printf '%s\n' "$picked" | grep -qxF -- "$SHELL_FZF_BACK_LABEL"; then
		return "$RETURN_BACK"
	fi
	picked="$(printf '%s\n' "$picked" | grep -v '^$' || true)"
	[ -n "$picked" ] || return "$RETURN_FAILURE"
	printf '%s\n' "$picked"
}

# @internal
# @description Update the keys of a group: multi-select from every key, then store the new membership.
#   Back in the key picker returns to the caller without writing.
# @arg $1 string The group.
# @arg $2 string `true` for dry-run.
# @arg $3 string The work directory.
# @exitcode 0 Updated (or printed in dry-run mode).
# @exitcode 1 Nothing was selected or the write failed.
# @exitcode 11 Back; nothing was changed.
# @example
#   _shell::conf::group::update "DB" false "$work"
#
_shell::conf::group::update() {
	local group="${1-}" dry_run="${2-false}" work="${3-}" picked rc=0 csv
	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return "$RETURN_FAILURE"
	fi
	picked="$(_shell::conf::key::pick_many "$work" "Select new keys for group '$group': " "TAB: mark   Enter: confirm   ${SHELL_FZF_BACK_LABEL}: previous")" || rc=$?
	if [ "$rc" -eq "$RETURN_BACK" ]; then
		shell::logger::info "Back — nothing was updated"
		return "$RETURN_BACK"
	fi
	if [ "$rc" -ne 0 ]; then
		shell::logger::error "No keys selected. Aborting update."
		return "$RETURN_FAILURE"
	fi
	csv="$(printf '%s\n' "$picked" | paste -sd "," -)"
	_shell::conf::write "$dry_run" "Updated group '$group' with new keys: $csv" "$SHELL_KEY_GROUP_FILE" replace "$group" "$csv"
}

# @internal
# @description Ask for a new name and rename a group (its keys are untouched).
# @arg $1 string The group.
# @arg $2 string `true` for dry-run.
# @exitcode 0 Renamed (or printed in dry-run mode).
# @exitcode 1 The name is empty or already taken, or the write failed.
# @example
#   _shell::conf::group::rename "OLD" false
#
_shell::conf::group::rename() {
	local old_group="${1-}" dry_run="${2-false}" new_group
	shell::console::print "[e] Enter new name for group '$old_group':" 208
	read -r new_group
	if [ -z "$new_group" ]; then
		shell::logger::error "No new group name entered. Aborting rename."
		return "$RETURN_FAILURE"
	fi
	new_group="$(shell::strings::sanitize::upper "$new_group")"
	if _shell::conf::entry "$SHELL_KEY_GROUP_FILE" "$new_group" >/dev/null; then
		shell::logger::error "Group '$new_group' already exists. Aborting rename."
		return "$RETURN_FAILURE"
	fi
	_shell::conf::write "$dry_run" "Renamed group '$old_group' to '$new_group'" "$SHELL_KEY_GROUP_FILE" rename "$old_group" "$new_group"
}

# @internal
# @description Remove a group after a yes/no confirmation (the keys themselves are kept).
# @arg $1 string The group.
# @arg $2 string `true` for dry-run (no confirmation, nothing is removed).
# @exitcode 0 Removed, declined (nothing changed) or printed in dry-run mode.
# @exitcode 1 The write failed.
# @example
#   _shell::conf::group::remove "DB" false
#
_shell::conf::group::remove() {
	local group="${1-}" dry_run="${2-false}" answer
	if [ "$dry_run" != "true" ]; then
		answer="$(shell::ask::reply "Remove the group '${group}'?")"
		if [ "$answer" != "yes" ]; then
			shell::logger::info "Nothing was removed"
			return "$RETURN_SUCCESS"
		fi
	fi
	_shell::conf::write "$dry_run" "Removed group: $group" "$SHELL_KEY_GROUP_FILE" delete "$group"
}

# @internal
# @description Ask for a name and create a group with the same keys as another one.
# @arg $1 string The group to clone.
# @arg $2 string `true` for dry-run.
# @exitcode 0 Cloned (or printed in dry-run mode).
# @exitcode 1 The group has no keys, the name is empty or taken, or the write failed.
# @example
#   _shell::conf::group::clone "DB" false
#
_shell::conf::group::clone() {
	local group="${1-}" dry_run="${2-false}" csv new_group
	csv="$(_shell::conf::entry "$SHELL_KEY_GROUP_FILE" "$group")" || {
		shell::logger::error "Group '$group' not found."
		return "$RETURN_FAILURE"
	}
	if [ -z "$csv" ]; then
		shell::logger::error "No keys defined in group '$group'."
		return "$RETURN_FAILURE"
	fi
	shell::console::print "[e] Enter new group name for the clone of '$group':" 208
	read -r new_group
	if [ -z "$new_group" ]; then
		shell::logger::error "No new group name entered. Aborting clone."
		return "$RETURN_FAILURE"
	fi
	new_group="$(shell::strings::sanitize::upper "$new_group")"
	if _shell::conf::entry "$SHELL_KEY_GROUP_FILE" "$new_group" >/dev/null; then
		shell::logger::error "Group '$new_group' already exists."
		return "$RETURN_FAILURE"
	fi
	_shell::conf::write "$dry_run" "Created new group '$new_group' as a clone of '$group' with keys: $csv" "$SHELL_KEY_GROUP_FILE" upsert "$new_group" "$csv"
}

# @internal
# @description Browse the keys of one group: key list with the masked preview, then the key action menu, then the
#   key list again. Back returns to the caller (the group list).
# @arg $1 string The group.
# @arg $2 string `true` for dry-run.
# @arg $3 string The work directory.
# @exitcode 0 Always.
# @example
#   _shell::conf::group::keys "DB" false "$work"
#
_shell::conf::group::keys() {
	local group="${1-}" dry_run="${2-false}" work="${3-}" csv list selected initial=""
	while true; do
		csv="$(_shell::conf::entry "$SHELL_KEY_GROUP_FILE" "$group")" || return "$RETURN_SUCCESS"
		list="$(printf '%s\n' "$csv" | tr ',' '\n' | grep -v '^$' || true)"
		if [ -z "$list" ]; then
			shell::logger::error "No keys defined in group '$group'."
			return "$RETURN_SUCCESS"
		fi
		selected="$(_shell::conf::pick "$work" key "Select a key from group '$group': " "Enter: actions   ESC / ${SHELL_FZF_BACK_LABEL}: previous" "$initial" "$list")" || return "$RETURN_SUCCESS"
		if [ -z "$selected" ] || [ "$selected" = "$SHELL_FZF_BACK_LABEL" ]; then
			return "$RETURN_SUCCESS"
		fi
		initial="$selected"
		_shell::conf::key::hub "$selected" "$dry_run" "$work"
	done
}

# @internal
# @description The action menu of one group: copy as JSON, view keys, update keys, rename, clone, remove, back.
#   Runs one action and returns, so the caller shows the group list again.
# @arg $1 string The group.
# @arg $2 string `true` for dry-run.
# @arg $3 string The work directory.
# @exitcode 0 Always (the outcome of the action is logged).
# @example
#   _shell::conf::group::hub "DB" false "$work"
#
_shell::conf::group::hub() {
	local group="${1-}" dry_run="${2-false}" work="${3-}" back="$SHELL_FZF_BACK_LABEL" action json rc=0 nl=$'\n'
	action="$(printf '%s\n' "Copy as JSON${nl}View keys${nl}Update keys${nl}Rename${nl}Clone${nl}Remove${nl}${back}" | shell::fzf::select \
		--prompt="Action: " --header="Group ${group}   Enter: run   ESC: back" \
		--preview="sh $(_shell::conf::sq "$work/preview.sh") group $(_shell::conf::sq "$group")" \
		--preview-window="right:55%:wrap" --height=60%)" || return "$RETURN_SUCCESS"
	case "$action" in
	"Copy as JSON")
		json="$(_shell::conf::group::json "$group")" || rc=$?
		if [ "$rc" -ne 0 ]; then
			shell::logger::error "Group '$group' has no keys to copy."
		else
			_shell::conf::copy "JSON of group ${group}" "$json" "$dry_run" "<JSON of group ${group}>" || true
		fi
		;;
	"View keys") _shell::conf::group::keys "$group" "$dry_run" "$work" ;;
	"Update keys") _shell::conf::group::update "$group" "$dry_run" "$work" || true ;;
	"Rename") _shell::conf::group::rename "$group" "$dry_run" || true ;;
	"Clone") _shell::conf::group::clone "$group" "$dry_run" || true ;;
	"Remove") _shell::conf::group::remove "$group" "$dry_run" || true ;;
	esac
	return "$RETURN_SUCCESS"
}

# @internal
# @description Protect a key (adds it to protected.conf through shell::conf::protected::add).
# @arg $1 string The key.
# @arg $2 string `true` for dry-run.
# @exitcode 0 Protected (or already protected, or printed in dry-run mode).
# @exitcode 1 The write failed.
# @example
#   _shell::conf::protected::protect "MY_KEY" false
#
_shell::conf::protected::protect() {
	if [ "${2-false}" = "true" ]; then
		shell::conf::protected::add "-n" "${1-}"
	else
		shell::conf::protected::add "${1-}"
	fi
}

# @internal
# @description Remove a key from protected.conf after a yes/no confirmation. Keys protected by the built-in
#   SHELL_PROTECTED_KEYS list stay protected.
# @arg $1 string The key.
# @arg $2 string `true` for dry-run (no confirmation, nothing is removed).
# @exitcode 0 Removed, declined (nothing changed) or printed in dry-run mode.
# @exitcode 1 The write failed.
# @example
#   _shell::conf::protected::unprotect "MY_KEY" false
#
_shell::conf::protected::unprotect() {
	local key="${1-}" dry_run="${2-false}" answer
	if [ "$dry_run" != "true" ]; then
		answer="$(shell::ask::reply "Stop protecting the key '${key}'?")"
		if [ "$answer" != "yes" ]; then
			shell::logger::info "Nothing was changed"
			return "$RETURN_SUCCESS"
		fi
	fi
	_shell::conf::write "$dry_run" "Removed protected key: $key" "$SHELL_KEY_PROTECTED_FILE" delete_line "$key"
}

# @internal
# @description The select -> action -> select loop shared by every interactive menu of this file.
#
#   Each pass rebuilds the list (so renames, removals and updates show immediately), shows it with the masked
#   live preview, runs the action for the picked name and shows the list again. Cancelling (ESC / Ctrl-C) or an
#   empty list on the first pass keeps the classic behaviour (error, return 1); after at least one action ESC
#   just closes the loop. The Back row returns SHELL_FZF_BACK_LABEL's code (11).
# @arg $1 string The kind of list: `key`, `group` or `protected`.
# @arg $2 string The action: `hub`, `update`, `rename`, `remove`, `clone`, `protect` (kind `key`) or `unprotect` (kind `protected`).
# @arg $3 string `true` for dry-run.
# @arg $4 string The prompt.
# @arg $5 string The verb of the "Back — nothing was <verb>" message.
# @arg $6 string The error shown when nothing can be selected on the first pass.
# @exitcode 0 The loop was closed after at least one action, or an empty list was reached.
# @exitcode 1 Nothing could be selected on the first pass.
# @exitcode 11 The user picked the "← Back" row.
# @example
#   _shell::conf::browse key update false "Select config key to update: " updated "No configuration selected."
#
_shell::conf::browse() {
	local kind="${1-key}" action="${2-hub}" dry_run="${3-false}" prompt="${4-}" verb="${5-changed}" empty="${6-Nothing to select.}"
	local work rc=0
	work="$(mktemp -d "${TMPDIR:-/tmp}/shell-conf.XXXXXX")" || {
		shell::logger::error "Could not create a temporary directory."
		return "$RETURN_FAILURE"
	}
	_shell::conf::browse::loop "$kind" "$action" "$dry_run" "$prompt" "$verb" "$empty" "$work" || rc=$?
	rm -rf "$work"
	return "$rc"
}

# @internal
# @description The loop body of _shell::conf::browse (see there).
# @arg $1 string The kind of list.
# @arg $2 string The action.
# @arg $3 string `true` for dry-run.
# @arg $4 string The prompt.
# @arg $5 string The verb.
# @arg $6 string The empty-list error.
# @arg $7 string The work directory.
# @exitcode 0 Closed after at least one action.
# @exitcode 1 Nothing could be selected on the first pass.
# @exitcode 11 Back.
# @example
#   _shell::conf::browse::loop key hub false "Select config key: " displayed "No configuration selected." "$work"
#
_shell::conf::browse::loop() {
	local kind="$1" action="$2" dry_run="$3" prompt="$4" verb="$5" empty="$6" work="$7"
	local back="$SHELL_FZF_BACK_LABEL" list selected header initial="" passes=0 pk="key" rc
	if [ "$kind" = "group" ]; then pk="group"; fi
	header="Enter: select   ESC: leave   ${back}: previous"
	while true; do
		_shell::conf::preview::init "$work"
		list="$(_shell::conf::list "$kind")"
		if [ -z "$list" ]; then
			if [ "$passes" -eq 0 ]; then
				shell::logger::error "$empty"
				return "$RETURN_FAILURE"
			fi
			shell::logger::info "Nothing left to select"
			return "$RETURN_SUCCESS"
		fi
		rc=0
		selected="$(_shell::conf::pick "$work" "$pk" "$prompt" "$header" "$initial" "$list")" || rc=$?
		if [ "$rc" -ne 0 ] || [ -z "$selected" ]; then
			if [ "$passes" -eq 0 ]; then
				shell::logger::error "$empty"
				return "$RETURN_FAILURE"
			fi
			shell::logger::info "Closed"
			return "$RETURN_SUCCESS"
		fi
		if [ "$selected" = "$back" ]; then
			if [ "$passes" -eq 0 ]; then
				shell::logger::info "Back — nothing was ${verb}"
			else
				shell::logger::info "Back"
			fi
			return "$RETURN_BACK"
		fi
		initial="$selected"
		passes=$((passes + 1))
		case "${kind}:${action}" in
		key:hub) _shell::conf::key::hub "$selected" "$dry_run" "$work" ;;
		key:update) _shell::conf::key::update "$selected" "$dry_run" || true ;;
		key:rename) _shell::conf::key::rename "$selected" "$dry_run" || true ;;
		key:remove) _shell::conf::key::remove "$selected" "$dry_run" || true ;;
		group:hub) _shell::conf::group::hub "$selected" "$dry_run" "$work" ;;
		group:update) _shell::conf::group::update "$selected" "$dry_run" "$work" || true ;;
		group:rename) _shell::conf::group::rename "$selected" "$dry_run" || true ;;
		group:remove) _shell::conf::group::remove "$selected" "$dry_run" || true ;;
		group:clone) _shell::conf::group::clone "$selected" "$dry_run" || true ;;
		protected:unprotect) _shell::conf::protected::unprotect "$selected" "$dry_run" || true ;;
		*:protect) _shell::conf::protected::protect "$selected" "$dry_run" || true ;;
		esac
	done
}

# @description Interactively selects a configuration key with a live, masked preview, then runs an action on it.
#
#   The list shows every key of SHELL_KEY_FILE. While you move the cursor, the preview pane shows the key, whether it is
#   protected (lock), the `#` comment above it, the groups that contain it and the value MASKED (first two characters,
#   bullets and length). Enter opens an action menu: Copy value, Reveal value, Update value, Rename key, Remove key
#   (the last three are hidden for protected keys, and the header says why) and "← Back". When the action finishes the
#   list comes back with the cursor kept and the data refreshed, so the flow is list -> action -> list.
#   The value is copied by the function itself (not by fzf) with shell::clipboard::copy, on every pass, byte for byte;
#   without a clipboard tool it is printed with a warning. An empty value is never copied.
#   A trailing "← Back" entry (SHELL_FZF_BACK_LABEL) leaves without changing anything; ESC / Ctrl-C ends the loop.
# @option -n Optional dry-run flag. If provided, copy and write commands are printed using shell::logger::command_clip instead of executed.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success (the loop was closed after at least one action).
# @exitcode 1 The operation failed (no key file, no key, or nothing selected).
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL).
# @example
#   shell::conf::key::get::fzf      # Browse keys, copy a value, come back to the list.
#   shell::conf::key::get::fzf -n   # Dry-run: nothing is copied or written.
#
shell::conf::key::get::fzf() {
	local dry_run="false"
	if [ "${1-}" = "-n" ]; then
		dry_run="true"
		shift
	fi
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a configuration key with a live masked preview, then copies, reveals, updates, renames or removes it (loops back to the list)"
		shell::logger::usage "shell::conf::key::get::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, copy and write commands are printed instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::conf::key::get::fzf"
		shell::logger::note "The list comes back after every action; leave with ESC or '$SHELL_FZF_BACK_LABEL' (returns ${RETURN_BACK})."
		return $RETURN_SUCCESS
	fi

	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure
	_shell::conf::browse key hub "$dry_run" "Select config key: " displayed "No configuration selected."
}

# @description Interactively selects a configuration key using fzf, with a live masked preview, and copies its value.
#
#   This is the same live browser as shell::conf::key::get::fzf: the preview shows the key, its protected status, its
#   comment, its groups and the masked value; Enter opens the action menu (Copy value first), and the list comes back after
#   every action. Nothing secret is printed unless you pick "Reveal value".
#   A trailing "← Back" entry lets you leave without changing anything.
# @option -n Optional dry-run flag. If provided, the clipboard copy command is printed instead of executed.
# @option -h Optional help flag. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::conf::key::view::fzf         # Select a key and copy its decoded value.
#   shell::conf::key::view::fzf -n      # Dry-run: print the clipboard copy command.
#
shell::conf::key::view::fzf() {
	local dry_run="false"
	if [ "${1-}" = "-n" ]; then
		dry_run="true"
		shift
	fi
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a configuration key using fzf with a live masked preview and copies its decoded value (loops back to the list)"
		shell::logger::usage "shell::conf::key::view::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the clipboard copy command is printed instead of executed."
		shell::logger::option "-h" "Optional help flag. Displays this help message."
		shell::logger::note "The list comes back after every action; leave with ESC or '$SHELL_FZF_BACK_LABEL' (returns ${RETURN_BACK})."
		return $RETURN_SUCCESS
	fi

	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure || {
		shell::logger::error "fzf is required but could not be installed."
		return 1
	}
	_shell::conf::browse key hub "$dry_run" "Select config key: " copied "No configuration key selected."
}

# @description Interactively selects a configuration key (live masked preview) and removes its entry, then shows the list again.
#
#   The list is rebuilt after every removal. The entry (and the `#` comment written directly above it) is dropped by an
#   atomic rewrite of SHELL_KEY_FILE, with the key matched literally. Protected keys cannot be removed, and a yes/no
#   confirmation is asked before anything is deleted. In dry-run mode the command is printed using shell::logger::command_clip.
#   A trailing "← Back" entry lets you leave without changing anything.
# @option -n Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::conf::key::remove::fzf         # Interactively select a key and remove its configuration entry.
#   shell::conf::key::remove::fzf -n      # Prints the removal command without executing it.
#
shell::conf::key::remove::fzf() {
	local dry_run="false"
	if [ "${1-}" = "-n" ]; then
		dry_run="true"
		shift
	fi
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a configuration key (live masked preview) and removes its entry from the configuration file"
		shell::logger::usage "shell::conf::key::remove::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::conf::key::remove::fzf"
		shell::logger::example "shell::conf::key::remove::fzf -n"
		shell::logger::note "The list comes back after every removal; leave with ESC or '$SHELL_FZF_BACK_LABEL' (returns ${RETURN_BACK})."
		return $RETURN_SUCCESS
	fi

	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure
	_shell::conf::browse key remove "$dry_run" "Select config key to remove: " removed "No configuration selected."
}

# @description Interactively updates the value of a configuration key (live masked preview), then shows the list again.
#
#   Pick a key, type the new value (the input is hidden), and the value is Base64-encoded and written by an atomic
#   rewrite of SHELL_KEY_FILE. The key is matched literally and Base64 containing `/`, `+` or `&` is safe. Protected keys
#   cannot be updated. When the update is done the list comes back with refreshed data, so the preview shows the change.
#   A trailing "← Back" entry lets you leave without changing anything.
# @option -n Optional dry-run flag. If provided, the update command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::conf::key::update::fzf       # Interactively select a key, enter a new value, and update its entry.
#   shell::conf::key::update::fzf -n    # Prints the update command without executing it.
#
shell::conf::key::update::fzf() {
	local dry_run="false"
	if [ "${1-}" = "-n" ]; then
		dry_run="true"
		shift
	fi
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively updates the value for a configuration key (live masked preview) in a constant configuration file"
		shell::logger::usage "shell::conf::key::update::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the update command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::conf::key::update::fzf"
		shell::logger::example "shell::conf::key::update::fzf -n"
		shell::logger::note "The list comes back after every update; leave with ESC or '$SHELL_FZF_BACK_LABEL' (returns ${RETURN_BACK})."
		return $RETURN_SUCCESS
	fi

	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure
	_shell::conf::browse key update "$dry_run" "Select config key to update: " updated "No configuration selected."
}

# @description Renames an existing configuration key (live masked preview), then shows the list again.
#
#   Pick a key and type the new name (upper-cased and sanitised). The key must not exist yet; its value is untouched.
#   The change is an atomic rewrite of SHELL_KEY_FILE with the old key matched literally. Protected keys cannot be renamed.
#   A trailing "← Back" entry lets you leave without changing anything.
# @option -n Optional dry-run flag. If provided, the renaming command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::conf::key::rename::fzf         # Interactively select a key and rename it.
#   shell::conf::key::rename::fzf -n      # Prints the renaming command without executing it.
#
shell::conf::key::rename::fzf() {
	local dry_run="false"
	if [ "${1-}" = "-n" ]; then
		dry_run="true"
		shift
	fi
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Renames an existing configuration key (live masked preview) in the key configuration file"
		shell::logger::usage "shell::conf::key::rename::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the renaming command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::conf::key::rename::fzf"
		shell::logger::example "shell::conf::key::rename::fzf -n"
		shell::logger::note "The list comes back after every rename; leave with ESC or '$SHELL_FZF_BACK_LABEL' (returns ${RETURN_BACK})."
		return $RETURN_SUCCESS
	fi

	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure
	_shell::conf::browse key rename "$dry_run" "Select config key to rename: " renamed "No key selected. Aborting rename."
}

# @description Groups selected configuration keys under a specified group name.
#
#   This function prompts you to enter a group name, then uses fzf (through shell::fzf::select, multi-select, with the
#   live masked key preview) to let you choose one or more configuration keys (from SHELL_KEY_FILE). It then stores the group in
#   SHELL_KEY_GROUP_FILE in the format:
#   group_name=key1,key2,...,keyN
#   If the group name already exists, the group entry is updated with the new selection (atomic rewrite, name matched literally).
#   Picking the "← Back" entry (SHELL_FZF_BACK_LABEL), alone or together with keys, writes nothing; a selection without it
#   is used as is. An optional dry-run flag (-n) prints the command via shell::logger::command_clip instead of executing it.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::conf::group::add::fzf         # Prompts for a group name and lets you select keys to group.
#   shell::conf::group::add::fzf -n      # Prints the command for creating/updating the group without executing it.
#
shell::conf::group::add::fzf() {
	local dry_run="false"
	if [ "${1-}" = "-n" ]; then
		dry_run="true"
		shift
	fi
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Groups selected configuration keys under a specified group name"
		shell::logger::usage "shell::conf::group::add::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::conf::group::add::fzf"
		shell::logger::example "shell::conf::group::add::fzf -n"
		shell::logger::note "Pick '$SHELL_FZF_BACK_LABEL' to leave without writing anything (returns ${RETURN_BACK})."
		return $RETURN_SUCCESS
	fi

	# Ensure the group configuration file exists.
	shell::fs::touch --private "$SHELL_KEY_GROUP_FILE"
	shell::permission::secure "$SHELL_KEY_GROUP_FILE"

	# Prompt the user for a group name.
	local group_name
	shell::console::print "[e] Enter group name:" 208
	read -r group_name
	if [ -z "$group_name" ]; then
		shell::logger::error "No group name entered. Aborting."
		return 1
	fi

	# Ensure the individual configuration file exists.
	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure

	# Sanitize the group name so it is a safe identifier.
	group_name=$(shell::strings::sanitize::upper "$group_name")

	local work rc=0 selected_keys
	work="$(mktemp -d "${TMPDIR:-/tmp}/shell-conf.XXXXXX")" || {
		shell::logger::error "Could not create a temporary directory."
		return 1
	}
	_shell::conf::preview::init "$work"
	selected_keys="$(_shell::conf::key::pick_many "$work" "Select config keys for group '$group_name': " "TAB: mark   Enter: confirm   ${SHELL_FZF_BACK_LABEL}: cancel")" || rc=$?
	rm -rf "$work"

	if [ "$rc" -eq "$RETURN_BACK" ]; then
		shell::logger::info "Back — nothing was grouped"
		return "$RETURN_BACK"
	fi
	if [ "$rc" -ne 0 ]; then
		shell::logger::error "No keys selected. Aborting group creation."
		return 1
	fi

	# Convert the multi-line selection to a comma-separated list.
	local keys_csv
	keys_csv=$(printf '%s\n' "$selected_keys" | paste -sd "," -)

	# If the group already exists, update it; otherwise, append it.
	if _shell::conf::entry "$SHELL_KEY_GROUP_FILE" "$group_name" >/dev/null; then
		_shell::conf::write "$dry_run" "Updated group '$group_name' with keys: $keys_csv" "$SHELL_KEY_GROUP_FILE" replace "$group_name" "$keys_csv"
	else
		_shell::conf::write "$dry_run" "Created group '$group_name' with keys: $keys_csv" "$SHELL_KEY_GROUP_FILE" upsert "$group_name" "$keys_csv"
	fi
}

# @description Interactively selects a group (live masked preview), then runs an action on it.
#
#   The preview shows the group name, how many keys it has and each key with a status (present or missing in SHELL_KEY_FILE)
#   and its masked value. Enter opens an action menu: Copy as JSON (the JSON is valid: quotes, backslashes and newlines
#   in values are escaped), View keys (a key list with the same masked preview and the key action menu), Update keys, Rename,
#   Clone, Remove and "← Back". After every action the group list comes back with refreshed data.
#   A trailing "← Back" entry lets you leave without changing anything; ESC / Ctrl-C ends the loop.
# @option -n Optional dry-run flag. If provided, copy and write commands are printed instead of executed.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success (the loop was closed after at least one action).
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::conf::group::view::fzf   # Browse groups, copy one as JSON or open its keys.
#
shell::conf::group::view::fzf() {
	local dry_run="false"
	if [ "${1-}" = "-n" ]; then
		dry_run="true"
		shift
	fi
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a group (live masked preview), then copies it as JSON, views its keys, updates, renames, clones or removes it (loops back to the list)"
		shell::logger::usage "shell::conf::group::view::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, copy and write commands are printed instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::note "The list comes back after every action; leave with ESC or '$SHELL_FZF_BACK_LABEL' (returns ${RETURN_BACK})."
		return $RETURN_SUCCESS
	fi

	# Ensure the group configuration file exists.
	if [ ! -f "$SHELL_KEY_GROUP_FILE" ]; then
		shell::logger::error "Group configuration file '$SHELL_KEY_GROUP_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure
	_shell::conf::browse group hub "$dry_run" "Select a group name: " displayed "No group selected."
}

# @description Interactively selects a group (live masked preview) and removes its entry, then shows the list again.
#
#   The group is dropped by an atomic rewrite of SHELL_KEY_GROUP_FILE with the name matched literally; the keys themselves are
#   kept. A yes/no confirmation is asked first. In dry-run mode the command is printed via shell::logger::command_clip.
#   A trailing "← Back" entry lets you leave without changing anything.
# @option -n Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::conf::group::remove::fzf         # Interactively select a group and remove its entry.
#   shell::conf::group::remove::fzf -n      # Prints the removal command without executing it.
#
shell::conf::group::remove::fzf() {
	local dry_run="false"
	if [ "${1-}" = "-n" ]; then
		dry_run="true"
		shift
	fi
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a group (live masked preview) and removes its entry from the group configuration file"
		shell::logger::usage "shell::conf::group::remove::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::conf::group::remove::fzf"
		shell::logger::example "shell::conf::group::remove::fzf -n"
		shell::logger::note "The list comes back after every removal; leave with ESC or '$SHELL_FZF_BACK_LABEL' (returns ${RETURN_BACK})."
		return $RETURN_SUCCESS
	fi

	if [ ! -f "$SHELL_KEY_GROUP_FILE" ]; then
		shell::logger::error "Group configuration file '$SHELL_KEY_GROUP_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure
	_shell::conf::browse group remove "$dry_run" "Select a group to remove: " removed "No group selected."
}

# @description Interactively updates an existing group by letting you select new keys for that group.
#
#   Pick a group (live masked preview), then choose its new keys in a multi-select list of every key (same masked preview,
#   through shell::fzf::select). "← Back" in the key list returns to the group list without writing; the group entry is
#   rewritten atomically with the name matched literally. After the update the group list comes back with refreshed data.
#   A trailing "← Back" entry in the group list lets you leave without changing anything.
# @option -n Optional dry-run flag. If provided, the update command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::conf::group::update::fzf         # Interactively select a group, update its keys, and update the group entry.
#   shell::conf::group::update::fzf -n      # Prints the update command without executing it.
#
shell::conf::group::update::fzf() {
	local dry_run="false"
	if [ "${1-}" = "-n" ]; then
		dry_run="true"
		shift
	fi
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively updates an existing group by letting you select new keys for that group"
		shell::logger::usage "shell::conf::group::update::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the update command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::conf::group::update::fzf"
		shell::logger::example "shell::conf::group::update::fzf -n"
		shell::logger::note "The group list comes back after every update; leave with ESC or '$SHELL_FZF_BACK_LABEL' (returns ${RETURN_BACK})."
		return $RETURN_SUCCESS
	fi

	if [ ! -f "$SHELL_KEY_GROUP_FILE" ]; then
		shell::logger::error "Group configuration file '$SHELL_KEY_GROUP_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure
	_shell::conf::browse group update "$dry_run" "Select a group to update: " updated "No group selected."
}

# @description Renames an existing group (live masked preview), then shows the list again.
#
#   Pick a group and type the new name (upper-cased and sanitised). The new name must not exist yet; the keys are untouched.
#   The change is an atomic rewrite of SHELL_KEY_GROUP_FILE with the old name matched literally.
#   A trailing "← Back" entry lets you leave without changing anything.
# @option -n Optional dry-run flag. If provided, the renaming command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::conf::group::rename::fzf         # Interactively select a group and rename it.
#   shell::conf::group::rename::fzf -n      # Prints the renaming command without executing it.
#
shell::conf::group::rename::fzf() {
	local dry_run="false"
	if [ "${1-}" = "-n" ]; then
		dry_run="true"
		shift
	fi
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Renames an existing group (live masked preview) in the group configuration file"
		shell::logger::usage "shell::conf::group::rename::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the renaming command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::example "shell::conf::group::rename::fzf"
		shell::logger::example "shell::conf::group::rename::fzf -n"
		shell::logger::note "The list comes back after every rename; leave with ESC or '$SHELL_FZF_BACK_LABEL' (returns ${RETURN_BACK})."
		return $RETURN_SUCCESS
	fi

	if [ ! -f "$SHELL_KEY_GROUP_FILE" ]; then
		shell::logger::error "Group configuration file '$SHELL_KEY_GROUP_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure
	_shell::conf::browse group rename "$dry_run" "Select group to rename: " renamed "No group selected. Aborting rename."
}

# @description Clones an existing group (live masked preview) by creating a new group with the same keys, then shows the list again.
#
#   Pick a group and type a name for the clone (upper-cased and sanitised). The name must not exist yet; the new entry has the
#   same comma-separated keys and is appended to SHELL_KEY_GROUP_FILE by an atomic rewrite.
#   In dry-run mode the command is printed using shell::logger::command_clip.
#   A trailing "← Back" entry lets you leave without changing anything.
# @option -n Optional dry-run flag. If provided, the cloning command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::conf::group::clone::fzf         # Interactively select a group and create a clone with a new group name.
#   shell::conf::group::clone::fzf -n      # Prints the cloning command without executing it.
#
shell::conf::group::clone::fzf() {
	local dry_run="false"
	if [ "${1-}" = "-n" ]; then
		dry_run="true"
		shift
	fi
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Clones an existing group (live masked preview) by creating a new group with the same keys"
		shell::logger::usage "shell::conf::group::clone::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the cloning command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::note "The list comes back after every clone; leave with ESC or '$SHELL_FZF_BACK_LABEL' (returns ${RETURN_BACK})."
		return $RETURN_SUCCESS
	fi

	# Ensure the group configuration file exists.
	if [ ! -f "$SHELL_KEY_GROUP_FILE" ]; then
		shell::logger::error "Group configuration file '$SHELL_KEY_GROUP_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure
	_shell::conf::browse group clone "$dry_run" "Select a group to clone: " cloned "No group selected. Aborting clone."
}

# @description Interactively selects a key (live masked preview) and adds it to the protected list, then shows the list again.
#
#   This function uses fzf to select a key from the configuration file (excluding comments) and adds it to the
#   protected.conf file through shell::conf::protected::add. Protected keys cannot be updated, renamed or removed.
#   A trailing "← Back" entry lets you leave without changing anything.
# @option -n Optional. Dry-run mode. Prints the command without executing it.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::conf::protected::add::fzf
#
shell::conf::protected::add::fzf() {
	local dry_run="false"
	if [ "${1-}" = "-n" ]; then
		dry_run="true"
		shift
	fi
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a key (live masked preview) and adds it to the protected list"
		shell::logger::usage "shell::conf::protected::add::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional. Dry-run mode. Prints the command without executing it."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::note "The list comes back after every addition; leave with ESC or '$SHELL_FZF_BACK_LABEL' (returns ${RETURN_BACK})."
		return $RETURN_SUCCESS
	fi

	# Ensure the configuration file exists.
	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure
	_shell::conf::browse key protect "$dry_run" "Select key to protect: " protected "No key selected."
}

# @description Interactively selects a protected key (live masked preview) and removes it from protected.conf, then shows the list again.
#
#   This function reads the protected.conf file, uses fzf to let the user select a key, and removes it by an atomic
#   rewrite after a yes/no confirmation. Keys protected by the built-in SHELL_PROTECTED_KEYS list stay protected.
#   In dry-run mode, the command is printed instead of executed.
#   A trailing "← Back" entry lets you leave without changing anything.
# @option -n Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @exitcode 11 The user picked the "← Back" entry (SHELL_FZF_BACK_LABEL); nothing was changed.
# @example
#   shell::conf::protected::remove::fzf
#
shell::conf::protected::remove::fzf() {
	local dry_run="false"
	if [ "${1-}" = "-n" ]; then
		dry_run="true"
		shift
	fi
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Interactively selects a protected key (live masked preview) and removes it from protected.conf"
		shell::logger::usage "shell::conf::protected::remove::fzf [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the removal command is printed using shell::logger::command_clip instead of executed."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::note "The list comes back after every removal; leave with ESC or '$SHELL_FZF_BACK_LABEL' (returns ${RETURN_BACK})."
		return $RETURN_SUCCESS
	fi

	# Check if the protected.conf file exists.
	if [ ! -f "$SHELL_KEY_PROTECTED_FILE" ]; then
		shell::logger::error "Protected key file '$SHELL_KEY_PROTECTED_FILE' not found."
		return 1
	fi

	shell::dependency::fzf::ensure
	_shell::conf::browse protected unprotect "$dry_run" "Select protected key to remove: " removed "No key selected."
}

# @description Retrieves and outputs the decoded value for a given configuration key from the key configuration file.
#
#   This function searches for the specified key in the configuration file defined by SHELL_KEY_FILE.
#   The configuration file is expected to have entries in the format:
#   key=encoded_value
#   If the key is found, the function decodes the associated Base64‑encoded value (using -D on macOS and -d on Linux)
#   and outputs the decoded value to standard output.
# @arg $1 string key: The configuration key whose value should be retrieved.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::key::get my_setting   # Outputs the decoded value for the key 'my_setting'.
#
shell::conf::key::get() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Retrieves and outputs the decoded value for a given configuration key from the key configuration file"
		shell::logger::usage "shell::conf::key::get [-h] <key>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "key" "The configuration key whose value should be retrieved."
		shell::logger::example "shell::conf::key::get my_setting"
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::conf::key::get [-h] <key>"
		return 1
	fi

	local key
	key="$(shell::strings::sanitize::upper "$1")"

	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	local encoded_value
	encoded_value="$(_shell::conf::entry "$SHELL_KEY_FILE" "$key")" || {
		shell::logger::error "Key '$key' not found in configuration."
		return 1
	}

	printf '%s\n' "$(_shell::conf::b64decode "$encoded_value")"
}

# @description Checks if a configuration key exists in the key configuration file.
#
#   This function searches for the specified key in the configuration file defined by SHELL_KEY_FILE.
#   The configuration file should have entries in the format:
#   key=encoded_value
#   If a line starting with "key=" is found, the function echoes "true" and returns 0.
#   Otherwise, it echoes "false" and returns 1.
#
#   Sample Usage:
#   # Using the exit status:
#   if shell::conf::key::exists my_setting; then
#   echo "Key 'my_setting' exists."
#   else
#   echo "Key 'my_setting' does not exist."
#   fi
#
#   # Capturing the output:
#   result=$(shell::conf::key::exists my_setting)
#   if [ "$result" = "true" ]; then
#   echo "Key 'my_setting' exists."
#   else
#   echo "Key 'my_setting' does not exist."
#   fi
# @arg $1 string key: The configuration key to check.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::key::exists my_setting   # Echoes "true" and returns 0 if 'my_setting' exists; otherwise, echoes "false" and returns 1.
#
shell::conf::key::exists() {
	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Checks if a configuration key exists in the key configuration file"
		shell::logger::usage "shell::conf::key::exists [-h] <key>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "key" "The configuration key to check."
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::conf::key::exists [-h] <key>"
		return 1
	fi

	local key
	key="$(shell::strings::sanitize::upper "$1")"

	if [ ! -f "$SHELL_KEY_FILE" ]; then
		shell::logger::error "Configuration file '$SHELL_KEY_FILE' not found."
		return 1
	fi

	if _shell::conf::entry "$SHELL_KEY_FILE" "$key" >/dev/null; then
		echo "true"
		return 0
	else
		echo "false"
		return 1
	fi
}

# @description Checks if the specified configuration key is protected.
#
#   This function iterates over the SHELL_PROTECTED_KEYS array to determine if the given key is marked as protected.
#   If the key is found in the array, the function echoes "true" and returns 0.
#   Otherwise, it echoes "false" and returns 1.
# @arg $1 string key: The configuration key to check.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   if shell::conf::protected::is "HOST"; then
#   shell::console::print "ERR: 'HOST' is a protected key and cannot be modified." 196
#   return 1
#   fi
#
shell::conf::protected::is() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Checks if the specified configuration key is protected"
		shell::logger::usage "shell::conf::protected::is [-h] <key>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "key" "The configuration key to check."
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::conf::protected::is <key>"
		return 1
	fi

	local key="$1"
	local file="$SHELL_KEY_PROTECTED_FILE"

	# Check if the key exists in the protected configuration file.
	# If the key is found, echo "true" and return 0.
	if [ -f "$file" ] && grep -qxF -- "$key" "$file"; then
		echo "true"
		return 0
	fi

	# If the key is not found in the protected configuration file,
	# check against the SHELL_PROTECTED_KEYS array.
	if [ -z "${SHELL_PROTECTED_KEYS+x}" ]; then
		shell::logger::error "SHELL_PROTECTED_KEYS array is not defined."
		return 1
	fi
	# Iterate over the SHELL_PROTECTED_KEYS array to check if the key is protected.
	# If the key matches any entry in the array, echo "true" and return 0.
	for protected in "${SHELL_PROTECTED_KEYS[@]}"; do
		if [ "$protected" = "$key" ]; then
			echo "true"
			return 0
		fi
	done

	echo "false"
	return 1
}

# @description Reads and displays the configurations for a given group by group name.
#
#   This function looks up the group entry in SHELL_KEY_GROUP_FILE for the specified group name.
#   The group entry is expected to be in the format:
#   group_name=key1,key2,...,keyN
#   For each key in the group, the function retrieves the corresponding configuration entry from SHELL_KEY_FILE,
#   decodes the Base64-encoded value (using -D on macOS and -d on Linux), and groups the key-value pairs
#   into a JSON object which is displayed.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::group::read my_group   # Displays the configurations for the keys in the group 'my_group'.
#
shell::conf::group::read() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Reads and displays the configurations for a given group by group name"
		shell::logger::usage "shell::conf::group::read [-h] <group_name>"
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::conf::group::read [-h] <group_name>"
		return 1
	fi

	local group_name="$1"

	# Check if the group configuration file exists.
	if [ ! -f "$SHELL_KEY_GROUP_FILE" ]; then
		shell::logger::error "Group configuration file '$SHELL_KEY_GROUP_FILE' not found."
		return 1
	fi

	# Sanitize the group name to ensure it is a valid variable name.
	group_name=$(shell::strings::sanitize::upper "$group_name")

	# Retrieve the comma-separated keys of the group (the name is matched literally, not as a regex).
	local keys_csv
	keys_csv="$(_shell::conf::entry "$SHELL_KEY_GROUP_FILE" "$group_name")" || {
		shell::logger::error "Group '$group_name' not found."
		return 1
	}
	if [ -z "$keys_csv" ]; then
		shell::logger::error "No keys defined in group '$group_name'."
		return 1
	fi

	# Values are escaped, so the JSON is valid whatever the values contain.
	local json_obj
	json_obj="$(_shell::conf::group::json "$group_name")"
	shell::console::print "$json_obj" 33 -E
	shell::clipboard::copy --best-effort "$json_obj"
}

# @description Lists all group names defined in the group configuration file.
#
#   This function reads the configuration file defined by SHELL_KEY_GROUP_FILE,
#   where each line is in the format:
#   group_name=key1,key2,...,keyN
#   It extracts and displays the group names (the part before the '=')
#   using the 'cut' command.
# @option -h Optional. Displays this help message.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::group::list       # Displays all group names.
#
shell::conf::group::list() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Lists all group names defined in the group configuration file"
		shell::logger::usage "shell::conf::group::list [-h]"
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	if [ ! -f "$SHELL_KEY_GROUP_FILE" ]; then
		shell::logger::error "Group configuration file '$SHELL_KEY_GROUP_FILE' not found."
		return 1
	fi

	# Extract group names from the configuration file.
	local groups
	groups=$(cut -d '=' -f 1 "$SHELL_KEY_GROUP_FILE")
	if [ -z "$groups" ]; then
		shell::logger::error "No groups found in '$SHELL_KEY_GROUP_FILE'."
		return 1
	fi

	echo "$groups"
}

# @description Synchronizes group configurations by ensuring that each group's keys exist in the key configuration file.
#   If a key listed in a group does not exist, it is removed from that group.
#   If a group ends up with no valid keys, that group entry is removed.
#
#   The function reads each group entry from SHELL_KEY_GROUP_FILE (entries in the format: group_name=key1,key2,...,keyN).
#   For each group, it splits the comma‑separated list of keys and checks each key using shell::conf::key::exists.
#   It builds a new list of valid keys. If the new list is non‑empty, the group entry is updated;
#   if it is empty, the group entry is omitted.
#   In dry‑run mode, the new group configuration is printed via shell::logger::command_clip without modifying the file.
# @option -n Optional dry-run flag. If provided, the new group configuration is printed using shell::logger::command_clip instead of being applied.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::group::sync         # Synchronizes the group configuration file.
#   shell::conf::group::sync -n      # Displays the updated group configuration without modifying the file.
#
shell::conf::group::sync() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Synchronizes group configurations by ensuring that each group's keys exist in the key configuration file"
		shell::logger::usage "shell::conf::group::sync [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the new group configuration is printed using shell::logger::command_clip instead of being applied."
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	if [ ! -f "$SHELL_KEY_GROUP_FILE" ]; then
		shell::logger::error "Group configuration file '$SHELL_KEY_GROUP_FILE' not found."
		return 1
	fi

	shell::logger::debug "Syncing group configuration..."

	# Create a temporary file for the updated configuration.
	local temp_file
	temp_file=$(mktemp) || {
		shell::logger::error "Unable to create temporary file."
		return 1
	}

	# Process each group entry.
	while IFS= read -r line || [ -n "$line" ]; do
		# Skip empty lines.
		[ -z "$line" ] && continue

		# Extract group name and keys.
		local group_name keys_csv
		group_name=$(echo "$line" | cut -d '=' -f 1)
		keys_csv=$(echo "$line" | cut -d '=' -f 2-)
		[ -z "$group_name" ] && continue

		# Build a new comma-separated list of valid keys.
		local new_keys=""
		# Use a portable loop to split keys_csv.
		while IFS= read -r key; do
			if [ "$(shell::conf::key::exists "$key")" = "true" ]; then
				if [ -z "$new_keys" ]; then
					new_keys="$key"
				else
					new_keys="${new_keys},${key}"
				fi
			fi
		done <<<"$(echo "$keys_csv" | tr ',' '\n')"

		if [ -n "$new_keys" ]; then
			echo "${group_name}=${new_keys}" >>"$temp_file"
		else
			shell::logger::warn "Group '$group_name' has no valid keys and will be removed."
		fi
	done <"$SHELL_KEY_GROUP_FILE"

	# If dry-run mode is enabled, print the new configuration and remove the temporary file.
	# Otherwise, replace the original configuration file with the new one.
	if [ "$dry_run" = "true" ]; then
		shell::clipboard::copy --best-effort "$(cat "$temp_file")"
		shell::exec::shell "rm $temp_file"
	else
		local backup_file="$SHELL_KEY_GROUP_BACKUP_FILE"
		# Change end of the backup file with YYYYMMDD format.
		backup_file="${backup_file}_$(date +%Y%m%d_%H%M%S)"
		# Check if the backup file does not exist, and create it if necessary.
		if [ ! -f "$backup_file" ]; then
			shell::fs::touch --private "$backup_file"
		fi
		shell::exec::shell "cp $SHELL_KEY_GROUP_FILE $backup_file"
		shell::exec::shell "mv $temp_file $SHELL_KEY_GROUP_FILE"
		shell::logger::success "Group configuration synchronized successfully."
	fi
}

# @description Adds a key to the protected key list stored in protected.conf.
#
#   This function appends a key to the protected.conf file located at $SHELL_CONFIG_DIR/protected.conf.
#   If the key already exists in the file, it will not be added again.
# @option -n Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed.
# @arg $1 string key: The key to mark as protected.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::protected::add
#
shell::conf::protected::add() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Adds a key to the protected key list stored in protected.conf"
		shell::logger::usage "shell::conf::protected::add [-n] [-h] <key>"
		shell::logger::option "-n" "Optional. Dry-run mode. Prints the command without executing it."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "key" "The key to mark as protected."
		shell::logger::option "-n" "Optional dry-run flag. If provided, the command is printed using shell::logger::command_clip instead of executed."
		shell::logger::item "key" "The key to mark as protected."
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	if [ $# -lt 1 ]; then
		echo "Usage: shell::conf::protected::add [-n] <key>"
		return 1
	fi

	local key="$1"
	local file="$SHELL_KEY_PROTECTED_FILE"

	# Check if the key is provided
	if [ -z "$key" ]; then
		shell::logger::error "No key provided to protect."
		return 1
	fi
	# Ensure the protected.conf file exists and has the correct permissions.
	if [ ! -d "$SHELL_CONFIG_DIR" ]; then
		shell::logger::error "Working directory '$SHELL_CONFIG_DIR' does not exist."
		return 1
	fi

	# Create the protected.conf file if it does not exist.
	# Use shell::fs::touch --private to ensure the file is created.
	# Set permissions to 777 for the file.
	shell::fs::touch --private "$file"
	shell::permission::secure "$file"

	# Check if the key is already protected.
	# Use grep to check if the key is already in the file.
	# The key is considered protected if it matches exactly (no partial matches).
	# Use ^ and $ to ensure we match the whole line.
	if grep -qxF -- "$key" "$file"; then
		shell::logger::warn "Key '$key' is already protected."
		return 0
	fi

	# Append the key to the protected.conf file.
	# Use echo to append the key, ensuring it is quoted to handle special characters.
	# Use shell::logger::command_clip for dry-run mode, otherwise run the command.
	local cmd="echo \"$key\" >> \"$file\""
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
	else
		shell::exec::shell "$cmd"
		shell::logger::success "Protected key added: $key"
	fi
}

# @description Synchronizes the protected.conf file by removing keys that no longer exist in key.conf.
#
#   This function compares the keys listed in protected.conf with those in key.conf.
#   Any protected key that is not found in key.conf will be removed.
#   In dry-run mode, the updated list is printed instead of being written to the file.
# @option -n Optional dry-run flag. If provided, the updated protected.conf is printed using shell::logger::command_clip instead of being applied.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::conf::protected::sync
#
shell::conf::protected::sync() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Synchronizes the protected.conf file by removing keys that no longer exist in key.conf"
		shell::logger::usage "shell::conf::protected::sync [-n] [-h]"
		shell::logger::option "-n" "Optional dry-run flag. If provided, the updated protected.conf is printed using shell::logger::command_clip instead of being applied."
		shell::logger::option "-h" "Optional. Displays this help message."
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	local key_file="$SHELL_KEY_FILE"
	local protected_file="$SHELL_KEY_PROTECTED_FILE"

	# Check if the protected.conf file and key.conf file exist.
	# If either file does not exist, print an error message and return.
	if [ ! -f "$protected_file" ]; then
		shell::logger::error "Protected key file '$protected_file' not found."
		return 1
	fi

	# Check if the key configuration file exists.
	# If it does not exist, print an error message and return.
	if [ ! -f "$key_file" ]; then
		shell::logger::error "Key configuration file '$key_file' not found."
		return 1
	fi

	shell::logger::debug "Syncing protected keys..."

	# Create a temporary file to store the updated protected keys.
	# Use mktemp to create a temporary file for the updated protected keys.
	local temp_file
	temp_file=$(mktemp) || {
		shell::logger::error "Unable to create temporary file."
		return 1
	}

	# Read the protected keys from the protected.conf file.
	# Use a while loop to read each line from the protected.conf file.
	# For each key, check if it exists in the key.conf file.
	# If the key exists, write it to the temporary file.
	# If the key does not exist, print a warning message.
	while IFS= read -r key; do
		[ -z "$key" ] && continue
		if _shell::conf::entry "$key_file" "$key" >/dev/null; then
			printf '%s\n' "$key" >>"$temp_file"
		else
			shell::logger::warn "Removing undefined protected key: $key"
		fi
	done <"$protected_file"

	# If dry-run mode is enabled, print the updated protected keys and remove the temporary file.
	# Otherwise, move the temporary file to the protected.conf file.
	if [ "$dry_run" = "true" ]; then
		shell::logger::debug "Dry-run: Updated protected keys:"
		cat "$temp_file"
		shell::exec::shell "rm \"$temp_file\""
	else
		shell::exec::shell "mv \"$temp_file\" \"$protected_file\""
		shell::logger::success "Protected keys synchronized successfully."
	fi
}
