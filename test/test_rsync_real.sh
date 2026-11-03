#!/usr/bin/env bash
# The shell::rsync::* commands against a REAL rsync (not the fake of test_rsync.sh): that the flags each
# command builds are accepted by rsync and do what the documentation says, on local directories and over
# a stand-in for ssh. It is where facts that cheat sheets get wrong are pinned down, for example that
# `--max-delete` deletes up to the limit and then stops (status 25) instead of refusing up front, and that
# `--partial-dir` and `--append-verify` cannot be used together.
#
# Skipped unless the rsync on the PATH is 3.x: macOS ships 2.6.9 / openrsync, which lack some of the flags.
#
# The "ssh" is a script that drops the ssh options and the host and runs the remote command here, so the
# remote-shell code path of rsync is exercised without a server.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

real_tests() {
	export SHELL_RSYNC_RETRY_DELAY=0
	mkdir -p "$HOME/bin"
	cat >"$HOME/bin/ssh" <<'FAKESSH'
#!/bin/sh
echo "ssh $*" >>"$FAKE_SSH_LOG"
while [ $# -gt 0 ]; do
	case "$1" in
	-i | -p | -F | -J | -o | -l) shift 2 ;;
	-*) shift ;;
	*) break ;;
	esac
done
shift
exec "$@"
FAKESSH
	chmod +x "$HOME/bin/ssh"
	export PATH="$HOME/bin:$PATH" FAKE_SSH_LOG="$HOME/ssh.log"
	: >"$FAKE_SSH_LOG"

	files() { (cd "$1" && find . -type f | sort | tr '\n' ' '); }
	quiet() { "$@" </dev/null >/dev/null 2>&1; }
	nostdin() { "$@" </dev/null; }

	mkdir -p "$HOME/src/sub" "$HOME/src/node_modules"
	echo A >"$HOME/src/a.txt"
	echo B >"$HOME/src/sub/b.txt"
	echo L >"$HOME/src/x.log"
	echo N >"$HOME/src/node_modules/n.js"

	# --- sync ---
	quiet shell::rsync::sync --exclude node_modules --exclude '*.log' "$HOME/src/" "$HOME/o1/"
	t_eq "real sync: copies the rest, honours --exclude" "./a.txt ./sub/b.txt " "$(files "$HOME/o1")"
	quiet shell::rsync::sync --include '*.log' --exclude '*' "$HOME/src/" "$HOME/o2/"
	t_eq "real sync: include before exclude (first rule wins)" "./x.log " "$(files "$HOME/o2")"
	quiet shell::rsync::sync "$HOME/src" "$HOME/o3/"
	t_eq "real sync: no trailing slash copies the directory itself" "yes" "$([ -f "$HOME/o3/src/a.txt" ] && echo yes || echo no)"
	t_rc "real sync: -z --bwlimit --chmod --stats --human are accepted" 0 nostdin shell::rsync::sync -z --bwlimit 5000 --chmod 'D755,F600' --stats --human "$HOME/src/" "$HOME/o4/"
	t_eq "real sync: --chmod applied" "600" "$(shell::fs::stat mode "$HOME/o4/a.txt")"
	t_rc "real sync: --total-progress is accepted (rsync 3.1+)" 0 nostdin shell::rsync::sync --total-progress "$HOME/src/" "$HOME/o5/"

	# --- over the stand-in for ssh ---
	echo key >"$HOME/k"
	quiet shell::rsync::sync -i "$HOME/k" -p 2222 -o ConnectTimeout=5 --exclude node_modules --exclude '*.log' "$HOME/src/" me@host:"$HOME/o6/"
	t_eq "real ssh push: copies" "./a.txt ./sub/b.txt " "$(files "$HOME/o6")"
	t_has "real ssh push: ssh received the options" "-o ConnectTimeout=5 -i $HOME/k -p 2222" "$(tail -n 1 "$FAKE_SSH_LOG")"
	quiet shell::rsync::sync me@host:"$HOME/src/" "$HOME/o7/"
	t_eq "real ssh pull: copies everything" "./a.txt ./node_modules/n.js ./sub/b.txt ./x.log " "$(files "$HOME/o7")"
	t_has "real ssh list: lists the remote directory" "a.txt" "$(shell::rsync::list me@host:"$HOME/src/" </dev/null 2>&1)"

	# --- diff ---
	echo CHANGED >"$HOME/src/a.txt"
	touch -t 202001010000 "$HOME/src/a.txt" # a different time for sure, so the size and the time both differ
	echo extra >"$HOME/o1/extra.txt"
	T_OUT="$(shell::rsync::diff --exclude node_modules --exclude '*.log' "$HOME/src/" "$HOME/o1/" </dev/null 2>&1)"
	t_has "real diff: a changed file" ">f.st...... a.txt" "$T_OUT"
	t_has "real diff: a file only at the destination" "*deleting   extra.txt" "$T_OUT"
	t_eq "real diff: changed nothing" "yes" "$([ -f "$HOME/o1/extra.txt" ] && [ "$(cat "$HOME/o1/a.txt")" = "A" ] && echo yes || echo no)"
	T_OUT="$(shell::rsync::diff --no-delete --exclude node_modules --exclude '*.log' "$HOME/src/" "$HOME/o1/" </dev/null 2>&1)"
	t_lacks "real diff: --no-delete leaves the deletions out" "deleting" "$T_OUT"

	# --- mirror ---
	quiet shell::rsync::mirror --exclude node_modules --exclude '*.log' "$HOME/src" "$HOME/o1"
	t_eq "real mirror: the destination equals the source" "./a.txt ./sub/b.txt " "$(files "$HOME/o1")"
	t_eq "real mirror: ...with the new content" "CHANGED" "$(cat "$HOME/o1/a.txt")"
	mkdir -p "$HOME/emptydir"
	t_rc "real mirror: an empty source is refused" 8 nostdin shell::rsync::mirror "$HOME/emptydir" "$HOME/o1"
	t_eq "real mirror: ...and the destination is untouched" "./a.txt ./sub/b.txt " "$(files "$HOME/o1")"
	mkdir -p "$HOME/big" "$HOME/o8"
	echo keep >"$HOME/big/keep"
	for i in 1 2 3 4 5 6; do echo x >"$HOME/o8/e$i"; done
	t_rc "real mirror: the limit stops the deletions (status 25)" 25 nostdin shell::rsync::mirror --max-delete 2 "$HOME/big" "$HOME/o8"
	t_eq "real mirror: ...after it deleted up to the limit, not before" "5" "$(ls "$HOME/o8" | wc -l | tr -d ' ')"
	quiet shell::rsync::mirror --max-delete 10 "$HOME/big" "$HOME/o8"
	t_eq "real mirror: with room, the rest is deleted" "keep" "$(ls "$HOME/o8")"

	# --- move ---
	mkdir -p "$HOME/mv/d"
	echo m >"$HOME/mv/f"
	echo n >"$HOME/mv/d/g"
	quiet shell::rsync::move "$HOME/mv/" "$HOME/mvdst/"
	t_eq "real move: files arrived" "./d/g ./f " "$(files "$HOME/mvdst")"
	t_eq "real move: files left the source, directories stayed" "" "$(files "$HOME/mv")"
	t_eq "real move: ...the empty directory is still there" "yes" "$([ -d "$HOME/mv/d" ] && echo yes || echo no)"

	# --- list ---
	T_OUT="$(shell::rsync::list "$HOME/src/" </dev/null 2>&1)"
	t_has "real list: shows files" "a.txt" "$T_OUT"
	t_lacks "real list: does not recurse by default" "b.txt" "$T_OUT"
	t_has "real list: -r recurses" "sub/b.txt" "$(shell::rsync::list -r "$HOME/src" </dev/null 2>&1)"
	t_eq "real list: copied nothing" "no" "$([ -e "$HOME/b.txt" ] && echo yes || echo no)"

	# --- resume ---
	head -c 300000 /dev/zero >"$HOME/bigfile"
	t_rc "real resume: default (partial dir)" 0 nostdin shell::rsync::resume "$HOME/bigfile" "$HOME/r1/"
	t_eq "real resume: file identical" "yes" "$(cmp -s "$HOME/bigfile" "$HOME/r1/bigfile" && echo yes || echo no)"
	t_rc "real resume: --append" 0 nostdin shell::rsync::resume --append "$HOME/bigfile" "$HOME/r2/"
	t_eq "real resume: --append, file identical" "yes" "$(cmp -s "$HOME/bigfile" "$HOME/r2/bigfile" && echo yes || echo no)"
	head -c 100000 "$HOME/bigfile" >"$HOME/r2/bigfile"
	t_rc "real resume: --append completes a truncated file" 0 nostdin shell::rsync::resume --append "$HOME/bigfile" "$HOME/r2/"
	t_eq "real resume: ...to the full size" "yes" "$(cmp -s "$HOME/bigfile" "$HOME/r2/bigfile" && echo yes || echo no)"
	t_rc "real resume: --partial" 0 nostdin shell::rsync::resume --partial "$HOME/bigfile" "$HOME/r3/"
	# the combination the DeployHQ cheat sheet shows is refused by rsync itself: the library refuses it first
	T_OUT="$(rsync -a --partial-dir=.p --append-verify "$HOME/bigfile" "$HOME/r4/" 2>&1)"
	t_has "real: rsync rejects --partial-dir with --append-verify" "cannot be used with" "$T_OUT"
	t_rc "real resume: so does the library" 2 nostdin shell::rsync::resume --append --partial-dir .p "$HOME/bigfile" "$HOME/r4/"

	# --- retries on a connection that fails twice ---
	mkdir -p "$HOME/flaky"
	cat >"$HOME/flaky/ssh" <<'FLAKY'
