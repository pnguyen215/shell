#!/usr/bin/env bash
# shell::rsync::* commands (src/lib/rsync.sh): what is validated, which command line each function builds
# (dry run and real run), when rsync is started again, and what comes back (exit statuses, messages).
#
# rsync and ssh are fakes. Each logs its name and arguments, one "[arg]" per word, to $FAKE_LOG and exits
# with the next status of $FAKE_RC_SEQ (one per line) or, when that is empty, with $FAKE_RC. Nothing here
# touches the network; the real rsync is in test_rsync_real.sh.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

mkdir -p "$HOME/bin" "$HOME/dir" "$HOME/dest" "$HOME/empty"
cat >"$HOME/bin/fake" <<'FAKE'
#!/bin/sh
{
	printf '%s' "${0##*/}"
	for a in "$@"; do printf ' [%s]' "$a"; done
	printf '\n'
} >>"$FAKE_LOG"
if [ -s "${FAKE_RC_SEQ-/nonexistent}" ]; then
	rc="$(sed -n 1p "$FAKE_RC_SEQ")"
	sed '1d' "$FAKE_RC_SEQ" >"$FAKE_RC_SEQ.tmp" && mv "$FAKE_RC_SEQ.tmp" "$FAKE_RC_SEQ"
	exit "$rc"
fi
exit "${FAKE_RC:-0}"
FAKE
chmod +x "$HOME/bin/fake"
for n in rsync ssh; do cp "$HOME/bin/fake" "$HOME/bin/$n"; done
export PATH="$HOME/bin:$PATH" FAKE_LOG="$HOME/fake.log" FAKE_RC_SEQ="$HOME/rc.seq" SHELL_RSYNC_RETRY_DELAY=0
: >"$FAKE_LOG"

echo data >"$HOME/a.txt"
echo more >"$HOME/dir/f.txt"
echo key >"$HOME/k"
printf 'node_modules\n' >"$HOME/ignore.txt"

reset() { : >"$FAKE_LOG"; }
last() { tail -n 1 "$FAKE_LOG"; }
calls() { wc -l <"$FAKE_LOG" | tr -d ' '; }
# nostdin <command...>: run without a terminal on the standard input
nostdin() { "$@" </dev/null; }
# dry <command...> -> what a dry run prints
dry() { nostdin "$@" 2>&1; }

# --- location kinds ------------------------------------------------------------
t_eq "kind: plain path" "local" "$(shell::rsync::spec::kind "/var/www")"
t_eq "kind: relative path" "local" "$(shell::rsync::spec::kind "site/")"
t_eq "kind: slash before the colon is a path" "local" "$(shell::rsync::spec::kind "./backup:2024")"
t_eq "kind: deep path with a colon" "local" "$(shell::rsync::spec::kind "a/b:c")"
t_eq "kind: host:path" "ssh" "$(shell::rsync::spec::kind "web1:/var/www")"
t_eq "kind: user@host:path" "ssh" "$(shell::rsync::spec::kind "deploy@web1:/var/www")"
t_eq "kind: user@host: (home)" "ssh" "$(shell::rsync::spec::kind "deploy@web1:")"
t_eq "kind: host::module" "daemon" "$(shell::rsync::spec::kind "mirror.example.com::pub/x")"
t_eq "kind: rsync://" "daemon" "$(shell::rsync::spec::kind "rsync://mirror.example.com/pub/")"
t_eq "kind: path with :: after a slash" "local" "$(shell::rsync::spec::kind "./a::b")"

t_rc "valid: path" 0 shell::rsync::spec::valid "./site/"
t_rc "valid: ssh" 0 shell::rsync::spec::valid "deploy@web1:/srv"
t_rc "valid: daemon module" 0 shell::rsync::spec::valid "user@mirror::pub"
t_rc "valid: daemon url with port" 0 shell::rsync::spec::valid "rsync://user@mirror:8730/pub/"
t_rc "valid: daemon url, modules listing" 0 shell::rsync::spec::valid "rsync://mirror/"
t_rc "valid: empty" 1 shell::rsync::spec::valid ""
t_rc "valid: host that is an option" 1 shell::rsync::spec::valid "-oProxyCommand=x:/tmp"
t_rc "valid: daemon without host" 1 shell::rsync::spec::valid "rsync:///pub"
t_rc "valid: daemon host with a semicolon" 1 shell::rsync::spec::valid "rsync://h;reboot/pub"
t_rc "valid: ssh host with a space" 1 shell::rsync::spec::valid "a b:/x"

