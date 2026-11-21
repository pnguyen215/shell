#!/usr/bin/env bash
# The fzf side of the zsh category (src/lib/zsh_fzf.sh, zsh_cache.sh, zsh_widget.sh): candidate
# generation and parsing, what a pick turns into, dry runs, cancelling, the TTL cache and the
# opt-in widgets. fzf is a fake that logs what it is given (stdin.N, args.N) and answers the Nth
# call with line N of $FAKE_FZF_PICKS: the pick is matched as text against the candidate lines
# and the whole matching line is printed, like fzf; `a;b` picks two lines; an empty line is ESC.
# Nothing here needs a terminal: _shell::zsh::fzf::has_tty is answered by the test.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

nl='
'
tab="$(printf '\t')"
mkdir -p "$HOME/bin" "$HOME/fzfdir"
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
case "$1" in --version) echo "0.64.0 (fake)"; exit 0 ;; esac
n="$(cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0)"
n=$((n + 1))
echo "$n" >"$FAKE_FZF_STATE"
cat >"$FAKE_FZF_DIR/stdin.$n"
printf '%s\n' "$@" >"$FAKE_FZF_DIR/args.$n"
pick="$(printf '%s\n' "$FAKE_FZF_PICKS" | sed -n "${n}p")"
[ -z "$pick" ] && exit 130
printf '%s\n' "$pick" | tr ';' '\n' | while IFS= read -r want; do
	grep -F -- "$want" "$FAKE_FZF_DIR/stdin.$n" | head -n 1
done
FAKE
chmod +x "$HOME/bin/fzf"
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME/fzfdir" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_FZF_PICKS=""
_shell::zsh::fzf::has_tty() { return 0; }

reset_fzf() {
	find "$FAKE_FZF_DIR" -maxdepth 1 -type f -delete
	rm -f "$FAKE_FZF_STATE"
}
fzf_calls() { cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0; }
# pick <picks> <command...> -> T_OUT / T_RC, the fzf log reset first
pick() {
	local picks="$1"
	shift
	reset_fzf
	T_OUT="$(FAKE_FZF_PICKS="$picks" "$@" 2>&1)"
	T_RC=$?
}
rc_is() { t_eq "$1" "$2" "$T_RC"; }

# ===================================================================================
# Source time costs nothing
# ===================================================================================
t_eq "source: no cache dir created" "no" "$([ -e "$SHELL_ZSH_CACHE_DIR" ] && echo yes || echo no)"
t_eq "source: widgets are opt-in" "0" "$SHELL_ZSH_WIDGETS"

# ===================================================================================
# No terminal: fail fast, fzf is never started
# ===================================================================================
_shell::zsh::fzf::has_tty() { return 1; }
reset_fzf
for fn in shell::zsh::history::search::fzf shell::zsh::process::kill::fzf shell::zsh::ssh::host::pick::fzf \
	shell::zsh::bookmark::goto::fzf shell::zsh::git::worktree::switch::fzf shell::zsh::manage::fzf; do
	t_rc "notty: $fn" "$RETURN_NOT_SUPPORTED" "$fn"
	t_has "notty: $fn says why" "interactive terminal" "$T_OUT"
done
t_eq "notty: fzf never ran" "0" "$(fzf_calls)"
_shell::zsh::fzf::has_tty() { return 0; }

# ===================================================================================
# History: parsing
# ===================================================================================
HF="$HOME/hist.plain"
printf '%s\n' 'ls -la' 'git status' 'ls -la' 'echo done' >"$HF"
t_eq "history file: newest first, each command once" \
	"4${tab}echo done${nl}3${tab}ls -la${nl}2${tab}git status" "$(_shell::zsh::history::from_file "$HF")"

XF="$HOME/hist.zsh"
printf '%s\n' ': 1700000000:0;ls -la' ': 1700000001:0;git status' ': 1700000002:0;echo one\' 'two' ': 1700000003:0;ls -la' >"$XF"
t_eq "history file: zsh extended format, continuation, dedupe" \
	"5${tab}ls -la${nl}3${tab}echo one ${SHELL_ZSH_NEWLINE_MARK} two${nl}2${tab}git status" "$(_shell::zsh::history::from_file "$XF")"

