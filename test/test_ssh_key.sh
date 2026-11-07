#!/usr/bin/env bash
# shell::ssh::key::*, ::permission::fix, ::agent::* and ::known_hosts::* (src/lib/ssh_key.sh, ssh_agent.sh,
# ssh_known_hosts.sh).
#
# ssh-keygen is the real one (it is deterministic and local); when it is not installed the parts that need
# it are skipped. ssh-add, ssh-agent and ssh-keyscan are fakes: they log their arguments to $FAKE_LOG, ssh-add
# -l exits with $FAKE_ADD_L_RC (0 = keys, 1 = none, 2 = no agent), the others with $FAKE_RC.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

mkdir -p "$HOME/bin"
cat >"$HOME/bin/ssh-add" <<'FAKE'
#!/bin/sh
{
	printf 'ssh-add'
	for a in "$@"; do printf ' [%s]' "$a"; done
	printf '\n'
} >>"$FAKE_LOG"
if [ "$1" = "-l" ] || [ "$1" = "-L" ]; then
	[ "${FAKE_ADD_L_RC:-0}" -eq 0 ] && echo "256 SHA256:fake key (ED25519)"
	exit "${FAKE_ADD_L_RC:-0}"
fi
exit "${FAKE_RC:-0}"
FAKE
cat >"$HOME/bin/ssh-agent" <<'FAKE'
#!/bin/sh
{
	printf 'ssh-agent'
	for a in "$@"; do printf ' [%s]' "$a"; done
	printf '\n'
} >>"$FAKE_LOG"
if [ "$1" = "-s" ]; then
	printf 'SSH_AUTH_SOCK=/tmp/fake-agent/agent.1; export SSH_AUTH_SOCK;\nSSH_AGENT_PID=4242; export SSH_AGENT_PID;\necho Agent pid 4242;\n'
