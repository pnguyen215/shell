#!/usr/bin/env bash
# @file dependency/clipboard.sh
# @brief Ensure a clipboard tool is installed (macOS has pbcopy built in).

# @description Make sure a clipboard tool is available.
#   macOS ships `pbcopy`. On Linux, `wl-copy` (wl-clipboard) is installed under
#   Wayland and `xclip` otherwise.
# @noargs
# @exitcode 0 A clipboard tool is available.
# @exitcode 3 No tool is available and none could be installed.
# @see shell::clipboard::copy
shell::dependency::clipboard::ensure() {
	if shell::clipboard::tool >/dev/null 2>&1; then
		return "$RETURN_SUCCESS"
	fi

	# macOS always has pbcopy; if we are here on macOS something is badly wrong.
	if shell::os::is_macos; then
		return "$RETURN_NOT_FOUND"
	fi

	if [ -n "${WAYLAND_DISPLAY-}" ]; then
		shell::dependency::ensure wl-copy wl-clipboard
	else
		shell::dependency::ensure xclip
	fi
}