printf '%s\n' '#1700000000' 'make build' '#1700000005' 'make test' >"$HOME/hist.bash"
t_eq "history file: bash time stamps skipped" "4${tab}make test${nl}2${tab}make build" "$(_shell::zsh::history::from_file "$HOME/hist.bash")"

fc_out='   12  git push
   11* ls
   10  echo a
       b
    9  git push'
t_eq "history list: fc/history format, continuation, dedupe" \
	"12${tab}git push${nl}11${tab}ls${nl}10${tab}echo a ${SHELL_ZSH_NEWLINE_MARK} b" "$(printf '%s\n' "$fc_out" | _shell::zsh::history::awk list 0)"
t_eq "history list: oldest-first input is reversed" "2${tab}b${nl}1${tab}a" "$(printf '  1  a\n  2  b\n' | _shell::zsh::history::awk list 1)"
SHELL_ZSH_HISTORY_LIMIT=2
t_eq "history: limit" "3${tab}c${nl}2${tab}b" "$(printf '  1  a\n  2  b\n  3  c\n' | _shell::zsh::history::awk list 1)"
SHELL_ZSH_HISTORY_LIMIT=50000
t_eq "history: empty lines are ignored" "" "$(printf '\n\n' | _shell::zsh::history::awk file 1)"
t_eq "history mode: explicit file" "file" "$(_shell::zsh::history::mode "$HF")"
t_eq "history mode: non-interactive falls back to a file" "file" "$(_shell::zsh::history::mode "")"
t_rc "history candidates: no file anywhere" "$RETURN_NOT_FOUND" _shell::zsh::history::candidates file "" ""
t_has "history candidates: says what it looked for" "No history file" "$T_OUT"

# ----- the picker
pick "git status" shell::zsh::history::search::fzf --file "$HF"
rc_is "history pick: rc" 0
t_eq "history pick: prints the command only" "git status" "$T_OUT"
t_has "history pick: field 2 is shown" "--with-nth=2.." "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "history pick: tab delimiter" "--delimiter=$tab" "$(cat "$FAKE_FZF_DIR/args.1")"
pick "git status" shell::zsh::history::search::fzf --file "$HF" -q "gi"
t_has "history pick: query" "--query=gi" "$(cat "$FAKE_FZF_DIR/args.1")"
pick "echo one" shell::zsh::history::search::fzf --file "$XF"
t_eq "history pick: a flattened entry keeps its marker outside zsh memory" "echo one ${SHELL_ZSH_NEWLINE_MARK} two" "$T_OUT"
pick "" shell::zsh::history::search::fzf --file "$HF"
rc_is "history pick: ESC" "$RETURN_CANCELLED"
: >"$HOME/hist.empty"
pick "x" shell::zsh::history::search::fzf --file "$HOME/hist.empty"
rc_is "history pick: empty history" "$RETURN_EMPTY"
t_eq "history pick: empty never starts fzf" "0" "$(fzf_calls)"
t_rc "history: unknown option" "$RETURN_INVALID" shell::zsh::history::search::fzf --nope
t_rc "history: missing value" "$RETURN_INVALID" shell::zsh::history::search::fzf --query
if [ -z "${ZSH_VERSION-}" ]; then
	t_rc "history: --push needs zsh" "$RETURN_NOT_SUPPORTED" shell::zsh::history::search::fzf --push --file "$HF"
else
	pick "git status" shell::zsh::history::search::fzf --push --file "$HF"
	rc_is "history: --push in zsh" 0
	t_eq "history: --push prints nothing" "" "$T_OUT"
fi
t_rc "history: help" 0 shell::zsh::history::search::fzf --help

# ----- the file is parsed through the cache; --refresh and the TTL decide when it is read again
CF="$HOME/hist.cached"
printf 'one\n' >"$CF"
pick "one" shell::zsh::history::search::fzf --file "$CF"
t_eq "history cache: first read" "one" "$T_OUT"
printf 'one\ntwo\n' >"$CF"
pick "two" shell::zsh::history::search::fzf --file "$CF"
t_lacks "history cache: new line is not offered yet (served from cache)" "two" "$(cat "$FAKE_FZF_DIR/stdin.1")"
pick "two" shell::zsh::history::search::fzf --file "$CF" --refresh
t_eq "history cache: --refresh reads the file again" "two" "$T_OUT"

