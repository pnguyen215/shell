#!/usr/bin/env bash
# shell::ssh::* client commands (src/lib/ssh_cmd.sh, ssh_transfer.sh, ssh_tunnel.sh): what is validated, which
# command line each function builds (dry run and real run), and what comes back (exit statuses, messages).
#
# ssh, scp, sftp, rsync and ssh-copy-id are fakes. Each logs its name and arguments, one "[arg]" per word,
# to $FAKE_LOG, copies its standard input to $FAKE_STDIN when that is set, and exits with $FAKE_RC. Nothing
# here touches the network.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

mkdir -p "$HOME/bin" "$HOME/empty"
cat >"$HOME/bin/fake" <<'FAKE'
#!/bin/sh
{
	printf '%s' "${0##*/}"
	for a in "$@"; do printf ' [%s]' "$a"; done
	printf '\n'
} >>"$FAKE_LOG"
if [ -n "${FAKE_STDIN-}" ]; then cat >"$FAKE_STDIN"; fi
exit "${FAKE_RC:-0}"
FAKE
chmod +x "$HOME/bin/fake"
for n in ssh scp sftp rsync ssh-copy-id; do cp "$HOME/bin/fake" "$HOME/bin/$n"; done
export PATH="$HOME/bin:$PATH" FAKE_LOG="$HOME/fake.log"
: >"$FAKE_LOG"

echo key >"$HOME/k"
echo cfg >"$HOME/cfg"
echo data >"$HOME/a.txt"
echo more >"$HOME/b.txt"
mkdir "$HOME/dir" "$HOME/dest"
printf 'echo hi\n' >"$HOME/s.sh"

reset() { : >"$FAKE_LOG"; }
last() { tail -n 1 "$FAKE_LOG"; }
# nostdin <command...>: run without a terminal on the standard input
nostdin() { "$@" </dev/null; }
# dry <command...> -> what a dry run prints
dry() { nostdin "$@" 2>&1; }

# --- validators ----------------------------------------------------------------
t_rc "target: user@host" 0 _shell::ssh::target::valid "deploy@10.0.0.5"
t_rc "target: alias" 0 _shell::ssh::target::valid "web-1.prod"
t_rc "target: ipv6 without brackets" 0 _shell::ssh::target::valid "::1"
t_rc "target: leading dash would be an option" 1 _shell::ssh::target::valid "-oProxyCommand=x"
t_rc "target: two @" 1 _shell::ssh::target::valid "a@b@c"
t_rc "target: leading @" 1 _shell::ssh::target::valid "@host"
t_rc "target: trailing @" 1 _shell::ssh::target::valid "user@"
t_rc "target: space" 1 _shell::ssh::target::valid "a b"
t_rc "target: semicolon" 1 _shell::ssh::target::valid "h;reboot"
t_rc "target: empty" 1 _shell::ssh::target::valid ""
t_rc "jump: list" 0 _shell::ssh::jump::valid "bastion1,ops@bastion2:2222"
t_rc "jump: leading dash" 1 _shell::ssh::jump::valid "-oProxyCommand=x"
t_rc "jump: space" 1 _shell::ssh::jump::valid "a b"
t_rc "option: Key=Value" 0 _shell::ssh::option::valid "Compression=yes"
t_rc "option: no value" 1 _shell::ssh::option::valid "Compression="
t_rc "option: no equals" 1 _shell::ssh::option::valid "Compression"
t_rc "option: bad key" 1 _shell::ssh::option::valid "Comp ression=yes"
t_rc "forward: plain" 0 _shell::ssh::forward::valid "8080:localhost:80"
t_rc "forward: bind and ipv6" 0 _shell::ssh::forward::valid "[::1]:8080:host:80"
t_rc "forward: unix socket" 0 _shell::ssh::forward::valid "3307:/var/run/mysqld/mysqld.sock"
t_rc "forward: needs a colon" 1 _shell::ssh::forward::valid "8080"
t_rc "forward: leading dash" 1 _shell::ssh::forward::valid "-8080:h:1"
t_rc "forward: space" 1 _shell::ssh::forward::valid "8080:h:80 x"
t_rc "spec: remote location" 0 _shell::ssh::spec::valid "deploy@web1:/var/www"
t_rc "spec: empty path is the home dir" 0 _shell::ssh::spec::valid "web1:"
t_rc "spec: no colon" 1 _shell::ssh::spec::valid "web1"
t_rc "spec: bad host" 1 _shell::ssh::spec::valid "-x:/tmp"
t_eq "path: a colon would look remote" "./a:b" "$(_shell::ssh::path::local "a:b")"
t_eq "path: absolute is left alone" "/x:y" "$(_shell::ssh::path::local "/x:y")"
t_eq "path: slash before the colon is left alone" "d/a:b" "$(_shell::ssh::path::local "d/a:b")"
t_eq "quote: plain words stay" "scp -r a/b host:/x" "$(_shell::ssh::quote scp -r a/b host:/x)"
t_eq "quote: space" "scp 'my file'" "$(_shell::ssh::quote scp "my file")"
t_eq "quote: empty word" "ssh ''" "$(_shell::ssh::quote ssh "")"
t_eq "quote: apostrophe" "echo 'it'\\''s'" "$(_shell::ssh::quote echo "it's")"

