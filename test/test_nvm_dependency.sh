#!/usr/bin/env bash
# shell::dependency::nvm::install and ::uninstall (src/dependency/nvm.sh): the pinned installer, what the
# installer is given, and above all the safety rules of the uninstaller, which runs `rm -rf`.
#
# The installer is faked: shell::net::run_remote_script is replaced by a function that records what it was
# given (URL, interpreter, NVM_DIR, PROFILE) and creates the nvm.sh a real install would. Nothing is
# downloaded and nothing outside the test's temporary HOME is ever touched.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

NVM="$HOME/.nvm"
export NVM_DIR="$NVM"
unset -f nvm 2>/dev/null
nl='
'
rc_of() {
	"$@" >/dev/null 2>&1
	echo "$?"
}
say() { "$@" 2>&1; }

# fake_install: put a minimal nvm where the installer would
fake_install() {
	if [ -z "${1-}" ] || [ "$1" = "/" ]; then
		printf 'fake_install: refusing "%s"\n' "${1-}" >&2
		return 1
	fi
	mkdir -p "$1/versions/node"
	cat >"$1/nvm.sh" <<'FAKE'
nvm() { printf '%s\n' "$*" >>"${FAKE_NVM_LOG:-/dev/null}"; }
FAKE
}

# --- install: help, options, versions -----------------------------------------------------------------
t_has "install -h: shows its usage" "USAGE: shell::dependency::nvm::install" "$(say shell::dependency::nvm::install -h)"
t_eq "install -h: returns 0" "0" "$(rc_of shell::dependency::nvm::install --help)"
t_eq "install: an unknown option" "2" "$(rc_of shell::dependency::nvm::install --bogus)"
t_eq "install: --version needs a value" "2" "$(rc_of shell::dependency::nvm::install --version)"
t_has "install -n: the pinned release is the default" "nvm-sh/nvm/$SHELL_NVM_VERSION/install.sh" "$(say shell::dependency::nvm::install -n)"
t_has "install -n: it is piped into bash" "| bash" "$(say shell::dependency::nvm::install -n)"
t_has "install -n: SHELL_NVM_VERSION is honoured" "nvm-sh/nvm/v0.39.1/install.sh" "$(SHELL_NVM_VERSION=v0.39.1 say shell::dependency::nvm::install -n)"
t_has "install -n -v: a release" "nvm-sh/nvm/v0.40.1/install.sh" "$(say shell::dependency::nvm::install -n -v v0.40.1)"
t_has "install -n -v: a release without the v" "nvm-sh/nvm/v0.40.1/install.sh" "$(say shell::dependency::nvm::install -n -v 0.40.1)"
t_has "install -n: it is the raw.githubusercontent.com URL" "https://raw.githubusercontent.com/nvm-sh/nvm/" "$(say shell::dependency::nvm::install -n)"
for bad in abc v1 1.2 v1.2 'v1.2.3;x' 'v1.2.3 x' 'v1.2.3/../x' '$(x)' 'v1.2.3-beta' vA.B.C '' 'master' 'v1.2.3|x'; do
	t_eq "install -v '$bad': refused" "2" "$(rc_of shell::dependency::nvm::install -n -v "$bad")"
done
t_has "install: ...with the reason" "Invalid nvm version: 'v1.2.3;x'" "$(say shell::dependency::nvm::install -n -v 'v1.2.3;x')"
t_eq "install -n: nothing is installed" "no" "$(shell::dependency::nvm::install -n >/dev/null 2>&1 && [ -e "$NVM_DIR" ] && echo yes || echo no)"

