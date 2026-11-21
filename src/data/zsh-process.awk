# Read by shell::zsh::process::kill::fzf (and by its ctrl-r reload); never sourced.
#   ps -A -o pid=,user=,pcpu=,pmem=,comm= | awk -v me=<pid> -f zsh-process.awk
# Output: <pid> TAB <display row>; the pid is the payload, the row is what fzf shows.
# <me> (the shell that runs the picker) is hidden so it is not killed by accident.
{
	pid = $1
	if (pid == me || pid !~ /^[0-9]+$/) next
	cmd = $0
	for (i = 1; i <= 4; i++) sub(/^[ \t]*[^ \t]+/, "", cmd)
	sub(/^[ \t]+/, "", cmd)
	if (cmd == "") next
	printf "%s\t%7s %-12s %5s %5s  %s\n", pid, pid, $2, $3, $4, cmd
}
