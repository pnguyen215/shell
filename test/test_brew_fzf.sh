#!/usr/bin/env bash
# shell::brew::*::fzf, shell::brew::manage, shell::brew::unused*, shell::brew::tidy and
# shell::brew::size (src/lib/brew_fzf.sh): what is listed for the user, what a pick turns into, what
# is asked before anything is removed, and how "unused" is decided.
#
# brew and fzf are both fakes. The fake brew logs every call to $FAKE_BREW_LOG and answers from
# files in $FAKE_BREW_DIR. The fake fzf logs the candidate lines (stdin.N) and its arguments (args.N)
# and answers the Nth call with line N of $FAKE_FZF_PICKS: a pick is matched as text against the
# candidate lines and the whole matching line is printed, like fzf; `a;b` picks two lines; an empty
# line is ESC. Text prompts (y/n) read the standard input of the function under test.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

mkdir "$HOME/bin" "$HOME/fake"
cat >"$HOME/bin/brew" <<'FAKE'
#!/bin/sh
printf '%s\n' "$*" >>"$FAKE_BREW_LOG"
key="$(printf '%s' "$*" | tr ' /' '__')"
[ -f "$FAKE_BREW_DIR/$key" ] && cat "$FAKE_BREW_DIR/$key"
rc=0
[ -f "$FAKE_BREW_DIR/$key.rc" ] && rc="$(cat "$FAKE_BREW_DIR/$key.rc")"
exit "$rc"
FAKE
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
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
chmod +x "$HOME/bin/brew" "$HOME/bin/fzf"
export PATH="$HOME/bin:$PATH" FAKE_BREW_DIR="$HOME/fake" FAKE_BREW_LOG="$HOME/brew.log"
export FAKE_FZF_DIR="$HOME/fzfdir" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_FZF_PICKS=""
mkdir "$FAKE_FZF_DIR"

nl='
'
B="$SHELL_FZF_BACK_LABEL"

# fb "<brew args>" "<what brew prints>"
fb() { printf '%s\n' "$2" >"$FAKE_BREW_DIR/$(printf '%s' "$1" | tr ' /' '__')"; }
reset_state() {
	: >"$FAKE_BREW_LOG"
	find "$FAKE_FZF_DIR" -maxdepth 1 \( -name 'stdin.*' -o -name 'args.*' \) -delete
	rm -f "$FAKE_FZF_STATE"
}
# run <picks> <stdin> <command...>  -> combined output; the brew / fzf logs are left for the asserts
run() {
	local picks="$1" input="$2"
	shift 2
	reset_state
	printf '%s' "$input" | FAKE_FZF_PICKS="$picks" "$@" 2>&1
}
log() { cat "$FAKE_BREW_LOG"; }
# calls of one sort in the brew log
logged() { grep -c -- "$1" "$FAKE_BREW_LOG"; }
fzf_calls() { cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0; }
rc_of() {
	"$@" >/dev/null 2>&1
	echo "$?"
}

# What brew "has installed".
fb "list --formula --versions" "git 2.45.0
jq 1.7.1 1.6
openssl@3 3.3.1
wget 1.24.5"
fb "list --formula --pinned" "wget"
fb "list --formula -1" "git
jq
openssl@3
wget"
fb "formulae" "git
jq
ripgrep
wget"
fb "casks" "firefox
iterm2
vlc"
fb "list --cask -1" "firefox"
fb "list --cask --versions" "firefox 128.0
vlc 3.0.21"
fb "list --cask --pinned" ""
: >"$FAKE_BREW_LOG"

# --- shell::brew::fzf::pick ----------------------------------------------------------------------
out="$(printf 'git  2.45\njq  1.7\n' | FAKE_FZF_PICKS="jq" shell::brew::fzf::pick 2>&1)"
t_eq "pick: prints the first word of the chosen row" "jq" "$out"
reset_state
out="$(printf 'git  2.45\njq  1.7\nwget  1\n' | FAKE_FZF_PICKS="git;wget" shell::brew::fzf::pick -m 2>&1)"
t_eq "pick -m: several rows, one name per line" "git${nl}wget" "$out"
t_has "pick -m: asks fzf for --multi" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "pick -m: ...and Ctrl-A to mark all" "--bind=ctrl-a:select-all" "$(cat "$FAKE_FZF_DIR/args.1")"
reset_state
printf 'a\n' | FAKE_FZF_PICKS="a" shell::brew::fzf::pick >/dev/null 2>&1
t_lacks "pick: single choice has no --multi" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
reset_state
printf 'a\n' | FAKE_FZF_PICKS="a" shell::brew::fzf::pick -p "Pick: " -P "info {1}" -H "a header" >/dev/null 2>&1
t_has "pick: the prompt" "--prompt=Pick: " "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "pick: the preview" "--preview=info {1}" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "pick: the header" "--header=a header" "$(cat "$FAKE_FZF_DIR/args.1")"
reset_state
printf '' | FAKE_FZF_PICKS="a" shell::brew::fzf::pick >/dev/null 2>&1
t_eq "pick: no rows is RETURN_EMPTY" "8" "$?"
t_eq "pick: ...and fzf is not even started" "0" "$(fzf_calls)"
reset_state
printf 'a\n' | FAKE_FZF_PICKS="" shell::brew::fzf::pick >/dev/null 2>&1
t_eq "pick: ESC is RETURN_CANCELLED" "9" "$?"
printf 'a\n' | shell::brew::fzf::pick --bogus >/dev/null 2>&1
t_eq "pick: unknown option" "2" "$?"
printf 'a\n' | shell::brew::fzf::pick -p >/dev/null 2>&1
t_eq "pick: an option without a value" "2" "$?"

