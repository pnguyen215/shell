#!/bin/bash
# crypto.sh

# shell::generate_random_key function
# Generates a random encryption key of specified length (in bytes) and outputs it to standard output.
#
# Usage:
#   shell::generate_random_key [bytes]
#
# Parameters:
#   - [bytes]: Optional. The length of the key to generate, in bytes. Defaults to 32 bytes.
#
# Description:
#   This function uses OpenSSL to generate a random key of the specified length in hexadecimal format.
#   It outputs the generated key to standard output, allowing it to be assigned to a variable or used directly.
#
# Example:
#   encryption_key=$(shell::generate_random_key)       # Generates a 32-byte key
#   encryption_key=$(shell::generate_random_key 64)    # Generates a 64-byte key
#   echo $encryption_key  # Outputs the generated key
#
# Returns:
#   0 on success, 1 on failure (e.g., OpenSSL not available).
#
# Notes:
#   - Requires OpenSSL to be installed.
shell::generate_random_key() {
	# Check for the help flag (-h)
	if [ "$1" = "-h" ]; then
		echo "$USAGE_SHELL_GENERATE_RANDOM_KEY"
		return 0
	fi

	local bytes="${1:-32}" # Default to 32 bytes if no argument is provided

	# Check if OpenSSL is installed
	if ! shell::is_command_available openssl; then
		shell::stdout "ERR: shell::generate_random_key: OpenSSL is not installed" 196 >&2
		return 1
	fi

	# Validate that bytes is a number
	if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
		shell::stdout "ERR: shell::generate_random_key: Invalid byte size. Must be a number." 196 >&2
		return 1
	fi

	# Generate a random key in hexadecimal format
	local key=$(openssl rand -hex "$bytes")

	# Check if key generation was successful
	if [ -z "$key" ]; then
		shell::stdout "ERR: shell::generate_random_key: Key generation failed" 196 >&2
		return 1
	fi

	echo "$key"
	return 0
}

