#!/usr/bin/env bash
# shell::markdown::* (src/markdown/*.sh, src/constant/markdown.sh).
#
# Telegram expectations follow https://core.telegram.org/bots/api#markdownv2-style:
# normal text escapes _ * [ ] ( ) ~ ` > # + - = | { } . ! \ ; code escapes only ` and \ ;
# the (...) of a link escapes only ) and \ . They are checked against the documented
# syntax, not against a live Bot API.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

NL=$'\n'
bs='\'
md() { shell::markdown::init -f markdown; }
tg() { shell::markdown::init -f telegram; }
pl() { shell::markdown::init -f plain; }

# --- lifecycle, format
t_eq "default format is markdown" "markdown" "$(shell::markdown::get_format)"
shell::markdown::init
t_eq "init: empty document renders nothing" "" "$(shell::markdown::render)"
t_eq "init: render rc" "0" "$(
	shell::markdown::render >/dev/null 2>&1
	echo $?
)"
shell::markdown::set_format telegram
t_eq "set_format/get_format" "telegram" "$(shell::markdown::get_format)"
t_rc "set_format: unknown format" 2 shell::markdown::set_format html
t_has "set_format: names the valid formats" "markdown telegram plain" "$T_OUT"
t_eq "set_format: failure keeps the format" "telegram" "$(shell::markdown::get_format)"
t_rc "set_format: no argument" 2 shell::markdown::set_format
t_rc "init: bad format" 2 shell::markdown::init -f nope
t_rc "init: unexpected argument" 2 shell::markdown::init extra
shell::markdown::init
t_eq "init resets the format to the default" "markdown" "$(shell::markdown::get_format)"
shell::markdown::init --format plain
t_eq "init --format" "plain" "$(shell::markdown::get_format)"

md
shell::markdown::paragraph "one"
shell::markdown::reset
t_eq "reset empties the document" "" "$(shell::markdown::render)"
shell::markdown::set_format telegram
shell::markdown::paragraph "x"
shell::markdown::reset
t_eq "reset keeps the format" "telegram" "$(shell::markdown::get_format)"

md
shell::markdown::paragraph "a"
shell::markdown::paragraph "b"
first="$(shell::markdown::render)"
second="$(shell::markdown::render)"
t_eq "render twice gives the same text" "$first" "$second"
t_eq "blocks are separated by one empty line" "a${NL}${NL}b" "$first"
shell::markdown::render >"$HOME/r.out"
t_eq "render output ends with one newline" "a${NL}${NL}b" "$(cat "$HOME/r.out")"
t_eq "render: trailing newline byte count" "5" "$(wc -c <"$HOME/r.out" | tr -d ' ')"

# format switching only affects what is added afterwards
md
shell::markdown::paragraph "a_b"
shell::markdown::set_format telegram
shell::markdown::paragraph "c_d"
t_eq "format switch: earlier blocks keep their format" "a\\_b${NL}${NL}c${bs}_d" "$(shell::markdown::render)"