# ===================================================================================
# Cache layer
# ===================================================================================
SHELL_ZSH_CACHE_DIR="$HOME/cachetest"
: >"$HOME/prod.count"
prod() {
	echo x >>"$HOME/prod.count"
	printf 'v%s\n' "$(wc -l <"$HOME/prod.count" | tr -d ' ')"
}
t_eq "cache: miss generates" "v1" "$(_shell::zsh::cache::get "" k1 300 prod)"
t_eq "cache: dir is private" "700" "$(shell::fs::stat mode "$SHELL_ZSH_CACHE_DIR")"
t_eq "cache: file is private" "600" "$(shell::fs::stat mode "$(_shell::zsh::cache::file k1)")"
t_eq "cache: fresh entry is served, producer not run" "v1" "$(_shell::zsh::cache::get "" k1 300 prod)"
t_eq "cache: producer ran once" "1" "$(wc -l <"$HOME/prod.count" | tr -d ' ')"
t_eq "cache: stale entry is served at once" "v1" "$(_shell::zsh::cache::get "" k1 0 prod)"
n=0
while [ "$n" -lt 30 ] && [ "$(cat "$(_shell::zsh::cache::file k1)")" != "v2" ]; do
	sleep 0.1
	n=$((n + 1))
done
t_eq "cache: ...and refreshed in the background" "v2" "$(cat "$(_shell::zsh::cache::file k1)")"
t_eq "cache: --refresh is synchronous" "v3" "$(_shell::zsh::cache::get refresh k1 300 prod)"
t_eq "cache: no temp file left" "0" "$(find "$SHELL_ZSH_CACHE_DIR" -name '*.tmp.*' | wc -l | tr -d ' ')"
empty_prod() { :; }
t_rc "cache: an empty result is not stored" "$RETURN_EMPTY" _shell::zsh::cache::get "" k2 300 empty_prod
t_eq "cache: ...no file" "no" "$([ -e "$(_shell::zsh::cache::file k2)" ] && echo yes || echo no)"
bad_prod() { return 5; }
t_rc "cache: a failing producer's status is kept" 5 _shell::zsh::cache::get "" k3 300 bad_prod
t_eq "cache: key with odd characters is made safe" "$SHELL_ZSH_CACHE_DIR/a_b_c.cache" "$(_shell::zsh::cache::file 'a/b c')"

t_rc "clear: dry run" 0 shell::zsh::cache::clear -n
t_has "clear: dry run prints find" "find " "$T_OUT"
t_eq "clear: dry run keeps files" "yes" "$([ -e "$(_shell::zsh::cache::file k1)" ] && echo yes || echo no)"
mkdir -p "$SHELL_ZSH_CACHE_DIR" && : >"$SHELL_ZSH_CACHE_DIR/not-ours.txt"
t_rc "clear: removes the cache" 0 shell::zsh::cache::clear
t_eq "clear: cache files gone" "0" "$(find "$SHELL_ZSH_CACHE_DIR" -name '*.cache*' | wc -l | tr -d ' ')"
t_eq "clear: other files are kept" "yes" "$([ -e "$SHELL_ZSH_CACHE_DIR/not-ours.txt" ] && echo yes || echo no)"
t_rc "clear: again is fine" 0 shell::zsh::cache::clear
t_rc "clear: unknown option" "$RETURN_INVALID" shell::zsh::cache::clear --nope
t_rc "clear: help" 0 shell::zsh::cache::clear -h
keep="$SHELL_ZSH_CACHE_DIR"
SHELL_ZSH_CACHE_DIR="$HOME"
t_rc "clear: refuses \$HOME" "$RETURN_INVALID" shell::zsh::cache::clear
SHELL_ZSH_CACHE_DIR="/"
t_rc "clear: refuses /" "$RETURN_INVALID" shell::zsh::cache::clear
SHELL_ZSH_CACHE_DIR="$keep"
SHELL_ZSH_CACHE_DIR="$HOME/.shell-config/cache/zsh"

