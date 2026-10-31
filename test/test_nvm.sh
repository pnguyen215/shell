#!/usr/bin/env bash
# shell::nvm::* (src/lang/nvm.sh) and shell::dependency::nvm::path / ::load: argument validation, the
# exact argv that reaches nvm, dry-run, flags, .nvmrc, automatic switching, the check-up.
#
# nvm is faked: $NVM_DIR/nvm.sh defines an `nvm` function that logs every call to $FAKE_NVM_LOG (and the
# number of arguments to $FAKE_NVM_LOG.argc) and answers from files in $FAKE_NVM_DIR. A test can therefore
# assert what nvm received and, for the refusals, that it was never started. The real nvm is not used here;
# test_nvm_real.sh runs the same commands against a real nvm.sh when SHELL_TEST_NVM_SRC points at one.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

export NVM_DIR="$HOME/.nvm"
mkdir -p "$NVM_DIR" "$HOME/fake"
cat >"$NVM_DIR/nvm.sh" <<'FAKE'
# Fake nvm.sh: the nvm function logs the call and answers from $FAKE_NVM_DIR/<args, space / * as _>.
nvm() {
	printf '%s\n' "$*" >>"$FAKE_NVM_LOG"
	printf '%s\n' "$#" >>"$FAKE_NVM_LOG.argc"
	_k="$(printf '%s' "$*" | tr ' /*' '___')"
	[ -f "$FAKE_NVM_DIR/$_k" ] && cat "$FAKE_NVM_DIR/$_k"
	_rc=0
	[ -f "$FAKE_NVM_DIR/$_k.rc" ] && _rc="$(cat "$FAKE_NVM_DIR/$_k.rc")"
	return "$_rc"
}
FAKE
export FAKE_NVM_DIR="$HOME/fake" FAKE_NVM_LOG="$HOME/nvm.log"
: >"$FAKE_NVM_LOG"
: >"$FAKE_NVM_LOG.argc"

nl='
'
# fn "<nvm args>" "<what nvm prints>"
fn() { printf '%s\n' "$2" >"$FAKE_NVM_DIR/$(printf '%s' "$1" | tr ' /*' '___')"; }
# calls <command...>  -> what nvm was asked to do (one line per call); the command's own output is dropped
calls() {
	: >"$FAKE_NVM_LOG"
	"$@" >/dev/null 2>&1
	cat "$FAKE_NVM_LOG"
}
rc_of() {
	"$@" >/dev/null 2>&1
	echo "$?"
}
say() { "$@" 2>&1; }
# nvm_unavailable <command...>  -> the command with nvm neither loaded nor findable; prints output and rc=N
no_nvm() (
	unset -f nvm 2>/dev/null
	shell::dependency::nvm::path() { return 3; }
	"$@" 2>&1
	echo "rc=$?"
)

# --- validation ---------------------------------------------------------------------------------
for ok in 20 v20.11.1 node stable iojs system default 'lts/*' lts/iron my-alias work_1 20.11 a.b 'lts/hydrogen' 7zip; do
	shell::nvm::version::valid "$ok"
	t_eq "version: '$ok' is safe" "0" "$?"
done
for bad in '' -x --lts .hidden /abs 'a b' 'a;b' 'a|b' 'a&b' 'a$b' 'a`b`' 'a"b' "a'b" 'a(b)' 'a>b' '../x' 'a..b' 'a\b' '~x'; do
	shell::nvm::version::valid "$bad"
	t_eq "version: '$bad' is refused" "1" "$?"
done
t_eq "version: a newline is refused" "1" "$(shell::nvm::version::valid "a${nl}b" >/dev/null 2>&1 && echo 0 || echo 1)"
for ok in work default my-alias a.b lts/iron a_b 7z; do
	shell::nvm::alias::valid "$ok"
	t_eq "alias: '$ok' is valid" "0" "$?"
done
for bad in '' -x 'a b' 'a;b' 'a*' 'a+b' '../x' '.x' 'a$b'; do
	shell::nvm::alias::valid "$bad"
	t_eq "alias: '$bad' is refused" "1" "$?"
done