# --- preview, rows, sizes -----------------------------------------------------------------------------
pv="$(shell::brew::fzf::preview)"
t_has "preview: runs brew info on the focused row" " info {1}" "$pv"
t_has "preview: ...with the brew that was found, quoted" "'$HOME/bin/brew'" "$pv"
t_has "preview: --cask" " info --cask {1}" "$(shell::brew::fzf::preview --cask)"
t_eq "preview: without Homebrew" "3" "$(
	shell::homebrew::path() { return 3; }
	shell::brew::fzf::preview >/dev/null 2>&1
	echo $?
)"
rows="$(shell::brew::fzf::rows::installed)"
t_eq "rows: one per package" "4" "$(printf '%s\n' "$rows" | wc -l | tr -d ' ')"
t_has "rows: name and version" "git" "$(printf '%s\n' "$rows" | grep '^git ')"
t_has "rows: more than one version is flagged" "1.7.1+1" "$rows"
t_has "rows: a pinned package is marked" "[pinned]" "$(printf '%s\n' "$rows" | grep '^wget ')"
t_lacks "rows: ...and only that one" "[pinned]" "$(printf '%s\n' "$rows" | grep '^git ')"
t_has "rows: casks" "firefox" "$(shell::brew::fzf::rows::installed --cask)"
t_eq "rows: first word is the name" "git" "$(printf '%s\n' "$rows" | head -n 1 | awk '{ print $1 }')"
out="$(printf 'a\tx\t512\tw\nb\tx\t2048\tw\nc\tx\t3145728\tw\n' | shell::brew::size::format)"
t_eq "size::format: kilobytes" "512K" "$(printf '%s\n' "$out" | sed -n 1p | cut -f3)"
t_eq "size::format: megabytes" "2.0M" "$(printf '%s\n' "$out" | sed -n 2p | cut -f3)"
t_eq "size::format: gigabytes" "3.0G" "$(printf '%s\n' "$out" | sed -n 3p | cut -f3)"
t_eq "size::format: other columns untouched" "c	x	3.0G	w" "$(printf '%s\n' "$out" | sed -n 3p)"

# --- help, unknown options and "no Homebrew" for every interactive function ---------------------------
for fn in install::fzf uninstall::fzf upgrade::fzf info::fzf pin::fzf unpin::fzf untap::fzf services::fzf \
	size unused unused::fzf tidy manage; do
	reset_state
	out="$(FAKE_FZF_PICKS="" "shell::brew::$fn" -h 2>&1)"
	t_has "$fn -h: shows its usage" "USAGE: shell::brew::$fn" "$out"
	t_eq "$fn -h: starts neither brew nor fzf" "0" "$(($(wc -l <"$FAKE_BREW_LOG") + $(fzf_calls)))"
	t_eq "$fn --help: returns 0" "0" "$(rc_of "shell::brew::$fn" --help)"
	t_eq "$fn: an unknown option is invalid" "2" "$(rc_of "shell::brew::$fn" --bogus)"
done
for fn in install::fzf uninstall::fzf upgrade::fzf info::fzf pin::fzf unpin::fzf untap::fzf services::fzf \
	size unused unused::fzf tidy manage; do
	reset_state
	out="$(
		shell::homebrew::path() { return 3; }
		shell::brew::$fn 2>&1
		echo "rc=$?"
	)"
	t_has "$fn: without Homebrew, rc 3" "rc=3" "$out"
	t_has "$fn: ...and how to install it" "shell::homebrew::install" "$out"
	t_eq "$fn: ...without opening fzf" "0" "$(fzf_calls)"
done

# --- install::fzf -------------------------------------------------------------------------------------------
out="$(run "jq;ripgrep" "" shell::brew::install::fzf)"
t_eq "install::fzf: installs what was marked" "install jq ripgrep" "$(grep '^install' "$FAKE_BREW_LOG")"
t_has "install::fzf: the list is brew formulae" "ripgrep" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "install::fzf: installed packages are tagged" "git  [installed]" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_lacks "install::fzf: ...and the others are not" "ripgrep  [installed]" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "install::fzf: marking several" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "install::fzf: with a preview of brew info" "info {1}" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "install::fzf: and a hint on the keys" "Tab: mark" "$(cat "$FAKE_FZF_DIR/args.1")"
run "" "" shell::brew::install::fzf >/dev/null
t_eq "install::fzf: ESC installs nothing" "0" "$(logged '^install')"
t_eq "install::fzf: ...and is not an error" "0" "$(rc_of shell::brew::install::fzf)"
out="$(run "vlc" "" shell::brew::install::fzf --cask)"
t_eq "install::fzf --cask: installs casks" "install --cask vlc" "$(grep '^install' "$FAKE_BREW_LOG")"
t_has "install::fzf --cask: from the cask list" "iterm2" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "install::fzf --cask: previews casks" "info --cask {1}" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "install::fzf --cask: tags installed casks" "firefox  [installed]" "$(cat "$FAKE_FZF_DIR/stdin.1")"
out="$(run "jq" "" shell::brew::install::fzf -n)"
t_eq "install::fzf -n: nothing is installed" "0" "$(logged '^install')"
t_has "install::fzf -n: the command is printed" "brew install jq" "$out"
fb "formulae" ""
out="$(run "jq" "" shell::brew::install::fzf)"
t_has "install::fzf: an empty catalogue says to update" "shell::brew::update" "$out"
t_eq "install::fzf: ...and is not an error" "0" "$(rc_of shell::brew::install::fzf)"
fb "formulae" "git
jq
ripgrep
wget"

