#!/usr/bin/env bash
# @file security/security_finding.sh
# @brief The finding model: one record format, one store, shared by every security module.
# @description
#   A finding is one observation with a severity, a confidence and the evidence behind it. An
#   indicator is not proof: every detection states why it fired and what would confirm it.
#
#   Fields (stored in this order, joined by SHELL_SECURITY_SEP, one finding per line):
#     id  category  severity  description  resource  detected_at  source  rationale
#     confidence  investigate  remediate
#
#   The store is a private (mode 600) temporary file, so detections running in a pipeline (a
#   subshell) still reach it. The function that starts a session owns it, renders it and removes
#   it; a function called by another one (the investigate workflow) only appends. No `trap` is
#   used: cleanup happens in `_shell::security::session::finish`.
#
#   Text is sanitised before it is stored: control characters become spaces and secrets
#   (passwords, tokens, URL credentials) are masked, so no report can leak them.

# @description Build the case-insensitive secret-word pattern once and print it.
#   BSD sed has no `I` flag, so each letter becomes a `[aA]` bracket.
# @internal
# @stdout An ERE alternation such as `[pP][aA][sS]...|[tT]...`.
# @exitcode 0 Always.
# @example
#   _shell::security::redact_re
#
_shell::security::redact_re() {
	if [ -z "${_SHELL_SECURITY_REDACT_RE-}" ]; then
		_SHELL_SECURITY_REDACT_RE="$(printf '%s\n' "$SHELL_SECURITY_SECRET_WORDS" | tr ' ' '\n' | awk 'NF {
			out = ""
			for (i = 1; i <= length($0); i++) {
				c = substr($0, i, 1); u = toupper(c); l = tolower(c)
				out = out ((u != l) ? "[" l u "]" : c)
			}
			print out }' | tr '\n' '|' | sed 's/|$//')"
	fi
	printf '%s' "$_SHELL_SECURITY_REDACT_RE"
}

# @description Make text safe to store and print: one line, no control characters, no secrets.
#   Masks `word=value`, `word: value`, `--word value` for the words in SHELL_SECURITY_SECRET_WORDS
#   and the password of `scheme://user:password@host`.
# @internal
# @arg $1 string Text.
# @stdout The sanitised text.
# @exitcode 0 Always.
# @example
#   _shell::security::sanitize "curl --token abc https://u:p@h/"
#
_shell::security::sanitize() {
	local re
	re="$(_shell::security::redact_re)"
	printf '%s' "${1-}" | tr '\n\r\t\037' '    ' | LC_ALL=C tr -d '\000-\010\013\014\016-\036\177' |
		sed -E \
			-e 's#([Bb][Ee][Aa][Rr][Ee][Rr]|[Bb][Aa][Ss][Ii][Cc]) +[A-Za-z0-9._~+/=-]+#\1 [REDACTED]#g' \
			-e "s#(://[^:/@ ]+):[^@/ ]+@#\\1:[REDACTED]@#g" \
			-e "s#(${re})([A-Za-z0-9_-]*)([=: ]+)(\"[^\"]*\"|'[^']*'|[^ ]+)#\\1\\2\\3[REDACTED]#g" \
			-e 's/^ +//; s/ +$//'
}

# @description Numeric rank of a severity (CRITICAL 4 ... INFO 0).
# @internal
# @arg $1 string Severity.
# @stdout The rank.
# @exitcode 0 Known severity.
# @exitcode 2 Unknown severity.
# @example
#   _shell::security::severity::rank HIGH
#
_shell::security::severity::rank() {
	case "${1-}" in
	CRITICAL) printf '4\n' ;;
	HIGH) printf '3\n' ;;
	MEDIUM) printf '2\n' ;;
	LOW) printf '1\n' ;;
	INFO) printf '0\n' ;;
	*) return "$RETURN_INVALID" ;;
	esac
}

