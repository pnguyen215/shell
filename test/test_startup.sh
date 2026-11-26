#!/usr/bin/env bash
# Start-up guards: the lazy loader must define the same functions as eager loading, load silently, fork
# nothing, leak no shell options, re-source safely and work from a path with spaces.
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
t_setup

SRC="$SHELL_TEST_ROOT"
# Child shells under test: bash always, zsh when installed.
set -- bash
command -v zsh >/dev/null 2>&1 && set -- bash zsh

# child <shell> <code>: run <code> in a clean shell that has the library loaded (lazy unless SHELL_LAZY=0).
clean_sh() { # <shell> <code>: a clean shell, no rc files (zsh does not word-split, hence two branches)
	if [ "$1" = "zsh" ]; then zsh -f -c "$2"; else bash --noprofile --norc -c "$2"; fi
}
child() {
	SHELL_DIR="$SRC" SHELL_AUTO_INSTALL_DEPS=0 clean_sh "$1" "source \"\$SHELL_DIR/src/shell.sh\"; $2"
}
names_code_bash='declare -F | sed "s/^declare -f //"'
names_code_zsh='print -rl -- ${(k)functions}'
names_of() { # <shell>
	if [ "$1" = "zsh" ]; then child zsh "$names_code_zsh" | sort; else child bash "$names_code_bash" | sort; fi
}

for sh in "$@"; do
	# Warm the cache once so the checks below measure the cache-hit path.
	child "$sh" ':' >/dev/null 2>&1

	# --- backward compatibility: every eager function exists in lazy mode, nothing else but the loader helpers
	SHELL_LAZY=0 names_of "$sh" >"$T_HOME/eager.$sh"
	names_of "$sh" >"$T_HOME/lazy.$sh"
	t_eq "$sh: eager mode defines functions" "1" "$([ "$(wc -l <"$T_HOME/eager.$sh")" -gt 1000 ] && echo 1 || echo 0)"
	t_eq "$sh: lazy mode lacks no eager function" "" "$(comm -23 "$T_HOME/eager.$sh" "$T_HOME/lazy.$sh")"
	t_eq "$sh: lazy mode adds no function" "" "$(comm -13 "$T_HOME/eager.$sh" "$T_HOME/lazy.$sh")"

	# --- the stubs cover every function a module defines: loading all modules adds no new name
	all_code='for f in "$SHELL_SRC_DIR"/*/*.sh; do case "$f" in */loader/*|*/constant/*) continue;; esac; source "$f" >/dev/null 2>&1; done;'
	if [ "$sh" = "zsh" ]; then
		child zsh "$all_code $names_code_zsh" | sort >"$T_HOME/forced.$sh"
	else
		child bash "$all_code $names_code_bash" | sort >"$T_HOME/forced.$sh"
	fi
	t_eq "$sh: forcing every module defines no function the stubs do not cover" "" "$(comm -13 "$T_HOME/lazy.$sh" "$T_HOME/forced.$sh")"

	# --- representative calls produce the same output and status in both modes
	for call in 'shell::os::type' 'shell::logger::style::get' 'shell::git::branch::sync -h' 'typeset -f shell::git::commit::amend >/dev/null; echo rc=$?'; do
		lazy_out="$(
			child "$sh" "$call" 2>&1
			echo "rc=$?"
		)"
		eager_out="$(
			SHELL_LAZY=0 child "$sh" "$call" 2>&1
			echo "rc=$?"
		)"
		t_eq "$sh: same result lazy vs eager: $call" "$eager_out" "$lazy_out"
	done

	# --- load guard: silent, exit 0, no leaked options, no load errors
	out="$(child "$sh" 'echo "errors=$SHELL_LOAD_ERRORS loaded=$SHELL_LOADED"' 2>&1)"
	t_eq "$sh: loads silently with no errors" "errors=0 loaded=1" "$out"
	if [ "$sh" = "zsh" ]; then
		opts_cmd='setopt'
		before="$(clean_sh zsh "$opts_cmd" | sort)"
		after="$(child zsh "$opts_cmd" | sort)"
	else
		opts_cmd='set +o; shopt -p'
		before="$(clean_sh bash "$opts_cmd")"
		after="$(child bash "$opts_cmd")"
	fi
	t_eq "$sh: sourcing leaks no shell options" "$before" "$after"

	# --- idempotent re-source
	out="$(child "$sh" 'source "$SHELL_DIR/src/shell.sh"; source "$SHELL_DIR/src/shell.sh"; echo "errors=$SHELL_LOAD_ERRORS"; shell::os::type' 2>&1)"
	t_eq "$sh: re-sourcing is safe" "errors=0