#!/bin/sh
n=$(cat "$FLAKY_COUNT" 2>/dev/null || echo 0)
n=$((n + 1))
echo "$n" >"$FLAKY_COUNT"
if [ "$n" -le 2 ]; then
	echo "ssh: connect to host: Connection timed out" >&2
	exit 255
fi
exec "$REAL_SSH" "$@"
FLAKY
	chmod +x "$HOME/flaky/ssh"
	export FLAKY_COUNT="$HOME/flaky.count" REAL_SSH="$HOME/bin/ssh"
	rm -f "$FLAKY_COUNT"
	(
		PATH="$HOME/flaky:$PATH"
		quiet shell::rsync::resume --retries 3 "$HOME/src/" me@host:"$HOME/r5/"
	)
	t_eq "real resume: the third run copied the files" "./a.txt ./node_modules/n.js ./sub/b.txt ./x.log " "$(files "$HOME/r5")"
	t_eq "real resume: ...after two failed runs" "3" "$(cat "$FLAKY_COUNT")"
}

case "$(rsync --version 2>/dev/null | head -n 1)" in
rsync\ \ version\ 3.*) real_tests ;;
*) printf '  (skipped: needs rsync 3.x on the PATH; this one is: %s)\n' "$(rsync --version 2>/dev/null | head -n 1)" ;;
esac

t_done
