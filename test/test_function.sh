#!/usr/bin/env bash
# Function discovery (lib/function.sh): the catalog, list, info and the pieces they share. Two kinds of
# test: against a small fixture source tree (what is recognised, and attached to the right function, is
# exactly what the awk programs say), and against the real library (nothing is lost, nothing is invented).
. "${SHELL_TEST_ROOT:?run tests through test/run_tests.sh (make test), never directly: they would write to your real HOME and ~/.gitconfig}/test/lib.sh"
t_setup

nl='
'
tab="$(printf '\t')"
REAL_SRC="$SHELL_SRC_DIR"
REAL_DIR="$SHELL_DIR"

# --- the fixture tree --------------------------------------------------------------------------------
fx="$HOME/fx"
mkdir -p "$fx/src/lib" "$fx/src/lang"
cat >"$fx/src/lib/alpha.sh" <<'FX'
#!/usr/bin/env bash
# @file lib/alpha.sh
# @brief The file header, directly above the first function with no blank line.
shell::alpha::first() {
	:
}

# @description Does the first thing.
#   More about the first thing, on a second line.
# @option -h | --help Show help.
# @arg $1 string The thing.
# @exitcode 0 Done.
# @example
#   shell::alpha::first thing
#
shell::alpha::documented() {
	:
}

# @description
#   The description starts on the line after the tag.
#
#   A second paragraph.
# @noargs
# @exitcode 0 Always.
#
shell::alpha::next_line() {
	:
}

# @internal
# @description A private helper.
_shell::alpha::helper() {
	:
}

# @description Separated from its function by a blank line: not its documentation.

shell::alpha::orphan() {
	:
}

shell::alpha::bare() {
	:
}
FX
cat >"$fx/src/lang/beta.sh" <<'FX'
# @description Second namespace.
shell::beta::one() { :; }
# @description Nested namespace.
shell::beta::nested::deep() { :; }
# @description Top-level style name.
shell::standalone() { :; }
FX
printf '%s\n' 'echo "not a function: shell::decoy::x() {"' >"$fx/src/lib/decoy.sh"
# In the fixture the shell "has loaded" only what FX_LOADED says; the real library is out of the picture.
FX_LOADED=""
use_fx() {
	SHELL_SRC_DIR="$fx/src"
	SHELL_DIR="$fx"
	_shell::function::loaded() { printf '%s\n' "$FX_LOADED" | tr ' ' '\n' | sed '/^$/d'; }
}
use_real() {
	SHELL_SRC_DIR="$REAL_SRC"
	SHELL_DIR="$REAL_DIR"
	# shellcheck source=/dev/null
	. "$REAL_DIR/src/lib/function.sh"
}
rec() { _shell::function::catalog | awk -F'\t' -v n="$1" '$1 == n'; }
field() { rec "$1" | cut -f"$2"; }

use_fx
cat_out="$(_shell::function::catalog)"
t_eq "catalog: one record per function in the tree (9, nothing from the decoy line)" "9" "$(printf '%s\n' "$cat_out" | wc -l | tr -d ' ')"
t_eq "catalog: 8 tab-separated fields on every record" "8" "$(printf '%s\n' "$cat_out" | awk -F'\t' '{ print NF }' | sort -u)"
t_eq "catalog: sorted by name" "$(printf '%s\n' "$cat_out" | cut -f1)" "$(printf '%s\n' "$cat_out" | cut -f1 | LC_ALL=C sort)"
t_eq "catalog: no duplicate names" "" "$(printf '%s\n' "$cat_out" | cut -f1 | sort | uniq -d)"
t_eq "catalog: a decoy inside a string is not a function" "" "$(rec 'shell::decoy::x')"

