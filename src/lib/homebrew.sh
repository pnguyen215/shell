#!/bin/bash
# homebrew.sh

function install_homebrew() {
    run_cmd_eval '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
}

function uninstall_homebrew() {
    if is_command_available brew; then
        echo "🚀 Uninstalling Homebrew..."
        run_cmd_eval '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"'
        run_cmd_eval 'sed -i.bak '/# Homebrew/d' "$HOME/.zprofile"' # Remove Homebrew-related lines from the shell profile
        echo "🟢 Homebrew uninstalled successfully!"
    else
        echo "🟡 Homebrew is not installed. Nothing to uninstall."
    fi
}
