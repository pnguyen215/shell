#!/usr/bin/env bash
# The loader of the Git toolkit (src/lang/git/index.sh): manifest against the filesystem, files without
# top-level side effects, and stubs that keep arguments, standard streams and exit status.
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
t_setup

TK="$SHELL_TEST_ROOT/src/lang/git"
# Groups whose action files are not written yet: shrink this list as each group lands (empty at the end).
PENDING=""

manifest="$(grep -oE '^shell::git::[a-z]+::[a-z_]+\(\)' "$TK/index.sh" | sed 's/()$//' | sort)"
t_eq "manifest: 33 public functions" "33" "$(printf '%s\n' "$manifest" | wc -l | tr -d ' ')"
t_eq "manifest: no duplicate" "" "$(printf '%s\n' "$manifest" | uniq -d)"

# words <string>: one word per line (zsh does not word-split unquoted variables, so loops read lines instead)
words() { printf '%s\n' "$1" | tr ' ' '\n' | sed '/^$/d'; }

# every manifest entry has its file (unless its group is still pending)
missing=""
while IFS= read -r fn; do
	rest="${fn#shell::git::}"
	group="${rest%%::*}"
	action="${rest#*::}"
	case " $PENDING " in *" $group "*) continue ;; esac
	[ -f "$TK/$group/$action.sh" ] || missing="$missing $group/$action.sh"
done <<EOF
$manifest
EOF
t_eq "manifest: every entry has its file" "" "$missing"

# every file on disk is in the manifest (a stray file is never executed, and it is reported here)
stray=""
for f in "$TK"/*/*.sh; do
	rel="${f#"$TK"/}"
	group="${rel%%/*}"
	[ "$group" = "_core" ] && continue
	action="${rel#*/}"
	action="${action%.sh}"
	case "$manifest" in *"shell::git::$group::$action"*) ;; *) stray="$stray $rel" ;; esac
done
t_eq "manifest: no file on disk is missing from it" "" "$stray"

# every stub loads the file its name says
wrong="$(grep -E '^shell::git::[a-z]+::[a-z_]+\(\)' "$TK/index.sh" | awk '{ split($1, a, "::"); g = a[3]; sub(/\(\)$/, "", a[4]); want = g "/" a[4]; if ($4 != want || $5 != "shell::git::" g "::" a[4]) print $1 }')"
t_eq "manifest: each stub loads <group>/<action> and calls <its own name>" "" "$wrong"

# _core: the files the loader sources exist, and nothing else is in _core
core_listed="$(sed -n 's/^	for name in \(.*\); do$/\1/p' "$TK/index.sh")"
core_missing=""
while IFS= read -r n; do [ -f "$TK/_core/$n.sh" ] || core_missing="$core_missing $n"; done <<EOF
$(words "$core_listed")
EOF
t_eq "_core: every listed helper file exists" "" "$core_missing"
core_extra=""
for f in "$TK"/_core/*.sh; do
	b="${f##*/}"
	b="${b%.sh}"
	case " $core_listed " in *" $b "*) ;; *) core_extra="$core_extra $b" ;; esac
done
t_eq "_core: no helper file the loader does not source" "" "$core_extra"

# action files: top level holds comments and exactly one function, named after the file; no side effects
check_file() { # <file> <expected function name or empty for _core>
	awk -v want="$2" '
		/^[ \t]*$/ || /^[ \t]*#/ { next }
		infn { if ($0 ~ /^}[ \t]*$/) infn = 0; next }
		/^_?shell::[A-Za-z0-9_:]+\(\) \{ .*; \}$/ { name = $1; sub(/\(\)$/, "", name); n++; names = names " " name; next }
		/^(function[ \t]+)?_?shell::[A-Za-z0-9_:]+[ \t]*\(\)[ \t]*\{[ \t]*$/ { name = $1; sub(/\(\)$/, "", name); n++; names = names " " name; infn = 1; next }
		{ print "top-level statement: " $0 }
		END { if (want != "" && (n != 1 || names != " " want)) print "expected exactly " want ", found:" names }' "$1"
}
bad=""
for f in "$TK"/*/*.sh "$TK/index.sh"; do
	rel="${f#"$TK"/}"
	group="${rel%%/*}"
	case "$rel" in
	index.sh) out="$(check_file "$f" "")" ;;
	_core/*) out="$(check_file "$f" "")" ;;
	*)
		action="${rel#*/}"
		action="${action%.sh}"
		out="$(check_file "$f" "shell::git::$group::$action")"
		;;
	esac
	[ -z "$out" ] || bad="$bad
$rel: $out"
done
t_eq "files: top level is comments and function definitions only; one public function per action file" "" "$bad"
# the contributor rule, stated where people look
t_has "index.sh states the contributor rule" "No command substitutions, external commands, file reads or network at the top level" "$(tr '\n' ' ' <"$TK/index.sh" | sed 's/# *//g; s/  */ /g' | sed 's/Contributor rule: no/Contributor rule: No/')"

# --- stubs on a copy of the tree extended with probe actions
copy="$HOME/my copy"
mkdir -p "$copy" && cp -R "$SHELL_TEST_ROOT/src" "$copy/src"
mkdir -p "$copy/src/lang/git/probe"
cat >>"$copy/src/lang/git/index.sh" <<'IDX'