# --- install: the real flow, with the installer faked ----------------------------------------------------------
cat >"$HOME/stub.sh" <<'STUB'
# What the installer is handed, and a fake install.
shell::net::run_remote_script() {
	printf 'url=%s interp=%s NVM_DIR=%s PROFILE=%s\n' "$1" "${2-}" "${NVM_DIR-}" "${PROFILE-<unset>}" >>"$STUB_LOG"
	[ "${STUB_FAIL-}" = "yes" ] && return 1
	[ "${STUB_NOTHING-}" = "yes" ] && return 0
	mkdir -p "${NVM_DIR}/versions/node"
	printf 'nvm() { :; }\n' >"${NVM_DIR}/nvm.sh"
	return 0
}
shell::dependency::curl::ensure() { [ "${STUB_NO_CURL-}" != "yes" ]; }
STUB
export STUB_LOG="$HOME/stub.log"
: >"$STUB_LOG"
rm -rf "$NVM"
out="$(
	. "$HOME/stub.sh"
	shell::dependency::nvm::install 2>&1
	echo "rc=$?"
)"
t_has "install: succeeds" "rc=0" "$out"
t_has "install: says it is installed" "nvm installed" "$out"
t_eq "install: the installer got the pinned URL, bash and the NVM_DIR" "url=https://raw.githubusercontent.com/nvm-sh/nvm/$SHELL_NVM_VERSION/install.sh interp=bash NVM_DIR=$NVM_DIR PROFILE=<unset>" "$(cat "$STUB_LOG")"
t_eq "install: nvm.sh is where the installer put it" "yes" "$([ -s "$NVM/nvm.sh" ] && echo yes || echo no)"
t_has "install: and nvm is loaded afterwards" "function" "$(
	. "$HOME/stub.sh"
	rm -rf "$NVM"
	shell::dependency::nvm::install >/dev/null 2>&1
	type nvm 2>&1
)"
: >"$STUB_LOG"
rm -rf "$NVM"
(
	. "$HOME/stub.sh"
	shell::dependency::nvm::install -p >/dev/null 2>&1
)
t_has "install --no-profile: the installer is told not to touch the profile" "PROFILE=/dev/null" "$(cat "$STUB_LOG")"
: >"$STUB_LOG"
rm -rf "$NVM"
(
	. "$HOME/stub.sh"
	shell::dependency::nvm::install -v 0.39.1 >/dev/null 2>&1
)
t_has "install -v: that release is the one downloaded" "nvm-sh/nvm/v0.39.1/install.sh" "$(cat "$STUB_LOG")"
: >"$STUB_LOG"
rm -rf "$NVM"
(
	. "$HOME/stub.sh"
	NVM_DIR="$HOME/custom nvm" shell::dependency::nvm::install >/dev/null 2>&1
)
t_has "install: a custom NVM_DIR (with a space) is passed on" "NVM_DIR=$HOME/custom nvm" "$(cat "$STUB_LOG")"
rm -rf "$HOME/custom nvm"
fake_install "$NVM"
: >"$STUB_LOG"
out="$(
	. "$HOME/stub.sh"
	shell::dependency::nvm::install 2>&1
	echo "rc=$?"
)"
t_has "install: already installed is a warning, not an error" "already installed" "$out"
t_has "install: ...rc 0" "rc=0" "$out"
t_eq "install: ...and the installer is not run again" "" "$(cat "$STUB_LOG")"
rm -rf "$NVM"
t_eq "install: a failing installer is rc 1" "1" "$(
	. "$HOME/stub.sh"
	STUB_FAIL=yes shell::dependency::nvm::install >/dev/null 2>&1
	echo $?
)"
t_eq "install: an installer that leaves no nvm.sh is rc 1" "1" "$(
	. "$HOME/stub.sh"
	STUB_NOTHING=yes shell::dependency::nvm::install >/dev/null 2>&1
	echo $?
)"
: >"$STUB_LOG"
t_eq "install: without curl the installer is not even started" "1" "$(
	. "$HOME/stub.sh"
	STUB_NO_CURL=yes shell::dependency::nvm::install >/dev/null 2>&1
	echo $?
)"
t_eq "install: ...so nothing was run" "" "$(cat "$STUB_LOG")"
rm -rf "$NVM"