# --- uninstall::fzf -----------------------------------------------------------------------------------------
fb "uses --installed git" ""
fb "uses --installed jq" ""
fb "uses --installed wget" ""
fb "uses --installed openssl@3" "curl
wget"
out="$(run "jq" "y${nl}" shell::brew::uninstall::fzf)"
t_eq "uninstall::fzf: asks, then uninstalls" "uninstall jq" "$(grep '^uninstall' "$FAKE_BREW_LOG")"
t_has "uninstall::fzf: the question names the package" "Uninstall jq?" "$out"
t_has "uninstall::fzf: marking several" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "uninstall::fzf: the list is the installed packages" "openssl@3" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "uninstall::fzf: pinned ones are marked" "[pinned]" "$(cat "$FAKE_FZF_DIR/stdin.1")"
run "jq" "n${nl}" shell::brew::uninstall::fzf >/dev/null
t_eq "uninstall::fzf: 'n' removes nothing" "0" "$(logged '^uninstall')"
out="$(run "jq" "n${nl}" shell::brew::uninstall::fzf)"
t_has "uninstall::fzf: ...and says it aborted" "Aborted" "$out"
run "jq" "" shell::brew::uninstall::fzf >/dev/null
t_eq "uninstall::fzf: end of input removes nothing" "0" "$(logged '^uninstall')"
out="$(run "jq;git" "" shell::brew::uninstall::fzf --yes)"
t_eq "uninstall::fzf --yes: does not ask" "uninstall jq git" "$(grep '^uninstall' "$FAKE_BREW_LOG")"
run "" "" shell::brew::uninstall::fzf --yes >/dev/null
t_eq "uninstall::fzf: ESC removes nothing" "0" "$(logged '^uninstall')"
out="$(run "openssl@3" "y${nl}" shell::brew::uninstall::fzf)"
t_eq "uninstall::fzf: a package another one needs is not removed" "0" "$(logged '^uninstall')"
t_has "uninstall::fzf: ...and who needs it is said" "Skipping openssl@3: still needed by curl wget" "$out"
t_has "uninstall::fzf: ...with nothing left to do" "Nothing to uninstall" "$out"
out="$(run "openssl@3;jq" "y${nl}" shell::brew::uninstall::fzf)"
t_eq "uninstall::fzf: the others of the pick still go" "uninstall jq" "$(grep '^uninstall' "$FAKE_BREW_LOG")"
fb "uses --installed openssl@3" "wget"
out="$(run "openssl@3;wget" "y${nl}" shell::brew::uninstall::fzf)"
t_eq "uninstall::fzf: a dependent that is removed in the same go is no obstacle" "uninstall openssl@3 wget" "$(grep '^uninstall' "$FAKE_BREW_LOG")"
fb "uses --installed openssl@3" "curl
wget"
out="$(run "jq" "" shell::brew::uninstall::fzf -n -y)"
t_eq "uninstall::fzf -n: nothing is removed" "0" "$(logged '^uninstall')"
t_has "uninstall::fzf -n: the command is printed" "brew uninstall jq" "$out"
out="$(run "firefox" "y${nl}" shell::brew::uninstall::fzf --cask)"
t_eq "uninstall::fzf --cask" "uninstall --cask firefox" "$(grep '^uninstall' "$FAKE_BREW_LOG")"
t_eq "uninstall::fzf --cask: casks are not checked for dependents" "0" "$(logged '^uses')"
t_has "uninstall::fzf --cask: the list is the casks" "vlc" "$(cat "$FAKE_FZF_DIR/stdin.1")"
out="$(run "firefox" "y${nl}" shell::brew::uninstall::fzf --zap)"
t_eq "uninstall::fzf --zap: implies --cask" "uninstall --cask --zap firefox" "$(grep '^uninstall' "$FAKE_BREW_LOG")"
t_has "uninstall::fzf --zap: the question warns about the data" "DELETE their data" "$out"
fb "list --formula --versions" ""
out="$(run "" "" shell::brew::uninstall::fzf)"
t_has "uninstall::fzf: with nothing installed" "Nothing is installed" "$out"
fb "list --formula --versions" "git 2.45.0
jq 1.7.1 1.6
openssl@3 3.3.1
wget 1.24.5"

