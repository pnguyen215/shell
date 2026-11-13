#!/usr/bin/env bash
# @file shield/security_render.sh
# @brief Renderers for findings and key/value tables: text, JSON, Markdown and CSV.
# @description
#   One renderer per format, dependency-free (no jq needed). Data goes to stdout; the logger keeps
#   writing diagnostics to stderr, so `shell::security::... --format json > out.json` stays clean.
#   Markdown is built with the existing `shell::markdown::*` module (no second escaper). CSV cells
#   that start with `= + - @` get a leading apostrophe so a spreadsheet cannot run them as a
#   formula. JSON strings escape backslash, quote and control characters.

# @description Print a value as a JSON string literal, including the quotes.
# @internal
# @arg $1 string Value.
# @stdout The quoted and escaped string.
# @exitcode 0 Always.
# @example
#   _shell::security::json::string 'say "hi"'   # "say \"hi\""
#
_shell::security::json::string() {
	printf '"%s"' "$(printf '%s' "${1-}" | LC_ALL=C tr -d '\000-\010\013\014\016-\037\177' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/$(printf '\t')/\\\\t/g")"
}

# @description Print a value as a quoted CSV cell (RFC 4180) that spreadsheets will not execute.
# @internal
# @arg $1 string Value.
# @stdout The cell.
# @exitcode 0 Always.
# @example
#   _shell::security::csv::cell '=1+1'   # "'=1+1"
#
_shell::security::csv::cell() {
	local value="${1-}"
	case "$value" in
	'='* | '+'* | '-'* | '@'*) value="'$value" ;;
	esac
	printf '"%s"' "$(printf '%s' "$value" | sed 's/"/""/g')"
}

# @description Render `key SEP value` records read from standard input.
# @internal
# @arg $1 string Format: text, json, markdown or csv.
# @arg $2 string Heading of the key column.
# @arg $3 string Heading of the value column.
# @arg $4 string Field separator of the input records.
# @stdout The table.
# @exitcode 0 Success.
# @exitcode 2 Unknown format.
# @example
#   printf 'os\037linux\n' | _shell::security::render::kv json key value "$(printf '\037')"
#
_shell::security::render::kv() {
	local format="${1-text}" kh="${2-key}" vh="${3-value}" sep="${4-$SHELL_SECURITY_SEP}"
	local data
	data="$(cat)"
	case "$format" in
	text)
		[ -n "$data" ] || return "$RETURN_SUCCESS"
		printf '%s\n' "$data" | awk -F"$sep" '{k[NR]=$1; v[NR]=$2; if (length($1) > w) w = length($1)}
			END {for (i = 1; i <= NR; i++) printf "%-" w "s  %s\n", k[i], v[i]}'
		;;
	json)
		local first=1 key value
		printf '{'
		while IFS="$sep" read -r key value; do
			[ -n "$key" ] || continue
			[ "$first" = 1 ] || printf ','
			first=0
			printf '%s:%s' "$(_shell::security::json::string "$key")" "$(_shell::security::json::string "$value")"
		done <<EOF
$data
EOF
		printf '}\n'
		;;
	csv)
		printf '%s,%s\n' "$(_shell::security::csv::cell "$kh")" "$(_shell::security::csv::cell "$vh")"
		local k v
		while IFS="$sep" read -r k v; do
			[ -n "$k" ] || continue
			printf '%s,%s\n' "$(_shell::security::csv::cell "$k")" "$(_shell::security::csv::cell "$v")"
		done <<EOF
$data
EOF
		;;
	markdown)
		local mk mv
		shell::markdown::init -f markdown || return "$?"
		shell::markdown::table_header "$kh" "$vh"
		while IFS="$sep" read -r mk mv; do
			[ -n "$mk" ] || continue
			shell::markdown::table_row "$mk" "$mv"
		done <<EOF
$data
EOF
		shell::markdown::table
		shell::markdown::render
		;;
	*)
		shell::logger::error "Unknown format: $format"
		return "$RETURN_INVALID"
		;;
	esac
}

