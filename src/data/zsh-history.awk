# Read by shell::zsh::history::search::fzf (via _shell::zsh::history::candidates); never sourced.
#
#   -v mode=list   input is the output of `fc -rl 1` (zsh) or `history` (bash): "  <id>  <command>"
#   -v mode=file   input is a history file: plain lines, or zsh's `: <time>:<dur>;<command>` form
#   -v rev=1       input is oldest first (bash history, files); 0 = newest first (zsh fc -r)
#   -v limit=N     most entries printed          -v mark=<text>   stands for a line break inside an entry
#
# Output, newest first, every command once (its most recent use): <id> TAB <command>
# In `list` mode <id> is the history event number; in `file` mode the line the entry starts on.

function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function add(id, cmd) {
	cmd = trim(cmd)
	if (cmd == "") return
	n++
	ids[n] = id
	cmds[n] = cmd
}

mode == "list" {
	if (match($0, /^[ ]*[0-9]+\*?[ ]+/)) {
		head = substr($0, RSTART, RLENGTH)
		gsub(/[^0-9]/, "", head)
		cur = 1
		start = head
		add(head, substr($0, RSTART + RLENGTH))
	} else if (cur && n > 0) {
		cmds[n] = cmds[n] mark trim($0)
	}
	next
}

mode == "file" {
	if ($0 ~ /^#[0-9]+$/) next              # bash HISTTIMEFORMAT stamp
	if (cont) {                              # the previous line ended with a backslash
		cmds[n] = cmds[n] mark $0
	} else {
		line = $0
		if (line ~ /^: [0-9]+:[0-9]+;/) sub(/^: [0-9]+:[0-9]+;/, "", line)
		add(NR, line)
	}
	cont = ($0 ~ /\\$/ && n > 0)
	if (cont) sub(/\\$/, "", cmds[n])
	next
}

END {
	out = 0
	for (k = 1; k <= n; k++) {
		i = rev ? n - k + 1 : k
		if (cmds[i] in seen) continue
		seen[cmds[i]] = 1
		print ids[i] "\t" cmds[i]
		if (++out >= limit) break
	}
}
