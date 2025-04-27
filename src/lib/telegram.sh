#!/bin/bash
# telegram.sh

# shell::gen_markdown_message function
# Constructs a Markdown-formatted message from multiple input lines.
#
# Usage:
#   shell::gen_markdown_message <line1> <line2> ...
#
# Parameters:
#   - <line1>, <line2>, ... : Lines to be concatenated into a single Markdown message.
#
# Description:
#   This function concatenates the provided input lines into one message separated by newlines.
#   You can use standard Markdown syntax (e.g., *bold*, _italic_, `code`) to format your text.
#
# Example:
#   message=$(shell::gen_markdown_message "*Hello*, this is a test message." "Here is some code:" "```bash\necho Hello\n```")
#   echo "$message"
shell::gen_markdown_message() {
    local message=""
    for line in "$@"; do
        message+="$line\n"
    done
    # Print the final message (printf "%b" interprets backslash escapes)
    printf "%b" "$message"
}

# shell::send_telegram_message function
# Sends a message via the Telegram Bot API.
#
# Usage:
#   shell::send_telegram_message [-n] <token> <chat_id> <message>
#
# Parameters:
#   - -n          : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#   - <token>     : The Telegram Bot API token.
#   - <chat_id>   : The chat identifier where the message should be sent.
#   - <message>   : The message text to send.
#
# Description:
#   The function first checks for an optional dry-run flag. It then verifies that at least three arguments are provided.
#   If the bot token or chat ID is missing, it prints an error message. Otherwise, it constructs a curl command to send
#   the message via Telegram's API. In dry-run mode, the command is printed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.
#
# Example:
#   shell::send_telegram_message 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 "Hello, World!"
#   shell::send_telegram_message -n 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 "Dry-run: Hello, World!"
shell::send_telegram_message() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n).
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_SEND_TELEGRAM_MESSAGE"
        return 0
    fi

    # Ensure that at least three arguments remain.
    if [ $# -lt 3 ]; then
        echo "Usage: shell::send_telegram_message [-n] <token> <chat_id> <message>"
        return 1
    fi

    local token="$1"
    local chatID="$2"
    local message="$3"

    # Verify that both token and chatID are defined.
    if [ -z "$token" ] || [ -z "$chatID" ]; then
        shell::colored_echo "🔴 Error: Bot Token or Chat ID is not defined." 196
        return 1
    fi

    # Construct the curl command to send the Telegram message.
    local cmd="curl -s -X POST \"https://api.telegram.org/bot${token}/sendMessage\" \
                -d \"chat_id=${chatID}\" \
                -d \"parse_mode=markdown\" \
                -d \"text=${message}\" >/dev/null"

    # Execute the command in dry-run mode or actually send the message.
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$cmd &"
    else
        shell::async "$cmd"
        shell::colored_echo "🟢 Telegram message sent." 46
    fi
}

# shell::send_telegram_attachment function
# Sends one or more attachments (files) via Telegram using the Bot API asynchronously.
#
# Usage:
#   shell::send_telegram_attachment [-n] <token> <chat_id> <description> [filename_1] [filename_2] [filename_3] ...
#
# Parameters:
#   - -n           : Optional dry-run flag. If provided, the command is printed using shell::on_evict instead of executed.
#   - <token>      : The Telegram Bot API token.
#   - <chat_id>    : The chat identifier to which the attachments are sent.
#   - <description>: A text description that is appended to each attachment's caption along with a timestamp.
#   - [filename_X] : One or more filenames of the attachments to send.
#
# Description:
#   The function first checks for an optional dry-run flag (-n) and verifies that the required parameters
#   are provided. For each provided file, if the file exists, it builds a curl command to send the file
#   asynchronously via Telegram's API. In dry-run mode, the command is printed using shell::on_evict.
#
# Example:
#   shell::send_telegram_attachment 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 "Report" file1.pdf file2.pdf
#   shell::send_telegram_attachment -n 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 "Report" file1.pdf
shell::send_telegram_attachment() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Check for the help flag (-h)
    if [ "$1" = "-h" ]; then
        echo "$USAGE_SHELL_SEND_TELEGRAM_ATTACHMENT"
        return 0
    fi

    # Ensure that at least four arguments remain: token, chat_id, description, and at least one filename.
    if [ $# -lt 4 ]; then
        echo "Usage: shell::send_telegram_attachment [-n] <token> <chat_id> <description> [filename_1] [filename_2] [filename_3] ..."
        return 1
    fi

    # Retrieve parameters.
    local token="$1"
    local chatID="$2"
    local description="$3"
    local files=("${@:4}")
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Iterate over each file and send as an attachment asynchronously.
    for filename in "${files[@]}"; do
        if [ -f "$filename" ]; then
            # Build the curl command to send the attachment.
            local cmd="curl -s -F chat_id=\"$chatID\" -F document=@\"$filename\" -F caption=\"$description ($timestamp)\" \"https://api.telegram.org/bot${token}/sendDocument\" >/dev/null"
            if [ "$dry_run" = "true" ]; then
                shell::on_evict "$cmd &"
            else
                shell::async "$cmd"
                shell::colored_echo "🟢 Async: Attachment '$filename' is being sent." 46
            fi
        else
            shell::colored_echo "🔴 Attachment '$filename' not found. Skipping." 196
        fi
    done
}