# @description Print the stored findings of the current session, most severe first.
#   Findings below the minimum severity are left out of the list and of the summary counts. An
#   empty result says so explicitly and points at the "not inspected" entries, because a check
#   that could not run is not a clean result.
# @internal
# @arg $1 string Format: text, json, markdown or csv.
# @arg $2 string Minimum severity (default INFO).
# @stdout The report.
# @exitcode 0 Success.
# @exitcode 2 Unknown format or severity.
# @example
#   _shell::security::render::findings json MEDIUM
#
_shell::security::render::findings() {
	local format="${1-text}" min="${2-INFO}" s="$SHELL_SECURITY_SEP"
	local min_rank
	min_rank="$(_shell::security::severity::rank "$min")" || return "$RETURN_INVALID"
	case " $SHELL_SECURITY_FORMATS " in *" $format "*) ;; *) return "$RETURN_INVALID" ;; esac

	local data
	data="$(awk -F"$s" -v s="$s" -v min="$min_rank" '
		BEGIN { r["CRITICAL"] = 4; r["HIGH"] = 3; r["MEDIUM"] = 2; r["LOW"] = 1; r["INFO"] = 0 }
		r[$3] >= min { print (4 - r[$3]) s $0 }' "$_SHELL_SECURITY_STORE" | sort | cut -d"$s" -f2-)"

	local host generated n_crit n_high n_med n_low n_info total
	host="$(hostname 2>/dev/null)"
	generated="$(_shell::security::now)"
	_shell::security::render::counts "$data"
	n_crit="$_SHELL_SECURITY_N_CRITICAL"
	n_high="$_SHELL_SECURITY_N_HIGH"
	n_med="$_SHELL_SECURITY_N_MEDIUM"
	n_low="$_SHELL_SECURITY_N_LOW"
	n_info="$_SHELL_SECURITY_N_INFO"
	total=$((n_crit + n_high + n_med + n_low + n_info))

	local id category severity description resource detected source rationale confidence investigate remediate
	case "$format" in
	json)
		printf '{"schema":"shell-security-findings/1","generated_at":%s,"host":%s,' "$(_shell::security::json::string "$generated")" "$(_shell::security::json::string "$host")"
		printf '"summary":{"CRITICAL":%s,"HIGH":%s,"MEDIUM":%s,"LOW":%s,"INFO":%s,"total":%s},"findings":[' "$n_crit" "$n_high" "$n_med" "$n_low" "$n_info" "$total"
		local first=1
		while IFS="$s" read -r id category severity description resource detected source rationale confidence investigate remediate; do
			[ -n "$id" ] || continue
			[ "$first" = 1 ] || printf ','
			first=0
			printf '{"id":%s,"category":%s,"severity":%s,"description":%s,"resource":%s,"detected_at":%s,"evidence_source":%s,"rationale":%s,"confidence":%s,"investigate":%s,"remediate":%s}' \
				"$(_shell::security::json::string "$id")" "$(_shell::security::json::string "$category")" "$(_shell::security::json::string "$severity")" \
				"$(_shell::security::json::string "$description")" "$(_shell::security::json::string "$resource")" "$(_shell::security::json::string "$detected")" \
				"$(_shell::security::json::string "$source")" "$(_shell::security::json::string "$rationale")" "$(_shell::security::json::string "$confidence")" \
				"$(_shell::security::json::string "$investigate")" "$(_shell::security::json::string "$remediate")"
		done <<EOF
$data
EOF
		printf ']}\n'
		;;
	csv)
		printf 'id,category,severity,description,resource,detected_at,evidence_source,rationale,confidence,investigate,remediate\n'
		while IFS="$s" read -r id category severity description resource detected source rationale confidence investigate remediate; do
			[ -n "$id" ] || continue
			printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
				"$(_shell::security::csv::cell "$id")" "$(_shell::security::csv::cell "$category")" "$(_shell::security::csv::cell "$severity")" \
				"$(_shell::security::csv::cell "$description")" "$(_shell::security::csv::cell "$resource")" "$(_shell::security::csv::cell "$detected")" \
				"$(_shell::security::csv::cell "$source")" "$(_shell::security::csv::cell "$rationale")" "$(_shell::security::csv::cell "$confidence")" \
				"$(_shell::security::csv::cell "$investigate")" "$(_shell::security::csv::cell "$remediate")"
		done <<EOF
