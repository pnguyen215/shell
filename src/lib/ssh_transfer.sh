#!/usr/bin/env bash
# @file lib/ssh_transfer.sh
# @brief Copy and sync files over SSH: scp, rsync and sftp.
# @description
#   `shell::ssh::scp::upload` and `shell::ssh::scp::download` are `scp`,
#   `shell::ssh::rsync::push` and `shell::ssh::rsync::pull` are `rsync -avz -e ssh`,
#   and `shell::ssh::sftp::connect` is an interactive `sftp`. They share the
#   options of the other ssh commands (`-p`, `-i`, `-J`, `-F`, `-o` ...) and are
#   run by the engine in lib/ssh_cmd.sh.
#
#   Things worth knowing:
#
#   * A remote location is `[user@]host:path`, written exactly as scp and rsync
#     write it. The host is checked like any ssh target; IPv6 literals do not fit
#     that form, use an alias of `~/.ssh/config`.
#   * A local path such as `backup:2024.tgz` would be read by scp as "file 2024.tgz
#     on host backup"; it is passed as `./backup:2024.tgz`.
#   * Local sources must exist (unless this is a dry run). Several downloads need
#     an existing local directory as destination.
#   * rsync follows its own rule about a trailing `/` on the source: `src/` copies
#     the contents, `src` copies the directory itself.
#   * `--delete` removes files at the destination (the server for `push`, **your
#     machine** for `pull`). Try it first with `--simulate`, or with `-n`.
#   * Recent scp (OpenSSH 9) talks the sftp protocol and needs no quoting for a
#     remote path with spaces; older scp passes it to a remote shell.
#   * `rsync::push` and `rsync::pull` are the short form. Local copies, mirrors with
#     guard rails, resumable transfers, `--bwlimit`, `--chmod` and the rest of the rsync
#     cheat sheets are in lib/rsync.sh (`shell::rsync::*`).

# @description Copy local files or directories to a server (`scp file user@host:/path`).
#   The last argument is the destination, as `[user@]host:path`. Use `-r` for a
#   directory.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -r | --recursive Copy directories recursively.
# @option -p | --port <n> Server port (scp -P).
# @option -i | --identity <file> Private key.
# @arg $@ string One or more local paths, then the remote destination.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, missing arguments, or an unsafe argument.
# @exitcode 3 scp, or a local source, is missing.
# @exitcode N Exit status of scp.
# @see shell::ssh::cmd
# @see shell::ssh::rsync::push
# @example
#   shell::ssh::scp::upload notes.txt deploy@web1:/home/deploy/
#   shell::ssh::scp::upload -r -p 2222 ./site deploy@web1:/var/www
#
shell::ssh::scp::upload() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Copy local files or directories to a server (scp)"
		shell::logger::usage "shell::ssh::scp::upload [-n] [options] <local>... <[user@]host:path>"
		shell::logger::item "local" "One or more local files or directories"
		shell::logger::item "destination" "Remote location, written [user@]host:path"
		shell::ssh::cmd::help scp
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::scp::upload notes.txt deploy@web1:/home/deploy/"
		shell::logger::example "shell::ssh::scp::upload -r -p 2222 ./site deploy@web1:/var/www"
		return "$RETURN_SUCCESS"
	fi
	shell::ssh::cmd scp upload "$@"
}

# @description Copy files or directories from a server to this machine (`scp user@host:/path dest/`).
#   The last argument is the local destination; the others are remote locations
#   written `[user@]host:path`. Use `-r` for a directory. With several sources
#   the destination must be an existing directory.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -r | --recursive Copy directories recursively.
# @option -p | --port <n> Server port (scp -P).
# @option -i | --identity <file> Private key.
# @arg $@ string One or more remote locations, then the local destination.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, missing arguments, or an unsafe argument.
# @exitcode 3 scp is missing.
# @exitcode N Exit status of scp.
# @see shell::ssh::cmd
# @see shell::ssh::rsync::pull
# @example
#   shell::ssh::scp::download deploy@web1:/var/log/app.log .
#   shell::ssh::scp::download -r deploy@web1:/etc/nginx ./backup/
#
shell::ssh::scp::download() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Copy files or directories from a server to this machine (scp)"
		shell::logger::usage "shell::ssh::scp::download [-n] [options] <[user@]host:path>... <local>"
		shell::logger::item "source" "One or more remote locations, written [user@]host:path"
		shell::logger::item "local" "Local destination (an existing directory when there are several sources)"
		shell::ssh::cmd::help scp
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::scp::download deploy@web1:/var/log/app.log ."
		shell::logger::example "shell::ssh::scp::download -r deploy@web1:/etc/nginx ./backup/"
		return "$RETURN_SUCCESS"
	fi
	shell::ssh::cmd scp download "$@"
}