t_rc "rate: megabytes" 0 shell::rsync::rate::valid "5m"
t_rc "rate: fraction" 0 shell::rsync::rate::valid "1.5M"
t_rc "rate: plain KiB/s" 0 shell::rsync::rate::valid "10240"
t_rc "rate: bad unit" 1 shell::rsync::rate::valid "5x"
t_rc "rate: unit twice" 1 shell::rsync::rate::valid "5mm"
t_rc "rate: unit first" 1 shell::rsync::rate::valid "m5"
t_rc "rate: two dots" 1 shell::rsync::rate::valid "1.2.3"
t_rc "rate: empty" 1 shell::rsync::rate::valid ""
t_rc "chmod: dirs and files" 0 shell::rsync::chmod::valid "D755,F644"
t_rc "chmod: symbolic" 0 shell::rsync::chmod::valid "Du=rwx,go=rx"
t_rc "chmod: leading dash" 1 shell::rsync::chmod::valid "-x"
t_rc "chmod: junk" 1 shell::rsync::chmod::valid "755;reboot"

# --- sync ------------------------------------------------------------------------
reset
nostdin shell::rsync::sync "$HOME/dir/" "$HOME/dest/" >/dev/null 2>&1
t_eq "sync: -a and nothing else" "rsync [-a] [--] [$HOME/dir/] [$HOME/dest/]" "$(last)"
reset
nostdin shell::rsync::sync -z --exclude .git --exclude '*.log' -p 2222 -i "$HOME/k" "$HOME/dir/" deploy@web1:/srv/ >/dev/null 2>&1
t_eq "sync: options, filters, ssh in -e" "rsync [-a] [-z] [--exclude=.git] [--exclude=*.log] [-e] [ssh -i $HOME/k -p 2222] [--] [$HOME/dir/] [deploy@web1:/srv/]" "$(last)"
reset
nostdin shell::rsync::sync -J bastion -o Compression=yes --batch --accept-new "$HOME/dir/" web1:/srv/ >/dev/null 2>&1
t_has "sync: ssh options go to -e" "[ssh -o Compression=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -J bastion]" "$(last)"
reset
nostdin shell::rsync::sync "$HOME/dir/" web1:/srv/ >/dev/null 2>&1
t_lacks "sync: plain ssh needs no -e" "[-e]" "$(last)"
reset
nostdin shell::rsync::sync web1:/srv/ "$HOME/dest/" >/dev/null 2>&1
t_eq "sync: pull" "rsync [-a] [--] [web1:/srv/] [$HOME/dest/]" "$(last)"
reset
nostdin shell::rsync::sync "$HOME/a.txt" "$HOME/dir/" "$HOME/dest/" >/dev/null 2>&1
t_eq "sync: several sources" "rsync [-a] [--] [$HOME/a.txt] [$HOME/dir/] [$HOME/dest/]" "$(last)"
reset
nostdin shell::rsync::sync --delete --max-delete 20 "$HOME/dir/" "$HOME/dest/" >/dev/null 2>&1
t_eq "sync: --delete is --delete-after" "rsync [-a] [--delete-after] [--max-delete=20] [--] [$HOME/dir/] [$HOME/dest/]" "$(last)"
reset
nostdin shell::rsync::sync --include '*.css' --exclude '*' --exclude-from "$HOME/ignore.txt" "$HOME/dir/" "$HOME/dest/" >/dev/null 2>&1
t_eq "sync: include / exclude keep the order typed" "rsync [-a] [--include=*.css] [--exclude=*] [--exclude-from=$HOME/ignore.txt] [--] [$HOME/dir/] [$HOME/dest/]" "$(last)"
reset
nostdin shell::rsync::sync --bwlimit 5m --timeout 30 --chmod D755,F644 --partial --stats --progress --itemize --human -v -c -u -L -H --ignore-existing --omit-dir-times --simulate "$HOME/dir/" "$HOME/dest/" >/dev/null 2>&1
t_has "sync: human and verbose" "[-h] [-v]" "$(last)"
t_has "sync: bwlimit" "[--bwlimit=5m]" "$(last)"
t_has "sync: timeout" "[--timeout=30]" "$(last)"
t_has "sync: chmod" "[--chmod=D755,F644]" "$(last)"
t_has "sync: partial" "[--partial]" "$(last)"
t_has "sync: stats and progress" "[--stats] [--progress]" "$(last)"
t_has "sync: itemize is -i" "[-i]" "$(last)"
t_has "sync: --simulate is -n" "[-n]" "$(last)"
t_has "sync: checksum, update, links" "[-c] [-u] [-L] [-H]" "$(last)"
t_has "sync: ignore-existing, omit-dir-times" "[--ignore-existing] [--omit-dir-times]" "$(last)"
reset
nostdin shell::rsync::sync --total-progress "$HOME/dir/" "$HOME/dest/" >/dev/null 2>&1
t_has "sync: --total-progress is --info=progress2" "[--info=progress2]" "$(last)"
reset
nostdin shell::rsync::sync -p 8730 "$HOME/dir/" rsync://mirror.example.com/pub/ >/dev/null 2>&1
t_eq "sync: daemon, -p is --port" "rsync [-a] [--port=8730] [--] [$HOME/dir/] [rsync://mirror.example.com/pub/]" "$(last)"
reset
nostdin shell::rsync::sync --sudo "$HOME/dir/" web1:/srv/ >/dev/null 2>&1
t_has "sync: --sudo" "[--rsync-path=sudo rsync]" "$(last)"
reset
nostdin shell::rsync::sync --rsync-path /opt/bin/rsync "$HOME/dir/" web1:/srv/ >/dev/null 2>&1
t_has "sync: --rsync-path" "[--rsync-path=/opt/bin/rsync]" "$(last)"
reset
mkdir "$HOME/-weird"
nostdin shell::rsync::sync -- -weird/ "$HOME/dest/" >/dev/null 2>&1
t_eq "sync: -- ends the options" "rsync [-a] [--] [-weird/] [$HOME/dest/]" "$(last)"
t_rc "sync: without -- a source named like an option is refused" 2 nostdin shell::rsync::sync -weird/ "$HOME/dest/"
reset
nostdin shell::rsync::sync -n -- -weird/ "$HOME/dest/" >/dev/null 2>&1
t_eq "sync: a dry run runs nothing" "" "$(last)"
t_has "sync: dry run prints the command" "rsync -a -- -weird/" "$(dry shell::rsync::sync -n -- -weird/ "$HOME/dest/")"
t_has "sync: dry run quotes a pattern" "'--exclude=*.log'" "$(dry shell::rsync::sync -n --exclude '*.log' ./a/ ./b/)"
t_has "sync: dry run quotes the -e string" "-e 'ssh -p 2222'" "$(dry shell::rsync::sync -n -p 2222 ./a/ web1:/b/)"
t_has "sync: the real run echoes the command" "rsync -a" "$(nostdin shell::rsync::sync "$HOME/dir/" "$HOME/dest/" 2>&1)"

