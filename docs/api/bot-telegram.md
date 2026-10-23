# bot/telegram.sh

Telegram Bot API integration.

## Overview

Security notes (differences from the previous implementation):
* Values are passed to curl as separate arguments. They were previously
interpolated into an `eval`'d string, so a message containing `"`,
`$(...)` or a backtick executed arbitrary commands.
* Text is sent with `--data-urlencode`; `&`, `%` and `+` no longer corrupt it.
* The bot token is masked in every printed/copied command.
* HTTP errors and `"ok":false` replies are reported as failures.

## Index

* [shell::telegram::send](#shelltelegramsend)
* [shell::telegram::send_document](#shelltelegramsend_document)

### shell::telegram::send

Send a text message through the Telegram Bot API.
The message is sent with `parse_mode=markdown`.

#### Example

```bash
shell::telegram::send "$TOKEN" "$CHAT_ID" "Deployment finished"
shell::telegram::send -n "$TOKEN" "$CHAT_ID" "Hello"
```

#### Options

* **-h** | **--help**

  Show help and return.

* **-n** | **--dry-run**

  Print the command (token masked) instead of sending.

#### Arguments

* **$1** (string): Bot token.
* **$2** (string): Chat ID.
* **$3** (string): Message text.

#### Exit codes

* **0**: The message was delivered (or dry-run printed).
* **1**: Delivery failed.
* **2**: A required argument is missing.

### shell::telegram::send_document

Send one or more files as Telegram documents.
Each caption is `<description> (<timestamp>)`. Missing files are skipped
with an error; the function fails if any upload fails.

#### Example

```bash
shell::telegram::send_document "$TOKEN" "$CHAT_ID" "Nightly logs" app.log db.log
```

#### Options

* **-h** | **--help**

  Show help and return.

* **-n** | **--dry-run**

  Print the commands (token masked) instead of sending.

#### Arguments

* **$1** (string): Bot token.
* **$2** (string): Chat ID.
* **$3** (string): Description used in every caption.
* **...** (string): One or more file paths.

#### Exit codes

* **0**: Every existing file was sent (or dry-run printed).
* **1**: At least one upload failed.
* **2**: A required argument is missing.