# @description Sync local files to a server (`rsync -avz -e ssh src user@host:dst`).
#   Only what changed is sent, compressed. Mind the trailing `/` of the source
#   (see the file description) and `--delete`, which removes files on the server.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --delete Delete files on the server that are not here.
# @option --exclude <pattern> Skip matching files (repeatable).
# @option --simulate Let rsync show what it would do, changing nothing.
# @arg $@ string One or more local paths, then the remote destination.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, missing arguments, or an unsafe argument.
# @exitcode 3 rsync, ssh, or a local source, is missing.
# @exitcode N Exit status of rsync.
# @see shell::ssh::cmd
# @see shell::ssh::rsync::pull
# @see shell::rsync::sync
# @example
#   shell::ssh::rsync::push ./site/ deploy@web1:/var/www/site/
#   shell::ssh::rsync::push --delete --simulate --exclude .git ./site/ deploy@web1:/var/www/site/
#
shell::ssh::rsync::push() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Sync local files to a server (rsync -avz over ssh)"
		shell::logger::usage "shell::ssh::rsync::push [-n] [options] <local>... <[user@]host:path>"
		shell::logger::item "local" "One or more local files or directories (a trailing / copies the contents)"
		shell::logger::item "destination" "Remote location, written [user@]host:path"
		shell::ssh::cmd::help rsync
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::rsync::push ./site/ deploy@web1:/var/www/site/"
		shell::logger::example "shell::ssh::rsync::push --delete --simulate ./site/ deploy@web1:/var/www/site/"
		return "$RETURN_SUCCESS"
	fi
	shell::ssh::cmd rsync push "$@"
}

# @description Sync files from a server to this machine (`rsync -avz -e ssh user@host:src dst`).
#   Only what changed is fetched, compressed. `--delete` removes files **on this
#   machine** that the server does not have: try it with `--simulate` first.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --delete Delete local files that are not on the server.
# @option --exclude <pattern> Skip matching files (repeatable).
# @option --simulate Let rsync show what it would do, changing nothing.
# @arg $@ string One or more remote locations, then the local destination.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, missing arguments, or an unsafe argument.
# @exitcode 3 rsync or ssh is missing.
# @exitcode N Exit status of rsync.
# @see shell::ssh::cmd
# @see shell::ssh::rsync::push
# @see shell::rsync::sync
# @example
#   shell::ssh::rsync::pull deploy@web1:/var/www/site/ ./site/
#   shell::ssh::rsync::pull --progress -p 2222 deploy@web1:/var/backups/ ./backups/
#
shell::ssh::rsync::pull() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Sync files from a server to this machine (rsync -avz over ssh)"
		shell::logger::usage "shell::ssh::rsync::pull [-n] [options] <[user@]host:path>... <local>"
		shell::logger::item "source" "One or more remote locations (a trailing / copies the contents)"
		shell::logger::item "local" "Local destination"
		shell::ssh::cmd::help rsync
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::rsync::pull deploy@web1:/var/www/site/ ./site/"
		shell::logger::example "shell::ssh::rsync::pull --progress -p 2222 deploy@web1:/var/backups/ ./backups/"
		return "$RETURN_SUCCESS"
	fi
	shell::ssh::cmd rsync pull "$@"
}

# @description Open an interactive SFTP session (`sftp [user@]host`).
#   Inside the session `get` and `put` move files, `ls cd pwd` browse the server
#   and `lls lcd lpwd` this machine.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option -p | --port <n> Server port (sftp -P).
# @option -i | --identity <file> Private key.
# @arg $1 string The target.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, no target, or an unsafe argument.
# @exitcode 3 sftp is missing.
# @exitcode N Exit status of sftp.
# @see shell::ssh::cmd
# @example
#   shell::ssh::sftp::connect deploy@web1
#   shell::ssh::sftp::connect -p 2222 deploy@web1
#
shell::ssh::sftp::connect() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Open an interactive SFTP session (sftp)"
		shell::logger::usage "shell::ssh::sftp::connect [-n] [options] <[user@]host|alias>"
		shell::logger::item "target" "user@host, host, or a Host alias of ~/.ssh/config"
		shell::ssh::cmd::help sftp
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::sftp::connect deploy@web1"
		shell::logger::example "shell::ssh::sftp::connect -p 2222 deploy@web1"
		return "$RETURN_SUCCESS"
	fi
	shell::ssh::cmd sftp target "$@"
}