# --- connect / exec ------------------------------------------------------------
t_has "connect dry run" "ssh deploy@10.0.0.5" "$(dry shell::ssh::connect -n deploy@10.0.0.5)"
t_has "connect dry run: every option" "ssh -o Compression=yes -o ConnectTimeout=9 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o BatchMode=yes -o StrictHostKeyChecking=accept-new -v -C -A -p 2222 -i $HOME/k -F $HOME/cfg -J bastion deploy@h" \
	"$(dry shell::ssh::connect -n -p 2222 -i "$HOME/k" -J bastion -F "$HOME/cfg" -o Compression=yes --timeout 9 --keepalive 30 --batch --accept-new -v -C -A deploy@h)"
t_has "connect dry run: remote command with a pipe is quoted" "ssh web1 'ls -l | wc -l'" "$(dry shell::ssh::connect -n web1 'ls -l | wc -l')"
reset
nostdin shell::ssh::connect -p 2222 -i "$HOME/k" deploy@web1 uptime >/dev/null 2>&1
t_eq "connect runs ssh with the right words" "ssh [-p] [2222] [-i] [$HOME/k] [deploy@web1] [uptime]" "$(last)"
reset
nostdin shell::ssh::connect web1 ls "my dir" >/dev/null 2>&1
t_eq "connect: remote words are passed as they are" "ssh [web1] [ls] [my dir]" "$(last)"
reset
nostdin shell::ssh::connect web1 -V >/dev/null 2>&1
t_eq "connect: what follows the target is not parsed" "ssh [web1] [-V]" "$(last)"
FAKE_RC=7 t_rc "connect returns the exit status of ssh" 7 nostdin shell::ssh::connect web1
t_rc "connect: dry run needs no key file" 0 nostdin shell::ssh::connect -n -i /no/such/key web1
t_rc "connect: missing key file" 3 nostdin shell::ssh::connect -i /no/such/key web1
t_rc "connect: missing config file" 3 nostdin shell::ssh::connect -F /no/such/cfg web1
t_rc "connect: no target" 2 nostdin shell::ssh::connect
t_rc "connect: unknown option" 2 nostdin shell::ssh::connect -z web1
t_rc "connect: bad port" 2 nostdin shell::ssh::connect -p 70000 web1
t_rc "connect: port without a value" 2 nostdin shell::ssh::connect -p
t_rc "connect: port 0" 2 nostdin shell::ssh::connect -p 0 web1
t_rc "connect: bad jump" 2 nostdin shell::ssh::connect -J 'a b' web1
t_rc "connect: bad -o" 2 nostdin shell::ssh::connect -o nonsense web1
t_rc "connect: timeout not a number" 2 nostdin shell::ssh::connect --timeout x web1
t_rc "connect: timeout 0" 2 nostdin shell::ssh::connect --timeout 0 web1
t_rc "connect: option-looking target" 2 nostdin shell::ssh::connect -- -oProxyCommand=evil
t_rc "connect: --foreground is for tunnels" 2 nostdin shell::ssh::connect --foreground web1
t_rc "connect: --recursive is for scp" 2 nostdin shell::ssh::connect -r web1
t_has "connect -h" "USAGE: shell::ssh::connect" "$(shell::ssh::connect -h)"
reset
PATH="$HOME/empty" t_rc "connect: ssh not installed" 3 nostdin shell::ssh::connect web1
t_eq "connect: nothing ran" "" "$(cat "$FAKE_LOG")"
t_has "exec dry run with -t" "ssh -t web1 sudo systemctl restart nginx" "$(dry shell::ssh::exec -n -t web1 sudo systemctl restart nginx)"
t_rc "exec: a command is required" 2 nostdin shell::ssh::exec web1
t_rc "exec: -t is not for scp" 2 nostdin shell::ssh::scp::upload -t "$HOME/a.txt" web1:/tmp

