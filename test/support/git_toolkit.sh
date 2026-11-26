#!/usr/bin/env bash
# Shared fixtures for the Git toolkit tests (src/lang/git). Source it after t_setup, in bash or zsh:
#
#   . "$SHELL_TEST_ROOT/test/lib.sh"; t_setup
#   . "$SHELL_TEST_ROOT/test/support/git_toolkit.sh"
#
# Provides (all state lives under $HOME, which t_setup points at a throwaway directory):
#   gt_init <dir>                 new repository on branch main, fixed identity, no signing, no hooks
#   gt_commit <msg> [file [text]] commit (touching <file>, default a unique one) at a fixed, increasing date
#   gt_remote [name]              bare repository $HOME/<name>.git (default origin) wired up and pushed
#   gt_fake_fzf                   fake fzf on PATH (see below) and the env that makes the toolkit use it
#   gt_input <line>...            scripted answers for prompts and numbered choices (SHELL_GIT_INPUT)
#   gt_git_counter [on|off]       a `git` shim on PATH that logs every call to $GT_GIT_LOG
#   gt_count [subcommand]         number of logged git calls (optionally only that subcommand)
#   gt_snapshot                   one text blob: HEAD, branch, status, refs, stash list; equal before/after = unchanged
#   gt_fixtures_odd_names         files with spaces, tabs, quotes, unicode, a leading dash, a glob and a newline
#
# Fake fzf: FAKE_FZF_PICKS holds one block per fzf call, blocks separated by a line `---`. Each line of a block
# selects the record whose visible text (hidden first field and ANSI removed) equals it, else contains it.
# `@all` selects every record, `@first` the first, `@rc=N` exits N printing nothing; an empty block exits 130
# (esc). A single block (no `---`) answers every call. stdin and arguments of call N are kept in $FAKE_FZF_DIR/stdin.N and args.N.

gt_init() {
	mkdir -p "$1" && cd "$1" || return 1
	git init -q . 2>/dev/null
	git symbolic-ref HEAD refs/heads/main
	git config user.email "t@example.com"
	git config user.name "T"
	git config commit.gpgsign false
	git config core.hooksPath /dev/null
	git config advice.detachedHead false
	GT_TICK=0
}

gt_commit() {
	local msg="$1" file="${2-}" text="${3-}" ts
	GT_TICK=$((${GT_TICK:-0} + 1))
	[ -n "$file" ] || file="file$GT_TICK.txt"
	[ -n "$text" ] || text="content $GT_TICK"
	printf '%s\n' "$text" >"$file"
	git add -- "$file"
	ts="@$((1577880000 + GT_TICK * 3600)) +0000"
	GIT_AUTHOR_DATE="$ts" GIT_COMMITTER_DATE="$ts" git commit -q -m "$msg"
}

gt_remote() {
	local name="${1:-origin}"
	git init -q --bare "$HOME/$name.git" 2>/dev/null
	git remote add "$name" "$HOME/$name.git"
	git push -q -u "$name" main 2>/dev/null
}

gt_input() {
	SHELL_GIT_INPUT="$HOME/gt-input.txt"
	export SHELL_GIT_INPUT
	: >"$SHELL_GIT_INPUT"
	local line
	for line in "$@"; do printf '%s\n' "$line" >>"$SHELL_GIT_INPUT"; done
	_SHELL_GIT_INPUT_OPEN=""
}

