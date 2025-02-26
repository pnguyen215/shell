#!/bin/bash
# homebrew.sh

function install_homebrew() {
    run_cmd_eval '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
}