# --- escaping (telegram)
t_eq "tg escape: Hello_World" "Hello${bs}_World" "$(shell::markdown::escape_text -f telegram 'Hello_World')"
t_eq "tg escape: link syntax as text" "${bs}[GitHub${bs}]${bs}(https://github${bs}.com${bs})" "$(shell::markdown::escape_text -f telegram '[GitHub](https://github.com)')"
t_eq "tg escape: version" "Version 1${bs}.2${bs}.3" "$(shell::markdown::escape_text -f telegram 'Version 1.2.3')"
t_eq "tg escape: price" 'Price: $100 \+ $20' "$(shell::markdown::escape_text -f telegram 'Price: $100 + $20')"
t_eq "tg escape: path" "Path: src/lib/git${bs}.sh" "$(shell::markdown::escape_text -f telegram 'Path: src/lib/git.sh')"
t_eq "tg escape: every special character" '\! \# \+ \- \= \{ \} \| \~' "$(shell::markdown::escape_text -f telegram '! # + - = { } | ~')"
t_eq "tg escape: the full documented set" '\_\*\[\]\(\)\~\`\>\#\+\-\=\|\{\}\.\!\\' "$(shell::markdown::escape_text -f telegram '_*[]()~`>#+-=|{}.!\')"
t_eq "tg escape: backslash" 'a\\b' "$(shell::markdown::escape_text -f telegram 'a\b')"
t_eq "tg escape: unicode untouched" "Xin chào, Việt Nam${bs}!" "$(shell::markdown::escape_text -f telegram 'Xin chào, Việt Nam!')"
t_eq "tg escape: empty string" "" "$(shell::markdown::escape_text -f telegram '')"
t_eq "tg escape: multiline keeps the newline" "a${bs}.${NL}b${bs}." "$(shell::markdown::escape_text -f telegram "a.${NL}b.")"
t_eq "tg code escape: only backtick and backslash" 'a.b-c \` \\ !' "$(shell::markdown::escape_code -f telegram 'a.b-c ` \ !')"
t_eq "tg url escape: parentheses and backslash only" 'https://a.org/w_(x\)?q=1&r=a-b.c' "$(shell::markdown::escape_url -f telegram 'https://a.org/w_(x)?q=1&r=a-b.c')"
t_eq "tg url escape: backslash" 'https://a.org/\\x' "$(shell::markdown::escape_url -f telegram 'https://a.org/\x')"
t_eq "plain escape: unchanged" "a_b *c*" "$(shell::markdown::escape_text -f plain 'a_b *c*')"

# --- escaping (markdown)
t_eq "md escape: inline markers" 'a\_b \*c\* \`d\` \[e\]' "$(shell::markdown::escape_text -f markdown 'a_b *c* `d` [e]')"
t_eq "md escape: backslash" 'a\\b' "$(shell::markdown::escape_text -f markdown 'a\b')"
t_eq "md escape: block markers only at line start" '\# h a#b > q 1. x' "$(shell::markdown::escape_text -f markdown '# h a#b > q 1. x')"
t_eq "md escape: heading marker" '\# not a heading' "$(shell::markdown::escape_text -f markdown '# not a heading')"
t_eq "md escape: mid-line # kept" 'issue #12 - done' "$(shell::markdown::escape_text -f markdown 'issue #12 - done')"
t_eq "md escape: list marker" '\- not a list' "$(shell::markdown::escape_text -f markdown '- not a list')"
t_eq "md escape: numbered line" '1\. not a list' "$(shell::markdown::escape_text -f markdown '1. not a list')"
t_eq "md escape: version number is left alone" 'Version 1.2.3' "$(shell::markdown::escape_text -f markdown 'Version 1.2.3')"
t_eq "md escape: second line start" "a${NL}"'\> q' "$(shell::markdown::escape_text -f markdown "a${NL}> q")"
t_eq "md url escape" 'https://a.org/w_%28x%29%20y' "$(shell::markdown::escape_url -f markdown 'https://a.org/w_(x) y')"
t_eq "md code escape: unchanged" 'a`b\c' "$(shell::markdown::escape_code -f markdown 'a`b\c')"
t_eq "md unicode untouched" "Việt Nam" "$(shell::markdown::escape_text -f markdown 'Việt Nam')"

# --- escape option handling
t_rc "escape: unknown -f" 2 shell::markdown::escape_text -f html x
t_rc "escape: -f without value" 2 shell::markdown::escape_text -f
t_rc "escape: no text" 2 shell::markdown::escape_text
t_rc "escape_url: no url" 2 shell::markdown::escape_url
t_rc "escape_code: no code" 2 shell::markdown::escape_code
tg
t_eq "escape uses the document format" "a${bs}.b" "$(shell::markdown::escape_text 'a.b')"
t_eq "escape keeps fragments, escapes the rest" "x${bs}. *y*" "$(shell::markdown::escape "x. $(shell::markdown::bold y)")"

