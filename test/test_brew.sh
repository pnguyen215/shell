#!/usr/bin/env bash
# shell::brew::* (src/lib/brew.sh) — the plain Homebrew commands: argument validation, the exact
# argv that reaches brew, dry-run, flags, error codes, and the shell-safety of package names.
#
# brew is faked: every call is appended to $FAKE_BREW_LOG, so a test can assert what brew received
# (and, for the refusals, that it was never started). The real brew is never run: the one test of
# "Homebrew is not installed" overrides shell::homebrew::path.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

mkdir "$HOME/bin" "$HOME/fake"
cat >"$HOME/bin/brew" <<'FAKE'
#!/bin/sh
# Fake brew: log the call; answer from $FAKE_BREW_DIR/<args with spaces and slashes as _>; exit with <that>.rc
printf '%s\n' "$*" >>"$FAKE_BREW_LOG"
key="$(printf '%s' "$*" | tr ' /' '__')"
[ -f "$FAKE_BREW_DIR/$key" ] && cat "$FAKE_BREW_DIR/$key"
rc=0
[ -f "$FAKE_BREW_DIR/$key.rc" ] && rc="$(cat "$FAKE_BREW_DIR/$key.rc")"
exit "$rc"
FAKE
chmod +x "$HOME/bin/brew"
export PATH="$HOME/bin:$PATH" FAKE_BREW_DIR="$HOME/fake" FAKE_BREW_LOG="$HOME/brew.log"
: >"$FAKE_BREW_LOG"

nl='
'
# calls <command...>  -> what brew was asked to do (one line per call); the command's own output is dropped
calls() {
	: >"$FAKE_BREW_LOG"
	"$@" >/dev/null 2>&1
	cat "$FAKE_BREW_LOG"
}
# rc_of <command...>  -> the exit status
rc_of() {
	"$@" >/dev/null 2>&1
	echo "$?"
}
# stdout+stderr of a command
say() { "$@" 2>&1; }

# --- name validation ---------------------------------------------------------------------------
for ok in git node@20 python@3.12 'c++' openssl@3 user/repo/name gcc@13 a_b a-b a.b 7zip; do
	shell::brew::name::valid "$ok"
	t_eq "name: '$ok' is safe" "0" "$?"
done
for bad in '' -rf --force -x .hidden '/abs' 'a b' 'a;b' 'a|b' 'a&b' 'a$b' 'a`b`' 'a"b' "a'b" 'a(b)' 'a*b' 'a>b' '../x' 'a..b' 'a\b' '~x'; do
	shell::brew::name::valid "$bad"
	t_eq "name: '$bad' is refused" "1" "$?"
done
t_eq "name: a newline is refused" "1" "$(shell::brew::name::valid "a${nl}b" >/dev/null 2>&1 && echo 0 || echo 1)"
for ok in homebrew/cask-versions acme/tools a.b/c_d x/y; do
	shell::brew::tap::valid "$ok"
	t_eq "tap: '$ok' is valid" "0" "$?"
done
for bad in '' git acme/ /tools a/b/c ../x acme/..x 'a b/c' 'a;b/c' -x/y .x/y; do
	shell::brew::tap::valid "$bad"
	t_eq "tap: '$bad' is refused" "1" "$?"
done

# --- brew is not installed ---------------------------------------------------------------------
out="$(
	shell::homebrew::path() { return 3; }
	shell::brew::run list 2>&1
)"
t_has "run: without Homebrew, says how to install it" "shell::homebrew::install" "$out"
t_eq "run: ...and returns RETURN_NOT_FOUND" "3" "$(
	shell::homebrew::path() { return 3; }
	shell::brew::run list >/dev/null 2>&1
	echo $?
)"
t_has "dry-run needs no Homebrew" "brew install git" "$(
	shell::homebrew::path() { return 3; }
	shell::brew::install -n git 2>&1
)"

