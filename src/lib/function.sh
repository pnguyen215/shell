#!/usr/bin/env bash
# @file lib/function.sh
# @brief Discovery of the library's own functions: catalog, list, details and an interactive explorer.
# @description
#   One mechanism, three faces. Everything the user can ask about the `shell::` functions goes through
#   `_shell::function::catalog`, which scans the source tree once (data/function-catalog.awk) and
#   returns one record per function:
#
#       name  visibility  category  loaded  file  first-line  def-line  summary      (tab separated)
#
#   * shell::function::list     reads the catalog, filters it, prints it as text (works without a terminal);
#   * shell::function::info     renders one function's shdoc block (data/function-doc.awk);
#   * shell::function::explore  is the fzf front end over the same records, with a fallback to `list`.
#
#   There is no function list to maintain and no metadata format of its own: a function is "in the
#   catalog" when it is defined in `src/` (or loaded in the session), and its description is the shdoc
#   block that `make lint` already requires above it. A new function, with its block, appears on its own.
#   Visibility is the `_shell::` prefix; "loaded" is what the current shell reports (declare -F in bash,
#   typeset +f in zsh), so a function that is in the tree but not loaded is shown as such.
#   Design and extension points: docs/features/function-discovery.md and docs/development/architecture.md.

# @internal
# @description Names of the `shell::` / `_shell::` functions loaded in the current shell, one per line.
#   Other functions of the user's environment are never listed. Bash and zsh enumerate functions
#   differently, so this is the only place that asks the shell.
# @stdout The names.
# @exitcode 0 Always.
# @example
#   _shell::function::loaded
#
_shell::function::loaded() {
	if [ -n "${ZSH_VERSION-}" ]; then
		typeset +f 2>/dev/null
	else
		declare -F 2>/dev/null | sed 's/^declare -f //'
	fi | grep -E '^_?shell::'
}

# @internal
# @description Whether a function is loaded in the current shell.
# @arg $1 string Function name.
# @exitcode 0 It is loaded.
# @exitcode 1 It is not.
# @example
#   _shell::function::is_loaded shell::fs::browse && echo yes
#
_shell::function::is_loaded() {
	[ -n "${1-}" ] && typeset -f "$1" >/dev/null 2>&1
}

# @internal
# @description The catalog: every `shell::` and `_shell::` function, one tab-separated record each.
#   Fields: name, visibility (public | internal), category, loaded (yes | no), file (relative to the
#   library root, `-` for a function that is loaded but not in the tree), first line of its
#   documentation block, line of the definition, summary (first line of its description). Sorted by name.
#   This is the single source every discovery interface reads.
# @stdout The records.
# @exitcode 0 Always (empty when the source tree cannot be read and nothing is loaded).
# @example
#   _shell::function::catalog | cut -f1,8
#
_shell::function::catalog() {
	local loaded tab
	tab="$(printf '\t')"
	loaded="$(_shell::function::loaded)"
	find "$SHELL_SRC_DIR" -name '*.sh' 2>/dev/null | LC_ALL=C sort |
		SHELL_FN_LOADED="$loaded" awk -v root="$SHELL_DIR" -f "$SHELL_FUNCTION_CATALOG_AWK" |
		LC_ALL=C sort -t "$tab" -k1,1
}