# metadata is attached to the right function
t_eq "meta: summary of a documented function" "Does the first thing." "$(field shell::alpha::documented 8)"
t_eq "meta: a description that starts on the next line" "The description starts on the line after the tag." "$(field shell::alpha::next_line 8)"
t_eq "meta: a block with no description has an empty summary" "" "$(field shell::alpha::bare 8)"
t_eq "meta: a block separated by a blank line is not attached" "" "$(field shell::alpha::orphan 8)"
t_eq "meta: a file header above a function is not its description" "" "$(field shell::alpha::first 8)"
t_eq "meta: one-line functions are found" "Second namespace." "$(field shell::beta::one 8)"
t_eq "meta: file" "src/lib/alpha.sh" "$(field shell::alpha::documented 5)"
t_eq "meta: other file" "src/lang/beta.sh" "$(field shell::beta::one 5)"
t_eq "meta: the definition line" "16" "$(field shell::alpha::documented 7)"
t_eq "meta: the block starts at its first comment line (8 lines above)" "8" "$(($(field shell::alpha::documented 7) - $(field shell::alpha::documented 6)))"
t_eq "meta: a function with no block starts where it is defined" "$(field shell::alpha::bare 7)" "$(field shell::alpha::bare 6)"
t_eq "meta: public" "public" "$(field shell::alpha::documented 2)"
t_eq "meta: internal" "internal" "$(field _shell::alpha::helper 2)"
t_eq "meta: category is the namespace" "alpha" "$(field shell::alpha::documented 3)"
t_eq "meta: category of a nested name is its first namespace" "beta" "$(field shell::beta::nested::deep 3)"
t_eq "meta: category of a top-level name" "shell" "$(field shell::standalone 3)"
t_eq "meta: category of a private name" "alpha" "$(field _shell::alpha::helper 3)"
t_eq "meta: not loaded when the shell does not have it" "no" "$(field shell::alpha::documented 4)"

# loaded vs defined
FX_LOADED="shell::alpha::documented"
t_eq "loaded: a function the shell has is marked loaded" "yes" "$(field shell::alpha::documented 4)"
t_eq "loaded: ...and its neighbour is not" "no" "$(field shell::alpha::bare 4)"
FX_LOADED="shell::alpha::documented shell::zsession::demo"
t_eq "session: a function loaded but not in the tree is listed" "shell::zsession::demo" "$(field shell::zsession::demo 1)"
t_eq "session: ...with no file" "-" "$(field shell::zsession::demo 5)"
t_eq "session: ...and no description" "" "$(field shell::zsession::demo 8)"
FX_LOADED=""

# list / filters over the fixture
t_eq "list --names: public only, sorted by name" "shell::alpha::bare${nl}shell::alpha::documented${nl}shell::alpha::first${nl}shell::alpha::next_line${nl}shell::alpha::orphan${nl}shell::beta::nested::deep${nl}shell::beta::one${nl}shell::standalone" "$(shell::function::list --names)"
t_eq "list --names: 8 public functions" "8" "$(shell::function::list --names | wc -l | tr -d ' ')"
t_eq "list --names -i: 9 with the internal one" "9" "$(shell::function::list --names -i | wc -l | tr -d ' ')"
t_lacks "list: internal helpers are hidden by default" "_shell::alpha::helper" "$(shell::function::list --names)"
t_has "list: ...and shown with --internal" "_shell::alpha::helper" "$(shell::function::list --names --internal)"
t_eq "list --namespace alpha" "5" "$(shell::function::list --names --namespace alpha | wc -l | tr -d ' ')"
t_eq "list --namespace=beta" "2" "$(shell::function::list --names --namespace=beta | wc -l | tr -d ' ')"
t_eq "list -c beta::nested: a nested namespace" "shell::beta::nested::deep" "$(shell::function::list --names -c beta::nested)"
t_eq "list --category is the same as --namespace" "2" "$(shell::function::list --names --category beta | wc -l | tr -d ' ')"
t_eq "list: a keyword in the name" "shell::beta::one" "$(shell::function::list --names beta::one)"
t_eq "list: a keyword in the description" "shell::beta::nested::deep" "$(shell::function::list --names Nested)"
t_eq "list: keywords are case-insensitive" "shell::alpha::documented" "$(shell::function::list --names FIRST THING)"
t_eq "list: every word must match (AND)" "" "$(shell::function::list --names first nested 2>/dev/null)"
t_eq "list: a namespace and a keyword together" "shell::alpha::documented" "$(shell::function::list --names -c alpha first thing)"
t_eq "list: -- ends the options" "shell::alpha::first" "$(shell::function::list --names -- alpha::first)"
t_eq "list --namespaces: one line per namespace with its count" "alpha            5${nl}beta             2${nl}shell            1" "$(shell::function::list --namespaces)"
out="$(shell::function::list)"
t_has "list: groups by namespace with a count" "alpha (5)" "$out"
t_has "list: names are indented under their group" "  shell::alpha::documented" "$out"
t_has "list: shows the summary" "Does the first thing." "$out"
t_has "list: a function without documentation says so" "(no description)" "$out"
t_has "list: a total" "8 function(s)" "$out"
t_eq "list --tsv: the catalog records" "8" "$(shell::function::list --tsv | awk -F'\t' '{ print NF }' | sort -u)"
t_eq "list --unloaded: everything in the fixture is not loaded" "8" "$(shell::function::list --names --unloaded | wc -l | tr -d ' ')"
t_has "list: unloaded functions are marked" "[not loaded] Does the first thing." "$out"
FX_LOADED="shell::alpha::documented"
t_eq "list --unloaded: ...a loaded one drops out" "7" "$(shell::function::list --names --unloaded | wc -l | tr -d ' ')"
FX_LOADED=""