$(SHELL_OS_TYPE='' child "$sh" 'shell::os::type')" "$out"

	# --- a lazy function works on first call, with exact arguments and stdin
	out="$(child "$sh" 'typeset -f shell::git::branch::sync >/dev/null && echo defined' 2>&1)"
	t_eq "$sh: stub reports the function as defined" "defined" "$out"
done

# --- zero forks at load (cache hit): external commands are shimmed to log themselves
shim="$T_HOME/shim"
mkdir -p "$shim"
for c in cat sed uname tput git curl awk tr date grep dirname basename which brew base64 head cut sort wc mktemp stat id hostname readlink; do
	p="$(command -v "$c" 2>/dev/null)" || continue
	printf '#!/bin/sh\necho %s >> "$SHIMLOG"\nexec %s "$@"\n' "$c" "$p" >"$shim/$c"
	chmod +x "$shim/$c"
done
for sh in "$@"; do
	child "$sh" ':' >/dev/null 2>&1 # warm
	: >"$T_HOME/shimlog"
	PATH="$shim:$PATH" SHIMLOG="$T_HOME/shimlog" SHELL_DIR="$SRC" clean_sh "$sh" "source \"\$SHELL_DIR/src/shell.sh\"" >/dev/null 2>&1
	t_eq "$sh: zero external processes at load (cache hit)" "" "$(sort "$T_HOME/shimlog" | uniq -c)"
done

# --- an override defined before a module loads survives the lazy load of that module
probe="$T_HOME/probe lib"
mkdir -p "$probe" && cp -R "$SRC/src" "$probe/src"
printf '# @description A.\nshell::probe::a() {\n\techo a-real\n}\n\n# @description B.\nshell::probe::b() {\n\techo b-real\n}\n' >"$probe/src/lib/probe_two.sh"
for sh in "$@"; do
	out="$(SHELL_DIR="$probe" SHELL_AUTO_INSTALL_DEPS=0 clean_sh "$sh" "source \"\$SHELL_DIR/src/shell.sh\"; shell::probe::b() { echo b-override; }; shell::probe::a; shell::probe::b" 2>&1)"
	t_eq "$sh: an override survives the lazy load of its module" "a-real
b-override" "$out"
	out="$(SHELL_DIR="$probe" SHELL_AUTO_INSTALL_DEPS=0 clean_sh "$sh" "source \"\$SHELL_DIR/src/shell.sh\"; shell::probe::b; shell::probe::a" 2>&1)"
	t_eq "$sh: without an override the real function runs" "b-real
a-real" "$out"
done

# --- cache lifecycle on a copy of the library whose path contains spaces
copy="$T_HOME/my lib copy"
mkdir -p "$copy" && cp -R "$SRC/src" "$copy/src"
run_copy() { SHELL_DIR="$copy" SHELL_AUTO_INSTALL_DEPS=0 bash --noprofile --norc -c "source \"\$SHELL_DIR/src/shell.sh\"; $1" 2>&1; }
t_eq "spaces in the path: loads" "errors=0" "$(run_copy 'echo errors=$SHELL_LOAD_ERRORS')"
t_eq "spaces in the path: cache is written inside the install dir" "yes" "$([ -s "$copy/.cache/lazy.sh" ] && echo yes || echo no)"
t_eq "spaces in the path: a lazy function runs" "defined" "$(run_copy 'typeset -f shell::git::commit::amend >/dev/null && echo defined')"
before_mtime="$(cksum <"$copy/.cache/lazy.sh")"
sleep 1
# Editing a module makes the cache stale: it is rebuilt and the new function is visible.
printf '\n# @description Test function.\nshell::startup_probe::ok() {\n\techo probe-ok\n}\n' >>"$copy/src/lib/goto.sh"
t_eq "stale cache is rebuilt after a module edit" "probe-ok" "$(run_copy 'shell::startup_probe::ok')"
t_eq "rebuilt cache differs" "1" "$([ "$before_mtime" != "$(cksum <"$copy/.cache/lazy.sh")" ] && echo 1 || echo 0)"
# A read-only install dir (no cache possible) falls back to eager loading.
rm -rf "$copy/.cache"
chmod 555 "$copy"
t_eq "unwritable install dir falls back to eager loading" "errors=0 probe-ok" "$(run_copy 'echo errors=$SHELL_LOAD_ERRORS $(shell::startup_probe::ok)')"
chmod 755 "$copy"
# SHELL_LAZY=0 never touches the cache.
rm -rf "$copy/.cache"
t_eq "SHELL_LAZY=0 loads eagerly" "errors=0" "$(SHELL_LAZY=0 run_copy 'echo errors=$SHELL_LOAD_ERRORS')"
t_eq "SHELL_LAZY=0 writes no cache" "no" "$([ -e "$copy/.cache/lazy.sh" ] && echo yes || echo no)"

t_done