# @internal
# @description The catalog filtered: visibility, namespace, keyword, load state.
#   The keyword is split on spaces; every word must occur (case-insensitive) in the name or the summary.
#   The namespace is the part after `shell::` (`git`), or a longer prefix (`git::commit`).
# @arg $1 string `true` to include internal functions (default `false`).
# @arg $2 string Optional. Namespace.
# @arg $3 string Optional. Keyword(s).
# @arg $4 string `true` to keep only functions that are not loaded.
# @stdout The matching catalog records.
# @exitcode 0 Always (nothing printed when nothing matches).
# @example
#   _shell::function::select false git "pick fzf"
#
_shell::function::select() {
	_shell::function::catalog | SHELL_FN_KW="${3-}" SHELL_FN_CAT="${2-}" awk -F'\t' -v internal="${1-false}" -v unl="${4-false}" '
		BEGIN {
			nw = split(tolower(ENVIRON["SHELL_FN_KW"]), raw, /[ \t]+/)
			for (i = 1; i <= nw; i++) if (raw[i] != "") words[++nk] = raw[i]
			cat = ENVIRON["SHELL_FN_CAT"]
		}
		internal != "true" && $2 == "internal" { next }
		unl == "true" && $4 == "yes" { next }
		cat != "" {
			bare = $1
			sub(/^_/, "", bare)
			if ($3 != cat && index(bare, "shell::" cat "::") != 1) next
		}
		nk > 0 {
			hay = tolower($1 " " $8)
			for (i = 1; i <= nk; i++) if (index(hay, words[i]) == 0) next
		}
		{ print }'
}

# @internal
# @description Resolve what the user typed to the name of a catalog function.
#   Accepts the full name, the name without `shell::` (`git::branch::merge`), or the internal form without `_shell::`.
# @arg $1 string The name as typed.
# @stdout The catalog record.
# @exitcode 0 Found.
# @exitcode 3 Not in the catalog.
# @example
#   record="$(_shell::function::find git::branch::merge)"
#
_shell::function::find() {
	local want record
	for want in "${1-}" "shell::${1-}" "_shell::${1-}"; do
		[ -n "$want" ] || continue
		record="$(_shell::function::catalog | awk -F'\t' -v n="$want" '$1 == n { print; exit }')"
		if [ -n "$record" ]; then
			printf '%s\n' "$record"
			return "$RETURN_SUCCESS"
		fi
	done
	return "$RETURN_NOT_FOUND"
}