# @description Parse the options every reporting function shares.
#   Sets _SHELL_SECURITY_FORMAT and _SHELL_SECURITY_MIN_SEVERITY. A function with extra options
#   strips them before calling this one.
# @internal
# @option -f | --format Output format: text, json, markdown or csv.
# @option --min-severity Lowest severity to print: INFO, LOW, MEDIUM, HIGH or CRITICAL.
# @exitcode 0 Success.
# @exitcode 2 Unknown option, format or severity.
# @example
#   _shell::security::args::parse --format json
#
_shell::security::args::parse() {
	_SHELL_SECURITY_FORMAT="$SHELL_SECURITY_DEFAULT_FORMAT"
	_SHELL_SECURITY_MIN_SEVERITY="INFO"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-f | --format)
			[ "$#" -ge 2 ] || {
				shell::logger::error "$1 needs a value"
				return "$RETURN_INVALID"
			}
			_SHELL_SECURITY_FORMAT="$2"
			shift 2
			;;
		--min-severity)
			[ "$#" -ge 2 ] || {
				shell::logger::error "$1 needs a value"
				return "$RETURN_INVALID"
			}
			_SHELL_SECURITY_MIN_SEVERITY="$2"
			shift 2
			;;
		*)
			shell::logger::error "Unknown argument: $1"
			return "$RETURN_INVALID"
			;;
		esac
	done
	case " $SHELL_SECURITY_FORMATS " in
	*" $_SHELL_SECURITY_FORMAT "*) ;;
	*)
		shell::logger::error "Unknown format: $_SHELL_SECURITY_FORMAT (use: $SHELL_SECURITY_FORMATS)"
		return "$RETURN_INVALID"
		;;
	esac
	_shell::security::severity::rank "$_SHELL_SECURITY_MIN_SEVERITY" >/dev/null || {
		shell::logger::error "Unknown severity: $_SHELL_SECURITY_MIN_SEVERITY (use: $SHELL_SECURITY_SEVERITIES)"
		return "$RETURN_INVALID"
	}
	return "$RETURN_SUCCESS"
}

# @description Open a finding session.
#   Creates the private store unless an enclosing function already opened one. Sets
#   _SHELL_SECURITY_OWNS to 1 when this call created it, 0 when it joined an existing one; the
#   caller passes that value to `finish`.
# @internal
# @exitcode 0 Success.
# @exitcode 1 The store could not be created.
# @example
#   _shell::security::session::begin; owns="$_SHELL_SECURITY_OWNS"
#
_shell::security::session::begin() {
	if [ -n "${_SHELL_SECURITY_STORE-}" ] && [ -f "$_SHELL_SECURITY_STORE" ]; then
		_SHELL_SECURITY_OWNS=0
		return "$RETURN_SUCCESS"
	fi
	local store old_umask
	old_umask="$(umask)"
	umask 077
	store="$(mktemp "$(shell::os::temp_dir)/shell-security.XXXXXX")"
	local rc=$?
	umask "$old_umask"
	if [ "$rc" -ne 0 ] || [ -z "$store" ]; then
		shell::logger::error "Cannot create the findings store"
		return "$RETURN_FAILURE"
	fi
	_SHELL_SECURITY_STORE="$store"
	_SHELL_SECURITY_OWNS=1
	return "$RETURN_SUCCESS"
}

# @description Close a finding session: render and delete the store when this call owns it.
# @internal
# @arg $1 integer 1 when the caller created the session (see `begin`), 0 otherwise.
# @arg $2 string Output format.
# @arg $3 string Minimum severity.
# @stdout The rendered report (only when the caller owns the session).
# @exitcode 0 Success.
# @example
#   _shell::security::session::finish "$owns" text INFO
#
_shell::security::session::finish() {
	[ "${1-0}" = "1" ] || return "$RETURN_SUCCESS"
	local rc=0
	_shell::security::render::findings "${2:-text}" "${3:-INFO}" || rc=$?
	rm -f "$_SHELL_SECURITY_STORE"
	_SHELL_SECURITY_STORE=""
	return "$rc"
}