$data
EOF
		;;
	markdown)
		shell::markdown::init -f markdown || return "$?"
		shell::markdown::heading 1 "Security findings"
		shell::markdown::paragraph "Host: $host. Generated: $generated."
		shell::markdown::paragraph "Summary: CRITICAL $n_crit, HIGH $n_high, MEDIUM $n_med, LOW $n_low, INFO $n_info ($total total). A finding is an indicator to validate, not proof of compromise."
		if [ "$total" -gt 0 ]; then
			shell::markdown::table_header "ID" "Severity" "Confidence" "Category" "Resource" "Description"
			while IFS="$s" read -r id category severity description resource detected source rationale confidence investigate remediate; do
				[ -n "$id" ] || continue
				shell::markdown::table_row "$id" "$severity" "$confidence" "$category" "$resource" "$description"
			done <<EOF
$data
EOF
			shell::markdown::table
			while IFS="$s" read -r id category severity description resource detected source rationale confidence investigate remediate; do
				[ -n "$id" ] || continue
				shell::markdown::heading 3 "$id ($severity)"
				shell::markdown::list_item "Detected: $detected"
				shell::markdown::list_item "Evidence source: $source"
				shell::markdown::list_item "Rationale: $rationale"
				shell::markdown::list_item "Investigate: $investigate"
				shell::markdown::list_item "Remediate: $remediate"
			done <<EOF
$data
EOF
		else
			shell::markdown::paragraph "No findings. Check for 'Not inspected' entries: a check that could not run is not a clean result."
		fi
		shell::markdown::render
		;;
	*)
		local c_on="" c_off="" c_sev=""
		if [ -t 1 ] && [ -z "${NO_COLOR-}" ]; then c_off=$'\033[0m'; fi
		printf 'Security findings - host %s - %s\n' "$host" "$generated"
		printf 'Summary: CRITICAL %s | HIGH %s | MEDIUM %s | LOW %s | INFO %s (%s total)\n' "$n_crit" "$n_high" "$n_med" "$n_low" "$n_info" "$total"
		printf 'A finding is an indicator to validate, not proof of compromise.\n'
		if [ "$total" -eq 0 ]; then
			printf '\nNo findings. A check that could not run is listed as "Not inspected"; it is not a clean result.\n'
		fi
		while IFS="$s" read -r id category severity description resource detected source rationale confidence investigate remediate; do
			[ -n "$id" ] || continue
			c_on=""
			if [ -n "$c_off" ]; then
				case "$severity" in
				CRITICAL) c_on=$'\033[1;97;41m' ;;
				HIGH) c_on=$'\033[31m' ;;
				MEDIUM) c_on=$'\033[33m' ;;
				LOW) c_on=$'\033[36m' ;;
				*) c_on=$'\033[2m' ;;
				esac
			fi
			c_sev="${c_on}[${severity}]${c_off}"
			printf '\n%s %s  (confidence: %s)\n' "$c_sev" "$id" "$confidence"
			printf '  Category:    %s\n  Resource:    %s\n  Description: %s\n  Detected:    %s\n  Source:      %s\n  Rationale:   %s\n  Investigate: %s\n  Remediate:   %s\n' \
				"$category" "$resource" "$description" "$detected" "$source" "$rationale" "$investigate" "$remediate"
		done <<EOF
$data
EOF
		;;
	esac
}

# @description Count findings per severity in a record list; results go to _SHELL_SECURITY_N_*.
# @internal
# @arg $1 string Records, one finding per line (field 3 is the severity).
# @exitcode 0 Always.
# @example
#   _shell::security::render::counts "$records"
#
_shell::security::render::counts() {
	local sev line
	_SHELL_SECURITY_N_CRITICAL=0
	_SHELL_SECURITY_N_HIGH=0
	_SHELL_SECURITY_N_MEDIUM=0
	_SHELL_SECURITY_N_LOW=0
	_SHELL_SECURITY_N_INFO=0
	[ -n "${1-}" ] || return "$RETURN_SUCCESS"
	for sev in CRITICAL HIGH MEDIUM LOW INFO; do
		line="$(printf '%s\n' "$1" | awk -F"$SHELL_SECURITY_SEP" -v sev="$sev" '$3 == sev {n++} END {print n + 0}')"
		case "$sev" in
		CRITICAL) _SHELL_SECURITY_N_CRITICAL="$line" ;;
		HIGH) _SHELL_SECURITY_N_HIGH="$line" ;;
		MEDIUM) _SHELL_SECURITY_N_MEDIUM="$line" ;;
		LOW) _SHELL_SECURITY_N_LOW="$line" ;;
		INFO) _SHELL_SECURITY_N_INFO="$line" ;;
		esac
	done
}
