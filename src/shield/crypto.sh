#!/usr/bin/env bash
# @file shield/crypto.sh
# @brief AES-256-CBC encryption helpers.

# @description Generates a random encryption key of specified length (in bytes) and outputs it to standard output.
#
#   This function uses OpenSSL to generate a random key of the specified length in hexadecimal format.
#   It outputs the generated key to standard output, allowing it to be assigned to a variable or used directly.
#
#   Notes:
#   - Requires OpenSSL to be installed.
# @arg $@ string bytes: Optional. The length of the key to generate, in bytes. Defaults to 32 bytes.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   encryption_key=$(shell::crypto::key::generate)       # Generates a 32-byte key
#   encryption_key=$(shell::crypto::key::generate 64)    # Generates a 64-byte key
#   echo $encryption_key  # Outputs the generated key
#
shell::crypto::key::generate() {
	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Generates a random encryption key of specified length (in bytes) and outputs it to standard output"
		shell::logger::usage "shell::crypto::key::generate [-h] [bytes]"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "bytes" "Optional. The length of the key to generate, in bytes. Defaults to 32 bytes."
		return $RETURN_SUCCESS
	fi

	local bytes="${1:-32}" # Default to 32 bytes if no argument is provided

	# Check if OpenSSL is installed
	if ! shell::command::exists openssl; then
		shell::console::print "ERR: shell::crypto::key::generate: OpenSSL is not installed" 196 >&2
		return 1
	fi

	# Validate that bytes is a number
	if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
		shell::console::print "ERR: shell::crypto::key::generate: Invalid byte size. Must be a number." 196 >&2
		return 1
	fi

	# Generate a random key in hexadecimal format
	local key=$(openssl rand -hex "$bytes")

	# Check if key generation was successful
	if [ -z "$key" ]; then
		shell::console::print "ERR: shell::crypto::key::generate: Key generation failed" 196 >&2
		return 1
	fi

	echo "$key"
	return 0
}

