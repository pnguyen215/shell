#!/usr/bin/env bash
# The nvm commands against a REAL nvm.sh (not the fake of the other nvm tests): that `use` really changes
# the PATH of this shell, that what follows the version of `exec` / `run` reaches the command with its
# arguments intact, that the parsers read what nvm really prints, that automatic switching follows a
# `cd`, and the whole life of an install (nvm, its versions, its removal).
#
# Skipped unless SHELL_TEST_NVM_SRC points at a checkout of https://github.com/nvm-sh/nvm (the directory
# with nvm.sh and nvm-exec):
#
#   git clone --depth 1 https://github.com/nvm-sh/nvm /tmp/nvm-src
#   SHELL_TEST_NVM_SRC=/tmp/nvm-src test/run_tests.sh nvm_real
#
# Nothing is downloaded: the "Node versions" are tiny scripts that print their version, placed where nvm
# keeps real ones, in a temporary NVM_DIR under the test's temporary HOME.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

nl='
'
rc_of() {
	"$@" >/dev/null 2>&1
	echo "$?"
}

real_tests() {
	export NVM_DIR="$HOME/.nvm"
	unset -f nvm 2>/dev/null
	mkdir -p "$NVM_DIR/versions/node" "$HOME/bin"
	cp "$SHELL_TEST_NVM_SRC/nvm.sh" "$SHELL_TEST_NVM_SRC/nvm-exec" "$NVM_DIR/"
	[ -f "$SHELL_TEST_NVM_SRC/bash_completion" ] && cp "$SHELL_TEST_NVM_SRC/bash_completion" "$NVM_DIR/"
	local v
	for v in v18.19.0 v20.9.0 v20.11.1 v22.2.0; do
		mkdir -p "$NVM_DIR/versions/node/$v/bin"
		printf '#!/bin/sh\ncase "$1" in\n-v | --version) echo %s ;;\n*) echo "node %s args: $*" ;;\nesac\n' "$v" "$v" >"$NVM_DIR/versions/node/$v/bin/node"
		chmod +x "$NVM_DIR/versions/node/$v/bin/node"
	done
	# fzf: answer the Nth call with the Nth line of $FAKE_FZF_PICKS (text matched against the candidates)
	cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
n="$(cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0)"
n=$((n + 1))
echo "$n" >"$FAKE_FZF_STATE"
cat >"$FAKE_FZF_DIR/stdin.$n"
pick="$(printf '%s\n' "$FAKE_FZF_PICKS" | sed -n "${n}p")"
[ -z "$pick" ] && exit 130
printf '%s\n' "$pick" | tr ';' '\n' | while IFS= read -r want; do
	grep -F -- "$want" "$FAKE_FZF_DIR/stdin.$n" | head -n 1
done
FAKE
	chmod +x "$HOME/bin/fzf"
	mkdir -p "$HOME/fzfdir"
	export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME/fzfdir" FAKE_FZF_STATE="$HOME/fzf.count"

	t_eq "real: nvm is not loaded before the first command" "no" "$(type nvm >/dev/null 2>&1 && echo yes || echo no)"
	case "$(shell::nvm::version 2>/dev/null | tail -n 1)" in
	[0-9]*.[0-9]*.[0-9]*) t_ok ;;
	*) t_bad "real: shell::nvm::version prints nvm's version" "got [$(shell::nvm::version 2>&1)]" ;;
	esac
	t_eq "real: ...and loading it did not switch Node (--no-use)" "system" "$(shell::nvm::query current)"

	# What nvm prints, as the parsers read it.
	t_eq "real: the installed versions" "v18.19.0 v20.9.0 v20.11.1 v22.2.0" "$(shell::nvm::versions::installed | tr '\n' ' ' | sed 's/ $//')"
	shell::nvm::default 22 >/dev/null 2>&1
	shell::nvm::alias work 18.19.0 >/dev/null 2>&1
	t_has "real: default and your alias, as nvm prints them" "work -> 18.19.0" "$(shell::nvm::aliases::user)"
	t_lacks "real: nvm's own aliases are not yours" "iojs" "$(shell::nvm::aliases::user)"
	t_has "real: the aliases of a version, in the rows" "default" "$(shell::nvm::fzf::rows::installed | grep '^v22.2.0')"
	t_has "real: ...your alias" "work" "$(shell::nvm::fzf::rows::installed | grep '^v18.19.0')"

	# `use` must change THIS shell.
	shell::nvm::use --silent 20 >/dev/null 2>&1
	t_eq "real: use changes the Node of this very shell" "$NVM_DIR/versions/node/v20.11.1/bin/node" "$(command -v node)"
	t_eq "real: current agrees" "v20.11.1" "$(shell::nvm::current 2>/dev/null | tail -n 1)"
	t_eq "real: which" "$NVM_DIR/versions/node/v22.2.0/bin/node" "$(shell::nvm::which 22 2>/dev/null | tail -n 1)"
	t_eq "real: the rows mark the one in use" "v20.11.1" "$(shell::nvm::fzf::rows::installed | grep '\[current\]' | awk '{ print $1 }')"
	t_eq "real: version::local resolves a prefix" "v20.11.1" "$(shell::nvm::version::local 20 2>/dev/null | tail -n 1)"
	shell::nvm::version::local 99 >/dev/null 2>&1
	t_eq "real: ...and says N/A with status 3 for an unknown one" "3" "$?"
	shell::nvm::deactivate --silent >/dev/null 2>&1
	t_eq "real: deactivate gives the system Node back" "system" "$(shell::nvm::query current)"

	# run / exec: what follows the version reaches the command untouched.
	t_eq "real: run passes node's arguments, flags included" "node v18.19.0 args: app.js --port 3000" "$(shell::nvm::run --silent 18 app.js --port 3000 2>/dev/null | tail -n 1)"
	t_eq "real: exec keeps the boundaries of its arguments" "a b|c|" "$(shell::nvm::exec --silent 22 sh -c 'printf "%s|" "$@"' x 'a b' c 2>/dev/null | tail -n 1)"
	t_has "real: exec puts that version first on the PATH" "$NVM_DIR/versions/node/v22.2.0/bin:" "$(shell::nvm::exec --silent 22 sh -c 'echo $PATH' 2>/dev/null | tail -n 1)"
	t_eq "real: ...without switching this shell" "system" "$(shell::nvm::query current)"
	shell::nvm::use --silent 20 >/dev/null 2>&1
	t_eq "real: exec 'current' runs on the active version" "ok" "$(shell::nvm::exec --silent current sh -c 'echo ok' 2>/dev/null | tail -n 1)"

	# uninstall
	shell::nvm::use --silent 22 >/dev/null 2>&1
	shell::nvm::uninstall v22.2.0 >/dev/null 2>&1
	t_eq "real: nvm refuses to uninstall the version in use (status 1)" "1" "$?"
	t_eq "real: ...and it is still there" "yes" "$([ -d "$NVM_DIR/versions/node/v22.2.0" ] && echo yes || echo no)"

	# .nvmrc
	local proj="$HOME/proj"
	mkdir -p "$proj/sub"
	(cd "$proj" && shell::nvm::nvmrc::write 18 >/dev/null 2>&1)
	t_eq "real: use with no version follows the .nvmrc of the project" "v18.19.0" "$(cd "$proj/sub" && shell::nvm::use --silent >/dev/null 2>&1 && shell::nvm::query current)"
	shell::nvm::use --silent 22 >/dev/null 2>&1

	# the unused versions, on what nvm really reports
	local scan
	scan="$(shell::nvm::unused::scan | cut -f1,2 | tr '\t' ':' | tr '\n' ' ' | sed 's/ $//')"
	t_eq "real: 22 (in use, default, node, stable) and 18 (work) are kept; the v20s are not" "v20.9.0:superseded v20.11.1:unreferenced" "$scan"
	t_eq "real: a project's .nvmrc keeps its version" "v20.11.1:unreferenced" "$(printf '20.9.0\n' >"$proj/sub/.nvmrc" && shell::nvm::unused::scan -p "$proj" | cut -f1,2 | tr '\t' ':' | tr '\n' ' ' | sed 's/ $//')"
	rm -f "$proj/sub/.nvmrc"
	t_eq "real: shell::nvm::size sees every version" "4" "$(shell::nvm::size 2>/dev/null | grep -c ' v')"

	# the pickers, on the real thing
	rm -f "$FAKE_FZF_STATE"
	FAKE_FZF_PICKS="v20.11.1" shell::nvm::use::fzf --silent >/dev/null 2>&1
	t_eq "real: use::fzf switches this shell to the pick" "v20.11.1" "$(shell::nvm::query current)"
	rm -f "$FAKE_FZF_STATE"
	printf 'y\n' | FAKE_FZF_PICKS="v20.9.0" shell::nvm::unused::fzf >/dev/null 2>&1
	t_eq "real: unused::fzf really uninstalls the pick" "no" "$([ -d "$NVM_DIR/versions/node/v20.9.0" ] && echo yes || echo no)"
	t_eq "real: ...and only that" "yes" "$([ -d "$NVM_DIR/versions/node/v20.11.1" ] && [ -d "$NVM_DIR/versions/node/v22.2.0" ] && [ -d "$NVM_DIR/versions/node/v18.19.0" ] && echo yes || echo no)"
	rm -f "$FAKE_FZF_STATE"
	printf 'work\n' | FAKE_FZF_PICKS="v18.19.0" shell::nvm::alias::fzf >/dev/null 2>&1
	t_has "real: alias::fzf created the alias, pointing at the version that was picked" "work -> v18.19.0" "$(shell::nvm::aliases::user)"

	# automatic switching follows a cd
	local a18="$HOME/auto18" a20="$HOME/auto20"
	mkdir -p "$a18" "$a20"
	printf '18\n' >"$a18/.nvmrc"
	printf '20\n' >"$a20/.nvmrc"
	cd "$a18" || return 1
	SHELL_NVM_AUTOUSE="" shell::nvm::autouse::on >/dev/null 2>&1
	t_eq "real: autouse::on applies the .nvmrc of the directory you are in" "v18.19.0" "$(shell::nvm::query current)"
	cd "$a20" || return 1
	SHELL_NVM_AUTOUSE_PWD="" shell::nvm::autouse::hook >/dev/null 2>&1
	t_eq "real: ...and follows a cd (zsh by itself, bash at the prompt)" "v20.11.1" "$(shell::nvm::query current)"
	shell::nvm::autouse::off >/dev/null 2>&1
	cd "$HOME" || return 1

	# the check-up and the cache
	t_has "real: doctor reports nvm and the default" "default: default -> 22" "$(shell::nvm::doctor 2>&1)"
	t_eq "real: cache dir" "$NVM_DIR/.cache" "$(shell::nvm::cache 2>/dev/null | tail -n 1)"

	# the end of it: remove nvm itself, for real
	shell::dependency::nvm::uninstall -y >/dev/null 2>&1
	t_eq "real: the uninstaller removes the whole nvm directory" "no" "$([ -e "$HOME/.nvm" ] && echo yes || echo no)"
	t_eq "real: ...and nvm is gone from this shell" "no" "$(type nvm >/dev/null 2>&1 && echo yes || echo no)"
}

if [ -n "${SHELL_TEST_NVM_SRC-}" ] && [ -f "${SHELL_TEST_NVM_SRC-}/nvm.sh" ]; then
	real_tests
else
	printf '  (skipped: set SHELL_TEST_NVM_SRC to a checkout of nvm-sh/nvm to run these against the real nvm)\n'
fi

t_done