# --- shell::brew::run ---------------------------------------------------------------------------
t_eq "run: passes the arguments through verbatim" "install --cask firefox" "$(calls shell::brew::run install --cask firefox)"
t_eq "run: an argument with spaces stays one argument" 'search two words' "$(calls shell::brew::run search 'two words')"
t_eq "run: -n does not start brew" "" "$(calls shell::brew::run -n install git)"
t_has "run: -n prints the command" "brew install git" "$(say shell::brew::run -n install git)"
t_eq "run: no sub-command is invalid" "2" "$(rc_of shell::brew::run)"
t_eq "run: -n alone is invalid too" "2" "$(rc_of shell::brew::run -n)"
printf '1\n' >"$FAKE_BREW_DIR/install_nope.rc"
t_eq "run: brew's exit status is returned" "1" "$(rc_of shell::brew::run install nope)"
rm -f "$FAKE_BREW_DIR/install_nope.rc"

# --- every function has a help, and --help never calls brew --------------------------------------
for fn in version help doctor config prefix cache update outdated upgrade pin unpin pinned tap untap \
	available search info list versions leaves deps uses missing install reinstall uninstall \
	link unlink switch cleanup autoremove services bundle::dump bundle::install bundle::cleanup; do
	out="$(calls "shell::brew::$fn" -h)"
	t_eq "$fn -h: brew is not started" "" "$out"
	out="$(say "shell::brew::$fn" --help)"
	t_has "$fn --help: shows its usage" "USAGE: shell::brew::$fn" "$out"
	t_has "$fn --help: documents --dry-run" "--dry-run" "$out"
	t_eq "$fn --help: returns 0" "0" "$(rc_of "shell::brew::$fn" -h)"
done

# --- install / reinstall / uninstall -------------------------------------------------------------
t_eq "install: formulae" "install git jq" "$(calls shell::brew::install git jq)"
t_eq "install: --cask" "install --cask firefox" "$(calls shell::brew::install --cask firefox)"
t_eq "install: -c is --cask" "install --cask firefox" "$(calls shell::brew::install -c firefox)"
t_eq "install: --formula" "install --formula git" "$(calls shell::brew::install --formula git)"
t_eq "install: --force" "install --force git" "$(calls shell::brew::install --force git)"
t_eq "install: -f is --force" "install --force git" "$(calls shell::brew::install -f git)"
t_eq "install: flags may follow the names" "install --cask a b" "$(calls shell::brew::install a b --cask)"
t_eq "install: versioned and tap-qualified names" "install node@20 acme/tools/foo" "$(calls shell::brew::install node@20 acme/tools/foo)"
t_eq "install: -n runs nothing" "" "$(calls shell::brew::install -n git)"
t_has "install: -n prints brew install" "brew install --cask firefox" "$(say shell::brew::install -n -c firefox)"
t_eq "install: no name is invalid" "2" "$(rc_of shell::brew::install)"
t_eq "install: ...and nothing runs" "" "$(calls shell::brew::install)"
t_has "install: ...with a message" "At least 1 package name(s) required" "$(say shell::brew::install)"
t_eq "install: unknown option" "2" "$(rc_of shell::brew::install --bogus git)"
t_has "install: ...is named" "Unknown option: --bogus" "$(say shell::brew::install --bogus git)"
t_eq "install: -- ends the options, a name after it is still checked" "2" "$(rc_of shell::brew::install -- --force)"
t_eq "reinstall: formulae" "reinstall git" "$(calls shell::brew::reinstall git)"
t_eq "reinstall: --cask --force" "reinstall --cask --force firefox" "$(calls shell::brew::reinstall -c -f firefox)"
t_eq "reinstall: needs a name" "2" "$(rc_of shell::brew::reinstall)"
t_eq "uninstall: formula" "uninstall wget" "$(calls shell::brew::uninstall wget)"
t_eq "uninstall: --force" "uninstall --force wget" "$(calls shell::brew::uninstall -f wget)"
t_eq "uninstall: --cask" "uninstall --cask firefox" "$(calls shell::brew::uninstall --cask firefox)"
t_eq "uninstall: --zap implies --cask" "uninstall --cask --zap firefox" "$(calls shell::brew::uninstall --zap firefox)"
t_eq "uninstall: -z with -c does not repeat --cask" "uninstall --cask --zap firefox" "$(calls shell::brew::uninstall -c -z firefox)"
t_eq "uninstall: --ignore-dependencies" "uninstall --ignore-dependencies openssl@3" "$(calls shell::brew::uninstall --ignore-dependencies openssl@3)"
t_eq "uninstall: needs a name" "2" "$(rc_of shell::brew::uninstall --zap)"