# --- sync: what is refused --------------------------------------------------------
t_rc "sync: needs two locations" 2 nostdin shell::rsync::sync "$HOME/dir/"
t_rc "sync: nothing at all" 2 nostdin shell::rsync::sync
t_rc "sync: unknown option" 2 nostdin shell::rsync::sync --nope "$HOME/dir/" "$HOME/dest/"
t_rc "sync: both remote" 2 nostdin shell::rsync::sync web1:/a web2:/b
t_rc "sync: remote to daemon" 2 nostdin shell::rsync::sync web1:/a rsync://h/m/
t_has "sync: both remote, why" "cannot copy from one server to another" "$(dry shell::rsync::sync web1:/a web2:/b)"
t_rc "sync: local and remote sources mixed" 2 nostdin shell::rsync::sync ./a web1:/b "$HOME/dest/"
t_rc "sync: invalid destination" 2 nostdin shell::rsync::sync ./a "-oProxyCommand=x:/tmp"
t_rc "sync: empty source" 2 nostdin shell::rsync::sync "" ./b
t_rc "sync: ssh options need a remote" 2 nostdin shell::rsync::sync -p 22 "$HOME/dir/" "$HOME/dest/"
t_rc "sync: --sudo needs a remote" 2 nostdin shell::rsync::sync --sudo "$HOME/dir/" "$HOME/dest/"
t_rc "sync: ssh options and a daemon" 2 nostdin shell::rsync::sync -i "$HOME/k" "$HOME/dir/" rsync://h/m/
t_rc "sync: --sudo and --rsync-path" 2 nostdin shell::rsync::sync --sudo --rsync-path x "$HOME/dir/" web1:/b
t_rc "sync: --max-delete needs --delete" 2 nostdin shell::rsync::sync --max-delete 5 "$HOME/dir/" "$HOME/dest/"
t_rc "sync: --max-delete is a number" 2 nostdin shell::rsync::sync --delete --max-delete lots "$HOME/dir/" "$HOME/dest/"
t_rc "sync: bad bandwidth" 2 nostdin shell::rsync::sync --bwlimit 5x "$HOME/dir/" "$HOME/dest/"
t_rc "sync: bandwidth needs a value" 2 nostdin shell::rsync::sync --bwlimit
t_rc "sync: timeout is a positive number" 2 nostdin shell::rsync::sync --timeout 0 "$HOME/dir/" "$HOME/dest/"
t_rc "sync: bad chmod" 2 nostdin shell::rsync::sync --chmod 'x;y' "$HOME/dir/" "$HOME/dest/"
t_rc "sync: empty --exclude" 2 nostdin shell::rsync::sync --exclude "" "$HOME/dir/" "$HOME/dest/"
t_rc "sync: --exclude needs a value" 2 nostdin shell::rsync::sync --exclude
t_rc "sync: bad port" 2 nostdin shell::rsync::sync -p 99999 "$HOME/dir/" web1:/b
t_rc "sync: bad jump" 2 nostdin shell::rsync::sync -J "a b" "$HOME/dir/" web1:/b
t_rc "sync: bad ssh option" 2 nostdin shell::rsync::sync -o Compression "$HOME/dir/" web1:/b
t_rc "sync: bad partial dir" 2 nostdin shell::rsync::sync --partial-dir -x "$HOME/dir/" web1:/b
t_rc "sync: --append with --partial-dir" 2 nostdin shell::rsync::sync --append --partial-dir .p "$HOME/dir/" web1:/b
t_rc "sync: -r is for list" 2 nostdin shell::rsync::sync -r "$HOME/dir/" "$HOME/dest/"
t_rc "sync: --retries is for resume" 2 nostdin shell::rsync::sync --retries 3 "$HOME/dir/" "$HOME/dest/"
t_rc "sync: --allow-empty is for mirror" 2 nostdin shell::rsync::sync --allow-empty "$HOME/dir/" "$HOME/dest/"
t_rc "sync: --no-delete is for diff" 2 nostdin shell::rsync::sync --no-delete "$HOME/dir/" "$HOME/dest/"
t_rc "sync: source must exist" 3 nostdin shell::rsync::sync "$HOME/nope/" "$HOME/dest/"
t_rc "sync: dry run does not need the source" 0 nostdin shell::rsync::sync -n "$HOME/nope/" "$HOME/dest/"
t_rc "sync: identity must exist" 3 nostdin shell::rsync::sync -i "$HOME/nokey" "$HOME/dir/" web1:/b
t_rc "sync: dry run does not need the identity" 0 nostdin shell::rsync::sync -n -i "$HOME/nokey" "$HOME/dir/" web1:/b
t_rc "sync: config must exist" 3 nostdin shell::rsync::sync -F "$HOME/nocfg" "$HOME/dir/" web1:/b
t_rc "sync: exclude file must exist" 3 nostdin shell::rsync::sync --exclude-from "$HOME/noignore" "$HOME/dir/" "$HOME/dest/"
t_rc "sync: dry run does not need the exclude file" 0 nostdin shell::rsync::sync -n --exclude-from "$HOME/noignore" "$HOME/dir/" "$HOME/dest/"
t_has "sync: --delete on a directory without a slash warns" "no trailing /" "$(nostdin shell::rsync::sync --delete "$HOME/dir" "$HOME/dest/" 2>&1)"
t_lacks "sync: --delete with a slash does not" "no trailing /" "$(nostdin shell::rsync::sync --delete "$HOME/dir/" "$HOME/dest/" 2>&1)"
t_lacks "sync: --delete on a file does not" "no trailing /" "$(nostdin shell::rsync::sync --delete "$HOME/a.txt" "$HOME/dest/" 2>&1)"