# --- finding and loading nvm -----------------------------------------------------------------------
t_eq "path: \$NVM_DIR/nvm.sh first" "$NVM_DIR/nvm.sh" "$(shell::dependency::nvm::path)"
t_eq "path: ~/.nvm when NVM_DIR is unset" "$HOME/.nvm/nvm.sh" "$(
	unset NVM_DIR
	shell::dependency::nvm::path
)"
t_eq "path: an NVM_DIR elsewhere wins over ~/.nvm" "$HOME/elsewhere/nvm.sh" "$(
	mkdir -p "$HOME/elsewhere" && cp "$NVM_DIR/nvm.sh" "$HOME/elsewhere/nvm.sh"
	NVM_DIR="$HOME/elsewhere" shell::dependency::nvm::path
)"
xdg_home="$HOME/xdg"
no_home="$HOME/emptyhome"
no_xdg="$HOME/nowhere"
t_eq "path: XDG_CONFIG_HOME/nvm" "$xdg_home/nvm/nvm.sh" "$(
	mkdir -p "$xdg_home/nvm" && cp "$NVM_DIR/nvm.sh" "$xdg_home/nvm/nvm.sh"
	unset NVM_DIR
	HOME="$no_home" XDG_CONFIG_HOME="$xdg_home" shell::dependency::nvm::path
)"
empty_dir="$HOME/emptynvm"
mkdir -p "$empty_dir" && : >"$empty_dir/nvm.sh"
t_eq "path: an empty nvm.sh does not count" "3" "$(
	HOME="$no_home" XDG_CONFIG_HOME="$no_xdg" NVM_DIR="$empty_dir" shell::dependency::nvm::path >/dev/null 2>&1
	echo $?
)"
if [ ! -s /opt/homebrew/opt/nvm/nvm.sh ] && [ ! -s /usr/local/opt/nvm/nvm.sh ] && [ ! -s /home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh ]; then
	t_eq "path: nothing installed is RETURN_NOT_FOUND" "3" "$(
		unset NVM_DIR
		HOME="$no_home" XDG_CONFIG_HOME="$no_xdg" shell::dependency::nvm::path >/dev/null 2>&1
		echo $?
	)"
fi

t_eq "load: not loaded yet" "not-loaded" "$(type nvm >/dev/null 2>&1 && echo loaded || echo not-loaded)"
shell::dependency::nvm::load
t_eq "load: succeeds" "0" "$?"
t_has "load: nvm is a function afterwards" "function" "$(type nvm 2>&1)"
t_eq "load: NVM_DIR is exported" "$NVM_DIR" "$(sh -c 'printf %s "$NVM_DIR"')"
: >"$FAKE_NVM_LOG"
shell::dependency::nvm::load
t_eq "load: loading twice is harmless and does not call nvm" "" "$(cat "$FAKE_NVM_LOG")"
t_has "load: without nvm, rc 3" "rc=3" "$(no_nvm shell::dependency::nvm::load)"
t_eq "load: it is passed --no-use (checked on a loader that reports its arguments)" "--no-use" "$(
	unset -f nvm 2>/dev/null
	mkdir -p "$HOME/argdir"
	printf 'nvm() { :; }\nprintf "%%s" "$*" >"%s/args"\n' "$HOME/argdir" >"$HOME/argdir/nvm.sh"
	NVM_DIR="$HOME/argdir" shell::dependency::nvm::load
	cat "$HOME/argdir/args"
)"

# --- shell::nvm::invoke --------------------------------------------------------------------------------
t_eq "invoke: passes the arguments through" "use 20" "$(calls shell::nvm::invoke use 20)"
t_eq "invoke: an argument with spaces stays one argument" "2" "$(
	: >"$FAKE_NVM_LOG.argc"
	shell::nvm::invoke alias 'two words' >/dev/null 2>&1
	cat "$FAKE_NVM_LOG.argc"
)"
t_eq "invoke: -n does not start nvm" "" "$(calls shell::nvm::invoke -n use 20)"
t_has "invoke: -n prints the command" "nvm use 20" "$(say shell::nvm::invoke -n use 20)"
t_has "invoke: echoes the command it runs" "nvm use 20" "$(say shell::nvm::invoke use 20)"
t_eq "invoke: no sub-command is invalid" "2" "$(rc_of shell::nvm::invoke)"
t_has "invoke: without nvm, says how to install it" "shell::dependency::nvm::install" "$(no_nvm shell::nvm::invoke use 20)"
t_has "invoke: without nvm, rc 3" "rc=3" "$(no_nvm shell::nvm::invoke use 20)"
t_has "invoke: -n needs no nvm" "nvm use 20" "$(no_nvm shell::nvm::invoke -n use 20)"
printf '3\n' >"$FAKE_NVM_DIR/use_99.rc"
t_eq "invoke: nvm's exit status is returned" "3" "$(rc_of shell::nvm::invoke use 99)"
rm -f "$FAKE_NVM_DIR/use_99.rc"
t_eq "query: prints what nvm printed, quietly" "v20.11.1" "$(fn current v20.11.1 && shell::nvm::query current)"
t_eq "query: and echoes nothing" "current" "$(calls shell::nvm::query current)"
t_eq "query: without nvm, rc 3" "3" "$(
	unset -f nvm 2>/dev/null
	shell::dependency::nvm::path() { return 3; }
	shell::nvm::query current >/dev/null 2>&1
	echo $?
)"

# --- every function has a help, and --help never calls nvm ------------------------------------------------
for fn in version help current which ls ls::remote version::local version::remote install uninstall use run exec deactivate unload \
	alias default unalias install::latest_npm reinstall_packages cache set_colors nvmrc::find nvmrc::read nvmrc::write \
	autouse::on autouse::off autouse::status doctor; do
	t_eq "$fn -h: nvm is not started" "" "$(calls "shell::nvm::$fn" -h)"
	out="$(say "shell::nvm::$fn" --help)"
	t_has "$fn --help: shows its usage" "USAGE: shell::nvm::$fn" "$out"
	t_eq "$fn --help: returns 0" "0" "$(rc_of "shell::nvm::$fn" -h)"