# empty results and bad usage
t_rc "list: nothing matches" 8 shell::function::list zzznomatch
t_eq "list: ...and prints nothing on stdout" "" "$(shell::function::list zzznomatch 2>/dev/null)"
t_rc "list: an unknown namespace" 8 shell::function::list --namespace nosuch
t_rc "list: an unknown option" 2 shell::function::list --bogus
t_rc "list: an option without its value" 2 shell::function::list --namespace
t_rc "list -h" 0 shell::function::list -h
SHELL_SRC_DIR="$HOME/nowhere"
t_rc "list: an unreadable source tree and nothing loaded matches nothing" 8 shell::function::list --names zzznomatch
use_fx

# info over the fixture
out="$(shell::function::info shell::alpha::documented)"
t_has "info: the name" "shell::alpha::documented" "$out"
t_has "info: visibility, namespace and load state" "public | alpha | not loaded" "$out"
t_has "info: where it is defined" "src/lib/alpha.sh:16" "$out"
t_has "info: description, both lines" "More about the first thing, on a second line." "$out"
t_has "info: options" "-h | --help Show help." "$out"
t_has "info: arguments" "\$1 string The thing." "$out"
t_has "info: exit codes" "0 Done." "$out"
t_has "info: examples, indented once" "  shell::alpha::first thing" "$out"
t_has "info: section headings" "EXAMPLES" "$out"
t_lacks "info: the lone # that ends the block is not shown" "#" "$out"
out="$(shell::function::info alpha::next_line)"
t_has "info: the name may omit shell::" "shell::alpha::next_line" "$out"
t_has "info: paragraphs" "A second paragraph." "$out"
t_has "info: @noargs" "(none)" "$out"
out="$(shell::function::info shell::alpha::bare)"
t_has "info: no documentation block" "no documentation block" "$out"
t_eq "info: ...still names the function" "1" "$(printf '%s\n' "$out" | grep -c '^shell::alpha::bare$')"
out="$(shell::function::info alpha::helper)"
t_has "info: the internal form is found without the prefix" "_shell::alpha::helper" "$out"
t_has "info: ...and is marked internal" "internal | alpha" "$out"
t_has "info --raw: the block as written" "# @description Does the first thing." "$(shell::function::info --raw alpha::documented)"
t_rc "info: unknown function" 3 shell::function::info shell::nope::nothing
t_has "info: ...suggests similar names" "Similar: shell::alpha::bare" "$(shell::function::info bare 2>&1)"
t_rc "info: no name" 2 shell::function::info
t_rc "info: two names" 2 shell::function::info a b
t_rc "info: unknown option" 2 shell::function::info --bogus x
t_rc "info -h" 0 shell::function::info -h
FX_LOADED="shell::zsession::demo"
out="$(shell::function::info shell::zsession::demo)"
t_has "info: a function with no source" "loaded" "$out"
t_has "info: ...says there is no documentation" "no documentation" "$out"
FX_LOADED=""

# a new function appears by itself, in the right place
cat >>"$fx/src/lang/beta.sh" <<'FX'
# @description Added later.
shell::beta::added() { :; }
FX
t_eq "new function: found without registering it anywhere" "Added later." "$(field shell::beta::added 8)"
t_has "new function: listed in its namespace" "shell::beta::added" "$(shell::function::list --names -c beta)"
t_eq "new function: the namespace count follows" "3" "$(shell::function::list --names -c beta | wc -l | tr -d ' ')"
mkdir -p "$fx/src/bot"
printf '# @description In a new file.\nshell::gamma::fresh() { :; }\n' >"$fx/src/bot/gamma.sh"
t_eq "new function: also in a new file of a new namespace" "src/bot/gamma.sh" "$(field shell::gamma::fresh 5)"
# a path with spaces
mkdir -p "$HOME/my fx/src/lib"
printf '# @description Spaces.\nshell::sp::ace() { :; }\n' >"$HOME/my fx/src/lib/s.sh"
SHELL_SRC_DIR="$HOME/my fx/src"
SHELL_DIR="$HOME/my fx"
t_eq "paths with spaces are read" "src/lib/s.sh" "$(field shell::sp::ace 5)"

