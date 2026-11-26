#!/usr/bin/env bash
# @file lang/git/index.sh
# @brief Loader and manifest of the Git toolkit: one stub per public function, real code loaded on first use.
# @description
#   Layout: `lang/git/<group>/<action>.sh` holds exactly one public function `shell::git::<group>::<action>`;
#   `lang/git/_core/*.sh` holds the private helpers `_shell::git::core::*`.
#
#   Every line below is the manifest: the stub of a public function and the file it loads. Nothing is globbed,
#   so a stray file is never executed and the load order is fixed. On the first call of a stub, the `_core`
#   files are sourced once, then the action file, then the call is repeated with the same arguments and
#   standard streams, and its exit status is returned. `declare -F`/`type` report the stub as a function from
#   the first moment.
#
#   Contributor rule: no command substitutions, external commands, file reads or network at the top level of
#   any file here. A file defines functions and nothing else.
#
#   Not part of this toolkit yet (backlog): branch::{rename,worktree,merged,stale,prune}, commit::{edit,undo,
#   split,reword,cherry-pick}, stage::{diff,reset,partial,restore}, log::{range,contributors,recent,bisect},
#   remote::{ahead,behind,tracking,url,pick}, stash::{pop,diff,branch}, repo::{large,orphans,integrity,
#   conflicts,contributors,activity}, flow::{finish,update,prune,publish}.
#
#   Names that already exist elsewhere in the library are kept as they are, not redefined: `branch::sync`
#   (syncs local branches with origin) and `commit::amend`.

# @internal
# @description Source the private helpers (`_core/*.sh`) once, in a fixed order.
# @exitcode 0 Loaded.
# @exitcode 1 A helper file failed to load.
# @example
#   _shell::git::core::boot
#
_shell::git::core::boot() {
	local root="${_SHELL_LAZY_ROOT:-$SHELL_SRC_DIR}/lang/git" name
	[ "${_SHELL_GIT_BOOTED-}" = "1" ] && return 0
	for name in env version state ui fzf confirm backup refs branch commit stage log remote stash repo flow; do
		# shellcheck source=/dev/null
		source "$root/_core/$name.sh" || {
			printf 'shell: failed to load %s\n' "$root/_core/$name.sh" >&2
			return 1
		}
	done
	_SHELL_GIT_BOOTED=1
	return 0
}

# @internal
# @description Stub body: load the toolkit helpers and the action file, then run the function again.
# @arg $1 string Action file without extension, relative to lang/git (for example `branch/pick`).
# @arg $2 string The public function name.
# @arg $@ string The caller's arguments, passed through unchanged.
# @exitcode * The function's own; 127 when the file does not define it; 1 when a file failed to load.
# @example
#   _shell::git::core::lazy branch/pick shell::git::branch::pick "$@"
#
_shell::git::core::lazy() {
	local rel="$1" fn="$2" root="${_SHELL_LAZY_ROOT:-$SHELL_SRC_DIR}/lang/git"
	shift 2
	_shell::git::core::boot || return 1
	case "${_SHELL_GIT_LOADED-}" in
	*"|$rel|"*)
		printf 'shell: %s is not defined by %s.sh\n' "$fn" "$rel" >&2
		return 127
		;;
	esac
	_SHELL_GIT_LOADED="${_SHELL_GIT_LOADED:-|}$rel|"
	# shellcheck source=/dev/null
	source "$root/$rel.sh" || {
		printf 'shell: failed to load %s\n' "$root/$rel.sh" >&2
		return 1
	}
	"$fn" "$@"
}

# --- manifest: branch
# @description Fuzzy-pick a local or remote branch and print its name.
#   Loaded on first call from lang/git/branch/pick.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::branch::pick -h
#
shell::git::branch::pick() { _shell::git::core::lazy branch/pick shell::git::branch::pick "$@"; }

# @description Pick among the branches you checked out recently.
#   Loaded on first call from lang/git/branch/recent.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::branch::recent -h
#
shell::git::branch::recent() { _shell::git::core::lazy branch/recent shell::git::branch::recent "$@"; }

