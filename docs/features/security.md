# Security investigation (Phase 1: foundation and first hunts)

`shell::security::*` helps administrators, SREs and incident responders look at a machine **they own or are authorised to investigate**. It is **read-only**: it never changes a setting, never deletes or restores a file, never calls `sudo`, and never touches another host.

> **Status.** This is Phase 1 of a phased roadmap (see [Roadmap](#roadmap)). Forensics, RCA, integrity monitoring, SSH audit, hardening and the unified `investigate` workflow are **not implemented yet**; they are listed as planned, not as available.

| Property    | Value                                                                                                                       |
| ----------- | --------------------------------------------------------------------------------------------------------------------------- |
| Audience    | System administrators, DevOps, SRE, security engineers, incident responders                                                 |
| Last review | 2026-11-13                                                                                                                  |
| Platforms   | macOS (Intel and Apple Silicon), Linux (Ubuntu 22.04 / 24.04 targeted); bash 3.2+ and zsh                                   |
| Source      | `src/shield/security_*.sh`, `src/constant/security.sh`; tests in `test/test_security_core.sh`, `test/test_security_hunt.sh` |

## What a finding is

Every detection produces a **finding** with the same fields, in every output format:

`id`, `category`, `severity`, `description`, `resource`, `detected_at`, `evidence_source`, `rationale`, `confidence`, `investigate`, `remediate`.

| Severity   | Meaning                                                            |
| ---------- | ------------------------------------------------------------------ |
| `CRITICAL` | Strong evidence of active compromise or severe exposure            |
| `HIGH`     | Significant suspicious activity that needs immediate investigation |
| `MEDIUM`   | Potential issue that needs validation                              |
| `LOW`      | Minor weakness or configuration concern                            |
| `INFO`     | Inventory or coverage note                                         |

**A finding is an indicator, not proof.** Each one states _why it fired_ and which ordinary software can cause the same signal (installers run from `/tmp`, administrators start netcat, and so on), and gives `confidence` (`high`, `medium`, `low`). Nothing is labelled "malicious". The finding `id` is derived from category, resource and description, so the same observation is stored once.

**Unavailable is not empty.** When a check cannot run (a missing `ps`/`ss`/`lsof`, an unreadable file) the report contains an `INFO` finding `Not inspected: ...` and the function returns `3`. A report with no findings says so and points at these entries; it never implies "clean".

## Public functions

| Function                             | What it does                                                                                                                                                                                                 | Extra options                                            |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------- |
| `shell::security::capabilities`      | Which investigations can run here and which tool provides each (also shows unsupported ones)                                                                                                                 |                                                          |
| `shell::security::host::info`        | OS, kernel, architecture, hostname, CPU, cores, memory                                                                                                                                                       |                                                          |
| `shell::security::host::users`       | Non-root UID 0 accounts (`HIGH`), administrator group members and active sessions (`INFO`)                                                                                                                   |                                                          |
| `shell::security::hunt::processes`   | Executables in temp directories (hidden or deleted ones rank higher), deleted binaries, shells started by servers, reverse-shell / miner / base64-exec / download-exec command lines, very high CPU (`INFO`) |                                                          |
| `shell::security::hunt::network`     | Non-loopback listeners (risky ports graded), DNS resolvers, proxy settings (credentials stripped)                                                                                                            |                                                          |
| `shell::security::hunt::connections` | Established connections correlated with their process: temp-dir process with a remote peer (`HIGH`), remote ports often used by miners / RATs (`MEDIUM`, low confidence)                                     | `--list` prints the connection table instead of findings |

Common options (every function except `capabilities`/`host::info` which take only `-f`): `-f, --format text|json|markdown|csv` (default `text`), `--min-severity INFO|LOW|MEDIUM|HIGH|CRITICAL` (default `INFO`), `-h, --help`.

All other functions of the module start with `_shell::security::` and are private.

## Examples

```bash
shell::security::capabilities                       # what can run on this machine
shell::security::host::info --format json
shell::security::hunt::processes --min-severity MEDIUM
shell::security::hunt::network --format markdown > network-findings.md
shell::security::hunt::connections --list --format csv
```

## Output formats

| Format     | Notes                                                                                                                                        |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `text`     | Severity-tagged blocks, summary line; colour only when stdout is a terminal and `NO_COLOR` is unset                                          |
| `json`     | One object: `schema` (`shell-security-findings/1`), `generated_at`, `host`, `summary` counts, `findings[]`. Dependency-free (no `jq` needed) |
| `markdown` | Built with `shell::markdown::*`; uses the shared Markdown buffer (it starts a new document)                                                  |
| `csv`      | RFC 4180, every cell quoted; a cell starting with `= + - @` gets a leading `'` so a spreadsheet cannot run it as a formula                   |

Data goes to **stdout**; diagnostics (errors, warnings) go to **stderr** through `shell::logger::*`, so `... --format json > out.json` is clean.

## Return codes

| Code | Meaning                                                            |
| ---- | ------------------------------------------------------------------ |
| 0    | Ran. Findings do **not** change the exit code                      |
| 2    | Invalid option, format or severity                                 |
| 3    | A required tool is missing; the report lists it as "Not inspected" |

## Permissions

No privileges are required. Without root, the owning process of **other users'** sockets and some process details are not visible: those rows are reported as "owner unknown" (an `INFO` finding), never as "no owner". Run as an account you are authorised to use for a complete view. The library never elevates privileges on its own.

## Security considerations

- **Secrets are masked.** Every finding passes through a sanitiser: `password`, `token`, `secret`, `api_key`, `authorization`, `bearer ...`, `scheme://user:password@host` and similar values become `[REDACTED]` (list: `SHELL_SECURITY_SECRET_WORDS`). Proxy variables are reduced to `host:port`. Environment variables are never dumped. Masking is pattern-based, so treat reports as sensitive anyway.
- The finding store is a private temporary file (mode 600) that is removed when the function finishes. No `trap` is installed.
- Detection rules are deliberately conservative and live in `src/constant/security.sh` (`SHELL_SECURITY_CMD_RULES`, `SHELL_SECURITY_EXPOSED_PORTS`, `SHELL_SECURITY_TMP_DIRS`, ...); override them before sourcing the library.
- Service names for exposed ports are inferred **from the port number only** and say so.
- Network checks observe this host's own sockets; nothing is scanned or contacted.

## Optional dependencies and platform notes

| Capability     | Linux                                    | macOS                        | Without it                              |
| -------------- | ---------------------------------------- | ---------------------------- | --------------------------------------- |
| Process list   | `ps`                                     | `ps`                         | "Not inspected", rc 3                   |
| Sockets        | `ss` (iproute2), else `lsof`             | `lsof`                       | "Not inspected", rc 3                   |
| Real exe path  | `/proc/<pid>/exe`                        | not available                | first absolute word of the command line |
| Administrators | `/etc/group` (`sudo admin wheel`)        | `dscl . -read /Groups/admin` | "Not inspected"                         |
| DNS resolvers  | `/etc/resolv.conf`                       | `scutil --dns`               | "Not inspected"                         |
| SHA-256        | `sha256sum`, `shasum`, `openssl`         | `shasum`, `openssl`          | finding ids fall back to `cksum`        |
| `jq`           | optional, only to validate JSON in tests |                              |                                         |

Known limitations: a command line with spaces in the program path is split at the first space (the program is still found in the temp-dir check); accounts that exist only in LDAP/directory services are not in the administrator inventory; users' `ps` output can be truncated by the platform for very long names; macOS has no `/proc`, so a deleted binary cannot be detected there.

## Troubleshooting

| Symptom                                     | Cause and fix                                                                                  |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `Not inspected: listening sockets`          | Neither `ss` nor `lsof` is installed. Install `iproute2` or `lsof`                             |
| "owning process ... could not be read"      | Normal without root; rerun with the privileges you are authorised to use                       |
| `Unknown format` / `Unknown severity`       | Use the values listed above (case-sensitive: `HIGH`, not `high`)                               |
| Markdown output replaced my Markdown buffer | `--format markdown` reuses `shell::markdown::*`; call `shell::markdown::init` again afterwards |

## Roadmap

Planned, **not yet available**: persistence and authentication hunts, `hunt::suspicious_files`/`ioc`/`all`; `forensics::*` (evidence collection, SHA-256 manifest, verification, timeline, export); `shell::diagnostic::rca::*`; `integrity::*` baselines; `ssh::*` audit (reusing `shell::ssh::*`); `hardening::*` (audit-only by default, `-n`, backups, explicit confirmation, never implicit `sudo`); `host::audit/privileges/permissions/firewall/encryption/report`; and the `shell::security::investigate` workflow that merges findings from these modules.