# @description List the library's functions, grouped by namespace.
#   Reads the function catalog (see lib/function.sh), so it needs no terminal and no fzf: it is the plain
#   text face of shell::function::explore. Public functions only, unless `--internal`. With a keyword, only
#   functions whose name or description contain every word (case-insensitive). A function that is in the
#   source tree but not loaded in this shell is marked `[not loaded]`.
# @option -c | --namespace Optional. Only this namespace, e.g. `git` or `git::commit` (`--category` is the same).
# @option -i | --internal Optional. Also list internal helpers (`_shell::*`).
# @option --unloaded Optional. Only functions that are in the source tree but not loaded in this shell.
# @option --names Optional. Names only, one per line (for scripts and completion).
# @option --namespaces Optional. One line per namespace with its number of functions.
# @option --tsv Optional. The raw catalog records, tab separated.
# @option -h | --help Show this help message.
# @arg $@ string keyword: Optional. Words to look for in names and descriptions.
# @stdout The listing.
# @exitcode 0 Something was listed.
# @exitcode 2 Invalid usage.
# @exitcode 8 Nothing matches.
# @see shell::function::info
# @see shell::function::explore
# @example
#   shell::function::list
#   shell::function::list git
#   shell::function::list --namespace git::commit pick
#   shell::function::list --names --namespace ssh
#
shell::function::list() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "List the shell:: functions by namespace, with their descriptions"
		shell::logger::usage "shell::function::list [-c <namespace>] [-i] [--unloaded] [--names | --namespaces | --tsv] [<keyword>...]"
		shell::logger::item "keyword" "Words that must all occur in the name or the description"
		shell::logger::option "-c, --namespace <ns>" "Only this namespace (git, ssh, git::commit, ...)"
		shell::logger::option "-i, --internal" "Also list the internal helpers (_shell::*)"
		shell::logger::option "--unloaded" "Only functions in the source tree that are not loaded in this shell"
		shell::logger::option "--names" "Names only, one per line"
		shell::logger::option "--namespaces" "One line per namespace with its function count"
		shell::logger::option "--tsv" "Raw catalog records, tab separated"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::function::list git"
		shell::logger::example "shell::function::list --namespace git::commit pick"
		return "$RETURN_SUCCESS"
	fi

	local internal="false" category="" unloaded="false" format="table" keyword="" val
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-i | --internal)
			internal="true"
			shift
			;;
		--unloaded)
			unloaded="true"
			shift
			;;
		--names | --namespaces | --tsv)
			format="${1#--}"
			shift
			;;
		-c | --namespace | --category | --namespace=* | --category=*)
			case "$1" in
			--*=*)
				val="${1#*=}"
				shift
				;;
			*)
				if [ "$#" -lt 2 ]; then
					shell::logger::error "Option $1 requires a value"
					return "$RETURN_INVALID"
				fi
				val="$2"
				shift 2
				;;
			esac
			category="$val"
			;;
		--)
			shift
			break
			;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*)
			keyword="${keyword:+$keyword }$1"
			shift
			;;
		esac
	done
	while [ "$#" -gt 0 ]; do
		keyword="${keyword:+$keyword }$1"
		shift
	done

	local records
	records="$(_shell::function::select "$internal" "$category" "$keyword" "$unloaded")"
	if [ -z "$records" ]; then
		shell::logger::warn "No function matches"
		return "$RETURN_EMPTY"
	fi

	case "$format" in
	tsv) printf '%s\n' "$records" ;;
	names) printf '%s\n' "$records" | cut -f1 ;;
	namespaces)
		printf '%s\n' "$records" | awk -F'\t' '{ c[$3]++ } END { for (k in c) printf "%s\t%d\n", k, c[k] }' | LC_ALL=C sort |
			awk -F'\t' '{ printf "%-16s %d\n", $1, $2 }'
		;;
	*)
		printf '%s\n' "$records" | LC_ALL=C sort -t "$(printf '\t')" -k3,3 -k1,1 | awk -F'\t' '
			{ n++; nm[n] = $1; ca[n] = $3; su[n] = ($8 == "" ? "(no description)" : $8)
			  if ($4 == "no") su[n] = "[not loaded] " su[n]
			  cnt[$3]++; if (length($1) > w) w = length($1) }
			END {
				pad = sprintf("%*s", w, "")
				for (i = 1; i <= n; i++) {
					if (ca[i] != last) { if (i > 1) print ""; printf "%s (%d)\n", ca[i], cnt[ca[i]]; last = ca[i] }
					printf "  %s%s  %s\n", nm[i], substr(pad, 1, w - length(nm[i])), su[i]
				}
				printf "\n%d function(s)\n", n
			}'
		;;
	esac
}

# @description Show everything the source says about one function.
#   Renders the function's shdoc block: description, options, arguments, input/output, exit codes,
#   see-also and examples, plus its namespace, visibility, whether it is loaded, and where it is defined.
#   Nothing is executed. The name may omit the `shell::` prefix.
# @option --raw Optional. Print the documentation block exactly as written in the source.
# @option -h | --help Show this help message.
# @arg $1 string name: The function, e.g. `shell::fs::browse` or `fs::browse`.
# @stdout The reference page.
# @exitcode 0 Shown.
# @exitcode 2 Invalid usage.
# @exitcode 3 No such function (similar names are suggested).
# @see shell::function::list
# @example
#   shell::function::info shell::git::commit::pick::fzf
#   shell::function::info fs::browse
#
shell::function::info() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Show the description, usage and examples of one shell:: function"
		shell::logger::usage "shell::function::info [--raw] <function>"
		shell::logger::item "function" "Full name, or without the shell:: prefix (fs::browse)"
		shell::logger::option "--raw" "Print the documentation block as written in the source"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::function::info fs::browse"
		return "$RETURN_SUCCESS"
	fi

	local raw="false" name=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--raw)
			raw="true"
			shift
			;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*)
			if [ -n "$name" ]; then
				shell::logger::error "Only one function is accepted (got '$name' and '$1')"
				return "$RETURN_INVALID"
			fi
			name="$1"
			shift
			;;
		esac
	done
	if [ -z "$name" ]; then
		shell::logger::error "A function name is required"
		return "$RETURN_INVALID"
	fi

	local record fn vis cat loaded file first line rest color="0"
	record="$(_shell::function::find "$name")" || {
		shell::logger::error "No such function: ${name}"
		local similar
		similar="$(_shell::function::select true "" "$name" | cut -f1 | head -n 8)"
		if [ -n "$similar" ]; then
			shell::logger::info "Similar: $(printf '%s' "$similar" | tr '\n' ' ')"
		fi
		return "$RETURN_NOT_FOUND"
	}
	IFS="$(printf '\t')" read -r fn vis cat loaded file first line rest <<EOF