# Nothing that could be an option or a shell construct ever reaches brew.
for bad in -rf -x 'a b' 'a;b' '$(x)' '`x`' '../x' 'a|b' '' 'a"b'; do
	t_eq "install '$bad': refused" "2" "$(rc_of shell::brew::install git "$bad")"
	t_eq "install '$bad': brew never started" "" "$(calls shell::brew::install git "$bad")"
	t_eq "uninstall '$bad': brew never started" "" "$(calls shell::brew::uninstall "$bad")"
done
t_has "install: an unsafe name is quoted in the message" "Invalid package name: 'a;b'" "$(say shell::brew::install 'a;b')"

# --- update / outdated / upgrade ------------------------------------------------------------------
t_eq "update" "update" "$(calls shell::brew::update)"
t_eq "update: --force" "update --force" "$(calls shell::brew::update -f)"
t_eq "update: takes no package" "2" "$(rc_of shell::brew::update git)"
t_has "update: ...says so" "takes no arguments" "$(say shell::brew::update git)"
t_eq "outdated" "outdated" "$(calls shell::brew::outdated)"
t_eq "outdated: --cask --greedy" "outdated --cask --greedy" "$(calls shell::brew::outdated --cask --greedy)"
t_eq "outdated: --formula" "outdated --formula" "$(calls shell::brew::outdated --formula)"
t_eq "outdated: -q" "outdated --quiet" "$(calls shell::brew::outdated -q)"
t_eq "outdated: -v" "outdated --verbose" "$(calls shell::brew::outdated -v)"
t_eq "outdated: for named packages" "outdated git" "$(calls shell::brew::outdated git)"
t_eq "upgrade: everything" "upgrade" "$(calls shell::brew::upgrade)"
t_eq "upgrade: named" "upgrade git jq" "$(calls shell::brew::upgrade git jq)"
t_eq "upgrade: --cask --greedy" "upgrade --cask --greedy" "$(calls shell::brew::upgrade -c -g)"
t_eq "upgrade: --force" "upgrade --force git" "$(calls shell::brew::upgrade -f git)"
t_eq "upgrade: -n" "" "$(calls shell::brew::upgrade -n)"
t_has "upgrade: -n prints it" "brew upgrade" "$(say shell::brew::upgrade -n)"
t_eq "upgrade: refuses an unsafe name" "2" "$(rc_of shell::brew::upgrade '--all')"

# --- pin / unpin / pinned ----------------------------------------------------------------------------
t_eq "pin" "pin node@20" "$(calls shell::brew::pin node@20)"
t_eq "pin: --cask" "pin --cask firefox" "$(calls shell::brew::pin -c firefox)"
t_eq "pin: needs a name" "2" "$(rc_of shell::brew::pin)"
t_eq "unpin" "unpin node@20" "$(calls shell::brew::unpin node@20)"
t_eq "unpin: needs a name" "2" "$(rc_of shell::brew::unpin)"
t_eq "pinned" "list --pinned" "$(calls shell::brew::pinned)"
t_eq "pinned: takes no argument" "2" "$(rc_of shell::brew::pinned git)"