# --- script --------------------------------------------------------------------
reset
FAKE_STDIN="$HOME/stdin.out" nostdin shell::ssh::script web1 "$HOME/s.sh" daily "my db" >/dev/null 2>&1
t_eq "script: bash -s with quoted args" "ssh [web1] [bash -s -- daily 'my db']" "$(last)"
t_eq "script: the file is the standard input" "echo hi" "$(cat "$HOME/stdin.out")"
reset
FAKE_STDIN="$HOME/stdin.out" nostdin shell::ssh::script web1 "$HOME/s.sh" >/dev/null 2>&1
t_eq "script: no args" "ssh [web1] [bash -s]" "$(last)"
t_has "script dry run" "< $HOME/s.sh" "$(dry shell::ssh::script -n web1 "$HOME/s.sh" x)"
t_rc "script: missing file" 3 nostdin shell::ssh::script web1 /no/such.sh
t_rc "script: file is required" 2 nostdin shell::ssh::script web1

# --- check ---------------------------------------------------------------------
reset
t_has "check: success message" "reachable" "$(nostdin shell::ssh::check web1 2>&1)"
t_eq "check: batch mode, short timeout, runs true" "ssh [-o] [BatchMode=yes] [-o] [ConnectTimeout=5] [web1] [true]" "$(last)"
reset
nostdin shell::ssh::check --timeout 2 web1 >/dev/null 2>&1
t_eq "check: your --timeout comes first and wins" "ssh [-o] [ConnectTimeout=2] [-o] [BatchMode=yes] [-o] [ConnectTimeout=5] [web1] [true]" "$(last)"
FAKE_RC=255 t_rc "check: cannot log in" 1 nostdin shell::ssh::check web1
t_has "check: failure message" "Cannot log in to web1" "$(FAKE_RC=255 nostdin shell::ssh::check web1 2>&1)"
t_rc "check: dry run does not judge" 0 nostdin shell::ssh::check -n web1
t_rc "check: one target only" 2 nostdin shell::ssh::check a b

# --- multiplexing --------------------------------------------------------------
reset
nostdin shell::ssh::mux::check web1 >/dev/null 2>&1
t_eq "mux check" "ssh [-O] [check] [web1]" "$(last)"
reset
nostdin shell::ssh::mux::stop -p 2222 web1 >/dev/null 2>&1
t_eq "mux stop" "ssh [-O] [exit] [-p] [2222] [web1]" "$(last)"