done
for fn in version help current which ls ls::remote version::local version::version install uninstall use run exec deactivate unload \
	alias default unalias install::latest_npm reinstall_packages cache set_colors; do
	case "$fn" in version::version) continue ;; esac
	t_has "$fn --help: documents --dry-run" "--dry-run" "$(say "shell::nvm::$fn" --help)"
done

# --- version, help, current, which --------------------------------------------------------------------------
t_eq "version" "--version" "$(calls shell::nvm::version)"
t_eq "version: takes no argument" "2" "$(rc_of shell::nvm::version x)"
t_eq "help" "--help" "$(calls shell::nvm::help)"
t_eq "current" "current" "$(calls shell::nvm::current)"
t_eq "current: takes no argument" "2" "$(rc_of shell::nvm::current 20)"
t_eq "which: a version" "which 22" "$(calls shell::nvm::which 22)"
t_eq "which: current" "which current" "$(calls shell::nvm::which current)"
t_eq "which: from .nvmrc" "which" "$(calls shell::nvm::which)"
t_eq "which: --silent" "which --silent" "$(calls shell::nvm::which --silent)"
t_eq "which: an unsafe version" "2" "$(rc_of shell::nvm::which 'a;b')"

# --- ls, ls-remote, version -------------------------------------------------------------------------------------
t_eq "ls" "ls" "$(calls shell::nvm::ls)"
t_eq "ls: flags and a filter" "ls --no-colors --no-alias 20" "$(calls shell::nvm::ls --no-colors --no-alias 20)"
t_eq "ls: unknown option" "2" "$(rc_of shell::nvm::ls --bogus)"
t_eq "ls: two filters" "2" "$(rc_of shell::nvm::ls 18 20)"
t_eq "ls::remote" "ls-remote" "$(calls shell::nvm::ls::remote)"
t_eq "ls::remote: --lts" "ls-remote --lts" "$(calls shell::nvm::ls::remote --lts)"
t_eq "ls::remote: --lts=<name>" "ls-remote --lts=iron --no-colors" "$(calls shell::nvm::ls::remote --lts=iron --no-colors)"
t_eq "ls::remote: a filter" "ls-remote 22" "$(calls shell::nvm::ls::remote 22)"
t_eq "ls::remote: a bad LTS name" "2" "$(rc_of shell::nvm::ls::remote '--lts=a;b')"
t_eq "ls::remote: an empty LTS name" "2" "$(rc_of shell::nvm::ls::remote '--lts=')"
t_eq "version::local" "version 20" "$(calls shell::nvm::version::local 20)"
t_eq "version::local: needs a version" "2" "$(rc_of shell::nvm::version::local)"
t_eq "version::remote" "version-remote 22" "$(calls shell::nvm::version::remote 22)"
t_eq "version::remote: --lts alone is enough" "version-remote --lts=iron" "$(calls shell::nvm::version::remote --lts=iron)"
t_eq "version::remote: needs a version or --lts" "2" "$(rc_of shell::nvm::version::remote)"
t_eq "version::remote: -n alone is not enough" "2" "$(rc_of shell::nvm::version::remote -n)"

# --- install ------------------------------------------------------------------------------------------------------
t_eq "install: a version" "install 22" "$(calls shell::nvm::install 22)"
t_eq "install: from .nvmrc" "install" "$(calls shell::nvm::install)"
t_eq "install: --lts" "install --lts" "$(calls shell::nvm::install --lts)"
t_eq "install: --lts=<name>" "install --lts=iron" "$(calls shell::nvm::install --lts=iron)"
t_eq "install: -s -b" "install -s -b 20.11.1" "$(calls shell::nvm::install -s -b 20.11.1)"
t_eq "install: --reinstall-packages-from <v> becomes =<v>" "install --reinstall-packages-from=20 22" "$(calls shell::nvm::install --reinstall-packages-from 20 22)"
t_eq "install: --reinstall-packages-from=<v>" "install --reinstall-packages-from=v20.11.1 22" "$(calls shell::nvm::install --reinstall-packages-from=v20.11.1 22)"
t_eq "install: --alias <name>" "install --alias=work 20" "$(calls shell::nvm::install --alias work 20)"
t_eq "install: --default --latest-npm --no-progress --skip-default-packages" "install --default --latest-npm --no-progress --skip-default-packages node" "$(calls shell::nvm::install --default --latest-npm --no-progress --skip-default-packages node)"
t_eq "install: flags may follow the version, nvm still gets them first" "install --lts --default 22" "$(calls shell::nvm::install 22 --lts --default)"
t_eq "install: lts/* as a version" "install lts/*" "$(calls shell::nvm::install 'lts/*')"
t_eq "install: -n runs nothing" "" "$(calls shell::nvm::install -n 22)"
t_has "install: -n prints nvm install" "nvm install --lts" "$(say shell::nvm::install -n --lts)"
t_eq "install: two versions" "2" "$(rc_of shell::nvm::install 18 20)"
t_eq "install: unknown option" "2" "$(rc_of shell::nvm::install --bogus 22)"
t_has "install: ...is named" "Unknown option: --bogus" "$(say shell::nvm::install --bogus 22)"
t_eq "install: --alias needs a value" "2" "$(rc_of shell::nvm::install --alias)"
for bad in -rf 'a b' 'a;b' '$(x)' '`x`' '../x' 'a|b' 'a"b'; do
	t_eq "install '$bad': refused, nvm never started" "" "$(calls shell::nvm::install "$bad")"
	t_eq "install '$bad': rc 2" "2" "$(rc_of shell::nvm::install "$bad")"
