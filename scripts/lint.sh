#!/usr/bin/env bash
# Repository lint: everything CI checks, runnable locally via `make lint`.
#
# Checks (each prints PASS/FAIL):
#   syntax       bash -n (and zsh -n when installed) on every .sh file
#   naming       every function is shell::<category>::... (src/shell.sh exempt)
#   shdoc        every function has an @description block; shdoc can render it
#   zsh-names    no `local path|status|options|...` (read-only/special in zsh)
#   portability  no bash>=4-only syntax, GNU-only flags, BASH_REMATCH, echo -e
#   constants    no top-level assignments outside src/constant (except the loader)
#   no-exit      library functions must `return`, never `exit`
#   static-analysis  (when installed) shellcheck with .shellcheckrc
#   shfmt        (when installed) formatting is canonical
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
fails=0
files="$(find src test scripts -name '*.sh' | sort) install.sh upgrade.sh uninstall.sh"
src_files="$(find src -name '*.sh' | sort)"

report() { # name status [detail]
	if [ "$2" = "ok" ]; then printf 'PASS  %s\n' "$1"; else
		printf 'FAIL  %s\n' "$1"
		[ -n "${3-}" ] && printf '%s\n' "$3" | sed 's/^/        /' | head -15
		fails=$((fails + 1))
	fi
}
grep_fail() { # name pattern [files] [exclude-regex]
	local out
	# shellcheck disable=SC2086
	out="$(grep -rnE -- "$2" ${3:-$src_files} 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | grep -vE "${4:-^\$NEVER}")"
	[ -z "$out" ] && report "$1" ok || report "$1" fail "$out"
}

# syntax
out=""
for f in $files; do bash -n "$f" 2>&1 || out="$out$f"$'\n'; done
if command -v zsh >/dev/null 2>&1; then for f in $src_files; do zsh -n "$f" 2>&1 || out="$out(zsh) $f"$'\n'; done; fi
[ -z "$out" ] && report syntax ok || report syntax fail "$out"

# naming
# shellcheck disable=SC2046  # the file list is intentionally word-split
out="$(grep -rhoE '^(function )?shell::[A-Za-z0-9_:]+\(\)' $(find src -name '*.sh' ! -path src/shell.sh) | sed 's/^function //; s/()//' |
	grep -vE '^shell::[a-z0-9_]+::[a-z0-9_:]+$')"
[ -z "$out" ] && report naming ok || report naming fail "$out"
out="$(grep -rnoE '^[A-Za-z_][A-Za-z0-9_]*\(\)' src --include=*.sh | grep -v 'shell::')"
[ -z "$out" ] && report naming-global-funcs ok || report naming-global-funcs fail "$out"

# shdoc
out="$(
	for f in $src_files; do
		awk -v f="$f" '
			/^shell::[A-Za-z0-9_:]+\(\)/ { if (!doc) print f ": " $1; doc = 0; next }
			/^# @description/ { doc = 1 }
			!/^#/ { doc = 0 }' "$f"
	done
)"
[ -z "$out" ] && report shdoc-coverage ok || report shdoc-coverage fail "$out"

# zsh-reserved names
grep_fail zsh-names '^[[:space:]]*local (-[a-zA-Z]+ )?(path|status|options|commands|functions|aliases|parameters|argv|reply|pipestatus)([ =]|$)'

# portability
grep_fail portability-bash4 'declare -A|local -A|mapfile|readarray|local -n [A-Za-z_]+=|declare -n [A-Za-z_]+=|\$\{[A-Za-z_0-9]+(,,|\^\^)|wait -n|\[\[ -v '
grep_fail portability-gnu '(^|[^_a-z])sed -i|readlink -f|date -d|base64 -w|grep -[a-zA-Z]*P |xargs -r|find .*-printf|(^|[^a-z])stat (-c|--format)|ps .*--sort' "$src_files" 'sed_inplace|shellbak|lib/fs\.sh|date -v|homebrew\.sh'
grep_fail portability-shell 'echo -e|echo -en|BASH_REMATCH|\$\{![A-Za-z_]|read -[a-z]*a '

# constants
# shellcheck disable=SC2046
out="$(grep -nE '^[A-Z][A-Z0-9_]*=' $(find src -name '*.sh' ! -path 'src/constant/*' ! -path src/shell.sh) 2>/dev/null)"
[ -z "$out" ] && report constants ok || report constants fail "$out"

# no exit in functions
grep_fail no-exit '^[[:space:]]+exit[[:space:]]' "$src_files"

if command -v shellcheck >/dev/null 2>&1; then
	out="$(shellcheck -x -S warning $files 2>&1 | grep -E '^(In |.*SC[0-9]+)' | head -20)"
	[ -z "$out" ] && report shellcheck ok || report shellcheck fail "$out"
else printf 'SKIP  shellcheck (not installed)\n'; fi

if command -v shfmt >/dev/null 2>&1; then
	out="$(shfmt -l $files 2>&1)"
	[ -z "$out" ] && report shfmt ok || report shfmt fail "needs formatting (run: make fmt):
$out"
else printf 'SKIP  shfmt (not installed)\n'; fi

printf '\n%s check(s) failed\n' "$fails"
[ "$fails" -eq 0 ]
