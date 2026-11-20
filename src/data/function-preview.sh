#!/bin/sh
# Preview panel of shell::function::explore (src/lib/function.sh).
#
# fzf runs a preview command in a separate process where the library's functions do not exist, so this
# is a standalone POSIX sh script. It does no discovery of its own: the explorer's rows already carry
# where each function's documentation block is.
#
# Arguments (the hidden columns of a row): name visibility loaded absolute-file first-line def-line relative-file
# Environment: SHELL_FUNCTION_DOC_AWK  the renderer (data/function-doc.awk)
name="$1"
vis="$2"
loaded="$3"
abs="$4"
first="$5"
line="$6"
rel="$7"

if [ "$name" = "@back" ]; then
	echo "Go back without changing anything"
elif [ "$abs" = "-" ]; then
	echo "$name"
	echo
	echo "Loaded in this shell, but not defined in the library's source tree: no documentation."
else
	{
		if [ "$first" -lt "$line" ] 2>/dev/null; then
			sed -n "${first},$((line - 1))p" "$abs"
		fi
	} | awk -v name="$name" -v vis="$vis" -v loaded="$loaded" -v file="$rel" -v line="$line" -v color=1 -f "$SHELL_FUNCTION_DOC_AWK"
fi