# --- the real library -----------------------------------------------------------------------------------
use_real
real="$(_shell::function::catalog)"
t_eq "real: every record has 8 fields" "8" "$(printf '%s\n' "$real" | awk -F'\t' '{ print NF }' | sort -u)"
unrelated_fn() { :; }
_other_helper() { :; }
t_eq "real: functions outside shell:: are never listed (even when defined in the shell)" "" "$(printf '%s\n' "$real" | cut -f1 | grep -x -e unrelated_fn -e _other_helper)"
unset -f unrelated_fn _other_helper
t_eq "real: only shell:: names" "0" "$(printf '%s\n' "$real" | cut -f1 | grep -c -v -E '^_?shell::')"
t_eq "real: no duplicates" "" "$(printf '%s\n' "$real" | cut -f1 | sort | uniq -d)"

# the catalog agrees with the source tree (what make lint checks) ...
defs="$(grep -rhoE '^_?shell::[A-Za-z0-9_:]+\(\)' "$REAL_SRC" --include='*.sh' | sed 's/()//' | sort)"
t_eq "real: exactly the functions defined in src/" "$defs" "$(printf '%s\n' "$real" | cut -f1 | sort)"
t_eq "real: public/internal follows the _shell:: prefix" "0" "$(printf '%s\n' "$real" | awk -F'\t' '($1 ~ /^_/) != ($2 == "internal")' | wc -l | tr -d ' ')"
# ... and with the shell
loaded_names="$(_shell::function::loaded | sort)"
t_eq "real: nothing in the tree failed to load" "" "$(printf '%s\n' "$real" | awk -F'\t' '$4 == "no" { print $1 }')"
t_eq "real: everything loaded under shell:: is in the catalog" "" "$(printf '%s\n%s\n' "$loaded_names" "$(printf '%s\n' "$real" | cut -f1 | sort)" | sort | uniq -u)"
# ... and with the documentation
t_eq "real: every public function has a description (the shdoc rule)" "" "$(printf '%s\n' "$real" | awk -F'\t' '$2 == "public" && $8 == "" { print $1 }')"
t_eq "real: every record points at the line where the function is defined" "0" "$(printf '%s\n' "$real" | awk -F'\t' -v d="$REAL_DIR" '{ n = 0; while ((getline l < (d "/" $5)) > 0) { n++; if (n == $7) { if (index(l, $1 "()") != 1) bad++; break } } close(d "/" $5) } END { print bad + 0 }')"
# the names in the generated API docs are a subset of what exists
stale="$(grep -rhoE '^[[:space:]]*- \[_?shell::[A-Za-z0-9_:]+\]' "$REAL_DIR/docs/api" 2>/dev/null | sed -E 's/.*\[//; s/\]//' | sort -u | awk -v cat="$(printf '%s\n' "$real" | cut -f1 | sort | tr '\n' ' ')" 'BEGIN { n = split(cat, a, " "); for (i = 1; i <= n; i++) k[a[i]] = 1 } !($1 in k) { print $1 }')"
if [ -n "$stale" ]; then
	printf '  NOTE: docs/api (generated, make docs) lists functions that no longer exist: %s\n' "$(printf '%s' "$stale" | tr '\n' ' ')"
