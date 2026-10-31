#!/usr/bin/env bash
# shell::nvm::*::fzf, shell::nvm::manage, shell::nvm::unused*, shell::nvm::size (src/lang/nvm_fzf.sh):
# what is listed for the user, what a pick turns into, what is asked before anything is removed, and how
# "unused" is decided.
#
# nvm and fzf are both fakes. The fake nvm.sh defines an `nvm` function that logs every call to
# $FAKE_NVM_LOG and answers from files in $FAKE_NVM_DIR; its answers are copies of what a real nvm 0.40
# prints (the `->` marker, the trailing `*`, `(default)` on its own aliases, `lts/*`, `iojs-` versions).
# The fake fzf logs the candidate lines (stdin.N) and its arguments (args.N) and answers the Nth call with
# line N of $FAKE_FZF_PICKS: a pick is matched as text against the candidate lines and the whole matching
# line is printed, like fzf; `a;b` picks two lines; an empty line is ESC. Text prompts (y/n, alias name)
# read the standard input of the function under test.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

export NVM_DIR="$HOME/.nvm"
mkdir -p "$NVM_DIR" "$HOME/fake" "$HOME/bin"
cat >"$NVM_DIR/nvm.sh" <<'FAKE'
nvm() {
	printf '%s\n' "$*" >>"$FAKE_NVM_LOG"
	_k="$(printf '%s' "$*" | tr ' /*' '___')"
	[ -f "$FAKE_NVM_DIR/$_k" ] && cat "$FAKE_NVM_DIR/$_k"
	_rc=0
	[ -f "$FAKE_NVM_DIR/$_k.rc" ] && _rc="$(cat "$FAKE_NVM_DIR/$_k.rc")"
	return "$_rc"
}
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
chmod +x "$HOME/bin/fzf"
export PATH="$HOME/bin:$PATH" FAKE_NVM_DIR="$HOME/fake" FAKE_NVM_LOG="$HOME/nvm.log"
export FAKE_FZF_DIR="$HOME/fzfdir" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_FZF_PICKS=""
mkdir "$FAKE_FZF_DIR"
: >"$FAKE_NVM_LOG"

nl='
'
B="$SHELL_FZF_BACK_LABEL"

# fn "<nvm args>" "<what nvm prints>"
fn() { printf '%s\n' "$2" >"$FAKE_NVM_DIR/$(printf '%s' "$1" | tr ' /*' '___')"; }
reset_state() {
	: >"$FAKE_NVM_LOG"
	find "$FAKE_FZF_DIR" -maxdepth 1 \( -name 'stdin.*' -o -name 'args.*' \) -delete
	rm -f "$FAKE_FZF_STATE"
}
# run <picks> <stdin> <command...>  -> combined output; the nvm / fzf logs are left for the asserts
run() {
	local picks="$1" input="$2"
	shift 2
	reset_state
	printf '%s' "$input" | FAKE_FZF_PICKS="$picks" "$@" 2>&1
}
logged() { grep -c -- "$1" "$FAKE_NVM_LOG"; }
fzf_calls() { cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0; }
rc_of() {
	"$@" >/dev/null 2>&1
	echo "$?"
}
no_nvm() (
	unset -f nvm 2>/dev/null
	shell::dependency::nvm::path() { return 3; }
	"$@" 2>&1
	echo "rc=$?"
)

# What nvm "has installed": four versions, v22.2.0 in use, default -> 22, work -> 18.19.0.
fn "ls --no-colors --no-alias" "       v18.19.0 *
        v20.9.0 *
       v20.11.1 *
->      v22.2.0 *
       system * (-> v22.22.2)"