# --- taps ---------------------------------------------------------------------------------------------
t_eq "tap: list" "tap" "$(calls shell::brew::tap)"
t_eq "tap: add" "tap homebrew/cask-versions" "$(calls shell::brew::tap homebrew/cask-versions)"
t_eq "tap: add from a URL" "tap acme/tools https://git.example.com/acme/homebrew-tools.git" "$(calls shell::brew::tap acme/tools https://git.example.com/acme/homebrew-tools.git)"
t_eq "tap: not user/repo" "2" "$(rc_of shell::brew::tap notatap)"
t_eq "tap: ...brew never started" "" "$(calls shell::brew::tap notatap)"
t_eq "tap: a URL that is an option" "2" "$(rc_of shell::brew::tap acme/tools --force)"
t_eq "tap: a URL with a space" "2" "$(rc_of shell::brew::tap acme/tools 'http://x y')"
t_eq "tap: three arguments" "2" "$(rc_of shell::brew::tap a/b http://x extra)"
t_eq "untap" "untap acme/tools" "$(calls shell::brew::untap acme/tools)"
t_eq "untap: several, --force" "untap --force a/b c/d" "$(calls shell::brew::untap -f a/b c/d)"
t_eq "untap: needs a tap" "2" "$(rc_of shell::brew::untap)"
t_eq "untap: validates every tap" "2" "$(rc_of shell::brew::untap a/b bad)"

# --- search / info / list --------------------------------------------------------------------------------
t_eq "search" "search python" "$(calls shell::brew::search python)"
t_eq "search: --desc --cask" "search --cask --desc video player" "$(calls shell::brew::search --cask --desc 'video player')"
t_eq "search: a /regex/" "search /^py.*/" "$(calls shell::brew::search '/^py.*/')"
t_eq "search: needs text" "2" "$(rc_of shell::brew::search)"
t_eq "search: only one text" "2" "$(rc_of shell::brew::search a b)"
t_eq "search: text after -- may start with a dash" "search -- -x" "$(calls shell::brew::search -- -x)"
t_eq "info" "info git" "$(calls shell::brew::info git)"
t_eq "info: --cask" "info --cask firefox" "$(calls shell::brew::info -c firefox)"
t_eq "info: --json is v2" "info --json=v2 git" "$(calls shell::brew::info --json git)"
t_eq "info: --installed with no name" "info --installed" "$(calls shell::brew::info -i)"
t_eq "info: refuses an unsafe name" "2" "$(rc_of shell::brew::info 'a b')"
t_eq "list" "list" "$(calls shell::brew::list)"
t_eq "list: --cask" "list --cask" "$(calls shell::brew::list --cask)"
t_eq "list: --versions of a package (the cheat sheet)" "list --versions git" "$(calls shell::brew::list --versions git)"
t_eq "list: --requested" "list --installed-on-request" "$(calls shell::brew::list -r)"
t_eq "list: --multiple --pinned -1" "list --versions --multiple --pinned -1" "$(calls shell::brew::list -v --multiple --pinned -1)"
t_eq "versions" "list --versions git" "$(calls shell::brew::versions git)"
t_eq "versions: --cask" "list --versions --cask firefox" "$(calls shell::brew::versions -c firefox)"
t_eq "versions: needs a name" "2" "$(rc_of shell::brew::versions)"
t_eq "available: formulae" "formulae" "$(calls shell::brew::available)"
t_eq "available: casks" "casks" "$(calls shell::brew::available --cask)"
t_eq "available: takes no name" "2" "$(rc_of shell::brew::available git)"
t_eq "leaves" "leaves" "$(calls shell::brew::leaves)"
t_eq "leaves: --requested" "leaves --installed-on-request" "$(calls shell::brew::leaves -r)"
t_eq "leaves: --dependency" "leaves --installed-as-dependency" "$(calls shell::brew::leaves -d)"
t_eq "deps: tree" "deps --tree git" "$(calls shell::brew::deps --tree git)"
t_eq "deps: installed, direct" "deps --installed --direct" "$(calls shell::brew::deps -i -1)"
t_eq "uses: restricted to installed formulae by default" "uses --installed openssl@3" "$(calls shell::brew::uses openssl@3)"
t_eq "uses: --recursive" "uses --installed --recursive openssl@3" "$(calls shell::brew::uses -r openssl@3)"
t_eq "uses: --all drops the restriction" "uses openssl@3" "$(calls shell::brew::uses --all openssl@3)"
t_eq "uses: needs a name" "2" "$(rc_of shell::brew::uses)"
t_eq "missing" "missing" "$(calls shell::brew::missing)"
t_eq "missing: named" "missing git" "$(calls shell::brew::missing git)"