$record
EOF
	if [ -t 1 ]; then color="1"; fi

	local block=""
	if [ "$file" != "-" ] && [ "$first" -lt "$line" ] && [ -r "$SHELL_DIR/$file" ]; then
		block="$(sed -n "${first},$((line - 1))p" "$SHELL_DIR/$file")"
	fi
	if [ "$raw" = "true" ]; then
		printf '%s\n' "$block"
		return "$RETURN_SUCCESS"
	fi
	printf '%s\n' "$block" | awk -v name="$fn" -v vis="$vis" -v category="$cat" -v loaded="$loaded" \
		-v file="$file" -v line="$line" -v color="$color" -f "$SHELL_FUNCTION_DOC_AWK"
}

# @internal
# @description Wait for Enter so the output of an action stays readable before fzf redraws.
# @exitcode 0 Always.
# @example
#   _shell::function::pause
#
_shell::function::pause() {
	local ignored
	printf '\nPress Enter to go back...' >&2
	read -r ignored || true
}

# @internal
# @description Run a library function in the CURRENT shell after an explicit confirmation.
#   Shows its usage, asks for the arguments (empty = none), shows the command line and asks to
#   confirm. It runs as typed, the way the same line typed at the prompt would, so quoting and
#   expansions behave normally, and the function can change the directory, the environment or
#   the shell's state. Nothing runs without the confirmation.
# @arg $1 string Function name (a catalog function loaded in this shell).
# @exitcode 0 It ran (see the printed status for its own exit code).
# @exitcode 3 It is not loaded in this shell.
# @exitcode 9 Cancelled (Ctrl-D, or "no" at the confirmation).
# @example
#   _shell::function::invoke shell::os::type
#
_shell::function::invoke() {
	local name="${1-}" args cmd status_code
	case "$name" in
	'' | *[!A-Za-z0-9_:]*)
		shell::logger::error "Not a function name: '${name}'"
		return "$RETURN_INVALID"
		;;
	esac
	if ! _shell::function::is_loaded "$name"; then
		shell::logger::error "${name} is not loaded in this shell (source the library again)"
		return "$RETURN_NOT_FOUND"
	fi
	shell::function::info "$name"
	printf '\nArguments for %s (empty = none, Ctrl-D cancels): ' "$name" >&2
	read -r args || {
		printf '\n' >&2
		return "$RETURN_CANCELLED"
	}
	cmd="${name}${args:+ ${args}}"
	if ! shell::ask::accept "Run: ${cmd}"; then
		shell::logger::info "Not run"
		return "$RETURN_CANCELLED"
	fi
	eval "$cmd"
	status_code=$?
	shell::logger::info "Exit status: ${status_code}"
	return "$RETURN_SUCCESS"
}