# shell::encode::aes256cbc function
# Encrypts a string using AES-256-CBC encryption and encodes the result in Base64.
#
# Usage:
#   shell::encode::aes256cbc [-h] <string> [key] [iv]
#
# Parameters:
#   - -h        : Optional. Displays this help message.
#   - <string>  : The string to encrypt.
#   - [key]     : Optional. The encryption key (32 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_KEY.
#   - [iv]      : Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV.
#
# Description:
#   This function encrypts the input string using AES-256-CBC with OpenSSL, using either the provided key
#   or the SHELL_SHIELD_ENCRYPTION_KEY environment variable. The encrypted output is Base64-encoded for safe storage
#   in configuration files, aligning with the library's existing Base64 usage. It checks for OpenSSL availability
#   and validates the key length. The function is compatible with both macOS and Linux.
#
# Example:
#   shell::encode::aes256cbc "sensitive data" "my64byteKey1234567890123456789012345678901234567890"  # Encrypts with specified key
#   export SHELL_SHIELD_ENCRYPTION_KEY="my64byteKey1234567890123456789012345678901234567890"
#   shell::encode::aes256cbc "sensitive data"  # Encrypts with SHELL_SHIELD_ENCRYPTION_KEY
#
# Returns:
#   The Base64-encoded encrypted string on success, or an error message on failure.
#
# Notes:
#   - Relies on the shell::stdout function for output.
#   - Requires OpenSSL to be installed.
#   - The encryption key must be 64 bytes for AES-256-CBC.
#   - If SHELL_SHIELD_ENCRYPTION_KEY is not set and no key is provided, the function fails.
shell::encode::aes256cbc() {
	# Check for the help flag (-h)
	if [ "$1" = "-h" ]; then
		echo "$USAGE_SHELL_ENCODE_AES256CBC"
		return 0
	fi

	local value="$1"
	local key="$2"
	local iv="$3"

	# Validate input
	if [ -z "$value" ]; then
		shell::stdout "ERR: shell::encode::aes256cbc: Missing argument value" 196 >&2
		echo "Usage: shell::encode::aes256cbc [-h] <value> [key] [iv]"
		return 1
	fi

	# Use SHELL_SHIELD_ENCRYPTION_KEY if no key is provided
	if [ -z "$key" ]; then
		local hasKey=$(shell::exist_key_conf "SHELL_SHIELD_ENCRYPTION_KEY")
		if [ "$hasKey" = "false" ]; then
			shell::add_key_conf "SHELL_SHIELD_ENCRYPTION_KEY" "$(shell::generate_random_key 32)"
		fi
		key=$(shell::get_key_conf_value "SHELL_SHIELD_ENCRYPTION_KEY")
	fi

	# Use SHELL_SHIELD_ENCRYPTION_IV if no iv is provided
	if [ -z "$iv" ]; then
		local hasIv=$(shell::exist_key_conf "SHELL_SHIELD_ENCRYPTION_IV")
		if [ "$hasIv" = "false" ]; then
			shell::add_key_conf "SHELL_SHIELD_ENCRYPTION_IV" "$(shell::generate_random_key 16)"
		fi
		iv=$(shell::get_key_conf_value "SHELL_SHIELD_ENCRYPTION_IV")
	fi

	# Validate key length (64 bytes for AES-256)
	if [ ${#key} -ne 64 ]; then
		shell::stdout "ERR: shell::encode::aes256cbc: Encryption key must be exactly 64 bytes" 196 >&2
		return 1
	fi

	# Validate iv length (32 bytes for AES-256)
	if [ ${#iv} -ne 32 ]; then
		shell::stdout "ERR: shell::encode::aes256cbc: Initialization vector must be exactly 32 bytes" 196 >&2
		return 1
	fi

	# Check if OpenSSL is installed
	if ! shell::is_command_available openssl; then
		shell::stdout "ERR: shell::encode::aes256cbc: OpenSSL is not installed" 196 >&2
		return 1
	fi

	# Encrypt the value string and encode in Base64
	local encrypted=$(printf "%s" "$value" | openssl enc -aes-256-cbc -base64 -K "$key" -iv "$iv" 2>/dev/null)
	if [ $? -ne 0 ]; then
		shell::stdout "ERR: shell::encode::aes256cbc: Encryption failed. Please check your key and try again." 196 >&2
		return 1
	fi

	echo "$encrypted"
	shell::clip_value "$encrypted"
	return 0
}

# shell::decode::aes256cbc function
# Decodes a Base64-encoded string and decrypts it using AES-256-CBC.
#
# Usage:
#   shell::decode::aes256cbc [-h] <string> [key] [iv]
#
# Parameters:
#   - -h        : Optional. Displays this help message.
#   - <string>  : The Base64-encoded string to decrypt.
#   - [key]     : Optional. The encryption key (32 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_KEY.
#   - [iv]      : Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV.
#
# Description:
#   This function decodes the Base64-encoded input string and decrypts it using AES-256-CBC with OpenSSL,
#   using either the provided key or the SHELL_SHIELD_ENCRYPTION_KEY environment variable. It checks for OpenSSL
#   availability and validates the key length. The function is compatible with both macOS and Linux.
#
# Example:
#   shell::decode::aes256cbc "Base64EncodedString" "my64byteKey1234567890123456789012345678901234567890"  # Decrypts with specified key
#   export SHELL_SHIELD_ENCRYPTION_KEY="my64byteKey1234567890123456789012345678901234567890"
#   shell::decode::aes256cbc "Base64EncodedString"  # Decrypts with SHELL_SHIELD_ENCRYPTION_KEY
#
# Returns:
#   The decrypted string on success, or an error message on failure.
#
# Notes:
#   - Relies on the shell::stdout function for output.
#   - Requires OpenSSL to be installed.
#   - The encryption key must be 64 bytes for AES-256-CBC.
#   - If SHELL_SHIELD_ENCRYPTION_KEY is not set and no key is provided, the function fails.
shell::decode::aes256cbc() {
	# Check for the help flag (-h)
	if [ "$1" = "-h" ]; then
		echo "$USAGE_SHELL_DECODE_AES256CBC"
		return 0
	fi

	local value="$1"
	local key="$2"
	local iv="$3"
	# Validate input
	if [ -z "$value" ]; then
		shell::stdout "ERR: shell::decode::aes256cbc: Missing argument value" 196 >&2
		echo "Usage: shell::decode::aes256cbc [-h] <value> [key] [iv]"
		return 1
	fi

	# Use SHELL_SHIELD_ENCRYPTION_KEY if no key is provided
	if [ -z "$key" ]; then
		local hasKey=$(shell::exist_key_conf "SHELL_SHIELD_ENCRYPTION_KEY")
		if [ "$hasKey" = "false" ]; then
			shell::stdout "ERR: shell::decode::aes256cbc: SHELL_SHIELD_ENCRYPTION_KEY is not set. Please set it or provide a key." 196 >&2
			return 1
		fi
		key=$(shell::get_key_conf_value "SHELL_SHIELD_ENCRYPTION_KEY")
	fi

	# Use SHELL_SHIELD_ENCRYPTION_IV if no iv is provided
	if [ -z "$iv" ]; then
		local hasIv=$(shell::exist_key_conf "SHELL_SHIELD_ENCRYPTION_IV")
		if [ "$hasIv" = "false" ]; then
			shell::stdout "ERR: shell::decode::aes256cbc: SHELL_SHIELD_ENCRYPTION_IV is not set. Please set it or provide a key." 196 >&2
			return 1
		fi
		iv=$(shell::get_key_conf_value "SHELL_SHIELD_ENCRYPTION_IV")
	fi

	# Validate key length (64 bytes for AES-256)
	if [ ${#key} -ne 64 ]; then
		shell::stdout "ERR: shell::decode::aes256cbc: Encryption key must be exactly 64 bytes" 196 >&2
		return 1
	fi

	# Validate iv length (32 bytes for AES-256)
	if [ ${#iv} -ne 32 ]; then
		shell::stdout "ERR: shell::decode::aes256cbc: Initialization vector must be exactly 32 bytes" 196 >&2
		return 1
	fi

	# Check if OpenSSL is installed
	if ! shell::is_command_available openssl; then
		shell::stdout "ERR: shell::decode::aes256cbc: OpenSSL is not installed" 196 >&2
		return 1
	fi

	local decrypted=$(echo "$value" | openssl enc -aes-256-cbc -d -base64 -K "$key" -iv "$iv" 2>/dev/null)
	if [ $? -ne 0 ]; then
		shell::stdout "ERR: shell::decode::aes256cbc: Decryption failed. Please check your key and try again." 196 >&2
		return 1
	fi

	echo "$decrypted"
	shell::clip_value "$decrypted"
	return 0
}

# shell::cryptography::create_password_hash function
# Creates a password hash using a specified OpenSSL algorithm.
#
# Usage:
#   shell::cryptography::create_password_hash [-h] <algorithm> <password>
#
# Parameters:
#   - -h         : Optional. Displays this help message.
#   - <algorithm>: Hashing algorithm.
#                   -1 for Use the MD5 based BSD password algorithm 1 (default)
#                   -apr1 for Use the apr1 algorithm (Apache variant of the BSD algorithm).
#                   -aixmd5 for Use the AIX MD5 algorithm (AIX variant of the BSD algorithm).
#                   -5 for Use the SHA-256 based hash algorithm
#                   -6 for Use the SHA-512 based hash algorithm
#   - <password> : The plain text password to hash.
#
# Description:
#   This function uses `openssl passwd` to generate a cryptographic hash of a password.
#   It supports various algorithms, including modern secure hashing algorithms like bcrypt
#   (identified by 'B' or 'B2') and SHA-based hashes ('5' for SHA256, '6' for SHA512).
#   The output includes the salt and the hashed password, suitable for storage.
#
# Example:
#   hashed_pass=$(shell::cryptography::create_password_hash 1 "MySecurePassword123!")
#   echo "Hashed password (bcrypt): $hashed_pass"
#
#   hashed_pass_sha256=$(shell::cryptography::create_password_hash 5 "AnotherPassword") # Uses SHA256
#   echo "Hashed password (SHA256): $hashed_pass_sha256"
#
# Returns:
#   The hashed password string on success, or an error message on failure.
#
# Notes:
#   - Requires OpenSSL to be installed.
#   - The 'algorithm' parameter directly corresponds to the flags used with `openssl passwd`.
#     It's crucial to select a strong, modern hashing algorithm.
#   - The function handles prompting for password if not provided directly, but this function
#     expects it as an argument for automation.
shell::cryptography::create_password_hash() {
	# Check for the help flag (-h)
	if [ "$1" = "-h" ]; then
		echo "$USAGE_SHELL_CRYPTOGRAPHY_CREATE_PASSWORD_HASH"
		return 0
	fi

	local algorithm="$1"
	local password="$2"

	if [ -z "$algorithm" ] || [ -z "$password" ]; then
		shell::stdout "ERR: shell::cryptography::create_password_hash: Missing required parameters." 196 >&2
		echo "Usage: shell::cryptography::create_password_hash [-h] <algorithm> <password>"
		return 1
	fi

	if ! shell::is_command_available openssl; then
		shell::stdout "ERR: shell::cryptography::create_password_hash: OpenSSL is not installed." 196 >&2
		return 1
	fi

	# Use openssl passwd. -stdin reads password from stdin.
	# The algorithm is passed as an option, e.g., -1, -apr1, -aixmd5, -5, -6.
	local hashed_password=$(printf "%s" "$password" | openssl passwd "-$algorithm" -stdin 2>/dev/null)

	if [ $? -ne 0 ] || [ -z "$hashed_password" ]; then
		shell::stdout "ERR: shell::cryptography::create_password_hash: Failed to create password hash. Check algorithm or OpenSSL installation." 196 >&2
		return 1
	fi

	echo "$hashed_password"
	return 0
}

# shell::encode::file::aes256cbc function
# Encrypts a file using AES-256-CBC encryption and saves the result to an output file.
#
# Usage:
#   shell::encode::file::aes256cbc [-n] [-h] <input_file> <output_file> [key] [iv]
#
# Parameters:
#   - -n           : Optional. Dry-run mode; prints the command using shell::logger::copy instead of executing it.
#   - -h           : Optional. Displays this help message.
#   - <input_file> : The path to the file to encrypt.
#   - <output_file>: The path where the encrypted file will be saved.
#   - [key]        : Optional. The encryption key (32 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_KEY.
#   - [iv]         : Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV.
#
# Description:
#   This function encrypts the specified input file using AES-256-CBC with OpenSSL, using either the provided key
#   or the SHELL_SHIELD_ENCRYPTION_KEY environment variable. The encrypted output is saved to the specified output file.
#   It checks for OpenSSL availability, validates the key and IV lengths, and ensures the input file exists.
#   The function is compatible with both macOS and Linux. In dry-run mode, it prints the encryption command without executing it.
#
# Example:
#   shell::encode::file::aes256cbc input.txt encrypted.bin "my64byteKey1234567890123456789012345678901234567890"  # Encrypts with specified key
#   export SHELL_SHIELD_ENCRYPTION_KEY="my64byteKey1234567890123456789012345678901234567890"
#   shell::encode::file::aes256cbc -n input.txt encrypted.bin  # Prints encryption command without executing
#
# Returns:
#   0 on success, 1 on failure (e.g., file not found, invalid key, or encryption failure).
#
# Notes:
#   - Relies on the shell::stdout, shell::logger::copy, and shell::run_cmd_eval functions for output and command execution.
#   - Requires OpenSSL to be installed.
#   - The encryption key must be 64 bytes (hex) for AES-256-CBC.
#   - The initialization vector must be 32 bytes (hex) for AES-256-CBC.
#   - If SHELL_SHIELD_ENCRYPTION_KEY or SHELL_SHIELD_ENCRYPTION_IV is not set and no key/IV is provided, the function generates and stores them.
shell::encode::file::aes256cbc() {
	local dry_run="false"

	# Check for help flag (-h)
	if [ "$1" = "-h" ]; then
		echo "$USAGE_SHELL_ENCODE_FILE_AES256CBC"
		return 0
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
		shell::stdout "ERR: shell::encode::file::aes256cbc: Missing input or output file" 196 >&2
		echo "Usage: shell::encode::file::aes256cbc [-n] [-h] <input_file> <output_file> [key] [iv]" >&2
		return 1
	fi

	# Check if input file exists
	if [ ! -f "$input_file" ]; then
		shell::stdout "ERR: shell::encode::file::aes256cbc: Input file '$input_file' does not exist" 196 >&2
		return 1
	fi

	# Check if output file already exists
	if [ -e "$output_file" ] && [ "$dry_run" = "false" ]; then
		shell::stdout "ERR: shell::encode::file::aes256cbc: Output file '$output_file' already exists" 196 >&2
		return 1
	fi

	# Use SHELL_SHIELD_ENCRYPTION_KEY if no key is provided
	if [ -z "$key" ]; then
		local hasKey=$(shell::exist_key_conf "SHELL_SHIELD_ENCRYPTION_KEY")
		if [ "$hasKey" = "false" ]; then
			shell::add_key_conf "SHELL_SHIELD_ENCRYPTION_KEY" "$(shell::generate_random_key 32)"
		fi
		key=$(shell::get_key_conf_value "SHELL_SHIELD_ENCRYPTION_KEY")
	fi

	# Use SHELL_SHIELD_ENCRYPTION_IV if no iv is provided
	if [ -z "$iv" ]; then
		local hasIv=$(shell::exist_key_conf "SHELL_SHIELD_ENCRYPTION_IV")
		if [ "$hasIv" = "false" ]; then
			shell::add_key_conf "SHELL_SHIELD_ENCRYPTION_IV" "$(shell::generate_random_key 16)"
		fi
		iv=$(shell::get_key_conf_value "SHELL_SHIELD_ENCRYPTION_IV")
	fi

	# Validate key length (64 bytes for AES-256)
	if [ ${#key} -ne 64 ]; then
		shell::stdout "ERR: shell::encode::file::aes256cbc: Encryption key must be exactly 64 bytes" 196 >&2
		return 1
	fi

	# Validate iv length (32 bytes for AES-256)
	if [ ${#iv} -ne 32 ]; then
		shell::stdout "ERR: shell::encode::file::aes256cbc: Initialization vector must be exactly 32 bytes" 196 >&2
		return 1
	fi

	# Check if OpenSSL is installed
	if ! shell::is_command_available openssl; then
		shell::stdout "ERR: shell::encode::file::aes256cbc: OpenSSL is not installed" 196 >&2
		return 1
	fi

	# Construct the encryption command
	local cmd="openssl enc -aes-256-cbc -K \"$key\" -iv \"$iv\" -in \"$input_file\" -out \"$output_file\""

	# Execute or print the command based on dry-run mode
	if [ "$dry_run" = "true" ]; then
		shell::logger::copy "$cmd"
		return 0
	fi

	# Encrypt the file using the constructed command
	if ! shell::run_cmd_eval "$cmd" 2>/dev/null; then
		shell::stdout "ERR: shell::encode::file::aes256cbc: Encryption failed. Please check your key and try again." 196 >&2
		return 1
	fi

	shell::stdout "INFO: File encrypted successfully to '$output_file'" 46
	shell::clip_value "$output_file"
	return 0
}

# shell::decode::file::aes256cbc function
# Decrypts a file encrypted with AES-256-CBC and saves the result to an output file.
#
# Usage:
#   shell::decode::file::aes256cbc [-n] [-h] <input_file> <output_file> [key] [iv]
#
# Parameters:
#   - -n           : Optional. Dry-run mode; prints the command using shell::logger::copy instead of executing it.
#   - -h           : Optional. Displays this help message.
#   - <input_file> : The path to the encrypted file to decrypt.
#   - <output_file>: The path where the decrypted file will be saved.
#   - [key]        : Optional. The encryption key (32 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_KEY.
#   - [iv]         : Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV.
#
# Description:
#   This function decrypts the specified input file using AES-256-CBC with OpenSSL, using either the provided key
#   or the SHELL_SHIELD_ENCRYPTION_KEY environment variable. The decrypted output is saved to the specified output file.
#   It checks for OpenSSL availability, validates the key and IV lengths, and ensures the input file exists.
#   The function is compatible with both macOS and Linux. In dry-run mode, it prints the decryption command without executing it.
#
# Example:
#   shell::decode::file::aes256cbc encrypted.bin output.txt "my64byteKey1234567890123456789012345678901234567890"  # Decrypts with specified key
#   export SHELL_SHIELD_ENCRYPTION_KEY="my64byteKey1234567890123456789012345678901234567890"
#   shell::decode::file::aes256cbc -n encrypted.bin output.txt  # Prints decryption command without executing
#
# Returns:
#   0 on success, 1 on failure (e.g., file not found, invalid key, or decryption failure).
#
# Notes:
#   - Relies on the shell::stdout, shell::logger::copy, and shell::run_cmd_eval functions for output and command execution.
#   - Requires OpenSSL to be installed.
#   - The encryption key must be 64 bytes (hex) for AES-256-CBC.
#   - The initialization vector must be 32 bytes (hex) for AES-256-CBC.
#   - If SHELL_SHIELD_ENCRYPTION_KEY or SHELL_SHIELD_ENCRYPTION_IV is not set and no key/IV is provided, the function fails.
shell::decode::file::aes256cbc() {
	local dry_run="false"

	# Check for help flag (-h)
	if [ "$1" = "-h" ]; then
		echo "$USAGE_SHELL_DECODE_FILE_AES256CBC"
		return 0
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
		shell::stdout "ERR: shell::decode::file::aes256cbc: Missing input or output file" 196 >&2
		echo "Usage: shell::decode::file::aes256cbc [-n] [-h] <input_file> <output_file> [key] [iv]" >&2
		return 1
	fi

	# Check if input file exists
	if [ ! -f "$input_file" ]; then
		shell::stdout "ERR: shell::decode::file::aes256cbc: Input file '$input_file' does not exist" 196 >&2
		return 1
	fi

	# Check if output file already exists
	if [ -e "$output_file" ] && [ "$dry_run" = "false" ]; then
		shell::stdout "ERR: shell::decode::file::aes256cbc: Output file '$output_file' already exists" 196 >&2
		return 1
	fi

	# Use SHELL_SHIELD_ENCRYPTION_KEY if no key is provided
	if [ -z "$key" ]; then
		local hasKey=$(shell::exist_key_conf "SHELL_SHIELD_ENCRYPTION_KEY")
		if [ "$hasKey" = "false" ]; then
			shell::stdout "ERR: shell::decode::file::aes256cbc: SHELL_SHIELD_ENCRYPTION_KEY is not set. Please set it or provide a key." 196 >&2
			return 1
		fi
		key=$(shell::get_key_conf_value "SHELL_SHIELD_ENCRYPTION_KEY")
	fi

	# Use SHELL_SHIELD_ENCRYPTION_IV if no iv is provided
	if [ -z "$iv" ]; then
		local hasIv=$(shell::exist_key_conf "SHELL_SHIELD_ENCRYPTION_IV")
		if [ "$hasIv" = "false" ]; then
			shell::stdout "ERR: shell::decode::file::aes256cbc: SHELL_SHIELD_ENCRYPTION_IV is not set. Please set it or provide an IV." 196 >&2
			return 1
		fi
		iv=$(shell::get_key_conf_value "SHELL_SHIELD_ENCRYPTION_IV")
	fi

	# Validate key length (64 bytes for AES-256)
	if [ ${#key} -ne 64 ]; then
		shell::stdout "ERR: shell::decode::file::aes256cbc: Encryption key must be exactly 64 bytes" 196 >&2
		return 1
	fi

	# Validate iv length (32 bytes for AES-256)
	if [ ${#iv} -ne 32 ]; then
		shell::stdout "ERR: shell::decode::file::aes256cbc: Initialization vector must be exactly 32 bytes" 196 >&2
		return 1
	fi

	# Check if OpenSSL is installed
	if ! shell::is_command_available openssl; then
		shell::stdout "ERR: shell::decode::file::aes256cbc: OpenSSL is not installed" 196 >&2
		return 1
	fi

	# Construct the decryption command
	local cmd="openssl enc -aes-256-cbc -d -K \"$key\" -iv \"$iv\" -in \"$input_file\" -out \"$output_file\""

	# Execute or print the command based on dry-run mode
	if [ "$dry_run" = "true" ]; then
		shell::logger::copy "$cmd"
		return 0
	fi

	# Decrypt the file using the constructed command
	if ! shell::run_cmd_eval "$cmd" 2>/dev/null; then
		shell::stdout "ERR: shell::decode::file::aes256cbc: Decryption failed. Please check your key and try again." 196 >&2
		return 1
	fi

	shell::stdout "INFO: File decrypted successfully to '$output_file'" 46
	shell::clip_value "$output_file"
	return 0
}