# --- version, help, doctor, config, prefix, cache ---------------------------------------------------------
t_eq "version" "--version" "$(calls shell::brew::version)"
t_eq "version: takes no argument" "2" "$(rc_of shell::brew::version x)"
t_eq "help" "help" "$(calls shell::brew::help)"
t_eq "help: a sub-command" "help install" "$(calls shell::brew::help install)"
t_eq "help: a sub-command with a dash" "help list-all" "$(calls shell::brew::help list-all)"
for bad in Install '-x' 'a b' 'a;b' '9x'; do
	t_eq "help '$bad': refused" "2" "$(rc_of shell::brew::help "$bad")"
done
t_eq "help: one sub-command at most" "2" "$(rc_of shell::brew::help a b)"
t_eq "doctor" "doctor" "$(calls shell::brew::doctor)"
t_eq "config" "config" "$(calls shell::brew::config)"
t_eq "prefix" "--prefix" "$(calls shell::brew::prefix)"
t_eq "prefix: of a package" "--prefix openssl@3" "$(calls shell::brew::prefix openssl@3)"
t_eq "prefix: prints what brew prints" "/opt/x" "$(printf '/opt/x\n' >"$FAKE_BREW_DIR/--prefix" && shell::brew::prefix 2>/dev/null | tail -n 1)"
rm -f "$FAKE_BREW_DIR/--prefix"
t_eq "cache" "--cache" "$(calls shell::brew::cache)"

# --- link / unlink / switch -------------------------------------------------------------------------------
t_eq "link" "link git" "$(calls shell::brew::link git)"
t_eq "link: --force --overwrite" "link --force --overwrite node@20" "$(calls shell::brew::link -f -o node@20)"
t_eq "link: --preview is brew's own dry run" "link --dry-run git" "$(calls shell::brew::link --preview git)"
t_eq "link: needs a name" "2" "$(rc_of shell::brew::link)"
t_eq "unlink" "unlink git" "$(calls shell::brew::unlink git)"
t_eq "unlink: --preview" "unlink --dry-run git" "$(calls shell::brew::unlink -p git)"

printf 'node@20 20.11.0\n' >"$FAKE_BREW_DIR/list_--versions_node@20"
t_eq "switch: unlink, then link the versioned formula" "list --versions node@20${nl}unlink node${nl}link --overwrite --force node@20" "$(calls shell::brew::switch node 20)"
t_eq "switch: a dotted version" "list --versions python@3.12${nl}unlink python${nl}link --overwrite --force python@3.12" "$(printf 'python@3.12 3.12.1\n' >"$FAKE_BREW_DIR/list_--versions_python@3.12" && calls shell::brew::switch python 3.12)"
t_eq "switch: a version that is not installed is refused, nothing is changed" "list --versions node@18" "$(calls shell::brew::switch node 18)"
t_eq "switch: ...with RETURN_NOT_FOUND" "3" "$(rc_of shell::brew::switch node 18)"
t_has "switch: ...and the way to install it" "shell::brew::install node@18" "$(say shell::brew::switch node 18)"
t_eq "switch: -n runs nothing, not even the check" "" "$(calls shell::brew::switch -n node 99)"
t_has "switch: -n prints both steps" "brew link --overwrite --force node@99" "$(say shell::brew::switch -n node 99)"
t_eq "switch: wrong argument count" "2" "$(rc_of shell::brew::switch node)"
t_eq "switch: the formula is a plain name" "2" "$(rc_of shell::brew::switch node@20 20)"
t_eq "switch: an unsafe formula" "2" "$(rc_of shell::brew::switch 'a;b' 20)"
t_eq "switch: a version is not an option" "2" "$(rc_of shell::brew::switch node --force)"
t_eq "switch: a version starts with a digit" "2" "$(rc_of shell::brew::switch node lts)"
t_eq "switch: nothing ran for the refusals" "" "$(calls shell::brew::switch node 'x;y')"
printf '1\n' >"$FAKE_BREW_DIR/unlink_node.rc"
t_eq "switch: a failing unlink stops before linking" "list --versions node@20${nl}unlink node" "$(calls shell::brew::switch node 20)"
t_eq "switch: ...and its status is returned" "1" "$(rc_of shell::brew::switch node 20)"
rm -f "$FAKE_BREW_DIR/unlink_node.rc"
t_eq "switch: without Homebrew, says so (not 'not installed')" "3" "$(
	shell::homebrew::path() { return 3; }
	shell::brew::switch node 20 >/dev/null 2>&1
	echo $?
)"

