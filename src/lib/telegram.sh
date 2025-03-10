#!/bin/bash
# telegram.sh

# build_markdown_message function
# Constructs a Markdown-formatted message from multiple input lines.
#
# Usage:
#   build_markdown_message <line1> <line2> ...
#
# Parameters:
#   - <line1>, <line2>, ... : Lines to be concatenated into a single Markdown message.
#
# Description:
#   This function concatenates the provided input lines into one message separated by newlines.
#   You can use standard Markdown syntax (e.g., *bold*, _italic_, `code`) to format your text.
#
# Example:
#   message=$(build_markdown_message "*Hello*, this is a test message." "Here is some code:" "```bash\necho Hello\n```")
#   echo "$message"
build_markdown_message() {
    local message=""
    for line in "$@"; do
        message+="$line\n"
    done
    # Print the final message (printf "%b" interprets backslash escapes)
    printf "%b" "$message"
}

# send_telegram_message function
# Sends a message via the Telegram Bot API.
#
# Usage:
#   send_telegram_message [-n] <token> <chat_id> <message>
#
# Parameters:
#   - -n          : Optional dry-run flag. If provided, the command is printed using on_evict instead of executed.
#   - <token>     : The Telegram Bot API token.
#   - <chat_id>   : The chat identifier where the message should be sent.
#   - <message>   : The message text to send.
#
# Description:
#   The function first checks for an optional dry-run flag. It then verifies that at least three arguments are provided.
#   If the bot token or chat ID is missing, it prints an error message. Otherwise, it constructs a curl command to send
#   the message via Telegram's API. In dry-run mode, the command is printed using on_evict; otherwise, it is executed using run_cmd_eval.
#
# Example:
#   send_telegram_message 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 "Hello, World!"
#   send_telegram_message -n 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 987654321 "Dry-run: Hello, World!"
send_telegram_message() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n).
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    # Ensure that at least three arguments remain.
    if [ $# -lt 3 ]; then
        echo "Usage: send_telegram_message [-n] <token> <chat_id> <message>"
        return 1
    fi

    local token="$1"
    local chatID="$2"
    local message="$3"

    # Verify that both token and chatID are defined.
    if [ -z "$token" ] || [ -z "$chatID" ]; then
        colored_echo "🔴 Error: Bot Token or Chat ID is not defined." 196
        return 1
    fi

    # Construct the curl command to send the Telegram message.
    local cmd="curl -s -X POST \"https://api.telegram.org/bot${token}/sendMessage\" \
                -d \"chat_id=${chatID}\" \
                -d \"parse_mode=markdown\" \
                -d \"text=${message}\" >/dev/null"

    # Execute the command in dry-run mode or actually send the message.
    if [ "$dry_run" = "true" ]; then
        on_evict "$cmd"
    else
        run_cmd_eval "$cmd"
        colored_echo "🟢 Telegram message sent." 46
    fi
}