done
for bad in 'a b' 'a;b' -x '$(x)' '../x' ''; do
	t_eq "install --alias '$bad': refused" "2" "$(rc_of shell::nvm::install --alias "$bad" 20)"
	t_eq "install --reinstall-packages-from '$bad': refused" "2" "$(rc_of shell::nvm::install --reinstall-packages-from "$bad" 20)"
done
t_eq "install: nothing ran for any refusal" "" "$(calls shell::nvm::install --alias 'a;b' 20)"
t_has "install: an unsafe version is quoted in the message" "Invalid version: 'a;b'" "$(say shell::nvm::install 'a;b')"

# --- uninstall ----------------------------------------------------------------------------------------------------
t_eq "uninstall" "uninstall 18.19.0" "$(calls shell::nvm::uninstall 18.19.0)"
t_eq "uninstall: --lts" "uninstall --lts" "$(calls shell::nvm::uninstall --lts)"
t_eq "uninstall: --lts=<name>" "uninstall --lts=hydrogen" "$(calls shell::nvm::uninstall --lts=hydrogen)"
t_eq "uninstall: needs a version or --lts" "2" "$(rc_of shell::nvm::uninstall)"
t_eq "uninstall: -n alone is not enough" "2" "$(rc_of shell::nvm::uninstall -n)"
t_eq "uninstall: -n runs nothing" "" "$(calls shell::nvm::uninstall -n 18)"
t_eq "uninstall: an unsafe version" "2" "$(rc_of shell::nvm::uninstall 'a;b')"
printf '1\n' >"$FAKE_NVM_DIR/uninstall_20.rc"
t_eq "uninstall: nvm's refusal (the version in use) is returned" "1" "$(rc_of shell::nvm::uninstall 20)"
rm -f "$FAKE_NVM_DIR/uninstall_20.rc"

# --- use, run, exec ------------------------------------------------------------------------------------------------
t_eq "use: a version" "use 20" "$(calls shell::nvm::use 20)"
t_eq "use: from .nvmrc" "use" "$(calls shell::nvm::use)"
t_eq "use: --silent" "use --silent 20" "$(calls shell::nvm::use --silent 20)"
t_eq "use: --lts" "use --lts" "$(calls shell::nvm::use --lts)"
t_eq "use: --lts=<name>" "use --lts=iron" "$(calls shell::nvm::use --lts=iron)"
t_eq "use: an alias" "use work" "$(calls shell::nvm::use work)"
t_eq "use: lts/iron" "use lts/iron" "$(calls shell::nvm::use lts/iron)"
t_eq "use: -n runs nothing" "" "$(calls shell::nvm::use -n 20)"
t_has "use: -n prints it" "nvm use 20" "$(say shell::nvm::use -n 20)"
t_eq "use: two versions" "2" "$(rc_of shell::nvm::use 18 20)"
t_eq "use: --all is not an nvm flag" "2" "$(rc_of shell::nvm::use --all)"
for bad in -x --bogus 'a b' 'a;b' '$(x)' '../x'; do
	t_eq "use '$bad': refused" "2" "$(rc_of shell::nvm::use "$bad")"
	t_eq "use '$bad': nvm never started" "" "$(calls shell::nvm::use "$bad")"
done
printf '3\n' >"$FAKE_NVM_DIR/use_99.rc"
t_eq "use: a version nvm does not know returns nvm's status" "3" "$(rc_of shell::nvm::use 99)"
rm -f "$FAKE_NVM_DIR/use_99.rc"

