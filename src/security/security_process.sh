#!/usr/bin/env bash
# @file security/security_process.sh
# @brief Process inspection and suspicious-process detection (`shell::security::hunt::processes`).
# @description
#   Read-only. Every rule is evidence-based and states how ordinary software can trigger it: a
#   process is never called malicious, only worth validating. Linux reads the real executable path
#   from /proc when readable; macOS has no /proc, so the executable is the absolute path in the
#   command line when there is one, otherwise unknown.

# @description Test whether a path is inside one of SHELL_SECURITY_TMP_DIRS.
#   Reads the directory list cached in _SHELL_SECURITY_TMP_LIST by `_shell::security::tmp_prime`.
# @internal
# @arg $1 string Absolute path.
# @exitcode 0 The path is inside a temporary directory.
# @exitcode 1 It is not.
# @example
#   _shell::security::in_tmp /tmp/a.out
#
_shell::security::in_tmp() {
	local p="${1-}" d
	while IFS= read -r d; do
		[ -n "$d" ] || continue
		case "$p" in "$d"/*) return 0 ;; esac
	done <<<"${_SHELL_SECURITY_TMP_LIST-}"
	return 1
}

# @description Cache SHELL_SECURITY_TMP_DIRS as a newline-separated list (zsh does not word-split).
# @internal
# @exitcode 0 Always.
# @example
#   _shell::security::tmp_prime
#
_shell::security::tmp_prime() {
	_SHELL_SECURITY_TMP_LIST="$(printf '%s\n' "$SHELL_SECURITY_TMP_DIRS" | tr ' ' '\n')"
}

# @description Print one normalised record per process.
#   Fields (joined by SHELL_SECURITY_SEP): pid, ppid, user, cpu, mem, elapsed, exe, command.
#   `exe` is the real path from /proc/<pid>/exe when readable (a deleted binary ends in
#   " (deleted)"), else the absolute first word of the command line, else empty.
# @internal
# @stdout The records.
# @exitcode 0 Success.
# @exitcode 3 `ps` is not installed.
# @example
#   _shell::security::process::list
#
_shell::security::process::list() {
	_shell::security::have ps || return "$RETURN_NOT_FOUND"
	local s="$SHELL_SECURITY_SEP" exe_map=""
	if [ -d "$SHELL_SECURITY_PROC_DIR" ]; then
		exe_map="$(find "$SHELL_SECURITY_PROC_DIR" -maxdepth 2 -name exe -type l -exec ls -ld {} + 2>/dev/null |
			sed -E "s#^.*/([0-9]+)/exe -> (.*)\$#\\1${s}\\2#" | grep -F "$s")"
	fi
	ps -axo pid=,ppid=,user=,pcpu=,pmem=,etime=,command= 2>/dev/null | EXE_MAP="$exe_map" awk -v s="$s" '
		BEGIN {
			n = split(ENVIRON["EXE_MAP"], lines, "\n")
			for (i = 1; i <= n; i++) { split(lines[i], kv, s); exe[kv[1]] = kv[2] }
		}
		NF >= 6 {
			cmd = $0; sub(/^[ \t]+/, "", cmd)
			for (i = 1; i <= 6; i++) sub(/^[^ \t]+[ \t]+/, "", cmd)
			e = exe[$1]
			if (e == "" && substr(cmd, 1, 1) == "/") { split(cmd, a, " "); e = a[1] }
			print $1 s $2 s $3 s $4 s $5 s $6 s e s cmd
		}'
}

# @description Base name of the first word of a command line, without a login-shell dash.
# @internal
# @arg $1 string Command line.
# @stdout The program name.
# @exitcode 0 Always.
# @example
#   _shell::security::process::base "/usr/bin/php-fpm: master"
#
_shell::security::process::base() {
	local first="${1%% *}"
	first="${first##*/}"
	first="${first#-}"
	printf '%s' "${first%:}"
}

# @description Why a command-line rule fired, in one sentence that includes the benign causes.
# @internal
# @arg $1 string Rule name.
# @stdout The rationale.
# @exitcode 0 Always.
# @example
#   _shell::security::process::rule_rationale miner
#
_shell::security::process::rule_rationale() {
	case "${1-}" in
	reverse-shell) printf 'The command line has the shape of a reverse shell (an interactive shell wired to a network socket, or netcat with -e). Admin and CTF tooling can look the same.' ;;
	miner) printf 'The command line names a cryptocurrency miner or a mining-pool URL. An authorised miner or a file that merely has that name would match too.' ;;
	encoded-exec) printf 'The command line decodes base64 straight into a shell, a common way to hide a payload. Some installers do this too.' ;;
	download-exec) printf 'The command line pipes a download into a shell. Common in legitimate installers; risky when the source is not trusted. A long-running process like this is unusual.' ;;
	*) printf 'The command line matches a configured detection rule.' ;;
	esac
}

