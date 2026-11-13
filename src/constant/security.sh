#!/usr/bin/env bash
# @file constant/security.sh
# @brief Defaults and fixed strings of the security investigation modules (src/shield/security_*.sh).
# @description
#   Every path, threshold and detection list used by `shell::security::*` is a constant here, so a
#   test (or a container with a relocated /proc) can point it elsewhere before sourcing the library.
#   Detection lists are deliberately short and conservative: a rule that fires on ordinary
#   software is worse than a missing rule.

# Separates the fields of an internal record. A control character that is not whitespace, so
# `read` keeps empty fields and a value may contain spaces.
SHELL_SECURITY_SEP=$'\037'

# Severity model, most severe first. Every finding carries exactly one of these.
SHELL_SECURITY_SEVERITIES="CRITICAL HIGH MEDIUM LOW INFO"

# Output formats understood by every reporting function.
SHELL_SECURITY_FORMATS="text json markdown csv"

# Default output format (override per call with --format).
: "${SHELL_SECURITY_DEFAULT_FORMAT:=text}"

# Linux process pseudo-filesystem; only read.
: "${SHELL_SECURITY_PROC_DIR:=/proc}"

# Account databases; only read.
: "${SHELL_SECURITY_PASSWD_FILE:=/etc/passwd}"
: "${SHELL_SECURITY_GROUP_FILE:=/etc/group}"
: "${SHELL_SECURITY_RESOLV_CONF:=/etc/resolv.conf}"

# Groups whose members can become root (Linux: sudo, admin, wheel; macOS: admin).
: "${SHELL_SECURITY_ADMIN_GROUPS:=sudo admin wheel}"

# Directories that ordinary software does not install long-running programs into.
# A program running from here is worth a look, not proof of anything.
: "${SHELL_SECURITY_TMP_DIRS:=/tmp /var/tmp /dev/shm /private/tmp /private/var/tmp}"

# A process at or above this CPU percentage is reported (LOW, informational about load only).
: "${SHELL_SECURITY_CPU_THRESHOLD:=90}"

# Parent programs that normally never start an interactive shell (base names, space separated).
: "${SHELL_SECURITY_SERVER_PARENTS:=nginx httpd apache2 php-fpm php-fpm8 mysqld postgres redis-server mongod memcached}"

# Base names of shells.
: "${SHELL_SECURITY_SHELLS:=sh bash zsh dash ksh fish}"

# Extended regular expressions matched against a process command line (case-sensitive).
# Each entry is `name|severity|confidence|regex`; one per line.
: "${SHELL_SECURITY_CMD_RULES:=reverse-shell|HIGH|medium|(bash|sh|zsh|dash) +-i .*(/dev/tcp/|/dev/udp/|>&)|(^| )(nc|ncat|netcat) .*( -e | --exec |-c +(ba)?sh)|mkfifo .*(nc|ncat)
miner|HIGH|medium|stratum\+(tcp|ssl)://|(^|/)(xmrig|minerd|cpuminer)( |$)
encoded-exec|MEDIUM|medium|base64 +(-d|-D|--decode).*\| *(sudo +)?(ba|z|da)?sh( |$)
download-exec|MEDIUM|low|(curl|wget) [^|]*\| *(sudo +)?(ba|z|da)?sh( |$)}"

# Words whose value is masked in every finding and report (case-insensitive, space separated).
: "${SHELL_SECURITY_SECRET_WORDS:=password passwd secret token apikey api_key api-key access_key accesskey credential authorization bearer private_key}"

# Listening ports that are risky when bound to a non-loopback address.
# `port:service:severity`, space separated. The service is inferred from the port only.
: "${SHELL_SECURITY_EXPOSED_PORTS:=23:telnet:HIGH 2375:docker-api-unencrypted:HIGH 21:ftp:MEDIUM 3389:rdp:MEDIUM 5900:vnc:MEDIUM 6379:redis:MEDIUM 11211:memcached:MEDIUM 27017:mongodb:MEDIUM 9200:elasticsearch:MEDIUM 5984:couchdb:MEDIUM 3306:mysql:LOW 5432:postgresql:LOW 445:smb:LOW}"

# Remote ports often used by remote-access tools and miners. A match is a prompt to look, not a verdict.
: "${SHELL_SECURITY_SUSPECT_REMOTE_PORTS:=4444 1337 31337 6667 3333 14444}"
