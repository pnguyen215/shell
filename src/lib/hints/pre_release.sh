#!/bin/bash
# pre_release.sh

# File viewer function using fzf with line highlighting and selection
# Compatible with Linux and macOS with ANSI color support - 100% width
view_file() {
	local file="$1"
	# Check if file argument is provided
	if [[ -z "$file" ]]; then
		echo "Usage: view_file <filename>"
		echo "View file content with line highlighting and selection using fzf"
		return 1
	fi
	# Check if file exists
	if [[ ! -f "$file" ]]; then
		echo "Error: File '$file' not found"
		return 1
	fi
	# Check if file is readable
	if [[ ! -r "$file" ]]; then
		echo "Error: File '$file' is not readable"
		return 1
	fi
	# Check file extension and exclude unsupported formats
	local ext="${file##*.}"
	# Convert to lowercase using tr instead of ${ext,,}
	ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
	case "$ext" in
	xls | xlsx | xlsm | xlsb | ods)
		echo "Error: Excel files are not supported"
		return 1
		;;
	ppt | pptx | pps | ppsx | odp)
		echo "Error: PowerPoint files are not supported"
		return 1
		;;
	doc | docx | odt)
		echo "Error: Word documents are not supported"
		return 1
		;;
	esac
	# Check if fzf is installed
	if ! command -v fzf &>/dev/null; then
		echo "Error: fzf is not installed. Please install fzf first."
		return 1
	fi

	local asked
	asked=$(shell::ask "Do you want to install bat, highlight, and pygmentize for syntax highlighting?")
	if [ "$asked" = "yes" ]; then
		shell::install_package bat
		shell::install_package highlight
	else
		echo "Skipping package installation."
		return 0
	fi

	# Create temporary files
	local temp_file=$(mktemp)
	local colored_file=$(mktemp)
	trap "rm -f '$temp_file' '$colored_file'" EXIT

	# Debug: Check if file has content
	local file_size=$(wc -l <"$file" 2>/dev/null || echo "0")
	if [[ $file_size -eq 0 ]]; then
		echo "Warning: File appears to be empty or has no newlines"
		echo "File size: $(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "unknown") bytes"
	fi

	local highlighting_method=""
	if command -v bat &>/dev/null; then
		highlighting_method="bat"
		bat --color=always --style=plain --paging=never "$file" | nl -ba >"$temp_file"
	elif command -v highlight &>/dev/null; then
		highlighting_method="highlight"
		highlight --out-format=ansi --force --no-doc "$file" 2>/dev/null | nl -ba >"$temp_file"
	elif command -v pygmentize &>/dev/null; then
		highlighting_method="pygmentize"
		pygmentize -f terminal -g "$file" 2>/dev/null | nl -ba >"$temp_file"
	else
		highlighting_method="basic"
		apply_basic_syntax_highlighting "$file" "$ext" >"$colored_file"
		nl -ba "$colored_file" >"$temp_file"
	fi

	local temp_size=$(wc -l <"$temp_file" 2>/dev/null || echo "0")
	if [[ $temp_size -eq 0 ]]; then
		shell::colored_echo "WARN: Syntax highlighting failed with method: $highlighting_method" 11
		nl -ba "$file" >"$temp_file"
		highlighting_method="plain"
	fi

	# Final check: if still no content, use cat with line numbers
	if [[ ! -s "$temp_file" ]]; then
		echo "Error: Failed to process file content. Using direct file access..."
		cat -n "$file" >"$temp_file"
		highlighting_method="cat"
	fi

	# Show debug info if temp file is still empty
	if [[ ! -s "$temp_file" ]]; then
		echo "Debug: Original file line count: $(wc -l <"$file")"
		echo "Debug: Temp file size: $(ls -la "$temp_file")"
		echo "Error: Unable to create processed file for fzf"
		return 1
	fi

	# Get current date/time and user info
	local current_datetime
	current_datetime=$(date +"%Y-%m-%d %H:%M:%S")

	# Trim file_size whitespace, leading/trailing characters
	file_size=$(echo "$file_size" | xargs)
	# Convert file size to human-readable format
	if [[ $file_size -gt 1000 ]]; then
		file_size=$(echo "$file_size" | awk '{printf "%.1fK", $1/1000}')
	else
		file_size=$(echo "$file_size" | awk '{printf "%d", $1}')
	fi

	# Main fzf interface with 100% width
	local selected_lines
	selected_lines=$(cat "$temp_file" | fzf \
		--multi \
		--bind 'enter:accept' \
		--bind 'ctrl-c:abort' \
		--bind 'ctrl-a:select-all' \
		--bind 'ctrl-d:deselect-all' \
		--bind 'tab:toggle' \
		--bind 'shift-tab:toggle+up' \
		--bind 'ctrl-r:toggle-all' \
		--bind 'ctrl-/:toggle-preview' \
		--header="File: $file | Lines: $file_size | MH: $highlighting_method | TAB: select | CTRL+A: all | CTRL+D: deselect | ENTER: copy | ESC: exit" \
		--preview="echo 'Selected lines will be copied to clipboard'" \
		--preview-window="top:1:wrap" \
		--height=100% \
		--border=rounded \
		--border-label="Shell $current_datetime" \
		--border-label-pos=top \
		--margin=0 \
		--padding=0 \
		--ansi \
		--layout=reverse \
		--info=inline \
		--prompt="Search > " \
		--pointer="▶" \
		--marker="✓" \
		--color="header:italic,label:blue,border:dim" \
		--tabstop=4)

	# if [[ -n "$selected_lines" ]]; then
	#     local content_to_copy
	#     content_to_copy=$(echo "$selected_lines" | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//' | sed 's/\x1b\[[0-9;]*m//g')
	#     if declare -f shell::clip_value > /dev/null 2>&1; then
	#         shell::clip_value "$content_to_copy"
	#     fi
	#     local line_count=$(echo "$selected_lines" | wc -l)
	#     echo "Copied $line_count line(s) from '$file'"
	# else
	#     echo "No lines selected"
	# fi

	if [[ -n "$selected_lines" ]]; then
		local line_numbers
		line_numbers=$(echo "$selected_lines" | sed -n 's/^[[:space:]]*\([0-9]*\)[[:space:]].*/\1/p')
		# Get original content for these line numbers (preserve exact original formatting)
		local content_to_copy=""
		while IFS= read -r line_num; do
			if [[ -n "$line_num" ]]; then
				# Get the original line content without modification from the original file
				local original_line
				original_line=$(sed -n "${line_num}p" "$file")
				if [[ -n "$content_to_copy" ]]; then
					content_to_copy="${content_to_copy}\n${original_line}"
				else
					content_to_copy="$original_line"
				fi
			fi
		done <<<"$line_numbers"
		# Convert \n back to actual newlines
		content_to_copy=$(echo -e "$content_to_copy")
		# Use clipboard function if available
		if declare -f shell::clip_value >/dev/null 2>&1; then
			shell::clip_value "$content_to_copy"
		fi
		# Show what was copied with enhanced formatting
		local line_count=$(echo "$line_numbers" | wc -l)
		echo "Copied $line_count line(s) from '$file'"
		echo "Selected line numbers: $(echo "$line_numbers" | tr '\n' ',' | sed 's/,$//')"
	else
		echo "No lines selected"
	fi
}