# @description Delete merged local branches after a multi-select, a summary and a confirmation.
#   Loaded on first call from lang/git/branch/cleanup.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::branch::cleanup -h
#
shell::git::branch::cleanup() { _shell::git::core::lazy branch/cleanup shell::git::branch::cleanup "$@"; }

# @description Compare two branches: ahead/behind counts, commits on each side, changed files.
#   Loaded on first call from lang/git/branch/compare.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::branch::compare -h
#
shell::git::branch::compare() { _shell::git::core::lazy branch/compare shell::git::branch::compare "$@"; }

# --- manifest: commit
# @description Fuzzy-pick a commit and print its hash.
#   Loaded on first call from lang/git/commit/pick.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::commit::pick -h
#
shell::git::commit::pick() { _shell::git::core::lazy commit/pick shell::git::commit::pick "$@"; }

# @description Create a fixup commit for a picked commit and autosquash it, with a backup ref.
#   Loaded on first call from lang/git/commit/fixup.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::commit::fixup -h
#
shell::git::commit::fixup() { _shell::git::core::lazy commit/fixup shell::git::commit::fixup "$@"; }

# @description Squash a range of commits into one, with a backup ref.
#   Loaded on first call from lang/git/commit/squash.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::commit::squash -h
#
shell::git::commit::squash() { _shell::git::core::lazy commit/squash shell::git::commit::squash "$@"; }

# @description Revert one or several picked commits, in the right order.
#   Loaded on first call from lang/git/commit/revert.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::commit::revert -h
#
shell::git::commit::revert() { _shell::git::core::lazy commit/revert shell::git::commit::revert "$@"; }

# --- manifest: stage
# @description Pick files to stage, with staged and unstaged state shown separately.
#   Loaded on first call from lang/git/stage/pick.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::stage::pick -h
#
shell::git::stage::pick() { _shell::git::core::lazy stage/pick shell::git::stage::pick "$@"; }

# @description Stage hunks interactively with git add -p.
#   Loaded on first call from lang/git/stage/patch.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::stage::patch -h
#
shell::git::stage::patch() { _shell::git::core::lazy stage/patch shell::git::stage::patch "$@"; }

# @description Pick staged files and unstage them.
#   Loaded on first call from lang/git/stage/unstage.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::stage::unstage -h
#
shell::git::stage::unstage() { _shell::git::core::lazy stage/unstage shell::git::stage::unstage "$@"; }

# @description Discard working-tree changes of picked files, after a recoverable snapshot.
#   Loaded on first call from lang/git/stage/discard.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::stage::discard -h
#
shell::git::stage::discard() { _shell::git::core::lazy stage/discard shell::git::stage::discard "$@"; }

# --- manifest: log
# @description Browse history in fzf with preview and key bindings.
#   Loaded on first call from lang/git/log/pick.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::log::pick -h
#
shell::git::log::pick() { _shell::git::core::lazy log/pick shell::git::log::pick "$@"; }

# @description Search history by message, added/removed string or regex.
#   Loaded on first call from lang/git/log/search.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::log::search -h
#
shell::git::log::search() { _shell::git::core::lazy log/search shell::git::log::search "$@"; }

# @description Show the history of one file, following renames.
#   Loaded on first call from lang/git/log/file.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::log::file -h
#
shell::git::log::file() { _shell::git::core::lazy log/file shell::git::log::file "$@"; }

# @description Print a compact decorated commit graph.
#   Loaded on first call from lang/git/log/graph.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::log::graph -h
#
shell::git::log::graph() { _shell::git::core::lazy log/graph shell::git::log::graph "$@"; }

# @description Blame a file or a line range interactively.
#   Loaded on first call from lang/git/log/blame.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::log::blame -h
#
shell::git::log::blame() { _shell::git::core::lazy log/blame shell::git::log::blame "$@"; }

# --- manifest: remote
# @description Sync the current branch with its upstream (fast-forward, merge or rebase).
#   Loaded on first call from lang/git/remote/sync.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::remote::sync -h
#
shell::git::remote::sync() { _shell::git::core::lazy remote/sync shell::git::remote::sync "$@"; }

