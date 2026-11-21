# Read by the ssh host preview of shell::zsh::ssh::host::pick::fzf; never sourced.
#   awk -v host=<alias> -f zsh-ssh-block.awk ~/.ssh/config
# Prints the `Host` block that defines <alias> (up to the next Host or Match line).
{
	line = $0
	sub(/^[ \t]+/, "", line)
	key = line
	sub(/[ \t=].*$/, "", key)
	key = tolower(key)
	if (key == "host" || key == "match") {
		if (inblock) exit
		if (key == "host") {
			rest = line
			sub(/^[^ \t=]+[ \t]*=?[ \t]*/, "", rest)
			sub(/[ \t]*#.*$/, "", rest)
			n = split(rest, pat, /[ \t]+/)
			for (i = 1; i <= n; i++) if (pat[i] == host) inblock = 1
		}
	}
	if (inblock) print $0
}
