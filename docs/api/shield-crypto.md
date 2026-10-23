# shield/crypto.sh

AES-256-CBC encryption helpers.

## Overview

Generates a random encryption key of specified length (in bytes) and outputs it to standard output.

This function uses OpenSSL to generate a random key of the specified length in hexadecimal format.
It outputs the generated key to standard output, allowing it to be assigned to a variable or used directly.

Notes:
- Requires OpenSSL to be installed.

## Index

* [shell::crypto::key::generate](#shellcryptokeygenerate)
* [shell::crypto::aes256cbc::encode](#shellcryptoaes256cbcencode)
* [shell::crypto::aes256cbc::decode](#shellcryptoaes256cbcdecode)
* [shell::crypto::password::hash](#shellcryptopasswordhash)
* [shell::crypto::aes256cbc::encode_file](#shellcryptoaes256cbcencode_file)
* [shell::crypto::aes256cbc::decode_file](#shellcryptoaes256cbcdecode_file)

### shell::crypto::key::generate

Generates a random encryption key of specified length (in bytes) and outputs it to standard output.

This function uses OpenSSL to generate a random key of the specified length in hexadecimal format.
It outputs the generated key to standard output, allowing it to be assigned to a variable or used directly.

Notes:
- Requires OpenSSL to be installed.

#### Example

```bash
encryption_key=$(shell::crypto::key::generate)       # Generates a 32-byte key
encryption_key=$(shell::crypto::key::generate 64)    # Generates a 64-byte key
echo $encryption_key  # Outputs the generated key
```

#### Arguments

* **...** (string): bytes: Optional. The length of the key to generate, in bytes. Defaults to 32 bytes.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::crypto::aes256cbc::encode

Encrypts a string using AES-256-CBC encryption and encodes the result in Base64.

This function encrypts the input string using AES-256-CBC with OpenSSL, using either the provided key
or the SHELL_SHIELD_ENCRYPTION_KEY environment variable. The encrypted output is Base64-encoded for safe storage
in configuration files, aligning with the library's existing Base64 usage. It checks for OpenSSL availability
and validates the key length. The function is compatible with both macOS and Linux.

Notes:
- Relies on the shell::console::print function for output.
- Requires OpenSSL to be installed.
- The encryption key must be 64 bytes for AES-256-CBC.
- If SHELL_SHIELD_ENCRYPTION_KEY is not set and no key is provided, the function fails.

#### Example

```bash
shell::crypto::aes256cbc::encode "sensitive data" "my64byteKey1234567890123456789012345678901234567890"  # Encrypts with specified key
export SHELL_SHIELD_ENCRYPTION_KEY="my64byteKey1234567890123456789012345678901234567890"
shell::crypto::aes256cbc::encode "sensitive data"  # Encrypts with SHELL_SHIELD_ENCRYPTION_KEY
```

#### Options

* **-h**

  Optional. Displays this help message.

#### Arguments

* **$1** (string): string: The string to encrypt.
* **...** (string): iv: Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::crypto::aes256cbc::decode

Decodes a Base64-encoded string and decrypts it using AES-256-CBC.

This function decodes the Base64-encoded input string and decrypts it using AES-256-CBC with OpenSSL,
using either the provided key or the SHELL_SHIELD_ENCRYPTION_KEY environment variable. It checks for OpenSSL
availability and validates the key length. The function is compatible with both macOS and Linux.

Notes:
- Relies on the shell::console::print function for output.
- Requires OpenSSL to be installed.
- The encryption key must be 64 bytes for AES-256-CBC.
- If SHELL_SHIELD_ENCRYPTION_KEY is not set and no key is provided, the function fails.

#### Example

```bash
shell::crypto::aes256cbc::decode "Base64EncodedString" "my64byteKey1234567890123456789012345678901234567890"  # Decrypts with specified key
export SHELL_SHIELD_ENCRYPTION_KEY="my64byteKey1234567890123456789012345678901234567890"
shell::crypto::aes256cbc::decode "Base64EncodedString"  # Decrypts with SHELL_SHIELD_ENCRYPTION_KEY
```

#### Options

* **-h**

  Optional. Displays this help message.

#### Arguments

* **$1** (string): string: The Base64-encoded string to decrypt.
* **...** (string): iv: Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::crypto::password::hash

Creates a password hash using a specified OpenSSL algorithm.

This function uses `openssl passwd` to generate a cryptographic hash of a password.
It supports various algorithms, including modern secure hashing algorithms like bcrypt
(identified by 'B' or 'B2') and SHA-based hashes ('5' for SHA256, '6' for SHA512).
The output includes the salt and the hashed password, suitable for storage.

Notes:
- Requires OpenSSL to be installed.
- The 'algorithm' parameter directly corresponds to the flags used with `openssl passwd`.
It's crucial to select a strong, modern hashing algorithm.
- The function handles prompting for password if not provided directly, but this function
expects it as an argument for automation.

#### Example

```bash
hashed_pass=$(shell::crypto::password::hash 1 "MySecurePassword123!")
echo "Hashed password (bcrypt): $hashed_pass"
hashed_pass_sha256=$(shell::crypto::password::hash 5 "AnotherPassword") # Uses SHA256
echo "Hashed password (SHA256): $hashed_pass_sha256"
```

#### Options

* **-h**

  Optional. Displays this help message.

#### Arguments

* **$1** (string): algorithm: Hashing algorithm. -1 for Use the MD5 based BSD password algorithm 1 (default) -apr1 for Use the apr1 algorithm (Apache variant of the BSD algorithm). -aixmd5 for Use the AIX MD5 algorithm (AIX variant of the BSD algorithm). -5 for Use the SHA-256 based hash algorithm -6 for Use the SHA-512 based hash algorithm
* **$2** (string): password: The plain text password to hash.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::crypto::aes256cbc::encode_file

Encrypts a file using AES-256-CBC encryption and saves the result to an output file.

This function encrypts the specified input file using AES-256-CBC with OpenSSL, using either the provided key
or the SHELL_SHIELD_ENCRYPTION_KEY environment variable. The encrypted output is saved to the specified output file.
It checks for OpenSSL availability, validates the key and IV lengths, and ensures the input file exists.
The function is compatible with both macOS and Linux. In dry-run mode, it prints the encryption command without executing it.

Notes:
- Relies on the shell::console::print, shell::logger::command_clip, and shell::exec::shell functions for output and command execution.
- Requires OpenSSL to be installed.
- The encryption key must be 64 bytes (hex) for AES-256-CBC.
- The initialization vector must be 32 bytes (hex) for AES-256-CBC.
- If SHELL_SHIELD_ENCRYPTION_KEY or SHELL_SHIELD_ENCRYPTION_IV is not set and no key/IV is provided, the function generates and stores them.

#### Example

```bash
shell::crypto::aes256cbc::encode_file input.txt encrypted.bin "my64byteKey1234567890123456789012345678901234567890"  # Encrypts with specified key
export SHELL_SHIELD_ENCRYPTION_KEY="my64byteKey1234567890123456789012345678901234567890"
shell::crypto::aes256cbc::encode_file -n input.txt encrypted.bin  # Prints encryption command without executing
```

#### Options

* **-n**

  Optional. Dry-run mode; prints the command using shell::logger::command_clip instead of executing it.

* **-h**

  Optional. Displays this help message.

#### Arguments

* **$1** (string): input_file: The path to the file to encrypt.
* **$2** (string): output_file: The path where the encrypted file will be saved.
* **...** (string): iv: Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

### shell::crypto::aes256cbc::decode_file

Decrypts a file encrypted with AES-256-CBC and saves the result to an output file.

This function decrypts the specified input file using AES-256-CBC with OpenSSL, using either the provided key
or the SHELL_SHIELD_ENCRYPTION_KEY environment variable. The decrypted output is saved to the specified output file.
It checks for OpenSSL availability, validates the key and IV lengths, and ensures the input file exists.
The function is compatible with both macOS and Linux. In dry-run mode, it prints the decryption command without executing it.

Notes:
- Relies on the shell::console::print, shell::logger::command_clip, and shell::exec::shell functions for output and command execution.
- Requires OpenSSL to be installed.
- The encryption key must be 64 bytes (hex) for AES-256-CBC.
- The initialization vector must be 32 bytes (hex) for AES-256-CBC.
- If SHELL_SHIELD_ENCRYPTION_KEY or SHELL_SHIELD_ENCRYPTION_IV is not set and no key/IV is provided, the function fails.

#### Example

```bash
shell::crypto::aes256cbc::decode_file encrypted.bin output.txt "my64byteKey1234567890123456789012345678901234567890"  # Decrypts with specified key
export SHELL_SHIELD_ENCRYPTION_KEY="my64byteKey1234567890123456789012345678901234567890"
shell::crypto::aes256cbc::decode_file -n encrypted.bin output.txt  # Prints decryption command without executing
```

#### Options

* **-n**

  Optional. Dry-run mode; prints the command using shell::logger::command_clip instead of executing it.

* **-h**

  Optional. Displays this help message.

#### Arguments

* **$1** (string): input_file: The path to the encrypted file to decrypt.
* **$2** (string): output_file: The path where the decrypted file will be saved.
* **...** (string): iv: Optional. The initialization vector (16 bytes for AES-256). If not provided, uses SHELL_SHIELD_ENCRYPTION_IV.

#### Exit codes

* **0**: Success.
* **1**: The operation failed.

