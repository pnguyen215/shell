#!/usr/bin/env bash
# @file bot/telegram.sh
# @brief Telegram Bot API integration.
# @description
#   Security notes (differences from the previous implementation):
#   * Values are passed to curl as separate arguments. They were previously
#     interpolated into an `eval`'d string, so a message containing `"`,
#     `$(...)` or a backtick executed arbitrary commands.
#   * Text is sent with `--data-urlencode`; `&`, `%` and `+` no longer corrupt it.
#   * The bot token is masked in every printed/copied command.
#   * HTTP errors and `"ok":false` replies are reported as failures.

# @internal
# @description Mask a bot token for display (keeps the first 4 characters).
# @arg $1 string The token.
# @stdout The masked token.
# @exitcode 0 Always.
shell::telegram::mask() {
	local token="${1-}"
	printf '%s****\n' "${token:0:4}"
}

# @internal
# @description POST to a Telegram Bot API method and verify the reply.
# @arg $1 string Bot token.
# @arg $2 string API method (sendMessage, sendDocument).
# @arg $@ string Extra curl arguments (-d / -F / --data-urlencode ...).
# @exitcode 0 Telegram answered `"ok":true`.
# @exitcode 1 Transport error, HTTP error or `"ok":false`.
shell::telegram::call() {
	local token="$1" method="$2"
	shift 2

	local response
	response="$(curl -sS -f --connect-timeout "$SHELL_NET_CONNECT_TIMEOUT" --max-time "$SHELL_NET_MAX_TIME" \
		-X POST "$@" "${SHELL_URL_TELEGRAM_API}/bot${token}/${method}")" || return "$RETURN_FAILURE"

	case "$response" in
	*'"ok":true'*) return "$RETURN_SUCCESS" ;;
	*)
		shell::logger::error "Telegram rejected the request: $response"
		return "$RETURN_FAILURE"
		;;
	esac
}

# @description Send a text message through the Telegram Bot API.
#   The message is sent with `parse_mode=markdown`.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command (token masked) instead of sending.
# @arg $1 string Bot token.
# @arg $2 string Chat ID.
# @arg $3 string Message text.
# @exitcode 0 The message was delivered (or dry-run printed).
# @exitcode 1 Delivery failed.
# @exitcode 2 A required argument is missing.
# @example
#   shell::telegram::send "$TOKEN" "$CHAT_ID" "Deployment finished"
#   shell::telegram::send -n "$TOKEN" "$CHAT_ID" "Hello"
shell::telegram::send() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Send a message via the Telegram Bot API"
		shell::logger::usage "shell::telegram::send [-n] <token> <chat_id> <message>"
		shell::logger::item "token" "Telegram Bot API token"
		shell::logger::item "chat_id" "Chat identifier that receives the message"
		shell::logger::item "message" "Message text (markdown)"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::telegram::send \"\$TOKEN\" \"\$CHAT_ID\" \"Hello\""
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local token="${1-}" chat_id="${2-}" message="${3-}"
	[ -n "$token" ] || {
		shell::logger::error "Bot Token is not defined"
		return "$RETURN_INVALID"
	}
	[ -n "$chat_id" ] || {
		shell::logger::error "Chat ID is not defined"
		return "$RETURN_INVALID"
	}
	[ -n "$message" ] || {
		shell::logger::error "Message is not defined"
		return "$RETURN_INVALID"
	}

	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "curl -X POST ${SHELL_URL_TELEGRAM_API}/bot$(shell::telegram::mask "$token")/sendMessage -d chat_id=${chat_id} -d parse_mode=markdown --data-urlencode text=<message>"
		return "$RETURN_SUCCESS"
	fi

	shell::dependency::curl::ensure || return "$RETURN_FAILURE"
	shell::telegram::call "$token" sendMessage \
		-d "chat_id=${chat_id}" -d "parse_mode=markdown" --data-urlencode "text=${message}" || {
		shell::logger::error "Failed to send the Telegram message."
		return "$RETURN_FAILURE"
	}
	shell::logger::debug "Telegram message sent to chat '$chat_id'."
}

# @description Send one or more files as Telegram documents.
#   Each caption is `<description> (<timestamp>)`. Missing files are skipped
#   with an error; the function fails if any upload fails.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the commands (token masked) instead of sending.
# @arg $1 string Bot token.
# @arg $2 string Chat ID.
# @arg $3 string Description used in every caption.
# @arg $@ string One or more file paths.
# @exitcode 0 Every existing file was sent (or dry-run printed).
# @exitcode 1 At least one upload failed.
# @exitcode 2 A required argument is missing.
# @example
#   shell::telegram::send_document "$TOKEN" "$CHAT_ID" "Nightly logs" app.log db.log
shell::telegram::send_document() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Send one or more attachments via the Telegram Bot API"
		shell::logger::usage "shell::telegram::send_document [-n] <token> <chat_id> <description> <file> [file ...]"
		shell::logger::option "-n, --dry-run" "Print the commands instead of executing them"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::telegram::send_document \"\$TOKEN\" \"\$CHAT_ID\" \"Logs\" app.log"
		return "$RETURN_SUCCESS"
	fi

	local dry_run="false"
	if [ "${1-}" = "-n" ] || [ "${1-}" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local token="${1-}" chat_id="${2-}" description="${3-}"
	[ -n "$token" ] || {
		shell::logger::error "Bot Token is not defined"
		return "$RETURN_INVALID"
	}
	[ -n "$chat_id" ] || {
		shell::logger::error "Chat ID is not defined"
		return "$RETURN_INVALID"
	}
	[ -n "$description" ] || {
		shell::logger::error "Description is not defined"
		return "$RETURN_INVALID"
	}
	[ "$#" -ge 4 ] || {
		shell::logger::error "No files to send"
		return "$RETURN_INVALID"
	}
	shift 3

	local timestamp file failed=0
	timestamp="$(date +"%Y-%m-%d %H:%M:%S")"

	for file in "$@"; do
		if [ ! -f "$file" ]; then
			shell::logger::error "Attachment '$file' not found. Skipping."
			failed=1
			continue
		fi
		if [ "$dry_run" = "true" ]; then
			shell::logger::command "curl -F chat_id=${chat_id} -F document=@\"${file}\" -F caption=\"${description} (${timestamp})\" ${SHELL_URL_TELEGRAM_API}/bot$(shell::telegram::mask "$token")/sendDocument"
			continue
		fi
		shell::dependency::curl::ensure || return "$RETURN_FAILURE"
		# curl -F "document=@file": the leading @ makes curl upload the file content.
		if shell::telegram::call "$token" sendDocument \
			-F "chat_id=${chat_id}" -F "document=@${file}" -F "caption=${description} (${timestamp})"; then
			shell::logger::success "Sent '$file'."
		else
			shell::logger::error "Failed to send '$file'."
			failed=1
		fi
	done

	return "$failed"
}
