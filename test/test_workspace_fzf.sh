#!/usr/bin/env bash
# shell::workspace::view::fzf / edit::fzf / manage::fzf (src/lib/workspace.sh): the live browser
# (config file -> key -> action -> back to the list), masking of secrets, copy on every pass of the
# loop, validated edits, the "← Back" entry and dry-run.
#
# fzf is a fake: the Nth call picks the line of $FAKE_FZF_PICKS that matches text (an empty pick is ESC)
# and logs the candidate lines (stdin.N) and its arguments (args.N). pbcopy is a fake that appends what it
# is given to $FAKE_CLIP, each copy ended by "|".
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

mkdir "$HOME/bin"
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
n="$(cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0)"
n=$((n + 1))
echo "$n" >"$FAKE_FZF_STATE"
cat >"$FAKE_FZF_DIR/stdin.$n"
printf '%s\n' "$@" >"$FAKE_FZF_DIR/args.$n"
pick="$(printf '%s\n' "$FAKE_FZF_PICKS" | sed -n "${n}p")"
[ -z "$pick" ] && exit 130
grep -F -- "$pick" "$FAKE_FZF_DIR/stdin.$n" | head -n 1
FAKE
cat >"$HOME/bin/pbcopy" <<'FAKE'
#!/bin/sh
cat >>"$FAKE_CLIP"
printf '|' >>"$FAKE_CLIP"
FAKE
chmod +x "$HOME/bin/fzf" "$HOME/bin/pbcopy"
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME/fzfdir" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_CLIP="$HOME/clip.log"
mkdir "$FAKE_FZF_DIR"
B="$SHELL_FZF_BACK_LABEL"
export TERM=dumb

# run <picks> <stdin> <command...>  -> exit status; output in $HOME/out.log
run() {
	rm -f "$FAKE_FZF_STATE" "$FAKE_CLIP"
	find "$FAKE_FZF_DIR" -name "stdin.*" -delete
	printf '%s' "$2" | FAKE_FZF_PICKS="$1" "${@:3}" >"$HOME/out.log" 2>&1
	echo "$?"
}
calls() { cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0; }
b64() { printf '%s' "$1" | base64 | tr -d '\n'; }

SECRET='p@ss w"ord$1'
ws="$SHELL_WORKSPACE_DIR/dxc/.ssh"
mkdir -p "$ws"
conf="$ws/server.conf"
{
	printf '[base]\nSSH_LOCAL_ADDR=%s\n\n' "$(b64 127.0.0.1)"
	printf '[dev]\nSSH_SERVER_ADDR=%s\nSSH_SERVER_PORT=%s\nSSH_SERVER_USER=%s\n' "$(b64 10.0.0.5)" "$(b64 22)" "$(b64 sysadmin)"
	printf 'SSH_LOCAL_PORT=%s\nSSH_SERVER_TARGET_SERVICE_PORT=%s\nDB_PASSWORD=%s\n' "$(b64 5432)" "$(b64 5432)" "$(b64 "$SECRET")"
} >"$conf"
printf '[dev]\nSSH_SERVER_PORT=%s\n' "$(b64 9092)" >"$ws/kafka.conf"
read_key() { shell::ini::read "$conf" "$1" "$2" 2>/dev/null; }

# --- the cache behind the live preview ------------------------------------------
cache="$HOME/cache"
_shell::workspace::conf::load "$conf" "$cache" dxc
t_eq "load: every key is listed" "7" "$(wc -l <"$cache/rows" | tr -d ' ')"
pw_n="$(awk -F'\t' '$2 == "DB_PASSWORD" { print $3 }' "$cache/kv")"
t_eq "load: the secret is kept exactly for copy" "$SECRET" "$(cat "$cache/v/$pw_n")"
t_eq "load: the secret is not in its preview" "0" "$(grep -cF 'ord$1' "$cache/p/$pw_n")"
t_eq "load: nor in the file overview" "0" "$(grep -cF 'ord$1' "$cache/o")"
t_has "load: the preview says it is hidden" "hidden" "$(cat "$cache/p/$pw_n")"
addr_n="$(awk -F'\t' '$2 == "SSH_SERVER_ADDR" { print $3 }' "$cache/kv")"
t_has "load: a normal value is decoded in the preview" "10.0.0.5" "$(cat "$cache/p/$addr_n")"
t_has "load: the preview shows the other keys of the section" "SSH_SERVER_USER" "$(cat "$cache/p/$addr_n")"
t_eq "sensitive: a *_REF key is a path, not a secret" "1" "$(
	_shell::workspace::conf::sensitive SSH_PRIVATE_KEY_REF
	echo $?
)"
t_eq "ssh_command: built from the section and [base]" "ssh -N -L 127.0.0.1:5432:127.0.0.1:5432 -p 22 sysadmin@10.0.0.5" "$(_shell::workspace::conf::ssh_command "$cache" dev)"