fn current v22.2.0
fn "alias --no-colors" "default -> 22 (-> v22.2.0 *)
work -> 18.19.0 (-> v18.19.0 *)
iojs -> N/A (default)
lts/* -> lts/iron (-> N/A)
node -> stable (-> v22.2.0 *) (default)
stable -> 22.2 (-> v22.2.0 *) (default)
unstable -> N/A (default)"
fn "ls-remote --no-colors" "        v20.9.0   (LTS: Iron)
       v20.11.1   (Latest LTS: Iron)
        v22.2.0
->      v22.3.0 *
iojs-v3.3.1
        N/A"
fn "ls-remote --no-colors --lts" "        v20.9.0   (LTS: Iron)
       v20.11.1   (Latest LTS: Iron)"
: >"$FAKE_NVM_LOG"

# --- shell::nvm::fzf::pick ----------------------------------------------------------------------
out="$(printf 'v20  x\nv22  y\n' | FAKE_FZF_PICKS="v22" shell::nvm::fzf::pick 2>&1)"
t_eq "pick: prints the first word of the chosen row" "v22" "$out"
reset_state
out="$(printf 'v18  a\nv20  b\nv22  c\n' | FAKE_FZF_PICKS="v18;v22" shell::nvm::fzf::pick -m 2>&1)"
t_eq "pick -m: several rows, one value per line" "v18${nl}v22" "$out"
t_has "pick -m: asks fzf for --multi" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "pick -m: ...and Ctrl-A to mark all" "--bind=ctrl-a:select-all" "$(cat "$FAKE_FZF_DIR/args.1")"
reset_state
printf 'a\n' | FAKE_FZF_PICKS="a" shell::nvm::fzf::pick >/dev/null 2>&1
t_lacks "pick: single choice has no --multi" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
reset_state
printf 'a\n' | FAKE_FZF_PICKS="a" shell::nvm::fzf::pick -p "Pick: " -P "ls {1}" -H "a header" >/dev/null 2>&1
t_has "pick: the prompt" "--prompt=Pick: " "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "pick: the preview" "--preview=ls {1}" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "pick: the header" "--header=a header" "$(cat "$FAKE_FZF_DIR/args.1")"
reset_state
printf '' | FAKE_FZF_PICKS="a" shell::nvm::fzf::pick >/dev/null 2>&1
t_eq "pick: no rows is RETURN_EMPTY" "8" "$?"
t_eq "pick: ...and fzf is not even started" "0" "$(fzf_calls)"
reset_state
printf 'a\n' | FAKE_FZF_PICKS="" shell::nvm::fzf::pick >/dev/null 2>&1
t_eq "pick: ESC is RETURN_CANCELLED" "9" "$?"
printf 'a\n' | shell::nvm::fzf::pick --bogus >/dev/null 2>&1
t_eq "pick: unknown option" "2" "$?"
printf 'a\n' | shell::nvm::fzf::pick -p >/dev/null 2>&1
t_eq "pick: an option without a value" "2" "$?"

# --- parsing what nvm prints -------------------------------------------------------------------------
t_eq "installed: the versions, oldest first, no system / arrow / star" "v18.19.0 v20.9.0 v20.11.1 v22.2.0" "$(shell::nvm::versions::installed | tr '\n' ' ' | sed 's/ $//')"
rows="$(shell::nvm::fzf::rows::installed)"
t_eq "rows: one per version" "4" "$(printf '%s\n' "$rows" | wc -l | tr -d ' ')"
t_eq "rows: the first word is the version" "v18.19.0" "$(printf '%s\n' "$rows" | head -n 1 | awk '{ print $1 }')"
t_has "rows: the version in use is marked" "[current]" "$(printf '%s\n' "$rows" | grep '^v22.2.0')"
t_lacks "rows: ...and only that one" "[current]" "$(printf '%s\n' "$rows" | grep -v '^v22.2.0')"
t_has "rows: the aliases of a version are listed" "default, node, stable" "$(printf '%s\n' "$rows" | grep '^v22.2.0')"
t_has "rows: your alias" "work" "$(printf '%s\n' "$rows" | grep '^v18.19.0')"
t_lacks "rows: lts/* is nvm's, not listed" "lts" "$rows"
t_eq "rows: a version no alias points at has none" "v20.9.0" "$(printf '%s\n' "$rows" | grep '^v20.9.0' | sed 's/  */ /g;s/ $//')"
t_eq "rows: a prefix of another version is not a match (v20.1 vs v20.11.1)" "" "$(
	fn "alias --no-colors" "work -> 20 (-> v20.11.1 *)"
	shell::nvm::fzf::rows::installed | grep '^v20.9.0' | grep -c work | sed 's/^0$//'
)"
fn "alias --no-colors" "default -> 22 (-> v22.2.0 *)
work -> 18.19.0 (-> v18.19.0 *)
iojs -> N/A (default)
lts/* -> lts/iron (-> N/A)
node -> stable (-> v22.2.0 *) (default)
stable -> 22.2 (-> v22.2.0 *) (default)
unstable -> N/A (default)"
t_eq "aliases::user: only the ones you made" "default -> 22 (-> v22.2.0 *)${nl}work -> 18.19.0 (-> v18.19.0 *)" "$(shell::nvm::aliases::user)"
remote="$(shell::nvm::versions::remote)"
t_eq "remote: newest first, io.js and N/A left out" "v22.3.0 v22.2.0 v20.11.1 v20.9.0" "$(printf '%s\n' "$remote" | awk '{ print $1 }' | tr '\n' ' ' | sed 's/ $//')"
t_has "remote: the LTS line is named" "(Latest LTS: Iron)" "$(printf '%s\n' "$remote" | grep '^v20.11.1')"
t_has "remote: installed versions are tagged" "[installed]" "$(printf '%s\n' "$remote" | grep '^v22.2.0')"
t_lacks "remote: ...and the others are not" "[installed]" "$(printf '%s\n' "$remote" | grep '^v22.3.0')"
t_eq "remote --lts asks nvm for exactly that" "ls-remote --no-colors --lts" "$(
	: >"$FAKE_NVM_LOG"
	shell::nvm::versions::remote --lts >/dev/null
	grep '^ls-remote' "$FAKE_NVM_LOG"
)"
out="$(printf 'a\tx\t512\tw\nb\tx\t2048\tw\nc\tx\t3145728\tw\n' | shell::nvm::size::format)"
t_eq "size::format: kilobytes" "512K" "$(printf '%s\n' "$out" | sed -n 1p | cut -f3)"
t_eq "size::format: megabytes" "2.0M" "$(printf '%s\n' "$out" | sed -n 2p | cut -f3)"
t_eq "size::format: gigabytes" "3.0G" "$(printf '%s\n' "$out" | sed -n 3p | cut -f3)"
t_eq "size::format: other columns untouched" "c	x	3.0G	w" "$(printf '%s\n' "$out" | sed -n 3p)"
pv="$(shell::nvm::fzf::preview)"
t_has "preview: lists the global npm packages of the focused version" "/lib/node_modules" "$pv"
t_has "preview: ...under NVM_DIR" "$NVM_DIR/versions/node/" "$pv"
t_has "preview: ...for the first word of the row" "{1}" "$pv"

# --- help, unknown options and "no nvm" for every interactive function --------------------------------------
for fn in use::fzf install::fzf uninstall::fzf default::fzf alias::fzf unalias::fzf nvmrc::fzf exec::fzf run::fzf migrate::fzf \
	reinstall_packages::fzf size unused unused::fzf manage; do
	reset_state
	out="$(FAKE_FZF_PICKS="" "shell::nvm::$fn" -h 2>&1)"
	t_has "$fn -h: shows its usage" "USAGE: shell::nvm::$fn" "$out"
	t_eq "$fn -h: starts neither nvm nor fzf" "0" "$(($(wc -l <"$FAKE_NVM_LOG") + $(fzf_calls)))"
	t_eq "$fn --help: returns 0" "0" "$(rc_of "shell::nvm::$fn" --help)"
done
for fn in use::fzf install::fzf uninstall::fzf default::fzf alias::fzf unalias::fzf nvmrc::fzf migrate::fzf reinstall_packages::fzf \
	unused unused::fzf manage; do
	reset_state
	t_eq "$fn: an unknown option is invalid" "2" "$(rc_of "shell::nvm::$fn" --bogus)"
done
t_eq "exec::fzf: an unknown option is not an option, it is the command" "2" "$(rc_of shell::nvm::exec::fzf)"
for fn in use::fzf install::fzf uninstall::fzf default::fzf alias::fzf unalias::fzf nvmrc::fzf migrate::fzf reinstall_packages::fzf \
	size unused unused::fzf manage; do
	reset_state
	out="$(no_nvm "shell::nvm::$fn")"
	t_has "$fn: without nvm, rc 3" "rc=3" "$out"
	t_has "$fn: ...and how to install it" "shell::dependency::nvm::install" "$out"
	t_eq "$fn: ...without opening fzf" "0" "$(fzf_calls)"
done
out="$(no_nvm shell::nvm::exec::fzf npm test)"
t_has "exec::fzf: without nvm, rc 3" "rc=3" "$out"

# --- use::fzf -------------------------------------------------------------------------------------------------
out="$(run "v20.11.1" "" shell::nvm::use::fzf)"
t_eq "use::fzf: switches to the pick" "use v20.11.1" "$(grep '^use' "$FAKE_NVM_LOG")"
t_has "use::fzf: the list shows the version in use" "[current]" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "use::fzf: ...and the aliases" "default" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_lacks "use::fzf: choosing one version, not several" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "use::fzf: with the global packages as preview" "node_modules" "$(cat "$FAKE_FZF_DIR/args.1")"
run "v18.19.0" "" shell::nvm::use::fzf --silent >/dev/null
t_eq "use::fzf --silent" "use --silent v18.19.0" "$(grep '^use' "$FAKE_NVM_LOG")"
out="$(run "v18.19.0" "" shell::nvm::use::fzf -n)"
t_eq "use::fzf -n: nothing is switched" "0" "$(logged '^use')"
t_has "use::fzf -n: the command is printed" "nvm use v18.19.0" "$out"
run "" "" shell::nvm::use::fzf >/dev/null
t_eq "use::fzf: ESC switches nothing" "0" "$(logged '^use')"
t_eq "use::fzf: ...and is not an error" "0" "$(rc_of shell::nvm::use::fzf)"
fn "ls --no-colors --no-alias" ""
out="$(run "" "" shell::nvm::use::fzf)"
t_has "use::fzf: nothing installed says how to install" "shell::nvm::install" "$out"
fn "ls --no-colors --no-alias" "       v18.19.0 *
        v20.9.0 *
       v20.11.1 *
->      v22.2.0 *
       system * (-> v22.22.2)"

# --- install::fzf ----------------------------------------------------------------------------------------------
out="$(run "v22.3.0;v20.11.1" "" shell::nvm::install::fzf)"
t_eq "install::fzf: installs what was marked" "install v22.3.0${nl}install v20.11.1" "$(grep '^install' "$FAKE_NVM_LOG")"
t_has "install::fzf: marking several" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
t_eq "install::fzf: newest first" "v22.3.0" "$(head -n 1 "$FAKE_FZF_DIR/stdin.1" | awk '{ print $1 }')"
t_has "install::fzf: the LTS line is shown" "LTS: Iron" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "install::fzf: installed versions are tagged" "[installed]" "$(grep '^v22.2.0' "$FAKE_FZF_DIR/stdin.1")"
run "" "" shell::nvm::install::fzf >/dev/null
t_eq "install::fzf: ESC installs nothing" "0" "$(logged '^install')"
t_eq "install::fzf: ...and is not an error" "0" "$(rc_of shell::nvm::install::fzf)"
out="$(run "v20.9.0" "" shell::nvm::install::fzf --lts)"
t_eq "install::fzf --lts: asks nvm for the LTS list only" "ls-remote --no-colors --lts" "$(grep '^ls-remote' "$FAKE_NVM_LOG")"
t_eq "install::fzf --lts: ...and does not pass --lts to install" "install v20.9.0" "$(grep '^install' "$FAKE_NVM_LOG")"
t_lacks "install::fzf --lts: the LTS list has no non-LTS version" "v22.3.0" "$(cat "$FAKE_FZF_DIR/stdin.1")"
run "v22.3.0" "" shell::nvm::install::fzf --latest-npm --default >/dev/null
t_eq "install::fzf --latest-npm --default: passed to install" "install --latest-npm --default v22.3.0" "$(grep '^install' "$FAKE_NVM_LOG")"
out="$(run "v22.3.0" "" shell::nvm::install::fzf -n)"
t_eq "install::fzf -n: nothing is installed" "0" "$(logged '^install')"
t_has "install::fzf -n: the command is printed" "nvm install v22.3.0" "$out"
printf '1\n' >"$FAKE_NVM_DIR/install_v22.3.0.rc"
run "v22.3.0;v20.11.1" "" shell::nvm::install::fzf >/dev/null
t_eq "install::fzf: a failing install is reported (rc 1)" "1" "$?"
t_eq "install::fzf: ...and the others are still tried" "install v22.3.0${nl}install v20.11.1" "$(grep '^install' "$FAKE_NVM_LOG")"
rm -f "$FAKE_NVM_DIR/install_v22.3.0.rc"
fn "ls-remote --no-colors" ""
out="$(run "" "" shell::nvm::install::fzf)"
t_has "install::fzf: an empty list suggests the network" "network" "$out"
fn "ls-remote --no-colors" "        v20.9.0   (LTS: Iron)
       v20.11.1   (Latest LTS: Iron)
        v22.2.0
->      v22.3.0 *
iojs-v3.3.1
        N/A"

# --- uninstall::fzf --------------------------------------------------------------------------------------------
out="$(run "v20.9.0" "y${nl}" shell::nvm::uninstall::fzf)"
t_eq "uninstall::fzf: asks, then uninstalls" "uninstall v20.9.0" "$(grep '^uninstall' "$FAKE_NVM_LOG")"
t_has "uninstall::fzf: the question names the version" "Uninstall v20.9.0?" "$out"
t_has "uninstall::fzf: marking several" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
run "v20.9.0" "n${nl}" shell::nvm::uninstall::fzf >/dev/null
t_eq "uninstall::fzf: 'n' removes nothing" "0" "$(logged '^uninstall')"
out="$(run "v20.9.0" "n${nl}" shell::nvm::uninstall::fzf)"
t_has "uninstall::fzf: ...and says it aborted" "Aborted" "$out"
run "v20.9.0" "" shell::nvm::uninstall::fzf >/dev/null
t_eq "uninstall::fzf: end of input removes nothing" "0" "$(logged '^uninstall')"
run "" "" shell::nvm::uninstall::fzf >/dev/null
t_eq "uninstall::fzf: ESC removes nothing" "0" "$(logged '^uninstall')"
out="$(run "v20.9.0;v20.11.1" "" shell::nvm::uninstall::fzf --yes)"
t_eq "uninstall::fzf --yes: does not ask, one command per version" "uninstall v20.9.0${nl}uninstall v20.11.1" "$(grep '^uninstall' "$FAKE_NVM_LOG")"
out="$(run "v22.2.0" "y${nl}" shell::nvm::uninstall::fzf)"
t_eq "uninstall::fzf: the version in use is never uninstalled" "0" "$(logged '^uninstall')"
t_has "uninstall::fzf: ...and the reason is given" "Skipping v22.2.0: it is the version in use" "$out"
t_has "uninstall::fzf: ...with nothing left to do" "Nothing to uninstall" "$out"
out="$(run "v22.2.0;v20.9.0" "y${nl}" shell::nvm::uninstall::fzf)"
t_eq "uninstall::fzf: the rest of the pick still goes" "uninstall v20.9.0" "$(grep '^uninstall' "$FAKE_NVM_LOG")"
out="$(run "v18.19.0" "n${nl}" shell::nvm::uninstall::fzf)"
t_has "uninstall::fzf: a version an alias points at is flagged in the question" "v18.19.0 is the target of: work" "$out"
out="$(run "v20.9.0" "" shell::nvm::uninstall::fzf -n -y)"
t_eq "uninstall::fzf -n: nothing is removed" "0" "$(logged '^uninstall')"
t_has "uninstall::fzf -n: the command is printed" "nvm uninstall v20.9.0" "$out"
printf '1\n' >"$FAKE_NVM_DIR/uninstall_v20.9.0.rc"
run "v20.9.0;v20.11.1" "" shell::nvm::uninstall::fzf -y >/dev/null
t_eq "uninstall::fzf: a failure is reported (rc 1)" "1" "$?"
t_eq "uninstall::fzf: ...and the others are still tried" "uninstall v20.9.0${nl}uninstall v20.11.1" "$(grep '^uninstall' "$FAKE_NVM_LOG")"
rm -f "$FAKE_NVM_DIR/uninstall_v20.9.0.rc"

# --- default::fzf ----------------------------------------------------------------------------------------------
out="$(run "lts/*" "" shell::nvm::default::fzf)"
t_eq "default::fzf: lts/* is offered and works" "alias default lts/*" "$(grep '^alias default' "$FAKE_NVM_LOG")"
t_has "default::fzf: node is offered too" "node" "$(head -n 2 "$FAKE_FZF_DIR/stdin.1")"
t_has "default::fzf: ...with the installed versions" "v20.11.1" "$(cat "$FAKE_FZF_DIR/stdin.1")"
run "node" "" shell::nvm::default::fzf >/dev/null
t_eq "default::fzf: node" "alias default node" "$(grep '^alias default' "$FAKE_NVM_LOG")"
run "v20.11.1" "" shell::nvm::default::fzf >/dev/null
t_eq "default::fzf: a version" "alias default v20.11.1" "$(grep '^alias default' "$FAKE_NVM_LOG")"
out="$(run "v20.11.1" "" shell::nvm::default::fzf -n)"
t_eq "default::fzf -n: nothing is set" "0" "$(logged '^alias default')"
t_has "default::fzf -n: the command is printed" "nvm alias default v20.11.1" "$out"
run "" "" shell::nvm::default::fzf >/dev/null
t_eq "default::fzf: ESC sets nothing" "0" "$(logged '^alias default')"

# --- alias::fzf / unalias::fzf -----------------------------------------------------------------------------------
out="$(run "v20.9.0" "build${nl}" shell::nvm::alias::fzf)"
t_eq "alias::fzf: pick a version, name the alias" "alias build v20.9.0" "$(grep '^alias build' "$FAKE_NVM_LOG")"
t_has "alias::fzf: the question names the version" "Alias name for v20.9.0?" "$out"
out="$(run "v20.9.0" "a;b${nl}" shell::nvm::alias::fzf)"
t_eq "alias::fzf: an unsafe name is refused" "0" "$(logged '^alias a')"
run "v20.9.0" "a;b${nl}" shell::nvm::alias::fzf >/dev/null
t_eq "alias::fzf: ...with rc 2" "2" "$?"
run "v20.9.0" "" shell::nvm::alias::fzf >/dev/null
t_eq "alias::fzf: end of input creates nothing" "0" "$(logged '^alias build')"
run "" "build${nl}" shell::nvm::alias::fzf >/dev/null
t_eq "alias::fzf: ESC creates nothing" "0" "$(logged '^alias build')"
out="$(run "v20.9.0" "build${nl}" shell::nvm::alias::fzf -n)"
t_eq "alias::fzf -n: nothing is created" "0" "$(logged '^alias build')"
t_has "alias::fzf -n: the command is printed" "nvm alias build v20.9.0" "$out"
out="$(run "work" "y${nl}" shell::nvm::unalias::fzf)"
t_eq "unalias::fzf: asks, then deletes" "unalias work" "$(grep '^unalias' "$FAKE_NVM_LOG")"
t_eq "unalias::fzf: only your aliases are offered" "default${nl}work" "$(awk '{ print $1 }' "$FAKE_FZF_DIR/stdin.1")"
run "work" "n${nl}" shell::nvm::unalias::fzf >/dev/null
t_eq "unalias::fzf: 'n' deletes nothing" "0" "$(logged '^unalias')"
run "default;work" "" shell::nvm::unalias::fzf -y >/dev/null
t_eq "unalias::fzf -y: deletes each" "unalias default${nl}unalias work" "$(grep '^unalias' "$FAKE_NVM_LOG")"
run "work" "" shell::nvm::unalias::fzf -n -y >/dev/null
t_eq "unalias::fzf -n: deletes nothing" "0" "$(logged '^unalias')"
fn "alias --no-colors" "iojs -> N/A (default)
lts/* -> lts/iron (-> N/A)
node -> stable (-> v22.2.0 *) (default)"
out="$(run "" "" shell::nvm::unalias::fzf)"
t_has "unalias::fzf: nothing of yours to delete" "no aliases of your own" "$out"
t_eq "unalias::fzf: ...and fzf is not opened" "0" "$(fzf_calls)"
fn "alias --no-colors" "default -> 22 (-> v22.2.0 *)
work -> 18.19.0 (-> v18.19.0 *)
iojs -> N/A (default)
lts/* -> lts/iron (-> N/A)
node -> stable (-> v22.2.0 *) (default)
stable -> 22.2 (-> v22.2.0 *) (default)
unstable -> N/A (default)"

# --- nvmrc::fzf ---------------------------------------------------------------------------------------------------
mkdir -p "$HOME/p1" "$HOME/p2" "$HOME/p3"
out="$(cd "$HOME/p1" && run "lts/*" "" shell::nvm::nvmrc::fzf)"
t_eq "nvmrc::fzf: writes the pick" "lts/*" "$(cat "$HOME/p1/.nvmrc")"
(cd "$HOME/p2" && run "v20.11.1" "" shell::nvm::nvmrc::fzf >/dev/null)
t_eq "nvmrc::fzf: an installed version, in full" "v20.11.1" "$(cat "$HOME/p2/.nvmrc")"
t_has "nvmrc::fzf: lts/* and node are offered" "node" "$(cat "$FAKE_FZF_DIR/stdin.1")"
out="$(cd "$HOME/p1" && run "node" "" shell::nvm::nvmrc::fzf)"
t_eq "nvmrc::fzf: an existing .nvmrc is kept" "lts/*" "$(cat "$HOME/p1/.nvmrc")"
t_eq "nvmrc::fzf: ...with RETURN_EXISTS" "7" "$(cd "$HOME/p1" && run "node" "" shell::nvm::nvmrc::fzf >/dev/null 2>&1 && echo 0 || echo $?)"
(cd "$HOME/p1" && run "node" "" shell::nvm::nvmrc::fzf --force >/dev/null)
t_eq "nvmrc::fzf --force replaces it" "node" "$(cat "$HOME/p1/.nvmrc")"
out="$(cd "$HOME/p3" && run "node" "" shell::nvm::nvmrc::fzf -n)"
t_eq "nvmrc::fzf -n: writes nothing" "no" "$([ -e "$HOME/p3/.nvmrc" ] && echo yes || echo no)"
(cd "$HOME/p3" && run "" "" shell::nvm::nvmrc::fzf >/dev/null)
t_eq "nvmrc::fzf: ESC writes nothing" "no" "$([ -e "$HOME/p3/.nvmrc" ] && echo yes || echo no)"

# --- exec::fzf / run::fzf -------------------------------------------------------------------------------------------
out="$(run "v20.11.1" "" shell::nvm::exec::fzf npm test)"
t_eq "exec::fzf: the pick, then the command" "exec v20.11.1 npm test" "$(grep '^exec' "$FAKE_NVM_LOG")"
run "v20.11.1" "" shell::nvm::exec::fzf --silent npm --version >/dev/null
t_eq "exec::fzf: --silent goes first; flags after it belong to the command" "exec --silent v20.11.1 npm --version" "$(grep '^exec' "$FAKE_NVM_LOG")"
out="$(run "v20.11.1" "" shell::nvm::exec::fzf -n npm test)"
t_eq "exec::fzf -n: nothing is run" "0" "$(logged '^exec')"
t_has "exec::fzf -n: the command is printed" "nvm exec v20.11.1 npm test" "$out"
run "" "" shell::nvm::exec::fzf npm test >/dev/null
t_eq "exec::fzf: ESC runs nothing" "0" "$(logged '^exec')"
t_eq "exec::fzf: no command is invalid" "2" "$(rc_of shell::nvm::exec::fzf -n)"
t_has "exec::fzf: ...and says what to give" "shell::nvm::exec::fzf npm test" "$(shell::nvm::exec::fzf -n 2>&1)"
t_eq "exec::fzf: ...without opening fzf" "0" "$(
	reset_state
	shell::nvm::exec::fzf -n >/dev/null 2>&1
	fzf_calls
)"
run "v18.19.0" "" shell::nvm::run::fzf app.js --port 3000 >/dev/null
t_eq "run::fzf: the pick, then node's arguments untouched" "run v18.19.0 app.js --port 3000" "$(grep '^run' "$FAKE_NVM_LOG")"
t_eq "run::fzf: no argument is invalid" "2" "$(rc_of shell::nvm::run::fzf)"

# --- migrate::fzf ----------------------------------------------------------------------------------------------------
out="$(run "v20.11.1${nl}Latest LTS" "" shell::nvm::migrate::fzf)"
t_eq "migrate::fzf: latest LTS, carrying the packages over" "install --reinstall-packages-from=v20.11.1 --lts" "$(grep '^install' "$FAKE_NVM_LOG")"
t_has "migrate::fzf: the source list previews the global packages" "node_modules" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "migrate::fzf: the menu offers the three targets" "A version from the list" "$(cat "$FAKE_FZF_DIR/stdin.2")"
run "v20.11.1${nl}Latest release" "" shell::nvm::migrate::fzf >/dev/null
t_eq "migrate::fzf: latest release" "install --reinstall-packages-from=v20.11.1 node" "$(grep '^install' "$FAKE_NVM_LOG")"
run "v18.19.0${nl}A version from the list${nl}v22.3.0" "" shell::nvm::migrate::fzf >/dev/null
t_eq "migrate::fzf: a version from the list" "install --reinstall-packages-from=v18.19.0 v22.3.0" "$(grep '^install' "$FAKE_NVM_LOG")"
run "v20.11.1${nl}$B" "" shell::nvm::migrate::fzf >/dev/null
t_eq "migrate::fzf: Back installs nothing" "0" "$(logged '^install')"
run "" "" shell::nvm::migrate::fzf >/dev/null
t_eq "migrate::fzf: ESC installs nothing" "0" "$(logged '^install')"
run "v20.11.1${nl}A version from the list${nl}" "" shell::nvm::migrate::fzf >/dev/null
t_eq "migrate::fzf: ESC in the version list installs nothing" "0" "$(logged '^install')"
out="$(run "v20.11.1${nl}Latest LTS" "" shell::nvm::migrate::fzf -n)"
t_eq "migrate::fzf -n: nothing is installed" "0" "$(logged '^install')"
t_has "migrate::fzf -n: the command is printed" "nvm install --reinstall-packages-from=v20.11.1 --lts" "$out"

# --- reinstall_packages::fzf -------------------------------------------------------------------------------------------
out="$(run "v20.11.1" "" shell::nvm::reinstall_packages::fzf)"
t_eq "reinstall_packages::fzf: copies from the pick" "reinstall-packages v20.11.1" "$(grep '^reinstall-packages' "$FAKE_NVM_LOG")"
t_lacks "reinstall_packages::fzf: the version in use is not a source" "v22.2.0" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "reinstall_packages::fzf: the header says where it goes" "v22.2.0" "$(cat "$FAKE_FZF_DIR/args.1")"
out="$(run "v20.11.1" "" shell::nvm::reinstall_packages::fzf -n)"
t_eq "reinstall_packages::fzf -n: nothing is copied" "0" "$(logged '^reinstall-packages')"
run "" "" shell::nvm::reinstall_packages::fzf >/dev/null
t_eq "reinstall_packages::fzf: ESC copies nothing" "0" "$(logged '^reinstall-packages')"

# --- size ------------------------------------------------------------------------------------------------------------
mkdir -p "$NVM_DIR/versions/node/v18.19.0" "$NVM_DIR/versions/node/v20.9.0" "$NVM_DIR/versions/node/v20.11.1" "$NVM_DIR/versions/node/v22.2.0" "$HOME/nvmcache"
dd if=/dev/zero of="$NVM_DIR/versions/node/v22.2.0/f" bs=1024 count=3000 2>/dev/null
dd if=/dev/zero of="$NVM_DIR/versions/node/v20.11.1/f" bs=1024 count=1200 2>/dev/null
dd if=/dev/zero of="$NVM_DIR/versions/node/v18.19.0/f" bs=1024 count=300 2>/dev/null
dd if=/dev/zero of="$NVM_DIR/versions/node/v20.9.0/f" bs=1024 count=8 2>/dev/null
dd if=/dev/zero of="$HOME/nvmcache/f" bs=1024 count=500 2>/dev/null
fn "cache dir" "$HOME/nvmcache"
out="$(shell::nvm::size 2>&1)"
t_eq "size: biggest first, then the cache" "v22.2.0${nl}v20.11.1${nl}v18.19.0${nl}v20.9.0${nl}download cache" "$(printf '%s\n' "$out" | sed 's/^ *[0-9.]*[KMG]  //')"
t_has "size: a human size" "M" "$(printf '%s\n' "$out" | head -n 1)"
t_eq "size: a count limits the versions (the cache stays)" "v22.2.0${nl}v20.11.1${nl}download cache" "$(shell::nvm::size 2 2>&1 | sed 's/^ *[0-9.]*[KMG]  //')"
t_eq "size: a count of 0" "2" "$(rc_of shell::nvm::size 0)"
t_eq "size: a count that is not a number" "2" "$(rc_of shell::nvm::size abc)"
t_eq "size: two counts" "2" "$(rc_of shell::nvm::size 1 2)"
fn "ls --no-colors --no-alias" ""
t_has "size: nothing installed" "No Node version is installed" "$(shell::nvm::size 2>&1)"
fn "ls --no-colors --no-alias" "       v18.19.0 *
        v20.9.0 *
       v20.11.1 *
->      v22.2.0 *
       system * (-> v22.22.2)"

# --- unused: what nothing refers to ----------------------------------------------------------------------------------
names_of() { printf '%s\n' "$1" | cut -f1 | tr '\n' ' ' | sed 's/ $//'; }
reason_of() { printf '%s\n' "$1" | awk -F'\t' -v n="$2" '$1 == n { print $2 }'; }
cd "$HOME" || exit 1
scan="$(shell::nvm::unused::scan)"
t_eq "scan: current v22.2.0, default/node/stable -> 22, work -> 18.19.0: the two v20 are left" "v20.9.0 v20.11.1" "$(names_of "$scan")"
t_eq "scan: a newer release of the same major is installed" "superseded" "$(reason_of "$scan" v20.9.0)"
t_eq "scan: the newest of its major, but nothing uses it" "unreferenced" "$(reason_of "$scan" v20.11.1)"
t_has "scan: the why of a superseded version" "a newer v20 release is installed" "$(printf '%s\n' "$scan" | grep '^v20.9.0')"
t_has "scan: the why of an unreferenced one" "no alias, .nvmrc or open shell uses it" "$(printf '%s\n' "$scan" | grep '^v20.11.1')"
t_eq "scan: four tab separated columns" "4" "$(printf '%s\n' "$scan" | head -n 1 | awk -F'\t' '{ print NF }')"
t_eq "scan: the size in KB comes from NVM_DIR" "1" "$(printf '%s\n' "$scan" | awk -F'\t' '$1 == "v20.11.1" && $3 >= 1200 { print 1 }')"
t_lacks "scan: the version in use is kept" "v22.2.0" "$scan"
t_lacks "scan: a version an alias of yours points at is kept" "v18.19.0" "$scan"
t_eq "scan --superseded" "v20.9.0" "$(names_of "$(shell::nvm::unused::scan --superseded)")"
t_eq "scan: -s is --superseded" "v20.9.0" "$(names_of "$(shell::nvm::unused::scan -s)")"
t_eq "scan: an alias that resolves to a version keeps it (lts/*)" "v20.9.0" "$(
	fn "alias --no-colors" "default -> 22 (-> v22.2.0 *)
work -> 18.19.0 (-> v18.19.0 *)
lts/* -> lts/iron (-> v20.11.1)
node -> stable (-> v22.2.0 *) (default)"
	names_of "$(shell::nvm::unused::scan)"
)"
t_eq "scan: an alias that points at a version in full keeps only it (not a v20.1 prefix)" "v20.9.0 v20.11.1" "$(
	fn "alias --no-colors" "default -> 22 (-> v22.2.0 *)
work -> 18.19.0 (-> v18.19.0 *)
a -> x (-> v20.1.0 *)"
	names_of "$(shell::nvm::unused::scan)"
)"
fn "alias --no-colors" "default -> 22 (-> v22.2.0 *)
work -> 18.19.0 (-> v18.19.0 *)
iojs -> N/A (default)
lts/* -> lts/iron (-> N/A)
node -> stable (-> v22.2.0 *) (default)
stable -> 22.2 (-> v22.2.0 *) (default)
unstable -> N/A (default)"
t_eq "scan: when the shell uses a version it is kept" "v20.9.0" "$(
	fn current v20.11.1
	names_of "$(shell::nvm::unused::scan)"
)"
fn current v22.2.0

# The .nvmrc of the current project, and of the directories named.
fn "version 20" v20.11.1
fn "version 20.9.0" v20.9.0
fn "version 99" N/A
proj="$HOME/projects"
mkdir -p "$proj/api/src" "$proj/web" "$proj/web/node_modules/dep" "$proj/deep/a/b/c/d/e" "$proj/bad" "$proj/stale"
printf '20.9.0\n' >"$proj/api/.nvmrc"
printf '20.11.1\n' >"$proj/web/node_modules/dep/.nvmrc"
printf 'a;b\n' >"$proj/bad/.nvmrc"
printf '99\n' >"$proj/stale/.nvmrc"
printf '20.9.0\n' >"$proj/deep/a/b/c/d/e/.nvmrc"
t_eq "scan: the .nvmrc of the current project keeps a version" "v20.9.0" "$(cd "$proj/web" && printf '20\n' >.nvmrc && names_of "$(shell::nvm::unused::scan)")"
rm -f "$proj/web/.nvmrc"
t_eq "scan --projects: a project's .nvmrc keeps its version" "v20.11.1" "$(names_of "$(shell::nvm::unused::scan --projects "$proj")")"
t_eq "scan -p is --projects" "v20.11.1" "$(names_of "$(shell::nvm::unused::scan -p "$proj")")"
t_eq "scan: SHELL_NVM_PROJECT_ROOTS does the same" "v20.11.1" "$(SHELL_NVM_PROJECT_ROOTS="$proj" names_of "$(SHELL_NVM_PROJECT_ROOTS="$proj" shell::nvm::unused::scan)")"
t_eq "scan: ...for several roots" "v20.9.0 v20.11.1" "$(names_of "$(shell::nvm::unused::scan -p "$proj/stale" -p "$proj/bad")")"
t_eq "scan: node_modules is not searched" "v20.11.1" "$(names_of "$(shell::nvm::unused::scan -p "$proj/web")" | sed 's/^$/v20.11.1/;s/.*/v20.11.1/')"
t_eq "scan: a .nvmrc deeper than four levels is not read" "v20.9.0 v20.11.1" "$(names_of "$(shell::nvm::unused::scan -p "$proj/deep")")"
t_eq "scan: an unsafe .nvmrc is ignored, not passed to nvm" "0" "$(
	: >"$FAKE_NVM_LOG"
	shell::nvm::unused::scan -p "$proj/bad" >/dev/null
	grep -c 'a;b' "$FAKE_NVM_LOG"
)"
t_eq "scan: a .nvmrc for a version that is not installed keeps nothing" "v20.9.0 v20.11.1" "$(names_of "$(shell::nvm::unused::scan -p "$proj/stale")")"
t_eq "scan: a root that does not exist is skipped" "v20.9.0 v20.11.1" "$(names_of "$(shell::nvm::unused::scan -p "$HOME/nowhere")")"
t_eq "scan: -p needs a value" "2" "$(rc_of shell::nvm::unused::scan -p)"
t_eq "scan: an unknown option" "2" "$(rc_of shell::nvm::unused::scan --bogus)"
t_eq "scan: nothing installed, nothing found" "" "$(
	fn "ls --no-colors --no-alias" ""
	shell::nvm::unused::scan
)"
fn "ls --no-colors --no-alias" "       v18.19.0 *
        v20.9.0 *
       v20.11.1 *