gt_fake_fzf() {
	mkdir -p "$HOME/gt-bin"
	cat >"$HOME/gt-bin/fzf" <<'FAKE'
#!/bin/sh
case "$1" in --version) echo "0.64.0 (fake)"; exit 0 ;; esac
dir="${FAKE_FZF_DIR:?}"
n="$(cat "$dir/count" 2>/dev/null || echo 0)"; n=$((n + 1)); echo "$n" >"$dir/count"
read0=""; print0=""
for a in "$@"; do case "$a" in --read0) read0=1 ;; --print0) print0=1 ;; esac; done
printf '%s\n' "$@" >"$dir/args.$n"
if [ -n "$read0" ]; then cat >"$dir/raw.$n"; tr '\0' '\n' <"$dir/raw.$n" >"$dir/stdin.$n"; else cat >"$dir/stdin.$n"; fi
bn="$n"
# A single block (no `---` line) answers every call.
printf '%s\n' "${FAKE_FZF_PICKS-}" | grep -qx -- '---' || bn=1
block="$(printf '%s\n' "${FAKE_FZF_PICKS-}" | awk -v n="$bn" 'BEGIN { c = 1 } /^---$/ { c++; next } c == n { print }')"
[ -z "$block" ] && exit 130
case "$block" in @rc=*) exit "${block#@rc=}" ;; esac
# Records with embedded newlines (paths) cannot be matched line by line: @all hands back the raw input.
if [ "$block" = "@all" ] && [ -n "$read0" ] && [ -n "$print0" ]; then cat "$dir/raw.$n"; exit 0; fi
esc="$(printf '\033')"
sed "s/$esc\\[[0-9;]*[A-Za-z]//g" "$dir/stdin.$n" >"$dir/plain.$n"
printf '%s\n' "$block" | while IFS= read -r want; do
	[ -z "$want" ] && continue
	case "$want" in
	@all) cat "$dir/stdin.$n" ;;
	@first) head -n 1 "$dir/stdin.$n" ;;
	*)
		# visible text = everything after the first unit separator (octal 037); exact match first, then substring
		ln="$(awk -v w="$want" '{ v = $0; sub(/^[^\037]*\037/, "", v); if (v == w) { print NR; exit } }' "$dir/plain.$n")"
		[ -z "$ln" ] && ln="$(awk -v w="$want" '{ v = $0; sub(/^[^\037]*\037/, "", v); if (index(v, w) > 0) { print NR; exit } }' "$dir/plain.$n")"
		[ -n "$ln" ] && sed -n "${ln}p" "$dir/stdin.$n"
		;;
	esac
done | if [ -n "$print0" ]; then tr '\n' '\0'; else cat; fi
exit 0
FAKE
	chmod +x "$HOME/gt-bin/fzf"
	FAKE_FZF_DIR="$HOME/gt-fzf"
	mkdir -p "$FAKE_FZF_DIR"
	find "$FAKE_FZF_DIR" -type f -delete
	export FAKE_FZF_DIR FAKE_FZF_PICKS="" SHELL_GIT_FORCE_FZF=1
	case ":$PATH:" in *":$HOME/gt-bin:"*) ;; *) PATH="$HOME/gt-bin:$PATH" ;; esac
	export PATH
	_SHELL_GIT_VER_FZF=""
}

gt_git_counter() {
	local real
	if [ "${1:-on}" = "off" ]; then
		PATH="${PATH#"$HOME"/gt-shim:}"
		return 0
	fi
	# Resolve the real git with the shim directory out of the way (turning it on twice must not loop).
	PATH="${PATH#"$HOME"/gt-shim:}"
	real="$(command -v git)"
	mkdir -p "$HOME/gt-shim"
	GT_GIT_LOG="$HOME/gt-git.log"
	export GT_GIT_LOG
	: >"$GT_GIT_LOG"
	printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "$GT_GIT_LOG"\nexec %s "$@"\n' "$real" >"$HOME/gt-shim/git"
	chmod +x "$HOME/gt-shim/git"
	case ":$PATH:" in *":$HOME/gt-shim:"*) ;; *) PATH="$HOME/gt-shim:$PATH" ;; esac
	export PATH
}

gt_count() {
	if [ -n "${1-}" ]; then
		awk -v s="$1" '{ for (i = 1; i <= NF; i++) if ($i !~ /^-/ ) { if ($i == s) c++; break } } END { print c + 0 }' "$GT_GIT_LOG"
	else
		wc -l <"$GT_GIT_LOG" | tr -d ' '
	fi
}

gt_snapshot() {
	{
		git rev-parse HEAD 2>&1
		git symbolic-ref -q HEAD 2>&1
		git status --porcelain=v1 2>&1
		git for-each-ref 2>&1
		git stash list 2>&1
	}
}

gt_fixtures_odd_names() {
	printf 'a\n' >"with space.txt"
	printf 'a\n' >"with	tab.txt"
	printf 'a\n' >"it's \"quoted\".txt"
	printf 'a\n' >"unicodé-日本.txt"
	printf 'a\n' >"-leading-dash.txt"
	printf 'a\n' >"glob[*]?.txt"
	printf 'a\n' >"new
line.txt"
}