t_eq "exec: a command" "exec 20 npm test" "$(calls shell::nvm::exec 20 npm test)"
t_eq "exec: --silent goes before the version" "exec --silent 20 npm test" "$(calls shell::nvm::exec --silent 20 npm test)"
t_eq "exec: current" "exec current node -p process.version" "$(calls shell::nvm::exec current node -p process.version)"
t_eq "exec: what follows the version is the command, flags included" "exec 20 npm --version --silent -n" "$(calls shell::nvm::exec 20 npm --version --silent -n)"
t_eq "exec: ...and an unknown flag after the version is the command's" "exec 20 ls --bogus" "$(calls shell::nvm::exec 20 ls --bogus)"
t_eq "exec: --lts needs no version" "exec --lts npm ci" "$(calls shell::nvm::exec --lts npm ci)"
t_eq "exec: --lts=<name>" "exec --lts=iron npm ci" "$(calls shell::nvm::exec --lts=iron npm ci)"
t_eq "exec: an argument with spaces stays one argument" "5" "$(
	: >"$FAKE_NVM_LOG.argc"
	shell::nvm::exec 20 sh -c 'echo a b' >/dev/null 2>&1
	cat "$FAKE_NVM_LOG.argc"
)"
t_eq "exec: -n before the version runs nothing" "" "$(calls shell::nvm::exec -n 20 npm test)"
t_has "exec: -n prints it" "nvm exec 20 npm test" "$(say shell::nvm::exec -n 20 npm test)"
t_eq "exec: a version without a command" "2" "$(rc_of shell::nvm::exec 20)"
t_has "exec: ...says what is missing" "A version and a command is required" "$(say shell::nvm::exec 20)"
t_eq "exec: nothing at all" "2" "$(rc_of shell::nvm::exec)"
t_eq "exec: --lts without a command" "2" "$(rc_of shell::nvm::exec --lts)"
t_eq "exec: an unsafe version" "2" "$(rc_of shell::nvm::exec 'a;b' ls)"
t_eq "exec: ...and nvm never started" "" "$(calls shell::nvm::exec 'a;b' ls)"
t_eq "exec: an unknown flag before the version" "2" "$(rc_of shell::nvm::exec --bogus 20 ls)"
t_eq "run: node arguments" "run 20 app.js" "$(calls shell::nvm::run 20 app.js)"
t_eq "run: node's --version stays node's" "run 18 --version" "$(calls shell::nvm::run 18 --version)"
t_eq "run: only a version" "run 20" "$(calls shell::nvm::run 20)"
t_eq "run: --lts needs no version" "run --lts app.js" "$(calls shell::nvm::run --lts app.js)"
t_eq "run: --lts alone" "run --lts" "$(calls shell::nvm::run --lts)"
t_eq "run: --silent" "run --silent 20 app.js" "$(calls shell::nvm::run --silent 20 app.js)"
t_eq "run: needs a version" "2" "$(rc_of shell::nvm::run)"
t_eq "run: an unsafe version" "2" "$(rc_of shell::nvm::run 'a;b' app.js)"
t_eq "run: -n runs nothing" "" "$(calls shell::nvm::run -n 20 app.js)"
t_eq "deactivate" "deactivate" "$(calls shell::nvm::deactivate)"
t_eq "deactivate: --silent" "deactivate --silent" "$(calls shell::nvm::deactivate --silent)"
t_eq "deactivate: takes no argument" "2" "$(rc_of shell::nvm::deactivate 20)"
t_eq "unload" "unload" "$(calls shell::nvm::unload)"

# --- aliases ----------------------------------------------------------------------------------------------------------
t_eq "alias: list" "alias" "$(calls shell::nvm::alias)"
t_eq "alias: a prefix" "alias lts" "$(calls shell::nvm::alias lts)"
t_eq "alias: --no-colors" "alias --no-colors" "$(calls shell::nvm::alias --no-colors)"
t_eq "alias: set" "alias work 20.11.1" "$(calls shell::nvm::alias work 20.11.1)"
t_eq "alias: set to lts/*" "alias work lts/*" "$(calls shell::nvm::alias work 'lts/*')"
t_eq "alias: three arguments" "2" "$(rc_of shell::nvm::alias a b c)"
t_eq "alias: an unsafe name" "2" "$(rc_of shell::nvm::alias 'a;b' 20)"
t_eq "alias: a name that is a flag" "2" "$(rc_of shell::nvm::alias -x 20)"
t_eq "alias: an unsafe version" "2" "$(rc_of shell::nvm::alias work 'a;b')"
t_eq "alias: -n runs nothing" "" "$(calls shell::nvm::alias -n work 20)"
t_eq "default: show" "alias default" "$(calls shell::nvm::default)"
t_eq "default: set" "alias default 22" "$(calls shell::nvm::default 22)"
t_eq "default: lts/*" "alias default lts/*" "$(calls shell::nvm::default 'lts/*')"
t_eq "default: node" "alias default node" "$(calls shell::nvm::default node)"
t_eq "default: -n runs nothing" "" "$(calls shell::nvm::default -n 22)"
t_has "default: -n prints it" "nvm alias default 22" "$(say shell::nvm::default -n 22)"
t_eq "default: an unsafe version" "2" "$(rc_of shell::nvm::default 'a;b')"
t_has "default: ...is named a version" "Invalid version: 'a;b'" "$(say shell::nvm::default 'a;b')"
t_eq "default: a flag is refused" "2" "$(rc_of shell::nvm::default --bogus)"
t_eq "default: two versions" "2" "$(rc_of shell::nvm::default 18 20)"
printf '3\n' >"$FAKE_NVM_DIR/alias_default_99.rc"
t_eq "default: nvm's status is returned, not mistaken for a usage error" "3" "$(rc_of shell::nvm::default 99)"
rm -f "$FAKE_NVM_DIR/alias_default_99.rc"
t_eq "unalias" "unalias work" "$(calls shell::nvm::unalias work)"
t_eq "unalias: needs a name" "2" "$(rc_of shell::nvm::unalias)"
t_eq "unalias: an unsafe name" "2" "$(rc_of shell::nvm::unalias 'a;b')"
t_eq "unalias: one name only" "2" "$(rc_of shell::nvm::unalias a b)"