# Basic syntax highlighting function for common languages
apply_basic_syntax_highlighting() {
	local file="$1"
	local ext="$2"
	if [[ ! -f "$file" ]] || [[ ! -r "$file" ]]; then
		echo "Error: Cannot read file $file" >&2
		return 1
	fi
	local RED='\033[0;31m'
	local GREEN='\033[0;32m'
	local YELLOW='\033[1;33m'
	local BLUE='\033[0;34m'
	local PURPLE='\033[0;35m'
	local CYAN='\033[0;36m'
	local WHITE='\033[1;37m'
	local GRAY='\033[0;90m'
	local NC='\033[0m' # No Color

	case "$ext" in
	sh | bash | zsh)
		sed -E \
			-e "s/(#.*$)/${GRAY}\1${NC}/g" \
			-e "s/(^|[[:space:]])(if|then|else|elif|fi|for|while|do|done|case|esac|function)([[:space:]]|$)/\1${BLUE}\2${NC}\3/g" \
			-e "s/(^|[[:space:]])(echo|printf|read|export|source)([[:space:]]|$)/\1${GREEN}\2${NC}\3/g" \
			-e "s/(\\\$[a-zA-Z_][a-zA-Z0-9_]*|\\\$\{[^}]*\})/${YELLOW}\1${NC}/g" \
			-e "s/(\"[^\"]*\")/${CYAN}\1${NC}/g" \
			-e "s/('[^']*')/${CYAN}\1${NC}/g" \
			"$file"
		;;
	py | python)
		sed -E \
			-e "s/(#.*$)/${GRAY}\1${NC}/g" \
			-e "s/(^|[[:space:]])(def|class|if|elif|else|for|while|try|except|finally|with|import|from|as|return|yield|break|continue|pass|lambda|and|or|not|in|is)([[:space:]]|$)/\1${BLUE}\2${NC}\3/g" \
			-e "s/(^|[[:space:]])(print|len|str|int|float|list|dict|tuple|set|range|enumerate|zip)([[:space:]]|\()/\1${GREEN}\2${NC}\3/g" \
			-e "s/(\"[^\"]*\")/${CYAN}\1${NC}/g" \
			-e "s/('[^']*')/${CYAN}\1${NC}/g" \
			-e "s/(^|[[:space:]])([0-9]+)([[:space:]]|$)/\1${YELLOW}\2${NC}\3/g" \
			"$file"
		;;
	ini | conf | config)
		sed -E \
			-e "s/(#.*$|;.*$)/${GRAY}\1${NC}/g" \
			-e "s/^\s*\[([^\]]*)\]/${BLUE}[\1]${NC}/g" \
			-e "s/^(\s*)([a-zA-Z_][a-zA-Z0-9_.-]*)\s*=/${GREEN}\1\2${NC}=/g" \
			-e "s/(=\s*)(\"[^\"]*\")(\s*$)/\1${CYAN}\2${NC}\3/g" \
			-e "s/(=\s*)([^#;]*[^#;\s])(\s*$)/\1${YELLOW}\2${NC}\3/g" \
			"$file"
		;;
	json)
		sed -E \
			-e "s/(\"[^\"]*\")(\s*:)/${BLUE}\1${NC}\2/g" \
			-e "s/(:)(\s*\"[^\"]*\")(\s*[,}])/\1${CYAN}\2${NC}\3/g" \
			-e "s/(:)(\s*[0-9]+)(\s*[,}])/\1${YELLOW}\2${NC}\3/g" \
			-e "s/(:)(\s*(true|false|null))(\s*[,}])/\1${GREEN}\2${NC}\4/g" \
			-e "s/(\{|\}|\[|\])/${YELLOW}\1${NC}/g" \
			"$file"
		;;
	go)
		sed -E \
			-e "s/(\/\/.*$)/${GRAY}\1${NC}/g" \
			-e "s/(^|[[:space:]])(func|package|import|var|const|type|struct|interface|map|chan|go|defer|select|case|default)([[:space:]]|$)/\1${BLUE}\2${NC}\3/g" \
			-e "s/(^|[[:space:]])(if|else|for|switch|break|continue)([[:space:]]|$)/\1${GREEN}\2${NC}\3/g" \
			-e "s/(\"[^\"]*\")/${CYAN}\1${NC}/g" \
			-e "s/('[^']*')/${CYAN}\1${NC}/g" \
			"$file"
		;;
	*)
		cat "$file"
		;;
	esac
}

