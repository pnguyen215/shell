# lib/ssh_agent.sh

The ssh agent: start, stop, list, add and remove keys.

## Overview

The agent keeps decrypted keys in memory, so a passphrase is typed once per
session instead of once per connection.

Things worth knowing:

- `shell::ssh::agent::start` sets `SSH_AUTH_SOCK` and `SSH_AGENT_PID` in **the
  shell you call it from**, which is the point (it is what `eval "$(ssh-agent -s)"`
  does). For that reason do not run it inside `$( ... )` or a pipeline: the
  variables would be lost with the subshell. `shell::ssh::agent::stop` unsets them.
- It does nothing when an agent is already reachable (the one of your desktop,
  or a forwarded one), so it is safe to call from a profile.
- No passphrase is taken on the command line; ssh-add asks for it.
- `--lifetime` makes a key leave the agent by itself after that many seconds.
- `--keychain` stores the passphrase in the macOS keychain
  (`ssh-add --apple-use-keychain`); it exists on macOS only.

## Index

- [shell::ssh::agent::start](#shellsshagentstart)
- [shell::ssh::agent::stop](#shellsshagentstop)
- [shell::ssh::agent::list](#shellsshagentlist)
- [shell::ssh::agent::add](#shellsshagentadd)
- [shell::ssh::agent::add::fzf](#shellsshagentaddfzf)
- [shell::ssh::agent::remove](#shellsshagentremove)
- [shell::ssh::agent::clear](#shellsshagentclear)

### shell::ssh::agent::start

Start an ssh agent in this shell (`eval "$(ssh-agent -s)"`).
Sets `SSH_AUTH_SOCK` and `SSH_AGENT_PID` here. Nothing is done when an agent
is already reachable. Do not run it in `$( ... )` or a pipeline.

#### Example

```bash
shell::ssh::agent::start && shell::ssh::agent::add
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Exit codes

- **0**: An agent is running (started now, or already there).
- **1**: ssh-agent failed or printed something unexpected.
- **3**: ssh-agent is missing.

#### See also

- [shell::ssh::agent::stop](#shellsshagentstop)

### shell::ssh::agent::stop

Stop the agent this shell started (`ssh-agent -k`).
Works from `SSH_AGENT_PID`, so it only stops an agent started with
`shell::ssh::agent::start` (or `eval "$(ssh-agent -s)"`) in this shell, never
the agent of your desktop session. Unsets `SSH_AUTH_SOCK` and `SSH_AGENT_PID`.

#### Example

```bash
shell::ssh::agent::stop
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Exit codes

- **0**: The agent was stopped.
- **1**: ssh-agent could not stop it.
- **3**: ssh-agent is missing, or this shell did not start an agent.

#### See also

- [shell::ssh::agent::start](#shellsshagentstart)

### shell::ssh::agent::list

List the keys the agent holds (`ssh-add -l`).

#### Example

```bash
shell::ssh::agent::list
shell::ssh::agent::list --public
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **--public**

  Print the public keys themselves (`ssh-add -L`) instead of fingerprints.

#### Exit codes

- **0**: The agent holds at least one key.
- **1**: No agent could be reached.
- **3**: ssh-add is missing.
- **8**: The agent holds no key.

#### Output on stdout

- One line per key.

#### See also

- [shell::ssh::agent::add](#shellsshagentadd)

### shell::ssh::agent::add

Add keys to the agent (`ssh-add [key...]`).
Without a key, ssh-add loads the default ones (`~/.ssh/id_ed25519`, `id_rsa` ...).
The agent must be reachable (see `shell::ssh::agent::start`). ssh-add asks for
the passphrase; nothing is taken on the command line.

#### Example

```bash
shell::ssh::agent::add
shell::ssh::agent::add -t 3600 ~/.ssh/id_ed25519
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-t** | **--lifetime \<sec\>**

  Drop the key from the agent after this many seconds.

- **--keychain**

  Store the passphrase in the macOS keychain (macOS only).

#### Arguments

- **...** (string): Optional private key files.

#### Exit codes

- **0**: Success.
- **1**: No agent could be reached.
- **2**: Unknown option or an invalid lifetime.
- **3**: ssh-add or a key is missing.
- **4**: `--keychain` was used on another system than macOS.
- N Exit status of ssh-add.

#### See also

- [shell::ssh::agent::add::fzf](#shellsshagentaddfzf)

### shell::ssh::agent::add::fzf

Pick private keys with fzf and add them to the agent.
The keys are the private keys found in `~/.ssh`; the preview shows the
fingerprint of the highlighted one. Several keys can be marked (Tab).

#### Example

```bash
shell::ssh::agent::add::fzf
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

- **-t** | **--lifetime \<sec\>**

  Drop the keys from the agent after this many seconds.

- **--keychain**

  Store the passphrases in the macOS keychain (macOS only).

#### Exit codes

- **0**: Success.
- **1**: No agent could be reached.
- **8**: There is no private key in `~/.ssh`.
- **9**: The selection was cancelled.
- N Exit status of shell::ssh::agent::add.

#### See also

- [shell::ssh::agent::add](#shellsshagentadd)

### shell::ssh::agent::remove

Remove keys from the agent (`ssh-add -d key`).
The key files stay on disk; only the copy in the agent's memory goes.

#### Example

```bash
shell::ssh::agent::remove ~/.ssh/id_ed25519
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Arguments

- **...** (string): One or more key files (the private key or its `.pub`).

#### Exit codes

- **0**: Success.
- **1**: No agent could be reached.
- **2**: Unknown option, or no key given.
- **3**: ssh-add or a key file is missing.
- N Exit status of ssh-add.

#### See also

- [shell::ssh::agent::clear](#shellsshagentclear)

### shell::ssh::agent::clear

Remove every key from the agent (`ssh-add -D`).
The key files stay on disk; only the copies in the agent's memory go.

#### Example

```bash
shell::ssh::agent::clear
```

#### Options

- **-h** | **--help**

  Show help and return.

- **-n** | **--dry-run**

  Print the command instead of running it.

#### Exit codes

- **0**: Success.
- **1**: No agent could be reached.
- **3**: ssh-add is missing.
- N Exit status of ssh-add.

#### See also

- [shell::ssh::agent::remove](#shellsshagentremove)