# --- exit statuses and hints --------------------------------------------------------
: >"$FAKE_RC_SEQ"
FAKE_RC=23 t_rc "status: rsync's own status is returned" 23 nostdin shell::rsync::sync "$HOME/dir/" "$HOME/dest/"
t_has "status 23: hint" "status 23" "$(FAKE_RC=23 nostdin shell::rsync::sync "$HOME/dir/" "$HOME/dest/" 2>&1)"
t_has "status 24: hint" "vanished" "$(FAKE_RC=24 nostdin shell::rsync::sync "$HOME/dir/" "$HOME/dest/" 2>&1)"
t_has "status 25: hint" "--max-delete" "$(FAKE_RC=25 nostdin shell::rsync::sync "$HOME/dir/" "$HOME/dest/" 2>&1)"
t_has "status 25: deleted files stay deleted" "stay deleted" "$(FAKE_RC=25 nostdin shell::rsync::sync "$HOME/dir/" "$HOME/dest/" 2>&1)"
t_lacks "status 0: no hint" "status" "$(nostdin shell::rsync::sync "$HOME/dir/" "$HOME/dest/" 2>&1)"
t_lacks "dry run: no hint" "status" "$(FAKE_RC=23 dry shell::rsync::sync -n "$HOME/dir/" "$HOME/dest/")"