# --- cleanup / autoremove -----------------------------------------------------------------------------------
t_eq "cleanup" "cleanup" "$(calls shell::brew::cleanup)"
t_eq "cleanup: --preview is brew cleanup --dry-run" "cleanup --dry-run" "$(calls shell::brew::cleanup --preview)"
t_eq "cleanup: -p -s" "cleanup --dry-run --scrub" "$(calls shell::brew::cleanup -p -s)"
t_eq "cleanup: --prune <days>" "cleanup --prune=30" "$(calls shell::brew::cleanup --prune 30)"
t_eq "cleanup: --prune=<days>" "cleanup --prune=30" "$(calls shell::brew::cleanup --prune=30)"
t_eq "cleanup: --prune all" "cleanup --prune=all" "$(calls shell::brew::cleanup --prune all)"
t_eq "cleanup: named" "cleanup git" "$(calls shell::brew::cleanup git)"
for bad in abc 3x -1 '1 2' '' 1.5; do
	t_eq "cleanup: --prune '$bad' is refused" "2" "$(rc_of shell::brew::cleanup --prune "$bad")"
	t_eq "cleanup: --prune '$bad': brew never started" "" "$(calls shell::brew::cleanup --prune "$bad")"
done
t_eq "cleanup: --prune needs a value" "2" "$(rc_of shell::brew::cleanup --prune)"
t_eq "cleanup: -n does not run" "" "$(calls shell::brew::cleanup -n)"
t_has "cleanup: -n prints it" "brew cleanup --dry-run" "$(say shell::brew::cleanup -n --preview)"
t_eq "autoremove" "autoremove" "$(calls shell::brew::autoremove)"
t_eq "autoremove: --preview" "autoremove --dry-run" "$(calls shell::brew::autoremove --preview)"
t_eq "autoremove: takes no name" "2" "$(rc_of shell::brew::autoremove git)"

# --- services -----------------------------------------------------------------------------------------------
t_eq "services: list" "services list" "$(calls shell::brew::services list)"
t_eq "services: start" "services start postgresql@16" "$(calls shell::brew::services start postgresql@16)"
t_eq "services: several names" "services restart a b" "$(calls shell::brew::services restart a b)"
t_eq "services: --all" "services stop --all" "$(calls shell::brew::services stop --all)"
t_eq "services: --all may come first" "services restart --all" "$(calls shell::brew::services --all restart)"
t_eq "services: cleanup" "services cleanup" "$(calls shell::brew::services cleanup)"
t_eq "services: info" "services info redis" "$(calls shell::brew::services info redis)"
for action in run kill; do
	t_eq "services: $action" "services $action redis" "$(calls shell::brew::services $action redis)"