# --- upgrade::fzf -------------------------------------------------------------------------------------------
fb "outdated --verbose" "git (2.44.0) < 2.45.0
jq (1.6) < 1.7.1
firefox (127.0) != 128.0"
out="$(run "git;firefox" "" shell::brew::upgrade::fzf)"
t_eq "upgrade::fzf: upgrades what was marked" "upgrade git firefox" "$(grep '^upgrade' "$FAKE_BREW_LOG")"
t_has "upgrade::fzf: the list shows the new version" "git (2.44.0) < 2.45.0" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "upgrade::fzf: marking several" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "upgrade::fzf: Ctrl-A marks all" "ctrl-a:select-all" "$(cat "$FAKE_FZF_DIR/args.1")"
run "" "" shell::brew::upgrade::fzf >/dev/null
t_eq "upgrade::fzf: ESC upgrades nothing" "0" "$(logged '^upgrade')"
out="$(run "git" "" shell::brew::upgrade::fzf -n)"
t_eq "upgrade::fzf -n: nothing is upgraded" "0" "$(logged '^upgrade')"
t_has "upgrade::fzf -n: the command is printed" "brew upgrade git" "$out"
fb "outdated --verbose --cask --greedy" "iterm2 (3.4) != latest"
out="$(run "iterm2" "" shell::brew::upgrade::fzf --cask --greedy)"
t_eq "upgrade::fzf --cask --greedy: asks brew for exactly that" "outdated --verbose --cask --greedy" "$(grep '^outdated' "$FAKE_BREW_LOG")"
t_eq "upgrade::fzf --cask --greedy: and upgrades with the same flags" "upgrade --cask --greedy iterm2" "$(grep '^upgrade' "$FAKE_BREW_LOG")"
fb "outdated --verbose --formula" ""
out="$(run "" "" shell::brew::upgrade::fzf --formula)"
t_has "upgrade::fzf: nothing outdated" "Everything is up to date" "$out"
t_eq "upgrade::fzf: ...without opening fzf" "0" "$(fzf_calls)"

# --- info::fzf (a loop) -------------------------------------------------------------------------------------
out="$(run "git${nl}jq" "" shell::brew::info::fzf)"
t_eq "info::fzf: shows each package that was picked, then leaves on ESC" "info git${nl}info jq" "$(grep '^info' "$FAKE_BREW_LOG")"
t_eq "info::fzf: the list came back after each pick" "3" "$(fzf_calls)"
t_lacks "info::fzf: picking one package, not several" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
out="$(run "firefox" "" shell::brew::info::fzf --cask)"
t_eq "info::fzf --cask" "info --cask firefox" "$(grep '^info' "$FAKE_BREW_LOG")"

# --- pin::fzf / unpin::fzf ----------------------------------------------------------------------------------
out="$(run "git;jq" "" shell::brew::pin::fzf)"
t_eq "pin::fzf: pins what was marked" "pin git jq" "$(grep '^pin' "$FAKE_BREW_LOG")"
t_lacks "pin::fzf: an already pinned package is not offered" "wget" "$(cat "$FAKE_FZF_DIR/stdin.1")"
run "git" "" shell::brew::pin::fzf -n >/dev/null
t_eq "pin::fzf -n: nothing is pinned" "0" "$(logged '^pin')"
run "firefox" "" shell::brew::pin::fzf --cask >/dev/null
t_eq "pin::fzf --cask" "pin --cask firefox" "$(grep '^pin' "$FAKE_BREW_LOG")"
run "" "" shell::brew::pin::fzf >/dev/null
t_eq "pin::fzf: ESC pins nothing" "0" "$(logged '^pin')"
out="$(run "wget" "" shell::brew::unpin::fzf)"
t_eq "unpin::fzf: unpins" "unpin wget" "$(grep '^unpin' "$FAKE_BREW_LOG")"
t_eq "unpin::fzf: only the pinned packages are offered" "wget" "$(cat "$FAKE_FZF_DIR/stdin.1")"
fb "list --formula --pinned" ""
out="$(run "" "" shell::brew::unpin::fzf)"
t_has "unpin::fzf: nothing is pinned" "Nothing is pinned" "$out"
t_eq "unpin::fzf: ...and fzf is not opened" "0" "$(fzf_calls)"
fb "list --formula --pinned" "wget"

# --- untap::fzf -----------------------------------------------------------------------------------------------
fb "tap" "homebrew/cask
homebrew/core
acme/tools
homebrew/cask-versions"
out="$(run "acme/tools" "y${nl}" shell::brew::untap::fzf)"
t_eq "untap::fzf: asks, then untaps" "untap acme/tools" "$(grep '^untap' "$FAKE_BREW_LOG")"
t_lacks "untap::fzf: homebrew/core is never offered" "homebrew/core" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_lacks "untap::fzf: nor homebrew/cask" "homebrew/cask$" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "untap::fzf: other homebrew taps are" "homebrew/cask-versions" "$(cat "$FAKE_FZF_DIR/stdin.1")"
run "acme/tools" "n${nl}" shell::brew::untap::fzf >/dev/null
t_eq "untap::fzf: 'n' untaps nothing" "0" "$(logged '^untap')"
out="$(run "acme/tools;homebrew/cask-versions" "" shell::brew::untap::fzf -y -f)"
t_eq "untap::fzf -y -f" "untap --force acme/tools homebrew/cask-versions" "$(grep '^untap' "$FAKE_BREW_LOG")"
run "acme/tools" "" shell::brew::untap::fzf -y -n >/dev/null
t_eq "untap::fzf -n: nothing is untapped" "0" "$(logged '^untap')"
fb "tap" "homebrew/cask
homebrew/core"
out="$(run "" "" shell::brew::untap::fzf)"
t_has "untap::fzf: no removable taps" "No removable taps" "$out"
fb "tap" "acme/tools"