# --- mirror ----------------------------------------------------------------------------
reset
nostdin shell::rsync::mirror "$HOME/dir" "$HOME/dest" >/dev/null 2>&1
t_eq "mirror: slash added, delete after, limit" "rsync [-a] [--delete-after] [--max-delete=1000] [--] [$HOME/dir/] [$HOME/dest]" "$(last)"
reset
nostdin shell::rsync::mirror "$HOME/dir/" "$HOME/dest" >/dev/null 2>&1
t_has "mirror: an existing slash stays single" "[$HOME/dir/] [$HOME/dest]" "$(last)"
reset
SHELL_RSYNC_MAX_DELETE=5 nostdin shell::rsync::mirror "$HOME/dir" "$HOME/dest" >/dev/null 2>&1
t_has "mirror: limit from SHELL_RSYNC_MAX_DELETE" "[--max-delete=5]" "$(last)"
reset
SHELL_RSYNC_MAX_DELETE=5 nostdin shell::rsync::mirror --max-delete 7 "$HOME/dir" "$HOME/dest" >/dev/null 2>&1
t_has "mirror: --max-delete wins" "[--max-delete=7]" "$(last)"
t_lacks "mirror: only one limit" "[--max-delete=5]" "$(last)"
reset
nostdin shell::rsync::mirror --exclude .git --simulate "$HOME/dir" web1:/srv/site >/dev/null 2>&1
t_eq "mirror: remote, exclude, simulate" "rsync [-a] [--delete-after] [--max-delete=1000] [-n] [--exclude=.git] [--] [$HOME/dir/] [web1:/srv/site]" "$(last)"
reset
nostdin shell::rsync::mirror web1:/srv/site "$HOME/dest" >/dev/null 2>&1
t_has "mirror: remote source gets the slash too" "[web1:/srv/site/]" "$(last)"
SHELL_RSYNC_MAX_DELETE=lots t_rc "mirror: bad SHELL_RSYNC_MAX_DELETE" 2 nostdin shell::rsync::mirror "$HOME/dir" "$HOME/dest"
reset
t_rc "mirror: empty source is refused" 8 nostdin shell::rsync::mirror "$HOME/empty" "$HOME/dest"
t_eq "mirror: ...and rsync never ran" "0" "$(calls)"
t_has "mirror: empty source, why" "delete everything" "$(dry shell::rsync::mirror "$HOME/empty" "$HOME/dest")"
reset
t_rc "mirror: --allow-empty" 0 nostdin shell::rsync::mirror --allow-empty "$HOME/empty" "$HOME/dest"
t_has "mirror: --allow-empty runs rsync" "[$HOME/empty/]" "$(last)"
t_rc "mirror: dry run skips the empty check" 0 nostdin shell::rsync::mirror -n "$HOME/empty" "$HOME/dest"
t_rc "mirror: never onto /" 2 nostdin shell::rsync::mirror "$HOME/dir" /
t_rc "mirror: never onto / (dry run too)" 2 nostdin shell::rsync::mirror -n "$HOME/dir" /
t_rc "mirror: the source must be a directory" 2 nostdin shell::rsync::mirror "$HOME/a.txt" "$HOME/dest"
t_has "mirror: ...named as typed" "$HOME/a.txt" "$(dry shell::rsync::mirror "$HOME/a.txt" "$HOME/dest")"
t_lacks "mirror: ...without the added slash" "a.txt/" "$(dry shell::rsync::mirror "$HOME/a.txt" "$HOME/dest")"
t_rc "mirror: the source must exist" 3 nostdin shell::rsync::mirror "$HOME/nope" "$HOME/dest"
t_rc "mirror: one source only" 2 nostdin shell::rsync::mirror "$HOME/dir" "$HOME/empty" "$HOME/dest"
t_rc "mirror: needs a destination" 2 nostdin shell::rsync::mirror "$HOME/dir"
t_rc "mirror: --delete is implied" 2 nostdin shell::rsync::mirror --delete "$HOME/dir" "$HOME/dest"
t_rc "mirror: --retries is for resume" 2 nostdin shell::rsync::mirror --retries 2 "$HOME/dir" "$HOME/dest"
t_has "mirror: status 25 explained" "--max-delete" "$(FAKE_RC=25 nostdin shell::rsync::mirror "$HOME/dir" "$HOME/dest" 2>&1)"