# --- npm, colours, cache ------------------------------------------------------------------------------------------------
t_eq "install::latest_npm" "install-latest-npm" "$(calls shell::nvm::install::latest_npm)"
t_eq "reinstall_packages" "reinstall-packages 20" "$(calls shell::nvm::reinstall_packages 20)"
t_eq "reinstall_packages: needs a version" "2" "$(rc_of shell::nvm::reinstall_packages)"
t_eq "reinstall_packages: an unsafe version" "2" "$(rc_of shell::nvm::reinstall_packages 'a;b')"
t_eq "cache: dir is the default" "cache dir" "$(calls shell::nvm::cache)"
t_eq "cache dir" "cache dir" "$(calls shell::nvm::cache dir)"
t_eq "cache clear" "cache clear" "$(calls shell::nvm::cache clear)"
t_eq "cache: -n runs nothing" "" "$(calls shell::nvm::cache -n clear)"
t_has "cache: -n prints it" "nvm cache clear" "$(say shell::nvm::cache -n clear)"
t_eq "cache: an unknown action" "2" "$(rc_of shell::nvm::cache purge)"
t_eq "cache: two actions" "2" "$(rc_of shell::nvm::cache dir clear)"
t_eq "cache: an unknown option" "2" "$(rc_of shell::nvm::cache --bogus)"
t_eq "set_colors" "set-colors cgYmW" "$(calls shell::nvm::set_colors cgYmW)"
t_eq "set_colors: none shows the current ones" "set-colors" "$(calls shell::nvm::set_colors)"
for bad in cgYm cgYmWr cgYmZ 'cgY m' 'cgYm;' 12345; do
	t_eq "set_colors '$bad': refused" "2" "$(rc_of shell::nvm::set_colors "$bad")"
done

# --- .nvmrc -------------------------------------------------------------------------------------------------------------
proj="$HOME/proj"
mkdir -p "$proj/a/b/c" "$HOME/other"
printf '20.11.1\n' >"$proj/.nvmrc"
t_eq "nvmrc::find: in the directory" "$proj/.nvmrc" "$(shell::nvm::nvmrc::find "$proj")"
t_eq "nvmrc::find: in a parent" "$proj/.nvmrc" "$(shell::nvm::nvmrc::find "$proj/a/b/c")"
t_eq "nvmrc::find: the current directory by default" "$proj/.nvmrc" "$(cd "$proj/a" && shell::nvm::nvmrc::find)"
t_eq "nvmrc::find: the nearest wins" "$proj/a/.nvmrc" "$(printf '18\n' >"$proj/a/.nvmrc" && shell::nvm::nvmrc::find "$proj/a/b")"
rm -f "$proj/a/.nvmrc"
t_eq "nvmrc::find: none is RETURN_NOT_FOUND" "3" "$(shell::nvm::nvmrc::find "$HOME/other" >/dev/null 2>&1 && echo 0 || echo $?)"
t_eq "nvmrc::read" "20.11.1" "$(shell::nvm::nvmrc::read "$proj/a")"
t_eq "nvmrc::read: trims blanks" "lts/iron" "$(printf '  lts/iron  \n' >"$proj/.nvmrc" && shell::nvm::nvmrc::read "$proj")"
t_eq "nvmrc::read: Windows line ends" "20" "$(printf '20\r\n' >"$proj/.nvmrc" && shell::nvm::nvmrc::read "$proj")"
t_eq "nvmrc::read: only the first line" "20" "$(printf '20\n# comment\n' >"$proj/.nvmrc" && shell::nvm::nvmrc::read "$proj")"
t_eq "nvmrc::read: an empty file is RETURN_EMPTY" "8" "$(: >"$proj/.nvmrc" && shell::nvm::nvmrc::read "$proj" >/dev/null 2>&1 && echo 0 || echo $?)"
t_eq "nvmrc::read: no file is RETURN_NOT_FOUND" "3" "$(shell::nvm::nvmrc::read "$HOME/other" >/dev/null 2>&1 && echo 0 || echo $?)"
rm -f "$proj/.nvmrc"
w="$HOME/w"
mkdir -p "$w"
t_eq "nvmrc::write: a version" "22" "$(cd "$w" && shell::nvm::nvmrc::write 22 >/dev/null 2>&1 && cat .nvmrc)"
t_has "nvmrc::write: says where" "$w/.nvmrc" "$(cd "$w" && shell::nvm::nvmrc::write --force 22 2>&1)"
t_eq "nvmrc::write: an existing file is kept" "7" "$(cd "$w" && shell::nvm::nvmrc::write 18 >/dev/null 2>&1 && echo 0 || echo $?)"
t_eq "nvmrc::write: ...and unchanged" "22" "$(cat "$w/.nvmrc")"
t_has "nvmrc::write: ...with a hint" "--force" "$(cd "$w" && shell::nvm::nvmrc::write 18 2>&1)"
t_eq "nvmrc::write --force replaces it" "lts/iron" "$(cd "$w" && shell::nvm::nvmrc::write -f lts/iron >/dev/null 2>&1 && cat .nvmrc)"
t_eq "nvmrc::write --dir" "node" "$(shell::nvm::nvmrc::write --dir "$HOME/other" node >/dev/null 2>&1 && cat "$HOME/other/.nvmrc")"
rm -f "$HOME/other/.nvmrc"
t_eq "nvmrc::write -n writes nothing" "no" "$(shell::nvm::nvmrc::write -n -d "$HOME/other" 20 >/dev/null 2>&1 && [ -e "$HOME/other/.nvmrc" ] && echo yes || echo no)"
t_has "nvmrc::write -n prints what it would write" '20' "$(shell::nvm::nvmrc::write -n -d "$HOME/other" 20 2>&1)"
t_eq "nvmrc::write: an unsafe version" "2" "$(rc_of shell::nvm::nvmrc::write -d "$HOME/other" 'a;b')"
t_eq "nvmrc::write: a missing directory" "2" "$(rc_of shell::nvm::nvmrc::write -d "$HOME/nowhere" 20)"
t_eq "nvmrc::write: two versions" "2" "$(rc_of shell::nvm::nvmrc::write -d "$HOME/other" 18 20)"
t_eq "nvmrc::write: an unknown option" "2" "$(rc_of shell::nvm::nvmrc::write --bogus 20)"
t_eq "nvmrc::write: --dir needs a value" "2" "$(rc_of shell::nvm::nvmrc::write --dir)"
fn current v20.11.1
t_eq "nvmrc::write: without a version, pins the active one" "v20.11.1" "$(shell::nvm::nvmrc::write -d "$HOME/other" >/dev/null 2>&1 && cat "$HOME/other/.nvmrc")"
rm -f "$HOME/other/.nvmrc"
fn current system
t_eq "nvmrc::write: with only the system Node active, nothing to pin" "2" "$(rc_of shell::nvm::nvmrc::write -d "$HOME/other")"
t_has "nvmrc::write: ...and it says how to give one" "shell::nvm::nvmrc::write 22" "$(say shell::nvm::nvmrc::write -d "$HOME/other")"
fn current v20.11.1