# --- services::fzf --------------------------------------------------------------------------------------------
fb "services list" "Name          Status  User File
postgresql@16 started me   /x/postgresql.plist
redis         none"
out="$(run "postgresql@16${nl}restart${nl}" "" shell::brew::services::fzf)"
t_eq "services::fzf: pick a service, then an action" "services restart postgresql@16" "$(grep '^services restart' "$FAKE_BREW_LOG")"
t_lacks "services::fzf: the header row is not a service" "Status" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "services::fzf: the actions are offered" "restart" "$(cat "$FAKE_FZF_DIR/stdin.2")"
t_has "services::fzf: ...with a way back" "$B" "$(cat "$FAKE_FZF_DIR/stdin.2")"
t_eq "services::fzf: the services come back after the action" "3" "$(fzf_calls)"
out="$(run "redis${nl}${B}${nl}redis${nl}stop" "" shell::brew::services::fzf)"
t_eq "services::fzf: Back returns to the services, nothing run" "services stop redis" "$(grep -E '^services (stop|start|restart|run|kill|info)' "$FAKE_BREW_LOG")"
run "redis${nl}start" "" shell::brew::services::fzf -n >/dev/null
t_eq "services::fzf -n: nothing is started" "0" "$(logged '^services start')"
run "" "" shell::brew::services::fzf >/dev/null
t_eq "services::fzf: ESC leaves" "0" "$(rc_of shell::brew::services::fzf)"
fb "services list" "Name Status User File"
out="$(run "" "" shell::brew::services::fzf)"
t_has "services::fzf: no services" "No services found" "$out"

# --- size ---------------------------------------------------------------------------------------------------------
mkdir -p "$HOME/cel/big" "$HOME/cel/mid" "$HOME/cel/small" "$HOME/casks/app"
dd if=/dev/zero of="$HOME/cel/big/f" bs=1024 count=3000 2>/dev/null
dd if=/dev/zero of="$HOME/cel/mid/f" bs=1024 count=1200 2>/dev/null
dd if=/dev/zero of="$HOME/cel/small/f" bs=1024 count=8 2>/dev/null
dd if=/dev/zero of="$HOME/casks/app/f" bs=1024 count=500 2>/dev/null
fb "--cellar" "$HOME/cel"
fb "--caskroom" "$HOME/casks"
out="$(shell::brew::size 2>&1)"
t_eq "size: biggest first" "big${nl}mid${nl}small" "$(printf '%s\n' "$out" | awk '{ print $2 }')"
t_has "size: a human size" "M" "$(printf '%s\n' "$out" | head -n 1)"
t_eq "size: a count limits the list" "big${nl}mid" "$(shell::brew::size 2 2>&1 | awk '{ print $2 }')"
t_eq "size --cask measures the Caskroom" "app" "$(shell::brew::size --cask 2>&1 | awk '{ print $2 }')"
t_eq "size: a count of 0" "2" "$(rc_of shell::brew::size 0)"
t_eq "size: a count that is not a number" "2" "$(rc_of shell::brew::size abc)"
t_eq "size: two counts" "2" "$(rc_of shell::brew::size 1 2)"
fb "--cellar" "$HOME/nowhere"
t_has "size: nothing installed" "Nothing is installed" "$(shell::brew::size 2>&1)"
fb "--cellar" "$HOME/cel"

# --- unused: orphans and stale formulae ------------------------------------------------------------------------
# Cellar: foo (old, a command nobody ran), bar (old, but its command is in the history), fresh (touched
# recently), lib1 (old, no commands), fzf (protected), orph1 / orph2 (dependencies nothing needs).
pfx="$HOME/pfx"
for p in foo bar fresh lib1 fzf orph1 orph2; do mkdir -p "$pfx/Cellar/$p/1.0"; done
for p in foo bar fresh fzf; do
	mkdir -p "$pfx/opt/$p/bin"
	: >"$pfx/opt/$p/bin/$p"
done
dd if=/dev/zero of="$pfx/Cellar/foo/1.0/f" bs=1024 count=300 2>/dev/null
dd if=/dev/zero of="$pfx/Cellar/orph1/1.0/f" bs=1024 count=100 2>/dev/null
ts_days_ago() { date -v-"$1"d +%Y%m%d%H%M 2>/dev/null || date -d "$1 days ago" +%Y%m%d%H%M; }
for p in foo bar lib1 fzf orph1 orph2; do touch -t 200001010000 "$pfx/Cellar/$p/1.0"; done
touch -t "$(ts_days_ago 40)" "$pfx/Cellar/fresh/1.0"
fb "--cellar" "$pfx/Cellar"
fb "--prefix" "$pfx"
fb "leaves --installed-on-request" "foo
bar
fresh
lib1
fzf"
fb "autoremove --dry-run" "==> Would autoremove 2 unneeded formulae:
orph1
orph2"
printf ': 1700000000:0;bar --help\n: 1700000001:0;ls -la\n' >"$HOME/.zsh_history"
printf 'cd /tmp\n' >"$HOME/.bash_history"
names_of() { printf '%s\n' "$1" | cut -f1 | tr '\n' ' ' | sed 's/ $//'; }
reason_of() { printf '%s\n' "$1" | awk -F'\t' -v n="$2" '$1 == n { print $2 }'; }

