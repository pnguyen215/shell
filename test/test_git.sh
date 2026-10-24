#!/usr/bin/env bash
# shell::git::commit::message::base: every catalog record must be a valid
# Conventional Commits 1.0.0 header, safe to pass to `git commit -m` through eval,
# and the menu must render it with or without the emoji. fzf is faked.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

catalog="$(shell::git::commit::message::catalog)"

# Run an awk program over the catalog; it prints one line per violation.
check() { printf '%s\n' "$catalog" | awk -F'|' "$1"; }

t_eq "catalog is large" "1" "$([ "$(printf '%s\n' "$catalog" | wc -l)" -ge 300 ] && echo 1 || echo 0)"
t_eq "many categories" "1" "$([ "$(printf '%s\n' "$catalog" | cut -d'|' -f1 | sort -u | wc -l)" -ge 30 ] && echo 1 || echo 0)"

t_eq "every record has exactly 4 fields" "" "$(check 'NF != 4 { print NR": "$0 }')"

# <type>[(scope)][!] with a type from the conventional set; scope is a lower-case noun.
t_eq "header: valid type, optional scope, optional !" "" "$(check '
$3 !~ /^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([a-z0-9][a-z0-9.-]*\))?!?$/ { print NR": "$3 }')"

# Description follows ": ", starts lower case, imperative text, no final period.
t_eq "description: starts lower case or a digit" "" "$(check '$4 !~ /^[a-z0-9]/ { print NR": "$4 }')"
t_eq "description: no final period" "" "$(check '$4 ~ /\.$/ { print NR": "$4 }')"
t_eq "description: long enough to be meaningful" "" "$(check 'length($4) < 12 && $4 != "initial commit" { print NR": "$4 }')"

# Safe for `git commit -m "..."` and eval: no quote, dollar, backtick, backslash, apostrophe, pipe.
t_eq "no shell-special characters" "" "$(check '
index($4, "\"") || index($4, "$") || index($4, "`") || index($4, "\\") || index($4, "\047") { print NR": "$4 }')"

# Header length: git recommends 72; commitlint allows 100 (emoji shortcode adds ~20).
t_eq "plain header <= 72 chars" "" "$(check 'length($3) + 2 + length($4) > 72 { print NR": "length($3)+2+length($4)": "$3": "$4 }')"
t_eq "emoji header <= 100 chars" "" "$(check 'length($3) + 2 + length($2) + 1 + length($4) > 100 { print NR": "$3": "$4 }')"
t_eq "emoji is a :shortcode:" "" "$(check '$2 !~ /^:[a-z0-9_+-]+:$/ { print NR": "$2 }')"

t_eq "no duplicate messages" "" "$(printf '%s\n' "$catalog" | cut -d'|' -f3,4 | sort | uniq -d)"
t_eq "no category has fewer than 5 messages" "" "$(printf '%s\n' "$catalog" | cut -d'|' -f1 | sort | uniq -c | awk '$1 < 5 { print }')"

# Semantics: a breaking change (!) must say what breaks, feat/fix/revert keep their meaning.
t_eq "breaking changes exist (edge case covered)" "1" "$([ "$(check '$3 ~ /!$/ { print }' | wc -l)" -ge 5 ] && echo 1 || echo 0)"
t_eq "revert type exists" "1" "$([ "$(check '$3 ~ /^revert/ { print }' | wc -l)" -ge 5 ] && echo 1 || echo 0)"
t_eq "all standard types are used" "11" "$(printf '%s\n' "$catalog" | cut -d'|' -f3 | sed 's/[(!].*//' | sort -u | wc -l | tr -d ' ')"

# --- the menu (fake fzf plays back picks, then ESC) ----------------------------------------
mkdir "$HOME/bin"
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
n="$(cat "$FAKE_FZF_STATE" 2>/dev/null || echo 0)"
n=$((n + 1))
echo "$n" >"$FAKE_FZF_STATE"
cat >"$FAKE_FZF_DIR/stdin.$n"
pick="$(printf '%s\n' "$FAKE_FZF_PICKS" | sed -n "${n}p")"
[ -z "$pick" ] && exit 130
printf '%s\n' "$pick"
FAKE
chmod +x "$HOME/bin/fzf"
export PATH="$HOME/bin:$PATH" FAKE_FZF_DIR="$HOME" FAKE_FZF_STATE="$HOME/fzf.count" FAKE_FZF_PICKS=""
reset_fzf() {
	find "$HOME" -maxdepth 1 -name 'stdin.*' -delete
	rm -f "$FAKE_FZF_STATE"
}
pick_msg() { # <category> <message-as-shown>  -> runs base with those two picks
	reset_fzf
	FAKE_FZF_PICKS="$(printf '%s\n%s' "$1" "$2")" shell::git::commit::message::base "${@:3}" 2>/dev/null
}

cat="Feature and Product Development"
out="$(pick_msg "$cat" "feat: :sparkles: add user-facing support for the requested workflow")"
t_eq "default: type first, emoji after the colon" "feat: :sparkles: add user-facing support for the requested workflow" "$out"
t_eq "default output is a parseable conventional header" "0" "$(printf '%s\n' "$out" | grep -Ec '^[a-z]+(\([a-z0-9.-]+\))?!?: ' | awk '{ print ($1 == 1) ? 0 : 1 }')"

out="$(pick_msg "$cat" "feat: add user-facing support for the requested workflow" --plain)"
t_eq "--plain drops the emoji" "feat: add user-facing support for the requested workflow" "$out"

# Scope and breaking marker are rendered in front of the colon.
out="$(pick_msg "Breaking Changes and Deprecations" "feat(api)!: :boom: remove deprecated endpoints and drop v1 support")"
t_eq "scope and ! precede the colon" "feat(api)!: :boom: remove deprecated endpoints and drop v1 support" "$out"

# The menus show the right lists.
reset_fzf
FAKE_FZF_PICKS="$cat" shell::git::commit::message::base >/dev/null 2>&1
t_has "category menu lists the first category" "CI/CD Pipeline Triggers" "$(cat "$HOME/stdin.1")"
t_has "category menu lists a new edge-case category" "Revert and Rollback" "$(cat "$HOME/stdin.1")"
t_has "message menu is limited to the category" "feat: :sparkles: support bulk actions for selected records" "$(cat "$HOME/stdin.2")"
t_lacks "message menu has no other category" "fix: :bug:" "$(cat "$HOME/stdin.2")"
t_lacks "no legacy emoji-first message is offered" ":sparkles: feat:" "$(cat "$HOME/stdin.2")"

# Cancelling is not an error and prints nothing.
reset_fzf
out="$(FAKE_FZF_PICKS="" shell::git::commit::message::base 2>/dev/null)"
t_eq "ESC at the category menu: nothing printed" "" "$out"
FAKE_FZF_PICKS="" shell::git::commit::message::base >/dev/null 2>&1
t_eq "ESC returns 0" "0" "$?"
reset_fzf
FAKE_FZF_PICKS="$cat" shell::git::commit::message::base >/dev/null 2>&1
t_eq "ESC at the message menu returns 0" "0" "$?"

shell::git::commit::message::base --bogus >/dev/null 2>&1
t_eq "unknown option is rejected" "2" "$?"
t_rc "help" 0 shell::git::commit::message::base -h
t_has "help mentions --plain" "--plain" "$T_OUT"

t_done