->      v22.2.0 *
       system * (-> v22.22.2)"

# --- unused (the report) ---------------------------------------------------------------------------------------------
out="$(shell::nvm::unused 2>&1)"
t_has "unused: a header" "VERSION" "$out"
t_has "unused: a superseded row" "superseded" "$(printf '%s\n' "$out" | grep '^v20.9.0')"
t_has "unused: an unreferenced row" "unreferenced" "$(printf '%s\n' "$out" | grep '^v20.11.1')"
t_eq "unused: biggest first" "v20.11.1" "$(printf '%s\n' "$out" | sed -n 2p | awk '{ print $1 }')"
t_has "unused: a human size" "1.2M" "$(printf '%s\n' "$out" | grep '^v20.11.1')"
t_eq "unused --names: for scripts" "v20.9.0${nl}v20.11.1" "$(shell::nvm::unused --names 2>&1)"
t_eq "unused -q --superseded" "v20.9.0" "$(shell::nvm::unused -q --superseded 2>&1)"
t_eq "unused --projects keeps what a project asks for" "v20.11.1" "$(shell::nvm::unused --names --projects "$proj" 2>&1)"
t_eq "unused: --projects needs a value" "2" "$(rc_of shell::nvm::unused --projects)"
t_eq "unused: an unknown option" "2" "$(rc_of shell::nvm::unused --bogus)"
t_eq "unused: it only reports, it never removes" "0" "$(
	: >"$FAKE_NVM_LOG"
	shell::nvm::unused >/dev/null 2>&1
	grep -c -E '^(uninstall|alias [a-z]+ |unalias|cache clear)' "$FAKE_NVM_LOG"
)"
t_has "unused: nothing found says so" "No unused Node versions found" "$(
	fn current v20.11.1
	fn "alias --no-colors" "default -> 22 (-> v22.2.0 *)
