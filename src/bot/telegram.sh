#!/bin/bash
# telegram.sh

# shell::send_telegram_message function
# Sends a message via the Telegram Bot API.
#
# Usage:
#   shell::send_telegram_message [-n] <token> <chat_id> <message>
#
# Parameters:
#   - -n          : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
#   - <token>     : The Telegram Bot API token.
#   - <chat_id>   : The chat identifier where the message should be sent.
#   - <message>   : The message text to send.
#
# Description:
#   The function first checks for an optional dry-run flag. It then verifies that at least three arguments are provided.
#   If the bot token or chat ID is missing, it prints an error message. Otherwise, it constructs a curl command to send
#   the message via Telegram's API. In dry-run mode, the command is printed using shell::logger::cmd_copy; otherwise, it is executed using shell::run_cmd_eval.
#
# Example:
#   shell::send_telegram_message 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 "Hello, World!"
#   shell::send_telegram_message -n 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 "Dry-run: Hello, World!"
shell::send_telegram_message() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::usage "shell::send_telegram_message [-n] [-h] <token> <chat_id> <message>"
		shell::logger::item "token" "The Telegram Bot API token"
		shell::logger::item "chat_id" "The chat identifier where the message should be sent"
		shell::logger::item "message" "The message text to send"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::example "shell::send_telegram_message 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 \"Hello, World!\""
		shell::logger::example "shell::send_telegram_message -n 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 \"Hello, World!\""
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local token="$1"
	local chatID="$2"
	local message="$3"

	if [ -z "$token" ]; then
		shell::logger::error "Bot Token is not defined"
		return $RETURN_INVALID
	fi

	if [ -z "$chatID" ]; then
		shell::logger::error "Chat ID is not defined"
		return $RETURN_INVALID
	fi

	if [ -z "$message" ]; then
		shell::logger::error "Message is not defined"
		return $RETURN_INVALID
	fi

	local cmd="curl -s -X POST \"https://api.telegram.org/bot${token}/sendMessage\" -d \"chat_id=${chatID}\" -d \"parse_mode=markdown\" -d \"text=${message}\" >/dev/null"

	# Execute the command in dry-run mode or actually send the message.
	if [ "$dry_run" = "true" ]; then
		shell::logger::cmd_copy "$cmd &"
	else
		shell::async "$cmd"
		shell::logger::success "Telegram message sent"
	fi

	return $RETURN_SUCCESS
}

# shell::send_telegram_attachment function
# Sends one or more attachments (files) via Telegram using the Bot API asynchronously.
#
# Usage:
#   shell::send_telegram_attachment [-n] <token> <chat_id> <description> [filename_1] [filename_2] [filename_3] ...
#
# Parameters:
#   - -n           : Optional dry-run flag. If provided, the command is printed using shell::logger::cmd_copy instead of executed.
#   - <token>      : The Telegram Bot API token.
#   - <chat_id>    : The chat identifier to which the attachments are sent.
#   - <description>: A text description that is appended to each attachment's caption along with a timestamp.
#   - [filename_X] : One or more filenames of the attachments to send.
#
# Description:
#   The function first checks for an optional dry-run flag (-n) and verifies that the required parameters
#   are provided. For each provided file, if the file exists, it builds a curl command to send the file
#   asynchronously via Telegram's API. In dry-run mode, the command is printed using shell::logger::cmd_copy.
#
# Example:
#   shell::send_telegram_attachment 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 "Report" file1.pdf file2.pdf
#   shell::send_telegram_attachment -n 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 "Report" file1.pdf
shell::send_telegram_attachment() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::usage "shell::send_telegram_attachment [-n] [-h] <token> <chat_id> <description> [filename_1] [filename_2] [filename_3] ..."
		shell::logger::item "token" "The Telegram Bot API token"
		shell::logger::item "chat_id" "The chat identifier to which the attachments are sent"
		shell::logger::item "description" "A text description that is appended to each attachment's caption along with a timestamp"
		shell::logger::item "filename_N" "One or more filenames of the attachments to send"
		shell::logger::option "-h, --help" "Show this help message"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::example "shell::send_telegram_attachment 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 \"Report\" file1.pdf file2.pdf"
		shell::logger::example "shell::send_telegram_attachment -n 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 \"Report\" file1.pdf"
		return $RETURN_SUCCESS
	fi

	local dry_run="false"
	if [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
		dry_run="true"
		shift
	fi

	local token="$1"
	local chatID="$2"
	local description="$3"
	local files=("${@:4}")

	if [ -z "$token" ]; then
		shell::logger::error "Bot Token is not defined"
		return $RETURN_INVALID
	fi

	if [ -z "$chatID" ]; then
		shell::logger::error "Chat ID is not defined"
		return $RETURN_INVALID
	fi

	if [ -z "$description" ]; then
		shell::logger::error "Description is not defined"
		return $RETURN_INVALID
	fi

	if [ ${#files[@]} -eq 0 ]; then
		shell::logger::error "No files to send"
		return $RETURN_INVALID
	fi

	local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
	shell::logger::debug "Sending ${#files[@]} attachments to chat '$chatID' with description: $description"

	# Iterate over each file and send as an attachment asynchronously.
	for filename in "${files[@]}"; do
		if [ -f "$filename" ]; then
			# Build the curl command to send the attachment.
			local cmd="curl -s -F chat_id=\"$chatID\" -F document=@\"$filename\" -F caption=\"$description ($timestamp)\" \"https://api.telegram.org/bot${token}/sendDocument\" >/dev/null"
			if [ "$dry_run" = "true" ]; then
				shell::logger::cmd_copy "$cmd &"
			else
				shell::async "$cmd"
				shell::logger::success "Attachment '$filename' is being sent."
			fi
		else
			shell::logger::error "Attachment '$filename' not found. Skipping."
		fi
	done
}
