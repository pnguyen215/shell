#!/usr/bin/env bash
# @file lang/git/repo/size.sh
# @brief Object, pack and tree sizes.

# @description Report how big the repository is without walking the working tree: loose objects and packs from
#   `git count-objects -v` (`-vH` on a terminal), the size of the files at HEAD from one `ls-tree -r -l`,
#   and the size of the git directory from `du -sk`. Plain mode (`--plain`, or stdout is not a terminal)
#   prints tab-separated rows with sizes in KiB (`loose_kib`, `pack_kib`, `gitdir_kib`) and bytes
#   (`tracked_bytes`). Works in a bare repository and in one without commits.
# @option --plain Tab-separated rows, sizes as numbers, no color.
# @option -h | --help Show this help.
# @stdout The sizes.
# @exitcode 0 Success.
# @exitcode 2 Invalid usage.
# @exitcode 3 Not a git repository.
# @example
#   shell::git::repo::size
#   shell::git::repo::size --plain
#
shell::git::repo::size() {
	_shell::git::core::repo_opts "$@" || return $?
	if [ "$_SHELL_GIT_RP_HELP" = "1" ]; then
		printf 'usage: shell::git::repo::size [--plain]\n'
		printf 'Object, pack and tracked-file sizes (count-objects, ls-tree, du).\n'
		return 0
	fi
	_shell::git::core::require_repo || return $?
	if [ "$_SHELL_GIT_RP_PLAIN" = "1" ]; then
		_shell::git::core::repo_size_data
		printf 'loose_objects\t%s\nloose_kib\t%s\npacked_objects\t%s\npacks\t%s\npack_kib\t%s\ngarbage\t%s\ntracked_files\t%s\ntracked_bytes\t%s\ngitdir_kib\t%s\n' \
			"$_SHELL_GIT_RP_SZ_LOOSE_COUNT" "$_SHELL_GIT_RP_SZ_LOOSE" "$_SHELL_GIT_RP_SZ_PACKED_COUNT" "$_SHELL_GIT_RP_SZ_PACKS" "$_SHELL_GIT_RP_SZ_PACK" \
			"$_SHELL_GIT_RP_SZ_GARBAGE" "$_SHELL_GIT_RP_SZ_TRACKED_FILES" "$_SHELL_GIT_RP_SZ_TRACKED" "$_SHELL_GIT_RP_SZ_GITDIR"
		return 0
	fi
	_shell::git::core::colors auto
	_shell::git::core::repo_size_data human
	printf 'loose objects\t%s (%s)\npacked objects\t%s in %s pack(s) (%s)\ntracked at HEAD\t%s in %s file(s)\ngit directory\t%s\n' \
		"$_SHELL_GIT_RP_SZ_LOOSE_COUNT" "$_SHELL_GIT_RP_SZ_LOOSE" "$_SHELL_GIT_RP_SZ_PACKED_COUNT" "$_SHELL_GIT_RP_SZ_PACKS" "$_SHELL_GIT_RP_SZ_PACK" \
		"$(_shell::git::core::repo_human "$_SHELL_GIT_RP_SZ_TRACKED")" "$_SHELL_GIT_RP_SZ_TRACKED_FILES" \
		"$(_shell::git::core::repo_human $((_SHELL_GIT_RP_SZ_GITDIR * 1024)))" | _shell::git::core::align "DIM,"
	return 0
}