# ===================================================================================
# Processes (ps is a fake that prints $FAKE_PS_ROWS)
# ===================================================================================
cat >"$HOME/bin/ps" <<'FAKE'
#!/bin/sh
printf '%s\n' "$*" >>"$FAKE_PS_LOG"
printf '%s\n' "$FAKE_PS_ROWS"
FAKE
chmod +x "$HOME/bin/ps"
export FAKE_PS_LOG="$HOME/ps.log"
: >"$FAKE_PS_LOG"
export FAKE_PS_ROWS="  101 alice          1.5  0.3 /usr/bin/node server.js
    1 root           0.0  0.0 /sbin/launchd
 $$ alice          0.1  0.1 -zsh
  202 bob            9.9  2.0 /Applications/My App.app/Contents/MacOS/My App"
cand="$(_shell::zsh::process::candidates false)"
t_has "process: row for a process" "101${tab}    101 alice" "$cand"
t_has "process: the command keeps its spaces" "/Applications/My App.app/Contents/MacOS/My App" "$cand"
t_lacks "process: this shell is hidden" "$$${tab}" "$cand"
t_has "process: own processes only by default" "-U " "$(cat "$FAKE_PS_LOG")"
: >"$FAKE_PS_LOG"
_shell::zsh::process::candidates true >/dev/null
t_has "process: --all lists everyone" "-A " "$(cat "$FAKE_PS_LOG")"
t_has "process: reload string is one pipeline" "| awk -v me=" "$(_shell::zsh::process::pipeline false)"

pick "node server" shell::zsh::process::kill::fzf -n
rc_is "process dry run: rc" 0
t_has "process dry run: prints the kill command" "kill -s TERM 101" "$T_OUT"
t_has "process: multi-select" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "process: reload bound (fzf >= 0.35)" "--bind=ctrl-r:reload(" "$(cat "$FAKE_FZF_DIR/args.1")"
pick "node server;My App" shell::zsh::process::kill::fzf -n -s KILL
t_has "process dry run: several, own signal" "kill -s KILL 101 202" "$T_OUT"
pick "launchd" shell::zsh::process::kill::fzf -n
rc_is "process: pid 1 is never signalled" "$RETURN_EMPTY"
t_has "process: ...and says so" "Skipping pid 1" "$T_OUT"
pick "" shell::zsh::process::kill::fzf
rc_is "process: ESC" "$RETURN_CANCELLED"
t_rc "process: bad signal" "$RETURN_INVALID" shell::zsh::process::kill::fzf -s 'TERM;ls'
t_rc "process: unknown option" "$RETURN_INVALID" shell::zsh::process::kill::fzf --nope
export FAKE_PS_ROWS=""
pick "x" shell::zsh::process::kill::fzf
rc_is "process: nothing to pick" "$RETURN_EMPTY"
t_rc "process: help" 0 shell::zsh::process::kill::fzf --help

# Real signals. The processes are orphaned (reparented to init) so a stopped one is not a zombie.
SHELL_ZSH_KILL_GRACE=2
victim="$(sh -c 'sleep 60 >/dev/null 2>&1 & echo $!')"
export FAKE_PS_ROWS="$victim alice 0.0 0.0 sleepy-victim"
pick "sleepy-victim" shell::zsh::process::kill::fzf
rc_is "process kill: SIGTERM stops a normal process" 0
t_eq "process kill: it is gone" "gone" "$(kill -0 "$victim" 2>/dev/null && echo alive || echo gone)"

stubborn="$(sh -c '(trap "" TERM; exec sleep 60) >/dev/null 2>&1 & echo $!')"
export FAKE_PS_ROWS="$stubborn alice 0.0 0.0 stubborn-victim"
SHELL_ZSH_KILL_GRACE=0
reset_fzf
T_OUT="$(printf 'n\n' | FAKE_FZF_PICKS="stubborn-victim" shell::zsh::process::kill::fzf 2>&1)"
T_RC=$?
rc_is "process kill: survivor and SIGKILL refused -> failure" "$RETURN_FAILURE"
t_has "process kill: says it is still running" "Still running" "$T_OUT"
t_eq "process kill: ...and it is" "alive" "$(kill -0 "$stubborn" 2>/dev/null && echo alive || echo gone)"
reset_fzf
T_OUT="$(printf 'y\n' | FAKE_FZF_PICKS="stubborn-victim" shell::zsh::process::kill::fzf 2>&1)"
T_RC=$?
rc_is "process kill: SIGKILL after you agree" 0
t_eq "process kill: now it is gone" "gone" "$(kill -0 "$stubborn" 2>/dev/null && echo alive || echo gone)"
SHELL_ZSH_KILL_GRACE=3
export FAKE_PS_ROWS=""

