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
        shell::colored_echo "🔴 shell::generate_random_key: OpenSSL is not installed" 196 >&2
        return 1
    fi

    # Validate that bytes is a number
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        shell::colored_echo "🔴 shell::generate_random_key: Invalid byte size. Must be a number." 196 >&2
        return 1
    fi

    # Generate a random key in hexadecimal format
    local key=$(openssl rand -hex "$bytes")

    # Check if key generation was successful
    if [ -z "$key" ]; then
        shell::colored_echo "🔴 shell::generate_random_key: Key generation failed" 196 >&2
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
#   - Relies on the shell::colored_echo function for output.
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
        shell::colored_echo "🔴 shell::encode::aes256cbc: Missing argument value" 196 >&2
        echo "Usage: shell::encode::aes256cbc [-h] <value> [key] [iv]"
        return 1
    fi

    # Use SHELL_SHIELD_ENCRYPTION_KEY if no key is provided
    if [ -z "$key" ]; then
        local hasKey=$(shell::exist_key_conf "SHELL_SHIELD_ENCRYPTION_KEY")
        if [ "$hasKey" = "false" ]; then
            shell::add_conf "SHELL_SHIELD_ENCRYPTION_KEY" "$(shell::generate_random_key 32)"
        fi
        key=$(shell::get_value_conf "SHELL_SHIELD_ENCRYPTION_KEY")
    fi

    # Use SHELL_SHIELD_ENCRYPTION_IV if no iv is provided
    if [ -z "$iv" ]; then
        local hasIv=$(shell::exist_key_conf "SHELL_SHIELD_ENCRYPTION_IV")
        if [ "$hasIv" = "false" ]; then
            shell::add_conf "SHELL_SHIELD_ENCRYPTION_IV" "$(shell::generate_random_key 16)"
        fi
        iv=$(shell::get_value_conf "SHELL_SHIELD_ENCRYPTION_IV")
    fi

    # Validate key length (64 bytes for AES-256)
    if [ ${#key} -ne 64 ]; then
        shell::colored_echo "🔴 shell::encode::aes256cbc: Encryption key must be exactly 64 bytes" 196 >&2
        return 1
    fi

    # Validate iv length (32 bytes for AES-256)
    if [ ${#iv} -ne 32 ]; then
        shell::colored_echo "🔴 shell::encode::aes256cbc: Initialization vector must be exactly 32 bytes" 196 >&2
        return 1
    fi

    # Check if OpenSSL is installed
    if ! shell::is_command_available openssl; then
        shell::colored_echo "🔴 shell::encode::aes256cbc: OpenSSL is not installed" 196 >&2
        return 1
    fi

    # Encrypt the value string and encode in Base64
    local encrypted=$(printf "%s" "$value" | openssl enc -aes-256-cbc -base64 -K "$key" -iv "$iv" 2>/dev/null)
    if [ $? -ne 0 ]; then
        shell::colored_echo "🔴 shell::encode::aes256cbc: Encryption failed. Please check your key and try again." 196 >&2
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
#   - Relies on the shell::colored_echo function for output.
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
        shell::colored_echo "🔴 shell::decode::aes256cbc: Missing argument value" 196 >&2
        echo "Usage: shell::decode::aes256cbc [-h] <value> [key] [iv]"
        return 1
    fi

    # Use SHELL_SHIELD_ENCRYPTION_KEY if no key is provided
    if [ -z "$key" ]; then
        local hasKey=$(shell::exist_key_conf "SHELL_SHIELD_ENCRYPTION_KEY")
        if [ "$hasKey" = "false" ]; then
            shell::colored_echo "🔴 shell::decode::aes256cbc: SHELL_SHIELD_ENCRYPTION_KEY is not set. Please set it or provide a key." 196 >&2
            return 1
        fi
        key=$(shell::get_value_conf "SHELL_SHIELD_ENCRYPTION_KEY")
    fi

    # Use SHELL_SHIELD_ENCRYPTION_IV if no iv is provided
    if [ -z "$iv" ]; then
        local hasIv=$(shell::exist_key_conf "SHELL_SHIELD_ENCRYPTION_IV")
        if [ "$hasIv" = "false" ]; then
            shell::colored_echo "🔴 shell::decode::aes256cbc: SHELL_SHIELD_ENCRYPTION_IV is not set. Please set it or provide a key." 196 >&2
            return 1
        fi
        iv=$(shell::get_value_conf "SHELL_SHIELD_ENCRYPTION_IV")
    fi

    # Validate key length (64 bytes for AES-256)
    if [ ${#key} -ne 64 ]; then
        shell::colored_echo "🔴 shell::decode::aes256cbc: Encryption key must be exactly 64 bytes" 196 >&2
        return 1
    fi

    # Validate iv length (32 bytes for AES-256)
    if [ ${#iv} -ne 32 ]; then
        shell::colored_echo "🔴 shell::decode::aes256cbc: Initialization vector must be exactly 32 bytes" 196 >&2
        return 1
    fi

    # Check if OpenSSL is installed
    if ! shell::is_command_available openssl; then
        shell::colored_echo "🔴 shell::decode::aes256cbc: OpenSSL is not installed" 196 >&2
        return 1
    fi

    local decrypted=$(echo "$value" | openssl enc -aes-256-cbc -d -base64 -K "$key" -iv "$iv" 2>/dev/null)
    if [ $? -ne 0 ]; then
        shell::colored_echo "🔴 shell::decode::aes256cbc: Decryption failed. Please check your key and try again." 196 >&2
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
#   - <algorithm>: Hashing algorithm (e.g., a, B, B2, 5, 6 for MD5, Blowfish, bcrypt, SHA256, SHA512 based hashes).
#                  Refer to `man openssl passwd` for supported algorithms and their identifiers.
#   - <password> : The plain text password to hash.
#
# Description:
#   This function uses `openssl passwd` to generate a cryptographic hash of a password.
#   It supports various algorithms, including modern secure hashing algorithms like bcrypt
#   (identified by 'B' or 'B2') and SHA-based hashes ('5' for SHA256, '6' for SHA512).
#   The output includes the salt and the hashed password, suitable for storage.
#
# Example:
#   hashed_pass=$(shell::cryptography::create_password_hash B "MySecurePassword123!") # Uses bcrypt
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
        shell::colored_echo "🔴 shell::cryptography::create_password_hash: Missing required parameters." 196 >&2
        echo "Usage: shell::cryptography::create_password_hash [-h] <algorithm> <password>"
        return 1
    fi

    if ! shell::is_command_available openssl; then
        shell::colored_echo "🔴 shell::cryptography::create_password_hash: OpenSSL is not installed." 196 >&2
        return 1
    fi

    # Use openssl passwd. -stdin reads password from stdin.
    # The algorithm is passed as an option, e.g., -a, -B, -5, -6.
    local hashed_password=$(printf "%s" "$password" | openssl passwd "-$algorithm" -stdin 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$hashed_password" ]; then
        shell::colored_echo "🔴 shell::cryptography::create_password_hash: Failed to create password hash. Check algorithm or OpenSSL installation." 196 >&2
        return 1
    fi

    echo "$hashed_password"
    return 0
}