# --- automatic switching --------------------------------------------------------------------------------------------------
auto="$HOME/auto"
mkdir -p "$auto/with" "$auto/without"
printf '20\n' >"$auto/with/.nvmrc"
t_eq "autouse: off to begin with" "off" "$(shell::nvm::autouse::status)"
t_eq "autouse::status: off is rc 1" "1" "$(rc_of shell::nvm::autouse::status)"
cd "$auto/with" || exit 1
: >"$FAKE_NVM_LOG"
shell::nvm::autouse::on >/dev/null 2>&1
t_eq "autouse::on: succeeds and switches once for the current directory" "use --silent" "$(cat "$FAKE_NVM_LOG")"
t_eq "autouse::status: on" "on" "$(shell::nvm::autouse::status)"
t_eq "autouse::status: on is rc 0" "0" "$(rc_of shell::nvm::autouse::status)"
if [ -n "${ZSH_VERSION-}" ]; then
	t_has "autouse::on: zsh gets a chpwd hook" "shell::nvm::autouse::hook" "${chpwd_functions[*]-}"
else
	t_has "autouse::on: bash gets a PROMPT_COMMAND hook" "shell::nvm::autouse::hook" "${PROMPT_COMMAND-}"
fi
# hook_in <dir>: enter <dir> (zsh runs the hook by itself on cd; bash does not) and run it from a clean state
hook_in() {
	cd "$1" || exit 1
	SHELL_NVM_AUTOUSE_PWD=""
	: >"$FAKE_NVM_LOG"
	shell::nvm::autouse::hook 2>&1
}
hook_in "$auto/with" >/dev/null
: >"$FAKE_NVM_LOG"
shell::nvm::autouse::hook
t_eq "hook: the same directory again does nothing" "" "$(cat "$FAKE_NVM_LOG")"
hook_in "$auto/without" >/dev/null
t_eq "hook: a directory without .nvmrc leaves the version alone" "" "$(cat "$FAKE_NVM_LOG")"
hook_in "$auto/with" >/dev/null
t_eq "hook: a directory with .nvmrc switches" "use --silent" "$(cat "$FAKE_NVM_LOG")"
printf '3\n' >"$FAKE_NVM_DIR/use_--silent.rc"
t_has "hook: a version that is not installed is reported" "not installed" "$(hook_in "$auto/with")"
rm -f "$FAKE_NVM_DIR/use_--silent.rc"
t_has "autouse::on: twice says it is on already" "already on" "$(shell::nvm::autouse::on 2>&1)"
shell::nvm::autouse::off >/dev/null 2>&1
t_eq "autouse::off: status is off" "off" "$(shell::nvm::autouse::status)"
if [ -n "${ZSH_VERSION-}" ]; then
	t_lacks "autouse::off: the zsh hook is gone" "shell::nvm::autouse::hook" "${chpwd_functions[*]-}"