scan="$(shell::brew::unused::scan)"
t_eq "scan: orphans first, then the stale formulae" "orph1 orph2 foo lib1" "$(names_of "$scan")"
t_eq "scan: an orphan" "orphan" "$(reason_of "$scan" orph1)"
t_eq "scan: a stale formula" "stale" "$(reason_of "$scan" foo)"
t_lacks "scan: a command found in the shell history is a sign of use" "bar" "$scan"
t_lacks "scan: a package touched within the period is not stale" "fresh" "$scan"
t_lacks "scan: a protected package is never proposed" "fzf" "$scan"
t_has "scan: the reason names the history" "none of its commands in your shell history" "$(printf '%s\n' "$scan" | grep '^foo')"
t_has "scan: a formula without commands says so" "no commands (a library?)" "$(printf '%s\n' "$scan" | grep '^lib1')"
t_eq "scan: the size in KB" "1" "$(printf '%s\n' "$scan" | awk -F'\t' '$1 == "foo" && $3 >= 300 { print 1 }')"
t_eq "scan: four tab separated columns" "4" "$(printf '%s\n' "$scan" | head -n 1 | awk -F'\t' '{ print NF }')"
t_eq "scan --orphans" "orph1 orph2" "$(names_of "$(shell::brew::unused::scan --orphans)")"
t_eq "scan --stale" "foo lib1" "$(names_of "$(shell::brew::unused::scan --stale)")"
t_eq "scan --days 30: the formula touched 40 days ago is stale too" "orph1 orph2 foo fresh lib1" "$(names_of "$(shell::brew::unused::scan --days 30)")"
t_eq "scan --days 90 is the default" "$scan" "$(shell::brew::unused::scan --days 90)"
t_eq "scan: SHELL_BREW_STALE_DAYS is the default period" "orph1 orph2 foo fresh lib1" "$(names_of "$(SHELL_BREW_STALE_DAYS=30 shell::brew::unused::scan)")"
nohist="$(shell::brew::unused::scan --no-history)"
t_eq "scan --no-history: age only, so the used command counts too" "orph1 orph2 foo bar lib1" "$(names_of "$nohist")"
t_has "scan --no-history: ...and the reason says history was not checked" "shell history not checked" "$(printf '%s\n' "$nohist" | grep '^foo')"
mv "$HOME/.zsh_history" "$HOME/.zsh_history.off"
mv "$HOME/.bash_history" "$HOME/.bash_history.off"
t_has "scan: with no history to read, says so rather than claiming 'unused'" "shell history not checked" "$(shell::brew::unused::scan --stale | grep '^bar')"
mv "$HOME/.zsh_history.off" "$HOME/.zsh_history"
mv "$HOME/.bash_history.off" "$HOME/.bash_history"
printf 'foo --version\n' >"$HOME/hist_custom"
t_lacks "scan: \$HISTFILE is read too" "foo" "$(HISTFILE="$HOME/hist_custom" shell::brew::unused::scan --stale)"
t_eq "scan: SHELL_BREW_PROTECTED is configurable" "orph1 orph2 lib1" "$(names_of "$(SHELL_BREW_PROTECTED="fzf foo" shell::brew::unused::scan)")"
t_eq "scan: ...and protects orphans too" "orph2 foo lib1" "$(names_of "$(SHELL_BREW_PROTECTED="fzf orph1" shell::brew::unused::scan)")"
t_eq "scan: an invalid number of days" "2" "$(rc_of shell::brew::unused::scan --days abc)"
t_eq "scan: zero days" "2" "$(rc_of shell::brew::unused::scan --days 0)"
t_eq "scan: --days needs a value" "2" "$(rc_of shell::brew::unused::scan --days)"
t_eq "scan: an unknown option" "2" "$(rc_of shell::brew::unused::scan --bogus)"
t_eq "scan: a leaf that is not in the Cellar is ignored" "orph1 orph2 foo lib1" "$(
	fb "leaves --installed-on-request" "foo
ghost
bar
lib1"
	names_of "$(shell::brew::unused::scan)"
)"
fb "leaves --installed-on-request" "foo
bar
fresh
lib1
fzf"
t_eq "scan: brew autoremove output of another shape yields no orphans" "foo lib1" "$(
	fb "autoremove --dry-run" "Nothing to do"
	names_of "$(shell::brew::unused::scan)"
)"
fb "autoremove --dry-run" "==> Would autoremove 2 unneeded formulae:
orph1
orph2"
t_eq "scan: no leftover temp file" "0" "$(
	mkdir "$HOME/tmpscan"
	TMPDIR="$HOME/tmpscan" shell::brew::unused::scan >/dev/null 2>&1
	find "$HOME/tmpscan" -mindepth 1 | wc -l | tr -d ' '
)"

# --- unused (the report) ---------------------------------------------------------------------------------------
out="$(shell::brew::unused 2>&1)"
t_has "unused: a header" "PACKAGE" "$out"
t_has "unused: an orphan row" "orph1" "$(printf '%s\n' "$out" | grep '^orph1')"
t_has "unused: with its reason" "orphan" "$(printf '%s\n' "$out" | grep '^orph1')"
t_has "unused: a stale row with a human size" "308K" "$(printf '%s\n' "$out" | grep '^foo')"
t_eq "unused: biggest first" "foo" "$(printf '%s\n' "$out" | sed -n 2p | awk '{ print $1 }')"
t_eq "unused --names: names only, for scripts" "orph1${nl}orph2${nl}foo${nl}lib1" "$(shell::brew::unused --names 2>&1)"
t_eq "unused -q --orphans" "orph1${nl}orph2" "$(shell::brew::unused -q --orphans 2>&1)"
t_eq "unused --days 30 --names" "orph1${nl}orph2${nl}foo${nl}fresh${nl}lib1" "$(shell::brew::unused --days 30 --names 2>&1)"
t_eq "unused: --days needs a value" "2" "$(rc_of shell::brew::unused --days)"
t_eq "unused: a bad number of days is reported" "2" "$(rc_of shell::brew::unused --days x)"
t_eq "unused: it only reports, it never removes" "0" "$(
	: >"$FAKE_BREW_LOG"
	shell::brew::unused >/dev/null 2>&1
	grep -c -E '^(uninstall|autoremove$|cleanup)' "$FAKE_BREW_LOG"
)"
t_has "unused: nothing found says so" "No unused packages found" "$(
	fb "autoremove --dry-run" ""
	fb "leaves --installed-on-request" "fzf"
	shell::brew::unused 2>&1
)"
fb "autoremove --dry-run" "==> Would autoremove 2 unneeded formulae:
orph1
orph2"
fb "leaves --installed-on-request" "foo
bar
fresh
lib1
fzf"