fi
exit "${FAKE_RC:-0}"
FAKE
cat >"$HOME/bin/ssh-keyscan" <<'FAKE'
#!/bin/sh
{
	printf 'ssh-keyscan'
	for a in "$@"; do printf ' [%s]' "$a"; done
	printf '\n'
} >>"$FAKE_LOG"
[ -n "${FAKE_SCAN_EMPTY-}" ] && exit 1
port=22
while [ $# -gt 1 ]; do
	[ "$1" = "-p" ] && port="$2"
	shift
done
name="$1"
[ "$port" = "22" ] || name="[$1]:$port"
printf '%s %s\n' "$name" "$FAKE_SCAN_KEY"
FAKE
chmod +x "$HOME/bin/ssh-add" "$HOME/bin/ssh-agent" "$HOME/bin/ssh-keyscan"
export PATH="$HOME/bin:$PATH" FAKE_LOG="$HOME/fake.log"
: >"$FAKE_LOG"
nostdin() { "$@" </dev/null; }
last() { tail -n 1 "$FAKE_LOG"; }

have_keygen=0
command -v ssh-keygen >/dev/null 2>&1 && have_keygen=1

# --- agent ----------------------------------------------------------------------
unset SSH_AUTH_SOCK SSH_AGENT_PID
FAKE_ADD_L_RC=2 t_rc "agent list: no agent" 1 nostdin shell::ssh::agent::list
FAKE_ADD_L_RC=1 t_rc "agent list: no key" 8 nostdin shell::ssh::agent::list
FAKE_ADD_L_RC=0 t_rc "agent list: keys" 0 nostdin shell::ssh::agent::list
t_has "agent list prints the fingerprints" "SHA256:fake" "$(FAKE_ADD_L_RC=0 nostdin shell::ssh::agent::list 2>&1)"
: >"$FAKE_LOG"
FAKE_ADD_L_RC=0 nostdin shell::ssh::agent::list --public >/dev/null 2>&1
t_eq "agent list --public is ssh-add -L" "ssh-add [-L]" "$(last)"
t_has "agent start dry run" 'eval "$(ssh-agent -s)"' "$(nostdin shell::ssh::agent::start -n 2>&1)"
FAKE_ADD_L_RC=2 shell::ssh::agent::start >/dev/null 2>&1
t_eq "agent start: SSH_AUTH_SOCK is set in THIS shell" "/tmp/fake-agent/agent.1" "${SSH_AUTH_SOCK-}"
t_eq "agent start: SSH_AGENT_PID is set in THIS shell" "4242" "${SSH_AGENT_PID-}"
: >"$FAKE_LOG"
FAKE_ADD_L_RC=0 t_has "agent start: an agent that answers is reused" "already available" "$(FAKE_ADD_L_RC=0 nostdin shell::ssh::agent::start 2>&1)"
t_lacks "agent start: ssh-agent was not started again" "ssh-agent" "$(cat "$FAKE_LOG")"
echo key >"$HOME/k1"
echo key >"$HOME/k2"
: >"$FAKE_LOG"
FAKE_ADD_L_RC=1 nostdin shell::ssh::agent::add -t 600 "$HOME/k1" "$HOME/k2" >/dev/null 2>&1
t_eq "agent add: lifetime and keys" "ssh-add [-t] [600] [$HOME/k1] [$HOME/k2]" "$(last)"
: >"$FAKE_LOG"
FAKE_ADD_L_RC=1 nostdin shell::ssh::agent::add >/dev/null 2>&1
t_eq "agent add: no key means the defaults" "ssh-add" "$(last)"
FAKE_ADD_L_RC=2 t_rc "agent add: no agent" 1 nostdin shell::ssh::agent::add "$HOME/k1"
t_rc "agent add: missing key" 3 nostdin shell::ssh::agent::add "$HOME/nokey"
t_rc "agent add: bad lifetime" 2 nostdin shell::ssh::agent::add -t abc "$HOME/k1"
t_rc "agent add: unknown option" 2 nostdin shell::ssh::agent::add --nope
if [ "$(shell::os::type)" != "macos" ]; then
	t_rc "agent add: --keychain is macOS only" 4 nostdin shell::ssh::agent::add --keychain "$HOME/k1"
fi
t_rc "agent add: dry run needs no agent" 0 nostdin shell::ssh::agent::add -n "$HOME/nokey"
: >"$FAKE_LOG"
FAKE_ADD_L_RC=1 nostdin shell::ssh::agent::remove "$HOME/k1" >/dev/null 2>&1
t_eq "agent remove" "ssh-add [-d] [$HOME/k1]" "$(last)"
t_rc "agent remove: needs a key" 2 nostdin shell::ssh::agent::remove
t_rc "agent remove: an option-looking key" 2 nostdin shell::ssh::agent::remove -- -D
t_rc "agent remove: missing key" 3 nostdin shell::ssh::agent::remove "$HOME/nokey"
: >"$FAKE_LOG"
FAKE_ADD_L_RC=1 nostdin shell::ssh::agent::clear >/dev/null 2>&1
t_eq "agent clear" "ssh-add [-D]" "$(last)"
: >"$FAKE_LOG"
shell::ssh::agent::stop >/dev/null 2>&1
t_eq "agent stop: ssh-agent -k" "ssh-agent [-k]" "$(last)"
t_eq "agent stop: the variables are gone" "" "${SSH_AUTH_SOCK-}${SSH_AGENT_PID-}"
t_rc "agent stop: nothing to stop" 3 nostdin shell::ssh::agent::stop
t_has "agent stop dry run" "ssh-agent -k" "$(nostdin shell::ssh::agent::stop -n 2>&1)"

# --- keys -----------------------------------------------------------------------
if [ "$have_keygen" -eq 1 ]; then
	mkdir -p "$SHELL_SSH_DIR" && chmod 700 "$SHELL_SSH_DIR"
	ssh-keygen -q -t ed25519 -N '' -C "me@test" -f "$SHELL_SSH_DIR/id_ed25519"
	ssh-keygen -q -t ed25519 -N '' -C "second" -f "$SHELL_SSH_DIR/work"
	key="$SHELL_SSH_DIR/id_ed25519"

	t_eq "public: same line as the .pub file" "$(cat "$key.pub")" "$(nostdin shell::ssh::key::public "$key")"
	t_rc "public --save: refuses to overwrite" 7 nostdin shell::ssh::key::public --save "$key"
	rm -f "$key.pub"
	t_rc "public --save: writes the .pub" 0 nostdin shell::ssh::key::public --save "$key"
	t_eq "public --save: a public key" "ssh-ed25519" "$(cut -d' ' -f1 <"$key.pub")"
	t_eq "public --save: mode 644" "644" "$(shell::fs::stat mode "$key.pub")"
	t_rc "public --save --force: overwrites" 0 nostdin shell::ssh::key::public --save --force "$key"
	t_rc "public: missing key" 3 nostdin shell::ssh::key::public "$SHELL_SSH_DIR/nokey"
	t_rc "public: a key is required" 2 nostdin shell::ssh::key::public
	t_has "public: dry run" "ssh-keygen -y -f" "$(nostdin shell::ssh::key::public -n "$key" 2>&1)"
	t_has "public: dry run with --save redirects" "> $key.pub" "$(nostdin shell::ssh::key::public -n -s "$key" 2>&1)"
	t_rc "public: not a key" 1 nostdin shell::ssh::key::public "$HOME/k1"

	fp="$(nostdin shell::ssh::key::fingerprint "$key.pub")"
	t_has "fingerprint: SHA256 by default" "SHA256:" "$fp"
	t_has "fingerprint: comment shown" "me@test" "$fp"
	t_has "fingerprint --md5" "MD5:" "$(nostdin shell::ssh::key::fingerprint --md5 "$key.pub")"
	t_eq "fingerprint: no argument lists every .pub" "2" "$(nostdin shell::ssh::key::fingerprint | wc -l | tr -d ' ')"
	t_eq "fingerprint: prints data only" "1" "$(nostdin shell::ssh::key::fingerprint "$key.pub" | wc -l | tr -d ' ')"
	t_rc "fingerprint: missing key" 3 nostdin shell::ssh::key::fingerprint "$SHELL_SSH_DIR/nokey"
	t_rc "fingerprint: unknown option" 2 nostdin shell::ssh::key::fingerprint --nope

	t_rc "comment: changes it" 0 nostdin shell::ssh::key::comment "$key" "new@comment"
	t_has "comment: stored in the key" "new@comment" "$(ssh-keygen -y -f "$key")"
	t_rc "comment: needs both arguments" 2 nostdin shell::ssh::key::comment "$key"
	t_rc "comment: missing key" 3 nostdin shell::ssh::key::comment "$SHELL_SSH_DIR/nokey" x
	t_has "passphrase: dry run" "ssh-keygen -p -f $key" "$(nostdin shell::ssh::key::passphrase -n "$key" 2>&1)"
	t_rc "passphrase: missing key" 3 nostdin shell::ssh::key::passphrase "$SHELL_SSH_DIR/nokey"

	# --- candidates / permissions -------------------------------------------------
	printf 'Host x\n' >"$SHELL_SSH_DIR/config"
	printf 'h ssh-ed25519 AAAA\n' >"$SHELL_SSH_DIR/known_hosts"
	printf 'ssh-ed25519 AAAA\n' >"$SHELL_SSH_DIR/authorized_keys"
	t_eq "candidates: private keys only" "$SHELL_SSH_DIR/id_ed25519
$SHELL_SSH_DIR/work" "$(_shell::ssh::key::candidates)"
	chmod 755 "$SHELL_SSH_DIR"
	chmod 644 "$key" "$SHELL_SSH_DIR/work" "$SHELL_SSH_DIR/config" "$SHELL_SSH_DIR/authorized_keys"
	chmod 600 "$key.pub" "$SHELL_SSH_DIR/known_hosts"
	before="$(shell::fs::stat mode "$key")"
	t_has "fix -n lists the chmod commands" "chmod 600 $key" "$(shell::ssh::permission::fix -n 2>&1)"
	t_eq "fix -n changes nothing" "$before" "$(shell::fs::stat mode "$key")"
	shell::ssh::permission::fix >/dev/null 2>&1
	t_eq "fix: directory 700" "700" "$(shell::fs::stat mode "$SHELL_SSH_DIR")"
	t_eq "fix: private key 600" "600" "$(shell::fs::stat mode "$key")"
	t_eq "fix: second private key 600" "600" "$(shell::fs::stat mode "$SHELL_SSH_DIR/work")"
	t_eq "fix: config 600" "600" "$(shell::fs::stat mode "$SHELL_SSH_DIR/config")"
	t_eq "fix: authorized_keys 600" "600" "$(shell::fs::stat mode "$SHELL_SSH_DIR/authorized_keys")"
	t_eq "fix: public key 644" "644" "$(shell::fs::stat mode "$key.pub")"
	t_eq "fix: known_hosts 644" "644" "$(shell::fs::stat mode "$SHELL_SSH_DIR/known_hosts")"
	t_has "fix: a second run has nothing to do" "already right" "$(shell::ssh::permission::fix 2>&1)"
	ln -s "$key" "$SHELL_SSH_DIR/link_to_key"
	chmod 644 "$key"
	shell::ssh::permission::fix >/dev/null 2>&1
	t_eq "fix: a symlink is left alone, its target is fixed once" "600" "$(shell::fs::stat mode "$key")"
	t_rc "fix: no such directory" 3 nostdin shell::ssh::permission::fix -d "$HOME/nodir"
	t_rc "fix: unknown option" 2 nostdin shell::ssh::permission::fix --nope

	# --- known_hosts --------------------------------------------------------------
	rm -f "$SHELL_SSH_KNOWN_HOSTS_FILE"
	export FAKE_SCAN_KEY
	FAKE_SCAN_KEY="$(cut -d' ' -f1,2 <"$key.pub")"
	: >"$FAKE_LOG"
	t_has "scan prints the keys" "ssh-ed25519" "$(nostdin shell::ssh::known_hosts::scan example.org 2>&1)"
	t_eq "scan: plain ssh-keyscan, nothing hashed or written" "ssh-keyscan [example.org]" "$(last)"
	t_rc "scan without --add writes nothing" 1 test -f "$SHELL_SSH_KNOWN_HOSTS_FILE"
	t_has "scan --port -t" "ssh-keyscan [-p] [2222] [-t] [ed25519] [-H] [example.org]" "$(
		: >"$FAKE_LOG"
		nostdin shell::ssh::known_hosts::scan --add -p 2222 -t ed25519 example.org >/dev/null 2>&1
		last
	)"
	t_has "scan --add: written as [host]:port" "[example.org]:2222 ssh-ed25519" "$(cat "$SHELL_SSH_KNOWN_HOSTS_FILE")"
	t_has "scan --add: fingerprints shown first" "SHA256:" "$(nostdin shell::ssh::known_hosts::scan --add other.org 2>&1)"
	t_has "scan --add: known host is left alone" "left unchanged" "$(nostdin shell::ssh::known_hosts::scan --add other.org 2>&1)"
	t_eq "scan --add: no duplicate entry" "1" "$(grep -c '^other.org ' "$SHELL_SSH_KNOWN_HOSTS_FILE")"
	FAKE_SCAN_EMPTY=1 t_rc "scan: host that answers nothing" 1 nostdin shell::ssh::known_hosts::scan dead.example
	t_has "scan --add dry run" "ssh-keyscan -H example.org >> $SHELL_SSH_KNOWN_HOSTS_FILE" "$(nostdin shell::ssh::known_hosts::scan -n --add example.org 2>&1)"
	t_rc "scan: a host is required" 2 nostdin shell::ssh::known_hosts::scan
	t_rc "scan: bad host" 2 nostdin shell::ssh::known_hosts::scan "a b"
	t_rc "scan: bad type" 2 nostdin shell::ssh::known_hosts::scan -t "x;y" example.org
	t_rc "scan: bad port" 2 nostdin shell::ssh::known_hosts::scan -p 0 example.org

	t_rc "find: hashed entry is found" 0 nostdin shell::ssh::known_hosts::find other.org
	t_rc "find: with --port" 0 nostdin shell::ssh::known_hosts::find -p 2222 example.org
	t_rc "find: unknown host" 3 nostdin shell::ssh::known_hosts::find nobody.example
	t_rc "find: a host is required" 2 nostdin shell::ssh::known_hosts::find
	t_rc "find: option-looking host" 2 nostdin shell::ssh::known_hosts::find -- -x
	t_rc "remove: known host" 0 nostdin shell::ssh::known_hosts::remove other.org
	t_rc "remove: it is gone" 3 nostdin shell::ssh::known_hosts::find other.org
	t_rc "remove: unknown host" 3 nostdin shell::ssh::known_hosts::remove other.org
	t_eq "remove: the old file is kept" "yes" "$([ -f "$SHELL_SSH_KNOWN_HOSTS_FILE.old" ] && echo yes)"
	t_has "remove dry run" "ssh-keygen -R '[example.org]:2222'" "$(nostdin shell::ssh::known_hosts::remove -n -p 2222 example.org 2>&1)"
else
	echo "  (skipped: ssh-keygen is not installed)"
fi

# --- every function has a help page ----------------------------------------------
for fn in key::public key::fingerprint key::passphrase key::comment permission::fix agent::start agent::stop agent::list agent::add agent::add::fzf agent::remove agent::clear known_hosts::find known_hosts::remove known_hosts::scan; do
	t_has "help: shell::ssh::$fn" "USAGE:" "$("shell::ssh::$fn" --help 2>&1)"
done

t_done