# --- view: copy on every pass, then Back ------------------------------------------
add="$(printf '%-8s %s' dev SSH_SERVER_ADDR)"
port="$(printf '%-8s %s' dev SSH_SERVER_PORT)"
t_eq "view: copy, copy again, Back, Back returns RETURN_BACK" "$RETURN_BACK" "$(run "server.conf
$add
Copy value
$port
Copy value
$B
$B" "" shell::workspace::view::fzf dxc)"
t_eq "view: both copies reached the clipboard, in order" "10.0.0.5|22|" "$(cat "$FAKE_CLIP")"
t_eq "view: the list came back after each action (7 menus)" "7" "$(calls)"
t_eq "view: Back is the last entry of the file list" "$B" "$(sed -n 's/\t.*//p' "$FAKE_FZF_DIR/stdin.1" | tail -n 1)"
t_eq "view: ...and of the key list" "$B" "$(sed -n 's/\t.*//p' "$FAKE_FZF_DIR/stdin.2" | tail -n 1)"
t_eq "view: ...and of the action menu" "$B" "$(tail -n 1 "$FAKE_FZF_DIR/stdin.3")"
t_has "view: the cursor comes back on the item copied last" "start:pos(" "$(cat "$FAKE_FZF_DIR/args.4")"
t_has "view: the key list has a live preview" "--preview=cat" "$(cat "$FAKE_FZF_DIR/args.2")"

run "server.conf
$(printf '%-8s %s' dev DB_PASSWORD)
Copy value
$B
$B
$B" "" shell::workspace::view::fzf dxc >/dev/null
t_eq "view: a value with spaces, quotes and \$ is copied verbatim" "${SECRET}|" "$(cat "$FAKE_CLIP")"
t_has "view: Reveal value is offered for a secret" "Reveal value" "$(cat "$FAKE_FZF_DIR/stdin.3")"
run "server.conf
$add
Copy value
$B
$B" "" shell::workspace::view::fzf dxc >/dev/null
t_eq "view: ...and not for a normal value" "0" "$(grep -c 'Reveal value' "$FAKE_FZF_DIR/stdin.3")"
t_has "view: the ssh tunnel command is offered" "Copy ssh tunnel command" "$(cat "$FAKE_FZF_DIR/stdin.3")"

run "server.conf
$(printf '%-8s %s' dev DB_PASSWORD)
Reveal value
$B
$B
$B" "" shell::workspace::view::fzf dxc >/dev/null
t_has "view: Reveal value prints the secret on request" 'p@ss w"ord$1' "$(cat "$HOME/out.log")"

t_eq "view: ESC returns 0" "0" "$(run "" "" shell::workspace::view::fzf dxc)"
t_eq "view: Back at the file list returns RETURN_BACK" "$RETURN_BACK" "$(run "$B" "" shell::workspace::view::fzf dxc)"
t_eq "view: Back at the action menu returns to the key list" "$RETURN_BACK" "$(run "server.conf
$add
$B
$B
$B" "" shell::workspace::view::fzf dxc)"
t_eq "view: ...which showed the key list twice" "5" "$(calls)"
t_eq "view: Back copied nothing" "" "$(cat "$FAKE_CLIP" 2>/dev/null)"
t_eq "view: unknown workspace returns 1" "1" "$(run "" "" shell::workspace::view::fzf nope)"
t_eq "view: no argument returns 1" "1" "$(run "" "" shell::workspace::view::fzf)"