# @internal
# @description The action menu of one function in the explorer: details, run, its own help, copy the name.
#   Choosing a function in the list never runs anything; "Run" is an explicit entry of this menu.
# @arg $1 string Function name.
# @exitcode 0 Always (back, cancel and every action return to the list).
# @example
#   _shell::function::act shell::os::type
#
_shell::function::act() {
	local name="${1-}" choice rc
	choice="$(shell::ask::option::back --prompt "${name}: " "Show details" "Run it..." "Show its own help (-h)" "Copy the name")"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		return "$RETURN_SUCCESS"
	fi
	case "$choice" in
	"Show details")
		shell::function::info "$name"
		_shell::function::pause
		;;
	"Run it...")
		_shell::function::invoke "$name"
		_shell::function::pause
		;;
	"Show its own help (-h)")
		if _shell::function::is_loaded "$name"; then
			"$name" -h
		else
			shell::logger::error "${name} is not loaded in this shell"
		fi
		_shell::function::pause
		;;
	"Copy the name")
		shell::clipboard::copy "$name"
		;;
	esac
	return "$RETURN_SUCCESS"
}

# @internal
# @description Turn catalog records into explorer rows `name vis loaded abs-file first line rel-file display`.
#   The first seven fields are hidden data for the preview and the actions; the last is what fzf shows
#   and searches: the name padded to a column, then the summary.
# @stdin Catalog records.
# @stdout The rows.
# @exitcode 0 Always.
# @example
#   _shell::function::select false git | _shell::function::rows
#
_shell::function::rows() {
	awk -F'\t' -v root="$SHELL_DIR" '
		{ n++; r[n] = $0; if (length($1) > w) w = length($1) }
		END {
			pad = sprintf("%*s", w, "")
			for (i = 1; i <= n; i++) {
				split(r[i], f, "\t")
				abs = (f[5] == "-") ? "-" : root "/" f[5]
				s = (f[8] == "" ? "(no description)" : f[8])
				if (length(s) > 72) s = substr(s, 1, 71) "…"
				if (f[4] == "no") s = "[not loaded] " s
				printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s  %s\n", f[1], f[2], f[4], abs, f[6], f[7], f[5], f[1] substr(pad, 1, w - length(f[1])), s
			}
		}'
}

