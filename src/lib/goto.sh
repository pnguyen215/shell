#!/bin/bash
# goto.sh

# shell::goto_version function
# Displays the version of the goto script.
#
# Usage:
#   shell::goto_version
#
# Description:
shell::goto_version() {
    echo "goto v0.0.1"
}

# shell::goto function
# Main function to handle user commands and navigate directories.
#
# Usage:
#   shell::goto [command]
#
# Description:
#   The 'shell::goto' function processes user commands to navigate directories, manage bookmarks,
shell::goto() {
    if [ $# -eq 0 ]; then
        shell::list_bookmark
    fi
    while [ $# -gt 0 ]; do
        arg=$1
        case $arg in
        "-ver" | "--version" | "-v")
            shell::goto_version
            break
            ;;

        "-cp")
            shell::clip_cwd
            break
            ;;

        "-s" | "-b")
            shell::add_bookmark $2
            break
            ;;

        "-d")
            local os
            os=$(shell::get_os_type)
            if [[ "$os" == "macos" ]]; then
                shell::remove_bookmark $2
            else
                shell::remove_bookmark_linux $2
            fi
            break
            ;;

        "-list" | "-all" | "-l")
            shell::list_bookmark
            break
            ;;

        "help" | "-h")
            shell::goto_usage
            break
            ;;

        "back" | "-b")
            shell::go_back
            break
            ;;
        *)
            if [ $# != 1 ]; then
                shell::colored_echo "🙈 What?!" 3
            else
                shell::go_bookmark $1
            fi
            break
            ;;
        esac
    done
}

# shell::goto_usage function
# Displays the help information for the goto script.
#
# Usage:
#   shell::goto_usage
#
# Description:
shell::goto_usage() {
    echo "  USAGE:"
    echo
    echo "    Goto <command>"
    echo
    echo "  COMMANDS:"
    echo
    echo "    shell::opent                             # (Mac Only) Open current directory in new Finder Tab."
    echo "    shell::opent <location>                  # (Mac Only) Open location in new Finder Tab."
    echo
    echo "    shell::goto                              # Shows help."
    echo "    shell::goto /User/ ./Home ~/help         # Goes to directory."
    echo "    shell::goto -all | -list                 # Shows all bookmarks."
    echo "    shell::goto <bookmark name>              # Goes to bookmarked directory."
    echo "    shell::goto -s <bookmark name>           # Saves current directory to bookmarks with given name"
    echo "    shell::goto back                         # Goes back in history"
    echo "    shell::goto -cp                          # Copy address to clipboard"
    echo "    shell::goto -d                           # Deletes bookmark"
    echo
    echo
    echo "    shell::goto help | -h                     # show help file."
    echo "    shell::goto -ver | --version | -v         # Show version."
    echo
    echo
}