# --- move ------------------------------------------------------------------------------------
reset
nostdin shell::rsync::move "$HOME/dir/" "$HOME/dest/" >/dev/null 2>&1
t_eq "move: --remove-source-files" "rsync [-a] [--remove-source-files] [--] [$HOME/dir/] [$HOME/dest/]" "$(last)"
reset
nostdin shell::rsync::move --simulate --exclude '*.part' "$HOME/dir/" nas:/inbox/ >/dev/null 2>&1
t_eq "move: simulate and exclude" "rsync [-a] [--remove-source-files] [-n] [--exclude=*.part] [--] [$HOME/dir/] [nas:/inbox/]" "$(last)"
t_has "move: says the directories stay" "empty directories" "$(nostdin shell::rsync::move "$HOME/dir/" "$HOME/dest/" 2>&1)"
t_lacks "move: no note with --simulate" "empty directories" "$(nostdin shell::rsync::move --simulate "$HOME/dir/" "$HOME/dest/" 2>&1)"
t_lacks "move: no note when rsync fails" "empty directories" "$(FAKE_RC=23 nostdin shell::rsync::move "$HOME/dir/" "$HOME/dest/" 2>&1)"
t_lacks "move: no note in a dry run" "empty directories" "$(dry shell::rsync::move -n "$HOME/dir/" "$HOME/dest/")"
t_rc "move: --delete is refused" 2 nostdin shell::rsync::move --delete "$HOME/dir/" "$HOME/dest/"
t_rc "move: --max-delete is refused" 2 nostdin shell::rsync::move --max-delete 3 "$HOME/dir/" "$HOME/dest/"
t_rc "move: source must exist" 3 nostdin shell::rsync::move "$HOME/nope/" "$HOME/dest/"