# --- scp -----------------------------------------------------------------------
reset
nostdin shell::ssh::scp::upload -r -p 2222 --preserve "$HOME/a.txt" "$HOME/dir" deploy@web1:/srv/ >/dev/null 2>&1
t_eq "upload: -p becomes -P, sources then destination" "scp [-r] [-p] [-P] [2222] [--] [$HOME/a.txt] [$HOME/dir] [deploy@web1:/srv/]" "$(last)"
reset
(cd "$HOME" && : >"x:y" && nostdin shell::ssh::scp::upload "x:y" web1:/tmp >/dev/null 2>&1)
t_eq "upload: a local name with a colon is not a host" "scp [--] [./x:y] [web1:/tmp]" "$(last)"
t_rc "upload: missing source" 3 nostdin shell::ssh::scp::upload /no/such web1:/tmp
t_rc "upload: dry run does not need the source" 0 nostdin shell::ssh::scp::upload -n /no/such web1:/tmp
t_rc "upload: destination must be remote" 2 nostdin shell::ssh::scp::upload "$HOME/a.txt" "$HOME/dest"
t_rc "upload: needs two arguments" 2 nostdin shell::ssh::scp::upload "$HOME/a.txt"
t_rc "upload: -v is accepted (scp has it)" 0 nostdin shell::ssh::scp::upload -n -v "$HOME/a.txt" web1:/tmp
reset
nostdin shell::ssh::scp::download -r deploy@web1:/etc/nginx "$HOME/dest" >/dev/null 2>&1
t_eq "download" "scp [-r] [--] [deploy@web1:/etc/nginx] [$HOME/dest]" "$(last)"
reset
nostdin shell::ssh::scp::download web1:/a web1:/b "$HOME/dest" >/dev/null 2>&1
t_eq "download: several sources into a directory" "scp [--] [web1:/a] [web1:/b] [$HOME/dest]" "$(last)"
t_rc "download: several sources need a directory" 2 nostdin shell::ssh::scp::download web1:/a web1:/b "$HOME/nodir"
t_rc "download: sources must be remote" 2 nostdin shell::ssh::scp::download "$HOME/a.txt" "$HOME/dest"
t_rc "download: --delete is for rsync" 2 nostdin shell::ssh::scp::download --delete web1:/a "$HOME/dest"

# --- rsync ---------------------------------------------------------------------
reset
nostdin shell::ssh::rsync::push -p 2222 -i "$HOME/k" -J bastion --delete --exclude .git --exclude '*.log' --progress "$HOME/dir/" deploy@web1:/srv/ >/dev/null 2>&1
t_eq "push: rsync -avz with ssh options in -e" "rsync [-avz] [--delete] [--exclude] [.git] [--exclude] [*.log] [--progress] [-e] [ssh -p 2222 -i $HOME/k -J bastion] [--] [$HOME/dir/] [deploy@web1:/srv/]" "$(last)"
reset
nostdin shell::ssh::rsync::push --simulate "$HOME/dir/" web1:/srv/ >/dev/null 2>&1
t_eq "push: --simulate is rsync -n, plain ssh" "rsync [-avz] [-n] [-e] [ssh] [--] [$HOME/dir/] [web1:/srv/]" "$(last)"
reset
nostdin shell::ssh::rsync::pull web1:/srv/ "$HOME/dest/" >/dev/null 2>&1
t_eq "pull" "rsync [-avz] [-e] [ssh] [--] [web1:/srv/] [$HOME/dest/]" "$(last)"
t_has "push dry run quotes the -e string" "-e 'ssh -p 2222'" "$(dry shell::ssh::rsync::push -n -p 2222 "$HOME/dir/" web1:/srv/)"
t_rc "push: -v is not an rsync option here" 2 nostdin shell::ssh::rsync::push -v "$HOME/dir/" web1:/srv/
t_rc "push: empty --exclude" 2 nostdin shell::ssh::rsync::push --exclude "" "$HOME/dir/" web1:/srv/
t_rc "push: --exclude needs a value" 2 nostdin shell::ssh::rsync::push --exclude