# ===================================================================================
# ssh hosts
# ===================================================================================
mkdir -p "$HOME/.ssh"
SSHC="$HOME/.ssh/config"
cat >"$SSHC" <<'CONF'
Host web1 web-alias
    HostName 10.0.0.5
    User deploy

Host db1
    HostName 10.0.0.9
    Port 2222

Host *
    ServerAliveInterval 30
CONF
t_eq "ssh candidates: plain aliases only" "web1${nl}web-alias${nl}db1" "$(_shell::zsh::ssh::candidates "")"
t_eq "ssh candidates: another file" "web1${nl}web-alias${nl}db1" "$(_shell::zsh::ssh::candidates "$SSHC")"
t_eq "ssh block: the Host block of an alias" "Host db1${nl}    HostName 10.0.0.9${nl}    Port 2222" "$(awk -v host=db1 -f "$SHELL_ZSH_SSH_BLOCK_AWK" "$SSHC")"
t_has "ssh block: found by its second alias" "HostName 10.0.0.5" "$(awk -v host=web-alias -f "$SHELL_ZSH_SSH_BLOCK_AWK" "$SSHC")"
t_eq "ssh block: unknown alias prints nothing" "" "$(awk -v host=nope -f "$SHELL_ZSH_SSH_BLOCK_AWK" "$SSHC")"
pick "db1" shell::zsh::ssh::host::pick::fzf
rc_is "ssh pick: rc" 0
t_eq "ssh pick: prints the alias" "db1" "$T_OUT"
t_has "ssh pick: preview shows the config block" "-f '$SHELL_ZSH_SSH_BLOCK_AWK' '$SSHC'" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "ssh pick: preview is {}-based" "-v host={}" "$(cat "$FAKE_FZF_DIR/args.1")"
pick "db1" shell::zsh::ssh::host::pick::fzf --connect -n
t_has "ssh --connect -n: delegates to shell::ssh::connect" "db1" "$T_OUT"
t_has "ssh --connect -n: it is an ssh command" "ssh" "$T_OUT"
pick "" shell::zsh::ssh::host::pick::fzf
rc_is "ssh pick: ESC" "$RETURN_CANCELLED"
pick "x" shell::zsh::ssh::host::pick::fzf -F "$HOME/no-such-config"
rc_is "ssh pick: missing config" "$RETURN_NOT_FOUND"
: >"$HOME/empty.conf"
pick "x" shell::zsh::ssh::host::pick::fzf -F "$HOME/empty.conf"
rc_is "ssh pick: no alias" "$RETURN_EMPTY"
t_rc "ssh pick: unknown option" "$RETURN_INVALID" shell::zsh::ssh::host::pick::fzf --nope
t_rc "ssh pick: help" 0 shell::zsh::ssh::host::pick::fzf -h

# ===================================================================================
# Bookmarks
# ===================================================================================
mkdir -p "$HOME/proj/alpha" "$HOME/proj/be|ta dir" "$(dirname "$SHELL_BOOKMARK_FILE")"
printf '%s\n' "$HOME/proj/alpha|alpha" "$HOME/proj/be|ta dir|beta" >"$SHELL_BOOKMARK_FILE"
t_eq "bookmark candidates: name, directory, row" \
	"alpha${tab}$HOME/proj/alpha${tab}alpha                $HOME/proj/alpha${nl}beta${tab}$HOME/proj/be|ta dir${tab}beta                 $HOME/proj/be|ta dir" \
	"$(_shell::zsh::bookmark::candidates)"