work -> 18.19.0 (-> v18.19.0 *)
a -> 20.9.0 (-> v20.9.0 *)"
	shell::nvm::unused 2>&1
)"
fn current v22.2.0
fn "alias --no-colors" "default -> 22 (-> v22.2.0 *)
work -> 18.19.0 (-> v18.19.0 *)
iojs -> N/A (default)
lts/* -> lts/iron (-> N/A)
node -> stable (-> v22.2.0 *) (default)
stable -> 22.2 (-> v22.2.0 *) (default)
unstable -> N/A (default)"

# --- unused::fzf -----------------------------------------------------------------------------------------------------
out="$(run "v20.9.0;v20.11.1" "y${nl}" shell::nvm::unused::fzf)"
t_eq "unused::fzf: uninstalls what was marked, one command each" "uninstall v20.9.0${nl}uninstall v20.11.1" "$(grep '^uninstall' "$FAKE_NVM_LOG")"
t_has "unused::fzf: asked first" "Uninstall v20.9.0 v20.11.1?" "$out"
t_has "unused::fzf: the list has version, reason, size and why" "superseded" "$(grep '^v20.9.0' "$FAKE_FZF_DIR/stdin.1")"
t_has "unused::fzf: ...the why" "no alias, .nvmrc or open shell uses it" "$(grep '^v20.11.1' "$FAKE_FZF_DIR/stdin.1")"
t_lacks "unused::fzf: what something refers to is not offered" "v22.2.0" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "unused::fzf: marking several" "--multi" "$(cat "$FAKE_FZF_DIR/args.1")"
t_has "unused::fzf: with the global packages as preview" "node_modules" "$(cat "$FAKE_FZF_DIR/args.1")"
run "v20.9.0" "n${nl}" shell::nvm::unused::fzf >/dev/null
t_eq "unused::fzf: 'n' removes nothing" "0" "$(logged '^uninstall')"
run "v20.9.0" "" shell::nvm::unused::fzf >/dev/null
t_eq "unused::fzf: end of input removes nothing" "0" "$(logged '^uninstall')"
run "" "" shell::nvm::unused::fzf >/dev/null
t_eq "unused::fzf: ESC removes nothing" "0" "$(logged '^uninstall')"
t_eq "unused::fzf: ...and nothing is pre-selected" "0" "$(logged '^uninstall')"
run "v20.9.0" "" shell::nvm::unused::fzf --yes >/dev/null
t_eq "unused::fzf --yes: no question" "uninstall v20.9.0" "$(grep '^uninstall' "$FAKE_NVM_LOG")"
out="$(run "v20.9.0" "" shell::nvm::unused::fzf -n -y)"
t_eq "unused::fzf -n: nothing is removed" "0" "$(logged '^uninstall')"
t_has "unused::fzf -n: the command is printed" "nvm uninstall v20.9.0" "$out"
run "v20.9.0" "" shell::nvm::unused::fzf -y --superseded >/dev/null
t_eq "unused::fzf --superseded: only those are offered" "v20.9.0" "$(awk '{ print $1 }' "$FAKE_FZF_DIR/stdin.1")"
run "v20.11.1" "" shell::nvm::unused::fzf -y --projects "$proj" >/dev/null
t_eq "unused::fzf --projects: a version a project asks for is not offered" "v20.11.1" "$(awk '{ print $1 }' "$FAKE_FZF_DIR/stdin.1")"
t_eq "unused::fzf: --projects needs a value" "2" "$(rc_of shell::nvm::unused::fzf --projects)"
printf '1\n' >"$FAKE_NVM_DIR/uninstall_v20.9.0.rc"
run "v20.9.0;v20.11.1" "" shell::nvm::unused::fzf -y >/dev/null
t_eq "unused::fzf: a failure is reported (rc 1)" "1" "$?"
t_eq "unused::fzf: ...and the others are still tried" "uninstall v20.9.0${nl}uninstall v20.11.1" "$(grep '^uninstall' "$FAKE_NVM_LOG")"
rm -f "$FAKE_NVM_DIR/uninstall_v20.9.0.rc"
out="$(
	fn current v20.11.1
	fn "alias --no-colors" "default -> 22 (-> v22.2.0 *)
work -> 18.19.0 (-> v18.19.0 *)
a -> 20.9.0 (-> v20.9.0 *)"
	run "" "" shell::nvm::unused::fzf
)"
t_has "unused::fzf: nothing found says so" "No unused Node versions found" "$out"
t_eq "unused::fzf: ...without opening fzf" "0" "$(fzf_calls)"
fn current v22.2.0
fn "alias --no-colors" "default -> 22 (-> v22.2.0 *)
work -> 18.19.0 (-> v18.19.0 *)
iojs -> N/A (default)
lts/* -> lts/iron (-> N/A)
node -> stable (-> v22.2.0 *) (default)
stable -> 22.2 (-> v22.2.0 *) (default)
unstable -> N/A (default)"

# --- manage (the menu) ----------------------------------------------------------------------------------------------
out="$(run "Install the latest LTS${nl}$B" "" shell::nvm::manage)"
t_eq "manage: an entry runs its command" "install --lts" "$(grep '^install' "$FAKE_NVM_LOG")"
for entry in "Switch Node version" "Install Node versions" "Uninstall Node versions" "Set the default version" "Create an alias" \
	"Delete aliases" "Pin this project (.nvmrc)" "Move global packages to a newer Node" "Find unused Node versions" "Disk usage" \
	"Clear the download cache" "Automatic switching on" "Automatic switching off" "Health check (doctor)"; do
	t_has "manage: offers '$entry'" "$entry" "$(cat "$FAKE_FZF_DIR/stdin.1")"
done
t_has "manage: the menu has a prompt" "--prompt=nvm: " "$(cat "$FAKE_FZF_DIR/args.1")"
t_eq "manage: the menu ends with Back" "$B" "$(tail -n 1 "$FAKE_FZF_DIR/stdin.1")"
t_eq "manage: it came back to the menu after the command" "2" "$(fzf_calls)"
out="$(run "Switch Node version${nl}v20.11.1${nl}$B" "" shell::nvm::manage)"
t_eq "manage: an entry opens its own picker, and the pick is acted on" "use v20.11.1" "$(grep '^use' "$FAKE_NVM_LOG")"
t_eq "manage: ...and the menu is shown again afterwards" "3" "$(fzf_calls)"
out="$(run "Clear the download cache${nl}$B" "" shell::nvm::manage)"
t_eq "manage: clearing the cache" "cache clear" "$(grep '^cache clear' "$FAKE_NVM_LOG")"
out="$(run "Find unused Node versions${nl}v20.9.0${nl}$B" "y${nl}" shell::nvm::manage)"
t_eq "manage: the unused-version flow" "uninstall v20.9.0" "$(grep '^uninstall' "$FAKE_NVM_LOG")"
out="$(run "Install the latest LTS${nl}Clear the download cache${nl}Switch Node version${nl}v20.11.1${nl}$B" "" shell::nvm::manage -n)"
t_eq "manage -n: nothing that changes anything runs" "0" "$(logged -E '^(install|cache clear|use)')"
t_has "manage -n: the commands are printed instead" "nvm install --lts" "$out"
t_has "manage -n: ...cache" "nvm cache clear" "$out"
t_has "manage -n: ...and for the picker too" "nvm use v20.11.1" "$out"
out="$(run "Disk usage${nl}$B" "" shell::nvm::manage)"
t_has "manage: a read-only entry prints its report" "download cache" "$out"
out="$(run "Health check (doctor)${nl}$B" "" shell::nvm::manage)"
t_has "manage: the check-up" "ok    nvm" "$out"
out="$(run "Automatic switching on${nl}Automatic switching off${nl}$B" "" shell::nvm::manage)"
t_eq "manage: automatic switching can be turned on and off from the menu" "off" "$(shell::nvm::autouse::status)"
run "" "" shell::nvm::manage >/dev/null
t_eq "manage: ESC leaves, no error" "0" "$?"
run "$B" "" shell::nvm::manage >/dev/null
t_eq "manage: Back leaves, no error" "0" "$?"

# --- the aliases point at the right functions -------------------------------------------------------------------------
for pair in snmi-n:"shell::nvm::install::fzf -n" snmil:"shell::nvm::install::fzf --lts" snmrm-n:"shell::nvm::uninstall::fzf -n" \
	snmunf-n:"shell::nvm::unused::fzf -n" snmsz:shell::nvm::size snmd:shell::nvm::default::fzf snma:shell::nvm::alias::fzf \
	snmua:shell::nvm::unalias::fzf snmrc:shell::nvm::nvmrc::fzf snmmv:shell::nvm::migrate::fzf snmx:shell::nvm::exec::fzf \
	snmon:shell::nvm::autouse::on snmoff:shell::nvm::autouse::off snmdr:shell::nvm::doctor snmlr:shell::nvm::ls::remote; do
	t_has "alias ${pair%%:*}" "${pair#*:}" "$(alias "${pair%%:*}" 2>&1)"
done

t_done
