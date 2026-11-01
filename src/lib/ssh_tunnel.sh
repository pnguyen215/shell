#!/usr/bin/env bash
# @file lib/ssh_tunnel.sh
# @brief SSH port forwarding: local (-L), remote (-R) and SOCKS (-D), by host or alias.
# @description
#   Complements `shell::ssh::tunnel::open` (lib/ssh.sh), which builds one `-L` tunnel
#   from seven fixed arguments, with these three that take any target (user@host or
#   an alias of `~/.ssh/config`, jump hosts included) and the same options as the
#   other ssh commands.
#
#   Things worth knowing:
#
#   * The tunnel runs as `ssh -N -T -f ...`: no remote command, no terminal, and ssh
#     goes to the background once the forward is established. `--foreground` keeps it
#     in this terminal (Ctrl-C stops it).
#   * `ExitOnForwardFailure=yes` makes ssh fail at once when it cannot bind the port,
#     instead of staying connected without a tunnel; `ServerAliveInterval` and
#     `ServerAliveCountMax` (SHELL_SSH_KEEPALIVE_INTERVAL, SHELL_SSH_KEEPALIVE_COUNT)
#     end it when the link dies. `--keepalive` overrides the interval.
#   * A background tunnel shows up in `shell::ssh::tunnel::list` and is stopped with
#     `shell::ssh::tunnel::kill` or `shell::ssh::tunnel::kill::fzf`.
#   * Forwards bind to 127.0.0.1 unless the spec starts with a bind address
#     (`0.0.0.0:8080:host:80` opens it to your network: be sure you want that). A
#     remote bind other than localhost also needs `GatewayPorts` on the server.
#   * A spec can end in a Unix socket path instead of `host:port`
#     (`3307:/var/run/mysqld/mysqld.sock`).

# @description Forward a local port to a service the server can reach (`ssh -L`).
#   `localhost:<port>` on this machine becomes the entry to `host:hostport` as seen
#   from the server (a database, an admin page ...).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --foreground Keep the tunnel in this terminal.
# @option --keepalive <sec> Keep-alive interval.
# @arg $1 string The target.
# @arg $2 string The spec: `[bind:]port:host:hostport` or `[bind:]port:/socket`.
# @exitcode 0 The tunnel is up (or the dry run printed).
# @exitcode 2 Unknown option, wrong arguments, or an unsafe argument.
# @exitcode 3 ssh is missing.
# @exitcode N Exit status of ssh (255 when it cannot connect or bind).
# @see shell::ssh::cmd
# @see shell::ssh::tunnel::open
# @example
#   shell::ssh::tunnel::local deploy@bastion 5432:db.internal:5432
#   shell::ssh::tunnel::local -J bastion deploy@app1 3307:127.0.0.1:3306
#
shell::ssh::tunnel::local() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Forward a local port to a service the server can reach (ssh -L)"
		shell::logger::usage "shell::ssh::tunnel::local [-n] [options] <[user@]host|alias> <[bind:]port:host:hostport>"
		shell::logger::item "target" "The SSH server (user@host, host or an alias)"
		shell::logger::item "spec" "local port, then the destination as seen from the server"
		shell::ssh::cmd::help ssh
		shell::logger::option "--foreground" "Keep the tunnel in this terminal instead of the background"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::tunnel::local deploy@bastion 5432:db.internal:5432"
		shell::logger::example "shell::ssh::tunnel::local -J bastion deploy@app1 3307:127.0.0.1:3306"
		return "$RETURN_SUCCESS"
	fi
	shell::ssh::cmd ssh tunnel_local "$@"
}

# @description Expose a local service on the server (`ssh -R`).
#   `port` on the server becomes the entry to `host:hostport` as seen from this
#   machine (a webhook receiver, a dev server to show someone ...).
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --foreground Keep the tunnel in this terminal.
# @option --keepalive <sec> Keep-alive interval.
# @arg $1 string The target.
# @arg $2 string The spec: `[bind:]port:host:hostport` or `[bind:]port:/socket`.
# @exitcode 0 The tunnel is up (or the dry run printed).
# @exitcode 2 Unknown option, wrong arguments, or an unsafe argument.
# @exitcode 3 ssh is missing.
# @exitcode N Exit status of ssh (255 when it cannot connect or bind).
# @see shell::ssh::cmd
# @example
#   shell::ssh::tunnel::remote deploy@web1 9090:localhost:3000
#
shell::ssh::tunnel::remote() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Expose a local service on the server (ssh -R)"
		shell::logger::usage "shell::ssh::tunnel::remote [-n] [options] <[user@]host|alias> <[bind:]port:host:hostport>"
		shell::logger::item "target" "The SSH server (user@host, host or an alias)"
		shell::logger::item "spec" "port on the server, then the destination as seen from this machine"
		shell::ssh::cmd::help ssh
		shell::logger::option "--foreground" "Keep the tunnel in this terminal instead of the background"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::tunnel::remote deploy@web1 9090:localhost:3000"
		return "$RETURN_SUCCESS"
	fi
	shell::ssh::cmd ssh tunnel_remote "$@"
}

# @description Start a SOCKS5 proxy that sends its traffic through the server (`ssh -D`).
#   Point a browser or `curl --socks5-hostname localhost:1080` at it.
# @option -h | --help Show help and return.
# @option -n | --dry-run Print the command instead of running it.
# @option --foreground Keep the tunnel in this terminal.
# @option --keepalive <sec> Keep-alive interval.
# @arg $1 string The target.
# @arg $2 integer Local port (default 1080).
# @exitcode 0 The proxy is up (or the dry run printed).
# @exitcode 2 Unknown option, wrong arguments, or an unsafe argument.
# @exitcode 3 ssh is missing.
# @exitcode N Exit status of ssh (255 when it cannot connect or bind).
# @see shell::ssh::cmd
# @example
#   shell::ssh::tunnel::socks deploy@web1
#   shell::ssh::tunnel::socks deploy@web1 1081
#
shell::ssh::tunnel::socks() {
	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		shell::logger::reset_options
		shell::logger::info "Start a SOCKS5 proxy through the server (ssh -D)"
		shell::logger::usage "shell::ssh::tunnel::socks [-n] [options] <[user@]host|alias> [port]"
		shell::logger::item "target" "The SSH server (user@host, host or an alias)"
		shell::logger::item "port" "Local port of the proxy (default 1080)"
		shell::ssh::cmd::help ssh
		shell::logger::option "--foreground" "Keep the tunnel in this terminal instead of the background"
		shell::logger::option "-n, --dry-run" "Print the command instead of executing it"
		shell::logger::option "-h, --help" "Display this help message"
		shell::logger::example "shell::ssh::tunnel::socks deploy@web1"
		shell::logger::example "shell::ssh::tunnel::socks -J bastion deploy@web1 1081"
		return "$RETURN_SUCCESS"
	fi
	shell::ssh::cmd ssh tunnel_socks "$@"
}