# --- uninstall: help, options, nothing to remove -------------------------------------------------------------------
t_has "uninstall -h: shows its usage" "USAGE: shell::dependency::nvm::uninstall" "$(say shell::dependency::nvm::uninstall -h)"
t_eq "uninstall: an unknown option" "2" "$(rc_of shell::dependency::nvm::uninstall --bogus)"
empty_home="$HOME/emptyhome"
no_xdg="$HOME/nowhere"
out="$(
	HOME="$empty_home" XDG_CONFIG_HOME="$no_xdg" shell::dependency::nvm::uninstall 2>&1
	echo "rc=$?"
)"
if [ ! -s /opt/homebrew/opt/nvm/nvm.sh ] && [ ! -s /usr/local/opt/nvm/nvm.sh ] && [ ! -s /home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh ]; then
	t_has "uninstall: nothing installed is a warning" "nvm is not installed" "$out"
	t_has "uninstall: ...rc 0" "rc=0" "$out"
fi

# --- uninstall: the safety rules ------------------------------------------------------------------------------------
fake_install "$NVM"
mkdir -p "$NVM/versions/node/v18.19.0" "$NVM/versions/node/v20.11.1"
t_has "uninstall: an nvm from Homebrew is left to brew" "brew uninstall nvm" "$(
	shell::dependency::nvm::path() { printf '%s\n' /opt/homebrew/opt/nvm/nvm.sh; }
	shell::dependency::nvm::uninstall -y 2>&1
)"
t_eq "uninstall: ...and nothing was deleted" "yes" "$([ -s "$NVM/nvm.sh" ] && echo yes || echo no)"
# NVM_DIR pointing at your home directory: nvm.sh is found in ~/.nvm, but NVM_DIR is not what may be deleted.
t_eq "uninstall: NVM_DIR=\$HOME is refused" "2" "$(NVM_DIR="$HOME" rc_of shell::dependency::nvm::uninstall -y)"
t_has "uninstall: ...with the reason" "Refusing to delete" "$(NVM_DIR="$HOME" say shell::dependency::nvm::uninstall -y)"
t_eq "uninstall: NVM_DIR=\$HOME/ is refused too" "2" "$(NVM_DIR="$HOME/" rc_of shell::dependency::nvm::uninstall -y)"
t_eq "uninstall: NVM_DIR=/ is refused" "2" "$(NVM_DIR=/ rc_of shell::dependency::nvm::uninstall -y)"
mkdir -p "$HOME/rel/nvm"
cp "$NVM/nvm.sh" "$HOME/rel/nvm/nvm.sh"
t_eq "uninstall: a relative NVM_DIR is refused" "2" "$(cd "$HOME/rel" && NVM_DIR="nvm" rc_of shell::dependency::nvm::uninstall -y)"
t_eq "uninstall: ...and left alone" "yes" "$([ -s "$HOME/rel/nvm/nvm.sh" ] && echo yes || echo no)"
mkdir -p "$HOME/not-nvm"
printf 'precious\n' >"$HOME/not-nvm/data"
t_eq "uninstall: a directory without nvm.sh is refused" "2" "$(NVM_DIR="$HOME/not-nvm" rc_of shell::dependency::nvm::uninstall -y)"
t_has "uninstall: ...with the reason" "does not contain nvm.sh" "$(NVM_DIR="$HOME/not-nvm" say shell::dependency::nvm::uninstall -y)"
t_eq "uninstall: ...and its contents are untouched" "precious" "$(cat "$HOME/not-nvm/data")"
t_eq "uninstall: after all the refusals the real one is intact" "yes" "$([ -s "$NVM/nvm.sh" ] && [ -d "$NVM/versions/node/v18.19.0" ] && echo yes || echo no)"

# --- uninstall: the profile files ----------------------------------------------------------------------------------
write_rc() {
	cat >"$1" <<'RC'
export PATH="$HOME/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
alias ll='ls -l'
RC
}
write_rc "$HOME/.bashrc"
write_rc "$HOME/.zshrc"
printf 'export EDITOR=vim\n' >"$HOME/.profile"
cp "$HOME/.bashrc" "$HOME/bashrc.orig"
cp "$HOME/.profile" "$HOME/profile.orig"

