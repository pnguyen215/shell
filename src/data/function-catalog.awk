# Function catalog: one TSV record per `shell::` function, built from the shdoc blocks of the source tree.
#
# Used by _shell::function::catalog (src/lib/function.sh); this file is the ONLY place that knows how a
# function and its documentation block are recognised, which is the convention `make lint` enforces:
# a function is a line `name() {` at column 0 starting with `shell::` or `_shell::`, and its
# documentation is the block of `#` lines directly above it.
#
# Input   stdin: the source files to scan, one path per line.
# Env     SHELL_FN_LOADED: the names of the functions loaded in the current shell, one per line.
# -v      root: the library root; paths in the output are relative to it.
# Output  name  visibility  category  loaded  file  first-line  def-line  summary      (tab separated, unsorted)
#           visibility  public | internal (a leading `_` in the name)
#           category    the namespace after `shell::` (`shell` for top-level names such as shell::version)
#           loaded      yes | no (defined in the tree, not loaded in this shell)
#           file `-`    a function loaded in the session that is not in the tree (summary empty)
#           first-line  the first line of its documentation block (equal to def-line when it has none)
BEGIN {
	n = split(ENVIRON["SHELL_FN_LOADED"], names, "\n")
	for (i = 1; i <= n; i++) if (names[i] != "") loaded[names[i]] = 1
}

# Text of a `# @tag text` line after the tag, trimmed.
function after(line, skip,    t) {
	t = substr(line, skip)
	sub(/^[ \t]+/, "", t)
	sub(/[ \t\r]+$/, "", t)
	gsub(/\t/, " ", t)
	return t
}

{
	f = $0
	if (f == "") next
	rel = f
	if (index(f, root "/") == 1) rel = substr(f, length(root) + 2)
	ln = 0; prev = 0
	while ((getline line < f) > 0) {
		ln++
		if (substr(line, 1, 1) == "#") {
			if (!prev) { bs = ln; desc = ""; want = 0; hdr = 0 }
			prev = 1
			if (line ~ /^# @file/) hdr = 1
			else if (line ~ /^# @description/) {
				if (desc == "") {
					t = after(line, 15)
					if (t != "") desc = t; else want = 1
				}
			} else if (line ~ /^# @/) want = 0
			else if (want) {
				t = after(line, 2)
				if (t != "") { desc = t; want = 0 }
			}
			continue
		}
		if (line ~ /^_?shell::[A-Za-z0-9_:]+\(\)/) {
			nm = line
			sub(/\(\).*/, "", nm)
			if (!prev || hdr) { first = ln; desc = "" } else first = bs
			bare = nm
			sub(/^_/, "", bare)
			k = split(bare, p, "::")
			rec_vis[nm] = (substr(nm, 1, 1) == "_") ? "internal" : "public"
			rec_cat[nm] = (k >= 3) ? p[2] : "shell"
			rec_file[nm] = rel
			rec_first[nm] = first
			rec_line[nm] = ln
			rec_desc[nm] = desc
		}
		prev = 0
	}
	close(f)
}

END {
	for (nm in rec_vis)
		printf "%s\t%s\t%s\t%s\t%s\t%d\t%d\t%s\n", nm, rec_vis[nm], rec_cat[nm], (nm in loaded) ? "yes" : "no", rec_file[nm], rec_first[nm], rec_line[nm], rec_desc[nm]
	for (nm in loaded) {
		if (nm in rec_vis) continue
		bare = nm
		sub(/^_/, "", bare)
		k = split(bare, p, "::")
		printf "%s\t%s\t%s\tyes\t-\t0\t0\t\n", nm, (substr(nm, 1, 1) == "_") ? "internal" : "public", (k >= 3) ? p[2] : "shell"
	}
}
