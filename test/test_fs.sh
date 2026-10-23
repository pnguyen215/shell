#!/usr/bin/env bash
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

shell::fs::mkdir --private "$HOME/priv" >/dev/null 2>&1
t_eq "mkdir --private is 700" "700" "$(shell::fs::stat mode "$HOME/priv")"
shell::fs::touch --private "$HOME/deep/er/secret.conf" >/dev/null 2>&1
t_eq "touch --private file is 600" "600" "$(shell::fs::stat mode "$HOME/deep/er/secret.conf")"
shell::fs::touch "$HOME/plain.txt" >/dev/null 2>&1
t_rc "touch keeps existing file" 0 test -f "$HOME/plain.txt"

# Regression: remove must refuse dangerous targets.
t_rc "remove refuses /" 2 shell::fs::remove /
t_rc "remove refuses \$HOME" 2 shell::fs::remove "$HOME"
t_rc "remove refuses empty" 2 shell::fs::remove ""
printf 'x' >"$HOME/del.txt"
shell::fs::remove "$HOME/del.txt" >/dev/null 2>&1
t_rc "remove deletes a file" 1 test -e "$HOME/del.txt"

printf 'a=1\nb=2\n' >"$HOME/f.txt"
shell::fs::sed_inplace 's/a=1/a=9/' "$HOME/f.txt"
t_eq "sed_inplace edits" "a=9" "$(head -n1 "$HOME/f.txt")"
t_eq "sed_inplace leaves no backup" "0" "$(find "$HOME" -maxdepth 1 -name '*shellbak*' | wc -l | tr -d ' ')"

printf 'hello' >"$HOME/m.json"
t_eq "mime json" "application/json" "$(shell::file::mime "$HOME/m.json")"
t_eq "mime of missing file fails" "3" "$(
	shell::file::mime "$HOME/none" >/dev/null 2>&1
	echo $?
)"
t_eq "base64 is single line" "aGVsbG8=" "$(shell::encode::file::base64 "$HOME/m.json")"

shell::fs::copy "$HOME/m.json" c1.json >/dev/null 2>&1
t_rc "copy created file" 0 test -f "$HOME/c1.json"
t_rc "copy refuses to overwrite" 1 shell::fs::copy "$HOME/m.json" c1.json
mkdir "$HOME/dest"
shell::fs::move "$HOME/dest" "$HOME/c1.json" >/dev/null 2>&1
t_rc "move put file in dest" 0 test -f "$HOME/dest/c1.json"

shell::permission::secure "$HOME/f.txt"
t_eq "permission::secure -> 600" "600" "$(shell::fs::stat mode "$HOME/f.txt")"
shell::permission::set "$HOME/f.txt" owner=read,write,execute group=read others=none >/dev/null 2>&1
t_eq "permission::set -> 740" "740" "$(shell::fs::stat mode "$HOME/f.txt")"
t_has "permission::analyze" "755" "$(shell::permission::analyze -rwxr-xr-x 2>&1)"

# Regression: IP validation used to fail even for valid addresses.
t_rc "ipv4 valid" 0 shell::validate::ip::address 192.168.1.10
t_rc "ipv4 octet range" 1 shell::validate::ip::address 999.1.1.1
t_rc "ipv6 valid" 0 shell::validate::ip::address 2001:db8::1
t_rc "ipv6 too short" 1 shell::validate::ip::address 1:2:3
t_rc "ipv6 two ::" 1 shell::validate::ip::address 1::2::3

# Ports
t_rc "port valid" 0 shell::net::port::valid 8080
t_rc "port zero invalid" 1 shell::net::port::valid 0
t_rc "port non-numeric invalid" 1 shell::net::port::valid 80a

t_done