pick "beta" shell::zsh::bookmark::goto::fzf --print
t_eq "bookmark --print: a directory with | and a space survives" "$HOME/proj/be|ta dir" "$T_OUT"
pick "alpha" shell::zsh::bookmark::goto::fzf -n
t_has "bookmark dry run: prints cd" "cd $HOME/proj/alpha" "$T_OUT"
t_has "bookmark: preview lists the directory" "{2}" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "bookmark: rows are field 3" "--with-nth=3" "$(cat "$FAKE_FZF_DIR/args.1")"
cd "$HOME" || exit 1
reset_fzf
FAKE_FZF_PICKS="alpha" shell::zsh::bookmark::goto::fzf >/dev/null 2>&1
t_eq "bookmark: goes there in the current shell" "$HOME/proj/alpha" "$(pwd -P)"
cd "$HOME" || exit 1
pick "" shell::zsh::bookmark::goto::fzf
rc_is "bookmark: ESC" "$RETURN_CANCELLED"
rm -f "$SHELL_BOOKMARK_FILE"
pick "x" shell::zsh::bookmark::goto::fzf
rc_is "bookmark: none saved" "$RETURN_EMPTY"
t_rc "bookmark: unknown option" "$RETURN_INVALID" shell::zsh::bookmark::goto::fzf --nope
t_rc "bookmark: help" 0 shell::zsh::bookmark::goto::fzf --help

# ===================================================================================
# Git worktrees
# ===================================================================================
G="$HOME/wt-repo"
mkdir -p "$G" && cd "$G" || exit 1
git init -q . >/dev/null 2>&1
git -c user.name=t -c user.email=t@t commit -q --allow-empty -m first >/dev/null 2>&1
git worktree add -q "$HOME/wt-feature dir" -b feature/x >/dev/null 2>&1
git worktree add -q --detach "$HOME/wt-detached" >/dev/null 2>&1
cand="$(_shell::zsh::worktree::candidates)"
t_eq "worktree: three entries" "3" "$(printf '%s\n' "$cand" | wc -l | tr -d ' ')"
t_has "worktree: path is the first field" "$HOME/wt-feature dir${tab}" "$cand"
t_has "worktree: branch shown without refs/heads" "feature/x" "$cand"
t_has "worktree: detached" "(detached)" "$cand"
t_has "worktree: the current one is marked" "*" "$(printf '%s\n' "$cand" | grep "${tab}\*")"
pick "feature/x" shell::zsh::git::worktree::switch::fzf --print
t_eq "worktree --print: a path with a space" "$HOME/wt-feature dir" "$T_OUT"
t_has "worktree: preview is git log of the path" "git -C {1} log" "$(cat "$FAKE_FZF_DIR/args.1")"
pick "feature/x" shell::zsh::git::worktree::switch::fzf -n
t_has "worktree dry run: prints cd" "cd " "$T_OUT"
t_eq "worktree dry run: did not move" "$G" "$(pwd -P)"
reset_fzf
FAKE_FZF_PICKS="feature/x" shell::zsh::git::worktree::switch::fzf >/dev/null 2>&1
t_eq "worktree: moves in the current shell" "$HOME/wt-feature dir" "$(pwd -P)"
cd "$G" || exit 1
pick "" shell::zsh::git::worktree::switch::fzf
rc_is "worktree: ESC" "$RETURN_CANCELLED"
rm -rf "$HOME/wt-detached"
pick "(detached)" shell::zsh::git::worktree::switch::fzf
rc_is "worktree: a directory that is gone" "$RETURN_NOT_FOUND"
t_has "worktree: ...points at prune" "prune" "$T_OUT"
cd "$HOME" || exit 1
pick "x" shell::zsh::git::worktree::switch::fzf
rc_is "worktree: not a repository" "$RETURN_NOT_FOUND"
t_eq "worktree: not a repository never starts fzf" "0" "$(fzf_calls)"
t_rc "worktree: unknown option" "$RETURN_INVALID" shell::zsh::git::worktree::switch::fzf --nope
t_rc "worktree: help" 0 shell::zsh::git::worktree::switch::fzf --help

