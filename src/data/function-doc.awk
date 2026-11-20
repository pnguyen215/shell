# Function documentation renderer: turns the shdoc block of one function into readable text.
#
# Used by shell::function::info and by the explorer's preview panel (which runs outside the library,
# so this is a standalone program). Reads the documentation block (the `#` lines above the function) on
# stdin and prints a short reference page. Nothing is guessed: only what the block says is shown.
#
# -v name    fully qualified function name
# -v vis     public | internal
# -v category  the namespace (git, ssh, ...)
# -v loaded  yes | no
# -v file    source file, relative to the library root (`-` when unknown)
# -v line    line of the definition
# -v color   1 to use ANSI bold for headings
function bold(s) { return color == "1" ? "\033[1m" s "\033[0m" : s }
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function add(sec, s) { body[sec] = body[sec] s "\n"; used[sec] = 1 }
function show(sec, title) {
	if (!used[sec]) return
	print ""
	print bold(title)
	printf "%s", body[sec]
}

BEGIN {
	cur = ""
	if (category == "") {
		bare = name
		sub(/^_/, "", bare)
		k = split(bare, parts, "::")
		category = (k >= 3) ? parts[2] : "shell"
	}
}

{
	l = $0
	if (l !~ /^#/) next
	sub(/^#/, "", l)
	if (l ~ /^ @[a-z]+/) {
		tag = l
		sub(/^ @/, "", tag)
		rest = tag
		sub(/^[a-z]+[ \t]*/, "", rest)
		sub(/[ \t].*$/, "", tag)
		rest = trim(rest)
		last = ""
		if (tag == "description") { cur = "desc"; if (rest != "") add("desc", "  " rest) }
		else if (tag == "option") { cur = "opt"; last = "opt"; add("opt", "  " rest) }
		else if (tag == "arg") { cur = "arg"; last = "arg"; add("arg", "  " rest) }
		else if (tag == "noargs") { cur = ""; add("arg", "  (none)") }
		else if (tag == "exitcode") { cur = "exit"; last = "exit"; add("exit", "  " rest) }
		else if (tag == "stdout") { cur = "io"; add("io", "  stdout  " rest) }
		else if (tag == "stderr") { cur = "io"; add("io", "  stderr  " rest) }
		else if (tag == "stdin") { cur = "io"; add("io", "  stdin   " rest) }
		else if (tag == "set") { cur = "io"; add("io", "  sets    " rest) }
		else if (tag == "env") { cur = "io"; add("io", "  env     " rest) }
		else if (tag == "see") { cur = ""; add("see", "  " rest) }
		else if (tag == "example") { cur = "ex"; if (rest != "") add("ex", "  " rest) }
		else cur = ""
		next
	}
	# a lone `#`: a paragraph break in the description, the end of an example
	if (l ~ /^[ \t]*$/) {
		if (cur == "desc" && used["desc"]) add("desc", "")
		else if (cur == "ex") cur = ""
		next
	}
	sub(/^ ?/, "", l)
	if (cur == "desc") add("desc", "  " trim(l))
	else if (cur == "ex") { sub(/^  /, "", l); add("ex", "  " l) }
	else if (cur == "opt" || cur == "arg" || cur == "exit") add(cur, "      " trim(l))
	else if (cur == "io") add("io", "          " trim(l))
}

END {
	print bold(name)
	print "  " vis " | " category " | " (loaded == "yes" ? "loaded" : "not loaded")
	if (file != "-" && file != "") print "  " file ":" line
	if (!used["desc"] && !used["opt"] && !used["arg"] && !used["ex"]) {
		print ""
		print "  (no documentation block above this function)"
		exit
	}
	sub(/\n+$/, "\n", body["desc"])
	show("desc", "DESCRIPTION")
	show("opt", "OPTIONS")
	show("arg", "ARGUMENTS")
	show("io", "INPUT / OUTPUT")
	show("exit", "EXIT CODES")
	show("see", "SEE ALSO")
	show("ex", "EXAMPLES")
}