run "server.conf
$add
Copy value
$B
$B" "" shell::workspace::view::fzf -n dxc >/dev/null
t_eq "view -n: only the command is put on the clipboard, not the value alone" "shell::clipboard::copy 10.0.0.5|" "$(cat "$FAKE_CLIP" 2>/dev/null)"
t_has "view -n: the command is printed" "shell::clipboard::copy" "$(cat "$HOME/out.log")"
run "server.conf
$(printf '%-8s %s' dev DB_PASSWORD)
Copy value
$B
$B" "" shell::workspace::view::fzf -n dxc >/dev/null
t_eq "view -n: a secret is not printed" "0" "$(grep -cF 'ord$1' "$HOME/out.log")"
t_eq "view -n: nor put on the clipboard" "0" "$(grep -cF 'ord$1' "$FAKE_CLIP")"

# A workspace with one file skips the file list.
mkdir -p "$SHELL_WORKSPACE_DIR/solo/.ssh"
printf '[dev]\nSSH_SERVER_PORT=%s\n' "$(b64 80)" >"$SHELL_WORKSPACE_DIR/solo/.ssh/web.conf"
t_eq "view: one file -> straight to the keys, Back leaves" "$RETURN_BACK" "$(run "$B" "" shell::workspace::view::fzf solo)"
t_eq "view: ...with a single menu" "1" "$(calls)"
mkdir -p "$SHELL_WORKSPACE_DIR/empty/.ssh"
t_eq "view: a workspace without .conf file returns 0" "0" "$(run "" "" shell::workspace::view::fzf empty)"

# --- edit: validated, saved, back to the list ----------------------------------------
before="$(cat "$conf")"
t_eq "edit: Back at the top returns RETURN_BACK" "$RETURN_BACK" "$(run "$B" "" shell::workspace::edit::fzf dxc)"
t_eq "edit: Back changed nothing" "$before" "$(cat "$conf")"
t_eq "edit: a valid port is saved, the list comes back, Back leaves" "$RETURN_BACK" "$(run "server.conf
$port
Edit value
$B
$B" "2222
" shell::workspace::edit::fzf dxc)"
t_eq "edit: the new value is Base64-encoded in the file" "2222" "$(read_key dev SSH_SERVER_PORT)"
t_eq "edit: the file stays valid (other values intact)" "10.0.0.5" "$(read_key dev SSH_SERVER_ADDR)"
t_eq "edit: the list came back after the save (5 menus)" "5" "$(calls)"
before="$(cat "$conf")"
run "server.conf
$port
Edit value
$B
$B" "99999
" shell::workspace::edit::fzf dxc >/dev/null
t_eq "edit: an invalid port is refused, nothing written" "$before" "$(cat "$conf")"
t_has "edit: ...with the reason" "not a valid port" "$(cat "$HOME/out.log")"
run "server.conf
$add
Edit value
$B
$B" "bad host!
" shell::workspace::edit::fzf dxc >/dev/null
t_eq "edit: an invalid address is refused" "$before" "$(cat "$conf")"
run "server.conf
$port
Edit value
$B
$B" "3333
" shell::workspace::edit::fzf -n dxc >/dev/null
t_eq "edit -n: nothing is written" "$before" "$(cat "$conf")"
t_has "edit -n: the command is printed" "shell::ini::write" "$(cat "$HOME/out.log")"
run "server.conf
$port
Edit value
$B
$B" "" shell::workspace::edit::fzf dxc >/dev/null
t_eq "edit: end of input at the prompt writes nothing" "$before" "$(cat "$conf")"
run "server.conf
$(printf '%-8s %s' dev DB_PASSWORD)
Edit value
$B
$B" "s3cret-new
" shell::workspace::edit::fzf -n dxc >/dev/null
t_eq "edit -n: a secret value is not printed" "0" "$(grep -c 's3cret-new' "$HOME/out.log")"