# @description Probe.
shell::git::probe::args() { _shell::git::core::lazy probe/args shell::git::probe::args "$@"; }
# @description Probe.
shell::git::probe::status() { _shell::git::core::lazy probe/status shell::git::probe::status "$@"; }
# @description Probe.
shell::git::probe::cat() { _shell::git::core::lazy probe/cat shell::git::probe::cat "$@"; }
# @description Probe.
shell::git::probe::wrong() { _shell::git::core::lazy probe/wrong shell::git::probe::wrong "$@"; }
# @description Probe.
shell::git::probe::broken() { _shell::git::core::lazy probe/broken shell::git::probe::broken "$@"; }
IDX
cat >"$copy/src/lang/git/probe/args.sh" <<'ACT'
# @description Print each argument in brackets.
shell::git::probe::args() {
	local a
	for a in "$@"; do printf '[%s]\n' "$a"; done
	printf 'err\n' >&2
}
ACT
cat >"$copy/src/lang/git/probe/status.sh" <<'ACT'
# @description Exit with the given status.
shell::git::probe::status() {
	return "$1"
}
ACT
cat >"$copy/src/lang/git/probe/cat.sh" <<'ACT'
# @description Copy stdin to stdout.
shell::git::probe::cat() {
	cat
}
ACT
cat >"$copy/src/lang/git/probe/wrong.sh" <<'ACT'
# @description Defines another name than the stub promised.
shell::git::probe::other() {
	echo other
}
ACT
printf 'shell::git::probe::broken() {\n' >"$copy/src/lang/git/probe/broken.sh"

run_child() { # <shell> <code>
	if [ "$1" = "zsh" ]; then
		SHELL_DIR="$copy" SHELL_AUTO_INSTALL_DEPS=0 zsh -f -c "source \"\$SHELL_DIR/src/shell.sh\"; $2" 2>&1
	else
		SHELL_DIR="$copy" SHELL_AUTO_INSTALL_DEPS=0 bash --noprofile --norc -c "source \"\$SHELL_DIR/src/shell.sh\"; $2" 2>&1
	fi
}
set -- bash
command -v zsh >/dev/null 2>&1 && set -- bash zsh
for sh in "$@"; do
	out="$(run_child "$sh" 'typeset -f shell::git::probe::args >/dev/null && echo defined; echo "booted=${_SHELL_GIT_BOOTED-no}"')"
	t_eq "$sh: a stub is a defined function and loads nothing yet" "defined
booted=no" "$out"
	out="$(run_child "$sh" 'shell::git::probe::args "a b" "" -x -- "*" "it'"'"'s" 2>/dev/null')"
	t_eq "$sh: arguments arrive exactly (spaces, empty, leading dash, glob, quote)" "[a b]
[]
[-x]
[--]
[*]
[it's]" "$out"
	out="$(run_child "$sh" 'shell::git::probe::args one 2>&1 >/dev/null')"
	t_eq "$sh: stderr stays stderr" "err" "$out"
	out="$(run_child "$sh" 'shell::git::probe::args one 2>/dev/null; shell::git::probe::args two 2>/dev/null')"
	t_eq "$sh: the second call goes straight to the real function" "[one]
[two]" "$out"
	out="$(run_child "$sh" 'shell::git::probe::status 7; echo "rc=$?"')"
	t_eq "$sh: exit status is returned" "rc=7" "$out"
	out="$(run_child "$sh" 'shell::git::probe::status 0; echo "rc=$?"')"
	t_eq "$sh: exit status 0 too" "rc=0" "$out"
	out="$(run_child "$sh" 'printf "line1\nline2\n" | shell::git::probe::cat')"
	t_eq "$sh: stdin reaches the function" "line1
line2" "$out"
	out="$(run_child "$sh" 'shell::git::probe::wrong; echo "rc=$?"')"
	t_has "$sh: a file that does not define its function is reported" "not defined by probe/wrong.sh" "$out"
	t_has "$sh: ...with status 127" "rc=127" "$out"
	out="$(run_child "$sh" 'shell::git::probe::wrong >/dev/null 2>&1; shell::git::probe::wrong; echo "rc=$?"')"
	t_has "$sh: a repeated first call does not recurse forever" "rc=127" "$out"
	out="$(run_child "$sh" 'shell::git::probe::broken; echo "rc=$?"')"
	t_has "$sh: a file that fails to load is reported with status 1" "rc=1" "$out"
	if [ "$sh" = "zsh" ]; then
		before="$(zsh -f -c setopt | sort)"
		after="$(run_child zsh 'shell::git::probe::args x >/dev/null 2>&1; setopt' | sort)"
	else
		before="$(bash --noprofile --norc -c 'set +o; shopt -p')"
		after="$(run_child bash 'shell::git::probe::args x >/dev/null 2>&1; set +o; shopt -p')"
	fi
	t_eq "$sh: calling a stub leaks no shell option" "$before" "$after"
	out="$(run_child "$sh" 'source "$SHELL_DIR/src/lang/git/index.sh"; source "$SHELL_DIR/src/lang/git/index.sh"; shell::git::probe::args z 2>/dev/null')"
	t_eq "$sh: re-sourcing index.sh is idempotent" "[z]" "$out"
	out="$(run_child "$sh" 'shell::git::probe::args a >/dev/null 2>&1; typeset -f _shell::git::core::err >/dev/null && echo core-loaded')"
	t_eq "$sh: the _core helpers load on first use" "core-loaded" "$out"
	out="$(SHELL_LAZY=0 run_child "$sh" 'shell::git::probe::args a 2>/dev/null')"
	t_eq "$sh: works the same with SHELL_LAZY=0" "[a]" "$out"
done

t_done
