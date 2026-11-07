#!/usr/bin/env bash
# shell::ssh::config::*, shell::ssh::connect::fzf and shell::ssh::agent::add::fzf (src/lib/ssh_config.sh,
# ssh_agent.sh): what is written to ~/.ssh/config (and where), what is listed, what is removed (and what is
# refused), and what a pick in fzf turns into.
#
# awk and the file system are real. ssh and ssh-add are fakes that log their arguments to $FAKE_LOG ("ssh -G"
# answers with canned lines). The fake fzf logs its candidates and answers the Nth call with line N of
# $FAKE_FZF_PICKS: a pick is matched as text against the candidate lines, `a;b` picks two, empty is ESC.
# The y/n question of `remove` reads the standard input of the function under test.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

mkdir -p "$HOME/bin" "$HOME/fzfdir"
cat >"$HOME/bin/ssh" <<'FAKE'
#!/bin/sh
{
	printf 'ssh'
	for a in "$@"; do printf ' [%s]' "$a"; done
	printf '\n'
} >>"$FAKE_LOG"
for a in "$@"; do
	if [ "$a" = "-G" ]; then
		printf 'user deploy\nhostname 10.0.0.5\nport 2222\nidentityfile ~/.ssh/id_rsa\nkexalgorithms x\ncompression no\n'
	fi
done
exit 0
FAKE
cat >"$HOME/bin/ssh-add" <<'FAKE'
#!/bin/sh
{
	printf 'ssh-add'
	for a in "$@"; do printf ' [%s]' "$a"; done
	printf '\n'
} >>"$FAKE_LOG"
[ "$1" = "-l" ] && exit 1
exit 0
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
chmod +x "$HOME/bin/ssh" "$HOME/bin/ssh-add" "$HOME/bin/fzf"
export PATH="$HOME/bin:$PATH" FAKE_LOG="$HOME/fake.log" FAKE_FZF_DIR="$HOME/fzfdir" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_FZF_PICKS=""
: >"$FAKE_LOG"

C="$SHELL_SSH_CONFIG_FILE"
nostdin() { "$@" </dev/null; }
last() { tail -n 1 "$FAKE_LOG"; }
reset_fzf() {
	find "$FAKE_FZF_DIR" -maxdepth 1 -name '*.*' -delete
	rm -f "$FAKE_FZF_STATE"
	: >"$FAKE_LOG"
}
nl='
'

# --- add: a new file ----------------------------------------------------------
t_rc "add: new file" 0 nostdin shell::ssh::config::add web1 10.0.0.5
t_eq "add: minimal block" "Host web1
    HostName 10.0.0.5" "$(cat "$C")"
t_eq "add: a new config is mode 600 (ssh requires it)" "600" "$(shell::fs::stat mode "$C")"
t_eq "add: ~/.ssh is mode 700" "700" "$(shell::fs::stat mode "$SHELL_SSH_DIR")"
t_rc "add: an existing alias is refused" 7 nostdin shell::ssh::config::add web1 9.9.9.9
t_eq "add: and the file is untouched" "Host web1
    HostName 10.0.0.5" "$(cat "$C")"