# --- resume ----------------------------------------------------------------------------------
reset
nostdin shell::rsync::resume "$HOME/a.txt" web1:/srv/ >/dev/null 2>&1
t_eq "resume: partial dir and timeout" "rsync [-a] [--partial-dir=.rsync-partial] [--timeout=120] [--] [$HOME/a.txt] [web1:/srv/]" "$(last)"
reset
nostdin shell::rsync::resume --total-progress --bwlimit 2m "$HOME/a.txt" web1:/srv/ >/dev/null 2>&1
t_has "resume: --total-progress and --bwlimit" "[--info=progress2] [--bwlimit=2m]" "$(last)"
reset
nostdin shell::rsync::resume --timeout 30 "$HOME/a.txt" web1:/srv/ >/dev/null 2>&1
t_has "resume: --timeout wins" "[--timeout=30]" "$(last)"
reset
SHELL_RSYNC_TIMEOUT=45 SHELL_RSYNC_PARTIAL_DIR=.parts nostdin shell::rsync::resume "$HOME/a.txt" web1:/srv/ >/dev/null 2>&1
t_has "resume: SHELL_RSYNC_TIMEOUT" "[--timeout=45]" "$(last)"
t_has "resume: SHELL_RSYNC_PARTIAL_DIR" "[--partial-dir=.parts]" "$(last)"
reset
nostdin shell::rsync::resume --partial-dir .mine "$HOME/a.txt" web1:/srv/ >/dev/null 2>&1
t_has "resume: --partial-dir wins" "[--partial-dir=.mine]" "$(last)"
t_lacks "resume: ...and the default is not added" ".rsync-partial" "$(last)"
reset
nostdin shell::rsync::resume --append "$HOME/a.txt" web1:/srv/ >/dev/null 2>&1
t_eq "resume: --append is --partial --append-verify, no partial dir" "rsync [-a] [--partial] [--append-verify] [--timeout=120] [--] [$HOME/a.txt] [web1:/srv/]" "$(last)"
reset
nostdin shell::rsync::resume --partial "$HOME/a.txt" web1:/srv/ >/dev/null 2>&1
t_eq "resume: --partial keeps files in place, no partial dir" "rsync [-a] [--partial] [--timeout=120] [--] [$HOME/a.txt] [web1:/srv/]" "$(last)"
t_rc "resume: --append and --partial-dir" 2 nostdin shell::rsync::resume --append --partial-dir .p "$HOME/a.txt" web1:/srv/
t_rc "resume: --retries is a positive number" 2 nostdin shell::rsync::resume --retries 0 "$HOME/a.txt" web1:/srv/
t_rc "resume: --retries needs a value" 2 nostdin shell::rsync::resume --retries
SHELL_RSYNC_RETRY_DELAY=soon t_rc "resume: bad SHELL_RSYNC_RETRY_DELAY" 2 nostdin shell::rsync::resume "$HOME/a.txt" web1:/srv/
SHELL_RSYNC_TIMEOUT=never t_rc "resume: bad SHELL_RSYNC_TIMEOUT" 2 nostdin shell::rsync::resume "$HOME/a.txt" web1:/srv/
SHELL_RSYNC_RETRIES=many t_rc "resume: bad SHELL_RSYNC_RETRIES" 2 nostdin shell::rsync::resume "$HOME/a.txt" web1:/srv/

# a network failure is retried, any other failure is not
reset
printf '255\n255\n' >"$FAKE_RC_SEQ"
t_rc "resume: succeeds after two network failures" 0 nostdin shell::rsync::resume --retries 3 "$HOME/a.txt" web1:/srv/
t_eq "resume: ...in three runs" "3" "$(calls)"
t_has "resume: ...saying so" "retry 2 of 3" "$T_OUT"
reset
printf '12\n30\n35\n10\n' >"$FAKE_RC_SEQ"
t_rc "resume: statuses 12, 30, 35 and 10 are network failures" 0 nostdin shell::rsync::resume --retries 5 "$HOME/a.txt" web1:/srv/
t_eq "resume: ...five runs" "5" "$(calls)"
reset
printf '255\n255\n255\n' >"$FAKE_RC_SEQ"
t_rc "resume: gives up, status of the last run" 255 nostdin shell::rsync::resume --retries 2 "$HOME/a.txt" web1:/srv/
t_eq "resume: ...after the first run and two retries" "3" "$(calls)"
t_has "resume: ...saying so" "Giving up after 2 retries" "$T_OUT"
: >"$FAKE_RC_SEQ"
reset
FAKE_RC=23 t_rc "resume: status 23 is returned" 23 nostdin shell::rsync::resume "$HOME/a.txt" web1:/srv/
t_eq "resume: ...and not retried" "1" "$(calls)"
reset
FAKE_RC=1 t_rc "resume: a usage error is returned" 1 nostdin shell::rsync::resume "$HOME/a.txt" web1:/srv/
t_eq "resume: ...and not retried either" "1" "$(calls)"
reset
printf '255\n' >"$FAKE_RC_SEQ"
nostdin shell::rsync::resume --retries 3 -n "$HOME/a.txt" web1:/srv/ >/dev/null 2>&1
t_eq "resume: a dry run prints once and never retries" "0" "$(calls)"
: >"$FAKE_RC_SEQ"