# --- unused::fzf -----------------------------------------------------------------------------------------------
out="$(run "foo;orph1" "y${nl}y${nl}" shell::brew::unused::fzf)"
t_eq "unused::fzf: uninstalls what was marked" "uninstall foo orph1" "$(grep '^uninstall' "$FAKE_BREW_LOG")"
t_has "unused::fzf: asked first" "Uninstall foo orph1?" "$out"
t_eq "unused::fzf: then offers autoremove, and the answer was yes" "1" "$(grep -c '^autoremove$' "$FAKE_BREW_LOG")"
t_has "unused::fzf: the list has package, reason, size and why" "foo" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "unused::fzf: ...the reason" "orphan" "$(grep '^orph1' "$FAKE_FZF_DIR/stdin.1")"
t_has "unused::fzf: ...the why" "none of its commands in your shell history" "$(grep '^foo' "$FAKE_FZF_DIR/stdin.1")"
t_lacks "unused::fzf: protected packages are not offered" "fzf" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_lacks "unused::fzf: ...nor the ones that are in use" "bar" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "unused::fzf: marking several" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "unused::fzf: the preview shows brew info" "info {1}" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "unused::fzf: ...and what depends on it" "uses --installed {1}" "$(cat "$FAKE_FZF_DIR/args.1")"
out="$(run "foo" "y${nl}n${nl}" shell::brew::unused::fzf)"
t_eq "unused::fzf: a 'no' to autoremove skips it" "0" "$(grep -c '^autoremove$' "$FAKE_BREW_LOG")"
t_eq "unused::fzf: ...but the uninstall happened" "uninstall foo" "$(grep '^uninstall' "$FAKE_BREW_LOG")"
run "foo" "n${nl}" shell::brew::unused::fzf >/dev/null
t_eq "unused::fzf: 'n' removes nothing" "0" "$(logged '^uninstall')"
run "foo" "" shell::brew::unused::fzf >/dev/null
t_eq "unused::fzf: end of input removes nothing" "0" "$(logged '^uninstall')"
run "" "" shell::brew::unused::fzf >/dev/null
t_eq "unused::fzf: ESC removes nothing" "0" "$(logged '^uninstall')"
t_eq "unused::fzf: nothing is pre-selected" "0" "$(logged '^uninstall')"
run "foo;orph2" "" shell::brew::unused::fzf --yes >/dev/null
t_eq "unused::fzf --yes: no question, then autoremove too" "uninstall foo orph2${nl}autoremove" "$(grep -E '^(uninstall|autoremove$)' "$FAKE_BREW_LOG")"
out="$(run "foo" "" shell::brew::unused::fzf -n -y)"
t_eq "unused::fzf -n: nothing is removed" "0" "$(logged -E '^(uninstall|autoremove$)')"
t_has "unused::fzf -n: the command is printed" "brew uninstall foo" "$out"
run "orph1;orph2" "y${nl}" shell::brew::unused::fzf --orphans >/dev/null
t_eq "unused::fzf --orphans" "orph1${nl}orph2" "$(awk '{ print $1 }' "$FAKE_FZF_DIR/stdin.1")"
run "foo" "y${nl}n${nl}" shell::brew::unused::fzf --stale >/dev/null
t_eq "unused::fzf --stale" "foo${nl}lib1" "$(awk '{ print $1 }' "$FAKE_FZF_DIR/stdin.1")"
run "fresh" "y${nl}n${nl}" shell::brew::unused::fzf --days 30 >/dev/null
t_has "unused::fzf --days: passed to the scan" "fresh" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_eq "unused::fzf: a bad number of days" "2" "$(rc_of shell::brew::unused::fzf --days x)"
t_eq "unused::fzf: --days needs a value" "2" "$(rc_of shell::brew::unused::fzf --days)"
printf '1\n' >"$FAKE_BREW_DIR/uninstall_foo.rc"
run "foo" "y${nl}y${nl}" shell::brew::unused::fzf >/dev/null
t_eq "unused::fzf: a failing uninstall is reported" "1" "$?"
t_eq "unused::fzf: ...and autoremove is not offered after a failure" "0" "$(grep -c '^autoremove$' "$FAKE_BREW_LOG")"
rm -f "$FAKE_BREW_DIR/uninstall_foo.rc"
out="$(
	fb "autoremove --dry-run" ""
	fb "leaves --installed-on-request" "fzf"
	run "" "" shell::brew::unused::fzf
)"
t_has "unused::fzf: nothing found says so" "No unused packages found" "$out"
t_eq "unused::fzf: ...without opening fzf" "0" "$(fzf_calls)"
fb "autoremove --dry-run" "==> Would autoremove 2 unneeded formulae:
orph1
orph2"
fb "leaves --installed-on-request" "foo
bar
fresh
lib1
fzf"