# ===================================================================================
# Hub menu
# ===================================================================================
loop_log="$HOME/loop.log"
shell::fzf::loop() {
	printf '%s\n' "$@" >"$loop_log"
	cat >"$HOME/loop.stdin"
}
t_rc "manage: opens a loop" 0 shell::zsh::manage::fzf
t_has "manage: with a back entry" "--back" "$(cat "$loop_log")"
t_has "manage: dispatches to the private function" "_shell::zsh::manage::dispatch" "$(cat "$loop_log")"
t_has "manage: lists install" "install" "$(cat "$HOME/loop.stdin")"
t_has "manage: lists the worktree switcher" "worktree" "$(cat "$HOME/loop.stdin")"
unset -f shell::fzf::loop
. "$SHELL_TEST_ROOT/src/core/fzf.sh"
shell::zsh::process::kill::fzf() { return "$RETURN_CANCELLED"; }
t_rc "manage dispatch: a cancelled picker is not an error" 0 _shell::zsh::manage::dispatch "Kill processes${tab}kill"
shell::zsh::ssh::host::pick::fzf() { return "$RETURN_EMPTY"; }
t_rc "manage dispatch: nothing to show is not an error" 0 _shell::zsh::manage::dispatch "Pick${tab}ssh"
shell::zsh::bookmark::goto::fzf() { return "$RETURN_NOT_FOUND"; }
t_rc "manage dispatch: a real failure is reported" "$RETURN_NOT_FOUND" _shell::zsh::manage::dispatch "Go${tab}bookmark"
t_rc "manage dispatch: unknown key" 0 _shell::zsh::manage::dispatch "?${tab}nope"
t_has "manage dispatch: unknown key warns" "Unknown entry" "$T_OUT"
t_rc "manage: help" 0 shell::zsh::manage::fzf --help

# ===================================================================================
# Widgets (zsh only, opt-in)
# ===================================================================================
t_rc "widget enable: help" 0 shell::zsh::widget::enable --help
t_rc "widget enable: unknown option" "$RETURN_INVALID" shell::zsh::widget::enable --nope
if [ -z "${ZSH_VERSION-}" ]; then
	t_rc "widget enable: needs zsh" "$RETURN_NOT_SUPPORTED" shell::zsh::widget::enable
else
	t_rc "widget enable: needs an interactive zsh" "$RETURN_NOT_SUPPORTED" shell::zsh::widget::enable
	t_rc "widget enable: dry run" 0 shell::zsh::widget::enable -n
	t_has "widget enable: dry run names a widget" "shell-history" "$T_OUT"
	t_has "widget enable: dry run names the key rule" "only if" "$T_OUT"
fi
LBUFFER="git checkout "
_shell::zsh::widget::insert "feature x"
t_eq "widget insert: a host is inserted as it is" "git checkout feature x " "$LBUFFER"
LBUFFER="cd "
_shell::zsh::widget::insert "/tmp/it's here" quote
t_eq "widget insert: a path is quoted as one word" "cd '/tmp/it'\\''s here' " "$LBUFFER"
LBUFFER="x"
_shell::zsh::widget::insert ""
t_eq "widget insert: nothing picked, line untouched" "x" "$LBUFFER"
t_eq "widget pick: the picker's output" "hello" "$(_shell::zsh::widget::pick printf hello)"
for w in shell-history shell-ssh-host shell-worktree shell-bookmark; do
	t_has "widget: $w is defined as a function target" "$w" "$(sed -n 's/.*"\(shell-[a-z-]*\)|.*/\1/p' "$SHELL_TEST_ROOT/src/lib/zsh_widget.sh")"
done

# A real interactive zsh: opt-in registers and binds free keys, and never takes a bound one.
if command -v zsh >/dev/null 2>&1; then
	zout="$(SHELL_ZSH_WIDGETS=1 SHELL_ZSH_KEY_SSH='^R' SHELL_DIR="$SHELL_TEST_ROOT" zsh -f -i -c '
		. "$SHELL_DIR/src/shell.sh" >/dev/null 2>&1
		bindkey "^Xh"; bindkey "^Xw"; bindkey "^Xb"; bindkey "^R"
		print -r -- "widgets: ${(k)widgets[(I)shell-*]}"' 2>&1)"
	t_has "widgets on: history key bound" '"^Xh" shell-history' "$zout"
	t_has "widgets on: worktree key bound" '"^Xw" shell-worktree' "$zout"
	t_has "widgets on: bookmark key bound" '"^Xb" shell-bookmark' "$zout"
	t_has "widgets on: a bound key is left alone" '"^R" history-incremental-search-backward' "$zout"
	t_lacks "widgets on: ...and not replaced" '"^R" _shell::zsh::widget' "$zout"
	zout="$(SHELL_DIR="$SHELL_TEST_ROOT" zsh -f -i -c '
		. "$SHELL_DIR/src/shell.sh" >/dev/null 2>&1
		bindkey "^Xh"' 2>&1)"
	t_has "widgets off by default: key stays free" "undefined-key" "$zout"
fi

cd "$HOME" || exit 1
t_done