# --- sftp / copy-id are one target ---------------------------------------------
reset
nostdin shell::ssh::sftp::connect -p 2222 -i "$HOME/k" web1 >/dev/null 2>&1
t_eq "sftp: -p becomes -P" "sftp [-P] [2222] [-i] [$HOME/k] [web1]" "$(last)"
t_rc "sftp: one target" 2 nostdin shell::ssh::sftp::connect a b
reset
nostdin shell::ssh::key::copy_id -p 2222 -i "$HOME/k" -J bastion deploy@web1 >/dev/null 2>&1
t_eq "copy_id: -p stays -p, a jump becomes -o ProxyJump" "ssh-copy-id [-p] [2222] [-i] [$HOME/k] [-o] [ProxyJump=bastion] [deploy@web1]" "$(last)"
t_rc "copy_id: -v is not an ssh-copy-id option" 2 nostdin shell::ssh::key::copy_id -v web1

# --- tunnels -------------------------------------------------------------------
reset
t_has "tunnel local: success message" "Tunnel is up" "$(nostdin shell::ssh::tunnel::local deploy@bastion 5432:db:5432 2>&1)"
t_eq "tunnel local: background, fail on bind, keep-alive" "ssh [-N] [-T] [-f] [-o] [ExitOnForwardFailure=yes] [-o] [ServerAliveInterval=30] [-o] [ServerAliveCountMax=3] [-L] [5432:db:5432] [deploy@bastion]" "$(last)"
reset
nostdin shell::ssh::tunnel::remote --foreground -p 2222 web1 9090:localhost:3000 >/dev/null 2>&1
t_eq "tunnel remote in the foreground" "ssh [-N] [-T] [-p] [2222] [-o] [ExitOnForwardFailure=yes] [-o] [ServerAliveInterval=30] [-o] [ServerAliveCountMax=3] [-R] [9090:localhost:3000] [web1]" "$(last)"
reset
nostdin shell::ssh::tunnel::socks --keepalive 5 -J bastion web1 >/dev/null 2>&1
t_eq "tunnel socks: default port, your keep-alive first" "ssh [-N] [-T] [-f] [-o] [ServerAliveInterval=5] [-o] [ServerAliveCountMax=3] [-J] [bastion] [-o] [ExitOnForwardFailure=yes] [-o] [ServerAliveInterval=30] [-o] [ServerAliveCountMax=3] [-D] [1080] [web1]" "$(last)"
reset
nostdin shell::ssh::tunnel::socks web1 1081 >/dev/null 2>&1
t_has "tunnel socks: given port" "[-D] [1081] [web1]" "$(last)"
t_lacks "tunnel: no success message when ssh fails" "Tunnel is up" "$(FAKE_RC=255 nostdin shell::ssh::tunnel::local web1 1:h:2 2>&1)"
FAKE_RC=255 t_rc "tunnel: ssh status is returned" 255 nostdin shell::ssh::tunnel::local web1 1:h:2
t_rc "tunnel local: bad spec" 2 nostdin shell::ssh::tunnel::local web1 notaspec
t_rc "tunnel local: spec and target" 2 nostdin shell::ssh::tunnel::local web1
t_rc "tunnel socks: bad port" 2 nostdin shell::ssh::tunnel::socks web1 99999
t_rc "tunnel socks: too many arguments" 2 nostdin shell::ssh::tunnel::socks web1 1080 extra

# --- every function has a help page --------------------------------------------
for fn in connect exec script check version mux::check mux::stop scp::upload scp::download rsync::push rsync::pull sftp::connect tunnel::local tunnel::remote tunnel::socks key::copy_id; do
	t_has "help: shell::ssh::$fn" "USAGE:" "$("shell::ssh::$fn" --help 2>&1)"
done

t_done