fi
t_has "real: shell::help is documented and public" "public | shell |" "$(shell::function::info shell::help)"
t_has "real: a public function of another module" "src/lib/fs.sh" "$(shell::function::info fs::browse)"
t_eq "real: namespaces seen by list" "1" "$(shell::function::list --namespaces | grep -c '^git ')"
t_has "real: --names -c git::commit::pick" "shell::git::commit::pick::fzf" "$(shell::function::list --names -c git::commit::pick)"
t_eq "real: ...only that prefix" "0" "$(shell::function::list --names -c git::commit::pick | grep -c -v '^shell::git::commit::pick')"
t_eq "real: -c matches the catalog count" "$(printf '%s\n' "$real" | awk -F'\t' '$2 == "public" && $3 == "ssh"' | wc -l | tr -d ' ')" "$(shell::function::list --names -c ssh | wc -l | tr -d ' ')"
# a function that is in the tree but not loaded (one unloaded in a subshell)
t_eq "real: unloaded function is reported as such" "shell::go::env::get_private" "$(
	unset -f shell::go::env::get_private
	shell::function::list --names --unloaded
)"
# one mechanism: the other files do not read function definitions on their own
t_eq "design: one reader of the catalog awk (outside the constants)" "1" "$(grep -rl 'SHELL_FUNCTION_CATALOG_AWK' "$REAL_SRC" | grep -vc '/constant/')"
t_eq "design: the entry point delegates (no listing logic in shell.sh)" "0" "$(grep -c 'declare -F\|typeset +f' "$REAL_SRC/shell.sh")"

# the architecture documentation matches the implementation
doc="$REAL_DIR/docs/features/function-discovery.md"
arch="$REAL_DIR/docs/development/architecture.md"
mine="$(printf '%s\n' "$real" | cut -f1,5 | awk -F'\t' '$2 == "src/lib/function.sh" { print $1 }')"
t_eq "docs: every function of the module is named in the feature guide (or its backtick short form)" "" "$(for f in $(printf '%s\n' "$mine" | grep -v '^_'); do grep -q -F "$f" "$doc" || grep -q -F "${f#shell::function::}" "$doc" || echo "$f"; done)"
t_eq "docs: every private function the guide names exists in the catalog" "" "$(grep -o '_shell::function::[a-z_]*' "$doc" "$arch" | sed 's/^[^:]*://' | sort -u | while read -r f; do printf '%s\n' "$real" | cut -f1 | grep -qx "$f" || echo "$f"; done)"
t_eq "docs: every shell::function::* the docs name exists" "" "$(grep -ohE '(^|[^_a-z])shell::function::[a-z_]*[a-z]' "$doc" "$arch" "$REAL_DIR/README.md" | sed 's/^[^s]*//' | sort -u | while read -r f; do printf '%s\n' "$real" | cut -f1 | grep -qx "$f" || echo "$f"; done)"
t_eq "docs: the data files the docs name exist" "" "$(grep -oh 'src/data/function-[a-z-]*\.[a-z]*\|data/function-[a-z-]*\.[a-z]*' "$doc" "$arch" | sed 's#^data/#src/data/#' | sort -u | while read -r f; do [ -f "$REAL_DIR/$f" ] || echo "$f"; done)"
t_has "docs: the architecture page has the section" "## Function discovery" "$(cat "$arch")"
t_has "docs: the index links the guide" "features/function-discovery.md" "$(cat "$REAL_DIR/docs/README.md")"
t_has "docs: the conventions tell contributors how the block is used" "shell::function::list" "$(cat "$REAL_DIR/docs/development/conventions.md")"
t_eq "docs: the aliases exist" "3" "$(grep -c '^alias sf[nli]=' "$REAL_DIR/src/alias/alias.sh")"

# the loader's own entry points
t_rc "help --plain lists" 0 shell::help --plain
t_has "help --plain: the list" "function(s)" "$(shell::help --plain git 2>&1)"
t_rc "help -h" 0 shell::help -h
t_has "help: auto mode without a terminal prints the list" "shell::git::commit::pick::fzf" "$(shell::help git::commit::pick 2>&1)"
t_has "explore: a namespace as the argument is the list of that namespace" "ssh (" "$(shell::function::explore ssh 2>&1)"
t_lacks "explore: ...and nothing else" "git (" "$(shell::function::explore ssh 2>&1)"
t_has "explore: other words are a search" "shell::git::commit::pick::fzf" "$(shell::function::explore pick commit 2>&1)"
t_rc "explore: unknown option" 2 shell::function::explore --bogus
t_rc "explore -h" 0 shell::function::explore -h
t_rc "explore: nothing matches" 8 shell::function::explore --plain zzznomatch

# invoking: validation only (the explorer tests cover the interactive part)
t_rc "invoke: not a function name" 2 _shell::function::invoke 'shell::os::type; echo hacked'
t_rc "invoke: not loaded" 3 _shell::function::invoke shell::nope::nothing

t_done