# @description Encrypts a string using AES-256-CBC encryption and encodes the result in Base64.
#
#   This function encrypts the input string using AES-256-CBC with OpenSSL, using either the provided key
#   or the SHELL_SHIELD_ENCRYPTION_KEY environment variable. The encrypted output is Base64-encoded for safe storage
#   in configuration files, aligning with the library's existing Base64 usage. It checks for OpenSSL availability
#   and validates the key length. The function is compatible with both macOS and Linux.
#
#   Notes:
#   - Relies on the shell::console::print function for output.
#   - Requires OpenSSL to be installed.
#   - The encryption key must be 64 bytes for AES-256-CBC.
#   - If SHELL_SHIELD_ENCRYPTION_KEY is not set and no key is provided, the function fails.
# @option -h Optional. Displays this help message.
# @arg $1 string string: The string to encrypt.
# @arg $@ string key: Optional. The encryption key (32 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_KEY.
# @arg $@ string iv: Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::crypto::aes256cbc::encode "sensitive data" "my64byteKey1234567890123456789012345678901234567890"  # Encrypts with specified key
#   export SHELL_SHIELD_ENCRYPTION_KEY="my64byteKey1234567890123456789012345678901234567890"
#   shell::crypto::aes256cbc::encode "sensitive data"  # Encrypts with SHELL_SHIELD_ENCRYPTION_KEY
#
shell::crypto::aes256cbc::encode() {
	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Encrypts a string using AES-256-CBC encryption and encodes the result in Base64"
		shell::logger::usage "shell::crypto::aes256cbc::encode [-h] <string> [key] [iv]"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "string" "The string to encrypt."
		shell::logger::item "key" "Optional. The encryption key (32 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_KEY."
		shell::logger::item "iv" "Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV."
		return $RETURN_SUCCESS
	fi

	local value="$1"
	local key="$2"
	local iv="$3"

	# Validate input
	if [ -z "$value" ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::encode: Missing argument value" 196 >&2
		echo "Usage: shell::crypto::aes256cbc::encode [-h] <value> [key] [iv]"
		return 1
	fi

	# Use SHELL_SHIELD_ENCRYPTION_KEY if no key is provided
	if [ -z "$key" ]; then
		local hasKey=$(shell::conf::key::exists "SHELL_SHIELD_ENCRYPTION_KEY")
		if [ "$hasKey" = "false" ]; then
			shell::conf::key::add "SHELL_SHIELD_ENCRYPTION_KEY" "$(shell::crypto::key::generate 32)"
		fi
		key=$(shell::conf::key::get "SHELL_SHIELD_ENCRYPTION_KEY")
	fi

	# Use SHELL_SHIELD_ENCRYPTION_IV if no iv is provided
	if [ -z "$iv" ]; then
		local hasIv=$(shell::conf::key::exists "SHELL_SHIELD_ENCRYPTION_IV")
		if [ "$hasIv" = "false" ]; then
			shell::conf::key::add "SHELL_SHIELD_ENCRYPTION_IV" "$(shell::crypto::key::generate 16)"
		fi
		iv=$(shell::conf::key::get "SHELL_SHIELD_ENCRYPTION_IV")
	fi

	# Validate key length (64 bytes for AES-256)
	if [ ${#key} -ne 64 ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::encode: Encryption key must be exactly 64 bytes" 196 >&2
		return 1
	fi

	# Validate iv length (32 bytes for AES-256)
	if [ ${#iv} -ne 32 ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::encode: Initialization vector must be exactly 32 bytes" 196 >&2
		return 1
	fi

	# Check if OpenSSL is installed
	if ! shell::command::exists openssl; then
		shell::console::print "ERR: shell::crypto::aes256cbc::encode: OpenSSL is not installed" 196 >&2
		return 1
	fi

	# Encrypt the value string and encode in Base64
	local encrypted=$(printf "%s" "$value" | openssl enc -aes-256-cbc -base64 -K "$key" -iv "$iv" 2>/dev/null)
	if [ $? -ne 0 ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::encode: Encryption failed. Please check your key and try again." 196 >&2
		return 1
	fi

	echo "$encrypted"
	shell::clipboard::copy --best-effort "$encrypted"
	return 0
}

# @description Decodes a Base64-encoded string and decrypts it using AES-256-CBC.
#
#   This function decodes the Base64-encoded input string and decrypts it using AES-256-CBC with OpenSSL,
#   using either the provided key or the SHELL_SHIELD_ENCRYPTION_KEY environment variable. It checks for OpenSSL
#   availability and validates the key length. The function is compatible with both macOS and Linux.
#
#   Notes:
#   - Relies on the shell::console::print function for output.
#   - Requires OpenSSL to be installed.
#   - The encryption key must be 64 bytes for AES-256-CBC.
#   - If SHELL_SHIELD_ENCRYPTION_KEY is not set and no key is provided, the function fails.
# @option -h Optional. Displays this help message.
# @arg $1 string string: The Base64-encoded string to decrypt.
# @arg $@ string key: Optional. The encryption key (32 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_KEY.
# @arg $@ string iv: Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::crypto::aes256cbc::decode "Base64EncodedString" "my64byteKey1234567890123456789012345678901234567890"  # Decrypts with specified key
#   export SHELL_SHIELD_ENCRYPTION_KEY="my64byteKey1234567890123456789012345678901234567890"
#   shell::crypto::aes256cbc::decode "Base64EncodedString"  # Decrypts with SHELL_SHIELD_ENCRYPTION_KEY
#
shell::crypto::aes256cbc::decode() {
	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Decodes a Base64-encoded string and decrypts it using AES-256-CBC"
		shell::logger::usage "shell::crypto::aes256cbc::decode [-h] <string> [key] [iv]"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "string" "The Base64-encoded string to decrypt."
		shell::logger::item "key" "Optional. The encryption key (32 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_KEY."
		shell::logger::item "iv" "Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV."
		return $RETURN_SUCCESS
	fi

	local value="$1"
	local key="$2"
	local iv="$3"
	# Validate input
	if [ -z "$value" ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::decode: Missing argument value" 196 >&2
		echo "Usage: shell::crypto::aes256cbc::decode [-h] <value> [key] [iv]"
		return 1
	fi

	# Use SHELL_SHIELD_ENCRYPTION_KEY if no key is provided
	if [ -z "$key" ]; then
		local hasKey=$(shell::conf::key::exists "SHELL_SHIELD_ENCRYPTION_KEY")
		if [ "$hasKey" = "false" ]; then
			shell::console::print "ERR: shell::crypto::aes256cbc::decode: SHELL_SHIELD_ENCRYPTION_KEY is not set. Please set it or provide a key." 196 >&2
			return 1
		fi
		key=$(shell::conf::key::get "SHELL_SHIELD_ENCRYPTION_KEY")
	fi

	# Use SHELL_SHIELD_ENCRYPTION_IV if no iv is provided
	if [ -z "$iv" ]; then
		local hasIv=$(shell::conf::key::exists "SHELL_SHIELD_ENCRYPTION_IV")
		if [ "$hasIv" = "false" ]; then
			shell::console::print "ERR: shell::crypto::aes256cbc::decode: SHELL_SHIELD_ENCRYPTION_IV is not set. Please set it or provide a key." 196 >&2
			return 1
		fi
		iv=$(shell::conf::key::get "SHELL_SHIELD_ENCRYPTION_IV")
	fi

	# Validate key length (64 bytes for AES-256)
	if [ ${#key} -ne 64 ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::decode: Encryption key must be exactly 64 bytes" 196 >&2
		return 1
	fi

	# Validate iv length (32 bytes for AES-256)
	if [ ${#iv} -ne 32 ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::decode: Initialization vector must be exactly 32 bytes" 196 >&2
		return 1
	fi

	# Check if OpenSSL is installed
	if ! shell::command::exists openssl; then
		shell::console::print "ERR: shell::crypto::aes256cbc::decode: OpenSSL is not installed" 196 >&2
		return 1
	fi

	local decrypted=$(echo "$value" | openssl enc -aes-256-cbc -d -base64 -K "$key" -iv "$iv" 2>/dev/null)
	if [ $? -ne 0 ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::decode: Decryption failed. Please check your key and try again." 196 >&2
		return 1
	fi

	echo "$decrypted"
	shell::clipboard::copy --best-effort "$decrypted"
	return 0
}

# @description Creates a password hash using a specified OpenSSL algorithm.
#
#   This function uses `openssl passwd` to generate a cryptographic hash of a password.
#   It supports various algorithms, including modern secure hashing algorithms like bcrypt
#   (identified by 'B' or 'B2') and SHA-based hashes ('5' for SHA256, '6' for SHA512).
#   The output includes the salt and the hashed password, suitable for storage.
#
#   Notes:
#   - Requires OpenSSL to be installed.
#   - The 'algorithm' parameter directly corresponds to the flags used with `openssl passwd`.
#   It's crucial to select a strong, modern hashing algorithm.
#   - The function handles prompting for password if not provided directly, but this function
#   expects it as an argument for automation.
# @option -h Optional. Displays this help message.
# @arg $1 string algorithm: Hashing algorithm. -1 for Use the MD5 based BSD password algorithm 1 (default) -apr1 for Use the apr1 algorithm (Apache variant of the BSD algorithm). -aixmd5 for Use the AIX MD5 algorithm (AIX variant of the BSD algorithm). -5 for Use the SHA-256 based hash algorithm -6 for Use the SHA-512 based hash algorithm
# @arg $2 string password: The plain text password to hash.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   hashed_pass=$(shell::crypto::password::hash 1 "MySecurePassword123!")
#   echo "Hashed password (bcrypt): $hashed_pass"
#   hashed_pass_sha256=$(shell::crypto::password::hash 5 "AnotherPassword") # Uses SHA256
#   echo "Hashed password (SHA256): $hashed_pass_sha256"
#
shell::crypto::password::hash() {
	# Check for the help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Creates a password hash using a specified OpenSSL algorithm"
		shell::logger::usage "shell::crypto::password::hash [-h] <algorithm> <password>"
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "algorithm" "Hashing algorithm. - 1 for Use the MD5 based BSD password algorithm 1 (default) - apr1 for Use the apr1 algorithm (Apache variant of the BSD algorithm). - aixmd5 for Use the AIX MD5 algorithm (AIX variant of the BSD algorithm). - 5 for Use the SHA-256 based hash algorithm. - 6 for Use the SHA-512 based hash algorithm."
		shell::logger::item "password" "The password to hash."
		shell::logger::example "hashed_pass=(shell::crypto::password::hash 1 \"MySecurePassword123!\")"
		return $RETURN_SUCCESS
	fi

	local algorithm="$1"
	local password="$2"

	if [ -z "$algorithm" ] || [ -z "$password" ]; then
		shell::console::print "ERR: shell::crypto::password::hash: Missing required parameters." 196 >&2
		echo "Usage: shell::crypto::password::hash [-h] <algorithm> <password>"
		return 1
	fi

	if ! shell::command::exists openssl; then
		shell::console::print "ERR: shell::crypto::password::hash: OpenSSL is not installed." 196 >&2
		return 1
	fi

	# Use openssl passwd. -stdin reads password from stdin.
	# The algorithm is passed as an option, e.g., -1, -apr1, -aixmd5, -5, -6.
	local hashed_password=$(printf "%s" "$password" | openssl passwd "-$algorithm" -stdin 2>/dev/null)

	if [ $? -ne 0 ] || [ -z "$hashed_password" ]; then
		shell::console::print "ERR: shell::crypto::password::hash: Failed to create password hash. Check algorithm or OpenSSL installation." 196 >&2
		return 1
	fi

	echo "$hashed_password"
	return 0
}

# @description Encrypts a file using AES-256-CBC encryption and saves the result to an output file.
#
#   This function encrypts the specified input file using AES-256-CBC with OpenSSL, using either the provided key
#   or the SHELL_SHIELD_ENCRYPTION_KEY environment variable. The encrypted output is saved to the specified output file.
#   It checks for OpenSSL availability, validates the key and IV lengths, and ensures the input file exists.
#   The function is compatible with both macOS and Linux. In dry-run mode, it prints the encryption command without executing it.
#
#   Notes:
#   - Relies on the shell::console::print, shell::logger::command_clip, and shell::exec::shell functions for output and command execution.
#   - Requires OpenSSL to be installed.
#   - The encryption key must be 64 bytes (hex) for AES-256-CBC.
#   - The initialization vector must be 32 bytes (hex) for AES-256-CBC.
#   - If SHELL_SHIELD_ENCRYPTION_KEY or SHELL_SHIELD_ENCRYPTION_IV is not set and no key/IV is provided, the function generates and stores them.
# @option -n Optional. Dry-run mode; prints the command using shell::logger::command_clip instead of executing it.
# @option -h Optional. Displays this help message.
# @arg $1 string input_file: The path to the file to encrypt.
# @arg $2 string output_file: The path where the encrypted file will be saved.
# @arg $@ string key: Optional. The encryption key (32 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_KEY.
# @arg $@ string iv: Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::crypto::aes256cbc::encode_file input.txt encrypted.bin "my64byteKey1234567890123456789012345678901234567890"  # Encrypts with specified key
#   export SHELL_SHIELD_ENCRYPTION_KEY="my64byteKey1234567890123456789012345678901234567890"
#   shell::crypto::aes256cbc::encode_file -n input.txt encrypted.bin  # Prints encryption command without executing
#
shell::crypto::aes256cbc::encode_file() {
	local dry_run="false"

	# Check for help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Encrypts a file using AES-256-CBC encryption and encodes the result in Base64"
		shell::logger::usage "shell::crypto::aes256cbc::encode_file [-n] [-h] <input_file> <output_file> [key] [iv]"
		shell::logger::option "-n" "Optional. Dry-run mode. Prints the command without executing it."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "input_file" "The path to the file to encrypt."
		shell::logger::item "output_file" "The path where the encrypted file will be saved."
		shell::logger::item "key" "Optional. The encryption key (32 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_KEY."
		shell::logger::item "iv" "Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV."
		shell::logger::example "shell::crypto::aes256cbc::encode_file input.txt encrypted.bin \"my64byteKey1234567890123456789012345678901234567890\""
		return $RETURN_SUCCESS
	fi

	# Check for dry-run flag (-n)
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	local input_file="$1"
	local output_file="$2"
	local key="$3"
	local iv="$4"

	# Validate input parameters
	if [ -z "$input_file" ] || [ -z "$output_file" ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::encode_file: Missing input or output file" 196 >&2
		echo "Usage: shell::crypto::aes256cbc::encode_file [-n] [-h] <input_file> <output_file> [key] [iv]" >&2
		return 1
	fi

	# Check if input file exists
	if [ ! -f "$input_file" ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::encode_file: Input file '$input_file' does not exist" 196 >&2
		return 1
	fi

	# Check if output file already exists
	if [ -e "$output_file" ] && [ "$dry_run" = "false" ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::encode_file: Output file '$output_file' already exists" 196 >&2
		return 1
	fi

	# Use SHELL_SHIELD_ENCRYPTION_KEY if no key is provided
	if [ -z "$key" ]; then
		local hasKey=$(shell::conf::key::exists "SHELL_SHIELD_ENCRYPTION_KEY")
		if [ "$hasKey" = "false" ]; then
			shell::conf::key::add "SHELL_SHIELD_ENCRYPTION_KEY" "$(shell::crypto::key::generate 32)"
		fi
		key=$(shell::conf::key::get "SHELL_SHIELD_ENCRYPTION_KEY")
	fi

	# Use SHELL_SHIELD_ENCRYPTION_IV if no iv is provided
	if [ -z "$iv" ]; then
		local hasIv=$(shell::conf::key::exists "SHELL_SHIELD_ENCRYPTION_IV")
		if [ "$hasIv" = "false" ]; then
			shell::conf::key::add "SHELL_SHIELD_ENCRYPTION_IV" "$(shell::crypto::key::generate 16)"
		fi
		iv=$(shell::conf::key::get "SHELL_SHIELD_ENCRYPTION_IV")
	fi

	# Validate key length (64 bytes for AES-256)
	if [ ${#key} -ne 64 ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::encode_file: Encryption key must be exactly 64 bytes" 196 >&2
		return 1
	fi

	# Validate iv length (32 bytes for AES-256)
	if [ ${#iv} -ne 32 ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::encode_file: Initialization vector must be exactly 32 bytes" 196 >&2
		return 1
	fi

	# Check if OpenSSL is installed
	if ! shell::command::exists openssl; then
		shell::console::print "ERR: shell::crypto::aes256cbc::encode_file: OpenSSL is not installed" 196 >&2
		return 1
	fi

	# Construct the encryption command
	local cmd="openssl enc -aes-256-cbc -K \"$key\" -iv \"$iv\" -in \"$input_file\" -out \"$output_file\""

	# Execute or print the command based on dry-run mode
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
		return 0
	fi

	# Encrypt the file using the constructed command
	if ! shell::exec::shell "$cmd" 2>/dev/null; then
		shell::console::print "ERR: shell::crypto::aes256cbc::encode_file: Encryption failed. Please check your key and try again." 196 >&2
		return 1
	fi

	shell::logger::success "File encrypted successfully to '$output_file'"
	shell::clipboard::copy --best-effort "$output_file"
	return 0
}

# @description Decrypts a file encrypted with AES-256-CBC and saves the result to an output file.
#
#   This function decrypts the specified input file using AES-256-CBC with OpenSSL, using either the provided key
#   or the SHELL_SHIELD_ENCRYPTION_KEY environment variable. The decrypted output is saved to the specified output file.
#   It checks for OpenSSL availability, validates the key and IV lengths, and ensures the input file exists.
#   The function is compatible with both macOS and Linux. In dry-run mode, it prints the decryption command without executing it.
#
#   Notes:
#   - Relies on the shell::console::print, shell::logger::command_clip, and shell::exec::shell functions for output and command execution.
#   - Requires OpenSSL to be installed.
#   - The encryption key must be 64 bytes (hex) for AES-256-CBC.
#   - The initialization vector must be 32 bytes (hex) for AES-256-CBC.
#   - If SHELL_SHIELD_ENCRYPTION_KEY or SHELL_SHIELD_ENCRYPTION_IV is not set and no key/IV is provided, the function fails.
# @option -n Optional. Dry-run mode; prints the command using shell::logger::command_clip instead of executing it.
# @option -h Optional. Displays this help message.
# @arg $1 string input_file: The path to the encrypted file to decrypt.
# @arg $2 string output_file: The path where the decrypted file will be saved.
# @arg $@ string key: Optional. The encryption key (32 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_KEY.
# @arg $@ string iv: Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV.
# @exitcode 0 Success.
# @exitcode 1 The operation failed.
# @example
#   shell::crypto::aes256cbc::decode_file encrypted.bin output.txt "my64byteKey1234567890123456789012345678901234567890"  # Decrypts with specified key
#   export SHELL_SHIELD_ENCRYPTION_KEY="my64byteKey1234567890123456789012345678901234567890"
#   shell::crypto::aes256cbc::decode_file -n encrypted.bin output.txt  # Prints decryption command without executing
#
shell::crypto::aes256cbc::decode_file() {
	local dry_run="false"

	# Check for help flag (-h)
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Decodes a Base64-encoded file and decrypts it using AES-256-CBC"
		shell::logger::usage "shell::crypto::aes256cbc::decode_file [-n] [-h] <input_file> <output_file> [key] [iv]"
		shell::logger::option "-n" "Optional. Dry-run mode. Prints the command without executing it."
		shell::logger::option "-h" "Optional. Displays this help message."
		shell::logger::item "input_file" "The path to the file to decrypt."
		shell::logger::item "output_file" "The path where the decrypted file will be saved."
		shell::logger::item "key" "Optional. The encryption key (32 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_KEY."
		shell::logger::item "iv" "Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV."
		shell::logger::example "shell::crypto::aes256cbc::decode_file encrypted.bin decrypted.txt \"my64byteKey1234567890123456789012345678901234567890\""
		return $RETURN_SUCCESS
	fi

	# Check for dry-run flag (-n)
	if [ "$1" = "-n" ]; then
		dry_run="true"
		shift
	fi

	local input_file="$1"
	local output_file="$2"
	local key="$3"
	local iv="$4"

	# Validate input parameters
	if [ -z "$input_file" ] || [ -z "$output_file" ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::decode_file: Missing input or output file" 196 >&2
		echo "Usage: shell::crypto::aes256cbc::decode_file [-n] [-h] <input_file> <output_file> [key] [iv]" >&2
		return 1
	fi

	# Check if input file exists
	if [ ! -f "$input_file" ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::decode_file: Input file '$input_file' does not exist" 196 >&2
		return 1
	fi

	# Check if output file already exists
	if [ -e "$output_file" ] && [ "$dry_run" = "false" ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::decode_file: Output file '$output_file' already exists" 196 >&2
		return 1
	fi

	# Use SHELL_SHIELD_ENCRYPTION_KEY if no key is provided
	if [ -z "$key" ]; then
		local hasKey=$(shell::conf::key::exists "SHELL_SHIELD_ENCRYPTION_KEY")
		if [ "$hasKey" = "false" ]; then
			shell::console::print "ERR: shell::crypto::aes256cbc::decode_file: SHELL_SHIELD_ENCRYPTION_KEY is not set. Please set it or provide a key." 196 >&2
			return 1
		fi
		key=$(shell::conf::key::get "SHELL_SHIELD_ENCRYPTION_KEY")
	fi

	# Use SHELL_SHIELD_ENCRYPTION_IV if no iv is provided
	if [ -z "$iv" ]; then
		local hasIv=$(shell::conf::key::exists "SHELL_SHIELD_ENCRYPTION_IV")
		if [ "$hasIv" = "false" ]; then
			shell::console::print "ERR: shell::crypto::aes256cbc::decode_file: SHELL_SHIELD_ENCRYPTION_IV is not set. Please set it or provide an IV." 196 >&2
			return 1
		fi
		iv=$(shell::conf::key::get "SHELL_SHIELD_ENCRYPTION_IV")
	fi

	# Validate key length (64 bytes for AES-256)
	if [ ${#key} -ne 64 ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::decode_file: Encryption key must be exactly 64 bytes" 196 >&2
		return 1
	fi

	# Validate iv length (32 bytes for AES-256)
	if [ ${#iv} -ne 32 ]; then
		shell::console::print "ERR: shell::crypto::aes256cbc::decode_file: Initialization vector must be exactly 32 bytes" 196 >&2
		return 1
	fi

	# Check if OpenSSL is installed
	if ! shell::command::exists openssl; then
		shell::console::print "ERR: shell::crypto::aes256cbc::decode_file: OpenSSL is not installed" 196 >&2
		return 1
	fi

	# Construct the decryption command
	local cmd="openssl enc -aes-256-cbc -d -K \"$key\" -iv \"$iv\" -in \"$input_file\" -out \"$output_file\""

	# Execute or print the command based on dry-run mode
	if [ "$dry_run" = "true" ]; then
		shell::logger::command_clip "$cmd"
		return 0
	fi

	# Decrypt the file using the constructed command
	if ! shell::exec::shell "$cmd" 2>/dev/null; then
		shell::console::print "ERR: shell::crypto::aes256cbc::decode_file: Decryption failed. Please check your key and try again." 196 >&2
		return 1
	fi

	shell::logger::success "File decrypted successfully to '$output_file'"
	shell::clipboard::copy --best-effort "$output_file"
	return 0
}