# Alias for easier use
alias vf='view_file'

# Help function (simplified)
view_file_help() {
	echo "  view_file <filename>        - View file with syntax highlighting (100% width)"
	echo "  view_file_simple <filename> - View file without syntax highlighting"
	echo "  test_file_content <filename> - Debug file reading issues"
	echo ""
	echo "Aliases:"
	echo "  vf  - shortcut for view_file"
	echo "  vfs - shortcut for view_file_simple"
	echo "  vft - shortcut for test_file_content"
	echo ""
	echo "Key Features:"
	echo "  - 100% width display with rounded borders"
	echo "  - Preserves original file content exactly"
	echo "  - Syntax highlighting for display only"
	echo "  - Original formatting maintained when copying"
	echo "  - Enhanced UI with timestamps and user info"
	echo ""
	echo "Key Bindings:"
	echo "  TAB         - Toggle line selection"
	echo "  CTRL+A      - Select all lines"
	echo "  CTRL+D      - Deselect all lines"
	echo "  CTRL+R      - Toggle all lines"
	echo "  CTRL+/      - Toggle preview window"
	echo "  ENTER       - Copy selected lines"
	echo "  ESC         - Exit without copying"
	echo ""
	echo "Troubleshooting:"
	echo "  1. If no content shows, try: vfs filename"
	echo "  2. To debug file issues, try: vft filename"
	echo "  3. Check file permissions and encoding"
}

alias vfh='view_file_help'