# @internal
# @description The namespace → function → action loop of the explorer.
# @arg $1 string Scratch directory.
# @arg $2 string `true` to include internal functions.
# @arg $3 string Optional. Namespace to start in (skips the namespace list).
# @arg $4 string Optional. Initial query of the function list (skips the namespace list).
# @arg $5 string `true` to keep only functions that are not loaded.
# @exitcode 0 Closed (ESC, or back out of the function list).
# @exitcode 8 There is nothing to explore.
# @exitcode 11 "← Back" at the namespace list.
# @example
#   _shell::function::explore_loop "$dir" false "" "" false
#
_shell::function::explore_loop() {
	local work="${1-}" internal="${2-false}" category="${3-}" query="${4-}" unloaded="${5-false}"
	local tab back="$SHELL_FZF_BACK_LABEL" step picked rc name total from_ns="false"
	local -a initial=() query_args=()
	tab="$(printf '\t')"
	_shell::function::select "$internal" "" "" "$unloaded" >"${work}/catalog.tsv"
	if [ ! -s "${work}/catalog.tsv" ]; then
		shell::logger::warn "No functions to explore"
		return "$RETURN_EMPTY"
	fi
	total="$(wc -l <"${work}/catalog.tsv" | tr -d ' ')"
	step="namespaces"
	if [ -n "$category" ] || [ -n "$query" ]; then step="functions"; fi
	export SHELL_FUNCTION_PREVIEW_TSV="${work}/catalog.tsv" SHELL_FUNCTION_DOC_AWK SHELL_FUNCTION_PREVIEW_SH

	while true; do
		case "$step" in
		namespaces)
			picked="$({
				printf 'all\tAll functions (%s)\n' "$total"
				awk -F'\t' '{ c[$3]++ } END { for (k in c) printf "%s\t%s (%d)\n", k, k, c[k] }' "${work}/catalog.tsv" | LC_ALL=C sort
				printf '@back\t%s\n' "$back"
			} | shell::fzf::select ${initial[@]+"${initial[@]}"} --height=60% "--delimiter=${tab}" --with-nth=2 \
				--prompt="Namespace: " --header="Enter: open   ESC: close" \
				"--preview=awk -F'\\t' -v c={1} '(c==\"all\" || \$3==c) { printf \"%s  %s\\n\", \$1, \$8 }' \"\$SHELL_FUNCTION_PREVIEW_TSV\" | head -n 300" \
				--preview-window='right:60%:wrap')"
			rc=$?
			if [ "$rc" -ne 0 ] || [ -z "$picked" ]; then
				return "$RETURN_SUCCESS"
			fi
			picked="${picked%%"$tab"*}"
			if [ "$picked" = "@back" ]; then
				return "$RETURN_BACK"
			fi
			initial=(--initial "$picked" --initial-field 1)
			category="$picked"
			if [ "$category" = "all" ]; then category=""; fi
			from_ns="true"
			step="functions"
			;;
		functions)
			query_args=()
			if [ -n "$query" ]; then query_args=("--query=${query}"); fi
			picked="$({
				awk -F'\t' -v c="$category" '
					c == "" { print; next }
					{ bare = $1; sub(/^_/, "", bare); if ($3 == c || index(bare, "shell::" c "::") == 1) print }' "${work}/catalog.tsv" | _shell::function::rows
				printf '@back\t-\t-\t-\t0\t0\t-\t%s\n' "$back"
			} | shell::fzf::select ${initial[@]+"${initial[@]}"} --height=80% "--delimiter=${tab}" --with-nth=8 \
				"--prompt=Function${category:+ (${category})}: " --header="Enter: actions (nothing runs until you choose Run)   ESC: close" \
				${query_args[@]+"${query_args[@]}"} \
				"--preview=sh \"\$SHELL_FUNCTION_PREVIEW_SH\" {1} {2} {3} {4} {5} {6} {7}" \
				--preview-window='right:50%:wrap' --no-hscroll)"
			rc=$?
			if [ "$rc" -ne 0 ] || [ -z "$picked" ]; then
				return "$RETURN_SUCCESS"
			fi
			name="${picked%%"$tab"*}"
			if [ "$name" = "@back" ]; then
				if [ "$from_ns" = "false" ]; then return "$RETURN_BACK"; fi
				query=""
				initial=(--initial "${category:-all}" --initial-field 1)
				step="namespaces"
				continue
			fi
			_shell::function::act "$name"
			initial=(--initial "$name" --initial-field 1)
			;;
		esac
	done
}