# @description Compare local branches with their remote counterparts.
#   Loaded on first call from lang/git/remote/compare.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::remote::compare -h
#
shell::git::remote::compare() { _shell::git::core::lazy remote/compare shell::git::remote::compare "$@"; }

# @description Fetch from a picked remote, pruning only when asked.
#   Loaded on first call from lang/git/remote/fetch.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::remote::fetch -h
#
shell::git::remote::fetch() { _shell::git::core::lazy remote/fetch shell::git::remote::fetch "$@"; }

# @description Prune stale remote-tracking branches after a dry-run preview.
#   Loaded on first call from lang/git/remote/prune.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::remote::prune -h
#
shell::git::remote::prune() { _shell::git::core::lazy remote/prune shell::git::remote::prune "$@"; }

# --- manifest: stash
# @description Pick a stash entry and print its reference.
#   Loaded on first call from lang/git/stash/pick.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::stash::pick -h
#
shell::git::stash::pick() { _shell::git::core::lazy stash/pick shell::git::stash::pick "$@"; }

# @description Save the working tree to a named stash.
#   Loaded on first call from lang/git/stash/save.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::stash::save -h
#
shell::git::stash::save() { _shell::git::core::lazy stash/save shell::git::stash::save "$@"; }

# @description Apply a picked stash and keep it.
#   Loaded on first call from lang/git/stash/apply.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::stash::apply -h
#
shell::git::stash::apply() { _shell::git::core::lazy stash/apply shell::git::stash::apply "$@"; }

# @description Drop a picked stash after a confirmation, printing its hash.
#   Loaded on first call from lang/git/stash/drop.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::stash::drop -h
#
shell::git::stash::drop() { _shell::git::core::lazy stash/drop shell::git::stash::drop "$@"; }

# --- manifest: repo
# @description Report the health of the repository: state, divergence, branches, stashes, conflicts.
#   Loaded on first call from lang/git/repo/health.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::repo::health -h
#
shell::git::repo::health() { _shell::git::core::lazy repo/health shell::git::repo::health "$@"; }

# @description Print commit, author and date-range statistics from one log pass.
#   Loaded on first call from lang/git/repo/stats.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::repo::stats -h
#
shell::git::repo::stats() { _shell::git::core::lazy repo/stats shell::git::repo::stats "$@"; }

# @description Report object, pack and working-tree sizes.
#   Loaded on first call from lang/git/repo/size.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::repo::size -h
#
shell::git::repo::size() { _shell::git::core::lazy repo/size shell::git::repo::size "$@"; }

# @description Print a compact summary of the repository.
#   Loaded on first call from lang/git/repo/summary.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::repo::summary -h
#
shell::git::repo::summary() { _shell::git::core::lazy repo/summary shell::git::repo::summary "$@"; }

# --- manifest: flow
# @description Start a feature branch from the base branch.
#   Loaded on first call from lang/git/flow/feature.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::flow::feature -h
#
shell::git::flow::feature() { _shell::git::core::lazy flow/feature shell::git::flow::feature "$@"; }

# @description Start a release branch from the release base.
#   Loaded on first call from lang/git/flow/release.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::flow::release -h
#
shell::git::flow::release() { _shell::git::core::lazy flow/release shell::git::flow::release "$@"; }

# @description Start a hotfix branch from the base branch.
#   Loaded on first call from lang/git/flow/hotfix.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::flow::hotfix -h
#
shell::git::flow::hotfix() { _shell::git::core::lazy flow/hotfix shell::git::flow::hotfix "$@"; }

# @description Integrate the base branch into the current branch (merge or rebase).
#   Loaded on first call from lang/git/flow/sync.sh; see that file for the full documentation.
# @arg $@ string Arguments of the function (`-h` shows its usage).
# @exitcode 0 Success.
# @example
#   shell::git::flow::sync -h
#
shell::git::flow::sync() { _shell::git::core::lazy flow/sync shell::git::flow::sync "$@"; }
