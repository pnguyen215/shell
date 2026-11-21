# Read by shell::zsh::install (src/lib/zsh.sh); never sourced.
#
#   awk -v mode=dir     -v home=<$HOME>                         -f zsh-hook.awk < rc   print the directory of the first hook
#   awk -v mode=rewrite -v begin=<B> -v end=<E> -v dir=<D> ...  -f zsh-hook.awk < rc   print rc with ONE marked hook for <D>
#
# A "hook" is the marked block (begin ... end) or a legacy unmarked `source .../src/shell.sh` line
# (the same lines uninstall.sh removes). Rewrite keeps every other line exactly as it is:
#   * the first hook (block or legacy line) is replaced in place by the marked block;
#   * further hooks are dropped, so there are no duplicates;
#   * with no hook the block is appended after one blank line;
#   * a block that is never closed exits with status 3 (nothing is guessed).

function trim_end(s) { sub(/[ \t\r]+$/, "", s); return s }

# A non-comment line that sources src/shell.sh.
function is_legacy(s) {
	if (s ~ /^[ \t]*#/ || index(s, "src/shell.sh") == 0) return 0
	return (s ~ /(^|[^A-Za-z0-9_])source[ \t]+/ || s ~ /(^|[;&|])[ \t]*\.[ \t]+[^ \t]/)
}

# The installation directory named by such a line, with ~ and $HOME expanded.
function extract(s,   t) {
	if (match(s, /(^|[^A-Za-z0-9_])source[ \t]+/)) t = substr(s, RSTART + RLENGTH)
	else if (match(s, /(^|[;&|])[ \t]*\.[ \t]+/)) t = substr(s, RSTART + RLENGTH)
	else return ""
	sub(/src\/shell\.sh.*$/, "", t)
	gsub(/["\047]/, "", t)
	sub(/\/+$/, "", t)
	if (t ~ /^~\//) t = home substr(t, 2)
	else if (t ~ /^\$HOME\//) t = home substr(t, 6)
	else if (t ~ /^\$\{HOME\}\//) t = home substr(t, 8)
	return t
}

function emit() {
	print begin
	print "source \"" dir "/src/shell.sh\""
	print end
	done = 1
}

mode == "dir" {
	if (is_legacy($0)) { print extract($0); exit }
	next
}

mode == "rewrite" {
	line = trim_end($0)
	if (inblock) {
		if (line == end) inblock = 0
		next
	}
	if (line == begin) {
		inblock = 1
		if (!done) emit()
		next
	}
	if (is_legacy($0)) {
		if (!done) emit()
		next
	}
	printed = $0
	has_printed = 1
	print
}

END {
	if (mode != "rewrite") exit
	if (inblock) exit 3
	if (!done) {
		if (has_printed && printed != "") print ""
		emit()
	}
}