out="$(shell::dependency::nvm::uninstall -n 2>&1)"
t_has "uninstall -n: prints the removal" "rm -rf \"$NVM_DIR\"" "$out"
t_has "uninstall -n: names the profile files it would change" "$HOME/.bashrc" "$out"
t_has "uninstall -n: ...and the other one" "$HOME/.zshrc" "$out"
t_lacks "uninstall -n: ...but not one without nvm in it" "$HOME/.profile" "$out"
t_eq "uninstall -n: nothing was removed" "yes" "$([ -s "$NVM/nvm.sh" ] && echo yes || echo no)"
t_eq "uninstall -n: ...and the profile is unchanged" "" "$(diff "$HOME/.bashrc" "$HOME/bashrc.orig")"

t_has "uninstall: asks first, naming the directory and the versions" "Delete $NVM_DIR with 2 installed Node version(s)" "$(printf 'n\n' | shell::dependency::nvm::uninstall 2>&1)"
printf 'n\n' | shell::dependency::nvm::uninstall >/dev/null 2>&1
t_eq "uninstall: 'n' removes nothing" "yes" "$([ -s "$NVM/nvm.sh" ] && echo yes || echo no)"
t_has "uninstall: ...and says it aborted" "Aborted" "$(printf 'n\n' | shell::dependency::nvm::uninstall 2>&1)"
shell::dependency::nvm::uninstall </dev/null >/dev/null 2>&1
t_eq "uninstall: end of input removes nothing" "yes" "$([ -s "$NVM/nvm.sh" ] && echo yes || echo no)"

# nvm loaded in this shell: it is deactivated and unloaded before the files go.
export FAKE_NVM_LOG="$HOME/nvm.log"
: >"$FAKE_NVM_LOG"
printf 'y\n' | shell::dependency::nvm::uninstall >/dev/null 2>&1
export NVM_DIR="$NVM" # zsh runs the end of a pipeline in this shell, where the uninstaller unset it
t_eq "uninstall: 'y' with nvm not loaded here removes the directory" "no" "$([ -e "$NVM" ] && echo yes || echo no)"
t_eq "uninstall: ...and cleans the nvm lines" "export PATH=\"\$HOME/bin:\$PATH\"${nl}alias ll='ls -l'" "$(cat "$HOME/.bashrc")"
t_eq "uninstall: ...in every profile that had them" "export PATH=\"\$HOME/bin:\$PATH\"${nl}alias ll='ls -l'" "$(cat "$HOME/.zshrc")"
t_eq "uninstall: ...keeping a backup of the original" "" "$(diff "$HOME/.bashrc.nvm-backup" "$HOME/bashrc.orig")"
t_eq "uninstall: ...and one per file it changed" "yes" "$([ -f "$HOME/.zshrc.nvm-backup" ] && echo yes || echo no)"
t_eq "uninstall: a profile without nvm is not touched" "" "$(diff "$HOME/.profile" "$HOME/profile.orig")"
t_eq "uninstall: ...and gets no backup" "no" "$([ -e "$HOME/.profile.nvm-backup" ] && echo yes || echo no)"
t_eq "uninstall: running it again finds nothing to do" "0" "$(XDG_CONFIG_HOME="$no_xdg" rc_of shell::dependency::nvm::uninstall -y)"

# --yes, a directory with a space, and the loaded nvm.
fake_install "$NVM"
write_rc "$HOME/.bashrc"
: >"$FAKE_NVM_LOG"
(
	. "$NVM/nvm.sh"
	shell::dependency::nvm::uninstall -y >/dev/null 2>&1
)
t_eq "uninstall -y: no question, the directory is gone" "no" "$([ -e "$NVM" ] && echo yes || echo no)"
t_eq "uninstall: a loaded nvm is deactivated, then unloaded" "deactivate${nl}unload" "$(cat "$FAKE_NVM_LOG")"
spaced="$HOME/my nvm"
fake_install "$spaced"
t_eq "uninstall: a directory with a space is removed whole" "no" "$(NVM_DIR="$spaced" shell::dependency::nvm::uninstall -y >/dev/null 2>&1 && [ -e "$spaced" ] && echo yes || echo no)"
t_eq "uninstall: ...and nothing else was lost" "yes" "$([ -d "$HOME" ] && [ -f "$HOME/.profile" ] && echo yes || echo no)"

t_done