# --- diff ------------------------------------------------------------------------------------
reset
nostdin shell::rsync::diff "$HOME/dir/" "$HOME/dest/" >/dev/null 2>&1
t_eq "diff: -a -n -i --delete" "rsync [-a] [-n] [-i] [--delete] [--] [$HOME/dir/] [$HOME/dest/]" "$(last)"
reset
nostdin shell::rsync::diff --no-delete --exclude node_modules -c "$HOME/dir/" web1:/srv/ >/dev/null 2>&1
t_eq "diff: --no-delete, checksum, exclude" "rsync [-a] [-n] [-i] [-c] [--exclude=node_modules] [--] [$HOME/dir/] [web1:/srv/]" "$(last)"
t_rc "diff: --simulate makes no sense" 2 nostdin shell::rsync::diff --simulate "$HOME/dir/" "$HOME/dest/"
t_rc "diff: -z makes no sense" 2 nostdin shell::rsync::diff -z "$HOME/dir/" "$HOME/dest/"
t_rc "diff: --delete is on by default" 2 nostdin shell::rsync::diff --delete "$HOME/dir/" "$HOME/dest/"
t_rc "diff: needs two locations" 2 nostdin shell::rsync::diff "$HOME/dir/"
t_rc "diff: the destination need not exist" 0 nostdin shell::rsync::diff "$HOME/dir/" "$HOME/not-yet/"

# --- list ------------------------------------------------------------------------------------
reset
nostdin shell::rsync::list "$HOME/dir/" >/dev/null 2>&1
t_eq "list: --list-only" "rsync [--list-only] [--] [$HOME/dir/]" "$(last)"
reset
nostdin shell::rsync::list -r --human -p 2222 web1:/srv/ >/dev/null 2>&1
t_eq "list: recursive, human, port" "rsync [--list-only] [-r] [-h] [-e] [ssh -p 2222] [--] [web1:/srv/]" "$(last)"
reset
nostdin shell::rsync::list rsync://mirror.example.com/ >/dev/null 2>&1
t_eq "list: the modules of a daemon" "rsync [--list-only] [--] [rsync://mirror.example.com/]" "$(last)"
t_rc "list: one location only" 2 nostdin shell::rsync::list "$HOME/dir/" "$HOME/dest/"
t_rc "list: needs a location" 2 nostdin shell::rsync::list
t_rc "list: -z makes no sense" 2 nostdin shell::rsync::list -z "$HOME/dir/"
t_rc "list: no filters" 2 nostdin shell::rsync::list --exclude x "$HOME/dir/"
t_rc "list: the path must exist" 3 nostdin shell::rsync::list "$HOME/nope/"

# --- version ------------------------------------------------------------------------------------
reset
nostdin shell::rsync::version >/dev/null 2>&1
t_eq "version: rsync --version" "rsync [--version]" "$(last)"

# --- every function has a help page --------------------------------------------------------------
for fn in sync mirror move resume diff list version; do
	t_has "help: shell::rsync::$fn" "USAGE:" "$("shell::rsync::$fn" --help 2>&1)"
done
t_has "help: mirror mentions its own option" "--allow-empty" "$(shell::rsync::mirror -h 2>&1)"
t_has "help: resume mentions its own option" "--retries" "$(shell::rsync::resume -h 2>&1)"
t_has "help: diff explains the output" "*deleting" "$(shell::rsync::diff -h 2>&1)"
t_lacks "help: diff has no --simulate" "--simulate" "$(shell::rsync::diff -h 2>&1)"
t_lacks "help: move has no --delete" "--delete " "$(shell::rsync::move -h 2>&1)"
t_has "help: sync has --delete" "--delete " "$(shell::rsync::sync -h 2>&1)"

t_done