# --- tidy -------------------------------------------------------------------------------------------------------
out="$(run "" "y${nl}y${nl}" shell::brew::tidy)"
t_eq "tidy: previews each step, then runs it" "autoremove --dry-run${nl}autoremove${nl}cleanup --dry-run${nl}cleanup" "$(grep -E '^(autoremove|cleanup)' "$FAKE_BREW_LOG")"
t_has "tidy: the steps are announced" "1/2" "$out"
run "" "n${nl}n${nl}" shell::brew::tidy >/dev/null
t_eq "tidy: two 'no' leave only the previews" "autoremove --dry-run${nl}cleanup --dry-run" "$(grep -E '^(autoremove|cleanup)' "$FAKE_BREW_LOG")"
run "" "y${nl}n${nl}" shell::brew::tidy >/dev/null
t_eq "tidy: each step has its own question" "autoremove --dry-run${nl}autoremove${nl}cleanup --dry-run" "$(grep -E '^(autoremove|cleanup)' "$FAKE_BREW_LOG")"
run "" "" shell::brew::tidy --yes >/dev/null
t_eq "tidy --yes: no questions" "autoremove --dry-run${nl}autoremove${nl}cleanup --dry-run${nl}cleanup" "$(grep -E '^(autoremove|cleanup)' "$FAKE_BREW_LOG")"
out="$(run "" "" shell::brew::tidy -n -y)"
t_eq "tidy -n: the previews run, the real steps do not" "autoremove --dry-run${nl}cleanup --dry-run" "$(grep -E '^(autoremove|cleanup)' "$FAKE_BREW_LOG")"
t_has "tidy -n: the real commands are printed" "brew autoremove" "$out"
t_has "tidy -n: ...both of them" "brew cleanup" "$out"

# --- manage (the menu) ----------------------------------------------------------------------------------------
out="$(run "Update Homebrew${nl}$B" "" shell::brew::manage)"
t_eq "manage: an entry runs its command" "update" "$(grep '^update' "$FAKE_BREW_LOG")"
t_has "manage: the menu lists every area" "Find unused packages" "$(cat "$FAKE_FZF_DIR/stdin.1")"
for entry in "Install packages" "Uninstall packages" "Upgrade outdated packages" "Browse installed packages" "Tidy up (autoremove + cleanup)" \
	"Largest packages" "Pin a package" "Unpin a package" "Services" "Taps" "Health check (doctor)"; do
	t_has "manage: offers '$entry'" "$entry" "$(cat "$FAKE_FZF_DIR/stdin.1")"
done
t_has "manage: the menu has a prompt" "--prompt=Homebrew: " "$(cat "$FAKE_FZF_DIR/args.1")"
t_eq "manage: the menu is last-entry Back" "$B" "$(tail -n 1 "$FAKE_FZF_DIR/stdin.1")"
t_eq "manage: and it came back to the menu after the command" "2" "$(fzf_calls)"
out="$(run "Health check (doctor)${nl}" "" shell::brew::manage)"
t_eq "manage: doctor" "doctor" "$(grep '^doctor' "$FAKE_BREW_LOG")"
out="$(run "Install packages${nl}jq${nl}$B" "" shell::brew::manage)"
t_eq "manage: an entry opens its own picker, and the pick is acted on" "install jq" "$(grep '^install' "$FAKE_BREW_LOG")"
t_eq "manage: ...and the menu is shown again afterwards" "3" "$(fzf_calls)"
out="$(run "Find unused packages${nl}foo${nl}$B" "y${nl}n${nl}" shell::brew::manage)"
t_eq "manage: the unused-package flow" "uninstall foo" "$(grep '^uninstall' "$FAKE_BREW_LOG")"
out="$(run "Update Homebrew${nl}Install packages${nl}jq${nl}$B" "" shell::brew::manage -n)"
t_eq "manage -n: nothing that changes the system runs" "0" "$(logged -E '^(update|install)')"
t_has "manage -n: the commands are printed instead" "brew update" "$out"
t_has "manage -n: ...for the picker too" "brew install jq" "$out"
out="$(run "Largest packages${nl}$B" "" shell::brew::manage)"
t_has "manage: a read-only entry prints its report" "308K  foo" "$out"
run "" "" shell::brew::manage >/dev/null
t_eq "manage: ESC leaves, no error" "0" "$?"
run "$B" "" shell::brew::manage >/dev/null
t_eq "manage: Back leaves, no error" "0" "$?"
t_eq "manage: ...and nothing ran" "0" "$(wc -l <"$FAKE_BREW_LOG" | tr -d ' ')"

# --- the aliases point at the right functions ---------------------------------------------------------------------
for pair in sbi-n:"shell::brew::install::fzf -n" sbic:"shell::brew::install::fzf --cask" sbrmc:"shell::brew::uninstall::fzf --cask" \
	sbor:"shell::brew::unused --orphans" sbunf-n:"shell::brew::unused::fzf -n" sbtidy-n:"shell::brew::tidy -n" sbsz:shell::brew::size \
	sbsv:shell::brew::services::fzf sbut:shell::brew::untap::fzf sbpin:shell::brew::pin::fzf sbunpin:shell::brew::unpin::fzf sbin:shell::brew::info::fzf; do
	t_has "alias ${pair%%:*}" "${pair#*:}" "$(alias "${pair%%:*}" 2>&1)"
done

t_done