# @description Browse the library's functions interactively: pick a namespace, search, read, then act.
#   An fzf explorer over the same catalog as shell::function::list. The list shows each function's name and
#   description (fuzzy search covers both); the preview on the right is its documentation. Enter opens a
#   menu, so choosing a function never runs it: show details, **run it** (asks for the arguments and
#   confirms, then runs in your current shell), show its own `-h`, or copy its name. Back and ESC return
#   without changing anything, and the list keeps its cursor after every action. fzf is optional: without
#   it, or when the output is not a terminal, the plain list is printed instead (use `--interactive` to
#   force fzf, `--plain` to force the list).
# @option -c | --namespace Optional. Start in this namespace (skips the namespace list).
# @option -i | --internal Optional. Also include internal helpers (`_shell::*`).
# @option --unloaded Optional. Only functions that are in the source tree but not loaded in this shell.
# @option --interactive Optional. Use fzf even if the output is not a terminal.
# @option --plain Optional. Print the plain list (shell::function::list) instead of opening fzf.
# @option -h | --help Show this help message.
# @arg $@ string query: Optional. A namespace name opens that namespace; anything else is the initial search.
# @exitcode 0 Closed (or the plain list was printed).
# @exitcode 2 Invalid usage.
# @exitcode 8 There is nothing to explore.
# @exitcode 11 The user picked "← Back" at the namespace list; nothing was changed.
# @see shell::function::list
# @see shell::function::info
# @example
#   shell::function::explore
#   shell::function::explore git
#   shell::function::explore pick commit
#
shell::function::explore() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Explore the shell:: functions with fzf: namespaces, search, preview, then run / copy"
		shell::logger::usage "shell::function::explore [-c <namespace>] [-i] [--unloaded] [--interactive | --plain] [<query>]"
		shell::logger::item "query" "A namespace (git) opens it; anything else is the initial search"
		shell::logger::option "-c, --namespace <ns>" "Start in this namespace"
		shell::logger::option "-i, --internal" "Also include internal helpers (_shell::*)"
		shell::logger::option "--unloaded" "Only functions in the source tree that are not loaded in this shell"
		shell::logger::option "--interactive" "Use fzf even if the output is not a terminal"
		shell::logger::option "--plain" "Print the plain list instead of opening fzf"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::note "Enter opens a menu; nothing runs until you pick 'Run it...' and confirm. fzf is optional."
		shell::logger::example "shell::function::explore"
		shell::logger::example "shell::function::explore git"
		return "$RETURN_SUCCESS"
	fi

	local internal="false" category="" unloaded="false" mode="auto" query="" val
	local -a list_args=()
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-i | --internal)
			internal="true"
			list_args+=(--internal)
			shift
			;;
		--unloaded)
			unloaded="true"
			list_args+=(--unloaded)
			shift
			;;
		--interactive)
			mode="interactive"
			shift
			;;
		--plain)
			mode="plain"
			shift
			;;
		-c | --namespace | --category | --namespace=* | --category=*)
			case "$1" in
			--*=*)
				val="${1#*=}"
				shift
				;;
			*)
				if [ "$#" -lt 2 ]; then
					shell::logger::error "Option $1 requires a value"
					return "$RETURN_INVALID"
				fi
				val="$2"
				shift 2
				;;
			esac
			category="$val"
			;;
		-?*)
			shell::logger::error "Unknown option: $1"
			return "$RETURN_INVALID"
			;;
		*)
			query="${query:+$query }$1"
			shift
			;;
		esac
	done

	# A lone word that is a namespace opens it; anything else is the initial search.
	if [ -z "$category" ] && [ -n "$query" ]; then
		case "$query" in
		*[!a-z0-9_:]*) ;;
		*)
			if [ -n "$(_shell::function::select "$internal" "$query" "" "$unloaded" | head -n 1)" ]; then
				category="$query"
				query=""
			fi
			;;
		esac
	fi

	local interactive="false"
	case "$mode" in
	interactive) interactive="true" ;;
	auto) if [ -t 1 ] && [ -t 0 ]; then interactive="true"; fi ;;
	esac
	if [ "$interactive" = "true" ] && ! command -v fzf >/dev/null 2>&1; then
		shell::logger::info "fzf is not installed (it is optional): showing the plain list"
		interactive="false"
	fi
	if [ "$interactive" = "false" ]; then
		if [ -n "$category" ]; then list_args+=(--namespace "$category"); fi
		if [ -n "$query" ]; then list_args+=(-- "$query"); fi
		shell::function::list ${list_args[@]+"${list_args[@]}"}
		return $?
	fi

	local work rc
	work="$(mktemp -d "${TMPDIR:-/tmp}/shell-function.XXXXXX" 2>/dev/null)" || {
		shell::logger::error "Could not create a temporary directory"
		return "$RETURN_FAILURE"
	}
	_shell::function::explore_loop "$work" "$internal" "$category" "$query" "$unloaded"
	rc=$?
	unset SHELL_FUNCTION_PREVIEW_TSV SHELL_FUNCTION_PREVIEW_SH
	rm -rf "$work"
	return "$rc"
}