# @description Record one finding in the current session.
#   A finding with the same id (same category, resource and description) is stored once, so
#   modules that see the same thing do not duplicate it. All text is sanitised.
# @internal
# @arg $1 string Category (process, network, host ...).
# @arg $2 string Severity: CRITICAL, HIGH, MEDIUM, LOW or INFO.
# @arg $3 string Affected resource (a pid, a path, a port).
# @arg $4 string Description.
# @arg $5 string Evidence source (the command or file the observation came from).
# @arg $6 string Detection rationale: why this fired, and what legitimate causes exist.
# @arg $7 string Confidence: high, medium or low.
# @arg $8 string Recommended investigation steps.
# @arg $9 string Recommended remediation.
# @exitcode 0 Recorded, or already present.
# @exitcode 2 Invalid severity or confidence, or no open session.
# @example
#   _shell::security::finding::add process MEDIUM "pid 42" "Runs from /tmp" "ps" "why" medium "check" "fix"
#
_shell::security::finding::add() {
	local category="${1-}" severity="${2-}" confidence="${7-}"
	_shell::security::severity::rank "$severity" >/dev/null || {
		shell::logger::error "finding: invalid severity '$severity'"
		return "$RETURN_INVALID"
	}
	case "$confidence" in high | medium | low) ;; *)
		shell::logger::error "finding: invalid confidence '$confidence'"
		return "$RETURN_INVALID"
		;;
	esac
	if [ -z "$category" ] || [ -z "${_SHELL_SECURITY_STORE-}" ] || [ ! -f "$_SHELL_SECURITY_STORE" ]; then
		shell::logger::error "finding: no open session"
		return "$RETURN_INVALID"
	fi

	local resource description source rationale investigate remediate
	resource="$(_shell::security::sanitize "${3-}")"
	description="$(_shell::security::sanitize "${4-}")"
	source="$(_shell::security::sanitize "${5-}")"
	rationale="$(_shell::security::sanitize "${6-}")"
	investigate="$(_shell::security::sanitize "${8-}")"
	remediate="$(_shell::security::sanitize "${9-}")"

	local digest id
	digest="$(printf '%s|%s|%s' "$category" "$resource" "$description" | _shell::security::sha256)" || digest="$(printf '%s|%s|%s' "$category" "$resource" "$description" | cksum | awk '{print $1}')"
	id="FND-$(printf '%s' "$category" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9\n' '-')-$(printf '%s' "$digest" | cut -c1-8)"

	# Same id already stored: nothing to add.
	if grep -qF -- "$id$SHELL_SECURITY_SEP" "$_SHELL_SECURITY_STORE" 2>/dev/null; then
		return "$RETURN_SUCCESS"
	fi

	local s="$SHELL_SECURITY_SEP"
	printf '%s\n' "$id$s$category$s$severity$s$description$s$resource$s$(_shell::security::now)$s$source$s$rationale$s$confidence$s$investigate$s$remediate" >>"$_SHELL_SECURITY_STORE"
}

# @description Record an INFO finding that a capability is unavailable.
#   Keeps "could not look" distinct from "looked and found nothing".
# @internal
# @arg $1 string Category.
# @arg $2 string What could not be inspected.
# @arg $3 string Why (missing tool, missing permission).
# @exitcode 0 Recorded.
# @example
#   _shell::security::finding::unavailable network "listening sockets" "neither ss nor lsof is installed"
#
_shell::security::finding::unavailable() {
	_shell::security::finding::add "${1-}" INFO "${2-}" "Not inspected: ${2-}" "capability check" \
		"${3-}. The result is unknown, not clean." high \
		"Install the missing tool or rerun with the required privileges, then repeat the check." \
		"None needed."
}