else
	t_lacks "autouse::off: the PROMPT_COMMAND hook is gone" "shell::nvm::autouse::hook" "${PROMPT_COMMAND-}"
fi
t_eq "autouse::on: without nvm, rc 3" "3" "$(
	unset -f nvm 2>/dev/null
	shell::dependency::nvm::path() { return 3; }
	shell::nvm::autouse::on >/dev/null 2>&1
	echo $?
)"
cd "$HOME" || exit 1

# --- doctor ---------------------------------------------------------------------------------------------------------------
fn --version 0.40.8
fn current v20.11.1
fn alias_default "default -> 20 (-> v20.11.1 *)"
d="$HOME/doc"
mkdir -p "$d/none" "$d/same" "$d/other" "$d/missing"
printf '20\n' >"$d/same/.nvmrc"
printf '18\n' >"$d/other/.nvmrc"
printf '99\n' >"$d/missing/.nvmrc"
fn "version 20" v20.11.1
fn "version 18" v18.19.0
fn "version 99" N/A
out="$(cd "$d/none" && shell::nvm::doctor 2>&1)"
t_has "doctor: reports nvm and where" "ok    nvm 0.40.8 ($NVM_DIR/nvm.sh)" "$out"
t_has "doctor: NVM_DIR" "NVM_DIR=$NVM_DIR" "$out"
t_has "doctor: the version in use" "ok    in use: v20.11.1" "$out"
t_has "doctor: the default" "default: default -> 20" "$out"
t_has "doctor: no .nvmrc" "no .nvmrc here or above" "$out"
t_eq "doctor: nothing wrong is rc 0" "0" "$(cd "$d/none" && rc_of shell::nvm::doctor)"
out="$(cd "$d/same" && shell::nvm::doctor 2>&1)"
t_has "doctor: .nvmrc that matches the version in use" "asks for 20, which is the one in use" "$out"
out="$(cd "$d/other" && shell::nvm::doctor 2>&1)"
t_has "doctor: .nvmrc that differs is a warning" "warn  $d/other/.nvmrc asks for 18 (v18.19.0) but v20.11.1 is in use" "$out"
t_eq "doctor: ...which is still rc 0" "0" "$(cd "$d/other" && rc_of shell::nvm::doctor)"
out="$(cd "$d/missing" && shell::nvm::doctor 2>&1)"
t_has "doctor: .nvmrc for a version that is not installed is a failure" "fail  $d/missing/.nvmrc asks for 99, which is not installed" "$out"
t_eq "doctor: ...and rc 1" "1" "$(cd "$d/missing" && rc_of shell::nvm::doctor)"
fn current system
t_has "doctor: only the system Node active" "warn  no nvm-managed Node is active" "$(cd "$d/none" && shell::nvm::doctor 2>&1)"
fn current v20.11.1
rm -f "$FAKE_NVM_DIR/alias_default"
t_has "doctor: no default" "warn  no default version" "$(cd "$d/none" && shell::nvm::doctor 2>&1)"
t_has "doctor: without nvm" "fail  nvm is not installed" "$(no_nvm shell::nvm::doctor)"
t_has "doctor: ...rc 3" "rc=3" "$(no_nvm shell::nvm::doctor)"
t_has "doctor: a node outside nvm is noticed" "is not the one nvm manages" "$(
	mkdir -p "$HOME/sysbin" && printf '#!/bin/sh\n' >"$HOME/sysbin/node" && chmod +x "$HOME/sysbin/node"
	PATH="$HOME/sysbin:$PATH" shell::nvm::doctor 2>&1
)"
t_has "doctor: a node managed by nvm is recognised" "is managed by nvm" "$(
	mkdir -p "$NVM_DIR/versions/node/v20.11.1/bin" && printf '#!/bin/sh\n' >"$NVM_DIR/versions/node/v20.11.1/bin/node" && chmod +x "$NVM_DIR/versions/node/v20.11.1/bin/node"
	PATH="$NVM_DIR/versions/node/v20.11.1/bin:$PATH" shell::nvm::doctor 2>&1
)"

# --- the aliases of the library ---------------------------------------------------------------------------------------------
for pair in snm:shell::nvm::manage snmu:shell::nvm::use::fzf snmi:shell::nvm::install::fzf snmrm:shell::nvm::uninstall::fzf \
	snmun:shell::nvm::unused snmunf:shell::nvm::unused::fzf snmls:shell::nvm::ls snmc:shell::nvm::current; do
	t_has "alias ${pair%%:*} -> ${pair#*:}" "${pair#*:}" "$(alias "${pair%%:*}" 2>&1)"
done
t_has "alias with a dry-run twin" "shell::nvm::manage -n" "$(alias snm-n 2>&1)"
missing=""
for fn in $(alias | sed -n "s/.*'\(shell::nvm::[A-Za-z0-9:_]*\).*/\1/p" | sort -u); do
	command -v "$fn" >/dev/null 2>&1 || missing="$missing $fn"
done
t_eq "every nvm alias points at a real function" "" "$missing"

t_done