# @description Run the process checks and record their findings.
# @internal
# @exitcode 0 Success.
# @exitcode 3 `ps` is unavailable.
# @example
#   _shell::security::hunt::processes::scan
#
_shell::security::hunt::processes::scan() {
	local s="$SHELL_SECURITY_SEP" data
	if ! _shell::security::have ps; then
		_shell::security::finding::unavailable process "process listing" "'ps' is not installed"
		return "$RETURN_NOT_FOUND"
	fi
	data="$(_shell::security::process::list)"
	if [ -z "$data" ]; then
		_shell::security::finding::unavailable process "process listing" "'ps' returned no processes"
		return "$RETURN_SUCCESS"
	fi
	_shell::security::tmp_prime

	local total
	total="$(printf '%s\n' "$data" | grep -c .)"
	_shell::security::finding::add process INFO "process table" "Inspected $total processes" "ps -axo pid,ppid,user,pcpu,pmem,etime,command" \
		"Coverage note: every visible process was checked against the process rules. Processes of other users are only fully visible to a privileged user." high \
		"None needed." "None needed."

	local self="$$" pid ppid user cpu mem etime exe cmd path_exe deleted dir name base pbase pcmd ci
	printf '%s\n' "$data" | while IFS="$s" read -r pid ppid user cpu mem etime exe cmd; do
		[ -n "$pid" ] || continue
		[ "$pid" = "$self" ] && continue
		[ "$ppid" = "$self" ] && continue
		case "$cmd" in "["*"]") continue ;; esac

		deleted=0
		path_exe="$exe"
		case "$exe" in *" (deleted)")
			deleted=1
			path_exe="${exe% (deleted)}"
			;;
		esac
		name="$(_shell::security::process::base "${path_exe:-$cmd}")"

		# Executable inside a temporary directory.
		if [ -n "$path_exe" ] && _shell::security::in_tmp "$path_exe"; then
			local sev="MEDIUM" extra=""
			case "$path_exe" in */.*)
				sev="HIGH"
				extra=" The file or a directory on its path is hidden (name starts with a dot)."
				;;
			esac
			if [ "$deleted" = 1 ]; then
				sev="HIGH"
				extra="$extra The binary was deleted from disk while still running."
			fi
			_shell::security::finding::add process "$sev" "pid $pid ($path_exe)" \
				"Process '$name' (pid $pid, user $user) runs from a temporary directory" "ps; ${SHELL_SECURITY_PROC_DIR}/<pid>/exe" \
				"Programs started from a temporary directory are a common malware pattern.$extra Build tools, installers and test runners also run from there, so this needs validating." medium \
				"Identify the parent (ppid $ppid) and start time ($etime ago); compare the file hash with a known-good source; check what files and sockets it holds open." \
				"If it is not expected, preserve evidence first (copy the binary and command line), then stop the process and remove the file through your normal change process."
		elif [ "$deleted" = 1 ]; then
			_shell::security::finding::add process LOW "pid $pid ($path_exe)" \
				"Process '$name' (pid $pid) runs a binary that was deleted or replaced on disk" "${SHELL_SECURITY_PROC_DIR}/<pid>/exe" \
				"Usually a package upgrade replaced the file and the process was not restarted. Only suspicious if the path is unusual." medium \
				"Check recent package updates for this path; confirm the running version." \
				"Restart the service during a maintenance window so it runs the installed binary."
		fi

		# A shell started by a server program.
		base="$(_shell::security::process::base "$cmd")"
		case " $SHELL_SECURITY_SHELLS " in *" $base "*)
			pcmd="$(printf '%s\n' "$data" | awk -F"$s" -v p="$ppid" '$1 == p {print $8; exit}')"
			pbase="$(_shell::security::process::base "$pcmd")"
			case " $SHELL_SECURITY_SERVER_PARENTS " in *" $pbase "*)
				_shell::security::finding::add process MEDIUM "pid $pid (parent $pbase pid $ppid)" \
					"Shell '$base' (pid $pid, user $user) was started by server program '$pbase'" "ps (ppid column)" \
					"Servers such as web or database daemons rarely start shells, and attackers use that after exploiting them. Applications that shell out on purpose (hooks, cron-like jobs) also do it." low \
					"Read the shell's full command line and the server's logs around the start time ($etime ago); check whether the application is meant to run commands." \
					"If unexpected, restrict what the server account can execute and review the application for command injection."
				;;
			esac
			;;
		esac

		# High CPU (load only, no verdict).
		ci="${cpu%%[.,]*}"
		case "$ci" in '' | *[!0-9]*) ;; *)
			if [ "$ci" -ge "$SHELL_SECURITY_CPU_THRESHOLD" ]; then
				_shell::security::finding::add process INFO "pid $pid ($name)" \
					"Process '$name' (pid $pid, user $user) uses ${cpu}% CPU" "ps (pcpu column)" \
					"High CPU alone is a load observation, not a security signal; compiles, indexing and media work do this routinely." high \
					"Check what the process is working on and for how long ($etime)." "None unless the load is unexpected."
			fi
			;;
		esac
	done

	# Command-line rules: one awk pass over every command line.
	local rules hits rule_name rule_sev rule_conf hit_pid hit_user hit_cmd
	rules="$SHELL_SECURITY_CMD_RULES"
	hits="$(printf '%s\n' "$data" | RULES="$rules" awk -F"$s" -v s="$s" -v self="$self" '
		BEGIN {
			n = split(ENVIRON["RULES"], r, "\n")
			for (i = 1; i <= n; i++) {
				m = split(r[i], f, "|"); if (m < 4) continue
				nm[i] = f[1]; sv[i] = f[2]; cf[i] = f[3]; re = f[4]
				for (j = 5; j <= m; j++) re = re "|" f[j]
				rx[i] = re
			}
		}
		$1 == self || $2 == self { next }
		{ for (i = 1; i <= n; i++) if (rx[i] != "" && $8 ~ rx[i]) print $1 s nm[i] s sv[i] s cf[i] s $3 s $8 }')"
	if [ -n "$hits" ]; then
		printf '%s\n' "$hits" | while IFS="$s" read -r hit_pid rule_name rule_sev rule_conf hit_user hit_cmd; do
			[ -n "$hit_pid" ] || continue
			_shell::security::finding::add process "$rule_sev" "pid $hit_pid (user $hit_user)" \
				"Command line of pid $hit_pid matches the '$rule_name' pattern: ${hit_cmd:0:200}" "ps (command column)" \
				"$(_shell::security::process::rule_rationale "$rule_name")" "$rule_conf" \
				"Find the parent chain and start time; read the full command line and the files and sockets the process holds; check where the binary came from." \
				"If it is not expected, preserve evidence first, then stop the process and investigate how it was started."
		done
	fi
	return "$RETURN_SUCCESS"
}