done
t_eq "services: -n" "" "$(calls shell::brew::services -n start redis)"
t_has "services: -n prints it" "brew services start redis" "$(say shell::brew::services -n start redis)"
t_eq "services: no action" "2" "$(rc_of shell::brew::services)"
t_eq "services: an unknown action" "2" "$(rc_of shell::brew::services explode redis)"
t_eq "services: start needs a name" "2" "$(rc_of shell::brew::services start)"
t_eq "services: list takes no name" "2" "$(rc_of shell::brew::services list redis)"
t_eq "services: list takes no --all" "2" "$(rc_of shell::brew::services list --all)"
t_eq "services: an unsafe name" "2" "$(rc_of shell::brew::services start 'a;b')"
t_eq "services: an unknown option" "2" "$(rc_of shell::brew::services --bogus list)"
t_eq "services: refusals start nothing" "" "$(calls shell::brew::services start '-x')"

# --- bundle --------------------------------------------------------------------------------------------------
t_eq "bundle dump" "bundle dump" "$(calls shell::brew::bundle::dump)"
t_eq "bundle dump: file, --force, --describe" "bundle dump --file=$HOME/Brewfile --force --describe" "$(calls shell::brew::bundle::dump -f -d "$HOME/Brewfile")"
t_eq "bundle dump: -n" "" "$(calls shell::brew::bundle::dump -n)"
printf 'brew "git"\n' >"$HOME/Brewfile"
t_eq "bundle install" "bundle install" "$(calls shell::brew::bundle::install)"
t_eq "bundle install: file" "bundle install --file=$HOME/Brewfile" "$(calls shell::brew::bundle::install "$HOME/Brewfile")"
t_eq "bundle install: a Brewfile that is missing" "3" "$(rc_of shell::brew::bundle::install "$HOME/nope")"
t_eq "bundle install: ...brew never started" "" "$(calls shell::brew::bundle::install "$HOME/nope")"
t_has "bundle install: -n does not need the file to exist" "brew bundle install --file=$HOME/nope" "$(say shell::brew::bundle::install -n "$HOME/nope")"
t_eq "bundle install: --force makes no sense" "2" "$(rc_of shell::brew::bundle::install --force)"
t_eq "bundle install: nor does --describe" "2" "$(rc_of shell::brew::bundle::install --describe)"
t_eq "bundle cleanup lists by default" "bundle cleanup --file=$HOME/Brewfile" "$(calls shell::brew::bundle::cleanup "$HOME/Brewfile")"
t_eq "bundle cleanup --force removes" "bundle cleanup --file=$HOME/Brewfile --force" "$(calls shell::brew::bundle::cleanup --force "$HOME/Brewfile")"
t_eq "bundle cleanup: --describe makes no sense" "2" "$(rc_of shell::brew::bundle::cleanup --describe)"
t_eq "bundle: two files" "2" "$(rc_of shell::brew::bundle::dump a b)"
t_eq "bundle: a file that looks like an option" "2" "$(rc_of shell::brew::bundle::dump -n --file)"
t_eq "bundle: a path with a space" "2" "$(rc_of shell::brew::bundle::dump 'my file')"
t_eq "bundle: an unknown option" "2" "$(rc_of shell::brew::bundle::dump --bogus)"

# --- the aliases ----------------------------------------------------------------------------------------------
for pair in sbm:shell::brew::manage sbi:shell::brew::install::fzf sbrm:shell::brew::uninstall::fzf sbup:shell::brew::upgrade::fzf \
	sbunf:shell::brew::unused::fzf sbun:shell::brew::unused sbtidy:shell::brew::tidy sbl:shell::brew::list sbo:shell::brew::outdated; do
	t_has "alias ${pair%%:*} -> ${pair#*:}" "${pair#*:}" "$(alias "${pair%%:*}" 2>&1)"
done
t_has "alias with a dry-run twin" "shell::brew::manage -n" "$(alias sbm-n 2>&1)"
# Every function an alias points at exists.
missing=""
for fn in $(alias | sed -n "s/.*'\(shell::brew::[A-Za-z0-9:_]*\).*/\1/p" | sort -u); do
	command -v "$fn" >/dev/null 2>&1 || missing="$missing $fn"
done
t_eq "every brew alias points at a real function" "" "$missing"

t_done