# --- inline formatting
md
t_eq "md bold" "**Important**" "$(shell::markdown::unwrap "$(shell::markdown::bold Important)")"
t_eq "md italic" "*Note*" "$(shell::markdown::unwrap "$(shell::markdown::italic Note)")"
t_eq "md bold_italic" "***Both***" "$(shell::markdown::unwrap "$(shell::markdown::bold_italic Both)")"
t_eq "md underline" "<u>U</u>" "$(shell::markdown::unwrap "$(shell::markdown::underline U)")"
t_eq "md strikethrough" "~~old~~" "$(shell::markdown::unwrap "$(shell::markdown::strikethrough old)")"
t_eq "md spoiler" '<span class="spoiler">s</span>' "$(shell::markdown::unwrap "$(shell::markdown::spoiler s)")"
t_eq "md code" '`git status`' "$(shell::markdown::unwrap "$(shell::markdown::code 'git status')")"
t_eq "md code with a backtick" '``a`b``' "$(shell::markdown::unwrap "$(shell::markdown::code 'a`b')")"
t_eq "md code starting with a backtick" '`` `x ``' "$(shell::markdown::unwrap "$(shell::markdown::code '`x')")"
t_eq "md code is not escaped" '`a_b*c`' "$(shell::markdown::unwrap "$(shell::markdown::code 'a_b*c')")"
t_eq "md link" "[GitHub](https://github.com)" "$(shell::markdown::unwrap "$(shell::markdown::link GitHub https://github.com)")"
t_eq "md link: empty text uses the url" "[https://a.org](https://a.org)" "$(shell::markdown::unwrap "$(shell::markdown::link '' https://a.org)")"
t_eq "md image" "![Screenshot](https://example.com/image.png)" "$(shell::markdown::unwrap "$(shell::markdown::image Screenshot https://example.com/image.png)")"
t_eq "md bold escapes its text" '**a\_b**' "$(shell::markdown::unwrap "$(shell::markdown::bold 'a_b')")"
tg
t_eq "tg bold" "*Important*" "$(shell::markdown::unwrap "$(shell::markdown::bold Important)")"
t_eq "tg italic" "_Note_" "$(shell::markdown::unwrap "$(shell::markdown::italic Note)")"
t_eq "tg bold_italic" "*_Both_*" "$(shell::markdown::unwrap "$(shell::markdown::bold_italic Both)")"
t_eq "tg underline" "__U__" "$(shell::markdown::unwrap "$(shell::markdown::underline U)")"
t_eq "tg strikethrough" "~old~" "$(shell::markdown::unwrap "$(shell::markdown::strikethrough old)")"
t_eq "tg spoiler" "||s||" "$(shell::markdown::unwrap "$(shell::markdown::spoiler s)")"
t_eq "tg code" '`git status`' "$(shell::markdown::unwrap "$(shell::markdown::code 'git status')")"
t_eq "tg code with special characters" '`a.b-c \` \\ !`' "$(shell::markdown::unwrap "$(shell::markdown::code 'a.b-c ` \ !')")"
t_eq "tg link" "[GitHub](https://github.com)" "$(shell::markdown::unwrap "$(shell::markdown::link GitHub https://github.com)")"
t_eq "tg link: text escaped" "[v1${bs}.2](https://a.org)" "$(shell::markdown::unwrap "$(shell::markdown::link v1.2 https://a.org)")"
t_eq "tg link: query parameters untouched" "[q](https://a.org/s?q=1&r=a-b.c#x)" "$(shell::markdown::unwrap "$(shell::markdown::link q 'https://a.org/s?q=1&r=a-b.c#x')")"
t_eq "tg link: parentheses in the url" '[w](https://en.wikipedia.org/wiki/A_(b\))' "$(shell::markdown::unwrap "$(shell::markdown::link w 'https://en.wikipedia.org/wiki/A_(b)')")"
t_eq "tg link: backslash in the url" 'https://a.org/\\x' "$(shell::markdown::escape_url 'https://a.org/\x')"
t_eq "tg image falls back to a link" "[Shot](https://a.org/i.png)" "$(shell::markdown::unwrap "$(shell::markdown::image Shot https://a.org/i.png)")"
t_eq "tg nested: bold around italic" "*a _b_ c*" "$(shell::markdown::unwrap "$(shell::markdown::bold "a $(shell::markdown::italic b) c")")"
t_eq "tg nested: no double escaping" '*a _b\.c_*' "$(shell::markdown::unwrap "$(shell::markdown::bold "a $(shell::markdown::italic 'b.c')")")"
t_eq "tg nested: strike inside bold" "*x ~y~*" "$(shell::markdown::unwrap "$(shell::markdown::bold "x $(shell::markdown::strikethrough y)")")"
t_eq "tg unicode in bold" "*Tiếng Việt*" "$(shell::markdown::unwrap "$(shell::markdown::bold 'Tiếng Việt')")"
pl
t_eq "plain bold has no markup" "Important" "$(shell::markdown::unwrap "$(shell::markdown::bold Important)")"
t_eq "plain link" "GitHub (https://github.com)" "$(shell::markdown::unwrap "$(shell::markdown::link GitHub https://github.com)")"
t_eq "plain image" "Shot (https://a.org/i.png)" "$(shell::markdown::unwrap "$(shell::markdown::image Shot https://a.org/i.png)")"
t_eq "plain code" "git status" "$(shell::markdown::unwrap "$(shell::markdown::code 'git status')")"

# empty and invalid input
for fn in bold italic bold_italic underline strikethrough spoiler code; do
	t_eq "$fn: empty text gives an empty fragment" "" "$(shell::markdown::$fn '')"
	t_rc "$fn: missing text" 2 shell::markdown::$fn
done
t_rc "link: missing url" 2 shell::markdown::link text ''
t_rc "link: one argument" 2 shell::markdown::link text
t_rc "link: newline in the url" 2 shell::markdown::link text "http://a${NL}b"
t_rc "image: one argument" 2 shell::markdown::image alt

# fragments leave nothing behind in the document
tg
shell::markdown::paragraph "Hi $(shell::markdown::bold you)"
case "$(shell::markdown::render)" in
*$'\001'* | *$'\002'*) t_bad "buffer holds no fragment markers" ;;
*) t_ok ;;
esac
t_eq "fragment composed into a paragraph" "Hi *you*" "$(shell::markdown::render)"
t_eq "unwrap removes markers" "*x*" "$(shell::markdown::unwrap "$(shell::markdown::bold x)")"
t_eq "fragment keeps trusted text verbatim" "Hi [Ann](tg://user?id=1)" "$(
	shell::markdown::reset
	shell::markdown::paragraph "Hi $(shell::markdown::fragment '[Ann](tg://user?id=1)')"
	shell::markdown::render
)"

# --- headings
md
shell::markdown::h1 "One"
shell::markdown::h2 "Two"
shell::markdown::h3 "Three"
shell::markdown::heading 4 "Four"
shell::markdown::heading 5 "Five"
shell::markdown::heading 6 "Six"
t_eq "md: heading levels 1-6" "# One${NL}${NL}## Two${NL}${NL}### Three${NL}${NL}#### Four${NL}${NL}##### Five${NL}${NL}###### Six" "$(shell::markdown::render)"
t_rc "heading: level 0" 2 shell::markdown::heading 0 x
t_rc "heading: level 7" 2 shell::markdown::heading 7 x
t_rc "heading: level not a number" 2 shell::markdown::heading a x
t_rc "heading: missing text" 2 shell::markdown::heading 2
t_rc "h1: missing text" 2 shell::markdown::h1
md
shell::markdown::h2 "Title: v1_2"
t_eq "md heading text is escaped" 'Title: v1\_2' "$(shell::markdown::render | sed 's/^## //')"
md
shell::markdown::h1 ""
t_eq "empty heading appends nothing" "" "$(shell::markdown::render)"
tg
shell::markdown::h1 "Git History v1.0"
shell::markdown::h3 "Sub"
t_eq "tg: headings become bold lines" "*Git History v1${bs}.0*${NL}${NL}*Sub*" "$(shell::markdown::render)"
pl
shell::markdown::h1 "Title"
shell::markdown::h2 "Sub"
shell::markdown::h3 "Small"
t_eq "plain: h1/h2 underlined" "Title${NL}=====${NL}${NL}Sub${NL}---${NL}${NL}Small" "$(shell::markdown::render)"

# --- paragraphs, quotes, rules
md
shell::markdown::paragraph "Hello_World"
t_eq "md paragraph escapes" 'Hello\_World' "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::paragraph ""
t_eq "empty paragraph appends nothing" "" "$(shell::markdown::render)"
t_rc "paragraph: no argument" 2 shell::markdown::paragraph
t_rc "paragraph: two arguments" 2 shell::markdown::paragraph a b
shell::markdown::reset
shell::markdown::paragraph "line one${NL}line two"
t_eq "multiline paragraph" "line one${NL}line two" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::blockquote "Quoted${NL}${NL}again"
t_eq "md blockquote" "> Quoted${NL}>${NL}> again" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::horizontal_rule
t_eq "md horizontal rule" "---" "$(shell::markdown::render)"
t_rc "horizontal_rule: argument" 2 shell::markdown::horizontal_rule x
tg
shell::markdown::blockquote "Quoted.${NL}more"
t_eq "tg blockquote" ">Quoted${bs}.${NL}>more" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::horizontal_rule
t_eq "tg horizontal rule is a plain separator" "$SHELL_MARKDOWN_TELEGRAM_RULE" "$(shell::markdown::render)"
t_lacks "tg separator needs no escaping" "$bs" "$SHELL_MARKDOWN_TELEGRAM_RULE"
shell::markdown::reset
shell::markdown::paragraph "Version 1.2.3"
shell::markdown::paragraph "Special characters: ! # + - = { } | ~"
shell::markdown::paragraph "Path: src/lib/git.sh"
shell::markdown::paragraph "Price: \$100 + \$20"
t_eq "tg compatibility sample" "Version 1${bs}.2${bs}.3${NL}${NL}Special characters: \\! \\# \\+ \\- \\= \\{ \\} \\| \\~${NL}${NL}Path: src/lib/git${bs}.sh${NL}${NL}"'Price: $100 \+ $20' "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::paragraph "Xin chào thế giới. Tiếng Việt!"
t_eq "tg vietnamese" "Xin chào thế giới${bs}. Tiếng Việt${bs}!" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::paragraph "$(shell::markdown::bold Git) $(shell::markdown::italic and) $(shell::markdown::code gh) plain.text"
t_eq "tg mixed formatting and plain text" "*Git* _and_ \`gh\` plain${bs}.text" "$(shell::markdown::render)"

# --- code blocks
md
shell::markdown::code_block bash "git log --oneline"
t_eq "md code block" "\`\`\`bash${NL}git log --oneline${NL}\`\`\`" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::code_block "echo a_b | tr 'a' 'b'"
t_eq "md code block without a language is not escaped" "\`\`\`${NL}echo a_b | tr 'a' 'b'${NL}\`\`\`" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::code_block text "a${NL}\`\`\`${NL}b"
t_eq "md code block: fence grows past inner backticks" "\`\`\`\`text${NL}a${NL}\`\`\`${NL}b${NL}\`\`\`\`" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::code_block "" "x${NL}"
t_eq "md code block: one trailing newline dropped" "\`\`\`${NL}x${NL}\`\`\`" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::code_block bash "l1${NL}l2"
t_eq "md multiline code" "\`\`\`bash${NL}l1${NL}l2${NL}\`\`\`" "$(shell::markdown::render)"
t_rc "code_block: bad language" 2 shell::markdown::code_block 'ba sh' x
t_rc "code_block: language with a backtick" 2 shell::markdown::code_block 'a`b' x
t_rc "code_block: no argument" 2 shell::markdown::code_block
t_rc "code_block: three arguments" 2 shell::markdown::code_block a b c
tg
shell::markdown::code_block bash "echo a.b-c | cat"
t_eq "tg code block: no escaping of normal characters" "\`\`\`bash${NL}echo a.b-c | cat${NL}\`\`\`" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::code_block text "a${NL}\`\`\`${NL}b \\ c"
t_eq "tg code block cannot close its own fence" "\`\`\`text${NL}a${NL}${bs}\`${bs}\`${bs}\`${NL}b ${bs}${bs} c${NL}\`\`\`" "$(shell::markdown::render)"
pl
shell::markdown::code_block bash "a${NL}b"
t_eq "plain code block is indented" "    a${NL}    b" "$(shell::markdown::render)"

# --- lists
md
shell::markdown::list "First" "Second"
t_eq "md list" "- First${NL}- Second" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::ordered_list "First" "Second" "Third"
t_eq "md ordered list" "1. First${NL}2. Second${NL}3. Third" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::list_item "Top"
shell::markdown::nested_item 1 "Child"
shell::markdown::nested_item 2 "Grandchild"
shell::markdown::list_item "Next"
t_eq "md nested list" "- Top${NL}    - Child${NL}        - Grandchild${NL}- Next" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::ordered_item "One"
shell::markdown::nested_item 1 "Sub"
shell::markdown::ordered_item "Two"
t_eq "md ordered with a nested item keeps counting" "1. One${NL}    - Sub${NL}2. Two" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::ordered_item "One"
shell::markdown::paragraph "break"
shell::markdown::ordered_item "Again"
t_eq "md numbering restarts after another block" "1. One${NL}${NL}break${NL}${NL}1. Again" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::list "a"
shell::markdown::list "b"
t_eq "md: two list calls are two blocks" "- a${NL}${NL}- b" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::list_item "line one${NL}line two"
t_eq "md multiline item is aligned" "- line one${NL}  line two" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::ordered_item "x${NL}y"
t_eq "md multiline ordered item is aligned" "1. x${NL}   y" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::list_item "a_b"
t_eq "md list item is escaped" 'a\_b' "$(shell::markdown::render | sed 's/^- //')"
t_rc "list_item: missing text" 2 shell::markdown::list_item
t_rc "list: no items" 2 shell::markdown::list
t_rc "ordered_list: no items" 2 shell::markdown::ordered_list
t_rc "nested_item: bad level" 2 shell::markdown::nested_item x "t"
t_rc "nested_item: negative level" 2 shell::markdown::nested_item -1 "t"
t_rc "nested_item: missing text" 2 shell::markdown::nested_item 1
tg
shell::markdown::list "First." "Second-item"
shell::markdown::nested_item 1 "Nested (x)"
t_eq "tg list: bullets and escaped text" "• First${bs}.${NL}• Second${bs}-item${NL}  ◦ Nested ${bs}(x${bs})" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::ordered_list "One" "Two"
t_eq "tg ordered list: the dot is escaped" "1${bs}. One${NL}2${bs}. Two" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::list_item "a${NL}b"
t_eq "tg multiline item is aligned" "• a${NL}  b" "$(shell::markdown::render)"
pl
shell::markdown::list "a_b" "c"
t_eq "plain list" "- a_b${NL}- c" "$(shell::markdown::render)"

# --- tables
md
shell::markdown::table_header "Hash" "Author" "Message"
shell::markdown::table_row "a1b2c3" "John" "Add feature"
shell::markdown::table_row "d4e5f6" "David" "Fix bug"
shell::markdown::table
t_eq "md table" "| Hash   | Author | Message     |${NL}| ------ | ------ | ----------- |${NL}| a1b2c3 | John   | Add feature |${NL}| d4e5f6 | David  | Fix bug     |" "$(shell::markdown::render)"
md
shell::markdown::table_header "L" "C" "R"
shell::markdown::table_align left center right
shell::markdown::table_row "a" "b" "c"
shell::markdown::table
t_eq "md table alignment" "| L   |  C  |   R |${NL}| :-- | :-: | --: |${NL}| a   |  b  |   c |" "$(shell::markdown::render)"
md
shell::markdown::table_header "A" "B"
shell::markdown::table_row "x|y" ""
shell::markdown::table_row "line1${NL}line2" "z"
shell::markdown::table_row "only"
shell::markdown::table_row "p" "q" "extra"
shell::markdown::table
t_eq "md table: pipes, empty and multiline cells, ragged rows" "| A              | B   |       |${NL}| -------------- | --- | ----- |${NL}| x\\|y           |     |       |${NL}| line1<br>line2 | z   |       |${NL}| only           |     |       |${NL}| p              | q   | extra |" "$(shell::markdown::render)"
t_eq "md table: cell with a pipe" "1" "$(shell::markdown::render | grep -c 'x\\|y')"
t_eq "md table: multiline cell uses <br>" "1" "$(shell::markdown::render | grep -c 'line1<br>line2')"
t_eq "md table: every line has the same number of pipes" "1" "$(shell::markdown::render | sed 's/\\|//g' | awk '{n=gsub(/\|/,"|")} NR==1{c=n} n!=c{bad=1} END{print bad?0:1}')"
md
shell::markdown::table_header "Tiếng" "Việt"
shell::markdown::table_row "xin" "chào"
shell::markdown::table
t_eq "md table with vietnamese text" "| Tiếng | Việt |${NL}| ----- | ---- |${NL}| xin   | chào |" "$(shell::markdown::render)"
md
shell::markdown::table_header "H"
shell::markdown::table
t_eq "md table without rows keeps the header" "| H   |${NL}| --- |" "$(shell::markdown::render)"
md
shell::markdown::table_header "A"
shell::markdown::table_row "x"
shell::markdown::table
shell::markdown::table_header "B"
shell::markdown::table_row "y"
shell::markdown::table
t_eq "table state is cleared after table" "| A   |${NL}| --- |${NL}| x   |${NL}${NL}| B   |${NL}| --- |${NL}| y   |" "$(shell::markdown::render)"
t_rc "table: nothing pending" 2 shell::markdown::table
t_rc "table_row: no table" 2 shell::markdown::table_row a
t_rc "table_align: no table" 2 shell::markdown::table_align left
t_rc "table_header: no cell" 2 shell::markdown::table_header
shell::markdown::table_header A
t_rc "table_row: no cell" 2 shell::markdown::table_row
t_rc "table_align: bad value" 2 shell::markdown::table_align middle
tg
shell::markdown::table_header "Commit" "Author" "Message"
shell::markdown::table_row "$(shell::markdown::code a1b2c3)" "John" "Add feature"
shell::markdown::table_row "d4e5f6" "David" "Fix bug"
shell::markdown::table
t_eq "tg table fallback" "*Commit:* \`a1b2c3\`${NL}*Author:* John${NL}*Message:* Add feature${NL}${NL}*Commit:* d4e5f6${NL}*Author:* David${NL}*Message:* Fix bug" "$(shell::markdown::render)"
tg
shell::markdown::table_header "Name" "Note"
shell::markdown::table_row "v1.0" ""
shell::markdown::table_row "b" "two${NL}lines | x"
shell::markdown::table
t_eq "tg table: escaping, empty cells skipped, newline flattened" "*Name:* v1${bs}.0${NL}${NL}*Name:* b${NL}*Note:* two lines ${bs}| x" "$(shell::markdown::render)"
pl
shell::markdown::table_header "Name" "Note"
shell::markdown::table_row "a" "b"
shell::markdown::table
t_eq "plain table fallback" "Name: a${NL}Note: b" "$(shell::markdown::render)"

# --- raw and append
md
shell::markdown::raw "# Custom Markdown"
shell::markdown::raw "_not_ escaped"
t_eq "raw keeps the text verbatim, as blocks" "# Custom Markdown${NL}${NL}_not_ escaped" "$(shell::markdown::render)"
shell::markdown::reset
shell::markdown::append "abc"
shell::markdown::append "def"
t_eq "append concatenates without separator" "abcdef" "$(shell::markdown::render)"
t_rc "raw: no argument" 2 shell::markdown::raw
t_rc "append: no argument" 2 shell::markdown::append
shell::markdown::reset
shell::markdown::raw ""
t_eq "empty raw appends nothing" "" "$(shell::markdown::render)"

# --- file export
md
shell::markdown::h1 "Report"
shell::markdown::paragraph "Body"
t_rc "to_file: write" 0 shell::markdown::to_file "$HOME/out.md"
t_eq "to_file content" "# Report${NL}${NL}Body" "$(cat "$HOME/out.md")"
t_eq "to_file ends with one newline" "$(shell::markdown::render | wc -c | tr -d ' ')" "$(wc -c <"$HOME/out.md" | tr -d ' ')"
t_rc "to_file: overwrite" 0 shell::markdown::to_file "$HOME/out.md"
t_rc "to_file: missing directory" 3 shell::markdown::to_file "$HOME/nope/out.md"
t_rc "to_file: a directory" 2 shell::markdown::to_file "$HOME"
t_rc "to_file: no path" 2 shell::markdown::to_file
t_rc "to_file: empty path" 2 shell::markdown::to_file ""
rm -f "$HOME/dry.md"
t_rc "to_file: dry run" 0 shell::markdown::to_file -n "$HOME/dry.md"
t_rc "to_file: dry run writes nothing" 1 test -e "$HOME/dry.md"
shell::markdown::reset
t_rc "to_file: empty document" 0 shell::markdown::to_file "$HOME/empty.md"
t_eq "to_file: empty document gives an empty file" "0" "$(wc -c <"$HOME/empty.md" | tr -d ' ')"
(cd "$HOME" && shell::markdown::paragraph x && shell::markdown::to_file rel.md)
t_eq "to_file: relative path" "x" "$(cat "$HOME/rel.md")"

# --- stdout / stderr separation
md
out="$(shell::markdown::paragraph "x" 2>/dev/null)"
t_eq "block functions print nothing on stdout" "" "$out"
err="$(shell::markdown::bold 2>&1 >/dev/null)"
t_has "errors go to stderr" "text argument" "$err"
out="$(shell::markdown::bold 2>/dev/null)"
t_eq "errors leave stdout clean" "" "$out"
out="$(shell::markdown::heading 9 x 2>/dev/null)"
t_eq "invalid heading prints nothing on stdout" "" "$out"
t_eq "render has nothing on stderr" "" "$(shell::markdown::render 2>&1 >/dev/null)"
t_eq "render does not mutate" "$(shell::markdown::render)" "$(shell::markdown::render)"

# --- help
for fn in init reset set_format get_format append raw render to_file escape escape_text escape_url escape_code fragment unwrap bold italic bold_italic underline strikethrough spoiler code link image heading h1 h2 h3 paragraph blockquote horizontal_rule code_block list_item ordered_item nested_item list ordered_list table_header table_align table_row table; do
	t_rc "help: $fn" 0 shell::markdown::$fn --help
	t_has "help: $fn usage" "shell::markdown::$fn" "$T_OUT"
done

# --- the public/private split
for fn in format_opt esc_text esc_url esc_code inline wrap emit clear cell cells record nth count pad item prefix_lines max_run repeat strip frag link_like valid_format wants_help help table_markdown table_cards; do
	t_eq "private: _shell::markdown::$fn exists" "function" "$(type -t _shell::markdown::$fn 2>/dev/null || { typeset -f _shell::markdown::$fn >/dev/null 2>&1 && echo function; })"
done

t_done