# @description Hunt for suspicious processes and report evidence-based findings.
#   Checks: executables in temporary directories (hidden or deleted ones rank higher), deleted
#   binaries, shells started by server programs, command lines that look like reverse shells,
#   miners or download-and-execute, and very high CPU use. Read-only; needs no privileges, but
#   processes of other users are only fully visible to a privileged user. A finding is an
#   indicator to validate, never a verdict.
# @option -h | --help Show help and return.
# @option -f | --format Output format: text, json, markdown or csv (default: text).
# @option --min-severity Lowest severity to print (default: INFO).
# @stdout The findings.
# @exitcode 0 Success.
# @exitcode 2 Invalid argument.
# @exitcode 3 `ps` is not installed (reported as a "Not inspected" finding).
# @example
#   shell::security::hunt::processes --min-severity MEDIUM
#
shell::security::hunt::processes() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Hunt for suspicious processes (evidence-based; findings are indicators, not verdicts)"
		shell::logger::usage "shell::security::hunt::processes [-f text|json|markdown|csv] [--min-severity LEVEL]"
		shell::logger::option "-f, --format" "Output format (default: text)"
		shell::logger::option "--min-severity" "Lowest severity to print (default: INFO)"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::security::hunt::processes --min-severity MEDIUM"
		return "$RETURN_SUCCESS"
	fi
	_shell::security::args::parse "$@" || return "$?"
	local format="$_SHELL_SECURITY_FORMAT" min="$_SHELL_SECURITY_MIN_SEVERITY" rc=0
	_shell::security::session::begin || return "$?"
	local owns="$_SHELL_SECURITY_OWNS"

	_shell::security::hunt::processes::scan || rc=$?

	_shell::security::session::finish "$owns" "$format" "$min" || return "$?"
	return "$rc"
}