run "server.conf
$(printf '%-8s %s' dev DB_PASSWORD)
Remove key
no
$B
$B" "" shell::workspace::edit::fzf dxc >/dev/null
t_eq "edit: Remove key answered no keeps the key" "$SECRET" "$(read_key dev DB_PASSWORD)"
run "server.conf
$(printf '%-8s %s' dev DB_PASSWORD)
Remove key
yes
$B
$B" "" shell::workspace::edit::fzf dxc >/dev/null
t_eq "edit: Remove key answered yes removes it" "" "$(read_key dev DB_PASSWORD)"
t_eq "edit: ...and the other keys stay" "10.0.0.5" "$(read_key dev SSH_SERVER_ADDR)"

# --- manage: the whole loop (view -> copy -> back -> copy -> edit -> copy -> back -> exit) ---
rm -f "$FAKE_CLIP"
t_eq "manage: view, copy, copy, back; edit, save, copy, back; Back leaves" "$RETURN_BACK" "$(run "dxc
view
server.conf
$add
Copy value
$port
Copy value
$B
$B
dxc
edit
server.conf
$port
Edit value
$(printf '%-8s %s' dev SSH_SERVER_USER)
Copy value
$B
$B
$B" "4444
" shell::workspace::manage::fzf)"
t_eq "manage: every copy reached the clipboard, also after edit" "10.0.0.5|2222|sysadmin|" "$(cat "$FAKE_CLIP")"
t_eq "manage: the edit inside the loop was saved" "4444" "$(read_key dev SSH_SERVER_PORT)"
t_eq "manage: the workspace list came back after each action" "dxc" "$(sed -n 's/\t.*//p' "$FAKE_FZF_DIR/stdin.10" | head -n 1)"
t_has "manage: the workspace list has a live preview" "--preview=cat" "$(cat "$FAKE_FZF_DIR/args.1")"
_shell::workspace::ws::previews "$SHELL_WORKSPACE_DIR" "$HOME/wsprev"
t_has "manage: the preview shows user@address:port" "sysadmin@10.0.0.5:4444" "$(cat "$HOME/wsprev/ws.dxc")"
t_has "manage: ...for every file of the workspace" "kafka.conf" "$(cat "$HOME/wsprev/ws.dxc")"
t_eq "manage: the preview skips sections without server fields" "0" "$(grep -c '\[base\]' "$HOME/wsprev/ws.dxc")"
t_has "manage: a workspace without .conf file still has a preview" "empty" "$(cat "$HOME/wsprev/ws.empty")"
t_has "manage: the awk Base64 decoder handles padding (22, 2222...)" "sysadmin@10.0.0.5:4444" "$(cat "$HOME/wsprev/ws.dxc")"
t_eq "manage: Back at the list returns RETURN_BACK" "$RETURN_BACK" "$(run "$B" "" shell::workspace::manage::fzf)"
t_eq "manage: Back at the action menu returns to the list" "$RETURN_BACK" "$(run "dxc
$B
$B" "" shell::workspace::manage::fzf)"
t_eq "manage: ...which showed the list twice" "3" "$(calls)"
t_eq "manage: ESC returns 0" "0" "$(run "" "" shell::workspace::manage::fzf)"
run "dxc
copy path
$B" "" shell::workspace::manage::fzf >/dev/null
t_eq "manage: copy path" "$SHELL_WORKSPACE_DIR/dxc|" "$(cat "$FAKE_CLIP")"
t_eq "manage: the action menu ends with Back" "$B" "$(tail -n 1 "$FAKE_FZF_DIR/stdin.2")"
run "dxc
remove
$B" "" shell::workspace::manage::fzf -n >/dev/null
t_eq "manage -n: remove is only printed" "1" "$([ -d "$SHELL_WORKSPACE_DIR/dxc" ] && echo 1 || echo 0)"
t_eq "manage: a missing workspace directory returns 1" "1" "$(
	SHELL_WORKSPACE_DIR="$HOME/none" run "" "" shell::workspace::manage::fzf
)"

# The temp directories are always removed.
t_eq "no temp directory is left behind" "0" "$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'shell-workspace.*' 2>/dev/null | wc -l | tr -d ' ')"

t_done