# --- add: options, order, force, backup ---------------------------------------
cat >"$C" <<'CFG'
# my defaults
Include /nonexistent/*.conf

Host old1
    HostName 1.1.1.1
    User olduser

# staging box
Host stage
    HostName 2.2.2.2

Host shared1 shared2
    HostName 3.3.3.3

Match host *.corp
    User corpuser

Host *
    ServerAliveInterval 15
CFG
chmod 640 "$C"
key="$HOME/my keys/id one"
mkdir -p "$HOME/my keys" && echo k >"$key"
nostdin shell::ssh::config::add -u deploy -p 2222 -i "$key" -J bastion --keepalive 20 --forward-agent web2 10.0.0.6 >/dev/null 2>&1
t_has "add: every setting is written" "Host web2
    HostName 10.0.0.6
    User deploy
    Port 2222
    IdentityFile \"$key\"
    IdentitiesOnly yes
    ProxyJump bastion
    ServerAliveInterval 20
    ServerAliveCountMax 3
    ForwardAgent yes" "$(cat "$C")"
t_eq "add: order of Host lines" "old1 stage shared1 shared2 web2" "$(_shell::ssh::config::aliases "$C" | tr '\n' ' ' | sed 's/ $//')"
host_star_line="$(grep -n '^Host \*' "$C" | cut -d: -f1)"
web2_line="$(grep -n '^Host web2' "$C" | cut -d: -f1)"
t_eq "add: web2 precedes Host *" "yes" "$([ "$web2_line" -lt "$host_star_line" ] && echo yes)"
t_eq "add: the file keeps its mode" "640" "$(shell::fs::stat mode "$C")"
t_has "add: Match and Host * are intact" "Match host *.corp
    User corpuser" "$(cat "$C")"
t_eq "add: the backup holds the previous content" "1" "$(grep -c '^Host old1' "$SHELL_SSH_CONFIG_BACKUP_FILE")"
t_eq "add: the backup is mode 600" "600" "$(shell::fs::stat mode "$SHELL_SSH_CONFIG_BACKUP_FILE")"
t_eq "add: and it lacks the new block" "0" "$(grep -c 'web2' "$SHELL_SSH_CONFIG_BACKUP_FILE")"
nostdin shell::ssh::config::add --mux web3 10.0.0.7 >/dev/null 2>&1
t_has "add --mux: ControlMaster lines" "    ControlMaster auto
    ControlPath $SHELL_SSH_SOCKET_DIR/%C
    ControlPersist $SHELL_SSH_CONTROL_PERSIST" "$(cat "$C")"
t_eq "add --mux: the socket directory exists, private" "700" "$(shell::fs::stat mode "$SHELL_SSH_SOCKET_DIR")"
nostdin shell::ssh::config::add --force -u root web2 10.9.9.9 >/dev/null 2>&1
t_eq "add --force: one block, replaced" "1" "$(grep -c '^Host web2$' "$C")"
t_has "add --force: new content" "HostName 10.9.9.9" "$(cat "$C")"
t_lacks "add --force: old content is gone" "ProxyJump bastion" "$(cat "$C")"
t_eq "add --force: still before Host *" "yes" "$([ "$(grep -n '^Host web2$' "$C" | cut -d: -f1)" -lt "$(grep -n '^Host \*' "$C" | cut -d: -f1)" ] && echo yes)"
t_eq "add: the comment above stage survives" "1" "$(grep -c '^# staging box' "$C")"

# --- add: dry run and validation -----------------------------------------------
cp "$C" "$HOME/before.cfg"
out="$(nostdin shell::ssh::config::add -n -u me web9 10.0.0.9 2>&1)"
t_has "add -n shows the block" "Host web9
    HostName 10.0.0.9
    User me" "$out"
t_eq "add -n changes nothing" "$(cat "$HOME/before.cfg")" "$(cat "$C")"
t_has "add -n with an existing alias says replace" "Would replace" "$(nostdin shell::ssh::config::add -n --force web2 1.2.3.4 2>&1)"
t_rc "add: alias with a space" 2 nostdin shell::ssh::config::add "bad name" h
t_rc "add: wildcard alias" 2 nostdin shell::ssh::config::add "a*" h
t_rc "add: alias starting with a dash" 2 nostdin shell::ssh::config::add -- -x h
t_rc "add: bad hostname" 2 nostdin shell::ssh::config::add a "h;rm"
t_rc "add: bad user" 2 nostdin shell::ssh::config::add -u "a b" a h
t_rc "add: bad port" 2 nostdin shell::ssh::config::add -p 70000 a h
t_rc "add: bad jump" 2 nostdin shell::ssh::config::add -J "x y" a h
t_rc "add: identity with a double quote" 2 nostdin shell::ssh::config::add -i 'a"b' a h
t_rc "add: two arguments needed" 2 nostdin shell::ssh::config::add onlyalias
t_rc "add: unknown option" 2 nostdin shell::ssh::config::add --nope a h
t_eq "add: no invalid input reached the file" "$(cat "$HOME/before.cfg")" "$(cat "$C")"
t_rc "add: another file with -f" 0 nostdin shell::ssh::config::add -f "$HOME/other.cfg" x 10.1.1.1
t_eq "add -f: written there" "Host x
    HostName 10.1.1.1" "$(cat "$HOME/other.cfg")"

# --- list ----------------------------------------------------------------------
list="$(shell::ssh::config::list)"
t_has "list: header" "ALIAS" "$list"
t_has "list: a row with host and user" "old1" "$list"
t_has "list: user column" "olduser" "$list"
t_lacks "list: patterns are not aliases" "*" "$(shell::ssh::config::list --names)"
t_eq "list --names" "old1
stage
shared1
shared2
web3
web2" "$(shell::ssh::config::list --names)"
t_eq "list: 'Host *' and Match are skipped, a row per alias" "7" "$(printf '%s\n' "$list" | wc -l | tr -d ' ')"
t_eq "list: an unset value is a dash" "-" "$(printf '%s\n' "$list" | grep '^stage' | awk '{print $3}')"
t_rc "list: no such file" 3 nostdin shell::ssh::config::list -f "$HOME/nope"
: >"$HOME/empty.cfg"
t_rc "list: no alias" 8 nostdin shell::ssh::config::list -f "$HOME/empty.cfg"
printf 'Host a\n  HostName first\n  HostName second\n  Port 22 # trailing comment\n' >"$HOME/first.cfg"
t_eq "list: the first value of an option wins, comments are cut" "a first 22" "$(shell::ssh::config::list -f "$HOME/first.cfg" | sed -n 2p | awk '{print $1, $2, $4}')"

# --- show ----------------------------------------------------------------------
: >"$FAKE_LOG"
out="$(nostdin shell::ssh::config::show web2 2>&1)"
t_eq "show: asks ssh -G" "ssh [-G] [web2]" "$(last)"
t_has "show: useful settings" "hostname 10.0.0.5" "$out"
t_lacks "show: not the noise" "kexalgorithms" "$out"
t_has "show --all: everything" "kexalgorithms x" "$(nostdin shell::ssh::config::show --all web2 2>&1)"
nostdin shell::ssh::config::show -f "$C" web2 >/dev/null 2>&1
t_eq "show -f: ssh -F" "ssh [-F] [$C] [-G] [web2]" "$(last)"
t_rc "show: a host is required" 2 nostdin shell::ssh::config::show
t_rc "show: option-looking host" 2 nostdin shell::ssh::config::show -- -x
t_rc "show: missing config" 3 nostdin shell::ssh::config::show -f "$HOME/nope" web2

# --- remove --------------------------------------------------------------------
t_rc "remove: unknown alias" 3 nostdin shell::ssh::config::remove --yes nope
t_rc "remove: an alias on a shared Host line is refused" 4 nostdin shell::ssh::config::remove --yes shared1
t_eq "remove: and nothing changed" "yes" "$(grep -q '^Host shared1 shared2' "$C" && echo yes)"
cp "$C" "$HOME/before.cfg"
t_has "remove -n reports" "Would remove" "$(nostdin shell::ssh::config::remove -n stage 2>&1)"
t_eq "remove -n changes nothing" "$(cat "$HOME/before.cfg")" "$(cat "$C")"
printf 'n\n' | shell::ssh::config::remove stage >/dev/null 2>&1
t_rc "remove: no keeps the block" 0 grep -q '^Host stage$' "$C"
printf 'y\n' | shell::ssh::config::remove stage >/dev/null 2>&1
t_rc "remove: yes removes it" 1 grep -q '^Host stage$' "$C"
t_eq "remove: the comment that sat above it is kept" "1" "$(grep -c '^# staging box' "$C")"
t_eq "remove: neighbours are intact" "old1 shared1 shared2 web3 web2" "$(_shell::ssh::config::aliases "$C" | tr '\n' ' ' | sed 's/ $//')"
t_has "remove: Match and Host * are intact" "Match host *.corp" "$(cat "$C")"
t_has "remove: Host * is intact" "Host *
    ServerAliveInterval 15" "$(cat "$C")"
t_eq "remove: the file keeps its mode" "640" "$(shell::fs::stat mode "$C")"
nostdin shell::ssh::config::remove --yes web3 >/dev/null 2>&1
t_eq "remove --yes: no question, block gone" "0" "$(grep -c 'web3' "$C")"
t_eq "remove: no blank-line pile-up" "0" "$(awk 'BEGIN{b=0} /^[ \t]*$/ {b++; if (b>1) bad++} !/^[ \t]*$/ {b=0} END{print bad+0}' "$C")"
t_eq "remove: the backup is the file before the change" "1" "$(grep -c 'web3' "$SHELL_SSH_CONFIG_BACKUP_FILE")"
t_rc "remove: an alias is required" 2 nostdin shell::ssh::config::remove
t_rc "remove: no such file" 3 nostdin shell::ssh::config::remove -f "$HOME/nope" --yes a
printf 'Host only\n    HostName h\n' >"$HOME/one.cfg"
shell::ssh::config::remove -f "$HOME/one.cfg" --yes only >/dev/null 2>&1
t_eq "remove: the last block leaves an empty file" "0" "$(wc -c <"$HOME/one.cfg" | tr -d ' ')"

# --- connect::fzf / remove::fzf --------------------------------------------------
reset_fzf
FAKE_FZF_PICKS="web2" nostdin shell::ssh::connect::fzf >/dev/null 2>&1
t_eq "connect::fzf: the pick is connected to" "ssh [web2]" "$(last)"
t_eq "connect::fzf: candidates are the plain aliases" "old1
shared1
shared2
web2" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_has "connect::fzf: the preview is ssh -G" "ssh -F $C -G {}" "$(cat "$FAKE_FZF_DIR/args.1")"
reset_fzf
FAKE_FZF_PICKS="web2" nostdin shell::ssh::connect::fzf -p 2222 -A >/dev/null 2>&1
t_eq "connect::fzf: options go to connect" "ssh [-A] [-p] [2222] [web2]" "$(last)"
reset_fzf
t_has "connect::fzf -n: dry run" "ssh web2" "$(FAKE_FZF_PICKS="web2" nostdin shell::ssh::connect::fzf -n 2>&1)"
t_eq "connect::fzf -n: ssh did not run" "" "$(cat "$FAKE_LOG")"
reset_fzf
FAKE_FZF_PICKS="" t_rc "connect::fzf: ESC cancels" 9 nostdin shell::ssh::connect::fzf
t_eq "connect::fzf: and nothing ran" "" "$(cat "$FAKE_LOG")"
reset_fzf
FAKE_FZF_PICKS="x" nostdin shell::ssh::connect::fzf -F "$HOME/other.cfg" >/dev/null 2>&1
t_eq "connect::fzf -F: the list comes from that file" "x" "$(cat "$FAKE_FZF_DIR/stdin.1")"
t_rc "connect::fzf: a config without alias" 8 nostdin shell::ssh::connect::fzf -F "$HOME/empty.cfg"
t_rc "connect::fzf: no config file" 3 nostdin shell::ssh::connect::fzf -F "$HOME/nope"
reset_fzf
printf 'y\n' | FAKE_FZF_PICKS="shared2" shell::ssh::config::remove::fzf >/dev/null 2>&1
t_eq "remove::fzf: shares a Host line, so it is refused" "yes" "$(grep -q '^Host shared1 shared2' "$C" && echo yes)"
reset_fzf
printf 'y\n' | FAKE_FZF_PICKS="old1" shell::ssh::config::remove::fzf >/dev/null 2>&1
t_eq "remove::fzf: the pick is removed" "0" "$(grep -c '^Host old1' "$C")"
reset_fzf
FAKE_FZF_PICKS="" t_rc "remove::fzf: ESC cancels" 9 nostdin shell::ssh::config::remove::fzf

# --- agent::add::fzf ------------------------------------------------------------
t_rc "agent add::fzf: no private key" 8 nostdin shell::ssh::agent::add::fzf
printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nxx\n' >"$SHELL_SSH_DIR/id_a"
printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nxx\n' >"$SHELL_SSH_DIR/id_b"
printf 'ssh-ed25519 AAAA\n' >"$SHELL_SSH_DIR/id_a.pub"
reset_fzf
FAKE_FZF_PICKS="id_a;id_b" nostdin shell::ssh::agent::add::fzf -t 300 >/dev/null 2>&1
t_eq "agent add::fzf: marked keys go to ssh-add" "ssh-add [-t] [300] [$SHELL_SSH_DIR/id_a] [$SHELL_SSH_DIR/id_b]" "$(last)"
t_eq "agent add::fzf: only private keys are offered" "$SHELL_SSH_DIR/id_a
$SHELL_SSH_DIR/id_b" "$(cat "$FAKE_FZF_DIR/stdin.1")"
reset_fzf
FAKE_FZF_PICKS="" t_rc "agent add::fzf: ESC cancels" 9 nostdin shell::ssh::agent::add::fzf

# --- every function has a help page ----------------------------------------------
for fn in config::add config::list config::show config::remove config::remove::fzf connect::fzf; do
	t_has "help: shell::ssh::$fn" "USAGE:" "$("shell::ssh::$fn" --help 2>&1)"
done

t_done
