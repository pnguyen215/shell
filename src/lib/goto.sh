#!/bin/bash
# goto.sh

# goto_version function
# Displays the version of the goto script.
#
# Usage:
#   goto_version
#
# Description:
goto_version() {
    echo "goto v0.0.1"
}

# goto function
# Main function to handle user commands and navigate directories.
#
# Usage:
#   goto [command]
#
# Description:
#   The 'goto' function processes user commands to navigate directories, manage bookmarks,
goto() {
    if [ $# -eq 0 ]; then
        shell::show_bookmark
    fi
    while [ $# -gt 0 ]; do
        arg=$1
        case $arg in
        "-ver" | "--version" | "-v")
            goto_version
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
            shell::show_bookmark
            break
            ;;

        "help" | "-h")
            goto_usage
            break
            ;;

        "back" | "-b")
            go_back
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

# goto_usage function
# Displays the help information for the goto script.
#
# Usage:
#   goto_usage
#
# Description:
goto_usage() {
    echo "  USAGE:"
    echo
    echo "    Goto <command>"
    echo
    echo "  COMMANDS:"
    echo
    echo "    shell::opent                             # (Mac Only) Open current directory in new Finder Tab."
    echo "    shell::opent <location>                  # (Mac Only) Open location in new Finder Tab."
    echo
    echo "    goto                              # Shows help."
    echo "    goto /User/ ./Home ~/help         # Goes to directory."
    echo "    goto -all | -list                 # Shows all bookmarks."
    echo "    goto <bookmark name>              # Goes to bookmarked directory."
    echo "    goto -s <bookmark name>           # Saves current directory to bookmarks with given name"
    echo "    goto back                         # Goes back in history"
    echo "    goto -cp                          # Copy address to clipboard"
    echo "    goto -d                           # Deletes bookmark"
    echo
    echo
    echo "    goto help | -h                     # show help file."
    echo "    goto -ver | --version | -v         # Show version."
    echo
    echo
}
